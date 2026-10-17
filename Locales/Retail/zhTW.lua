local _, AF = ...
local L = AF.Locales.zhTW


L.CHANGELOG_ENTRY_2_1_5 = [[### 改進
- ArtisanFinder 現已在同一下載套件中支援正式服與 WoW Forever，並為各版本提供相應功能。]]

L.CHANGELOG_ENTRY_2_1_4 = [[### 已變更

* 更新了介面版本，以支援《魔獸世界》12.1.5更新。]]
L.CHANGELOG_ENTRY_2_1_3 = [[### 已變更

* 減少檢查過期專業掃描資料及顯示已掃描專業時的重複計算，提升大型工匠檔案的反應速度。

### 已修正

* 修正在編輯模式中選取ArtisanFinder控制項後出現的快捷列錯誤。
* 建立專業清單及過期掃描摘要時，現在會安全略過格式錯誤的已儲存掃描紀錄。]]
L.CHANGELOG_ENTRY_2_1_2 = [[### 已修正

* 喚能師的蓄力施法（如火焰吐息）不再會被 ArtisanFinder 打斷。
* 客戶製造訂單輪詢和清單重新整理現在只會在客戶訂單介面開啟時執行，在你施法/引導或受限制時會延後，且客戶訂單重新整理事件不再排隊客戶輪詢。]]
L.CHANGELOG_ENTRY_2_1_1 = [[### 新增

* 專業技能面板的材料預覽現在可以使用「無限材料」切換，在未擁有所有材料時模擬品質分配。
* 專業技能面板控制項現在可以在插件選項中設定為預設最大化或最小化。

### 已修正

* 材料技能資料掃描現在會容忍不完整的基準材料資料，而不是直接失敗。
* 如果掃描進度資料缺失或格式異常，專業技能掃描佇列處理現在會安全退出。
* 交易連結的專業技能解析現在會安全忽略格式異常的數字標記。]]
L.CHANGELOG_ENTRY_2_1_0 = [[### 新增

* 工匠匯入/匯出現在可同時宣傳另一個帳號的工匠和你主帳號的工匠。
* 準備訂單現在有進階模式，讓客戶能在追蹤製作前選擇必要材料品質和可選材料。
* ArtisanFinder 現在可根據所選材料配置估算預期製作品質，並建議能達到已知最佳結果的材料組合，而不是總是預設使用最高品質材料。

### 已變更

* 專業技能掃描現在會儲存材料技能資料，以便在客戶端可靠模擬品質、提供建議並支援進階準備。無法支援新模型的舊掃描記錄會被清除或標記為過期，讓玩家知道哪些角色需要重新掃描。
* 點擊符合條件的客戶列現在可將 Objective Tracker 中追蹤的製作材料套用到製造訂單表單中。

### 已修正

* 開啟專業技能時不應再造成明顯 FPS 下降。
* 能製作某件物品的公會成員現在會顯示真實的上線狀態，而不再總是顯示為離線。
* 交易頻道功能現在可在俄語遊戲用戶端上正常運作。
* 完整專業技能掃描現在能更均勻地分配工作，大型專業技能的卡頓更少。]]
L.CHANGELOG_ENTRY_2_0_5 = [[### 新增

* 客戶列現在為標準製作和帶可選材料的製作提供「準備訂單」操作。
* 已準備製作會在 Objective Tracker 中追蹤必要元件、已選可選材料、所需數量、擁有和缺少數量，以及品質標記。
* 當啟用 Auctionator 時，已準備製作的拍賣場搜尋現在會使用 Auctionator 臨時多重搜尋。

### 已變更

* 「個人訂單」和「公會訂單」按鈕已移除，現在只需點擊工匠列即可自動填入左側表單。]]
L.CHANGELOG_ENTRY_2_0_3 = [[### 已修正

* 完成製作訂單時，對贊助訂單 NPC 或分身角色的悄悄話嘗試。]]
L.CHANGELOG_ENTRY_2_0_2 = [[### 新增

* 當製作訂單完成時向客戶發送通知。]]
L.CHANGELOG_ENTRY_2_0_1 = [[### 新增

* 簡體中文、拉美西班牙語、葡萄牙語和巴西葡萄牙語本地化。

### 已變更

* 小幅通訊最佳化。
* 插件訊息通訊現在會被壓縮。

### 已修正

* 修正長時間工作階段中的小型記憶體洩漏。]]

L.OPTIONS_SECTION_NOTIFICATIONS = "通知"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS = "隱藏自己傳送給其他角色的訂單通知"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS_DESC = "當個人訂單由你的某個角色傳送給你的其他角色時，隱藏其通知。"
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS = "隱藏自己傳送給其他角色的已完成訂單通知"
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS_DESC = "當已完成的客戶訂單由你的某個角色傳送時，隱藏其通知。"
L.OPTIONS_ORDER_SOUND = "訂單通知音效"
L.OPTIONS_ORDER_SOUND_DESC = "選擇訂單通知播放的音效。"
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED = "啟用訂單通知音效"
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED_DESC = "為個人訂單和已完成的客戶訂單播放音效。"
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED = "啟用訂單通知橫幅"
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED_DESC = "為個人訂單和已完成的客戶訂單在畫面中央顯示橫幅。"
L.OPTIONS_ORDER_SOUND_CATALOG_SHOP_OPEN = "商城面板開啟"
L.OPTIONS_ORDER_SOUND_STORE_DELIVERY = "商城交付提示"
L.OPTIONS_ORDER_SOUND_STORE_OPEN = "商城視窗"
L.OPTIONS_ORDER_SOUND_BNET_TOAST = "Battle.net 提示"
L.OPTIONS_ORDER_SOUND_PROFESSION_TOAST = "專業技能提示"
L.OPTIONS_ORDER_SOUND_EVENT_SCHEDULER_CHIME = "行事曆提示音"
L.OPTIONS_ORDER_SOUND_GARRISON_WORK_ORDER = "開始工作訂單"
L.OPTIONS_ORDER_SOUND_BACKPACK_COIN = "硬幣選擇"
L.OPTIONS_ORDER_SOUND_SOULBIND = "啟用靈魂羈絆"
L.OPTIONS_ORDER_SOUND_GM_CHAT_WARNING = "GM 聊天警告"
L.OPTIONS_ORDER_SOUND_READY_CHECK = "準備確認"
L.OPTIONS_ORDER_SOUND_AUCTION = "拍賣場"
L.OPTIONS_ORDER_SOUND_CHANNEL = "音效頻道"
L.OPTIONS_ORDER_SOUND_CHANNEL_DESC = "選擇訂單通知使用的遊戲音效頻道。"
L.OPTIONS_SOUND_CHANNEL_DEFAULT = "主音量"
L.OPTIONS_SOUND_CHANNEL_SFX = "音效"
L.OPTIONS_SOUND_CHANNEL_MUSIC = "音樂"
L.OPTIONS_SOUND_CHANNEL_AMBIENCE = "環境音"
L.OPTIONS_SOUND_CHANNEL_DIALOG = "對話"
L.OPTIONS_PLAY_ORDER_SOUND = "播放音效"
L.OPTIONS_PLAY_ORDER_SOUND_DESC = "播放選取的訂單通知音效。"
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS = "清除通知"
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS_DESC = "清除已記住的個人訂單通知。"

L.TUTORIAL_RESET_DONE = "教學已重設。"
L.TUTORIAL_INTRO = "ArtisanFinder 會在兩個地方運作。先逐一開啟你的專業技能一次，讓它掃描製作資料。接著前往製造訂單 NPC，在建立訂單時查看可用工匠。"
L.TUTORIAL_MINIMAP_BUTTON = "使用小地圖按鈕快速管理 ArtisanFinder。\n左鍵切換可用狀態，中鍵切換自動可用，右鍵開啟選項，Shift+點擊隱藏按鈕。"
L.TUTORIAL_CUSTOMER_STATUS = "在製造訂單表單中選擇一個訂單物品。ArtisanFinder 隨後會搜尋相符的工匠。"
L.TUTORIAL_CUSTOMER_SEARCH = "篩選、排序或重新整理所選製作的結果。"
L.TUTORIAL_CUSTOMER_ROW = "列會顯示佣金、品質、可用狀態、公會或交易頻道來源，以及工匠備註。"
L.TUTORIAL_CUSTOMER_ACTION = "點擊真實列可自動填寫客戶訂單表單。\n\n開啟列選單，可收藏工匠、密語，或在可用時開啟其專業技能。"
L.TUTORIAL_PROFESSION_NAME = "教學"

L.CUSTOMER_SIDE_PREVIEW = "客戶預覽"
L.CUSTOMER_SIDE_PREVIEW_EMPTY = "此列尚未儲存客戶可見資料。"
L.CUSTOMER_SIDE_PREVIEW_SCANNING = "正在掃描此製作。掃描完成後將更新客戶預覽。"
L.TUTORIAL_CRAFTER_PREVIEW = "將滑鼠停在客戶預覽圖示上，查看客戶會看到的所選製作內容，包括物品專屬數值與專業技能預設值合併後的結果。"
