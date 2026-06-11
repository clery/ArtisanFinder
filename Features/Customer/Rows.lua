local _, AF = ...

local DETAIL_ELLIPSIS = "..."
local WHO_SPINNER_SIZE = 16
local WHO_SPINNER_PADDING = 5

local function GetUTF8EndForCharCount(text, count)
	text = tostring(text or "")
	count = tonumber(count) or 0
	if count <= 0 then
		return 0
	end
	local pos = 1
	local chars = 0
	while pos <= #text and chars < count do
		local byte = text:byte(pos) or 0
		local step = 1
		if byte >= 240 then
			step = 4
		elseif byte >= 224 then
			step = 3
		elseif byte >= 194 then
			step = 2
		end
		chars = chars + 1
		pos = pos + step
	end
	return math.min(#text, pos - 1)
end

local function GetUTF8CharCount(text)
	text = tostring(text or "")
	local count = 0
	local pos = 1
	while pos <= #text do
		local byte = text:byte(pos) or 0
		local step = 1
		if byte >= 240 then
			step = 4
		elseif byte >= 224 then
			step = 3
		elseif byte >= 194 then
			step = 2
		end
		count = count + 1
		pos = pos + step
	end
	return count
end

local function SetFittedDetailText(row, commissionText, note)
	commissionText = tostring(commissionText or "")
	note = tostring(note or "")
	if note == "" then
		row.detail:SetText(commissionText)
		return false
	end

	local maxWidth = math.max(row.detail:GetWidth() or 0, (row:GetWidth() or 0) - 67, 280)
	local prefix = commissionText .. " - "
	row.detail:SetText(prefix .. note)
	if row.detail:GetStringWidth() <= maxWidth then
		return false
	end

	row.detail:SetText(prefix .. DETAIL_ELLIPSIS)
	if row.detail:GetStringWidth() > maxWidth then
		row.detail:SetText(commissionText)
		return true
	end

	local low = 0
	local high = GetUTF8CharCount(note)
	while low < high do
		local mid = math.ceil((low + high) / 2)
		row.detail:SetText(prefix .. note:sub(1, GetUTF8EndForCharCount(note, mid)) .. DETAIL_ELLIPSIS)
		if row.detail:GetStringWidth() <= maxWidth then
			low = mid
		else
			high = mid - 1
		end
	end
	row.detail:SetText(prefix .. note:sub(1, GetUTF8EndForCharCount(note, low)) .. DETAIL_ELLIPSIS)
	return true
end

local function EnsureWhoSpinner(row)
	if not row.whoSpinner then
		local spinner = CreateFrame("Frame", nil, row, "SpinnerTemplate")
		spinner:SetSize(WHO_SPINNER_SIZE, WHO_SPINNER_SIZE)
		spinner:Hide()
		row.whoSpinner = spinner
	end
	if not row.whoSpinner.artisanFinderConfigured then
		row.whoSpinner.artisanFinderConfigured = true
		row.whoSpinner:EnableMouse(true)
		row.whoSpinner:SetScript("OnEnter", function(owner)
			local refreshIcon = CreateAtlasMarkup and CreateAtlasMarkup("UI-RefreshButton", 14, 14) or ""
			GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
			GameTooltip:SetText(AF:Text("WHO_REFRESH_HINT", refreshIcon), 1, 0.82, 0, 1, true)
			GameTooltip:Show()
		end)
		row.whoSpinner:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end
	return row.whoSpinner
end

local function PositionWhoSpinner(row, shown)
	local spinner = EnsureWhoSpinner(row)
	if not shown then
		if spinner:IsShown() then
			spinner:Hide()
		end
		row.artisanFinderWhoSpinnerName = nil
		return
	end

	local nameWidth = row.name:GetStringWidth() or 0
	local maxOffset = math.max(0, (row.name:GetWidth() or 0) - WHO_SPINNER_SIZE)
	spinner:ClearAllPoints()
	spinner:SetPoint("LEFT", row.name, "LEFT", math.min(nameWidth + WHO_SPINNER_PADDING, maxOffset), 0)
	row.artisanFinderWhoSpinnerName = row.artisanFinderWhoName
	if not spinner:IsShown() then
		spinner:Show()
	end
end

function AF:IsCustomerEntryWhoPending(entry)
	if not entry or entry.tutorialFake or entry.debug then
		return false
	end
	return self:IsWhoStatusPending(entry.orderTarget or entry.name or entry.target) == true
end

function AF:RefreshCustomerWhoLoadingIndicators()
	for _, row in ipairs(self.customerRows or {}) do
		if row:IsShown() and row.artisanFinderWhoName then
			PositionWhoSpinner(row, self:IsWhoStatusPending(row.artisanFinderWhoName) == true)
		elseif row.whoSpinner then
			row.whoSpinner:Hide()
			row.artisanFinderWhoSpinnerName = nil
		end
	end
end

function AF:UpdateCustomerRowWhoRefreshButton(row)
	if not row or not row.whoRefresh then
		return
	end
	local enabled = row:IsShown() and self:IsCustomerEntryWhoRefreshAvailable(row.entry)
	local entry = row.entry
	local shown = row:IsShown()
		and self:IsCustomerEntryWhoRefreshable(entry)
	row.whoRefresh:SetShown(shown)
	row.whoRefresh:SetEnabled(enabled)
	row.whoRefresh:SetAlpha(1)
end

function AF:UpdateCustomerWhoRefreshButtons()
	for _, row in ipairs(self.customerRows or {}) do
		self:UpdateCustomerRowWhoRefreshButton(row)
	end
end

function AF:BuildCustomerRowViewModel(entry)
	if entry and entry.tutorialFake then
		return {
			displayName = entry.name or self:Text("TUTORIAL_FAKE_ARTISAN_NAME"),
			detail = entry.note or self:Text("TUTORIAL_FAKE_ARTISAN_NOTE"),
			detailNote = "",
			capability = entry.capabilityText or self:Text("TUTORIAL_FAKE_ARTISAN_CAPABILITY"),
			updatedAt = "",
			certified = true,
			favorite = self.customerTutorialFavorite == true,
		}
	end

	local displayNameSource = entry.displayName or entry.name or "?"
	local displayName = self:GetDisplayPlayerName(displayNameSource)
	local statusTooltipText
	local isOnline = self:IsCustomerEntryOnline(entry)
	local availabilityState = entry.availabilityState
	if not availabilityState then
		if self:IsCustomerEntryWhoCheckFailed(entry) then
			availabilityState = "check_failed"
		elseif entry.unavailableCached or entry.unavailableFavorite then
			availabilityState = "unavailable"
		elseif self:IsCustomerEntryOffline(entry) then
			availabilityState = "offline"
		elseif entry.offlineCached and not isOnline then
			availabilityState = entry.tradeLead and "unknown" or "unavailable"
		elseif isOnline then
			availabilityState = "online"
		end
	end
	if self:IsCustomerEntryWhoCheckFailed(entry) then
		local statusText = self:Text("ONLINE_CHECK_FAILED")
		displayName = displayName .. " |cffaa5555(" .. statusText .. ")|r"
		statusTooltipText = "(" .. statusText .. ")"
	elseif availabilityState == "unavailable" then
		local statusText = self:Text("UNAVAILABLE")
		displayName = displayName .. " |cff888888(" .. statusText .. ")|r"
		statusTooltipText = "(" .. statusText .. ")"
	elseif availabilityState == "offline" then
		local statusText = self:Text("OFFLINE")
		displayName = displayName .. " |cff888888(" .. statusText .. ")|r"
		statusTooltipText = "(" .. statusText .. ")"
	elseif availabilityState == "unknown" then
		displayName = displayName .. " |cff888888(" .. self:Text("UNKNOWN") .. ")|r"
	end
	if entry.afk then
		displayName = displayName .. " |cffffd100(" .. self:Text("AWAY") .. ")|r"
	end

	local detail
	local detailNote
	local capability
	local onlineAs
	local crafterName = self:NormalizeName(entry.orderTarget or entry.name)
	local contactName = self:NormalizeName(entry.target)
	local displayNameTarget = self:NormalizeName(entry.displayName)
	if (entry.guildMember or entry.onlineContact) and contactName and crafterName and contactName ~= crafterName and displayNameTarget ~= contactName and not entry.offlineCached and not entry.unavailableFavorite then
		onlineAs = self:Text("ONLINE_AS", self:GetDisplayPlayerName(contactName))
	end
	if entry.tradeLead then
		detail = entry.note or self:Text("MISSING_ADDON_DATA")
		capability = (entry.professionID and self:GetProfessionName(entry.professionID)) or entry.professionName or ""
		if entry.guildMember then
			capability = "|cff33ff99" .. self:Text("GUILD_MEMBER") .. "|r" .. (capability ~= "" and ("\n" .. capability) or "")
		end
	else
		detailNote = entry.note and entry.note ~= "" and entry.note or ""
		detail = self:FormatMoney(entry.priceCopper, entry.freeCommission)
		capability = self:FormatCapability(entry)
		if entry.ownAlt then
			capability = "|cff33ff99" .. self:Text(entry.ownSelf and "YOUR_CHARACTER" or "YOUR_ALT") .. "|r" .. (capability ~= "" and ("\n" .. capability) or "")
		end
		if entry.guildMember then
			capability = "|cff33ff99" .. self:Text("GUILD_MEMBER") .. "|r" .. (capability ~= "" and ("\n" .. capability) or "")
		end
		if onlineAs then
			capability = "|cff33ff99" .. onlineAs .. "|r" .. (capability ~= "" and ("\n" .. capability) or "")
		end
	end

	return {
		displayName = displayName,
		detail = detail,
		detailNote = detailNote,
		capability = capability,
		updatedAt = self:FormatCustomerRowUpdatedAt(entry),
		certified = not entry.tradeLead,
		favorite = self:IsFavoriteArtisan(entry),
		whoName = self:GetCustomerEntryWhoName(entry),
		whoPending = self:IsCustomerEntryWhoPending(entry),
		statusTooltipText = statusTooltipText,
		availabilityState = availabilityState,
	}
end

function AF:ApplyCustomerRowViewModel(row, viewModel, minimumHeight, bottomPadding)
	local keepSpinner = row.whoSpinner
		and row.whoSpinner:IsShown()
		and row.artisanFinderWhoSpinnerName == viewModel.whoName
		and viewModel.whoPending
	if row.whoSpinner and not keepSpinner then
		row.whoSpinner:Hide()
		row.artisanFinderWhoSpinnerName = nil
	end
	row.certified:SetShown(viewModel.certified)
	row.favorite:SetShown(viewModel.favorite)
	row.artisanFinderWhoName = viewModel.whoName
	row.name:SetText(viewModel.displayName or "")
	row.nameStatusTooltipText = nil
	if viewModel.statusTooltipText and (row.name:GetStringWidth() or 0) > (row.name:GetWidth() or 0) + 1 then
		row.nameStatusTooltipText = viewModel.statusTooltipText
	end
	row.updatedAt:SetText(viewModel.updatedAt or "")
	row.updatedAt:SetWidth(math.max(1, math.ceil((row.updatedAt:GetStringWidth() or 0) + 2)))
	local noteTruncated = SetFittedDetailText(row, viewModel.detail, viewModel.detailNote)
	row.noteTooltipText = noteTruncated and viewModel.detailNote or nil
	row.capability:SetText(viewModel.capability or "")
	PositionWhoSpinner(row, viewModel.whoPending)
	self:UpdateCustomerRowWhoRefreshButton(row)

	return math.max(
		minimumHeight,
		6 + row.name:GetStringHeight() + 3 + row.detail:GetStringHeight() + 3 + row.capability:GetStringHeight() + bottomPadding
	)
end

function AF:RefreshCustomerRowAges()
	for _, row in ipairs(self.customerRows or {}) do
		if row:IsShown() and row.entry and row.updatedAt then
			row.updatedAt:SetText(self:FormatCustomerRowUpdatedAt(row.entry) or "")
			row.updatedAt:SetWidth(math.max(1, math.ceil((row.updatedAt:GetStringWidth() or 0) + 2)))
		end
	end
end
