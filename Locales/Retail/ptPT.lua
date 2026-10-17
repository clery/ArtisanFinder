local _, AF = ...
local L = AF.Locales.ptPT


L.CHANGELOG_ENTRY_2_1_5 = [[### Alterado
- ArtisanFinder suporta agora Retail e WoW Forever na mesma transferência, com funcionalidades adaptadas a cada versão.]]

L.CHANGELOG_ENTRY_2_1_4 = [[### Alterado

* A versão da interface foi atualizada para o patch 12.1.5 de World of Warcraft.]]
L.CHANGELOG_ENTRY_2_1_3 = [[### Alterado

* Foi reduzido o processamento repetido ao verificar análises de profissões desatualizadas e apresentar profissões analisadas, melhorando a resposta com perfis de artesãos grandes.

### Corrigido

* Foram corrigidos erros nas barras de ação após selecionar controlos do ArtisanFinder no modo de edição.
* As entradas de análise guardadas com formato incorreto são agora ignoradas em segurança ao criar listas de profissões e resumos de análises desatualizadas.]]
L.CHANGELOG_ENTRY_2_1_2 = [[### Corrigido

* Lançamentos potencializados de Evocador, como Sopro de Fogo, já não são interrompidos pelo ArtisanFinder.
* A consulta e atualização da lista de encomendas de criação do cliente agora só são executadas quando a interface de encomendas do cliente está aberta, aguardam enquanto estás a lançar/canalizar ou estás restrito, e os eventos de atualização de encomendas do cliente já não as colocam em fila.]]
L.CHANGELOG_ENTRY_2_1_1 = [[### Adicionado

* As pré-visualizações de reagentes no painel de profissão podem agora usar a opção "Reagentes ilimitados" para simular distribuições de qualidade sem possuir todos os reagentes.
* Os controlos do painel de profissão podem agora abrir por defeito maximizados ou minimizados nas opções do addon.

### Corrigido

* As análises dos dados de perícia dos reagentes agora toleram dados base incompletos em vez de falharem.
* O processamento da fila de análise de profissão agora termina em segurança se os dados de progresso da análise estiverem em falta ou mal formados.
* A análise de profissões a partir de ligações de comércio agora ignora em segurança tokens numéricos mal formados.]]
L.CHANGELOG_ENTRY_2_1_0 = [[### Adicionado

* A importação/exportação de artesãos oferece uma forma de anunciar artesãos de outra conta, bem como da tua conta principal.
* Preparar encomenda tem agora um modo Avançado que permite aos clientes escolher qualidades de reagentes necessários e reagentes opcionais antes de acompanhar uma criação.
* O ArtisanFinder pode agora estimar a qualidade de fabrico esperada a partir da configuração de reagentes selecionada e sugerir combinações de reagentes que atinjam o melhor resultado conhecido sem usar sempre por defeito materiais da qualidade mais alta.

### Alterado

* As análises de profissão guardam agora os dados de perícia de reagentes necessários para simulação de qualidade, recomendações e preparação avançada fiáveis do lado do cliente. Registos de análise antigos que não suportam o novo modelo são limpos ou marcados como desatualizados, para que os jogadores saibam que personagens precisam de nova análise.
* Clicar numa linha de cliente correspondente pode agora aplicar os materiais de criação acompanhados a partir do Objective Tracker no formulário de encomenda de fabrico.

### Corrigido

* Abrir uma profissão já não deverá causar uma queda significativa de FPS.
* Os membros da guilda que podem criar um item mostram agora o seu estado online real em vez de aparecerem sempre offline.
* As funcionalidades do canal de comércio funcionam agora em clientes de jogo russos.
* As análises completas de profissão distribuem agora o trabalho de forma mais uniforme, com menos bloqueios e engasgos em profissões grandes.]]
L.CHANGELOG_ENTRY_2_0_5 = [[### Adicionado

* As linhas de cliente incluem agora ações de Preparar encomenda para criações padrão e criações com reagentes opcionais.
* Criações preparadas são acompanhadas no Objective Tracker com componentes necessários, reagentes opcionais selecionados, quantidades necessárias, contagens possuídas e em falta, e marcadores de qualidade.
* Pesquisas na Casa de Leilões a partir de criações preparadas usam agora pesquisas múltiplas temporárias do Auctionator quando o Auctionator está ativado.

### Alterado

* Os botões "Encomenda pessoal" e "Encomenda de guilda" foram removidos para que um simples clique numa linha de artesão preencha automaticamente o formulário à esquerda.]]
L.CHANGELOG_ENTRY_2_0_3 = [[### Corrigido

* Tentativa de sussurro em PNJs de Encomenda de Mecenas ou personagens alternativos ao concluir uma encomenda de criação.]]
L.CHANGELOG_ENTRY_2_0_2 = [[### Adicionado

* Notificações para clientes quando uma encomenda de criação for concluída.]]
L.CHANGELOG_ENTRY_2_0_1 = [[### Adicionado

* Localização para chinês simplificado, espanhol da América Latina, português e português do Brasil.

### Alterado

* Pequenas otimizações de comunicação.
* A comunicação de mensagens do addon está agora comprimida.

### Corrigido

* Pequena fuga de memória em sessões longas.]]

L.OPTIONS_SECTION_NOTIFICATIONS = "Notificações"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS = "Ocultar as tuas encomendas para personagens alternativas"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS_DESC = "Oculta notificações de encomendas pessoais para as tuas personagens alternativas quando enviadas por uma das tuas personagens."
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS = "Ocultar as tuas encomendas concluídas para personagens alternativas"
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS_DESC = "Oculta notificações de encomendas de cliente concluídas quando enviadas por uma das tuas personagens."
L.OPTIONS_ORDER_SOUND = "Som de notificação de encomendas"
L.OPTIONS_ORDER_SOUND_DESC = "Escolhe o som tocado nas notificações de encomendas."
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED = "Ativar som de notificação de encomendas"
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED_DESC = "Toca um som para encomendas pessoais e encomendas de cliente concluídas."
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED = "Ativar aviso de notificação de encomendas"
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED_DESC = "Mostra um aviso no centro do ecrã para encomendas pessoais e encomendas de cliente concluídas."
L.OPTIONS_ORDER_SOUND_CATALOG_SHOP_OPEN = "Painel da loja aberto"
L.OPTIONS_ORDER_SOUND_STORE_DELIVERY = "Aviso de entrega da loja"
L.OPTIONS_ORDER_SOUND_STORE_OPEN = "Janela da loja"
L.OPTIONS_ORDER_SOUND_BNET_TOAST = "Aviso Battle.net"
L.OPTIONS_ORDER_SOUND_PROFESSION_TOAST = "Aviso de profissão"
L.OPTIONS_ORDER_SOUND_EVENT_SCHEDULER_CHIME = "Sino do calendário"
L.OPTIONS_ORDER_SOUND_GARRISON_WORK_ORDER = "Início de ordem de trabalho"
L.OPTIONS_ORDER_SOUND_BACKPACK_COIN = "Seleção de moeda"
L.OPTIONS_ORDER_SOUND_SOULBIND = "Ativação de vínculo de alma"
L.OPTIONS_ORDER_SOUND_GM_CHAT_WARNING = "Aviso de conversa MJ"
L.OPTIONS_ORDER_SOUND_READY_CHECK = "Verificação de prontidão"
L.OPTIONS_ORDER_SOUND_AUCTION = "Casa de leilões"
L.OPTIONS_ORDER_SOUND_CHANNEL = "Canal de som"
L.OPTIONS_ORDER_SOUND_CHANNEL_DESC = "Escolhe que canal de som do jogo toca as notificações de encomendas."
L.OPTIONS_SOUND_CHANNEL_DEFAULT = "Mestre"
L.OPTIONS_SOUND_CHANNEL_SFX = "Efeitos sonoros"
L.OPTIONS_SOUND_CHANNEL_MUSIC = "Música"
L.OPTIONS_SOUND_CHANNEL_AMBIENCE = "Ambiente"
L.OPTIONS_SOUND_CHANNEL_DIALOG = "Diálogo"
L.OPTIONS_PLAY_ORDER_SOUND = "Tocar Som"
L.OPTIONS_PLAY_ORDER_SOUND_DESC = "Toca o som selecionado para notificações de encomendas."
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS = "Limpar Notificações"
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS_DESC = "Limpa notificações de encomendas pessoais guardadas."

L.TUTORIAL_RESET_DONE = "tutorial reposto."
L.TUTORIAL_INTRO = "O ArtisanFinder funciona em dois lugares. Abre cada uma das tuas profissões uma vez para analisar os dados de fabrico. Depois visita o PNJ de encomendas de fabrico para ver artesãos disponíveis ao criar uma encomenda."
L.TUTORIAL_MINIMAP_BUTTON = "Usa o botão do minimapa para gerir rapidamente o ArtisanFinder.\nClique esquerdo alterna disponibilidade, clique do meio alterna disponibilidade automática, clique direito abre opções e Shift-clique esconde o botão."
L.TUTORIAL_CUSTOMER_STATUS = "Seleciona um item de encomenda no formulário de encomendas de fabrico. O ArtisanFinder procura então artesãos compatíveis."
L.TUTORIAL_CUSTOMER_SEARCH = "Filtra, ordena ou atualiza os resultados para o fabrico selecionado."
L.TUTORIAL_CUSTOMER_ROW = "As linhas mostram comissão, qualidade, disponibilidade, origem de guilda ou chat de comércio e a nota do artesão."
L.TUTORIAL_CUSTOMER_ACTION = "Clica numa linha real para preencher automaticamente o formulário de encomenda de cliente.\n\nAbre o menu da linha para marcar um artesão como favorito, sussurrar-lhe ou abrir a profissão dele quando disponível."
L.TUTORIAL_PROFESSION_NAME = "Tutorial"

L.CUSTOMER_SIDE_PREVIEW = "Pré-visualização de cliente"
L.CUSTOMER_SIDE_PREVIEW_EMPTY = "Ainda não há dados visíveis ao cliente guardados para esta linha."
L.CUSTOMER_SIDE_PREVIEW_SCANNING = "Este fabrico está a ser analisado. A pré-visualização de cliente será atualizada quando a análise terminar."
L.TUTORIAL_CRAFTER_PREVIEW = "Passa o rato sobre o ícone de Pré-visualização de cliente para ver o que os clientes verão para o fabrico selecionado, incluindo valores específicos do item combinados com as predefinições da profissão."
