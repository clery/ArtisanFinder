local _, AF = ...

-- Forever links encode GUID, profession spell, then base skill line. Inspect
-- these fields rather than treating GUID fragments as possible professions.
function AF:GetTradeAdvertisementProfessionCandidates(link)
    local body = tostring(link or ""):match("|Htrade:([^|]+)|h")
    -- Native links may carry additional fields after the skill line.
    local skillLineID = tostring(body or ""):match("^[^:]+:%d+:(%d+)")
    local professionID = self:GetSupportedProfessionID(tonumber(skillLineID))
    if not professionID then
        -- Older profession hyperlinks encode the profession spell first.
        local first = tonumber(tostring(body or ""):match("^(%d+):"))
        local spells = {[7411]=333, [2018]=164, [2108]=165, [2259]=171,
            [3908]=197, [4036]=202, [25229]=755, [45357]=773, [2550]=185, [3273]=129}
        professionID = first and self:GetSupportedProfessionID(spells[first])
    end
    if not professionID and body then
        -- A localized profession label also identifies rank-specific links
        -- whose payload differs from the native GUID/spell/skill-line form.
        local label = tostring(link):match("|h%[(.-)%]|h")
        if label then
            for _, id in ipairs({164,165,171,197,202,333,755,773,185,129,182,186,356,393}) do
                if self:GetSupportedProfessionID(id) and self:GetProfessionName(id) == label then
                    professionID = id
                    break
                end
            end
        end
    end
    return professionID and {[professionID] = true} or {}
end

local InitializeTradeChat = AF.InitializeTradeChat
function AF:InitializeTradeChat()
    -- Repair previously observed advertisements whose professions were missed.
    for _, bucket in ipairs({self.db.tradeLeads or {}, self.db.tradeLeadCache or {}}) do
        for _, lead in pairs(bucket) do
            if not lead.debug and lead.professionLink then
                lead.professionCandidates = self:GetTradeAdvertisementProfessionCandidates(lead.professionLink)
            end
        end
    end
    InitializeTradeChat(self)
end

-- Individual recipe advertisements use enchant hyperlinks, including recipes
-- from professions other than Enchanting. Resolve their profession explicitly.
function AF:GetAdditionalTradeAdvertisements(message)
    local links, seen = {}, {}
    for link, recipeText in tostring(message or ""):gmatch("(|Henchant:(%d+)[^|]*|h.-|h)") do
        local recipeID = tonumber(recipeText)
        if recipeID and not seen[recipeID] then
            seen[recipeID] = true
            local professionID
            if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoByRecipeID then
                local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoByRecipeID, recipeID)
                if ok and type(info) == "table" then
                    for _, key in ipairs({"parentProfessionID", "parentSkillLineID", "skillLineID", "professionID", "profession"}) do
                        professionID = self:GetSupportedProfessionID(info[key])
                        if professionID then break end
                    end
                end
            end
            if professionID then
                links[#links + 1] = {link=link, key="recipe:"..recipeID, recipeID=recipeID,
                    professionCandidates={[professionID]=true}}
            end
        end
    end
    return links
end
