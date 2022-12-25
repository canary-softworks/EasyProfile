export type table = {any}
export type dictionary = {[string]: any}
export type array = {[number]: any}

export type PlayerMetaData = {DataCreated: number; DataLoadCount: number}

-- // Variables

local Package = { }

local Assets = script.Assets
local Plugins = script.Plugins
local Settings = require(script.Settings)

---

local Players = game:GetService("Players")

local LoadedPlayers = { }
local DataStoreObject = { }
local PlayerDataObject = { }
local DataStoreObjectHidden = { }

DataStoreObjectHidden.__index = PlayerDataObject

local ProfileService = require(Plugins.ProfileService)
local Signal = require(Plugins.Signal)

type ScriptSignal = typeof(Signal.new())

-- // Functions

ProfileService.CriticalStateSignal:Connect(function()
	warn("Code 503: DataService is currently experiencing issues with data storing. Try again later.")
end)

local function assert<a>(value: a, callback: () -> ()): a?
	if not value then
		callback()
	end
	return value
end

--[[

	DataService.CreateDataStore(name: string, defaultData: dictionary): DataStoreObject

	Creates / gets a new DataStore, essentially DataStoreService:GetDataStore().
	
	[name]: The name of the DataStore that should be returned.
	[defualtData]: A dictionary of the default data a player will have upon joining the first time.

--]]

function Package.CreateDataStore(name: string, defaultData: dictionary)
	local DataStoreObject = setmetatable({ }, {__index = DataStoreObject})
	local ProfileStore = ProfileService.GetProfileStore(name, defaultData)

	if LoadedPlayers[name] then
		error(string.format("DataService: DataStore '%s' already exists.", name))
	end

	LoadedPlayers[name] = { }

	DataStoreObject.SessionLockClaimed = Signal.new() :: ScriptSignal
	DataStoreObject.SessionLockUnclaimed = Signal.new() :: ScriptSignal
	DataStoreObject.Name = name :: string
	DataStoreObject.DataStore = ProfileStore :: typeof(ProfileStore)

	return DataStoreObject
end

--[[

	DataStoreObject:GetName(): string

	Returns the DataStore's name, useful for debugging.

--]]

function DataStoreObject:GetName(): string
	return self.Name
end

--[[

	DataStoreObject:GetLoadedPlayers(): {Player}

	Returns a table of all the players that were loaded from when this function was called.
	Can be useful for seeing if all player's data is loaded.

--]]

function DataStoreObject:GetLoadedPlayers(): {Player}
	local PlayersTable = { }

	for player, data in pairs(LoadedPlayers[self.Name]) do
		table.insert(PlayersTable, player)
	end

	return PlayersTable
end

--[[

	DataStoreObject:RemoveDataAsync(userId: number): nil

	Wipes a user's data, can be helpful for dealing with GDPR compliance in-game.
	
	[userId]: The UserId of the player that the data should be removed from.

--]]

function DataStoreObject:RemoveDataAsync(userId: number)
	self.DataStore:WipeProfileAsync(string.format(Settings.KeyStringPattern, userId))
end

--[[

	DataStoreObject:GetDataAsync(userId: number): dictionary?

	Returns a read-only dictionary of `userId`'s data.
	
	[userId]: The UserId of the player that the data should be viewed from.

--]]

function DataStoreObject:GetDataAsync(userId: number): dictionary?
	local RequestedData = self.DataStore:ViewProfileAsync(string.format(Settings.KeyStringPattern, userId)).Data

	if RequestedData then
		return table.freeze(RequestedData)
	else
		warn(string.format("Requested data for user %d does not exist.", userId))
	end

	return
end

--[[

	DataStoreObject:LoadDataAsync(player: Player, reconcileData: boolean?): PlayerDataObject

	Loads the player data and allows you to change it.
	
	[player]: The player the data should be loaded for.
	[reconcileData (Optional)]: If you changed the `defaultData` argument in your datastore, this argument
	determines if any new/removed keys from the default data should apply to the person you are loading data to.
	Defaults to true. 

--]]

function DataStoreObject:LoadDataAsync(player: Player, reconcileData: boolean?)
	reconcileData = reconcileData or true
	
	assert(player, function()
		error("DataService: Cannot load player data without player object.")
	end)

	local PlayerDataObject = setmetatable({ }, DataStoreObjectHidden)
	local PlayerProfile = self.DataStore:LoadProfileAsync(string.format(Settings.KeyStringPattern, player.UserId))

	self.SessionLockClaimed:Fire(player)

	PlayerDataObject.Name = self.Name :: string
	PlayerDataObject.Player = player :: Player

	PlayerDataObject.KeyChanged = Signal.new() :: ScriptSignal
	PlayerDataObject.KeyRemoved = Signal.new() :: ScriptSignal
	PlayerDataObject.DataLoaded = Signal.new() :: ScriptSignal

	if PlayerProfile then
		PlayerProfile:AddUserId(player.UserId)

		if reconcileData then
			PlayerProfile:Reconcile()
		end

		PlayerProfile:ListenToRelease(function()
			LoadedPlayers[self.Name][player] = nil
			setmetatable(PlayerDataObject, nil)
			
			player:Kick("DataService\n\nPlayer data was loaded on another server or did not leave.")
		end)

		if player:IsDescendantOf(Players) then
			LoadedPlayers[self.Name][player] = PlayerProfile

			task.defer(function()
				repeat task.wait() until PlayerDataObject.DataLoaded._listening == true
				PlayerDataObject.DataLoaded:Fire()
			end)
		else
			PlayerProfile:Release()
		end
	else
		player:Kick("DataService\n\nPlayer data was trying to be loaded on another server at the same time.")
	end

	return PlayerDataObject
end

--[[

	DataStoreObject:UnclaimSessionLock(self: any, player: Player, valuesToSave: dictionary?): nil

	Unclaims the data session lock of the loaded player data.
	
	Only use this function when the player is leaving/teleporting,
	or else the player will be kicked from the game.
	
	[player]: The player whose session lock should be unclaimed.
	[valuesToSave (Optional)]: Values to save when the player's
	session lock is unclaimed. For example, you might have attri-
	butes in the player that store data, and you want that data
	to be saved when the player leaves.

--]]

function DataStoreObject:UnclaimSessionLock(player: Player, valuesToSave: dictionary?)
	local PlayerData = LoadedPlayers[self.Name][player]

	if PlayerData then
		if valuesToSave then
			for key, value in pairs(valuesToSave) do
				if PlayerData.Data[key] and typeof(value) ~= "Instance" then
					PlayerData.Data[key] = value
				else
					error(string.format("DataService: Invalid key: '%s' is an instance or does not exist.", key))
				end
			end
		end

		PlayerData:Release()
		self.SessionLockUnclaimed:Fire(player)
	else
		warn(string.format("%s's data is not currently session-locked.", player.Name))
	end
end

function DataStoreObject:SetGlobalKey(userId: number, keyType: string, data: dictionary)
	-- self.DataStore:GlobalUpdateProfileAsync(userId, function(GlobalUpdates)
	-- GlobalUpdates:AddActiveUpdate({
	--	 Type = keyType;
	-- 	 Data = data;
	--	})
	--	end)
end

function DataStoreObject:GetGlobalKey(userId: number, keyType: string): any
	return
end

--[[

	PlayerData:CreateLeaderstats(self: any, keys: {string}): nil

	Creates leaderstats for the player based on `keys`.
	
	[keys]: For each string in this parameter, a new value will
	be created to it's corresponding type. The value will be
	the value saved to datastore, and the name will be the key
	provided.

--]]

function PlayerDataObject:CreateLeaderstats(keys: {string})
	local Leaderstats = Instance.new("Folder")
	local ValueTypes = {
		["number"] = "NumberValue";
		["string"] = "StringValue";
		["boolean"] = "BoolValue";
	}

	Leaderstats.Name = "leaderstats"
	Leaderstats.Parent = self.Player

	for _, value in keys do
		if type(self:GetKey(value)) == "number" or type(self:GetKey(value)) == "boolean" or type(self:GetKey(value)) == "string" then
			local NewValue = Instance.new(ValueTypes[type(self:GetKey(value))])

			NewValue.Value = self:GetKey(value)
			NewValue.Name = value

			NewValue.Parent = Leaderstats
		end
	end
end

--[[

	PlayerData:SetKey(self: any, key: string, value: any): nil

	Sets/adds `key` and sets its value to `value`
	
	[key]: The key to be set/added.
	[value]: The value that `key` should be set to.

--]]

function PlayerDataObject:SetKey(key: string, value: any)
	local PlayerData = LoadedPlayers[self.Name][self.Player]

	if PlayerData then
		PlayerData.Data[key] = value
		self.KeyChanged:Fire(key, value)
	end
end

--[[

	PlayerData:GetKey(self: any, key: string): any

	Returns `key` if it exists.
	
	[key]: The key to be returned.

--]]

function PlayerDataObject:GetKey(key: string): any
	local PlayerData = LoadedPlayers[self.Name][self.Player]

	if PlayerData and PlayerData.Data[key] then
		return PlayerData.Data[key]
	else
		error(string.format("Key '%s' does not exist.", key))
		return nil
	end
end

--[[

	PlayerData:RemoveKey(self: any, key: string): nil

	Removes `key` from data if it exists.
	
	[key]: The key to remove.

--]]

function PlayerDataObject:RemoveKey(key: string)
	local PlayerData = LoadedPlayers[self.Name][self.Player]

	if PlayerData and PlayerData.Data[key] then
		PlayerData.Data[key] = nil
		self.KeyRemoved:Fire(key)
	else
		error(string.format("Key '%s' does not exist.", key))
	end
end

--[[

	PlayerData:GetKeyChangedSignal(self: any, key: string): ScriptSignal

	Returns a ScriptSignal that fires whenever `key` is changed.
	
	[key]: The key to be monitored.

--]]

function PlayerDataObject:GetKeyChangedSignal(key: string): ScriptSignal
	local PlayerData = LoadedPlayers[self.Name][self.Player]
	local event = Signal.new()

	if PlayerData and PlayerData.Data[key] then
		self.KeyChanged:Connect(function(changedKey, changedValue)
			if key == changedKey then
				event:Fire(changedValue)
			end
		end)

		return event
	else
		error(string.format("Key '%s' does not exist.", key))
	end
end

--[[

	PlayerData:GetMetaData(self: any): PlayerMetaData

	Returns metadata about a player. Data types include
	the os.time() when the data for the player was cre-
	ated, and the amount of times it was loaded ever.

--]]

function PlayerDataObject:GetMetaData(): PlayerMetaData
	local PlayerData = LoadedPlayers[self.Name][self.Player]
	
	return {DataCreated = PlayerData.MetaData.ProfileCreateTime; DataLoadCount = PlayerData.MetaData.SessionLoadCount}
end

return Package
