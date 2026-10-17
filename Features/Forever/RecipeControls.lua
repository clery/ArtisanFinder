local addonName, AF = ...
local controls
local art="Interface\\AddOns\\"..addonName.."\\Assets\\Forever\\"

local function NewIcon(parent,size,name,title,description,action)
    local button=CreateFrame("Button",nil,parent)
    button:SetSize(size,size)
    button.Icon=button:CreateTexture(nil,"ARTWORK")
    button.Icon:SetAllPoints()
    button.Icon:SetTexture(art..name..".tga")
    local glow=button:CreateTexture(nil,"HIGHLIGHT")
    glow:SetAllPoints(button.Icon)
    glow:SetTexture(art..name..".tga")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.2)
    button:SetHighlightTexture(glow)
    button:SetScript("OnClick",action)
    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText(AF:Text(title),1,0.82,0)
        if description then GameTooltip:AddLine(AF:Text(description),1,1,1,true) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",GameTooltip_Hide)
    return button
end
-- Featured recipe data is retained in saved profiles, but no controls or
-- recipe-list hooks are installed while the feature is disabled.
function AF:RefreshForeverRecipeControls()
    local page=ProfessionsFrame and ProfessionsFrame.CraftingPage
    if not self.db or not self.db.artisanProfile or not page or not page.LinkButton then return end
    if not controls then
        controls=NewIcon(page,24,"Advertising","FOREVER_ADVERTISE_PROFESSION","FOREVER_ADVERTISE_PROFESSION_HELP",function()
            local id=AF:GetCurrentSupportedProfessionID()
            if id and AF:IsOwnProfessionWindowOpen() and not InCombatLockdown() then
                AF:SetProfessionAdvertised(AF.playerName,id,not AF:IsProfessionAdvertised(AF.playerName,id))
                AF:RefreshCrafterUI()
            end
        end)
        controls:SetPoint("LEFT",page.LinkButton,"RIGHT",4,0)
    end
    local own=self:IsOwnProfessionWindowOpen() and not InCombatLockdown()
    controls:SetShown(own)
    if own then controls.Icon:SetDesaturated(not self:IsProfessionAdvertised(self.playerName,self:GetCurrentSupportedProfessionID())) end
end
