local _, AF = ...

local function GetScanJobKey(recipeID, itemID)
	return tostring(recipeID or 0) .. ":" .. tostring(itemID or 0)
end

local function GetRecommendationSnapshot(item)
	if not item then
		return ""
	end
	return table.concat({
		tostring(item.bestReagentSummary or ""),
		tostring(item.bestQuality or ""),
		tostring(item.bestQualityAtlas or ""),
		tostring(item.rawBestQuality or ""),
		tostring(item.bestReagentTruncated == true),
		tostring(item.bestReagentPendingNames == true),
	}, "|")
end

function AF:PrepareProfessionForScan(profession)
	local profile = self.db.artisanProfile
	local professionKey = tostring(profession.id)
	profile.professions[professionKey] = profile.professions[professionKey] or {
		id = profession.id,
		name = profession.name,
		recipes = {},
		updatedAt = self:Now(),
	}
	local professionEntry = profile.professions[professionKey]
	professionEntry.id = profession.id
	professionEntry.name = profession.name
	professionEntry.updatedAt = self:Now()
	professionEntry.professionLink = self:GetProfessionLink()
	professionEntry.recipes = professionEntry.recipes or {}
	return professionEntry
end

function AF:BuildScanProgress(profession, professionEntry, signature, force, mode)
	local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetAllRecipeIDs()
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

	local profile = self.db.artisanProfile
	local pending = {}
	for _, recipeID in ipairs(recipeIDs) do
		local recipeInfo = C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(recipeID)
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
					or not existing.bestReagentSummary
					or existing.bestReagentSummary == ""
					or existing.bestReagentPendingNames == true
				if force or not completed[key] then
					table.insert(pending, {
						key = key,
						kind = needsFull and "full" or mode,
						recipeID = recipeID,
						itemID = itemID,
						recipeName = recipeInfo and recipeInfo.name,
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
		completed = completed,
		total = #pending + self:TableCount(completed),
		scanned = self:TableCount(completed),
		recommendationsUpdated = previous and previous.signature == progressSignature and tonumber(previous.recommendationsUpdated) or 0,
		startedAt = previous and previous.startedAt or self:Now(),
		updatedAt = self:Now(),
	}
	return professionEntry.scanProgress
end

function AF:ScanJob(profession, professionEntry, job)
	local profile = self.db.artisanProfile
	local itemKey = tostring(job.itemID)
	local existing = profile.items[itemKey] or {}
	profile.items[itemKey] = existing
	existing.itemID = job.itemID
	existing.recipeID = job.recipeID
	existing.recipeName = job.recipeName or existing.recipeName or self:Text("RECIPE_FALLBACK", tostring(job.recipeID))
	existing.itemName = self:GetDisplayItemName(job.itemID, existing.itemName)
	existing.professionID = profession.id
	existing.professionName = profession.name
	if job.kind == "probe" then
		local probe = self:GetRecipeSkillProbe(job.recipeID)
		if probe then
			local needsFull = self:ProbeRequiresFullScan(existing, job.recipeID, job.itemID, probe)
			self:ApplyRecipeSkillProbe(existing, job.recipeID, probe)
			if needsFull then
				table.insert(professionEntry.scanProgress.pending, {
					key = "full:" .. GetScanJobKey(job.recipeID, job.itemID),
					kind = "full",
					recipeID = job.recipeID,
					itemID = job.itemID,
					recipeName = job.recipeName,
				})
				professionEntry.scanProgress.total = professionEntry.scanProgress.total + 1
			end
		else
			table.insert(professionEntry.scanProgress.pending, {
				key = "full:" .. GetScanJobKey(job.recipeID, job.itemID),
				kind = "full",
				recipeID = job.recipeID,
				itemID = job.itemID,
				recipeName = job.recipeName,
			})
			professionEntry.scanProgress.total = professionEntry.scanProgress.total + 1
		end
	else
		local beforeRecommendation = GetRecommendationSnapshot(existing)
		self:ApplyRecipeCapability(existing, job.recipeID)
		local afterRecommendation = GetRecommendationSnapshot(existing)
		if beforeRecommendation ~= afterRecommendation and existing.bestReagentSummary and existing.bestReagentSummary ~= "" then
			professionEntry.scanProgress.recommendationsUpdated = (tonumber(professionEntry.scanProgress.recommendationsUpdated) or 0) + 1
		end
	end
	existing.updatedAt = self:Now()
	professionEntry.recipes[tostring(job.recipeID)] = true
end

function AF:IsCurrentProfessionScanAvailable(professionID)
	if not C_TradeSkillUI or not C_TradeSkillUI.IsTradeSkillReady or not C_TradeSkillUI.IsTradeSkillReady() then
		return false
	end
	if self:IsLinkedProfessionOpen() then
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

	local profile = self.db and self.db.artisanProfile
	local professionEntry = profile and profile.professions and profile.professions[tostring(active.professionID)]
	local progress = professionEntry and professionEntry.scanProgress
	if not progress or progress.signature ~= active.signature then
		self.activeScan = nil
		return nil
	end

	return active, professionEntry, progress
end

function AF:RefreshScanProgressUI(force)
	self.scanRefreshCounter = (self.scanRefreshCounter or 0) + 1
	if force or self.scanRefreshCounter >= 8 then
		self.scanRefreshCounter = 0
		if self.RefreshCrafterUI then
			self:RefreshCrafterUI()
		end
		if self.RefreshMinimap then
			self:RefreshMinimap()
		end
	end
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
	if self.RefreshOptionsPanel then
		self:RefreshOptionsPanel()
	end
	self:Print(self:Text("SCAN_COMPLETE", tonumber(progress.scanned) or 0, professionEntry.name))
	self:Print(self:Text("SCAN_RECOMMENDATIONS_UPDATED", tonumber(progress.recommendationsUpdated) or 0, professionEntry.name))
end

function AF:ProcessScanQueue()
	if self.scanProcessing then
		return
	end
	if self:IsInCombatLocked() then
		self.deferredScanResume = true
		return
	end
	self.scanProcessing = true
	C_Timer.After(0.03, function()
		AF.scanProcessing = false
		if AF:IsInCombatLocked() then
			AF.deferredScanResume = true
			return
		end

		local active, professionEntry, progress = AF:GetActiveScanProgress()
		if not active then
			return
		end

		local job = table.remove(progress.pending, 1)
		if job then
			local profession = { id = active.professionID, name = professionEntry.name }
			AF:ScanJob(profession, professionEntry, job)
			progress.completed[job.key] = true
			progress.scanned = (tonumber(progress.scanned) or 0) + 1
			progress.updatedAt = AF:Now()
			AF:RefreshScanProgressUI()
		end

		if #progress.pending == 0 then
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
	local remaining = progress and progress.pending and #progress.pending or 0
	self.activeScan = nil

	if remaining > 0 and not silent then
		self:Print(self:Text("SCAN_PAUSED", professionEntry.name or self:Text("PROFESSION_FALLBACK", tostring(active.professionID)), remaining))
	end
end

function AF:StartOrResumeCurrentProfessionScan(force, silent, mode, forceProbe)
	if self:IsInCombatLocked() then
		self.deferredScanResume = true
		return 0
	end
	if self:IsLinkedProfessionOpen() then
		self.activeScan = nil
		return 0
	end

	if not C_TradeSkillUI or not C_TradeSkillUI.IsTradeSkillReady or not C_TradeSkillUI.IsTradeSkillReady() then
		if not silent then
			self:Print(self:Text("SCAN_OPEN_PROFESSION"))
		end
		return 0
	end

	local profession = self:GetCurrentProfessionInfo()
	if not profession then
		if not silent then
			self:Print(self:Text("SCAN_NO_PROFESSION"))
		end
		return 0
	end

	local currentSignature = self:GetCurrentProfessionScanSignature(profession)
	if not currentSignature then
		return 0
	end
	mode = force and "full" or (mode or "probe")

	if self.activeScan and tonumber(self.activeScan.professionID) == tonumber(profession.id) then
		return 0
	end

	local professionEntry = self:PrepareProfessionForScan(profession)
	if professionEntry.scanSignature == currentSignature and professionEntry.scanProgress then
		local remaining = professionEntry.scanProgress.pending and #professionEntry.scanProgress.pending or 0
		if remaining == 0 then
			professionEntry.scanProgress = nil
		end
	end
	if not force and not forceProbe and professionEntry.scanSignature == currentSignature and not professionEntry.scanProgress then
		return 0
	end

	local progress
	local progressSignature = table.concat({ currentSignature, mode }, "|")
	if not force and professionEntry.scanProgress and professionEntry.scanProgress.signature == progressSignature then
		progress = professionEntry.scanProgress
	else
		progress = self:BuildScanProgress(profession, professionEntry, currentSignature, force, mode)
	end
	if not progress then
		if not silent then
			self:Print(self:Text("SCAN_NO_RECIPES"))
		end
		return 0
	end
	if #progress.pending == 0 then
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
	professionEntry.scanSignature = nil
	self:Print(self:Text(progress.scanned and progress.scanned > 0 and "SCAN_RESUMED" or "SCAN_STARTED", profession.name))
	self:ProcessScanQueue()
	return #progress.pending
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
	local professionEntry = self.db
		and self.db.artisanProfile
		and self.db.artisanProfile.professions
		and self.db.artisanProfile.professions[tostring(profession.id)]
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
	if reason == "SKILL_LINES_CHANGED" or reason == "SPELLS_CHANGED" or reason == "TRAIT_CONFIG_UPDATED" or reason == "TRAIT_PENDING_APPLIED" then
		return true, true
	end
	return false, false
end

function AF:IsKnowledgeApplyPending(professionID)
	if not professionID or not C_ProfSpecs or not C_Traits or not C_ProfSpecs.GetConfigIDForSkillLine or not C_Traits.ConfigHasStagedChanges then
		return false
	end
	local configID = C_ProfSpecs.GetConfigIDForSkillLine(professionID)
	return configID and configID ~= 0 and C_Traits.ConfigHasStagedChanges(configID) == true
end

function AF:QueueAutoScan(force)
	return self:QueueAutoScanForChange(force and "FORCE" or "AUTO")
end

function AF:QueueAutoScanForChange(reason)
	if self:IsInCombatLocked() then
		self.deferredAutoScanReason = reason or self.deferredAutoScanReason
		return
	end
	if self:IsLinkedProfessionOpen() then
		self.pendingAutoScanReason = nil
		return
	end
	if reason == "TRAIT_NODE_CHANGED" then
		self.knowledgeApplyScanPending = true
		self.pendingAutoScanReason = "TRAIT_PENDING_APPLIED"
		return
	end

	if self.autoScanQueued then
		self.pendingAutoScanReason = reason or self.pendingAutoScanReason
		return
	end

	self.autoScanQueued = true
	self.pendingAutoScanReason = reason or self.pendingAutoScanReason
	C_Timer.After(1.0, function()
		AF.autoScanQueued = false
		if AF:IsInCombatLocked() then
			AF.deferredAutoScanReason = AF.pendingAutoScanReason
			return
		end
		if AF:IsLinkedProfessionOpen() then
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
		AF.pendingAutoScanReason = nil
		if AF.knowledgeApplyScanPending then
			reason = "TRAIT_PENDING_APPLIED"
			AF.knowledgeApplyScanPending = nil
		end
		local force = reason == "FORCE"
		if force then
			AF:StartOrResumeCurrentProfessionScan(true, true, "full")
			return
		end
		local shouldStart, forceProbe = AF:ShouldStartAutoScanForReason(reason, profession, currentSignature)
		if shouldStart then
			AF:StartOrResumeCurrentProfessionScan(false, true, "probe", forceProbe)
		end
	end)
end

function AF:ResumeCurrentProfessionScanIfNeeded()
	if self:IsLinkedProfessionOpen() then
		self.activeScan = nil
		return 0
	end

	local profession = self:GetCurrentProfessionInfo()
	if not profession then
		return 0
	end
	local professionEntry = self.db and self.db.artisanProfile and self.db.artisanProfile.professions[tostring(profession.id)]
	local currentSignature = self:GetCurrentProfessionScanSignature(profession)
	if not currentSignature then
		return 0
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
