local EasyProfile = require(game:GetService("ReplicatedStorage").Packages.EasyProfile)
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

        for _, globalKey in profileObject:GetGlobalKeys() do
            print(globalKey)
        end

        profileObject.GlobalKeyAdded:Connect(function(globalKey)
            print(globalKey)
        end)

        DataStore:SetGlobalKeyAsync(player.UserId, "Test", `Hello {player.UserId}! Welcome to the testing area`)
    end)

    DataStore:GetProfileAsync(player.UserId):After(function(success, data)
        print(success, data)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    DataStore:UnclaimSessionLock(player)
end)