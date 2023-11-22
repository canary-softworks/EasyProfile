# Leaderstats

When using EasyProfile, Roblox's player list `leaderstats` are rather easy to setup. You only need to call 1 function. Here's an example of leaderstats being set up when the player joins:

```lua
local function PlayerAdded(player)
    MyNewDataStore:LoadProfileAsync(player):After(function(success, playerProfile)
        if not success then
            return
        end

        playerProfile:CreateProfileLeaderstats(player, {"Tokens", "Gold"}) -- The leaderstats folder is also returned here, in case you want to mod values
    end)
end
```

When they join, your leaderboard should look just like this: 

![Player list example](images/datastoring-images/playerlist-example.png)