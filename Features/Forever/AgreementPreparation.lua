local _, AF = ...
local requestedItems={}
local function requestItem(id)
    if not requestedItems[id] and C_Item and C_Item.RequestLoadItemDataByID then
        requestedItems[id]=true pcall(C_Item.RequestLoadItemDataByID,id)
    end
end
local function validLink(link,kind,id)
    return type(link)=="string" and tonumber(link:match("|H"..kind..":(%d+)"))==id
end
function AF:GetAgreementMaterialPresentation(material)
    local id=tonumber(material.itemID)
    if not id or id<1 or id%1~=0 then return self:Text("AGREEMENT_UNKNOWN_CRAFT") end
    local name,link
    if C_Item and C_Item.GetItemInfo then name,link=C_Item.GetItemInfo(id) end
    if not name then requestItem(id) end
    name=name or self:GetDisplayItemName(id)
    return name,validLink(link,"item",id) and link or "|cffffffff|Hitem:"..id.."|h["..name.."]|h|r"
end

-- Remote labels are fallbacks, never craft identity. Resolve presentation locally
-- without changing the shared terms used by agreement revisions and retries.
function AF:GetAgreementCraftPresentation(record)
    local itemID,recipeID=tonumber(record.itemID),tonumber(record.recipeID)
    local name,link
    if itemID and itemID>0 and C_Item and C_Item.GetItemInfo then
        local ok,value,cached=pcall(C_Item.GetItemInfo,itemID)
        if ok and not (self.IsSecretValue and self:IsSecretValue(value)) and type(value)=="string" and value~="" then name=value end
        if ok and not (self.IsSecretValue and self:IsSecretValue(cached)) and type(cached)=="string" then link=cached end
        if not name then requestItem(itemID) end
    elseif recipeID and recipeID>0 and C_Spell and C_Spell.GetSpellName then
        local ok,value=pcall(C_Spell.GetSpellName,recipeID)
        if ok and not (self.IsSecretValue and self:IsSecretValue(value)) and type(value)=="string" and value~="" then name=value end
    end
    local kind,id
    if itemID and itemID>0 then kind,id="item",itemID
    elseif recipeID and recipeID>0 then kind,id="enchant",recipeID end
    if kind and validLink(record.itemLink,kind,id) then
        -- Preserve bonus data only when the hyperlink agrees with the stored identity.
        link=record.itemLink:gsub("(|h%[)[^|]*(%]|h)",function(before,after) return before..(name or record.itemName or self:Text("AGREEMENT_UNKNOWN_CRAFT"))..after end,1)
    end
    name=name or record.itemName or self:Text("AGREEMENT_UNKNOWN_CRAFT")
    if kind and not validLink(link,kind,id) then link="|cffffffff|H"..kind..":"..id.."|h["..name.."]|h|r" end
    return name,link
end

-- Only the ordering character can read inventory for an agreement. Artisan views
-- use a bounded customer snapshot, never their own bags or bank.
function AF:IsAgreementCustomer(record)
    local owner=self.playerName or (self.GetPlayerFullName and self:GetPlayerFullName())
    return record.localRole~="artisan" and (record.customer==nil or record.customer==owner)
end

-- Schematics remain local. Stock messages contain only required reagent counts.
function AF:GetAgreementMaterials(record,ignoreStock)
    if not record or not record.recipeID then return nil end
    if record.materialSnapshot then
        local materials={}
        for id,value in pairs(record.materialSnapshot) do
            materials[#materials+1]={itemID=tonumber(id),quantity=value.quantity,owned=value.owned,
                missing=value.owned and math.max(0,value.quantity-value.owned) or nil}
        end
        table.sort(materials,function(a,b) return a.itemID<b.itemID end)
        return #materials>0 and materials or nil,record.materialOutput
    end
    local entry = self:CreatePreparedCraftEntry({recipeID=record.recipeID,itemID=record.itemID,
        itemName=self:GetAgreementCraftPresentation(record),professionID=record.professionID,name=record.artisan,reagents=record.reagents})
    if not entry and self.GetForeverKnownCrafts then
        for _,craft in ipairs(self:GetForeverKnownCrafts(record.craftingCharacter,record.professionID)) do
            if tonumber(craft.recipeID)==tonumber(record.recipeID) then
                local copy={} for key,value in pairs(craft) do copy[key]=value end
                copy.itemName=self:GetAgreementCraftPresentation(record)
                entry=self:CreatePreparedCraftEntry(copy)
                if entry then break end
            end
        end
    end
    if not entry then return nil end
    local quantity=tonumber(record.quantity) or 1
    if quantity<1 or quantity>999 or quantity%1~=0 then return nil end
    local materials={}
    for _,reagent in ipairs(entry.reagents or {}) do
        local count
        if not ignoreStock and self:IsAgreementCustomer(record) and C_Item and C_Item.GetItemCount then
            local ok,value=pcall(C_Item.GetItemCount,reagent.itemID,true,false,true)
            if ok and not (self.IsSecretValue and self:IsSecretValue(value)) and type(value)=="number" and value>=0 and value%1==0 then count=value end
        elseif not ignoreStock and not self:IsAgreementCustomer(record) then
            local snapshot=record.customerStock
            if snapshot and snapshot.customer==record.customer then count=snapshot.counts[tostring(reagent.itemID)] end
        end
        local needed=reagent.quantity*quantity
        materials[#materials+1]={itemID=reagent.itemID,quantity=needed,owned=count,missing=count and math.max(0,needed-count) or nil}
    end
    local output
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic then
        local ok,schematic=pcall(C_TradeSkillUI.GetRecipeSchematic,record.recipeID,false)
        if ok and schematic then
            local minimum=tonumber(schematic.quantityMin)
            local maximum=tonumber(schematic.quantityMax)
            if minimum and minimum>0 then output={minimum=minimum*quantity,maximum=(maximum or minimum)*quantity} end
        end
    end
    return materials,output
end

function AF:TrackAgreementMaterials(record)
    if not record or record.status~="Accepted" then return nil end
    local materials=self:GetAgreementMaterials(record)
    if not materials then return nil end
    self.db=self.db or self:EnsureDB()
    self.db.preparedCrafts=self.db.preparedCrafts or {}
    local key=table.concat({"agreement",GetRealmName and GetRealmName() or "",self.playerName or self:GetPlayerFullName(),tostring(record.id)},":")
    local prepared={key=key,mode="standard",recipeID=record.recipeID,
        itemID=record.itemID and record.itemID>0 and record.itemID or nil,
        professionID=record.professionID,itemName=self:GetAgreementCraftPresentation(record),target=record.artisan,
        createdAt=self:Now(),reagents={}}
    for _,material in ipairs(materials) do
        prepared.reagents[#prepared.reagents+1]={itemID=material.itemID,quantity=material.quantity}
    end
    for index=#self.db.preparedCrafts,1,-1 do
        if self.db.preparedCrafts[index].key==key then table.remove(self.db.preparedCrafts,index) end
    end
    table.insert(self.db.preparedCrafts,1,prepared)
    self:RefreshPreparationTracker()
    return prepared
end

-- Once accepted, these persisted values are the agreement, not live inventory.
function AF:FreezeAgreementMaterials(record,unknown,counts)
    if record.materialSnapshot then return end
    local materials,output=self:GetAgreementMaterials(record,unknown)
    record.materialSnapshot={}
    for _,material in ipairs(materials or {}) do
        local owned
        if not unknown then
            if counts then owned=counts[tostring(material.itemID)] else owned=material.owned end
        end
        record.materialSnapshot[tostring(material.itemID)]={quantity=material.quantity,owned=owned}
    end
    record.materialOutput=output
    record.customerStock=nil
end

-- Before acceptance only: authenticated customer stock for the pending terms.
function AF:SendAgreementCustomerStock(record,requestedItems)
    if not self:IsAgreementCustomer(record) or record.delivery=="draft" or (record.status~="Pending" and record.status~="Counteroffered") or not self.SendAgreementWire then return end
    local materials=self:GetAgreementMaterials(record)
    local counts={}
    -- The customer need not know the artisan's profession or recipe. Remember
    -- authenticated reagent IDs so bag events can refresh the same inventory.
    self.agreementStockItems=self.agreementStockItems or {}
    if requestedItems then record.stockItems=requestedItems end
    if record.stockItems then self.agreementStockItems[record.id]=record.stockItems end
    for id in pairs(self.agreementStockItems[record.id] or {}) do
        if C_Item and C_Item.GetItemCount then
            local ok,value=pcall(C_Item.GetItemCount,tonumber(id),true,false,true)
            if ok and not (self.IsSecretValue and self:IsSecretValue(value)) and type(value)=="number" and value>=0 and value%1==0 then
                counts[id]=math.min(value,1000000000)
            end
        end
    end
    if not self.agreementStockItems[record.id] then
        for index,material in ipairs(materials or {}) do
            if index>32 then return end
            if material.owned~=nil then counts[tostring(material.itemID)]=math.min(material.owned,1000000000) end
        end
    end
    return self:SendAgreementWire(record.artisan,{kind="customerStock",id=record.id,counts=counts})
end

function AF:RequestAgreementCustomerStock(record)
    if record.localRole~="artisan" or (record.status~="Pending" and record.status~="Counteroffered") or not self.SendAgreementWire then return end
    self.agreementStockRequests=self.agreementStockRequests or {}
    local stamp=self:Now()
    if stamp-(self.agreementStockRequests[record.id] or -math.huge)<5 then return end
    self.agreementStockRequests[record.id]=stamp
    local items={}
    for index,material in ipairs(self:GetAgreementMaterials(record) or {}) do
        if index>32 then return end
        items[tostring(material.itemID)]=true
    end
    self:SendAgreementWire(record.customer,{kind="stockRequest",id=record.id,items=items})
end
