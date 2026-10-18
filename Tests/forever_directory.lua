local AF = { db = {customerCache={[100]={}},artisanProfile={professions={}},tradeLeadMinutes=15,defaultSort="best"}, playerName="Buyer-Realm", CACHE_MAX_AGE=1209600, LIVE_QUERY_TIMEOUT=5 }
assert(loadfile("Flavors/Forever.lua"))("ArtisanFinder",AF)
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
local function check(value,message) assert(value,message) end
AF.GetProfessionName=function(_,id) return tostring(id) end
AF.Now=function() return 1000 end
AF.NormalizeName=function(_,name) return name end
AF.GetPlayerFullName=function() return "Buyer-Realm" end
AF.IsAvailable=function() return false end
AF.IsFavoriteArtisan=function(_,e) return e.name=="Favorite-Realm" end
AF.GetDisplayItemName=function(_,id) return id==100 and "Mithril Sword" or "Enchant Boots" end
AF.CustomerEntryMatchesFilter=function(_,e,f) return (e.name or ""):lower():find(f,1,true) or (e.professionID==164 and f=="blacksmithing") end
AF.ForEachArtisanProfile=function(_,callback) callback("Alt-Realm",{items={[100]={},[-200]={}}}) end
local entry={name="Favorite-Realm",professionID=164,itemID=100,note="Bring materials",updatedAt=990}
AF.GetCachedArtisans=function(_,id) return id==100 and {entry,entry} or {{name="Enchanter-Realm",professionID=333,itemID=-200,updatedAt=980}} end
AF.Text=function(_,key) return key end
AF.tradeLeads={one={name="Trader-Realm",professionCandidates={[165]=true},updatedAt=990},old={name="Expired-Realm",professionCandidates={[171]=true},updatedAt=1}}
load("Core/Bootstrap.lua")
load("Features/Forever/GuildDirectory.lua") load("Features/Forever/DiscoverySources.lua") load("Features/Forever/Directory.lua")
local rows=AF:GetDirectoryEntries("")
check(#rows==3,"directory deduplicates recipe buckets, includes active trade, excludes stale trade")
check(rows[1].name=="Favorite-Realm","favorites sort first")
check(#AF:GetDirectoryEntries("mithril")==1,"item name search")
check(#AF:GetDirectoryEntries("blacksmithing")==1,"profession search")
check(#AF:GetDirectoryEntries("enchanter")==1,"artisan name search")
check(entry.directoryItemName==nil,"directory copies cache entries")
check(AF:GetForeverNameplateObservation("Expired-Realm")==nil,"expired observations rejected")
check(AF:GetForeverNameplateObservation("Trader-Realm").source=="TRADE","trade provenance retained")
AF.db.customerCache[100].verified={name="Trader-Realm",professionID=164,verifiedAt=995}
check(AF:GetForeverNameplateObservation("Trader-Realm").source=="ADDON","verified addon observation preferred")
AF.db.customerCache[100].verified.verifiedAt=600
check(AF:GetForeverNameplateObservation("Trader-Realm").source=="TRADE","stale addon falls back to trade")
AF.db.customerCache[100].verified.verifiedAt=995
AF.db.customerCache[100].verified.offline=true
check(AF:GetForeverNameplateObservation("Trader-Realm").source=="TRADE","offline addon never shown as currently advertising")

-- Exercise the actual standalone UI and pooled rows with no order frames/APIs.
C_CraftingOrders=nil ProfessionsCustomerOrdersFrame=nil
local created=0
local function object()
 local o={shown=true,width=680,height=400,text="",scripts={}}
 local methods={
  SetSize=function(s,w,h)s.width=w s.height=h end,GetWidth=function(s)return s.width end,GetHeight=function(s)return s.height end,
  SetPoint=function(s,...)s.point={...}end,SetWidth=function(s,w)s.width=w end,
  SetText=function(s,t)s.text=t end,GetText=function(s)return s.text end,
  SetTextColor=function(s,...)s.color={...} end,SetJustifyH=function(s,value)s.justifyH=value end,SetVertexColor=function(s,...)s.vertexColor={...} end,SetRotation=function(s,value)s.rotation=value end,
  SetScript=function(s,k,v)s.scripts[k]=v end,
  GetScript=function(s,k)return s.scripts[k] end,
  HookScript=function(s,key,fn)
   local previous=s.scripts[key]
   s.scripts[key]=function(...) if previous then previous(...) end fn(...) end
  end,
  IsMouseOver=function(s)return s.mouseOver==true end,
  SetFrameLevel=function(s,v)s.level=v end,GetFrameLevel=function(s)return rawget(s,"level") or 0 end,
  EnableMouse=function(s,v)s.mouseEnabled=v end,Show=function(s)s.shown=true end,Hide=function(s)s.shown=false end,
  SetShown=function(s,v)s.shown=v end,IsShown=function(s)return s.shown end,
  CreateTexture=function()return object()end,CreateFontString=function()return object()end,
  GetNormalTexture=function(s)s.normal=rawget(s,"normal") or object() return s.normal end,
  GetHighlightTexture=function(s)s.highlight=rawget(s,"highlight") or object() return s.highlight end,
  SetEnabled=function(s,v)s.enabled=v end,
 }
 setmetatable(o,{__index=function(_,k)return methods[k] or function()end end})
 return o
end
UIParent=object() UISpecialFrames={}
CreateFrame=function(_,name,parent,template)
 created=created+1
 local o=object() o.parent=parent
 if template=="BasicFrameTemplateWithInset" then o.TitleText=object() end
 if template=="ScrollFrameTemplate" then o.ScrollBar=object() end
 if template=="SearchBoxTemplate" then
  o.searchIcon=object() o.clearButton=object() o.Instructions=object()
  o.scripts.OnTextChanged=function(box) box.clearButton:SetShown(box:GetText()~="") end
  o.clearButton.scripts.OnClick=function() o:SetText("") o.scripts.OnTextChanged(o) end
 end
 if name then _G[name]=o end
 return o
end
GameTooltip=object() GameTooltip.AddLine=function()end
C_Timer={After=function()end}
AF.GetProfessionName=function(_,id)return tostring(id) end
AF.GetProfessionIconMarkup=function()return ""end
AF.GetRememberedProfessionLink=function()return nil end
AF.GetDisplayPlayerName=function(_,name)return name end
AF.BuildCustomerRowViewModel=function(_,e)return e end
AF.ApplyCustomerRowViewModel=function()return 72 end
AF.BroadcastQuery=function(_,id)AF.queried=id end
AF.RefreshCustomerEntryWhoStatus=function()end
AF.ToggleFavoriteArtisan=function()end
AF.DebugLog=function()end
local stubs={} for key,value in pairs(AF) do stubs[key]=value end
load("Utils/Formatting.lua")
for key,value in pairs(stubs) do AF[key]=value end
AF.GetProfessionPriceEntry=function() return nil end
load("Features/Forever/Pricing.lua")
load("Features/Forever/Hierarchy.lua")
load("Features/Forever/Sorting.lua")
load("Features/Customer/ProfessionOpening.lua")
load("Features/Forever/DirectoryUI.lua")
AF:InitializeCustomerUI()
check(not AF.customerFrame:IsShown(),"standalone directory starts hidden")
AF:OpenCustomerUI()
check(AF.customerFrame:IsShown(),"directory opens independently of professions/order UI")
check(AF.customerFrame.previous.point[1]=="CENTER" and AF.customerFrame.previous.point[2]==AF.customerFrame.footer and AF.customerFrame.previous.point[5]==0,"pagination arrows centered vertically in fixed footer")
check(AF.customerFrame.previous.point[4]==-180 and AF.customerFrame.next.point[4]==180,"pagination reserves fixed space for large page counts")
check(AF.customerFrame.scroll.point[4]==nil and AF.customerFrame.scroll.point[2]==-34,"table uses full width with only frame and scrollbar gutters")
check(AF.customerFrame.scroll.ScrollBar.point[2]==AF.customerFrame and AF.customerFrame.scroll.ScrollBar.point[4]==-12,"scrollbar stays inside the panel")
check(#AF:GetVisibleCustomerEntries()==3,"standalone UI renders known artisans")
check(AF.customerFrame.header.parent==AF.customerFrame,"search and headers stay outside scrolling content")
check(AF.customerFrame.scroll.ScrollBar.scripts.OnEnter==nil,"scrollbar has no row hover hooks")
check(AF.customerRows[1].point[3]==0,"first row starts immediately below the pinned header")
check(AF.customerRows[1].price.justifyH=="RIGHT","commissions align on the right edge of their column")
AF.customerFrame.scroll:SetSize(874,456)
AF:RefreshCustomerResults()
check(AF.customerRows[1].name:GetWidth()>200,"full names receive more width while retaining six profession icons")
check(AF.customerRows[1].updatedAt:GetWidth()>80,"last observed retains room beside fixed hover controls")
local pinnedHeader=AF.customerFrame.header.point
AF.customerFrame.scroll:SetVerticalScroll(250)
check(AF.customerFrame.header.point==pinnedHeader,"scrolling expanded crafts leaves header anchors unchanged")
local visualRow=AF.customerRows[1]
visualRow.star.scripts.OnEnter(visualRow.star)
check(visualRow.star.art.vertexColor[1]==1,"hover brightens the icon itself")
visualRow.star.scripts.OnLeave(visualRow.star)
check(visualRow.star.art.vertexColor[1]<1,"leaving restores restrained icon brightness")
AF.directorySource="TRADE" AF:RefreshCustomerResults()
check(AF.customerFrame.sourceValue.color[1]==1,"active source filter uses gold text")
AF.directorySource=nil AF:RefreshCustomerResults()
check(AF.customerFrame.sourceValue.color[1]<1,"clearing source filter restores muted text")
print("PASS pinned discovery headers, wider names, price alignment, icon brightness and active filters")
local allocated=created
AF:RefreshCustomerResults()
check(created==allocated,"refresh reuses rows")
AF.customerFrame.search:SetText("blacksmithing") AF:RefreshCustomerResults()
check(#AF:GetVisibleCustomerEntries()==2,"text filtering includes matching cached discovery history")
AF.customerFrame.search:SetText("")
AF:SelectCustomerItem("|Hitem:100:0|h[Mithril Sword]|h")
check(AF.queried==100,"item links start live addon query")
AF:SelectCustomerItem("Mithril Sword")
check(AF.currentCustomerItemID==100,"known item name resolves to live query")
AF:SelectCustomerItem("missing item")
check(AF.currentCustomerItemID==100,"failed item lookup preserves active query")
GetCursorInfo=function() return "item",100,"|Hitem:100:0|h[Mithril Sword]|h" end
ClearCursor=function() end
AF.customerFrame.item.scripts.OnReceiveDrag(AF.customerFrame.item)
check(AF.currentCustomerItemID==100,"dragging an item selects its exact ID")
local queued={}
C_Timer.After=function(delay,callback) queued[#queued+1]={delay=delay,callback=callback} end
AF:SelectCustomerItem(101)
check(#queued==1 and AF.queried==100,"switching items during cooldown queues the new query")
AF.Now=function() return 1005 end
queued[1].callback()
check(AF.queried==101,"queued item lookup is eventually sent")
AF:SelectCustomerItem(100)
AF:SelectCustomerItem(nil)
queued[#queued].callback()
check(AF.queried==101,"clearing item selection cancels a queued stale query")
check(AF.currentCustomerItemID==nil,"all-artisans clears recipe context")
AF.customerFrame.search:SetText("") AF:RefreshCustomerResults()
AF:ToggleCustomerUI()
check(not AF.customerFrame:IsShown(),"minimap/slash can close directory")
print("PASS Forever directory aggregation, filters, provenance, expiry, standalone UI and row reuse; no orders APIs")

local missing={name="Mixed Crafter",professionID=333}
local linked={name="Mixed Crafter",professionID=333,professionLink="|Htrade:Player-1:7413:333|h[Enchanting]|h"}
local other={name="Mixed Crafter",professionID=165,professionLink="|Htrade:Player-1:2108:165|h[Leatherworking]|h"}
local options=AF:GetOpenableForeverProfessions({entry=missing,offers={missing,linked,other,linked}})
assert(#options==2 and options[1]==other and options[2]==linked,"group uses linked offers even when representative has no link")
AF.professionOpenFailures={[AF:GetProfessionOpenFailureKey(linked)]=true}
assert(AF:CanReliablyOpenProfession(linked),"previous failure must allow a user retry")
assert(#AF:GetOpenableForeverProfessions({entry=missing,offers={missing}})==0,"unavailable links stay disabled")
print("PASS grouped profession-link selection, deduplication and retry after failure")

-- Hidden discovery must not aggregate or rebuild results on guild events.
local savedRows=AF.GetForeverDirectoryRows
AF.GetForeverDirectoryRows=function() error("hidden discovery rebuilt its results") end
AF:RefreshCustomerResults()
AF.GetForeverDirectoryRows=savedRows
AF.customerFrame:Show()

-- Moving from a row onto a child must not hide the clickable action strip.
local deferred={}
C_Timer.After=function(_,fn) deferred[#deferred+1]=fn end
local row=AF.customerRows[1]
row.mouseOver=true row.scripts.OnEnter(row)
assert(row.actions:IsShown() and row.updatedAt:IsShown(),"last observed stays visible beside hover actions")
row.mouseOver=false row.scripts.OnLeave(row)
row.action.mouseOver=true row.action.scripts.OnEnter(row.action)
for _,fn in ipairs(deferred) do fn() end deferred={}
assert(row.actions:IsShown(),"parent leave must not hide hovered child controls")
assert(row.actions.mouseEnabled==false and row.action:GetFrameLevel()>row.actions:GetFrameLevel(),"container cannot steal clicks")
AF:RefreshCustomerResults()
assert(row.actions:IsShown(),"incoming results must preserve action strip beneath cursor")
row.action.mouseOver=false row.action.scripts.OnLeave(row.action)
for _,fn in ipairs(deferred) do fn() end
assert(not row.actions:IsShown() and row.updatedAt:IsShown(),"actions hide only after leaving row and controls")
print("PASS directory child hover handoff, click layering and hover preservation during refresh")

-- Row clicks expand rather than whisper; the explicit action still whispers.
AF.directoryExpandedArtisans={} AF.directoryExpandedProfessions={}
AF:RefreshCustomerResults()
local artisan=AF.customerRows[1]
local name=artisan.group.name
local whispers=0 ChatFrame_SendTell=function() whispers=whispers+1 end
artisan.scripts.OnClick(artisan)
assert(AF.directoryExpandedArtisans[name] and whispers==0,"artisan click expands without whispering")
local job=AF.customerRows[2]
assert(job.view.kind=="profession" and not job.star:IsShown(),"profession subrow follows its artisan")
job.scripts.OnEnter(job)
job.scripts.OnClick(job)
assert(AF.directoryExpandedProfessions[job.view.key],"profession click expands known crafts")
assert(AF.customerFrame.content:GetHeight()>=AF.customerFrame.scroll:GetHeight(),"expanded list remains scrollable")
print("PASS real directory row clicks render expandable artisan/job rows without sending whispers")

assert(AF.customerFrame.item==AF.customerFrame.search,"only one physical search field remains")
assert(rawget(AF.customerFrame,"searchIcon")==nil and rawget(AF.customerFrame,"refresh")==nil,"old artisan search icon and manual refresh removed")
AF.directoryExpandedArtisans={} AF.directoryExpandedProfessions={}
AF.currentCustomerItemID=100
AF.customerFrame.search:SetText("Trader")
AF.customerFrame.search.scripts.OnTextChanged(AF.customerFrame.search)
assert(AF.currentCustomerItemID==nil,"typing a new filter clears the previous item context")
assert(#AF:GetVisibleCustomerEntries()==1 and AF.customerRows[1].group.name=="Trader-Realm","unified field filters artisan names")
AF.GetProfessionName=function(_,id) return id==165 and "Leatherworking" or tostring(id) end
AF.customerFrame.search:SetText("leatherworking") AF.customerFrame.search.scripts.OnTextChanged(AF.customerFrame.search)
assert(#AF:GetVisibleCustomerEntries()==1 and AF.customerRows[1].group.name=="Trader-Realm","unified field filters localized profession names")
AF.customerFrame.search:SetText("Mithril Sword") AF.customerFrame.search.scripts.OnTextChanged(AF.customerFrame.search)
assert(#AF:GetVisibleCustomerEntries()>0,"known item names filter locally without requiring Enter")
AF.customerFrame.search:SetText("Favorite-Realm") AF.customerFrame.search.scripts.OnTextChanged(AF.customerFrame.search)
AF.customerFrame.search.scripts.OnEnterPressed(AF.customerFrame.search)
assert(AF.currentCustomerItemID==nil,"artisan text is not treated as a failed item search")
print("PASS unified artisan/profession/item search, stale item reset, exact-item/drag support and refresh removal")

UnitIsPlayer=function(unit) return unit=="target" end
AF.GetForeverUnitFullName=function() return "Trader-Realm" end
AF.directoryProfession=164 AF.directorySource="ADDON" AF.currentCustomerItemID=100
AF:ToggleCustomerUI()
assert(AF.customerFrame:IsShown() and AF.customerFrame.search:GetText()=="Trader-Realm")
assert(AF.directoryTargetName=="Trader-Realm" and AF.directoryExpandedArtisans["Trader-Realm"],"target is exact-filtered and expanded")
assert(AF.directoryProfession==nil and AF.directorySource==nil and AF.currentCustomerItemID==nil,"old filters cannot hide target")
assert(AF.customerRows[1].view.kind=="artisan" and AF.customerRows[1].group.name=="Trader-Realm")
assert(AF.customerRows[2].view.kind=="profession","target professions are revealed")
AF:ToggleCustomerUI()
assert(AF.customerFrame:IsShown(),"clicking with a known target focuses instead of closing")
AF.customerFrame.search:SetText("") AF.customerFrame.search.scripts.OnTextChanged(AF.customerFrame.search)
assert(AF.directoryTargetName==nil,"editing clears exact-target restriction")
UnitIsPlayer=function() return false end
AF:ToggleCustomerUI()
assert(not AF.customerFrame:IsShown(),"without a player target the button still toggles")
print("PASS targeted artisan button focus, exact full-name search, expansion and filter reset")

AF.customerFrame:Show()
local headers=AF.customerFrame.sortHeaders
headers[3].scripts.OnClick(headers[3])
assert(AF.db.foreverDirectorySort.key=="price" and not AF.db.foreverDirectorySort.descending)
assert(headers[3].arrow:IsShown() and not headers[1].arrow:IsShown(),"only sorted column shows arrow")
assert(headers[3].heading.color[1]>headers[1].heading.color[1],"sorted heading has distinct brighter color")
local rotation=headers[3].arrow.rotation
headers[3].scripts.OnClick(headers[3])
assert(AF.db.foreverDirectorySort.descending and headers[3].arrow.rotation==-rotation,"header click reverses arrow")
print("PASS clickable sort headers, active color and directional arrow")

C_Item={GetItemInfo=function(id) return "Mithril Sword","|cff1eff00|Hitem:"..id.."|h[Mithril Sword]|h|r" end,
    GetItemIconByID=function() return 123456 end}
AF.IsSecretValue=function() return false end
AF.directoryTargetName=nil AF.customerFrame.search:SetText("")
AF.directoryExpandedArtisans={["Trader-Realm"]=true}
AF.directoryExpandedProfessions={["Trader-Realm:165"]=true}
AF.db.customerCache[100].craft={name="Trader-Realm",professionID=165,itemID=100,recipeID=2100,updatedAt=995}
AF:RefreshCustomerResults()
local craftRow
for _,candidate in ipairs(AF.customerRows) do if candidate:IsShown() and candidate.view.kind=="craft" then craftRow=candidate break end end
assert(craftRow and craftRow.itemIcon:IsShown() and craftRow.itemLink:IsShown())
local trackedEntry
AF.TrackForeverCraftMaterials=function(_,entry) trackedEntry=entry end
assert(craftRow.track:IsShown(),"craft rows expose the track-materials icon")
craftRow.track.scripts.OnClick(craftRow.track)
assert(trackedEntry==craftRow.entry,"track button uses the clicked craft, independently of current search")
assert(craftRow.name:GetText():find("|Hitem:100",1,true),"craft names render real item links")
local tooltipPayload
GameTooltip.SetHyperlink=function(_,payload) tooltipPayload=payload end
craftRow.itemLink.scripts.OnEnter(craftRow.itemLink)
assert(tooltipPayload=="item:100","name hover opens native item tooltip")
local clicked
SetItemRef=function(payload) clicked=payload end
craftRow.itemLink.scripts.OnClick(craftRow.itemLink)
assert(clicked=="item:100","item name behaves as a clickable chat-style link")
AF.directoryExpandedArtisans={} AF:RefreshCustomerResults()
assert(not AF.customerRows[1].itemIcon:IsShown() and not AF.customerRows[1].itemLink:IsShown() and not AF.customerRows[1].track:IsShown(),"pooled artisan rows hide item-only controls")
print("PASS craft item icons, colored links, native hover tooltips, click behavior and recycled row cleanup")

assert(rawget(AF.customerFrame,"lookup")==nil and rawget(AF.customerFrame,"all")==nil,"external search and clear controls removed")
local search=AF.customerFrame.search
assert(search.searchIcon and search.clearButton and search.Instructions,"uses native search-box children")
search:SetText("Trader") search.scripts.OnTextChanged(search)
assert(search.clearButton:IsShown(),"native template text-change behavior retained alongside filtering")
AF.directoryTargetName="Trader-Realm" AF.currentCustomerItemID=100
search.clearButton.scripts.OnClick(search.clearButton)
assert(search:GetText()=="" and AF.directoryTargetName==nil and AF.currentCustomerItemID==nil,"embedded clear resets text and all search context")
assert(not search.clearButton:IsShown(),"embedded clear disappears when empty")
print("PASS native crafting-style search box, embedded icons, inherited behavior and clear/search integration")

local previousMenu,previousSelect=MenuUtil,AF.SelectCustomerItem
local choices={}
MenuUtil={CreateContextMenu=function(owner,build)
    build(owner,{CreateTitle=function() end,CreateButton=function(_,label,action)
        local choice={label=label,action=action}
        choices[#choices+1]=choice
        return {SetTooltip=function(_,fn) choice.tooltip=fn end}
    end})
end}
AF.SelectCustomerItem=function() return nil,{{itemID=2000,name="Matching Sword"},{itemID=2001,name="Matching Shield"}} end
AF.customerFrame.search.scripts.OnEnterPressed(AF.customerFrame.search)
assert(#choices==2 and choices[1].label:find("|Hitem:2000|h",1,true),"ambiguous item results display item links")
assert(not choices[1].label:find("(2000)",1,true),"item results omit raw IDs")
local hovered
choices[2].tooltip({SetHyperlink=function(_,payload) hovered=payload end})
assert(hovered=="item:2001","hovering a search choice shows its native item tooltip")
MenuUtil,AF.SelectCustomerItem=previousMenu,previousSelect
print("PASS Enter search item choices use hoverable item links without raw IDs")

AF.directoryExpandedArtisans={} AF.directoryExpandedProfessions={}
AF:RefreshCustomerResults()
local artisanRow=AF.customerRows[1]
local professionButton=artisanRow.professionButtons[1]
assert(professionButton and professionButton:IsShown(),"profession icons have individual click targets")
local artisanName,professionID=artisanRow.group.name,professionButton.professionID
professionButton.scripts.OnClick(professionButton)
assert(AF.directoryExpandedArtisans[artisanName] and AF.directoryExpandedProfessions[artisanName..":"..professionID],"icon expands artisan and matching profession")
print("PASS profession icon clicks expand artisan and selected profession")

for _,row in ipairs(AF.customerRows) do
    if row:IsShown() and row.view.kind~="artisan" then
        assert(row.source:GetText()=="" and row.updatedAt:GetText()=="" and not row.updatedAt:IsShown(),"child rows omit discovery source and last observed")
        row.scripts.OnEnter(row)
        assert(not row.updatedAt:IsShown(),"hover cannot restore child timestamps")
    end
end
print("PASS discovery source and last observed appear only on artisan rows")

local originalBuild=AF.BuildForeverExpandedRows
local many={} for key,value in pairs(artisanRow.group) do many[key]=value end
many.professions={[164]=true,[165]=true,[171]=true,[185]=true,[197]=true,[202]=true,[333]=true}
local normalGroup=artisanRow.group
AF.BuildForeverExpandedRows=function() return {{kind="artisan",group=many},{kind="artisan",group=normalGroup}} end
AF:RefreshCustomerResults()
local tall,normal=AF.customerRows[1],AF.customerRows[2]
assert(tall:GetHeight()==normal:GetHeight()*2,"more than six professions doubles row height")
assert(tall.professionButtons[7].point[4]==tall.professionButtons[1].point[4] and tall.professionButtons[7].point[5]<tall.professionButtons[1].point[5],"seventh icon wraps beneath first")
assert(normal.point[3]==tall.point[3]-tall:GetHeight(),"following row starts below the taller row")
AF.BuildForeverExpandedRows=originalBuild
print("PASS six-icon profession wrapping, double-height rows and cumulative row positions")

local parentName=normalGroup.name
local altEntry={} for key,value in pairs(normalGroup.entry) do altEntry[key]=value end
altEntry.orderTarget="Alt Crafter"
local job={name=parentName,entry=altEntry,offers={altEntry},professions={[164]=true},updatedAt=990,source="ADDON"}
AF.BuildForeverExpandedRows=function() return {{kind="profession",group=job,professionID=164}} end
AF:RefreshCustomerResults()
local professionRow=AF.customerRows[1]
assert(professionRow.professions:GetText()=="(Alt Crafter)","profession column identifies an alt by its full name")
for _,button in ipairs(professionRow.professionButtons) do assert(not button:IsShown(),"profession rows have no profession icons") end
altEntry.orderTarget=parentName
AF:RefreshCustomerResults()
assert(professionRow.professions:GetText()=="","same character does not repeat its name")
AF.BuildForeverExpandedRows=originalBuild
print("PASS profession rows replace icons with alt character name only when different from artisan")

assert(AF.customerRows[1].itemLink:GetFrameLevel()<AF.customerRows[1].track:GetFrameLevel(),"item-name hit area cannot cover action icons")
local content=AF.customerFrame.content
local originalSetSize=content.SetSize
local sizes={}
content.SetSize=function(self,width,height) sizes[#sizes+1]=height originalSetSize(self,width,height) end
AF:RefreshCustomerResults()
assert(#sizes==1,"refresh sets final scroll height once, avoiding temporary scroll clamping")
content.SetSize=originalSetSize
print("PASS action hit areas stay above item links and refresh avoids shrinking scroll content")

assert(not AF.customerRows[1].whoRefresh:IsShown() and AF.customerRows[1].whoRefresh.enabled==false,"refresh control remains implemented but hidden and disabled")

local recycled=AF.customerRows[1]
recycled.hovered=true recycled.entry=nil
AF:RefreshCustomerResults()
assert(recycled.entry and recycled.view,"reusing a previously hovered row with cleared entry does not crash")
for _,row in ipairs(AF.customerRows) do
    if not row:IsShown() then
        assert(row.hovered==false and rawget(row,"entry")==nil and rawget(row,"view")==nil,"hidden rows clear hover and identity together")
    end
end
print("PASS filter refresh safely reuses hovered rows after their entry was cleared")

for _,row in ipairs(AF.customerRows) do
    if row:IsShown() then
        assert(row.link:IsShown()==(#AF:GetOpenableForeverProfessions(row.group)>0),"profession link is shown only when a usable link exists")
    end
end

-- Background bursts rebuild once; UI actions still use immediate rendering.
AF.customerFrame:Show()
local scheduled={}
C_Timer.After=function(delay,callback) scheduled[#scheduled+1]={delay=delay,callback=callback} end
AF.directoryRefreshQueued=nil
AF.directoryLastRefreshAt=AF:Now()
local originalRefresh=AF.RefreshCustomerResults
local rebuilds=0
AF.RefreshCustomerResults=function() rebuilds=rebuilds+1 end
for index=1,1000 do AF:QueueCustomerResultsRefresh() end
assert(#scheduled==1 and scheduled[1].delay>=5 and rebuilds==0,"event bursts cannot rebuild discovery every second")
scheduled[1].callback()
assert(rebuilds==1 and not AF.directoryRefreshQueued,"batched rebuild runs once and releases queue")
AF.customerFrame:Hide()
AF:QueueCustomerResultsRefresh()
assert(#scheduled==1,"hidden discovery schedules no rebuild")
AF.RefreshCustomerResults=originalRefresh
local originalCached=AF.GetCachedArtisans
AF.GetOwnAltRows=function() return {} end
AF.GetCachedArtisans=function() error("directory render invoked item query pipeline") end
AF:GetDirectoryEntries("")
AF.GetCachedArtisans=originalCached
AF.GetOwnAltRows=nil
print("PASS discovery batches 1000 background events and avoids item-query side effects during general listing")
