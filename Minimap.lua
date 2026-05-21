local _, AF = ...

local ICON = 7548932 -- inv-12-profession-blacksmithing-repairhammer-purple
local ICON_COORDS = { 0, 1, 0, 1 }

local function OpenProfessionPanel()
	pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
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

function AF:PopulateMinimapTooltip(tooltip)
	if not tooltip or not tooltip.AddLine then
		return
	end
	tooltip:AddLine("ArtisanFinder", 1, 0.82, 0)
	tooltip:AddLine(AF.available and AF:Text("MINIMAP_AVAILABLE") or AF:Text("MINIMAP_UNAVAILABLE"), AF.available and 0.1 or 1, AF.available and 1 or 0.25, 0.1)
	tooltip:AddLine(AF:Text("MINIMAP_AUTO_AVAILABILITY", AF.db.autoAvailability and AF:Text("ENABLED") or AF:Text("DISABLED")), 1, 1, 1)
	if AF.db.autoAvailability then
		tooltip:AddLine(AF:Text("MINIMAP_AUTO_HINT"), 0.65, 0.65, 0.65, true)
	end
	local professionRows = AF:GetAdvertisingProfessionRows()
	if #professionRows > 0 then
		local currentCharacter
		for _, row in ipairs(professionRows) do
			if row.characterName ~= currentCharacter then
				currentCharacter = row.characterName
				tooltip:AddLine(AF:GetDisplayPlayerName(currentCharacter), 1, 0.82, 0)
			end
			local icon = AF:GetProfessionIconMarkup(row.professionID, row, 14) or ""
			local text = AF:Text("MINIMAP_PROFESSION_SCANNED", row.professionName, row.count)
			if icon ~= "" then
				text = icon .. " " .. text
			end
			if row.advertised then
				tooltip:AddLine("  " .. text, 1, 1, 1)
			else
				tooltip:AddLine("  " .. text .. " |cff888888(" .. AF:Text("MINIMAP_NOT_ADVERTISED") .. ")|r", 0.65, 0.65, 0.65)
			end
		end
	else
		tooltip:AddLine(AF:Text("MINIMAP_SCANNED", 0), 1, 1, 1)
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(AF:Text("MINIMAP_LEFT_CLICK"), 0.65, 0.65, 0.65)
	tooltip:AddLine(AF:Text("MINIMAP_MIDDLE_CLICK"), 0.65, 0.65, 0.65)
	tooltip:AddLine(AF:Text("MINIMAP_RIGHT_CLICK"), 0.65, 0.65, 0.65)
	tooltip:AddLine(AF:Text("MINIMAP_SHIFT_CLICK"), 0.65, 0.65, 0.65)
end

function AF:RefreshOpenMinimapTooltip()
	local tooltip = _G.LibDBIconTooltip
	if not self.minimapTooltipShown or not tooltip or not tooltip:IsShown() or not tooltip.ClearLines then
		return
	end
	local owner = tooltip.GetOwner and tooltip:GetOwner()
	local ownerName = owner and owner.GetName and owner:GetName()
	if ownerName and ownerName ~= "LibDBIcon10_ArtisanFinder" then
		return
	end
	tooltip:ClearLines()
	self:PopulateMinimapTooltip(tooltip)
	tooltip:Show()
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
			AF.minimapTooltipShown = true
			AF:PopulateMinimapTooltip(tooltip)
		end,
		OnLeave = function()
			AF.minimapTooltipShown = false
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
	self.minimapIcon:ResetButtonBorder("ArtisanFinder")
	self.minimapIcon:ResetButtonBackground("ArtisanFinder")
	self.minimapIcon:ResetButtonHighlightTexture("ArtisanFinder")
	self.minimapIcon:SetButtonIcon("ArtisanFinder", ICON, 18, "CENTER", 0, 0)
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
	self:RefreshOpenMinimapTooltip()
end
