local AF={IsForever=true,db={crafterSections={item=true}}}
assert(loadfile("Flavors/Forever.lua"))("ArtisanFinder",AF)
assert(loadfile("Features/Crafter/UI.lua"))("ArtisanFinder",AF)
local function region()
    local object={shown=true,text=""}
    return setmetatable(object,{__index=function(self,key)
        if key=="IsShown" then return function() return self.shown end end
        if key=="GetText" then return function() return self.text end end
        if key=="SetShown" then return function(_,shown) self.shown=shown end end
        if key=="Show" then return function() self.shown=true end end
        if key=="Hide" then return function() self.shown=false end end
        if key=="GetTop" or key=="GetBottom" then return function() return nil end end
        if key=="HasFocus" then return function() return false end end
        return function() end
    end})
end
local function panel()
    local object=region()
    local methods=getmetatable(object).__index
    return setmetatable(object,{__index=function(self,key)
        if key:match("^[A-Z]") then return methods(self,key) end
        local value=region() rawset(self,key,value) return value
    end})
end
local defaults,item=panel(),panel()
AF.crafterDefaultsFrame,AF.crafterFrame=defaults,item
defaults.price.Field=region() defaults.note.Field=region()
item.artisanFinderHasContext=true
item.artisanFinderDirty=true
for _,key in ipairs({"defaultSectionToggle","itemSectionToggle","scanSectionToggle","advertisingSectionToggle"}) do defaults[key].arrow=region() end
item.price.artisanFinderDirty=true
item.price.text="0.1234"
item.note.artisanFinderDirty=false
AF:LayoutCrafterSections()
assert(not item.shown,"Forever can collapse item specifics with unsaved edits")
assert(item.price.text=="0.1234" and item.artisanFinderDirty,"collapse preserves unsaved commission")
AF.db.crafterSections.item=false
AF:LayoutCrafterSections()
assert(item.shown,"expanding restores item specifics")
AF.crafterUIConfig.allowCollapseDirtyItem=false AF.IsForever=false AF.db.crafterSections.item=true
AF:LayoutCrafterSections()
assert(item.shown,"Retail retains automatic visibility of dirty item specifics")
print("PASS Forever item specifics collapse/expand preserves unsaved edits and Retail behavior")
