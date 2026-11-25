--!strict
-- Tiny helpers for building UI in code, plus the shared ScreenGui and toast messages.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = {}

UI.Colors = {
	Panel = Color3.fromRGB(35, 25, 55),
	PanelLight = Color3.fromRGB(60, 45, 90),
	Accent = Color3.fromRGB(255, 110, 180),
	Gold = Color3.fromRGB(255, 205, 60),
	Good = Color3.fromRGB(80, 200, 120),
	Bad = Color3.fromRGB(230, 80, 80),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(190, 180, 210),
}

function UI.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = props.Parent
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

function UI.corner(radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UI.stroke(color: Color3?, thickness: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Thickness = thickness or 2,
		Transparency = 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.label(props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
	}
	for k, v in props do
		if k ~= "MaxTextSize" then
			base[k] = v
		end
	end
	return UI.new("TextLabel", base, { UI.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 32 }) })
end

function UI.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local base: { [string]: any } = {
		BackgroundColor3 = UI.Colors.PanelLight,
		Font = Enum.Font.FredokaOne,
		TextColor3 = UI.Colors.Text,
		TextScaled = true,
		AutoButtonColor = true,
	}
	local maxText = props.MaxTextSize or 24
	for k, v in props do
		if k ~= "MaxTextSize" then
			base[k] = v
		end
	end
	local button = UI.new("TextButton", base, {
		UI.corner(10),
		UI.new("UITextSizeConstraint", { MaxTextSize = maxText }),
		UI.new("UIPadding", {
			PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
		}),
	})
	button.Activated:Connect(onClick) -- Activated fires for mouse, touch and gamepad
	return button
end

local screen: ScreenGui = UI.new("ScreenGui", {
	Name = "DesignToImpressUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
})
UI.Screen = screen

local toastHolder = UI.new("Frame", {
	Name = "Toasts",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 90),
	Size = UDim2.new(0.6, 0, 0, 200),
	Parent = screen,
}, {
	UI.new("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

function UI.toast(text: string, color: Color3?)
	local toast = UI.label({
		Text = text,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = color or UI.Colors.Panel,
		MaxTextSize = 22,
		Parent = toastHolder,
	})
	UI.corner(10).Parent = toast
	task.delay(2.5, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

return UI
