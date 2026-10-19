-- Cross-language order notifications extend the legacy layout without renaming peers.
local AF={db={},playerName="Customer-Realm",PROTOCOL_VERSION="1"}
local function load(path) assert(loadfile(path))("ArtisanFinder",AF) end
load("Utils/Formatting.lua")
load("Core/NotificationSound.lua")
load("Features/Retail/Orders/Notifications.lua")
AF.NormalizeName=function(_,value) return value end
AF.GetPlayerFullName=function() return AF.playerName end
AF.GetRememberedArtisanContact=function() end
AF.IsOwnArtisanCharacter=function() return false end
AF.GetItemIDFromLink=function() end
AF.Now=function() return 1000 end
AF.DebugLog=function() end
local locale="enUS"
AF.GetProfessionName=function(_,id) assert(id==164) return locale=="frFR" and "Forge" or "Blacksmithing" end
C_Item={GetItemInfo=function(id)
    assert(id==123)
    local name=locale=="frFR" and "Épée en mithril" or "Mithril Sword"
    return name,"|Hitem:123|h["..name.."]|h",2,nil,nil,nil,nil,nil,nil,456
end,GetItemIconByID=function() return 456 end}
C_TradeSkillUI={GetProfessionInfoByRecipeID=function(id) assert(id==789) return {professionID=999,parentProfessionID=164} end}
Enum={CraftingOrderState={Fulfilled=2}}
AF.SendAddon=function() return true end
local sent
AF.SendPayloadParts=function(_,parts,channel,target)
    assert(channel=="WHISPER" and target=="Artisan-Realm")
    sent=parts return true
end
local input={itemID=123,recipeID=789,itemName="Mithril Sword",professionName="Blacksmithing",commissionCopper=10}
assert(AF:SendOrderNotification("Artisan-Realm",1,input))
assert(#sent==14 and sent[1]=="O" and sent[6]==123 and sent[13]==164 and sent[14]==789,"O appends canonical profession/recipe IDs after legacy fields")
assert(input.professionID==nil,"preparing wire metadata does not mutate caller input")
-- An old reader still reads these exact original positions.
assert(AF:DecodeField(sent[9])=="Mithril Sword" and AF:DecodeField(sent[11])=="Blacksmithing")
local captured
AF.NotifyPersonalOrder=function(_,character,count,sender,details)
    assert(character=="Artisan-Realm" and count==1 and sender=="Customer-Realm") captured=details
end
locale="frFR"
AF:HandleOrderNotification(sent,"Customer-Realm")
assert(captured.itemID==123 and captured.recipeID==789 and captured.professionID==164)
assert(captured.itemName=="Épée en mithril" and captured.professionName=="Forge","new receiver resolves sender's English labels from numeric IDs")
local legacy={} for i=1,12 do legacy[i]=sent[i] end
AF:HandleOrderNotification(legacy,"Customer-Realm")
assert(captured.itemName=="Épée en mithril" and captured.professionName=="Blacksmithing","legacy peers retain profession-name fallback and local item resolution")
legacy[13]="nan" legacy[14]="-789"
AF:HandleOrderNotification(legacy,"Customer-Realm")
assert(captured.professionID==nil and captured.recipeID==nil,"invalid appended identifiers are ignored")
-- Fulfilled notifications have the same append-only extension after their ten fields.
locale="enUS"
assert(AF:SendFulfilledOrderNotification({orderID=42,customerName="Artisan-Realm",itemID=123,spellID=789},input))
assert(#sent==12 and sent[1]=="F" and sent[4]==123 and sent[11]==164 and sent[12]==789)
AF.NotifyCustomerOrderFulfilled=function(_,order,details,sender)
    assert(order.orderID=="42" and sender=="Customer-Realm") captured=details
end
locale="frFR"
AF:HandleFulfilledOrderNotification(sent,"Customer-Realm")
assert(captured.itemName=="Épée en mithril" and captured.professionName=="Forge" and captured.recipeID==789)
legacy={} for i=1,10 do legacy[i]=sent[i] end
AF:HandleFulfilledOrderNotification(legacy,"Customer-Realm")
assert(captured.professionID==nil and captured.professionName=="Blacksmithing","old fulfilled messages remain readable")
-- Fallback without compressed payload transport still obeys the client frame limit.
AF.SendPayloadParts=nil
AF.SendAddon=function(_,payload) assert(#payload<=255) sent=payload return true end
assert(AF:SendOrderNotification("Artisan-Realm",1,input))
assert(sent:find("|164|789",1,true))
assert(AF:SendFulfilledOrderNotification({orderID=42,customerName="Artisan-Realm",itemID=123,spellID=789},input))
assert(sent:find("|164|789",1,true))
print("PASS Retail cross-locale O/F numeric metadata, append-only legacy compatibility and bounded whisper fallback")
