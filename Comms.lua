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
end

function AF:GetDiscoveryChannelID()
	local id = GetChannelName(self.CHANNEL_NAME)
	if id == 0 then
		self:JoinDiscoveryChannel()
		id = GetChannelName(self.CHANNEL_NAME)
	end
	return id
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
	if professionID ~= 0 and tonumber(item.professionID) ~= professionID then
		return
	end

	local throttleKey = table.concat({ sender, itemID, professionID }, ":")
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

	self:SendAddon(payload, "WHISPER", sender)
	self.db.responseThrottle[throttleKey] = self:Now()
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

	if not itemID then
		return
	end

	local verifiedForCurrentQuery = queryToken
		and self.currentCustomerQueryToken
		and queryToken == tonumber(self.currentCustomerQueryToken)
		and itemID == tonumber(self.currentCustomerQueryItemID)
		and ((tonumber(self.currentCustomerQueryProfessionID) or 0) == 0 or professionID == tonumber(self.currentCustomerQueryProfessionID))

	local itemKey = tostring(itemID)
	self.db.customerCache[itemKey] = self.db.customerCache[itemKey] or {}
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
		concentrationQuality = concentrationQuality,
		concentrationCost = concentrationCost,
		professionLink = professionLink ~= "" and professionLink or nil,
		updatedAt = timestamp,
		verifiedAt = verifiedForCurrentQuery and self:Now() or nil,
		lastQueryToken = queryToken,
		lastQueryAt = verifiedForCurrentQuery and self.lastQueryAt or nil,
	}

	if self.RefreshCustomerResults then
		self:RefreshCustomerResults()
	end
end
