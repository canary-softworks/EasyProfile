# In Game Example

Here is an example of how you can use EasyProfile in your game!

Below is a `ModuleScript` that will be handling all of our player's data. This is a traditional method that has been used with ProfileService and that can be used with EasyProfile. 

When handling data we use `playerProfile:GetProfileData` instead of `Profile.Data` which you would use to access data with ProfileService.

Lets start off by seeing how we would handle the players data when they join.

```lua
local EasyProfile = require(location)

-- Params: ProfileStoreName, Data that will be given to the player when they join for the first time
local PlayerDataStore = EasyProfile.CreateProfileStore("PlayerDataStore.V1", {})

local dataModule = {
	Profiles = {}, -- This is where we would store all of our players profiles, we put it under the module so that we can access these players profiles in other scripts if we need to. 
}

function dataModule:Joined(player: Player)
    -- Loads the player's profile
	PlayerDataStore:LoadProfileAsync(player):After(function(success, playerProfile)
        if not success then
            -- If something went wrong it would let us know
			warn("Not successful in retrieving " .. player.DisplayName)
			return
		end

        -- Here we add the player's profile data to the profiles table
		dataModule.Profiles[player.UserId] = playerProfile:GetProfileData()

        -- An example of editing the player's data
		dataModule.Profiles[player.UserId]["Foo"] = 1
	end)
end

return dataModule
```

Now to handle data when the player leaves we would add this:

```lua
local EasyProfile = require(location)

-- Params: ProfileStoreName, Data that will be given to the player when they join for the first time
local PlayerDataStore = EasyProfile.CreateProfileStore("PlayerDataStore.V1", {})

local dataModule = {
	Profiles = {}, -- This is where we would store all of our players profiles, we put it under the module so that we can access these players profiles in other scripts if we need to. 
}

function dataModule:Joined(player: Player)
    -- Loads the player's profile
	PlayerDataStore:LoadProfileAsync(player):After(function(success, playerProfile)
        if not success then
            -- If something went wrong it would let us know
			warn("Not successful in retrieving " .. player.DisplayName)
			return
		end

        -- Here we add the player's profile data to the profiles table
		dataModule.Profiles[player.UserId] = playerProfile:GetProfileData()

        -- An example of editing the player's data
		dataModule.Profiles[player.UserId]["Foo"] = 1
	end)
end

function dataModule:Leaving(player)
    -- Printing the data so that we can see what is being saved
	print(dataModule.Profiles[player.UserId])

    -- Unclaiming the session
	PlayerDataStore:UnclaimSessionLock(player)

    -- Removing the player's profile from the profiles table as we no longer need it
    dataModule.Profiles[player.UserId] = nil
end

return dataModule
```
