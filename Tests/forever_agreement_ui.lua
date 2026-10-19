local AF={db={},playerName="Customer Last",MAX_COMMISSION_COPPER=999999990000}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
load("Locales/enUS.lua") load("Locales/Forever/enUS.lua")
function AF:Text(key,...) local value=self.Locales.enUS[key] or key return select("#",...)>0 and string.format(value,...) or value end
local function widget(parent)
    local w={shown=true,scripts={},text="",enabled=true,parent=parent,children={},level=parent and parent:GetFrameLevel()+1 or 0}
    if parent then parent.children[#parent.children+1]=w end
    function w:SetPoint(...) self.point={...} self.points=self.points or {} self.points[#self.points+1]={...} end
    function w:ClearAllPoints() self.point=nil end
    function w:SetSize(width,height) self.width=width self.height=height end
    function w:SetWidth(width) self.width=width end
    function w:SetHeight(height) self.height=height end
    function w:GetWidth() return self.width end
    function w:GetHeight() return self.height end
    function w:SetScale(scale) self.scale=scale end
    function w:GetFrameLevel() return self.level end
    function w:SetFrameLevel(level)
        local delta=level-self.level self.level=level
        for _,child in ipairs(self.children) do child:SetFrameLevel(child:GetFrameLevel()+delta) end
    end
    function w:SetFrameStrata(value) self.strata=value end
    function w:GetFrameStrata() return self.strata or self.parent and self.parent:GetFrameStrata() or "MEDIUM" end
    function w:SetToplevel(value) self.toplevel=value end
    function w:Raise() self.raises=(self.raises or 0)+1 end
    function w:EnableMouse(value) self.mouse=value end
    function w:SetScript(key,fn) self.scripts[key]=fn end
    function w:HookScript(key,fn)
        local previous=self.scripts[key]
        self.scripts[key]=function(...) if previous then previous(...) end fn(...) end
    end
    function w:GetScrollChild() return self.scrollChild end
    function w:SetScrollChild(child) self.scrollChild=child end
    function w:SetText(value) self.text=value if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
    function w:GetText() return self.text end
    function w:GetFont() return "font",12,"" end
    function w:SetFont(path,size,flags) self.fontSize=size end
    function w:GetFontString() return self end
    function w:SetEnabled(value) self.enabled=value end
    function w:SetAlpha(value) self.alpha=value end
    function w:SetTexture(value) self.texture=value end
    function w:SetAtlas(value) self.atlas=value end
    function w:SetVertexColor(...) self.color={...} end
    function w:SetTextColor(...) self.textColor={...} end
    function w:IsShown() return self.shown end
    function w:Show() local was=self.shown self.shown=true if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
    function w:Hide() self.shown=false end
    function w:SetShown(value) self.shown=value end
    function w:CreateAnimationGroup()
        local group={plays=0,stops=0}
        function group:Play() self.plays=self.plays+1 end
        function group:Stop() self.stops=self.stops+1 end
        function group:CreateAnimation()
            local animation={}
            for _,method in ipairs({"SetScaleFrom","SetScaleTo","SetDuration","SetSmoothing","SetFromAlpha","SetToAlpha"}) do
                animation[method]=function() end
            end
            return animation
        end
        return group
    end
    function w:CreateTexture() return widget() end
    function w:CreateFontString(_,_,template) local font=widget() font.fontTemplate=template return font end
    for _,method in ipairs({"SetAllPoints","SetColorTexture","SetShadowColor","SetJustifyH","SetJustifyV",
        "SetWordWrap","SetAutoFocus","SetMaxLetters","SetNumeric","SetTextInsets","SetFontObject","ClearFocus",
        "SetClampedToScreen","SetMovable","EnableMouseWheel","RegisterForDrag","SetBackdrop","SetBackdropBorderColor",
        "StartMoving","StopMovingOrSizing","SetPortraitToAsset","RegisterEvent"}) do w[method]=function() end end
    return w
end
UIParent=widget() UIParent:SetSize(1920,1080) UISpecialFrames={}
CreateFrame=function(_,_,parent,template)
    local w=widget(parent) w.template=template
    if template=="SmallItemButtonTemplate" then
        w.Icon=widget() w.Icon:SetSize(30,30) w.Icon:SetPoint("TOPLEFT")
        w.NameFrame=widget() w.NameFrame:SetAtlas("QuestItemBorder") w.NameFrame:SetPoint("LEFT",w.Icon,"RIGHT",2,0)
        w.Name=widget() w.Name:SetSize(92,36) w.Name:SetPoint("LEFT",w.NameFrame,"LEFT",4,0)
    end
    if template=="UIPanelScrollFrameTemplate" then
        w.ScrollBar=widget(w)
        w.ScrollBar.value=0
    end
    w.TitleContainer={TitleText=widget()} w.PortraitContainer={portrait=widget()} return w
end
-- Emulate the inherited Blizzard range handler: hideable bars follow overflow,
-- and their value is clamped when content shrinks or the viewport grows.
ScrollFrame_OnScrollRangeChanged=function(scroll,_,range)
    scroll.ScrollBar:SetShown(not scroll.scrollBarHideable or range>0)
    scroll.ScrollBar.value=math.min(scroll.ScrollBar.value,range)
    scroll.verticalScroll=scroll.ScrollBar.value
end
GameTooltip=widget()
GameTooltip.SetOwner=function() end GameTooltip.SetHyperlink=function(self,value) self.link=value end
GameTooltip.AddLine=function() end
local notices=0
UIErrorsFrame={AddMessage=function() notices=notices+1 end}
local restricted=false
InCombatLockdown=function() return restricted end IsInInstance=function() return false end
GetRealmName=function() return "Mega" end
local support=false
AF.HasAgreementSupport=function() return support end AF.ProbeAgreementSupport=function() end
local records={} local ignored={}
AF.GetAgreements=function(_,direction)
    local result={}
    for _,r in pairs(records) do
        if (direction=="incoming" and r.localRole=="artisan") or (direction=="outgoing" and r.localRole=="customer") then result[#result+1]=r end
    end
    table.sort(result,function(a,b) return a.id<b.id end) return result
end
AF.GetAgreement=function(_,id) return records[id] end
AF.GetAgreementStore=function() return {records=records,ignored=ignored} end
AF.MarkAgreementRead=function(_,id) records[id].unread=false end
AF.IgnoreAgreementPeer=function(_,peer) ignored[peer]=true end AF.UnignoreAgreementPeer=function(_,peer) ignored[peer]=nil end
AF.FormatMoney=function(_,amount) return tostring(amount) end AF.GetDisplayItemName=function(_,id) assert(id>0) return "Item "..id end
AF.Now=function() return 100 end AF.NormalizeName=function(_,name) return name end
local itemLookups={}
C_Item={GetItemCount=function(id) itemLookups[#itemLookups+1]=id return 3 end,GetItemInfo=function(id) assert(id>0) return "Item "..id end,
    GetItemIconByID=function(id) assert(id>0) return "icon"..id end}
C_Texture={GetAtlasInfo=function(atlas) return atlas=="QuestBG-Parchment" and {} end}
C_Spell={GetSpellTexture=function(id) return "spell"..id end}
C_TradeSkillUI={GetRecipeSchematic=function() return {quantityMin=2,quantityMax=3,reagentSlotSchematics={
    {required=true,quantityRequired=4,reagents={{itemID=10}}},{required=true,quantityRequired=2,reagents={{itemID=20}}}}} end}
AF.RefreshPreparationTracker=function() end
load("UI/Minimap.lua")
load("Features/Forever/PreparationTracker.lua") load("Features/Forever/AgreementPreparation.lua") load("Features/Forever/AgreementUI.lua")
local quantity={quantity=2,recipeID=1,itemID=-1,itemName="Enchant",professionID=333,artisan="Contact Last",craftingCharacter="Crafter Alt",id="A",status="Accepted"}
local materials,output=AF:GetAgreementMaterials(quantity)
assert(materials[1].quantity==8 and materials[1].missing==5 and materials[2].quantity==4 and output.minimum==4 and output.maximum==6)
assert(#itemLookups==2 and itemLookups[1]>0 and itemLookups[2]>0,"negative enchant identity never goes to item APIs")
local prepared=AF:TrackAgreementMaterials(quantity)
assert(prepared.key=="agreement:Mega:Customer Last:A" and prepared.itemID==nil and prepared.reagents[1].quantity==8)
AF:TrackAgreementMaterials(quantity) assert(#AF.db.preparedCrafts==1,"same agreement replaces its own tracking only")
quantity.id="B" AF:TrackAgreementMaterials(quantity) assert(#AF.db.preparedCrafts==2)
quantity.status="Pending" assert(not AF:TrackAgreementMaterials(quantity))
local total,err=AF:GetAgreementEditorTotal(50,3) assert(total==150 and not err)
assert(AF:GetAgreementEditorTotal(nil,2)==nil and AF:GetAgreementEditorTotal(0,2)==0)
local _,overflow=AF:GetAgreementEditorTotal(AF.MAX_COMMISSION_COPPER,2) assert(overflow=="PRICE_ERROR")
local _,invalid=AF:GetAgreementEditorTotal(10,0) assert(invalid=="QUANTITY_ERROR")
AF.customerFrame=widget(UIParent)
AF.customerFrame:SetFrameStrata("HIGH") AF.customerFrame:SetFrameLevel(100)
AF.customerFrame.agreements=widget(AF.customerFrame)
AF.CreateAgreementDraft=function(_,input)
    local r={} for k,v in pairs(input) do r[k]=v end
    r.id="draft" r.localRole="customer" r.customer=AF.playerName r.status="Pending" r.delivery="draft" r.stateRevision=0 r.updatedAt=100
    records[r.id]=r return r
end
AF.SendAgreement=function(_,id) return false,"unsupported" end
local frame=AF:OpenAgreementEditor({artisan="Contact Last",craftingCharacter="Crafter Alt",recipeID=1,itemID=-1,professionID=333,itemName="Enchant",unitCommission=50})
local function checkActionLayout()
    assert(frame.height==756,"agreement page keeps its full height in every state")
    local visible={}
    for action,button in pairs(frame.actions) do
        assert(button.template=="UIPanelButtonTemplate" and button.text~="" and not button.art,"labeled native action: "..action)
        assert(not button.text:find("AGREEMENT_",1,true),"translated button label")
        if button:IsShown() then
            local x,y=button.point[2],-button.point[3]
            assert(x>=350 and x+button.width<=808 and y>=558 and y+button.height<=-frame.notice.point[3]-8,"actions stay below materials and above warning")
            visible[#visible+1]={x=x,y=y,width=button.width,height=button.height}
        end
    end
    for i,a in ipairs(visible) do for j,b in ipairs(visible) do if j>i then
        assert(a.x+a.width<=b.x or b.x+b.width<=a.x or a.y+a.height<=b.y or b.y+b.height<=a.y,"buttons do not overlap")
    end end end
    assert(-frame.notice.point[3]+30<=frame.height-8,"warning has its own bottom space")
    assert(frame.height*frame.scale<=UIParent:GetHeight()-24 and 840*frame.scale<=UIParent:GetWidth()-24,"all controls fit smaller screens")
    for _,button in ipairs({frame.ignored}) do
        assert(button.template=="UIPanelButtonTemplate" and button.text~="" and not button.art,"ignored list toggle stays labeled")
    end
end
checkActionLayout()
assert(frame.paper.atlas=="QuestBG-Parchment","use full parchment atlas without legacy texture padding")
assert(frame.paper.points[1][1]=="TOPLEFT" and frame.paper.points[2][1]=="BOTTOMRIGHT")
assert(frame.paper.backing.points[1][1]=="TOPLEFT" and frame.paper.backing.points[2][1]=="BOTTOMRIGHT","opaque backing fills entire resizable page")
assert(not frame.rows[1].tab and not frame.rows[1].paper and not frame.rows[1].edge,"simple list has no overlapping folder parts")
assert(frame.rows[1].item.textColor[1]>.8,"list uses light readable text")
assert(frame.stamp.point[1]=="BOTTOMRIGHT" and frame.stamp.mouse==false and not frame.stamp:IsShown())
local function checkLayering()
    assert(frame:GetFrameStrata()=="DIALOG" and frame:GetFrameLevel()>AF.customerFrame:GetFrameLevel(),"request window above discovery")
    assert(frame.toplevel and frame.mouse and frame.raises>0,"native top-level window raises and catches background clicks")
    for _,control in ipairs({frame.detail,frame.detail.quantity,frame.detail.money[1],frame.detail.item,frame.actions.SEND,frame.rows[1]}) do
        assert(control:GetFrameStrata()=="DIALOG" and control:GetFrameLevel()>frame:GetFrameLevel(),"controls inherit front window layer")
    end
end
checkLayering()
-- Reopening an already visible editor must still raise it, including embedded discovery.
ProfessionsFrame=widget(UIParent) ProfessionsFrame:SetFrameLevel(300)
AF.customerFrame.parent=ProfessionsFrame AF.customerFrame:SetFrameStrata("MEDIUM") AF.customerFrame:SetFrameLevel(305)
local raised=frame.raises
AF:OpenAgreementEditor({artisan="Contact Last",recipeID=1,unitCommission=50})
assert(frame.raises>raised) checkLayering()
frame:Hide() AF:ShowAgreements("incoming") checkLayering()
AF:OpenAgreementEditor({artisan="Contact Last",craftingCharacter="Crafter Alt",recipeID=1,itemID=-1,professionID=333,itemName="Enchant",unitCommission=50})
assert(frame and frame:IsShown() and frame.detail.contact.text:find("Contact Last") and frame.detail.crafter.text:find("Crafter Alt"))
frame.detail.quantity:SetText("3") frame.detail.quantity.scripts.OnTextChanged(frame.detail.quantity,true)
assert(frame.detail.money[3]:GetText()=="50" and frame.detail.money[2]:GetText()=="1","quantity multiplies default unit price")
-- Unsent requests survive real tab callbacks, empty views and reopening.
frame.detail.money[1]:SetText("2") frame.detail.money[2]:SetText("34") frame.detail.money[3]:SetText("56")
frame.detail.money[1].scripts.OnTextChanged(frame.detail.money[1],true)
frame.detail.message:SetText("Keep this request")
frame.notice:SetText("Old validation warning")
frame.incoming.scripts.OnClick()
assert(frame.notice.text=="" and not frame.detail:IsShown() and not next(records),"switch clears stale warnings without saving or sending a draft")
AF:RefreshAgreementUI()
frame.outgoing.scripts.OnClick()
assert(frame.editorInput.artisan=="Contact Last" and frame.editorInput.craftingCharacter=="Crafter Alt" and frame.editorInput.recipeID==1)
assert(frame.detail.quantity:GetText()=="3" and frame.detail.money[1]:GetText()=="2" and frame.detail.money[2]:GetText()=="34" and frame.detail.money[3]:GetText()=="56")
assert(frame.detail.message:GetText()=="Keep this request" and frame.detail.priceEdited,"all unsent form values restored")
frame:Hide() AF:ShowAgreements("outgoing")
assert(frame.detail.message:GetText()=="Keep this request" and frame.editorInput,"reopening retains local request")
-- Explicit toast navigation selects the request without discarding an outgoing editor.
local toastRecord={id="toast-record",localRole="artisan",customer="Visitor Name",artisan=AF.playerName,
    recipeID=1,itemID=2,professionID=333,itemName="Item",quantity=1,status="Pending",stateRevision=1,updatedAt=100,unread=true}
records[toastRecord.id]=toastRecord
AF:OpenAgreementNotification(toastRecord)
assert(frame.direction=="incoming" and frame.selectedID==toastRecord.id and not toastRecord.unread)
frame.outgoing.scripts.OnClick()
assert(frame.editorInput and frame.detail.message:GetText()=="Keep this request")
assert(frame.detail.quantity:GetText()=="3" and frame.detail.money[1]:GetText()=="2" and frame.detail.money[2]:GetText()=="34" and frame.detail.money[3]:GetText()=="56")
records[toastRecord.id]=nil
-- Reset the price before the original submission assertions.
frame.detail.money[1]:SetText("0") frame.detail.money[2]:SetText("1") frame.detail.money[3]:SetText("50")
AF:AgreementUIAction("SEND")
assert(records.draft.quantity==3 and records.draft.commission==150 and records.draft.delivery=="draft")
assert(frame.notice.text==AF:Text("AGREEMENT_UNSUPPORTED"),"unsupported peer retains explicit unsent draft")
local r={id="incoming",localRole="artisan",customer="Customer Other",artisan="Customer Last",craftingCharacter="Customer Last",
    recipeID=1,itemID=2,professionID=333,itemName="Item 2",quantity=1,commission=40,message="Original",status="Pending",stateRevision=1,updatedAt=100,unread=true}
records[r.id]=r
AF:ShowAgreements("incoming") frame.rows[1].scripts.OnClick()
UIParent:SetSize(1024,600) AF:RefreshAgreementUI()
checkActionLayout()
local fixedScale=frame.scale
for _,state in ipairs({"Draft","Pending","Counteroffered","Accepted","Completed","Declined","Cancelled","Expired"}) do
    r.status=state r.snapshotDelivery={failed=true}
    AF:RefreshAgreementUI() checkActionLayout()
    assert(frame.scale==fixedScale,"state and delivery updates never rescale the page")
end
assert(r.completionStampSeen and frame.stamp.animation.plays==1,"stamp animation keeps page dimensions")
r.status="Pending" r.snapshotDelivery=nil r.completionStampSeen=nil
frame.selectedID=nil AF:RefreshAgreementUI()
assert(not frame.detail:IsShown() and frame.height==756 and frame.scale==fixedScale,"empty selection keeps page dimensions")
frame.selectedID=r.id AF:RefreshAgreementUI()
assert(frame.scale<1,"larger action footer fits low-height display")
UIParent:SetSize(1920,1080) AF:RefreshAgreementUI()
assert(frame.scale==1)
assert(not r.unread and frame.actions.ACCEPT:IsShown() and frame.actions.COUNTER:IsShown())
assert(frame.detail.contact.text:find("Customer Other"),"incoming contact is customer rather than self")
frame.detail.money[3]:SetText("99") frame.detail.message:SetText("My counter")
AF:RefreshAgreementUI()
assert(frame.detail.money[3]:GetText()=="99" and frame.detail.message:GetText()=="My counter","background refresh preserves unsent counter")
frame.notice:SetText("Old counter warning")
frame.outgoing.scripts.OnClick()
assert(frame.selectedID=="draft" and frame.notice.text=="","each tab restores its own selection and clears old warning")
assert(frame.detail.message:GetText()=="Keep this request","incoming counter does not overwrite outgoing message")
frame.incoming.scripts.OnClick()
assert(frame.selectedID==r.id and frame.detail.money[3]:GetText()=="99" and frame.detail.message:GetText()=="My counter","counteroffer survives switching tabs")
-- A different record has an independent edit buffer.
local other={} for key,value in pairs(r) do other[key]=value end
other.id="incoming2" other.message="Other request" other.commission=23 records[other.id]=other
AF:RefreshAgreementUI() frame.rows[2].scripts.OnClick()
assert(frame.notice.text=="" and frame.detail.message:GetText()=="Other request")
frame.detail.message:SetText("Other counter")
frame.rows[1].scripts.OnClick()
assert(frame.detail.message:GetText()=="My counter" and frame.detail.money[3]:GetText()=="99")
frame.rows[2].scripts.OnClick() assert(frame.detail.message:GetText()=="Other counter")
frame.rows[1].scripts.OnClick() records[other.id]=nil
r.stateRevision=2 r.commission=80 r.message="New terms" AF:RefreshAgreementUI()
assert(frame.detail.money[3]:GetText()=="80" and frame.detail.message:GetText()=="New terms","committed terms replace stale editor")
r.pendingAction={} r.delivery="pending" AF:RefreshAgreementUI()
assert(not frame.actions.ACCEPT:IsShown() and not frame.actions.COMPLETE:IsShown() and not frame.actions.RETRY:IsShown())
r.localRole="customer" r.pendingAction.command={action="submit"} AF:RefreshAgreementUI()
assert(frame.actions.CANCEL:IsShown(),"queued request can be cancelled before delivery")
r.pendingAction.command.action="cancel" AF:RefreshAgreementUI()
assert(not frame.actions.CANCEL:IsShown(),"pending cancellation cannot be submitted twice")
r.localRole="artisan"
r.delivery="failed" AF:RefreshAgreementUI() assert(frame.actions.RETRY:IsShown())
assert(AF:GetAgreementDisplayStatus(r)==AF:Text("AGREEMENT_DELIVERY_FAILED"))
r.pendingAction=nil r.delivery="delivered" r.status="Counteroffered" AF:RefreshAgreementUI()
assert(frame.actions.DECLINE:IsShown() and frame.actions.COUNTER:IsShown(),"artisan can decline their outstanding counteroffer")
r.status="Accepted" r.completion={customer=false,artisan=false} AF:RefreshAgreementUI()
checkActionLayout()
assert(frame.actions.COMPLETE.text==AF:Text("AGREEMENT_BUTTON_COMPLETE"))
r.completion.customer=true AF:RefreshAgreementUI()
assert(frame.actions.COMPLETE.text==AF:Text("AGREEMENT_BUTTON_CONFIRM"))
assert(AF:GetAgreementDisplayStatus(r)==AF:Text("AGREEMENT_AWAITING_CONFIRMATION") and frame.actions.COMPLETE:IsShown())
r.completion.artisan=true AF:RefreshAgreementUI() assert(not frame.actions.COMPLETE:IsShown())
r.status="Completed" AF:RefreshAgreementUI() assert(frame.actions.DELETE:IsShown() and not frame.actions.CANCEL:IsShown())
local queued=0
AF.QueueAgreementNotification=function() queued=queued+1 end
frame:Hide() r.unread=true local initial=notices
restricted=true AF:OnAgreementChanged(r,true) assert(not frame:IsShown() and notices==initial)
restricted=false AF:OnAgreementChanged(r,true) assert(not frame:IsShown() and notices==initial and queued==2 and AF.customerFrame.agreements.artisanFinderNotificationBadge.text.text=="1")
assert(AF:GetAgreementUnreadCount()==1)
-- A missing schematic can use locally cached reagent details without transmitting them.
C_TradeSkillUI.GetRecipeSchematic=function() return nil end
AF.GetForeverKnownCrafts=function() return {{recipeID=1,itemID=-1,professionID=333,reagents={{itemID=30,quantity=5}}}} end
local fallback=AF:GetAgreementMaterials(r) assert(fallback[1].quantity==5)
print("PASS Forever agreement UI, commission editor, local materials and quiet notifications")

-- Drive real UI callbacks against two actual models through recorded whisper frames.
local queue,clients={},{}
local bob={playerName="Artisan Last",db={},MAX_COMMISSION_COPPER=AF.MAX_COMMISSION_COPPER,
    Locales=AF.Locales,Text=AF.Text,Now=AF.Now,NormalizeName=AF.NormalizeName,
    FormatMoney=AF.FormatMoney,GetDisplayItemName=AF.GetDisplayItemName,
    CreatePreparedCraftEntry=AF.CreatePreparedCraftEntry,RefreshPreparationTracker=function() end}
for _,addon in ipairs({AF,bob}) do
    assert(loadfile("Features/Forever/Agreements.lua"))("ArtisanFinder",addon)
    assert(loadfile("Features/Forever/AgreementComms.lua"))("ArtisanFinder",addon)
    addon:InitializeAgreements()
    addon.SendPayloadParts=function(self,parts,channel,target)
        assert(channel=="WHISPER")
        queue[#queue+1]={payload=table.concat(parts,"|"),sender=self.playerName,target=target}
        return true
    end
    clients[addon.playerName]=addon
end
assert(loadfile("Features/Forever/AgreementPreparation.lua"))("ArtisanFinder",bob)
assert(loadfile("Features/Forever/AgreementUI.lua"))("ArtisanFinder",bob)
local function flush()
    local iterations=0
    while #queue>0 do
        iterations=iterations+1 assert(iterations<1000)
        local message=table.remove(queue,1)
        clients[message.target]:OnAgreementMessage(message.payload,"WHISPER",message.sender)
    end
end
local moneyChecks=0
GetMoney=function() moneyChecks=moneyChecks+1 return 0 end
C_Item.GetItemCount=function() return 0 end
AF:OpenAgreementEditor({artisan=bob.playerName,craftingCharacter="Artisan Alt",recipeID=1,
    itemID=2,professionID=333,itemName="Item 2",unitCommission=50})
flush()
local missing=AF:GetAgreementMaterials(AF.agreementsFrame.editorInput)
assert(missing and missing[1].owned==0 and missing[1].missing>0)
AF.agreementsFrame.actions.SEND.scripts.OnClick()
flush()
local actual=AF:GetAgreements("outgoing")[1]
assert(actual and actual.delivery=="delivered" and actual.artisan==bob.playerName)
bob:ShowAgreements("incoming")
bob.agreementsFrame.rows[1].scripts.OnClick()
bob.agreementsFrame.detail.money[3]:SetText("75")
bob.agreementsFrame.detail.message:SetText("Bring materials")
bob.agreementsFrame.actions.COUNTER.scripts.OnClick()
flush()
assert(actual.status=="Counteroffered" and actual.commission==75)
AF.agreementsFrame.actions.ACCEPT.scripts.OnClick()
flush()
assert(actual.status=="Accepted" and bob:GetAgreement(actual.id).status=="Accepted")
AF.agreementsFrame.actions.COMPLETE.scripts.OnClick()
flush()
assert(actual.status=="Accepted" and actual.completion.customer and not actual.completion.artisan)
assert(not AF.agreementsFrame.stamp:IsShown() and not bob.agreementsFrame.stamp:IsShown(),"one completion signature does not stamp")
local customerStamp,artisanStamp=AF.agreementsFrame.stamp,bob.agreementsFrame.stamp
local customerPlays,artisanPlays=customerStamp.animation.plays,artisanStamp.animation.plays
bob.agreementsFrame.actions.COMPLETE.scripts.OnClick()
flush()
assert(actual.status=="Completed" and bob:GetAgreement(actual.id).status=="Completed")
assert(customerStamp:IsShown() and artisanStamp:IsShown(),"both completed copies receive stamp")
assert(customerStamp.animation.plays==customerPlays+1 and artisanStamp.animation.plays==artisanPlays+1,"live mutual confirmation animates once on both clients")
AF:OnAgreementChanged(actual,true) AF:RefreshAgreementUI()
AF.agreementsFrame:Hide() AF:ShowAgreements("outgoing")
AF.agreementsFrame.rows[1].scripts.OnClick()
assert(customerStamp:IsShown() and customerStamp.animation.plays==customerPlays+1,"updates, reopening and reselecting completed page never replay stamp")
assert(AF.agreementsFrame.height==756,"completed page uses the same height with stamp space reserved")
assert(customerStamp.point[4]==-30 and customerStamp.point[5]==26)
-- Saved marker survives UI recreation / reload, without entering a wire snapshot.
local existing=bob.agreementsFrame bob.agreementsFrame=nil
bob:ShowAgreements("incoming") bob.agreementsFrame.rows[1].scripts.OnClick()
assert(bob.agreementsFrame.stamp:IsShown() and bob.agreementsFrame.stamp.animation.plays==0,"saved viewed agreement is static after UI recreation")
assert(actual.completionStampSeen and bob:GetAgreement(actual.id).completionStampSeen)
assert(AF:AgreementSnapshot(actual).completionStampSeen==nil,"animation marker never enters shared wire terms")
-- An unseen historical completed record animates only on its first visible display.
local historical=bob:GetAgreement(actual.id)
historical.completionStampSeen=nil
bob.agreementsFrame:Hide() bob:OnAgreementChanged(historical,true)
assert(not historical.completionStampSeen,"hidden updates do not consume first-open animation")
bob:ShowAgreements("incoming")
assert(historical.completionStampSeen and bob.agreementsFrame.stamp.animation.plays==1,"first visible historical opening animates")
bob.agreementsFrame:Hide() bob:ShowAgreements("incoming") bob.agreementsFrame.rows[1].scripts.OnClick()
assert(bob.agreementsFrame.stamp.animation.plays==1,"historical reopen stays static")
bob.agreementsFrame=existing
print("PASS full parchment anchors, simple list rows, mutual completion / first-open stamp, persistent static reopening")
print("PASS real customer/artisan UI callbacks synchronize counteroffers, acceptance and mutual completion through private frames")

-- A balance of zero and entirely missing materials never gate submission.
assert(actual.commission==75 and moneyChecks==0,"agreement flow never checks the customer's money")
for _,zeroPrice in ipairs({true,false}) do
    AF:OpenAgreementEditor({artisan=bob.playerName,craftingCharacter="Artisan Alt",recipeID=1,
        itemID=2,professionID=333,itemName="Item 2",unitCommission=zeroPrice and 0 or nil})
    local panel=AF.agreementsFrame.detail
    assert(panel.money[1]:GetText()==(zeroPrice and "0" or ""))
    AF.agreementsFrame.actions.SEND.scripts.OnClick()
    local sent=AF:GetAgreement(AF.agreementsFrame.selectedID)
    flush()
    assert(sent.delivery=="delivered" and bob:GetAgreement(sent.id),"zero balance and missing materials allow delivery")
    assert((zeroPrice and sent.commission==0) or (not zeroPrice and sent.commission==nil),"free remains distinct from unspecified commission")
end
assert(moneyChecks==0)
-- A known local restriction must not look like a successful queued send.
AF:OpenAgreementEditor({artisan=bob.playerName,recipeID=1,itemID=2,professionID=333,itemName="Item 2"})
AF.IsAddonCommsUnavailable=function() return true end
AF.agreementsFrame.actions.SEND.scripts.OnClick()
local blocked=AF:GetAgreement(AF.agreementsFrame.selectedID)
assert(blocked.delivery=="draft" and not blocked.pendingAction,"restricted send leaves an explicitly unsent draft")
assert(AF.agreementsFrame.notice.text==AF:Text("AGREEMENT_RESTRICTED"))
AF.IsAddonCommsUnavailable=nil
-- Unknown peer support remains explained after changing tabs and reopening.
AF:OpenAgreementEditor({artisan="Older Client",recipeID=1,itemID=2,professionID=333,itemName="Item 2"})
AF.agreementsFrame.actions.SEND.scripts.OnClick()
local unsupported=AF:GetAgreement(AF.agreementsFrame.selectedID)
assert(unsupported.delivery=="draft")
AF.agreementsFrame.incoming.scripts.OnClick() AF.agreementsFrame.outgoing.scripts.OnClick()
assert(AF.agreementsFrame.detail.info.text==AF:Text("AGREEMENT_UNSUPPORTED"))
-- Draft validation explains its failure without clearing the entered fields.
AF:OpenAgreementEditor({artisan=bob.playerName,recipeID=1,itemID=2,professionID=333,itemName="Item 2"})
AF.agreementsFrame.detail.message:SetText("|Hitem:2|h[Do not put links in notes]|h")
AF.agreementsFrame.actions.SEND.scripts.OnClick()
assert(AF.agreementsFrame.notice.text==AF:Text("AGREEMENT_INVALID_ERROR") and AF.agreementsFrame.editorInput)
assert(AF.agreementsFrame.detail.message:GetText():find("Do not put links",1,true))
print("PASS zero-balance missing-material submission, zero/unspecified prices, and explicit unsent failure reasons")

local remote={itemID=123,recipeID=456,itemName="Mithril Sword",itemLink="|cffffffff|Hitem:123:0:0|h[Mithril Sword]|h|r"}
local originalInfo=C_Item.GetItemInfo
C_Item.GetItemInfo=function(id) assert(id>0) return "Épée en mithril","|Hitem:"..id.."|h[Épée en mithril]|h" end
local localName,localLink=AF:GetAgreementCraftPresentation(remote)
assert(localName=="Épée en mithril" and localLink=="|cffffffff|Hitem:123:0:0|h[Épée en mithril]|h|r","agreement display localizes ID while preserving hyperlink payload")
assert(remote.itemName=="Mithril Sword" and remote.itemLink:find("[Mithril Sword]",1,true),"rendering cannot mutate shared agreement terms")
C_Item.GetItemInfo=function() return nil end
local fallbackName,fallbackLink=AF:GetAgreementCraftPresentation(remote)
assert(fallbackName==remote.itemName and fallbackLink==remote.itemLink,"unloaded IDs retain sender label temporarily")
C_Item.GetItemInfo=originalInfo
C_Spell.GetSpellName=function(id) assert(id==456) return "Enchantement de bottes" end
local enchant={itemID=-456,recipeID=456,itemName="Enchant Boots",itemLink="|Henchant:456|h[Enchant Boots]|h"}
local enchantName,enchantLink=AF:GetAgreementCraftPresentation(enchant)
assert(enchantName=="Enchantement de bottes" and enchantLink:find("[Enchantement de bottes]",1,true),"enchant agreement resolves recipe ID without querying negative item IDs")
print("PASS agreement cross-locale ID presentation, hyperlink preservation, unavailable data fallback and immutable terms")

-- Exchange and accept the same proposal while the two clients resolve different labels.
queue={}
AF.Now=function() return 200 end bob.Now=AF.Now
C_Spell.GetSpellName=nil
C_Item.GetItemInfo=function(id) return "Mithril Sword","|Hitem:"..id..":0|h[Mithril Sword]|h" end
AF:OpenAgreementEditor({artisan=bob.playerName,craftingCharacter="Artisan Alt",recipeID=456,
    itemID=123,professionID=164,itemName="Mithril Sword",itemLink="|Hitem:123:0|h[Mithril Sword]|h",unitCommission=0})
AF.agreementsFrame.actions.SEND.scripts.OnClick()
local englishRecord=AF:GetAgreement(AF.agreementsFrame.selectedID)
flush()
C_Item.GetItemInfo=function(id) return "Épée en mithril","|Hitem:"..id..":0|h[Épée en mithril]|h" end
local frenchRecord=bob:GetAgreement(englishRecord.id)
assert(frenchRecord and bob:GetAgreementCraftPresentation(frenchRecord)=="Épée en mithril")
assert(frenchRecord.itemName==englishRecord.itemName and frenchRecord.itemLink==englishRecord.itemLink,"local labels never rewrite proposal terms")
assert(bob:PerformAgreementAction(frenchRecord.id,"counter",{commission=10})) flush()
assert(AF:PerformAgreementAction(englishRecord.id,"accept")) flush()
assert(englishRecord.status=="Accepted" and frenchRecord.status=="Accepted" and englishRecord.proposalRevision==frenchRecord.proposalRevision,"cross-locale presentation does not break exact-revision acceptance")
C_Item.GetItemInfo=originalInfo
print("PASS English/French agreement clients exchange, counteroffer and accept shared numeric craft identity")

-- All entry points share unread counts, with mouse-transparent bounded badges.
local mini=widget(UIParent)
AF.minimapIcon={GetMinimapButton=function() return mini end}
AF.standaloneMinimapButton=widget(UIParent)
AF.foreverAgreementsTab=widget(UIParent) AF.foreverAgreementsTab.notificationBadgeInsideTab=true
AF.customerFrame.agreements.notificationBadgeInsideTab=true
local getUnreadCount=AF.GetAgreementUnreadCount
local unreadCount=0
AF.GetAgreementUnreadCount=function() return unreadCount end
for _,count in ipairs({0,1,9,10,150,0}) do
    unreadCount=count AF:RefreshAgreementUnreadIndicator()
    for _,button in ipairs({mini,AF.standaloneMinimapButton,AF.customerFrame.agreements,AF.foreverAgreementsTab}) do
        local badge=button.artisanFinderNotificationBadge
        assert(badge:IsShown()==(count>0))
        assert(badge.text.text==(count>9 and "9+" or tostring(count)))
        assert(badge.mouse==false and badge:GetFrameLevel()>button:GetFrameLevel())
        if button.notificationBadgeInsideTab then
            assert(badge.point[1]=="TOPRIGHT" and badge.point[2]==button and badge.point[3]=="TOPRIGHT" and badge.point[4]==-2 and badge.point[5]==-2,"tab badges sit inside the top-right corner")
        else assert(badge.point[1]=="TOPRIGHT","minimap badges keep their existing placement") end
        assert(badge.background.color[1]>badge.background.color[2])
        assert(badge.background:GetWidth()==(count>9 and 19 or 14) and badge.background:GetHeight()==14)
        assert(badge.background.point[1]=="CENTER")
        assert(badge:GetWidth()==(count>9 and 23 or 18) and badge:GetHeight()==18,"text retains its original unclipped layout")
        assert(badge.text.fontTemplate=="GameFontNormalSmall" and badge.text.fontSize==nil,"badge font remains unchanged")
        assert(badge.text.textColor[1]==1 and badge.text.textColor[2]==1 and badge.text.textColor[3]==1)
    end
end
print("PASS unread badges on minimap, standalone and discovery: 0/1/9/10/150, mouse passthrough")

AF.GetAgreementUnreadCount=getUnreadCount
for _,direction in ipairs({"incoming","outgoing"}) do
    for _,record in ipairs(AF:GetAgreements(direction)) do record.unread=false end
end
local unread=AF:GetAgreements("outgoing")[1]
assert(unread)
unread.unread=true AF:RefreshAgreementUnreadIndicator()
assert(mini.artisanFinderNotificationBadge.text.text=="1")
AF:MarkAgreementRead(unread.id)
assert(not mini.artisanFinderNotificationBadge:IsShown() and not AF.foreverAgreementsTab.artisanFinderNotificationBadge:IsShown())
print("PASS marking an agreement read immediately clears all unread entry badges")

assert(AF.agreementsFrame.detail.contact.fontSize==14 and AF.agreementsFrame.detail.message.fontSize==14)
assert(AF.agreementsFrame.detail.money[1].fontSize==16 and AF.agreementsFrame.actions.SEND.fontSize==14)

-- Every listed material and selected craft has a real locally resolved hyperlink.
local cachedInfo=C_Item.GetItemInfo
local getMaterials=AF.GetAgreementMaterials
AF.GetAgreementMaterials=function() return {{itemID=10,owned=0,quantity=2,missing=2},{itemID=20,owned=1,quantity=3,missing=2}},{minimum=1,maximum=1} end
C_Item.GetItemInfo=function(id) assert(id>0) return "Local reagent "..id,"|cffa335ee|Hitem:"..id..":0|h[Local reagent "..id.."]|h|r" end
local hoverFrame=AF:OpenAgreementEditor({artisan="Hover Contact",craftingCharacter="Hover Alt",recipeID=456,itemID=123,itemName="Remote label",unitCommission=0})
local editor=hoverFrame.detail
assert(editor.itemText.text=="Local reagent 123","native reward displays plain item name")
local beforeQuantity,beforeMessage=editor.quantity:GetText(),editor.message:GetText()
editor.item.scripts.OnEnter(editor.item)
assert(GameTooltip.link:find("|Hitem:123:",1,true))
editor.item.scripts.OnLeave(editor.item) assert(not GameTooltip:IsShown())
assert(editor.quantity:GetText()==beforeQuantity and editor.message:GetText()==beforeMessage and hoverFrame.editorInput,"hover does not submit or select another record")
local material=editor.materialRows[2]
assert(material.label.text=="Local reagent 10")
assert(not material.label.text:find("|c",1,true) and material.counts.text:find("0 / 2",1,true),"white reward name and separate quantities stay readable")
assert(material.border.color[1]==163/255 and material.border.color[3]==238/255,"rarity remains on reward icon border")
material.scripts.OnEnter(material) assert(GameTooltip.link:find("|Hitem:10:",1,true))
material.scripts.OnLeave(material) assert(not GameTooltip:IsShown())
assert(editor.materialRows[3].label.text=="Local reagent 20")
-- Missing item data stays hoverable, and repeated refreshes request it only once.
local requests=0
C_Item.GetItemInfo=function(id) assert(id>0) return nil end
C_Item.RequestLoadItemDataByID=function(id) assert(id>0) requests=requests+1 end
AF:OpenAgreementEditor({artisan="Hover Contact",recipeID=456,itemID=99123,itemName="Loading item"})
local requested=requests AF:RefreshAgreementUI() assert(requests==requested)
assert(editor.itemText.text=="Loading item")
editor.item.scripts.OnEnter(editor.item) assert(GameTooltip.link:find("|Hitem:99123",1,true))
editor.message:SetText("Unsaved local note") editor.money[1]:SetText("12")
C_Item.GetItemInfo=cachedInfo
hoverFrame.scripts.OnEvent(hoverFrame,"ITEM_DATA_LOAD_RESULT",99123,true)
assert(editor.message:GetText()=="Unsaved local note" and editor.money[1]:GetText()=="12","item data refresh retains unfinished form")
-- Enchant links always use a positive recipe identity, ignoring unrelated remote links.
AF:OpenAgreementEditor({artisan="Hover Contact",recipeID=456,itemID=-456,itemName="Enchant boots",itemLink="|Hitem:123|h[Wrong item]|h"})
assert(editor.itemText.text=="Enchant boots")
editor.item.scripts.OnEnter(editor.item) assert(GameTooltip.link:find("|Henchant:456",1,true))
editor.item.scripts.OnLeave(editor.item) assert(not GameTooltip:IsShown())
print("PASS craft and material hyperlinks: local labels, item and enchant hover, unavailable cache, immutable editor")

-- A long list is fully scrollable, and reused rows cannot retain previous links.
AF.GetAgreementMaterials=function()
    local rows={} for id=1,12 do rows[#rows+1]={itemID=id,owned=0,quantity=1,missing=1} end
    return rows
end
AF:RefreshAgreementMaterialsUI()
assert(#editor.materialRows==12 and editor.materialContent.height==408)
assert(editor.materialScroll.ScrollBar:IsShown(),"overflowing materials show scrollbar")
editor.materialScroll.ScrollBar.value=100
editor.materialScroll:SetHeight(500)
editor.materialScroll.scripts.OnSizeChanged(editor.materialScroll)
assert(not editor.materialScroll.ScrollBar:IsShown() and editor.materialScroll.verticalScroll==0,"viewport growth hides scrollbar and resets offset")
editor.materialScroll:SetHeight(130)
editor.materialScroll.scripts.OnSizeChanged(editor.materialScroll)
assert(editor.materialScroll.ScrollBar:IsShown(),"viewport shrinking restores scrollbar")
editor.materialRows[12].scripts.OnEnter(editor.materialRows[12])
assert(GameTooltip.link:find("|Hitem:12",1,true))
AF.GetAgreementMaterials=function() return {{itemID=99,owned=0,quantity=1,missing=1}} end
AF:RefreshAgreementMaterialsUI()
assert(not editor.materialRows[12]:IsShown())
assert(not editor.materialScroll.ScrollBar:IsShown(),"short material list hides scrollbar")
local counts=editor.materialRows[1].counts
assert(counts.point[1]=="LEFT" and counts.point[2]==editor.materialRows[1].nameFrame and counts.point[3]=="RIGHT" and counts.point[4]==6,"status immediately follows item name box")
assert(counts.textColor[1]>counts.textColor[2] and counts.text:find("1 missing",1,true),"missing quantities use warning color and explicit text")
AF.GetAgreementMaterials=function() return {{itemID=99,owned=2,quantity=1,missing=0}} end
AF:RefreshAgreementMaterialsUI()
assert(counts.textColor[2]>counts.textColor[1] and counts.text:find("2 / 1",1,true),"bag updates reuse row with enough-material color and accurate counts")
assert(not editor.materialScroll.ScrollBar:IsShown())
editor.materialRows[1].scripts.OnEnter(editor.materialRows[1]) assert(GameTooltip.link:find("|Hitem:99",1,true))
AF.GetAgreementMaterials=function() return {{itemID=99,quantity=1}} end
AF:RefreshAgreementMaterialsUI()
assert(counts.text==AF:Text("AGREEMENT_MATERIAL_UNKNOWN",1),"unavailable customer stock is explicit unknown, not zero or artisan stock")
assert(counts.textColor[1]==.25 and counts.textColor[2]==.18,"unknown stock uses neutral ink, never enough/missing color")
AF.GetAgreementMaterials=getMaterials
