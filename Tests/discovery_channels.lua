local AF={IsForever=true,CHANNEL_NAME="ArtisanFinder"}
local now, joins, leaves, swaps = 0,0,0,0
local channels={"ArtisanFinder","LinkedInnSync","CraftBoardF","RGamingAddonChan","General","Trade","LocalDefense","My Channel"}
local pending={}
local attached={"General","ArtisanFinder"}
local removals=0
C_Timer={After=function(delay,callback) pending[#pending+1]={at=now+delay,callback=callback} end}
local function advance(seconds)
    local finish=now+seconds
    while true do
        local first
        for index,timer in ipairs(pending) do
            if timer.at<=finish and (not first or timer.at<pending[first].at) then first=index end
        end
        if not first then break end
        local timer=table.remove(pending,first) now=timer.at timer.callback()
    end
    now=finish
end
GetChannelList=function()
    local out={} for index,name in ipairs(channels) do
        out[#out+1]=index out[#out+1]=name out[#out+1]=false
    end
    return unpack(out)
end
GetChannelName=function(name)
    for index,value in ipairs(channels) do if value==name then return index end end
    return 0
end
C_ChatInfo={SwapChatChannelsByChannelIndex=function(a,b)
    swaps=swaps+1 channels[a],channels[b]=channels[b],channels[a]
    -- Channel events may arrive during ordering.
    AF:MoveDiscoveryChannelsToEnd()
end}
LeaveChannelByName=function() leaves=leaves+1 end
JoinTemporaryChannel=function(name) joins=joins+1 end -- delayed server acknowledgement
JoinChannelByName=JoinTemporaryChannel
NUM_CHAT_WINDOWS=1
GetChatWindowChannels=function() return unpack(attached) end
RemoveChatWindowChannel=function(_,name)
    removals=removals+1
    for index=#attached,1,-1 do if attached[index]==name then table.remove(attached,index) end end
    AF:HideDiscoveryChannelFromChat()
end
assert(loadfile("Features/Social/Comms.lua"))("ArtisanFinder",AF)
AF.Now=function() return now end
AF.IsProtectedActionRestricted=function() return false end
AF.IsTradeChannelName=function(_,name) return name=="Trade" end
AF:QueueDiscoveryChannelJoin()
assert(table.concat(channels,",")=="General,Trade,LocalDefense,My Channel,ArtisanFinder,LinkedInnSync,CraftBoardF,RGamingAddonChan","all networks move to end, preserving other channels")
local before=swaps
for index=1,100 do AF:QueueDiscoveryChannelJoin() AF:GetDiscoveryChannelID() end
advance(20)
assert(leaves==0 and joins==0 and swaps==before,"already joined channels never churn")
assert(removals==1,"channel updates do not continually remove hidden channels")
-- A newly joined player channel is inserted before networks without rejoining.
channels[#channels+1]="Custom Two"
AF:MoveDiscoveryChannelsToEnd()
assert(channels[5]=="Custom Two" and channels[6]=="ArtisanFinder")
-- Missing channels share the same readiness/throttle across direct and queued calls.
channels={"General","Trade","My Channel"}
AF.discoveryVisibleChannelSignature=nil
AF:QueueDiscoveryChannelJoin(0)
advance(0)
assert(joins==0,"wait for normal channels to settle")
advance(5)
assert(joins==1,"join once after channels settle")
for index=1,100 do AF:GetDiscoveryChannelID() AF:EnsureDiscoveryNetworkChannel("ArtisanFinder",true) end
advance(24)
assert(joins==1,"pending joins are throttled for thirty seconds")
channels[#channels+1]="ArtisanFinder"
advance(10)
assert(joins==1 and leaves==0,"server acknowledgement ends retries without leaving")
-- Compatibility channels also wait for the normal channel list.
channels={}
assert(AF:EnsureDiscoveryNetworkChannel("LinkedInnSync")==0 and joins==1)
channels={"General","Trade"}
AF:EnsureDiscoveryNetworkChannel("LinkedInnSync")
advance(4)
AF:EnsureDiscoveryNetworkChannel("LinkedInnSync")
assert(joins==2)
AF:EnsureDiscoveryNetworkChannel("LinkedInnSync")
assert(joins==2)
print("PASS discovery channel ordering, no rejoin loop, shared join throttle and idempotent chat hiding")
