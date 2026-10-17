local _, AF = ...
local L = AF.Locales.frFR

L.FOREVER_HISTORICAL = "Historique"
L.CLEAR_HELP_SCANS = "/af clear scans [Prénom Nom] - efface les scans de ce personnage ou du nom complet indiqué"
L.FOREVER_ARTISAN = "Artisan"
L.FOREVER_PROFESSION = "Métier"
L.FOREVER_DISCOVERED_BY = "Découvert via"
L.FOREVER_LAST_OBSERVED = "Dernière observation"
L.FOREVER_SOURCE_TRADE = "Offre Commerce"
L.FOREVER_SOURCE_GUILD = "Guilde"
L.FOREVER_SOURCE_ADDON = "ArtisanFinder"
L.FOREVER_ALL = "Tous"
L.FOREVER_PREVIOUS = "Page précédente"
L.FOREVER_NEXT = "Page suivante"
L.FOREVER_ARTISAN_COUNT = "%d artisans"
L.FOREVER_DIRECTORY_EMPTY = "Aucun artisan trouvé. Essayez un autre objet ou élargissez les filtres."
L.FOREVER_JUST_NOW = "à l’instant"
L.FOREVER_MINUTES_AGO = "il y a %d min"
L.FOREVER_PAGE = "Page %d / %d · %d artisans"
L.FOREVER_ITEM_NOT_FOUND = "Aucun objet connu correspondant. Collez un lien, saisissez un identifiant ou glissez l’objet ici."
L.FOREVER_CHOOSE_ITEM = "Choisir un objet"
L.FOREVER_MINIMAP_OPEN = "Clic gauche : ouvrir l’annuaire des artisans"
L.FOREVER_MINIMAP_AVAILABILITY = "Ctrl-clic gauche : changer la disponibilité"
L.SELECT_ORDER_ITEM = "Recherchez un objet par nom, identifiant ou lien, ou glissez-le dans le champ de recherche."
L.PROFESSION_LINK = "Voir le métier"

L.FOREVER_INDICATORS = "Indicateurs de métier"
L.FOREVER_INDICATORS_ENABLED = "Afficher les icônes de métier au-dessus des joueurs alliés"
L.FOREVER_INDICATORS_SIZE = "Taille des icônes"
L.FOREVER_INDICATORS_OFFSET = "Décalage vertical"

L.CHANGELOG_ENTRY_FOREVER_0_3_0_dev = [[### Ajouté
- Recherche d’artisans par nom, métier ou objet, y compris leurs personnages secondaires connus. Recherchez un objet à partir de son lien ou en le glissant dans la découverte.
- Découverte des artisans utilisant Linked Inn, CraftBoard et Release Gaming – Find Crafts, en complément d’ArtisanFinder, des membres de guilde et des annonces du canal Commerce.
- Suivi des composants d’une fabrication dans les objectifs de quête et recherche des matériaux manquants avec Auctionator.

### Modifié
- Annuaire dépliable affichant les niveaux de métier, recettes connues, commissions et notes. Filtrez et triez les résultats, retrouvez vos favoris en tête, consultez les métiers ou contactez directement les artisans.
- Saisie des commissions par métier ou objet en or, argent et cuivre.
- Choix d’afficher ou non les noms des joueurs alliés à côté des icônes de métier, dont la taille évolue désormais en douceur avec la distance.
- Amélioration des performances dans les grandes guildes, de la mémorisation de la disponibilité et de la fiabilité des liens de métier.
- Ajout de guides pour l’artisanat et la découverte, consultables à tout moment, et traduction de l’interface dans les dix langues prises en charge.]]

L.CHANGELOG_ENTRY_FOREVER_0_2_0 = [[### Ajouté
- Annuaire autonome avec recherche d’artisans, favoris et liens de métier.
- Gestion des commissions, notes et disponibilités par métier ou recette depuis la fenêtre d’artisanat.
- Annonces pour les métiers analysés de vos personnages, import et export de profils d’artisans.
- Repérage des artisans à proximité grâce aux icônes de métier au-dessus des joueurs alliés.]]

L.FOREVER_DEMO_HELP = "/af demo [on|off] - affiche les icônes de métier sur une cible alliée ou vous-même pendant cinq minutes."
L.FOREVER_DEMO_STARTED = "Icônes de démonstration activées pour %s pendant cinq minutes. Elles apparaissent hors combat et hors instance. /af demo off pour arrêter."
L.FOREVER_DEMO_STOPPED = "Démonstration des icônes arrêtée."
L.FOREVER_DEMO_NO_NAME = "Aucun nom de joueur disponible pour la démonstration."

L.FOREVER_PRICE = "Prix"
L.FOREVER_PRICE_ITEM = "Commission de l’objet"
L.FOREVER_PRICE_DEFAULT = "Tarif du métier"
L.FOREVER_PRICE_UNKNOWN = "Commission non partagée. Contactez l’artisan pour un devis."

L.FOREVER_NO_KNOWN_CRAFTS = "Aucune recette partagée connue."
L.FOREVER_NO_DEFAULT_NOTE = "Aucune note de métier partagée."
L.FOREVER_RECIPE_ID = "Recette n°%d"

L.FOREVER_SEARCH_ALL = "Rechercher un artisan, métier ou objet"
L.FOREVER_SEARCH_ALL_HELP = "Filtrez par artisan, métier ou objet connu. Entrée pour rechercher un objet par nom, identifiant ou lien, ou glissez un objet ici."

L.FOREVER_COIN_GOLD = "Or"
L.FOREVER_COIN_SILVER = "Argent"
L.FOREVER_COIN_COPPER = "Cuivre"
L.FOREVER_COIN_HELP = "Saisissez des pièces entières (0 à 99 pour l’argent et le cuivre). Laissez les champs vides pour ne pas fixer de commission ou hériter du tarif du métier. Saisissez -1 en Or pour accepter toute commission."

L.COMMISSION_HELP_POSITIVE = "Fixez la commission en or, argent et cuivre. Argent et cuivre : de 0 à 99."
L.COMMISSION_HELP_FREE = "Saisissez -1 dans le champ Or : commission libre."
L.COMMISSION_INVALID = "Saisissez des montants entiers en or, argent et cuivre (0 à 99 pour argent et cuivre), ou -1 en Or pour une commission libre."

L.FOREVER_SORT = "Trier les artisans"
L.FOREVER_SORT_HINT = "Cliquez pour trier selon cette colonne. Cliquez à nouveau pour inverser l’ordre."

L.FOREVER_TRACK_MATERIALS = "Suivre les composants"

L.FOREVER_TRACK_MATERIALS_HELP = "Suivre les composants de cette fabrication dans les objectifs de quête. À l’hôtel des ventes, rechercher les composants manquants avec Auctionator."

L.FOREVER_MATERIALS_UNAVAILABLE = "Les composants nécessaires ne sont pas disponibles. Ouvrez le lien de métier de l’artisan ou analysez la recette, puis réessayez."

L.FOREVER_HOURS_AGO = "il y a %d h"

L.FOREVER_DAYS_AGO = "il y a %d j"

L.FOREVER_MONTHS_AGO = "il y a %d mois"

L.FOREVER_YEARS_AGO = "il y a %d an(s)"

L.FOREVER_DISCOVERY_OPTIONS = "Découverte"
L.OPTIONS_SHOW_OWN_CHARACTER_ROWS_DESC = "Inclure votre personnage actuel dans la découverte lorsqu’il peut fabriquer un objet correspondant."

L.FOREVER_SHOW_FRIENDLY_NAMES = "Afficher les noms des joueurs alliés"
L.FOREVER_FRIENDLY_NAMES_QUESTION = "Souhaitez-vous afficher les noms des joueurs alliés à côté des icônes de métier d’ArtisanFinder ? Vous pourrez modifier ce choix dans les réglages d’ArtisanFinder."

L.FOREVER_ADVERTISE_PROFESSION = "Annoncer ce métier"
L.FOREVER_ADVERTISE_PROFESSION_HELP = "Activer ou désactiver les annonces pour ce métier dans ArtisanFinder."

L.FOREVER_TUTORIAL_SEARCH = "Recherchez un artisan, un métier ou un objet connu. Appuyez sur Entrée pour rechercher un objet par nom, identifiant ou lien, ou glissez un objet dans le champ."
L.FOREVER_TUTORIAL_HEADERS = "Les icônes de filtre permettent de choisir les métiers et les sources. Cliquez sur Artisan, Découvert via, Prix ou Dernière observation pour trier, puis à nouveau pour inverser l’ordre. Les favoris restent en tête."
L.FOREVER_TUTORIAL_ROWS = "Cliquez sur un artisan pour afficher ses métiers et niveaux, puis sur un métier pour voir les recettes connues. Survolez les lignes pour les notes et actions. L’étoile ajoute aux favoris ; le lien de métier et le chuchotement permettent de contacter l’artisan. Suivre les composants crée une liste de matériaux. Le tarif du métier est utilisé sauf si un objet a son propre tarif."
L.FOREVER_TUTORIAL_PAGES = "Utilisez les flèches pour changer de page. Faites défiler le tableau pour voir les métiers et recettes dépliés."
L.FOREVER_TUTORIAL_RESET = "Tutoriels réinitialisés. Ouvrez la découverte ou un métier pour revoir le guide. Les icônes d’information permettent toujours de rouvrir l’aide."

L.FOREVER_TUTORIAL_END_HINT = "Cliquez à nouveau sur cette icône d’information pour terminer le tutoriel."
