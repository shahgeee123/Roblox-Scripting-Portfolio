--!strict
local Players = game:GetService("Players")
local PanelController = require(script.Parent.PanelController)

local gui = Instance.new("ScreenGui")
gui.Name = "PortfolioPanelDemo"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Size = UDim2.fromOffset(180, 44)
button.Position = UDim2.fromOffset(24, 24)
button.BackgroundColor3 = Color3.fromRGB(75, 102, 235)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamMedium
button.TextSize = 16
button.Text = "Inventory  [B]"
button.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Size = UDim2.new(0.8, 0, 0, 180)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(24, 29, 42)
panel.Parent = gui
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(420, 180)
constraint.Parent = panel
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -40, 1, -40)
label.Position = UDim2.fromOffset(20, 20)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamMedium
label.TextSize = 20
label.TextColor3 = Color3.fromRGB(235, 239, 250)
label.TextWrapped = true
label.Text = "Inventory\nPanel animation demonstration"
label.Parent = panel

local controller = PanelController.new(panel, button)
gui.Destroying:Connect(controller.Destroy)
