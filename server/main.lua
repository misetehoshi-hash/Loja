local QBCore = exports['qb-core']:GetCoreObject()

-- ===================== FUNÇÕES AUXILIARES =====================

-- Obtém grupo e grade do jogador a partir da tabela player_groups (apenas jobs)
local function GetPlayerGroupInfo(citizenid)
    local result = exports.oxmysql:executeSync('SELECT `group`, `grade` FROM player_groups WHERE citizenid = ? AND `type` = "job"', { citizenid })
    if result and #result > 0 then
        return result[1].group, result[1].grade
    end
    return nil, nil
end

-- Verifica se o jogador pode gerenciar a loja (pelo grupo e nível mínimo)
local function IsPlayerAllowedToManage(playerId, shopId)
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return false end
    local citizenid = Player.PlayerData.citizenid
    local group, grade = GetPlayerGroupInfo(citizenid)
    if not group then return false end

    local shop = Config.shop[tonumber(shopId)]
    if not shop or not shop.managers then return false end

    for _, manager in ipairs(shop.managers) do
        if manager.job == group then
            if not manager.minGrade or grade >= manager.minGrade then
                return true
            end
        end
    end
    return false
end

-- Verifica se o item é permitido para o grupo (baseado nas restrições)
-- Parâmetro extra 'grade' pode ser usado para permissões especiais (ex: dono)
local function IsItemAllowedForJob(group, itemName, grade)
    -- Se for admin ou grade muito alta (ex: dono), permite todos os itens
    if group == "admin" or (grade and grade >= 4) then
        return true
    end
    local restricted = Config.jobItemRestrictions and Config.jobItemRestrictions[group]
    if not restricted then return true end
    for _, allowedItem in ipairs(restricted) do
        if allowedItem == itemName then return true end
    end
    return false
end

-- Deposita o valor na conta da loja (tabela bank_accounts_new, campo amount, chave 'id')
local function DepositToShopAccount(shopId, amount)
    local shop = Config.shop[tonumber(shopId)]
    if not shop or not shop.bankAccount then 
        print("^1[ERROR] DepositToShopAccount: shop or bankAccount not found for shopId " .. tostring(shopId))
        return false 
    end
    local success = pcall(function()
        exports.oxmysql:update('UPDATE bank_accounts_new SET amount = amount + ? WHERE id = ?', { amount, shop.bankAccount })
    end)
    if success then
        print("^2[DEBUG] DepositToShopAccount: " .. amount .. " deposited to account " .. shop.bankAccount)
    else
        print("^1[ERROR] DepositToShopAccount: failed to update account " .. shop.bankAccount)
    end
    return success
end

-- Registra log de ação de gestão (add/remove stock)
local function LogManagementAction(shopId, action, itemName, quantity, price, citizenid)
    exports.oxmysql:insert('INSERT INTO shop_management_logs (shop_id, action, item_name, quantity, price, performed_by) VALUES (?, ?, ?, ?, ?, ?)',
        { shopId, action, itemName, quantity, price, citizenid })
end

-- ===================== CALLBACKS =====================

-- Verificar permissão de gerenciamento
QBCore.Functions.CreateCallback('iv-shops:server:canManageShop', function(source, cb, shopId)
    cb(IsPlayerAllowedToManage(source, shopId))
end)

-- Obter inventário do jogador (para select de adição)
QBCore.Functions.CreateCallback('iv-shops:server:getPlayerInventory', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    local items = {}
    if exports['ox_inventory'] then
        local oxInventory = exports.ox_inventory:GetInventoryItems(source)
        for _, item in pairs(oxInventory) do
            table.insert(items, { name = item.name, label = item.label, amount = item.amount })
        end
    else
        for slot, item in pairs(Player.PlayerData.items) do
            if item and item.amount > 0 then
                local itemInfo = QBCore.Shared.Items[item.name]
                table.insert(items, { name = item.name, label = itemInfo and itemInfo.label or item.name, amount = item.amount })
            end
        end
    end
    cb(items)
end)

-- Obter estoque normal da loja
QBCore.Functions.CreateCallback('iv-shops:server:getShopStock', function(source, cb, shopId)
    local stock = exports.oxmysql:executeSync('SELECT item_name, quantity, price FROM shop_stock WHERE shop_id = ?', { shopId })
    for _, row in ipairs(stock) do
        row.price = tonumber(row.price) or 0
        row.label = QBCore.Shared.Items[row.item_name] and QBCore.Shared.Items[row.item_name].label or row.item_name
        row.image = Config.items[row.item_name] and Config.items[row.item_name].image or Config.defaultImagePath .. row.item_name .. ".png"
    end
    cb(stock)
end)

-- Adicionar item ao estoque normal (gerente)
QBCore.Functions.CreateCallback('iv-shops:server:addItemToShop', function(source, cb, shopId, itemName, quantity)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false, "Jogador não encontrado.") return end

    if not IsPlayerAllowedToManage(src, shopId) then
        cb(false, "Sem permissão para gerenciar esta loja.")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local group, grade = GetPlayerGroupInfo(citizenid)
    if not IsItemAllowedForJob(group, itemName, grade) then
        cb(false, "Seu cargo não pode adicionar este item.")
        return
    end

    local hasItem = Player.Functions.GetItemByName(itemName)
    if not hasItem or hasItem.amount < quantity then
        cb(false, "Você não tem esse item em quantidade suficiente.")
        return
    end

    local price = Config.defaultPrices[itemName]
    if not price then
        cb(false, "Item sem preço definido na configuração.")
        return
    end

    local removed = Player.Functions.RemoveItem(itemName, quantity)
    if not removed then
        cb(false, "Erro ao remover o item do seu inventário.")
        return
    end

    local success = pcall(function()
        exports.oxmysql:insert('INSERT INTO shop_stock (shop_id, item_name, quantity, price, added_by) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity), price = VALUES(price)',
            { shopId, itemName, quantity, price, citizenid })
    end)

    if not success then
        Player.Functions.AddItem(itemName, quantity)
        cb(false, "Erro ao salvar no banco de dados. Item devolvido.")
        return
    end

    -- Registrar log de gestão
    LogManagementAction(shopId, 'add_stock', itemName, quantity, price, citizenid)

    TriggerClientEvent('QBCore:Notify', src, 'Item adicionado à loja!', 'success')
    cb(true, "Item adicionado com sucesso!")
end)

-- Remover item do estoque normal (gerente) – devolve ao inventário
QBCore.Functions.CreateCallback('iv-shops:server:removeItemFromShop', function(source, cb, shopId, itemName, quantity)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false, "Jogador não encontrado.") return end

    if not IsPlayerAllowedToManage(src, shopId) then
        cb(false, "Sem permissão para gerenciar esta loja.")
        return
    end

    -- Buscar preço atual no estoque para o log
    local stockInfo = exports.oxmysql:executeSync('SELECT price FROM shop_stock WHERE shop_id = ? AND item_name = ?', { shopId, itemName })
    if #stockInfo == 0 then
        cb(false, "Item não encontrado no estoque.")
        return
    end
    local price = stockInfo[1].price

    local stock = exports.oxmysql:executeSync('SELECT quantity FROM shop_stock WHERE shop_id = ? AND item_name = ?', { shopId, itemName })
    if #stock == 0 or stock[1].quantity < quantity then
        cb(false, "Quantidade indisponível no estoque.")
        return
    end

    local added = Player.Functions.AddItem(itemName, quantity)
    if not added then
        cb(false, "Não foi possível adicionar o item ao seu inventário (cheio?).")
        return
    end

    local newQty = stock[1].quantity - quantity
    if newQty <= 0 then
        exports.oxmysql:update('DELETE FROM shop_stock WHERE shop_id = ? AND item_name = ?', { shopId, itemName })
    else
        exports.oxmysql:update('UPDATE shop_stock SET quantity = ? WHERE shop_id = ? AND item_name = ?', { newQty, shopId, itemName })
    end

    -- Registrar log de gestão
    local citizenid = Player.PlayerData.citizenid
    LogManagementAction(shopId, 'remove_stock', itemName, quantity, price, citizenid)

    TriggerClientEvent('QBCore:Notify', src, 'Item removido da loja e devolvido ao seu inventário.', 'success')
    cb(true, "Item removido com sucesso!")
end)

-- ===================== OFERTAS A GRANEL =====================

-- Criar nova oferta
QBCore.Functions.CreateCallback('iv-shops:server:createBulkOffer', function(source, cb, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false, "Jogador não encontrado.") return end

    if not IsPlayerAllowedToManage(src, data.shopId) then
        cb(false, "Sem permissão para gerenciar esta loja.")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local group, grade = GetPlayerGroupInfo(citizenid)
    if not IsItemAllowedForJob(group, data.itemName, grade) then
        cb(false, "Seu cargo não pode criar oferta para este item.")
        return
    end

    -- Verifica se o item tem preço tabelado
    if not Config.defaultPrices[data.itemName] then
        cb(false, "Item sem preço definido.")
        return
    end

    local success = pcall(function()
        exports.oxmysql:insert('INSERT INTO shop_bulk_offers (shop_id, item_name, total_quantity, min_quantity, discount, created_by) VALUES (?, ?, ?, ?, ?, ?)',
            { data.shopId, data.itemName, data.totalQuantity, data.minQuantity, data.discount, citizenid })
    end)

    if success then
        TriggerClientEvent('QBCore:Notify', src, 'Oferta criada com sucesso!', 'success')
        cb(true, "Oferta criada.")
    else
        cb(false, "Erro ao criar oferta.")
    end
end)

-- Listar ofertas (para gerente: todas; para cliente: apenas completas)
QBCore.Functions.CreateCallback('iv-shops:server:getBulkOffers', function(source, cb, data)
    local shopId = data.shopId
    local all = data.all or false

    local query = [[
        SELECT o.*, COALESCE(SUM(s.quantity), 0) as available
        FROM shop_bulk_offers o
        LEFT JOIN shop_stock s ON s.shop_id = o.shop_id AND s.item_name = o.item_name
        WHERE o.shop_id = ?
        GROUP BY o.id
    ]]
    if not all then
        query = query .. " HAVING available >= o.total_quantity"
    end

    local offers = exports.oxmysql:executeSync(query, { shopId })

    for _, offer in ipairs(offers) do
        offer.label = QBCore.Shared.Items[offer.item_name] and QBCore.Shared.Items[offer.item_name].label or offer.item_name
        offer.price = Config.defaultPrices[offer.item_name] or 0
        offer.image = Config.defaultImagePath .. offer.item_name .. ".png"
        offer.available = tonumber(offer.available) or 0
    end

    cb(offers)
end)

-- Excluir oferta (gerente)
QBCore.Functions.CreateCallback('iv-shops:server:deleteBulkOffer', function(source, cb, offerId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false, "Jogador não encontrado.") return end

    local offer = exports.oxmysql:executeSync('SELECT shop_id FROM shop_bulk_offers WHERE id = ?', { offerId })
    if #offer == 0 then cb(false, "Oferta não encontrada.") return end

    if not IsPlayerAllowedToManage(src, offer[1].shop_id) then
        cb(false, "Sem permissão.")
        return
    end

    exports.oxmysql:update('DELETE FROM shop_bulk_offers WHERE id = ?', { offerId })
    cb(true, "Oferta excluída.")
end)

-- ===================== COMPRAS =====================

-- Compra normal (entrega imediata)
QBCore.Functions.CreateCallback('iv-shops:server:purchaseItems', function(source, cb, items, shopId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false, "Jogador não encontrado.") return end
    if not items or #items == 0 then cb(false, "Carrinho vazio.") return end

    local shop = Config.shop[tonumber(shopId)]
    if not shop then cb(false, "Loja inválida.") return end

    -- Distância
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local shopCoords = vector3(shop.location.x, shop.location.y, shop.location.z)
    if #(playerCoords - shopCoords) > 5.0 then cb(false, "Você está muito longe da loja.") return end

    -- Estoque
    local stock = exports.oxmysql:executeSync('SELECT item_name, quantity, price FROM shop_stock WHERE shop_id = ?', { shopId })
    local stockDict = {}
    for _, row in ipairs(stock) do stockDict[row.item_name] = { quantity = row.quantity, price = row.price } end

    local subtotal = 0
    local itemsToUpdate = {}
    local itemsToAdd = {}
    for _, clientItem in ipairs(items) do
        local itemName = clientItem.name
        local quantity = tonumber(clientItem.quantity)
        if not quantity or quantity <= 0 then cb(false, "Quantidade inválida.") return end

        local valid = stockDict[itemName]
        if not valid then cb(false, "Item " .. itemName .. " não disponível.") return end
        if valid.quantity < quantity then cb(false, "Estoque insuficiente para " .. itemName) return end

        subtotal = subtotal + (valid.price * quantity)
        table.insert(itemsToUpdate, { name = itemName, qty = quantity })
        table.insert(itemsToAdd, { name = itemName, amount = quantity })
    end

    local tax = subtotal * Config.taxRate
    local total = subtotal - tax

    -- Processar pagamento
    local removed = Player.Functions.RemoveMoney('cash', total)
    local paymentMethod = 'cash'
    if not removed then
        removed = Player.Functions.RemoveMoney('bank', total)
        paymentMethod = 'bank'
    end
    if not removed then
        cb(false, "Saldo insuficiente (necessário: $" .. string.format("%.2f", total) .. ")")
        return
    end

    -- Depositar na conta da loja
    DepositToShopAccount(shopId, total)

    -- Adicionar itens ao jogador
    local addedItems = {}
    local success = true
    for _, item in ipairs(itemsToAdd) do
        if Player.Functions.AddItem(item.name, item.amount) then
            table.insert(addedItems, { name = item.name, amount = item.amount })
        else
            success = false
            break
        end
    end

    if not success then
        -- Rollback: devolver dinheiro
        if paymentMethod == 'cash' then Player.Functions.AddMoney('cash', total) else Player.Functions.AddMoney('bank', total) end
        for _, added in ipairs(addedItems) do
            Player.Functions.RemoveItem(added.name, added.amount)
        end
        cb(false, "Erro ao adicionar item. Transação cancelada.")
        return
    end

    -- Dar baixa no estoque
    for _, item in ipairs(itemsToUpdate) do
        exports.oxmysql:update('UPDATE shop_stock SET quantity = quantity - ? WHERE shop_id = ? AND item_name = ?', { item.qty, shopId, item.name })
    end

    -- Registrar log de compra
    local itemsJson = json.encode(addedItems)
    exports.oxmysql:insert('INSERT INTO shop_logs (identifier, shop_id, shop_name, items, subtotal, tax, total, payment_method) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { Player.PlayerData.citizenid, shopId, shop.name, itemsJson, subtotal, tax, total, paymentMethod })

    TriggerClientEvent('QBCore:Notify', src, 'Compra realizada com sucesso!', 'success')
    cb(true, "Compra finalizada com sucesso!")
end)

-- Compra a granel (reserva)
QBCore.Functions.CreateCallback('iv-shops:server:purchaseBulk', function(source, cb, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false, "Jogador não encontrado.") return end

    local shop = Config.shop[tonumber(data.shopId)]
    if not shop then cb(false, "Loja inválida.") return end

    -- Buscar oferta
    local offer = exports.oxmysql:executeSync('SELECT * FROM shop_bulk_offers WHERE id = ?', { data.offerId })
    if #offer == 0 then cb(false, "Oferta não encontrada.") return end
    offer = offer[1]

    -- Verificar quantidade mínima
    if data.quantity < offer.min_quantity then
        cb(false, "Quantidade mínima é " .. offer.min_quantity)
        return
    end

    -- Verificar disponibilidade (estoque total)
    local stock = exports.oxmysql:executeSync('SELECT SUM(quantity) as total FROM shop_stock WHERE shop_id = ? AND item_name = ?', { data.shopId, offer.item_name })
    local available = tonumber(stock[1].total) or 0
    if available < data.quantity then
        cb(false, "Estoque insuficiente para a quantidade solicitada.")
        return
    end

    -- Calcular preço com desconto
    local basePrice = Config.defaultPrices[offer.item_name]
    if not basePrice then cb(false, "Item sem preço definido.") return end
    local unitPrice = basePrice * (1 - offer.discount / 100)
    local subtotal = unitPrice * data.quantity
    local tax = subtotal * Config.taxRate
    local total = subtotal - tax

    -- Pagamento
    local removed = Player.Functions.RemoveMoney('cash', total)
    local paymentMethod = 'cash'
    if not removed then
        removed = Player.Functions.RemoveMoney('bank', total)
        paymentMethod = 'bank'
    end
    if not removed then
        cb(false, "Saldo insuficiente (necessário: $" .. string.format("%.2f", total) .. ")")
        return
    end

    -- Depositar na conta da loja
    DepositToShopAccount(data.shopId, total)

    -- Criar reserva
    exports.oxmysql:insert('INSERT INTO shop_reservations (identifier, shop_id, item_name, quantity, price_paid) VALUES (?, ?, ?, ?, ?)',
        { Player.PlayerData.citizenid, data.shopId, offer.item_name, data.quantity, unitPrice })

    -- Dar baixa no estoque (remover do estoque normal)
    local stockItems = exports.oxmysql:executeSync('SELECT id, quantity FROM shop_stock WHERE shop_id = ? AND item_name = ? ORDER BY added_at ASC', { data.shopId, offer.item_name })
    local remaining = data.quantity
    for _, row in ipairs(stockItems) do
        if remaining <= 0 then break end
        local take = math.min(remaining, row.quantity)
        if take == row.quantity then
            exports.oxmysql:update('DELETE FROM shop_stock WHERE id = ?', { row.id })
        else
            exports.oxmysql:update('UPDATE shop_stock SET quantity = quantity - ? WHERE id = ?', { take, row.id })
        end
        remaining = remaining - take
    end

    -- Registrar log de compra (opcional, como itens reservados)
    local itemsForLog = { { name = offer.item_name, amount = data.quantity } }
    local itemsJson = json.encode(itemsForLog)
    exports.oxmysql:insert('INSERT INTO shop_logs (identifier, shop_id, shop_name, items, subtotal, tax, total, payment_method) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { Player.PlayerData.citizenid, data.shopId, shop.name, itemsJson, subtotal, tax, total, paymentMethod })

    TriggerClientEvent('QBCore:Notify', src, 'Compra a granel realizada! Os itens foram reservados.', 'success')
    cb(true, "Compra a granel finalizada!")
end)

-- Listar reservas do jogador
QBCore.Functions.CreateCallback('iv-shops:server:getReservations', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end
    local res = exports.oxmysql:executeSync('SELECT * FROM shop_reservations WHERE identifier = ?', { Player.PlayerData.citizenid })
    for _, r in ipairs(res) do
        r.label = QBCore.Shared.Items[r.item_name] and QBCore.Shared.Items[r.item_name].label or r.item_name
        r.price_paid = tonumber(r.price_paid)
    end
    cb(res)
end)

-- Retirar item da reserva
QBCore.Functions.CreateCallback('iv-shops:server:withdrawReservation', function(source, cb, data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        cb(false, "Jogador não encontrado.")
        return
    end

    local res = exports.oxmysql:executeSync('SELECT * FROM shop_reservations WHERE id = ? AND identifier = ?', 
        { data.reservationId, Player.PlayerData.citizenid })
    if #res == 0 then 
        cb(false, "Reserva não encontrada.")
        return
    end
    res = res[1]

    if data.quantity > res.quantity then
        cb(false, "Quantidade solicitada maior que a reservada.")
        return
    end

    -- Verificar espaço no inventário
    local canAdd = false
    if exports['ox_inventory'] then
        canAdd = exports.ox_inventory:CanCarryItem(src, res.item_name, data.quantity)
    else
        -- Para qb-inventory, tentamos adicionar e tratamos erro depois
        canAdd = true
    end

    if not canAdd then
        cb(false, "Inventário cheio.")
        return
    end

    local added = Player.Functions.AddItem(res.item_name, data.quantity)
    if not added then
        cb(false, "Não foi possível adicionar o item (inventário cheio?).")
        return
    end

    local newQty = res.quantity - data.quantity
    if newQty <= 0 then
        exports.oxmysql:update('DELETE FROM shop_reservations WHERE id = ?', { data.reservationId })
    else
        exports.oxmysql:update('UPDATE shop_reservations SET quantity = ? WHERE id = ?', { newQty, data.reservationId })
    end

    cb(true, "Item retirado com sucesso!")
end)

-- ===================== LOGS E RELATÓRIOS =====================

-- Buscar logs de compras
QBCore.Functions.CreateCallback('iv-shops:server:getPurchaseLogs', function(source, cb, shopId)
    local logs = exports.oxmysql:executeSync([[
        SELECT l.*, p.group as customer_group
        FROM shop_logs l
        LEFT JOIN player_groups p ON l.identifier = p.citizenid AND p.type = 'job'
        WHERE l.shop_id = ?
        ORDER BY l.timestamp DESC
        LIMIT 100
    ]], { shopId })
    cb(logs)
end)

-- Buscar logs de gestão
QBCore.Functions.CreateCallback('iv-shops:server:getManagementLogs', function(source, cb, shopId)
    local logs = exports.oxmysql:executeSync([[
        SELECT m.*, p.group as manager_group
        FROM shop_management_logs m
        LEFT JOIN player_groups p ON m.performed_by = p.citizenid AND p.type = 'job'
        WHERE m.shop_id = ?
        ORDER BY m.timestamp DESC
        LIMIT 100
    ]], { shopId })
    cb(logs)
end)

-- Buscar melhores clientes
QBCore.Functions.CreateCallback('iv-shops:server:getTopCustomers', function(source, cb, shopId)
    local top = exports.oxmysql:executeSync([[
        SELECT 
            l.identifier,
            p.group as customer_group,
            COUNT(*) as purchase_count,
            SUM(l.total) as total_spent
        FROM shop_logs l
        LEFT JOIN player_groups p ON l.identifier = p.citizenid AND p.type = 'job'
        WHERE l.shop_id = ?
        GROUP BY l.identifier
        ORDER BY total_spent DESC
        LIMIT 10
    ]], { shopId })
    cb(top)
end)

-- Listar todos os itens (para select de criação de oferta), filtrando por grupo
QBCore.Functions.CreateCallback('iv-shops:server:getAllItems', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        cb({})
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local group, grade = GetPlayerGroupInfo(citizenid)
    if not group then
        cb({})
        return
    end

    local allowedItems = Config.jobItemRestrictions[group] -- pode ser nil (todos permitidos)

    local items = {}
    for name, data in pairs(QBCore.Shared.Items) do
        if not allowedItems then
            table.insert(items, { name = name, label = data.label })
        else
            for _, allowed in ipairs(allowedItems) do
                if allowed == name then
                    table.insert(items, { name = name, label = data.label })
                    break
                end
            end
        end
    end

    table.sort(items, function(a, b) return a.label < b.label end)
    cb(items)
end)