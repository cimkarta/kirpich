-- ===== KIRPICH UI :: liquid-glass style, Obsidian-compatible API =====
local Library, ThemeManager, SaveManager = (function()
local ThemeManager, SaveManager
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
if env.KirpichUILib and env.KirpichUILib.Unload then
    pcall(function() env.KirpichUILib:Unload() end)
end

local Library = {
    Options = {}, Toggles = {}, Registry = {}, Signals = {}, UnloadCallbacks = {}, Tabs = {},
    Scheme = {},
    CornerRadius = 18, DPIScale = 1, Toggled = true, Unloaded = false,
    Animations = { ToggleWindow = false, TabSwitch = true, Groupbox = true, Dropdown = true, KeyPicker = true },
    ShowCustomCursor = true, Keybinds = {}, AccentUpdaters = {}, CornerObjects = {},
    NotifySide = "Right",
}
env.KirpichUILib = Library

local C = Library.Scheme
C.BackgroundColor = Color3.fromRGB(52, 52, 56)   -- smoky glass base
C.SidebarColor = Color3.fromRGB(74, 74, 78)
C.MainColor = Color3.fromRGB(246, 246, 247)       -- frosted card (rendered at high transparency)
C.RowColor = Color3.fromRGB(252, 252, 253)        -- frosted control (rendered at high transparency)
C.OutlineColor = Color3.fromRGB(255, 255, 255)    -- glass rim light
C.PopupColor = Color3.fromRGB(22, 22, 24)
C.AccentColor = Color3.fromRGB(10, 132, 255)      -- glass blue
C.FontColor = Color3.fromRGB(246, 246, 247)
C.DimColor = Color3.fromRGB(178, 178, 184)
C.OffColor = Color3.fromRGB(156, 156, 160)
C.KnobOff = Color3.fromRGB(255, 255, 255)
C.Font = Font.fromEnum(Enum.Font.Gotham)

local FAMILY = "rbxasset://fonts/families/GothamSSm.json"
local F_REG = Font.new(FAMILY, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local F_MED = Font.new(FAMILY, Enum.FontWeight.Medium, Enum.FontStyle.Normal)
local F_BOLD = Font.new(FAMILY, Enum.FontWeight.Bold, Enum.FontStyle.Normal)

local ALIGN_L, ALIGN_R, ALIGN_C = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right, Enum.TextXAlignment.Center
local INPUT_M1, INPUT_M2, INPUT_M3 = Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3
local INPUT_TOUCH, INPUT_KB, INPUT_MOVE = Enum.UserInputType.Touch, Enum.UserInputType.Keyboard, Enum.UserInputType.MouseMovement

-- ---------- helpers ----------
local GLASS_ALPHA = { Background = 0.3, Sidebar = 0.55, Main = 0.88, Row = 0.8, Outline = 0.8 }
local function glassAlphaFor(col)
    if col == C.BackgroundColor then return GLASS_ALPHA.Background
    elseif col == C.SidebarColor then return GLASS_ALPHA.Sidebar
    elseif col == C.MainColor then return GLASS_ALPHA.Main
    elseif col == C.RowColor then return GLASS_ALPHA.Row
    elseif col == C.OutlineColor then return GLASS_ALPHA.Outline
    elseif col == C.PopupColor then return 0.16 end
end

local function create(class, props)
    if props and props.BackgroundColor3 and props.BackgroundTransparency == nil and class ~= "TextBox" then
        local a = glassAlphaFor(props.BackgroundColor3)
        if a then props.BackgroundTransparency = a end
    end
    local o = Instance.new(class)
    local okGui = pcall(function() return o:IsA("GuiObject") end)
    if okGui and o:IsA("GuiObject") then o.BorderSizePixel = 0 end
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else o[k] = v end
    end
    if parent then o.Parent = parent end
    return o
end

local function newText(props)
    local cls = props.Class or "TextLabel"
    props.Class = nil
    props.BackgroundTransparency = 1
    props.FontFace = props.FontFace or F_MED
    props.TextSize = props.TextSize or 13
    props.TextColor3 = props.TextColor3 or C.FontColor
    props.RichText = true
    props.TextXAlignment = props.TextXAlignment or ALIGN_L
    props.Text = props.Text or ""
    return create(cls, props)
end

local function addCorner(parent, delta, fixed)
    local r = fixed or math.max(0, Library.CornerRadius + (delta or 0))
    local u = create("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
    if not fixed then table.insert(Library.CornerObjects, { u, delta or 0 }) end
    return u
end

local function addStroke(parent, color, thickness, transparency)
    local s = create("UIStroke", {
        Color = color or C.OutlineColor, Thickness = thickness or 1, Transparency = transparency or 0.72,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
    })
    create("UIGradient", {
        Rotation = 45,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.82),
            NumberSequenceKeypoint.new(0.55, 0.82), NumberSequenceKeypoint.new(1, 0.25),
        }),
        Parent = s,
    })
    return s
end

local function addPadding(parent, l, r, t, b)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0), Parent = parent,
    })
end

local function addList(parent, dir, pad, ha, va)
    return create("UIListLayout", {
        FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, pad or 0),
        HorizontalAlignment = ha or Enum.HorizontalAlignment.Left,
        VerticalAlignment = va or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder, Parent = parent,
    })
end

local function tw(inst, props, t, style, dir)
    local ok, tween = pcall(function()
        return TweenService:Create(inst, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    end)
    if ok and tween then tween:Play() return tween end
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[KirpichUI] callback error: " .. tostring(err)) end
end

local function stripRich(s)
    return (tostring(s or ""):gsub("<[^>]+>", ""))
end

local function roundTo(v, dec)
    dec = tonumber(dec) or 0
    if dec <= 0 then return math.floor(v + 0.5) end
    local m = 10 ^ dec
    return math.floor(v * m + 0.5) / m
end

local function fmtNum(v, dec)
    dec = tonumber(dec) or 0
    if dec > 0 then return string.format("%." .. dec .. "f", v) end
    return tostring(math.floor(v + 0.5))
end

local function inputIsPress(i)
    return i.UserInputType == INPUT_M1 or i.UserInputType == INPUT_TOUCH
end

local Sink
Sink = setmetatable({}, {
    __index = function(_, k)
        if k == "Value" then return false end
        return function() return Sink end
    end,
    __call = function() return Sink end,
})

local function guard(name, fn)
    return function(...)
        local res = table.pack(pcall(fn, ...))
        if res[1] then return res[2] end
        warn("[KirpichUI] " .. name .. " failed: " .. tostring(res[2]))
        return Sink
    end
end

local ICONS = {
    house = "⌂", user = "☺", crosshair = "⊕", plane = "✈", eye = "◉", star = "★", settings = "⚙",
}

local function feature(name)
    local f = _G._isAdditionalFeatureEnabled
    if type(f) == "function" then
        local ok, r = pcall(f, name)
        return ok and r and true or false
    end
    return true
end

-- ---------- core ----------
function Library:GiveSignal(conn)
    table.insert(self.Signals, conn)
    return conn
end

function Library:OnUnload(fn)
    table.insert(self.UnloadCallbacks, fn)
end

function Library:RegisterAccent(fn)
    table.insert(self.AccentUpdaters, fn)
    pcall(fn, self.Scheme.AccentColor)
end

function Library:SetAccent(color)
    self.Scheme.AccentColor = color
    for _, fn in ipairs(self.AccentUpdaters) do pcall(fn, color) end
end

function Library:SetCornerRadius(n)
    n = tonumber(n) or 10
    self.CornerRadius = n
    for i = #self.CornerObjects, 1, -1 do
        local e = self.CornerObjects[i]
        if e[1] and e[1].Parent then
            e[1].CornerRadius = UDim.new(0, math.max(0, n + e[2]))
        else
            table.remove(self.CornerObjects, i)
        end
    end
end
env.KirpichApplyCorner = function(n) Library:SetCornerRadius(n) end

function Library:GetCustomIcon(id)
    if tonumber(id) then
        return { Url = string.format("rbxthumb://type=Asset&id=%.0f&w=150&h=150", tonumber(id)), ImageRectOffset = Vector2.zero, ImageRectSize = Vector2.zero }
    end
    return nil
end

local function iconUrl(id)
    if id == nil then return nil end
    if tonumber(id) then return string.format("rbxthumb://type=Asset&id=%.0f&w=150&h=150", tonumber(id)) end
    if type(id) == "string" and (id:find("rbxasset") or id:find("rbxthumb") or id:find("http")) then return id end
    return nil
end

-- ---------- gui root ----------
local ScreenGui = create("ScreenGui", {
    Name = "KirpichUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999, IgnoreGuiInset = true,
})
do
    local ok = pcall(function()
        if gethui then
            ScreenGui.Parent = gethui()
        else
            if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end
            ScreenGui.Parent = game:GetService("CoreGui")
        end
    end)
    if not ok or not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end
Library.ScreenGui = ScreenGui

local PopupBackdrop = create("TextButton", {
    Name = "PopupBackdrop", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 50, Parent = ScreenGui,
})
local PopupHolder = create("Frame", {
    Name = "PopupHolder", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 51, Parent = ScreenGui,
})
Library.PopupHolder = PopupHolder

local NotifHolder = create("Frame", {
    Name = "Notifications", BackgroundTransparency = 1, Size = UDim2.new(0, 270, 1, -28),
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), ZIndex = 60, Parent = ScreenGui,
})
addList(NotifHolder, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)

function Library:ClosePopup()
    local p = self._popup
    self._popup = nil
    if p then
        pcall(function() p.Frame:Destroy() end)
        if p.OnClose then pcall(p.OnClose) end
    end
    PopupBackdrop.Visible = false
end
PopupBackdrop.Activated:Connect(function() Library:ClosePopup() end)

function Library:SetGlassBlur(size, enabled)
    if size ~= nil then self.GlassBlurSize = tonumber(size) or 14 end
    if enabled ~= nil then self.GlassBlurOn = enabled and true or false end
    if self._applyBlur then self:_applyBlur() end
end

function Library:SetDPIScale(n)
    n = tonumber(n) or 100
    if n > 10 then n = n / 100 end
    self.DPIScale = n
    if self._dpi then self._dpi.Scale = n end
    self:ClosePopup()
end

-- global drag handling (one drag at a time)
function Library:StartDrag(fn, onEnd)
    self._dragFn = fn
    self._dragEnd = onEnd
end
Library:GiveSignal(UIS.InputChanged:Connect(function(input)
    if Library._dragFn and (input.UserInputType == INPUT_MOVE or input.UserInputType == INPUT_TOUCH) then
        Library._dragFn(Vector2.new(input.Position.X, input.Position.Y))
    end
end))
Library:GiveSignal(UIS.InputEnded:Connect(function(input)
    if Library._dragFn and inputIsPress(input) then
        local e = Library._dragEnd
        Library._dragFn, Library._dragEnd = nil, nil
        if e then pcall(e) end
    end
end))

function Library:MakeDraggable(frame, handle, ignoreToggled)
    handle.InputBegan:Connect(function(input)
        if not inputIsPress(input) then return end
        if not ignoreToggled and not Library.Toggled then return end
        local startMouse = Vector2.new(input.Position.X, input.Position.Y)
        local startPos = frame.Position
        Library:StartDrag(function(p)
            local d = p - startMouse
            local target = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            if _G.SmoothMenuDrag then tw(frame, { Position = target }, 0.08) else frame.Position = target end
        end)
    end)
end

function Library:Unload()
    if self.Unloaded then return end
    self.Unloaded = true
    for _, fn in ipairs(self.UnloadCallbacks) do pcall(fn) end
    for _, c in ipairs(self.Signals) do pcall(function() c:Disconnect() end) end
    pcall(function() self.ScreenGui:Destroy() end)
    if env.KirpichUILib == self then env.KirpichUILib = nil end
end

-- ---------- notifications ----------
function Library:Notify(info, time2)
    if type(info) ~= "table" then info = { Description = tostring(info), Time = time2 } end
    local dur = tonumber(info.Time) or 5
    local wrap = create("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Parent = NotifHolder })
    local card = create("Frame", {
        BackgroundColor3 = C.PopupColor, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(1.3, 0, 0, 0), Parent = wrap,
    })
    addCorner(card, -2)
    addStroke(card, C.OutlineColor)
    addPadding(card, 12, 12, 9, 12)
    addList(card, Enum.FillDirection.Vertical, 2)
    local hasTitle = info.Title and tostring(info.Title) ~= ""
    if hasTitle then
        newText({ Text = tostring(info.Title), FontFace = F_BOLD, TextSize = 13, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true, LayoutOrder = 1, Parent = card })
    end
    if info.Description and tostring(info.Description) ~= "" then
        newText({ Text = tostring(info.Description), TextSize = 12, TextColor3 = C.DimColor, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextWrapped = true, LayoutOrder = 2, Parent = card })
    end
    local bar = create("Frame", { BackgroundColor3 = C.AccentColor, BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), Parent = card })
    Library:RegisterAccent(function(col) bar.BackgroundColor3 = col end)
    tw(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.25, Enum.EasingStyle.Quart)
    tw(bar, { Size = UDim2.new(0, 0, 0, 2) }, dur, Enum.EasingStyle.Linear)
    task.delay(dur, function()
        if not card.Parent then return end
        local t = tw(card, { Position = UDim2.new(1.3, 0, 0, 0) }, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        task.delay(0.3, function() pcall(function() wrap:Destroy() end) end)
    end)
end

-- ---------- popups ----------
local function placePopup(popup, anchor, w, h, alignRight)
    local s = Library.DPIScale
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local aPos, aSize = anchor.AbsolutePosition, anchor.AbsoluteSize
    local x = aPos.X
    if alignRight then x = aPos.X + aSize.X - w * s end
    x = math.max(4, math.min(x, vp.X - w * s - 4))
    local y = aPos.Y + aSize.Y + 4
    if y + h * s > vp.Y - 4 then y = math.max(4, aPos.Y - h * s - 4) end
    popup.Position = UDim2.fromOffset(x, y)
end

local function newPopupFrame(w, h)
    local popup = create("Frame", {
        BackgroundColor3 = C.PopupColor, Size = UDim2.fromOffset(w, h), Active = true, ZIndex = 52, Parent = PopupHolder,
    })
    create("UIScale", { Scale = Library.DPIScale, Parent = popup })
    addCorner(popup, -2)
    addStroke(popup, C.OutlineColor)
    return popup
end

function Library:OpenList(anchor, spec)
    self:ClosePopup()
    local s = self.DPIScale
    local vals = spec.Values or {}
    local rowH = 26
    local searchH = spec.Searchable and 30 or 0
    local contentH = math.min(190, math.max(1, #vals) * rowH + 8)
    local h = contentH + searchH
    local w = math.max(spec.MinWidth or 120, anchor.AbsoluteSize.X / s)
    local popup = newPopupFrame(w, h)
    popup.ClipsDescendants = true
    placePopup(popup, anchor, w, h, spec.AlignRight)
    PopupBackdrop.Visible = true
    self._popup = { Frame = popup, OnClose = spec.OnClose }

    local query = ""
    local list = create("ScrollingFrame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, searchH), Size = UDim2.new(1, 0, 1, -searchH),
        ScrollBarThickness = 2, ScrollBarImageColor3 = C.DimColor, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = popup,
    })
    addPadding(list, 4, 4, 4, 4)
    addList(list, Enum.FillDirection.Vertical, 0)

    local function render()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local n = 0
        for _, v in ipairs(vals) do
            local name = tostring(v)
            if query == "" or name:lower():find(query, 1, true) then
                n = n + 1
                local sel = spec.IsSelected and spec.IsSelected(v) or false
                local b = create("TextButton", {
                    BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, rowH), Text = "", LayoutOrder = n, Parent = list,
                })
                addCorner(b, -6)
                newText({ Text = name, TextSize = 12, TextColor3 = sel and Color3.new(1, 1, 1) or C.DimColor, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -28, 1, 0), Position = UDim2.new(0, 8, 0, 0), Parent = b })
                if sel then
                    local dot = create("Frame", { BackgroundColor3 = C.AccentColor, Size = UDim2.fromOffset(6, 6), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0), Parent = b })
                    addCorner(dot, nil, 3)
                end
                b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.88 end)
                b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
                b.Activated:Connect(function()
                    safeCall(spec.OnPick, v)
                    if spec.KeepOpen then render() else Library:ClosePopup() end
                end)
            end
        end
    end
    if spec.Searchable then
        local box = newText({
            Class = "TextBox", Text = "", PlaceholderText = "Search...", PlaceholderColor3 = C.DimColor, ClearTextOnFocus = false,
            TextSize = 12, BackgroundTransparency = GLASS_ALPHA.Row, BackgroundColor3 = C.RowColor, Size = UDim2.new(1, -12, 0, 22),
            Position = UDim2.new(0, 6, 0, 5), Parent = popup,
        })
        box.BackgroundTransparency = GLASS_ALPHA.Row
        addCorner(box, -6)
        addPadding(box, 8, 8, 0, 0)
        box:GetPropertyChangedSignal("Text"):Connect(function()
            query = box.Text:lower()
            render()
        end)
    end
    render()
end

function Library:ShowInfoPopup(anchor, lines, alignRight)
    self:ClosePopup()
    local w = 200
    local h = math.max(1, #lines) * 22 + 14
    local popup = newPopupFrame(w, h)
    placePopup(popup, anchor, w, h, alignRight)
    PopupBackdrop.Visible = true
    self._popup = { Frame = popup }
    addPadding(popup, 10, 10, 7, 7)
    addList(popup, Enum.FillDirection.Vertical, 0)
    if #lines == 0 then lines = { { "Nothing here yet", "" } } end
    for i, ln in ipairs(lines) do
        local row = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i, Parent = popup })
        newText({ Text = ln[1], TextSize = 12, Size = UDim2.new(0.65, 0, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
        newText({ Text = ln[2], TextSize = 12, TextColor3 = C.AccentColor, TextXAlignment = ALIGN_R, Size = UDim2.new(0.35, 0, 1, 0), Position = UDim2.new(0.65, 0, 0, 0), Parent = row })
    end
end

-- ---------- color picker popup ----------
local function rainbowSequence()
    local pts = {}
    for i = 0, 6 do pts[#pts + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(math.min(i / 6, 0.999), 1, 1)) end
    return ColorSequence.new(pts)
end

local function openColorPicker(CP, anchor)
    Library:ClosePopup()
    local hasAlpha = CP.Transparency ~= nil
    local w, h = 196, 168 + (hasAlpha and 18 or 0) + 30
    local popup = newPopupFrame(w, h)
    placePopup(popup, anchor, w, h, true)
    PopupBackdrop.Visible = true
    Library._popup = { Frame = popup }
    popup.ClipsDescendants = false

    newText({ Text = stripRich(CP.Title or "Color"), FontFace = F_BOLD, TextSize = 12, Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 0, 8), Parent = popup })

    local sv = create("Frame", { BackgroundColor3 = Color3.fromHSV(CP.Hue, 1, 1), Size = UDim2.new(1, -20, 0, 100), Position = UDim2.new(0, 10, 0, 30), ClipsDescendants = true, Active = true, Parent = popup })
    addCorner(sv, nil, 6)
    local white = create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = sv })
    create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = white })
    local black = create("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), Parent = sv })
    create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), Parent = black })
    local svCur = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), Parent = sv })
    addCorner(svCur, nil, 5)
    create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = svCur })

    local hue = create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -20, 0, 10), Position = UDim2.new(0, 10, 0, 138), Active = true, Parent = popup })
    addCorner(hue, nil, 5)
    create("UIGradient", { Color = rainbowSequence(), Parent = hue })
    local hueCur = create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(4, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(CP.Hue, 0, 0.5, 0), Parent = hue })
    addCorner(hueCur, nil, 2)

    local alphaBar, alphaCur
    local yHex = 160
    if hasAlpha then
        alphaBar = create("Frame", { BackgroundColor3 = CP.Value, Size = UDim2.new(1, -20, 0, 10), Position = UDim2.new(0, 10, 0, 158), Active = true, Parent = popup })
        addCorner(alphaBar, nil, 5)
        create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.9) }), Parent = alphaBar })
        alphaCur = create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(4, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1 - CP.Transparency, 0, 0.5, 0), Parent = alphaBar })
        addCorner(alphaCur, nil, 2)
        yHex = 178
    end

    local hex = newText({
        Class = "TextBox", Text = "#" .. CP.Value:ToHex(), TextSize = 12, ClearTextOnFocus = false, BackgroundTransparency = GLASS_ALPHA.Row,
        BackgroundColor3 = C.RowColor, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.new(0, 10, 0, yHex), TextXAlignment = ALIGN_C, Parent = popup,
    })
    hex.BackgroundTransparency = GLASS_ALPHA.Row
    addCorner(hex, -6)

    local function refresh()
        sv.BackgroundColor3 = Color3.fromHSV(CP.Hue, 1, 1)
        svCur.Position = UDim2.new(CP.Sat, 0, 1 - CP.Vib, 0)
        hueCur.Position = UDim2.new(CP.Hue, 0, 0.5, 0)
        if alphaBar then alphaBar.BackgroundColor3 = CP.Value; alphaCur.Position = UDim2.new(1 - CP.Transparency, 0, 0.5, 0) end
        hex.Text = "#" .. CP.Value:ToHex()
    end
    refresh()

    local function bind(frame, fn)
        frame.InputBegan:Connect(function(input)
            if not inputIsPress(input) then return end
            local function upd(p)
                local ax, ay = frame.AbsolutePosition.X, frame.AbsolutePosition.Y
                local aw, ah = math.max(1, frame.AbsoluteSize.X), math.max(1, frame.AbsoluteSize.Y)
                fn(math.clamp((p.X - ax) / aw, 0, 1), math.clamp((p.Y - ay) / ah, 0, 1))
                refresh()
            end
            upd(Vector2.new(input.Position.X, input.Position.Y))
            Library:StartDrag(upd)
        end)
    end
    bind(sv, function(x, y) CP.Sat, CP.Vib = x, 1 - y; CP:_Set() end)
    bind(hue, function(x) CP.Hue = x; CP:_Set() end)
    if alphaBar then bind(alphaBar, function(x) CP.Transparency = 1 - x; CP:_Set() end) end
    hex.FocusLost:Connect(function()
        local ok, col = pcall(function() return Color3.fromHex(hex.Text) end)
        if ok and col then CP:SetValueRGB(col); refresh() else hex.Text = "#" .. CP.Value:ToHex() end
    end)
end

-- ---------- element builders ----------
local function newRow(ctx, height)
    ctx.n = ctx.n + 1
    local row = create("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or 34), LayoutOrder = ctx.n, Parent = ctx.Parent })
    create("Frame", { Name = "Sep", BackgroundColor3 = C.OutlineColor, BackgroundTransparency = 0.9, Size = UDim2.new(1, -20, 0, 1), Position = UDim2.new(0, 10, 1, -1), Parent = row })
    return row
end

local function newRight(row)
    local right = create("Frame", {
        Name = "Right", BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Parent = row,
    })
    addList(right, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    return right
end

local function rowLabel(row, text, right)
    local lbl = newText({
        Text = text or "", TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.new(0, 10, 0, 0), Parent = row,
    })
    if right then
        local function upd() lbl.Size = UDim2.new(1, -(right.AbsoluteSize.X + 24), 1, 0) end
        right:GetPropertyChangedSignal("AbsoluteSize"):Connect(upd)
        upd()
    end
    return lbl
end

local function register(ctx, El, row, text)
    El.Row = row
    El._visible, El._match = true, true
    El.SearchText = stripRich(text or ""):lower()
    table.insert(ctx.Tab.Elements, El)
    El.Group = ctx.Group
    function El:_Apply() row.Visible = self._visible and self._match end
    function El:SetVisible(v) self._visible = v and true or false; self:_Apply() end
    function El:SetDisabled(v) self.Disabled = v and true or false end
    return El
end

local function fire(obj, ...)
    safeCall(obj.Callback, ...)
    for _, fn in ipairs(obj.Changed) do safeCall(fn, ...) end
end

local function attachAddons(El, right, ctx)
    El._addon = 0
    function El:AddColorPicker(idx, info)
        info = info or {}
        local CP = { Type = "ColorPicker", Idx = idx, Title = info.Title or info.Text or "Color", Callback = info.Callback, Changed = {}, Transparency = info.Transparency }
        local default = info.Default or Color3.new(1, 1, 1)
        CP.Hue, CP.Sat, CP.Vib = default:ToHSV()
        CP.Value = default
        El._addon = El._addon + 1
        local sw = create("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = default, Size = UDim2.fromOffset(26, 14), LayoutOrder = El._addon, Parent = right })
        addCorner(sw, nil, 4)
        addStroke(sw, C.OutlineColor)
        function CP:_Set()
            self.Value = Color3.fromHSV(self.Hue, self.Sat, self.Vib)
            sw.BackgroundColor3 = self.Value
            fire(self, self.Value, self.Transparency)
        end
        function CP:SetValueRGB(c, t)
            self.Hue, self.Sat, self.Vib = c:ToHSV()
            if t ~= nil then self.Transparency = t end
            self:_Set()
        end
        function CP:SetValue(v, t)
            if typeof(v) == "Color3" then return self:SetValueRGB(v, t) end
            if type(v) == "table" then
                self.Hue, self.Sat, self.Vib = v[1] or v.h or self.Hue, v[2] or v.s or self.Sat, v[3] or v.v or self.Vib
                if t ~= nil then self.Transparency = t end
                self:_Set()
            end
        end
        function CP:OnChanged(fn) table.insert(self.Changed, fn); return self end
        function CP:SetVisible(v) sw.Visible = v and true or false end
        sw.Activated:Connect(function() openColorPicker(CP, sw) end)
        if idx then Library.Options[idx] = CP end
        return El
    end
    function El:AddKeyPicker(idx, info)
        info = info or {}
        local KP = { Type = "KeyPicker", Idx = idx, Mode = info.Mode or "Toggle", Callback = info.Callback, ChangedCallback = info.ChangedCallback, Changed = {}, Clicked = {}, Toggled = false, Holding = false, NoUI = info.NoUI, Text = info.Text }
        local function norm(k)
            if typeof(k) == "EnumItem" then return k.Name end
            if k == nil or k == "" then return "None" end
            return tostring(k)
        end
        KP.Value = norm(info.Default)
        El._addon = El._addon + 1
        local btn = create("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.RowColor, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), LayoutOrder = El._addon, Parent = right })
        addCorner(btn, -6)
        addStroke(btn, C.OutlineColor)
        local txt = newText({ Text = KP.Value, TextSize = 11, TextColor3 = C.DimColor, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), TextXAlignment = ALIGN_C, Parent = btn })
        addPadding(btn, 8, 8, 0, 0)
        local listening = false
        local function disp() txt.Text = listening and "..." or KP.Value; txt.TextColor3 = listening and C.AccentColor or C.DimColor end
        function KP:GetState()
            if self.Mode == "Always" then return true end
            if self.Mode == "Hold" then return self.Holding end
            return self.Toggled
        end
        function KP:SetValue(data)
            if type(data) == "table" then
                if data[1] ~= nil then self.Value = norm(data[1]) end
                if data[2] then self.Mode = data[2] end
            else
                self.Value = norm(data)
            end
            disp()
            safeCall(self.ChangedCallback, (Enum.KeyCode[self.Value] or self.Value))
            for _, fn in ipairs(self.Changed) do safeCall(fn, self.Value) end
        end
        function KP:OnChanged(fn) table.insert(self.Changed, fn); return self end
        function KP:OnClick(fn) table.insert(self.Clicked, fn); return self end
        function KP:SetVisible(v) btn.Visible = v and true or false end
        btn.Activated:Connect(function()
            listening = true
            disp()
        end)
        local function nameOf(input)
            if input.UserInputType == INPUT_KB then return input.KeyCode.Name end
            if input.UserInputType == INPUT_M1 then return "MB1" end
            if input.UserInputType == INPUT_M2 then return "MB2" end
            if input.UserInputType == INPUT_M3 then return "MB3" end
            return nil
        end
        Library:GiveSignal(UIS.InputBegan:Connect(function(input)
            local n = nameOf(input)
            if not n then return end
            if listening then
                if input.UserInputType == INPUT_M1 then return end
                listening = false
                KP:SetValue(n == "Escape" and "None" or n)
                return
            end
            if UIS:GetFocusedTextBox() or KP.Value == "None" or KP.Value ~= n then return end
            if KP.Mode == "Toggle" then KP.Toggled = not KP.Toggled; fire(KP, KP:GetState())
            elseif KP.Mode == "Hold" then KP.Holding = true; fire(KP, true)
            else fire(KP, KP:GetState()) end
            for _, fn in ipairs(KP.Clicked) do safeCall(fn) end
        end))
        Library:GiveSignal(UIS.InputEnded:Connect(function(input)
            local n = nameOf(input)
            if n and KP.Mode == "Hold" and KP.Holding and KP.Value == n then
                KP.Holding = false
                fire(KP, false)
            end
        end))
        if idx then Library.Options[idx] = KP end
        table.insert(Library.Keybinds, KP)
        KP.Label = info.Text
        return El
    end
end

local function attachElements(obj, ctx)
    -- Toggle / Checkbox
    local function addToggle(self, idx, info)
        info = info or {}
        local row = newRow(ctx, 34)
        local right = newRight(row)
        local lbl = rowLabel(row, info.Text, right)
        local track = create("Frame", { BackgroundColor3 = C.OffColor, BackgroundTransparency = 0.55, Size = UDim2.fromOffset(42, 24), LayoutOrder = 100, Parent = right })
        addCorner(track, nil, 12)
        addStroke(track, C.OutlineColor, 1, 0.8)
        local knob = create("Frame", { BackgroundColor3 = C.KnobOff, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0, 2, 0.5, -10), Parent = track })
        addCorner(knob, nil, 10)
        create("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.85, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = knob })
        local hit = create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = row })
        right.ZIndex = 3
        local T = { Type = "Toggle", Idx = idx, Value = info.Default and true or false, Text = info.Text, Callback = info.Callback, Changed = {}, Addons = {} }
        local function disp(anim)
            local on = T.Value
            local tcol = on and C.AccentColor or C.OffColor
            local talpha = on and 0.08 or 0.55
            local kcol = Color3.new(1, 1, 1)
            local kpos = on and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
            if anim then
                tw(track, { BackgroundColor3 = tcol, BackgroundTransparency = talpha }, 0.28, Enum.EasingStyle.Quint)
                tw(knob, { BackgroundColor3 = kcol, Position = kpos }, 0.28, Enum.EasingStyle.Back)
            else
                track.BackgroundColor3, track.BackgroundTransparency, knob.BackgroundColor3, knob.Position = tcol, talpha, kcol, kpos
            end
        end
        disp(false)
        Library:RegisterAccent(function(col) if T.Value then track.BackgroundColor3 = col end end)
        register(ctx, T, row, info.Text)
        attachAddons(T, right, ctx)
        function T:SetValue(v) self.Value = v and true or false; disp(true); fire(self, self.Value) end
        function T:OnChanged(fn) table.insert(self.Changed, fn); return self end
        function T:SetText(t) self.Text = t; lbl.Text = t; self.SearchText = stripRich(t):lower() end
        hit.Activated:Connect(function() if not T.Disabled then T:SetValue(not T.Value) end end)
        if idx then Library.Toggles[idx] = T end
        return T
    end
    obj.AddToggle = guard("AddToggle", addToggle)
    obj.AddCheckbox = guard("AddCheckbox", addToggle)

    -- Label
    obj.AddLabel = guard("AddLabel", function(self, a, b, c)
        local info, idx = {}, nil
        if type(a) == "table" then info = a
        elseif type(b) == "table" then idx, info = a, b
        else info = { Text = a, DoesWrap = b } end
        local wrapT = info.DoesWrap
        local row = newRow(ctx, 30)
        local right = newRight(row)
        local lbl
        if wrapT then
            row.AutomaticSize = Enum.AutomaticSize.Y
            row.Size = UDim2.new(1, 0, 0, 30)
            lbl = newText({ Text = info.Text or "", TextSize = 13, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -24, 0, 0), Position = UDim2.new(0, 10, 0, 0), Parent = row })
            addPadding(row, 0, 0, 7, 9)
            right.Visible = false
        else
            lbl = rowLabel(row, info.Text, right)
        end
        local L = { Type = "Label", Idx = idx, Text = info.Text or "", TextLabel = lbl }
        register(ctx, L, row, info.Text)
        attachAddons(L, right, ctx)
        function L:SetText(t) self.Text = tostring(t); lbl.Text = tostring(t); self.SearchText = stripRich(t):lower() end
        if idx then Library.Labels = Library.Labels or {}; Library.Labels[idx] = L end
        return L
    end)

    -- Divider
    obj.AddDivider = guard("AddDivider", function(self, a)
        local text = type(a) == "table" and a.Text or a
        local row = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, text and 22 or 12), Parent = ctx.Parent })
        ctx.n = ctx.n + 1
        row.LayoutOrder = ctx.n
        local line = create("Frame", { BackgroundColor3 = C.OutlineColor, Size = UDim2.new(1, -20, 0, 1), Position = UDim2.new(0, 10, 0.5, 0), Parent = row })
        if text and tostring(text) ~= "" then
            line.Visible = false
            newText({ Text = tostring(text):upper(), TextSize = 10, FontFace = F_BOLD, TextColor3 = C.DimColor, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0), Parent = row })
        end
        local D = { Type = "Divider", Row = row, _visible = true, _match = true, SearchText = "" }
        table.insert(ctx.Tab.Elements, D)
        function D:_Apply() row.Visible = self._visible and (self._match or ctx.Tab.Window.Query == "") end
        function D:SetVisible(v) self._visible = v and true or false; self:_Apply() end
        return D
    end)

    -- Image (banner / picture / page art, works in any groupbox, dependency box or directly on a tab)
    local imgCache = {}
    local function resolveImage(src)
        if src == nil then return "" end
        if tonumber(src) then return string.format("rbxassetid://%.0f", tonumber(src)) end
        if type(src) ~= "string" then return "" end
        if src:find("^rbxassetid") or src:find("^rbxthumb") or src:find("^rbxasset") or src:find("^rbxgameasset") then return src end
        return nil
    end
    local function loadRemoteImage(url, apply)
        if imgCache[url] then apply(imgCache[url]) return end
        if type(request) ~= "function" or type(writefile) ~= "function" or type(getcustomasset) ~= "function" then return end
        task.spawn(function()
            local ok, res = pcall(request, { Url = url, Method = "GET" })
            if not ok or type(res) ~= "table" or not res.Success or type(res.Body) ~= "string" or #res.Body == 0 then return end
            local sum = 0
            for i = 1, #url do sum = (sum * 31 + url:byte(i)) % 1000000007 end
            local ext = url:match("%.(%w+)[%?#]?[^/]*$")
            if not ext or #ext > 4 then ext = "png" end
            local dir = "Kirpich/images"
            pcall(function()
                if type(isfolder) == "function" and type(makefolder) == "function" then
                    if not isfolder("Kirpich") then makefolder("Kirpich") end
                    if not isfolder(dir) then makefolder(dir) end
                end
            end)
            local path = dir .. "/img_" .. sum .. "." .. ext
            local okW = pcall(writefile, path, res.Body)
            if not okW then return end
            local okA, asset = pcall(getcustomasset, path)
            if okA and asset then
                imgCache[url] = asset
                apply(asset)
            end
        end)
    end
    local SCALE = { Crop = Enum.ScaleType.Crop, Fit = Enum.ScaleType.Fit, Stretch = Enum.ScaleType.Stretch, Tile = Enum.ScaleType.Tile }
    obj.AddImage = guard("AddImage", function(self, a, b)
        local info = type(a) == "table" and a or { Image = a, Height = tonumber(b) }
        local height = math.max(8, tonumber(info.Height) or 120)
        local inset = tonumber(info.Inset)
        if inset == nil then inset = 10 end
        local capH = (info.Caption and tostring(info.Caption) ~= "") and 22 or 0
        local row = newRow(ctx, height + capH + 12)
        local img = create("ImageLabel", {
            Name = "Picture", BackgroundColor3 = C.RowColor, Image = "", ScaleType = SCALE[info.ScaleType or "Crop"] or Enum.ScaleType.Crop,
            ImageTransparency = tonumber(info.ImageTransparency) or 0,
            Size = UDim2.new(1, -inset * 2, 0, height), Position = UDim2.fromOffset(inset, 6), Parent = row,
        })
        addCorner(img, nil, tonumber(info.Corner) or 12)
        addStroke(img, C.OutlineColor, 1, 0.65)
        local cap = newText({
            Text = info.Caption and tostring(info.Caption) or "", TextSize = 11, TextColor3 = C.DimColor, TextTruncate = Enum.TextTruncate.AtEnd,
            Size = UDim2.new(1, -inset * 2, 0, 18), Position = UDim2.new(0, inset, 0, height + 8), Visible = capH > 0, Parent = row,
        })
        local I = { Type = "Image", Image = info.Image, Caption = info.Caption, Height = height, Func = info.Func or info.Callback, Picture = img }
        local token = 0
        function I:SetImage(src)
            self.Image = src
            token = token + 1
            local mine = token
            local r = resolveImage(src)
            if r ~= nil then img.Image = r return end
            img.Image = ""
            loadRemoteImage(tostring(src), function(asset)
                if mine == token and img.Parent then img.Image = asset end
            end)
        end
        function I:SetCaption(t)
            self.Caption = t
            cap.Text = t and tostring(t) or ""
            cap.Visible = cap.Text ~= ""
            self.SearchText = stripRich(cap.Text):lower()
        end
        function I:SetHeight(h)
            h = math.max(8, tonumber(h) or height)
            height = h
            self.Height = h
            img.Size = UDim2.new(1, -inset * 2, 0, h)
            cap.Position = UDim2.new(0, inset, 0, h + 8)
            row.Size = UDim2.new(1, 0, 0, h + (cap.Visible and 22 or 0) + 12)
        end
        if I.Func then
            local hit = create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = img.ZIndex + 1, Parent = img })
            hit.Activated:Connect(function() safeCall(I.Func) end)
        end
        register(ctx, I, row, info.Caption or "")
        I:SetImage(info.Image)
        return I
    end)

    -- Button
    local function buildButton(info, row, holder, S)
        local btn = create("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundColor3 = C.RowColor, Size = S.Size, Position = S.Position, Parent = holder,
        })
        addCorner(btn, nil, 13)
        addStroke(btn, C.OutlineColor)
        local lbl = newText({ Text = info.Text or "Button", TextSize = 13, TextXAlignment = ALIGN_C, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.fromScale(1, 1), Parent = btn })
        btn.MouseEnter:Connect(function() tw(btn, { BackgroundTransparency = 0.74 }, 0.18) end)
        btn.MouseLeave:Connect(function() tw(btn, { BackgroundTransparency = GLASS_ALPHA.Row }, 0.22) end)
        local B = { Type = "Button", Text = info.Text, Func = info.Func or info.Callback, Button = btn }
        btn.Activated:Connect(function()
            if B.Disabled then return end
            safeCall(B.Func)
        end)
        function B:SetText(t) self.Text = t; lbl.Text = t end
        function B:SetVisible(v) btn.Visible = v and true or false end
        function B:SetDisabled(v) self.Disabled = v and true or false; lbl.TextTransparency = v and 0.5 or 0 end
        return B
    end
    obj.AddButton = guard("AddButton", function(self, a, b)
        local info = type(a) == "table" and a or { Text = a, Func = b }
        local row = newRow(ctx, 38)
        local holder = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0.5, -13), Parent = row })
        addList(holder, Enum.FillDirection.Horizontal, 6)
        local B = buildButton(info, row, holder, { Size = UDim2.fromScale(1, 1), Position = UDim2.new() })
        register(ctx, B, row, info.Text)
        local count = 1
        function B:AddButton(a2, b2)
            local info2 = type(a2) == "table" and a2 or { Text = a2, Func = b2 }
            count = count + 1
            local scale = 1 / count
            for _, ch in ipairs(holder:GetChildren()) do
                if ch:IsA("TextButton") then ch.Size = UDim2.new(scale, -(6 * (count - 1) / count), 1, 0) end
            end
            local B2 = buildButton(info2, row, holder, { Size = UDim2.new(scale, -(6 * (count - 1) / count), 1, 0), Position = UDim2.new() })
            return B2
        end
        return B
    end)

    -- Slider
    obj.AddSlider = guard("AddSlider", function(self, idx, info)
        info = info or {}
        local row = newRow(ctx, 34)
        local mn, mx = tonumber(info.Min) or 0, tonumber(info.Max) or 100
        if mx <= mn then mx = mn + 1 end
        local dec = tonumber(info.Rounding)
        if dec == nil then dec = tonumber(info.Round) or 0 end
        local lbl = newText({ Text = info.Text or "", TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(0.38, -10, 1, 0), Position = UDim2.new(0, 10, 0, 0), Parent = row })
        local valBox = newText({
            Class = "TextBox", Text = "", TextSize = 11, TextColor3 = C.DimColor, ClearTextOnFocus = false, BackgroundTransparency = GLASS_ALPHA.Row,
            BackgroundColor3 = C.RowColor, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(34, 20),
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), TextXAlignment = ALIGN_C, Parent = row,
        })
        valBox.BackgroundTransparency = GLASS_ALPHA.Row
        addCorner(valBox, -6)
        addStroke(valBox, C.OutlineColor)
        addPadding(valBox, 6, 6, 0, 0)
        local track = create("Frame", { BackgroundColor3 = C.OffColor, BackgroundTransparency = 0.55, Size = UDim2.new(0.62, -60, 0, 6), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.38, 0, 0.5, 0), Parent = row })
        addCorner(track, nil, 3)
        local fill = create("Frame", { BackgroundColor3 = C.AccentColor, Size = UDim2.fromScale(0, 1), Parent = track })
        addCorner(fill, nil, 3)
        local knob = create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Parent = track })
        addCorner(knob, nil, 8)
        create("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.85, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = knob })
        local hit = create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 14, 0, 26), Position = UDim2.new(0, -7, 0.5, -13), Parent = track })
        local function fitTrack()
            track.Size = UDim2.new(0.62, -(valBox.AbsoluteSize.X + 20), 0, 6)
        end
        valBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTrack)
        Library:RegisterAccent(function(col) fill.BackgroundColor3 = col end)

        local S = { Type = "Slider", Idx = idx, Min = mn, Max = mx, Rounding = dec, Text = info.Text, Callback = info.Callback, Changed = {}, Suffix = info.Suffix or "", Prefix = info.Prefix or "" }
        S.Value = math.clamp(tonumber(info.Default) or mn, mn, mx)
        local function display()
            local a = (S.Value - S.Min) / (S.Max - S.Min)
            fill.Size = UDim2.fromScale(a, 1)
            knob.Position = UDim2.new(a, 0, 0.5, 0)
            local txt
            if type(info.FormatDisplayValue) == "function" then
                local ok, r = pcall(info.FormatDisplayValue, S, S.Value)
                if ok and r ~= nil then txt = tostring(r) end
            end
            valBox.Text = txt or (S.Prefix .. fmtNum(S.Value, S.Rounding) .. S.Suffix)
        end
        display()
        register(ctx, S, row, info.Text)
        function S:SetValue(v)
            v = tonumber(v)
            if not v then return end
            self.Value = roundTo(math.clamp(v, self.Min, self.Max), self.Rounding)
            display()
            fire(self, self.Value)
        end
        function S:SetMin(v) self.Min = v; display() end
        function S:SetMax(v) self.Max = v; display() end
        function S:SetText(t) self.Text = t; lbl.Text = t; self.SearchText = stripRich(t):lower() end
        function S:OnChanged(fn) table.insert(self.Changed, fn); return self end
        hit.InputBegan:Connect(function(input)
            if S.Disabled or not inputIsPress(input) then return end
            local page = ctx.Tab.Page
            if page then page.ScrollingEnabled = false end
            local function upd(p)
                local a = math.clamp((p.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
                local v = roundTo(S.Min + a * (S.Max - S.Min), S.Rounding)
                if v ~= S.Value then S:SetValue(v) end
            end
            upd(Vector2.new(input.Position.X, input.Position.Y))
            Library:StartDrag(upd, function() if page then page.ScrollingEnabled = true end end)
        end)
        valBox.FocusLost:Connect(function()
            local n = tonumber((valBox.Text:gsub("[^%d%.%-]", "")))
            if n then S:SetValue(n) else display() end
        end)
        if idx then Library.Options[idx] = S end
        return S
    end)

    -- Dropdown
    obj.AddDropdown = guard("AddDropdown", function(self, idx, info)
        info = info or {}
        local row = newRow(ctx, 36)
        local hasText = info.Text and tostring(info.Text) ~= ""
        local lbl
        if hasText then
            lbl = newText({ Text = info.Text, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0, 10, 0, 0), Parent = row })
        end
        local btn = create("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundColor3 = C.RowColor, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0), Size = hasText and UDim2.new(0.5, -10, 0, 24) or UDim2.new(1, -20, 0, 24), Parent = row,
        })
        addCorner(btn, -6)
        addStroke(btn, C.OutlineColor)
        local txt = newText({ Text = "", TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -26, 1, 0), Position = UDim2.new(0, 9, 0, 0), Parent = btn })
        newText({ Text = "▼", TextSize = 7, TextColor3 = C.DimColor, TextXAlignment = ALIGN_C, Size = UDim2.fromOffset(16, 24), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 0), Parent = btn })

        local D = { Type = "Dropdown", Idx = idx, Values = info.Values or {}, Multi = info.Multi and true or false, Text = info.Text, Callback = info.Callback, Changed = {}, Searchable = info.Searchable, AllowNull = info.AllowNull }
        if D.Multi then
            D.Value = {}
            local def = info.Default
            if type(def) == "table" then
                for k, v in pairs(def) do
                    if type(k) == "number" then
                        local name = (type(v) == "number" and D.Values[v]) or v
                        if name ~= nil then D.Value[name] = true end
                    elseif v then D.Value[k] = true end
                end
            end
        else
            local def = info.Default
            if type(def) == "number" and D.Values[def] ~= nil then def = D.Values[def] end
            D.Value = def
        end
        local function display()
            if D.Multi then
                local names = {}
                for _, v in ipairs(D.Values) do if D.Value[v] then names[#names + 1] = tostring(v) end end
                txt.Text = #names == 0 and "None" or table.concat(names, ", ")
            else
                txt.Text = D.Value ~= nil and tostring(D.Value) or "None"
            end
            txt.TextColor3 = (txt.Text == "None") and C.DimColor or C.FontColor
        end
        display()
        register(ctx, D, row, info.Text)
        function D:SetValue(v)
            if self.Multi then
                local m = {}
                if type(v) == "table" then
                    for k, val in pairs(v) do
                        if type(k) == "number" then m[val] = true elseif val then m[k] = true end
                    end
                end
                self.Value = m
            else
                if type(v) == "number" and self.Values[v] ~= nil and not table.find(self.Values, v) then v = self.Values[v] end
                self.Value = v
            end
            display()
            fire(self, self.Value)
        end
        function D:SetValues(v) self.Values = v or {}; display() end
        function D:SetText(t) self.Text = t; if lbl then lbl.Text = t end end
        function D:OnChanged(fn) table.insert(self.Changed, fn); return self end
        function D:Refresh() display() end
        btn.Activated:Connect(function()
            if D.Disabled then return end
            Library:OpenList(btn, {
                Values = D.Values, Searchable = D.Searchable or #D.Values > 12, KeepOpen = D.Multi,
                IsSelected = function(v) if D.Multi then return D.Value[v] == true end return D.Value == v end,
                OnPick = function(v)
                    if D.Multi then
                        local m = {}
                        for k, val in pairs(D.Value) do m[k] = val end
                        if m[v] then
                            local count = 0
                            for _ in pairs(m) do count = count + 1 end
                            if count <= 1 and info.AllowNull == false then return end
                            m[v] = nil
                        else
                            m[v] = true
                        end
                        D:SetValue(m)
                    else
                        if D.Value == v and info.AllowNull == true then D:SetValue(nil) else D:SetValue(v) end
                    end
                end,
            })
        end)
        if idx then Library.Options[idx] = D end
        return D
    end)

    -- Input
    obj.AddInput = guard("AddInput", function(self, idx, info)
        info = info or {}
        local row = newRow(ctx, 36)
        local hasText = info.Text and tostring(info.Text) ~= ""
        local lbl
        if hasText then
            lbl = newText({ Text = info.Text, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0, 10, 0, 0), Parent = row })
        end
        local box = newText({
            Class = "TextBox", Text = tostring(info.Default or ""), PlaceholderText = info.Placeholder or "", PlaceholderColor3 = C.DimColor,
            ClearTextOnFocus = false, TextSize = 12, BackgroundTransparency = GLASS_ALPHA.Row, BackgroundColor3 = C.RowColor, AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0), Size = hasText and UDim2.new(0.5, -10, 0, 24) or UDim2.new(1, -20, 0, 24),
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })
        box.BackgroundTransparency = GLASS_ALPHA.Row
        addCorner(box, -6)
        addStroke(box, C.OutlineColor)
        addPadding(box, 9, 9, 0, 0)
        if info.MaxLength then box.MaxVisibleGraphemes = info.MaxLength end
        local I = { Type = "Input", Idx = idx, Value = box.Text, Text = info.Text, Callback = info.Callback, Changed = {}, Numeric = info.Numeric }
        register(ctx, I, row, info.Text)
        function I:SetValue(v) box.Text = tostring(v or ""); self.Value = box.Text; fire(self, self.Value) end
        function I:OnChanged(fn) table.insert(self.Changed, fn); return self end
        function I:SetText(t) self.Text = t; if lbl then lbl.Text = t end end
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if info.Numeric then
                local cleaned = box.Text:gsub("[^%d%.%-]", "")
                if cleaned ~= box.Text then box.Text = cleaned return end
            end
            I.Value = box.Text
            if not info.Finished then fire(I, I.Value) end
        end)
        box.FocusLost:Connect(function(enter)
            I.Value = box.Text
            if info.Finished then fire(I, I.Value) end
        end)
        if idx then Library.Options[idx] = I end
        return I
    end)

    -- Image
    obj.AddImage = guard("AddImage", function(self, idx, info)
        info = info or {}
        local h = tonumber(info.Height) or 100
        local row = newRow(ctx, h + 12)
        local holder = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, h), Position = UDim2.new(0, 10, 0, 6), Parent = row })
        local img = create("ImageLabel", {
            BackgroundTransparency = info.BackgroundTransparency or 1, Size = UDim2.fromScale(1, 1), Image = info.Image or "",
            ScaleType = info.ScaleType or Enum.ScaleType.Fit, ImageColor3 = info.Color or Color3.new(1, 1, 1),
            ImageTransparency = info.Transparency or 0, Parent = holder,
        })
        local M = { Type = "Image", Idx = idx, Holder = holder, Image = info.Image, Destroyed = false }
        register(ctx, M, row, "")
        holder.Destroying:Connect(function() M.Destroyed = true end)
        function M:SetImage(v) self.Image = v; img.Image = v end
        return M
    end)

    -- Dependency box
    obj.AddDependencyBox = guard("AddDependencyBox", function(self)
        ctx.n = ctx.n + 1
        local frame = create("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = ctx.n, Parent = ctx.Parent })
        addList(frame, Enum.FillDirection.Vertical, 0)
        local sub = { Parent = frame, n = 0, Tab = ctx.Tab, Group = ctx.Group }
        local DB = { Type = "DependencyBox", Holder = frame }
        attachElements(DB, sub)
        function DB:SetupDependencies(deps)
            local function check()
                local ok = true
                for _, d in ipairs(deps) do
                    local el, want = d[1], d[2]
                    if el and el.Value ~= want then ok = false break end
                end
                frame.Visible = ok
            end
            for _, d in ipairs(deps) do
                if d[1] and d[1].OnChanged then d[1]:OnChanged(check) end
            end
            check()
        end
        return DB
    end)
end

-- ---------- groupbox / tab ----------
local function createGroupbox(Tab, column, name)
    local G = { Tab = Tab, Name = name }
    Tab._gorder = (Tab._gorder or 0) + 1
    local holder = create("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = Tab._gorder, Parent = column })
    addList(holder, Enum.FillDirection.Vertical, 6)
    if name and tostring(name) ~= "" then
        local gLbl = newText({ Text = stripRich(tostring(name)):upper(), TextSize = 10, FontFace = F_BOLD, TextColor3 = C.DimColor, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = holder })
        addPadding(gLbl, 8, 0, 0, 0)
    end
    local box = create("Frame", { BackgroundColor3 = C.MainColor, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, ClipsDescendants = true, Parent = holder })
    addCorner(box, -2)
    addStroke(box, C.OutlineColor)
    addList(box, Enum.FillDirection.Vertical, 0)
    G.Holder, G.Container = holder, box
    local ctx = { Parent = box, n = 0, Tab = Tab, Group = G }
    G.Ctx = ctx
    attachElements(G, ctx)
    table.insert(Tab.Groupboxes, G)
    return G
end

-- ---------- window ----------
function Library:CreateWindow(cfg)
    cfg = cfg or {}
    local Window = { Tabs = {}, Library = self, Query = "", _order = 0 }
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local reqW = cfg.Size and cfg.Size.X.Offset or 720
    local reqH = cfg.Size and cfg.Size.Y.Offset or 480
    local W = math.max(300, math.min(reqW, vp.X - 20))
    local H = math.max(220, math.min(reqH, vp.Y - 76))
    local compact = W < 560
    local sideW = compact and 54 or 192
    local single = (W - sideW) < 470
    Library.Toggled = cfg.AutoShow ~= false
    if cfg.NotifySide == "Left" then
        NotifHolder.AnchorPoint = Vector2.new(0, 1)
        NotifHolder.Position = UDim2.new(0, 14, 1, -14)
    end

    local Container = create("Frame", {
        Name = "Window", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Visible = Library.Toggled, Parent = ScreenGui,
    })
    local dpi = create("UIScale", { Scale = Library.DPIScale, Parent = Container })
    Library._dpi = dpi

    Library.GlassBlurSize = Library.GlassBlurSize or 14
    if Library.GlassBlurOn == nil then Library.GlassBlurOn = true end
    local okBlur, glassBlur = pcall(function()
        local b = Instance.new("BlurEffect")
        b.Name = "KirpichGlassBlur"
        b.Size = 0
        b.Parent = game:GetService("Lighting")
        return b
    end)
    function Library:_applyBlur()
        if not okBlur or not glassBlur or not glassBlur.Parent then return end
        local target = (Library.Toggled and Library.GlassBlurOn) and Library.GlassBlurSize or 0
        tw(glassBlur, { Size = target }, 0.25)
    end
    table.insert(Library.UnloadCallbacks, function()
        if okBlur and glassBlur then pcall(function() glassBlur:Destroy() end) end
    end)

    local timeL, cfgL
    local pageLayouts = {}

    -- root
    local Root = create("Frame", { Name = "Root", BackgroundColor3 = C.BackgroundColor, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 0), ClipsDescendants = true, Parent = Container })
    addCorner(Root, 0)
    addStroke(Root, C.OutlineColor, 1.5, 0.3)
    do -- glass reflection
        local white = Color3.new(1, 1, 1)
        local sheen = create("Frame", { Name = "Sheen", BackgroundColor3 = white, Size = UDim2.fromScale(1, 1), Active = false, ZIndex = 0, Parent = Root })
        addCorner(sheen, 0)
        create("UIGradient", {
            Rotation = 35,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(0.28, 0.9),
                NumberSequenceKeypoint.new(0.55, 0.99), NumberSequenceKeypoint.new(0.8, 0.96),
                NumberSequenceKeypoint.new(1, 0.84),
            }),
            Parent = sheen,
        })
        local tint = create("Frame", { Name = "Tint", BackgroundColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.fromScale(1, 1), Active = false, ZIndex = 0, Parent = Root })
        addCorner(tint, 0)
        create("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.97), NumberSequenceKeypoint.new(1, 0.86),
            }),
            Parent = tint,
        })
        local rim = create("Frame", { Name = "Rim", BackgroundColor3 = white, Size = UDim2.new(1, -36, 0, 1), Position = UDim2.new(0, 18, 0, 0), Active = false, ZIndex = 5, Parent = Root })
        create("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = rim,
        })
    end
    Window.Root, Window.Container = Root, Container

    local PAD = 10
    local Sidebar = create("Frame", { Name = "Sidebar", BackgroundColor3 = C.SidebarColor, Size = UDim2.new(0, sideW - PAD, 1, -PAD * 2), Position = UDim2.fromOffset(PAD, PAD), Parent = Root })
    addCorner(Sidebar, -2)
    addStroke(Sidebar, C.OutlineColor, 1, 0.6)

    local header = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), Parent = Sidebar })
    local logoUrl2 = iconUrl(cfg.Icon)
    local logo = create("ImageLabel", { BackgroundColor3 = C.AccentColor, Image = logoUrl2 or "", Size = UDim2.fromOffset(34, 34), Position = compact and UDim2.new(0.5, -17, 0, 12) or UDim2.new(0, 10, 0, 12), Parent = header })
    addCorner(logo, nil, 9)
    Library:RegisterAccent(function(col) logo.BackgroundColor3 = col end)
    local titleL, footL
    if not compact then
        titleL = newText({ Text = stripRich(cfg.Title or "Menu"), TextSize = 14, FontFace = F_BOLD, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -62, 0, 18), Position = UDim2.new(0, 52, 0, 12), Parent = header })
        footL = newText({ Text = stripRich(cfg.Footer or ""), TextSize = 11, TextColor3 = C.DimColor, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -62, 0, 14), Position = UDim2.new(0, 52, 0, 30), Parent = header })
    end

    -- search pill (sidebar)
    local searchBox, searchBtn
    local tabTop = 62
    if not compact then
        local sw = create("Frame", { Name = "SearchPill", BackgroundColor3 = C.RowColor, Size = UDim2.new(1, -16, 0, 32), Position = UDim2.fromOffset(8, 58), Parent = Sidebar })
        addCorner(sw, nil, 16)
        addStroke(sw, C.OutlineColor, 1, 0.55)
        local ring = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(9, 9), Position = UDim2.fromOffset(13, 10), Parent = sw })
        addCorner(ring, nil, 5)
        create("UIStroke", { Color = C.DimColor, Thickness = 1.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ring })
        create("Frame", { BackgroundColor3 = C.DimColor, Size = UDim2.fromOffset(5, 1.4), Position = UDim2.fromOffset(20, 20), Rotation = 45, Parent = sw })
        searchBox = newText({
            Class = "TextBox", Text = "", PlaceholderText = "Search", PlaceholderColor3 = C.DimColor, ClearTextOnFocus = false, TextSize = 12,
            Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(34, 0), Parent = sw,
        })
        tabTop = 98
    end

    local tabList = create("ScrollingFrame", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, tabTop), Size = UDim2.new(1, 0, 1, -tabTop - 54), ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = Sidebar,
    })
    addPadding(tabList, 8, 8, 2, 4)
    addList(tabList, Enum.FillDirection.Vertical, 3)

    local profile = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 54), Position = UDim2.new(0, 0, 1, -54), Parent = Sidebar })
    create("Frame", { BackgroundColor3 = C.OutlineColor, Size = UDim2.new(1, -20, 0, 1), Position = UDim2.new(0, 10, 0, 0), Parent = profile })
    local av = create("ImageLabel", {
        BackgroundColor3 = C.RowColor, Size = UDim2.fromOffset(30, 30), Position = compact and UDim2.new(0.5, -15, 0, 12) or UDim2.new(0, 10, 0, 12),
        Image = LocalPlayer and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100", LocalPlayer.UserId) or "", Parent = profile,
    })
    addCorner(av, nil, 15)
    if not compact then
        newText({ Text = LocalPlayer and LocalPlayer.DisplayName or "player", TextSize = 12, FontFace = F_BOLD, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -60, 0, 16), Position = UDim2.new(0, 48, 0, 11), Parent = profile })
        newText({ Text = "@" .. (LocalPlayer and LocalPlayer.Name or "player"), TextSize = 10, TextColor3 = C.DimColor, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -60, 0, 14), Position = UDim2.new(0, 48, 0, 27), Parent = profile })
    end

    local TOPH = 54
    local Content = create("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, -sideW, 1, 0), Position = UDim2.new(0, sideW, 0, 0), Parent = Root })
    local topbar = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, TOPH), Parent = Content })
    local PageArea = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -TOPH), Position = UDim2.new(0, 0, 0, TOPH), ClipsDescendants = true, Parent = Content })

    -- page title
    local pageTitle = newText({ Text = "", TextSize = 22, FontFace = F_BOLD, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -270, 1, 0), Position = UDim2.new(0, 16, 0, 0), Parent = topbar })

    -- round window buttons (minimize / unload)
    local function circleBtn(glyph, xOff)
        local b = create("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.RowColor, Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xOff, 0.5, 0), Parent = topbar })
        addCorner(b, nil, 14)
        addStroke(b, C.OutlineColor, 1, 0.5)
        local g = newText({ Text = glyph, TextSize = 16, FontFace = F_BOLD, TextColor3 = C.DimColor, TextXAlignment = ALIGN_C, Size = UDim2.fromScale(1, 1), Parent = b })
        b.MouseEnter:Connect(function() tw(b, { BackgroundTransparency = 0.7 }, 0.15) end)
        b.MouseLeave:Connect(function() tw(b, { BackgroundTransparency = GLASS_ALPHA.Row }, 0.2) end)
        return b, g
    end
    local minBtn = circleBtn("–", -50)
    local closeBtn, closeG = circleBtn("×", -14)
    minBtn.Activated:Connect(function() Window:Toggle(false) end)
    local armed = false
    closeBtn.Activated:Connect(function()
        if armed then Library:Unload() return end
        armed = true
        closeG.TextColor3 = Color3.fromRGB(255, 69, 58)
        Library:Notify({ Title = "<b>Menu</b>", Description = "Press × again to unload", Time = 2 })
        task.delay(2.5, function()
            armed = false
            if closeG.Parent then closeG.TextColor3 = C.DimColor end
        end)
    end)

    -- config pill
    local leftHolder = create("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -90, 0, 0), Parent = topbar })
    addList(leftHolder, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
    local cfgPill = create("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.RowColor, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), LayoutOrder = 1, Parent = leftHolder })
    addCorner(cfgPill, nil, 14)
    addStroke(cfgPill, C.OutlineColor)
    addList(cfgPill, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
    addPadding(cfgPill, 12, 12, 0, 0)
    local cfgName = newText({ Text = "default", TextSize = 12, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), LayoutOrder = 1, Parent = cfgPill })
    newText({ Text = "▼", TextSize = 7, TextColor3 = C.DimColor, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), LayoutOrder = 2, Parent = cfgPill })
    local function curCfg()
        local sm = Library.SaveManagerObj
        return sm and sm.CurrentConfig or "default"
    end
    function Window:UpdateConfigName()
        local n = curCfg()
        cfgName.Text = n
        if cfgL then cfgL.Text = n end
    end
    cfgPill.Activated:Connect(function()
        local sm = Library.SaveManagerObj
        if not sm then return end
        local names = sm:GetConfigs()
        if #names == 0 then names = { "default" } end
        Library:OpenList(cfgPill, {
            Values = names, MinWidth = 140, IsSelected = function(v) return v == curCfg() end,
            OnPick = function(v) sm:Load(v); Window:UpdateConfigName() end,
        })
    end)
    local savePill = create("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.RowColor, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), LayoutOrder = 2, Parent = leftHolder })
    addCorner(savePill, nil, 14)
    addStroke(savePill, C.OutlineColor)
    addPadding(savePill, 14, 14, 0, 0)
    newText({ Text = "Save", TextSize = 12, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), Parent = savePill })
    savePill.Activated:Connect(function()
        local sm = Library.SaveManagerObj
        if sm then
            local ok = sm:Save(curCfg())
            Library:Notify({ Title = "<b>Config</b>", Description = ok and ("Saved: " .. curCfg()) or "Save failed", Time = 2 })
        end
    end)

    -- search (compact mode keeps the topbar icon)
    if compact then
        searchBtn = create("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(28, 28), LayoutOrder = 0, Parent = leftHolder })
        local ring = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(11, 11), Position = UDim2.fromOffset(7, 7), Parent = searchBtn })
        addCorner(ring, nil, 6)
        create("UIStroke", { Color = C.DimColor, Thickness = 1.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ring })
        create("Frame", { BackgroundColor3 = C.DimColor, Size = UDim2.fromOffset(6, 1.6), Position = UDim2.fromOffset(16, 19), Rotation = 45, Parent = searchBtn })
        searchBox = newText({
            Class = "TextBox", Text = "", PlaceholderText = "Search...", PlaceholderColor3 = C.DimColor, ClearTextOnFocus = false, TextSize = 12,
            BackgroundTransparency = GLASS_ALPHA.Row, BackgroundColor3 = C.RowColor, Size = UDim2.new(1, -100, 0, 28),
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 8, Visible = false, Parent = topbar,
        })
        searchBox.BackgroundTransparency = GLASS_ALPHA.Row
        addCorner(searchBox, nil, 13)
        addStroke(searchBox, C.OutlineColor)
        addPadding(searchBox, 9, 9, 0, 0)
        searchBtn.Activated:Connect(function()
            searchBox.Visible = not searchBox.Visible
            if searchBox.Visible then searchBox:CaptureFocus() else searchBox.Text = "" end
        end)
    end
    local function applySearch()
        local q = Window.Query
        local tab = Window.CurrentTab
        if not tab then return end
        for _, el in ipairs(tab.Elements) do
            el._match = (q == "") or (el.SearchText ~= nil and el.SearchText ~= "" and el.SearchText:find(q, 1, true) ~= nil)
            if el._Apply then el:_Apply() end
        end
        for _, g in ipairs(tab.Groupboxes) do
            local any = (q == "")
            if not any then
                for _, el in ipairs(tab.Elements) do
                    if el.Group == g and el.Type ~= "Divider" and el._visible and el._match then any = true break end
                end
            end
            g.Holder.Visible = any
        end
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        Window.Query = searchBox.Text:lower()
        applySearch()
    end)

    -- categories / tabs
    function Window:AddCategory(name)
        self._order = self._order + 1
        local l = newText({ Text = stripRich(name):upper(), TextSize = 10, FontFace = F_BOLD, TextColor3 = C.DimColor, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = self._order, Visible = not compact, Parent = tabList })
        addPadding(l, 8, 0, 6, 0)
        if compact then
            local sp = create("Frame", { BackgroundColor3 = C.OutlineColor, Size = UDim2.new(1, -8, 0, 1), LayoutOrder = self._order, Parent = tabList })
            l:Destroy()
        end
    end

    function Window:SelectTab(tab)
        if self.CurrentTab == tab then return end
        local prev = self.CurrentTab
        self.CurrentTab = tab
        for _, t in ipairs(self.Tabs) do
            local on = (t == tab)
            t.Page.Visible = on
            t.Button.BackgroundTransparency = on and 0.76 or 1
            if t.Stroke then t.Stroke.Transparency = on and 0.4 or 1 end
            t.IconL.TextColor3 = on and C.AccentColor or C.DimColor
            if t.NameL then t.NameL.TextColor3 = on and Color3.new(1, 1, 1) or C.DimColor end
        end
        Library:ClosePopup()
        pageTitle.Text = stripRich(tab.Name)
        if prev then
            if Library.Animations.TabSwitch and feature("Smooth Tab Swap") then
                tab.Page.Position = UDim2.fromOffset(0, 10)
                tw(tab.Page, { Position = UDim2.fromOffset(0, 0) }, 0.22, Enum.EasingStyle.Quart)
            end
            if feature("Tab Icon Bounce") then
                local sc = tab.IconL:FindFirstChild("BounceScale") or create("UIScale", { Name = "BounceScale", Scale = 1, Parent = tab.IconL })
                sc.Scale = 0.7
                tw(sc, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
            end
            if type(_G._playTabWhoosh) == "function" then pcall(_G._playTabWhoosh) end
        end
        applySearch()
    end

    function Window:AddTab(name, icon, desc)
        self._order = self._order + 1
        local Tab = { Name = name, Window = self, Groupboxes = {}, Elements = {} }
        local btn = create("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 36), LayoutOrder = self._order, Parent = tabList,
        })
        addCorner(btn, nil, 14)
        local btnStroke = create("UIStroke", { Color = C.OutlineColor, Thickness = 1, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = btn })
        local glyph = ICONS[icon] or "•"
        local iconL = newText({
            Text = glyph, TextSize = 16, TextColor3 = C.DimColor, TextXAlignment = ALIGN_C, Size = UDim2.fromOffset(24, 36),
            Position = compact and UDim2.new(0.5, -12, 0, 0) or UDim2.new(0, 10, 0, 0), Parent = btn,
        })
        local nameL
        if not compact then
            nameL = newText({ Text = name, TextSize = 13, TextColor3 = C.DimColor, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -44, 1, 0), Position = UDim2.new(0, 40, 0, 0), Parent = btn })
        end
        btn.MouseEnter:Connect(function() if Window.CurrentTab ~= Tab then btn.BackgroundTransparency = 0.94 end end)
        btn.MouseLeave:Connect(function() if Window.CurrentTab ~= Tab then btn.BackgroundTransparency = 1 end end)

        local page = create("ScrollingFrame", {
            Name = "Page_" .. stripRich(name), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.OutlineColor, ScrollBarImageTransparency = 0.6, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = PageArea,
        })
        addPadding(page, 14, 14, 4, 16)
        addList(page, single and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal, 12)
        local function column(order)
            local col = create("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = single and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -6, 0, 0), LayoutOrder = order, Parent = page })
            addList(col, Enum.FillDirection.Vertical, 12)
            return col
        end
        Tab.Left, Tab.Right = column(1), column(2)
        table.insert(pageLayouts, { page = page, left = Tab.Left, right = Tab.Right })
        Tab.Page, Tab.Button, Tab.IconL, Tab.NameL, Tab.Stroke = page, btn, iconL, nameL, btnStroke

        function Tab:AddLeftGroupbox(n, ic) return createGroupbox(self, self.Left, n) end
        function Tab:AddRightGroupbox(n, ic) return createGroupbox(self, self.Right, n) end
        function Tab:AddTabbox()
            local TB = {}
            local flip = false
            function TB:AddTab(n)
                flip = not flip
                return createGroupbox(Tab, flip and Tab.Left or Tab.Right, n)
            end
            return TB
        end
        function Tab:AddImage(info, b)
            if type(info) ~= "table" then info = { Image = info, Height = tonumber(b) } end
            local g = createGroupbox(self, info.Side == "Right" and self.Right or self.Left, info.Title)
            return g:AddImage(info)
        end
        Tab.AddBanner = Tab.AddImage
        function Tab:Show() Window:SelectTab(self) end
        function Tab:UpdateWarningBox() end

        btn.Activated:Connect(function() Window:SelectTab(Tab) end)
        table.insert(self.Tabs, Tab)
        Library.Tabs[name] = Tab
        if #self.Tabs == 1 then self:SelectTab(Tab) end
        return Tab
    end

    function Window:SetAnimations(flags)
        if type(flags) == "table" then
            for k, v in pairs(flags) do Library.Animations[k] = v end
        end
    end
    function Window:SetTitle(t) if titleL then titleL.Text = stripRich(t) end end
    function Window:SetFooter(t) if footL then footL.Text = stripRich(t) end end
    function Window:Toggle(v)
        if v == nil then v = not Library.Toggled end
        Library.Toggled = v and true or false
        Library:ClosePopup()
        Library:_applyBlur()
        if Library.Toggled then
            Container.Visible = true
            if Library.Animations.ToggleWindow then
                dpi.Scale = Library.DPIScale * 0.94
                tw(dpi, { Scale = Library.DPIScale }, 0.2, Enum.EasingStyle.Quart)
            end
        else
            Container.Visible = false
        end
    end
    function Window:Show() self:Toggle(true) end
    function Window:Hide() self:Toggle(false) end
    function Window:Destroy() Library:Unload() end

    Library:MakeDraggable(Container, header, false)
    Library:MakeDraggable(Container, topbar, false)
    Library:MakeDraggable(Container, profile, false)

    -- mouse / touch resize
    local MIN_W, MIN_H = 360, 200
    local function relayout(w)
        local ns = (w - sideW) < 470
        if ns == single then return end
        single = ns
        for _, e in ipairs(pageLayouts) do
            local l = e.page:FindFirstChildOfClass("UIListLayout")
            if l then l.FillDirection = ns and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
            for _, col in ipairs({ e.left, e.right }) do
                col.Size = ns and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -6, 0, 0)
            end
        end
    end
    local function makeHandle(name, size, pos, anchor, dx, dy)
        local h = create("TextButton", {
            Name = name, Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
            Size = size, Position = pos, AnchorPoint = anchor, ZIndex = 30, Parent = Container,
        })
        h.InputBegan:Connect(function(input)
            if not inputIsPress(input) or not Library.Toggled then return end
            local startMouse = Vector2.new(input.Position.X, input.Position.Y)
            local sw, sh = Container.Size.X.Offset, Container.Size.Y.Offset
            local startPos = Container.Position
            local sc = Library.DPIScale
            Library:StartDrag(function(p)
                local d = (p - startMouse) / sc
                local cam2 = workspace.CurrentCamera
                local vp2 = cam2 and cam2.ViewportSize or Vector2.new(1280, 720)
                local nw = dx ~= 0 and math.clamp(sw + d.X, MIN_W, math.max(MIN_W, vp2.X / sc - 10)) or sw
                local nh = dy ~= 0 and math.clamp(sh + d.Y, MIN_H, math.max(MIN_H, vp2.Y / sc - 10)) or sh
                Container.Size = UDim2.fromOffset(nw, nh)
                Container.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + (nw - sw) * sc / 2,
                    startPos.Y.Scale, startPos.Y.Offset + (nh - sh) * sc / 2
                )
                relayout(nw)
            end)
        end)
        return h
    end
    local gripSize = UIS.TouchEnabled and 34 or 24
    makeHandle("ResizeRight", UDim2.new(0, 10, 1, -gripSize), UDim2.new(1, 5, 0, 18), Vector2.new(1, 0), 1, 0)
    makeHandle("ResizeBottom", UDim2.new(1, -gripSize, 0, 10), UDim2.new(0, 0, 1, 5), Vector2.new(0, 1), 0, 1)
    local corner = makeHandle("ResizeCorner", UDim2.fromOffset(gripSize, gripSize), UDim2.new(1, 0, 1, 0), Vector2.new(1, 1), 1, 1)
    local grip = newText({
        Text = "◢", TextSize = 12, TextColor3 = C.DimColor, TextXAlignment = ALIGN_R, TextYAlignment = Enum.TextYAlignment.Bottom,
        Size = UDim2.new(1, -12, 1, -12), ZIndex = 31, Parent = corner,
    })
    grip.TextTransparency = 1
    corner.MouseEnter:Connect(function() grip.TextTransparency = 0.35; grip.TextColor3 = C.AccentColor end)
    corner.MouseLeave:Connect(function() grip.TextTransparency = 1; grip.TextColor3 = C.DimColor end)
    function Window:Resize(w, h)
        w = math.max(MIN_W, tonumber(w) or Container.Size.X.Offset)
        h = math.max(MIN_H, tonumber(h) or Container.Size.Y.Offset)
        Container.Size = UDim2.fromOffset(w, h)
        relayout(w)
    end

    local function toggleKeyName()
        local tk = Library.ToggleKeybind
        if type(tk) == "table" and tk.Value and tk.Value ~= "None" then return tk.Value end
        local d = cfg.ToggleKeybind
        if typeof(d) == "EnumItem" then return d.Name end
        if type(d) == "string" then return d end
    end
    Library:GiveSignal(UIS.InputBegan:Connect(function(input)
        if input.UserInputType ~= INPUT_KB or UIS:GetFocusedTextBox() then return end
        local n = toggleKeyName()
        if n and input.KeyCode.Name == n then Window:Toggle() end
    end))

    -- mobile toggle button
    if UIS.TouchEnabled then
        local mb = create("TextButton", {
            Text = "", AutoButtonColor = false, BackgroundColor3 = C.BackgroundColor, Size = UDim2.fromOffset(42, 42),
            Position = UDim2.new(0, 14, 0.5, -21), ZIndex = 20, Parent = ScreenGui,
        })
        Library._mobileBtn = mb
        addCorner(mb, nil, 21)
        addStroke(mb, C.OutlineColor, 1.5)
        local u = iconUrl(cfg.Icon)
        if u then
            local im = create("ImageLabel", { BackgroundTransparency = 1, Image = u, Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(8, 8), ZIndex = 21, Parent = mb })
            addCorner(im, nil, 6)
        else
            newText({ Text = "K", FontFace = F_BOLD, TextSize = 18, TextXAlignment = ALIGN_C, Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = mb })
        end
        mb.InputBegan:Connect(function(input)
            if not inputIsPress(input) then return end
            local start = Vector2.new(input.Position.X, input.Position.Y)
            local startPos = mb.Position
            local moved = false
            Library:StartDrag(function(p)
                local d = p - start
                if d.Magnitude > 8 then moved = true end
                if moved then mb.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
            end, function()
                if not moved then Window:Toggle() end
            end)
        end)
    end

    Library.Window = Window
    Library:_applyBlur()
    return Window
end

-- ===== SaveManager =====
SaveManager = { Folder = "Kirpich", Ignore = {}, CurrentConfig = "default" }
local function hasFS()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
        and type(makefolder) == "function" and type(isfolder) == "function" and type(listfiles) == "function"
end
local function ensureFolder(path)
    if not hasFS() then return end
    local cur = ""
    for part in string.gmatch(path, "[^/]+") do
        cur = (cur == "") and part or (cur .. "/" .. part)
        if not isfolder(cur) then pcall(makefolder, cur) end
    end
end
function SaveManager:SetLibrary(lib) self.Library = lib; lib.SaveManagerObj = self end
function SaveManager:IgnoreThemeSettings() self.Ignore["ThemeAccentColor"] = true end
function SaveManager:SetIgnoreIndexes(list) for _, k in ipairs(list or {}) do self.Ignore[k] = true end end
function SaveManager:SetFolder(f) self.Folder = f; ensureFolder(f .. "/settings") end
function SaveManager:_Path(name) return self.Folder .. "/settings/" .. name .. ".json" end
function SaveManager:GetConfigs()
    local out = {}
    if not hasFS() then return out end
    ensureFolder(self.Folder .. "/settings")
    local ok, files = pcall(listfiles, self.Folder .. "/settings")
    if ok and type(files) == "table" then
        for _, f in ipairs(files) do
            local n = tostring(f):match("([^/\\]+)%.json$")
            if n then out[#out + 1] = n end
        end
    end
    table.sort(out)
    return out
end
function SaveManager:Save(name)
    if not name or name == "" or not hasFS() then return false end
    ensureFolder(self.Folder .. "/settings")
    local lib = self.Library or Library
    local out = {}
    local function add(idx, o)
        if self.Ignore[idx] then return end
        local t = o.Type
        if t == "Toggle" then out[#out + 1] = { type = t, idx = idx, value = o.Value }
        elseif t == "Slider" then out[#out + 1] = { type = t, idx = idx, value = o.Value }
        elseif t == "Dropdown" then
            if o.Multi then
                local names = {}
                for k, v in pairs(o.Value) do if v then names[#names + 1] = k end end
                out[#out + 1] = { type = t, idx = idx, multi = true, value = names }
            else
                out[#out + 1] = { type = t, idx = idx, value = o.Value }
            end
        elseif t == "ColorPicker" then out[#out + 1] = { type = t, idx = idx, hex = o.Value:ToHex(), transparency = o.Transparency }
        elseif t == "KeyPicker" then out[#out + 1] = { type = t, idx = idx, key = o.Value, mode = o.Mode }
        elseif t == "Input" then out[#out + 1] = { type = t, idx = idx, text = o.Value } end
    end
    for idx, o in pairs(lib.Toggles) do add(idx, o) end
    for idx, o in pairs(lib.Options) do add(idx, o) end
    local ok = pcall(function() writefile(self:_Path(name), HttpService:JSONEncode({ objects = out })) end)
    if ok then self.CurrentConfig = name end
    return ok
end
function SaveManager:Load(name)
    if not name or name == "" or not hasFS() then return false end
    local path = self:_Path(name)
    if not isfile(path) then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" then return false end
    local lib = self.Library or Library
    for _, e in ipairs(data.objects or {}) do
        pcall(function()
            if self.Ignore[e.idx] then return end
            if e.type == "Toggle" then
                local o = lib.Toggles[e.idx]; if o then o:SetValue(e.value) end
            else
                local o = lib.Options[e.idx]
                if not o then return end
                if e.type == "Slider" then o:SetValue(e.value)
                elseif e.type == "Dropdown" then
                    if e.multi then
                        local m = {}
                        for _, n in ipairs(e.value or {}) do m[n] = true end
                        o:SetValue(m)
                    else o:SetValue(e.value) end
                elseif e.type == "ColorPicker" then o:SetValueRGB(Color3.fromHex(e.hex), e.transparency)
                elseif e.type == "KeyPicker" then o:SetValue({ e.key, e.mode })
                elseif e.type == "Input" then o:SetValue(e.text) end
            end
        end)
    end
    self.CurrentConfig = name
    return true
end
function SaveManager:LoadAutoloadConfig()
    if not hasFS() then return end
    local p = self.Folder .. "/settings/autoload.txt"
    if isfile(p) then
        local ok, name = pcall(readfile, p)
        if ok and name and name ~= "" then
            self:Load(name)
            if Library.Window then Library.Window:UpdateConfigName() end
        end
    end
end
function SaveManager:BuildConfigSection(tab)
    local lib = self.Library or Library
    local box = tab:AddRightGroupbox("Configuration", "folder")
    self.Ignore["SaveManager_ConfigName"] = true
    self.Ignore["SaveManager_ConfigList"] = true
    box:AddInput("SaveManager_ConfigName", { Text = "Config name", Placeholder = "name" })
    local dd = box:AddDropdown("SaveManager_ConfigList", { Text = "Config list", Values = self:GetConfigs(), AllowNull = true })
    local function refresh()
        dd:SetValues(self:GetConfigs())
        dd:SetValue(nil)
    end
    local function note(t) lib:Notify({ Title = "<b>Config</b>", Description = t, Time = 2 }) end
    box:AddButton({ Text = "Create config", Func = function()
        local n = (lib.Options.SaveManager_ConfigName.Value or ""):gsub("[^%w%-_ ]", "")
        if n == "" then return note("Enter a config name") end
        if self:Save(n) then note("Created: " .. n); refresh() else note("Save failed (no file access?)") end
        if lib.Window then lib.Window:UpdateConfigName() end
    end })
    box:AddButton({ Text = "Load config", Func = function()
        local n = lib.Options.SaveManager_ConfigList.Value
        if not n then return note("Select a config") end
        if self:Load(n) then note("Loaded: " .. n) else note("Load failed") end
        if lib.Window then lib.Window:UpdateConfigName() end
    end })
    box:AddButton({ Text = "Overwrite config", Func = function()
        local n = lib.Options.SaveManager_ConfigList.Value
        if not n then return note("Select a config") end
        if self:Save(n) then note("Overwritten: " .. n) else note("Save failed") end
    end })
    box:AddButton({ Text = "Refresh list", Func = refresh })
    box:AddButton({ Text = "Set as autoload", Func = function()
        local n = lib.Options.SaveManager_ConfigList.Value
        if not n then return note("Select a config") end
        pcall(function() writefile(self.Folder .. "/settings/autoload.txt", n) end)
        note("Autoload: " .. n)
    end })
end

-- ===== ThemeManager =====
ThemeManager = { Folder = "Kirpich", DefaultTheme = "Default", BuiltInThemes = { Default = { 1, {} } } }
function ThemeManager:SetLibrary(lib) self.Library = lib end
function ThemeManager:SetFolder(f) self.Folder = f end
function ThemeManager:ApplyToTab(tab)
    local lib = self.Library or Library
    local box = tab:AddLeftGroupbox("Theme", "paintbrush")
    box:AddLabel("Accent color"):AddColorPicker("ThemeAccentColor", {
        Default = lib.Scheme.AccentColor, Title = "Accent color",
        Callback = function(c) lib:SetAccent(c) end,
    })
    box:AddButton({ Text = "Reset accent", Func = function()
        local o = lib.Options.ThemeAccentColor
        if o then o:SetValueRGB(Color3.fromRGB(10, 132, 255)) end
    end })
end

return Library, ThemeManager, SaveManager
end)()
-- ===== END KIRPICH UI =====
task.spawn(function()
    local okK, errK = pcall(function()

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")

    local LP = Players.LocalPlayer
    local POS = Vector3.new(507.4, 458.4, 37.7)

    local SHOW_DIST = 30
    local HIDE_DIST = 42
    local BPM = 118

    local env = (getgenv and getgenv()) or _G

    if env.KIRPICH_CLEANUP then
        pcall(env.KIRPICH_CLEANUP)
    end

    for _, name in ipairs({ "LOCAL_KIRPICH", "LOCAL_KIRPICH_ORBIT" }) do
        local old = workspace:FindFirstChild(name)
        if old then old:Destroy() end
    end

    local BRICK = Color3.fromRGB(172, 82, 52)
    local BRICK_2 = Color3.fromRGB(150, 68, 42)
    local DARK = Color3.fromRGB(96, 42, 26)
    local MORTAR = Color3.fromRGB(222, 192, 158)
    local GLOW = Color3.fromRGB(255, 150, 90)

    local model = Instance.new("Model")
    model.Name = "LOCAL_KIRPICH"
    model.Parent = workspace

    local function makePart(name, size, position, color, material, shape)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.CFrame = CFrame.new(position)
        p.Anchored = false
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        p.Massless = true
        p.Material = material or Enum.Material.Brick
        p.Color = color or BRICK
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        if shape then p.Shape = shape end
        p.Parent = model
        return p
    end

    local center = POS + Vector3.new(0, 3.2, 0)
    local function at(x, y, z)
        return center + Vector3.new(x, y, z)
    end

    local root = makePart("HumanoidRootPart", Vector3.new(0.2, 0.2, 0.2), center)
    root.Transparency = 1
    root.Anchored = true

    local lower = makePart("LowerTorso", Vector3.new(1.3, 1, 0.85), center, BRICK_2)
    local upper = makePart("UpperTorso", Vector3.new(1.6, 1.5, 0.95), at(0, 1.25, 0), BRICK)
    local head = makePart("Head", Vector3.new(2.1, 2.1, 2.1), at(0, 2.95, 0), BRICK)

    local belt = makePart("Belt", Vector3.new(1.38, 0.2, 0.93), at(0, 0.42, 0), MORTAR, Enum.Material.Concrete)
    local capTop = makePart("CapTop", Vector3.new(2.25, 0.5, 2.25), at(0, 4.2, 0), DARK, Enum.Material.Slate)
    local capBrim = makePart("CapBrim", Vector3.new(2.0, 0.14, 0.8), at(0, 4.02, -1.35), DARK, Enum.Material.Slate)
    local neckPart = makePart("NeckBrick", Vector3.new(0.9, 0.3, 0.7), at(0, 2.0, 0), MORTAR, Enum.Material.Concrete)

    local lua = makePart("LeftUpperArm", Vector3.new(0.52, 1, 0.52), at(-1.1, 0.95, 0), BRICK)
    local lla = makePart("LeftLowerArm", Vector3.new(0.44, 0.95, 0.44), at(-1.1, -0.05, 0), BRICK_2)
    local lh = makePart("LeftHand", Vector3.new(0.5, 0.42, 0.5), at(-1.1, -0.74, 0), MORTAR, Enum.Material.Concrete)

    local rua = makePart("RightUpperArm", Vector3.new(0.52, 1, 0.52), at(1.1, 0.95, 0), BRICK)
    local rla = makePart("RightLowerArm", Vector3.new(0.44, 0.95, 0.44), at(1.1, -0.05, 0), BRICK_2)
    local rh = makePart("RightHand", Vector3.new(0.5, 0.42, 0.5), at(1.1, -0.74, 0), MORTAR, Enum.Material.Concrete)

    local lul = makePart("LeftUpperLeg", Vector3.new(0.6, 1.5, 0.6), at(-0.36, -1.3, 0), BRICK)
    local lll = makePart("LeftLowerLeg", Vector3.new(0.52, 1.4, 0.52), at(-0.36, -2.75, 0), BRICK_2)
    local lf = makePart("LeftFoot", Vector3.new(0.66, 0.38, 1.0), at(-0.36, -3.6, -0.15), DARK, Enum.Material.Slate)

    local rul = makePart("RightUpperLeg", Vector3.new(0.6, 1.5, 0.6), at(0.36, -1.3, 0), BRICK)
    local rll = makePart("RightLowerLeg", Vector3.new(0.52, 1.4, 0.52), at(0.36, -2.75, 0), BRICK_2)
    local rf = makePart("RightFoot", Vector3.new(0.66, 0.38, 1.0), at(0.36, -3.6, -0.15), DARK, Enum.Material.Slate)

    local J = {}

    local function connect(name, p0, p1, pivot, animated)
        local worldPivot = CFrame.new(pivot)
        local m = Instance.new("Motor6D")
        m.Name = name
        m.Part0 = p0
        m.Part1 = p1
        m.C0 = p0.CFrame:ToObjectSpace(worldPivot)
        m.C1 = p1.CFrame:ToObjectSpace(worldPivot)
        m.Parent = p0
        if animated then
            J[name] = m
        end
        return m
    end

    connect("Root", root, lower, center, false)
    connect("Waist", lower, upper, at(0, 0.65, 0), true)
    connect("Neck", upper, head, at(0, 2.0, 0), true)

    connect("LShoulder", upper, lua, at(-0.9, 1.75, 0), true)
    connect("LElbow", lua, lla, at(-1.1, 0.45, 0), true)
    connect("LWrist", lla, lh, at(-1.1, -0.52, 0), true)

    connect("RShoulder", upper, rua, at(0.9, 1.75, 0), true)
    connect("RElbow", rua, rla, at(1.1, 0.45, 0), true)
    connect("RWrist", rla, rh, at(1.1, -0.52, 0), true)

    connect("LHip", lower, lul, at(-0.36, -0.5, 0), true)
    connect("LKnee", lul, lll, at(-0.36, -2.05, 0), true)
    connect("LAnkle", lll, lf, at(-0.36, -3.45, 0), true)

    connect("RHip", lower, rul, at(0.36, -0.5, 0), true)
    connect("RKnee", rul, rll, at(0.36, -2.05, 0), true)
    connect("RAnkle", rll, rf, at(0.36, -3.45, 0), true)

    connect("BeltW", lower, belt, at(0, 0.42, 0), false)
    connect("NeckW", upper, neckPart, at(0, 2.0, 0), false)
    connect("CapW", head, capTop, at(0, 4.2, 0), false)
    connect("BrimW", head, capBrim, at(0, 4.02, -1.35), false)

    model.PrimaryPart = root

    local face = Instance.new("SurfaceGui")
    face.Name = "KIRPICH_FACE"
    face.Face = Enum.NormalId.Front
    face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    face.PixelsPerStud = 100
    face.LightInfluence = 0
    face.Parent = head

    local function eye(x)
        local e = Instance.new("Frame")
        e.AnchorPoint = Vector2.new(0.5, 0.5)
        e.Position = UDim2.fromScale(x, 0.42)
        e.Size = UDim2.fromScale(0.13, 0.17)
        e.BackgroundColor3 = Color3.fromRGB(25, 15, 12)
        e.BorderSizePixel = 0
        e.Parent = face

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = e

        local glint = Instance.new("Frame")
        glint.AnchorPoint = Vector2.new(0.5, 0.5)
        glint.Position = UDim2.fromScale(0.62, 0.3)
        glint.Size = UDim2.fromScale(0.32, 0.26)
        glint.BackgroundColor3 = Color3.new(1, 1, 1)
        glint.BorderSizePixel = 0
        glint.Parent = e
        local gc = Instance.new("UICorner")
        gc.CornerRadius = UDim.new(1, 0)
        gc.Parent = glint
    end

    eye(0.3)
    eye(0.7)

    local function blush(x)
        local b = Instance.new("Frame")
        b.AnchorPoint = Vector2.new(0.5, 0.5)
        b.Position = UDim2.fromScale(x, 0.6)
        b.Size = UDim2.fromScale(0.16, 0.08)
        b.BackgroundColor3 = Color3.fromRGB(255, 130, 130)
        b.BackgroundTransparency = 0.35
        b.BorderSizePixel = 0
        b.Parent = face
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = b
    end

    blush(0.17)
    blush(0.83)

    local mouth = Instance.new("TextLabel")
    mouth.AnchorPoint = Vector2.new(0.5, 0.5)
    mouth.Position = UDim2.fromScale(0.5, 0.62)
    mouth.Size = UDim2.fromScale(0.26, 0.26)
    mouth.BackgroundTransparency = 1
    mouth.Text = "3"
    mouth.Rotation = 90
    mouth.TextScaled = true
    mouth.Font = Enum.Font.GothamBlack
    mouth.TextColor3 = Color3.fromRGB(25, 15, 12)
    mouth.Parent = face

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "KIRPICH_MESSAGE"
    billboard.Adornee = head
    billboard.Size = UDim2.fromOffset(190, 38)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.1, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = math.huge
    billboard.ResetOnSpawn = false
    billboard.Enabled = false
    billboard.Parent = head

    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.fromScale(1, 1)
    msg.BackgroundColor3 = DARK
    msg.BackgroundTransparency = 1
    msg.Text = "I am kirpich :3"
    msg.TextColor3 = Color3.fromRGB(255, 214, 180)
    msg.TextTransparency = 1
    msg.TextSize = 16
    msg.Font = Enum.Font.GothamBold
    msg.Parent = billboard

    local msgCorner = Instance.new("UICorner")
    msgCorner.CornerRadius = UDim.new(0, 8)
    msgCorner.Parent = msg

    local msgStroke = Instance.new("UIStroke")
    msgStroke.Color = BRICK
    msgStroke.Thickness = 2
    msgStroke.Transparency = 1
    msgStroke.Parent = msg

    local highlight = Instance.new("Highlight")
    highlight.Adornee = model
    highlight.FillColor = BRICK
    highlight.OutlineColor = GLOW
    highlight.FillTransparency = 0.75
    highlight.OutlineTransparency = 0.1
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = model

    local light = Instance.new("PointLight")
    light.Color = GLOW
    light.Range = 14
    light.Brightness = 1.2
    light.Parent = upper

    local embers = Instance.new("ParticleEmitter")
    embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    embers.Color = ColorSequence.new(GLOW, BRICK)
    embers.LightEmission = 0.6
    embers.Rate = 7
    embers.Lifetime = NumberRange.new(1, 1.8)
    embers.Speed = NumberRange.new(0.6, 1.4)
    embers.SpreadAngle = Vector2.new(180, 180)
    embers.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(1, 0),
    })
    embers.Parent = upper

    local orbit = {}
    for i = 1, 4 do
        local b = makePart(
            "OrbitBrick" .. i,
            Vector3.new(0.6, 0.45, 0.3),
            POS,
            (i % 2 == 0) and BRICK or BRICK_2
        )
        b.Anchored = true
        table.insert(orbit, b)
    end

    local I = CFrame.identity
    local function A(x, y, z)
        return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
    end

    local SEQ = { "roll", "roll", "R", "L", "R", "L", "cross", "cross" }

    local function getPose(name, w)
        local T = {}
        if name == "roll" then
            T.LShoulder = A(25 + 18 * w, 0, -14)
            T.RShoulder = A(25 - 18 * w, 0, 14)
            T.LElbow = A(85 + 20 * w, 0, 0)
            T.RElbow = A(85 - 20 * w, 0, 0)
            T.LWrist = A(20 * w, 0, 0)
            T.RWrist = A(-20 * w, 0, 0)
            T.Waist = A(0, 6 * w, 0)
        elseif name == "R" then
            T.RShoulder = A(25, 0, -22)
            T.RElbow = A(125, 0, 0)
            T.RWrist = A(-15, 0, 0)
            T.LShoulder = A(-12, 0, -18)
            T.LElbow = A(15 + 10 * w, 0, 0)
            T.Waist = A(0, -12, -4)
            T.Neck = A(0, 8, 5)
        elseif name == "L" then
            T.LShoulder = A(25, 0, 22)
            T.LElbow = A(125, 0, 0)
            T.LWrist = A(-15, 0, 0)
            T.RShoulder = A(-12, 0, 18)
            T.RElbow = A(15 + 10 * w, 0, 0)
            T.Waist = A(0, 12, 4)
            T.Neck = A(0, -8, -5)
        else
            T.LShoulder = A(40, 0, 28)
            T.RShoulder = A(40, 0, -28)
            T.LElbow = A(55 + 12 * w, 0, 0)
            T.RElbow = A(55 - 12 * w, 0, 0)
            T.Waist = A(4, 0, 0)
        end
        return T
    end

    local function update(dt)
        if not model.Parent then return end

        local char = LP.Character
        local playerRoot = char and char:FindFirstChild("HumanoidRootPart")

        local lookAt = POS + Vector3.new(0, 3.2, -1)
        local dist = math.huge
        if playerRoot then
            lookAt = Vector3.new(playerRoot.Position.X, POS.Y + 3.2, playerRoot.Position.Z)
            dist = (playerRoot.Position - center).Magnitude
        end

        local base = CFrame.lookAt(center, lookAt)

        local alpha = math.clamp((HIDE_DIST - dist) / (HIDE_DIST - SHOW_DIST), 0, 1)
        billboard.Enabled = alpha > 0.01
        msg.TextTransparency = 1 - alpha
        msg.BackgroundTransparency = 1 - alpha * 0.9
        msgStroke.Transparency = 1 - alpha

        local t = os.clock()
        local beats = t * BPM / 60
        local idx = math.floor(beats) % #SEQ + 1
        local ph = beats % 1
        local w = math.sin(ph * math.pi * 2)
        local dip = (math.cos(ph * math.pi * 2) + 1) / 2

        local T = getPose(SEQ[idx], w)

        T.LHip = A(18 * dip, 0, -4)
        T.RHip = A(18 * dip, 0, 4)
        T.LKnee = A(-36 * dip, 0, 0)
        T.RKnee = A(-36 * dip, 0, 0)
        T.LAnkle = A(18 * dip, 0, 0)
        T.RAnkle = A(18 * dip, 0, 0)
        T.Neck = T.Neck or A(8 * dip, 0, 0)

        local k = 1 - math.exp(-dt * 20)
        for name, motor in pairs(J) do
            motor.Transform = motor.Transform:Lerp(T[name] or I, k)
        end

        root.CFrame = base * CFrame.new(0, -dip * 0.25, 0)

        highlight.OutlineTransparency = 0.1 + 0.15 * (1 - dip)
        light.Brightness = 1 + 0.5 * dip

        for i, brick in ipairs(orbit) do
            local angle = t * 1.4 + (i - 1) * math.pi / 2
            brick.CFrame = base * CFrame.new(
                math.cos(angle) * 2.8,
                2.4 + math.sin(t * 2 + i) * 0.3,
                math.sin(angle) * 2.8
            ) * CFrame.Angles(t, angle, t * 0.5)
        end
    end

    local connection = RunService.RenderStepped:Connect(update)

    env.KIRPICH_CLEANUP = function()
        if connection then
            connection:Disconnect()
            connection = nil
        end
        if model then
            model:Destroy()
        end
    end

    pcall(function()
        Library:OnUnload(function()
            pcall(env.KIRPICH_CLEANUP)
        end)
    end)

    print("PROJECT KIRPICH V10 LOADED")
    end)
    if not okK then warn("[Kirpich] " .. tostring(errK)) end
end)
local Options = Library.Options
local Toggles = Library.Toggles
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
do
	local lib = Library
		local TweenService = game:GetService("TweenService")
		local tbl5 = {
			Home = 1,
			Main = 2,
			Target = 3,
			Drone = 4,
			Visuals = 5,
			Cosmetics = 6,
			Settings = 7,
		}
		local n14 = 1
		local sound = Instance.new("Sound")
		sound.Name = "KirpichTabWhoosh"
		sound.SoundId = "rbxassetid://138158731526545"
		sound.Volume = 0.12
		sound.PlaybackSpeed = 1.35
		sound.RollOffMaxDistance = 0
		local SoundService = game:GetService("SoundService")
		if SoundService then
			sound.Parent = SoundService
			_G._initialTabLoaded = false
			task.delay(0.8, function()
				_G._initialTabLoaded = true
			end)
			local function isAdditionalFeatureEnabled(arg)
				local additionalFeaturesDropdown = lib and lib.Options and lib.Options.AdditionalFeaturesDropdown
				if not additionalFeaturesDropdown then
					return true
				end
				if type(additionalFeaturesDropdown.Value) == "table" then
					return additionalFeaturesDropdown.Value[arg] == true
				end
				if type(additionalFeaturesDropdown.Value) == "string" then
					return additionalFeaturesDropdown.Value == arg
				end
				return false
			end
			_G._isAdditionalFeatureEnabled = isAdditionalFeatureEnabled
			local n15 = 0
			_G._playTabWhoosh = function()
				if not _G._initialTabLoaded then
					return
				end
				if not isAdditionalFeatureEnabled("Tab Swap Sound") then
					return
				end
				if tick() - n15 < 0.1 then
					return
				end
				n15 = tick()
				pcall(function()
					sound.TimePosition = 0
					sound:Play()
				end)
			end
			_G.SmoothMenuDrag = false
		end
end
do
	local lib = Library
	local Debris = game:GetService("Debris")
	local presets = {
		IPhone = "rbxassetid://139746569667955",
		Ding = "rbxassetid://97643101798871",
		["Steam Notification"] = "rbxassetid://139308638407157",
		["Steam Achievement"] = "rbxassetid://78959439349986",
		Mobile = "rbxassetid://131935970184832",
		Blump = "rbxassetid://129485210015224",
		Alert = "rbxassetid://134026118100102",
		Soundful = "rbxassetid://105733192844099",
		Drum = "rbxassetid://96628258513206",
		Soft = "rbxassetid://131661992591924",
	}
	local zap = {
		"rbxassetid://134119055334162",
		"rbxassetid://135103601014582",
		"rbxassetid://126172750038425",
	}
	local lastZap
	local state = { disabled = false }
	getgenv().KirpichNotifState = state
	local function play(id)
		if not id or id == "" then return end
		pcall(function()
			local opt = lib.Options.NotifVolume
			local s = Instance.new("Sound")
			s.SoundId = id
			s.Volume = (opt and opt.Value or 5) * 0.4
			s.RollOffMaxDistance = 0
			s.Parent = workspace
			s:Play()
			Debris:AddItem(s, 5)
		end)
	end
	local function notifSound()
		local o, t = lib.Options, lib.Toggles
		local custom = o.NotifSoundID and tonumber(o.NotifSoundID.Value)
		if t.UseCustomSoundID and t.UseCustomSoundID.Value and custom then
			play("rbxassetid://" .. string.format("%.0f", custom))
			return
		end
		local preset = o.NotifPreset and o.NotifPreset.Value or "IPhone"
		if preset == "Random Zap" then
			local pool = {}
			for _, id in ipairs(zap) do
				if id ~= lastZap then table.insert(pool, id) end
			end
			lastZap = pool[math.random(1, #pool)]
			play(lastZap)
			return
		end
		play(presets[preset] or presets.IPhone)
	end
	local origNotify = lib.Notify
	lib.Notify = function(self, ...)
		if state.disabled then return end
		task.spawn(notifSound)
		return origNotify(self, ...)
	end
end
local Window = Library:CreateWindow({
    Title = "Kirpich v0.1",
    Footer = "by cimkarta",
    Icon = 101625258941158,
    Font = Enum.Font.Gotham,
    NotifySide = "Right",
    ToggleKeybind = Enum.KeyCode.RightShift,
    ShowCustomCursor = true,
    Center = true,
    AutoShow = true,
    Resizable = true,
    Size = UDim2.fromOffset(720, 440),
    CornerRadius = 18,
    EnableSidebarResize = true,
    EnableCompacting = true,
    SidebarCompacted = true,
    SidebarCompactWidth = 48,
    MinSidebarWidth = 100,
    CompactWidthActivation = 100,
    BackgroundImage = "rbxassetid://0",
    Animations = {
        ToggleWindow = false,
        TabSwitch = true,
        Groupbox = true,
        Dropdown = true,
        KeyPicker = true,
    },
    TabTransitionTime = 0.35,
    TabSwipeOffset = 24,
    TabSwipeFrom = "auto",
})
pcall(function()
    Window:SetAnimations({ ToggleWindow = false, TabSwitch = true, Groupbox = true, Dropdown = true, KeyPicker = true }, 0.35, 24, "auto")
end)
local Sink
Sink = setmetatable({}, {
    __index = function(_, k)
        if k == "Value" then return false end
        return function() return Sink end
    end,
    __call = function() return Sink end,
})
getgenv().__KRP_SINK = Sink
getgenv().__KRP_TC = function(t)
    if type(t) ~= "string" or t:find("<", 1, true) or t:find("%%") then
        return t
    end
    local out, prevAlnum = {}, false
    for i = 1, #t do
        local ch = t:sub(i, i)
        if not prevAlnum and ch:match("%a") then
            ch = ch:upper()
        end
        prevAlnum = ch:match("[%w'\226]") ~= nil
        out[#out + 1] = ch
    end
    return table.concat(out)
end
getgenv().__KRP_ICONS = { ["Player Actions"] = "user", ["Role Fling"] = "swords" }
Window:AddCategory("General")
local Tabs = {
    Home = Window:AddTab("<b>Home</b>", "house", "Profile, statistics"),
    Main = Window:AddTab("Main", "user"),
    Target = Window:AddTab("Target", "crosshair"),
    Drone = Window:AddTab("Troll", "plane"),
}
Window:AddCategory("Common")
Tabs.Visuals = Window:AddTab("Visuals", "eye")
Tabs.Cosmetics = Window:AddTab("Cosmetics", "star")
Tabs.Settings = Window:AddTab("Settings", "settings")
Tabs.Server = Tabs.Home
Tabs.Models = Tabs.Visuals
Tabs.Anims = Tabs.Cosmetics
Tabs.Skins = Tabs.Cosmetics
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
do
    local Greetings = Tabs.Home:AddLeftGroupbox("Greetings", "chess-queen")
    local thumbnail = string.format("rbxthumb://type=AvatarBust&id=%d&w=180&h=180", localPlayer.UserId)
    local avatar = Greetings:AddImage("MyIcon", {
        Image = thumbnail,
        Height = 180,
        Color = Color3.new(1, 1, 1),
        Transparency = 0,
        BackgroundTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
    })
    task.spawn(function()
        local holder = avatar and avatar.Holder
        local image = holder and holder:FindFirstChildWhichIsA("ImageLabel", true)
        if not image then return end
        for attempt = 1, 6 do
            if avatar.Destroyed or not image.Parent then return end
            local ok, content, ready = pcall(function()
                return Players:GetUserThumbnailAsync(localPlayer.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size180x180)
            end)
            if avatar.Destroyed or not image.Parent then return end
            if ok and ready and type(content) == "string" and content ~= "" then
                image.Image = content
                image.ImageColor3 = Color3.new(1, 1, 1)
                image.ImageTransparency = 0
                image.ImageRectOffset = Vector2.zero
                image.ImageRectSize = Vector2.zero
                avatar.Image = content
            end
            task.wait(math.min(attempt * 0.5, 2))
            if avatar.Destroyed or not image.Parent then return end
            if image.IsLoaded then return end
        end
        if image.Parent then
            image.Image = thumbnail
            avatar.Image = thumbnail
        end
    end)
    local hour = tonumber(os.date("%H")) or 12
    local greeting = "Night"
    if hour >= 5 and hour < 12 then
        greeting = "Morning"
    elseif hour >= 12 and hour < 17 then
        greeting = "Afternoon"
    elseif hour >= 17 and hour < 21 then
        greeting = "Evening"
    end
    Greetings:AddLabel({ Text = ("%s, <b>%s</b> "):format(greeting, localPlayer.DisplayName), DoesWrap = true })
    Greetings:AddDivider()
    Greetings:AddLabel({ Text = "Welcome to <b><font color=\"#fffb00\">Kirpich</font></b>", DoesWrap = true })
end
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local MiscGroup = Tabs.Home:AddRightGroupbox("Server", "globe")
MiscGroup:AddButton({
    Text = "Unload Script",
    Func = function()
        Library:Unload()
    end,
})
MiscGroup:AddButton({
    Text = "Rejoin Server",
    Func = function()
        local localPlayer = Players.LocalPlayer
        local isVipServer = game.VIPServerId ~= "" and game.VIPServerId ~= nil
        pcall(function()
            if isVipServer then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
            else
                TeleportService:Teleport(game.PlaceId, localPlayer)
            end
        end)
    end,
})
local function runBlock(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[Kirpich] " .. name .. " failed: " .. tostring(err))
        pcall(function()
        end)
    end
end
runBlock("Player+Server", function()
    local UserInputService = game:GetService("UserInputService")
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local lp = Players.LocalPlayer
    local mods = { speed = nil, jump = nil, infJump = false, noclip = false, antiFling = false }
    Library.KirpichMods = mods
    local conns = {}
    local function bind(signal, fn)
        local c = signal:Connect(fn)
        table.insert(conns, c)
        return c
    end
    local function getHum()
        local c = lp.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end
    bind(RunService.Heartbeat, function()
        local hum = getHum()
        if not hum then return end
        if mods.speed and hum.WalkSpeed ~= mods.speed then
            hum.WalkSpeed = mods.speed
        end
        if mods.jump then
            hum.UseJumpPower = true
            if hum.JumpPower ~= mods.jump then
                hum.JumpPower = mods.jump
            end
        end
    end)
    local noclipParts = {}
    local noclipList, noclipChar, noclipAt = {}, nil, 0
    bind(RunService.Stepped, function()
        if not mods.noclip then return end
        local char = lp.Character
        if not char then return end
        local now = os.clock()
        if char ~= noclipChar or now - noclipAt > 0.5 then
            noclipChar, noclipAt = char, now
            table.clear(noclipList)
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then noclipList[#noclipList + 1] = part end
            end
        end
        for i = 1, #noclipList do
            local part = noclipList[i]
            if part.CanCollide then
                noclipParts[part] = true
                part.CanCollide = false
            end
        end
    end)
    local function disableNoclip()
        mods.noclip = false
        for part in pairs(noclipParts) do
            if part.Parent then part.CanCollide = true end
        end
        table.clear(noclipParts)
    end
    local flingParts = {}
    local safeCFrame, safeTime = nil, 0
    local antiFlingAt = 0
    bind(RunService.Stepped, function()
        if not mods.antiFling then return end
        local nowAF = os.clock()
        if nowAF - antiFlingAt < 0.12 then return end
        antiFlingAt = nowAF
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp and p.Character then
                for _, part in ipairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        flingParts[part] = true
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
    bind(RunService.Heartbeat, function()
        if not mods.antiFling then return end
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local v, w = hrp.AssemblyLinearVelocity, hrp.AssemblyAngularVelocity
        if v.Magnitude > 200 or w.Magnitude > 60 then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end
            end
            if safeCFrame then hrp.CFrame = safeCFrame end
        elseif os.clock() - safeTime > 0.1 then
            safeCFrame, safeTime = hrp.CFrame, os.clock()
        end
    end)
    local function disableAntiFling()
        mods.antiFling = false
        for part in pairs(flingParts) do
            if part.Parent then part.CanCollide = true end
        end
        table.clear(flingParts)
    end
    Library.KirpichDisableAntiFling = disableAntiFling
    bind(UserInputService.JumpRequest, function()
        if not mods.infJump then return end
        local hum = getHum()
        if hum and hum.Health > 0 then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
    local PlayerGroup = Tabs.Main:AddRightGroupbox("Player", "user")
    getgenv().__KRP_PLAYER_BOX = PlayerGroup
    PlayerGroup:AddSlider("WalkSpeedSlider", {
        Text = "WalkSpeed", Default = 16, Min = 16, Max = 150, Rounding = 0,
        Callback = function(v) mods.speed = v end,
    })
    PlayerGroup:AddSlider("JumpPowerSlider", {
        Text = "JumpPower", Default = 50, Min = 50, Max = 250, Rounding = 0,
        Callback = function(v) mods.jump = v end,
    })
    PlayerGroup:AddToggle("InfJumpToggle", {
        Text = "Infinite Jump", Default = false,
        Tooltip = "Jump in the air",
        Callback = function(v) mods.infJump = v end,
    })
    PlayerGroup:AddToggle("NoclipToggle", {
        Text = "Noclip", Default = false,
        Tooltip = "Walk through walls",
        Callback = function(v)
            if v then mods.noclip = true else disableNoclip() end
        end,
    })
    PlayerGroup:AddToggle("AntiFlingToggle", {
        Text = "Anti Fling", Default = false,
        Tooltip = "Fling protection",
        Callback = function(v)
            if v then mods.antiFling = true else disableAntiFling() end
        end,
    })
    PlayerGroup:AddDivider()
    PlayerGroup:AddButton({
        Text = "Reset Stats",
        Tooltip = "Default speed and jump",
        Func = function()
            mods.speed, mods.jump = nil, nil
            Options.WalkSpeedSlider:SetValue(16)
            Options.JumpPowerSlider:SetValue(50)
            local hum = getHum()
            if hum then
                hum.WalkSpeed = 16
                hum.JumpPower = 50
            end
        end,
    })
    PlayerGroup:AddButton({
        Text = "Respawn",
        Tooltip = "Kill your character",
        Func = function()
            local hum = getHum()
            if hum then hum.Health = 0 end
        end,
    })
    local ServerGroup = MiscGroup
    local HopGroup = MiscGroup
    local function copyText(text, what)
        if setclipboard then
            setclipboard(text)
        end
    end
    ServerGroup:AddButton({
        Text = "Copy Join Script",
        Func = function()
            copyText(('game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s")'):format(game.PlaceId, game.JobId), "join script")
        end,
    })
    ServerGroup:AddButton({
        Text = "Copy Job ID",
        Func = function() copyText(game.JobId, "job id") end,
    })
    local function findServer(smallest)
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&excludeFullGames=true&limit=100")
            :format(game.PlaceId, smallest and "Asc" or "Desc")
        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        if not ok or type(res) ~= "table" or type(res.data) ~= "table" then return nil end
        local list = {}
        for _, s in ipairs(res.data) do
            if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
                table.insert(list, s)
            end
        end
        if #list == 0 then return nil end
        if smallest then
            table.sort(list, function(a, b) return a.playing < b.playing end)
            return list[1]
        end
        return list[math.random(#list)]
    end
    local hopBusy = false
    local function hop(smallest)
        if hopBusy then return end
        hopBusy = true
        task.spawn(function()
            local server = findServer(smallest)
            if not server then
                hopBusy = false
                return
            end
            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, lp)
            task.delay(5, function() hopBusy = false end)
        end)
    end
    HopGroup:AddButton({ Text = "Server Hop", Tooltip = "Random other server", Func = function() hop(false) end })
    HopGroup:AddButton({ Text = "Small Server", Tooltip = "Server with the fewest players", Func = function() hop(true) end })
    bind(TeleportService.TeleportInitFailed, function(p, _, msg)
        if p == lp then
            hopBusy = false
        end
    end)
    Library:OnUnload(function()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        pcall(disableNoclip)
        pcall(disableAntiFling)
        local hum = getHum()
        if hum then
            pcall(function() hum.WalkSpeed = 16 hum.JumpPower = 50 end)
        end
    end)
end)
do
    local lp = Players.LocalPlayer
    local accentColor = Color3.fromRGB(255, 255, 255)
    local dimColor = Color3.fromRGB(120, 120, 120)
    local conns = {}
    local function bind(signal, fn)
        local c = signal:Connect(fn)
        table.insert(conns, c)
        return c
    end
    local function mk(className, props)
        local inst = Instance.new(className)
        local parent = props.Parent
        props.Parent = nil
        for k, v in pairs(props) do inst[k] = v end
        inst.Parent = parent
        return inst
    end
    local guiParent
    runBlock("block", function()
        local ok, res = pcall(function() return (gethui and gethui()) or game:GetService("CoreGui") end)
        guiParent = ok and res or lp:WaitForChild("PlayerGui")
    end)
    local function findTool(p, name)
        local char, backpack = p and p.Character, p and p:FindFirstChildOfClass("Backpack")
        return char and char:FindFirstChild(name) or backpack and backpack:FindFirstChild(name)
    end
    local shaderCleanup
    local espCleanup
    runBlock("ESP", function()
        local MAX_DIST = 10000
        local esp = { on = false }
        local espGui = mk("ScreenGui", {
            Name = "KirpichESP",
            IgnoreGuiInset = true,
            ResetOnSpawn = false,
            DisplayOrder = -2,
            Enabled = false,
            Parent = guiParent,
        })
        local chamsFolder = mk("Folder", { Name = "Chams", Parent = espGui })
        local black = Color3.new(0, 0, 0)
        local red = Color3.fromRGB(255, 58, 58)
        local blue = Color3.fromRGB(64, 150, 255)
        local white = Color3.fromRGB(255, 255, 255)
        local entries = {}
        local serverRoles = {}
        local espAlive = true
        task.spawn(function()
            local remote
            while espAlive do
                if esp.on then
                    if not remote or not remote.Parent then
                        remote = game:GetService("ReplicatedStorage"):FindFirstChild("GetPlayerData", true)
                    end
                    if remote and remote:IsA("RemoteFunction") then
                        local ok, data = pcall(remote.InvokeServer, remote)
                        if ok and type(data) == "table" then
                            local newRoles = {}
                            for name, d in pairs(data) do
                                if type(d) == "table" and type(d.Role) == "string" and not d.Dead and not d.Killed then
                                    newRoles[name] = d.Role
                                end
                            end
                            serverRoles = newRoles
                        end
                    end
                end
                task.wait(1)
            end
        end)
        local function getRole(plr)
            if findTool(plr, "Knife") then
                return "Murderer"
            end
            if findTool(plr, "Gun") then
                return "Sheriff"
            end
            local r = serverRoles[plr.Name]
            if r == "Murderer" then
                return "Murderer"
            end
            if r == "Sheriff" or r == "Hero" then
                return "Sheriff"
            end
        end
        local function label(anchorY)
            return mk("TextLabel", {
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextColor3 = white,
                TextStrokeColor3 = black,
                TextStrokeTransparency = 0.4,
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0.5, anchorY),
                Size = UDim2.fromOffset(240, 16),
                Visible = false,
                Parent = espGui,
            })
        end
        local function add(plr)
            if plr == lp or entries[plr] then
                return
            end
            local e = { plr = plr }
            e.hl = mk("Highlight", {
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                FillTransparency = 1,
                OutlineTransparency = 0,
                Enabled = false,
                Parent = chamsFolder,
            })
            e.name = label(1)
            e.info = label(0)
            entries[plr] = e
        end
        local function remove(plr)
            local e = entries[plr]
            if not e then
                return
            end
            e.hl:Destroy()
            e.name:Destroy()
            e.info:Destroy()
            entries[plr] = nil
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            add(plr)
        end
        bind(Players.PlayerAdded, add)
        bind(Players.PlayerRemoving, remove)
        local function hideAll()
            for _, e in pairs(entries) do
                e.hl.Enabled = false
                e.name.Visible = false
                e.info.Visible = false
            end
        end
        bind(RunService.RenderStepped, function()
            if not esp.on then
                return
            end
            local cam = workspace.CurrentCamera
            if not cam then
                return
            end
            local camPos = cam.CFrame.Position
            for plr, e in pairs(entries) do
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local dist = hrp and (camPos - hrp.Position).Magnitude
                if hrp and hum and hum.Health > 0 and dist <= MAX_DIST then
                    local role = getRole(plr)
                    local col = role == "Murderer" and red or role == "Sheriff" and blue or white
                    e.hl.Adornee = char
                    e.hl.OutlineColor = col
                    e.hl.Enabled = true
                    local top = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                    local bottom = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.4, 0))
                    if top.Z > 0 and bottom.Z > 0 then
                        local x = (top.X + bottom.X) / 2
                        e.name.Text = plr.DisplayName
                        e.name.TextColor3 = col
                        e.name.Position = UDim2.fromOffset(x, top.Y - 3)
                        e.name.Visible = true
                        e.info.Text = math.floor(dist + 0.5) .. " studs"
                        e.info.TextColor3 = col
                        e.info.Position = UDim2.fromOffset(x, bottom.Y + 3)
                        e.info.Visible = true
                    else
                        e.name.Visible = false
                        e.info.Visible = false
                    end
                else
                    e.hl.Enabled = false
                    e.name.Visible = false
                    e.info.Visible = false
                end
            end
        end)
        local EG = Tabs.Visuals:AddLeftGroupbox("Main", "eye")
        getgenv().__KRP_VIS_WORLD = Tabs.Visuals:AddLeftGroupbox("World", "sun")
        getgenv().__KRP_VIS_FX = Tabs.Visuals:AddRightGroupbox("Effects", "star")
        EG:AddToggle("ESPEnable", {
            Text = "ESP", Default = false, Tooltip = "Role outline, nickname, distance (up to 10000 studs)",
            Callback = function(on)
                esp.on = on
                espGui.Enabled = on
                if not on then hideAll() end
            end,
        })
        pcall(function()
            local cloneref = cloneref or function(i) return i end
            local Players = cloneref(game:GetService("Players"))
            local InsertService = cloneref(game:GetService("InsertService"))
            local player = Players.LocalPlayer
            local AURAS = {
                { name = "Electric Aura", id = 78011019574795, keepAccessoryMeshes = false },
                { name = "The Aura", id = 80960525975597, keepAccessoryMeshes = false },
                { name = "The Aura", id = 112446670287992, keepAccessoryMeshes = false },
                { name = "The Aura", id = 80145706481445, keepAccessoryMeshes = false },
                { name = "The Aura", id = 90816193741219, keepAccessoryMeshes = false },
                { name = "The Aura", id = 106192507657319, keepAccessoryMeshes = false },
                { name = "The Aura", id = 14676802199, keepAccessoryMeshes = false },
                { name = "The Aura", id = 12958677973, keepAccessoryMeshes = false },
                { name = "The Aura", id = 10088609715, keepAccessoryMeshes = false },
                { name = "The Aura", id = 10748799551, keepAccessoryMeshes = false },
                { name = "The Aura", id = 12726196401, keepAccessoryMeshes = false },
                { name = "The Aura", id = 15757188347, keepAccessoryMeshes = false },
                { name = "The Aura", id = 118916085952001, keepAccessoryMeshes = false },
                { name = "The Aura", id = 17544028481, keepAccessoryMeshes = false },
                { name = "The Aura", id = 81854979707877, keepAccessoryMeshes = false },
                { name = "The Aura", id = 88197945147803, keepAccessoryMeshes = false },
                { name = "The Aura", id = 15128763881, keepAccessoryMeshes = false },
                { name = "The Aura", id = 18717284648, keepAccessoryMeshes = false },
                { name = "The Aura", id = 17155480496, keepAccessoryMeshes = false },
            }

            local labels, indexOf = {}, {}
            do
                local n = 0
                for i, a in ipairs(AURAS) do
                    local label = a.name
                    if label == "The Aura" then
                        n += 1
                        label = "The Aura " .. n
                    end
                    labels[i] = label
                    indexOf[label] = i
                end
            end

            local BODY = {}
            for _, n in ipairs({
                "Head", "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart",
                "Left Arm", "Right Arm", "Left Leg", "Right Leg",
                "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
                "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
            }) do BODY[n] = true end

            local FALLBACK = {
                UpperTorso = { "Torso" }, LowerTorso = { "Torso" }, Torso = { "UpperTorso" },
                ["Left Arm"] = { "LeftUpperArm" }, LeftUpperArm = { "Left Arm" }, LeftLowerArm = { "Left Arm" }, LeftHand = { "Left Arm" },
                ["Right Arm"] = { "RightUpperArm" }, RightUpperArm = { "Right Arm" }, RightLowerArm = { "Right Arm" }, RightHand = { "Right Arm" },
                ["Left Leg"] = { "LeftUpperLeg" }, LeftUpperLeg = { "Left Leg" }, LeftLowerLeg = { "Left Leg" }, LeftFoot = { "Left Leg" },
                ["Right Leg"] = { "RightUpperLeg" }, RightUpperLeg = { "Right Leg" }, RightLowerLeg = { "Right Leg" }, RightFoot = { "Right Leg" },
            }

            local EFFECT = {
                ParticleEmitter = true, Trail = true, Beam = true, Fire = true, Smoke = true, Sparkles = true,
                PointLight = true, SpotLight = true, SurfaceLight = true, Highlight = true,
            }

            local modelCache = {}

            local function loadModel(id)
                if modelCache[id] ~= nil then return modelCache[id] or nil end
                local model
                local ok, res = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
                if ok and type(res) == "table" and res[1] then
                    model = res[1]
                else
                    local ok2, res2 = pcall(function() return InsertService:LoadAsset(id) end)
                    if ok2 and res2 then model = res2 end
                end
                modelCache[id] = model or false
                return model
            end

            local function resolveBody(character, name)
                local p = character:FindFirstChild(name)
                if p and p:IsA("BasePart") then return p end
                for _, alt in ipairs(FALLBACK[name] or {}) do
                    local q = character:FindFirstChild(alt)
                    if q and q:IsA("BasePart") then return q end
                end
                return character:FindFirstChild("HumanoidRootPart")
            end

            local function build(index, entry)
                local character = player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if not (character and hrp) then return nil, "no character" end

                local model = loadModel(entry.id)
                if not model then return nil, "asset load failed" end

                local container = Instance.new("Folder")
                container.Name = "MilkAura_" .. index
                container.Parent = character

                local created = {}
                local function fail(msg)
                    for _, inst in ipairs(created) do pcall(function() inst:Destroy() end) end
                    pcall(function() container:Destroy() end)
                    return nil, msg
                end

                local rigRoot = model:FindFirstChild("HumanoidRootPart", true)
                    or model:FindFirstChild("UpperTorso", true)
                    or model:FindFirstChild("Torso", true)
                local baseCF
                if rigRoot and rigRoot:IsA("BasePart") then
                    baseCF = rigRoot.CFrame
                elseif model:IsA("Model") then
                    baseCF = model:GetPivot()
                else
                    baseCF = CFrame.new()
                end

                local function inAccessory(inst)
                    return inst:FindFirstAncestorWhichIsA("Accessory") ~= nil
                end

                local carriers = {}
                local function carrierFor(src, visible)
                    if carriers[src] then return carriers[src] end
                    local rel = baseCF:ToObjectSpace(src.CFrame)
                    local c = src:Clone()
                    c:ClearAllChildren()
                    if visible then
                        for _, child in ipairs(src:GetChildren()) do
                            if child:IsA("DataModelMesh") or child:IsA("SurfaceAppearance")
                                or child:IsA("Decal") or child:IsA("Texture") then
                                child:Clone().Parent = c
                            end
                        end
                    else
                        c.Transparency = 1
                    end
                    c.Anchored = false
                    c.CanCollide = false
                    c.CanTouch = false
                    c.CanQuery = false
                    c.Massless = true
                    c.CFrame = hrp.CFrame * rel
                    c.Parent = container
                    local weld = Instance.new("Weld")
                    weld.Part0 = hrp
                    weld.Part1 = c
                    weld.C0 = rel
                    weld.Parent = c
                    carriers[src] = c
                    return c
                end

                local function targetFor(src)
                    if not src then return hrp end
                    local inAcc = inAccessory(src)
                    if BODY[src.Name] and not inAcc then
                        return resolveBody(character, src.Name)
                    end
                    local visible = (not inAcc) or (entry.keepAccessoryMeshes == true)
                    return carrierFor(src, visible)
                end

                local amap = {}
                local function attachmentFor(src)
                    if amap[src] then return amap[src] end
                    local target = targetFor(src:FindFirstAncestorWhichIsA("BasePart"))
                    if not target then return nil end
                    local existing = target:FindFirstChild(src.Name)
                    if existing and existing:IsA("Attachment") and not existing:GetAttribute("MilkAura") then
                        amap[src] = existing
                        return existing
                    end
                    local a = src:Clone()
                    a:ClearAllChildren()
                    a:SetAttribute("MilkAura", true)
                    a.Parent = target
                    created[#created + 1] = a
                    amap[src] = a
                    return a
                end

                local descendants = model:GetDescendants()

                -- floating visible parts (everything that is not the rig body)
                for _, d in ipairs(descendants) do
                    if d:IsA("BasePart") and not BODY[d.Name] then
                        if (not inAccessory(d)) or entry.keepAccessoryMeshes == true then
                            carrierFor(d, true)
                        end
                    end
                end

                -- effects
                local links = {}
                for _, d in ipairs(descendants) do
                    if EFFECT[d.ClassName] then
                        if d:IsA("Highlight") then
                            local h = d:Clone()
                            h.Adornee = character
                            h.Parent = container
                        else
                            local p = d.Parent
                            local parentInst
                            if p and p:IsA("Attachment") then
                                parentInst = attachmentFor(p)
                            elseif p and p:IsA("BasePart") then
                                parentInst = targetFor(p)
                            else
                                parentInst = hrp
                            end
                            if parentInst then
                                local c = d:Clone()
                                c.Parent = parentInst
                                created[#created + 1] = c
                                if c:IsA("Trail") or c:IsA("Beam") then
                                    links[#links + 1] = { c, d }
                                end
                            end
                        end
                    end
                end

                for _, pair in ipairs(links) do
                    local c, src = pair[1], pair[2]
                    pcall(function()
                        if src.Attachment0 then c.Attachment0 = attachmentFor(src.Attachment0) end
                        if src.Attachment1 then c.Attachment1 = attachmentFor(src.Attachment1) end
                    end)
                end

                if #created == 0 and #container:GetChildren() == 0 then
                    return fail("model has no aura parts")
                end

                return { container = container, created = created }
            end


            local selected, desired, gen = 1, false, 0
            local active = nil

            local function teardown(state)
                if not state then return end
                for _, inst in ipairs(state.created) do
                    pcall(function() inst:Destroy() end)
                end
                pcall(function() state.container:Destroy() end)
            end

            local function apply()
                gen += 1
                local my = gen
                task.spawn(function()
                    local old = active
                    active = nil
                    teardown(old)
                    if not desired then return end
                    local ch = player.Character
                    if ch then ch:WaitForChild("HumanoidRootPart", 5) end
                    if my ~= gen or not desired then return end
                    local entry = AURAS[selected]
                    local ok, state, err = pcall(build, selected, entry)
                    if not ok then
                        err = state
                        state = nil
                    end
                    if my ~= gen or not desired then
                        teardown(state)
                        return
                    end
                    if state then
                        active = state
                    else
                        desired = false
                        pcall(function() Library.Toggles.AuraEnable:SetValue(false) end)
                        pcall(function()
                            Library:Notify({ Title = "<b>Aura</b>", Description = labels[selected] .. ": " .. tostring(err), Time = 3 })
                        end)
                    end
                end)
            end

            EG:AddDropdown("AuraSelect", {
                Text = "Aura", Values = labels, Default = labels[1], Multi = false,
                Tooltip = "Pick an aura, then switch it on",
                Callback = function(v)
                    local i = indexOf[v]
                    if not i or i == selected then return end
                    selected = i
                    if desired then apply() end
                end,
            })
            EG:AddToggle("AuraEnable", {
                Text = "Aura", Default = false, Tooltip = "Wear the selected aura",
                Callback = function(on)
                    desired = on and true or false
                    apply()
                end,
            })

            local charConn = player.CharacterAdded:Connect(function(char)
                active = nil
                if not desired then return end
                char:WaitForChild("HumanoidRootPart", 10)
                task.wait(0.6)
                if desired then apply() end
            end)

            Library:OnUnload(function()
                desired = false
                gen += 1
                pcall(function() charConn:Disconnect() end)
                local old = active
                active = nil
                teardown(old)
            end)
        end)
        do
            local WS = game:GetService("Workspace")
            local brickColor = Color3.fromRGB(160, 65, 40)
            local brickOn = false
            local gen = 0
            local brickConn
            local saved = setmetatable({}, { __mode = "k" })
            local function isPlayerPart(part)
                if part:FindFirstAncestor("VisualMorph") then return true end
                for _, pl in ipairs(Players:GetPlayers()) do
                    local ch = pl.Character
                    if ch and part:IsDescendantOf(ch) then return true end
                end
                return false
            end
            local function applyBrick(part, myGen)
                if not brickOn or myGen ~= gen then return end
                if not part:IsA("BasePart") or part:IsA("Terrain") then return end
                if saved[part] or isPlayerPart(part) then return end
                local k = WS:FindFirstChild("LOCAL_KIRPICH")
                if k and part:IsDescendantOf(k) then return end
                local rec = { Color = part.Color, Material = part.Material, fx = {} }
                saved[part] = rec
                pcall(function()
                    part.Color = brickColor
                    part.Material = Enum.Material.Brick
                end)
                for _, o in ipairs(part:GetChildren()) do
                    if o:IsA("Texture") or o:IsA("Decal") then
                        rec.fx[o] = o.Transparency
                        o.Transparency = 1
                    end
                end
            end
            local function restoreAll(myGen)
                local list = {}
                for part in pairs(saved) do list[#list + 1] = part end
                for i, part in ipairs(list) do
                    if myGen ~= gen then return end
                    local rec = saved[part]
                    if rec then
                        saved[part] = nil
                        pcall(function()
                            part.Color = rec.Color
                            part.Material = rec.Material
                        end)
                        for o, tr in pairs(rec.fx) do
                            pcall(function() o.Transparency = tr end)
                        end
                    end
                    if i % 250 == 0 then task.wait() end
                end
            end
            local function setBrick(on)
                gen += 1
                local myGen = gen
                brickOn = on and true or false
                if brickConn then brickConn:Disconnect() brickConn = nil end
                if not brickOn then
                    task.spawn(restoreAll, myGen)
                    return
                end
                brickConn = WS.DescendantAdded:Connect(function(o)
                    if o:IsA("BasePart") then
                        task.wait()
                        applyBrick(o, myGen)
                    end
                end)
                task.spawn(function()
                    local n = 0
                    for _, o in ipairs(WS:GetDescendants()) do
                        if not brickOn or myGen ~= gen then return end
                        applyBrick(o, myGen)
                        n += 1
                        if n % 400 == 0 then task.wait() end
                    end
                end)
            end
            EG:AddToggle("BrickVisual", {
                Text = "Kirpich Visual", Default = false,
                Tooltip = "Turns the map into brick (players untouched)",
                Callback = function(on) setBrick(on) end,
            })
            Library:OnUnload(function() pcall(setBrick, false) end)
        end
        do
            local Players = game:GetService("Players")
            local RunService = game:GetService("RunService")
            local ContentProvider = game:GetService("ContentProvider")
            local player = Players.LocalPlayer
            local PLACEHOLDER = "rbxasset://textures/ui/GuiImagePlaceholder.png"
            local targetUserId, targetName = nil, nil
            local appliedUserId, appliedName = nil, nil
            local morphOn, applying, searchToken = false, false, 0
            local currentClone, animStop = nil, nil
            local morphConns, hidden = {}, {}
            local statusLbl, preview
            local setPreview, fetchBust
            local morph
            local function setStatus(t)
                if statusLbl then pcall(function() statusLbl:SetText(tostring(t)) end) end
            end
            EG:AddDivider()
            EG:AddInput("MorphNick", {
                Text = "Skin Nickname", Default = "", Placeholder = "nick or user ID...",
                Tooltip = "Type a nickname: the skin preview shows up below",
                Finished = false,
                Callback = function(v)
                    searchToken += 1
                    local my = searchToken
                    local name = tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if name == "" then
                        targetUserId, targetName = nil, nil
                        if setPreview then setPreview(PLACEHOLDER) end
                        setStatus("Enter a nickname")
                        return
                    end
                    task.spawn(function()
                        task.wait(0.6)
                        if my ~= searchToken then return end
                        setStatus("Searching...")
                        local userId, real
                        local num = tonumber(name)
                        if num then
                            local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(num) end)
                            if ok and n then userId, real = num, n end
                        end
                        if not userId then
                            local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(name) end)
                            if ok and id then userId, real = id, name end
                        end
                        if my ~= searchToken then return end
                        if not userId then
                            targetUserId, targetName = nil, nil
                            if setPreview then setPreview(PLACEHOLDER) end
                            setStatus("Player not found")
                            return
                        end
                        targetUserId, targetName = userId, real
                        local img = fetchBust and fetchBust(userId) or PLACEHOLDER
                        if my ~= searchToken then return end
                        if setPreview then setPreview(img) end
                        setStatus(real .. " (" .. userId .. ")")
                        if morphOn and appliedUserId ~= userId then
                            task.spawn(function() morph(userId, real) end)
                        end
                    end)
                end,
            })
            preview = EG:AddImage("MorphPreview", {
                Image = PLACEHOLDER, Height = 150, Color = Color3.new(1, 1, 1),
                Transparency = 0, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
            })
            statusLbl = EG:AddLabel({ Text = "Enter a nickname", DoesWrap = true })
            setPreview = function(img)
                if not preview then return end
                preview.Image = img
                local holder = preview.Holder
                local label = holder and holder:FindFirstChildWhichIsA("ImageLabel", true)
                if label then
                    label.Image = img
                    label.ImageColor3 = Color3.new(1, 1, 1)
                    label.ImageTransparency = 0
                    label.ImageRectOffset = Vector2.zero
                    label.ImageRectSize = Vector2.zero
                end
            end
            fetchBust = function(userId)
                for _ = 1, 5 do
                    local ok, content, ready = pcall(function()
                        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420)
                    end)
                    if ok and ready and type(content) == "string" and content ~= "" then return content end
                    task.wait(0.4)
                end
                return string.format("rbxthumb://type=AvatarBust&id=%d&w=420&h=420", userId)
            end
            local ANIMS = {
            	R15 = {
            		idle = "rbxassetid://507766666", walk = "rbxassetid://507777826", run = "rbxassetid://507767714",
            		jump = "rbxassetid://507765000", fall = "rbxassetid://507767968", climb = "rbxassetid://507765644",
            		swim = "rbxassetid://507784897", swimidle = "rbxassetid://507785072", sit = "rbxassetid://2506281703",
            	},
            	R6 = {
            		idle = "rbxassetid://180435571", walk = "rbxassetid://180426354", run = "rbxassetid://180426354",
            		jump = "rbxassetid://125750702", fall = "rbxassetid://180436148", climb = "rbxassetid://180436334",
            		swim = "rbxassetid://180426354", swimidle = "rbxassetid://180435571", sit = "rbxassetid://178130996",
            	},
            }

            local function newAnimator(char, realHum, clone, cloneHum)
            	local animator = cloneHum:FindFirstChildOfClass("Animator")
            	if not animator then
            		animator = Instance.new("Animator")
            		animator.Parent = cloneHum
            	end
            	local isR6 = cloneHum.RigType == Enum.HumanoidRigType.R6
            	local defs = isR6 and ANIMS.R6 or ANIMS.R15
            	local sameRig = realHum.RigType == cloneHum.RigType
            	local mirrorCache, defaultCache = {}, {}
            	local defaultKey, defaultTrack = nil, nil
            	local info = { mode = "none" }
            	local toolCache = {}

            	local function load(cache, id)
            		local t = cache[id]
            		if t ~= nil then return t or nil end
            		local anim = Instance.new("Animation")
            		anim.AnimationId = id
            		local ok, tr = pcall(function() return animator:LoadAnimation(anim) end)
            		if ok and tr then
            			cache[id] = tr
            			return tr
            		end
            		cache[id] = false
            		return nil
            	end

            	local function mirror()
            		local ok, tracks = pcall(function() return realHum:GetPlayingAnimationTracks() end)
            		if not ok then return 0 end
            		local seen, count = {}, 0
            		for _, rt in ipairs(tracks) do
            			local good, id = pcall(function() return rt.Animation and rt.Animation.AnimationId end)
            			if good and id and id ~= "" and rt.IsPlaying and rt.WeightCurrent > 0.02 then
            				local ct = load(mirrorCache, id)
            				if ct then
            					count = count + 1
            					seen[id] = true
            					local weight = math.max(rt.WeightCurrent, 0.05)
            					if not ct.IsPlaying then
            						pcall(function()
            							ct.Priority = rt.Priority
            							ct.Looped = rt.Looped
            						end)
            						ct:Play(0.1, weight, rt.Speed)
            					else
            						ct:AdjustWeight(weight, 0)
            						ct:AdjustSpeed(rt.Speed)
            					end
            					if rt.Length > 0 and math.abs(ct.TimePosition - rt.TimePosition) > 0.25 then
            						pcall(function() ct.TimePosition = rt.TimePosition end)
            					end
            				end
            			end
            		end
            		for id, ct in pairs(mirrorCache) do
            			if ct and ct.IsPlaying and not seen[id] then ct:Stop(0.15) end
            		end
            		return count
            	end

            	local function pickDefault()
            		local state = realHum:GetState()
            		local hrp = char:FindFirstChild("HumanoidRootPart")
            		local v = hrp and hrp.AssemblyLinearVelocity or Vector3.zero
            		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
            		local moving = realHum.MoveDirection.Magnitude > 0.1 and speed > 0.5
            		if state == Enum.HumanoidStateType.Jumping then return "jump", speed end
            		if state == Enum.HumanoidStateType.Freefall then return "fall", speed end
            		if state == Enum.HumanoidStateType.Climbing then return "climb", speed end
            		if state == Enum.HumanoidStateType.Swimming then return moving and "swim" or "swimidle", speed end
            		if state == Enum.HumanoidStateType.Seated then return "sit", speed end
            		if moving then return speed > 18 and "run" or "walk", speed end
            		return "idle", speed
            	end

            	local function playDefault()
            		local key, speed = pickDefault()
            		local tr = load(defaultCache, defs[key])
            		if not tr then
            			key = "idle"
            			tr = load(defaultCache, defs.idle)
            		end
            		if not tr then return false end
            		if defaultKey ~= key then
            			if defaultTrack then defaultTrack:Stop(0.2) end
            			defaultKey, defaultTrack = key, tr
            			tr:Play(0.2)
            		end
            		if key == "walk" or key == "run" then
            			tr:AdjustSpeed(math.clamp(speed / 14.5, 0.3, 3))
            		else
            			tr:AdjustSpeed(1)
            		end
            		return true
            	end

            	local function stopDefault()
            		if defaultTrack then
            			defaultTrack:Stop(0.15)
            			defaultTrack, defaultKey = nil, nil
            		end
            	end

            	local function copyTransforms()
            		for _, m in ipairs(char:GetDescendants()) do
            			if m:IsA("Motor6D") then
            				local cm = clone:FindFirstChild(m.Name, true)
            				if cm and cm:IsA("Motor6D") then cm.Transform = m.Transform end
            			end
            		end
            	end


            	local TOOLANIM = {
            		R6 = { hold = "rbxassetid://182393478", slash = "rbxassetid://129967390" },
            		R15 = { hold = "rbxassetid://507768375", slash = "rbxassetid://522635514" },
            	}
            	local toolDefs = isR6 and TOOLANIM.R6 or TOOLANIM.R15
            	local holdTrack, hookedTool, hookConn

            	local function stopTool()
            		if holdTrack and holdTrack.IsPlaying then holdTrack:Stop(0.15) end
            		if hookConn then hookConn:Disconnect() hookConn = nil end
            		hookedTool = nil
            	end

            	local function playTool()
            		local tool = char:FindFirstChildOfClass("Tool")
            		if not tool then
            			stopTool()
            			return
            		end
            		if not holdTrack then
            			holdTrack = load(toolCache, toolDefs.hold)
            			if holdTrack then
            				pcall(function()
            					holdTrack.Priority = Enum.AnimationPriority.Action
            					holdTrack.Looped = true
            				end)
            			end
            		end
            		if holdTrack and not holdTrack.IsPlaying then holdTrack:Play(0.15) end
            		if hookedTool ~= tool then
            			if hookConn then hookConn:Disconnect() end
            			hookedTool = tool
            			hookConn = tool.Activated:Connect(function()
            				if tool.Name ~= "Knife" then return end
            				local sl = load(toolCache, toolDefs.slash)
            				if not sl then return end
            				pcall(function()
            					sl.Priority = Enum.AnimationPriority.Action2
            					sl.Looped = false
            				end)
            				if sl.IsPlaying then sl:Stop(0) end
            				sl:Play(0.05)
            			end)
            		end
            	end

            	function info.step()
            		local mirrored = sameRig and mirror() or 0
            		if mirrored > 0 then
            			stopDefault()
            			stopTool()
            			info.mode = "copy"
            			return
            		end
            		if playDefault() then
            			playTool()
            			info.mode = "default"
            			return
            		end
            		if sameRig then
            			copyTransforms()
            			info.mode = "transform"
            		end
            	end

            	function info.stop()
            		stopTool()
            		for _, cache in ipairs({ mirrorCache, defaultCache, toolCache }) do
            			for _, t in pairs(cache) do
            				if t then pcall(function() t:Stop(0) end) end
            			end
            		end
            	end

            	return info
            end

            local function clearVisual()
            	for _, c in ipairs(morphConns) do pcall(function() c:Disconnect() end) end
            	table.clear(morphConns)
            	if animStop then
            		pcall(animStop)
            		animStop = nil
            	end
            	if currentClone then
            		pcall(function() currentClone:Destroy() end)
            		currentClone = nil
            	end
            	for _, v in ipairs(hidden) do
            		if v.Parent then pcall(function() v.LocalTransparencyModifier = 0 end) end
            	end
            	table.clear(hidden)
            end

            local function isHideable(v)
            	return (v:IsA("BasePart") or v:IsA("Decal")) and not v:FindFirstAncestorOfClass("Tool")
            end

            local function groundDist(hum, hrp)
            	if hum.HipHeight > 0 then return hum.HipHeight + hrp.Size.Y * 0.5 end
            	return 3
            end

            function morph(userId, name)
            	if applying then return end
            	applying = true

            	local char = player.Character
            	local realHRP = char and char:FindFirstChild("HumanoidRootPart")
            	local realHum = char and char:FindFirstChildOfClass("Humanoid")
            	if not realHRP or not realHum then
            		setStatus("No character")
            		applying = false
            		return
            	end

            	setStatus("Loading outfit...")
            	clearVisual()

            	local ok, clone = pcall(function() return Players:CreateHumanoidModelFromUserId(userId) end)
            	if not ok or not clone then
            		setStatus("Load error")
            		applying = false
            		return
            	end
            	local cloneHum = clone:FindFirstChildOfClass("Humanoid")
            	local cloneHRP = clone:FindFirstChild("HumanoidRootPart")
            	if not cloneHum or not cloneHRP then
            		clone:Destroy()
            		setStatus("Skin error")
            		applying = false
            		return
            	end

            	setStatus("Loading textures...")
            	pcall(function() ContentProvider:PreloadAsync(clone:GetDescendants()) end)
            	task.wait(0.6)

            	if player.Character ~= char or not realHRP.Parent or realHum.Health <= 0 then
            		clone:Destroy()
            		setStatus("Character changed, toggle again")
            		applying = false
            		return
            	end

            	clone.Name = "VisualMorph"
            	for _, v in ipairs(clone:GetDescendants()) do
            		if v:IsA("LuaSourceContainer") then v:Destroy() end
            	end
            	cloneHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            	cloneHum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
            	cloneHum.PlatformStand = true
            	pcall(function() cloneHum.EvaluateStateMachine = false end)

            	local parts = {}
            	for _, v in ipairs(clone:GetDescendants()) do
            		if v:IsA("BasePart") then
            			v.CanCollide = false
            			v.CanTouch = false
            			v.Massless = true
            			parts[#parts + 1] = v
            		end
            	end
            	local fpParts = {}
            	for _, v in ipairs(clone:GetDescendants()) do
            		if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
            			fpParts[#fpParts + 1] = v
            		end
            	end
            	local lastFP = nil
            	cloneHRP.Anchored = true
            	cloneHRP.CFrame = realHRP.CFrame

            	clone.Parent = workspace
            	currentClone = clone
            	RunService.Heartbeat:Wait()

            	local anim = newAnimator(char, realHum, clone, cloneHum)
            	animStop = anim.stop

            	table.clear(hidden)
            	for _, v in ipairs(char:GetDescendants()) do
            		if isHideable(v) then hidden[#hidden + 1] = v end
            	end
            	table.insert(morphConns, char.DescendantAdded:Connect(function(d)
            		if isHideable(d) then hidden[#hidden + 1] = d end
            	end))

            	table.insert(morphConns, RunService.RenderStepped:Connect(function()
            		if not clone.Parent or not realHRP.Parent then return end
            		cloneHRP.CFrame = realHRP.CFrame * CFrame.new(0, groundDist(cloneHum, cloneHRP) - groundDist(realHum, realHRP), 0)
            		for i = 1, #hidden do
            			local v = hidden[i]
            			if v.Parent then v.LocalTransparencyModifier = 1 end
            		end
            		anim.step()
            		local cam = workspace.CurrentCamera
            		local fp = cam ~= nil and (cam.CFrame.Position - cam.Focus.Position).Magnitude < 1.5
            		if fp ~= lastFP then
            			lastFP = fp
            			for i = 1, #fpParts do
            				local v = fpParts[i]
            				if v.Parent then pcall(function() v.LocalTransparencyModifier = fp and 1 or 0 end) end
            			end
            		end
            	end))
            	table.insert(morphConns, RunService.Stepped:Connect(function()
            		for i = 1, #parts do parts[i].CanCollide = false end
            	end))
            	table.insert(morphConns, realHum.Died:Connect(clearVisual))

            	appliedUserId, appliedName = userId, name
            	task.wait(0.3)
            	local modeText = anim.mode == "copy" and "anims: mirrored" or (anim.mode == "default" and "anims: default" or "anims: " .. anim.mode)
            	if realHum.RigType ~= cloneHum.RigType then
            		setStatus((name or "") .. " (R6/R15 differ, " .. modeText .. ")")
            	else
            		setStatus("Skin applied: " .. (name or "") .. " (" .. modeText .. ")")
            	end
            	applying = false
            end


            local charConn
            local function stopMorph()
                morphOn = false
                if charConn then charConn:Disconnect() charConn = nil end
                clearVisual()
                appliedUserId, appliedName = nil, nil
            end
            EG:AddToggle("MorphSkin", {
                Text = "Apply Skin", Default = false,
                Tooltip = "Visual only: others still see your real avatar",
                Callback = function(on)
                    if not on then
                        stopMorph()
                        setStatus(targetName and (targetName .. " (off)") or "Enter a nickname")
                        return
                    end
                    if not targetUserId then
                        setStatus("Find a player first")
                        morphOn = true
                    else
                        morphOn = true
                        task.spawn(morph, targetUserId, targetName)
                    end
                    if charConn then charConn:Disconnect() end
                    charConn = player.CharacterAdded:Connect(function(char)
                        clearVisual()
                        applying = false
                        task.spawn(function()
                            char:WaitForChild("HumanoidRootPart", 10)
                            char:WaitForChild("Humanoid", 10)
                            task.wait(0.8)
                            local id, nm = appliedUserId or targetUserId, appliedName or targetName
                            if morphOn and id and player.Character == char then
                                morph(id, nm)
                            end
                        end)
                    end)
                end,
            })
            Library:OnUnload(function() pcall(stopMorph) end)
        end
        espCleanup = function()
            esp.on = false
            espAlive = false
            espGui:Destroy()
        end
    end)
    Library:OnUnload(function()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        pcall(shaderCleanup)
        pcall(espCleanup)
    end)
end
do
    local UserInputService = game:GetService("UserInputService")
    local player = Players.LocalPlayer
    local accentColor = Color3.fromRGB(255, 255, 255)
    local connections = {}
    local function connect(signal, fn)
        local c = signal:Connect(fn)
        table.insert(connections, c)
        return c
    end
    local function create(className, props)
        local inst = Instance.new(className)
        local parent = props.Parent
        props.Parent = nil
        for k, v in pairs(props) do inst[k] = v end
        inst.Parent = parent
        return inst
    end
    local function tween(inst, t, props, dir, style)
        local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
        tw:Play()
        return tw
    end
    local function getHumanoid()
        local c = player.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end
    local config, loading = {}, false
    local function setConfig(key, v) config[key] = v end
    local function register() end
    local modelsTab = Tabs.Models
    local stopAura, stopSpin, stopAnims, stopCursor, stopSkinChanger
    local uid = 0
    local flip = {}
    local function nextId(prefix)
        uid += 1
        return "H_" .. prefix .. uid
    end
    local function addSection(tab, name, existingBox)
        local box = type(existingBox) == "table" and existingBox or nil
        if not box then
            flip[tab] = not flip[tab]
            box = flip[tab] and tab:AddLeftGroupbox(name, (getgenv().__KRP_ICONS or {})[name]) or tab:AddRightGroupbox(name, (getgenv().__KRP_ICONS or {})[name])
        end
        local S = { box = box }
        function S:Collapsible() return self end
        function S:Label(text)
            local l = box:AddLabel(getgenv().__KRP_TC(text), true, nextId("L"))
            return { SetText = function(t) pcall(function() l:SetText(t) end) end }
        end
        function S:Toggle(n, desc, cb)
            local id, mute = nextId("T"), false
            local t = box:AddToggle(id, {
                Text = getgenv().__KRP_TC(n), Tooltip = desc, Default = false,
                Callback = function(v) if not mute and cb then cb(v) end end,
            })
            return {
                Set = function(v, silent)
                    mute = silent and true or false
                    t:SetValue(v)
                    mute = false
                end,
                Get = function() return t.Value end,
            }
        end
        function S:Slider(n, min, max, default, cb, fmt)
            local id, mute = nextId("S"), false
            local s = box:AddSlider(id, {
                Text = getgenv().__KRP_TC(n), Default = default, Min = min, Max = max, Rounding = 0,
                FormatDisplayValue = fmt and function(_, v) return fmt(v) end or nil,
                Callback = function(v) if not mute and cb then cb(v) end end,
            })
            return {
                Set = function(v, silent)
                    mute = silent and true or false
                    s:SetValue(v)
                    mute = false
                end,
                Get = function() return s.Value end,
            }
        end
        local function dropdown(n, options, default, cb)
            local id, mute = nextId("D"), false
            local d = box:AddDropdown(id, {
                Text = getgenv().__KRP_TC(n), Values = options, Default = default,
                Callback = function(v) if not mute and cb then cb(v) end end,
            })
            return {
                Set = function(v, silent)
                    mute = silent and true or false
                    d:SetValue(v)
                    mute = false
                end,
                SetValues = function(vals) d:SetValues(vals) end,
                Get = function() return d.Value end,
            }
        end
        function S:Select(n, desc, options, default, cb) return dropdown(n, options, default, cb) end
        function S:Segmented(n, options, default, cb) return dropdown(n, options, default, cb) end
        function S:Button(n, desc, cb)
            box:AddButton({ Text = getgenv().__KRP_TC(n), Tooltip = desc, Func = cb })
        end
        function S:ColorPicker(n, desc, default, cb)
            local id, mute = nextId("C"), false
            box:AddLabel(getgenv().__KRP_TC(n)):AddColorPicker(id, {
                Default = default, Title = getgenv().__KRP_TC(n),
                Callback = function(c) if not mute and cb then cb(c) end end,
            })
            return {
                Set = function(c, silent)
                    mute = silent and true or false
                    Options[id]:SetValueRGB(c)
                    mute = false
                end,
                Get = function() return Options[id].Value end,
            }
        end
        return S
    end
    runBlock("aura", function()
    	local aura = {
    		on = false,
    		style = "Energy",
    		custom = Color3.fromRGB(105, 205, 255),
    		intensity = 55,
    		size = 100,
    	}
    	local auraRoot
    	local auraObjects = {}
    	local emitters = {}
    	local auraLight
    	local auraHighlight
    	local rainbowAt = 0
    	local function track(inst)
    		table.insert(auraObjects, inst)
    		return inst
    	end
    	local function clear()
    		for _, inst in ipairs(auraObjects) do
    			if inst.Parent then
    				inst:Destroy()
    			end
    		end
    		table.clear(auraObjects)
    		table.clear(emitters)
    		auraRoot, auraLight, auraHighlight = nil, nil, nil
    	end
    	local function styleColor()
    		if aura.style == "Flame" then
    			return Color3.fromRGB(255, 92, 34)
    		elseif aura.style == "Frost" then
    			return Color3.fromRGB(125, 225, 255)
    		elseif aura.style == "Void" then
    			return Color3.fromRGB(145, 65, 255)
    		elseif aura.style == "Rainbow" then
    			return Color3.fromHSV(os.clock() * 0.15 % 1, 0.85, 1)
    		elseif aura.style == "Custom" then
    			return aura.custom
    		end
    		return Color3.fromRGB(105, 205, 255)
    	end
    	local function addEmitter(parent, secondary)
    		local scale = aura.size / 100
    		local rate = aura.intensity * (secondary and 0.18 or 0.42)
    		local texture = "rbxasset://textures/particles/sparkles_main.dds"
    		local speed = NumberRange.new(0.45, 1.5)
    		local acceleration = Vector3.new(0, 1.2, 0)
    		local lifetime = NumberRange.new(0.65, 1.25)
    		local size
    		if aura.style == "Flame" and not secondary then
    			texture = "rbxasset://textures/particles/fire_main.dds"
    			speed = NumberRange.new(1.2, 2.8)
    			acceleration = Vector3.new(0, 3.5, 0)
    			size = NumberSequence.new({
    				NumberSequenceKeypoint.new(0, 0.7 * scale),
    				NumberSequenceKeypoint.new(0.55, 1.5 * scale),
    				NumberSequenceKeypoint.new(1, 0),
    			})
    		elseif aura.style == "Void" and not secondary then
    			texture = "rbxasset://textures/particles/smoke_main.dds"
    			speed = NumberRange.new(0.2, 0.8)
    			acceleration = Vector3.new(0, 1.8, 0)
    			lifetime = NumberRange.new(1, 1.8)
    			size = NumberSequence.new({
    				NumberSequenceKeypoint.new(0, 1.1 * scale),
    				NumberSequenceKeypoint.new(0.65, 2.1 * scale),
    				NumberSequenceKeypoint.new(1, 0),
    			})
    		elseif aura.style == "Frost" and not secondary then
    			texture = "rbxasset://textures/particles/smoke_main.dds"
    			speed = NumberRange.new(0.15, 0.65)
    			acceleration = Vector3.new(0, -0.7, 0)
    			lifetime = NumberRange.new(0.9, 1.6)
    			size = NumberSequence.new({
    				NumberSequenceKeypoint.new(0, 0.65 * scale),
    				NumberSequenceKeypoint.new(0.7, 1.35 * scale),
    				NumberSequenceKeypoint.new(1, 0),
    			})
    		else
    			size = NumberSequence.new({
    				NumberSequenceKeypoint.new(0, (secondary and 0.22 or 0.42) * scale),
    				NumberSequenceKeypoint.new(0.5, (secondary and 0.13 or 0.7) * scale),
    				NumberSequenceKeypoint.new(1, 0),
    			})
    		end
    		local color = styleColor()
    		local emitter = track(create("ParticleEmitter", {
    			Name = secondary and "RockHubAuraSparks" or "RockHubAuraCore",
    			Texture = texture,
    			Rate = rate,
    			Lifetime = lifetime,
    			Speed = speed,
    			Acceleration = acceleration,
    			SpreadAngle = Vector2.new(180, 180),
    			Rotation = NumberRange.new(0, 360),
    			RotSpeed = NumberRange.new(-100, 100),
    			LightEmission = aura.style == "Void" and 0.15 or 0.85,
    			LightInfluence = 0,
    			Size = size,
    			Transparency = NumberSequence.new({
    				NumberSequenceKeypoint.new(0, secondary and 0.05 or 0.2),
    				NumberSequenceKeypoint.new(0.75, 0.45),
    				NumberSequenceKeypoint.new(1, 1),
    			}),
    			Color = ColorSequence.new(color),
    			Parent = parent,
    		}))
    		table.insert(emitters, emitter)
    	end
    	local function build()
    		clear()
    		if not aura.on then
    			return
    		end
    		local char = player.Character
    		local root = char and char:FindFirstChild("HumanoidRootPart")
    		local hum = char and char:FindFirstChildOfClass("Humanoid")
    		if not root or not hum or hum.Health <= 0 then
    			return
    		end
    		auraRoot = root
    		local bottom = track(create("Attachment", { Name = "RockHubAuraBottom", Position = Vector3.new(0, -1.5, 0), Parent = root }))
    		local center = track(create("Attachment", { Name = "RockHubAuraCenter", Position = Vector3.new(0, 0.45, 0), Parent = root }))
    		addEmitter(bottom, false)
    		addEmitter(center, true)
    		local color = styleColor()
    		auraLight = track(create("PointLight", {
    			Name = "RockHubAuraLight",
    			Color = color,
    			Brightness = 0.8 + aura.intensity / 45,
    			Range = 7 + aura.size / 30,
    			Shadows = false,
    			Parent = root,
    		}))
    		auraHighlight = track(create("Highlight", {
    			Name = "RockHubAuraHighlight",
    			Adornee = char,
    			DepthMode = Enum.HighlightDepthMode.Occluded,
    			FillColor = color,
    			FillTransparency = 0.92,
    			OutlineColor = color,
    			OutlineTransparency = 0.35,
    			Parent = char,
    		}))
    	end
    	connect(player.CharacterAdded, function()
    		if aura.on then
    			task.delay(0.4, build)
    		end
    	end)
    	connect(RunService.Heartbeat, function()
    		if not aura.on then
    			return
    		end
    		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    		if not root then
    			if auraRoot then
    				clear()
    			end
    			return
    		end
    		if auraRoot ~= root or not auraRoot.Parent then
    			build()
    			return
    		end
    		local now = os.clock()
    		if aura.style ~= "Rainbow" or now - rainbowAt < 0.06 then
    			return
    		end
    		rainbowAt = now
    		local hue = now * 0.16 % 1
    		local c1 = Color3.fromHSV(hue, 0.9, 1)
    		local c2 = Color3.fromHSV((hue + 0.16) % 1, 0.9, 1)
    		local sequence = ColorSequence.new(c1, c2)
    		for _, emitter in ipairs(emitters) do
    			emitter.Color = sequence
    		end
    		auraLight.Color = c1
    		auraHighlight.FillColor = c1
    		auraHighlight.OutlineColor = c2
    	end)
    	local sec = addSection(modelsTab, "Effects", getgenv().__KRP_VIS_FX)
    	sec:Toggle("Aura", "particles and glow around your character", function(on)
    		aura.on = on
    		build()
    	end)
    	sec:Select("Style", "right click - previous", { "Energy", "Flame", "Frost", "Void", "Rainbow", "Custom" }, aura.style, function(v)
    		aura.style = v
    		if aura.on then
    			build()
    		end
    	end)
    	sec:ColorPicker("Aura Color", "used when Style = Custom", aura.custom, function(c)
    		aura.custom = c
    		if not loading then
    			aura.style = "Custom"
    		end
    		if aura.on then
    			build()
    		end
    	end)
    	sec:Slider("Intensity", 10, 100, aura.intensity, function(v)
    		aura.intensity = v
    		if aura.on then
    			build()
    		end
    	end, function(v)
    		return v .. "%"
    	end)
    	sec:Slider("Size", 50, 200, aura.size, function(v)
    		aura.size = v
    		if aura.on then
    			build()
    		end
    	end, function(v)
    		return v .. "%"
    	end)
    	stopAura = function()
    		aura.on = false
    		clear()
    	end
    end)
    runBlock("bhop", function()
    	local bhop = { on = false, mode = "Hold Space", max = 60, gain = 8 }
    	local hops = 0
    	local landedAt = 0
    	local lastJump = 0
    	local inAir = false
    	local baseFov
    	local function resetBhop()
    		hops = 0
    		local cam = workspace.CurrentCamera
    		if baseFov and cam then
    			tween(cam, 0.3, { FieldOfView = baseFov })
    		end
    	end
    	connect(RunService.Heartbeat, function()
    		if not bhop.on then
    			return
    		end
    		local char = player.Character
    		local hrp = char and char:FindFirstChild("HumanoidRootPart")
    		local hum = char and char:FindFirstChildOfClass("Humanoid")
    		if not hrp or not hum or hum.Health <= 0 then
    			return
    		end
    		local moving = hum.MoveDirection.Magnitude > 0.1
    		local want = bhop.mode == "Auto" and moving or bhop.mode == "Hold Space" and UserInputService:IsKeyDown(Enum.KeyCode.Space)
    		local grounded = hum.FloorMaterial ~= Enum.Material.Air
    		local now = os.clock()
    		if grounded then
    			if inAir then
    				landedAt = now
    			end
    			inAir = false
    			if want and moving then
    				if now - lastJump > 0.2 then
    					lastJump = now
    					hops += 1
    					hum:ChangeState(Enum.HumanoidStateType.Jumping)
    				end
    			elseif now - landedAt > 0.25 or not moving then
    				if hops > 0 then
    					resetBhop()
    				end
    			end
    		else
    			inAir = true
    			if moving and hops > 0 then
    				local speed = math.min(hum.WalkSpeed + hops * bhop.gain * 0.5, bhop.max)
    				local dir = hum.MoveDirection.Unit
    				local v = hrp.AssemblyLinearVelocity
    				hrp.AssemblyLinearVelocity = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
    				local cam = workspace.CurrentCamera
    				if cam then
    					baseFov = baseFov or cam.FieldOfView
    					local k = math.clamp((speed - hum.WalkSpeed) / math.max(bhop.max - hum.WalkSpeed, 1), 0, 1)
    					cam.FieldOfView = cam.FieldOfView + (baseFov + 12 * k - cam.FieldOfView) * 0.15
    				end
    			end
    		end
    	end)
    	local sec = addSection(Tabs.Main, "Player", getgenv().__KRP_PLAYER_BOX or Sink)
    	sec:Toggle("Bunny Hop", "bunny hop - every jump makes you faster", function(on)
    		bhop.on = on
    		if not on then
    			resetBhop()
    		end
    	end)
    	sec:Segmented("Bhop Mode", { "Hold Space", "Auto" }, bhop.mode, function(v)
    		bhop.mode = v
    	end)
    	sec:Slider("Bhop Max Speed", 30, 150, bhop.max, function(v)
    		bhop.max = v
    	end)
    	sec:Slider("Bhop Gain Per Hop", 2, 20, bhop.gain, function(v)
    		bhop.gain = v
    	end)
    end)
    runBlock("spin", function()
    	local spin = { on = false, speed = 10, dir = "Right" }
    	local spinHum
    	connect(RunService.Heartbeat, function(dt)
    		if not spin.on then
    			return
    		end
    		local char = player.Character
    		local hrp = char and char:FindFirstChild("HumanoidRootPart")
    		local hum = getHumanoid()
    		if not hrp or not hum or hum.Health <= 0 then
    			return
    		end
    		if hum.AutoRotate then
    			hum.AutoRotate = false
    		end
    		spinHum = hum
    		local w = spin.speed * 1.5 * (spin.dir == "Right" and -1 or 1)
    		hrp.CFrame *= CFrame.Angles(0, w * dt, 0)
    	end)
    	local function stop()
    		if spinHum and spinHum.Parent then
    			spinHum.AutoRotate = true
    		end
    		spinHum = nil
    	end
    	local sec = addSection(Tabs.Main, "Player", getgenv().__KRP_PLAYER_BOX or Sink)
    	sec:Toggle("Spin", "spin your character around", function(on)
    		spin.on = on
    		if not on then
    			stop()
    		end
    	end)
    	sec:Slider("Spin Speed", 1, 30, spin.speed, function(v)
    		spin.speed = v
    	end, function(v)
    		return v .. "x"
    	end)
    	sec:Segmented("Spin Direction", { "Left", "Right" }, spin.dir, function(v)
    		spin.dir = v
    	end)
    	stopSpin = function()
    		spin.on = false
    		stop()
    	end
    end)
    runBlock("FREE ANIMS", function()
        local emotes = {
        	{ 3360689775, "Salute", false },
        	{ 3360692915, "Tilt", false },
        	{ 5915779043, "Applaud", false },
        	{ 3576968026, "Shrug", false },
        	{ 3360686498, "Stadium", false },
        	{ 3576686446, "Hello", false },
        	{ 3576823880, "Point2", false },
        	{ 3716636630, "Monkey", false },
        	{ 4646306583, "Curtsy", false },
        	{ 4849499887, "Happy", false },
        	{ 3823158750, "Godlike", false },
        	{ 14353423348, "Baby Queen - Bouncy Twirl", false },
        	{ 4689362868, "Sleep", false },
        	{ 3576717965, "Shy", false },
        	{ 14353421343, "Baby Queen - Face Frame", false },
        	{ 5917570207, "Floss Dance", false },
        	{ 5104377791, "Hero Landing", false },
        	{ 15610015346, "Yungblud Happier Jump", false },
        	{ 7466046574, "Quiet Waves", false },
        	{ 5230661597, "Bored", false },
        	{ 14353425085, "Baby Queen - Strut", false },
        	{ 5915776835, "High Wave", false },
        	{ 12507097350, "Alo Yoga Pose - Lotus Position", false },
        	{ 4940597758, "Cower", false },
        	{ 4272484885, "Baby Dance", false },
        	{ 101573394483995, "Effortless Aura Pose", false },
        	{ 76361248833307, "Godly Aura fly pose idle", false },
        	{ 3994127840, "Celebrate", false },
        	{ 132384701706046, "💀MM2 Fake Dead", false },
        	{ 10214418283, "V Pose - Tommy Hilfiger", false },
        	{ 104131847054135, "Jamal Brazil Groove", true },
        	{ 16553249658, "Mae Stephens - Piano Hands", false },
        	{ 10214406616, "Frosty Flair - Tommy Hilfiger", false },
        	{ 139021427684680, "KATSEYE - Touch", false },
        	{ 4849502101, "Sad", false },
        	{ 4102315500, "Haha", false },
        	{ 15698511500, "Cuco - Levitate", false },
        	{ 106708015414624, "Endless Aura Floating", false },
        	{ 3762654854, "Greatest", false },
        	{ 98603994713783, "Rat Dance", false },
        	{ 15554010118, "Olivia Rodrigo Head Bop", false },
        	{ 93511411593120, "/e fly", false },
        	{ 105381637724646, "🎃Pumpkin King👑", false },
        	{ 71302743123422, "Popular", false },
        	{ 88425531063616, "Stylish Floating", false },
        	{ 104142334418357, "[BEST] It's Gangnam Style!", false },
        	{ 4049646104, "Line Dance", false },
        	{ 120642514156293, "Secret Handshake Dance", false },
        	{ 111378664166805, "Moonwalk", true },
        	{ 80963950541052, "hip sway", false },
        	{ 7202898984, "Show Dem Wrists - KSI", false },
        	{ 5938394742, "Old Town Road Dance - Lil Nas X (LNX)", false },
        	{ 74716792202343, "🕷️ Hornet's Spider Dance 🕷️", false },
        	{ 4940592718, "Confused", false },
        	{ 15679955281, "Festive Dance", false },
        	{ 115203580644128, "⚡ Raiden Punching Armstrong Loop", false },
        	{ 79312439851071, "Chappell Roan HOT TO GO!", false },
        	{ 3762641826, "Side to Side", false },
        	{ 5230615437, "Beckon", false },
        	{ 130371895389423, "[BEST] Invisiblity", false },
        	{ 107282826166809, "Basketball Head", false },
        	{ 79017619155911, "Wall Phase (GLITCH)", true },
        	{ 125328720114284, "Nervy Dance", true },
        	{ 113702736944973, "Yuji Jumping Edit", true },
        	{ 4272351660, "Fast Hands", false },
        	{ 97164262994588, "Floating in Love 🥰", false },
        	{ 16572756230, "HIPMOTION - Amaarae", false },
        	{ 78224683906191, "Cute Feet Kicking", false },
        	{ 82727664018494, "Lush Life", false },
        	{ 5938365243, "Dolphin Dance", false },
        	{ 70919402339484, "Scuba Nick Wilde", true },
        	{ 95325218641213, "Psycho Teddy", true },
        	{ 15506503658, "Victory Dance", false },
        	{ 4940602656, "Jumping Wave", false },
        	{ 108635834286627, "Spiderman Hang", false },
        	{ 5915773992, "Break Dance", false },
        	{ 3934986896, "Dizzy", false },
        	{ 136648387080677, "DARE - Gorillaz", false },
        	{ 111426928948833, "Floating on clouds", false },
        	{ 127764273000599, "Dropkick", false },
        	{ 137234266130963, "MJ - P.Y.T. Pretty Young Thing", false },
        	{ 17746270218, "Sturdy Dance - Ice Spice", false },
        	{ 3716633898, "Twirl", false },
        	{ 129149402922241, "griddy", false },
        	{ 94064805002669, "Cute Kawaii Posing >-<", false },
        	{ 139058906415119, "Floating", false },
        	{ 94292601332790, ";invisible me", false },
        	{ 4212496830, "Zombie", false },
        	{ 75911227509248, "Ghost Floating", false },
        	{ 79127989560307, "Moon Walk", false },
        	{ 89157328525577, "silly jumping spider dance", false },
        	{ 5938396308, "HOLIDAY Dance - Lil Nas X (LNX)", false },
        	{ 120904242187887, "🤣 GOOFY FLAP FLY ANIME - FUNNY MEME", true },
        	{ 107708114415320, "Big Guy - 🔥 Ice Spice x Spongebob", false },
        	{ 132367660388476, "SHAKE", false },
        	{ 14353417553, "Baby Queen - Air Guitar & Knee Slide", false },
        	{ 138515241510970, "Cute kawaii girly idle Profile pose", false },
        	{ 76261461321661, "★ curiously cute sitting pose", false },
        	{ 4391208058, "Shuffle", false },
        	{ 88859617281337, "WOOF BARK WOOF", false },
        	{ 10370922566, "Sidekicks - George Ezra", false },
        	{ 103040723950430, "Gojo Floating JJK/ The Honored One", false },
        	{ 82995540773684, "Tornado", false },
        	{ 3994130516, "Bodybuilder", false },
        	{ 13823339506, "Tommy - Archer", false },
        	{ 4849487550, "Agree", false },
        	{ 79216795769647, "Tall Scary Creature", false },
        	{ 83917238288783, "cute dancy dance", true },
        	{ 122147154162464, "Hakari Dance", false },
        	{ 118853736905967, "Wall Aura Farm Pose", false },
        	{ 4849497510, "Power Blast", false },
        	{ 15123050663, "Bone Chillin' Bop", false },
        	{ 103102322875221, "Skibidi Toilet - Titan Speakerman Laser Spin", false },
        	{ 133685484220846, "KATSEYE - GNARLY", false },
        	{ 117119421748582, "Jamal Brazil Groove", true },
        	{ 111539333518905, "Needy V sit Split Drop (OG) 🔮", true },
        	{ 72947568152049, "Cute Sit", false },
        	{ 14353419229, "Baby Queen - Dramatic Bow", false },
        	{ 3576745472, "Fashionable", false },
        	{ 106370760824973, "Possessed Glitcher", false },
        	{ 98388724133440, "[OG] i got that feeling 💌", true },
        	{ 122740406985544, "Fly Aura pose", true },
        	{ 80573839869810, "Kneeling Sit", true },
        	{ 89360359553814, "Sunflower", true },
        	{ 73181508272121, "Party Funk", true },
        	{ 73049975726252, "Yeah, Im Listening...", true },
        	{ 121621458064078, "Wish Nle Choppa", true },
        	{ 123838228516868, "[Limited] Cute Crying Beg Kneeling", true },
        	{ 126941778232900, "♡ kawaii sit emote with cat paws", true },
        	{ 116416944161215, "♡ kawaii schoolgirl sitting pose", true },
        	{ 76598468338330, "Fall From The Sky", true },
        	{ 88456688900525, "Reanimated 🎃", true },
        	{ 77080714986256, "Moving Like Berney", true },
        	{ 77016426916262, "Rich Girl Flowside", true },
        	{ 108039409530319, "Runway Victoria Fashion Model", true },
        	{ 137636136946673, "Tubo Dance", true },
        	{ 87433588393157, "Cute Bouncy Side Sway", true },
        	{ 131145074585836, "Viltrum Hovering Aura Farm (Invincible)", true },
        	{ 82831170082875, "Stopframe: Puppet Panic", true },
        	{ 98094482524931, "Met my match [Say Now]", true },
        	{ 96059912242002, "Them Hips", true },
        	{ 79087653980931, "Master Lord Verity Setalcix", true },
        	{ 73710784930636, "Cry for Me - [TREND] IronMouse", true },
        	{ 121132556900708, "Floating Aura", true },
        	{ 99246819283563, "Goofball Griddy [MOCAP]", true },
        	{ 128814921948602, "Super Funk Dance", true },
        	{ 104751376138396, "Worm Infinite Roll", true },
        	{ 87636335269696, "Consegue dançar igual ?", true },
        	{ 121793928888678, "cute bratty whiny adorable girl sit pose", true },
        	{ 83161594745131, "⏳[BEST] I'M A DEMON WITH THIS 😈", true },
        	{ 90418129403506, "Relaxed Cloud Floating", true },
        	{ 86938925857615, "Superhero Pose", true },
        	{ 90923883214225, "Master Of Humanity!", true },
        	{ 122249198697121, "Nameless monster dance", true },
        	{ 140461713742908, "He Pedals Funk Emote", true },
        	{ 76618267763261, "𑣲 KISS N TELL - AESPA", true },
        	{ 93647110985355, "Scuba [FULL VERSION]", true },
        	{ 73148982402007, "Fake Running Disconnect lag", true },
        	{ 82966937735800, "I got that feeling trend", true },
        	{ 90121297911534, "Jeyke Funk", true },
        	{ 98840627727488, "Peaches - Justin Bieber", true },
        	{ 126178027638785, "Tinashe - Nasty Girl", true },
        	{ 98049374819131, "Diego - Jojo Anime Pose", true },
        	{ 114800420888775, "Pennywise Dance 👹🤡", true },
        	{ 135157485603506, "[⭐] Scubaa Scubaa", true },
        	{ 105765738022096, "♡ : Cutesy standing doll pose", true },
        	{ 131171992525098, "One Arm Push Ups", true },
        	{ 101582120044688, "sweet puppy girl kicking leg profile pose", true },
        	{ 81708325562195, "Cute Needy Happy Shake Dance", true },
        	{ 105201400407575, "Cute Happy Bouncy Jumps Dance", true },
        	{ 81346143283632, "needy kawaii puppy sitting profile pose", true },
        	{ 71819053016074, "[BEST] i got that feeling MM2", true },
        	{ 116521788694479, "🔥 The Bass Trend", true },
        	{ 73757246494324, "Werewolf Alpha Transformation - Halloween", true },
        	{ 126498185656790, "Happy Bounce", true },
        	{ 78623311762574, "WestPole Emote [OG]", true },
        	{ 97926971484337, "12 to 12 [PERFECT]", true },
        	{ 96403455275692, "Trend Dance of Lord Verity", true },
        	{ 94724645460262, "The worm move", true },
        	{ 128779345795509, "Alien goofy wave✨", true },
        	{ 97052459488169, "Feeling myself emote", true },
        	{ 120918501233808, "Funy tubo dance", true },
        	{ 134942500171655, "Pathetic Cat (Furry)", true },
        	{ 129965107667269, "Lagui pose", true },
        	{ 93072647185531, "🔥 Dorobo Dance [V2]", true },
        	{ 103722701410933, "Brazilian Dance Viral Trend", true },
        	{ 110569633730333, "Lord Verity dance! (Emote)", true },
        	{ 88160454118928, "[BEST] Salsa", true },
        	{ 123604753182408, "ADELA - Nicole Kidman", true },
        	{ 110059706944899, "im a demon with this nh (balenci balenci) Dance", true },
        	{ 140594655288573, "Mangarap Dance", true },
        	{ 91914407217006, "The Bass Trend V2", true },
        	{ 90960483742655, "MM2 fake death pose (unique)", true },
        	{ 139324301384120, "Cute anime girl pose (cute)", true },
        	{ 117343790961625, "BLACKPINK ROSÉ - On The Ground", true },
        	{ 128860586829249, "anime dance", true },
        	{ 119998025796052, "Super Needy Jiggly Shake Dance", true },
        	{ 89733893354683, "Cute Bouncy Shake Dance", true },
        	{ 102174264026632, "GG Animation", true },
        	{ 86375122997153, "still idle", true },
        	{ 112654855034352, "Green Lantern Aura Pose", true },
        	{ 132600795042399, "Bby Wow trend", true },
        	{ 73193222304259, "Jamal Dance 3.0", true },
        	{ 87663078346140, "Halloween Vampire ´ཀ` Zombie ҂ Coffin Crawl Pose", true },
        	{ 99311131968819, "Stopframe: Sneaky Shuffle", true },
        	{ 138127306398554, "Confident Flying Aura Farming", true },
        	{ 106724593413222, "Cutsey Flying Aura 💕", true },
        	{ 122901201145982, "Emo Floating Aura", true },
        	{ 132697034165623, "🤡💀 Murder Mystery 2 OOF 💀🤡", true },
        	{ 108435804337942, "Murder Mystery 2 💀👹🥹🤡", true },
        	{ 109436261994235, "Shy Vampire", true },
        	{ 100120361806075, "MM2 💀🤡", true },
        	{ 94897348118820, "MM2 💀😭😵🤡", true },
        	{ 104120919345158, "♡ cute halloween headless holding your head pose", true },
        	{ 96021230764442, "[OG] Milwaukee Bounce", true },
        	{ 116215733070133, "Just Wanna Rock (Lil Uzi Vert)", true },
        	{ 125450302010193, "💀 L Dance", true },
        	{ 108395206588249, "💀mm2 fake side lay", true },
        	{ 91339094607949, "Ballerina Spin", true },
        	{ 91341416163208, "Cute Sitting", true },
        	{ 82555721533394, "Choo Choo TRAIN", true },
        	{ 117498793976482, "Snowman Dance - Left", true },
        	{ 123032739590624, "Snowman Dance - Right", true },
        	{ 83190195248548, "Boredom", true },
        	{ 106393319667237, "\"Don't Stop Til' You Get Enough\" Music Video Intro", true },
        	{ 79729995051649, "Chedder Bbq Wavy Sour Cream and Onion /Trend Dance", true },
        	{ 111937410622410, "Balance balance", true },
        	{ 126198554443561, "I had a hunch", true },
        	{ 110870173502552, "ghostly possession, pose, aura", true },
        	{ 133537618008799, "Toxic Laugh", true },
        	{ 71555837867329, "NPC Greeting", true },
        	{ 80160023079097, "[Mini Me] Gangnam Style", true },
        	{ 80069514148007, "Vezna Idle Animation", true },
        	{ 113267287854914, "cute kawaii sit", true },
        	{ 119535274797446, "Press F to inspect", true },
        	{ 76934438548184, "Kangaroo Dance King Aura", true },
        	{ 138032573559043, "Orange Caramel Chaewon Catallena Dance", true },
        	{ 95654893473488, "Passinho do Jamal 🇧🇷 Mandrake", true },
        	{ 99399545142101, "Headless Swap", true },
        	{ 99576158170768, "Everybody - Backstreet Boys", true },
        }
        local function idStr(id)
        	return string.format("%.0f", id)
        end
        local emoteList = {}
        for _, r in ipairs(emotes) do
            table.insert(emoteList, { id = r[1], name = r[2], new = r[3], kind = "e" })
        end
        local animCache = {}
        local function loadAnims(assetId)
        	if animCache[assetId] then
        		return animCache[assetId]
        	end
        	local ok, objs = pcall(function()
        		return game:GetObjects("rbxassetid://" .. idStr(assetId))
        	end)
        	if not ok or type(objs) ~= "table" then
        		return {}
        	end
        	local anims = {}
        	for _, o in ipairs(objs) do
        		local list = o:GetDescendants()
        		table.insert(list, 1, o)
        		for _, a in ipairs(list) do
        			if a:IsA("Animation") and a.AnimationId ~= "" then
        				table.insert(anims, { slot = a.Parent and a.Parent.Name:lower() or "", name = a.Name, id = a.AnimationId })
        			end
        		end
        	end
        	table.sort(anims, function(x, y)
        		return x.name < y.name
        	end)
        	animCache[assetId] = anims
        	return anims
        end
        local emoteTrack
        local emoteAnims = {}
        local function stopEmote()
        	if emoteTrack then
        		pcall(function()
        			emoteTrack:Stop(0.2)
        		end)
        		emoteTrack = nil
        	end
        end
        local function playEmote(e)
        	local hum = getHumanoid()
        	if not hum then
        		return
        	end
        	task.spawn(function()
        		local menuSeq2 = emoteAnims[e.id]
        		if not menuSeq2 then
        			local list = loadAnims(e.id)
        			menuSeq2 = list[1] and list[1].id
        			emoteAnims[e.id] = menuSeq2
        		end
        		stopEmote()
        		if menuSeq2 then
        			local anim = Instance.new("Animation")
        			anim.AnimationId = menuSeq2
        			local animator = hum:FindFirstChildOfClass("Animator") or hum
        			local ok, tr = pcall(function()
        				return animator:LoadAnimation(anim)
        			end)
        			if ok and tr then
        				tr.Priority = Enum.AnimationPriority.Action
        				tr.Looped = true
        				tr:Play(0.2)
        				emoteTrack = tr
        				return
        			end
        		end
        		local ok, _, tr = pcall(function()
        			return hum:PlayEmoteAndGetAnimTrackById(e.id)
        		end)
        		if ok and tr then
        			emoteTrack = tr
        		end
        	end)
        end
        connect(RunService.Heartbeat, function()
        	if emoteTrack then
        		local hum = getHumanoid()
        		if hum and hum.MoveDirection.Magnitude > 0.1 then
        			stopEmote()
        		end
        	end
        end)
        stopAnims = function()
            stopEmote()
        end
        connect(player.CharacterAdded, function()
            emoteTrack = nil
        end)
        local emoteLabels, emoteByLabel = {}, {}
        for _, e in ipairs(emoteList) do
            local label = e.name
            if emoteByLabel[label] then label = label .. " (" .. tostring(e.id) .. ")" end
            emoteByLabel[label] = e
            table.insert(emoteLabels, label)
        end
        local emoSec = addSection(Tabs.Anims, "Emotes")
        local curEmote = emoteLabels[1]
        emoSec:Select("Emote", "choose an emote (stops on move)", emoteLabels, curEmote, function(v) curEmote = v end)
        emoSec:Button("Play Emote", nil, function()
            local e = emoteByLabel[curEmote]
            if e then playEmote(e) end
        end)
        emoSec:Button("Stop Emote", nil, stopEmote)
        getgenv().__KRP_EMOTES = {
            labels = emoteLabels,
            play = function(label)
                local e = emoteByLabel[label]
                if e then playEmote(e) end
            end,
            stop = stopEmote,
            current = function() return curEmote end,
            isPlaying = function()
                return emoteTrack ~= nil
            end,
        }
        getgenv().__KRP_PLAY_EMOTE = function()
            local e = emoteByLabel[curEmote]
            if e then playEmote(e) end
        end
    end)
    runBlock("CURSORS", function()
        local cursorList = {
        	{ 11726322365, "Pink Heart" },
        	{ 11754490336, "Heart Scope" },
        	{ 12094859168, "White Heart" },
        	{ 12094860445, "Mint Heart" },
        	{ 11747999974, "Red Heart" },
        	{ 12909937176, "Angel Heart" },
        	{ 11767039760, "Heart Line" },
        	{ 84069910734738, "Heart Sight" },
        	{ 14128309111, "Heart Cross" },
        	{ 11739569706, "Pixel Heart" },
        	{ 12323570810, "Glow Heart" },
        	{ 12146777431, "Soft Heart" },
        	{ 11254520798, "Neon Pink" },
        	{ 81102279303918, "Neon Rose" },
        	{ 11716577756, "Pink Medic" },
        	{ 12439641494, "Pink Scope" },
        	{ 91638190237682, "Neon Green" },
        	{ 1458996342, "Ice X" },
        	{ 942455758, "Cyan Tri" },
        	{ 5159914167, "Classic" },
        	{ 29066471, "Red Dot" },
        	{ 10891594364, "Glow Orb" },
        	{ 13613212658, "Rainbow Star" },
        	{ 13944218938, "Pink Star" },
        	{ 13944215054, "White Star" },
        	{ 130225909042821, "Purple Star" },
        	{ 84232095638395, "Star Line" },
        	{ 11893991373, "Kuromi" },
        	{ 12030244945, "Hello Kitty" },
        	{ 11768101227, "Gengar" },
        	{ 130973865039213, "Kitty Pointer" },
        	{ 108267553252298, "Pink Pointer" },
        	{ 12818611757, "Blue Pointer" },
        }
        local sizes = { S = 28, M = 40, L = 56 }
        local cur = { on = false, id = nil, mode = "Always", size = "M" }
        local function img(id)
        	return ("rbxthumb://type=Asset&id=%d&w=150&h=150"):format(id)
        end
        local cursorGui = create("ScreenGui", { Name = "KirpichCursor", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 2000 })
        pcall(function()
        	cursorGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
        end)
        if not cursorGui.Parent then
            pcall(function() cursorGui.Parent = player:WaitForChild("PlayerGui", 5) end)
        end
        local icon = create("ImageLabel", {
        	AnchorPoint = Vector2.new(0.5, 0.5),
        	BackgroundTransparency = 1,
        	Size = UDim2.fromOffset(sizes.M, sizes.M),
        	ScaleType = Enum.ScaleType.Fit,
        	Visible = false,
        	ZIndex = 10,
        	Parent = cursorGui,
        })
        local scale = create("UIScale", { Parent = icon })
        local hidden = false
        local function updateCursor()
        	local char = player.Character
        	local active = cur.on and cur.id ~= nil and (cur.mode == "Always" or char and char:FindFirstChild("Gun") ~= nil)
        	if active then
        		UserInputService.MouseIconEnabled = false
        		hidden = true
        		local m = UserInputService:GetMouseLocation()
        		icon.Position = UDim2.fromOffset(m.X, m.Y)
        		icon.Visible = true
        	elseif hidden then
        		hidden = false
        		UserInputService.MouseIconEnabled = true
        		icon.Visible = false
        	end
        end
        pcall(function()
        	RunService:UnbindFromRenderStep("KirpichCursor")
        end)
        RunService:BindToRenderStep("KirpichCursor", Enum.RenderPriority.Last.Value + 10, updateCursor)
        connect(UserInputService:GetPropertyChangedSignal("MouseIconEnabled"), function()
        	if hidden and UserInputService.MouseIconEnabled then
        		UserInputService.MouseIconEnabled = false
        	end
        end)
        connect(UserInputService.InputBegan, function(input)
        	if icon.Visible and input.UserInputType == Enum.UserInputType.MouseButton1 then
        		scale.Scale = 0.75
        		tween(scale, 0.25, { Scale = 1 }, Enum.EasingDirection.Out, Enum.EasingStyle.Back)
        	end
        end)
        local names, byName = {}, {}
        for _, c in ipairs(cursorList) do
            names[#names + 1] = c[2]
            byName[c[2]] = c[1]
        end
        local imgTok = 0
        local function applyCursor()
            if cur.id then
                local id = cur.id
                imgTok += 1
                local tok = imgTok
                icon.Image = img(id)
                task.delay(2, function()
                    if tok ~= imgTok or cur.id ~= id or icon.IsLoaded then return end
                    icon.Image = "rbxassetid://" .. id
                    task.delay(2, function()
                        if tok ~= imgTok or cur.id ~= id or icon.IsLoaded then return end
                        icon.Image = "http://www.roblox.com/asset/?id=" .. id
                    end)
                end)
            end
            local s = sizes[cur.size] or 40
            icon.Size = UDim2.fromOffset(s, s)
        end
        local cSec = addSection(Tabs.Visuals, "Cursors")
        cSec:Toggle("Custom Cursor", "custom cursor instead of default", function(on)
            cur.on = on
            if on and not cur.id then
                cur.id = cursorList[1][1]
            end
            applyCursor()
        end)
        cSec:Select("Cursor", "choose a cursor", names, names[1], function(v)
            cur.id = byName[v]
            applyCursor()
        end)
        cSec:Select("Mode", "Always or only with Gun in hand", { "Always", "Gun" }, cur.mode, function(v) cur.mode = v end)
        cSec:Select("Size", "S / M / L", { "S", "M", "L" }, cur.size, function(v)
            cur.size = v
            applyCursor()
        end)
        stopCursor = function()
            pcall(function() RunService:UnbindFromRenderStep("KirpichCursor") end)
            cur.on = false
            if hidden then UserInputService.MouseIconEnabled = true end
            hidden = false
            cursorGui:Destroy()
        end
    end)
    runBlock("SKIN CHANGER", function()
        local skinCfg = {
        	sel = { Knife = nil, Gun = nil },
        	listType = "Knife",
        	size = 100,
        	glow = false,
        	sparkles = false,
        	trail = false,
        	light = 60,
        	enabled = true,
        }
        local skinRows = {
        	{ "GhostK2018", "Ghost 2018", "K", "Legendary", 121944778, 2514800940, 1, 1, 1, 2513732969, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Biogun", "Biogun", "G", "Uncommon", 79401392, 4659589763, 1.5, 1.5, 1.5, 4659627458, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Skulls_K_2021", "Skulls 2021", "K", "Uncommon", 121944778, 7756610618, 1, 1, 1, 7800220325, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "AmericaGun", "America", "G", "Classic", 25298496, 164669251, 1.5, 1.5, 1.5, 164676043, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Frozen_K_2022", "Frozen 2022", "K", "Common", 121944778, 4528568803, 1, 1, 1, 11834404402, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscythe", "Gingerscythe (Rare)", "K", "Rare", 15397894467, 15397714781, 0.9733, 0.9733, 0.9733, 15683138101, 0, -0.9894, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscythe_Legendary", "Gingerscythe (Legendary)", "K", "Legendary", 15397894467, 15397484015, 0.9733, 0.9733, 0.9733, 15683140564, 0, -0.9894, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Jack", "Jack", "K", "Rare", 121944778, 315094945, 1.0005, 1, 1, 315099010, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Space", "Space", "K", "Rare", 957726558, 3183404232, 1, 1, 1, 3183607442, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Splash", "Splash", "K", "Legendary", 121944778, 235343795, 1, 1, 1, 235371439, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gifts_K_2019", "Gifts 2019", "K", "Common", 957726558, 4534828383, 1, 1, 1, 4534856285, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bones_K_2024", "Bones 2024", "K", "Uncommon", 6600901997, 89105172362040, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "RandLuger", "Glitch2", "K", "Common", 121944778, 191784815, 1, 1, 1, 196751515, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Kool", "Yellow", "K", "Common", 121944778, 473621021, 1, 1, 1, 473625906, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "WebbedK", "Webbed", "K", "Common", 957726558, 4210410097, 1, 1, 1, 4210949599, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Witch_K_2022", "Witchbrew", "K", "Uncommon", 957726558, 11245959206, 1, 1, 1, 11254115609, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "PredatorKnife", "Predator", "K", "Legendary", 121944778, 199611278, 1, 1, 1, 235372015, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Eyeball_K_2022", "Eyeball", "K", "Common", 121944778, 11217645677, 1, 1, 1, 11254065007, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Heart_K_2023", "Heart", "K", "Rare", 10855586895, 12248435132, 1, 1, 1, 12339327069, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Butterflies_G_2025", "Butterflies", "G", "Rare", 79401392, 124763121225655, 1.6, 1.6, 1.6, 135662872427976, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Tulip", "Tulip", "K", "Common", 121944778, 387468258, 1, 1, 1, 387874661, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sharky_K_2024", "Sharky", "K", "Rare", 6600901997, 18321899067, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ScratchBlue", "Scratch · ScratchBlue", "K", "Legendary", 121944778, 1311186323, 1, 1, 1, 1133316381, 0, -0.9885, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "MLG", "Shiny", "K", "Legendary", 121944778, 473623765, 1, 1, 1, 473626979, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Slate", "Slate", "K", "Common", 121944778, 161577504, 1, 1, 1, 198453556, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cherry", "Cherry", "K", "Common", 121944778, 155195316, 1, 1, 1, 6711852603, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Love", "Love", "K", "Common", 121944778, 192527236, 1, 1, 1, 196750845, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snoop", "Red", "K", "Uncommon", 121944778, 473621136, 1, 1, 1, 473626150, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Linked", "Linked", "K", "Common", 121944778, 172762850, 1, 1, 1, 198453528, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Elite", "Elite", "K", "Legendary", 121944778, 241077941, 1, 1, 1, 241095344, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ZombieK2018", "Zombie 2018", "K", "Uncommon", 121944778, 103728247210594, 1, 1, 1, 2513734908, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Eyes_K_2020", "Watcher 2020", "K", "Common", 957726558, 5866358413, 1, 1, 1, 5866438542, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Aurora_K_2019", "Aurora 2019", "K", "Rare", 957726558, 4534823003, 1, 1, 1, 4534860689, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerbread_K_2022", "Gingerbread 2022", "K", "Rare", 121944778, 11802560347, 1, 1, 1, 11834399071, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SlimyK", "Slimy", "K", "Common", 957726558, 4210874138, 1, 1, 1, 4210932676, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Witched", "Witched", "K", "Legendary", 957726558, 4210410129, 1, 1, 1, 4210938270, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "MoltenKnife", "Molten", "K", "Rare", 121944778, 472483450, 1, 1, 1, 235371809, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "StickersX_K_2022", "Stickers 2022 · StickersX_K_2022", "K", "Common", 957726558, 11823434191, 1, 1, 1, 11834387858, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Moons", "Moons", "K", "Uncommon", 121944778, 531835087, 1, 1, 1, 531873154, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "VampireK2018", "Vampire 2018", "K", "Rare", 121944778, 2513708625, 1, 1, 1, 2513734708, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "JD", "JD", "K", "Legendary", 121944778, 559676009, 1, 1, 1, 566867312, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Pumpkin_K_2020", "Pumpkin 2020", "K", "Uncommon", 957726558, 5872477622, 1, 1, 1, 5872490600, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ghosts_K_2023", "Ghosts 2023", "K", "Common", 121944778, 15037729398, 1, 1, 1, 15091326116, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Fireplace_K_2023", "Fireplace", "K", "Uncommon", 121944778, 15382624195, 1, 1, 1, 15635558021, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gift_K_2020", "Wrap", "K", "Uncommon", 121944778, 6121854102, 1, 1, 1, 6121854816, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Survivors_K_2022", "Makeshift", "K", "Rare", 121944778, 11218956882, 1, 1, 1, 11254180750, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Love_K_2023", "Love 2023", "K", "Common", 10855586895, 12248652835, 1, 1, 1, 12339328595, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Fade", "Fade", "K", "Legendary", 121944778, 288136894, 1, 1, 1, 315501640, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Branches", "Branches", "K", "Uncommon", 957726558, 4210409800, 1, 1, 1, 4210943691, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SwirlyAxeBlue", "Blue Swirly", "K", "Unique", 8293463844, 74192567120797, 0.0579, 0.0579, 0.0579, 9552048857, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Candle_K_2020", "Candle", "K", "Common", 957726558, 5872478022, 1, 1, 1, 5872491708, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Wavy_K_2024", "Wavy", "K", "Common", 6600901997, 16846003250, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Frostflame_K_2024", "Frostflame", "K", "Rare", 6600901997, 121019096457803, 1, 1, 1, 104988218477551, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Leaves_K_2023", "Leaves", "K", "Common", 6600901997, 15081802321, 1, 1, 1, 15091400883, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Stickers_X_K_2024", "Stickers 2024 · Stickers_X_K_2024", "K", "Common", 6600901997, 109835260607049, 1, 1, 1, 83843575465564, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sparkle4", "Sparkle4", "K", "Common", 121944778, 306917565, 1, 1, 1, 310712788, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Wolf", "Wolf", "K", "Uncommon", 121944778, 531835092, 1, 1, 1, 531873487, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Tailslide", "Tailslide", "K", "Common", 121944778, 240942385, 1, 1, 1, 305506822, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Squire", "Squire", "K", "Rare", 121944778, 243372276, 1, 1, 1, 315501560, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Clan", "Clan", "K", "Common", 121944778, 161495171, 1, 1, 1, 235366460, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ghosts_K_2020", "Ghosts 2020", "K", "Uncommon", 957726558, 5866362606, 1, 1, 1, 5866442790, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Constellation", "Constellation · Constellation", "G", "Godly", 124598402927958, 79010754957272, 0.1007, 0.1007, 0.1007, 114197436469014, 0, -0.2701, 0.7265, 1, 0, 0, 0, 0.9999, 0.0125, 0, -0.0125, 0.9999 },
        	{ "Ornaments_K_2020", "Ornaments 2020", "K", "Common", 957726558, 6121852598, 1, 1, 1, 6121853160, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bats", "Bats (Rare)", "K", "Rare", 121944778, 531836446, 1, 1, 1, 531873625, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Stockings_K_2022", "Stockings 2022", "K", "Uncommon", 957726558, 11824212997, 1, 1, 1, 11834392930, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ghastly_K_2023", "Ghastly", "K", "Rare", 121944778, 15029785979, 1, 1, 1, 15091407068, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cookie_K_2021", "Cookie", "K", "Uncommon", 121944778, 8275035982, 1, 1, 1, 8304752586, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Web", "Web", "K", "Legendary", 121944778, 315110729, 1, 1, 1, 315104004, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Santa_K_2018", "Santa 2018", "K", "Common", 121944778, 2659488082, 1, 1, 1, 2669637780, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "CandySwirl_K_2019", "Candy Swirl", "K", "Rare", 957726558, 4534829449, 1, 1, 1, 4534860226, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cane_K_2018", "Cane 2018", "K", "Rare", 121944778, 2659489980, 1, 1, 1, 2669638508, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Meltdown_K_2023", "Meltdown", "K", "Uncommon", 957726558, 15035536803, 1, 1, 1, 15091340751, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowy2017", "Snowy 2017", "K", "Rare", 121944778, 1268287181, 1, 1, 1, 1268705947, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Slashed_K_2020", "Slashed", "K", "Common", 957726558, 5929316036, 1, 1, 1, 5929317433, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "GreenFire", "Green Fire", "K", "Legendary", 121944778, 1268253789, 1, 1, 1, 1268706374, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowflakes_K_2019", "Snowflakes 2019", "K", "Common", 121944778, 4534831727, 1, 1, 1, 4534855045, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Shaded", "Shaded", "K", "Common", 957726558, 4659587929, 1, 1, 1, 4659636085, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ZombifiedK", "Zombified", "K", "Uncommon", 121944778, 114781782298919, 1, 1, 1, 4210928053, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscythe_Ancient", "Gingerscythe (Ancient)", "K", "Ancient", 15395668244, 15409195246, 0.0638, 0.0638, 0.0638, 15683188776, 0, -0.22, 0.944, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Reaver_Godly", "Reaver (Godly)", "K", "Godly", 7774174974, 7774175135, 0.25, 0.2499, 0.25, 7791511648, 0, -0.9987, -0.0037, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Canes_K_2023", "Canes", "K", "Uncommon", 121944778, 15381447325, 1, 1, 1, 15635574962, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "CamoKnife", "Camo", "K", "Uncommon", 121944778, 3183403069, 1, 1, 1, 3183606225, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SketchYT", "Sketchy", "K", "Common", 121944778, 539831264, 1, 1, 1, 546161470, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Hunter_K_2022", "Hunter", "K", "Common", 121944778, 11246309889, 1, 1, 1, 11254154978, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "OverseerKnife", "Overseer", "K", "Legendary", 121944778, 198299790, 1, 1, 1, 198458910, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SilentNight_K_2020", "Silent Night", "K", "Rare", 957726558, 6121850778, 1, 1, 1, 6121851313, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Beach_K_2023", "Beach", "K", "Legendary", 6600901997, 13894391232, 1, 1, 1, 13944136198, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Clownfish_K_2024", "Clownfish", "K", "Common", 6600901997, 18321899540, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Moon_K_2021", "Moon", "K", "Common", 121944778, 7756612294, 1, 1, 1, 7800224197, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Skulls", "Skulls", "K", "Legendary", 957726558, 4210409968, 1, 1, 1, 4210915060, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sweetheart", "Sweetheart", "K", "Common", 121944778, 363142139, 1, 1, 1, 363150761, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Zombified_K_2022", "Zombified 2022", "K", "Rare", 121944778, 11218741536, 1, 1, 1, 11254182560, 0, -1.0087, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SnakebiteK", "Snakebite", "K", "Rare", 957726558, 4210409981, 1, 1, 1, 4210939388, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Waves_K_2024", "Waves 2024", "K", "Rare", 6600901997, 18321898887, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "CandyCorn_K_2022", "Candy Corn 2022", "K", "Common", 121944778, 11217550170, 1, 1, 1, 11254057417, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "CottonCandy", "Cotton Candy", "K", "Legendary", 121944778, 435754345, 1, 1, 1, 435933179, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Static", "Static", "K", "Common", 121944778, 365566391, 1, 1, 1, 365568163, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bats_K_2020", "Bats 2020", "K", "Common", 957726558, 5930584000, 1, 1, 1, 5930729222, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Portal_K_2020", "Portal", "K", "Rare", 957726558, 5866364902, 1, 1, 1, 5866444722, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerbread_K_2019", "Gingerbread 2019", "K", "Uncommon", 957726558, 4534824961, 1, 1, 1, 4534856940, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "GhostRbx_K_2022", "Ghostly", "K", "Uncommon", 121944778, 11117362816, 1, 1, 1, 11117375743, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Rose_K_2023", "Rose", "K", "Uncommon", 10855586895, 12238708500, 1, 1, 1, 12339325736, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "LMFAO", "Pink", "K", "Uncommon", 121944778, 473621215, 1, 1, 1, 473626473, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Swirl_K_2021", "Swirl", "K", "Rare", 121944778, 8294015413, 1, 1, 1, 8304757110, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Dew", "Black", "K", "Rare", 121944778, 473621267, 1, 1, 1, 473626646, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Holly_K_2018", "Holly", "K", "Uncommon", 121944778, 2664997532, 1, 1, 1, 2669638990, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ribbon_K_2023", "Ribbon", "K", "Common", 957726558, 15332484220, 1, 1, 1, 15635552019, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Chips", "Blue", "K", "Uncommon", 121944778, 473621164, 1, 1, 1, 473626317, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Candles_K_2024", "Candles", "K", "Common", 6600901997, 137012419503995, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Wreaths_K_2024", "Wreaths", "K", "Uncommon", 6600901997, 100835235112831, 1, 1, 1, 78432760615312, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Wrapped_K_2024", "Wrapped 2024", "K", "Uncommon", 6600901997, 73121682334065, 1, 1, 1, 72638846676083, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ghosts_K_2024", "Ghosts 2024", "K", "Common", 6600901997, 128247285156176, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerbread2017", "Gingerbread 2017", "K", "Rare", 121944778, 1268295971, 1, 1, 1, 1268705527, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Hearts", "Hearts", "K", "Common", 121944778, 363311795, 1, 1, 1, 363362737, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sweater_K_2018", "Sweater 2018", "K", "Uncommon", 121944778, 2664997385, 1, 1, 1, 2669640567, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Candied_K_2022", "Candied", "K", "Common", 121944778, 11802560748, 1, 1, 1, 11834384755, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cracks_K_2021", "Cracks", "K", "Common", 121944778, 7756612787, 1, 1, 1, 7800224981, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Aurora_K_2021", "Aurora 2021", "K", "Legendary", 121944778, 8275036346, 1, 1, 1, 8304750877, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "MummyK2018", "Mummy 2018", "K", "Uncommon", 121944778, 2513648136, 1, 1, 1, 2513733542, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sparkle2", "Sparkle2", "K", "Common", 121944778, 306914370, 1, 1, 1, 310710191, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "PumpkinPie_K_2023", "Pumpkin Pie", "K", "Uncommon", 121944778, 15320084464, 1, 1, 1, 15413117611, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sparkle9", "Sparkle9", "K", "Common", 121944778, 306919809, 1, 1, 1, 310715104, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Igloo_K_2024", "Igloo", "K", "Common", 6600901997, 126697433046307, 1, 1, 1, 73203940450745, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "IceHammer_Ancient", "Icecrusher (Ancient)", "K", "Ancient", 11848711686, 11850483027, 0.07, 0.07, 0.07, 11855274019, -0.0075, -1.0949, 0.0014, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Doritos", "Purple", "K", "Rare", 121944778, 473621310, 1, 1, 1, 473626740, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Frostflame_G_2024", "Frostflame", "G", "Rare", 79401392, 76059118984667, 1.6, 1.6, 1.6, 114781759936576, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Grind", "Grind", "K", "Common", 121944778, 240937041, 1, 1, 1, 305503942, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Blossom", "Blossom", "K", "Common", 121944778, 363138170, 1, 1, 1, 363150561, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cane_K_2021", "Cane 2021", "K", "Common", 121944778, 8293557762, 1, 1, 1, 8304750295, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sandy", "Sandy", "K", "Common", 121944778, 365566396, 1, 1, 1, 365568056, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Stainless", "Stainless", "K", "Common", 121944778, 91790701, 1, 1, 1, 235366771, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Tiger", "Tiger", "K", "Uncommon", 957726558, 3183403283, 1, 1, 1, 3183606579, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Kraken_K_2024", "Kraken", "K", "Rare", 6600901997, 127474140762204, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Meadow_G_2025", "Meadow", "G", "Uncommon", 79401392, 107182071164823, 1.6, 1.6, 1.6, 107321881182350, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "PumpkinPatch", "Pumpkin", "K", "Common", 957726558, 4210409792, 1, 1, 1, 4210931354, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Fusion", "Fusion", "K", "Legendary", 121944778, 365566399, 1, 1, 1, 365569686, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Future", "Future", "K", "Uncommon", 121944778, 163926951, 1, 1, 1, 197639041, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ollie", "Ollie", "K", "Common", 121944778, 240941633, 1, 1, 1, 305504399, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ToxicK", "Toxic", "K", "Rare", 121944778, 2513648163, 1, 1, 1, 2513734535, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Dark_K_2023", "Darkknife", "K", "Rare", 121944778, 15081468336, 1, 1, 1, 15091343579, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Chromatic_K_2023", "Chromatic", "K", "Legendary", 6600901997, 12927939898, 1, 1, 1, 12965304445, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Frostfade_K_2023", "Frostfade", "K", "Legendary", 6600901997, 15344578184, 1, 1, 1, 15635565488, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sub", "Sub", "K", "Common", 121944778, 545569636, 1, 1, 1, 546159250, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Stickers_K_2021", "Stickers 2021 · Stickers_K_2021", "K", "Common", 121944778, 7757619418, 1, 1, 1, 7800229084, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Hardened", "Hardened", "K", "Common", 957726558, 3183401814, 1, 1, 1, 3183605810, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Robot_K_2024", "Robot", "K", "Rare", 6600901997, 16833551908, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Spider_K_2023", "Spider 2023", "K", "Common", 957726558, 15091217506, 1, 1, 1, 15091399982, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Jellyfish_K_2024", "Jellyfish", "K", "Uncommon", 6600901997, 18321899333, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Circuit", "Circuit", "K", "Uncommon", 121944778, 155356565, 1, 1, 1, 235366945, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Infected_K_2022", "Infected 2022", "K", "Common", 121944778, 11217988441, 1, 1, 1, 11254175272, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "HotChocolate_K_2024", "Hot Chocolate", "K", "Common", 6600901997, 105940775587606, 1, 1, 1, 133307062463653, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "HauntedK", "Haunted", "K", "Common", 121944778, 2513648134, 1, 1, 1, 2513733741, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sweater", "Sweater", "K", "Uncommon", 121944778, 1268293368, 1, 1, 1, 1268704902, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Missing", "Missing", "K", "Uncommon", 121944778, 163625649, 1, 1, 1, 198455936, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sunny_G_2025", "Sunny", "G", "Rare", 79401392, 105937622090347, 1.6, 1.6, 1.6, 93906279038399, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Logcutter_K_2024", "Logcutter", "K", "Rare", 6600901997, 73375064666195, 1, 1, 1, 71088901904009, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Webs", "Webs", "K", "Uncommon", 121944778, 1133322612, 1, 1, 1, 1133325465, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Reindeer_K_2024", "Reindeer", "K", "Common", 6600901997, 121109734938655, 1, 1, 1, 109101361674956, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "DeepSea", "Deep Sea", "K", "Rare", 957726558, 4659571247, 1, 1, 1, 4659634072, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Noodle_K_2023", "Pool Noodle", "K", "Uncommon", 6600901997, 13895318303, 1, 1, 1, 13944133313, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Galaxy", "Galaxy", "K", "Rare", 121944778, 192367012, 1, 1, 1, 192480941, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Spring_K_2024", "Spring", "K", "Rare", 957726558, 16830850572, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Coal_K_2022", "Coal 2022", "K", "Common", 121944778, 11802560508, 1, 1, 1, 11834390120, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Leaf", "Leaf", "K", "Common", 957726558, 4659588788, 1, 1, 1, 4659636452, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Emerald", "Emerald", "K", "Legendary", 121944778, 173946596, 1, 1, 1, 198461276, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Starry_K_2021", "Starry 2021", "K", "Rare", 121944778, 8303534347, 1, 1, 1, 8304757707, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Stockings_G_2024", "Stockings 2024", "G", "Common", 6600918074, 75065116268922, 0.0384, 0.0388, 0.0369, 76288270695961, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Ginger_K_2018", "Ginger 2018", "K", "Legendary", 121944778, 2659488706, 1, 1, 1, 2669638742, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowfall_K_2023", "Snowfall", "K", "Common", 957726558, 15381549802, 1, 1, 1, 15635568751, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Brains", "Brains", "K", "Common", 121944778, 531864479, 1, 1, 1, 531873956, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Skool", "Skool", "K", "Common", 121944778, 178200933, 1, 1, 1, 295269977, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Valentine", "Valentine", "K", "Common", 121944778, 363139123, 1, 1, 1, 363362726, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Frosty", "Frosty", "K", "Uncommon", 121944778, 1268375270, 1, 1, 1, 1268704507, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Giftbag_K_2020", "Gift Bag", "K", "Common", 957726558, 6121846201, 1, 1, 1, 6121847170, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "CandyCorn_K_2020", "Candy Corn 2020", "K", "Common", 957726558, 5866354929, 1, 1, 1, 5866435364, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Frozen_K_2019", "Frozen 2019", "K", "Uncommon", 957726558, 4528568803, 1, 1, 1, 4534857523, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "OrangeMarble", "Orange Marble", "K", "Rare", 121944778, 531653125, 1, 1, 1, 531873011, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gifted", "Gifted", "K", "Uncommon", 121944778, 190131936, 1, 1, 1, 197627734, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Dungeon", "Dungeon", "K", "Rare", 957726558, 4210409814, 1, 1, 1, 4210920512, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sparkle5", "Sparkle5", "K", "Common", 121944778, 306909649, 1, 1, 1, 310713235, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscythe_Godly", "Gingerscythe (Godly)", "K", "Godly", 15397282571, 15409017869, 0.0696, 0.0696, 0.0697, 15683175970, 0, -0.94, -0.063, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Rainbow", "Rainbow (Rare)", "K", "Rare", 121944778, 157019835, 1, 1, 1, 159747377, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cardboard", "Cardboard", "K", "Common", 121944778, 159435782, 1, 1, 1, 235366729, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Passion", "Passion", "K", "Common", 121944778, 363139004, 1, 1, 1, 363150334, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Rune", "Rune", "K", "Legendary", 121944778, 3183404423, 1, 1, 1, 3183607894, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bleached", "Bleached", "K", "Common", 121944778, 311711104, 1, 1, 1, 315500879, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "TravelerAxeRed", "Red Traveler's", "K", "Unique", 15057341638, 129174189928841, 0.0681, 0.0681, 0.0681, 15695405379, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Vines_K_2023", "Vines", "K", "Common", 957726558, 15037307112, 1, 1, 1, 15091325210, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowman_K_2021", "Snowman 2021", "K", "Uncommon", 121944778, 8275035798, 1, 1, 1, 8304753468, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ghosts_K_2021", "Wraiths", "K", "Uncommon", 121944778, 7808358755, 1, 1, 1, 7808362279, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Krypto", "Krypto", "K", "Rare", 121944778, 155572642, 1, 1, 1, 198458841, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ElderwoodKnife", "Elderwood Blade", "K", "Godly", 11238166013, 11238176757, 0.07, 0.07, 0.07, 11254879631, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Reptile", "Reptile", "K", "Common", 121944778, 162671092, 1, 1, 1, 162672131, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowflake_K_2022", "Snowflake 2022", "K", "Uncommon", 957726558, 11823783274, 1, 1, 1, 11834397133, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Eclipse_K_2023", "Eclipse", "K", "Uncommon", 121944778, 15081587332, 1, 1, 1, 15091404278, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Storm_K_2024", "Storm", "K", "Rare", 6600901997, 124972846638078, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Scratch", "Scratch · Scratch", "K", "Legendary", 121944778, 531835091, 1, 1, 1, 531873371, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SantasMagic", "Santa's Magic", "K", "Legendary", 957726558, 4535479726, 1, 1, 1, 4535483042, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Palms_K_2024", "Palms", "K", "Legendary", 6600901997, 18351264716, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Darkness_K_2022", "Darkness", "K", "Common", 121944778, 11217282454, 1, 1, 1, 11254081561, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Constellation_K_2024", "Nightstar", "K", "Legendary", 6600901997, 125699146017319, 1, 1, 1, 113979322866878, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Adurite", "Adurite", "K", "Uncommon", 121944778, 192482160, 1, 1, 1, 192492943, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Prism", "Prism", "K", "Common", 121944778, 297795989, 1, 1, 1, 306046703, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "MummyK", "Mummy", "K", "Uncommon", 121944778, 91472505507923, 1, 1, 1, 1133352032, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Marble_K_2023", "Marble", "K", "Uncommon", 6600901997, 12926768989, 1, 1, 1, 12965302237, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Steel_K_2023", "Steel", "K", "Uncommon", 957726558, 15028885294, 1, 1, 1, 15091405483, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SantasSpirit", "Santa's Spirit", "K", "Legendary", 957726558, 6123356424, 1, 1, 1, 6123357775, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Doge", "Doge", "K", "Uncommon", 121944778, 159758190, 1, 1, 1, 235371276, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "EliteBlue", "Blue Elite", "K", "Legendary", 121944778, 1269369946, 1, 1, 1, 1269374321, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "WitchBrew_K_2024", "Witch's Brew", "K", "Uncommon", 6600901997, 101625224396969, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Log", "Log", "K", "Common", 121944778, 365566383, 1, 1, 1, 365567962, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bunny", "Bunny", "K", "Common", 121944778, 387366668, 1, 1, 1, 387874365, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Combat", "Combat", "K", "Common", 121944778, 3183532466, 1, 1, 1, 3183604570, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Mistletoe_K_2022", "Mistletoe", "K", "Uncommon", 957726558, 11823994753, 1, 1, 1, 11834394793, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Nether", "Nether", "K", "Rare", 121944778, 166089996, 1, 1, 1, 197657098, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Starfish_K_2024", "Starfish", "K", "Common", 6600901997, 18321898656, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Brush", "Brush", "K", "Uncommon", 121944778, 5435976404, 1, 1, 1, 365568602, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "XmasStickers_K_2021", "Stickers 2021 · XmasStickers_K_2021", "K", "Common", 121944778, 8275034832, 1, 1, 1, 8304755417, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Monster_K_2024", "Monster", "K", "Uncommon", 6600901997, 136318121608837, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Fragile_K_2023", "Fragile", "K", "Common", 6600901997, 12936083164, 1, 1, 1, 12965294432, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "RedFire", "Red Fire", "K", "Legendary", 121944778, 1269255990, 1, 1, 1, 1269256860, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "GreenMarble", "Green Marble", "K", "Rare", 121944778, 110469751488021, 1, 1, 1, 1133366830, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerheart_K_2024", "Gingerheart", "K", "Uncommon", 6600901997, 77403934219171, 1, 1, 1, 115273559455814, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowglobe_K_2023", "Snowglobe", "K", "Rare", 121944778, 15382647009, 1, 1, 1, 15635576863, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Latte_K_2023", "Latte", "K", "Legendary", 121944778, 15319905553, 1, 1, 1, 15413114703, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Wood_K_2023", "Wood", "K", "Common", 957726558, 15036170420, 1, 1, 1, 15091401811, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Magma_K_2021", "Magma 2021", "K", "Rare", 121944778, 7756613022, 1, 1, 1, 7800225996, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Goo", "Goo", "K", "Common", 121944778, 178402851, 1, 1, 1, 237336076, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Wanwood", "Wanwood", "K", "Uncommon", 121944778, 159653725, 1, 1, 1, 192132094, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Trees_K_2020", "Trees", "K", "Common", 957726558, 75614417738235, 1, 1, 1, 6123336879, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gifts_K_2024", "Gifts 2024", "K", "Common", 6600901997, 80884642545249, 1, 1, 1, 129290011017110, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Lights_K_2019", "Lights 2019", "K", "Uncommon", 121944778, 4534825993, 1, 1, 1, 4534858185, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "TNL", "TNL", "K", "Common", 121944778, 201480146, 1, 1, 1, 201542790, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Elf2017", "Elf 2017", "K", "Common", 121944778, 1268702375, 1, 1, 1, 1268703023, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gothic_K_2021", "Gothic", "K", "Uncommon", 121944778, 7756611289, 1, 1, 1, 7800221141, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowflake_K_2018", "Snowflake 2018", "K", "Uncommon", 121944778, 2659487731, 1, 1, 1, 2669639913, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Stalker", "Stalker", "K", "Uncommon", 121944778, 155313728, 1, 1, 1, 198455980, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Hazard_K_2022", "Hazard", "K", "Uncommon", 121944778, 11217121434, 1, 1, 1, 11254083234, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "PotionK2018", "Potion 2018", "K", "Uncommon", 957726558, 2513648150, 1, 1, 1, 2513733987, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Marley", "Green", "K", "Common", 121944778, 473620972, 1, 1, 1, 473625785, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bells_K_2023", "Bells", "K", "Common", 121944778, 15382279697, 1, 1, 1, 15635570486, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Lovely", "Lovely", "K", "Common", 957726558, 4659572197, 1, 1, 1, 4659635584, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Stars_K_2023", "Stars", "K", "Uncommon", 957726558, 15381316403, 1, 1, 1, 15635559978, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Present", "Present", "K", "Common", 121944778, 1268314631, 1, 1, 1, 1268699212, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Zombie_K_2023", "Zombie 2023", "K", "Uncommon", 957726558, 11218741536, 1, 1, 1, 15091339932, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Copper", "Copper", "K", "Common", 121944778, 3183401534, 1, 1, 1, 3183605392, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Vampire_K_2022", "Vampire 2022", "K", "Legendary", 121944778, 11215450234, 1, 1, 1, 11254125546, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Abstract", "Abstract", "K", "Rare", 121944778, 5437299417, 1, 1, 1, 365569428, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ornament2", "Ornament2", "K", "Common", 121944778, 331744472, 1, 1, 1, 331745341, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Arctic_K_2022", "Arctic", "K", "Legendary", 121944778, 11802561076, 1, 1, 1, 11834401547, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Pine_K_2019", "Pine", "K", "Common", 957726558, 4534830880, 1, 1, 1, 4534855710, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Jigsaw", "Jigsaw", "K", "Uncommon", 121944778, 365566397, 1, 1, 1, 365569126, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Nova", "Nova", "K", "Rare", 121944778, 198766824, 1, 1, 1, 235371686, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Xbox", "Xbox", "K", "Common", 121944778, 450680781, 1, 1, 1, 439325100, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Zombie", "Zombie", "K", "Common", 121944778, 1782551901, 1, 1, 1, 1133331875, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Musical", "Musical", "K", "Rare", 121944778, 365566387, 1, 1, 1, 365569566, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sidewinder", "Sidewinder", "K", "Common", 121944778, 295302778, 1, 1, 1, 305503783, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Stockings_K_2020", "Stockings 2020", "K", "Common", 957726558, 6123161536, 1, 1, 1, 6123335682, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Choco", "Choco", "K", "Common", 121944778, 386204101, 1, 1, 1, 387874991, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sparkle10", "Sparkle10", "K", "Common", 121944778, 306921666, 1, 1, 1, 310715768, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sparkle8", "Sparkle8", "K", "Common", 121944778, 306913268, 1, 1, 1, 310714407, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Korblox", "Korblox", "K", "Rare", 121944778, 313561541, 1, 1, 1, 315501501, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Aqua", "Aqua", "K", "Common", 121944778, 250006854, 1, 1, 1, 315501208, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Donut", "Donut", "K", "Uncommon", 121944778, 161529618, 1, 1, 1, 235366815, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Spectrum", "Spectrum", "K", "Rare", 121944778, 162718300, 1, 1, 1, 198458862, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Skull_K_2023", "Etched", "K", "Common", 957726558, 15029874889, 1, 1, 1, 15091321393, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SlimeK", "Slime", "K", "Common", 121944778, 2513648162, 1, 1, 1, 2513734227, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowman_K_2018", "Snowman 2018", "K", "Common", 121944778, 2659487396, 1, 1, 1, 2669640152, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "GraveK", "Grave", "K", "Common", 2514683594, 2513648160, 1, 1, 1, 2513728474, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Coal_K_2021", "Coal 2021", "K", "Common", 121944778, 8275036203, 1, 1, 1, 8304751659, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sleigh_K_2024", "Sleigh", "K", "Rare", 6600901997, 85646229893233, 1, 1, 1, 74917318027165, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Tree_K_2021", "Tree 2021", "K", "Uncommon", 121944778, 8275034131, 1, 1, 1, 8304756423, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Mummy_K_2020", "Mummy 2020", "K", "Uncommon", 121944778, 5866365511, 1, 1, 1, 5866447521, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Carved_K_2020", "Carved", "K", "Common", 957726558, 5866356691, 1, 1, 1, 5866436906, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Damp", "Damp", "K", "Rare", 121944778, 161673042, 1, 1, 1, 198461253, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Frosted_K_2019", "Frosted", "K", "Common", 957726558, 4534831933, 1, 1, 1, 4534853444, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowman", "Snowman", "K", "Uncommon", 121944778, 5538532923, 1, 1, 1, 331745799, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Phantom", "Phantom", "K", "Common", 121944778, 1132701173, 1, 1, 1, 1133332075, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bio_K_2023", "Bio", "K", "Rare", 6600901997, 12926766355, 1, 1, 1, 12965298174, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ice", "Ice", "K", "Common", 121944778, 161313071, 1, 1, 1, 191976710, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "CandyCorn2019", "Candy Corn 2019", "K", "Common", 121944778, 4210409803, 1, 1, 1, 4210934082, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Denis", "Denis", "K", "Common", 121944778, 539825831, 1, 1, 1, 546161062, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Broken_K_2023", "Broken", "K", "Legendary", 10855586895, 12237805628, 1, 1, 1, 12339323856, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BatsK", "Bats (Common)", "K", "Common", 121944778, 2513648113, 1, 1, 1, 2513732731, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Coal", "Coal", "K", "Common", 121944778, 1268280806, 1, 1, 1, 1268699677, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Present_K_2023", "Present 2023", "K", "Common", 121944778, 15382053242, 1, 1, 1, 15635553149, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Hive", "Hive", "K", "Uncommon", 121944778, 314921929, 1, 1, 1, 315501434, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Euro", "Euro", "K", "Common", 121944778, 240940193, 1, 1, 1, 305504173, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bones_K_2020", "Bones 2020", "K", "Rare", 957726558, 5872477763, 1, 1, 1, 5872492951, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Icecracker_K_2020", "Icecracker", "K", "Legendary", 957726558, 6121847917, 1, 1, 1, 6121848805, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sparkle7", "Sparkle7", "K", "Common", 121944778, 306913560, 1, 1, 1, 310714089, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Corl", "Corl", "K", "Common", 121944778, 545392975, 1, 1, 1, 546161858, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sparkle3", "Sparkle3", "K", "Common", 121944778, 306916804, 1, 1, 1, 310710694, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Carrot", "Carrot", "K", "Common", 121944778, 387418042, 1, 1, 1, 387874071, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Icicles_K_2018", "Icicles", "K", "Rare", 121944778, 2659488219, 1, 1, 1, 2669639638, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Glowy_K_2023", "Glowy", "K", "Uncommon", 121944778, 15091291377, 1, 1, 1, 15091403551, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Tree2017", "Tree 2017", "K", "Uncommon", 121944778, 108294449974966, 1, 1, 1, 1268704124, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Santa", "Santa", "K", "Common", 121944778, 5359654461, 1, 1, 1, 331746096, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Coal_K_2018", "Coal 2018", "K", "Common", 121944778, 2669120347, 1, 1, 1, 2669638285, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Oily", "Oily", "K", "Common", 121944778, 314421009, 1, 1, 1, 315501170, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bats_K_2024", "Bats 2024", "K", "Common", 6600901997, 134605667915149, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Fanta", "Orange", "K", "Common", 121944778, 473621067, 1, 1, 1, 473626025, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Popsicle_K_2023", "Popsicle", "K", "Uncommon", 6600901997, 13884848877, 1, 1, 1, 13944131578, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ripper_K_2020", "Ripper", "K", "Legendary", 957726558, 5866360934, 1, 1, 1, 5866441301, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Witch", "Witch", "K", "Common", 121944778, 531836445, 1, 1, 1, 531873553, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Reaver_Ancient", "Reaver (Ancient)", "K", "Ancient", 7774148738, 7774148967, 0.2726, 0.2726, 0.2726, 7791640819, 0, -0.094, 0.0422, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Runic_K_2022", "Curse", "K", "Rare", 121944778, 11246439789, 1, 1, 1, 11254123390, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Midnight", "Midnight", "K", "Legendary", 121944778, 161367322, 1, 1, 1, 197664126, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Borders", "Borders", "K", "Common", 121944778, 155199285, 1, 1, 1, 198453499, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Toy_K_2023", "Toy", "K", "Common", 6600901997, 13884851371, 1, 1, 1, 13944128440, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ecto", "Ecto", "K", "Common", 121944778, 1132715027, 1, 1, 1, 1133331679, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Painted_K_2023", "Painted", "K", "Rare", 6600901997, 12935208652, 1, 1, 1, 12965311567, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Splatter", "Splatter", "K", "Common", 121944778, 16944380350, 1, 1, 1, 16964346058, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Plasmite", "Plasmite", "K", "Legendary", 121944778, 161369273, 1, 1, 1, 161369368, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Watcher_K_2021", "Watcher 2021", "K", "Rare", 121944778, 7756613596, 1, 1, 1, 7800227475, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Mummified", "Mummified", "K", "Common", 957726558, 4210409851, 1, 1, 1, 4210946577, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Hazmat", "Hazmat", "K", "Uncommon", 121944778, 311358906, 1, 1, 1, 315501297, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Stickers_K_2024", "Stickers 2024 · Stickers_K_2024", "K", "Common", 6600901997, 121348523107585, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ginger", "Ginger", "K", "Rare", 121944778, 5353674093, 1, 1, 1, 331744703, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Eco", "Eco", "K", "Common", 121944778, 365566401, 1, 1, 1, 365567889, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Indy", "Indy", "K", "Common", 121944778, 240943629, 1, 1, 1, 305506951, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Tree_K_2022", "Tree 2022", "K", "Rare", 957726558, 11803199540, 1, 1, 1, 11834400185, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Carrot_K_2023", "Carrot 2023", "K", "Uncommon", 6600901997, 12928323969, 1, 1, 1, 12965307410, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "CandyCorn_K_2024", "Candy Corn 2024", "K", "Common", 6600901997, 76315981363183, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerbread_K_2020", "Gingerbread 2020", "K", "Uncommon", 957726558, 6121849468, 1, 1, 1, 6121850031, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Traveler_K_2023", "Traveler", "K", "Legendary", 957726558, 15069923204, 1, 1, 1, 15091407901, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "HighTech", "High Tech", "K", "Uncommon", 957726558, 4659546595, 1, 1, 1, 4659635055, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bluesteel", "Bluesteel", "K", "Uncommon", 121944778, 157904876, 1, 1, 1, 159947939, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Lucky", "Lucky", "K", "Uncommon", 121944778, 365566400, 1, 1, 1, 365569265, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Wrapped", "Wrapped", "K", "Uncommon", 121944778, 5366242489, 1, 1, 1, 331745500, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowman_K_2024", "Snowman 2024", "K", "Uncommon", 6600901997, 75066955538535, 1, 1, 1, 85751270338066, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowman_K_2022", "Snowman 2022", "K", "Common", 957726558, 11823641715, 1, 1, 1, 11834391469, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "VoidRbx", "Void", "K", "Uncommon", 121944778, 11548074269, 1, 1, 1, 11548082732, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cursed_K_2024", "Cursed", "K", "Legendary", 6600901997, 137589393181339, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Spectral_K_2021", "Spectral", "K", "Legendary", 121944778, 7756613337, 1, 1, 1, 7800226793, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Graffiti", "Graffiti", "K", "Uncommon", 957726558, 4659573175, 1, 1, 1, 4659634630, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Moons_K_2024", "Moons 2024", "K", "Uncommon", 6600901997, 87244940102225, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Pepper", "Brown", "K", "Common", 121944778, 473620934, 1, 1, 1, 473625645, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cheesy", "Cheesy", "K", "Uncommon", 121944778, 161425686, 1, 1, 1, 198455898, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Giftwrap_K_2021", "Giftwrap", "K", "Common", 121944778, 8275035514, 1, 1, 1, 8304754179, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Haunted_K_2021", "Haunted 2021", "K", "Common", 121944778, 7756611602, 1, 1, 1, 7800222135, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Floral_K_2023", "Floral", "K", "Rare", 6600901997, 13894957068, 1, 1, 1, 13944135218, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ghosty", "Ghosty", "K", "Common", 121944778, 531835085, 1, 1, 1, 531873080, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Paper", "Paper", "K", "Uncommon", 121944778, 179035664, 1, 1, 1, 235366870, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Carrot_K_2024", "Carrot 2024", "K", "Uncommon", 6600901997, 16845528588, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bones", "Bones", "K", "Common", 121944778, 531836449, 1, 1, 1, 531873816, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "MagmaK", "Magma", "K", "Rare", 121944778, 1782168732, 1, 1, 1, 1133317890, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Zombie_K_2021", "Zombie 2021", "K", "Uncommon", 121944778, 7845697152, 1, 1, 1, 7800222975, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Wraith_K_2022", "Wraith", "K", "Rare", 121944778, 11215449757, 1, 1, 1, 11254118399, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Melon", "Melon", "K", "Uncommon", 121944778, 311701292, 1, 1, 1, 315501369, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cavern_K_2019", "Cavern", "K", "Legendary", 957726558, 4534822092, 1, 1, 1, 4534861110, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Neon", "Neon", "K", "Common", 121944778, 159653652, 1, 1, 1, 159746637, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ornament1", "Ornament (Common)", "K", "Common", 121944778, 331744475, 1, 1, 1, 331745428, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Eggs", "Egg", "K", "Common", 121944778, 386052294, 1, 1, 1, 387875405, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Roses", "Roses", "K", "Common", 121944778, 361630297, 1, 1, 1, 363352002, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Frozen_K_2023", "Frozen 2023", "K", "Common", 121944778, 15382634403, 1, 1, 1, 15635556891, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sparkle1", "Sparkle1", "K", "Common", 121944778, 306912202, 1, 1, 1, 310709709, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Checker", "Checker", "K", "Uncommon", 121944778, 160167441, 1, 1, 1, 198461230, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Summer_Stickers_K_2023", "Stickers 2023", "K", "Common", 6600901997, 13895498375, 1, 1, 1, 13944129977, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cane", "Cane", "K", "Rare", 121944778, 5359571109, 1, 1, 1, 331140746, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Jack_K_2022", "Lantern", "K", "Uncommon", 121944778, 11245572024, 1, 1, 1, 11254093910, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sorry", "Corrupt", "K", "Unique", 121944778, 162016526, 1, 1, 1, 197879343, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowflakes_K_2020", "Snowflakes 2020", "K", "Rare", 121944778, 137773102398455, 1, 1, 1, 6123338102, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Scarf_K_2023", "Scarf", "K", "Common", 121944778, 15414881863, 1, 1, 1, 15415482999, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Santa2017", "Santa 2017", "K", "Common", 121944778, 1268277801, 1, 1, 1, 1268703618, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Brains2019", "Brains 2019", "K", "Uncommon", 957726558, 4210409062, 1, 1, 1, 4210929184, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Vortex", "Vortex", "K", "Rare", 121944778, 235347825, 1, 1, 1, 235371508, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Stickers_K_2022", "Stickers 2022 · Stickers_K_2022", "K", "Common", 121944778, 11217750489, 1, 1, 1, 11254067158, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Elf", "Elf", "K", "Common", 121944778, 5364286895, 1, 1, 1, 331746317, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ribbons_K_2021", "Ribbons", "K", "Common", 121944778, 8275035072, 1, 1, 1, 8304754882, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sparkle6", "Sparkle6", "K", "Common", 121944778, 306915414, 1, 1, 1, 310713648, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "RbxScary_K_2023", "Ghoulish", "K", "Common", 121944778, 114660299589667, 1, 1, 1, 14967668214, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Vampire", "Vampire", "K", "Uncommon", 121944778, 531835090, 1, 1, 1, 531873248, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Fragile_G_2023", "Fragile", "G", "Common", 79401392, 12942152157, 1.5, 1.5, 1.5, 12965349193, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "GraveG", "Grave", "G", "Common", 2514719081, 2513648170, 1, 1, 1, 2513731746, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "GreenCamo_K_2022", "Zombie Camo", "K", "Common", 121944778, 121944805, 1, 1, 1, 11254145154, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Wrapped_G_2018", "Wrapped 2018", "G", "Common", 79401392, 124221082305936, 1.6, 1.6, 1.6, 2669787533, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Wraith_G_2022", "Wraith", "G", "Rare", 79401392, 83637468346183, 1.6, 1.6, 1.6, 11255504462, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Webs_G_2022", "Webs", "G", "Common", 79401392, 11255255382, 1.6, 1.6, 1.6, 11284147880, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "WebbedG", "Webbed", "G", "Common", 79401392, 130141624327731, 1.6, 1.6, 1.6, 4210936652, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Wavy_G_2024", "Wavy", "G", "Common", 79401392, 16846545641, 1.6, 1.6, 1.6, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Vines_G_2023", "Vines", "G", "Common", 79401392, 15045930187, 1.6, 1.6, 1.6, 15091402817, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Vampire_G_2022", "Vampire 2022", "G", "Legendary", 79401392, 11228808312, 1.6, 1.6, 1.6, 11255503583, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Tree_G_2022", "Tree 2022", "G", "Rare", 79401392, 77983878883558, 1.6, 1.6, 1.6, 11834441321, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Traveler_G_2023", "Traveler", "G", "Legendary", 79401392, 89199801409332, 1.6, 1.6, 1.6, 15091344462, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "ToxicG", "Toxic", "G", "Rare", 79401392, 2513648169, 1.6, 1.6, 1.6, 2513742519, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Sweater_G_2018", "Sweater 2018", "G", "Uncommon", 79401392, 2664997267, 1.6, 1.6, 1.6, 2669787088, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Stockings_G_2022", "Stockings 2022", "G", "Uncommon", 79401392, 11831384378, 1.6, 1.6, 1.6, 11834440319, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "StickersX_G_2022", "Stickers 2022", "G", "Common", 79401392, 11830420444, 1.6, 1.6, 1.6, 11834432971, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Steel_G_2023", "Steel", "G", "Uncommon", 79401392, 15044112684, 1.6, 1.6, 1.6, 15091341552, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Stars_G_2023", "Stars", "G", "Uncommon", 79401392, 15383997060, 1.6, 1.6, 1.6, 15635574031, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Starry_G_2020", "Starry 2020", "G", "Common", 79401392, 5930583738, 1.6, 1.6, 1.6, 5930731295, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Starfish_G_2024", "Starfish", "G", "Common", 79401392, 18321970590, 1.6, 1.6, 1.6, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Splat", "Splat", "G", "Common", 79401392, 3183406439, 1.6, 1.6, 1.6, 3183639522, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Spectral_G_2021", "Spectral", "G", "Legendary", 79401392, 7757802804, 1.6, 1.6, 1.6, 7800255531, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Snowman_G_2023", "Snowman 2023", "G", "Uncommon", 79401392, 15382659346, 1.6, 1.6, 1.6, 15635572427, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Snowman_G_2022", "Snowman 2022", "G", "Common", 79401392, 11830604534, 1.6, 1.6, 1.6, 11834436620, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Snowflakes_G_2019", "Snowflakes", "G", "Common", 79401392, 4534835479, 1.6, 1.6, 1.6, 4534866065, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Snowman_G_2018", "Snowman 2018", "G", "Common", 79401392, 2669119107, 1.6, 1.6, 1.6, 2669786846, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Snowflake_G_2023", "Snowflake 2023", "G", "Rare", 79401392, 15351058932, 1.6, 1.6, 1.6, 15635575718, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Snowflake_G_2022", "Snowflake 2022", "G", "Uncommon", 79401392, 11830940122, 1.6, 1.6, 1.6, 11834437796, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Snowflake_G_2018", "Snowflake 2018", "G", "Uncommon", 79401392, 2659487954, 1.6, 1.6, 1.6, 2669786515, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "SnakebiteG", "Snakebite", "G", "Rare", 79401392, 109575851098597, 1.6, 1.6, 1.6, 4210925026, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "SlimeG", "Slime", "G", "Common", 79401392, 2513648152, 1.6, 1.6, 1.6, 2513742319, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "SilentNight_G_2020", "Silent Night", "G", "Rare", 79401392, 6121861331, 1.6, 1.6, 1.6, 6121862034, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Santa_G_2023", "Santa 2023", "G", "Common", 79401392, 15349904283, 1.6, 1.6, 1.6, 15635550625, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Santa_G_2018", "Elf 2018", "G", "Common", 79401392, 2664997044, 1.6, 1.6, 1.6, 2669785184, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Sandy_G_2024", "Sandy", "G", "Common", 79401392, 18323743340, 1.6, 1.6, 1.6, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "RainbowGun", "Rainbow", "G", "Rare", 79401392, 3183408196, 1.6, 1.6, 1.6, 3183640145, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Pumpkin_G_2023", "Pumpkin", "G", "Common", 79401392, 15044730839, 1.6, 1.6, 1.6, 15091327743, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "PotionG2018", "Potion", "G", "Uncommon", 79401392, 2513648149, 1.6, 1.6, 1.6, 2513742133, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Predator", "Predator", "G", "Legendary", 79401392, 202773960, 1.6, 1.6, 1.6, 203810176, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Portal_G_2020", "Portal", "G", "Uncommon", 79401392, 5866372960, 1.6, 1.6, 1.6, 5866461926, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Popsicle_G_2024", "Popsicle", "G", "Uncommon", 79401392, 18321970792, 1.6, 1.6, 1.6, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Pirate", "Pirate", "G", "Uncommon", 79401392, 78093206510643, 1.6, 1.6, 1.6, 3183639867, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Pine_G_2019", "Pine", "G", "Common", 79401392, 4534870630, 1.6, 1.6, 1.6, 4534871260, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Palms_G_2024", "Palms", "G", "Legendary", 79401392, 18321971106, 1.6, 1.6, 1.6, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Ornaments_G_2020", "Ornaments", "G", "Common", 79401392, 6121862915, 1.6, 1.6, 1.6, 6121863515, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Neon_G_2023", "Neon", "G", "Rare", 79401392, 15382654157, 1.6, 1.6, 1.6, 15635560825, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Mummy", "Mummy", "G", "Rare", 79401392, 315154445, 1.6, 1.6, 1.6, 315155591, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Moonlight_G_2022", "Moonlight", "G", "Uncommon", 79401392, 11254380241, 1.6, 1.6, 1.6, 11284143055, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Mistletoe_G_2022", "Mistletoe", "G", "Uncommon", 79401392, 11831277409, 1.6, 1.6, 1.6, 11834438982, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Latte_G_2023", "Latte", "G", "Legendary", 79401392, 15320206276, 1.6, 1.6, 1.6, 15413116029, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Infected_G_2022", "Infected", "G", "Common", 79401392, 11227996367, 1.6, 1.6, 1.6, 11255502768, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Icicles_G_2018", "Icicles", "G", "Rare", 79401392, 2659488496, 1.6, 1.6, 1.6, 2669786044, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Icedriller_G_2020", "Icedriller", "G", "Legendary", 79401392, 6121865669, 1.6, 1.6, 1.6, 6121866490, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "IceCamo_G_2021", "Ice Camo", "G", "Rare", 79401392, 8275032575, 1.6, 1.6, 1.6, 8304767724, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Holly_G_2018", "Holly", "G", "Uncommon", 79401392, 2664997622, 1.6, 1.6, 1.6, 2669786261, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Hazard_G_2022", "Hazard", "G", "Uncommon", 79401392, 11227146152, 1.6, 1.6, 1.6, 11255505449, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "HauntedG", "Haunted", "G", "Common", 79401392, 2513648133, 1.6, 1.6, 1.6, 2513741901, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Gingerbread_G_2022", "Gingerbread 2022", "G", "Rare", 79401392, 11810420546, 1.6, 1.6, 1.6, 11834442414, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Gingerbread_G_2021", "Gingerbread 2021", "G", "Uncommon", 79401392, 8275032201, 1.6, 1.6, 1.6, 8304772140, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Gingerbread_G_2020", "Gingerbread 2020", "G", "Uncommon", 79401392, 6121859173, 1.6, 1.6, 1.6, 6121860619, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Ginger_G_2018", "Ginger 2018", "G", "Legendary", 79401392, 2659488834, 1.6, 1.6, 1.6, 2669785821, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Gifts_G_2019", "Gifts", "G", "Common", 79401392, 4534835908, 1.6, 1.6, 1.6, 4534867381, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Giftbag_G_2020", "Gift Bag", "G", "Common", 79401392, 6121864116, 1.6, 1.6, 1.6, 6121864813, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Gift_G_2020", "Wrap", "G", "Uncommon", 79401392, 6121866988, 1.6, 1.6, 1.6, 6121867603, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Ghosts_G_2021", "Wraiths", "G", "Uncommon", 79401392, 7758397251, 1.6, 1.6, 1.6, 7800251557, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Ghosts_G_2020", "Ghosts", "G", "Rare", 79401392, 5866372208, 1.6, 1.6, 1.6, 5866465099, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Ghostfire_G_2022", "Ghostfire", "G", "Rare", 79401392, 11254634864, 1.6, 1.6, 1.6, 11284140034, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "GhostG2018", "Ghost", "G", "Legendary", 79401392, 2513648114, 1.6, 1.6, 1.6, 2513741407, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Ghastly_G_2023", "Ghastly", "G", "Rare", 79401392, 15045716708, 1.6, 1.6, 1.6, 15091342564, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Frozen_G_2023", "Frozen 2023", "G", "Common", 79401392, 15344638282, 1.6, 1.6, 1.6, 15635571468, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Frostfade_G_2023", "Frostfade", "G", "Legendary", 79401392, 15383614259, 1.6, 1.6, 1.6, 15635577623, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Frosted_G_2019", "Frosted", "G", "Common", 79401392, 4528661069, 1.6, 1.6, 1.6, 4534866678, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Floatie_G_2024", "Floatie", "G", "Uncommon", 79401392, 18321972013, 1.6, 1.6, 1.6, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "FallCamo_G_2021", "Fall Camo", "G", "Uncommon", 79401392, 7758737021, 1.6, 1.6, 1.6, 7800257544, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Eyes_G_2020", "Watcher 2020", "G", "Common", 79401392, 5866372450, 1.6, 1.6, 1.6, 5866459380, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Elf_G_2023", "Elf 2023", "G", "Common", 79401392, 15349698419, 1.6, 1.6, 1.6, 15635569893, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "DefaultGun", "Default Gun", "G", "Common", 79401392, 91723031, 1.6, 1.6, 1.6, 197518111, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Darkness_G_2022", "Darkness", "G", "Common", 79401392, 11242038756, 1.6, 1.6, 1.6, 11255507374, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Dark_G_2023", "Darkgun", "G", "Rare", 79401392, 15082826256, 1.6, 1.6, 1.6, 15091406343, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Cookie_G_2021", "Cookie", "G", "Uncommon", 79401392, 8275032831, 1.6, 1.6, 1.6, 8304771148, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Coal_G_2021", "Coal 2021", "G", "Common", 79401392, 8275033614, 1.6, 1.6, 1.6, 8304769409, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Coal_G_2022", "Coal 2022", "G", "Common", 79401392, 11809114380, 1.6, 1.6, 1.6, 11834434264, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Coal_G_2018", "Coal 2018", "G", "Common", 79401392, 2669120201, 1.6, 1.6, 1.6, 2669784920, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Clownfish_G_2024", "Clownfish", "G", "Common", 79401392, 18321972771, 1.6, 1.6, 1.6, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Cavern_G_2019", "Cavern", "G", "Legendary", 79401392, 128240852390197, 1.6, 1.6, 1.6, 4534875511, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Cat_G_2021", "Cat", "G", "Common", 79401392, 7759004533, 1.6, 1.6, 1.6, 7800253444, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Carved_G_2020", "Carved", "G", "Common", 79401392, 5866372800, 1.6, 1.6, 1.6, 5866457985, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Carrot_G_2024", "Carrot", "G", "Uncommon", 79401392, 16856497935, 1.6, 1.6, 1.6, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Canes_G_2023", "Canes", "G", "Uncommon", 79401392, 15383886872, 1.6, 1.6, 1.6, 15635558982, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "CandySwirl_G_2019", "Candy Swirl", "G", "Rare", 79401392, 4534836730, 1.6, 1.6, 1.6, 4534874602, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Cane_G_2018", "Cane 2018", "G", "Rare", 79401392, 2659489762, 1.6, 1.6, 1.6, 2669785546, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "CandyCorn_G_2022", "Candy Corn 2022", "G", "Common", 79401392, 11226919330, 1.6, 1.6, 1.6, 11255558166, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Candied_G_2022", "Candied", "G", "Common", 79401392, 11809753556, 1.6, 1.6, 1.6, 11834435627, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Brains_G_2022", "Brains", "G", "Uncommon", 79401392, 11254925304, 1.6, 1.6, 1.6, 11284145298, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Bones2019", "Bones", "G", "Uncommon", 79401392, 4210405561, 1.6, 1.6, 1.6, 4210926347, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "BatsG", "Bats", "G", "Common", 79401392, 2513648112, 1.6, 1.6, 1.6, 2513741174, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Apoc_G_2022", "Apocalypse", "G", "Common", 79401392, 11228269165, 1.6, 1.6, 1.6, 11255501940, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Arctic_G_2022", "Arctic", "G", "Legendary", 79401392, 85287913991189, 1.6, 1.6, 1.6, 11834443783, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Watcher_G_2021", "Watcher 2021", "G", "Rare", 79401392, 7757907850, 1.5, 1.5, 1.5, 7800256309, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Floral_G_2024", "Floral", "G", "Rare", 79401392, 18323742549, 1.5, 1.5, 1.5, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Melon_G_2023", "Melon", "G", "Uncommon", 79401392, 13904908523, 1.5, 1.5, 1.5, 13944154336, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Starry_G_2021", "Starry 2021", "G", "Rare", 79401392, 8303507091, 1.5, 1.5, 1.5, 8304772774, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Toy_G_2023", "Toy", "G", "Common", 79401392, 13905642635, 1.5, 1.5, 1.5, 13944153112, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Camo", "Camo", "G", "Uncommon", 79401392, 160024546, 1.5, 1.5, 1.5, 160024789, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Star", "Star", "G", "Common", 79401392, 161642996, 1.5, 1.5, 1.5, 203807904, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "GoldenGun", "Golden", "G", "Classic", 25298496, 134632723, 1.5, 1.5, 1.5, 147835357, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Wooden", "Wooden", "G", "Uncommon", 79401392, 84001524223260, 1.5, 1.5, 1.5, 238546356, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "iRevolver", "iRevolver", "G", "Rare", 79401392, 160219396, 1.5, 1.5, 1.5, 203809168, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Magma_G_2021", "Magma", "G", "Rare", 79401392, 7758322982, 1.5, 1.5, 1.5, 7800252572, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "SnowmanGun", "Snowman", "G", "Uncommon", 79401392, 332496723, 1.5, 1.5, 1.5, 332497603, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Sketch", "Sketch", "G", "Uncommon", 79401392, 161976144, 1.5, 1.5, 1.5, 203808108, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "ElfGun", "Elf", "G", "Common", 79401392, 86899632763415, 1.5, 1.5, 1.5, 332767999, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Ritual_G_2024", "Ritual", "G", "Rare", 79401392, 122499606241450, 1.5, 1.5, 1.5, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "SlouseClownGun", "Clown", "G", "Unique", 79401392, 4663058089, 1.5, 1.5, 1.5, 4659627976, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Ornament2Gun", "Ornament2", "G", "Common", 79401392, 332496722, 1.5, 1.5, 1.5, 332497550, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "MummyG2018", "Mummy 2018", "G", "Uncommon", 79401392, 2513708668, 1.5, 1.5, 1.5, 2513741663, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "ZombifiedG", "Zombified", "G", "Uncommon", 79401392, 137443657929688, 1.5, 1.5, 1.5, 4210944924, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Aliens_G_2021", "Aliens", "G", "Common", 79401392, 94636545088559, 1.5, 1.5, 1.5, 7800250906, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "CaneGun", "Cane", "G", "Rare", 79401392, 112112286408164, 1.5, 1.5, 1.5, 332497187, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Bacon", "Bacon", "G", "Rare", 79401392, 178240361, 1.5, 1.5, 1.5, 238546467, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "GingerGun", "Ginger", "G", "Rare", 79401392, 140264190350882, 1.5, 1.5, 1.5, 332497038, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Bats_G_2024", "Bats 2024", "G", "Common", 79401392, 127442391741629, 1.5, 1.5, 1.5, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Lights_G_2019", "Lights 2019", "G", "Uncommon", 79401392, 4534840659, 1.5, 1.5, 1.5, 4534872673, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Molten", "Molten", "G", "Rare", 79401392, 160570263, 1.5, 1.5, 1.5, 203869308, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Gingerbread_G_2019", "Gingerbread 2019", "G", "Uncommon", 79401392, 4534842979, 1.5, 1.5, 1.5, 4534872116, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Galactic", "Galactic", "G", "Rare", 79401392, 173912996, 1.5, 1.5, 1.5, 173913533, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Engraved", "Engraved", "G", "Common", 79401392, 159670413, 1.5, 1.5, 1.5, 203807690, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "SantaGun", "Santa", "G", "Common", 79401392, 76370731428901, 1.5, 1.5, 1.5, 332496861, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Nuke_G_2023", "Nuke", "G", "Rare", 79401392, 12936824008, 1.5, 1.5, 1.5, 12965335931, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "BluesteelGun", "Bluesteel", "G", "Uncommon", 79401392, 161420087, 1.5, 1.5, 1.5, 162668203, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Ornament1Gun", "Ornament1", "G", "Common", 79401392, 332358313, 1.5, 1.5, 1.5, 332497144, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Bleed", "Rupture", "G", "Legendary", 79401392, 315010891, 1.5, 1.5, 1.5, 315100702, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Candleflame_G_2024", "Candleflame", "G", "Rare", 79401392, 115359559909377, 1.5, 1.5, 1.5, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Marina", "Marina", "G", "Uncommon", 79401392, 159899596, 1.5, 1.5, 1.5, 203808190, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "XmasStickers_G_2021", "Stickers 2021 · XmasStickers_G_2021", "G", "Common", 79401392, 110585366732058, 1.6, 1.6, 1.6, 8304770115, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Cracks_G_2021", "Cracks", "G", "Common", 79401392, 7758056748, 1.5, 1.5, 1.5, 7800254737, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Stickers_G_2021", "Stickers 2021 · Stickers_G_2021", "G", "Common", 79401392, 7758615144, 1.5, 1.5, 1.5, 7800257010, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "WrappedGun", "Wrapped", "G", "Uncommon", 79401392, 103005044438900, 1.5, 1.5, 1.5, 332497103, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Caution", "Caution", "G", "Uncommon", 79401392, 48737841, 1.5, 1.5, 1.5, 238546422, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "HL2", "HL2", "G", "Common", 79401392, 181689885, 1.5, 1.5, 1.5, 238546100, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "WaterBalloons_G_2024", "Balloons", "G", "Common", 79401392, 18323742698, 1.5, 1.5, 1.5, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Gun1", "Cowboy", "G", "Classic", 79401392, 79401500, 1.5, 1.5, 1.5, 144290769, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Sunset_G_2023", "Sun", "G", "Rare", 79401392, 13896017136, 1.5, 1.5, 1.5, 13944156090, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Nightfire", "Nightfire", "G", "Rare", 79401392, 4659577665, 1.5, 1.5, 1.5, 4659626966, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Frozen_G_2019", "Frozen 2019", "G", "Uncommon", 79401392, 4528661973, 1.5, 1.5, 1.5, 4534873956, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Summer_Stickers_G_2023", "Stickers 2023", "G", "Common", 79401392, 13905821320, 1.5, 1.5, 1.5, 13944151909, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Ace", "Ace", "G", "Rare", 79401392, 178208194, 1.5, 1.5, 1.5, 238546577, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Asteroid", "Asteroid", "G", "Common", 79401392, 6394252363, 1.5, 1.5, 1.5, 476599365, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Mummy_G_2020", "Mummy 2020", "G", "Uncommon", 79401392, 5866372623, 1.5, 1.5, 1.5, 5866463755, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Night", "Night", "G", "Uncommon", 79401392, 159882296, 1.5, 1.5, 1.5, 159971385, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Splash_G", "Splash", "G", "Legendary", 79401392, 4659576260, 1.5, 1.5, 1.5, 4659626370, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "CandyCorn_G_2024", "Candy Corn 2024", "G", "Common", 79401392, 110799536201694, 1.5, 1.5, 1.5, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Painted_G_2023", "Painted", "G", "Uncommon", 79401392, 12937817240, 1.5, 1.5, 1.5, 12965344675, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Spitfire", "Spitfire", "G", "Rare", 79401392, 159883934, 1.5, 1.5, 1.5, 159971321, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Snowman_G_2021", "Snowman 2021", "G", "Uncommon", 79401392, 8275033129, 1.5, 1.5, 1.5, 8304766932, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "VampireG2018", "Vampire 2018", "G", "Rare", 79401392, 2513708622, 1.5, 1.5, 1.5, 2513742751, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Imbued", "Imbued", "G", "Rare", 79401392, 156263287, 1.5, 1.5, 1.5, 162668312, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Pea", "Pea", "G", "Common", 79401392, 162911948, 1.5, 1.5, 1.5, 238545971, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Viper", "Viper", "G", "Legendary", 79401392, 159991281, 1.5, 1.5, 1.5, 160299600, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Universe", "Universe", "G", "Legendary", 79401392, 238542777, 1.5, 1.5, 1.5, 238546660, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "TreeGun", "Tree", "G", "Legendary", 79401392, 106909830955114, 1.5, 1.5, 1.5, 332497688, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Nutcracker", "Nutcracker", "G", "Uncommon", 79401392, 5538506180, 1.5, 1.5, 1.5, 332497657, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Infiltrator", "Infiltrator", "G", "Common", 79401392, 156265112, 1.5, 1.5, 1.5, 203806022, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Clown_G_2024", "Clown 2024", "G", "Uncommon", 79401392, 83300450889998, 1.5, 1.5, 1.5, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "BigKill", "Big Kill", "G", "Common", 79401392, 159963965, 1.5, 1.5, 1.5, 162669041, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Aurora_G_2019", "Aurora 2019", "G", "Rare", 79401392, 70440729181948, 1.5, 1.5, 1.5, 4534875165, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "ZombieG2018", "Zombie", "G", "Uncommon", 79401392, 140056674605111, 1.5, 1.5, 1.5, 2513743298, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "RIP", "RIP", "G", "Common", 79401392, 4210409923, 1.5, 1.5, 1.5, 4210947993, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "CandyCorn_G_2020", "Candy Corn 2020", "G", "Common", 79401392, 5866371945, 1.5, 1.5, 1.5, 5866454590, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Cold", "Cold", "G", "Common", 79401392, 161309663, 1.5, 1.5, 1.5, 161309889, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Leaves_G_2024", "Leaves", "G", "Uncommon", 79401392, 105437948088593, 1.5, 1.5, 1.5, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Overseer", "Overseer", "G", "Legendary", 79401392, 162262248, 1.5, 1.5, 1.5, 175668680, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Stickers_G_2024", "Stickers 2024 · Stickers_G_2024", "G", "Common", 79401392, 89311097227409, 1.5, 1.5, 1.5, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Sparkle", "Sparkle", "G", "Legendary", 79401392, 162976205, 1.5, 1.5, 1.5, 203869110, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Hacker", "Hacker", "G", "Rare", 79401392, 198413638, 1.5, 1.5, 1.5, 203819271, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Cursed_G_2024", "Cursed", "G", "Legendary", 79401392, 134978959658778, 1.5, 1.5, 1.5, 0, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "LoveGun", "Love", "G", "Uncommon", 79401392, 159686237, 1.5, 1.5, 1.5, 203867650, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Iron", "Iron", "G", "Common", 79401392, 159707533, 1.5, 1.5, 1.5, 160201541, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Fallout", "Fallout", "G", "Common", 79401392, 172596465, 1.5, 1.5, 1.5, 175668592, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Cola", "Soda", "G", "Uncommon", 79401392, 320398770, 1.5, 1.5, 1.5, 238546400, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Gothic_G_2021", "Gothic", "G", "Uncommon", 79401392, 7758572472, 1.5, 1.5, 1.5, 7800253970, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Monster", "Monster", "G", "Rare", 79401392, 4210409812, 1.5, 1.5, 1.5, 4210941474, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Aid", "Juice", "G", "Common", 79401392, 7164849213, 1.5, 1.5, 1.5, 203807397, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Ripper_G_2020", "Ripper", "G", "Legendary", 79401392, 5866373797, 1.5, 1.5, 1.5, 5866460591, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Aurora_G_2021", "Aurora 2021", "G", "Legendary", 79401392, 96698273353001, 1.5, 1.5, 1.5, 8304766165, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Chromatic_G_2023", "Chromatic", "G", "Legendary", 79401392, 12937562728, 1.5, 1.5, 1.5, 12965339774, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Bit", "Bit", "G", "Common", 79401392, 178259396, 1.5, 1.5, 1.5, 238549030, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "News", "News", "G", "Common", 79401392, 178238688, 1.5, 1.5, 1.5, 238546032, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Cheddar", "Cheddar", "G", "Uncommon", 79401392, 160274812, 1.5, 1.5, 1.5, 203808317, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "SawChroma", "Saw · SawChroma", "K", "Godly", 168119698, 3171086347, 0.5, 0.5, 0.55, 3187398132, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Knife1", "Splitter", "K", "Classic", 22771612, 22771560, 0.15, 0.15, 0.15, 143820641, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Icewing", "Icewing", "K", "Ancient", 3183449780, 2279588369, 0.085, 0.085, 0.085, 2669997196, -0.0001, -1, -0.1, 1, 0, 0, 0, 0.8625, -0.5061, 0, 0.5061, 0.8625 },
        	{ "IceShard", "Ice Shard", "K", "Godly", 188539751, 188539820, 0.85, 0.85, 0.85, 1268710824, -0.0001, -0.0312, 1.071, 1, 0, 0, 0, -0.0842, 0.9965, 0, -0.9965, -0.0842 },
        	{ "IceDragon", "Ice Dragon", "K", "Godly", 165708869, 165708903, 0.5, 0.5, 0.5, 585846454, -0.0001, -0.1514, 1.2029, 1, 0, 0, 0, 0.0802, 0.9968, 0, -0.9968, 0.0802 },
        	{ "HeatChroma", "Heat · HeatChroma", "K", "Godly", 105333894, 3171194706, 0.3, 0.3, 0.3, 3187444849, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Heat", "Heat · Heat", "K", "Godly", 105333894, 105334003, 0.3, 0.3, 0.3, 3187444758, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Handsaw", "Handsaw", "K", "Godly", 54430772, 54430066, 0.4, 0.6, 0.53, 332042435, 0.0031, 0.0461, -0.803, -1, -0.0004, 0.0029, 0.0029, -0.0614, 0.9981, -0.0002, 0.9981, 0.0614 },
        	{ "HallowsBlade", "Hallow's Blade", "K", "Godly", 179155055, 1132750758, 0.55, 0.55, 0.555, 1132775323, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SwirlyGunBronze", "Bronze Swirly", "G", "Unique", 8310911339, 113787938041112, 1, 1, 1, 9552063524, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Gingermint_KChroma", "Cookiecane", "K", "Godly", 11837984324, 11837984504, 0.0687, 0.0687, 0.0687, 11979596437, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "GingerbladeChroma", "Gingerblade", "K", "Godly", 2248389833, 2248390749, 0.61, 0.61, 0.6095, 2672351679, -0.5814, 0.7932, -0.0418, 0.042, 0.6372, 0.7696, 0.0428, -0.7707, 0.6358, 0.9982, 0.0062, -0.0597 },
        	{ "GhostKnife", "Ghost", "K", "Classic", 64131019, 64131051, 3, 2, 2, 144268841, -0.0001, -0.0054, -0.6642, 1, 0, 0, 0, 0.0068, -1, 0, 1, 0.0068 },
        	{ "GemstoneChroma", "Gemstone · GemstoneChroma", "K", "Godly", 1626714161, 3183577898, 25, 25, 25, 3183657875, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gemstone", "Gemstone · Gemstone", "K", "Godly", 1626714161, 3183579677, 25, 25, 25, 3183657748, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Frostsaber", "Frostsaber", "K", "Godly", 1192795322, 1192795941, 0.55, 0.55, 0.6, 1268934541, 0, -0.0706, 1.1513, 1, 0, 0, 0, -0.0286, 0.9996, 0, -0.9996, -0.0286 },
        	{ "Frostbite", "Frostbite", "K", "Godly", 4528435571, 4528435630, 1.1, 1.1, 1.1, 4528373246, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Flames", "Flames", "K", "Godly", 238314098, 238314124, 0.6, 0.8, 0.73, 585873746, 0, 0.0027, 1.1242, 1, 0, 0, 0, 0.0654, 0.9979, 0, -0.9979, 0.0654 },
        	{ "FangChroma", "Fang · FangChroma", "K", "Godly", 117500241, 0, 0.4, 0.4, 0.4, 3187397850, 0, -1, -0.1, 0.0872, 0, -0.9962, 0, 1, 0, 0.9962, 0, 0.0872 },
        	{ "Fang", "Fang · Fang", "K", "Godly", 117500241, 117500388, 0.4, 0.4, 0.4, 3187397768, 0, -1, -0.1, 0.0872, 0, -0.9962, 0, 1, 0, 0.9962, 0, 0.0872 },
        	{ "EternalCane", "Eternalcane", "K", "Godly", 3132923779, 4488374804, 0.95, 0.95, 0.95, 4488391411, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Eternal4", "Eternal IV", "K", "Godly", 3132923779, 4999951444, 0.95, 0.95, 0.95, 4999958740, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Eternal3", "Eternal III", "K", "Godly", 3132923779, 3279683257, 0.95, 0.95, 0.95, 3281170430, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Eternal2", "Eternal II", "K", "Godly", 532155954, 2545251852, 0.5, 0.5, 0.5, 2545253030, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Eternal", "Eternal", "K", "Godly", 532155954, 532156041, 0.45, 0.45, 0.45, 538706317, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SwirlyGunSilver", "Silver Swirly", "G", "Unique", 8310911339, 108720084988330, 1, 1, 1, 9552064240, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "DeathshardChroma", "Deathshard · DeathshardChroma", "K", "Godly", 62275962, 3167029738, 0.75, 0.75, 0.75, 3187397317, 0, -1, -0.1001, 0, 0, -1, 0, 1, 0, 1, 0, 0 },
        	{ "Deathshard", "Deathshard · Deathshard", "K", "Godly", 62275962, 192567360, 0.75, 0.75, 0.75, 3175017717, 0, -1, -0.1, 0, 0, -1, 0, 1, 0, 1, 0, 0 },
        	{ "Darksword", "Darksword", "K", "Godly", 15020899066, 15020899218, 0.08, 0.08, 0.08, 15080267070, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Clockwork", "Clockwork", "K", "Godly", 352571495, 352570357, 1.1, 1.6, 1.2, 360609441, 0.0002, 0.0291, 1.1578, 1, 0, 0, 0, -0.0018, 1, 0, -1, -0.0018 },
        	{ "Chill", "Chill", "K", "Godly", 105329941, 105978218, 0.5, 0.5, 0.5, 332022166, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "CandyCorn", "CandyCorn", "K", "Common", 121944778, 1311187229, 1, 1, 1, 1133337797, 0, -0.9885, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "CandleflameChroma", "Candleflame", "K", "Godly", 7791364860, 7791364988, 0.065, 0.065, 0.065, 7806149582, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BonebladeChroma", "Boneblade", "K", "Godly", 1857106669, 2516324337, 0.7, 0.7, 0.7, 2513597845, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BlueSeer", "Blue Seer", "K", "Godly", 156092238, 3184062977, 0.7, 0.91, 1, 3184139996, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BloodKnife", "Blood", "K", "Classic", 51682254, 51941734, 0.5, 0.5, 0.3, 144307188, 0, -0.0504, -0.3497, 1, 0, 0, 0, -0.0392, -0.9992, 0, 0.9992, -0.0392 },
        	{ "BattleAxe", "BattleAxe", "K", "Godly", 1084767698, 1084767901, 0.56, 0.56, 0.56, 1133237368, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Nightblade", "Nightblade", "K", "Godly", 103838505, 103838996, 0.7, 0.45, 0.5, 475478854, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "OrangeSeer", "Orange Seer", "K", "Godly", 156092238, 7443788709, 0.7, 0.91, 1, 3184139504, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Peppermint", "Peppermint", "K", "Godly", 6085025295, 6074789360, 0.07, 0.07, 0.07, 6076067750, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Phantom2022", "Phantom 2022", "K", "Godly", 121944778, 95338306077286, 1, 1, 1, 11229732037, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Pixel", "Pixel", "K", "Godly", 361629844, 361630114, 3, 3, 3, 365347166, 0, -0.1546, 0.9239, 1, 0, 0, 0, 0, 1, 0, -1, 0 },
        	{ "Prismatic", "Prismatic", "K", "Godly", 5355753728, 5355747943, 0.06, 0.0692, 0.06, 5360359935, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Pumpking", "Pumpking", "K", "Godly", 94840342, 1133078553, 0.4, 0.4, 0.4, 1133082421, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "PurpleSeer", "Purple Seer", "K", "Godly", 156092238, 3184063317, 0.7, 0.91, 1, 3184140119, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "RedSeer", "Red Seer", "K", "Godly", 156092238, 3184063443, 0.7, 0.91, 1, 3184139367, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Saw", "Saw · Saw", "K", "Godly", 168119698, 168119736, 0.5, 0.5, 0.55, 3187397991, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "YellowSeer", "Yellow Seer", "K", "Godly", 156092238, 7443776855, 0.7, 0.91, 1, 3184139648, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Xmas", "Xmas", "K", "Godly", 187852667, 187852629, 0.6, 0.6, 0.6, 332077449, -0.0001, -0.124, 1.1068, 1, 0, 0, 0, 0, 1, 0, -1, 0 },
        	{ "WintersEdge", "Winter's Edge", "K", "Godly", 93108071, 93112631, 0.45, 0.45, 0.45, 1268708987, 0, -1, -0.1, 0, 0, -1, 0, 1, 0, 1, 0, 0 },
        	{ "Virtual", "Virtual", "K", "Godly", 130101214, 386250868, 0.6, 0.6, 0.7, 386276987, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Turkey2023", "Turkey", "K", "Godly", 15320557481, 86999625612475, 0.056, 0.056, 0.056, 15413162319, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Wrapped_K_2018", "Wrapped 2018", "K", "Common", 121944778, 2672196316, 1, 1, 1, 2669640357, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "AduriteGun", "Adurite", "G", "Uncommon", 79401392, 162812733, 1.5, 1.5, 1.5, 175668921, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "TimeKnife", "Prince", "K", "Classic", 70990583, 70990591, 0.5, 0.8, 0.5, 143917700, -0.0386, 0.0062, -0.9927, -0.0967, -0.0823, 0.9919, 0.9951, -0.0262, 0.0949, 0.0182, 0.9963, 0.0844 },
        	{ "TidesChroma", "Tides · TidesChroma", "K", "Godly", 238314382, 3171168641, 0.7, 0.9, 0.7, 3187398906, 0, -0.2257, 1.0324, 1, 0.0025, 0, 0, -0.0191, 0.9998, 0.0025, -0.9998, -0.0191 },
        	{ "Tides", "Tides · Tides", "K", "Godly", 238314382, 238314431, 0.7, 0.9, 0.7, 3187398809, 0, -0.226, 1.032, 1, 0, 0, 0, 0.048, 0.9988, 0, -0.9988, 0.048 },
        	{ "TheSeer", "Seer · TheSeer", "K", "Godly", 156092238, 156092253, 0.7, 0.91, 1, 3184139765, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Spider", "Spider", "K", "Godly", 302165984, 315122091, 0.55, 0.57, 0.52, 315120760, 0, -0.15, 0.973, 1, 0, 0, 0, 0, 1, 0, -1, 0 },
        	{ "Snowflake", "Snowflake", "K", "Godly", 582120569, 582120836, 0.6, 0.6, 0.6, 1268932977, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SlasherChroma", "Slasher · SlasherChroma", "K", "Godly", 283709822, 3171107559, 0.45, 0.45, 0.45, 3187398385, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Slasher", "Slasher · Slasher", "K", "Godly", 283709822, 313894904, 0.45, 0.45, 0.45, 3187398274, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ShadowKnife", "Shadow", "K", "Classic", 86297695, 86290910, 0.4, 0.2, 0.2, 144070096, 0, -0.0087, -0.703, 0.0033, 0, 1, 1, 0.0049, -0.0033, -0.0049, 1, 0 },
        	{ "SeerChroma", "Seer · SeerChroma", "K", "Godly", 156092238, 3184059718, 1, 1, 1, 3184140321, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Scythe", "Batwing", "K", "Ancient", 305826272, 2511673515, 1, 1, 1, 375690925, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "AuroraKnife", "Australis", "K", "Godly", 16025287191, 97521579968070, 0.0753, 0.0753, 0.0753, 101343256002049, 0, -1.1615, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BattleAxe2", "BattleAxe II", "K", "Godly", 2397016406, 2521633652, 0.7357, 0.7357, 0.7357, 2513535503, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bioblade", "Bioblade", "K", "Godly", 4662600017, 4751538400, 0.0624, 0.0684, 0.066, 4751540097, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "IcepiercerSilver", "Silver Icepiercer", "G", "Unique", 11868991644, 122077395445706, 0.0548, 0.0548, 0.0548, 12226843957, 0, -0.66, 0.2344, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Constellation_G_2024", "Nightsky", "G", "Legendary", 6600918074, 140562006976774, 0.0384, 0.0388, 0.0369, 94311965719769, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cookieblade", "Cookieblade", "K", "Godly", 6123168377, 6123168583, 1, 1, 1, 6121574620, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Eggblade", "Eggblade", "K", "Godly", 6596834762, 6596824396, 0.0686, 0.0686, 0.0686, 6607512359, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ElderwoodScythe", "Elderwood Scythe", "K", "Ancient", 4217523241, 4210044808, 0.0764, 0.0764, 0.0764, 4468593654, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "FlowerwoodKnife", "Flowerwood", "K", "Godly", 16883629972, 16895441338, 0.0792, 0.0792, 0.0792, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ghostblade", "Ghostblade", "K", "Godly", 4217554208, 4210531490, 0.0535, 0.0535, 0.0535, 4217586790, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Hallowscythe", "Hallowscythe", "K", "Ancient", 5841877975, 5841879647, 0.0708, 0.0708, 0.0708, 5877016863, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Heartblade", "Heartblade", "K", "Godly", 6404140078, 6413074818, 1.1003, 1.1003, 1.1003, 6413214382, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sugar", "Sugar", "G", "Godly", 101086719, 72286618177616, 0.5, 0.5, 0.5, 3215356000, -0.1, 0.536, 1.079, -1, 0, 0, 0, -1, 0, 0, 0, 1 },
        	{ "Iceflake", "Iceflake", "K", "Godly", 8231045240, 8231046270, 0.0675, 0.0675, 0.0675, 8304818186, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Logchopper", "Logchopper", "K", "Ancient", 4535643726, 4535641077, 1, 1, 1, 4528268775, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Nebula", "Nebula", "K", "Godly", 6596839942, 6256756879, 1.1522, 1.1522, 1.1522, 6598123521, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Pearl_K", "Pearl", "K", "Godly", 18276861801, 74986100175804, 0.0697, 0.0697, 0.0697, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Plasmablade", "Plasmablade", "K", "Godly", 9702732853, 10015130416, 0.0018, 0.0016, 0.0017, 10014680882, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Rainbow_K", "Rainbow (Godly)", "K", "Godly", 12921240966, 12921241867, 0.0652, 0.0652, 0.0652, 12966184630, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sakura_K", "Sakura", "K", "Godly", 12307707430, 12307707797, 0.0741, 0.0741, 0.0741, 12339366064, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SwirlyAxe", "Swirly Axe", "K", "Ancient", 8293463844, 8293464070, 0.0579, 0.0579, 0.0579, 8304801000, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SwirlyBlade", "Swirly Blade", "K", "Godly", 8302964090, 8302965681, 0.0669, 0.0669, 0.0669, 8304805693, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "VampiresEdge", "Vampire's Edge", "K", "Godly", 5841895234, 5842343736, 0.067, 0.067, 0.067, 5873256998, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "IceHammer", "Icecrusher (Rare)", "K", "Rare", 957726558, 11850788417, 1, 1, 1, 11855360152, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SwirlyAxeSilver", "Silver Swirly", "K", "Unique", 8293463844, 137014121340838, 0.0579, 0.0579, 0.0579, 9552051805, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Waves_K", "Waves", "K", "Godly", 13916938702, 13916939964, 0.0792, 0.0792, 0.0793, 13933066522, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "WraithKnife", "Spirit", "K", "Godly", 112444333460928, 131787177447081, 0.1047, 0.1047, 0.1047, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Wrapped_G_2024", "Wrapped 2024", "G", "Uncommon", 6600918074, 137311445183389, 0.0384, 0.0388, 0.0369, 109929760056853, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ZombieBat", "Bat", "K", "Godly", 11182796403, 11192090515, 0.0741, 0.0741, 0.0741, 11229814357, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Wrapped_K_2022", "Wrapped 2022", "K", "Common", 121944778, 331744478, 1, 1, 1, 11834403282, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Amerilaser", "Amerilaser", "G", "Godly", 116657254, 445884341, 0.7, 0.7, 0.7, 446050753, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BaubleChroma", "Bauble", "G", "Godly", 107813118898769, 109913147403488, 0.0471, 0.0471, 0.0471, 137938731902685, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Blaster", "Blaster", "G", "Godly", 92656610, 90586029262535, 0.4, 0.45, 0.5, 386277381, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Blossom_G", "Blossom", "G", "Godly", 12322809632, 12322809917, 0.0476, 0.0441, 0.0438, 12339377105, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ChromaDarkbringer", "Darkbringer", "G", "Godly", 4730813852, 4728494788, 0.039, 0.039, 0.039, 4751507011, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ChromaLightbringer", "Lightbringer", "G", "Godly", 4730813852, 4728487789, 0.039, 0.039, 0.039, 4751507078, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ConstellationChroma", "Constellation · ConstellationChroma", "G", "Godly", 124598402927958, 123603327635244, 0.1012, 0.1012, 0.1012, 98517109155878, 0, -0.27, 0.727, 1, 0, 0, 0, 0.9999, 0.0125, 0, -0.0125, 0.9999 },
        	{ "Darkshot", "Darkshot", "G", "Godly", 15027451531, 15027451643, 0.04, 0.04, 0.04, 15080280688, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Disint", "Laser (Classic)", "G", "Classic", 18265627, 18265614, 1, 1, 1, 54798135, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "GingerLuger", "Ginger Luger", "G", "Godly", 95356090, 2674981863, 1.8, 1.8, 1.8, 2674983099, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingermint_G", "Gingermint", "G", "Godly", 11866444071, 11866444253, 0.0461, 0.0461, 0.0461, 11872179646, 0, -0.3283, 0.7857, 1, 0, 0, 0, 0.9997, 0.0246, 0, -0.0246, 0.9997 },
        	{ "GreenLuger", "Green Luger", "G", "Godly", 95356090, 126534866, 1.8, 1.8, 1.8, 332044679, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Laser", "Laser · Laser", "G", "Godly", 130099641, 161254231, 0.5, 0.5, 0.5, 3187422496, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "LaserChroma", "Laser · LaserChroma", "G", "Godly", 130099641, 0, 0.5, 0.5, 0.5, 3187422628, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "LugerChroma", "Luger", "G", "Godly", 95356090, 0, 1.8, 1.8, 1.8, 3187399258, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Lugercane", "Lugercane", "G", "Godly", 95356090, 4535479829, 1.8, 1.8, 1.8, 4535482609, 0, -0.5, 0.5, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ocean_G", "Ocean", "G", "Godly", 13928587755, 90484783616182, 0.0787, 0.0431, 0.0468, 13933165014, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "Phaser", "Phaser", "G", "Classic", 69486593, 69486519, 0.8, 0.8, 0.8, 144325423, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Plasmabeam", "Plasmabeam", "G", "Godly", 9702755186, 10015208201, 0.0424, 0.0463, 0.0439, 10014717343, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "Shark", "Shark · Shark", "G", "Godly", 118269783, 203858007, 0.3, 0.43, 0.4, 3187421705, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "SharkChroma", "Shark · SharkChroma", "G", "Godly", 118269783, 3171214838, 0.44, 0.44, 0.44, 3187421856, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "Chick_K_2025", "Chick", "K", "Common", 121944778, 116056287470892, 1, 1, 1, 116361515042274, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SwirlyGunChroma", "Swirly Gun · SwirlyGunChroma", "G", "Godly", 8310911339, 8293539377, 1, 1, 1, 8311453396, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "TravelerGunChroma", "Traveler's Gun", "G", "Godly", 15090814396, 132537117087610, 0.0499, 0.0499, 0.0499, 15097920149, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "VampireAxe_Gold", "Vampire's Axe · VampireAxe_Gold", "K", "Unique", 92263601594064, 132843202397207, 0.0725, 0.0725, 0.0725, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "VampireGunChroma", "Vampire's Gun · VampireGunChroma", "G", "Godly", 126591885289479, 104946799389637, 0.05, 0.05, 0.05, 0, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "WatergunChroma", "Watergun", "G", "Godly", 18280999342, 129036269962882, 0.0395, 0.0395, 0.0395, 18351465514, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "AuroraGun", "Borealis", "G", "Godly", 16070198638, 107873598804292, 0.0469, 0.0469, 0.0469, 108635848059846, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "SwirlyAxeBronze", "Bronze Swirly", "K", "Unique", 8293463844, 82459482426756, 0.0579, 0.0579, 0.0579, 9552050165, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SwirlyGunBlue", "Blue Swirly", "G", "Unique", 8310911339, 104958144059634, 1, 1, 1, 9552060741, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "FlowerwoodGun", "Flowerwood Gun", "G", "Godly", 16895099893, 16895448237, 0.0519, 0.0519, 0.0519, 0, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "Decorated_K_2025", "Decorated", "K", "Uncommon", 121944778, 136070215876929, 1, 1, 1, 124860763249593, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Hallowgun", "Hallowgun", "G", "Godly", 5841866437, 5841868338, 0.0408, 0.0408, 0.0408, 5877089721, -0.6954, -0.2885, -0.036, -0.0467, 0.056, -0.9973, 0, 0.9984, 0.056, 0.9989, 0.0026, -0.0466 },
        	{ "IceHammer_Godly", "Icecrusher (Godly)", "K", "Godly", 11855737283, 11855737599, 0.07, 0.07, 0.07, 11855282546, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Icebeam", "Icebeam", "G", "Godly", 8310908064, 8231066536, 1, 1, 1.0002, 8305000161, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "SwirlyAxeGold", "Gold Swirly", "K", "Unique", 8293463844, 76537714037540, 0.0579, 0.0579, 0.0579, 9552054920, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Turtle_K_2024", "Turtle", "K", "Uncommon", 6600901997, 127394910308086, 1, 1, 1, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Jinglegun", "Jinglegun", "G", "Godly", 6125843704, 6125843755, 1, 1, 1, 6121678262, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Makeshift", "Makeshift", "G", "Godly", 11158364935, 11274360089, 0.0546, 0.0546, 0.0546, 11229837140, -0.0028, -0.4133, 0.7372, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "Celestial", "Celestial", "K", "Ancient", 109711282082830, 117556526686597, 0.0533, 0.0533, 0.0533, 136673966529736, 0, 0.0018, 0.2811, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Pearl_G", "Pearlshine", "G", "Godly", 18280804203, 136668364239627, 0.0431, 0.0431, 0.0431, 0, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "Rainbow_G", "Rainbow Gun", "G", "Godly", 12921221200, 12921231088, 0.0519, 0.0519, 0.0519, 12966354606, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "Spectre2022", "Spectre", "G", "Godly", 11165536294, 11165715120, 0.052, 0.052, 0.052, 11229779932, -0.0011, -0.5, 0.6295, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "Stickers_X_G_2024", "Stickers 2024 · Stickers_X_G_2024", "G", "Common", 6600918074, 139997450438464, 0.0384, 0.0388, 0.0369, 91224254479440, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "SwirlyGun", "Swirly Gun · SwirlyGun", "G", "Godly", 8310911339, 97363489382281, 1, 1, 1, 8305002569, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "VampireAxe_Purple", "Vampire's Axe · VampireAxe_Purple", "K", "Unique", 92263601594064, 125726996015099, 0.0725, 0.0725, 0.0725, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "VampireGun", "Vampire's Gun · VampireGun", "G", "Godly", 126591885289479, 105399657891158, 0.0483, 0.0483, 0.0483, 0, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "WraithGun", "Soul", "G", "Godly", 79527507796407, 80102752403085, 0.0444, 0.0444, 0.0444, 0, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "Infected", "Infected", "K", "Common", 121944778, 6978645136, 1, 1, 1, 200953094, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Forest_G_2024", "Forest", "G", "Uncommon", 79401392, 114741314080418, 1.6, 1.6, 1.6, 78199422065424, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Patrick", "Patrick", "K", "Common", 121944778, 7837986943, 1, 1, 1, 383476085, 0, -0.9885, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Dartbringer", "Dartbringer", "G", "Unique", 6689725889, 6689727175, 0.4426, 0.4258, 0.4258, 8626617523, 0.0352, -0.3793, 0.465, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SlouseClown", "Clown", "K", "Unique", 121944778, 197196512, 1, 1, 1, 315501118, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cane_G_2021", "Cane 2021", "G", "Common", 79401392, 8275031710, 1.5, 1.5, 1.5, 8304768700, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "SharkSeeker", "SharkSeeker", "G", "Unique", 6967743598, 6689657395, 0.75, 0.75, 0.75, 6967771328, 0.1, -0.1, -0.5, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Iceblaster", "Iceblaster", "G", "Godly", 6125828567, 6120563948, 1, 1, 1, 6121579464, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "TravelerAxe", "Traveler's Axe", "K", "Ancient", 15057341638, 15057460725, 0.0681, 0.0681, 0.0681, 15070870271, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Hallow", "Hallow's Edge", "K", "Godly", 179155055, 179155105, 0.57, 0.57, 0.57, 531878205, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "RaygunSilver", "Silver Raygun", "G", "Unique", 115447220952926, 133327506424645, 0.0471, 0.0471, 0.0471, 71511736314707, 0.0009, -0.554, 0.7423, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "AmericaSword", "Old Glory", "K", "Godly", 262027449, 445805934, 0.6, 0.6, 0.6, 446047742, 0, 0.25, 1.9, 1, 0, 0, 0, 0.0767, 0.9971, 0, -0.9971, 0.0767 },
        	{ "VampireAxe_Bronze", "Vampire's Axe · VampireAxe_Bronze", "K", "Unique", 92263601594064, 117917193798694, 0.0725, 0.0725, 0.0725, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Tree", "Tree", "K", "Legendary", 121944778, 5838589224, 1, 1, 1, 331745577, 0, -1.0285, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Tree_K_2023", "Tree 2023", "K", "Rare", 957726558, 121944805, 1, 1, 1, 15635563249, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowy", "Snowy", "K", "Uncommon", 121944778, 5538538671, 1, 1, 1, 332011125, 0, -0.9885, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "EliteGreen", "Green Elite", "K", "Legendary", 121944778, 137946316996767, 1, 1, 1, 332754554, 0, -1.0285, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Apoc_K_2022", "Apocalypse", "K", "Common", 121944778, 11218500706, 1, 1, 1, 11254172968, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Alex", "Alex", "K", "Common", 121944778, 545604317, 1, 1, 1, 546159020, 0, -0.9885, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Combat2", "Combat II", "K", "Common", 121944778, 6932358967, 1, 1, 1, 4972196241, 0.0416, -1.1409, 0.0773, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BronzeVampiresEdge", "Bronze Vamp's Edge", "K", "Unique", 5841895234, 124129066234254, 0.067, 0.067, 0.067, 12253493272, 0, -1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BlueVampiresEdge", "Blue Vamp's Edge", "K", "Unique", 5841895234, 116887066557099, 0.067, 0.067, 0.067, 12253491988, 0, -1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "GoldVampiresEdge", "Gold Vamp's Edge", "K", "Unique", 5841895234, 89466623295527, 0.067, 0.067, 0.067, 12253496571, 0, -1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SilverVampiresEdge", "Silver Vamp's Edge", "K", "Unique", 5841895234, 93427229045342, 0.067, 0.067, 0.067, 12253494893, 0, -1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Flora", "Flora", "G", "Godly", 108253816085047, 116621225933096, 0.0457, 0.0457, 0.0457, 139276091458016, 0, -0.5, 0.5, 0.9999, -0.0087, -0.0087, 0.0087, 1, 0, 0.0087, -0.0001, 1 },
        	{ "Bloom", "Bloom", "K", "Godly", 73266355643345, 103489229144925, 0.079, 0.079, 0.079, 132419834610569, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bunnies_K_2025", "Bunnies", "K", "Legendary", 121944778, 104875261384354, 1, 1, 1, 90549252812333, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Carrots_K_2025", "Carrots", "K", "Common", 121944778, 137285542474252, 1, 1, 1, 76914260444878, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Potion", "Potion", "K", "Uncommon", 121944778, 1782402938, 1, 1, 1, 1133366632, 0, -0.9885, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Reaver_Legendary", "Reaver (Legendary)", "K", "Legendary", 121944778, 121291446597917, 1, 1, 1, 7791485669, 0, -1.0087, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Igloo_G_2024", "Igloo", "G", "Common", 79401392, 73071132008000, 1.6, 1.6, 1.6, 95517099886712, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Reaver", "Reaver (Rare)", "K", "Rare", 121944778, 118176521118205, 1, 1, 1, 7791484774, 0, -1.0087, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "IceHammer_Legendary", "Icecrusher (Legendary)", "K", "Legendary", 957726558, 11851776706, 1, 1, 1, 11855361567, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Icebreaker", "Icebreaker", "K", "Ancient", 6124173614, 6124173821, 0.9685, 0.9685, 0.9685, 6121572723, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "VampireAxe", "Vampire's Axe (Ancient)", "K", "Ancient", 92263601594064, 73008954478338, 0.0725, 0.0725, 0.0725, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SwirlyGunGold", "Gold Swirly", "G", "Unique", 8310911339, 122072784662988, 1, 1, 1, 9552065167, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Minty", "Minty", "G", "Godly", 4528424409, 4528424475, 1.119, 1.119, 1.119, 4528291487, -0.0211, 0.2222, 0.772, -0.9998, 0, -0.0211, 0.0016, -0.9972, -0.075, -0.021, -0.075, 0.997 },
        	{ "BlueHarvester", "Blue Harvester", "G", "Unique", 7775027413, 8266618476, 0.06, 0.05, 0.05, 8194219645, 0, -0.54, 0.4558, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ElderwoodGun", "Elderwood Revolver", "G", "Godly", 4210029922, 4210038158, 0.0298, 0.0298, 0.0298, 4468571736, -0.5676, -0.1243, -0.0424, -0.0003, 0.023, -0.9997, -0.0117, 0.9997, 0.023, 0.9999, 0.0117, 0 },
        	{ "Candy", "Candy", "K", "Godly", 19040337, 19040326, 1.1, 1.4, 1.1, 332021011, 0, 0.866, -0.006, 0, 0, 1, 0, -1, 0, 1, 0, 0 },
        	{ "ElderwoodGunSilver", "Silver Elderwood", "G", "Unique", 4210029922, 5357372620, 0.0407, 0.0456, 0.0406, 4468583758, -0.6706, -0.1995, -0.0658, 0.0161, 0.0001, -0.9999, 0.0208, 0.9998, 0.0005, 0.9997, -0.0208, 0.0161 },
        	{ "ElderwoodKnifeBlue", "Blue Elderwood", "K", "Unique", 11238166013, 14741388867, 0.07, 0.07, 0.07, 11505913287, 0, -1.347, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SilverHallow", "Silver Hallow", "K", "Unique", 179155055, 104150976879041, 0.5, 0.5, 0.5, 2511341094, 0, -1.3549, 0.0348, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SilverIceblaster", "Silver Iceblaster", "G", "Unique", 6125828567, 6246950589, 1, 1, 1, 6404166698, -0.0085, -0.7, -0.546, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "SilverIcebreaker", "Silver Icebreaker", "K", "Unique", 6124173614, 6237992602, 1, 1, 1, 6404126280, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SilverHarvester", "Silver Harvester", "G", "Unique", 7775027413, 8266615645, 0.06, 0.05, 0.05, 8194217388, 0, -0.51, 0.4458, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BlueSugar", "Blue Sugar", "G", "Unique", 101086719, 3241860913, 0.6, 0.6, 0.6, 3215355152, -0.1, 0.5361, 1.0789, -1, 0, 0, 0, -1, 0, 0, 0, 1 },
        	{ "LogchopperSilver", "Silver Logchopper", "K", "Unique", 4535643726, 9346155546, 1, 1, 1, 4753352581, -0.0051, -0.7237, 0.328, 0.9962, -0.0316, -0.0816, 0.0342, 0.9989, 0.031, 0.0806, -0.0336, 0.9962 },
        	{ "MintySilver", "Silver Minty", "G", "Unique", 5216810177, 4753313914, 1.15, 1.15, 1.15, 4753346087, 0.0545, -0.2787, 0.5806, 0.9959, -0.0334, 0.0839, 0.0337, 0.9994, -0.0026, -0.0838, 0.0054, 0.9965 },
        	{ "SilverCandy", "Silver Candy", "K", "Unique", 19040337, 97784569465604, 1, 1.3333, 1, 1520190188, 0, 0.866, -0.006, 0, 0, 1, 0, -1, 0, 1, 0, 0 },
        	{ "ElderwoodGunBlue", "Blue Elderwood", "G", "Unique", 4210029922, 5827160585, 0.0407, 0.0456, 0.0406, 4468574885, -0.6706, -0.1995, -0.0658, 0.0161, 0.0001, -0.9999, 0.0208, 0.9998, 0.0005, 0.9997, -0.0208, 0.0161 },
        	{ "ElderwoodGunBronze", "Bronze Elderwood", "G", "Unique", 4210029922, 5355144249, 0.0407, 0.0456, 0.0406, 4468585407, -0.6706, -0.1995, -0.0658, 0.0161, 0.0001, -0.9999, 0.0208, 0.9998, 0.0005, 0.9997, -0.0208, 0.0161 },
        	{ "ElderwoodGunGold", "Gold Elderwood", "G", "Unique", 4210029922, 126940459873407, 0.0407, 0.0456, 0.0406, 4468584345, -0.6706, -0.1995, -0.0658, 0.0161, 0.0001, -0.9999, 0.0208, 0.9998, 0.0005, 0.9997, -0.0208, 0.0161 },
        	{ "ElderwoodKnifeBronze", "Bronze Elderwood", "K", "Unique", 11238166013, 14741383535, 0.07, 0.07, 0.07, 11505914752, 0, -1.347, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ElderwoodKnifeGold", "Gold Elderwood", "K", "Unique", 11238166013, 14741358103, 0.07, 0.07, 0.07, 11505917850, 0, -1.347, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "ElderwoodKnifeSilver", "Silver Elderwood", "K", "Unique", 11238166013, 14741374486, 0.07, 0.07, 0.07, 11505916486, 0, -1.3468, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BronzeHallow", "Bronze Hallow", "K", "Unique", 179155055, 2518167440, 0.5, 0.5, 0.5, 2511342846, 0, -1.3549, 0.0348, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "GoldHallow", "Gold Hallow", "K", "Unique", 179155055, 110453608575133, 0.5, 0.5, 0.5, 2511340308, 0, -1.3549, 0.0348, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "RedHallow", "Red Hallow", "K", "Unique", 179155055, 73958132414440, 0.5, 0.5, 0.5, 2511343130, 0, -1.3549, 0.0348, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "RaygunBronze", "Bronze Raygun", "G", "Unique", 115447220952926, 122251377901095, 0.0471, 0.0471, 0.0471, 138881346504998, 0.0009, -0.554, 0.7423, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "RaygunRed", "Red Raygun", "G", "Unique", 115447220952926, 104160895526874, 0.0471, 0.0471, 0.0471, 132354489228618, 0.0009, -0.554, 0.7423, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BronzeIceblaster", "Bronze Iceblaster", "G", "Unique", 6125828567, 6246948951, 1, 1, 1, 6404167442, -0.0085, -0.7, -0.546, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "GoldIceblaster", "Gold Iceblaster", "G", "Unique", 6125828567, 6246949956, 1, 1, 1, 6404165933, -0.0085, -0.7, -0.546, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "RedIceblaster", "Red Iceblaster", "G", "Unique", 6125828567, 6246951385, 1, 1, 1, 6404168049, -0.0085, -0.7, -0.546, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "BronzeIcebreaker", "Bronze Icebreaker", "K", "Unique", 6124173614, 6237991982, 1, 1, 1, 6404127119, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "GoldIcebreaker", "Gold Icebreaker", "K", "Unique", 6124173614, 6237993632, 1, 1, 1, 6404115112, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "RedIcebreaker", "Red Icebreaker", "K", "Unique", 6124173614, 6237994207, 1, 1, 1, 6404129111, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BronzeHarvester", "Bronze Harvester", "G", "Unique", 7775027413, 8266617019, 0.06, 0.05, 0.05, 8194221072, 0, -0.52, 0.4158, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "GoldHarvester", "Gold Harvester", "G", "Unique", 7775027413, 8266613473, 0.06, 0.05, 0.05, 8194222523, 0, -0.52, 0.4258, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Harvester", "Harvester", "G", "Ancient", 7775027413, 7775245551, 0.06, 0.05, 0.05, 7800847534, 0, -0.5366, 0.4983, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SilverSugar", "Silver Sugar", "G", "Unique", 101086719, 80417567706028, 0.6, 0.6, 0.6, 3215355602, -0.1, 0.5361, 1.0789, -1, 0, 0, 0, -1, 0, 0, 0, 1 },
        	{ "GoldSugar", "Gold Sugar", "G", "Unique", 101086719, 77907977694388, 0.6, 0.6, 0.6, 3215355797, -0.1, 0.5361, 1.0789, -1, 0, 0, 0, -1, 0, 0, 0, 1 },
        	{ "BronzeSugar", "Bronze Sugar", "G", "Unique", 101086719, 6958436959, 0.6, 0.6, 0.6, 3215355397, -0.1, 0.5361, 1.0789, -1, 0, 0, 0, -1, 0, 0, 0, 1 },
        	{ "LogchopperBlue", "Blue Logchopper", "K", "Unique", 4535643726, 4753303501, 1, 1, 1, 4753353471, 0, -0.9536, 0.3372, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "LogchopperBronze", "Bronze Logchopper", "K", "Unique", 4535643726, 7572081485, 0.96, 0.96, 0.96, 4753354123, 0, -0.9536, 0.3372, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "LogchopperGold", "Gold Logchopper", "K", "Unique", 4535643726, 108331174915822, 0.96, 0.96, 0.96, 4753354638, 0, -0.9536, 0.3372, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "MintyBronze", "Bronze Minty", "G", "Unique", 5216810177, 5211061190, 1.15, 1.15, 1.15, 4753348263, 0.0545, -0.2787, 0.5806, 0.9959, -0.0334, 0.0839, 0.0337, 0.9994, -0.0026, -0.0838, 0.0054, 0.9965 },
        	{ "BlueCandy", "Blue Candy", "K", "Unique", 19040337, 3241832047, 1, 1.3333, 1, 1489495701, 0, 0.866, -0.006, 0, 0, 1, 0, -1, 0, 1, 0, 0 },
        	{ "BronzeCandy", "Bronze Candy", "K", "Unique", 19040337, 122687610829006, 1, 1.3333, 1, 1520189487, 0, 0.866, -0.006, 0, 0, 1, 0, -1, 0, 1, 0, 0 },
        	{ "GoldCandy", "Gold Candy", "K", "Unique", 19040337, 2885942815, 1, 1.3333, 1, 1520188792, 0, 0.866, -0.006, 0, 0, 1, 0, -1, 0, 1, 0, 0 },
        	{ "Celestial_Silver", "Silver Celestial", "K", "Unique", 109711282082830, 119629165572031, 0.0533, 0.0533, 0.0533, 90241292303974, 0, 0.002, 0.281, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Constellation_Silver", "Silver Constellation", "G", "Unique", 124598402927958, 88000474566609, 0.1007, 0.1007, 0.1007, 100747436297625, 0, -0.27, 0.727, 1, 0, 0, 0, 0.9999, 0.0125, 0, -0.0125, 0.9999 },
        	{ "IcepiercerRed", "Red Icepiercer", "G", "Unique", 11868991644, 12196203001, 0.0548, 0.0548, 0.0548, 12227133450, 0, -0.66, 0.234, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscythe_Blue", "Blue Gingerscythe", "K", "Unique", 15397282571, 125204450826311, 0.0696, 0.0696, 0.0697, 0, 0, -0.94, -0.063, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "TravelerAxeSilver", "Silver Traveler's", "K", "Unique", 15057341638, 125312600693078, 0.0681, 0.0681, 0.0681, 15695407742, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "VampireAxe_Silver", "Vampire's Axe · VampireAxe_Silver", "K", "Unique", 92263601594064, 78665201678229, 0.0725, 0.0725, 0.0725, 0, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Celestial_Bronze", "Bronze Celestial", "K", "Unique", 109711282082830, 118098317574486, 0.0533, 0.0533, 0.0533, 119399643874968, 0, 0.002, 0.281, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Celestial_Gold", "Gold Celestial", "K", "Unique", 109711282082830, 74186573010586, 0.0533, 0.0533, 0.0533, 104229967982042, 0, 0.002, 0.281, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Celestial_Red", "Red Celestial", "K", "Unique", 109711282082830, 91261836086535, 0.0533, 0.0533, 0.0533, 119157529694972, 0, 0.002, 0.281, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Constellation_Bronze", "Bronze Constellation", "G", "Unique", 124598402927958, 84518828644661, 0.1007, 0.1007, 0.1007, 112811587103866, 0, -0.27, 0.727, 1, 0, 0, 0, 0.9999, 0.0125, 0, -0.0125, 0.9999 },
        	{ "Constellation_Gold", "Gold Constellation", "G", "Unique", 124598402927958, 129541547610095, 0.1007, 0.1007, 0.1007, 132975248521820, 0, -0.27, 0.727, 1, 0, 0, 0, 0.9999, 0.0125, 0, -0.0125, 0.9999 },
        	{ "Constellation_Red", "Red Constellation", "G", "Unique", 124598402927958, 97613309386908, 0.1007, 0.1007, 0.1007, 85766514163212, 0, -0.27, 0.727, 1, 0, 0, 0, 0.9999, 0.0125, 0, -0.0125, 0.9999 },
        	{ "Icepiercer", "Icepiercer", "G", "Ancient", 11868991644, 11869075814, 0.0548, 0.0548, 0.0548, 11874071041, 0, -0.5819, 0.0324, 1, 0, 0, 0, 0.9978, -0.0658, 0, 0.0658, 0.9978 },
        	{ "IcepiercerBronze", "Bronze Icepiercer", "G", "Unique", 11868991644, 136041212037383, 0.0548, 0.0548, 0.0548, 12226920195, 0, -0.66, 0.234, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "IcepiercerGold", "Gold Icepiercer", "G", "Unique", 11868991644, 89221956008018, 0.0548, 0.0548, 0.0548, 12226688172, 0, -0.66, 0.234, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "IceHammerGold", "Gold Icecrusher", "K", "Unique", 11848711686, 132842079563749, 0.0736, 0.0736, 0.0736, 12227137860, 0, -0.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscythe_Bronze", "Bronze Gingerscythe", "K", "Unique", 15397282571, 88640690300238, 0.0696, 0.0696, 0.0697, 0, 0, -0.94, -0.063, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "IceHammerBronze", "Bronze Icecrusher", "K", "Unique", 11848711686, 88591542566831, 0.0736, 0.0736, 0.0736, 12227148356, 0, -0.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "TravelerAxeBronze", "Bronze Traveler's", "K", "Unique", 15057341638, 87152090639814, 0.0681, 0.0681, 0.0681, 15695407020, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "TravelerAxeGold", "Gold Traveler's", "K", "Unique", 15057341638, 107837737026552, 0.0681, 0.0681, 0.0681, 15695408631, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "TreeGun2023", "Evergun", "G", "Godly", 15408863676, 83856783954564, 0.023, 0.023, 0.023, 15694357721, 0.0363, -0.4269, 0.9423, 0.9995, 0, 0.0305, 0, 1, 0, -0.0305, 0, 0.9995 },
        	{ "TreeKnife2023", "Evergreen", "K", "Godly", 15408280573, 125133515152716, 0.0046, 0.0046, 0.0046, 15694357137, 0.0502, -1.7515, -0.0305, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscope", "Gingerscope", "G", "Ancient", 15374602183, 15409041564, 0.0842, 0.0842, 0.0842, 15666596216, 0, -0.4, 0.9, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscope_Blue", "Blue Gingerscope", "G", "Unique", 15374602183, 100142423147247, 0.0842, 0.0842, 0.0842, 0, 0, -0.42, 0.97, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscope_Bronze", "Bronze Gingerscope", "G", "Unique", 15374602183, 93684911189915, 0.0842, 0.0842, 0.0842, 0, 0, -0.42, 0.97, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscope_Gold", "Gold Gingerscope", "G", "Unique", 15374602183, 75888854860786, 0.0842, 0.0842, 0.0842, 0, 0, -0.42, 0.97, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscope_Silver", "Silver Gingerscope", "G", "Unique", 15374602183, 129527194826480, 0.0842, 0.0842, 0.0842, 0, 0, -0.42, 0.97, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SunsetGun", "Sunrise", "G", "Godly", 109742397574153, 71731808219690, 0.0458, 0.0458, 0.0458, 129480661108374, 0, -0.1086, 0.6442, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SunsetKnife", "Sunset", "K", "Godly", 137082284051764, 93782017269677, 0.074, 0.074, 0.074, 103526268515240, 0, -1.3352, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Synthwave", "Synthwave (Rare)", "K", "Rare", 6600901997, 139525295603551, 1, 1, 1, 84935740002917, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Synthwave_Ancient", "Synthwave (Ancient)", "K", "Ancient", 81344146777937, 84281380230931, 0.0741, 0.0741, 0.0741, 133828016595037, 0.0228, -0.64, 0.2496, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Synthwave_Godly", "Synthwave (Godly)", "K", "Godly", 132672824913652, 81048398253986, 0.0741, 0.0741, 0.0741, 116075729415230, -0.0142, -1.06, 0.0292, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Synthwave_Legendary", "Synthwave (Legendary)", "K", "Legendary", 6600901997, 115419740311345, 1, 1, 1, 132040985617451, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "IceHammerRed", "Red Icecrusher", "K", "Unique", 11848711686, 71714696554176, 0.0736, 0.0736, 0.0736, 12227186408, 0, -0.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "IceHammerSilver", "Silver Icecrusher", "K", "Unique", 11848711686, 108890976731643, 0.0736, 0.0736, 0.0736, 12227142478, 0, -0.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscythe_Gold", "Gold Gingerscythe", "K", "Unique", 15397282571, 87952488946515, 0.0696, 0.0696, 0.0697, 0, 0, -1.1001, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerscythe_Silver", "Silver Gingerscythe", "K", "Unique", 15397282571, 110584978259893, 0.0696, 0.0696, 0.0697, 0, 0, -1.1001, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Raygun", "Raygun", "G", "Godly", 115447220952926, 127881437685243, 0.0471, 0.0471, 0.0471, 139431943195380, 0.0009, -0.554, 0.7423, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "UFOs_K_2025", "UFOs", "K", "Common", 6600901997, 101182606016909, 1, 1, 1, 97641024072972, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Xeno_K_2025", "Xeno", "K", "Rare", 6600901997, 101379516858862, 1, 1, 1, 80492487454400, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "HauntedHouse_K_2025", "Haunted 2025", "K", "Common", 6600901997, 96264372471629, 1, 1, 1, 90194465176219, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "PumpkinPatch_K_2025", "Pumpkin 2025", "K", "Uncommon", 6600901997, 92052630861897, 1, 1, 1, 119626042140839, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Bats_K_2025", "Cats", "K", "Common", 6600901997, 116130292497156, 1, 1, 1, 140366567839959, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Energized_G_2025", "Energized", "G", "Legendary", 79401392, 96975375477860, 1.6, 1.6, 1.6, 114403390530326, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Hologram_G_2025", "Hologram", "G", "Rare", 79401392, 130121703557220, 1.6, 1.6, 1.6, 108751717527377, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Treats_G_2025", "Treats", "G", "Uncommon", 79401392, 121735248301175, 1.6, 1.6, 1.6, 76537883908961, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "CandyCorn_G_2025", "Candy Corn 2025", "G", "Common", 79401392, 88054952272755, 1.6, 1.6, 1.6, 129781304866793, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Eyes_G_2025", "Eyes", "G", "Uncommon", 79401392, 81682248459741, 1.6, 1.6, 1.6, 90751163516480, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Abduction_K_2025", "Abduction", "K", "Uncommon", 6600901997, 125213231050513, 1, 1, 1, 107510647616718, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Treats_K_2025", "Treats", "K", "Uncommon", 6600901997, 117148660034316, 1, 1, 1, 115298865715727, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "StickersH_K_2025", "Stickers 2025 · StickersH_K_2025", "K", "Common", 6600901997, 91672438499477, 1, 1, 1, 100461386281007, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "CandyCorn_K_2025", "Candy Corn 2025", "K", "Common", 6600901997, 84607607123689, 1, 1, 1, 86405207895194, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Hologram_K_2025", "Hologram", "K", "Rare", 6600901997, 139678078674313, 1, 1, 1, 77773918675860, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Energized_K_2025", "Energized", "K", "Legendary", 6600901997, 104379655242590, 1, 1, 1, 86258299490709, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "UFOs_G_2025", "UFOs", "G", "Common", 79401392, 81729797666928, 1.6, 1.6, 1.6, 84030107970606, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Fall_G_2025", "Fall", "G", "Common", 79401392, 72560612536240, 1.6, 1.6, 1.6, 78153346812503, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Xeno_G_2025", "Xeno", "G", "Rare", 79401392, 88277879999522, 1.6, 1.6, 1.6, 139755862211442, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "HeartWand", "Heart Wand · HeartWand", "K", "Godly", 77738838473091, 76246633927299, 0.0782, 0.0782, 0.0782, 118334707962654, 0, -0.8, 0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "RaygunGold", "Gold Raygun", "G", "Unique", 115447220952926, 128241054560504, 0.0471, 0.0471, 0.0471, 76250851065456, 0.0009, -0.554, 0.7423, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Treat", "Treat", "G", "Godly", 135790480817772, 86649236464456, 0.0538, 0.0538, 0.0538, 131626924640663, 0, 0, 0.6, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "XenoGun", "Xenoshot", "G", "Godly", 96867436912658, 103568875118220, 0.0534, 0.0534, 0.0534, 96859273002742, 0.0253, -0.0153, 0.8973, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "XenoKnife", "Xenoknife", "K", "Godly", 136619680236977, 113651973865393, 0.0784, 0.0784, 0.0784, 115021756767182, 0, -1.2953, 0.0848, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "StickersT2025", "Stickers 2025 · StickersT2025", "K", "Common", 6600901997, 113144896198208, 1, 1, 1, 115280072896190, -0.0224, -1.0551, 0.0453, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BaubleKnife", "Ornament (Godly)", "K", "Godly", 116508096109443, 135843404105980, 0.0731, 0.0731, 0.0731, 111092946728824, 0, -1.15, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Blizzard", "Blizzard · Blizzard", "G", "Godly", 77235373292363, 131115493735176, 0.043, 0.043, 0.043, 88928894807422, 0, -0.57, 0.75, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "BlizzardChroma", "Blizzard · BlizzardChroma", "G", "Godly", 77235373292363, 97280881789656, 0.0433, 0.0433, 0.0433, 139495852635932, 0, -0.32, 0.34, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Frozen_G_2025", "Frozen 2025", "G", "Legendary", 79401392, 87079980851460, 1.5, 1.5, 1.5, 90622014285727, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Frozen_K_2025", "Frozen 2025", "K", "Legendary", 6600901997, 103391577880162, 1, 1, 1, 108996627787763, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingerbread_G_2025", "Gingerbread 2025", "G", "Uncommon", 79401392, 77398327971959, 1.5, 1.5, 1.5, 74908113882525, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Gingerbread_K_2025", "Gingerbread 2025", "K", "Uncommon", 6600901997, 86777384953188, 1, 1, 1, 134478959354477, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Gingercookie_G_2025", "Gingercookie", "G", "Rare", 79401392, 112196863510306, 1.5, 1.5, 1.5, 99160839686845, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Gingercookie_K_2025", "Gingercookie", "K", "Rare", 6600901997, 77551638357810, 1, 1, 1, 111408683823094, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Lights_G_2025", "Lights 2025", "G", "Common", 79401392, 80557940854587, 1.5, 1.5, 1.5, 104258636970738, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Lights_K_2025", "Lights 2025", "K", "Common", 6600901997, 71217678785248, 1, 1, 1, 71228862432065, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Ornaments_K_2025", "Ornaments 2025", "K", "Uncommon", 6600901997, 128273296066714, 1, 1, 1, 132504094164819, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Peppermint_G_2025", "Peppermint", "G", "Common", 79401392, 107986046289088, 1.5, 1.5, 1.5, 73148873488539, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Peppermint_K_2025", "Peppermint 2025", "K", "Common", 6600901997, 120181028268113, 1, 1, 1, 84605926178412, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SnowDagger", "Snow Dagger", "K", "Godly", 140633396635861, 77812964601215, 0.0598, 0.0598, 0.0598, 95328449981238, 0, -1.15, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowball_G_2025", "Snowball", "G", "Common", 79401392, 81738515769034, 1.5, 1.5, 1.5, 104416405402940, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Snowcannon", "Snowcannon", "G", "Godly", 99836890880541, 122392330922281, 0.05, 0.05, 0.05, 129186939023729, 0, -0.32, 0.34, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Snowstorm", "Snowstorm · Snowstorm", "K", "Godly", 127534150487935, 84853425379784, 0.077, 0.077, 0.077, 70973050894155, 0, -1.26, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SnowstormChroma", "Snowstorm · SnowstormChroma", "K", "Godly", 86944837615327, 86253759560362, 0.077, 0.077, 0.077, 94202294092932, 0, -1.18, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Spearmint_G_2025", "Spearmint", "G", "Rare", 79401392, 125101257679057, 1.5, 1.5, 1.5, 81352860339620, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Spearmint_K_2025", "Spearmint", "K", "Rare", 6600901997, 73372556711687, 1, 1, 1, 98506456649552, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "StickersX_G_2025", "Stickers 2025", "G", "Common", 79401392, 123572826899313, 1.5, 1.5, 1.5, 127489830827583, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "StickersX_K_2025", "Stickers 2025 · StickersX_K_2025", "K", "Common", 6600901997, 130231206599976, 1, 1, 1, 102283625659356, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sweater_G_2025", "Sweater 2025", "G", "Uncommon", 79401392, 83785504897240, 1.5, 1.5, 1.5, 118557229750245, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Sweater_K_2025", "Sweater 2025", "K", "Uncommon", 6600901997, 134310239127931, 1, 1, 1, 102130993592804, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Penguin_K_2025", "Penguin", "K", "Common", 6600901997, 72734484939175, 1, 1, 1, 93320180084418, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "SweetChroma", "Sweet · SweetChroma", "K", "Godly", 88250692342609, 120707737118924, 0.0691, 0.0691, 0.0691, 90923771881248, 0, -1, 0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Cupid_K_2026", "Cupid", "K", "Legendary", 121944778, 91124699102770, 1, 1, 1, 123955324398353, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Heartbreak_G_2026", "Heartbreak", "G", "Rare", 79401392, 102957418708034, 1.6, 1.6, 1.6, 79235438948261, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Paws_G_2026", "Paws", "G", "Uncommon", 79401392, 108504597564281, 1.6, 1.6, 1.6, 120089556380493, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Blossom_K_2026", "Blossom 2026", "K", "Uncommon", 121944778, 139596499078847, 1, 1, 1, 110160120309916, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Strawberries_G_2026", "Strawberries", "G", "Common", 79401392, 103202994163470, 1.6, 1.6, 1.6, 128646835922561, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Hearts_K_2026", "Hearts 2026", "K", "Common", 121944778, 112048035793774, 1, 1, 1, 99939659856909, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Plaid_G_2026", "Plaid", "G", "Common", 79401392, 100185145262613, 1.6, 1.6, 1.6, 121681210724670, 0, -0.7, -0.3, 1, 0, 0, 0, 0, -1, 0, 1, 0 },
        	{ "Starry_K_2026", "Starry 2026", "K", "Uncommon", 121944778, 98911990727243, 1, 1, 1, 130537925107449, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Strawberries_K_2026", "Strawberries", "K", "Common", 121944778, 75968382870233, 1, 1, 1, 73897192147749, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sweet_K_2026", "Yummy", "K", "Rare", 121944778, 139481558107907, 1, 1, 1, 113677688954146, 0, -1, -0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "HeartWandChroma", "Heart Wand · HeartWandChroma", "K", "Godly", 77738838473091, 78842905206144, 0.0782, 0.0782, 0.0782, 99154743764163, 0, -0.8, 0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        	{ "Sweet", "Sweet · Sweet", "K", "Godly", 88250692342609, 75844398224824, 0.0691, 0.0691, 0.0691, 126937716954396, 0, -1, 0.1, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        }
        local rarityOrder = {
        	Ancient = 1,
        	Godly = 2,
        	Unique = 3,
        	Legendary = 4,
        	Vintage = 5,
        	Classic = 6,
        	Rare = 7,
        	Uncommon = 8,
        	Common = 9,
        }
        local skins = {}
        local skinsByKey = {}
        for _, e in ipairs(skinRows) do
        	local s = {
        		key = e[1],
        		name = e[2],
        		type = e[3] == "K" and "Knife" or "Gun",
        		rarity = e[4],
        		mesh = "rbxassetid://" .. e[5],
        		tex = e[6] ~= 0 and "rbxassetid://" .. e[6] or "",
        		scale = { e[7], e[8], e[9] },
        		img = e[10],
        		src = "tool",
        		from = e[4],
        		grip = e[11] and CFrame.new(e[11], e[12], e[13], e[14], e[15], e[16], e[17], e[18], e[19], e[20], e[21], e[22]) or nil,
        	}
        	table.insert(skins, s)
        	skinsByKey[s.key] = s
        end
        table.sort(skins, function(a, b)
        	local ra, rb = rarityOrder[a.rarity] or 10, rarityOrder[b.rarity] or 10
        	if ra ~= rb then
        		return ra < rb
        	end
        	return a.name < b.name
        end)
        local applied = {}
        local function restore(part)
        	local a = applied[part]
        	if not a then
        		return
        	end
        	pcall(function()
        		if a.mesh and a.orig then
        			a.mesh.MeshId = a.orig.MeshId
        			a.mesh.TextureId = a.orig.TextureId
        			a.mesh.Scale = a.orig.Scale
        		end
        		if a.origColor then
        			part.Color = a.origColor
        			part.Material = a.origMat
        		end
        		if a.overlay then
        			a.overlay:Destroy()
        		end
        		part.LocalTransparencyModifier = 0
        	end)
        	for _, f in ipairs(a.fx) do
        		f:Destroy()
        	end
        	applied[part] = nil
        end
        local function restoreAll()
        	for part in pairs(applied) do
        		restore(part)
        	end
        end
        local function makeTrailAtts(handle)
        	local s = handle.Size
        	local axis = s.X >= s.Y and s.X >= s.Z and Vector3.xAxis or (s.Y >= s.Z and Vector3.yAxis or Vector3.zAxis)
        	local len = (s * axis).Magnitude / 2
        	local a0 = create("Attachment", { Name = "RockHubTrail0", Position = axis * len * 0.9, Parent = handle })
        	local a1 = create("Attachment", { Name = "RockHubTrail1", Position = -axis * len * 0.2, Parent = handle })
        	return a0, a1
        end
        local function applyFx(a, handle)
        	for _, f in ipairs(a.fx) do
        		f:Destroy()
        	end
        	a.fx = {}
        	local col = accentColor
        	if skinCfg.glow then
        		table.insert(a.fx, create("PointLight", {
        			Name = "RockHubGlow",
        			Color = col,
        			Brightness = skinCfg.light / 25,
        			Range = 9,
        			Shadows = false,
        			Parent = handle,
        		}))
        	end
        	if skinCfg.sparkles then
        		table.insert(a.fx, create("ParticleEmitter", {
        			Name = "RockHubSparkles",
        			Texture = "rbxasset://textures/particles/sparkles_main.dds",
        			LightEmission = 1,
        			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) }),
        			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
        			Lifetime = NumberRange.new(0.4, 0.8),
        			Rate = 14,
        			Speed = NumberRange.new(0.5, 1.5),
        			SpreadAngle = Vector2.new(180, 180),
        			Parent = handle,
        		}))
        	end
        	if skinCfg.trail then
        		local a0, a1 = makeTrailAtts(handle)
        		table.insert(a.fx, a0)
        		table.insert(a.fx, a1)
        		table.insert(a.fx, create("Trail", {
        			Name = "RockHubTrail",
        			Attachment0 = a0,
        			Attachment1 = a1,
        			LightEmission = 1,
        			Lifetime = 0.22,
        			MinLength = 0.05,
        			FaceCamera = true,
        			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
        			WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
        			Parent = handle,
        		}))
        	end
        end
        local refScale = { tool = nil, display = nil }
        local K = 1
        local function updateK()
        	if refScale.tool and refScale.display and refScale.display > 0 then
        		K = refScale.tool / refScale.display
        		setConfig("Skin Changer/K", K)
        	end
        end
        register("Skin Changer/K", function(v)
        	if type(v) == "number" and v > 0 then
        		K = v
        	end
        end, function()
        	return K
        end, 1)
        local function scaleMag(part)
        	if part:IsA("MeshPart") then
        		local meshSize = part.MeshSize
        		return meshSize.Magnitude > 0 and (part.Size / meshSize).Magnitude or nil
        	end
        	local specialMesh = part:FindFirstChildOfClass("SpecialMesh")
        	return specialMesh and specialMesh.Scale.Magnitude or nil
        end
        local function calcScale(s, kind)
        	local v = Vector3.new(s.scale[1], s.scale[2], s.scale[3])
        	local origin = s.src or "display"
        	if kind == "tool" and origin == "display" then
        		v *= K
        	elseif kind == "display" and origin == "tool" then
        		v /= K
        	end
        	return v * (skinCfg.size / 100)
        end
        local function applySkin(part, weapon, isTool)
        	local kind = isTool and "tool" or "display"
        	if not applied[part] then
        		local e = scaleMag(part)
        		if e and e > 0 and refScale[kind] ~= e then
        			refScale[kind] = e
        			updateK()
        		end
        	end
        	local s = skinsByKey[skinCfg.sel[weapon]]
        	if not s then
        		restore(part)
        		return
        	end
        	local a = applied[part]
        	if a and a.key == s.key and a.size == skinCfg.size then
        		if a.mesh and not a.overlay and a.mesh.MeshId ~= s.mesh then
        			a.key = nil
        		else
        			if a.overlay then
        				part.LocalTransparencyModifier = 1
        			end
        			return
        		end
        	end
        	if not a then
        		a = { fx = {}, origColor = part.Color, origMat = part.Material }
        		local specialMesh = part:FindFirstChildOfClass("SpecialMesh")
        		if specialMesh and not part:IsA("MeshPart") then
        			a.mesh = specialMesh
        			a.orig = { MeshId = specialMesh.MeshId, TextureId = specialMesh.TextureId, Scale = specialMesh.Scale }
        		end
        		applied[part] = a
        	end
        	a.key, a.size = s.key, skinCfg.size
        	if a.mesh and not (kind == "tool" and s.grip) then
        		if a.overlay then
        			a.overlay:Destroy()
        			a.overlay = nil
        			part.LocalTransparencyModifier = 0
        		end
        		a.mesh.MeshId = s.mesh
        		a.mesh.TextureId = s.tex
        		a.mesh.Scale = calcScale(s, kind)
        		if s.color then
        			part.Color = Color3.new(s.color[1], s.color[2], s.color[3])
        			pcall(function()
        				part.Material = Enum.Material[s.mat]
        			end)
        		end
        	else
        		if a.overlay then
        			a.overlay:Destroy()
        		end
        		if a.mesh and a.orig then
        			a.mesh.MeshId = a.orig.MeshId
        			a.mesh.TextureId = a.orig.TextureId
        			a.mesh.Scale = a.orig.Scale
        		end
        		local offset = CFrame.identity
        		local tool = part.Parent
        		if kind == "tool" and s.grip and tool and tool:IsA("Tool") then
        			offset = tool.Grip * s.grip:Inverse()
        		end
        		local p = create("Part", {
        			Name = "RockHubSkin",
        			Size = Vector3.one * 0.2,
        			Transparency = 0,
        			CanCollide = false,
        			CanTouch = false,
        			CanQuery = false,
        			Massless = true,
        			Anchored = false,
        			CFrame = part.CFrame * offset,
        			Parent = part,
        		})
        		create("SpecialMesh", {
        			MeshType = Enum.MeshType.FileMesh,
        			MeshId = s.mesh,
        			TextureId = s.tex,
        			Scale = calcScale(s, kind),
        			Parent = p,
        		})
        		if s.color then
        			p.Color = Color3.new(s.color[1], s.color[2], s.color[3])
        			pcall(function()
        				p.Material = Enum.Material[s.mat]
        			end)
        		end
        		create("WeldConstraint", { Part0 = part, Part1 = p, Parent = p })
        		a.overlay = p
        		part.LocalTransparencyModifier = 1
        	end
        	if isTool then
        		applyFx(a, part)
        	end
        end
        local function getHandles()
        	local list = {}
        	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
        		for _, tool in ipairs(container and container:GetChildren() or {}) do
        			if tool:IsA("Tool") and (tool.Name == "Knife" or tool.Name == "Gun") then
        				local h = tool:FindFirstChild("Handle")
        				if h and h:IsA("BasePart") then
        					table.insert(list, { h, tool.Name, true })
        				end
        			end
        		end
        	end
        	return list
        end
        local function invalidate()
        	for _, a in pairs(applied) do
        		a.key = nil
        	end
        end
        local lastScan = 0
        connect(RunService.Heartbeat, function()
        	local now = os.clock()
        	if skinCfg.enabled and now - lastScan > 0.5 then
        		lastScan = now
        		for _, t in ipairs(getHandles()) do
        			pcall(applySkin, t[1], t[2], t[3])
        		end
        		for part in pairs(applied) do
        			if not part:IsDescendantOf(game) then
        				applied[part] = nil
        			elseif not (part.Parent and part.Parent:IsA("Tool")) then
        				restore(part)
        			end
        		end
        	end
        end)
        local function labelOf(s) return s.name .. "  [" .. s.rarity .. "]" end
        local opts = { Knife = { "Default" }, Gun = { "Default" } }
        local byLabel2 = { Knife = {}, Gun = {} }
        for _, s in ipairs(skins) do
            local l = labelOf(s)
            if byLabel2[s.type][l] then l = l .. " (" .. s.key .. ")" end
            byLabel2[s.type][l] = s
            table.insert(opts[s.type], l)
        end
        local function pick(weapon)
            return function(v)
                local s = byLabel2[weapon][v]
                skinCfg.sel[weapon] = s and s.key or nil
                invalidate()
                lastScan = 0
            end
        end
        local function fxChange(key)
            return function(v)
                skinCfg[key] = v
                invalidate()
                lastScan = 0
            end
        end
        local kSec = addSection(Tabs.Visuals, "Skin Changer")
        local en = kSec:Toggle("Skin Changer", "only you see the skins", function(on)
            skinCfg.enabled = on
            if on then
                invalidate()
                lastScan = 0
            else
                restoreAll()
            end
        end)
        en.Set(true, true)
        kSec:Select("Knife Skin", "knives", opts.Knife, "Default", pick("Knife"))
        kSec:Select("Gun Skin", "guns", opts.Gun, "Default", pick("Gun"))
        local fSec = addSection(Tabs.Visuals, "Skin Effects")
        fSec:Slider("Size", 50, 200, skinCfg.size, fxChange("size"), function(v) return v .. "%" end)
        fSec:Toggle("Glow", nil, fxChange("glow"))
        fSec:Slider("Glow Light", 0, 100, skinCfg.light, fxChange("light"))
        fSec:Toggle("Sparkles", nil, fxChange("sparkles"))
        fSec:Toggle("Trail", nil, fxChange("trail"))
        stopSkinChanger = restoreAll
    end)
    runBlock("MODELS", function()
        local function svc(name)
            local s = game:GetService(name)
            return cloneref and cloneref(s) or s
        end
        local InsertService = svc("InsertService")

        local modelFolder = workspace:FindFirstChild("KirpichModels")
        if modelFolder then modelFolder:Destroy() end
        modelFolder = Instance.new("Folder")
        modelFolder.Name = "KirpichModels"
        modelFolder.Parent = workspace

        local slots = {
            { id = 138151705692565, name = "Model 1" },
            { id = 117318033999248, name = "Model 2" },
        }
        for _, s in ipairs(slots) do
            s.enabled = false
            s.auto = true
            s.scale = 1
            s.offY = 0
            s.rotY = 0
            s.hideBody = true
            s.hideTouched = false
            s.tok = 0
            s.busy = false
            s.again = false
        end

        local statusLabel
        local function setStatus(text)
            if statusLabel then pcall(statusLabel.SetText, text) end
        end

        local CLOTH = { Shirt = true, Pants = true, ShirtGraphic = true, BodyColors = true }

        local function fetchObjects(id)
            local errs = {}
            local ok, res = pcall(function()
                return game:GetObjects("rbxassetid://" .. id)
            end)
            if ok and res and #res > 0 then return res end
            table.insert(errs, ok and "GetObjects: empty" or ("GetObjects: " .. tostring(res)))
            local ok2, asset = pcall(function() return InsertService:LoadAsset(id) end)
            if ok2 and asset then return asset:GetChildren() end
            table.insert(errs, "LoadAsset: " .. tostring(asset))
            local ok3, res3 = pcall(function()
                return InsertService:LoadLocalAsset("rbxassetid://" .. id)
            end)
            if ok3 and res3 then return { res3 } end
            table.insert(errs, "LoadLocalAsset: " .. tostring(res3))
            return nil, table.concat(errs, " | ")
        end

        local function stripRoot(root)
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Animator")
                    or d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") then
                    pcall(function() d:Destroy() end)
                end
            end
        end

        local function loadTemplate(slot)
            if slot.loaded then return true end
            local objs, err = fetchObjects(slot.id)
            if not objs then return false, err end
            local root = Instance.new("Model")
            for _, o in ipairs(objs) do o.Parent = root end
            stripRoot(root)
            slot.acc, slot.cloth = {}, {}
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("Accoutrement") then
                    table.insert(slot.acc, d)
                elseif CLOTH[d.ClassName] then
                    table.insert(slot.cloth, d)
                end
            end
            for _, a in ipairs(slot.acc) do a.Parent = nil end
            for _, c in ipairs(slot.cloth) do c.Parent = nil end
            local hasPart = false
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("BasePart") then hasPart = true break end
            end
            if hasPart then slot.root = root end
            slot.loaded = true
            return true
        end

        local function charParts()
            local ch = player.Character
            if not ch then return nil end
            local hum = ch:FindFirstChildOfClass("Humanoid")
            local hrp = ch:FindFirstChild("HumanoidRootPart")
            if hum and hrp then return ch, hum, hrp end
            return nil
        end

        local function weld(p0, p1, c0)
            local w = Instance.new("Weld")
            w.Part0 = p0
            w.Part1 = p1
            w.C0 = c0
            w.Parent = p1
            return w
        end

        local function unwear(slot)
            local st = slot.state
            if not st then return end
            slot.state = nil
            if st.model then pcall(function() st.model:Destroy() end) end
            for _, a in ipairs(st.acc) do pcall(function() a:Destroy() end) end
            for _, c in ipairs(st.cloth) do pcall(function() c:Destroy() end) end
            for _, e in ipairs(st.swapped) do
                pcall(function()
                    if e.parent and e.parent.Parent then e.inst.Parent = e.parent end
                end)
            end
            for inst, tr in pairs(st.hidden) do
                pcall(function()
                    if inst.Parent then inst.Transparency = tr end
                end)
            end
        end

        local function buildModel(slot, ch, hrp, cbCF, cbSize)
            local m = slot.root:Clone()
            local _, bsize = m:GetBoundingBox()
            local k = slot.scale
            if slot.auto then
                k *= cbSize.Y / math.max(bsize.Y, 0.05)
            end
            k = math.clamp(k, 0.02, 200)
            pcall(function() m:ScaleTo(k) end)

            local parts = {}
            for _, d in ipairs(m:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.Anchored = false
                    d.CanCollide = false
                    d.CanTouch = false
                    d.CanQuery = false
                    d.Massless = true
                    table.insert(parts, d)
                end
            end
            if #parts == 0 then
                m:Destroy()
                return nil, false
            end

            local cf = {}
            for _, p in ipairs(parts) do cf[p] = p.CFrame end

            local mapTo, matched = {}, {}
            for _, p in ipairs(parts) do
                local mine = ch:FindFirstChild(p.Name)
                if mine and mine:IsA("BasePart") then
                    mapTo[p] = mine
                    table.insert(matched, p)
                end
            end

            local rig = #matched >= 4
            if rig then
                for _, p in ipairs(parts) do
                    local mine = mapTo[p]
                    if mine then
                        weld(mine, p, CFrame.new(0, slot.offY, 0))
                    else
                        local best, bd = nil, math.huge
                        for _, q in ipairs(matched) do
                            local d = (cf[p].Position - cf[q].Position).Magnitude
                            if d < bd then best, bd = q, d end
                        end
                        weld(best, p, cf[best]:ToObjectSpace(cf[p]))
                    end
                end
            else
                local bbcf, msize = m:GetBoundingBox()
                local main = m.PrimaryPart
                if not main or not main:IsDescendantOf(m) then
                    local bv = -1
                    for _, p in ipairs(parts) do
                        local v = p.Size.X * p.Size.Y * p.Size.Z
                        if v > bv then main, bv = p, v end
                    end
                end
                local feetY = cbCF.Position.Y - cbSize.Y / 2
                local baseOff = feetY + msize.Y / 2 - hrp.Position.Y
                local target = CFrame.new(0, baseOff + slot.offY, 0) * CFrame.Angles(0, math.rad(slot.rotY), 0)
                weld(hrp, main, target * bbcf:ToObjectSpace(cf[main]))
                for _, p in ipairs(parts) do
                    if p ~= main then
                        weld(main, p, cf[main]:ToObjectSpace(cf[p]))
                    end
                end
            end
            m.Name = slot.name
            return m, rig
        end

        local function hideBody(st, ch, hrp)
            for _, d in ipairs(ch:GetDescendants()) do
                if d ~= hrp and (d:IsA("BasePart") or d:IsA("Decal")) then
                    local acc = d:FindFirstAncestorWhichIsA("Accoutrement")
                    if not (acc and acc:GetAttribute("KirpichAcc")) and st.hidden[d] == nil then
                        st.hidden[d] = d.Transparency
                        d.Transparency = 1
                    end
                end
            end
        end

        local function wearOnce(slot)
            unwear(slot)
            local ch, hum, hrp = charParts()
            if not ch then
                setStatus("No character")
                return
            end
            setStatus("Loading " .. slot.name .. "...")
            local loaded, err = loadTemplate(slot)
            if not loaded then
                setStatus("Failed to load " .. slot.name .. " (" .. slot.id .. "): " .. tostring(err))
                return
            end
            ch, hum, hrp = charParts()
            if not ch or not slot.enabled then return end

            local cbCF, cbSize = ch:GetBoundingBox()
            local st = { acc = {}, cloth = {}, swapped = {}, hidden = {} }
            slot.state = st
            local modes = {}
            local rig = false

            if slot.root then
                local m, isRig = buildModel(slot, ch, hrp, cbCF, cbSize)
                if m then
                    m.Parent = modelFolder
                    st.model = m
                    rig = isRig
                    table.insert(modes, isRig and "on body" or "as model")
                end
            end

            for _, c in ipairs(slot.cloth) do
                local clone = c:Clone()
                local old = ch:FindFirstChildOfClass(c.ClassName)
                if old then
                    table.insert(st.swapped, { inst = old, parent = ch })
                    old.Parent = nil
                end
                clone.Parent = ch
                table.insert(st.cloth, clone)
            end
            if #st.cloth > 0 then table.insert(modes, "clothes") end

            for _, a in ipairs(slot.acc) do
                local clone = a:Clone()
                clone:SetAttribute("KirpichAcc", true)
                local ok = pcall(function() hum:AddAccessory(clone) end)
                if ok then table.insert(st.acc, clone) else clone:Destroy() end
            end
            if #st.acc > 0 then table.insert(modes, "accessories") end

            if not slot.hideTouched then
                slot.hideBody = rig
                if slot.setHide then slot.setHide(rig) end
            end
            if slot.hideBody and (rig or st.model) then
                hideBody(st, ch, hrp)
            end

            if #modes == 0 then
                setStatus(slot.name .. ": nothing found inside")
            else
                setStatus(slot.name .. " worn (" .. table.concat(modes, ", ") .. ")")
            end
        end

        local function wear(slot)
            if slot.busy then
                slot.again = true
                return
            end
            slot.busy = true
            repeat
                slot.again = false
                local ok, err = pcall(wearOnce, slot)
                if not ok then setStatus("Error: " .. tostring(err)) end
            until not slot.again
            slot.busy = false
        end

        local function schedule(slot)
            if not slot.enabled then return end
            slot.tok += 1
            local tok = slot.tok
            task.delay(0.2, function()
                if slot.tok == tok and slot.enabled then wear(slot) end
            end)
        end

        connect(player.CharacterRemoving, function()
            for _, s in ipairs(slots) do unwear(s) end
        end)
        connect(player.CharacterAdded, function()
            task.wait(1)
            for _, s in ipairs(slots) do
                if s.enabled then task.spawn(wear, s) end
            end
        end)

        local mSec = addSection(Tabs.Visuals, "Models")
        statusLabel = mSec:Label("Switch a model on")

        for _, slot in ipairs(slots) do
            pcall(function() mSec.box:AddDivider(slot.name) end)

            local wearT = mSec:Toggle("Wear " .. slot.name, "id " .. slot.id, function(v)
                slot.enabled = v
                if v then
                    task.spawn(wear, slot)
                else
                    slot.tok += 1
                    unwear(slot)
                    setStatus(slot.name .. " removed")
                end
            end)
            slot.setWear = function(v) wearT.Set(v, true) end

            local autoT = mSec:Toggle("Auto Size", "fit the model to your height", function(v)
                slot.auto = v
                schedule(slot)
            end)
            autoT.Set(true, true)

            mSec:Slider("Size", 10, 500, 100, function(v)
                slot.scale = v / 100
                schedule(slot)
            end, function(v) return string.format("%.2f", v / 100) end)

            mSec:Slider("Height", -40, 40, 0, function(v)
                slot.offY = v / 4
                schedule(slot)
            end, function(v) return string.format("%.2f", v / 4) end)

            local hideT = mSec:Toggle("Hide My Body", "hide your own body while worn", function(v)
                slot.hideBody = v
                slot.hideTouched = true
                schedule(slot)
            end)
            hideT.Set(true, true)
            slot.setHide = function(v) hideT.Set(v, true) end

            mSec:Button("Rotate 90", "turn the model by 90 degrees", function()
                slot.rotY = (slot.rotY + 90) % 360
                schedule(slot)
            end)
        end

        pcall(function() mSec.box:AddDivider("General") end)
        mSec:Button("Wear Both", "put on both models", function()
            for _, s in ipairs(slots) do
                s.enabled = true
                if s.setWear then s.setWear(true) end
                task.spawn(wear, s)
            end
        end)
        mSec:Button("Remove All", "take off everything", function()
            for _, s in ipairs(slots) do
                s.enabled = false
                s.tok += 1
                if s.setWear then s.setWear(false) end
                unwear(s)
            end
            setStatus("All removed")
        end)

        Library:OnUnload(function()
            for _, s in ipairs(slots) do
                s.enabled = false
                s.tok += 1
                unwear(s)
            end
            pcall(function() modelFolder:Destroy() end)
        end)
    end)
    Library:OnUnload(function()
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        for _, f in ipairs({ stopAura, stopSpin, stopAnims, stopCursor, stopSkinChanger }) do
            pcall(f)
        end
    end)
end
do
    local UserInputService = game:GetService("UserInputService")
    local Stats = game:GetService("Stats")
    local accentColor = Color3.fromRGB(255, 255, 255)
    local dimColor = Color3.fromRGB(120, 120, 120)
    local connections = {}
    local function connect(signal, fn)
        local c = signal:Connect(fn)
        table.insert(connections, c)
        return c
    end
    local function create(className, props)
        local inst = Instance.new(className)
        local parent = props.Parent
        props.Parent = nil
        for k, v in pairs(props) do inst[k] = v end
        inst.Parent = parent
        return inst
    end
    local function tween(inst, t, props, dir, style)
        local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
        tw:Play()
        return tw
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "KirpichOverlay"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 50
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    do
        local ok, res = pcall(function() return (gethui and gethui()) or game:GetService("CoreGui") end)
        gui.Parent = ok and res or player:WaitForChild("PlayerGui")
    end
    local charMods = Library.KirpichMods or { antiFling = false }
    local function disableAntiFling()
        if Library.KirpichDisableAntiFling then Library.KirpichDisableAntiFling() end
    end
    local function getHumanoid()
        local character = player.Character
        return character and character:FindFirstChildOfClass("Humanoid")
    end
    local function getPing()
        local ok, ping = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and type(ping) == "number" then
            return ping
        end
        ok, ping = pcall(function()
            return player:GetNetworkPing() * 2000
        end)
        return ok and ping or 0
    end
    local function findTool(p, name)
        local char, backpack = p and p.Character, p and p:FindFirstChildOfClass("Backpack")
        return char and char:FindFirstChild(name) or backpack and backpack:FindFirstChild(name)
    end
    local function alive(p)
        local char = p and p.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.Health > 0 then
            return hrp, hum, char
        end
    end
    local lobbyCache, lobbyCFrame, lobbyHalfSize, lobbyCacheAt
    local function inLobby(pos)
        local now = os.clock()
        if not lobbyCacheAt or now - lobbyCacheAt > 1 or not lobbyCache or not lobbyCache.Parent then
            lobbyCacheAt = now
            lobbyCache = workspace:FindFirstChild("Lobby") or workspace:FindFirstChild("RegularLobby")
            lobbyCFrame, lobbyHalfSize = nil, nil
            if lobbyCache then
                local ok, cf, size = pcall(lobbyCache.GetBoundingBox, lobbyCache)
                if ok then
                    lobbyCFrame = cf
                    lobbyHalfSize = size / 2 + Vector3.new(10, 30, 10)
                end
            end
        end
        if not lobbyCFrame then
            return false
        end
        local rel = lobbyCFrame:PointToObjectSpace(pos)
        return math.abs(rel.X) <= lobbyHalfSize.X and math.abs(rel.Y) <= lobbyHalfSize.Y and math.abs(rel.Z) <= lobbyHalfSize.Z
    end
    local desync = { real = nil, pause = 0, on = false }
    local function pauseDesync(root)
        if desync.real and root and root.Parent then
            root.CFrame = desync.real
        end
        desync.real = nil
        desync.pause += 1
    end
    local function resumeDesync()
        desync.pause = math.max(0, desync.pause - 1)
    end
    local playerFlingAction, playerKnifeKill, playerGunKill, killAllHook, playerHugAction, roleFlingSec
    local shootMurdererHook, flingRoleHook, grabGunHook
    local stopPlayersActions, stopRoleFling, stopVoteDupe
    local uid, flip = 0, {}
    local function nextId(prefix)
        uid += 1
        return "R_" .. prefix .. uid
    end
    local function addSection(tab, name, side)
        local icon = (getgenv().__KRP_ICONS or {})[name]
        local box
        if type(side) == "table" then
            box = side
        elseif side == "Left" then
            box = tab:AddLeftGroupbox(name, icon)
        elseif side == "Right" then
            box = tab:AddRightGroupbox(name, icon)
        else
            flip[tab] = not flip[tab]
            box = flip[tab] and tab:AddLeftGroupbox(name, icon) or tab:AddRightGroupbox(name, icon)
        end
        local S = { box = box }
        function S:Collapsible() return self end
        function S:Toggle(n, desc, cb)
            local id, mute = nextId("T"), false
            local t = box:AddToggle(id, {
                Text = getgenv().__KRP_TC(n), Tooltip = desc, Default = false,
                Callback = function(v) if not mute and cb then cb(v) end end,
            })
            return {
                Set = function(v, silent)
                    mute = silent and true or false
                    t:SetValue(v)
                    mute = false
                end,
                Get = function() return t.Value end,
            }
        end
        function S:Slider(n, min, max, default, cb, fmt)
            local id, mute = nextId("S"), false
            local s = box:AddSlider(id, {
                Text = getgenv().__KRP_TC(n), Default = default, Min = min, Max = max, Rounding = 0,
                FormatDisplayValue = fmt and function(_, v) return fmt(v) end or nil,
                Callback = function(v) if not mute and cb then cb(v) end end,
            })
            return {
                Set = function(v, silent)
                    mute = silent and true or false
                    s:SetValue(v)
                    mute = false
                end,
                Get = function() return s.Value end,
            }
        end
        local function dropdown(n, options, default, cb)
            local id, mute = nextId("D"), false
            local d = box:AddDropdown(id, {
                Text = getgenv().__KRP_TC(n), Values = options, Default = default, Searchable = #options > 12,
                Callback = function(v) if not mute and cb then cb(v) end end,
            })
            return {
                Set = function(v, silent)
                    mute = silent and true or false
                    d:SetValue(v)
                    mute = false
                end,
                SetValues = function(vals) d:SetValues(vals) end,
                Get = function() return d.Value end,
            }
        end
        function S:Select(n, desc, options, default, cb) return dropdown(n, options, default, cb) end
        function S:ColorPicker(n, desc, default, cb)
            local id, mute = nextId("C"), false
            box:AddLabel(getgenv().__KRP_TC(n)):AddColorPicker(id, {
                Default = default, Title = getgenv().__KRP_TC(n),
                Callback = function(c) if not mute and cb then cb(c) end end,
            })
            return {
                Set = function(c, silent)
                    mute = silent and true or false
                    Options[id]:SetValueRGB(c)
                    mute = false
                end,
                Get = function() return Options[id].Value end,
            }
        end
        function S:Segmented(n, options, default, cb) return dropdown(n, options, default, cb) end
        function S:Button(n, desc, cb)
            box:AddButton({ Text = getgenv().__KRP_TC(n), Tooltip = desc, Func = cb })
        end
        function S:Label(text)
            local l = box:AddLabel(getgenv().__KRP_TC(text), true, nextId("L"))
            return {
                SetText = function(t) pcall(function() l:SetText(t) end) end,
            }
        end
        return S
    end
    runBlock("hug", function()
		do
			local hugAnimIds = { 125491951751014, 90892690280238, 88712283515515, 99919046918338, 127717306748023 }
			local hugState = { on = false, target = nil }
			local track, menuSeq2, loadingAnim
			local function getHugAnimId()
				if menuSeq2 then
					return menuSeq2
				end
				for _, id in ipairs(hugAnimIds) do
					local ok, objs = pcall(function()
						return game:GetObjects("rbxassetid://" .. id)
					end)
					if ok and type(objs) == "table" then
						for _, o in ipairs(objs) do
							local list = o:GetDescendants()
							table.insert(list, 1, o)
							for _, a in ipairs(list) do
								if a:IsA("Animation") and a.AnimationId ~= "" then
									menuSeq2 = a.AnimationId
									return menuSeq2
								end
							end
						end
					end
				end
			end
			local function stopHugAnim()
				if track then
					pcall(function()
						track:Stop(0.25)
					end)
					track = nil
				end
			end
			local function playHugAnim()
				local hum = getHumanoid()
				if not hum or loadingAnim then
					return
				end
				loadingAnim = true
				task.spawn(function()
					local id = getHugAnimId()
					if id and hugState.on then
						stopHugAnim()
						local anim = Instance.new("Animation")
						anim.AnimationId = id
						local animator = hum:FindFirstChildOfClass("Animator") or hum
						local ok, tr = pcall(function()
							return animator:LoadAnimation(anim)
						end)
						if ok and tr then
							tr.Priority = Enum.AnimationPriority.Action4
							tr.Looped = true
							tr:Play(0.25)
							track = tr
						end
					end
					loadingAnim = false
				end)
			end
			local function stopHug()
				hugState.on = false
				hugState.target = nil
				stopHugAnim()
			end
			connect(RunService.Heartbeat, function()
				if not hugState.on then
					return
				end
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if not hrp then
					return
				end
				local th = alive(hugState.target)
				if not th then
					stopHug()
					return
				end
				local front = th.CFrame * CFrame.new(0, 0, -1.4)
				hrp.CFrame = CFrame.lookAt(front.Position, Vector3.new(th.Position.X, front.Position.Y, th.Position.Z))
				hrp.AssemblyLinearVelocity = Vector3.zero
				if not track then
					playHugAnim()
				end
			end)
			playerHugAction = function(target)
				if hugState.on and hugState.target == target then
					stopHug()
					return false
				end
				stopHugAnim()
				hugState.on = true
				hugState.target = target
				playHugAnim()
				return true
			end
			connect(Players.PlayerRemoving, function(leaving)
				if hugState.target == leaving then
					stopHug()
				end
			end)
			table.insert(connections, {
				Disconnect = function()
					stopHug()
				end,
			})
		end
    end)
    runBlock("auto grab gun", function()
		do
			local autoGrab = { on = false }
			local busy = false
			local lastDrop
			local gunHolders = {}
			local function has(name)
				return findTool(player, name)
			end
			local function dropPart(d)
				if d:IsA("BasePart") then
					return d
				end
				if d:IsA("Model") then
					return d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart", true)
				end
			end
			local function findGunDrop()
				if lastDrop and lastDrop.Parent then
					return lastDrop
				end
				local d = workspace:FindFirstChild("GunDrop", true)
				if d then
					local g = dropPart(d)
					if g then
						return g
					end
				end
			end
			local function touch(hrp, g)
				if firetouchinterest then
					firetouchinterest(hrp, g, 0)
					firetouchinterest(hrp, g, 1)
				end
			end
			local function getMurdererPos()
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player and findTool(p, "Knife") then
						local c = p.Character
						local h = c and c:FindFirstChild("HumanoidRootPart")
						if h then
							return h.Position
						end
					end
				end
			end
			local function grabGun(gun, manual, deathPos)
				if busy then
					return
				end
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum or hum.Health <= 0 then
					return
				end
				if not manual and inLobby(hrp.Position) then
					return
				end
				if has("Knife") then
					if manual then
					end
					return
				end
				if has("Gun") then
					return
				end
				gun = gun or findGunDrop()
				if not gun and not deathPos then
					if manual then
					end
					return
				end
				busy = true
				local gradStart2 = os.clock()
				local function exists(g)
					return g and g.Parent and g or nil
				end
				while not exists(gun) and os.clock() - gradStart2 < 1.5 do
					gun = exists(lastDrop)
					if gun then
						break
					end
					RunService.Heartbeat:Wait()
				end
				if not exists(gun) or not hrp.Parent or hum.Health <= 0 then
					busy = false
					return
				end
				if not manual then
					local tw = os.clock()
					while os.clock() - tw < 3 do
						local pos = getMurdererPos()
						if not pos or not exists(gun) or (pos - gun.Position).Magnitude > 8 then
							break
						end
						RunService.Heartbeat:Wait()
					end
					if not exists(gun) then
						busy = false
						return
					end
				end
				pauseDesync(hrp)
				local savedCF = hrp.CFrame
				local gotGun = false
				local target
				local function onChild(c)
					if c.Name ~= "Gun" or gotGun then
						return
					end
					gotGun = true
					target = nil
					if hrp.Parent and hum.Health > 0 then
						hrp.CFrame = savedCF
						hrp.AssemblyLinearVelocity = Vector3.zero
					end
				end
				local backpack = player:FindFirstChildOfClass("Backpack")
				local arrowL = backpack and backpack.ChildAdded:Connect(onChild)
				local arrowR = char.ChildAdded:Connect(onChild)
				local stepConn = RunService.Stepped:Connect(function()
					if target and hrp.Parent then
						hrp.CFrame = target
						hrp.AssemblyLinearVelocity = Vector3.zero
					end
				end)
				touch(hrp, gun)
				RunService.Heartbeat:Wait()
				if not gotGun and has("Gun") then
					gotGun = true
				end
				if not gotGun then
					local retryStart = os.clock()
					while not gotGun and os.clock() - retryStart < 0.35 do
						gun = exists(gun) or exists(lastDrop)
						if not gun or not hrp.Parent or hum.Health <= 0 then
							break
						end
						target = gun.CFrame
						hrp.CFrame = target
						hrp.AssemblyLinearVelocity = Vector3.zero
						touch(hrp, gun)
						RunService.Heartbeat:Wait()
						if not gotGun and has("Gun") then
							onChild({ Name = "Gun" })
						end
					end
				end
				stepConn:Disconnect()
				if arrowL then
					arrowL:Disconnect()
				end
				arrowR:Disconnect()
				target = nil
				if hrp.Parent and hum.Health > 0 then
					hrp.CFrame = savedCF
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
				busy = false
				resumeDesync()
				if gotGun then
				elseif manual then
				end
			end
			connect(workspace.DescendantAdded, function(d)
				if d.Name ~= "GunDrop" then
					return
				end
				local g = dropPart(d)
				if not g then
					return
				end
				lastDrop = g
				if autoGrab.on and not busy then
					task.spawn(grabGun, g)
				end
			end)
			connect(RunService.Heartbeat, function()
				if not autoGrab.on then
					if next(gunHolders) then
						table.clear(gunHolders)
					end
					return
				end
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player then
						local char = p.Character
						local hrp = char and char:FindFirstChild("HumanoidRootPart")
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						local alive = hrp and hum and hum.Health > 0
						if alive and findTool(p, "Gun") then
							gunHolders[p] = hrp.Position
						elseif gunHolders[p] then
							local pos = gunHolders[p]
							gunHolders[p] = nil
							if hum and hum.Health <= 0 and not busy then
								task.spawn(grabGun, nil, false, pos)
							end
						end
					end
				end
				for p in pairs(gunHolders) do
					if not p.Parent then
						gunHolders[p] = nil
					end
				end
			end)
			grabGunHook = grabGun
			local sec = addSection(Tabs.Main, "Auto Pickup Gun")
			sec:Toggle("Enable", "sheriff dies - you grab the gun instantly", function(on)
				autoGrab.on = on
				if on then
					task.spawn(grabGun)
				end
			end)
			sec:Button("Pickup Now", "take the dropped gun right now", function()
				grabGun(nil, true)
			end)
			if not firetouchinterest then
				sec:Button("No Firetouchinterest", "executor lacks it - grab relies on teleport only", function() end)
			end
		end
    end)
    runBlock("role fling", function()
		do
			local fling = { autoSheriff = false, busy = false, cancel = false, nextScan = 0, autoCharacter = nil, autoReadyAt = 0 }
			local flungCharacters = {}
			local roleCache, roleCacheAt = {}, 0
			local activeCleanup
			local ROLE_TTL = 2.5
			local function refreshRoles(force)
				if not force and os.clock() - roleCacheAt < 0.7 then
					return
				end
				roleCacheAt = os.clock()
				local remote = game:GetService("ReplicatedStorage"):FindFirstChild("GetPlayerData", true)
				if not (remote and remote:IsA("RemoteFunction")) then
					roleCache = {}
					return
				end
				local ok, data = pcall(remote.InvokeServer, remote)
				if not ok or type(data) ~= "table" then
					roleCache = {}
					return
				end
				roleCacheAt = os.clock()
				local nextRoles = {}
				for name, info in pairs(data) do
					if type(info) == "table" and type(info.Role) == "string" and not info.Dead and not info.Killed then
						nextRoles[name] = info.Role
					end
				end
				roleCache = nextRoles
			end
			local function hasRole(p, role)
				if role == "Murderer" and findTool(p, "Knife") then
					return true
				end
				if role == "Sheriff" and findTool(p, "Gun") then
					return true
				end
				if os.clock() - roleCacheAt > ROLE_TTL then
					return false
				end
				local value = roleCache[p.Name]
				return role == "Murderer" and value == "Murderer" or role == "Sheriff" and (value == "Sheriff" or value == "Hero")
			end
			local function findRole(role)
				refreshRoles()
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player and hasRole(p, role) then
						local char = p.Character
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						local root = char and char:FindFirstChild("HumanoidRootPart")
						if hum and hum.Health > 0 and root then
							return p
						end
					end
				end
			end
			local function resetRoles()
				roleCache, roleCacheAt = {}, 0
				fling.autoCharacter = nil
				fling.autoReadyAt = 0
				fling.nextScan = 0
			end
			local function watchRespawn(p)
				connect(p.CharacterAdded, function(c)
					roleCache[p.Name] = nil
					roleCacheAt = 0
					flungCharacters[c] = nil
					if p == player then
						resetRoles()
					end
				end)
			end
			for _, p in ipairs(Players:GetPlayers()) do
				watchRespawn(p)
			end
			connect(Players.PlayerAdded, watchRespawn)
			local wasLobby
			local function impact(pos, color)
				local ring = create("Part", {
					Name = "KirpichFlingImpact",
					Anchored = true,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					CastShadow = false,
					Material = Enum.Material.Neon,
					Color = color,
					Transparency = 0.15,
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.12, 1, 1),
					CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
					Parent = workspace,
				})
				tween(ring, 0.45, { Size = Vector3.new(0.12, 14, 14), Transparency = 1 }, Enum.EasingDirection.Out, Enum.EasingStyle.Quint)
				game:GetService("Debris"):AddItem(ring, 0.5)
			end
			local function flingPlayer(target, role, manual)
				if fling.busy then
					if manual then
					end
					return false
				end
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local targetChar = target and target.Character
				local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
				local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
				if not (root and hum and hum.Health > 0 and targetRoot and targetHum and targetHum.Health > 0) then
					if manual then
					end
					return false
				end
				if targetHum.Sit then
					if manual then
					end
					return false
				end
				fling.busy, fling.cancel = true, false
				local desyncWasActive = desync.on or desync.force
				if desyncWasActive then
					pauseDesync(root)
				end
				local savedPivot = char:GetPivot()
				local savedAutoRotate = hum.AutoRotate
				local savedFallenHeight = workspace.FallenPartsDestroyHeight
				local savedSeatedEnabled = hum:GetStateEnabled(Enum.HumanoidStateType.Seated)
				local fallenHeightDisabled = false
				local wasAntiFling = charMods.antiFling == true
				local color = role == "Sheriff" and Color3.fromRGB(70, 150, 255) or Color3.fromRGB(255, 70, 70)
				local highlight = create("Highlight", {
					Name = "KirpichFlingTarget",
					Adornee = targetChar,
					DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
					FillColor = color,
					FillTransparency = 0.65,
					OutlineColor = accentColor,
					OutlineTransparency = 0,
					Parent = targetChar,
				})
				local marker = create("BillboardGui", {
					Name = "KirpichFlingMarker",
					Adornee = targetRoot,
					AlwaysOnTop = true,
					Size = UDim2.fromOffset(150, 30),
					StudsOffset = Vector3.new(0, 3.5, 0),
					Parent = gui,
				})
				create("TextLabel", {
					Text = "FLINGING  ↓",
					Font = Enum.Font.GothamBlack,
					TextSize = 14,
					TextColor3 = color,
					TextStrokeColor3 = Color3.new(),
					TextStrokeTransparency = 0.25,
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					Parent = marker,
				})
				local bodyVelocity = create("BodyVelocity", {
					Velocity = Vector3.zero,
					MaxForce = Vector3.new(9e9, 9e9, 9e9),
					Parent = root,
				})
				local cleaned = false
				local function cleanup()
					if cleaned then
						return
					end
					cleaned = true
					for _, inst in ipairs({ bodyVelocity, highlight, marker }) do
						if inst and inst.Parent then
							inst:Destroy()
						end
					end
					pcall(hum.SetStateEnabled, hum, Enum.HumanoidStateType.Seated, savedSeatedEnabled)
					if player.Character == char and root.Parent and hum.Health > 0 then
						pcall(function()
							for _ = 1, 6 do
								char:PivotTo(savedPivot * CFrame.new(0, 0.5, 0))
								for _, part in ipairs(char:GetChildren()) do
									if part:IsA("BasePart") then
										part.AssemblyLinearVelocity = Vector3.zero
										part.AssemblyAngularVelocity = Vector3.zero
									end
								end
								if (root.Position - savedPivot.Position).Magnitude < 25 then
									break
								end
								RunService.Heartbeat:Wait()
							end
							hum.AutoRotate = savedAutoRotate
							hum:ChangeState(Enum.HumanoidStateType.GettingUp)
						end)
					end
					if fallenHeightDisabled then
						pcall(function()
							workspace.FallenPartsDestroyHeight = savedFallenHeight
						end)
					end
					if wasAntiFling then
						charMods.antiFling = true
					end
					if desyncWasActive then
						resumeDesync()
					end
					fling.busy = false
					activeCleanup = nil
				end
				activeCleanup = cleanup
				if wasAntiFling then
					disableAntiFling()
				end
				hum.AutoRotate = false
				fallenHeightDisabled = pcall(function()
					workspace.FallenPartsDestroyHeight = 0 / 0
				end)
				if not fallenHeightDisabled then
					cleanup()
					if manual then
					end
					return false
				end
				pcall(hum.SetStateEnabled, hum, Enum.HumanoidStateType.Seated, false)
				pcall(function()
					if sethiddenproperty then
						sethiddenproperty(player, "SimulationRadius", math.huge)
					end
				end)
				local started = os.clock()
				local lastPos = targetRoot.Position
				local launchOrigin = lastPos
				local launched = false
				local targetPart = targetRoot or targetChar:FindFirstChild("Head") or targetChar:FindFirstChildWhichIsA("BasePart")
				local function targetEscaped()
					if not targetPart.Parent then
						return false
					end
					lastPos = targetPart.Position
					local distance = (lastPos - launchOrigin).Magnitude
					local speed = targetPart.AssemblyLinearVelocity.Magnitude
					return lastPos.Y <= savedFallenHeight + 30 or distance > 350 or distance > 120 and speed > 200
				end
				local function flingPosition(pos, angle)
					local cf = CFrame.new(targetPart.Position) * pos * angle
					root.CFrame = cf
					char:PivotTo(cf)
					root.Velocity = Vector3.new(9e7, 9e8, 9e7)
					root.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
				end
				local ok, err = pcall(function()
					local angle = 0
					while os.clock() - started < 2 and not fling.cancel do
						if not (root.Parent and hum.Health > 0 and targetPart.Parent and targetHum.Health > 0) then
							break
						end
						if targetEscaped() then
							launched = true
							break
						end
						local speed = targetPart.AssemblyLinearVelocity.Magnitude
						angle += 100
						local steps
						if speed < 50 then
							local lead = targetHum.MoveDirection * speed / 1.25
							local rotation = CFrame.Angles(math.rad(angle), 0, 0)
							steps = {
								{ CFrame.new(0, 1.5, 0) + lead, rotation },
								{ CFrame.new(0, -1.5, 0) + lead, rotation },
								{ CFrame.new(0, 1.5, 0) + lead, rotation },
								{ CFrame.new(0, -1.5, 0) + lead, rotation },
								{ CFrame.new(0, 1.5, 0) + targetHum.MoveDirection, rotation },
								{ CFrame.new(0, -1.5, 0) + targetHum.MoveDirection, rotation },
							}
						else
							local flat, quarter = CFrame.new(), CFrame.Angles(math.rad(90), 0, 0)
							steps = {
								{ CFrame.new(0, 1.5, targetHum.WalkSpeed), quarter },
								{ CFrame.new(0, -1.5, -targetHum.WalkSpeed), flat },
								{ CFrame.new(0, 1.5, targetHum.WalkSpeed), quarter },
								{ CFrame.new(0, -1.5, 0), quarter },
								{ CFrame.new(0, -1.5, 0), flat },
								{ CFrame.new(0, -1.5, 0), quarter },
								{ CFrame.new(0, -1.5, 0), flat },
							}
						end
						for _, step in ipairs(steps) do
							flingPosition(step[1], step[2])
							task.wait()
							if fling.cancel or targetEscaped() then
								launched = not fling.cancel
								break
							end
						end
						if launched then
							break
						end
					end
				end)
				cleanup()
				if ok and launched and lastPos then
					impact(lastPos, color)
				end
				if manual then
					if ok and launched then
					elseif ok then
					end
				end
				return ok and launched
			end
			local function flingRole(role, manual)
				local target = findRole(role)
				if not target then
					if manual then
					end
					return false
				end
				return flingPlayer(target, role, manual), target
			end
			connect(RunService.Heartbeat, function()
				if not fling.autoSheriff or fling.busy or os.clock() < fling.nextScan then
					return
				end
				fling.nextScan = os.clock() + 0.8
				local myR = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if myR then
					local nowLobby = inLobby(myR.Position) and true or false
					if wasLobby ~= nil and wasLobby ~= nowLobby then
						table.clear(flungCharacters)
						resetRoles()
					end
					wasLobby = nowLobby
				end
				local target = findRole("Sheriff")
				local char = target and target.Character
				local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
				local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not char or not targetRoot or not myRoot or flungCharacters[char] or inLobby(targetRoot.Position) or inLobby(myRoot.Position) then
					fling.autoCharacter = nil
					fling.autoReadyAt = 0
					return
				end
				if fling.autoCharacter ~= char then
					fling.autoCharacter = char
					fling.autoReadyAt = os.clock() + 2.5
					return
				end
				if os.clock() < fling.autoReadyAt then
					return
				end
				refreshRoles(true)
				if target.Character ~= char or not hasRole(target, "Sheriff") then
					fling.autoCharacter = nil
					return
				end
				fling.autoReadyAt = os.clock() + 2.5
				task.spawn(function()
					if flingPlayer(target, "Sheriff", false) then
						flungCharacters[char] = true
					end
				end)
			end)
			connect(Players.PlayerRemoving, function(p)
				if p.Character then
					flungCharacters[p.Character] = nil
				end
			end)
			local sec = Sink
			roleFlingSec = sec
			sec:Toggle("Auto Fling Sheriff", "fling each sheriff down once per life", function(on)
				fling.autoSheriff = on
				fling.nextScan = 0
				fling.autoCharacter = nil
				fling.autoReadyAt = 0
				if not on then
					fling.cancel = true
				end
			end)
			sec:Button("Fling Sheriff", "fling the current sheriff down", function()
				flingRole("Sheriff", true)
			end)
			sec:Button("Fling Murderer", "fling the current murderer down", function()
				flingRole("Murderer", true)
			end)
			flingRoleHook = flingRole
			playerFlingAction = function(target)
				local role = hasRole(target, "Sheriff") and "Sheriff" or (hasRole(target, "Murderer") and "Murderer" or "Player")
				return flingPlayer(target, role, true)
			end
			stopRoleFling = function()
				fling.autoSheriff = false
				fling.cancel = true
				if activeCleanup then
					activeCleanup()
				end
			end
		end
    end)
    runBlock("murderer", function()
		do
			local autoKill = false
			local killing = false
			local cancelKill = false
			local lastAutoKill = 0
			local function getTargets(sheriffOnly, origin, includeLobby)
				local list = {}
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player then
						local hrp = alive(p)
						if hrp and (includeLobby or not inLobby(hrp.Position)) then
							local gun = findTool(p, "Gun") ~= nil
							if not sheriffOnly or gun then
								table.insert(list, { p = p, gun = gun, d = (hrp.Position - origin).Magnitude })
							end
						end
					end
				end
				table.sort(list, function(a, b)
					if a.gun ~= b.gun then
						return a.gun
					end
					return a.d < b.d
				end)
				return list
			end
			local function getKnife(hum)
				local char = player.Character
				local knife = char and char:FindFirstChild("Knife")
				if knife then
					return knife
				end
				local backpack = player:FindFirstChildOfClass("Backpack")
				knife = backpack and backpack:FindFirstChild("Knife")
				if knife then
					hum:EquipTool(knife)
					for _ = 1, 10 do
						if knife.Parent == char then
							break
						end
						RunService.Heartbeat:Wait()
					end
					return knife
				end
			end
			local function hit(knife, char)
				pcall(function()
					knife:Activate()
				end)
				local handle = knife:FindFirstChild("Handle")
				if handle and firetouchinterest then
					for _, n in ipairs({ "HumanoidRootPart", "UpperTorso", "Torso", "Head" }) do
						local part = char:FindFirstChild(n)
						if part then
							firetouchinterest(handle, part, 0)
							firetouchinterest(handle, part, 1)
						end
					end
				end
			end
			local function makeStandIn(char)
				local old = char.Archivable
				char.Archivable = true
				local ok, clone = pcall(function()
					return char:Clone()
				end)
				char.Archivable = old
				if not ok or not clone then
					return
				end
				for _, d in ipairs(clone:GetDescendants()) do
					if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
						d:Destroy()
					elseif d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CanQuery = false
						d.CanTouch = false
					elseif d:IsA("Humanoid") then
						d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					end
				end
				clone.Name = "KirpichStandIn"
				clone.Parent = workspace.CurrentCamera
				return clone
			end
			local function hideChar(char, on)
				for _, d in ipairs(char:GetDescendants()) do
					if d:IsA("BasePart") or d:IsA("Decal") then
						d.LocalTransparencyModifier = on and 1 or 0
					end
				end
			end
			local function killAll(sheriffOnly, silent, onlyList)
				if killing then
					return
				end
				local hrp, hum, char = alive(player)
				if not hrp then
					return
				end
				if not findTool(player, "Knife") then
					if not silent then
					end
					return
				end
				local list = getTargets(sheriffOnly, hrp.Position, onlyList ~= nil)
				if onlyList then
					local filtered = {}
					for _, e in ipairs(list) do
						if table.find(onlyList, e.p) then
							table.insert(filtered, e)
						end
					end
					list = filtered
				end
				if #list == 0 then
					if not silent then
					end
					return
				end
				killing, cancelKill = true, false
				pauseDesync(hrp)
				local savedCF = hrp.CFrame
				local gradStart2 = os.clock()
				local cam = workspace.CurrentCamera
				local oldCamType, camCF = cam.CameraType, cam.CFrame
				local standIn = makeStandIn(char)
				cam.CameraType = Enum.CameraType.Scriptable
				cam.CFrame = camCF
				local knife = getKnife(hum)
				local target
				local stepConn = RunService.Stepped:Connect(function()
					cam.CFrame = camCF
					if hrp.Parent then
						hideChar(char, true)
						if target then
							hrp.CFrame = target
							hrp.AssemblyLinearVelocity = Vector3.zero
						end
					end
				end)
				local left = #list
				while left > 0 and os.clock() - gradStart2 < 2 do
					if cancelKill or hum.Health <= 0 or not hrp.Parent then
						break
					end
					left = 0
					for _, e in ipairs(list) do
						local th, _, targetChar = alive(e.p)
						if th and not cancelKill then
							left += 1
							local behind = th.CFrame * CFrame.new(0, 0, 1.4)
							target = CFrame.lookAt(behind.Position, th.Position)
							hrp.CFrame = target
							hrp.AssemblyLinearVelocity = Vector3.zero
							knife = knife and knife.Parent and knife or getKnife(hum)
							if knife then
								hit(knife, targetChar)
							end
							RunService.Heartbeat:Wait()
							if knife then
								hit(knife, targetChar)
							end
						end
					end
				end
				target = nil
				stepConn:Disconnect()
				if hrp.Parent and hum.Health > 0 then
					hrp.CFrame = savedCF
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
				RunService.Heartbeat:Wait()
				if char.Parent then
					hideChar(char, false)
				end
				if standIn then
					standIn:Destroy()
				end
				cam.CameraType = oldCamType
				if hum.Parent then
					cam.CameraSubject = hum
				end
				local killed = 0
				for _, e in ipairs(list) do
					if not alive(e.p) then
						killed += 1
					end
				end
				killing = false
				resumeDesync()
				if not onlyList then
				end
			end
			playerKnifeKill = function(target)
				killAll(false, false, { target })
			end
			connect(RunService.Heartbeat, function()
				if not autoKill or killing or os.clock() - lastAutoKill < 2 then
					return
				end
				local hrp = alive(player)
				if not hrp or inLobby(hrp.Position) or not findTool(player, "Knife") then
					return
				end
				lastAutoKill = os.clock()
				task.spawn(killAll, false, true)
			end)
			local auraOn, auraRange = false, 12
			connect(RunService.Heartbeat, function()
				if not auraOn or killing then
					return
				end
				local hrp, hum, char = alive(player)
				if not hrp or inLobby(hrp.Position) or not findTool(player, "Knife") then
					return
				end
				local knife = getKnife(hum)
				if not knife then
					return
				end
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player then
						local th, _, tc = alive(p)
						if th and (th.Position - hrp.Position).Magnitude <= auraRange then
							hit(knife, tc)
						end
					end
				end
			end)
			killAllHook = function() killAll(false) end
			local sec = Sink
			pcall(function() sec.box:AddDivider() end)
			sec:Button("Kill All", "teleport to everyone and stab them", function()
				killAll(false)
			end)
			sec:Toggle("Kill Aura", "you have the knife - everyone close gets stabbed", function(on)
				auraOn = on
			end)
			sec:Slider("Kill Aura Range", 5, 40, auraRange, function(v)
				auraRange = v
			end, function(v)
				return v .. " studs"
			end)
			sec:Button("Kill Sheriff", "only the one with the gun", function()
				killAll(true)
			end)
			sec:Toggle("Auto Kill All", "you get the knife - everyone dies", function(on)
				autoKill = on
				lastAutoKill = 0
			end)
		end
    end)
    runBlock("silent aim", function()
		do
			local shotArgs, isBlocked
			local lastPos, desyncUntil = {}, {}
			connect(RunService.Heartbeat, function()
				local now = os.clock()
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player then
						local c = p.Character
						local h = c and c:FindFirstChild("HumanoidRootPart")
						if h then
							local prev = lastPos[p]
							local moved = prev and (h.Position - prev).Magnitude or 0
							if moved > 30 or h.AssemblyLinearVelocity.Magnitude > 150 then
								desyncUntil[p] = now + 1.5
							end
							lastPos[p] = h.Position
						else
							lastPos[p] = nil
						end
					end
				end
				for p in pairs(lastPos) do
					if not p.Parent then
						lastPos[p], desyncUntil[p] = nil, nil
					end
				end
			end)
			local function isDesyncing(p)
				return p and (desyncUntil[p] or 0) > os.clock()
			end
			local function expandHitbox(murdererRoot)
				if not murdererRoot or not murdererRoot.Parent then
					return function() end
				end
				local o = { size = murdererRoot.Size, transp = murdererRoot.Transparency, collide = murdererRoot.CanCollide }
				pcall(function()
					murdererRoot.CanCollide = false
					murdererRoot.Transparency = 1
					murdererRoot.Size = Vector3.one * 50
				end)
				local done = false
				return function()
					if done then
						return
					end
					done = true
					if murdererRoot.Parent then
						pcall(function()
							murdererRoot.Size = o.size
							murdererRoot.Transparency = o.transp
							murdererRoot.CanCollide = o.collide
						end)
					end
				end
			end
			local shotCfg = {
				wallbang = true,
				pred = 100,
				part = "Torso",
				quiet = true,
			}
			local busy = false
			local wallMisses = 0
			local aimParams = RaycastParams.new()
			aimParams.FilterType = Enum.RaycastFilterType.Exclude
			local peekOffsets = {
				Vector3.new(0, 0, 4),
				Vector3.new(0, 0, -4),
				Vector3.new(4, 0, 0),
				Vector3.new(-4, 0, 0),
				Vector3.new(0, 5, 3),
				Vector3.new(0, 2, 2),
			}
			local quietOffsets = {
				Vector3.new(0, 4, 0),
				Vector3.new(0, 7, 0),
				Vector3.new(3, 0, 0),
				Vector3.new(-3, 0, 0),
				Vector3.new(3, 4, 0),
				Vector3.new(-3, 4, 0),
				Vector3.new(0, 0, -3),
				Vector3.new(0, 10, 0),
			}
			local function findQuietSpot(murdererRoot, myChar)
				local root = myChar and myChar:FindFirstChild("HumanoidRootPart")
				if not root then
					return nil
				end
				aimParams.FilterDescendantsInstances = { myChar, murdererRoot.Parent, workspace.CurrentCamera }
				local facing = CFrame.lookAt(root.Position, Vector3.new(murdererRoot.Position.X, root.Position.Y, murdererRoot.Position.Z))
				for _, offset in ipairs(quietOffsets) do
					local pos = (facing * CFrame.new(offset)).Position
					if not isBlocked(root.Position, pos) and not isBlocked(pos, murdererRoot.Position) then
						return CFrame.lookAt(pos, murdererRoot.Position)
					end
				end
			end
			local function getMuzzle()
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				return hrp and hrp:FindFirstChild("GunRaycastAttachment")
			end
			local function muzzlePos(fallback)
				local a = getMuzzle()
				return a and a.WorldPosition or fallback
			end
			shotArgs = function(origin, aimPos, fromOrigin)
				local a = getMuzzle()
				local from = not fromOrigin and a and a.WorldCFrame or CFrame.lookAt(origin, aimPos)
				local dir = aimPos - from.Position
				if dir.Magnitude < 0.01 then
					dir = Vector3.new(0, 0, -1)
				end
				return from, CFrame.lookAt(aimPos, aimPos + dir.Unit)
			end
			isBlocked = function(a, b, extraIgnore)
				local list = { workspace.CurrentCamera }
				for _, x in ipairs(extraIgnore or {}) do
					table.insert(list, x)
				end
				for _, pl in ipairs(Players:GetPlayers()) do
					if pl.Character then
						table.insert(list, pl.Character)
					end
				end
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				for _ = 1, 8 do
					params.FilterDescendantsInstances = list
					local hit = workspace:Raycast(a, b - a, params)
					if not hit then
						return false
					end
					local pt = hit.Instance
					if pt.Transparency >= 0.9 or not pt.CanCollide then
						table.insert(list, pt)
					else
						return true
					end
				end
				return true
			end
			local function reportWallbang(hit)
				if hit then
					wallMisses = 0
					return
				end
				wallMisses = wallMisses + 1
				if wallMisses == 2 then
				end
			end
			local function getPeekCf(murdererRoot, myChar)
				if shotCfg.quiet then
					local s = findQuietSpot(murdererRoot, myChar)
					if s then
						return s
					end
				end
				aimParams.FilterDescendantsInstances = { myChar, murdererRoot.Parent, workspace.CurrentCamera }
				for _, offset in ipairs(peekOffsets) do
					local pos = (murdererRoot.CFrame * CFrame.new(offset)).Position
					if not isBlocked(pos, murdererRoot.Position) then
						return CFrame.lookAt(pos, murdererRoot.Position)
					end
				end
				local behind = murdererRoot.CFrame * CFrame.new(0, 0, 3)
				return CFrame.lookAt(behind.Position, murdererRoot.Position)
			end
			local function getMurderer()
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player and findTool(p, "Knife") then
						local char = p.Character
						local hrp = char and char:FindFirstChild("HumanoidRootPart")
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if hrp and hum and hum.Health > 0 then
							return p, hrp
						end
					end
				end
			end
			local function findGunRemote(gun)
				local knifeLocal = gun:FindFirstChild("KnifeLocal")
				local cb = knifeLocal and knifeLocal:FindFirstChild("CreateBeam")
				local remote = cb and cb:FindFirstChild("RemoteFunction")
				if remote then
					return remote, "beam"
				end
				for _, d in ipairs(gun:GetDescendants()) do
					if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and d.Name:lower():find("shoot") then
						return d, "shoot"
					end
				end
			end
			local function equipGun()
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not hum then
					return
				end
				local gun = char:FindFirstChild("Gun")
				if gun then
					return gun
				end
				local backpack = player:FindFirstChildOfClass("Backpack")
				gun = backpack and backpack:FindFirstChild("Gun")
				if not gun then
					return
				end
				hum:EquipTool(gun)
				for _ = 1, 10 do
					if gun.Parent == char then
						break
					end
					RunService.Heartbeat:Wait()
				end
				return gun
			end
			local function tpMakeStandIn(char)
				local old = char.Archivable
				char.Archivable = true
				local ok, clone = pcall(function()
					return char:Clone()
				end)
				char.Archivable = old
				if not ok or not clone then
					return
				end
				for _, d in ipairs(clone:GetDescendants()) do
					if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
						d:Destroy()
					elseif d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CanQuery = false
						d.CanTouch = false
					elseif d:IsA("Humanoid") then
						d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					end
				end
				clone.Name = "KirpichStandIn"
				clone.Parent = workspace.CurrentCamera
				return clone
			end
			local function tpHideChar(char, on)
				for _, d in ipairs(char:GetDescendants()) do
					if d:IsA("BasePart") or d:IsA("Decal") then
						d.LocalTransparencyModifier = on and 1 or 0
					end
				end
			end
			local tpActive = false
			local function beginPeekTp(murdererRoot)
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum or hum.Health <= 0 or not murdererRoot or not murdererRoot.Parent then
					return
				end
				local cam = workspace.CurrentCamera
				local savedCF, camCF, oldCamType = hrp.CFrame, cam.CFrame, cam.CameraType
				pauseDesync(hrp)
				local standIn = tpMakeStandIn(char)
				cam.CameraType = Enum.CameraType.Scriptable
				cam.CFrame = camCF
				tpHideChar(char, true)
				local peekCf = getPeekCf(murdererRoot, char)
				hrp.CFrame = peekCf
				hrp.AssemblyLinearVelocity = Vector3.zero
				local conn = RunService.Stepped:Connect(function()
					cam.CFrame = camCF
					if hrp.Parent then
						tpHideChar(char, true)
						hrp.CFrame = peekCf
						hrp.AssemblyLinearVelocity = Vector3.zero
					end
				end)
				local done = false
				local function restore()
					if done then
						return
					end
					done = true
					conn:Disconnect()
					if hrp.Parent and hum.Health > 0 then
						hrp.CFrame = savedCF
						hrp.AssemblyLinearVelocity = Vector3.zero
					end
					RunService.Heartbeat:Wait()
					if char.Parent then
						tpHideChar(char, false)
					end
					if standIn then
						standIn:Destroy()
					end
					cam.CameraType = oldCamType
					cam.CameraSubject = hum
					tpActive = false
					resumeDesync()
				end
				return peekCf, restore
			end
			local function shootMurderer(manual, useTp)
				if busy then
					return
				end
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum or hum.Health <= 0 then
					return
				end
				if not findTool(player, "Gun") then
					if manual then
					end
					return
				end
				local _, murdererRoot = getMurderer()
				if not murdererRoot then
					if manual then
					end
					return
				end
				local gun = equipGun()
				if not gun then
					return
				end
				local gunRemote, kind = findGunRemote(gun)
				local tr = os.clock()
				while not gunRemote and os.clock() - tr < 1 do
					RunService.Heartbeat:Wait()
					gunRemote, kind = findGunRemote(gun)
				end
				if not gunRemote then
					return
				end
				busy = true
				pauseDesync(hrp)
				local savedCF = hrp.CFrame
				local cam = workspace.CurrentCamera
				local oldCamType = cam.CameraType
				local wallbang = shotCfg.wallbang
				local pingMs = getPing() / 1000
				local murdererChar = murdererRoot.Parent
				local murderer = Players:GetPlayerFromCharacter(murdererChar)
				local desynced = isDesyncing(murderer)
				local function predictAim()
					if desynced then
						return murdererRoot.Position
					end
					local target = murdererRoot
					if shotCfg.part == "Head" then
						target = murdererChar:FindFirstChild("Head") or murdererRoot
					else
						target = murdererChar:FindFirstChild("UpperTorso") or murdererChar:FindFirstChild("Torso") or murdererRoot
					end
					local v = murdererRoot.AssemblyLinearVelocity
					local lead = shotCfg.pred / 1000
					return target.Position + Vector3.new(v.X, v.Y * 0.5, v.Z) * lead
				end
				local peekCf, holdConn
				local wbSpot
				wallbang = isBlocked(muzzlePos(gun:FindFirstChild("Handle") and gun.Handle.Position or hrp.Position), murdererRoot.Position)
				local teleporting = wallbang or useTp
				local camCF, standIn = cam.CFrame, nil
				if teleporting then
					standIn = tpMakeStandIn(char)
					cam.CameraType = Enum.CameraType.Scriptable
					cam.CFrame = camCF
					tpHideChar(char, true)
					peekCf = getPeekCf(murdererRoot, char)
					hrp.CFrame = peekCf
					hrp.AssemblyLinearVelocity = Vector3.zero
					holdConn = RunService.Stepped:Connect(function()
						cam.CFrame = camCF
						if peekCf and hrp.Parent then
							tpHideChar(char, true)
							if murdererRoot.Parent and not shotCfg.quiet then
								peekCf = getPeekCf(murdererRoot, char)
							end
							hrp.CFrame = peekCf
							hrp.AssemblyLinearVelocity = Vector3.zero
						end
					end)
				end
				local recentFake = os.clock() - (desync.lastFakeAt or 0) < 0.6
				if teleporting and not recentFake then
					RunService.Heartbeat:Wait()
				end
				if recentFake then
					local waitUntil = (desync.lastFakeAt or 0) + math.clamp(pingMs / 2, 0.02, 0.2) + 0.05
					while os.clock() < waitUntil do
						RunService.Heartbeat:Wait()
					end
				end
				local aimPos = predictAim()
				local handle = gun:FindFirstChild("Handle")
				local origin = wbSpot or (teleporting and peekCf and peekCf.Position) or (handle and handle.Position or hrp.Position)
				local murdererHum = murdererChar and murdererChar:FindFirstChildOfClass("Humanoid")
				if murdererHum then
					task.spawn(function()
						local t = os.clock()
						while os.clock() - t < 1.2 do
							if murdererHum.Health <= 0 or not murdererHum.Parent then
								if wbSpot then
									reportWallbang(true)
								end
								return
							end
							RunService.Heartbeat:Wait()
						end
						if wbSpot then
							reportWallbang(false)
						end
					end)
				end
				local restoreHitbox = expandHitbox(murdererRoot)
				task.delay(0.4, restoreHitbox)
				task.spawn(function()
					local ok, res = pcall(function()
						if kind == "beam" then
							return gunRemote:InvokeServer(1, aimPos, "AH2")
						elseif gunRemote:IsA("RemoteFunction") then
							return gunRemote:InvokeServer(shotArgs(origin, aimPos, wbSpot ~= nil or teleporting))
						else
							gunRemote:FireServer(shotArgs(origin, aimPos, wbSpot ~= nil or teleporting))
							return "(event, no reply)"
						end
					end)
					if not ok then
						warn("[Kirpich] shot failed: " .. tostring(res))
					end
				end)
				if teleporting then
					local t = os.clock()
					local holdTime = math.clamp(pingMs / 2 + 0.03333333333333333, 0.05, 0.18)
					repeat
						RunService.Heartbeat:Wait()
					until os.clock() - t >= holdTime
					holdConn:Disconnect()
					if hrp.Parent and hum.Health > 0 then
						hrp.CFrame = savedCF
						hrp.AssemblyLinearVelocity = Vector3.zero
					end
					RunService.Heartbeat:Wait()
					if char.Parent then
						tpHideChar(char, false)
					end
					if standIn then
						standIn:Destroy()
					end
					cam.CameraType = oldCamType
					cam.CameraSubject = hum
				end
				busy = false
				resumeDesync()
			end
			shootMurdererHook = shootMurderer
			playerGunKill = function(target)
				if not target or not findTool(target, "Knife") then
					return
				end
				shootMurderer(true)
			end
			local sec = addSection(Tabs.Target, "Silent Aim", "Left")
			do
				local rs = game:GetService("ReplicatedStorage")
				local players = game:GetService("Players")
				local collection = game:GetService("CollectionService")
				local run = game:GetService("RunService")
				local lp = players.LocalPlayer

				local stats = game:GetService("Stats")

				getgenv().SILENT_S = {
					enabled = false,
					predict = true,
					direct = true,
					force = true,
					auto_on = false,
					auto_delay = 0,
					am_sheriff = false,
					fire_gap = 0,
					last_shot = 0,
					stand_off = 15,
				}
				local S = getgenv().SILENT_S


				local MAX_RANGE = 300

				local gap_min = 0
				local gap_seen = false
				local gap_gun = nil
				local want_since = 0

				local function gap_reset()
					gap_min = 0
					gap_seen = false
					S.fire_gap = 0
				end

				local function gap_push(value)
					if value <= 0 then return end
					if not gap_seen or value < gap_min then
						gap_min = value
						gap_seen = true
						S.fire_gap = value
					end
				end

				local round_mod = nil

				local function get_round()
					if round_mod then return round_mod end
					local ok, m = pcall(function()
						return require(rs:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
					end)
					if ok and type(m) == "table" then round_mod = m end
					return round_mod
				end

				local function holds(container, name)
					return container ~= nil and container:FindFirstChild(name) ~= nil
				end

				local function lp_has_gun()
					return holds(lp.Character, "Gun") or holds(lp:FindFirstChildOfClass("Backpack"), "Gun")
				end

				local target_player = nil
				local target_char = nil
				local target_part = nil
				local target_hum = nil

				local function refresh_target()
					local found = nil
					local m = get_round()
					local data = m and m.PlayerData or nil
					if type(data) == "table" then
						local me = data[lp.Name]
						S.am_sheriff = (me ~= nil and (me.Role == "Sheriff" or me.Role == "Hero")) or lp_has_gun()
						for name, d in pairs(data) do
							if type(d) == "table" and d.Role == "Murderer" and not d.Dead then
								found = players:FindFirstChild(name)
								break
							end
						end
					else
						S.am_sheriff = lp_has_gun()
					end
					if not found then
						for _, plr in ipairs(players:GetPlayers()) do
							if plr ~= lp and holds(plr.Character, "Knife") then
								found = plr
								break
							end
						end
					end
					if found ~= target_player then
						target_player = found
						target_char = nil
						target_part = nil
						target_hum = nil
					end
					if not found then return end
					local char = found.Character
					if char ~= target_char then
						target_char = char
						target_part = nil
						target_hum = nil
					end
					if not char then return end
					if not target_part or not target_part.Parent then
						target_part = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
					end
					if not target_hum or not target_hum.Parent then
						target_hum = char:FindFirstChildOfClass("Humanoid")
					end
				end

				local function target_alive()
					if not target_part or not target_part.Parent then return false end
					if not target_hum or not target_hum.Parent then return false end
					return target_hum.Health > 0
				end

				local ray_params = RaycastParams.new()
				ray_params.FilterType = Enum.RaycastFilterType.Exclude
				ray_params.IgnoreWater = false

				local ignore_base = {}
				local ignore_work = {}
				local ignore_time = 0

				local function refresh_ignore()
					local now = os.clock()
					if #ignore_base > 0 and now - ignore_time < 0.5 then return end
					ignore_time = now
					table.clear(ignore_base)
					local char = lp.Character
					if char then ignore_base[1] = char end
					local ok, tagged = pcall(function() return collection:GetTagged("WeaponPassthrough") end)
					if ok and type(tagged) == "table" then
						for k = 1, #tagged do
							ignore_base[#ignore_base + 1] = tagged[k]
						end
					end
				end

				local function trace(origin, direction)
					refresh_ignore()
					table.clear(ignore_work)
					for k = 1, #ignore_base do ignore_work[k] = ignore_base[k] end
					local result = nil
					for _ = 1, 6 do
						ray_params.FilterDescendantsInstances = ignore_work
						result = workspace:Raycast(origin, direction, ray_params)
						if not result then break end
						local inst = result.Instance
						if not inst then break end
						local ok, tr = pcall(function() return inst.Transparency end)
						if not ok or tr ~= 1 then break end
						ignore_work[#ignore_work + 1] = inst
					end
					return result
				end

				local function gun_attachment()
					local char = lp.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					if not hrp then return nil, nil end
					return hrp:FindFirstChild("GunRaycastAttachment"), hrp
				end

				local function origin_cframe()
					local att, hrp = gun_attachment()
					if att then return att.WorldCFrame end
					if hrp then return hrp.CFrame end
					return nil
				end

				local function grav()
					local ok, g = pcall(function() return workspace.Gravity end)
					if ok and type(g) == "number" and g > 0 then return g end
					return 0
				end

				local P = {
					snap = 48,
					ring = 48,
					hit_r = 2.1,
					pad = 2.6,
					min_span = 5,
					max_span = 90,
					acc_t = 0.15,
					acc_max = 280,
					acc_min = 40,
					speed_floor = 26,
					speed_head = 1.3,
				}

				local snap_t = table.create(P.snap, 0)
				local snap_p = table.create(P.snap, Vector3.zero)
				local snap_n = 0
				local snap_i = 0

				local TR = {
					part = nil,
					pos = nil,
					time = 0,
					vel = Vector3.zero,
					gap = 0,
					ready = false,
					fresh = Vector3.zero,
					air = false,
					air_since = 0,
					jumping = false,
					jump_v = 0,
					fresh_ok = false,
					turn = 0,
					spoof = 0,
					clr = 0,
					air_edge = 0,
					jump_fresh = false,
				}

				local SK = {
					vt = table.create(P.ring, 0),
					dx = table.create(P.ring, 0),
					dz = table.create(P.ring, 0),
					vn = 0,
					vi = 0,
				}

				local EC = {
					ping = 0,
					rtt = 0,
					jitter = 0,
					seen = false,
					step = 0,
					step_seen = false,
				}

				local function step_push(dt)
					if dt <= 0 or dt > 0.5 then return end
					if EC.step_seen then
						EC.step = EC.step * 0.85 + dt * 0.15
					else
						EC.step = dt
						EC.step_seen = true
					end
				end

				local function sample_span()
					local span = math.max(EC.step, TR.gap)
					if span <= 0 then return 0 end
					return span
				end

				local HY = {
					pos = {},
					w = {},
					n = 0,
					weight = 0,
					primary = nil,
					stamp = 0,
					conf = 0,
				}

				local ground_params = RaycastParams.new()
				ground_params.FilterType = Enum.RaycastFilterType.Exclude
				ground_params.IgnoreWater = true

				local ground_filter = {}
				local axis_pool = {}

				local function ground_below(pos, reach)
					table.clear(ground_filter)
					local n = 0
					local char = target_char
					if char then
						n = n + 1
						ground_filter[n] = char
					end
					local mine = lp.Character
					if mine then
						n = n + 1
						ground_filter[n] = mine
					end
					ground_params.FilterDescendantsInstances = ground_filter
					local res = workspace:Raycast(pos, Vector3.new(0, -reach, 0), ground_params)
					if res then return res.Position.Y end
					return nil
				end

				local function snap_push(now, pos)
					snap_i = snap_i % P.snap + 1
					snap_t[snap_i] = now
					snap_p[snap_i] = pos
					if snap_n < P.snap then snap_n = snap_n + 1 end
				end

				local function snap_get(k)
					local idx = (snap_i - k - 1) % P.snap + 1
					return snap_t[idx], snap_p[idx]
				end

				local function fit_velocity()
					if snap_n < 3 then return nil end
					local newest = snap_get(0)
					local used = 0
					local sum_d = 0
					local win = sample_span() * 4
					for k = 0, snap_n - 1 do
						local t = snap_get(k)
						if newest - t > win then break end
						used = used + 1
						sum_d = sum_d + t - newest
					end
					if used < 3 then return nil end
					local mean_d = sum_d / used
					local num = Vector3.zero
					local den = 0
					for k = 0, used - 1 do
						local t, p = snap_get(k)
						local d = t - newest - mean_d
						num = num + p * d
						den = den + d * d
					end
					if den < 1e-8 then return nil end
					return num / den, -mean_d
				end

				local function recent_velocity()
					if snap_n < 2 then return nil end
					local newest, head = snap_get(0)
					local fallback, fallback_age = nil, nil
					local target_span = sample_span() * 2
					local max_span = target_span * 2
					for k = 1, snap_n - 1 do
						local t, p = snap_get(k)
						local dt = newest - t
						if dt > max_span then break end
						if dt > 0 then
							fallback = (head - p) / dt
							fallback_age = dt * 0.5
							if dt >= target_span then
								return fallback, fallback_age
							end
						end
					end
					return fallback, fallback_age
				end

				local KIN = {
					ok = false,
					ax = 0,
					az = 0,
					smax = 0,
				}

				local function kin_clear()
					KIN.ok = false
					KIN.ax = 0
					KIN.az = 0
					KIN.smax = 0
				end

				local function fit_kin()
					if snap_n < 5 then return nil end
					local t0 = snap_get(0)
					local win = math.max(sample_span() * 5, 0.12)
					local scale = win
					local n, s1, s2, s3, s4 = 0, 0, 0, 0, 0
					local bx0, bx1, bx2 = 0, 0, 0
					local bz0, bz1, bz2 = 0, 0, 0
					for k = 0, snap_n - 1 do
						local t, p = snap_get(k)
						local age = t0 - t
						if age > win then break end
						local u = -age / scale
						local u2 = u * u
						n = n + 1
						s1 = s1 + u
						s2 = s2 + u2
						s3 = s3 + u2 * u
						s4 = s4 + u2 * u2
						bx0 = bx0 + p.X
						bx1 = bx1 + p.X * u
						bx2 = bx2 + p.X * u2
						bz0 = bz0 + p.Z
						bz1 = bz1 + p.Z * u
						bz2 = bz2 + p.Z * u2
					end
					if n < 5 then return nil end
					local det = n * (s2 * s4 - s3 * s3)
						- s1 * (s1 * s4 - s3 * s2)
						+ s2 * (s1 * s3 - s2 * s2)
					if math.abs(det) < 1e-9 then return nil end
					local function solve(b0, b1, b2)
						local d1 = n * (b1 * s4 - s3 * b2)
							- b0 * (s1 * s4 - s3 * s2)
							+ s2 * (s1 * b2 - b1 * s2)
						local d2 = n * (s2 * b2 - b1 * s3)
							- s1 * (s1 * b2 - b1 * s2)
							+ b0 * (s1 * s3 - s2 * s2)
						return d1 / det, d2 / det
					end
					local cx1, cx2 = solve(bx0, bx1, bx2)
					local cz1, cz2 = solve(bz0, bz1, bz2)
					local vx, vz = cx1 / scale, cz1 / scale
					local ax, az = 2 * cx2 / (scale * scale), 2 * cz2 / (scale * scale)
					if vx ~= vx or vz ~= vz or ax ~= ax or az ~= az then return nil end
					return Vector3.new(vx, 0, vz), Vector3.new(ax, 0, az)
				end

				local function kin_update()
					local kv, ka = fit_kin()
					if not kv then
						KIN.ok = false
						KIN.ax = 0
						KIN.az = 0
						return nil
					end
					KIN.ok = true
					local sp = math.sqrt(kv.X * kv.X + kv.Z * kv.Z)
					if sp > KIN.smax then
						KIN.smax = sp
					else
						KIN.smax = KIN.smax * 0.985 + sp * 0.015
					end
					if ka and not TR.air then
						local am = math.sqrt(ka.X * ka.X + ka.Z * ka.Z)
						local ax, az = ka.X, ka.Z
						if am > P.acc_max and am > 0 then
							ax = ax * P.acc_max / am
							az = az * P.acc_max / am
						end
						KIN.ax = KIN.ax * 0.5 + ax * 0.5
						KIN.az = KIN.az * 0.5 + az * 0.5
					else
						KIN.ax = KIN.ax * 0.5
						KIN.az = KIN.az * 0.5
					end
					return kv
				end

				local function snap_vel(k)
					local t0, p0 = snap_get(k)
					local t1, p1 = snap_get(k + 1)
					local d = t0 - t1
					if d <= 0 then return nil end
					return (p0 - p1) / d, d
				end

				local function vert_accel()
					if snap_n < 3 then return nil end
					local v0, d0 = snap_vel(0)
					local v1, d1 = snap_vel(1)
					if not v0 or not v1 then return nil end
					local span = (d0 + d1) * 0.5
					if span <= 1e-4 then return nil end
					return (v0.Y - v1.Y) / span
				end

				local function air_vy()
					if snap_n < 2 then return nil end
					local edge = TR.air_edge
					if edge <= 0 then return nil end
					local g = grav()
					local newest, head = snap_get(0)
					local want = sample_span() * 2
					local best = nil
					for k = 1, snap_n - 1 do
						local t, p = snap_get(k)
						if t < edge then break end
						local dt = newest - t
						if dt > 1e-4 then
							best = (head.Y - p.Y) / dt - 0.5 * g * dt
							if dt >= want then break end
						end
					end
					return best
				end

				local function body_clearance()
					local part = target_part
					local hum = target_hum
					if not part or not hum then return 0 end
					local ok, value = pcall(function() return part.Size.Y * 0.5 + hum.HipHeight end)
					if ok and type(value) == "number" and value > 0 then return value end
					return 0
				end

				local GC = {
					base = 0,
					seen = false,
				}

				local JL = {
					v = 0,
					seen = false,
				}

				local function stand_clearance()
					if GC.seen then return GC.base end
					return body_clearance()
				end

				local function engine_vel(part)
					local ok, v = pcall(function() return part.AssemblyLinearVelocity end)
					if not ok or typeof(v) ~= "Vector3" then
						ok, v = pcall(function() return part.Velocity end)
					end
					if not ok or typeof(v) ~= "Vector3" then return nil end
					if v.Magnitude ~= v.Magnitude then return nil end
					return v
				end

				local function vel_trust(pv, ev)
					if not pv or not ev then return 0 end
					local ph = Vector3.new(pv.X, 0, pv.Z)
					local eh = Vector3.new(ev.X, 0, ev.Z)
					local pm, em = ph.Magnitude, eh.Magnitude
					if pm < 1 and em < 1 then return 1 end
					if pm < 1 or em < 1 then return 0 end
					local ratio = em / pm
					if ratio > 1.5 or ratio < 0.6 then return 0 end
					local align = ph.Unit:Dot(eh.Unit)
					if align < 0.7 then return 0 end
					local a = math.clamp((align - 0.7) / 0.25, 0, 1)
					local r = 1 - math.clamp(math.abs(ratio - 1) / 0.4, 0, 1)
					return a * r
				end

				local function phase_velocity(v, age, air)
					if not v then return nil end
					local y = 0
					if air then
						y = v.Y - grav() * math.clamp(age or 0, 0, sample_span() * 4)
					end
					return Vector3.new(v.X, y, v.Z)
				end

				local function merge_vel(fit, fit_age, fast, fast_age, engine, engine_age, air)
					local stable = phase_velocity(fit, fit_age, air)
					local instant = phase_velocity(fast, fast_age, air)
					local turn = 0
					if stable and instant then
						local sh = Vector3.new(stable.X, 0, stable.Z)
						local ih = Vector3.new(instant.X, 0, instant.Z)
						if sh.Magnitude > 1 and ih.Magnitude > 1 then
							turn = math.acos(math.clamp(sh.Unit:Dot(ih.Unit), -1, 1)) / math.pi
						end
					end
					local base = instant or stable
					if not base then return Vector3.zero, 0, nil, 0 end
					if stable and instant then
						local agility = math.clamp(turn * 2.2, 0, 1)
						base = stable:Lerp(instant, 0.4 + 0.6 * agility)
					end
					local trust = 0
					if engine then
						local live = phase_velocity(engine, engine_age, air)
						trust = vel_trust(base, live)
						if trust > 0 and air then
							base = Vector3.new(base.X, base.Y, base.Z):Lerp(Vector3.new(base.X, live.Y, base.Z), trust * 0.35)
						end
					end
					return base, turn, instant or stable, trust
				end

				local function vel_push(now, hx, hz)
					SK.vi = SK.vi % P.ring + 1
					SK.vt[SK.vi] = now
					SK.dx[SK.vi] = hx
					SK.dz[SK.vi] = hz
					if SK.vn < P.ring then SK.vn = SK.vn + 1 end
				end

				local function track_clear()
					TR.part = nil
					TR.pos = nil
					TR.vel = Vector3.zero
					TR.gap = 0
					TR.ready = false
					TR.fresh = Vector3.zero
					TR.air = false
					TR.jumping = false
					TR.jump_v = 0
					TR.fresh_ok = false
					TR.turn = 0
					TR.spoof = 0
					TR.clr = 0
					TR.air_edge = 0
					TR.jump_fresh = false
					GC.base = 0
					GC.seen = false
					JL.v = 0
					JL.seen = false
					snap_n, snap_i = 0, 0
					SK.vn, SK.vi = 0, 0
					kin_clear()
				end

				local function track_seed(part, pos, now)
					TR.part = part
					TR.pos = pos
					TR.time = now
					TR.vel = Vector3.zero
					TR.fresh = Vector3.zero
					TR.fresh_ok = false
					TR.turn = 0
					TR.jump_v = 0
					TR.gap = 0
					TR.ready = false
					TR.spoof = 0
					TR.air_edge = 0
					TR.jump_fresh = false
					GC.base = 0
					GC.seen = false
					snap_n, snap_i = 0, 0
					kin_clear()
					snap_push(now, pos)
				end

				local function track_fresh(now)
					local part = target_part
					if not part or not part.Parent then
						TR.fresh_ok = false
						return
					end
					local pos = part.Position
					local g = grav()
					local sv = snap_vel(0)
					local vy = sv and sv.Y or 0
					local accel = vert_accel()
					local falling = accel ~= nil and accel < -g * 0.5
					local guess = stand_clearance()
					local reach = guess + 6 + math.abs(vy) * sample_span() * 4
					local air
					local gy = ground_below(pos, reach)
					if gy then
						local clr = pos.Y - gy
						TR.clr = clr
						if math.abs(vy) < 1 and not falling then
							if GC.seen then
								if clr < GC.base then
									GC.base = GC.base * 0.7 + clr * 0.3
								else
									GC.base = GC.base * 0.98 + clr * 0.02
								end
							else
								GC.base = clr
								GC.seen = true
							end
						end
						local floor = GC.seen and GC.base or guess
						local tol = math.max(floor * 0.35, 1)
						air = clr > floor + tol
						if not air and falling and math.abs(vy) > 4 and clr > floor + 0.35 then
							air = true
						end
					else
						air = true
					end
					if air ~= TR.air then
						TR.air_edge = now
						if air then
							TR.air_since = now
							TR.jump_fresh = true
							TR.jump_v = JL.seen and JL.v or math.max(vy, 0)
						else
							TR.jump_fresh = false
							TR.jump_v = 0
						end
					end
					local model_vy = TR.jump_v - g * math.max(0, now - TR.air_since)
					TR.air = air
					TR.jumping = air and (vy > 1 or model_vy > 1)
				end

				local function track(now)
					local part = target_part
					if not part or not part.Parent then
						if TR.part then track_clear() end
						return
					end
					track_fresh(now)
					local pos = part.Position
					if part ~= TR.part or not TR.pos then
						track_seed(part, pos, now)
						return
					end
					local dt = now - TR.time
					if dt > 0.75 or (pos - TR.pos).Magnitude > 140 then
						track_seed(part, pos, now)
						return
					end
					if dt <= 0 then return end
					if (pos - TR.pos).Magnitude == 0 then
						if TR.gap > 0 and dt >= TR.gap then
							TR.vel = Vector3.zero
							TR.fresh = Vector3.zero
						end
						return
					end
					step_push(dt)
					TR.gap = dt
					snap_push(now, pos)
					TR.pos = pos
					TR.time = now
					local fit, fit_age = fit_velocity()
					local fast, fast_age = recent_velocity()
					local engine = engine_vel(part)
					local fresh, turn, instant, trust = merge_vel(fit, fit_age, fast, fast_age, engine, sample_span() * 0.5, TR.air)
					local kv = kin_update()
					if kv then
						fresh = Vector3.new(kv.X, fresh.Y, kv.Z)
					end
					if engine and trust <= 0 then
						if TR.spoof < 20 then TR.spoof = TR.spoof + 1 end
					elseif TR.spoof > 0 then
						TR.spoof = TR.spoof - 1
					end
					if TR.air then
						local vy = air_vy()
						if vy then
							fresh = Vector3.new(fresh.X, vy, fresh.Z)
							local since = math.max(0, now - TR.air_edge)
							if TR.jump_fresh and since <= 0.2 then
								local impulse = vy + grav() * since
								if impulse > 1 then
									if JL.seen then
										JL.v = JL.v * 0.7 + impulse * 0.3
									else
										JL.v = impulse
										JL.seen = true
									end
									if impulse > TR.jump_v then TR.jump_v = impulse end
								end
							else
								TR.jump_fresh = false
							end
						end
					end
					TR.vel = fresh
					TR.ready = fit ~= nil or fast ~= nil
					TR.fresh = TR.vel
					TR.fresh_ok = TR.ready
					TR.turn = turn
					local raw = instant or fresh
					vel_push(now, raw.X, raw.Z)
				end

				local function raw_rtt()
					local data, net
					local ok, ms = pcall(function()
						return stats.Network.ServerStatsItem["Data Ping"]:GetValue()
					end)
					if ok and type(ms) == "number" and ms == ms and ms > 4 and ms < 800 then
						data = ms / 1000
					end
					local fine, value = pcall(function() return lp:GetNetworkPing() end)
					if fine and type(value) == "number" and value == value and value > 0 then
						local r = value * 2
						if r > 0.004 and r < 0.8 then net = r end
					end
					if data and net then return (data + net) * 0.5 end
					return data or net
				end

				local function sample_ping()
					local rtt = raw_rtt()
					if not rtt or rtt ~= rtt then return end
					rtt = math.clamp(rtt, 0, 1)
					if EC.seen then
						EC.jitter = EC.jitter * 0.9 + math.abs(rtt - EC.rtt) * 0.1
						EC.rtt = EC.rtt * 0.82 + rtt * 0.18
					else
						EC.rtt = rtt
						EC.jitter = 0
						EC.seen = true
					end
					EC.ping = EC.rtt
				end

				local function lead_time()
					if not EC.seen then return 0 end
					local stale = 0
					if TR.time > 0 and EC.step_seen then
						stale = math.clamp(os.clock() - TR.time, 0, EC.step)
					end
					return math.clamp(EC.rtt + EC.jitter * 0.5 + stale, 0, 1)
				end

				local function rotate_y(v, ang)
					local c, s = math.cos(ang), math.sin(ang)
					return Vector3.new(v.X * c - v.Z * s, v.Y, v.X * s + v.Z * c)
				end

				local function dir_stats(win)
					if SK.vn < 4 then return 1, 0 end
					win = math.max(win, sample_span() * 3)
					local newest = SK.vt[SK.vi]
					local sx, sz, n = 0, 0, 0
					local prev = nil
					local turn, turn_n = 0, 0
					local oldest = newest
					for k = 0, SK.vn - 1 do
						local idx = (SK.vi - k - 1) % P.ring + 1
						local t = SK.vt[idx]
						if newest - t > win then break end
						local hx, hz = SK.dx[idx], SK.dz[idx]
						local m = math.sqrt(hx * hx + hz * hz)
						if m > 0 then
							sx = sx + hx / m
							sz = sz + hz / m
							n = n + 1
							local ang = math.atan2(hz, hx)
							if prev then
								local d = ang - prev
								while d > math.pi do d = d - 6.2831853 end
								while d < -math.pi do d = d + 6.2831853 end
								turn = turn + d
								turn_n = turn_n + 1
							end
							prev = ang
							oldest = t
						end
					end
					if n < 2 then return 1, 0 end
					local coh = math.clamp(math.sqrt(sx * sx + sz * sz) / n, 0, 1)
					local omega = 0
					local elapsed = newest - oldest
					if turn_n >= 1 and elapsed > 1e-3 then
						omega = -turn / elapsed
					end
					return coh, omega
				end

				local function predict_from(base, sa, sb, fh, now)
					local span = math.max(0, sa + sb)
					local g = grav()
					local dir = fh
					if dir.Magnitude == 0 then
						dir = Vector3.new(TR.vel.X, 0, TR.vel.Z)
					end
					local x, z
					if span > 0 and KIN.ok then
						local age = math.clamp(now - TR.time, 0, sample_span() * 2)
						local ax, az = KIN.ax, KIN.az
						if TR.air or math.sqrt(ax * ax + az * az) < P.acc_min then ax, az = 0, 0 end
						local vx = dir.X + ax * age
						local vz = dir.Z + az * age
						local ta = math.min(span, P.acc_t)
						local dx = vx * span + 0.5 * ax * ta * ta
						local dz = vz * span + 0.5 * az * ta * ta
						local reach = math.sqrt(dx * dx + dz * dz)
						local cap = math.max(KIN.smax * P.speed_head, P.speed_floor) * span
						if reach > cap and reach > 1e-6 then
							dx = dx * cap / reach
							dz = dz * cap / reach
						end
						x = base.X + dx
						z = base.Z + dz
					else
						local hspan = span
						if span > 0 and dir.Magnitude > 0 and not TR.air then
							local coh, omega = dir_stats(span)
							local conf = math.clamp(coh, 0, 1) * (1 - math.clamp(TR.turn, 0, 1) * 0.5)
							if omega ~= 0 then
								dir = rotate_y(dir, math.clamp(omega * span * 0.5 * conf, -0.6, 0.6))
							end
							hspan = span * (0.85 + 0.15 * conf)
						end
						x = base.X + dir.X * hspan
						z = base.Z + dir.Z * hspan
					end
					local y = base.Y
					if TR.air and span > 0 then
						local vy = TR.vel.Y
						local phase = math.max(0, now - TR.air_since)
						local modeled = TR.jump_v - g * phase
						if TR.jumping and TR.jump_v > 0 and g > 0 and phase <= TR.jump_v / g and modeled > vy then
							vy = modeled
						end
						y = base.Y + vy * span - 0.5 * g * span * span
						if y < base.Y then
							local clearance = stand_clearance()
							local reach = base.Y - y + clearance
							local gy = ground_below(Vector3.new(x, base.Y, z), reach)
							if gy then
								local floor = gy + clearance
								if y < floor then y = floor end
							end
						end
					end
					return Vector3.new(x, y, z)
				end

				local function build_hyps(base, now)
					table.clear(HY.pos)
					table.clear(HY.w)
					local horizon = S.predict and TR.ready and lead_time() or 0
					local fh = Vector3.new(TR.fresh.X, 0, TR.fresh.Z)
					HY.primary = predict_from(base, 0, horizon, fh, now)
					HY.n = 1
					HY.pos[1] = HY.primary
					HY.w[1] = 1
					HY.weight = 1
					HY.stamp = now
				end

				local function score_axis(anchor, axis)
					local covered = 0
					local lo, hi = 0, 0
					for k = 1, HY.n do
						local d = HY.pos[k] - anchor
						local a = d:Dot(axis)
						local perp = (d - axis * a).Magnitude
						if perp <= P.hit_r then
							covered = covered + HY.w[k]
							if a < lo then lo = a end
							if a > hi then hi = a end
						end
					end
					return covered, lo, hi
				end

				local function corridor_axes(anchor)
					table.clear(axis_pool)
					local n = 0
					local function add(v)
						if typeof(v) ~= "Vector3" or v.Magnitude < 1e-4 then return end
						local u = v.Unit
						for k = 1, n do
							if axis_pool[k]:Dot(u) > 0.985 then return end
						end
						n = n + 1
						axis_pool[n] = u
					end
					local fh = Vector3.new(TR.fresh.X, 0, TR.fresh.Z)
					if TR.air then add(TR.fresh) end
					add(fh)
					for k = 1, HY.n do
						add(HY.pos[k] - anchor)
					end
					add(TR.fresh)
					add(Vector3.new(0, 1, 0))
					return n
				end

				local function build_corridor(now)
					local part = target_part
					if not part or not part.Parent then return nil end
					local base = part.Position
					build_hyps(base, now)
					local anchor = HY.primary or base
					local count = corridor_axes(anchor)
					local best_axis, best_cov, best_lo, best_hi = nil, -1, 0, 0
					for k = 1, count do
						local axis = axis_pool[k]
						local cov, lo, hi = score_axis(anchor, axis)
						if cov > best_cov then
							best_axis, best_cov, best_lo, best_hi = axis, cov, lo, hi
						end
					end
					if not best_axis then return nil end
					HY.conf = HY.weight > 0 and best_cov / HY.weight or 0

					local pad = P.pad
					local origin = anchor + best_axis * (best_lo - pad)
					local aim = anchor + best_axis * (best_hi + pad)
					if (aim - origin).Magnitude < 4 then
						origin = anchor - best_axis * 4
						aim = anchor + best_axis * 4
					end
					return origin, aim, HY.conf, anchor
				end

				local pred_off = Vector3.zero
				local pred_stamp = 0

				local function lead_offset()
					local part = target_part
					if not part or not part.Parent then return Vector3.zero end
					if not S.predict or not TR.ready then return Vector3.zero end
					local base = part.Position
					local now = os.clock()
					local fh = Vector3.new(TR.fresh.X, 0, TR.fresh.Z)
					local point = predict_from(base, 0, lead_time(), fh, now)
					local off = point - base
					pred_stamp = now
					pred_off = off
					return pred_off
				end

				local function cloud_confidence()
					local anchor = HY.primary
					if not anchor or HY.n == 0 or HY.weight <= 0 then return 0 end
					local covered = 0
					for k = 1, HY.n do
						if (HY.pos[k] - anchor).Magnitude <= P.hit_r then
							covered = covered + HY.w[k]
						end
					end
					return covered / HY.weight
				end
				local hit_names = {
					"HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso", "Head",
					"RightUpperArm", "LeftUpperArm", "Right Arm", "Left Arm",
					"RightUpperLeg", "LeftUpperLeg", "Right Leg", "Left Leg",
					"RightLowerLeg", "LeftLowerLeg",
				}

				local hit_parts = {}
				local hit_count = 0
				local hit_char = nil

				local function refresh_parts()
					local char = target_char
					if char == hit_char then return end
					table.clear(hit_parts)
					hit_count = 0
					hit_char = char
					if not char then return end
					for k = 1, #hit_names do
						local part = char:FindFirstChild(hit_names[k])
						if part and part:IsA("BasePart") then
							hit_count = hit_count + 1
							hit_parts[hit_count] = part
						end
					end
				end

				local function los_clear(origin, point)
					if not origin or not point then return false end
					local delta = point - origin
					local dist = delta.Magnitude
					if dist < 0.5 then return true end
					if dist > MAX_RANGE then return false end
					local hit = trace(origin, delta)
					if not hit then return true end
					local inst = hit.Instance
					local char = target_char
					if inst and char and (inst == char or inst:IsDescendantOf(char)) then return true end
					return (hit.Position - origin).Magnitude >= dist - 0.75
				end

				local function pick_point(origin, strict)
					refresh_parts()
					if hit_count == 0 then return nil end
					local off = lead_offset()
					local first = nil
					for k = 1, hit_count do
						local part = hit_parts[k]
						if not part.Parent then
							hit_char = nil
						else
							local point = part.Position + off
							if not origin then return point end
							if not first then first = point end
							if los_clear(origin, point) then return point end
						end
					end
					if strict then return nil end
					return first
				end

				local force_att = nil
				local force_saved = nil
				local force_stamp = 0

				local function restore_origin()
					local att = force_att
					if not att then return end
					local saved = force_saved
					force_att = nil
					force_saved = nil
					if saved then
						pcall(function()
							if att.Parent then att.CFrame = saved end
						end)
					end
				end

				local function push_origin(cf)
					local att = gun_attachment()
					if not att then return false end
					if force_att and force_att ~= att then restore_origin() end
					if not force_att then
						local ok, saved = pcall(function() return att.CFrame end)
						if not ok or typeof(saved) ~= "CFrame" then return false end
						force_att = att
						force_saved = saved
					end
					force_stamp = os.clock()
					local ok = pcall(function() att.WorldCFrame = cf end)
					if not ok then
						restore_origin()
						return false
					end
					task.defer(restore_origin)
					return true
				end

				local function is_target_hit(inst)
					local char = target_char
					if not inst or not char then return false end
					return inst == char or inst:IsDescendantOf(char)
				end

				local function force_clear(origin, aim)
					local hit = trace(origin, aim - origin)
					if not hit then return false end
					return is_target_hit(hit.Instance)
				end

				local function force_velocity()
					if TR.fresh_ok and TR.fresh.Magnitude > 0.5 then return TR.fresh end
					if TR.ready and TR.vel.Magnitude > 0.5 then return TR.vel end
					return Vector3.zero
				end

				local function resolve_force()
					local part = target_part
					if not part or not part.Parent then return nil end
					local live = part.Position
					local now = os.clock()

					local origin, aim, conf, anchor = build_corridor(now)
					if origin and aim then
						local axis = aim - origin
						local span = axis.Magnitude
						if span > 1e-3 then
							local u = axis / span
							local mark = anchor or live
							local behind = (mark - origin):Dot(u)
							if behind < P.pad then
								origin = origin - u * (P.pad - behind)
							end
							local ahead = (aim - mark):Dot(u)
							if ahead < P.min_span then
								aim = mark + u * P.min_span
							end
							local want = S.stand_off
							while want > 0 do
								local probe = origin - u * want
								if (aim - probe).Magnitude <= P.max_span
									and los_clear(probe, mark)
									and los_clear(probe, live) then
									origin = probe
									break
								end
								want = want - 3
							end
							if (aim - origin).Magnitude > P.max_span then
								origin = aim - u * P.max_span
							end
							return CFrame.new(origin, aim), CFrame.new(aim), conf or 0, mark
						end
					end

					local vel = force_velocity()
					local dir = Vector3.new(0, -1, 0)
					if vel.Magnitude > 3 then
						dir = vel.Unit
					else
						local mine = origin_cframe()
						if mine then
							local delta = live - mine.Position
							if delta.Magnitude > 2 then dir = delta.Unit end
						end
					end
					local back = live - dir * 6
					local front = live + dir * math.max(P.min_span, vel.Magnitude * lead_time() + 8)
					if not force_clear(back, front) then
						back = live - dir * 2.5
					end
					return CFrame.new(back, front), CFrame.new(front), 0, live
				end

				local function shot_shift(dt)
					if not S.predict or not TR.ready or dt <= 0 then return Vector3.zero end
					local shift = Vector3.new(TR.vel.X * dt, 0, TR.vel.Z * dt)
					if TR.air then
						local g = grav()
						local horizon = lead_time()
						local vy = TR.vel.Y
						local phase = math.max(0, os.clock() - TR.air_since)
						local modeled = TR.jump_v - g * phase
						if TR.jumping and TR.jump_v > 0 and g > 0 and phase <= TR.jump_v / g and modeled > vy then vy = modeled end
						shift = Vector3.new(shift.X, vy * dt - g * horizon * dt - 0.5 * g * dt * dt, shift.Z)
					end
					return shift
				end

				local function compensate_force(origin_cf, aim_cf, started)
					local shift = shot_shift(math.max(0, os.clock() - started))
					if shift == Vector3.zero then return origin_cf, aim_cf end
					local origin = origin_cf.Position + shift
					local aim = aim_cf.Position + shift
					return CFrame.new(origin, aim), CFrame.new(aim)
				end

				local function direct_point()
					local part = target_part
					if not part or not part.Parent then return nil end
					local cf = origin_cframe()
					if not cf then return nil end
					local live = part.Position
					local point = live + lead_offset()
					if not los_clear(cf.Position, live) or not los_clear(cf.Position, point) then return nil end
					return point, cf
				end

				local function resolve_shot()
					if not S.enabled or not S.am_sheriff or not target_alive() then return nil end
					if S.direct then
						local point = direct_point()
						if point then
							restore_origin()
							return CFrame.new(point)
						end
					end
					if S.force then
						local started = os.clock()
						local origin_cf, aim_cf = resolve_force()
						if origin_cf and aim_cf then
							origin_cf, aim_cf = compensate_force(origin_cf, aim_cf, started)
							if push_origin(origin_cf) then return aim_cf end
						end
					end
					local cf = origin_cframe()
					local aim = pick_point(cf and cf.Position or nil, false)
					if not aim then return nil end
					return CFrame.new(aim)
				end

				local function compensate_resolve(cf)
					if S.force or typeof(cf) ~= "CFrame" then return cf end
					return CFrame.new(cf.Position + shot_shift(math.max(0, os.clock() - pred_stamp)))
				end

				local weapon_service = nil
				local orig_mouse = nil
				local orig_screen = nil
				local hook_mouse = nil
				local hook_screen = nil

				local ws_inst = nil
				local function get_weapon_service()
					local cs = rs:FindFirstChild("ClientServices")
					local inst = cs and cs:FindFirstChild("WeaponService")
					if inst ~= ws_inst then
						ws_inst = inst
						weapon_service = nil
					end
					if weapon_service then return weapon_service end
					if not inst then return nil end
					local ok, m = pcall(require, inst)
					if ok and type(m) == "table" then weapon_service = m end
					return weapon_service
				end

				local function install_hooks()
					local m = get_weapon_service()
					if not m then return end
					if not hook_mouse then
						local function knife_aim()
							local fn = getgenv().KNIFE_AIM_RESOLVE
							if type(fn) ~= "function" then return nil end
							local ok, cf = pcall(fn)
							if ok and typeof(cf) == "CFrame" then return cf end
							return nil
						end
						hook_mouse = function(self, ...)
							sample_ping()
							local ok, cf = pcall(resolve_shot)
							if ok and cf then return compensate_resolve(cf) end
							local kcf = knife_aim()
							if kcf then return kcf end
							return orig_mouse(self, ...)
						end
						hook_screen = function(self, x, y, ...)
							sample_ping()
							local ok, cf = pcall(resolve_shot)
							if ok and cf then return compensate_resolve(cf) end
							local kcf = knife_aim()
							if kcf then return kcf end
							return orig_screen(self, x, y, ...)
						end
					end
					pcall(function() setreadonly(m, false) end)
					if type(m.GetMouseTargetCFrame) == "function" and m.GetMouseTargetCFrame ~= hook_mouse then
						orig_mouse = m.GetMouseTargetCFrame
						pcall(function() m.GetMouseTargetCFrame = hook_mouse end)
					end
					if type(m.GetTargetPosition) == "function" and m.GetTargetPosition ~= hook_screen then
						orig_screen = m.GetTargetPosition
						pcall(function() m.GetTargetPosition = hook_screen end)
					end
				end

				local gun_fired_conn = nil
				local last_fire_stamp = 0

				local function on_gun_fired(tool)
					if typeof(tool) ~= "Instance" then return end
					local char = lp.Character
					if not char then return end
					local ok, mine = pcall(function() return tool:IsDescendantOf(char) end)
					if not ok or not mine then return end
					local now = os.clock()
					if last_fire_stamp > 0 and want_since > 0 and want_since <= last_fire_stamp then
						gap_push(now - last_fire_stamp)
					end
					last_fire_stamp = now
				end

				local function connect_gun_fired()
					if gun_fired_conn then return end
					local m = get_weapon_service()
					if not m then return end
					local ev = m.GunFired
					if typeof(ev) ~= "Instance" then return end
					gun_fired_conn = ev.OnClientEvent:Connect(function(tool)
						pcall(on_gun_fired, tool)
					end)
				end

				local function get_gun()
					local char = lp.Character
					if char then
						local g = char:FindFirstChild("Gun")
						if g then return g, true end
					end
					local bp = lp:FindFirstChildOfClass("Backpack")
					if bp then
						local g = bp:FindFirstChild("Gun")
						if g then return g, false end
					end
					return nil, false
				end

				local function fire_gun(gun, start_cf, aim_cf)
					if not gun or not start_cf or not aim_cf then return false end
					local remote = gun:FindFirstChild("Shoot")
					if not remote or not remote:IsA("RemoteEvent") then return false end
					return (pcall(function() remote:FireServer(start_cf, aim_cf) end))
				end

				local function auto_step(now)
					if not S.auto_on or not S.enabled or not S.am_sheriff or getgenv().AUTOFARM_HOLD or not target_alive() then
						want_since = 0
						return
					end
					local gun, equipped = get_gun()
					if not gun then
						want_since = 0
						return
					end
					if gun ~= gap_gun then
						gap_gun = gun
						gap_reset()
					end
					if not equipped then
						want_since = 0
						local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
						if hum then pcall(function() hum:EquipTool(gun) end) end
						return
					end
					if want_since == 0 then want_since = now end
					local hold = S.auto_delay
					if hold < S.fire_gap then hold = S.fire_gap end
					local since = last_fire_stamp > 0 and last_fire_stamp or S.last_shot
					if now - since < hold then return end
					if S.direct then
						local point, cf0 = direct_point()
						if point and cf0 then
							if fire_gun(gun, cf0, CFrame.new(point)) then
								S.last_shot = now
							end
							return
						end
					end
					if S.force then
						local started = os.clock()
						local origin_cf, aim_cf = resolve_force()
						if not origin_cf or not aim_cf then return end
						origin_cf, aim_cf = compensate_force(origin_cf, aim_cf, started)
						if fire_gun(gun, origin_cf, aim_cf) then
							S.last_shot = now
						end
						return
					end
					local cf = origin_cframe()
					if not cf then return end
					local aim = pick_point(cf.Position, true)
					if not aim then return end
					local aim_cf = compensate_resolve(CFrame.new(aim))
					if fire_gun(gun, cf, aim_cf) then
						S.last_shot = now
					end
				end

				local watch_conns = {}

				local function clear_watch()
					for k = 1, #watch_conns do
						local conn = watch_conns[k]
						pcall(function() conn:Disconnect() end)
					end
					table.clear(watch_conns)
				end

				local function setup_watch()
					clear_watch()
					local m = get_round()
					if m and m.PlayerDataChanged then
						watch_conns[#watch_conns + 1] = m.PlayerDataChanged.Event:Connect(function()
							pcall(refresh_target)
						end)
					end
					watch_conns[#watch_conns + 1] = lp.CharacterAdded:Connect(function()
						task.wait(0.3)
						pcall(refresh_target)
					end)
				end

				local next_role = 0
				local next_hook = 0

				local function tick()
					if force_att and os.clock() - force_stamp > 0.05 then restore_origin() end
					if not S.enabled then return end
					local now = os.clock()
					if now >= next_role then
						next_role = now + 0.2
						refresh_target()
					end
					sample_ping()
					track(now)
					if now >= next_hook then
						next_hook = now + 1
						install_hooks()
						connect_gun_fired()
					end
					auto_step(now)
				end

				local main_conn = run.Heartbeat:Connect(function()
					pcall(tick)
				end)

				local silentToggle = sec:Toggle("Silent Aimbot", "shoot anywhere - the bullet hits the murderer, through walls", function(v)
					S.enabled = v
					getgenv().SILENT_AIM_ACTIVE = v
					if v then
						task.spawn(function()
							pcall(install_hooks)
							pcall(connect_gun_fired)
							pcall(setup_watch)
							pcall(refresh_target)
						end)
					else
						clear_watch()
						track_clear()
					end
				end)

				local predToggle = sec:Toggle("Prediction", "lead the shot by ping and movement", function(v)
					S.predict = v
					if not v then track_clear() end
				end)
				predToggle.Set(true, true)

				local directToggle = sec:Toggle("Direct Shot", "no wall in the way - shoot straight at the murderer", function(v)
					S.direct = v
					if not v then restore_origin() end
				end)
				directToggle.Set(true, true)

				local wallToggle = sec:Toggle("Shoot Through Walls", "bullet starts from a clear spot and passes walls", function(v)
					S.force = v
					if not v then restore_origin() end
				end)
				wallToggle.Set(true, true)

				sec:Slider("Wall Origin", 0, 40, S.stand_off, function(v)
					S.stand_off = v
				end, function(v)
					return v .. " studs"
				end)

				sec:Toggle("Auto Shoot (Silent)", "auto shoot the murderer when you hold the gun", function(v)
					S.auto_on = v
				end)

				sec:Slider("Auto Shoot Delay", 0, 600, 0, function(v)
					S.auto_delay = v / 1000
				end, function(v)
					return v .. "ms"
				end)

				getgenv().SILENT_INSTALL_HOOKS = function()
					pcall(install_hooks)
				end

				getgenv().SILENT_DBG = function()
					local coh, omega = dir_stats(lead_time())
					return {
						target = target_player and target_player.Name or "none",
						ping = EC.ping,
						rtt = EC.rtt,
						jitter = EC.jitter,
						step = EC.step,
						lead = lead_time(),
						coherence = coh,
						omega = omega,
						turn = TR.turn,
						spoof = TR.spoof,
						clearance = TR.clr,
						ground = GC.seen and GC.base or 0,
						jump_learned = JL.seen and JL.v or 0,
						jump_v = TR.jump_v,
						fire_gap = S.fire_gap,
						want_since = want_since,
						conf_point = cloud_confidence(),
						conf_ray = HY.conf,
						gap = TR.gap,
						airborne = TR.air,
						vel_fresh = TR.fresh,
						vel_pos = TR.vel,
					}
				end

				task.spawn(function()
					pcall(install_hooks)
					pcall(connect_gun_fired)
				end)

				getgenv().SILENT_UNLOAD = function()
					S.enabled = false
					S.predict = false
					S.force = false
					S.auto_on = false
					getgenv().SILENT_AIM_ACTIVE = false
					restore_origin()
					clear_watch()
					track_clear()
					if gun_fired_conn then
						pcall(function() gun_fired_conn:Disconnect() end)
						gun_fired_conn = nil
					end
					if main_conn then
						pcall(function() main_conn:Disconnect() end)
						main_conn = nil
					end
					local m = weapon_service
					if m then
						pcall(function() setreadonly(m, false) end)
						if orig_mouse then
							pcall(function() m.GetMouseTargetCFrame = orig_mouse end)
						end
						if orig_screen then
							pcall(function() m.GetTargetPosition = orig_screen end)
						end
					end
				end
				table.insert(connections, { Disconnect = function() pcall(getgenv().SILENT_UNLOAD) end })
			end
			local autoShoot = false
			local lastAutoKill = 0
			connect(RunService.Heartbeat, function()
				if not autoShoot or busy or os.clock() - lastAutoKill < 2 then
					return
				end
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum or hum.Health <= 0 or inLobby(hrp.Position) then
					return
				end
				if not findTool(player, "Gun") or not getMurderer() then
					return
				end
				lastAutoKill = os.clock()
				task.spawn(shootMurderer, false, false)
			end)
			sec:Toggle("Auto Shoot Murderer", "you have the gun - tps next to the murderer only when a wall blocks the shot", function(on)
				autoShoot = on
				lastAutoKill = 0
			end)
			local avoidOn, avoidDist = false, 40
			local AVOID_COOLDOWN, AVOID_SPEED = 0.75, 25
			local avoidLast, avoidGoal = -math.huge, nil
			local avoidBox, avoidScan = nil, 0

			local function flat(v)
				return Vector3.new(v.X, 0, v.Z)
			end

			local function avoidCoinBox()
				if avoidBox and avoidBox:IsDescendantOf(workspace) then return avoidBox end
				avoidBox = nil
				local now = os.clock()
				if now - avoidScan < 2 then return nil end
				avoidScan = now
				for _, d in ipairs(workspace:GetDescendants()) do
					if d.Name == "CoinContainer" then
						avoidBox = d
						break
					end
				end
				return avoidBox
			end

			local function chooseEscape(me, threat, nowDist)
				local box = avoidCoinBox()
				if not box then return nil end
				local awayVec = flat(me - threat)
				local away = awayVec.Magnitude < 0.1 and Vector3.new(1, 0, 0) or awayVec.Unit
				local need = math.max(avoidDist + 15, nowDist + 25)
				local fwd, fwdScore = nil, -math.huge
				local any, anyScore = nil, -math.huge
				local safest, safestDist = nil, -math.huge
				for _, c in ipairs(box:GetChildren()) do
					if c:IsA("BasePart") and c.Name == "Coin_Server" then
						local toCoin = flat(c.Position - me)
						local d = toCoin.Magnitude
						local fromThreat = flat(c.Position - threat).Magnitude
						if fromThreat > safestDist and d >= 8 then
							safest, safestDist = c, fromThreat
						end
						if d >= avoidDist and fromThreat >= need then
							local align = toCoin.Unit:Dot(away)
							local score = fromThreat + d * 0.35 + align * 20
							if align > 0 and score > fwdScore then fwd, fwdScore = c, score end
							if score > anyScore then any, anyScore = c, score end
						end
					end
				end
				return fwd or any or (safestDist > nowDist + 10 and safest or nil)
			end

			connect(RunService.Heartbeat, function(dt)
				if not avoidOn then
					avoidGoal = nil
					return
				end
				local hrp = alive(player)
				if not hrp or inLobby(hrp.Position) or findTool(player, "Knife") then
					avoidGoal = nil
					return
				end
				local _, mRoot = getMurderer()
				if not mRoot or inLobby(mRoot.Position) then
					avoidGoal = nil
					return
				end
				local threat = mRoot.Position
				local dist = flat(hrp.Position - threat).Magnitude
				local now = os.clock()
				if avoidGoal and not avoidGoal.Parent then avoidGoal = nil end
				if dist < avoidDist and now - avoidLast >= AVOID_COOLDOWN
					and (not avoidGoal or flat(avoidGoal.Position - threat).Magnitude < avoidDist + 15) then
					local goal = chooseEscape(hrp.Position, threat, dist)
					if goal then
						avoidGoal = goal
						avoidLast = now
					end
				end
				if not avoidGoal then return end
				if dist >= avoidDist + 10 then
					avoidGoal = nil
					return
				end
				local target = avoidGoal.Position + Vector3.new(0, 3, 0)
				local delta = target - hrp.Position
				if delta.Magnitude < 3 then
					avoidGoal = nil
					return
				end
				local stepLen = math.min(AVOID_SPEED * math.clamp(dt, 0, 0.1), delta.Magnitude)
				hrp.CFrame = CFrame.new(hrp.Position + delta.Unit * stepLen) * hrp.CFrame.Rotation
				hrp.AssemblyLinearVelocity = Vector3.zero
			end)
			sec:Toggle("Avoid Murderer", "run to a safe coin away from the murderer", function(on)
				avoidOn = on
				if not on then avoidGoal = nil end
			end)
			sec:Slider("Avoid Distance", 15, 100, avoidDist, function(v)
				avoidDist = v
			end, function(v)
				return v .. " studs"
			end)
			getgenv().__KRP_SHOOT = function() shootMurderer(true) end
			sec:Button("Shoot Murderer", "take out the gun and fire", function()
				shootMurderer(true)
			end)
		end
    end)
    runBlock("anti kill all", function()
		do
			local on = false
			local lastPos = {}
			local dangerUntil = 0
			local warned = false
			local mode = "V2"
			local savedCF, oldCamType
			local function restore(hrp, hum)
				if hrp and hrp.Parent and savedCF then
					hrp.CFrame = savedCF
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
				if savedCF then
					resumeDesync()
				end
				savedCF = nil
				local cam = workspace.CurrentCamera
				cam.CameraType = oldCamType or Enum.CameraType.Custom
				if hum then
					cam.CameraSubject = hum
				end
			end
			connect(RunService.Heartbeat, function()
				if not on then
					if desync.force then
						desync.force = false
					end
					desync.v2 = false
					if savedCF then
						local c = player.Character
						restore(c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid"))
					end
					return
				end
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local now = os.clock()
				if not hrp or not hum or hum.Health <= 0 or findTool(player, "Knife") or inLobby(hrp.Position) or char:FindFirstChild("Gun") then
					desync.force = false
					desync.v2 = false
					warned = false
					if savedCF then
						restore(hrp, hum)
					end
					return
				end
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player then
						local c = p.Character
						local murd = c and c:FindFirstChild("HumanoidRootPart")
						if murd and findTool(p, "Knife") then
							local pos = murd.Position
							if c:FindFirstChild("Knife") and (pos - hrp.Position).Magnitude < 20 then
								dangerUntil = math.max(dangerUntil, now + 0.8)
							end
							local prev = lastPos[p]
							if prev and (pos - prev).Magnitude > 25 and not inLobby(prev) and not inLobby(pos) then
								dangerUntil = now + 2
							end
							lastPos[p] = pos
						else
							lastPos[p] = nil
						end
					end
				end
				local danger = now < dangerUntil
				if mode == "V1" and danger and not warned then
					warned = true
				elseif not danger then
					warned = false
				end
				if mode == "V2" then
					local pos
					for _, p in ipairs(Players:GetPlayers()) do
						if p ~= player and findTool(p, "Knife") and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
							pos = p.Character.HumanoidRootPart.Position
						end
					end
					desync.murdererPos = pos
					desync.force = true
					desync.v2 = true
					return
				end
				desync.v2 = false
				desync.force = false
				if danger then
					if not savedCF then
						pauseDesync(hrp)
						savedCF = hrp.CFrame
						local cam = workspace.CurrentCamera
						oldCamType = cam.CameraType
						cam.CameraType = Enum.CameraType.Scriptable
					end
					hrp.CFrame = CFrame.new(savedCF.Position + Vector3.new(math.random(-30, 30), math.random(60, 90), math.random(-30, 30)))
					hrp.AssemblyLinearVelocity = Vector3.zero
				elseif savedCF then
					restore(hrp, hum)
				end
			end)
			local sec = addSection(Tabs.Main, "Player", getgenv().__KRP_PLAYER_BOX or Sink)
			sec:Toggle("Anti Kill All", "protection from kill all", function(v)
				on = v
				if not v then
					desync.force = false
				end
			end)
			sec:Segmented("Anti Kill All Mode", { "V1", "V2" }, mode, function(v)
				mode = v
				desync.force = false
				if v ~= "V1" and savedCF then
					local c = player.Character
					restore(c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid"))
				end
			end)
		end
    end)
    runBlock("desync", function()
		do
			local desyncCfg = { on = false, mode = "Random", radius = 80, interval = 30, tracer = true }
			local fakePos
			local nextPick = 0
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			local function randomSpot(center, char)
				rayParams.FilterDescendantsInstances = { char, workspace.CurrentCamera }
				for _ = 1, 8 do
					local a = math.random() * math.pi * 2
					local d = desyncCfg.radius * (0.4 + 0.6 * math.random())
					local p = center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
					local hit = workspace:Raycast(p + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), rayParams)
					if hit then
						return hit.Position + Vector3.new(0, 3, 0)
					end
				end
				return center + Vector3.new(0, 0, desyncCfg.radius)
			end
			connect(RunService.Heartbeat, function()
				if not (desyncCfg.on or desync.force) or desync.pause > 0 then
					return
				end
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not hrp or not hum or hum.Health <= 0 then
					return
				end
				desync.gunHold = char:FindFirstChild("Gun") ~= nil
				if desync.gunHold then
					desync.fakeCF = nil
					return
				end
				local now = os.clock()
				local pos = hrp.Position
				if desync.force and desync.v2 then
					local best, bestDist
					for _ = 1, 6 do
						local dir = Vector3.new(math.random() * 2 - 1, (math.random() * 2 - 1) * 0.4, math.random() * 2 - 1)
						if dir.Magnitude < 0.05 then
							dir = Vector3.xAxis
						end
						local spot = pos + dir.Unit * (40 + math.random() * 60)
						local d = desync.murdererPos and (spot - desync.murdererPos).Magnitude or 999
						if d >= 40 and (not bestDist or d > bestDist) then
							best, bestDist = spot, d
						end
					end
					fakePos = best or pos + Vector3.new(0, 80, 0)
				elseif desyncCfg.mode == "Random" then
					if not fakePos or now >= nextPick then
						fakePos = randomSpot(pos, char)
						nextPick = now + desyncCfg.interval / 1000
					end
				elseif desyncCfg.mode == "Orbit" then
					local a = now * 3
					fakePos = pos + Vector3.new(math.cos(a) * desyncCfg.radius * 0.3, 0, math.sin(a) * desyncCfg.radius * 0.3)
				else
					fakePos = pos + Vector3.new(0, 200, 0)
				end
				local realCF = hrp.CFrame
				desync.real = realCF
				desync.lastFakeAt = os.clock()
				local sentPos = now * 40
				desync.fakeCF = CFrame.new(fakePos) * CFrame.Angles(sentPos * 1.3 + math.random() * 6.28, sentPos + math.random() * 6.28, sentPos * 0.7 + math.random() * 6.28)
				hrp.CFrame = desync.fakeCF
				if sethiddenproperty then
					pcall(sethiddenproperty, hrp, "NetworkIsSleeping", false)
				end
				local v = hrp.AssemblyLinearVelocity
				desync.realVel = v
				if v.Magnitude < 8 then
					local a = math.random() * math.pi * 2
					hrp.AssemblyLinearVelocity = Vector3.new(math.cos(a) * 12, 6, math.sin(a) * 12)
				end
			end)
			pcall(function()
				RunService:UnbindFromRenderStep("KirpichDesync")
			end)
			RunService:BindToRenderStep("KirpichDesync", Enum.RenderPriority.First.Value, function()
				if not desync.real then
					return
				end
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					hrp.CFrame = desync.real
					if desync.realVel then
						hrp.AssemblyLinearVelocity = desync.realVel
					end
				end
				desync.real, desync.realVel = nil, nil
			end)
			local vis = { char = nil, folder = nil, parts = {}, a0 = nil, a1 = nil }
			local function clearGhost()
				if vis.folder then
					vis.folder:Destroy()
				end
				vis.folder, vis.char = nil, nil
				table.clear(vis.parts)
			end
			local function buildGhost(char)
				clearGhost()
				vis.char = char
				vis.folder = create("Model", { Name = "KirpichDesyncGhost", Parent = workspace.CurrentCamera })
				for _, src in ipairs(char:GetChildren()) do
					if src:IsA("BasePart") and src.Name ~= "HumanoidRootPart" then
						local ok, g = pcall(function()
							return src:Clone()
						end)
						if ok and g then
							for _, c in ipairs(g:GetChildren()) do
								if not c:IsA("DataModelMesh") then
									c:Destroy()
								end
							end
							pcall(function()
								g.TextureID = ""
							end)
							g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
							g.Material = Enum.Material.ForceField
							g.Color = accentColor
							g.Transparency = 0.2
							g.Parent = vis.folder
							vis.parts[src] = g
						end
					end
				end
				create("Highlight", {
					Adornee = vis.folder,
					FillTransparency = 1,
					OutlineColor = accentColor,
					OutlineTransparency = 0.3,
					DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
					Parent = vis.folder,
				})
				local function makePoint()
					local pt = create("Part", {
						Anchored = true,
						CanCollide = false,
						CanQuery = false,
						CanTouch = false,
						Transparency = 1,
						Size = Vector3.new(0.1, 0.1, 0.1),
						Parent = vis.folder,
					})
					return create("Attachment", { Parent = pt }), pt
				end
				local a0, p0 = makePoint()
				local a1, p1 = makePoint()
				vis.p0, vis.p1 = p0, p1
				create("Beam", {
					Attachment0 = a0,
					Attachment1 = a1,
					FaceCamera = true,
					LightEmission = 1,
					LightInfluence = 0,
					Width0 = 0.14,
					Width1 = 0.14,
					Segments = 1,
					Color = ColorSequence.new(accentColor),
					Transparency = NumberSequence.new(0.15, 0.55),
					Parent = p0,
				})
			end
			pcall(function()
				RunService:UnbindFromRenderStep("KirpichDesyncVis")
			end)
			RunService:BindToRenderStep("KirpichDesyncVis", Enum.RenderPriority.First.Value + 1, function()
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if not (desyncCfg.on or desync.force) or not desyncCfg.tracer or desync.pause > 0 or desync.gunHold or not hrp or not desync.fakeCF then
					if vis.folder then
						clearGhost()
					end
					return
				end
				if vis.char ~= char or not vis.folder or not vis.folder.Parent then
					buildGhost(char)
				end
				local fakeCF = desync.fakeCF
				local rootCf = hrp.CFrame
				for src, g in pairs(vis.parts) do
					if src.Parent then
						g.CFrame = fakeCF * rootCf:ToObjectSpace(src.CFrame)
					end
				end
				vis.p0.CFrame = rootCf
				vis.p1.CFrame = fakeCF
			end)
			table.insert(connections, {
				Disconnect = function()
					pcall(function()
						RunService:UnbindFromRenderStep("KirpichDesyncVis")
					end)
					clearGhost()
				end,
			})
			table.insert(connections, {
				Disconnect = function()
					pcall(function()
						RunService:UnbindFromRenderStep("KirpichDesync")
					end)
				end,
			})
			local sec = addSection(Tabs.Main, "Desync")
			sec:Toggle("Enable", nil, function(on)
				desyncCfg.on = on
				desync.on = on
				fakePos = nil
				if not on then
					desync.fakeCF = nil
				end
			end)
			local tracerToggle = sec:Toggle("Tracer", "show where others see you", function(on)
				desyncCfg.tracer = on
			end)
			tracerToggle.Set(true, true)
		end
    end)
    runBlock("player actions", function()
		do
			local roleCache = {}
			local roleRemote
			local spectating
			local bangTarget, bangTrack
			local bangStarted = 0
			local function roleOf(p)
				if findTool(p, "Knife") then
					return "Murderer", Color3.fromRGB(255, 80, 80)
				end
				if findTool(p, "Gun") then
					return "Sheriff", Color3.fromRGB(80, 160, 255)
				end
				local role = roleCache[p.Name]
				if role == "Murderer" then
					return "Murderer", Color3.fromRGB(255, 80, 80)
				end
				if role == "Sheriff" or role == "Hero" then
					return role, Color3.fromRGB(80, 160, 255)
				end
				return "Innocent", dimColor
			end
			local function stopSpectate()
				spectating = nil
				local hum = getHumanoid()
				local cam = workspace.CurrentCamera
				if hum and cam then
					cam.CameraType = Enum.CameraType.Custom
					cam.CameraSubject = hum
				end
			end
			local function toggleSpectate(target)
				if spectating == target then
					stopSpectate()
					return
				end
				local char = target.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if not hum then
					return
				end
				spectating = target
				workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
				workspace.CurrentCamera.CameraSubject = hum
			end
			local function stopBang()
				bangTarget = nil
				if bangTrack then
					pcall(function()
						bangTrack:Stop(0.15)
						bangTrack:Destroy()
					end)
					bangTrack = nil
				end
			end
			local function toggleBang(target)
				if bangTarget == target then
					stopBang()
					return
				end
				local targetChar = target.Character
				local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
				local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
				local hum = getHumanoid()
				if not (targetHum and targetHum.Health > 0 and targetRoot and hum and hum.Health > 0) then
					return
				end
				stopBang()
				bangTarget = target
				bangStarted = os.clock()
				local anim = Instance.new("Animation")
				anim.AnimationId = hum.RigType == Enum.HumanoidRigType.R15 and "rbxassetid://5918726674" or "rbxassetid://148840371"
				local ok, track = pcall(function()
					return (hum:FindFirstChildOfClass("Animator") or hum):LoadAnimation(anim)
				end)
				anim:Destroy()
				if ok and track then
					track.Priority = Enum.AnimationPriority.Action4
					track.Looped = true
					track:Play(0.15)
					bangTrack = track
				end
			end
			connect(RunService.Heartbeat, function()
				if spectating then
					local char = spectating.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if not hum or hum.Health <= 0 then
						stopSpectate()
					end
				end
				if not bangTarget then
					return
				end
				local myChar, targetChar = player.Character, bangTarget.Character
				local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
				local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
				local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
				local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
				if not (myRoot and myHum and myHum.Health > 0 and targetRoot and targetHum and targetHum.Health > 0) then
					stopBang()
					return
				end
				local pulse = math.sin((os.clock() - bangStarted) * 12) * 0.18
				myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 1.15 + pulse)
				myRoot.AssemblyLinearVelocity = Vector3.zero
			end)
			local tgt = Tabs.Target
			local selected
			local sec = addSection(tgt, "Player Actions", "Left")
			local function names()
				local list = {}
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player then list[#list + 1] = p.Name end
				end
				table.sort(list)
				return list
			end
			local dd = sec.box:AddDropdown("R_ActionsPlayer", {
				Text = "Player Nickname",
				Values = names(),
				Default = nil,
				AllowNull = true,
				Searchable = true,
				Callback = function(v)
					if type(v) == "table" then
						for name in pairs(v) do v = name break end
					end
					selected = (type(v) == "string" and v ~= "") and v or nil
				end,
			})
			local roleLabel = sec:Label("Role: -")
			local function current()
				local p = selected and Players:FindFirstChild(selected)
				if p and p ~= player then return p end
			end
			local function refreshList()
				pcall(function() dd:SetValues(names()) end)
				if selected and not Players:FindFirstChild(selected) then
					selected = nil
					pcall(function() dd:SetValue(nil) end)
				end
			end
			sec:Button("Fling", "fling the selected player", function()
				local t = current()
				if t and playerFlingAction then playerFlingAction(t) end
			end)
			sec:Button("Spectate", "toggle spectating the selected player", function()
				local t = current()
				if t then toggleSpectate(t) end
			end)
			sec:Button("Bang", "toggle - press again to stop", function()
				local t = current()
				if t then toggleBang(t) end
			end)
			sec:Button("Hug", "toggle - press again to stop", function()
				local t = current()
				if t and playerHugAction then playerHugAction(t) end
			end)
			sec:Button("Kill", "needs the knife or the gun", function()
				local t = current()
				if not t then return end
				if findTool(player, "Knife") and playerKnifeKill then
					playerKnifeKill(t)
				elseif findTool(player, "Gun") and playerGunKill then
					playerGunKill(t)
				end
			end)
			sec:Button("Kill All", "teleport to everyone and stab them", function()
				if not killAllHook or not findTool(player, "Knife") then return end
				killAllHook()
			end)
			connect(Players.PlayerAdded, refreshList)
			connect(Players.PlayerRemoving, function(leaving)
				if spectating == leaving then
					stopSpectate()
				end
				if bangTarget == leaving then
					stopBang()
				end
				task.defer(refreshList)
			end)
			task.spawn(function()
				while gui.Parent do
					if not roleRemote or not roleRemote.Parent then
						roleRemote = game:GetService("ReplicatedStorage"):FindFirstChild("GetPlayerData", true)
					end
					if roleRemote and roleRemote:IsA("RemoteFunction") then
						local ok, data = pcall(roleRemote.InvokeServer, roleRemote)
						if ok and type(data) == "table" then
							local nextRoles = {}
							for name, info in pairs(data) do
								if type(info) == "table" and type(info.Role) == "string" and not info.Dead and not info.Killed then
									nextRoles[name] = info.Role
								end
							end
							roleCache = nextRoles
						end
					end
					local p = selected and Players:FindFirstChild(selected)
					if p then
						local role = roleOf(p)
						roleLabel.SetText("Role: " .. role)
					else
						roleLabel.SetText("Role: -")
					end
					task.wait(1)
				end
			end)
			stopPlayersActions = function()
				stopSpectate()
				stopBang()
			end
		end
    end)
    runBlock("knife throw", function()
		do
			local ka = {
				on = false, auto = false, mode = "Smart", maxDist = 250, fov = 360,
				wall = true, predict = true, lead = 100, sticky = true,
				autoMin = 55, autoRange = 70, speed = 96, lastThrow = 0, cur = nil, dead = false,
			}
			local marker
			local function knifeTool()
				local c = player.Character
				return c and c:FindFirstChild("Knife")
			end
			local function clearPath(from, to, targetChar)
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { player.Character, targetChar }
				return workspace:Raycast(from, to - from, params) == nil
			end
			local function evaluate(p, origin)
				local th, _, tc = alive(p)
				if not th then
					return
				end
				local dist = (th.Position - origin).Magnitude
				if dist > ka.maxDist then
					return
				end
				local cam = workspace.CurrentCamera
				if ka.fov < 360 then
					local dir = (th.Position - cam.CFrame.Position).Unit
					local ang = math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(dir), -1, 1)))
					if ang > ka.fov / 2 then
						return
					end
				end
				local vel = th.AssemblyLinearVelocity
				local point = th.Position
				if ka.predict then
					local flight = dist / ka.speed
					point = point + Vector3.new(vel.X, 0, vel.Z) * flight * (ka.lead / 100)
				end
				local clear = clearPath(origin, point, tc)
				if ka.wall and not clear then
					return
				end
				local chance = (clear and 1 or 0.3) * (1 - 0.5 * dist / ka.maxDist) * (1 - 0.3 * math.min(Vector3.new(vel.X, 0, vel.Z).Magnitude / 32, 1))
				return point, math.clamp(chance, 0, 1), dist, th
			end
			local function pickTarget(origin)
				if ka.sticky and ka.cur then
					local point, chance, dist = evaluate(ka.cur, origin)
					if point then
						return ka.cur, point, chance, dist
					end
				end
				local cam = workspace.CurrentCamera
				local best, bestKey, bp, bc, bd
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= player then
						local point, chance, dist, th = evaluate(p, origin)
						if point and not inLobby(th.Position) then
							local ang = math.acos(math.clamp(cam.CFrame.LookVector:Dot((th.Position - cam.CFrame.Position).Unit), -1, 1))
							local key
							if ka.mode == "Nearest" then
								key = dist
							elseif ka.mode == "Crosshair" then
								key = ang
							elseif ka.mode == "Sheriff" then
								key = (findTool(p, "Gun") and 0 or 10000) + dist
							else
								key = (findTool(p, "Gun") and -1000 or 0) + dist * (1 + ang)
							end
							if not bestKey or key < bestKey then
								best, bestKey, bp, bc, bd = p, key, point, chance, dist
							end
						end
					end
				end
				return best, bp, bc, bd
			end
			local function currentAim()
				local hrp = alive(player)
				if not hrp then
					return
				end
				local p, point = pickTarget(hrp.Position)
				ka.cur = p
				return point
			end
			pcall(function()
				local ws = require(game:GetService("ReplicatedStorage"):WaitForChild("ClientServices", 5):WaitForChild("WeaponService", 5))
				local oldMouse, oldTarget = ws.GetMouseTargetCFrame, ws.GetTargetPosition
				local function redirect(orig)
					return function(...)
						if ka.on and not ka.dead and knifeTool() then
							local ok, point = pcall(currentAim)
							if ok and point then
								return CFrame.new(point)
							end
						end
						return orig(...)
					end
				end
				local myMouse = oldMouse and redirect(oldMouse)
				local myTarget = oldTarget and redirect(oldTarget)
				if myMouse then ws.GetMouseTargetCFrame = myMouse end
				if myTarget then ws.GetTargetPosition = myTarget end
				table.insert(connections, {
					Disconnect = function()
						ka.dead = true
						if ws.GetMouseTargetCFrame == myMouse then ws.GetMouseTargetCFrame = oldMouse end
						if ws.GetTargetPosition == myTarget then ws.GetTargetPosition = oldTarget end
					end,
				})
			end)
			local showMarker = true
			local function setMarker(char, text)
				if not (char and showMarker) then
					if marker then marker.Enabled = false end
					return
				end
				if not marker then
					marker = Instance.new("BillboardGui")
					marker.Name = "KirpichKnifeMarker"
					marker.Size = UDim2.fromOffset(70, 24)
					marker.StudsOffset = Vector3.new(0, 3.5, 0)
					marker.AlwaysOnTop = true
					local l = Instance.new("TextLabel")
					l.Name = "L"
					l.Size = UDim2.fromScale(1, 1)
					l.BackgroundTransparency = 1
					l.TextColor3 = Color3.fromRGB(255, 70, 70)
					l.TextStrokeTransparency = 0
					l.Font = Enum.Font.GothamBold
					l.TextSize = 14
					l.Parent = marker
					marker.Parent = workspace.CurrentCamera
				end
				marker.Adornee = char:FindFirstChild("HumanoidRootPart")
				marker.L.Text = "◎ " .. text
				marker.Enabled = true
			end
			table.insert(connections, { Disconnect = function() if marker then marker:Destroy() end end })
			local function throwKnife(point)
				local knife = knifeTool()
				local events = knife and knife:FindFirstChild("Events")
				local remote = events and events:FindFirstChild("KnifeThrown")
				local handle = knife and knife:FindFirstChild("Handle")
				if not (remote and handle) then
					return false
				end
				ka.lastThrow = os.clock()
				pcall(function()
					remote:FireServer(handle.CFrame, CFrame.new(point))
				end)
				return true
			end
			task.spawn(function()
				while not ka.dead do
					task.wait(0.12)
					pcall(function()
						local hrp = alive(player)
						if not ((ka.on or ka.auto) and hrp and knifeTool()) or inLobby(hrp.Position) then
							ka.cur = nil
							setMarker(nil)
							return
						end
						local p, point, chance, dist = pickTarget(hrp.Position)
						ka.cur = p
						if not p then
							setMarker(nil)
							return
						end
						setMarker(p.Character, math.floor(chance * 100 + 0.5) .. "%")
						if ka.auto and os.clock() - ka.lastThrow >= 1.6 and dist <= ka.autoRange and chance >= ka.autoMin / 100 then
							throwKnife(point)
						end
					end)
				end
			end)
			local sec = addSection(Tabs.Target, "Knife Throw", "Left")
			sec:Toggle("Knife Throw Aimbot", "your thrown knife flies at the best target", function(on)
				ka.on = on
				ka.cur = nil
			end)
			sec:Select("Target Mode", "who the knife aims at", { "Smart", "Crosshair", "Nearest", "Sheriff" }, ka.mode, function(v)
				ka.mode = v
			end)
			sec:Slider("Max Distance", 30, 400, ka.maxDist, function(v) ka.maxDist = v end, function(v) return v .. " st" end)
			sec:Slider("Aim FOV", 10, 360, ka.fov, function(v) ka.fov = v end, function(v) return v .. "°" end)
			sec:Toggle("Wall Check", "skip targets behind walls", function(on) ka.wall = on end).Set(true, true)
			sec:Toggle("Predict Movement", "lead moving targets", function(on) ka.predict = on end).Set(true, true)
			sec:Slider("Lead %", 0, 150, ka.lead, function(v) ka.lead = v end)
			sec:Toggle("Sticky Target", "keep the same target while valid", function(on) ka.sticky = on end).Set(true, true)
			sec:Toggle("Target Marker", "show the chance over the target", function(on)
				showMarker = on
				if not on then setMarker(nil) end
			end).Set(true, true)
			sec:Toggle("Auto Throw", "throws by itself when the chance is high enough", function(on)
				ka.auto = on
			end)
			sec:Slider("Auto Min Chance %", 20, 95, ka.autoMin, function(v) ka.autoMin = v end)
			sec:Slider("Auto Range", 20, 200, ka.autoRange, function(v) ka.autoRange = v end, function(v) return v .. " st" end)
		end
    end)
    runBlock("troll fun", function()
		do
			local UIS = game:GetService("UserInputService")
			local sec = addSection(Tabs.Drone, "Troll Fun")
			local headless, korblox, touchFling, wallHop = false, false, false, false
			local gravOn, gravVal = false, 50
			local origGravity = workspace.Gravity
			local legNames = { "RightUpperLeg", "RightLowerLeg", "RightFoot", "Right Leg" }
			connect(RunService.RenderStepped, function()
				local char = player.Character
				if not char then
					return
				end
				if headless then
					local head = char:FindFirstChild("Head")
					if head then
						head.LocalTransparencyModifier = 1
						for _, d in ipairs(head:GetChildren()) do
							if d:IsA("Decal") then
								d.Transparency = 1
							end
						end
					end
				end
				if korblox then
					for _, n in ipairs(legNames) do
						local part = char:FindFirstChild(n)
						if part then
							part.LocalTransparencyModifier = 1
						end
					end
				end
			end)
			sec:Toggle("Fake Headless", "hides your head (only you see it)", function(on)
				headless = on
				if not on then
					local head = player.Character and player.Character:FindFirstChild("Head")
					if head then
						head.LocalTransparencyModifier = 0
						for _, d in ipairs(head:GetChildren()) do
							if d:IsA("Decal") then
								d.Transparency = 0
							end
						end
					end
				end
			end)
			sec:Toggle("Fake Korblox", "hides your right leg (only you see it)", function(on)
				korblox = on
				if not on and player.Character then
					for _, n in ipairs(legNames) do
						local part = player.Character:FindFirstChild(n)
						if part then
							part.LocalTransparencyModifier = 0
						end
					end
				end
			end)
			sec:Toggle("Gravity", "change world gravity", function(on)
				gravOn = on
				workspace.Gravity = on and gravVal or origGravity
			end)
			sec:Slider("Gravity Value", 0, 300, gravVal, function(v)
				gravVal = v
				if gravOn then
					workspace.Gravity = v
				end
			end)
			sec:Toggle("Touch Fling", "anyone who touches you gets flung", function(on)
				touchFling = on
			end)
			task.spawn(function()
				while true do
					RunService.Heartbeat:Wait()
					if touchFling then
						local hrp = alive(player)
						if hrp then
							local vel = hrp.AssemblyLinearVelocity
							hrp.AssemblyLinearVelocity = vel * 10000 + Vector3.new(0, 10000, 0)
							RunService.RenderStepped:Wait()
							if hrp.Parent then
								hrp.AssemblyLinearVelocity = vel
							end
							RunService.Stepped:Wait()
							if hrp.Parent then
								hrp.AssemblyLinearVelocity = vel + Vector3.new(0, 0.1, 0)
							end
						end
					end
				end
			end)
			local flickAngle = 90
			connect(UIS.JumpRequest, function()
				if not wallHop then
					return
				end
				local hrp, hum = alive(player)
				if not hrp or hum:GetState() ~= Enum.HumanoidStateType.Freefall then
					return
				end
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = { player.Character }
				params.FilterType = Enum.RaycastFilterType.Exclude
				local wall = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * 3, params)
				if not wall then
					return
				end
				hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 50, hrp.AssemblyLinearVelocity.Z)
				if flickAngle > 0 then
					local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
					local n = Vector3.new(wall.Normal.X, 0, wall.Normal.Z)
					local sign = (look.Magnitude > 0.01 and look:Cross(-n).Y < 0) and -1 or 1
					local ang = math.rad(flickAngle) * sign
					local rot = hrp.CFrame - hrp.CFrame.Position
					local pos = hrp.Position
					hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, ang, 0) * rot
					task.delay(0.05, function()
						if hrp.Parent then
							hrp.CFrame = CFrame.new(hrp.Position) * rot
						end
					end)
				end
			end)
			sec:Slider("Flick Angle", 0, 180, flickAngle, function(v)
				flickAngle = v
			end, function(v)
				return v .. "°"
			end)
			sec:Toggle("Wall Hop", "jump again in the air next to a wall", function(on)
				wallHop = on
			end)
			local sg = { on = false, max = 120, accel = 60, cur = 0, air = false, landAt = 0 }
			connect(RunService.Heartbeat, function(dt)
				if not sg.on then
					sg.cur, sg.air = 0, false
					return
				end
				local hrp, hum = alive(player)
				if not hrp then
					return
				end
				local st = hum:GetState()
				if st == Enum.HumanoidStateType.Climbing or st == Enum.HumanoidStateType.Swimming or st == Enum.HumanoidStateType.Seated then
					sg.cur, sg.air = 0, false
					return
				end
				dt = math.min(dt, 0.1)
				local now = os.clock()
				local inAir = st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping
				local md = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
				local moving = md.Magnitude > 0.1
				local v = hrp.AssemblyLinearVelocity
				local flat = Vector3.new(v.X, 0, v.Z)
				if inAir then
					sg.air = true
					if moving then
						sg.cur = math.max(sg.cur, hum.WalkSpeed)
						if flat.Magnitude > sg.cur and flat.Magnitude <= sg.max then
							sg.cur = flat.Magnitude
						end
						sg.cur = math.min(sg.max, sg.cur + sg.accel * dt)
					end
				else
					if sg.air then
						sg.air, sg.landAt = false, now
					end
					if now - sg.landAt > 0.3 then
						sg.cur = 0
					end
				end
				if sg.cur > 0 and moving and (inAir or now - sg.landAt <= 0.25) and flat.Magnitude < sg.cur + 1 then
					local want = md.Unit * sg.cur
					if (flat - want).Magnitude > 0.5 then
						hrp.AssemblyLinearVelocity = Vector3.new(want.X, v.Y, want.Z)
					end
				end
			end)
			sec:Toggle("Speed Glitch", "build speed while moving in the air", function(on)
				sg.on = on
				sg.cur, sg.air = 0, false
			end)
			sec:Slider("Glitch Speed", 30, 300, sg.max, function(v)
				sg.max = v
			end)
			sec:Slider("Glitch Acceleration", 10, 300, sg.accel, function(v)
				sg.accel = v
			end)
			local clickFling = false
			connect(UIS.InputBegan, function(input, gpe)
				if not clickFling or gpe then
					return
				end
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
					return
				end
				local tgt = player:GetMouse().Target
				local model = tgt and tgt:FindFirstAncestorOfClass("Model")
				local p = model and Players:GetPlayerFromCharacter(model)
				if p and p ~= player and playerFlingAction then
					task.spawn(playerFlingAction, p)
				end
			end)
			sec:Toggle("Click Fling", "click a player to fling them", function(on)
				clickFling = on
			end)
			do
				local tpTool, tpConns = nil, {}
				local tpOn = false
				local function dropConns()
					for _, c in ipairs(tpConns) do pcall(function() c:Disconnect() end) end
					tpConns = {}
				end
				local function removeTool()
					dropConns()
					if tpTool then
						pcall(function() tpTool:Destroy() end)
						tpTool = nil
					end
				end
				local function giveTool()
					removeTool()
					local bp = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
					if not bp then return end
					local tool = Instance.new("Tool")
					tool.Name = "Teleport"
					tool.RequiresHandle = false
					tool.CanBeDropped = false
					tool.Parent = bp
					tpTool = tool
					local mouse
					table.insert(tpConns, tool.Equipped:Connect(function(m) mouse = m end))
					table.insert(tpConns, tool.Unequipped:Connect(function() mouse = nil end))
					table.insert(tpConns, tool.Activated:Connect(function()
						if not mouse then return end
						local char = player.Character
						local root = char and char:FindFirstChild("HumanoidRootPart")
						if not root then return end
						root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 4, 0))
					end))
				end
				connect(player.CharacterAdded, function()
					if not tpOn then return end
					task.wait(1)
					if tpOn then giveTool() end
				end)
				sec:Toggle("TP Tool", "gives a Teleport tool: equip and click to teleport to the cursor", function(on)
					tpOn = on
					if on then giveTool() else removeTool() end
				end)
				Library:OnUnload(function()
					tpOn = false
					removeTool()
				end)
			end
			do
				local Debris = game:GetService("Debris")
				local SoundService = game:GetService("SoundService")
				local ContentProvider = game:GetService("ContentProvider")
				local AK_NAME = "Fling AK"
				local AK_DELAY = 0.1
				local AK_RANGE = 1000
				local AK_MAG = 30
				local AK_RELOAD = 2.2
				local AK_ACCENT = Color3.fromRGB(255, 255, 255)
				local AK_CAM_KICK = 0.005
				local AK_GUN_KICK_ADD = 0.4
				local AK_GUN_KICK_MAX = 0.9
				local SHOT_IDS = { 1905367471, 5568116128, 132464216, 165946534 }
				local EMPTY_IDS = { "rbxasset://sounds/switch3.wav", "rbxasset://sounds/switch.wav" }
				local RELOAD_IDS = { "rbxasset://sounds/electronicpingshort.wav", "rbxasset://sounds/switch.wav" }
				local ak = {
					on = false, session = 0, ammo = AK_MAG,
					reloading = false, reloadAlpha = 0, reloadToken = 0,
					tool = nil, equipped = nil,
					camKick = 0, gunKick = 0, lastShot = 0,
					flinging = false, soundsLoading = false,
					sounds = {}, parts = {}, conns = {}, toolConns = {}, hud = nil,
				}

				local function akResolveSound(list)
					for _, id in ipairs(list) do
						local url = type(id) == "number" and ("rbxassetid://" .. id) or id
						local s = Instance.new("Sound")
						s.SoundId = url
						s.Volume = 0
						s.Parent = SoundService
						local loaded = false
						local ok = pcall(function()
							ContentProvider:PreloadAsync({ s }, function(_, status)
								loaded = status == Enum.AssetFetchStatus.Success
							end)
						end)
						s:Destroy()
						if ok and loaded then
							return url
						end
					end
				end
				local function akLoadSounds()
					if ak.soundsLoading or ak.sounds.shot then
						return
					end
					ak.soundsLoading = true
					ak.sounds.shot = akResolveSound(SHOT_IDS)
					ak.sounds.empty = akResolveSound(EMPTY_IDS)
					ak.sounds.reload = akResolveSound(RELOAD_IDS)
					ak.soundsLoading = false
				end
				local function akPlay(key, parent, volume, pitch)
					local url = ak.sounds[key]
					if not url or not parent then
						return
					end
					local s = Instance.new("Sound")
					s.SoundId = url
					s.Volume = volume or 1
					s.PlaybackSpeed = pitch or 1
					s.RollOffMaxDistance = 300
					s.Parent = parent
					s:Play()
					Debris:AddItem(s, 3)
				end

				local function akBuildHud()
					local hudGui = create("ScreenGui", { Name = "KirpichFlingAKHud", ResetOnSpawn = false, DisplayOrder = 150 })
					local parented = false
					if gethui then
						parented = pcall(function() hudGui.Parent = gethui() end)
					end
					if not parented then
						parented = pcall(function() hudGui.Parent = game:GetService("CoreGui") end)
					end
					if not parented then
						hudGui.Parent = player:WaitForChild("PlayerGui")
					end
					local frame = create("Frame", {
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, -24, 1, -90),
						Size = UDim2.fromOffset(170, 62),
						BackgroundColor3 = Color3.fromRGB(16, 16, 18),
						BackgroundTransparency = 0.15,
						Visible = false,
						Parent = hudGui,
					})
					create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = frame })
					create("UIStroke", { Color = AK_ACCENT, Transparency = 0.6, Parent = frame })
					create("TextLabel", {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(12, 6),
						Size = UDim2.new(1, -24, 0, 14),
						Font = Enum.Font.GothamBold,
						TextSize = 11,
						TextColor3 = Color3.fromRGB(140, 140, 145),
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = string.upper(AK_NAME),
						Parent = frame,
					})
					local ammoLabel = create("TextLabel", {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(12, 20),
						Size = UDim2.new(1, -24, 0, 30),
						Font = Enum.Font.GothamBlack,
						TextSize = 26,
						TextColor3 = AK_ACCENT,
						TextXAlignment = Enum.TextXAlignment.Left,
						RichText = true,
						Parent = frame,
					})
					local bar = create("Frame", {
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, 12, 1, -7),
						Size = UDim2.new(1, -24, 0, 3),
						BackgroundColor3 = Color3.fromRGB(40, 40, 44),
						BorderSizePixel = 0,
						Parent = frame,
					})
					create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
					local fill = create("Frame", {
						Size = UDim2.fromScale(0, 1),
						BackgroundColor3 = AK_ACCENT,
						BorderSizePixel = 0,
						Parent = bar,
					})
					create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
					local reloadButton = create("TextButton", {
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, -24, 1, -158),
						Size = UDim2.fromOffset(90, 34),
						BackgroundColor3 = Color3.fromRGB(16, 16, 18),
						BackgroundTransparency = 0.15,
						Font = Enum.Font.GothamBold,
						TextSize = 12,
						TextColor3 = AK_ACCENT,
						Text = "RELOAD",
						Visible = false,
						Parent = hudGui,
					})
					create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = reloadButton })
					return { gui = hudGui, frame = frame, ammo = ammoLabel, fill = fill, reloadButton = reloadButton }
				end
				local function akUpdateHud()
					local hud = ak.hud
					if not hud or not hud.gui.Parent then
						return
					end
					local col = ak.ammo <= 5 and "#FF5A4F" or "#FFFFFF"
					hud.ammo.Text = string.format('<font color="%s">%d</font> <font color="#787878" size="16">/ ∞</font>', col, ak.ammo)
					local show = ak.equipped ~= nil
					hud.frame.Visible = show
					hud.reloadButton.Visible = show and UIS.TouchEnabled
				end
				local function akSetFill(a)
					if ak.hud and ak.hud.fill.Parent then
						ak.hud.fill.Size = UDim2.fromScale(a, 1)
					end
				end

				local function akFinishReload(token)
					if token ~= ak.reloadToken then
						return
					end
					ak.ammo = AK_MAG
					ak.reloading = false
					ak.reloadAlpha = 0
					akSetFill(0)
					akUpdateHud()
				end
				local function akStartReload()
					if ak.reloading or ak.ammo >= AK_MAG or not ak.equipped then
						return
					end
					ak.reloading = true
					ak.reloadToken += 1
					local token = ak.reloadToken
					local session = ak.session
					local handle = ak.equipped:FindFirstChild("Handle")
					akPlay("reload", handle, 0.8, 0.8)
					task.spawn(function()
						local started = os.clock()
						while ak.on and session == ak.session and token == ak.reloadToken do
							local a = (os.clock() - started) / AK_RELOAD
							if a >= 1 then
								break
							end
							ak.reloadAlpha = a
							akSetFill(a)
							if a > 0.55 and not ak.parts.clicked then
								ak.parts.clicked = true
								akPlay("reload", handle, 0.9, 1.2)
							end
							if a > 0.88 and not ak.parts.racked then
								ak.parts.racked = true
								akPlay("empty", handle, 1, 0.9)
							end
							RunService.Heartbeat:Wait()
						end
						ak.parts.clicked, ak.parts.racked = false, false
						if ak.on and session == ak.session and token == ak.reloadToken then
							akFinishReload(token)
						end
					end)
				end
				local function akCancelReload()
					ak.reloadToken += 1
					ak.reloading = false
					ak.reloadAlpha = 0
					ak.parts.clicked, ak.parts.racked = false, false
					akSetFill(0)
				end

				local function akAimRay()
					local cam = workspace.CurrentCamera
					local pos = UIS:GetMouseLocation()
					if UIS.TouchEnabled and not UIS.MouseEnabled then
						pos = cam.ViewportSize / 2
					end
					return cam:ViewportPointToRay(pos.X, pos.Y)
				end
				local function akTracer(from, to)
					local dist = (to - from).Magnitude
					local beam = create("Part", {
						Anchored = true,
						CanCollide = false,
						CanQuery = false,
						CanTouch = false,
						CastShadow = false,
						Material = Enum.Material.Neon,
						Color = Color3.fromRGB(255, 235, 170),
						Size = Vector3.new(0.07, 0.07, dist),
						CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2),
						Parent = workspace.CurrentCamera,
					})
					tween(beam, 0.08, { Transparency = 1 })
					Debris:AddItem(beam, 0.1)
				end
				local function akMuzzleFlash()
					local muzzle = ak.parts.muzzle
					if not muzzle or not muzzle.Parent then
						return
					end
					local flash = create("Part", {
						Anchored = true,
						CanCollide = false,
						CanQuery = false,
						CanTouch = false,
						Material = Enum.Material.Neon,
						Color = Color3.fromRGB(255, 210, 120),
						Shape = Enum.PartType.Ball,
						Size = Vector3.one * math.random(6, 11) / 10,
						CFrame = muzzle.CFrame,
						Parent = workspace.CurrentCamera,
					})
					create("PointLight", { Color = Color3.fromRGB(255, 190, 90), Brightness = 4, Range = 12, Parent = flash })
					tween(flash, 0.06, { Transparency = 1, Size = Vector3.one * 0.2 })
					Debris:AddItem(flash, 0.08)
				end

				local function akShoot(handle)
					local char = player.Character
					if not char or ak.reloading then
						return
					end
					local now = os.clock()
					if now - ak.lastShot < AK_DELAY then
						return
					end
					if ak.ammo <= 0 then
						ak.lastShot = now + 0.25
						akPlay("empty", handle, 0.8, 1)
						akStartReload()
						return
					end
					ak.lastShot = now
					ak.ammo -= 1
					akUpdateHud()
					ak.camKick += AK_CAM_KICK
					ak.gunKick = math.min(ak.gunKick + AK_GUN_KICK_ADD, AK_GUN_KICK_MAX)
					akPlay("shot", handle, 1.1, 0.95 + math.random() * 0.12)
					akMuzzleFlash()

					local ray = akAimRay()
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { char, workspace.CurrentCamera }
					local result = workspace:Raycast(ray.Origin, ray.Direction * AK_RANGE, params)
					local hitPos = result and result.Position or (ray.Origin + ray.Direction * AK_RANGE)
					local from = ak.parts.muzzle and ak.parts.muzzle.Position or handle.Position
					akTracer(from, hitPos)

					if result and playerFlingAction and not ak.flinging then
						local model = result.Instance:FindFirstAncestorOfClass("Model")
						local victim = model and Players:GetPlayerFromCharacter(model)
						if victim and victim ~= player then
							ak.flinging = true
							task.spawn(function()
								pcall(playerFlingAction, victim)
								ak.flinging = false
							end)
						end
					end

					if ak.ammo <= 0 then
						task.delay(0.15, akStartReload)
					end
				end

				local function akAddPart(tool, base, name, size, color, offset, material, shape)
					local p = Instance.new("Part")
					p.Name = name
					p.Size = size
					p.Color = color
					p.Material = material or Enum.Material.Metal
					p.CanCollide = false
					p.Massless = true
					p.TopSurface = Enum.SurfaceType.Smooth
					p.BottomSurface = Enum.SurfaceType.Smooth
					if shape then
						p.Shape = shape
					end
					p.CFrame = base.CFrame * offset
					p.Parent = tool
					local w = Instance.new("Weld")
					w.Part0 = base
					w.Part1 = p
					w.C0 = offset
					w.Parent = p
					return p, w
				end

				local function akDropToolConns()
					for _, c in ipairs(ak.toolConns) do
						pcall(function() c:Disconnect() end)
					end
					table.clear(ak.toolConns)
				end
				local function akMakeTool()
					local tool = Instance.new("Tool")
					tool.Name = AK_NAME
					tool.RequiresHandle = true
					tool.CanBeDropped = false
					tool.ToolTip = "hold to spray, R to reload"
					local baseGrip = CFrame.new(0, -0.25, 0.3)
					tool.Grip = baseGrip

					local body = Color3.fromRGB(22, 22, 26)
					local steel = Color3.fromRGB(96, 98, 108)
					local soft = Color3.fromRGB(40, 40, 46)
					local smoothMat = Enum.Material.SmoothPlastic
					local metal = Enum.Material.Metal
					local neon = Enum.Material.Neon
					local cyl = Enum.PartType.Cylinder
					local ball = Enum.PartType.Ball
					local alongZ = CFrame.Angles(0, math.rad(90), 0)
					local upright = CFrame.Angles(0, 0, math.rad(90))

					local handle = Instance.new("Part")
					handle.Name = "Handle"
					handle.Size = Vector3.new(0.3, 0.3, 2)
					handle.Transparency = 1
					handle.CanCollide = false
					handle.Parent = tool

					local function add(name, size, color, offset, material, shape)
						return akAddPart(tool, handle, name, size, color, offset, material, shape)
					end
					local function tube(name, length, dia, y, z, color, material)
						return add(name, Vector3.new(length, dia, dia), color, CFrame.new(0, y, z) * alongZ, material or smoothMat, cyl)
					end
					local function orb(name, dia, y, z, color, material)
						return add(name, Vector3.one * dia, color, CFrame.new(0, y, z), material or smoothMat, ball)
					end

					tube("Body", 2.3, 0.44, 0.05, 0.2, body)
					orb("BodyRear", 0.44, 0.05, 1.35, body)
					orb("BodyFront", 0.44, 0.05, -0.95, body)
					tube("Shroud", 1.1, 0.3, 0.05, -1.65, soft)
					tube("Barrel", 1.5, 0.12, 0.05, -2.3, steel, metal)
					tube("MuzzleTip", 0.22, 0.2, 0.05, -2.98, body, metal)
					tube("RingA", 0.04, 0.34, 0.05, -1.25, AK_ACCENT, neon)
					tube("RingB", 0.04, 0.34, 0.05, -2.1, AK_ACCENT, neon)
					add("TopLine", Vector3.new(0.04, 0.03, 1.9), AK_ACCENT, CFrame.new(0, 0.28, 0.1), neon)
					tube("Stock", 0.9, 0.2, 0.0, 1.95, soft)
					tube("StockPad", 0.08, 0.42, 0.0, 2.45, body)
					add("Grip", Vector3.new(0.78, 0.2, 0.2), soft, CFrame.new(0, -0.5, 0.6) * CFrame.Angles(math.rad(-14), 0, 0) * upright, smoothMat, cyl)

					local mag, magWeld = add("Magazine", Vector3.new(0.85, 0.22, 0.22), body, CFrame.new(0, -0.5, -0.35) * CFrame.Angles(math.rad(8), 0, 0) * upright, smoothMat, cyl)
					akAddPart(tool, mag, "MagWindow", Vector3.new(0.5, 0.02, 0.06), AK_ACCENT, CFrame.new(0, 0, 0.115), neon)
					local _, boltWeld = add("Bolt", Vector3.new(0.04, 0.05, 0.4), AK_ACCENT, CFrame.new(0.23, 0.1, -0.05), neon)
					local led = orb("AmmoLed", 0.07, 0.27, 0.8, Color3.fromRGB(80, 255, 130), neon)

					local muzzle = Instance.new("Part")
					muzzle.Name = "Muzzle"
					muzzle.Size = Vector3.new(0.1, 0.1, 0.1)
					muzzle.Transparency = 1
					muzzle.CanCollide = false
					muzzle.Massless = true
					muzzle.CFrame = handle.CFrame * CFrame.new(0, 0.05, -3.2)
					muzzle.Parent = tool
					local mw = Instance.new("Weld")
					mw.Part0, mw.Part1 = handle, muzzle
					mw.C0 = CFrame.new(0, 0.05, -3.2)
					mw.Parent = muzzle

					local magBase = magWeld.C0
					local boltBase = boltWeld.C0
					local holding = false

					local function smooth(x)
						x = math.clamp(x, 0, 1)
						return x * x * (3 - 2 * x)
					end

					table.insert(ak.toolConns, RunService.RenderStepped:Connect(function(dt)
						if not tool.Parent then
							return
						end
						ak.gunKick = math.max(ak.gunKick - dt * 9, 0)
						local a = ak.reloadAlpha
						local tilt, magDrop, boltBack = 0, 0, 0
						if ak.reloading then
							tilt = smooth(a / 0.2) - smooth((a - 0.85) / 0.15)
							if a < 0.35 then
								magDrop = smooth(a / 0.35)
							elseif a < 0.55 then
								magDrop = 1
							else
								magDrop = 1 - smooth((a - 0.55) / 0.25)
							end
							if a > 0.82 and a < 0.95 then
								boltBack = math.sin((a - 0.82) / 0.13 * math.pi)
							end
						end
						tool.Grip = baseGrip
							* CFrame.new(0, ak.gunKick * 0.02, ak.gunKick * 0.18 + tilt * 0.1)
							* CFrame.Angles(math.rad(ak.gunKick * 4 - tilt * 38), math.rad(tilt * 12), math.rad(tilt * 24))
						magWeld.C0 = CFrame.new(0, -magDrop * 1.2, 0) * magBase
						mag.Transparency = magDrop > 0.85 and 0.5 or 0
						boltWeld.C0 = boltBase * CFrame.new(0, 0, boltBack * 0.55)
						if ak.reloading then
							led.Color = Color3.fromRGB(255, 205, 70)
						elseif ak.ammo <= 5 then
							led.Color = Color3.fromRGB(255, 80, 70)
						else
							led.Color = Color3.fromRGB(80, 255, 130)
						end
					end))
					table.insert(ak.toolConns, tool.Equipped:Connect(function()
						ak.equipped = tool
						ak.parts.muzzle = muzzle
						akUpdateHud()
					end))
					table.insert(ak.toolConns, tool.Unequipped:Connect(function()
						holding = false
						if ak.equipped == tool then
							ak.equipped = nil
						end
						akCancelReload()
						akUpdateHud()
					end))
					table.insert(ak.toolConns, tool.Activated:Connect(function()
						if holding then
							return
						end
						holding = true
						local session = ak.session
						task.spawn(function()
							while holding and ak.on and session == ak.session and tool.Parent == player.Character do
								akShoot(handle)
								task.wait(AK_DELAY)
							end
							holding = false
						end)
					end))
					table.insert(ak.toolConns, tool.Deactivated:Connect(function()
						holding = false
					end))
					table.insert(ak.toolConns, tool.Destroying:Connect(function()
						if ak.equipped == tool then
							ak.equipped = nil
							akUpdateHud()
						end
					end))
					return tool
				end

				local function akRemoveTool()
					akDropToolConns()
					ak.equipped = nil
					local backpack = player:FindFirstChildOfClass("Backpack")
					for _, holder in ipairs({ player.Character, backpack }) do
						local t = holder and holder:FindFirstChild(AK_NAME)
						if t then
							pcall(function() t:Destroy() end)
						end
					end
				end
				local function akGiveTool()
					if not ak.on then
						return
					end
					local char = player.Character
					local backpack = player:FindFirstChildOfClass("Backpack")
					if not char or not backpack then
						return
					end
					if backpack:FindFirstChild(AK_NAME) or char:FindFirstChild(AK_NAME) then
						return
					end
					akDropToolConns()
					akMakeTool().Parent = backpack
				end

				local function akStart()
					if ak.on then
						return
					end
					ak.on = true
					ak.session += 1
					local session = ak.session
					ak.ammo = AK_MAG
					ak.camKick, ak.gunKick = 0, 0
					ak.flinging = false
					ak.hud = akBuildHud()
					task.spawn(akLoadSounds)
					table.insert(ak.conns, player.CharacterAdded:Connect(function()
						akCancelReload()
						ak.ammo = AK_MAG
						ak.equipped = nil
						akUpdateHud()
						task.wait(0.5)
						if ak.on and session == ak.session then
							akGiveTool()
						end
					end))
					table.insert(ak.conns, UIS.InputBegan:Connect(function(input, gp)
						if not gp and input.KeyCode == Enum.KeyCode.R then
							akStartReload()
						end
					end))
					table.insert(ak.conns, ak.hud.reloadButton.Activated:Connect(akStartReload))
					table.insert(ak.conns, RunService.RenderStepped:Connect(function(dt)
						ak.camKick = ak.camKick * math.exp(-dt * 12)
						if ak.camKick > 0.0005 then
							local cam = workspace.CurrentCamera
							cam.CFrame = cam.CFrame * CFrame.Angles(ak.camKick, 0, 0)
						end
					end))
					local lastCheck = 0
					table.insert(ak.conns, RunService.Heartbeat:Connect(function()
						local now = os.clock()
						if now - lastCheck < 1 then
							return
						end
						lastCheck = now
						if alive(player) then
							akGiveTool()
						end
					end))
					akGiveTool()
					akUpdateHud()
				end
				local function akStop()
					if not ak.on then
						return
					end
					ak.on = false
					ak.session += 1
					akCancelReload()
					for _, c in ipairs(ak.conns) do
						pcall(function() c:Disconnect() end)
					end
					table.clear(ak.conns)
					akRemoveTool()
					if ak.hud and ak.hud.gui then
						pcall(function() ak.hud.gui:Destroy() end)
					end
					ak.hud = nil
					ak.flinging = false
				end

				sec:Toggle("Fling AK", "gives a gun: every player you hit gets flung (Kirpich fling)", function(on)
					if on then akStart() else akStop() end
				end)
				Library:OnUnload(akStop)
			end
		end
    end)
    runBlock("coin autofarm", function()
        local Players = game:GetService("Players")
        local RS = game:GetService("ReplicatedStorage")
        local RunService = game:GetService("RunService")
        local CollectionService = game:GetService("CollectionService")
        local Stats = game:GetService("Stats")
        local VirtualUser = game:GetService("VirtualUser")
        local lp = Players.LocalPlayer
        local genv = getgenv()
        local ROT = CFrame.Angles(-math.pi / 2, 0, 0)

        local on, autoReset, autoKill, autoFling, murderCheck, safeStart = false, false, false, false, false, false
        local mode = "Basic"
        local maxSpeed = 23
        local bagHandled = false
        local roundActive = false
        local target = nil
        local lastY = nil
        local collectedIds, collectedCount = {}, 0
        local holding, holdPos, underPos = false, nil, nil
        local noCollideBackup = {}
        local touchBackup = {}
        local resumeAt = 0
        local pingSmooth, pingAt = 0, 0
        local roundModule
        local mapModel, mapCF, mapSize
        local lastCollect = 0
        local conns = {}
        local TP = {
            coin = nil, pos = nil, from = nil, at = 0, settle = 0, poke = 0,
            slow = 1, miss = 0, fails = 0, pause = 0, deep = 2.5,
            ban = setmetatable({}, { __mode = "k" }),
        }
        genv.AUTOFARM_HOLD = false

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.IgnoreWater = true
        rayParams.RespectCanCollide = true

        local function getHRP()
            local c = lp.Character
            return c and c:FindFirstChild("HumanoidRootPart")
        end

        local function playerData()
            if not roundModule then
                local ok, res = pcall(function()
                    local mods = RS:FindFirstChild("Modules")
                    local m = mods and mods:FindFirstChild("CurrentRoundClient")
                    return m and require(m)
                end)
                if ok and type(res) == "table" then roundModule = res end
            end
            return roundModule and roundModule.PlayerData
        end

        local function myRole()
            local pd = playerData()
            local me = type(pd) == "table" and pd[lp.Name]
            return me and me.Role
        end

        local function isAlive()
            local char = lp.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return false end
            local pd = playerData()
            if type(pd) == "table" then
                local me = pd[lp.Name]
                if not me or not me.Role or me.Dead then return false end
            end
            return true
        end

        local function bagFull()
            local gui = lp:FindFirstChild("PlayerGui")
            local main = gui and gui:FindFirstChild("MainGUI")
            local game_ = main and main:FindFirstChild("Game")
            local bags = game_ and game_:FindFirstChild("CoinBags")
            local cont = bags and bags:FindFirstChild("Container")
            if not cont then return false end
            local full = false
            for _, f in ipairs(cont:GetChildren()) do
                if f:IsA("Frame") and f.Visible then
                    local fl = f:FindFirstChild("Full")
                    if not fl or not fl.Visible then return false end
                    full = true
                end
            end
            return full
        end

        local function updateHold()
            genv.AUTOFARM_HOLD = (on and autoKill) and not bagHandled
        end

        local function setCanTouch(restore)
            if restore then
                for part in pairs(touchBackup) do
                    if part.Parent then part.CanTouch = true end
                end
                table.clear(touchBackup)
                return
            end
            local char = lp.Character
            if not char then return end
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") and d.CanTouch then
                    touchBackup[d] = true
                    d.CanTouch = false
                end
            end
        end

        local function resetRound()
            collectedIds = {}
            collectedCount = 0
            bagHandled = false
            roundActive = false
            target = nil
            TP.coin, TP.pos, TP.from = nil, nil, nil
            TP.slow, TP.miss, TP.fails, TP.pause = 1, 0, 0, 0
            table.clear(TP.ban)
            setCanTouch(true)
            updateHold()
        end

        local function setNoclip(state)
            local char = lp.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if state then
                if not char then return end
                if not holding then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then holdPos = hrp.Position end
                end
                holding = true
                if hum then pcall(function() hum.PlatformStand = true end) end
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("BasePart") and d.CanCollide then
                        if noCollideBackup[d] == nil then noCollideBackup[d] = d.CanCollide end
                        d.CanCollide = false
                    end
                end
            else
                holding = false
                setCanTouch(true)
                if hum then pcall(function() hum.PlatformStand = false end) end
                for part, was in pairs(noCollideBackup) do
                    if part and part.Parent then pcall(function() part.CanCollide = was end) end
                end
                noCollideBackup = {}
            end
        end

        local function placeAt(part, pos)
            pcall(function()
                part.CFrame = CFrame.new(pos) * ROT
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end)
        end

        local function groundRay(pos)
            local filter = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character then filter[#filter + 1] = p.Character end
            end
            rayParams.FilterDescendantsInstances = filter
            return workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -60, 0), rayParams)
        end

        local function restoreStanding()
            local hrp = getHRP()
            local hum = hrp and hrp.Parent:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then return end
            local hit = groundRay(holdPos or hrp.Position) or (holdPos and groundRay(hrp.Position))
            local pos = (hit and (hit.Position + Vector3.new(0, hum.HipHeight + hrp.Size.Y / 2 + 0.2, 0))) or holdPos
            if not pos then return end
            local look = hrp.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            pcall(function()
                hrp.CFrame = (flat.Magnitude > 0.05) and CFrame.lookAt(pos, pos + flat) or CFrame.new(pos)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end

        local function stopFarm()
            TP.coin = nil
            if not holding then return end
            restoreStanding()
            underPos = nil
            setNoclip(false)
        end

        local function coinValid(part)
            return part and part.Parent and part:IsA("BasePart")
                and not part:GetAttribute("Collected") and not part:GetAttribute("Delete")
        end

        local function otherPositions()
            local list = {}
            for _, p in ipairs(Players:GetPlayers()) do
                local char = (p ~= lp) and p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then list[#list + 1] = hrp.Position end
            end
            return list
        end

        local function crowded(pos, myDist, others)
            for _, op in ipairs(others) do
                local d = (op - pos).Magnitude
                if d < 6 and d < myDist then return true end
            end
            return false
        end

        local function nearestCoin(origin, coins)
            local others = otherPositions()
            local best, bestScore = nil, math.huge
            for _, c in ipairs(coins) do
                local d = (c.Position - origin).Magnitude
                if crowded(c.Position, d, others) then d = d + 1000 end
                if d < bestScore then bestScore, best = d, c end
            end
            return best
        end

        local cachedMurd, cachedMurdAt = nil, 0
        local function murdererPart()
            local now = os.clock()
            if (now - cachedMurdAt) < 0.25 then return cachedMurd end
            cachedMurdAt, cachedMurd = now, nil
            local pd = playerData()
            if type(pd) ~= "table" then return nil end
            local me, char = pd[lp.Name], lp.Character
            if me then
                if me.Role == "Murderer" or me.Role == "Zombie" then return nil end
                if char and char:GetAttribute("Zombie") == true then return nil end
            end
            local mine = getHRP()
            local bestD = math.huge
            for name, data in pairs(pd) do
                local plr = Players:FindFirstChild(name)
                local pchar = plr and plr.Character
                local bad = type(data) == "table" and (data.Role == "Murderer" or data.Role == "Zombie"
                    or (pchar and pchar:GetAttribute("Zombie") == true))
                if bad and not data.Dead and name ~= lp.Name then
                    local hrp = pchar and pchar:FindFirstChild("HumanoidRootPart")
                    local hum = pchar and pchar:FindFirstChildOfClass("Humanoid")
                    local alive = hrp and (hum and hum.Health > 0 or not hum)
                    if alive then
                        local d = mine and (hrp.Position - mine.Position).Magnitude or 0
                        if d < bestD then cachedMurd, bestD = hrp, d end
                    end
                end
            end
            return cachedMurd
        end

        local function flatDist(a, b)
            return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
        end

        local function pickCoin(origin, coins, murderPos)
            if not murderCheck or not murderPos then return nearestCoin(origin, coins) end
            local others = otherPositions()
            local farthest, farthestD = nil, -1
            local best, bestScore = nil, math.huge
            for _, c in ipairs(coins) do
                local md = flatDist(c.Position, murderPos)
                if md > farthestD then farthestD, farthest = md, c end
                if md >= 40 then
                    local d = (c.Position - origin).Magnitude
                    if crowded(c.Position, d, others) then d = d + 1000 end
                    if d < bestScore then bestScore, best = d, c end
                end
            end
            if best then return best end
            if farthest and farthestD >= 24 then return farthest end
            return nil
        end

        local function coinOk(coin, murderPos)
            if not coinValid(coin) then return false end
            if murderCheck and murderPos and flatDist(coin.Position, murderPos) < 24 then return false end
            return true
        end

        local function avoidPath(from, goal, murderPos)
            if not murderCheck or not murderPos then return goal end
            local md = flatDist(from, murderPos)
            if md >= 40 then return goal end
            local away = Vector3.new(from.X - murderPos.X, 0, from.Z - murderPos.Z)
            away = (away.Magnitude < 0.1 and Vector3.new(1, 0, 0) or away).Unit
            local toGoal = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
            local len = toGoal.Magnitude
            if len < 0.1 then return goal end
            local weight = 1 + ((1 - (md / 40)) * 2)
            local dir = toGoal.Unit + (away * weight)
            local np = from + ((dir.Magnitude < 0.1 and away or dir.Unit) * len)
            return Vector3.new(np.X, goal.Y, np.Z)
        end

        local function touchParts(coin)
            local list, seen = {}, {}
            local function add(p)
                if p and not seen[p] and p:IsA("BasePart") and p:FindFirstChildOfClass("TouchTransmitter") then
                    seen[p] = true
                    list[#list + 1] = p
                end
            end
            add(coin)
            for _, c in ipairs(coin:GetChildren()) do add(c) end
            local parent = coin.Parent
            if parent then
                if parent:IsA("BasePart") then add(parent) end
                for _, c in ipairs(parent:GetChildren()) do add(c) end
            end
            if #list == 0 then list[1] = coin end
            return list
        end

        local function collect(coin)
            if type(firetouchinterest) ~= "function" then return end
            if not coin or not coin.Parent then return end
            local now = os.clock()
            if (now - lastCollect) < 0.05 then return end
            lastCollect = now
            local hrp = getHRP()
            if not hrp then return end
            for _, part in ipairs(touchParts(coin)) do
                pcall(firetouchinterest, hrp, part, 0)
                pcall(firetouchinterest, hrp, part, 1)
            end
        end

        local function speedNow()
            local now = os.clock()
            local dt = now - pingAt
            if dt >= 0.25 then
                pingAt = now
                local ok, p = pcall(function()
                    return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
                end)
                p = math.clamp((ok and tonumber(p)) or lp:GetNetworkPing(), 0, 1)
                if p > pingSmooth then
                    pingSmooth = p
                else
                    pingSmooth = pingSmooth + ((p - pingSmooth) * math.min(dt, 1))
                end
            end
            return math.min(maxSpeed, 23 / (1 + (math.max(pingSmooth - 0.1, 0) * 1.5)))
        end

        local function stepToward(hrp, goal, dt)
            local delta = goal - hrp.Position
            local dist = delta.Magnitude
            local np
            if dist > 0.1 then
                local sp = (mode == "Teleport") and 23 or speedNow()
                np = hrp.Position + (delta.Unit * math.min(sp * dt, dist))
            else
                np = goal
            end
            local cf = CFrame.new(np)
            if mode ~= "Basic" then cf = cf * ROT end
            pcall(function()
                hrp.CFrame = cf
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end

        local function safeStartMove(hrp, dt)
            if not underPos then
                if not (mapModel and mapModel.Parent) then
                    mapModel = nil
                    for _, m in ipairs(workspace:GetChildren()) do
                        if m:IsA("Model") and (m:GetAttribute("MapID") ~= nil or m:FindFirstChild("CoinContainer")) then
                            mapModel = m
                            mapCF, mapSize = m:GetBoundingBox()
                            break
                        end
                    end
                    if not mapModel then return false end
                end
                local rel = mapCF:PointToObjectSpace(hrp.Position)
                if math.abs(rel.X) > (mapSize.X / 2) or math.abs(rel.Z) > (mapSize.Z / 2) then return false end
                local base = (holding and holdPos) or hrp.Position
                local hit = groundRay(base)
                local y = math.max(mapCF.Position.Y - (mapSize.Y / 2), ((hit and hit.Position.Y) or base.Y) - 60) - 8
                underPos = Vector3.new(base.X, y, base.Z)
            end
            setNoclip(true)
            stepToward(hrp, underPos, dt)
            return true
        end

        local function tpCheck(now, murderPos)
            if now >= TP.settle then setCanTouch(true) end
            local c = TP.coin
            if not c then return end
            local valid = coinValid(c) and true or false
            if (valid and murderPos and not coinOk(c, murderPos)) or not valid then
                if not valid and now >= TP.settle then
                    TP.from, TP.at = TP.pos, now
                    TP.miss = 0
                    TP.slow = math.max(1, TP.slow * 0.9)
                end
                TP.coin = nil
            elseif (now - TP.settle) > 1.2 then
                TP.ban[c] = now + 6
                if TP.deep > 0 then
                    TP.deep = math.max(0, TP.deep - 1)
                else
                    TP.miss = TP.miss + 1
                    TP.fails = TP.fails + 1
                    TP.slow = math.min(4, TP.slow * 1.5)
                    if TP.miss >= 2 then
                        TP.pause = (TP.fails >= 4) and math.huge or (now + 6)
                    end
                end
                TP.coin = nil
            end
        end

        local function tpStep(hrp, coins, murderPos)
            local now = os.clock()
            tpCheck(now, murderPos)
            local c = TP.coin
            if c then
                setNoclip(true)
                placeAt(hrp, TP.pos)
                if now >= TP.settle and now >= TP.poke then
                    TP.poke = now + 0.2
                    collect(c)
                end
                return
            end
            local pick
            if now >= TP.pause then
                local list = {}
                for _, coin in ipairs(coins) do
                    local b = TP.ban[coin]
                    if not b or now >= b then list[#list + 1] = coin end
                end
                pick = pickCoin(TP.from or hrp.Position, list, murderPos)
            end
            if pick then
                local cp = pick.Position
                local ready = (TP.from and (TP.at + (math.max(0.4, (cp - TP.from).Magnitude / 23) * TP.slow))) or now
                local lead = 0.15 + (math.min((cp - hrp.Position).Magnitude, 300) / 1000)
                if now >= (ready - lead) then
                    local pos = cp - Vector3.new(0, TP.deep, 0)
                    TP.coin, TP.pos = pick, pos
                    TP.settle = math.max(now + lead, ready)
                    TP.poke = 0
                    setNoclip(true)
                    holdPos, underPos = cp, nil
                    setCanTouch(false)
                    placeAt(hrp, pos)
                    return
                end
                if holding then
                    setNoclip(true)
                    placeAt(hrp, TP.pos or hrp.Position)
                end
                return
            end
            if holding and TP.pos then
                setNoclip(true)
                placeAt(hrp, TP.pos)
                return
            end
            stopFarm()
        end

        -- bag-full handling: kill / fling / reset
        local fl = { gen = 0, running = false }

        local function mapPresent()
            for _, m in ipairs(workspace:GetChildren()) do
                if m:IsA("Model") and (m:GetAttribute("MapID") ~= nil or m:FindFirstChild("CoinContainer")) then
                    return true
                end
            end
            return false
        end

        local function pickMurderer()
            local pd = playerData()
            if type(pd) ~= "table" then return nil, false end
            for _, p in ipairs(Players:GetPlayers()) do
                local d = pd[p.Name]
                if p ~= lp and type(d) == "table" and not d.Dead and d.Role == "Murderer" then
                    local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    return hrp and p or nil, true
                end
            end
            return nil, false
        end

        function fl.stop()
            fl.gen = fl.gen + 1
            fl.running = false
        end

        function fl.start()
            if not autoFling then return false end
            if myRole() == "Murderer" then return false end
            if not select(2, pickMurderer()) then return false end
            fl.stop()
            fl.running = true
            local gen = fl.gen
            local oldChar = lp.Character
            task.spawn(function()
                local t0 = os.clock()
                local function respawned()
                    local c = lp.Character
                    local h = (c ~= oldChar) and c and c:FindFirstChildOfClass("Humanoid")
                    return h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") ~= nil
                end
                while fl.gen == gen and not respawned() and (os.clock() - t0) < 15 do task.wait(0.25) end
                if fl.gen == gen and respawned() then
                    task.wait(1)
                    while fl.gen == gen and on and autoFling and mapPresent() do
                        local m, any = pickMurderer()
                        if not any then break end
                        if m and playerFlingAction then pcall(playerFlingAction, m) end
                        task.wait(0.5)
                    end
                end
                if fl.gen == gen then fl.running = false end
            end)
            return true
        end

        function fl.reset()
            local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.Health = 0 end) end
        end

        local function killReady()
            return killAllHook ~= nil and findTool(lp, "Knife") ~= nil
        end

        local function holdAndKill()
            task.spawn(function()
                local done = false
                task.spawn(function()
                    pcall(killAllHook)
                    done = true
                end)
                local t0 = os.clock()
                while on and bagHandled and isAlive() and not done and (os.clock() - t0) < 30 do
                    task.wait(0.5)
                end
                if on and bagHandled and isAlive() then
                    if fl.start() then fl.reset()
                    elseif autoReset then fl.reset() end
                end
            end)
        end

        local function onBagFull()
            target = nil
            stopFarm()
            if bagHandled then return end
            bagHandled = true
            updateHold()
            if autoKill and killReady() then
                holdAndKill()
            elseif fl.start() then
                fl.reset()
            elseif autoReset then
                fl.reset()
            end
        end

        -- events
        task.spawn(function()
            local gp = RS:WaitForChild("Remotes"):WaitForChild("Gameplay")
            local cs = gp:WaitForChild("CoinsStarted", 15)
            if cs then conns[#conns + 1] = cs.OnClientEvent:Connect(function() resetRound() fl.stop() end) end
            local vs = gp:WaitForChild("VictoryScreen", 15)
            if vs then conns[#conns + 1] = vs.OnClientEvent:Connect(fl.stop) end
            local tp = gp:WaitForChild("TeleportToPart", 15)
            if tp then
                conns[#conns + 1] = tp.OnClientEvent:Connect(function()
                    resumeAt = os.clock() + 0.25
                    underPos, target = nil, nil
                    roundActive = false
                    TP.coin, TP.pos, TP.from = nil, nil, nil
                    if holding then setNoclip(false) end
                end)
            end
        end)

        conns[#conns + 1] = lp.CharacterAdded:Connect(function()
            holding, holdPos, underPos = false, nil, nil
            noCollideBackup = {}
            resetRound()
        end)

        conns[#conns + 1] = lp.Idled:Connect(function()
            if on then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        end)

        conns[#conns + 1] = RunService.Stepped:Connect(function(_, dt)
            if not on then return end
            if os.clock() < resumeAt then return end
            if genv.__KRP_ANTICOIN then return end
            if not isAlive() then
                target = nil
                stopFarm()
                return
            end
            local hrp = getHRP()
            if not hrp then return end

            local coins = {}
            for _, c in ipairs(CollectionService:GetTagged("CoinVisual")) do
                if c and c.Parent and c:IsA("BasePart") then
                    if c:GetAttribute("Collected") then
                        local id = c:GetAttribute("CoinID")
                        if id and not collectedIds[id] then
                            collectedIds[id] = true
                            collectedCount = collectedCount + 1
                        end
                    elseif not c:GetAttribute("Delete") then
                        coins[#coins + 1] = c
                    end
                end
            end

            if roundActive and bagFull() then
                onBagFull()
                return
            end

            if #coins > 0 then
                roundActive = true
                if bagHandled then
                    bagHandled = false
                    updateHold()
                end
                local mpart = murderCheck and murdererPart() or nil
                local mpos = mpart and mpart.Position or nil
                if mode == "Teleport" then
                    tpStep(hrp, coins, mpos)
                    return
                end
                if not coinOk(target, mpos) then
                    target = pickCoin(hrp.Position, coins, mpos)
                end
                if target then
                    setNoclip(true)
                    underPos = nil
                    local cp = target.Position
                    lastY = cp.Y
                    local goal
                    if mode == "Down" then
                        local flat = flatDist(hrp.Position, cp)
                        local safe = (not mpos) or flatDist(hrp.Position, mpos) > 20
                        if flat <= 4 and safe then
                            collect(target)
                            holdPos = cp
                            goal = cp
                        else
                            goal = Vector3.new(cp.X, cp.Y - 6, cp.Z)
                        end
                    else
                        if (cp - hrp.Position).Magnitude <= 6 then
                            collect(target)
                            holdPos = cp
                        end
                        goal = cp
                    end
                    stepToward(hrp, avoidPath(hrp.Position, goal, mpos), dt)
                elseif mpos then
                    setNoclip(true)
                    local away = Vector3.new(hrp.Position.X - mpos.X, 0, hrp.Position.Z - mpos.Z)
                    away = (away.Magnitude < 0.1 and Vector3.new(1, 0, 0) or away).Unit
                    local y = hrp.Position.Y
                    if mode == "Down" and lastY then y = lastY - 6 end
                    stepToward(hrp, hrp.Position + (away * 40) + Vector3.new(0, y - hrp.Position.Y, 0), dt)
                end
            else
                target = nil
                tpCheck(os.clock(), nil)
                if mode == "Teleport" and roundActive and holding and TP.pos then
                    placeAt(hrp, TP.pos)
                elseif roundActive and not bagHandled and collectedCount > 0 then
                    onBagFull()
                elseif bagHandled or roundActive then
                    stopFarm()
                elseif safeStart then
                    if not safeStartMove(hrp, dt) then stopFarm() end
                else
                    stopFarm()
                end
            end
        end)

        -- UI
        local box = Tabs.Main:AddLeftGroupbox("Auto Farm · Coins", "coins")
        box:AddToggle("CF_On", {
            Text = "Enable Auto Farm", Default = false,
            Tooltip = "collects coins: Basic / Down / Teleport, flees the murderer, avoids crowded coins",
            Callback = function(v)
                on = v
                genv.AUTOFARM_ON = v
                resetRound()
                local hrp = getHRP()
                if v and hrp then TP.from, TP.at = hrp.Position, os.clock() end
                if not v then stopFarm() end
            end,
        })
        box:AddDropdown("CF_Mode", {
            Text = "Mode", Values = { "Basic", "Down", "Teleport" }, Default = 1, Multi = false,
            Tooltip = "Basic: straight flight. Down: fly under the floor. Teleport: snap to coin",
            Callback = function(v)
                local m = (type(v) == "table" and v[1]) or v
                if m ~= "Basic" and m ~= "Down" and m ~= "Teleport" then m = "Basic" end
                if m == mode then return end
                mode, target = m, nil
                TP.coin = nil
                setCanTouch(true)
                local hrp = getHRP()
                if hrp then TP.from, TP.at = hrp.Position, os.clock() end
            end,
        })
        box:AddSlider("CF_Speed", {
            Text = "Speed", Default = 23, Min = 10, Max = 23, Rounding = 0, Suffix = " st/s",
            Tooltip = "flight speed in studs per second",
            Callback = function(v) maxSpeed = tonumber(v) or 23 end,
        })
        box:AddToggle("CF_Safe", {
            Text = "Safe Start", Default = false,
            Tooltip = "waits under the map between rounds until coins spawn",
            Callback = function(v) safeStart, underPos = v, nil end,
        })
        box:AddToggle("CF_Reset", {
            Text = "Auto Reset", Default = false,
            Tooltip = "reset the character when the coin bag is full",
            Callback = function(v) autoReset = v end,
        })
        box:AddToggle("CF_Fling", {
            Text = "Auto Fling", Default = false,
            Tooltip = "full bag: reset, then fling the murderer in the next life",
            Callback = function(v)
                autoFling = v
                if not v then fl.stop() end
            end,
        })
        box:AddToggle("CF_Kill", {
            Text = "Auto Kill", Default = false,
            Tooltip = "full bag as murderer: kill everyone, then reset / fling",
            Callback = function(v)
                autoKill = v
                updateHold()
            end,
        })
        box:AddToggle("CF_Murder", {
            Text = "Murder Check", Default = false,
            Tooltip = "flee the murderer and skip coins near them",
            Callback = function(v) murderCheck, target = v, nil end,
        })

        Library:OnUnload(function()
            on, autoReset, autoKill, autoFling, murderCheck = false, false, false, false, false
            genv.AUTOFARM_ON = false
            genv.AUTOFARM_HOLD = false
            fl.stop()
            for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
            stopFarm()
            setCanTouch(true)
        end)
    end)
runBlock("screen buttons", function()
        local UIS = game:GetService("UserInputService")
        local DEFAULT_OPACITY = 55
        local opacity = DEFAULT_OPACITY
        local roundness = 28
        local tpOnShot = false
        local buttons = {}
        local layer = create("Folder", { Name = "ScreenButtons", Parent = gui })
        local function viewport()
            local cam = workspace.CurrentCamera
            return cam and cam.ViewportSize or Vector2.new(1280, 720)
        end
        local WHITE = Color3.new(1, 1, 1)
        local INK = Color3.fromRGB(30, 4, 8)
        local ringStrokes
        local function part(parent, x, y, w, h, o)
            o = o or {}
            local f = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(x, y),
                Size = UDim2.fromScale(w, h),
                BackgroundColor3 = o.color or WHITE,
                BackgroundTransparency = (o.ring or o.hidden) and 1 or 0,
                BorderSizePixel = 0,
                Rotation = o.rot or 0,
                ZIndex = 7,
                Parent = parent,
            })
            if o.round then
                create("UICorner", { CornerRadius = UDim.new(o.round, 0), Parent = f })
            end
            if o.ring then
                local st = create("UIStroke", {
                    Color = o.color or WHITE, Thickness = 2,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f,
                })
                if ringStrokes then table.insert(ringStrokes, st) end
            end
            return f
        end
        local Icons = {}
        function Icons.crosshair(b)
            part(b, 0.5, 0.5, 0.68, 0.68, { ring = true, round = 0.5 })
            part(b, 0.5, 0.08, 0.08, 0.24, { round = 0.3 })
            part(b, 0.5, 0.92, 0.08, 0.24, { round = 0.3 })
            part(b, 0.08, 0.5, 0.24, 0.08, { round = 0.3 })
            part(b, 0.92, 0.5, 0.24, 0.08, { round = 0.3 })
            part(b, 0.5, 0.5, 0.14, 0.14, { round = 0.5 })
        end
        function Icons.skull(b)
            part(b, 0.5, 0.42, 0.82, 0.72, { round = 0.5 })
            part(b, 0.5, 0.78, 0.46, 0.3, { round = 0.2 })
            part(b, 0.33, 0.45, 0.2, 0.2, { round = 0.5, color = INK })
            part(b, 0.67, 0.45, 0.2, 0.2, { round = 0.5, color = INK })
            part(b, 0.5, 0.62, 0.08, 0.1, { round = 0.3, color = INK, rot = 45 })
            part(b, 0.42, 0.84, 0.03, 0.2, { color = INK })
            part(b, 0.5, 0.84, 0.03, 0.2, { color = INK })
            part(b, 0.58, 0.84, 0.03, 0.2, { color = INK })
        end
        function Icons.badge(b)
            part(b, 0.5, 0.5, 0.62, 0.62, { round = 0.12 })
            part(b, 0.5, 0.5, 0.62, 0.62, { round = 0.12, rot = 45 })
            part(b, 0.5, 0.5, 0.34, 0.34, { round = 0.5, color = INK })
            part(b, 0.5, 0.5, 0.2, 0.2, { round = 0.5 })
        end
        function Icons.knife(b)
            local g = part(b, 0.5, 0.5, 1, 1, { hidden = true, rot = 40 })
            part(g, 0.5, 0.38, 0.18, 0.55, { round = 0.15 })
            part(g, 0.5, 0.105, 0.127, 0.127, { rot = 45, round = 0.1 })
            part(g, 0.5, 0.68, 0.42, 0.07, { round = 0.4, color = Color3.fromRGB(210, 210, 215) })
            part(g, 0.5, 0.84, 0.13, 0.25, { round = 0.3, color = Color3.fromRGB(235, 235, 240) })
        end
        function Icons.pistol(b)
            part(b, 0.5, 0.3, 0.86, 0.24, { round = 0.2 })
            part(b, 0.56, 0.3, 0.3, 0.04, { color = INK })
            part(b, 0.28, 0.6, 0.22, 0.46, { round = 0.18, rot = -12 })
            part(b, 0.56, 0.54, 0.2, 0.2, { ring = true, round = 0.5 })
            part(b, 0.91, 0.3, 0.07, 0.1, { color = INK })
        end
        function Icons.note(b)
            part(b, 0.27, 0.8, 0.3, 0.2, { round = 0.5, rot = -20 })
            part(b, 0.73, 0.7, 0.3, 0.2, { round = 0.5, rot = -20 })
            part(b, 0.385, 0.5, 0.07, 0.6)
            part(b, 0.845, 0.4, 0.07, 0.6)
            part(b, 0.61, 0.15, 0.56, 0.12, { rot = -11, round = 0.2 })
        end
        local function makeButton(cfg)
            local B = { cfg = cfg, size = cfg.size or 64, color = cfg.color, enabled = false, active = false }
            local frame = create("TextButton", {
                Name = "KB_" .. cfg.id,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(cfg.x, cfg.y),
                Size = UDim2.fromOffset(B.size, B.size),
                BackgroundColor3 = B.color,
                BackgroundTransparency = opacity / 100,
                AutoButtonColor = false,
                Text = "",
                Visible = false,
                ZIndex = 5,
                Parent = layer,
            })
            local corner = create("UICorner", { CornerRadius = UDim.new(roundness / 100, 0), Parent = frame })
            B.corner = corner
            local stroke = create("UIStroke", {
                Color = B.color, Thickness = 2, Transparency = 0.15,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = frame,
            })
            local grad = create("UIGradient", {
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 0.55),
                }),
                Parent = frame,
            })
            local scale = create("UIScale", { Scale = 1, Parent = frame })
            local iconBox = create("Frame", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.4),
                Size = UDim2.fromScale(0.5, 0.5),
                ZIndex = 6,
                Parent = frame,
            })
            create("UIAspectRatioConstraint", { AspectRatio = 1, Parent = iconBox })
            ringStrokes = {}
            B.ringStrokes = ringStrokes
            if cfg.draw then
                cfg.draw(iconBox)
            end
            ringStrokes = nil
            local caption = create("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(0.9, 0.22),
                Position = UDim2.fromScale(0.05, 0.64),
                Font = Enum.Font.GothamBold,
                Text = cfg.name,
                TextColor3 = Color3.new(1, 1, 1),
                TextStrokeTransparency = 0.6,
                TextScaled = true,
                ZIndex = 6,
                Parent = frame,
            })
            create("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 6, Parent = caption })
            B.frame, B.stroke, B.caption = frame, stroke, caption
            function B:Refresh()
                corner.CornerRadius = UDim.new(roundness / 100, 0)
                for _, st in ipairs(self.ringStrokes or {}) do
                    st.Thickness = math.max(1.5, self.size * 0.045)
                end
                frame.Size = UDim2.fromOffset(self.size, self.size)
                frame.BackgroundColor3 = self.color
                stroke.Color = self.color
                frame.BackgroundTransparency = self.active and math.max(0, opacity / 100 - 0.25) or opacity / 100
                stroke.Transparency = self.active and 0 or 0.15
                stroke.Thickness = self.active and 3 or 2
            end
            function B:SetVisible(v)
                self.enabled = v
                frame.Visible = v
            end
            function B:SetActive(v)
                self.active = v
                self:Refresh()
            end
            function B:SetCaption(t)
                caption.Text = t
            end
            function B:Flash(c)
                local old = frame.BackgroundColor3
                frame.BackgroundColor3 = c or Color3.new(1, 1, 1)
                tween(frame, 0.35, { BackgroundColor3 = self.color })
            end
            local dragging, startInput, startPos, moved = false, nil, nil, false
            frame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging, moved = true, false
                    startInput = input.Position
                    startPos = frame.AbsolutePosition + frame.AbsoluteSize / 2
                    tween(scale, 0.1, { Scale = 0.9 })
                    input.Changed:Connect(function()
                        if input.UserInputState == Enum.UserInputState.End then
                            if dragging then
                                dragging = false
                                tween(scale, 0.15, { Scale = 1 })
                                if moved and B.onMoved then
                                    B.onMoved()
                                end
                                if not moved and cfg.action then
                                    task.spawn(cfg.action, B)
                                end
                            end
                        end
                    end)
                end
            end)
            connect(UIS.InputChanged, function(input)
                if not dragging or not startInput then return end
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                    local delta = input.Position - startInput
                    if not moved and delta.Magnitude > 8 then moved = true end
                    if moved then
                        local vs = viewport()
                        local p = startPos + Vector2.new(delta.X, delta.Y)
                        local nx = math.clamp(p.X / vs.X, 0.02, 0.98)
                        local ny = math.clamp(p.Y / vs.Y, 0.02, 0.98)
                        frame.Position = UDim2.fromScale(nx, ny)
                        cfg.x, cfg.y = nx, ny
                    end
                end
            end)
            B:Refresh()
            table.insert(buttons, B)
            return B
        end
        local function noKnife() return not findTool(player, "Knife") end
        local shoot = makeButton({
            id = "Shoot", name = "SHOT", draw = Icons.crosshair, x = 0.88, y = 0.45, size = 66,
            color = Color3.fromRGB(150, 20, 30),
            action = function(B)
                if not shootMurdererHook then return B:Flash(Color3.fromRGB(255, 0, 0)) end
                shootMurdererHook(true, tpOnShot)
                B:Flash()
            end,
        })
        local flingM = makeButton({
            id = "FlingM", name = "FLING M", draw = Icons.skull, x = 0.88, y = 0.58, size = 66,
            color = Color3.fromRGB(150, 20, 30),
            action = function(B)
                if not flingRoleHook then return B:Flash(Color3.fromRGB(255, 0, 0)) end
                flingRoleHook("Murderer", true)
                B:Flash()
            end,
        })
        local flingS = makeButton({
            id = "FlingS", name = "FLING S", draw = Icons.badge, x = 0.88, y = 0.71, size = 66,
            color = Color3.fromRGB(150, 20, 30),
            action = function(B)
                if not flingRoleHook then return B:Flash(Color3.fromRGB(255, 0, 0)) end
                flingRoleHook("Sheriff", true)
                B:Flash()
            end,
        })
        local killA = makeButton({
            id = "KillAll", name = "KILL ALL", draw = Icons.knife, x = 0.76, y = 0.58, size = 66,
            color = Color3.fromRGB(150, 20, 30),
            action = function(B)
                if not killAllHook or noKnife() then return B:Flash(Color3.fromRGB(255, 0, 0)) end
                killAllHook()
                B:Flash()
            end,
        })
        local grab = makeButton({
            id = "Grab", name = "PICKUP", draw = Icons.pistol, x = 0.76, y = 0.45, size = 66,
            color = Color3.fromRGB(150, 20, 30),
            action = function(B)
                if not grabGunHook then return B:Flash(Color3.fromRGB(255, 0, 0)) end
                grabGunHook(nil, true)
                B:Flash()
            end,
        })
        local emoteBtns = {}
        for i = 1, 3 do
            local slot = { label = nil }
            local btn = makeButton({
                id = "Emote" .. i, name = "EMOTE " .. i, draw = Icons.note, x = 0.12, y = 0.45 + (i - 1) * 0.13, size = 60,
                color = Color3.fromRGB(150, 20, 30),
                action = function(B)
                    local api = getgenv().__KRP_EMOTES
                    if not api or not slot.label then return B:Flash(Color3.fromRGB(255, 0, 0)) end
                    if B.active and api.isPlaying() then
                        api.stop()
                        B:SetActive(false)
                    else
                        for _, other in ipairs(emoteBtns) do other.btn:SetActive(false) end
                        api.play(slot.label)
                        B:SetActive(true)
                    end
                end,
            })
            emoteBtns[i] = { slot = slot, btn = btn }
        end
        connect(RunService.Heartbeat, function()
            local api = getgenv().__KRP_EMOTES
            if api and not api.isPlaying() then
                for _, e in ipairs(emoteBtns) do
                    if e.btn.active then e.btn:SetActive(false) end
                end
            end
        end)
        local main = addSection(Tabs.Cosmetics, "Screen Buttons", "Left")
        main:Slider("Opacity", 10, 95, DEFAULT_OPACITY, function(v)
            opacity = v
            for _, b in ipairs(buttons) do b:Refresh() end
        end, function(v) return v .. "%" end)
        main:Slider("Roundness", 0, 50, roundness, function(v)
            roundness = v
            for _, b in ipairs(buttons) do b:Refresh() end
        end, function(v) return v == 50 and "circle" or v .. "%" end)
        main:Toggle("Shot Button Uses Teleport", "tp next to the murderer, camera stays", function(v)
            tpOnShot = v
        end).Set(false, true)
        main:Button("Reset Positions", "put every button back to its default place", function()
            for _, b in ipairs(buttons) do
                b.cfg.x, b.cfg.y = b.cfg.defX, b.cfg.defY
                b.frame.Position = UDim2.fromScale(b.cfg.x, b.cfg.y)
                if b.onMoved then b.onMoved() end
            end
        end)
        main:Label("Tap = use. Hold and drag = move.")
        local function posSliders(sec, btn)
            local sx = sec:Slider("Position X", 2, 98, math.floor(btn.cfg.x * 100 + 0.5), function(v)
                btn.cfg.x = v / 100
                btn.frame.Position = UDim2.fromScale(btn.cfg.x, btn.cfg.y)
            end, function(v) return v .. "%" end)
            local sy = sec:Slider("Position Y", 2, 98, math.floor(btn.cfg.y * 100 + 0.5), function(v)
                btn.cfg.y = v / 100
                btn.frame.Position = UDim2.fromScale(btn.cfg.x, btn.cfg.y)
            end, function(v) return v .. "%" end)
            btn.onMoved = function()
                sx.Set(math.clamp(math.floor(btn.cfg.x * 100 + 0.5), 2, 98), true)
                sy.Set(math.clamp(math.floor(btn.cfg.y * 100 + 0.5), 2, 98), true)
            end
        end
        local function section(btn, title, extra)
            btn.cfg.defX, btn.cfg.defY = btn.cfg.x, btn.cfg.y
            local sec = addSection(Tabs.Cosmetics, title)
            sec:Toggle("Show Button", nil, function(v) btn:SetVisible(v) end)
            sec:Slider("Size", 36, 140, btn.size, function(v)
                btn.size = v
                btn:Refresh()
            end, function(v) return v .. "px" end)
            sec:ColorPicker("Color", nil, btn.color, function(c)
                btn.color = c
                btn:Refresh()
            end)
            posSliders(sec, btn)
            if extra then extra(sec) end
        end
        section(shoot, "Shot Murderer Button")
        section(flingM, "Fling Murderer Button")
        section(flingS, "Fling Sheriff Button")
        section(killA, "Kill All (Knife) Button")
        section(grab, "Pickup Gun Button")
        local api = getgenv().__KRP_EMOTES
        local labels = api and api.labels or { "-" }
        for i, e in ipairs(emoteBtns) do
            e.btn.cfg.defX, e.btn.cfg.defY = e.btn.cfg.x, e.btn.cfg.y
            local sec = addSection(Tabs.Cosmetics, "Emote Button " .. i)
            local function assign(v)
                e.slot.label = v
                e.btn:SetCaption(#v > 14 and (v:sub(1, 12) .. "..") or v)
            end
            local dd = sec:Select("Emote", "pick any emote from the Emotes list (searchable)", labels, labels[i] or labels[1], assign)
            assign(labels[i] or labels[1])
            sec:Button("Take Emote From Emotes", "uses the emote currently selected in the Emotes group", function()
                local cur = api and api.current and api.current()
                if cur then
                    dd.Set(cur, true)
                    assign(cur)
                end
            end)
            sec:Toggle("Show Button", nil, function(v)
                e.btn:SetVisible(v)
            end)
            sec:Slider("Size", 36, 140, e.btn.size, function(v)
                e.btn.size = v
                e.btn:Refresh()
            end, function(v) return v .. "px" end)
            sec:ColorPicker("Color", nil, e.btn.color, function(c)
                e.btn.color = c
                e.btn:Refresh()
            end)
            posSliders(sec, e.btn)
        end
        Library:OnUnload(function()
            pcall(function() layer:Destroy() end)
        end)
    end)
    Library:OnUnload(function()
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        desync.on = false
        if stopRoleFling then pcall(stopRoleFling) end
        if stopPlayersActions then pcall(stopPlayersActions) end
        if stopVoteDupe then pcall(stopVoteDupe) end
        pcall(function() RunService:UnbindFromRenderStep("KirpichDesync") end)
        pcall(function() RunService:UnbindFromRenderStep("KirpichDesyncVis") end)
        pcall(function() gui:Destroy() end)
    end)
end
do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Lighting = game:GetService("Lighting")
    local Sink = getgenv().__KRP_SINK
    local rhId = 0
    local function rid(p) rhId += 1; return "RH_" .. (p or "E") .. rhId end
    local function toNames(v)
        local out = {}
        if type(v) == "table" then
            for k, val in pairs(v) do
                if type(k) == "number" and type(val) == "string" then out[#out + 1] = val
                elseif type(k) == "string" and val == true then out[#out + 1] = k end
            end
        elseif type(v) == "string" and v ~= "" then out[1] = v end
        return out
    end
    local function toSet(v)
        local s = {}
        for _, n in ipairs(toNames(v)) do s[n] = true end
        return s
    end
    local function safe(fn, ...)
        if type(fn) ~= "function" then return end
        local ok, err = pcall(fn, ...)
        if not ok then warn("[Kirpich] callback error: " .. tostring(err)) end
    end
    local wrapContainer
    local function buildAdders(w, box)
        function w:AddToggle(cfg)
            cfg = cfg or {}
            local id = cfg.Flag and ("RH_" .. cfg.Flag) or rid("T")
            local t = box:AddToggle(id, {
                Text = getgenv().__KRP_TC(cfg.Name or "toggle"),
                Default = cfg.Default and true or false,
                Callback = function(v) safe(cfg.Callback, v) end,
            })
            local o = { __el = t, __id = id }
            function o:GetValue() return t.Value end
            function o:SetValue(v) t:SetValue(v and true or false) end
            local dep
            setmetatable(o, { __index = function(_, k)
                if k == "Value" then return t.Value end
                if k == "Option" then
                    if not dep then
                        dep = box:AddDependencyBox()
                        pcall(function() dep:SetupDependencies({ { Toggles[id], true } }) end)
                        dep = wrapContainer(dep)
                    end
                    return dep
                end
            end })
            return o
        end
        function w:AddSlider(cfg)
            cfg = cfg or {}
            local id = cfg.Flag and ("RH_" .. cfg.Flag) or rid("S")
            local mn, mx = tonumber(cfg.Min) or 0, tonumber(cfg.Max) or 100
            local dec = tonumber(cfg.Round or cfg.Rounding) or 0
            local s = box:AddSlider(id, {
                Text = getgenv().__KRP_TC(cfg.Name or "slider"),
                Default = tonumber(cfg.Default) or mn,
                Min = mn, Max = mx, Rounding = dec,
                Suffix = (type(cfg.Type) == "string") and cfg.Type or "",
                Callback = function(v) safe(cfg.Callback, v) end,
            })
            local o = { __el = s }
            function o:GetValue() return s.Value end
            function o:SetValue(v) s:SetValue(v) end
            setmetatable(o, { __index = function(_, k) if k == "Value" then return s.Value end end })
            return o
        end
        local function makeDropdown(cfg, values, multi, display)
            local id = cfg.Flag and ("RH_" .. cfg.Flag) or rid("D")
            local def = cfg.Default
            if multi then def = toSet(def) end
            local d = box:AddDropdown(id, {
                Text = getgenv().__KRP_TC(cfg.Name or "dropdown"),
                Values = values,
                Default = (not multi) and def or nil,
                Multi = multi and true or false,
                Searchable = (#values > 12),
                Callback = function(v)
                    local out = v
                    if multi then out = toNames(v) end
                    if display then
                        if multi then
                            local r = {}
                            for _, x in ipairs(out) do r[#r + 1] = display.toName[x] or x end
                            out = r
                        else
                            out = display.toName[out] or out
                        end
                    end
                    safe(cfg.Callback, out)
                end,
            })
            if multi and next(def) then
                pcall(function() d:SetValue(def) end)
            end
            return d, id
        end
        function w:AddDropdown(cfg)
            cfg = cfg or {}
            local multi = cfg.Multi and true or false
            local d = makeDropdown(cfg, cfg.Values or {}, multi, nil)
            local o = { __el = d }
            function o:GetValue()
                if multi then return toNames(d.Value) end
                return d.Value
            end
            function o:SetValue(v)
                if multi then d:SetValue(toSet(v)) else d:SetValue(v) end
            end
            function o:SetValues(v) d:SetValues(v or {}) end
            function o:Generate() end
            setmetatable(o, { __index = function(_, k) if k == "Value" then return o:GetValue() end end })
            return o
        end
        function w:AddColorPicker(cfg)
            cfg = cfg or {}
            local id = cfg.Flag and ("RH_" .. cfg.Flag) or rid("C")
            local lbl = box:AddLabel(getgenv().__KRP_TC(cfg.Name or "color"))
            lbl:AddColorPicker(id, {
                Default = (typeof(cfg.Default) == "Color3") and cfg.Default or Color3.new(1, 1, 1),
                Title = getgenv().__KRP_TC(cfg.Name or "color"),
                Transparency = cfg.Transparency and 0 or nil,
                Callback = function(c)
                    local tr = Options[id] and Options[id].Transparency
                    safe(cfg.Callback, c, tr)
                end,
            })
            local o = {}
            function o:GetValue() local op = Options[id]; if op then return op.Value end return cfg.Default end
            function o:SetValue(c) local op = Options[id]; if op then op:SetValueRGB(c) end end
            setmetatable(o, { __index = function(_, k) if k == "Value" then return o:GetValue() end end })
            return o
        end
        function w:AddKeybind(cfg)
            cfg = cfg or {}
            local id = cfg.Flag and ("RH_" .. cfg.Flag) or rid("K")
            local lbl = box:AddLabel(getgenv().__KRP_TC(cfg.Name or "keybind"))
            local function nameOf(k)
                if typeof(k) == "EnumItem" then return k.Name end
                return tostring(k)
            end
            lbl:AddKeyPicker(id, {
                Default = cfg.Default or "None",
                Mode = "Hold",
                Text = getgenv().__KRP_TC(cfg.Name or "keybind"),
                NoUI = true,
                ChangedCallback = function(k) safe(cfg.Callback, nameOf(k)) end,
            })
            if cfg.Default then task.defer(function() safe(cfg.Callback, cfg.Default) end) end
            local o = {}
            function o:GetValue() return Options[id] and Options[id].Value or cfg.Default end
            function o:SetValue(k) pcall(function() Options[id]:SetValue({ k, "Hold" }) end) end
            return o
        end
        function w:AddButton(cfg)
            cfg = cfg or {}
            box:AddButton({ Text = getgenv().__KRP_TC(cfg.Name or "Button"), Func = function() safe(cfg.Callback) end })
            return {}
        end
        function w:AddLabel(name, wrapText)
            local l = box:AddLabel(getgenv().__KRP_TC(tostring(name or "")), wrapText and true or false)
            local o = {}
            function o:SetValue(v) pcall(function() l:SetText(tostring(v)) end) end
            function o:GetValue() return l.Text end
            return o
        end
    end
    wrapContainer = function(box)
        local w = { __box = box }
        buildAdders(w, box)
        return w
    end
    do
    local okW, errW = pcall(function()
        local Lighting = game:GetService("Lighting")
        local Players = game:GetService("Players")
        local RunService = game:GetService("RunService")
        local Workspace = workspace
        local localPlayer = Players.LocalPlayer
        local skyReady = false
        local function wr(sec)
            local S = {}
            local function named(text, cfg)
                local c = {}
                for k, v in pairs(cfg or {}) do c[k] = v end
                c.Name = c.Name or text
                return c
            end
            function S:AddLabel(text)
                local L = {}
                function L:AddToggle(cfg) return sec:AddToggle(named(text, cfg)) end
                function L:AddSlider(cfg) return sec:AddSlider(named(text, cfg)) end
                function L:AddDropdown(cfg) return sec:AddDropdown(named(text, cfg)) end
                function L:AddColorPicker(cfg) return sec:AddColorPicker(named(text, cfg)) end
                return L
            end
            function S:AddButton(cfg) return sec:AddButton(cfg) end
            return S
        end
        local shaderSec = wr(wrapContainer(getgenv().__KRP_VIS_WORLD))
        local camSec = wr(wrapContainer(getgenv().__KRP_VIS_WORLD))
        local hatSec = wr(wrapContainer(getgenv().__KRP_VIS_FX))
        local trailSec = wr(wrapContainer(getgenv().__KRP_VIS_FX))
do
			local tbl6 = {
				Nebula = {
					Bk = "http://www.roblox.com/asset?id=135207744",
					Dn = "http://www.roblox.com/asset?id=135207662",
					Ft = "http://www.roblox.com/asset?id=135207770",
					Lf = "http://www.roblox.com/asset?id=135207615",
					Rt = "http://www.roblox.com/asset?id=135207695",
					Up = "http://www.roblox.com/asset?id=135207794",
				},
				Storm = {
					Bk = "rbxassetid://15502511288",
					Dn = "rbxassetid://15502508460",
					Ft = "rbxassetid://15502510289",
					Lf = "rbxassetid://15502507918",
					Rt = "rbxassetid://15502509398",
					Up = "rbxassetid://15502511911",
				},
				Sunset = {
					Bk = "rbxassetid://600830446",
					Dn = "rbxassetid://600831635",
					Ft = "rbxassetid://600832720",
					Lf = "rbxassetid://600886090",
					Rt = "rbxassetid://600833862",
					Up = "rbxassetid://600835177",
				},
				["Deep Space"] = {
					Bk = "http://www.roblox.com/asset/?id=159248188",
					Dn = "http://www.roblox.com/asset/?id=159248183",
					Ft = "http://www.roblox.com/asset/?id=159248187",
					Lf = "http://www.roblox.com/asset/?id=159248173",
					Rt = "http://www.roblox.com/asset/?id=159248192",
					Up = "http://www.roblox.com/asset/?id=159248176",
				},
				Crimson = {
					Bk = "http://www.roblox.com/asset/?id=401664839",
					Dn = "http://www.roblox.com/asset/?id=401664862",
					Ft = "http://www.roblox.com/asset/?id=401664960",
					Lf = "http://www.roblox.com/asset/?id=401664881",
					Rt = "http://www.roblox.com/asset/?id=401664901",
					Up = "http://www.roblox.com/asset/?id=401664936",
				},
				Galaxy = {
					Bk = "rbxassetid://15983968922",
					Dn = "rbxassetid://15983966825",
					Ft = "rbxassetid://15983965025",
					Lf = "rbxassetid://15983967420",
					Rt = "rbxassetid://15983966246",
					Up = "rbxassetid://15983964246",
				},
				Blossom = {
					Bk = "http://www.roblox.com/asset/?id=271042516",
					Dn = "http://www.roblox.com/asset/?id=271077243",
					Ft = "http://www.roblox.com/asset/?id=271042556",
					Lf = "http://www.roblox.com/asset/?id=271042310",
					Rt = "http://www.roblox.com/asset/?id=271042467",
					Up = "http://www.roblox.com/asset/?id=271077958",
				},
				Arctic = {
					Bk = "http://www.roblox.com/asset/?id=225469390",
					Dn = "http://www.roblox.com/asset/?id=225469395",
					Ft = "http://www.roblox.com/asset/?id=225469403",
					Lf = "http://www.roblox.com/asset/?id=225469450",
					Rt = "http://www.roblox.com/asset/?id=225469471",
					Up = "http://www.roblox.com/asset/?id=225469481",
				},
				Midnight = {
					Bk = "http://www.roblox.com/asset/?id=12064107",
					Dn = "http://www.roblox.com/asset/?id=12064152",
					Ft = "http://www.roblox.com/asset/?id=12064121",
					Lf = "http://www.roblox.com/asset/?id=12063984",
					Rt = "http://www.roblox.com/asset/?id=12064115",
					Up = "http://www.roblox.com/asset/?id=12064131",
				},
				Stylized = {
					Bk = "rbxassetid://18351376859",
					Dn = "rbxassetid://18351374919",
					Ft = "rbxassetid://18351376800",
					Lf = "rbxassetid://18351376469",
					Rt = "rbxassetid://18351376457",
					Up = "rbxassetid://18351377189",
				},
				Overcast = {
					Bk = "http://www.roblox.com/asset/?id=4498828382",
					Dn = "http://www.roblox.com/asset/?id=4498828812",
					Ft = "http://www.roblox.com/asset/?id=4498829917",
					Lf = "http://www.roblox.com/asset/?id=4498830911",
					Rt = "http://www.roblox.com/asset/?id=4498830417",
					Up = "http://www.roblox.com/asset/?id=4498831746",
				},
				Frostfall = {
					Bk = "http://www.roblox.com/asset/?id=155657655",
					Dn = "http://www.roblox.com/asset/?id=155674246",
					Ft = "http://www.roblox.com/asset/?id=155657609",
					Lf = "http://www.roblox.com/asset/?id=155657671",
					Rt = "http://www.roblox.com/asset/?id=155657619",
					Up = "http://www.roblox.com/asset/?id=155674931",
				},
				Default = {
					Bk = "rbxasset://textures/sky/sky512_bk.tex",
					Dn = "rbxasset://textures/sky/sky512_dn.tex",
					Ft = "rbxasset://textures/sky/sky512_ft.tex",
					Lf = "rbxasset://textures/sky/sky512_lf.tex",
					Rt = "rbxasset://textures/sky/sky512_rt.tex",
					Up = "rbxasset://textures/sky/sky512_up.tex",
				},
			}
			local tbl7 = nil
			skyReady = false
			local function fn51(arg)
				local v46 = tbl6[arg]
				if not v46 then
					return
				end
				local sky = Lighting:FindFirstChildOfClass("Sky")
				if sky and not tbl7 then
					tbl7 = {
						Bk = sky.SkyboxBk,
						Dn = sky.SkyboxDn,
						Ft = sky.SkyboxFt,
						Lf = sky.SkyboxLf,
						Rt = sky.SkyboxRt,
						Up = sky.SkyboxUp,
					}
				end
				if not sky then
					sky = Instance.new("Sky")
					sky.Parent = Lighting
				end
				sky.Name = "Sky"
				pcall(function()
					sky.SkyboxBk = v46.Bk
					sky.SkyboxDn = v46.Dn
					sky.SkyboxFt = v46.Ft
					sky.SkyboxLf = v46.Lf
					sky.SkyboxRt = v46.Rt
					sky.SkyboxUp = v46.Up
				end)
			end
			shaderSec:AddLabel("Custom Skybox"):AddDropdown({
				Flag = "CustomSkybox",
				Values = {
					"Nebula",
					"Storm",
					"Sunset",
					"Deep Space",
					"Crimson",
					"Galaxy",
					"Blossom",
					"Arctic",
					"Midnight",
					"Stylized",
					"Overcast",
					"Frostfall",
					"Default",
				},
				Default = "Default",
				Callback = function(arg)
					if not skyReady and arg == "Default" then
						return
					end
					skyReady = true
					fn51(arg)
				end,
			})
			shaderSec:AddButton({
				Name = "Restore Original Sky",
				Callback = function()
					local sky = Lighting:FindFirstChildOfClass("Sky")
					if sky and tbl7 then
						pcall(function()
							sky.SkyboxBk = tbl7.Bk
							sky.SkyboxDn = tbl7.Dn
							sky.SkyboxFt = tbl7.Ft
							sky.SkyboxLf = tbl7.Lf
							sky.SkyboxRt = tbl7.Rt
							sky.SkyboxUp = tbl7.Up
						end)
					end
				end,
			})
		end
do
			local fx = {}
			local baseExposure
			local state = {}
			local sliders = {}
			local zero = { exposure = 0, saturation = 0, contrast = 0, bloom = 0, bloomSize = 24, rays = 0, fog = 0, blur = 0, tint = Color3.new(1, 1, 1) }
			local presets = {
				["Off"] = {},
				["Ultra HD"] = { exposure = 0.5, saturation = 0.2, contrast = 0.15, bloom = 3.5, bloomSize = 40, rays = 0.6, fog = 0.15 },
				["Cinematic"] = { exposure = 0.8, saturation = 0.4, contrast = 0.5, bloom = 6, bloomSize = 56, rays = 0.8, fog = 0.3 },
				["Cyberpunk"] = { saturation = 0.8, contrast = 0.3, bloom = 5, rays = 0.4, fog = 0, tint = Color3.fromRGB(0, 255, 255) },
				["Soft"] = { saturation = 0.05, contrast = 0.05, bloom = 1.5, fog = 0.4 },
				["Realistic"] = { exposure = 1, saturation = 0.3, contrast = 0.4, bloom = 2, bloomSize = 24, rays = 0.5, fog = 0.2 },
				["Horror"] = { exposure = -0.5, saturation = -0.5, contrast = 0.8, blur = 10, fog = 0.5 },
				["Anime"] = { saturation = 0.6, contrast = 0.2, bloom = 2, bloomSize = 20, rays = 0.7, fog = 0.1, tint = Color3.fromRGB(255, 200, 200) },
			}
			local order = { "Off", "Ultra HD", "Cinematic", "Cyberpunk", "Soft", "Realistic", "Horror", "Anime" }
			local function effect(class, name)
				local inst = fx[name]
				if inst and inst.Parent then
					return inst
				end
				inst = Instance.new(class)
				inst.Name = name
				inst.Parent = Lighting
				fx[name] = inst
				return inst
			end
			local function clear()
				for k, inst in pairs(fx) do
					pcall(function() inst:Destroy() end)
					fx[k] = nil
				end
				if baseExposure ~= nil then
					Lighting.ExposureCompensation = baseExposure
					baseExposure = nil
				end
			end
			local function apply()
				if baseExposure == nil then
					baseExposure = Lighting.ExposureCompensation
				end
				Lighting.ExposureCompensation = state.exposure
				local cc = effect("ColorCorrectionEffect", "KirpichShaderColor")
				cc.Saturation = state.saturation
				cc.Contrast = state.contrast
				cc.TintColor = state.tint
				local bloom = effect("BloomEffect", "KirpichShaderBloom")
				bloom.Intensity = state.bloom
				bloom.Size = state.bloomSize
				local rays = effect("SunRaysEffect", "KirpichShaderRays")
				rays.Intensity = state.rays
				local atm = effect("Atmosphere", "KirpichShaderFog")
				atm.Density = state.fog
				local blur = effect("BlurEffect", "KirpichShaderBlur")
				blur.Size = state.blur
			end
			for k, v in pairs(zero) do
				state[k] = v
			end
			local function setManual(key, v)
				state[key] = v
				apply()
			end
			shaderSec:AddLabel("Shader Preset"):AddDropdown({
				Flag = "ShaderPreset",
				Values = order,
				Default = "Off",
				Callback = function(name)
					local p = presets[name]
					if not p then
						return
					end
					for k, v in pairs(zero) do
						state[k] = p[k] == nil and v or p[k]
					end
					if name == "Off" then
						clear()
					else
						apply()
					end
					pcall(function()
						sliders.exposure:SetValue(state.exposure)
						sliders.saturation:SetValue(state.saturation)
						sliders.contrast:SetValue(state.contrast)
						sliders.blur:SetValue(state.blur)
					end)
				end,
			})
			sliders.exposure = shaderSec:AddLabel("Brightness"):AddSlider({
				Flag = "ShaderBrightness", Min = -3, Max = 4, Default = 0, Round = 1,
				Callback = function(v) setManual("exposure", v) end,
			})
			sliders.saturation = shaderSec:AddLabel("Saturation"):AddSlider({
				Flag = "ShaderSaturation", Min = -1, Max = 2, Default = 0, Round = 2,
				Callback = function(v) setManual("saturation", v) end,
			})
			sliders.contrast = shaderSec:AddLabel("Contrast"):AddSlider({
				Flag = "ShaderContrast", Min = -2, Max = 3, Default = 0, Round = 1,
				Callback = function(v) setManual("contrast", v) end,
			})
			sliders.blur = shaderSec:AddLabel("Blur"):AddSlider({
				Flag = "ShaderBlur", Min = 0, Max = 56, Default = 0, Round = 0,
				Callback = function(v) setManual("blur", v) end,
			})
			pcall(function() Library:OnUnload(clear) end)
		end
do
				local tbl10 = {}
				local tbl11 = nil
				shaderSec:AddLabel("Tokyowami Shaders"):AddToggle({
					Default = false,
					Flag = "TokyowamiShaders",
					Callback = function(arg)
						pcall(function()
						end)
						if arg then
							if tbl11 then
								return
							end
							tbl11 = {
								Brightness = Lighting.Brightness,
								ClockTime = Lighting.ClockTime,
								FogColor = Lighting.FogColor,
								FogEnd = Lighting.FogEnd,
								FogStart = Lighting.FogStart,
								Ambient = Lighting.Ambient,
								OutdoorAmbient = Lighting.OutdoorAmbient,
								ColorShift_Top = Lighting.ColorShift_Top,
								ColorShift_Bottom = Lighting.ColorShift_Bottom,
								ExposureCompensation = Lighting.ExposureCompensation,
								ShadowSoftness = Lighting.ShadowSoftness,
							}
							local bloomEffect = Instance.new("BloomEffect")
							bloomEffect.Intensity = 0.1
							bloomEffect.Threshold = 0
							bloomEffect.Size = 100
							bloomEffect.Parent = Lighting
							local colorCorrectionEffect = Instance.new("ColorCorrectionEffect")
							colorCorrectionEffect.Name = "WraithInari"
							colorCorrectionEffect.Saturation = 0.05
							colorCorrectionEffect.TintColor = Color3.fromRGB(255, 224, 219)
							colorCorrectionEffect.Parent = Lighting
							local sunRaysEffect = Instance.new("SunRaysEffect")
							sunRaysEffect.Intensity = 0.05
							sunRaysEffect.Parent = Lighting
							local blurEffect = Instance.new("BlurEffect")
							blurEffect.Size = 1
							blurEffect.Parent = Lighting
							local sky = Instance.new("Sky")
							sky.Name = "WraithSunset"
							sky.SkyboxUp = "rbxassetid://323493360"
							sky.SkyboxLf = "rbxassetid://323494252"
							sky.SkyboxBk = "rbxassetid://323494035"
							sky.SkyboxFt = "rbxassetid://323494130"
							sky.SkyboxDn = "rbxassetid://323494368"
							sky.SunAngularSize = 14
							sky.SkyboxRt = "rbxassetid://323494067"
							sky.Parent = Lighting
							tbl10 = { bloomEffect, colorCorrectionEffect, sunRaysEffect, blurEffect, sky }
							Lighting.Brightness = 2.14
							Lighting.ColorShift_Bottom = Color3.fromRGB(11, 0, 20)
							Lighting.ColorShift_Top = Color3.fromRGB(240, 127, 14)
							Lighting.OutdoorAmbient = Color3.fromRGB(34, 0, 49)
							Lighting.ClockTime = 6.7
							Lighting.FogColor = Color3.fromRGB(94, 76, 106)
							Lighting.FogEnd = 1000
							Lighting.FogStart = 0
							Lighting.ExposureCompensation = 0.24
							Lighting.ShadowSoftness = 0
							Lighting.Ambient = Color3.fromRGB(59, 33, 27)
						else
							for _, v48 in pairs(tbl10) do
								pcall(function()
									v48:Destroy()
								end)
							end
							tbl10 = {}
							if tbl11 then
								for k, v48 in pairs(tbl11) do
									pcall(function()
										Lighting[k] = v48
									end)
								end
								tbl11 = nil
							end
						end
					end,
				})
			end
do
				local flag13 = false
				local n26 = 0.5
				local connection2 = nil
				local cFrame = nil
				pcall(function() getgenv().__KRP_VIS_WORLD:AddDivider() end)
				camSec:AddLabel("Smoothness"):AddSlider({
					Min = 10,
					Max = 90,
					Default = 50,
					Rounding = 0,
					Flag = "SmoothCamAmount",
					Callback = function(arg)
						n26 = arg / 100
					end,
				})
				camSec:AddLabel("Smooth Camera"):AddToggle({
					Default = false,
					Flag = "SmoothCam",
					Callback = function(arg)
						pcall(function()
						end)
						flag13 = arg
						if connection2 then
							connection2:Disconnect()
							connection2 = nil
						end
						if not arg then
							return
						end
						local currentCamera = Workspace.CurrentCamera
						if not currentCamera then
							return
						end
						cFrame = currentCamera.CFrame
						connection2 = RunService.RenderStepped:Connect(function()
							if not flag13 then
								return
							end
							local currentCamera2 = Workspace.CurrentCamera
							if not currentCamera2 then
								return
							end
							local cFrame2 = currentCamera2.CFrame
							local clamp = math.clamp
							local v48 = n26
							local n27
							if n26 then
								n27 = v48
							else
								n27 = 0.25
							end
							local v49 = clamp(1 - n27, 0.05, 1)
							local v50 = cFrame.Position:Lerp(cFrame2.Position, v49)
							cFrame = CFrame.new(v50)
							local n28 = cFrame2 - cFrame2.Position
							currentCamera2.CFrame = CFrame.new(v50) * n28
						end)
					end,
				})
			end
do
				local tbl8 = {}
				local transparency = 0.3
				local flag13 = false
				local color = Color3.fromRGB(0, 255, 255)
				local function fn52(arg)
					local v48 = tbl8[arg]
					if v48 then
						pcall(function()
							v48:Destroy()
						end)
						tbl8[arg] = nil
					end
				end
				local function fn53(parent)
					local head = parent and parent:FindFirstChild("Head")
					if not head then
						return
					end
					fn52(parent)
					local part2 = Instance.new("Part")
					part2.Name = "Hat"
					part2.Transparency = transparency
					part2.Color = color
					part2.Material = Enum.Material.Neon
					part2.CanCollide = false
					part2.CanTouch = false
					part2.CanQuery = false
					part2.Massless = true
					local specialMesh = Instance.new("SpecialMesh")
					specialMesh.MeshId = "rbxassetid://1033714"
					specialMesh.Scale = Vector3.new(2.25, 1.5, 2.25)
					specialMesh.Parent = part2
					local weldConstraint = Instance.new("WeldConstraint")
					weldConstraint.Part0 = head
					weldConstraint.Part1 = part2
					weldConstraint.Parent = part2
					part2.CFrame = head.CFrame * CFrame.new(0, 1.1, 0)
					part2.Parent = parent
					tbl8[parent] = part2
				end
				local tbl9 = {}
				local lifetime = 0.5
				local n26 = 0
				local flag14 = false
				local flag15 = false
				local color2 = Color3.fromRGB(0, 255, 255)
				local color3 = Color3.fromRGB(0, 86, 255)
				local color4 = Color3.fromRGB(255, 0, 0)
				local function fn54(arg)
					if tbl9[arg] then
						pcall(function()
							tbl9[arg]:Destroy()
						end)
						tbl9[arg] = nil
					end
					arg = arg and arg:FindFirstChild("HumanoidRootPart")
					if arg then
						local trailAttach0 = arg:FindFirstChild("TrailAttach0")
						local trailAttach1 = arg:FindFirstChild("TrailAttach1")
						if trailAttach0 then
							trailAttach0:Destroy()
						end
						if trailAttach1 then
							trailAttach1:Destroy()
						end
					end
				end
				local function fn55(parent)
					local humanoidRootPart = parent and parent:FindFirstChild("HumanoidRootPart")
					if not humanoidRootPart then
						return
					end
					fn54(parent)
					local attachment = Instance.new("Attachment")
					attachment.Name = "TrailAttach0"
					attachment.Position = Vector3.new(0, 2, 0)
					attachment.Parent = humanoidRootPart
					local attachment2 = Instance.new("Attachment")
					attachment2.Name = "TrailAttach1"
					attachment2.Position = Vector3.new(0, -2, 0)
					attachment2.Parent = humanoidRootPart
					local trail = Instance.new("Trail")
					trail.Attachment0 = attachment
					trail.Attachment1 = attachment2
					trail.Lifetime = lifetime
					trail.LightEmission = 0.2
					trail.Enabled = true
					local new = NumberSequenceKeypoint.new
					trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, n26), new(1, 1) })
					if flag15 then
						trail.Color = ColorSequence.new(color3, color4)
					else
						trail.Color = ColorSequence.new(color2)
					end
					trail.Parent = parent
					tbl9[parent] = trail
				end
				local flag16 = false
				local flag17 = false
				pcall(function() getgenv().__KRP_VIS_FX:AddDivider() end)
				hatSec:AddLabel("China Hat"):AddToggle({
					Flag = "WR14",
					Default = false,
					Callback = function(arg)
						pcall(function()
						end)
						flag16 = arg
						if arg then
							fn53(localPlayer.Character)
						else
							fn52(localPlayer.Character)
						end
					end,
				})
				hatSec:AddLabel("Hat Transparency"):AddSlider({
					Flag = "WR15",
					Min = 0,
					Max = 100,
					Default = 30,
					Rounding = 0,
					Callback = function(arg)
						transparency = arg / 100
						for _, v48 in pairs(tbl8) do
							if v48.Parent then
								v48.Transparency = transparency
							end
						end
					end,
				})
				hatSec:AddLabel("Hat Rainbow"):AddToggle({
					Flag = "WR16",
					Default = false,
					Callback = function(arg)
						pcall(function()
						end)
						flag13 = arg
					end,
				})
				hatSec:AddLabel("Hat Color"):AddColorPicker({
					Flag = "WR17",
					Default = color,
					Callback = function(arg)
						color = arg
						for _, v48 in pairs(tbl8) do
							if v48.Parent then
								v48.Color = color
							end
						end
					end,
				})
				localPlayer.CharacterAdded:Connect(function(character)
					task.wait(0.5)
					if flag17 then
						pcall(function()
							fn55(character)
						end)
					end
				end)
				pcall(function() getgenv().__KRP_VIS_FX:AddDivider() end)
				trailSec:AddLabel("Trail"):AddToggle({
					Flag = "WR18",
					Default = false,
					Callback = function(arg)
						pcall(function()
						end)
						flag17 = arg
						if arg then
							fn55(localPlayer.Character)
						else
							fn54(localPlayer.Character)
						end
					end,
				})
				trailSec:AddLabel("Trail Lifetime"):AddSlider({
					Flag = "WR19",
					Min = 1,
					Max = 30,
					Default = 5,
					Rounding = 0,
					Callback = function(arg)
						lifetime = arg / 10
						for _, v48 in pairs(tbl9) do
							if v48.Parent then
								v48.Lifetime = lifetime
							end
						end
					end,
				})
				trailSec:AddLabel("Trail Fade Start"):AddSlider({
					Flag = "WR20",
					Min = 0,
					Max = 100,
					Default = 0,
					Rounding = 0,
					Callback = function(arg)
						n26 = arg / 100
						for _, v48 in pairs(tbl9) do
							if v48.Parent then
								local new = NumberSequenceKeypoint.new
								v48.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, n26), new(1, 1) })
							end
						end
					end,
				})
				trailSec:AddLabel("Trail Gradient"):AddToggle({
					Flag = "WR21",
					Default = false,
					Callback = function(arg)
						pcall(function()
						end)
						flag15 = arg
						for _, v48 in pairs(tbl9) do
							if v48.Parent then
								v48.Color = flag15 and ColorSequence.new(color3, color4) or ColorSequence.new(color2)
							end
						end
					end,
				})
				trailSec:AddLabel("Trail Rainbow"):AddToggle({
					Flag = "WR22",
					Default = false,
					Callback = function(arg)
						pcall(function()
						end)
						flag14 = arg
					end,
				})
				trailSec:AddLabel("Trail Color"):AddColorPicker({
					Flag = "WR23",
					Default = color2,
					Callback = function(arg)
						color2 = arg
						if not flag15 then
							for _, v48 in pairs(tbl9) do
								if v48.Parent then
									v48.Color = ColorSequence.new(color2)
								end
							end
						end
					end,
				})
				trailSec:AddLabel("Trail Gradient 1"):AddColorPicker({
					Flag = "WR24",
					Default = color3,
					Callback = function(arg)
						color3 = arg
						if flag15 then
							for _, v48 in pairs(tbl9) do
								if v48.Parent then
									v48.Color = ColorSequence.new(color3, color4)
								end
							end
						end
					end,
				})
				trailSec:AddLabel("Trail Gradient 2"):AddColorPicker({
					Flag = "WR25",
					Default = color4,
					Callback = function(arg)
						color4 = arg
						if flag15 then
							for _, v48 in pairs(tbl9) do
								if v48.Parent then
									v48.Color = ColorSequence.new(color3, color4)
								end
							end
						end
					end,
				})
				localPlayer.CharacterAdded:Connect(function(character)
					task.spawn(function()
						local head = character:WaitForChild("Head", 5)
						local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
						task.wait(0.25)
						local v48 = flag16
						if not flag16 then
							head = v48
						end
						if head then
							fn53(character)
						end
						local v49 = flag17
						if not flag17 then
							humanoidRootPart = v49
						end
						if humanoidRootPart then
							fn55(character)
						end
					end)
				end)
				task.spawn(function()
					while true do
						task.wait(0.05)
						if next(tbl8) == nil and next(tbl9) == nil then
							continue
						end
						for k, v48 in pairs(tbl8) do
							if v48 and v48.Parent and k == localPlayer.Character then
								v48.Transparency = transparency
								v48.Color = flag13 and Color3.fromHSV(tick() % 6 / 6, 1, 1) or color
							end
						end
						for k, v48 in pairs(tbl9) do
							if v48 and v48.Parent and k == localPlayer.Character then
								v48.Lifetime = lifetime
								v48.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, n26), NumberSequenceKeypoint.new(1, 1) })
								if flag15 then
									v48.Color = ColorSequence.new(color3, color4)
									continue
								end
								v48.Color = ColorSequence.new(flag14 and Color3.fromHSV(tick() % 6 / 6, 1, 1) or color2)
							end
						end
					end
				end)
			end
    end)
    if not okW then warn("[wraith visuals] " .. tostring(errW)) end
    end
    local moveBox = wrapContainer(getgenv().__KRP_PLAYER_BOX or Sink)
    local function block(name, fn)
        local ok, err = pcall(fn)
        if not ok then warn("[Kirpich] block '" .. name .. "' failed: " .. tostring(err)) end
    end
    block("player", function()
do
	local players = game:GetService("Players")
	local run = game:GetService("RunService")
	local uis = game:GetService("UserInputService")
	local vu = game:GetService("VirtualUser")
	local ws = workspace
	local lp = players.LocalPlayer
	local function get_hrp()
		local c = lp.Character
		return c and c:FindFirstChild("HumanoidRootPart")
	end
	local anti_afk = false
	local fly_on = false
	local fly_speed = 60
	local fly_gravity = ws.Gravity
	local fly_up_on, fly_down_on = true, true
	local fly_up_kc, fly_down_kc = Enum.KeyCode.Space, Enum.KeyCode.LeftControl
	local jump_hold_t = 0
	local idle_conn = lp.Idled:Connect(function()
		if anti_afk then
			pcall(function()
				vu:CaptureController()
				vu:ClickButton2(Vector2.new())
			end)
		end
	end)
	local controls_ref = nil
	local function get_controls()
		if controls_ref then return controls_ref end
		local ok, res = pcall(function()
			local ps = lp:FindFirstChild("PlayerScripts")
			local pm = ps and ps:FindFirstChild("PlayerModule")
			if not pm then return nil end
			return require(pm):GetControls()
		end)
		if ok and res then controls_ref = res end
		return controls_ref
	end
	local function flat_unit(v)
		local f = Vector3.new(v.X, 0, v.Z)
		if f.Magnitude > 0 then return f.Unit end
		return Vector3.zero
	end
	local function get_move_vector(cam)
		local c = get_controls()
		if c then
			local ok, v = pcall(function() return c:GetMoveVector() end)
			if ok and typeof(v) == "Vector3" and v.Magnitude > 0.05 then
				return v
			end
		end
		local ch = lp.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum and cam then
			local md = hum.MoveDirection
			if md.Magnitude > 0.05 then
				local ff, fr = flat_unit(cam.CFrame.LookVector), flat_unit(cam.CFrame.RightVector)
				return Vector3.new(md:Dot(fr), 0, -md:Dot(ff))
			end
		end
		return Vector3.zero
	end
	local jump_conn = uis.JumpRequest:Connect(function()
		jump_hold_t = os.clock()
	end)
	local fly_conn = run.RenderStepped:Connect(function()
		if not fly_on then return end
		local h = get_hrp()
		if not h then return end
		local cam = ws.CurrentCamera
		local dir = Vector3.zero
		if uis:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
		if uis:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
		if uis:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
		if uis:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
		local mv = get_move_vector(cam)
		if mv.Magnitude > 0.05 then
			dir = dir + cam.CFrame.LookVector * (-mv.Z) + cam.CFrame.RightVector * mv.X
		end
		local jump_held = (os.clock() - jump_hold_t) < 0.2
		if fly_up_on and (uis:IsKeyDown(fly_up_kc) or jump_held) then dir = dir + Vector3.yAxis end
		if fly_down_on and uis:IsKeyDown(fly_down_kc) then dir = dir - Vector3.yAxis end
		if dir.Magnitude > 0 then dir = dir.Unit * fly_speed end
		h.AssemblyLinearVelocity = dir
	end)
	getgenv().MISC_UNLOAD = function()
		anti_afk, fly_on = false, false
		if idle_conn then pcall(function() idle_conn:Disconnect() end) idle_conn = nil end
		if fly_conn then pcall(function() fly_conn:Disconnect() end) fly_conn = nil end
		if jump_conn then pcall(function() jump_conn:Disconnect() end) jump_conn = nil end
		ws.Gravity = fly_gravity
	end
	(function(target)
		local fly = target:AddToggle({
			Name = "fly",
			Default = false,
			Flag = "Fly",
			Option = true,
			Callback = function(v)
				fly_on = v
				if v then
					ws.Gravity = 0
				else
					ws.Gravity = fly_gravity
					local h = get_hrp()
					if h then h.AssemblyLinearVelocity = Vector3.zero end
				end
			end
		})
		fly.Option:AddSlider({
			Name = "speed",
			Default = 60,
			Min = 10,
			Max = 300,
			Round = 0,
			Flag = "misc_fly_speed",
			Callback = function(v)
				fly_speed = v
			end
		})
		fly.Option:AddToggle({
			Name = "up",
			Default = true,
			Flag = "FluUp",
			Callback = function(v)
				fly_up_on = v
			end
		})
		fly.Option:AddToggle({
			Name = "down",
			Default = true,
			Flag = "FlyDown",
			Callback = function(v)
				fly_down_on = v
			end
		})
		fly.Option:AddKeybind({
			Name = "up",
			Default = "Space",
			Flag = "misc_fly_up_key",
			Callback = function(k)
				local ok, kc = pcall(function() return Enum.KeyCode[k] end)
				if ok and kc then fly_up_kc = kc end
			end
		})
		fly.Option:AddKeybind({
			Name = "down",
			Default = "LeftControl",
			Flag = "misc_fly_down_key",
			Callback = function(k)
				local ok, kc = pcall(function() return Enum.KeyCode[k] end)
				if ok and kc then fly_down_kc = kc end
			end
		})
	end)(moveBox)
	moveBox:AddToggle({
		Name = "anti afk",
		Default = false,
		Flag = "Afk",
		ToolTip = "Prevents the idle kick",
		Callback = function(v)
			anti_afk = v
		end
	})
end
    end)
    block("player mods", function()
do
	local run = game:GetService("RunService")
	local ws = workspace
	local lp = game:GetService("Players").LocalPlayer
	local fov_on, fov_value = false, 70
	local fov_original = nil
	local fov_conn = nil
	(function(target)
		local customfov = target:AddToggle({
			Name = "custom fov",
			Default = false,
			Flag = "Custom Fov",
			Option = true,
			Callback = function(v)
				fov_on = v
				local cam = ws.CurrentCamera
				if v then
					if cam then
						fov_original = cam.FieldOfView
						cam.FieldOfView = fov_value
					end
					if not fov_conn then
						fov_conn = run.RenderStepped:Connect(function()
							if fov_on then
								local camera = ws.CurrentCamera
								if camera and camera.FieldOfView ~= fov_value then
									camera.FieldOfView = fov_value
								end
							end
						end)
					end
				else
					if cam and fov_original then
						cam.FieldOfView = fov_original
					end
					if fov_conn then
						pcall(function() fov_conn:Disconnect() end)
						fov_conn = nil
					end
				end
			end
		})
		customfov.Option:AddSlider({
			Name = "Value",
			Default = 70,
			Min = 30,
			Max = 120,
			Round = 0,
			Flag = "char_fov_value",
			Callback = function(v)
				fov_value = v
				if fov_on then
					local cam = ws.CurrentCamera
					if cam then
						cam.FieldOfView = v
					end
				end
			end
		})
	end)(moveBox)
	lp.CharacterAdded:Connect(function()
		task.wait(0.1)
		if fov_on then
			local cam = ws.CurrentCamera
			if cam then
				if not fov_original then fov_original = cam.FieldOfView end
				cam.FieldOfView = fov_value
			end
		end
	end)
	getgenv().CHARACTER_UNLOAD = function()
		fov_on = false
		if fov_conn then pcall(function() fov_conn:Disconnect() end) fov_conn = nil end
		local cam = ws.CurrentCamera
		if cam and fov_original then pcall(function() cam.FieldOfView = fov_original end) end
	end
end
    end)
end
runBlock("angel wings", function()
    local lp = game:GetService("Players").LocalPlayer
    local on = false
    local holder
    local function emitter(parent, tex, rate, transp)
        local p = Instance.new("ParticleEmitter")
        p.Texture = tex
        p.Rate = rate
        p.Lifetime = NumberRange.new(1, 2)
        p.Speed = NumberRange.new(2.5)
        p.Acceleration = Vector3.new(0, -6, 0)
        p.EmissionDirection = Enum.NormalId.Front
        p.LightEmission = 1
        p.LightInfluence = 1
        p.LockedToPart = true
        p.RotSpeed = NumberRange.new(-100, 100)
        p.Rotation = NumberRange.new(-360, 360)
        p.SpreadAngle = Vector2.new(0, 360)
        p.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5, 0.3), NumberSequenceKeypoint.new(1, 0.5, 0.3)})
        local keys = {}
        for i = 1, #transp, 3 do keys[#keys + 1] = NumberSequenceKeypoint.new(transp[i], transp[i + 1], transp[i + 2]) end
        p.Transparency = NumberSequence.new(keys)
        p.Parent = parent
    end
    local function beam(parent, a0, a1, curve)
        local b = Instance.new("Beam")
        b.Attachment0, b.Attachment1 = a0, a1
        b.Texture = "rbxassetid://9544400688"
        b.TextureSpeed = 0
        b.LightEmission = 1
        b.LightInfluence = 1
        b.CurveSize0, b.CurveSize1 = curve, curve
        b.Width0, b.Width1 = 4, 6
        b.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0)})
        b.Parent = parent
    end
    local function att(parent, name, pos)
        local a = Instance.new("Attachment")
        a.Name, a.Position, a.Parent = name, pos, parent
        return a
    end
    local function destroyHolder()
        if holder then holder:Destroy() holder = nil end
    end
    local function build(char)
        destroyHolder()
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if not torso then return end
        holder = Instance.new("Folder")
        holder.Name = "KirpichAngel"
        holder.Parent = char
        local halo = att(torso, "AngelHalo", Vector3.new(0, 4.25, 0))
        emitter(halo, "rbxassetid://7511321694", 50, {0,1,0, 0.1,1,0, 0.3,0,0, 0.8,0,0, 1,1,0})
        emitter(halo, "rbxassetid://1084976679", 100, {0,1,0, 0.2,0,0, 0.8,0,0, 1,1,0})
        local light = Instance.new("PointLight")
        light.Brightness, light.Range = 4, 5
        light.Parent = torso
        local center = att(torso, "AngelWingCenter", Vector3.new(0, 0.75, 0.5))
        local tipL = att(torso, "AngelWingTipL", Vector3.new(-5.25, 0, 2))
        local tipR = att(torso, "AngelWingTipR", Vector3.new(5.25, 0, 2))
        beam(holder, center, tipL, 2)
        beam(holder, center, tipR, -2)
    end
    local function apply()
        local char = lp.Character
        if on and char then build(char) else destroyHolder() end
    end
    local grp = Tabs.Visuals:AddRightGroupbox("Angel Wings", "feather")
    grp:AddToggle("AngelWings", {
        Text = "Angel Wings",
        Default = false,
        Callback = function(v)
            on = v
            apply()
        end,
    })
    lp.CharacterAdded:Connect(function(c)
        holder = nil
        task.wait(0.5)
        if on then build(c) end
    end)
end)
runBlock("xray", function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local ws = workspace
    local on, strength = false, 0.7
    local original = {}
    local queue, qi = {}, 1
    local function eligible(part)
        if not part:IsA("BasePart") or part:IsA("Terrain") or part.Transparency >= 1 then return false end
        local m = part:FindFirstAncestorWhichIsA("Model")
        while m do
            if Players:GetPlayerFromCharacter(m) then return false end
            m = m.Parent and m.Parent:FindFirstAncestorWhichIsA("Model") or nil
        end
        return true
    end
    local function apply(part)
        if original[part] == nil and part.Parent and eligible(part) then
            original[part] = part.Transparency
            part.Transparency = part.Transparency + (1 - part.Transparency) * strength
        end
    end
    local function refresh()
        for part, t in pairs(original) do
            if part.Parent then
                part.Transparency = t + (1 - t) * strength
            else
                original[part] = nil
            end
        end
    end
    local function restore()
        for part, t in pairs(original) do
            if part.Parent then part.Transparency = t end
            original[part] = nil
        end
        queue, qi = {}, 1
    end
    local conn = RunService.Heartbeat:Connect(function()
        if not on then return end
        local n = 0
        while qi <= #queue and n < 300 do
            local part = queue[qi]
            qi += 1
            n += 1
            if part then apply(part) end
        end
        if qi > #queue then queue, qi = {}, 1 end
    end)
    ws.DescendantAdded:Connect(function(part)
        if on and part:IsA("BasePart") then table.insert(queue, part) end
    end)
    local grp = Tabs.Visuals:AddRightGroupbox("X-Ray", "eye-off")
    grp:AddToggle("XRayOn", {
        Text = "X-Ray",
        Default = false,
        Callback = function(v)
            on = v
            if v then
                queue, qi = ws:GetDescendants(), 1
            else
                restore()
            end
        end,
    })
    grp:AddSlider("XRayStrength", {
        Text = "Strength", Default = 70, Min = 10, Max = 100, Rounding = 0, Suffix = "%",
        Callback = function(v)
            strength = v / 100
            refresh()
        end,
    })
end)
runBlock("weather", function()
    local RunService = game:GetService("RunService")
    local ws = workspace
    local lp = game:GetService("Players").LocalPlayer
    local TEX = {
        soft = "rbxassetid://118641183", fine = "rbxassetid://247944275", petal = "rbxassetid://243160943",
        petal2 = "rbxassetid://243344623", leaf = "rbxassetid://5057182105", fog = "rbxassetid://248376121",
        fog2 = "rbxassetid://292289455", glow = "rbxassetid://243664672", dot = "rbxassetid://9829889760",
    }
    local COLOR = {
        Snow = Color3.fromRGB(240, 246, 255), Petal = Color3.fromRGB(255, 255, 255), Leaf = Color3.fromRGB(255, 255, 255),
        Firefly = Color3.fromRGB(196, 255, 96), Mist = Color3.fromRGB(214, 222, 232), Ember = Color3.fromRGB(255, 140, 44),
        Ash = Color3.fromRGB(168, 164, 160), Pollen = Color3.fromRGB(255, 238, 190),
    }
    local RECIPES = {
        Snow = { colour = "Snow", layers = {
            { tex = "soft", y = 12, h = 30, reach = 1.25, rate = {140, 950}, life = {8, 11}, speed = {0.4, 1.4}, fall = 2.6, size = {0.16, 0.3}, alpha = 0.97, spread = 180 },
            { tex = "soft", y = 8, h = 16, reach = 0.55, rate = {6, 70}, life = {6, 9}, speed = {0.3, 1}, fall = 2.2, size = {0.3, 0.46}, alpha = 0.9, spread = 180 },
            { tex = "fine", y = 14, h = 34, reach = 1.5, rate = {40, 300}, life = {9, 12}, speed = {0.2, 0.8}, fall = 3, size = {0.12, 0.2}, alpha = 0.9, spread = 180 },
            { tex = "fog", ground = true, y = 1.8, h = 4, reach = 1.5, rate = {0.1, 1}, life = {8, 12}, speed = {0.3, 0.9}, size = {16, 28}, alpha = 0.08, spread = 180 },
        }},
        Blossom = { colour = "Petal", layers = {
            { tex = "petal", y = 12, h = 28, reach = 1.4, rate = {5, 60}, life = {10, 14}, speed = {0, 0}, fall = 1.7, size = {0.42, 0.7}, alpha = 1, spread = 30, rot = 150 },
            { tex = "petal2", y = 8, h = 16, reach = 0.7, rate = {3, 36}, life = {8, 11}, speed = {0, 0}, fall = 1.7, size = {0.34, 0.54}, alpha = 1, spread = 30, rot = 170 },
        }},
        Leaves = { colour = "Leaf", layers = {
            { tex = "leaf", y = 12, h = 28, reach = 1.4, rate = {5, 46}, life = {10, 14}, speed = {0, 0}, fall = 2.8, size = {0.7, 1.15}, alpha = 1, spread = 30, rot = 220, col = Color3.fromRGB(255, 150, 60) },
            { tex = "leaf", y = 10, h = 24, reach = 1.2, rate = {4, 38}, life = {10, 14}, speed = {0, 0}, fall = 2.8, size = {0.64, 1.05}, alpha = 1, spread = 30, rot = 200, col = Color3.fromRGB(235, 90, 50) },
            { tex = "leaf", y = 8, h = 18, reach = 0.7, rate = {3, 28}, life = {8, 11}, speed = {0, 0}, fall = 2.8, size = {0.78, 1.25}, alpha = 1, spread = 30, rot = 180, col = Color3.fromRGB(255, 205, 80) },
        }},
        Fireflies = { colour = "Firefly", layers = {
            { tex = "glow", ground = true, y = 3.6, h = 6.5, reach = 1.2, rate = {1.5, 16}, life = {5, 8}, speed = {0.3, 0.9}, size = {0.34, 0.6}, alpha = 1, spread = 180, glow = 1 },
            { tex = "glow", ground = true, y = 3.2, h = 5, reach = 0.8, rate = {0.5, 6}, life = {5, 8}, speed = {0.2, 0.6}, size = {1.4, 2.1}, alpha = 0.12, spread = 180, glow = 1 },
        }},
        Mist = { colour = "Mist", layers = {
            { tex = "fog", ground = true, y = 2, h = 4, reach = 1.7, rate = {0.6, 4}, life = {9, 13}, speed = {0.4, 1.1}, size = {18, 30}, alpha = 0.18, spread = 180, rot = 4 },
            { tex = "fog2", ground = true, y = 4, h = 5, reach = 1.5, rate = {0.3, 2}, life = {10, 14}, speed = {0.3, 0.8}, size = {22, 36}, alpha = 0.1, spread = 180, rot = 3 },
        }},
        Embers = { colour = "Ember", layers = {
            { tex = "glow", ground = true, y = 4, h = 8, reach = 1, rate = {4, 44}, life = {2.2, 4}, speed = {1.6, 3.4}, size = {0.16, 0.34}, alpha = 1, spread = 35, lift = 3.4, glow = 1 },
            { tex = "dot", ground = true, y = 3, h = 6, reach = 0.7, rate = {6, 70}, life = {1.2, 2.4}, speed = {2, 4.5}, size = {1.4, 2.4}, alpha = 1, spread = 40, lift = 3, glow = 1 },
        }},
        Ash = { colour = "Ash", layers = {
            { tex = "glow", y = 12, h = 28, reach = 1.3, rate = {12, 120}, life = {8, 12}, speed = {0, 0}, fall = 1.4, size = {0.16, 0.3}, alpha = 0.6, spread = 30, rot = 40 },
        }},
        Pollen = { colour = "Pollen", layers = {
            { tex = "glow", y = 5, h = 11, reach = 0.7, rate = {2, 26}, life = {6, 10}, speed = {0.1, 0.4}, size = {0.12, 0.24}, alpha = 0.9, spread = 180, glow = 1 },
        }},
    }
    local st = { on = false, kind = "Snow", amount = 60, opacity = 80, speed = 100, radius = 30 }
    local folder, nodes = nil, {}
    local function destroyAll()
        if folder then folder:Destroy() end
        folder, nodes = nil, {}
    end
    local function build()
        destroyAll()
        local recipe = RECIPES[st.kind]
        folder = Instance.new("Folder")
        folder.Name = "KirpichWeather"
        folder.Parent = ws
        local speedK = st.speed / 100
        local opK = st.opacity / 100
        for _, L in ipairs(recipe.layers) do
            local part = Instance.new("Part")
            part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
            part.Transparency = 1
            part.Parent = folder
            local em = Instance.new("ParticleEmitter")
            em.Texture = TEX[L.tex]
            local lo, hi = L.rate[1], L.rate[2]
            em.Rate = (lo + (hi - lo) * (st.amount / 100)) * (st.amount / 60)
            em.Lifetime = NumberRange.new(L.life[1], L.life[2])
            em.Speed = NumberRange.new(L.speed[1] * speedK, L.speed[2] * speedK)
            local a = L.alpha * opK
            em.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1 - a), NumberSequenceKeypoint.new(0.8, 1 - a), NumberSequenceKeypoint.new(1, 1),
            })
            em.Size = NumberSequence.new((L.size[1] + L.size[2]) / 2)
            em.Color = ColorSequence.new(L.col or COLOR[recipe.colour])
            em.SpreadAngle = Vector2.new(L.spread, L.spread)
            em.LightEmission = L.glow or 0
            em.Rotation = NumberRange.new(0, 360)
            em.RotSpeed = NumberRange.new(-(L.rot or 0), L.rot or 0)
            if L.lift then
                em.Acceleration = Vector3.new(0, L.lift, 0)
                em.EmissionDirection = Enum.NormalId.Top
            else
                em.Acceleration = Vector3.new(0, -(L.fall or 0), 0)
                em.EmissionDirection = Enum.NormalId.Bottom
            end
            em.Parent = part
            table.insert(nodes, { part = part, L = L })
        end
    end
    RunService.Heartbeat:Connect(function()
        if not st.on or not folder then return end
        local cam = ws.CurrentCamera
        if not cam then return end
        local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        local camPos = cam.CFrame.Position
        for _, n in ipairs(nodes) do
            local L = n.L
            local tile = st.radius * 2 * L.reach
            local baseY = (L.ground and hrp) and (hrp.Position.Y - 3) or (camPos.Y - 2)
            local cx = (L.ground and hrp) and hrp.Position.X or camPos.X
            local cz = (L.ground and hrp) and hrp.Position.Z or camPos.Z
            n.part.Size = Vector3.new(tile, L.h, tile)
            n.part.CFrame = CFrame.new(cx, baseY + L.y, cz)
        end
    end)
    local grp = Tabs.Visuals:AddRightGroupbox("Weather", "cloud-snow")
    grp:AddToggle("WeatherOn", {
        Text = "Weather", Default = false,
        Callback = function(v)
            st.on = v
            if v then build() else destroyAll() end
        end,
    })
    grp:AddDropdown("WeatherKind", {
        Text = "Kind", Values = {"Snow", "Blossom", "Leaves", "Fireflies", "Mist", "Embers", "Ash", "Pollen"}, Default = "Snow",
        Callback = function(v)
            st.kind = v
            if st.on then build() end
        end,
    })
    local function rebuildOnChange(key)
        return function(v)
            st[key] = v
            if st.on then build() end
        end
    end
    grp:AddSlider("WeatherAmount", { Text = "Amount", Default = 60, Min = 0, Max = 100, Rounding = 0, Callback = rebuildOnChange("amount") })
    grp:AddSlider("WeatherOpacity", { Text = "Opacity", Default = 80, Min = 20, Max = 100, Rounding = 0, Callback = rebuildOnChange("opacity") })
    grp:AddSlider("WeatherSpeed", { Text = "Speed", Default = 100, Min = 60, Max = 150, Rounding = 0, Callback = rebuildOnChange("speed") })
    grp:AddSlider("WeatherRadius", { Text = "Radius", Default = 30, Min = 12, Max = 50, Rounding = 0, Callback = rebuildOnChange("radius") })
end)
runBlock("anti-aim", function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local RS = game:GetService("ReplicatedStorage")
    local lp = Players.LocalPlayer
    local st = {
        on = false, dir = "Random", power = 5, smart = true, vel = true, md = true,
        active = false, savedVel = nil, spoofVel = nil, savedDir = nil, spoofDir = nil,
        angle = 0, flip = 1, jitterDir = nil, jitterUntil = 0,
        moveDir = nil, moveUntil = 0, roles = {}, remote = nil,
    }
    task.spawn(function()
        while true do
            pcall(function()
                if not st.remote or not st.remote.Parent then
                    st.remote = RS:FindFirstChild("GetPlayerData", true)
                end
                if st.remote and st.remote:IsA("RemoteFunction") then
                    local ok, data = pcall(st.remote.InvokeServer, st.remote)
                    if ok and type(data) == "table" then st.roles = data end
                end
            end)
            task.wait(0.5)
        end
    end)
    local function restore()
        if not st.active then return end
        st.active = false
        local root, hum = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart"), lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
        if st.spoofVel and st.savedVel and root and root.Parent then
            root.AssemblyLinearVelocity = st.savedVel
        end
        if st.spoofDir and st.savedDir and hum and hum.Parent then
            if (hum.MoveDirection - st.spoofDir).Magnitude < 0.05 then hum:Move(st.savedDir, false) end
        end
        st.savedVel, st.spoofVel, st.savedDir, st.spoofDir = nil, nil, nil, nil
    end
    local function r() return math.random() * 2 - 1 end
    local function spoofVector(power)
        if st.dir == "Underground" then return Vector3.new(r() * power * 0.15, -power, r() * power * 0.15) end
        if st.dir == "Sky" then return Vector3.new(r() * power * 0.15, power, r() * power * 0.15) end
        if st.dir == "Spin" then
            st.angle = (st.angle + 0.9 + math.random() * 0.6) % (2 * math.pi)
            return Vector3.new(math.cos(st.angle) * power, r() * power * 0.35, math.sin(st.angle) * power)
        end
        if st.dir == "Jitter" then
            local now = os.clock()
            if not st.jitterDir or now >= st.jitterUntil then
                local d = Vector3.new(r(), r() * 0.4, r())
                st.jitterDir = d.Magnitude > 0.1 and d.Unit or Vector3.xAxis
                st.jitterUntil = now + 0.25 + math.random() * 0.25
            end
            st.flip = -st.flip
            return st.jitterDir * (power * 1.6 * st.flip)
        end
        return Vector3.new((math.random() < 0.5 and -1 or 1) * power, r() * power, (math.random() < 0.5 and -1 or 1) * power)
    end
    local function shouldPause(char)
        if not st.smart then return false end
        return char:FindFirstChildOfClass("Tool") ~= nil and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    end
    local function clamp32(v) return math.clamp(v, -32767, 32767) end
    RunService.PreSimulation:Connect(restore)
    RunService.Heartbeat:Connect(function()
        if not st.on then restore(); return end
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 or hum.Sit then return end
        local role = st.roles[lp.Name]
        if type(role) ~= "table" or role.Dead == true or role.Killed == true then return end
        if shouldPause(char) then restore(); return end
        local power = 32767 * math.clamp(st.power, 1, 10) / 10
        local spoof = spoofVector(power)
        if st.vel then
            st.savedVel = root.AssemblyLinearVelocity
            st.spoofVel = Vector3.new(clamp32(spoof.X), clamp32(spoof.Y), clamp32(spoof.Z))
            root.AssemblyLinearVelocity = st.spoofVel
        end
        if st.md then
            local now = os.clock()
            if not st.moveDir or now >= st.moveUntil then
                local a = math.random() * 2 * math.pi
                st.moveDir = Vector3.new(math.cos(a), 0, math.sin(a))
                st.moveUntil = now + 0.15 + math.random() * 0.3
            end
            st.savedDir, st.spoofDir = hum.MoveDirection, st.moveDir
            hum:Move(st.moveDir, false)
        end
        st.active = st.vel or st.md
    end)
    local grp = Tabs.Main:AddRightGroupbox("Anti-Aim", "shield")
    grp:AddToggle("AntiAimOn", {
        Text = "Anti Aim", Default = false,
        Callback = function(v)
            st.on = v
            if not v then restore() end
        end,
    })
    grp:AddDropdown("AntiAimDir", {
        Text = "Direction", Values = {"Random", "Jitter", "Spin", "Underground", "Sky"}, Default = "Random",
        Callback = function(v) st.dir = v end,
    })
    grp:AddSlider("AntiAimPower", {
        Text = "Spoof Strength", Default = 5, Min = 1, Max = 10, Rounding = 0,
        Callback = function(v) st.power = v end,
    })
    grp:AddToggle("AntiAimSmart", {
        Text = "Smart Pause", Default = true,
        Callback = function(v) st.smart = v end,
    })
    grp:AddToggle("AntiAimVel", {
        Text = "Spoof Velocity", Default = true,
        Callback = function(v) st.vel = v; if not v then restore() end end,
    })
    grp:AddToggle("AntiAimMove", {
        Text = "Spoof Move Direction", Default = true,
        Callback = function(v) st.md = v; if not v then restore() end end,
    })
end)
runBlock("anti-coin", function()
    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local ws = workspace
    local lp = Players.LocalPlayer
    local enabled, strict = false, false
    local coins = setmetatable({}, { __mode = "k" })
    local charParts = setmetatable({}, { __mode = "k" })
    getgenv().__KRP_ANTICOIN = false
    local function blockCoin(part)
        if not part:IsA("BasePart") then return end
        if coins[part] == nil then coins[part] = part.CanTouch end
        if part.CanTouch then part.CanTouch = false end
    end
    local function scanCoins()
        for _, map in ipairs(ws:GetChildren()) do
            local container = map:FindFirstChild("CoinContainer")
            if container then
                for _, part in ipairs(container:GetChildren()) do pcall(blockCoin, part) end
            end
        end
    end
    local function blockCharacter()
        local char = lp.Character
        if not char then return end
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                if charParts[part] == nil then charParts[part] = part.CanTouch end
                if part.CanTouch then pcall(function() part.CanTouch = false end) end
            end
        end
    end
    local function restore()
        for part, original in pairs(coins) do
            if part.Parent then pcall(function() part.CanTouch = original end) end
            coins[part] = nil
        end
        for part, original in pairs(charParts) do
            if part.Parent then pcall(function() part.CanTouch = original end) end
            charParts[part] = nil
        end
        strict = false
    end
    local function setEnabled(v)
        enabled = not not v
        getgenv().__KRP_ANTICOIN = enabled
        if enabled then pcall(scanCoins) else restore() end
    end
    ws.DescendantAdded:Connect(function(part)
        if enabled and part.Parent and part.Parent.Name == "CoinContainer" then pcall(blockCoin, part) end
    end)
    lp.CharacterAdded:Connect(function()
        if not enabled or not strict then return end
        task.wait(0.5)
        pcall(blockCharacter)
    end)
    task.spawn(function()
        local gameplay
        while not gameplay do
            local remotes = RS:FindFirstChild("Remotes", true)
            gameplay = remotes and remotes:FindFirstChild("Gameplay")
            if not gameplay then task.wait(1) end
        end
        local collected = gameplay:FindFirstChild("CoinCollected")
        if not collected then return end
        collected.OnClientEvent:Connect(function()
            if not enabled or strict then return end
            strict = true
            pcall(blockCharacter)
        end)
    end)
    task.spawn(function()
        while true do
            task.wait(0.5)
            if enabled then
                pcall(scanCoins)
                if strict then pcall(blockCharacter) end
            end
        end
    end)
    local grp = Tabs.Main:AddRightGroupbox("Anti-Coin", "coins")
    grp:AddToggle("AntiCoinOn", {
        Text = "Anti Coin", Default = false,
        Callback = setEnabled,
    })
end)
runBlock("role farm", function()
    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local lp = Players.LocalPlayer
    local roles = {}
    task.spawn(function()
        local remote
        while true do
            pcall(function()
                if not remote or not remote.Parent then remote = RS:FindFirstChild("GetPlayerData", true) end
                if remote and remote:IsA("RemoteFunction") then
                    local ok, data = pcall(remote.InvokeServer, remote)
                    if ok and type(data) == "table" then roles = data end
                end
            end)
            task.wait(0.5)
        end
    end)
    local st = { murder = false, sheriff = false, innocent = false, lastStab = 0, lastShot = 0, lastGrab = 0 }
    local function myRole()
        local r = roles[lp.Name]
        if type(r) ~= "table" or not r.Role or r.Dead == true or r.Killed == true then return nil end
        return tostring(r.Role):lower()
    end
    local function aliveChar()
        local c = lp.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if c and h and h.Health > 0 then return c, h end
    end
    local function murdererAlive()
        for name, r in pairs(roles) do
            if type(r) == "table" and r.Role and tostring(r.Role):lower():find("murder")
                and r.Dead ~= true and r.Killed ~= true and name ~= lp.Name then
                return true
            end
        end
        return false
    end
    local function equipKnife()
        local c, h = aliveChar()
        if not c then return nil end
        local knife = c:FindFirstChild("Knife")
        if knife then return knife end
        local bp = lp:FindFirstChildOfClass("Backpack")
        local stored = bp and bp:FindFirstChild("Knife")
        if stored then pcall(function() h:EquipTool(stored) end) end
        return c:FindFirstChild("Knife")
    end
    local function stabAll()
        local knife = equipKnife()
        if not knife or not firetouchinterest then return end
        local handle = knife:FindFirstChild("Handle") or knife:FindFirstChildWhichIsA("BasePart")
        if not handle then return end
        local hit = 0
        for _, p in ipairs(Players:GetPlayers()) do
            local r = p ~= lp and roles[p.Name]
            local c = p.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if type(r) == "table" and r.Dead ~= true and r.Killed ~= true and h and h.Health > 0 then
                hit += 1
                for _, name in ipairs({ "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso", "Head" }) do
                    local part = c:FindFirstChild(name)
                    if part then
                        pcall(function()
                            firetouchinterest(handle, part, 0); firetouchinterest(handle, part, 1)
                        end)
                    end
                end
            end
        end
        if hit > 0 then pcall(function() knife:Activate() end) end
    end
    local function shootMurderer()
        local hook = rawget(getgenv(), "__KRP_SHOOT")
        if type(hook) == "function" then pcall(hook) end
    end
    local function grabGun()
        local drop = workspace:FindFirstChild("GunDrop", true)
        if not drop then return end
        local part = drop:IsA("BasePart") and drop
            or (drop:IsA("Model") and (drop.PrimaryPart or drop:FindFirstChildWhichIsA("BasePart", true)))
        if not part then return end
        local c = aliveChar()
        if not c or c:FindFirstChild("Gun") then return end
        local root = c:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local saved = root.CFrame
        local started = os.clock()
        while os.clock() - started < 1.2 and part.Parent and not c:FindFirstChild("Gun") do
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.zero
                root.CFrame = CFrame.new(part.Position + Vector3.new(0, 2.5, 0))
            end)
            if firetouchinterest then
                for _, cp in ipairs(c:GetChildren()) do
                    if cp:IsA("BasePart") then
                        pcall(function() firetouchinterest(cp, part, 0); firetouchinterest(cp, part, 1) end)
                    end
                end
            end
            RunService.Heartbeat:Wait()
        end
        pcall(function() root.CFrame = saved end)
    end
    task.spawn(function()
        while true do
            task.wait(0.15)
            pcall(function()
                if not (st.murder or st.sheriff or st.innocent) then return end
                local role = myRole()
                if not role or not aliveChar() then return end
                local now = os.clock()
                if role:find("murder") then
                    if st.murder and now - st.lastStab >= 0.4 then
                        st.lastStab = now
                        stabAll()
                    end
                elseif role == "sheriff" then
                    if st.sheriff and now - st.lastShot >= 0.5 and murdererAlive() then
                        st.lastShot = now
                        shootMurderer()
                    end
                elseif role ~= "hero" then
                    local c = aliveChar()
                    if st.innocent and c and now - st.lastGrab >= 2 and not c:FindFirstChild("Gun") then
                        st.lastGrab = now
                        grabGun()
                    end
                end
            end)
        end
    end)
    local grp = Tabs.Main:AddRightGroupbox("Role Farm", "swords")
    grp:AddToggle("RoleFarmMurder", {
        Text = "Murderer: Stab All", Default = false,
        Callback = function(v) st.murder = v end,
    })
    grp:AddToggle("RoleFarmSheriff", {
        Text = "Sheriff: Shoot Murderer", Default = false,
        Callback = function(v) st.sheriff = v end,
    })
    grp:AddToggle("RoleFarmInnocent", {
        Text = "Innocent: Grab Gun", Default = false,
        Callback = function(v) st.innocent = v end,
    })
end)
runBlock("anti-glare", function()
    local Lighting = game:GetService("Lighting")
    local st = { on = false, darken = 45, orig = nil }
    local function apply()
        if not st.on then
            if st.orig then
                Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient = st.orig[1], st.orig[2], st.orig[3]
                st.orig = nil
            end
            return
        end
        if not st.orig then
            st.orig = { Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient }
        end
        local d = math.clamp(st.darken / 100, 0, 1)
        local black = Color3.new(0, 0, 0)
        Lighting.Brightness = st.orig[1] * (1 - d * 0.8)
        Lighting.Ambient = st.orig[2]:Lerp(black, d)
        Lighting.OutdoorAmbient = st.orig[3]:Lerp(black, d)
    end
    local grp = Tabs.Visuals:AddRightGroupbox("Anti-Glare", "sun")
    grp:AddToggle("AntiGlareOn", {
        Text = "Anti-Glare", Default = false,
        Callback = function(v)
            st.on = v
            apply()
        end,
    })
    grp:AddSlider("AntiGlareDarken", {
        Text = "Darken", Default = 45, Min = 0, Max = 100, Rounding = 0, Suffix = "%",
        Callback = function(v)
            st.darken = v
            apply()
        end,
    })
end)
do
    local Settings = Tabs.Settings
    local menu = Settings:AddLeftGroupbox("Menu", "settings")
    menu:AddLabel("Menu key"):AddKeyPicker("MenuKeybind", {
        Default = "RightShift",
        NoUI = true,
        Text = "Menu keybind",
    })
    Library.ToggleKeybind = Options.MenuKeybind
    menu:AddButton({
        Text = "Unload Script",
        Func = function()
            Library:Unload()
        end,
    })
    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    ThemeManager:SetFolder("Kirpich")
    SaveManager:SetFolder("Kirpich/mm2")
    SaveManager:BuildConfigSection(Settings)
    ThemeManager:ApplyToTab(Settings)
    pcall(function()
        SaveManager:LoadAutoloadConfig()
    end)
end
do
	local lib = Library
	local Settings = Tabs.Settings
	local notif = Settings:AddLeftGroupbox("<b>Notifications</b>", "bell-ring")
	notif:AddCheckbox("DisableNotifications", {
		Text = "Disable Notifications",
		Default = false,
		Callback = function(v)
			local st = getgenv().KirpichNotifState
			if st then st.disabled = v end
		end,
	})
	notif:AddDivider("Sound Settings")
	notif:AddDropdown("NotifPreset", {
		Text = "Presets",
		Values = { "IPhone", "Ding", "Steam Notification", "Steam Achievement", "Random Zap", "Soft", "Mobile", "Blump", "Alert", "Soundful", "Drum" },
		Default = "IPhone",
		AllowNull = false,
		ValueImages = {
			IPhone = "smartphone", Ding = "bell", ["Steam Notification"] = "message-square",
			["Steam Achievement"] = "trophy", ["Random Zap"] = "zap", Soft = "volume-1",
			Mobile = "phone-call", Blump = "bell-ring", Alert = "triangle-alert",
			Soundful = "volume-2", Drum = "music",
		},
	})
	notif:AddInput("NotifSoundID", {
		Text = "Sound ID",
		Default = "",
		Placeholder = "Enter Sound ID...",
		Numeric = true,
	})
	notif:AddCheckbox("UseCustomSoundID", {
		Text = "Set Sound ID Notification",
		Default = false,
	})
	notif:AddSlider("NotifVolume", {
		Text = "Notification Volume",
		Default = 5, Min = 0, Max = 10, Rounding = 0,
		Compact = true,
	})
	notif:AddButton({
		Text = "Send Test Notification",
		Func = function()
			lib:Notify({ Title = "<b>Kirpich</b>", Description = "Notification test", Time = 3 })
		end,
	})
	local disp = Settings:AddRightGroupbox("<b>Display Settings</b>", "monitor")
	disp:AddCheckbox("UseDefaultCursor", {
		Text = "Use Default Cursor",
		Default = false,
		Callback = function(v)
			lib.ShowCustomCursor = not v
			local sg = lib.ScreenGui
			local cursor = sg and sg:FindFirstChild("Cursor", true)
			if cursor then cursor.Visible = not v end
			if v then
				game:GetService("UserInputService").MouseIconEnabled = true
			end
		end,
	})
	disp:AddDivider()
	disp:AddSlider("CornerRadiusSlider", {
		Text = "Corner Radius",
		Default = 10, Min = 0, Max = 20, Rounding = 0,
		Callback = function(v)
			getgenv().KirpichApplyCorner(v)
		end,
	})
	disp:AddDropdown("GUIScale", {
		Text = "UI Scale",
		Default = "100",
		Values = { "75", "80", "85", "90", "95", "100", "105", "110", "115", "120", "125", "130", "140", "150", "160", "175", "200" },
		Callback = function(v)
			local n = tonumber(v)
			if n then
				lib:SetDPIScale(n)
				task.defer(function()
					task.wait(0.05)
					if _G._updateTabIndicatorVisibility then
						_G._updateTabIndicatorVisibility()
					end
				end)
			end
		end,
	})
	disp:AddDivider()
	disp:AddCheckbox("MenuOpenCloseAnim", {
		Text = "Menu ON / OFF Animation",
		Default = false,
		Callback = function(v)
			pcall(function()
				Window:SetAnimations({ ToggleWindow = v, TabSwitch = true, Groupbox = true, Dropdown = true, KeyPicker = true }, 0.35, 24, "auto")
			end)
		end,
	})
	disp:AddCheckbox("SmoothMenuDrag", {
		Text = "Smooth Menu Drag",
		Default = false,
		Callback = function(v)
			_G.SmoothMenuDrag = v
		end,
	})
	disp:AddDropdown("AdditionalFeaturesDropdown", {
		Text = "Additional Features",
		Values = { "Smooth Tab Swap", "Tab Swap Sound", "Tab Icon Bounce" },
		Multi = true,
		AllowNull = true,
		Default = { "Smooth Tab Swap", "Tab Swap Sound", "Tab Icon Bounce" },
		ValueImages = {
			["Smooth Tab Swap"] = "sparkles",
			["Tab Swap Sound"] = "volume-2",
			["Tab Icon Bounce"] = "zap",
		},
		Callback = function()
			if _G._updateTabIndicatorVisibility then
				_G._updateTabIndicatorVisibility()
			end
		end,
	})
	local wmFrame, wmApplyVis, wmSize
	do
		local RunService = game:GetService("RunService")
		local Players = game:GetService("Players")
		local lp = Players.LocalPlayer
		local bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
		local frame = Instance.new("Frame")
		frame.Name = "Watermark"
		frame.AutomaticSize = Enum.AutomaticSize.X
		frame.Size = UDim2.fromOffset(0, 32)
		frame.Position = UDim2.fromOffset(14, 20)
		frame.BackgroundColor3 = lib.Scheme.BackgroundColor
		frame.BackgroundTransparency = 0.2
		frame.BorderSizePixel = 0
		frame.ZIndex = 10
		frame.Active = true
		frame.Parent = lib.ScreenGui
		wmFrame = frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, lib.CornerRadius or 10)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Color = lib.Scheme.OutlineColor
		stroke.Transparency = 0.72
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Parent = frame
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = frame
		local icon = Instance.new("ImageLabel")
		icon.Name = "BrickIcon"
		icon.Size = UDim2.fromOffset(36, 36)
		icon.BackgroundTransparency = 1
		icon.Image = "rbxthumb://type=Asset&id=101625258941158&w=150&h=150"
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 11
		icon.Parent = frame
		local labels = {}
		local function mk(text, color, visible, parent)
			local t = Instance.new("TextLabel")
			t.AutomaticSize = Enum.AutomaticSize.X
			t.Size = UDim2.fromOffset(0, 32)
			t.BackgroundTransparency = 1
			t.Text = text
			t.TextColor3 = color or lib.Scheme.FontColor
			t.FontFace = bold
			t.TextSize = 16
			t.ZIndex = 11
			t.Visible = visible
			t.Parent = parent or frame
			table.insert(labels, t)
			return t
		end
		local green = Color3.fromHex("69ff00")
		local nameL = mk("KIRPICH", nil, true)
		local sep1 = mk(" ", nil, true)
		local fpsL = mk("60 FPS", green, true)
		local sep2 = mk(" ", nil, true)
		local pingL = mk("50 MS", green, true)
		local sep3 = mk(" ", nil, false)
		local verL = mk("v30", nil, false)
		local sep4 = mk(" ", nil, false)
		local timeL = mk("00:00", nil, false)
		local sep5 = mk(" ", nil, false)
		local acc = Instance.new("Frame")
		acc.AutomaticSize = Enum.AutomaticSize.X
		acc.Size = UDim2.fromOffset(0, 32)
		acc.BackgroundTransparency = 1
		acc.BorderSizePixel = 0
		acc.ZIndex = 11
		acc.Visible = false
		acc.Parent = frame
		local accLayout = Instance.new("UIListLayout")
		accLayout.FillDirection = Enum.FillDirection.Horizontal
		accLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		accLayout.Padding = UDim.new(0, 6)
		accLayout.Parent = acc
		local head = Instance.new("ImageLabel")
		head.Size = UDim2.fromOffset(22, 22)
		head.BackgroundTransparency = 1
		head.Image = "rbxthumb://type=AvatarHeadShot&id=" .. lp.UserId .. "&w=48&h=48"
		head.ScaleType = Enum.ScaleType.Fit
		head.ZIndex = 11
		head.Parent = acc
		local headCorner = Instance.new("UICorner")
		headCorner.CornerRadius = UDim.new(1, 0)
		headCorner.Parent = head
		local accName = mk(lp.Name, nil, true, acc)
		local function fpsColor(n)
			if n <= 34 then return Color3.fromHex("ff0000") end
			if n <= 89 then return Color3.fromHex("ff6b00") end
			if n <= 164 then return Color3.fromHex("bba902") end
			return green
		end
		local function pingColor(n)
			if n <= 75 then return green end
			if n <= 140 then return Color3.fromHex("bba902") end
			if n <= 250 then return Color3.fromHex("ff6b00") end
			return Color3.fromHex("ff0000")
		end
		local samples, total = {}, 0
		local fpsC, pingC = green, green
		local lastText = 0
		local lastBg, lastOutline, lastFont
		lib:GiveSignal(RunService.Heartbeat:Connect(function(dt)
			table.insert(samples, dt)
			total += dt
			while #samples > 30 do
				total -= table.remove(samples, 1)
			end
			if not frame.Visible then return end
			local fps = math.max(1, math.floor(#samples / math.max(total, 1e-4) + 0.5))
			local ping = 0
			pcall(function()
				ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
			end)
			local a = math.min(1, dt * 4)
			fpsC = fpsC:Lerp(fpsColor(fps), a)
			pingC = pingC:Lerp(pingColor(ping), a)
			fpsL.TextColor3 = fpsC
			pingL.TextColor3 = pingC
			local now = tick()
			if now - lastText >= 0.5 then
				lastText = now
				fpsL.Text = string.format("%d FPS", fps)
				pingL.Text = string.format("%d MS", ping)
				if timeL.Visible then
					timeL.Text = string.format("%02d:%02d", tonumber(os.date("%H")), tonumber(os.date("%M")))
				end
			end
			if lastBg ~= lib.Scheme.BackgroundColor then
				lastBg = lib.Scheme.BackgroundColor
				frame.BackgroundColor3 = lastBg
			end
			if lastOutline ~= lib.Scheme.OutlineColor then
				lastOutline = lib.Scheme.OutlineColor
				if not (stroke:FindFirstChild("WMChroma") and stroke.WMChroma.Enabled) then
					stroke.Color = lastOutline
				end
			end
			if lastFont ~= lib.Scheme.FontColor then
				lastFont = lib.Scheme.FontColor
				for _, l in ipairs(labels) do
					if l ~= fpsL and l ~= pingL then
						l.TextColor3 = lastFont
					end
				end
			end
		end))
		local chromaConn
		local function setChroma(on)
			local g = stroke:FindFirstChild("WMChroma")
			if on then
				if not g then
					g = Instance.new("UIGradient")
					g.Name = "WMChroma"
					g.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 128)),
						ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 0)),
						ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 255, 180)),
						ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 140, 255)),
						ColorSequenceKeypoint.new(0.8, Color3.fromRGB(180, 0, 255)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 128)),
					})
					g.Parent = stroke
				end
				g.Enabled = true
				stroke.Thickness = 1.8
				stroke.Transparency = 0.1
				stroke.Color = Color3.new(1, 1, 1)
				if chromaConn then chromaConn:Disconnect() end
				chromaConn = RunService.RenderStepped:Connect(function()
					if frame.Visible and g.Parent then
						g.Rotation = tick() * 120 % 360
					end
				end)
				lib:GiveSignal(chromaConn)
			else
				if g then g.Enabled = false end
				stroke.Thickness = 1
				stroke.Transparency = 0.72
				stroke.Color = lib.Scheme.OutlineColor
				if chromaConn then
					chromaConn:Disconnect()
					chromaConn = nil
				end
			end
		end
		local function syncSeps()
			sep3.Visible = verL.Visible
			sep4.Visible = timeL.Visible
			sep5.Visible = acc.Visible
		end
		local openBtn, openHolder
		local vis = {
			Icon = function(v) icon.Visible = v; accName.Text = v and lp.Name or (lp.Name .. " ") end,
			Name = function(v) nameL.Visible = v; sep1.Visible = v end,
			FPS = function(v) fpsL.Visible = v; sep2.Visible = v or pingL.Visible end,
			Ping = function(v) pingL.Visible = v; sep2.Visible = fpsL.Visible or v end,
			Version = function(v) verL.Visible = v; syncSeps() end,
			Time = function(v) timeL.Visible = v; syncSeps() end,
			Account = function(v) acc.Visible = v; syncSeps() end,
			["Chroma Wave"] = function(v) setChroma(v) end,
		}
		wmApplyVis = function(value)
			value = type(value) == "table" and value or {}
			for k, fn in pairs(vis) do
				fn(value[k] == true)
			end
		end
		wmSize = function(n)
			local textSize = 9 + (n - 1) * 13 / 9
			local h = 20 + (n - 1) * 22 / 9
			local avatar = 8 + (n - 1) * 18 / 9
			local ic = 18 + (n - 1) * 24 / 9
			for _, l in ipairs(labels) do
				l.TextSize = textSize
				l.Size = UDim2.fromOffset(0, h)
			end
			acc.Size = UDim2.fromOffset(0, h)
			head.Size = UDim2.fromOffset(avatar, avatar)
			icon.Size = UDim2.fromOffset(ic, ic)
			if openHolder then openHolder.Size = UDim2.fromOffset(0, h) end
			if openBtn then
				openBtn.TextSize = math.max(8, textSize - 2)
				openBtn.Size = UDim2.fromOffset(0, math.max(14, h - 8))
			end
			frame.Size = UDim2.fromOffset(0, h)
		end
		if game:GetService("UserInputService").TouchEnabled then
			openHolder = Instance.new("Frame")
			openHolder.Name = "ZZOpen"
			openHolder.AutomaticSize = Enum.AutomaticSize.X
			openHolder.Size = UDim2.fromOffset(0, 32)
			openHolder.BackgroundTransparency = 1
			openHolder.BorderSizePixel = 0
			openHolder.ZIndex = 11
			openHolder.Parent = frame
			local hp = Instance.new("UIPadding")
			hp.PaddingLeft = UDim.new(0, 8)
			hp.Parent = openHolder
			openBtn = Instance.new("TextButton")
			openBtn.Name = "OpenButton"
			openBtn.AutoButtonColor = false
			openBtn.AutomaticSize = Enum.AutomaticSize.X
			openBtn.AnchorPoint = Vector2.new(0, 0.5)
			openBtn.Position = UDim2.fromScale(0, 0.5)
			openBtn.Size = UDim2.fromOffset(0, 24)
			openBtn.BackgroundColor3 = lib.Scheme.AccentColor
			openBtn.BackgroundTransparency = 0.55
			openBtn.BorderSizePixel = 0
			openBtn.FontFace = bold
			openBtn.Text = lib.Toggled and "Close" or "Open"
			openBtn.TextColor3 = lib.Scheme.FontColor
			openBtn.TextSize = 14
			openBtn.ZIndex = 12
			openBtn.Parent = openHolder
			local oc = Instance.new("UICorner")
			oc.CornerRadius = UDim.new(1, 0)
			oc.Parent = openBtn
			local op = Instance.new("UIPadding")
			op.PaddingLeft = UDim.new(0, 12)
			op.PaddingRight = UDim.new(0, 12)
			op.Parent = openBtn
			local os2 = Instance.new("UIStroke")
			os2.Color = lib.Scheme.AccentColor
			os2.Transparency = 0.4
			os2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			os2.Parent = openBtn
			openBtn.Activated:Connect(function()
				if lib.Window then lib.Window:Toggle() end
			end)
			lib:GiveSignal(RunService.Heartbeat:Connect(function()
				local t = lib.Toggled and "Close" or "Open"
				if openBtn.Text ~= t then openBtn.Text = t end
			end))
		end
		lib:MakeDraggable(frame, frame, true)
		frame.Visible = true
	end
	disp:AddDivider()
	disp:AddCheckbox("GlassBlur", {
		Text = "Glass Blur",
		Default = true,
		Callback = function(v)
			lib:SetGlassBlur(nil, v)
		end,
	})
	disp:AddSlider("GlassBlurSize", {
		Text = "Blur Strength",
		Default = 14, Min = 0, Max = 30, Rounding = 0,
		Compact = true,
		Callback = function(v)
			lib:SetGlassBlur(v, nil)
		end,
	})
	disp:AddDivider()
	disp:AddCheckbox("MenuWatermark", {
		Text = "Kirpich Watermark & Stats",
		Default = true,
		Callback = function(v)
			wmFrame.Visible = v
			if lib._mobileBtn then lib._mobileBtn.Visible = not v end
		end,
	})
	disp:AddDivider("Watermark Settings")
	disp:AddSlider("MenuWatermarkSize", {
		Text = "Watermark Size",
		Default = 6, Min = 1, Max = 10, Rounding = 0,
		Compact = true,
		Callback = function(v)
			wmSize(v)
		end,
	})
	disp:AddDropdown("WmVisibility", {
		Text = "Show Elements",
		Values = { "Icon", "Name", "FPS", "Ping", "Version", "Time", "Account", "Chroma Wave" },
		Default = { "Icon", "Name", "FPS", "Ping" },
		Multi = true,
		ValueImages = {
			Icon = "image", Name = "sparkles", FPS = "gauge", Ping = "wifi",
			Version = "code", Time = "clock", Account = "user", ["Chroma Wave"] = "waves-horizontal",
		},
		Callback = function(v)
			wmApplyVis(v)
		end,
	})
	wmSize(6)
	wmApplyVis(lib.Options.WmVisibility.Value)
	if lib._mobileBtn then lib._mobileBtn.Visible = not wmFrame.Visible end
end
