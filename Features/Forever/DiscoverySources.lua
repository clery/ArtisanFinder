local _, AF = ...
local labels={ADDON="FOREVER_SOURCE_ADDON",TRADE="FOREVER_SOURCE_TRADE",GUILD="FOREVER_SOURCE_GUILD"}
local addonNames={LINKEDINN="Linked Inn",CRAFTBOARD="CraftBoard",RELEASEGAMING="Release Gaming"}
local priority={"ADDON","LINKEDINN","CRAFTBOARD","RELEASEGAMING","GUILD","TRADE"}

function AF:GetForeverDiscoverySource(entry)
    if entry.thirdPartySource then return entry.thirdPartySource end
    if entry.guildDiscovery then return "GUILD" end
    if entry.linkedInn then return "LINKEDINN" end
    return entry.tradeLead and "TRADE" or "ADDON"
end
function AF:GetForeverDiscoverySourceLabel(source)
    return addonNames[source] or self:Text(labels[source] or labels.ADDON)
end
function AF:GetPreferredForeverDiscoverySource(sources)
    for _,source in ipairs(priority) do if sources[source] then return source end end
    return "TRADE"
end
