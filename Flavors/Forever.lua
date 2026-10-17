local _, AF = ...
AF.flavor = "Forever"
AF.IsRetail, AF.IsForever = false, true
AF.capabilities = { craftingOrders=false, recipeQuality=false, standaloneDirectory=true, nameplateIndicators=true }
-- Passive discovery is independent of the crafter availability policy.
AF.capabilities.passiveTradeDiscovery = true
AF.PREFIX = "ARTFINDFF1"
AF.PROTOCOL_VERSION = "FF1"
AF.CHANNEL_NAME = "ArtisanFinder"

-- Presentation and recipe-policy differences used by the shared crafter panel.
AF.crafterUIConfig = {allowCollapseDirtyItem=true,
    requireExplicitLearning=true,excludeNPCCrafting=true,collapseBesideCloseButton=true,highCollapseButton=true}
