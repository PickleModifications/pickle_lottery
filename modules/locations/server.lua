function SocietyProfit(accounts, amount)
    for k,v in pairs(accounts) do 
        AddSocietyMoney(k, amount * (v * 0.01))
    end
end

RegisterNetEvent("pickle_lottery:shopPurchase", function(index, itemIndex, amount)
    local source = source
    if amount < 1 then return end
    local cfg = Config.Locations[index]
    if not cfg then return end
    local store = cfg.store or Config.DefaultStore
    local item = store.items[itemIndex]
    if not item then return end
    local itemCFG = Config.Items[item.item] or {}
    if not Inventory.CanCarryItem(source, item.item, amount) then
        ShowNotification(source, _L("no_room"))
        return
    end
    local remaining = GetMoney(source) - (amount * item.price)
    if remaining < 0 then 
        ShowNotification(source, _L("no_afford", math.ceil(remaining * -1)))
        return
    end
    RemoveMoney(source, amount * item.price)
    if store.accounts then
        SocietyProfit(store.accounts, amount * item.price)
    end
    if itemCFG?.game == "scratch" then
        for i=1, amount do
            GenerateScratchoff(source, item.item)
        end
    else
        Inventory.AddItem(source, item.item, amount)
    end
end)

RegisterNetEvent("pickle_lottery:purchaseTicket", function(index, itemData)
    local source = source
    local ticket = itemData.metadata
    local store = Config.Locations[index].store or Config.DefaultStore
    local game = ticket?.game
    if not game then return end
    local cfg = Config.Games[game]
    local price
    if game == "keno" then
        price = cfg.games[ticket.games] * cfg.wagers[ticket.wager]
    elseif game == "moneyball" then
        price = cfg.price * #ticket.panels
    end
    if not price then return end
    local remaining = GetMoney(source) - price
    if remaining < 0 then 
        ShowNotification(source, _L("no_afford", math.ceil(remaining * -1)))
        return
    end
    RemoveMoney(source, price)
    if store.accounts then
        SocietyProfit(store.accounts, price)
    end
    GiveReceipt(source, itemData.metadata)
end)