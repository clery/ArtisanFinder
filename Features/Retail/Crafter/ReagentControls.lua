local _, AF = ...

local function ReagentMatches(left, right)
	if not left or not right then
		return false
	end
	if ProfessionsUtil and ProfessionsUtil.CraftingReagentMatches then
		return ProfessionsUtil.CraftingReagentMatches(left, right)
	end
	if left.itemID and right.itemID then
		return tonumber(left.itemID) == tonumber(right.itemID)
	end
	if left.currencyID and right.currencyID then
		return tonumber(left.currencyID) == tonumber(right.currencyID)
	end
	return false
end

local function GetReagentQuantityRequired(slot, reagent)
	for _, variableQuantity in ipairs(slot and slot.variableQuantities or {}) do
		if ReagentMatches(variableQuantity.reagent, reagent) then
			return tonumber(variableQuantity.quantity) or tonumber(slot.quantityRequired) or 1
		end
	end
	return tonumber(slot and slot.quantityRequired) or 1
end

local function IsBasicReagentSlot(slot)
	return slot
		and Enum
		and Enum.CraftingReagentType
		and slot.reagentType == Enum.CraftingReagentType.Basic
end

local function IsBasicQualityReagentSlot(slot)
	return IsBasicReagentSlot(slot)
		and Professions
		and Professions.ReagentInputMode
		and Professions.GetReagentInputMode
		and Professions.GetReagentInputMode(slot) == Professions.ReagentInputMode.Quality
end

local function IsUnlimitedSelectableReagentSlot(slot)
	if not slot or not Enum or not Enum.CraftingReagentType or not Enum.TradeskillSlotDataType then
		return false
	end
	if slot.dataSlotType ~= Enum.TradeskillSlotDataType.ModifiedReagent then
		return false
	end
	if IsBasicReagentSlot(slot) then
		return false
	end

	local reagentType = slot.reagentType
	local craftingReagentType = Enum.CraftingReagentType
	local isRequiredModifying = ProfessionsUtil
		and ProfessionsUtil.IsReagentSlotModifyingRequired
		and ProfessionsUtil.IsReagentSlotModifyingRequired(slot)
	return isRequiredModifying == true
		or reagentType == craftingReagentType.Modifying
		or reagentType == rawget(craftingReagentType, "Optional")
		or reagentType == craftingReagentType.Finishing
end

local function ReagentBelongsToSlot(slot, reagent)
	for _, slotReagent in ipairs(slot and slot.reagents or {}) do
		if ReagentMatches(slotReagent, reagent) then
			return true
		end
	end
	return false
end

local function GetUnlimitedReagentForSlot(slot, useBestQuality)
	local reagents = type(slot and slot.reagents) == "table" and slot.reagents or nil
	if not reagents then
		return nil
	end
	local startIndex = useBestQuality and #reagents or 1
	local endIndex = useBestQuality and 1 or #reagents
	local step = useBestQuality and -1 or 1
	for reagentIndex = startIndex, endIndex, step do
		local reagent = reagents[reagentIndex]
		if type(reagent) == "table" and (reagent.itemID or reagent.currencyID) then
			return reagent
		end
	end
	return nil
end

local function SetCheckboxText(check, text)
	local fontString = check and (check.Text or check.text)
	if fontString then
		fontString:SetText(text)
		fontString:Show()
	end
end

local function PositionUnlimitedReagentsCheckbox(form, check)
	local nativeCheck = form and form.AllocateBestQualityCheckbox
	if not nativeCheck or not check then
		return
	end

	local nativeText = nativeCheck.Text or nativeCheck.text
	check:ClearAllPoints()
	if nativeText then
		check:SetPoint("LEFT", nativeText, "RIGHT", 12, 0)
	else
		check:SetPoint("LEFT", nativeCheck, "RIGHT", 160, 0)
	end
end

local function ClampWholeNumber(value, minimum, maximum)
	value = math.floor(tonumber(value) or 0)
	if minimum and value < minimum then
		value = minimum
	end
	if maximum and value > maximum then
		value = maximum
	end
	return value
end


function AF:EnsureUnlimitedReagentsCheckbox(form)
	form = form or self:GetCraftingSchematicForm()
	if not form or not form.AllocateBestQualityCheckbox then
		return nil
	end
	if form.ArtisanFinderUnlimitedReagentsCheckbox then
		return form.ArtisanFinderUnlimitedReagentsCheckbox
	end

	local check = CreateFrame("CheckButton", nil, form, "UICheckButtonTemplate")
	check:SetSize(26, 26)
	PositionUnlimitedReagentsCheckbox(form, check)
	check:SetFrameLevel((form.AllocateBestQualityCheckbox:GetFrameLevel() or form:GetFrameLevel() or 0) + 1)
	SetCheckboxText(check, LIGHTGRAY_FONT_COLOR:WrapTextInColorCode(self:Text("PROFESSION_PANEL_UNLIMITED_REAGENTS")))
	check:SetScript("OnClick", function(button)
		AF:SetUnlimitedReagentsEnabled(button:GetChecked() == true)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end)
	check:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:SetText(AF:Text("PROFESSION_PANEL_UNLIMITED_REAGENTS"), 1, 0.82, 0)
		GameTooltip:AddLine(AF:Text("PROFESSION_PANEL_UNLIMITED_REAGENTS_TOOLTIP"), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	check:SetScript("OnLeave", GameTooltip_Hide)
	check:Hide()

	form.ArtisanFinderUnlimitedReagentsCheckbox = check
	return check
end

function AF:IsUnlimitedReagentsEnabled()
	return self.db and self.db.unlimitedReagents == true
end

function AF:IsUnlimitedReagentFlyoutContextActive(context)
	if not context or not self:IsUnlimitedReagentsEnabled() or not self:IsOwnProfessionWindowOpen() then
		return false
	end
	local transaction = context.transaction
	if not transaction or transaction.IsRecraft and transaction:IsRecraft() then
		return false
	end
	local slot = context.reagentSlotSchematic
	if not IsUnlimitedSelectableReagentSlot(slot) then
		return false
	end
	local form = self:GetCraftingSchematicForm()
	local formTransaction = form and form.GetTransaction and form:GetTransaction()
	return formTransaction == nil or formTransaction == transaction
end

function AF:GetUnlimitedReagentQuantityOverride(reagent)
	local context = self.professionUnlimitedReagentQuantityContext
	if not reagent then
		return nil
	end
	if self:IsUnlimitedReagentFlyoutContextActive(context) then
		local slot = context.reagentSlotSchematic
		if ReagentBelongsToSlot(slot, reagent) then
			return GetReagentQuantityRequired(slot, reagent)
		end
	end

	if not self:IsUnlimitedReagentsEnabled() or not self:IsOwnProfessionWindowOpen() then
		return nil
	end
	local form = self:GetCraftingSchematicForm()
	local transaction = form and form.GetTransaction and form:GetTransaction()
	local schematic = transaction and transaction.GetRecipeSchematic and transaction:GetRecipeSchematic()
	if not transaction or type(schematic) ~= "table" or type(schematic.reagentSlotSchematics) ~= "table" then
		return nil
	end
	if transaction.IsRecraft and transaction:IsRecraft() then
		return nil
	end

	for _, slot in ipairs(schematic.reagentSlotSchematics) do
		if IsUnlimitedSelectableReagentSlot(slot) and ReagentBelongsToSlot(slot, reagent) then
			return GetReagentQuantityRequired(slot, reagent)
		end
	end
	return nil
end

function AF:CallWithUnlimitedReagentQuantityContext(context, callback, ...)
	local previous = self.professionUnlimitedReagentQuantityContext
	self.professionUnlimitedReagentQuantityContext = context
	local ok, result = pcall(callback, ...)
	self.professionUnlimitedReagentQuantityContext = previous
	if not ok then
		error(result, 0)
	end
	return result
end

function AF:CallWithUnlimitedReagentPopupContext(context, callback, ...)
	local previous = self.professionUnlimitedReagentPopupContext
	self.professionUnlimitedReagentPopupContext = context
	local ok, result = pcall(callback, ...)
	self.professionUnlimitedReagentPopupContext = previous
	if not ok then
		error(result, 0)
	end
	return result
end

function AF:SyncUnlimitedReagentExemptions(transaction)
	if not transaction or not transaction.ClearExemptedReagents or not transaction.SetExemptedReagent then
		return
	end
	if transaction.IsRecraft and transaction:IsRecraft() then
		return
	end

	transaction:ClearExemptedReagents()
	if not self:IsUnlimitedReagentsEnabled() then
		return
	end

	local schematic = transaction.GetRecipeSchematic and transaction:GetRecipeSchematic()
	for slotIndex, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
		if IsUnlimitedSelectableReagentSlot(slot) then
			local allocations = transaction.GetAllocations and transaction:GetAllocations(slotIndex)
			if allocations and allocations.Enumerate then
				for _, allocation in allocations:Enumerate() do
					local reagent = allocation.GetReagent and allocation:GetReagent()
					if reagent and ReagentBelongsToSlot(slot, reagent) then
						transaction:SetExemptedReagent(reagent, slot.dataSlotIndex)
					end
				end
			end
		end
	end
end

function AF:PrepareUnlimitedReagentSelection(context, reagent)
	if not reagent or not self:IsUnlimitedReagentFlyoutContextActive(context) then
		return
	end
	local slot = context.reagentSlotSchematic
	local transaction = context.transaction
	if not ReagentBelongsToSlot(slot, reagent) or not transaction or not transaction.SetExemptedReagent then
		return
	end
	transaction:SetExemptedReagent(reagent, slot.dataSlotIndex)
end

function AF:PatchUnlimitedReagentFlyoutBehavior(behavior, transaction, reagentSlotSchematic, slot)
	if not behavior or behavior.artisanFinderUnlimitedReagentsPatched then
		return behavior
	end

	local context = {
		transaction = transaction,
		reagentSlotSchematic = reagentSlotSchematic,
		slot = slot,
	}
	if not self:IsUnlimitedReagentFlyoutContextActive(context) then
		return behavior
	end

	behavior.artisanFinderUnlimitedReagentsPatched = true
	behavior.artisanFinderUnlimitedReagentsContext = context

	local originalGetUnownedFlags = behavior.GetUnownedFlags
	behavior.GetUnownedFlags = function(patchedBehavior)
		if AF:IsUnlimitedReagentFlyoutContextActive(context) then
			return true, true
		end
		return originalGetUnownedFlags(patchedBehavior)
	end

	behavior.PopulateDataProvider = function(_, dataProvider, elements)
		for _, item in ipairs(elements and elements.items or {}) do
			local reagent = Professions and Professions.CreateItemReagent and Professions.CreateItemReagent(item:GetItemID())
			dataProvider:Insert({
				item = item,
				reagent = reagent,
				forceAccumulateInventory = true,
				artisanFinderUnlimitedReagents = true,
				artisanFinderUnlimitedReagentsContext = context,
			})
		end
		for _, reagent in ipairs(elements and elements.currencyReagents or {}) do
			dataProvider:Insert({
				reagent = reagent,
				artisanFinderUnlimitedReagents = true,
				artisanFinderUnlimitedReagentsContext = context,
			})
		end
	end

	local originalOnElementEnter = behavior.OnElementEnter
	behavior.OnElementEnter = function(patchedBehavior, elementData, tooltip)
		if elementData and elementData.artisanFinderUnlimitedReagents and AF:IsUnlimitedReagentFlyoutContextActive(context) then
			return AF:CallWithUnlimitedReagentQuantityContext(context, originalOnElementEnter, patchedBehavior, elementData, tooltip)
		end
		return originalOnElementEnter(patchedBehavior, elementData, tooltip)
	end

	local originalIsElementEnabled = behavior.IsElementEnabled
	behavior.IsElementEnabled = function(patchedBehavior, elementData, count)
		if not elementData or not elementData.artisanFinderUnlimitedReagents or not AF:IsUnlimitedReagentFlyoutContextActive(context) then
			return originalIsElementEnabled(patchedBehavior, elementData, count)
		end

		local reagent = elementData.reagent
		local activeTransaction = context.transaction
		if not reagent or activeTransaction:HasAllocatedReagent(reagent) then
			return false
		end
		if activeTransaction.AreDependentReagentsAllocated and not activeTransaction:AreDependentReagentsAllocated(reagent) then
			return false
		end

		local recraftAllocation = activeTransaction.GetRecraftAllocation and activeTransaction:GetRecraftAllocation()
		if recraftAllocation and C_TradeSkillUI.IsRecraftReagentValid and not C_TradeSkillUI.IsRecraftReagentValid(recraftAllocation, reagent) then
			return false
		end

		return true
	end

	return behavior
end

function AF:PatchUnlimitedReagentReplacementPopup()
	if self.unlimitedReagentReplacementPopupHooked or not StaticPopup_Show then
		return
	end
	self.unlimitedReagentReplacementPopupHooked = true

	local function WrapReplacementCallback(which, _, _, data)
		if which == "PROFESSIONS_RECRAFT_REPLACE_OPTIONAL_REAGENT"
			and type(data) == "table"
			and type(data.callback) == "function"
			and not data.artisanFinderUnlimitedReagentsWrapped then
			local context = AF.professionUnlimitedReagentPopupContext
			local reagent = context and context.reagent
			if reagent and AF:IsUnlimitedReagentFlyoutContextActive(context) then
				local popupContext = {
					transaction = context.transaction,
					reagentSlotSchematic = context.reagentSlotSchematic,
					slot = context.slot,
				}
				local popupReagent = reagent
				local originalCallback = data.callback
				data.artisanFinderUnlimitedReagentsWrapped = true
				data.callback = function(...)
					AF:PrepareUnlimitedReagentSelection(popupContext, popupReagent)
					local result = AF:CallWithUnlimitedReagentQuantityContext(popupContext, originalCallback, ...)
					AF:SyncUnlimitedReagentExemptions(popupContext.transaction)
					AF:RefreshCraftingSchematicStats()
					return result
				end
			end
		end
	end

	hooksecurefunc("StaticPopup_Show", WrapReplacementCallback)
end

function AF:RefreshUnlimitedReagentFlyoutButton(button, elementData, behavior)
	if not button or not elementData or not elementData.artisanFinderUnlimitedReagents then
		return
	end
	local context = elementData.artisanFinderUnlimitedReagentsContext
	if not self:IsUnlimitedReagentFlyoutContextActive(context) then
		return
	end
	local quantity = GetReagentQuantityRequired(context.reagentSlotSchematic, elementData.reagent)
	if button.SetItemButtonCount then
		button:SetItemButtonCount(quantity)
	end
	if button.UpdateState then
		button:UpdateState(quantity, elementData, behavior)
	end
end

function AF:HookUnlimitedReagentFlyouts()
	if self.unlimitedReagentFlyoutsHooked then
		return
	end
	if not CreateProfessionsMCRFlyout or not ProfessionsUtil or not ProfessionsUtil.GetReagentQuantityInPossession then
		return
	end
	self.unlimitedReagentFlyoutsHooked = true

	-- Blizzard's reagent picker checks ownership inside local flyout and popup callbacks.
	-- Keep overrides scoped to the active crafting form and its unlimited-selectable slots.
	local originalGetReagentQuantity = ProfessionsUtil.GetReagentQuantityInPossession
	ProfessionsUtil.GetReagentQuantityInPossession = function(reagent, ...)
		local override = AF.GetUnlimitedReagentQuantityOverride and AF:GetUnlimitedReagentQuantityOverride(reagent)
		if override then
			return override
		end
		return originalGetReagentQuantity(reagent, ...)
	end

	local originalCreateProfessionsMCRFlyout = CreateProfessionsMCRFlyout
	CreateProfessionsMCRFlyout = function(transaction, reagentSlotSchematic, slot)
		local behavior = originalCreateProfessionsMCRFlyout(transaction, reagentSlotSchematic, slot)
		return AF:PatchUnlimitedReagentFlyoutBehavior(behavior, transaction, reagentSlotSchematic, slot)
	end
	self:PatchUnlimitedReagentReplacementPopup()

	if ProfessionsFlyoutItemButtonMixin and ProfessionsFlyoutItemButtonMixin.Init then
		hooksecurefunc(ProfessionsFlyoutItemButtonMixin, "Init", function(button, elementData, behavior)
			AF:RefreshUnlimitedReagentFlyoutButton(button, elementData, behavior)
		end)
	end
	if ProfessionsFlyoutCurrencyButtonMixin and ProfessionsFlyoutCurrencyButtonMixin.Init then
		hooksecurefunc(ProfessionsFlyoutCurrencyButtonMixin, "Init", function(button, elementData, behavior)
			AF:RefreshUnlimitedReagentFlyoutButton(button, elementData, behavior)
		end)
	end

	if ProfessionsFlyoutMixin and ProfessionsFlyoutMixin.TriggerEvent then
		local originalTriggerEvent = ProfessionsFlyoutMixin.TriggerEvent
		ProfessionsFlyoutMixin.TriggerEvent = function(flyout, event, ...)
			local flyoutSelf, elementData = ...
			local behavior = flyout and flyout.GetBehavior and flyout:GetBehavior()
			local context = behavior and behavior.artisanFinderUnlimitedReagentsContext
			if event == ProfessionsFlyoutMixin.Event.ItemSelected
				and flyoutSelf == flyout
				and elementData
				and elementData.artisanFinderUnlimitedReagents
				and AF:IsUnlimitedReagentFlyoutContextActive(context) then
				context.reagent = elementData.reagent
				AF:PrepareUnlimitedReagentSelection(context, context.reagent)
				local result = AF:CallWithUnlimitedReagentPopupContext(context, function(...)
					return AF:CallWithUnlimitedReagentQuantityContext(context, originalTriggerEvent, flyout, event, ...)
				end, ...)
				AF:SyncUnlimitedReagentExemptions(context.transaction)
				return result
			end
			return originalTriggerEvent(flyout, event, ...)
		end
	end
end

function AF:RefreshCraftingSchematicStats(form)
	form = form or self:GetCraftingSchematicForm()
	if form and form.UpdateDetailsStats then
		pcall(form.UpdateDetailsStats, form)
	end
	if form and form.UpdateOutputItem then
		pcall(form.UpdateOutputItem, form)
	end
	local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
	if page and page.ValidateControls then
		pcall(page.ValidateControls, page)
	end
end

function AF:RefreshCraftingQualityDialog(form)
	form = form or self:GetCraftingSchematicForm()
	local dialog = form and form.QualityDialog
	local transaction = form and form.GetTransaction and form:GetTransaction()
	if not dialog or not transaction or not dialog:IsShown() or not dialog.GetSlotIndex or not dialog.ReinitAllocations then
		return
	end

	local slotIndex = dialog:GetSlotIndex()
	if not slotIndex or not transaction.GetAllocationsCopy then
		return
	end
	local ok, allocations = pcall(transaction.GetAllocationsCopy, transaction, slotIndex)
	if ok and allocations then
		pcall(dialog.ReinitAllocations, dialog, allocations)
	end
end

function AF:IsUnlimitedReagentDialog(dialog)
	local form = self:GetCraftingSchematicForm()
	local slot = dialog and dialog.reagentSlotSchematic
	return self:IsUnlimitedReagentsEnabled()
		and self:IsOwnProfessionWindowOpen()
		and form
		and dialog == form.QualityDialog
		and IsBasicQualityReagentSlot(slot)
end

function AF:RefreshUnlimitedReagentsQualityDialog(dialog)
	if not self:IsUnlimitedReagentDialog(dialog) then
		return
	end

	local quantityRequired = ClampWholeNumber(dialog.GetQuantityRequired and dialog:GetQuantityRequired() or 0, 0)
	for _, container in ipairs(dialog.containers or {}) do
		local editBox = container.EditBox
		local button = container.Button
		if editBox then
			editBox:SetMinMaxValues(0, quantityRequired)
			editBox:SetEnabled(true)
		end
		if button then
			button:SetItemButtonCount(quantityRequired)
			button:DesaturateHierarchy(0)
		end
	end

	local quantityAllocated = dialog.Accumulate and dialog:Accumulate() or 0
	local canEnable = not dialog.disallowZeroAllocations and quantityAllocated == 0
	if dialog.AcceptButton then
		dialog.AcceptButton:SetEnabled(canEnable or quantityAllocated >= quantityRequired)
	end
end

function AF:AllocateUnlimitedQualityReagent(dialog, qualityIndex, value)
	if not self:IsUnlimitedReagentDialog(dialog) or not dialog.allocations then
		return nil
	end

	local quantityRequired = ClampWholeNumber(dialog:GetQuantityRequired(), 0)
	value = ClampWholeNumber(value, 0, quantityRequired)
	local reagent = dialog:GetReagent(qualityIndex)
	if reagent then
		dialog.allocations:Allocate(reagent, value)
	end

	local overflow = math.max(0, (dialog:Accumulate() or 0) - quantityRequired)
	if overflow > 0 then
		for deallocateIndex = 1, dialog:GetReagentSlotCount() do
			if deallocateIndex ~= qualityIndex then
				local deallocateReagent = dialog:GetReagent(deallocateIndex)
				local oldQuantity = dialog.allocations:GetQuantityAllocated(deallocateReagent)
				local deallocatable = math.min(overflow, oldQuantity)
				if deallocatable > 0 then
					overflow = overflow - deallocatable
					dialog.allocations:Allocate(deallocateReagent, oldQuantity - deallocatable)
				end
			end
			if overflow <= 0 then
				break
			end
		end
	end

	dialog.artisanFinderUpdatingEditBoxes = true
	for reagentIndex = 1, dialog:GetReagentSlotCount() do
		local container = dialog.containers and dialog.containers[reagentIndex]
		local editBox = container and container.EditBox
		local editReagent = dialog:GetReagent(reagentIndex)
		if editBox and editReagent then
			editBox:SetValue(dialog.allocations:GetQuantityAllocated(editReagent))
		end
	end
	dialog.artisanFinderUpdatingEditBoxes = nil

	self:RefreshUnlimitedReagentsQualityDialog(dialog)
	return value
end

function AF:HookUnlimitedReagentsQualityDialog(form)
	local dialog = form and form.QualityDialog
	if not dialog or dialog.artisanFinderUnlimitedReagentsHooked then
		return
	end

	dialog.artisanFinderUnlimitedReagentsHooked = true
	if dialog.Setup then
		hooksecurefunc(dialog, "Setup", function(hookedDialog)
			AF:RefreshUnlimitedReagentsQualityDialog(hookedDialog)
		end)
	end
	if dialog.Open then
		hooksecurefunc(dialog, "Open", function(hookedDialog)
			AF:RefreshUnlimitedReagentsQualityDialog(hookedDialog)
		end)
	end
	if dialog.ReinitAllocations then
		hooksecurefunc(dialog, "ReinitAllocations", function(hookedDialog)
			AF:RefreshUnlimitedReagentsQualityDialog(hookedDialog)
		end)
	end

	for qualityIndex, container in ipairs(dialog.containers or {}) do
		local editBox = container.EditBox
		if editBox then
			editBox.artisanFinderOriginalOnEnterPressed = editBox:GetScript("OnEnterPressed")
			editBox:SetScript("OnEnterPressed", function(box)
				if AF:IsUnlimitedReagentDialog(dialog) then
					return AF:AllocateUnlimitedQualityReagent(dialog, qualityIndex, tonumber(box:GetText()) or 0)
				end
				local original = box.artisanFinderOriginalOnEnterPressed
				if original then
					return original(box)
				end
			end)

			editBox.artisanFinderOriginalOnEditFocusLost = editBox:GetScript("OnEditFocusLost")
			editBox:SetScript("OnEditFocusLost", function(box)
				if AF:IsUnlimitedReagentDialog(dialog) then
					return AF:AllocateUnlimitedQualityReagent(dialog, qualityIndex, tonumber(box:GetText()) or 0)
				end
				local original = box.artisanFinderOriginalOnEditFocusLost
				if original then
					return original(box)
				end
			end)

			editBox.artisanFinderOriginalOnTextChanged = editBox:GetScript("OnTextChanged")
			editBox:SetScript("OnTextChanged", function(box, userChanged)
				if dialog.artisanFinderUpdatingEditBoxes then
					return
				end
				if AF:IsUnlimitedReagentDialog(dialog) then
					if not userChanged then
						return AF:AllocateUnlimitedQualityReagent(dialog, qualityIndex, tonumber(box:GetText()) or 0)
					end
					return
				end
				local original = box.artisanFinderOriginalOnTextChanged
				if original then
					return original(box, userChanged)
				end
			end)
		end

		local button = container.Button
		if button then
			button.artisanFinderOriginalOnClick = button:GetScript("OnClick")
			button:SetScript("OnClick", function(clickedButton, buttonName, down)
				if AF:IsUnlimitedReagentDialog(dialog) and not IsShiftKeyDown() then
					if buttonName == "LeftButton" then
						return AF:AllocateUnlimitedQualityReagent(dialog, qualityIndex, dialog:GetQuantityRequired())
					elseif buttonName == "RightButton" then
						return AF:AllocateUnlimitedQualityReagent(dialog, qualityIndex, 0)
					end
				end
				local original = clickedButton.artisanFinderOriginalOnClick
				if original then
					return original(clickedButton, buttonName, down)
				end
			end)
		end
	end
end

function AF:ApplyUnlimitedReagentsToCraftingForm(force)
	if not self:IsUnlimitedReagentsEnabled() or not self:IsOwnProfessionWindowOpen() then
		return false
	end

	local form = self:GetCraftingSchematicForm()
	local transaction = form and form.GetTransaction and form:GetTransaction()
	local schematic = transaction and transaction.GetRecipeSchematic and transaction:GetRecipeSchematic()
	if not transaction or type(schematic) ~= "table" or type(schematic.reagentSlotSchematics) ~= "table" then
		return false
	end
	if transaction.IsRecraft and transaction:IsRecraft() then
		return false
	end
	if not force and transaction.IsManuallyAllocated and transaction:IsManuallyAllocated() then
		return false
	end

	local useBestQuality = Professions
		and Professions.ShouldAllocateBestQualityReagents
		and Professions.ShouldAllocateBestQualityReagents() == true
	local allocated = false
	local hasSelectableUnlimitedSlots = false
	for slotIndex, slot in ipairs(schematic.reagentSlotSchematics) do
		if IsBasicQualityReagentSlot(slot) then
			local allocations = transaction.GetAllocations and transaction:GetAllocations(slotIndex)
			if allocations and allocations.Clear and allocations.Allocate then
				allocations:Clear()
				local reagent = GetUnlimitedReagentForSlot(slot, useBestQuality)
				if reagent then
					allocations:Allocate(reagent, GetReagentQuantityRequired(slot, reagent))
					allocated = true
				end
			end
		elseif IsUnlimitedSelectableReagentSlot(slot) then
			hasSelectableUnlimitedSlots = true
		end
	end

	if not allocated and not hasSelectableUnlimitedSlots then
		return false
	end
	if allocated and transaction.SetManuallyAllocated then
		transaction:SetManuallyAllocated(true)
	end
	self:SyncUnlimitedReagentExemptions(transaction)
	if form.UpdateAllSlots then
		form:UpdateAllSlots()
	end
	self:RefreshCraftingQualityDialog(form)
	self:RefreshCraftingSchematicStats(form)
	return true
end

function AF:RestoreOwnedReagentAllocations()
	if not self:IsOwnProfessionWindowOpen() then
		return false
	end

	local form = self:GetCraftingSchematicForm()
	local transaction = form and form.GetTransaction and form:GetTransaction()
	if not transaction or not Professions or not Professions.AllocateAllBasicReagents then
		return false
	end

	local useBestQuality = Professions.ShouldAllocateBestQualityReagents
		and Professions.ShouldAllocateBestQualityReagents() == true
	if not (transaction.IsRecraft and transaction:IsRecraft()) then
		self:SyncUnlimitedReagentExemptions(transaction)
		if transaction.SanitizeAllocations then
			transaction:SanitizeAllocations()
		end
	end
	Professions.AllocateAllBasicReagents(transaction, useBestQuality)
	if form.UpdateAllSlots then
		form:UpdateAllSlots()
	end
	self:RefreshCraftingQualityDialog(form)
	self:RefreshCraftingSchematicStats(form)
	return true
end

function AF:ApplyProfessionReagentMode()
	if self:IsUnlimitedReagentsEnabled() then
		return self:ApplyUnlimitedReagentsToCraftingForm(true)
	end
	return self:RestoreOwnedReagentAllocations()
end

function AF:SetUnlimitedReagentsEnabled(enabled)
	if not self.db then
		return
	end
	self.db.unlimitedReagents = enabled == true
	self:RefreshUnlimitedReagentsCheck()
	self:ApplyProfessionReagentMode()
end

function AF:RefreshUnlimitedReagentsCheck()
	local form = self:GetCraftingSchematicForm()
	local check = self:EnsureUnlimitedReagentsCheckbox(form)
	if not check then
		return
	end

	SetCheckboxText(check, LIGHTGRAY_FONT_COLOR:WrapTextInColorCode(self:Text("PROFESSION_PANEL_UNLIMITED_REAGENTS")))
	PositionUnlimitedReagentsCheckbox(form, check)
	check:SetChecked(self:IsUnlimitedReagentsEnabled())
	local nativeCheck = form and form.AllocateBestQualityCheckbox
	local shown = self:IsOwnProfessionWindowOpen() and nativeCheck and nativeCheck:IsShown()
	check:SetShown(shown)
	if shown then
		check:Enable()
		check:SetAlpha(1)
	else
		check:Disable()
	end
end


function AF:InitializeCrafterReagentControls(form)
	if form.RegisterCallback and ProfessionsRecipeSchematicFormMixin then
		local refresh = function()
			AF:RefreshUnlimitedReagentsCheck()
			AF:RefreshCrafterUI()
		end
		local useBestRefresh = function()
			if AF:IsUnlimitedReagentsEnabled() then
				AF:ApplyUnlimitedReagentsToCraftingForm(true)
			end
			refresh()
		end
		form:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.AllocationsModified, refresh)
		form:RegisterCallback(ProfessionsRecipeSchematicFormMixin.Event.UseBestQualityModified, useBestRefresh)
	end

	self:EnsureUnlimitedReagentsCheckbox(form)
	self:HookUnlimitedReagentsQualityDialog(form)
	self:HookUnlimitedReagentFlyouts()
end
