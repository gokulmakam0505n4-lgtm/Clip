--!strict
-- Client entry point. Waits for the server's remotes, then starts each UI piece.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("DTIRemotes") :: Folder
local state = remotes:WaitForChild("GameState") :: Folder

local HUD = require(script.Parent:WaitForChild("HUD"))
local BuildController = require(script.Parent:WaitForChild("BuildController"))
local ShowcaseUI = require(script.Parent:WaitForChild("ShowcaseUI"))

HUD.Start(state)
BuildController.Start(state, remotes)
ShowcaseUI.Start(state, remotes)
