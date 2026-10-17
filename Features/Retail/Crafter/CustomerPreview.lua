local _, AF = ...
local CUSTOMER_PREVIEW_TEXTURE = 4675733

local function CreateCustomerPreviewButton(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(18, 18)
	button:SetNormalTexture(CUSTOMER_PREVIEW_TEXTURE)
	button:SetPushedTexture(CUSTOMER_PREVIEW_TEXTURE)
	return button
end

local function ConfigureCustomerPreviewButton(button, getEntry)
	button:SetScript("OnEnter", function(self)
		local entry, defaultEntry, disabledText = getEntry()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(AF:Text("CUSTOMER_SIDE_PREVIEW"), 1, 0.82, 0)
		if disabledText then
			GameTooltip:AddLine(disabledText, 0.75, 0.75, 0.75, true)
		elseif entry or defaultEntry then
			local previewEntry = CopyTable(defaultEntry)
			for key, value in pairs(entry or {}) do
				previewEntry[key] = value
			end
			AF:AddCustomerEntryTooltipLines(GameTooltip, previewEntry, { title = false, source = false, pricing = true })
		else
			GameTooltip:AddLine(AF:Text("CUSTOMER_SIDE_PREVIEW_EMPTY"), 0.65, 0.65, 0.65, true)
		end
		AF:StyleCustomerTooltip(GameTooltip)
		AF:FitTooltipWidthToContent(GameTooltip)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return button
end

function AF:CreateCrafterCustomerPreview(frame)
	frame.customerPreview = ConfigureCustomerPreviewButton(CreateCustomerPreviewButton(frame), function()
		local context = frame.artisanFinderLoadedContext
		local item = context and AF.db.artisanProfile.items[tostring(context.itemID or "")]
		local defaultEntry = context and context.professionID and AF:GetProfessionPriceEntry(AF.db.artisanProfile, context.professionID)
		if context and item and not AF:IsRecipeEntryScanComplete(context, item) then
			return item, defaultEntry, AF:Text("CUSTOMER_SIDE_PREVIEW_SCANNING")
		end
		return item, defaultEntry
	end)
	frame.customerPreview:SetPoint("RIGHT", frame.info, "LEFT", -2, 0)
end

function AF:RefreshCrafterCustomerPreview(frame, context, item)
	if frame.customerPreview then
		if self:IsRecipeEntryScanComplete(context, item) then
			frame.customerPreview:Enable()
			frame.customerPreview:SetAlpha(1)
		else
			frame.customerPreview:Disable()
			frame.customerPreview:SetAlpha(0.45)
		end
	end
end

function AF:AddCrafterPreviewTutorialTile(info, parent, frame)
	if frame and frame.customerPreview and frame.customerPreview:IsShown() then
		self.TutorialHelpers.AddHelpPlateTile(info, parent, self:Text("TUTORIAL_CRAFTER_PREVIEW"), nil, frame.customerPreview)
	end
end
