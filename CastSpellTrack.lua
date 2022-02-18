local addonName, CST = ...

local TrackBase = CST.TrackBase
local L = CST.L

local adb = LibStub("AceDB-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local db

local tinsert, tremove, tostring, print, ipairs = table.insert, table.remove, tostring, print, ipairs


SLASH_CASTSPELLTRACK1 = "/cst"
SLASH_CASTSPELLTRACK2 = "/castspelltrack"

function SlashCmdList.CASTSPELLTRACK()
    CST:ShowOption()
end

local defaultDb = {
    global = {
        -- TODO: 添加全局设置
    },
    profile = {
        trackMap = {}
    }
}

local showList, mapList

do 
    showList = {}
    mapList = {}
    for k, v in ipairs(CST.UnitConfig) do
        if v.show then
            tinsert(showList, L[v.name])
            mapList[L[v.name]] = v.name
        end
    end
end

local function copyConfig(config)
    local ret = {}
    
    for k, v in pairs(config) do
        if type(v) == "table" then
            ret[k] = copyConfig(v)
        else
            ret[k] = v
        end
    end
    
    return ret
end

local function InitDefaultDb()
    for k, v in ipairs(CST.UnitConfig) do
        defaultDb.profile.trackMap[v.name] = copyConfig(TrackBase.defaultConfig)
        defaultDb.profile.trackMap[v.name].name = v.name
        if v.name ~= "player" then
            defaultDb.profile.trackMap[v.name].enable = false
        end
    end
end

-- main frame
do 
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, event, ...)
        CST[event](CST, ...)
    end)

    CST.mainFrame = frame

    function CST:ADDON_LOADED(name)
        if name == addonName then
            -- self:Print("addon loaded")
            InitDefaultDb()
            db = adb:New("CastSpellTrackDB", defaultDb, true)
            self:InitCoreTrackFrame()
            self:CreateTracks()
            self.mainFrame:UnregisterEvent("ADDON_LOADED")
        end
    end
end

function CST:InitCoreTrackFrame()
    if not self.tracks then self.tracks = {} end
    -- self:Print("init track")
    local trackFrame = CreateFrame("Frame") 
    trackFrame:RegisterEvent("UNIT_SPELLCAST_START")
    trackFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    trackFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    trackFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    trackFrame:RegisterEvent("UNIT_SPELLCAST_STOP")

    trackFrame:SetScript("OnEvent", function(frame, event, ...)
        for k, v in pairs(self.tracks) do
            if v[event] then
                v[event](v, ...)
            end
        end
    end)

    self.trackFrame = trackFrame
end

function CST:CreateTracks()
    for k, v in pairs(db.profile.trackMap) do
        if v.enable and mapList[L[v.name]] then
            self:CreateTrack(v.name)
        end
    end
end

function CST:CreateTrack(key)
    local track = TrackBase.New(key , db.profile.trackMap[key])
    self.tracks[key] = track
end

function CST:Print(msg)
    msg = tostring(msg)
    print(msg)
end

function CST:ShowOption()
    -- self:Print("open option")
    for k, v in pairs(self.tracks) do
        v:OnOpenOption()
    end

    local optionFrame = AceGUI:Create("Frame")
    optionFrame:SetTitle(L.title)
    optionFrame:SetWidth(500)
    optionFrame:SetHeight(500)
    optionFrame:SetLayout("Flow")

    self:ShowDropDown(optionFrame)
end

function CST:ShowDropDown(optionFrame)
    local currentDropDownVal = L.player
    local currentDropDownTrackDb

    local globalSettingContainer = AceGUI:Create("InlineGroup")
    globalSettingContainer:SetHeight(200)
    globalSettingContainer:SetLayout("Flow")
    globalSettingContainer:SetTitle(L.globalSetting)
    globalSettingContainer:SetFullWidth(true)

    optionFrame:AddChild(globalSettingContainer)

    local globalReset = AceGUI:Create("Button")
    globalReset:SetText(L.resetAllButton)
    
    
    globalSettingContainer:AddChild(globalReset)
    
    local playerContainer = AceGUI:Create("SimpleGroup")
    playerContainer:PauseLayout()
    playerContainer:SetLayout("Fill")
    playerContainer:SetFullWidth(true)
    playerContainer:SetHeight(350)
    optionFrame:AddChild(playerContainer)

    local dropDownContainer = AceGUI:Create("DropdownGroup")
    
    -- 下拉列表数据
    currentDropDownTrackDb = db.profile.trackMap[mapList[currentDropDownVal]]

    playerContainer:SetLayout("Fill")
    dropDownContainer:SetGroupList(showList)
    dropDownContainer:SetTitle(L.choose)

    playerContainer:AddChild(dropDownContainer)

    local enableCheck = AceGUI:Create("CheckBox")
    enableCheck:SetLabel(L.enable)
    enableCheck:SetValue(currentDropDownTrackDb.enable)
    enableCheck:SetCallback("OnValueChanged", function (widget, callbackName, val)
        local key = mapList[currentDropDownVal]
        currentDropDownTrackDb.enable = val
        if val then
            if self.tracks[key] then
                self.tracks[key]:Enable() 
            else
                self:CreateTrack(key)
            end
        else
            if self.tracks[key] then
                self.tracks[mapList[currentDropDownVal]]:Disable()
            end
        end
    end)
    dropDownContainer:AddChild(enableCheck)

    -- 追踪数量slider
    local trackCountSlider = AceGUI:Create("Slider")
    trackCountSlider:SetLabel(L.trackCount)
    trackCountSlider:SetValue(currentDropDownTrackDb.trackCount)
    trackCountSlider:SetSliderValues(1, 10, 1)
    trackCountSlider:SetFullWidth(true)
    trackCountSlider:SetCallback("OnValueChanged", function (widget, callbackName, val)
        local key = mapList[currentDropDownVal]

        if self.tracks[key] then
            self.tracks[key]:OnTrackCountChange(val)
        end
    end)

    dropDownContainer:AddChild(trackCountSlider)

    -- 缩放slider
    local scaleSlider = AceGUI:Create("Slider")
    scaleSlider:SetLabel(L.scale)
    scaleSlider:SetValue(currentDropDownTrackDb.scale)
    scaleSlider:SetSliderValues(0.5, 4, 0.1)
    scaleSlider:SetFullWidth(true)
    scaleSlider:SetCallback("OnValueChanged", function (widget, callbackName, val)
        local key = mapList[currentDropDownVal]

        if self.tracks[key] then
            self.tracks[key]:OnScaleChange(val)
        end
    end)

    dropDownContainer:AddChild(scaleSlider)
    
    -- 背景透明度
    local bgAlphaSlider = AceGUI:Create("Slider")
    bgAlphaSlider:SetLabel(L.backGroundAlpha)
    bgAlphaSlider:SetValue(currentDropDownTrackDb.bgAlpha)
    bgAlphaSlider:SetSliderValues(0, 1, 0.1)
    bgAlphaSlider:SetFullWidth(true)
    bgAlphaSlider:SetCallback("OnValueChanged", function (widget, callbackName, val)
        local key = mapList[currentDropDownVal]
        if self.tracks[key] then
            self.tracks[key]:OnBgAlphaChange(val)
        end
    end)

    dropDownContainer:AddChild(bgAlphaSlider)

    -- 分割线
    local line = AceGUI:Create("Heading")
    line:SetFullWidth(true)
    dropDownContainer:AddChild(line)

    -- 背景颜色
    local bgColor = currentDropDownTrackDb.bgColor
    local bgColorPicker = AceGUI:Create("ColorPicker")
    bgColorPicker:SetHasAlpha(false)
    bgColorPicker:SetLabel(L.backGroundColor)
    bgColorPicker:SetColor(bgColor.r, bgColor.g, bgColor.b, 1)
    bgColorPicker:SetCallback("OnValueConfirmed", function (widget, callbackName, r, g, b, a)
        local key = mapList[currentDropDownVal]
        if self.tracks[key] then
            self.tracks[key]:OnBgColorChange(r, g, b)
        end
    end)

    dropDownContainer:AddChild(bgColorPicker)

    -- 拖拽
    local dragCheck = AceGUI:Create("CheckBox")
    dragCheck:SetLabel(L.enableDrag)
    dragCheck:SetValue(currentDropDownTrackDb.enableDrag)
    dragCheck:SetCallback("OnValueChanged", function (widget, callbackName, val)
        local key = mapList[currentDropDownVal]
        if self.tracks[key] then
            self.tracks[key]:OnDragChange(val)
        end
    end)

    dropDownContainer:AddChild(dragCheck)

    -- 名称checkbox
    local nameCheck = AceGUI:Create("CheckBox")
    nameCheck:SetLabel(L.showName)
    nameCheck:SetValue(currentDropDownTrackDb.enableName)
    nameCheck:SetCallback("OnValueChanged", function (widget, callbackName, val)
        local key = mapList[currentDropDownVal]
        if self.tracks[key] then
            self.tracks[key]:OnShowName(val)
        end
    end)

    dropDownContainer:AddChild(nameCheck)

    local function SetSettingVal(config)
        enableCheck:SetValue(config.enable)
        trackCountSlider:SetValue(config.trackCount)
        scaleSlider:SetValue(config.scale)
        bgAlphaSlider:SetValue(config.bgAlpha)
        bgColorPicker:SetColor(config.bgColor.r, config.bgColor.g, config.bgColor.b, 1)
        dragCheck:SetValue(config.enableDrag)
        nameCheck:SetValue(currentDropDownTrackDb.enableName)
    end

    globalReset:SetCallback("OnClick", function (widget, callbackName, val)
        db:ResetDB()
        currentDropDownTrackDb = db.profile.trackMap[mapList[currentDropDownVal]]

        for k, v in pairs(db.profile.trackMap) do
            if self.tracks[v.name] then
                self.tracks[v.name]:Reset(v)
            end
        end

        SetSettingVal(currentDropDownTrackDb)
    end)

    -- 重置按钮
    local resetButton = AceGUI:Create("Button")
    resetButton:SetText(L.resetButton)
    resetButton:SetCallback("OnClick", function (widget, callbackName, val)
        local key = mapList[currentDropDownVal]
        local oldConfig = db.profile.trackMap[key]

        db.profile.trackMap[key] = copyConfig(TrackBase.defaultConfig)
        db.profile.trackMap[key].name = oldConfig.name

        SetSettingVal(db.profile.trackMap[key])

        if self.tracks[key] then
            self.tracks.player:Reset(db.profile.trackMap[key])
        end
    end)


    dropDownContainer:AddChild(resetButton)
    dropDownContainer:SetCallback("OnGroupSelected", function (widget, callbackName, val)
        currentDropDownVal = showList[val]
        currentDropDownTrackDb = db.profile.trackMap[mapList[currentDropDownVal]]
        
        SetSettingVal(currentDropDownTrackDb)
    end)

    playerContainer:ResumeLayout()
    playerContainer:PerformLayout()
    dropDownContainer:SetGroup(1)
end

function CST:IsTrackEnable(key)
    if not self.tracks[key] then
        return false
    end

    return self.tracks[key].config.enable
end