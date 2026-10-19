local _, AF = ...
local L = AF.Locales.ptBR


L.CHANGELOG_ENTRY_2_1_5 = [[### Alterado
- ArtisanFinder agora oferece suporte ao Retail e ao WoW Forever no mesmo download, com recursos adaptados a cada versão.]]

L.CHANGELOG_ENTRY_2_1_4 = [[### Alterado

* A versão da interface foi atualizada para o patch 12.1.5 de World of Warcraft.]]
L.CHANGELOG_ENTRY_2_1_3 = [[### Alterado

* O processamento repetido ao verificar varreduras de profissões desatualizadas e exibir profissões analisadas foi reduzido, melhorando a resposta com perfis de artesãos grandes.

### Corrigido

* Foram corrigidos erros nas barras de ação após selecionar controles do ArtisanFinder no modo de edição.
* As entradas de varredura salvas com formato incorreto agora são ignoradas com segurança ao criar listas de profissões e resumos de varreduras desatualizadas.]]
L.CHANGELOG_ENTRY_2_1_2 = [[### Corrigido

* Conjurações potencializadas de Evocador, como Sopro de Fogo, não são mais interrompidas pelo ArtisanFinder.
* A consulta e atualização da lista de pedidos de criação do cliente agora só rodam quando a interface de pedidos do cliente está aberta, esperam enquanto você está conjurando/canalizando ou restrito, e os eventos de atualização de pedidos do cliente não colocam mais isso na fila.]]
L.CHANGELOG_ENTRY_2_1_1 = [[### Adicionado

* As prévias de reagentes do painel de profissão agora podem usar a opção "Reagentes ilimitados" para simular alocações de qualidade sem possuir todos os reagentes.
* Os controles do painel de profissão agora podem abrir por padrão maximizados ou minimizados nas opções do addon.

### Corrigido

* As varreduras de dados de habilidade dos reagentes agora toleram dados base incompletos em vez de falhar.
* O processamento da fila de varredura de profissão agora sai com segurança se os dados de progresso da varredura estiverem ausentes ou malformados.
* A análise de profissões por links de comércio agora ignora com segurança tokens numéricos malformados.]]
L.CHANGELOG_ENTRY_2_1_0 = [[### Adicionado

* A importação/exportação de artesãos oferece uma forma de divulgar artesãos de outra conta além da sua conta principal.
* Preparar pedido agora tem um modo Avançado que permite aos clientes escolher qualidades de reagentes obrigatórios e reagentes opcionais antes de rastrear uma criação.
* O ArtisanFinder agora pode estimar a qualidade esperada de criação pela configuração de reagentes selecionada e sugerir combinações de reagentes que alcancem o melhor resultado conhecido sem sempre usar por padrão materiais da qualidade mais alta.

### Alterado

* As varreduras de profissão agora salvam os dados de perícia de reagentes necessários para uma simulação confiável do lado do cliente de qualidade, recomendações e preparação avançada. Registros de varredura antigos que não oferecem suporte ao novo modelo são limpos ou marcados como desatualizados para que os jogadores saibam quais personagens precisam de uma nova varredura.
* Clicar em uma linha de cliente correspondente agora pode aplicar os materiais de criação rastreados do Objective Tracker ao formulário de pedido de criação.

### Corrigido

* Abrir uma profissão não deve mais causar uma queda significativa de FPS.
* Membros da guilda que podem criar um item agora mostram seu status online real em vez de sempre aparecerem offline.
* Os recursos do canal de comércio agora funcionam em clientes de jogo russos.
* As varreduras completas de profissão agora distribuem o trabalho de forma mais uniforme, com menos travamentos e engasgos em profissões grandes.]]
L.CHANGELOG_ENTRY_2_0_5 = [[### Adicionado

* As linhas de cliente agora incluem ações de Preparar pedido para criações padrão e criações com reagentes opcionais.
* Criações preparadas são rastreadas no Objective Tracker com componentes obrigatórios, reagentes opcionais selecionados, quantidades necessárias, contagens possuídas e faltantes, e marcadores de qualidade.
* Pesquisas na Casa de Leilões a partir de criações preparadas agora usam pesquisas múltiplas temporárias do Auctionator quando o Auctionator está ativado.

### Alterado

* Os botões "Pedido pessoal" e "Pedido de guilda" foram removidos para que um simples clique em uma linha de artesão preencha automaticamente o formulário à esquerda.]]
L.CHANGELOG_ENTRY_2_0_3 = [[### Corrigido

* Tentativa de sussurro em PNJs de Pedido de Patrono ou personagens alternativos ao concluir um pedido de criação.]]
L.CHANGELOG_ENTRY_2_0_2 = [[### Adicionado

* Notificações para clientes quando um pedido de criação for concluído.]]
L.CHANGELOG_ENTRY_2_0_1 = [[### Adicionado

* Localização para chinês simplificado, espanhol da América Latina, português e português do Brasil.

### Alterado

* Pequenas otimizações de comunicação.
* A comunicação de mensagens do addon agora é compactada.

### Corrigido

* Pequeno vazamento de memória em sessões longas.]]

L.OPTIONS_ORDER_SOUND = "Som de notificação de pedidos"
L.OPTIONS_ORDER_SOUND_DESC = "Escolha o som tocado nas notificações de pedidos."
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED = "Ativar som de notificação de pedidos"
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED_DESC = "Toca um som para pedidos pessoais e pedidos de cliente concluídos."
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED = "Ativar aviso de notificação de pedidos"
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED_DESC = "Mostra um aviso no centro da tela para pedidos pessoais e pedidos de cliente concluídos."
L.OPTIONS_ORDER_SOUND_STORE_OPEN = "Janela da loja"
L.OPTIONS_ORDER_SOUND_EVENT_SCHEDULER_CHIME = "Sino do calendário"
L.OPTIONS_ORDER_SOUND_CHANNEL_DESC = "Escolha qual canal de som do jogo toca as notificações de pedidos."
L.OPTIONS_PLAY_ORDER_SOUND_DESC = "Toca o som selecionado para notificações de pedidos."
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS_DESC = "Limpa notificações de pedidos pessoais guardadas."
L.OPTIONS_SECTION_NOTIFICATIONS = "Notificações"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS = "Ocultar seus pedidos para personagens alternativos"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS_DESC = "Oculta notificações de pedidos pessoais para seus personagens alternativos quando enviadas por um dos seus personagens."
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS = "Ocultar seus pedidos concluídos para personagens alternativos"
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS_DESC = "Oculta notificações de pedidos de cliente concluídos quando enviadas por um dos seus personagens."
L.OPTIONS_ORDER_SOUND_CATALOG_SHOP_OPEN = "Painel da loja aberto"
L.OPTIONS_ORDER_SOUND_STORE_DELIVERY = "Aviso de entrega da loja"
L.OPTIONS_ORDER_SOUND_BNET_TOAST = "Aviso Battle.net"
L.OPTIONS_ORDER_SOUND_PROFESSION_TOAST = "Aviso de profissão"
L.OPTIONS_ORDER_SOUND_GARRISON_WORK_ORDER = "Início de ordem de trabalho"
L.OPTIONS_ORDER_SOUND_BACKPACK_COIN = "Seleção de moeda"
L.OPTIONS_ORDER_SOUND_SOULBIND = "Ativação de vínculo de alma"
L.OPTIONS_ORDER_SOUND_GM_CHAT_WARNING = "Aviso de conversa MJ"
L.OPTIONS_ORDER_SOUND_READY_CHECK = "Verificação de prontidão"
L.OPTIONS_ORDER_SOUND_AUCTION = "Casa de leilões"
L.OPTIONS_ORDER_SOUND_CHANNEL = "Canal de som"
L.OPTIONS_SOUND_CHANNEL_DEFAULT = "Mestre"
L.OPTIONS_SOUND_CHANNEL_SFX = "Efeitos sonoros"
L.OPTIONS_SOUND_CHANNEL_MUSIC = "Música"
L.OPTIONS_SOUND_CHANNEL_AMBIENCE = "Ambiente"
L.OPTIONS_SOUND_CHANNEL_DIALOG = "Diálogo"
L.OPTIONS_PLAY_ORDER_SOUND = "Tocar Som"
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS = "Limpar Notificações"

L.TUTORIAL_RESET_DONE = "tutorial redefinido."
L.TUTORIAL_INTRO = "O ArtisanFinder funciona em dois lugares. Abra cada uma das suas profissões uma vez para escanear os dados de criação. Depois visite o PNJ de ordens de criação para ver artesãos disponíveis ao criar uma ordem."
L.TUTORIAL_MINIMAP_BUTTON = "Use o botão do minimapa para gerenciar rapidamente o ArtisanFinder.\nClique esquerdo alterna disponibilidade, clique do meio alterna disponibilidade automática, clique direito abre opções e Shift-clique oculta o botão."
L.TUTORIAL_CUSTOMER_STATUS = "Selecione um item de ordem no formulário de ordens de criação. O ArtisanFinder então procura artesãos compatíveis."
L.TUTORIAL_CUSTOMER_SEARCH = "Filtre, ordene ou atualize os resultados para a criação selecionada."
L.TUTORIAL_CUSTOMER_ROW = "As linhas mostram comissão, qualidade, disponibilidade, origem de guilda ou chat de comércio e a observação do artesão."
L.TUTORIAL_CUSTOMER_ACTION = "Clique em uma linha real para preencher automaticamente o formulário de pedido do cliente.\n\nAbra o menu da linha para marcar um artesão como favorito, sussurrar para ele ou abrir a profissão dele quando disponível."
L.TUTORIAL_PROFESSION_NAME = "Tutorial"

L.TUTORIAL_CRAFTER_PREVIEW = "Passe o cursor sobre o ícone de Pré-visualização de cliente para ver o que os clientes verão para a criação selecionada, incluindo valores específicos do item combinados com os padrões da profissão."
L.CUSTOMER_SIDE_PREVIEW = "Pré-visualização de cliente"
L.CUSTOMER_SIDE_PREVIEW_EMPTY = "Ainda não há dados visíveis ao cliente guardados para esta linha."
L.CUSTOMER_SIDE_PREVIEW_SCANNING = "Esta criação está sendo escaneada. A pré-visualização de cliente será atualizada quando o escaneamento terminar."

L.CHANGELOG_ENTRY_2_2_0 = [[### Corrigido
- As notificações de pedidos pessoais agora incluem identificadores de receita e profissão para exibir os nomes de itens e profissões no idioma de quem recebe.
- Mensagens antigas grandes demais mantêm seus identificadores e descartam os nomes alternativos, ou são interrompidas com segurança se ainda excederem o limite da mensagem.
- As atualizações de dados de itens atualizam apenas os painéis e as fabricações rastreadas afetados, reduzindo o processamento desnecessário.]]
