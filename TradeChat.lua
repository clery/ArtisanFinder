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
	[2550] = 185, -- Cooking
}

local KNOWN_PROFESSION_SKILL_LINES = {
	[164] = true, -- Blacksmithing
	[165] = true, -- Leatherworking
	[171] = true, -- Alchemy
	[182] = true, -- Herbalism
	[185] = true, -- Cooking
	[186] = true, -- Mining
	[197] = true, -- Tailoring
	[202] = true, -- Engineering
	[333] = true, -- Enchanting
	[356] = true, -- Fishing
	[393] = true, -- Skinning
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
	for number in tostring(body or ""):gmatch("(%d+)") do
		number = tonumber(number)
		local mappedSkillLine = PROFESSION_SPELL_TO_SKILL_LINE[number]
		if mappedSkillLine then
			candidates[mappedSkillLine] = true
		end
		if KNOWN_PROFESSION_SKILL_LINES[number] then
			candidates[number] = true
		end
	end
	return candidates
end

local function AddCandidate(candidates, value)
	value = tonumber(value)
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
	if not self.db or not self.db.debugSelfResults then
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
				name = profession.name or self:GetProfessionName(professionID),
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
		local name = DEBUG_TRADE_NAMES[index] .. "-" .. (GetRealmName() or "")
		self.tradeLeads["__debug_trade_" .. tostring(index)] = {
			name = name,
			target = name,
			professionLink = profession.link,
			professionName = profession.name,
			professionCandidates = candidates,
			updatedAt = now,
			tradeLead = true,
			certified = false,
			debug = true,
		}
	end
end

function AF:OnTradeChatMessage(message, sender)
	if self:IsInCombatLocked() then
		return
	end

	local links = ExtractTradeLinks(message)
	if #links == 0 or not sender then
		return
	end

	local name = self:NormalizeName(sender)
	if not name or name == self:NormalizeName(self.playerName or self:GetPlayerFullName()) then
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
			professionLink = linkInfo.link,
			professionName = linkInfo.name,
			professionCandidates = GetTradeLinkProfessionCandidates(linkInfo.link),
			updatedAt = now,
			tradeLead = true,
			certified = false,
		}
		self.tradeLeads[leadKey] = lead
		self.db.tradeLeadCache[leadKey] = lead
	end

	if self.RefreshCustomerResults then
		self:RefreshCustomerResults()
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

function AF:GetCachedTradeLeadFallbackRows(itemID, professionID, filterText, seenNames, recipeID)
	local rows = {}
	local now = self:Now()
	local normalizedProfessionID = tonumber(professionID) or 0
	local recipeProfessionCandidates = self:GetCustomerRecipeProfessionCandidates(recipeID, normalizedProfessionID)
	local hasRecipeProfessionCandidates = next(recipeProfessionCandidates) ~= nil
	filterText = tostring(filterText or ""):lower()

	for cacheKey, lead in pairs(self.db and self.db.tradeLeadCache or {}) do
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
				professionID = normalizedProfessionID,
				professionName = lead.professionName,
				professionLink = lead.professionLink,
				updatedAt = lead.updatedAt,
				tradeLead = true,
				certified = false,
				tradeProfessionMatch = true,
				offlineCached = true,
				note = self:Text("MISSING_ADDON_DATA"),
			}
			local haystack = table.concat({
				row.name or "",
				row.professionName or "",
				row.note or "",
			}, " "):lower()
			if filterText == "" or haystack:find(filterText, 1, true) then
				table.insert(rows, row)
			end
		end
	end

	return rows
end

function AF:GetCustomerRecipeProfessionCandidates(recipeID, professionID)
	local candidates = {}
	AddCandidate(candidates, professionID)

	if recipeID and C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID then
		local ok, professionInfo = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeID)
		if ok then
			AddProfessionInfoCandidates(candidates, professionInfo)
		end
	end

	return candidates
end

function AF:GetTradeLeadRows(itemID, professionID, filterText, seenNames, recipeID)
	self:PruneTradeLeads()
	local rows = {}
	local normalizedProfessionID = tonumber(professionID) or 0
	local recipeProfessionCandidates = self:GetCustomerRecipeProfessionCandidates(recipeID, normalizedProfessionID)
	local hasRecipeProfessionCandidates = next(recipeProfessionCandidates) ~= nil
	filterText = tostring(filterText or ""):lower()

	for name, lead in pairs(self.tradeLeads or {}) do
		local hasProfessionCandidates = lead.professionCandidates and next(lead.professionCandidates) ~= nil
		local exactProfessionMatch = hasRecipeProfessionCandidates
			and hasProfessionCandidates
			and HasIntersection(lead.professionCandidates, recipeProfessionCandidates)
		if exactProfessionMatch and not (seenNames and seenNames[name]) then
			local row = {
				name = lead.name,
				target = lead.target,
				itemID = itemID,
				professionID = normalizedProfessionID,
				professionName = lead.professionName,
				professionLink = lead.professionLink,
				updatedAt = lead.updatedAt,
				tradeLead = true,
				certified = false,
				tradeProfessionMatch = exactProfessionMatch == true,
				note = self:Text("MISSING_ADDON_DATA"),
			}
			local haystack = table.concat({
				row.name or "",
				row.professionName or "",
				row.note or "",
			}, " "):lower()
			if filterText == "" or haystack:find(filterText, 1, true) then
				table.insert(rows, row)
				if seenNames then
					seenNames[name] = true
					if row.name then
						seenNames[row.name] = true
					end
					if row.target then
						seenNames[row.target] = true
					end
				end
			end
		end
	end

	return rows
end
