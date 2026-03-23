local GT = GetTime
OBH = {}

-- CONFIGURATION
OBH.AutoFeign = true
OBH.AggroDelay = 0.2 -- Seconds to wait before Feigning
OBH.AlertCooldown = 3.0 -- Seconds to wait before showing the red alert again

OBH.t = CreateFrame("GameTooltip", "OBH_Scanner", UIParent, "GameTooltipTemplate")
OBH.f = CreateFrame("Frame", "OBH_Events", UIParent)
OBH.f:RegisterEvent("START_AUTOREPEAT_SPELL")
OBH.f:RegisterEvent("STOP_AUTOREPEAT_SPELL")

OBH.auto = false
OBH.next = nil
OBH.enabled = true
OBH.baseSpeed = nil 
OBH.aggroTime = nil -- Tracks when the mob first targeted us
OBH.lastAlert = 0   -- Tracks when the last chat message was sent

-- Event handler
OBH.f:SetScript("OnEvent", function()
    if event == "START_AUTOREPEAT_SPELL" then
        OBH.auto = true
        local speed = UnitRangedDamage("player") or 3
        if not OBH.baseSpeed then OBH.baseSpeed = speed end
        OBH.next = GT() + speed
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        OBH.auto = false
        OBH.next = nil
    end
end)

-- OnUpdate: Predicts the next shot time
OBH.f:SetScript("OnUpdate", function()
    if OBH.auto and OBH.next then
        local now = GT()
        if OBH.next < now then
            local speed = UnitRangedDamage("player") or 3
            OBH.next = now + speed
        end
    end
end)

-- Spell Names
OBH.name = {
    [1] = "Aimed Shot",
    [2] = "Auto Shot",
    [3] = "Steady Shot",
    [4] = "Arcane Shot",
    [5] = "Multi-Shot",
    [6] = "Feign Death",
}

OBH.asSlot, OBH.arcSlot, OBH.ssSlot, OBH.msSlot, OBH.fdSlot = nil, nil, nil, nil, nil

-- SAFE HELPER
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

-- MAIN ENGINE: Version 4.4 (Aggro Confirmation + Spam Filter)
function OBH:Run(useMulti)
    if not self.enabled or not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then return end

    -- Load slots
    self.asSlot  = self.asSlot  or self:GetActionSlot(self.name[1]) or 13
    self.arcSlot = self.arcSlot or self:GetActionSlot(self.name[4]) or 14
    self.ssSlot  = self.ssSlot  or self:GetActionSlot(self.name[3]) or 15
    self.msSlot  = self.msSlot  or self:GetActionSlot(self.name[5]) or 16
    self.fdSlot  = self.fdSlot  or self:GetActionSlot(self.name[6]) or 18

    ---------------------------------------
    -- V4.4: AGGRO CONFIRMATION (With Chat Throttling)
    ---------------------------------------
    local now = GT()
    local inGroup = (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0)
    
    if inGroup and self.AutoFeign then
        if UnitIsUnit("targettarget", "player") then
            -- Mob is targeting us; start/check the timer
            if not self.aggroTime then 
                self.aggroTime = now 
            elseif (now - self.aggroTime) >= OBH.AggroDelay then
                local fdStart, fdDur = GetActionCooldown(self.fdSlot)
                if fdDur == 0 then
                    CastSpellByName(self.name[6])
                    
                    -- Only print the red message if the cooldown has passed
                    if (now - self.lastAlert) >= self.AlertCooldown then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000OBH: Aggro Confirmed! Feigning Death.|r")
                        self.lastAlert = now
                    end
                    
                    self.aggroTime = nil -- Reset timer after use
                    return
                end
            end
        else
            -- Mob is NOT targeting us; reset the timer
            self.aggroTime = nil
        end
    end

    if self:IsCasting() then return end

    local weaponSpeed = UnitRangedDamage("player") or 3
    local timeLeft = self.next and (self.next - now) or 0
    local hasteFactor = (self.baseSpeed) and (weaponSpeed / self.baseSpeed) or 1
    
    local steadyWindow = 1.7 * hasteFactor 
    local multiWindow  = 0.6 * hasteFactor
    local arcaneWindow = 0.3 * hasteFactor

    -- PRIORITY 1: Hybrid Aimed Shot
    if GetActionCooldown(self.asSlot) == 0 then
        if timeLeft > (weaponSpeed * 0.9) or timeLeft < 0.1 then 
            CastSpellByName(self.name[1])
            return
        end
    end

    -- PRIORITY 2: Steady Shot
    if timeLeft > steadyWindow then
        CastSpellByName(self.name[3])
        return
    end

    -- PRIORITY 3: The Brothers
    if useMulti then
        if GetActionCooldown(self.msSlot) == 0 and timeLeft > multiWindow then
            CastSpellByName(self.name[5])
            return
        end
    end

    if GetActionCooldown(self.arcSlot) == 0 and timeLeft > arcaneWindow then
        CastSpellByName(self.name[4])
        return
    end

    -- PRIORITY 4: Auto Shot
    if not self.auto and IsActionInRange(self.asSlot) == 1 then
        CastSpellByName(self.name[2])
    end
end

DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00OBH V4.4 (Chat Spam Protection) Loaded.|r")
