local _, AF = ...

local WHO_STATUS_TTL = 300
local WHO_STATUS_LIMIT = 5
local WHO_SYSTEM_SUPPRESS_AFTER_QUERY = 30
local WHO_SYSTEM_SUPPRESS_AFTER_RESULT = 0.5

local function GetLibWho()
	return LibStub and LibStub:GetLibrary("LibWho-2.0", true)
end

local function IsWhoCountSystemMessage(message)
	if type(message) ~= "string" then
		return false
	end
	if WHO_NUM_RESULTS then
		local pattern = tostring(WHO_NUM_RESULTS):gsub("%%d", "%%d+")
		if message:find(pattern) then
			return true
		end
	end
	return message:match("^%d+ players? total$") ~= nil
end

local function IsWhoResultSystemMessage(message)
	if type(message) ~= "string" then
		return false
	end
	local plain = message
		:gsub("|c%x%x%x%x%x%x%x%x", "")
		:gsub("|r", "")
		:gsub("|H.-|h(.-)|h", "%1")
	local whoNames = AF.suppressWhoSystemNames
	if plain:match("%[[^%]]+%].*:") then
		return true
	end
	if not whoNames then
		return false
	end
	for name in pairs(whoNames) do
		if plain:lower():find(tostring(name):lower(), 1, true) then
			return true
		end
	end
	return false
end

local function SuppressOwnWhoSystemMessage(_, _, message)
	if AF.suppressWhoSystemUntil and AF:Now() <= AF.suppressWhoSystemUntil and (IsWhoCountSystemMessage(message) or IsWhoResultSystemMessage(message)) then
		return true
	end
	return false
end

function AF:GetCustomerEntryWhoName(entry)
	return AF:NormalizeName(entry and (entry.orderTarget or entry.name or entry.target))
end

local function GetEntryWhoName(entry)
	return AF:GetCustomerEntryWhoName(entry)
end

local function GetWhoResultName(result)
	return AF:NormalizeName(result and (result.fullName or result.Name or result.name))
end

local function NormalizeWhoQueryName(name, preserveRealmless)
	if not name or name == "" then
		return nil
	end
	name = tostring(name):gsub("%s+", "")
	if preserveRealmless and not name:find("-", 1, true) then
		return name
	end
	return AF:NormalizeName(name)
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
	if entry.guildMember then
		return false
	end
	if AF:GetWhoStatus(GetEntryWhoName(entry)) == true then
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

local function EntryMatchesWhoName(entry, name)
	if not entry or not name then
		return false
	end
	local normalizedName = AF:NormalizeName(name)
	local baseName = tostring(normalizedName or name):match("^([^-]+)")
	local orderTarget = AF:NormalizeName(entry.orderTarget or entry.name)
	local target = AF:NormalizeName(entry.target)
	local orderBase = tostring(orderTarget or ""):match("^([^-]+)")
	local targetBase = tostring(target or ""):match("^([^-]+)")
	return orderTarget == normalizedName
		or target == normalizedName
		or (baseName and orderBase and baseName:lower() == orderBase:lower())
		or (baseName and targetBase and baseName:lower() == targetBase:lower())
end

local function KickWhoQueue(label)
	local lib = GetLibWho()
	if not lib or not lib.AskWhoNext then
		return
	end
	DebugPrint("who start", label or "")
	AF.customerWhoLastKickAt = AF:Now()
	AF.suppressWhoSystemUntil = AF:Now() + WHO_SYSTEM_SUPPRESS_AFTER_QUERY
	if AF.UpdateCustomerWhoRefreshButtons then
		AF:UpdateCustomerWhoRefreshButtons()
		C_Timer.After(tonumber(AF.LIVE_QUERY_TIMEOUT) or 5, function()
			AF:UpdateCustomerWhoRefreshButtons()
		end)
	end
	pcall(lib.AskWhoNext, lib)
end

local function PromoteWhoQuery(lib, query, queue)
	local queued = lib and lib.Queue and queue and lib.Queue[queue]
	if not queued then
		return false
	end
	for index, args in ipairs(queued) do
		if args.query == query then
			if index > 1 then
				table.remove(queued, index)
				table.insert(queued, 1, args)
			end
			return true
		end
	end
	return false
end

function AF:InitializeWhoStatus()
	self.whoStatus = self.whoStatus or {}
	self.whoStatusDebug = self.whoStatusDebug == true
	if ChatFrame_AddMessageEventFilter and not self.whoStatusChatFilterRegistered then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", SuppressOwnWhoSystemMessage)
		self.whoStatusChatFilterRegistered = true
	end
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
	local now = self:Now()
	if status and status.checkedAt then
		if not includeExpired and now - status.checkedAt > WHO_STATUS_TTL then
			return nil
		end
		return status.online
	end

	local onlineSeenAt = name and self.db and self.db.whoOnlineCache and tonumber(self.db.whoOnlineCache[name])
	if onlineSeenAt then
		if now - onlineSeenAt <= WHO_STATUS_TTL then
			return true
		end
		self.db.whoOnlineCache[name] = nil
	end
	return nil
end

function AF:IsWhoStatusPending(name)
	name = self:NormalizeName(name)
	local status = name and self.whoStatus and self.whoStatus[name]
	return status and status.pending == true
end

function AF:IsCustomerWhoStatusReady()
	local lastKickAt = tonumber(self.customerWhoLastKickAt)
	return not lastKickAt or self:Now() - lastKickAt >= (tonumber(self.LIVE_QUERY_TIMEOUT) or 5)
end

function AF:GetCustomerWhoStatusReadyRemaining()
	local lastKickAt = tonumber(self.customerWhoLastKickAt)
	if not lastKickAt then
		return 0
	end
	local remaining = (tonumber(self.LIVE_QUERY_TIMEOUT) or 5) - (self:Now() - lastKickAt)
	return math.max(0, math.ceil(remaining))
end

function AF:IsCustomerEntryWhoRefreshAvailable(entry)
	if not entry or entry.tutorialFake or entry.ownAlt then
		return false
	end
	local name = GetEntryWhoName(entry)
	return name and self:IsCustomerWhoStatusReady()
end

function AF:IsCustomerEntryOnline(entry)
	if not entry or entry.ownAlt then
		return false
	end
	if entry.guildMember then
		return entry.guildOnline == true
	end
	return self:GetWhoStatus(GetEntryWhoName(entry)) == true
end

function AF:IsCustomerEntryOffline(entry)
	if not entry or entry.ownAlt then
		return false
	end
	if entry.guildMember then
		return entry.guildOnline == false
	end
	if self.HasProfessionOpenFailed and self:HasProfessionOpenFailed(entry) then
		return true
	end
	return self:GetWhoStatus(GetEntryWhoName(entry)) == false
end

function AF:MarkCustomerWhoOnline(name)
	name = self:NormalizeName(name)
	if not name then
		return
	end

	local now = self:Now()
	self.db.whoOnlineCache = self.db.whoOnlineCache or {}
	self.db.whoOnlineCache[name] = now
	for _, itemCache in pairs(self.db and self.db.customerCache or {}) do
		for _, entry in pairs(itemCache or {}) do
			if EntryMatchesWhoName(entry, name) then
				entry.updatedAt = now
			end
		end
	end
	for _, lead in pairs(self.db and self.db.tradeLeadCache or {}) do
		if EntryMatchesWhoName(lead, name) then
			lead.updatedAt = now
		end
	end
	for _, row in ipairs(self.customerRows or {}) do
		if row.entry and EntryMatchesWhoName(row.entry, name) then
			row.entry.updatedAt = now
		end
	end
end

function AF:ClearCustomerWhoOnline(name)
	name = self:NormalizeName(name)
	if name and self.db and self.db.whoOnlineCache then
		self.db.whoOnlineCache[name] = nil
	end
end

function AF:QueueWhoStatusCheck(name, preserveRealmless, forceRefresh, priority)
	name = NormalizeWhoQueryName(name, preserveRealmless)
	local lib = GetLibWho()
	if not name or not lib or not lib.UserInfo then
		DebugPrint("who unavailable for", tostring(name))
		return false
	end

	self.whoStatus = self.whoStatus or {}
	local now = self:Now()
	local status = self.whoStatus[name]
	local query = 'n-"' .. name .. '"'
	if status and status.pending then
		DebugPrint("who already queued", name)
		if priority then
			local promoted = PromoteWhoQuery(lib, query, lib.WHOLIB_QUEUE_QUIET)
			if self.RefreshCustomerWhoLoadingIndicators then
				self:RefreshCustomerWhoLoadingIndicators()
			end
			return promoted
		end
		return false
	end
	if not forceRefresh and status and status.checkedAt and now - status.checkedAt <= WHO_STATUS_TTL then
		DebugPrint("who cached", name, FormatWhoStatus(status.online))
		return false
	end

	self.whoStatus[name] = status or {}
	status = self.whoStatus[name]
	status.pending = true
	status.queuedAt = now
	DebugPrint("who queue", name)

	local baseName = tostring(name):match("^([^-]+)") or name
	local function onWhoResult(_, results, complete)
		local resultStatus = AF.whoStatus and AF.whoStatus[name]
		if not resultStatus then
			return
		end
		resultStatus.pending = nil
		local hasResults = results and #results > 0
		if not complete and not hasResults then
			DebugPrint("who result", name, FormatWhoStatus(resultStatus.online), "incomplete")
			AF.suppressWhoSystemUntil = AF:Now() + WHO_SYSTEM_SUPPRESS_AFTER_RESULT
			if AF.RefreshCustomerResults then
				AF:RefreshCustomerResults()
			end
			return
		end
		local previousCheckedAt = resultStatus.checkedAt
		resultStatus.checkedAt = AF:Now()
		AF.suppressWhoSystemUntil = resultStatus.checkedAt + WHO_SYSTEM_SUPPRESS_AFTER_RESULT
		local wasOnline = resultStatus.online == true
		local matched = false
		if complete and not hasResults and not wasOnline then
			resultStatus.online = false
		else
			resultStatus.online = nil
		end
		for _, result in ipairs(results or {}) do
			if IsWhoResultMatch(name, result) then
				resultStatus.online = true
				AF:MarkCustomerWhoOnline(name)
				AF:MarkCustomerWhoOnline(GetWhoResultName(result))
				matched = true
				break
			end
		end
		if wasOnline and not matched then
			resultStatus.online = true
			AF:MarkCustomerWhoOnline(name)
			resultStatus.checkedAt = previousCheckedAt or resultStatus.checkedAt
		elseif resultStatus.online ~= true then
			AF:ClearCustomerWhoOnline(name)
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
		if self.RefreshCustomerWhoLoadingIndicators then
			self:RefreshCustomerWhoLoadingIndicators()
		end
		return false
	end
	if priority then
		PromoteWhoQuery(lib, query, lib.WHOLIB_QUEUE_QUIET)
	end
	self.suppressWhoSystemUntil = now + WHO_SYSTEM_SUPPRESS_AFTER_QUERY
	self.suppressWhoSystemNames = {
		[name] = true,
		[baseName] = true,
	}
	return true
end

function AF:QueueCustomerWhoStatusChecks(rows, startQueue, batchSeen, kickPending, limit)
	local lib = GetLibWho()
	if not lib then
		DebugPrint("LibWho not loaded")
		return 0
	end
	if not startQueue then
		return 0
	end

	local queued = 0
	local skippedPending = 0
	local queueLimit = tonumber(limit) or WHO_STATUS_LIMIT
	local seen = {}
	batchSeen = batchSeen or {}
	for _, entry in ipairs(rows or {}) do
		local name = GetEntryWhoName(entry)
		if name and not seen[name] and not batchSeen[name] and ShouldWhoCheckEntry(entry) then
			seen[name] = true
			if self:IsWhoStatusPending(name) then
				if kickPending then
					DebugPrint("who skip queued", name)
				end
				skippedPending = skippedPending + 1
			elseif self:QueueWhoStatusCheck(name) then
				batchSeen[name] = true
				queued = queued + 1
				if queued >= queueLimit then
					break
				end
			else
				batchSeen[name] = true
			end
		end
	end

	if queued > 0 or (kickPending and skippedPending > 0) then
		if self.RefreshCustomerWhoLoadingIndicators then
			self:RefreshCustomerWhoLoadingIndicators()
		end
		KickWhoQueue(tostring(queued))
	end
	return queued
end

function AF:RefreshCustomerEntryWhoStatus(entry)
	if not self:IsCustomerEntryWhoRefreshAvailable(entry) then
		return false
	end

	local name = GetEntryWhoName(entry)
	if not name then
		return false
	end

	local queued = self:QueueWhoStatusCheck(name, nil, true, true)
	if self.RefreshCustomerWhoLoadingIndicators then
		self:RefreshCustomerWhoLoadingIndicators()
	end
	if queued then
		local now = self:Now()
		local waitTime = tonumber(self.LIVE_QUERY_TIMEOUT) or 5
		if not self.customerWhoLastKickAt or now - self.customerWhoLastKickAt >= waitTime then
			KickWhoQueue(name)
		end
	end
	if self.UpdateCustomerWhoRefreshButtons then
		self:UpdateCustomerWhoRefreshButtons()
	end
	return queued
end

function AF:CheckWhoStatusNow(name)
	name = NormalizeWhoQueryName(name, true)
	if not name then
		self:Print(self:Text("WHO_USAGE"))
		return
	end
	self.whoStatus = self.whoStatus or {}
	self.whoStatus[name] = nil
	if self:QueueWhoStatusCheck(name, true) then
		KickWhoQueue(name)
		self:Print(self:Text("WHO_CHECK_STARTED", name))
	else
		self:Print(self:Text("WHO_CHECK_NOT_STARTED", name))
	end
end
