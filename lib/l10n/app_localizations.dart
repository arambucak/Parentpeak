import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const localizationsDelegates = [delegate];
  static const supportedLocales = [
    Locale('en'),
    Locale('de'),
    Locale('ar'),
    Locale('fa'),
    Locale('ku'),
    Locale('ckb'),
    Locale('fr'),
    Locale('es'),
    Locale('it'),
    Locale('pt'),
    Locale('nl'),
    Locale('pl'),
    Locale('tr'),
    Locale('ja'),
    Locale('zh'),
    Locale('hi'),
  ];

  Map<String, String> _stringsForLocale() =>
      _localizedValues[locale.languageCode] ?? _localizedValues['en']!;

  String get appTitle => _stringsForLocale()['appTitle'] ?? 'Parentpeak';
  String get trustedDevicesTitle =>
      _stringsForLocale()['trustedDevicesTitle'] ?? 'Trusted Devices';
  String get removeDeviceDialogTitle =>
      _stringsForLocale()['removeDeviceDialogTitle'] ??
      'Remove device and delete data?';
  String removeDeviceDialogMessage(String deviceName) =>
      (_stringsForLocale()['removeDeviceDialogMessage'] ??
              'Remove {deviceName}?')
          .replaceAll('{deviceName}', deviceName);
  String get deviceNameLabel =>
      _stringsForLocale()['deviceNameLabel'] ?? 'Enter device name';
  String get deviceNameHelper =>
      _stringsForLocale()['deviceNameHelper'] ?? 'Enter the exact device name';
  String get cancel => _stringsForLocale()['cancel'] ?? 'Cancel';
  String get removeDevice =>
      _stringsForLocale()['removeDevice'] ?? 'Remove device';
  String get deviceRemoved =>
      _stringsForLocale()['deviceRemoved'] ?? 'Device removed successfully.';
  String get deviceRemoveError =>
      _stringsForLocale()['deviceRemoveError'] ?? 'Failed to remove device.';
  String get cannotRemovePriority =>
      _stringsForLocale()['cannotRemovePriority'] ??
      'This device cannot be removed.';
  String removedAt(String date) =>
      (_stringsForLocale()['removedAt'] ?? 'Removed at: {date}')
          .replaceAll('{date}', date);

  String t(String key, {String? fallback}) =>
      _stringsForLocale()[key] ?? fallback ?? key;

  String tFormat(
    String key,
    Map<String, String> placeholders, {
    String? fallback,
  }) {
    var value = _stringsForLocale()[key] ?? fallback ?? key;
    placeholders.forEach((name, replacement) {
      value = value.replaceAll('{$name}', replacement);
    });
    return value;
  }

  // New MVP strings
  String get chatTitle => _stringsForLocale()['chatTitle'] ?? 'Chat';
  String get chatLabel => _stringsForLocale()['chatLabel'] ?? 'Chat';
  String get calendarTitle =>
      _stringsForLocale()['calendarTitle'] ?? 'Calendar';
  String get calendarLabel =>
      _stringsForLocale()['calendarLabel'] ?? 'Calendar';
  String get devicesLabel => _stringsForLocale()['devicesLabel'] ?? 'Devices';
  String get messageHint =>
      _stringsForLocale()['messageHint'] ?? 'Write a supportive message…';
  String get send => _stringsForLocale()['send'] ?? 'Send';
  String get noMessages =>
      _stringsForLocale()['noMessages'] ?? 'No messages yet';
  String get addEvent => _stringsForLocale()['addEvent'] ?? 'Add event';
  String get noEvents => _stringsForLocale()['noEvents'] ?? 'No events yet';

  // FamilyWall inspired features
  String get locationTitle =>
      _stringsForLocale()['locationTitle'] ?? 'Location';
  String get locationLabel =>
      _stringsForLocale()['locationLabel'] ?? 'Location';
  String get todoTitle => _stringsForLocale()['todoTitle'] ?? 'To-Do';
  String get todoLabel => _stringsForLocale()['todoLabel'] ?? 'To-Do';
  String get shoppingTitle =>
      _stringsForLocale()['shoppingTitle'] ?? 'Shopping';
  String get shoppingLabel =>
      _stringsForLocale()['shoppingLabel'] ?? 'Shopping';
  String get photosTitle => _stringsForLocale()['photosTitle'] ?? 'Photos';
  String get photosLabel => _stringsForLocale()['photosLabel'] ?? 'Photos';
  String get contactsTitle =>
      _stringsForLocale()['contactsTitle'] ?? 'Contacts';
  String get contactsLabel =>
      _stringsForLocale()['contactsLabel'] ?? 'Contacts';
  String get moreLabel => _stringsForLocale()['moreLabel'] ?? 'More';

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'Parentpeak',
      'trustedDevicesTitle': 'Trusted Devices',
      'removeDeviceDialogTitle': 'Remove device and delete data?',
      'removeDeviceDialogMessage':
          'You are about to remove "{deviceName}" from your Trusted Circle. This will delete local data and keys on the target device permanently. Please type the device name to confirm:',
      'deviceNameLabel': 'Enter device name',
      'deviceNameHelper': 'Enter the exact device name',
      'cancel': 'Cancel',
      'removeDevice': 'Remove device',
      'deviceRemoved': 'Device removed successfully.',
      'deviceRemoveError': 'Failed to remove device.',
      'cannotRemovePriority': 'This device cannot be removed.',
      'removedAt': 'Removed at: {date}',
      'chatTitle': 'Pedagogy Chat',
      'chatLabel': 'Chat',
      'calendarTitle': 'Family Calendar',
      'calendarLabel': 'Calendar',
      'devicesLabel': 'Devices',
      'messageHint': 'Write a supportive message…',
      'send': 'Send',
      'noMessages': 'No messages yet',
      'addEvent': 'Add event',
      'noEvents': 'No events yet',
      'locationTitle': 'Family Location',
      'locationLabel': 'Location',
      'todoTitle': 'To-Do List',
      'todoLabel': 'To-Do',
      'shoppingTitle': 'Shopping List',
      'shoppingLabel': 'Shopping',
      'photosTitle': 'Family Photos',
      'photosLabel': 'Photos',
      'contactsTitle': 'Emergency Contacts',
      'contactsLabel': 'Contacts',
      'moreLabel': 'More',
      'treasureTileTitle': 'Giveaway Market',
      'treasureTileSubtitle': 'Give away, exchange, meet parents',
      'treasureFeedSubtitle': 'Local, honest, easy to understand',
      'treasureFeedFilterStreet': 'On your street',
      'treasureFeedFilterWalk5': '5 minutes away',
      'treasureFeedFilterDistrict': 'In your area',
      'treasureUploadTitle': 'Share a treasure',
      'treasureUploadSubtitle': 'One photo is enough to start',
      'treasureUploadSubline': 'One photo, quick check, done',
      'treasurePhotoSectionTitle': 'Take a photo',
      'treasurePhotoSectionHint': 'Show the item just as it is right now.',
      'treasureTakePhoto': 'Take photo',
      'treasureChooseFromLibrary': 'From library',
      'treasureUseDifferentPhoto': 'Change photo',
      'treasurePhotoReady': 'Photo ready',
      'treasurePickFromGallery': 'Choose from gallery',
      'treasureAddSecondPhoto': 'Add second photo',
      'treasureAddMorePhotos': 'More photos',
      'treasurePhotoGalleryHint': 'Choose a cover image or remove extras.',
      'treasureCoverPhotoLabel': 'Cover',
      'treasureOpenGallery': 'Open gallery',
      'treasurePhotoCount': '{count} photos',
      'treasureAiTitle': 'Quickly recognized',
      'treasureAiHelper': 'We suggest category and color right away.',
      'treasureAiAccept': 'Use suggestion',
      'treasureAiEdit': 'Adjust',
      'treasureCategoryVehicles': 'Vehicles',
      'treasureTitleLabel': 'Title',
      'treasureTitlePlaceholder': 'e.g. Red balance bike',
      'treasureColorLabel': 'Color',
      'treasureColorPlaceholder': 'e.g. Red, sage, natural wood',
      'treasureDistanceLabel': 'Distance',
      'treasureDistanceHelper':
          'This helps nearby families quickly decide whether it fits their day.',
      'treasurePreviewTitle': 'Aero feed preview',
      'treasureSizeAgePlaceholder': 'e.g. size 92 or age 2 to 3 years',
      'treasureConditionHelper': 'Honest is perfect.',
      'treasureConditionLikeNew': 'Studio condition',
      'treasureConditionGood': 'Round 2',
      'treasureConditionRaider': 'Wild mode',
      'treasureConditionLikeNewHint': 'Very well kept, almost like new.',
      'treasureConditionGoodHint': 'Clearly used, fully ready to go.',
      'treasureConditionRaiderHint':
          'Shows signs of use, but ready for the next adventure.',
      'treasureOptionalNoteLabel': 'Short note',
      'treasureOptionalNotePlaceholder': 'e.g. Size 92, fits a bit smaller.',
      'treasureOptionalNoteHelper':
          'One honest sentence helps nearby families immediately.',
      'treasureRecordVoiceNote': 'Record',
      'treasureVoiceProcessing': 'Turning voice into text...',
      'treasureVoiceAutofillHint':
          'We turn your note into a ready-to-share first draft.',
      'treasurePreviewNoteLabel': 'Family note',
      'treasureReserveTitle': 'Plan handover',
      'treasureReserveAndPickup': 'View & save',
      'treasureHandoverCoffeeMode': 'Quick meetup',
      'treasureHandoverCoffeeModeText': 'Quick hello, hand over, done.',
      'treasureHandoverFlyingSwap': 'Quiet swap',
      'treasureHandoverFlyingSwapText':
          'Contact-free pickup when it suits you.',
      'treasureReserveCoffeeMode': 'Save meetup',
      'treasureReserveFlyingSwap': 'Save quiet swap',
      'treasureTimeWindowLabel': 'Available times',
      'treasureContactlessPointLabel': 'Pickup spot',
      'treasureHandoverQuestion': 'How do you want to hand over?',
      'treasureGuidelineHonest':
          'Share honestly instead of aiming for perfection.',
      'treasureGuidelineNoPressure': 'Signs of use are completely okay.',
      'treasureGuidelineTempo': 'You choose: quick meetup or quiet swap.',
      'treasureGuidelineCommunity':
          'That makes sharing in the neighborhood feel easy.',
      'treasureMonthlyFamiliesHelped':
          'You have made {count} families in your neighborhood happy this month.',
      'treasureNextHandoverSample':
          'Next handover: Sunday, 10:30 AM with Altun family (Coffee mode)',
      'treasureColorLine': 'Color: {color}',
      'treasureListedAgoLine': 'Listed: {time}',
      'treasureDateOrSwap': 'Quick meetup or quiet swap',
      'treasureCoffeeQuickTitle': 'Quick coffee meetup',
      'treasureContactlessNoPressure': 'Contactless pickup with no pressure',
      'treasureReserveSuccess': 'Reservation confirmed. Happy sharing.',
      'treasureUploadSuccess': 'Your treasure is now visible.',
      'treasureDraftSaved': 'Draft saved. You can continue later.',
      'treasureDraftRestored': 'Your last draft is ready again.',
      'treasureDraftDiscarded': 'Draft discarded.',
      'treasureDiscardDraftTitle': 'Discard draft?',
      'treasureDiscardDraftText':
          'Your current form state and saved local draft will be removed.',
      'treasurePhotoAdded': 'Photo added.',
      'treasureVoiceNoteSaved': 'Note added.',
      'treasureFeedEmptyTitle': 'No treasures near you yet',
      'treasureFeedEmptyText':
          'Start with the first item your family is ready to pass on.',
      'treasureShareFirstCta': 'Share something now',
      'treasureMyItemsEmptyTitle': 'You have not listed anything yet',
      'treasureMyItemsEmptyText': 'One photo is enough to get started.',
      'treasureNoResultsTitle': 'Nothing suitable right now',
      'treasureNoResultsText': 'Try a wider distance or check again later.',
      'treasureNetworkError':
          'Connection was interrupted. Please try again in a moment.',
      'treasureUploadFailed':
          'Upload failed for the moment. Your draft is still safe.',
      'treasurePhotoMissing':
          'Add a photo first so families can instantly see what you are sharing.',
      'treasurePhotoRequired': 'Please add at least one photo.',
      'treasureConditionRequired': 'Please select a condition.',
      'treasureCategoryRequired': 'Please select a category.',
      'treasureSizeAgeRequired': 'Please add size or age.',
      'treasureFilterAll': 'All',
      'treasureFilterDistanceAll': 'Any distance',
      'treasureFilterDistance250': 'Up to 250 m',
      'treasureFilterDistance500': 'Up to 500 m',
      'treasureSelectedForHandover': 'Saved',
      'treasureFreshToday': 'New today',
      'treasureJustListed': 'Just listed',
      'treasureMinutesAgoShort': '{count} min ago',
      'treasureHoursAgoShort': '{count}h ago',
      'treasureSelectForHandover': 'Select for handover',
      'treasureDetailSectionAbout': 'What to know',
      'treasureDetailSectionPickup': 'Pickup & handover',
      'treasureDetailSelectedHint':
          'This treasure is currently selected for your handover.',
      'treasureSelectionConfirmed':
          '{title} is now selected for your handover.',
      'treasureReservationPrepared': '{title}: {mode} - {detail}',
      'treasureSlotSunday': 'Sunday, 10:00 - 11:30 AM',
      'treasureSlotMonday': 'Monday, 5:30 - 6:15 PM',
      'treasureSlotTuesday': 'Tuesday, 8:15 - 8:45 AM',
      'treasureDropRetterBox': 'Rescue box in front of the house',
      'treasureDropKitaLocker': 'Daycare wardrobe (slot "Seagull")',
      'treasureDropMailbox': 'Mailbox box at the entrance',
    },
    'de': {
      'appTitle': 'Parentpeak',
      'trustedDevicesTitle': 'Vertrauenswürdige Geräte',
      'removeDeviceDialogTitle': 'Gerät entfernen und Daten löschen?',
      'removeDeviceDialogMessage':
          'Sie entfernen das Gerät "{deviceName}" aus Ihrem Trusted Circle. Dies löscht alle lokal gespeicherten Daten und Schlüssel auf dem Zielgerät unwiderruflich. Bitte geben Sie den Gerätenamen zur Bestätigung ein:',
      'deviceNameLabel': 'Gerätename eingeben',
      'deviceNameHelper': 'Geben Sie den Gerätenamen exakt ein',
      'cancel': 'Abbrechen',
      'removeDevice': 'Gerät entfernen',
      'deviceRemoved': 'Gerät erfolgreich entfernt.',
      'deviceRemoveError': 'Fehler beim Entfernen des Geräts.',
      'cannotRemovePriority': 'Dieses Gerät kann nicht entfernt werden.',
      'removedAt': 'Entfernt am: {date}',
      'chatTitle': 'Pädagogik-Chat',
      'chatLabel': 'Chat',
      'calendarTitle': 'Familienkalender',
      'calendarLabel': 'Kalender',
      'devicesLabel': 'Geräte',
      'messageHint': 'Schreibe eine unterstützende Nachricht…',
      'send': 'Senden',
      'noMessages': 'Noch keine Nachrichten',
      'addEvent': 'Termin hinzufügen',
      'noEvents': 'Noch keine Termine',
      'locationTitle': 'Familien-Standorte',
      'locationLabel': 'Standort',
      'todoTitle': 'Aufgabenliste',
      'todoLabel': 'To-Do',
      'shoppingTitle': 'Einkaufsliste',
      'shoppingLabel': 'Einkauf',
      'photosTitle': 'Familienfotos',
      'photosLabel': 'Fotos',
      'contactsTitle': 'Notfallkontakte',
      'contactsLabel': 'Kontakte',
      'moreLabel': 'Mehr',
      'treasureTileTitle': 'Verschenkmarkt',
      'treasureTileSubtitle': 'Verschenken, austauschen, Eltern verbinden',
      'treasureFeedSubtitle': 'Lokal, ehrlich, sofort verständlich',
      'treasureFeedFilterStreet': 'In deiner Straße',
      'treasureFeedFilterWalk5': '5 Gehminuten',
      'treasureFeedFilterDistrict': 'Im Viertel',
      'treasureUploadTitle': 'Schatz teilen',
      'treasureUploadSubtitle': 'Ein Foto reicht für den Start',
      'treasureUploadSubline': 'Ein Foto, kurzer Check, fertig',
      'treasurePhotoSectionTitle': 'Foto aufnehmen',
      'treasurePhotoSectionHint':
          'Zeig den Gegenstand einfach so, wie er gerade ist.',
      'treasureTakePhoto': 'Foto machen',
      'treasureChooseFromLibrary': 'Aus Mediathek',
      'treasureUseDifferentPhoto': 'Foto wechseln',
      'treasurePhotoReady': 'Foto bereit',
      'treasurePickFromGallery': 'Aus Galerie wählen',
      'treasureAddSecondPhoto': 'Zweites Foto hinzufügen',
      'treasureAddMorePhotos': 'Mehr Fotos',
      'treasurePhotoGalleryHint': 'Wähle ein Coverbild oder entferne Extras.',
      'treasureCoverPhotoLabel': 'Cover',
      'treasureOpenGallery': 'Galerie öffnen',
      'treasurePhotoCount': '{count} Fotos',
      'treasureAiTitle': 'Schnell erkannt',
      'treasureAiHelper': 'Wir schlagen dir Kategorie und Farbe direkt vor.',
      'treasureAiAccept': 'Übernehmen',
      'treasureAiEdit': 'Anpassen',
      'treasureCategoryVehicles': 'Fahrzeuge',
      'treasureTitleLabel': 'Titel',
      'treasureTitlePlaceholder': 'z. B. Rotes Laufrad',
      'treasureColorLabel': 'Farbe',
      'treasureColorPlaceholder': 'z. B. Rot, Salbei, Naturholz',
      'treasureDistanceLabel': 'Entfernung',
      'treasureDistanceHelper':
          'So schnell kann jemand aus der Nähe einschätzen, ob es gerade passt.',
      'treasurePreviewTitle': 'Feed-Vorschau',
      'treasureSizeAgePlaceholder': 'z. B. Größe 92 oder 2 bis 3 Jahre',
      'treasureConditionHelper': 'Ehrlich ist perfekt.',
      'treasureConditionLikeNew': 'Wie neu',
      'treasureConditionGood': 'Gut genutzt',
      'treasureConditionRaider': 'Mit Spuren',
      'treasureConditionLikeNewHint': 'Sehr gepflegt, fast wie neu.',
      'treasureConditionGoodHint': 'Sichtbar genutzt, voll einsatzbereit.',
      'treasureConditionRaiderHint':
          'Mit Spuren, aber bereit fürs nächste Abenteuer.',
      'treasureOptionalNoteLabel': 'Kurze Notiz',
      'treasureOptionalNotePlaceholder':
          'z. B. Größe 92, fällt eher kleiner aus.',
      'treasureOptionalNoteHelper':
          'Ein ehrlicher Satz hilft anderen Familien sofort weiter.',
      'treasureRecordVoiceNote': 'Einsprechen',
      'treasureVoiceProcessing': 'Wird in Text umgewandelt...',
      'treasureVoiceAutofillHint':
          'Wir wandeln deine Notiz in einen startklaren Text um.',
      'treasurePreviewNoteLabel': 'Familien-Hinweis',
      'treasureReserveTitle': 'Übergabe planen',
      'treasureReserveAndPickup': 'Ansehen & sichern',
      'treasureHandoverCoffeeMode': 'Kurz treffen',
      'treasureHandoverCoffeeModeText': 'Kurz hallo, übergeben, fertig.',
      'treasureHandoverFlyingSwap': 'Still tauschen',
      'treasureHandoverFlyingSwapText': 'Kontaktlos abholen, wenn es passt.',
      'treasureReserveCoffeeMode': 'Treffen sichern',
      'treasureReserveFlyingSwap': 'Stillen Tausch sichern',
      'treasureTimeWindowLabel': 'Verfügbare Zeiten',
      'treasureContactlessPointLabel': 'Abholpunkt',
      'treasureHandoverQuestion': 'Wie wollt ihr übergeben?',
      'treasureGuidelineHonest': 'Ehrlich teilen statt perfekt inszenieren.',
      'treasureGuidelineNoPressure': 'Gebrauchsspuren sind okay.',
      'treasureGuidelineTempo':
          'Ihr entscheidet: kurz treffen oder still tauschen.',
      'treasureGuidelineCommunity': 'So wird Teilen im Viertel leicht.',
      'treasureMonthlyFamiliesHelped':
          'Du hast diesen Monat schon {count} Familien in deiner Nachbarschaft glücklich gemacht.',
      'treasureNextHandoverSample':
          'Nächste Übergabe: Sonntag, 10:30 Uhr bei Familie Altun (Kaffee-Modus)',
      'treasureColorLine': 'Farbe: {color}',
      'treasureListedAgoLine': 'Eingestellt: {time}',
      'treasureDateOrSwap': 'Kurz treffen oder still tauschen',
      'treasureCoffeeQuickTitle': 'Kurz treffen',
      'treasureContactlessNoPressure': 'Ganz ohne Druck',
      'treasureReserveSuccess':
          'Reservierung bestätigt. Viel Freude beim Tauschen.',
      'treasureUploadSuccess': 'Dein Schatz ist jetzt sichtbar.',
      'treasureDraftSaved':
          'Entwurf gespeichert. Du kannst später weitermachen.',
      'treasureDraftRestored': 'Dein letzter Entwurf ist wieder da.',
      'treasureDraftDiscarded': 'Entwurf verworfen.',
      'treasureDiscardDraftTitle': 'Entwurf verwerfen?',
      'treasureDiscardDraftText':
          'Dein aktueller Formularstand und der lokal gespeicherte Entwurf werden entfernt.',
      'treasurePhotoAdded': 'Foto hinzugefügt.',
      'treasureVoiceNoteSaved': 'Notiz übernommen.',
      'treasureFeedEmptyTitle': 'Noch keine Schätze in deiner Nähe',
      'treasureFeedEmptyText':
          'Starte einfach mit dem ersten Teil, das bei euch weiterziehen darf.',
      'treasureShareFirstCta': 'Jetzt etwas teilen',
      'treasureMyItemsEmptyTitle': 'Du hast noch nichts eingestellt',
      'treasureMyItemsEmptyText': 'Ein Foto genügt, um loszulegen.',
      'treasureNoResultsTitle': 'Gerade nichts Passendes dabei',
      'treasureNoResultsText':
          'Versuch es mit einer größeren Entfernung oder schau später nochmal rein.',
      'treasureNetworkError':
          'Die Verbindung war kurz weg. Versuch es gleich nochmal.',
      'treasureUploadFailed':
          'Das Hochladen hat gerade nicht geklappt. Dein Entwurf bleibt erhalten.',
      'treasurePhotoMissing':
          'Füge zuerst ein Foto hinzu, damit Familien sofort sehen, worum es geht.',
      'treasurePhotoRequired': 'Bitte füge mindestens ein Foto hinzu.',
      'treasureConditionRequired': 'Bitte wähle einen Zustand aus.',
      'treasureCategoryRequired': 'Bitte wähle eine Kategorie aus.',
      'treasureSizeAgeRequired': 'Bitte ergänze Größe oder Alter.',
      'treasureFilterAll': 'Alle',
      'treasureFilterDistanceAll': 'Jede Distanz',
      'treasureFilterDistance250': 'Bis 250 m',
      'treasureFilterDistance500': 'Bis 500 m',
      'treasureSelectedForHandover': 'Vorgemerkt',
      'treasureFreshToday': 'Heute neu',
      'treasureJustListed': 'Gerade neu',
      'treasureMinutesAgoShort': 'vor {count} Min.',
      'treasureHoursAgoShort': 'vor {count} Std.',
      'treasureSelectForHandover': 'Für Übergabe wählen',
      'treasureDetailSectionAbout': 'Auf einen Blick',
      'treasureDetailSectionPickup': 'Abholung & Übergabe',
      'treasureDetailSelectedHint':
          'Dieser Schatz ist aktuell für deine Übergabe vorgemerkt.',
      'treasureSelectionConfirmed':
          '{title} ist jetzt für deine Übergabe vorgemerkt.',
      'treasureReservationPrepared': '{title}: {mode} - {detail}',
      'treasureSlotSunday': 'Sonntag, 10:00 - 11:30 Uhr',
      'treasureSlotMonday': 'Montag, 17:30 - 18:15 Uhr',
      'treasureSlotTuesday': 'Dienstag, 08:15 - 08:45 Uhr',
      'treasureDropRetterBox': 'Retter-Box vor der Haustür',
      'treasureDropKitaLocker': 'Kita-Garderobe (Fach "Möwe")',
      'treasureDropMailbox': 'Briefkastenbox am Eingang',
    },
    'tr': {
      'appTitle': 'Parentpeak',
      'trustedDevicesTitle': 'Güvenilir Cihazlar',
      'removeDeviceDialogTitle': 'Cihazı kaldır ve verileri sil?',
      'removeDeviceDialogMessage':
          '"{deviceName}" cihazını Güvenilir Çevrenizden kaldırmak üzeresiniz. Bu işlem hedef cihazdaki tüm yerel verileri ve anahtarları kalıcı olarak siler. Onaylamak için cihaz adını yazın:',
      'deviceNameLabel': 'Cihaz adını girin',
      'deviceNameHelper': 'Cihaz adını tam olarak girin',
      'cancel': 'İptal',
      'removeDevice': 'Cihazı kaldır',
      'deviceRemoved': 'Cihaz başarıyla kaldırıldı.',
      'deviceRemoveError': 'Cihaz kaldırılırken hata oluştu.',
      'cannotRemovePriority': 'Bu cihaz kaldırılamaz.',
      'removedAt': 'Kaldırılma tarihi: {date}',
      'chatTitle': 'Pedagoji Sohbeti',
      'chatLabel': 'Sohbet',
      'calendarTitle': 'Aile Takvimi',
      'calendarLabel': 'Takvim',
      'devicesLabel': 'Cihazlar',
      'messageHint': 'Destekleyici bir mesaj yaz…',
      'send': 'Gönder',
      'noMessages': 'Henüz mesaj yok',
      'addEvent': 'Etkinlik ekle',
      'noEvents': 'Henüz etkinlik yok',
      'locationTitle': 'Aile Konumları',
      'locationLabel': 'Konum',
      'todoTitle': 'Yapılacaklar Listesi',
      'todoLabel': 'Yapılacaklar',
      'shoppingTitle': 'Alışveriş Listesi',
      'shoppingLabel': 'Alışveriş',
      'photosTitle': 'Aile Fotoğrafları',
      'photosLabel': 'Fotoğraflar',
      'contactsTitle': 'Acil Durum Kişileri',
      'contactsLabel': 'Kişiler',
      'moreLabel': 'Daha Fazla',
      'treasureTileTitle': 'Hediye Pazarı',
      'treasureTileSubtitle': 'Hediye et, paylaş, ebeveynleri buluştur',
      'treasureFeedSubtitle': 'Yerel, dürüst, anlaşılması kolay',
      'treasureFeedFilterStreet': 'Sokağında',
      'treasureFeedFilterWalk5': '5 dakika yürüme mesafesi',
      'treasureFeedFilterDistrict': 'Mahallende',
      'treasureUploadTitle': 'Hazine paylaş',
      'treasureUploadSubtitle': 'Başlamak için bir fotoğraf yeterli',
      'treasureUploadSubline': 'Bir fotoğraf, hızlı kontrol, tamam',
      'treasurePhotoSectionTitle': 'Fotoğraf çek',
      'treasurePhotoSectionHint': 'Eşyayı olduğu gibi göster.',
      'treasureTakePhoto': 'Fotoğraf çek',
      'treasureChooseFromLibrary': 'Galeriden seç',
      'treasureUseDifferentPhoto': 'Fotoğrafı değiştir',
      'treasurePhotoReady': 'Fotoğraf hazır',
      'treasurePickFromGallery': 'Galeriden seç',
      'treasureAddSecondPhoto': 'İkinci fotoğraf ekle',
      'treasureAddMorePhotos': 'Daha fazla fotoğraf',
      'treasurePhotoGalleryHint':
          'Bir kapak resmi seç veya fazlalıkları kaldır.',
      'treasureCoverPhotoLabel': 'Kapak',
      'treasureOpenGallery': 'Galeriyi aç',
      'treasurePhotoCount': '{count} fotoğraf',
      'treasureAiTitle': 'Hızlıca tanındı',
      'treasureAiHelper': 'Kategori ve rengi hemen öneriyoruz.',
      'treasureAiAccept': 'Kabul et',
      'treasureAiEdit': 'Düzenle',
      'treasureCategoryVehicles': 'Araçlar',
      'treasureTitleLabel': 'Başlık',
      'treasureTitlePlaceholder': 'ör. Kırmızı denge bisikleti',
      'treasureColorLabel': 'Renk',
      'treasureColorPlaceholder': 'ör. Kırmızı, adaçayı yeşili, doğal ahşap',
      'treasureDistanceLabel': 'Mesafe',
      'treasureDistanceHelper':
          'Yakındaki aileler bunun kendilerine uyup uymadığını hızlıca görebilir.',
      'treasurePreviewTitle': 'Akış önizlemesi',
      'treasureSizeAgePlaceholder': 'ör. Beden 92 veya 2-3 yaş',
      'treasureConditionHelper': 'Dürüstlük mükemmeldir.',
      'treasureConditionLikeNew': 'Yeni gibi',
      'treasureConditionGood': 'İyi kullanılmış',
      'treasureConditionRaider': 'Kullanım izleri var',
      'treasureConditionLikeNewHint': 'Çok bakımlı, neredeyse yeni.',
      'treasureConditionGoodHint': 'Belli ki kullanılmış, tam işlevsel.',
      'treasureConditionRaiderHint':
          'Kullanım izleri var ama bir sonraki maceraya hazır.',
      'treasureOptionalNoteLabel': 'Kısa not',
      'treasureOptionalNotePlaceholder': 'ör. Beden 92, biraz küçük kalıyor.',
      'treasureOptionalNoteHelper':
          'Dürüst bir cümle diğer ailelere hemen yardımcı olur.',
      'treasureRecordVoiceNote': 'Sesli not',
      'treasureVoiceProcessing': 'Metne dönüştürülüyor...',
      'treasureVoiceAutofillHint':
          'Notunuzu paylaşıma hazır bir metne dönüştürüyoruz.',
      'treasurePreviewNoteLabel': 'Aile notu',
      'treasureReserveTitle': 'Teslim planla',
      'treasureReserveAndPickup': 'Görüntüle ve kaydet',
      'treasureHandoverCoffeeMode': 'Kısa buluşma',
      'treasureHandoverCoffeeModeText': 'Merhaba, teslim, tamam.',
      'treasureHandoverFlyingSwap': 'Sessiz takas',
      'treasureHandoverFlyingSwapText': 'Uygun olduğunda temassız al.',
      'treasureReserveCoffeeMode': 'Buluşmayı kaydet',
      'treasureReserveFlyingSwap': 'Sessiz takası kaydet',
      'treasureTimeWindowLabel': 'Uygun zamanlar',
      'treasureContactlessPointLabel': 'Teslim noktası',
      'treasureHandoverQuestion': 'Nasıl teslim etmek istiyorsunuz?',
      'treasureGuidelineHonest': 'Mükemmel göstermek yerine dürüstçe paylaş.',
      'treasureGuidelineNoPressure': 'Kullanım izleri sorun değil.',
      'treasureGuidelineTempo':
          'Siz karar verin: kısa buluşma veya sessiz takas.',
      'treasureGuidelineCommunity': 'Mahallede paylaşmak böyle kolaylaşır.',
      'treasureMonthlyFamiliesHelped':
          'Bu ay mahallendeki {count} aileyi mutlu ettin.',
      'treasureNextHandoverSample':
          'Sonraki teslim: Pazar, 10:30 Altun ailesi ile (Kahve modu)',
      'treasureColorLine': 'Renk: {color}',
      'treasureListedAgoLine': 'Eklenme: {time}',
      'treasureDateOrSwap': 'Kısa buluşma veya sessiz takas',
      'treasureCoffeeQuickTitle': 'Kısa buluşma',
      'treasureContactlessNoPressure': 'Hiç baskı olmadan',
      'treasureReserveSuccess':
          'Rezervasyon onaylandı. Paylaşmanın tadını çıkarın.',
      'treasureUploadSuccess': 'Hazineniz artık görünür.',
      'treasureDraftSaved':
          'Taslak kaydedildi. Daha sonra devam edebilirsiniz.',
      'treasureDraftRestored': 'Son taslağınız tekrar hazır.',
      'treasureDraftDiscarded': 'Taslak silindi.',
      'treasureDiscardDraftTitle': 'Taslağı sil?',
      'treasureDiscardDraftText':
          'Mevcut form durumunuz ve kaydedilen yerel taslak kaldırılacak.',
      'treasurePhotoAdded': 'Fotoğraf eklendi.',
      'treasureVoiceNoteSaved': 'Not eklendi.',
      'treasureFeedEmptyTitle': 'Yakınında henüz hazine yok',
      'treasureFeedEmptyText':
          'Ailenizin artık ihtiyaç duymadığı ilk eşyayla başlayın.',
      'treasureShareFirstCta': 'Şimdi bir şey paylaş',
      'treasureMyItemsEmptyTitle': 'Henüz bir şey paylaşmadınız',
      'treasureMyItemsEmptyText': 'Başlamak için bir fotoğraf yeterli.',
      'treasureNoResultsTitle': 'Şu an uygun bir şey yok',
      'treasureNoResultsText':
          'Daha geniş bir mesafe deneyin veya daha sonra tekrar bakın.',
      'treasureNetworkError':
          'Bağlantı kesildi. Lütfen biraz sonra tekrar deneyin.',
      'treasureUploadFailed':
          'Yükleme şu an başarısız oldu. Taslağınız güvende.',
      'treasurePhotoMissing':
          'Ailelerin ne paylaştığınızı hemen görebilmesi için önce bir fotoğraf ekleyin.',
      'treasurePhotoRequired': 'Lütfen en az bir fotoğraf ekleyin.',
      'treasureConditionRequired': 'Lütfen bir durum seçin.',
      'treasureCategoryRequired': 'Lütfen bir kategori seçin.',
      'treasureSizeAgeRequired': 'Lütfen beden veya yaş ekleyin.',
      'treasureFilterAll': 'Tümü',
      'treasureFilterDistanceAll': 'Her mesafe',
      'treasureFilterDistance250': '250 m\'ye kadar',
      'treasureFilterDistance500': '500 m\'ye kadar',
      'treasureSelectedForHandover': 'Kaydedildi',
      'treasureFreshToday': 'Bugün yeni',
      'treasureJustListed': 'Az önce eklendi',
      'treasureMinutesAgoShort': '{count} dk önce',
      'treasureHoursAgoShort': '{count} sa önce',
      'treasureSelectForHandover': 'Teslim için seç',
      'treasureDetailSectionAbout': 'Bir bakışta',
      'treasureDetailSectionPickup': 'Teslim alma ve teslim',
      'treasureDetailSelectedHint':
          'Bu hazine şu an tesliminiz için kaydedildi.',
      'treasureSelectionConfirmed': '{title} şimdi tesliminiz için kaydedildi.',
      'treasureReservationPrepared': '{title}: {mode} - {detail}',
      'treasureSlotSunday': 'Pazar, 10:00 - 11:30',
      'treasureSlotMonday': 'Pazartesi, 17:30 - 18:15',
      'treasureSlotTuesday': 'Salı, 08:15 - 08:45',
      'treasureDropRetterBox': 'Kapının önündeki kurtarma kutusu',
      'treasureDropKitaLocker': 'Kreş dolabı ("Martı" bölmesi)',
      'treasureDropMailbox': 'Girişteki posta kutusu',
    }
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => [
        'en',
        'de',
        'ar',
        'fa',
        'ku',
        'ckb',
        'fr',
        'es',
        'it',
        'pt',
        'nl',
        'pl',
        'tr',
        'ja',
        'zh',
        'hi',
        'ru',
        'uk',
        'hr',
        'sr',
        'fi',
        'da',
        'el',
        'sw',
        'am',
        'ha',
        'so',
        'ti'
      ].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
