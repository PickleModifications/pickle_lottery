local CurrentApp
local InteractCB

function TicketValues(name, data)
    local cfg = Config.Games[name]
    if name == "keno" then 
        local spots = data.spots
        local wager = cfg.wagers[data.wager]
        local games = cfg.games[data.games]
        if not wager or not games then return end
        return {
            spots = spots,
            wager = wager,
            games = games
        }
    elseif name == "moneyball" then
        local panels = data.panels
        local price = cfg.price * #panels
        if not panels or not price then return end
        return {
            panels = panels,
            price = price
        }
    end
end

function DisplayApp(app, data, itemData)
    CurrentApp = {app = app, data = data, itemData = itemData}
    SendNUIMessage({
        type = "displayApp",
        app = app,
        data = data
    })
    SetNuiFocus(true, true)
    DisableCamera(true)
end

function HideApp(nuiClose)
    if nuiClose then
        SendNUIMessage({
            type = "hideApp",
        })
    else
        CurrentApp = nil
        SetNuiFocus(false, false)
        DisableCamera(false)
    end
end

RegisterNetEvent("pickle_lottery:interactItem", function(item, itemData)
    local cfg = Config.Items[item]
    if not cfg then return end
    local game = Config.Games[cfg.game]
    if not game then
        game = cfg
    end
    DisplayApp(cfg.game, {
        game = game,
        data = itemData.metadata
    }, itemData)
end)

RegisterNUICallback("saveTicket", function(data)
    SetNuiFocus(false, false)
    local game = Config.Games[data.app]
    local ticket
    if data.app == "keno" then
        local spots = {}
        for i=1, #data.selections[4] do 
            spots[i] = data.selections[4][i] + 1
        end
        ticket = {
            game = data.app,
            spots = spots,
            wager = data.selections[2][1] + 1, -- Wager selection for each game.
            games = data.selections[1][1] + 1 -- Game selection for how many games to play.
        }
    elseif data.app == "moneyball" then
        local panels = {}
        for i=1, #data.panels do 
            local panelData = data.panels[i][1]
            panelData[#panelData + 1] = data.panels[i][2]
            panels[#panels + 1] = panelData
        end

        ticket = {
            game = data.app,
            panels = panels,
            price = game.price
        }
    end
    local appData = CurrentApp
    HideApp()
    TriggerServerEvent("pickle_lottery:saveTicket", ticket, appData.itemData)
end)

RegisterNUICallback("closeApp", function(data)
    HideApp()
end)