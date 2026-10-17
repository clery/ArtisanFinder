local AF={db={foreverIndicators={}}}
local A={handlers={},L={},Safe=function(value) return value~="SECRET" end}
AF.foreverIndicatorsAdapter=A
A.On=function(event,handler) A.handlers[event]=handler end
AF.Text=function(_,key) return key end
local values,writes,popups,combat,failure={},0,{},false,nil
local FRIENDLY="nameplateShowFriendlyPlayers"
local ONLY="nameplateShowOnlyNameForFriendlyPlayerUnits"
local NAMES="UnitNameFriendlyPlayerName"
InCombatLockdown=function() return combat end
C_CVar={GetCVar=function(name) return values[name] end,SetCVar=function(name,value)
    assert(not combat) writes=writes+1
    if name==failure then return false end
    values[name]=value return true
end}
StaticPopupDialogs={}
StaticPopup_Show=function(key) popups[#popups+1]=StaticPopupDialogs[key] return {} end
assert(loadfile("Features/Forever/NameplateSetup.lua"))("ArtisanFinder",AF)
AF.RefreshForeverNameplates=function()
    A.db.settings.iconOnly=A.ShouldHideNativeNameplates()
    A.SyncIconOnlyNameplates()
end
local function reset()
    AF.db.foreverIndicators={}
    A.char={} A.readOnly=false A.friendlyNamesApplied=nil A.nameplateChoicePopupShown=nil
    A.db={settings={indicators=true,overhead=true,iconOnly=false}}
    values={[FRIENDLY]="0",[ONLY]="0",[NAMES]="1"}
    writes=0 popups={} combat=false failure=nil
end
reset()
A.TryNameplateSetup() A.TryNameplateSetup()
assert(#popups==1 and writes==0,"ask once without changing settings before an answer")
popups[1].OnAccept()
assert(AF.db.foreverIndicators.showFriendlyNames==true and not A.db.settings.iconOnly)
assert(values[FRIENDLY]=="1" and values[ONLY]=="1" and values[NAMES]=="1","yes enables native names-only anchors")
A.TryNameplateSetup()
assert(#popups==1,"saved choice suppresses later prompts")
AF:SetForeverFriendlyNames(false)
assert(A.db.settings.iconOnly and values[NAMES]=="0","settings can change explicit answer to hide names")
A.friendlyNamesApplied=nil A.SyncIconOnlyNameplates()
assert(A.db.settings.iconOnly,"reload preserves explicit hidden preference regardless of anchor CVars")
AF:SetForeverFriendlyNames(true)
assert(not A.db.settings.iconOnly and values[NAMES]=="1","settings can restore friendly names")
A.db.settings.indicators=false A.SyncIconOnlyNameplates()
assert(values[FRIENDLY]=="0" and values[ONLY]=="0" and values[NAMES]=="1","disable restores original settings after multiple choices")
reset() A.TryNameplateSetup() popups[1].OnCancel(nil,nil,"override")
assert(AF.db.foreverIndicators.showFriendlyNames==nil,"popup dismissal is not a no answer")
popups[1].OnCancel(nil,nil,"clicked")
assert(AF.db.foreverIndicators.showFriendlyNames==false and values[NAMES]=="0","explicit no hides names")
reset() combat=true A.TryNameplateSetup()
assert(#popups==0 and writes==0,"prompt and CVar writes defer in combat")
combat=false A.TryNameplateSetup() popups[1].OnAccept()
combat=true AF:SetForeverFriendlyNames(false)
assert(values[NAMES]=="1","settings changes defer protected writes during combat")
combat=false A.handlers.PLAYER_REGEN_ENABLED()
assert(values[NAMES]=="0","pending explicit choice applies after combat")
reset() A.readOnly=true A.TryNameplateSetup()
assert(#popups==0 and writes==0,"read-only data cannot apply setup")
reset() A.char.iconOnlyNameplateRestore="0" A.char.iconOnlyNameOnlyRestore="0"
values[FRIENDLY]="1" values[ONLY]="1"
AF:SetForeverFriendlyNames(false)
A.db.settings.indicators=false A.SyncIconOnlyNameplates()
assert(values[FRIENDLY]=="0" and values[ONLY]=="0","legacy experimental restoration data is preserved")
reset() failure=FRIENDLY AF:SetForeverFriendlyNames(true)
assert(A.friendlyNamesApplied==nil,"failed apply remains pending")
failure=nil A.SyncIconOnlyNameplates()
assert(values[FRIENDLY]=="1" and A.friendlyNamesApplied==true,"failed apply retries")
print("PASS explicit friendly-name prompt, yes/no choices, settings changes, reload, restore, legacy migration and combat deferral")

reset()
Enum={NamePlateSimplifiedType={FriendlyPlayer=3}}
values.nameplateSimplifiedTypes="15"
AF:SetForeverFriendlyNames(true)
assert(values.nameplateSimplifiedTypes=="11","show names disables friendly-player simplification only")
assert(values[NAMES]=="1" and math.floor(tonumber(values.nameplateSimplifiedTypes)/4)%2==0,
    "untargeted native names pass the simplified-unit name visibility rule")
-- Change a different simplification category while AF owns the friendly bit.
values.nameplateSimplifiedTypes="10"
A.db.settings.indicators=false A.SyncIconOnlyNameplates()
assert(values.nameplateSimplifiedTypes=="14","restoration preserves later edits to other unit categories")
reset() values.nameplateSimplifiedTypes="15"
AF:SetForeverFriendlyNames(true)
AF:SetForeverFriendlyNames(false)
assert(values.nameplateSimplifiedTypes=="15","choosing no restores original friendly simplification")
reset() values.nameplateSimplifiedTypes="11"
AF:SetForeverFriendlyNames(true)
assert(values.nameplateSimplifiedTypes=="11" and not A.char.nameplatePreferencesRestore.nameplateSimplifiedTypes,
    "already-unsimplified player settings are not claimed or modified")
print("PASS actual Forever simplified-nameplate flag, untargeted name eligibility and bit-preserving restoration")
