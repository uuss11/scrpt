local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "RE_Pro_Gui"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local iconFrame = Instance.new("TextButton")
iconFrame.Name = "IconFrame"
iconFrame.Size = UDim2.new(0, 55, 0, 55)
iconFrame.Position = UDim2.new(0, 15, 0, 15)
iconFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
iconFrame.BackgroundTransparency = 0.3
iconFrame.BorderSizePixel = 0
iconFrame.Text = "" 
iconFrame.AutoButtonColor = false 
iconFrame.Parent = gui

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0, 16)
iconCorner.Parent = iconFrame

local iconStroke = Instance.new("UIStroke")
iconStroke.Thickness = 1.5
iconStroke.Color = Color3.fromRGB(255, 255, 255)
iconStroke.Transparency = 0.7
iconStroke.Parent = iconFrame

local label = Instance.new("TextLabel")
label.Name = "RELabel"
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text = "RE"
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextScaled = true
label.Font = Enum.Font.GothamBlack
label.Parent = iconFrame

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 75, 75)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 150)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 75, 75))
})
gradient.Rotation = 45
gradient.Parent = label

local dragging = false
local dragStartPos, dragStartMouse
local hasDragged = false 

iconFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        hasDragged = false
        dragStartPos = iconFrame.Position
        dragStartMouse = input.Position
        
        TweenService:Create(iconFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 50, 0, 50)}):Play()
    end
end)

iconFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        TweenService:Create(iconFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, 55, 0, 55)}):Play()
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
        
        local viewportSize = workspace.CurrentCamera.ViewportSize
        newPos = UDim2.new(
            0, math.clamp(newPos.X.Offset, 0, viewportSize.X - iconFrame.AbsoluteSize.X),
            0, math.clamp(newPos.Y.Offset, 0, viewportSize.Y - iconFrame.AbsoluteSize.Y)
        )
        iconFrame.Position = newPos
    end
end)

local menuFrame = Instance.new("CanvasGroup")
menuFrame.Name = "MenuFrame"
menuFrame.Size = UDim2.new(0, 260, 0, 170)
menuFrame.Position = UDim2.new(0, 20, 0, 80)
menuFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
menuFrame.BackgroundTransparency = 0.25
menuFrame.BorderSizePixel = 0
menuFrame.GroupTransparency = 1
menuFrame.Visible = false
menuFrame.Parent = gui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 12)
menuCorner.Parent = menuFrame

local menuStroke = Instance.new("UIStroke")
menuStroke.Thickness = 1
menuStroke.Color = Color3.fromRGB(255, 255, 255)
menuStroke.Transparency = 0.8
menuStroke.Parent = menuFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 35)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "RE PANEL"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.Parent = menuFrame

local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 100)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 200))
})
titleGradient.Parent = titleLabel

local divider = Instance.new("Frame")
divider.Size = UDim2.new(0.85, 0, 0, 1)
divider.Position = UDim2.new(0.075, 0, 0, 35)
divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
divider.BackgroundTransparency = 0.8
divider.BorderSizePixel = 0
divider.Parent = menuFrame

local hitboxBtn = Instance.new("TextButton")
hitboxBtn.Name = "HitboxBtn"
hitboxBtn.Size = UDim2.new(0.85, 0, 0, 36)
hitboxBtn.Position = UDim2.new(0.075, 0, 0, 50)
hitboxBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
hitboxBtn.BackgroundTransparency = 0.3
hitboxBtn.Text = "Enable Hitbox"
hitboxBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
hitboxBtn.Font = Enum.Font.GothamSemibold
hitboxBtn.TextSize = 14
hitboxBtn.AutoButtonColor = false
hitboxBtn.Parent = menuFrame

local hitboxCorner = Instance.new("UICorner")
hitboxCorner.CornerRadius = UDim.new(0, 8)
hitboxCorner.Parent = hitboxBtn

local hitboxStroke = Instance.new("UIStroke")
hitboxStroke.Thickness = 1
hitboxStroke.Color = Color3.fromRGB(255, 255, 255)
hitboxStroke.Transparency = 0.85
hitboxStroke.Parent = hitboxBtn

local sliderTitle = Instance.new("TextLabel")
sliderTitle.Size = UDim2.new(0, 100, 0, 20)
sliderTitle.Position = UDim2.new(0.075, 0, 0, 100)
sliderTitle.BackgroundTransparency = 1
sliderTitle.Text = "Hitbox Size"
sliderTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
sliderTitle.Font = Enum.Font.GothamMedium
sliderTitle.TextSize = 13
sliderTitle.TextXAlignment = Enum.TextXAlignment.Left
sliderTitle.Parent = menuFrame

local sizeLabel = Instance.new("TextLabel")
sizeLabel.Name = "SizeLabel"
sizeLabel.Size = UDim2.new(0, 40, 0, 20)
sizeLabel.Position = UDim2.new(1, -60, 0, 100)
sizeLabel.BackgroundTransparency = 1
sizeLabel.Text = "20"
sizeLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
sizeLabel.Font = Enum.Font.GothamBold
sizeLabel.TextSize = 14
sizeLabel.TextXAlignment = Enum.TextXAlignment.Right
sizeLabel.Parent = menuFrame

local sliderBg = Instance.new("Frame")
sliderBg.Name = "SliderBg"
sliderBg.Size = UDim2.new(0.85, 0, 0, 4)
sliderBg.Position = UDim2.new(0.075, 0, 0, 130)
sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
sliderBg.BorderSizePixel = 0
sliderBg.Parent = menuFrame

local sliderCorner = Instance.new("UICorner")
sliderCorner.CornerRadius = UDim.new(1, 0)
sliderCorner.Parent = sliderBg

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = sliderFill

local sliderThumb = Instance.new("Frame")
sliderThumb.Name = "SliderThumb"
sliderThumb.Size = UDim2.new(0, 14, 0, 14)
sliderThumb.Position = UDim2.new(0, 0, 0.5, 0)
sliderThumb.AnchorPoint = Vector2.new(0.5, 0.5)
sliderThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sliderThumb.BorderSizePixel = 0
sliderThumb.Parent = sliderBg

local thumbCorner = Instance.new("UICorner")
thumbCorner.CornerRadius = UDim.new(1, 0)
thumbCorner.Parent = sliderThumb

local thumbStroke = Instance.new("UIStroke")
thumbStroke.Color = Color3.fromRGB(255, 100, 100)
thumbStroke.Thickness = 2
thumbStroke.Parent = sliderThumb

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 35, 0, 35)
closeBtn.Position = UDim2.new(1, -35, 0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = menuFrame

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 80, 80)}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(150, 150, 150)}):Play()
end)

local hitboxSize = 20 
local minSize = 5
local maxSize = 150
local isDraggingSlider = false
local hitboxEnabled = false
local menuOpen = false

local function updateSliderUI()
    local ratio = (hitboxSize - minSize) / (maxSize - minSize)
    local thumbX = ratio * sliderBg.AbsoluteSize.X
    
    TweenService:Create(sliderThumb, TweenInfo.new(0.1), {Position = UDim2.new(0, thumbX, 0.5, 0)}):Play()
    TweenService:Create(sliderFill, TweenInfo.new(0.1), {Size = UDim2.new(ratio, 0, 1, 0)}):Play()
    sizeLabel.Text = tostring(math.round(hitboxSize))
end

local function applyHitboxToPlayer(player)
    if player == LocalPlayer or not player.Character then return end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
        hrp.Transparency = 0.7
        hrp.BrickColor = BrickColor.new("White")
        hrp.Material = Enum.Material.SmoothPlastic
        hrp.CanCollide = false
    end
end

local function updateAllHitboxSizes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            applyHitboxToPlayer(player)
        end
    end
end

sliderThumb.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = true
        TweenService:Create(sliderThumb, TweenInfo.new(0.2), {Size = UDim2.new(0, 18, 0, 18)}):Play()
    end
end)

sliderThumb.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDraggingSlider = false
        TweenService:Create(sliderThumb, TweenInfo.new(0.2), {Size = UDim2.new(0, 14, 0, 14)}):Play()
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local sliderAbsPos = sliderBg.AbsolutePosition
        local sliderAbsSize = sliderBg.AbsoluteSize
        local mouseX = input.Position.X
        
        local relativeX = math.clamp(mouseX - sliderAbsPos.X, 0, sliderAbsSize.X)
        local ratio = relativeX / sliderAbsSize.X
        
        hitboxSize = minSize + (maxSize - minSize) * ratio
        hitboxSize = math.round(hitboxSize)
        
        updateSliderUI()
        
        if hitboxEnabled then
            updateAllHitboxSizes()
        end
    end
end)

sliderBg:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSliderUI)

local function toggleMenu()
    menuOpen = not menuOpen
    if menuOpen then
        menuFrame.Position = UDim2.new(
            0, iconFrame.Position.X.Offset + 15,
            0, iconFrame.Position.Y.Offset + 70
        )
        menuFrame.Visible = true
        TweenService:Create(menuFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            GroupTransparency = 0,
            Position = UDim2.new(0, iconFrame.Position.X.Offset + 15, 0, iconFrame.Position.Y.Offset + 60)
        }):Play()
        task.wait(0.1)
        updateSliderUI()
    else
        local closeTween = TweenService:Create(menuFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            GroupTransparency = 1,
            Position = UDim2.new(0, iconFrame.Position.X.Offset + 15, 0, iconFrame.Position.Y.Offset + 70)
        })
        closeTween:Play()
        closeTween.Completed:Wait()
        if not menuOpen then menuFrame.Visible = false end
    end
end

closeBtn.MouseButton1Click:Connect(function()
    if menuOpen then toggleMenu() end
end)

iconFrame.MouseButton1Click:Connect(function()
    if not hasDragged then toggleMenu() end
end)

local hitboxConnection = nil
local updateConnection = nil

local function resetHitboxes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.Transparency = 1
                hrp.CanCollide = false
            end
        end
    end
end

local function enforceHitboxes()
    if not hitboxEnabled then return end
    updateAllHitboxSizes()
end

hitboxBtn.MouseEnter:Connect(function()
    if not hitboxEnabled then
        TweenService:Create(hitboxBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 45)}):Play()
    end
end)
hitboxBtn.MouseLeave:Connect(function()
    if not hitboxEnabled then
        TweenService:Create(hitboxBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 30)}):Play()
    end
end)

local function toggleHitbox()
    hitboxEnabled = not hitboxEnabled
    
    if hitboxEnabled then
        updateAllHitboxSizes()
        
        hitboxConnection = Players.PlayerAdded:Connect(function(player)
            if player ~= LocalPlayer then
                player.CharacterAdded:Connect(function(character)
                    task.wait(1) 
                    if hitboxEnabled then applyHitboxToPlayer(player) end
                end)
            end
        end)
        
        updateConnection = RunService.RenderStepped:Connect(enforceHitboxes)
        
        TweenService:Create(hitboxBtn, TweenInfo.new(0.3), {
            BackgroundColor3 = Color3.fromRGB(40, 180, 70),
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
        hitboxBtn.Text = "Hitbox Enabled"
    else
        resetHitboxes()
        if hitboxConnection then hitboxConnection:Disconnect() end
        if updateConnection then updateConnection:Disconnect() end
        
        TweenService:Create(hitboxBtn, TweenInfo.new(0.3), {
            BackgroundColor3 = Color3.fromRGB(25, 25, 30),
            TextColor3 = Color3.fromRGB(220, 220, 220)
        }):Play()
        hitboxBtn.Text = "Enable Hitbox"
    end
end

hitboxBtn.MouseButton1Click:Connect(function()
    TweenService:Create(hitboxBtn, TweenInfo.new(0.1), {Size = UDim2.new(0.82, 0, 0, 34)}):Play()
    task.wait(0.1)
    TweenService:Create(hitboxBtn, TweenInfo.new(0.1), {Size = UDim2.new(0.85, 0, 0, 36)}):Play()
    toggleHitbox()
end)

LocalPlayer.CharacterRemoving:Connect(function()
    resetHitboxes()
    if hitboxConnection then hitboxConnection:Disconnect() end
    if updateConnection then updateConnection:Disconnect() end
end)

task.wait(0.5)
updateSliderUI()

