local consoleActive = true
local consoleStopRequested = false
local v12DescendantConnection = nil
local v12HookMt = nil
local v12OldNamecall = nil
local v12HookInstalled = false
local v12InstalledHook = nil
local v12HookReadonly = true
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local function isFunction(value)
    return type(value) == "function" and value or nil
end

local directProviders = {
    getgenv = function() return getgenv end,
    getrawmetatable = function() return getrawmetatable end,
    newcclosure = function() return newcclosure end,
    checkcaller = function() return checkcaller end,
    getnamecallmethod = function() return getnamecallmethod end,
    setreadonly = function() return setreadonly end,
    isreadonly = function() return isreadonly end,
    make_writeable = function() return make_writeable end,
    writefile = function() return writefile end,
    readfile = function() return readfile end,
    isfile = function() return isfile end,
    setclipboard = function() return setclipboard end,
    toclipboard = function() return toclipboard end,
    gethui = function() return gethui end,
}

local function directGlobal(name)
    local provider = directProviders[name]
    if provider then
        local ok, value = pcall(provider)
        if ok and value ~= nil then return value end
    end
    return nil
end

local function collectEnvironmentTables()
    local environments = {}
    local seen = {}
    local function add(name, value)
        if type(value) == "table" and not seen[value] then
            seen[value] = true
            table.insert(environments, {Name = name, Value = value})
        end
    end

    local okG, globalEnv = pcall(function() return _G end)
    if okG then add("_G", globalEnv) end

    local getgenvFunction = directGlobal("getgenv")
    if getgenvFunction then
        local okEnv, generatedEnv = pcall(getgenvFunction)
        if okEnv then add("getgenv", generatedEnv) end
    end

    return environments
end

local EnvironmentTables = collectEnvironmentTables()

local function lookupFunction(name)
    local direct = directGlobal(name)
    if isFunction(direct) then return direct end
    for _, item in ipairs(EnvironmentTables) do
        local ok, value = pcall(function() return rawget(item.Value, name) end)
        if ok and isFunction(value) then return value end
    end
    return nil
end

local Native = {
    getgenv = lookupFunction("getgenv"),
    getrawmetatable = lookupFunction("getrawmetatable"),
    newcclosure = lookupFunction("newcclosure"),
    checkcaller = lookupFunction("checkcaller"),
    getnamecallmethod = lookupFunction("getnamecallmethod"),
    setreadonly = lookupFunction("setreadonly") or lookupFunction("make_writeable"),
    isreadonly = lookupFunction("isreadonly"),
    writefile = lookupFunction("writefile"),
    readfile = lookupFunction("readfile"),
    isfile = lookupFunction("isfile"),
    setclipboard = lookupFunction("setclipboard") or lookupFunction("toclipboard"),
    gethui = lookupFunction("gethui")
}

local errorHistory = {}
local sessionFiles = {}
local EnvironmentStatus
local Safe = {}

local function reportError(domain, message)
    local entry = string.format("[%s] %s", tostring(domain or "General"), tostring(message or "Unknown error"))
    table.insert(errorHistory, {Domain = tostring(domain or "General"), Message = tostring(message or "Unknown error"), Timestamp = os.time()})
    if #errorHistory > 100 then table.remove(errorHistory, 1) end
    pcall(function() print("[RE] " .. entry) end)
    return entry
end

Safe.reportError = reportError
Safe.getErrors = function() return errorHistory end
Safe.clearErrors = function() table.clear(errorHistory) end
Safe.getrawmetatable = function(...)
    if not Native.getrawmetatable then return nil, "Hook API unavailable" end
    local ok, value = pcall(Native.getrawmetatable, ...)
    if ok then return value end
    reportError("Hook", value)
    return nil, "Hook exception: " .. tostring(value)
end
Safe.newcclosure = function(fn)
    if not Native.newcclosure then return fn end
    local ok, value = pcall(Native.newcclosure, fn)
    if ok then return value end
    reportError("Hook", value)
    return fn
end
Safe.checkcaller = function(...)
    if not Native.checkcaller then return false end
    local ok, value = pcall(Native.checkcaller, ...)
    return ok and value == true or false
end
Safe.getnamecallmethod = function(...)
    if not Native.getnamecallmethod then return "" end
    local ok, value = pcall(Native.getnamecallmethod, ...)
    return ok and tostring(value) or ""
end
Safe.setreadonly = function(...)
    if not Native.setreadonly then return false, "Hook API unavailable" end
    local ok, value = pcall(Native.setreadonly, ...)
    if ok then return true, value end
    reportError("Hook", value)
    return false, "Hook exception: " .. tostring(value)
end
Safe.isreadonly = function(value)
    if not Native.isreadonly then return nil end
    local ok, result = pcall(Native.isreadonly, value)
    if ok and type(result) == "boolean" then return result end
    return nil
end
Safe.writefile = function(path, data)
    path, data = tostring(path or ""), tostring(data or "")
    if Native.writefile then
        local ok, err = pcall(Native.writefile, path, data)
        if ok then return true end
        reportError("FileSystem", err)
    end
    sessionFiles[path] = data
    return false, "Filesystem API unavailable; using session storage"
end
Safe.readfile = function(path)
    path = tostring(path or "")
    if Native.readfile then
        local ok, value = pcall(Native.readfile, path)
        if ok then return value end
        reportError("FileSystem", value)
    end
    return sessionFiles[path], "Filesystem API unavailable; using session storage"
end
Safe.isfile = function(path)
    path = tostring(path or "")
    if Native.isfile then
        local ok, value = pcall(Native.isfile, path)
        if ok and value == true then return true end
        if not ok then reportError("FileSystem", value) end
    end
    return sessionFiles[path] ~= nil, sessionFiles[path] ~= nil and nil or "Filesystem API unavailable"
end
Safe.setclipboard = function(text)
    text = tostring(text or "")
    if not Native.setclipboard then
        reportError("Clipboard", "Clipboard API unavailable")
        return false, "Clipboard API unavailable"
    end
    local ok, err = pcall(Native.setclipboard, text)
    if ok then return true end
    reportError("Clipboard", err)
    return false, "Clipboard exception: " .. tostring(err)
end
Safe.gethui = function(...)
    if not Native.gethui then return nil, "UI host API unavailable" end
    local ok, value = pcall(Native.gethui, ...)
    if ok then return value end
    reportError("UI", value)
    return nil, "UI host exception: " .. tostring(value)
end
Safe.canHook = Native.getrawmetatable ~= nil and Native.newcclosure ~= nil and Native.getnamecallmethod ~= nil and Native.setreadonly ~= nil

EnvironmentStatus = {
    Clipboard = Native.setclipboard ~= nil,
    Filesystem = Native.writefile ~= nil or Native.readfile ~= nil or Native.isfile ~= nil,
    UIHost = false,
    Hooks = Safe.canHook
}
pcall(function()
    print(string.format("[RE] Environment | Clipboard: %s | Filesystem: %s | Hooks: %s", EnvironmentStatus.Clipboard and "READY" or "UNAVAILABLE", EnvironmentStatus.Filesystem and "READY" or "UNAVAILABLE", EnvironmentStatus.Hooks and "READY" or "UNAVAILABLE"))
end)

local INSPECTOR_SETTINGS = {
    MaxLogs = 150,
    MaxDepth = 5,
    MaxStringLength = 500,
    Deduplicate = true,
    LogsPerFrame = 10
}

local remoteListeners = setmetatable({}, {__mode = "k"})
local setupRemoteListener
local startConsoleMonitor
local stopConsoleMonitor

local function makeDraggable(topbar, object)
    local dragging, dragInput, dragStart, startPos

    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = object.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            object.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "RE_Ultimate_Framework"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999

local guiParentSet = false
local hui = Safe.gethui()
if hui then
    local ok = pcall(function() gui.Parent = hui end)
    guiParentSet = ok and gui.Parent ~= nil
end
if not guiParentSet then
    local ok = pcall(function() gui.Parent = CoreGui end)
    guiParentSet = ok and gui.Parent ~= nil
end
if not guiParentSet and LocalPlayer then
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        local ok = pcall(function() gui.Parent = playerGui end)
        guiParentSet = ok and gui.Parent ~= nil
    end
end
EnvironmentStatus.UIHost = guiParentSet
pcall(function() print("[RE] UI Host: " .. (guiParentSet and "READY" or "UNAVAILABLE")) end)
if not guiParentSet then Safe.reportError("UI", "No valid GUI parent was available") end

-- [[ ICON STYLING: Glassmorphism ]]
local iconBtn = Instance.new("TextButton")
iconBtn.Size = UDim2.new(0, 54, 0, 54)
iconBtn.Position = UDim2.new(0, 18, 0, 18)
iconBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
iconBtn.BackgroundTransparency = 0.35
iconBtn.BorderSizePixel = 0
iconBtn.Text = "ℝ𝔼"
iconBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
iconBtn.TextStrokeTransparency = 0.9
iconBtn.Font = Enum.Font.GothamBold
iconBtn.TextSize = 22
iconBtn.AutoButtonColor = false
iconBtn.Parent = gui
makeDraggable(iconBtn, iconBtn)

local iconScale = Instance.new("UIScale")
iconScale.Scale = 1
iconScale.Parent = iconBtn
iconBtn.MouseButton1Down:Connect(function()
    TweenService:Create(iconScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.9}):Play()
end)
iconBtn.MouseButton1Up:Connect(function()
    TweenService:Create(iconScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end)

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0, 16)
iconCorner.Parent = iconBtn

local iconStroke = Instance.new("UIStroke")
iconStroke.Color = Color3.fromRGB(200, 220, 255)
iconStroke.Thickness = 1.5
iconStroke.Transparency = 0.6
iconStroke.Parent = iconBtn

iconBtn.MouseEnter:Connect(function()
    TweenService:Create(iconBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.15}):Play()
    TweenService:Create(iconStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0.2}):Play()
end)
iconBtn.MouseLeave:Connect(function()
    TweenService:Create(iconBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.35}):Play()
    TweenService:Create(iconStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0.6}):Play()
end)

-- [[ MENU STYLING ]]
local menuFrame = Instance.new("Frame")
menuFrame.Size = UDim2.new(0, 330, 0, 145)
menuFrame.Position = UDim2.new(0, 65, 0, 15)
menuFrame.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
menuFrame.BackgroundTransparency = 0.4 
menuFrame.BorderSizePixel = 0
menuFrame.Visible = false
menuFrame.Active = false 
menuFrame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 30)
title.BackgroundTransparency = 1
title.BorderSizePixel = 0
title.Text = "  ℝ𝔼  |  وحدة التحكم"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true 
title.Parent = menuFrame
makeDraggable(title, menuFrame)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = menuFrame

-- [[ GLASS BUTTON FUNCTION ]]
local function createButton(parent, posX, posY, width, height, text)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, width, 0, height)
    btn.Position = UDim2.new(0, posX, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundTransparency = 0.92
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(240, 245, 255)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.8
    stroke.Thickness = 1
    stroke.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.75,
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 0.4
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.92,
            TextColor3 = Color3.fromRGB(240, 245, 255)
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 0.8
        }):Play()
    end)
    return btn
end

local toggleInspectorBtn = createButton(menuFrame, 10, 42, 310, 42, "فتح الكونسول")
toggleInspectorBtn.TextColor3 = Color3.fromRGB(150, 200, 255)

local stopConsoleBtn = createButton(menuFrame, 10, 92, 310, 42, "إيقاف الكونسول وتنظيفه")
stopConsoleBtn.TextColor3 = Color3.fromRGB(255, 120, 120)

-- [[ INSPECTOR STYLING ]]
local inspectorFrame = Instance.new("Frame")
inspectorFrame.Size = UDim2.new(0, 640, 0, 380)
inspectorFrame.Position = UDim2.new(0, 405, 0, 15)
inspectorFrame.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
inspectorFrame.BackgroundTransparency = 0.4
inspectorFrame.BorderSizePixel = 0
inspectorFrame.Visible = false
inspectorFrame.Active = false 
inspectorFrame.Parent = gui

local inspectorTitle = Instance.new("TextLabel")
inspectorTitle.Size = UDim2.new(1, -30, 0, 32)
inspectorTitle.BackgroundTransparency = 1
inspectorTitle.BorderSizePixel = 0
inspectorTitle.Text = "  ℝ𝔼  |  كونسول مراقبة الريموتات"
inspectorTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
inspectorTitle.Font = Enum.Font.GothamBold
inspectorTitle.TextSize = 13
inspectorTitle.TextXAlignment = Enum.TextXAlignment.Left
inspectorTitle.Active = true
inspectorTitle.Parent = inspectorFrame
makeDraggable(inspectorTitle, inspectorFrame)

local inspectorCloseBtn = Instance.new("TextButton")
inspectorCloseBtn.Size = UDim2.new(0, 30, 0, 32)
inspectorCloseBtn.Position = UDim2.new(1, -30, 0, 0)
inspectorCloseBtn.BackgroundTransparency = 1
inspectorCloseBtn.Text = "✕"
inspectorCloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
inspectorCloseBtn.Font = Enum.Font.GothamBold
inspectorCloseBtn.TextSize = 14
inspectorCloseBtn.Parent = inspectorFrame

local toolbarFrame = Instance.new("Frame")
toolbarFrame.Size = UDim2.new(1, -20, 0, 32)
toolbarFrame.Position = UDim2.new(0, 10, 0, 38)
toolbarFrame.BackgroundTransparency = 1
toolbarFrame.Parent = inspectorFrame

local toggleSpyBtn = createButton(toolbarFrame, 0, 0, 100, 30, "تسجيل: متوقف")
local clearSpyBtn = createButton(toolbarFrame, 110, 0, 60, 30, "مسح")
clearSpyBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
local copySelectedBtn = createButton(toolbarFrame, 180, 0, 100, 30, "نسخ المحدد")
local copyAllBtn = createButton(toolbarFrame, 290, 0, 100, 30, "نسخ الكل")
local dedupBtn = createButton(toolbarFrame, 400, 0, 110, 30, "دمج التكرار: ON")
dedupBtn.TextColor3 = Color3.fromRGB(150, 255, 150)

local leftScroll = Instance.new("ScrollingFrame")
leftScroll.Size = UDim2.new(0, 260, 1, -85)
leftScroll.Position = UDim2.new(0, 10, 0, 75)
leftScroll.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
leftScroll.BackgroundTransparency = 0.7
leftScroll.BorderSizePixel = 0
leftScroll.ScrollBarThickness = 2
leftScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
leftScroll.Parent = inspectorFrame

local leftLayout = Instance.new("UIListLayout")
leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
leftLayout.Padding = UDim.new(0, 4)
leftLayout.Parent = leftScroll

local rightScroll = Instance.new("ScrollingFrame")
rightScroll.Size = UDim2.new(1, -290, 1, -85)
rightScroll.Position = UDim2.new(0, 280, 0, 75)
rightScroll.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
rightScroll.BackgroundTransparency = 0.7
rightScroll.BorderSizePixel = 0
rightScroll.ScrollBarThickness = 2
rightScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
rightScroll.Parent = inspectorFrame

local rightLayout = Instance.new("UIListLayout")
rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
rightLayout.Padding = UDim.new(0, 6)
rightLayout.Parent = rightScroll

leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    leftScroll.CanvasSize = UDim2.new(0, 0, 0, leftLayout.AbsoluteContentSize.Y + 10)
end)
rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    rightScroll.CanvasSize = UDim2.new(0, 0, 0, rightLayout.AbsoluteContentSize.Y + 10)
end)

-- تطبيق تأثير الحواف الزجاجية على الإطارات الرئيسية
local function applyGlassBorders(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = object

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.85
    stroke.Parent = object
end

applyGlassBorders(menuFrame, 12)
applyGlassBorders(inspectorFrame, 12)
applyGlassBorders(leftScroll, 8)
applyGlassBorders(rightScroll, 8)

-- خط زخرفي أنيق أسفل شريط العناوين
local function addAccentLine(parent, color)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, 0)
    line.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
    line.BackgroundTransparency = 0.7
    line.BorderSizePixel = 0
    line.Parent = parent
end

addAccentLine(title, Color3.fromRGB(150, 200, 255))
addAccentLine(inspectorTitle, Color3.fromRGB(150, 200, 255))

local menuScale = Instance.new("UIScale")
menuScale.Scale = 0.95
menuScale.Parent = menuFrame
local inspectorScale = Instance.new("UIScale")
inspectorScale.Scale = 0.95
inspectorScale.Parent = inspectorFrame
inspectorFrame.Position = UDim2.new(0.5, -320, 0.5, -190)

local function showPanel(panel, scaleObject, visible)
    if visible then
        panel.Visible = true
        scaleObject.Scale = scaleObject.Scale - 0.05
        TweenService:Create(scaleObject, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.3}):Play()
    else
        TweenService:Create(panel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
        task.delay(0.15, function() panel.Visible = false end)
    end
end

local logsDatabase = {}
local logQueue = {}
local logCounter = 0
local activeTreeData = ""
local spyRecording = false

iconBtn.MouseButton1Click:Connect(function()
    showPanel(menuFrame, menuScale, not menuFrame.Visible)
end)
closeBtn.MouseButton1Click:Connect(function()
    showPanel(menuFrame, menuScale, false)
end)
inspectorCloseBtn.MouseButton1Click:Connect(function()
    showPanel(inspectorFrame, inspectorScale, false)
end)
toggleInspectorBtn.MouseButton1Click:Connect(function()
    showPanel(inspectorFrame, inspectorScale, not inspectorFrame.Visible)
end)

local function formatTime()
    local t = DateTime.now():ToUniversalTime()
    return string.format("%02d:%02d:%02d.%03d", t.Hour, t.Minute, t.Second, t.Millisecond)
end

local function parseData(data, depth, seen)
    depth = depth or 1
    seen = seen or {}
    local t = typeof(data)
    if depth > INSPECTOR_SETTINGS.MaxDepth then return "{Max Depth}" end
    if t == "table" then
        if seen[data] then return "{Circular Ref}" end
        seen[data] = true
        local parsed = {}
        for k, v in pairs(data) do parsed[tostring(k)] = parseData(v, depth + 1, seen) end
        return parsed
    elseif t == "Instance" then
        local okName, name = pcall(function() return data.Name end)
        local okClass, class = pcall(function() return data.ClassName end)
        local okPath, path = pcall(function() return data:GetFullName() end)
        if not (okName and okClass) then return "{Destroyed}" end
        if class == "Player" then
            local okId, id = pcall(function() return data.UserId end)
            return string.format("Player: %s [UserId=%s]", okPath and path or name, okId and tostring(id) or "?")
        end
        return string.format("Instance: %s [%s]", okPath and path or name, class)
    elseif t == "Vector3" then
        return string.format("Vector3(%.2f, %.2f, %.2f)", data.X, data.Y, data.Z)
    elseif t == "Vector2" then
        return string.format("Vector2(%.2f, %.2f)", data.X, data.Y)
    elseif t == "CFrame" then
        return string.format("CFrame(%.1f, %.1f, %.1f)", data.Position.X, data.Position.Y, data.Position.Z)
    elseif t == "EnumItem" then
        return tostring(data)
    elseif t == "string" then
        return #data > INSPECTOR_SETTINGS.MaxStringLength and string.sub(data, 1, INSPECTOR_SETTINGS.MaxStringLength) .. "..." or '"' .. data .. '"'
    end
    return tostring(data)
end

local function getArgumentTypes(args)
    local types = {}
    local limit = type(args) == "table" and (tonumber(args.n) or #args) or 0
    for index = 1, limit do
        local value = args[index]
        local valueType = typeof(value)
        if valueType == "Instance" then
            local ok, className = pcall(function() return value.ClassName end)
            valueType = ok and ("Instance<" .. className .. ">") or "Instance"
        end
        types[index] = valueType
    end
    return types
end

local function renderTree(data, parent, indentLevel, textStr)
    for k, v in pairs(data) do
        local row = Instance.new("TextLabel")
        row.Size = UDim2.new(1, -10, 0, 20)
        row.Position = UDim2.new(0, 5, 0, 0)
        row.BackgroundTransparency = 1
        row.Font = Enum.Font.Code
        row.TextSize = 12
        row.TextColor3 = Color3.fromRGB(240, 245, 255)
        row.TextXAlignment = Enum.TextXAlignment.Left
        
        local indent = string.rep("  ", indentLevel)
        if type(v) == "table" then
            row.Text = indent .. "▼ [" .. tostring(k) .. "] Table"
            row.TextColor3 = Color3.fromRGB(150, 200, 255)
            row.Parent = parent
            textStr = textStr .. row.Text .. "\n"
            textStr = renderTree(v, parent, indentLevel + 1, textStr)
        else
            row.Text = indent .. "├─ " .. tostring(k) .. ": " .. tostring(v)
            row.TextColor3 = Color3.fromRGB(200, 220, 240)
            row.Parent = parent
            textStr = textStr .. row.Text .. "\n"
        end
    end
    return textStr
end

local function drawLogUI(logData)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 50)
    btn.Position = UDim2.new(0, 4, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundTransparency = 0.94
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.LayoutOrder = -logData.ID
    
    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = btn
    
    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color = logData.Direction == "Incoming ⬇️" and Color3.fromRGB(150, 255, 180) or Color3.fromRGB(200, 180, 255)
    rowStroke.Transparency = 0.6
    rowStroke.Thickness = 1
    rowStroke.Parent = btn
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 1, 0)
    lbl.Position = UDim2.new(0, 5, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.RichText = true
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn
    
    local function updateText()
        local countStr = logData.Count > 1 and string.format(" <font color='rgb(255,150,150)'>x%d</font>", logData.Count) or ""
        local dirColor = logData.Direction == "Incoming ⬇️" and "rgb(150,255,180)" or "rgb(200,180,255)"
        local senderStr = logData.Sender == "Server" and "<font color='rgb(180,220,255)'>Server</font>" or string.format("<font color='rgb(255,220,150)'>%s</font>", logData.Sender)
        
        lbl.Text = string.format("<b>#%03d</b> %s%s\n<font color='%s'>%s</font> | %s\n<font color='rgb(180,190,200)'>%s | Sender: %s</font>", 
            logData.ID, logData.Name, countStr, dirColor, logData.Direction, logData.Method, logData.Timestamp, senderStr)
    end
    updateText()
    
    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.8}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.94}):Play() end)
    
    btn.MouseButton1Click:Connect(function()
        rightScroll.Visible = true
        for _, c in ipairs(rightScroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
        
        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, -10, 0, 95)
        header.Position = UDim2.new(0, 5, 0, 0)
        header.BackgroundTransparency = 1
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Font = Enum.Font.Code
        header.TextSize = 12
        header.TextColor3 = Color3.fromRGB(255, 255, 255)
        header.Text = string.format("ID: #%03d\nRemote: %s\nClass: %s\nPath: %s\nDirection: %s\nSender: %s", 
            logData.ID, logData.Name, logData.Class, logData.Path, logData.Direction, logData.Sender)
        header.Parent = rightScroll
        
        activeTreeData = header.Text .. "\n\nArguments:\n"
        activeTreeData = renderTree(logData.Args, rightScroll, 0, activeTreeData)
    end)
    
    btn.Parent = leftScroll
    logData.UI = btn
    logData.UpdateFunc = updateText
end

RunService.Heartbeat:Connect(function()
    if not consoleActive then return end
    if #logQueue > 0 then
        local count = math.min(#logQueue, INSPECTOR_SETTINGS.LogsPerFrame)
        for i = 1, count do
            local newLog = table.remove(logQueue, 1)
            
            local skip = false
            if INSPECTOR_SETTINGS.Deduplicate and #logsDatabase > 0 then
                local lastLog = logsDatabase[#logsDatabase]
                if lastLog.Name == newLog.Name and lastLog.Method == newLog.Method and lastLog.Direction == newLog.Direction then
                    lastLog.Count = lastLog.Count + 1
                    lastLog.Timestamp = newLog.Timestamp
                    if lastLog.UpdateFunc then lastLog.UpdateFunc() end
                    skip = true
                end
            end
            if not skip then
                table.insert(logsDatabase, newLog)
                drawLogUI(newLog)
                
                if #logsDatabase > INSPECTOR_SETTINGS.MaxLogs then
                    local old = table.remove(logsDatabase, 1)
                    if old.UI then
                        old.UI:Destroy()
                    end
                end
            end
        end
    end
end)

toggleSpyBtn.MouseButton1Click:Connect(function()
    spyRecording = not spyRecording
    if spyRecording and startConsoleMonitor then pcall(startConsoleMonitor) else if stopConsoleMonitor then pcall(stopConsoleMonitor) end end
    toggleSpyBtn.Text = spyRecording and "تسجيل: شغال" or "تسجيل: متوقف"
    toggleSpyBtn.TextColor3 = spyRecording and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(240, 245, 255)
end)

clearSpyBtn.MouseButton1Click:Connect(function()
    logsDatabase = {}; logQueue = {}
    for _, c in ipairs(leftScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    for _, c in ipairs(rightScroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
end)

copySelectedBtn.MouseButton1Click:Connect(function()
    if activeTreeData == "" then
        copySelectedBtn.Text = "لا يوجد تحديد"
        task.delay(1.5, function() copySelectedBtn.Text = "نسخ المحدد" end)
        return
    end
    local copied, copyError = Safe.setclipboard(activeTreeData)
    if copied then
        copySelectedBtn.Text = "تم النسخ!"
        copySelectedBtn.TextColor3 = Color3.fromRGB(150, 255, 150)
    elseif copyError == "Clipboard API unavailable" then
        copySelectedBtn.Text = "الحافظة غير مدعومة"
    else
        copySelectedBtn.Text = "فشل النسخ"
    end
    task.delay(1.5, function()
        copySelectedBtn.Text = "نسخ المحدد"
        copySelectedBtn.TextColor3 = Color3.fromRGB(240, 245, 255)
    end)
end)

copyAllBtn.MouseButton1Click:Connect(function()
    if #logsDatabase == 0 then
        copyAllBtn.Text = "السجل فارغ"
        task.delay(1.5, function() copyAllBtn.Text = "نسخ الكل" end)
        return
    end

    local allDataText = "=== سجل ريموتات اللعبة الكامل ===\n\n"
    for _, log in ipairs(logsDatabase) do
        allDataText = allDataText .. string.format("[#%03d] [%s] %s (%s) | %s | المرسل: %s | التكرار: x%d\n", log.ID, log.Timestamp, log.Name, log.Method, log.Direction, log.Sender, log.Count)
        allDataText = allDataText .. "المسار: " .. tostring(log.Path) .. "\n"
        allDataText = allDataText .. "أنواع الوسائط: " .. table.concat(log.ArgTypes or {}, ", ") .. "\n"
        local argsText = ""
        local function parseArgsToString(data, indentLevel)
            for k, v in pairs(data or {}) do
                local indent = string.rep("  ", indentLevel)
                if type(v) == "table" then
                    argsText = argsText .. indent .. "[" .. tostring(k) .. "] Table:\n"
                    parseArgsToString(v, indentLevel + 1)
                else
                    argsText = argsText .. indent .. tostring(k) .. ": " .. tostring(v) .. "\n"
                end
            end
        end
        parseArgsToString(log.Args, 1)
        allDataText = allDataText .. "البيانات الممررة:\n" .. argsText .. "\n-------------------------\n"
    end

    local copied, copyError = Safe.setclipboard(allDataText)
    if copied then
        copyAllBtn.Text = "تم نسخ السجل!"
        copyAllBtn.TextColor3 = Color3.fromRGB(150, 255, 150)
    elseif copyError == "Clipboard API unavailable" then
        copyAllBtn.Text = "الحافظة غير مدعومة"
        copyAllBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
    else
        copyAllBtn.Text = "فشل النسخ"
        copyAllBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
    end
    task.delay(1.8, function()
        copyAllBtn.Text = "نسخ الكل"
        copyAllBtn.TextColor3 = Color3.fromRGB(240, 245, 255)
    end)
end)

dedupBtn.MouseButton1Click:Connect(function()
    INSPECTOR_SETTINGS.Deduplicate = not INSPECTOR_SETTINGS.Deduplicate
    dedupBtn.Text = "دمج التكرار: " .. (INSPECTOR_SETTINGS.Deduplicate and "ON" or "OFF")
    dedupBtn.TextColor3 = INSPECTOR_SETTINGS.Deduplicate and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 150, 150)
end)

setupRemoteListener = function(obj)
    if not consoleActive or not obj then return end
    local known = remoteListeners[obj]
    if known then return end
    local okClass, isRemote = pcall(function() return obj:IsA("RemoteEvent") end)
    if not okClass or not isRemote then return end
    local okConnection, connectionOrError = pcall(function()
        return obj.OnClientEvent:Connect(function(...)
            if not consoleActive or not spyRecording then return end
            local args = {...}
            local sender = "Server"
            for _, arg in pairs(args) do
                local okArg, isPlayer = pcall(function() return typeof(arg) == "Instance" and arg:IsA("Player") end)
                if okArg and isPlayer and arg ~= LocalPlayer then
                    local okName, argName = pcall(function() return arg.Name end)
                    sender = "Player: " .. (okName and tostring(argName) or "Unknown")
                    break
                end
            end
            task.defer(function()
                if not consoleActive or not spyRecording then return end
                if #logQueue >= INSPECTOR_SETTINGS.MaxLogs * 2 then table.remove(logQueue, 1) end
                logCounter = logCounter + 1
                local okRecord, recordError = pcall(function()
                    local parsed = parseData(args)
                    table.insert(logQueue, {
                        ID = logCounter,
                        Name = obj.Name,
                        Class = obj.ClassName,
                        Method = "OnClientEvent",
                        Direction = "Incoming ⬇️",
                        Sender = sender,
                        Path = obj:GetFullName(),
                        Timestamp = formatTime(),
                        Args = parsed,
                        ArgTypes = getArgumentTypes(args),
                        ArgCount = #args,
                        Count = 1
                    })
                end)
                if not okRecord and Safe and Safe.reportError then Safe.reportError("RemoteMonitor", recordError) end
            end)
        end)
    end)
    if okConnection and connectionOrError then
        remoteListeners[obj] = connectionOrError
    else
        remoteListeners[obj] = nil
        if Safe and Safe.reportError then Safe.reportError("RemoteMonitor", connectionOrError or "listener connection failed") end
    end
end

startConsoleMonitor = function()
    if not consoleActive or not spyRecording then return end
    for _, obj in ipairs(game:GetDescendants()) do
        setupRemoteListener(obj)
    end
    if not v12DescendantConnection then
        local ok, connection = pcall(function()
            return game.DescendantAdded:Connect(function(obj)
                if consoleActive and spyRecording then setupRemoteListener(obj) end
            end)
        end)
        if ok then v12DescendantConnection = connection end
    end
end

stopConsoleMonitor = function()
    if v12DescendantConnection then
        pcall(function() v12DescendantConnection:Disconnect() end)
        v12DescendantConnection = nil
    end
    for object, connection in pairs(remoteListeners) do
        if connection then pcall(function() connection:Disconnect() end) end
        remoteListeners[object] = nil
    end
end

local v12HookOwnerKey = "RE_Ultimate_Console_NamecallHook"

local function v12RestoreHook()
    if not v12HookInstalled or not v12HookMt or not v12OldNamecall then return true end
    local currentHook = nil
    local currentOk = pcall(function() currentHook = v12HookMt.__namecall end)
    if not currentOk then
        Safe.reportError("Hook", "Unable to inspect current __namecall")
        return false, "Unable to inspect current __namecall"
    end
    if currentHook ~= v12InstalledHook then
        v12HookInstalled = false
        v12InstalledHook = nil
        v12HookMt = nil
        v12OldNamecall = nil
        return true
    end
    local writable, writableError = Safe.setreadonly(v12HookMt, false)
    if not writable then
        Safe.reportError("Hook", writableError or "Unable to make __namecall writable")
        return false, writableError
    end
    local restored, restoreError = pcall(function() v12HookMt.__namecall = v12OldNamecall end)
    Safe.setreadonly(v12HookMt, v12HookReadonly)
    if not restored then
        Safe.reportError("Hook", restoreError or "Unable to restore __namecall")
        return false, restoreError
    end
    v12HookInstalled = false
    v12InstalledHook = nil
    local owner = rawget(_G, v12HookOwnerKey)
    if type(owner) == "table" and owner.Hook == currentHook then
        rawset(_G, v12HookOwnerKey, nil)
    end
    v12HookMt = nil
    v12OldNamecall = nil
    return true
end

local function recordOutgoingCall(remote, method, packedArgs)
    if not consoleActive or not spyRecording then return end
    local okRecord, recordError = pcall(function()
        if #logQueue >= INSPECTOR_SETTINGS.MaxLogs * 2 then table.remove(logQueue, 1) end
        logCounter = logCounter + 1
        local remoteName = "Unknown"
        local remoteClass = "Unknown"
        local remotePath = "Unknown"
        local sender = "You"
        pcall(function() remoteName = tostring(remote.Name) end)
        pcall(function() remoteClass = tostring(remote.ClassName) end)
        pcall(function() remotePath = tostring(remote:GetFullName()) end)
        pcall(function() sender = "You (" .. tostring(LocalPlayer.Name) .. ")" end)
        local copiedArgs = {}
        local typedArgs = {n = packedArgs.n}
        for index = 1, packedArgs.n do
            copiedArgs[index] = packedArgs[index]
            typedArgs[index] = packedArgs[index]
        end
        local parsed = parseData(copiedArgs)
        table.insert(logQueue, {
            ID = logCounter,
            Name = remoteName,
            Class = remoteClass,
            Method = method,
            Direction = "Outgoing ⬆️",
            Sender = sender,
            Path = remotePath,
            Timestamp = formatTime(),
            Args = parsed,
            ArgTypes = getArgumentTypes(typedArgs),
            ArgCount = packedArgs.n,
            Count = 1
        })
    end)
    if not okRecord and Safe and Safe.reportError then Safe.reportError("RemoteMonitor", recordError) end
end

local previousHookOwner = rawget(_G, v12HookOwnerKey)
local previousHookRestored = true
if type(previousHookOwner) == "table" and type(previousHookOwner.Restore) == "function" then
    local previousOk, previousResult = pcall(previousHookOwner.Restore)
    previousHookRestored = previousOk and previousResult ~= false
    if not previousHookRestored then
        Safe.reportError("Hook", "Previous console hook could not be restored")
    end
end

if Safe.canHook and previousHookRestored then
    pcall(function()
        local mt = Safe.getrawmetatable(game)
        if mt then
            local oldNamecall = mt.__namecall
            if type(oldNamecall) == "function" then
                v12HookMt = mt
                v12OldNamecall = oldNamecall
                v12HookReadonly = Safe.isreadonly(mt)
                if v12HookReadonly == nil then v12HookReadonly = true end
                local writable = Safe.setreadonly(mt, false)
                if writable then
                    local installedHook = Safe.newcclosure(function(self, ...)
                        local result = table.pack(oldNamecall(self, ...))
                        if not consoleActive or not spyRecording then
                            return table.unpack(result, 1, result.n)
                        end
                        local method = Safe.getnamecallmethod()
                        if method ~= "FireServer" and method ~= "InvokeServer" or Safe.checkcaller() then
                            return table.unpack(result, 1, result.n)
                        end
                        local packedArgs = table.pack(...)
                        task.defer(function()
                            local okLogger, loggerError = pcall(recordOutgoingCall, self, method, packedArgs)
                            if not okLogger and Safe and Safe.reportError then Safe.reportError("RemoteMonitor", loggerError) end
                        end)
                        return table.unpack(result, 1, result.n)
                    end)
                    local assigned, assignError = pcall(function() mt.__namecall = installedHook end)
                    Safe.setreadonly(mt, v12HookReadonly)
                    if assigned then
                        v12InstalledHook = installedHook
                        v12HookInstalled = true
                        rawset(_G, v12HookOwnerKey, {Hook = installedHook, Restore = v12RestoreHook})
                    else
                        v12HookMt = nil
                        v12OldNamecall = nil
                        Safe.reportError("Hook", assignError or "Unable to install __namecall")
                    end
                end
            end
        end
    end)
end

local function stopConsole()
    consoleActive = false
    consoleStopRequested = true
    spyRecording = false
    toggleSpyBtn.Text = "تسجيل: متوقف"
    toggleSpyBtn.TextColor3 = Color3.fromRGB(240, 245, 255)
    if stopConsoleMonitor then pcall(stopConsoleMonitor) end
    pcall(v12RestoreHook)
    pcall(function() inspectorFrame.Visible = false end)
    pcall(function() menuFrame.Visible = false end)
    pcall(function() if gui then gui:Destroy() end end)
end

stopConsoleBtn.MouseButton1Click:Connect(stopConsole)

if not guiParentSet then
    stopConsole()
end

local iconPulse = iconStroke
if iconPulse then
    task.spawn(function()
        while consoleActive and iconPulse.Parent do
            local fadeOut = TweenService:Create(iconPulse, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.8})
            local fadeIn = TweenService:Create(iconPulse, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.4})
            fadeOut:Play()
            fadeOut.Completed:Wait()
            if not consoleActive or not iconPulse.Parent then break end
            fadeIn:Play()
            fadeIn.Completed:Wait()
        end
    end)
end

local function finishConsoleStartup()
    if not consoleActive then return end
    pcall(function()
        iconBtn.Visible = true
        menuFrame.Visible = false
        inspectorFrame.Visible = false
    end)
end

task.defer(finishConsoleStartup)

