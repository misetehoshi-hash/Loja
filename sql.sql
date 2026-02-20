-- Tabela de logs de compra
CREATE TABLE IF NOT EXISTS `shop_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(60) NOT NULL,
    `shop_id` INT NOT NULL,
    `shop_name` VARCHAR(100),
    `items` LONGTEXT NOT NULL,
    `subtotal` DECIMAL(10,2) NOT NULL,
    `tax` DECIMAL(10,2) NOT NULL,
    `total` DECIMAL(10,2) NOT NULL,
    `payment_method` VARCHAR(10),
    `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de estoque normal
CREATE TABLE IF NOT EXISTS `shop_stock` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `shop_id` INT NOT NULL,
    `item_name` VARCHAR(50) NOT NULL,
    `quantity` INT NOT NULL DEFAULT 0,
    `price` DECIMAL(10,2) NOT NULL,
    `added_by` VARCHAR(60),
    `added_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_shop_item` (`shop_id`, `item_name`)
);

-- Tabela de reservas (compras a granel)
CREATE TABLE IF NOT EXISTS `shop_reservations` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(60) NOT NULL,
    `shop_id` INT NOT NULL,
    `item_name` VARCHAR(50) NOT NULL,
    `quantity` INT NOT NULL DEFAULT 0,
    `price_paid` DECIMAL(10,2) NOT NULL,
    `purchase_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `identifier` (`identifier`),
    INDEX `shop_id` (`shop_id`)
);

-- Tabela de ofertas a granel
DROP TABLE IF EXISTS `shop_bulk_offers`;
CREATE TABLE `shop_bulk_offers` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `shop_id` INT NOT NULL,
    `item_name` VARCHAR(50) NOT NULL,
    `total_quantity` INT NOT NULL,
    `min_quantity` INT NOT NULL,
    `discount` INT NOT NULL,
    `created_by` VARCHAR(60),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `shop_id` (`shop_id`)
);

-- Tabela para logs de ações de gerentes (adição/remoção de itens)
CREATE TABLE IF NOT EXISTS `shop_management_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `shop_id` INT NOT NULL,
    `action` VARCHAR(20) NOT NULL, -- 'add_stock' ou 'remove_stock'
    `item_name` VARCHAR(50) NOT NULL,
    `quantity` INT NOT NULL,
    `price` DECIMAL(10,2) NOT NULL, -- preço na época (tabelado)
    `performed_by` VARCHAR(60) NOT NULL, -- citizenid de quem fez a ação
    `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `shop_id` (`shop_id`),
    INDEX `performed_by` (`performed_by`)
);