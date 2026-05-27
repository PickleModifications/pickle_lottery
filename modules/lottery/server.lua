local Games = {
    keno = {
        game_id = 0,
        games = {},
    },
    moneyball = {
        game_id = 0,
        games = {},
    }
}

function GiveReceipt(source, ticket)
    local data = ticket
    if data.game == "keno" then 
        local game = Config.Games[data.game]
        data.wager = game.wagers[data.wager]
        data.games = game.games[data.games]
        data.gameStart = Games.keno.game_id + 1
        data.gameEnd = data.gameStart + (data.games - 1)
    elseif data.game == "moneyball" then
        local game = Config.Games[data.game]
        data.gameStart = Games.moneyball.game_id + 1
    else
        return
    end
    data.date = os.date(Config.Lottery.dateFormat)
    MySQL.Async.insert("INSERT INTO lottery_receipts (type, data) VALUES (@type, @data);", {
        ["@type"] = data.game,
        ["@data"] = json.encode(data)
    }, function(id)
        data.id = id
        Inventory.AddItem(source, "lottery_receipt", 1, data)
    end)
end

function GetUniqueNumber(range, data)
    local number
    repeat
        local found
        local num = math.random(range[1], range[2])
        for j=1, #data do 
            if data[j] == num then 
                found = true
            end
        end
        if not found then
            number = num
        end
    until number    
    return number
end

function GenerateScratchoff(source, item)
    local cfg = Config.Items[item]
    local ticket = {
        game = "scratch",
        winningNumbers = {},
        numbers = {},
        background = cfg.image,
        prizes = cfg.prizes,
        eachRow = cfg.numbers.eachRow
    }
    for i=1, #cfg.prizes do 
        ticket.winningNumbers[i] = GetUniqueNumber(cfg.numbers.range, ticket.winningNumbers)
    end
    table.sort(ticket.winningNumbers, function(num, num2)
        return num < num2
    end)
    for i=1, (cfg.numbers.rows * cfg.numbers.eachRow) do 
        ticket.numbers[i] = GetUniqueNumber(cfg.numbers.range, ticket.numbers)
    end
    MySQL.Async.insert("INSERT INTO lottery_receipts (id, type, data) VALUES (@id, @type, @data);", {
        ["@type"] = "scratch",
        ["@data"] = json.encode(ticket)
    }, function(id)
        ticket.id = id
        Inventory.AddItem(source, item, 1, ticket)
    end)
end

function GetLotteryNumbers(game) 
    local cfg = Config.Games[game]
    if not cfg then return end
    local numbers = {}
    local range = {1, cfg.ballCount}
    local amount
    local extraNumber
    if game == "keno" then
        amount = cfg.drawCount
    elseif game == "moneyball" then
        amount = #cfg.prizes - 1
        extraNumber = math.random(1, cfg.moneyballCount)
    end
    for i=1, amount do
        numbers[#numbers + 1] = GetUniqueNumber(range, numbers)
    end
    table.sort(numbers, function(num, num2)
        return num < num2
    end)
    if extraNumber then 
        numbers[#numbers + 1] = extraNumber
    end
    return numbers
end

function GenerateGame(game)
    local data = {
        date = os.date(Config.Lottery.dateFormat),
        numbers = GetLotteryNumbers(game)
    } 
    if game == "keno" then
        MySQL.Async.insert("INSERT INTO lottery_keno (numbers, receipts) VALUES (@numbers, @receipts);", {
            ["@numbers"] = json.encode(data.numbers),
            ["@receipts"] = json.encode({})
        }, function(game_id)
            data.id = game_id
            Games[game].game_id = game_id
            Games[game].games[game_id] = data
            local gameCount = 0
            local lowest
            for k,v in pairs(Games[game].games) do
                if not lowest or k < lowest then
                    lowest = k 
                end 
                gameCount = gameCount + 1
            end
            if lowest and gameCount > 10 then
                Games[game].games[lowest] = nil
            end
            MySQL.Async.fetchAll("SELECT * FROM lottery_receipts WHERE type=@type", {
                ["@type"] = "keno"
            }, function(results)
                local receipts = {}
                for i=1, #results do 
                    local receipt = json.decode(results[i].data)
                    if (receipt.gameStart <= game_id and receipt.gameEnd >= game_id) then
                        receipts[#receipts + 1] = results[i].id
                    end
                end
                MySQL.Async.execute("UPDATE lottery_keno SET receipts=@receipts WHERE id=@id", {
                    ["@id"] = game_id,
                    ["@receipts"] = json.encode(receipts)
                })
            end)
            if Discord.Drawings.enabled then
                local numbers = ""
                for i=1, #data.numbers - 1 do 
                    local num = data.numbers[i]
                    if i ~= #data.numbers - 1 then
                        num = num .. ", "
                    end
                    numbers = numbers .. num
                end
                DiscordNotify("keno_notify", {
                    id = data.id,
                    numbers = numbers
                })
            end
        end)
    elseif game == "moneyball" then 
        MySQL.Async.insert("INSERT INTO lottery_moneyball (numbers, receipts) VALUES (@numbers, @receipts);", {
            ["@numbers"] = json.encode(data.numbers),
            ["@receipts"] = json.encode({})
        }, function(game_id)
            data.id = game_id
            Games[game].game_id = game_id
            Games[game].games[game_id] = data
            local gameCount = 0
            local lowest
            for k,v in pairs(Games[game].games) do
                if not lowest or k < lowest then
                    lowest = k 
                end 
                gameCount = gameCount + 1
            end
            if lowest and gameCount > 10 then
                Games[game].games[lowest] = nil
            end
            MySQL.Async.fetchAll("SELECT * FROM lottery_receipts WHERE type=@type", {
                ["@type"] = "moneyball"
            }, function(results)
                local receipts = {}
                for i=1, #results do 
                    local receipt = json.decode(results[i].data)
                    if (receipt.gameStart == game_id) then
                        receipts[#receipts + 1] = results[i].id
                    end
                end
                MySQL.Async.execute("UPDATE lottery_moneyball SET receipts=@receipts WHERE id=@id", {
                    ["@id"] = game_id,
                    ["@receipts"] = json.encode(receipts)
                })
            end)
            if Discord.Drawings.enabled then
                local moneyball = data.numbers[#data.numbers]
                local numbers = ""
                for i=1, #data.numbers - 1 do 
                    local num = data.numbers[i]
                    if i ~= #data.numbers - 1 then
                        num = num .. ", "
                    end
                    numbers = numbers .. num
                end
                DiscordNotify("moneyball_notify", {
                    id = data.id,
                    numbers = numbers,
                    moneyball = moneyball
                })
            end
        end)
    end
end

function WinnerEvent(source, index, prize)
    local playerName = GetPlayerName(source)  -- Get the player's name
    ShowNotification(source, _L("redeem_won", prize))
    AddMoney(source, prize)
    TriggerClientEvent("pickle_lottery:locationSound", -1, index, "winner")
    if Config.Lottery.canSocietyLose then
        local cfg = Config.Locations[index]
        local store = cfg.store or Config.DefaultStore
        for k,v in pairs(store.accounts) do 
            RemoveSocietyMoney(k, prize * (v * 0.01))
        end
    end

    -- Send a Discord notification about the winner
    if Discord.Drawings.enabled then
        DiscordNotify("winner_notify", {
            playerName = playerName,
            prize = prize
        })
    end
end

function DiscordNotify(notifyType, args)
    local title, description = "", ""
    if notifyType == "keno_notify" then
        title = _L("discord_keno_drawing_title")
        description = _L("discord_keno_drawing_desc", args.id, args.numbers)
    elseif notifyType == "moneyball_notify" then
        title = _L("discord_moneyball_drawing_title")
        description = _L("discord_moneyball_drawing_desc", args.id, args.numbers, args.moneyball)
    end
    PerformHttpRequest(Discord.Drawings.webhook, function(err, text, headers)
    end, 'POST', json.encode({
        username = Discord.Username, 
        avatar_url = Discord.AvatarURL, 
        embeds = {
        {
            ["color"] = 0,
            ["title"] = title, 
            ["description"] = description,
            ["footer"] ={
                ["text"] = os.date("%c"),
            },
        }
    }}), { ['Content-Type']= 'application/json' })
end

RegisterUsableItem("lottery_keno", function(source, item, data) 
    TriggerClientEvent("pickle_lottery:interactItem", source, "lottery_keno", data)
end)

RegisterUsableItem("lottery_moneyball", function(source, item, data) 
    TriggerClientEvent("pickle_lottery:interactItem", source, "lottery_moneyball", data)
end)

for k,v in pairs(Config.Items) do 
    if v.game == "scratch" then 
        RegisterUsableItem(k, function(source, item, data) 
            TriggerClientEvent("pickle_lottery:interactItem", source, k, data)
            data.metadata.scratched = true
            Inventory.SetMetadata(source, data.slot, data.metadata)
        end)    
    end
end 

RegisterUsableItem("lottery_receipt", function(source, item, data) 
    TriggerClientEvent("pickle_lottery:interactItem", source, "lottery_receipt", data)
end)

RegisterNetEvent("pickle_lottery:saveTicket", function(ticket, itemData)
    Inventory.SetMetadata(source, itemData.slot, ticket)
end)

RegisterNetEvent("pickle_lottery:redeemTicket", function(index, itemData)
    local source = source
    local receipt_id = itemData.metadata.id
    if itemData.metadata?.game == "keno" then
        local numbers = itemData.metadata.spots
        MySQL.Async.fetchAll("SELECT * FROM lottery_keno WHERE id >= @gameStart AND id <= @gameEnd;", {
            ["@gameStart"] = itemData.metadata.gameStart,
            ["@gameEnd"] = itemData.metadata.gameEnd,
        }, function(results)
            local redeemGames = {}
            local prize = 0
            local maxResult
            for i=1, #results do 
                local receipts = json.decode(results[i].receipts or "[]")
                for j=1, #receipts do 
                    if receipts[j] == receipt_id then
                        redeemGames[#redeemGames + 1] = results[i] 
                        break
                    end
                end
                if not maxResult or results[i].id > maxResult then
                    maxResult = results[i].id
                end
            end
            for i=1, #redeemGames do 
                local game = redeemGames[i]
                local ticketNumbers = json.decode(game.numbers)
                local spots = 0
                for j=1, #ticketNumbers do 
                    local number = ticketNumbers[j]
                    for k=1, #numbers do 
                        if numbers[k] == number then
                            spots = spots + 1
                            break
                        end
                    end 
                end
                local prizeList = Config.Games.keno.prizes[#numbers]
                if not prizeList then
                    print("[ERROR] You need to set a prize for " .. #numbers .. " slot games.")
                    return
                end
                local cash = prizeList[spots + 1]
                if not cash then
                    print("[ERROR] You need to set a prize for " .. #spots .. " spots in the " .. #numbers .. " slot game.")
                    return
                end
                local receipts = json.decode(game.receipts)
                local newReceipts = {}
                for j=1, #receipts do
                    if receipts[j] ~= receipt_id then
                        newReceipts[#newReceipts + 1] = receipts[j]
                    end                    
                end
                prize = prize + cash
                MySQL.Async.execute("UPDATE lottery_keno SET receipts=@receipts WHERE id=@id;", {
                    ["@id"] = game.id,
                    ["@receipts"] = json.encode(newReceipts)
                })
            end
            if prize > 0 then
                MySQL.Async.fetchAll("SELECT * FROM lottery_receipts WHERE id=@id;", {
                    ["@id"] = receipt_id,
                }, function(results)
                    if #results < 1 then return print("NO RECEIPT", receipt_id) end
                    WinnerEvent(source, index, prize * json.decode(results[i].data).wager)
                end)
            else
                ShowNotification(source, _L("redeem_lost"))
            end
            if maxResult == itemData.metadata.gameEnd then -- Max Games
                Inventory.RemoveItem(source, itemData.name, 1, itemData.slot)
                MySQL.Async.execute("DELETE FROM lottery_receipts WHERE id=@id;", {
                    ["@id"] = receipt_id
                })
                ShowNotification(source, _L("redeem_games_none"))
            else
                ShowNotification(source, _L("redeem_games_more"))
            end
        end)
    elseif itemData.metadata?.game == "moneyball" then
        MySQL.Async.fetchAll("SELECT * FROM lottery_moneyball WHERE id=@gameStart;", {
            ["@gameStart"] = itemData.metadata.gameStart,
        }, function(results)
            local redeemGames = {}
            local prize = 0
            local game = results[1]
            if not game then 
                ShowNotification(source, _L("redeem_games_more"))
                return
            end
            local receipts = json.decode(game.receipts or "[]")
            local receipt
            for j=1, #receipts do 
                if receipts[j] == receipt_id then
                    receipt = receipts[j]
                    break
                end
            end
            if not receipt then return end
            local panels = itemData.metadata.panels
            for i=1, #panels do
                local numbers = panels[i]
                local ticketNumbers = json.decode(game.numbers)
                local spots = 0
                local moneyball = (numbers[#numbers] == ticketNumbers[#ticketNumbers])
                for j=1, #ticketNumbers - 1 do 
                    local number = ticketNumbers[j]
                    for k=1, #numbers do 
                        if numbers[k] == number then
                            spots = spots + 1
                            break
                        end
                    end 
                end
                if spots == (#ticketNumbers - 1) and moneyball then -- If all including moneyball, jackpot.
                    spots = #ticketNumbers
                end
                local cash = (spots > 0 and Config.Games.moneyball.prizes[spots] or 0)
                if not cash then
                    print("[ERROR] You need to set a prize for " .. #spots .. " spots in the moneyball game.")
                    return
                end
                prize = prize + cash
            end
            local newReceipts = {}
            for j=1, #receipts do
                if receipts[j] ~= receipt_id then
                    newReceipts[#newReceipts + 1] = receipts[j]
                end                    
            end
            MySQL.Async.execute("UPDATE lottery_moneyball SET receipts=@receipts WHERE id=@id;", {
                ["@id"] = game.id,
                ["@receipts"] = json.encode(newReceipts)
            })
            MySQL.Async.execute("DELETE FROM lottery_receipts WHERE id=@id;", {
                ["@id"] = receipt_id
            })
            if prize > 0 then
                WinnerEvent(source, index, prize)
            else
                ShowNotification(source, _L("redeem_lost"))
            end
            Inventory.RemoveItem(source, itemData.name, 1, itemData.slot)
        end)
    elseif itemData.metadata?.game == "scratch" then
        MySQL.Async.fetchAll("SELECT * FROM lottery_receipts WHERE id=@id;", {
            ["@id"] = itemData.metadata?.id,
        }, function(results)
            if #results < 1 then return end
            local game = json.decode(results[1].data)
            local numbers = game.numbers
            local ticketNumbers = game.winningNumbers
            local spots = 0
            for j=1, #ticketNumbers do 
                local number = ticketNumbers[j]
                for k=1, #numbers do 
                    if numbers[k] == number then
                        spots = spots + 1
                        break
                    end
                end 
            end
            local prize = (spots > 0 and game.prizes[spots] or 0)
            if not prize then
                print("[ERROR] You need to set a prize for a scratchoff.")
                return
            end
            MySQL.Async.execute("DELETE FROM lottery_receipts WHERE id=@id;", {
                ["@id"] = results[1].id
            })
            if prize > 0 then
                WinnerEvent(source, index, prize)
            else
                ShowNotification(source, _L("redeem_lost"))
            end
            Inventory.RemoveItem(source, itemData.name, 1, itemData.slot)
        end)
    end
end)

lib.callback.register("pickle_lottery:getDrawings", function(source, name)
    if name ~= "keno" and name ~= "moneyball" then return end
    local data = Games[name]
    local games = {}
    for k,v in pairs(data.games) do 
        games[#games + 1] = v
    end
    table.sort(games, function(t1, t2)
        return t1.id > t2.id
    end)
    return data.game_id, games 
end)

lib.cron.new(Config.Games.keno.drawingFrequency, function()
    GenerateGame("keno")
end)

lib.cron.new(Config.Games.moneyball.drawingFrequency, function()
    GenerateGame("moneyball")
end)

MySQL.ready(function()
    MySQL.Async.fetchAll("SELECT * FROM lottery_keno ORDER BY id DESC;", {}, function(results)
        if #results > 0 then
            Games.keno.game_id = results[1].id
        end
        for i=1, #results do 
            local time = math.ceil(results[i].date / 1000)
            if i <= 10 then
                local date = os.date(Config.Lottery.dateFormat, time)
                Games.keno.games[results[i].id] = {
                    id = results[i].id,
                    date = date,
                    numbers = json.decode(results[i].numbers)
                }
            else
                local receipts = json.decode(results[i].receipts)
                if not receipts or #receipts < 1 then
                    MySQL.Async.execute("DELETE FROM lottery_keno WHERE id=@id", {["@id"] = results[i].id})
                elseif receipts then
                    if (time - os.time()) > (Config.Lottery.redeemExpiration * (60 * 60 * 24)) then -- Ticket expired.
                        MySQL.Async.execute("DELETE FROM lottery_keno WHERE id=@id", {["@id"] = results[i].id})
                        for i=1, #receipts do 
                            MySQL.Async.execute("DELETE FROM lottery_receipts WHERE id=@id", {["@id"] = receipts[i]})
                        end
                    end
                end
            end
        end
    end)
    MySQL.Async.fetchAll("SELECT * FROM lottery_moneyball ORDER BY id DESC;", {}, function(results)
        if #results > 0 then
            Games.moneyball.game_id = results[1].id
        end
        for i=1, #results do 
            local time = math.ceil(results[i].date / 1000)
            if i <= 10 then
                local date = os.date(Config.Lottery.dateFormat, time)
                Games.moneyball.games[results[i].id] = {
                    id = results[i].id,
                    date = date,
                    numbers = json.decode(results[i].numbers)
                }
            else
                local receipts = json.decode(results[i].receipts)
                if not receipts or #receipts < 1 then
                    MySQL.Async.execute("DELETE FROM lottery_moneyball WHERE id=@id", {["@id"] = results[i].id})
                elseif receipts then
                    if (time - os.time()) > (Config.Lottery.redeemExpiration * (60 * 60 * 24)) then -- Ticket expired.
                        MySQL.Async.execute("DELETE FROM lottery_moneyball WHERE id=@id", {["@id"] = results[i].id})
                        for i=1, #receipts do 
                            MySQL.Async.execute("DELETE FROM lottery_receipts WHERE id=@id", {["@id"] = receipts[i]})
                        end
                    end
                end
            end
        end
    end)
end)

RegisterCommand("keno", function()
    GenerateGame("keno")
end)