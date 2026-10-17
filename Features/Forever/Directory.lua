local _, AF = ...

function AF:GetForeverArtisanNameMatches(query)
    query=tostring(query or ""):lower()
    local graph,matched,queue={},{},{}
    local function connect(left,right)
        left,right=self:NormalizeName(left),self:NormalizeName(right)
        if not left or not right then return end
        graph[left]=graph[left] or {} graph[right]=graph[right] or {}
        graph[left][right]=true graph[right][left]=true
    end
    for name,contact in pairs(self.db.artisanContacts or {}) do connect(name,contact.target) end
    for _,bucket in pairs(self.db.customerCache or {}) do
        for _,entry in pairs(bucket) do connect(entry.orderTarget or entry.name,entry.target) end
    end
    for name,profile in pairs(self.db.artisanCharacters or {}) do
        if not profile.importedAlt then connect(name,self.playerName) end
    end
    for name in pairs(graph) do
        if name:lower():find(query,1,true) then matched[name]=true queue[#queue+1]=name end
    end
    local index=1
    while queue[index] do
        for name in pairs(graph[queue[index]]) do
            if not matched[name] then matched[name]=true queue[#queue+1]=name end
        end
        index=index+1
    end
    return matched
end

-- The original cache/ranking pipeline remains the source of recipe search results.
-- A directory query has no selected item, so collect its known item buckets first.
function AF:GetDirectoryEntries(filterText,build)
	filterText = tostring(filterText or ""):lower()
	local itemIDs, rows, seen, craftMatches = {}, {}, {}, {}
    local nameMatches=filterText~="" and self:GetForeverArtisanNameMatches(filterText) or {}
	self:ForEachArtisanProfile(function(_, profile)
		local professions={}
        for itemID,item in pairs(profile.items or {}) do
            -- A collapsed listing needs one representative per character/profession.
            -- Item searches still inspect every known output.
            local profession=tostring(item.professionID or 0)
            if not self.GetOwnAltRows or filterText~="" or not professions[profession] then
                itemIDs[tonumber(itemID) or itemID]=true
                professions[profession]=true
            end
        end
	end)
	local function add(entry, itemID, itemName)
		local name = self:NormalizeName(entry.orderTarget or entry.name or entry.target)
		if not name then return end
		local key = name .. ":" .. tostring(entry.professionID or 0) .. ":" .. self:GetForeverDiscoverySource(entry)
		if seen[key] then
            seen[key].updatedAt=math.max(tonumber(seen[key].updatedAt) or 0,tonumber(entry.updatedAt or entry.verifiedAt) or 0)
            return
        end
        local matches = filterText == "" or nameMatches[name] or name:lower():find(filterText,1,true)
            or self:CustomerEntryMatchesFilter(entry,filterText)
            or tostring(itemName or ""):lower():find(filterText,1,true)
            or (entry.professionID and self:GetProfessionName(entry.professionID):lower():find(filterText,1,true))
        if not matches and self.GetForeverKnownCrafts and entry.professionID then
            local craftKey=name..":"..entry.professionID
            if craftMatches[craftKey]==nil then
                craftMatches[craftKey]=false
                for _,craft in ipairs(self:GetForeverKnownCrafts(name,tonumber(entry.professionID),build)) do
                    if craft.craftName:lower():find(filterText,1,true) then craftMatches[craftKey]=true break end
                end
            end
            matches=craftMatches[craftKey]
        end
		if not matches then return end
		local copy = {}
		for k, value in pairs(entry) do copy[k] = value end
		copy.itemID = copy.itemID or itemID
		copy.directoryItemName = itemName
		rows[#rows + 1], seen[key] = copy, copy
	end
	for itemID in pairs(itemIDs) do
		local itemName = self:GetDisplayItemName(itemID)
		-- Remote offers are collected below; rendering must not issue guild recipe queries.
        local ownRows=self.GetOwnAltRows and self:GetOwnAltRows(itemID,nil,"",{})
            or self:GetCachedArtisans(itemID,"",self.db.defaultSort or "best")
		for _, entry in ipairs(ownRows) do
			add(entry, itemID, itemName)
		end
	end
    -- A directory is discovery history, not only the last live item query.
    -- Nonguild, nonfavorite respondents must remain discoverable afterward.
    for itemID,bucket in pairs(self.db.customerCache or {}) do
        local itemName=self:GetDisplayItemName(tonumber(itemID) or itemID)
        for _,entry in pairs(bucket) do
            local updated=tonumber(entry.updatedAt or entry.verifiedAt) or 0
            if (not entry.debug or self.IsDevFakeRowsEnabled and self:IsDevFakeRowsEnabled())
                and (self:IsFavoriteArtisan(entry) or updated>0 and self:Now()-updated<=(self.CACHE_MAX_AGE or (14*86400))) then
                add(entry,tonumber(itemID) or itemID,itemName)
            end
        end
    end
    for name, presence in pairs(self.db.foreverDiscoveries or {}) do
        if self:Now()-(tonumber(presence.updatedAt) or 0) <= (self.CACHE_MAX_AGE or (14*86400)) then
            for id in pairs(presence.professions or {}) do
                add({name=name, target=name, professionID=id, updatedAt=presence.updatedAt,
                    verifiedAt=presence.updatedAt, addonPresence=true})
            end
        end
    end
    for _,entry in ipairs(self:GetForeverGuildDirectoryEntries()) do add(entry) end
    if self.GetLinkedInnDirectoryEntries then
        for _,entry in ipairs(self:GetLinkedInnDirectoryEntries()) do add(entry) end
    end
    if self.GetCompatibilityDirectoryEntries then
        for _,entry in ipairs(self:GetCompatibilityDirectoryEntries()) do add(entry) end
    end
	-- Trade advertisements are useful before any recipe query has been made.
    local function addTradeLead(lead,lifetime)
		if self:Now() - (tonumber(lead.updatedAt) or 0) <= lifetime then
			for professionID in pairs(lead.professionCandidates or {}) do
				add({ name = lead.name, target = lead.target, professionID = professionID,
					professionLink = lead.professionLink, updatedAt = lead.updatedAt,
					tradeLead = true, note = lead.note or self:Text("MISSING_ADDON_DATA") })
			end
		end
    end
    for _,lead in pairs(self.tradeLeads or {}) do addTradeLead(lead,(tonumber(self.db.tradeLeadMinutes) or 15)*60) end
    for _,lead in pairs(self.db.tradeLeadCache or {}) do addTradeLead(lead,self.CACHE_MAX_AGE or (14*86400)) end
	table.sort(rows, function(a, b)
		local af, bf = self:IsFavoriteArtisan(a), self:IsFavoriteArtisan(b)
		if af ~= bf then return af end
		return tostring(a.name or "") < tostring(b.name or "")
	end)
	return rows
end

function AF:FindForeverItems(query)
    query=tostring(query or ""):lower():match("^%s*(.-)%s*$")
    local matches,seen={},{}
    local function add(itemID,item)
        itemID=tonumber(itemID)
        if not itemID or itemID<=0 or seen[itemID] then return end
        local name=item and (item.itemName or item.recipeName) or self:GetDisplayItemName(itemID)
        name=name or self:GetDisplayItemName(itemID)
        if name and name:lower():find(query,1,true) then
            seen[itemID]=true matches[#matches+1]={itemID=itemID,name=name}
        end
    end
    self:ForEachArtisanProfile(function(_,profile)
        for id,item in pairs(profile.items or {}) do add(id,item) end
    end)
    for id,bucket in pairs(self.db.customerCache or {}) do
        local entry=next(bucket) and select(2,next(bucket))
        add(id,entry)
    end
    if self.ForEachLinkedInnItem then self:ForEachLinkedInnItem(add) end
    for _,records in pairs(self.db.compatibilityDiscoveries or {}) do
        for _,presence in pairs(records) do
            if self:Now()-(tonumber(presence.updatedAt) or 0)<=(self.CACHE_MAX_AGE or 1209600) then
                for _,craft in ipairs(presence.crafts or {}) do add(craft.itemID,{itemName=craft.craftName}) end
            end
        end
    end
    table.sort(matches,function(a,b) return a.name==b.name and a.itemID<b.itemID or a.name<b.name end)
    return matches
end

function AF:GetForeverDirectoryRows(query,profession,source,build)
    local entries
    if self.currentCustomerItemID then
        entries=self:GetCachedArtisans(self.currentCustomerItemID,query or "","best",self.currentCustomerQueryToken)
    else entries=self:GetDirectoryEntries(query or "",build) end
    if self.currentCustomerItemID and self.GetLinkedInnDirectoryEntries then
        local merged={} for _,entry in ipairs(entries) do merged[#merged+1]=entry end
        for _,entry in ipairs(self:GetLinkedInnDirectoryEntries(self.currentCustomerItemID)) do
            if not query or query=="" or self:CustomerEntryMatchesFilter(entry,query:lower()) then merged[#merged+1]=entry end
        end
        entries=merged
    end
    if self.currentCustomerItemID and self.GetCompatibilityDirectoryEntries then
        local merged={} for _,entry in ipairs(entries) do merged[#merged+1]=entry end
        for _,entry in ipairs(self:GetCompatibilityDirectoryEntries(self.currentCustomerItemID)) do
            if not query or query=="" or self:CustomerEntryMatchesFilter(entry,query:lower()) then merged[#merged+1]=entry end
        end
        entries=merged
    end
    local groups,rows={},{}
    for _,entry in ipairs(entries) do
        local discovered=self:GetForeverDiscoverySource(entry)
        local id=tonumber(entry.professionID)
        if (not profession or id==profession) and (not source or source==discovered) then
            local name=self:NormalizeName(entry.orderTarget or entry.name or entry.target)
            if name and (not self.directoryTargetName or name==self.directoryTargetName) then
                local row=groups[name]
                if not row then
                    row={name=name,entry=entry,professions={},offers={},sources={},updatedAt=0}
                    groups[name]=row rows[#rows+1]=row
                end
                if id and id>0 then row.professions[id]=true end
                row.offers[#row.offers+1]=entry row.sources[discovered]=true
                row.updatedAt=math.max(row.updatedAt,tonumber(entry.updatedAt or entry.verifiedAt) or 0)
                if row.entry.tradeLead and not entry.tradeLead then row.entry=entry end
                row.source=self:GetPreferredForeverDiscoverySource(row.sources)
            end
        end
    end
    if self.SortForeverDirectoryRows then self:SortForeverDirectoryRows(rows) else
    table.sort(rows,function(a,b)
        local favoriteA,favoriteB=self:IsFavoriteArtisan(a.entry),self:IsFavoriteArtisan(b.entry)
        if favoriteA~=favoriteB then return favoriteA end
        return a.name:lower()<b.name:lower()
    end)
    end
    return rows
end

function AF:SelectCustomerItem(value)
	local itemID = tonumber(value) or tonumber(tostring(value or ""):match("item:(%d+)"))
    if not itemID and value and tostring(value):match("%S") then
        if C_Item and C_Item.GetItemInfo then
            local ok,_,link=pcall(C_Item.GetItemInfo,value)
            if ok and link then itemID=tonumber(link:match("item:(%d+)")) end
        end
        if not itemID then
            local matches=self:FindForeverItems(value)
            local exact={}
            for _,match in ipairs(matches) do
                if match.name:lower()==tostring(value):lower() then exact[#exact+1]=match end
            end
            if #exact==1 then itemID=exact[1].itemID
            elseif #exact>1 then return nil,exact end
            if not itemID and #matches==1 then itemID=matches[1].itemID end
            if not itemID then return nil,matches end
        end
    end
	if itemID and (itemID < 1 or itemID ~= math.floor(itemID)) then return nil,{} end
	self.currentCustomerItemID = itemID
	self.currentCustomerItemName = itemID and self:GetDisplayItemName(itemID) or nil
	self.currentCustomerProfessionID = 0
	self.currentCustomerRecipeID = nil
	self.currentCustomerQueryToken = nil
	self.currentCustomerQueryItemID = nil
	self.currentCustomerQueryProfessionID = nil
	self.directoryPage=1
	self.foreverItemSelection=(self.foreverItemSelection or 0)+1
	if self.customerFrame then self.customerFrame.scroll:SetVerticalScroll(0) end
	self:RefreshCustomerQuery(itemID ~= nil)
	return itemID
end

function AF:GetForeverNameplateObservation(fullName)
	fullName = self:NormalizeName(fullName)
	if not fullName or not self.db then return nil end
	local now, professions, expiresAt = self:Now(), {}, 0
    local linked = self.db.linkedInnDiscoveries and self.db.linkedInnDiscoveries[fullName]
    if linked and (tonumber(linked.expiresAt) or 0)>now then
        local ids={} for id in pairs(linked.professions or {}) do ids[id]=true end
        return {professions=ids,source="LINKEDINN",expiresAt=linked.expiresAt}
    end
    local presence = self.db.foreverDiscoveries and self.db.foreverDiscoveries[fullName]
    if presence and (tonumber(presence.expiresAt) or 0) > now then
        return {professions=presence.professions, source="ADDON", expiresAt=presence.expiresAt}
    end
	local function add(id, expiry)
		id=tonumber(id)
		if id and id>0 and expiry>now then professions[id]=true expiresAt=math.max(expiresAt,expiry) end
	end
	local playerName=self:NormalizeName(self.playerName or self:GetPlayerFullName())
	if fullName==playerName and self:IsAvailable() then
		for id in pairs(self.db.artisanProfile.professions or {}) do
			if self:IsProfessionAdvertised(playerName,tonumber(id)) then add(id,now+60) end
		end
	end
	for _,bucket in pairs(self.db.customerCache or {}) do
		for _,entry in pairs(bucket) do
			if self:NormalizeName(entry.orderTarget or entry.name or entry.target)==fullName
				and not entry.debug and not entry.knownUnavailable and not entry.unavailableCached and not entry.unavailableFavorite
				and not entry.offline and not entry.offlineCached then
				-- A scan retained for days does not imply a currently advertising artisan.
				local verified=tonumber(entry.verifiedAt) or tonumber(entry.updatedAt) or 0
				add(entry.professionID,verified+(tonumber(self.CACHE_LIVE_AGE) or 300))
			end
		end
	end
	if next(professions) then return {professions=professions,source="ADDON",expiresAt=expiresAt} end
	for _,lead in pairs(self.tradeLeads or {}) do
		if self:NormalizeName(lead.name or lead.target)==fullName then
			for id in pairs(lead.professionCandidates or {}) do add(id,(tonumber(lead.updatedAt) or 0)+(tonumber(self.db.tradeLeadMinutes) or 15)*60) end
		end
	end
	if next(professions) then return {professions=professions,source="TRADE",expiresAt=expiresAt} end
end
