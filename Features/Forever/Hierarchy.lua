local _, AF = ...

function AF:GetForeverProfessionLabel(group,professionID)
    local title=self:GetProfessionName(professionID)
    local level,maximum
    local function use(skill,max)
        skill,max=tonumber(skill),tonumber(max)
        if skill and skill>0 and (not level or skill>level) then level,maximum=skill,max end
    end
    for _,entry in ipairs(group.offers or {group.entry}) do
        if tonumber(entry.professionID)==tonumber(professionID) then
            local name=self:NormalizeName(entry.orderTarget or entry.name or entry.target or group.name)
            local profile=self.db.artisanCharacters and self.db.artisanCharacters[name]
            if name==self:NormalizeName(self.playerName or self:GetPlayerFullName()) then profile=self.db.artisanProfile end
            local profession=profile and profile.professions and (profile.professions[tostring(professionID)] or profile.professions[professionID])
            if profession then use(profession.skillLevel,profession.maxSkillLevel) end
            use(entry.skillLevel,entry.maxSkillLevel)
            local presence=self.db.foreverDiscoveries and self.db.foreverDiscoveries[name]
            local skill=presence and presence.skills and presence.skills[tonumber(professionID)]
            if skill then use(skill.level,skill.maximum) end
            local linked=self.db.linkedInnDiscoveries and self.db.linkedInnDiscoveries[name]
            local known=linked and linked.professions and linked.professions[tonumber(professionID)]
            if known then use(known.rank,known.max) end
        end
    end
    if not level then return title end
    return title.." ("..level..(maximum and maximum>=level and ("/"..maximum) or "")..")"
end

function AF:GetForeverProfessionDefaults(name, professionID)
    name=self:NormalizeName(name)
    local profile=self.db.artisanCharacters and self.db.artisanCharacters[name]
    if name==self:NormalizeName(self.playerName or self:GetPlayerFullName()) then profile=self.db.artisanProfile end
    if profile then return self:GetProfessionPriceEntry(profile,professionID) end
    local presence=self.db.foreverDiscoveries and self.db.foreverDiscoveries[name]
    return presence and presence.commissions and presence.commissions[tonumber(professionID)]
end

function AF:GetForeverKnownCrafts(name, professionID, build)
    name=self:NormalizeName(name)
    local crafts,seen={},{}
    local function add(entry,itemID,recipeID)
        itemID=tonumber(itemID or entry.itemID)
        recipeID=tonumber(recipeID or entry.recipeID)
        if not itemID and recipeID then itemID=-recipeID end
        if not itemID then return end
        local key=tostring(recipeID or 0)..":"..itemID
        if seen[key] then return end
        local copy={} for field,value in pairs(entry) do copy[field]=value end
        copy.name,copy.target,copy.professionID=name,name,professionID
        copy.itemID,copy.recipeID=itemID,recipeID
        local title=copy.itemName or copy.recipeName
        if not title and itemID>0 then title=self:GetDisplayItemName(itemID) end
        if not title and recipeID and C_Spell and C_Spell.GetSpellName then
            local ok,value=pcall(C_Spell.GetSpellName,recipeID)
            if ok and not self:IsSecretValue(value) then title=value end
        end
        copy.craftName=title or self:Text("FOREVER_RECIPE_ID",recipeID or itemID)
        crafts[#crafts+1]=copy seen[key]=copy
    end
    local profile=self.db.artisanCharacters and self.db.artisanCharacters[name]
    if name==self:NormalizeName(self.playerName or self:GetPlayerFullName()) then profile=self.db.artisanProfile end
    local recipes={}
    if profile then
        for itemID,item in pairs(profile.items or {}) do
            if tonumber(item.professionID)==professionID then
                add(item,itemID) local recipe=tonumber(item.recipeID) if recipe then recipes[recipe]=true end
            end
        end
        local profession=profile.professions and (profile.professions[tostring(professionID)] or profile.professions[professionID])
        for recipe,known in pairs(profession and profession.recipes or {}) do
            recipe=tonumber(recipe)
            if known and recipe and not recipes[recipe] then
                local outputs=self.GetRecipeOutputItemIDs and self:GetRecipeOutputItemIDs(recipe) or {[-recipe]=true}
                for itemID in pairs(outputs) do add({},itemID,recipe) end
            end
        end
    end
    if build and not build.customerCrafts then
        build.customerCrafts={}
        for itemID,bucket in pairs(self.db.customerCache or {}) do
            for _,entry in pairs(bucket) do
                local owner=self:NormalizeName(entry.orderTarget or entry.name or entry.target)
                local id=tonumber(entry.professionID)
                if owner and id then
                    local key=owner..":"..id
                    local list=build.customerCrafts[key] or {}
                    build.customerCrafts[key]=list
                    list[#list+1]={entry=entry,itemID=itemID}
                end
            end
        end
    end
    if build then
        for _,craft in ipairs(build.customerCrafts[name..":"..professionID] or {}) do add(craft.entry,craft.itemID) end
    else
        for itemID,bucket in pairs(self.db.customerCache or {}) do
            for _,entry in pairs(bucket) do
                if self:NormalizeName(entry.orderTarget or entry.name or entry.target)==name and tonumber(entry.professionID)==professionID then add(entry,itemID) end
            end
        end
    end
    local linked=self.db.linkedInnDiscoveries and self.db.linkedInnDiscoveries[name]
    local profession=linked and linked.professions and linked.professions[professionID]
    for _,recipe in ipairs(profession and profession.recipes or {}) do
        local outputs=self.GetRecipeOutputItemIDs and self:GetRecipeOutputItemIDs(recipe) or {[-recipe]=true}
        for itemID in pairs(outputs) do add({linkedInn=true,professionLink=profession.link,updatedAt=linked.updatedAt},itemID,recipe) end
    end
    for source,records in pairs(self.db.compatibilityDiscoveries or {}) do
        local presence=records[name]
        if presence and self:Now()-(tonumber(presence.updatedAt) or 0)<=(self.CACHE_MAX_AGE or 1209600) then
            for _,craft in ipairs(presence.crafts or {}) do
                if tonumber(craft.professionID)==professionID then
                    local entry={} for key,value in pairs(craft) do entry[key]=value end
                    entry.thirdPartySource=source entry.updatedAt=presence.updatedAt
                    entry.itemName=entry.craftName
                    add(entry)
                end
            end
        end
    end
    table.sort(crafts,function(a,b)
        if a.craftName~=b.craftName then return a.craftName<b.craftName end
        return a.itemID<b.itemID
    end)
    return crafts
end

function AF:BuildForeverExpandedRows(groups,first,last,query,build)
    query=tostring(query or ""):lower():match("^%s*(.-)%s*$")
    local itemID=tonumber(self.currentCustomerItemID)
    local nameMatches=query~="" and self.GetForeverArtisanNameMatches and self:GetForeverArtisanNameMatches(query) or {}
    local function matches(text) return tostring(text or ""):lower():find(query,1,true)~=nil end
    self.directoryExpandedArtisans=self.directoryExpandedArtisans or {}
    self.directoryExpandedProfessions=self.directoryExpandedProfessions or {}
    local rows={}
    for index=first,last do
        local group=groups[index]
        rows[#rows+1]={kind="artisan",group=group,key=group.name,expanded=self.directoryExpandedArtisans[group.name]}
        if self.directoryExpandedArtisans[group.name] then
            local ids={} for id in pairs(group.professions) do ids[#ids+1]=id end table.sort(ids)
            for _,id in ipairs(ids) do
                local broad=not itemID and (query=="" or nameMatches[group.name] or matches(group.name) or matches(self:GetProfessionName(id)))
                local crafts={}
                if not broad or self.directoryExpandedProfessions[group.name..":"..id] then
                    for _,craft in ipairs(self:GetForeverKnownCrafts(group.name,id,build)) do
                        if broad or (itemID and tonumber(craft.itemID)==itemID) or (not itemID and matches(craft.craftName)) then
                            crafts[#crafts+1]=craft
                        end
                    end
                end
                if broad or #crafts>0 then
                    local offers={}
                    for _,entry in ipairs(group.offers) do if tonumber(entry.professionID)==id then offers[#offers+1]=entry end end
                    local entry=offers[1] or group.entry
                    for _,offer in ipairs(offers) do if self:CanReliablyOpenProfession(offer) then entry=offer break end end
                    local job={name=group.name,entry=entry,offers=offers,professions={[id]=true},source=group.source,updatedAt=group.updatedAt}
                    local key=group.name..":"..id
                    rows[#rows+1]={kind="profession",group=job,key=key,expanded=self.directoryExpandedProfessions[key],professionID=id}
                    if self.directoryExpandedProfessions[key] then
                        for _,craft in ipairs(crafts) do
                            rows[#rows+1]={kind="craft",group={name=group.name,entry=craft,offers={craft},professions={[id]=true},source=group.source,updatedAt=craft.updatedAt or group.updatedAt},label=craft.craftName}
                        end
                        if #crafts==0 then rows[#rows+1]={kind="empty",group=job,label=self:Text("FOREVER_NO_KNOWN_CRAFTS")} end
                    end
                end
            end
        end
    end
    return rows
end

function AF:ToggleForeverDirectoryRow(view)
    if view.kind=="artisan" then
        self.directoryExpandedArtisans[view.key]=not self.directoryExpandedArtisans[view.key]
    elseif view.kind=="profession" then
        self.directoryExpandedProfessions[view.key]=not self.directoryExpandedProfessions[view.key]
    else return end
    self:RefreshCustomerResults()
end

function AF:GetForeverCraftPresentation(entry)
    local itemID,recipeID=tonumber(entry.itemID),tonumber(entry.recipeID)
    local name=entry.craftName or entry.itemName or entry.recipeName or "?"
    local link,texture,payload
    if itemID and itemID>0 then
        payload="item:"..itemID
        if C_Item and C_Item.GetItemInfo then
            local ok,_,cached=pcall(C_Item.GetItemInfo,itemID)
            if ok and not self:IsSecretValue(cached) then link=cached end
        end
        if C_Item and C_Item.GetItemIconByID then
            local ok,value=pcall(C_Item.GetItemIconByID,itemID)
            if ok and not self:IsSecretValue(value) then texture=value end
        end
        if not link and C_Item and C_Item.RequestLoadItemDataByID then
            self.foreverPendingCraftItems=self.foreverPendingCraftItems or {}
            if not self.foreverPendingCraftItems[itemID] then
                self.foreverPendingCraftItems[itemID]=true
                pcall(C_Item.RequestLoadItemDataByID,itemID)
            end
        end
    elseif recipeID then payload="enchant:"..recipeID end
    if not texture and recipeID and C_Spell and C_Spell.GetSpellTexture then
        local ok,value=pcall(C_Spell.GetSpellTexture,recipeID)
        if ok and not self:IsSecretValue(value) then texture=value end
    end
    return link or (payload and ("|H"..payload.."|h["..name.."]|h") or name),texture or 134400,payload
end
function AF:OnDirectoryItemDataLoaded(itemID,success)
    if success==false then return end
    if self.foreverPendingCraftItems and self.foreverPendingCraftItems[itemID] then
        self.foreverPendingCraftItems[itemID]=nil
        self:RequestCustomerResultsRefresh()
    end
end
