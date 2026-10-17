local count,now,combat=0,1000,false
local function check(value,message) count=count+1 assert(value,message) end
local frames,units,plates,timers,observations={},{},{},{},{}
UIParent={}
local function region()
    return {Hide=function(s) s.shown=false end,Show=function(s) s.shown=true end,
        SetShown=function(s,v) s.shown=v end,ClearAllPoints=function() end,SetPoint=function(s,...) s.point={...} end,
        SetSize=function() end,SetAllPoints=function() end,SetTexture=function(s,v) s.texture=v end,
        SetText=function(s,v) s.text=v end,SetTextColor=function() end,
        AddMaskTexture=function(s,v) s.mask=v end}
end
local eventFrame
CreateFrame=function(_,_,parent)
    local f=region()
    f.RegisterEvent=function() end f.SetScript=function(s,event,fn) s[event]=fn end
    if not parent then eventFrame=f return f end
    assert(parent==UIParent)
    f.SetScale=function(s,value) s.scale=value end
    f.SetFrameStrata=function(s,v) s.strata=v end f.EnableMouse=function(_,v) assert(not v) end
    f.CreateFontString=function(s) s.badge=region() return s.badge end
    f.CreateTexture=function(s,_,_,_,level)
        local key=level==7 and "borders" or "icons" s[key]=s[key] or {}
        local texture=region() table.insert(s[key],texture) return texture
    end
    f.CreateMaskTexture=function(s) s.masks=s.masks or {} local m=region() table.insert(s.masks,m) return m end
    f.IsProtected=function() return false end
    frames[#frames+1]=f return f
end
GetLocale=function() return "enUS" end
InCombatLockdown=function() return combat end IsInInstance=function() return false end
UnitIsPlayer=function(unit) return units[unit] and units[unit].player end
UnitIsFriend=function(_,unit) return units[unit] and units[unit].friend end
UnitName=function(unit) local u=units[unit] or {} return u.name,u.surname end
C_NamePlate={GetNamePlateForUnit=function(unit) return plates[unit] end,GetNamePlates=function() return plates end}
C_Timer={NewTimer=function(delay,callback)
    local timer={delay=delay,callback=callback,Cancel=function(s) s.cancelled=true end}
    table.insert(timers,timer) return timer
end}
local AF={ADDON_NAME="ArtisanFinder",playerName="Self-Realm",db={}}
assert(loadfile("Flavors/Forever.lua"))("ArtisanFinder",AF)
function AF:Now() return now end
function AF:NormalizeName(name) return name:lower() end
function AF:GetForeverNameplateObservation(name) return observations[name:lower()] end
assert(loadfile("Features/Forever/Names.lua"))("ArtisanFinder",AF)
assert(loadfile("Features/Forever/Indicators.lua"))("ArtisanFinder",AF)
assert(loadfile("Features/Forever/NameplateScaling.lua"))("ArtisanFinder",AF)
assert(loadfile("Features/Forever/Nameplates.lua"))("ArtisanFinder",AF)
local A=AF.foreverIndicatorsAdapter
-- This fixture isolates native-frame rendering; automatic preference selection is
-- covered by forever_nameplate_setup.lua.
A.ShouldHideNativeNameplates=function() return AF.db.foreverIndicators.iconOnly~=false end
local function emit(event,...) eventFrame.OnEvent(eventFrame,event,...) end
local function shown()
    local out={} for _,f in ipairs(frames) do if f.shown then out[#out+1]=f end end return out
end
local function add(unit,name)
    units[unit]={name=name,surname="Surname",friend=true,player=true}
    local plate={scripts={},GetUnit=function() return unit end,IsForbidden=function() return false end}
    plate.UnitFrame={alpha=1,name={alpha=.8}}
    plate.UnitFrame.name.GetAlpha=function(s) return s.alpha end
    plate.UnitFrame.name.SetAlpha=function(s,value) s.alpha=value end
    plate.UnitFrame.GetAlpha=function(s) return s.alpha end
    plate.UnitFrame.SetAlpha=function(s,value) s.alpha=value end
    plate.IsShown=function() return not plate.hidden end
    plate.HookScript=function(s,event,fn) s.scripts[event]=fn end
    plates[unit]=plate
end
add("nameplate1","Artisan") add("nameplate2","Unknown")
observations["artisan surname"]={source="TRADE",professions={[164]=true,[202]=true},expiresAt=1100}
emit("PLAYER_LOGIN")
check(#shown()==1,"bridge matches only observed artisan")
check(plates.nameplate1.UnitFrame.name.alpha==0 and plates.nameplate2.UnitFrame.name.alpha==0,
    "icon-only hides native friendly visuals, including players without advertisements")
local icon=shown()[1]
check(icon.strata=="BACKGROUND","icons below ordinary UI")
check(icon.point[2]==plates.nameplate1,"profession overlay stays anchored to native moving plate")
check(#icon.icons==2 and #icon.masks==2 and #icon.borders==2,"multiple circular icons with brass borders")
check(icon.badge==nil,"nameplate icons have no text label")
check(timers[#timers].delay==100,"expiry timer derived from observation")
now=1100 timers[#timers].callback()
check(#shown()==0,"expiry hides indicators")
observations["artisan surname"]={source="ADDON",professions={[164]=true},expiresAt=1300}
AF:RefreshForeverNameplates()
check(#shown()==1 and shown()[1].badge==nil,"addon indicators render without text")
check(not shown()[1].icons[2].shown and not shown()[1].borders[2].shown,"pool hides surplus icons and rims")
plates.nameplate1.hidden=true plates.nameplate1.scripts.OnHide()
check(#shown()==0,"hidden native anchor cleans overlay")
plates.nameplate1.hidden=false plates.nameplate1.scripts.OnShow()
check(#shown()==1,"native visibility restores overlay")
combat=true emit("PLAYER_REGEN_DISABLED")
check(#shown()==0,"combat cleanup")
check(plates.nameplate1.UnitFrame.name.alpha==.8,"combat cleanup restores prior native alpha")
combat=false emit("PLAYER_REGEN_ENABLED")
check(#shown()==1,"combat end restores indicator")
AF.db.foreverIndicators.enabled=false AF:RefreshForeverNameplates()
check(#shown()==0,"settings disable indicators")
check(plates.nameplate1.UnitFrame.name.alpha==.8 and plates.nameplate2.UnitFrame.name.alpha==.8,
    "disabling indicators restores all native friendly frames")
AF.db.foreverIndicators.enabled=true AF.db.foreverIndicators.offset=-100 AF:RefreshForeverNameplates()
check(#shown()==1 and A.db.settings.iconOffset==-100,"negative offset retained")
local allocated=#frames
for i=1,30 do AF:RefreshForeverNameplates() end
check(#frames==allocated,"bounded pool across refreshes")
units.nameplate1.name="Unknown" emit("UNIT_NAME_UPDATE","nameplate1")
check(#shown()==0,"recycled identity cannot retain stale icon")
print("PASS "..count.." Forever nameplate assertions")

AF.Text=function(_,key,...) return key end
AF.Print=function() end
assert(loadfile("Features/Forever/Demo.lua"))("ArtisanFinder",AF)
units.nameplate1.name="Demo"
units.target=units.nameplate1
units.player={name="Self",surname="Surname",player=true,friend=true}
check(AF:HandleFlavorSlash("demo", ""),"demo slash handled by Forever")
check(AF.foreverNameplateDemo.name=="Demo Surname","demo uses friendly target full name")
check(#shown()==1 and shown()[1].badge==nil,"demo uses circular icons without text")
check(#shown()[1].icons>=3,"demo renders sample professions")
combat=true emit("PLAYER_REGEN_DISABLED")
check(#shown()==0,"demo respects combat suppression")
combat=false emit("PLAYER_REGEN_ENABLED")
check(#shown()==1,"demo restores after combat")
AF:HandleFlavorSlash("demo","off")
check(not AF.foreverNameplateDemo and #shown()==0,"demo off removes temporary observation and icons")
units.target=nil
AF:StartForeverNameplateDemo()
check(AF.foreverNameplateDemo.name=="Self Surname","demo falls back to player")
local timer=AF.foreverDemoTimer
check(timer.delay==300,"demo expires after five minutes")
now=now+300 timer.callback()
check(not AF.foreverNameplateDemo,"timer clears demo")
check(not AF.db.foreverNameplateDemo,"demo is not persisted")
check(not AF:HandleFlavorSlash("other",""),"unrelated commands continue to shared slash handler")
print("PASS Forever demo targeting, circular rendering, badge, stop, expiry and combat behavior")

AF.db.foreverIndicators.iconOnly=false
AF:RefreshForeverNameplates()
check(plates.nameplate1.UnitFrame.name.alpha==.8,"normal mode retains native visuals")
AF.db.foreverIndicators.iconOnly=true
AF:RefreshForeverNameplates()
check(plates.nameplate1.UnitFrame.name.alpha==0,"icon-only mode can be re-enabled")
emit("NAME_PLATE_UNIT_REMOVED","nameplate1")
check(plates.nameplate1.UnitFrame.name.alpha==.8,"removed plate is restored before recycling")
units.nameplate1.player=false
emit("NAME_PLATE_UNIT_ADDED","nameplate1")
check(plates.nameplate1.UnitFrame.name.alpha==.8,"NPC nameplate visuals remain untouched")
units.nameplate1.player=true units.nameplate1.friend=false
emit("UNIT_NAME_UPDATE","nameplate1")
check(plates.nameplate1.UnitFrame.name.alpha==.8,"enemy player visuals remain untouched")
print("PASS icon-only friendly visuals, normal mode, combat, disabling and plate recycling")

hooksecurefunc=function(object,method,callback)
    local original=object[method]
    object[method]=function(...) local result=original(...) callback(...) return result end
end
add("nameplate3","Fade Test")
emit("NAME_PLATE_UNIT_ADDED","nameplate3")
plates.nameplate3.UnitFrame.name:SetAlpha(.6)
check(plates.nameplate3.UnitFrame.name.alpha==0,"native alpha updates cannot reveal hidden friendly visuals")
AF.db.foreverIndicators.iconOnly=false AF:RefreshForeverNameplates()
check(plates.nameplate3.UnitFrame.name.alpha==.6,"normal mode restores latest native fade alpha")
print("PASS native alpha hook preserves hidden visuals without polling and restores updated alpha")

-- Explicit preference controls visibility independently of native CVar values.
C_CVar={GetCVar=function() return "1" end,SetCVar=function() return true end}
assert(loadfile("Features/Forever/NameplateSetup.lua"))("ArtisanFinder",AF)
AF:SetForeverFriendlyNames(false)
check(plates.nameplate3.UnitFrame.name.alpha==0,"explicit no hides names even when native CVars are enabled")
AF:SetForeverFriendlyNames(true)
check(plates.nameplate3.UnitFrame.name.alpha==.6,"explicit yes immediately restores native names")
print("PASS explicit friendly-name preference controls native visibility")

local function settleAnimations()
    for step=1,6 do
        for _,frame in ipairs(frames) do if frame.OnUpdate then frame.OnUpdate(frame,.05) end end
    end
end
local distance,ticker=5,nil
UnitDistanceSquared=function() return distance*distance,true end
C_Timer.NewTicker=function(interval,callback)
    ticker={interval=interval,tick=callback,Cancel=function(self) self.cancelled=true end}
    return ticker
end
units.nameplate3.friend=true units.nameplate3.player=true
observations["fade test surname"]={source="ADDON",professions={[164]=true},expiresAt=now+100}
AF:RefreshForeverNameplates()
local scaled
for _,frame in ipairs(shown()) do if frame.point[2]==plates.nameplate3 then scaled=frame end end
check(scaled and scaled.scale==1,"nearby artisan uses configured icon size")
check(ticker and ticker.interval==.25,"distance updates are limited to four per second")
distance=40 ticker.tick()
check(scaled.scale==1 and scaled.OnUpdate,"new estimated range starts a tween instead of snapping")
scaled.OnUpdate(scaled,.125)
check(scaled.scale>.5 and scaled.scale<1,"icon moves through intermediate sizes")
settleAnimations()
check(not scaled.OnUpdate,"finished tween removes per-frame handler")
check(scaled.scale==.5,"farther artisan icon shrinks to 50 percent while moving")
distance=500 ticker.tick()
check(scaled.scale==.5,"distant icons stay at 50 percent size")
UnitDistanceSquared=function() return 0,false end
ticker.tick() settleAnimations()
check(scaled.scale==1,"unavailable distance safely falls back to normal scale")
local running=ticker
AF.db.foreverIndicators.enabled=false AF:RefreshForeverNameplates()
check(running.cancelled,"distance ticker stops when indicators are disabled")
print("PASS distance-based icon scaling, moving units, minimum size, unavailable data and ticker cleanup")

AF.db.foreverIndicators.enabled=true
AF:SetForeverFriendlyNames(false)
check(plates.nameplate3.UnitFrame.alpha==1,"hiding names never changes native unit frame opacity")
AF:SetForeverFriendlyNames(true)
check(plates.nameplate3.UnitFrame.name.alpha>0 and plates.nameplate3.UnitFrame.alpha==1,
    "show names restores text without changing native unit frame visibility")
-- Native name text can start transparent while a plate is being initialized.
plates.nameplate3.UnitFrame.name.alpha=0
AF:SetForeverFriendlyNames(false)
AF:SetForeverFriendlyNames(true)
check(plates.nameplate3.UnitFrame.name.alpha==1,"show names cannot restore a stale zero alpha from initialization")
print("PASS only name text is hidden; native unit frame is untouched and zero-alpha restoration is repaired")

AF.db.foreverIndicators.enabled=true
local distances={nameplate4=5,nameplate5=60,nameplate6=45}
for _,pair in ipairs({{"nameplate4","Nearby"},{"nameplate5","Faraway"},{"nameplate6","Stranger"}}) do
    add(pair[1],pair[2])
    observations[(pair[2].." Surname"):lower()]={source="ADDON",professions={[164]=true},expiresAt=now+100}
end
UnitDistanceSquared=function(unit)
    if unit=="nameplate6" then return 0,false end
    local value=distances[unit]
    return value and value*value or 0,value~=nil
end
CheckInteractDistance=function(unit,index)
    if not distances[unit] then return end
    return distances[unit]<=(index==3 and 8 or 28)
end
C_Item={IsItemInRange=function(itemID,unit)
    if not distances[unit] then return end
    return distances[unit]<=({[1251]=15,[1180]=30,[18662]=40})[itemID]
end}
AF:RefreshForeverNameplates()
local function scaleOf(unit)
    for _,frame in ipairs(shown()) do if frame.point[2]==plates[unit] then return frame.scale end end
end
check(scaleOf("nameplate4")==1 and scaleOf("nameplate5")==.5 and scaleOf("nameplate6")==.5,
    "simultaneous near, far and nongroup players each receive their own scale")
distances.nameplate4=50 distances.nameplate5=5 distances.nameplate6=6
ticker.tick() settleAnimations()
check(scaleOf("nameplate4")==.5 and scaleOf("nameplate5")==1 and scaleOf("nameplate6")>.9,
    "one timer independently follows all players moving in opposite directions")
print("PASS multiple simultaneous players scale independently, including nongroup distance estimates")

distances.nameplate4=5 distances.nameplate5=60
ticker.tick()
local animating=0
for _,frame in ipairs(shown()) do if frame.OnUpdate then animating=animating+1 end end
check(animating>=2,"multiple moving players animate independently")
AF.db.foreverIndicators.enabled=false AF:RefreshForeverNameplates()
for _,frame in ipairs(frames) do check(not frame.OnUpdate,"released overlays cannot retain animation handlers") end
print("PASS smooth independent size transitions, intermediate scales, idle and release cleanup")
