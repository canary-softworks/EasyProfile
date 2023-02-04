type table = {any}
type dictionary = {[string]: any}
type array = {[number]: any}

type PlayerMetaData = {DataCreated: number; DataLoadCount: number}
type SessionMetaData = {Name: string; LoadedAt: number; Key: string}
type ScriptConnection = {Disconnect: (self: any) -> (); Connected: boolean}
type ScriptSignal = {
	Connect: (self: any, func: (...any) -> ()) -> (ScriptConnection);
	Wait: (self: any) -> (...any);
	Once: (self: any, func: (...any) -> ()) -> (ScriptConnection);
}

-- // Variables

local Package = { }

local Assets = script.Assets
local Plugins = script.Plugins
local Settings = require(script.Settings)

---

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LoadedPlayers = { }

local DataStoreObject = { }
local PlayerDataObject = { }

local ProfileService = require(Plugins.ProfileService)
local Signal = require(Plugins.Signal)
local console = require(Plugins.Console)
local OptionalParam = require(Plugins.OptionalParam)

-- // Functions

ProfileService.CriticalStateSignal:Connect(function()
	console.warn("Code 503: DataService is currently experiencing issues with data storing. Try again later.")
end)

--[[

	Creates / gets a DataStore, equivalent to
	`DataStoreService:GetDataStore()`.
	
	@param [string] name - The name of the data-
	store to get.
	
	@param [dictionary] defaultData - The data
	to give to a player when they are new to a
	game.
	
	@returns [DataStoreObject]

--]]

function Package.CreateDataStore(name: string, defaultData: dictionary)
	local DataStoreObject = setmetatable({ }, {__index = DataStoreObject})
	local ProfileStore = ProfileService.GetProfileStore(name, defaultData)

	if LoadedPlayers[name] then
		console.error(`A DataStore named '{name}' already exists.`)
	end

	LoadedPlayers[name] = { }

	DataStoreObject.SessionLockClaimed = Signal.new() :: ScriptSignal
	DataStoreObject.SessionLockUnclaimed = Signal.new() :: ScriptSignal
	
	DataStoreObject.Name = name :: string
	DataStoreObject.ClassName = "DataStoreObject" :: string
	DataStoreObject.DataStore = ProfileStore :: any
	
	table.freeze(DataStoreObject)

	return DataStoreObject
end

--[[

	Gets all loaded players in a DataStoreObject.
	
	@returns [array] An array of players.

--]]

function DataStoreObject:GetLoadedPlayers(): {Player}
	local PlayersTable = { }

	for player, data in pairs(LoadedPlayers[self.Name]) do
		table.insert(PlayersTable, player)
	end

	return PlayersTable
end

--[[

	Completely wipes a player's data,
	useful for complying with GDPR in
	a live game.
	
	@param [number] userId - The userId
	of the whose data to wipe.
	
	@returns [void]

--]]

function DataStoreObject:RemoveDataAsync(userId: number)
	self.DataStore:WipeProfileAsync(string.format(Settings.KeyStringPattern, userId))
end

--[[

	Allows you to view a player's data that
	is not in-game.
	
	@param [number] userId - The `userId` of 
	the player to view the data of
	
	@returns [dictionary?] - A player's data,
	you can make changes to it though they will
	not save.

--]]

function DataStoreObject:GetDataAsync(userId: number): dictionary?
	local RequestedData = self.DataStore:ViewProfileAsync(string.format(Settings.KeyStringPattern, userId)).Data

	if RequestedData then
		return RequestedData
	else
		console.silentError(`Requested data for user {userId} does not exist.`)
	end

	return
end

--[[

	Loads the provided player's data, unlike
	`DataStoreObject:GetDataAsync()`, this can
	be used to edit/save a player's data, only
	if they are in the running server.
	
	@param [Player] player - The player to load
	the data from.
	
	@param [?boolean] reconcileData - If you
	change your `defaultData`, the next time
	the player loads in their data it will
	reflect those changes. Note: It will
	only reset keys, all values will
	remain the same.
	
	@returns [PlayerDataObject]

--]]

function DataStoreObject:LoadDataAsync(player: Player, reconcileData: boolean?, claimedHandler: (placeId: number, gameJobId: string) -> () | "ForceLoad" | "Cancel"?)
	local PlayerDataObject = setmetatable({ }, {__index = PlayerDataObject})
	
	reconcileData = OptionalParam(reconcileData, true)
	claimedHandler = OptionalParam(claimedHandler, "ForceLoad")
	
	local PlayerData = self.DataStore:LoadProfileAsync(string.format(Settings.KeyStringPattern, player.UserId), claimedHandler)
	
	local Created = os.time()
	local LoadedSignal = Signal.new()

	self.SessionLockClaimed:Fire(player)

	PlayerDataObject.Name = self.Name :: string
	PlayerDataObject.Player = player :: Player
	
	PlayerDataObject.LoadedAt = Created

	PlayerDataObject.KeyChanged = Signal.new() :: ScriptSignal
	PlayerDataObject.KeyAdded = Signal.new() :: ScriptSignal
	PlayerDataObject.KeyRemoved = Signal.new() :: ScriptSignal
	PlayerDataObject.GlobalKeyAdded = Signal.new() :: ScriptSignal

	task.defer(function()
		if PlayerData then
			PlayerData:AddUserId(player.UserId)

			if reconcileData then
				PlayerData:Reconcile()
			end

			PlayerData:ListenToRelease(function()
				LoadedPlayers[self.Name][player] = nil
				
				setmetatable(PlayerDataObject, nil)
				table.clear(PlayerDataObject)

				player:Kick(`Could not save data for user {player.UserId}; possible data corruption. Retry later.`)
			end)

			if player:IsDescendantOf(Players) then
				LoadedPlayers[self.Name][player] = PlayerData
				
				for _, globalKey in ipairs(PlayerData.GlobalUpdates:GetActiveUpdates()) do
					PlayerData.GlobalUpdates:LockActiveUpdate(globalKey[1])
				end
				
				PlayerData.GlobalUpdates:ListenToNewActiveUpdate(function(id, data)
					PlayerData.GlobalUpdates:LockActiveUpdate(id)
				end)
				
				PlayerData.GlobalUpdates:ListenToNewLockedUpdate(function(id, data)
					PlayerDataObject.GlobalKeyAdded:Fire(data.key_type, data.sent_data)
					PlayerData.GlobalUpdates:ClearLockedUpdate(id)
				end)
				
				LoadedSignal:Fire()
			else
				PlayerData:Release()
			end
		else
			player:Kick(`Could not load data for user {player.UserId}; retry later.`)
			console.warn(`Could not load data for user {player.UserId}; retry later.`)
		end
	end)
	
	LoadedSignal:Wait()

	return PlayerDataObject
end

--[[

	Unclaims the session lock on the provided
	player. With valuesToSave, you can easily
	save any attributes or values you may have
	added to the player to get data easily.
	
	@param [Player] player - The player to unc-
	laim the session lock for.
	
	@param [?dictionary] valuesToSave - Any
	values that should be saved when the pl-
	ayer is removed from the game.
	
	@returns [void]

--]]

function DataStoreObject:UnclaimSessionLock(player: Player, valuesToSave: dictionary?)
	local PlayerData = LoadedPlayers[self.Name][player]
	
	console.assert(player, "Cannot unclaim session lock; field 'player' is nil.")

	if PlayerData then
		if valuesToSave then
			for key, value in pairs(valuesToSave) do
				if PlayerData.Data[key] and typeof(value) ~= "Instance" then
					PlayerData.Data[key] = value
				else
					console.error(`DataService: Invalid key: {key} is an instance or does not exist.`)
				end
			end
		end

		PlayerData:Release()
		self.SessionLockUnclaimed:Fire(player)
	else
		console.warn(`User {player.UserId}'s data is not currently session-locked.`)
	end
end

--[[

	Sends out a global key to the player with the
	passed user id.
	
	@param [number] userId - The user the key should
	be sent to.
	@param [string] keyType - The type of the key,
	used to check the type if needed.
	@param [any] data - Data to be sent with the key.
	@returns [void]

--]]

function DataStoreObject:SetGlobalKeyAsync(userId: number, key: string, value: any)
	self.DataStore:GlobalUpdateProfileAsync(
		string.format(Settings.KeyStringPattern, userId),
		function(global_updates)
			global_updates:AddActiveUpdate({
				key_type = key;
				sent_data = value;
			})
		end
	)
end

--[[

	Sets a key in the player's data.
	
	@param [string] key - The name of the key to set.
	@param [any] value - The value of the key.
	@returns [void]

--]]

function PlayerDataObject:SetKey(key: string, value: any)
	local PlayerData = LoadedPlayers[self.Name][self.Player]

	if PlayerData then
		if not PlayerData.Data[key] then
			self.KeyAdded:Fire(key, value)
		else
			self.KeyChanged:Fire(key, value)
		end
		
		PlayerData.Data[key] = value
	end
end

--[[

	Gets the value of a key in a player's
	data, nil and an error if it doesn't
	exist.
	
	@param [string] key - The key to fetch.
	@returns [any?] The value of the key passed.

--]]

function PlayerDataObject:GetKey(key: string): any?
	local PlayerData = LoadedPlayers[self.Name][self.Player]

	if PlayerData and PlayerData.Data[key] then
		return PlayerData.Data[key]
	else
		console.error(`Key '{key}' does not exist.`)
		return nil
	end
end

--[[

	Gets all global keys sent to a player. They are
	removed after this process.
	
	@returns [dictionary]

--]]

function PlayerDataObject:GetGlobalKeys(): {[string]: any}
	local PlayerData = LoadedPlayers[self.Name][self.Player]
	local keys = { } :: {[string]: any}
	
	for _, globalKey in ipairs(PlayerData.GlobalUpdates:GetLockedUpdates()) do
		keys[globalKey[2].key_type] = globalKey[2].sent_data
		PlayerData.GlobalUpdates:ClearLockedUpdate(globalKey[1])
	end
	
	return keys
end

--[[

	Removes a key from the player's data, errors if nil.
	
	@param [string] key - The key to be removed.
	@returns [void]

--]]

function PlayerDataObject:RemoveKey(key: string)
	local PlayerData = LoadedPlayers[self.Name][self.Player]

	if PlayerData and PlayerData.Data[key] then
		PlayerData.Data[key] = nil
		self.KeyRemoved:Fire(key)
	else
		console.error(`Key '{key}' does not exist.`)
	end
end

--[[

	Returns a ScriptSignal that fires whenever `key` is changed.
	
	@param [string] key - The key to be monitored.
	@returns [ScriptSignal] The signal that is fired when the
	specified key is changed.

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
		console.silentError(`Key '{key}' does not exist.`)
	end
end

--[[

	Returns metadata about a player. Data types include
	the os.time() when the data for the player was cre-
	ated, and the amount of times it was loaded ever.
	
	@returns [PlayerMetaData]

--]]

function PlayerDataObject:GetMetaData(): PlayerMetaData
	local PlayerData = LoadedPlayers[self.Name][self.Player]
	
	return {DataCreated = PlayerData.MetaData.ProfileCreateTime; DataLoadCount = PlayerData.MetaData.SessionLoadCount}
end

--[[

	Gets info about a player's local session. Inform-
	ation like Datastore name, the time the data was
	loaded at, and the data key are returned.
	
	@returns [DataIdentity]

--]]

function PlayerDataObject:GetSessionMetaData(): SessionMetaData
	return {Name = self.Name :: string; LoadedAt = self.LoadedAt :: number; Key = string.format(Settings.KeyStringPattern, self.Player.UserId) :: string}
end

return Package
