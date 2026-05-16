local _, AF = ...

local function NormalizeCommand(message)
	message = tostring(message or ""):lower():match("^%s*(.-)%s*$")
	local command, rest = message:match("^(%S+)%s*(.-)$")
	return command or "", rest or ""
end

function AF:SetDebugSelfResults(enabled)
	self.db.debugSelfResults = enabled == true
	self:Print("debug self results " .. (self.db.debugSelfResults and "enabled" or "disabled") .. ".")
	if self.RefreshCustomerQuery then
		self:RefreshCustomerQuery(true)
	end
end

function AF:PrintSlashHelp()
	self:Print("/af debug on - show this character in customer results when scanned")
	self:Print("/af debug off - disable debug self results")
	self:Print("/af debug toggle - toggle debug self results")
	self:Print("/af debug - show current debug state")
end

function AF:HandleSlash(message)
	local command, rest = NormalizeCommand(message)
	if command == "debug" then
		if rest == "on" then
			self:SetDebugSelfResults(true)
		elseif rest == "off" then
			self:SetDebugSelfResults(false)
		elseif rest == "toggle" then
			self:SetDebugSelfResults(not self.db.debugSelfResults)
		elseif rest == "" then
			self:Print("debug self results are " .. (self.db.debugSelfResults and "enabled" or "disabled") .. ".")
		else
			self:Print("unknown debug command: " .. rest)
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
