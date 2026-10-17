local AF = {}
assert(loadfile("Flavors/Forever.lua"))("ArtisanFinder",AF)
local function load(path) assert(loadfile(path))('ArtisanFinder', AF) end
load('Core/Bootstrap.lua')
load('Core/Data.lua')
load('Features/Social/Comms.lua')
assert(AF:GetSupportedProfessionID(185)==185, 'Cooking supported')
assert(AF:IsCurrentScanModelEntry({foreverRecipe=true,recipeID=7418}))
assert(not AF:HasAdvancedReagentFacts({foreverRecipe=true,recipeID=7418}))
AF.db={customerCache={}}
AF.NormalizeName=function(_,name) return name~='' and name or nil end
AF.DecodeField=function(_,value) return value or '' end
AF.DecodeNote=function(_,value) return value end
AF.Now=function() return 1000 end
AF.GetPlayerFullName=function() return 'Viewer-Forever' end
AF.DecodeCompactOptionalReagentDeltas=function() end
AF.GetImportedArtisanProfile=function() end
AF.GetLocalArtisanProfile=function() end
AF.GetRememberedProfessionLink=function() end
AF.DebugLog=function() end
AF.ApplyPendingReagentDetail=function() end
AF.RefreshCustomerResults=function() end
local reagents={{itemID=10940,quantity=1}}
AF:HandleResponse({'R','FF1',-7418,333,25000,0,'Enchant note',7418,999,'',99,'Crafter-Forever','',0,{foreverRecipe=true,reagents=reagents}},'Crafter-Forever')
local entry=AF.db.customerCache['-7418']['Crafter-Forever']
assert(entry.foreverRecipe and entry.recipeID==7418)
assert(entry.priceCopper==25000 and entry.note=='Enchant note')
assert(entry.reagents==reagents)
assert(entry.quality==nil and entry.totalSkill==nil and entry.maxOutputQuality==nil,'no fabricated crafting quality')
assert(AF:IsCurrentScanModelEntry(entry))
assert(not AF:IsGuildOrderEntry({guildMember=true}))
print('PASS Forever social response, enchant recipe keys, commissions, real reagent data; no quality/order APIs')
