local _, AF = ...
AF.flavor = "Retail"
AF.IsRetail, AF.IsForever = true, false
AF.capabilities = { craftingOrders=true, recipeQuality=true, standaloneDirectory=false, nameplateIndicators=false }
-- Passive discovery is independent of the crafter availability policy.
AF.capabilities.passiveTradeDiscovery = false
AF.PREFIX = "ARTFIND1"
AF.PROTOCOL_VERSION = "5"
AF.CHANNEL_NAME = "ArtisanFinder"

-- Presentation and recipe-policy differences used by the shared crafter panel.
AF.crafterUIConfig = {}
