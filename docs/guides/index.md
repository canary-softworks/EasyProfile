# Profile Stores

If you have ever used ProfileService before, you have probably heard of the `ProfileStore`. It's basically just a [GlobalDataStore](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore), but instead of managing keys, it manages individual profiles instead. These profiles are assigned to a unique ID, so they can be assigned to the player's `UserId`, or it can be it's own thing. Though, first, lets create a new `ProfileStore` using the `DataService.CreateProfileStore` function:

```lua
local DataService = require(game:GetService("ReplicatedStorage").Packages.EasyProfile)
local MyNewDataStore = DataService.CreateProfileStore("MyProfileStore", {Tokens = 100, Gold = 5, Items = {"Wooden Sword"}})
```

Now, we can detect when the player joins, and when they do, we can load in their data by using `ProfileStoreObject:LoadProfileAsync`. This will load in the profile and allow you to interact with the data. Since it returns a Future, we will use the `After` method; please also note that you can use the `Await` method as well which will yield the thread and return the profile object. Here's how you would do the latter:

```lua
local DataService = require(game:GetService("ReplicatedStorage").Packages.EasyProfile)
local PlayerService = game:GetService("Players")
local MyNewDataStore = DataService.CreateProfileStore("MyProfileStore", {Tokens = 100, Gold = 5, Items = {"Wooden Sword"}})

-- // Functions

local function PlayerAdded(player)
    MyNewDataStore:LoadProfileAsync(player):After(function(success, playerProfile)

    end) -- Load the profile, you can also add an optional `reconcile` argument which reconciles the data
end

PlayerService.PlayerAdded:Connect(PlayerAdded)
```

Now sometimes, the player will join before the server script runs. To fix this, we can loop through all of the players after we listen to the player added event, then run the player added function:

```lua
local DataService = require(game:GetService("ReplicatedStorage").Packages.EasyProfile)
local PlayerService = game:GetService("Players")
local MyNewDataStore = DataService.CreateProfileStore("MyProfileStore", {Tokens = 100, Gold = 5, Items = {"Wooden Sword"}})

-- // Functions

local function PlayerAdded(player)
    MyNewDataStore:LoadProfileAsync(player):After(function(success, playerProfile)

    end)
end

PlayerService.PlayerAdded:Connect(PlayerAdded)

for _, player in PlayerService:GetPlayers() do
    task.spawn(PlayerAdded, player)
end
```

Now we are all set! But first, we have to make sure to unclaim the session lock when the player leaves. Doing this is pretty simple, just add this to your script:

```lua
PlayerService.PlayerRemoving:Connect(function(player)
    MyNewDataStore:UnclaimSessionLock(player)
end)
```