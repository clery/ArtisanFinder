local _, AF = ...

local TOAST_DEFAULT_POSITION = { point = "TOP", x = 0, y = -170 }
local MINIMAP_DEFAULT_POSITION = { point = "CENTER", x = -180, y = -120 }

local function GetLibEditMode()
	return LibStub and LibStub("LibEditMode", true)
end

local function GetEditModeAccountSettings()
	return EditModeManagerFrame and EditModeManagerFrame.AccountSettings
end

local function GetToastDefault()
	return {
		point = TOAST_DEFAULT_POSITION.point,
		x = TOAST_DEFAULT_POSITION.x,
		y = TOAST_DEFAULT_POSITION.y,
	}
end

local function GetMinimapDefault()
	return {
		point = MINIMAP_DEFAULT_POSITION.point,
		x = MINIMAP_DEFAULT_POSITION.x,
		y = MINIMAP_DEFAULT_POSITION.y,
	}
end

local function WrapSelectionVisibility(frame, enabledGetter)
	local lib = GetLibEditMode()
	local selection = lib and lib.frameSelections and lib.frameSelections[frame]
	if not selection or selection.artisanFinderVisibilityWrapped then
		return
	end
	selection.artisanFinderVisibilityWrapped = true
	local showHighlighted = selection.ShowHighlighted
	selection.ShowHighlighted = function(self, ...)
		if enabledGetter() then
			return showHighlighted(self, ...)
		end
		self.isSelected = false
		self:Hide()
	end
	local showSelected = selection.ShowSelected
	selection.ShowSelected = function(self, ...)
		if enabledGetter() then
			return showSelected(self, ...)
		end
		self.isSelected = false
		self:Hide()
	end
end

local function RefreshSelectionVisibility(frame, enabled)
	local lib = GetLibEditMode()
	local selection = lib and lib.frameSelections and lib.frameSelections[frame]
	if not selection then
		return
	end
	if enabled then
		if lib:IsInEditMode() then
			selection:ShowHighlighted()
		end
	else
		frame:SetMovable(false)
		selection.isSelected = false
		selection:Hide()
	end
end

local function CreateAccountSettingsCheckButton(parent, label, x, y, callback)
	local checkButton = CreateFrame("Frame", nil, parent, "EditModeCheckButtonTemplate")
	checkButton:SetSize(215, 32)
	checkButton:SetPoint("TOPLEFT", x, y)
	checkButton:SetLabelText(label)
	checkButton:SetCallback(callback)
	return checkButton
end

local function CreateSliderSetting(name, desc, defaultValue, minValue, maxValue, step, getter, setter, formatter)
	return {
		name = name,
		desc = desc,
		kind = Enum.EditModeSettingDisplayType.Slider,
		default = defaultValue,
		get = function()
			return getter()
		end,
		set = function(_, value)
			setter(value)
		end,
		minValue = minValue,
		maxValue = maxValue,
		valueStep = step,
		formatter = formatter,
	}
end

local function CreateDropdownSetting(name, desc, defaultValue, values, getter, setter)
	return {
		name = name,
		desc = desc,
		kind = Enum.EditModeSettingDisplayType.Dropdown,
		default = defaultValue,
		values = values,
		get = function()
			return getter()
		end,
		set = function(_, value)
			setter(value)
		end,
	}
end

function AF:IsOrderToastEditModeVisible()
	return not self.db or self.db.editModeShowOrderToast ~= false
end

function AF:IsStandaloneButtonEditModeVisible()
	return not self.db or self.db.editModeShowStandaloneButton ~= false
end

function AF:RegisterOrderNotificationEditModeFrame(lib)
	local anchor = self:GetOrderNotificationAnchor()
	if anchor.artisanFinderEditModeRegistered then
		return
	end
	anchor.artisanFinderEditModeRegistered = true
	lib:AddFrame(anchor, function(_, _, point, x, y)
		AF:SetOrderNotificationAnchorPosition(point, x, y)
	end, GetToastDefault(), self:Text("EDITMODE_ORDER_TOAST"))
	WrapSelectionVisibility(anchor, function()
		return AF:IsOrderToastEditModeVisible()
	end)
	lib:AddFrameSettings(anchor, {
		CreateSliderSetting(
			self:Text("EDITMODE_TOAST_SCALE"),
			self:Text("EDITMODE_TOAST_SCALE_DESC"),
			1,
			0.75,
			1.5,
			0.05,
			function()
				return AF:GetOrderNotificationScale()
			end,
			function(value)
				AF:SetOrderNotificationScale(value)
			end,
			function(value)
				return string.format("%d%%", math.floor((tonumber(value) or 1) * 100 + 0.5))
			end
		),
		CreateDropdownSetting(
			self:Text("EDITMODE_TOAST_GROW_DIRECTION"),
			self:Text("EDITMODE_TOAST_GROW_DIRECTION_DESC"),
			"DOWN",
			{
				{ text = self:Text("EDITMODE_GROW_DOWN"), value = "DOWN" },
				{ text = self:Text("EDITMODE_GROW_UP"), value = "UP" },
			},
			function()
				return AF:GetOrderNotificationGrowDirection()
			end,
			function(value)
				AF:SetOrderNotificationGrowDirection(value)
			end
		),
	})
end

function AF:RegisterStandaloneMinimapEditModeFrame(lib)
	local button = self:GetStandaloneMinimapButton()
	if not button or button.artisanFinderEditModeRegistered then
		return
	end
	button.artisanFinderEditModeRegistered = true
	button.editModeName = self:Text("EDITMODE_STANDALONE_BUTTON")
	lib:AddFrame(button, function(_, _, point, x, y)
		AF.db.minimap.standalonePoint = point or "CENTER"
		AF.db.minimap.standaloneX = math.floor((tonumber(x) or 0) + 0.5)
		AF.db.minimap.standaloneY = math.floor((tonumber(y) or 0) + 0.5)
		AF:PositionStandaloneMinimapButton()
	end, GetMinimapDefault(), self:Text("EDITMODE_STANDALONE_BUTTON"))
	WrapSelectionVisibility(button, function()
		return AF:IsStandaloneButtonEditModeVisible()
	end)
end

function AF:RefreshEditModeVisibility()
	RefreshSelectionVisibility(self:GetOrderNotificationAnchor(), self:IsOrderToastEditModeVisible())
	local button = self:GetStandaloneMinimapButton()
	if button then
		RefreshSelectionVisibility(button, self:IsStandaloneButtonEditModeVisible())
	end
end

function AF:RefreshEditModeAccountSettings()
	local section = self.editModeAccountSettingsSection
	if not section then
		return
	end
	section.OrderToast:SetControlChecked(self:IsOrderToastEditModeVisible())
	section.StandaloneButton:SetControlChecked(self:IsStandaloneButtonEditModeVisible())
end

function AF:CreateEditModeAccountSettingsSection(accountSettings)
	if self.editModeAccountSettingsSection or not accountSettings or not accountSettings.SettingsContainer then
		return
	end
	local scrollChild = accountSettings.SettingsContainer.ScrollChild
	if not scrollChild then
		return
	end
	local section = CreateFrame("Frame", "ArtisanFinderEditModeAccountSettings", scrollChild)
	section:SetSize(450, 86)
	section.fixedWidth = 450
	section.fixedHeight = 86
	section.layoutIndex = 99

	section.Title = section:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	section.Title:SetPoint("TOPLEFT", 5, -6)
	section.Title:SetText(self:Text("EDITMODE_ARTISANFINDER_SECTION"))

	section.OrderToast = CreateAccountSettingsCheckButton(section, self:Text("EDITMODE_SHOW_ORDER_TOAST"), 0, -34, function(checked)
		AF.db.editModeShowOrderToast = not not checked
		AF:RefreshEditModeVisibility()
	end)
	section.StandaloneButton = CreateAccountSettingsCheckButton(section, self:Text("EDITMODE_SHOW_STANDALONE_BUTTON"), 225, -34, function(checked)
		AF.db.editModeShowStandaloneButton = not not checked
		AF:RefreshEditModeVisibility()
	end)

	self.editModeAccountSettingsSection = section
	self:RefreshEditModeAccountSettings()
	if accountSettings.LayoutSettings and not self.editModeAccountSettingsLayouting then
		self.editModeAccountSettingsLayouting = true
		accountSettings:LayoutSettings()
		self.editModeAccountSettingsLayouting = nil
	end
end

function AF:InitializeEditModeAccountSettings()
	if self.editModeAccountSettingsInitialized then
		return
	end
	self.editModeAccountSettingsInitialized = true
	local accountSettings = GetEditModeAccountSettings()
	self:CreateEditModeAccountSettingsSection(accountSettings)
	if EditModeAccountSettingsMixin and EditModeAccountSettingsMixin.LayoutSettings then
		hooksecurefunc(EditModeAccountSettingsMixin, "LayoutSettings", function(settings)
			AF:CreateEditModeAccountSettingsSection(settings)
			AF:RefreshEditModeAccountSettings()
		end)
	end
	if accountSettings then
		accountSettings:HookScript("OnShow", function()
			AF:CreateEditModeAccountSettingsSection(accountSettings)
			AF:RefreshEditModeAccountSettings()
		end)
	end
end

function AF:InitializeEditMode()
	if self.editModeInitialized then
		return
	end
	local lib = GetLibEditMode()
	if not lib then
		return
	end
	self.editModeInitialized = true
	self:RegisterOrderNotificationEditModeFrame(lib)
	self:RegisterStandaloneMinimapEditModeFrame(lib)
	self:InitializeEditModeAccountSettings()
	lib:RegisterCallback("enter", function()
		AF:RefreshEditModeVisibility()
	end)
end
