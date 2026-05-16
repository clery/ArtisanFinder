local _, AF = ...

local SORT_MODES = {
	{ key = "best", label = "Best" },
	{ key = "price", label = "Price" },
	{ key = "quality", label = "Quality" },
	{ key = "recent", label = "Recent" },
}

local ROW_HEIGHT = 50

local function GetAgeText(now, updatedAt)
	local age = math.max(0, now - (updatedAt or now))
	if age < 60 then
		return "just now"
	end
	if age < 3600 then
		return math.floor(age / 60) .. "m ago"
	end
	return math.floor(age / 3600) .. "h ago"
end

local function CreateCustomerRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(332, ROW_HEIGHT)
	AF:StyleListRow(row)
	row:EnableMouse(true)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.name:SetPoint("TOPLEFT", 8, -5)
	row.name:SetPoint("RIGHT", -6, 0)
	row.name:SetJustifyH("LEFT")

	row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
	row.detail:SetPoint("RIGHT", -6, 0)
	row.detail:SetJustifyH("LEFT")

	row.capability = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.capability:SetPoint("TOPLEFT", row.detail, "BOTTOMLEFT", 0, -2)
	row.capability:SetPoint("RIGHT", -6, 0)
	row.capability:SetJustifyH("LEFT")

	row:SetScript("OnClick", function(buttonFrame, button)
		if button == "RightButton" and buttonFrame.entry then
			AF:ShowCustomerMenu(buttonFrame.entry, buttonFrame)
		end
	end)

	return row
end

function AF:InitializeCustomerUI()
	self.customerRows = {}
	self.customerSortIndex = self.customerSortIndex or 1
	self:AttachCustomerUI()
end

function AF:AttachCustomerUI()
	if self.customerFrame or not ProfessionsCustomerOrdersFrame or not ProfessionsCustomerOrdersFrame.Form then
		return
	end

	local parent = ProfessionsCustomerOrdersFrame.Form
	local frame = CreateFrame("Frame", "ArtisanFinderCustomerFrame", parent, "BackdropTemplate")
	frame:SetSize(368, 426)
	frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 8, -2)
	self:ApplyProfessionPanel(frame)
	frame:Hide()

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", 14, -12)
	frame.title:SetText("ArtisanFinder")

	frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.status:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -7)
	frame.status:SetPoint("RIGHT", -14, 0)
	frame.status:SetJustifyH("LEFT")
	frame.status:SetText("Select an order item.")
	frame.divider = self:AddDivider(frame, frame.status, -8)

	frame.search = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
	frame.search:SetSize(176, 20)
	frame.search:SetPoint("TOPLEFT", frame.divider, "BOTTOMLEFT", 0, -8)
	frame.search:SetAutoFocus(false)
	frame.search:SetScript("OnTextChanged", function()
		SearchBoxTemplate_OnTextChanged(frame.search)
		AF:RefreshCustomerResults()
	end)

	frame.sort = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.sort:SetSize(92, 22)
	frame.sort:SetPoint("LEFT", frame.search, "RIGHT", 8, 0)
	frame.sort:SetText("Sort: " .. SORT_MODES[self.customerSortIndex or 1].label)
	frame.sort:SetScript("OnClick", function()
		AF.customerSortIndex = (AF.customerSortIndex or 1) + 1
		if AF.customerSortIndex > #SORT_MODES then
			AF.customerSortIndex = 1
		end
		frame.sort:SetText("Sort: " .. SORT_MODES[AF.customerSortIndex].label)
		AF:RefreshCustomerResults()
	end)

	frame.refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.refresh:SetSize(58, 22)
	frame.refresh:SetPoint("LEFT", frame.sort, "RIGHT", 6, 0)
	frame.refresh:SetText("Refresh")
	frame.refresh:SetScript("OnClick", function()
		AF:RefreshCustomerQuery(true)
	end)

	frame.scroll = CreateFrame("ScrollFrame", "ArtisanFinderCustomerScrollFrame", frame, "UIPanelScrollFrameTemplate")
	frame.scroll:SetPoint("TOPLEFT", frame.search, "BOTTOMLEFT", 0, -9)
	frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 14)
	frame.scroll:SetFrameLevel(frame:GetFrameLevel() + 2)
	frame.content = CreateFrame("Frame", nil, frame.scroll)
	frame.content:SetSize(332, 1)
	frame.scroll:SetScrollChild(frame.content)
	frame.scrollInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.scrollInset:SetPoint("TOPLEFT", frame.scroll, "TOPLEFT", -4, 4)
	frame.scrollInset:SetPoint("BOTTOMRIGHT", frame.scroll, "BOTTOMRIGHT", 23, -4)
	frame.scrollInset:SetFrameLevel(frame:GetFrameLevel() + 1)
	self:ApplyProfessionInset(frame.scrollInset)

	frame.menuBlocker = CreateFrame("Button", "ArtisanFinderCustomerMenuBlocker", UIParent)
	frame.menuBlocker:SetAllPoints(UIParent)
	frame.menuBlocker:SetFrameStrata("FULLSCREEN_DIALOG")
	frame.menuBlocker:EnableMouse(true)
	frame.menuBlocker:RegisterForClicks("AnyUp")
	frame.menuBlocker:Hide()
	frame.menuBlocker:SetScript("OnClick", function()
		AF:HideCustomerMenu()
	end)

	frame.menu = CreateFrame("Frame", "ArtisanFinderCustomerMenu", UIParent, "BackdropTemplate")
	frame.menu:SetSize(136, 96)
	frame.menu:SetFrameStrata("FULLSCREEN_DIALOG")
	frame.menu:SetFrameLevel(frame.menuBlocker:GetFrameLevel() + 10)
	self:ApplyProfessionPanel(frame.menu)
	frame.menu:Hide()

	frame.menu.whisper = CreateFrame("Button", nil, frame.menu, "UIPanelButtonTemplate")
	frame.menu.whisper:SetSize(112, 22)
	frame.menu.whisper:SetPoint("TOP", 0, -10)
	frame.menu.whisper:SetText("Whisper")
	frame.menu.whisper:SetScript("OnClick", function()
		if frame.menu.entry then
			AF:OpenWhisper(frame.menu.entry.target or frame.menu.entry.name, AF:GetCrafterWhisperMessage(frame.menu.entry))
		end
		AF:HideCustomerMenu()
	end)

	frame.menu.personal = CreateFrame("Button", nil, frame.menu, "UIPanelButtonTemplate")
	frame.menu.personal:SetSize(112, 22)
	frame.menu.personal:SetPoint("TOP", frame.menu.whisper, "BOTTOM", 0, -4)
	frame.menu.personal:SetText("Personal Order")
	frame.menu.personal:SetScript("OnClick", function()
		if frame.menu.entry then
			AF:FillPersonalOrder(frame.menu.entry)
		end
		AF:HideCustomerMenu()
	end)

	frame.menu.link = CreateFrame("Button", nil, frame.menu, "UIPanelButtonTemplate")
	frame.menu.link:SetSize(112, 22)
	frame.menu.link:SetPoint("TOP", frame.menu.personal, "BOTTOM", 0, -4)
	frame.menu.link:SetText("Profession")
	frame.menu.link:SetScript("OnClick", function()
		if frame.menu.entry then
			AF:OpenCrafterProfession(frame.menu.entry)
		end
		AF:HideCustomerMenu()
	end)

	self.customerFrame = frame
	frame:SetScript("OnShow", function()
		frame.elapsed = 0
		AF:RefreshCustomerQuery()
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		frame.elapsed = (frame.elapsed or 0) + elapsed
		if frame.elapsed >= 1.5 then
			frame.elapsed = 0
			AF:RefreshCustomerQuery()
		end
	end)
	parent:HookScript("OnShow", function()
		AF.customerFrame:Show()
		AF:RefreshCustomerQuery()
	end)
	parent:HookScript("OnHide", function()
		AF.customerFrame:Hide()
		AF:HideCustomerMenu()
	end)

	if parent:IsShown() then
		frame:Show()
		self:RefreshCustomerQuery()
	end
end

function AF:HideCustomerMenu()
	local frame = self.customerFrame
	if not frame then
		return
	end
	if frame.menu then
		frame.menu:Hide()
	end
	if frame.menuBlocker then
		frame.menuBlocker:Hide()
	end
end

function AF:ShowCustomerMenu(entry, owner)
	local menu = self.customerFrame and self.customerFrame.menu
	if not menu then
		return
	end
	menu.entry = entry
	if entry.professionLink then
		menu.link:Enable()
	else
		menu.link:Disable()
	end
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", owner, "TOPRIGHT", 2, 0)
	self.customerFrame.menuBlocker:Show()
	menu:Show()
end

function AF:GetCustomerOrderItemContext()
	local form = ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
	if not form then
		return nil
	end

	local transaction = form.transaction
	local recipeID
	local itemID
	local professionID

	if transaction and transaction.GetRecipeID then
		local ok, value = pcall(transaction.GetRecipeID, transaction)
		if ok then
			recipeID = value
		end
	end
	recipeID = recipeID or (transaction and transaction.recipeID)
	if transaction and transaction.GetRecipeSchematic then
		local ok, schematic = pcall(transaction.GetRecipeSchematic, transaction)
		if ok and schematic then
			recipeID = recipeID or schematic.recipeID
		end
	end

	if not recipeID and form.GetRecipeInfo then
		local ok, recipeInfo = pcall(form.GetRecipeInfo, form)
		if ok and recipeInfo then
			recipeID = recipeInfo.recipeID
		end
	end

	if recipeID and C_TradeSkillUI then
		local ok, outputs = pcall(function()
			return self:GetRecipeOutputItemIDs(recipeID)
		end)
		if ok and outputs then
			for outputItemID in pairs(outputs) do
				if not itemID or tonumber(outputItemID) < tonumber(itemID) then
					itemID = outputItemID
				end
			end
		end
		if C_TradeSkillUI.GetProfessionInfoByRecipeID then
			local okProfession, professionInfo = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeID)
			if okProfession and professionInfo then
				professionID = professionInfo.profession or professionInfo.professionID or professionInfo.skillLineID
			end
		end
	end

	return itemID and {
		itemID = itemID,
		itemName = self:GetDisplayItemName(itemID),
		recipeID = recipeID,
		professionID = professionID or 0,
	} or nil
end

function AF:ClearDebugSelfResults(itemID)
	local cache = self.db.customerCache[tostring(itemID or "")]
	if not cache then
		return
	end
	for key, entry in pairs(cache) do
		if entry.debug then
			cache[key] = nil
		end
	end
end

function AF:InjectDebugSelfResult(itemID, professionID)
	self:ClearDebugSelfResults(itemID)
	if not self.db.debugSelfResults then
		return
	end
	if not self.currentCustomerQueryToken then
		return
	end

	local item = self.db.artisanProfile.items[tostring(itemID or "")]
	if not item then
		return
	end
	if professionID and professionID ~= 0 and tonumber(item.professionID) ~= tonumber(professionID) then
		return
	end

	local basePriceCopper, freeCommission, note = self:GetItemPrice(itemID, item.professionID)
	local itemKey = tostring(itemID)
	local now = self:Now()
	self.db.customerCache[itemKey] = self.db.customerCache[itemKey] or {}
	for i = 1, 50 do
		local isFree = i % 7 == 0 or freeCommission
		self.db.customerCache[itemKey]["__debug_self_" .. i] = {
			name = (self.playerName or self:GetPlayerFullName()) .. " Debug " .. i,
			target = self.playerName or self:GetPlayerFullName(),
			itemID = itemID,
			professionID = item.professionID,
			professionName = item.professionName or self:GetProfessionName(item.professionID),
			priceCopper = isFree and 0 or ((tonumber(basePriceCopper) or 0) + (i * 10000)),
			freeCommission = isFree,
			note = (note ~= "" and note or "Debug crafter") .. " #" .. i,
			recipeID = item.recipeID,
			recipeDifficulty = item.recipeDifficulty,
			totalSkill = tonumber(item.totalSkill) and (tonumber(item.totalSkill) + (i % 9) - 4) or nil,
			quality = tonumber(item.quality) and math.max(1, tonumber(item.quality) - (i % 2)) or nil,
			concentrationQuality = tonumber(item.concentrationQuality) and math.min(5, tonumber(item.concentrationQuality) + (i % 3 == 0 and 0 or -1)) or nil,
			concentrationCost = item.concentrationCost,
			professionLink = item.professionLink,
			updatedAt = now,
			verifiedAt = now,
			lastQueryToken = self.currentCustomerQueryToken,
			lastQueryAt = self.lastQueryAt,
			debug = true,
		}
	end
end

function AF:RefreshCustomerQuery(force)
	self:AttachCustomerUI()
	local frame = self.customerFrame
	if not frame or not frame:IsShown() then
		return
	end

	local context = self:GetCustomerOrderItemContext()
	if not context then
		self.currentCustomerItemID = nil
		self.currentCustomerItemName = nil
		self.currentCustomerProfessionID = nil
		self.currentCustomerQueryToken = nil
		self.currentCustomerQueryItemID = nil
		self.currentCustomerQueryProfessionID = nil
		self:RefreshCustomerResults("Select an order item.")
		return
	end

	local changed = self.currentCustomerItemID ~= context.itemID or self.currentCustomerProfessionID ~= context.professionID
	self.currentCustomerItemID = context.itemID
	self.currentCustomerItemName = context.itemName
	self.currentCustomerProfessionID = context.professionID

	if changed or force or not self.currentCustomerQueryToken then
		self:BroadcastQuery(context.itemID, context.professionID)
	end
	self:InjectDebugSelfResult(context.itemID, context.professionID)

	self:RefreshCustomerResults()
end

function AF:EnsureCustomerRows(count)
	local frame = self.customerFrame
	if not frame then
		return
	end
	for i = #self.customerRows + 1, count do
		local row = CreateCustomerRow(frame.content)
		row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
		self.customerRows[i] = row
	end
end

function AF:RefreshCustomerResults(statusOverride)
	local frame = self.customerFrame
	if not frame then
		return
	end

	local itemID = self.currentCustomerItemID
	local itemName = self.currentCustomerItemName or self:GetDisplayItemName(itemID)
	local sortMode = SORT_MODES[self.customerSortIndex or 1].key
	local filterText = frame.search and frame.search:GetText() or ""
	local queryToken = self.currentCustomerQueryToken
	local professionID = self.currentCustomerProfessionID
	local rows = itemID and self:GetCachedArtisans(itemID, filterText, sortMode, queryToken, professionID) or {}
	frame.status:SetText(statusOverride or (itemID and ("Available artisans for " .. itemName) or "Select an order item."))
	self:EnsureCustomerRows(#rows)
	frame.content:SetHeight(math.max(1, #rows * ROW_HEIGHT))

	local now = self:Now()
	for i, row in ipairs(self.customerRows or {}) do
		local entry = rows[i]
		if entry then
			row.entry = entry
			row:SetWidth(math.max(280, frame.scroll:GetWidth() - 4))
			row.name:SetText((entry.name or "?"))
			local note = entry.note and entry.note ~= "" and (" - " .. entry.note) or ""
			row.detail:SetText(self:FormatMoney(entry.priceCopper, entry.freeCommission) .. note .. " (" .. GetAgeText(now, entry.updatedAt) .. ")")
			row.capability:SetText(self:FormatCapability(entry))
			row:Show()
		else
			row.entry = nil
			row:Hide()
		end
	end

	if #rows == 0 and itemID then
		local hasAvailableUnfiltered = false
		if filterText ~= "" then
			hasAvailableUnfiltered = #self:GetCachedArtisans(itemID, "", sortMode, queryToken, professionID) > 0
		end
		if self.db.debugSelfResults and not self.db.artisanProfile.items[tostring(itemID)] then
			frame.status:SetText("Debug on, but this character has not scanned " .. itemName .. ".")
		elseif filterText ~= "" and hasAvailableUnfiltered then
			frame.status:SetText("No available artisans match the filter for " .. itemName .. ".")
		elseif self.lastQueryAt and self:Now() - self.lastQueryAt < self.LIVE_QUERY_TIMEOUT then
			frame.status:SetText("Checking available artisans for " .. itemName .. "...")
		else
			frame.status:SetText("No available artisans found for " .. itemName .. ".")
		end
	end
end

function AF:GetCrafterWhisperMessage(entry)
	local capability = self:FormatCapability(entry)
	if capability == "" then
		return ""
	end
	return "Hi! ArtisanFinder shows for this craft: " .. capability .. ". "
end

function AF:OpenCrafterProfession(entry)
	if not entry or not entry.professionLink then
		return
	end

	self.pendingProfessionRecipeID = tonumber(entry.recipeID)
	self.pendingProfessionRecipeTries = 12
	SetItemRef(entry.professionLink, entry.professionLink, "LeftButton", DEFAULT_CHAT_FRAME)
	self:QueuePendingProfessionRecipeSelection()
end

function AF:QueuePendingProfessionRecipeSelection()
	if self.pendingProfessionRecipeQueued or not self.pendingProfessionRecipeID then
		return
	end

	self.pendingProfessionRecipeQueued = true
	C_Timer.After(0.25, function()
		AF.pendingProfessionRecipeQueued = false
		AF:TrySelectPendingProfessionRecipe()
	end)
end

function AF:TrySelectPendingProfessionRecipe()
	local recipeID = self.pendingProfessionRecipeID
	if not recipeID then
		return
	end

	local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
	local recipeList = page and page.RecipeList
	local form = page and page.SchematicForm
	if not page or not recipeList or not form or not page:IsVisible() then
		self.pendingProfessionRecipeTries = (self.pendingProfessionRecipeTries or 0) - 1
		if self.pendingProfessionRecipeTries > 0 then
			self:QueuePendingProfessionRecipeSelection()
		end
		return
	end

	local recipeInfo = C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(recipeID)
	if recipeInfo then
		recipeList:SelectRecipe(recipeInfo, true)
	end

	local selectedRecipeInfo = form.GetRecipeInfo and form:GetRecipeInfo()
	if selectedRecipeInfo and tonumber(selectedRecipeInfo.recipeID) == recipeID then
		self.pendingProfessionRecipeID = nil
		self.pendingProfessionRecipeTries = nil
		return
	end

	self.pendingProfessionRecipeTries = (self.pendingProfessionRecipeTries or 0) - 1
	if self.pendingProfessionRecipeTries > 0 then
		self:QueuePendingProfessionRecipeSelection()
	else
		self.pendingProfessionRecipeID = nil
	end
end

function AF:FillPersonalOrder(entry)
	if not entry then
		self:Print("open a customer order before filling a personal order.")
		return
	end

	local form = ProfessionsCustomerOrdersFrame.Form
	local recipient = self:NormalizeName(entry.target or entry.name)
	form:SetOrderRecipient(Enum.CraftingOrderType.Personal)
	form.OrderRecipientDropdown:SetText(PROFESSIONS_CRAFTING_FORM_ORDER_RECIPIENT_PRIVATE)
	form.OrderRecipientTarget:SetText(recipient)

	local commissionCopper = 0
	if not entry.freeCommission and tonumber(entry.priceCopper) and tonumber(entry.priceCopper) > 0 then
		commissionCopper = tonumber(entry.priceCopper) or 0
	end
	if commissionCopper > 0 then
		local commissionGold = tostring(math.floor(commissionCopper / 10000))
		form.PaymentContainer.TipMoneyInputFrame.GoldBox:SetText(commissionGold)
	end

	form:UpdateListOrderButton()
	self:Print("filled personal order fields. Please review before placing the order.")
end
