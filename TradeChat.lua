local _, AF = ...

local TRADE_LEAD_TTL = 5 * 60
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

local function ExtractTradeLink(message)
	local link, name = tostring(message or ""):match("(|c%x+|Htrade:.-|h%[(.-)%]|h|r)")
	if link then
		return link, name
	end
	link, name = tostring(message or ""):match("(|Htrade:.-|h%[(.-)%]|h)")
	return link, name
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

function AF:InitializeTradeChat()
	self.tradeLeads = self.tradeLeads or {}
end

function AF:OnTradeChatMessage(message, sender)
	local link, professionName = ExtractTradeLink(message)
	if not link or not sender then
		return
	end

	local name = self:NormalizeName(sender)
	if not name or name == self:NormalizeName(self.playerName or self:GetPlayerFullName()) then
		return
	end

	self.tradeLeads = self.tradeLeads or {}
	self.tradeLeads[name] = {
		name = name,
		target = name,
		professionLink = link,
		professionName = professionName,
		professionCandidates = GetTradeLinkProfessionCandidates(link),
		updatedAt = self:Now(),
		tradeLead = true,
		certified = false,
	}

	if self.RefreshCustomerResults then
		self:RefreshCustomerResults()
	end
end

function AF:PruneTradeLeads()
	local now = self:Now()
	for name, lead in pairs(self.tradeLeads or {}) do
		if not lead.updatedAt or now - lead.updatedAt > TRADE_LEAD_TTL then
			self.tradeLeads[name] = nil
		end
	end
end

function AF:GetTradeLeadRows(itemID, professionID, filterText, seenNames)
	self:PruneTradeLeads()
	local rows = {}
	local normalizedProfessionID = tonumber(professionID) or 0
	filterText = tostring(filterText or ""):lower()

	for name, lead in pairs(self.tradeLeads or {}) do
		local hasProfessionCandidates = lead.professionCandidates and next(lead.professionCandidates) ~= nil
		local exactProfessionMatch = normalizedProfessionID == 0
			or not hasProfessionCandidates
			or tonumber(lead.professionID) == normalizedProfessionID
			or (lead.professionCandidates and lead.professionCandidates[normalizedProfessionID])
		if not (seenNames and seenNames[name]) then
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
			end
		end
	end

	return rows
end
