local _, AF = ...

-- Shared by Retail order alerts and Forever agreement toasts.
local FALLBACK = "CATALOG_SHOP_OPEN_LOADING_SCREEN"
function AF:PlayNotificationSound(force)
    local db = self.db
    if not force and db and (db.orderNotificationsEnabled == false or db.orderNotificationSoundEnabled == false) then
        return
    end
    local key = db and db.orderNotificationSound or FALLBACK
    local sound = SOUNDKIT and (SOUNDKIT[key] or SOUNDKIT[FALLBACK])
    local channel = db and db.orderNotificationChannel
    channel = channel and channel ~= "" and channel ~= "default" and channel or nil
    if sound and PlaySound then PlaySound(sound, channel) end
end

-- Preserve the Retail settings preview and slash-command API.
function AF:PlayOrderNotificationSound(force)
    self:PlayNotificationSound(force)
end
