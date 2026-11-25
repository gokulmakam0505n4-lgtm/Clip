--!strict
-- Central tuning for Design to Impress. Change numbers here, not in the scripts.

local RunService = game:GetService("RunService")
local IS_STUDIO = RunService:IsStudio()

local Config = {}

-- Round timings (seconds). In Studio the phases are shortened so you can test quickly.
Config.IntermissionTime = if IS_STUDIO then 10 else 20
Config.ThemeRevealTime = 4
Config.DesignTime = if IS_STUDIO then 90 else 300 -- 5 minutes live
Config.ShowcaseTimePerRoom = 10
Config.ResultsTime = 10

-- Rounds start once this many players are in the server (1 in Studio for solo testing).
Config.MinPlayers = if IS_STUDIO then 1 else 2
Config.MaxPlots = 12

-- Room geometry (studs).
Config.RoomSize = 24 -- floor is RoomSize x RoomSize
Config.WallHeight = 14
Config.GridSize = 1
Config.MaxItemsPerRoom = 60

-- Rewards.
Config.PlaceRewards = {
	{ Coins = 100, XP = 60 }, -- 1st
	{ Coins = 60, XP = 40 }, -- 2nd
	{ Coins = 40, XP = 30 }, -- 3rd
}
Config.ParticipationReward = { Coins = 15, XP = 15 }

-- XP needed to go from level N to N+1 is XPPerLevel * N.
Config.XPPerLevel = 100

Config.Themes = {
	{ Name = "Haunted Bedroom", Hint = "Spooky, dark and a little bit creepy." },
	{ Name = "Dream Café", Hint = "Cosy seats, warm lights, somewhere to sip a latte." },
	{ Name = "Gamer Setup", Hint = "Screens, neon and the comfiest chair you own." },
}

Config.DataStoreName = "DTI_PlayerData_v1"

return Config
