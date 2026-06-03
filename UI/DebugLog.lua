local _, AF = ...

local DEBUG_LOG_LIMIT = 300

local function BoolText(AF, value)
	return value and AF:Text("ENABLED") or AF:Text("DISABLED")
end

local function EscapeLogText(value)
	return tostring(value or ""):gsub("|", "||")
end

local function GetDebugTimestamp()
	local nowMS = debugprofilestop and debugprofilestop() or ((GetTime and GetTime() or 0) * 1000)
	AF.debugTimestampBaseMS = AF.debugTimestampBaseMS or nowMS
	AF.debugTimestampBaseTime = AF.debugTimestampBaseTime or (time and time() or 0)
	local elapsedMS = math.max(0, nowMS - AF.debugTimestampBaseMS)
	local stampTime = AF.debugTimestampBaseTime + math.floor(elapsedMS / 1000)
	local stamp = date and date("%H:%M:%S", stampTime) or "00:00:00"
	return string.format("%s.%03d", stamp, math.floor(elapsedMS % 1000))
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
	local line = string.format("%s [%s] %s", GetDebugTimestamp(), EscapeLogText(category or "debug"), EscapeLogText(message))
	table.insert(self.debugLogLines, line)
	while #self.debugLogLines > DEBUG_LOG_LIMIT do
		table.remove(self.debugLogLines, 1)
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
	frame.editBox:SetCursorPosition(0)
	if frame.scroll.SetHorizontalScroll then
		frame.scroll:SetHorizontalScroll(0)
	end
	if frame.scroll.SetVerticalScroll then
		frame.scroll:SetVerticalScroll(0)
	end
end

function AF:CreateDebugLogFrame()
	local frame = CreateFrame("Frame", "ArtisanFinderDebugLogFrame", UIParent, "ArtisanFinderDebugLogFrameTemplate")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	frame.title:SetText(self:Text("DEBUG_LOGS_TITLE"))

	frame.editBox = frame.scroll.editBox
	frame.editBox:SetMultiLine(true)
	frame.editBox:SetAutoFocus(false)
	frame.editBox:SetFontObject(ChatFontNormal)
	frame.editBox:SetSize(560, 340)
	frame.editBox:SetScript("OnEscapePressed", function(box)
		box:ClearFocus()
	end)
	frame.scroll:SetScrollChild(frame.editBox)

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
