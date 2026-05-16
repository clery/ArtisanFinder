local _, AF = ...

local function NormalizeCommand(message)
	message = tostring(message or ""):lower():match("^%s*(.-)%s*$")
	local command, rest = message:match("^(%S+)%s*(.-)$")
	return command or "", rest or ""
end

function AF:SetDebugSelfResults(enabled)
	self.db.debugSelfResults = enabled == true
	self:Print(self:Text("DEBUG_SELF_CHANGED", self.db.debugSelfResults and self:Text("ENABLED") or self:Text("DISABLED")))
	if self.RefreshCustomerQuery then
		self:RefreshCustomerQuery(true)
	end
end

function AF:PrintSlashHelp()
	self:Print(self:Text("SCAN_HELP_FORCE"))
	self:Print(self:Text("DEBUG_HELP_ON"))
	self:Print(self:Text("DEBUG_HELP_OFF"))
	self:Print(self:Text("DEBUG_HELP_TOGGLE"))
	self:Print(self:Text("DEBUG_HELP_STATE"))
end

function AF:HandleSlash(message)
	local command, rest = NormalizeCommand(message)
	if command == "scan" then
		if self.StartOrResumeCurrentProfessionScan then
			self:StartOrResumeCurrentProfessionScan(true, false)
		end
	elseif command == "debug" then
		if rest == "on" then
			self:SetDebugSelfResults(true)
		elseif rest == "off" then
			self:SetDebugSelfResults(false)
		elseif rest == "toggle" then
			self:SetDebugSelfResults(not self.db.debugSelfResults)
		elseif rest == "" then
			self:Print(self:Text("DEBUG_SELF_STATE", self.db.debugSelfResults and self:Text("ENABLED") or self:Text("DISABLED")))
		else
			self:Print(self:Text("DEBUG_UNKNOWN", rest))
			self:PrintSlashHelp()
		end
	else
		self:PrintSlashHelp()
	end
end

function AF:InitializeSlashCommands()
	SLASH_ARTISANFINDER1 = "/af"
	SLASH_ARTISANFINDER2 = "/artisanfinder"
	SlashCmdList.ARTISANFINDER = function(message)
		AF:HandleSlash(message)
	end
end
