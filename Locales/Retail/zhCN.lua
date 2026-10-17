local _, AF = ...
local L = AF.Locales.zhCN


L.CHANGELOG_ENTRY_2_1_5 = [[### 改进
- ArtisanFinder 现已在同一下载包中支持正式服和 WoW Forever，并为各版本提供相应功能。]]

L.CHANGELOG_ENTRY_2_1_4 = [[### 已更改

* 更新了接口版本，以适配《魔兽世界》12.1.5补丁。]]
L.CHANGELOG_ENTRY_2_1_3 = [[### 已更改

* 减少检查过期专业扫描数据和显示已扫描专业时的重复计算，提高大型工匠档案的响应速度。

### 已修复

* 修复在编辑模式中选择ArtisanFinder控件后出现的动作条错误。
* 生成专业列表和过期扫描摘要时，现在会安全跳过格式错误的已保存扫描记录。]]
L.CHANGELOG_ENTRY_2_1_2 = [[### 已修复

* 唤魔师的蓄力施法（如火焰吐息）不再会被 ArtisanFinder 打断。
* 客户制造订单轮询和列表刷新现在只会在客户订单界面打开时运行，在你施法/引导或受限制时会延后，并且客户订单刷新事件不再排队客户轮询。]]
L.CHANGELOG_ENTRY_2_1_1 = [[### 新增

* 专业面板的材料预览现在可以使用“无限材料”开关，在不拥有所有材料的情况下模拟品质分配。
* 专业面板控件现在可以在插件选项中设为默认最大化或最小化。

### 已修复

* 材料技能数据扫描现在会容忍不完整的基准材料数据，而不是直接失败。
* 如果扫描进度数据缺失或格式异常，专业扫描队列处理现在会安全退出。
* 交易链接的专业解析现在会安全忽略格式异常的数字标记。]]
L.CHANGELOG_ENTRY_2_1_0 = [[### 新增

* 工匠导入/导出现在可同时宣传另一个账号的工匠和你主账号的工匠。
* 准备订单现在有高级模式，让客户能在追踪制作前选择必需材料品质和可选材料。
* ArtisanFinder 现在可根据所选材料配置估算预期制作品质，并建议能达到已知最佳结果的材料组合，而不是总是默认使用最高品质材料。

### 已更改

* 专业扫描现在会保存材料技能数据，以便在客户端可靠模拟品质、提供建议并支持高级准备。无法支持新模型的旧扫描记录会被清除或标记为过期，让玩家知道哪些角色需要重新扫描。
* 点击匹配的客户行现在可将 Objective Tracker 中追踪的制作材料应用到制造订单表单中。

### 已修复

* 打开专业时不应再导致明显 FPS 下降。
* 能制作某件物品的公会成员现在会显示真实的在线状态，而不再总是显示为离线。
* 交易频道功能现在可在俄语游戏客户端上正常工作。
* 完整专业扫描现在能更均匀地分配工作，大型专业的卡顿和掉帧更少。]]
L.CHANGELOG_ENTRY_2_0_5 = [[### 新增

* 客户行现在为标准制作和带可选材料的制作提供“准备订单”操作。
* 已准备制作会在 Objective Tracker 中追踪必需组件、已选可选材料、所需数量、拥有和缺少数量，以及品质标记。
* 当启用 Auctionator 时，已准备制作的拍卖行搜索现在会使用 Auctionator 临时多重搜索。

### 已更改

* “个人订单”和“公会订单”按钮已移除，现在只需点击工匠行即可自动填充左侧表单。]]
L.CHANGELOG_ENTRY_2_0_3 = [[### 已修复

* 完成制作订单时，对赞助订单 NPC 或小号角色的悄悄话尝试。]]
L.CHANGELOG_ENTRY_2_0_2 = [[### 新增

* 当制作订单完成时向客户发送通知。]]
L.CHANGELOG_ENTRY_2_0_1 = [[### 新增

* 简体中文、拉美西班牙语、葡萄牙语和巴西葡萄牙语本地化。

### 已更改

* 小幅通信优化。
* 插件消息通信现在会被压缩。

### 已修复

* 修复长时间会话中的小型内存泄漏。]]

L.OPTIONS_SECTION_NOTIFICATIONS = "通知"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS = "隐藏自己发送给其他角色的订单通知"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS_DESC = "当个人订单由你的某个角色发送给你的其他角色时，隐藏其通知。"
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS = "隐藏自己发送给其他角色的已完成订单通知"
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS_DESC = "当已完成的客户订单由你的某个角色发送时，隐藏其通知。"
L.OPTIONS_ORDER_SOUND = "订单通知音效"
L.OPTIONS_ORDER_SOUND_DESC = "选择订单通知播放的声音。"
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED = "启用订单通知音效"
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED_DESC = "为个人订单和已完成的客户订单播放声音。"
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED = "启用订单通知横幅"
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED_DESC = "为个人订单和已完成的客户订单在屏幕中央显示横幅。"
L.OPTIONS_ORDER_SOUND_CATALOG_SHOP_OPEN = "商城面板打开"
L.OPTIONS_ORDER_SOUND_STORE_DELIVERY = "商城交付通知"
L.OPTIONS_ORDER_SOUND_STORE_OPEN = "商城窗口"
L.OPTIONS_ORDER_SOUND_BNET_TOAST = "战网通知"
L.OPTIONS_ORDER_SOUND_PROFESSION_TOAST = "专业通知"
L.OPTIONS_ORDER_SOUND_EVENT_SCHEDULER_CHIME = "日历提示音"
L.OPTIONS_ORDER_SOUND_GARRISON_WORK_ORDER = "开始工作订单"
L.OPTIONS_ORDER_SOUND_BACKPACK_COIN = "硬币选择"
L.OPTIONS_ORDER_SOUND_SOULBIND = "激活灵魂羁绊"
L.OPTIONS_ORDER_SOUND_GM_CHAT_WARNING = "GM聊天警告"
L.OPTIONS_ORDER_SOUND_READY_CHECK = "就位确认"
L.OPTIONS_ORDER_SOUND_AUCTION = "拍卖行"
L.OPTIONS_ORDER_SOUND_CHANNEL = "声音频道"
L.OPTIONS_ORDER_SOUND_CHANNEL_DESC = "选择订单通知使用的游戏声音频道。"
L.OPTIONS_SOUND_CHANNEL_DEFAULT = "主音量"
L.OPTIONS_SOUND_CHANNEL_SFX = "音效"
L.OPTIONS_SOUND_CHANNEL_MUSIC = "音乐"
L.OPTIONS_SOUND_CHANNEL_AMBIENCE = "环境音"
L.OPTIONS_SOUND_CHANNEL_DIALOG = "对话"
L.OPTIONS_PLAY_ORDER_SOUND = "播放声音"
L.OPTIONS_PLAY_ORDER_SOUND_DESC = "播放选中的订单通知声音。"
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS = "清除通知"
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS_DESC = "清除已记住的个人订单通知。"

L.TUTORIAL_RESET_DONE = "教程已重置。"
L.TUTORIAL_INTRO = "ArtisanFinder 会在两个地方工作。先逐个打开你的专业一次，以扫描制造数据。然后前往制造订单 NPC，在创建订单时查看可用工匠。"
L.TUTORIAL_MINIMAP_BUTTON = "使用小地图按钮快速管理 ArtisanFinder。\n左键切换可用状态，中键切换自动可用，右键打开选项，Shift+点击隐藏按钮。"
L.TUTORIAL_CUSTOMER_STATUS = "在制造订单表单中选择一个订单物品。ArtisanFinder 随后会搜索匹配的工匠。"
L.TUTORIAL_CUSTOMER_SEARCH = "筛选、排序或刷新所选物品的结果。"
L.TUTORIAL_CUSTOMER_ROW = "行会显示佣金、品质、可用状态、公会或交易频道来源，以及工匠备注。"
L.TUTORIAL_CUSTOMER_ACTION = "点击真实行可自动填写客户订单表单。\n\n打开行菜单，可收藏工匠、密语，或在可用时打开其专业。"
L.TUTORIAL_PROFESSION_NAME = "教程"

L.CUSTOMER_SIDE_PREVIEW = "客户预览"
L.CUSTOMER_SIDE_PREVIEW_EMPTY = "此行尚未保存客户可见数据。"
L.CUSTOMER_SIDE_PREVIEW_SCANNING = "正在扫描此制造。扫描完成后将更新客户预览。"
L.TUTORIAL_CRAFTER_PREVIEW = "将鼠标悬停在客户预览图标上，查看客户会看到的所选制造内容，包括物品专属数值与专业默认值合并后的结果。"
