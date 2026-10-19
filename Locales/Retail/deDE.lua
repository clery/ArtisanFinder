local _, AF = ...
local L = AF.Locales.deDE


L.CHANGELOG_ENTRY_2_1_5 = [[### Geändert
- ArtisanFinder unterstützt jetzt Retail und WoW Forever mit demselben Download und jeweils angepassten Funktionen.]]

L.CHANGELOG_ENTRY_2_1_4 = [[### Geändert

* Die Interface-Version wurde für World of Warcraft Patch 12.1.5 aktualisiert.]]
L.CHANGELOG_ENTRY_2_1_3 = [[### Geändert

* Wiederholte Berechnungen beim Prüfen veralteter Berufsscans und Anzeigen gescannter Berufe wurden reduziert, damit große Handwerkerprofile schneller reagieren.

### Behoben

* Aktionsleistenfehler nach der Auswahl von ArtisanFinder-Steuerelementen im Bearbeitungsmodus wurden behoben.
* Fehlerhafte gespeicherte Scaneinträge werden beim Erstellen von Berufslisten und Übersichten veralteter Scans nun sicher übersprungen.]]
L.CHANGELOG_ENTRY_2_1_2 = [[### Behoben

* Ermächtigte Evoker-Zauber wie Feueratem werden nicht mehr von ArtisanFinder unterbrochen.
* Die Abfrage und Listenaktualisierung von Kunden-Handwerksaufträgen laufen jetzt nur noch, wenn die Kundenauftrags-UI geöffnet ist, warten während du zauberst/kanalisierst oder eingeschränkt bist, und werden nicht mehr durch Aktualisierungsereignisse für Kundenaufträge eingereiht.]]
L.CHANGELOG_ENTRY_2_1_1 = [[### Hinzugefügt

* Reagenzienvorschauen im Berufsfenster können jetzt einen Schalter "Unbegrenzte Reagenzien" verwenden, um Qualitätsverteilungen zu simulieren, ohne jedes Reagenz zu besitzen.
* Die Steuerelemente im Berufsfenster können in den Addon-Optionen jetzt standardmäßig maximiert oder minimiert starten.

### Behoben

* Scans von Reagenzien-Fertigkeitsdaten tolerieren jetzt unvollständige Basisdaten, statt fehlzuschlagen.
* Die Verarbeitung der Berufsscan-Warteschlange beendet sich jetzt sicher, wenn Scanfortschrittsdaten fehlen oder fehlerhaft sind.
* Die Auswertung von Handelslink-Berufen ignoriert fehlerhafte numerische Tokens jetzt sicher.]]
L.CHANGELOG_ENTRY_2_1_0 = [[### Hinzugefügt

* Handwerker-Import/-Export bietet eine Möglichkeit, Handwerker eines anderen Accounts zusätzlich zu deinem Hauptaccount zu bewerben.
* Auftrag vorbereiten hat jetzt einen erweiterten Modus, mit dem Kunden die Qualitäten benötigter Reagenzien und optionale Reagenzien vor dem Verfolgen einer Herstellung auswählen können.
* ArtisanFinder kann jetzt die erwartete Herstellungsqualität aus der ausgewählten Reagenzienkonfiguration schätzen und Reagenzienkombinationen vorschlagen, die das beste bekannte Ergebnis erreichen, ohne immer automatisch Materialien höchster Qualität zu verwenden.

### Geändert

* Berufsscans speichern jetzt die Reagenzien-Fertigkeitsdaten, die für zuverlässige kundenseitige Qualitätssimulation, Empfehlungen und erweiterte Vorbereitung nötig sind. Ältere Scan-Datensätze, die das neue Modell nicht unterstützen, werden gelöscht oder als veraltet markiert, damit Spieler wissen, welche Charaktere einen neuen Scan brauchen.
* Durch Klicken auf eine passende Kundenzeile können verfolgte Herstellungsmaterialien aus dem Objective Tracker jetzt in das Handwerksauftragsformular übernommen werden.

### Behoben

* Das Öffnen eines Berufs sollte keinen deutlichen FPS-Einbruch mehr verursachen.
* Gildenmitglieder, die einen Gegenstand herstellen können, zeigen jetzt ihren echten Onlinestatus, statt immer als offline zu erscheinen.
* Handelschat-Funktionen funktionieren jetzt auf russischen Spielclients.
* Vollständige Berufsscans verteilen ihre Arbeit jetzt gleichmäßiger, mit weniger Einfrieren und Ruckeln bei großen Berufen.]]
L.CHANGELOG_ENTRY_2_0_5 = [[### Hinzugefügt

* Kundenzeilen enthalten jetzt Aktionen zum Vorbereiten von Aufträgen für Standardherstellungen und Herstellungen mit optionalen Reagenzien.
* Vorbereitete Herstellungen werden im Objective Tracker mit benötigten Komponenten, ausgewählten optionalen Reagenzien, benötigter Menge, vorhandener und fehlender Anzahl sowie Qualitätsmarkierungen verfolgt.
* Auktionshaussuchen aus vorbereiteten Herstellungen verwenden jetzt temporäre Auctionator-Mehrfachsuchen, wenn Auctionator aktiviert ist.

### Geändert

* Die Schaltflächen "Persönlicher Auftrag" und "Gildenauftrag" wurden entfernt, damit ein einfacher Klick auf eine Handwerkerzeile das Formular links automatisch ausfüllt.]]
L.CHANGELOG_ENTRY_2_0_3 = [[### Behoben

* Flüsterversuch bei Patron-Auftrags-NSCs oder Twink-Charakteren beim Abschluss eines Handwerksauftrags.]]
L.CHANGELOG_ENTRY_2_0_2 = [[### Hinzugefügt

* Benachrichtigungen für Kunden, wenn ein Handwerksauftrag erfüllt wurde.]]
L.CHANGELOG_ENTRY_2_0_1 = [[### Hinzugefügt

* Lokalisierung für vereinfachtes Chinesisch, lateinamerikanisches Spanisch, Portugiesisch und brasilianisches Portugiesisch.

### Geändert

* Kleine Kommunikationsoptimierungen.
* Addon-Nachrichtenkommunikation ist jetzt komprimiert.

### Behoben

* Kleines Speicherleck bei langen Sitzungen.]]

L.OPTIONS_SECTION_NOTIFICATIONS = "Benachrichtigungen"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS = "Auftragsbenachrichtigungen eigener Twinks von dir ausblenden"
L.OPTIONS_HIDE_SELF_ALT_ORDER_NOTIFICATIONS_DESC = "Blendet Benachrichtigungen über persönliche Aufträge für deine Twinks aus, wenn sie von einem deiner Charaktere gesendet wurden."
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS = "Erfüllte Aufträge eigener Twinks von dir ausblenden"
L.OPTIONS_HIDE_SELF_ALT_FULFILLED_NOTIFICATIONS_DESC = "Blendet Benachrichtigungen über erfüllte Kundenaufträge aus, wenn sie von einem deiner Charaktere gesendet wurden."
L.OPTIONS_ORDER_SOUND = "Ton für Auftragsbenachrichtigungen"
L.OPTIONS_ORDER_SOUND_DESC = "Wähle den Ton für Auftragsbenachrichtigungen."
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED = "Ton für Auftragsbenachrichtigungen aktivieren"
L.OPTIONS_ORDER_NOTIFICATION_SOUND_ENABLED_DESC = "Spielt einen Ton für persönliche Aufträge und erfüllte Kundenaufträge ab."
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED = "Banner für Auftragsbenachrichtigungen aktivieren"
L.OPTIONS_ORDER_NOTIFICATION_BANNER_ENABLED_DESC = "Zeigt ein Bildschirmbanner für persönliche Aufträge und erfüllte Kundenaufträge."
L.OPTIONS_ORDER_SOUND_CATALOG_SHOP_OPEN = "Shopfenster öffnen"
L.OPTIONS_ORDER_SOUND_STORE_DELIVERY = "Shop-Lieferbenachrichtigung"
L.OPTIONS_ORDER_SOUND_STORE_OPEN = "Shopfenster"
L.OPTIONS_ORDER_SOUND_BNET_TOAST = "Battle.net-Benachrichtigung"
L.OPTIONS_ORDER_SOUND_PROFESSION_TOAST = "Berufsbenachrichtigung"
L.OPTIONS_ORDER_SOUND_EVENT_SCHEDULER_CHIME = "Kalenderklang"
L.OPTIONS_ORDER_SOUND_GARRISON_WORK_ORDER = "Arbeitsauftrag starten"
L.OPTIONS_ORDER_SOUND_BACKPACK_COIN = "Münzauswahl"
L.OPTIONS_ORDER_SOUND_SOULBIND = "Seelenbandaktivierung"
L.OPTIONS_ORDER_SOUND_GM_CHAT_WARNING = "GM-Chatwarnung"
L.OPTIONS_ORDER_SOUND_READY_CHECK = "Bereitschaftscheck"
L.OPTIONS_ORDER_SOUND_AUCTION = "Auktionshaus"
L.OPTIONS_ORDER_SOUND_CHANNEL = "Tonkanal"
L.OPTIONS_ORDER_SOUND_CHANNEL_DESC = "Wähle, welcher Spieltonkanal Auftragsbenachrichtigungen abspielt."
L.OPTIONS_SOUND_CHANNEL_DEFAULT = "Master"
L.OPTIONS_SOUND_CHANNEL_SFX = "Soundeffekte"
L.OPTIONS_SOUND_CHANNEL_MUSIC = "Musik"
L.OPTIONS_SOUND_CHANNEL_AMBIENCE = "Umgebung"
L.OPTIONS_SOUND_CHANNEL_DIALOG = "Dialog"
L.OPTIONS_PLAY_ORDER_SOUND = "Ton abspielen"
L.OPTIONS_PLAY_ORDER_SOUND_DESC = "Spielt den ausgewählten Ton für Auftragsbenachrichtigungen ab."
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS = "Benachrichtigungen löschen"
L.OPTIONS_CLEAR_ORDER_NOTIFICATIONS_DESC = "Löscht gespeicherte Benachrichtigungen für persönliche Aufträge."

L.TUTORIAL_RESET_DONE = "Tutorial zurückgesetzt."
L.TUTORIAL_INTRO = "ArtisanFinder funktioniert an zwei Stellen. Öffne jeden deiner Berufe einmal, damit die Handwerksdaten gescannt werden. Besuche danach den NSC für Handwerksaufträge, um beim Erstellen eines Auftrags verfügbare Handwerker zu sehen."
L.TUTORIAL_MINIMAP_BUTTON = "Nutze die Minimap-Schaltfläche, um ArtisanFinder schnell zu steuern.\nLinksklick schaltet Verfügbarkeit um, Mittelklick die Auto-Verfügbarkeit, Rechtsklick öffnet Optionen und Umschalt-Klick blendet die Schaltfläche aus."
L.TUTORIAL_CUSTOMER_STATUS = "Wähle im Handwerksauftragsformular einen Auftragsgegenstand aus. Danach sucht ArtisanFinder passende Handwerker."
L.TUTORIAL_CUSTOMER_SEARCH = "Filtere, sortiere oder aktualisiere die Ergebnisse für den ausgewählten Gegenstand."
L.TUTORIAL_CUSTOMER_ROW = "Zeilen zeigen Kommission, Qualität, Verfügbarkeit, Gilden- oder Handelschat-Quelle und die Notiz des Handwerkers."
L.TUTORIAL_CUSTOMER_ACTION = "Klicke auf eine echte Zeile, um das Kundenauftragsformular automatisch auszufüllen.\n\nÖffne das Zeilenmenü, um einen Handwerker zu favorisieren, anzuflüstern oder seinen Beruf zu öffnen, wenn verfügbar."
L.TUTORIAL_PROFESSION_NAME = "Tutorial"

L.CUSTOMER_SIDE_PREVIEW = "Kundenvorschau"
L.CUSTOMER_SIDE_PREVIEW_EMPTY = "Für diese Zeile sind noch keine kundensichtbaren Daten gespeichert."
L.CUSTOMER_SIDE_PREVIEW_SCANNING = "Diese Herstellung wird gescannt. Die Kundenvorschau wird nach Abschluss des Scans aktualisiert."
L.TUTORIAL_CRAFTER_PREVIEW = "Fahre über das Kundenvorschau-Symbol, um zu sehen, was Kunden für den ausgewählten Gegenstand sehen, einschließlich gegenstandsspezifischer Werte zusammen mit Berufsstandards."

L.CHANGELOG_ENTRY_2_2_0 = [[### Behoben
- Benachrichtigungen zu persönlichen Aufträgen enthalten jetzt Rezept- und Berufskennungen, damit Gegenstands- und Berufsnamen in der Sprache des Empfängers angezeigt werden können.
- Zu große ältere Benachrichtigungen behalten ihre Kennungen und verzichten auf Ersatznamen. Überschreiten sie weiterhin das Nachrichtenlimit, wird der Versand sicher abgebrochen.
- Aktualisierte Gegenstandsdaten erneuern nur die betroffenen Fenster und verfolgten Herstellungsvorgänge und vermeiden so unnötige Verarbeitung.]]
