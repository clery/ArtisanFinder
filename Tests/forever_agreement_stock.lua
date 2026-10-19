-- Customer inventory is authoritative even when the artisan owns more reagents.
local stamp=1800000000
local clients,queue={},{}
local active
local customerSchematic=false
ChatThrottleLib={SendAddonMessage=function(_,priority,prefix,payload,channel,target)
    assert(channel=="WHISPER" and #payload<=255 and prefix=="ArtisanFinder")
    queue[#queue+1]={sender=active.playerName,target=target,payload=payload,prefix=prefix}
end}
local stocks={["Order Customer"]={[10]=2,[20]=0},["Craft Artisan"]={[10]=900,[20]=500}}
local lookups={}
GetRealmName=function() return "Stock Realm" end
C_Item={GetItemCount=function(id)
    lookups[active.playerName]=(lookups[active.playerName] or 0)+1
    return stocks[active.playerName][id]
end}
C_TradeSkillUI={GetRecipeSchematic=function()
    if active.playerName=="Order Customer" and not customerSchematic then return nil end
    return {reagentSlotSchematics={
    {required=true,quantityRequired=4,reagents={{itemID=10}}},
    {required=true,quantityRequired=2,reagents={{itemID=20}}}}} end}
local function client(name,savedDB)
    local a={playerName=name,db=savedDB or {}}
    function a:Now() return stamp end
    function a:GetDisplayItemName(id) return "Item "..id end
    function a:NormalizeName(name) return name end
    function a:Text(key) return key end
    a.PREFIX="ArtisanFinder" a.PROTOCOL_VERSION="1"
    function a:IsAddonCommsUnavailable() return false end
    function a:IsSecretValue() return false end
    function a:IsDevTrafficLogsEnabled() return false end
    assert(loadfile("Features/Social/Comms.lua"))("ArtisanFinder",a)
    for _,path in ipairs({"Agreements","AgreementComms","PreparationTracker","AgreementPreparation"}) do
        assert(loadfile("Features/Forever/"..path..".lua"))("ArtisanFinder",a)
    end
    a:InitializeAgreements() clients[name]=a return a
end
local function flush()
    local count=0
    while #queue>0 do
        count=count+1 assert(count<1000,"stock feedback loop")
        local message=table.remove(queue,1)
        active=clients[message.target]
        if active then active:OnAddonMessage(message.prefix,message.payload,"WHISPER",message.sender) end
    end
end
local customer=client("Order Customer") local artisan=client("Craft Artisan")
active=customer customer:MarkAgreementSupport(artisan.playerName)
local order=assert(customer:CreateAgreementDraft({artisan=artisan.playerName,recipeID=100,itemID=123,professionID=164,quantity=3}))
assert(customer:SendAgreement(order.id)) flush()
local remote=assert(artisan:GetAgreement(order.id))
active=artisan
assert(artisan:GetAgreementMaterials(remote)[1].owned==2,"customer without recipe must publish artisan-requested counts via real dispatcher")
active=customer
assert(customer:GetAgreementMaterials(order)==nil,"customer lacks artisan recipe")
-- Remember requested IDs for later bag refreshes, even without recipe knowledge.
stocks[customer.playerName][10]=7
customer:SendAgreementCustomerStock(order) flush()
active=artisan assert(artisan:GetAgreementMaterials(remote)[1].owned==7)
stocks[customer.playerName][10]=2
active=customer customerSchematic=true
customer:SendAgreementCustomerStock(order) flush()
active=customer
local materials=customer:GetAgreementMaterials(order)
assert(materials[1].owned==2 and materials[1].quantity==12 and materials[1].missing==10)
assert(materials[2].owned==0 and materials[2].missing==6,"zero stock is known, not unknown")
active=artisan
materials=artisan:GetAgreementMaterials(remote)
assert(materials[1].owned==2 and materials[1].missing==10 and materials[2].owned==0)
assert(not lookups[artisan.playerName],"artisan inventory must never be queried")
assert(not artisan:SendAgreementCustomerStock(remote),"artisan cannot publish customer stock")
assert(not artisan:AgreementSnapshot(remote).counts,"inventory must not enter authoritative agreement snapshots")
-- Live customer bag refresh updates both views without changing agreement terms.
stocks[customer.playerName][10]=15
active=customer customer:SendAgreementCustomerStock(order) flush()
active=artisan materials=artisan:GetAgreementMaterials(remote)
assert(materials[1].owned==15 and materials[1].missing==0 and remote.stateRevision==1 and remote.status=="Pending")
-- An artisan refresh can request stock after reload; no local inventory fallback.
remote.customerStock=nil
materials=artisan:GetAgreementMaterials(remote)
assert(materials[1].owned==nil and materials[1].missing==nil and materials[1].quantity==12)
stamp=stamp+6
artisan:RequestAgreementCustomerStock(remote) flush()
active=artisan assert(artisan:GetAgreementMaterials(remote)[1].owned==15)
local before=remote.customerStock
artisan:ReceiveAgreementBody({kind="customerStock",id=order.id,counts={["10"]=999}},"Forged User")
assert(remote.customerStock==before,"stock sender must be ordering customer")
artisan:ReceiveAgreementBody({kind="customerStock",id=order.id,counts={["10"]=-1}},customer.playerName)
assert(remote.customerStock==before,"negative stock rejected")
artisan:ReceiveAgreementBody({kind="customerStock",id=order.id,counts={["10"]=0/0}},customer.playerName)
assert(remote.customerStock==before,"non-finite stock rejected")
local oversized={} for id=1,33 do oversized[tostring(id)]=1 end
artisan:ReceiveAgreementBody({kind="customerStock",id=order.id,counts=oversized},customer.playerName)
assert(remote.customerStock==before,"stock message bounded")
-- Remote messages cannot overwrite the customer's own bag data.
active=customer
customer:ReceiveAgreementBody({kind="customerStock",id=order.id,counts={["10"]=999}},artisan.playerName)
assert(customer:GetAgreementMaterials(order)[1].owned==15 and not customer.agreementCustomerStock)
-- Missing APIs and missing customer schematic produce unknown, never zero.
C_Item.GetItemCount=nil
assert(customer:GetAgreementMaterials(order)[1].owned==nil)
customer:SendAgreementCustomerStock(order) flush()
active=artisan materials=artisan:GetAgreementMaterials(remote)
assert(materials[1].owned==nil and materials[1].missing==nil)
-- Legacy clients can ignore stockRequest; required counts stay available.
queue={} remote.customerStock=nil
materials=artisan:GetAgreementMaterials(remote)
assert(materials[1].quantity==12 and materials[1].owned==nil and not lookups[artisan.playerName])
-- Untrusted requests cannot solicit arbitrary inventory or unbounded item lists.
active=customer
local remembered=customer.agreementStockItems[order.id]
customer:ReceiveAgreementBody({kind="stockRequest",id=order.id,items={["30"]=true}},"Forged User")
assert(customer.agreementStockItems[order.id]==remembered)
stamp=stamp+6
customer:ReceiveAgreementBody({kind="stockRequest",id=order.id,items={["-1"]=true}},artisan.playerName)
assert(customer.agreementStockItems[order.id]==remembered)
local requested={} for id=1,33 do requested[tostring(id)]=true end
customer:ReceiveAgreementBody({kind="stockRequest",id=order.id,items=requested},artisan.playerName)
assert(customer.agreementStockItems[order.id]==remembered)
-- Freeze on artisan acceptance. Bag changes, late stock messages and reloads
-- cannot change either participant's agreed missing-material counts.
C_Item.GetItemCount=function(id)
    lookups[active.playerName]=(lookups[active.playerName] or 0)+1
    return stocks[active.playerName][id]
end
customerSchematic=false
stocks[customer.playerName][10]=3
active=artisan stamp=stamp+6 artisan:RequestAgreementCustomerStock(remote) flush()
active=artisan assert(artisan:PerformAgreementAction(remote.id,"accept")) flush()
assert(remote.materialSnapshot["10"].quantity==12 and remote.materialSnapshot["10"].owned==3)
active=customer
assert(order.materialSnapshot["10"].owned==3 and customer:GetAgreementMaterials(order)[1].missing==9)
local frozenLookups=lookups[customer.playerName]
stocks[customer.playerName][10]=500
customer:SendAgreementCustomerStock(order)
customer:ReceiveAgreementBody({kind="stockRequest",id=order.id,items={["10"]=true}},artisan.playerName)
active=artisan
artisan:ReceiveAgreementBody({kind="customerStock",id=order.id,counts={["10"]=999}},customer.playerName)
artisan:RequestAgreementCustomerStock(remote)
assert(#queue==0 and lookups[customer.playerName]==frozenLookups,"accepted agreement must never request or sample inventory")
assert(artisan:GetAgreementMaterials(remote)[1].missing==9)
active=customer
assert(customer:GetAgreementMaterials(order)[1].missing==9 and lookups[customer.playerName]==frozenLookups)
-- Reload saved records; no session stock/recipe needed and no inventory traffic.
customer.agreementStockItems=nil artisan.agreementStockItems=nil
customer:InitializeAgreements() artisan:InitializeAgreements()
active=artisan artisan:RequestAgreementCustomerStock(remote)
active=customer customer:SendAgreementCustomerStock(order)
assert(#queue==0 and customer:GetAgreementMaterials(order)[1].missing==9)
assert(customer:PerformAgreementAction(order.id,"complete")) flush()
active=artisan assert(artisan:PerformAgreementAction(remote.id,"complete")) flush()
assert(order.status=="Completed" and order.materialSnapshot["10"].owned==3)
-- Artisan's later authoritative snapshots cannot rewrite frozen material terms.
local changed=artisan:AgreementSnapshot(remote)
changed.materialSnapshot["10"].owned=900 changed.stateRevision=changed.stateRevision+1
active=customer customer:ReceiveAgreementBody({kind="snapshot",record=changed,ack=order.commandSequence},artisan.playerName)
assert(order.materialSnapshot["10"].owned==3)
flush()
-- Customer accepts counteroffer without knowing recipe, after session cache loss.
active=customer
customer:MarkAgreementSupport(artisan.playerName)
local second=assert(customer:CreateAgreementDraft({artisan=artisan.playerName,recipeID=100,itemID=123,professionID=164,quantity=1}))
assert(customer:SendAgreement(second.id)) flush()
active=artisan local secondRemote=artisan:GetAgreement(second.id)
assert(artisan:PerformAgreementAction(second.id,"counter",{commission=100})) flush()
customer.agreementStockItems=nil
stocks[customer.playerName][10]=1
active=customer assert(customer:PerformAgreementAction(second.id,"accept"))
stocks[customer.playerName][10]=999
flush()
assert(second.materialSnapshot["10"].owned==1 and secondRemote.materialSnapshot["10"].owned==1)
-- Legacy accepted records get explicit unknown values, never a new stock query.
second.materialSnapshot=nil second.materialOutput=nil
secondRemote.materialSnapshot=nil secondRemote.materialOutput=nil
local customerBefore=lookups[customer.playerName]
active=customer customer:InitializeAgreements()
active=artisan artisan:InitializeAgreements()
assert(second.materialSnapshot and secondRemote.materialSnapshot)
assert(artisan:GetAgreementMaterials(secondRemote)[1].owned==nil)
assert(lookups[customer.playerName]==customerBefore and #queue==0)
local function copy(value)
    if type(value)~="table" then return value end
    local result={} for key,entry in pairs(value) do result[key]=copy(entry) end return result
end
local customerDB,artisanDB=copy(customer.db),copy(artisan.db)
customer=client("Order Customer",customerDB)
artisan=client("Craft Artisan",artisanDB)
active=customer local restored=customer:GetAgreement(order.id)
assert(customer:GetAgreementMaterials(restored)[1].missing==9)
customer:SendAgreementCustomerStock(restored)
active=artisan restored=artisan:GetAgreement(order.id)
artisan:RequestAgreementCustomerStock(restored)
assert(artisan:GetAgreementMaterials(restored)[1].missing==9)
assert(#queue==0 and lookups[customer.playerName]==customerBefore,"fresh clients restore frozen saved variables without inventory queries")
print("PASS immutable accepted material snapshot, both roles, late packets, reload, counteroffer acceptance and legacy unknown")
print("PASS production agreement wire, unknown customer recipe, authenticated reagent requests, agreement customer stock, both roles, refresh, unknown fallback, privacy, authentication and message limits")
