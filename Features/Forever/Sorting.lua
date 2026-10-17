local _, AF = ...
local keys={name=true,source=true,price=true,observed=true}

function AF:GetForeverDirectorySort()
    local sort=self.db and self.db.foreverDirectorySort
    if type(sort)~="table" or not keys[sort.key] then return "name",false end
    return sort.key,sort.descending==true
end
function AF:SetForeverDirectorySort(key)
    if not keys[key] then return end
    local current,descending=self:GetForeverDirectorySort()
    if current==key then descending=not descending else descending=key=="observed" end
    self.db.foreverDirectorySort={key=key,descending=descending}
    self.directoryPage=1
    if self.customerFrame then self.customerFrame.scroll:SetVerticalScroll(0) end
    self:RefreshCustomerResults()
end
function AF:SortForeverDirectoryRows(rows)
    local key,descending=self:GetForeverDirectorySort()
    local values,favorites={},{}
    for _,row in ipairs(rows) do
        favorites[row]=self:IsFavoriteArtisan(row.entry)==true
        if key=="price" then
            local _,_,price=self:GetForeverDirectoryPrice(row)
            values[row]=price
        elseif key=="observed" then values[row]=tonumber(row.updatedAt) or 0
        elseif key=="source" then
            values[row]=self:GetForeverDiscoverySourceLabel(row.source):lower()
        else values[row]=row.name:lower() end
    end
    table.sort(rows,function(a,b)
        if favorites[a]~=favorites[b] then return favorites[a] end
        local left,right=values[a],values[b]
        -- Missing quotes always follow known prices, in either direction.
        if left==nil or right==nil then
            if left~=right then return left~=nil end
        elseif left~=right then
            if descending then return left>right end
            return left<right
        end
        if a.name:lower()~=b.name:lower() then return a.name:lower()<b.name:lower() end
        return a.name<b.name
    end)
end

-- Preserve the visible session's order while presence/price timestamps update.
function AF:StabilizeForeverDirectoryRows(rows,context)
    local state=self.directoryLiveOrder
    if not state or state.context~=context then
        state={context=context,ranks={},nextRank=0}
        self.directoryLiveOrder=state
    end
    for _,row in ipairs(rows) do
        if not state.ranks[row.name] then
            state.nextRank=state.nextRank+1 state.ranks[row.name]=state.nextRank
        end
    end
    table.sort(rows,function(a,b)
        local favoriteA,favoriteB=self:IsFavoriteArtisan(a.entry)==true,self:IsFavoriteArtisan(b.entry)==true
        if favoriteA~=favoriteB then return favoriteA end
        return state.ranks[a.name]<state.ranks[b.name]
    end)
end
