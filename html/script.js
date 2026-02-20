const resourceName = window.resourceName || (window.GetParentResourceName ? GetParentResourceName() : 'mri_qivshops');
const baseUrl = `https://${resourceName}`;

let shopData = null;
let cart = [];
let itemsConfig = {};
let defaultImagePath = "nui://ox_inventory/web/images/";
let taxRate = 0.10;
let shopId = null;
let currentMode = 'normal'; // 'normal', 'bulk', 'reservations'
let currentBulkOffer = null;

$(document).ready(() => {
    window.addEventListener("message", (event) => {
        const data = event.data;
        if (data.action === "openShop") {
            shopData = data.shop;
            shopId = data.shopId;
            itemsConfig = data.itemsConfig || {};
            defaultImagePath = data.defaultImagePath || "nui://ox_inventory/web/images/";
            taxRate = data.taxRate || 0.10;
            openShop();
        } else if (data.action === "closeShop") {
            closeShop();
        } else if (data.action === "openManagement") {
            shopData = data.shop;
            shopId = data.shopId;
            openManagement();
        } else if (data.action === "closeManagement") {
            closeManagement();
        }
    });

    $("#close-button").click(closeShop);
    $("#close-management-button").click(closeManagement);
    $("#clear-cart").click(clearCart);
    $("#checkout-button").click(checkout);
    $(".search-box input").on("input", function () { filterItems($(this).val()); });
    $("#sort-select").change(function () { sortItems($(this).val()); });

    // Abas de modo de compra
    $("#mode-normal").click(() => switchMode('normal'));
    $("#mode-bulk").click(() => switchMode('bulk'));
    $("#mode-reservations").click(() => switchMode('reservations'));

    // Abas de gerenciamento
    $("#manage-stock-tab").click(() => switchManagementTab('stock'));
    $("#manage-offers-tab").click(() => switchManagementTab('offers'));
    $("#manage-logs-tab").click(() => switchManagementTab('logs'));

    // Abas internas dos logs
    $("#logs-purchases-tab").click(() => switchLogsTab('purchases'));
    $("#logs-management-tab").click(() => switchLogsTab('management'));
    $("#logs-top-tab").click(() => switchLogsTab('top'));

    // Gerenciamento - ações
    $("#add-to-shop-btn").click(addItemToShop);
    $("#create-offer-btn").click(createOffer);
    $(document).on('click', '.remove-stock-btn', function() {
        const itemName = $(this).data('item');
        const maxQty = $(this).data('max');
        removeItemFromShop(itemName, maxQty);
    });
    $(document).on('click', '.delete-offer-btn', function() {
        const offerId = $(this).data('id');
        deleteOffer(offerId);
    });
    $(document).on('click', '.withdraw-reservation-btn', function() {
        const reservationId = $(this).data('id');
        const maxQty = $(this).data('max');
        let qty = prompt(`Quantidade a retirar (máx: ${maxQty}):`, "1");
        if (!qty) return;
        qty = parseInt(qty);
        if (isNaN(qty) || qty <= 0 || qty > maxQty) {
            showNotification("error", "Quantidade inválida.");
            return;
        }
        $.post(baseUrl + "/withdrawReservation", JSON.stringify({ reservationId, quantity: qty }))
            .done(response => {
                if (response.success) {
                    showNotification("success", response.message);
                    if (currentMode === 'reservations') loadReservations();
                } else {
                    showNotification("error", response.message);
                }
            });
    });
});

// ===================== MODO DE COMPRA =====================
function switchMode(mode) {
    currentMode = mode;
    $(".mode-tab").removeClass("active");
    $(`#mode-${mode}`).addClass("active");

    $(".items-grid").empty();
    clearCart();

    if (mode === 'reservations') {
        loadReservations();
        $("#bulk-info").hide();
        $("#checkout-button").text('Finalizar Compra').prop('disabled', true);
    } else if (mode === 'bulk') {
        loadBulkOffers();
        $("#bulk-info").show();
        $("#checkout-button").text('Comprar Lote').prop('disabled', true);
    } else {
        loadShopStock();
        $("#bulk-info").hide();
        $("#checkout-button").text('Finalizar Compra').prop('disabled', true);
    }
}

// ===================== FUNÇÕES DA LOJA (COMPRAS) =====================
function openShop() {
    $("#shop-name").text(shopData.name);
    populateCategories();
    switchMode('normal');
    $("body").fadeIn(300);
    $("#shop-container").show();
    $("#management-panel").hide();
}

function closeShop() {
    $("body").fadeOut(300, () => {
        cart = [];
        updateCart();
        $.post(baseUrl + "/closeShopFinished", JSON.stringify({}));
    });
}

function loadShopStock() {
    $.post(baseUrl + "/getShopStock", JSON.stringify({ shopId }))
        .done(stock => displayStockItems(stock));
}

function loadBulkOffers() {
    $.post(baseUrl + "/getBulkOffers", JSON.stringify({ shopId, all: false }))
        .done(offers => displayBulkOffers(offers));
}

function loadReservations() {
    $.post(baseUrl + "/getReservations", JSON.stringify({}))
        .done(reservations => displayReservations(reservations));
}

function displayStockItems(stock) {
    const itemsGrid = $(".items-grid");
    itemsGrid.empty();
    if (!stock || stock.length === 0) {
        itemsGrid.html('<p class="no-items">Nenhum item disponível.</p>');
        return;
    }
    stock.forEach(item => {
        const price = Number(item.price) || 0;
        const itemCard = $("<div>").addClass("item-card").html(`
            <img src="${item.image || defaultImagePath + item.item_name + '.png'}" alt="${item.label}" onerror="this.src='img/default-item.png'">
            <h3>${item.label}</h3>
            <span class="price">$${price.toFixed(2)}</span>
            <span class="stock-qty">Estoque: ${item.quantity}</span>
            <button class="add-to-cart-btn" data-name="${item.item_name}" data-label="${item.label}" data-price="${price}" data-max="${item.quantity}">
                <i class="fas fa-cart-plus"></i> Add carrinho
            </button>
        `);
        itemCard.find(".add-to-cart-btn").click(() => addToCart({
            name: item.item_name,
            label: item.label,
            price: price,
            maxBuy: item.quantity
        }));
        itemsGrid.append(itemCard);
    });
}

function displayBulkOffers(offers) {
    const itemsGrid = $(".items-grid");
    itemsGrid.empty();
    if (!offers || offers.length === 0) {
        itemsGrid.html('<p class="no-items">Nenhuma oferta a granel disponível no momento.</p>');
        return;
    }
    offers.forEach(offer => {
        const price = Number(offer.price) || 0;
        const discountedPrice = price * (1 - offer.discount / 100);
        const itemCard = $("<div>").addClass("item-card offer-card").html(`
            <img src="${offer.image || defaultImagePath + offer.item_name + '.png'}" alt="${offer.label}" onerror="this.src='img/default-item.png'">
            <h3>${offer.label}</h3>
            <span class="price"><s>$${price.toFixed(2)}</s> $${discountedPrice.toFixed(2)}</span>
            <span class="discount-badge">-${offer.discount}%</span>
            <span class="min-qty">Mínimo: ${offer.min_quantity} unidades</span>
            <span class="stock-qty">Disponível: ${offer.available}</span>
            <button class="select-offer-btn" data-offer-id="${offer.id}" data-name="${offer.item_name}" data-label="${offer.label}" data-price="${discountedPrice}" data-min="${offer.min_quantity}" data-max="${offer.available}" data-discount="${offer.discount}">
                <i class="fas fa-cart-plus"></i> Selecionar oferta
            </button>
        `);
        itemCard.find(".select-offer-btn").click(() => selectBulkOffer({
            id: offer.id,
            name: offer.item_name,
            label: offer.label,
            price: discountedPrice,
            minBuy: offer.min_quantity,
            maxBuy: offer.available,
            discount: offer.discount,
            image: offer.image
        }));
        itemsGrid.append(itemCard);
    });
}

function displayReservations(reservations) {
    const itemsGrid = $(".items-grid");
    itemsGrid.empty();
    if (!reservations || reservations.length === 0) {
        itemsGrid.html('<p class="no-reservations">Você não possui reservas.</p>');
        return;
    }
    reservations.forEach(res => {
        const card = $("<div>").addClass("item-card reservation-card").html(`
            <h3>${res.label}</h3>
            <span class="price">Preço pago: $${Number(res.price_paid).toFixed(2)}</span>
            <span class="stock-qty">Quantidade reservada: ${res.quantity}</span>
            <button class="withdraw-reservation-btn" data-id="${res.id}" data-max="${res.quantity}">
                <i class="fas fa-arrow-down"></i> Retirar
            </button>
        `);
        itemsGrid.append(card);
    });
}

function selectBulkOffer(offer) {
    clearCart();
    currentBulkOffer = offer;
    cart.push({
        offerId: offer.id,
        name: offer.name,
        label: offer.label,
        price: offer.price,
        quantity: offer.minBuy,
        minBuy: offer.minBuy,
        maxBuy: offer.maxBuy,
        discount: offer.discount,
        image: offer.image
    });
    updateCart();
    showNotification("success", `Oferta de ${offer.label} selecionada.`);
}

function populateCategories() {
    const categoriesList = $(".categories-list");
    categoriesList.empty();
    shopData.categories.forEach((category, index) => {
        const categoryItem = $("<div>")
            .addClass("category-item")
            .html(`<i class="${category.icon}"></i>${category.name}`)
            .click(() => {
                $(".category-item").removeClass("active");
                categoryItem.addClass("active");
                $("#current-category").text(category.name);
                if (currentMode === 'normal') loadShopStock();
                else if (currentMode === 'bulk') loadBulkOffers();
            });
        if (index === 0) {
            categoryItem.addClass("active");
            $("#current-category").text(category.name);
        }
        categoriesList.append(categoryItem);
    });
}

function addToCart(item) {
    if (currentMode === 'bulk') return; // não usado diretamente

    const existing = cart.find(i => i.name === item.name);
    if (existing) {
        if (existing.quantity < item.maxBuy) {
            existing.quantity += 1;
        } else {
            showNotification("error", `Limite máximo de ${item.maxBuy} unidades atingido.`);
            return;
        }
    } else {
        cart.push({
            name: item.name,
            label: item.label,
            price: item.price,
            quantity: 1,
            maxBuy: item.maxBuy,
            image: defaultImagePath + item.name + ".png"
        });
    }
    updateCart();
    showNotification("success", `${item.label} adicionado ao carrinho`);
}

function updateCart() {
    const cartItems = $(".cart-items");
    cartItems.empty();
    if (cart.length === 0) {
        cartItems.html('<p class="empty-cart">Carrinho vazio</p>');
        updateCartSummary();
        return;
    }
    cart.forEach(item => {
        const cartItem = $("<div>").addClass("cart-item").html(`
            <img src="${item.image}" alt="${item.label}" onerror="this.src='img/default-item.png'">
            <div class="cart-item-details">
                <div class="cart-item-name">${item.label}</div>
                <div class="cart-item-price">$${item.price.toFixed(2)}</div>
            </div>
            <div class="cart-item-controls">
                <div class="quantity-control">
                    <button class="quantity-btn minus">-</button>
                    <span class="quantity">${item.quantity}</span>
                    <button class="quantity-btn plus">+</button>
                </div>
                <button class="cart-item-remove"><i class="fas fa-trash"></i></button>
            </div>
        `);
        cartItem.find(".minus").click(() => updateItemQuantity(item, -1));
        cartItem.find(".plus").click(() => updateItemQuantity(item, 1));
        cartItem.find(".cart-item-remove").click(() => removeFromCart(item));
        cartItems.append(cartItem);
    });
    updateCartSummary();
}

function updateItemQuantity(item, change) {
    if (currentMode === 'bulk') {
        const newQty = item.quantity + change;
        if (newQty < item.minBuy) {
            showNotification("error", `Quantidade mínima é ${item.minBuy}.`);
            return;
        }
        if (newQty > item.maxBuy) {
            showNotification("error", `Quantidade máxima disponível é ${item.maxBuy}.`);
            return;
        }
        item.quantity = newQty;
    } else {
        const newQty = item.quantity + change;
        if (newQty < 1) {
            removeFromCart(item);
            return;
        } else if (newQty <= item.maxBuy) {
            item.quantity = newQty;
        } else {
            showNotification("error", `Limite máximo de ${item.maxBuy} unidades.`);
            return;
        }
    }
    updateCart();
}

function removeFromCart(item) {
    if (currentMode === 'bulk') {
        cart = [];
        currentBulkOffer = null;
    } else {
        cart = cart.filter(i => i.name !== item.name);
    }
    updateCart();
    showNotification("error", `${item.label} removido do carrinho`);
}

function updateCartSummary() {
    if (cart.length === 0) {
        $("#subtotal").text("$0.00");
        $("#tax").text("$0.00");
        $("#total-amount").text("$0.00");
        $("#checkout-button").prop("disabled", true);
        $("#cart-count").text("0");
        return;
    }
    const subtotal = cart.reduce((total, item) => total + item.price * item.quantity, 0);
    const tax = subtotal * taxRate;
    const total = subtotal - tax;
    $("#cart-count").text(cart.reduce((acc, i) => acc + i.quantity, 0));
    $("#subtotal").text(`$${subtotal.toFixed(2)}`);
    $("#tax").text(`$${tax.toFixed(2)}`);
    $("#total-amount").text(`$${total.toFixed(2)}`);
    $("#checkout-button").prop("disabled", false);
    if (currentMode === 'bulk' && cart[0]) {
        $("#bulk-discount-value").text(cart[0].discount || 0);
    }
}

function clearCart() {
    cart = [];
    currentBulkOffer = null;
    updateCart();
}

function checkout() {
    if (cart.length === 0) {
        showNotification("error", "Carrinho vazio!");
        return;
    }

    if (currentMode === 'bulk') {
        const offer = cart[0];
        $.post(baseUrl + "/purchaseBulk", JSON.stringify({
            shopId,
            offerId: offer.offerId,
            quantity: offer.quantity
        })).done(response => {
            if (response.success) {
                showNotification("success", response.message);
                clearCart();
                loadBulkOffers();
            } else {
                showNotification("error", response.message);
            }
        });
    } else if (currentMode === 'normal') {
        const payload = cart.map(item => ({ name: item.name, quantity: item.quantity }));
        $.post(baseUrl + "/purchaseItems", JSON.stringify({ items: payload, shopId }))
            .done(response => {
                if (response.success) {
                    showNotification("success", response.message);
                    clearCart();
                    loadShopStock();
                } else {
                    showNotification("error", response.message);
                }
            });
    }
}

function filterItems(query) {
    if (currentMode === 'normal') loadShopStock();
    else if (currentMode === 'bulk') loadBulkOffers();
}
function sortItems(sortBy) {
    if (currentMode === 'normal') loadShopStock();
    else if (currentMode === 'bulk') loadBulkOffers();
}

// ===================== GERENCIAMENTO =====================
function openManagement() {
    $("#manage-shop-name").text("Gerenciar " + shopData.name);
    switchManagementTab('stock');
    $("body").fadeIn(300);
    $("#management-panel").show();
    $("#shop-container").hide();
}

function closeManagement() {
    $("body").fadeOut(300, () => {
        $.post(baseUrl + "/closeManagementFinished", JSON.stringify({}));
    });
}

function switchManagementTab(tab) {
    $(".management-tab").removeClass("active");
    $(`#manage-${tab}-tab`).addClass("active");
    $(".management-panel").removeClass("active");
    $(`#manage-${tab}-panel`).addClass("active");

    if (tab === 'stock') {
        loadStockManagement();
    } else if (tab === 'offers') {
        loadOffersManagement();
    } else if (tab === 'logs') {
        loadLogsData();
    }
}

function loadStockManagement() {
    $.post(baseUrl + "/getShopStock", JSON.stringify({ shopId }))
        .done(stock => {
            const tbody = $("#stock-table-body");
            tbody.empty();
            stock.forEach(item => {
                const price = Number(item.price) || 0;
                const row = $("<tr>").html(`
                    <td>${item.label}</td>
                    <td>${item.quantity}</td>
                    <td>$${price.toFixed(2)}</td>
                    <td>
                        <button class="remove-stock-btn" data-item="${item.item_name}" data-max="${item.quantity}">
                            <i class="fas fa-trash"></i> Remover
                        </button>
                    </td>
                `);
                tbody.append(row);
            });
        });

    $.post(baseUrl + "/getPlayerInventory", JSON.stringify({}))
        .done(inventory => {
            const select = $("#inv-item-select");
            select.empty().append('<option value="">Selecione um item</option>');
            if (inventory && inventory.length > 0) {
                inventory.forEach(item => {
                    select.append(`<option value="${item.name}" data-max="${item.amount}">${item.label} (${item.amount})</option>`);
                });
            } else {
                select.append('<option value="" disabled>Inventário vazio</option>');
            }
        });
}

function loadOffersManagement() {
    $.post(baseUrl + "/getBulkOffers", JSON.stringify({ shopId, all: true }))
        .done(offers => {
            const tbody = $("#offers-table-body");
            tbody.empty();
            offers.forEach(offer => {
                const status = offer.available >= offer.total_quantity ? 'Completa' : `Incompleta (${offer.available}/${offer.total_quantity})`;
                const row = $("<tr>").html(`
                    <td>${offer.label}</td>
                    <td>${offer.total_quantity}</td>
                    <td>${offer.min_quantity}</td>
                    <td>${offer.discount}%</td>
                    <td>${status}</td>
                    <td>
                        <button class="delete-offer-btn" data-id="${offer.id}">
                            <i class="fas fa-trash"></i> Excluir
                        </button>
                    </td>
                `);
                tbody.append(row);
            });
        });

    $.post(baseUrl + "/getAllItems", JSON.stringify({}))
        .done(items => {
            const select = $("#offer-item-select");
            select.empty().append('<option value="">Selecione um item</option>');
            items.forEach(item => {
                select.append(`<option value="${item.name}">${item.label}</option>`);
            });
        });
}

// ===================== FUNÇÕES DE LOGS =====================
function loadLogsData() {
    switchLogsTab('purchases');
}

function switchLogsTab(tab) {
    $(".logs-tab").removeClass("active");
    $(`#logs-${tab}-tab`).addClass("active");
    $(".logs-table-container").removeClass("active");
    $(`#logs-${tab}`).addClass("active");

    if (tab === 'purchases') {
        loadPurchaseLogs();
    } else if (tab === 'management') {
        loadManagementLogs();
    } else if (tab === 'top') {
        loadTopCustomers();
    }
}

function loadPurchaseLogs() {
    $.post(baseUrl + "/getPurchaseLogs", JSON.stringify({}))
        .done(logs => {
            const tbody = $("#purchases-table-body");
            tbody.empty();
            logs.forEach(log => {
                let itemsList = '';
                try {
                    const items = JSON.parse(log.items);
                    itemsList = items.map(i => `${i.amount}x ${i.label || i.name}`).join('<br>');
                } catch (e) {
                    itemsList = log.items;
                }
                const row = $("<tr>").html(`
                    <td>${new Date(log.timestamp).toLocaleString()}</td>
                    <td>${log.identifier}</td>
                    <td>${log.customer_group || '-'}</td>
                    <td>${itemsList}</td>
                    <td>$${parseFloat(log.subtotal).toFixed(2)}</td>
                    <td>$${parseFloat(log.tax).toFixed(2)}</td>
                    <td>$${parseFloat(log.total).toFixed(2)}</td>
                    <td>${log.payment_method}</td>
                `);
                tbody.append(row);
            });
        });
}

function loadManagementLogs() {
    $.post(baseUrl + "/getManagementLogs", JSON.stringify({}))
        .done(logs => {
            const tbody = $("#management-table-body");
            tbody.empty();
            logs.forEach(log => {
                const actionLabel = log.action === 'add_stock' ? 'Adicionou' : 'Removeu';
                const row = $("<tr>").html(`
                    <td>${new Date(log.timestamp).toLocaleString()}</td>
                    <td>${actionLabel}</td>
                    <td>${log.item_name}</td>
                    <td>${log.quantity}</td>
                    <td>$${parseFloat(log.price).toFixed(2)}</td>
                    <td>${log.performed_by}</td>
                    <td>${log.manager_group || '-'}</td>
                `);
                tbody.append(row);
            });
        });
}

function loadTopCustomers() {
    $.post(baseUrl + "/getTopCustomers", JSON.stringify({}))
        .done(customers => {
            const tbody = $("#top-table-body");
            tbody.empty();
            customers.forEach(c => {
                const row = $("<tr>").html(`
                    <td>${c.identifier}</td>
                    <td>${c.customer_group || '-'}</td>
                    <td>${c.purchase_count}</td>
                    <td>$${parseFloat(c.total_spent).toFixed(2)}</td>
                `);
                tbody.append(row);
            });
        });
}

function addItemToShop() {
    const itemName = $("#inv-item-select").val();
    const quantity = parseInt($("#add-quantity").val());
    if (!itemName || quantity <= 0) {
        showNotification("error", "Preencha todos os campos corretamente.");
        return;
    }
    $.post(baseUrl + "/addItemToShop", JSON.stringify({ shopId, itemName, quantity }))
        .done(response => {
            if (response.success) {
                showNotification("success", response.message);
                loadStockManagement();
            } else {
                showNotification("error", response.message);
            }
        });
}

function removeItemFromShop(itemName, maxQty) {
    let qty = prompt(`Quantidade a remover (máx: ${maxQty}):`, "1");
    if (!qty) return;
    qty = parseInt(qty);
    if (isNaN(qty) || qty <= 0 || qty > maxQty) {
        showNotification("error", "Quantidade inválida.");
        return;
    }
    $.post(baseUrl + "/removeItemFromShop", JSON.stringify({ shopId, itemName, quantity: qty }))
        .done(response => {
            if (response.success) {
                showNotification("success", response.message);
                loadStockManagement();
            } else {
                showNotification("error", response.message);
            }
        });
}

function createOffer() {
    const itemName = $("#offer-item-select").val();
    const totalQty = parseInt($("#offer-total-quantity").val());
    const minQty = parseInt($("#offer-min-quantity").val());
    const discount = parseInt($("#offer-discount").val());

    if (!itemName || totalQty <= 0 || minQty <= 0 || minQty > totalQty) {
        showNotification("error", "Preencha todos os campos corretamente.");
        return;
    }

    $.post(baseUrl + "/createBulkOffer", JSON.stringify({
        shopId,
        itemName,
        totalQuantity: totalQty,
        minQuantity: minQty,
        discount
    })).done(response => {
        if (response.success) {
            showNotification("success", response.message);
            loadOffersManagement();
        } else {
            showNotification("error", response.message);
        }
    });
}

function deleteOffer(offerId) {
    if (!confirm("Tem certeza que deseja excluir esta oferta?")) return;
    $.post(baseUrl + "/deleteBulkOffer", JSON.stringify({ offerId }))
        .done(response => {
            if (response.success) {
                showNotification("success", response.message);
                loadOffersManagement();
            } else {
                showNotification("error", response.message);
            }
        });
}

// ===================== NOTIFICAÇÕES =====================
function showNotification(type, message) {
    const notification = $(`<div class="notification ${type}"><i class="fas ${type === 'success' ? 'fa-check-circle' : 'fa-exclamation-circle'}"></i><span>${message}</span></div>`);
    $("#notification-container").append(notification);
    setTimeout(() => notification.remove(), 3000);
}