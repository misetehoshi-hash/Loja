Config = {}

Config.taxRate = 0.10 -- 10% de imposto
Config.defaultImagePath = "nui://ox_inventory/web/images/"

-- Preços tabelados (fixos por item)
Config.defaultPrices = {
    -- Itens da mecânica
    ["repairkit"]          = 7000,
    ["advancedrepairkit"]  = 8000,
    ["tools"]            = 8000,
    ["screwdriverset"]     = 8000,
    ["syphoningkit"]       = 15000,
    ["lockpick"]           = 10000,
    ["jerrycan"]           = 7000,
    ["advancedlockpick"]   = 15000,
    
    -- Itens do 24/7
    ["tosti"]              = 6,
    ["sandwich"]           = 10,
    ["water_bottle"]       = 750,
    ["coffee"]             = 250,
    ["hersheysbar"]        = 750,
    ["peanutmandms"]       = 250,
    ["mandms"]             = 250,
    ["snikkel_candy"]      = 250,
    ["twerks_candy"]       = 250,
    ["lighter"]            = 750,
    ["rolling_paper"]      = 250,
    ["cleaningkit"]        = 250,
    -- Adicione outros itens conforme necessário
}

-- Restrições de itens por grupo (job) – baseado na tabela player_groups
Config.jobItemRestrictions = {
    mechanic = { 
        "repairkit", 
        "advancedrepairkit", 
        "tools", 
        "screwdriverset", 
        "syphoningkit", 
        "lockpick",
        "advancedlockpick",
        "jerrycan" 
    },
    police = { "weapon_pistol", "ammo-9" },
    -- Se um grupo não estiver listado, todos os itens são permitidos (para admins, etc.)
}

Config.shop = {
    [1] = {
        name = "24/7 Supermarket",
        location = vector4(29.17, -1345.6, 29.5, 88.68),
        npcModel = "mp_m_shopkeep_01",
        managers = {                                -- Quem pode gerenciar esta loja (grupo e nível mínimo)
            { job = "mechanic", minGrade = 0 },      -- mecânicos qualquer nível
            { job = "police",   minGrade = 2 },      -- policiais nível 2+
            { job = "admin" },                         -- admin (qualquer nível)
        },
        bankAccount = "supermarket_247",            -- identificador da conta bancária da loja
        blip = { id = 59, color = 25, scale = 0.7 },
        categories = {
            {
                name = "Comidas",
                icon = "fas fa-utensils",
                items = {
                    {name = "tosti", label = "Tosti", maxBuy = 10},
                    {name = "sandwich", label = "Sanduíche", maxBuy = 10}
                }
            },
            {
                name = "Bebidas",
                icon = "fas fa-wine-glass",
                items = {
                    {name = "water_bottle", label = "Água", maxBuy = 5},
                    {name = "coffee", label = "Café", maxBuy = 5}
                }
            },
            {
                name = "Doces",
                icon = "fas fa-cookie",
                items = {
                    {name = "hersheysbar", label = "ChocoKing", maxBuy = 10},
                    {name = "peanutmandms", label = "PeanutPop", maxBuy = 10},
                    {name = "mandms", label = "ChocoMelt", maxBuy = 10},
                    {name = "snikkel_candy", label = "Snikkel", maxBuy = 10},
                    {name = "twerks_candy", label = "Twerks", maxBuy = 10}
                }
            },
            {
                name = "Utéis",
                icon = "fas fa-mortar-pestle",
                items = {
                    {name = "lighter", label = "Lanterna", maxBuy = 2},
                    {name = "rolling_paper", label = "Seda", maxBuy = 5},
                    {name = "cleaningkit", label = "Kit de limpeza", maxBuy = 3}
                }
            }
        }
    },
    [2] = {
        name = "24/7 Supermarket",
        location = vector4(1964.17, 3744.03, 32.34, 300.83),
        npcModel = "mp_m_shopkeep_01",
        managers = {
            { job = "mechanic", minGrade = 0 },
            { job = "police",   minGrade = 2 },
            { job = "admin" },
        },
        bankAccount = "supermarket_247_2",
        blip = { id = 59, color = 25, scale = 0.7 },
        categories = {
            {
                name = "Comidas",
                icon = "fas fa-utensils", 
                items = {
                    {name = "tosti", label = "Tosti", maxBuy = 10},
                    {name = "sandwich", label = "Sanduíche", maxBuy = 10}
                }
            },
            {
                name = "Bebidas", 
                icon = "fas fa-wine-glass", 
                items = {
                    {name = "water_bottle", label = "Água", maxBuy = 5},
                    {name = "coffee", label = "Café", maxBuy = 5}
                }
            },
            {
                name = "Doces", 
                icon = "fas fa-cookie", 
                items = {
                    {name = "hersheysbar", label = "ChocoKing", maxBuy = 10},
                    {name = "peanutmandms", label = "PeanutPop", maxBuy = 10},
                    {name = "mandms", label = "ChocoMelt", maxBuy = 10},
                    {name = "snikkel_candy", label = "Snikkel", maxBuy = 10},
                    {name = "twerks_candy", label = "Twerks", maxBuy = 10}
                }
            },
            {
                name = "Utéis", 
                icon = "fas fa-mortar-pestle", 
                items = {
                    {name = "lighter", label = "Lanterna", maxBuy = 2},
                    {name = "rolling_paper", label = "Seda", maxBuy = 5},
                    {name = "cleaningkit", label = "Kit de limpeza", maxBuy = 3}
                }
            }
        }
    },
    [3] = {
        name = "Mecanica",
        location = vector4(-346.4524, -139.5054, 39.0096, 176.9706),
        bankAccount = "mechanic",  -- Agora usando o nome correto da conta
        npcModel = "mp_m_shopkeep_01",
        managers = {
            { job = "mechanic", minGrade = 2 },
            { job = "admin" },
        },
        blip = { id = 59, color = 25, scale = 0.7 },
        categories = {
            {
                name = "Reparos",
                icon = "fas fa-utensils", 
                items = {
                    {name = "repairkit", label = "Kit de Reparo", maxBuy = 5},
                    {name = "advancedrepairkit", label = "Kit de Reparo Avançado", maxBuy = 5}
                }
            },
            {
                name = "Ferramentas", 
                icon = "fas fa-wine-glass", 
                items = {
                    {name = "screwdriverset", label = "Kit de Ferramentas", maxBuy = 3},
                    {name = "tools", label = "Ferramentas", maxBuy = 3}
                }
            },
            {
                name = "Outros", 
                icon = "fas fa-cookie", 
                items = {
                    {name = "syphoningkit", label = "Kit de Sifonagem", maxBuy = 2},
                    {name = "jerrycan", label = "Lata armazena gasolina", maxBuy = 2}
                }
            }
        }
    },
}

Config.items = {} -- para imagens personalizadas, se necessário