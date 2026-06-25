-- LibDataBroker-1.1
-- Public domain. Originally by Tekkub.

local MAJOR, MINOR = "LibDataBroker-1.1", 4
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.attributestorage = lib.attributestorage or {}
lib.namestorage = lib.namestorage or {}
lib.proxystorage = lib.proxystorage or {}

local attributestorage = lib.attributestorage
local namestorage = lib.namestorage
local proxystorage = lib.proxystorage
local callbacks = lib.callbacks

function lib:DataObjectIterator()
    return pairs(proxystorage)
end

function lib:GetDataObjectByName(dataobjectname)
    return proxystorage[dataobjectname]
end

function lib:GetNameByDataObject(dataobject)
    return namestorage[dataobject]
end

local domt = {}
function domt:__index(key)
    local storage = rawget(self, "storage")
    if not storage then return nil end
    return storage[key]
end
function domt:__newindex(key, value)
    local storage = rawget(self, "storage")
    if not storage then
        rawset(self, "storage", {})
        storage = rawget(self, "storage")
    end
    local old = storage[key]
    storage[key] = value
    if old ~= value then
        local name = namestorage[self]
        if name then
            callbacks:Fire("LibDataBroker_AttributeChanged", name, key, value, self)
            callbacks:Fire("LibDataBroker_AttributeChanged_"..name, name, key, value, self)
            callbacks:Fire("LibDataBroker_AttributeChanged_"..name.."_"..key, name, key, value, self)
            callbacks:Fire("LibDataBroker_AttributeChanged__"..key, name, key, value, self)
        end
    end
end

function lib:NewDataObject(name, dataobj)
    if proxystorage[name] then return end
    local proxy = setmetatable({storage = {}}, domt)
    proxystorage[name] = proxy
    namestorage[proxy] = name
    if dataobj then
        for k, v in pairs(dataobj) do
            proxy[k] = v
        end
    end
    callbacks:Fire("LibDataBroker_DataObjectCreated", name, proxy)
    return proxy
end
