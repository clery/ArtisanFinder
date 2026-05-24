local _, AF = ...

local DEBUG_LOG_LIMIT = 300

local function BoolText(AF, value)
	return value and AF:Text("ENABLED") or AF:Text("DISABLED")
end

function AF:IsDebugEnabled()
	return self.db and self.db.debugEnabled == true
end

function AF:IsDevEnabled()
	return self.db and self.db.devEnabled == true
end

function AF:IsDevFakeRowsEnabled()
	return self:IsDevEnabled() and self.db.devFakeRows == true
end

function AF:IsDevTrafficLogsEnabled()
	return self:IsDevEnabled() and self.db.devTrafficLogs == true
end

function AF:DebugLog(category, message)
	if not self:IsDebugEnabled() then
		return
	end
	self.debugLogLines = self.debugLogLines or {}
	local line = string.format("[%s] %s", tostring(category or "debug"), tostring(message or ""))
	table.insert(self.debugLogLines, line)
	while #self.debugLogLines > DEBUG_LOG_LIMIT do
		table.remove(self.debugLogLines, 1)
	end
	if self.debugLogFrame and self.debugLogFrame:IsShown() then
		self:RefreshDebugLogFrame()
	end
end

function AF:ClearDebugLog()
	table.wipe(self.debugLogLines or {})
	if self.debugLogFrame and self.debugLogFrame:IsShown() then
		self:RefreshDebugLogFrame()
	end
	self:Print(self:Text("DEBUG_LOGS_CLEARED"))
end

function AF:GetDebugLogText()
	return table.concat(self.debugLogLines or {}, "\n")
end

function AF:RefreshDebugLogFrame()
	local frame = self.debugLogFrame
	if not frame or not frame.editBox then
		return
	end
	frame.editBox:SetHeight(math.max(340, (#(self.debugLogLines or {}) * 14) + 24))
	frame.editBox:SetText(self:GetDebugLogText())
	frame.editBox:HighlightText(0, 0)
end

function AF:CreateDebugLogFrame()
	local frame = CreateFrame("Frame", "ArtisanFinderDebugLogFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(620, 420)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	if frame.TitleBg then
		frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 5, 0)
	else
		frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
	end
	frame.title:SetText(self:Text("DEBUG_LOGS_TITLE"))

	frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	frame.scroll:SetPoint("TOPLEFT", 12, -32)
	frame.scroll:SetPoint("BOTTOMRIGHT", -32, 42)

	frame.editBox = CreateFrame("EditBox", nil, frame.scroll)
	frame.editBox:SetMultiLine(true)
	frame.editBox:SetAutoFocus(false)
	frame.editBox:SetFontObject(ChatFontNormal)
	frame.editBox:SetSize(560, 340)
	frame.editBox:SetScript("OnEscapePressed", function(box)
		box:ClearFocus()
	end)
	frame.scroll:SetScrollChild(frame.editBox)

	frame.clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.clear:SetSize(96, 22)
	frame.clear:SetPoint("BOTTOMRIGHT", -12, 12)
	frame.clear:SetText(self:Text("DEBUG_LOGS_CLEAR"))
	frame.clear:SetScript("OnClick", function()
		AF:ClearDebugLog()
	end)

	self.debugLogFrame = frame
	return frame
end

function AF:OpenDebugLogFrame()
	if not self:IsDebugEnabled() then
		self:PrintSlashHelp()
		return
	end
	local frame = self.debugLogFrame or self:CreateDebugLogFrame()
	self:RefreshDebugLogFrame()
	frame:Show()
	frame.editBox:SetFocus()
	frame.editBox:HighlightText()
end

function AF:SetDebugEnabled(enabled)
	self.db.debugEnabled = enabled == true
	if not self.db.debugEnabled then
		self.db.devEnabled = false
		self.db.devFakeRows = false
		self.db.devTrafficLogs = false
		self.localeOverride = nil
		if self.ClearAllDebugSelfResults then
			self:ClearAllDebugSelfResults()
		end
		if self.ClearDebugTradeLeads then
			self:ClearDebugTradeLeads()
		end
	end
	self:Print(self:Text("DEBUG_CHANGED", BoolText(self, self.db.debugEnabled)))
	self:RefreshCustomerQuery(true)
end

function AF:SetDevEnabled(enabled)
	self.db.devEnabled = enabled == true
	if self.db.devEnabled then
		self.db.debugEnabled = true
		self.db.devFakeRows = true
	else
		self.db.devFakeRows = false
		self.db.devTrafficLogs = false
		if self.ClearAllDebugSelfResults then
			self:ClearAllDebugSelfResults()
		end
		if self.ClearDebugTradeLeads then
			self:ClearDebugTradeLeads()
		end
	end
	self:Print(self:Text("DEV_CHANGED", BoolText(self, self.db.devEnabled)))
	self:RefreshCustomerQuery(true)
end

function AF:SetDevFakeRows(enabled)
	if enabled then
		self.db.debugEnabled = true
		self.db.devEnabled = true
		self.db.devFakeRows = true
		self:Print(self:Text("DEV_FAKE_CHANGED", BoolText(self, true)))
		self:RefreshCustomerQuery(true)
	else
		self.db.devFakeRows = false
		if self.ClearAllDebugSelfResults then
			self:ClearAllDebugSelfResults()
		end
		if self.ClearDebugTradeLeads then
			self:ClearDebugTradeLeads()
		end
		self:Print(self:Text("DEV_FAKE_CHANGED", BoolText(self, false)))
		self:RefreshCustomerQuery(true)
	end
end

function AF:SetDevTrafficLogs(enabled)
	if enabled then
		self.db.debugEnabled = true
		self.db.devEnabled = true
	end
	self.db.devTrafficLogs = enabled == true
	self:Print(self:Text("DEV_TRAFFIC_CHANGED", BoolText(self, self.db.devTrafficLogs)))
end
