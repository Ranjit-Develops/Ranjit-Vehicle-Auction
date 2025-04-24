local QBCore = exports['qb-core']:GetCoreObject()
local activeAuctions = {}
print("^2Ranjit - Car Auction Script By ranjit_07^7")

function InitializeDatabase()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS vehicle_auctions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            vehicle VARCHAR(50) NOT NULL,
            startingBid INT NOT NULL,
            currentBid INT NOT NULL,
            endTime INT NOT NULL,
            createdBy VARCHAR(50) NOT NULL,
            highestBidder VARCHAR(50) NULL
        );
    ]], {})

    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS auction_bids (
            id INT AUTO_INCREMENT PRIMARY KEY,
            auctionId INT NOT NULL,
            bidder VARCHAR(50) NOT NULL,
            amount INT NOT NULL,
            timestamp INT NOT NULL,
            FOREIGN KEY (auctionId) REFERENCES vehicle_auctions(id)
        );
    ]], {})

    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS auction_claims (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            vehicle VARCHAR(50) NOT NULL,
            claim_expires INT NOT NULL,
            claimed BOOLEAN NOT NULL DEFAULT 0
        );
    ]], {})

end

function LoadAuctions()
    local currentTime = os.time()
    
    activeAuctions = {}
    
    local results = exports.oxmysql:executeSync('SELECT * FROM vehicle_auctions WHERE endTime > ?', {currentTime})
    
    if results then
        for _, auction in ipairs(results) do
            activeAuctions[auction.id] = auction
            
            local timeRemaining = auction.endTime - currentTime
            if timeRemaining > 0 then
                SetTimeout(timeRemaining * 1000, function()
                    CompleteAuction(auction.id, activeAuctions[auction.id])
                end)
            end
        end
    end
end

function PrepareAuctionsForClient()
    local clientAuctions = {}
    local currentTime = os.time()
    
    
    local results = exports.oxmysql:executeSync('SELECT * FROM vehicle_auctions WHERE endTime > ?', {currentTime})
    
    if results then
        for _, auction in pairs(results) do
            local bidderName = "None"
            if auction.highestBidder then
                local result = exports.oxmysql:executeSync('SELECT charinfo FROM players WHERE citizenid = ?', {auction.highestBidder})
                if result and result[1] then
                    local charinfo = json.decode(result[1].charinfo)
                    bidderName = charinfo.firstname .. " " .. charinfo.lastname
                end
            end
            
            table.insert(clientAuctions, {
                id = auction.id,
                vehicle = auction.vehicle,
                currentBid = auction.currentBid,
                startingBid = auction.startingBid,
                timeRemaining = auction.endTime - currentTime,
                highestBidderName = bidderName,
                endTime = auction.endTime
            })
        end
    end
    
    return clientAuctions
end

function BroadcastAuctionUpdate(auctionId, updateType, data)
    TriggerClientEvent('vehicle-auction:update', -1, auctionId, updateType, data)
end

function ValidateBidIncrement(currentBid, newBid, previousBidTime)
    local currentTime = os.time()
    
    if newBid < currentBid + Config.MinimumBidIncrement then
        return false, "Bid must be at least $" .. Config.MinimumBidIncrement .. " more than the current bid"
    end
    
    if previousBidTime and (currentTime - previousBidTime) < Config.BidCooldownSeconds then
        return false, "Please wait " .. Config.BidCooldownSeconds .. " seconds between bids"
    end
    
    return true, ""
end

function CanPlayerAffordBid(Player, bidAmount)
    local bankBalance = Player.Functions.GetMoney('bank')
    return bankBalance >= bidAmount, "You need at least $" .. bidAmount .. " in your bank account to place this bid"
end

function UpdateOfflinePlayerMoney(citizenId, amount)
    local result = exports.oxmysql:executeSync('SELECT money FROM players WHERE citizenid = ?', {citizenId})
    if result and result[1] then
        local money = json.decode(result[1].money)
        money.bank = money.bank + amount
        
        exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?', {
            json.encode(money),
            citizenId
        })
        return true
    end
    return false
end

function AddMoneyToOfflinePlayer(citizenid, amount, accountType)
    if not citizenid or not amount then return false end
    accountType = accountType or "bank"
    
    if QBCore.Functions.GetPlayerByCitizenId(citizenid) then
        return false
    end
    
    local result = exports.oxmysql:executeSync('SELECT money FROM players WHERE citizenid = ?', {citizenid})
    if result and result[1] then
        local moneyData = json.decode(result[1].money)
        
        local currentBalance = moneyData[accountType] or 0
        moneyData[accountType] = currentBalance + amount
        
        exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?', {
            json.encode(moneyData),
            citizenid
        })
        
        return true
    else
        return false
    end
end

function RemoveMoneyFromOfflinePlayer(citizenid, amount, accountType)
    if not citizenid or not amount then return false end
    accountType = accountType or "bank"
    
    if QBCore.Functions.GetPlayerByCitizenId(citizenid) then
        return false
    end
    
    local result = exports.oxmysql:executeSync('SELECT money FROM players WHERE citizenid = ?', {citizenid})
    if result and result[1] then
        local moneyData = json.decode(result[1].money)
        
        local currentBalance = moneyData[accountType] or 0
        if currentBalance < amount then
            return false
        end
        
        moneyData[accountType] = currentBalance - amount
        
        exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?', {
            json.encode(moneyData),
            citizenid
        })
        
        return true
    else
        return false
    end
end

function ForceRemoveMoneyFromOfflinePlayer(citizenid, amount, accountType)
    if not citizenid or not amount then return false end
    accountType = accountType or "bank"
    
    if QBCore.Functions.GetPlayerByCitizenId(citizenid) then
        return false
    end
    
    local result = exports.oxmysql:executeSync('SELECT money FROM players WHERE citizenid = ?', {citizenid})
    if result and result[1] then
        local moneyData = json.decode(result[1].money)
        
        local currentBalance = moneyData[accountType] or 0
        moneyData[accountType] = currentBalance - amount
        
        exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?', {
            json.encode(moneyData),
            citizenid
        })
        
        return true
    else
        return false
    end
end

function GetPlayerName(citizenId)
    local result = exports.oxmysql:executeSync('SELECT charinfo FROM players WHERE citizenid = ?', {citizenId})
    if result and result[1] then
        local charinfo = json.decode(result[1].charinfo)
        return charinfo.firstname .. " " .. charinfo.lastname
    end
    return "Unknown"
end

RegisterNetEvent('vehicle-auction:placeBid', function(auctionId, bidAmount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local auction = activeAuctions[auctionId]
    if not auction then
        TriggerClientEvent('QBCore:Notify', src, "This auction no longer exists", "error")
        return
    end
    
    if os.time() >= auction.endTime then
        TriggerClientEvent('QBCore:Notify', src, "This auction has already ended", "error")
        return
    end
    
    local previousBidTime = nil
    local result = exports.oxmysql:executeSync('SELECT timestamp FROM auction_bids WHERE auctionId = ? AND bidder = ? ORDER BY timestamp DESC LIMIT 1', {
        auctionId,
        Player.PlayerData.citizenid
    })
    if result and result[1] then
        previousBidTime = result[1].timestamp
    end
    
    local isValid, validationMessage = ValidateBidIncrement(auction.currentBid, bidAmount, previousBidTime)
    if not isValid then
        TriggerClientEvent('QBCore:Notify', src, validationMessage, "error")
        return
    end
    
    local canAfford, affordMessage = CanPlayerAffordBid(Player, bidAmount)
    if not canAfford then
        TriggerClientEvent('QBCore:Notify', src, affordMessage, "error")
        return
    end
    
    if auction.highestBidder then
        local previousBidder = QBCore.Functions.GetPlayerByCitizenId(auction.highestBidder)
        if previousBidder then
            previousBidder.Functions.AddMoney('bank', auction.currentBid, "auction-bid-refund")
            TriggerClientEvent('QBCore:Notify', previousBidder.PlayerData.source, "You have been outbid! Your $" .. auction.currentBid .. " has been refunded", "info")
        else
            UpdateOfflinePlayerMoney(auction.highestBidder, auction.currentBid)
        end
    end
    
    Player.Functions.RemoveMoney('bank', bidAmount, "auction-bid-placed")
    
    local currentTime = os.time()
    activeAuctions[auctionId].currentBid = bidAmount
    activeAuctions[auctionId].highestBidder = Player.PlayerData.citizenid
    
    exports.oxmysql:insert('INSERT INTO auction_bids (auctionId, bidder, amount, timestamp) VALUES (?, ?, ?, ?)', {
        auctionId,
        Player.PlayerData.citizenid,
        bidAmount,
        currentTime
    })
    
    exports.oxmysql:execute('UPDATE vehicle_auctions SET currentBid = ?, highestBidder = ? WHERE id = ?', {
        bidAmount,
        Player.PlayerData.citizenid,
        auctionId
    })
    
    local bidderName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
    SendDiscordWebhook(
        "BidPlaced",
        "New Bid Placed on Vehicle Auction",
        "**Vehicle:** " .. auction.vehicle .. "\n" ..
        "**Bidder:** " .. bidderName .. "\n" ..
        "**Bid Amount:** $" .. bidAmount .. "\n" ..
        "**Time:** " .. os.date("%Y-%m-%d %H:%M:%S", currentTime),
        Config.Colors.Yellow
    )
    
    BroadcastAuctionUpdate(auctionId, "bid", {
        bidder = bidderName,
        amount = bidAmount
    })
    
    TriggerClientEvent('QBCore:Notify', src, "Your bid of $" .. bidAmount .. " has been placed!", "success")
end)

function CompleteAuction(id, auction)
    if not auction then return end
    
    activeAuctions[id] = nil
    
    if not auction.highestBidder then
        SendDiscordWebhook(
            "AuctionCompleted",
            "Auction Completed With No Bids",
            "**Vehicle:** " .. auction.vehicle .. "\n" ..
            "**Starting Bid:** $" .. auction.startingBid .. "\n" ..
            "**Time:** " .. os.date("%Y-%m-%d %H:%M:%S", os.time()),
            Config.Colors.Red
        )
        
        BroadcastAuctionUpdate(id, "completed", {
            vehicle = auction.vehicle,
            winner = "No Winner",
            finalBid = "No Bids"
        })
        return
    end
    
    local winner = QBCore.Functions.GetPlayerByCitizenId(auction.highestBidder)
    local winnerName = GetPlayerName(auction.highestBidder)
    
    if winner then
        TriggerClientEvent('QBCore:Notify', winner.PlayerData.source, "Congratulations! You won the auction for " .. auction.vehicle .. ". The vehicle will be available in your claims list.", "success")
    end
    
    local claimExpires = os.time() + (Config.ClaimExpirationDays * 24 * 60 * 60)
    exports.oxmysql:insert('INSERT INTO auction_claims (citizenid, vehicle, claim_expires, claimed) VALUES (?, ?, ?, 0)', {
        auction.highestBidder,
        auction.vehicle,
        claimExpires
    })
    
    SendDiscordWebhook(
        "AuctionCompleted",
        "Auction Completed Successfully",
        "**Vehicle:** " .. auction.vehicle .. "\n" ..
        "**Winner:** " .. winnerName .. "\n" ..
        "**Final Price:** $" .. auction.currentBid .. "\n" ..
        "**Time:** " .. os.date("%Y-%m-%d %H:%M:%S", os.time()),
        Config.Colors.Green
    )
    
    BroadcastAuctionUpdate(id, "completed", {
        vehicle = auction.vehicle,
        winner = winnerName,
        finalBid = auction.currentBid
    })
    
    exports.oxmysql:execute('DELETE FROM vehicle_auctions WHERE id = ?', {id})
end

RegisterNetEvent('vehicle-auction:createAuction', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        TriggerClientEvent('QBCore:Notify', src, "Error creating auction: Player not found", "error")
        return
    end
    

    
    if not data.vehicle or not data.startingBid or not data.duration then
        TriggerClientEvent('QBCore:Notify', src, "Invalid auction data provided", "error")
        return
    end
    
    local durationInSeconds = math.floor(data.duration * 3600)
    
    if durationInSeconds < 60 then
        TriggerClientEvent('QBCore:Notify', src, "Auction duration must be at least 1 minute", "error")
        return
    end
    
    local endTime = os.time() + durationInSeconds
    
    local durationText = ""
    if data.duration < 1 then
        local minutes = math.floor(data.duration * 60)
        durationText = minutes .. " minute" .. (minutes > 1 and "s" or "")
    else
        local hours = math.floor(data.duration)
        local minutes = math.floor((data.duration - hours) * 60)
        
        if minutes > 0 then
            durationText = hours .. " hour" .. (hours > 1 and "s" or "") .. " and " .. minutes .. " minute" .. (minutes > 1 and "s" or "")
        else
            durationText = hours .. " hour" .. (hours > 1 and "s" or "")
        end
    end
    
    exports.oxmysql:insert('INSERT INTO vehicle_auctions (vehicle, startingBid, currentBid, endTime, createdBy) VALUES (?, ?, ?, ?, ?)', {
        data.vehicle,
        data.startingBid,
        data.startingBid,
        endTime,
        Player.PlayerData.citizenid
    }, function(auctionId)
        if not auctionId or auctionId <= 0 then
            TriggerClientEvent('QBCore:Notify', src, "Failed to create auction", "error")
            return
        end
        
        local newAuction = {
            id = auctionId,
            vehicle = data.vehicle,
            startingBid = data.startingBid,
            currentBid = data.startingBid,
            endTime = endTime,
            createdBy = Player.PlayerData.citizenid,
            highestBidder = nil
        }
        
        activeAuctions[auctionId] = newAuction
        
        
        SetTimeout(durationInSeconds * 1000, function()
            CompleteAuction(auctionId, activeAuctions[auctionId])
        end)
        
        SendDiscordWebhook(
            "AuctionCreated",
            "New Vehicle Auction Created",
            "**Vehicle:** " .. data.vehicle .. "\n" ..
            "**Starting Bid:** $" .. data.startingBid .. "\n" ..
            "**Duration:** " .. durationText .. "\n" ..
            "**End Time:** " .. os.date("%Y-%m-%d %H:%M:%S", endTime),
            Config.Colors.Blue
        )
        
        Citizen.Wait(500)
        
        local clientAuctions = PrepareAuctionsForClient()
        TriggerClientEvent('vehicle-auction:receiveAuctions', -1, clientAuctions)
        
        BroadcastAuctionUpdate(auctionId, "created", {
            vehicle = data.vehicle,
            id = auctionId
        })
        
        TriggerClientEvent('QBCore:Notify', src, "Auction  created successfully for " .. durationText, "success")
    end)
end)

RegisterNetEvent('vehicle-auction:claimVehicle', function(claimId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local result = exports.oxmysql:executeSync('SELECT * FROM auction_claims WHERE id = ? AND citizenid = ? AND claimed = 0', {
        claimId,
        Player.PlayerData.citizenid
    })
    
    if not result or not result[1] then
        TriggerClientEvent('QBCore:Notify', src, "Vehicle claim not found or already claimed", "error")
        return
    end
    
    local claim = result[1]
    
    if os.time() > claim.claim_expires then
        TriggerClientEvent('QBCore:Notify', src, "This claim has expired", "error")
        
        exports.oxmysql:execute('UPDATE auction_claims SET claimed = 1 WHERE id = ?', {claimId})
        Player.Functions.AddMoney('bank', math.floor(claim.amount / 2), "expired-auction-refund")
        
        return
    end
    
    local plate = GeneratePlate()
    
    exports.oxmysql:execute('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        Player.PlayerData.license,
        Player.PlayerData.citizenid,
        claim.vehicle,
        GetHashKey(claim.vehicle),
        '{}',
        plate,
        0
    })
    
    exports.oxmysql:execute('UPDATE auction_claims SET claimed = 1 WHERE id = ?', {claimId})
    
    TriggerClientEvent('QBCore:Notify', src, "Vehicle successfully claimed! Check your garage.", "success")
    
    local playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
    SendDiscordWebhook(
        "AuctionCompleted",
        "Vehicle Claimed From Auction",
        "**Vehicle:** " .. claim.vehicle .. "\n" ..
        "**Claimed By:** " .. playerName .. "\n" ..
        "**Plate:** " .. plate .. "\n" ..
        "**Time:** " .. os.date("%Y-%m-%d %H:%M:%S", os.time()),
        Config.Colors.Green
    )
end)

function GeneratePlate()
    local plate = string.upper(QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(3))
    
    local result = exports.oxmysql:executeSync('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if result and #result > 0 then
        return GeneratePlate()
    end
    
    return plate
end

function SendDiscordWebhook(webhookType, title, data, color)
    if not Config.Webhooks[webhookType] then return end
    
    PerformHttpRequest(Config.Webhooks[webhookType], function(err, text, headers) end, 'POST', json.encode({
        embeds = {{
            title = title,
            description = data,
            color = color,
            footer = {
                text = "Ranjit - Vehicle Auction System • " .. os.date("%Y-%m-%d %H:%M:%S")
            }
        }}
    }), { ['Content-Type'] = 'application/json' })
end

function GetPlayerClaims(citizenid)
    local result = exports.oxmysql:executeSync('SELECT * FROM auction_claims WHERE citizenid = ? AND claimed = 0', {citizenid})
    if result then
        for i, claim in ipairs(result) do
            result[i].expires = os.date("%Y-%m-%d %H:%M:%S", claim.claim_expires)
        end
    end
    return result or {}
end

RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local claims = exports.oxmysql:executeSync('SELECT * FROM auction_claims WHERE citizenid = ? AND claimed = 0 AND claim_expires < ?', {
        Player.PlayerData.citizenid,
        os.time()
    })
    
    if claims and #claims > 0 then
        for _, claim in ipairs(claims) do
            exports.oxmysql:execute('UPDATE auction_claims SET claimed = 1 WHERE id = ?', {claim.id})
            
            local bidResult = exports.oxmysql:executeSync('SELECT amount FROM auction_bids WHERE bidder = ? AND auctionId IN (SELECT id FROM vehicle_auctions WHERE vehicle = ?)', {
                Player.PlayerData.citizenid,
                claim.vehicle
            })
            
            if bidResult and bidResult[1] then
                local refundAmount = math.floor(bidResult[1].amount / 2)
                Player.Functions.AddMoney('bank', refundAmount, "expired-claim-refund")
                TriggerClientEvent('QBCore:Notify', src, "You have an expired vehicle claim. $" .. refundAmount .. " has been refunded to your account", "info")
            end
        end
    end
end)

RegisterNetEvent('vehicle-auction:requestAuctions', function()
    local src = source
    local auctions = PrepareAuctionsForClient()
    TriggerClientEvent('vehicle-auction:receiveAuctions', src, auctions)
end)

RegisterNetEvent('vehicle-auction:requestClaims', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    TriggerClientEvent('vehicle-auction:receiveClaims', src, GetPlayerClaims(Player.PlayerData.citizenid))
end)

QBCore.Commands.Add('createauction', 'Create a vehicle auction (Admin Only)', {}, false, function(source)
    TriggerClientEvent('vehicle-auction:openCreateMenu', source)
end, 'admin')

CreateThread(function()
    InitializeDatabase()
    Wait(1000)
    LoadAuctions()
end)

QBCore.Functions.CreateCallback("vehicle-auction:getActiveAuctions", function(source, cb)
    cb(PrepareAuctionsForClient())
end)

QBCore.Functions.CreateCallback("vehicle-auction:getBidHistory", function(source, cb, auctionId)
    local history = GetBidHistory(auctionId)
    cb(history)
end)

QBCore.Functions.CreateCallback("vehicle-auction:getClaimableVehicles", function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    
    cb(GetPlayerClaims(Player.PlayerData.citizenid))
end)

QBCore.Functions.CreateCallback("vehicle-auction:placeBid", function(source, cb, auctionId, bidAmount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false, "Player not found") end
    
    local auction = activeAuctions[auctionId]
    if not auction then
        return cb(false, "This auction no longer exists")
    end
    
    if os.time() >= auction.endTime then
        return cb(false, "This auction has already ended")
    end
    
    local previousBidTime = nil
    local result = exports.oxmysql:executeSync('SELECT timestamp FROM auction_bids WHERE auctionId = ? AND bidder = ? ORDER BY timestamp DESC LIMIT 1', {
        auctionId,
        Player.PlayerData.citizenid
    })
    if result and result[1] then
        previousBidTime = result[1].timestamp
    end
    
    local isValid, validationMessage = ValidateBidIncrement(auction.currentBid, bidAmount, previousBidTime)
    if not isValid then
        return cb(false, validationMessage)
    end
    
    local canAfford, affordMessage = CanPlayerAffordBid(Player, bidAmount)
    if not canAfford then
        return cb(false, affordMessage)
    end
    
    if auction.highestBidder then
        local previousBidder = QBCore.Functions.GetPlayerByCitizenId(auction.highestBidder)
        if previousBidder then
            previousBidder.Functions.AddMoney('bank', auction.currentBid, "auction-bid-refund")
            TriggerClientEvent('QBCore:Notify', previousBidder.PlayerData.source, "You have been outbid! Your $" .. auction.currentBid .. " has been refunded", "info")
        else
            AddMoneyToOfflinePlayer(auction.highestBidder, auction.currentBid)
        end
    end
    
    Player.Functions.RemoveMoney('bank', bidAmount, "auction-bid-placed")
    
    local currentTime = os.time()
    activeAuctions[auctionId].currentBid = bidAmount
    activeAuctions[auctionId].highestBidder = Player.PlayerData.citizenid
    
    exports.oxmysql:insert('INSERT INTO auction_bids (auctionId, bidder, amount, timestamp) VALUES (?, ?, ?, ?)', {
        auctionId,
        Player.PlayerData.citizenid,
        bidAmount,
        currentTime
    })
    
    exports.oxmysql:execute('UPDATE vehicle_auctions SET currentBid = ?, highestBidder = ? WHERE id = ?', {
        bidAmount,
        Player.PlayerData.citizenid,
        auctionId
    })
    
    local bidderName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
    SendDiscordWebhook(
        "BidPlaced",
        "New Bid Placed on Vehicle Auction",
        "**Vehicle:** " .. auction.vehicle .. "\n" ..
        "**Bidder:** " .. bidderName .. "\n" ..
        "**Bid Amount:** $" .. bidAmount .. "\n" ..
        "**Time:** " .. os.date("%Y-%m-%d %H:%M:%S", currentTime),
        Config.Colors.Yellow
    )
    
    BroadcastAuctionUpdate(auctionId, "bid", {
        bidder = bidderName,
        amount = bidAmount
    })
    
    cb(true, "Bid placed successfully!")
end)

QBCore.Functions.CreateCallback("vehicle-auction:claimVehicle", function(source, cb, claimId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    local result = exports.oxmysql:executeSync('SELECT * FROM auction_claims WHERE id = ? AND citizenid = ? AND claimed = 0', {
        claimId,
        Player.PlayerData.citizenid
    })
    
    if not result or not result[1] then
        return cb(false)
    end
    
    local claim = result[1]
    
    if os.time() > claim.claim_expires then
        TriggerClientEvent('QBCore:Notify', source, "This claim has expired", "error")
        
        exports.oxmysql:execute('UPDATE auction_claims SET claimed = 1 WHERE id = ?', {claimId})
        
        local bidResult = exports.oxmysql:executeSync('SELECT amount FROM auction_bids WHERE bidder = ? AND auctionId IN (SELECT id FROM vehicle_auctions WHERE vehicle = ?)', {
            Player.PlayerData.citizenid,
            claim.vehicle
        })
        
        if bidResult and bidResult[1] then
            local refundAmount = math.floor(bidResult[1].amount / 2)
            Player.Functions.AddMoney('bank', refundAmount, "expired-auction-refund")
        end
        
        return cb(false)
    end
    
    local plate = GeneratePlate()
    
    exports.oxmysql:execute('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        Player.PlayerData.license,
        Player.PlayerData.citizenid,
        claim.vehicle,
        GetHashKey(claim.vehicle),
        '{}',
        plate,
        0
    })
    
    exports.oxmysql:execute('UPDATE auction_claims SET claimed = 1 WHERE id = ?', {claimId})
    
    local playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
    SendDiscordWebhook(
        "AuctionCompleted",
        "Vehicle Claimed From Auction",
        "**Vehicle:** " .. claim.vehicle .. "\n" ..
        "**Claimed By:** " .. playerName .. "\n" ..
        "**Plate:** " .. plate .. "\n" ..
        "**Time:** " .. os.date("%Y-%m-%d %H:%M:%S", os.time()),
        Config.Colors.Green
    )
    
    cb(true, {model = claim.vehicle, plate = plate})
end)

function GetBidHistory(auctionId)
    local results = exports.oxmysql:executeSync('SELECT b.*, p.charinfo FROM auction_bids b LEFT JOIN players p ON b.bidder = p.citizenid WHERE b.auctionId = ? ORDER BY b.timestamp DESC LIMIT 20', {auctionId})
    
    if not results then return {} end
    
    local history = {}
    for _, bid in ipairs(results) do
        local charInfo = json.decode(bid.charinfo) or {}
        local bidderName = "Unknown"
        if charInfo.firstname and charInfo.lastname then
            bidderName = charInfo.firstname .. " " .. charInfo.lastname
        end
        
        table.insert(history, {
            bidder = bid.bidder,
            charName = bidderName,
            amount = bid.amount,
            timestamp = bid.timestamp
        })
    end
    
    return history
end

RegisterNetEvent("vehicle-auction:requestBidHistory", function(auctionId)
    local src = source
    local history = GetBidHistory(auctionId)
    TriggerClientEvent("vehicle-auction:receiveBidHistory", src, history)
end)





QBCore.Functions.CreateCallback("vehicle-auction:getBidHistory", function(source, cb, auctionId)
    if not auctionId then
        return cb({})
    end
    
    local history = exports.oxmysql:executeSync('SELECT b.*, p.charinfo FROM auction_bids b LEFT JOIN players p ON b.bidder = p.citizenid WHERE b.auctionId = ? ORDER BY b.timestamp DESC LIMIT 20', {auctionId})
    
    if not history or #history == 0 then
        return cb({})
    end
    
    local formattedHistory = {}
    for _, bid in ipairs(history) do
        local charInfo = json.decode(bid.charinfo) or {}
        local bidderName = "Unknown"
        if charInfo.firstname and charInfo.lastname then
            bidderName = charInfo.firstname .. " " .. charInfo.lastname
        end
        
        table.insert(formattedHistory, {
            bidder = bid.bidder,
            charName = bidderName,
            amount = bid.amount,
            timestamp = bid.timestamp
        })
    end
    
    cb(formattedHistory)
end)

QBCore.Functions.CreateCallback("vehicle-auction:getClaimableVehicles", function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    
    local result = exports.oxmysql:executeSync('SELECT * FROM auction_claims WHERE citizenid = ? AND claimed = 0 AND claim_expires > ?',
        {Player.PlayerData.citizenid, os.time()})
    
    if result then
        for i, claim in ipairs(result) do
            result[i].expires = os.date("%Y-%m-%d %H:%M:%S", claim.claim_expires)
            
            result[i].vehicleName = claim.vehicle:upper()
        end
    end
    
    cb(result or {})
end)

QBCore.Functions.CreateCallback("vehicle-auction:validateClaim", function(source, cb, claimId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    local result = exports.oxmysql:executeSync('SELECT * FROM auction_claims WHERE id = ? AND citizenid = ? AND claimed = 0 AND claim_expires > ?', {
        claimId,
        Player.PlayerData.citizenid,
        os.time()
    })
    
    cb(result ~= nil and #result > 0)
end)

RegisterNetEvent('vehicle-auction:completeClaim')
AddEventHandler('vehicle-auction:completeClaim', function(claimId, props, plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local claim = exports.oxmysql:executeSync('SELECT * FROM auction_claims WHERE id = ? AND citizenid = ? AND claimed = 0', {
        claimId,
        Player.PlayerData.citizenid
    })[1]
    
    
    local success = MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        Player.PlayerData.license,
        Player.PlayerData.citizenid,
        claim.vehicle,
        props.model,
        json.encode(props),
        plate,
        1
    })
    
    if success then
        exports.oxmysql:execute('UPDATE auction_claims SET claimed = 1 WHERE id = ?', {claimId})
        TriggerClientEvent('QBCore:Notify', src, 'Vehicle successfully claimed and registered', 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to save vehicle', 'error')
    end
end)

RegisterNetEvent('vehicle-auction:server:SaveCar')
AddEventHandler('vehicle-auction:server:SaveCar', function(mods, vehicle, hash, plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local result = MySQL.query.await('SELECT plate FROM player_vehicles WHERE plate = ?', { plate })
    if result[1] == nil then
        MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            Player.PlayerData.license,
            Player.PlayerData.citizenid,
            vehicle.model,
            hash,
            json.encode(mods),
            plate,
            0
        })
        TriggerClientEvent('QBCore:Notify', src, 'Vehicle successfully registered to you', 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Failed to claim vehicle - Plate already exists', 'error')
    end
end)

RegisterNetEvent('vehicle-auction:markClaimed', function(claimId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    exports.oxmysql:execute('UPDATE auction_claims SET claimed = 1 WHERE id = ? AND citizenid = ?', {
        claimId,
        Player.PlayerData.citizenid
    })
    
    local playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
    
    local vehicleInfo = exports.oxmysql:executeSync('SELECT vehicle FROM auction_claims WHERE id = ?', {claimId})
    
    if vehicleInfo and vehicleInfo[1] then
        SendDiscordWebhook(
            "AuctionCompleted",
            "Vehicle Claimed From Auction",
            "**Vehicle:** " .. vehicleInfo[1].vehicle .. "\n" ..
            "**Claimed By:** " .. playerName .. "\n" ..
            "**Time:** " .. os.date("%Y-%m-%d %H:%M:%S", os.time()),
            Config.Colors.Green
        )
    end
end)

RegisterNetEvent('vehicle-auction:server:SaveCar', function(props, vehicleInfo, hash, plate, claimId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local result = exports.oxmysql:executeSync('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if result and #result > 0 then
        TriggerClientEvent('QBCore:Notify', src, "A vehicle with this plate already exists", "error")
        return
    end
    
    local vehicle = vehicleInfo.model
    if not vehicle then vehicle = props.model end
    
    local success = exports.oxmysql:insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        Player.PlayerData.license,
        Player.PlayerData.citizenid,
        vehicle,
        hash,
        json.encode(props),
        plate,
        1
    })
    
    if success then
        if claimId then
            exports.oxmysql:execute('UPDATE auction_claims SET claimed = 1 WHERE id = ? AND citizenid = ?', {
                claimId,
                Player.PlayerData.citizenid
            })
        end
        
        local playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        SendDiscordWebhook(
            "AuctionCompleted",
            "Vehicle Successfully Stored in Garage",
            "**Vehicle:** " .. vehicle .. "\n" ..
            "**Owner:** " .. playerName .. "\n" ..
            "**Plate:** " .. plate .. "\n" ..
            "**Time:** " .. os.date("%Y-%m-%d %H:%M:%S", os.time()),
            Config.Colors.Green
        )
        
        TriggerClientEvent('QBCore:Notify', src, "Vehicle saved to garage with plate: " .. plate, "success")
    else
        TriggerClientEvent('QBCore:Notify', src, "Failed to save vehicle to garage", "error")
    end
end)

QBCore.Functions.CreateCallback("vehicle-auction:validateClaim", function(source, cb, claimId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    local result = exports.oxmysql:executeSync('SELECT * FROM auction_claims WHERE id = ? AND citizenid = ? AND claimed = 0 AND claim_expires > ?', {
        claimId,
        Player.PlayerData.citizenid,
        os.time()
    })
    
    cb(result and #result > 0)
end)

QBCore.Functions.CreateCallback("vehicle-auction:claimVehicle", function(source, cb, claimId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    local result = exports.oxmysql:executeSync('SELECT * FROM auction_claims WHERE id = ? AND citizenid = ? AND claimed = 0', {
        claimId,
        Player.PlayerData.citizenid
    })
    
    if not result or not result[1] then
        return cb(false)
    end
    
    local claim = result[1]
    
    if os.time() > claim.claim_expires then
        TriggerClientEvent('QBCore:Notify', source, "This claim has expired", "error")
        
        exports.oxmysql:execute('UPDATE auction_claims SET claimed = 1 WHERE id = ?', {claimId})
        
        local bidResult = exports.oxmysql:executeSync('SELECT amount FROM auction_bids WHERE bidder = ? AND auctionId IN (SELECT id FROM vehicle_auctions WHERE vehicle = ? ORDER BY timestamp DESC LIMIT 1)', {
            Player.PlayerData.citizenid,
            claim.vehicle
        })
        
        if bidResult and bidResult[1] then
            local refundAmount = math.floor(bidResult[1].amount / 2)
            Player.Functions.AddMoney('bank', refundAmount, "expired-auction-refund")
            TriggerClientEvent('QBCore:Notify', source, "You've been refunded $" .. refundAmount .. " for your expired claim", "info")
        end
        
        return cb(false)
    end
    
    cb(true, {model = claim.vehicle})
end)