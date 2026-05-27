if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

function RegisterUsableItem(name, cb)
    QBCore.Functions.CreateUseableItem(name, function(source, data)
        local item = data
        if item.info then
            item.metadata = data.info
            item.info = nil
        end
        cb(source, nil, item)
    end)
end

function ShowNotification(target, text)
	TriggerClientEvent(GetCurrentResourceName()..":showNotification", target, text)
end

function GetIdentifier(source)
    local xPlayer = QBCore.Functions.GetPlayer(source).PlayerData
    return xPlayer.citizenid 
end

function SetPlayerMetadata(source, key, data)
    QBCore.Functions.GetPlayer(source).Functions.SetMetaData(key, data)
end

function AddMoney(source, count)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    xPlayer.Functions.AddMoney('cash',count)
end

function RemoveMoney(source, count)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    xPlayer.Functions.RemoveMoney('cash',count)
end

function GetMoney(source)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    return xPlayer.PlayerData.money.cash
end

function CheckPermission(source, permission)
    local xPlayer = QBCore.Functions.GetPlayer(source).PlayerData
    local name = xPlayer.job.name
    local rank = xPlayer.job.grade.level
    if permission.jobs[name] and permission.jobs[name] <= rank then 
        return true
    end
    for i=1, #permission.groups do 
        if QBCore.Functions.HasPermission(source, permission.groups[i]) then 
            return true 
        end
    end
end

-- Society Funds
--
-- QBCore moved society money out of qb-management into qb-banking, while
-- QBox-family servers most commonly use Renewed-Banking. To stay compatible
-- across all three (and avoid a script error when the configured/legacy
-- resource is missing), we lazy-resolve which one to talk to on first call
-- and cache the resulting add/remove closures. Server owners can also pin a
-- specific resource via Config.Lottery.societyResource.

local SocietyAdd, SocietyRemove
local societyResolved = false
local societyWarned = false

local function isStarted(name)
    return GetResourceState(name) == 'started'
end

local function resolveSocietyHandlers()
    local pinned = Config and Config.Lottery and Config.Lottery.societyResource
    pinned = (type(pinned) == 'string') and pinned or 'auto'

    if pinned == 'none' then
        return nil, nil, 'disabled by config'
    end

    -- Ordered candidates. Renewed-Banking is checked first because it's the
    -- typical QBox setup and most QB servers that have it intentionally use
    -- it instead of qb-banking. qb-management is the legacy fallback.
    local candidates
    if pinned == 'auto' then
        candidates = { 'Renewed-Banking', 'qb-banking', 'qb-management' }
    else
        candidates = { pinned }
    end

    for _, res in ipairs(candidates) do
        if isStarted(res) then
            if res == 'Renewed-Banking' then
                return
                    function(name, amount) exports['Renewed-Banking']:addAccountMoney(name, amount) end,
                    function(name, amount) exports['Renewed-Banking']:removeAccountMoney(name, amount) end,
                    res
            elseif res == 'qb-banking' then
                return
                    function(name, amount) exports['qb-banking']:AddMoney(name, amount, 'pickle_lottery') end,
                    function(name, amount) exports['qb-banking']:RemoveMoney(name, amount, 'pickle_lottery') end,
                    res
            elseif res == 'qb-management' then
                return
                    function(name, amount) exports['qb-management']:AddMoney(name, amount) end,
                    function(name, amount) exports['qb-management']:RemoveMoney(name, amount) end,
                    res
            end
        end
    end

    return nil, nil, 'no compatible banking resource started'
end

local function ensureSocietyHandlers()
    if societyResolved then return end
    societyResolved = true
    local add, remove, source = resolveSocietyHandlers()
    SocietyAdd, SocietyRemove = add, remove
    if add then
        print(('[pickle_lottery] Society money routed through %s.'):format(source))
    elseif not societyWarned then
        societyWarned = true
        print(('[pickle_lottery] Society payouts disabled: %s. Set Config.Lottery.societyResource if your banking resource has a non-standard name.'):format(source or 'unknown'))
    end
end

-- Resolve at startup so the routing print shows up immediately in the
-- server console, instead of only on the first lottery purchase. Brief
-- wait gives the banking resource a chance to start if it loads after
-- pickle_lottery in the manifest order.
CreateThread(function()
    Wait(2000)
    ensureSocietyHandlers()
end)

function AddSocietyMoney(name, amount)
    ensureSocietyHandlers()
    if not SocietyAdd then return end
    local ok, err = pcall(SocietyAdd, name, amount)
    if not ok then
        print(('[pickle_lottery] AddSocietyMoney(%s, %s) failed: %s'):format(tostring(name), tostring(amount), tostring(err)))
    end
end

function RemoveSocietyMoney(name, amount)
    ensureSocietyHandlers()
    if not SocietyRemove then return end
    local ok, err = pcall(SocietyRemove, name, amount)
    if not ok then
        print(('[pickle_lottery] RemoveSocietyMoney(%s, %s) failed: %s'):format(tostring(name), tostring(amount), tostring(err)))
    end
end

-- Inventory Fallback

CreateThread(function()
    Wait(100)
    
    if InitializeInventory then return InitializeInventory() end -- Already loaded through inventory folder.
    
    Inventory = {}

    Inventory.Items = {}
    
    Inventory.Ready = false

    Inventory.CanCarryItem = function(source, name, count)
        local slots = 40 -- Change this if higher / lower.
        local items = Inventory.GetInventory(source)
        return (#items + count < slots)
    end

    Inventory.GetInventory = function(source)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local items = {}
        local data = xPlayer.PlayerData.items
        for slot, item in pairs(data) do 
            items[#items + 1] = {
                name = item.name,
                label = item.label,
                count = item.amount,
                weight = item.weight,
                slot = item.slot,
                metadata = item.info
            }
        end
        return items
    end

    Inventory.AddItem = function(source, name, count, metadata) -- Metadata is not required.
        local xPlayer = QBCore.Functions.GetPlayer(source)
        xPlayer.Functions.AddItem(name, count, nil, metadata)
    end

    Inventory.RemoveItem = function(source, name, count, slot)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        xPlayer.Functions.RemoveItem(name, count, slot)
    end
    
    Inventory.SetMetadata = function(source, slot, metadata)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local Inventory = xPlayer.PlayerData.items
        Inventory[slot].info = metadata
        xPlayer.Functions.SetInventory(Inventory, true)
    end
    
    Inventory.GetItemCount = function(source, name)
        local xPlayer = QBCore.Functions.GetPlayer(source)
        local item = xPlayer.Functions.GetItemByName(name)
        return item and item.amount or 0
    end

    lib.callback.register("pickle_lottery:getInventory", function(source)
        return Inventory.GetInventory(source)
    end)

    for item, data in pairs(QBCore.Shared.Items) do
        Inventory.Items[item] = {label = data.label}
    end

    Inventory.Ready = true
end)