local addonName, AF = ...

AF.CHANGELOG_FALLBACK_VERSION = "2.1.1"
AF.CHANGELOG_RECENT_ENTRIES = {
	{
		version = "2.1.1",
		key = "CHANGELOG_ENTRY_2_1_1",
	},
	{
		version = "2.1.0",
		key = "CHANGELOG_ENTRY_2_1_0",
	},
	{
		version = "2.0.5",
		key = "CHANGELOG_ENTRY_2_0_5",
	},
	{
		version = "2.0.3",
		key = "CHANGELOG_ENTRY_2_0_3",
	},
	{
		version = "2.0.2",
		key = "CHANGELOG_ENTRY_2_0_2",
	},
	{
		version = "2.0.1",
		key = "CHANGELOG_ENTRY_2_0_1",
	},
}

local CHANGELOG_CONTENT_WIDTH = 500
local CHANGELOG_CONTENT_SCROLLBAR_GUTTER = 28
local CHANGELOG_CONTENT_SCROLL_WIDTH = CHANGELOG_CONTENT_WIDTH + CHANGELOG_CONTENT_SCROLLBAR_GUTTER
local CHANGELOG_CONTENT_MIN_HEIGHT = 300
local CHANGELOG_CONTENT_PADDING_BOTTOM = 16
local CHANGELOG_CONTENT_LINE_SPACING = 4
local CHANGELOG_HTML_HEIGHT_PADDING = 24
local CHANGELOG_DRAWER_WIDTH = 112
local CHANGELOG_DRAWER_GAP = 12
local CHANGELOG_FRAME_LEFT_PADDING = 16
local CHANGELOG_FRAME_RIGHT_PADDING = 36
local CHANGELOG_MAIN_LEFT = CHANGELOG_FRAME_LEFT_PADDING + CHANGELOG_DRAWER_WIDTH + CHANGELOG_DRAWER_GAP
local CHANGELOG_FRAME_WIDTH = CHANGELOG_MAIN_LEFT + CHANGELOG_CONTENT_SCROLL_WIDTH + CHANGELOG_FRAME_RIGHT_PADDING
local CHANGELOG_FRAME_HEIGHT = 460
local CHANGELOG_DRAWER_TOP_OFFSET = -34
local CHANGELOG_DRAWER_BOTTOM_OFFSET = 50
local CHANGELOG_DRAWER_BUTTON_WIDTH = 78
local CHANGELOG_DRAWER_BUTTON_HEIGHT = 22
local CHANGELOG_DRAWER_BUTTON_SPACING = 4
local CHANGELOG_DRAWER_INSET = 6
local CHANGELOG_DRAWER_SCROLLBAR_WIDTH = 22
local CHANGELOG_SCROLL_STEP = 58
local CHANGELOG_CONTENT_INSET = 6
local CHANGELOG_SCROLLBAR_INSET = 18
local CHANGELOG_SEPARATOR_ALPHA = 0.35

local function IsPackagedVersion(version)
	version = tostring(version or "")
	return version ~= "" and not version:find("@", 1, true)
end

local function GetMetadataVersion()
	if not C_AddOns or not C_AddOns.GetAddOnMetadata then
		return nil
	end
	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	return IsPackagedVersion(version) and tostring(version) or nil
end

local function ParseVersion(version)
	local major, minor, patch = tostring(version or ""):match("v?(%d+)%.(%d+)%.(%d+)")
	return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
end

local function CompareVersions(left, right)
	local leftMajor, leftMinor, leftPatch = ParseVersion(left)
	local rightMajor, rightMinor, rightPatch = ParseVersion(right)
	if leftMajor ~= rightMajor then
		return leftMajor - rightMajor
	end
	if leftMinor ~= rightMinor then
		return leftMinor - rightMinor
	end
	return leftPatch - rightPatch
end

local function IsVersionNewerThan(version, previousVersion)
	if not previousVersion or previousVersion == "" then
		return true
	end
	return CompareVersions(version, previousVersion) > 0
end

function AF:GetAddonVersion()
	return GetMetadataVersion() or self.CHANGELOG_FALLBACK_VERSION
end

function AF:GetChangelogEntries(sinceVersion)
	local entries = {}
	for _, entry in ipairs(self.CHANGELOG_RECENT_ENTRIES or {}) do
		if IsVersionNewerThan(entry.version, sinceVersion) then
			table.insert(entries, {
				version = entry.version,
				content = self:Text(entry.key),
			})
		end
	end
	if #entries == 0 then
		table.insert(entries, {
			version = self:GetAddonVersion(),
			content = self:Text("CHANGELOG_ENTRY_2_1_1"),
		})
	end
	return entries
end

function AF:PrepareChangelogState(db, hadPersistedState)
	db.changelog = type(db.changelog) == "table" and db.changelog or {}
	local version = self:GetAddonVersion()
	if not IsPackagedVersion(version) then
		return
	end
	if db.changelog.lastSeenVersion == nil then
		if hadPersistedState then
			self.pendingChangelogVersion = version
		else
			db.changelog.lastSeenVersion = version
			db.changelog.lastSeenAt = self:Now()
			self.pendingChangelogVersion = nil
		end
	elseif db.changelog.lastSeenVersion ~= version then
		self.pendingChangelogVersion = version
	else
		self.pendingChangelogVersion = nil
	end
end

function AF:MarkChangelogSeen(version)
	if not self.db then
		return
	end
	self.db.changelog = self.db.changelog or {}
	self.db.changelog.lastSeenVersion = version or self:GetAddonVersion()
	self.db.changelog.lastSeenAt = self:Now()
	if self.pendingChangelogVersion == self.db.changelog.lastSeenVersion then
		self.pendingChangelogVersion = nil
	end
end

local function AddLine(lines, text)
	table.insert(lines, text)
end

local function TrimLeft(text)
	return tostring(text or ""):gsub("^%s+", "")
end

local function StripChangelogVersionHeading(AF, entry)
	local content = TrimLeft(entry and entry.content or "")
	local version = entry and entry.version or AF:Text("CHANGELOG_UNRELEASED")
	local heading = AF:Text("CHANGELOG_VERSION", version)
	local escapedHeading = heading:gsub("([^%w])", "%%%1")
	content = content:gsub("^#%s*" .. escapedHeading .. "%s*\n+", "", 1)
	content = content:gsub("^" .. escapedHeading .. "%s*\n+", "", 1)
	return content
end

local function FindChangelogEntry(entries, version)
	for _, entry in ipairs(entries or {}) do
		if entry.version == version then
			return entry
		end
	end
	return entries and entries[1] or nil
end

local function BuildChangelogMarkdownEntry(AF, entry)
	if not entry then
		return ""
	end
	local lines = {}
	local content = StripChangelogVersionHeading(AF, entry)
	if content ~= "" then
		AddLine(lines, content)
	end
	return table.concat(lines, "\n")
end

local function BuildChangelogTextEntry(AF, entry)
	if not entry then
		return ""
	end
	local lines = {}
	local content = StripChangelogVersionHeading(AF, entry)
	if content ~= "" then
		AddLine(lines, content)
	end
	return table.concat(lines, "\n")
end

local function GetLibMarkdown()
	if not LibStub or type(LibStub.GetLibrary) ~= "function" then
		return nil
	end
	local lib = LibStub:GetLibrary("LibMarkdown-1.0", true)
	if type(lib) == "table" and (type(lib.ToHTML) == "function" or type(lib.ToHtml) == "function") then
		return lib
	end
	return nil
end

local function ClampValue(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function GetChangelogScrollBar(scrollFrame)
	if not scrollFrame then
		return nil
	end
	return scrollFrame.ScrollBar or (scrollFrame.GetName and _G[(scrollFrame:GetName() or "") .. "ScrollBar"])
end

local function SetChangelogButtonAtlas(button, normalAtlas, pushedAtlas, disabledAtlas, highlightAtlas)
	button:SetNormalAtlas(normalAtlas)
	button:SetPushedAtlas(pushedAtlas)
	button:SetDisabledAtlas(disabledAtlas or normalAtlas)
	button:SetHighlightAtlas(highlightAtlas or normalAtlas, "ADD")
end

local function SetChangelogMinimalThumbAtlas(thumb, state)
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

local function SetChangelogScrollBarValueFromCursor(bar, cursorOffset)
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
	local offset = ClampValue(trackTop - thumbTop, 0, travel)
	scrollBar:SetValue((offset / travel) * maxValue)
end

local function UpdateChangelogMinimalScrollBar(bar)
	local scrollBar = bar and bar.ScrollBar
	if not scrollBar then
		return
	end

	local _, maxValue = scrollBar:GetMinMaxValues()
	maxValue = tonumber(maxValue) or 0
	local scrollFrame = bar.ScrollFrame
	local shown = maxValue > 0 and scrollFrame and scrollFrame:IsShown()
	bar:SetShown(shown)
	if not shown then
		return
	end

	local track = bar.Track
	local thumb = bar.Thumb
	local trackHeight = track:GetHeight()
	local visibleHeight = scrollFrame and scrollFrame:GetHeight() or trackHeight
	local contentHeight = visibleHeight + maxValue
	local thumbHeight = ClampValue(math.floor(trackHeight * (visibleHeight / contentHeight)), 23, trackHeight)
	local travel = math.max(1, trackHeight - thumbHeight)
	local value = ClampValue(scrollBar:GetValue() or 0, 0, maxValue)

	thumb:SetHeight(thumbHeight)
	thumb:ClearAllPoints()
	thumb:SetPoint("TOP", track, "TOP", 0, -((value / maxValue) * travel))
end

local function HideChangelogLegacyScrollBar(scrollBar)
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

local function CreateChangelogMinimalScrollBar(parent, scrollFrame, scrollBar)
	if not scrollBar then
		return nil
	end

	local bar = CreateFrame("Frame", nil, parent, "ArtisanFinderCustomerMinimalScrollBarTemplate")
	bar.ScrollFrame = scrollFrame
	bar.ScrollBar = scrollBar

	SetChangelogButtonAtlas(bar.Back, "minimal-scrollbar-arrow-top", "minimal-scrollbar-arrow-top-down", "minimal-scrollbar-arrow-top", "minimal-scrollbar-arrow-top-over")
	bar.Back:SetScript("OnClick", function()
		scrollBar:SetValue((scrollBar:GetValue() or 0) - CHANGELOG_SCROLL_STEP)
	end)

	SetChangelogButtonAtlas(bar.Forward, "minimal-scrollbar-arrow-bottom", "minimal-scrollbar-arrow-bottom-down", "minimal-scrollbar-arrow-bottom", "minimal-scrollbar-arrow-bottom-over")
	bar.Forward:SetScript("OnClick", function()
		scrollBar:SetValue((scrollBar:GetValue() or 0) + CHANGELOG_SCROLL_STEP)
	end)

	bar.Track:EnableMouse(true)
	bar.Track:SetScript("OnMouseDown", function()
		SetChangelogScrollBarValueFromCursor(bar)
	end)

	bar.Thumb = bar.Track.Thumb
	bar.Thumb:EnableMouse(true)
	bar.Thumb:SetHitRectInsets(-4, -4, -4, -4)
	bar.Thumb:SetScript("OnEnter", function(thumb)
		if not thumb.isMouseDown then
			SetChangelogMinimalThumbAtlas(thumb, "over")
		end
	end)
	bar.Thumb:SetScript("OnLeave", function(thumb)
		if not thumb.isMouseDown then
			SetChangelogMinimalThumbAtlas(thumb, "normal")
		end
	end)
	bar.Thumb:SetScript("OnMouseDown", function(thumb)
		thumb.isMouseDown = true
		SetChangelogMinimalThumbAtlas(thumb, "down")
		local scale = UIParent:GetEffectiveScale()
		local _, cursorY = GetCursorPosition()
		bar.dragCursorOffset = (thumb:GetTop() or (cursorY / scale)) - (cursorY / scale)
		bar:SetScript("OnUpdate", function()
			SetChangelogScrollBarValueFromCursor(bar, bar.dragCursorOffset)
		end)
	end)
	bar.Thumb:SetScript("OnMouseUp", function(thumb)
		thumb.isMouseDown = false
		bar:SetScript("OnUpdate", nil)
		if thumb:IsMouseOver() then
			SetChangelogMinimalThumbAtlas(thumb, "over")
		else
			SetChangelogMinimalThumbAtlas(thumb, "normal")
		end
	end)
	bar.Thumb:SetScript("OnHide", function(thumb)
		thumb.isMouseDown = false
		bar:SetScript("OnUpdate", nil)
		SetChangelogMinimalThumbAtlas(thumb, "normal")
	end)

	scrollBar:HookScript("OnValueChanged", function()
		UpdateChangelogMinimalScrollBar(bar)
	end)
	scrollFrame:HookScript("OnScrollRangeChanged", function()
		UpdateChangelogMinimalScrollBar(bar)
	end)
	scrollFrame:HookScript("OnShow", function()
		UpdateChangelogMinimalScrollBar(bar)
	end)
	bar:SetScript("OnSizeChanged", function()
		UpdateChangelogMinimalScrollBar(bar)
	end)

	bar:Hide()
	return bar
end

function AF:BuildChangelogMarkdown(sinceVersion, selectedVersion)
	local entries = selectedVersion and self:GetChangelogEntries() or self:GetChangelogEntries(sinceVersion)
	local entry = FindChangelogEntry(entries, selectedVersion)
	return BuildChangelogMarkdownEntry(self, entry)
end

function AF:BuildChangelogText(sinceVersion, selectedVersion)
	local entries = selectedVersion and self:GetChangelogEntries() or self:GetChangelogEntries(sinceVersion)
	local entry = FindChangelogEntry(entries, selectedVersion)
	return BuildChangelogTextEntry(self, entry)
end

function AF:BuildChangelogHTML(sinceVersion, selectedVersion)
	local markdown = GetLibMarkdown()
	if not markdown then
		return nil
	end
	local renderer = markdown.ToHTML or markdown.ToHtml
	local ok, html = pcall(renderer, markdown, self:BuildChangelogMarkdown(sinceVersion, selectedVersion))
	if ok and type(html) == "string" and html ~= "" then
		return html
	end
	return nil
end

local function RefreshChangelogDrawer(AF, frame, entries, selectedVersion)
	local buttonStep = CHANGELOG_DRAWER_BUTTON_HEIGHT + CHANGELOG_DRAWER_BUTTON_SPACING
	for index, entry in ipairs(entries or {}) do
		local button = frame.versionButtons[index]
		if not button then
			button = CreateFrame("Button", nil, frame.drawerBody, "UIPanelButtonTemplate")
			button:SetSize(frame.drawerButtonWidth or CHANGELOG_DRAWER_BUTTON_WIDTH, CHANGELOG_DRAWER_BUTTON_HEIGHT)
			button:SetPoint("TOPLEFT", 0, -((index - 1) * buttonStep))
			button:SetScript("OnClick", function(self)
				AF:RefreshChangelogFrame(frame.sinceVersion, self.entryVersion)
			end)
			frame.versionButtons[index] = button
		end
		button.entryVersion = entry.version
		button:SetText(entry.version or AF:Text("CHANGELOG_UNRELEASED"))
		button:Show()
		if button.entryVersion == selectedVersion then
			button:LockHighlight()
			button:GetFontString():SetTextColor(1, 0.82, 0)
		else
			button:UnlockHighlight()
			button:GetFontString():SetTextColor(1, 1, 1)
		end
	end
	for index = #(entries or {}) + 1, #frame.versionButtons do
		frame.versionButtons[index]:Hide()
	end
	local drawerHeight = math.max(1, (#(entries or {}) * buttonStep) - CHANGELOG_DRAWER_BUTTON_SPACING)
	frame.drawerBody:SetSize(frame.drawerButtonWidth or CHANGELOG_DRAWER_BUTTON_WIDTH, drawerHeight)
end

local function UpdateChangelogDrawerLayout(frame)
	local hasScrollBar = frame.drawerModernScrollBar and frame.drawerModernScrollBar:IsShown()
	local rightInset = hasScrollBar and CHANGELOG_DRAWER_SCROLLBAR_WIDTH or CHANGELOG_DRAWER_INSET
	local buttonWidth = math.max(1, CHANGELOG_DRAWER_WIDTH - CHANGELOG_DRAWER_INSET - rightInset)
	frame.drawerButtonWidth = buttonWidth

	frame.drawerScroll:ClearAllPoints()
	frame.drawerScroll:SetPoint("TOPLEFT", CHANGELOG_DRAWER_INSET, -CHANGELOG_DRAWER_INSET)
	frame.drawerScroll:SetPoint("BOTTOMRIGHT", -rightInset, CHANGELOG_DRAWER_INSET)
	frame.drawerBody:SetWidth(buttonWidth)
	for _, button in ipairs(frame.versionButtons or {}) do
		button:SetWidth(buttonWidth)
	end
end

function AF:RefreshChangelogFrame(sinceVersion, selectedVersion)
	local frame = self.changelogFrame
	if not frame then
		return
	end
	if sinceVersion == nil and selectedVersion == nil then
		sinceVersion = frame.sinceVersion
	end
	local version = self:GetAddonVersion()
	local entries = self:GetChangelogEntries()
	local selectedEntry = FindChangelogEntry(entries, selectedVersion or frame.selectedChangelogVersion)
	selectedVersion = selectedEntry and selectedEntry.version or nil
	frame.sinceVersion = sinceVersion
	frame.selectedChangelogVersion = selectedVersion
	frame.title:SetText(self:Text("CHANGELOG_TITLE"))
	frame.versionText:SetText(self:Text("CHANGELOG_VERSION", selectedVersion or version))
	frame.description:SetText(self:Text("CHANGELOG_DESCRIPTION"))
	frame.acknowledge:SetText(self:Text("CHANGELOG_ACKNOWLEDGE"))
	frame.content:SetWidth(CHANGELOG_CONTENT_WIDTH)
	frame.html:SetWidth(CHANGELOG_CONTENT_WIDTH)
	RefreshChangelogDrawer(self, frame, entries, selectedVersion)
	local html = self:BuildChangelogHTML(sinceVersion, selectedVersion)
	if html then
		frame.content:Hide()
		frame.html:Show()
		frame.html:SetText(html)
		local htmlHeight = CHANGELOG_CONTENT_MIN_HEIGHT
		if type(frame.html.GetContentHeight) == "function" then
			htmlHeight = frame.html:GetContentHeight() + CHANGELOG_HTML_HEIGHT_PADDING
		end
		frame.html:SetHeight(math.max(CHANGELOG_CONTENT_MIN_HEIGHT, htmlHeight))
		frame.body:SetSize(CHANGELOG_CONTENT_WIDTH, frame.html:GetHeight())
	else
		frame.html:Hide()
		frame.content:Show()
		frame.content:SetText(self:BuildChangelogText(sinceVersion, selectedVersion))
		frame.content:SetHeight(math.max(CHANGELOG_CONTENT_MIN_HEIGHT, frame.content:GetStringHeight() + CHANGELOG_CONTENT_PADDING_BOTTOM))
		frame.body:SetSize(CHANGELOG_CONTENT_WIDTH, frame.content:GetHeight())
	end
	frame.scroll:SetVerticalScroll(0)
	UpdateChangelogMinimalScrollBar(frame.contentScrollBar)
	UpdateChangelogMinimalScrollBar(frame.drawerModernScrollBar)
	UpdateChangelogDrawerLayout(frame)
	frame.changelogVersion = version
end

function AF:CreateChangelogFrame()
	local frame = CreateFrame("Frame", "ArtisanFinderChangelogFrame", UIParent, "DefaultPanelTemplate")
	frame:SetSize(CHANGELOG_FRAME_WIDTH, CHANGELOG_FRAME_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	if self.ApplyCustomerSidePanel then
		self:ApplyCustomerSidePanel(frame)
	end
	if frame.Inset then
		frame.Inset:Hide()
	end

	frame.title = frame.TitleContainer and frame.TitleContainer.TitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetText("ArtisanFinder")

	frame.versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.versionText:SetPoint("TOPLEFT", CHANGELOG_MAIN_LEFT, -34)
	frame.versionText:SetPoint("TOPRIGHT", -18, -34)
	frame.versionText:SetJustifyH("LEFT")

	frame.description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.description:SetPoint("TOPLEFT", frame.versionText, "BOTTOMLEFT", 0, -8)
	frame.description:SetPoint("RIGHT", -18, 0)
	frame.description:SetJustifyH("LEFT")
	frame.description:SetWordWrap(true)

	frame.drawer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.drawer:SetPoint("TOPLEFT", CHANGELOG_FRAME_LEFT_PADDING, CHANGELOG_DRAWER_TOP_OFFSET)
	frame.drawer:SetPoint("BOTTOMLEFT", CHANGELOG_FRAME_LEFT_PADDING, CHANGELOG_DRAWER_BOTTOM_OFFSET)
	frame.drawer:SetWidth(CHANGELOG_DRAWER_WIDTH)

	frame.drawerScroll = CreateFrame("ScrollFrame", nil, frame.drawer, "UIPanelScrollFrameTemplate")
	frame.drawerScroll:SetPoint("TOPLEFT", CHANGELOG_DRAWER_INSET, -CHANGELOG_DRAWER_INSET)
	frame.drawerScroll:SetPoint("BOTTOMRIGHT", -CHANGELOG_DRAWER_INSET, CHANGELOG_DRAWER_INSET)

	frame.drawerBody = CreateFrame("Frame", nil, frame.drawerScroll)
	frame.drawerBody:SetSize(CHANGELOG_DRAWER_BUTTON_WIDTH, 1)
	frame.drawerScroll:SetScrollChild(frame.drawerBody)
	frame.versionButtons = {}
	frame.drawerScrollBar = GetChangelogScrollBar(frame.drawerScroll)
	HideChangelogLegacyScrollBar(frame.drawerScrollBar)
	frame.drawerModernScrollBar = CreateChangelogMinimalScrollBar(frame.drawer, frame.drawerScroll, frame.drawerScrollBar)
	if frame.drawerModernScrollBar then
		frame.drawerModernScrollBar:SetPoint("TOPLEFT", frame.drawer, "TOPRIGHT", -CHANGELOG_SCROLLBAR_INSET, -CHANGELOG_CONTENT_INSET)
		frame.drawerModernScrollBar:SetPoint("BOTTOMLEFT", frame.drawer, "BOTTOMRIGHT", -CHANGELOG_SCROLLBAR_INSET, CHANGELOG_CONTENT_INSET)
		frame.drawerModernScrollBar:SetFrameLevel(frame.drawer:GetFrameLevel() + 6)
	end

	frame.separator = frame:CreateTexture(nil, "ARTWORK")
	frame.separator:SetColorTexture(0.62, 0.51, 0.27, CHANGELOG_SEPARATOR_ALPHA)
	frame.separator:SetPoint("TOP", frame.drawer, "TOPRIGHT", CHANGELOG_DRAWER_GAP / 2, 0)
	frame.separator:SetPoint("BOTTOM", frame.drawer, "BOTTOMRIGHT", CHANGELOG_DRAWER_GAP / 2, 0)
	frame.separator:SetWidth(2)

	frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	frame.scroll:SetPoint("TOPLEFT", CHANGELOG_MAIN_LEFT, -88)
	frame.scroll:SetPoint("BOTTOMRIGHT", -36, 56)
	frame.scroll:SetFrameLevel(frame:GetFrameLevel() + 2)

	frame.body = CreateFrame("Frame", nil, frame.scroll)
	frame.body:SetSize(CHANGELOG_CONTENT_WIDTH, CHANGELOG_CONTENT_MIN_HEIGHT)
	frame.scroll:SetScrollChild(frame.body)
	frame.scrollBar = GetChangelogScrollBar(frame.scroll)
	HideChangelogLegacyScrollBar(frame.scrollBar)
	frame.contentScrollBar = CreateChangelogMinimalScrollBar(frame, frame.scroll, frame.scrollBar)
	if frame.contentScrollBar then
		frame.contentScrollBar:SetPoint("TOPLEFT", frame.scroll, "TOPRIGHT", -CHANGELOG_CONTENT_INSET, -CHANGELOG_CONTENT_INSET)
		frame.contentScrollBar:SetPoint("BOTTOMLEFT", frame.scroll, "BOTTOMRIGHT", -CHANGELOG_CONTENT_INSET, CHANGELOG_CONTENT_INSET)
		frame.contentScrollBar:SetFrameLevel(frame:GetFrameLevel() + 6)
	end

	frame.content = frame.body:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.content:SetPoint("TOPLEFT")
	frame.content:SetPoint("TOPRIGHT")
	frame.content:SetJustifyH("LEFT")
	frame.content:SetJustifyV("TOP")
	frame.content:SetWordWrap(true)
	frame.content:SetSpacing(CHANGELOG_CONTENT_LINE_SPACING)

	frame.html = CreateFrame("SimpleHTML", nil, frame.body)
	frame.html:SetPoint("TOPLEFT")
	frame.html:SetPoint("TOPRIGHT")
	frame.html:SetHeight(CHANGELOG_CONTENT_MIN_HEIGHT)
	frame.html:SetFontObject("h1", "GameFontNormalLarge")
	frame.html:SetTextColor("h1", 1, 0.82, 0, 1)
	frame.html:SetFontObject("h2", "GameFontNormal")
	frame.html:SetTextColor("h2", 1, 0.82, 0, 1)
	frame.html:SetFontObject("h3", "GameFontNormal")
	frame.html:SetTextColor("h3", 1, 0.82, 0, 1)
	frame.html:SetFontObject("p", "GameFontHighlight")
	frame.html:SetTextColor("p", 1, 1, 1, 1)
	frame.html:Hide()

	frame.acknowledge = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.acknowledge:SetSize(112, 24)
	frame.acknowledge:SetPoint("BOTTOMRIGHT", -16, 16)
	frame.acknowledge:SetScript("OnClick", function()
		AF:MarkChangelogSeen(frame.changelogVersion)
		frame:Hide()
	end)

	frame:SetScript("OnHide", function(self)
		AF:MarkChangelogSeen(self.changelogVersion)
	end)

	table.insert(UISpecialFrames, "ArtisanFinderChangelogFrame")
	self.changelogFrame = frame
	return frame
end

function AF:OpenChangelogFrame(sinceVersion)
	local frame = self.changelogFrame or self:CreateChangelogFrame()
	frame.sinceVersion = sinceVersion
	frame.selectedChangelogVersion = nil
	self:RefreshChangelogFrame(sinceVersion)
	frame:Show()
	frame:Raise()
end

function AF:QueueChangelogPanel()
	if not self.pendingChangelogVersion or self.changelogPanelQueued then
		return
	end
	self.changelogPanelQueued = true
	C_Timer.After(1, function()
		AF.changelogPanelQueued = nil
		if not AF.db or not AF.pendingChangelogVersion then
			return
		end
		if AF:IsProtectedActionRestricted() then
			C_Timer.After(3, function()
				AF:QueueChangelogPanel()
			end)
			return
		end
		local sinceVersion = AF.db and AF.db.changelog and AF.db.changelog.lastSeenVersion
		AF:OpenChangelogFrame(sinceVersion)
	end)
end
