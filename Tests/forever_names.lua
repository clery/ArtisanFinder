local function load(path,AF) assert(loadfile(path))("ArtisanFinder",AF) end
local units={player={"Fess","Oakenshield"},target={"Fess","Stormcaller"}}
UnitName=function(unit) return unpack(units[unit] or {}) end
GetRealmName=function() error("live Forever identity must not consult a server") end
local AF={}
load("Flavors/Forever.lua",AF) load("Core/Bootstrap.lua",AF) load("Core/Data.lua",AF)
load("Features/Forever/Names.lua",AF)
assert(AF:GetPlayerFullName()=="Fess Oakenshield","surname is part of player identity")
assert(AF:GetForeverUnitFullName("target")=="Fess Stormcaller","target uses both parts")
assert(AF:NormalizeName("  Fess   Oakenshield  ")=="Fess Oakenshield","space is retained and normalized")
assert(AF:NormalizeName("Fess Oakenshield")~=AF:NormalizeName("Fess Stormcaller"),"same first name never collides")
assert(AF:NormalizeName("Ann A")~=AF:NormalizeName("An Na"),"names cannot collide through space stripping")
assert(AF:GetDisplayPlayerName("Fess Oakenshield")=="Fess Oakenshield")
assert(AF:GetNameRealm("Fess Oakenshield")==nil)
assert(AF:IsNameOnConnectedRealm("Fess Oakenshield"),"shared routing accepts the global full name")
local oldProfile={characterName="Fess-Oakenshield",items={["100"]={note="Bring materials"}},professions={}}
local db={artisanCharacters={["Fess-Oakenshield"]=oldProfile},artisanProfile=oldProfile,
 advertising={["Fess-Oakenshield"]={["164"]=false}},favoriteArtisans={["Fess Oakenshield-OldRealm"]=true},
 professionLinks={["Fess-Oakenshield:164"]="trade-link"},
 customerCache={["100"]={["Fess Stormcaller-OldRealm"]={name="Fess Stormcaller-OldRealm",target="Fess Stormcaller-OldRealm"},
 ["UnknownSmith-OldRealm"]={name="UnknownSmith-OldRealm",note="Legacy observation"}}},
 foreverIndicators={characters={["Fess-Oakenshield"]={nameplateSetupVersion=1}}}}
GetRealmName=function() return "OldRealm" end
AF:MigrateForeverPlayerNames(db)
assert(db.artisanCharacters["Fess Oakenshield"]==oldProfile and oldProfile.characterName=="Fess Oakenshield")
assert(db.artisanCharacters["Fess-Oakenshield"]==nil)
assert(db.advertising["Fess Oakenshield"]["164"]==false,"advertising opt-out preserved")
assert(db.professionLinks["Fess Oakenshield:164"]=="trade-link","shared profession links migrate")
assert(db.favoriteArtisans["Fess Oakenshield"],"favorite and known legacy suffix migrate")
assert(db.customerCache["100"]["Fess Stormcaller"].target=="Fess Stormcaller")
assert(db.customerCache["100"]["UnknownSmith-OldRealm"]==nil and db.foreverLegacyDiscoveryNames.customerCache["100"]["UnknownSmith-OldRealm"].note=="Legacy observation","incomplete legacy names retained without exposing an incorrect whisper target")
assert(db.foreverIndicators.characters["Fess Oakenshield"].nameplateSetupVersion==1,"one-time setup stays acknowledged")
AF:MigrateForeverPlayerNames(db)
assert(db.artisanCharacters["Fess Oakenshield"].items["100"].note=="Bring materials","migration idempotent")
units.player={"Elendra","Lightspeed"}
db.artisanCharacters["Elendra-Lightspeed"]={characterName="Elendra-Lightspeed",items={["200"]={note="Alt commission"}}}
AF:MigrateForeverPlayerNames(db)
assert(db.artisanCharacters["Elendra Lightspeed"].items["200"].note=="Alt commission","each alt migrates when its native full name becomes available")
local retail={}
load("Flavors/Retail.lua",retail) load("Core/Bootstrap.lua",retail) load("Core/Data.lua",retail)
UnitFullName=function() return "Retailplayer","HomeRealm" end
assert(retail:GetPlayerFullName()=="Retailplayer-HomeRealm","Retail remains realm qualified")
assert(retail:NormalizeName("Otherplayer")=="Otherplayer-OldRealm","Retail normalization unchanged")
print("PASS Forever full-name identity, surname uniqueness, preference/link migration and Retail isolation")
