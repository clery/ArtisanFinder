local _, AF = ...

local SCAN_PROBE_JOB_DELAY = 0.05
local SCAN_FULL_JOB_DELAY = 0.25
local FAST_SCAN_PROBE_JOB_DELAY = 0.01
local FAST_SCAN_FULL_JOB_DELAY = 0.01
local FAST_SCAN_PROBE_JOBS_PER_TICK = 25
local FAST_SCAN_FULL_JOBS_PER_TICK = 4
local FAST_SCAN_TICK_BUDGET_MS = 8
local SLOW_SCAN_TICK_WARNING_MS = 1000
local SCAN_GC_STEP_SIZE = 32
local HEAVY_JOB_QUALITY_TIER_THRESHOLD = 12

local function GetScanTimeMS()
	if debugprofilestop then
		return debugprofilestop()
	end
	return GetTime() * 1000
end

local function GetScanJobKey(recipeID, itemID)
	return tostring(recipeID or 0) .. ":" .. tostring(itemID or 0)
end

local function CopyScanItem(item)
	local copy = {}
	for key, value in pairs(item or {}) do
		copy[key] = value
	end
	return copy
end

local function GetRecommendationSnapshot(item)
	if not item then
		return ""
	end
	return table.concat({
		tostring(item.bestReagentSignature or ""),
		tostring(item.bestQuality or ""),
		tostring(item.bestQualityAtlas or ""),
		tostring(item.bestOutputItemLevel or ""),
		tostring(item.rawBestQuality or ""),
		tostring(item.bestReagentTruncated == true),
		tostring(item.bestReagentPendingNames == true),
		tostring(item.optionalDifficultyDelta or ""),
		tostring(item.optionalQuality or ""),
		tostring(item.optionalOutputItemLevel or ""),
		tostring(item.optionalConcentrationQuality or ""),
		tostring(item.optionalBestReagentSignature or ""),
		tostring(item.optionalBestReagentTruncated == true),
	}, "|")
end

local function GetProfessionEquipmentState(profession)
	if not profession then
		return nil
	end
	local candidateIDs = {
		profession.id,
		profession.parentProfessionID,
		profession.skillLineID,
	}
	for _, professionID in ipairs(candidateIDs) do
		professionID = tonumber(professionID)
		if professionID then
			local ok, slots = pcall(C_TradeSkillUI.GetProfessionSlots, professionID)
			if ok and type(slots) == "table" and next(slots) then
				local parts = {}
				for _, slotID in ipairs(slots) do
					local link = GetInventoryItemLink and GetInventoryItemLink("player", slotID)
					table.insert(parts, tostring(slotID) .. "=" .. tostring(link or "empty"))
				end
				return {
					professionID = professionID,
					signature = professionID .. ":" .. table.concat(parts, "|"),
				}
			end
		end
	end
	return nil
end

local function GetProfessionEntry(AF, professionOrID)
	local professionID = type(professionOrID) == "table" and professionOrID.id or professionOrID
	local profile = AF.db and AF.db.artisanProfile
	return profile and profile.professions and profile.professions[tostring(professionID)]
end

function AF:IsSkillProbeScanReason(reason)
	return reason == "SKILL_LINES_CHANGED"
		or reason == "SPELLS_CHANGED"
		or reason == "PROFESSION_EQUIPMENT_CHANGED"
		or reason == "TRAIT_CONFIG_UPDATED"
		or reason == "TRAIT_PENDING_APPLIED"
end

function AF:GetCurrentProfessionEquipmentSignature(profession)
	local state = GetProfessionEquipmentState(profession)
	return state and state.signature or nil
end

function AF:GetCurrentProfessionEquipmentState(profession)
	return GetProfessionEquipmentState(profession)
end

function AF:StoreBestProfessionEquipmentState(profession, state)
	local professionEntry = profession and GetProfessionEntry(self, profession)
	if not professionEntry or type(state) ~= "table" then
		return
	end
	professionEntry.equipmentSignature = state.signature or professionEntry.equipmentSignature
end

function AF:GetProfessionEquipmentSignatureChanged(profession)
	local state = self:GetCurrentProfessionEquipmentState(profession)
	local signature = state and state.signature
	if not signature then
		return false
	end
	local professionEntry = GetProfessionEntry(self, profession)
	if not professionEntry then
		return false
	end
	local changed = professionEntry.equipmentSignature and professionEntry.equipmentSignature ~= signature
	professionEntry.equipmentSignature = signature
	return changed == true
end

function AF:ShouldQueueProfessionEquipmentScan(profession)
	local professionEntry = profession and GetProfessionEntry(self, profession)
	if not professionEntry then
		return false
	end
	local snapshots = self:GetCurrentProfessionSkillSnapshots(profession)
	if type(snapshots) == "table" then
		local savedTotals = professionEntry.bestProfessionSkillTotals
		if type(savedTotals) ~= "table" then
			self:StoreBestProfessionSkillSnapshots(profession, snapshots)
			return false
		end
		local sawComparableSkill = false
		for key, snapshot in pairs(snapshots) do
			local currentSkill = tonumber(snapshot.totalSkill)
			local bestSkill = tonumber(savedTotals[key])
			if currentSkill and bestSkill then
				sawComparableSkill = true
				if currentSkill > bestSkill then
					return true
				end
			end
		end
		if sawComparableSkill then
			return false
		end
		self:StoreBestProfessionSkillSnapshots(profession, snapshots)
		return false
	end
	return false
end

function AF:RestartActiveScanForEquipmentUpgrade(profession)
	if not self:IsOwnProfessionWindowOpen() then
		return false
	end
	if not self.activeScan or not profession or tonumber(self.activeScan.professionID) ~= tonumber(profession.id) then
		return false
	end
	if not self:ShouldQueueProfessionEquipmentScan(profession) then
		return false
	end
	local professionEntry = GetProfessionEntry(self, profession)
	if professionEntry then
		professionEntry.scanProgress = nil
		professionEntry.scanSignature = nil
	end
	self.activeScan = nil
	self.scanProcessing = false
	self.scanQueueToken = (self.scanQueueToken or 0) + 1
	self.pendingProfessionEquipmentScan = true
	self.pendingAutoScanReason = "PROFESSION_EQUIPMENT_CHANGED"
	self:StartOrResumeCurrentProfessionScan(false, true, "probe", true, "PROFESSION_EQUIPMENT_CHANGED")
	return true
end

function AF:GetProfessionSavedItemCount(professionID)
	local profile = self.db and self.db.artisanProfile
	if not profile or not profile.items then
		return 0
	end
	local count = 0
	for _, item in pairs(profile.items) do
		if tonumber(item.professionID) == tonumber(professionID) then
			count = count + 1
		end
	end
	return count
end

function AF:AddProfessionSkillSnapshot(snapshots, info)
	if type(info) ~= "table" then
		return
	end
	local professionID = tonumber(info.professionID)
	if not professionID then
		return
	end
	local skillLevel = tonumber(info.skillLevel) or 0
	local skillModifier = tonumber(info.skillModifier) or 0
	snapshots[tostring(professionID)] = {
		id = professionID,
		skillLevel = skillLevel,
		skillModifier = skillModifier,
		totalSkill = skillLevel + skillModifier,
		maxSkillLevel = tonumber(info.maxSkillLevel) or 0,
	}
end

function AF:ProfessionSkillInfoMatchesCurrentProfession(profession, info)
	if not profession or type(info) ~= "table" then
		return false
	end
	local professionID = tonumber(info.professionID)
	local parentProfessionID = tonumber(info.parentProfessionID)
	local currentParentID = tonumber(profession.parentProfessionID)
	return professionID == tonumber(profession.id)
		or professionID == tonumber(profession.skillLineID)
		or (currentParentID and parentProfessionID == currentParentID)
		or parentProfessionID == tonumber(profession.id)
end

function AF:GetCurrentProfessionSkillSnapshots(profession)
	if not profession then
		return nil
	end
	local snapshots = {}
	local okChildren, childInfos = pcall(C_TradeSkillUI.GetChildProfessionInfos)
	if okChildren and type(childInfos) == "table" then
		for _, info in ipairs(childInfos) do
			if self:ProfessionSkillInfoMatchesCurrentProfession(profession, info) then
				self:AddProfessionSkillSnapshot(snapshots, info)
			end
		end
	end
	local okChild, info = pcall(C_TradeSkillUI.GetChildProfessionInfo)
	if okChild then
		self:AddProfessionSkillSnapshot(snapshots, info)
	end
	local okProfession, skillInfo = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, profession.id)
	if okProfession then
		self:AddProfessionSkillSnapshot(snapshots, skillInfo)
	end
	return next(snapshots) and snapshots or nil
end

function AF:GetSavedProfessionSkillTotals(profession)
	local professionEntry = profession and GetProfessionEntry(self, profession)
	return professionEntry and professionEntry.bestProfessionSkillTotals or nil
end

function AF:StoreBestProfessionSkillSnapshots(profession, snapshots)
	local professionEntry = profession and GetProfessionEntry(self, profession)
	if not professionEntry or type(snapshots) ~= "table" then
		return
	end
	professionEntry.bestProfessionSkillTotals = professionEntry.bestProfessionSkillTotals or {}
	for key, snapshot in pairs(snapshots) do
		local totalSkill = tonumber(snapshot.totalSkill)
		if totalSkill and totalSkill > (tonumber(professionEntry.bestProfessionSkillTotals[key]) or 0) then
			professionEntry.bestProfessionSkillTotals[key] = totalSkill
			professionEntry.bestProfessionSkillAt = self:Now()
		end
	end
end

function AF:PrepareProfessionForScan(profession)
	if not self:IsOwnProfessionWindowOpen() then
		return nil
	end

	local profile = self.db.artisanProfile
	local supportedProfessionID = self:GetSupportedProfessionID(profession.id, profession)
	if not supportedProfessionID then
		return nil
	end
	profession.id = supportedProfessionID
	local professionKey = tostring(supportedProfessionID)
	profile.professions[professionKey] = profile.professions[professionKey] or {
		id = supportedProfessionID,
		recipes = {},
		updatedAt = self:Now(),
	}
	local professionEntry = profile.professions[professionKey]
	professionEntry.id = supportedProfessionID
	professionEntry.name = nil
	professionEntry.parentProfessionID = profession.parentProfessionID
	professionEntry.skillLineID = profession.skillLineID
	professionEntry.childProfessionID = profession.childProfessionID
	professionEntry.icon = professionEntry.icon or profession.icon
	professionEntry.updatedAt = self:Now()
	professionEntry.professionLink = self:CaptureCurrentProfessionLink(profession) or professionEntry.professionLink
	professionEntry.recipes = professionEntry.recipes or {}
	self:StoreBestProfessionEquipmentState(profession, self:GetCurrentProfessionEquipmentState(profession))
	self:StoreBestProfessionSkillSnapshots(profession, self:GetCurrentProfessionSkillSnapshots(profession))
	return professionEntry
end

function AF:BuildScanProgress(profession, professionEntry, signature, force, mode, reason)
	local recipeIDs = self:GetCurrentProfessionRecipeIDs(profession)
	if type(recipeIDs) ~= "table" then
		return nil, self:Text("SCAN_NO_RECIPES")
	end

	mode = force and "full" or (mode or "probe")
	local progressSignature = table.concat({ signature, mode }, "|")
	local previous = professionEntry.scanProgress
	local completed = {}
	if not force and previous and previous.signature == progressSignature and type(previous.completed) == "table" then
		completed = previous.completed
	end
	local completedCount = self:TableCount(completed)

	local profile = self.db.artisanProfile
	local pending = {}
	for _, recipeID in ipairs(recipeIDs) do
		local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
		local learned = not recipeInfo or recipeInfo.learned ~= false
		if learned then
			local outputs = self:GetRecipeOutputItemIDs(recipeID)
			for itemID in pairs(outputs) do
				local key = mode .. ":" .. GetScanJobKey(recipeID, itemID)
				local existing = profile.items[tostring(itemID)]
				local needsFull = force
					or not existing
					or tonumber(existing.recipeID) ~= tonumber(recipeID)
					or tonumber(existing.professionID) ~= tonumber(profession.id)
					or not existing.bestReagents
					or existing.bestReagentPendingNames == true
				if force or not completed[key] then
					table.insert(pending, {
						key = key,
						kind = needsFull and "full" or mode,
						recipeID = recipeID,
						itemID = itemID,
					})
				end
			end
		end
	end

	professionEntry.scanProgress = {
		signature = progressSignature,
		professionSignature = signature,
		mode = mode,
		pending = pending,
		pendingTotal = #pending,
		completed = completed,
		completedCount = completedCount,
		total = #pending + completedCount,
		scanned = completedCount,
		recommendationsUpdated = previous and previous.signature == progressSignature and tonumber(previous.recommendationsUpdated) or 0,
		skillUpgrades = previous and previous.signature == progressSignature and tonumber(previous.skillUpgrades) or 0,
		skillDowngradesSkipped = previous and previous.signature == progressSignature and tonumber(previous.skillDowngradesSkipped) or 0,
		reason = reason,
		startedAt = previous and previous.startedAt or self:Now(),
		updatedAt = self:Now(),
	}
	return professionEntry.scanProgress
end

local function GetPendingIndex(progress)
	return math.max(1, tonumber(progress and progress.pendingIndex) or 1)
end

local function GetPendingTotal(progress)
	return tonumber(progress and progress.pendingTotal) or #(progress and progress.pending or {})
end

local function GetPendingCount(progress)
	local pending = progress and progress.pending
	if not pending then
		return 0
	end
	return math.max(0, GetPendingTotal(progress) - GetPendingIndex(progress) + 1)
end

local function GetNextPendingJob(progress)
	local pending = progress and progress.pending
	return pending and pending[GetPendingIndex(progress)]
end

local function AppendPendingJob(progress, job)
	if not progress or not progress.pending or not job then
		return
	end
	local index = GetPendingTotal(progress) + 1
	progress.pending[index] = job
	progress.pendingTotal = index
end

function AF:IsLowerOrEqualEquipmentProbe(existing, probe)
	if not existing or not probe then
		return false
	end
	local existingSkill = tonumber(existing.totalSkill)
	local probedSkill = tonumber(probe.totalSkill)
	if not existingSkill or not probedSkill then
		return false
	end
	return probedSkill <= existingSkill
end

function AF:ScanJob(profession, professionEntry, job)
	if not self:IsOwnProfessionWindowOpen() then
		self:PauseActiveProfessionScan(true)
		return false
	end
	local recipeInfo = C_TradeSkillUI.GetRecipeInfo(job.recipeID)
	if not self:RecipeBelongsToProfession(profession, recipeInfo, self:GetCurrentProfessionCategoryIDs(), job.recipeID) then
		return "skipped"
	end
	local profile = self.db.artisanProfile
	local itemKey = tostring(job.itemID)
	local savedItem = profile.items[itemKey]
	local existing = CopyScanItem(savedItem)
	if job.kind ~= "probe" then
		profile.items[itemKey] = existing
	end
	existing.itemID = job.itemID
	existing.recipeID = job.recipeID
	existing.professionID = profession.id
	existing.itemName = nil
	existing.recipeName = nil
	existing.professionName = nil
	if job.kind == "probe" then
		local probe = self:GetRecipeSkillProbe(job.recipeID)
		if probe then
			if professionEntry.scanProgress and professionEntry.scanProgress.reason == "PROFESSION_EQUIPMENT_CHANGED" and self:IsLowerOrEqualEquipmentProbe(existing, probe) then
				professionEntry.scanProgress.skillDowngradesSkipped = (tonumber(professionEntry.scanProgress.skillDowngradesSkipped) or 0) + 1
				return
			end
			local equipmentSkillUpgrade = professionEntry.scanProgress
				and professionEntry.scanProgress.reason == "PROFESSION_EQUIPMENT_CHANGED"
				and tonumber(probe.totalSkill)
				and savedItem
				and tonumber(savedItem.totalSkill)
				and tonumber(probe.totalSkill) > tonumber(savedItem.totalSkill)
			if equipmentSkillUpgrade then
				professionEntry.scanProgress.skillUpgrades = (tonumber(professionEntry.scanProgress.skillUpgrades) or 0) + 1
			end
			local needsFull = equipmentSkillUpgrade or self:ProbeRequiresFullScan(savedItem, job.recipeID, job.itemID, probe)
			if not needsFull then
				self:ApplyRecipeSkillProbe(existing, job.recipeID, probe)
				profile.items[itemKey] = existing
			end
			if needsFull then
				local qualityTierCombinations = self:EstimateRecipeQualityTierCombinations(job.recipeID)
				AppendPendingJob(professionEntry.scanProgress, {
					key = "full:" .. GetScanJobKey(job.recipeID, job.itemID),
					kind = "full",
					recipeID = job.recipeID,
					itemID = job.itemID,
					qualityTierCombinations = qualityTierCombinations,
				})
				professionEntry.scanProgress.total = professionEntry.scanProgress.total + 1
				return true
			end
		else
			local qualityTierCombinations = self:EstimateRecipeQualityTierCombinations(job.recipeID)
			AppendPendingJob(professionEntry.scanProgress, {
				key = "full:" .. GetScanJobKey(job.recipeID, job.itemID),
				kind = "full",
				recipeID = job.recipeID,
				itemID = job.itemID,
				qualityTierCombinations = qualityTierCombinations,
			})
			professionEntry.scanProgress.total = professionEntry.scanProgress.total + 1
			return true
		end
	else
		local beforeRecommendation = GetRecommendationSnapshot(existing)
		self:ApplyRecipeCapability(existing, job.recipeID)
		local afterRecommendation = GetRecommendationSnapshot(existing)
		if beforeRecommendation ~= afterRecommendation and existing.bestReagents then
			professionEntry.scanProgress.recommendationsUpdated = (tonumber(professionEntry.scanProgress.recommendationsUpdated) or 0) + 1
		end
	end
	existing.updatedAt = self:Now()
	professionEntry.recipes[tostring(job.recipeID)] = true
	return true
end

function AF:IsCurrentProfessionScanAvailable(professionID)
	if not C_TradeSkillUI.IsTradeSkillReady() then
		return false
	end
	if not self:IsOwnProfessionWindowOpen() then
		return false
	end
	local current = self:GetCurrentProfessionInfo()
	return current and tonumber(current.id) == tonumber(professionID)
end

function AF:GetActiveScanProgress()
	local active = self.activeScan
	if not active or not active.professionID then
		return nil
	end
	if not self:IsCurrentProfessionScanAvailable(active.professionID) then
		self.activeScan = nil
		return nil
	end

	local professionEntry = GetProfessionEntry(self, active.professionID)
	local progress = professionEntry and professionEntry.scanProgress
	if not progress or progress.signature ~= active.signature then
		self.activeScan = nil
		return nil
	end

	return active, professionEntry, progress
end

function AF:GetCurrentProfessionScanPercent(profession)
	local active, _, progress = self:GetActiveScanProgress()
	if not active or not progress or not profession or tonumber(active.professionID) ~= tonumber(profession.id) then
		return nil
	end

	local total = tonumber(progress.total) or 0
	if total <= 0 then
		return 0
	end

	local completed = tonumber(progress.completedCount) or self:TableCount(progress.completed)
	local percent = math.floor((completed / total) * 100)
	if percent < 0 then
		return 0
	end
	if percent > 100 then
		return 100
	end
	return percent
end

function AF:RefreshScanProgressUI(force)
	if self.activeScan then
		self.scanRefreshCounter = 0
		if self.UpdateCrafterScanProgressText then
			self:UpdateCrafterScanProgressText()
		end
		return
	end

	self.scanRefreshCounter = (self.scanRefreshCounter or 0) + 1
	if force or self.scanRefreshCounter >= 8 then
		self.scanRefreshCounter = 0
		self:RefreshCrafterUI()
		self:RefreshMinimap()
	end
end

function AF:GetScanJobDelay(job)
	if self.db and self.db.fastScan == true then
		if job and job.kind == "full" then
			return FAST_SCAN_FULL_JOB_DELAY
		end
		return FAST_SCAN_PROBE_JOB_DELAY
	end
	if job and job.kind == "full" then
		return SCAN_FULL_JOB_DELAY
	end
	return SCAN_PROBE_JOB_DELAY
end

function AF:GetScanJobsPerTick(job)
	if not self.db or self.db.fastScan ~= true then
		return 1
	end
	if job and job.kind == "full" then
		if job.qualityTierCombinations and job.qualityTierCombinations > HEAVY_JOB_QUALITY_TIER_THRESHOLD then
			return 1
		end
		return FAST_SCAN_FULL_JOBS_PER_TICK
	end
	return FAST_SCAN_PROBE_JOBS_PER_TICK
end

function AF:CompleteActiveScan(active, professionEntry, progress)
	professionEntry.scanSignature = progress.professionSignature or progress.signature
	professionEntry.scanMode = progress.mode
	professionEntry.scannedAt = self:Now()
	professionEntry.scanProgress = nil
	self.activeScan = nil
	self.lastCompletedScan = {
		professionID = active.professionID,
		signature = progress.signature,
		completedAt = self:Now(),
	}
	self:RefreshScanProgressUI(true)
	self:RefreshOptionsPanel()
	local currentProfession = self:GetCurrentProfessionInfo()
	if not currentProfession or tonumber(currentProfession.id) ~= tonumber(active.professionID) then
		currentProfession = { id = active.professionID }
	end
	self:StoreBestProfessionEquipmentState(currentProfession, self:GetCurrentProfessionEquipmentState(currentProfession))
	self:StoreBestProfessionSkillSnapshots(currentProfession, self:GetCurrentProfessionSkillSnapshots(currentProfession))
	if progress.reason == "PROFESSION_EQUIPMENT_CHANGED" and (tonumber(progress.skillUpgrades) or 0) == 0 then
		self:DebugLog("scan", string.format(
			"complete profession=%s mode=%s scanned=%d recommendations=%d noEquipmentUpgrades=true",
			tostring(professionEntry.id),
			tostring(progress.mode),
			tonumber(progress.scanned) or 0,
			tonumber(progress.recommendationsUpdated) or 0
		))
		self:Print(self:Text("SCAN_EQUIPMENT_NO_UPGRADES", tonumber(progress.skillDowngradesSkipped) or 0, self:GetProfessionName(professionEntry.id)))
		return
	end
	self:DebugLog("scan", string.format(
		"complete profession=%s mode=%s scanned=%d recommendations=%d",
		tostring(professionEntry.id),
		tostring(progress.mode),
		tonumber(progress.scanned) or 0,
		tonumber(progress.recommendationsUpdated) or 0
	))
	self:Print(self:Text("SCAN_COMPLETE", tonumber(progress.scanned) or 0, self:GetProfessionName(professionEntry.id)))
	self:Print(self:Text("SCAN_RECOMMENDATIONS_UPDATED", tonumber(progress.recommendationsUpdated) or 0, self:GetProfessionName(professionEntry.id)))
end

function AF:ProcessScanQueue()
	if self.scanProcessing then
		return
	end
	if not self:IsOwnProfessionWindowOpen() then
		self:PauseActiveProfessionScan(true)
		return
	end
	if self:IsInCombatLocked() then
		self.deferredScanResume = true
		return
	end
	self.scanProcessing = true
	self.scanQueueToken = (self.scanQueueToken or 0) + 1
	local token = self.scanQueueToken
	local active, professionEntry, progress = self:GetActiveScanProgress()
	local nextJob = GetNextPendingJob(progress)
	C_Timer.After(self:GetScanJobDelay(nextJob), function()
		if token ~= AF.scanQueueToken then
			return
		end
		AF.scanProcessing = false
		if AF:IsInCombatLocked() then
			AF.deferredScanResume = true
			return
		end
		if not AF:IsOwnProfessionWindowOpen() then
			AF:PauseActiveProfessionScan(true)
			return
		end

		local active, professionEntry, progress = AF:GetActiveScanProgress()
		if not active then
			return
		end

		local jobsToProcess = AF:GetScanJobsPerTick(GetNextPendingJob(progress))
		local tickStarted = GetScanTimeMS()
		local profession = { id = active.professionID }
		local processedCount = 0
		local lastJob
		local slowestJob
		local slowestJobMS = 0
		for processed = 1, jobsToProcess do
			local pendingIndex = GetPendingIndex(progress)
			local job = GetNextPendingJob(progress)
			if not job then
				break
			end
			local jobStarted = GetScanTimeMS()
			local result = AF:ScanJob(profession, professionEntry, job)
			local jobMS = GetScanTimeMS() - jobStarted
			if jobMS > slowestJobMS then
				slowestJobMS = jobMS
				slowestJob = job
			end
			if result == false then
				return
			end
			processedCount = processed
			lastJob = job
			progress.pendingIndex = pendingIndex + 1
			progress.pending[pendingIndex] = nil
			progress.completed[job.key] = true
			progress.completedCount = (tonumber(progress.completedCount) or 0) + 1
			if result ~= "skipped" then
				progress.scanned = (tonumber(progress.scanned) or 0) + 1
			end
			progress.updatedAt = AF:Now()
			if AF.db and AF.db.fastScan == true and processed > 0 and GetScanTimeMS() - tickStarted >= FAST_SCAN_TICK_BUDGET_MS then
				break
			end
		end
		if collectgarbage then
			collectgarbage("step", SCAN_GC_STEP_SIZE)
		end
		local tickMS = GetScanTimeMS() - tickStarted
		if tickMS >= SLOW_SCAN_TICK_WARNING_MS then
			AF:DebugLog("scan", string.format(
				"slow tick ms=%.1f processed=%d budget=%d fast=%s profession=%s mode=%s pending=%d/%d scanned=%d completed=%d total=%d last=%s:%s:%s slowest=%.1fms:%s:%s:%s",
				tickMS,
				processedCount,
				jobsToProcess,
				tostring(AF.db and AF.db.fastScan == true),
				tostring(active.professionID),
				tostring(progress.mode),
				GetPendingCount(progress),
				GetPendingTotal(progress),
				tonumber(progress.scanned) or 0,
				tonumber(progress.completedCount) or 0,
				tonumber(progress.total) or 0,
				tostring(lastJob and lastJob.kind or ""),
				tostring(lastJob and lastJob.recipeID or ""),
				tostring(lastJob and lastJob.itemID or ""),
				slowestJobMS,
				tostring(slowestJob and slowestJob.kind or ""),
				tostring(slowestJob and slowestJob.recipeID or ""),
				tostring(slowestJob and slowestJob.itemID or "")
			))
		end
		AF:RefreshScanProgressUI()

		if GetPendingCount(progress) == 0 then
			AF:CompleteActiveScan(active, professionEntry, progress)
		else
			AF:ProcessScanQueue()
		end
	end)
end

function AF:PauseActiveProfessionScan(silent)
	local active = self.activeScan
	if not active or not active.professionID then
		return
	end

	local professionEntry = self.db
		and self.db.artisanProfile
		and self.db.artisanProfile.professions
		and self.db.artisanProfile.professions[tostring(active.professionID)]
	if professionEntry and professionEntry.scanSignature == active.signature then
		professionEntry.scanProgress = nil
		self.activeScan = nil
		return
	end
	local progress = professionEntry and professionEntry.scanProgress
	local remaining = GetPendingCount(progress)
	self.activeScan = nil
	self:RefreshScanProgressUI(true)
	self:DebugLog("scan", string.format("paused profession=%s remaining=%d silent=%s", tostring(active.professionID), tonumber(remaining) or 0, tostring(silent == true)))

	if remaining > 0 and not silent then
		self:Print(self:Text("SCAN_PAUSED", self:GetProfessionName(active.professionID), remaining))
	end
end

function AF:StartOrResumeCurrentProfessionScan(force, silent, mode, forceProbe, reason)
	if self:IsInCombatLocked() then
		self:DebugLog("scan", "deferred start: combat")
		self.deferredScanResume = true
		return 0
	end
	if not self:IsOwnProfessionWindowOpen() then
		self:DebugLog("scan", "start skipped: profession window closed")
		self.activeScan = nil
		return 0
	end

	if not C_TradeSkillUI.IsTradeSkillReady() then
		self:DebugLog("scan", "start skipped: trade skill not ready")
		if not silent then
			self:Print(self:Text("SCAN_OPEN_PROFESSION"))
		end
		return 0
	end

	local profession = self:GetCurrentProfessionInfo()
	if not profession then
		self:DebugLog("scan", "start skipped: no current profession")
		if not silent then
			self:Print(self:Text("SCAN_NO_PROFESSION"))
		end
		return 0
	end
	profession.id = self:GetSupportedProfessionID(profession.id, profession)
	if not profession.id then
		self:DebugLog("scan", "start skipped: unsupported profession")
		return 0
	end

	local currentSignature = self:GetCurrentProfessionScanSignature(profession)
	if not currentSignature then
		self:DebugLog("scan", "start skipped: missing scan signature")
		return 0
	end
	mode = force and "full" or (mode or "probe")

	if self.activeScan and tonumber(self.activeScan.professionID) == tonumber(profession.id) then
		return 0
	end

	local professionEntry = self:PrepareProfessionForScan(profession)
	if not professionEntry then
		return 0
	end
	if reason == "PROFESSION_EQUIPMENT_CHANGED" then
		professionEntry.equipmentSignature = self:GetCurrentProfessionEquipmentSignature(profession) or professionEntry.equipmentSignature
	end
	if professionEntry.scanSignature == currentSignature and professionEntry.scanProgress then
		local remaining = GetPendingCount(professionEntry.scanProgress)
		if remaining == 0 then
			professionEntry.scanProgress = nil
		end
	end
	if not force and not forceProbe and professionEntry.scanSignature == currentSignature and not professionEntry.scanProgress then
		self:DebugLog("scan", string.format("start skipped: unchanged profession=%s mode=%s", tostring(profession.id), tostring(mode)))
		return 0
	end

	local progress
	local progressSignature = table.concat({ currentSignature, mode }, "|")
	if not force and professionEntry.scanProgress and professionEntry.scanProgress.signature == progressSignature then
		progress = professionEntry.scanProgress
	else
		progress = self:BuildScanProgress(profession, professionEntry, currentSignature, force, mode, reason)
	end
	if not progress then
		self:DebugLog("scan", string.format("start skipped: no recipes profession=%s mode=%s", tostring(profession.id), tostring(mode)))
		if not silent then
			self:Print(self:Text("SCAN_NO_RECIPES"))
		end
		return 0
	end
	if GetPendingCount(progress) == 0 then
		self:DebugLog("scan", string.format("start skipped: no pending jobs profession=%s mode=%s", tostring(profession.id), tostring(mode)))
		professionEntry.scanSignature = currentSignature
		professionEntry.scanMode = mode
		professionEntry.scannedAt = self:Now()
		professionEntry.scanProgress = nil
		return 0
	end

	self.activeScan = {
		professionID = profession.id,
		signature = progress.signature,
	}
	self:DebugLog("scan", string.format(
		"started profession=%s mode=%s pending=%d force=%s reason=%s",
		tostring(profession.id),
		tostring(mode),
		GetPendingCount(progress),
		tostring(force == true),
		tostring(reason or "")
	))
	professionEntry.scanSignature = nil
	self:RefreshScanProgressUI(true)
	if reason ~= "PROFESSION_EQUIPMENT_CHANGED" then
		self:Print(self:Text(progress.scanned and progress.scanned > 0 and "SCAN_RESUMED" or "SCAN_STARTED", profession.name))
	end
	self:ProcessScanQueue()
	return GetPendingCount(progress)
end

function AF:ProfessionHasPendingReagentNameWork(professionID)
	local profile = self.db and self.db.artisanProfile
	if not profile or not profile.items then
		return false
	end
	for _, item in pairs(profile.items) do
		if tonumber(item.professionID) == tonumber(professionID) and item.bestReagentPendingNames then
			return true
		end
	end
	return false
end

function AF:ShouldStartAutoScanForReason(reason, profession, currentSignature)
	local professionEntry = GetProfessionEntry(self, profession)
	if not professionEntry then
		return true, false
	end
	if professionEntry.scanProgress then
		return true, false
	end
	if professionEntry.scanSignature ~= currentSignature then
		return true, false
	end
	if reason == "ITEM_DATA_LOADED" then
		return self:ProfessionHasPendingReagentNameWork(profession.id), true
	end
	if self:IsSkillProbeScanReason(reason) then
		return true, true
	end
	return false, false
end

function AF:IsKnowledgeApplyPending(professionID)
	if not professionID then
		return false
	end
	local configID = C_ProfSpecs.GetConfigIDForSkillLine(professionID)
	return configID and configID ~= 0 and C_Traits.ConfigHasStagedChanges(configID) == true
end

function AF:QueueAutoScan(force)
	return self:QueueAutoScanForChange(force and "FORCE" or "AUTO")
end

function AF:QueueProfessionDataSourceProbe()
	if self:IsInCombatLocked() or not self:IsOwnProfessionWindowOpen() then
		return
	end
	local profession = self:GetCurrentProfessionInfo()
	if not profession then
		return
	end
	local signatureChanged = self:GetProfessionEquipmentSignatureChanged(profession)
	if not signatureChanged and not self.pendingProfessionEquipmentScan then
		return
	end
	if self:RestartActiveScanForEquipmentUpgrade(profession) then
		return
	end
	if self.activeScan then
		return
	end
	if not self:ShouldQueueProfessionEquipmentScan(profession) then
		return
	end
	local now = self:Now()
	if self.lastProfessionDataSourceProbeAt and now - self.lastProfessionDataSourceProbeAt < 3 then
		return
	end
	self.lastProfessionDataSourceProbeAt = now
	self.pendingProfessionEquipmentScan = true
	self:QueueAutoScanForChange("PROFESSION_EQUIPMENT_CHANGED")
end

function AF:StartProfessionEquipmentWatch()
	self.professionEquipmentWatchToken = (self.professionEquipmentWatchToken or 0) + 1
	local token = self.professionEquipmentWatchToken
	local function Tick()
		if token ~= AF.professionEquipmentWatchToken then
			return
		end
		if AF:IsInCombatLocked() then
			C_Timer.After(1.0, Tick)
			return
		end
		if not AF:IsOwnProfessionWindowOpen() or not C_TradeSkillUI.IsTradeSkillReady() then
			return
		end
		local profession = AF:GetCurrentProfessionInfo()
		if not profession then
			return
		end
		local changed = AF:GetProfessionEquipmentSignatureChanged(profession)
		if changed and AF:RestartActiveScanForEquipmentUpgrade(profession) then
			return
		end
		if changed and AF:ShouldQueueProfessionEquipmentScan(profession) then
			AF.pendingProfessionEquipmentScan = true
			AF:QueueAutoScanForChange("PROFESSION_EQUIPMENT_CHANGED")
		end
		C_Timer.After(1.0, Tick)
	end
	C_Timer.After(1.0, Tick)
end

function AF:StopProfessionEquipmentWatch()
	self.professionEquipmentWatchToken = (self.professionEquipmentWatchToken or 0) + 1
end

function AF:QueueAutoScanForChange(reason)
	if self:IsInCombatLocked() then
		self.deferredAutoScanReason = reason or self.deferredAutoScanReason
		if reason == "PROFESSION_EQUIPMENT_CHANGED" then
			self.deferredProfessionEquipmentSkillLineID = self.pendingProfessionEquipmentSkillLineID or self.deferredProfessionEquipmentSkillLineID
		end
		return
	end
	if not self:IsOwnProfessionWindowOpen() then
		self.pendingAutoScanReason = nil
		return
	end
	if reason == "TRAIT_NODE_CHANGED" then
		self.knowledgeApplyScanPending = true
		self.pendingAutoScanReason = "TRAIT_PENDING_APPLIED"
		return
	end
	if reason == "PROFESSION_EQUIPMENT_CHANGED" then
		self.pendingProfessionEquipmentScan = true
	end

	if self.autoScanQueued and reason ~= "PROFESSION_EQUIPMENT_CHANGED" then
		self.pendingAutoScanReason = reason or self.pendingAutoScanReason
		return
	end

	self.autoScanQueued = true
	self.autoScanToken = (self.autoScanToken or 0) + 1
	local token = self.autoScanToken
	self.pendingAutoScanReason = reason or self.pendingAutoScanReason
	local delay = reason == "PROFESSION_EQUIPMENT_CHANGED" and 2.0 or 1.0
	C_Timer.After(delay, function()
		if token ~= AF.autoScanToken then
			return
		end
		AF.autoScanQueued = false
			if AF:IsInCombatLocked() then
				AF.deferredAutoScanReason = AF.pendingAutoScanReason
				AF.deferredProfessionEquipmentSkillLineID = AF.pendingProfessionEquipmentSkillLineID
				return
			end
			if not AF:IsOwnProfessionWindowOpen() then
				AF.pendingAutoScanReason = nil
				return
			end
		local profession = AF:GetCurrentProfessionInfo()
		if not profession then
			return
		end
		local currentSignature = AF:GetCurrentProfessionScanSignature(profession)
		if not currentSignature then
			return
		end
		if AF:IsKnowledgeApplyPending(profession.id) then
			AF.knowledgeApplyScanPending = true
			AF:QueueAutoScanForChange(AF.pendingAutoScanReason or "TRAIT_PENDING")
			return
		end
		local reason = AF.pendingAutoScanReason
		if AF.deferredProfessionEquipmentSkillLineID and reason == "PROFESSION_EQUIPMENT_CHANGED" then
			AF.pendingProfessionEquipmentSkillLineID = AF.deferredProfessionEquipmentSkillLineID
			AF.deferredProfessionEquipmentSkillLineID = nil
		end
		AF.pendingAutoScanReason = nil
		if AF.knowledgeApplyScanPending then
			reason = "TRAIT_PENDING_APPLIED"
			AF.knowledgeApplyScanPending = nil
		end
		if reason == "PROFESSION_EQUIPMENT_CHANGED" and not AF:ShouldQueueProfessionEquipmentScan(profession) then
			AF.pendingProfessionEquipmentScan = nil
			return
		end
		local force = reason == "FORCE"
		if force then
			AF:StartOrResumeCurrentProfessionScan(true, true, "full")
			return
		end
		local shouldStart, forceProbe = AF:ShouldStartAutoScanForReason(reason, profession, currentSignature)
		if shouldStart then
			AF:StartOrResumeCurrentProfessionScan(false, true, "probe", forceProbe, reason)
			if reason == "PROFESSION_EQUIPMENT_CHANGED" then
				AF.pendingProfessionEquipmentScan = nil
			end
		end
	end)
end

function AF:ResumeCurrentProfessionScanIfNeeded()
	if not self:IsOwnProfessionWindowOpen() then
		self.activeScan = nil
		return 0
	end

	local profession = self:GetCurrentProfessionInfo()
	if not profession then
		return 0
	end
	local professionEntry = GetProfessionEntry(self, profession)
	local currentSignature = self:GetCurrentProfessionScanSignature(profession)
	if not currentSignature then
		return 0
	end
	local pendingReason = self.pendingAutoScanReason
	if pendingReason then
		local shouldStart, forceProbe = self:ShouldStartAutoScanForReason(pendingReason, profession, currentSignature)
		self.pendingAutoScanReason = nil
		if pendingReason == "PROFESSION_EQUIPMENT_CHANGED" then
			self.pendingProfessionEquipmentSkillLineID = nil
		end
		if shouldStart then
			local queued = self:StartOrResumeCurrentProfessionScan(false, true, "probe", forceProbe, pendingReason)
			if pendingReason == "PROFESSION_EQUIPMENT_CHANGED" and queued > 0 then
				self.pendingProfessionEquipmentScan = nil
			end
			return queued
		end
	end
	if professionEntry and professionEntry.scanSignature == currentSignature then
		professionEntry.scanProgress = nil
		return 0
	end
	if not professionEntry or professionEntry.scanSignature ~= currentSignature or professionEntry.scanProgress then
		return self:StartOrResumeCurrentProfessionScan(false, true)
	end
	return 0
end
