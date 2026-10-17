local _, AF = ...
-- Forever has learned recipes and reagents, but no crafting orders, quality
-- simulations, concentration, or profession specialization tree.
local function Call(name, ...)
    local fn=C_TradeSkillUI and C_TradeSkillUI[name]
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,...)
    if ok and not AF:IsSecretValue(value) then return value end
end
function AF:GetCurrentProfessionInfo()
    local info=Call("GetBaseProfessionInfo") or Call("GetChildProfessionInfo")
    if not info then return end
    local child=Call("GetProfessionChildSkillLineID") or info.professionID
    local id=tonumber(info.parentProfessionID) or tonumber(info.professionID) or tonumber(child)
    if not id or id==0 then return end
    return {id=id,parentProfessionID=info.parentProfessionID,skillLineID=child,
        childProfessionID=child,name=info.parentProfessionName or info.professionName,
        icon=info.professionIcon or info.icon,skillLevel=info.skillLevel,maxSkillLevel=info.maxSkillLevel}
end
function AF:GetRecipeOutputItemIDs(recipeID)
    local outputs={}
    local link=Call("GetRecipeItemLink",recipeID)
    local id=link and self:GetItemIDFromLink(link)
    local data=Call("GetRecipeOutputItemData",recipeID,{})
    id=id or type(data)=="table" and tonumber(data.itemID)
    if id and id>0 then outputs[id]=true end
    -- Enchants without an item output still have a stable recipe identity.
    -- Negative keys are internal only; never submitted to item/order APIs.
    if not next(outputs) then outputs[-recipeID]=true end
    return outputs
end

function AF:CaptureCurrentProfessionLink(profession, _)
	if not self:IsOwnProfessionWindowOpen() then
		return nil
	end

	profession = profession or self:GetCurrentProfessionInfo()
	local professionID = profession and profession.id
	if not professionID then
		return nil
	end

	local link = self:GetProfessionLink()
	if not link then
		return nil
	end

	local characterName = self:NormalizeName(self.activeArtisanCharacter or self.playerName or self:GetPlayerFullName())
	return self:StoreProfessionLink(characterName, professionID, link)
end

function AF:GetProfessionSpecSignature() return "forever" end
function AF:GetProfessionRecipeSignature()
    local ids={}
    for _,id in ipairs(Call("GetAllRecipeIDs") or {}) do
        local info=Call("GetRecipeInfo",id)
        if info and info.learned==true then ids[#ids+1]=id end
    end
    table.sort(ids)
    return table.concat(ids,",")
end
function AF:GetCurrentProfessionScanSignature(profession)
    return profession and table.concat({"forever-1",profession.id,self:GetProfessionRecipeSignature()},"|")
end
function AF:GetCurrentProfessionScanSignatureVersion() return "forever-1" end
function AF:GetRecipeSkillProbe(recipeID)
    local info=Call("GetRecipeInfo",recipeID)
    if not info or info.learned~=true then return end
    local profession=self:GetCurrentProfessionInfo()
    return {foreverRecipe=true,learned=true,recipeName=info.name,
        skillProbeSignature=tostring(recipeID)..":learned",
        totalSkill=profession and profession.skillLevel,
        professionLink=self:CaptureCurrentProfessionLink(profession)}
end
function AF:ApplyRecipeSkillProbe(item,recipeID,probe)
    if not probe then return end
    item.foreverRecipe=true
    item.recipeID=recipeID
    item.recipeName=probe.recipeName
    item.skillProbeSignature=probe.skillProbeSignature
    item.totalSkill=probe.totalSkill
    item.professionLink=probe.professionLink or item.professionLink
    item.scanModelVersion=self.SCAN_MODEL_VERSION
end
function AF:GetRecipeCapability(recipeID)
    local capability=self:GetRecipeSkillProbe(recipeID) or {}
    capability.bestReagents={}
    local schematic=Call("GetRecipeSchematic",recipeID,false)
    for _,slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local basic=not Enum or not Enum.CraftingReagentType or slot.reagentType==Enum.CraftingReagentType.Basic
        if not slot.hiddenInCraftingForm and (slot.required or basic) then
            local reagent=slot.reagents and slot.reagents[1]
            if reagent and reagent.itemID then
                capability.bestReagents[#capability.bestReagents+1]={itemID=reagent.itemID,
                    quantity=slot.quantityRequired or 1,slotIndex=slot.slotIndex or slot.dataSlotIndex}
            end
        end
    end
    return capability
end
function AF:ApplyRecipeCapability(item,recipeID)
    local capability=self:GetRecipeCapability(recipeID)
    self:ApplyRecipeSkillProbe(item,recipeID,capability)
    item.bestReagents=capability.bestReagents
    item.reagents=capability.bestReagents
    item.bestReagentPendingNames=false
    item.fullScanSignature="forever:"..tostring(recipeID)
    item.scannedAt=self:Now()
end
function AF:ClearRecipeCapabilityRuntimeCaches() self.recipeCapabilityCache=nil end
function AF:ProbeRequiresFullScan(item) return not item or not item.foreverRecipe end
function AF:EstimateRecipeQualityTierCombinations() return 1 end

function AF:ScanForeverRecipeJob(profession, professionEntry, job)
    if not self:IsOwnProfessionWindowOpen() then self:PauseActiveProfessionScan(true) return false end
    local info=C_TradeSkillUI.GetRecipeInfo(job.recipeID)
    if not info or info.learned~=true or not self:RecipeBelongsToProfession(profession,info,self:GetCurrentProfessionCategoryIDs(),job.recipeID) then return "skipped" end
    local profile=self.db.artisanProfile
    local key=tostring(job.itemID)
    local item=profile.items[key] or {}
    item.itemID=job.itemID
    item.recipeID=job.recipeID
    item.professionID=profession.id
    item.professionIcon=profession.icon
    self:ApplyRecipeCapability(item,job.recipeID)
    item.updatedAt=self:Now()
    profile.items[key]=item
    professionEntry.recipes[tostring(job.recipeID)]=true
    return true
end

