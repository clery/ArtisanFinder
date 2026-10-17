local function load(path,AF) assert(loadfile(path))("ArtisanFinder",AF) end
local AF={}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
C_Timer={After=function(_,fn) fn() end}
load("Flavors/Forever.lua",AF) load("Core/Bootstrap.lua",AF)
load("Core/Util.lua",AF) load("Core/Core.lua",AF)
AF.EnsureDB=function(self) self.db=self.db or {} end
load("Features/Forever/Availability.lua",AF)
AF.DebugLog=function() end
AF.Print=function() end
AF.Text=function(_,key) return key end
AF.IsProtectedActionRestricted=function() return false end
AF.IsAddonCommsUnavailable=function() return false end
AF.db={manualAvailabilityMode=AF.AVAILABILITY_CURRENT,rememberManualAvailability=false}
AF:EnsureDB()
assert(AF.db.rememberManualAvailability,"Forever migrates to remembering availability")
assert(AF:GetInitialFlavorAvailabilityMode()==AF.AVAILABILITY_CURRENT)
AF:SetAvailabilityMode(AF.AVAILABILITY_ACCOUNT,true)
AF.availabilityMode=nil
AF:SetAvailabilityMode(AF:GetInitialFlavorAvailabilityMode(),true)
assert(AF:GetAvailabilityMode()==AF.AVAILABILITY_ACCOUNT,"manual availability survives reload")
AF:SetAvailabilityMode(AF.AVAILABILITY_UNAVAILABLE,true)
assert(AF:GetInitialFlavorAvailabilityMode()==AF.AVAILABILITY_UNAVAILABLE,"explicit off persists too")
AF.db.rememberManualAvailability=false AF:EnsureDB()
assert(not AF.db.rememberManualAvailability,"subsequent explicit opt-out respected")
C_PartyInfo={IsDelveInProgress=function() return true end}
local inside,kind=false,"none"
IsInInstance=function() return inside,kind end
GetChannelList=function() return 1,"General - Stormwind City",false,2,"Trade - English",false end
AF.db.autoAvailability=true AF.db.lastAvailabilityMode=AF.AVAILABILITY_CURRENT
assert(not AF:IsInUnavailableActivity(),"Retail delve stub cannot disable Forever cities")
assert(AF:GetInitialFlavorAvailabilityMode()==AF.AVAILABILITY_CURRENT,"capital login restores auto availability immediately")
AF:QueueAutoAvailabilityRefresh()
assert(AF:GetAvailabilityMode()==AF.AVAILABILITY_CURRENT,"deferred channel refresh enables city advertising")
inside=true kind="party"
assert(AF:GetInitialFlavorAvailabilityMode()==AF.AVAILABILITY_UNAVAILABLE,"dungeon auto exclusion remains effective")
AF:RefreshAutoAvailability(true)
assert(not AF:IsAvailable())
inside=false kind="none" AF:RefreshAutoAvailability(true)
assert(AF:IsAvailable(),"returning to capital re-enables availability")
GetChannelList=function() return 1,"General - Elwynn Forest",false end
EnumerateServerChannels=nil
assert(not AF:ShouldAutoBeAvailable(),"noncapital without Trade channel stays unavailable")
print("PASS Forever availability persistence, explicit off, opt-out, capital login/refresh and dungeon exclusions")
