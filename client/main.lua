local QBCore = exports['qb-core']:GetCoreObject()
local isShopOpen = false
local isManagementOpen = false
local shopKeepers = {}
local currentShopId = nil

local function CreateShopkeeper(coords, model)
    RequestModel(GetHashKey(model))
    local attempts = 0
    while not HasModelLoaded(GetHashKey(model)) and attempts < 50 do
        Wait(50)
        attempts = attempts + 1
    end
    if not HasModelLoaded(GetHashKey(model)) then
        print("^1[ERROR] Failed to load model: " .. model)
        return nil
    end
    local groundZ = coords.z
    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, 0)
    if not foundGround then groundZ = coords.z end
    local npc = CreatePed(4, GetHashKey(model), coords.x, coords.y, groundZ, coords.w, false, true)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    return npc
end

local function OpenShop(shopData, shopId)
    if isShopOpen or isManagementOpen then return end
    isShopOpen = true
    currentShopId = shopId

    local itemsConfig = {}
    for k, v in pairs(Config.items or {}) do
        itemsConfig[k] = v.image or (Config.defaultImagePath .. k .. ".png")
    end

    SetNuiFocus(true, true)
    SetCursorLocation(0.5, 0.5)

    SendNUIMessage({
        action = "openShop",
        shop = shopData,
        shopId = shopId,
        taxRate = Config.taxRate,
        itemsConfig = itemsConfig,
        defaultImagePath = Config.defaultImagePath
    })
end

local function CloseShop()
    if not isShopOpen then return end
    SendNUIMessage({ action = "closeShop" })
end

local function OpenManagement(shopData, shopId)
    if isShopOpen or isManagementOpen then return end
    isManagementOpen = true
    currentShopId = shopId

    SetNuiFocus(true, true)
    SetCursorLocation(0.5, 0.5)

    QBCore.Functions.TriggerCallback('iv-shops:server:canManageShop', function(canManage)
        if canManage then
            SendNUIMessage({
                action = "openManagement",
                shop = shopData,
                shopId = shopId
            })
        else
            QBCore.Functions.Notify("Você não tem permissão para gerenciar esta loja.", "error")
            CloseManagement()
        end
    end, shopId)
end

local function CloseManagement()
    if not isManagementOpen then return end
    SendNUIMessage({ action = "closeManagement" })
end

CreateThread(function()
    if not Config or not Config.shop then
        print("^1[ERROR] Config not loaded properly")
        return
    end

    local targetSystem = nil
    if exports['qb-target'] then
        targetSystem = 'qb'
    elseif exports.ox_target then
        targetSystem = 'ox'
    end

    for k, shop in pairs(Config.shop) do
        local blip = AddBlipForCoord(shop.location.x, shop.location.y, shop.location.z)
        SetBlipSprite(blip, shop.blip.id)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, shop.blip.scale)
        SetBlipColour(blip, shop.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(shop.name)
        EndTextCommandSetBlipName(blip)

        local npc = CreateShopkeeper(shop.location, shop.npcModel or "mp_m_shopkeep_01")
        if npc then
            shopKeepers[k] = npc

            local options = {
                {
                    type = "client",
                    event = "iv-shops:client:OpenShop",
                    icon = "fas fa-shopping-basket",
                    label = "Comprar",
                    shop = shop,
                    shopId = k
                },
                {
                    type = "client",
                    event = "iv-shops:client:OpenManagement",
                    icon = "fas fa-tools",
                    label = "Gerenciar Loja",
                    shop = shop,
                    shopId = k
                }
            }

            if targetSystem == 'qb' then
                exports['qb-target']:AddTargetEntity(npc, { options = options, distance = 2.0 })
            elseif targetSystem == 'ox' then
                exports.ox_target:addLocalEntity(npc, {
                    {
                        name = "shopkeeper_buy_" .. k,
                        icon = "fas fa-shopping-basket",
                        label = "Comprar",
                        onSelect = function()
                            TriggerEvent("iv-shops:client:OpenShop", { shop = shop, shopId = k })
                        end,
                        distance = 2.0
                    },
                    {
                        name = "shopkeeper_manage_" .. k,
                        icon = "fas fa-tools",
                        label = "Gerenciar Loja",
                        onSelect = function()
                            TriggerEvent("iv-shops:client:OpenManagement", { shop = shop, shopId = k })
                        end,
                        distance = 2.0
                    }
                })
            end
        end
    end
end)

RegisterNetEvent('iv-shops:client:OpenShop')
AddEventHandler('iv-shops:client:OpenShop', function(data)
    OpenShop(data.shop, data.shopId)
end)

RegisterNetEvent('iv-shops:client:OpenManagement')
AddEventHandler('iv-shops:client:OpenManagement', function(data)
    OpenManagement(data.shop, data.shopId)
end)

CreateThread(function()
    while true do
        Wait((isShopOpen or isManagementOpen) and 0 or 500)
        if (isShopOpen or isManagementOpen) and IsControlJustReleased(0, 177) then
            if isShopOpen then CloseShop() end
            if isManagementOpen then CloseManagement() end
        end
    end
end)

-- NUI Callbacks
RegisterNUICallback('closeShopFinished', function(_, cb)
    if isShopOpen then
        isShopOpen = false
        currentShopId = nil
        SetNuiFocus(false, false)
    end
    cb('ok')
end)

RegisterNUICallback('closeManagementFinished', function(_, cb)
    if isManagementOpen then
        isManagementOpen = false
        currentShopId = nil
        SetNuiFocus(false, false)
    end
    cb('ok')
end)

RegisterNUICallback('purchaseItems', function(data, cb)
    if not currentShopId then cb({ success = false, message = "Loja não identificada." }) return end
    QBCore.Functions.TriggerCallback('iv-shops:server:purchaseItems', function(success, message)
        cb({ success = success, message = message })
    end, data.items, currentShopId)
end)

RegisterNUICallback('purchaseBulk', function(data, cb)
    if not currentShopId then cb({ success = false, message = "Loja não identificada." }) return end
    QBCore.Functions.TriggerCallback('iv-shops:server:purchaseBulk', function(success, message)
        cb({ success = success, message = message })
    end, data)
end)

RegisterNUICallback('getReservations', function(_, cb)
    QBCore.Functions.TriggerCallback('iv-shops:server:getReservations', function(res)
        cb(res)
    end)
end)

RegisterNUICallback('withdrawReservation', function(data, cb)
    QBCore.Functions.TriggerCallback('iv-shops:server:withdrawReservation', function(success, message)
        cb({ success = success, message = message })
    end, data)
end)

RegisterNUICallback('getShopStock', function(data, cb)
    if not currentShopId then cb({}) return end
    QBCore.Functions.TriggerCallback('iv-shops:server:getShopStock', function(stock)
        cb(stock)
    end, currentShopId)
end)

RegisterNUICallback('getBulkOffers', function(data, cb)
    if not currentShopId then cb({}) return end
    QBCore.Functions.TriggerCallback('iv-shops:server:getBulkOffers', function(offers)
        cb(offers)
    end, { shopId = currentShopId, all = data.all })
end)

RegisterNUICallback('getPlayerInventory', function(_, cb)
    QBCore.Functions.TriggerCallback('iv-shops:server:getPlayerInventory', function(inv)
        cb(inv)
    end)
end)

RegisterNUICallback('getAllItems', function(_, cb)
    QBCore.Functions.TriggerCallback('iv-shops:server:getAllItems', function(items)
        cb(items)
    end)
end)

RegisterNUICallback('addItemToShop', function(data, cb)
    if not currentShopId then cb({ success = false, message = "Loja não identificada." }) return end
    QBCore.Functions.TriggerCallback('iv-shops:server:addItemToShop', function(success, message)
        cb({ success = success, message = message })
    end, currentShopId, data.itemName, data.quantity)
end)

RegisterNUICallback('removeItemFromShop', function(data, cb)
    if not currentShopId then cb({ success = false, message = "Loja não identificada." }) return end
    QBCore.Functions.TriggerCallback('iv-shops:server:removeItemFromShop', function(success, message)
        cb({ success = success, message = message })
    end, currentShopId, data.itemName, data.quantity)
end)

RegisterNUICallback('createBulkOffer', function(data, cb)
    if not currentShopId then cb({ success = false, message = "Loja não identificada." }) return end
    data.shopId = currentShopId
    QBCore.Functions.TriggerCallback('iv-shops:server:createBulkOffer', function(success, message)
        cb({ success = success, message = message })
    end, data)
end)

RegisterNUICallback('deleteBulkOffer', function(data, cb)
    QBCore.Functions.TriggerCallback('iv-shops:server:deleteBulkOffer', function(success, message)
        cb({ success = success, message = message })
    end, data.offerId)
end)

-- Callbacks para logs
RegisterNUICallback('getPurchaseLogs', function(_, cb)
    if not currentShopId then cb({}) return end
    QBCore.Functions.TriggerCallback('iv-shops:server:getPurchaseLogs', function(logs)
        cb(logs)
    end, currentShopId)
end)

RegisterNUICallback('getManagementLogs', function(_, cb)
    if not currentShopId then cb({}) return end
    QBCore.Functions.TriggerCallback('iv-shops:server:getManagementLogs', function(logs)
        cb(logs)
    end, currentShopId)
end)

RegisterNUICallback('getTopCustomers', function(_, cb)
    if not currentShopId then cb({}) return end
    QBCore.Functions.TriggerCallback('iv-shops:server:getTopCustomers', function(customers)
        cb(customers)
    end, currentShopId)
end)

RegisterNetEvent('iv-shops:client:forceClose')
AddEventHandler('iv-shops:client:forceClose', function()
    if isShopOpen then
        isShopOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "closeShop" })
    end
    if isManagementOpen then
        isManagementOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "closeManagement" })
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isShopOpen or isManagementOpen then SetNuiFocus(false, false) end
        for _, ped in pairs(shopKeepers) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
    end
end)