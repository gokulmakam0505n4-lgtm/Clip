--!strict
-- Entry point: builds the world, creates remotes and starts every service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBuilder = require(script.Parent.WorldBuilder)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local RoundManager = require(script.Parent.RoundManager)
local LeaderboardService = require(script.Parent.LeaderboardService)

local function remote(className: string, name: string, parent: Instance): any
	local r = Instance.new(className)
	r.Name = name
	r.Parent = parent
	return r
end

local remoteFolder = Instance.new("Folder")
remoteFolder.Name = "DTIRemotes"
local placeItem: RemoteFunction = remote("RemoteFunction", "PlaceItem", remoteFolder)
local removeItem: RemoteFunction = remote("RemoteFunction", "RemoveItem", remoteFolder)
local setSurface: RemoteFunction = remote("RemoteFunction", "SetSurface", remoteFolder)
local vote: RemoteEvent = remote("RemoteEvent", "Vote", remoteFolder)
local results: RemoteEvent = remote("RemoteEvent", "Results", remoteFolder)
local notify: RemoteEvent = remote("RemoteEvent", "Notify", remoteFolder)

local state = Instance.new("Folder")
state.Name = "GameState"
state:SetAttribute("Phase", "Waiting")
state:SetAttribute("Theme", "")
state:SetAttribute("EndsAt", 0)
state.Parent = remoteFolder

placeItem.OnServerInvoke = function(player, itemId, x, z, rot)
	return PlotService.Place(player, itemId, x, z, rot)
end
removeItem.OnServerInvoke = function(player, target)
	return PlotService.Remove(player, target)
end
setSurface.OnServerInvoke = function(player, itemId)
	return PlotService.SetSurface(player, itemId)
end

local world = WorldBuilder.Build()
PlotService.Init(world.Plots)
DataService.Start()
LeaderboardService.Start(world.Board)

remoteFolder.Parent = ReplicatedStorage -- parent last so clients see a complete folder
RoundManager.Start(world, { State = state, Vote = vote, Results = results, Notify = notify })
