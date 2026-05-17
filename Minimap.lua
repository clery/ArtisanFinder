local _, AF = ...

local ICON = "Interface\\AddOns\\ArtisanFinder\\Images\\MinimapIcon.tga"
local ICON_COORDS = { 0, 1, 0, 1 }

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
		self:Print(self:Text("MINIMAP_LIBS_MISSING"))
		return
	end

	self.minimapBroker = ldb:NewDataObject("ArtisanFinder", {
		type = "data source",
		text = "ArtisanFinder",
		icon = ICON,
		iconCoords = ICON_COORDS,
		OnClick = function(_, button)
			if IsShiftKeyDown() then
				AF:SetMinimapHidden(true)
			elseif button == "LeftButton" then
				AF:ToggleAvailable()
			elseif button == "MiddleButton" then
				AF:ToggleAutoAvailability()
			elseif button == "RightButton" then
				OpenProfessionPanel()
			end
		end,
		OnTooltipShow = function(tooltip)
			if not tooltip or not tooltip.AddLine then
				return
			end
			tooltip:AddLine("ArtisanFinder", 1, 0.82, 0)
			tooltip:AddLine(AF.available and AF:Text("MINIMAP_AVAILABLE") or AF:Text("MINIMAP_UNAVAILABLE"), AF.available and 0.1 or 1, AF.available and 1 or 0.25, 0.1)
			tooltip:AddLine(AF:Text("MINIMAP_AUTO_AVAILABILITY", AF.db.autoAvailability and AF:Text("ENABLED") or AF:Text("DISABLED")), 1, 1, 1)
			if AF.db.autoAvailability then
				tooltip:AddLine(AF:Text("MINIMAP_AUTO_HINT"), 0.65, 0.65, 0.65, true)
			end
			tooltip:AddLine(AF:Text("MINIMAP_SCANNED", AF:TableCount(AF.db.artisanProfile.items)), 1, 1, 1)
			tooltip:AddLine(" ")
			tooltip:AddLine(AF:Text("MINIMAP_LEFT_CLICK"), 0.65, 0.65, 0.65)
			tooltip:AddLine(AF:Text("MINIMAP_MIDDLE_CLICK"), 0.65, 0.65, 0.65)
			tooltip:AddLine(AF:Text("MINIMAP_RIGHT_CLICK"), 0.65, 0.65, 0.65)
			tooltip:AddLine(AF:Text("MINIMAP_SHIFT_CLICK"), 0.65, 0.65, 0.65)
		end,
	})

	icon:Register("ArtisanFinder", self.minimapBroker, self.db.minimap)
	self.minimapIcon = icon
	self:StyleMinimapButton()
	self:RefreshMinimap()
end

function AF:StyleMinimapButton()
	if not self.minimapIcon then
		return
	end
	self.minimapIcon:RemoveButtonBorder("ArtisanFinder")
	self.minimapIcon:RemoveButtonBackground("ArtisanFinder")
	self.minimapIcon:SetButtonIcon("ArtisanFinder", ICON, 31, "CENTER", 0, 0)
	local button = self.minimapIcon:GetMinimapButton("ArtisanFinder")
	if button then
		button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
		local highlight = button:GetHighlightTexture()
		if highlight then
			highlight:SetAlpha(0)
		end
		if not button.artisanFinderHoverStyled then
			button.artisanFinderHoverStyled = true
			button:HookScript("OnEnter", function(self)
				if self.icon then
					self.icon:SetVertexColor(1, 0.95, 0.72)
					self.icon:SetScale(1.06)
				end
			end)
			button:HookScript("OnLeave", function(self)
				if self.icon then
					self.icon:SetVertexColor(1, 1, 1)
					self.icon:SetScale(1)
				end
			end)
		end
	end
end

function AF:SetMinimapHidden(hidden)
	self.db.minimap.hide = hidden == true
	if self.minimapIcon then
		if self.db.minimap.hide then
			self.minimapIcon:Hide("ArtisanFinder")
		else
			self.minimapIcon:Show("ArtisanFinder")
		end
	end
	if self.RefreshOptionsPanel then
		self:RefreshOptionsPanel()
	end
end

function AF:RefreshMinimap()
	if not self.minimapBroker then
		return
	end

	self.minimapBroker.iconR = 1
	self.minimapBroker.iconG = 1
	self.minimapBroker.iconB = 1

	if self.minimapIcon then
		self.minimapIcon:Refresh("ArtisanFinder", self.db.minimap)
		self:StyleMinimapButton()
		if self.db.minimap.hide then
			self.minimapIcon:Hide("ArtisanFinder")
		else
			self.minimapIcon:Show("ArtisanFinder")
		end
	end
end
