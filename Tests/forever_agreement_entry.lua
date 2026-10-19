local AF={playerName="Customer Person"}
assert(loadfile("Features/Forever/AgreementEntry.lua"))("ArtisanFinder",AF)
AF.NormalizeName=function(_,name) return name end
AF.GetForeverEntryCommission=function(_,craft) return craft.price end
AF.GetForeverCraftPresentation=function(_,craft) return "|Henchant:"..craft.recipeID.."|h[Craft]|h" end
AF.OpenAgreementEditor=function(_,input) return input end
local craft={name="Crafting Alt",target="Crafting Alt",itemID=-123,recipeID=123,professionID=333,craftName="Enchant",price=0}
local original={name="Crafting Alt",entry={name="Crafting Alt",target="Online Artisan",professionID=333},offers={{name="Crafting Alt",target="Online Artisan",professionID=333}}}
local view={kind="craft",artisanGroup=original,group={name="Crafting Alt",entry=craft}}
local input=AF:RequestForeverCraftAgreement(view)
assert(input.artisan=="Online Artisan" and input.craftingCharacter=="Crafting Alt","contact recovered from original offers, not overwritten copied craft target")
assert(input.commission==0 and input.unitCommission==0,"explicit free price retained")
assert(input.itemID==-123 and input.recipeID==123 and input.itemLink:find("enchant:123",1,true),"enchant identity stays recipe based")
craft.price=nil
assert(AF:RequestForeverCraftAgreement(view).commission==nil,"unspecified commission stays distinct from free")
assert(AF:RequestForeverCraftAgreement({kind="artisan",group=original})==nil,"artisan must select a known craft")
original.offers[1].target=AF.playerName original.entry.target=AF.playerName
assert(AF:RequestForeverCraftAgreement(view)==nil,"cannot request own advertiser")
print("PASS agreement entry preserves online contact, crafting alt, enchant identity and free/unknown prices")
