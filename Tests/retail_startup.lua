-- Run from the addon root with lua5.1 Tests/retail_startup.lua.
-- Retail must retain order registration, startup and lazy panel attachment.
local AF, calls, registered, timers = {}, {}, {}, {}
assert(loadfile("Flavors/Retail.lua"))("ArtisanFinder",AF)
C_CraftingOrders = nil
Enum = {}
CreateFrame = function()
 return {
  RegisterEvent = function(_, event)
   registered[event] = true
  end,
  SetScript = function(frame, script, callback) frame[script] = callback end,
 }
end
C_Timer = {After = function(_, callback) timers[#timers+1] = callback end}
InCombatLockdown = function() return false end
local function load(path) assert(loadfile(path))('ArtisanFinder', AF) end
load('Core/Bootstrap.lua')
load('Core/Util.lua')
load('Core/Core.lua')
local initialize = {'InitializeComms','InitializeWhoStatus','InitializeGuild','InitializeMinimap','InitializeCustomerUI','InitializePreparationTracker','InitializeOrderNotifications','InitializeCrafterUI','InitializeSlashCommands','InitializeTradeChat','InitializeOptions','InitializeTutorial','InitializeEditMode','QueueChangelogPanel','CleanupCustomerCache','PrintDeprecatedScanWarning'}
for _, name in ipairs(initialize) do
 AF[name] = function() calls[name] = (calls[name] or 0)+1 end
end
AF.EnsureDB = function(self) self.db = self.db or {} end
AF.GetPlayerFullName = function() return 'Tester-Forever' end
AF.SelectActiveArtisanProfile = function(self, name) assert(name=='Tester-Forever') end
AF.Text = function(_, key) return key end
AF.Print = function() end
AF.DebugLog = function() end
AF.frame.OnEvent(AF.frame, 'ADDON_LOADED', 'ArtisanFinder')
AF.frame.OnEvent(AF.frame, 'PLAYER_LOGIN')
for _, name in ipairs(initialize) do
 if name ~= 'PrintDeprecatedScanWarning' then assert(calls[name] == 1, name..' must initialize once') end
end
assert(AF:GetAvailabilityMode() == AF.AVAILABILITY_UNAVAILABLE)
assert(registered.TRADE_SKILL_SHOW and registered.CHAT_MSG_CHANNEL and registered.CHAT_MSG_ADDON)
assert(registered.CRAFTINGORDERS_SHOW_CUSTOMER and registered.CRAFTINGORDERS_FULFILL_ORDER_RESPONSE)
local hooked=0
AF.InitializeCustomerOrderFormHook=function() hooked=hooked+1 end
AF.frame.OnEvent(AF.frame, 'ADDON_LOADED', 'Blizzard_ProfessionsCustomerOrders')
assert(hooked==1, 'Retail order panel lazy-load hook retained')
AF:SetAvailabilityMode(AF.AVAILABILITY_CURRENT, true)
assert(AF:IsAvailable() and AF:IsCurrentCharacterOnlyAvailable())
AF:SetAvailabilityMode(AF.AVAILABILITY_ACCOUNT, true)
assert(AF:IsAvailable() and not AF:IsCurrentCharacterOnlyAvailable())
AF:SetAvailabilityMode('invalid', true)
assert(not AF:IsAvailable())
local attached = 0
AF.AttachCrafterUI = function() attached=attached+1 end
AF.AttachCustomerUI=function() attached=attached+1 end
AF:TryAttachProfessionUIs()
assert(attached==2, "Retail attaches customer and crafter UIs")
for _, callback in ipairs(timers) do callback() end
assert(calls.PrintDeprecatedScanWarning==1)
assert(AF.PREFIX=='ARTFIND1' and AF.PROTOCOL_VERSION=='5', 'Retail protocol preserved')
print('PASS Retail core startup, order events, notifications/preparation initialization, lazy order-panel attachment and protocol')
