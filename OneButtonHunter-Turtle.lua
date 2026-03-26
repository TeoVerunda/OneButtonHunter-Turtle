local GT = GetTime
OBH = {}

-- CONFIGURATION
OBH.AutoFeign = true
OBH.AutoMark = true       
OBH.MarkHealthCutoff = 10 -- Don't mark if target HP is below 10%
OBH.MarkRetryDelay = 5.0  -- Fail-safe: Don't re-mark same target for 5s if icon is hidden
OBH.AggroDelay = 0.5 
OBH.AlertCooldown = 3.0 
OBH.InputLagSafety = 0.1

-- DYNAMIC CALIBRATION
OBH.BaseSteady = 1.5      
OBH.BufferPercent = 0.02 
OBH.PriorityWindow = 0.1  
OBH.RaidLagBuffer = 0.2  

-- EMERGENCY FALLBACK SLOTS (Update if your bars differ)
local FORCED_SLOTS = {
    as = 13,  -- Aimed Shot
    arc = 14, -- Arcane Shot
    ss = 15,  -- Steady Shot
    ms = 16,  -- Multi-Shot
    fd = 18,  -- Feign Death
    conc = 19 -- Concussive
}

OBH.t = CreateFrame("GameTooltip", "OBH_Scanner", UIParent, "GameTooltipTemplate")
OBH.f = CreateFrame("Frame", "OBH_Events", UIParent)
OBH.f:RegisterEvent("START_AUTOREPEAT_SPELL")
OBH.f:RegisterEvent("STOP_AUTOREPEAT_SPELL")

OBH.auto, OBH.next, OBH.enabled = false, nil, true
OBH.baseSpeed, OBH.aggroTime, OBH.lastAlert, OBH.lastRun = nil, nil, 0, 0 
OBH.lastMarkTime, OBH.lastMarkGUID = 0, nil 

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

local function SafeGetText(lineNum)
    local textObj = _G["OBH_ScannerTextLeft"..lineNum]
    if textObj and type(textObj.GetText) == "function" then
        local val = textObj:GetText()
        return (type(val) == "string") and val or ""
    end
    return ""
end

function OBH:GetActionSlot(spellName, fallback)
    for i = 1, 120 do
        OBH_Scanner:SetOwner(UIParent, "ANCHOR_NONE")
        OBH_Scanner:SetAction(i)
        if SafeGetText(1) == spellName then
            OBH_Scanner:Hide()
            return i
        end
    end
    OBH_Scanner:Hide()
    return fallback
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
    local markTex = "Interface\\Icons\\Ability_Hunter_SniperShot"
    for i = 1, 32 do
        local texture = UnitDebuff("target", i)
        if not texture then break end
        if texture == markTex or string.find(texture, "SniperShot") then return true end
    end
    return false
end

-- MAIN ENGINE: VERSION 6.5 (TACTICAL RAID BUILD)
function OBH:Run(useMulti)
    local now = GT()
    if (now - self.lastRun) < self.InputLagSafety then return end
    self.lastRun = now 

    if not self.enabled or not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then return end

    -- Slot Detection Fallbacks
    self.asSlot   = self.asSlot   or self:GetActionSlot(self.name[1], FORCED_SLOTS.as)
    self.arcSlot  = self.arcSlot  or self:GetActionSlot(self.name[4], FORCED_SLOTS.arc)
    self.ssSlot   = self.ssSlot   or self:GetActionSlot(self.name[3], FORCED_SLOTS.ss)
    self.msSlot   = self.msSlot   or self:GetActionSlot(self.name[5], FORCED_SLOTS.ms)
    self.fdSlot   = self.fdSlot   or self:GetActionSlot(self.name[6], FORCED_SLOTS.fd)
    self.concSlot = self.concSlot or self:GetActionSlot(self.name[8], FORCED_SLOTS.conc)

    -- 1. TACTICAL MARKING
    local targetID = (UnitGUID and UnitGUID("target")) or UnitName("target")
    local targetHP = (UnitHealth("target") / UnitHealthMax("target")) * 100
    
    if self.AutoMark and targetHP > self.MarkHealthCutoff and not self:HasMark() then
        if self.lastMarkGUID ~= targetID or (now - self.lastMarkTime) > self.MarkRetryDelay then
            CastSpellByName(self.name[7])
            self.lastMarkTime = now
            self.lastMarkGUID = targetID
            return 
        end
    end

    -- 2. AGGRO EMERGENCY
    local inGroup = (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0)
    if inGroup and self.AutoFeign and UnitIsUnit("targettarget", "player") then
        local _, cDur = GetActionCooldown(self.concSlot)
        if cDur == 0 then CastSpellByName(self.name[8]) end
        if not self.aggroTime then self.aggroTime = now 
        elseif (now - self.aggroTime) >= self.AggroDelay then
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
    if (asDur - self.RaidLagBuffer) <= self.PriorityWindow then
        if timeLeft > (weaponSpeed * 0.85) or timeLeft < 0.15 then 
            CastSpellByName(self.name[1])
            return
        end
    end

    -- Multi-Shot Check
    if useMulti and msDur <= self.PriorityWindow and timeLeft > 0.4 then
        CastSpellByName(self.name[5])
        return
    end

    -- Steady Shot Check
    local ssWindow = (weaponSpeed < 1.9) and 0.25 or (currentSteadyCast + dynamicBuffer)
    if timeLeft > ssWindow then
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

DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00OBH V6.6 (Github Release Build) Loaded.|r")
