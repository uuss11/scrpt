local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.Name = "DeltaGUI"

local mainFrame = Instance.new("Frame", gui)
mainFrame.Size = UDim2.new(0, 300, 0, 200)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false

local rain = Instance.new("ParticleEmitter", mainFrame)
rain.Texture = "rbxassetid://123456"
rain.VelocitySpread = 50
rain.Lifetime = NumberRange.new(2)
rain.Rate = 100
rain.Speed = NumberRange.new(50)
rain.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.5)})
rain.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
rain.Rotation = NumberRange.new(0, 360)
rain.RotSpeed = NumberRange.new(-50, 50)
rain.Color = ColorSequence.new(Color3.new(1, 1, 0))

local partnershipText = Instance.new("TextLabel", mainFrame)
partnershipText.Size = UDim2.new(1, 0, 0, 30)
partnershipText.Position = UDim2.new(0, 0, 0, 10)
partnershipText.Text = "شراكة بين رضا ᨖ و مايكي MI"
partnershipText.TextColor3 = Color3.new(1, 1, 1)
partnershipText.BackgroundTransparency = 1
partnershipText.Font = Enum.Font.SciFi
partnershipText.TextSize = 18

local toggleButton = Instance.new("TextButton", mainFrame)
toggleButton.Size = UDim2.new(0, 100, 0, 40)
toggleButton.Position = UDim2.new(0.5, -50, 0.5, -20)
toggleButton.Text = "تفعيل سبيد وطيران"
toggleButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.Font = Enum.Font.SciFi
toggleButton.TextSize = 18

local isEnabled = false

toggleButton.MouseButton1Click:Connect(function()
    isEnabled = not isEnabled
    if isEnabled then
        toggleButton.Text = "إيقاف الكل"
        player.Character.Humanoid.WalkSpeed = 50
        player.Character.Humanoid.JumpPower = 100
    else
        toggleButton.Text = "تفعيل سبيد وطيران"
        player.Character.Humanoid.WalkSpeed = 16
        player.Character.Humanoid.JumpPower = 50
    end
end)

local icon = Instance.new("TextButton", gui)
icon.Size = UDim2.new(0, 50, 0, 50)
icon.Position = UDim2.new(0, 10, 0, 10)
icon.Text = "Re+Mi"
icon.BackgroundColor3 = Color3.new(0, 0, 0)
icon.TextColor3 = Color3.new(1, 1, 0)
icon.Font = Enum.Font.SciFi
icon.TextSize = 24

local iconRain = Instance.new("ParticleEmitter", icon)
iconRain.Texture = "rbxassetid://123456"
iconRain.VelocitySpread = 50
iconRain.Lifetime = NumberRange.new(2)
iconRain.Rate = 50
iconRain.Speed = NumberRange.new(50)
iconRain.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.5)})
iconRain.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
iconRain.Rotation = NumberRange.new(0, 360)
iconRain.RotSpeed = NumberRange.new(-50, 50)
iconRain.Color = ColorSequence.new(Color3.new(1, 1, 0))

icon.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

local closeButton = Instance.new("TextButton", mainFrame)
closeButton.Size = UDim2.new(0, 100, 0, 40)
closeButton.Position = UDim2.new(0.5, -50, 0.8, -20)
closeButton.Text = "إغلاق"
closeButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Font = Enum.Font.SciFi
closeButton.TextSize = 18

closeButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

while true do
    for i = 0, 1, 0.01 do
        partnershipText.TextColor3 = Color3.new(i, 1 - i, i)
        toggleButton.TextColor3 = Color3.new(1 - i, i, 1 - i)
        wait(0.1)
    end
end
