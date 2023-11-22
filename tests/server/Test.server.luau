local EasyProfile = require(game:GetService("ServerStorage").Packages.EasyProfile)
local Players = game:GetService("Players")
local DataStore = EasyProfile.CreateProfileStore("TestDataStore", {
    Items = {"Sword"},
    Coins = 100,
    Gems = 5,
})

Players.PlayerAdded:Connect(function(player)
    DataStore:LoadProfileAsync(player, true):After(function(success, profileObject)
        local ProfileData = profileObject:GetProfileData()

        print(ProfileData)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    DataStore:UnclaimSessionLock(player)
end)