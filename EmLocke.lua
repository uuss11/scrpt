local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.Name = "REIcon"

local icon = Instance.new("TextButton", gui)
icon.Name = "Icon"
icon.Size = UDim2.new(0, 50, 0, 50)
icon.Position = UDim2.new(0, 10, 0, 10)
icon.Text = "RE"
icon.TextSize = 20
icon.BackgroundColor3 = Color3.new(1, 1, 1)
icon.BorderSizePixel = 2
icon.BorderColor3 = Color3.new(0, 0, 0)

local colors = {
    Color3.new(0, 0, 1),
    Color3.new(0, 1, 1)
}
local currentColorIndex = 1
local colorChangeSpeed = 1

local function changeColor()
    currentColorIndex = currentColorIndex + 1
    if currentColorIndex > #colors then
        currentColorIndex = 1
    end
    icon.BorderColor3 = colors[currentColorIndex]
end

local lastColorChange = tick()
game:GetService("RunService").RenderStepped:Connect(function()
    if tick() - lastColorChange >= colorChangeSpeed then
        changeColor()
        lastColorChange = tick()
    end
end)

local menu = Instance.new("Frame", gui)
menu.Name = "Menu"
menu.Size = UDim2.new(0, 100, 0, 50)
menu.Position = UDim2.new(0, 70, 0, 10)
menu.BackgroundColor3 = Color3.new(0.2, 0.2, 0.5)
menu.Visible = false

local menuBorder = Instance.new("UIStroke", menu)
menuBorder.Thickness = 2
menuBorder.Color = Color3.new(0, 0, 1)

local function changeMenuBorderColor()
    currentColorIndex = currentColorIndex + 1
    if currentColorIndex > #colors then
        currentColorIndex = 1
    end
    menuBorder.Color = colors[currentColorIndex]
end

local lastMenuColorChange = tick()
game:GetService("RunService").RenderStepped:Connect(function()
    if tick() - lastMenuColorChange >= colorChangeSpeed then
        changeMenuBorderColor()
        lastMenuColorChange = tick()
    end
end)

local emLockButton = Instance.new("TextButton", menu)
emLockButton.Name = "EmLockButton"
emLockButton.Size = UDim2.new(0, 90, 0, 30)
emLockButton.Position = UDim2.new(0, 5, 0, 10)
emLockButton.Text = "إيم لوك: إيقاف"
emLockButton.TextSize = 14
emLockButton.BackgroundColor3 = Color3.new(0.4, 0.4, 0.8)
emLockButton.BorderSizePixel = 0

local function toggleMenu()
    menu.Visible = not menu.Visible
end

icon.MouseButton1Click:Connect(toggleMenu)

local emLock = false
local closestPlayer = nil

local function findClosestPlayer()
    local closestDistance = math.huge
    local closest = nil
    for _, otherPlayer in ipairs(game.Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (player.Character.HumanoidRootPart.Position - otherPlayer.Character.HumanoidRootPart.Position).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closest = otherPlayer
            end
        end
    end
    return closest
end

local function updateAimLock()
    if emLock and closestPlayer and closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local targetPosition = closestPlayer.Character.HumanoidRootPart.Position
        player.Character.HumanoidRootPart.CFrame = CFrame.new(player.Character.HumanoidRootPart.Position, Vector3.new(targetPosition.X, player.Character.HumanoidRootPart.Position.Y, targetPosition.Z))
    end
end

local function toggleEmLock()
    emLock = not emLock
    if emLock then
        emLockButton.Text = "إيم لوك: تفعيل"
        closestPlayer = findClosestPlayer()
        print("تم تفعيل إيم لوك على: " .. (closestPlayer and closestPlayer.Name or "لا يوجد خصم"))
    else
        emLockButton.Text = "إيم لوك: إيقاف"
        closestPlayer = nil
        print("تم إيقاف إيم لوك")
    end
end

emLockButton.MouseButton1Click:Connect(toggleEmLock)

game:GetService("RunService").RenderStepped:Connect(function()
    if emLock then
        updateAimLock()
    end
end)
