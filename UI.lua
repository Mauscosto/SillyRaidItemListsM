----------------------------------------------------------------------
-- Silly Raid Item Lists - UI.lua
-- All UI frames: main checklist, entry editor, profile manager, import/export
----------------------------------------------------------------------

local addonName, SRIL = ...

----------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------
local COLUMN_COUNT = 3
local ROW_HEIGHT = 22
local ICON_SIZE = 20
local HEADER_COLOR = { r = 1, g = 1, b = 1 }  -- white
local GREEN = { r = 0.2, g = 1, b = 0.2 }
local RED = { r = 1, g = 0.3, b = 0.3 }
local WHITE = { r = 1, g = 1, b = 1 }
local MAIN_WIDTH = 750
local MAIN_HEIGHT = 620
local ENTRIES_PER_COL = 30
local HIDDEN_ALPHA = 0.4  -- dimmed opacity for hidden entries when shown

----------------------------------------------------------------------
-- Utility: Create a styled button
----------------------------------------------------------------------
local function CreateStyledButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 80, height or 22)
    btn:SetText(text)
    return btn
end

----------------------------------------------------------------------
-- Utility: Create a simple EditBox
----------------------------------------------------------------------
local function CreateEditBox(parent, width, height, numeric)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(width or 120, height or 20)
    eb:SetAutoFocus(false)
    if numeric then eb:SetNumeric(true) end
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
end

----------------------------------------------------------------------
-- MAIN WINDOW
----------------------------------------------------------------------
local mainFrame

local function CreateMainFrame()
    if mainFrame then return mainFrame end

    mainFrame = CreateFrame("Frame", "SRILMainFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(MAIN_WIDTH, MAIN_HEIGHT)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:SetFrameLevel(10)
    mainFrame.TitleText:SetText("Silly Raid Item Lists")
    mainFrame:Hide()

    -- Profile selector bar at top
    local profileBar = CreateFrame("Frame", nil, mainFrame)
    profileBar:SetPoint("TOPLEFT", mainFrame.InsetBg or mainFrame, "TOPLEFT", 8, -4)
    profileBar:SetPoint("TOPRIGHT", mainFrame.InsetBg or mainFrame, "TOPRIGHT", -8, -4)
    profileBar:SetHeight(28)

    local profileLabel = profileBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profileLabel:SetPoint("LEFT", 4, 0)
    profileLabel:SetText("Profile:")

    local profileDropdown = CreateFrame("Frame", "SRILProfileDropdown", profileBar, "UIDropDownMenuTemplate")
    profileDropdown:SetPoint("LEFT", profileLabel, "RIGHT", -8, -2)
    UIDropDownMenu_SetWidth(profileDropdown, 150)

    local function ProfileDropdown_Init(self2, level)
        local names = SRIL:GetProfileNames()
        for _, name in ipairs(names) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.func = function()
                SRIL:SetActiveProfile(name)
                UIDropDownMenu_SetText(profileDropdown, name)
                SRIL:ScanBags()
                SRIL:RefreshMainList()
            end
            info.checked = (name == SRIL:GetActiveProfile())
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(profileDropdown, ProfileDropdown_Init)

    mainFrame.profileDropdown = profileDropdown

    -- Buttons along top bar
    local btnManageProfiles = CreateStyledButton(profileBar, "Profiles", 70, 22)
    btnManageProfiles:SetPoint("LEFT", profileDropdown, "RIGHT", 0, 2)
    btnManageProfiles:SetScript("OnClick", function() SRIL:ShowProfileManager() end)

    local btnAddItem = CreateStyledButton(profileBar, "+ Item", 60, 22)
    btnAddItem:SetPoint("LEFT", btnManageProfiles, "RIGHT", 4, 0)
    btnAddItem:SetScript("OnClick", function() SRIL:ShowEntryEditor(nil, nil) end)

    local btnAddHeader = CreateStyledButton(profileBar, "+ Header", 70, 22)
    btnAddHeader:SetPoint("LEFT", btnAddItem, "RIGHT", 4, 0)
    btnAddHeader:SetScript("OnClick", function() SRIL:ShowHeaderEditor(nil, nil) end)

    local btnImportExport = CreateStyledButton(profileBar, "Import/Export", 90, 22)
    btnImportExport:SetPoint("LEFT", btnAddHeader, "RIGHT", 4, 0)
    btnImportExport:SetScript("OnClick", function() SRIL:ShowImportExport() end)

    -- Show Hidden toggle
    mainFrame.showHidden = false
    local btnShowHidden = CreateStyledButton(profileBar, "Show Hidden", 90, 22)
    btnShowHidden:SetPoint("LEFT", btnImportExport, "RIGHT", 4, 0)
    btnShowHidden:SetScript("OnClick", function()
        mainFrame.showHidden = not mainFrame.showHidden
        if mainFrame.showHidden then
            btnShowHidden:SetText("Hide Hidden")
        else
            btnShowHidden:SetText("Show Hidden")
        end
        SRIL:RefreshMainList()
    end)
    mainFrame.btnShowHidden = btnShowHidden

    -- Second bar: column layout controls
    local colBar = CreateFrame("Frame", nil, mainFrame)
    colBar:SetPoint("TOPLEFT", profileBar, "BOTTOMLEFT", 0, -2)
    colBar:SetPoint("TOPRIGHT", profileBar, "BOTTOMRIGHT", 0, -2)
    colBar:SetHeight(24)

    local colLabel = colBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colLabel:SetPoint("LEFT", 4, 0)
    colLabel:SetText("Rows per column:")
    colLabel:SetTextColor(0.7, 0.7, 0.7)

    local lblCol1 = colBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblCol1:SetPoint("LEFT", colLabel, "RIGHT", 8, 0)
    lblCol1:SetText("Col1:")
    lblCol1:SetTextColor(0.7, 0.7, 0.7)

    local ebCol1 = CreateEditBox(colBar, 35, 18, true)
    ebCol1:SetPoint("LEFT", lblCol1, "RIGHT", 2, 0)
    ebCol1:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local profile = SRIL:GetProfileData()
        profile.col1Rows = tonumber(self:GetText()) or nil
        SRIL:RefreshMainList()
    end)
    mainFrame.ebCol1 = ebCol1

    local lblCol2 = colBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblCol2:SetPoint("LEFT", ebCol1, "RIGHT", 8, 0)
    lblCol2:SetText("Col2:")
    lblCol2:SetTextColor(0.7, 0.7, 0.7)

    local ebCol2 = CreateEditBox(colBar, 35, 18, true)
    ebCol2:SetPoint("LEFT", lblCol2, "RIGHT", 2, 0)
    ebCol2:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local profile = SRIL:GetProfileData()
        profile.col2Rows = tonumber(self:GetText()) or nil
        SRIL:RefreshMainList()
    end)
    mainFrame.ebCol2 = ebCol2

    local colHint = colBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colHint:SetPoint("LEFT", ebCol2, "RIGHT", 8, 0)
    colHint:SetText("|cff666666(Col3 = overflow, leave blank for auto)|r")

    -- Content area - scrollable
    local scrollFrame = CreateFrame("ScrollFrame", "SRILScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", colBar, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", "SRILContent", scrollFrame)
    content:SetSize(MAIN_WIDTH - 40, 800)
    scrollFrame:SetScrollChild(content)

    mainFrame.content = content
    mainFrame.scrollFrame = scrollFrame

    -- Row frames pool
    mainFrame.rowFrames = {}

    return mainFrame
end

----------------------------------------------------------------------
-- Create a row frame for an entry
----------------------------------------------------------------------
local function GetOrCreateRowFrame(parent, index)
    if parent.rowFrames and parent.rowFrames[index] then
        parent.rowFrames[index]:Show()
        return parent.rowFrames[index]
    end

    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", 2, 0)
    row.icon = icon

    -- Label
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -60, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label

    -- Count text
    local countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    countText:SetJustifyH("RIGHT")
    countText:SetWidth(55)
    row.countText = countText

    -- Highlight on hover
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)

    -- Click handler: right-click = context menu, left-click = edit
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            SRIL:ShowRowContextMenu(self, self.entryIndex)
        elseif button == "LeftButton" then
            local entry = self.entryData
            if entry then
                if entry.type == "header" then
                    SRIL:ShowHeaderEditor(self.entryIndex, entry)
                else
                    SRIL:ShowEntryEditor(self.entryIndex, entry)
                end
            end
        end
    end)

    -- Tooltip on hover for items
    row:SetScript("OnEnter", function(self)
        if self.entryData and self.entryData.type == "item" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.entryData.itemID)
            -- Show alt items info
            if self.entryData.altItems and #self.entryData.altItems > 0 then
                local tracksCharges = self.entryData.tracksCharges
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(tracksCharges and "Alternatives (charges):" or "Alternatives:", 1, 0.82, 0)
                for _, alt in ipairs(self.entryData.altItems) do
                    local altName = GetItemInfo(alt.itemID) or ("Item " .. alt.itemID)
                    local altCount = tracksCharges and SRIL:GetItemCharges(alt.itemID) or SRIL:GetItemCount(alt.itemID)
                    local altNeeded = alt.minCount or self.entryData.minCount or 1
                    local altColor = altCount >= altNeeded and GREEN or RED
                    GameTooltip:AddDoubleLine(
                        altName,
                        altCount .. "/" .. altNeeded,
                        1, 1, 1,
                        altColor.r, altColor.g, altColor.b
                    )
                end
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if not parent.rowFrames then parent.rowFrames = {} end
    parent.rowFrames[index] = row
    return row
end

----------------------------------------------------------------------
-- Refresh the main checklist
----------------------------------------------------------------------
function SRIL:RefreshMainList()
    if not mainFrame or not mainFrame:IsShown() then return end

    local content = mainFrame.content
    local entries = self:GetProfileEntries()

    -- Update profile dropdown text
    UIDropDownMenu_SetText(mainFrame.profileDropdown, self:GetActiveProfile())

    -- Hide all existing rows
    if content.rowFrames then
        for _, row in pairs(content.rowFrames) do
            row:Hide()
        end
    end

    if #entries == 0 then
        -- Show helper text
        if not content.emptyText then
            content.emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            content.emptyText:SetPoint("CENTER", content, "CENTER", 0, 0)
            content.emptyText:SetText("No entries yet!\nClick '+ Item' or '+ Header' to get started.")
            content.emptyText:SetTextColor(0.6, 0.6, 0.6)
        end
        content.emptyText:Show()
        return
    end

    if content.emptyText then content.emptyText:Hide() end

    -- Filter entries based on showHidden toggle
    local showHidden = mainFrame.showHidden
    local visibleEntries = {}
    for i, entry in ipairs(entries) do
        if not entry.hidden or showHidden then
            table.insert(visibleEntries, { index = i, entry = entry })
        end
    end

    if #visibleEntries == 0 then
        if not content.emptyText then
            content.emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            content.emptyText:SetPoint("CENTER", content, "CENTER", 0, 0)
            content.emptyText:SetTextColor(0.6, 0.6, 0.6)
        end
        content.emptyText:SetText("All entries are hidden.\nClick 'Show Hidden' to see them.")
        content.emptyText:Show()
        return
    end

    -- Layout: multi-column with manual breakpoints
    local profile = self:GetProfileData()
    local col1Rows = profile.col1Rows
    local col2Rows = profile.col2Rows

    -- Update edit boxes to reflect current profile values
    mainFrame.ebCol1:SetText(col1Rows and tostring(col1Rows) or "")
    mainFrame.ebCol2:SetText(col2Rows and tostring(col2Rows) or "")

    local colWidth = math.floor((MAIN_WIDTH - 50) / COLUMN_COUNT)
    local col = 0
    local rowInCol = 0

    -- Determine max rows per column for content height calculation
    local colCounts = { 0, 0, 0 }

    -- Figure out which column each entry goes into
    local function getColLimit(currentCol)
        if currentCol == 0 and col1Rows then return col1Rows end
        if currentCol == 1 and col2Rows then return col2Rows end
        return nil -- no limit on col 3 (overflow)
    end

    for vi, vEntry in ipairs(visibleEntries) do
        local i = vEntry.index
        local entry = vEntry.entry
        local row = GetOrCreateRowFrame(content, vi)
        row.entryIndex = i
        row.entryData = entry
        row:SetWidth(colWidth - 4)

        local xOffset = col * colWidth + 4
        local yOffset = -(rowInCol * ROW_HEIGHT) - 4

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", xOffset, yOffset)

        local isHidden = entry.hidden

        if entry.type == "header" then
            row.icon:Hide()
            row.label:SetPoint("LEFT", row, "LEFT", 4, 0)
            local headerText = entry.label or "Header"
            if isHidden then headerText = "|cff666666(H)|r " .. headerText end
            row.label:SetText(headerText)
            row.label:SetFontObject(GameFontNormal)
            if isHidden then
                row.label:SetTextColor(HEADER_COLOR.r * HIDDEN_ALPHA, HEADER_COLOR.g * HIDDEN_ALPHA, HEADER_COLOR.b * HIDDEN_ALPHA)
            else
                row.label:SetTextColor(HEADER_COLOR.r, HEADER_COLOR.g, HEADER_COLOR.b)
            end
            row.countText:SetText("")
        elseif entry.type == "item" then
            row.icon:Show()
            row.icon:SetTexture(entry.iconID or 134400)
            row.label:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
            row.label:SetFontObject(GameFontNormalSmall)

            local displayName = entry.label or ("Item " .. entry.itemID)
            local needed = entry.minCount or 1
            local satisfied, primaryCount, totalCount, satisfiedByAlt = self:GetEntryStatus(entry)

            if isHidden then displayName = "|cff666666(H)|r " .. displayName end
            row.label:SetText(displayName)

            local countStr = primaryCount .. "/" .. needed
            if satisfied and satisfiedByAlt then
                countStr = countStr .. "*"
            end
            row.countText:SetText(countStr)

            if isHidden then
                row.label:SetTextColor(0.4, 0.4, 0.4)
                row.countText:SetTextColor(0.4, 0.4, 0.4)
                row.icon:SetAlpha(HIDDEN_ALPHA)
            elseif satisfied then
                row.label:SetTextColor(GREEN.r, GREEN.g, GREEN.b)
                row.countText:SetTextColor(GREEN.r, GREEN.g, GREEN.b)
                row.icon:SetAlpha(1)
            else
                row.label:SetTextColor(RED.r, RED.g, RED.b)
                row.countText:SetTextColor(RED.r, RED.g, RED.b)
                row.icon:SetAlpha(1)
            end
        end

        rowInCol = rowInCol + 1
        if col < 3 then colCounts[col + 1] = rowInCol end

        local limit = getColLimit(col)
        if limit and rowInCol >= limit and col < 2 then
            rowInCol = 0
            col = col + 1
        end
    end
    -- Final column count
    if col < 3 then colCounts[col + 1] = rowInCol end

    -- Update content height based on tallest column
    local maxRows = math.max(colCounts[1] or 0, colCounts[2] or 0, colCounts[3] or 0)
    local totalHeight = maxRows * ROW_HEIGHT + 20
    content:SetHeight(math.max(totalHeight, 200))
end

----------------------------------------------------------------------
-- Row context menu (right-click)
----------------------------------------------------------------------
local contextMenu = CreateFrame("Frame", "SRILContextMenu", UIParent, "UIDropDownMenuTemplate")
contextMenu.displayMode = "MENU"

function SRIL:ShowRowContextMenu(rowFrame, entryIndex)
    local entries = self:GetProfileEntries()
    local entry = entries[entryIndex]
    if not entry then return end

    -- Close any existing menu first
    CloseDropDownMenus()

    local menuList = {
        { text = "Edit", notCheckable = true, func = function()
            if entry.type == "header" then
                SRIL:ShowHeaderEditor(entryIndex, entry)
            else
                SRIL:ShowEntryEditor(entryIndex, entry)
            end
        end },
        { text = "Move Up", notCheckable = true, func = function()
            if entryIndex > 1 then
                SRIL:MoveEntry(entryIndex, entryIndex - 1)
                SRIL:RefreshMainList()
            end
        end },
        { text = "Move Down", notCheckable = true, func = function()
            if entryIndex < #entries then
                SRIL:MoveEntry(entryIndex, entryIndex + 1)
                SRIL:RefreshMainList()
            end
        end },
        { text = "Move to Top", notCheckable = true, func = function()
            if entryIndex > 1 then
                SRIL:MoveEntry(entryIndex, 1)
                SRIL:RefreshMainList()
            end
        end },
        { text = "Move to Bottom", notCheckable = true, func = function()
            if entryIndex < #entries then
                SRIL:MoveEntry(entryIndex, #entries)
                SRIL:RefreshMainList()
            end
        end },
        { text = " ", notCheckable = true, disabled = true },
        { text = "|cffff3333Delete|r", notCheckable = true, func = function()
            SRIL:RemoveEntry(entryIndex)
            SRIL:RefreshMainList()
        end },
        { text = "Cancel", notCheckable = true },
    }

    EasyMenu(menuList, contextMenu, "cursor", 0, 0, "MENU")
end

----------------------------------------------------------------------
-- ENTRY EDITOR (for items)
----------------------------------------------------------------------
local entryEditor

function SRIL:ShowEntryEditor(editIndex, existingEntry)
    if not entryEditor then
        entryEditor = CreateFrame("Frame", "SRILEntryEditor", UIParent, "BasicFrameTemplateWithInset")
        entryEditor:SetSize(420, 460)
        entryEditor:SetPoint("CENTER", 200, 0)
        entryEditor:SetMovable(true)
        entryEditor:EnableMouse(true)
        entryEditor:RegisterForDrag("LeftButton")
        entryEditor:SetScript("OnDragStart", entryEditor.StartMoving)
        entryEditor:SetScript("OnDragStop", entryEditor.StopMovingOrSizing)
        entryEditor:SetClampedToScreen(true)
        entryEditor:SetFrameStrata("FULLSCREEN_DIALOG")
        entryEditor:SetFrameLevel(100)

        local yPos = -35
        local leftMargin = 15

        -- Label
        local lblName = entryEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lblName:SetPoint("TOPLEFT", leftMargin, yPos)
        lblName:SetText("Display Name:")
        yPos = yPos - 20
        local ebName = CreateEditBox(entryEditor, 280, 20)
        ebName:SetPoint("TOPLEFT", leftMargin, yPos)
        entryEditor.ebName = ebName

        yPos = yPos - 30
        -- Item ID
        local lblItemID = entryEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lblItemID:SetPoint("TOPLEFT", leftMargin, yPos)
        lblItemID:SetText("Item ID (required):")
        yPos = yPos - 20
        local ebItemID = CreateEditBox(entryEditor, 120, 20, true)
        ebItemID:SetPoint("TOPLEFT", leftMargin, yPos)
        entryEditor.ebItemID = ebItemID

        -- Icon ID
        local lblIconID = entryEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lblIconID:SetPoint("TOPLEFT", 200, yPos + 20)
        lblIconID:SetText("Icon ID (required):")
        local ebIconID = CreateEditBox(entryEditor, 120, 20, true)
        ebIconID:SetPoint("TOPLEFT", 200, yPos)
        entryEditor.ebIconID = ebIconID

        -- Icon preview
        local iconPreview = entryEditor:CreateTexture(nil, "ARTWORK")
        iconPreview:SetSize(32, 32)
        iconPreview:SetPoint("LEFT", ebIconID, "RIGHT", 8, 0)
        iconPreview:SetTexture(134400)
        entryEditor.iconPreview = iconPreview

        -- Update preview when icon ID changes
        ebIconID:SetScript("OnTextChanged", function(self)
            local id = tonumber(self:GetText())
            if id and id > 0 then
                entryEditor.iconPreview:SetTexture(id)
            end
        end)

        yPos = yPos - 30
        -- Min Count
        local lblCount = entryEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lblCount:SetPoint("TOPLEFT", leftMargin, yPos)
        lblCount:SetText("Min Count (required):")
        yPos = yPos - 20
        local ebCount = CreateEditBox(entryEditor, 80, 20, true)
        ebCount:SetPoint("TOPLEFT", leftMargin, yPos)
        entryEditor.ebCount = ebCount

        yPos = yPos - 30
        -- Alt Items (multi-line text area)
        local lblAlts = entryEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lblAlts:SetPoint("TOPLEFT", leftMargin, yPos)
        lblAlts:SetText("Alternative Items (one per line: ItemID,MinCount):")
        yPos = yPos - 15

        local altScroll = CreateFrame("ScrollFrame", "SRILAltScroll", entryEditor, "UIPanelScrollFrameTemplate")
        altScroll:SetPoint("TOPLEFT", leftMargin, yPos)
        altScroll:SetSize(370, 80)

        local altBg = altScroll:CreateTexture(nil, "BACKGROUND")
        altBg:SetAllPoints()
        altBg:SetColorTexture(0, 0, 0, 0.3)

        local altEdit = CreateFrame("EditBox", nil, altScroll)
        altEdit:SetMultiLine(true)
        altEdit:SetAutoFocus(false)
        altEdit:SetFontObject(ChatFontNormal)
        altEdit:SetWidth(350)
        altEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        altScroll:SetScrollChild(altEdit)
        entryEditor.altEdit = altEdit

        yPos = yPos - 95

        -- Help text
        local helpText = entryEditor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        helpText:SetPoint("TOPLEFT", leftMargin, yPos)
        helpText:SetText("|cff888888Example alt line: 12345,5|r")
        helpText:SetTextColor(0.5, 0.5, 0.5)

        yPos = yPos - 25

        -- Save button
        local btnSave = CreateStyledButton(entryEditor, "Save", 100, 24)
        btnSave:SetPoint("TOPLEFT", leftMargin, yPos)
        entryEditor.btnSave = btnSave

        -- Cancel button
        local btnCancel = CreateStyledButton(entryEditor, "Cancel", 80, 24)
        btnCancel:SetPoint("LEFT", btnSave, "RIGHT", 8, 0)
        btnCancel:SetScript("OnClick", function() entryEditor:Hide() end)

        -- Hidden checkbox
        local cbHidden = CreateFrame("CheckButton", "SRILHiddenCheck", entryEditor, "UICheckButtonTemplate")
        cbHidden:SetSize(24, 24)
        cbHidden:SetPoint("LEFT", btnCancel, "RIGHT", 12, 0)
        cbHidden.text = cbHidden.text or _G["SRILHiddenCheckText"] or cbHidden:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cbHidden.text:SetText("Hidden")
        cbHidden.text:SetPoint("LEFT", cbHidden, "RIGHT", 2, 0)
        entryEditor.cbHidden = cbHidden

        -- Track Charges checkbox (for items like trinkets/wands that have charges)
        local cbCharges = CreateFrame("CheckButton", "SRILChargesCheck", entryEditor, "UICheckButtonTemplate")
        cbCharges:SetSize(24, 24)
        cbCharges:SetPoint("LEFT", cbHidden.text, "RIGHT", 12, 0)
        cbCharges.text = cbCharges.text or _G["SRILChargesCheckText"] or cbCharges:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cbCharges.text:SetText("Track Charges")
        cbCharges.text:SetPoint("LEFT", cbCharges, "RIGHT", 2, 0)
        cbCharges.tooltipText = "Count this item by its charges instead of by stack size. Use for trinkets, wands, or other charge-bearing items."
        entryEditor.cbCharges = cbCharges

        yPos = yPos - 35

        -- Separator line
        local sep = entryEditor:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", leftMargin, yPos)
        sep:SetPoint("TOPRIGHT", -leftMargin, yPos)
        sep:SetColorTexture(0.4, 0.4, 0.4, 0.6)
        entryEditor.sep = sep

        yPos = yPos - 10

        -- Move / Delete buttons (only visible when editing)
        local btnMoveTop = CreateStyledButton(entryEditor, "Move to Top", 90, 22)
        btnMoveTop:SetPoint("TOPLEFT", leftMargin, yPos)
        entryEditor.btnMoveTop = btnMoveTop

        local btnMoveUp = CreateStyledButton(entryEditor, "Move Up", 70, 22)
        btnMoveUp:SetPoint("LEFT", btnMoveTop, "RIGHT", 4, 0)
        entryEditor.btnMoveUp = btnMoveUp

        local btnMoveDown = CreateStyledButton(entryEditor, "Move Down", 80, 22)
        btnMoveDown:SetPoint("LEFT", btnMoveUp, "RIGHT", 4, 0)
        entryEditor.btnMoveDown = btnMoveDown

        local btnMoveBottom = CreateStyledButton(entryEditor, "Move to Bottom", 100, 22)
        btnMoveBottom:SetPoint("LEFT", btnMoveDown, "RIGHT", 4, 0)
        entryEditor.btnMoveBottom = btnMoveBottom

        yPos = yPos - 28

        local btnDelete = CreateStyledButton(entryEditor, "Delete Entry", 100, 22)
        btnDelete:SetPoint("TOPLEFT", leftMargin, yPos)
        entryEditor.btnDelete = btnDelete
    end

    -- Populate fields
    entryEditor.TitleText:SetText(editIndex and "Edit Item Entry" or "Add Item Entry")

    -- Show or hide move/delete controls based on whether we're editing
    local isEditing = (editIndex ~= nil)
    entryEditor.sep:SetShown(isEditing)
    entryEditor.btnMoveTop:SetShown(isEditing)
    entryEditor.btnMoveUp:SetShown(isEditing)
    entryEditor.btnMoveDown:SetShown(isEditing)
    entryEditor.btnMoveBottom:SetShown(isEditing)
    entryEditor.btnDelete:SetShown(isEditing)

    -- Resize frame based on mode
    entryEditor:SetHeight(isEditing and 460 or 380)

    if isEditing then
        -- Store editIndex in a mutable table so button handlers always see current value
        local pos = { idx = editIndex }
        entryEditor.currentPos = pos

        -- Position indicator label (create once, update each time)
        if not entryEditor.posLabel then
            local posLabel = entryEditor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            posLabel:SetPoint("LEFT", entryEditor.btnDelete, "RIGHT", 12, 0)
            entryEditor.posLabel = posLabel
        end

        local function updatePosLabel()
            local entries = SRIL:GetProfileEntries()
            entryEditor.posLabel:SetText("|cffaaaaaa(" .. pos.idx .. "/" .. #entries .. ")|r")
        end
        entryEditor.posLabel:Show()
        updatePosLabel()

        entryEditor.btnMoveTop:SetScript("OnClick", function()
            if pos.idx > 1 then
                SRIL:MoveEntry(pos.idx, 1)
                pos.idx = 1
                updatePosLabel()
                SRIL:RefreshMainList()
            end
        end)
        entryEditor.btnMoveUp:SetScript("OnClick", function()
            if pos.idx > 1 then
                SRIL:MoveEntry(pos.idx, pos.idx - 1)
                pos.idx = pos.idx - 1
                updatePosLabel()
                SRIL:RefreshMainList()
            end
        end)
        entryEditor.btnMoveDown:SetScript("OnClick", function()
            local entries = SRIL:GetProfileEntries()
            if pos.idx < #entries then
                SRIL:MoveEntry(pos.idx, pos.idx + 1)
                pos.idx = pos.idx + 1
                updatePosLabel()
                SRIL:RefreshMainList()
            end
        end)
        entryEditor.btnMoveBottom:SetScript("OnClick", function()
            local entries = SRIL:GetProfileEntries()
            if pos.idx < #entries then
                SRIL:MoveEntry(pos.idx, #entries)
                pos.idx = #entries
                updatePosLabel()
                SRIL:RefreshMainList()
            end
        end)
        entryEditor.btnDelete:SetScript("OnClick", function()
            SRIL:RemoveEntry(pos.idx)
            entryEditor:Hide()
            SRIL:RefreshMainList()
        end)
    else
        if entryEditor.posLabel then entryEditor.posLabel:Hide() end
    end

    if existingEntry then
        entryEditor.ebName:SetText(existingEntry.label or "")
        entryEditor.ebItemID:SetText(tostring(existingEntry.itemID or ""))
        entryEditor.ebIconID:SetText(tostring(existingEntry.iconID or ""))
        entryEditor.ebCount:SetText(tostring(existingEntry.minCount or ""))
        entryEditor.cbHidden:SetChecked(existingEntry.hidden or false)
        entryEditor.cbCharges:SetChecked(existingEntry.tracksCharges or false)
        -- Build alt items text
        local altLines = {}
        if existingEntry.altItems then
            for _, alt in ipairs(existingEntry.altItems) do
                table.insert(altLines, string.format("%d,%d", alt.itemID or 0, alt.minCount or 1))
            end
		else
			table.insert(altLines,"00000,0")
        end
        entryEditor.altEdit:SetText(table.concat(altLines, "\n"))
        local iconID = existingEntry.iconID
        if iconID then entryEditor.iconPreview:SetTexture(iconID) end
    else
        entryEditor.ebName:SetText("")
        entryEditor.ebItemID:SetText("")
        entryEditor.ebIconID:SetText("")
        entryEditor.ebCount:SetText("")
        entryEditor.altEdit:SetText("_")
        entryEditor.iconPreview:SetTexture(134400)
        entryEditor.cbHidden:SetChecked(false)
        entryEditor.cbCharges:SetChecked(false)
    end

    -- Save handler
    entryEditor.btnSave:SetScript("OnClick", function()
        local name = entryEditor.ebName:GetText()
        local itemID = tonumber(entryEditor.ebItemID:GetText())
        local iconID = tonumber(entryEditor.ebIconID:GetText())
        local minCount = tonumber(entryEditor.ebCount:GetText())

        -- Validate required fields
        if not itemID or itemID <= 0 then
            print("|cffff0000[SRIL] Item ID is required and must be a positive number.|r")
            return
        end
        if not iconID or iconID <= 0 then
            print("|cffff0000[SRIL] Icon ID is required and must be a positive number.|r")
            return
        end
        if not minCount or minCount < 1 then
            print("|cffff0000[SRIL] Min Count is required and must be at least 1.|r")
            return
        end

        -- If no name, try to get it from game cache
        if (not name or name == "") then
            name = GetItemInfo(itemID) or ("Item " .. itemID)
        end

        -- Parse alt items
        local altItems = {}
        local altText = entryEditor.altEdit:GetText()
        if altText and altText ~= "" then
            for line in altText:gmatch("[^\r\n]+") do
                line = line:match("^%s*(.-)%s*$") -- trim
                if line ~= "" then
                    local parts = {}
                    for part in line:gmatch("[^,]+") do
                        table.insert(parts, tonumber(part:match("^%s*(.-)%s*$")))
                    end
                    if parts[1] and parts[1] > 0 then
                        table.insert(altItems, {
                            itemID = parts[1],
                            minCount = parts[2] or minCount,
                        })
                    end
                end
            end
        end

        local entryData = {
            type = "item",
            label = name,
            itemID = itemID,
            iconID = iconID,
            minCount = minCount,
            altItems = #altItems > 0 and altItems or nil,
            hidden = entryEditor.cbHidden:GetChecked() or false,
            tracksCharges = entryEditor.cbCharges:GetChecked() or nil,
        }

        if editIndex then
            local saveIdx = entryEditor.currentPos and entryEditor.currentPos.idx or editIndex
            SRIL:UpdateEntry(saveIdx, entryData)
        else
            SRIL:AddEntry(entryData)
        end

        entryEditor:Hide()
        SRIL:ScanBags()
        SRIL:RefreshMainList()
    end)

    -- Close other editors to avoid overlap
    if headerEditor then headerEditor:Hide() end

    entryEditor:Show()
    entryEditor:Raise()
end
local headerEditor

function SRIL:ShowHeaderEditor(editIndex, existingEntry)
    if not headerEditor then
        headerEditor = CreateFrame("Frame", "SRILHeaderEditor", UIParent, "BasicFrameTemplateWithInset")
        headerEditor:SetSize(300, 130)
        headerEditor:SetPoint("CENTER", 200, 100)
        headerEditor:SetMovable(true)
        headerEditor:EnableMouse(true)
        headerEditor:RegisterForDrag("LeftButton")
        headerEditor:SetScript("OnDragStart", headerEditor.StartMoving)
        headerEditor:SetScript("OnDragStop", headerEditor.StopMovingOrSizing)
        headerEditor:SetClampedToScreen(true)
        headerEditor:SetFrameStrata("FULLSCREEN_DIALOG")
        headerEditor:SetFrameLevel(100)

        local lblName = headerEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lblName:SetPoint("TOPLEFT", 15, -35)
        lblName:SetText("Header Text:")

        local ebName = CreateEditBox(headerEditor, 260, 20)
        ebName:SetPoint("TOPLEFT", 15, -55)
        headerEditor.ebName = ebName

        local btnSave = CreateStyledButton(headerEditor, "Save", 80, 24)
        btnSave:SetPoint("TOPLEFT", 15, -85)
        headerEditor.btnSave = btnSave

        local btnCancel = CreateStyledButton(headerEditor, "Cancel", 80, 24)
        btnCancel:SetPoint("LEFT", btnSave, "RIGHT", 8, 0)
        btnCancel:SetScript("OnClick", function() headerEditor:Hide() end)

        -- Hidden checkbox
        local cbHidden = CreateFrame("CheckButton", "SRILHeaderHiddenCheck", headerEditor, "UICheckButtonTemplate")
        cbHidden:SetSize(24, 24)
        cbHidden:SetPoint("LEFT", btnCancel, "RIGHT", 12, 0)
        cbHidden.text = cbHidden.text or _G["SRILHeaderHiddenCheckText"] or cbHidden:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cbHidden.text:SetText("Hidden")
        cbHidden.text:SetPoint("LEFT", cbHidden, "RIGHT", 2, 0)
        headerEditor.cbHidden = cbHidden

        -- Separator
        local sep = headerEditor:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", 15, -115)
        sep:SetPoint("TOPRIGHT", -15, -115)
        sep:SetColorTexture(0.4, 0.4, 0.4, 0.6)
        headerEditor.sep = sep

        -- Move buttons
        local btnMoveTop = CreateStyledButton(headerEditor, "Move to Top", 90, 22)
        btnMoveTop:SetPoint("TOPLEFT", 15, -125)
        headerEditor.btnMoveTop = btnMoveTop

        local btnMoveUp = CreateStyledButton(headerEditor, "Move Up", 70, 22)
        btnMoveUp:SetPoint("LEFT", btnMoveTop, "RIGHT", 4, 0)
        headerEditor.btnMoveUp = btnMoveUp

        local btnMoveDown = CreateStyledButton(headerEditor, "Move Down", 80, 22)
        btnMoveDown:SetPoint("TOPLEFT", 15, -150)
        headerEditor.btnMoveDown = btnMoveDown

        local btnMoveBottom = CreateStyledButton(headerEditor, "Move to Bottom", 100, 22)
        btnMoveBottom:SetPoint("LEFT", btnMoveDown, "RIGHT", 4, 0)
        headerEditor.btnMoveBottom = btnMoveBottom

        -- Delete button
        local btnDelete = CreateStyledButton(headerEditor, "Delete Header", 100, 22)
        btnDelete:SetPoint("TOPLEFT", 15, -180)
        headerEditor.btnDelete = btnDelete
    end

    headerEditor.TitleText:SetText(editIndex and "Edit Header" or "Add Header")
    headerEditor.ebName:SetText(existingEntry and existingEntry.label or "")
    headerEditor.cbHidden:SetChecked(existingEntry and existingEntry.hidden or false)

    -- Show or hide move/delete controls
    local isEditing = (editIndex ~= nil)
    headerEditor.sep:SetShown(isEditing)
    headerEditor.btnMoveTop:SetShown(isEditing)
    headerEditor.btnMoveUp:SetShown(isEditing)
    headerEditor.btnMoveDown:SetShown(isEditing)
    headerEditor.btnMoveBottom:SetShown(isEditing)
    headerEditor.btnDelete:SetShown(isEditing)
    headerEditor:SetHeight(isEditing and 215 or 130)

    if isEditing then
        local pos = { idx = editIndex }
        headerEditor.currentPos = pos

        if not headerEditor.posLabel then
            local posLabel = headerEditor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            posLabel:SetPoint("LEFT", headerEditor.btnDelete, "RIGHT", 12, 0)
            headerEditor.posLabel = posLabel
        end

        local function updatePosLabel()
            local entries = SRIL:GetProfileEntries()
            headerEditor.posLabel:SetText("|cffaaaaaa(" .. pos.idx .. "/" .. #entries .. ")|r")
        end
        headerEditor.posLabel:Show()
        updatePosLabel()

        headerEditor.btnMoveTop:SetScript("OnClick", function()
            if pos.idx > 1 then
                SRIL:MoveEntry(pos.idx, 1)
                pos.idx = 1
                updatePosLabel()
                SRIL:RefreshMainList()
            end
        end)
        headerEditor.btnMoveUp:SetScript("OnClick", function()
            if pos.idx > 1 then
                SRIL:MoveEntry(pos.idx, pos.idx - 1)
                pos.idx = pos.idx - 1
                updatePosLabel()
                SRIL:RefreshMainList()
            end
        end)
        headerEditor.btnMoveDown:SetScript("OnClick", function()
            local entries = SRIL:GetProfileEntries()
            if pos.idx < #entries then
                SRIL:MoveEntry(pos.idx, pos.idx + 1)
                pos.idx = pos.idx + 1
                updatePosLabel()
                SRIL:RefreshMainList()
            end
        end)
        headerEditor.btnMoveBottom:SetScript("OnClick", function()
            local entries = SRIL:GetProfileEntries()
            if pos.idx < #entries then
                SRIL:MoveEntry(pos.idx, #entries)
                pos.idx = #entries
                updatePosLabel()
                SRIL:RefreshMainList()
            end
        end)
        headerEditor.btnDelete:SetScript("OnClick", function()
            SRIL:RemoveEntry(pos.idx)
            headerEditor:Hide()
            SRIL:RefreshMainList()
        end)
    else
        if headerEditor.posLabel then headerEditor.posLabel:Hide() end
    end

    headerEditor.btnSave:SetScript("OnClick", function()
        local label = headerEditor.ebName:GetText()
        if not label or label == "" then
            print("|cffff0000[SRIL] Header text is required.|r")
            return
        end

        local entryData = { type = "header", label = label, hidden = headerEditor.cbHidden:GetChecked() or false }

        if editIndex then
            local saveIdx = headerEditor.currentPos and headerEditor.currentPos.idx or editIndex
            SRIL:UpdateEntry(saveIdx, entryData)
        else
            SRIL:AddEntry(entryData)
        end

        headerEditor:Hide()
        SRIL:RefreshMainList()
    end)

    -- Close other editors to avoid overlap
    if entryEditor then entryEditor:Hide() end

    headerEditor:Show()
    headerEditor:Raise()
end

----------------------------------------------------------------------
-- RENAME DIALOG (custom frame, avoids StaticPopup issues)
----------------------------------------------------------------------
local renameDialog

function SRIL:ShowRenameDialog(oldName)
    if not renameDialog then
        renameDialog = CreateFrame("Frame", "SRILRenameDialog", UIParent, "BasicFrameTemplateWithInset")
        renameDialog:SetSize(300, 130)
        renameDialog:SetPoint("CENTER", 0, 100)
        renameDialog:SetMovable(true)
        renameDialog:EnableMouse(true)
        renameDialog:RegisterForDrag("LeftButton")
        renameDialog:SetScript("OnDragStart", renameDialog.StartMoving)
        renameDialog:SetScript("OnDragStop", renameDialog.StopMovingOrSizing)
        renameDialog:SetClampedToScreen(true)
        renameDialog:SetFrameStrata("FULLSCREEN_DIALOG")
        renameDialog:SetFrameLevel(200)
        renameDialog.TitleText:SetText("Rename Profile")

        local lblName = renameDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lblName:SetPoint("TOPLEFT", 15, -35)
        lblName:SetText("New name:")

        local ebName = CreateEditBox(renameDialog, 260, 20)
        ebName:SetPoint("TOPLEFT", 15, -55)
        renameDialog.ebName = ebName

        local btnRename = CreateStyledButton(renameDialog, "Rename", 80, 24)
        btnRename:SetPoint("TOPLEFT", 15, -85)
        renameDialog.btnRename = btnRename

        local btnCancel = CreateStyledButton(renameDialog, "Cancel", 80, 24)
        btnCancel:SetPoint("LEFT", btnRename, "RIGHT", 8, 0)
        btnCancel:SetScript("OnClick", function() renameDialog:Hide() end)

        ebName:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            renameDialog.btnRename:Click()
        end)
    end

    renameDialog.ebName:SetText(oldName)
    renameDialog.ebName:HighlightText()
    renameDialog.ebName:SetFocus()

    renameDialog.btnRename:SetScript("OnClick", function()
        local newName = renameDialog.ebName:GetText()
        if not newName or newName == "" then return end
        if newName == oldName then
            renameDialog:Hide()
            return
        end
        if SRIL.db.profiles[newName] then
            print("|cffff0000[SRIL] A profile named '" .. newName .. "' already exists.|r")
            return
        end
        SRIL:RenameProfile(oldName, newName)
        renameDialog:Hide()
        SRIL:RefreshProfileList()
        SRIL:RefreshMainList()
    end)

    renameDialog:Show()
    renameDialog:Raise()
end

----------------------------------------------------------------------
-- PROFILE MANAGER
----------------------------------------------------------------------
local profileManager

function SRIL:ShowProfileManager()
    if not profileManager then
        profileManager = CreateFrame("Frame", "SRILProfileManager", UIParent, "BasicFrameTemplateWithInset")
        profileManager:SetSize(400, 380)
        profileManager:SetPoint("CENTER", -200, 0)
        profileManager:SetMovable(true)
        profileManager:EnableMouse(true)
        profileManager:RegisterForDrag("LeftButton")
        profileManager:SetScript("OnDragStart", profileManager.StartMoving)
        profileManager:SetScript("OnDragStop", profileManager.StopMovingOrSizing)
        profileManager:SetClampedToScreen(true)
        profileManager:SetFrameStrata("FULLSCREEN_DIALOG")
        profileManager:SetFrameLevel(50)
        profileManager.TitleText:SetText("Profile Manager")

        -- New profile name
        local lblNew = profileManager:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lblNew:SetPoint("TOPLEFT", 15, -35)
        lblNew:SetText("New Profile Name:")

        local ebNew = CreateEditBox(profileManager, 200, 20)
        ebNew:SetPoint("TOPLEFT", 15, -55)
        profileManager.ebNew = ebNew

        local btnCreate = CreateStyledButton(profileManager, "Create", 70, 22)
        btnCreate:SetPoint("LEFT", ebNew, "RIGHT", 8, 0)
        btnCreate:SetScript("OnClick", function()
            local name = profileManager.ebNew:GetText()
            if name and name ~= "" then
                SRIL:CreateProfile(name)
                SRIL:SetActiveProfile(name)
                profileManager.ebNew:SetText("")
                SRIL:RefreshProfileList()
                SRIL:RefreshMainList()
            end
        end)

        -- Profile list scroll
        local scrollFrame = CreateFrame("ScrollFrame", "SRILProfileScroll", profileManager, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 15, -85)
        scrollFrame:SetPoint("BOTTOMRIGHT", -35, 45)

        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetWidth(330)
        content:SetHeight(400)
        scrollFrame:SetScrollChild(content)
        profileManager.listContent = content
        profileManager.profileRows = {}

        -- Close button
        local btnClose = CreateStyledButton(profileManager, "Close", 80, 24)
        btnClose:SetPoint("BOTTOMRIGHT", -15, 12)
        btnClose:SetScript("OnClick", function() profileManager:Hide() end)

        -- Reset to defaults button
        local btnReset = CreateStyledButton(profileManager, "Reset All", 90, 24)
        btnReset:SetPoint("BOTTOMLEFT", 15, 12)
        btnReset:SetScript("OnClick", function()
            SRIL:ShowResetConfirm()
        end)

        -- Starter Profiles button
        local btnStarters = CreateStyledButton(profileManager, "Starter Profiles", 130, 24)
        btnStarters:SetPoint("LEFT", btnReset, "RIGHT", 8, 0)
        btnStarters:SetScript("OnClick", function()
            SRIL:ShowStarterProfiles()
        end)
    end

    SRIL:RefreshProfileList()
    profileManager:Show()
    profileManager:Raise()
end

----------------------------------------------------------------------
-- RESET CONFIRMATION DIALOG
----------------------------------------------------------------------
local resetConfirm

function SRIL:ShowResetConfirm()
    if not resetConfirm then
        resetConfirm = CreateFrame("Frame", "SRILResetConfirm", UIParent, "BasicFrameTemplateWithInset")
        resetConfirm:SetSize(340, 190)
        resetConfirm:SetPoint("CENTER", 0, 100)
        resetConfirm:SetMovable(true)
        resetConfirm:EnableMouse(true)
        resetConfirm:RegisterForDrag("LeftButton")
        resetConfirm:SetScript("OnDragStart", resetConfirm.StartMoving)
        resetConfirm:SetScript("OnDragStop", resetConfirm.StopMovingOrSizing)
        resetConfirm:SetClampedToScreen(true)
        resetConfirm:SetFrameStrata("FULLSCREEN_DIALOG")
        resetConfirm:SetFrameLevel(200)
        resetConfirm.TitleText:SetText("Reset Profiles")

        local warnText = resetConfirm:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        warnText:SetPoint("TOPLEFT", 15, -35)
        warnText:SetPoint("TOPRIGHT", -15, -35)
        warnText:SetText("|cffff3333WARNING:|r This will delete ALL profiles\nand leave you with a single empty Default profile.\nThis cannot be undone.\n\nYou can re-import starter profiles afterwards\nfrom the Starter Profiles menu.")
        warnText:SetJustifyH("CENTER")

        local btnConfirm = CreateStyledButton(resetConfirm, "Reset All", 90, 24)
        btnConfirm:SetPoint("BOTTOMRIGHT", resetConfirm, "BOTTOM", -4, 12)
        btnConfirm:SetScript("OnClick", function()
            -- Wipe all profiles, leave just an empty Default
            wipe(SRIL.db.profiles)
            SRIL.db.profiles["Default"] = { entries = {} }
            SRIL.db.activeProfile = "Default"
            resetConfirm:Hide()
            SRIL:RefreshProfileList()
            SRIL:RefreshMainList()
            print("|cff00ccffSilly Raid Item Lists|r profiles reset.")
        end)

        local btnCancel = CreateStyledButton(resetConfirm, "Cancel", 80, 24)
        btnCancel:SetPoint("BOTTOMLEFT", resetConfirm, "BOTTOM", 4, 12)
        btnCancel:SetScript("OnClick", function() resetConfirm:Hide() end)
    end

    resetConfirm:Show()
    resetConfirm:Raise()
end

----------------------------------------------------------------------
-- STARTER PROFILES PICKER
----------------------------------------------------------------------
local starterProfiles

function SRIL:ShowStarterProfiles()
    if not starterProfiles then
        starterProfiles = CreateFrame("Frame", "SRILStarterProfiles", UIParent, "BasicFrameTemplateWithInset")
        starterProfiles:SetSize(380, 360)
        starterProfiles:SetPoint("CENTER", 200, 0)
        starterProfiles:SetMovable(true)
        starterProfiles:EnableMouse(true)
        starterProfiles:RegisterForDrag("LeftButton")
        starterProfiles:SetScript("OnDragStart", starterProfiles.StartMoving)
        starterProfiles:SetScript("OnDragStop", starterProfiles.StopMovingOrSizing)
        starterProfiles:SetClampedToScreen(true)
        starterProfiles:SetFrameStrata("FULLSCREEN_DIALOG")
        starterProfiles:SetFrameLevel(150)
        starterProfiles.TitleText:SetText("Starter Profiles")

        -- Header text
        local header = starterProfiles:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", 15, -32)
        header:SetPoint("TOPRIGHT", -15, -32)
        header:SetJustifyH("LEFT")
        header:SetText("Click |cff00ff00Import|r to add a starter profile.\nYou can edit it freely after importing.")

        -- Scroll frame for the list
        local scrollFrame = CreateFrame("ScrollFrame", "SRILStarterScroll", starterProfiles, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 15, -75)
        scrollFrame:SetPoint("BOTTOMRIGHT", -35, 45)

        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetWidth(310)
        content:SetHeight(400)
        scrollFrame:SetScrollChild(content)
        starterProfiles.listContent = content
        starterProfiles.rows = {}

        -- Close button
        local btnClose = CreateStyledButton(starterProfiles, "Close", 80, 24)
        btnClose:SetPoint("BOTTOMRIGHT", -15, 12)
        btnClose:SetScript("OnClick", function() starterProfiles:Hide() end)
    end

    SRIL:RefreshStarterProfilesList()
    starterProfiles:Show()
    starterProfiles:Raise()
end

function SRIL:RefreshStarterProfilesList()
    if not starterProfiles then return end
    local content = starterProfiles.listContent

    -- Clear old rows
    for _, row in pairs(starterProfiles.rows) do
        row:Hide()
    end

    local list = self:GetStarterProfiles()
    local yPos = 0

    if #list == 0 then
        -- Show "no profiles available" message
        local row = starterProfiles.rows[1]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetSize(310, 30)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.text:SetPoint("LEFT", 5, 0)
            row.text:SetText("|cff999999No starter profiles available.|r")
            starterProfiles.rows[1] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, 0)
        row:Show()
        return
    end

    for i, info in ipairs(list) do
        local row = starterProfiles.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetSize(310, 28)

            -- Name label
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", 5, 0)

            -- Import button
            row.btnImport = CreateStyledButton(row, "Import", 75, 22)
            row.btnImport:SetPoint("RIGHT", -5, 0)

            starterProfiles.rows[i] = row
        end

        row.nameText:SetText(info.name or "Unnamed")

        -- Capture the name in a local for the closure
        local starterName = info.name
        row.btnImport:SetScript("OnClick", function()
            local ok, result = SRIL:ImportStarterProfile(starterName)
            if ok then
                print("|cff00ccffSilly Raid Item Lists|r imported starter profile: |cff00ff00" .. result .. "|r")
                SRIL:SetActiveProfile(result)
                SRIL:RefreshProfileList()
                SRIL:RefreshMainList()
            else
                print("|cff00ccffSilly Raid Item Lists|r import failed: " .. tostring(result))
            end
        end)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -yPos)
        row:Show()
        yPos = yPos + 32
    end

    content:SetHeight(math.max(yPos, 100))
end

function SRIL:RefreshProfileList()
    if not profileManager then return end
    local content = profileManager.listContent

    -- Clear old rows
    for _, row in pairs(profileManager.profileRows) do
        row:Hide()
    end

    local names = self:GetProfileNames()
    local yPos = 0

    for i, name in ipairs(names) do
        local row = profileManager.profileRows[i]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetHeight(24)
            row:SetWidth(330)

            local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("LEFT", 4, 0)
            label:SetWidth(120)
            label:SetJustifyH("LEFT")
            row.label = label

            local btnSelect = CreateStyledButton(row, "Select", 50, 20)
            btnSelect:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            row.btnSelect = btnSelect

            local btnRen = CreateStyledButton(row, "Ren", 35, 20)
            btnRen:SetPoint("RIGHT", btnSelect, "LEFT", -2, 0)
            row.btnRen = btnRen

            local btnDup = CreateStyledButton(row, "Copy", 45, 20)
            btnDup:SetPoint("RIGHT", btnRen, "LEFT", -2, 0)
            row.btnDup = btnDup

            local btnDel = CreateStyledButton(row, "Del", 35, 20)
            btnDel:SetPoint("RIGHT", btnDup, "LEFT", -2, 0)
            row.btnDel = btnDel

            profileManager.profileRows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yPos)
        row:Show()

        local isActive = (name == self:GetActiveProfile())
        row.label:SetText(isActive and ("|cff00ff00" .. name .. "|r") or name)

        row.btnSelect:SetScript("OnClick", function()
            SRIL:SetActiveProfile(name)
            SRIL:ScanBags()
            SRIL:RefreshProfileList()
            SRIL:RefreshMainList()
        end)

        row.btnRen:SetScript("OnClick", function()
            SRIL:ShowRenameDialog(name)
        end)

        row.btnDup:SetScript("OnClick", function()
            local newName = name .. " Copy"
            SRIL:DuplicateProfile(name, newName)
            SRIL:RefreshProfileList()
        end)

        row.btnDel:SetScript("OnClick", function()
            if name == "Default" then
                print("|cffff0000[SRIL] Cannot delete the Default profile.|r")
                return
            end
            StaticPopupDialogs["SRIL_DELETE_PROFILE"] = {
                text = "Delete profile '" .. name .. "'?",
                button1 = "Delete",
                button2 = "Cancel",
                OnAccept = function()
                    SRIL:DeleteProfile(name)
                    SRIL:RefreshProfileList()
                    SRIL:RefreshMainList()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("SRIL_DELETE_PROFILE")
        end)

        yPos = yPos - 26
    end

    content:SetHeight(math.abs(yPos) + 10)
end

----------------------------------------------------------------------
-- IMPORT / EXPORT
----------------------------------------------------------------------
local importExportFrame

function SRIL:ShowImportExport()
    if not importExportFrame then
        importExportFrame = CreateFrame("Frame", "SRILImportExport", UIParent, "BasicFrameTemplateWithInset")
        importExportFrame:SetSize(500, 350)
        importExportFrame:SetPoint("CENTER", 0, 50)
        importExportFrame:SetMovable(true)
        importExportFrame:EnableMouse(true)
        importExportFrame:RegisterForDrag("LeftButton")
        importExportFrame:SetScript("OnDragStart", importExportFrame.StartMoving)
        importExportFrame:SetScript("OnDragStop", importExportFrame.StopMovingOrSizing)
        importExportFrame:SetClampedToScreen(true)
        importExportFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        importExportFrame:SetFrameLevel(50)
        importExportFrame.TitleText:SetText("Import / Export Profile")

        -- Export button
        local btnExport = CreateStyledButton(importExportFrame, "Export Current Profile", 160, 24)
        btnExport:SetPoint("TOPLEFT", 15, -35)
        btnExport:SetScript("OnClick", function()
            local encoded = SRIL:ExportProfile(SRIL:GetActiveProfile())
            if encoded then
                importExportFrame.editBox:SetText(encoded)
                importExportFrame.editBox:HighlightText()
                importExportFrame.editBox:SetFocus()
                importExportFrame.statusText:SetText("|cff00ff00Profile exported! Copy the text above.|r")
            end
        end)

        -- Import button
        local btnImport = CreateStyledButton(importExportFrame, "Import from Text", 130, 24)
        btnImport:SetPoint("LEFT", btnExport, "RIGHT", 8, 0)
        btnImport:SetScript("OnClick", function()
            importExportFrame.editBox:SetFocus()
            local text = importExportFrame.editBox:GetText()
            if text and text ~= "" then
                local success, result = SRIL:ImportProfile(text)
                if success then
                    SRIL:SetActiveProfile(result)
                    SRIL:ScanBags()
                    SRIL:RefreshMainList()
                    importExportFrame.statusText:SetText("|cff00ff00Imported as '" .. result .. "'!|r")
                else
                    importExportFrame.statusText:SetText("|cffff0000Import failed: " .. result .. "|r")
                end
            end
        end)

        -- Text area
        local scrollFrame = CreateFrame("ScrollFrame", "SRILIEScroll", importExportFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 15, -65)
        scrollFrame:SetPoint("BOTTOMRIGHT", -35, 40)

        local bg = scrollFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.3)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(440)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scrollFrame:SetScrollChild(editBox)
        importExportFrame.editBox = editBox

        -- Status text
        local statusText = importExportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("BOTTOMLEFT", 15, 15)
        statusText:SetText("")
        importExportFrame.statusText = statusText
    end

    importExportFrame.editBox:SetText("")
    importExportFrame.statusText:SetText("Paste an import string, or click Export to generate one.")
    importExportFrame:Show()
    importExportFrame:Raise()
end

----------------------------------------------------------------------
-- Toggle main window
----------------------------------------------------------------------
function SRIL:ToggleMainWindow()
    local frame = CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        self:ScanBags()
        self:RefreshMainList()
    end
end

----------------------------------------------------------------------
-- ESC to close
----------------------------------------------------------------------
tinsert(UISpecialFrames, "SRILMainFrame")

----------------------------------------------------------------------
-- INTERFACE OPTIONS PANEL
--
-- Adds an entry under the standard Interface > AddOns options window.
-- Right now it's just a button that opens the main addon window.
----------------------------------------------------------------------
local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "SRILOptionsPanel", UIParent)
    panel.name = "Silly Raid Item Lists"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Silly Raid Item Lists")

    -- Subtitle / blurb
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Build and manage consumable checklists for raids with profiles and import/export.")

    -- Button to open main window
    local btnOpen = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnOpen:SetSize(180, 24)
    btnOpen:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -20)
    btnOpen:SetText("Open Silly Raid Item Lists")
    btnOpen:SetScript("OnClick", function()
        -- Close the options window first so our window isn't stuck behind it
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
            HideUIPanel(InterfaceOptionsFrame)
        end
        if SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        end
        SRIL:ToggleMainWindow()
    end)

    -- Hint text
    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", btnOpen, "BOTTOMLEFT", 0, -12)
    hint:SetText("You can also use |cff00ff00/sril|r or click the minimap button.")

    return panel
end

local function RegisterOptionsPanel()
    local panel = CreateOptionsPanel()

    -- Modern retail API (Dragonflight+) uses Settings.RegisterCanvasLayoutCategory.
    -- Classic / older clients use InterfaceOptions_AddCategory.
    -- Try the modern one first, fall back to the old one.
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = panel.name
        Settings.RegisterAddOnCategory(category)
        SRIL.optionsCategoryID = category.ID
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        SRIL.optionsCategoryID = panel.name
    end
end

-- Register on PLAYER_LOGIN to make sure the options system is ready
local optionsRegFrame = CreateFrame("Frame")
optionsRegFrame:RegisterEvent("PLAYER_LOGIN")
optionsRegFrame:SetScript("OnEvent", function()
    RegisterOptionsPanel()
end)
