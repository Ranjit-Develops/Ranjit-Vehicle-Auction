local QBCore = exports['qb-core']:GetCoreObject()

local previewVehicle = nil
local previewCamera = nil
local isCameraActive = false
local currentZoomLevel = 5.0
local activeAuctions = {}
local claimableVehicles = {}
local currentAuctionData = nil
local previewState = {
    lastPreviewModel = nil,
    previewActive = false,
    rotationZ = 0.0
}
print("^2Ranjit - Car Auction Script By ranjit_07^7")
CreateThread(function()
    SetupAuctionHouse()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "hideUI" })
end)

function SetupAuctionHouse()
    local blip = AddBlipForCoord(Config.AuctionHouse.Ped.coords.x, Config.AuctionHouse.Ped.coords.y, Config.AuctionHouse.Ped.coords.z)
    SetBlipSprite(blip, Config.AuctionHouse.Blip.sprite)
    SetBlipColour(blip, Config.AuctionHouse.Blip.color)
    SetBlipScale(blip, Config.AuctionHouse.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.AuctionHouse.Blip.label)
    EndTextCommandSetBlipName(blip)

    local pedModel = Config.AuctionHouse.Ped.model
    RequestModel(GetHashKey(pedModel))
    while not HasModelLoaded(GetHashKey(pedModel)) do
        Wait(1)
    end

    auctionPed = CreatePed(4, GetHashKey(pedModel),
        Config.AuctionHouse.Ped.coords.x,
        Config.AuctionHouse.Ped.coords.y,
        Config.AuctionHouse.Ped.coords.z - 1.0,
        Config.AuctionHouse.Ped.coords.w,
        false,
        true
    )
    
    SetEntityAsMissionEntity(auctionPed, true, true)
    SetBlockingOfNonTemporaryEvents(auctionPed, true)
    FreezeEntityPosition(auctionPed, true)
    SetEntityInvincible(auctionPed, true)
    TaskStartScenarioInPlace(auctionPed, Config.AuctionHouse.Ped.scenario, 0, true)

    exports['qb-target']:AddTargetEntity(auctionPed, {
        options = {
            {
                type = "client",
                event = "vehicle-auction:openMenu",
                icon = "fas fa-car-alt",
                label = "Browse Vehicle Auctions",
            },
            {
                type = "client",
                event = "vehicle-auction:openClaimMenu",
                icon = "fas fa-key",
                label = "Claim Won Vehicles",
            },
        },
        distance = 2.5,
    })
end

function CleanupPreview(force)
    if force and previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
        previewVehicle = nil
    end
    previewState.previewActive = false
end

function PreviewVehicle(model)
    if previewState.lastPreviewModel == model and previewVehicle and DoesEntityExist(previewVehicle) then
        return
    end
    
    CleanupPreview(true)
    
    local hash = GetHashKey(model)
    RequestModel(hash)
    
    local attempts = 0
    while not HasModelLoaded(hash) and attempts < 50 do
        Wait(100)
        attempts = attempts + 1
    end
    
    if not HasModelLoaded(hash) then
        QBCore.Functions.Notify('Failed to load vehicle model', 'error')
        return
    end
    
    local coords = Config.AuctionHouse.PreviewSpot
    previewVehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.w, false, false)
    
    if not DoesEntityExist(previewVehicle) then
        QBCore.Functions.Notify('Failed to create preview vehicle', 'error')
        return
    end
    
    SetEntityHeading(previewVehicle, coords.w)
    SetVehicleOnGroundProperly(previewVehicle)
    FreezeEntityPosition(previewVehicle, true)
    SetVehicleDoorsLocked(previewVehicle, 2)
    SetVehicleDirtLevel(previewVehicle, 0.0)
    SetVehicleLights(previewVehicle, 2)
    SetVehicleBurnout(previewVehicle, false)
    SetVehicleEngineOn(previewVehicle, true, true, false)
    
    previewState.lastPreviewModel = model
    previewState.previewActive = true
    previewState.rotationZ = coords.w
    
    local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(hash))
    if vehicleName == "NULL" or vehicleName == "" then
        vehicleName = GetDisplayNameFromVehicleModel(hash)
        if vehicleName == "NULL" or vehicleName == "" then
            vehicleName = model:upper()
        end
    end
    
    SendNUIMessage({
        action = "updatePreviewName",
        name = vehicleName
    })
    
    SendNUIMessage({
        action = "showPreviewMode"
    })
    
    SetNuiFocus(true, true)
    
    CreatePreviewCamera()
end

function CreatePreviewCamera()
    if previewCamera then
        DestroyCam(previewCamera, true)
    end
    
    previewCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    
    if not previewVehicle or not DoesEntityExist(previewVehicle) then
        return
    end
    
    local vehicleModel = GetEntityModel(previewVehicle)
    local minDim, maxDim = GetModelDimensions(vehicleModel)
    
    local vehicleSize = maxDim - minDim
    local vehicleHeight = vehicleSize.z
    local vehicleLength = vehicleSize.y
    local vehicleWidth = vehicleSize.x
    
    local camDistance = (vehicleLength * 2.0) + 1.0
    
    local vehicleCoords = GetEntityCoords(previewVehicle)
    local camX = vehicleCoords.x - (camDistance * math.sin(math.rad(previewState.rotationZ)))
    local camY = vehicleCoords.y - (camDistance * math.cos(math.rad(previewState.rotationZ)))
    local camZ = vehicleCoords.z + (vehicleHeight * 0.5) + 0.6
    
    SetCamCoord(previewCamera, camX, camY, camZ)
    PointCamAtCoord(previewCamera, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + (vehicleHeight * 0.3))
    
    local baseFov = Config.Camera.defaultFov
    SetCamFov(previewCamera, baseFov)
    
    SetCamActive(previewCamera, true)
    RenderScriptCams(true, true, 1000, true, true)
    
    isCameraActive = true
    currentZoomLevel = camDistance
    
    CreateThread(function()
        while isCameraActive and previewState.previewActive do
            Wait(0)
            
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 38, true)
            DisableControlAction(0, 47, true)
            DisableControlAction(0, 71, true)
            DisableControlAction(0, 72, true)
            DisableControlAction(0, 75, true)
            
            if IsControlJustPressed(0, 177) then
                ExitPreviewMode()
            end
        end
    end)
end

function RotatePreviewVehicle(direction)
    if not previewVehicle or not DoesEntityExist(previewVehicle) then return end
    
    local rotationAmount = 45.0
    
    if direction == "left" then
        previewState.rotationZ = previewState.rotationZ - rotationAmount
    elseif direction == "right" then
        previewState.rotationZ = previewState.rotationZ + rotationAmount
    end
    
    SetEntityHeading(previewVehicle, previewState.rotationZ)
    
    if previewCamera then
        local vehicleCoords = GetEntityCoords(previewVehicle)
        local minDim, maxDim = GetModelDimensions(GetEntityModel(previewVehicle))
        local vehicleSize = maxDim - minDim
        local camDistance = (vehicleSize.y * 2.0) + 1.0
        
        local camX = vehicleCoords.x - (camDistance * math.sin(math.rad(previewState.rotationZ)))
        local camY = vehicleCoords.y - (camDistance * math.cos(math.rad(previewState.rotationZ)))
        local camZ = vehicleCoords.z + (vehicleSize.z * 0.5) + 0.6
        
        SetCamCoord(previewCamera, camX, camY, camZ)
        PointCamAtCoord(previewCamera, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + (vehicleSize.z * 0.3))
    end
end

function ExitPreviewMode()
    previewState.previewActive = false
    isCameraActive = false
    
    if previewCamera then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(previewCamera, true)
        previewCamera = nil
    end
    
    if previewVehicle then
        DeleteEntity(previewVehicle)
        previewVehicle = nil
    end
    
    SendNUIMessage({
        action = "hidePreviewMode"
    })
    
    SetNuiFocus(true, true)
end

function OpenAuctionMenu()
    TriggerServerEvent("vehicle-auction:requestAuctions")
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openAuctionMenu",
        loading = true
    })
end

function RefreshAuctionData()
    TriggerServerEvent("vehicle-auction:requestAuctions")
end

function FormatTimeRemaining(endTime)
    local currentTime = os.time()
    local remainingSeconds = endTime - currentTime
    
    if (remainingSeconds <= 0) then
        return "Ended"
    end
    
    local days = math.floor(remainingSeconds / 86400)
    remainingSeconds = remainingSeconds - (days * 86400)
    
    local hours = math.floor(remainingSeconds / 3600)
    remainingSeconds = remainingSeconds - (hours * 3600)
    
    local minutes = math.floor(remainingSeconds / 60)
    remainingSeconds = remainingSeconds - (minutes * 60)
    
    local timeStr = ""
    if (days > 0) then
        timeStr = days .. "d " .. hours .. "h"
    elseif (hours > 0) then
        timeStr = hours .. "h " .. minutes .. "m"
    elseif (minutes > 0) then
        timeStr = minutes .. "m " .. remainingSeconds .. "s"
    else
        timeStr = remainingSeconds .. "s"
    end
    
    return timeStr
end

function SubmitBid(auctionId, bidAmount)
    TriggerServerEvent("vehicle-auction:placeBid", auctionId, bidAmount)
end

function RequestBidHistory(auctionId)
    if not auctionId then return end
    
    QBCore.Functions.TriggerCallback("vehicle-auction:getBidHistory", function(history)
        SendNUIMessage({
            action = "updateBidHistory",
            history = history
        })
    end, auctionId)
end

function OpenClaimMenu()
    TriggerEvent('vehicle-auction:claimVehicle')
end

RegisterNUICallback("closeUI", function(data, cb)
    SetNuiFocus(false, false)
    if isCameraActive then
        ExitPreviewMode()
    end
    cb({})
end)

RegisterNUICallback("previewVehicle", function(data, cb)
    local vehicleModel = data.vehicle
    PreviewVehicle(vehicleModel)
    cb({})
end)

RegisterNUICallback("placeBid", function(data, cb)
    SubmitBid(data.auctionId, data.bidAmount)
    cb({})
end)

RegisterNUICallback("getBidHistory", function(data, cb)
    RequestBidHistory(data.auctionId)
    cb({})
end)

RegisterNUICallback("closeMenu", function(data, cb)
    SetNuiFocus(false, false)
    if isCameraActive then
        ExitPreviewMode()
    end
    cb({})
end)

RegisterNUICallback("rotatePreview", function(data, cb)
    RotatePreviewVehicle(data.direction)
    cb({success = true})
end)

RegisterNUICallback("closePreview", function(data, cb)
    ExitPreviewMode()
    cb({})
end)

function CloseAuctionUI()
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = "hideUI"
    })
    if isCameraActive then
        ExitPreviewMode()
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    SetNuiFocus(false, false)
end)

RegisterNetEvent("vehicle-auction:openMenu", function()
    OpenAuctionMenu()
end)

RegisterNetEvent("vehicle-auction:openClaimMenu", function()
    OpenClaimMenu()
end)

RegisterNetEvent("vehicle-auction:updateAuctions", function(auctions)
    activeAuctions = auctions
    RefreshAuctionData()
end)

RegisterNetEvent("vehicle-auction:auctionUpdate", function(auctionId, newBid, bidderName)
    for i, auction in pairs(activeAuctions) do
        if auction.id == auctionId then
            auction.currentBid = newBid
            break
        end
    end
    
    if currentAuctionData and currentAuctionData.id == auctionId then
        QBCore.Functions.Notify(bidderName .. " placed a bid of $" .. newBid .. " on " .. currentAuctionData.vehicleName, "primary")
    end
    
    RefreshAuctionData()
    RequestBidHistory(auctionId)
end)

RegisterNetEvent("vehicle-auction:auctionComplete", function(auctionId, winnerName)
    for i, auction in pairs(activeAuctions) do
        if auction.id == auctionId then
            table.remove(activeAuctions, i)
            QBCore.Functions.Notify("Auction for " .. auction.vehicleName .. " has ended. Winner: " .. winnerName, "primary")
            break
        end
    end
    
    RefreshAuctionData()
end)

RegisterNetEvent("vehicle-auction:receiveAuctions", function(auctions)
    
    activeAuctions = auctions
    
    local formattedAuctions = {}
    for _, auction in pairs(activeAuctions) do
        local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(auction.vehicle)))
        if vehicleName == "NULL" or vehicleName == "" then
            vehicleName = GetDisplayNameFromVehicleModel(GetHashKey(auction.vehicle))
        end
        
        if vehicleName == "" then
            vehicleName = auction.vehicle:upper()
        end
        
        local auctionData = {
            id = auction.id,
            vehicle = auction.vehicle,
            vehicleName = vehicleName,
            startingBid = auction.startingBid,
            currentBid = auction.currentBid,
            timeRemaining = auction.timeRemaining,
            highestBidderName = auction.highestBidderName or "None",
            endTime = auction.endTime
        }
        
        table.insert(formattedAuctions, auctionData)
    end
    
    SendNUIMessage({
        action = "updateAuctions",
        auctions = formattedAuctions,
        loading = false
    })
end)

RegisterNetEvent("vehicle-auction:receiveBidHistory", function(bidHistory)
    SendNUIMessage({
        action = "updateBidHistory",
        history = bidHistory
    })
end)

RegisterNetEvent("vehicle-auction:receiveClaims", function(claims)
    claimableVehicles = claims
    
    if #claimableVehicles == 0 then
        QBCore.Functions.Notify("You have no vehicles to claim", "error")
        SetNuiFocus(false, false)
        return
    end
    
    local formattedVehicles = {}
    for _, claim in pairs(claimableVehicles) do
        table.insert(formattedVehicles, {
            id = claim.id,
            vehicle = claim.vehicle,
            vehicleName = GetDisplayNameFromVehicleModel(GetHashKey(claim.vehicle)),
            expires = claim.expires
        })
    end
    
    SendNUIMessage({
        action = "updateClaims",
        vehicles = formattedVehicles,
        loading = false
    })
end)

RegisterNetEvent("vehicle-auction:update", function(auctionId, updateType, data)
    if updateType == "bid" then
        QBCore.Functions.Notify(data.bidder .. " placed a bid of $" .. data.amount , "primary")
        RefreshAuctionData()
        
        if currentAuctionData and currentAuctionData.id == auctionId then
            TriggerServerEvent("vehicle-auction:requestBidHistory", auctionId)
        end
    elseif updateType == "completed" then
        QBCore.Functions.Notify("Auction for " .. data.vehicle .. " has ended. Winner: " .. data.winner, "primary")
        RefreshAuctionData()
    elseif updateType == "created" then
        local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(data.vehicle)))
        if vehicleName == "NULL" or vehicleName == "" then
            vehicleName = GetDisplayNameFromVehicleModel(GetHashKey(data.vehicle))
        end
        
        QBCore.Functions.Notify("New auction created for " .. vehicleName, "success")
        
        TriggerServerEvent("vehicle-auction:requestAuctions")
        
        if activeAuctions ~= nil then
            Wait(300)
            OpenAuctionMenu()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        if activeAuctions and next(activeAuctions) then
            RefreshAuctionData()
        end
    end
end)

RegisterNUICallback("selectAuction", function(data, cb)
    for _, auction in pairs(activeAuctions) do
        if auction.id == data.auctionId then
            currentAuctionData = auction
            break
        end
    end
    
    TriggerServerEvent("vehicle-auction:requestBidHistory", data.auctionId)
    cb({})
end)

RegisterNetEvent('vehicle-auction:openCreateMenu')
AddEventHandler('vehicle-auction:openCreateMenu', function()
    local categories = {}
    for category, _ in pairs(Config.VehiclePool) do
        table.insert(categories, {
            header = category:gsub("^%l", string.upper),
            params = {
                event = "vehicle-auction:selectVehicle",
                args = {
                    category = category
                }
            }
        })
    end
    
    table.insert(categories, 1, {
        header = "Create New Auction",
        isMenuHeader = true
    })
    
    table.insert(categories, {
        header = "⬅ Close",
        params = {
            event = "qb-menu:closeMenu"
        }
    })
    
    exports['qb-menu']:openMenu(categories)
end)

RegisterNetEvent('vehicle-auction:selectVehicle')
AddEventHandler('vehicle-auction:selectVehicle', function(data)
    local category = data.category
    local vehicles = Config.VehiclePool[category]
    local vehicleMenu = {}
    
    table.insert(vehicleMenu, {
        header = "Select a Vehicle",
        isMenuHeader = true
    })
    
    table.insert(vehicleMenu, {
        header = "⬅ Go Back",
        params = {
            event = "vehicle-auction:openCreateMenu"
        }
    })
    
    for _, vehicle in ipairs(vehicles) do
        table.insert(vehicleMenu, {
            header = vehicle.name,
            txt = "Select this vehicle for auction",
            params = {
                event = "vehicle-auction:setAuctionParams",
                args = {
                    vehicleName = vehicle.name,
                    vehicleModel = vehicle.model
                }
            }
        })
    end
    
    exports['qb-menu']:openMenu(vehicleMenu)
end)

RegisterNetEvent('vehicle-auction:setAuctionParams')
AddEventHandler('vehicle-auction:setAuctionParams', function(data)
    local vehicleName = data.vehicleName
    local vehicleModel = data.vehicleModel
    
    if Config.EnablePreviewInAdmin then
        PreviewVehicle(vehicleModel)
    end
    
    local dialog = exports['qb-input']:ShowInput({
        header = "Create Auction for " .. vehicleName,
        submitText = "Create Auction",
        inputs = {
            {
                text = "Starting Bid ($)",
                name = "startingBid",
                type = "number",
                isRequired = true,
                default = "5000"
            },
            {
                text = "0.01=1min, 1=1hr",
                name = "duration",
                type = "text",
                isRequired = true,
                default = "24"
            }
        }
    })
    
    if dialog then
        local startingBid = tonumber(dialog.startingBid)
        local duration = tonumber(dialog.duration)
        
        if not startingBid or startingBid <= 0 then
            QBCore.Functions.Notify("Starting bid must be greater than $0", "error")
            return
        end
        
        if not duration or duration <= 0 or duration > 168 then
            QBCore.Functions.Notify("Duration must be between 0.01 (1 minute) and 168 hours", "error")
            return
        end
        
        local durationText = ""
        if duration < 0.02 then
            QBCore.Functions.Notify("Duration must be at least 0.01 hours (1 minute)", "error")
            return
        elseif duration < 1 then
            local minutes = math.floor(duration * 60)
            durationText = minutes .. " minute" .. (minutes > 1 and "s" or "")
            QBCore.Functions.Notify("Creating auction for " .. durationText, "primary")
        else
            local hours = math.floor(duration)
            local minutes = math.floor((duration - hours) * 60)
            
            if minutes > 0 then
                durationText = hours .. " hour" .. (hours > 1 and "s" or "") .. " and " .. minutes .. " minute" .. (minutes > 1 and "s" or "")
            else
                durationText = hours .. " hour" .. (hours > 1 and "s" or "")
            end
            QBCore.Functions.Notify("Creating auction for " .. durationText, "primary")
        end
        
        TriggerServerEvent('vehicle-auction:createAuction', {
            vehicle = vehicleModel,
            startingBid = startingBid,
            duration = duration
        })
        
        if Config.EnablePreviewInAdmin and isCameraActive then
            ExitPreviewMode()
        end
        
        exports['qb-menu']:closeMenu()
        
        Wait(1000)
        OpenAuctionMenu()
    else
        if Config.EnablePreviewInAdmin and isCameraActive then
            ExitPreviewMode()
        end
    end
end)

RegisterNetEvent('vehicle-auction:claimVehicle')
AddEventHandler('vehicle-auction:claimVehicle', function()
    if GlobalState.lastClaimTime and (GetGameTimer() - GlobalState.lastClaimTime) < 2000 then
        return
    end
    GlobalState.lastClaimTime = GetGameTimer()
    
    QBCore.Functions.TriggerCallback('vehicle-auction:getClaimableVehicles', function(vehicles)
        if not vehicles or #vehicles == 0 then
            QBCore.Functions.Notify('No vehicles to claim!', 'error')
            return
        end
        
        local claimMenu = {
            {
                header = "🏆 Claim Won Vehicles",
                isMenuHeader = true
            }
        }
        
        local seenVehicles = {}
        for _, vehicle in ipairs(vehicles) do
            if not seenVehicles[vehicle.id] then
                seenVehicles[vehicle.id] = true
                local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(vehicle.vehicle)))
                if vehicleName == "NULL" or vehicleName == "" then
                    vehicleName = vehicle.vehicle:upper()
                end
                
                table.insert(claimMenu, {
                    header = vehicleName,
                    txt = "Won vehicle - Click to claim",
                    params = {
                        event = "vehicle-auction:confirmClaim",
                        args = {
                            claimId = vehicle.id,
                            vehicle = vehicle.vehicle
                        }
                    }
                })
            end
        end
        
        table.insert(claimMenu, {
            header = "⬅ Close",
            params = {
                event = "qb-menu:closeMenu"
            }
        })
        
        exports['qb-menu']:openMenu(claimMenu)
    end)
end)

RegisterNetEvent('vehicle-auction:confirmClaim')
AddEventHandler('vehicle-auction:confirmClaim', function(data)
    if GlobalState.lastConfirmTime and (GetGameTimer() - GlobalState.lastConfirmTime) < 2000 then
        return
    end
    GlobalState.lastConfirmTime = GetGameTimer()
    
    local coords = GetEntityCoords(PlayerPedId())
    local spawnPoint = vector4(coords.x + 3.0, coords.y + 3.0, coords.z, 0.0)
    
    QBCore.Functions.TriggerCallback('vehicle-auction:claimVehicle', function(success, vehicleData)
        if not success then
            QBCore.Functions.Notify('This vehicle has already been claimed', 'error')
            return
        end
        
        if GlobalState.isSpawningVehicle then
            QBCore.Functions.Notify('Please wait for your current vehicle to spawn', 'error')
            return
        end
        
        GlobalState.isSpawningVehicle = true
        QBCore.Functions.SpawnVehicle(data.vehicle, function(veh)
            GlobalState.isSpawningVehicle = false
            if not veh or not DoesEntityExist(veh) then
                QBCore.Functions.Notify('Failed to spawn vehicle', 'error')
                return
            end
            
            SetEntityHeading(veh, spawnPoint.w)
            SetVehicleEngineOn(veh, true, true, false)
            TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
            TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
            CreateThread(function()
                local timeout = 60
                local entered = false
                while timeout > 0 and not entered do
                    if IsPedInVehicle(PlayerPedId(), veh, false) then
                        entered = true
                        Wait(1000)
                        local plate = QBCore.Functions.GetPlate(veh)
                        local props = QBCore.Functions.GetVehicleProperties(veh)
                        TriggerServerEvent('vehicle-auction:completeClaim', data.claimId, props, plate)
                        break
                    end
                    timeout = timeout - 1
                    Wait(1000)
                end
                if not entered then
                    DeleteVehicle(veh)
                    QBCore.Functions.Notify('Vehicle claim timed out', 'error')
                end
            end)
        end, spawnPoint, true)
    end, data.claimId)
end)

RegisterNetEvent('vehicle-auction:claimVehicle')
AddEventHandler('vehicle-auction:claimVehicle', function()
    if GlobalState.lastClaimTime and (GetGameTimer() - GlobalState.lastClaimTime) < 2000 then
        return
    end
    GlobalState.lastClaimTime = GetGameTimer()
    
    QBCore.Functions.TriggerCallback('vehicle-auction:getClaimableVehicles', function(vehicles)
        if not vehicles or #vehicles == 0 then
            QBCore.Functions.Notify('No vehicles to claim!', 'error')
            return
        end
        
        local claimMenu = {
            {
                header = "🏆 Claim Won Vehicles",
                isMenuHeader = true
            }
        }
        
        for _, vehicle in ipairs(vehicles) do
            local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(GetHashKey(vehicle.vehicle)))
            if vehicleName == "NULL" or vehicleName == "" then
                vehicleName = GetDisplayNameFromVehicleModel(GetHashKey(vehicle.vehicle))
                if vehicleName == "NULL" or vehicleName == "" then
                    vehicleName = vehicle.vehicle:upper()
                end
            end
            
            table.insert(claimMenu, {
                header = vehicleName,
                txt = "Expires: " .. vehicle.expires,
                params = {
                    event = "vehicle-auction:confirmClaim",
                    args = {
                        claimId = vehicle.id,
                        vehicle = vehicle.vehicle,
                        vehicleName = vehicleName
                    }
                }
            })
        end
        
        table.insert(claimMenu, {
            header = "⬅ Close",
            params = {
                event = "qb-menu:closeMenu"
            }
        })
        
        exports['qb-menu']:openMenu(claimMenu)
    end)
end)

function getVehicleFromVehList(hash)
    local vehicles = QBCore.Shared.Vehicles
    for k, v in pairs(vehicles) do
        if hash == GetHashKey(k) then
            return k
        end
    end
    return nil
end

RegisterNetEvent('vehicle-auction:confirmClaim')
AddEventHandler('vehicle-auction:confirmClaim', function(data)
    if GlobalState.lastConfirmTime and (GetGameTimer() - GlobalState.lastConfirmTime) < 2000 then
        return
    end
    GlobalState.lastConfirmTime = GetGameTimer()
    
    QBCore.Functions.TriggerCallback('vehicle-auction:validateClaim', function(isValid)
        if not isValid then
            QBCore.Functions.Notify('This vehicle is unavailable or already claimed', 'error')
            return
        end
        
        local coords = GetEntityCoords(PlayerPedId())
        local spawnPoint = vector4(coords.x + 3.0, coords.y + 3.0, coords.z, 0.0)
        
        if GlobalState.isSpawningVehicle then
            QBCore.Functions.Notify('Please wait for your current vehicle to spawn', 'error')
            return
        end
        
        GlobalState.isSpawningVehicle = true
        QBCore.Functions.SpawnVehicle(data.vehicle, function(veh)
            GlobalState.isSpawningVehicle = false
            if not veh or not DoesEntityExist(veh) then
                QBCore.Functions.Notify('Failed to spawn vehicle', 'error')
                return
            end
            
            SetEntityHeading(veh, spawnPoint.w)
            SetVehicleEngineOn(veh, true, true, false)
            TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
            TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
            
            QBCore.Functions.Notify('Vehicle claimed! Use /savevehicle to store it in your garage', 'success')
            
            TriggerServerEvent('vehicle-auction:markClaimed', data.claimId)
            
            RegisterCommand('savevehicle', function()
                SaveClaimedVehicle(data.claimId, veh)
            end, false)
            
            SetTimeout(60000, function()
                if IsPedInVehicle(PlayerPedId(), veh, false) then
                    SaveClaimedVehicle(data.claimId, veh)
                end
            end)
        end, spawnPoint, true)
    end, data.claimId)
end)

function SaveClaimedVehicle(claimId, veh)
    if not DoesEntityExist(veh) then
        QBCore.Functions.Notify('Vehicle not found', 'error')
        return
    end
    
    local plate = QBCore.Functions.GetPlate(veh)
    local props = QBCore.Functions.GetVehicleProperties(veh)
    local hash = props.model
    local vehname = getVehicleFromVehList(hash)
    
    if vehname then
        TriggerServerEvent('vehicle-auction:server:SaveCar', props, vehname, hash, plate, claimId)
        QBCore.Functions.Notify('Vehicle saved to your garage!', 'success')
    else
        QBCore.Functions.Notify('Could not identify vehicle model. Please contact an admin.', 'error')
    end
end

RegisterNetEvent('vehicle-auction:client:SaveCar')
AddEventHandler('vehicle-auction:client:SaveCar', function(claimId)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped)
    
    if veh ~= nil and veh ~= 0 then
        SaveClaimedVehicle(claimId, veh)
    else
        QBCore.Functions.Notify('You need to be in a vehicle', 'error')
    end
end)

