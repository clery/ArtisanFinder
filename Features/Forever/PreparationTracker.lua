local _, AF = ...

function AF:CreatePreparedCraftEntry(entry)
    if not entry or not tonumber(entry.recipeID) then return nil end
    local recipeID=tonumber(entry.recipeID)
    local reagents,seen={},{}
    local function add(reagent,quantity)
        local id=tonumber(reagent and reagent.itemID)
        quantity=tonumber(quantity or reagent and reagent.quantity)
        if not id or id<=0 or not quantity or quantity<=0 then return end
        if seen[id] then seen[id].quantity=seen[id].quantity+quantity
        else
            local copy={itemID=id,quantity=quantity}
            seen[id]=copy reagents[#reagents+1]=copy
        end
    end
    local schematic
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local ok,value=pcall(C_TradeSkillUI.GetRecipeSchematic,recipeID,false)
        if ok then schematic=value end
    end
    if schematic and schematic.reagentSlotSchematics then
        for _,slot in ipairs(schematic.reagentSlotSchematics) do
            local basic=not Enum or not Enum.CraftingReagentType or slot.reagentType==Enum.CraftingReagentType.Basic
            if not slot.hiddenInCraftingForm and (slot.required or basic) then
                add(slot.reagents and slot.reagents[1],slot.quantityRequired)
            end
        end
    else
        for _,reagent in ipairs(entry.reagents or entry.bestReagents or {}) do add(reagent) end
    end
    if #reagents==0 then return nil end
    table.sort(reagents,function(a,b) return a.itemID<b.itemID end)
    local target=self:NormalizeName(entry.orderTarget or entry.name or entry.target)
    return {key=table.concat({recipeID,entry.itemID or 0,target or "?","standard"},":"),
        mode="standard",recipeID=recipeID,itemID=entry.itemID,professionID=entry.professionID,
        itemName=entry.craftName or entry.itemName or entry.recipeName or self:GetDisplayItemName(entry.itemID),
        target=target,createdAt=self:Now(),reagents=reagents}
end

function AF:TrackForeverCraftMaterials(entry)
    local prepared=self:AddPreparedCraftToTracker(entry,"standard")
    if not prepared then self:Print(self:Text("FOREVER_MATERIALS_UNAVAILABLE")) end
    return prepared
end
