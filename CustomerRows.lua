local _, AF = ...

function AF:BuildCustomerRowViewModel(entry)
	local displayName = self:GetDisplayPlayerName(entry.name or "?")
	if entry.unavailableFavorite then
		displayName = displayName .. " |cff888888(" .. self:Text("UNAVAILABLE") .. ")|r"
	elseif entry.offlineCached then
		displayName = displayName .. " |cff888888" .. self:Text("OFFLINE_LAST_SEEN", self:FormatRelativeTime(entry.updatedAt)) .. "|r"
	end

	local detail
	local capability
	local onlineAs
	local crafterName = self:NormalizeName(entry.orderTarget or entry.name)
	local contactName = self:NormalizeName(entry.target)
	if contactName and crafterName and contactName ~= crafterName and not entry.offlineCached and not entry.unavailableFavorite then
		onlineAs = self:Text("ONLINE_AS", self:GetDisplayPlayerName(contactName))
	end
	if entry.tradeLead then
		detail = entry.note or self:Text("MISSING_ADDON_DATA")
		capability = entry.professionName or ""
	else
		local note = entry.note and entry.note ~= "" and (" - " .. entry.note) or ""
		detail = self:FormatMoney(entry.priceCopper, entry.freeCommission) .. note
		capability = self:FormatCapability(entry)
		if onlineAs then
			capability = "|cff33ff99" .. onlineAs .. "|r" .. (capability ~= "" and ("\n" .. capability) or "")
		end
	end

	return {
		displayName = displayName,
		detail = detail,
		capability = capability,
		updatedAt = self:FormatCustomerRowUpdatedAt(entry),
		certified = not entry.tradeLead,
		favorite = self:IsFavoriteArtisan(entry),
	}
end

function AF:ApplyCustomerRowViewModel(row, viewModel, minimumHeight, bottomPadding)
	row.certified:SetShown(viewModel.certified)
	row.favorite:SetShown(viewModel.favorite)
	row.name:SetText(viewModel.displayName or "")
	row.updatedAt:SetText(viewModel.updatedAt or "")
	row.detail:SetText(viewModel.detail or "")
	row.capability:SetText(viewModel.capability or "")

	return math.max(
		minimumHeight,
		6 + row.name:GetStringHeight() + 3 + row.detail:GetStringHeight() + 3 + row.capability:GetStringHeight() + bottomPadding
	)
end
