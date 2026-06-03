local _, AF = ...
local locale = GetLocale()
AF.Locales = AF.Locales or {}
local L = setmetatable({}, { __index = AF.Locales.esES or AF.Locales.enUS })
AF.Locales.esMX = L
if locale == "esMX" then
	AF.L = L
end

L.ADDON_COMMS_UNAVAILABLE_INSTANCE = "La comunicación de ArtisanFinder no está disponible durante actividades restringidas."
L.SELECT_ORDER_ITEM = "Selecciona un objeto de la orden."
L.YOUR_ALT = "Tu personaje alterno"
L.PERSONAL_ORDER = "Orden personal"
L.GUILD_ORDER = "Orden de hermandad"
L.PERSONAL_ORDER_NO_FORM = "abre una orden de cliente antes de llenar una orden personal."
L.PERSONAL_ORDER_FILLED = "Se llenaron los campos de la orden personal. Revísalos antes de colocar la orden."
L.GUILD_ORDER_FILLED = "Se llenaron los campos de la orden de hermandad. Revísalos antes de colocar la orden."
L.ORDER_NOTIFICATION_MESSAGE = "%s recibió %d orden(es) personal(es)."
L.ORDER_NOTIFICATION_TITLE = "Orden personal recibida"
L.ORDER_NOTIFICATION_META = "Para %s - De %s"
L.ORDER_NOTIFICATION_UNKNOWN_ITEM = "Orden personal"
L.ORDER_FULFILLED_NOTIFICATION_TITLE = "Orden de fabricación completada"
L.ORDER_FULFILLED_NOTIFICATION_META = "Creado por %s"
L.ORDER_FULFILLED_NOTIFICATION_ACTION = "Revisa tu buzón"
L.ORDER_FULFILLED_NOTIFICATION_UNKNOWN_ITEM = "Orden de fabricación"
L.UNKNOWN_CRAFTER = "Artesano desconocido"
L.ORDER_TOOLTIP_ROW = "%s%s: %d orden(es) personal(es)"
L.EDITMODE_ORDER_TOAST = "Aviso de orden de ArtisanFinder"
L.EDITMODE_TOAST_SCALE_DESC = "Ajusta el tamaño del aviso de notificación de órdenes."
L.EDITMODE_TOAST_GROW_DIRECTION_DESC = "Elige dónde se apilan avisos adicionales de notificaciones de órdenes."
L.DEBUG_HELP_NOTIFY = "/af dev notify [personaje] [cantidad] - simula una notificación de orden personal de un personaje alterno"
L.DEV_HELP_FULFILLED = "/af dev fulfilled [artesano] - simula una notificación de orden de cliente completada"
L.DEV_HELP_SOUND = "/af dev sound order - reproduce el sonido de notificación de órdenes"
L.DEBUG_ORDERS_STATE = "depuración de órdenes personales: actual=%s últimoRemitente=%s"
L.OPTIONS_ORDER_SOUND = "Sonido de notificación de órdenes"
L.OPTIONS_ORDER_SOUND_DESC = "Elige el sonido para las notificaciones de órdenes."
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED = "Activar sonido de notificación de órdenes"
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED_DESC = "Reproduce un sonido para órdenes personales y órdenes de cliente completadas."
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED = "Activar aviso de notificación de órdenes"
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED_DESC = "Muestra un aviso en el centro de la pantalla para órdenes personales y órdenes de cliente completadas."
L.OPTIONS_PLAY_ORDER_SOUND_DESC = "Reproduce el sonido seleccionado para notificaciones de órdenes."
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS_DESC = "Borra las notificaciones recordadas de órdenes personales."
L.ORDER_NOTIFICATIONS_CLEARED = "notificaciones de órdenes personales borradas."
L.MINIMAP_SHIFT_RIGHT_CLICK = "Mayús-clic derecho: borrar notificaciones de órdenes"
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS = "Borrar notificaciones"
L.TUTORIAL_INTRO = "ArtisanFinder funciona en dos lugares. Abre cada una de tus profesiones una vez para escanear tus datos de fabricación. Después visita al PNJ de órdenes de fabricación para ver artesanos disponibles al crear una orden."
L.TUTORIAL_CUSTOMER_STATUS = "Selecciona un objeto de orden en el formulario de órdenes de fabricación. ArtisanFinder buscará artesanos compatibles."
L.TUTORIAL_CUSTOMER_ACTION = "Haz clic en una fila real para llenar automáticamente el formulario de orden de cliente.\n\nUsa el menú de la fila para marcar un artesano como favorito, susurrarle o abrir su profesión si está disponible."
