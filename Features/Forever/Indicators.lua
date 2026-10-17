local _, AF = ...
-- Keep the previously validated Forever nameplate engine independent of the
-- Retail profile schema. All observations come from the original data model.
local A={catalog={},readOnly=false}
AF.foreverIndicatorsAdapter=A
local icons={
    [164]="Trade_BlackSmithing",[165]="INV_Misc_ArmorKit_17",[171]="Trade_Alchemy",
    [197]="Trade_Tailoring",[202]="Trade_Engineering",[333]="Trade_Engraving",
    [185]="INV_Misc_Food_15",[129]="Spell_Holy_SealOfSacrifice",
}
for id in pairs(icons) do A.catalog[id]=true end
function A.Safe(value) return not (issecretvalue and issecretvalue(value)) end
function A.Now() return AF:Now() end
function A.Log(value) if AF.DebugLog then AF:DebugLog("nameplates",value) end end
function A.Icon(id)
    if id==165 and C_Spell and C_Spell.GetSpellTexture then
        local texture=C_Spell.GetSpellTexture(2108)
        if A.Safe(texture) and texture then return texture end
    end
    return "Interface\\Icons\\"..(icons[id] or "INV_Misc_QuestionMark")
end
local function ready()
    if type(AF.db)~="table" then return false end
    if type(AF.db.foreverIndicators)~="table" then AF.db.foreverIndicators={} end
    local settings=AF.db.foreverIndicators
    if settings.enabled==nil then settings.enabled=true end
    settings.size=math.max(12,math.min(32,tonumber(settings.size) or 24))
    settings.offset=math.max(-100,math.min(30,tonumber(settings.offset) or -20))
    if type(settings.characters)~="table" then settings.characters={} end
    local name=AF.playerName or AF:GetPlayerFullName()
    if not name then return false end
    if type(settings.characters[name])~="table" then settings.characters[name]={} end
    A.char=settings.characters[name]
    A.db={settings={indicators=settings.enabled==true,overhead=settings.enabled==true,iconOnly=A.ShouldHideNativeNameplates and A.ShouldHideNativeNameplates() or false,iconSize=settings.size,iconOffset=settings.offset}}
    return true
end
function A.FindUnit(unit)
    if not AF.GetForeverNameplateObservation then return end
    local fullName=AF:GetForeverUnitFullName(unit)
    return fullName and AF:GetForeverNameplateObservation(fullName)
end
function A.Current(observation,now)
    if observation.expiresAt and observation.expiresAt>(now or A.Now()) then
        return observation,observation.source=="DEMO" and "demo" or (observation.source=="TRADE" and "trade" or "verified")
    end
    return observation,"historical"
end
function A.UpdateWorld() if ready() then A.UpdateOverhead() end end
function AF:RefreshForeverNameplates()
    if ready() and A.RescanNameplates then A.RescanNameplates() end
end
local frame=CreateFrame("Frame")
local handlers={}
function A.On(event,handler)
    handlers[event]=handlers[event] or {}
    table.insert(handlers[event],handler)
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent",function(_,event,...)
    if not ready() then return end
    for _,handler in ipairs(handlers[event] or {}) do handler(...) end
end)
local media="Interface\\AddOns\\"..AF.ADDON_NAME.."\\Assets\\Forever\\"
function A.MaskNameplateIcon(parent,texture)
    if texture.afRoundMask then return texture.afRoundMask end
    local mask=parent:CreateMaskTexture(nil,"ARTWORK") mask:SetAllPoints(texture)
    mask:SetTexture(media.."CircleMask.tga","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE") texture:AddMaskTexture(mask)
    texture.afRoundMask=mask
    local border=parent:CreateTexture(nil,"OVERLAY",nil,7) border:SetAllPoints(texture) border:SetTexture(media.."CircleBorder.tga")
    texture.afRoundBorder=border
    return mask
end
function A.ShowNameplateIcon(texture,shown)
    texture:SetShown(shown) texture.afRoundBorder:SetShown(shown)
end
-- Refresh only after model changes, not on every rendered frame.
for _,method in ipairs({"OnTradeChatMessage","HandleResponse","SetProfessionAdvertised","SetAvailabilityMode"}) do
    if type(AF[method])=="function" and hooksecurefunc then
        hooksecurefunc(AF,method,function() A.UpdateWorld() end)
    end
end

