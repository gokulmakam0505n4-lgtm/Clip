--!strict
-- Lobby leaderboard: players in this server, ranked by wins, then level.

local Players = game:GetService("Players")

local LeaderboardService = {}

function LeaderboardService.Start(board: Part)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 220, 90)
	title.Text = "TOP DESIGNERS"
	title.Parent = gui

	local rows: { TextLabel } = {}
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(0.9, 0.08)
		row.Position = UDim2.fromScale(0.05, 0.17 + (i - 1) * 0.082)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.new(1, 1, 1)
		row.Text = ""
		row.Parent = gui
		rows[i] = row
	end

	task.spawn(function()
		while true do
			local list = Players:GetPlayers()
			table.sort(list, function(a, b)
				local aw, bw = (a:GetAttribute("Wins") or 0) :: number, (b:GetAttribute("Wins") or 0) :: number
				if aw ~= bw then
					return aw > bw
				end
				return ((a:GetAttribute("Level") or 1) :: number) > ((b:GetAttribute("Level") or 1) :: number)
			end)
			for i, row in rows do
				local p = list[i]
				if p then
					row.Text = string.format("%d. %s   🏆 %d   ⭐ Lv %d", i, p.DisplayName,
						(p:GetAttribute("Wins") or 0) :: number, (p:GetAttribute("Level") or 1) :: number)
				else
					row.Text = ""
				end
			end
			task.wait(5)
		end
	end)
end

return LeaderboardService
