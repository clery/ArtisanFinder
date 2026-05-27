local _, AF = ...

function AF:InitializeComms()
	C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)
	self.responseThrottle = {}
	self:QueueDiscoveryChannelJoin(8)
end

local function HasVisibleServerChannel(channelName, ...)
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "string" and value ~= channelName then
			return true
		end
	end
	return false
end

function AF:HasJoinedServerChannel()
	return HasVisibleServerChannel(self.CHANNEL_NAME, GetChannelList())
end

function AF:HasJoinedTradeChannel()
	return self:GetJoinedTradeChannelID() ~= nil
end

function AF:GetJoinedTradeChannelID()
	if not GetChannelList then
		return nil
	end
	local channels = { GetChannelList() }
	for index, value in ipairs(channels) do
		if type(value) == "string" and value ~= self.CHANNEL_NAME and self:IsTradeChannelName(value) then
			return tonumber(channels[index - 1]) or GetChannelName(value)
		end
	end
	return nil
end

function AF:GetLastVisibleServerChannelID()
	if not GetChannelList then
		return nil
	end
	local lastID
	local channels = { GetChannelList() }
	for index, value in ipairs(channels) do
		if type(value) == "string" and value ~= self.CHANNEL_NAME then
			lastID = math.max(lastID or 0, tonumber(channels[index - 1]) or 0)
		end
	end
	return lastID
end

function AF:GetVisibleServerChannelSignature()
	if not GetChannelList then
		return ""
	end
	local channels = { GetChannelList() }
	local parts = {}
	for index, value in ipairs(channels) do
		if type(value) == "string" and value ~= self.CHANNEL_NAME then
			table.insert(parts, tostring(channels[index - 1] or 0) .. ":" .. value)
		end
	end
	return table.concat(parts, "|")
end

function AF:VisibleServerChannelsStable(requiredSeconds)
	local signature = self:GetVisibleServerChannelSignature()
	local now = self:Now()
	if signature ~= self.discoveryVisibleChannelSignature then
		self.discoveryVisibleChannelSignature = signature
		self.discoveryVisibleChannelStableAt = now
		return false
	end
	return now - (tonumber(self.discoveryVisibleChannelStableAt) or now) >= (requiredSeconds or 3)
end

function AF:DiscoveryChannelNeedsRejoin()
	local discoveryID = GetChannelName(self.CHANNEL_NAME)
	if discoveryID == 0 then
		return false
	end
	local lastVisibleID = self:GetLastVisibleServerChannelID()
	return lastVisibleID and discoveryID < lastVisibleID
end

function AF:QueueDiscoveryChannelJoin(delay)
	if self.discoveryChannelJoinQueued then
		return
	end
	if GetChannelName(self.CHANNEL_NAME) ~= 0 and not self:DiscoveryChannelNeedsRejoin() then
		self:HideDiscoveryChannelFromChat()
		return
	end
	self.discoveryChannelJoinQueued = true
	C_Timer.After(delay or 8, function()
		AF.discoveryChannelJoinQueued = false
		if AF:IsInCombatLocked() then
			AF.deferredDiscoveryChannelJoin = true
			return
		end
		if AF:DiscoveryChannelNeedsRejoin() then
			LeaveChannelByName(AF.CHANNEL_NAME)
			AF:QueueDiscoveryChannelJoin(2)
			return
		end
		if not AF:HasJoinedTradeChannel() then
			AF:QueueDiscoveryChannelJoin(2)
			return
		end
		if not AF:VisibleServerChannelsStable(3) then
			AF:QueueDiscoveryChannelJoin(2)
			return
		end
		AF:JoinDiscoveryChannel()
	end)
end

function AF:JoinDiscoveryChannel()
	if GetChannelName(self.CHANNEL_NAME) == 0 then
		JoinTemporaryChannel(self.CHANNEL_NAME)
	end
	self:HideDiscoveryChannelFromChat()
	self:HideDiscoveryChannelFromChat(0.5)
	self:HideDiscoveryChannelFromChat(2)
	self:HideDiscoveryChannelFromChat(5)
end

function AF:GetDiscoveryChannelID()
	local id = GetChannelName(self.CHANNEL_NAME)
	if id == 0 then
		if not self:HasJoinedTradeChannel() then
			self:QueueDiscoveryChannelJoin(2)
			return 0
		end
		self:JoinDiscoveryChannel()
		id = GetChannelName(self.CHANNEL_NAME)
	end
	self:HideDiscoveryChannelFromChat()
	return id
end

function AF:HideDiscoveryChannelFromChat(delay)
	C_Timer.After(delay or 0.25, function()
		if AF:IsInCombatLocked() then
			return
		end
		for i = 1, (NUM_CHAT_WINDOWS or 0) do
			local chatFrame = _G["ChatFrame" .. i]
			if chatFrame and ChatFrame_RemoveChannel then
				ChatFrame_RemoveChannel(chatFrame, AF.CHANNEL_NAME)
			end
			if RemoveChatWindowChannel then
				RemoveChatWindowChannel(i, AF.CHANNEL_NAME)
			end
		end
	end)
end

function AF:SendAddon(prefixPayload, chatType, target, priority, queueName)
	if self:IsInCombatLocked() then
		return false
	end
	priority = priority or "NORMAL"
	queueName = queueName or table.concat({ self.PREFIX, chatType or "", target or "" }, ":")
	ChatThrottleLib:SendAddonMessage(priority, self.PREFIX, prefixPayload, chatType, target, queueName)
	if self:IsDevTrafficLogsEnabled() then
		self:DebugLog("send", string.format("%s %s %s", tostring(chatType or "?"), tostring(target or ""), tostring(prefixPayload or "")))
	end
	return true
end

function AF:BroadcastQuery(itemID, professionID)
	if self:IsInCombatLocked() then
		return false
	end
	itemID = tonumber(itemID)
	if not itemID then
		return false
	end
	local requestTime = self:Now()
	local normalizedProfessionID = self:GetSupportedProfessionID(professionID) or 0
	if normalizedProfessionID == 0 then
		return false
	end
	self.lastQueryItemID = itemID
	self.lastQueryProfessionID = normalizedProfessionID
	self.lastQueryAt = requestTime
	self.currentCustomerQueryToken = requestTime
	self.currentCustomerQueryItemID = itemID
	self.currentCustomerQueryProfessionID = normalizedProfessionID

	local channelID = self:GetDiscoveryChannelID()

	local payload = table.concat({
		"Q",
		self.PROTOCOL_VERSION,
		itemID,
		normalizedProfessionID,
		requestTime,
		self:EncodeField(self.playerName or self:GetPlayerFullName(), 48),
	}, "|")

	local sent = false
	local queueName = table.concat({ "Q", itemID, normalizedProfessionID }, ":")
	if channelID and channelID ~= 0 then
		sent = self:SendAddon(payload, "CHANNEL", tostring(channelID), "NORMAL", queueName .. ":CHANNEL") or sent
	end
	if IsInGuild and IsInGuild() then
		sent = self:SendAddon(payload, "GUILD", nil, "NORMAL", queueName .. ":GUILD") or sent
	end
	if self.GetOnlineGuildQueryTargets then
		local recipeID = tonumber(self.currentCustomerRecipeID) or 0
		local whisperTargets = self:GetOnlineGuildQueryTargets(normalizedProfessionID, recipeID, 30)
		for _, target in ipairs(whisperTargets) do
			sent = self:SendAddon(payload, "WHISPER", target, "BULK", queueName .. ":GUILD_WHISPER:" .. tostring(target)) or sent
		end
	end
	self:DebugLog("query", string.format("sent item=%s profession=%s channel=%s guild=%s result=%s", tostring(itemID), tostring(normalizedProfessionID), tostring(channelID or 0), tostring(IsInGuild and IsInGuild() == true), tostring(sent == true)))
	return sent
end

function AF:QueueBroadcastQuery(itemID, professionID)
	itemID = tonumber(itemID)
	if not itemID then
		return false
	end
	self.pendingCustomerQueryItemID = itemID
	self.pendingCustomerQueryProfessionID = self:GetSupportedProfessionID(professionID) or 0
	if self.customerQueryQueued then
		return true
	end
	self.customerQueryQueued = true
	C_Timer.After(0.2, function()
		AF.customerQueryQueued = false
		if AF:IsInCombatLocked() then
			return
		end
		local pendingItemID = AF.pendingCustomerQueryItemID
		local pendingProfessionID = AF.pendingCustomerQueryProfessionID
		AF.pendingCustomerQueryItemID = nil
		AF.pendingCustomerQueryProfessionID = nil
		if pendingItemID and tonumber(AF.currentCustomerItemID) == tonumber(pendingItemID) then
			AF:BroadcastQuery(pendingItemID, pendingProfessionID)
			AF:InjectDebugSelfResult(pendingItemID, pendingProfessionID)
			AF:InjectDebugTradeLeads()
			AF:RefreshCustomerResults()
		end
	end)
	return true
end

function AF:OnAddonMessage(prefix, message, channel, sender)
	if prefix ~= self.PREFIX then
		return
	end

	local normalizedSender = self:NormalizeName(sender)
	if normalizedSender == self:NormalizeName(self.playerName or self:GetPlayerFullName()) then
		return
	end

	local parts = { strsplit("|", message or "") }
	local kind, version = parts[1], parts[2]
	if version ~= self.PROTOCOL_VERSION then
		return
	end
	if self:IsDevTrafficLogsEnabled() then
		self:DebugLog("recv", string.format("%s %s %s", tostring(channel or "?"), tostring(normalizedSender or "?"), tostring(message or "")))
	end

	if kind == "Q" then
		self:HandleQuery(parts, normalizedSender, channel)
	elseif kind == "R" then
		self:HandleResponse(parts, normalizedSender)
	elseif kind == "DR" then
		self:HandleReagentDetailRequest(parts, normalizedSender)
	elseif kind == "D" then
		self:HandleReagentDetail(parts, normalizedSender)
	elseif kind == "O" then
		self:HandleOrderNotification(parts, normalizedSender)
	end
end

local function ItemMatchesQuery(item, itemID, professionID)
	if not item then
		return false
	end
	if item.itemID and tonumber(item.itemID) ~= tonumber(itemID) then
		return false
	end
	if professionID == 0 then
		return true
	end
	return AF:GetSupportedProfessionID(item.professionID, item) == AF:GetSupportedProfessionID(professionID)
end

local function CanRespondForCrafter(AF, crafterName, requesterName, channel)
	crafterName = AF:NormalizeName(crafterName)
	requesterName = AF:NormalizeName(requesterName)
	if not crafterName then
		return false
	end
	if requesterName and AF:IsNameOnConnectedRealm(requesterName) and AF:IsNameOnConnectedRealm(crafterName) then
		return true
	end
	if not AF.GetCachedGuildRosterEntry then
		return false
	end
	if channel == "GUILD" then
		return AF:GetCachedGuildRosterEntry(crafterName) ~= nil
	end
	return requesterName
		and AF:GetCachedGuildRosterEntry(requesterName) ~= nil
		and AF:GetCachedGuildRosterEntry(crafterName) ~= nil
end

function AF:GetAdvertisedItemMatches(itemID, professionID, requesterName, channel)
	local matches = {}
	local currentOnly = self:IsCurrentCharacterOnlyAvailable()
	local playerName = self:NormalizeName(self.playerName or self:GetPlayerFullName())
	local function addMatches(onlyCurrentCharacter)
		self:ForEachArtisanProfile(function(characterName, profile)
			if onlyCurrentCharacter and self:NormalizeName(characterName) ~= playerName then
				return
			end
			local item = profile.items and profile.items[tostring(itemID)]
			if CanRespondForCrafter(self, characterName, requesterName, channel)
				and ItemMatchesQuery(item, itemID, professionID)
				and self:IsProfessionAdvertised(characterName, item.professionID)
			then
				table.insert(matches, {
					characterName = characterName,
					profile = profile,
					item = item,
				})
			end
		end)
	end

	addMatches(currentOnly)
	if #matches == 0 and currentOnly then
		local currentProfile = self.db and self.db.artisanCharacters and self.db.artisanCharacters[playerName]
		if not (currentProfile and currentProfile.items and next(currentProfile.items)) then
			addMatches(false)
		end
	end
	return matches
end

function AF:FindProfileItem(characterName, itemID, recipeID)
	characterName = self:NormalizeName(characterName)
	local function matches(item)
		return item
			and (not item.itemID or tonumber(item.itemID) == tonumber(itemID))
			and ((tonumber(recipeID) or 0) == 0 or tonumber(item.recipeID) == tonumber(recipeID))
	end
	if characterName and self.db and self.db.artisanCharacters then
		local profile = self.db.artisanCharacters[characterName]
		local item = profile and profile.items and profile.items[tostring(itemID)]
		if matches(item) then
			return item, profile, characterName
		end
	end
	for foundName, profile in pairs(self.db and self.db.artisanCharacters or {}) do
		local item = profile and profile.items and profile.items[tostring(itemID)]
		if matches(item) then
			return item, profile, foundName
		end
	end
	return nil
end

function AF:HandleQuery(parts, sender, channel)
	if not self:IsAvailable() then
		return
	end

	local itemID = tonumber(parts[3])
	local professionID = self:GetSupportedProfessionID(tonumber(parts[4])) or 0
	local queryToken = tonumber(parts[5]) or self:Now()
	local requesterName = self:NormalizeName(self:DecodeField(parts[6])) or sender
	if not itemID or professionID == 0 then
		return
	end

	local matches = self:GetAdvertisedItemMatches(itemID, professionID, requesterName, channel)
	if #matches == 0 then
		return
	end

	for _, match in ipairs(matches) do
		local item = match.item
		local crafterName = match.characterName
		local throttleKey = table.concat({ sender, crafterName, itemID, professionID, queryToken }, ":")
		self.responseThrottle = self.responseThrottle or {}
		local lastSent = self.responseThrottle[throttleKey]
		if not lastSent or self:Now() - lastSent >= self.RESPONSE_THROTTLE then
			local priceCopper, freeCommission, note = self:GetItemPriceForProfile(match.profile, itemID, item.professionID)
			local encodedNote = self:EncodeNote(note)
			local encodedLink = self:EncodeField(item.professionLink)
			local responseProfessionID = self:GetSupportedProfessionID(item.professionID, item)
			local encodedReagents = self:EncodeField(self:EncodeReagentEntries(item.bestReagents), 160)
			local payloadParts = {
				"R",
				self.PROTOCOL_VERSION,
				itemID,
				tonumber(responseProfessionID) or tonumber(item.professionID) or 0,
				tonumber(priceCopper) or 0,
				freeCommission and 1 or 0,
				encodedNote,
				tonumber(item.recipeID) or 0,
				self:Now(),
				tonumber(item.recipeDifficulty) or "",
				tonumber(item.totalSkill) or "",
				tonumber(item.quality) or "",
				tonumber(item.concentrationQuality) or "",
				tonumber(item.concentrationCost) or "",
				encodedLink,
				queryToken,
				tonumber(item.bestQuality) or "",
				tonumber(item.bestConcentrationQuality) or "",
				tonumber(item.bestTotalSkill) or "",
				tonumber(item.bestConcentrationCost) or "",
				item.bestReagentTruncated and 1 or 0,
				item.bestReagents and 1 or 0,
				self:EncodeField(crafterName, 48),
				tonumber(item.optionalDifficultyDelta) or "",
				tonumber(item.optionalQuality) or "",
				tonumber(item.optionalConcentrationQuality) or "",
				tonumber(item.optionalSlotCount) or "",
				channel == "GUILD" and self:EncodeField(requesterName, 48) or "",
				encodedReagents,
				UnitIsAFK and UnitIsAFK("player") and 1 or 0,
				tonumber(item.bestOutputItemLevel) or "",
				tonumber(item.optionalOutputItemLevel) or "",
			}
			local payload = table.concat(payloadParts, "|")
			if #payload > 255 then
				payloadParts[29] = ""
				payloadParts[22] = 0
				payload = table.concat(payloadParts, "|")
			end
			if #payload > 255 then
				payloadParts[15] = ""
				payload = table.concat(payloadParts, "|")
			end
			if #payload > 255 then
				payloadParts[7] = self:EncodeField(note, 32)
				payload = table.concat(payloadParts, "|")
			end
			if #payload > 255 then
				payloadParts[17] = ""
				payloadParts[18] = ""
				payloadParts[19] = ""
				payloadParts[20] = ""
				payloadParts[21] = 0
				payloadParts[22] = 0
				payloadParts[24] = ""
				payloadParts[25] = ""
				payloadParts[26] = ""
				payloadParts[27] = ""
				payloadParts[29] = ""
				payload = table.concat(payloadParts, "|")
			end

			local responseChannel = channel == "GUILD" and "GUILD" or "WHISPER"
			local responseTarget = responseChannel == "WHISPER" and sender or nil
			if self:SendAddon(payload, responseChannel, responseTarget, "NORMAL", "R:" .. tostring(sender)) then
				self.responseThrottle[throttleKey] = self:Now()
			end
		end
	end
end

function AF:HandleReagentDetailRequest(parts, sender)
	local itemID = tonumber(parts[3])
	local recipeID = tonumber(parts[4]) or 0
	local queryToken = tonumber(parts[5])
	local crafterName = self:NormalizeName(self:DecodeField(parts[6]))
	if not itemID or not queryToken or not sender then
		return false
	end

	local item = self:FindProfileItem(crafterName, itemID, recipeID)

	local throttleKey = table.concat({ "D", sender, crafterName or "", itemID, recipeID, queryToken }, ":")
	self.responseThrottle = self.responseThrottle or {}
	local lastSent = self.responseThrottle[throttleKey]
	if lastSent and self:Now() - lastSent < self.DETAIL_REQUEST_THROTTLE then
		return false
	end

	if self:SendReagentDetail(item, sender, queryToken, crafterName) then
		self.responseThrottle[throttleKey] = self:Now()
		return true
	end
	return false
end

function AF:SendReagentDetail(item, target, queryToken, crafterName)
	local details = self:EncodeReagentEntries(item and item.bestReagents)
	if not details or details == "" then
		return false
	end

	local optionalDetails = self:EncodeReagentEntries(item and item.optionalBestReagents)
	local detailText = optionalDetails and optionalDetails ~= "" and ("R4:" .. details .. "\nO4:" .. optionalDetails) or ("R3:" .. details)
	local encodedSummary = self:EncodeReagentSummary(detailText, 1050)
	local chunks = {}
	local maxChunkBytes = 150
	local offset = 1
	while offset <= #encodedSummary do
		table.insert(chunks, encodedSummary:sub(offset, offset + maxChunkBytes - 1))
		offset = offset + maxChunkBytes
	end

	local sent = false
	for index, chunk in ipairs(chunks) do
		local payload = table.concat({
			"D",
			self.PROTOCOL_VERSION,
			tonumber(item.itemID) or 0,
			tonumber(item.recipeID) or 0,
			queryToken,
			index,
			#chunks,
			chunk,
			self:EncodeField(crafterName, 48),
		}, "|")
		local queueName = table.concat({ "D", target or "", crafterName or "", item.itemID or 0, item.recipeID or 0, queryToken or 0 }, ":")
		sent = self:SendAddon(payload, "WHISPER", target, "BULK", queueName) or sent
	end
	return sent
end

function AF:EncodeReagentEntries(reagents)
	local parts = {}
	for _, reagent in ipairs(reagents or {}) do
		local kind = reagent.kind == "currency" and "c" or "i"
		local id = tonumber(reagent.currencyID or reagent.itemID or reagent.id)
		if id then
			parts[#parts + 1] = table.concat({
				kind,
				tostring(id),
				tostring(tonumber(reagent.quantity) or 1),
				tostring(tonumber(reagent.quality) or 0),
				tostring(tonumber(reagent.dataSlotIndex) or 0),
			}, ":")
		end
	end
	return table.concat(parts, ";")
end

function AF:DecodeReagentEntries(encoded)
	local reagents = {}
	for entry in tostring(encoded or ""):gmatch("[^;]+") do
		entry = entry:match("^%s*(.-)%s*$")
		local kind, id, quantity, quality, dataSlotIndex = entry:match("^([ic]):(%d+):(%d+):(%d+):?(%d*)$")
		if not kind then
			kind, id, quantity = entry:match("^([ic])(%d+):(%d+)$")
		end
		id = tonumber(id)
		if kind and id then
			local reagent = {
				kind = kind == "c" and "currency" or "item",
				quantity = tonumber(quantity) or 1,
				quality = tonumber(quality) or nil,
				dataSlotIndex = tonumber(dataSlotIndex) or nil,
			}
			if reagent.kind == "currency" then
				reagent.currencyID = id
			else
				reagent.itemID = id
			end
			reagents[#reagents + 1] = reagent
		end
	end
	return #reagents > 0 and reagents or nil
end

function AF:EncodeReagentSummary(summary, maxBytes)
	local encodedLines = {}
	local length = 0
	for reagentText in tostring(summary or ""):gmatch("[^;\n]+") do
		reagentText = reagentText:match("^%s*(.-)%s*$")
		if reagentText ~= "" then
			local encodedLine = self:EncodeField(reagentText)
			local separator = #encodedLines > 0 and self:EncodeField("; ") or ""
			if length + #separator + #encodedLine > maxBytes then
				break
			end
			if separator ~= "" then
				table.insert(encodedLines, separator)
				length = length + #separator
			end
			table.insert(encodedLines, encodedLine)
			length = length + #encodedLine
		end
	end
	return table.concat(encodedLines, "")
end

function AF:HandleResponse(parts, sender)
	local itemID = tonumber(parts[3])
	local professionID = tonumber(parts[4]) or 0
	local priceCopper = tonumber(parts[5]) or 0
	local freeCommission = tonumber(parts[6]) == 1
	local note = self:DecodeNote(parts[7])
	local recipeID = tonumber(parts[8]) or 0
	local timestamp = tonumber(parts[9]) or self:Now()
	local recipeDifficulty = tonumber(parts[10])
	local totalSkill = tonumber(parts[11])
	local quality = tonumber(parts[12])
	local concentrationQuality = tonumber(parts[13])
	local concentrationCost = tonumber(parts[14])
	local professionLink = self:DecodeField(parts[15])
	local queryToken = tonumber(parts[16])
	local bestQuality = tonumber(parts[17])
	local bestConcentrationQuality = tonumber(parts[18])
	local bestTotalSkill = tonumber(parts[19])
	local bestConcentrationCost = tonumber(parts[20])
	local bestReagentTruncated = tonumber(parts[21]) == 1
	local hasReagentSummary = tonumber(parts[22]) == 1
	local crafterName = self:NormalizeName(self:DecodeField(parts[23])) or sender
	local optionalDifficultyDelta = tonumber(parts[24])
	local optionalQuality = tonumber(parts[25])
	local optionalConcentrationQuality = tonumber(parts[26])
	local optionalSlotCount = tonumber(parts[27])
	local responseTarget = self:NormalizeName(self:DecodeField(parts[28]))
	local responseSupportsReagentDetails = parts[29] ~= nil
	local responseReagents = self:DecodeReagentEntries(self:DecodeField(parts[29]))
	local afk = tonumber(parts[30]) == 1
	local bestOutputItemLevel = tonumber(parts[31])
	local optionalOutputItemLevel = tonumber(parts[32])
	local cacheKey = crafterName

	if not itemID then
		return
	end
	if responseTarget and responseTarget ~= self:NormalizeName(self.playerName or self:GetPlayerFullName()) then
		return
	end
	local guildResponse = responseTarget ~= nil
	local guildRosterEntry = guildResponse and self:GetCachedGuildRosterEntry(crafterName) or nil

	local verifiedForCurrentQuery = queryToken
		and self.currentCustomerQueryToken
		and queryToken == tonumber(self.currentCustomerQueryToken)
		and itemID == tonumber(self.currentCustomerQueryItemID)

	local itemKey = tostring(itemID)
	self.db.customerCache[itemKey] = self.db.customerCache[itemKey] or {}
	local previous = self.db.customerCache[itemKey][cacheKey]
	local previousRecipeID = tonumber(previous and previous.recipeID) or 0
	local savedReagents = responseReagents or (previousRecipeID == recipeID and previous and previous.bestReagents) or nil
	local savedOptionalBestReagents = self:GetDistinctOptionalBestReagents(savedReagents, previousRecipeID == recipeID and previous and previous.optionalBestReagents or nil)
	hasReagentSummary = hasReagentSummary and (responseSupportsReagentDetails or savedReagents ~= nil)
	if professionLink ~= "" then
		self:RememberProfessionLink(crafterName, professionID, professionLink)
	elseif previous and previous.professionLink then
		professionLink = previous.professionLink
	else
		professionLink = self:GetRememberedProfessionLink(crafterName, professionID) or ""
	end
	if self.RememberArtisanContact then
		self:RememberArtisanContact(crafterName, sender)
	end
	self.db.customerCache[itemKey][cacheKey] = {
		name = crafterName,
		target = sender,
		orderTarget = crafterName,
		itemID = itemID,
		professionID = professionID,
		priceCopper = priceCopper,
		freeCommission = freeCommission,
		note = note,
		recipeID = recipeID,
		recipeDifficulty = recipeDifficulty,
		totalSkill = totalSkill,
		quality = quality,
		concentrationQuality = concentrationQuality,
		concentrationCost = concentrationCost,
		bestQuality = bestQuality,
		bestConcentrationQuality = bestConcentrationQuality,
		bestTotalSkill = bestTotalSkill,
		bestConcentrationCost = bestConcentrationCost,
		bestOutputItemLevel = bestOutputItemLevel,
		bestReagentTruncated = bestReagentTruncated,
		bestReagents = savedReagents,
		bestReagentSummaryUpdatedAt = previousRecipeID == recipeID and previous and previous.bestReagentSummaryUpdatedAt or nil,
		hasReagentSummary = hasReagentSummary,
		optionalDifficultyDelta = optionalDifficultyDelta,
		optionalQuality = optionalQuality,
		optionalOutputItemLevel = optionalOutputItemLevel,
		optionalConcentrationQuality = optionalConcentrationQuality,
		optionalSlotCount = optionalSlotCount,
		optionalBestReagents = savedOptionalBestReagents,
		optionalBestReagentSummaryUpdatedAt = previousRecipeID == recipeID and previous and previous.optionalBestReagentSummaryUpdatedAt or nil,
		optionalBestReagentTruncated = previousRecipeID == recipeID and previous and previous.optionalBestReagentTruncated or nil,
		professionLink = professionLink ~= "" and professionLink or nil,
		updatedAt = timestamp,
		verifiedAt = verifiedForCurrentQuery and self:Now() or nil,
		lastQueryToken = queryToken,
		lastQueryAt = verifiedForCurrentQuery and self.lastQueryAt or nil,
		guildMember = guildResponse or nil,
		guildOnline = guildResponse and true or nil,
		guildMemberGUID = guildRosterEntry and guildRosterEntry.guid or nil,
		afk = afk or nil,
	}
	if responseReagents then
		self.db.customerCache[itemKey][cacheKey].bestReagentSummaryUpdatedAt = self:Now()
		self.db.customerCache[itemKey][cacheKey].reagentDetailRequested = nil
	end
	self:DebugLog("response", string.format(
		"stored crafter=%s sender=%s item=%s profession=%s queryMatch=%s guild=%s reagents=%s",
		tostring(crafterName or ""),
		tostring(sender or ""),
		tostring(itemID or ""),
		tostring(professionID or ""),
		tostring(verifiedForCurrentQuery == true),
		tostring(guildResponse == true),
		tostring(responseReagents ~= nil)
	))
	self:ApplyPendingReagentDetail(sender, itemID, recipeID, queryToken, crafterName)

	self:RefreshCustomerResults()
end

function AF:GetReagentDetailKey(sender, itemID, recipeID, queryToken, crafterName)
	return table.concat({ sender, crafterName or "", itemID or 0, recipeID or 0, queryToken or 0 }, ":")
end

function AF:IsReagentDetailCacheFresh(entry)
	if not entry or not entry.bestReagents then
		return false
	end
	local updatedAt = tonumber(entry.bestReagentSummaryUpdatedAt)
	return updatedAt and self:Now() - updatedAt < self.REAGENT_DETAIL_CACHE_MAX_AGE
end

function AF:RequestReagentDetail(entry)
	if not entry or entry.tradeLead or self:IsReagentDetailCacheFresh(entry) then
		return false
	end
	if not entry.hasReagentSummary and not entry.bestReagents then
		return false
	end
	local itemID = tonumber(entry.itemID)
	local recipeID = tonumber(entry.recipeID) or 0
	local queryToken = tonumber(entry.lastQueryToken or self.currentCustomerQueryToken)
	local target = self:NormalizeName(entry.target or entry.name)
	local crafterName = self:NormalizeName(entry.orderTarget or entry.name)
	if not itemID or not queryToken or not target then
		return false
	end

	local key = self:GetReagentDetailKey(target, itemID, recipeID, queryToken, crafterName)
	self.reagentDetailRequests = self.reagentDetailRequests or {}
	local now = self:Now()
	local lastRequested = self.reagentDetailRequests[key]
	if lastRequested and now - lastRequested < self.DETAIL_REQUEST_THROTTLE then
		entry.reagentDetailRequested = true
		return false
	end

	local payload = table.concat({
		"DR",
		self.PROTOCOL_VERSION,
		itemID,
		recipeID,
		queryToken,
		self:EncodeField(crafterName, 48),
	}, "|")
	if not self:SendAddon(payload, "WHISPER", target, "NORMAL", table.concat({ "DR", target or "", crafterName or "", itemID, recipeID }, ":")) then
		return false
	end

	self.reagentDetailRequests[key] = now
	entry.reagentDetailRequested = true
	local itemCache = self.db and self.db.customerCache and self.db.customerCache[tostring(itemID)]
	local cachedEntry = itemCache and itemCache[crafterName or target]
	if cachedEntry then
		cachedEntry.reagentDetailRequested = true
	end
	return true
end

function AF:ApplyPendingReagentDetail(sender, itemID, recipeID, queryToken, crafterName)
	if not self.pendingReagentDetails then
		return
	end
	crafterName = self:NormalizeName(crafterName) or sender
	local key = self:GetReagentDetailKey(sender, itemID, recipeID, queryToken, crafterName)
	local pending = self.pendingReagentDetails[key]
	if not pending or (not pending.reagents and not pending.unsupported) then
		return
	end
	local itemCache = self.db.customerCache[tostring(itemID)]
	local entry = itemCache and itemCache[crafterName]
	local entryRecipeID = tonumber(entry and entry.recipeID) or 0
	if entry and tonumber(entry.lastQueryToken) == tonumber(queryToken) and entryRecipeID == (tonumber(recipeID) or 0) then
		if pending.unsupported then
			entry.hasReagentSummary = nil
			entry.reagentDetailRequested = nil
			self.pendingReagentDetails[key] = nil
			return
		end
		entry.bestReagents = pending.reagents or entry.bestReagents
		entry.bestReagentSummaryUpdatedAt = self:Now()
		entry.optionalBestReagents = self:GetDistinctOptionalBestReagents(entry.bestReagents, pending.optionalBestReagents or entry.optionalBestReagents)
		entry.optionalBestReagentSummaryUpdatedAt = entry.optionalBestReagents and self:Now() or nil
		entry.reagentDetailRequested = nil
		self.pendingReagentDetails[key] = nil
	end
end

function AF:HandleReagentDetail(parts, sender)
	local itemID = tonumber(parts[3])
	local recipeID = tonumber(parts[4]) or 0
	local queryToken = tonumber(parts[5])
	local seq = tonumber(parts[6])
	local total = tonumber(parts[7])
	local payload = parts[8]
	local crafterName = self:NormalizeName(self:DecodeField(parts[9])) or sender
	if not itemID or not queryToken or not seq or not total or not payload then
		return
	end
	if queryToken ~= tonumber(self.currentCustomerQueryToken) or itemID ~= tonumber(self.currentCustomerQueryItemID) then
		return
	end
	if seq < 1 or total < 1 or seq > total or total > 8 then
		return
	end

	self.pendingReagentDetails = self.pendingReagentDetails or {}
	local key = self:GetReagentDetailKey(sender, itemID, recipeID, queryToken, crafterName)
	local pending = self.pendingReagentDetails[key]
	if not pending or pending.total ~= total then
		pending = { total = total, chunks = {}, received = 0 }
		self.pendingReagentDetails[key] = pending
	end
	if not pending.chunks[seq] then
		pending.received = pending.received + 1
	end
	pending.chunks[seq] = payload

	if pending.received == pending.total then
		local combined = table.concat(pending.chunks, "")
		local decoded = self:DecodeField(combined)
		if decoded:sub(1, 3) == "R4:" then
			local body = decoded:sub(4)
			local reagentText, optionalText = body:match("^(.-)%s*;%s*O4:(.*)$")
			if not reagentText then
				reagentText, optionalText = body:match("^(.-)\nO4:(.*)$")
			end
			pending.reagents = self:DecodeReagentEntries(reagentText or body)
			pending.optionalBestReagents = optionalText and self:DecodeReagentEntries(optionalText) or nil
		elseif decoded:sub(1, 3) == "R3:" then
			pending.reagents = self:DecodeReagentEntries(decoded:sub(4))
		elseif decoded:sub(1, 3) == "R2:" then
			pending.reagents = self:DecodeReagentEntries(decoded:sub(4))
		elseif decoded:sub(1, 3) == "S1:" then
			pending.unsupported = true
		else
			pending.reagents = self:DecodeReagentEntries(decoded)
		end
		if not pending.reagents then
			pending.unsupported = true
		end
		self:DebugLog("details", string.format(
			"complete crafter=%s sender=%s item=%s recipe=%s chunks=%d unsupported=%s",
			tostring(crafterName or ""),
			tostring(sender or ""),
			tostring(itemID or ""),
			tostring(recipeID or ""),
			tonumber(total) or 0,
			tostring(pending.unsupported == true)
		))
		self:ApplyPendingReagentDetail(sender, itemID, recipeID, queryToken, crafterName)
		self:RefreshCustomerResults()
	end
end
