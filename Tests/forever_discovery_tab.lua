local function frame()
 local f={shown=true,width=750,height=594,points={{"CENTER"}},scripts={},strata="MEDIUM",level=1,movable=true}
 function f:SetPoint(...) self.points[#self.points+1]={...} end
 function f:ClearAllPoints() self.points={} end
 function f:GetPoint(index) return unpack(self.points[index]) end
 function f:GetNumPoints() return #self.points end
 function f:SetMovable(value) self.movable=value end
 function f:IsMovable() return self.movable end
 function f:StopMovingOrSizing() self.moving=false end
 function f:SetScale(scale) self.scale=scale end
 function f:GetScale() return self.scale or 1 end
 function f:SetSize(w,h) self.width=w self.height=h end
 function f:SetHeight(h)self.height=h end
 function f:GetWidth() return self.width end function f:GetHeight() return self.height end
 function f:SetParent(parent) self.parent=parent end function f:GetParent() return self.parent end
 function f:SetFrameStrata(value) self.strata=value end function f:GetFrameStrata() return self.strata end
 function f:SetFrameLevel(value) self.level=value end function f:GetFrameLevel() return self.level end
 function f:Show() self.shown=true end
 function f:Hide() local shown=self.shown self.shown=false if shown and self.scripts.OnHide then self.scripts.OnHide() end end
 function f:IsShown() return self.shown end function f:SetShown(value) if value then self:Show() else self:Hide() end end
 function f:SetChecked(value) self.checked=value end function f:SetID(value) self.id=value end
 function f:HookScript(key,fn) local old=self.scripts[key] self.scripts[key]=function(...) if old then old(...) end fn(...) end end
 return f
end
UIParent=frame() SidePanelTabButtonMixin={}
CreateFrame=function(_,_,parent,template)
 assert(template=="LargeSideTabButtonTemplate")
 local f=frame() f.parent=parent f.Icon={SetTexture=function() end}
 function f:EnableMouse(enabled) self.mouseEnabled=enabled end
 function f:SetFillToInterior(value) self.fillToInterior=value end
 function f:SetCustomOnMouseUpHandler(handler) self.mouseUp=handler end
 function f:OnMouseUp(button,upInside) if self.mouseUp then self.mouseUp(self,button,upInside) end end
 return f
end
hooksecurefunc=function(object,key,fn) local old=object[key] object[key]=function(...) local result=old(...) fn(...) return result end end
ProfessionsFrame=frame()
ProfessionsFrame.TitleContainer={TitleText=frame()}
function ProfessionsFrame:GetTitleText() return self.TitleContainer.TitleText end
ProfessionsFrame.BookPage=frame() ProfessionsFrame.CraftingPage=frame()
ProfessionsFrame.BookPage:Hide()
ProfessionsFrame.ProfessionsOverviewTab=frame()
local first,last,hidden=frame(),frame(),frame() hidden:Hide()
ProfessionsFrame.rightProfessionTabs={first,last,hidden}
ProfessionsFrame.RefreshRightTabs=function() end
ProfessionsFrame.RightTabSelected=function(self,selected) self.selected=selected end
local AF={ADDON_NAME="ArtisanFinder",crafterDefaultsFrame=frame(),crafterDefaultsCollapseButton=frame()}
AF.customerFrame=frame() AF.customerFrame.parent=UIParent AF.customerFrame:SetSize(920,620) AF.customerFrame:SetScale(.9)
AF.AttachCustomerUI=function() end AF.AttachCrafterUI=function() end
AF.Text=function(_,key)return key end
AF.UpdateCrafterRightTabs=function(self,expanded) self.tabsExpanded=expanded end
AF.IsOwnProfessionWindowOpen=function() return true end
AF.RefreshCustomerResults=function(self) self.refreshed=true end
AF.SelectForeverDirectoryTab=function(self,kind)
 self.customerFrame.directoryTab=kind
 self.customerFrame:SetHeight(kind=="agreements" and 684 or 620)
 if self.directoryInProfessions then ProfessionsFrame:SetHeight(self.customerFrame:GetHeight()) end
 self:PositionForeverDiscoveryTab()
end
AF.OpenCustomerUI=function(self) self.customerFrame:Show() end AF.ToggleCustomerUI=AF.OpenCustomerUI
assert(loadfile("Features/Forever/DiscoveryTab.lua"))("ArtisanFinder",AF)
AF:EnsureForeverDiscoveryTab()
local tab=AF.foreverDiscoveryTab
assert(tab and tab.points[1][2]==last,"discovery tab follows the last visible profession, skipping hidden slots")
assert(tab.mouseEnabled,"native frame tab accepts mouse input")
local agreements=AF.foreverAgreementsTab
assert(agreements and agreements.points[1][2]==tab,"Agreements follows Discovery after all native profession tabs")
assert(tab.tooltipText=="ArtisanFinder - FOREVER_DISCOVERY_OPTIONS" and agreements.tooltipText=="ArtisanFinder - AGREEMENT_TAB","native tooltips name both ArtisanFinder views")
assert(agreements.notificationBadgeInsideTab,"crafting Agreements tab has its unread badge inside its top-right corner")
tab:OnMouseUp("RightButton",true)
assert(not AF.directoryInProfessions,"right click does not select discovery")
tab:OnMouseUp("LeftButton",false)
assert(not AF.directoryInProfessions,"releasing outside does not select discovery")
tab:OnMouseUp("LeftButton",true)
assert(AF.directoryInProfessions and tab.checked and AF.customerFrame.parent==ProfessionsFrame,"selecting discovery embeds the directory and selects the native tab")
assert(not AF.customerFrame:IsMovable(),"embedded directory cannot be dragged")
assert(not ProfessionsFrame:GetTitleText():IsShown(),"embedded discovery hides the native crafting title")
assert(ProfessionsFrame.width==920 and AF.customerFrame:GetScale()==1,"embedded view uses the new directory width without inheriting standalone scale")
assert(not ProfessionsFrame.BookPage.shown and not ProfessionsFrame.CraftingPage.shown and not AF.crafterDefaultsFrame.shown)
AF:UpdateCrafterRightTabs(true)
assert(not AF.tabsExpanded and tab.checked,"embedded discovery keeps tabs on the crafting window and stays selected")
assert(not AF:IsOwnProfessionWindowOpen(),"discovery never exposes own-recipe advertising controls")
agreements:OnMouseUp("RightButton",true)
assert(AF.customerFrame.directoryTab=="discovery","Agreements ignores right click")
agreements:OnMouseUp("LeftButton",true)
assert(AF.directoryInProfessions and AF.customerFrame.directoryTab=="agreements" and agreements.checked and not tab.checked,"crafting Agreements tab switches shared content and selection")
assert(not AF.customerFrame:IsMovable() and not ProfessionsFrame:GetTitleText():IsShown(),"Agreements keeps the crafting host locked and native title hidden")
assert(ProfessionsFrame:GetHeight()==684,"embedded host grows for agreement actions")
tab:OnMouseUp("LeftButton",true)
assert(AF.customerFrame.directoryTab=="discovery" and tab.checked and not agreements.checked and ProfessionsFrame:GetHeight()==620,"Discovery tab restores table height and native selected state")
ProfessionsFrame:RightTabSelected(first)
assert(not AF.directoryInProfessions and not tab.checked and AF.customerFrame.parent==UIParent and not AF.customerFrame.shown)
assert(ProfessionsFrame.width==750 and AF.customerFrame.width==920,"profession and standalone directory sizes restore")
assert(AF.customerFrame:IsMovable(),"standalone directory becomes draggable again")
agreements:OnMouseUp("LeftButton",true)
assert(AF.directoryInProfessions and AF.customerFrame.directoryTab=="agreements" and agreements.checked,"Agreements opens directly from a normal native profession view")
ProfessionsFrame:RightTabSelected(first)
assert(not AF.directoryInProfessions and not agreements.checked,"native profession selection detaches Agreements too")
assert(ProfessionsFrame:GetTitleText():IsShown(),"switching professions restores native title")
assert(AF.customerFrame:GetScale()==.9,"detaching restores standalone scaling")
tab:OnMouseUp("LeftButton",true) AF:OpenCustomerUI()
assert(not AF.directoryInProfessions and AF.customerFrame.parent==UIParent and AF.customerFrame.shown,"minimap/slash access returns to standalone discovery")
tab:OnMouseUp("LeftButton",true) ProfessionsFrame:Hide()
assert(not AF.directoryInProfessions and not tab.checked,"closing professions clears discovery selection")
assert(AF.customerFrame:IsMovable() and ProfessionsFrame:GetTitleText():IsShown(),"closing professions restores drag and native title")
ProfessionsFrame:GetTitleText():Hide()
AF.customerFrame:SetMovable(false)
tab:OnMouseUp("LeftButton",true) AF:OpenCustomerUI()
assert(not ProfessionsFrame:GetTitleText():IsShown(),"detaching preserves an already hidden title")
assert(not AF.customerFrame:IsMovable(),"detaching preserves an already locked directory")
print("PASS native discovery side tab ordering, selection, embedded view, profession switching, standalone access and close cleanup")
