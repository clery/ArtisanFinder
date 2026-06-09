local addonName, AF = ...

AF.CHANGELOG_FALLBACK_VERSION = "2.0.6"

local CHANGELOG_CONTENT_WIDTH = 500
local CHANGELOG_CONTENT_MIN_HEIGHT = 300
local CHANGELOG_CONTENT_PADDING_BOTTOM = 16
local CHANGELOG_CONTENT_LINE_SPACING = 4

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

function AF:GetAddonVersion()
	return GetMetadataVersion() or self.CHANGELOG_FALLBACK_VERSION
end

function AF:GetChangelogEntries()
	return {
		{
			version = self:GetAddonVersion(),
			sections = {
				{
					title = self:Text("CHANGELOG_ADDED"),
					items = {
						self:Text("CHANGELOG_ENTRY_PANEL"),
						self:Text("CHANGELOG_ENTRY_TRANSFER"),
						self:Text("CHANGELOG_ENTRY_ADVANCED_PREP"),
						self:Text("CHANGELOG_ENTRY_REAGENT_RECOMMENDATIONS"),
					},
				},
				{
					title = self:Text("CHANGELOG_CHANGED"),
					items = {
						self:Text("CHANGELOG_ENTRY_SCAN_REWORK"),
					},
				},
				{
					title = self:Text("CHANGELOG_FIXED"),
					items = {
						self:Text("CHANGELOG_ENTRY_SCAN_PERFORMANCE"),
					},
				},
			},
		},
	}
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

function AF:BuildChangelogText()
	local lines = {}
	for entryIndex, entry in ipairs(self:GetChangelogEntries()) do
		if entryIndex > 1 then
			AddLine(lines, "")
		end
		local version = entry.version or self:Text("CHANGELOG_UNRELEASED")
		AddLine(lines, "|cffffd100" .. self:Text("CHANGELOG_VERSION", version) .. "|r")
		for _, section in ipairs(entry.sections or {}) do
			AddLine(lines, "")
			AddLine(lines, "|cffffffff" .. tostring(section.title or "") .. "|r")
			for _, item in ipairs(section.items or {}) do
				AddLine(lines, "- " .. tostring(item))
			end
		end
	end
	return table.concat(lines, "\n")
end

function AF:RefreshChangelogFrame()
	local frame = self.changelogFrame
	if not frame then
		return
	end
	local version = self:GetAddonVersion()
	frame.title:SetText(self:Text("CHANGELOG_TITLE"))
	frame.versionText:SetText(self:Text("CHANGELOG_VERSION", version))
	frame.description:SetText(self:Text("CHANGELOG_DESCRIPTION"))
	frame.acknowledge:SetText(self:Text("CHANGELOG_ACKNOWLEDGE"))
	frame.content:SetWidth(CHANGELOG_CONTENT_WIDTH)
	frame.content:SetText(self:BuildChangelogText())
	frame.content:SetHeight(math.max(CHANGELOG_CONTENT_MIN_HEIGHT, frame.content:GetStringHeight() + CHANGELOG_CONTENT_PADDING_BOTTOM))
	frame.body:SetSize(CHANGELOG_CONTENT_WIDTH, frame.content:GetHeight())
	frame.scroll:SetVerticalScroll(0)
	frame.changelogVersion = version
end

function AF:CreateChangelogFrame()
	local frame = CreateFrame("Frame", "ArtisanFinderChangelogFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(580, 460)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 5, 0)

	frame.versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.versionText:SetPoint("TOPLEFT", 18, -34)
	frame.versionText:SetPoint("TOPRIGHT", -18, -34)
	frame.versionText:SetJustifyH("LEFT")

	frame.description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.description:SetPoint("TOPLEFT", frame.versionText, "BOTTOMLEFT", 0, -8)
	frame.description:SetPoint("RIGHT", -18, 0)
	frame.description:SetJustifyH("LEFT")
	frame.description:SetWordWrap(true)

	frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	frame.scroll:SetPoint("TOPLEFT", 16, -88)
	frame.scroll:SetPoint("BOTTOMRIGHT", -36, 56)

	frame.body = CreateFrame("Frame", nil, frame.scroll)
	frame.body:SetSize(CHANGELOG_CONTENT_WIDTH, CHANGELOG_CONTENT_MIN_HEIGHT)
	frame.scroll:SetScrollChild(frame.body)

	frame.content = frame.body:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.content:SetPoint("TOPLEFT")
	frame.content:SetPoint("TOPRIGHT")
	frame.content:SetJustifyH("LEFT")
	frame.content:SetJustifyV("TOP")
	frame.content:SetWordWrap(true)
	frame.content:SetSpacing(CHANGELOG_CONTENT_LINE_SPACING)

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

function AF:OpenChangelogFrame()
	local frame = self.changelogFrame or self:CreateChangelogFrame()
	self:RefreshChangelogFrame()
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
		AF:OpenChangelogFrame()
	end)
end
