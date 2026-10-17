local _, AF = ...

local EnsureDB = AF.EnsureDB
function AF:EnsureDB()
    EnsureDB(self)
    if not self.db.foreverAvailabilityDefaultsApplied then
        self.db.rememberManualAvailability = true
        self.db.foreverAvailabilityDefaultsApplied = true
    end
end

-- Forever has no Delves. Only actual dungeon/PvP instances should apply the
-- activity exclusions; Retail-only API stubs must not disable city availability.
function AF:IsInUnavailableActivity()
    if not IsInInstance then return false end
    local inside, kind = IsInInstance()
    if inside ~= true then return false end
    local exclusions = self.db and self.db.autoAvailabilityDisable or {}
    if kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena" then
        return exclusions[kind] ~= false
    end
    return false
end

function AF:GetInitialFlavorAvailabilityMode()
    if self.db.autoAvailability then
        local mode = self.db.lastAvailabilityMode
        if mode ~= self.AVAILABILITY_CURRENT and mode ~= self.AVAILABILITY_ACCOUNT then mode = self.AVAILABILITY_ACCOUNT end
        return self:ShouldAutoBeAvailable() and mode or self.AVAILABILITY_UNAVAILABLE
    end
    return self.db.rememberManualAvailability and self.db.manualAvailabilityMode or self.AVAILABILITY_UNAVAILABLE
end
