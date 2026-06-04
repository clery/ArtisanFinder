local _, AF = ...

local WHO_STATUS_TTL = 300
local WHO_SYSTEM_SUPPRESS_AFTER_QUERY = 30
local WHO_SYSTEM_SUPPRESS_AFTER_RESULT = 0.5
local WHO_RESPONSE_TIMEOUT = 5

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
	local name = AF:NormalizeName(entry and (entry.orderTarget or entry.name or entry.target))
	if AF:IsOwnArtisanCharacter(name) then
		return nil
	end
	return name
end

local function GetEntryWhoName(entry)
	return AF:GetCustomerEntryWhoName(entry)
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

local function RefreshWhoUi()
	if AF.RefreshCustomerWhoLoadingIndicators then
		AF:RefreshCustomerWhoLoadingIndicators()
	end
	if AF.RefreshCustomerResults then
		AF:RefreshCustomerResults()
	end
end

local function CompleteWhoQuery(request, results, complete)
	if not request or AF.whoStatusActive ~= request then
		return
	end

	local resultStatus = AF.whoStatus and AF.whoStatus[request.name]
	if resultStatus then
		resultStatus.pending = nil
		local hasResults = results and #results > 0
		if complete or hasResults then
			resultStatus.checkFailedAt = nil
			local previousCheckedAt = resultStatus.checkedAt
			resultStatus.checkedAt = AF:Now()
			local wasOnline = resultStatus.online == true
			local matched = false
			if complete and not hasResults and not wasOnline then
				resultStatus.online = false
			else
				resultStatus.online = nil
			end
			for _, result in ipairs(results or {}) do
				if IsWhoResultMatch(request.name, result) then
					resultStatus.online = true
					AF:MarkCustomerWhoOnline(request.name)
					AF:MarkCustomerWhoOnline(GetWhoResultName(result))
					matched = true
					break
				end
			end
			if wasOnline and not matched then
				resultStatus.online = true
				AF:MarkCustomerWhoOnline(request.name)
				resultStatus.checkedAt = previousCheckedAt or resultStatus.checkedAt
			elseif resultStatus.online ~= true then
				AF:ClearCustomerWhoOnline(request.name)
			end
		else
			resultStatus.online = nil
			resultStatus.checkFailedAt = AF:Now()
		end
	end

	AF.whoStatusActive = nil
	AF.suppressWhoSystemUntil = AF:Now() + WHO_SYSTEM_SUPPRESS_AFTER_RESULT
	RefreshWhoUi()
	if AF.UpdateCustomerWhoRefreshButtons then
		AF:UpdateCustomerWhoRefreshButtons()
	end
end

local function ReadWhoResults()
	local numWhos, totalCount = C_FriendList.GetNumWhoResults()
	numWhos = tonumber(numWhos) or 0
	totalCount = tonumber(totalCount) or numWhos
	local results = {}
	for index = 1, numWhos do
		local info = C_FriendList.GetWhoInfo(index)
		if info then
			results[#results + 1] = info
		end
	end
	local maxWhos = tonumber(MAX_WHOS_FROM_SERVER) or 50
	local complete = totalCount == #results and totalCount < maxWhos
	return results, complete
end

local function HandleNativeWhoEvent(_, event, message)
	if not AF.whoStatusActive then
		return
	end
	if event == "CHAT_MSG_SYSTEM" then
		local isCount = IsWhoCountSystemMessage(message)
		if not isCount then
			return
		end
	end
	local results, complete = ReadWhoResults()
	CompleteWhoQuery(AF.whoStatusActive, results, complete)
end

local function EnsureWhoFrame()
	if AF.whoStatusFrame then
		return
	end
	AF.whoStatusFrame = CreateFrame("Frame")
	AF.whoStatusFrame:RegisterEvent("WHO_LIST_UPDATE")
	AF.whoStatusFrame:RegisterEvent("CHAT_MSG_SYSTEM")
	AF.whoStatusFrame:SetScript("OnEvent", HandleNativeWhoEvent)
end

local function StartManualWhoQuery(name)
	local baseName = tostring(name):match("^([^-]+)") or name
	local request = {
		name = name,
		query = 'n-"' .. name .. '"',
		startedAt = AF:Now(),
		suppressNames = {
			[name] = true,
			[baseName] = true,
		},
	}
	AF.whoStatusActive = request
	AF.customerWhoLastKickAt = AF:Now()
	AF.suppressWhoSystemUntil = AF:Now() + WHO_SYSTEM_SUPPRESS_AFTER_QUERY
	AF.suppressWhoSystemNames = request.suppressNames
	if AF.UpdateCustomerWhoRefreshButtons then
		AF:UpdateCustomerWhoRefreshButtons()
		C_Timer.After(tonumber(AF.LIVE_QUERY_TIMEOUT) or 5, function()
			AF:UpdateCustomerWhoRefreshButtons()
		end)
	end
	pcall(C_FriendList.SetWhoToUi, false)
	local ok = pcall(C_FriendList.SendWho, request.query, Enum.SocialWhoOrigin.Social)
	if ok then
		local token = request
		C_Timer.After(WHO_RESPONSE_TIMEOUT, function()
			CompleteWhoQuery(token, {}, false)
		end)
	else
		CompleteWhoQuery(request, {}, false)
	end
	return ok
end

function AF:InitializeWhoStatus()
	self.whoStatus = self.whoStatus or {}
	pcall(C_AddOns.LoadAddOn, "Blizzard_FriendsFrame")
	EnsureWhoFrame()
	if ChatFrame_AddMessageEventFilter and not self.whoStatusChatFilterRegistered then
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", SuppressOwnWhoSystemMessage)
		self.whoStatusChatFilterRegistered = true
	end
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

function AF:IsWhoStatusFailed(name)
	name = self:NormalizeName(name)
	local status = name and self.whoStatus and self.whoStatus[name]
	local failedAt = status and tonumber(status.checkFailedAt)
	if not failedAt then
		return false
	end
	return self:Now() - failedAt <= WHO_STATUS_TTL
end

function AF:IsCustomerWhoStatusReady()
	local lastKickAt = tonumber(self.customerWhoLastKickAt)
	return not self.whoStatusActive and (not lastKickAt or self:Now() - lastKickAt >= (tonumber(self.LIVE_QUERY_TIMEOUT) or 5))
end

function AF:GetCustomerWhoStatusReadyRemaining()
	if self.whoStatusActive and self.whoStatusActive.startedAt then
		local remaining = WHO_RESPONSE_TIMEOUT - (self:Now() - self.whoStatusActive.startedAt)
		return math.max(0, math.ceil(remaining))
	end
	local lastKickAt = tonumber(self.customerWhoLastKickAt)
	if not lastKickAt then
		return 0
	end
	local remaining = (tonumber(self.LIVE_QUERY_TIMEOUT) or 5) - (self:Now() - lastKickAt)
	return math.max(0, math.ceil(remaining))
end

function AF:IsCustomerEntryWhoRefreshAvailable(entry)
	if not self:IsCustomerEntryWhoRefreshable(entry) then
		return false
	end
	local name = GetEntryWhoName(entry)
	return name and self:IsCustomerWhoStatusReady()
end

function AF:IsCustomerEntryWhoRefreshable(entry)
	return entry
		and not entry.tutorialFake
		and not entry.debug
		and not entry.ownAlt
		and not self:IsOwnArtisanCharacter(entry.orderTarget or entry.name or entry.target)
		and not entry.guildMember
		and entry.tradeLead == true
		and GetEntryWhoName(entry) ~= nil
end

function AF:IsCustomerEntryOnline(entry)
	if not entry or entry.ownAlt then
		return false
	end
	if self:IsCustomerEntryWhoCheckFailed(entry) then
		return false
	end
	if entry.guildMember then
		local rosterEntry = self:GetCachedGuildRosterEntry(entry.orderTarget or entry.name or entry.target)
		entry.guildOnline = rosterEntry and rosterEntry.online or nil
		return rosterEntry and rosterEntry.online == true or false
	end
	if not self:IsCustomerEntryWhoRefreshable(entry) then
		return false
	end
	return self:GetWhoStatus(GetEntryWhoName(entry)) == true
end

function AF:IsCustomerEntryWhoCheckFailed(entry)
	if not self:IsCustomerEntryWhoRefreshable(entry) then
		return false
	end
	return self:IsWhoStatusFailed(GetEntryWhoName(entry))
end

function AF:IsCustomerEntryOffline(entry)
	if not entry or entry.ownAlt then
		return false
	end
	if self:IsCustomerEntryWhoCheckFailed(entry) then
		return false
	end
	if entry.guildMember then
		local rosterEntry = self:GetCachedGuildRosterEntry(entry.orderTarget or entry.name or entry.target)
		entry.guildOnline = rosterEntry and rosterEntry.online or nil
		return rosterEntry and rosterEntry.online == false or false
	end
	if not self:IsCustomerEntryWhoRefreshable(entry) then
		return false
	end
	if self:HasProfessionOpenFailed(entry) then
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
	for _, lead in pairs(self.db and self.db.tradeLeadCache or {}) do
		if EntryMatchesWhoName(lead, name) then
			lead.updatedAt = now
		end
	end
	for _, lead in pairs(self.db and self.db.tradeLeads or {}) do
		if EntryMatchesWhoName(lead, name) then
			lead.updatedAt = now
		end
	end
	for _, lead in pairs(self.customerTradeLeadSnapshot and self.customerTradeLeadSnapshot.leads or {}) do
		if EntryMatchesWhoName(lead, name) then
			lead.snapshotUpdatedAt = now
		end
	end
	for _, lead in pairs(self.customerTradeLeadSnapshot and self.customerTradeLeadSnapshot.cache or {}) do
		if EntryMatchesWhoName(lead, name) then
			lead.snapshotUpdatedAt = now
		end
	end
	for _, row in ipairs(self.customerRows or {}) do
		if row.entry and EntryMatchesWhoName(row.entry, name) then
			if row.entry.tradeLead then
				row.entry.snapshotUpdatedAt = now
			else
				row.entry.updatedAt = now
			end
		end
	end
	if self.RefreshCustomerRowAges then
		self:RefreshCustomerRowAges()
	end
end

function AF:ClearCustomerWhoOnline(name)
	name = self:NormalizeName(name)
	if name and self.db and self.db.whoOnlineCache then
		self.db.whoOnlineCache[name] = nil
	end
end

function AF:RefreshCustomerEntryWhoStatus(entry)
	if not self:IsCustomerEntryWhoRefreshAvailable(entry) then
		return false
	end

	local name = GetEntryWhoName(entry)
	if not name then
		return false
	end

	self.whoStatus = self.whoStatus or {}
	self.whoStatus[name] = self.whoStatus[name] or {}
	local status = self.whoStatus[name]
	status.pending = true
	status.requestedAt = self:Now()
	if self:IsCustomerEntryOnline(entry) then
		status.online = true
		status.checkedAt = self:Now()
		self:MarkCustomerWhoOnline(name)
		self:RefreshCustomerResults()
	end

	if self.RefreshCustomerWhoLoadingIndicators then
		self:RefreshCustomerWhoLoadingIndicators()
	end
	local started = StartManualWhoQuery(name)
	if not started then
		status.pending = nil
		if self.RefreshCustomerWhoLoadingIndicators then
			self:RefreshCustomerWhoLoadingIndicators()
		end
	end
	if self.UpdateCustomerWhoRefreshButtons then
		self:UpdateCustomerWhoRefreshButtons()
	end
	return started
end
