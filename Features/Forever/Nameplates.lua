local _, AF = ...

---@class ArtisanFinderNamePlate : NamePlateFrame
---@field GetUnit fun(self: ArtisanFinderNamePlate): string?

local A = AF.foreverIndicatorsAdapter
local visible, active, pool = {}, {}, {}
local expiryTimer
local observedPlates = setmetatable({}, {__mode = "k"})
local function truth(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn, ...)
    return ok and A.Safe(value) and value == true
end
local hiddenFrames=setmetatable({}, {__mode="k"})
local function wantsHiddenNames()
    return A.ShouldHideNativeNameplates and A.ShouldHideNativeNameplates()==true
end
local function restoreNative(unit)
    for frame,state in pairs(hiddenFrames) do
        if state.hidden and (not unit or state.unit==unit) then
            state.writing=true
            state.hidden=false
            local alpha=state.alpha
            if not wantsHiddenNames() and alpha==0 then alpha=1 end
            local ok=pcall(frame.SetAlpha,frame,alpha)
            state.writing=nil
            if not ok then state.hidden=true end
        end
    end
end
local function hideNative(unit,plate)
    if not wantsHiddenNames() then return end
    -- Name-only mode already hides bars. Never hide the entire native frame:
    -- only the name text belongs to our explicit visibility preference.
    local frame=plate and plate.UnitFrame and plate.UnitFrame.name
    if not frame or type(frame.SetAlpha)~="function" or type(frame.GetAlpha)~="function" then return end
    local ok,alpha=pcall(frame.GetAlpha,frame)
    if not ok or not A.Safe(alpha) or type(alpha)~="number" then return end
    local state=hiddenFrames[frame]
    if not state then state={} hiddenFrames[frame]=state end
    if not state.hidden then state.alpha=alpha end
    state.unit=unit
    state.writing=true
    state.hidden=pcall(frame.SetAlpha,frame,0)
    state.writing=nil
    -- Native range/fade updates may reset alpha. Follow those writes without polling.
    if state.hidden and not state.hooked and hooksecurefunc then
        state.hooked=pcall(hooksecurefunc,frame,"SetAlpha",function(_,value)
            if state.writing or not state.hidden or InCombatLockdown() then return end
            if not A.Safe(value) or type(value)~="number" then return end
            if not wantsHiddenNames() then
                if value>0 then state.alpha=value end
                restoreNative(state.unit)
                return
            end
            if value==0 then return end
            state.alpha=value
            state.writing=true
            pcall(frame.SetAlpha,frame,0)
            state.writing=nil
        end)
    end
end
local function release(unit)
    local entry = active[unit]
    if not entry then return end
    entry.frame:SetScript("OnUpdate",nil)
    entry.scaleAnimating=nil
    entry.frame:Hide()
    entry.frame:ClearAllPoints()
    active[unit] = nil
    if not next(active) then A.StopNameplateScaling() end
    pool[#pool + 1] = entry
end
local function clear()
    restoreNative()
    if expiryTimer then expiryTimer:Cancel() expiryTimer = nil end
    for unit in pairs(active) do release(unit) end
end
local function allowed()
    return A.db and A.db.settings.indicators and A.db.settings.overhead
        and not InCombatLockdown() and not (IsInInstance and IsInInstance())
        and C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function"
end
local function acquire()
    local entry = table.remove(pool)
    if entry then return entry end
    local f = CreateFrame("Frame", nil, UIParent)
    f:Hide()
    f:EnableMouse(false)
    f:SetFrameStrata("BACKGROUND")
    return {frame = f, icons = {}}
end

function A.UpdateOverhead()
    if expiryTimer then expiryTimer:Cancel() expiryTimer = nil end
    if not allowed() then clear() return end
    if not wantsHiddenNames() then restoreNative() end
    local now, nextExpiry = A.Now(), nil
    for unit in pairs(visible) do
        release(unit)
        if truth(UnitIsPlayer, unit) and truth(UnitIsFriend, "player", unit) then
            if wantsHiddenNames() then
                local ok,plate=pcall(C_NamePlate.GetNamePlateForUnit,unit)
                if ok and A.Safe(plate) and plate then
                    local safe,forbidden=pcall(plate.IsForbidden,plate)
                    if safe and A.Safe(forbidden) and forbidden==false then hideNative(unit,plate) end
                end
            end
            local profile = A.FindUnit(unit)
            local observation, source
            if profile then observation, source = A.Current(profile, now) end
            if observation and source ~= "historical" then
                local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
                local forbiddenOK, forbidden
                if ok and A.Safe(plate) and plate then
                    ---@cast plate ArtisanFinderNamePlate
                    forbiddenOK, forbidden = pcall(plate.IsForbidden, plate)
                end
                local unitOK, assigned
                if forbiddenOK and A.Safe(forbidden) and forbidden == false then
                    ---@cast plate ArtisanFinderNamePlate
                    unitOK, assigned = pcall(plate.GetUnit, plate)
                end
                if unitOK and A.Safe(assigned) and assigned == unit and truth(plate.IsShown, plate) then
                    -- Observe native visibility without replacing Blizzard scripts.
                    -- UIParent-owned overlays otherwise outlive a hidden anchor.
                    if not observedPlates[plate] and type(plate.HookScript) == "function" then
                        local hidden = pcall(plate.HookScript, plate, "OnHide", function()
                            for token, entry in pairs(active) do
                                if entry.plate == plate then release(token) end
                            end
                        end)
                        local shown = pcall(plate.HookScript, plate, "OnShow", function()
                            if A.db then A.UpdateOverhead() end
                        end)
                        observedPlates[plate] = hidden and shown
                    end
                    local professions = {}
                    for id, enabled in pairs(observation.professions or {}) do
                        if enabled and A.catalog[id] then professions[#professions+1] = id end
                    end
                    table.sort(professions)
                    if #professions > 0 and observedPlates[plate] then
                        local entry = acquire()
                        entry.plate = plate
                        local size = A.db.settings.iconSize
                        entry.frame:SetSize(#professions * (size + 2) - 2, size)
                        for i, id in ipairs(professions) do
                            local icon = entry.icons[i]
                            if not icon then
                                icon = entry.frame:CreateTexture(nil, "OVERLAY")
                                A.MaskNameplateIcon(entry.frame,icon)
                                entry.icons[i] = icon
                            end
                            icon:ClearAllPoints()
                            icon:SetPoint("LEFT", entry.frame, "LEFT", (i-1)*(size+2), 0)
                            icon:SetSize(size, size)
                            icon:SetTexture(A.Icon(id))
                            if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
                            A.ShowNameplateIcon(icon,true)
                        end
                        for i = #professions+1, #entry.icons do A.ShowNameplateIcon(entry.icons[i],false) end
                        local attached = pcall(entry.frame.SetPoint, entry.frame, "BOTTOM", plate, "TOP", 0, 12 + A.db.settings.iconOffset)
                        active[unit] = entry
                        local protectionOK, protected = pcall(entry.frame.IsProtected, entry.frame)
                        if attached and protectionOK and A.Safe(protected) and protected == false then
                            A.UpdateNameplateScale(unit,entry)
                            entry.frame:Show()
                            local expires = observation.expiresAt
                            if expires and expires > now and (not nextExpiry or expires < nextExpiry) then nextExpiry = expires end
                        else
                            release(unit)
                            A.Log("Overhead attachment unavailable: " .. unit)
                        end
                    end
                end
            end
        end
    end
    A.StartNameplateScaling(active)
    -- One deadline for visible advertisements, not per-frame polling or a cache scan.
    if nextExpiry and C_Timer and C_Timer.NewTimer then
        expiryTimer = C_Timer.NewTimer(math.max(0.05, nextExpiry-now), function()
            expiryTimer = nil
            A.UpdateWorld()
        end)
    end
end

function A.RescanNameplates()
    if A.SyncIconOnlyNameplates then A.SyncIconOnlyNameplates() end
    clear()
    visible = {}
    if not allowed() or type(C_NamePlate.GetNamePlates) ~= "function" then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or not A.Safe(plates) or type(plates) ~= "table" then return end
    local count = 0
    for _, plate in pairs(plates) do
        if A.Safe(plate) and plate then
            ---@cast plate ArtisanFinderNamePlate
            local valid, forbidden = pcall(plate.IsForbidden, plate)
            if valid and A.Safe(forbidden) and forbidden == false then
                local got, unit = pcall(plate.GetUnit, plate)
                if got and A.Safe(unit) and type(unit) == "string" and unit:match("^nameplate%d+$") then
                    visible[unit] = true
                    count = count + 1
                    if count >= 80 then break end
                end
            end
        end
    end
    A.UpdateOverhead()
end

A.On("NAME_PLATE_UNIT_ADDED", function(unit)
    if not A.Safe(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    visible[unit] = true
    if A.db then A.UpdateOverhead() end
end)
A.On("NAME_PLATE_UNIT_REMOVED", function(unit)
    if not A.Safe(unit) or type(unit) ~= "string" then return end
    visible[unit] = nil
    restoreNative(unit)
    release(unit)
    if A.db then A.UpdateOverhead() end
end)
A.On("UNIT_NAME_UPDATE", function(unit)
    if A.Safe(unit) and type(unit) == "string" and visible[unit] then A.UpdateOverhead() end
end)
A.On("PLAYER_REGEN_DISABLED", clear)
A.On("PLAYER_REGEN_ENABLED", A.RescanNameplates)
A.On("PLAYER_ENTERING_WORLD", A.RescanNameplates)
A.On("PLAYER_LOGIN", A.RescanNameplates)

