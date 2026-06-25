----------------------------------------------------------------------
-- Silly Raid Item Lists - Core.lua
-- Data layer: profiles, entries, bag scanning, import/export
----------------------------------------------------------------------

local addonName, SRIL = ...
_G["SillyRaidItemLists"] = SRIL

SRIL.version = "1.0.0"

----------------------------------------------------------------------
-- Default saved-variable structure
----------------------------------------------------------------------
local DEFAULT_DB = {
    minimap = { hide = false, minimapPos = 225 },
    activeProfile = "Default",
    profiles = {
        ["Default"] = {
            entries = {},  -- ordered list of {type="item"|"header", ...}
        },
    },
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[DeepCopy(k)] = DeepCopy(v) end
    return dst
end

----------------------------------------------------------------------
-- Simple base64 encode/decode for import/export
----------------------------------------------------------------------
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64Encode(data)
    local out = {}
    local pad = 0
    for i = 1, #data, 3 do
        local a, b, c = string.byte(data, i, i + 2)
        b = b or 0; c = c or 0
        if i + 1 > #data then pad = pad + 1 end
        if i + 2 > #data then pad = pad + 1 end
        local n = a * 65536 + b * 256 + c
        table.insert(out, string.sub(b64chars, math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1))
        table.insert(out, string.sub(b64chars, math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1))
        if pad < 2 then
            table.insert(out, string.sub(b64chars, math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1))
        else
            table.insert(out, "=")
        end
        if pad < 1 then
            table.insert(out, string.sub(b64chars, n % 64 + 1, n % 64 + 1))
        else
            table.insert(out, "=")
        end
    end
    return table.concat(out)
end

local b64lookup = {}
for i = 1, 64 do b64lookup[string.byte(b64chars, i)] = i - 1 end

local function base64Decode(data)
    data = data:gsub("[^%w%+%/=]", "")
    local out = {}
    for i = 1, #data, 4 do
        local a = b64lookup[string.byte(data, i)] or 0
        local b = b64lookup[string.byte(data, i + 1)] or 0
        local c = b64lookup[string.byte(data, i + 2)] or 0
        local d = b64lookup[string.byte(data, i + 3)] or 0
        local n = a * 262144 + b * 4096 + c * 64 + d
        table.insert(out, string.char(math.floor(n / 65536) % 256))
        if string.sub(data, i + 2, i + 2) ~= "=" then
            table.insert(out, string.char(math.floor(n / 256) % 256))
        end
        if string.sub(data, i + 3, i + 3) ~= "=" then
            table.insert(out, string.char(n % 256))
        end
    end
    return table.concat(out)
end

----------------------------------------------------------------------
-- Simple serializer (Lua table <-> string)
----------------------------------------------------------------------
local function serializeValue(val, depth)
    depth = depth or 0
    if depth > 50 then return "nil" end
    local t = type(val)
    if t == "string" then
        return string.format("%q", val)
    elseif t == "number" then
        return tostring(val)
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "table" then
        local parts = {}
        -- array part
        local maxn = 0
        for k in pairs(val) do
            if type(k) == "number" and k == math.floor(k) and k > 0 then
                if k > maxn then maxn = k end
            end
        end
        local arrayDone = {}
        for i = 1, maxn do
            table.insert(parts, serializeValue(val[i], depth + 1))
            arrayDone[i] = true
        end
        -- hash part
        for k, v in pairs(val) do
            if not arrayDone[k] then
                local keyStr
                if type(k) == "string" then
                    keyStr = "[" .. string.format("%q", k) .. "]"
                elseif type(k) == "number" then
                    keyStr = "[" .. tostring(k) .. "]"
                else
                    keyStr = "[" .. string.format("%q", tostring(k)) .. "]"
                end
                table.insert(parts, keyStr .. "=" .. serializeValue(v, depth + 1))
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "nil"
end

local function deserialize(str)
    -- Safe: we only load tables of primitives
    local func, err = loadstring("return " .. str)
    if not func then return nil, err end
    setfenv(func, {})
    local ok, result = pcall(func)
    if not ok then return nil, result end
    return result
end

----------------------------------------------------------------------
-- Starter Profiles helper
--
-- Imports a single starter profile by name. The data lives in
-- DefaultProfileData.lua as SRIL.STARTER_PROFILES.
--
-- Returns: true, finalName  on success
--          false, errorMsg  on failure
----------------------------------------------------------------------
function SRIL:ImportStarterProfile(starterName)
    if not SRIL.STARTER_PROFILES then
        return false, "No starter profiles available."
    end

    -- Find the matching starter profile entry
    local entry
    for _, info in ipairs(SRIL.STARTER_PROFILES) do
        if info.name == starterName then
            entry = info
            break
        end
    end

    if not entry then
        return false, "Starter profile not found: " .. tostring(starterName)
    end

    -- Decode + deserialize
    local decoded = base64Decode(entry.data)
    if not decoded or decoded == "" then
        return false, "Failed to decode starter profile data."
    end

    local data, err = deserialize(decoded)
    if not data or type(data) ~= "table" or not data.entries then
        return false, "Invalid starter profile data: " .. (err or "unknown error")
    end

    -- Pick a unique name (so re-importing doesn't clobber user edits)
    local name = entry.name
    local baseName = name
    local counter = 1
    while self.db.profiles[name] do
        counter = counter + 1
        name = baseName .. " (" .. counter .. ")"
    end

    self.db.profiles[name] = {
        entries = data.entries,
        col1Rows = data.col1Rows,
        col2Rows = data.col2Rows,
    }

    return true, name
end

-- Returns the list of starter profiles available for import
function SRIL:GetStarterProfiles()
    return SRIL.STARTER_PROFILES or {}
end


----------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Init saved variables
        if not SillyRaidItemListsDB then
            SillyRaidItemListsDB = DeepCopy(DEFAULT_DB)
        end
        local db = SillyRaidItemListsDB
        -- Ensure structure
        if not db.minimap then db.minimap = DeepCopy(DEFAULT_DB.minimap) end
        if not db.profiles then db.profiles = DeepCopy(DEFAULT_DB.profiles) end
        if not db.activeProfile then db.activeProfile = "Default" end
        if not db.profiles[db.activeProfile] then
            db.profiles[db.activeProfile] = { entries = {} }
        end

        SRIL.db = db

        -- Register minimap button
        SRIL:RegisterMinimapButton()

        -- Initial bag scan
        C_Timer.After(1, function() SRIL:ScanBags() end)

        print("|cff00ccffSilly Raid Item Lists|r v" .. SRIL.version .. " loaded. Type |cff00ff00/sril|r to toggle.")

    elseif event == "BAG_UPDATE" then
        if SRIL.db then
            -- Throttle: BAG_UPDATE can fire many times per frame (looting, mail, etc.)
            -- Batch into a single scan after a short delay
            if not SRIL._bagUpdatePending then
                SRIL._bagUpdatePending = true
                C_Timer.After(0.2, function()
                    SRIL._bagUpdatePending = false
                    SRIL:ScanBags()
                    if SRIL.RefreshMainList then SRIL:RefreshMainList() end
                end)
            end
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, function()
            if SRIL.db then
                SRIL:ScanBags()
                if SRIL.RefreshMainList then SRIL:RefreshMainList() end
            end
        end)
    end
end)

----------------------------------------------------------------------
-- Slash command
----------------------------------------------------------------------
SLASH_SRIL1 = "/sril"
SLASH_SRIL2 = "/sillyraiditems"
SLASH_SRIL3 = "/list"
SlashCmdList["SRIL"] = function(msg)
    SRIL:ToggleMainWindow()
end

----------------------------------------------------------------------
-- Minimap Button
----------------------------------------------------------------------
function SRIL:RegisterMinimapButton()
    local ldb = LibStub("LibDataBroker-1.1")
    local icon = LibStub("LibDBIcon-1.0")

    local dataObj = ldb:NewDataObject("SillyRaidItemLists", {
        type = "launcher",
        text = "Silly Raid Item Lists",
        icon = 134877, -- INV_Misc_QuestionMark / a potion icon
        OnClick = function(self2, button)
            if button == "LeftButton" then
                SRIL:ToggleMainWindow()
            elseif button == "RightButton" then
                SRIL:ToggleMainWindow()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cff00ccffSilly Raid Item Lists|r")
            tooltip:AddLine("Left-click to toggle window", 1, 1, 1)
        end,
    })

    icon:Register("SillyRaidItemLists", dataObj, self.db.minimap)
end

----------------------------------------------------------------------
-- Bag Scanning
----------------------------------------------------------------------
SRIL.bagCounts = {} -- [itemID] = count
SRIL.bagCharges = {} -- [itemID] = total charges across all stacks (only for charged items)

-- Hidden tooltip used to scan for charge text
local SRIL_ChargeTooltip = CreateFrame("GameTooltip", "SRIL_ChargeTooltip", UIParent, "GameTooltipTemplate")
SRIL_ChargeTooltip:SetOwner(UIParent, "ANCHOR_NONE")

-- Returns the charge count from an item in a bag slot, or nil if it has no charges.
-- Reads the item tooltip looking for a line like "5 Charges" or "1 Charge".
local function ScanSlotForCharges(bag, slot)
    SRIL_ChargeTooltip:ClearLines()
    SRIL_ChargeTooltip:SetBagItem(bag, slot)
    for i = 1, SRIL_ChargeTooltip:NumLines() do
        local line = _G["SRIL_ChargeTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                -- Match "5 Charges" or "1 Charge" at start of line
                local n = text:match("^(%d+) Charges?$")
                if n then
                    return tonumber(n)
                end
            end
        end
    end
    return nil
end

function SRIL:ScanBags()
    wipe(self.bagCounts)
    wipe(self.bagCharges)
    for bag = 0, 4 do
        local numSlots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info
            if C_Container and C_Container.GetContainerItemInfo then
                info = C_Container.GetContainerItemInfo(bag, slot)
            end
            local foundItemID, foundCount
            if info then
                foundItemID = info.itemID
                foundCount = info.stackCount or 1
            else
                -- Fallback for older API
                local texture, itemCount, locked, quality, readable, lootable, link, isFiltered, noValue, itemID2
                if GetContainerItemInfo then
                    texture, itemCount, locked, quality, readable, lootable, link, isFiltered, noValue, itemID2 = GetContainerItemInfo(bag, slot)
                end
                foundItemID = itemID2
                foundCount = itemCount or 1
            end
            if foundItemID then
                self.bagCounts[foundItemID] = (self.bagCounts[foundItemID] or 0) + foundCount
                -- Check for charges (sum across stacks if a player carries more than one)
                local charges = ScanSlotForCharges(bag, slot)
                if charges then
                    self.bagCharges[foundItemID] = (self.bagCharges[foundItemID] or 0) + charges
                end
            end
        end
    end
end

function SRIL:GetItemCount(itemID)
    return self.bagCounts[itemID] or 0
end

function SRIL:GetItemCharges(itemID)
    return self.bagCharges[itemID] or 0
end

----------------------------------------------------------------------
-- Profile API
----------------------------------------------------------------------
function SRIL:GetActiveProfile()
    return self.db.activeProfile
end

function SRIL:GetProfileData()
    return self.db.profiles[self.db.activeProfile]
end

function SRIL:GetProfileEntries()
    local p = self:GetProfileData()
    return p and p.entries or {}
end

function SRIL:SetActiveProfile(name)
    if self.db.profiles[name] then
        self.db.activeProfile = name
    end
end

function SRIL:CreateProfile(name)
    if not self.db.profiles[name] then
        self.db.profiles[name] = { entries = {} }
    end
end

function SRIL:DeleteProfile(name)
    if name == "Default" then return end -- can't delete default
    self.db.profiles[name] = nil
    if self.db.activeProfile == name then
        self.db.activeProfile = "Default"
        if not self.db.profiles["Default"] then
            self.db.profiles["Default"] = { entries = {} }
        end
    end
end

function SRIL:RenameProfile(oldName, newName)
    if oldName == newName then return end
    if self.db.profiles[newName] then return end
    self.db.profiles[newName] = self.db.profiles[oldName]
    self.db.profiles[oldName] = nil
    if self.db.activeProfile == oldName then
        self.db.activeProfile = newName
    end
end

function SRIL:DuplicateProfile(srcName, newName)
    if not self.db.profiles[srcName] then return end
    if self.db.profiles[newName] then return end
    self.db.profiles[newName] = DeepCopy(self.db.profiles[srcName])
end

function SRIL:GetProfileNames()
    local names = {}
    for k in pairs(self.db.profiles) do
        table.insert(names, k)
    end
    table.sort(names)
    return names
end

----------------------------------------------------------------------
-- Entry API
----------------------------------------------------------------------
-- Entry types:
-- {type="header", label="Section Name"}
-- {type="item", itemID=12345, iconID=123456, label="Item Name", minCount=5, altItems={{itemID=X, iconID=Y},...} }

function SRIL:AddEntry(entry)
    local entries = self:GetProfileEntries()
    table.insert(entries, entry)
end

function SRIL:RemoveEntry(index)
    local entries = self:GetProfileEntries()
    table.remove(entries, index)
end

function SRIL:MoveEntry(fromIndex, toIndex)
    local entries = self:GetProfileEntries()
    if fromIndex < 1 or fromIndex > #entries then return end
    if toIndex < 1 or toIndex > #entries then return end
    local entry = table.remove(entries, fromIndex)
    table.insert(entries, toIndex, entry)
end

function SRIL:UpdateEntry(index, newData)
    local entries = self:GetProfileEntries()
    if entries[index] then
        for k, v in pairs(newData) do
            entries[index][k] = v
        end
    end
end

----------------------------------------------------------------------
-- Check if an item entry is satisfied (enough in bags)
----------------------------------------------------------------------
function SRIL:IsEntrySatisfied(entry)
    if entry.type ~= "item" then return true end
    local needed = entry.minCount or 1
    -- Check primary item
    local count = self:GetItemCount(entry.itemID)
    if count >= needed then return true, count end
    -- Check alternatives
    if entry.altItems then
        for _, alt in ipairs(entry.altItems) do
            local altCount = self:GetItemCount(alt.itemID)
            if altCount >= (alt.minCount or needed) then
                return true, altCount
            end
        end
    end
    return false, count
end

-- For alt-linked items: returns true if ANY item in the alt group meets its threshold
function SRIL:GetEntryStatus(entry)
    if entry.type ~= "item" then return nil end
    local needed = entry.minCount or 1

    -- Pick the right counter: charges (when tracksCharges) or item count
    local getCount
    if entry.tracksCharges then
        getCount = function(id) return self:GetItemCharges(id) end
    else
        getCount = function(id) return self:GetItemCount(id) end
    end

    local primaryCount = getCount(entry.itemID)
    local primarySatisfied = primaryCount >= needed
    local satisfied = primarySatisfied
    local satisfiedByAlt = false
    local totalRelevant = primaryCount

    if entry.altItems and #entry.altItems > 0 then
        for _, alt in ipairs(entry.altItems) do
            local altCount = getCount(alt.itemID)
            if altCount >= (alt.minCount or needed) then
                satisfied = true
                if not primarySatisfied then
                    satisfiedByAlt = true
                end
            end
            totalRelevant = totalRelevant + altCount
        end
    end

    return satisfied, primaryCount, totalRelevant, satisfiedByAlt
end

----------------------------------------------------------------------
-- Import / Export
----------------------------------------------------------------------
function SRIL:ExportProfile(profileName)
    local profile = self.db.profiles[profileName]
    if not profile then return nil end
    local exportData = {
        name = profileName,
        entries = DeepCopy(profile.entries),
        col1Rows = profile.col1Rows,
        col2Rows = profile.col2Rows,
        version = self.version,
    }
    local serialized = serializeValue(exportData)
    return base64Encode(serialized)
end

function SRIL:ImportProfile(encodedStr, overrideName)
    local decoded = base64Decode(encodedStr)
    if not decoded or decoded == "" then return false, "Failed to decode data." end
    local data, err = deserialize(decoded)
    if not data then return false, "Failed to deserialize: " .. (err or "unknown error") end
    if type(data) ~= "table" or not data.entries then return false, "Invalid profile data." end

    local name = overrideName or data.name or "Imported"
    -- Make unique name if needed
    local baseName = name
    local counter = 1
    while self.db.profiles[name] do
        counter = counter + 1
        name = baseName .. " (" .. counter .. ")"
    end

    self.db.profiles[name] = {
        entries = data.entries,
        col1Rows = data.col1Rows,
        col2Rows = data.col2Rows,
    }
    return true, name
end
