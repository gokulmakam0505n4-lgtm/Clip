--!strict
-- Showcase (camera flies to each room, star rating) and Results (podium + ranking list).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

local ShowcaseUI = {}

local PODIUM_VIEW = CFrame.lookAt(Vector3.new(0, 14, 6), Vector3.new(0, 6, -20))
local MEDALS = { "🥇", "🥈", "🥉" }

function ShowcaseUI.Start(state: Folder, remotes: Folder)
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local voteRemote = remotes:WaitForChild("Vote") :: RemoteEvent
	local resultsRemote = remotes:WaitForChild("Results") :: RemoteEvent

	local cameraLocked = false
	local function lockCamera(target: CFrame)
		camera.CameraType = Enum.CameraType.Scriptable
		if cameraLocked then
			TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { CFrame = target }):Play()
		else
			camera.CFrame = target
		end
		cameraLocked = true
	end
	local function unlockCamera()
		if not cameraLocked then
			return
		end
		cameraLocked = false
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	---------------------------------------------------------------- Voting panel
	local votePanel = UI.new("Frame", {
		Name = "Voting", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0, 420, 0, 130), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.05,
		Visible = false, Parent = UI.Screen,
	}, { UI.corner(16), UI.stroke(UI.Colors.Gold) })
	local voteTitle = UI.label({
		Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(1, -20, 0, 34), MaxTextSize = 28, Parent = votePanel,
	})
	local starRow = UI.new("Frame", {
		Position = UDim2.new(0, 10, 0, 50), Size = UDim2.new(1, -20, 0, 66), BackgroundTransparency = 1, Parent = votePanel,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local ownRoomLabel = UI.label({
		Position = UDim2.new(0, 10, 0, 56), Size = UDim2.new(1, -20, 0, 40), MaxTextSize = 22,
		TextColor3 = UI.Colors.Muted, Text = "This is your room! Everyone else is voting...", Parent = votePanel,
	})

	local currentOwner = 0
	local myStars = 0
	local starButtons: { TextButton } = {}
	local function paintStars()
		for i, b in starButtons do
			b.BackgroundColor3 = if i <= myStars then UI.Colors.Gold else UI.Colors.PanelLight
		end
	end
	for i = 1, 5 do
		starButtons[i] = UI.button({
			Name = "Star" .. i, LayoutOrder = i, Text = "⭐", Size = UDim2.new(0, 66, 0, 66), MaxTextSize = 40, Parent = starRow,
		}, function()
			if currentOwner == 0 or currentOwner == player.UserId then
				return
			end
			myStars = i
			paintStars()
			voteRemote:FireServer(currentOwner, i)
		end)
	end

	local function showRoom()
		local idx = state:GetAttribute("ShowcaseIndex")
		if state:GetAttribute("Phase") ~= "Showcase" or typeof(idx) ~= "number" or idx < 1 then
			return
		end
		local plotIndex = state:GetAttribute("ShowcasePlot")
		local root = workspace:FindFirstChild("DesignToImpress")
		local plots = root and root:FindFirstChild("Plots")
		local plot = plots and typeof(plotIndex) == "number" and plots:FindFirstChild("Plot" .. plotIndex)
		if plot then
			lockCamera(plot:GetAttribute("CameraCFrame") :: CFrame)
		end
		currentOwner = (state:GetAttribute("ShowcaseOwner") or 0) :: number
		myStars = 0
		paintStars()
		local name = (state:GetAttribute("ShowcaseOwnerName") or "?") :: string
		local index = (state:GetAttribute("ShowcaseIndex") or 1) :: number
		local total = (state:GetAttribute("ShowcaseTotal") or 1) :: number
		local isMine = currentOwner == player.UserId
		voteTitle.Text = string.format("%s's room  (%d/%d)", name, index, total)
		starRow.Visible = not isMine
		ownRoomLabel.Visible = isMine
		votePanel.Visible = true
	end
	state:GetAttributeChangedSignal("ShowcaseIndex"):Connect(showRoom)

	---------------------------------------------------------------- Results panel
	local resultsPanel = UI.new("Frame", {
		Name = "Results", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.55, 0),
		Size = UDim2.new(0, 300, 0, 320), BackgroundColor3 = UI.Colors.Panel, BackgroundTransparency = 0.05,
		Visible = false, Parent = UI.Screen,
	}, { UI.corner(16), UI.stroke(UI.Colors.Gold) })
	UI.label({
		Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(1, -20, 0, 36), Text = "🏆 Results", TextColor3 = UI.Colors.Gold,
		MaxTextSize = 30, Parent = resultsPanel,
	})
	local resultsList = UI.new("ScrollingFrame", {
		Position = UDim2.new(0, 10, 0, 50), Size = UDim2.new(1, -20, 1, -60), BackgroundTransparency = 1,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = resultsPanel,
	}, {
		UI.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	resultsRemote.OnClientEvent:Connect(function(ranking: { any })
		for _, child in resultsList:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for _, entry in ranking do
			local medal = MEDALS[entry.Place] or ("#" .. entry.Place)
			local mine = entry.UserId == player.UserId
			UI.label({
				LayoutOrder = entry.Place,
				Size = UDim2.new(1, 0, 0, 44),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 18,
				TextColor3 = if mine then UI.Colors.Gold else UI.Colors.Text,
				Text = string.format("%s %s  %.1f⭐ (%d votes)\n+%d coins  +%d XP", medal, entry.Name, entry.Score, entry.Votes, entry.Coins, entry.XP),
				Parent = resultsList,
			})
			if mine then
				UI.toast(string.format("You placed %s! +%d coins", medal, entry.Coins), UI.Colors.Good)
			end
		end
		resultsPanel.Visible = true
		lockCamera(PODIUM_VIEW)
	end)

	local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent
	notifyRemote.OnClientEvent:Connect(function(message: string)
		UI.toast(message)
	end)

	---------------------------------------------------------------- Phase changes
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = state:GetAttribute("Phase")
		if phase ~= "Showcase" then
			votePanel.Visible = false
			currentOwner = 0
		end
		if phase ~= "Results" then
			resultsPanel.Visible = false
		end
		if phase ~= "Showcase" and phase ~= "Results" then
			unlockCamera()
		end
	end)
	-- Joining mid-showcase: jump straight to the current room.
	showRoom()
end

return ShowcaseUI
