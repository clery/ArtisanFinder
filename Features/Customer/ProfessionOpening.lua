local _, AF = ...

-- Shared opening/retry state; client adapters supply link eligibility and guild identity.

function AF:ShowProfessionButtonTooltip(button)
	button = button or (self.customerFrame and self.customerFrame.menu and self.customerFrame.menu.link)
	local text = button and button.artisanFinderTooltipText
	if not text then
		return
	end
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:SetText(text, 1, 0.82, 0, 1, true)
	GameTooltip:Show()
end

function AF:SetProfessionButtonTooltip(text, duration)
	local button = self.customerFrame and self.customerFrame.menu and self.customerFrame.menu.link
	if not button then
		return
	end
	button.artisanFinderTooltipText = text
	button.artisanFinderTooltipToken = (button.artisanFinderTooltipToken or 0) + 1
	local token = button.artisanFinderTooltipToken
	if button:IsMouseOver() then
		self:ShowProfessionButtonTooltip(button)
	end
	if duration then
		C_Timer.After(duration, function()
			local currentButton = AF.customerFrame and AF.customerFrame.menu and AF.customerFrame.menu.link
			if currentButton and currentButton.artisanFinderTooltipToken == token then
				AF:ClearProfessionButtonTooltip()
			end
		end)
	end
end

function AF:ClearProfessionButtonTooltip()
	local button = self.customerFrame and self.customerFrame.menu and self.customerFrame.menu.link
	if not button then
		return
	end
	button.artisanFinderTooltipText = nil
	button.artisanFinderTooltipToken = (button.artisanFinderTooltipToken or 0) + 1
	if button:IsMouseOver() then
		GameTooltip:Hide()
	end
end

function AF:GetProfessionOpenFailureKey(entry)
	if not entry then
		return nil
	end
	local target = self:NormalizeName(entry.orderTarget or entry.name or entry.target)
	local professionID = tonumber(entry.professionID) or 0
	local professionLink = entry.professionLink or self:GetRememberedProfessionLink(entry.orderTarget or entry.name, entry.professionID) or ""
	if not target and professionID == 0 and professionLink == "" then
		return nil
	end
	return tostring(target or "?") .. ":" .. tostring(professionID) .. ":" .. tostring(professionLink)
end

function AF:HasProfessionOpenFailed(entry)
	local key = self:GetProfessionOpenFailureKey(entry)
	return key and self.professionOpenFailures and self.professionOpenFailures[key] == true
end

function AF:MarkProfessionOpenFailed(entry)
	local key = self:GetProfessionOpenFailureKey(entry)
	if key then
		self.professionOpenFailures = self.professionOpenFailures or {}
		self.professionOpenFailures[key] = true
	end

	local menu = self.customerFrame and self.customerFrame.menu
	if menu and menu:IsShown() and menu.entry == entry then
		menu.link:Disable()
		self:SetProfessionButtonTooltip(self:Text("PROFESSION_LINK_UNAVAILABLE_TOOLTIP"))
	end
	if self.RefreshCustomerResults then
		self:RefreshCustomerResults()
	end
end

function AF:ClearPendingProfessionOpen()
	self.pendingProfessionRecipeID = nil
	self.pendingProfessionID = nil
	self.pendingProfessionRecipeTries = nil
	self.pendingProfessionLink = nil
	self.pendingProfessionLinkPayload = nil
	self.pendingProfessionTarget = nil
	self.pendingProfessionEntry = nil
	self.pendingProfessionOpenToken = (self.pendingProfessionOpenToken or 0) + 1
end

function AF:OpenCrafterProfession(entry)
	if not entry then
		return
	end
	if entry.tutorialFake then
		self:SetProfessionButtonTooltip(self:Text("TUTORIAL_FAKE_ACTION_TOOLTIP"), 4)
		return
	end

	if not self:CanReliablyOpenProfession(entry) then
		self:SetProfessionButtonTooltip(self:Text("PROFESSION_LINK_UNAVAILABLE_TOOLTIP"), 6)
		return
	end

	local guildProfessionGUID = self:GetProfessionOpenGuildGUID(entry)
	if guildProfessionGUID then
		local professionID = tonumber(entry.professionID)
		if not professionID then
			self:SetProfessionButtonTooltip(self:Text("PROFESSION_LINK_UNAVAILABLE_TOOLTIP"), 6)
			return
		end
		local ok = pcall(C_GuildInfo.QueryGuildMemberRecipes, guildProfessionGUID, professionID)
		if not ok then
			self:SetProfessionButtonTooltip(self:Text("PROFESSION_LINK_UNAVAILABLE_TOOLTIP"), 6)
			return
		end
		self:HideCustomerMenu()
		return
	end

	local professionLink = entry.professionLink or self:GetRememberedProfessionLink(entry.orderTarget or entry.name, entry.professionID)
	if not professionLink then
		self:MarkProfessionOpenFailed(entry)
		return
	end

	local professionLinkPayload = professionLink:match("|H([^|]+)|h") or professionLink
	self.pendingProfessionRecipeID = tonumber(entry.recipeID)
	self.pendingProfessionID = tonumber(entry.professionID)
	self.pendingProfessionRecipeTries = 12
	self.pendingProfessionLink = professionLink
	self.pendingProfessionLinkPayload = professionLinkPayload
	self.pendingProfessionTarget = entry.orderTarget or entry.name
	self.pendingProfessionEntry = entry
	self.pendingProfessionOpenToken = (self.pendingProfessionOpenToken or 0) + 1
	local openToken = self.pendingProfessionOpenToken
	local ok = pcall(SetItemRef, professionLinkPayload, professionLink, "LeftButton", DEFAULT_CHAT_FRAME)
	if not ok then
		self:MarkProfessionOpenFailed(entry)
		self:ClearPendingProfessionOpen()
		return
	end
	C_Timer.After(1, function()
		if AF.pendingProfessionOpenToken ~= openToken then
			return
		end
		local menu = AF.customerFrame and AF.customerFrame.menu
		local sameEntry = menu and menu:IsShown() and menu.entry == entry
		local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
		if sameEntry and (not page or not page:IsVisible()) then
			AF:MarkProfessionOpenFailed(entry)
			AF:ClearPendingProfessionOpen()
		end
	end)
	self:QueuePendingProfessionRecipeSelection()
end

function AF:QueuePendingProfessionRecipeSelection()
	if self.pendingProfessionRecipeQueued or not self.pendingProfessionRecipeID then
		return
	end

	self.pendingProfessionRecipeQueued = true
	C_Timer.After(0.25, function()
		AF.pendingProfessionRecipeQueued = false
		AF:TrySelectPendingProfessionRecipe()
	end)
end

function AF:TrySelectPendingProfessionRecipe()
	local recipeID = self.pendingProfessionRecipeID
	if not recipeID then
		return
	end

	local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
	local recipeList = page and page.RecipeList
	local form = page and page.SchematicForm
	if not page or not recipeList or not form or not page:IsVisible() then
		self.pendingProfessionRecipeTries = (self.pendingProfessionRecipeTries or 0) - 1
		if self.pendingProfessionRecipeTries > 0 then
			self:QueuePendingProfessionRecipeSelection()
			return
		end
		self:MarkProfessionOpenFailed(self.pendingProfessionEntry or {
			orderTarget = self.pendingProfessionTarget,
			name = self.pendingProfessionTarget,
			professionID = self.pendingProfessionID,
			professionLink = self.pendingProfessionLink,
		})
		self:ClearPendingProfessionOpen()
		return
	end

	self:HideCustomerMenu()

	local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
	if recipeInfo then
		recipeList:SelectRecipe(recipeInfo, true)
	end

	local selectedRecipeInfo = form.GetRecipeInfo and form:GetRecipeInfo()
	if selectedRecipeInfo and tonumber(selectedRecipeInfo.recipeID) == recipeID then
		self:ClearPendingProfessionOpen()
		return
	end

	self.pendingProfessionRecipeTries = (self.pendingProfessionRecipeTries or 0) - 1
	if self.pendingProfessionRecipeTries > 0 then
		self:QueuePendingProfessionRecipeSelection()
	else
		self:ClearPendingProfessionOpen()
	end
end
