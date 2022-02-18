local _, CST = ...

local TrackBase = {}

local tinsert, tremove, abs, ipairs = table.insert, table.remove, math.abs, ipairs
local GetSpellTexture, GetSpellInfo = GetSpellTexture, GetSpellInfo

CST.TrackBase = TrackBase

local cross = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7"
local texLayer, stateLayer = 2, 3

do
    local defaultConfig = {
        trackCount = 3,
        iconSize = 45,
        layer = "LOW",
        scale = 1,
        enable = true,
        bgAlpha = 0.1,
        enableDrag = true,
        bgColor = {r = 1, g = 1, b = 1},
        enableName = true
    }

    TrackBase.defaultConfig = defaultConfig

end

function TrackBase.New(unitID, config)
    local tbl = {
        unitID = unitID,
        config = config
    }
    local track = setmetatable(tbl, {__index = TrackBase})
    track:Init()
    return track
end

function TrackBase:Init()
    -- CST:Print("base frame")

    self.waitSpells = {} 
    self.moveSpells = {} 
    self.currentTime = 0

    -- Track Frame
    local frame = CreateFrame("Frame")
    self.frame = frame
    self:SetFrameSize()
    self:CreateDragTex()
    self:CreateNameText()
    self:CreateTemplateTexture()

    self.frame:SetScript("OnUpdate", function (frame, elapse)
        self:Update(elapse)
    end)
end

function TrackBase:SetFrameSize()
    local config = self.config
    self.frame:SetWidth(config.iconSize * (config.trackCount + 1))
    self.frame:SetHeight(config.iconSize)

    if self.config.left and self.config.top then
        self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self.config.left, self.config.top)
    else
        self.frame:SetPoint("CENTER", 0, 0)
    end
    self.frame:SetScale(config.scale)
end

function TrackBase:CreateDragTex()
    local dragTex = self.frame:CreateTexture(nil, self.config.layer, nil, 1)
    local config = self.config

    dragTex:SetColorTexture(config.bgColor.r, config.bgColor.g, config.bgColor.b, 1)
    dragTex:SetAlpha(config.bgAlpha)
    dragTex:SetPoint("CENTER", 0, 0)
    dragTex:SetWidth(config.iconSize * (config.trackCount + 1))
    dragTex:SetHeight(config.iconSize)

    self.frame:RegisterForDrag("LeftButton")
    self:RegisterDrag(config.enableDrag)

    self.dragTex = dragTex
end

function TrackBase:CreateNameText()
    local name = self.frame:CreateFontString()
    name:SetFont("Fonts\\FRIZQT__.TTF", 10)
    name:SetText(self.config.name)
    name:SetPoint("CENTER", 0, self.config.iconSize / 2 + 5)
    name:SetHeight(25)

    self.nameText = name
end

function TrackBase:RegisterDrag(flag)
    self.frame:SetMovable(flag)
    self.frame:EnableMouse(flag)

    if flag then
        self.frame:SetScript("OnDragStart", function(frame)
            frame:StartMoving()
        end)

        self.frame:SetScript("OnDragStop", function(frame)
            frame:StopMovingOrSizing()

            self.config.left = frame:GetLeft()
            self.config.top = frame:GetTop()
        end)
    else 
        self.frame:SetScript("OnDragStart", nil)

        self.frame:SetScript("OnDragStop", nil)
    end
end

function TrackBase:TrackSpell(castGUID, spellID, isChannel, isNoneInstant, successCast)
    local track = {
        castGUID = castGUID,
        spellID = spellID,
        isChannel = isChannel,
        isNoneInstant = isNoneInstant,
        index = 0,                              -- 移动下标
        alpha = 1,
        x = 0,
        y = 0,                                  
        tex = nil,                              -- 法术图标
        stopMove = isChannel or isNoneInstant,  -- 是否暂停移动
        successCast = successCast,              -- 法术释放成功
        stateTex = nil                          -- 状态图标
    }

    local name = GetSpellInfo(spellID)
    track.spellName = name

    return track
end

function TrackBase:AddWaitSpell(track)
    tinsert(self.waitSpells, track)

    if self.stopMove then
        self.stopMove = nil
    end
end

function TrackBase:AddMoveSpell()
    local waitSpell = self.waitSpells[1]
    tremove(self.waitSpells, 1)

    local tex = self:GetTexture()
    tex:SetTexture(GetSpellTexture(waitSpell.spellID))
    tex:SetPoint("TOPRIGHT", 0, 0)
    tex:SetAlpha(1)

    waitSpell.tex = tex
    tinsert(self.moveSpells, waitSpell)

    if waitSpell.stateTex then
        waitSpell.stateTex:SetPoint("TOPRIGHT", 0, 0)
        waitSpell.stateTex:SetAlpha(1)
    end

    if waitSpell.stopMove then
        self.stopMove = true
    end

    waitSpell.stopMove = nil
end

function TrackBase:CreateStateTex(track)
    local stateTex = self:GetTexture(stateLayer)

    stateTex:SetAlpha(0)
    stateTex:SetTexture(cross)
    track.stateTex = stateTex
end

function TrackBase:CreateTemplateTexture()
    if not self.texutresPool then self.texturePool = {} end

    for i = 1, self.config.trackCount + 1, 1 do
        local tex = self:CreateTexture()
        tinsert(self.texturePool, tex)
    end
end

function TrackBase:CreateTexture(subLayer)
    if not subLayer then
        subLayer = texLayer
    end

    local tex = self.frame:CreateTexture(nil, self.config.layerh, nil, subLayer)
    tex:SetWidth(self.config.iconSize)
    tex:SetHeight(self.config.iconSize)
    return tex
end

function TrackBase:GetTexture(subLayer)
    if not subLayer then
        subLayer = texLayer
    end

    if not self.texturePool[subLayer] then
        self.texturePool[subLayer] = {}
    end

    if #self.texturePool[subLayer] > 0 then
        local ret = self.texturePool[subLayer][1]
        tremove(self.texturePool[subLayer], 1)
        return ret
    end

    local tex = self:CreateTexture(subLayer)
    return tex
end

function TrackBase:TexAlpha(track)
    local config = self.config
    if track.index < config.trackCount - 1 then
        return 
    end

    local alpha = 1
    local totalSize = config.iconSize * config.trackCount
    local alphaSize = totalSize - abs(track.x)

    if alphaSize < 0 then
        alpha = 0
    else
        alpha = alphaSize / config.iconSize
    end
    track.tex:SetAlpha(alpha)

    if track.stateTex then
        track.stateTex:SetAlpha(alpha)
    end
end

function TrackBase:RemoveTrack()
    if #self.moveSpells <= 0 then
        return 
    end

    local track = self.moveSpells[1]

    self:RecyleTexture(track.tex)
    track.tex = nil
    
    if track.stateTex then
        self:RecyleTexture(track.stateTex, stateLayer)
        track.stateTex = nil
    end
    
    tremove(self.moveSpells, 1)
end

function TrackBase:RecyleTexture(tex, subLevel)
    if not subLevel then
        subLevel = texLayer
    end

    tinsert(self.texturePool[subLevel], tex)
    tex:SetAlpha(0)
end

function TrackBase: CheckSpellAlreadyTrack(castGUID, spellID)
    for k, v in ipairs(self.waitSpells) do
        if v.castGUID == castGUID then
            v.stopMove = nil
            v.successCast = true
            return true
        end

        if v.isChannel then
            -- channel法术需要使用名称判断
            local name = GetSpellInfo(spellID)

            -- 如果这个channel法术不是等待队列的最后一个，那么就不应该阻止移动了
            if k ~= #self.waitSpells then
                v.stopMove = nil
            end

            if v.spellName == name then
                return true
            end
        end
    end

    -- 已移动法术
    if #self.moveSpells > 0 then
        local moveSpell = self.moveSpells[#self.moveSpells]
        if moveSpell.castGUID == castGUID and moveSpell.isNoneInstant then
            moveSpell.stopMove = nil
            moveSpell.successCast = true

            --- 有可能先收到stop，再收到success，这种情况下技能释放成功
            if moveSpell.stateTex then
                self:RecyleTexture(moveSpell.stateTex, stateLayer)
                moveSpell.stateTex = nil
            end

            return true
        end

        if moveSpell.isChannel then
            local name = GetSpellInfo(spellID)

            if moveSpell.spellName == name then
                return true
            end
        end
    end

    return false
end

function TrackBase:Reset(config)
    self.config = config

    local width = self.config.iconSize * (self.config.trackCount + 1) 
    self.frame:SetWidth(width)
    self.dragTex:SetWidth(width)
    self.dragTex:SetAlpha(self.config.bgAlpha)
    self.nameText:SetAlpha(1)

    self.frame:SetScale(1)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", 0, 0)
    
    if self.config.enable then
        self.frame:SetAlpha(1)
    else
        self.frame:SetAlpha(0)
    end

    if #self.waitSpells > 0 then
        for i = #self.waitSpells, 1, -1 do
            tremove(self.waitSpells, i)
        end
    end

    if #self.moveSpells > 0 then
        for i = #self.moveSpells, 1, -1 do
            self:RemoveTrack()
        end
    end
end

function TrackBase:Disable()
    self.frame:SetAlpha(0)
end

function TrackBase:Enable()
    self.frame:SetAlpha(1)
end


-- 设置相关
function TrackBase:OnOpenOption()
    if #self.waitSpells > 0 then
        for i = #self.waitSpells, 1, -1 do
            tremove(self.waitSpells, i)
        end
    end

    if #self.moveSpells > 0 then
        for i = #self.moveSpells, 1, -1 do
            self:RemoveTrack()
        end
    end
end

function TrackBase:OnTrackCountChange(val)
    self.config.trackCount = val

    local width = self.config.iconSize * (val + 1) 
    self.frame:SetWidth(width)
    self.dragTex:SetWidth(width)
end

function TrackBase:OnScaleChange(val)
    self.config.scale = val

    local l = self.frame:GetLeft()

    local t = self.frame:GetTop()
    local s = self.frame:GetScale()

    s = val / s

    self.frame:SetScale(val)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l / s, t / s)
end

function TrackBase:OnBgAlphaChange(val)
    self.config.bgAlpha = val
    self.dragTex:SetAlpha(val)
end

function TrackBase:OnDragChange(val)
    self.config.enableDrag = val
    self:RegisterDrag(val)
end

function TrackBase:OnBgColorChange(r, g, b)
    self.config.bgColor = {r = r, g = g, b = b}
    self.dragTex:SetColorTexture(r, g, b)
end

function TrackBase:OnShowName(val)
    self.config.enableName = val

    if val then
        self.nameText:SetAlpha(1)
    else
        self.nameText:SetAlpha(0)
    end
end

do
    local updateRate = 0.05
    local gcd = 1.5

    function TrackBase:Update(elapse)
        self.currentTime = self.currentTime + elapse

        if self.currentTime > updateRate then
            local config = self.config
            local moveSpeed = config.iconSize / gcd

            if #self.waitSpells > 0 then
                moveSpeed = moveSpeed * 5
            end

            -- 如果没有暂停移动
            if not self.stopMove then
                if #self.moveSpells > 0 then
                    for k, v in ipairs(self.moveSpells) do
                        local tex = v.tex
                        v.x = v.x - moveSpeed * self.currentTime
                        
                        if abs(v.x) > (v.index + 1) * config.iconSize then
                            -- 当移动到下一格时，让texture位置贴合该格起始位置
                            v.index = v.index + 1
                            v.x = -v.index * config.iconSize
                        end
                        
                        tex:SetPoint("TOPRIGHT", v.x, v.y)
                        if v.stateTex then
                            v.stateTex:SetPoint("TOPRIGHT", v.x ,v.y)
                            v.stateTex:SetAlpha(1)
                        end
                        self:TexAlpha(v)
                        
                    end
                end
                
                if #self.waitSpells > 0 and (#self.moveSpells == 0 or self.moveSpells[#self.moveSpells].index > 0) then
                    self:AddMoveSpell()
                end
                
                if #self.moveSpells > 0 then
                    if self.moveSpells[1].index > config.trackCount then
                        self:RemoveTrack()
                    end
                end
            end
            
            self.currentTime = 0
        end
    end

    --- spell cast handle
    function TrackBase:UNIT_SPELLCAST_START (unitTarget, castGUID, spellID)
        if unitTarget ~= self.unitID then return end
        
        local track = self:TrackSpell(castGUID, spellID, false, true, false)
        self:AddWaitSpell(track)
    end

    function TrackBase:UNIT_SPELLCAST_CHANNEL_START(unitTarget, castGUID, spellID)
        if unitTarget ~= self.unitID then return end
        
        -- 该事件castGUID为nil, channel法术默认释放成功
        local track = self:TrackSpell(castGUID, spellID, true, false, true)
        self:AddWaitSpell(track)
    end

    function TrackBase:UNIT_SPELLCAST_SUCCEEDED(unitTarget, castGUID, spellID)
        if unitTarget ~= self.unitID then return end

        if self:CheckSpellAlreadyTrack(castGUID, spellID) then
            return 
        end
        
        local track = self:TrackSpell(castGUID, spellID, false, false, true)
        self:AddWaitSpell(track)
    end

    function TrackBase:UNIT_SPELLCAST_STOP(unitTarget, castGUID, spellID)
        if unitTarget ~= self.unitID then return end

        if self.stopMove then
            self.stopMove = nil
        end

        for k, v in ipairs(self.waitSpells) do
            if v.castGUID == castGUID then
                v.stopMove = nil
            end

            -- 检测失败法术是否是该法术
            if v.castGUID == castGUID and not v.successCast then
                self:CreateStateTex(v)
            end
        end

        for k, v in ipairs(self.moveSpells) do
            if v.castGUID == castGUID and not v.successCast then
                self:CreateStateTex(v)
            end
        end
    end

    function TrackBase:UNIT_SPELLCAST_CHANNEL_STOP(unitTarget, castGUID, spellID)
        if unitTarget ~= self.unitID then return end

        for k, v in ipairs(self.waitSpells) do
            if v.isChannel then
                -- channel法术需要使用名称判断
                local name = GetSpellInfo(spellID)

                if v.spellName == name then
                    v.stopMove = nil
                end
            end
        end

        -- 已移动法术
        if #self.moveSpells > 0 then
            local moveSpell = self.moveSpells[#self.moveSpells]
            if moveSpell.isChannel then
                local name = GetSpellInfo(spellID)

                if moveSpell.spellName == name then
                    self.stopMove = nil
                end
            end
        end
    end
end