local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local Safe = {
    getrawmetatable = function(...) local s, r = pcall(getrawmetatable, ...) return s and r or nil end,
    newcclosure = function(...) local s, r = pcall(newcclosure, ...) return s and r or (function(...) return ... end) end,
    checkcaller = function(...) local s, r = pcall(checkcaller, ...) return s and r or false end,
    getnamecallmethod = function(...) local s, r = pcall(getnamecallmethod, ...) return s and r or "" end,
    setreadonly = function(...) local s, r = pcall(setreadonly, ...) return s and r or nil end,
    writefile = function(...) local s, r = pcall(writefile, ...) return s and r or nil end,
    readfile = function(...) local s, r = pcall(readfile, ...) return s and r or nil end,
    isfile = function(...) local s, r = pcall(isfile, ...) return s and r or false end,
    setclipboard = function(...) local s, r = pcall(setclipboard, ...) return s and r or nil end,
    gethui = function(...) local s, r = pcall(gethui, ...) return s and r or nil end,
    http_request = function(...) 
        local f = http_request or request or (syn and syn.request) or (http and http.request)
        if f then
            local s, r = pcall(f, ...)
            return s and r or nil
        end
        return nil
    end
}

local INSPECTOR_SETTINGS = {
    MaxLogs = 150,
    MaxDepth = 5,
    MaxStringLength = 500,
    Deduplicate = true,
    LogsPerFrame = 10
}

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

pcall(function()
    local hui = Safe.gethui()
    if hui then
        gui.Parent = hui
    else
        gui.Parent = CoreGui
    end
end)
if gui.Parent == nil then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local iconBtn = Instance.new("TextButton")
iconBtn.Size = UDim2.new(0, 40, 0, 40)
iconBtn.Position = UDim2.new(0, 15, 0, 15)
iconBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
iconBtn.BorderSizePixel = 2
iconBtn.BorderColor3 = Color3.fromRGB(255, 50, 50)
iconBtn.Text = "RE"
iconBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
iconBtn.Font = Enum.Font.Code
iconBtn.TextSize = 20
iconBtn.Parent = gui
makeDraggable(iconBtn, iconBtn)

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
title.Font = Enum.Font.Code
title.TextSize = 13
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
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.Code
    btn.TextSize = 12
    btn.Parent = parent
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
inspectorTitle.Font = Enum.Font.Code
inspectorTitle.TextSize = 12
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
modelFrame.Size = UDim2.new(0, 340, 0, 150)
modelFrame.Position = UDim2.new(0.5, -170, 0.5, -75)
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
modelTitle.Font = Enum.Font.Code
modelTitle.TextSize = 12
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
modelNameBox.PlaceholderText = "google/gemma-3-27b-it:free"
modelNameBox.Text = "google/gemma-3-27b-it:free"
modelNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
modelNameBox.Font = Enum.Font.Code
modelNameBox.TextSize = 11
modelNameBox.Parent = modelFrame

local applyModelBtn = createButton(modelFrame, 10, 112, 320, 30, "تطبيق")
applyModelBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)

local savedApiKey = ""
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

applyModelBtn.MouseButton1Click:Connect(function()
    savedApiKey = apiKeyBox.Text
    if savedApiKey ~= "" then
        Safe.writefile("re_ai_key.txt", savedApiKey)
    end
    modelFrame.Visible = false
    inspectorTitle.Text = "  [RE] Inspector - AI Model: " .. modelNameBox.Text
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

iconBtn.MouseButton1Click:Connect(function() menuFrame.Visible = not menuFrame.Visible end)
closeBtn.MouseButton1Click:Connect(function() menuFrame.Visible = false end)
inspectorCloseBtn.MouseButton1Click:Connect(function() inspectorFrame.Visible = false end)
toggleInspectorBtn.MouseButton1Click:Connect(function() inspectorFrame.Visible = not inspectorFrame.Visible end)

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
        local success, name = pcall(function() return data.Name end)
        local successClass, class = pcall(function() return data.ClassName end)
        return success and string.format("Instance: %s [%s]", name, class) or "{Destroyed}"
    elseif t == "Vector3" or t == "Vector2" then
        return string.format("%s(%.2f, %.2f, %.2f)", t, data.X, data.Y, data.Z or 0)
    elseif t == "CFrame" then
        return string.format("CFrame(%.1f, %.1f, %.1f)", data.Position.X, data.Position.Y, data.Position.Z)
    elseif t == "string" then
        return #data > INSPECTOR_SETTINGS.MaxStringLength and string.sub(data, 1, INSPECTOR_SETTINGS.MaxStringLength) .. "..." or '"' .. data .. '"'
    end
    return tostring(data)
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
    btn.Size = UDim2.new(1, 0, 0, 42)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.Text = ""
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
            
            if INSPECTOR_SETTINGS.Deduplicate and #logsDatabase > 0 then
                local lastLog = logsDatabase[#logsDatabase]
                if lastLog.Name == newLog.Name and lastLog.Method == newLog.Method and lastLog.Direction == newLog.Direction then
                    lastLog.Count = lastLog.Count + 1
                    lastLog.Timestamp = newLog.Timestamp
                    if lastLog.UpdateFunc then lastLog.UpdateFunc() end
                    continue
                end
            end
            
            table.insert(logsDatabase, newLog)
            drawLogUI(newLog)
            
            if #logsDatabase > INSPECTOR_SETTINGS.MaxLogs then
                local old = table.remove(logsDatabase, 1)
                if old.UI then old.UI:Destroy() end
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
    if activeTreeData ~= "" then Safe.setclipboard(activeTreeData) end
end)

copyAllBtn.MouseButton1Click:Connect(function()
    if #logsDatabase == 0 then return end
    
    local allDataText = "=== سجل ريموتات اللعبة الكامل ===\n\n"
    for _, log in ipairs(logsDatabase) do
        allDataText = allDataText .. string.format("[#%03d] [%s] %s (%s) | %s | المرسل: %s | التكرار: x%d\n", 
            log.ID, log.Timestamp, log.Name, log.Method, log.Direction, log.Sender, log.Count)
        allDataText = allDataText .. "المسار: " .. log.Path .. "\n"
        local argsText = ""
        local function parseArgsToString(data, indentLevel)
            for k, v in pairs(data) do
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
    
    if Safe.setclipboard then
        Safe.setclipboard(allDataText)
        copyAllBtn.Text = "تم النسخ!"
        copyAllBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        task.delay(1.5, function() 
            copyAllBtn.Text = "نسخ الكل" 
            copyAllBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        end)
    else
        copyAllBtn.Text = "غير مدعوم"
    end
end)

dedupBtn.MouseButton1Click:Connect(function()
    INSPECTOR_SETTINGS.Deduplicate = not INSPECTOR_SETTINGS.Deduplicate
    dedupBtn.Text = "دمج التكرار: " .. (INSPECTOR_SETTINGS.Deduplicate and "ON" or "OFF")
    dedupBtn.BackgroundColor3 = INSPECTOR_SETTINGS.Deduplicate and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(100, 50, 50)
end)

local chatHistory = {}
local latestGeneratedScript = ""

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

local function callOpenRouter(userPromptText)
    if savedApiKey == "" then
        appendAiOutput("خطأ: مطلوب مفتاح API - افتح تبويبة النموذج 🔧 والصق مفتاح OpenRouter الخاص بك.", Color3.fromRGB(255, 50, 50))
        return
    end

    genBtn.Active = false
    sendEditBtn.Active = false
    genBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    sendEditBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    appendAiOutput("جارٍ التوليد...", Color3.fromRGB(255, 255, 100))

    if #chatHistory == 0 then
        -- 💡 تم تقوية وتحديث البرومبت ليكون أكثر دقة وصرامة
        table.insert(chatHistory, {
    role = "system",
    content = [[أنت مهندس برمجيات خبير ومحترف جداً في لغة Luau وبيئة تطوير Roblox. مهمتك تحليل سجلات الشبكة (RemoteEvents / RemoteFunctions) بدقة مطلقة وتوليد أكواد برمجية تنفيذية نظيفة، آمنة، ومستقرة بنسبة 100%.

قواعد وشروط صارمة للغاية (يُمنع منعاً باتاً مخالفقتها):
1. **انعدام التعليقات التامة:** يُحظر كتابة أي تعليق برمجي نهائياً (مثل `--` أو تعليقات توضيحية) داخل الكود المولد لمنع أي أخطاء أثناء تنفيذ الـ loadstring.
2. **التحقق الدفاعي الصارم (Defensive Programming):** لا تعتمد أبداً على الوصول المباشر بالنقطة (مثل game.Workspace.Part). استخدم دائماً FindFirstChild أو مسارات آمنة متحقق منها لتفادي أخطاء الـ nil pointer أو الـ Infinite Yield.
3. **مطابقة الـ Arguments بدقة:** التزم حرفياً بالأنواع والبيانات (Arguments) الظاهرة في سجل الكونسول المرفق. إذا كان الريموت يتطلب جداول أو قيم محددة، قم بتضمينها بدقة ولا ترسلها فارغة عشوائياً.
4. **عزل الأخطاء (Error Containment):** يجب حماية كل عملية اتصال بالسيرفر (FireServer / InvokeServer) أو حلقات التكرار داخل pcall مع فترات انتظار منطقية task.wait() لتجنب حظر السيرفر (Rate Limiting).
5. **شكل المخرجات النهائي:** إجابتك يجب أن تكون كود Lua صافي فقط، محصور حصرياً داخل بلوك ```lua ... ``` ولا تحوي أي حرف، نص، أو شرح خارجه نهائياً.]]
})

    end

    table.insert(chatHistory, {
        role = "user",
        content = userPromptText
    })

    task.spawn(function()
        local payloadData = {
            model = modelNameBox.Text ~= "" and modelNameBox.Text or "google/gemma-3-27b-it:free",
            messages = chatHistory,
            max_tokens = 8000
        }

        local success, res = pcall(function()
            return Safe.http_request({
                Url = "https://openrouter.ai/api/v1/chat/completions",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Authorization"] = "Bearer " .. savedApiKey,
                    ["HTTP-Referer"] = "https://openrouter.ai",
                    ["X-Title"] = "RE Panel AI"
                },
                Body = HttpService:JSONEncode(payloadData)
            })
        end)

        genBtn.Active = true
        sendEditBtn.Active = true
        genBtn.BackgroundColor3 = Color3.fromRGB(90, 30, 130)
        sendEditBtn.BackgroundColor3 = Color3.fromRGB(180, 90, 20)

        if success and res and res.Body then
            local decodeSuccess, decoded = pcall(function()
                return HttpService:JSONDecode(res.Body)
            end)

            if decodeSuccess and decoded and decoded.choices and decoded.choices[1] then
                local replyContent = decoded.choices[1].message.content
                table.insert(chatHistory, {
                    role = "assistant",
                    content = replyContent
                })

                local scriptMatch = string.match(replyContent, "```lua%s*(.-)%s*```") or string.match(replyContent, "```%s*(.-)%s*```") or replyContent
                latestGeneratedScript = scriptMatch

                appendAiOutput("تم توليد وتحديث السكربت بنجاح (جاهز للنسخ والتنفيذ).", Color3.fromRGB(100, 255, 100))
                for line in string.gmatch(scriptMatch, "[^\r\n]+") do
                    appendAiOutput(line, Color3.fromRGB(170, 220, 255))
                end
            else
                appendAiOutput("خطأ في تحليل رد الـ API.", Color3.fromRGB(255, 50, 50))
            end
        else
            appendAiOutput("فشل الطلب إلى OpenRouter API.", Color3.fromRGB(255, 50, 50))
        end
    end)
end

genBtn.MouseButton1Click:Connect(function()
    local consoleSummary = "=== معلومات اللعبة ===\n"
    consoleSummary = consoleSummary .. string.format("PlaceId: %s | GameId: %s | اسم اللعبة: %s\n\n=== السجل المجمع للكونسول ===\n", tostring(game.PlaceId), tostring(game.GameId), tostring(game.Name))
    
    for _, log in ipairs(logsDatabase) do
        consoleSummary = consoleSummary .. string.format("[%s] %s (%s) | %s | المرسل: %s | المسار: %s\n", 
            log.Timestamp, log.Name, log.Method, log.Direction, log.Sender, log.Path)
    end

    callOpenRouter(consoleSummary)
end)

sendEditBtn.MouseButton1Click:Connect(function()
    if editInput.Text == "" then return end
    local promptText = editInput.Text
    editInput.Text = ""
    callOpenRouter(promptText)
end)

copyScriptBtn.MouseButton1Click:Connect(function()
    if latestGeneratedScript ~= "" then
        Safe.setclipboard(latestGeneratedScript)
        copyScriptBtn.Text = "تم النسخ ✓"
        copyScriptBtn.BackgroundColor3 = Color3.fromRGB(30, 160, 80)
        task.delay(1.5, function() 
            copyScriptBtn.Text = "نسخ السكربت 📋" 
            copyScriptBtn.BackgroundColor3 = Color3.fromRGB(40, 130, 70)
        end)
    else
        copyScriptBtn.Text = "لا يوجد سكربت!"
        task.delay(1.5, function() copyScriptBtn.Text = "نسخ السكربت 📋" end)
    end
end)

execAiBtn.MouseButton1Click:Connect(function()
    if latestGeneratedScript ~= "" then
        pcall(function()
            local fn = loadstring(latestGeneratedScript)
            if fn then fn() end
        end)
    end
end)

local function setupRemoteListener(obj)
    if obj:IsA("RemoteEvent") then
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
                        Count = 1
                    })
                end)
            end)
        end)
    end
end

for _, obj in ipairs(game:GetDescendants()) do
    setupRemoteListener(obj)
end

game.DescendantAdded:Connect(function(obj)
    setupRemoteListener(obj)
end)

-- المتغيرات العامة للأزرار
local rapidEnabled = false
local hitboxEnabled, deadlyEnabled, noclipEnabled, invisibleEnabled, ghostEnabled, godModeEnabled, espEnabled = false, false, false, false, false, false, false
local hitboxSize = 20

pcall(function()
    local mt = Safe.getrawmetatable(game)
    if mt then
        local oldNamecall = mt.__namecall
        Safe.setreadonly(mt, false)

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
                        Count = 1
                    })
                end)
            end
            
            if rapidEnabled and not Safe.checkcaller() and method == "FireServer" and (sName and rName == "RequestActionSync" or self.Name == "RequestActionSync") then
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
    end
end)

sizeInput.FocusLost:Connect(function()
    local num = tonumber(sizeInput.Text)
    if num then hitboxSize = math.clamp(num, 2, 200); sizeInput.Text = tostring(hitboxSize) end
end)

-- 💡 تم تصحيح دالة الأزرار لتقوم بتحديث المتغيرات العامة (Global) بشكل مباشر وصحيح
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
        elseif btn == espBtn then espEnabled = not espEnabled; currentState = espEnabled end
        
        btn.BackgroundColor3 = currentState and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(40, 40, 45)
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
                local hl = Instance.new("Highlight")
                hl.Name = "RE_HL"
                hl.FillColor = Color3.fromRGB(255, 0, 0)
                hl.FillTransparency = 0.5
                hl.Parent = player.Character
            end
        end
    else
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Character and player.Character:FindFirstChild("RE_HL") then player.Character.RE_HL:Destroy() end
        end
    end
end)

