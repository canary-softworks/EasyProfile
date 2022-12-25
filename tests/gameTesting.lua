-- // Create datastore

local DataService = require(game:GetService("ReplicatedStorage"):WaitForChild("DataService"))
local PlayersService = game:GetService("Players")

local DefaultData = {Cash = 100; Gems = 10; Coins = 100}
local PlayerDataStore = DataService.CreateDataStore("PlayerData", DefaultData)

local Formatter = "%02i"

-- // Set up workspace

local CashPrompt = workspace.Cash.Prompt
local GemsPrompt = workspace.Gems.Prompt

CashPrompt.Triggered:Connect(function(player)
	local PlayerCash: NumberValue = player:WaitForChild("leaderstats"):WaitForChild("Cash")
	local PlayerCoins: NumberValue = player:WaitForChild("leaderstats"):WaitForChild("Coins")
	
	PlayerCash.Value += 10
	PlayerCoins.Value += 50
end)

GemsPrompt.Triggered:Connect(function(player)
	local PlayerGems: NumberValue = player:WaitForChild("leaderstats"):WaitForChild("Gems")
	
	PlayerGems.Value += 5
end)

-- // Connect to datastore events

PlayerDataStore.SessionLockUnclaimed:Connect(function(player: Player)
	print(string.format("Session lock for %s was unclaimed.", player.Name))
end)

PlayerDataStore.SessionLockClaimed:Connect(function(player: Player)
	print(string.format("Session lock for %s was claimed.", player.Name))
end)

-- // Set up data

PlayersService.PlayerAdded:Connect(function(player)
	local PlayerData = PlayerDataStore:LoadDataAsync(player, true)
	
	for _, player in ipairs(PlayerDataStore:GetLoadedPlayers()) do
		print(player.Name)
	end
	
	PlayerData.DataLoaded:Connect(function()
		local Leaderstats = {"Cash", "Gems", "Coins"}
		local MetaData = PlayerData:GetMetaData()
		local FormattedTime = os.date("!*t", MetaData.DataCreated)
		
		PlayerData:CreateLeaderstats(Leaderstats)
		
		print("Create Time: " .. Formatter:format(FormattedTime.month) .. "/" .. Formatter:format(FormattedTime.day) .. "/" .. FormattedTime.year, "Load Count: " .. MetaData.DataLoadCount)
	end)
end)

PlayersService.PlayerRemoving:Connect(function(player)
	local Leaderstats = player:WaitForChild("leaderstats")
	
	PlayerDataStore:UnclaimSessionLock(player, {
		Cash = Leaderstats:WaitForChild("Cash").Value;
		Gems = Leaderstats:WaitForChild("Gems").Value;
		Coins = Leaderstats:WaitForChild("Coins").Value;
	})
end)
