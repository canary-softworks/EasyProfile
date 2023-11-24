# Profiles

Now we can get started on profiles. As explained in the introduction, profiles are essentially the successor to datastore keys. These are much easier to use and make the process of data saving so much easier. Setting the data here is as simple as editing a table. No getter or setter functions, you can make your own.



<!-- ----------------

```lua
local EasyProfile = require(location)
-- Here we create our ProfileStore, similar to DataStoreService:GetDataStore()
local PlayerDataStore = EasyProfile.CreateProfileStore("PlayerDataStore.V1", {})

local dataModule = {
	Profiles = {}, -- This is where we would store all of our players profiles, we put it under the module so that we can access these players profiles in other scripts if we need to. 
}

-- self: Player
function dataModule:Joined()
	PlayerDataStore:LoadProfileAsync(self):After(function(success, playerProfile)
        if not success then
            -- If something went wrong it would let us know
			warn("Not successful in retrieving " .. self.DisplayName)
			return
		end

        -- Here we add the players profile data to the table above
		dataModule.Profiles[self.UserId] = playerProfile:GetProfileData()

        -- An example of editing the players data
		dataModule.Profiles[self.UserId]["Foo"] = 1
	end)
end

-- self: Player
function dataModule:Leaving()
    -- Printing the data so that we can see what is being saved
	print(dataModule.Profiles[self.UserId])
	PlayerDataStore:UnclaimSessionLock(self)
end

return dataModule
``` -->



----------------

What we will do first is get the data we can edit from the profile. In order to do this, you must call `PlayerProfile:GetProfileData`.

```lua
local function PlayerAdded(player)
    MyNewDataStore:LoadProfileAsync(player):After(function(success, playerProfile)
        if not success then
            return
        end

        local ProfileData = playerProfile:GetProfileData()

        print(ProfileData) -- Output: {Tokens = 100, Gold = 5, Items = {"Wooden Sword"}}
    end)
end
```

Now that we have verified that our code is indeed working, we can now edit the values in the profile data dictionary as so:

```lua
local function PlayerAdded(player)
    MyNewDataStore:LoadProfileAsync(player):After(function(success, playerProfile)
        if not success then
            return
        end

        local ProfileData = playerProfile:GetProfileData()

        print(ProfileData) -- Output: {Tokens = 100, Gold = 5, Items = {"Wooden Sword"}}
        table.insert(ProfileData.Items, "Iron Sword")
        print(ProfileData) -- Output: {Tokens = 100, Gold = 5, Items = {"Wooden Sword", "Iron Sword"}}
    end)
end
```

We can do quite a bit with this, such as increase the user's cash each time they join, or even remove specific items. When we join back, the iron sword should persist if you set up the profile store correctly. Though, there is one more thing you should learn: `GlobalKey`s.