local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "RE_Simple_Gui"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local iconBtn = Instance.new("TextButton")
iconBtn.Size = UDim2.new(0, 45, 0, 45)
iconBtn.Position = UDim2.new(0, 15, 0, 15)
iconBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
iconBtn.BorderSizePixel = 2
iconBtn.BorderColor3 = Color3.fromRGB(255, 50, 50)
iconBtn.Text = "RE"
iconBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
iconBtn.Font = Enum.Font.Code
iconBtn.TextSize = 20
iconBtn.Parent = gui

local dragging = false
local dragStartPos, dragStartMouse
local hasDragged = false 

iconBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        hasDragged = false
        dragStartPos = iconBtn.Position
        dragStartMouse = input.Position
    end
end)

iconBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        task.delay(0.1, function() hasDragged = false end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartMouse
        if delta.Magnitude > 5 then hasDragged = true end
        
        local newPos = UDim2.new(
            dragStartPos.X.Scale,
            dragStartPos.X.Offset + delta.X,
            dragStartPos.Y.Scale,
            dragStartPos.Y.Offset + delta.Y
        )
        iconBtn.Position = newPos
    end
end)

local menuFrame = Instance.new("Frame")
menuFrame.Size = UDim2.new(0, 200, 0, 200)
menuFrame.Position = UDim2.new(0, 70, 0, 15)
menuFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
menuFrame.BorderSizePixel = 2
menuFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
menuFrame.Visible = false
menuFrame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
title.BorderSizePixel = 0
title.Text = "RE:  رضا سكربت تحالف المناويج"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.Code
title.TextSize = 16
title.Parent = menuFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
closeBtn.Font = Enum.Font.Code
closeBtn.TextSize = 16
closeBtn.Parent = menuFrame

local hitboxBtn = Instance.new("TextButton")
hitboxBtn.Size = UDim2.new(0.9, 0, 0, 30)
hitboxBtn.Position = UDim2.new(0.05, 0, 0, 40)
hitboxBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
hitboxBtn.BorderSizePixel = 1
hitboxBtn.BorderColor3 = Color3.fromRGB(100, 100, 100)
hitboxBtn.Text = "Hitbox: OFF"
hitboxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hitboxBtn.Font = Enum.Font.Code
hitboxBtn.TextSize = 14
hitboxBtn.Parent = menuFrame

local sizeInput = Instance.new("TextBox")
sizeInput.Size = UDim2.new(0.9, 0, 0, 30)
sizeInput.Position = UDim2.new(0.05, 0, 0, 80)
sizeInput.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
sizeInput.BorderSizePixel = 1
sizeInput.BorderColor3 = Color3.fromRGB(100, 100, 100)
sizeInput.Text = "20"
sizeInput.PlaceholderText = "Hitbox Size"
sizeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
sizeInput.Font = Enum.Font.Code
sizeInput.TextSize = 14
sizeInput.ClearTextOnFocus = false
sizeInput.Parent = menuFrame

local deadlyBtn = Instance.new("TextButton")
deadlyBtn.Size = UDim2.new(0.9, 0, 0, 30)
deadlyBtn.Position = UDim2.new(0.05, 0, 0, 120)
deadlyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
deadlyBtn.BorderSizePixel = 1
deadlyBtn.BorderColor3 = Color3.fromRGB(100, 100, 100)
deadlyBtn.Text = "Deadly Bullet: OFF"
deadlyBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
deadlyBtn.Font = Enum.Font.Code
deadlyBtn.TextSize = 14
deadlyBtn.Parent = menuFrame

local noclipBtn = Instance.new("TextButton")
noclipBtn.Size = UDim2.new(0.9, 0, 0, 30)
noclipBtn.Position = UDim2.new(0.05, 0, 0, 160)
noclipBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
noclipBtn.BorderSizePixel = 1
noclipBtn.BorderColor3 = Color3.fromRGB(100, 100, 100)
noclipBtn.Text = "Noclip: OFF"
noclipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
noclipBtn.Font = Enum.Font.Code
noclipBtn.TextSize = 14
noclipBtn.Parent = menuFrame

iconBtn.MouseButton1Click:Connect(function()
    if not hasDragged then
        menuFrame.Visible = not menuFrame.Visible
        if menuFrame.Visible then
            menuFrame.Position = UDim2.new(0, iconBtn.Position.X.Offset + 60, 0, iconBtn.Position.Y.Offset)
        end
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    menuFrame.Visible = false
end)

local hitboxSize = 20
local hitboxEnabled = false
local deadlyEnabled = false
local noclipEnabled = false

sizeInput.FocusLost:Connect(function()
    local num = tonumber(sizeInput.Text)
    if num then
        hitboxSize = math.clamp(num, 2, 200)
        sizeInput.Text = tostring(hitboxSize)
    else
        sizeInput.Text = tostring(hitboxSize)
    end
end)

local function enforceFeatures()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Massless = true
                hrp.CanCollide = false
                
                if deadlyEnabled then
                    hrp.Size = Vector3.new(6, 6, 6) 
                    hrp.Transparency = 1
                    hrp.CFrame = Camera.CFrame * CFrame.new(0, 0, -12) 
                elseif hitboxEnabled then
                    if hrp.Size.X ~= hitboxSize then
                        hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                        hrp.Transparency = 0.7
                        hrp.BrickColor = BrickColor.new("White")
                        hrp.Material = Enum.Material.SmoothPlastic
                    end
                else
                    if hrp.Size.X ~= 2 then
                        hrp.Size = Vector3.new(2, 2, 1)
                        hrp.Transparency = 1
                    end
                end
            end
        end
    end
    
    if noclipEnabled and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end

local function toggleHitbox()
    hitboxEnabled = not hitboxEnabled
    if hitboxEnabled then
        hitboxBtn.Text = "Hitbox: ON"
        hitboxBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        deadlyEnabled = false
        deadlyBtn.Text = "Deadly Bullet: OFF"
        deadlyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        deadlyBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
    else
        hitboxBtn.Text = "Hitbox: OFF"
        hitboxBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    end
end

local function toggleDeadly()
    deadlyEnabled = not deadlyEnabled
    if deadlyEnabled then
        deadlyBtn.Text = "Deadly Bullet: ON"
        deadlyBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        deadlyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        hitboxEnabled = false
        hitboxBtn.Text = "Hitbox: OFF"
        hitboxBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    else
        deadlyBtn.Text = "Deadly Bullet: OFF"
        deadlyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        deadlyBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
    end
end

local function toggleNoclip()
    noclipEnabled = not noclipEnabled
    if noclipEnabled then
        noclipBtn.Text = "Noclip: ON"
        noclipBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    else
        noclipBtn.Text = "Noclip: OFF"
        noclipBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    end
end

hitboxBtn.MouseButton1Click:Connect(toggleHitbox)
deadlyBtn.MouseButton1Click:Connect(toggleDeadly)
noclipBtn.MouseButton1Click:Connect(toggleNoclip)

RunService.RenderStepped:Connect(enforceFeatures)
