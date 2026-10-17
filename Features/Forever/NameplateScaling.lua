local _, AF = ...
local A=AF.foreverIndicatorsAdapter
local scaleTicker

-- Exact distance is not exposed for every nongroup player. Use read-only
-- range brackets for those units; each player's checks remain independent.
local friendlyRangeItems={{1251,15},{1180,30},{18662,40}}
local rangeItemsRequested=false
local function estimateDistance(unit)
    local minimum,maximum,answered=0,math.huge,false
    local function bracket(fn,range,...)
        if type(fn)~="function" then return end
        local ok,result=pcall(fn,...)
        if not ok or not A.Safe(result) then return end
        if result==true or result==1 then maximum=math.min(maximum,range) answered=true
        elseif result==false or result==0 then minimum=math.max(minimum,range) answered=true end
    end
    bracket(CheckInteractDistance,8,unit,3)
    bracket(CheckInteractDistance,28,unit,4)
    if C_Item and C_Item.IsItemInRange then
        if not rangeItemsRequested and C_Item.RequestLoadItemDataByID then
            rangeItemsRequested=true
            for _,probe in ipairs(friendlyRangeItems) do pcall(C_Item.RequestLoadItemDataByID,probe[1]) end
        end
        for _,probe in ipairs(friendlyRangeItems) do bracket(C_Item.IsItemInRange,probe[2],probe[1],unit) end
    end
    if not answered then return end
    if maximum<math.huge then return math.max(minimum,math.min(maximum,(minimum+maximum)/2)) end
    return math.max(40,minimum)
end
local function distanceTo(unit)
    if UnitDistanceSquared then
        local ok,squared,checked=pcall(UnitDistanceSquared,unit)
        if ok and A.Safe(checked) and checked==true and A.Safe(squared)
            and type(squared)=="number" and squared>=0 then return math.sqrt(squared) end
    end
    if UnitPosition then
        local ok,x,y,z,map=pcall(UnitPosition,unit)
        local own,px,py,pz,pmap=pcall(UnitPosition,"player")
        if ok and own and A.Safe(map) and A.Safe(pmap) and map~=nil and map==pmap
            and A.Safe(x) and A.Safe(y) and A.Safe(z) and A.Safe(px) and A.Safe(py) and A.Safe(pz)
            and type(x)=="number" and type(y)=="number" and type(z)=="number"
            and type(px)=="number" and type(py)=="number" and type(pz)=="number" then
            return math.sqrt((x-px)^2+(y-py)^2+(z-pz)^2)
        end
    end
    return estimateDistance(unit)
end
function A.UpdateNameplateScale(unit,entry)
    if type(entry.frame.SetScale)~="function" then return end
    local distance=distanceTo(unit)
    local scale=1
    if distance then
        -- Full configured size within 5 yards, 50% size at 40 yards and beyond.
        scale=math.max(.5,math.min(1,1-.5*(distance-5)/35))
    elseif entry.plate and type(entry.plate.GetEffectiveScale)=="function"
        and type(UIParent.GetEffectiveScale)=="function" then
        local ok,value=pcall(entry.plate.GetEffectiveScale,entry.plate)
        local parentOK,parent=pcall(UIParent.GetEffectiveScale,UIParent)
        if ok and parentOK and A.Safe(value) and A.Safe(parent)
            and type(value)=="number" and type(parent)=="number" and parent>0 then
            scale=math.max(.5,math.min(1,value/parent))
        end
    end
    if entry.scaleOwner~=unit or not entry.scale then
        entry.scaleOwner=unit
        entry.scale=scale
        entry.targetScale=scale
        entry.frame:SetScale(scale)
        return
    end
    if entry.targetScale==scale and entry.scaleAnimating then return end
    entry.targetScale=scale
    if math.abs(entry.scale-scale)<.0001 then
        entry.scale=scale
        entry.frame:SetScale(scale)
        entry.scaleAnimating=nil
        entry.frame:SetScript("OnUpdate",nil)
        return
    end
    local initial,elapsed=entry.scale,0
    entry.scaleAnimating=true
    -- Distance probes stay at 4 Hz. Only a short visual tween runs per frame,
    -- and its handler is removed as soon as the transition finishes.
    entry.frame:SetScript("OnUpdate",function(frame,delta)
        elapsed=elapsed+delta
        local progress=math.min(1,elapsed/.25)
        local eased=1-(1-progress)^3
        entry.scale=initial+(scale-initial)*eased
        frame:SetScale(entry.scale)
        if progress>=1 then
            entry.scale=scale
            entry.scaleAnimating=nil
            frame:SetScript("OnUpdate",nil)
        end
    end)
end
function A.StopNameplateScaling()
    if scaleTicker then scaleTicker:Cancel() scaleTicker=nil end
end
function A.StartNameplateScaling(active)
    if scaleTicker or not next(active) or not C_Timer or not C_Timer.NewTicker then return end
    scaleTicker=C_Timer.NewTicker(.25,function()
        if InCombatLockdown() or not next(active) then A.StopNameplateScaling() return end
        for unit,entry in pairs(active) do A.UpdateNameplateScale(unit,entry) end
    end)
end
