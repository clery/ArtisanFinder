local AF={SCAN_MODEL_VERSION=4}
assert(loadfile("Flavors/Forever.lua"))("ArtisanFinder",AF)
local checks=0
local function check(value,message) checks=checks+1 assert(value,message) end
local function load(path) assert(loadfile(path))("ArtisanFinderForever",AF) end
local recipes={
 [101]={recipeID=101,name="Copper axe",learned=true,professionID=164},
 [102]={recipeID=102,name="Unknown axe",learned=false,professionID=164},
 [103]={recipeID=103,name="Enchant item",learned=true,professionID=164},
 [104]={recipeID=104,name="Other profession",learned=true,professionID=171},
}
local own=true
local timers={}
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
GetTime=os.clock
C_TradeSkillUI={
 GetBaseProfessionInfo=function() return {professionID=164,professionName="Blacksmithing",skillLevel=180} end,
 GetProfessionChildSkillLineID=function() return 164 end,
 GetAllRecipeIDs=function() return {101,102,103,104} end,
 GetRecipeInfo=function(id) return recipes[id] end,
 GetProfessionInfoByRecipeID=function(id) return {professionID=recipes[id].professionID} end,
 GetRecipeItemLink=function(id) if id==101 then return "|Hitem:201|h[Copper axe]|h" end end,
 GetRecipeOutputItemData=function(id) if id==101 then return {itemID=201} end end,
 GetRecipeSchematic=function(id) return {reagentSlotSchematics={{required=true,quantityRequired=3,reagents={{itemID=301}}}}} end,
 CanTradeSkillListLink=function() return true end,
 GetTradeSkillListLink=function() return "|Htrade:164|h[Blacksmithing]|h" end,
 IsTradeSkillReady=function() return true end,
}
AF.db={artisanProfile={professions={},items={},professionPrices={}}}
AF.IsSecretValue=function() return false end
AF.GetItemIDFromLink=function(_,link) return tonumber(link:match("item:(%d+)")) end
AF.IsOwnProfessionWindowOpen=function() return own end
AF.GetSupportedProfessionID=function(_,id) return id end
AF.NormalizeName=function(_,v) return v end
AF.StoreProfessionLink=function(_,name,id,link) return link end
AF.GetPlayerFullName=function() return "Crafter-Realm" end
AF.Now=function() return 100 end
AF.TableCount=function(_,t) local n=0 for _ in pairs(t) do n=n+1 end return n end
AF.DebugLog=function() end
AF.Print=function() end
AF.Text=function(_,key) return key end
AF.IsProtectedActionRestricted=function() return false end
AF.IsCurrentScanModelEntry=function(_,entry) return entry and entry.foreverRecipe end
AF.RefreshOptionsPanel=function() end
AF.GetProfessionName=function() return "Blacksmithing" end
load("Features/Forever/RecipeCapability.lua")
load("Features/Crafter/ProfessionRecipes.lua")
load("Features/Crafter/Scanner.lua")
AF.RefreshScanProgressUI=function() end
local profession=AF:GetCurrentProfessionInfo()
check(profession.id==164,"base Forever profession resolves")
local entry=AF:PrepareProfessionForScan(profession)
local signature=AF:GetCurrentProfessionScanSignature(profession)
local progress=AF:BuildScanProgress(profession,entry,signature,true,"full")
check(progress.total==2,"all learned recipes scan; unlearned and other professions excluded")
check(progress.pending[2].itemID==-103,"itemless enchants retain stable recipe identity")
AF:StartBuiltProfessionScan(profession,entry,signature,"full",true,true,"FORCE",progress)
while #timers>0 do local fn=table.remove(timers,1) fn() end
local item=AF.db.artisanProfile.items["201"]
check(item and item.foreverRecipe,"actual crafted output indexed")
check(item.recipeName=="Copper axe","learned name stored without quality APIs")
check(item.bestReagents[1].quantity==3 and item.bestReagents[1].itemID==301,"required reagents retained")
check(AF.db.artisanProfile.items["-103"].recipeID==103,"itemless enchant scanned")
check(not AF.db.artisanProfile.items["-102"],"unknown recipe never advertised")
check(entry.scanSignature==signature and not entry.scanProgress and not AF.activeScan,"queue completes and saves signature")
item.note="Keep my note" item.priceCopper=50000
AF:ScanJob(profession,entry,{recipeID=101,itemID=201})
check(item.note=="Keep my note" and item.priceCopper==50000,"rescan preserves commission and notes")
local oldSignature=signature
recipes[102].learned=true
check(AF:GetCurrentProfessionScanSignature(profession)~=oldSignature,"learning a recipe invalidates scan signature")
recipes[102].learned=false
progress=AF:BuildScanProgress(profession,entry,signature,true,"full")
AF:StartBuiltProfessionScan(profession,entry,signature,"full",true,true,"FORCE",progress)
own=false
while #timers>0 do local fn=table.remove(timers,1) fn() end
check(not AF.activeScan and entry.scanProgress~=nil,"closing profession pauses queue without losing remaining work")
print("PASS "..checks.." Forever profession scan assertions (no crafting orders/quality/spec APIs present)")
