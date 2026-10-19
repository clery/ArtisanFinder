local _, AF = ...

-- Expanded craft rows copy and rewrite target. Resolve the advertiser using
-- the original artisan offers, keeping the crafting character separate.
function AF:GetAgreementInputFromCraft(group, craft)
    if type(group)~="table" or type(craft)~="table" then return end
    local character=self:NormalizeName(craft.orderTarget or craft.name or group.name)
    local contact,priority
    local function use(offer)
        if type(offer)~="table" or offer.ownAlt then return end
        local owner=self:NormalizeName(offer.orderTarget or offer.name)
        if owner==character and tonumber(offer.professionID)==tonumber(craft.professionID) then
            local candidate=self:NormalizeName(offer.target or offer.name)
            local rank=(not offer.tradeLead and not offer.linkedInn and not offer.thirdPartySource) and 2 or 0
            if candidate~=character then rank=rank+4 end
            if candidate and (not priority or rank>priority) then contact,priority=candidate,rank end
        end
    end
    for _,offer in ipairs(group.offers or {}) do use(offer) end
    use(group.entry)
    if not contact and self.GetRememberedArtisanContact then contact=self:GetRememberedArtisanContact(character) end
    contact=contact or self:NormalizeName(group.name)
    if not contact or contact==self:NormalizeName(self.playerName or self:GetPlayerFullName()) then return end
    local price=self:GetForeverEntryCommission(craft,craft.itemID)
    local link=self:GetForeverCraftPresentation(craft)
    return {artisan=contact,contact=contact,craftingCharacter=character,itemID=craft.itemID,
        recipeID=craft.recipeID,professionID=craft.professionID,itemLink=link,
        itemName=craft.craftName or craft.itemName or craft.recipeName,quantity=1,
        commission=price,unitCommission=price,reagents=craft.reagents or craft.bestReagents}
end

function AF:RequestForeverCraftAgreement(view)
    if not view or view.kind~="craft" then return end
    local input=self:GetAgreementInputFromCraft(view.artisanGroup or view.group,view.group.entry)
    if input then return self:OpenAgreementEditor(input) end
end
