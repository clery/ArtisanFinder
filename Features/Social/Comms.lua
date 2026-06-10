local _, AF = ...

local COMPRESSED_PAYLOAD_KIND = "Z"

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
			-- GetChannelName returns 0 (not nil) when the channel is unknown
			local id = tonumber(channels[index - 1]) or tonumber(GetChannelName(value))
			if id and id > 0 then
				return id
			end
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
		if AF:IsProtectedActionRestricted() then
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
		if AF:IsProtectedActionRestricted() then
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

local function BuildPayload(parts)
	for index, value in ipairs(parts) do
		parts[index] = tostring(value or "")
	end
	return table.concat(parts, "|")
end

local function HasTablePayloadPart(parts)
	for _, value in ipairs(parts or {}) do
		if type(value) == "table" then
			return true
		end
	end
	return false
end

local function IsOnlineGuildWhisperTarget(AF, target)
	if not AF.GetCachedGuildRosterEntry then
		return false
	end
	local rosterEntry = AF:GetCachedGuildRosterEntry(target)
	return rosterEntry and rosterEntry.online == true
end

local function IsCompactResponse(parts)
	return parts and parts[15] == "C1"
end

function AF:CleanupResponseThrottle(now)
	if not self.responseThrottle then
		return 0
	end
	now = tonumber(now) or self:Now()
	local cleanupInterval = tonumber(self.RESPONSE_THROTTLE_CLEANUP_INTERVAL) or 60
	if self.responseThrottleCleanedAt and now - self.responseThrottleCleanedAt < cleanupInterval then
		-- Throttle keys embed per-query tokens, so the table only shrinks on
		-- cleanup; bypass the interval if it has grown past the cap.
		local maxEntries = tonumber(self.RESPONSE_THROTTLE_MAX_ENTRIES) or 500
		local size = 0
		for _ in pairs(self.responseThrottle) do
			size = size + 1
			if size > maxEntries then
				break
			end
		end
		if size <= maxEntries then
			return 0
		end
	end
	self.responseThrottleCleanedAt = now

	local maxAge = tonumber(self.RESPONSE_THROTTLE_MAX_AGE)
		or math.max(tonumber(self.RESPONSE_THROTTLE) or 0, tonumber(self.DETAIL_REQUEST_THROTTLE) or 0)
	if maxAge <= 0 then
		return 0
	end
	local cutoff = now - maxAge
	local removed = 0
	for key, lastSent in pairs(self.responseThrottle) do
		lastSent = tonumber(lastSent) or 0
		if lastSent <= 0 or lastSent <= cutoff then
			self.responseThrottle[key] = nil
			removed = removed + 1
		end
	end
	return removed
end

function AF:GetCommsCompressionLibraries()
	if self.commsCompressionChecked then
		return self.libSerialize, self.libDeflate
	end
	self.commsCompressionChecked = true
	if LibStub then
		self.libSerialize = LibStub:GetLibrary("LibSerialize", true)
		self.libDeflate = LibStub:GetLibrary("LibDeflate", true)
	end
	return self.libSerialize, self.libDeflate
end

function AF:EncodeCompressedPayloadParts(parts)
	local serializer, deflater = self:GetCommsCompressionLibraries()
	if not serializer or not deflater then
		return nil
	end
	local ok, serialized = pcall(serializer.Serialize, serializer, parts)
	if not ok or type(serialized) ~= "string" then
		return nil
	end
	local compressed = deflater:CompressDeflate(serialized)
	if type(compressed) ~= "string" then
		return nil
	end
	local encoded = deflater:EncodeForWoWAddonChannel(compressed)
	if type(encoded) ~= "string" or encoded == "" then
		return nil
	end
	local payload = BuildPayload({
		COMPRESSED_PAYLOAD_KIND,
		self.PROTOCOL_VERSION,
		encoded,
	})
	return #payload <= 255 and payload or nil
end

function AF:DecodeCompressedPayloadParts(encoded)
	local serializer, deflater = self:GetCommsCompressionLibraries()
	if not serializer or not deflater then
		return nil
	end
	local decoded = deflater:DecodeForWoWAddonChannel(tostring(encoded or ""))
	if type(decoded) ~= "string" then
		return nil
	end
	local decompressed = deflater:DecompressDeflate(decoded)
	if type(decompressed) ~= "string" then
		return nil
	end
	local ok, parts = serializer:Deserialize(decompressed)
	if not ok or type(parts) ~= "table" then
		return nil
	end
	return parts
end

-- Lean wire format for reagent skill facts (single addon message instead of the
-- full facts table, which can exceed the 255-byte payload limit by 4x). Only
-- crafter-specific probe results travel; the customer rebuilds slot structure,
-- reagent lists, quantities, texts, and skill-neutral slots from its own local
-- C_TradeSkillUI.GetRecipeSchematic data (AF:RehydrateWireReagentSkillFacts).
-- Wire keys:
--   w = wire format version (marker distinguishing wire facts from legacy full facts)
--   v = scanModelVersion, s = baseSkill, d = baseRecipeDifficulty, q = maxOutputQuality
--   b = array of required slots with non-zero quality skill bonuses (skill-neutral
--       slots are omitted entirely): i = slotIndex, x = dataSlotIndex,
--       n = quantity, t = { [reagentQuality] = skillBonusPerUnit }
--   o = array of optional reagents that shift recipe difficulty/skill (reagents
--       with no net effect are omitted): m = itemID, d = difficultyDelta (added
--       to recipe difficulty when selected), k = skillDelta (added to total skill
--       when selected). The customer rebuilds optional slot structure locally and
--       matches these deltas onto its schematic reagents by itemID.
local WIRE_FACTS_FORMAT = 2

local function EncodeCompactDeltaNumber(value)
	value = tonumber(value)
	if not value or value == 0 then
		return nil
	end
	if value == math.floor(value) then
		return tostring(value)
	end
	local text = string.format("%.3f", value)
	text = text:gsub("0+$", ""):gsub("%.$", "")
	return text
end

local function DecodeCompactDeltaNumber(value)
	if value == nil or value == "" then
		return nil
	end
	return tonumber(value)
end

local function AddOptionalDeltaToMap(map, itemID, difficultyDelta, skillDelta)
	itemID = tonumber(itemID)
	difficultyDelta = tonumber(difficultyDelta)
	skillDelta = tonumber(skillDelta)
	if not itemID or ((not difficultyDelta or difficultyDelta == 0) and (not skillDelta or skillDelta == 0)) then
		return map
	end
	map = map or {}
	map[itemID] = {
		difficultyDelta = difficultyDelta and difficultyDelta ~= 0 and difficultyDelta or nil,
		skillDelta = skillDelta and skillDelta ~= 0 and skillDelta or nil,
	}
	return map
end

local function BuildOptionalDeltaMapFromWire(wire)
	local map
	for _, reagent in ipairs(type(wire) == "table" and type(wire.o) == "table" and wire.o or {}) do
		map = AddOptionalDeltaToMap(map, reagent.m, reagent.d, reagent.k)
	end
	return map
end

function AF:EncodeCompactOptionalReagentDeltas(facts)
	local entries
	for _, slot in ipairs(type(facts) == "table" and facts.optionalSlots or {}) do
		for _, reagent in ipairs(type(slot.reagents) == "table" and slot.reagents or {}) do
			local itemID = tonumber(reagent.itemID)
			local difficultyDelta = EncodeCompactDeltaNumber(reagent.difficultyDelta)
			local skillDelta = EncodeCompactDeltaNumber(reagent.skillDelta)
			if itemID and (difficultyDelta or skillDelta) then
				entries = entries or {}
				local text = tostring(itemID) .. ":" .. (difficultyDelta or "")
				if skillDelta then
					text = text .. ":" .. skillDelta
				end
				entries[#entries + 1] = text
			end
		end
	end
	return entries and table.concat(entries, ",") or ""
end

function AF:DecodeCompactOptionalReagentDeltas(encoded)
	encoded = tostring(encoded or "")
	if encoded == "" then
		return nil
	end
	local map
	for token in encoded:gmatch("[^,]+") do
		local itemID, difficultyText, skillText = token:match("^(%d+):([^:]*):?([^:]*)$")
		map = AddOptionalDeltaToMap(
			map,
			itemID,
			DecodeCompactDeltaNumber(difficultyText),
			DecodeCompactDeltaNumber(skillText)
		)
	end
	return map
end

function AF:BuildWireReagentSkillFacts(facts)
	if type(facts) ~= "table" or type(facts.requiredSlots) ~= "table" then
		return nil
	end
	local wire = {
		w = WIRE_FACTS_FORMAT,
		v = tonumber(facts.scanModelVersion) or 0,
		s = tonumber(facts.baseSkill) or 0,
		d = tonumber(facts.baseRecipeDifficulty) or 0,
		q = tonumber(facts.maxOutputQuality) or 0,
	}
	local bonusSlots
	for _, slot in ipairs(facts.requiredSlots) do
		local slotBonuses
		for quality, bonus in pairs(type(slot.qualityBonuses) == "table" and slot.qualityBonuses or {}) do
			if tonumber(quality) and (tonumber(bonus) or 0) ~= 0 then
				slotBonuses = slotBonuses or {}
				slotBonuses[tonumber(quality)] = tonumber(bonus)
			end
		end
		if slotBonuses then
			bonusSlots = bonusSlots or {}
			bonusSlots[#bonusSlots + 1] = {
				i = tonumber(slot.slotIndex),
				x = tonumber(slot.dataSlotIndex),
				n = tonumber(slot.quantity) or 1,
				t = slotBonuses,
			}
		end
	end
	wire.b = bonusSlots
	local optionalReagents
	for _, slot in ipairs(facts.optionalSlots or {}) do
		for _, reagent in ipairs(type(slot.reagents) == "table" and slot.reagents or {}) do
			local itemID = tonumber(reagent.itemID)
			local difficultyDelta = tonumber(reagent.difficultyDelta) or 0
			local skillDelta = tonumber(reagent.skillDelta) or 0
			if itemID and (difficultyDelta ~= 0 or skillDelta ~= 0) then
				optionalReagents = optionalReagents or {}
				optionalReagents[#optionalReagents + 1] = {
					m = itemID,
					d = difficultyDelta ~= 0 and difficultyDelta or nil,
					k = skillDelta ~= 0 and skillDelta or nil,
				}
			end
		end
	end
	wire.o = optionalReagents
	return wire
end

function AF:SendAddon(prefixPayload, chatType, target, priority, queueName)
	if self:IsAddonCommsUnavailable() then
		if self:IsDevTrafficLogsEnabled() then
			self:DebugLog("send", string.format("blocked restricted %s %s %s", tostring(chatType or "?"), tostring(target or ""), tostring(prefixPayload or "")))
		end
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

function AF:SendPayloadParts(payloadParts, chatType, target, priority, queueName)
	if HasTablePayloadPart(payloadParts) then
		local compressedPayload = self:EncodeCompressedPayloadParts(payloadParts)
		if compressedPayload then
			return self:SendAddon(compressedPayload, chatType, target, priority, queueName)
		end
		return false
	end
	local payload = BuildPayload(payloadParts)
	if #payload <= 255 then
		return self:SendAddon(payload, chatType, target, priority, queueName)
	end
	local compressedPayload = self:EncodeCompressedPayloadParts(payloadParts)
	if compressedPayload then
		return self:SendAddon(compressedPayload, chatType, target, priority, queueName)
	end
	return false
end

function AF:BuildCompactResponsePayloadParts(item, itemID, responseProfessionID, priceCopper, freeCommission, encodedNote, recipeID, timestamp, encodedLink, queryToken, crafterName, responseTarget, afk, optionalDeltaText)
	return {
		"R",
		self.PROTOCOL_VERSION,
		itemID,
		tonumber(responseProfessionID) or tonumber(item and item.professionID) or 0,
		tonumber(priceCopper) or 0,
		freeCommission and 1 or 0,
		encodedNote,
		tonumber(recipeID) or 0,
		timestamp,
		encodedLink,
		queryToken,
		self:EncodeField(crafterName, 48),
		responseTarget and self:EncodeField(responseTarget, 48) or "",
		afk and 1 or 0,
		"C1",
		tonumber(item and item.recipeDifficulty) or 0,
		tonumber(item and item.totalSkill) or 0,
		tonumber(item and item.quality) or 0,
		tonumber(item and item.concentrationQuality) or 0,
		tonumber(item and item.bestQuality) or 0,
		tonumber(item and item.bestConcentrationQuality) or 0,
		tonumber(item and item.bestTotalSkill) or 0,
		tonumber(item and item.maxOutputQuality) or 0,
		tonumber(item and item.optionalSlotCount) or 0,
		item and item.hasReagentSummary and 1 or ((item and item.bestReagents) and 1 or 0),
		optionalDeltaText or self:EncodeCompactOptionalReagentDeltas(item and item.reagentSkillFacts),
	}
end

function AF:SendCompactResponse(item, itemID, responseProfessionID, priceCopper, freeCommission, note, recipeID, timestamp, professionLink, queryToken, crafterName, responseChannel, responseTarget, afk, queueName)
	local encodedNote = self:EncodeNote(note)
	local encodedLink = self:EncodeField(professionLink)
	local responseTargetName = responseChannel == "GUILD" and responseTarget or nil
	local optionalDeltaText = self:EncodeCompactOptionalReagentDeltas(item and item.reagentSkillFacts)
	local payloadParts = self:BuildCompactResponsePayloadParts(item, itemID, responseProfessionID, priceCopper, freeCommission, encodedNote, recipeID, timestamp, encodedLink, queryToken, crafterName, responseTargetName, afk, optionalDeltaText)
	local payload = BuildPayload(payloadParts)
	if #payload > 255 then
		payloadParts = self:BuildCompactResponsePayloadParts(item, itemID, responseProfessionID, priceCopper, freeCommission, "", recipeID, timestamp, "", queryToken, crafterName, responseTargetName, afk, optionalDeltaText)
		payload = BuildPayload(payloadParts)
	end
	if #payload > 255 and optionalDeltaText ~= "" then
		payloadParts = self:BuildCompactResponsePayloadParts(item, itemID, responseProfessionID, priceCopper, freeCommission, "", recipeID, timestamp, "", queryToken, crafterName, responseTargetName, afk, "")
		payload = BuildPayload(payloadParts)
	end
	if #payload <= 255 then
		return self:SendAddon(payload, responseChannel, responseChannel == "WHISPER" and responseTarget or nil, "NORMAL", queueName)
	end
	return false
end

function AF:BroadcastQuery(itemID, professionID)
	itemID = tonumber(itemID)
	if not itemID then
		return false
	end
	local requestTime = self:Now()
	local normalizedProfessionID = self:GetSupportedProfessionID(professionID) or 0
	if normalizedProfessionID == 0 then
		return false
	end
	if self:IsAddonCommsUnavailable() then
		self.currentCustomerQueryToken = nil
		self.currentCustomerQueryItemID = nil
		self.currentCustomerQueryProfessionID = nil
		self.lastQueryAt = nil
		self.customerQueryBlockedByRestrictionItemID = itemID
		self.customerQueryBlockedByRestrictionProfessionID = normalizedProfessionID
		self:NotifyAddonCommsUnavailable()
		self:DebugLog("query", string.format("blocked restricted item=%s profession=%s", tostring(itemID), tostring(normalizedProfessionID)))
		return false
	end
	self.customerQueryBlockedByRestrictionItemID = nil
	self.customerQueryBlockedByRestrictionProfessionID = nil
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
	local sentOnChannel = false
	local queueName = table.concat({ "Q", itemID, normalizedProfessionID }, ":")
	if channelID and channelID ~= 0 then
		sentOnChannel = self:SendAddon(payload, "CHANNEL", tostring(channelID), "NORMAL", queueName .. ":CHANNEL")
		sent = sentOnChannel or sent
	end
	if IsInGuild and IsInGuild() then
		sent = self:SendAddon(payload, "GUILD", nil, "NORMAL", queueName .. ":GUILD") or sent
	end
	if self.GetOnlineGuildQueryTargets then
		local recipeID = tonumber(self.currentCustomerRecipeID) or 0
		local whisperTargets = self:GetOnlineGuildQueryTargets(normalizedProfessionID, recipeID, 30)
		local skippedWhispers = 0
		local skippedOfflineWhispers = 0
		for _, target in ipairs(whisperTargets) do
			if sentOnChannel and self:IsNameOnConnectedRealm(target) then
				skippedWhispers = skippedWhispers + 1
			elseif not IsOnlineGuildWhisperTarget(self, target) then
				skippedOfflineWhispers = skippedOfflineWhispers + 1
			else
				sent = self:SendAddon(payload, "WHISPER", target, "BULK", queueName .. ":GUILD_WHISPER:" .. tostring(target)) or sent
			end
		end
		if (skippedWhispers > 0 or skippedOfflineWhispers > 0) and self:IsDevTrafficLogsEnabled() then
			self:DebugLog("query", string.format("skipped guild whispers reachableOnChannel=%d offline=%d", skippedWhispers, skippedOfflineWhispers))
		end
	end
	self:DebugLog("query", string.format("sent item=%s profession=%s channel=%s guild=%s result=%s", tostring(itemID), tostring(normalizedProfessionID), tostring(channelID or 0), tostring(IsInGuild and IsInGuild() == true), tostring(sent == true)))
	return sent
end

function AF:IsCustomerQueryBlockedByRestriction(itemID, professionID)
	return self:IsAddonCommsUnavailable()
		and tonumber(self.customerQueryBlockedByRestrictionItemID) == tonumber(itemID)
		and tonumber(self.customerQueryBlockedByRestrictionProfessionID or 0) == tonumber(professionID or self.currentCustomerProfessionID or 0)
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
	if self:IsSecretValue(prefix) or self:IsSecretValue(message) or self:IsSecretValue(channel) or self:IsSecretValue(sender) then
		self:DebugLog("recv", "skipped secret addon payload")
		return
	end
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
	if kind == COMPRESSED_PAYLOAD_KIND then
		parts = self:DecodeCompressedPayloadParts(parts[3]) or {}
		kind, version = parts[1], parts[2]
		if version ~= self.PROTOCOL_VERSION then
			return
		end
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
	elseif kind == "F" then
		self:HandleFulfilledOrderNotification(parts, normalizedSender)
	end
end

local function ItemMatchesQuery(item, itemID, professionID)
	if not item then
		return false
	end
	if not AF:IsCurrentScanModelEntry(item) then
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

	self:CleanupResponseThrottle()
	for _, match in ipairs(matches) do
		local item = match.item
		local crafterName = match.characterName
		local throttleKey = table.concat({ sender, crafterName, itemID, professionID, queryToken }, ":")
		self.responseThrottle = self.responseThrottle or {}
		local lastSent = self.responseThrottle[throttleKey]
		if not lastSent or self:Now() - lastSent >= self.RESPONSE_THROTTLE then
			local priceCopper, freeCommission, note = self:GetItemPriceForProfile(match.profile, itemID, item.professionID)
			local encodedNote = self:EncodeNote(note)
			local responseProfessionID = self:GetSupportedProfessionID(item.professionID, item)
			local profession = match.profile.professions and match.profile.professions[tostring(responseProfessionID or "")]
			local professionLink = (profession and profession.professionLink)
				or self:GetRememberedProfessionLink(crafterName, responseProfessionID)
				or item.professionLink
			if self:IsSecretValue(professionLink) then
				professionLink = nil
			end
			local encodedLink = self:EncodeField(professionLink)
			local responseTimestamp = self:Now()
			local afk = UnitIsAFK and UnitIsAFK("player")
			local wireFacts = self:BuildWireReagentSkillFacts(item.reagentSkillFacts)
			local payloadParts = {
				"R",
				self.PROTOCOL_VERSION,
				itemID,
				tonumber(responseProfessionID) or tonumber(item.professionID) or 0,
				tonumber(priceCopper) or 0,
				freeCommission and 1 or 0,
				encodedNote,
				tonumber(item.recipeID) or 0,
				responseTimestamp,
				encodedLink,
				queryToken,
				self:EncodeField(crafterName, 48),
				channel == "GUILD" and self:EncodeField(requesterName, 48) or "",
				afk and 1 or 0,
				wireFacts,
			}
			local responseChannel = channel == "GUILD" and "GUILD" or "WHISPER"
			local responseTarget = responseChannel == "WHISPER" and sender or nil
			local sent = self:SendPayloadParts(payloadParts, responseChannel, responseTarget, "NORMAL", "R:" .. tostring(sender))
			if sent and self:IsDevTrafficLogsEnabled() then
				self:DebugLog("response", string.format("sent crafter=%s target=%s item=%s profession=%s facts=%s bonusSlots=%d", tostring(crafterName or ""), tostring(responseTarget or requesterName or ""), tostring(itemID or ""), tostring(responseProfessionID or ""), wireFacts and "wire" or "none", wireFacts and #(wireFacts.b or {}) or 0))
			end
			if not sent then
				sent = self:SendCompactResponse(item, itemID, responseProfessionID, priceCopper, freeCommission, note, item.recipeID, responseTimestamp, professionLink, queryToken, crafterName, responseChannel, responseChannel == "GUILD" and requesterName or sender, afk, "R:" .. tostring(sender) .. ":compact")
				if not sent and self:IsDevTrafficLogsEnabled() then
					self:DebugLog("response", string.format("send failed crafter=%s target=%s item=%s profession=%s compact=true", tostring(crafterName or ""), tostring(sender or ""), tostring(itemID or ""), tostring(responseProfessionID or "")))
				end
			end
			if sent then
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

	self:CleanupResponseThrottle()
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
	local queueName = table.concat({ "D", target or "", crafterName or "", item.itemID or 0, item.recipeID or 0, queryToken or 0 }, ":")
	local fullPayload = {
		"D",
		self.PROTOCOL_VERSION,
		tonumber(item.itemID) or 0,
		tonumber(item.recipeID) or 0,
		queryToken,
		1,
		1,
		self:EncodeField(detailText),
		self:EncodeField(crafterName, 48),
	}
	if self:SendPayloadParts(fullPayload, "WHISPER", target, "BULK", queueName) then
		return true
	end

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
	local professionLink = self:DecodeField(parts[10])
	local queryToken = tonumber(parts[11])
	local crafterName = self:NormalizeName(self:DecodeField(parts[12])) or sender
	local responseTarget = self:NormalizeName(self:DecodeField(parts[13]))
	local afk = tonumber(parts[14]) == 1
	local compactResponse = IsCompactResponse(parts)
	local reagentSkillFacts = type(parts[15]) == "table" and parts[15] or nil
	local wireFacts
	local compactOptionalReagentDeltas
	local factsMode
	local cacheKey = crafterName

	if not itemID then
		return
	end
	if compactResponse then
		reagentSkillFacts = nil
		compactOptionalReagentDeltas = self:DecodeCompactOptionalReagentDeltas(parts[26])
		factsMode = "compact"
	elseif reagentSkillFacts and reagentSkillFacts.w ~= nil then
		wireFacts = reagentSkillFacts
		if tonumber(wireFacts.v) ~= tonumber(self.SCAN_MODEL_VERSION) then
			return
		end
		reagentSkillFacts = self.RehydrateWireReagentSkillFacts and self:RehydrateWireReagentSkillFacts(wireFacts, recipeID) or nil
		compactOptionalReagentDeltas = BuildOptionalDeltaMapFromWire(wireFacts)
		factsMode = reagentSkillFacts and "wire" or "wire-rehydrate-failed"
	elseif reagentSkillFacts then
		if not self:IsCurrentScanModelEntry({
			scanModelVersion = reagentSkillFacts.scanModelVersion,
			reagentSkillFacts = reagentSkillFacts,
		}) then
			return
		end
		factsMode = "legacy"
	else
		return
	end
	if responseTarget and responseTarget ~= self:NormalizeName(self.playerName or self:GetPlayerFullName()) then
		return
	end
	local guildResponse = responseTarget ~= nil
	local guildRosterEntry = guildResponse and self:GetCachedGuildRosterEntry(crafterName) or nil
	local validGuildResponse = guildResponse and guildRosterEntry ~= nil
	local guildKey = validGuildResponse and self.GetCurrentGuildCacheKey and self:GetCurrentGuildCacheKey() or nil

	local verifiedForCurrentQuery = queryToken
		and self.currentCustomerQueryToken
		and queryToken == tonumber(self.currentCustomerQueryToken)
		and itemID == tonumber(self.currentCustomerQueryItemID)

	local itemKey = tostring(itemID)
	self.db.customerCache[itemKey] = self.db.customerCache[itemKey] or {}
	local previous = self.db.customerCache[itemKey][cacheKey]
	compactOptionalReagentDeltas = compactOptionalReagentDeltas or (previous and previous.compactOptionalReagentDeltas)
	if not reagentSkillFacts then
		-- Compact response or failed wire rehydration: never downgrade valid
		-- cached detailed facts to synthetic empty ones.
		local previousFacts = previous and previous.reagentSkillFacts
		if previousFacts and previousFacts.compact ~= true and self:IsCurrentScanModelEntry(previous) then
			reagentSkillFacts = previousFacts
			factsMode = factsMode .. "+reused-cached"
		else
			reagentSkillFacts = {
				scanModelVersion = self.SCAN_MODEL_VERSION,
				baseRecipeDifficulty = compactResponse and (tonumber(parts[16]) or 0) or (wireFacts and tonumber(wireFacts.d)) or 0,
				baseSkill = compactResponse and (tonumber(parts[17]) or 0) or (wireFacts and tonumber(wireFacts.s)) or 0,
				maxOutputQuality = compactResponse and (tonumber(parts[23]) or 0) or (wireFacts and tonumber(wireFacts.q)) or 0,
				requiredSlots = {},
				optionalSlots = {},
				compact = true,
			}
		end
	end
	local hasDetailedFacts = reagentSkillFacts.compact ~= true
	local suggestionEntry = {
		recipeID = recipeID,
		itemID = itemID,
		scanModelVersion = reagentSkillFacts.scanModelVersion,
		reagentSkillFacts = reagentSkillFacts,
	}
	local suggestion = hasDetailedFacts and self.BuildReagentSuggestion and self:BuildReagentSuggestion(suggestionEntry) or nil
	local outcome = hasDetailedFacts and self.ComputeCraftOutcome and self:ComputeCraftOutcome(suggestionEntry) or nil
	local savedReagents = suggestion and suggestion.reagents or nil
	local bestQuality = compactResponse and tonumber(parts[20]) or (suggestion and suggestion.quality or nil)
	local bestConcentrationQuality = compactResponse and tonumber(parts[21]) or (suggestion and suggestion.concentrationQuality or nil)
	local bestTotalSkill = compactResponse and tonumber(parts[22]) or (suggestion and suggestion.skill or nil)
	local concentrationQuality = compactResponse and tonumber(parts[19]) or (outcome and outcome.concentrationQuality or nil)
	local quality = compactResponse and tonumber(parts[18]) or (outcome and outcome.quality or nil)
	local recipeDifficulty = compactResponse and tonumber(parts[16]) or tonumber(reagentSkillFacts.baseRecipeDifficulty)
	local totalSkill = compactResponse and tonumber(parts[17]) or tonumber(reagentSkillFacts.baseSkill)
	local optionalSlotCount = compactResponse and tonumber(parts[24]) or #(reagentSkillFacts.optionalSlots or {})
	local hasReagentSummary = compactResponse and tonumber(parts[25]) == 1 or savedReagents ~= nil or wireFacts ~= nil
	if professionLink ~= "" then
		self:RememberProfessionLink(crafterName, professionID, professionLink)
	elseif previous and previous.professionLink then
		professionLink = previous.professionLink
	else
		professionLink = self:GetRememberedProfessionLink(crafterName, professionID) or ""
	end
	if validGuildResponse and self.RememberArtisanContact then
		self:RememberArtisanContact(crafterName, sender, guildKey)
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
		concentrationCost = nil,
		bestQuality = bestQuality,
		bestConcentrationQuality = bestConcentrationQuality,
		bestTotalSkill = bestTotalSkill,
		bestConcentrationCost = nil,
		bestOutputItemLevel = nil,
		bestReagentTruncated = false,
		bestReagents = savedReagents,
		bestReagentSummaryUpdatedAt = savedReagents and self:Now() or nil,
		hasReagentSummary = hasReagentSummary,
		compactOptionalReagentDeltas = compactOptionalReagentDeltas,
		optionalDifficultyDelta = nil,
		optionalQuality = nil,
		optionalOutputItemLevel = nil,
		optionalConcentrationQuality = nil,
		optionalSlotCount = optionalSlotCount,
		optionalBestReagents = nil,
		optionalBestReagentSummaryUpdatedAt = nil,
		optionalBestReagentTruncated = nil,
		scanModelVersion = reagentSkillFacts.scanModelVersion,
		reagentSkillFacts = reagentSkillFacts,
		-- Kept only while facts are synthetic so detailed facts can be
		-- rehydrated later once the local recipe schematic resolves.
		wireReagentSkillFacts = reagentSkillFacts.compact == true and wireFacts or nil,
		maxOutputQuality = reagentSkillFacts.maxOutputQuality,
		professionLink = professionLink ~= "" and professionLink or nil,
		updatedAt = timestamp,
		verifiedAt = verifiedForCurrentQuery and self:Now() or nil,
		lastQueryToken = queryToken,
		lastQueryAt = verifiedForCurrentQuery and self.lastQueryAt or nil,
		guildMember = validGuildResponse or nil,
		guildOnline = validGuildResponse and true or nil,
		guildMemberGUID = guildRosterEntry and guildRosterEntry.guid or nil,
		guildKey = guildKey,
		afk = afk or nil,
	}
	self:DebugLog("response", string.format(
		"stored crafter=%s sender=%s item=%s profession=%s queryMatch=%s guild=%s reagents=%s compact=%s facts=%s",
		tostring(crafterName or ""),
		tostring(sender or ""),
		tostring(itemID or ""),
		tostring(professionID or ""),
		tostring(verifiedForCurrentQuery == true),
		tostring(validGuildResponse == true),
		tostring(savedReagents ~= nil),
		tostring(compactResponse == true),
		tostring(factsMode or "?")
	))
	self:ApplyPendingReagentDetail(sender, itemID, recipeID, queryToken, crafterName)

	self:RefreshCustomerResults()
end

function AF:GetReagentDetailKey(sender, itemID, recipeID, queryToken, crafterName)
	return table.concat({ sender, crafterName or "", itemID or 0, recipeID or 0, queryToken or 0 }, ":")
end

local function CustomerCacheEntryMatchesDetail(AF, entry, sender, recipeID, queryToken, crafterName)
	if not entry then
		return false
	end
	local entryRecipeID = tonumber(entry.recipeID) or 0
	if tonumber(entry.lastQueryToken) ~= tonumber(queryToken) or entryRecipeID ~= (tonumber(recipeID) or 0) then
		return false
	end
	local normalizedCrafter = AF:NormalizeName(crafterName)
	local normalizedSender = AF:NormalizeName(sender)
	for _, name in ipairs({ entry.orderTarget, entry.name, entry.target }) do
		local normalizedName = AF:NormalizeName(name)
		if normalizedName and (normalizedName == normalizedCrafter or normalizedName == normalizedSender) then
			return true
		end
	end
	return false
end

local function FindCustomerCacheEntryForDetail(AF, itemID, sender, recipeID, queryToken, crafterName)
	local itemCache = AF.db and AF.db.customerCache and AF.db.customerCache[tostring(itemID)]
	if not itemCache then
		return nil
	end
	local direct = itemCache[crafterName]
	if CustomerCacheEntryMatchesDetail(AF, direct, sender, recipeID, queryToken, crafterName) then
		return direct
	end
	for _, entry in pairs(itemCache) do
		if CustomerCacheEntryMatchesDetail(AF, entry, sender, recipeID, queryToken, crafterName) then
			return entry
		end
	end
	return nil
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
	local entry = FindCustomerCacheEntryForDetail(self, itemID, sender, recipeID, queryToken, crafterName)
	if entry then
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
			if self.HasAdvancedReagentFacts then
				self:HasAdvancedReagentFacts(entry)
			end
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
	local key = self:GetReagentDetailKey(sender, itemID, recipeID, queryToken, crafterName)
	local expectedCurrentQuery = queryToken == tonumber(self.currentCustomerQueryToken)
		and itemID == tonumber(self.currentCustomerQueryItemID)
	local expectedRequestedDetail = self.reagentDetailRequests and self.reagentDetailRequests[key] ~= nil
	if not expectedCurrentQuery and not expectedRequestedDetail then
		return
	end
	if seq < 1 or total < 1 or seq > total or total > 8 then
		return
	end

	self.pendingReagentDetails = self.pendingReagentDetails or {}
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
		if self.reagentDetailRequests then
			self.reagentDetailRequests[key] = nil
		end
		self:RefreshCustomerResults()
	end
end
