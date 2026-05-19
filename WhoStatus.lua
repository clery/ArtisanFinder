local _, AF = ...

local WHO_STATUS_TTL = 300
local WHO_STATUS_LIMIT = 5

local function GetLibWho()
	return LibStub and LibStub:GetLibrary("LibWho-2.0", true)
end

local function GetEntryWhoName(entry)
	return AF:NormalizeName(entry and (entry.orderTarget or entry.name or entry.target))
end

local function GetWhoResultName(result)
	return AF:NormalizeName(result and (result.fullName or result.Name or result.name))
end

local function IsWhoResultMatch(requestedName, result)
	local resultName = GetWhoResultName(result)
	if resultName == requestedName then
		return true
	end
	local requestedBase = tostring(requestedName or ""):match("^([^-]+)")
	local resultBase = tostring(resultName or ""):match("^([^-]+)")
	return requestedBase and resultBase and requestedBase:lower() == resultBase:lower()
end

local function ShouldWhoCheckEntry(entry)
	if not entry or entry.ownAlt then
		return false
	end
	if entry.tradeLead or entry.offlineCached or entry.unavailableFavorite then
		return true
	end
	return false
end

local function DebugPrint(...)
	if AF.whoStatusDebug then
		AF:Print(table.concat({ ... }, " "))
	end
end

local function FormatWhoStatus(value)
	if value == nil then
		return "unknown"
	end
	return tostring(value)
end

local function KickWhoQueue(label)
	local lib = GetLibWho()
	if not lib or not lib.AskWhoNext then
		return
	end
	DebugPrint("who start", label or "")
	pcall(lib.AskWhoNext, lib)
	if C_Timer then
		C_Timer.After(0.1, function()
			local currentLib = GetLibWho()
			if currentLib and currentLib.AskWhoNext then
				if currentLib.WhoInProgress or not currentLib.readyForNext or (currentLib.frame and currentLib.frame:IsShown()) then
					return
				end
				DebugPrint("who start delayed", label or "")
				pcall(currentLib.AskWhoNext, currentLib)
			end
		end)
	end
end

function AF:InitializeWhoStatus()
	self.whoStatus = self.whoStatus or {}
	self.whoStatusDebug = self.whoStatusDebug == true
end

function AF:SetWhoStatusDebug(enabled)
	self.whoStatusDebug = enabled == true
	local lib = GetLibWho()
	if lib and lib.SetWhoLibDebug then
		pcall(lib.SetWhoLibDebug, lib, self.whoStatusDebug)
	end
	self:Print(self:Text("WHO_DEBUG_CHANGED", self.whoStatusDebug and self:Text("ENABLED") or self:Text("DISABLED")))
end

function AF:StartCustomerWhoStatusChecks(duration)
	self.customerWhoStatusStartUntil = self:Now() + (duration or 3)
	self.customerWhoStatusBatchSeen = {}
end

function AF:GetWhoStatus(name, includeExpired)
	name = self:NormalizeName(name)
	local status = name and self.whoStatus and self.whoStatus[name]
	if not status or not status.checkedAt then
		return nil
	end
	if not includeExpired and self:Now() - status.checkedAt > WHO_STATUS_TTL then
		return nil
	end
	return status.online
end

function AF:IsCustomerEntryOffline(entry)
	if not entry or entry.ownAlt then
		return false
	end
	if self.HasProfessionOpenFailed and self:HasProfessionOpenFailed(entry) then
		return true
	end
	return self:GetWhoStatus(GetEntryWhoName(entry), true) == false
end

function AF:QueueWhoStatusCheck(name)
	name = self:NormalizeName(name)
	local lib = GetLibWho()
	if not name or not lib or not lib.UserInfo then
		DebugPrint("who unavailable for", tostring(name))
		return false
	end

	self.whoStatus = self.whoStatus or {}
	local now = self:Now()
	local status = self.whoStatus[name]
	if status and status.pending then
		if now - (status.queuedAt or now) <= 15 then
			return false
		end
		status.pending = nil
	end
	if status and status.checkedAt and now - status.checkedAt <= WHO_STATUS_TTL then
		DebugPrint("who cached", name, FormatWhoStatus(status.online))
		return false
	end

	self.whoStatus[name] = status or {}
	status = self.whoStatus[name]
	status.pending = true
	status.queuedAt = now
	DebugPrint("who queue", name)

	local query = 'n-"' .. name .. '"'
	local function onWhoResult(_, results, complete)
		local resultStatus = AF.whoStatus and AF.whoStatus[name]
		if not resultStatus then
			return
		end
		resultStatus.pending = nil
		local hasResults = results and #results > 0
		if not complete and not hasResults then
			DebugPrint("who result", name, FormatWhoStatus(resultStatus.online), "incomplete")
			if AF.RefreshCustomerResults then
				AF:RefreshCustomerResults()
			end
			return
		end
		resultStatus.checkedAt = AF:Now()
		if complete and not hasResults then
			resultStatus.online = false
		else
			resultStatus.online = nil
		end
		for _, result in ipairs(results or {}) do
			if IsWhoResultMatch(name, result) then
				resultStatus.online = true
				break
			end
		end
		DebugPrint("who result", name, FormatWhoStatus(resultStatus.online), "complete", tostring(complete))
		if AF.RefreshCustomerResults then
			AF:RefreshCustomerResults()
		end
	end

	local ok = pcall(lib.Who, lib, query, {
		queue = lib.WHOLIB_QUEUE_QUIET,
		callback = onWhoResult,
		noRetry = true,
	})
	if not ok then
		DebugPrint("who queue failed", name)
		status.pending = nil
		status.checkedAt = now
		status.online = nil
		return false
	end
	return true
end

function AF:QueueCustomerWhoStatusChecks(rows, startQueue, batchSeen)
	local lib = GetLibWho()
	if not lib then
		DebugPrint("LibWho not loaded")
		return 0
	end
	if not startQueue then
		return 0
	end

	local queued = 0
	local seen = {}
	batchSeen = batchSeen or {}
	for _, entry in ipairs(rows or {}) do
		local name = GetEntryWhoName(entry)
		if name and not seen[name] and not batchSeen[name] and ShouldWhoCheckEntry(entry) then
			seen[name] = true
			batchSeen[name] = true
			if self:QueueWhoStatusCheck(name) then
				queued = queued + 1
				if queued >= WHO_STATUS_LIMIT then
					break
				end
			end
		end
	end

	if queued > 0 then
		KickWhoQueue(tostring(queued))
	end
	return queued
end

function AF:CheckWhoStatusNow(name)
	name = self:NormalizeName(name)
	if not name then
		self:Print(self:Text("WHO_USAGE"))
		return
	end
	self.whoStatus = self.whoStatus or {}
	self.whoStatus[name] = nil
	if self:QueueWhoStatusCheck(name) then
		KickWhoQueue(name)
		self:Print(self:Text("WHO_CHECK_STARTED", name))
	else
		self:Print(self:Text("WHO_CHECK_NOT_STARTED", name))
	end
end
