local AF = {}
local LoadFile = rawget(_G, "loadfile")

local function Check(condition, message)
	if not condition then
		error(message or "check failed", 2)
	end
end

local function LoadAddonFile(path)
	local chunk, err = LoadFile(path)
	Check(chunk, err)
	return chunk("ArtisanFinder", AF)
end

local timers = {}
local function RunTimers(count)
	for _ = 1, count do
		local callback = table.remove(timers, 1)
		if not callback then
			return
		end
		callback()
	end
end

local ordersFrameShown = false
local channeling = false
local listMyOrdersCalls = 0
local getMyOrdersCalls = 0
local pendingOrderCallback

_G.C_Timer = {
	After = function(_, callback)
		table.insert(timers, callback)
	end,
}
_G.C_FunctionContainers = {
	CreateCallback = function(callback)
		return callback
	end,
}
_G.C_CraftingOrders = {
	ListMyOrders = function(request)
		listMyOrdersCalls = listMyOrdersCalls + 1
		pendingOrderCallback = request.callback
	end,
	GetMyOrders = function()
		getMyOrdersCalls = getMyOrdersCalls + 1
		return {}
	end,
}
_G.Enum = {
	CraftingOrderResult = {
		Ok = 0,
		MissingNpc = 32,
	},
	CraftingOrderSortType = {
		ItemName = 1,
		TimeRemaining = 2,
	},
}
_G.ProfessionsCustomerOrdersFrame = {
	IsShown = function()
		return ordersFrameShown
	end,
}
_G.UnitCastingInfo = function()
	return nil
end
_G.UnitChannelInfo = function(unit)
	if unit == "player" and channeling then
		return "Fire Breath"
	end
	return nil
end
_G.issecretvalue = function(value)
	return type(value) == "table" and value.secret == true
end

AF.db = {
	customerOrderStates = {},
}
AF.DebugLog = function()
end
AF.Text = function(_, key)
	return key
end
AF.IsProtectedActionRestricted = function()
	return false
end

LoadAddonFile("Core/Util.lua")
LoadAddonFile("Features/Orders/Notifications.lua")

AF:QueueCustomerOrderStateRefresh("craftingorders_can_request", 0)
RunTimers(1)
Check(listMyOrdersCalls == 0, "can-request event queued customer state ListMyOrders")

AF:QueueCustomerOrderStateRefresh("init", 0)
RunTimers(1)
Check(listMyOrdersCalls == 0, "closed customer orders UI queued customer state ListMyOrders")

ordersFrameShown = true
channeling = true
AF:QueueCustomerOrderStateRefresh("show-customer", 0)
RunTimers(1)
Check(listMyOrdersCalls == 0, "active player channel queued customer state ListMyOrders")
Check(#timers == 1, "active player channel did not defer customer state refresh")

channeling = false
RunTimers(1)
Check(listMyOrdersCalls == 1, "deferred customer state refresh did not run after channel")
Check(type(pendingOrderCallback) == "function", "customer state refresh did not create callback")
pendingOrderCallback(Enum.CraftingOrderResult.Ok, false)
Check(getMyOrdersCalls == 1, "customer state refresh callback did not read orders after safe callback")

channeling = false
AF:RefreshCustomerOrderStates("show-customer")
Check(listMyOrdersCalls == 2, "direct customer state refresh did not request when safe")
channeling = true
local timersBeforeCallback = #timers
pendingOrderCallback(Enum.CraftingOrderResult.Ok, false)
Check(getMyOrdersCalls == 1, "customer state callback read orders during active player channel")
Check(#timers == timersBeforeCallback + 1, "customer state callback did not defer while player channel active")

print("customer_order_state_refresh: ok")
