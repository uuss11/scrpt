local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "RE_رضا:  تحالف المناويج"
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

local menuFrame = Instance.new("Frame")
menuFrame.Size = UDim2.new(0, 200, 0, 360)
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
title.Text = "لوحة RE"
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

local function createButton(pos, text)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, pos)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Parent = menuFrame
    return btn
end

local hitboxBtn = createButton(40, "هيتبوكس: إيقاف")
local sizeInput = Instance.new("TextBox")
sizeInput.Size = UDim2.new(0.9, 0, 0, 30)
sizeInput.Position = UDim2.new(0.05, 0, 0, 80)
sizeInput.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
sizeInput.Text = "20"
sizeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
sizeInput.Parent = menuFrame

local deadlyBtn = createButton(120, "رصاصة قاتلة: إيقاف")
local noclipBtn = createButton(160, "اختراق الجدران: إيقاف")
local invisibleBtn = createButton(200, "الاختفاء: إيقاف")
local ghostBtn = createButton(240, "وضع الشبح: إيقاف")
local godBtn = createButton(280, "الخلود: إيقاف")

local dragging, dragStartPos, dragStartMouse, hasDragged = false, nil, nil, false
local titleDragging, titleDragStartPos, titleDragStartMouse, titleHasDragged = false, nil, nil, false

iconBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        hasDragged = false
        dragStartPos = iconBtn.Position
        dragStartMouse = input.Position
    end
end)

iconBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        task.delay(0.1, function() hasDragged = false end)
    end
end)

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        titleDragging = true
        titleHasDragged = false
        titleDragStartPos = menuFrame.Position
        titleDragStartMouse = input.Position
    end
end)

title.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        titleDragging = false
        task.delay(0.1, function() titleHasDragged = false end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
       and input.UserInputType ~= Enum.UserInputType.Touch then return end
    if dragging then
        local delta = input.Position - dragStartMouse
        if delta.Magnitude > 5 then hasDragged = true end
        iconBtn.Position = UDim2.new(
            dragStartPos.X.Scale, dragStartPos.X.Offset + delta.X,
            dragStartPos.Y.Scale, dragStartPos.Y.Offset + delta.Y)
    elseif titleDragging then
        local delta = input.Position - titleDragStartMouse
        if delta.Magnitude > 5 then titleHasDragged = true end
        menuFrame.Position = UDim2.new(
            titleDragStartPos.X.Scale, titleDragStartPos.X.Offset + delta.X,
            titleDragStartPos.Y.Scale, titleDragStartPos.Y.Offset + delta.Y)
    end
end)

iconBtn.MouseButton1Click:Connect(function()
    if not hasDragged then
        menuFrame.Visible = not menuFrame.Visible
        if menuFrame.Visible then
            menuFrame.Position = UDim2.new(0, iconBtn.Position.X.Offset + 60, 0, iconBtn.Position.Y.Offset)
        end
    end
end)

closeBtn.MouseButton1Click:Connect(function() menuFrame.Visible = false end)

local hitboxSize = 20
local hitboxEnabled = false
local deadlyEnabled = false
local noclipEnabled = false
local invisibleEnabled = false
local ghostEnabled = false
local godModeEnabled = false

sizeInput.FocusLost:Connect(function()
    local num = tonumber(sizeInput.Text)
    if num then
        hitboxSize = math.clamp(num, 2, 200)
        sizeInput.Text = tostring(hitboxSize)
    end
end)

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")

    if deadlyEnabled or hitboxEnabled then
        local camCF = Camera.CFrame
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if deadlyEnabled then
                        hrp.Size = Vector3.new(6, 6, 6)
                        hrp.Transparency = 1
                        hrp.CFrame = camCF * CFrame.new(0, 0, -12)
                    elseif hitboxEnabled then
                        hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                        hrp.Transparency = 0.7
                        hrp.BrickColor = BrickColor.new("White")
                    else
                        hrp.Size = Vector3.new(2, 2, 1)
                        hrp.Transparency = 1
                    end
                end
            end
        end
    end

    if noclipEnabled then
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
            if hrp and humanoid and humanoid.Health > 0 then
                local bounds = Workspace:GetPartBoundsInBox(hrp.CFrame, hrp.Size)
                for _, wall in ipairs(bounds) do
                    local wallTop = wall.Position.Y + wall.Size.Y / 2
                    local hrpBottom = hrp.Position.Y - hrp.Size.Y / 2
                    if hrpBottom >= wallTop - 0.5 then
                        -- player is standing on this part: ground, skip
                    else
                        if wall.CanCollide and wall.Anchored and not wall:IsDescendantOf(char) then
                            wall.CanCollide = false
                        end
                    end
                end
            end
        end
    elseif char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not part.CanCollide then
                part.CanCollide = true
            end
        end
    end

    if invisibleEnabled and char then
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("BasePart") and desc ~= char:FindFirstChild("HumanoidRootPart") then
                desc.Transparency = 1
            elseif desc:IsA("Decal") or desc:IsA("Texture") then
                desc.Transparency = 1
            elseif desc:IsA("SpecialMesh") then
                desc.TextureTransparency = 1
            end
        end
    elseif char then
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc.Transparency = 0
            elseif desc:IsA("Decal") or desc:IsA("Texture") then
                desc.Transparency = 0
            elseif desc:IsA("SpecialMesh") then
                desc.TextureTransparency = 0
            end
        end
    end

    if godModeEnabled and humanoid then
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        end)
        humanoid.MaxHealth = 999999
        humanoid.Health = 999999
    end

    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = ghostEnabled end
    end
end)

hitboxBtn.MouseButton1Click:Connect(function()
    hitboxEnabled = not hitboxEnabled
    if hitboxEnabled then
        deadlyEnabled = false
        deadlyBtn.Text = "رصاصة قاتلة: إيقاف"
        deadlyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    end
    hitboxBtn.Text = hitboxEnabled and "هيتبوكس: تشغيل" or "هيتبوكس: إيقاف"
    hitboxBtn.BackgroundColor3 = hitboxEnabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(50, 50, 50)
end)

deadlyBtn.MouseButton1Click:Connect(function()
    deadlyEnabled = not deadlyEnabled
    if deadlyEnabled then
        hitboxEnabled = false
        hitboxBtn.Text = "هيتبوكس: إيقاف"
        hitboxBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    end
    deadlyBtn.Text = deadlyEnabled and "رصاصة قاتلة: تشغيل" or "رصاصة قاتلة: إيقاف"
    deadlyBtn.BackgroundColor3 = deadlyEnabled and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(50, 50, 50)
end)

noclipBtn.MouseButton1Click:Connect(function()
    noclipEnabled = not noclipEnabled
    noclipBtn.Text = noclipEnabled and "اختراق الجدران: تشغيل" or "اختراق الجدران: إيقاف"
    noclipBtn.BackgroundColor3 = noclipEnabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(50, 50, 50)
end)

invisibleBtn.MouseButton1Click:Connect(function()
    invisibleEnabled = not invisibleEnabled
    invisibleBtn.Text = invisibleEnabled and "الاختفاء: تشغيل" or "الاختفاء: إيقاف"
    invisibleBtn.BackgroundColor3 = invisibleEnabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(50, 50, 50)
end)

ghostBtn.MouseButton1Click:Connect(function()
    ghostEnabled = not ghostEnabled
    ghostBtn.Text = ghostEnabled and "وضع الشبح: تشغيل" or "وضع الشبح: إيقاف"
    ghostBtn.BackgroundColor3 = ghostEnabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(50, 50, 50)
end)

godBtn.MouseButton1Click:Connect(function()
    godModeEnabled = not godModeEnabled
    godBtn.Text = godModeEnabled and "الخلود: تشغيل" or "الخلود: إيقاف"
    godBtn.BackgroundColor3 = godModeEnabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(50, 50, 50)
end)

