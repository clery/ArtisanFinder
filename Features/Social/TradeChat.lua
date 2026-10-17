local _, AF = ...

local DEFAULT_TRADE_LEAD_MINUTES = 15
local DEBUG_TRADE_LEAD_COUNT = 5
local DEBUG_TRADE_NAMES = {
	"Marielle",
	"Thorgann",
	"Velindra",
	"Orryn",
	"Selwen",
}
local PROFESSION_SPELL_TO_SKILL_LINE = {
	[2259] = 171, -- Alchemy
	[2018] = 164, -- Blacksmithing
	[7411] = 333, -- Enchanting
	[4036] = 202, -- Engineering
	[45357] = 773, -- Inscription
	[25229] = 755, -- Jewelcrafting
	[2108] = 165, -- Leatherworking
	[3908] = 197, -- Tailoring
}

local KNOWN_PROFESSION_SKILL_LINES = {
	[164] = true, -- Blacksmithing
	[165] = true, -- Leatherworking
	[171] = true, -- Alchemy
	[197] = true, -- Tailoring
	[202] = true, -- Engineering
	[333] = true, -- Enchanting
	[755] = true, -- Jewelcrafting
	[773] = true, -- Inscription
}
local function ExtractTradeLinks(message)
	local links = {}
	local seen = {}
	message = tostring(message or "")
	for link, name in message:gmatch("(|c%x%x%x%x%x%x%x%x|Htrade:[^|]+|h%[(.-)%]|h|r)") do
		local key = link:match("|Htrade:([^|]+)|h") or link
		if not seen[key] then
			seen[key] = true
			table.insert(links, { link = link, name = name, key = key })
		end
	end
	for link, name in message:gmatch("(|Htrade:[^|]+|h%[(.-)%]|h)") do
		local key = link:match("|Htrade:([^|]+)|h") or link
		if not seen[key] then
			seen[key] = true
			table.insert(links, { link = link, name = name, key = key })
		end
	end
	return links
end

local function GetTradeLinkProfessionCandidates(link)
	local body = tostring(link or ""):match("|Htrade:([^|]+)|h")
	local candidates = {}
	for numberText in tostring(body or ""):gmatch("(%d+)") do
		local number = tonumber(numberText)
		if number then
			local mappedSkillLine = PROFESSION_SPELL_TO_SKILL_LINE[number]
			if mappedSkillLine then
				candidates[mappedSkillLine] = true
			end
			if KNOWN_PROFESSION_SKILL_LINES[number] then
				candidates[number] = true
			end
		end
	end
	return candidates
end

local function AddCandidate(candidates, value)
	value = AF:GetSupportedProfessionID(value)
	if value and value ~= 0 then
		candidates[value] = true
	end
end

local function AddProfessionInfoCandidates(candidates, professionInfo)
	if type(professionInfo) ~= "table" then
		return
	end
	AddCandidate(candidates, professionInfo.profession)
	AddCandidate(candidates, professionInfo.professionID)
	AddCandidate(candidates, professionInfo.skillLineID)
	AddCandidate(candidates, professionInfo.parentProfession)
	AddCandidate(candidates, professionInfo.parentProfessionID)
	AddCandidate(candidates, professionInfo.parentSkillLineID)
	AddCandidate(candidates, professionInfo.sourceSkillLineID)
end

local function HasIntersection(left, right)
	for key in pairs(left or {}) do
		if right and right[key] then
			return true
		end
	end
	return false
end

local function TradeLeadMatchesFilter(row, filterText)
	if filterText == "" then
		return true
	end
	local haystack = table.concat({
		row.name or "",
		row.professionName or "",
		row.note or "",
	}, " "):lower()
	return haystack:find(filterText, 1, true)
end

local function MarkTradeLeadSeen(seenNames, key, row)
	if not seenNames then
		return
	end
	seenNames[key] = true
	if row.name then
		seenNames[row.name] = true
	end
	if row.target then
		seenNames[row.target] = true
	end
end

local function CopyTradeLead(lead)
	local copy = {}
	for key, value in pairs(lead or {}) do
		if key == "professionCandidates" and type(value) == "table" then
			local candidates = {}
			for candidate in pairs(value) do
				candidates[candidate] = true
			end
			copy[key] = candidates
		else
			copy[key] = value
		end
	end
	copy.snapshotUpdatedAt = copy.updatedAt
	return copy
end

function AF:InitializeTradeChat()
	self.db.tradeLeads = self.db.tradeLeads or {}
	self.tradeLeads = self.db.tradeLeads
	self:PruneTradeLeads()
end

function AF:GetTradeLeadTTL()
	local minutes = tonumber(self.db and self.db.tradeLeadMinutes) or DEFAULT_TRADE_LEAD_MINUTES
	return minutes * 60
end

function AF:ClearDebugTradeLeads()
	self.tradeLeads = self.tradeLeads or self.db and self.db.tradeLeads or {}
	for key, lead in pairs(self.tradeLeads or {}) do
		if lead.debug then
			self.tradeLeads[key] = nil
		end
	end
end

function AF:InjectDebugTradeLeads()
	self.tradeLeads = self.tradeLeads or self.db and self.db.tradeLeads or {}
	self:ClearDebugTradeLeads()
	if not self:IsDevFakeRowsEnabled() then
		return
	end

	local profile = self.db.artisanProfile
	local now = self:Now()
	local professions = {}
	for professionKey, profession in pairs(profile and profile.professions or {}) do
		local professionID = tonumber(profession.id) or tonumber(professionKey)
		if professionID then
		table.insert(professions, {
			id = professionID,
			link = profession.professionLink,
		})
		end
	end
	if #professions == 0 then
		return
	end

	for index = 1, DEBUG_TRADE_LEAD_COUNT do
		local profession = professions[((index - 1) % #professions) + 1]
		local selectedProfessionID = tonumber(self.currentCustomerProfessionID)
		if selectedProfessionID and selectedProfessionID ~= 0 then
			for _, candidateProfession in ipairs(professions) do
				if tonumber(candidateProfession.id) == selectedProfessionID then
					profession = candidateProfession
					break
				end
			end
		end
		local candidates = {}
		candidates[profession.id] = true
		local name = self.IsForever and (DEBUG_TRADE_NAMES[index] .. " Hearthstone") or (DEBUG_TRADE_NAMES[index] .. "-" .. (GetRealmName() or ""))
		self.tradeLeads["__debug_trade_" .. tostring(index)] = {
			name = name,
			target = name,
			professionLink = profession.link,
			professionCandidates = candidates,
			updatedAt = now,
			tradeLead = true,
			certified = false,
			debug = true,
		}
	end
end

function AF:OnTradeChatMessage(message, sender, _, channelName, _, _, _, _, channelBaseName)
    self.tradeChatDiagnostics = self.tradeChatDiagnostics or {received=0, stored=0}
    local diagnostic = self.tradeChatDiagnostics
    diagnostic.received = diagnostic.received + 1
    diagnostic.stage = "received"
	if self:IsProtectedActionRestricted() then
        diagnostic.stage = "protected activity restriction"
        self:DebugLog("trade", "skipped chat: protected activity restriction")
		return
	end
	if self:IsSecretValue(message) or self:IsSecretValue(sender) or self:IsSecretValue(channelName) or self:IsSecretValue(channelBaseName) then
		diagnostic.stage = "secret payload"
        self:DebugLog("trade", "skipped secret chat payload")
		return
	end
    if self.db and self.db.debugEnabled then
        local hyperlink = tostring(message or ""):find("|H", 1, true)
        if diagnostic.received <= 3 or hyperlink or self:IsTradeChannelName(channelName) or self:IsTradeChannelName(channelBaseName) then
            self:DebugLog("trade", string.format("received #%d sender=%s channel=%s base=%s payload=%s",
                diagnostic.received, tostring(sender), tostring(channelName), tostring(channelBaseName), tostring(message):sub(1,2048)))
        end
    end
	if not (self.capabilities and self.capabilities.passiveTradeDiscovery) and self:IsInUnavailableActivity() then
        diagnostic.stage = "unavailable activity"
        self:DebugLog("trade", "skipped chat: unavailable activity")
		return
	end
	if not self:IsTradeChannelName(channelName) and not self:IsTradeChannelName(channelBaseName) then
        diagnostic.stage = "not a Trade channel"
        if tostring(message or ""):find("|Htrade:", 1, true) then
            self:DebugLog("trade", "skipped profession link: channel="..tostring(channelName).." base="..tostring(channelBaseName))
        end
		return
	end

	local links = ExtractTradeLinks(message)
    if self.GetAdditionalTradeAdvertisements then
        for _, info in ipairs(self:GetAdditionalTradeAdvertisements(message)) do links[#links + 1] = info end
    end
	if self:IsDevTrafficLogsEnabled() and #links > 0 then
		self:DebugLog("trade", string.format("%s: %d profession link(s)", tostring(sender or "?"), #links))
	end
    diagnostic.stage = "parsed"
    self:DebugLog("trade", "parsed advertisements="..#links)
	if #links == 0 or not sender then
        diagnostic.stage = #links == 0 and "no recognized links" or "missing sender"
        self:DebugLog("trade", "skipped: "..diagnostic.stage)
		return
	end

	local name = self:NormalizeName(sender)
	if not name or name == self:NormalizeName(self.playerName or self:GetPlayerFullName()) then
        diagnostic.stage = not name and "invalid sender" or "own advertisement"
        self:DebugLog("trade", "skipped: "..diagnostic.stage.." normalized="..tostring(name))
		return
	end

	self.db.tradeLeads = self.db.tradeLeads or {}
	self.tradeLeads = self.db.tradeLeads
	for leadKey, lead in pairs(self.tradeLeads) do
		if lead.target == name and not lead.debug then
			self.tradeLeads[leadKey] = nil
		end
	end

	local now = self:Now()
	self.db.tradeLeadCache = self.db.tradeLeadCache or {}
	for index, linkInfo in ipairs(links) do
		local leadKey = name .. ":" .. tostring(linkInfo.key or index)
		local lead = {
			name = name,
			target = name,
			professionLink = not linkInfo.recipeID and linkInfo.link or nil,
            recipeLink = linkInfo.recipeID and linkInfo.link or nil,
            recipeID = linkInfo.recipeID,
			professionCandidates = linkInfo.professionCandidates or (self.GetTradeAdvertisementProfessionCandidates
                and self:GetTradeAdvertisementProfessionCandidates(linkInfo.link)
                or GetTradeLinkProfessionCandidates(linkInfo.link)),
			updatedAt = now,
			tradeLead = true,
			certified = false,
		}
        if self.IsForever and self.RememberProfessionLink and lead.professionLink then
            for id in pairs(lead.professionCandidates) do self:RememberProfessionLink(name,id,lead.professionLink) end
        end
        self:DebugLog("trade", "link="..tostring(linkInfo.key).." profession="..tostring(next(lead.professionCandidates or {}) or "unresolved"))
		self.tradeLeads[leadKey] = lead
		self.db.tradeLeadCache[leadKey] = lead
	end
    diagnostic.stage = "stored"
    diagnostic.stored = diagnostic.stored + #links
	self:DebugLog("trade", string.format("stored leads sender=%s count=%d", tostring(name or ""), #links))
    local frozen = not self.IsForever and self.db and self.db.freezeTradeLeadRows == true
    self:DebugLog("trade", "refresh frozen="..tostring(frozen).." handler="..tostring(type(self.RefreshCustomerResults)).." panel="..tostring(self.customerFrame ~= nil))
	if not frozen and self.RefreshCustomerResults then
		self:RequestCustomerResultsRefresh()
	end
end

function AF:PrintTradeChatDiagnostics()
    local state = self.tradeChatDiagnostics or {}
    local registered = self.frame and self.frame.IsEventRegistered and self.frame:IsEventRegistered("CHAT_MSG_CHANNEL")
    self:DebugLog("trade", string.format("STATUS registered=%s received=%d stored=%d lastStage=%s flavor=%s",
        tostring(registered), state.received or 0, state.stored or 0, tostring(state.stage), tostring(self.flavor)))
    local active, cached, unresolved = 0, 0, 0
    for _, lead in pairs(self.tradeLeads or {}) do
        active = active + 1
        if not next(lead.professionCandidates or {}) then unresolved = unresolved + 1 end
    end
    for _ in pairs(self.db.tradeLeadCache or {}) do cached = cached + 1 end
    self:DebugLog("trade", string.format("CACHE active=%d cached=%d unresolved=%d frozen=%s item=%s professionFilter=%s sourceFilter=%s",
        active, cached, unresolved, tostring(self.db.freezeTradeLeadRows), tostring(self.currentCustomerItemID), tostring(self.directoryProfession), tostring(self.directorySource)))
    if self.GetForeverDirectoryRows then
        local query = self.customerFrame and self.customerFrame.search and self.customerFrame.search:GetText() or ""
        local rows = self:GetForeverDirectoryRows(query, self.directoryProfession, self.directorySource)
        self:DebugLog("trade", "DIRECTORY rows="..#rows.." search="..tostring(query))
    end
end

function AF:PruneTradeLeads()
	if self.db then
		self.db.tradeLeads = self.db.tradeLeads or {}
		self.tradeLeads = self.db.tradeLeads
	end
	local now = self:Now()
	local ttl = self:GetTradeLeadTTL()
	for name, lead in pairs(self.tradeLeads or {}) do
		if not lead.updatedAt or now - lead.updatedAt > ttl then
			self.tradeLeads[name] = nil
		end
	end
end

function AF:RebuildCustomerTradeLeadSnapshot(itemID, professionID, recipeID)
	self:PruneTradeLeads()
	local leads = {}
	for key, lead in pairs(self.tradeLeads or {}) do
		leads[key] = CopyTradeLead(lead)
	end
	local cache = {}
	for key, lead in pairs(self.db and self.db.tradeLeadCache or {}) do
		cache[key] = CopyTradeLead(lead)
	end
	self.customerTradeLeadSnapshot = {
		itemID = tonumber(itemID) or 0,
		professionID = tonumber(professionID) or 0,
		recipeID = tonumber(recipeID) or 0,
		leads = leads,
		cache = cache,
	}
end

function AF:GetCustomerTradeLeadSnapshotLeads(itemID, professionID, recipeID, includeCache)
	local snapshot = self.customerTradeLeadSnapshot
	if not snapshot then
		return nil
	end
	if snapshot.itemID ~= (tonumber(itemID) or 0)
		or snapshot.professionID ~= (tonumber(professionID) or 0)
		or snapshot.recipeID ~= (tonumber(recipeID) or 0)
	then
		return nil
	end
	if includeCache then
		return snapshot.cache
	end
	return snapshot.leads
end

function AF:GetCachedTradeLeadFallbackRows(itemID, professionID, filterText, seenNames, recipeID)
	local rows = {}
	local now = self:Now()
	local normalizedProfessionID = tonumber(professionID) or 0
	local recipeProfessionCandidates = self:GetCustomerRecipeProfessionCandidates(recipeID, normalizedProfessionID)
	local hasRecipeProfessionCandidates = next(recipeProfessionCandidates) ~= nil
	filterText = tostring(filterText or ""):lower()
	local sourceLeads = self.db and self.db.tradeLeadCache or {}
	if not self.IsForever and self.db and self.db.freezeTradeLeadRows == true then
		sourceLeads = self:GetCustomerTradeLeadSnapshotLeads(itemID, normalizedProfessionID, recipeID, true) or {}
	end

	for cacheKey, lead in pairs(sourceLeads) do
		local updatedAt = tonumber(lead and lead.updatedAt) or 0
		local hasProfessionCandidates = lead.professionCandidates and next(lead.professionCandidates) ~= nil
		local exactProfessionMatch = hasRecipeProfessionCandidates
			and hasProfessionCandidates
			and HasIntersection(lead.professionCandidates, recipeProfessionCandidates)
		if exactProfessionMatch
			and updatedAt > 0
			and now - updatedAt <= self.CACHE_MAX_AGE
			and not (seenNames and (seenNames[cacheKey] or seenNames[lead.name] or seenNames[lead.target]))
		then
			local row = {
				name = lead.name,
				target = lead.target,
				itemID = itemID,
				recipeID = tonumber(recipeID),
				professionID = normalizedProfessionID,
				professionName = normalizedProfessionID ~= 0 and self:GetProfessionName(normalizedProfessionID) or nil,
				professionLink = lead.professionLink,
				updatedAt = lead.updatedAt,
				snapshotUpdatedAt = lead.snapshotUpdatedAt or lead.updatedAt,
				tradeLead = true,
				certified = false,
				tradeProfessionMatch = true,
				offlineCached = true,
				offlineFallback = true,
				note = self:Text("MISSING_ADDON_DATA"),
			}
			if TradeLeadMatchesFilter(row, filterText) and self:IsCustomerEntryOrderEligible(row) then
				table.insert(rows, row)
			end
		end
	end

	return rows
end

function AF:GetCustomerRecipeProfessionCandidates(recipeID, professionID)
	local candidates = {}
	AddCandidate(candidates, professionID)

	if recipeID then
		local professionInfo = C_TradeSkillUI.GetProfessionInfoByRecipeID(recipeID)
		AddProfessionInfoCandidates(candidates, professionInfo)
	end

	return candidates
end

function AF:GetTradeLeadRows(itemID, professionID, filterText, seenNames, recipeID)
	local rows = {}
	local normalizedProfessionID = tonumber(professionID) or 0
	local recipeProfessionCandidates = self:GetCustomerRecipeProfessionCandidates(recipeID, normalizedProfessionID)
	local hasRecipeProfessionCandidates = next(recipeProfessionCandidates) ~= nil
	filterText = tostring(filterText or ""):lower()
	local sourceLeads = self.tradeLeads or {}
	if not self.IsForever and self.db and self.db.freezeTradeLeadRows == true then
		sourceLeads = self:GetCustomerTradeLeadSnapshotLeads(itemID, normalizedProfessionID, recipeID) or {}
	end

	for name, lead in pairs(sourceLeads) do
		local hasProfessionCandidates = lead.professionCandidates and next(lead.professionCandidates) ~= nil
		local exactProfessionMatch = hasRecipeProfessionCandidates
			and hasProfessionCandidates
			and HasIntersection(lead.professionCandidates, recipeProfessionCandidates)
		if exactProfessionMatch and not (seenNames and seenNames[name]) then
			local row = {
				name = lead.name,
				target = lead.target,
				itemID = itemID,
				recipeID = tonumber(recipeID),
				professionID = normalizedProfessionID,
				professionName = normalizedProfessionID ~= 0 and self:GetProfessionName(normalizedProfessionID) or nil,
				professionLink = lead.professionLink,
				updatedAt = lead.updatedAt,
				snapshotUpdatedAt = lead.snapshotUpdatedAt or lead.updatedAt,
				tradeLead = true,
				certified = false,
				tradeProfessionMatch = exactProfessionMatch == true,
				note = self:Text("MISSING_ADDON_DATA"),
			}
			if TradeLeadMatchesFilter(row, filterText) and self:IsCustomerEntryOrderEligible(row) then
				table.insert(rows, row)
				MarkTradeLeadSeen(seenNames, name, row)
			end
		end
	end

	return rows
end
