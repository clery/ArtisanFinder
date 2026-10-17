local function load(path,AF) assert(loadfile(path))("ArtisanFinder",AF) end
for _,flavor in ipairs({"Retail","Forever"}) do
    local AF={}
    load("Flavors/"..flavor..".lua",AF) load("Core/Bootstrap.lua",AF)
    local immediate,queued=0,0
    AF.RefreshCustomerResults=function() immediate=immediate+1 end
    AF:RequestCustomerResultsRefresh()
    assert(immediate==1,"shared dispatcher retains immediate refresh without a flavor scheduler")
    AF.QueueCustomerResultsRefresh=function() queued=queued+1 end
    AF:RequestCustomerResultsRefresh()
    assert(queued==1 and immediate==1,"shared dispatcher chooses scheduler exactly once")
    AF.RefreshCustomerResults=nil AF.QueueCustomerResultsRefresh=nil
    AF:RequestCustomerResultsRefresh()
    load("Utils/Formatting.lua",AF)
    local adapter=flavor=="Retail" and "Features/Retail/Crafter/RecipeCapability.lua" or "Features/Forever/RecipeCapability.lua"
    load(adapter,AF) load("Features/Crafter/ProfessionRecipes.lua",AF)
    load("Features/Customer/ProfessionOpening.lua",AF)
    load(flavor=="Retail" and "Features/Retail/Customer/UI.lua" or "Features/Forever/DirectoryUI.lua",AF)
    load("Features/Crafter/UI.lua",AF)
    if flavor=="Retail" then load("Features/Retail/Crafter/ReagentControls.lua",AF) end
    for _,method in ipairs({"ProfessionInfoMatchesProfession","GetCurrentProfessionRecipeIDs","RecipeBelongsToProfession","GetProfessionLink"}) do
        assert(debug.getinfo(AF[method],"S").source:find("Features/Crafter/ProfessionRecipes.lua",1,true),method.." is shared")
    end
    for _,method in ipairs({"OpenCrafterProfession","ClearPendingProfessionOpen","TrySelectPendingProfessionRecipe"}) do
        assert(debug.getinfo(AF[method],"S").source:find("Features/Customer/ProfessionOpening.lua",1,true),method.." is shared")
    end
    assert(debug.getinfo(AF.GetCurrentCraftingRecipeContext,"S").source:find("Features/Crafter/UI.lua",1,true))
    local recipe={recipeID=1}
    local form={IsVisible=function() return true end,GetRecipeInfo=function() return recipe end}
    ProfessionsFrame={IsShown=function() return true end}
    C_TradeSkillUI={GetProfessionInfoByRecipeID=function() return {professionID=164} end,IsNPCCrafting=function() return false end}
    AF.GetCraftingSchematicForm=function() return form end
    AF.GetCurrentProfessionInfo=function() return {id=164} end
    AF.GetSupportedProfessionID=function(_,id) return id end
    AF.GetRecipeOutputItemIDs=function() return {[100]=true} end
    assert(AF:GetCurrentCraftingRecipeContext().learned==(flavor=="Retail"),"shared context retains learning policy")
    recipe.learned=true assert(AF:GetCurrentCraftingRecipeContext().learned)
    C_TradeSkillUI.IsNPCCrafting=function() return true end
    assert(AF:IsOwnProfessionWindowOpen()==(flavor=="Retail"),"NPC policy stays isolated")
    C_TradeSkillUI.IsNPCCrafting=function() return false end
    local order,directory,crafter=0,0,0
    AF.OnOrderNotificationItemDataLoaded=function() order=order+1 end
    AF.OnDirectoryItemDataLoaded=function() directory=directory+1 end
    AF.RefreshCrafterUIScanSafe=function() crafter=crafter+1 end
    C_Timer={After=function(_,fn) fn() end}
    AF:OnItemDataLoaded(100,true)
    assert(order==1 and directory==1 and crafter==1,"shared item-data handler dispatches all consumers")
end
local AF={db={},Now=function() return 1000 end,QueueDiscoveryChannelJoin=function() end}
load("Flavors/Forever.lua",AF) load("Core/Bootstrap.lua",AF)
load("Features/Social/Comms.lua",AF)
local registered,timers={},{}
C_ChatInfo={RegisterAddonMessagePrefix=function(prefix) registered[prefix]=true end}
C_Timer={After=function(delay,fn) timers[delay]=fn end,NewTicker=function() return {Cancel=function() end} end}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
load("Features/Forever/Discovery.lua",AF) load("Features/Forever/LinkedInn.lua",AF) load("Features/Forever/Compatibility.lua",AF)
AF.QueueDiscoveryChannelJoin=function() end
AF:InitializeComms()
for _,prefix in ipairs({"ARTFINDFF1","LinkedInn","CBRD","ReleaseGaming"}) do assert(registered[prefix],"initializer registers "..prefix) end
assert(timers[10] and timers[12] and timers[15],"all discovery transports initialize through the shared comms entry point")
print("PASS shared function ownership, flavor recipe policies, item-data dispatch and discovery initializer composition")
