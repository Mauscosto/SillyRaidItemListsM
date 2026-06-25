-- LibDBIcon-1.0
-- Public domain. Originally by Rabbit.

local DBICON10 = "LibDBIcon-1.0"
local DBICON10_MINOR = 47
if not LibStub then return end
local lib = LibStub:NewLibrary(DBICON10, DBICON10_MINOR)
if not lib then return end

lib.objects = lib.objects or {}
lib.callbackRegistered = lib.callbackRegistered or false
lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.radius = lib.radius or 80
local ldb = LibStub("LibDataBroker-1.1")

local minimapShapes = {
    ["ROUND"] = {true, true, true, true},
    ["SQUARE"] = {false, false, false, false},
    ["CORNER-TOPLEFT"] = {false, false, false, true},
    ["CORNER-TOPRIGHT"] = {false, false, true, false},
    ["CORNER-BOTTOMLEFT"] = {false, true, false, false},
    ["CORNER-BOTTOMRIGHT"] = {true, false, false, false},
    ["SIDE-LEFT"] = {false, true, false, true},
    ["SIDE-RIGHT"] = {true, false, true, false},
    ["SIDE-TOP"] = {false, false, true, true},
    ["SIDE-BOTTOM"] = {true, true, false, false},
    ["TRICORNER-TOPLEFT"] = {false, true, true, true},
    ["TRICORNER-TOPRIGHT"] = {true, false, true, true},
    ["TRICORNER-BOTTOMLEFT"] = {true, true, false, true},
    ["TRICORNER-BOTTOMRIGHT"] = {true, true, true, false},
}

local function getMinimapShape()
    return GetMinimapShape and GetMinimapShape() or "ROUND"
end

local function updatePosition(button, db)
    local angle = math.rad(db and db.minimapPos or 225)
    local x, y, q = math.cos(angle), math.sin(angle), 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end
    local minimapShape = minimapShapes[getMinimapShape()]
    if minimapShape and minimapShape[q] then
        x = x * 80
        y = y * 80
    else
        local round = math.sqrt(2) / 2
        x = math.max(-round, math.min(x, round))
        y = math.max(-round, math.min(y, round))
        x = x * 80 * 2 / math.sqrt(2)
        y = y * 80 * 2 / math.sqrt(2)
    end
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function onClick(self, b)
    local obj = self.dataObject
    if obj.OnClick then
        obj.OnClick(self, b)
    end
end

local function onMouseDown(self) self.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95) end
local function onMouseUp(self) self.icon:SetTexCoord(0, 1, 0, 1) end
local function onEnter(self)
    if self.dataObject.OnTooltipShow then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        self.dataObject.OnTooltipShow(GameTooltip)
        GameTooltip:Show()
    end
end
local function onLeave(self) GameTooltip:Hide() end

local function onDragStart(self)
    self.isMouseDown = true
    self.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    self:SetScript("OnUpdate", function(self2)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local angle = math.deg(math.atan2(py - my, px - mx)) % 360
        self2.db.minimapPos = angle
        updatePosition(self2, self2.db)
    end)
end

local function onDragStop(self)
    self.isMouseDown = false
    self.icon:SetTexCoord(0, 1, 0, 1)
    self:SetScript("OnUpdate", nil)
end

local function createButton(name, object, db)
    local button = CreateFrame("Button", "LibDBIcon10_"..name, Minimap)
    button.dataObject = object
    button.db = db
    button:SetFrameStrata("MEDIUM")
    button:SetSize(31, 31)
    button:SetFrameLevel(8)
    button:RegisterForClicks("anyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(136477) -- Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture(136430) -- Interface\\Minimap\\MiniMap-TrackingBorder
    overlay:SetPoint("TOPLEFT")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture(136467) -- Interface\\Minimap\\UI-Minimap-Background
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(object.icon)
    icon:SetPoint("TOPLEFT", 7, -6)
    button.icon = icon

    button:SetScript("OnClick", onClick)
    button:SetScript("OnMouseDown", onMouseDown)
    button:SetScript("OnMouseUp", onMouseUp)
    button:SetScript("OnEnter", onEnter)
    button:SetScript("OnLeave", onLeave)
    button:SetScript("OnDragStart", onDragStart)
    button:SetScript("OnDragStop", onDragStop)
    button.SetIconTexture = function(self2, tex) self2.icon:SetTexture(tex) end

    lib.objects[name] = button
    if db and db.hide then button:Hide() else button:Show() end
    updatePosition(button, db)
    return button
end

function lib:Register(name, object, db)
    if lib.objects[name] then return end
    db.minimapPos = db.minimapPos or 225
    createButton(name, object, db)
end

function lib:Show(name) if lib.objects[name] then lib.objects[name]:Show() end end
function lib:Hide(name) if lib.objects[name] then lib.objects[name]:Hide() end end
function lib:IsRegistered(name) return lib.objects[name] and true or false end
function lib:Refresh(name, db)
    local button = lib.objects[name]
    if button then
        if db then button.db = db end
        updatePosition(button, button.db)
        if button.db and button.db.hide then button:Hide() else button:Show() end
    end
end
function lib:GetMinimapButton(name) return lib.objects[name] end
