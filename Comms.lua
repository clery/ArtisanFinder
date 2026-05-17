local _, AF = ...

function AF:InitializeComms()
	C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)
	self:JoinDiscoveryChannel()
end

function AF:JoinDiscoveryChannel()
	if GetChannelName(self.CHANNEL_NAME) == 0 then
		if JoinTemporaryChannel then
			JoinTemporaryChannel(self.CHANNEL_NAME)
		else
			JoinChannelByName(self.CHANNEL_NAME)
		end
	end
	self:HideDiscoveryChannelFromChat()
end

function AF:GetDiscoveryChannelID()
	local id = GetChannelName(self.CHANNEL_NAME)
	if id == 0 then
		self:JoinDiscoveryChannel()
		id = GetChannelName(self.CHANNEL_NAME)
	end
	self:HideDiscoveryChannelFromChat()
	return id
end

function AF:HideDiscoveryChannelFromChat()
	if self.discoveryChannelHideQueued then
		return
	end
	self.discoveryChannelHideQueued = true
	C_Timer.After(0.25, function()
		AF.discoveryChannelHideQueued = false
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

function AF:SendAddon(prefixPayload, chatType, target)
	local result = C_ChatInfo.SendAddonMessage(self.PREFIX, prefixPayload, chatType, target)
	return result
end

function AF:BroadcastQuery(itemID, professionID)
	itemID = tonumber(itemID)
	if not itemID then
		return false
	end
	local requestTime = self:Now()
	local normalizedProfessionID = tonumber(professionID) or 0
	self.lastQueryItemID = itemID
	self.lastQueryProfessionID = normalizedProfessionID
	self.lastQueryAt = requestTime
	self.currentCustomerQueryToken = requestTime
	self.currentCustomerQueryItemID = itemID
	self.currentCustomerQueryProfessionID = normalizedProfessionID

	local channelID = self:GetDiscoveryChannelID()
	if not channelID or channelID == 0 then
		return false
	end

	local payload = table.concat({
		"Q",
		self.PROTOCOL_VERSION,
		itemID,
		normalizedProfessionID,
		requestTime,
	}, "|")

	self:SendAddon(payload, "CHANNEL", tostring(channelID))
	return true
end

function AF:QueueBroadcastQuery(itemID, professionID)
	itemID = tonumber(itemID)
	if not itemID then
		return false
	end
	self.pendingCustomerQueryItemID = itemID
	self.pendingCustomerQueryProfessionID = tonumber(professionID) or 0
	if self.customerQueryQueued then
		return true
	end
	self.customerQueryQueued = true
	C_Timer.After(0.2, function()
		AF.customerQueryQueued = false
		local pendingItemID = AF.pendingCustomerQueryItemID
		local pendingProfessionID = AF.pendingCustomerQueryProfessionID
		AF.pendingCustomerQueryItemID = nil
		AF.pendingCustomerQueryProfessionID = nil
		if pendingItemID and tonumber(AF.currentCustomerItemID) == tonumber(pendingItemID) then
			AF:BroadcastQuery(pendingItemID, pendingProfessionID)
			if AF.RefreshCustomerResults then
				AF:RefreshCustomerResults()
			end
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

	if kind == "Q" then
		self:HandleQuery(parts, normalizedSender)
	elseif kind == "R" then
		self:HandleResponse(parts, normalizedSender)
	elseif kind == "DR" then
		self:HandleReagentDetailRequest(parts, normalizedSender)
	elseif kind == "D" then
		self:HandleReagentDetail(parts, normalizedSender)
	end
end

function AF:HandleQuery(parts, sender)
	if not self.available then
		return
	end

	local itemID = tonumber(parts[3])
	local professionID = tonumber(parts[4]) or 0
	local queryToken = tonumber(parts[5]) or self:Now()
	if not itemID then
		return
	end

	local item = self.db.artisanProfile.items[tostring(itemID)]
	if not item then
		return
	end

	local throttleKey = table.concat({ sender, itemID, professionID, queryToken }, ":")
	local lastSent = self.db.responseThrottle[throttleKey]
	if lastSent and self:Now() - lastSent < self.RESPONSE_THROTTLE then
		return
	end

	local priceCopper, freeCommission, note = self:GetItemPrice(itemID, item.professionID)
	local encodedNote = self:EncodeNote(note)
	local encodedLink = self:EncodeField(item.professionLink)
	local payloadParts = {
		"R",
		self.PROTOCOL_VERSION,
		itemID,
		tonumber(item.professionID) or 0,
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
		self:EncodeField(item.qualityAtlas, 48),
		self:EncodeField(item.bestQualityAtlas, 48),
		item.bestReagentSummary and item.bestReagentSummary ~= "" and 1 or 0,
	}
	local payload = table.concat(payloadParts, "|")
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
		payloadParts[21] = ""
		payloadParts[22] = ""
		payloadParts[23] = ""
		payloadParts[24] = ""
		payload = table.concat(payloadParts, "|")
	end

	self:SendAddon(payload, "WHISPER", sender)
	self.db.responseThrottle[throttleKey] = self:Now()
end

function AF:HandleReagentDetailRequest(parts, sender)
	if not self.available then
		return
	end

	local itemID = tonumber(parts[3])
	local recipeID = tonumber(parts[4]) or 0
	local queryToken = tonumber(parts[5])
	if not itemID or not queryToken then
		return
	end

	local item = self.db.artisanProfile.items[tostring(itemID)]
	if not item or not item.bestReagentSummary or item.bestReagentSummary == "" then
		return
	end
	if recipeID ~= 0 and tonumber(item.recipeID) ~= recipeID then
		return
	end

	local throttleKey = table.concat({ "D", sender, itemID, recipeID, queryToken }, ":")
	local lastSent = self.db.responseThrottle[throttleKey]
	if lastSent and self:Now() - lastSent < self.DETAIL_REQUEST_THROTTLE then
		return
	end

	self:SendReagentDetail(item, sender, queryToken)
	self.db.responseThrottle[throttleKey] = self:Now()
end

function AF:SendReagentDetail(item, target, queryToken)
	local summary = item and item.bestReagentSummary
	if not summary or summary == "" then
		return
	end

	local encodedSummary = self:EncodeReagentSummary(summary, 1050)
	local chunks = {}
	local maxChunkBytes = 150
	local offset = 1
	while offset <= #encodedSummary do
		table.insert(chunks, encodedSummary:sub(offset, offset + maxChunkBytes - 1))
		offset = offset + maxChunkBytes
	end

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
		}, "|")
		self:SendAddon(payload, "WHISPER", target)
	end
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
	local qualityAtlas = self:DecodeField(parts[22])
	local bestQualityAtlas = self:DecodeField(parts[23])
	local hasReagentSummary = tonumber(parts[24]) == 1

	if not itemID then
		return
	end

	local verifiedForCurrentQuery = queryToken
		and self.currentCustomerQueryToken
		and queryToken == tonumber(self.currentCustomerQueryToken)
		and itemID == tonumber(self.currentCustomerQueryItemID)

	local itemKey = tostring(itemID)
	self.db.customerCache[itemKey] = self.db.customerCache[itemKey] or {}
	local previous = self.db.customerCache[itemKey][sender]
	local previousRecipeID = tonumber(previous and previous.recipeID) or 0
	self.db.customerCache[itemKey][sender] = {
		name = sender,
		itemID = itemID,
		professionID = professionID,
		professionName = self:GetProfessionName(professionID),
		priceCopper = priceCopper,
		freeCommission = freeCommission,
		note = note,
		recipeID = recipeID,
		recipeDifficulty = recipeDifficulty,
		totalSkill = totalSkill,
		quality = quality,
		qualityAtlas = qualityAtlas ~= "" and qualityAtlas or nil,
		concentrationQuality = concentrationQuality,
		concentrationCost = concentrationCost,
		bestQuality = bestQuality,
		bestQualityAtlas = bestQualityAtlas ~= "" and bestQualityAtlas or nil,
		bestConcentrationQuality = bestConcentrationQuality,
		bestTotalSkill = bestTotalSkill,
		bestConcentrationCost = bestConcentrationCost,
		bestReagentTruncated = bestReagentTruncated,
		bestReagentSummary = previousRecipeID == recipeID and previous and previous.bestReagentSummary or nil,
		hasReagentSummary = hasReagentSummary,
		professionLink = professionLink ~= "" and professionLink or nil,
		updatedAt = timestamp,
		verifiedAt = verifiedForCurrentQuery and self:Now() or nil,
		lastQueryToken = queryToken,
		lastQueryAt = verifiedForCurrentQuery and self.lastQueryAt or nil,
	}
	self:ApplyPendingReagentDetail(sender, itemID, recipeID, queryToken)

	if self.RefreshCustomerResults then
		self:RefreshCustomerResults()
	end
end

function AF:GetReagentDetailKey(sender, itemID, recipeID, queryToken)
	return table.concat({ sender, itemID or 0, recipeID or 0, queryToken or 0 }, ":")
end

function AF:RequestReagentDetail(entry)
	if not entry or entry.tradeLead or entry.bestReagentSummary or not entry.hasReagentSummary then
		return false
	end
	local itemID = tonumber(entry.itemID)
	local recipeID = tonumber(entry.recipeID) or 0
	local queryToken = tonumber(entry.lastQueryToken or self.currentCustomerQueryToken)
	local target = self:NormalizeName(entry.target or entry.name)
	if not itemID or not queryToken or not target then
		return false
	end

	local key = self:GetReagentDetailKey(target, itemID, recipeID, queryToken)
	self.reagentDetailRequests = self.reagentDetailRequests or {}
	local now = self:Now()
	local lastRequested = self.reagentDetailRequests[key]
	if lastRequested and now - lastRequested < self.DETAIL_REQUEST_THROTTLE then
		entry.reagentDetailRequested = true
		return false
	end

	self.reagentDetailRequests[key] = now
	entry.reagentDetailRequested = true
	local itemCache = self.db and self.db.customerCache and self.db.customerCache[tostring(itemID)]
	local cachedEntry = itemCache and itemCache[target]
	if cachedEntry then
		cachedEntry.reagentDetailRequested = true
	end

	local payload = table.concat({
		"DR",
		self.PROTOCOL_VERSION,
		itemID,
		recipeID,
		queryToken,
	}, "|")
	self:SendAddon(payload, "WHISPER", target)
	return true
end

function AF:ApplyPendingReagentDetail(sender, itemID, recipeID, queryToken)
	if not self.pendingReagentDetails then
		return
	end
	local key = self:GetReagentDetailKey(sender, itemID, recipeID, queryToken)
	local pending = self.pendingReagentDetails[key]
	if not pending or not pending.summary then
		return
	end
	local itemCache = self.db.customerCache[tostring(itemID)]
	local entry = itemCache and itemCache[sender]
	local entryRecipeID = tonumber(entry and entry.recipeID) or 0
	if entry and tonumber(entry.lastQueryToken) == tonumber(queryToken) and entryRecipeID == (tonumber(recipeID) or 0) then
		entry.bestReagentSummary = pending.summary
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
	local key = self:GetReagentDetailKey(sender, itemID, recipeID, queryToken)
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
		pending.summary = self:DecodeField(combined)
		self:ApplyPendingReagentDetail(sender, itemID, recipeID, queryToken)
		if self.RefreshCustomerResults then
			self:RefreshCustomerResults()
		end
	end
end
