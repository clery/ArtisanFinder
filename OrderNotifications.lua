local _, AF = ...

local ORDER_SOUND_FALLBACK = "CATALOG_SHOP_OPEN_LOADING_SCREEN" -- catalog_shop_open_loading_screen_1
local TOAST_WIDTH = 340
local TOAST_HEIGHT = 80
local TOAST_SPACING = 6
local TOAST_FADE_IN_SECONDS = 0.18
local TOAST_HOLD_SECONDS = 4.4
local TOAST_FADE_OUT_SECONDS = 0.7
local DEV_ORDER_ITEM_ID = 240949
local DEV_CUSTOMER_NAMES = {
	"Aelindra",
	"Belorian",
	"Celendra",
	"Dathren",
	"Elowen",
	"Faelaris",
	"Kaedryn",
	"Lyrielle",
}

local function GetOrderSound()
	local soundKey = AF.db and AF.db.orderNotificationSound or ORDER_SOUND_FALLBACK
	return SOUNDKIT and (SOUNDKIT[soundKey] or SOUNDKIT[ORDER_SOUND_FALLBACK])
end

local function GetOrderSoundChannel()
	local channel = AF.db and AF.db.orderNotificationChannel
	return channel and channel ~= "" and channel ~= "default" and channel or nil
end

local function CanShowOrderNotification(self)
	if self:IsInCombatLocked() then
		return false
	end
	if self:IsInUnavailableActivity() then
		return false
	end
	return true
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

local function FormatOrderCharacter(AF, characterName)
	return AF:GetDisplayPlayerName(characterName)
end

local function FormatOrderCustomer(AF, customerName)
	return AF:GetDisplayPlayerName(customerName)
end

local function Clamp(value, minValue, maxValue, fallback)
	value = tonumber(value) or fallback or minValue
	return math.min(math.max(value, minValue), maxValue)
end

local function GetOrderNotificationItemInfo(details)
	details = details or {}
	local itemID = tonumber(details.itemID) or AF:GetItemIDFromLink(details.itemLink)
	local itemName = details.itemName
	local itemLink = details.itemLink
	local itemQuality = tonumber(details.itemQuality)
	local itemIcon = tonumber(details.itemIcon)
	if itemID then
		local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
		itemName = itemName or name
		itemLink = itemLink or link
		itemQuality = itemQuality or tonumber(quality)
		itemIcon = itemIcon or tonumber(icon) or (C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID))
		if not name and C_Item.RequestLoadItemDataByID then
			pcall(C_Item.RequestLoadItemDataByID, itemID)
		end
	end
	return itemID, itemName, itemLink, itemQuality, itemIcon
end

local function SetItemTextColor(fontString, quality)
	quality = tonumber(quality)
	if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
		local color = ITEM_QUALITY_COLORS[quality]
		fontString:SetTextColor(color.r or 1, color.g or 1, color.b or 1)
	elseif quality and GetItemQualityColor then
		local r, g, b = GetItemQualityColor(quality)
		fontString:SetTextColor(r or 1, g or 1, b or 1)
	else
		fontString:SetTextColor(1, 1, 1)
	end
end

local function SetToastIconQuality(frame, quality, itemIDOrLink)
	if SetItemButtonQuality then
		SetItemButtonQuality(frame, quality, itemIDOrLink, true)
		return
	end
	quality = tonumber(quality)
	if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
		local color = ITEM_QUALITY_COLORS[quality]
		frame.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
		frame.IconBorder:SetVertexColor(color.r or 1, color.g or 1, color.b or 1)
		frame.IconBorder:Show()
	elseif quality and GetItemQualityColor then
		local r, g, b = GetItemQualityColor(quality)
		frame.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
		frame.IconBorder:SetVertexColor(r or 1, g or 1, b or 1)
		frame.IconBorder:Show()
	else
		frame.IconBorder:Hide()
	end
end

local function GetRandomDevCustomerName()
	local base = DEV_CUSTOMER_NAMES[random(1, #DEV_CUSTOMER_NAMES)]
	local realm = GetRealmName and GetRealmName()
	realm = realm and realm:gsub("%s+", "") or nil
	return realm and (base .. "-" .. realm) or base
end

local function GetRandomDevCommission()
	return (random(1, 100) * 100) * 10000
end

local function CopyOrderDetails(details)
	if type(details) ~= "table" then
		return {}
	end
	return {
		itemID = tonumber(details.itemID),
		itemLink = details.itemLink,
		itemName = details.itemName,
		itemQuality = tonumber(details.itemQuality),
		itemIcon = tonumber(details.itemIcon),
		commissionCopper = tonumber(details.commissionCopper),
		customerName = details.customerName,
		professionName = details.professionName,
	}
end

local function StripOrderDisplayText(text)
	text = tostring(text or "")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	text = text:gsub("|A.-|a", "")
	text = text:gsub("|T.-|t", "")
	text = text:gsub("%s+", " "):match("^%s*(.-)%s*$")
	return text ~= "" and text or nil
end

local function GetFallbackOrderIcon(form)
	local outputIcon = form and form.OutputIcon
	local iconTexture = outputIcon and outputIcon.Icon
	local texture = iconTexture and iconTexture.GetTexture and iconTexture:GetTexture()
	return tonumber(texture)
end

local function GetFallbackOrderName(form, recipeSchematic)
	local text = form and form.order and form.order.isRecraft
		and form.RecraftRecipeName and form.RecraftRecipeName.GetText and form.RecraftRecipeName:GetText()
		or form and form.RecipeName and form.RecipeName.GetText and form.RecipeName:GetText()
	return StripOrderDisplayText(text) or StripOrderDisplayText(recipeSchematic and recipeSchematic.name)
end

local function FillOrderDetailsFromItemInfo(details)
	local itemID, itemName, itemLink, itemQuality, itemIcon = GetOrderNotificationItemInfo(details)
	details.itemID = details.itemID or itemID
	details.itemName = details.itemName or itemName
	details.itemLink = details.itemLink or itemLink
	details.itemQuality = details.itemQuality or itemQuality
	details.itemIcon = details.itemIcon or itemIcon
	return details
end

local function FillOrderDetailsFallback(details, form, recipeSchematic)
	details.itemName = details.itemName or GetFallbackOrderName(form, recipeSchematic)
	details.itemIcon = details.itemIcon or GetFallbackOrderIcon(form)
	return details
end

local function ResetOrderNotificationToast(_, toast)
	toast:Hide()
	toast:ClearAllPoints()
	toast.itemID = nil
	toast.itemLink = nil
	toast.elapsed = nil
	toast.paused = false
	toast:SetAlpha(1)
	toast:SetScale(1)
	if toast.IconBorder then
		toast.IconBorder:Hide()
	end
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

function AF:PlayOrderNotificationSound(force)
	if not force and self.db and (self.db.orderNotificationsEnabled == false or self.db.orderNotificationSoundEnabled == false) then
		return
	end
	-- if not force and not CanShowOrderNotification(self) then
	-- 	return
	-- end
	local sound = GetOrderSound()
	if sound then
		PlaySound(sound, GetOrderSoundChannel())
	end
end

function AF:ShowOrderNotification(characterName, count, details)
	if self.db and (self.db.orderNotificationsEnabled == false or self.db.orderNotificationBannerEnabled == false) then
		return
	end
	-- if not CanShowOrderNotification(self) then
	-- 	return
	-- end
	self:ShowOrderNotificationToast(characterName, count, details)
end

function AF:NotifyPersonalOrder(characterName, count, sender, details)
	characterName = self:NormalizeName(characterName)
	if not characterName then
		return
	end
	local playerName = self:NormalizeName(self.playerName or self:GetPlayerFullName())
	if characterName == playerName and sender then
		return
	end
	count = tonumber(count) or 1
	details = CopyOrderDetails(details)
	if not details.customerName or details.customerName == "" then
		details.customerName = sender and sender ~= "dev" and sender or nil
	end
	FillOrderDetailsFromItemInfo(details)
	self.db.orderNotifications = self.db.orderNotifications or {}
	self.altOrderNotifications = self.db.orderNotifications
	self.altOrderNotifications[characterName] = {
		characterName = characterName,
		count = count,
		professionName = details.professionName or (self.altOrderNotifications[characterName] and self.altOrderNotifications[characterName].professionName) or (sender == "dev" and self:Text("DEBUG_ORDER_PROFESSION") or nil),
		updatedAt = self:Now(),
		sender = sender,
		dev = sender == "dev" or nil,
		itemID = details.itemID,
		itemLink = details.itemLink,
		itemName = details.itemName,
		itemQuality = details.itemQuality,
		itemIcon = details.itemIcon,
		commissionCopper = details.commissionCopper,
		customerName = details.customerName,
	}
	self.lastOrderNotificationSender = sender
	self:DebugLog("orders", string.format("notify character=%s count=%s sender=%s item=%s commission=%s customer=%s", tostring(characterName), tostring(count), tostring(sender or ""), tostring(details.itemID or ""), tostring(details.commissionCopper or ""), tostring(details.customerName or "")))
	self:PlayOrderNotificationSound()
	self:ShowOrderNotification(characterName, count, details)
	if self.RefreshCraftingOrderIndicator then
		self:RefreshCraftingOrderIndicator()
	end
end

function AF:GetOrderNotificationGrowDirection()
	local direction = self.db and self.db.orderNotificationGrowDirection
	return direction == "UP" and "UP" or "DOWN"
end

function AF:GetOrderNotificationScale()
	local scale = tonumber(self.db and self.db.orderNotificationScale) or 1
	if scale < 0.75 then
		return 0.75
	end
	if scale > 1.5 then
		return 1.5
	end
	return scale
end

function AF:SetOrderNotificationScale(scale)
	self.db.orderNotificationScale = Clamp(scale, 0.75, 1.5, 1)
	self:RefreshOrderNotificationToasts()
end

function AF:SetOrderNotificationGrowDirection(direction)
	self.db.orderNotificationGrowDirection = direction == "UP" and "UP" or "DOWN"
	self:RefreshOrderNotificationToasts()
end

function AF:HandleOrderNotification(parts, sender)
	local characterName = self:DecodeField(parts[3])
	local count = tonumber(parts[4]) or 1
	local details = {
		itemID = tonumber(parts[6]),
		commissionCopper = tonumber(parts[7]),
		customerName = self:DecodeField(parts[8]),
		itemName = self:DecodeField(parts[9]),
		itemIcon = tonumber(parts[10]),
		professionName = self:DecodeField(parts[11]),
		itemQuality = tonumber(parts[12]),
	}
	self:NotifyPersonalOrder(characterName, count, sender, details)
end

function AF:SendOrderNotification(characterName, count, details)
	characterName = self:NormalizeName(characterName)
	if not characterName or not self.SendAddon then
		return false
	end
	details = CopyOrderDetails(details)
	FillOrderDetailsFromItemInfo(details)
	local messageTarget = self:GetRememberedArtisanContact(characterName) or characterName
	local payload = table.concat({
		"O",
		self.PROTOCOL_VERSION,
		self:EncodeField(characterName, 48),
		tonumber(count) or 1,
		self:Now(),
		tonumber(details.itemID) or "",
		tonumber(details.commissionCopper) or "",
		self:EncodeField(details.customerName or self.playerName or self:GetPlayerFullName(), 48),
		self:EncodeField(details.itemName or "", 64),
		tonumber(details.itemIcon) or "",
		self:EncodeField(details.professionName or "", 40),
		tonumber(details.itemQuality) or "",
	}, "|")
	self:DebugLog("orders", "send target=" .. tostring(messageTarget) .. " orderTarget=" .. tostring(characterName) .. " item=" .. tostring(details.itemID or ""))
	return self:SendAddon(payload, "WHISPER", messageTarget, "NORMAL", "O:" .. characterName)
end

function AF:OnPersonalOrderCountsUpdated()
	local total, rows = CountPersonalOrders()
	self.currentPersonalOrderRows = rows
	local previous = self.currentPersonalOrderCount
	self.currentPersonalOrderCount = total
	local playerName = self:NormalizeName(self.playerName or self:GetPlayerFullName())
	if playerName and total <= 0 and self.altOrderNotifications and self.altOrderNotifications[playerName] then
		self.altOrderNotifications[playerName] = nil
	end
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
		self.pendingPersonalOrderDetails = nil
		return
	end
	local target = self.pendingPersonalOrderTarget
	local details = self.pendingPersonalOrderDetails
	self.pendingPersonalOrderTarget = nil
	self.pendingPersonalOrderDetails = nil
	if target then
		if self:IsOwnArtisanCharacter(target) then
			self:NotifyPersonalOrder(target, 1, nil, details)
		end
		self:SendOrderNotification(target, 1, details)
	end
end

function AF:CapturePersonalOrderDetails(orderInfo, form)
	if type(orderInfo) ~= "table"
		or orderInfo.orderType ~= Enum.CraftingOrderType.Personal
		or not orderInfo.orderTarget
		or orderInfo.orderTarget == ""
	then
		return nil
	end
	local details = {
		commissionCopper = tonumber(orderInfo.tipAmount),
		customerName = self.playerName or self:GetPlayerFullName(),
	}
	if form and form.order then
		details.professionName = C_TradeSkillUI.GetProfessionNameForSkillLineAbility(form.order.skillLineAbilityID)
		local recipeID = form.order.spellID
		local transaction = form.transaction
		local recipeSchematic = transaction and transaction.GetRecipeSchematic and transaction:GetRecipeSchematic()
		if form.order.isRecraft and form.order.recraftItemHyperlink then
			details.itemLink = form.order.recraftItemHyperlink
			details.itemID = self:GetItemIDFromLink(details.itemLink)
			details.itemName = details.itemID and self:GetItemName(details.itemID)
			details.itemIcon = details.itemID and C_Item.GetItemIconByID(details.itemID)
		elseif recipeID and transaction then
			local optionalReagents = transaction.CreateOptionalCraftingReagentInfoTbl and transaction:CreateOptionalCraftingReagentInfoTbl() or nil
			local minimumQuality = form.minQualityIDs and form.order.minQuality and form.minQualityIDs[form.order.minQuality] or nil
			local outputItemInfo = C_TradeSkillUI.GetRecipeOutputItemData(recipeID, optionalReagents, nil, minimumQuality)
			if outputItemInfo then
				details.itemLink = outputItemInfo.hyperlink
				details.itemID = tonumber(outputItemInfo.itemID) or self:GetItemIDFromLink(outputItemInfo.hyperlink)
				details.itemName = details.itemID and self:GetItemName(details.itemID) or outputItemInfo.itemName
				details.itemIcon = outputItemInfo.icon or (details.itemID and C_Item.GetItemIconByID(details.itemID))
			end
		end
		FillOrderDetailsFallback(details, form, recipeSchematic)
	end
	FillOrderDetailsFromItemInfo(details)
	return details
end

function AF:InitializeCustomerOrderFormHook()
	if self.customerOrderFormHooked or not ProfessionsCustomerOrderFormMixin or not ProfessionsCustomerOrderFormMixin.ListOrder then
		return
	end
	self.customerOrderFormHooked = true
	hooksecurefunc(ProfessionsCustomerOrderFormMixin, "ListOrder", function(form)
		if not form or not form.order or form.order.orderType ~= Enum.CraftingOrderType.Personal then
			return
		end
		local target = form.OrderRecipientTarget and form.OrderRecipientTarget:GetText()
		if not target or target == "" then
			return
		end
		local details = AF:CapturePersonalOrderDetails({
			orderType = form.order.orderType,
			orderTarget = target,
			tipAmount = form.PaymentContainer and form.PaymentContainer.TipMoneyInputFrame and form.PaymentContainer.TipMoneyInputFrame:GetAmount(),
		}, form)
		AF.pendingPersonalOrderTarget = AF:NormalizeName(target)
		AF.pendingPersonalOrderDetails = details
		AF:DebugLog("orders", "pending details target=" .. tostring(AF.pendingPersonalOrderTarget) .. " item=" .. tostring(details and details.itemID or ""))
	end)
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
				AF.pendingPersonalOrderDetails = AF:CapturePersonalOrderDetails(orderInfo)
				AF:DebugLog("orders", "pending target=" .. tostring(AF.pendingPersonalOrderTarget))
			else
				AF.pendingPersonalOrderTarget = nil
				AF.pendingPersonalOrderDetails = nil
			end
		end)
	end
	self:InitializeCustomerOrderFormHook()
	self:InitializeCraftingOrderIndicator()
	self.db.orderNotifications = self.db.orderNotifications or {}
	self.altOrderNotifications = self.db.orderNotifications
	self:OnPersonalOrderCountsUpdated()
end

function AF:GetKnownOrderRows()
	local rows = {}
	local playerName = self:NormalizeName(self.playerName or self:GetPlayerFullName())
	for _, row in ipairs(self.currentPersonalOrderRows or {}) do
		table.insert(rows, row)
	end
	for characterName, entry in pairs(self.altOrderNotifications or {}) do
		if characterName ~= playerName and tonumber(entry.count) and tonumber(entry.count) > 0 then
			table.insert(rows, {
				characterName = characterName,
				count = tonumber(entry.count) or 1,
				professionName = entry.professionName,
				updatedAt = entry.updatedAt,
				sender = entry.sender,
				alt = true,
				dev = entry.dev,
				itemID = entry.itemID,
				itemLink = entry.itemLink,
				itemName = entry.itemName,
				itemQuality = entry.itemQuality,
				itemIcon = entry.itemIcon,
				commissionCopper = entry.commissionCopper,
				customerName = entry.customerName,
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
	local _, itemName, itemLink, itemQuality, itemIcon = GetOrderNotificationItemInfo({ itemID = DEV_ORDER_ITEM_ID, itemName = "Masterwork Sin'dorei Band" })
	self:NotifyPersonalOrder(characterName, tonumber(count) or 1, "dev", {
		itemID = DEV_ORDER_ITEM_ID,
		itemName = itemName or "Masterwork Sin'dorei Band",
		itemLink = itemLink,
		itemQuality = itemQuality,
		itemIcon = itemIcon,
		commissionCopper = GetRandomDevCommission(),
		customerName = GetRandomDevCustomerName(),
		professionName = self:Text("DEBUG_ORDER_PROFESSION"),
	})
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
	self.db.orderNotifications = self.db.orderNotifications or {}
	self.altOrderNotifications = self.db.orderNotifications
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

function AF:ClearOrderNotifications(silent)
	self.db.orderNotifications = {}
	self.altOrderNotifications = self.db.orderNotifications
	local toastPool = self.orderNotificationToastPool
	for _, toast in ipairs(self.orderNotificationActiveToasts or {}) do
		if toastPool and toastPool:IsActive(toast) then
			toastPool:Release(toast)
		else
			ResetOrderNotificationToast(nil, toast)
		end
	end
	self.orderNotificationActiveToasts = {}
	if GameTooltip then
		GameTooltip:Hide()
	end
	if self.RefreshCraftingOrderIndicator then
		self:RefreshCraftingOrderIndicator()
	end
	if self.RefreshOpenMinimapTooltip then
		self:RefreshOpenMinimapTooltip()
	end
	if not silent then
		self:Print(self:Text("ORDER_NOTIFICATIONS_CLEARED"))
	end
end

function AF:PrintOrderDebugState()
	self:Print(self:Text("DEBUG_ORDERS_STATE", tostring(self.currentPersonalOrderCount or 0), tostring(self.lastOrderNotificationSender or "")))
	for _, row in ipairs(self:GetKnownOrderRows()) do
		self:Print(self:Text(
			"DEBUG_ORDERS_ROW",
			self:GetDisplayPlayerName(row.characterName),
			row.itemName or row.professionName or "",
			tonumber(row.count) or 0,
			row.current and "current" or "alt"
		))
	end
end

function AF:InitializeOrderNotificationToast(frame)
	frame:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(80)
	frame:EnableMouse(true)
	frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame:SetClampedToScreen(true)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 14,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame:SetBackdropColor(0.02, 0.018, 0.014, 0.92)
	frame:SetBackdropBorderColor(0.86, 0.72, 0.34, 0.95)
	frame:Hide()

	frame.Icon = frame:CreateTexture(nil, "ARTWORK")
	frame.Icon:SetSize(48, 48)
	frame.Icon:SetPoint("LEFT", 14, 0)
	frame.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	frame.IconBorder = frame:CreateTexture(nil, "OVERLAY")
	frame.IconBorder:SetPoint("TOPLEFT", frame.Icon, -5, 5)
	frame.IconBorder:SetPoint("BOTTOMRIGHT", frame.Icon, 5, -5)
	frame.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
	frame.IconBorder:Hide()

	frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", 72, -10)
	frame.Title:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
	frame.Title:SetJustifyH("LEFT")
	frame.Title:SetWordWrap(false)

	frame.ItemName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
	frame.ItemName:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 0, -2)
	frame.ItemName:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
	frame.ItemName:SetJustifyH("LEFT")
	frame.ItemName:SetWordWrap(false)

	frame.Meta = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.Meta:SetPoint("TOPLEFT", frame.ItemName, "BOTTOMLEFT", 0, -1)
	frame.Meta:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
	frame.Meta:SetJustifyH("LEFT")
	frame.Meta:SetTextColor(0.82, 0.82, 0.82)
	frame.Meta:SetWordWrap(false)

	frame.Commission = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.Commission:SetPoint("TOPLEFT", frame.Meta, "BOTTOMLEFT", 0, -1)
	frame.Commission:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
	frame.Commission:SetJustifyH("LEFT")
	frame.Commission:SetTextColor(1, 0.82, 0)
	frame.Commission:SetWordWrap(false)

	frame:SetScript("OnEnter", function(toast)
		toast.paused = true
		toast.elapsed = TOAST_FADE_IN_SECONDS
		toast:SetAlpha(1)
		if toast.itemLink or toast.itemID then
			GameTooltip:SetOwner(toast, "ANCHOR_TOP")
			if toast.itemLink then
				GameTooltip:SetHyperlink(toast.itemLink)
			elseif GameTooltip.SetItemByID then
				GameTooltip:SetItemByID(toast.itemID)
			else
				GameTooltip:SetHyperlink("item:" .. tostring(toast.itemID))
			end
			GameTooltip:Show()
		end
	end)
	frame:SetScript("OnLeave", function(toast)
		toast.paused = false
		GameTooltip:Hide()
	end)
	frame:SetScript("OnClick", function(toast, button)
		if button == "RightButton" then
			GameTooltip:Hide()
			AF:ReleaseOrderNotificationToast(toast)
			return
		end
		if toast.itemLink and HandleModifiedItemClick then
			HandleModifiedItemClick(toast.itemLink)
		end
	end)
	frame:SetScript("OnUpdate", function(toast, elapsed)
		if toast.paused then
			return
		end
		toast.elapsed = (toast.elapsed or 0) + elapsed
		local t = toast.elapsed
		if t < TOAST_FADE_IN_SECONDS then
			toast:SetAlpha(t / TOAST_FADE_IN_SECONDS)
		elseif t < TOAST_HOLD_SECONDS then
			toast:SetAlpha(1)
		elseif t < TOAST_HOLD_SECONDS + TOAST_FADE_OUT_SECONDS then
			toast:SetAlpha(1 - ((t - TOAST_HOLD_SECONDS) / TOAST_FADE_OUT_SECONDS))
		else
			AF:ReleaseOrderNotificationToast(toast)
		end
	end)

	return frame
end

function AF:GetOrderNotificationToastPool()
	if not self.orderNotificationToastPool then
		self.orderNotificationToastPool = CreateFramePool("Button", UIParent, "BackdropTemplate", ResetOrderNotificationToast, nil, function(frame)
			AF:InitializeOrderNotificationToast(frame)
		end)
	end
	return self.orderNotificationToastPool
end

function AF:GetOrderNotificationAnchor()
	if self.orderNotificationAnchor then
		return self.orderNotificationAnchor
	end
	local anchor = CreateFrame("Frame", "ArtisanFinderOrderNotificationAnchor", UIParent)
	anchor:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
	anchor:SetClampedToScreen(true)
	anchor:EnableMouse(false)
	anchor:Show()
	self.orderNotificationAnchor = anchor
	self:PositionOrderNotificationAnchor()
	return anchor
end

function AF:PositionOrderNotificationAnchor()
	local anchor = self.orderNotificationAnchor
	if not anchor then
		return
	end
	anchor:ClearAllPoints()
	local point = self.db and self.db.orderNotificationPoint or "TOP"
	anchor:SetPoint(point, UIParent, point, self.db and self.db.orderNotificationX or 0, self.db and self.db.orderNotificationY or -170)
	self:RefreshOrderNotificationToasts()
end

function AF:SetOrderNotificationAnchorPosition(point, x, y)
	self.db.orderNotificationPoint = point or "TOP"
	self.db.orderNotificationX = math.floor((tonumber(x) or 0) + 0.5)
	self.db.orderNotificationY = math.floor((tonumber(y) or -170) + 0.5)
	self:PositionOrderNotificationAnchor()
end

function AF:RefreshOrderNotificationAnchor()
	local anchor = self:GetOrderNotificationAnchor()
	anchor:SetScale(self:GetOrderNotificationScale())
	anchor:SetSize(TOAST_WIDTH, TOAST_HEIGHT)
end

function AF:SetupOrderNotificationToast(frame, characterName, count, details)
	details = CopyOrderDetails(details)
	local itemID, itemName, itemLink, itemQuality, itemIcon = GetOrderNotificationItemInfo(details)
	frame.itemID = itemID
	frame.itemLink = itemLink
	frame.elapsed = 0
	frame.paused = false
	frame:SetAlpha(0)
	frame:SetScale(self:GetOrderNotificationScale())
	frame.Icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_Note_01")
	SetToastIconQuality(frame, itemQuality, itemLink or itemID)
	frame.Title:SetText(self:Text("ORDER_NOTIFICATION_TITLE"))
	frame.ItemName:SetText(itemName or details.itemName or self:Text("ORDER_NOTIFICATION_UNKNOWN_ITEM"))
	SetItemTextColor(frame.ItemName, itemQuality)
	frame.Meta:SetText(self:Text(
		"ORDER_NOTIFICATION_META",
		FormatOrderCharacter(self, characterName),
		FormatOrderCustomer(self, details.customerName or self:Text("UNKNOWN_CUSTOMER"))
	))
	frame.Commission:SetText(self:Text(
		"ORDER_NOTIFICATION_COMMISSION",
		self:FormatMoney(tonumber(details.commissionCopper) or 0)
	))
end

function AF:RefreshOrderNotificationToasts()
	self:RefreshOrderNotificationAnchor()
	local scale = self:GetOrderNotificationScale()
	local anchor = self:GetOrderNotificationAnchor()
	local activeToasts = self.orderNotificationActiveToasts or {}
	local growUp = self:GetOrderNotificationGrowDirection() == "UP"
	local offsetStep = (TOAST_HEIGHT + TOAST_SPACING) * scale
	for index, toast in ipairs(activeToasts) do
		toast:ClearAllPoints()
		toast:SetScale(scale)
		if growUp then
			toast:SetPoint("BOTTOM", anchor, "BOTTOM", 0, (index - 1) * offsetStep)
		else
			toast:SetPoint("TOP", anchor, "TOP", 0, -((index - 1) * offsetStep))
		end
	end
end

function AF:ReleaseOrderNotificationToast(toast)
	if not toast then
		return
	end
	local activeToasts = self.orderNotificationActiveToasts or {}
	for index, activeToast in ipairs(activeToasts) do
		if activeToast == toast then
			table.remove(activeToasts, index)
			break
		end
	end
	local toastPool = self:GetOrderNotificationToastPool()
	if toastPool:IsActive(toast) then
		toastPool:Release(toast)
	else
		ResetOrderNotificationToast(nil, toast)
	end
	self:RefreshOrderNotificationToasts()
end

function AF:AcquireOrderNotificationToast()
	return self:GetOrderNotificationToastPool():Acquire()
end

function AF:ShowOrderNotificationToast(characterName, count, details)
	local frame = self:AcquireOrderNotificationToast()
	self.orderNotificationActiveToasts = self.orderNotificationActiveToasts or {}
	table.insert(self.orderNotificationActiveToasts, frame)
	self:SetupOrderNotificationToast(frame, characterName, count, details)
	self:RefreshOrderNotificationToasts()
	frame:Show()
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
	frame:HookScript("OnEvent", function()
		C_Timer.After(0, function()
			AF:RefreshCraftingOrderIndicator()
		end)
	end)
	frame:HookScript("OnEnter", function(owner)
		C_Timer.After(0, function()
			AF:AddCraftingOrderIndicatorTooltip(owner or frame)
		end)
	end)
	C_Timer.After(0, function()
		AF:RefreshCraftingOrderIndicator()
	end)
end

function AF:AddCraftingOrderIndicatorTooltip(owner)
	local rows = self:GetKnownOrderRows()
	if #rows == 0 or not GameTooltip then
		return
	end
	if not GameTooltip:IsShown() then
		GameTooltip:SetOwner(owner or GetCraftingOrderFrame() or UIParent, "ANCHOR_LEFT")
		GameTooltip:SetText(PROFESSIONS_CRAFTING_ORDERS or "Crafting Orders", 1, 0.82, 0)
	end
	GameTooltip_AddBlankLineToTooltip(GameTooltip)
	GameTooltip_AddNormalLine(GameTooltip, "ArtisanFinder", false)
	for _, row in ipairs(rows) do
		local count = tonumber(row.count) or 0
		if count > 0 then
			local name = row.alt and self:GetFullDisplayPlayerName(row.characterName) or self:GetDisplayPlayerName(row.characterName)
			local profession = row.professionName and row.professionName ~= "" and (" - " .. row.professionName) or ""
			GameTooltip_AddNormalLine(GameTooltip, self:Text("ORDER_TOOLTIP_ROW", name, profession, count), false)
			if row.itemName and row.itemName ~= "" then
				GameTooltip_AddHighlightLine(GameTooltip, row.itemName, false)
			end
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
		icon:SetVertexColor(0.15, 0.95, 1)
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
