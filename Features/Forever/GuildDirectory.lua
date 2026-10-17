local _, AF = ...

-- Guild membership exposes professions, not availability, prices or recipe knowledge.
function AF:GetForeverGuildDirectoryEntries()
    local rows,seen={},{}
    if not IsInGuild or not IsInGuild() then self.foreverGuildDirectoryCache=nil return rows end
    local now=self:Now()
    local club=C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
    local guild=club or GetGuildInfo and GetGuildInfo("player") or self.currentGuildCacheKey
    local cached=self.foreverGuildDirectoryCache
    if cached and cached.guild==guild and now-cached.at<5 then return cached.rows end
    local playerName=self:NormalizeName(self.playerName or (self.GetPlayerFullName and self:GetPlayerFullName()))
    local function add(name,id,online,guid,skillLevel)
        name=self:NormalizeName(name)
        id=self:GetSupportedProfessionID(tonumber(id))
        if not name or not id or name==playerName then return end
        local key=name..":"..id
        if seen[key] then return end
        seen[key]=true
        local roster=self.guildRosterByName and self.guildRosterByName[name]
        self.foreverGuildLastObserved=self.foreverGuildLastObserved or {}
        local observed=roster and roster.lastObservedOnlineAt or self.foreverGuildLastObserved[name]
        if online==true then
            observed=now
            self.foreverGuildLastObserved[name]=observed
            if roster then roster.lastObservedOnlineAt=observed end
        end
        rows[#rows+1]={name=name,target=name,professionID=id,guildMember=true,guildDiscovery=true,
            guildMemberGUID=guid or roster and roster.guid,guildOnline=online==true,skillLevel=tonumber(skillLevel),
            updatedAt=observed or 0}
    end
    if C_Club and C_Club.GetGuildClubId and C_Club.GetClubMembers and C_Club.GetMemberInfo then
        if club then
            for _,memberID in ipairs(C_Club.GetClubMembers(club) or {}) do
                local member=C_Club.GetMemberInfo(club,memberID)
                if member then
                    local offline=Enum and Enum.ClubMemberPresence and Enum.ClubMemberPresence.Offline
                    local online=offline~=nil and member.presence~=nil and member.presence~=offline
                    add(member.name,member.profession1ID,online,member.guid,member.profession1Rank)
                    add(member.name,member.profession2ID,online,member.guid,member.profession2Rank)
                end
            end
        end
    end
    -- Legacy guild profession lists are also used by Forever's guild UI.
    if GetNumGuildTradeSkill and GetGuildTradeSkillInfo then
        local profession
        for index=1,tonumber(GetNumGuildTradeSkill()) or 0 do
            local id,_,_,header,_,_,_,name,fullName,_,online=GetGuildTradeSkillInfo(index)
            if header then profession=id
            else add(fullName or name,profession,online==true or online==1) end
        end
    end
    self.foreverGuildDirectoryCache={guild=guild,at=now,rows=rows}
    return rows
end

