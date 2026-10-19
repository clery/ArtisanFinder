local _, AF = ...
local L = AF.Locales.zhTW

L.CLEAR_HELP_SCANS = "/af clear scans [名 姓]] - 清除此角色或指定角色的掃描製作資料"

L.FOREVER_HISTORICAL = "歷史紀錄"
L.FOREVER_ARTISAN = "工匠"
L.FOREVER_PROFESSION = "專業"
L.FOREVER_DISCOVERED_BY = "發現來源"
L.FOREVER_LAST_OBSERVED = "最近發現"
L.FOREVER_SOURCE_TRADE = "交易廣告"
L.FOREVER_SOURCE_GUILD = "公會"
L.FOREVER_SOURCE_ADDON = "ArtisanFinder"
L.FOREVER_ALL = "全部"
L.FOREVER_PREVIOUS = "上一頁"
L.FOREVER_NEXT = "下一頁"
L.FOREVER_ARTISAN_COUNT = "%d 位工匠"
L.FOREVER_DIRECTORY_EMPTY = "找不到工匠。請搜尋其他物品或放寬篩選條件。"
L.FOREVER_JUST_NOW = "剛剛"
L.FOREVER_MINUTES_AGO = "%d 分鐘前"
L.FOREVER_PAGE = "第 %d / %d 頁 · %d 位工匠"
L.FOREVER_ITEM_NOT_FOUND = "找不到已知物品。請貼上物品連結、輸入物品 ID，或將物品拖曳至此處。"
L.FOREVER_CHOOSE_ITEM = "選擇物品"
L.FOREVER_MINIMAP_OPEN = "左鍵點擊：開啟工匠目錄"
L.FOREVER_MINIMAP_AVAILABILITY = "Ctrl+左鍵：切換接單狀態"
L.FOREVER_INDICATORS = "專業圖示"
L.FOREVER_INDICATORS_ENABLED = "在友方玩家上方顯示專業圖示"
L.FOREVER_INDICATORS_SIZE = "圖示大小"
L.FOREVER_INDICATORS_OFFSET = "垂直偏移"
L.FOREVER_DEMO_HELP = "/af demo [on/off] - 在友方目標或自己上方預覽專業圖示，持續五分鐘。"
L.FOREVER_DEMO_STARTED = "已為 %s 啟用五分鐘的示範圖示。僅在非戰鬥、非副本狀態顯示。輸入 /af demo off 停止。"
L.FOREVER_DEMO_STOPPED = "圖示示範已停止。"
L.FOREVER_DEMO_NO_NAME = "無法取得示範玩家的名稱。"
L.FOREVER_PRICE = "價格"
L.FOREVER_PRICE_ITEM = "物品佣金"
L.FOREVER_PRICE_DEFAULT = "專業預設佣金"
L.FOREVER_PRICE_UNKNOWN = "未提供佣金。請聯絡工匠詢價。"
L.FOREVER_NO_KNOWN_CRAFTS = "暫無已知的分享配方。"
L.FOREVER_NO_DEFAULT_NOTE = "未提供專業預設備註。"
L.FOREVER_RECIPE_ID = "配方 #%d"
L.FOREVER_SEARCH_ALL = "搜尋工匠、專業或物品"
L.FOREVER_SEARCH_ALL_HELP = "依工匠、專業或已知物品名稱篩選。按 Enter 以名稱、ID 或連結搜尋物品，也可將物品拖曳至此處。"
L.FOREVER_COIN_GOLD = "金幣"
L.FOREVER_COIN_SILVER = "銀幣"
L.FOREVER_COIN_COPPER = "銅幣"
L.FOREVER_COIN_HELP = "輸入整數金額（銀幣與銅幣為 0–99）。留空表示未指定佣金或使用專業預設佣金。在金幣欄輸入 -1 接受任意佣金。"
L.FOREVER_SORT = "排序目錄"
L.FOREVER_SORT_HINT = "點擊依此欄排序，再次點擊反轉順序。"
L.FOREVER_TRACK_MATERIALS = "追蹤材料"
L.FOREVER_TRACK_MATERIALS_HELP = "在任務目標中追蹤此配方的材料。在拍賣場透過 Auctionator 搜尋缺少的材料。"
L.FOREVER_MATERIALS_UNAVAILABLE = "材料需求無法取得。請開啟工匠的專業連結或掃描配方後再試。"
L.FOREVER_HOURS_AGO = "%d 小時前"
L.FOREVER_DAYS_AGO = "%d 天前"
L.FOREVER_MONTHS_AGO = "%d 個月前"
L.FOREVER_YEARS_AGO = "%d 年前"
L.FOREVER_DISCOVERY_OPTIONS = "探索"
L.FOREVER_SHOW_FRIENDLY_NAMES = "顯示友方玩家姓名"
L.FOREVER_FRIENDLY_NAMES_QUESTION = "是否在 ArtisanFinder 專業圖示旁顯示友方玩家姓名？之後可在插件設定中變更。"
L.FOREVER_ADVERTISE_PROFESSION = "刊登此專業服務"
L.FOREVER_ADVERTISE_PROFESSION_HELP = "開啟或關閉 ArtisanFinder 中的此專業服務廣告。"
L.SELECT_ORDER_ITEM = "依名稱、ID 或連結搜尋物品，或將物品拖曳至此處。"
L.PROFESSION_LINK = "檢視專業"
L.COMMISSION_HELP_POSITIVE = "以金幣、銀幣與銅幣設定佣金。銀幣與銅幣為 0–99。"
L.COMMISSION_HELP_FREE = "在金幣欄輸入 -1 接受任意佣金。"
L.COMMISSION_INVALID = "請輸入整數金額（銀幣與銅幣為 0–99），或在金幣欄輸入 -1 接受任意佣金。"
L.OPTIONS_SHOW_OWN_CHARACTER_ROWS_DESC = "目前角色能夠製作符合物品時，將其顯示於目錄中。"

L.FOREVER_TUTORIAL_SEARCH = "依工匠、專業或已知物品搜尋。按 Enter 以物品名稱、ID 或連結查詢，也可將物品拖曳至搜尋框。"
L.FOREVER_TUTORIAL_HEADERS = "使用篩選圖示選擇專業與來源。點擊工匠、發現來源、價格或最近發現即可排序，再次點擊反轉順序。收藏的工匠始終優先顯示。"
L.FOREVER_TUTORIAL_ROWS = "點擊工匠展開專業與技能等級，再點擊專業查看已知配方。游標停留可查看備註及操作。星號用於收藏，專業連結與密語用於聯絡工匠。「追蹤材料」可建立材料清單。物品未單獨定價時使用專業預設佣金。"
L.FOREVER_TUTORIAL_PAGES = "使用箭頭切換工匠頁。在表格內捲動查看展開的專業及配方。"
L.FOREVER_TUTORIAL_RESET = "教學已重置。開啟目錄或專業即可再次查看。資訊圖示可隨時重新開啟說明。"

L.FOREVER_TUTORIAL_END_HINT = "再次點擊此資訊圖示即可結束教學。"

-- Private crafting agreements
L.AGREEMENT_TITLE = "製作協議"
L.AGREEMENT_TOAST_TITLE = "製作協議"
L.AGREEMENT_REQUEST = "請求製作"
L.AGREEMENT_SLASH_HELP = "/af agreements - 開啟私人製作協議"
L.AGREEMENT_INCOMING = "收到的"
L.AGREEMENT_OUTGOING = "發出的"
L.AGREEMENT_DRAFT = "未傳送的草稿"
L.AGREEMENT_PENDING = "待處理"
L.AGREEMENT_COUNTEROFFERED = "還價"
L.AGREEMENT_ACCEPTED = "已接受"
L.AGREEMENT_COMPLETED = "已完成"
L.AGREEMENT_DECLINED = "已拒絕"
L.AGREEMENT_CANCELLED = "已取消"
L.AGREEMENT_EXPIRED = "已過期"
L.AGREEMENT_AWAITING_CONFIRMATION = "等待完成確認"
L.AGREEMENT_WAITING_DELIVERY = "等待送達確認"
L.AGREEMENT_CONTACT = "聯絡人：%s"
L.AGREEMENT_CRAFTING_CHARACTER = "製作角色：%s"
L.AGREEMENT_QUANTITY = "製作次數"
L.AGREEMENT_TOTAL_COMMISSION = "總佣金（留空表示未指定）"
L.AGREEMENT_MESSAGE = "選填留言"
L.AGREEMENT_MATERIALS = "材料 · 擁有 / 所需 · 缺少"
L.AGREEMENT_MATERIAL_UNKNOWN = "? / %d · 缺少數量未知"
L.AGREEMENT_MATERIAL_LINE = "%s · %d / %d · 缺少 %d"
L.AGREEMENT_MORE_MATERIALS = "另有 %d 種材料（滑鼠指向查看全部）"
L.AGREEMENT_OUTPUT = "產出：%d–%d 件物品"
L.AGREEMENT_DRAFT_HELP = "協議僅記錄雙方意向。製作、交易及付款仍須手動完成。佣金為零表示免費。"
L.AGREEMENT_UNSUPPORTED = "尚未確認對方支援此功能。傳送將儲存未傳送的草稿；也可密語聯絡工匠。"
L.AGREEMENT_UNKNOWN_CRAFT = "未知製作"
L.AGREEMENT_EMPTY = "此清單中沒有協議。"
L.AGREEMENT_LIST_COUNT = "%d 份協議 · 捲動瀏覽"
L.AGREEMENT_NOTIFICATION = "製作協議已更新：%s"
L.AGREEMENT_QUANTITY_ERROR = "請輸入 1–999 次製作。"
L.AGREEMENT_PRICE_ERROR = "請輸入有效且未超出上限的總佣金。"
L.AGREEMENT_ACTION_ERROR = "無法完成此操作。請檢查協議後重試。"
L.AGREEMENT_RESTRICTED = "目前活動限制插件訊息，無法傳送。草稿已儲存，請離開此活動後重試。"
L.AGREEMENT_CAPACITY_ERROR = "已有50份進行中的送出協議。請完成或取消一份後再傳送。"
L.AGREEMENT_INVALID_ERROR = "草稿中的製作詳情或訊息無效。請選擇已知配方、其他收件人，並使用不超過256字且不含連結的訊息。"
L.AGREEMENT_SCHEMA_ERROR = "這些協議由較新版本儲存。請更新ArtisanFinder後再傳送。"
L.AGREEMENT_MATERIALS_ERROR = "無法取得此製作的材料資訊。"
L.AGREEMENT_SEND = "傳送請求"
L.AGREEMENT_ACCEPT = "接受這些條款"
L.AGREEMENT_DECLINE = "拒絕協議"
L.AGREEMENT_COUNTER = "以此總佣金和留言傳送還價"
L.AGREEMENT_CANCEL = "取消協議"
L.AGREEMENT_COMPLETE = "聲明或確認完成"
L.AGREEMENT_TRACK = "追蹤所需材料"
L.AGREEMENT_RETRY = "重試送達並同步最新狀態"
L.AGREEMENT_WHISPER = "密語聯絡人"
L.AGREEMENT_IGNORE = "忽略此玩家往後的請求"
L.AGREEMENT_DELETE = "刪除此本機紀錄"
L.AGREEMENT_IGNORED = "已忽略的請求傳送者"
L.AGREEMENT_NO_IGNORED = "沒有已忽略的玩家。"
L.AGREEMENT_UNIGNORE = "允許 %s 的請求"
L.AGREEMENT_DELIVERY_FAILED = "送達失敗 — 可以重試"

-- Labeled agreement actions
L.AGREEMENT_BUTTON_SEND = "傳送請求"
L.AGREEMENT_BUTTON_ACCEPT = "接受條款"
L.AGREEMENT_BUTTON_DECLINE = "拒絕"
L.AGREEMENT_BUTTON_COUNTER = "還價"
L.AGREEMENT_BUTTON_CANCEL = "取消協議"
L.AGREEMENT_BUTTON_COMPLETE = "聲明完成"
L.AGREEMENT_BUTTON_TRACK = "追蹤材料"
L.AGREEMENT_BUTTON_RETRY = "重試傳送"
L.AGREEMENT_BUTTON_WHISPER = "密語"
L.AGREEMENT_BUTTON_IGNORE = "忽略玩家"
L.AGREEMENT_BUTTON_DELETE = "刪除紀錄"
L.AGREEMENT_BUTTON_IGNORED = "已忽略的玩家"
L.AGREEMENT_BUTTON_PREVIOUS = "上一頁"
L.AGREEMENT_BUTTON_NEXT = "下一頁"
L.AGREEMENT_BUTTON_CONFIRM = "確認完成"

L.FOREVER_COMPLETED_AGREEMENTS = "已完成的協議"
L.FOREVER_COMPLETED_COUNTS = "完成 %d · 與你 %d"
L.FOREVER_COMPLETED_PERSONAL = "與你完成 %d"
L.FOREVER_COMPLETED_AGREEMENTS_HELP = "工匠回報的所有角色完成總數。「與你」統計與你的角色完成的協議。雙方都必須確認完成。以前刪除的歷史紀錄無法復原。"

L.AGREEMENT_TAB = "協議"

L.CHANGELOG_ENTRY_FOREVER_2_1_4 = [[### 新增
- 在獨立工匠目錄中使用搜尋、最愛和專業技能連結尋找工匠。
- 在製作視窗中管理專業技能與配方的佣金、備註及可用狀態。
- 發布各角色已掃描的專業技能，匯入或匯出工匠檔案。
- 透過友方玩家頭頂的專業技能圖示辨識附近的工匠。]]

L.CHANGELOG_ENTRY_FOREVER_2_1_5 = [[### 新增
- 按工匠、專業技能或物品名稱尋找工匠，包括關聯的分身。使用物品連結搜尋，或將物品拖入搜尋視窗。
- 除 ArtisanFinder、公會成員和交易頻道資訊外，還可透過 Linked Inn、CraftBoard 和 Release Gaming – Find Crafts 發現工匠。
- 在任務目標中追蹤製作材料，並使用 Auctionator 搜尋缺少的材料。

### 已變更
- 瀏覽可展開的工匠目錄，查看專業技能等級、已學配方、佣金及備註。篩選和排序結果、優先顯示最愛，並直接開啟專業技能連結或密語工匠。]]

L.CHANGELOG_ENTRY_FOREVER_2_2_0 = [[### 新增
- 直接從搜尋結果發起私人製作協議：請求製作、協商數量和佣金、接受或拒絕條款，並由雙方確認完成。
- 在專用分頁中瀏覽收到和發出的協議，查看未讀標記、通知、送達狀態並重試傳送。
- 在搜尋結果中查看已完成協議總數，並單獨顯示與你完成的協議數量。
- 在目標追蹤器中單獨追蹤已接受的協議，並使用 Auctionator 搜尋缺少的材料。

### 已變更
- 協議採用固定尺寸的羊皮紙頁面，搭配任務風格物品卡片、醒目的缺少材料提示和完成印章。
- 材料數量來自客戶，並在協議被接受時儲存。重新開啟已接受的協議不會請求或更改這些數量；無法取得的數量仍顯示為未知。
- 私人協議要求雙方使用相容版本的 ArtisanFinder。協議不會自動製作、交易或轉移金幣。]]
