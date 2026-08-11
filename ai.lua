local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

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

pcall(function()
    if gethui then
        gui.Parent = gethui()
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
local openAIBtn = createButton(toolbarFrame, 430, 0, 85, 28, "AI 🤖")
openAIBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 180)
local changeModelBtn = createButton(toolbarFrame, 520, 0, 85, 28, "النموذج 🔧")
changeModelBtn.BackgroundColor3 = Color3.fromRGB(100, 80, 30)

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
                    goto continue
                end
            end
            ::continue::
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
    if activeTreeData ~= "" then pcall(function() setclipboard(activeTreeData) end) end
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
    
    if setclipboard then
        pcall(function() setclipboard(allDataText) end)
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

local rapidEnabled = false

local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    
    if spyRecording and not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
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
    
    if rapidEnabled and not checkcaller() and method == "FireServer" and self.Name == "RequestActionSync" then
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
setreadonly(mt, true)

local hitboxEnabled, deadlyEnabled, noclipEnabled, invisibleEnabled, ghostEnabled, godModeEnabled, espEnabled = false, false, false, false, false, false, false
local hitboxSize = 20

sizeInput.FocusLost:Connect(function()
    local num = tonumber(sizeInput.Text)
    if num then hitboxSize = math.clamp(num, 2, 200); sizeInput.Text = tostring(hitboxSize) end
end)

local function toggleBtn(btn, stateVar)
    btn.MouseButton1Click:Connect(function()
        if btn == rapidBtn then rapidEnabled = not rapidEnabled stateVar = rapidEnabled
        elseif btn == hitboxBtn then hitboxEnabled = not hitboxEnabled stateVar = hitboxEnabled
        elseif btn == deadlyBtn then deadlyEnabled = not deadlyEnabled stateVar = deadlyEnabled
        elseif btn == noclipBtn then noclipEnabled = not noclipEnabled stateVar = noclipEnabled
        elseif btn == invisibleBtn then invisibleEnabled = not invisibleEnabled stateVar = invisibleEnabled
        elseif btn == ghostBtn then ghostEnabled = not ghostEnabled stateVar = ghostEnabled
        elseif btn == godBtn then godModeEnabled = not godModeEnabled stateVar = godModeEnabled
        elseif btn == espBtn then espEnabled = not espEnabled stateVar = espEnabled end
        
        btn.BackgroundColor3 = stateVar and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(40, 40, 45)
    end)
end

toggleBtn(hitboxBtn)
toggleBtn(deadlyBtn)
toggleBtn(rapidBtn)
toggleBtn(noclipBtn)
toggleBtn(invisibleBtn)
toggleBtn(ghostBtn)
toggleBtn(godBtn)
toggleBtn(espBtn)

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

local function buildConsoleText()
    if #logsDatabase == 0 then
        return "لا توجد ريموتات مسجلة - فعّل زر التسجيل في Inspector وادخل اللعبة ثم ارمِ بالسلاح واجمع أكبر عدد من الريموتات"
    end
    
    local out = "=== Roblox Remote Console Log ===\n"
    out = out .. "Game: " .. game.Name .. " | PlaceId: " .. tostring(game.PlaceId) .. "\n"
    out = out .. "Total remotes captured: " .. #logsDatabase .. "\n\n"
    
    local seen = {}
    for _, log in ipairs(logsDatabase) do
        local key = log.Name .. "|" .. log.Method .. "|" .. log.Direction
        if not seen[key] then
            seen[key] = true
            out = out .. string.format("[%s] %s (%s) | %s | Path: %s | Sender: %s | x%d\n", 
                log.Timestamp, log.Name, log.Method, log.Direction, log.Path, log.Sender, log.Count)
            if type(log.Args) == "table" then
                local function writeArgs(data, indent)
                    if type(data) ~= "table" then
                        out = out .. indent .. "args: " .. tostring(data) .. "\n"
                        return
                    end
                    for k, v in pairs(data) do
                        if type(v) == "table" then
                            out = out .. indent .. "[" .. tostring(k) .. "] Table:\n"
                            writeArgs(v, indent .. "    ")
                        else
                            out = out .. indent .. tostring(k) .. ": " .. tostring(v) .. "\n"
                        end
                    end
                end
                writeArgs(log.Args, "    ")
            end
            out = out .. "---\n"
        end
    end
    return out
end

local AI_SETTINGS = {
    API_KEY = "",
    KEY_FILE = "re_ai_key.txt",
    MODEL = "google/gemma-3-27b-it:free",
    ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"
}

pcall(function()
    if readfile and isfile and isfile(AI_SETTINGS.KEY_FILE) then
        local k = readfile(AI_SETTINGS.KEY_FILE):match("%S+")
        if k then AI_SETTINGS.API_KEY = k end
    end
end)

local function saveApiKey(k)
    AI_SETTINGS.API_KEY = k
    pcall(function()
        if writefile then writefile(AI_SETTINGS.KEY_FILE, k) end
    end)
end

local aiFrame = Instance.new("Frame")
aiFrame.Size = UDim2.new(0, 620, 0, 360)
aiFrame.Position = UDim2.new(0, 1030, 0, 15)
aiFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
aiFrame.BorderSizePixel = 1
aiFrame.BorderColor3 = Color3.fromRGB(150, 100, 255)
aiFrame.Visible = false
aiFrame.Active = false
aiFrame.Parent = gui

local aiTitle = Instance.new("TextLabel")
aiTitle.Size = UDim2.new(1, -30, 0, 28)
aiTitle.BackgroundColor3 = Color3.fromRGB(35, 28, 45)
aiTitle.BorderSizePixel = 0
aiTitle.Text = "  [RE] AI Script Generator - Model: " .. AI_SETTINGS.MODEL
aiTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
aiTitle.Font = Enum.Font.Code
aiTitle.TextSize = 12
aiTitle.TextXAlignment = Enum.TextXAlignment.Left
aiTitle.Active = true
aiTitle.Parent = aiFrame
makeDraggable(aiTitle, aiFrame)

local aiCloseBtn = Instance.new("TextButton")
aiCloseBtn.Size = UDim2.new(0, 30, 0, 28)
aiCloseBtn.Position = UDim2.new(1, -30, 0, 0)
aiCloseBtn.BackgroundTransparency = 1
aiCloseBtn.Text = "X"
aiCloseBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
aiCloseBtn.Font = Enum.Font.Code
aiCloseBtn.TextSize = 14
aiCloseBtn.Parent = aiFrame

local aiStatus = Instance.new("TextLabel")
aiStatus.Size = UDim2.new(1, -16, 0, 24)
aiStatus.Position = UDim2.new(0, 8, 0, 32)
aiStatus.BackgroundTransparency = 1
aiStatus.Text = "جاهز - اضغط زر التوليد لتحليل الكونسول وتوليد سكربت قوي"
aiStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
aiStatus.Font = Enum.Font.Code
aiStatus.TextSize = 11
aiStatus.TextXAlignment = Enum.TextXAlignment.Left
aiStatus.Parent = aiFrame

local aiGenerateBtn = Instance.new("TextButton")
aiGenerateBtn.Size = UDim2.new(0, 250, 0, 34)
aiGenerateBtn.Position = UDim2.new(0, 8, 0, 58)
aiGenerateBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 170)
aiGenerateBtn.Text = "توليد سكربت من الكونسول ⚡"
aiGenerateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
aiGenerateBtn.Font = Enum.Font.Code
aiGenerateBtn.TextSize = 13
aiGenerateBtn.Parent = aiFrame

local aiCopyBtn = Instance.new("TextButton")
aiCopyBtn.Size = UDim2.new(0, 120, 0, 30)
aiCopyBtn.Position = UDim2.new(0, 266, 0, 60)
aiCopyBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
aiCopyBtn.Text = "نسخ الكامل"
aiCopyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
aiCopyBtn.Font = Enum.Font.Code
aiCopyBtn.TextSize = 12
aiCopyBtn.Parent = aiFrame

local aiEditBtn = Instance.new("TextButton")
aiEditBtn.Size = UDim2.new(0, 120, 0, 30)
aiEditBtn.Position = UDim2.new(0, 394, 0, 60)
aiEditBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 30)
aiEditBtn.Text = "تعديل 📝"
aiEditBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
aiEditBtn.Font = Enum.Font.Code
aiEditBtn.TextSize = 12
aiEditBtn.Parent = aiFrame

local aiRunBtn = Instance.new("TextButton")
aiRunBtn.Size = UDim2.new(0, 120, 0, 30)
aiRunBtn.Position = UDim2.new(0, 490, 0, 60)
aiRunBtn.BackgroundColor3 = Color3.fromRGB(130, 40, 40)
aiRunBtn.Text = "تنفيذ ✓"
aiRunBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
aiRunBtn.Font = Enum.Font.Code
aiRunBtn.TextSize = 12
aiRunBtn.Parent = aiFrame

local aiScriptScroll = Instance.new("ScrollingFrame")
aiScriptScroll.Size = UDim2.new(1, -16, 1, -150)
aiScriptScroll.Position = UDim2.new(0, 8, 0, 102)
aiScriptScroll.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
aiScriptScroll.BorderSizePixel = 1
aiScriptScroll.ScrollBarThickness = 4
aiScriptScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
aiScriptScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
aiScriptScroll.Parent = aiFrame

local aiScriptLayout = Instance.new("UIListLayout")
aiScriptLayout.Parent = aiScriptScroll
aiScriptLayout.SortOrder = Enum.SortOrder.LayoutOrder

local aiEditScroll = Instance.new("ScrollingFrame")
aiEditScroll.Size = UDim2.new(1, -16, 0, 70)
aiEditScroll.Position = UDim2.new(0, 8, 1, -80)
aiEditScroll.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
aiEditScroll.BorderSizePixel = 1
aiEditScroll.Visible = false
aiEditScroll.Parent = aiFrame

local aiEditLayout = Instance.new("UIListLayout")
aiEditLayout.Padding = UDim.new(0, 3)
aiEditLayout.Parent = aiEditScroll

local aiEditInput = Instance.new("TextBox")
aiEditInput.Size = UDim2.new(1, -90, 0, 64)
aiEditInput.Position = UDim2.new(0, 3, 0, 3)
aiEditInput.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
aiEditInput.PlaceholderText = "اكتب التعديل هنا... (مثال: ضيف ESP للخصوم، سوّيلهم سبيد أعلى، خلّص الهيتبوكس أحمر...)"
aiEditInput.Text = ""
aiEditInput.TextColor3 = Color3.fromRGB(255, 255, 255)
aiEditInput.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
aiEditInput.Font = Enum.Font.Code
aiEditInput.TextSize = 12
aiEditInput.TextXAlignment = Enum.TextXAlignment.Left
aiEditInput.TextYAlignment = Enum.TextYAlignment.Top
aiEditInput.Parent = aiEditScroll

local aiEditSendBtn = Instance.new("TextButton")
aiEditSendBtn.Size = UDim2.new(0, 84, 0, 64)
aiEditSendBtn.Position = UDim2.new(1, -87, 0, 3)
aiEditSendBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 170)
aiEditSendBtn.Text = "أرسل\nالتعديل"
aiEditSendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
aiEditSendBtn.Font = Enum.Font.Code
aiEditSendBtn.TextSize = 12
aiEditSendBtn.Parent = aiEditScroll

aiCloseBtn.MouseButton1Click:Connect(function() aiFrame.Visible = false end)

openAIBtn.MouseButton1Click:Connect(function()
    aiFrame.Visible = not aiFrame.Visible
    if not aiFrame.Visible then aiEditScroll.Visible = false end
end)

local modelFrame = Instance.new("Frame")
modelFrame.Size = UDim2.new(0, 340, 0, 150)
modelFrame.Position = UDim2.new(0, 1030, 0, 385)
modelFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
modelFrame.BorderSizePixel = 1
modelFrame.BorderColor3 = Color3.fromRGB(200, 160, 50)
modelFrame.Visible = false
modelFrame.Active = false
modelFrame.Parent = gui

local modelTitle = Instance.new("TextLabel")
modelTitle.Size = UDim2.new(1, -30, 0, 24)
modelTitle.BackgroundColor3 = Color3.fromRGB(40, 35, 30)
modelTitle.BorderSizePixel = 0
modelTitle.Text = "  تغيير نموذج الذكاء الاصطناعي"
modelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
modelTitle.Font = Enum.Font.Code
modelTitle.TextSize = 12
modelTitle.TextXAlignment = Enum.TextXAlignment.Left
modelTitle.Active = true
modelTitle.Parent = modelFrame
makeDraggable(modelTitle, modelFrame)

local modelCloseBtn = Instance.new("TextButton")
modelCloseBtn.Size = UDim2.new(0, 30, 0, 24)
modelCloseBtn.Position = UDim2.new(1, -30, 0, 0)
modelCloseBtn.BackgroundTransparency = 1
modelCloseBtn.Text = "X"
modelCloseBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
modelCloseBtn.Font = Enum.Font.Code
modelCloseBtn.TextSize = 12
modelCloseBtn.Parent = modelFrame

local modelHint = Instance.new("TextLabel")
modelHint.Size = UDim2.new(1, -10, 0, 34)
modelHint.Position = UDim2.new(0, 5, 0, 26)
modelHint.BackgroundTransparency = 1
modelHint.Text = "الصق اسم النموذج من OpenRouter:\nمثال: qwen/qwen3-coder:free | anthropic/claude-3.5-haiku"
modelHint.TextColor3 = Color3.fromRGB(200, 200, 200)
modelHint.Font = Enum.Font.Code
modelHint.TextSize = 10
modelHint.TextXAlignment = Enum.TextXAlignment.Left
modelHint.TextWrapped = true
modelHint.Parent = modelFrame

local apiKeyInput = Instance.new("TextBox")
apiKeyInput.Size = UDim2.new(1, -10, 0, 24)
apiKeyInput.Position = UDim2.new(0, 5, 0, 62)
apiKeyInput.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
apiKeyInput.PlaceholderText = "API Key: sk-or-v1-... (يُحفظ تلقائياً)"
apiKeyInput.Text = ""
apiKeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
apiKeyInput.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
apiKeyInput.Font = Enum.Font.Code
apiKeyInput.TextSize = 11
apiKeyInput.Parent = modelFrame

local modelInput = Instance.new("TextBox")
modelInput.Size = UDim2.new(1, -10, 0, 24)
modelInput.Position = UDim2.new(0, 5, 0, 90)
modelInput.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
modelInput.PlaceholderText = "google/gemma-3-27b-it:free"
modelInput.Text = ""
modelInput.TextColor3 = Color3.fromRGB(255, 255, 255)
modelInput.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
modelInput.Font = Enum.Font.Code
modelInput.TextSize = 11
modelInput.Parent = modelFrame

local modelApplyBtn = Instance.new("TextButton")
modelApplyBtn.Size = UDim2.new(0, 100, 0, 24)
modelApplyBtn.Position = UDim2.new(0, 5, 0, 118)
modelApplyBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
modelApplyBtn.Text = "تطبيق"
modelApplyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
modelApplyBtn.Font = Enum.Font.Code
modelApplyBtn.TextSize = 11
modelApplyBtn.Parent = modelFrame

modelCloseBtn.MouseButton1Click:Connect(function() modelFrame.Visible = false end)
changeModelBtn.MouseButton1Click:Connect(function()
    modelFrame.Visible = not modelFrame.Visible
    modelInput.Text = AI_SETTINGS.MODEL
    apiKeyInput.Text = ""
end)

apiKeyInput.FocusLost:Connect(function(enter)
    if enter then
        local k = apiKeyInput.Text:match("^%s*(.-)%s*$")
        if k and k ~= "" then
            saveApiKey(k)
            aiStatus.Text = "تم حفظ مفتاح API ✓"
            apiKeyInput.Text = ""
        end
    end
end)

modelApplyBtn.MouseButton1Click:Connect(function()
    local k = apiKeyInput.Text:match("^%s*(.-)%s*$")
    if k and k ~= "" then saveApiKey(k) end
    apiKeyInput.Text = ""
    local m = modelInput.Text:match("^%s*(.-)%s*$")
    if m and m ~= "" then
        AI_SETTINGS.MODEL = m
        aiTitle.Text = "  [RE] AI Script Generator - Model: " .. AI_SETTINGS.MODEL
        aiStatus.Text = "تم تغيير النموذج إلى: " .. m
        modelFrame.Visible = false
    elseif AI_SETTINGS.API_KEY ~= "" then
        modelFrame.Visible = false
    end
end)

local aiHistory = {}

local AI_SYSTEM_PROMPT = [[أنت أقوى مبرمج سكربتات Roblox Lua في العالم. مهمتك توليد سكربت Lua (LocalScript) قوي جدًا واسطوري من تحليل سجل ريموتات الشبكة (Remote Console Log).

القواعد:
1. تنبيه مهم: الريموتات في السجل ليست فقط ريموتات أسلحة — تشمل كل أنواع شبكة اللعبة: ريموتات الضرر، القتل، الحركة، sprint، التحميل، الأدوات، المال/العملة، الـ spawn، المهارات وغيرها. حلل بدقة كل RemoteEvent (اسمه، مساره، اتجاهه، وسائطه) وافهم وظيفة كل واحد واستفد منه حسب نوعه.
2. أنشئ سكربت كامل مع واجهة GUI بسيطة (ScreenGui) وأزرار تفعيلات قوية تستند مباشرة إلى الريموتات الموجودة - السكربت يجب أن يستغل الريموتات الحية في اللعبة عبر FireServer بوسائط صحيحة مستخرجة من الريموتات نفسها (مثل hitPosition, origin, direction, hitInstance, hitHumanoid).
3. ضمّن هذه التفعيلات قدر الإمكان حسب الريموتات المتوفرة:
   - Aimbot/Magic Bullet: يعدل جدول hitPosition إلى أقرب رأس على الشاشة ويضبط origin وdirection تلقائيًا (IsHeadshot=true إن وجد)
   - Rapid Fire / Auto Shoot: يخاطب Remote الرمي (اسمه من الكونسول) تلقائيًا كل فريم بسرعة قصوى مع ملء المخزون وإيقاف أنيميشن التحميل
   - No Cooldown / Inf Ammo: يعدّل ValueBase وAttributes للاسلحة
   - God Mode / Infinite Health / Regen
   - Invisible / NoClip / Anti-Stun / Anti-Knockback
   - Speed / Jump Power
   - ESP (Highlight أو صندوق BillboardGui)
   - Kill Aura / Hitbox Extender على HumanoidRootPart الأعداء
   - Any Remote abuse found in the console: FireServer on high-value remotes repeatedly (damage, kill, spawn, currency)
4. السكربت يجب أن يكون: كامل وجاهز للتشغيل مباشرة (loadstring)، بدون أخطاء syntax، يستخدم pcall للحماية، يعمل في أي executor حديث (Synapse X, Delta, Fluxus, Solara, Arceus X)، يستخدم gethui() أو CoreGui، وبنية GUI مدمجة داخل السكربت نفسه.
5. لا تشرح - فقط أرجع كود Lua كامل داخل بلوك ```lua ... ``` — لا تكتب أي كلام خارج البلوك.
6. تأكد أن أسماء الريموتات والمواضع مطابقة تمامًا لما في سجل الكونسول.

سجل الريموتات المرسل إليه:]]

local function callOpenRouter(messages, callback)
    if AI_SETTINGS.API_KEY == "" then
        callback(false, "مطلوب مفتاح API - افتح تبويبة 'النموذج 🔧' والصق مفتاح OpenRouter الخاص بك (sk-or-v1-...)")
        return
    end
    task.spawn(function()
        local ok, result = pcall(function()
            return HttpService:JSONEncode({
                model = AI_SETTINGS.MODEL,
                messages = messages,
                max_tokens = 8000
            })
        end)
        if not ok then
            callback(false, "فشل تشفير الطلب: " .. tostring(result))
            return
        end
        
        local resp = nil
        if http_request then
            local res = http_request({
                Url = AI_SETTINGS.ENDPOINT,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Authorization"] = "Bearer " .. AI_SETTINGS.API_KEY,
                    ["HTTP-Referer"] = "https://openrouter.ai",
                    ["X-Title"] = "RE Panel AI"
                },
                Body = result
            })
            resp = res and res.Body
        else
            local web = loadstring(game:HttpGet("https://raw.githubusercontent.com/ai-district/web/main/main.lua"))()
            resp = web.request(AI_SETTINGS.ENDPOINT, "POST", {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "Bearer " .. AI_SETTINGS.API_KEY
            }, result)
            resp = resp and resp.body
        end
        
        if not resp then
            callback(false, "فشل الاتصال بـ OpenRouter - تحقق من الإنترنت أو جرب executor آخر")
            return
        end
        
        local data = HttpService:JSONDecode(resp)
        if data and data.choices and #data.choices > 0 then
            local content = data.choices[1].message.content
            local code = content:match("```lua%s*(.-)%s*```") or content:match("```\n?(.-)\n?```") or content
            callback(true, code, content)
        else
            callback(false, data and data.error and (data.error.message or tostring(data.error)) or "رد فارغ من النموذج")
        end
    end)
end

local function clearAiOutput()
    for _, c in ipairs(aiScriptScroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
end

local function showAiOutput(text)
    clearAiOutput()
    local lastLabel = nil
    for line in text:gmatch("[^\r\n]+") do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -10, 0, 15)
        lbl.BackgroundTransparency = 1
        lbl.Text = line
        lbl.TextColor3 = Color3.fromRGB(180, 255, 180)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextWrapped = true
        lbl.Parent = aiScriptScroll
        lastLabel = lbl
    end
    if not lastLabel then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -10, 0, 15)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(180, 255, 180)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 10
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = aiScriptScroll
    end
end

local lastGeneratedScript = ""
local lastFullResponse = ""
local aiWorking = false

local function runGeneration(messages, editMode)
    if aiWorking then return end
    aiWorking = true
    aiGenerateBtn.Text = "جارٍ التوليد..."
    aiGenerateBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    aiCopyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    aiEditBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    aiStatus.Text = editMode and "جارٍ تطبيق التعديل..." or "جارٍ تحليل الكونسول وإرساله للذكاء الاصطناعي..."
    clearAiOutput()
    
    callOpenRouter(messages, function(success, code, full)
        aiWorking = false
        aiGenerateBtn.Text = "توليد سكربت من الكونسول ⚡"
        aiGenerateBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 170)
        aiCopyBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
        aiEditBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 30)
        
        if success then
            lastGeneratedScript = code
            lastFullResponse = full
            showAiOutput(code)
            aiStatus.Text = "تم التوليد بنجاح ✓ - اضغط نسخ الكامل ثم تنفيذ"
            aiEditScroll.Visible = false
        else
            aiStatus.Text = "خطأ: " .. tostring(code)
            showAiOutput("ERROR: " .. tostring(code))
        end
    end)
end

aiGenerateBtn.MouseButton1Click:Connect(function()
    if #logsDatabase == 0 then
        aiStatus.Text = "لا توجد ريموتات! فعّل التسجيل في Inspector وارمِ بالسلاح أولاً"
        return
    end
    
    local consoleText = buildConsoleText()
    local userMsg = {role = "user", content = consoleText}
    
    aiHistory = {
        {role = "system", content = AI_SYSTEM_PROMPT .. "\n" .. consoleText},
        userMsg
    }
    
    runGeneration(aiHistory, false)
end)

aiCopyBtn.MouseButton1Click:Connect(function()
    if lastGeneratedScript == "" then
        aiStatus.Text = "لا يوجد سكربت لنسخه - ولّد أولاً"
        return
    end
    if setclipboard then
        pcall(function() setclipboard(lastGeneratedScript) end)
        aiStatus.Text = "تم نسخ السكربت الكامل للحافظة ✓"
        aiCopyBtn.Text = "تم النسخ!"
        task.delay(1.5, function() aiCopyBtn.Text = "نسخ الكامل" end)
    else
        aiStatus.Text = "setclipboard غير مدعوم في هذا الـ executor"
    end
end)

aiEditBtn.MouseButton1Click:Connect(function()
    if lastGeneratedScript == "" then
        aiStatus.Text = "لا يوجد سكربت - ولّد أولاً ثم عدّل"
        return
    end
    aiEditScroll.Visible = not aiEditScroll.Visible
    if aiEditScroll.Visible then
        aiEditInput:CaptureFocus()
    end
end)

aiEditSendBtn.MouseButton1Click:Connect(function()
    local edit = aiEditInput.Text:match("^%s*(.-)%s*$")
    if not edit or edit == "" then return end
    
    aiEditInput.Text = ""
    aiEditScroll.Visible = false
    
    table.insert(aiHistory, {role = "user", content = "التعديل المطلوب: " .. edit .. "\n\nأرسل السكربت الكامل المعدل داخل بلوك ```lua ... ``` بدون أي كلام خارجه."})
    
    runGeneration(aiHistory, true)
end)

aiRunBtn.MouseButton1Click:Connect(function()
    if lastGeneratedScript == "" then
        aiStatus.Text = "لا يوجد سكربت لتنفيذه"
        return
    end
    local ok, err = pcall(function() loadstring(lastGeneratedScript)() end)
    if ok then
        aiStatus.Text = "تم تنفيذ السكربت ✓"
    else
        aiStatus.Text = "فشل التنفيذ: " .. tostring(err)
    end
end)

