local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

local flying = false
local noclipEnabled = false
local liftSpeed = 50
local walkSpeed = 16
local currentBodyVelocity = nil
local up = false
local down = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RezaFlightControlGUI"
screenGui.ResetOnSpawn = false

local success = pcall(function() screenGui.Parent = CoreGui end)
if not success then screenGui.Parent = player:WaitForChild("PlayerGui") end

local toggleIcon = Instance.new("TextButton")
toggleIcon.Name = "ToggleIcon"
toggleIcon.Size = UDim2.new(0, 45, 0, 45)
toggleIcon.Position = UDim2.new(0, 20, 0.5, -22)
toggleIcon.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
toggleIcon.Text = "RE"
toggleIcon.TextColor3 = Color3.fromRGB(255, 60, 60)
toggleIcon.Font = Enum.Font.GothamBlack
toggleIcon.TextSize = 20
toggleIcon.Active = true
toggleIcon.Draggable = true
toggleIcon.Parent = screenGui

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(1, 0)
iconCorner.Parent = toggleIcon

local iconStroke = Instance.new("UIStroke")
iconStroke.Color = Color3.fromRGB(255, 60, 60)
iconStroke.Thickness = 2
iconStroke.Parent = toggleIcon

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 280, 0, 240)
mainFrame.Position = UDim2.new(0.5, -140, 0.5, -120)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = mainFrame

local uiStroke = Instance.new("UIStroke")
uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
uiStroke.Color = Color3.fromRGB(255, 60, 60)
uiStroke.Thickness = 2
uiStroke.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Text = "REZA SYSTEM"
titleLabel.Size = UDim2.new(1, 0, 0, 25)
titleLabel.Position = UDim2.new(0, 0, 0, 5)
titleLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.BackgroundTransparency = 1
titleLabel.Parent = mainFrame

local titleLine = Instance.new("Frame")
titleLine.Size = UDim2.new(0.9, 0, 0, 1)
titleLine.Position = UDim2.new(0.05, 0, 0, 30)
titleLine.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
titleLine.BorderSizePixel = 0
titleLine.Parent = mainFrame

local function createButton(name, position, size, text)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = size
    button.Position = position
    button.Text = text
    button.TextColor3 = Color3.fromRGB(220, 220, 220)
    button.TextSize = 12
    button.Font = Enum.Font.GothamBold
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    button.AutoButtonColor = true
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = button
    
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 75)}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 55)}):Play()
    end)
    
    button.Parent = mainFrame
    return button
end

local function createInputDisplay(name, position, value)
    local box = Instance.new("TextBox")
    box.Name = name
    box.Size = UDim2.new(0, 50, 0, 30)
    box.Position = position
    box.Text = tostring(value)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.TextSize = 14
    box.Font = Enum.Font.GothamBold
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    box.ClearTextOnFocus = false
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = box
    
    box.Parent = mainFrame
    return box
end

local toggleFlyButton = createButton("ToggleFlyButton", UDim2.new(0, 15, 0, 40), UDim2.new(0, 90, 0, 30), "تفعيل الطيران")
local upButton = createButton("UpButton", UDim2.new(0, 15, 0, 75), UDim2.new(0, 90, 0, 30), "صعود (تعليق)")
local downButton = createButton("DownButton", UDim2.new(0, 15, 0, 110), UDim2.new(0, 90, 0, 30), "نزول (تعليق)")

local increaseFlyButton = createButton("IncFly", UDim2.new(0, 120, 0, 60), UDim2.new(0, 30, 0, 30), "+")
local flySpeedDisplay = createInputDisplay("FlyDisp", UDim2.new(0, 155, 0, 60), liftSpeed)
local decreaseFlyButton = createButton("DecFly", UDim2.new(0, 210, 0, 60), UDim2.new(0, 30, 0, 30), "-")
local flyTitle = Instance.new("TextLabel", mainFrame)
flyTitle.Text = "سرعة الطيران"
flyTitle.Size = UDim2.new(0, 120, 0, 15)
flyTitle.Position = UDim2.new(0, 120, 0, 40)
flyTitle.BackgroundTransparency = 1
flyTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
flyTitle.Font = Enum.Font.Gotham

local increaseWalkButton = createButton("IncWalk", UDim2.new(0, 120, 0, 115), UDim2.new(0, 30, 0, 30), "+")
local walkSpeedDisplay = createInputDisplay("WalkDisp", UDim2.new(0, 155, 0, 115), walkSpeed)
local decreaseWalkButton = createButton("DecWalk", UDim2.new(0, 210, 0, 115), UDim2.new(0, 30, 0, 30), "-")
local walkTitle = Instance.new("TextLabel", mainFrame)
walkTitle.Text = "سرعة المشي"
walkTitle.Size = UDim2.new(0, 120, 0, 15)
walkTitle.Position = UDim2.new(0, 120, 0, 95)
walkTitle.BackgroundTransparency = 1
walkTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
walkTitle.Font = Enum.Font.Gotham

local noclipButton = Instance.new("TextButton")
noclipButton.Name = "NoclipButton"
noclipButton.Size = UDim2.new(0, 250, 0, 30)
noclipButton.Position = UDim2.new(0.5, -125, 0, 155)
noclipButton.Text = "اختراق الجدران"
noclipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
noclipButton.TextSize = 14
noclipButton.Font = Enum.Font.GothamBlack
noclipButton.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
noclipButton.AutoButtonColor = false
noclipButton.ClipsDescendants = true
noclipButton.Parent = mainFrame

local noclipCorner = Instance.new("UICorner")
noclipCorner.CornerRadius = UDim.new(0, 6)
noclipCorner.Parent = noclipButton

local shine = Instance.new("Frame")
shine.Size = UDim2.new(0, 20, 2, 0)
shine.Position = UDim2.new(-0.2, 0, -0.5, 0)
shine.Rotation = 15
shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
shine.BackgroundTransparency = 0.5
shine.BorderSizePixel = 0
shine.Parent = noclipButton

task.spawn(function()
    while task.wait(2.5) do
        if not noclipButton or not noclipButton.Parent then break end
        shine.Position = UDim2.new(-0.2, 0, -0.5, 0)
        TweenService:Create(shine, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.new(1.2, 0, -0.5, 0)}):Play()
    end
end)

local resetButton = Instance.new("TextButton")
resetButton.Name = "ResetButton"
resetButton.Size = UDim2.new(0, 250, 0, 30)
resetButton.Position = UDim2.new(0.5, -125, 0, 195)
resetButton.Text = "RESET"
resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetButton.TextSize = 14
resetButton.Font = Enum.Font.GothamBlack
resetButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
resetButton.AutoButtonColor = true
resetButton.Parent = mainFrame

local resetCorner = Instance.new("UICorner")
resetCorner.CornerRadius = UDim.new(0, 6)
resetCorner.Parent = resetButton

resetButton.MouseEnter:Connect(function()
    TweenService:Create(resetButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play()
end)
resetButton.MouseLeave:Connect(function()
    TweenService:Create(resetButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(180, 40, 40)}):Play()
end)

toggleIcon.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

local function updateFlightState()
    if currentBodyVelocity then
        currentBodyVelocity:Destroy()
        currentBodyVelocity = nil
    end
    if flying and humanoidRootPart then
        currentBodyVelocity = Instance.new("BodyVelocity")
        currentBodyVelocity.Velocity = Vector3.zero
        currentBodyVelocity.MaxForce = Vector3.new(0, 1e5, 0)
        currentBodyVelocity.P = 1250
        currentBodyVelocity.Parent = humanoidRootPart
    end
end

noclipButton.MouseButton1Click:Connect(function()
    noclipEnabled = not noclipEnabled
    if noclipEnabled then
        noclipButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        noclipButton.Text = "اختراق الجدران: تشغيل"
    else
        noclipButton.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
        noclipButton.Text = "اختراق الجدران"
    end
end)

resetButton.MouseButton1Click:Connect(function()
    flying = false
    updateFlightState()
    toggleFlyButton.Text = "تفعيل الطيران"
    toggleFlyButton.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    
    noclipEnabled = false
    noclipButton.BackgroundColor3 = Color3.fromRGB(40, 100, 200)
    noclipButton.Text = "اختراق الجدران"
    
    up = false
    down = false
    
    liftSpeed = 50
    flySpeedDisplay.Text = tostring(liftSpeed)
    
    walkSpeed = 16
    walkSpeedDisplay.Text = tostring(walkSpeed)
    if humanoid then humanoid.WalkSpeed = walkSpeed end
end)

toggleFlyButton.MouseButton1Click:Connect(function()
    flying = not flying
    if flying then
        toggleFlyButton.Text = "إيقاف الطيران"
        toggleFlyButton.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
        updateFlightState()
    else
        toggleFlyButton.Text = "تفعيل الطيران"
        toggleFlyButton.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
        updateFlightState()
    end
end)

flySpeedDisplay.FocusLost:Connect(function()
    local num = tonumber(flySpeedDisplay.Text)
    if num then
        liftSpeed = num
    else
        flySpeedDisplay.Text = tostring(liftSpeed)
    end
end)

walkSpeedDisplay.FocusLost:Connect(function()
    local num = tonumber(walkSpeedDisplay.Text)
    if num then
        walkSpeed = num
        if humanoid then humanoid.WalkSpeed = walkSpeed end
    else
        walkSpeedDisplay.Text = tostring(walkSpeed)
    end
end)

increaseFlyButton.MouseButton1Click:Connect(function()
    liftSpeed = math.min(200000, liftSpeed + 10)
    flySpeedDisplay.Text = tostring(liftSpeed)
end)

decreaseFlyButton.MouseButton1Click:Connect(function()
    liftSpeed = math.max(10, liftSpeed - 10)
    flySpeedDisplay.Text = tostring(liftSpeed)
end)

increaseWalkButton.MouseButton1Click:Connect(function()
    walkSpeed = math.min(500, walkSpeed + 5)
    walkSpeedDisplay.Text = tostring(walkSpeed)
    if humanoid then humanoid.WalkSpeed = walkSpeed end
end)

decreaseWalkButton.MouseButton1Click:Connect(function()
    walkSpeed = math.max(16, walkSpeed - 5)
    walkSpeedDisplay.Text = tostring(walkSpeed)
    if humanoid then humanoid.WalkSpeed = walkSpeed end
end)

upButton.MouseButton1Down:Connect(function() up = true end)
upButton.MouseButton1Up:Connect(function() up = false end)
downButton.MouseButton1Down:Connect(function() down = true end)
downButton.MouseButton1Up:Connect(function() down = false end)

RunService.Stepped:Connect(function()
    if noclipEnabled and character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if flying and currentBodyVelocity and currentBodyVelocity.Parent then
        local liftDirection = 0
        if up then liftDirection = liftSpeed end
        if down then liftDirection = -liftSpeed end
        currentBodyVelocity.Velocity = Vector3.new(0, liftDirection, 0)
    end
end)

player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    humanoid = character:WaitForChild("Humanoid")
    humanoid.WalkSpeed = walkSpeed
    if flying then updateFlightState() end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

