local _, AF = ...

local ORDER_SOUND_FALLBACK = "CATALOG_SHOP_OPEN_LOADING_SCREEN" -- catalog_shop_open_loading_screen_1
local TOAST_WIDTH = 340
local TOAST_HEIGHT = 80
local TOAST_SPACING = 6
local TOAST_FADE_IN_SECONDS = 0.18
local TOAST_HOLD_SECONDS = 4.4
local TOAST_FADE_OUT_SECONDS = 0.7
local ORDER_NOTIFICATION_FALLBACK_DELAY_SECONDS = 1
local CUSTOMER_ORDER_REFRESH_DELAY_SECONDS = 0.5
local CUSTOMER_ORDER_REFRESH_DEFER_DELAY_SECONDS = 1.5
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

local function GetOptionalGlobal(name)
	return rawget(_G, name)
end

local function IsFrameShown(frame)
	return frame and frame.IsShown and frame:IsShown()
end

local function GetCraftingOrdersTitle(self)
	return GetOptionalGlobal("PROFESSIONS_CRAFTING_ORDERS") or self:Text("CRAFTING_ORDERS_TITLE")
end

local function IsCustomerOrdersFrameOpen()
	local ordersFrame = GetOptionalGlobal("ProfessionsCustomerOrdersFrame")
	return IsFrameShown(ordersFrame)
end

local function GetCustomerOrderStateRefreshBlockReason(self)
	if self.IsProtectedActionRestricted and self:IsProtectedActionRestricted() then
		return "restricted"
	end
	if self.IsPlayerCastingOrChanneling and self:IsPlayerCastingOrChanneling() then
		return "player-casting"
	end
	if not IsCustomerOrdersFrameOpen() then
		return "orders-ui-closed"
	end
	return nil
end

local function ShouldRetryCustomerOrderStateRefresh(blockReason)
	return blockReason == "restricted" or blockReason == "player-casting"
end

local function GetOrderSound()
	local soundKey = AF.db and AF.db.orderNotificationSound or ORDER_SOUND_FALLBACK
	return SOUNDKIT and (SOUNDKIT[soundKey] or SOUNDKIT[ORDER_SOUND_FALLBACK])
end

local function GetOrderSoundChannel()
	local channel = AF.db and AF.db.orderNotificationChannel
	return channel and channel ~= "" and channel ~= "default" and channel or nil
end

local function CanShowOrderNotification(self)
	if self:IsProtectedActionRestricted() then
		return false
	end
	if self:IsInUnavailableActivity() then
		return false
	end
	return true
end

local function CountPersonalOrders()
	if not C_CraftingOrders or not C_CraftingOrders.GetPersonalOrdersInfo then
		return 0, {}
	end
	local infos = C_CraftingOrders.GetPersonalOrdersInfo() or {}
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

local function GetCurrentOrderFallbackDetails(rows)
	local details = {}
	for _, row in ipairs(rows or {}) do
		if row.current and row.professionName and row.professionName ~= "" then
			details.professionName = row.professionName
			details.itemName = row.professionName
			return details
		end
	end
	return details
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
		itemName = name or itemName
		itemLink = link or itemLink
		itemQuality = tonumber(quality) or itemQuality
		itemIcon = tonumber(icon) or itemIcon or C_Item.GetItemIconByID(itemID)
		if not name then
			pcall(C_Item.RequestLoadItemDataByID, itemID)
		end
	end
	return itemID, itemName, itemLink, itemQuality, itemIcon
end

local function IsOrderNotificationItemDataLoaded(details)
	local itemID = tonumber(details and details.itemID) or AF:GetItemIDFromLink(details and details.itemLink)
	if not itemID then
		return true
	end
	local name, link = C_Item.GetItemInfo(itemID)
	if name and link then
		return true
	end
	pcall(C_Item.RequestLoadItemDataByID, itemID)
	return false
end

local function SetItemTextColor(fontString, quality)
	quality = tonumber(quality)
	if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
		local color = ITEM_QUALITY_COLORS[quality]
		fontString:SetTextColor(color.r or 1, color.g or 1, color.b or 1)
	elseif quality and C_Item and C_Item.GetItemQualityColor then
		local r, g, b = C_Item.GetItemQualityColor(quality)
		fontString:SetTextColor(r or 1, g or 1, b or 1)
	else
		fontString:SetTextColor(1, 1, 1)
	end
end

local function GetItemQualityColorCode(quality)
	quality = tonumber(quality)
	local r, g, b = 1, 1, 1
	if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
		local color = ITEM_QUALITY_COLORS[quality]
		r, g, b = color.r or r, color.g or g, color.b or b
	elseif quality and C_Item and C_Item.GetItemQualityColor then
		r, g, b = C_Item.GetItemQualityColor(quality)
	end
	return string.format("|cff%02x%02x%02x", math.floor((r or 1) * 255 + 0.5), math.floor((g or 1) * 255 + 0.5), math.floor((b or 1) * 255 + 0.5))
end

local function GetOrderTooltipItemLine(AF, row)
	local itemID, itemName, itemLink, itemQuality, itemIcon = GetOrderNotificationItemInfo(row)
	row.itemID = row.itemID or itemID
	row.itemName = row.itemName or itemName
	row.itemLink = row.itemLink or itemLink
	row.itemQuality = row.itemQuality or itemQuality
	row.itemIcon = row.itemIcon or itemIcon
	if not itemName or itemName == "" or not itemIcon or (itemID and not itemQuality) then
		if itemID then
			pcall(C_Item.RequestLoadItemDataByID, itemID)
			AF.pendingOrderTooltipItemData = true
		end
		return nil
	end
	local icon = CreateTextureMarkup and CreateTextureMarkup(itemIcon, 16, 16, 16, 16, 0, 1, 0, 1) or ""
	local color = GetItemQualityColorCode(itemQuality)
	return string.format("%s%s%s|r", icon ~= "" and (icon .. " ") or "", color, itemName)
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
	elseif quality and C_Item and C_Item.GetItemQualityColor then
		local r, g, b = C_Item.GetItemQualityColor(quality)
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
	local itemLink = details.itemLink and details.itemLink ~= "" and details.itemLink or nil
	local itemName = details.itemName and details.itemName ~= "" and details.itemName or nil
	local customerName = details.customerName and details.customerName ~= "" and details.customerName or nil
	local crafterName = details.crafterName and details.crafterName ~= "" and details.crafterName or nil
	local professionName = details.professionName and details.professionName ~= "" and details.professionName or nil
	return {
		notificationType = details.notificationType,
		itemID = tonumber(details.itemID),
		orderID = details.orderID,
		itemLink = itemLink,
		itemName = itemName,
		itemQuality = tonumber(details.itemQuality),
		itemIcon = tonumber(details.itemIcon),
		commissionCopper = tonumber(details.commissionCopper),
		customerName = customerName,
		crafterName = crafterName,
		professionName = professionName,
	}
end

local function GetCustomerOrderKey(order)
	if type(order) ~= "table" then
		return nil
	end
	if order.orderID then
		return tostring(order.orderID)
	end
	return table.concat({
		tostring(order.itemID or ""),
		tostring(order.spellID or ""),
		tostring(order.orderType or ""),
		tostring(order.expirationTime or ""),
		tostring(order.crafterName or ""),
	}, ":")
end

local function IsCustomerOrderFulfilled(order)
	return type(order) == "table"
		and Enum
		and Enum.CraftingOrderState
		and order.orderState == Enum.CraftingOrderState.Fulfilled
end

local function IsPatronOrder(order)
	return type(order) == "table"
		and Enum
		and Enum.CraftingOrderType
		and order.orderType == Enum.CraftingOrderType.Npc
end

local function IsOwnOrderCustomer(self, customerName)
	customerName = self:NormalizeName(customerName)
	if not customerName then
		return false
	end
	if customerName == self:NormalizeName(self.playerName or self:GetPlayerFullName()) then
		return true
	end
	return self:IsOwnArtisanCharacter(customerName)
end

local function IsSelfNotificationSender(self, senderName)
	senderName = self:NormalizeName(senderName)
	if not senderName then
		return false
	end
	if senderName == self:NormalizeName(self.playerName or self:GetPlayerFullName()) then
		return true
	end
	return self:IsOwnArtisanCharacter(senderName)
end

local function GetCustomerOrderStateValue(order)
	return type(order) == "table" and tostring(order.orderState or "") or ""
end

local function HasOrderItemDetails(details)
	return type(details) == "table"
		and (tonumber(details.itemID) or (details.itemLink and details.itemLink ~= "") or (details.itemName and details.itemName ~= "") or tonumber(details.itemIcon)) ~= nil
end

local function MergeOrderDetails(primary, fallback)
	local details = CopyOrderDetails(primary)
	fallback = CopyOrderDetails(fallback)
	for key, value in pairs(fallback) do
		if details[key] == nil then
			details[key] = value
		end
	end
	return details
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

local function FillOrderDetailsFromRecipeInfo(details, recipeInfo)
	if type(recipeInfo) ~= "table" then
		return details
	end
	details.itemID = details.itemID or tonumber(recipeInfo.itemID)
	details.itemLink = details.itemLink or recipeInfo.hyperlink
	details.itemName = details.itemName or recipeInfo.name
	details.itemIcon = details.itemIcon or recipeInfo.icon
	return FillOrderDetailsFromItemInfo(details)
end

local function FillOrderDetailsFromOrderInfo(details, order)
	if type(order) ~= "table" then
		return FillOrderDetailsFromItemInfo(details)
	end
	details.itemID = details.itemID or tonumber(order.itemID)
	details.itemLink = details.itemLink or order.outputItemHyperlink or order.recraftItemHyperlink
	details.itemID = details.itemID or AF:GetItemIDFromLink(details.itemLink)
	details.itemName = details.itemName or (details.itemID and AF:GetItemName(details.itemID))
	details.itemIcon = details.itemIcon or (details.itemID and C_Item.GetItemIconByID(details.itemID))
	details.commissionCopper = details.commissionCopper or tonumber(order.tipAmount)
	details.customerName = details.customerName or order.customerName
	details.crafterName = details.crafterName or order.crafterName
	if order.skillLineAbilityID and C_TradeSkillUI and C_TradeSkillUI.GetProfessionNameForSkillLineAbility then
		details.professionName = details.professionName or C_TradeSkillUI.GetProfessionNameForSkillLineAbility(order.skillLineAbilityID)
	end
	if order.skillLineAbilityID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfoForSkillLineAbility then
		local okRecipeInfo, recipeInfo = pcall(C_TradeSkillUI.GetRecipeInfoForSkillLineAbility, order.skillLineAbilityID)
		if okRecipeInfo then
			FillOrderDetailsFromRecipeInfo(details, recipeInfo)
		end
	end
	return FillOrderDetailsFromItemInfo(details)
end

local function GetFulfilledOrderDetails(order)
	local details = {
		notificationType = "fulfilled",
		commissionCopper = tonumber(order and order.tipAmount),
		customerName = order and order.customerName,
		crafterName = order and order.crafterName,
		orderID = order and order.orderID,
		itemID = order and tonumber(order.itemID),
		itemLink = order and (order.outputItemHyperlink or order.recraftItemHyperlink),
	}
	return FillOrderDetailsFromOrderInfo(details, order)
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
	if self:QueueOrderNotificationToastUntilItemLoaded(characterName, count, details) then
		return
	end
	self:ShowOrderNotificationToast(characterName, count, details)
end

function AF:NotifyCustomerOrderFulfilled(order, details, sender)
	if IsPatronOrder(order) then
		self:DebugLog("orders", "skip patron fulfilled order=" .. tostring(order and order.orderID or ""))
		return
	end
	if self.db and self.db.hideSelfAltFulfilledNotifications == true and IsSelfNotificationSender(self, sender) then
		self:DebugLog("orders", "skip self alt fulfilled notification order=" .. tostring(order and order.orderID or ""))
		return
	end
	details = CopyOrderDetails(details or GetFulfilledOrderDetails(order))
	details.notificationType = "fulfilled"
	FillOrderDetailsFromOrderInfo(details, order)
	self:DebugLog("orders", string.format("fulfilled order=%s item=%s crafter=%s", tostring(order and order.orderID or ""), tostring(details.itemID or ""), tostring(details.crafterName or "")))
	self:PlayOrderNotificationSound()
	self:ShowOrderNotification(self.playerName or self:GetPlayerFullName(), 1, details)
end

function AF:NotifyPersonalOrder(characterName, count, sender, details)
	characterName = self:NormalizeName(characterName)
	if not characterName then
		return
	end
	local playerName = self:NormalizeName(self.playerName or self:GetPlayerFullName())
	local senderName = self:NormalizeName(sender)
	if characterName == playerName and senderName == playerName then
		return
	end
	if self.db and self.db.hideSelfAltOrderNotifications == true and characterName ~= playerName and IsSelfNotificationSender(self, sender) then
		self:DebugLog("orders", "skip self alt order notification character=" .. tostring(characterName))
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
	if senderName and senderName ~= playerName then
		self.lastOrderNotificationWhisperAt = GetTime and GetTime() or self:Now()
		self.lastOrderNotificationWhisperCharacter = characterName
	end
	self:DebugLog("orders", string.format("notify character=%s count=%s sender=%s item=%s commission=%s customer=%s", tostring(characterName), tostring(count), tostring(sender or ""), tostring(details.itemID or ""), tostring(details.commissionCopper or ""), tostring(details.customerName or "")))
	self:PlayOrderNotificationSound()
	self:ShowOrderNotification(characterName, count, details)
	if self.RefreshCraftingOrderIndicator then
		self:RefreshCraftingOrderIndicator()
	end
end

function AF:QueueOrderNotificationToastUntilItemLoaded(characterName, count, details)
	details = CopyOrderDetails(details)
	local itemID = tonumber(details.itemID) or self:GetItemIDFromLink(details.itemLink)
	if not itemID or IsOrderNotificationItemDataLoaded(details) then
		return false
	end
	self.pendingOrderNotificationToasts = self.pendingOrderNotificationToasts or {}
	table.insert(self.pendingOrderNotificationToasts, {
		characterName = characterName,
		count = count,
		details = details,
	})
	return true
end

function AF:OnOrderNotificationItemDataLoaded(itemID)
	local pending = self.pendingOrderNotificationToasts
	local refreshTooltip = self.pendingOrderTooltipItemData == true
	self.pendingOrderTooltipItemData = nil
	if (not pending or #pending == 0) and not refreshTooltip then
		return
	end
	itemID = tonumber(itemID)
	local remaining = {}
	for _, pendingToast in ipairs(pending or {}) do
		local details = CopyOrderDetails(pendingToast.details)
		local pendingItemID = tonumber(details.itemID) or self:GetItemIDFromLink(details.itemLink)
		if (not itemID or itemID == pendingItemID) and IsOrderNotificationItemDataLoaded(details) then
			FillOrderDetailsFromItemInfo(details)
			local entry = self.altOrderNotifications and self.altOrderNotifications[pendingToast.characterName]
			if entry and (not pendingItemID or tonumber(entry.itemID) == pendingItemID) then
				FillOrderDetailsFromItemInfo(entry)
			end
			self:ShowOrderNotificationToast(pendingToast.characterName, pendingToast.count, details)
		else
			table.insert(remaining, pendingToast)
		end
	end
	self.pendingOrderNotificationToasts = remaining
	if self.RefreshCraftingOrderIndicator then
		self:RefreshCraftingOrderIndicator()
	end
	if refreshTooltip and self.RefreshOpenCraftingOrderIndicatorTooltip then
		self:RefreshOpenCraftingOrderIndicatorTooltip()
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

function AF:HandleFulfilledOrderNotification(parts, sender)
	local orderID = self:DecodeField(parts[3])
	local crafterName = self:DecodeField(parts[6])
	if not crafterName or crafterName == "" then
		crafterName = sender
	end
	local details = {
		notificationType = "fulfilled",
		orderID = orderID,
		itemID = tonumber(parts[4]),
		commissionCopper = tonumber(parts[5]),
		crafterName = crafterName,
		itemName = self:DecodeField(parts[7]),
		itemIcon = tonumber(parts[8]),
		professionName = self:DecodeField(parts[9]),
		itemQuality = tonumber(parts[10]),
	}
	if orderID and orderID ~= "" then
		self.db.customerOrderStates = self.db.customerOrderStates or {}
		self.db.customerOrderStates[tostring(orderID)] = tostring(Enum.CraftingOrderState.Fulfilled)
	end
	self:NotifyCustomerOrderFulfilled({
		orderID = orderID,
		orderState = Enum.CraftingOrderState.Fulfilled,
		itemID = details.itemID,
		tipAmount = details.commissionCopper,
		crafterName = details.crafterName,
	}, details, sender)
end

function AF:SendOrderNotification(characterName, count, details)
	characterName = self:NormalizeName(characterName)
	if not characterName or not self.SendAddon then
		return false
	end
	details = CopyOrderDetails(details)
	FillOrderDetailsFromItemInfo(details)
	local messageTarget = self:GetRememberedArtisanContact(characterName) or characterName
	local payloadParts = {
		"O",
		self.PROTOCOL_VERSION,
		self:EncodeField(characterName),
		tonumber(count) or 1,
		self:Now(),
		tonumber(details.itemID) or "",
		tonumber(details.commissionCopper) or "",
		self:EncodeField(details.customerName or self.playerName or self:GetPlayerFullName()),
		self:EncodeField(details.itemName or ""),
		tonumber(details.itemIcon) or "",
		self:EncodeField(details.professionName or ""),
		tonumber(details.itemQuality) or "",
	}
	self:DebugLog("orders", "send target=" .. tostring(messageTarget) .. " orderTarget=" .. tostring(characterName) .. " item=" .. tostring(details.itemID or ""))
	if self.SendPayloadParts and self:SendPayloadParts(payloadParts, "WHISPER", messageTarget, "NORMAL", "O:" .. characterName) then
		return true
	end
	payloadParts[3] = self:EncodeField(characterName, 48)
	payloadParts[8] = self:EncodeField(details.customerName or self.playerName or self:GetPlayerFullName(), 48)
	payloadParts[9] = self:EncodeField(details.itemName or "", 64)
	payloadParts[11] = self:EncodeField(details.professionName or "", 40)
	for index, value in ipairs(payloadParts) do
		payloadParts[index] = tostring(value or "")
	end
	return self:SendAddon(table.concat(payloadParts, "|"), "WHISPER", messageTarget, "NORMAL", "O:" .. characterName)
end

function AF:SendFulfilledOrderNotification(order, details)
	if IsPatronOrder(order) then
		self:DebugLog("orders", "skip patron fulfilled payload order=" .. tostring(order and order.orderID or ""))
		return false
	end
	if type(order) ~= "table" or not order.customerName or order.customerName == "" then
		return false
	end
	details = CopyOrderDetails(details or GetFulfilledOrderDetails(order))
	details.notificationType = "fulfilled"
	FillOrderDetailsFromOrderInfo(details, order)
	local target = self:NormalizeName(order.customerName)
	if not target then
		return false
	end
	if IsOwnOrderCustomer(self, target) then
		details.crafterName = details.crafterName or self.playerName or self:GetPlayerFullName()
		self:DebugLog("orders", "skip own fulfilled whisper target=" .. tostring(target) .. " order=" .. tostring(order.orderID or ""))
		self:NotifyCustomerOrderFulfilled(order, details, self.playerName or self:GetPlayerFullName())
		return true
	end
	if not self.SendAddon then
		return false
	end
	local payloadParts = {
		"F",
		self.PROTOCOL_VERSION,
		self:EncodeField(order.orderID and tostring(order.orderID) or ""),
		tonumber(details.itemID) or "",
		tonumber(details.commissionCopper) or "",
		self:EncodeField(details.crafterName or self.playerName or self:GetPlayerFullName()),
		self:EncodeField(details.itemName or ""),
		tonumber(details.itemIcon) or "",
		self:EncodeField(details.professionName or ""),
		tonumber(details.itemQuality) or "",
	}
	self:DebugLog("orders", "send fulfilled target=" .. tostring(target) .. " order=" .. tostring(order.orderID or "") .. " item=" .. tostring(details.itemID or ""))
	if self.SendPayloadParts and self:SendPayloadParts(payloadParts, "WHISPER", target, "NORMAL", "F:" .. tostring(order.orderID or "")) then
		return true
	end
	payloadParts[3] = self:EncodeField(order.orderID and tostring(order.orderID) or "", 48)
	payloadParts[6] = self:EncodeField(details.crafterName or self.playerName or self:GetPlayerFullName(), 48)
	payloadParts[7] = self:EncodeField(details.itemName or "", 64)
	payloadParts[9] = self:EncodeField(details.professionName or "", 40)
	for index, value in ipairs(payloadParts) do
		payloadParts[index] = tostring(value or "")
	end
	return self:SendAddon(table.concat(payloadParts, "|"), "WHISPER", target, "NORMAL", "F:" .. tostring(order.orderID or ""))
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
		self:QueueCurrentOrderNotificationFallback(total - previous, rows)
	end
	if self.RefreshCraftingOrderIndicator then
		self:RefreshCraftingOrderIndicator()
	end
end

function AF:QueueCurrentOrderNotificationFallback(count, rows)
	local playerName = self:NormalizeName(self.playerName or self:GetPlayerFullName())
	if not playerName then
		return
	end
	local eventTime = GetTime and GetTime() or self:Now()
	self.currentOrderNotificationFallbackToken = (self.currentOrderNotificationFallbackToken or 0) + 1
	local token = self.currentOrderNotificationFallbackToken
	local details = GetCurrentOrderFallbackDetails(rows)
	C_Timer.After(ORDER_NOTIFICATION_FALLBACK_DELAY_SECONDS, function()
		if AF.currentOrderNotificationFallbackToken ~= token then
			return
		end
		if AF.lastOrderNotificationWhisperCharacter == playerName
			and AF.lastOrderNotificationWhisperAt
			and AF.lastOrderNotificationWhisperAt >= eventTime - 0.25
		then
			return
		end
		AF:DebugLog("orders", string.format("fallback character=%s count=%s profession=%s", tostring(playerName), tostring(count or 1), tostring(details.professionName or "")))
		AF:ShowOrderNotification(playerName, tonumber(count) or 1, details)
	end)
end

function AF:QueueCustomerOrderStateRefresh(reason, delay)
	if not C_CraftingOrders or not C_CraftingOrders.ListMyOrders then
		return
	end
	if reason == "craftingorders_can_request" then
		return
	end
	self.customerOrderStateRefreshToken = (self.customerOrderStateRefreshToken or 0) + 1
	local token = self.customerOrderStateRefreshToken
	C_Timer.After(delay or CUSTOMER_ORDER_REFRESH_DELAY_SECONDS, function()
		if AF.customerOrderStateRefreshToken ~= token then
			return
		end
		local blockReason = GetCustomerOrderStateRefreshBlockReason(AF)
		if blockReason then
			if ShouldRetryCustomerOrderStateRefresh(blockReason) then
				AF:QueueCustomerOrderStateRefresh(reason, CUSTOMER_ORDER_REFRESH_DEFER_DELAY_SECONDS)
			end
			return
		end
		AF:RefreshCustomerOrderStates(reason)
	end)
end

function AF:RefreshCustomerOrderStates(reason)
	if self.customerOrderStateRequestActive or not C_FunctionContainers or not C_FunctionContainers.CreateCallback or not C_CraftingOrders or not C_CraftingOrders.ListMyOrders then
		return
	end
	local blockReason = GetCustomerOrderStateRefreshBlockReason(self)
	if blockReason then
		if ShouldRetryCustomerOrderStateRefresh(blockReason) then
			self:QueueCustomerOrderStateRefresh(reason, CUSTOMER_ORDER_REFRESH_DEFER_DELAY_SECONDS)
		end
		return
	end
	self.customerOrderStateRequestActive = true
	self.customerOrderStateRequestToken = (self.customerOrderStateRequestToken or 0) + 1
	local requestToken = self.customerOrderStateRequestToken
	self.customerOrderStateRefreshOrders = {}
	C_Timer.After(10, function()
		if AF.customerOrderStateRequestActive and AF.customerOrderStateRequestToken == requestToken then
			AF.customerOrderStateRequestActive = nil
			AF.customerOrderStateRefreshOrders = nil
			AF:DebugLog("orders", "customer states timeout reason=" .. tostring(reason or ""))
		end
	end)

	local function Request(offset)
		if not C_FunctionContainers or not C_FunctionContainers.CreateCallback or not C_CraftingOrders or not C_CraftingOrders.ListMyOrders then
			AF.customerOrderStateRequestActive = nil
			AF.customerOrderStateRefreshOrders = nil
			AF:DebugLog("orders", "customer states unavailable reason=" .. tostring(reason or ""))
			return
		end
		local callback
		callback = C_FunctionContainers.CreateCallback(function(result, expectMoreRows)
			if not AF.customerOrderStateRequestActive or AF.customerOrderStateRequestToken ~= requestToken then
				return
			end
			if result and Enum and Enum.CraftingOrderResult and result ~= Enum.CraftingOrderResult.Ok then
				AF.customerOrderStateRequestActive = nil
				AF.customerOrderStateRefreshOrders = nil
				AF:DebugLog("orders", string.format("customer states failed result=%s reason=%s", tostring(result), tostring(reason or "")))
				return
			end
			local blockReason = GetCustomerOrderStateRefreshBlockReason(AF)
			if blockReason then
				AF.customerOrderStateRequestActive = nil
				AF.customerOrderStateRefreshOrders = nil
				if ShouldRetryCustomerOrderStateRefresh(blockReason) then
					AF:QueueCustomerOrderStateRefresh(reason, CUSTOMER_ORDER_REFRESH_DEFER_DELAY_SECONDS)
				end
				return
			end
			local orders = C_CraftingOrders and C_CraftingOrders.GetMyOrders and C_CraftingOrders.GetMyOrders() or {}
			for index = (tonumber(offset) or 0) + 1, #orders do
				table.insert(AF.customerOrderStateRefreshOrders, orders[index])
			end
			if expectMoreRows and #orders > (tonumber(offset) or 0) then
				Request(#orders)
				return
			end
			AF.customerOrderStateRequestActive = nil
			AF:ProcessCustomerOrderStates(AF.customerOrderStateRefreshOrders, result, reason)
			AF.customerOrderStateRefreshOrders = nil
		end)
		local ok = pcall(C_CraftingOrders.ListMyOrders, {
			offset = tonumber(offset) or 0,
			callback = callback,
			primarySort = { sortType = Enum.CraftingOrderSortType.ItemName, reversed = false },
			secondarySort = { sortType = Enum.CraftingOrderSortType.TimeRemaining, reversed = false },
		})
		if not ok then
			AF.customerOrderStateRequestActive = nil
			AF.customerOrderStateRefreshOrders = nil
			AF:DebugLog("orders", "customer states request failed reason=" .. tostring(reason or ""))
		end
	end

	Request(0)
end

function AF:ProcessCustomerOrderStates(orders, result, reason)
	self.db.customerOrderStates = self.db.customerOrderStates or {}
	local initialized = self.customerOrderStatesInitialized == true
	local seen = {}
	for _, order in ipairs(orders or {}) do
		if IsPatronOrder(order) then
			self:DebugLog("orders", "skip patron state order=" .. tostring(order.orderID or ""))
		else
			local key = GetCustomerOrderKey(order)
			if key then
				seen[key] = true
				local previousState = self.db.customerOrderStates[key]
				local currentState = GetCustomerOrderStateValue(order)
				if (initialized or previousState ~= nil)
					and IsCustomerOrderFulfilled(order)
					and previousState
					and previousState ~= ""
					and previousState ~= currentState
				then
					self:NotifyCustomerOrderFulfilled(order)
				end
				self.db.customerOrderStates[key] = currentState
			end
		end
	end
	for key in pairs(self.db.customerOrderStates) do
		if not seen[key] then
			self.db.customerOrderStates[key] = nil
		end
	end
	self.customerOrderStatesInitialized = true
	self:DebugLog("orders", string.format("customer states result=%s reason=%s count=%s", tostring(result or ""), tostring(reason or ""), tostring(#(orders or {}))))
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
			self:NotifyPersonalOrder(target, 1, self.playerName or self:GetPlayerFullName(), details)
		end
		self:SendOrderNotification(target, 1, details)
	end
	if self.QueueCustomerOrderStateRefresh then
		self:QueueCustomerOrderStateRefresh("placement-response", 2)
	end
end

function AF:OnFulfillOrderResponse(result, orderID)
	local key = orderID and tostring(orderID) or nil
	local pending = key and self.pendingFulfilledOrderNotifications and self.pendingFulfilledOrderNotifications[key]
	if key and self.pendingFulfilledOrderNotifications then
		self.pendingFulfilledOrderNotifications[key] = nil
	end
	if result ~= Enum.CraftingOrderResult.Ok or not pending then
		return
	end
	if IsPatronOrder(pending.order) then
		self:DebugLog("orders", "skip patron fulfilled send order=" .. tostring(orderID or ""))
		return
	end
	self:SendFulfilledOrderNotification(pending.order, pending.details)
end

function AF:CapturePendingFulfilledOrder(orderID)
	if not C_CraftingOrders or not C_CraftingOrders.GetClaimedOrder then
		return
	end
	local order = C_CraftingOrders.GetClaimedOrder()
	if type(order) ~= "table" or tostring(order.orderID or "") ~= tostring(orderID or "") then
		return
	end
	if IsPatronOrder(order) then
		self:DebugLog("orders", "skip patron pending fulfilled order=" .. tostring(orderID or ""))
		return
	end
	self.pendingFulfilledOrderNotifications = self.pendingFulfilledOrderNotifications or {}
	self.pendingFulfilledOrderNotifications[tostring(orderID)] = {
		order = order,
		details = GetFulfilledOrderDetails(order),
	}
	self:DebugLog("orders", "pending fulfilled order=" .. tostring(orderID) .. " customer=" .. tostring(order.customerName or ""))
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
				details.itemName = details.itemID and self:GetItemName(details.itemID) or rawget(outputItemInfo, "itemName")
				details.itemIcon = outputItemInfo.icon or (details.itemID and C_Item.GetItemIconByID(details.itemID))
			end
		end
		FillOrderDetailsFallback(details, form, recipeSchematic)
	elseif orderInfo.skillLineAbilityID then
		details.professionName = C_TradeSkillUI.GetProfessionNameForSkillLineAbility(orderInfo.skillLineAbilityID)
		local okRecipeInfo, recipeInfo = pcall(C_TradeSkillUI.GetRecipeInfoForSkillLineAbility, orderInfo.skillLineAbilityID)
		if okRecipeInfo then
			local recipeID = tonumber(recipeInfo and recipeInfo.recipeID)
			if recipeID then
				local okOutput, outputItemInfo = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID, orderInfo.craftingReagentItems, orderInfo.recraftItem, orderInfo.minCraftingQualityID)
				if okOutput and type(outputItemInfo) == "table" then
					details.itemLink = details.itemLink or outputItemInfo.hyperlink
					details.itemID = details.itemID or tonumber(outputItemInfo.itemID) or self:GetItemIDFromLink(outputItemInfo.hyperlink)
					details.itemName = details.itemName or rawget(outputItemInfo, "itemName")
					details.itemIcon = details.itemIcon or outputItemInfo.icon
				end
			end
			FillOrderDetailsFromRecipeInfo(details, recipeInfo)
		end
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
	hooksecurefunc(C_CraftingOrders, "PlaceNewOrder", function(orderInfo)
		if type(orderInfo) == "table"
			and orderInfo.orderType == Enum.CraftingOrderType.Personal
			and orderInfo.orderTarget
			and orderInfo.orderTarget ~= ""
		then
			local target = AF:NormalizeName(orderInfo.orderTarget)
			local capturedDetails = AF:CapturePersonalOrderDetails(orderInfo)
			if target == AF.pendingPersonalOrderTarget and HasOrderItemDetails(AF.pendingPersonalOrderDetails) and not HasOrderItemDetails(capturedDetails) then
				AF.pendingPersonalOrderDetails = MergeOrderDetails(AF.pendingPersonalOrderDetails, capturedDetails)
			else
				AF.pendingPersonalOrderDetails = MergeOrderDetails(capturedDetails, target == AF.pendingPersonalOrderTarget and AF.pendingPersonalOrderDetails or nil)
			end
			AF.pendingPersonalOrderTarget = target
			AF:DebugLog("orders", "pending target=" .. tostring(AF.pendingPersonalOrderTarget))
		else
			AF.pendingPersonalOrderTarget = nil
			AF.pendingPersonalOrderDetails = nil
		end
	end)
	if C_CraftingOrders.FulfillOrder then
		hooksecurefunc(C_CraftingOrders, "FulfillOrder", function(orderID)
			AF:CapturePendingFulfilledOrder(orderID)
		end)
	end
	self:InitializeCustomerOrderFormHook()
	self:InitializeCraftingOrderIndicator()
	self.db.orderNotifications = self.db.orderNotifications or {}
	self.altOrderNotifications = self.db.orderNotifications
	self:OnPersonalOrderCountsUpdated()
	self:QueueCustomerOrderStateRefresh("init", 2)
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

function AF:DevNotifyFulfilledOrder(crafterName)
	self.db.debugEnabled = true
	self.db.devEnabled = true
	local _, itemName, itemLink, itemQuality, itemIcon = GetOrderNotificationItemInfo({ itemID = DEV_ORDER_ITEM_ID, itemName = "Masterwork Sin'dorei Band" })
	local devCrafterName = crafterName and crafterName ~= "" and crafterName or GetRandomDevCustomerName()
	local commissionCopper = GetRandomDevCommission()
	self:NotifyCustomerOrderFulfilled({
		orderID = "dev-fulfilled",
		orderState = Enum.CraftingOrderState.Fulfilled,
		itemID = DEV_ORDER_ITEM_ID,
		tipAmount = commissionCopper,
		crafterName = devCrafterName,
	}, {
		notificationType = "fulfilled",
		itemID = DEV_ORDER_ITEM_ID,
		itemName = itemName or "Masterwork Sin'dorei Band",
		itemLink = itemLink,
		itemQuality = itemQuality,
		itemIcon = itemIcon,
		commissionCopper = commissionCopper,
		crafterName = devCrafterName,
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
	self:DebugLog("orders", self:Text("DEBUG_ORDERS_STATE", tostring(self.currentPersonalOrderCount or 0), tostring(self.lastOrderNotificationSender or "")))
	for _, row in ipairs(self:GetKnownOrderRows()) do
		self:DebugLog("orders", self:Text(
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

	frame.IconBorder:Hide()

	frame.Title:SetJustifyH("LEFT")
	frame.Title:SetWordWrap(false)

	frame.ItemName:SetJustifyH("LEFT")
	frame.ItemName:SetWordWrap(false)

	frame.Meta:SetJustifyH("LEFT")
	frame.Meta:SetTextColor(0.82, 0.82, 0.82)
	frame.Meta:SetWordWrap(false)

	frame.Commission:SetJustifyH("LEFT")
	frame.Commission:SetTextColor(1, 0.82, 0)
	frame.Commission:SetWordWrap(false)

	frame:SetScript("OnEnter", function(toast)
		toast.paused = true
		toast.elapsed = TOAST_FADE_IN_SECONDS
		toast:SetAlpha(1)
		if toast.itemLink or toast.itemID then
			GameTooltip:SetOwner(toast, "ANCHOR_TOP")
			AF:HideEmbeddedItemTooltip(GameTooltip)
			if toast.itemLink then
				GameTooltip:SetHyperlink(toast.itemLink)
			elseif GameTooltip.SetItemByID then
				GameTooltip:SetItemByID(toast.itemID)
			else
				GameTooltip:SetHyperlink("item:" .. tostring(toast.itemID))
			end
			AF:HideEmbeddedItemTooltip(GameTooltip)
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
		self.orderNotificationToastPool = CreateFramePool("Button", UIParent, "ArtisanFinderOrderNotificationToastTemplate", ResetOrderNotificationToast, nil, function(frame)
			AF:InitializeOrderNotificationToast(frame)
		end)
	end
	return self.orderNotificationToastPool
end

function AF:GetOrderNotificationAnchor()
	if self.orderNotificationAnchor then
		return self.orderNotificationAnchor
	end
	local anchor = CreateFrame("Frame", "ArtisanFinderOrderNotificationAnchor", UIParent, "ArtisanFinderOrderNotificationAnchorTemplate")
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
	local isFulfilled = details.notificationType == "fulfilled"
	frame.itemID = itemID
	frame.itemLink = itemLink
	frame.elapsed = 0
	frame.paused = false
	frame:SetAlpha(0)
	frame:SetScale(self:GetOrderNotificationScale())
	frame.Icon:SetTexture(itemIcon or "Interface\\Icons\\INV_Misc_Note_01")
	SetToastIconQuality(frame, itemQuality, itemLink or itemID)
	frame.Title:SetText(self:Text(isFulfilled and "ORDER_FULFILLED_NOTIFICATION_TITLE" or "ORDER_NOTIFICATION_TITLE"))
	frame.ItemName:SetText(itemName or details.itemName or details.professionName or self:Text(isFulfilled and "ORDER_FULFILLED_NOTIFICATION_UNKNOWN_ITEM" or "ORDER_NOTIFICATION_UNKNOWN_ITEM"))
	SetItemTextColor(frame.ItemName, itemQuality)
	if isFulfilled then
		frame.Meta:SetText(self:Text(
			"ORDER_FULFILLED_NOTIFICATION_META",
			FormatOrderCustomer(self, details.crafterName or self:Text("UNKNOWN_CRAFTER"))
		))
		frame.Commission:SetText(self:Text("ORDER_FULFILLED_NOTIFICATION_ACTION"))
	else
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
	self.craftingOrderTooltipOwner = owner or GetCraftingOrderFrame() or UIParent
	if not GameTooltip:IsShown() then
		GameTooltip:SetOwner(self.craftingOrderTooltipOwner, "ANCHOR_LEFT")
		GameTooltip:SetText(GetCraftingOrdersTitle(self), 1, 0.82, 0)
	end
	GameTooltip_AddBlankLineToTooltip(GameTooltip)
	GameTooltip_AddNormalLine(GameTooltip, "ArtisanFinder", false)
	for _, row in ipairs(rows) do
		local count = tonumber(row.count) or 0
		if count > 0 then
			local name = row.alt and self:GetFullDisplayPlayerName(row.characterName) or self:GetDisplayPlayerName(row.characterName)
			local profession = row.professionName and row.professionName ~= "" and (" - " .. row.professionName) or ""
			GameTooltip_AddNormalLine(GameTooltip, self:Text("ORDER_TOOLTIP_ROW", name, profession, count), false)
			local itemLine = GetOrderTooltipItemLine(self, row)
			if itemLine then
				GameTooltip:AddLine("  " .. itemLine, 1, 1, 1, true)
			elseif HasOrderItemDetails(row) then
				GameTooltip:AddLine("  " .. self:Text("ITEM_FALLBACK"), 0.65, 0.65, 0.65, true)
			end
		end
	end
	GameTooltip:Show()
end

function AF:RefreshOpenCraftingOrderIndicatorTooltip()
	if not GameTooltip or not GameTooltip:IsShown() or not self.craftingOrderTooltipOwner then
		return
	end
	GameTooltip:ClearLines()
	GameTooltip:SetOwner(self.craftingOrderTooltipOwner, "ANCHOR_LEFT")
	GameTooltip:SetText(GetCraftingOrdersTitle(self), 1, 0.82, 0)
	self:AddCraftingOrderIndicatorTooltip(self.craftingOrderTooltipOwner)
end

function AF:RefreshCraftingOrderIndicator()
	self:InitializeCraftingOrderIndicator()
	local frame = GetCraftingOrderFrame()
	if not frame then
		return
	end
	local currentTotal, altTotal = GetOrderTotals(self)
	local hasAlt = altTotal > 0
	local icon = frame.Icon or GetOptionalGlobal("MiniMapCraftingOrderIcon")
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
