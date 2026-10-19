local AF={records={}}
local sounds={}
SOUNDKIT={CATALOG_SHOP_OPEN_LOADING_SCREEN=999, CUSTOM_ALERT=123}
PlaySound=function(sound,channel)sounds[#sounds+1]={sound,channel}end
assert(loadfile("Core/NotificationSound.lua"))("ArtisanFinder",AF)
local created,stamp,blocked,opened=0,0,false,0
GetTime=function()return stamp end
InCombatLockdown=function()return blocked end
IsInInstance=function()return false end
local function widget()
    local w={scripts={}}
    for _,name in ipairs({"SetSize","SetFrameStrata","SetFrameLevel","EnableMouse","RegisterForClicks","SetClampedToScreen",
        "SetJustifyH","SetWordWrap","ClearAllPoints","SetPoint","RegisterEvent","SetDesaturated"}) do w[name]=function()end end
    function w:SetTextColor(r,g,b)self.color={r,g,b}end
    function w:SetVertexColor(r,g,b)self.color={r,g,b}end
    function w:SetBackdrop(value)self.backdrop=value end
    function w:SetBackdropColor(...)self.background={...}end
    function w:SetBackdropBorderColor(...)self.border={...}end
    function w:SetAtlas(value)self.atlas=value end
    function w:GetText()return self.text end
    function w:SetPoint(...) self.point={...} end
    function w:SetHeight(value) self.height=value end
    function w:GetHeight() return self.height or 108 end
    function w:GetStringWidth() return #(self.text or "")*6 end
    function w:CreateTexture()return widget()end
    function w:CreateFontString()return widget()end
    function w:SetScript(name,fn)self.scripts[name]=fn end
    function w:SetTexture(value)self.texture=value end
    function w:SetText(value)self.text=value end
    function w:SetAlpha(value)self.alpha=value end
    function w:Hide()self.shown=false end
    function w:Show()self.shown=true end
    return w
end
UIParent=widget()
local tooltipLines={}
GameTooltip=widget()
GameTooltip.SetOwner=function() end
GameTooltip.SetHyperlink=function() end
GameTooltip.AddLine=function(_,value) tooltipLines[#tooltipLines+1]=value end
CreateFrame=function(_,_,_,template)
    assert(template=="ArtisanFinderOrderNotificationToastTemplate")created=created+1
    local w=widget()for _,key in ipairs({"Icon","IconBorder","Title","ItemName","Meta","Commission"})do w[key]=widget()end return w
end
local quality,requests=nil,0
ITEM_QUALITY_COLORS={[3]={r=.0,g=.44,b=.87},[4]={r=.64,g=.21,b=.93}}
C_Item={GetItemIconByID=function(id)assert(id>0)return "item"..id end,
    GetItemInfo=function(id)assert(id>0)return "Local item","item:"..id,quality end,
    RequestLoadItemDataByID=function(id)assert(id>0)requests=requests+1 end}
C_Spell={GetSpellTexture=function(id)return "spell"..id end}
function AF:GetAgreement(id)return self.records[id]end
function AF:Text(key,...)
    if key=="ORDER_NOTIFICATION_META" then return string.format("For %s - From %s",...)end
    if key=="ORDER_NOTIFICATION_COMMISSION" then return string.format("Commission: %s",...)end
    return key
end
function AF:FormatMoney(value,free)return free and "Free" or tostring(value).." coins" end
function AF:GetAgreementCraftPresentation(r)return "Local item",r.itemID>0 and "item:"..r.itemID or "enchant:"..r.recipeID end
function AF:GetAgreementDisplayStatus(r)return r.status end
function AF:OpenAgreementNotification(r)opened=opened+1 self.selected=r.id r.unread=false end
assert(loadfile("Features/Forever/AgreementNotifications.lua"))("ArtisanFinder",AF)
local function record(id,item)
    local r={id=id,itemID=item or 42,recipeID=7,stateRevision=1,status="Pending",unread=true,localRole="artisan",customer="Other Name",artisan="My Name",craftingCharacter="My Alt",commission=12345}
    AF.records[id]=r return r
end
local r=record("one")AF:QueueAgreementNotification(r)
local s=AF.agreementNotifications local toast=s.active[1]
assert(#sounds==1 and sounds[1][1]==SOUNDKIT.CATALOG_SHOP_OPEN_LOADING_SCREEN and sounds[1][2]==nil,
    "new visible agreement uses the Retail default sound and default channel")
assert(toast.Title.text=="AGREEMENT_TOAST_TITLE" and toast.Message.text=="" and toast:GetHeight()==108)
assert(toast.Commission.text=="Commission: 12345 coins" and toast.Status.text=="Pending")
assert(toast.Status.color[1]==.72 and toast.Status.color[2]==.68 and toast.Status.color[3]==.6,"pending status retains neutral color")
assert(toast.ItemName.color[1]==1 and toast.IconBorder.shown,"unknown rarity has neutral style")
assert(requests==1,"missing quality requests item metadata once")
toast.scripts.OnEvent(toast,"ITEM_DATA_LOAD_RESULT",99,true)
assert(requests==1 and toast.ItemName.color[1]==1,"unrelated item events do not change the toast")
quality=4 toast.scripts.OnEvent(toast,"ITEM_DATA_LOAD_RESULT",42,true)
assert(toast.ItemName.color[1]==.64 and toast.IconBorder.color[3]==.93,"loaded rarity updates name and frame")
assert(toast.backdrop.edgeFile:find("UI%-DialogBox%-Gold%-Border") and toast.Parchment.atlas=="Profession-Background-Template2")
assert(created==1 and toast.Meta.text=="For My Alt - From Other Name" and toast.ItemName.text=="Local item")
AF:QueueAgreementNotification(r)assert(#s.active==1 and #s.pending==0)
assert(#sounds==1,"deduplication and metadata updates do not replay audio")
r.message=string.rep("é",100).."\n ending"
toast.scripts.OnEvent(toast,"ITEM_DATA_LOAD_RESULT",42,true)
assert(toast.Message.text:sub(-3)=="…" and not toast.Message.text:find("\n",1,true) and toast:GetHeight()==124)
assert(toast.Message.text:sub(1,-4):gsub("é","")=="" and toast.messageText:find(" ending",1,true))
toast.scripts.OnEnter(toast)
assert(tooltipLines[#tooltipLines]==toast.messageText,"tooltip retains the full optional message")
toast.scripts.OnLeave(toast)
assert(#sounds==1,"hover pause/resume does not replay audio")
toast.scripts.OnClick(toast,"RightButton")assert(opened==0 and r.unread and #s.active==0)
assert(toast.Message.text=="" and toast:GetHeight()==108 and toast.messageText==nil,"pool resets preview")
r.message="Short message" r.stateRevision=2 r.status="Accepted" r.localRole="customer" AF:QueueAgreementNotification(r)
assert(s.active[1].Message.text=="Short message")
assert(s.active[1]==toast and toast.Status.color[1]==.2 and toast.Status.color[2]==1 and toast.Status.color[3]==.2,"accepted status is green on a reused toast")
assert(s.active[1].Commission.text=="Commission: 12345 coins" and s.active[1].Status.text=="Accepted")
assert(s.active[1].Meta.text=="For My Alt - From Other Name","both participants remain clear on outgoing updates")
toast=s.active[1]toast.scripts.OnClick(toast,"LeftButton")assert(opened==1 and AF.selected==r.id and not r.unread)
local soundCount=#sounds
blocked=true
local enchant=record("enchant",-7)AF:QueueAgreementNotification(enchant)assert(#s.pending==1 and #s.active==0)
enchant.stateRevision=2 enchant.status="Counteroffered" AF:QueueAgreementNotification(enchant)
assert(#s.pending==1,"deferred revisions coalesce")
assert(#sounds==soundCount,"restricted notifications remain silent")
blocked=false AF:RefreshAgreementNotifications()assert(s.active[1].Icon.texture=="spell7" and s.active[1].Status.text=="Counteroffered")
assert(#sounds==soundCount+1,"coalesced deferred notification sounds once on display")
assert(s.active[1].ItemName.color[1]==1,"pooled enchant must clear previous item rarity")
assert(s.active[1].Status.color[1]==.72 and s.active[1].Status.color[2]==.68,"reuse clears accepted green")
local cancelled=record("cancelled") cancelled.status="CANCELLED" AF:QueueAgreementNotification(cancelled)
local cancelledToast=s.active[2]
assert(cancelledToast.Status.color[1]==1 and cancelledToast.Status.color[2]==.2 and cancelledToast.Status.color[3]==.2,"cancelled status is red independently of localized display text")
AF:ReleaseAgreementNotification(cancelledToast)
local pending=record("pending") AF:QueueAgreementNotification(pending)
assert(s.active[2]==cancelledToast and cancelledToast.Status.color[1]==.72 and cancelledToast.Status.color[2]==.68 and cancelledToast.Status.color[3]==.6,"reuse clears cancelled red")
AF:ReleaseAgreementNotification(cancelledToast)
enchant.commission=0 AF:ReleaseAgreementNotification(s.active[1]) enchant.stateRevision=3 AF:QueueAgreementNotification(enchant)
assert(s.active[1].Commission.text=="Commission: Free")
enchant.commission=nil AF:ReleaseAgreementNotification(s.active[1]) enchant.stateRevision=4 AF:QueueAgreementNotification(enchant)
assert(s.active[1].Commission.text=="Commission: —","nil commission differs from zero")
soundCount=#sounds
blocked=true s.active[1].scripts.OnUpdate(s.active[1],1)assert(#s.active==0 and enchant.unread)
blocked=false AF:RefreshAgreementNotifications()
assert(#sounds==soundCount,"resuming a previously visible card after combat must not replay its sound")
s.active[1].scripts.OnUpdate(s.active[1],6)assert(#s.active==0 and enchant.unread)
for i=1,12 do
 local entry=record("many"..i) if i==2 then entry.message="Optional message" end AF:QueueAgreementNotification(entry)
end
assert(s.active[1].point[5]==-170 and s.active[2].point[5]==-286 and s.active[3].point[5]==-418,"mixed-height stack reserves each preview plus spacing")
assert(#s.active==3 and created==3)
while #s.active>0 do s.active[1].scripts.OnUpdate(s.active[1],6)end
assert(created==3 and #s.free==3)
soundCount=#sounds
blocked=true AF:QueueAgreementNotification(record("old"))stamp=301 blocked=false AF:RefreshAgreementNotifications()assert(#s.active==0)
assert(#sounds==soundCount,"expired deferred notification stays silent")
blocked=true
local read=record("read") AF:QueueAgreementNotification(read) read.unread=false
blocked=false AF:RefreshAgreementNotifications()
assert(#sounds==soundCount,"already read deferred notification stays silent")
AF.db={orderNotificationSound="CUSTOM_ALERT",orderNotificationChannel="Master"}
AF:QueueAgreementNotification(record("configured"))
assert(sounds[#sounds][1]==123 and sounds[#sounds][2]=="Master","Retail configured sound and channel are shared")
AF.db.orderNotificationSound="unknown" AF.db.orderNotificationChannel="default"
AF:QueueAgreementNotification(record("fallback"))
assert(sounds[#sounds][1]==999 and sounds[#sounds][2]==nil,"unknown sound and default channel match Retail fallback")
soundCount=#sounds AF.db.orderNotificationSoundEnabled=false
AF:QueueAgreementNotification(record("silent"))
assert(#sounds==soundCount,"disabled notification sound is respected")
AF.db.orderNotificationSoundEnabled=true AF.db.orderNotificationChannel=""
AF:PlayOrderNotificationSound()
assert(#sounds==soundCount+1 and sounds[#sounds][2]==nil,"legacy Retail preview API shares playback and blank channel fallback")
AF.db.orderNotificationsEnabled=false AF:PlayNotificationSound()
assert(#sounds==soundCount+1,"legacy disabled notifications remain silent")
AF:PlayOrderNotificationSound(true)
assert(#sounds==soundCount+2,"forced Retail preview preserves existing override")
PlaySound=nil AF:PlayNotificationSound(true)
PlaySound=function()error("no soundkit must not play")end SOUNDKIT=nil AF:PlayNotificationSound(true)
print("PASS Forever agreement Retail-style toasts: dedup, bounded reuse, restrictions, expiry, click/dismiss and enchant IDs")
