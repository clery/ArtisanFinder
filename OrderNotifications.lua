local _, AF = ...

local ORDER_SOUND_FALLBACK = "CATALOG_SHOP_OPEN_LOADING_SCREEN" -- catalog_shop_open_loading_screen_1

local function GetOrderSound()
	local soundKey = AF.db and AF.db.orderNotificationSound or ORDER_SOUND_FALLBACK
	return SOUNDKIT and (SOUNDKIT[soundKey] or SOUNDKIT[ORDER_SOUND_FALLBACK])
end

local function GetOrderSoundChannel()
	local channel = AF.db and AF.db.orderNotificationChannel
	return channel and channel ~= "" and channel ~= "default" and channel or nil
end

local function CountPersonalOrders()
	local infos = C_CraftingOrders and C_CraftingOrders.GetPersonalOrdersInfo and C_CraftingOrders.GetPersonalOrdersInfo() or {}
	local total = 0
	local rows = {}
	for _, info in ipairs(infos) do
		local count = tonumber(info.numPersonalOrders) or 0
		if count > 0 then
			total = total + count
			table.insert(rows, {
				characterName = AF.playerName or AF:GetPlayerFullName(),
				professionName = info.professionName,
				count = count,
				current = true,
			})
		end
	end
	return total, rows
end

local function GetCraftingOrderFrame()
	return MinimapCluster
		and MinimapCluster.IndicatorFrame
		and MinimapCluster.IndicatorFrame.CraftingOrderFrame
end

local function GetOrderTotals(AF)
	local currentTotal = 0
	local altTotal = 0
	for _, row in ipairs(AF:GetKnownOrderRows()) do
		local count = tonumber(row.count) or 0
		if row.current then
			currentTotal = currentTotal + count
		elseif row.alt then
			altTotal = altTotal + count
		end
	end
	return currentTotal, altTotal
end

function AF:PlayOrderNotificationSound()
	local sound = GetOrderSound()
	if sound then
		PlaySound(sound, GetOrderSoundChannel())
	end
end

function AF:ShowOrderNotification(characterName, count)
	local text = self:Text("ORDER_NOTIFICATION_MESSAGE", self:GetDisplayPlayerName(characterName), tonumber(count) or 1)
	if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then
		RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo.RAID_WARNING)
	elseif UIErrorsFrame and UIErrorsFrame.AddMessage then
		UIErrorsFrame:AddMessage(text, 1, 0.82, 0)
	else
		self:Print(text)
	end
end

function AF:NotifyPersonalOrder(characterName, count, sender)
	characterName = self:NormalizeName(characterName)
	if not characterName then
		return
	end
	local playerName = self:NormalizeName(self.playerName or self:GetPlayerFullName())
	if characterName == playerName and sender then
		return
	end
	count = tonumber(count) or 1
	self.altOrderNotifications = self.altOrderNotifications or {}
	self.altOrderNotifications[characterName] = {
		characterName = characterName,
		count = count,
		professionName = self.altOrderNotifications[characterName] and self.altOrderNotifications[characterName].professionName or (sender == "dev" and self:Text("DEBUG_ORDER_PROFESSION") or nil),
		updatedAt = self:Now(),
		sender = sender,
		dev = sender == "dev" or nil,
	}
	self.lastOrderNotificationSender = sender
	self:DebugLog("orders", string.format("notify character=%s count=%s sender=%s", tostring(characterName), tostring(count), tostring(sender or "")))
	self:PlayOrderNotificationSound()
	self:ShowOrderNotification(characterName, count)
	if self.RefreshCraftingOrderIndicator then
		self:RefreshCraftingOrderIndicator()
	end
end

function AF:HandleOrderNotification(parts, sender)
	local characterName = self:DecodeField(parts[3])
	local count = tonumber(parts[4]) or 1
	self:NotifyPersonalOrder(characterName, count, sender)
end

function AF:SendOrderNotification(characterName, count)
	characterName = self:NormalizeName(characterName)
	if not characterName or not self.SendAddon then
		return false
	end
	local payload = table.concat({
		"O",
		self.PROTOCOL_VERSION,
		self:EncodeField(characterName, 48),
		tonumber(count) or 1,
		self:Now(),
	}, "|")
	self:DebugLog("orders", "send target=" .. tostring(characterName))
	return self:SendAddon(payload, "WHISPER", characterName, "NORMAL", "O:" .. characterName)
end

function AF:OnPersonalOrderCountsUpdated()
	local total, rows = CountPersonalOrders()
	self.currentPersonalOrderRows = rows
	local previous = self.currentPersonalOrderCount
	self.currentPersonalOrderCount = total
	self:DebugLog("orders", string.format("count previous=%s current=%s", tostring(previous), tostring(total)))
	if previous ~= nil and total > previous then
		self:PlayOrderNotificationSound()
	end
	if self.RefreshCraftingOrderIndicator then
		self:RefreshCraftingOrderIndicator()
	end
end

function AF:OnOrderPlacementResponse(result)
	if result ~= Enum.CraftingOrderResult.Ok then
		self.pendingPersonalOrderTarget = nil
		return
	end
	local target = self.pendingPersonalOrderTarget
	self.pendingPersonalOrderTarget = nil
	if target then
		self:SendOrderNotification(target, 1)
	end
end

function AF:InitializeOrderNotifications()
	if self.orderNotificationsInitialized then
		return
	end
	self.orderNotificationsInitialized = true
	if C_CraftingOrders and C_CraftingOrders.PlaceNewOrder then
		hooksecurefunc(C_CraftingOrders, "PlaceNewOrder", function(orderInfo)
			if type(orderInfo) == "table"
				and orderInfo.orderType == Enum.CraftingOrderType.Personal
				and orderInfo.orderTarget
				and orderInfo.orderTarget ~= ""
			then
				AF.pendingPersonalOrderTarget = AF:NormalizeName(orderInfo.orderTarget)
				AF:DebugLog("orders", "pending target=" .. tostring(AF.pendingPersonalOrderTarget))
			else
				AF.pendingPersonalOrderTarget = nil
			end
		end)
	end
	self:InitializeCraftingOrderIndicator()
	self:OnPersonalOrderCountsUpdated()
end

function AF:GetKnownOrderRows()
	local rows = {}
	for _, row in ipairs(self.currentPersonalOrderRows or {}) do
		table.insert(rows, row)
	end
	for characterName, entry in pairs(self.altOrderNotifications or {}) do
		if tonumber(entry.count) and tonumber(entry.count) > 0 then
			table.insert(rows, {
				characterName = characterName,
				count = tonumber(entry.count) or 1,
				professionName = entry.professionName,
				updatedAt = entry.updatedAt,
				sender = entry.sender,
				alt = true,
				dev = entry.dev,
			})
		end
	end
	return rows
end

function AF:DevNotifyOrder(characterName, count)
	self.db.debugEnabled = true
	self.db.devEnabled = true
	characterName = self:NormalizeName(characterName)
	local playerName = self:NormalizeName(self.playerName or self:GetPlayerFullName())
	if not characterName or characterName == playerName then
		local playerBase = tostring(playerName or "ArtisanFinder"):match("^([^-]+)") or "ArtisanFinder"
		local realm = self:GetNameRealm(playerName) or (GetRealmName() and GetRealmName():gsub("%s+", "")) or "Realm"
		characterName = playerBase .. "Alt-" .. realm
	end
	self:NotifyPersonalOrder(characterName, tonumber(count) or 1, "dev")
end

function AF:DevSetCurrentOrders(count)
	count = tonumber(count) or 1
	self.db.debugEnabled = true
	self.db.devEnabled = true
	self.currentPersonalOrderCount = count
	self.currentPersonalOrderRows = {}
	if count > 0 then
		table.insert(self.currentPersonalOrderRows, {
			characterName = self.playerName or self:GetPlayerFullName(),
			professionName = self:Text("DEBUG_ORDER_PROFESSION"),
			count = count,
			current = true,
			dev = true,
		})
	end
	self:RefreshCraftingOrderIndicator()
end

function AF:DevSetAltOrders(characterName, professionName, count)
	characterName = self:NormalizeName(characterName or self:GetPlayerFullName())
	if not characterName then
		return
	end
	count = tonumber(count) or 1
	self.db.debugEnabled = true
	self.db.devEnabled = true
	self.altOrderNotifications = self.altOrderNotifications or {}
	self.altOrderNotifications[characterName] = {
		characterName = characterName,
		professionName = professionName and professionName ~= "" and professionName or self:Text("DEBUG_ORDER_PROFESSION"),
		count = count,
		updatedAt = self:Now(),
		sender = "dev",
		dev = true,
	}
	self:RefreshCraftingOrderIndicator()
end

function AF:DevClearOrders()
	for characterName, entry in pairs(self.altOrderNotifications or {}) do
		if entry.dev then
			self.altOrderNotifications[characterName] = nil
		end
	end
	if self.currentPersonalOrderRows and self.currentPersonalOrderRows[1] and self.currentPersonalOrderRows[1].dev then
		self.currentPersonalOrderRows = {}
		self.currentPersonalOrderCount = 0
	end
	self:RefreshCraftingOrderIndicator()
end

function AF:PrintOrderDebugState()
	self:Print(self:Text("DEBUG_ORDERS_STATE", tostring(self.currentPersonalOrderCount or 0), tostring(self.lastOrderNotificationSender or "")))
	for _, row in ipairs(self:GetKnownOrderRows()) do
		self:Print(self:Text(
			"DEBUG_ORDERS_ROW",
			self:GetDisplayPlayerName(row.characterName),
			row.professionName or "",
			tonumber(row.count) or 0,
			row.current and "current" or "alt"
		))
	end
end

function AF:InitializeCraftingOrderIndicator()
	if self.craftingOrderIndicatorInitialized then
		return
	end
	local frame = GetCraftingOrderFrame()
	if not frame then
		return
	end
	self.craftingOrderIndicatorInitialized = true
	hooksecurefunc(frame, "OnEnter", function(owner)
		AF:AddCraftingOrderIndicatorTooltip(owner)
	end)
end

function AF:AddCraftingOrderIndicatorTooltip(owner)
	local rows = self:GetKnownOrderRows()
	if #rows == 0 or not GameTooltip or not GameTooltip:IsShown() then
		return
	end
	GameTooltip_AddBlankLineToTooltip(GameTooltip)
	GameTooltip_AddNormalLine(GameTooltip, "ArtisanFinder", false)
	for _, row in ipairs(rows) do
		local count = tonumber(row.count) or 0
		if count > 0 then
			local name = row.alt and self:GetFullDisplayPlayerName(row.characterName) or self:GetDisplayPlayerName(row.characterName)
			local profession = row.professionName and row.professionName ~= "" and (" - " .. row.professionName) or ""
			GameTooltip_AddNormalLine(GameTooltip, self:Text("ORDER_TOOLTIP_ROW", name, profession, count), false)
		end
	end
	GameTooltip:Show()
end

function AF:RefreshCraftingOrderIndicator()
	self:InitializeCraftingOrderIndicator()
	local frame = GetCraftingOrderFrame()
	if not frame then
		return
	end
	local currentTotal, altTotal = GetOrderTotals(self)
	local hasAlt = altTotal > 0
	local icon = frame.Icon or _G.MiniMapCraftingOrderIcon
	if hasAlt and icon then
		icon:SetVertexColor(0.45, 0.85, 1)
	elseif icon then
		icon:SetVertexColor(1, 1, 1)
	end
	if hasAlt or currentTotal > 0 then
		frame:Show()
	elseif frame.countInfos and #frame.countInfos == 0 then
		frame:Hide()
	end
	if frame:GetParent() and frame:GetParent().Layout then
		frame:GetParent():Layout()
	end
end
