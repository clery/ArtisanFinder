local _, AF = ...

local ICON = "Interface\\Icons\\INV_Inscription_Tradeskill01"
local ICON_COORDS = { 0.08, 0.92, 0.08, 0.92 }

local function OpenProfessionPanel()
	if C_AddOns and C_AddOns.LoadAddOn then
		pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
	end
	if ProfessionsFrame and ProfessionsFrame:IsShown() then
		AF:FocusCrafterUI()
	elseif ToggleProfessionsBook then
		ToggleProfessionsBook()
	elseif ProfessionsFrame then
		ShowUIPanel(ProfessionsFrame)
	end
	C_Timer.After(0.1, function()
		AF:FocusCrafterUI()
	end)
end

function AF:InitializeMinimap()
	if self.minimapInitialized then
		return
	end
	self.minimapInitialized = true

	if self.db.minimap.angle and self.db.minimap.minimapPos == nil then
		self.db.minimap.minimapPos = self.db.minimap.angle
	end
	if self.db.minimap.minimapPos == nil then
		self.db.minimap.minimapPos = 225
	end

	local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
	local icon = LibStub and LibStub("LibDBIcon-1.0", true)
	if not ldb or not icon then
		self:Print("minimap libraries were not available.")
		return
	end

	self.minimapBroker = ldb:NewDataObject("ArtisanFinder", {
		type = "data source",
		text = "ArtisanFinder",
		icon = ICON,
		iconCoords = ICON_COORDS,
		OnClick = function(_, button)
			if button == "LeftButton" then
				AF:ToggleAvailable()
			elseif button == "RightButton" then
				OpenProfessionPanel()
			end
		end,
		OnTooltipShow = function(tooltip)
			if not tooltip or not tooltip.AddLine then
				return
			end
			tooltip:AddLine("ArtisanFinder", 1, 0.82, 0)
			tooltip:AddLine(AF.available and "Available this session" or "Unavailable this session", AF.available and 0.1 or 1, AF.available and 1 or 0.25, 0.1)
			tooltip:AddLine("Scanned items: " .. AF:TableCount(AF.db.artisanProfile.items), 1, 1, 1)
			tooltip:AddLine(" ")
			tooltip:AddLine("Left-click: toggle availability", 0.65, 0.65, 0.65)
			tooltip:AddLine("Right-click: open profession panel", 0.65, 0.65, 0.65)
		end,
	})

	icon:Register("ArtisanFinder", self.minimapBroker, self.db.minimap)
	self.minimapIcon = icon
	self:RefreshMinimap()
end

function AF:RefreshMinimap()
	if not self.minimapBroker then
		return
	end

	local scanned = self:TableCount(self.db.artisanProfile.items)
	if scanned == 0 then
		self.minimapBroker.iconR = 0.65
		self.minimapBroker.iconG = 0.65
		self.minimapBroker.iconB = 0.65
	elseif self.available then
		self.minimapBroker.iconR = 0.3
		self.minimapBroker.iconG = 1
		self.minimapBroker.iconB = 0.3
	else
		self.minimapBroker.iconR = 1
		self.minimapBroker.iconG = 0.78
		self.minimapBroker.iconB = 0.25
	end

	if self.minimapIcon then
		self.minimapIcon:Refresh("ArtisanFinder", self.db.minimap)
	end
end
