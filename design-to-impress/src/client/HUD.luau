--!strict
-- Top bar (phase, theme, timer), player stats (coins, level, XP bar) and the theme reveal splash.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

local HUD = {}

local PHASE_TEXT = {
	Waiting = "Waiting for more players...",
	Intermission = "Next round starting soon",
	Theme = "The theme is...",
	Design = "Design your room!",
	Showcase = "Showcase - rate each room",
	Results = "Results!",
}

function HUD.Start(state: Folder)
	local player = Players.LocalPlayer
	local screen = UI.Screen

	local bar = UI.new("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0.5, 0, 0, 72),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = screen,
	}, {
		UI.corner(14),
		UI.stroke(UI.Colors.Accent),
		UI.new("UISizeConstraint", { MinSize = Vector2.new(300, 0), MaxSize = Vector2.new(560, math.huge) }),
	})
	local phaseLabel = UI.label({
		Name = "Phase", Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -110, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 26, Parent = bar,
	})
	local themeLabel = UI.label({
		Name = "Theme", Position = UDim2.new(0, 12, 0, 38), Size = UDim2.new(1, -110, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UI.Colors.Gold, MaxTextSize = 22, Parent = bar,
	})
	local timerLabel = UI.label({
		Name = "Timer", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 90, 0, 50), TextXAlignment = Enum.TextXAlignment.Right, MaxTextSize = 40, Parent = bar,
	})

	-- Stats, top-left (clear of the mobile thumbstick and jump button).
	local stats = UI.new("Frame", {
		Name = "Stats",
		Position = UDim2.new(0, 10, 0, 90),
		Size = UDim2.new(0, 170, 0, 62),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.2,
		Parent = screen,
	}, { UI.corner(12) })
	local coinsLabel = UI.label({
		Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -20, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, TextColor3 = UI.Colors.Gold, Parent = stats,
	})
	local levelLabel = UI.label({
		Position = UDim2.new(0, 10, 0, 28), Size = UDim2.new(1, -20, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 15, Parent = stats,
	})
	local xpBack = UI.new("Frame", {
		Position = UDim2.new(0, 10, 0, 47), Size = UDim2.new(1, -20, 0, 8),
		BackgroundColor3 = Color3.fromRGB(20, 15, 30), Parent = stats,
	}, { UI.corner(4) })
	local xpFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = UI.Colors.Accent, Parent = xpBack,
	}, { UI.corner(4) })

	local function refreshStats()
		local coins = (player:GetAttribute("Coins") or 0) :: number
		local level = (player:GetAttribute("Level") or 1) :: number
		local into = (player:GetAttribute("XPIntoLevel") or 0) :: number
		local need = (player:GetAttribute("XPForNextLevel") or 100) :: number
		coinsLabel.Text = "🪙 " .. coins
		levelLabel.Text = string.format("Level %d  (%d / %d XP)", level, into, need)
		TweenService:Create(xpFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(math.clamp(into / need, 0, 1), 1) }):Play()
	end
	for _, attr in { "Coins", "Level", "XPIntoLevel", "XPForNextLevel" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshStats)
	end
	refreshStats()

	-- Theme reveal splash.
	local splash = UI.new("Frame", {
		Name = "ThemeSplash",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.8, 0.3),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	local splashTheme = UI.label({
		Size = UDim2.fromScale(1, 0.65), TextColor3 = UI.Colors.Gold, MaxTextSize = 90, Parent = splash,
		TextStrokeTransparency = 0.3,
	})
	local splashHint = UI.label({
		Position = UDim2.fromScale(0, 0.65), Size = UDim2.fromScale(1, 0.3), MaxTextSize = 32, Parent = splash,
		TextStrokeTransparency = 0.5,
	})

	local function refreshPhase()
		local phase = state:GetAttribute("Phase") :: string
		local theme = (state:GetAttribute("Theme") or "") :: string
		local text = PHASE_TEXT[phase] or phase
		if phase == "Design" and player:GetAttribute("PlotIndex") == nil then
			text = "Spectating - you'll build next round"
		end
		phaseLabel.Text = text
		themeLabel.Text = if theme ~= "" and phase ~= "Theme" then "Theme: " .. theme else ""

		if phase == "Theme" then
			splashTheme.Text = theme
			splashHint.Text = (state:GetAttribute("ThemeHint") or "") :: string
			splash.Visible = true
			splash.Size = UDim2.fromScale(0.2, 0.08)
			TweenService:Create(splash, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.8, 0.3) }):Play()
		else
			splash.Visible = false
		end
	end
	state:GetAttributeChangedSignal("Phase"):Connect(refreshPhase)
	state:GetAttributeChangedSignal("Theme"):Connect(refreshPhase)
	player:GetAttributeChangedSignal("PlotIndex"):Connect(refreshPhase)
	refreshPhase()

	RunService.Heartbeat:Connect(function()
		local endsAt = (state:GetAttribute("EndsAt") or 0) :: number
		local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
		if endsAt <= 0 or state:GetAttribute("Phase") == "Waiting" then
			timerLabel.Text = ""
		else
			timerLabel.Text = string.format("%d:%02d", left // 60, left % 60)
			timerLabel.TextColor3 = if left <= 10 then UI.Colors.Bad else UI.Colors.Text
		end
	end)
end

return HUD
