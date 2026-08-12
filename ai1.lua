local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

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
    make_writeable = function() return make_writeable end,
    writefile = function() return writefile end,
    readfile = function() return readfile end,
    isfile = function() return isfile end,
    setclipboard = function() return setclipboard end,
    toclipboard = function() return toclipboard end,
    gethui = function() return gethui end,
    request = function() return request end,
    http_request = function() return http_request end,
    syn = function() return syn end,
    http = function() return http end
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

    local okSyn, synEnv = pcall(function() return directGlobal("syn") end)
    if okSyn then add("syn", synEnv) end
    local okHttp, httpEnv = pcall(function() return directGlobal("http") end)
    if okHttp then add("http", httpEnv) end
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

local function lookupTable(name)
    local direct = directGlobal(name)
    if type(direct) == "table" then return direct end
    for _, item in ipairs(EnvironmentTables) do
        local ok, value = pcall(function() return rawget(item.Value, name) end)
        if ok and type(value) == "table" then return value end
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
    writefile = lookupFunction("writefile"),
    readfile = lookupFunction("readfile"),
    isfile = lookupFunction("isfile"),
    setclipboard = lookupFunction("setclipboard") or lookupFunction("toclipboard"),
    gethui = lookupFunction("gethui")
}

local synTable = lookupTable("syn")
local httpTable = lookupTable("http")
local requestFunction = lookupFunction("request") or lookupFunction("http_request")
if not requestFunction and type(synTable) == "table" then requestFunction = isFunction(synTable.request) end
if not requestFunction and type(httpTable) == "table" then requestFunction = isFunction(httpTable.request) end

local errorHistory = {}
local sessionFiles = {}
local EnvironmentStatus
local function reportError(domain, message)
    local entry = string.format("[%s] %s", tostring(domain or "General"), tostring(message or "Unknown error"))
    table.insert(errorHistory, {Domain = tostring(domain or "General"), Message = tostring(message or "Unknown error"), Timestamp = os.time()})
    if #errorHistory > 100 then table.remove(errorHistory, 1) end
    pcall(function() print("[RE] " .. entry) end)
    return entry
end

local Safe = {}
Safe.reportError = reportError
Safe.getErrors = function() return errorHistory end
Safe.clearErrors = function() table.clear(errorHistory) end
Safe.getEnvironmentStatus = function()
    return {
        HTTP = requestFunction ~= nil,
        Clipboard = Native.setclipboard ~= nil,
        Filesystem = Native.writefile ~= nil or Native.readfile ~= nil or Native.isfile ~= nil,
        UIHost = EnvironmentStatus and EnvironmentStatus.UIHost or false,
        Hooks = Native.getrawmetatable ~= nil and Native.newcclosure ~= nil and Native.getnamecallmethod ~= nil and Native.setreadonly ~= nil
    }
end
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
Safe.http_request = function(options)
    if not requestFunction then
        reportError("HTTP", "HTTP API unavailable")
        return nil, "HTTP API unavailable"
    end

    local maxRetries = 3
    local backoffDelay = 1.5
    local lastResponse = nil
    local lastError = nil

    for attempt = 1, maxRetries do
        local ok, response = pcall(requestFunction, options)
        if not ok then
            lastError = response
            reportError("HTTP", response)
        else
            lastResponse = response
            if type(response) == "table" then
                local status = tonumber(response.StatusCode or response.status_code or response.Status or response.status)
                if status == 429 and attempt < maxRetries then
                    pcall(function() warn(string.format("[RE] HTTP 429 Rate Limit encountered. Retrying in %.1fs (attempt %d/%d)...", backoffDelay, attempt, maxRetries)) end)
                    task.wait(backoffDelay)
                    backoffDelay = backoffDelay * 2
                else
                    return response
                end
            else
                return response
            end
        end
        if attempt < maxRetries then
            task.wait(backoffDelay)
            backoffDelay = backoffDelay * 2
        end
    end

    return lastResponse, lastError and ("HTTP request exception: " .. tostring(lastError)) or "HTTP request failed after retries"
end
Safe.canHook = Native.getrawmetatable ~= nil and Native.newcclosure ~= nil and Native.getnamecallmethod ~= nil and Native.setreadonly ~= nil

EnvironmentStatus = {
    HTTP = requestFunction ~= nil,
    Clipboard = Native.setclipboard ~= nil,
    Filesystem = Native.writefile ~= nil or Native.readfile ~= nil or Native.isfile ~= nil,
    UIHost = false,
    Hooks = Safe.canHook
}
pcall(function()
    print(string.format("[RE] Environment | HTTP: %s | Clipboard: %s | Filesystem: %s | Hooks: %s", EnvironmentStatus.HTTP and "READY" or "UNAVAILABLE", EnvironmentStatus.Clipboard and "READY" or "UNAVAILABLE", EnvironmentStatus.Filesystem and "READY" or "UNAVAILABLE", EnvironmentStatus.Hooks and "READY" or "UNAVAILABLE"))
end)

local INSPECTOR_SETTINGS = {
    MaxLogs = 150,
    MaxDepth = 5,
    MaxStringLength = 500,
    Deduplicate = true,
    LogsPerFrame = 10
}

local AI_SUMMARY_SETTINGS = {
    MaxGroups = 35,
    MaxSummaryLength = 8000,
    MaxValueLength = 160,
    MaxChatMessages = 4
}

local DEFAULT_AI_MODEL = "google/gemma-4-26b-a4b-it:free"
local EXTRA_AI_MODEL = "nvidia/nemotron-3-nano-30b-a3b:free"
local MODEL_FILE = "re_ai_model.txt"
local remoteListeners = setmetatable({}, {__mode = "k"})

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

local iconBtn = Instance.new("TextButton")
iconBtn.Size = UDim2.new(0, 40, 0, 40)
iconBtn.Position = UDim2.new(0, 15, 0, 15)
iconBtn.BackgroundColor3 = Color3.fromRGB(38, 34, 58)
iconBtn.BorderSizePixel = 0
iconBtn.Text = "RE"
iconBtn.TextColor3 = Color3.fromRGB(248, 247, 255)
iconBtn.TextStrokeTransparency = 0.8
iconBtn.Font = Enum.Font.GothamBold
iconBtn.TextSize = 16
iconBtn.AutoButtonColor = false
iconBtn.Parent = gui
makeDraggable(iconBtn, iconBtn)

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0, 12)
iconCorner.Parent = iconBtn
local iconStroke = Instance.new("UIStroke")
iconStroke.Color = Color3.fromRGB(143, 104, 255)
iconStroke.Thickness = 1.4
iconStroke.Transparency = 0.18
iconStroke.Parent = iconBtn
local iconGradient = Instance.new("UIGradient")
iconGradient.Rotation = 135
iconGradient.Color = ColorSequence.new(Color3.fromRGB(104, 67, 190), Color3.fromRGB(33, 166, 190))
iconGradient.Parent = iconBtn
iconBtn.MouseEnter:Connect(function()
    TweenService:Create(iconBtn, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 42, 0, 42)}):Play()
end)
iconBtn.MouseLeave:Connect(function()
    TweenService:Create(iconBtn, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 40, 0, 40)}):Play()
end)

local menuFrame = Instance.new("Frame")
menuFrame.Size = UDim2.new(0, 330, 0, 285)
menuFrame.Position = UDim2.new(0, 65, 0, 15)
menuFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
menuFrame.BorderSizePixel = 1
menuFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
menuFrame.Visible = false
menuFrame.Active = false 
menuFrame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 0, 26)
title.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
title.BorderSizePixel = 0
title.Text = "  RE Ultimate Panel"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Active = true 
title.Parent = menuFrame
makeDraggable(title, menuFrame)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 26)
closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
closeBtn.Font = Enum.Font.Code
closeBtn.TextSize = 14
closeBtn.Parent = menuFrame

local function createButton(parent, posX, posY, width, height, text)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, width, 0, height)
    btn.Position = UDim2.new(0, posX, 0, posY)
    btn.BackgroundColor3 = Color3.fromRGB(37, 42, 52)
    btn.BackgroundTransparency = 0.04
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(232, 238, 248)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(105, 125, 155)
    stroke.Transparency = 0.7
    stroke.Thickness = 1
    stroke.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0,
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        if btn.BackgroundColor3 ~= Color3.fromRGB(50, 150, 50) then
            TweenService:Create(btn, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 0.04,
                TextColor3 = Color3.fromRGB(232, 238, 248)
            }):Play()
        end
    end)
    return btn
end

local hitboxBtn = createButton(menuFrame, 8, 34, 100, 34, "هيتبوكس: إيقاف")
local sizeInput = Instance.new("TextBox")
sizeInput.Size = UDim2.new(0, 50, 0, 22)
sizeInput.Position = UDim2.new(0, 114, 0, 40)
sizeInput.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
sizeInput.Text = "20"
sizeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
sizeInput.Font = Enum.Font.Code
sizeInput.TextSize = 12
sizeInput.Parent = menuFrame

local deadlyBtn = createButton(menuFrame, 172, 34, 150, 34, "رصاصة قاتلة: إيقاف")
local rapidBtn = createButton(menuFrame, 8, 76, 150, 34, "الطلق السحري: إيقاف")
local noclipBtn = createButton(menuFrame, 172, 76, 150, 34, "اختراق الجدران: إيقاف")
local invisibleBtn = createButton(menuFrame, 8, 118, 150, 34, "الاختفاء: إيقاف")
local ghostBtn = createButton(menuFrame, 172, 118, 150, 34, "وضع الشبح: إيقاف")
local godBtn = createButton(menuFrame, 8, 160, 314, 34, "الخلود: إيقاف")
local espBtn = createButton(menuFrame, 8, 202, 314, 34, "كشف الأماكن: إيقاف")
local toggleInspectorBtn = createButton(menuFrame, 8, 244, 314, 34, "فتح Remote Inspector ⚡")
toggleInspectorBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 150)

local inspectorFrame = Instance.new("Frame")
inspectorFrame.Size = UDim2.new(0, 620, 0, 360)
inspectorFrame.Position = UDim2.new(0, 405, 0, 15)
inspectorFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
inspectorFrame.BorderSizePixel = 1
inspectorFrame.BorderColor3 = Color3.fromRGB(100, 150, 255)
inspectorFrame.Visible = false
inspectorFrame.Active = false 
inspectorFrame.Parent = gui

local inspectorTitle = Instance.new("TextLabel")
inspectorTitle.Size = UDim2.new(1, -30, 0, 28)
inspectorTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
inspectorTitle.BorderSizePixel = 0
inspectorTitle.Text = "  [RE] Inspector - Network Logger"
inspectorTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
inspectorTitle.Font = Enum.Font.GothamBold
inspectorTitle.TextSize = 11
inspectorTitle.TextXAlignment = Enum.TextXAlignment.Left
inspectorTitle.Active = true
inspectorTitle.Parent = inspectorFrame
makeDraggable(inspectorTitle, inspectorFrame)

local inspectorCloseBtn = Instance.new("TextButton")
inspectorCloseBtn.Size = UDim2.new(0, 30, 0, 28)
inspectorCloseBtn.Position = UDim2.new(1, -30, 0, 0)
inspectorCloseBtn.BackgroundTransparency = 1
inspectorCloseBtn.Text = "X"
inspectorCloseBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
inspectorCloseBtn.Font = Enum.Font.Code
inspectorCloseBtn.TextSize = 14
inspectorCloseBtn.Parent = inspectorFrame

local toolbarFrame = Instance.new("Frame")
toolbarFrame.Size = UDim2.new(1, -10, 0, 30)
toolbarFrame.Position = UDim2.new(0, 5, 0, 33)
toolbarFrame.BackgroundTransparency = 1
toolbarFrame.Parent = inspectorFrame

local toggleSpyBtn = createButton(toolbarFrame, 0, 0, 85, 28, "تسجيل: متوقف")
local clearSpyBtn = createButton(toolbarFrame, 90, 0, 55, 28, "مسح")
clearSpyBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
local copySelectedBtn = createButton(toolbarFrame, 150, 0, 85, 28, "نسخ المحدد")
local copyAllBtn = createButton(toolbarFrame, 240, 0, 85, 28, "نسخ الكل")
copyAllBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
local dedupBtn = createButton(toolbarFrame, 330, 0, 95, 28, "دمج التكرار: ON")
dedupBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
local aiTabBtn = createButton(toolbarFrame, 430, 0, 55, 28, "AI 🤖")
aiTabBtn.BackgroundColor3 = Color3.fromRGB(110, 50, 150)
local modelTabBtn = createButton(toolbarFrame, 490, 0, 65, 28, "النموذج 🔧")
modelTabBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)

local leftScroll = Instance.new("ScrollingFrame")
leftScroll.Size = UDim2.new(0, 250, 1, -70)
leftScroll.Position = UDim2.new(0, 5, 0, 65)
leftScroll.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
leftScroll.BorderSizePixel = 0
leftScroll.ScrollBarThickness = 3
leftScroll.Parent = inspectorFrame

local leftLayout = Instance.new("UIListLayout")
leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
leftLayout.Padding = UDim.new(0, 2)
leftLayout.Parent = leftScroll

local rightScroll = Instance.new("ScrollingFrame")
rightScroll.Size = UDim2.new(1, -265, 1, -70)
rightScroll.Position = UDim2.new(0, 260, 0, 65)
rightScroll.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
rightScroll.BorderSizePixel = 0
rightScroll.ScrollBarThickness = 3
rightScroll.Parent = inspectorFrame

local rightLayout = Instance.new("UIListLayout")
rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
rightLayout.Padding = UDim.new(0, 4)
rightLayout.Parent = rightScroll

leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    leftScroll.CanvasSize = UDim2.new(0, 0, 0, leftLayout.AbsoluteContentSize.Y + 8)
end)
rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    rightScroll.CanvasSize = UDim2.new(0, 0, 0, rightLayout.AbsoluteContentSize.Y + 8)
end)

local aiFrame = Instance.new("Frame")
aiFrame.Size = UDim2.new(1, -265, 1, -70)
aiFrame.Position = UDim2.new(0, 260, 0, 65)
aiFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
aiFrame.BorderSizePixel = 0
aiFrame.Visible = false
aiFrame.Parent = inspectorFrame

local genBtn = createButton(aiFrame, 5, 5, 130, 26, "توليد سكربت ⚡")
genBtn.BackgroundColor3 = Color3.fromRGB(90, 30, 130)
local copyScriptBtn = createButton(aiFrame, 140, 5, 95, 26, "نسخ السكربت 📋")
copyScriptBtn.BackgroundColor3 = Color3.fromRGB(40, 130, 70)
local execAiBtn = createButton(aiFrame, 240, 5, 55, 26, "تنفيذ ✓")
execAiBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 140)

local editInput = Instance.new("TextBox")
editInput.Size = UDim2.new(1, -305, 0, 26)
editInput.Position = UDim2.new(0, 300, 0, 5)
editInput.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
editInput.PlaceholderText = "اكتب تعديلك هنا..."
editInput.Text = ""
editInput.TextColor3 = Color3.fromRGB(255, 255, 255)
editInput.Font = Enum.Font.Code
editInput.TextSize = 11
editInput.Parent = aiFrame

local sendEditBtn = createButton(aiFrame, 1, 35, 110, 26, "تعديل 📝")
sendEditBtn.Position = UDim2.new(1, -112, 0, 35)
sendEditBtn.BackgroundColor3 = Color3.fromRGB(180, 90, 20)

local aiScroll = Instance.new("ScrollingFrame")
aiScroll.Size = UDim2.new(1, -10, 1, -68)
aiScroll.Position = UDim2.new(0, 5, 0, 65)
aiScroll.BackgroundColor3 = Color3.fromRGB(10, 10, 13)
aiScroll.BorderSizePixel = 0
aiScroll.ScrollBarThickness = 3
aiScroll.Parent = aiFrame

local aiScrollLay = Instance.new("UIListLayout")
aiScrollLay.SortOrder = Enum.SortOrder.LayoutOrder
aiScrollLay.Padding = UDim.new(0, 2)
aiScrollLay.Parent = aiScroll

local modelFrame = Instance.new("Frame")
modelFrame.Size = UDim2.new(0, 340, 0, 220)
modelFrame.Position = UDim2.new(0.5, -170, 0.5, -110)
modelFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
modelFrame.BorderSizePixel = 1
modelFrame.BorderColor3 = Color3.fromRGB(100, 100, 150)
modelFrame.Visible = false
modelFrame.Active = true
modelFrame.Parent = inspectorFrame

local modelTitle = Instance.new("TextLabel")
modelTitle.Size = UDim2.new(1, -30, 0, 26)
modelTitle.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
modelTitle.BorderSizePixel = 0
modelTitle.Text = "  إعدادات النموذج الذكي"
modelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
modelTitle.Font = Enum.Font.GothamBold
modelTitle.TextSize = 11
modelTitle.TextXAlignment = Enum.TextXAlignment.Left
modelTitle.Parent = modelFrame
makeDraggable(modelTitle, modelFrame)

local modelCloseBtn = Instance.new("TextButton")
modelCloseBtn.Size = UDim2.new(0, 30, 0, 26)
modelCloseBtn.Position = UDim2.new(1, -30, 0, 0)
modelCloseBtn.BackgroundTransparency = 1
modelCloseBtn.Text = "X"
modelCloseBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
modelCloseBtn.Font = Enum.Font.Code
modelCloseBtn.TextSize = 14
modelCloseBtn.Parent = modelFrame

local apiKeyBox = Instance.new("TextBox")
apiKeyBox.Size = UDim2.new(1, -20, 0, 30)
apiKeyBox.Position = UDim2.new(0, 10, 0, 36)
apiKeyBox.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
apiKeyBox.PlaceholderText = "API Key: sk-or-v1-... (يُحفظ تلقائياً)"
apiKeyBox.Text = ""
apiKeyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
apiKeyBox.Font = Enum.Font.Code
apiKeyBox.TextSize = 11
apiKeyBox.Parent = modelFrame

local modelNameBox = Instance.new("TextBox")
modelNameBox.Size = UDim2.new(1, -20, 0, 30)
modelNameBox.Position = UDim2.new(0, 10, 0, 74)
modelNameBox.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
modelNameBox.PlaceholderText = DEFAULT_AI_MODEL
modelNameBox.Text = DEFAULT_AI_MODEL
modelNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
modelNameBox.Font = Enum.Font.Code
modelNameBox.TextSize = 11
modelNameBox.Parent = modelFrame

local modelMoreBtn = createButton(modelFrame, 10, 110, 320, 26, "↓ عرض المزيد")
modelMoreBtn.BackgroundColor3 = Color3.fromRGB(55, 75, 125)

local modelListFrame = Instance.new("Frame")
modelListFrame.Size = UDim2.new(0, 320, 0, 30)
modelListFrame.Position = UDim2.new(0, 10, 0, 140)
modelListFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
modelListFrame.BorderSizePixel = 0
modelListFrame.Visible = false
modelListFrame.Parent = modelFrame

local extraModelBtn = createButton(modelListFrame, 0, 0, 320, 28, EXTRA_AI_MODEL)
extraModelBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 90)

local applyModelBtn = createButton(modelFrame, 10, 180, 320, 30, "تطبيق")
applyModelBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)

local function addGlassStyle(object, radius, strokeColor, transparency)
    object.BackgroundTransparency = transparency or 0.08
    object.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 10)
    corner.Parent = object
    local stroke = Instance.new("UIStroke")
    stroke.Color = strokeColor or Color3.fromRGB(115, 135, 175)
    stroke.Thickness = 1
    stroke.Transparency = 0.32
    stroke.Parent = object
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 105
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 52, 70)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 30, 43)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 21, 31))
    })
    gradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.08),
        NumberSequenceKeypoint.new(1, 0.2)
    })
    gradient.Parent = object
end

addGlassStyle(menuFrame, 11, Color3.fromRGB(116, 96, 190), 0.06)
addGlassStyle(inspectorFrame, 11, Color3.fromRGB(77, 155, 210), 0.06)
addGlassStyle(modelFrame, 10, Color3.fromRGB(116, 96, 190), 0.04)
addGlassStyle(aiFrame, 8, Color3.fromRGB(96, 76, 155), 0.08)
addGlassStyle(leftScroll, 8, Color3.fromRGB(70, 85, 110), 0.12)
addGlassStyle(rightScroll, 8, Color3.fromRGB(70, 85, 110), 0.12)
addGlassStyle(aiScroll, 8, Color3.fromRGB(70, 85, 110), 0.12)

local menuScale = Instance.new("UIScale")
menuScale.Scale = 0.92
menuScale.Parent = menuFrame
local inspectorScale = Instance.new("UIScale")
inspectorScale.Scale = 0.88
inspectorScale.Parent = inspectorFrame
inspectorFrame.Position = UDim2.new(0.5, -273, 0.5, -158)

local function styleInput(box, accent)
    box.BorderSizePixel = 0
    box.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    box.BackgroundTransparency = 0.08
    box.Font = Enum.Font.Gotham
    box.TextSize = 11
    box.ClearTextOnFocus = false
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = box
    local stroke = Instance.new("UIStroke")
    stroke.Color = accent or Color3.fromRGB(92, 110, 145)
    stroke.Transparency = 0.56
    stroke.Thickness = 1
    stroke.Parent = box
end

styleInput(sizeInput, Color3.fromRGB(130, 105, 220))
styleInput(editInput, Color3.fromRGB(130, 105, 220))
styleInput(apiKeyBox, Color3.fromRGB(90, 150, 210))
styleInput(modelNameBox, Color3.fromRGB(90, 150, 210))

local function styleTopbar(bar, accent)
    bar.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
    bar.BackgroundTransparency = 0.08
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 0
    gradient.Color = ColorSequence.new(Color3.fromRGB(47, 53, 73), Color3.fromRGB(25, 29, 41))
    gradient.Parent = bar
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 2)
    line.Position = UDim2.new(0, 0, 1, -2)
    line.BorderSizePixel = 0
    line.BackgroundColor3 = accent or Color3.fromRGB(137, 97, 235)
    line.Parent = bar
end

styleTopbar(title, Color3.fromRGB(142, 93, 235))
styleTopbar(inspectorTitle, Color3.fromRGB(72, 170, 222))
styleTopbar(modelTitle, Color3.fromRGB(142, 93, 235))

local function showPanel(panel, scaleObject, visible)
    if visible then
        panel.Visible = true
        scaleObject.Scale = scaleObject.Scale - 0.05
        TweenService:Create(scaleObject, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = scaleObject.Scale + 0.05}):Play()
    else
        panel.Visible = false
    end
end

local savedApiKey = ""
local savedModel = DEFAULT_AI_MODEL
if Safe.isfile(MODEL_FILE) then
    local modelContent = Safe.readfile(MODEL_FILE)
    if modelContent and string.gsub(modelContent, "%s+", "") ~= "" then
        savedModel = string.gsub(modelContent, "^%s*(.-)%s*$", "%1")
    end
end
modelNameBox.Text = savedModel

if Safe.isfile("re_ai_key.txt") then
    local content = Safe.readfile("re_ai_key.txt")
    if content and content ~= "" then
        savedApiKey = content
        apiKeyBox.Text = savedApiKey
    end
end

apiKeyBox.FocusLost:Connect(function()
    savedApiKey = apiKeyBox.Text
    if savedApiKey ~= "" then
        Safe.writefile("re_ai_key.txt", savedApiKey)
    end
end)

local function normalizeModelName(value)
    local model = string.gsub(tostring(value or ""), "^%s*(.-)%s*$", "%1")
    return model ~= "" and model or DEFAULT_AI_MODEL
end

modelMoreBtn.MouseButton1Click:Connect(function()
    modelListFrame.Visible = not modelListFrame.Visible
    modelMoreBtn.Text = modelListFrame.Visible and "↑ إخفاء النماذج" or "↓ عرض المزيد"
end)

extraModelBtn.MouseButton1Click:Connect(function()
    modelNameBox.Text = EXTRA_AI_MODEL
    modelListFrame.Visible = false
    modelMoreBtn.Text = "↓ عرض المزيد"
end)

applyModelBtn.MouseButton1Click:Connect(function()
    savedApiKey = string.gsub(apiKeyBox.Text or "", "^%s*(.-)%s*$", "%1")
    savedModel = normalizeModelName(modelNameBox.Text)
    modelNameBox.Text = savedModel
    if savedApiKey ~= "" then Safe.writefile("re_ai_key.txt", savedApiKey) end
    Safe.writefile(MODEL_FILE, savedModel)
    modelFrame.Visible = false
    inspectorTitle.Text = "  [RE] Inspector - AI Model: " .. savedModel
end)

aiTabBtn.MouseButton1Click:Connect(function()
    rightScroll.Visible = false
    aiFrame.Visible = true
end)

modelTabBtn.MouseButton1Click:Connect(function()
    modelFrame.Visible = not modelFrame.Visible
end)

modelCloseBtn.MouseButton1Click:Connect(function()
    modelFrame.Visible = false
end)

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

local logsDatabase = {}
local logQueue = {}
local logCounter = 0
local activeTreeData = ""
local spyRecording = false

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
    for index, value in ipairs(args or {}) do
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
        row.Size = UDim2.new(1, 0, 0, 18)
        row.BackgroundTransparency = 1
        row.Font = Enum.Font.Code
        row.TextSize = 11
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
            row.TextColor3 = Color3.fromRGB(200, 200, 200)
            row.Parent = parent
            textStr = textStr .. row.Text .. "\n"
        end
    end
    return textStr
end

local function drawLogUI(logData)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -6, 0, 42)
    btn.Position = UDim2.new(0, 3, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(29, 35, 47)
    btn.BackgroundTransparency = 0.08
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = ""
    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 6)
    rowCorner.Parent = btn
    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color = logData.Direction == "Incoming ⬇️" and Color3.fromRGB(73, 170, 132) or Color3.fromRGB(125, 103, 195)
    rowStroke.Transparency = 0.76
    rowStroke.Thickness = 1
    rowStroke.Parent = btn
    btn.LayoutOrder = -logData.ID
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -6, 1, 0)
    lbl.Position = UDim2.new(0, 3, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.RichText = true
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = btn
    
    local function updateText()
        local countStr = logData.Count > 1 and string.format(" <font color='rgb(255,100,100)'>x%d</font>", logData.Count) or ""
        local dirColor = logData.Direction == "Incoming ⬇️" and "rgb(100,255,100)" or "rgb(255,100,100)"
        local senderStr = logData.Sender == "Server" and "<font color='rgb(150,150,255)'>Server</font>" or string.format("<font color='rgb(255,200,100)'>%s</font>", logData.Sender)
        
        lbl.Text = string.format("<b>#%03d</b> %s%s\n<font color='%s'>%s</font> | %s\n<font color='rgb(150,150,150)'>%s | Sender: %s</font>", 
            logData.ID, logData.Name, countStr, dirColor, logData.Direction, logData.Method, logData.Timestamp, senderStr)
    end
    updateText()
    
    btn.MouseButton1Click:Connect(function()
        rightScroll.Visible = true
        aiFrame.Visible = false
        for _, c in ipairs(rightScroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
        
        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, 0, 0, 75)
        header.BackgroundTransparency = 1
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Font = Enum.Font.Code
        header.TextSize = 11
        header.TextColor3 = Color3.fromRGB(220, 220, 220)
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
    toggleSpyBtn.Text = spyRecording and "تسجيل: شغال" or "تسجيل: متوقف"
    toggleSpyBtn.BackgroundColor3 = spyRecording and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(40, 40, 45)
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
        copySelectedBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    elseif copyError == "Clipboard API unavailable" then
        copySelectedBtn.Text = "الحافظة غير مدعومة"
    else
        copySelectedBtn.Text = "فشل النسخ"
    end
    task.delay(1.5, function()
        copySelectedBtn.Text = "نسخ المحدد"
        copySelectedBtn.BackgroundColor3 = Color3.fromRGB(37, 42, 52)
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
        copyAllBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    elseif copyError == "Clipboard API unavailable" then
        copyAllBtn.Text = "الحافظة غير مدعومة"
        copyAllBtn.BackgroundColor3 = Color3.fromRGB(120, 55, 45)
    else
        copyAllBtn.Text = "فشل النسخ"
        copyAllBtn.BackgroundColor3 = Color3.fromRGB(120, 55, 45)
    end
    task.delay(1.8, function()
        copyAllBtn.Text = "نسخ الكل"
        copyAllBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    end)
end)

dedupBtn.MouseButton1Click:Connect(function()
    INSPECTOR_SETTINGS.Deduplicate = not INSPECTOR_SETTINGS.Deduplicate
    dedupBtn.Text = "دمج التكرار: " .. (INSPECTOR_SETTINGS.Deduplicate and "ON" or "OFF")
    dedupBtn.BackgroundColor3 = INSPECTOR_SETTINGS.Deduplicate and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(100, 50, 50)
end)

local function trimForAi(value, maxLength)
    local text = tostring(value or "")
    maxLength = maxLength or AI_SUMMARY_SETTINGS.MaxValueLength
    return #text > maxLength and string.sub(text, 1, maxLength) .. "..." or text
end

local function stableSerialize(value, depth)
    depth = depth or 0
    if depth > INSPECTOR_SETTINGS.MaxDepth then return "{MaxDepth}" end
    if type(value) ~= "table" then return trimForAi(value) end
    local keys = {}
    for key in pairs(value) do table.insert(keys, tostring(key)) end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do table.insert(parts, key .. "=" .. stableSerialize(value[key], depth + 1)) end
    return "{" .. table.concat(parts, ";") .. "}"
end

local function inferEventHints(logData)
    local source = string.lower(tostring(logData.Name or "") .. " " .. stableSerialize(logData.Args or {}, 0))
    local result = {}
    local words = {"kill", "death", "damage", "hit", "shoot", "shot", "fire", "respawn", "spawn", "heal", "ammo", "equip", "purchase", "buy", "round"}
    for _, word in ipairs(words) do
        if string.find(source, word, 1, true) then result[word] = true end
    end
    local values = {}
    for word in pairs(result) do table.insert(values, word) end
    table.sort(values)
    return #values > 0 and table.concat(values, ", ") or "unknown"
end

local function sortedSet(set)
    local values = {}
    for value in pairs(set) do table.insert(values, value) end
    table.sort(values)
    return values
end

-- Keep every raw record locally; send one representative sample per Remote path to the AI.
local function buildAiSummary()
    local groups = {}
    for _, log in ipairs(logsDatabase) do
        local key = tostring(log.Path or log.Name or "UnknownRemote")
        local group = groups[key]
        if not group then
            group = {Name = log.Name or "Unknown", Path = key, Occurrences = 0, Payloads = {}, TypeShapes = {}, Methods = {}, Directions = {}, Senders = {}, Hints = {}, Sample = log, LastId = 0}
            groups[key] = group
        end
        group.Occurrences = group.Occurrences + (tonumber(log.Count) or 1)
        group.Payloads[stableSerialize(log.Args or {}, 0)] = true
        group.TypeShapes[table.concat(log.ArgTypes or {}, ",")] = true
        group.Methods[tostring(log.Method or "unknown")] = true
        group.Directions[tostring(log.Direction or "unknown")] = true
        group.Senders[tostring(log.Sender or "unknown")] = true
        group.Hints[inferEventHints(log)] = true
        if (tonumber(log.ID) or 0) >= group.LastId then group.Sample, group.LastId = log, tonumber(log.ID) or 0 end
    end

    local ordered = {}
    for _, group in pairs(groups) do table.insert(ordered, group) end
    table.sort(ordered, function(a, b) return a.Occurrences == b.Occurrences and a.Path < b.Path or a.Occurrences > b.Occurrences end)
    local lines = {
        "=== COMPACT CONSOLE SUMMARY ===",
        string.format("PlaceId=%s | GameId=%s | Name=%s", tostring(game.PlaceId), tostring(game.GameId), tostring(game.Name)),
        string.format("RawVisibleRecords=%d | UniqueRemotes=%d", #logsDatabase, #ordered),
        "Policy=one representative sample per Remote path; repetition is aggregated locally",
        ""
    }
    for index = 1, math.min(#ordered, AI_SUMMARY_SETTINGS.MaxGroups) do
        local group = ordered[index]
        local line = string.format("[%02d] Remote=%s | Path=%s | Occurrences=%d | UniquePayloads=%d | TypeShapes=%d | Methods=%s | Directions=%s | Senders=%s | EventHints=%s\nSampleTypes=%s\nSampleArgs=%s\n", index, trimForAi(group.Name), trimForAi(group.Path, 420), group.Occurrences, #sortedSet(group.Payloads), #sortedSet(group.TypeShapes), trimForAi(table.concat(sortedSet(group.Methods), ", "), 180), trimForAi(table.concat(sortedSet(group.Directions), ", "), 180), trimForAi(table.concat(sortedSet(group.Senders), ", "), 220), trimForAi(table.concat(sortedSet(group.Hints), ", "), 180), trimForAi(table.concat(group.Sample.ArgTypes or {}, ", "), 260), trimForAi(stableSerialize(group.Sample.Args or {}, 0), AI_SUMMARY_SETTINGS.MaxValueLength * 4))
        if #(table.concat(lines, "\n")) + #line > AI_SUMMARY_SETTINGS.MaxSummaryLength then
            table.insert(lines, string.format("... truncated after %d Remote groups ...", index - 1))
            break
        end
        table.insert(lines, line)
    end
    return table.concat(lines, "\n")
end

local chatHistory = {}
local latestGeneratedScript = ""
local function trimChatHistory()
    while #chatHistory > AI_SUMMARY_SETTINGS.MaxChatMessages do table.remove(chatHistory, 2) end
end

local function appendAiOutput(text, color)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 11
    lbl.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text
    lbl.Parent = aiScroll
    aiScroll.CanvasSize = UDim2.new(0, 0, 0, aiScrollLay.AbsoluteContentSize.Y + 20)
end

local aiRequestBusy = false

local function setAiBusy(busy)
    aiRequestBusy = busy
    genBtn.Active = not busy
    sendEditBtn.Active = not busy
    genBtn.AutoButtonColor = not busy
    sendEditBtn.AutoButtonColor = not busy
    genBtn.BackgroundColor3 = busy and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(90, 30, 130)
    sendEditBtn.BackgroundColor3 = busy and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(180, 90, 20)
end

local function responseField(response, ...)
    if type(response) ~= "table" then return nil end
    for _, key in ipairs({...}) do
        if response[key] ~= nil then return response[key] end
    end
    return nil
end

local function extractApiError(responseBody, decoded)
    if type(decoded) == "table" and type(decoded.error) == "table" then
        return tostring(decoded.error.message or decoded.error.code or "Unknown API error")
    end
    local text = tostring(responseBody or "")
    return #text > 500 and string.sub(text, 1, 500) .. "..." or (text ~= "" and text or "Unknown network error")
end

local function callOpenRouter(userPromptText)
    if aiRequestBusy then
        appendAiOutput("انتظر انتهاء الطلب الحالي.", Color3.fromRGB(255, 220, 100))
        return
    end
    if savedApiKey == "" then
        appendAiOutput("خطأ: مطلوب مفتاح API - افتح تبويبة النموذج والصق مفتاح OpenRouter.", Color3.fromRGB(255, 50, 50))
        return
    end

    setAiBusy(true)
    appendAiOutput("جارٍ الاتصال بـ OpenRouter...", Color3.fromRGB(255, 255, 100))

    if #chatHistory == 0 then
        table.insert(chatHistory, {
            role = "system",
            content = [[أنت مهندس Luau متخصص في أدوات الاختبار والمراقبة المصرّح بها داخل ألعاب Roblox التي يملك المستخدم كودها أو يملك إذن اختبارها.

هدفك إنتاج كود قابل للتشغيل فعلياً، وليس قالباً شكلياً. استخدم سجل الشبكة كبيانات تشخيصية فقط ولا تحوّل أي Remote إلى أداة غش أو تخريب أو تجاوز صلاحيات.

استخدم ملخصات Remote المضغوطة كما هي: Occurrences تعني عدد التكرارات، وUniquePayloads عدد أشكال البيانات المختلفة، وSampleArgs عينة تشخيصية واحدة. لا تطلب إعادة إرسال التكرارات ولا تفترض وظيفة Remote من الاسم وحده.

عند نقص البيانات، أنشئ أدوات اختبار محلية آمنة داخل Roblox Studio أو تجربة يملكها المطور، ولا تنفذ الكود المولد تلقائياً. أخرج كود Luau كامل فقط داخل ```lua ... ``` ولا تكتب أي نص خارجه.]]
        })
    end

    table.insert(chatHistory, {role = "user", content = tostring(userPromptText or "")})
    trimChatHistory()

    task.spawn(function()
        local selectedModel = normalizeModelName(modelNameBox.Text)
        local payloadData = {
            model = selectedModel,
            messages = chatHistory,
            max_tokens = 4000,
            temperature = 0.2,
            stream = false
        }

        local response, requestError = Safe.http_request({
            Url = "https://openrouter.ai/api/v1/chat/completions",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["Accept"] = "application/json",
                ["Authorization"] = "Bearer " .. savedApiKey,
                ["HTTP-Referer"] = "https://openrouter.ai",
                ["X-Title"] = "RE Panel AI"
            },
            Body = HttpService:JSONEncode(payloadData)
        })

        local responseBody = responseField(response, "Body", "body")
        local statusCode = tonumber(responseField(response, "StatusCode", "status_code", "Status", "status"))
        local decoded = nil
        local decodeSuccess = false
        if responseBody ~= nil then
            decodeSuccess, decoded = pcall(function() return HttpService:JSONDecode(tostring(responseBody)) end)
        end

        if response == nil then
            appendAiOutput(tostring(requestError or "HTTP API unavailable"), Color3.fromRGB(255, 70, 70))
        elseif statusCode and (statusCode < 200 or statusCode >= 300) then
            local errDetail = extractApiError(responseBody, decoded)
            Safe.reportError("HTTP", string.format("HTTP %d: %s", statusCode, errDetail))
            appendAiOutput(string.format("فشل OpenRouter [HTTP %d]: %s", statusCode, errDetail), Color3.fromRGB(255, 70, 70))
        elseif responseBody == nil then
            appendAiOutput("HTTP response body غير موجود", Color3.fromRGB(255, 70, 70))
        elseif not decodeSuccess then
            Safe.reportError("HTTP", "Invalid JSON: " .. tostring(decoded))
            appendAiOutput("Invalid JSON", Color3.fromRGB(255, 70, 70))
        elseif type(decoded) ~= "table" or type(decoded.choices) ~= "table" or not decoded.choices[1] or type(decoded.choices[1].message) ~= "table" then
            appendAiOutput("رد OpenRouter لا يحتوي على choices/message صالح.", Color3.fromRGB(255, 70, 70))
        else
            local replyContent = tostring(decoded.choices[1].message.content or "")
            if replyContent == "" then
                appendAiOutput("رد OpenRouter فارغ.", Color3.fromRGB(255, 70, 70))
            else
                table.insert(chatHistory, {role = "assistant", content = replyContent})
                trimChatHistory()
                local scriptMatch = string.match(replyContent, "```lua%s*(.-)%s*```") or string.match(replyContent, "```%s*(.-)%s*```") or replyContent
                latestGeneratedScript = scriptMatch
                appendAiOutput("تم استلام رد الذكاء الاصطناعي.", Color3.fromRGB(100, 255, 100))
                for line in string.gmatch(scriptMatch, "[^\r\n]+") do appendAiOutput(line, Color3.fromRGB(170, 220, 255)) end
            end
        end

        setAiBusy(false)
    end)
end

genBtn.MouseButton1Click:Connect(function()
    callOpenRouter(buildAiSummary())
end)

sendEditBtn.MouseButton1Click:Connect(function()
    if editInput.Text == "" then return end
    local promptText = editInput.Text
    editInput.Text = ""
    callOpenRouter(promptText)
end)

copyScriptBtn.MouseButton1Click:Connect(function()
    if latestGeneratedScript == "" then
        copyScriptBtn.Text = "لا يوجد سكربت!"
    else
        local copied, copyError = Safe.setclipboard(latestGeneratedScript)
        if copied then
            copyScriptBtn.Text = "تم النسخ ✓"
            copyScriptBtn.BackgroundColor3 = Color3.fromRGB(30, 160, 80)
        elseif copyError == "Clipboard API unavailable" then
            copyScriptBtn.Text = "الحافظة غير مدعومة"
        else
            copyScriptBtn.Text = "فشل النسخ"
        end
    end
    task.delay(1.5, function()
        copyScriptBtn.Text = "نسخ السكربت 📋"
        copyScriptBtn.BackgroundColor3 = Color3.fromRGB(40, 130, 70)
    end)
end)

execAiBtn.Text = "فحص النص ✓"
execAiBtn.MouseButton1Click:Connect(function()
    if latestGeneratedScript == "" then
        appendAiOutput("لا يوجد نص مولد لفحصه.", Color3.fromRGB(255, 220, 100))
        return
    end
    local balance = 0
    for _ in string.gmatch(latestGeneratedScript, "function") do balance = balance + 1 end
    for _ in string.gmatch(latestGeneratedScript, "end") do balance = balance - 1 end
    if balance == 0 then
        appendAiOutput("الفحص النصي الأولي نجح. لم يتم تنفيذ الكود.", Color3.fromRGB(100, 255, 100))
    else
        appendAiOutput("يوجد احتمال عدم توازن بين function وend. راجع الكود يدوياً.", Color3.fromRGB(255, 180, 80))
    end
end)

local function setupRemoteListener(obj)
    if remoteListeners[obj] then return end
    if not obj:IsA("RemoteEvent") then return end
    remoteListeners[obj] = true
    pcall(function()
            obj.OnClientEvent:Connect(function(...)
                if not spyRecording then return end
                local args = {...}
                
                local sender = "Server"
                for _, arg in pairs(args) do
                    if typeof(arg) == "Instance" and arg:IsA("Player") and arg ~= LocalPlayer then
                        sender = "Player: " .. arg.Name
                        break
                    end
                end

                task.defer(function()
                    if #logQueue >= INSPECTOR_SETTINGS.MaxLogs * 2 then
                        table.remove(logQueue, 1)
                    end
                    logCounter = logCounter + 1
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
            end)
        end)
    end

for _, obj in ipairs(game:GetDescendants()) do
    setupRemoteListener(obj)
end

game.DescendantAdded:Connect(function(obj)
    setupRemoteListener(obj)
end)

local rapidEnabled = false
local hitboxEnabled, deadlyEnabled, noclipEnabled, invisibleEnabled, ghostEnabled, godModeEnabled, espEnabled = false, false, false, false, false, false, false
local hitboxSize = 20

if Safe.canHook then
    pcall(function()
        local mt = Safe.getrawmetatable(game)
        if mt then
            local oldNamecall = mt.__namecall
            local writable = Safe.setreadonly(mt, false)
            if writable and type(oldNamecall) == "function" then
                mt.__namecall = Safe.newcclosure(function(self, ...)
                    local args = {...}
                    local method = Safe.getnamecallmethod()
            
            if spyRecording and not Safe.checkcaller() and (method == "FireServer" or method == "InvokeServer") then
                local sName, rName = pcall(function() return self.Name end)
                local sClass, rClass = pcall(function() return self.ClassName end)
                local sPath, rPath = pcall(function() return self:GetFullName() end)
                
                local remoteName = sName and rName or "Unknown"
                local remoteClass = sClass and rClass or "Unknown"
                local remotePath = sPath and rPath or "Unknown"
                
                local safeArgs = {}
                for i, v in ipairs(args) do safeArgs[i] = v end
                
                task.defer(function()
                    if #logQueue >= INSPECTOR_SETTINGS.MaxLogs * 2 then
                        table.remove(logQueue, 1)
                    end
                    logCounter = logCounter + 1
                    local parsed = parseData(safeArgs)
                    
                    table.insert(logQueue, {
                        ID = logCounter,
                        Name = remoteName,
                        Class = remoteClass,
                        Method = method,
                        Direction = "Outgoing ⬆️",
                        Sender = "You (" .. LocalPlayer.Name .. ")",
                        Path = remotePath,
                        Timestamp = formatTime(),
                        Args = parsed,
                        ArgTypes = getArgumentTypes(args),
                        ArgCount = #args,
                        Count = 1
                    })
                end)
            end
            
            local successRN, remoteNameVal = pcall(function() return self.Name end)
            if rapidEnabled and not Safe.checkcaller() and method == "FireServer" and successRN and remoteNameVal == "RequestActionSync" then
                local target = nil
                local shortestDist = math.huge
                
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                        local pos, onScreen = Camera:WorldToViewportPoint(p.Character.Head.Position)
                        if onScreen then
                            local dist = (Vector2.new(Mouse.X, Mouse.Y) - Vector2.new(pos.X, pos.Y)).Magnitude
                            if dist < shortestDist then target = p; shortestDist = dist end
                        end
                    end
                end
                
                if target then
                    local head = target.Character.Head
                    for i, v in pairs(args) do
                        if type(v) == "table" and rawget(v, "hitPosition") ~= nil then
                            v.hitInstance = head
                            v.hitHumanoid = target.Character.Humanoid
                            v.hitPosition = head.Position
                            v.direction = (head.Position - (v.origin or head.Position)).Unit
                            v.IsHeadshot = true
                            args[i] = v
                            return oldNamecall(self, unpack(args))
                        end
                    end
                end
            end
            
                    return oldNamecall(self, ...)
                end)
                Safe.setreadonly(mt, true)
            else
                Safe.setreadonly(mt, true)
            end
        end
    end)
end

sizeInput.FocusLost:Connect(function()
    local num = tonumber(sizeInput.Text)
    if num then hitboxSize = math.clamp(num, 2, 200); sizeInput.Text = tostring(hitboxSize) end
end)

local function clearESP()
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local highlight = character and character:FindFirstChild("RE_HL")
        if highlight then highlight:Destroy() end
    end
end

local function toggleBtn(btn, textOn, textOff)
    btn.MouseButton1Click:Connect(function()
        local currentState = false
        if btn == rapidBtn then rapidEnabled = not rapidEnabled; currentState = rapidEnabled
        elseif btn == hitboxBtn then hitboxEnabled = not hitboxEnabled; currentState = hitboxEnabled
        elseif btn == deadlyBtn then deadlyEnabled = not deadlyEnabled; currentState = deadlyEnabled
        elseif btn == noclipBtn then noclipEnabled = not noclipEnabled; currentState = noclipEnabled
        elseif btn == invisibleBtn then invisibleEnabled = not invisibleEnabled; currentState = invisibleEnabled
        elseif btn == ghostBtn then ghostEnabled = not ghostEnabled; currentState = ghostEnabled
        elseif btn == godBtn then godModeEnabled = not godModeEnabled; currentState = godModeEnabled
        elseif btn == espBtn then 
            espEnabled = not espEnabled
            if not espEnabled then clearESP() end
            currentState = espEnabled 
        end
        
        if currentState then
            btn.BackgroundTransparency = 0
            btn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        else
            btn.BackgroundTransparency = 0.04
            btn.BackgroundColor3 = Color3.fromRGB(37, 42, 52)
        end
        btn.Text = currentState and textOn or textOff
    end)
end

toggleBtn(hitboxBtn, "هيتبوكس: تشغيل", "هيتبوكس: إيقاف")
toggleBtn(deadlyBtn, "رصاصة قاتلة: تشغيل", "رصاصة قاتلة: إيقاف")
toggleBtn(rapidBtn, "الطلق السحري: تشغيل", "الطلق السحري: إيقاف")
toggleBtn(noclipBtn, "اختراق الجدران: تشغيل", "اختراق الجدران: إيقاف")
toggleBtn(invisibleBtn, "الاختفاء: تشغيل", "الاختفاء: إيقاف")
toggleBtn(ghostBtn, "وضع الشبح: تشغيل", "وضع الشبح: إيقاف")
toggleBtn(godBtn, "الخلود: تشغيل", "الخلود: إيقاف")
toggleBtn(espBtn, "كشف الأماكن: تشغيل", "كشف الأماكن: إيقاف")

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")

    if hitboxEnabled or deadlyEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = player.Character.HumanoidRootPart
                hrp.CanCollide = false
                hrp.Transparency = 0.3
                if deadlyEnabled then 
                    hrp.Size = Vector3.new(6, 6, 6); hrp.CFrame = Camera.CFrame * CFrame.new(0, 0, -12)
                else 
                    hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize) 
                end
            end
        end
    end

    if noclipEnabled and char then
        for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
    end

    if invisibleEnabled and char then
        for _, desc in ipairs(char:GetDescendants()) do if desc:IsA("BasePart") then desc.Transparency = 1 end end
    end

    if godModeEnabled and humanoid then
        pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false); humanoid.MaxHealth = 9e9; humanoid.Health = 9e9 end)
    end

    if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.Anchored = ghostEnabled end
    
    if espEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and not player.Character:FindFirstChild("RE_HL") then
                local highlight = Instance.new("Highlight")
                highlight.Name = "RE_HL"
                highlight.FillColor = Color3.fromRGB(255, 0, 0)
                highlight.FillTransparency = 0.5
                highlight.OutlineTransparency = 0
                highlight.Parent = player.Character
            end
        end
    end
end)


