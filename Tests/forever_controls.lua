local AF={db={artisanProfile={featuredRecipes={["10"]=true}}},playerName="Tester"}
assert(loadfile("Flavors/Forever.lua"))("ArtisanFinder",AF)
local count,created=0,0
local allFrames={}
local function check(v,text) count=count+1 assert(v,text) end
local function frame()
 created=created+1
 local f={scripts={},hooks={},shown=true,mouse=false,width=300}
 allFrames[#allFrames+1]=f
 function f:SetSize(w) self.width=w end
 function f:SetPoint(...) self.point={...} end
 function f:SetHighlightTexture(texture)
  self.highlight=self.highlight or {ClearAllPoints=function() end,SetAllPoints=function() end,SetAlpha=function(self,value) self.alpha=value end}
  self.highlight.texture=texture
 end
 function f:GetHighlightTexture() return self.highlight end
 function f:SetMotionScriptsWhileDisabled() end
 function f:SetScript(name,fn) self.scripts[name]=fn end
 function f:HookScript(name,fn) self.hooks[name]=fn end
 function f:SetShown(v) self.shown=v==true end
 function f:Hide() self.shown=false end
 function f:IsShown() return self.shown end
 function f:IsMouseOver() return self.mouse end
 function f:SetAlpha(v) self.alpha=v end
 function f:GetWidth() return self.width end
 function f:SetWidth(v) self.width=v end
 function f:ClearAllPoints() end
 function f:SetHeight() end
 function f:SetAllPoints() end
 function f:SetFontObject() end
 function f:SetNormalTexture() end
 function f:SetJustifyH() end
 function f:GetFrameLevel() return 1 end
 function f:SetFrameLevel(v) self.level=v end
 function f:SetFrameStrata(v) self.strata=v end
 function f:GetNumPoints() return self.point and 1 or 0 end
 function f:GetPoint() return unpack(self.point) end
 function f:SetOnMinimizedCallback(fn) self.minimize=fn end
 function f:SetOnMaximizedCallback(fn) self.maximize=fn end
 function f:SetMinimizedLook() end
 function f:SetMaximizedLook() end
 function f:SetBackdrop() end
 function f:SetBackdropColor() end
 function f:EnableMouse() end
 function f:SetAutoFocus() end
 function f:SetMaxLetters() end
 function f:SetEnabled(v) self.enabled=v end
 function f:Enable() self.enabled=true end
 function f:Disable() self.enabled=false end
 function f:SetChecked(v) self.checked=v end
 function f:ClearFocus() end
 function f:SetText(v) self.text=v end
 function f:GetText() return self.text or "" end
 function f:Click() self.scripts.OnClick(self) end
 function f:CreateFontString() local label=frame() function label:SetJustifyH() end function label:SetJustifyV() end function label:SetWordWrap() end function label:SetMaxLines() end return label end
 function f:GetStringWidth() return 0 end
 function f:CreateTexture()
  return {SetAllPoints=function() end,SetBlendMode=function() end,SetAlpha=function(self,v) self.alpha=v end,SetPoint=function() end,SetTexture=function(self,v) self.texture=v end,
   SetDesaturated=function(self,v) self.grey=v end,SetAtlas=function() end,SetHeight=function() end,SetSize=function() end,SetColorTexture=function() end,SetRotation=function() end,SetShown=function() end,Hide=function() end,SetVertexColor=function() end}
 end
 return f
end
CreateFrame=function(_,_,parent,template)
 local f=frame() f.parent=parent f.template=template
 if template=="UICheckButtonTemplate" then f.Text=frame() end
 if template=="DefaultPanelTemplate" then f.TitleContainer=frame() f.TitleContainer.TitleText=frame() f.Bg=f:CreateTexture() f.TopTileStreaks=f:CreateTexture() end
 if template=="MaximizeMinimizeButtonFrameTemplate" then f.MaximizeButton=frame() f.MinimizeButton=frame() end
 return f
end
NineSliceUtil={ApplyLayoutByName=function() end}

local combat,external=false,false
local learned={[10]=true,[11]=true,[12]=false}
InCombatLockdown=function() return combat end
C_TradeSkillUI={GetRecipeInfo=function(id) return {recipeID=id,learned=learned[id]} end}
AF.IsOwnProfessionWindowOpen=function() return not external end
AF.GetCurrentSupportedProfessionID=function() return 164 end
local advertised=false
AF.IsProfessionAdvertised=function() return advertised end
AF.SetProfessionAdvertised=function(_,name,id,value) advertised=value end
AF.RefreshCrafterUI=function() AF:RefreshForeverRecipeControls() end
GameTooltip_Hide=function() end
local page,form,box=frame(),frame(),frame()
local selection={recipeID=10}
form.FavoriteButton=frame()
form.GetRecipeInfo=function() return selection end
page.SchematicForm=form page.LinkButton=frame() page.RecipeList={ScrollBox=box}
local row=frame()
row.Label=frame() row.SkillUps=frame() row.SkillUps.width=20 row.Count=frame()
local node={data={recipeInfo={recipeID=10,learned=true}}}
box.ForEachFrame=function(_,fn) fn(row,node) end
box.RegisterCallback=function(self,_,fn,owner) self.initializer=function(r,n) fn(owner,r,n) end end
ScrollBoxListMixin={Event={OnInitializedFrame="initialized"}}
EventRegistry={callbacks={},RegisterCallback=function(self,event,fn,owner) self.callbacks[event]=function(...) fn(owner,...) end end}
ProfessionsFrame={CraftingPage=page}
ProfessionsFrame.ProfessionsOverviewTab=frame()
ProfessionsFrame.ProfessionsOverviewTab:SetPoint("TOPLEFT",ProfessionsFrame,"TOPRIGHT",0,-60)
ProfessionsFrame.rightProfessionTabs={frame()}
ProfessionsFrame.rightProfessionTabs[1]:SetPoint("TOPLEFT",ProfessionsFrame.ProfessionsOverviewTab,"BOTTOMLEFT",0,-2)
AF.crafterDefaultsFrame=frame()
assert(loadfile("Features/Forever/RecipeControls.lua"))("ArtisanFinderForever",AF)
AF:RefreshForeverRecipeControls()
local feature,advertise
for _,f in ipairs(allFrames) do
 if f.parent==form then feature=f end
 if f.parent==page then advertise=f end
end
check(AF.db.artisanProfile.featuredRecipes["10"],"disabled feature preserves saved selections")
check(not feature and not row.artisanFinderFeaturedButton,"featured controls are disabled on form and recipe rows")
check(not box.initializer and not EventRegistry.callbacks["Professions.RecipeListOnEnter"],"disabled feature installs no recipe-list callbacks")
check(advertise and advertise.point[2]==page.LinkButton,"trumpet stays beside link")
check(advertise.Icon.texture==table.concat({"Interface","AddOns","ArtisanFinderForever","Assets","Forever","Advertising.tga"},string.char(92)),"advertising texture uses native path separators")
local tooltipTitle,tooltipHelp
AF.Text=function(_,key) return "localized:"..key end
GameTooltip={SetOwner=function() end,SetText=function(_,text) tooltipTitle=text end,
    AddLine=function(_,text) tooltipHelp=text end,Show=function() end}
advertise.scripts.OnEnter(advertise)
check(tooltipTitle=="localized:FOREVER_ADVERTISE_PROFESSION" and tooltipHelp=="localized:FOREVER_ADVERTISE_PROFESSION_HELP",
    "advertising title and help use locale messages")
check(advertise.highlight.texture.texture:find("Advertising.tga",1,true),"advertising uses shaped highlight")
check(advertise.highlight.texture.alpha==0.2,"advertising hover brightens subtly")
advertise:Click() check(advertised,"advertising enabled by trumpet")
advertise:Click() check(not advertised,"advertising disabled by trumpet")
external=true AF:RefreshForeverRecipeControls()
check(not advertise.shown,"linked professions cannot change advertising")
external=false combat=true AF:RefreshForeverRecipeControls()
check(not advertise.shown,"combat hides advertising control")
check(ProfessionsFrame.ProfessionsOverviewTab.point[2]==ProfessionsFrame,"native tab anchors remain untouched")
print("PASS "..count.." Forever advertising and disabled featured-control assertions")
