--!strict
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local PanelController = {}

function PanelController.new(panel: Frame, toggle: GuiButton)
	local openPosition = panel.Position
	local closedPosition = openPosition + UDim2.fromOffset(0, 24)
	local isOpen = false
	local destroyed = false
	local activeTween: Tween? = nil
	local completion: RBXScriptConnection? = nil
	panel.Visible = false
	panel.Position = closedPosition

	local function cancelTransition()
		if completion then completion:Disconnect(); completion = nil end
		if activeTween then activeTween:Cancel(); activeTween = nil end
	end

	local function setOpen(value: boolean)
		if destroyed or value == isOpen then return end
		isOpen = value
		cancelTransition()
		panel.Visible = true
		local tween = TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
			Position = if value then openPosition else closedPosition,
		})
		activeTween = tween
		completion = tween.Completed:Connect(function()
			panel.Visible = isOpen
			if completion then completion:Disconnect(); completion = nil end
			activeTween = nil
		end)
		tween:Play()
	end

	local clicked = toggle.Activated:Connect(function() setOpen(not isOpen) end)
	local input = UserInputService.InputBegan:Connect(function(key, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		if key.KeyCode == Enum.KeyCode.B then setOpen(not isOpen) end
	end)

	local function destroy()
		if destroyed then return end
		destroyed = true
		cancelTransition()
		clicked:Disconnect()
		input:Disconnect()
		panel.Visible = false
		panel.Position = openPosition
	end

	return { SetOpen = setOpen, Destroy = destroy }
end

return table.freeze(PanelController)
