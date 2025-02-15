local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.Name = "DeltaGUI"

local mainFrame = Instance.new("Frame", gui)
mainFrame.Size = UDim2.new(0, 220, 0, 260) 
mainFrame.Position = UDim2.new(0.5, -110, 0.5, -130)
mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
mainFrame.BorderSizePixel = 2

local border = Instance.new("UIStroke", mainFrame)
border.Thickness = 2

local titleFrame = Instance.new("Frame", mainFrame)
titleFrame.Size = UDim2.new(1, 0, 0, 40)
titleFrame.Position = UDim2.new(0, 0, 0, 5)
titleFrame.BackgroundTransparency = 1

local partnershipText = Instance.new("TextLabel", titleFrame)
partnershipText.Size = UDim2.new(1, 0, 1, 0)
partnershipText.Text = "شراكة بين رضا ملاحظة توجد بعض التفعيلات قيد الصيانة وقيد التجربة ᨖ ومايكي "
partnershipText.TextColor3 = Color3.new(1, 1, 1)
partnershipText.BackgroundTransparency = 1
partnershipText.Font = Enum.Font.SciFi
partnershipText.TextSize = 16

spawn(function()
    while true do
        for i = 0, 1, 0.05 do
            local wave = math.sin(i * math.pi * 2) * 0.5 + 0.5
            partnershipText.TextColor3 = Color3.fromHSV(wave, 1, 1)
            border.Color = Color3.fromHSV(wave, 1, 1)
            wait(0.05)
        end
    end
end)

local function createButton(text, posX, posY)
    local button = Instance.new("TextButton", mainFrame)
    button.Size = UDim2.new(0, 90, 0, 35)
    button.Position = UDim2.new(0, posX, 0, posY + 40)
    button.Text = text
    button.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.SciFi
    button.TextSize = 14
    return button
end

local speedButton = createButton("سبيد وطيران", 5, 10)
local vanishButton = createButton("اختفاء لاعب", 105, 10)
local colorButton = createButton("لون متغير", 5, 50)
local smallButton = createButton("تصغير جدا", 105, 50)
local bigButton = createButton("تكبير جدا", 5, 90)
local monsterButton = createButton("لاعب وحش", 105, 90)
local closeButton = createButton("إغلاق", 50, 140)

local isSpeed, isVanished, isColorChanging, isSmall, isBig, isMonster = false, false, false, false, false, false

speedButton.MouseButton1Click:Connect(function()
    isSpeed = not isSpeed
    speedButton.Text = isSpeed and "إيقاف" or "سبيد وطيران"
    player.Character.Humanoid.WalkSpeed = isSpeed and 200 or 16
    player.Character.Humanoid.JumpPower = isSpeed and 500 or 50
end)

vanishButton.MouseButton1Click:Connect(function()
    isVanished = not isVanished
    vanishButton.Text = isVanished and "إلغاء" or "اختفاء لاعب/تجربه"
    for _, part in pairs(player.Character:GetChildren()) do
        if part:IsA("BasePart") then
            part.Transparency = isVanished and 1 or 0
        end
    end
end)

colorButton.MouseButton1Click:Connect(function()
    isColorChanging = not isColorChanging
    colorButton.Text = isColorChanging and "إيقاف" or "لون متغير"
    while isColorChanging do
        for i = 0, 1, 0.1 do
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Color = Color3.fromHSV(i, 1, 1)
                end
            end
            wait(0.05)
        end
    end
end)

smallButton.MouseButton1Click:Connect(function()
    isSmall = not isSmall
    isBig = false
    smallButton.Text = isSmall and "إرجاع" or "تصغير جدا/صيانه"
    player.Character.HumanoidRootPart.Size = isSmall and Vector3.new(0.2, 0.2, 0.2) or Vector3.new(2, 2, 1)
    player.Character.Humanoid.BodyHeightScale.Value = isSmall and 0.05 or 1
    player.Character.Humanoid.BodyWidthScale.Value = isSmall and 0.05 or 1
    player.Character.Humanoid.BodyDepthScale.Value = isSmall and 0.05 or 1
end)

bigButton.MouseButton1Click:Connect(function()
    isBig = not isBig
    isSmall = false
    bigButton.Text = isBig and "إرجاع" or "تكبير جدا"
    player.Character.HumanoidRootPart.Size = isBig and Vector3.new(10, 10, 10) or Vector3.new(2, 2, 1)
    player.Character.Humanoid.BodyHeightScale.Value = isBig and 5 or 1
    player.Character.Humanoid.BodyWidthScale.Value = isBig and 5 or 1
    player.Character.Humanoid.BodyDepthScale.Value = isBig and 5 or 1
end)

monsterButton.MouseButton1Click:Connect(function()
    isMonster = not isMonster
    monsterButton.Text = isMonster and "إيقاف" or "لاعب وحش/صيانه"
    while isMonster do
        player.Character.Humanoid.BodyHeightScale.Value = math.random(1, 10)
        player.Character.Humanoid.BodyWidthScale.Value = math.random(1, 10)
        player.Character.Humanoid.BodyDepthScale.Value = math.random(1, 10)
        wait(0.1)
    end
    player.Character.Humanoid.BodyHeightScale.Value = 1
    player.Character.Humanoid.BodyWidthScale.Value = 1
    player.Character.Humanoid.BodyDepthScale.Value = 1
end)

closeButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

local icon = Instance.new("TextButton", gui)
icon.Size = UDim2.new(0, 45, 0, 45)
icon.Position = UDim2.new(0, 10, 0, 10)
icon.Text = "Re+Mi"
icon.BackgroundColor3 = Color3.new(0, 0, 0)
icon.TextColor3 = Color3.new(1, 1, 0)
icon.Font = Enum.Font.SciFi
icon.TextSize = 18
icon.BorderSizePixel = 2

local iconBorder = Instance.new("UIStroke", icon)
iconBorder.Thickness = 2

icon.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

local function makeDraggable(frame)
    local dragToggle, dragStart, startPos

    local function updateInput(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragToggle = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragToggle = false
                end
            end)
        end
    end)

    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragToggle then
                updateInput(input)
            end
        end
    end)
end

makeDraggable(mainFrame)
makeDraggable(icon)
