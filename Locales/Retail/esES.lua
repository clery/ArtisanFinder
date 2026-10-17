local _, AF = ...
local L = AF.Locales.esES


L.CHANGELOG_ENTRY_2_1_4 = [[### Cambiado

* Se ha actualizado la versión de interfaz para el parche 12.1.5 de World of Warcraft.]]
L.CHANGELOG_ENTRY_2_1_3 = [[### Cambiado

* Se ha reducido el procesamiento repetido al comprobar escaneos de profesiones obsoletos y mostrar profesiones escaneadas, mejorando la respuesta con perfiles de artesanos grandes.

### Corregido

* Se han corregido los errores de las barras de acción tras seleccionar controles de ArtisanFinder en el modo de edición.
* Las entradas de escaneo guardadas con formato incorrecto ahora se omiten de forma segura al crear listas de profesiones y resúmenes de escaneos obsoletos.]]
L.CHANGELOG_ENTRY_2_1_2 = [[### Corregido

* Los lanzamientos potenciados de evocador, como Aliento de fuego, ya no son interrumpidos por ArtisanFinder.
* La consulta y actualización de lista de pedidos de fabricación de cliente ahora solo se ejecutan cuando la interfaz de pedidos de cliente está abierta, se aplazan mientras estás lanzando/canalizando o estás restringido, y los eventos de actualización de pedidos de cliente ya no las ponen en cola.]]
L.CHANGELOG_ENTRY_2_1_1 = [[### Añadido

* Las vistas previas de componentes del panel de profesión ahora pueden usar un interruptor "Componentes ilimitados" para simular asignaciones de calidad sin poseer todos los componentes.
* Los controles del panel de profesión ahora pueden abrirse por defecto maximizados o minimizados desde las opciones del addon.

### Corregido

* Los escaneos de datos de habilidad de componentes ahora toleran datos base incompletos en lugar de fallar.
* El procesamiento de la cola de escaneo de profesiones ahora sale de forma segura si faltan datos de progreso del escaneo o están mal formados.
* El análisis de profesiones desde enlaces de comercio ahora ignora de forma segura tokens numéricos mal formados.]]
L.CHANGELOG_ENTRY_2_1_0 = [[### Añadido

* La importación/exportación de artesanos ofrece una forma de anunciar los artesanos de otra cuenta además de los de tu cuenta principal.
* Preparar pedido ahora tiene un modo Avanzado que permite a los clientes elegir calidades de componentes requeridos y componentes opcionales antes de seguir una fabricación.
* ArtisanFinder ahora puede estimar la calidad de fabricación prevista a partir de la configuración de componentes seleccionada y sugerir combinaciones de componentes que alcancen el mejor resultado conocido sin usar siempre por defecto los materiales de mayor calidad.

### Cambiado

* Los escaneos de profesión ahora guardan los datos de habilidad de componentes necesarios para una simulación fiable del lado del cliente de la calidad, las recomendaciones y la preparación avanzada. Los registros de escaneo antiguos que no admiten el nuevo modelo se borran o se marcan como obsoletos para que los jugadores sepan qué personajes necesitan un nuevo escaneo.
* Al hacer clic en una fila de cliente coincidente, ahora se pueden aplicar los materiales de fabricación seguidos desde el Objective Tracker al formulario de pedido de fabricación.

### Corregido

* Abrir una profesión ya no debería causar una caída importante de FPS.
* Los miembros de hermandad que pueden fabricar un objeto ahora muestran su estado de conexión real en lugar de aparecer siempre desconectados.
* Las funciones del canal de comercio ahora funcionan en clientes de juego rusos.
* Los escaneos completos de profesión ahora reparten su trabajo de forma más uniforme, con menos bloqueos y tirones en profesiones grandes.]]
L.CHANGELOG_ENTRY_2_0_5 = [[### Añadido

* Las filas de cliente ahora incluyen acciones de Preparar pedido para fabricaciones estándar y fabricaciones con componentes opcionales.
* Las fabricaciones preparadas se siguen en el Objective Tracker con componentes requeridos, componentes opcionales seleccionados, cantidades necesarias, recuentos disponibles y faltantes, y marcadores de calidad.
* Las búsquedas en la casa de subastas desde fabricaciones preparadas ahora usan búsquedas múltiples temporales de Auctionator cuando Auctionator está activado.

### Cambiado

* Los botones "Pedido personal" y "Pedido de hermandad" se han eliminado para que un simple clic en una fila de artesano rellene automáticamente el formulario de la izquierda.]]
L.CHANGELOG_ENTRY_2_0_3 = [[### Corregido

* Intento de susurro a PNJ de pedidos de patrón o personajes alternativos al completar un pedido de fabricación.]]
L.CHANGELOG_ENTRY_2_0_2 = [[### Añadido

* Notificaciones para clientes cuando se completa un pedido de fabricación.]]
L.CHANGELOG_ENTRY_2_0_1 = [[### Añadido

* Localización para chino simplificado, español de Latinoamérica, portugués y portugués de Brasil.

### Cambiado

* Pequeñas optimizaciones de comunicación.
* La comunicación de mensajes del addon ahora está comprimida.

### Corregido

* Pequeña fuga de memoria en sesiones largas.]]

L.OPTIONS_SECTION_NOTIFICATIONS = "Notificaciones"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS = "Ocultar tus pedidos para personajes alternativos"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS_DESC = "Oculta las notificaciones de pedidos personales para tus personajes alternativos cuando las envía uno de tus personajes."
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS = "Ocultar tus pedidos completados para personajes alternativos"
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS_DESC = "Oculta las notificaciones de pedidos de cliente completados cuando las envía uno de tus personajes."
L.OPTIONS_ORDER_SOUND = "Sonido de notificación de pedidos"
L.OPTIONS_ORDER_SOUND_DESC = "Elige el sonido para las notificaciones de pedidos."
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED = "Activar sonido de notificación de pedidos"
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED_DESC = "Reproduce un sonido para pedidos personales y pedidos de cliente completados."
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED = "Activar aviso de notificación de pedidos"
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED_DESC = "Muestra un aviso en el centro de la pantalla para pedidos personales y pedidos de cliente completados."
L.OPTIONS_ORDER_SOUND_CATALOG_SHOP_OPEN = "Abrir panel de tienda"
L.OPTIONS_ORDER_SOUND_STORE_DELIVERY = "Aviso de entrega de tienda"
L.OPTIONS_ORDER_SOUND_STORE_OPEN = "Ventana de tienda"
L.OPTIONS_ORDER_SOUND_BNET_TOAST = "Aviso de Battle.net"
L.OPTIONS_ORDER_SOUND_PROFESSION_TOAST = "Aviso de profesión"
L.OPTIONS_ORDER_SOUND_EVENT_SCHEDULER_CHIME = "Campana de calendario"
L.OPTIONS_ORDER_SOUND_GARRISON_WORK_ORDER = "Inicio de orden de trabajo"
L.OPTIONS_ORDER_SOUND_BACKPACK_COIN = "Selección de moneda"
L.OPTIONS_ORDER_SOUND_SOULBIND = "Activación de vínculo de alma"
L.OPTIONS_ORDER_SOUND_GM_CHAT_WARNING = "Aviso de chat MJ"
L.OPTIONS_ORDER_SOUND_READY_CHECK = "Comprobación de preparación"
L.OPTIONS_ORDER_SOUND_AUCTION = "Casa de subastas"
L.OPTIONS_ORDER_SOUND_CHANNEL = "Canal de sonido"
L.OPTIONS_ORDER_SOUND_CHANNEL_DESC = "Elige qué canal de sonido del juego reproduce las notificaciones de pedidos."
L.OPTIONS_SOUND_CHANNEL_DEFAULT = "Maestro"
L.OPTIONS_SOUND_CHANNEL_SFX = "Efectos de sonido"
L.OPTIONS_SOUND_CHANNEL_MUSIC = "Música"
L.OPTIONS_SOUND_CHANNEL_AMBIENCE = "Ambiente"
L.OPTIONS_SOUND_CHANNEL_DIALOG = "Diálogo"
L.OPTIONS_PLAY_ORDER_SOUND = "Reproducir sonido"
L.OPTIONS_PLAY_ORDER_SOUND_DESC = "Reproduce el sonido seleccionado para notificaciones de pedidos."
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS = "Borrar notificaciones"
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS_DESC = "Borra las notificaciones recordadas de pedidos personales."

L.TUTORIAL_RESET_DONE = "tutorial restablecido."
L.TUTORIAL_INTRO = "ArtisanFinder funciona en dos lugares. Abre cada una de tus profesiones una vez para escanear tus datos de fabricación. Después visita al PNJ de pedidos de fabricación para ver artesanos disponibles al crear un pedido."
L.TUTORIAL_MINIMAP_BUTTON = "Usa el botón del minimapa para gestionar ArtisanFinder rápidamente.\nClic izquierdo alterna disponibilidad, clic central alterna disponibilidad automática, clic derecho abre opciones y Mayús-clic oculta el botón."
L.TUTORIAL_CUSTOMER_STATUS = "Selecciona un objeto de pedido en el formulario de pedidos de fabricación. ArtisanFinder buscará artesanos compatibles."
L.TUTORIAL_CUSTOMER_SEARCH = "Filtra, ordena o actualiza los resultados del objeto seleccionado."
L.TUTORIAL_CUSTOMER_ROW = "Las filas muestran comisión, calidad, disponibilidad, origen de hermandad o chat de comercio y la nota del artesano."
L.TUTORIAL_CUSTOMER_ACTION = "Haz clic en una fila real para rellenar automáticamente el formulario de pedido de cliente.\n\nAbre el menú de la fila para marcar un artesano como favorito, susurrarle o abrir su profesión si está disponible."
L.TUTORIAL_PROFESSION_NAME = "Tutorial"

L.CUSTOMER_SIDE_PREVIEW = "Vista previa de cliente"
L.CUSTOMER_SIDE_PREVIEW_EMPTY = "Aún no hay datos visibles para el cliente guardados en esta fila."
L.CUSTOMER_SIDE_PREVIEW_SCANNING = "Se está escaneando esta fabricación. La vista previa de cliente se actualizará al terminar."
L.TUTORIAL_CRAFTER_PREVIEW = "Pasa el cursor sobre el icono de vista previa de cliente para ver lo que verán los clientes para el objeto seleccionado, incluidos valores específicos del objeto combinados con los predeterminados de la profesión."
