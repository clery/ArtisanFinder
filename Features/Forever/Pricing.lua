local _, AF = ...

function AF:GetForeverEntryCommission(entry, itemID)
    local name=self:NormalizeName(entry.orderTarget or entry.name or entry.target)
    local id=tonumber(entry.professionID)
    local profile=self.db.artisanCharacters and self.db.artisanCharacters[name]
    if name==self:NormalizeName(self.playerName or self:GetPlayerFullName()) then profile=self.db.artisanProfile end
    if itemID then
        if profile then
            local price,free=self:GetEntryCommission(profile.items and profile.items[tostring(itemID)])
            if price~=nil then return price,free,"item" end
        end
        if tonumber(entry.itemID)==tonumber(itemID) and not entry.tradeLead and not entry.linkedInn and not entry.thirdPartySource then
            local price,free=self:GetEntryCommission(entry)
            if price~=nil then return price,free,"item" end
        end
    end
    if profile then
        local price,free=self:GetEntryCommission(self:GetProfessionPriceEntry(profile,id))
        if price~=nil then return price,free,"default" end
    end
    local presence=self.db.foreverDiscoveries and self.db.foreverDiscoveries[name]
    local commission=presence and presence.commissions and presence.commissions[id]
    local price,free=self:GetEntryCommission(commission)
    if price~=nil then return price,free,"default" end
end

function AF:GetForeverDirectoryPrice(group,context)
    local itemID=self.currentCustomerItemID
    if context~=nil then itemID=context or nil end
    local minimum,allFree=nil,true
    local details,seen={},{}
    for _,entry in ipairs(group.offers or {group.entry}) do
        local price,free,source=self:GetForeverEntryCommission(entry,itemID)
        if price~=nil then
            minimum=math.min(minimum or price,price)
            allFree=allFree and free==true
            local key=tostring(entry.professionID)..":"..price..":"..tostring(free)
            if not seen[key] then
                seen[key]=true
                details[#details+1]=self:GetProfessionName(entry.professionID).." · "..self:FormatMoney(price,free).." ("..
                    self:Text(source=="item" and "FOREVER_PRICE_ITEM" or "FOREVER_PRICE_DEFAULT")..")"
            end
        end
    end
    local text="—"
    if minimum~=nil then
        text=self:FormatMoney(minimum,allFree)
    end
    return text,details,minimum
end
