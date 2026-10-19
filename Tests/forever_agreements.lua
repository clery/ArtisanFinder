local stamp=1800000000
local clients,queue={},{}
GetRealmName=function()return "Test Realm"end
local function client(name,db)
    local a={playerName=name,db=db or {},MAX_COMMISSION_COPPER=999999990000}
    function a:Now()return stamp end
    function a:SendPayloadParts(parts,channel,target)
        assert(channel=="WHISPER")
        local payload=table.concat(parts,"|") assert(#payload<=255)
        queue[#queue+1]={sender=name,target=target,payload=payload}return true
    end
    assert(loadfile("Features/Forever/Agreements.lua"))("ArtisanFinder",a)
    assert(loadfile("Features/Forever/AgreementComms.lua"))("ArtisanFinder",a)
    a:InitializeAgreements()clients[name]=a return a
end
local function flush()
    local safety=0
    while #queue>0 do
        safety=safety+1 assert(safety<10000,"loop")
        local m=table.remove(queue,1)
        if clients[m.target] then clients[m.target]:OnAgreementMessage(m.payload,"WHISPER",m.sender)end
    end
end
local alice=client("Alice Fullname") local bob=client("Bob Fullname")
alice:ProbeAgreementSupport(bob.playerName)flush()assert(alice:HasAgreementSupport(bob.playerName))
local function draft()
    stamp=stamp+61
    alice:MarkAgreementSupport(bob.playerName)
    local r=assert(alice:CreateAgreementDraft({artisan=bob.playerName,craftingCharacter="Bob Craftingalt",itemID=123,recipeID=100,professionID=164,quantity=3,commission=600,message="Please craft"}))
    assert(alice:SendAgreement(r.id))flush()assert(bob:GetAgreement(r.id))assert(r.delivery=="delivered")return r
end
local r=draft()
assert(bob:PerformAgreementAction(r.id,"counter",{commission=900,message="New terms"}))flush()
assert(r.status=="Counteroffered" and r.commission==900 and r.proposalRevision==2)
assert(not bob:CommitAgreementAction(bob:GetAgreement(r.id),"accept",{},1,"customer"))
assert(alice:PerformAgreementAction(r.id,"ACCEPT"))flush()assert(r.status=="Accepted")
assert(alice:PerformAgreementAction(r.id,"complete"))flush()assert(r.status=="Accepted" and r.completion.customer)
assert(bob:GetCompletedAgreementCounts()==0,"unilateral completion must not count")
assert(bob:PerformAgreementAction(r.id,"complete"))flush()assert(r.status=="Completed")
local total,personal=alice:GetCompletedAgreementCounts({[bob.playerName]=true})
assert(total==0 and personal==1,"customer receipt counts privately, not as own artisan work")
assert(bob:GetCompletedAgreementCounts()==1,"mutual completion counts one agreement, not craft quantity")
bob:RecordCompletedAgreement(bob:GetAgreement(r.id))
assert(bob:GetCompletedAgreementCounts()==1,"duplicate completion is idempotent")
assert(not alice:PerformAgreementAction(r.id,"accept"))
local before=r.stateRevision
local hostile=bob:AgreementSnapshot(bob:GetAgreement(r.id)) hostile.pendingAction={command={action="cancel"}} hostile.localRole="artisan"
alice:ReceiveAgreementBody({kind="snapshot",record=hostile,ack=100},bob.playerName)assert(r.localRole=="customer" and not r.pendingAction)
alice:ReceiveAgreementBody({kind="snapshot",record=bob:AgreementSnapshot(bob:GetAgreement(r.id)),ack=100},"Forged Name")assert(r.stateRevision==before)
assert(alice:DeleteAgreement(r.id))assert(not alice:GetAgreement(r.id))
local _,afterDelete=alice:GetCompletedAgreementCounts({[bob.playerName]=true}) assert(afterDelete==1,"deleting history preserves lifetime total")
alice:ReceiveAgreementBody({kind="snapshot",record=bob:AgreementSnapshot(bob:GetAgreement(r.id)),ack=100},bob.playerName)assert(not alice:GetAgreement(r.id))
local d=assert(alice:CreateAgreementDraft({artisan="Unknown User",recipeID=2,professionID=164}))
assert(not alice:SendAgreement(d.id))assert(d.delivery=="draft")flush()
local retry=draft()
clients[bob.playerName]=nil
assert(alice:PerformAgreementAction(retry.id,"cancel"))flush()
for _,elapsed in ipairs({5,15,40,120,120})do stamp=stamp+elapsed alice:TickAgreements()flush()end
assert(retry.delivery=="failed" and retry.pendingAction.attempts==5)
local saved=alice.db alice=client(alice.playerName,saved)
assert(alice:GetAgreement(retry.id).delivery=="failed")
clients[bob.playerName]=bob
assert(alice:RetryAgreement(retry.id))flush()assert(alice:GetAgreement(retry.id).status=="Cancelled")
local expiry=draft()stamp=stamp+172801 alice:TickAgreements()bob:TickAgreements()assert(expiry.status=="Expired")
assert(bob:IgnoreAgreementPeer("Ignored Person"))assert(bob:GetAgreementStore().ignored["Ignored Person"])
bob:UnignoreAgreementPeer("Ignored Person")assert(not bob:GetAgreementStore().ignored["Ignored Person"])
assert(not alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=1,professionID=1,quantity=1000}))
assert(not alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=1,professionID=1,commission=1000000000000}))
assert(alice:OnAgreementMessage("AG1|1|1|33|bad","WHISPER",bob.playerName))
assert(alice:OnAgreementMessage("AG1|1|1|1|bad","GUILD",bob.playerName))
assert(alice:OnAgreementMessage("AG1|1|1|1|bad","WHISPER",bob.playerName))
assert(not alice:OnAgreementMessage("FA|FF1|164","WHISPER",bob.playerName))
local lost=draft()
assert(bob:PerformAgreementAction(lost.id,"accept"))queue={}
assert(lost.status=="Pending")stamp=stamp+5 bob:TickAgreements()flush()
assert(lost.status=="Accepted" and not bob:GetAgreement(lost.id).snapshotDelivery)
local future={foreverAgreements={characters={["Test Realm:Future Name"]={agreements={version=99,records={secret=true}}}}}}
local futureClient=client("Future Name",future)
assert(not futureClient:CreateAgreementDraft({artisan="Other Name",recipeID=1,professionID=1}))
assert(future.foreverAgreements.characters["Test Realm:Future Name"].agreements.records.secret)
local declined=draft()assert(bob:PerformAgreementAction(declined.id,"decline"))flush()assert(declined.status=="Declined")
local cancelled=draft()assert(bob:PerformAgreementAction(cancelled.id,"accept"))flush()
assert(alice:PerformAgreementAction(cancelled.id,"cancel"))flush()
assert(cancelled.status=="Cancelled" and not bob:PerformAgreementAction(cancelled.id,"complete"))
local late=draft()assert(bob:PerformAgreementAction(late.id,"accept"))queue={}
stamp=stamp+172801 alice:TickAgreements()assert(late.status=="Expired")
alice:ReceiveAgreementBody({kind="snapshot",record=bob:AgreementSnapshot(bob:GetAgreement(late.id)),ack=1},bob.playerName)
assert(late.status=="Accepted")flush()
local altered=bob:AgreementSnapshot(bob:GetAgreement(late.id))altered.commission=500000 altered.stateRevision=altered.stateRevision+1
alice:ReceiveAgreementBody({kind="snapshot",record=altered,ack=1},bob.playerName)assert(late.commission==600)
assert(not alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=1,professionID=1,quantity=1.5}))
assert(not alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=1,professionID=1,quantity=0/0}))
assert(not alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=1,professionID=1,message=string.rep("a",257)}))
assert(not alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=1,professionID=1,message=string.rep("é",257)}))
assert(not alice:OnAgreementMessage("AG2|1|1|1|bad","WHISPER",bob.playerName))
local victim=client("Victim Person")victim:IgnoreAgreementPeer("Ignored Person")
local request=alice:AgreementSnapshot(late)request.customer="Ignored Person"request.artisan=victim.playerName request.id="ignored-1"request.status="Pending"request.stateRevision=0 request.proposalRevision=1 request.createdAt=stamp request.updatedAt=stamp request.completion={customer=false,artisan=false}
victim:ReceiveAgreementBody({kind="command",record=request,sequence=1,revision=1,action="submit",terms={}},"Ignored Person")assert(#victim:GetAgreements()==0)
request.customer="Real Person"victim:ReceiveAgreementBody({kind="command",record=request,sequence=1,revision=1,action="submit",terms={}},"Forged Person")assert(#victim:GetAgreements()==0)
for i=1,4 do request.id="rate-"..i victim:ReceiveAgreementBody({kind="command",record=request,sequence=1,revision=1,action="submit",terms={}},"Real Person")end
assert(#victim:GetAgreements()==3)flush()
local cap=client("Cap Person")
for i=1,50 do assert(cap:CreateAgreementDraft({artisan=bob.playerName,recipeID=i,professionID=1}))end
assert(not cap:CreateAgreementDraft({artisan=bob.playerName,recipeID=51,professionID=1}))
local budget=draft()clients[bob.playerName]=nil
assert(alice:PerformAgreementAction(budget.id,"cancel"))flush()stamp=stamp+5 alice:TickAgreements()flush()
local spent=budget.pendingAction.attempts alice=client(alice.playerName,alice.db)assert(alice:GetAgreement(budget.id).pendingAction.attempts==spent)
clients[bob.playerName]=bob
local free=assert(alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=1,professionID=1,commission=0}))
assert(free.commission==0)
local unknown=assert(alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=1,professionID=1}))assert(unknown.commission==nil)
assert(not alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=123,professionID=333,itemID=12,itemLink="|Hitem:999|h[Wrong craft]|h"}))
assert(not alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=123,professionID=333,itemID=-123,itemLink="|Hspell:123|h[Wrong kind]|h"}))
assert(not alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=123,professionID=333,message="|Tmalicious:10000|t"}))
local linked=assert(alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=123,professionID=333,itemID=12,itemLink="|cffffffff|Hitem:12:0:0|h[Valid craft]|h|r"}))assert(linked.itemID==12)
local enchanted=assert(alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=123,professionID=333,itemID=-123,itemLink="|cffffd000|Henchant:123|h[Valid enchant]|h|r"}))assert(enchanted.recipeID==123)
local enchant=assert(alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=123,professionID=333,itemID=-123}))assert(enchant.recipeID==123)
-- A duplicate command replays its acknowledgement without another state transition.
local latest=bob:GetAgreement(retry.id) local revision=latest.stateRevision
bob:ReceiveAgreementBody({kind="command",id=latest.id,sequence=1,revision=1,action="accept",terms={}},alice.playerName)
assert(latest.stateRevision==revision)flush()
-- Oversized/malformed frames cannot allocate an agreement.
local count=#alice:GetAgreements()
for i=1,20 do alice:OnAgreementMessage("AG1|"..i.."|1|32|x","WHISPER","Noise Person")end
local partials=0 for _ in pairs(alice.agreementFrames)do partials=partials+1 end assert(partials<=2)
assert(#alice:GetAgreements()==count)
-- Evicting bounded replay tombstones cannot revive a deleted recent proposal.
local replayVictim=client("Replay Victim")local replayStore=replayVictim:GetAgreementStore()
for i=1,1001 do replayStore.tombstones["deleted-"..i]=stamp end
replayVictim:TickAgreements()
local evicted
for i=1,1001 do if not replayStore.tombstones["deleted-"..i]then evicted="deleted-"..i break end end
assert(evicted and replayStore.replayFloor==stamp)
local proposal=alice:AgreementSnapshot(linked)
proposal.id=evicted proposal.customer="Replay Customer"proposal.artisan=replayVictim.playerName proposal.createdAt=stamp proposal.updatedAt=stamp
replayVictim:ReceiveAgreementBody({kind="command",record=proposal,action="submit",sequence=1,revision=1,terms={}},proposal.customer)
assert(not replayVictim:GetAgreement(evicted))
stamp=stamp+1 proposal.id="honest-new-proposal"proposal.createdAt=stamp proposal.updatedAt=stamp
replayVictim:ReceiveAgreementBody({kind="command",record=proposal,action="submit",sequence=1,revision=1,terms={}},proposal.customer)
assert(replayVictim:GetAgreement(proposal.id))flush()
for _,bad in ipairs({string.char(128),string.char(192,128),string.char(226),string.char(237,160,128),string.char(244,144,128,128)})do
    assert(not alice:CreateAgreementDraft({artisan=bob.playerName,recipeID=1,professionID=1,message=bad}))
    assert(not alice:CreateAgreementDraft({artisan=bad,recipeID=1,professionID=1}))
end
assert(alice:CreateAgreementDraft({artisan="Élodie 雅 Craft",recipeID=1,professionID=1,message="Bonjour 世界 😀"}))
-- Cancellation supersedes an unacknowledged submit and arrives first safely.
local earlyCustomer=client("Early Customer")local earlyArtisan=client("Early Artisan")
earlyCustomer:MarkAgreementSupport(earlyArtisan.playerName)
local early=assert(earlyCustomer:CreateAgreementDraft({artisan=earlyArtisan.playerName,recipeID=2,professionID=164}))
assert(earlyCustomer:SendAgreement(early.id))local original=early.pendingAction.command queue={}
assert(earlyCustomer:PerformAgreementAction(early.id,"cancel"))
assert(early.status=="Pending" and early.pendingAction.command.sequence==2)flush()
assert(early.status=="Cancelled" and not early.pendingAction)
local cancelledRemote=earlyArtisan:GetAgreement(early.id)assert(cancelledRemote.status=="Cancelled" and not cancelledRemote.unread)
earlyArtisan:ReceiveAgreementBody(original,earlyCustomer.playerName)flush()assert(cancelledRemote.status=="Cancelled")
local forgedCancel=earlyCustomer:AgreementSnapshot(early)forgedCancel.id="forged-cancel"forgedCancel.status="Pending"forgedCancel.stateRevision=0
local beforeCancel=#earlyArtisan:GetAgreements()
earlyArtisan:ReceiveAgreementBody({kind="command",action="cancel",record=forgedCancel,sequence=2,revision=1,terms={}},"Forged Canceller")assert(#earlyArtisan:GetAgreements()==beforeCancel)
-- An unacknowledged completion declaration can also be superseded by cancellation.
local completeRace=draft()assert(bob:PerformAgreementAction(completeRace.id,"accept"))flush()
assert(alice:PerformAgreementAction(completeRace.id,"complete"))queue={}
assert(alice:PerformAgreementAction(completeRace.id,"cancel"))flush()assert(completeRace.status=="Cancelled")
local premature=earlyCustomer:AgreementSnapshot(early)premature.id="premature-completion"premature.status="Pending"premature.stateRevision=0 premature.completion={customer=true,artisan=false}
earlyArtisan:ReceiveAgreementBody({kind="command",action="submit",record=premature,sequence=1,revision=1,terms={}},earlyCustomer.playerName)assert(not earlyArtisan:GetAgreement(premature.id))
local invalidComplete=earlyCustomer:AgreementSnapshot(early)invalidComplete.status="Completed"invalidComplete.completion={customer=true,artisan=false}assert(not earlyCustomer:ValidateAgreementRecord(invalidComplete))
local damaged=client("Damaged Store")
local damagedRecord=assert(damaged:CreateAgreementDraft({artisan=bob.playerName,recipeID=1,professionID=1}))
local damagedStore=damaged:GetAgreementStore()
damagedStore.sequence=0/0 damagedStore.replayFloor="bad"damagedStore.tombstones.bad="not a timestamp"damagedStore.ignored[12]=true
damagedRecord.pendingAction={}damagedRecord.snapshotDelivery={}damagedRecord.commandSequence=-5
local damagedDB=damaged.db
damaged=client("Damaged Store",damagedDB)damaged:TickAgreements()
assert(damaged:GetAgreement(damagedRecord.id)==damagedRecord and damagedRecord.delivery=="failed")
assert(not damagedRecord.pendingAction and not damagedRecord.snapshotDelivery)
assert(damaged:GetAgreementStore().sequence==0 and damaged:GetAgreementStore().replayFloor==0 and not damaged:GetAgreementStore().tombstones.bad)
local recreated=assert(damaged:CreateAgreementDraft({artisan=bob.playerName,recipeID=1,professionID=1}))assert(recreated.id~=damagedRecord.id)
local alt=client("Other Character",saved)assert(#alt:GetAgreements()==0)
print("PASS Forever agreements lifecycle, authentication, retry/reload, expiry, limits and isolation")

-- Engine item-quality named color tokens are legitimate item link decoration.
for _,decoration in ipairs({"|cffa335ee","|cnIQ4:","|cnEPIC_PURPLE_COLOR:"}) do
    local decorated=assert(alice:CreateAgreementDraft({artisan=bob.playerName,itemID=123,recipeID=100,professionID=164,
        itemLink=decoration.."|Hitem:123:0:0:0|h[Crafted item]|h|r"}))
    assert(alice:ValidateAgreementRecord(decorated))
    decorated.itemLink=decoration.."|Hitem:456|h[Different item]|h|r"
    local valid,field=alice:ValidateAgreementRecord(decorated)
    assert(not valid and field=="itemLink","color decoration never bypasses item identity checks")
    alice:GetAgreementStore().records[decorated.id]=nil
end
local rejectedField
alice.DebugLog=function(_,category,line) assert(category=="agreements") rejectedField=line end
assert(not alice:CreateAgreementDraft({artisan=bob.playerName,itemID=123,recipeID=100,professionID=164,message="|Hitem:123|h[Private text]|h"}))
assert(rejectedField:find("invalid message",1,true) and not rejectedField:find("Private text",1,true),"debug log identifies the field without exposing message contents")
print("PASS engine-colored item links and privacy-preserving validation diagnostics")

-- A second local character contributes once; other realms and customer roles do not inflate public totals.
local statsDB=bob.db
local alt=client("Bob Otheralt",statsDB)
local existing=bob:AgreementSnapshot(r)
existing.id="migrated-completed" existing.artisan=alt.playerName existing.craftingCharacter=alt.playerName existing.localRole="artisan"
alt:GetAgreementStore().records[existing.id]=existing
alt:GetAgreementStore().completedStatsMigrated=nil
assert(alt:GetCompletedAgreementCounts()==2,"same-realm artisan totals aggregate across characters")
assert(bob:GetCompletedAgreementCounts()==2)
assert(alt:DeleteAgreement(existing.id))
assert(client(alt.playerName,statsDB):GetCompletedAgreementCounts()==2,"reload and deletion preserve migrated totals")
GetRealmName=function()return "Different Realm"end
assert(client(bob.playerName,statsDB):GetCompletedAgreementCounts()==0,"do not combine realms")
GetRealmName=function()return "Test Realm"end
print("PASS completed agreement lifetime totals, private counts, migration, deduplication and realm isolation")

local pruned=client("Pruned Artisan")
local old=pruned:AgreementSnapshot(r)
old.id="old-completed" old.artisan=pruned.playerName old.localRole="artisan" old.createdAt=stamp-3000000 old.updatedAt=old.createdAt
pruned:GetAgreementStore().records[old.id]=old
pruned:GetAgreementStore().completedStatsMigrated=nil
pruned:GetCompletedAgreementCounts()
pruned:TickAgreements()
assert(not pruned:GetAgreement(old.id) and pruned:GetCompletedAgreementCounts()==1,"pruning preserves lifetime counter")
print("PASS completed counters survive automatic terminal history cleanup")

local customerAlt=client("Alice Otheralt",alice.db)
local receipt=customerAlt:AgreementSnapshot(r)
receipt.id="customer-alt-completed" receipt.customer=customerAlt.playerName receipt.localRole="customer"
customerAlt:GetAgreementStore().records[receipt.id]=receipt
customerAlt:GetAgreementStore().completedStatsMigrated=nil
local artisanTotal,personalTotal=customerAlt:GetCompletedAgreementCounts({[bob.playerName]=true})
assert(artisanTotal==0 and personalTotal==2,"private history aggregates own customer alts without publishing it")
local wrong=customerAlt:AgreementSnapshot(receipt)
wrong.id="wrong-local-owner" wrong.customer="Unrelated Customer" wrong.localRole="customer"
customerAlt:GetAgreementStore().records[wrong.id]=wrong
customerAlt:RecordCompletedAgreement(wrong)
local _,stillPersonal=customerAlt:GetCompletedAgreementCounts({[bob.playerName]=true})
assert(stillPersonal==2,"mismatched local participant cannot inflate private completion history")
print("PASS private completion counts aggregate own alts and reject mismatched owner identity")
