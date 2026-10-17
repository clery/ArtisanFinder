local _, AF = ...

local function safe(value)
    return not (issecretvalue and issecretvalue(value))
end
local function clean(value)
    if not safe(value) or type(value)~="string" then return end
    value=value:gsub("%s+"," "):match("^%s*(.-)%s*$")
    return value~="" and value or nil
end
function AF:CombineForeverName(firstName,surname)
    firstName,surname=clean(firstName),clean(surname)
    if not firstName then return end
    if not surname or firstName:sub(-#surname-1)==" "..surname then return firstName end
    return firstName.." "..surname
end
function AF:GetForeverUnitFullName(unit)
    if NameUtil and NameUtil.GetUnmodifiedUnitFullName then
        local ok,name=pcall(NameUtil.GetUnmodifiedUnitFullName,unit)
        if ok and clean(name) then return clean(name) end
    end
    local getName=UnitNameUnmodified or UnitName
    if not getName then return end
    local firstName,surname=getName(unit)
    return self:CombineForeverName(firstName,surname)
end
function AF:GetPlayerFullName() return self:GetForeverUnitFullName("player") end
function AF:NormalizeName(name) return clean(name) end
function AF:GetDisplayPlayerName(name) return clean(name) or "" end
function AF:GetFullDisplayPlayerName(name) return self:GetDisplayPlayerName(name) end
-- Compatibility for shared callers: every full name belongs to the same
-- player namespace. The surname is never interpreted as a realm.
function AF:GetNameRealm() return nil end
function AF:IsNameOnConnectedRealm(name) return clean(name)~=nil end

local function merge(existing,old)
    if type(existing)~="table" or type(old)~="table" then return existing end
    for key,value in pairs(old) do
        if existing[key]==nil then existing[key]=value
        elseif type(existing[key])=="table" and type(value)=="table" then merge(existing[key],value) end
    end
    return existing
end
function AF:MigrateForeverPlayerNames(db)
    local fullName=self:GetPlayerFullName()
    if not fullName then return end
    db.foreverNameMigratedCharacters=db.foreverNameMigratedCharacters or {}
    if db.foreverNameVersion==1 and db.foreverNameMigratedCharacters[fullName] then return end
    local getName=UnitNameUnmodified or UnitName
    local firstName,surname
    if getName then firstName,surname=getName("player") end
    firstName,surname=clean(firstName),clean(surname)
    local aliases={}
    aliases[fullName]=fullName
    if fullName and firstName and surname then
        aliases[firstName.."-"..surname]=fullName
        aliases[fullName:gsub("%s+","")]=fullName
    end
    -- A one-time migration can recognize the former client realm suffix.
    -- Do not infer another player's surname from a collapsed legacy name.
    ---@type string?
    local realm=GetRealmName and GetRealmName()
    if not safe(realm) or type(realm)~="string" then realm=nil end
    realm=realm and realm:gsub("%s+","")
    local function incompleteLegacyName(value)
        local name=clean(value)
        if name and realm and name:sub(-#realm-1)=="-"..realm then
            local base=clean(name:sub(1,-#realm-2))
            return base and not base:find(" ",1,true) and not aliases[base] and not aliases[name]
        end
        return false
    end
    -- Older discovery records may have irreversibly lost the separator between
    -- first and last name. Preserve them, but never whisper a guessed identity.
    local function archiveIncomplete(map,archive)
        if type(map)~="table" then return end
        for key,entry in pairs(map) do
            if type(entry)=="table" and incompleteLegacyName(entry.orderTarget or entry.name or entry.target) then
                archive[key]=entry map[key]=nil
            end
        end
    end
    local legacy=db.foreverLegacyDiscoveryNames or {customerCache={},tradeLeadCache={},tradeLeads={}}
    db.foreverLegacyDiscoveryNames=legacy
    for item,bucket in pairs(db.customerCache or {}) do
        legacy.customerCache[item]=legacy.customerCache[item] or {}
        archiveIncomplete(bucket,legacy.customerCache[item])
    end
    archiveIncomplete(db.tradeLeadCache,legacy.tradeLeadCache)
    archiveIncomplete(db.tradeLeads,legacy.tradeLeads)
    local function migrateName(name)
        name=clean(name)
        if not name then return end
        if aliases[name] then return aliases[name] end
        if realm and name:sub(-#realm-1)=="-"..realm then
            name=clean(name:sub(1,-#realm-2))
            return aliases[name] or name
        end
        return name
    end
    local function rekey(map)
        if type(map)~="table" then return end
        local changes={}
        for old,value in pairs(map) do
            local name=migrateName(old)
            if name and name~=old then changes[#changes+1]={old,name,value} end
        end
        for _,change in ipairs(changes) do
            local old,name,value=unpack(change)
            if map[name]==nil then map[name]=value else merge(map[name],value) end
            map[old]=nil
        end
    end
    for _,field in ipairs({"artisanCharacters","advertising","advertisingKnown","favoriteArtisans","artisanContacts","whoOnlineCache"}) do rekey(db[field]) end
    local function entryNames(entry)
        if type(entry)~="table" then return end
        for _,field in ipairs({"name","displayName","target","orderTarget","characterName"}) do
            if entry[field] then entry[field]=migrateName(entry[field]) end
        end
    end
    entryNames(db.artisanProfile)
    for _,profile in pairs(db.artisanCharacters or {}) do entryNames(profile) end
    for _,bucket in pairs(db.customerCache or {}) do
        rekey(bucket) for _,entry in pairs(bucket) do entryNames(entry) end
    end
    for _,field in ipairs({"tradeLeadCache","tradeLeads","artisanContacts"}) do
        for _,entry in pairs(db[field] or {}) do entryNames(entry) end
    end
    if db.foreverIndicators then rekey(db.foreverIndicators.characters) end
    local links={}
    for key,value in pairs(db.professionLinks or {}) do
        local name,id=key:match("^(.*):(%d+)$")
        name=name and migrateName(name)
        links[name and (name..":"..id) or key]=value
    end
    db.professionLinks=links
    if db.guildCache then
        local guilds={}
        for old,cache in pairs(db.guildCache.byGuild or {}) do
            local key=clean(cache.guildName)
            key=key and key:lower() or old
            cache.guildRealm=nil cache.guildKey=key
            rekey(cache.rosterByName)
            for _,entry in pairs(cache.rosterByName or {}) do entryNames(entry) end
            if guilds[key] then merge(guilds[key],cache) else guilds[key]=cache end
        end
        db.guildCache.byGuild=guilds db.guildCache.guildRealm=nil
    end
    db.foreverNameVersion=1
    db.foreverNameMigratedCharacters[fullName]=true
end
local ensureDB=AF.EnsureDB
function AF:EnsureDB()
    local db=ensureDB(self)
    self:MigrateForeverPlayerNames(db)
    db.connectedRealmCache=nil
    return db
end
