local _, AF = ...

local TOAST_DEFAULT_POSITION = { point = "TOP", x = 0, y = -170 }
local MINIMAP_DEFAULT_POSITION = { point = "CENTER", x = -180, y = -120 }

local function GetLibEditMode()
	return LibStub and LibStub("LibEditMode", true)
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

local function CreateSliderSetting(name, desc, defaultValue, minValue, maxValue, step, getter, setter, formatter, editableValue)
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
		editableValue = editableValue ~= false,
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

local function FormatPercent(value)
	return string.format("%d%%", math.floor((tonumber(value) or 1) * 100 + 0.5))
end

local function HideReadOnlySliderEditBoxes(dialog)
	for _, widget in next, dialog.Settings.widgets or {} do
		if widget.setting and widget.setting.editableValue == false and widget.EditBox then
			widget.EditBox:Hide()
		end
	end
end

local function PatchReadOnlySliderValues(lib)
	local dialog = lib.internal and lib.internal.dialog
	if not dialog or dialog.artisanFinderReadOnlySliderValuesPatched then
		return
	end
	dialog.artisanFinderReadOnlySliderValuesPatched = true
	local updateSettings = dialog.UpdateSettings
	dialog.UpdateSettings = function(self, ...)
		local result = updateSettings(self, ...)
		HideReadOnlySliderEditBoxes(self)
		return result
	end
	local refreshWidgets = dialog.RefreshWidgets
	dialog.RefreshWidgets = function(self, ...)
		local result = refreshWidgets(self, ...)
		HideReadOnlySliderEditBoxes(self)
		return result
	end
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
			FormatPercent,
			false
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
	lib:AddFrameSettings(button, {
		CreateSliderSetting(
			self:Text("EDITMODE_STANDALONE_SCALE"),
			self:Text("EDITMODE_STANDALONE_SCALE_DESC"),
			1,
			0.5,
			3,
			0.05,
			function()
				return AF:GetStandaloneMinimapScale()
			end,
			function(value)
				AF:SetStandaloneMinimapScale(value)
			end,
			FormatPercent,
			false
		),
	})
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
	PatchReadOnlySliderValues(lib)
end
