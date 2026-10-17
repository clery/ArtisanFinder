local _, AF = ...
local A = AF.foreverIndicatorsAdapter
local FRIENDLY="nameplateShowFriendlyPlayers"
local ONLY_NAME="nameplateShowOnlyNameForFriendlyPlayerUnits"
local NAMES="UnitNameFriendlyPlayerName"
local SIMPLIFIED="nameplateSimplifiedTypes"
local POPUP="ARTISANFINDER_FRIENDLY_NAMES"

local function read(name)
    if not C_CVar or type(C_CVar.GetCVar)~="function" then return end
    local ok,value=pcall(C_CVar.GetCVar,name)
    if ok and A.Safe(value) then
        if value=="0" or value=="1" then return value end
        local numeric=type(value)=="string" and tonumber(value)
        if name==SIMPLIFIED and numeric and numeric>=0 and numeric%1==0 then return value end
    end
end
local function write(name,value)
    if InCombatLockdown() or not C_CVar or type(C_CVar.SetCVar)~="function" then return false end
    local ok,result=pcall(C_CVar.SetCVar,name,value)
    return ok and A.Safe(result) and result~=false and read(name)==value
end
local function savedSettings()
    local saved=A.char.nameplatePreferencesRestore or {}
    A.char.nameplatePreferencesRestore=saved
    -- Preserve restoration data left by previous experimental versions.
    for name,value in pairs(A.char.nameplateRestore or {}) do
        if saved[name]==nil then saved[name]={previous=value,applied="1"} end
    end
    for name,field in pairs({[FRIENDLY]="iconOnlyNameplateRestore",[ONLY_NAME]="iconOnlyNameOnlyRestore"}) do
        if A.char[field] and saved[name]==nil then saved[name]={previous=A.char[field],applied="1"} end
        A.char[field]=nil
    end
    A.char.nameplateRestore=nil
    return saved
end
local function restoreSetting(name,entry)
    local current=read(name)
    if entry.bit and current then
        -- Restore only our bit, even if another unit category changed meanwhile.
        local value=tonumber(current)
        local mask=2^(entry.bit-1)
        local currentBit=math.floor(value/mask)%2
        local appliedBit=math.floor(tonumber(entry.applied)/mask)%2
        local originalBit=math.floor(tonumber(entry.previous)/mask)%2
        if currentBit==appliedBit and currentBit~=originalBit then
            return write(name,tostring(value+(originalBit-currentBit)*mask))
        end
        return true
    end
    return current~=entry.applied or write(name,entry.previous)
end
local function syncFriendlySimplification(showNames,saved)
    local index=Enum and Enum.NamePlateSimplifiedType and Enum.NamePlateSimplifiedType.FriendlyPlayer
    if not index then return true end
    local current=read(SIMPLIFIED)
    if not current then return true end
    if not showNames then
        local previous=saved[SIMPLIFIED]
        if previous and not restoreSetting(SIMPLIFIED,previous) then return false end
        saved[SIMPLIFIED]=nil
        return true
    end
    local value=tonumber(current)
    local mask=2^(index-1)
    if math.floor(value/mask)%2==0 then return true end
    local applied=tostring(value-mask)
    if not saved[SIMPLIFIED] then saved[SIMPLIFIED]={previous=current,applied=applied,bit=index} end
    saved[SIMPLIFIED].applied=applied
    return write(SIMPLIFIED,applied)
end
function A.ShouldHideNativeNameplates()
    return AF.db and AF.db.foreverIndicators and AF.db.foreverIndicators.showFriendlyNames==false
end
function A.SyncIconOnlyNameplates()
    if not A.char or A.readOnly or InCombatLockdown() then return end
    local settings=A.db and A.db.settings
    local preference=AF.db and AF.db.foreverIndicators and AF.db.foreverIndicators.showFriendlyNames
    local enabled=settings and settings.indicators and settings.overhead and type(preference)=="boolean"
    local saved=savedSettings()
    if not enabled then
        for _,name in ipairs({FRIENDLY,ONLY_NAME,NAMES,SIMPLIFIED}) do
            local entry=saved[name]
            if entry then
                if not restoreSetting(name,entry) then return end
                saved[name]=nil
            end
        end
        A.friendlyNamesApplied=nil
        return
    end
    settings.iconOnly=preference==false
    -- Both choices need native nameplate anchors. Only the explicit choice
    -- controls names; no guessing from current CVars or hooks on user settings.
    for _,setting in ipairs({{ONLY_NAME,"1"},{NAMES,preference and "1" or "0"},{FRIENDLY,"1"}}) do
        local name,value=setting[1],setting[2]
        local current=read(name)
        if current==nil then return end
        if current~=value then
            if not saved[name] then saved[name]={previous=current,applied=value} end
            saved[name].applied=value
            if not write(name,value) then return end
        elseif saved[name] then saved[name].applied=value end
    end
    if not syncFriendlySimplification(preference,saved) then return end
    A.friendlyNamesApplied=preference
end
function AF:SetForeverFriendlyNames(value)
    self.db.foreverIndicators=self.db.foreverIndicators or {}
    self.db.foreverIndicators.showFriendlyNames=value==true
    if StaticPopup_Hide then StaticPopup_Hide(POPUP) end
    A.friendlyNamesApplied=nil
    if self.RefreshForeverNameplates then self:RefreshForeverNameplates() end
end
function A.TryNameplateSetup()
    if not A.char or A.readOnly or InCombatLockdown() then return end
    local settings=AF.db and AF.db.foreverIndicators
    if not settings or type(settings.showFriendlyNames)=="boolean" then A.SyncIconOnlyNameplates() return end
    if A.nameplateChoicePopupShown or not StaticPopupDialogs or not StaticPopup_Show then return end
    StaticPopupDialogs[POPUP]={
        text=AF:Text("FOREVER_FRIENDLY_NAMES_QUESTION"),
        button1=YES or "Yes",button2=NO or "No",
        OnAccept=function() AF:SetForeverFriendlyNames(true) end,
        OnCancel=function(_,_,reason)
            if reason==nil or reason=="clicked" then AF:SetForeverFriendlyNames(false) end
        end,
        OnHide=function() A.nameplateChoicePopupShown=nil end,
        timeout=0,whileDead=1,hideOnEscape=false,preferredIndex=3,wide=1,
    }
    A.nameplateChoicePopupShown=StaticPopup_Show(POPUP)~=nil
end
A.On("PLAYER_LOGIN",A.TryNameplateSetup)
A.On("PLAYER_ENTERING_WORLD",A.TryNameplateSetup)
A.On("PLAYER_REGEN_ENABLED",A.TryNameplateSetup)
