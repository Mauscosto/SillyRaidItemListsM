-- CallbackHandler-1.0
-- Public domain. Originally by Ace3 team.

local MAJOR, MINOR = "CallbackHandler-1.0", 7
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)
if not CallbackHandler then return end

local meta = {__index = function(tbl, key) tbl[key] = {} return tbl[key] end}

function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)
    RegisterName = RegisterName or "RegisterCallback"
    UnregisterName = UnregisterName or "UnregisterCallback"
    UnregisterAllName = UnregisterAllName or "UnregisterAllCallbacks"

    local events = setmetatable({}, meta)
    local registry = {recurse = 0, events = events}

    function registry:Fire(eventname, ...)
        if not rawget(events, eventname) or not next(events[eventname]) then return end
        local oldrecurse = registry.recurse
        registry.recurse = oldrecurse + 1
        for obj, func in pairs(events[eventname]) do
            if type(func) == "string" then
                if type(obj[func]) == "function" then obj[func](obj, eventname, ...) end
            elseif func then
                func(eventname, ...)
            end
        end
        registry.recurse = oldrecurse
        if registry.insertQueue and oldrecurse == 0 then
            for eventname2, tbl in pairs(registry.insertQueue) do
                for obj, func in pairs(tbl) do
                    events[eventname2][obj] = func
                end
            end
            registry.insertQueue = nil
        end
    end

    target[RegisterName] = function(self2, eventname, method, ...)
        if type(eventname) ~= "string" then error("Usage: " .. RegisterName .. "(eventname, method): 'eventname' - string expected.", 2) end
        method = method or eventname
        if registry.recurse > 0 then
            registry.insertQueue = registry.insertQueue or setmetatable({}, meta)
            registry.insertQueue[eventname][self2] = method
        else
            events[eventname][self2] = method
        end
    end

    target[UnregisterName] = function(self2, eventname)
        if not self2 or not eventname then return end
        if rawget(events, eventname) then
            events[eventname][self2] = nil
        end
    end

    target[UnregisterAllName] = function(self2)
        if self2 then
            for eventname, callbacks in pairs(events) do
                callbacks[self2] = nil
            end
        end
    end

    return registry
end
