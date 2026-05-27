if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

function RegisterUsableItem(name, cb)
    ESX.RegisterUsableItem(name, function(source, item, data) 
        print("VARS: ", source, item, data)
        local data = data
        if type(item) == "table" then
            data = item
        else 
            
        end
        if data.info then
            data.metadata = data.info
            data.info = nil
        end
        TriggerClientEvent("pickle_lottery:interactItem", source, name, data)
    end)
end

function ShowNotification(target, text)
	TriggerClientEvent(GetCurrentResourceName()..":showNotification", target, text)
end

function GetIdentifier(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer.identifier
end

function SetPlayerMetadata(source, key, data)
    -- No player metadata in ESX.
end

function AddMoney(source, count)
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.addMoney(count)
end

function RemoveMoney(source, count)
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.removeMoney(count)
end

function GetMoney(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return xPlayer.getMoney()
end

function CheckPermission(source, permission)
    local xPlayer = ESX.GetPlayerFromId(source)
    local name = xPlayer.job.name
    local rank = xPlayer.job.grade
    local group = xPlayer.getGroup()
    if permission.jobs[name] and permission.jobs[name] <= rank then 
        return true
    end
    for i=1, #permission.groups do 
        if group == permission.groups[i] then 
            return true 
        end
    end
end

-- Society Funds

function AddSocietyMoney(name, amount)
    TriggerEvent('esx_addonaccount:getSharedAccount', "society_" .. name, function(account)
        if account then
            account.addMoney(amount)
        end
    end)
end

function RemoveSocietyMoney(name, amount)
    TriggerEvent('esx_addonaccount:getSharedAccount', "society_" .. name, function(account)
        if account then
            account.removeMoney(amount)
        end
    end)
end

-- Inventory Fallback

CreateThread(function()
    Wait(100)

    if InitializeInventory then return InitializeInventory() end -- Already loaded through inventory folder.

    print("The only supported inventory for ESX is ox_inventory and qs-inventory, if you would like to port to a different inventory, please use the example shown in the inventory folder.")
end)