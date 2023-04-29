type dictionary = {[string]: any}
type array = {[number]: any}

type PlayerMetaData = {DataCreated: number; DataLoadCount: number; ActiveSession: {placeId: number; jobId: string;}}
export type GlobalKey = {Key: string, Value: any, KeyId: number}

type ScriptConnection = {
	Disconnect: (self: ScriptConnection) -> ();
	Connected: boolean
}

type ScriptSignal<T...> = {
	Connect: (self: ScriptSignal<T...>?, func: (T...) -> ()) -> (ScriptConnection);
	Wait: (self: ScriptSignal<T...>?) -> (T...);
	Once: (self: ScriptSignal<T...>?, func: (T...) -> ()) -> (ScriptConnection);
	ConnectParallel: (self: ScriptSignal<T...>?, func: (T...) -> ()) -> (ScriptConnection);
}

-- // Variables

local Package = { }

local Assets = script.Assets
local Plugins = script.Plugins
local Settings = require(script.Settings)

---

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ProfileService = require(Plugins.ProfileService)

local LoadedPlayers = { }

local DataStoreObject = { }
local PlayerDataObject = { }

local Signal = require(Plugins.Signal)
local OptionalParam = require(Plugins.OptionalParam)

-- // Functions

local function assert<a, b>(assertion: a, msg: b): a?
	if not assertion then
		error(msg)
		return nil
	end
	return assertion
end

local function silentError<a>(msg: a)
	local thread = task.spawn(error, msg, 0)
	task.cancel(thread)
	thread = nil
end

assert(
	RunService:IsServer(),
	"DataService: Cannot run on any environments except the server."
)

ProfileService.CriticalStateSignal:Connect(function()
	warn("DataService: There is an issue with data storing right now.")
end)

Package.DataStoreCreated = Signal.new() :: ScriptSignal<string, dictionary>

function Package.CreateDataStore(name: string, defaultData: dictionary)
	local DataStoreObject = setmetatable({ }, {__index = DataStoreObject})
	local ProfileStore = ProfileService.GetProfileStore(name, defaultData)
	
	assert(name, "DataService: A datastore name must be defined.")
	assert(defaultData, "DataService: Default user data must be defined.")

	if LoadedPlayers[name] then
		error(`DataService: A DataStore named '{name}' already exists.`)
	end

	LoadedPlayers[name] = { }
	Package.DataStoreCreated:Fire(name, defaultData)

	DataStoreObject.SessionLockClaimed = Signal.new() :: ScriptSignal<Player>
	DataStoreObject.SessionLockUnclaimed = Signal.new() :: ScriptSignal<Player>
	
	DataStoreObject.Name = name :: string
	DataStoreObject.ClassName = "DataStoreObject" :: string
	DataStoreObject._datastore = ProfileStore :: any

	return table.freeze(DataStoreObject)
end

function DataStoreObject:GetLoadedPlayers(): {Player}
	local PlayersTable = { }

	for player, data in LoadedPlayers[self.Name] do
		table.insert(PlayersTable, player)
	end

	return table.freeze(PlayersTable)
end

function DataStoreObject:RemoveDataAsync(userId: number)
	self._datastore:WipeProfileAsync(string.format(Settings.KeyStringPattern, userId))
end

function DataStoreObject:GetDataAsync(userId: number): dictionary?
	local RequestedData = self._datastore:ViewProfileAsync(string.format(Settings.KeyStringPattern, userId)).Data
	
	if not RequestedData then
		silentError(`DataService: Requested data for user {userId} does not exist.`)
		return nil
	end
	
	return RequestedData
end

function DataStoreObject:LoadDataAsync(player: Player, reconcileData: boolean?, claimedHandler: ((placeId: number, gameJobId: string) -> ("ForceLoad" | "Cancel"))?)
	local PlayerDataObject = setmetatable({ }, {__index = PlayerDataObject})
	
	assert(player, "DataService: Cannot unclaim session lock for a nil player.")
	
	reconcileData = OptionalParam(reconcileData, true)
	claimedHandler = OptionalParam(claimedHandler, function()
		return "ForceLoad"
	end)
	
	local PlayerData = self._datastore:LoadProfileAsync(string.format(Settings.KeyStringPattern, player.UserId), claimedHandler)
	local LoadedSignal = Signal.new()

	self.SessionLockClaimed:Fire(player)
	
	PlayerDataObject.ClassName = "PlayerDataObject"

	PlayerDataObject.KeyChanged = Signal.new() :: ScriptSignal<string, any>
	PlayerDataObject.KeyAdded = Signal.new() :: ScriptSignal<string, any>
	PlayerDataObject.KeyRemoved = Signal.new() :: ScriptSignal<string>
	PlayerDataObject.KeyUpdated = Signal.new() :: ScriptSignal<string, any, any>
	
	PlayerDataObject.GlobalKeyAdded = Signal.new() :: ScriptSignal<GlobalKey>
	
	PlayerDataObject.MetaTagAdded = Signal.new() :: ScriptSignal<string, any>
	PlayerDataObject.MetaTagChanged = Signal.new() :: ScriptSignal<string, any>
	PlayerDataObject.MetaTagRemoved = Signal.new() :: ScriptSignal<string>

	task.defer(function()
		if not PlayerData then
			player:Kick(`Could not load data for user {player.UserId}; retry later.`)
			warn(`DataService: Could not load data for user {player.UserId}; retry later.`)
			return
		end

		if not player:IsDescendantOf(Players) then
			PlayerData:Release()
			return
		end
		
		if reconcileData then
			PlayerData:Reconcile()
		end
		
		PlayerData:AddUserId(player.UserId)
		PlayerData:ListenToRelease(function()
			LoadedPlayers[self.Name][player] = nil
			self.SessionLockUnclaimed:Fire(player)
		
			setmetatable(PlayerDataObject, nil)
			table.clear(PlayerDataObject)

			player:Kick(`Could not save data for user {player.UserId}; possible data corruption. Retry later.`)
		end)
		
		LoadedPlayers[self.Name][player] = PlayerData
		PlayerDataObject._data = LoadedPlayers[self.Name][player]
				
		for _, globalKey in PlayerData.GlobalUpdates:GetActiveUpdates() do
			PlayerData.GlobalUpdates:LockActiveUpdate(globalKey[1])
		end
				
		PlayerData.GlobalUpdates:ListenToNewActiveUpdate(function(keyId: number, data: any)
			PlayerData.GlobalUpdates:LockActiveUpdate(keyId)
		end)
				
		PlayerData.GlobalUpdates:ListenToNewLockedUpdate(function(keyId: number, data: any)
			PlayerDataObject.GlobalKeyAdded:Fire({Key = data.Key; Value = data.Value; KeyId = keyId;})
			PlayerData.GlobalUpdates:ClearLockedUpdate(keyId)
		end)
				
		LoadedSignal:Fire()
	end)
	
	LoadedSignal:Wait()
	
	return PlayerDataObject
end

function DataStoreObject:UnclaimSessionLock(player: Player, valuesToSave: dictionary?)
	local PlayerData = LoadedPlayers[self.Name][player]
	
	assert(player, "DataService: Cannot unclaim session lock for a nil player.")
	
	if not PlayerData then
		silentError(`DataService: User {player.UserId}'s data is not currently session-locked.`)
		return
	end
	
	if valuesToSave then
		for key, value in valuesToSave do
			if not PlayerData.Data[key] then
				error(`DataService: Invalid key: {key} is an instance or does not exist.`)
				return
			end
			
			PlayerData.Data[key] = value
		end
	end

	PlayerData:Release()
end

function DataStoreObject:SetGlobalKeyAsync<a>(userId: number, key: string, value: a)
	self._datastore:GlobalUpdateProfileAsync(string.format(Settings.KeyStringPattern, userId), function(globalUpdates)
		globalUpdates:AddActiveUpdate({
			Key = key;
			Value = value;
		})
	end)
end

function DataStoreObject:RemoveGlobalKeyAsync(userId: number, keyId: number)
	self._datastore:GlobalUpdateProfileAsync(string.format(Settings.KeyStringPattern, userId), function(globalUpdates)
		globalUpdates:ClearActiveUpdate(keyId)
	end)
end

function PlayerDataObject:SetKey<a>(key: string, value: a)
	local PlayerData = self._data
	
	if not PlayerData then
		return
	end

	if not PlayerData.Data[key] then
		self.KeyAdded:Fire(key, value)
	else
		self.KeyChanged:Fire(key, value)
	end
	
	PlayerData.Data[key] = value
end

function PlayerDataObject:GetKey<a>(key: string): a?
	local PlayerData = self._data
	
	if not PlayerData or not PlayerData.Data[key] then
		error(`DataService: Key '{key}' does not exist.`)
		return nil
	end
	
	return PlayerData.Data[key]
end

function PlayerDataObject:GetGlobalKeys(): {GlobalKey}?
	local PlayerData = self._data
	local Keys = { }
	
	if not PlayerData then
		return nil
	end
	
	for _, globalKey in PlayerData.GlobalUpdates:GetLockedUpdates() do
		table.insert(Keys, {Key = globalKey[2].Key; Value = globalKey[2].Value; KeyId = globalKey[1]})
		PlayerData.GlobalUpdates:ClearLockedUpdate(globalKey[1])
	end
	
	return table.freeze(Keys)
end

function PlayerDataObject:GetKeys(): {[string]: any}?
	local PlayerData = self._data
	local Keys = { }
	
	if not PlayerData then
		return nil
	end
	
	for keyName, key in PlayerData.Data do
		Keys[keyName] = key
	end
	
	return table.freeze(Keys)
end

function PlayerDataObject:GetUserIds(): {number}?
	local PlayerData = self._data
	
	if not PlayerData then
		return nil
	end
	
	return PlayerData.UserIds
end

function PlayerDataObject:RemoveUserIds(userIds: {number})
	local PlayerData = self._data
	
	if not PlayerData then
		return
	end
	
	for _, userId in userIds do
		PlayerData:RemoveUserId(userId)
	end
end

function PlayerDataObject:RemoveKey(key: string)
	local PlayerData = self._data
	
	if not PlayerData or not PlayerData.Data[key] then
		error(`DataService: Key '{key}' does not exist.`)
		return
	end

	PlayerData.Data[key] = nil
	self.KeyRemoved:Fire(key)
end

function PlayerDataObject:UpdateKey<a>(key: string, callback: (oldValue: a) -> (any))
	local PlayerData = self._data

	if not PlayerData then
		return
	end
	
	local oldValue = self:GetKey(key)
	local newValue = callback(oldValue)
	
	self:SetKey(key, newValue)
	self.KeyUpdated:Fire(key, newValue, oldValue)
end

function PlayerDataObject:GetKeyChangedSignal(key: string): ScriptSignal<any>?
	local PlayerData = self._data
	local Event = Signal.new()
	
	if not PlayerData or not PlayerData.Data[key] then
		silentError(`DataService: Key '{key}' does not exist.`)
		return nil
	end
	
	self.KeyChanged:Connect(function(changedKey, changedValue)
		if key == changedKey then
			Event:Fire(changedValue)
		end
	end)

	return Event
end

function PlayerDataObject:GetMetaData(): PlayerMetaData?
	local PlayerData = self._data  
	
	if not PlayerData then
		return nil
	end
	
	return table.freeze({
		DataCreated = PlayerData.MetaData.ProfileCreateTime;
		DataLoadCount = PlayerData.MetaData.SessionLoadCount;
		ActiveSession = {placeId = PlayerData.MetaData.ActiveSession[1], jobId = PlayerData.MetaData.ActiveSession[2]}
	})
end

function PlayerDataObject:GetMetaTag<a>(tag: string): a?
	local PlayerData = self._data
	
	if not PlayerData or not PlayerData.MetaData.MetaTags then
		silentError(`DataService: Tag '{tag}' does not exist.`)
		return nil
	end
	
	return PlayerData.MetaData.MetaTags[tag]
end

function PlayerDataObject:SetMetaTag<a>(tag: string, value: a)
	local PlayerData = self._data
	
	if not PlayerData then
		return
	end
	
	if not PlayerData.MetaData.MetaTags[tag] then
		self.MetaTagAdded:Fire(tag, value)
	else
		self.MetaTagChanged:Fire(tag, value)
	end
	
	PlayerData.MetaData.MetaTags[tag] = value
end

function PlayerDataObject:RemoveMetaTag(tag: string)
	local PlayerData = self._data
	
	if not PlayerData or not PlayerData.MetaData.MetaTags[tag] then
		silentError(`DataService: Tag '{tag}' does not exist.`)
		return
	end
	
	PlayerData.MetaData.MetaTags[tag] = nil
	self.MetaTagRemoved:Fire(tag)
end

function PlayerDataObject:GetDataUsage(): number
	local EncodedUsage = HttpService:JSONEncode(self._data.Data)
	local UsageLength = string.len(EncodedUsage)
	
	return (UsageLength / 4194304) * 100
end

return table.freeze(Package)
