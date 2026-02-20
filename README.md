🛒 Modern Shop System - FiveM (QBCore)

Sistema completo de lojas com estoque dinâmico, ofertas a granel, reservas e gerenciamento avançado para servidores FiveM baseados no QBCore. Desenvolvido para oferecer uma experiência moderna e intuitiva tanto para jogadores quanto para administradores.
✨ Funcionalidades
🛍️ Para Jogadores

    Compra Normal: Adicione itens ao carrinho, respeitando limites de quantidade e estoque.

    Compra a Granel: Ofertas especiais com desconto (10% a 30%) e quantidade mínima. Os itens são reservados e podem ser retirados aos poucos.

    Minhas Reservas: Visualize todas as suas compras a granel e retire itens conforme sua necessidade e espaço no inventário.

    Carrinho de Compras: Interface moderna com cálculo automático de subtotal, imposto e total.

    Busca e Filtros: Encontre itens por nome ou ordenação por preço.

🛠️ Para Gerentes e Donos

    Gerenciamento de Estoque: Adicione itens do seu inventário à loja (com restrição por grupo) e remova itens devolvendo ao inventário.

    Criação de Ofertas a Granel: Defina item, quantidade total, quantidade mínima por compra e desconto. A oferta só fica visível para clientes quando o estoque normal atingir a quantidade total.

    Painel de Logs:

        Compras: Histórico de todas as transações realizadas.

        Gestão de Estoque: Registro de adições e remoções de itens por gerentes.

        Melhores Clientes: Ranking dos 10 clientes que mais gastaram na loja.

    Depósito Bancário: Todo valor pago pelos clientes é automaticamente depositado na conta bancária da loja (tabela bank_accounts_new).

🔒 Sistema de Permissões

    Baseado na tabela player_groups do servidor.

    Controle por grupo (job) e nível (grade) para acesso ao gerenciamento.

    Restrição de itens por grupo: apenas itens autorizados podem ser adicionados ao estoque.

💾 Banco de Dados

    shop_stock: Estoque normal da loja.

    shop_bulk_offers: Ofertas a granel criadas por gerentes.

    shop_reservations: Reservas de itens comprados a granel.

    shop_logs: Registro de todas as compras.

    shop_management_logs: Logs de ações de gerentes (add/remove stock).

🎨 Interface Moderna

    Design responsivo com tema escuro e acentos em verde/ciano.

    Abas para alternar entre modos de compra e painéis de gerenciamento.

    Notificações elegantes para feedback de ações.

    Tabelas com rolagem e cabeçalho fixo para visualização de logs.

📋 Requisitos

    Servidor FiveM com artefato recomendado.

    QBCore framework (versão atualizada).

    oxmysql para conexão com banco de dados.

    qb-target ou ox_target (opcional, mas recomendado para interação com NPCs).

    ox_inventory (opcional, suporte nativo; fallback para qb-inventory).

🔧 Instalação

    Baixe o repositório e cole a pasta mri_QIVShops em seu diretório resources.

    Importe o arquivo sql.sql para seu banco de dados (cria as tabelas necessárias).

    Configure o config.lua conforme suas lojas, itens, grupos e contas bancárias.

    Adicione ensure mri_QIVShops ao seu server.cfg.

    Reinicie o servidor ou inicie o recurso manualmente.

⚙️ Configuração
config.lua

    Config.taxRate: Percentual de imposto sobre compras (ex: 0.10 = 10%).

    Config.defaultPrices: Preços tabelados para todos os itens vendáveis.

    Config.jobItemRestrictions: Restrições de itens por grupo (job). Exemplo:
    lua

    mechanic = { "repairkit", "advancedrepairkit", "toolbox" }

    Config.shop: Definição das lojas. Cada loja deve conter:

        name, location,

