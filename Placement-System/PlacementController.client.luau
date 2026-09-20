--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Grid = require(ReplicatedStorage:WaitForChild("GridUtil"))
local remote = ReplicatedStorage:WaitForChild("RequestPlacement") :: RemoteEvent
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local plot = workspace:WaitForChild("PortfolioPlots"):WaitForChild(tostring(player.UserId)) :: BasePart
local turn = 0

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.R then
		turn = (turn + 1) % 4
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		if mouse.Target ~= plot then return end
		local x, z = Grid.worldToCell(plot, mouse.Hit.Position)
		remote:FireServer(x, z, turn)
	end
end)
