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
title.Text = "ℝ𝔼: رضا "
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
local hitboxColor = Color3.fromRGB(255, 255, 255)

sizeInput.FocusLost:Connect(function()
    local num = tonumber(sizeInput.Text)
    if num then
        hitboxSize = math.clamp(num, 2, 200)
        sizeInput.Text = tostring(hitboxSize)
    end
end)

local colorIconBtn = Instance.new("TextButton")
colorIconBtn.Size = UDim2.new(0, 28, 0, 28)
colorIconBtn.BackgroundColor3 = hitboxColor
colorIconBtn.BackgroundTransparency = 0.6
colorIconBtn.BorderSizePixel = 1
colorIconBtn.BorderColor3 = Color3.fromRGB(200, 200, 200)
colorIconBtn.Text = "C"
colorIconBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
colorIconBtn.Font = Enum.Font.Code
colorIconBtn.TextSize = 14
colorIconBtn.Visible = false
colorIconBtn.Parent = gui

local colorFrame = Instance.new("Frame")
colorFrame.Size = UDim2.new(0, 220, 0, 180)
colorFrame.Position = UDim2.new(0, 200, 0, 15)
colorFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
colorFrame.BorderSizePixel = 2
colorFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
colorFrame.Visible = false
colorFrame.Parent = gui

local colorTitle = Instance.new("TextLabel")
colorTitle.Size = UDim2.new(1, -30, 0, 26)
colorTitle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
colorTitle.BorderSizePixel = 0
colorTitle.Text = "لون الهيتبوكس"
colorTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
colorTitle.Font = Enum.Font.Code
colorTitle.TextSize = 14
colorTitle.Parent = colorFrame

local colorCloseBtn = Instance.new("TextButton")
colorCloseBtn.Size = UDim2.new(0, 30, 0, 26)
colorCloseBtn.Position = UDim2.new(1, -30, 0, 0)
colorCloseBtn.BackgroundTransparency = 1
colorCloseBtn.Text = "X"
colorCloseBtn.TextColor3 = Color3.fromRGB(255, 50, 50)
colorCloseBtn.Font = Enum.Font.Code
colorCloseBtn.TextSize = 14
colorCloseBtn.Parent = colorFrame
colorCloseBtn.MouseButton1Click:Connect(function() colorFrame.Visible = false end)

local previewBox = Instance.new("Frame")
previewBox.Size = UDim2.new(0, 40, 0, 40)
previewBox.Position = UDim2.new(0, 10, 0, 36)
previewBox.BackgroundColor3 = hitboxColor
previewBox.BorderSizePixel = 1
previewBox.BorderColor3 = Color3.fromRGB(200, 200, 200)
previewBox.Parent = colorFrame

local previewAlpha = Instance.new("TextLabel")
previewAlpha.Size = UDim2.new(0, 40, 0, 18)
previewAlpha.Position = UDim2.new(0, 10, 0, 78)
previewAlpha.BackgroundTransparency = 1
previewAlpha.Text = "شفاف"
previewAlpha.TextColor3 = Color3.fromRGB(200, 200, 200)
previewAlpha.Font = Enum.Font.Code
previewAlpha.TextSize = 11
previewAlpha.Parent = colorFrame

local function makeSlider(labelText, yPos, startValue, callback)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 50, 0, 20)
    label.Position = UDim2.new(0, 60, 0, yPos)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.Code
    label.TextSize = 12
    label.Parent = colorFrame

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 140, 0, 14)
    track.Position = UDim2.new(0, 60, 0, yPos + 18)
    track.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    track.BorderSizePixel = 0
    track.Parent = colorFrame

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(startValue, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    fill.BorderSizePixel = 0
    fill.Parent = track

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 12, 0, 20)
    thumb.Position = UDim2.new(startValue, -6, 0, -3)
    thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    thumb.BorderSizePixel = 0
    thumb.Parent = track

    local sliderDragging = false
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = true
            local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            thumb.Position = UDim2.new(rel, -6, 0, -3)
            callback(rel)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            thumb.Position = UDim2.new(rel, -6, 0, -3)
            callback(rel)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = false
        end
    end)
    return track
end

local hueValue = 0
local satValue = 0.4
local brightValue = 0.8

makeSlider("تدرج", 100, hueValue, function(rel)
    hueValue = rel
    local h, s, b = Color3.fromHSV(hueValue, satValue, brightValue):ToHSV()
    hitboxColor = Color3.fromHSV(h, s, b)
    previewBox.BackgroundColor3 = hitboxColor
    colorIconBtn.BackgroundColor3 = hitboxColor
end)

makeSlider("تشبع", 140, satValue, function(rel)
    satValue = rel
    hitboxColor = Color3.fromHSV(hueValue, satValue, brightValue)
    previewBox.BackgroundColor3 = hitboxColor
    colorIconBtn.BackgroundColor3 = hitboxColor
end)

makeSlider("إضاءة", 180, brightValue, function(rel)
    brightValue = math.max(rel, 0.15)
    hitboxColor = Color3.fromHSV(hueValue, satValue, brightValue)
    previewBox.BackgroundColor3 = hitboxColor
    colorIconBtn.BackgroundColor3 = hitboxColor
end)

local alphaSliderTrack, alphaSliderFill, alphaSliderThumb = nil, nil, nil
local alphaValue = 0.7

local alphaLabel = Instance.new("TextLabel")
alphaLabel.Size = UDim2.new(0, 50, 0, 20)
alphaLabel.Position = UDim2.new(0, 60, 0, 220)
alphaLabel.BackgroundTransparency = 1
alphaLabel.Text = "شفافية"
alphaLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
alphaLabel.Font = Enum.Font.Code
alphaLabel.TextSize = 12
alphaLabel.Parent = colorFrame

alphaSliderTrack = Instance.new("Frame")
alphaSliderTrack.Size = UDim2.new(0, 140, 0, 14)
alphaSliderTrack.Position = UDim2.new(0, 60, 0, 238)
alphaSliderTrack.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
alphaSliderTrack.BorderSizePixel = 0
alphaSliderTrack.Parent = colorFrame

alphaSliderFill = Instance.new("Frame")
alphaSliderFill.Size = UDim2.new(alphaValue, 0, 1, 0)
alphaSliderFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
alphaSliderFill.BorderSizePixel = 0
alphaSliderFill.Parent = alphaSliderTrack

alphaSliderThumb = Instance.new("Frame")
alphaSliderThumb.Size = UDim2.new(0, 12, 0, 20)
alphaSliderThumb.Position = UDim2.new(alphaValue, -6, 0, -3)
alphaSliderThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
alphaSliderThumb.BorderSizePixel = 0
alphaSliderThumb.Parent = alphaSliderTrack

local alphaDragging = false
alphaSliderTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        alphaDragging = true
        local rel = math.clamp((input.Position.X - alphaSliderTrack.AbsolutePosition.X) / alphaSliderTrack.AbsoluteSize.X, 0, 1)
        alphaSliderFill.Size = UDim2.new(rel, 0, 1, 0)
        alphaSliderThumb.Position = UDim2.new(rel, -6, 0, -3)
        alphaValue = rel
        colorIconBtn.BackgroundTransparency = 1 - math.clamp(rel, 0.1, 0.9)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if alphaDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
       or input.UserInputType == Enum.UserInputType.Touch) then
        local rel = math.clamp((input.Position.X - alphaSliderTrack.AbsolutePosition.X) / alphaSliderTrack.AbsoluteSize.X, 0, 1)
        alphaSliderFill.Size = UDim2.new(rel, 0, 1, 0)
        alphaSliderThumb.Position = UDim2.new(rel, -6, 0, -3)
        alphaValue = rel
        colorIconBtn.BackgroundTransparency = 1 - math.clamp(rel, 0.1, 0.9)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        alphaDragging = false
    end
end)

colorIconBtn.MouseButton1Click:Connect(function()
    colorFrame.Visible = not colorFrame.Visible
end)

colorIconBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStartPos = colorIconBtn.Position
        dragStartMouse = input.Position
    end
end)

colorIconBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        task.delay(0.05, function() end)
    end
end)

local function applyHitbox()
    local camCF = Camera.CFrame
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CanCollide = false
                hrp.Transparency = 1 - alphaValue
                hrp.Color = hitboxColor
                hrp.Material = Enum.Material.Glass
                if deadlyEnabled then
                    hrp.Size = Vector3.new(6, 6, 6)
                    hrp.CFrame = camCF * CFrame.new(0, 0, -12)
                elseif hitboxEnabled then
                    hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                else
                    hrp.Size = Vector3.new(2, 2, 1)
                    hrp.Material = Enum.Material.Plastic
                end
            end
        end
    end
end

local function refreshGodHealth()
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.MaxHealth = 999999
        humanoid.Health = 999999
    end
end

local function lockDeathState(humanoid)
    if not humanoid then return end
    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)
end

local function onCharacterAdded(char)
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    lockDeathState(humanoid)
    char.DescendantAdded:Connect(function(desc)
        if invisibleEnabled and desc:IsA("BasePart") then
            desc.Transparency = 1
        end
    end)
    if humanoid then
        humanoid.HealthChanged:Connect(function()
            if godModeEnabled then
                humanoid.MaxHealth = 999999
                humanoid.Health = 999999
            end
        end)
        humanoid.Died:Connect(function()
            if godModeEnabled then
                pcall(function()
                    humanoid.Health = 999999
                    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                end)
            end
        end)
    end
    if godModeEnabled then
        task.delay(0.3, refreshGodHealth)
    end
end

if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")

    applyHitbox()

    if noclipEnabled and char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and humanoid and humanoid.Health > 0 then
            local bounds = Workspace:GetPartBoundsInBox(hrp.CFrame, hrp.Size)
            for _, wall in ipairs(bounds) do
                local wallTop = wall.Position.Y + wall.Size.Y / 2
                local hrpBottom = hrp.Position.Y - hrp.Size.Y / 2
                if hrpBottom < wallTop - 0.5 then
                    if wall.CanCollide and wall.Anchored and not wall:IsDescendantOf(char) then
                        wall.CanCollide = false
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
            if desc:IsA("BasePart") then
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
        lockDeathState(humanoid)
        refreshGodHealth()
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
    colorIconBtn.Visible = hitboxEnabled
    hitboxBtn.Text = hitboxEnabled and "هيتبوكس: تشغيل" or "هيتبوكس: إيقاف"
    hitboxBtn.BackgroundColor3 = hitboxEnabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(50, 50, 50)
    if not hitboxEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = Vector3.new(2, 2, 1)
                    hrp.Transparency = 1
                    hrp.CanCollide = false
                    hrp.Material = Enum.Material.Plastic
                end
            end
        end
    end
end)

deadlyBtn.MouseButton1Click:Connect(function()
    deadlyEnabled = not deadlyEnabled
    if deadlyEnabled then
        hitboxEnabled = false
        hitboxBtn.Text = "هيتبوكس: إيقاف"
        hitboxBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        colorIconBtn.Visible = false
    else
        colorIconBtn.Visible = hitboxEnabled
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
    if not ghostEnabled then
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end
        end
    end
end)

godBtn.MouseButton1Click:Connect(function()
    godModeEnabled = not godModeEnabled
    godBtn.Text = godModeEnabled and "الخلود: تشغيل" or "الخلود: إيقاف"
    godBtn.BackgroundColor3 = godModeEnabled and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(50, 50, 50)
    if godModeEnabled then
        local char = LocalPlayer.Character
        if char then
            lockDeathState(char:FindFirstChildOfClass("Humanoid"))
            refreshGodHealth()
        end
    end
end)

