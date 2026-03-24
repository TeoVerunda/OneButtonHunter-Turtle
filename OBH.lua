local GT = GetTime
OBH = {}

-- CONFIGURATION
OBH.AutoFeign = true
OBH.AutoMark = true       
OBH.AggroDelay = 0.2 
OBH.AlertCooldown = 3.0 
OBH.InputLagSafety = 0.1

-- DYNAMIC CALIBRATION
OBH.BaseSteady = 1.5      
OBH.BufferPercent = 0.05  
OBH.PriorityWindow = 0.1  -- The "Anti-Hiccup" threshold

OBH.t = CreateFrame("GameTooltip", "OBH_Scanner", UIParent, "GameTooltipTemplate")
OBH.f = CreateFrame("Frame", "OBH_Events", UIParent)
OBH.f:RegisterEvent("START_AUTOREPEAT_SPELL")
OBH.f:RegisterEvent("STOP_AUTOREPEAT_SPELL")

OBH.auto, OBH.next, OBH.enabled = false, nil, true
OBH.baseSpeed, OBH.aggroTime, OBH.lastAlert, OBH.lastRun = nil, nil, 0, 0 

OBH.f:SetScript("OnEvent", function()
    if event == "START_AUTOREPEAT_SPELL" then
        OBH.auto = true
        local speed = UnitRangedDamage("player") or 3
        if not OBH.baseSpeed then OBH.baseSpeed = speed end
        OBH.next = GT() + speed
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        OBH.auto, OBH.next = false, nil
    end
end)

OBH.f:SetScript("OnUpdate", function()
    if OBH.auto and OBH.next then
        local now = GT()
        if OBH.next < now then
            local speed = UnitRangedDamage("player") or 3
            OBH.next = now + speed
        end
    end
end)

OBH.name = {
    [1] = "Aimed Shot",
    [2] = "Auto Shot",
    [3] = "Steady Shot",
    [4] = "Arcane Shot",
    [5] = "Multi-Shot",
    [6] = "Feign Death",
    [7] = "Hunter's Mark",
    [8] = "Concussive Shot",
}

OBH.asSlot, OBH.arcSlot, OBH.ssSlot, OBH.msSlot, OBH.fdSlot, OBH.concSlot = nil, nil, nil, nil, nil, nil

local function SafeGetText(lineNum)
    local textObj = _G["OBH_ScannerTextLeft"..lineNum]
    if textObj and type(textObj.GetText) == "function" then
        local val = textObj:GetText()
        return (type(val) == "string") and val or ""
    end
    return ""
end

function OBH:GetActionSlot(spellName)
    for i = 1, 120 do
        OBH_Scanner:SetOwner(UIParent, "ANCHOR_NONE")
        OBH_Scanner:SetAction(i)
        if SafeGetText(1) == spellName then
            OBH_Scanner:Hide()
            return i
        end
    end
    OBH_Scanner:Hide()
    return nil
end

function OBH:IsCasting()
    if CastingBarFrame and CastingBarFrame:IsShown() then return true end
    OBH_Scanner:SetOwner(UIParent, "ANCHOR_NONE")
    OBH_Scanner:SetUnit("player")
    local text = SafeGetText(1)
    OBH_Scanner:Hide()
    if text == "" then return false end
    return string.find(text, "Casting") or string.find(text, "Aimed") or string.find(text, "Steady") or string.find(text, "Multi")
end

function OBH:HasMark()
    local i = 1
    while true do
        local texture = UnitDebuff("target", i)
        if not texture then break end
        if texture and string.find(texture, "Ability_Hunter_SniperShot") then return true end
        i = i + 1
    end
    return false
end

-- MAIN ENGINE: Version 6.2 (The "No Hesitation" Build)
function OBH:Run(useMulti)
    local now = GT()
    if (now - self.lastRun) < self.InputLagSafety then return end
    self.lastRun = now 

    if not self.enabled or not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then return end

    self.asSlot   = self.asSlot   or self:GetActionSlot(self.name[1]) or 13
    self.arcSlot  = self.arcSlot  or self:GetActionSlot(self.name[4]) or 14
    self.ssSlot   = self.ssSlot   or self:GetActionSlot(self.name[3]) or 15
    self.msSlot   = self.msSlot   or self:GetActionSlot(self.name[5]) or 16
    self.fdSlot   = self.fdSlot   or self:GetActionSlot(self.name[6]) or 18
    self.concSlot = self.concSlot or self:GetActionSlot(self.name[8]) or 19

    -- 1. MARKING
    if self.AutoMark and not self:HasMark() then
        CastSpellByName(self.name[7])
        return 
    end

    -- 2. AGGRO EMERGENCY
    local inGroup = (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0)
    if inGroup and self.AutoFeign and UnitIsUnit("targettarget", "player") then
        local _, cDur = GetActionCooldown(self.concSlot)
        if cDur == 0 then CastSpellByName(self.name[8]) end
        if not self.aggroTime then self.aggroTime = now 
        elseif (now - self.aggroTime) >= OBH.AggroDelay then
            local _, fdDur = GetActionCooldown(self.fdSlot)
            if fdDur == 0 then
                CastSpellByName(self.name[6])
                self.aggroTime = nil 
                return
            end
        end
    else self.aggroTime = nil end

    if self:IsCasting() then return end

    -- 3. ROTATION ENGINE
    local weaponSpeed = UnitRangedDamage("player") or 3
    local timeLeft = self.next and (self.next - now) or 0
    local hasteFactor = (self.baseSpeed) and (weaponSpeed / self.baseSpeed) or 1
    local currentSteadyCast = self.BaseSteady * hasteFactor
    local dynamicBuffer = weaponSpeed * self.BufferPercent
    
    local _, asDur = GetActionCooldown(self.asSlot)
    local _, msDur = GetActionCooldown(self.msSlot)

    -- Aimed Shot Check
    if asDur <= self.PriorityWindow then
        if timeLeft > (weaponSpeed * 0.9) or timeLeft < 0.1 then 
            CastSpellByName(self.name[1])
            return
        end
    end

    -- Multi-Shot Check
    if useMulti and msDur <= self.PriorityWindow and timeLeft > 0.5 then
        CastSpellByName(self.name[5])
        return
    end

    -- Steady Shot Check (The "No Hesitation" Logic)
    if timeLeft > (currentSteadyCast + dynamicBuffer) then
        CastSpellByName(self.name[3])
        return
    end

    -- Arcane Shot Filler
    if GetActionCooldown(self.arcSlot) <= self.PriorityWindow and timeLeft > 0.2 then
        CastSpellByName(self.name[4])
        return
    end

    -- Initialize Auto Shot
    if not self.auto and IsActionInRange(self.asSlot) == 1 then
        CastSpellByName(self.name[2])
    end
end

DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00OBH V6.2 (No Hesitation) Loaded.|r")
