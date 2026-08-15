local consoleActive = true
local consoleStopRequested = false
local v12OwnedConnections = {}
local v12HeartbeatConnection = nil
local v12RenderConnection = nil
local v12DescendantConnection = nil
local v12UiViewportConnection = nil
local v12HookMt = nil
local v12OldNamecall = nil
local v12HookInstalled = false
local v12OriginalPartState = {}
local v13OriginalHumanoidState = {}
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

    local requestDeadline = type(options) == "table" and tonumber(options.__Deadline) or nil
    if type(options) == "table" then options.__Deadline = nil end
    local maxRetries = 3
    local backoffDelay = 1.5
    local lastResponse = nil
    local lastError = nil

    local function remainingSeconds()
        return requestDeadline and (requestDeadline - os.clock()) or nil
    end

    for attempt = 1, maxRetries do
        local remaining = remainingSeconds()
        if remaining and remaining <= 0 then
            return lastResponse, "HTTP request timeout after " .. tostring(AI_REQUEST_TIMEOUT_SECONDS) .. " seconds"
        end
        if remaining and type(options) == "table" then options.Timeout = math.max(1, remaining) end

        local ok, response = pcall(requestFunction, options)
        if not ok then
            lastError = response
            reportError("HTTP", response)
        else
            lastResponse = response
            if type(response) == "table" then
                local status = tonumber(response.StatusCode or response.status_code or response.Status or response.status)
                if status and (status == 429 or status >= 500) and attempt < maxRetries then
                    remaining = remainingSeconds()
                    if remaining and remaining <= 0 then
                        return response, "HTTP request timeout after " .. tostring(AI_REQUEST_TIMEOUT_SECONDS) .. " seconds"
                    end
                    local waitSeconds = remaining and math.min(backoffDelay, remaining) or backoffDelay
                    pcall(function() warn(string.format("[RE] HTTP %d transient response. Retrying in %.1fs (attempt %d/%d)...", status, waitSeconds, attempt, maxRetries)) end)
                    task.wait(waitSeconds)
                    backoffDelay = backoffDelay * 2
                else
                    return response
                end
            else
                return response
            end
        end
        if attempt < maxRetries then
            remaining = remainingSeconds()
            if remaining and remaining <= 0 then
                return lastResponse, "HTTP request timeout after " .. tostring(AI_REQUEST_TIMEOUT_SECONDS) .. " seconds"
            end
            local waitSeconds = remaining and math.min(backoffDelay, remaining) or backoffDelay
            task.wait(waitSeconds)
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
local EXTRA_AI_MODEL = "poolside/laguna-xs-2.1:free"
local SECONDARY_AI_MODEL = "nvidia/nemotron-3-nano-30b-a3b:free"
local MODEL_FILE = "re_ai_model.txt"
local AI_REQUEST_TIMEOUT_SECONDS = 240
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
iconBtn.Text = "ℝ𝔼"
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
modelListFrame.Size = UDim2.new(0, 320, 0, 60)
modelListFrame.Position = UDim2.new(0, 10, 0, 140)
modelListFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
modelListFrame.BorderSizePixel = 0
modelListFrame.Visible = false
modelListFrame.Parent = modelFrame

local extraModelBtn = createButton(modelListFrame, 0, 0, 320, 28, EXTRA_AI_MODEL)
extraModelBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 90)
local secondaryModelBtn = createButton(modelListFrame, 0, 30, 320, 28, SECONDARY_AI_MODEL)
secondaryModelBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 90)

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
secondaryModelBtn.MouseButton1Click:Connect(function()
    modelNameBox.Text = SECONDARY_AI_MODEL
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

local function extractGeneratedCode(replyContent)
    local candidates = {}
    local function addCandidate(value)
        value = tostring(value or "")
        value = string.gsub(value, "^%s+", "")
        value = string.gsub(value, "%s+$", "")
        if value ~= "" then table.insert(candidates, value) end
    end
    for block in string.gmatch(replyContent, "```[%w_%-]*%s*(.-)```") do
        addCandidate(block)
    end
    addCandidate(replyContent)
    local best = ""
    local bestScore = -1
    for _, candidate in ipairs(candidates) do
        local score = 0
        if string.find(candidate, "local Players", 1, true) then score = score + 100 end
        if string.find(candidate, "REZA_DiagnosticUI", 1, true) then score = score + 80 end
        if string.find(candidate, "OpenButton", 1, true) then score = score + 50 end
        if string.find(candidate, "local function appendStatus(text)", 1, true) then score = score + 50 end
        if string.find(candidate, "local packedArgs = table.pack(...)", 1, true) then score = score + 40 end
        if string.find(candidate, "sampleArgs = packedArgs", 1, true) then score = score + 40 end
        if string.find(candidate, "RunService.RenderStepped:Connect(function()", 1, true) then score = score + 40 end
        if string.match(candidate, "main%(%)[%s]*$") or string.match(candidate, "end%)%s*$") then score = score + 40 end
        score = score + math.min(20, math.floor(#candidate / 2000))
        if score > bestScore then
            bestScore = score
            best = candidate
        end
    end
    return best
end

local GENERATED_SCRIPT_SHAPE = "auto"

local function validateGeneratedScript(scriptText)
    local requiredLiterals = {
        "REZA_DiagnosticUI", "وحدة تشخيص الريموتات", "إغلاق",
        "بدء المراقبة", "إيقاف المراقبة", "عرض الملخص", "نسخ السجل", "تنظيف السجل",
        "UIStroke", "UICorner", "ScrollingFrame"
    }
    for _, marker in ipairs(requiredLiterals) do
        if not string.find(scriptText, marker, 1, true) then
            return false, "missing " .. marker
        end
    end
    local requiredAlternatives = {
        {"OpenButton", "openButton"},
        {"MainPanel", "mainPanel"}
    }
    for _, alternatives in ipairs(requiredAlternatives) do
        local found = false
        for _, marker in ipairs(alternatives) do
            if string.find(scriptText, marker, 1, true) then found = true break end
        end
        if not found then return false, "missing UI marker " .. alternatives[1] end
    end
    local requiredPatterns = {
        {"function%s+appendStatus%s*%(", "status append function"},
        {"table%.pack%s*%(%s*%.%.%.%s*%)", "table.pack"},
        {"packedArgs%s*%[%s*[^]]+%s*%]", "packedArgs indexed access"},
        {"sampleArgs%s*=%s*packedArgs", "sampleArgs storage"},
        {"targets%s*=%s*{", "targets table"},
        {"function%s+cleanup%s*%(", "cleanup function"}
    }
    for _, item in ipairs(requiredPatterns) do
        if not string.match(scriptText, item[1]) then return false, "missing " .. item[2] end
    end
    local forbiddenPatterns = {
        {"%-%-!strict", "--!strict"}, {"%+=", "+="}, {"%.%.=", "..="},
        {"%*%=", "*="}, {"/=", "/="},
        {"hookmetamethod%s*%(", "hookmetamethod("}, {"getrawmetatable%s*%(", "getrawmetatable("},
        {"__namecall", "__namecall"}, {"FireServer%s*%(", "FireServer("}, {"FireClient%s*%(", "FireClient("}, {"FireAllClients%s*%(", "FireAllClients("}, {"InvokeServer%s*%(", "InvokeServer("}, {"InvokeClient%s*%(", "InvokeClient("}, {"GetDescendants%s*%(", "GetDescendants("}
    }
    for _, item in ipairs(forbiddenPatterns) do
        if string.match(scriptText, item[1]) then return false, "forbidden " .. item[2] end
    end
    local finalText = string.gsub(scriptText, "%s+$", "")
    local hasLegacyMain = string.match(scriptText, "local%s+function%s+main%s*%(") ~= nil and string.match(finalText, "main%(%)[%s]*$") ~= nil
    local modernBody = string.match(finalText, "RunService%s*%.%s*RenderStepped%s*:%s*Connect%s*%(%s*function%s*%((.*)end%)%s*$")
    local hasModernCallback = modernBody ~= nil
    local emptyModernCallback = modernBody ~= nil and string.gsub(modernBody, "%s", "") == ""
    if GENERATED_SCRIPT_SHAPE == "main" then
        if not hasLegacyMain then
            return false, "legacy mode requires main() as the final executable line"
        end
        if not string.match(scriptText, "task%.delay%s*%(%s*10%s*,%s*printSummary%s*%)") then
            return false, "legacy mode missing task.delay(10, printSummary)"
        end
    elseif GENERATED_SCRIPT_SHAPE == "end" then
        if not hasModernCallback then
            return false, "modern mode requires the final end) callback"
        end
        if emptyModernCallback then
            return false, "modern mode RenderStepped callback is empty"
        end
    elseif hasLegacyMain then
        if not string.match(scriptText, "task%.delay%s*%(%s*10%s*,%s*printSummary%s*%)") then
            return false, "main() output missing task.delay(10, printSummary)"
        end
    elseif hasModernCallback then
        if emptyModernCallback then
            return false, "end) output RenderStepped callback is empty"
        end
    else
        return false, "output must end with main() or end) callback"
    end
    return true, ""
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
            content = [[You are a code compiler, not an explainer. Silently apply the contract below and immediately output one complete Roblox LocalScript. Do not plan, reason aloud, repeat requirements, or output prose. The first characters of the response must be ```lua and the response must contain exactly one ```lua``` code block and nothing outside it. If a detail is difficult, choose the simplest complete working implementation instead of explaining.

Generate a standalone plain Luau LocalScript for an authorized client-side inbound diagnostic monitor with an Arabic UI while preserving the supplied source structure. Use ASCII identifiers and metadata values, with Arabic only in visible UI Text. No --!strict, type annotations, generic types, typed methods, continue, compound assignments (+=, -=, ..=, *=, /=), table.clear, table.create, table.clone, require, top-level return, executor-only APIs, server-only APIs, hooks, placeholders, TODOs, pseudocode, omitted sections, comments, explanations, or reasoning text. Every block must compile with matching end. The source begins with local Players = game:GetService("Players") and its top-level RenderStepped callback must remain the final wrapper; do not invent main() or append code after the callback. The final characters must be end).

UI contract: build a ScreenGui named REZA_DiagnosticUI with ResetOnSpawn = false. Create a visible rounded TextButton named OpenButton with UICorner and UIStroke; it toggles a rounded panel named MainPanel. MainPanel has UIStroke and UICorner, title Text exactly "وحدة تشخيص الريموتات", and close TextButton Text exactly "إغلاق". Add five real buttons with MouseButton1Click:Connect handlers and these exact Arabic Text values: "بدء المراقبة", "إيقاف المراقبة", "عرض الملخص", "نسخ السجل", "تنظيف السجل". Create a ScrollingFrame log with UIListLayout and local function appendStatus(text) that appends TextLabels and updates CanvasSize; never put a full summary in status.Text. Initialize the UI and monitoring inside the existing source flow; do not require a main() function and do not append a standalone main() call. Preserve the original top-level callback closure as the final `end)`.

Monitor contract: declare Players, ReplicatedStorage, LocalPlayer, records = {}, recordByKey = {}, connections = {}, monitoring = false, statusLabel, logScroll, screenGui. Declare a literal `local targets = {` table containing the fixed inbound RemoteEvent target records before startMonitoring; never reference an undeclared targets variable. Implement resolvePath(path) using ReplicatedStorage, skipping only a first segment equal to "ReplicatedStorage", traversing one FindFirstChild segment at a time inside pcall, and returning nil on error. Implement serializeValue(value, seen, depth) with depth limit for nil, string, number, boolean, table/circular table, Instance/Player, Vector3, Vector2, CFrame, Color3, EnumItem, destroyed objects, and unknown values; check typeof before properties and pcall risky Instance reads.

Use getArgTypes(packedArgs) with exactly a numeric loop for i = 1, packedArgs.n do and packedArgs[i]. In each OnClientEvent callback use local packedArgs = table.pack(...). Create one record per meta.Path .. "|" .. meta.Method and insert into records only on first creation; repeats only increment occurrences. Store sampleArgs = packedArgs exactly, preserving sampleArgs.n and sampleArgs[i]. Each record has remoteName, fullPath, class, method, direction = "Incoming", sender = "Server", timestamp, occurrences, argTypes, sampleArgs.

Implement logInbound(meta, remoteInstance, packedArgs), connectTarget(meta), startMonitoring(), stopMonitoring(), printSummary(), cleanup(), clearRecords(), and copyLog(). Keep metadata separate from remoteInstance; never assign custom Instance fields. Protect path traversal, IsA, Connect, and every Disconnect with separate pcall calls. Key connections by meta.Path .. "|" .. meta.Method and never duplicate listeners. Use only a fixed target list from the supplied compact summary and only connect RemoteEvent.OnClientEvent. Do not scan GetDescendants. Do not use hookmetamethod, getrawmetatable, __namecall, FireServer, InvokeServer, FireClient, FireAllClients, or InvokeClient. copyLog must look up optional setclipboard inside pcall and show an Arabic status when unavailable.

printSummary must append readable lines to the ScrollingFrame, including timestamp, sender, fullPath, class, method, occurrences, argTypes, and serialized sampleArgs values by looping sampleArgs[i] from 1 to sampleArgs.n. cleanup must stop monitoring, disconnect safely, destroy only this script's ScreenGui, and reset state by assignment. Before emitting, silently verify syntax, all required Arabic labels, packedArgs indexing, pcall boundaries, fixed inbound targets, the original RenderStepped:Connect(function() wrapper, and that the final characters are end). Output code now; output nothing else.]]
        })
    end

    local requestMessages = {}
    if type(chatHistory[1]) == "table" and chatHistory[1].role == "system" then
        table.insert(requestMessages, chatHistory[1])
    end
    table.insert(requestMessages, {role = "user", content = tostring(userPromptText or "")})

    task.spawn(function()
        local selectedModel = normalizeModelName(modelNameBox.Text)
        local payloadData = {
            model = selectedModel,
            messages = requestMessages,
            max_tokens = 8000,
            temperature = 0,
            reasoning = {effort = "none", exclude = true},
            stream = false
        }

        local requestDeadline = os.clock() + AI_REQUEST_TIMEOUT_SECONDS
        local response, requestError = Safe.http_request({
            __Deadline = requestDeadline,
            Timeout = AI_REQUEST_TIMEOUT_SECONDS,
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
            local requestMessage = tostring(requestError or "HTTP API unavailable")
            if string.find(string.lower(requestMessage), "timeout", 1, true) then
                appendAiOutput("انتهت مهلة طلب OpenRouter بعد 4 دقائق.", Color3.fromRGB(255, 150, 70))
            else
                appendAiOutput(requestMessage, Color3.fromRGB(255, 70, 70))
            end
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
                    local scriptMatch = extractGeneratedCode(replyContent)
                    local choice = decoded.choices[1]
                    local finishReason = string.lower(tostring(choice.finish_reason or ""))
                    local nativeFinishReason = string.lower(tostring(choice.native_finish_reason or ""))
                    local outputWasTruncated = string.find(finishReason, "length", 1, true) ~= nil or string.find(nativeFinishReason, "length", 1, true) ~= nil
                    if outputWasTruncated then
                        latestGeneratedScript = ""
                        appendAiOutput("رفض المخرج: انتهى حد التوكنات قبل اكتمال السكربت. لم يتم تشغيل الفاحص على مخرج مبتور.", Color3.fromRGB(255, 120, 70))
                    else
                        local valid, validationError = validateGeneratedScript(scriptMatch)
                        if not valid then
                            latestGeneratedScript = ""
                            appendAiOutput("رفض الفاحص مخرج الذكاء الاصطناعي: " .. validationError, Color3.fromRGB(255, 180, 70))
                        else
                            chatHistory = {chatHistory[1], {role = "assistant", content = replyContent}}
                            latestGeneratedScript = scriptMatch
                            appendAiOutput("تم استلام سكربت اجتاز الفحص البنيوي.", Color3.fromRGB(100, 255, 100))
                            for line in string.gmatch(scriptMatch, "[^\r\n]+") do appendAiOutput(line, Color3.fromRGB(170, 220, 255)) end
                        end
                    end
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

for _, obj in ipairs(game:GetDescendants()) do
    setupRemoteListener(obj)
end
local rapidEnabled = false
local hitboxEnabled, deadlyEnabled, noclipEnabled, invisibleEnabled, ghostEnabled, godModeEnabled, espEnabled = false, false, false, false, false, false, false
local hitboxSize = 20

if Safe.canHook then
    pcall(function()
        local mt = Safe.getrawmetatable(game)
        if mt then
            local oldNamecall = mt.__namecall
            v12HookMt = mt
            v12OldNamecall = oldNamecall
            local writable = Safe.setreadonly(mt, false)
            if writable and type(oldNamecall) == "function" then
                mt.__namecall = Safe.newcclosure(function(self, ...)
                    local args = {...}
                    local method = Safe.getnamecallmethod()
                    if consoleActive and spyRecording and not Safe.checkcaller() and (method == "FireServer" or method == "InvokeServer") then
                        local sName, rName = pcall(function() return self.Name end)
                        local sClass, rClass = pcall(function() return self.ClassName end)
                        local sPath, rPath = pcall(function() return self:GetFullName() end)
                        local remoteName = sName and rName or "Unknown"
                        local remoteClass = sClass and rClass or "Unknown"
                        local remotePath = sPath and rPath or "Unknown"
                        local safeArgs = {}
                        for index, value in ipairs(args) do safeArgs[index] = value end
                        task.defer(function()
                            if not consoleActive or not spyRecording then return end
                            if #logQueue >= INSPECTOR_SETTINGS.MaxLogs * 2 then table.remove(logQueue, 1) end
                            logCounter = logCounter + 1
                            local okRecord, recordError = pcall(function()
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
                            if not okRecord and Safe and Safe.reportError then Safe.reportError("RemoteMonitor", recordError) end
                        end)
                    end
                    -- Monitoring is observational; preserve the original payload and return path.
                    return oldNamecall(self, ...)
                end)
                v12HookInstalled = true
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

-- RE V13 staged adapter: appended after the V11 working recorder script.
local RE_DESIGN = {
    Colors = {
        Background = Color3.fromRGB(15, 18, 24),
        Glass = Color3.fromRGB(24, 30, 39),
        GlassDeep = Color3.fromRGB(20, 25, 33),
        Card = Color3.fromRGB(30, 37, 48),
        MicroGlass = Color3.fromRGB(37, 45, 57),
        Floating = Color3.fromRGB(34, 42, 53),
        Primary = Color3.fromRGB(55, 112, 164),
        Secondary = Color3.fromRGB(72, 84, 101),
        Accent = Color3.fromRGB(91, 145, 184),
        Border = Color3.fromRGB(123, 140, 158),
        Text = Color3.fromRGB(246, 248, 251),
        Muted = Color3.fromRGB(184, 193, 203),
        Success = Color3.fromRGB(60, 145, 103),
        Warning = Color3.fromRGB(190, 145, 65),
        Danger = Color3.fromRGB(184, 76, 84),
        Info = Color3.fromRGB(88, 137, 181)
    },
    Motion = {Fast = 0.12, Normal = 0.18, Smooth = 0.26, Complex = 0.35},
    Spacing = {XS = 4, S = 8, M = 12, L = 16, XL = 24},
    TouchMinimum = 36,
    Icon = "ℝ𝔼",
    Signal = "⌁",
    V13Button = nil
}

local v13BootStage = "V11 recorder baseline loaded"
local v13BootDiagnostics = {}
local function v13BootDiagnostic(stage, moduleName, functionName, status, errorText, recovery)
    local item = {
        Stage = tostring(stage or v13BootStage),
        Module = tostring(moduleName or "Core"),
        Function = tostring(functionName or "unknown"),
        Status = tostring(status or "INFO"),
        Error = tostring(errorText or ""),
        Recovery = tostring(recovery or ""),
        Timestamp = os.time()
    }
    table.insert(v13BootDiagnostics, item)
    if #v13BootDiagnostics > 80 then table.remove(v13BootDiagnostics, 1) end
    pcall(function()
        print(string.format("RE ULTIMATE CONSOLE v13 | BOOT | Stage: %s | Module: %s | Function: %s | Status: %s | Error: %s | Recovery: %s", item.Stage, item.Module, item.Function, item.Status, item.Error, item.Recovery))
    end)
    return item
end
local function v13SetBootStage(stage)
    v13BootStage = tostring(stage or "Unknown")
    return v13BootStage
end
Safe.getBootDiagnostics = function() return v13BootDiagnostics end
local function rememberV12Connection(connection)
    if connection then table.insert(v12OwnedConnections, connection) end
    return connection
end
local v13UiReady = guiParentSet == true
pcall(function()
    iconBtn.Text = "ℝ𝔼"
    iconBtn.TextColor3 = RE_DESIGN.Colors.Text
    iconBtn.TextStrokeTransparency = 1
    iconBtn.Font = Enum.Font.GothamBold
    iconBtn.TextSize = 17
    iconBtn.BackgroundColor3 = RE_DESIGN.Colors.Glass
    iconBtn.BackgroundTransparency = 0
    iconBtn.BorderSizePixel = 0
    iconBtn.ZIndex = 1000
    title.Text = "ℝ𝔼  |  وحدة التحكم"
    inspectorTitle.Text = "ℝ𝔼  |  مراقب الريموتات"
end)
local v13NoclipOriginal = {}
local v13NoclipWorldOriginal = {}
local function v13RestoreNoclip()
    for part, original in pairs(v13NoclipOriginal) do
        pcall(function()
            if part and part.Parent then part.CanCollide = original end
        end)
    end
    for part, original in pairs(v13NoclipWorldOriginal) do
        pcall(function()
            if part and part.Parent then part.CanCollide = original end
        end)
    end
    v13NoclipOriginal = {}
    v13NoclipWorldOriginal = {}
end
local function v13ApplyNoclipState()
    local character = LocalPlayer and LocalPlayer.Character
    if not noclipEnabled then
        v13RestoreNoclip()
        return
    end
    if not character then return end
    local ok, parts = pcall(function() return character:GetDescendants() end)
    if ok and type(parts) == "table" then
        for _, part in ipairs(parts) do
            pcall(function()
                if part and part:IsA("BasePart") then
                    if v13NoclipOriginal[part] == nil then v13NoclipOriginal[part] = part.CanCollide end
                    part.CanCollide = false
                end
            end)
        end
    end
    local humanoid = nil
    local hrp = nil
    pcall(function() humanoid = character:FindFirstChildOfClass("Humanoid") end)
    pcall(function() hrp = character:FindFirstChild("HumanoidRootPart") end)
    if not hrp or not humanoid or humanoid.Health <= 0 then return end
    local boundsOk, bounds = pcall(function() return Workspace:GetPartBoundsInBox(hrp.CFrame, hrp.Size) end)
    if not boundsOk or type(bounds) ~= "table" then return end
    for _, wall in ipairs(bounds) do
        pcall(function()
            if wall and wall:IsA("BasePart") and wall.CanCollide and wall.Anchored and not wall:IsDescendantOf(character) then
                local wallTop = wall.Position.Y + wall.Size.Y / 2
                local hrpBottom = hrp.Position.Y - hrp.Size.Y / 2
                if hrpBottom < wallTop - 0.5 then
                    if v13NoclipWorldOriginal[wall] == nil then v13NoclipWorldOriginal[wall] = wall.CanCollide end
                    wall.CanCollide = false
                end
            end
        end)
    end
end
local v13NoclipConnection = nil

-- First-V13 recorder bridge: auto-enable capture, attach the V9 fixed targets,
-- and own the dynamic DescendantAdded connection for cleanup/retry safety.
local v13FixedRecorderTargets = {
    "ReplicatedStorage.Events.RemoteEvents.CharacterMuzzleFlash",
    "ReplicatedStorage.Events.RemoteEvents.ReplicateFakeBullet",
    "ReplicatedStorage.Events.RemoteEvents.ReplicateSlidingEffect",
    "ReplicatedStorage.Events.RemoteEvents.ReplicateImpactEffect",
    "ReplicatedStorage.Modules.DataService.Networker._remotes.DataService.RemoteEvent",
    "ReplicatedStorage.Events.RemoteEvents.KillfeedEntry",
    "ReplicatedStorage.Events.RemoteEvents.ReplicateJumpPad",
    "ReplicatedStorage.Events.RemoteEvents.ShowDeathScreen",
    "ReplicatedStorage.Modules.RagdollService.RagdollRemote"
}
local function v13ResolveRecorderPath(path)
    local current = game
    for segment in string.gmatch(tostring(path or ""), "[^%.]+") do
        if segment ~= "game" and segment ~= "DataModel" then
            local ok, child = pcall(function() return current and current:FindFirstChild(segment) end)
            if not ok or not child then return nil end
            current = child
        end
    end
    return current
end
local function v13StartLegacyMonitor()
    if not consoleActive or not guiParentSet then
        v13BootDiagnostic(v13BootStage, "RemoteMonitor", "v13StartLegacyMonitor", "SKIPPED", "GUI host is not ready", "retry on next attachment")
        return false
    end
    for _, path in ipairs(v13FixedRecorderTargets) do
        local object = v13ResolveRecorderPath(path)
        if object then pcall(function() setupRemoteListener(object) end) end
    end
    if not v12DescendantConnection then
        local ok, connection = pcall(function()
            return game.DescendantAdded:Connect(function(obj)
                if consoleActive then pcall(function() setupRemoteListener(obj) end) end
            end)
        end)
        if ok and connection then v12DescendantConnection = rememberV12Connection(connection) end
    end
    v13BootDiagnostic(v13BootStage, "RemoteMonitor", "v13StartLegacyMonitor", "PASS", "", "V9 fixed targets plus V10 dynamic listeners active")
    return true
end
pcall(function()
    spyRecording = true
    toggleSpyBtn.Text = "تسجيل: شغال"
    toggleSpyBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
end)
task.defer(function() pcall(v13StartLegacyMonitor) end)

pcall(function() v13BootDiagnostic(v13BootStage, "Stage0", "V11 recorder", "PASS", "", "append V13 adapter") end)

local function reUiFailure(functionName, errorText, recovery)
    pcall(function()
        v13BootDiagnostic(v13BootStage, "UI", functionName, "FAILED", errorText, recovery or "keep object functional")
        Safe.reportError("UI." .. tostring(functionName), errorText)
    end)
end

local function reTween(object, properties, duration)
    if not object or not consoleActive then return end
    local ok, err = pcall(function()
        TweenService:Create(object, TweenInfo.new(duration or RE_DESIGN.Motion.Normal, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties):Play()
    end)
    if not ok then reUiFailure("reTween", err, "skip motion") end
end

local function reSurface(object, material, accent)
    if not object then return end
    local ok, err = pcall(function()
        local colors = RE_DESIGN.Colors
        local isScroll = false
        pcall(function() isScroll = object:IsA("ScrollingFrame") end)
        object.BackgroundColor3 = material == "Primary" and colors.Glass or material == "Secondary" and colors.GlassDeep or material == "Floating" and colors.Floating or material == "Accent" and colors.MicroGlass or colors.Card
        object.BackgroundTransparency = isScroll and 1 or 0
        object.BorderSizePixel = 0
        local corner = object:FindFirstChild("REGlassCorner")
        if not corner then
            corner = Instance.new("UICorner")
            corner.Name = "REGlassCorner"
            corner.CornerRadius = UDim.new(0, material == "Primary" and 16 or 10)
            corner.Parent = object
        end
        local stroke = object:FindFirstChild("REGlassStroke")
        if not stroke then
            stroke = Instance.new("UIStroke")
            stroke.Name = "REGlassStroke"
            stroke.Thickness = 1
            stroke.Parent = object
        end
        stroke.Color = accent or colors.Border
        stroke.Transparency = 0.18
        local gradient = object:FindFirstChild("REGlassGradient")
        if gradient then gradient.Enabled = false end
        local sheen = object:FindFirstChild("REGlassSheen")
        if sheen then sheen.Visible = false end
        local children = object:GetChildren()
        for _, child in ipairs(children) do
            if child:IsA("UIGradient") then
                child:Destroy()
            elseif child.Name == "REGlassSheen" then
                child.Visible = false
            end
        end
    end)
    if not ok then reUiFailure("reSurface", err, "fallback to plain surface") end
end

local function reStyleButton(button, role)
    if not button then return end
    local ok, err = pcall(function()
        local colors = RE_DESIGN.Colors
        button.AutoButtonColor = false
        button.BackgroundColor3 = role == "Primary" and colors.Primary or role == "Danger" and colors.Danger or role == "Success" and colors.Success or role == "Accent" and colors.Accent or colors.MicroGlass
        button.BackgroundTransparency = 0
        button.BorderSizePixel = 0
        button.TextColor3 = colors.Text
        button.Font = Enum.Font.GothamMedium
        button.TextSize = math.max(11, button.TextSize)
        reSurface(button, role == "Primary" and "Accent" or "Micro", role == "Danger" and colors.Danger or role == "Success" and colors.Success or colors.Border)
        local scale = button:FindFirstChild("REButtonScale")
        if not scale then
            scale = Instance.new("UIScale")
            scale.Name = "REButtonScale"
            scale.Scale = 1
            scale.Parent = button
            rememberV12Connection(button.MouseEnter:Connect(function() reTween(scale, {Scale = 1.025}, RE_DESIGN.Motion.Fast) end))
            rememberV12Connection(button.MouseLeave:Connect(function() reTween(scale, {Scale = 1}, RE_DESIGN.Motion.Normal) end))
            rememberV12Connection(button.MouseButton1Down:Connect(function() reTween(scale, {Scale = 0.965}, RE_DESIGN.Motion.Fast) end))
            rememberV12Connection(button.MouseButton1Up:Connect(function() reTween(scale, {Scale = 1.01}, RE_DESIGN.Motion.Fast) end))
        end
    end)
    if not ok then reUiFailure("reStyleButton", err, "keep native button behavior") end
end

local function reStyleText(object, size, color, font)
    if not object then return end
    local ok, err = pcall(function()
        object.TextColor3 = color or RE_DESIGN.Colors.Text
        object.TextStrokeTransparency = 1
        object.Font = font or Enum.Font.Gotham
        object.TextSize = size or object.TextSize
    end)
    if not ok then reUiFailure("reStyleText", err, "keep native text") end
end

local function reApplyResponsiveLayout()
    if not Camera or not inspectorFrame then return end
    local ok, err = pcall(function()
        local viewport = Camera.ViewportSize
        local width = math.max(292, math.min(620, viewport.X - 18))
        local height = math.max(280, math.min(520, viewport.Y - 34))
        local compact = width < 480
        inspectorFrame.Size = UDim2.new(0, width, 0, height)
        inspectorFrame.Position = UDim2.new(0.5, -width * 0.5, 0.5, -height * 0.5)
        inspectorScale.Scale = compact and 0.84 or 0.92
        if menuFrame and menuScale then
            local menuWidth = math.max(280, math.min(340, viewport.X - 28))
            menuFrame.Size = UDim2.new(0, menuWidth, 0, 285)
            menuFrame.Position = UDim2.new(0, math.max(12, math.min(65, viewport.X - menuWidth - 12)), 0, 15)
            menuScale.Scale = viewport.X < 420 and 0.82 or 0.92
        end
        if compact then
            leftScroll.Size = UDim2.new(1, -10, 0, 108)
            leftScroll.Position = UDim2.new(0, 5, 0, 65)
            rightScroll.Size = UDim2.new(1, -10, 1, -188)
            rightScroll.Position = UDim2.new(0, 5, 0, 183)
            aiFrame.Size = UDim2.new(1, -10, 1, -70)
            aiFrame.Position = UDim2.new(0, 5, 0, 65)
            modelFrame.Size = UDim2.new(0, math.max(270, width - 24), 0, 220)
            modelFrame.Position = UDim2.new(0.5, -math.max(270, width - 24) * 0.5, 0.5, -110)
        else
            leftScroll.Size = UDim2.new(0, 250, 1, -70)
            leftScroll.Position = UDim2.new(0, 5, 0, 65)
            rightScroll.Size = UDim2.new(1, -265, 1, -70)
            rightScroll.Position = UDim2.new(0, 260, 0, 65)
            aiFrame.Size = UDim2.new(1, -265, 1, -70)
            aiFrame.Position = UDim2.new(0, 260, 0, 65)
            modelFrame.Size = UDim2.new(0, 340, 0, 220)
            modelFrame.Position = UDim2.new(0.5, -170, 0.5, -110)
        end
    end)
    if not ok then reUiFailure("reApplyResponsiveLayout", err, "keep previous layout") end
end

local function reBuildIcon(parent, size, active)
    if not parent then return nil end
    local holder
    local ok, err = pcall(function()
        holder = Instance.new("Frame")
        holder.Size = UDim2.new(0, size, 0, size)
        holder.BackgroundTransparency = 1
        holder.Active = false
        holder.Selectable = false
        holder.Parent = parent
        local core = Instance.new("Frame")
        core.AnchorPoint = Vector2.new(0.5, 0.5)
        core.Position = UDim2.new(0.5, 0, 0.5, 0)
        core.Size = UDim2.new(0, math.floor(size * 0.28), 0, math.floor(size * 0.28))
        core.Rotation = 45
        core.BorderSizePixel = 0
        core.BackgroundColor3 = active and RE_DESIGN.Colors.Accent or RE_DESIGN.Colors.Primary
        core.Parent = holder
        local coreCorner = Instance.new("UICorner")
        coreCorner.CornerRadius = UDim.new(0, 3)
        coreCorner.Parent = core
        for index = 1, 2 do
            local orbit = Instance.new("Frame")
            orbit.AnchorPoint = Vector2.new(0.5, 0.5)
            orbit.Position = UDim2.new(0.5, 0, 0.5, 0)
            orbit.Size = UDim2.new(0.78, 0, 0.48, 0)
            orbit.Rotation = index == 1 and 28 or -28
            orbit.BackgroundTransparency = 1
            orbit.BorderSizePixel = 0
            orbit.Active = false
            orbit.Selectable = false
            orbit.Parent = holder
            local orbitStroke = Instance.new("UIStroke")
            orbitStroke.Color = index == 1 and RE_DESIGN.Colors.Primary or RE_DESIGN.Colors.Secondary
            orbitStroke.Thickness = math.max(1, math.floor(size / 12))
            orbitStroke.Transparency = 0.04
            orbitStroke.Parent = orbit
            local orbitCorner = Instance.new("UICorner")
            orbitCorner.CornerRadius = UDim.new(1, 0)
            orbitCorner.Parent = orbit
        end
    end)
    if not ok then reUiFailure("reBuildIcon", err, "use text icon") end
    return holder
end

-- V13 visual pass: one opaque owner per window; scroll regions are transparent content layers.
task.defer(function()
    pcall(function()
        reSurface(iconBtn, "Accent", RE_DESIGN.Colors.Accent)
        iconBtn.Text = "ℝ𝔼"
        iconBtn.TextStrokeTransparency = 1
        iconBtn.BackgroundTransparency = 0
        iconBtn.BackgroundColor3 = RE_DESIGN.Colors.Glass
        reSurface(menuFrame, "Primary", RE_DESIGN.Colors.Secondary)
        reSurface(inspectorFrame, "Primary", RE_DESIGN.Colors.Primary)
        reSurface(aiFrame, "Secondary", RE_DESIGN.Colors.Secondary)
        reSurface(modelFrame, "Floating", RE_DESIGN.Colors.Secondary)
        reSurface(toggleInspectorBtn, "Primary")
        reSurface(aiTabBtn, "Accent")
        reSurface(modelTabBtn, "Secondary")
        if title then title.BackgroundTransparency = 1 end
        if inspectorTitle then inspectorTitle.BackgroundTransparency = 1 end
        if modelTitle then modelTitle.BackgroundTransparency = 1 end
        if toolbarFrame then toolbarFrame.BackgroundTransparency = 1 end
        if leftScroll then leftScroll.BackgroundTransparency = 1 end
        if rightScroll then rightScroll.BackgroundTransparency = 1 end
        if aiScroll then aiScroll.BackgroundTransparency = 1 end
        reApplyResponsiveLayout()
        pcall(function() gui.ZIndexBehavior = Enum.ZIndexBehavior.Global end)
        pcall(function() title.TextStrokeTransparency = 1; inspectorTitle.TextStrokeTransparency = 1; modelTitle.TextStrokeTransparency = 1 end)
        local function v13LayerWindow(root, zIndex, opaque)
            if not root then return end
            root.ZIndex = zIndex
            if opaque then root.BackgroundTransparency = 0 end
            local ok, descendants = pcall(function() return root:GetDescendants() end)
            if ok and type(descendants) == "table" then
                for _, child in ipairs(descendants) do
                    pcall(function()
                        if child:IsA("GuiObject") then
                            child.ZIndex = zIndex + 1
                            if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                                child.TextStrokeTransparency = 1
                            end
                        elseif child:IsA("UIGradient") then
                            child:Destroy()
                        elseif child.Name == "REGlassSheen" then
                            child:Destroy()
                        end
                    end)
                end
            end
        end
        -- Only these roots own an opaque background. The recorder scrolls are content only.
        v13LayerWindow(menuFrame, 100, true)
        v13LayerWindow(inspectorFrame, 300, true)
        v13LayerWindow(leftScroll, 320, false)
        v13LayerWindow(rightScroll, 320, false)
        v13LayerWindow(aiFrame, 340, true)
        v13LayerWindow(aiScroll, 342, false)
        v13LayerWindow(modelFrame, 500, true)
        v13LayerWindow(iconBtn, 1000, true)
        if menuFrame then menuFrame.BackgroundColor3 = RE_DESIGN.Colors.Glass end
        if inspectorFrame then inspectorFrame.BackgroundColor3 = RE_DESIGN.Colors.GlassDeep; inspectorFrame.BackgroundTransparency = 0 end
        if aiFrame then aiFrame.BackgroundColor3 = RE_DESIGN.Colors.Card; aiFrame.BackgroundTransparency = 0 end
        if modelFrame then modelFrame.BackgroundColor3 = RE_DESIGN.Colors.Floating; modelFrame.BackgroundTransparency = 0 end
        -- V11 owns legacy click handlers; this pass owns appearance and layer order only.
    end)
end)

-- Noclip controller: Stepped runs with the physics loop and survives respawns.
task.defer(function()
    pcall(function()
        v13NoclipConnection = rememberV12Connection(RunService.Stepped:Connect(function()
            pcall(v13ApplyNoclipState)
        end))
    end)
end)

task.defer(function()
local V13 = {}
local v13Generation = 0
local v13ConnectionRegistry = {}
local v13ModuleState = {}
local v13Timeline = {}
local v13Findings = {}
local v13Evidence = {}
local v13RemoteCatalog = {}
local v13ActivitySummary = {}
local v13ServiceSnapshot = {}
local v13ApiObservation = {}
local v13Queue = {}
local v13RateState = {Started = os.clock(), Count = 0}
local v13ActiveTab = "لوحة التحكم"
local v13Panel = nil
local v13Content = nil
local v13SafeMode = true
local v13Destroyed = false
local v13Initialized = false
local v13Running = false
local v13SetModule
local v13TimelineAdd
local V13_LIMITS = {
    MaxQueue = 120,
    MaxTimeline = 180,
    MaxFindings = 80,
    MaxEvidence = 100,
    MaxRemoteCatalog = 300,
    MaxUiRows = 70,
    DiscoveryBatch = 40,
    DiscoveryMaxNodes = 1200,
    DiscoveryMaxDepth = 7,
    MaxPathLength = 260,
    MaxStringLength = 180,
    MaxTestItems = 40,
    RateWindow = 2,
    RateLimit = 20
}

V13.SafeMode = true
V13.Limits = V13_LIMITS
V13.Modules = v13ModuleState
V13.Findings = v13Findings
V13.Timeline = v13Timeline
V13.Evidence = v13Evidence
V13.RemoteCatalog = v13RemoteCatalog
V13.ApiObservation = v13ApiObservation
V13.BootDiagnostics = v13BootDiagnostics

local function v13Text(value, limit)
    local result = tostring(value or "")
    local maxLength = limit or V13_LIMITS.MaxStringLength
    if #result > maxLength then return string.sub(result, 1, maxLength) .. "..." end
    return result
end

local function v13Now()
    if type(formatTime) == "function" then
        local ok, value = pcall(formatTime)
        if ok then return value end
    end
    return os.date("%H:%M:%S")
end

local function v13OwnConnection(connection)
    if connection then table.insert(v13ConnectionRegistry, connection) end
    return connection
end

local function v13Disconnect(connection)
    if connection then pcall(function() connection:Disconnect() end) end
end

local function v13BoundedInsert(list, value, limit)
    table.insert(list, value)
    while #list > limit do table.remove(list, 1) end
end

local function v13SafeCall(domain, callback, ...)
    local args = {...}
    if type(callback) ~= "function" then
        local missing = "callback unavailable"
        Safe.reportError(domain, missing)
        if v13SetModule then v13SetModule(string.gsub(tostring(domain), "^V13%.", ""), false, "FAILED: " .. missing) end
        v13BootDiagnostic(v13BootStage, domain, "startup", "FAILED", missing, "module skipped; Console continues")
        return false, nil, missing
    end
    local ok, a, b, c = pcall(function() return callback(unpack(args)) end)
    if ok then return true, a, b, c end
    Safe.reportError(domain, a)
    if v13SetModule then v13SetModule(string.gsub(tostring(domain), "^V13%.", ""), false, "FAILED: " .. tostring(a)) end
    v13BootDiagnostic(v13BootStage, domain, "startup", "FAILED", a, "module skipped; Console continues")
    return false, nil, tostring(a)
end

v13SetModule = function(name, running, detail)
    v13ModuleState[name] = {Running = running == true, Detail = tostring(detail or ""), Updated = v13Now()}
end

v13TimelineAdd = function(kind, message, data)
    local item = {
        ID = #v13Timeline + 1,
        Timestamp = v13Now(),
        Kind = v13Text(kind, 40),
        Message = v13Text(message, 240),
        Data = data
    }
    v13BoundedInsert(v13Timeline, item, V13_LIMITS.MaxTimeline)
    return item
end

local function v13EvidenceAdd(kind, source, value)
    local item = {
        ID = #v13Evidence + 1,
        Timestamp = v13Now(),
        Kind = v13Text(kind, 50),
        Source = v13Text(source, V13_LIMITS.MaxPathLength),
        Value = v13Text(value, 600)
    }
    v13BoundedInsert(v13Evidence, item, V13_LIMITS.MaxEvidence)
    return item
end

local function v13FindingAdd(code, severity, titleText, detail, evidenceId)
    local key = tostring(code) .. "|" .. tostring(titleText)
    for _, old in ipairs(v13Findings) do
        if old.Key == key then
            old.Count = (old.Count or 1) + 1
            old.Timestamp = v13Now()
            return old
        end
    end
    local item = {
        ID = #v13Findings + 1,
        Key = key,
        Code = v13Text(code, 50),
        Severity = v13Text(severity, 30),
        Title = v13Text(titleText, 160),
        Detail = v13Text(detail, 420),
        Evidence = evidenceId,
        Count = 1,
        Timestamp = v13Now(),
        Confirmed = false
    }
    v13BoundedInsert(v13Findings, item, V13_LIMITS.MaxFindings)
    v13TimelineAdd("Finding", item.Title, item.ID)
    return item
end

local function v13RateAllow(weight)
    local now = os.clock()
    if now - v13RateState.Started >= V13_LIMITS.RateWindow then
        v13RateState.Started = now
        v13RateState.Count = 0
    end
    local amount = tonumber(weight) or 1
    if v13RateState.Count + amount > V13_LIMITS.RateLimit then return false end
    v13RateState.Count = v13RateState.Count + amount
    return true
end

local function v13QueuePush(value)
    if not v13RateAllow(1) then return false end
    v13BoundedInsert(v13Queue, value, V13_LIMITS.MaxQueue)
    return true
end

local function v13GetChildren(parent)
    local ok, children = pcall(function() return parent:GetChildren() end)
    if ok and type(children) == "table" then return children end
    return {}
end

local function v13InstancePath(object)
    if not object then return "" end
    local ok, path = pcall(function() return object:GetFullName() end)
    if ok then return v13Text(path, V13_LIMITS.MaxPathLength) end
    return ""
end

local function v13Class(object)
    if not object then return "" end
    local ok, value = pcall(function() return object.ClassName end)
    return ok and tostring(value) or ""
end

local function v13Walk(root, callback, maxNodes, maxDepth)
    local visited = 0
    local function visit(object, depth)
        if not consoleActive or visited >= maxNodes or depth > maxDepth then return end
        visited = visited + 1
        local okCallback = pcall(callback, object)
        if not okCallback then Safe.reportError("V13.Discovery", "callback failed") end
        if visited >= maxNodes then return end
        local children = v13GetChildren(object)
        for _, child in ipairs(children) do
            if not consoleActive or visited >= maxNodes then break end
            visit(child, depth + 1)
        end
    end
    visit(root, 0)
    return visited
end

local function v13ResolvePath(path)
    local text = tostring(path or "")
    local current = game
    local first = true
    for segment in string.gmatch(text, "[^%.]+") do
        if first and (segment == "game" or segment == "DataModel") then
            first = false
        elseif segment == "ReplicatedStorage" and current == game then
            local ok, service = pcall(function() return game:GetService("ReplicatedStorage") end)
            if not ok then return nil end
            current = service
            first = false
        else
            first = false
            local ok, nextObject = pcall(function() return current and current:FindFirstChild(segment) end)
            if not ok or not nextObject then return nil end
            current = nextObject
        end
    end
    return current
end

V13.ResolvePath = v13ResolvePath

local function v13TypeShape(value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if depth > 3 then return "depth" end
    local valueType = typeof(value)
    if valueType == "table" then
        if seen[value] then return "table(circular)" end
        seen[value] = true
        local keys = {}
        for key in pairs(value) do table.insert(keys, tostring(key)) end
        table.sort(keys)
        local shown = {}
        for index = 1, math.min(#keys, 8) do table.insert(shown, keys[index]) end
        return "table{" .. table.concat(shown, ",") .. "}"
    end
    if valueType == "Instance" then return "Instance<" .. v13Class(value) .. ">" end
    return valueType
end

local function v13Indicator(text)
    local source = string.lower(tostring(text or ""))
    local groups = {
        {Code = "SQLI_INDICATOR", Name = "SQLi مؤشر", Patterns = {" union ", " select ", " or 1=1", " drop table", " information_schema"}},
        {Code = "XSS_INDICATOR", Name = "XSS مؤشر", Patterns = {"<script", "javascript:", "onerror=", "onload=", "<img"}},
        {Code = "TRAVERSAL_INDICATOR", Name = "Path Traversal مؤشر", Patterns = {"../", "..\\", "%2e%2e", "etc/passwd", "win.ini"}},
        {Code = "SSRF_INDICATOR", Name = "SSRF مؤشر", Patterns = {"169.254.169.254", "127.0.0.1", "localhost", "file://", "gopher://"}},
        {Code = "COMMAND_INDICATOR", Name = "Command Injection مؤشر", Patterns = {"cmd.exe", "powershell", "bash -c", ";whoami", "&& whoami", "| whoami"}}
    }
    local result = {}
    for _, group in ipairs(groups) do
        for _, pattern in ipairs(group.Patterns) do
            if string.find(source, pattern, 1, true) then
                table.insert(result, group)
                break
            end
        end
    end
    return result
end

local function v13AnalyzeInput(source, value)
    local text = tostring(value or "")
    if text == "" then return end
    local indicators = v13Indicator(text)
    if #text > 120 then
        local evidence = v13EvidenceAdd("Input", source, "long-string length=" .. tostring(#text))
        v13FindingAdd("INPUT_LONG", "low", "قيمة نصية طويلة", "تم رصد نص طويل ضمن بيانات ملاحظة؛ لا يمثل ذلك ثغرة مؤكدة.", evidence.ID)
    end
    for _, item in ipairs(indicators) do
        local evidence = v13EvidenceAdd(item.Name, source, text)
        v13FindingAdd(item.Code, "info", item.Name, "مؤشر نصي في بيانات ملتقطة فقط؛ لم يتم إرسال حمولة اختبار.", evidence.ID)
    end
end

local function v13AnalyzeValue(source, value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    if depth > 4 then return end
    local valueType = typeof(value)
    if valueType == "string" then
        v13AnalyzeInput(source, value)
    elseif valueType == "table" then
        if seen[value] then return end
        seen[value] = true
        local count = 0
        for key, child in pairs(value) do
            count = count + 1
            if count > 40 then break end
            v13AnalyzeInput(source, key)
            v13AnalyzeValue(source, child, depth + 1, seen)
        end
    end
end

V13.InputAnalyzer = {}
function V13.InputAnalyzer.start()
    v13SetModule("InputAnalyzer", true, "جاهز للتحليل السلبي")
end
function V13.InputAnalyzer.inspectLog(log)
    if type(log) ~= "table" then return nil end
    local source = tostring(log.Path or log.Name or "Unknown")
    v13AnalyzeValue(source, log.Args, 0, {})
    local shapes = {}
    for index, valueType in ipairs(log.ArgTypes or {}) do
        shapes[index] = tostring(index) .. ":" .. tostring(valueType)
    end
    return {Source = source, Shape = table.concat(shapes, ", "), Count = tonumber(log.ArgCount) or 0}
end

V13.RemoteDiscovery = {}
function V13.RemoteDiscovery.start()
    if v13ModuleState.RemoteDiscovery and v13ModuleState.RemoteDiscovery.Running then return end
    v13SetModule("RemoteDiscovery", true, "تشغيل اكتشاف محدود عند الطلب")
    v13TimelineAdd("Module", "بدأ Remote Discovery")
    v13Generation = v13Generation + 1
    local generation = v13Generation
    task.spawn(function()
        local localCatalog = {}
        local count = v13Walk(game, function(object)
            if not consoleActive or generation ~= v13Generation then return end
            local className = v13Class(object)
            if className == "RemoteEvent" or className == "RemoteFunction" or className == "UnreliableRemoteEvent" then
                local path = v13InstancePath(object)
                local item = {Name = v13Text(object.Name, 100), Class = className, Path = path, Timestamp = v13Now()}
                table.insert(localCatalog, item)
                v13RemoteCatalog[path] = item
                v13QueuePush({Kind = "Remote", Value = item})
            end
        end, V13_LIMITS.DiscoveryMaxNodes, V13_LIMITS.DiscoveryMaxDepth)
        v13RemoteCatalog.Count = math.min(#localCatalog, V13_LIMITS.MaxRemoteCatalog)
        if consoleActive and generation == v13Generation then
            v13SetModule("RemoteDiscovery", false, "اكتمل الاكتشاف: " .. tostring(#localCatalog) .. " ريموت")
            v13TimelineAdd("Discovery", "اكتمل اكتشاف الريموتات", count)
        end
    end)
end
function V13.RemoteDiscovery.stop()
    v13Generation = v13Generation + 1
    v13SetModule("RemoteDiscovery", false, "متوقف")
end

V13.RemoteActivity = {}
function V13.RemoteActivity.start()
    return V13.RemoteActivity.refresh()
end
function V13.RemoteActivity.refresh()
    local byPath = {}
    for _, log in ipairs(logsDatabase or {}) do
        local path = tostring(log.Path or log.Name or "Unknown")
        local item = byPath[path]
        if not item then
            item = {Path = path, Name = tostring(log.Name or "Unknown"), Count = 0, Methods = {}, Directions = {}, Last = log.Timestamp}
            byPath[path] = item
        end
        item.Count = item.Count + (tonumber(log.Count) or 1)
        item.Methods[tostring(log.Method or "unknown")] = true
        item.Directions[tostring(log.Direction or "unknown")] = true
        item.Last = log.Timestamp or item.Last
    end
    v13ActivitySummary = byPath
    V13.ActivitySummary = v13ActivitySummary
    v13SetModule("RemoteActivity", true, "تجميع محلي للسجل")
    v13TimelineAdd("Activity", "تم تحديث ملخص نشاط الريموتات", #logsDatabase)
    return byPath
end
function V13.RemoteActivity.stop()
    v13SetModule("RemoteActivity", false, "متوقف")
end

V13.ArgumentInspector = {}
function V13.ArgumentInspector.start()
    return V13.ArgumentInspector.refresh()
end
function V13.ArgumentInspector.refresh()
    local total = 0
    for _, log in ipairs(logsDatabase or {}) do
        if total >= V13_LIMITS.MaxTestItems then break end
        V13.InputAnalyzer.inspectLog(log)
        total = total + 1
    end
    v13SetModule("ArgumentInspector", true, "فحص حجمي محدود: " .. tostring(total) .. " سجل")
    v13TimelineAdd("Input", "تم تحديث فحص الوسائط", total)
    return total
end
function V13.ArgumentInspector.stop()
    v13SetModule("ArgumentInspector", false, "متوقف")
end

V13.ServerIntel = {}
function V13.ServerIntel.start()
    return V13.ServerIntel.refresh()
end
function V13.ServerIntel.refresh()
    local snapshot = {
        PlaceId = tostring(game.PlaceId),
        GameId = tostring(game.GameId),
        JobId = v13Text(game.JobId, 100),
        PlaceVersion = v13Text(game.PlaceVersion, 100),
        PlayerCount = #Players:GetPlayers(),
        MaxPlayers = tonumber(Players.MaxPlayers) or 0,
        Timestamp = v13Now(),
        Services = {}
    }
    for _, child in ipairs(v13GetChildren(game)) do
        if #snapshot.Services >= 80 then break end
        table.insert(snapshot.Services, v13Class(child) .. ":" .. v13Text(child.Name, 80))
    end
    v13ServiceSnapshot = snapshot
    V13.ServerSnapshot = snapshot
    v13SetModule("ServerIntel", true, "لقطة معلومات السيرفر محدثة")
    v13EvidenceAdd("Server", "game", "PlaceId=" .. snapshot.PlaceId .. " JobId=" .. snapshot.JobId)
    v13TimelineAdd("Server", "تم تحديث ذكاء السيرفر")
    return snapshot
end
function V13.ServerIntel.stop()
    v13SetModule("ServerIntel", false, "متوقف")
end

V13.InstanceInspector = {}
function V13.InstanceInspector.start()
    v13SetModule("InstanceInspector", true, "جاهز للفحص عند الطلب")
end
function V13.InstanceInspector.inspect(path)
    local object = v13ResolvePath(path)
    if not object then
        v13TimelineAdd("Instance", "تعذر حل المسار: " .. v13Text(path, 160))
        return nil, "المسار غير موجود"
    end
    local children = v13GetChildren(object)
    local info = {Name = v13Text(object.Name, 100), Class = v13Class(object), Path = v13InstancePath(object), Children = {}, ChildCount = #children}
    for index = 1, math.min(#children, 50) do
        table.insert(info.Children, v13Class(children[index]) .. ":" .. v13Text(children[index].Name, 80))
    end
    v13EvidenceAdd("Instance", info.Path, info.Class .. " children=" .. tostring(info.ChildCount))
    v13TimelineAdd("Instance", "تم فحص Instance/Service", info.Path)
    return info
end
function V13.InstanceInspector.stop()
    v13SetModule("InstanceInspector", false, "متوقف")
end

V13.Api = {}
function V13.Api.start()
    return V13.Api.refresh()
end
function V13.Api.refresh()
    local status = Safe.getEnvironmentStatus()
    v13ApiObservation = {
        HttpAvailable = status.HTTP == true,
        Endpoint = "https://openrouter.ai/api/v1/chat/completions",
        Scope = "طلبات Console AI فقط؛ لا توجد مراقبة عامة لطلبات اللعبة",
        Timestamp = v13Now()
    }
    V13.ApiObservation = v13ApiObservation
    v13SetModule("ApiObservation", true, status.HTTP and "HTTP متاح لطلبات Console" or "HTTP غير متاح")
    v13TimelineAdd("API", "تم تحديث حالة API")
    return v13ApiObservation
end
function V13.Api.stop()
    v13SetModule("ApiObservation", false, "متوقف")
end

V13.Security = {}
function V13.Security.start()
    V13.Security.setSafeMode(true)
    v13SetModule("Security", true, "Safe Mode جاهز للتحليل السلبي")
end
function V13.Security.setSafeMode(value)
    v13SafeMode = value ~= false
    V13.SafeMode = v13SafeMode
    v13TimelineAdd("Security", v13SafeMode and "Safe Mode مفعّل" or "تم طلب الوضع غير الآمن؛ بقيت الاختبارات سلبية فقط")
end
function V13.Security.runPassive()
    v13SafeMode = true
    V13.SafeMode = true
    local inspected = 0
    for _, log in ipairs(logsDatabase or {}) do
        if inspected >= V13_LIMITS.MaxTestItems then break end
        local source = tostring(log.Path or log.Name or "Unknown")
        v13AnalyzeValue(source, log.Args, 0, {})
        if tostring(log.Direction or "") == "Outgoing ⬆️" then
            if string.find(string.lower(source), "admin", 1, true) or string.find(string.lower(source), "auth", 1, true) then
                local evidence = v13EvidenceAdd("Authorization", source, "Observed outgoing call; passive review only")
                v13FindingAdd("AUTH_REVIEW", "info", "مراجعة تفويض مطلوبة", "تم رصد مسار يبدو متعلقاً بالصلاحيات؛ لا يوجد إثبات لتجاوز التفويض.", evidence.ID)
            end
        end
        inspected = inspected + 1
    end
    local evidence = v13EvidenceAdd("SecurityRun", "Console", "Safe Mode; no payloads sent; records=" .. tostring(inspected))
    v13FindingAdd("SAFE_MODE_RUN", "info", "تحليل أمني سلبي", "تم تحليل البيانات الملتقطة محلياً فقط دون إرسال SQLi/XSS/SSRF أو استدعاءات Fuzz.", evidence.ID)
    v13SetModule("Security", true, "تحليل سلبي آمن: " .. tostring(inspected) .. " سجل")
    v13TimelineAdd("Security", "اكتمل التحليل الأمني السلبي", inspected)
    return inspected
end
function V13.Security.prepareFuzzPlan()
    local plan = {
        Mode = "SAFE_DRY_RUN",
        SendsRequests = false,
        TargetCount = 0,
        Cases = {},
        Timestamp = v13Now()
    }
    for path, item in pairs(v13ActivitySummary or {}) do
        if plan.TargetCount >= V13_LIMITS.MaxTestItems then break end
        plan.TargetCount = plan.TargetCount + 1
        table.insert(plan.Cases, {Path = path, Method = item.Methods and "observed-methods" or "unknown", Mutation = "not-generated", Action = "review-only"})
    end
    local evidence = v13EvidenceAdd("FuzzPlan", "Console", "SAFE_DRY_RUN targets=" .. tostring(plan.TargetCount))
    v13FindingAdd("FUZZ_DRY_RUN", "info", "خطة Fuzz آمنة", "تم إنشاء خطة مراجعة فقط. لم يتم تعديل أو إرسال أي Remote payload.", evidence.ID)
    v13TimelineAdd("Security", "تم إعداد خطة Fuzz بدون إرسال", plan.TargetCount)
    V13.FuzzPlan = plan
    return plan
end
function V13.Security.stop()
    v13SetModule("Security", false, "متوقف")
end

V13.VulnerabilityDetection = {}
function V13.VulnerabilityDetection.start()
    return V13.VulnerabilityDetection.refresh()
end
function V13.VulnerabilityDetection.refresh()
    local result = #v13Findings
    v13SetModule("VulnerabilityDetection", true, "نتائج مؤشرات غير مؤكدة: " .. tostring(result))
    v13TimelineAdd("Detection", "تم تحديث كشف المؤشرات", result)
    return result
end
function V13.VulnerabilityDetection.stop()
    v13SetModule("VulnerabilityDetection", false, "متوقف")
end

V13.EvidenceCollector = {}
function V13.EvidenceCollector.start()
    v13SetModule("EvidenceCollector", true, "جاهز لحفظ الأدلة")
end
function V13.EvidenceCollector.snapshot()
    local value = "logs=" .. tostring(#(logsDatabase or {})) .. " findings=" .. tostring(#v13Findings) .. " remotes=" .. tostring(v13RemoteCatalog.Count or 0)
    local item = v13EvidenceAdd("Snapshot", "Console", value)
    v13TimelineAdd("Evidence", "تم حفظ لقطة أدلة", item.ID)
    return item
end
function V13.EvidenceCollector.stop()
    v13SetModule("EvidenceCollector", false, "متوقف")
end

V13.FindingsModule = {}
function V13.FindingsModule.start()
    return V13.FindingsModule.refresh()
end
function V13.FindingsModule.refresh()
    v13SetModule("Findings", true, "نتائج مدمجة ومحدودة")
    v13TimelineAdd("Findings", "تم تحديث النتائج", #v13Findings)
end
function V13.FindingsModule.stop()
    v13SetModule("Findings", false, "متوقف")
end

V13.TimelineModule = {}
function V13.TimelineModule.start()
    v13SetModule("Timeline", true, "سجل زمني محدود")
end
function V13.TimelineModule.stop()
    v13SetModule("Timeline", false, "متوقف")
end

V13.Export = {}
function V13.Export.start()
    v13SetModule("Export", true, "تصدير محلي فقط")
end
function V13.Export.buildReport()
    local lines = {"=== RE Ultimate Console v13 Report ===", "Generated=" .. v13Now(), "SafeMode=" .. tostring(v13SafeMode), ""}
    table.insert(lines, "[Server]")
    table.insert(lines, "PlaceId=" .. tostring(v13ServiceSnapshot.PlaceId or game.PlaceId) .. " JobId=" .. v13Text(v13ServiceSnapshot.JobId or game.JobId, 100))
    table.insert(lines, "[Modules]")
    for name, state in pairs(v13ModuleState) do
        table.insert(lines, tostring(name) .. " | running=" .. tostring(state.Running) .. " | " .. v13Text(state.Detail, 160))
    end
    table.insert(lines, "[Findings]")
    for _, finding in ipairs(v13Findings) do
        table.insert(lines, string.format("#%d | %s | %s | %s | evidence=%s", finding.ID, finding.Severity, finding.Code, finding.Title, tostring(finding.Evidence)))
    end
    table.insert(lines, "[Timeline]")
    local startIndex = math.max(1, #v13Timeline - 50)
    for index = startIndex, #v13Timeline do
        local item = v13Timeline[index]
        table.insert(lines, string.format("%s | %s | %s", item.Timestamp, item.Kind, item.Message))
    end
    return table.concat(lines, "\n")
end
function V13.Export.copy()
    local report = V13.Export.buildReport()
    local copied, copyError = Safe.setclipboard(report)
    if not copied then Safe.reportError("V13.Export", copyError) end
    return copied, report
end
function V13.Export.save()
    local report = V13.Export.buildReport()
    local saved = Safe.writefile("re_console_v13_report.txt", report)
    return saved, report
end
function V13.Export.stop()
    v13SetModule("Export", false, "متوقف")
end

local function v13StartAll()
    if v13Destroyed or v13Running then return end
    if not guiParentSet or not v13UiReady then
        v13BootDiagnostic("V13 module initialization", "Core", "v13StartAll", "SKIPPED", "UI is not confirmed", "keep optional modules stopped")
        return
    end
    consoleActive = true
    consoleStopRequested = false
    v13Initialized = true
    v13Running = true
    v13SetBootStage("V13 module initialization")
    v13BootDiagnostic(v13BootStage, "Core", "v13StartAll", "START", "", "initializing isolated modules")
    v13SafeCall("V13.RemoteActivity", V13.RemoteActivity.start)
    v13SafeCall("V13.ArgumentInspector", V13.ArgumentInspector.start)
    v13SafeCall("V13.ServerIntel", V13.ServerIntel.start)
    v13SafeCall("V13.InstanceInspector", V13.InstanceInspector.start)
    v13SafeCall("V13.Api", V13.Api.start)
    v13SafeCall("V13.Security", V13.Security.start)
    v13SafeCall("V13.InputAnalyzer", V13.InputAnalyzer.start)
    v13SafeCall("V13.VulnerabilityDetection", V13.VulnerabilityDetection.start)
    v13SafeCall("V13.EvidenceCollector", V13.EvidenceCollector.start)
    v13SafeCall("V13.Findings", V13.FindingsModule.start)
    v13SafeCall("V13.Timeline", V13.TimelineModule.start)
    v13SafeCall("V13.Export", V13.Export.start)
    v13SafeCall("V13.Evidence", V13.EvidenceCollector.snapshot)
    v13SetModule("Core", true, "Console v13 تعمل")
    v13TimelineAdd("Core", "بدأت وحدات Console v13")
    v13BootDiagnostic(v13BootStage, "Core", "v13StartAll", "PASS", "", "Console and isolated modules running")
end

local function v13StopAll()
    consoleActive = false
    consoleStopRequested = true
    v13Running = false
    v13SafeCall("V13.RemoteDiscovery", V13.RemoteDiscovery.stop)
    v13SafeCall("V13.RemoteActivity", V13.RemoteActivity.stop)
    v13SafeCall("V13.ArgumentInspector", V13.ArgumentInspector.stop)
    v13SafeCall("V13.ServerIntel", V13.ServerIntel.stop)
    v13SafeCall("V13.InstanceInspector", V13.InstanceInspector.stop)
    v13SafeCall("V13.Api", V13.Api.stop)
    v13SafeCall("V13.Security", V13.Security.stop)
    v13SafeCall("V13.VulnerabilityDetection", V13.VulnerabilityDetection.stop)
    v13SafeCall("V13.Evidence", V13.EvidenceCollector.stop)
    v13SafeCall("V13.Findings", V13.FindingsModule.stop)
    v13SafeCall("V13.Timeline", V13.TimelineModule.stop)
    v13SafeCall("V13.Export", V13.Export.stop)
    v13SetModule("Core", false, "متوقف")
end

V13.StartAll = v13StartAll
V13.StopAll = v13StopAll

local function v13ClearContent()
    if not v13Content then return end
    for _, child in ipairs(v13Content:GetChildren()) do pcall(function() child:Destroy() end) end
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 3)
    layout.Parent = v13Content
end

local function v13AddLabel(text, color, height)
    if not v13Content then return nil end
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 0, height or 22)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = true
    label.Font = Enum.Font.Code
    label.TextSize = 10
    label.TextColor3 = color or Color3.fromRGB(220, 225, 235)
    label.TextStrokeTransparency = 1
    label.Text = tostring(text or "")
    label.LayoutOrder = #v13Content:GetChildren()
    label.ZIndex = 372
    label.Parent = v13Content
    return label
end

local function v13AddCard(titleText, valueText, accent, height)
    if not v13Content then return nil end
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, height or 54)
    card.BorderSizePixel = 0
    card.LayoutOrder = #v13Content:GetChildren()
    card.ZIndex = 372
    card.Parent = v13Content
    reSurface(card, "Secondary", accent or RE_DESIGN.Colors.Primary)
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -18, 0, 16)
    titleLabel.Position = UDim2.new(0, 9, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.ZIndex = 373
    titleLabel.Text = tostring(titleText or "")
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    reStyleText(titleLabel, 10, RE_DESIGN.Colors.Muted, Enum.Font.GothamMedium)
    titleLabel.Parent = card
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(1, -18, 0, (height or 54) - 22)
    valueLabel.Position = UDim2.new(0, 9, 0, 21)
    valueLabel.BackgroundTransparency = 1
    valueLabel.ZIndex = 373
    valueLabel.Text = tostring(valueText or "")
    valueLabel.TextWrapped = true
    valueLabel.TextXAlignment = Enum.TextXAlignment.Left
    reStyleText(valueLabel, 14, RE_DESIGN.Colors.Text, Enum.Font.GothamBold)
    valueLabel.Parent = card
    return card
end

local function v13AddAction(text, callback, color)
    if not v13Content then return nil end
    local button = createButton(v13Content, 0, 0, 100, 26, text)
    button.Size = UDim2.new(1, -8, 0, 26)
    button.Position = UDim2.new(0, 4, 0, 0)
    button.LayoutOrder = #v13Content:GetChildren()
    button.ZIndex = 372
    if color then button.BackgroundColor3 = color end
    reStyleButton(button, color and "Primary" or "Secondary")
    v13OwnConnection(button.MouseButton1Click:Connect(function()
        if not consoleActive then return end
        local ok, err = pcall(callback)
        if not ok then Safe.reportError("V13.UI", err) end
    end))
    return button
end

local function v13RefreshCanvas()
    if v13Content then
        local layout = v13Content:FindFirstChildOfClass("UIListLayout")
        if layout then v13Content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12) end
    end
end

local function v13RenderDashboard()
    v13ClearContent()
    v13AddLabel(RE_DESIGN.Icon .. "  RE ULTIMATE CONSOLE  |  لوحة التحكم", RE_DESIGN.Colors.Text, 26)
    v13AddCard("CORE STATUS", consoleActive and "● شغال  •  V13" or "○ متوقف", consoleActive and RE_DESIGN.Colors.Success or RE_DESIGN.Colors.Warning, 58)
    v13AddCard("OBSERVABILITY", string.format("%d logs  •  %d remotes  •  %d findings", #(logsDatabase or {}), tonumber(v13RemoteCatalog.Count or 0), #v13Findings), RE_DESIGN.Colors.Primary, 58)
    v13AddCard("SECURITY", v13SafeMode and "SAFE MODE  •  تحليل سلبي فقط" or "SAFE MODE", RE_DESIGN.Colors.Accent, 58)
    v13AddCard("SERVER", string.format("%d/%d players  •  Place %s", #Players:GetPlayers(), tonumber(Players.MaxPlayers) or 0, tostring(game.PlaceId)), RE_DESIGN.Colors.Secondary, 58)
    v13AddLabel("الوضع: " .. (consoleActive and "شغال" or "متوقف") .. " | Safe Mode: " .. (v13SafeMode and "مفعّل" or "مفعّل افتراضياً"), RE_DESIGN.Colors.Muted, 22)
    v13AddAction("بدء وحدات Console", function() v13StartAll(); v13RenderDashboard() end, Color3.fromRGB(40, 120, 70))
    v13AddAction("إيقاف وتنظيف Console", function() V13.Cleanup() end, Color3.fromRGB(130, 50, 50))
    v13AddAction("اكتشاف الريموتات المحدود", function() V13.RemoteDiscovery.start(); v13RenderDashboard() end, Color3.fromRGB(45, 90, 140))
    v13AddAction("تحليل الوسائط والمؤشرات", function() V13.ArgumentInspector.refresh(); V13.Security.runPassive(); v13RenderDashboard() end, Color3.fromRGB(95, 65, 135))
    v13AddAction("إنشاء خطة Fuzz آمنة", function() V13.RemoteActivity.refresh(); V13.Security.prepareFuzzPlan(); v13RenderDashboard() end, Color3.fromRGB(100, 75, 35))
    for name, state in pairs(v13ModuleState) do
        v13AddLabel(name .. " | " .. (state.Running and "شغال" or "متوقف") .. " | " .. v13Text(state.Detail, 120), state.Running and Color3.fromRGB(170, 255, 180) or Color3.fromRGB(170, 175, 185), 20)
    end
    v13RefreshCanvas()
end

local function v13RenderLogs()
    v13ClearContent()
    v13AddLabel(RE_DESIGN.Signal .. "  السجلات | سجلات V12 المجمعة محلياً", RE_DESIGN.Colors.Text, 24)
    local startIndex = math.max(1, #(logsDatabase or {}) - V13_LIMITS.MaxUiRows + 1)
    for index = startIndex, #(logsDatabase or {}) do
        local log = logsDatabase[index]
        v13AddLabel(string.format("#%s %s | %s | %s | x%s", tostring(log.ID), v13Text(log.Name, 80), v13Text(log.Method, 30), v13Text(log.Direction, 30), tostring(log.Count or 1)), Color3.fromRGB(215, 220, 230), 20)
    end
    v13RefreshCanvas()
end

local function v13RenderRemotes()
    v13ClearContent()
    v13AddLabel(RE_DESIGN.Signal .. "  الريموتات | Remote Discovery و Remote Activity", RE_DESIGN.Colors.Text, 24)
    v13AddAction("تحديث نشاط الريموتات", function() V13.RemoteActivity.refresh(); v13RenderRemotes() end, Color3.fromRGB(45, 90, 140))
    v13AddAction("بدء اكتشاف محدود", function() V13.RemoteDiscovery.start(); v13RenderRemotes() end, Color3.fromRGB(45, 90, 140))
    local count = 0
    for path, item in pairs(v13RemoteCatalog) do
        if path ~= "Count" and count < V13_LIMITS.MaxUiRows then
            v13AddLabel(item.Class .. " | " .. v13Text(path, 190), Color3.fromRGB(210, 220, 235), 20)
            count = count + 1
        end
    end
    for path, item in pairs(v13ActivitySummary or {}) do
        if count < V13_LIMITS.MaxUiRows then
            v13AddLabel("نشاط x" .. tostring(item.Count) .. " | " .. v13Text(path, 190), Color3.fromRGB(255, 220, 160), 20)
            count = count + 1
        end
    end
    v13RefreshCanvas()
end

local function v13RenderServer()
    v13ClearContent()
    v13AddLabel("ذكاء السيرفر و Instance/Service inspection", Color3.fromRGB(160, 220, 255), 24)
    v13AddAction("تحديث معلومات السيرفر", function() V13.ServerIntel.refresh(); v13RenderServer() end, Color3.fromRGB(45, 90, 140))
    local snapshot = v13ServiceSnapshot
    v13AddLabel("PlaceId=" .. tostring(snapshot.PlaceId or game.PlaceId), Color3.fromRGB(220, 225, 235), 20)
    v13AddLabel("GameId=" .. tostring(snapshot.GameId or game.GameId), Color3.fromRGB(220, 225, 235), 20)
    v13AddLabel("JobId=" .. v13Text(snapshot.JobId or game.JobId, 180), Color3.fromRGB(220, 225, 235), 20)
    v13AddLabel("Players=" .. tostring(snapshot.PlayerCount or #Players:GetPlayers()) .. "/" .. tostring(snapshot.MaxPlayers or Players.MaxPlayers), Color3.fromRGB(220, 225, 235), 20)
    for _, service in ipairs(snapshot.Services or {}) do v13AddLabel(service, Color3.fromRGB(190, 205, 220), 19) end
    v13RefreshCanvas()
end

local function v13RenderSecurity()
    v13ClearContent()
    v13AddLabel(RE_DESIGN.Icon .. "  الأمان | Safe Mode هو الوضع الافتراضي", RE_DESIGN.Colors.Warning, 24)
    v13AddLabel("الاختبارات هنا سلبية ومحدودة: لا تُرسل حمولة SQLi/XSS/SSRF ولا تعدل Remotes.", Color3.fromRGB(220, 225, 235), 34)
    v13AddAction("تشغيل التحليل الأمني السلبي", function() V13.Security.runPassive(); v13RenderSecurity() end, Color3.fromRGB(95, 65, 135))
    v13AddAction("خطة Fuzz بدون إرسال", function() V13.Security.prepareFuzzPlan(); v13RenderSecurity() end, Color3.fromRGB(100, 75, 35))
    v13AddAction("تشغيل Input Analyzer", function() V13.ArgumentInspector.refresh(); v13RenderSecurity() end, Color3.fromRGB(45, 90, 140))
    for _, finding in ipairs(v13Findings) do
        v13AddLabel(finding.Severity .. " | " .. finding.Code .. " | " .. finding.Title, Color3.fromRGB(255, 200, 150), 22)
    end
    v13RefreshCanvas()
end

local function v13RenderApi()
    v13ClearContent()
    v13AddLabel("API | ملاحظة طلبات Console فقط", Color3.fromRGB(160, 220, 255), 24)
    v13AddAction("تحديث حالة API", function() V13.Api.refresh(); v13RenderApi() end, Color3.fromRGB(45, 90, 140))
    v13AddLabel("HTTP=" .. tostring(v13ApiObservation.HttpAvailable), Color3.fromRGB(220, 225, 235), 20)
    v13AddLabel("Endpoint=" .. tostring(v13ApiObservation.Endpoint or "غير محدد"), Color3.fromRGB(220, 225, 235), 20)
    v13AddLabel(tostring(v13ApiObservation.Scope or "لا توجد ملاحظة"), Color3.fromRGB(190, 205, 220), 30)
    v13RefreshCanvas()
end

local function v13RenderFindings()
    v13ClearContent()
    v13AddLabel(RE_DESIGN.Icon .. "  النتائج | Findings و Evidence", RE_DESIGN.Colors.Warning, 24)
    v13AddAction("حفظ Snapshot", function() V13.EvidenceCollector.snapshot(); v13RenderFindings() end, Color3.fromRGB(45, 90, 140))
    v13AddAction("نسخ التقرير", function() local copied = V13.Export.copy(); v13AddLabel(copied and "تم نسخ التقرير" or "تعذر النسخ", copied and Color3.fromRGB(160, 255, 170) or Color3.fromRGB(255, 150, 130), 22) end, Color3.fromRGB(40, 120, 70))
    v13AddAction("حفظ التقرير", function() local saved = V13.Export.save(); v13AddLabel(saved and "تم حفظ التقرير" or "تعذر الحفظ", saved and Color3.fromRGB(160, 255, 170) or Color3.fromRGB(255, 150, 130), 22) end, Color3.fromRGB(45, 90, 140))
    for _, finding in ipairs(v13Findings) do
        v13AddLabel(string.format("#%d | %s | %s | x%d\n%s", finding.ID, finding.Severity, finding.Code, finding.Count or 1, finding.Detail), Color3.fromRGB(235, 215, 195), 38)
    end
    v13RefreshCanvas()
end

local function v13RenderTimeline()
    v13ClearContent()
    v13AddLabel(RE_DESIGN.Signal .. "  الخط الزمني | Timeline", RE_DESIGN.Colors.Text, 24)
    local startIndex = math.max(1, #v13Timeline - V13_LIMITS.MaxUiRows + 1)
    for index = startIndex, #v13Timeline do
        local item = v13Timeline[index]
        v13AddLabel(item.Timestamp .. " | " .. item.Kind .. " | " .. item.Message, Color3.fromRGB(210, 220, 230), 20)
    end
    v13RefreshCanvas()
end

local function v13RenderSettings()
    v13ClearContent()
    v13AddLabel("الإعدادات | حدود التشغيل والتنظيف", Color3.fromRGB(160, 220, 255), 24)
    v13AddLabel("Safe Mode=" .. tostring(v13SafeMode) .. " | Queue=" .. tostring(V13_LIMITS.MaxQueue) .. " | UI=" .. tostring(V13_LIMITS.MaxUiRows), Color3.fromRGB(220, 225, 235), 24)
    v13AddAction("Safe Mode: تشغيل افتراضي", function() V13.Security.setSafeMode(true); v13RenderSettings() end, Color3.fromRGB(40, 120, 70))
    v13AddAction("إيقاف وتنظيف جميع موارد Console", function() V13.Cleanup() end, Color3.fromRGB(130, 50, 50))
    v13AddLabel("كل Workers وTimers الجديدة تستخدم consoleActive وGeneration للإيقاف، والاتصالات الجديدة مسجلة للتنظيف.", Color3.fromRGB(190, 205, 220), 38)
    v13RefreshCanvas()
end

local function v13RenderTab(tab)
    v13ActiveTab = tab
    if tab == "لوحة التحكم" then v13RenderDashboard()
    elseif tab == "السجلات" then v13RenderLogs()
    elseif tab == "الريموتات" then v13RenderRemotes()
    elseif tab == "ذكاء السيرفر" then v13RenderServer()
    elseif tab == "الأمان" then v13RenderSecurity()
    elseif tab == "API" then v13RenderApi()
    elseif tab == "النتائج" then v13RenderFindings()
    elseif tab == "الخط الزمني" then v13RenderTimeline()
    elseif tab == "الإعدادات" then v13RenderSettings()
    end
end

v13Panel = Instance.new("Frame")
v13Panel.Size = UDim2.new(1, -10, 1, -104)
v13Panel.Position = UDim2.new(0, 5, 0, 99)
v13Panel.BackgroundColor3 = RE_DESIGN.Colors.GlassDeep
v13Panel.BackgroundTransparency = 0
v13Panel.BorderSizePixel = 0
v13Panel.ZIndex = 360
v13Panel.Visible = false
v13Panel.Parent = inspectorFrame
    pcall(function() addGlassStyle(v13Panel, 8, Color3.fromRGB(78, 135, 190), 0.1) end)
    reSurface(v13Panel, "Primary", RE_DESIGN.Colors.Primary)
    v13Panel.ZIndex = 360
    v13Panel.BackgroundTransparency = 0
    v13Panel.BackgroundColor3 = RE_DESIGN.Colors.GlassDeep

local v13TabBar = Instance.new("ScrollingFrame")
v13TabBar.Size = UDim2.new(1, -10, 0, 34)
v13TabBar.Position = UDim2.new(0, 5, 0, 62)
v13TabBar.BackgroundTransparency = 1
v13TabBar.BorderSizePixel = 0
v13TabBar.ZIndex = 370
v13TabBar.ScrollBarThickness = 0
v13TabBar.ScrollingDirection = Enum.ScrollingDirection.X
v13TabBar.CanvasSize = UDim2.new(0, 9 * 77, 0, 0)
v13TabBar.Visible = false
v13TabBar.ZIndex = 370
v13TabBar.Parent = inspectorFrame
local v13TabLayout = Instance.new("UIListLayout")
v13TabLayout.FillDirection = Enum.FillDirection.Horizontal
v13TabLayout.Padding = UDim.new(0, 5)
v13TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
v13TabLayout.Parent = v13TabBar
v13OwnConnection(v13TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    if not consoleActive then return end
    v13TabBar.CanvasSize = UDim2.new(0, v13TabLayout.AbsoluteContentSize.X + 8, 0, 0)
end))

local v13TabNames = {"لوحة التحكم", "السجلات", "الريموتات", "ذكاء السيرفر", "الأمان", "API", "النتائج", "الخط الزمني", "الإعدادات"}
local v13TabButtons = {}
for index, tabName in ipairs(v13TabNames) do
    local tabButton = createButton(v13TabBar, 0, 0, 72, 30, tabName)
    tabButton.LayoutOrder = index
    tabButton.ZIndex = 371
    tabButton.TextSize = 9
    reStyleButton(tabButton, "Secondary")
    v13TabButtons[tabName] = tabButton
    v13OwnConnection(tabButton.MouseButton1Click:Connect(function()
        if not consoleActive then return end
        for name, button in pairs(v13TabButtons) do button.BackgroundColor3 = name == tabName and Color3.fromRGB(55, 110, 155) or Color3.fromRGB(37, 42, 52) end
        v13RenderTab(tabName)
    end))
end

v13Content = Instance.new("ScrollingFrame")
v13Content.Size = UDim2.new(1, -10, 1, -10)
v13Content.Position = UDim2.new(0, 5, 0, 5)
v13Content.BackgroundTransparency = 1
v13Content.BorderSizePixel = 0
v13Content.ZIndex = 371
v13Content.ScrollBarThickness = 3
v13Content.CanvasSize = UDim2.new(0, 0, 0, 0)
v13Content.ZIndex = 371
v13Content.Parent = v13Panel

local v13OpenButton = createButton(toolbarFrame, 0, 0, 50, 28, "v13")
RE_DESIGN.V13Button = v13OpenButton
reStyleButton(v13OpenButton, "Accent")
v13OpenButton.AnchorPoint = Vector2.new(1, 0)
v13OpenButton.Position = UDim2.new(1, -5, 0, 0)
v13OpenButton.ZIndex = 380
v13OpenButton.BackgroundColor3 = RE_DESIGN.Colors.Accent
v13OwnConnection(v13OpenButton.MouseButton1Click:Connect(function()
    if not consoleActive then return end
    local visible = not v13Panel.Visible
    v13Panel.Visible = visible
    v13TabBar.Visible = visible
    rightScroll.Visible = not visible
    aiFrame.Visible = false
    modelFrame.Visible = false
    if visible then
        for name, button in pairs(v13TabButtons) do button.BackgroundColor3 = name == "لوحة التحكم" and Color3.fromRGB(55, 110, 155) or Color3.fromRGB(37, 42, 52) end
        v13RenderTab("لوحة التحكم")
    end
end))

v13OwnConnection(inspectorCloseBtn.MouseButton1Click:Connect(function()
    if v13Panel then v13Panel.Visible = false end
    if v13TabBar then v13TabBar.Visible = false end
end))

function V13.Cleanup()
    if v13Destroyed then return end
    v13Destroyed = true
    v13Running = false
    v13BootDiagnostic("Cleanup", "Core", "V13.Cleanup", "START", "", "stopping owned resources")
    consoleActive = false
    consoleStopRequested = true
    v13Generation = v13Generation + 1
    v13StopAll()
    if type(v13RestoreNoclip) == "function" then pcall(v13RestoreNoclip) end
    if type(clearESP) == "function" then pcall(clearESP) end
    rapidEnabled = false
    hitboxEnabled = false
    deadlyEnabled = false
    noclipEnabled = false
    invisibleEnabled = false
    ghostEnabled = false
    godModeEnabled = false
    espEnabled = false
    for _, connection in ipairs(v13ConnectionRegistry) do v13Disconnect(connection) end
    for _, connection in ipairs(v12OwnedConnections) do v13Disconnect(connection) end
    v12OwnedConnections = {}
    v13ConnectionRegistry = {}
    for object, connection in pairs(remoteListeners) do
        if type(connection) == "userdata" or type(connection) == "table" then v13Disconnect(connection) end
        remoteListeners[object] = nil
    end
    if v12HeartbeatConnection then v13Disconnect(v12HeartbeatConnection); v12HeartbeatConnection = nil end
    if v12RenderConnection then v13Disconnect(v12RenderConnection); v12RenderConnection = nil end
    if v12DescendantConnection then v13Disconnect(v12DescendantConnection); v12DescendantConnection = nil end
    if v12UiViewportConnection then v13Disconnect(v12UiViewportConnection); v12UiViewportConnection = nil end
    if v12HookInstalled and v12HookMt and v12OldNamecall then
        local writable = Safe.setreadonly(v12HookMt, false)
        if writable then
            pcall(function() v12HookMt.__namecall = v12OldNamecall end)
            Safe.setreadonly(v12HookMt, true)
        end
        v12HookInstalled = false
    end
    if type(restoreV12State) == "function" then pcall(restoreV12State) end
    if gui then pcall(function() gui:Destroy() end) end
    v13Panel = nil
    v13Content = nil
    v13Initialized = false
    v13Timeline = {}
    v13Findings = {}
    v13Evidence = {}
    v13Queue = {}
    v13BootDiagnostic("Cleanup", "Core", "V13.Cleanup", "PASS", "", "owned resources disconnected and GUI destroyed")
    Safe.reportError("V13", "Console v13 تم إيقافها وتنظيف مواردها")
end
if guiParentSet then
    v13StartAll()
    v13RenderTab("لوحة التحكم")
else
    v13BootDiagnostic("V13 module initialization", "Core", "startup gate", "SKIPPED", "GUI host is not ready", "deferred startup will retry after host attachment")
    task.spawn(function()
        for attempt = 1, 24 do
            if not consoleActive then return end
            if guiParentSet and v13UiReady then
                v13StartAll()
                v13RenderTab("لوحة التحكم")
                return
            end
            task.wait(0.25)
        end
        v13BootDiagnostic("V13 module initialization", "Core", "startup gate", "FAILED", "GUI host retry exhausted", "Console remains in emergency recovery mode")
    end)
end



task.defer(function()
    V13.CleanupOnStop = V13.Cleanup
    _G.RE_Ultimate_Console_V13 = V13
end)
end)
