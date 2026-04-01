local GT = GetTime

OBH = {}   -- Ranged / Global
OBHM = {}  -- Melee / Survival

-- ==========================================
-- 1. CONFIGURATION
-- ==========================================
OBH.AutoFeign = true
OBH.AutoMark = true
OBH.MarkHealthCutoff = 10
OBH.MarkRetryDelay = 5.0
OBH.AggroDelay = 0.5
OBH.AlertCooldown = 3.0
OBH.InputLagSafety = 0.1

OBH.BaseSteady = 1.5
OBH.BufferPercent = 0.02
OBH.PriorityWindow = 0.1
OBH.RaidLagBuffer = 0.2

OBHM.DeterrenceHP = 50

-- ASPECT SETTINGS
OBH.HawkTexture  = "Interface\\Icons\\Spell_Nature_RavenForm"
OBH.WolfTexture  = "Interface\\Icons\\Ability_Mount_WhiteDireWolf"
OBH.ViperTexture = "Interface\\Icons\\Ability_hunter_aspectoftheviper"

OBH.ViperLow  = 5
OBH.ViperHigh = 30
OBH.AspectEnabled = true   -- Set false to disable auto aspects by default

-- IMPROVED FALLBACK SLOTS (less likely to conflict)
local FORCED_SLOTS = {
    as = 61, arc = 62, ss = 63, ms = 64,
    fd = 65, conc = 66,
    rapt = 67, mong = 68, wing = 69,
    lace = 70, carve = 71,
    exp = 72, immol = 73
}

-- SPELL NAMES
OBH.name = {
    [1]  = "Aimed Shot",      [2]  = "Auto Shot",
    [3]  = "Steady Shot",     [4]  = "Arcane Shot",
    [5]  = "Multi-Shot",      [6]  = "Feign Death",
    [7]  = "Hunter's Mark",   [8]  = "Concussive Shot",
    [9]  = "Raptor Strike",   [10] = "Mongoose Bite",
    [11] = "Wing Clip",       [12] = "Aspect of the Wolf",
    [13] = "Deterrence",      [14] = "Carve",
    [15] = "Lacerate",        [16] = "Explosive Trap",
    [17] = "Immolation Trap"
}

-- ==========================================
-- 2. CORE SYSTEMS
-- ==========================================
OBH.t = CreateFrame("GameTooltip", "OBH_Scanner", UIParent, "GameTooltipTemplate")
OBH.f = CreateFrame("Frame", "OBH_Events", UIParent)

OBH.f:RegisterEvent("START_AUTOREPEAT_SPELL")
OBH.f:RegisterEvent("STOP_AUTOREPEAT_SPELL")

OBH.auto, OBH.next, OBH.enabled = false, nil, true
OBH.baseSpeed, OBH.aggroTime, OBH.lastAlert, OBH.lastRun = nil, nil, 0, 0
OBH.lastMarkTime, OBH.lastMarkGUID = 0, nil
OBH.warned = false

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

function OBH:HasBuff(texPath)
    for i = 1, 32 do
        local tex = UnitBuff("player", i)
        if not tex then break end
        if string.find(tex, texPath) then return true end
    end
    return false
end

-- ==========================================
-- SLASH COMMAND
-- ==========================================
SLASH_OBH1 = "/obh"
SlashCmdList["OBH"] = function(msg)
    msg = strlower(msg or "")
    if msg == "aspect off" or msg == "off" then
        OBH.AspectEnabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[OBH] Aspect Manager → Disabled|r")
    elseif msg == "aspect on" or msg == "on" then
        OBH.AspectEnabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[OBH] Aspect Manager → Enabled|r")
    elseif msg == "aspect" or msg == "status" then
        local status = OBH.AspectEnabled and "|cff00ff00ENABLED" or "|cffff0000DISABLED"
        DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[OBH] Aspect Manager is " .. status .. "|r")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[OBH] Usage: /obh aspect on | off | status|r")
    end
end

-- ==========================================
-- 3. RANGED ENGINE (with improved warnings)
-- ==========================================
function OBH:Run(useMulti)
    local now = GT()
    if (now - self.lastRun) < self.InputLagSafety then return end
    self.lastRun = now

    if not self.enabled or not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then return end

    -- Slot Detection + Warning
    self.asSlot   = self.asSlot   or self:GetActionSlot(self.name[1], FORCED_SLOTS.as)
    self.arcSlot  = self.arcSlot  or self:GetActionSlot(self.name[4], FORCED_SLOTS.arc)
    self.ssSlot   = self.ssSlot   or self:GetActionSlot(self.name[3], FORCED_SLOTS.ss)
    self.msSlot   = self.msSlot   or self:GetActionSlot(self.name[5], FORCED_SLOTS.ms)
    self.fdSlot   = self.fdSlot   or self:GetActionSlot(self.name[6], FORCED_SLOTS.fd)
    self.concSlot = self.concSlot or self:GetActionSlot(self.name[8], FORCED_SLOTS.conc)

    if self.asSlot == FORCED_SLOTS.as and not GetActionInfo(self.asSlot) then
        if not OBH.warned then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[OBH] WARNING: Aimed Shot not found on action bars!|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Please place Aimed Shot somewhere visible.|r")
            OBH.warned = true
        end
    end

    -- Aspect Management with Toggle
    if OBH.AspectEnabled then
        local manaP = (UnitMana("player") / UnitManaMax("player")) * 100
        if manaP <= OBH.ViperLow then
            if not self:HasBuff(OBH.ViperTexture) then
                CastSpellByName("Aspect of the Viper")
            end
        elseif manaP >= OBH.ViperHigh then
            if not self:HasBuff(OBH.HawkTexture) then
                CastSpellByName("Aspect of the Hawk")
            end
        end
    end

    -- Ranged Rotation
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

    local weaponSpeed = UnitRangedDamage("player") or 3
    local timeLeft = self.next and (self.next - now) or 0
    local hasteFactor = (self.baseSpeed) and (weaponSpeed / self.baseSpeed) or 1
    local currentSteadyCast = self.BaseSteady * hasteFactor
    local dynamicBuffer = weaponSpeed * self.BufferPercent

    local _, asDur = GetActionCooldown(self.asSlot)
    local _, msDur = GetActionCooldown(self.msSlot)

    if (asDur - self.RaidLagBuffer) <= self.PriorityWindow then
        if timeLeft > (weaponSpeed * 0.85) or timeLeft < 0.15 then
            CastSpellByName(self.name[1])
            return
        end
    end

    if useMulti and msDur <= self.PriorityWindow and timeLeft > 0.4 then
        CastSpellByName(self.name[5])
        return
    end

    local ssWindow = (weaponSpeed < 1.9) and 0.25 or (currentSteadyCast + dynamicBuffer)
    if timeLeft > ssWindow then
        CastSpellByName(self.name[3])
        return
    end

    if GetActionCooldown(self.arcSlot) <= self.PriorityWindow and timeLeft > 0.2 then
        CastSpellByName(self.name[4])
        return
    end

    if not self.auto and IsActionInRange(self.asSlot) == 1 then
        CastSpellByName(self.name[2])
    end
end

-- ==========================================
-- 4. MELEE ENGINE
-- ==========================================
function OBHM:Run(isAoE)
    local now = GT()
    if (now - (OBH.lastRun or 0)) < OBH.InputLagSafety then return end
    OBH.lastRun = now

    if not UnitExists("target") or UnitIsDead("target") then
        TargetNearestEnemy()
        if UnitExists("target") then
            local mongSlot = OBH:GetActionSlot(OBH.name[10], FORCED_SLOTS.mong)
            local wingSlot = OBH:GetActionSlot(OBH.name[11], FORCED_SLOTS.wing)
            if IsActionInRange(mongSlot) ~= 1 and IsActionInRange(wingSlot) ~= 1 then
                ClearTarget()
                return
            end
        end
    end

    if not UnitExists("target") or not UnitCanAttack("player", "target") then return end

    -- Aspect Logic with Toggle
    if OBH.AspectEnabled then
        local manaP = (UnitMana("player") / UnitManaMax("player")) * 100
        if manaP <= OBH.ViperLow then
            if not OBH:HasBuff(OBH.ViperTexture) then
                CastSpellByName("Aspect of the Viper")
            end
        elseif manaP >= OBH.ViperHigh then
            if not OBH:HasBuff(OBH.WolfTexture) then
                CastSpellByName("Aspect of the Wolf")
            end
        end
    end

    -- Defensive
    local hpP = (UnitHealth("player") / UnitHealthMax("player")) * 100
    if hpP < OBHM.DeterrenceHP then
        CastSpellByName(OBH.name[13])
    end

    -- Aggro Feign
    if (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0) and UnitIsUnit("targettarget", "player") then
        CastSpellByName(OBH.name[6])
        return
    end

    -- Melee Rotation
    local laceSlot = OBH:GetActionSlot(OBH.name[15], FORCED_SLOTS.lace)
    local raptSlot = OBH:GetActionSlot(OBH.name[9], FORCED_SLOTS.rapt)

    local _, laceCD = GetActionCooldown(laceSlot)
    if laceCD == 0 then
        CastSpellByName(OBH.name[15])
    end

    if isAoE then
        CastSpellByName(OBH.name[14])
        CastSpellByName(OBH.name[16])
    else
        CastSpellByName(OBH.name[17])
    end

    if not IsCurrentAction(raptSlot) then
        CastSpellByName(OBH.name[9])
    end

    CastSpellByName(OBH.name[10])

    local _, wingCD = GetActionCooldown(FORCED_SLOTS.wing)
    local _, mongCD = GetActionCooldown(FORCED_SLOTS.mong)
    local _, raptCD = GetActionCooldown(FORCED_SLOTS.rapt)
    if wingCD == 0 and laceCD > 0 and raptCD > 0 and mongCD > 0 then
        CastSpellByName(OBH.name[11])
    end
end

-- ==========================================
-- LOAD MESSAGE
-- ==========================================
local aspectStatus = OBH.AspectEnabled and "|cff00ff00ENABLED" or "|cffff0000DISABLED"
DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00OBH V7.0 Loaded.|r Aspect Manager: " .. aspectStatus)
DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00/obh aspect on | off | status  -  Toggle auto aspects|r")
