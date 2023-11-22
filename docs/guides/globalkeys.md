# Global Keys

Global keys are a better way of handling cross server communication with data, and you can even send data to offline `UserId`'s. It uses the Global Updates feature of ProfileService internally, and that system is very confusing which is why we made our own. There's really only 3 functions to learn, so it should be pretty straightforward to learn.

To start, we can create and setup our profile store just as how we did previously:

```lua
local DataService = require(game:GetService("ReplicatedStorage").Packages.EasyProfile)
local PlayerService = game:GetService("Players")
local MyNewDataStore = DataService.CreateProfileStore("MyProfileStore", {Tokens = 100, Gold = 5, Items = {"Wooden Sword"}})

-- // Functions

local function PlayerAdded(player)
    MyNewDataStore:LoadProfileAsync(player):After(function(success, playerProfile)
        if not success then
            return
        end
    end)
end

PlayerService.PlayerRemoving:Connect(function(player)
    MyNewDataStore:UnclaimSessionLock(player)
end)

PlayerService.PlayerAdded:Connect(PlayerAdded)

for _, player in PlayerService:GetPlayers() do
    task.spawn(PlayerAdded, player)
end
```

First, in our `PlayerAdded` function, lets send a new global key out to ourselves by using the `ProfileStoreObject:SetGlobalKeyAsync` method:

```lua
local function PlayerAdded(player)
    MyNewDataStore:LoadProfileAsync(player):After(function(success, playerProfile)
        if not success then
            return
        end

        MyNewDataStore:SetGlobalKeyAsync(player.UserId, "GlobalKeyTest", "somerandomstringdata") -- The first argument is the player who is recieving it, and the others are the key name followed by the value
    end)
end
```

To listen when the player recieves a new key in-game, you can use the `ProfileObject.GlobalKeyAdded` event, it will fire when a new key is added:

```lua
local function PlayerAdded(player)
    MyNewDataStore:LoadProfileAsync(player):After(function(success, playerProfile)
        if not success then
            return
        end

        playerProfile.GlobalKeyAdded:Connect(function(globalKey)
            print(globalKey) -- Output: {Key = "GlobalKeyTest", Value = {this = "is a test"}, KeyId = 1}
        end)

        MyNewDataStore:SetGlobalKeyAsync(player.UserId, "GlobalKeyTest", "somerandomstringdata")
    end)
end
```

Please note that when doing this, you must wait around 60 seconds for the key to be recieved. Though next, we should setup a way for us to recieve keys that we got when were offline. In order to do this, you can use the `ProfileObject:GetGlobalKeys` method, it returns a table of global keys that we can loop through:

```lua
local function PlayerAdded(player)
    MyNewDataStore:LoadProfileAsync(player):After(function(success, playerProfile)
        if not success then
            return
        end
        
        for _, globalKey in playerProfile:GetGlobalKeys() do
           print(globalKey.Key, ":", globalKey.Value) -- Output: GlobalKeyTest : somerandomstringdata
        end

        playerProfile.GlobalKeyAdded:Connect(function(globalKey)
            print(globalKey) -- Output: {Key = "GlobalKeyTest", Value = "somerandomstringdata", KeyId = 2}
        end)

        MyNewDataStore:SetGlobalKeyAsync(player.UserId, "GlobalKeyTest", "somerandomstringdata")
    end)
end
```

Please do note that there is a difference between `GlobalKey`'s and regular keys. `GlobalKey`'s are supposed to be global: they can be recieved globally, and regular keys are just for the individual player that owns the profile.

### Extras

There are a few extra functions you should know about. Here is a table of them: 

|Function|Description|
|-|-|
|`ProfileObject:GetDataUsage`|Allows you to measure the size of the profile's data, in a percentage (%)|
|`ProfileObject:GetMetaData`|Gets specific meta data about the profile, such as the amount of times it was loaded.|
|`ProfileStoreObject:GetProfileAsync`|Gets the profile data for a specific `UserId`, useful for getting anyones data and overwriting it. Any edited values will not reflect to the profile unless overwrite is called.|