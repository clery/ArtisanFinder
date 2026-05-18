local _, AF = ...

local SORT_MODES = {
	{ key = "best", labelKey = "SORT_RECOMMENDED" },
	{ key = "commission", labelKey = "SORT_COMMISSION" },
	{ key = "quality", labelKey = "SORT_QUALITY" },
}

local ROW_HEIGHT = 58
local ROW_BOTTOM_PADDING = 7
local ROW_TOP_PADDING = 4
local CUSTOMER_PANEL_WIDTH = 452
local CUSTOMER_PANEL_COLLAPSED_WIDTH = 28
local CUSTOMER_PANEL_ATTACH_OFFSET_X = -5

local function GetSortMode(index)
	return SORT_MODES[index or 1] or SORT_MODES[1]
end

local function GetSortLabel(index)
	return AF:Text(GetSortMode(index).labelKey)
end

local function GetSortIndexByKey(key)
	for index, mode in ipairs(SORT_MODES) do
		if mode.key == key then
			return index
		end
	end
	return 1
end

function AF:GetCustomerSortOptions()
	local options = {}
	for _, mode in ipairs(SORT_MODES) do
		table.insert(options, { key = mode.key, text = self:Text(mode.labelKey) })
	end
	return options
end

function AF:SetDefaultSort(key)
	self.db.defaultSort = GetSortMode(GetSortIndexByKey(key)).key
	self.customerSortIndex = GetSortIndexByKey(self.db.defaultSort)
	if self.customerFrame and self.customerFrame.sort then
		self.customerFrame.sort:SetText(self:Text("SORT_BUTTON", GetSortLabel(self.customerSortIndex)))
	end
	if self.RefreshCustomerResults then
		self:RefreshCustomerResults()
	end
	if self.RefreshOptionsPanel then
		self:RefreshOptionsPanel()
	end
end

local function SaveFramePoints(frame)
	local points = {}
	for i = 1, frame:GetNumPoints() do
		local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(i)
		points[i] = {
			point = point,
			relativeTo = relativeTo,
			relativePoint = relativePoint,
			xOfs = xOfs,
			yOfs = yOfs,
		}
	end
	return points
end

local function RestoreFramePoints(frame, points)
	if not frame or not points then
		return
	end
	frame:ClearAllPoints()
	for _, point in ipairs(points) do
		if point.relativeTo then
			frame:SetPoint(point.point, point.relativeTo, point.relativePoint, point.xOfs, point.yOfs)
		else
			frame:SetPoint(point.point, point.xOfs, point.yOfs)
		end
	end
end


local function GetScrollBar(scrollFrame)
	return scrollFrame and (scrollFrame.ScrollBar or _G[(scrollFrame:GetName() or "") .. "ScrollBar"])
end

local function Clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function SetButtonAtlas(button, normalAtlas, pushedAtlas, disabledAtlas, highlightAtlas)
	if not button then
		return
	end
	if button.SetNormalAtlas then
		button:SetNormalAtlas(normalAtlas)
	end
	if button.SetPushedAtlas then
		button:SetPushedAtlas(pushedAtlas)
	end
	if button.SetDisabledAtlas then
		button:SetDisabledAtlas(disabledAtlas or normalAtlas)
	end
	if button.SetHighlightAtlas then
		button:SetHighlightAtlas(highlightAtlas or normalAtlas, "ADD")
	end
end

local function TrySetTextureAtlas(texture, atlas, useAtlasSize)
	if not texture or not atlas then
		return false
	end
	if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlas) then
		return false
	end
	if texture.SetAtlas then
		local ok = pcall(texture.SetAtlas, texture, atlas, useAtlasSize)
		return ok == true
	end
	return false
end

local function SetMinimalThumbAtlas(thumb, state)
	if not thumb then
		return
	end
	local suffix = ""
	if state == "over" then
		suffix = "-over"
	elseif state == "down" then
		suffix = "-down"
	end
	thumb.Begin:SetAtlas("minimal-scrollbar-small-thumb-top" .. suffix, true)
	thumb.Middle:SetAtlas("minimal-scrollbar-small-thumb-middle" .. suffix, true)
	thumb.End:SetAtlas("minimal-scrollbar-small-thumb-bottom" .. suffix, true)
end

local function SetScrollBarValueFromCursor(bar, cursorOffset)
	local track = bar.Track
	local scrollBar = bar.ScrollBar
	if not track or not scrollBar or not track.GetTop then
		return
	end

	local _, maxValue = scrollBar:GetMinMaxValues()
	maxValue = tonumber(maxValue) or 0
	if maxValue <= 0 then
		return
	end

	local scale = UIParent:GetEffectiveScale()
	local _, cursorY = GetCursorPosition()
	cursorY = cursorY / scale

	local trackTop = track:GetTop()
	local trackHeight = track:GetHeight()
	local thumbHeight = bar.Thumb:GetHeight()
	local travel = math.max(1, trackHeight - thumbHeight)
	local thumbTop = cursorY + (cursorOffset or -(thumbHeight / 2))
	local offset = Clamp(trackTop - thumbTop, 0, travel)
	scrollBar:SetValue((offset / travel) * maxValue)
end

local function UpdateCustomerScrollBar(bar)
	local scrollBar = bar and bar.ScrollBar
	if not scrollBar then
		return
	end

	local _, maxValue = scrollBar:GetMinMaxValues()
	maxValue = tonumber(maxValue) or 0
	bar:SetShown(maxValue > 0)
	if maxValue <= 0 then
		return
	end

	local track = bar.Track
	local thumb = bar.Thumb
	local trackHeight = track:GetHeight()
	local scrollFrame = bar.ScrollFrame
	local visibleHeight = scrollFrame and scrollFrame:GetHeight() or trackHeight
	local contentHeight = visibleHeight + maxValue
	local thumbHeight = Clamp(math.floor(trackHeight * (visibleHeight / contentHeight)), 23, trackHeight)
	local travel = math.max(1, trackHeight - thumbHeight)
	local value = Clamp(scrollBar:GetValue() or 0, 0, maxValue)

	thumb:SetHeight(thumbHeight)
	thumb:ClearAllPoints()
	thumb:SetPoint("TOP", track, "TOP", 0, -((value / maxValue) * travel))
end

local function CreateCustomerMinimalScrollBar(parent, scrollFrame, scrollBar)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetWidth(17)
	bar.ScrollFrame = scrollFrame
	bar.ScrollBar = scrollBar

	bar.Back = CreateFrame("Button", nil, bar)
	bar.Back:SetSize(17, 11)
	bar.Back:SetPoint("TOP")
	SetButtonAtlas(bar.Back, "minimal-scrollbar-arrow-top", "minimal-scrollbar-arrow-top-down", "minimal-scrollbar-arrow-top", "minimal-scrollbar-arrow-top-over")
	bar.Back:SetScript("OnClick", function()
		scrollBar:SetValue((scrollBar:GetValue() or 0) - ROW_HEIGHT)
	end)

	bar.Forward = CreateFrame("Button", nil, bar)
	bar.Forward:SetSize(17, 11)
	bar.Forward:SetPoint("BOTTOM")
	SetButtonAtlas(bar.Forward, "minimal-scrollbar-arrow-bottom", "minimal-scrollbar-arrow-bottom-down", "minimal-scrollbar-bottom-top", "minimal-scrollbar-arrow-bottom-over")
	bar.Forward:SetScript("OnClick", function()
		scrollBar:SetValue((scrollBar:GetValue() or 0) + ROW_HEIGHT)
	end)

	bar.Track = CreateFrame("Frame", nil, bar)
	bar.Track:SetWidth(8)
	bar.Track:SetPoint("TOP", 0, -19)
	bar.Track:SetPoint("BOTTOM", 0, 19)
	bar.Track:EnableMouse(true)
	bar.Track.Begin = bar.Track:CreateTexture(nil, "ARTWORK")
	bar.Track.Begin:SetAtlas("minimal-scrollbar-track-top", true)
	bar.Track.Begin:SetPoint("TOPLEFT")
	bar.Track.End = bar.Track:CreateTexture(nil, "ARTWORK")
	bar.Track.End:SetAtlas("minimal-scrollbar-track-bottom", true)
	bar.Track.End:SetPoint("BOTTOMLEFT")
	bar.Track.Middle = bar.Track:CreateTexture(nil, "ARTWORK")
	bar.Track.Middle:SetAtlas("!minimal-scrollbar-track-middle", true)
	bar.Track.Middle:SetPoint("TOPLEFT", bar.Track.Begin, "BOTTOMLEFT")
	bar.Track.Middle:SetPoint("BOTTOMRIGHT", bar.Track.End, "TOPRIGHT")
	bar.Track:SetScript("OnMouseDown", function()
		SetScrollBarValueFromCursor(bar)
	end)

	bar.Thumb = CreateFrame("Button", nil, bar.Track)
	bar.Thumb:SetSize(8, 23)
	bar.Thumb:EnableMouse(true)
	bar.Thumb:SetHitRectInsets(-4, -4, -4, -4)
	bar.Thumb.Begin = bar.Thumb:CreateTexture(nil, "OVERLAY")
	bar.Thumb.Begin:SetAtlas("minimal-scrollbar-small-thumb-top", true)
	bar.Thumb.Begin:SetPoint("TOPLEFT")
	bar.Thumb.End = bar.Thumb:CreateTexture(nil, "OVERLAY")
	bar.Thumb.End:SetAtlas("minimal-scrollbar-small-thumb-bottom", true)
	bar.Thumb.End:SetPoint("BOTTOMLEFT")
	bar.Thumb.Middle = bar.Thumb:CreateTexture(nil, "OVERLAY")
	bar.Thumb.Middle:SetAtlas("minimal-scrollbar-small-thumb-middle", true)
	bar.Thumb.Middle:SetPoint("TOPLEFT", bar.Thumb.Begin, "BOTTOMLEFT")
	bar.Thumb.Middle:SetPoint("BOTTOMRIGHT", bar.Thumb.End, "TOPRIGHT")
	bar.Thumb:SetScript("OnEnter", function(thumb)
		if not thumb.isMouseDown then
			SetMinimalThumbAtlas(thumb, "over")
		end
	end)
	bar.Thumb:SetScript("OnLeave", function(thumb)
		if not thumb.isMouseDown then
			SetMinimalThumbAtlas(thumb, "normal")
		end
	end)
	bar.Thumb:SetScript("OnMouseDown", function(thumb)
		thumb.isMouseDown = true
		SetMinimalThumbAtlas(thumb, "down")
		local scale = UIParent:GetEffectiveScale()
		local _, cursorY = GetCursorPosition()
		bar.dragCursorOffset = (thumb:GetTop() or (cursorY / scale)) - (cursorY / scale)
		bar:SetScript("OnUpdate", function()
			SetScrollBarValueFromCursor(bar, bar.dragCursorOffset)
		end)
	end)
	bar.Thumb:SetScript("OnMouseUp", function(thumb)
		thumb.isMouseDown = false
		bar:SetScript("OnUpdate", nil)
		if thumb:IsMouseOver() then
			SetMinimalThumbAtlas(thumb, "over")
		else
			SetMinimalThumbAtlas(thumb, "normal")
		end
	end)
	bar.Thumb:SetScript("OnHide", function(thumb)
		thumb.isMouseDown = false
		bar:SetScript("OnUpdate", nil)
		SetMinimalThumbAtlas(thumb, "normal")
	end)

	scrollBar:HookScript("OnValueChanged", function()
		UpdateCustomerScrollBar(bar)
	end)
	bar:SetScript("OnSizeChanged", function()
		UpdateCustomerScrollBar(bar)
	end)

	bar:Hide()
	return bar
end

local function HideLegacyScrollBar(scrollBar)
	if not scrollBar then
		return
	end
	scrollBar:SetAlpha(0)
	scrollBar:EnableMouse(false)
	if scrollBar.ScrollUpButton then
		scrollBar.ScrollUpButton:EnableMouse(false)
	end
	if scrollBar.ScrollDownButton then
		scrollBar.ScrollDownButton:EnableMouse(false)
	end
end

local function SplitAroundPlaceholder(text)
	local placeholderStart, placeholderEnd = tostring(text or ""):find("%s", 1, true)
	if not placeholderStart then
		return tostring(text or ""), ""
	end
	return text:sub(1, placeholderStart - 1), text:sub(placeholderEnd + 1)
end

local function CreateCustomerRow(parent)
	local row = CreateFrame("Button", nil, parent, "ArtisanFinderCustomerRowTemplate")
	AF:StyleListRow(row)
	row:EnableMouse(true)
	row:RegisterForClicks("LeftButtonUp")

	if not TrySetTextureAtlas(row.favorite, "PetJournal-FavoritesIcon", true)
		and not TrySetTextureAtlas(row.favorite, "communities-icon-heart", true) then
		row.favorite:SetTexture("Interface\\Common\\FavoritesIcon")
	end
	row.favorite:Hide()

	row.name:ClearAllPoints()
	row.name:SetPoint("TOPLEFT", row.certified, "TOPRIGHT", 4, 0)
	row.name:SetPoint("RIGHT", -40, 0)
	row.updatedAt:ClearAllPoints()
	row.updatedAt:SetPoint("TOPRIGHT", -40, -6)
	row.detail:ClearAllPoints()
	row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
	row.detail:SetPoint("RIGHT", -40, 0)
	row.capability:ClearAllPoints()
	row.capability:SetPoint("TOPLEFT", row.detail, "BOTTOMLEFT", 0, -3)
	row.capability:SetPoint("RIGHT", -40, 0)

	row.action:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
	row.action:SetPushedTexture("Interface\\Buttons\\UI-OptionsButton")
	row.action:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	row.action:GetNormalTexture():ClearAllPoints()
	row.action:GetNormalTexture():SetSize(21, 21)
	row.action:GetNormalTexture():SetPoint("CENTER")
	row.action:GetPushedTexture():ClearAllPoints()
	row.action:GetPushedTexture():SetSize(21, 21)
	row.action:GetPushedTexture():SetPoint("CENTER", 1, -1)
	row.action:SetScript("OnClick", function(buttonFrame)
		if row.entry then
			AF:ShowCustomerMenu(row.entry, buttonFrame)
		end
	end)
	row:SetScript("OnEnter", function(buttonFrame)
		if buttonFrame.entry then
			GameTooltip:SetOwner(buttonFrame, "ANCHOR_RIGHT")
			GameTooltip:SetText(AF:GetDisplayPlayerName(buttonFrame.entry.name or "?"), 1, 0.82, 0)
			if buttonFrame.entry.professionName then
				GameTooltip:AddLine(buttonFrame.entry.professionName, 1, 1, 1)
			end
			GameTooltip:AddLine(buttonFrame.entry.tradeLead and AF:Text("MISSING_ADDON_DATA") or AF:Text("CERTIFIED_ADDON_DATA"), buttonFrame.entry.tradeLead and 0.75 or 0.35, buttonFrame.entry.tradeLead and 0.75 or 1, buttonFrame.entry.tradeLead and 0.75 or 0.35, true)
			if not buttonFrame.entry.tradeLead then
				AF:RequestReagentDetail(buttonFrame.entry)
				AF:AddCapabilityTooltipLines(GameTooltip, buttonFrame.entry)
			end
			AF:StyleCustomerTooltip(GameTooltip)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return row
end

function AF:HookCustomerCurrentListings()
	if self.currentListingsHooked then
		return
	end

	local form = ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
	local listings = form and form.CurrentListings
	if not listings then
		return
	end

	self.currentListingsHooked = true
	listings:HookScript("OnShow", function()
		AF:QueueCustomerSidePanelLayout()
	end)
	listings:HookScript("OnHide", function()
		AF:QueueCustomerSidePanelLayout()
	end)
end

function AF:RestoreCurrentListingsAnchor()
	local form = ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.Form
	local listings = form and form.CurrentListings
	if self.currentListingsOriginalPoints then
		RestoreFramePoints(listings, self.currentListingsOriginalPoints)
		self.currentListingsMoved = false
	end
end

function AF:PositionCustomerSidePanels()
	local ordersFrame = ProfessionsCustomerOrdersFrame
	local form = ordersFrame and ordersFrame.Form
	local frame = self.customerFrame
	if not ordersFrame or not form or not frame then
		return
	end

	self:HookCustomerCurrentListings()

	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", ordersFrame, "TOPRIGHT", CUSTOMER_PANEL_ATTACH_OFFSET_X, 0)
	frame:SetPoint("BOTTOMLEFT", ordersFrame, "BOTTOMRIGHT", CUSTOMER_PANEL_ATTACH_OFFSET_X, 0)
	frame:SetWidth(frame.collapsed and CUSTOMER_PANEL_COLLAPSED_WIDTH or CUSTOMER_PANEL_WIDTH)
	local ordersHeight = ordersFrame:GetHeight()
	if ordersHeight and ordersHeight > 0 then
		frame:SetHeight(ordersHeight)
	end

	local listings = form.CurrentListings
	if not listings then
		return
	end

	if not frame:IsShown() or not form:IsShown() or not ordersFrame:IsShown() then
		self:RestoreCurrentListingsAnchor()
		return
	end
	if not listings:IsShown() then
		if self.currentListingsMoved then
			self:RestoreCurrentListingsAnchor()
		end
		return
	end

	if not self.currentListingsOriginalPoints then
		local originalPoints = SaveFramePoints(listings)
		if #originalPoints == 0 then
			return
		end
		self.currentListingsOriginalPoints = originalPoints
	end

	listings:ClearAllPoints()
	listings:SetPoint("TOPLEFT", frame, "TOPRIGHT", -1, 0)
	listings:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -1, 0)
	self.currentListingsMoved = true
end

function AF:QueueCustomerSidePanelLayout()
	self:PositionCustomerSidePanels()
	if C_Timer then
		C_Timer.After(0, function()
			AF:PositionCustomerSidePanels()
		end)
	end
end

function AF:SetCustomerStatusText(text)
	local frame = self.customerFrame
	if not frame or not frame.statusPrefix then
		return
	end
	frame.statusPrefix:SetText(text or "")
	frame.statusPrefix:ClearAllPoints()
	frame.statusPrefix:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -32)
	frame.statusPrefix:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
	if frame.itemLink then
		frame.itemLink:Hide()
		frame.itemLink.itemLinkText = nil
	end
	if frame.statusSuffix then
		frame.statusSuffix:SetText("")
	end
end

function AF:SetCustomerStatusItem(itemID, itemName, templateKey)
	local frame = self.customerFrame
	if not frame or not frame.statusPrefix or not itemID then
		self:SetCustomerStatusText(self:Text("SELECT_ORDER_ITEM"))
		return
	end

	itemName = itemName or self:GetDisplayItemName(itemID)
	local prefix, suffix = SplitAroundPlaceholder(self:Text(templateKey or "AVAILABLE_ARTISANS_FOR", "%s"))
	frame.statusPrefix:ClearAllPoints()
	frame.statusPrefix:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -32)
	frame.statusPrefix:SetText(prefix)
	frame.statusPrefix:SetWidth(math.max(1, frame.statusPrefix:GetStringWidth() + 2))

	local itemLink = "item:" .. tostring(itemID)
	local displayText = "[" .. tostring(itemName) .. "]"
	if C_Item and C_Item.GetItemInfo then
		local _, link = C_Item.GetItemInfo(itemID)
		itemLink = link or itemLink
		displayText = link or displayText
	elseif GetItemInfo then
		local _, link = GetItemInfo(itemID)
		itemLink = link or itemLink
		displayText = link or displayText
	end

	frame.itemLink.itemLinkText = itemLink
	frame.itemLink.text:SetText(displayText)
	frame.itemLink:SetWidth(math.max(1, frame.itemLink.text:GetStringWidth() + 4))
	frame.itemLink:Show()
	frame.statusSuffix:SetText(suffix)
end

function AF:SetCustomerPanelCollapsed(collapsed)
	local frame = self.customerFrame
	if not frame then
		return
	end

	frame.collapsed = collapsed and true or false
	for _, region in ipairs(frame.collapsibleRegions or {}) do
		region:SetShown(not frame.collapsed)
	end

	if frame.title then
		frame.title:SetShown(not frame.collapsed)
	end
	if frame.TitleContainer then
		frame.TitleContainer:SetShown(not frame.collapsed)
	end
	if frame.NineSlice then
		frame.NineSlice:SetShown(not frame.collapsed)
	end
	if frame.Bg then
		frame.Bg:SetShown(not frame.collapsed)
	end
	if frame.TopTileStreaks then
		frame.TopTileStreaks:SetShown(not frame.collapsed)
	end
	if frame.collapsedRail then
		frame.collapsedRail:SetShown(frame.collapsed)
	end
	if frame.collapseButton then
		frame.collapseButton:ClearAllPoints()
		if frame.collapsed then
			frame.collapseButton:SetPoint("TOP", frame.collapsedRail or frame, "TOP", 0, 0)
			if frame.collapseButton.SetMaximizedLook then
				frame.collapseButton:SetMaximizedLook()
			end
		else
			frame.collapseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 0)
			if frame.collapseButton.SetMinimizedLook then
				frame.collapseButton:SetMinimizedLook()
			end
		end
	end

	if frame.collapsed then
		self:HideCustomerMenu()
	else
		self:RefreshCustomerQuery(true)
	end
	self:QueueCustomerSidePanelLayout()
end

function AF:InitializeCustomerUI()
	self.customerRows = {}
	self.customerSortIndex = GetSortIndexByKey(self.db and self.db.defaultSort or "best")
	self:AttachCustomerUI()
end

function AF:RefreshCustomerLocale()
	local frame = self.customerFrame
	if not frame then
		return
	end
	self.customerSortIndex = SORT_MODES[self.customerSortIndex or 1] and self.customerSortIndex or 1
	if frame.sort then
		frame.sort:SetText(self:Text("SORT_BUTTON", GetSortLabel(self.customerSortIndex)))
	end
	if frame.refresh then
		frame.refresh:SetText(self:Text("REFRESH"))
	end
	if frame.menu then
		frame.menu.favorite:SetText(self:Text(frame.menu.entry and self:IsFavoriteArtisan(frame.menu.entry) and "UNFAVORITE" or "FAVORITE"))
		frame.menu.whisper:SetText(self:Text("WHISPER"))
		frame.menu.personal:SetText(self:Text("PERSONAL_ORDER"))
		frame.menu.link:SetText(self:Text("PROFESSION"))
	end
end

function AF:AttachCustomerUI()
	if self.customerFrame or not ProfessionsCustomerOrdersFrame or not ProfessionsCustomerOrdersFrame.Form then
		return
	end

	local ordersFrame = ProfessionsCustomerOrdersFrame
	local parent = ordersFrame.Form
	local panelHeight = ordersFrame:GetHeight()
	if not panelHeight or panelHeight <= 0 then
		panelHeight = 568
	end
	local frame = CreateFrame("Frame", "ArtisanFinderCustomerFrame", ordersFrame, "ArtisanFinderCustomerPanelTemplate")
	frame:SetSize(CUSTOMER_PANEL_WIDTH, panelHeight)
	frame:SetPoint("TOPLEFT", ordersFrame, "TOPRIGHT", CUSTOMER_PANEL_ATTACH_OFFSET_X, 0)
	frame:SetPoint("BOTTOMLEFT", ordersFrame, "BOTTOMRIGHT", CUSTOMER_PANEL_ATTACH_OFFSET_X, 0)
	frame:SetFrameLevel(parent:GetFrameLevel())
	self:ApplyCustomerSidePanel(frame)
	frame:Hide()

	local titleParent = frame.TitleContainer or frame
	frame.title = frame.TitleText or titleParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.title:SetParent(titleParent)
	frame.title:ClearAllPoints()
	frame.title:SetPoint("TOP", titleParent, "TOP", 0, -5)
	frame.title:SetPoint("LEFT", titleParent, "LEFT", 0, 0)
	frame.title:SetPoint("RIGHT", titleParent, "RIGHT", 0, 0)
	frame.title:SetJustifyH("CENTER")
	frame.title:SetText("ArtisanFinder")

	frame.collapseButton:SetFrameLevel((frame.TitleContainer and frame.TitleContainer:GetFrameLevel() or frame:GetFrameLevel()) + 5)
	frame.collapseButton:SetOnMinimizedCallback(function()
		AF:SetCustomerPanelCollapsed(true)
	end)
	frame.collapseButton:SetOnMaximizedCallback(function()
		AF:SetCustomerPanelCollapsed(false)
	end)
	frame.collapseButton:SetMinimizedLook()
	frame.collapsedRail:SetFrameLevel(frame:GetFrameLevel())
	self:ApplyProfessionPanel(frame.collapsedRail)
	frame.collapsedRail:Hide()

	frame.status = frame.statusPrefix
	frame.status:ClearAllPoints()
	frame.status:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -32)
	frame.status:SetPoint("RIGHT", -14, 0)
	frame.status:SetJustifyH("LEFT")
	frame.status:SetText(self:Text("SELECT_ORDER_ITEM"))
	frame.statusPrefix = frame.status
	frame.itemLink:SetHeight(16)
	frame.itemLink:ClearAllPoints()
	frame.itemLink:SetPoint("LEFT", frame.statusPrefix, "RIGHT", 0, 0)
	frame.itemLink.text:SetJustifyH("LEFT")
	frame.itemLink:Hide()
	frame.itemLink:SetScript("OnEnter", function(button)
		if button.itemLinkText then
			GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(button.itemLinkText)
			GameTooltip:Show()
		end
	end)
	frame.itemLink:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	frame.statusSuffix:ClearAllPoints()
	frame.statusSuffix:SetPoint("LEFT", frame.itemLink, "RIGHT", 0, 0)
	frame.statusSuffix:SetPoint("RIGHT", -14, 0)
	frame.statusSuffix:SetJustifyH("LEFT")
	frame.divider = self:AddDivider(frame, frame.status, -8)

	frame.search:SetSize(172, 22)
	frame.search:ClearAllPoints()
	frame.search:SetPoint("TOPLEFT", frame.divider, "BOTTOMLEFT", 0, -8)
	frame.search:SetAutoFocus(false)
	frame.search:SetScript("OnTextChanged", function()
		SearchBoxTemplate_OnTextChanged(frame.search)
		AF:RefreshCustomerResults()
	end)

	frame.sort:SetSize(154, 24)
	frame.sort:ClearAllPoints()
	frame.sort:SetPoint("LEFT", frame.search, "RIGHT", 8, 0)
	self.customerSortIndex = SORT_MODES[self.customerSortIndex or 1] and self.customerSortIndex or 1
	frame.sort:SetText(self:Text("SORT_BUTTON", GetSortLabel(self.customerSortIndex)))
	frame.sort:SetScript("OnClick", function()
		AF.customerSortIndex = (AF.customerSortIndex or 1) + 1
		if AF.customerSortIndex > #SORT_MODES then
			AF.customerSortIndex = 1
		end
		AF.db.defaultSort = GetSortMode(AF.customerSortIndex).key
		frame.sort:SetText(AF:Text("SORT_BUTTON", GetSortLabel(AF.customerSortIndex)))
		AF:RefreshCustomerResults()
		if AF.RefreshOptionsPanel then
			AF:RefreshOptionsPanel()
		end
	end)

	frame.refresh:SetSize(70, 24)
	frame.refresh:ClearAllPoints()
	frame.refresh:SetPoint("LEFT", frame.sort, "RIGHT", 6, 0)
	frame.refresh:SetText(self:Text("REFRESH"))
	frame.refresh:SetScript("OnClick", function()
		AF:RefreshCustomerQuery(true)
	end)

	frame.scroll:ClearAllPoints()
	frame.scroll:SetPoint("TOPLEFT", frame.search, "BOTTOMLEFT", 0, -9)
	frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 35)
	frame.scroll:SetFrameLevel(frame:GetFrameLevel() + 2)
	frame.content = CreateFrame("Frame", nil, frame.scroll)
	frame.content:SetSize(394, 1)
	if frame.content.SetClipsChildren then
		frame.content:SetClipsChildren(true)
	end
	frame.scroll:SetScrollChild(frame.content)
	frame.scrollInset:ClearAllPoints()
	frame.scrollInset:SetPoint("TOPLEFT", frame.scroll, "TOPLEFT", -4, 4)
	frame.scrollInset:SetPoint("BOTTOMRIGHT", frame.scroll, "BOTTOMRIGHT", 23, -4)
	frame.scrollInset:SetFrameLevel(frame:GetFrameLevel() + 1)
	self:ApplyCustomerListInset(frame.scrollInset)
	frame.scrollBar = GetScrollBar(frame.scroll)
	if frame.scrollBar then
		HideLegacyScrollBar(frame.scrollBar)
		frame.modernScrollBar = CreateCustomerMinimalScrollBar(frame, frame.scroll, frame.scrollBar)
		frame.modernScrollBar:SetPoint("TOPLEFT", frame.scrollInset, "TOPRIGHT", -18, -4)
		frame.modernScrollBar:SetPoint("BOTTOMLEFT", frame.scrollInset, "BOTTOMRIGHT", -18, 4)
		frame.modernScrollBar:SetFrameLevel(frame:GetFrameLevel() + 6)
	end

	frame.menuBlocker = CreateFrame("Button", "ArtisanFinderCustomerMenuBlocker", UIParent)
	frame.menuBlocker:SetAllPoints(UIParent)
	frame.menuBlocker:SetFrameStrata("FULLSCREEN_DIALOG")
	frame.menuBlocker:EnableMouse(true)
	frame.menuBlocker:RegisterForClicks("AnyUp")
	frame.menuBlocker:Hide()
	frame.menuBlocker:SetScript("OnClick", function()
		AF:HideCustomerMenu()
	end)

	frame.menu = CreateFrame("Frame", "ArtisanFinderCustomerMenu", UIParent, "ArtisanFinderCustomerMenuTemplate")
	frame.menu:SetFrameStrata("FULLSCREEN_DIALOG")
	frame.menu:SetFrameLevel(frame.menuBlocker:GetFrameLevel() + 10)
	self:ApplyCustomerPopupPanel(frame.menu)
	frame.menu:Hide()

	frame.menu.favorite:SetText(self:Text("FAVORITE"))
	frame.menu.favorite:SetScript("OnClick", function()
		if frame.menu.entry then
			AF:ToggleFavoriteArtisan(frame.menu.entry)
			AF:RefreshCustomerResults()
		end
		AF:HideCustomerMenu()
	end)

	frame.menu.whisper:SetText(self:Text("WHISPER"))
	frame.menu.whisper:SetScript("OnClick", function()
		if frame.menu.entry then
			AF:OpenWhisper(frame.menu.entry.target or frame.menu.entry.name)
		end
		AF:HideCustomerMenu()
	end)

	frame.menu.personal:SetText(self:Text("PERSONAL_ORDER"))
	frame.menu.personal:SetScript("OnClick", function()
		if frame.menu.entry then
			AF:FillPersonalOrder(frame.menu.entry)
		end
		AF:HideCustomerMenu()
	end)

	frame.menu.link:SetText(self:Text("PROFESSION"))
	frame.menu.link:SetScript("OnClick", function()
		if frame.menu.entry then
			AF:OpenCrafterProfession(frame.menu.entry)
		end
		AF:HideCustomerMenu()
	end)

	frame.collapsibleRegions = {
		frame.status,
		frame.divider,
		frame.search,
		frame.sort,
		frame.refresh,
		frame.scroll,
		frame.scrollInset,
		frame.modernScrollBar,
	}

	self.customerFrame = frame
	frame:SetScript("OnShow", function()
		frame.elapsed = 0
		AF:QueueCustomerSidePanelLayout()
		if not frame.collapsed then
			AF:RefreshCustomerQuery()
		end
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		if frame.collapsed then
			return
		end
		frame.elapsed = (frame.elapsed or 0) + elapsed
		if frame.elapsed >= 1.5 then
			frame.elapsed = 0
			AF:RefreshCustomerQuery()
		end
	end)
	parent:HookScript("OnShow", function()
		AF.customerFrame:Show()
		AF:QueueCustomerSidePanelLayout()
		if not AF.customerFrame.collapsed then
			AF:RefreshCustomerQuery()
		end
	end)
	parent:HookScript("OnHide", function()
		AF.customerFrame:Hide()
		AF:HideCustomerMenu()
		AF:RestoreCurrentListingsAnchor()
	end)
	self:HookCustomerCurrentListings()

	if parent:IsShown() then
		frame:Show()
		self:QueueCustomerSidePanelLayout()
		if not frame.collapsed then
			self:RefreshCustomerQuery()
		end
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
	menu.favorite:SetText(self:Text(self:IsFavoriteArtisan(entry) and "UNFAVORITE" or "FAVORITE"))
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


function AF:RefreshCustomerQuery(force)
	self:AttachCustomerUI()
	self:QueueCustomerSidePanelLayout()
	local frame = self.customerFrame
	if not frame or not frame:IsShown() then
		return
	end

	local context = self:GetCustomerOrderItemContext()
	if not context then
		self.currentCustomerItemID = nil
		self.currentCustomerItemName = nil
		self.currentCustomerProfessionID = nil
		self.currentCustomerRecipeID = nil
		self.currentCustomerQueryToken = nil
		self.currentCustomerQueryItemID = nil
		self.currentCustomerQueryProfessionID = nil
		self:RefreshCustomerResults(self:Text("SELECT_ORDER_ITEM"))
		return
	end

	local changed = self.currentCustomerItemID ~= context.itemID or self.currentCustomerProfessionID ~= context.professionID
	self.currentCustomerItemID = context.itemID
	self.currentCustomerItemName = context.itemName
	self.currentCustomerProfessionID = context.professionID
	self.currentCustomerRecipeID = context.recipeID

	if force then
		self:BroadcastQuery(context.itemID, context.professionID)
	elseif changed or not self.currentCustomerQueryToken then
		self.currentCustomerQueryToken = nil
		self.currentCustomerQueryItemID = nil
		self.currentCustomerQueryProfessionID = nil
		self:QueueBroadcastQuery(context.itemID, context.professionID)
	end
	self:InjectDebugSelfResult(context.itemID, context.professionID)
	if self.InjectDebugTradeLeads then
		self:InjectDebugTradeLeads()
	end

	self:RefreshCustomerResults()
end

function AF:EnsureCustomerRows(count)
	local frame = self.customerFrame
	if not frame then
		return
	end
	for i = #self.customerRows + 1, count do
		local row = CreateCustomerRow(frame.content)
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
	local sortMode = GetSortMode(self.customerSortIndex).key
	local filterText = frame.search and frame.search:GetText() or ""
	local queryToken = self.currentCustomerQueryToken
	local rows = itemID and self:GetCachedArtisans(itemID, filterText, sortMode, queryToken) or {}
	if statusOverride then
		self:SetCustomerStatusText(statusOverride)
	elseif itemID then
		self:SetCustomerStatusItem(itemID, itemName)
	else
		self:SetCustomerStatusText(self:Text("SELECT_ORDER_ITEM"))
	end
	self:EnsureCustomerRows(#rows)
	frame.content:SetWidth(math.max(1, frame.scroll:GetWidth() - 4))
	if frame.scrollBar then
		frame.scrollBar:SetShown(true)
		frame.scrollBar:SetAlpha(0)
	end

	local contentHeight = ROW_TOP_PADDING
	for i, row in ipairs(self.customerRows or {}) do
		local entry = rows[i]
		if entry then
			row.entry = entry
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -contentHeight)
			row:SetWidth(math.max(280, frame.scroll:GetWidth() - 4))
			row.name:ClearAllPoints()
			row.name:SetPoint("TOPLEFT", row.certified, "TOPRIGHT", 4, 0)
			row.name:SetPoint("RIGHT", -40, 0)
			local rowHeight = self:ApplyCustomerRowViewModel(row, self:BuildCustomerRowViewModel(entry), ROW_HEIGHT, ROW_BOTTOM_PADDING)
			row:SetHeight(rowHeight)
			contentHeight = contentHeight + rowHeight
			row:Show()
		else
			row.entry = nil
			row:Hide()
		end
	end
	frame.content:SetHeight(math.max(1, contentHeight))
	if frame.modernScrollBar then
		UpdateCustomerScrollBar(frame.modernScrollBar)
	end

	if #rows == 0 and itemID then
		local hasAvailableUnfiltered = false
		if filterText ~= "" then
			hasAvailableUnfiltered = #self:GetCachedArtisans(itemID, "", sortMode, queryToken) > 0
		end
		if self.db.debugSelfResults and not self.db.artisanProfile.items[tostring(itemID)] then
			self:SetCustomerStatusItem(itemID, itemName, "DEBUG_NOT_SCANNED")
		elseif filterText ~= "" and hasAvailableUnfiltered then
			self:SetCustomerStatusItem(itemID, itemName, "NO_FILTER_MATCH")
		elseif self.pendingCustomerQueryItemID == itemID or (self.lastQueryAt and self:Now() - self.lastQueryAt < self.LIVE_QUERY_TIMEOUT) then
			self:SetCustomerStatusItem(itemID, itemName, "CHECKING_ARTISANS")
		else
			self:SetCustomerStatusItem(itemID, itemName, "NO_ARTISANS_FOUND")
		end
	end
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
		self:Print(self:Text("PERSONAL_ORDER_NO_FORM"))
		return
	end

	local form = ProfessionsCustomerOrdersFrame.Form
	local recipient = self:NormalizeName(entry.orderTarget or entry.name or entry.target)
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
	self:Print(self:Text("PERSONAL_ORDER_FILLED"))
end
