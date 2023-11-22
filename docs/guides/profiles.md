# Profiles

Now we can get started on profiles. As explained in the introduction, profiles are essentially the successor to datastore keys. These are much easier to use and make the process of data saving so much easier. Setting the data here is as simple as editing a table. No getter or setter functions, you can make your own.

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