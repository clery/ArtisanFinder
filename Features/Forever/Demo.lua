local _, AF = ...

local GetObservation = AF.GetForeverNameplateObservation
function AF:GetForeverNameplateObservation(fullName)
    local demo = self.foreverNameplateDemo
    if demo and demo.expiresAt > self:Now() and self:NormalizeName(fullName) == demo.name then
        return demo
    end
    return GetObservation(self, fullName)
end

function AF:StopForeverNameplateDemo(silent)
    self.foreverNameplateDemo = nil
    if self.foreverDemoTimer then self.foreverDemoTimer:Cancel() self.foreverDemoTimer = nil end
    self:RefreshForeverNameplates()
    if not silent then self:Print(self:Text("FOREVER_DEMO_STOPPED")) end
end

function AF:StartForeverNameplateDemo()
    self:StopForeverNameplateDemo(true)
    local unit = "player"
    if UnitIsPlayer("target") and UnitIsFriend("player", "target") then unit = "target" end
    local name = self:NormalizeName(self:GetForeverUnitFullName(unit))
    if not name then self:Print(self:Text("FOREVER_DEMO_NO_NAME")) return end
    self.foreverNameplateDemo = {name=name, professions={[164]=true,[165]=true,[333]=true},
        source="DEMO", expiresAt=self:Now()+300}
    if C_Timer and C_Timer.NewTimer then
        self.foreverDemoTimer = C_Timer.NewTimer(300, function() AF:StopForeverNameplateDemo(true) end)
    end
    self:RefreshForeverNameplates()
    self:Print(self:Text("FOREVER_DEMO_STARTED", name))
end

function AF:HandleFlavorSlash(command, rest)
    if command=="agreements" then self:ShowAgreements() return true end
    if command ~= "demo" then return false end
    if rest == "off" or rest == "stop" then self:StopForeverNameplateDemo()
    elseif rest == "" or rest == "on" then self:StartForeverNameplateDemo()
    else self:Print(self:Text("FOREVER_DEMO_HELP")) end
    return true
end

function AF:PrintFlavorSlashHelp()
    self:Print(self:Text("FOREVER_DEMO_HELP"))
    self:Print(self:Text("AGREEMENT_SLASH_HELP"))
end
