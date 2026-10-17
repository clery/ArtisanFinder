local _, AF = ...
local L = AF.Locales.frFR


L.CHANGELOG_ENTRY_2_1_4 = [[### Modifié

* Mise à jour de la version d'interface pour le patch 12.1.5 de World of Warcraft.]]
L.CHANGELOG_ENTRY_2_1_3 = [[### Modifié

* Réduction des traitements répétés lors de la vérification des scans de métiers obsolètes et de l'affichage des métiers scannés, pour une meilleure réactivité avec les profils d'artisans volumineux.

### Corrigé

* Correction des erreurs de barres d'action après la sélection des contrôles d'ArtisanFinder en mode Édition.
* Les entrées de scan enregistrées mal formées sont désormais ignorées sans erreur lors de la création des listes de métiers et des résumés de scans obsolètes.]]
L.CHANGELOG_ENTRY_2_1_2 = [[### Corrigé

* Les sorts renforcés d'évocateur comme Souffle de feu ne sont plus interrompus par ArtisanFinder.
* La vérification et l'actualisation de la liste des commandes d'artisanat côté client ne s'exécutent désormais que lorsque l'interface des commandes client est ouverte, attendent pendant que vous incantez/canalisez ou êtes en état restreint, et ne sont plus mises en file par les événements d'actualisation des commandes client.]]
L.CHANGELOG_ENTRY_2_1_1 = [[### Ajouté

* Les aperçus de composants du panneau de métier peuvent maintenant utiliser une option "Composants illimités" pour simuler les répartitions de qualité sans posséder tous les composants.
* Les contrôles du panneau de métier peuvent maintenant s'ouvrir par défaut en mode maximisé ou minimisé depuis les options de l'addon.

### Corrigé

* Les scans des données de compétence des composants tolèrent maintenant les données de base incomplètes au lieu d'échouer.
* Le traitement de la file de scan de métier se termine maintenant sans erreur si les données de progression du scan sont absentes ou mal formées.
* L'analyse des métiers depuis les liens de commerce ignore maintenant les jetons numériques mal formés sans erreur.]]
L.CHANGELOG_ENTRY_2_1_0 = [[### Ajouté

* L'importation/exportation d'artisans offre un moyen d'annoncer les artisans d'un autre compte en plus de ceux de votre compte principal.
* Préparer la commande propose maintenant un mode Avancé qui permet aux clients de choisir les qualités des composants requis et les composants optionnels avant de suivre une fabrication.
* ArtisanFinder peut maintenant estimer la qualité de fabrication attendue à partir de la configuration de composants sélectionnée et suggérer des combinaisons de composants atteignant le meilleur résultat connu sans toujours choisir par défaut les matériaux de plus haute qualité.

### Modifié

* Les scans de métier enregistrent maintenant les données de compétence des composants nécessaires pour une simulation fiable côté client de la qualité, des recommandations et de la préparation avancée. Les anciens enregistrements de scan qui ne prennent pas en charge le nouveau modèle sont effacés ou marqués obsolètes afin que les joueurs sachent quels personnages doivent être rescannés.
* Cliquer sur une ligne client correspondante peut maintenant appliquer les matériaux de fabrication suivis depuis l'Objective Tracker dans le formulaire de commande d'artisanat.

### Corrigé

* Ouvrir un métier ne devrait plus provoquer de chute importante d'IPS.
* Les membres de guilde pouvant fabriquer un objet affichent maintenant leur véritable statut en ligne au lieu d'apparaître toujours hors ligne.
* Les fonctionnalités du canal Commerce fonctionnent maintenant sur les clients de jeu russes.
* Les scans complets de métier répartissent maintenant leur travail plus uniformément, avec moins de blocages et de saccades sur les grands métiers.]]
L.CHANGELOG_ENTRY_2_0_5 = [[### Ajouté

* Les lignes client incluent désormais des actions Préparer la commande pour les fabrications standard et celles avec composants optionnels.
* Les fabrications préparées sont suivies dans l'Objective Tracker avec composants requis, composants optionnels sélectionnés, quantités nécessaires, comptes possédés et manquants, et marqueurs de qualité.
* Les recherches à l'hôtel des ventes depuis les fabrications préparées utilisent désormais les recherches multiples temporaires d'Auctionator quand Auctionator est activé.

### Modifié

* Les boutons "Commande personnelle" et "Commande de guilde" ont été supprimés afin qu'un simple clic sur une ligne d'artisan remplisse automatiquement le formulaire à gauche.]]
L.CHANGELOG_ENTRY_2_0_3 = [[### Corrigé

* Tentative de chuchotement sur les PNJ de commandes de mécène ou les personnages secondaires à la fin d'une commande d'artisanat.]]
L.CHANGELOG_ENTRY_2_0_2 = [[### Ajouté

* Notifications pour les clients lorsqu'une commande d'artisanat a été terminée.]]
L.CHANGELOG_ENTRY_2_0_1 = [[### Ajouté

* Localisation pour le chinois simplifié, l'espagnol d'Amérique latine, le portugais et le portugais brésilien.

### Modifié

* Petites optimisations de communication.
* La communication des messages d'addon est désormais compressée.

### Corrigé

* Petite fuite mémoire lors des longues sessions.]]

L.OPTIONS_SECTION_NOTIFICATIONS = "Notifications"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS = "Masquer vos commandes d'autres personnages"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS_DESC = "Masque les notifications de commandes personnelles destinées à vos autres personnages lorsqu'elles sont envoyées par l'un de vos personnages."
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS = "Masquer vos commandes terminées d'autres personnages"
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS_DESC = "Masque les notifications de commandes client terminées lorsqu'elles sont envoyées par l'un de vos personnages."
L.OPTIONS_ORDER_SOUND = "Son de notification de commande"
L.OPTIONS_ORDER_SOUND_DESC = "Choisissez le son joué pour les notifications de commande."
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED = "Activer le son de notification de commande"
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED_DESC = "Joue un son pour les commandes personnelles et les commandes client terminées."
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED = "Activer la bannière de notification de commande"
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED_DESC = "Affiche une bannière au centre de l’écran pour les commandes personnelles et les commandes client terminées."
L.OPTIONS_ORDER_SOUND_CATALOG_SHOP_OPEN = "Ouverture de la boutique"
L.OPTIONS_ORDER_SOUND_STORE_DELIVERY = "Notification de livraison boutique"
L.OPTIONS_ORDER_SOUND_STORE_OPEN = "Fenêtre de boutique"
L.OPTIONS_ORDER_SOUND_BNET_TOAST = "Notification Battle.net"
L.OPTIONS_ORDER_SOUND_PROFESSION_TOAST = "Notification de métier"
L.OPTIONS_ORDER_SOUND_EVENT_SCHEDULER_CHIME = "Carillon de calendrier"
L.OPTIONS_ORDER_SOUND_GARRISON_WORK_ORDER = "Début d'ordre de travail"
L.OPTIONS_ORDER_SOUND_BACKPACK_COIN = "Sélection de pièce"
L.OPTIONS_ORDER_SOUND_SOULBIND = "Activation de lien d'âme"
L.OPTIONS_ORDER_SOUND_GM_CHAT_WARNING = "Avertissement de discussion MJ"
L.OPTIONS_ORDER_SOUND_READY_CHECK = "Appel de préparation"
L.OPTIONS_ORDER_SOUND_AUCTION = "Hôtel des ventes"
L.OPTIONS_ORDER_SOUND_CHANNEL = "Canal sonore"
L.OPTIONS_ORDER_SOUND_CHANNEL_DESC = "Choisissez le canal audio utilisé pour les notifications de commande."
L.OPTIONS_SOUND_CHANNEL_DEFAULT = "Maître"
L.OPTIONS_SOUND_CHANNEL_SFX = "Effets sonores"
L.OPTIONS_SOUND_CHANNEL_MUSIC = "Musique"
L.OPTIONS_SOUND_CHANNEL_AMBIENCE = "Ambiance"
L.OPTIONS_SOUND_CHANNEL_DIALOG = "Dialogues"
L.OPTIONS_PLAY_ORDER_SOUND = "Jouer le son"
L.OPTIONS_PLAY_ORDER_SOUND_DESC = "Joue le son de notification de commande sélectionné."
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS = "Effacer les notifications"
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS_DESC = "Efface les notifications de commandes personnelles mémorisées."

L.TUTORIAL_RESET_DONE = "tutoriel réinitialisé."
L.TUTORIAL_INTRO = "ArtisanFinder fonctionne à deux endroits. Ouvrez chacun de vos métiers une fois pour scanner vos données d'artisanat. Rendez-vous ensuite au PNJ de commandes d'artisanat pour voir les artisans disponibles pendant la création d'une commande."
L.TUTORIAL_MINIMAP_BUTTON = "Utilisez le bouton de minicarte pour gérer ArtisanFinder rapidement.\nClic gauche : disponibilité, clic molette : disponibilité auto, clic droit : options, Maj-clic : masquer le bouton."
L.TUTORIAL_CUSTOMER_STATUS = "Sélectionnez un objet de commande dans le formulaire de commande d'artisanat. ArtisanFinder cherche ensuite les artisans correspondants."
L.TUTORIAL_CUSTOMER_SEARCH = "Filtrez, triez ou actualisez les résultats pour l'objet sélectionné."
L.TUTORIAL_CUSTOMER_ROW = "Les lignes affichent commission, qualité, disponibilité, source guilde ou canal Commerce, et la note de l'artisan."
L.TUTORIAL_CUSTOMER_ACTION = "Cliquez sur une vraie ligne pour remplir automatiquement le formulaire de commande client.\n\nOuvrez le menu de la ligne pour ajouter un artisan aux favoris, le chuchoter ou ouvrir son métier si disponible."
L.TUTORIAL_PROFESSION_NAME = "Tutoriel"

L.CUSTOMER_SIDE_PREVIEW = "Aperçu client"
L.CUSTOMER_SIDE_PREVIEW_EMPTY = "Aucune donnée visible par le client n'est encore enregistrée pour cette ligne."
L.CUSTOMER_SIDE_PREVIEW_SCANNING = "Cette fabrication est en cours d'analyse. L'aperçu client sera actualisé à la fin de l'analyse."
L.TUTORIAL_CRAFTER_PREVIEW = "Survolez l'icône Aperçu client pour voir ce que les clients verront pour l'objet sélectionné, avec les valeurs propres à l'objet fusionnées avec les valeurs par défaut du métier."
