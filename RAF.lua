local addonName, RAF = ...

RAF                  = RAF or {}
_G[addonName]        = RAF

-------------------------------------------------------
-- Saved variables
-------------------------------------------------------

RAFDB                = RAFDB or {
    x      = 0,
    y      = 0,
    locked = false,
}

-------------------------------------------------------
-- Constants
-------------------------------------------------------

local ARENA_UNITS    = { "arena1", "arena2", "arena3" }
local frameWidth     = 110
local frameHeight    = 50

local TRINKET_SPELLS = {
    [42292] = true, -- PvP Trinket (generic)
    [59752] = true, -- Every Man for Himself (human racial)
}

local spells         = {
    [46924] = true, -- Bladestorm
    [23920] = true, -- Spell Reflection
    [31224] = true, -- Cloak of Shadows
    [45438] = true, -- Ice Block
    [642]   = true, -- Divine Shield
    [10278] = true, -- Hand of Protection
    [45479] = true, -- Icebound Fortitude
    [498]   = true, -- Divine Protection
    [19263] = true, -- Deterrence
    [19574] = true, -- Bestial Wrath
    [29574] = true, -- Innervate
    [32182] = true, -- Heroism
    [2825]  = true, -- Bloodlust
    [12472] = true, -- Icy Veins
    [49039] = true, -- Lichborne
    [48707] = true, -- Anti-Magic Shell
    [47585] = true, -- Dispersion
    [33206] = true, -- Pain Suppression
    [10060] = true, -- Power Infusion
    [26669] = true, -- Evasion
    [64205] = true, -- Divine Sacrifice
    [6940]  = true, -- Hand of Sacrifice
    [46968] = true, -- Shockwave
    [17197] = true, -- Recklessness
    [20230] = true, -- Retaliation
    [5246]  = true, -- Intimidating Shout
    [20066] = true, -- Repentance
    [10308] = true, -- Hammer of Justice
    [51713] = true, -- Shadow Dance
    [16166] = true, -- Elemental Mastery
    [50334] = true, -- Berserking
    [61336] = true, -- Survival Instincts



}

-------------------------------------------------------
-- Helpers
-------------------------------------------------------

local function IsInArena()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "arena"
end

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local function GetClassColor(unit)
    local _, class = UnitClass(unit)
    local c = class and RAID_CLASS_COLORS[class]
    if c then
        return c.r, c.g, c.b
    end
    return 0.2, 0.2, 0.2
end

-------------------------------------------------------
-- Root container & movement
-------------------------------------------------------

-- Root container & movement
RAF.frame = RAF.frame or CreateFrame("Frame", addonName .. "Root", UIParent)
local root = RAF.frame

root:SetSize(frameWidth, frameHeight * #ARENA_UNITS + 8)
root:SetPoint("CENTER", UIParent, "CENTER", RAFDB.x, RAFDB.y)
root:SetMovable(true)
root:SetClampedToScreen(true)
root:EnableMouse(true)

root:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and not RAFDB.locked then
        self:StartMoving()
    end
end)

root:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local ux, uy = UIParent:GetCenter()
        RAFDB.x = x - ux
        RAFDB.y = y - uy
    end
end)

-------------------------------------------------------
-- Frame creation
-------------------------------------------------------

local function CreateArenaFrame(parent, index, unit)
    local f = CreateFrame("Button", addonName .. "Arena" .. index, parent)
    f:SetSize(frameWidth, frameHeight)
    f.unit = unit

    if index == 1 then
        -- first frame anchored to the root, just like InterruptBar icons to bar
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    else
        -- others stacked below the previous one
        f:SetPoint("TOPLEFT", parent.frames[index - 1], "BOTTOMLEFT", 0, -4)
    end

    f:RegisterForClicks("AnyUp")
    f:EnableMouse(true)

    -- Class-colored background (neutral; bars get class color)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0, 0, 0, 0.8)
    f.bg = bg

    -- Black border (always visible)
    local black = f:CreateTexture(nil, "BORDER")
    black:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    black:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
    black:SetTexture(0, 0, 0, 1)
    f.blackBorder = black

    -- White border (only when targeted)
    local white = f:CreateTexture(nil, "OVERLAY")
    white:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2)
    white:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
    white:SetTexture(1, 1, 1, 1)
    white:Hide()
    f.targetBorder = white

    -- Health bar (solid)
    local hp = CreateFrame("StatusBar", nil, f)
    hp:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    hp:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    hp:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    hp:SetHeight(frameHeight * 0.8)
    hp:SetMinMaxValues(0, 1)
    hp:SetValue(1)
    f.healthBar = hp

    -- Power bar (solid)
    local pp = CreateFrame("StatusBar", nil, f)
    pp:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    pp:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -1)
    pp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    pp:SetMinMaxValues(0, 1)
    pp:SetValue(1)
    f.powerBar = pp

    -- Trinket icon (slightly smaller than frame height)
    local trinketSize = frameHeight - 20 -- 40 if frameHeight = 50
    local trinket = CreateFrame("Frame", nil, f)
    trinket:SetSize(trinketSize, trinketSize)
    trinket:SetPoint("LEFT", f, "RIGHT", 4, 0)

    -- Black border
    local tBorder = trinket:CreateTexture(nil, "BORDER")
    tBorder:SetPoint("TOPLEFT", trinket, "TOPLEFT", -1, 1)
    tBorder:SetPoint("BOTTOMRIGHT", trinket, "BOTTOMRIGHT", 1, -1)
    tBorder:SetTexture(0, 0, 0, 1)

    -- Icon texture (zoomed)
    local tTex = trinket:CreateTexture(nil, "ARTWORK")
    tTex:SetAllPoints()
    tTex:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    -- Cooldown spiral
    local tCD = CreateFrame("Cooldown", nil, trinket, "CooldownFrameTemplate")
    tCD:SetAllPoints()
    tCD.noomnicc        = true
    tCD.noCooldownCount = true

    trinket.icon        = tTex
    trinket.cd          = tCD
    trinket:Hide()

    f.trinket = trinket

    -- Left-side spells icon (e.g. important buff/debuff)
    local spellsSize = frameHeight - 20 -- a bit smaller than the frame
    local spellsIcon = CreateFrame("Frame", nil, f)
    spellsIcon:SetSize(spellsSize, spellsSize)
    spellsIcon:SetPoint("RIGHT", f, "LEFT", -4, 0)

    -- Black border
    local sBorder = spellsIcon:CreateTexture(nil, "BORDER")
    sBorder:SetPoint("TOPLEFT", spellsIcon, "TOPLEFT", -1, 1)
    sBorder:SetPoint("BOTTOMRIGHT", spellsIcon, "BOTTOMRIGHT", 1, -1)
    sBorder:SetTexture(0, 0, 0, 1)

    -- Zoomed texture
    local sTex = spellsIcon:CreateTexture(nil, "ARTWORK")
    sTex:SetAllPoints()
    sTex:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    -- Cooldown spiral
    local sCD = CreateFrame("Cooldown", nil, spellsIcon, "CooldownFrameTemplate")
    sCD:SetAllPoints()
    sCD.noomnicc        = true
    sCD.noCooldownCount = true

    spellsIcon.icon     = sTex
    spellsIcon.cd       = sCD
    spellsIcon:Hide()

    f.spellsIcon = spellsIcon

    -- Drag by child frames (when unlocked)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and RAFDB.locked and UnitExists(self.unit) then
            TargetUnit(self.unit)
        end
    end)

    return f
end

root.frames = {}
for i, unit in ipairs(ARENA_UNITS) do
    root.frames[i] = CreateArenaFrame(root, i, unit)
end

local function RAF_UpdateSpellsIconForUnitFrame(f)
    if not f.spellsIcon or not f.unit then return end

    local unit = f.unit
    local now = GetTime()

    local bestSpellId, bestIcon, bestStart, bestDuration, bestRemaining

    -- Check debuffs
    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime,
        unitCaster, isStealable, _, spellId = UnitDebuff(unit, i)
        if not name then break end

        if spells[spellId] and duration and duration > 0 and expirationTime then
            local remaining = expirationTime - now
            if remaining > 0 and (not bestRemaining or remaining > bestRemaining) then
                bestSpellId   = spellId
                bestIcon      = icon
                bestDuration  = duration
                bestStart     = expirationTime - duration
                bestRemaining = remaining
            end
        end
    end

    -- Optionally also check buffs (UnitBuff) if your list includes them:
    for i = 1, 40 do
        local name, icon, count, buffType, duration, expirationTime,
        unitCaster, isStealable, _, spellId = UnitBuff(unit, i)
        if not name then break end

        if spells[spellId] and duration and duration > 0 and expirationTime then
            local remaining = expirationTime - now
            if remaining > 0 and (not bestRemaining or remaining > bestRemaining) then
                bestSpellId   = spellId
                bestIcon      = icon
                bestDuration  = duration
                bestStart     = expirationTime - duration
                bestRemaining = remaining
            end
        end
    end

    if bestSpellId then
        f.spellsIcon.icon:SetTexture(bestIcon or "")
        f.spellsIcon:Show()
        f.spellsIcon.cd:SetCooldown(bestStart, bestDuration)
    else
        f.spellsIcon:Hide()
    end
end

-------------------------------------------------------
-- Updating frames
-------------------------------------------------------

local function UpdateUnitFrame(f)
    local unit = f.unit

    if not UnitExists(unit) or (not IsInArena() and not RAF.testMode) then
        f:Hide()
        return
    end

    f:Show()

    local r, g, b = GetClassColor(unit)

    -- Neutral background
    f.bg:SetTexture(0, 0, 0, 0.8)

    -- Class-colored solid bars
    f.healthBar:SetStatusBarColor(r, g, b, 1)
    f.powerBar:SetStatusBarColor(r, g, b * 0.8, 1)

    local hp, hpMax = UnitHealth(unit), UnitHealthMax(unit)
    if hpMax and hpMax > 0 then
        f.healthBar:SetMinMaxValues(0, hpMax)
        f.healthBar:SetValue(hp)
    end

    local powerType = UnitPowerType(unit)
    local pp, ppMax = UnitPower(unit, powerType), UnitPowerMax(unit, powerType)
    if ppMax and ppMax > 0 then
        f.powerBar:SetMinMaxValues(0, ppMax)
        f.powerBar:SetValue(pp)
    end

    if UnitIsUnit("target", unit) then
        f.targetBorder:Show()
    else
        f.targetBorder:Hide()
    end
    RAF_UpdateSpellsIconForUnitFrame(f)
end

function RAF:UpdateAll()
    for _, f in ipairs(root.frames) do
        UpdateUnitFrame(f)
    end
end

-------------------------------------------------------
-- Visibility & test mode
-------------------------------------------------------

RAF.testMode = RAF.testMode or false

function RAF:SetVisible(state)
    if state then
        root:Show()
    else
        root:Hide()
    end
end

function RAF:RefreshVisibility()
    if self.testMode then
        self:SetVisible(true)
        for i, f in ipairs(root.frames) do
            f:Show()
            f.bg:SetTexture(0, 0, 0, 0.8)
            f.healthBar:SetMinMaxValues(0, 100)
            f.healthBar:SetValue(80 - (i - 1) * 10)
            f.powerBar:SetMinMaxValues(0, 100)
            f.powerBar:SetValue(50 + (i - 1) * 10)
            f.healthBar:SetStatusBarColor(0.2, 0.6, 1, 1)
            f.powerBar:SetStatusBarColor(0.2, 0.6, 0.8, 1)
            f.targetBorder:Hide()
            -- inside: for i, f in ipairs(root.frames) do
            if f.trinket then
                local _, _, tex = GetSpellInfo(59752) -- PvP trinket icon
                f.trinket.icon:SetTexture(tex or "")
                f.trinket:Show()
                f.trinket.cd:SetCooldown(0, 0) -- no cooldown in test
            end
            if f.spellsIcon then
                local _, _, tex = GetSpellInfo(29574) -- Innervate
                f.spellsIcon.icon:SetTexture(tex or "")
                f.spellsIcon:Show()
                f.spellsIcon.cd:SetCooldown(GetTime() - 5, 20) -- no cooldown in test, just show the icon
            end
        end
        return
    end

    if IsInArena() then
        self:SetVisible(true)
        self:UpdateAll()
    else
        self:SetVisible(false)
    end
end

local function RAF_OnCombatLogEvent(...)
    local timestamp, eventType,
    srcGUID, srcName, srcFlags,
    dstGUID, dstName, dstFlags,
    spellID, spellName, spellSchool = ...
    if eventType ~= "SPELL_CAST_SUCCESS" then return end
    if not TRINKET_SPELLS[spellID] then return end

    for _, f in ipairs(root.frames) do
        if f.unit and UnitGUID(f.unit) == srcGUID and f.trinket then
            local _, _, tex = GetSpellInfo(spellID)
            f.trinket.icon:SetTexture(tex or "")
            f.trinket:Show()
            f.trinket.cd:SetCooldown(GetTime(), 120)
        end
    end
end

-------------------------------------------------------
-- Events
-------------------------------------------------------

local ef = CreateFrame("Frame")
ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ef:RegisterEvent("PLAYER_ENTERING_WORLD")
ef:RegisterEvent("ARENA_OPPONENT_UPDATE")
ef:RegisterEvent("UNIT_HEALTH")
ef:RegisterEvent("UNIT_MAXHEALTH")
ef:RegisterEvent("UNIT_MANA")
ef:RegisterEvent("UNIT_RAGE")
ef:RegisterEvent("UNIT_ENERGY")
ef:RegisterEvent("UNIT_RUNIC_POWER")
ef:RegisterEvent("PLAYER_TARGET_CHANGED")
ef:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ef:RegisterEvent("UNIT_AURA")

ef:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "PLAYER_LOGIN" then
        DEFAULT_CHAT_FRAME:AddMessage(
            "RaidArenaFrames loaded. Use /raf test to toggle test mode, /raf lock to toggle lock.", 0.4, 0.8, 1)
        RAF:RefreshVisibility()
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        RAF:RefreshVisibility()
    elseif event == "PLAYER_TARGET_CHANGED" then
        RAF:UpdateAll()
    elseif event == "ARENA_OPPONENT_UPDATE" then
        RAF:UpdateAll()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        RAF_OnCombatLogEvent(arg1, ...)
    elseif event:match("^UNIT_") and arg1 and arg1:match("^arena[1-3]$") then
        RAF:UpdateAll()
    elseif event == "UNIT_AURA" and arg1 and arg1:match("^arena[1-3]$") then
        RAF:UpdateAll()
    end
end)

-------------------------------------------------------
-- Slash commands
-------------------------------------------------------

SLASH_RAIDARENAFRAMES1 = "/raf"
SlashCmdList["RAIDARENAFRAMES"] = function(msg)
    msg = msg and msg:lower() or ""
    if msg == "test" then
        RAF.testMode = not RAF.testMode
        RAF:RefreshVisibility()
        DEFAULT_CHAT_FRAME:AddMessage("RaidArenaFrames test mode: " .. tostring(RAF.testMode), 0.4, 0.8, 1)
    elseif msg == "lock" then
        RAFDB.locked = not RAFDB.locked
        DEFAULT_CHAT_FRAME:AddMessage("RaidArenaFrames locked: " .. tostring(RAFDB.locked), 0.4, 0.8, 1)
    else
        DEFAULT_CHAT_FRAME:AddMessage("/raf test - toggle test mode", 0.4, 0.8, 1)
        DEFAULT_CHAT_FRAME:AddMessage("/raf lock - toggle lock", 0.4, 0.8, 1)
    end
end
