import 'package:parentpeak/models/family_recipe.dart';

/// Mehrsprachige Fallback-Rezepte für die Familien-Küche.
///
/// Diese Rezepte werden ausgeliefert, wenn die KI nicht verfügbar ist
/// (Rate-Limit, Netzwerkfehler, ungültige Antwort). Weil sie genau dann
/// greifen, wenn KEINE KI verfügbar ist, können sie nicht zur Laufzeit
/// übersetzt werden — darum sind die nutzersichtbaren Texte (Titel,
/// Beschreibung, Zutaten, Schritte, Eltern-Tipp) in allen Hauptsprachen
/// gepflegt: Deutsch, Englisch, Türkisch, Kurmandschi.
///
/// Für nicht gepflegte Sprachen wird Englisch als inklusiver Rückfall genutzt.
///
/// WICHTIG: Die strukturellen Felder (prepMinutes, costPerPortion, minChildAge,
/// allergensFree, season) sind in allen Sprachen IDENTISCH — nur die Texte
/// unterscheiden sich. So bleibt die Allergen-Sicherheit (AllergenGuard)
/// unabhängig von der Sprache gültig: `allergensFree` nutzt kanonische Keys
/// und die `ingredients` enthalten dieselben Lebensmittel in jeder Sprache.
class FallbackRecipes {
  const FallbackRecipes._();

  /// Liefert die Fallback-Rezepte in der gewünschten Sprache. Fällt für nicht
  /// gepflegte Sprachen auf Englisch zurück (inklusiv statt Deutsch-only).
  static List<FamilyRecipe> forLanguage(String languageCode) {
    switch (languageCode) {
      case 'de':
        return _de;
      case 'tr':
        return _tr;
      case 'ku':
        return _ku;
      case 'en':
      default:
        return _en;
    }
  }

  // ─── Deutsch ───────────────────────────────────────────────────────────
  static const _de = [
    // BABY (ab 6 Monaten, BLW/Brei) — sicheres Fallback für die Jüngsten.
    FamilyRecipe(
      id: '',
      title: 'Gemüse-Kartoffel-Brei',
      description: 'Mild und weich — ideal für die ersten Löffel (ab 6 Mon.).',
      prepMinutes: 20,
      costPerPortion: 0.80,
      minChildAge: 0,
      ingredients: [
        '2 Kartoffeln',
        '1 Karotte',
        '1 kleine Zucchini',
        '1 TL Olivenöl',
        'Wasser'
      ],
      steps: [
        'Kartoffeln, Karotte und Zucchini schälen und klein würfeln.',
        'In wenig Wasser weich kochen (ca. 15 Min).',
        'Mit dem Öl fein pürieren (für Babys ganz glatt).',
        'Lauwarm servieren — Konsistenz je nach Alter anpassen.'
      ],
      allergensFree: ['nuesse', 'ei', 'laktose', 'gluten', 'fisch'],
      season: '',
      tip: 'Für größere Kinder gröber stampfen statt pürieren — mehr zu kauen.',
    ),
    // FLEISCH
    FamilyRecipe(
      id: '',
      title: 'Spaghetti Bolognese',
      description: 'DER Klassiker — Kinder-Liebling Nr. 1 weltweit.',
      prepMinutes: 30,
      costPerPortion: 2.00,
      minChildAge: 1,
      ingredients: [
        '400g Spaghetti',
        '300g Hackfleisch',
        '1 Dose Tomaten',
        '1 Karotte',
        '1 Zwiebel',
        'Olivenöl'
      ],
      steps: [
        'Zwiebel + Karotte fein hacken, in Öl anbraten.',
        'Hack dazu, krümelig braten.',
        'Tomaten dazu, 15 Min köcheln.',
        'Nudeln kochen, servieren.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip: 'Lass dein Kind das Hackfleisch krümeln — wer mithilft isst lieber.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Hähnchen-Nuggets aus dem Ofen',
      description: 'Knusprig wie aus dem Restaurant aber gesünder.',
      prepMinutes: 25,
      costPerPortion: 2.20,
      minChildAge: 1,
      ingredients: [
        '500g Hähnchenbrust',
        '100g Semmelbrösel',
        '1 Ei',
        'Paprikapulver',
        'Salz'
      ],
      steps: [
        'Hähnchen in Stücke schneiden.',
        'In Ei wenden, dann in Semmelbrösel.',
        '15 Min bei 200 Grad backen.',
        'Mit Ketchup oder Gurkensticks servieren.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip:
          'Kinder ab 3 können beim Panieren helfen — Hände eintauchen macht Spaß!',
    ),
    FamilyRecipe(
      id: '',
      title: 'Mini-Schnitzel mit Kartoffelpüree',
      description: 'Schnell, saftig, und das Püree ist wie eine Umarmung.',
      prepMinutes: 30,
      costPerPortion: 2.50,
      minChildAge: 1,
      ingredients: [
        '4 kleine Schweineschnitzel',
        '100g Semmelbrösel',
        '1 Ei',
        '600g Kartoffeln',
        '50ml Milch',
        'Butter'
      ],
      steps: [
        'Kartoffeln kochen, stampfen mit Milch + Butter.',
        'Schnitzel klopfen, in Ei + Brösel wenden.',
        'In Pfanne goldbraun braten.',
        'Mit Püree + Gurkensalat servieren.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip:
          'Kleine Schnitzel, die in Kinderhände passen, wirken einladender als große.',
    ),
    // FISCH
    FamilyRecipe(
      id: '',
      title: 'Selbstgemachte Fischstäbchen',
      description: 'Besser als TK — und in 20 Min fertig.',
      prepMinutes: 20,
      costPerPortion: 2.30,
      minChildAge: 1,
      ingredients: [
        '400g Fischfilet (Kabeljau/Seelachs)',
        '80g Semmelbrösel',
        '1 Ei',
        'Zitrone',
        'Salz'
      ],
      steps: [
        'Fisch in Stäbchen schneiden.',
        'In Ei, dann Semmelbrösel wenden.',
        'In Pfanne mit wenig Öl 3-4 Min pro Seite braten.',
        'Mit Zitrone und Kartoffeln servieren.'
      ],
      allergensFree: ['nuesse', 'laktose'],
      season: '',
      tip:
          'Die Stäbchen-Form macht Fisch für Kinder attraktiver als ein ganzes Filet.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Lachs-Nudeln mit Sahne-Sauce',
      description: 'Cremig, mild, reich an Omega-3 für kleine Gehirne.',
      prepMinutes: 20,
      costPerPortion: 3.00,
      minChildAge: 2,
      ingredients: [
        '300g Pasta',
        '200g Lachsfilet',
        '150ml Sahne',
        '1 EL Butter',
        'Dill',
        'Salz'
      ],
      steps: [
        'Nudeln kochen.',
        'Lachs in Stücke schneiden, in Butter anbraten.',
        'Sahne dazu, kurz aufkochen.',
        'Mit Nudeln vermischen, Dill drauf.'
      ],
      allergensFree: ['nuesse', 'ei'],
      season: '',
      tip: 'Lachs ist mild genug für Kinder, die keinen Fischgeschmack mögen.',
    ),
    // VEGETARISCH
    FamilyRecipe(
      id: '',
      title: 'Pizza vom Blech (mit Kindern belegt)',
      description: 'Jedes Kind belegt seine eigene Ecke — Spaß garantiert.',
      prepMinutes: 30,
      costPerPortion: 1.50,
      minChildAge: 1,
      ingredients: [
        '1 Fertig-Pizzateig (oder 500g Mehl + Hefe)',
        '200ml Tomatensauce',
        '200g Käse',
        'Belag nach Wunsch: Mais, Salami, Paprika'
      ],
      steps: [
        'Teig ausrollen auf Blech.',
        'Sauce verteilen.',
        'Kinder belegen lassen!',
        '12-15 Min bei 220 Grad backen.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip: 'Jedes Familienmitglied bekommt ein Viertel zum Selbst-Belegen.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Mac and Cheese (Nudeln mit Käse)',
      description:
          'Cremig, käsig, geht immer. Comfort-Food für die ganze Familie.',
      prepMinutes: 20,
      costPerPortion: 1.30,
      minChildAge: 1,
      ingredients: [
        '400g Makkaroni',
        '200ml Milch',
        '150g geriebener Käse',
        '1 EL Butter',
        '1 EL Mehl',
        'Muskat'
      ],
      steps: [
        'Nudeln kochen.',
        'Butter schmelzen, Mehl einrühren.',
        'Milch dazu, glatt rühren.',
        'Käse unterheben bis cremig.',
        'Nudeln in Sauce wenden.'
      ],
      allergensFree: ['nuesse', 'ei'],
      season: '',
      tip:
          'Käse-Fäden ziehen finden Kinder faszinierend — das ist Teil des Spaßes!',
    ),
    FamilyRecipe(
      id: '',
      title: 'Pfannkuchen mit Apfelmus',
      description: 'Süß, schnell, beliebt bei JEDEM Kind.',
      prepMinutes: 15,
      costPerPortion: 0.80,
      minChildAge: 1,
      ingredients: ['200g Mehl', '2 Eier', '300ml Milch', 'Butter', 'Apfelmus'],
      steps: [
        'Teig glatt rühren.',
        'Pfanne erhitzen, Butter rein.',
        'Dünn ausgießen, goldbraun wenden.',
        'Mit Apfelmus servieren.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip:
          'Pfannkuchen eignen sich perfekt zum gemeinsamen Wenden-Üben ab 4 Jahren.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Kartoffelsuppe mit Würstchen',
      description: 'Wärmt von innen. Kinder lieben die Würstchen-Stücke drin.',
      prepMinutes: 25,
      costPerPortion: 1.40,
      minChildAge: 1,
      ingredients: [
        '600g Kartoffeln',
        '1 Karotte',
        '500ml Brühe',
        '2 Wiener Würstchen',
        '100ml Sahne'
      ],
      steps: [
        'Kartoffeln + Karotte würfeln, in Brühe kochen.',
        'Pürieren (nicht ganz glatt — Stücke lassen).',
        'Sahne einrühren.',
        'Würstchen in Scheiben schneiden, dazu geben.'
      ],
      allergensFree: ['nuesse', 'ei'],
      season: '',
      tip: 'Lass dein Kind die Würstchen mit dem Kindermesser schneiden.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Reis-Pfanne mit Hähnchen und Gemüse',
      description: 'Bunt, schnell, alles in einer Pfanne.',
      prepMinutes: 25,
      costPerPortion: 2.00,
      minChildAge: 1,
      ingredients: [
        '250g Reis',
        '300g Hähnchenbrust',
        '1 Paprika',
        '1 kleine Zucchini',
        '2 EL Sojasauce',
        'Öl'
      ],
      steps: [
        'Reis kochen.',
        'Hähnchen in Streifen schneiden, anbraten.',
        'Gemüse dazu, 5 Min braten.',
        'Reis unterheben, Sojasauce drüber.'
      ],
      allergensFree: ['nuesse', 'ei', 'laktose'],
      season: '',
      tip:
          'Wenn Kinder das Gemüse in lustigen Formen schneiden, hilft das beim Probieren.',
    ),
  ];

  // ─── English ─────────────────────────────────────────────────────────────
  static const _en = [
    // BABY (from 6 months, BLW/puree) — safe fallback for the youngest.
    FamilyRecipe(
      id: '',
      title: 'Veggie potato puree',
      description: 'Mild and soft — perfect for the first spoonfuls (6 mo+).',
      prepMinutes: 20,
      costPerPortion: 0.80,
      minChildAge: 0,
      ingredients: [
        '2 potatoes',
        '1 carrot',
        '1 small zucchini',
        '1 tsp olive oil',
        'water'
      ],
      steps: [
        'Peel potatoes, carrot and zucchini and dice small.',
        'Cook in a little water until soft (about 15 min).',
        'Puree finely with the oil (very smooth for babies).',
        'Serve lukewarm — adjust the texture to the age.'
      ],
      allergensFree: ['nuesse', 'ei', 'laktose', 'gluten', 'fisch'],
      season: '',
      tip: 'For older kids, mash coarsely instead of pureeing — more to chew.',
    ),
    // MEAT
    FamilyRecipe(
      id: '',
      title: 'Spaghetti Bolognese',
      description: 'THE classic — kids\' favourite number one worldwide.',
      prepMinutes: 30,
      costPerPortion: 2.00,
      minChildAge: 1,
      ingredients: [
        '400g spaghetti',
        '300g minced meat',
        '1 tin of tomatoes',
        '1 carrot',
        '1 onion',
        'olive oil'
      ],
      steps: [
        'Finely chop the onion and carrot, sauté in oil.',
        'Add the mince and brown until crumbly.',
        'Add the tomatoes and simmer for 15 minutes.',
        'Cook the pasta and serve.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip: 'Let your child crumble the mince — helping makes them eat better.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Oven-Baked Chicken Nuggets',
      description: 'As crispy as the restaurant, but healthier.',
      prepMinutes: 25,
      costPerPortion: 2.20,
      minChildAge: 1,
      ingredients: [
        '500g chicken breast',
        '100g breadcrumbs',
        '1 egg',
        'paprika powder',
        'salt'
      ],
      steps: [
        'Cut the chicken into pieces.',
        'Coat in egg, then in breadcrumbs.',
        'Bake for 15 minutes at 200°C.',
        'Serve with ketchup or cucumber sticks.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip: 'Kids from age 3 can help with the breading — dipping hands is fun!',
    ),
    FamilyRecipe(
      id: '',
      title: 'Mini Schnitzel with Mashed Potatoes',
      description: 'Quick, juicy, and the mash is like a warm hug.',
      prepMinutes: 30,
      costPerPortion: 2.50,
      minChildAge: 1,
      ingredients: [
        '4 small pork cutlets',
        '100g breadcrumbs',
        '1 egg',
        '600g potatoes',
        '50ml milk',
        'butter'
      ],
      steps: [
        'Boil the potatoes, mash with milk and butter.',
        'Flatten the cutlets, coat in egg and breadcrumbs.',
        'Fry in a pan until golden.',
        'Serve with mash and cucumber salad.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip:
          'Small cutlets that fit in little hands feel more inviting than big ones.',
    ),
    // FISH
    FamilyRecipe(
      id: '',
      title: 'Homemade Fish Fingers',
      description: 'Better than frozen — and ready in 20 minutes.',
      prepMinutes: 20,
      costPerPortion: 2.30,
      minChildAge: 1,
      ingredients: [
        '400g fish fillet (cod/pollock)',
        '80g breadcrumbs',
        '1 egg',
        'lemon',
        'salt'
      ],
      steps: [
        'Cut the fish into sticks.',
        'Coat in egg, then breadcrumbs.',
        'Fry in a little oil for 3-4 minutes per side.',
        'Serve with lemon and potatoes.'
      ],
      allergensFree: ['nuesse', 'laktose'],
      season: '',
      tip: 'The finger shape makes fish more appealing than a whole fillet.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Salmon Pasta in Cream Sauce',
      description: 'Creamy, mild, rich in omega-3 for little brains.',
      prepMinutes: 20,
      costPerPortion: 3.00,
      minChildAge: 2,
      ingredients: [
        '300g pasta',
        '200g salmon fillet',
        '150ml cream',
        '1 tbsp butter',
        'dill',
        'salt'
      ],
      steps: [
        'Cook the pasta.',
        'Cut the salmon into pieces and sauté in butter.',
        'Add the cream and bring to a brief boil.',
        'Mix with the pasta and sprinkle with dill.'
      ],
      allergensFree: ['nuesse', 'ei'],
      season: '',
      tip: 'Salmon is mild enough for children who dislike a fishy taste.',
    ),
    // VEGETARIAN
    FamilyRecipe(
      id: '',
      title: 'Sheet-Pan Pizza (topped by the kids)',
      description: 'Each child tops their own corner — fun guaranteed.',
      prepMinutes: 30,
      costPerPortion: 1.50,
      minChildAge: 1,
      ingredients: [
        '1 ready pizza dough (or 500g flour + yeast)',
        '200ml tomato sauce',
        '200g cheese',
        'toppings of choice: corn, salami, pepper'
      ],
      steps: [
        'Roll out the dough on a baking tray.',
        'Spread the sauce.',
        'Let the kids add the toppings!',
        'Bake for 12-15 minutes at 220°C.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip: 'Each family member gets a quarter to top themselves.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Mac and Cheese',
      description:
          'Creamy, cheesy, always a hit. Comfort food for the whole family.',
      prepMinutes: 20,
      costPerPortion: 1.30,
      minChildAge: 1,
      ingredients: [
        '400g macaroni',
        '200ml milk',
        '150g grated cheese',
        '1 tbsp butter',
        '1 tbsp flour',
        'nutmeg'
      ],
      steps: [
        'Cook the pasta.',
        'Melt the butter, stir in the flour.',
        'Add the milk and stir until smooth.',
        'Fold in the cheese until creamy.',
        'Toss the pasta in the sauce.'
      ],
      allergensFree: ['nuesse', 'ei'],
      season: '',
      tip: 'Kids find cheese pulls fascinating — that\'s part of the fun!',
    ),
    FamilyRecipe(
      id: '',
      title: 'Pancakes with Apple Sauce',
      description: 'Sweet, quick, loved by EVERY child.',
      prepMinutes: 15,
      costPerPortion: 0.80,
      minChildAge: 1,
      ingredients: [
        '200g flour',
        '2 eggs',
        '300ml milk',
        'butter',
        'apple sauce'
      ],
      steps: [
        'Stir the batter until smooth.',
        'Heat the pan, add butter.',
        'Pour thinly, flip until golden.',
        'Serve with apple sauce.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip: 'Pancakes are perfect for practising flipping together from age 4.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Potato Soup with Sausage',
      description: 'Warms you from the inside. Kids love the sausage pieces.',
      prepMinutes: 25,
      costPerPortion: 1.40,
      minChildAge: 1,
      ingredients: [
        '600g potatoes',
        '1 carrot',
        '500ml stock',
        '2 Vienna sausages',
        '100ml cream'
      ],
      steps: [
        'Dice the potatoes and carrot, cook in the stock.',
        'Blend (not completely smooth — leave some chunks).',
        'Stir in the cream.',
        'Slice the sausages and add them in.'
      ],
      allergensFree: ['nuesse', 'ei'],
      season: '',
      tip: 'Let your child slice the sausages with a child-safe knife.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Rice Pan with Chicken and Vegetables',
      description: 'Colourful, quick, all in one pan.',
      prepMinutes: 25,
      costPerPortion: 2.00,
      minChildAge: 1,
      ingredients: [
        '250g rice',
        '300g chicken breast',
        '1 pepper',
        '1 small courgette',
        '2 tbsp soy sauce',
        'oil'
      ],
      steps: [
        'Cook the rice.',
        'Cut the chicken into strips and sauté.',
        'Add the vegetables and fry for 5 minutes.',
        'Fold in the rice and drizzle with soy sauce.'
      ],
      allergensFree: ['nuesse', 'ei', 'laktose'],
      season: '',
      tip:
          'Cutting the vegetables into fun shapes helps children give them a try.',
    ),
  ];

  // ─── Türkçe ────────────────────────────────────────────────────────────
  static const _tr = [
    // BEBEK (6 aydan itibaren, BLW/püre) — en küçükler için güvenli seçenek.
    FamilyRecipe(
      id: '',
      title: 'Sebzeli patates püresi',
      description: 'Yumuşak ve hafif — ilk kaşıklar için ideal (6 ay+).',
      prepMinutes: 20,
      costPerPortion: 0.80,
      minChildAge: 0,
      ingredients: [
        '2 patates',
        '1 havuç',
        '1 küçük kabak',
        '1 tatlı kaşığı zeytinyağı',
        'su'
      ],
      steps: [
        'Patates, havuç ve kabağı soyup küçük küçük doğra.',
        'Az suda yumuşayana kadar pişir (yaklaşık 15 dk).',
        'Yağla birlikte ince püre yap (bebekler için çok pürüzsüz).',
        'Ilık servis et — kıvamı yaşa göre ayarla.'
      ],
      allergensFree: ['nuesse', 'ei', 'laktose', 'gluten', 'fisch'],
      season: '',
      tip: 'Daha büyük çocuklar için püre yerine kabaca ez — çiğnemesi için.',
    ),
    // ET
    FamilyRecipe(
      id: '',
      title: 'Spaghetti Bolognese',
      description: 'Klasiklerin klasiği — dünyada çocukların bir numarası.',
      prepMinutes: 30,
      costPerPortion: 2.00,
      minChildAge: 1,
      ingredients: [
        '400g spagetti',
        '300g kıyma',
        '1 kutu domates',
        '1 havuç',
        '1 soğan',
        'zeytinyağı'
      ],
      steps: [
        'Soğanı ve havucu ince doğrayıp yağda kavurun.',
        'Kıymayı ekleyip ufalanana kadar kavurun.',
        'Domatesi ekleyip 15 dakika pişirin.',
        'Makarnayı haşlayıp servis edin.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip: 'Kıymayı çocuğunuz ufalasın — yardım eden daha iştahlı yer.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Fırında Tavuk Nugget',
      description: 'Restorandaki kadar çıtır ama daha sağlıklı.',
      prepMinutes: 25,
      costPerPortion: 2.20,
      minChildAge: 1,
      ingredients: [
        '500g tavuk göğsü',
        '100g galeta unu',
        '1 yumurta',
        'kırmızı toz biber',
        'tuz'
      ],
      steps: [
        'Tavuğu parçalara ayırın.',
        'Önce yumurtaya, sonra galeta ununa bulayın.',
        '200 derecede 15 dakika pişirin.',
        'Ketçap veya salatalık çubuklarıyla servis edin.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip:
          '3 yaşından büyük çocuklar paneleme işine yardım edebilir — ellerini batırmak eğlenceli!',
    ),
    FamilyRecipe(
      id: '',
      title: 'Patates Püresiyle Mini Şnitzel',
      description: 'Hızlı, sulu ve püre sıcacık bir sarılma gibi.',
      prepMinutes: 30,
      costPerPortion: 2.50,
      minChildAge: 1,
      ingredients: [
        '4 küçük dana/dilim et',
        '100g galeta unu',
        '1 yumurta',
        '600g patates',
        '50ml süt',
        'tereyağı'
      ],
      steps: [
        'Patatesleri haşlayıp süt ve tereyağıyla ezin.',
        'Etleri dövüp yumurta ve galeta ununa bulayın.',
        'Tavada altın renginde kızartın.',
        'Püre ve salatalık salatasıyla servis edin.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip:
          'Çocuk eline sığan küçük şnitzeller büyüklerden daha davetkâr görünür.',
    ),
    // BALIK
    FamilyRecipe(
      id: '',
      title: 'Ev Yapımı Balık Çubukları',
      description: 'Dondurulmuştan daha iyi — hem de 20 dakikada hazır.',
      prepMinutes: 20,
      costPerPortion: 2.30,
      minChildAge: 1,
      ingredients: [
        '400g balık fileto (morina/mezgit)',
        '80g galeta unu',
        '1 yumurta',
        'limon',
        'tuz'
      ],
      steps: [
        'Balığı çubuklar hâlinde kesin.',
        'Önce yumurtaya, sonra galeta ununa bulayın.',
        'Az yağda her iki tarafını 3-4 dakika kızartın.',
        'Limon ve patatesle servis edin.'
      ],
      allergensFree: ['nuesse', 'laktose'],
      season: '',
      tip: 'Çubuk şekli, balığı bütün filetodan daha çekici kılar.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Kremalı Soslu Somonlu Makarna',
      description: 'Kremamsı, hafif, küçük beyinler için omega-3 deposu.',
      prepMinutes: 20,
      costPerPortion: 3.00,
      minChildAge: 2,
      ingredients: [
        '300g makarna',
        '200g somon fileto',
        '150ml krema',
        '1 yemek kaşığı tereyağı',
        'dereotu',
        'tuz'
      ],
      steps: [
        'Makarnayı haşlayın.',
        'Somonu parçalayıp tereyağında soteleyin.',
        'Kremayı ekleyip kısa süre kaynatın.',
        'Makarnayla karıştırıp üzerine dereotu serpin.'
      ],
      allergensFree: ['nuesse', 'ei'],
      season: '',
      tip: 'Somon, balık tadını sevmeyen çocuklar için yeterince hafiftir.',
    ),
    // VEJETARYEN
    FamilyRecipe(
      id: '',
      title: 'Tepsi Pizza (çocuklar süslesin)',
      description: 'Her çocuk kendi köşesini süsler — eğlence garanti.',
      prepMinutes: 30,
      costPerPortion: 1.50,
      minChildAge: 1,
      ingredients: [
        '1 hazır pizza hamuru (veya 500g un + maya)',
        '200ml domates sosu',
        '200g peynir',
        'istediğiniz malzeme: mısır, sucuk, biber'
      ],
      steps: [
        'Hamuru tepsiye açın.',
        'Sosu yayın.',
        'Çocuklar malzemeleri eklesin!',
        '220 derecede 12-15 dakika pişirin.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip: 'Her aile ferdi süslemek için bir çeyrek alır.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Peynirli Makarna (Mac and Cheese)',
      description: 'Kremamsı, bol peynirli, her zaman tutar. Tüm aileye şifa.',
      prepMinutes: 20,
      costPerPortion: 1.30,
      minChildAge: 1,
      ingredients: [
        '400g makarna (dirsek)',
        '200ml süt',
        '150g rendelenmiş peynir',
        '1 yemek kaşığı tereyağı',
        '1 yemek kaşığı un',
        'muskat'
      ],
      steps: [
        'Makarnayı haşlayın.',
        'Tereyağını eritip unu ekleyin.',
        'Sütü ekleyip pürüzsüz olana dek karıştırın.',
        'Peyniri ekleyip kremamsı kıvam alana dek karıştırın.',
        'Makarnayı sosla harmanlayın.'
      ],
      allergensFree: ['nuesse', 'ei'],
      season: '',
      tip: 'Çocuklar uzayan peyniri çok sever — bu da eğlencenin bir parçası!',
    ),
    FamilyRecipe(
      id: '',
      title: 'Elma Püreli Krep',
      description: 'Tatlı, hızlı, HER çocuğun sevdiği.',
      prepMinutes: 15,
      costPerPortion: 0.80,
      minChildAge: 1,
      ingredients: [
        '200g un',
        '2 yumurta',
        '300ml süt',
        'tereyağı',
        'elma püresi'
      ],
      steps: [
        'Hamuru pürüzsüz olana dek karıştırın.',
        'Tavayı ısıtıp tereyağı ekleyin.',
        'İnce dökün, altın renginde çevirin.',
        'Elma püresiyle servis edin.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip: '4 yaşından itibaren birlikte krep çevirme alıştırması için ideal.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Sosisli Patates Çorbası',
      description:
          'İçinizi ısıtır. Çocuklar içindeki sosis parçalarına bayılır.',
      prepMinutes: 25,
      costPerPortion: 1.40,
      minChildAge: 1,
      ingredients: [
        '600g patates',
        '1 havuç',
        '500ml et suyu',
        '2 sosis',
        '100ml krema'
      ],
      steps: [
        'Patates ve havucu küp küp doğrayıp et suyunda haşlayın.',
        'Blenderdan geçirin (tam pürüzsüz değil — parçalar kalsın).',
        'Kremayı ekleyip karıştırın.',
        'Sosisleri dilimleyip ekleyin.'
      ],
      allergensFree: ['nuesse', 'ei'],
      season: '',
      tip: 'Sosisleri çocuğunuz çocuk bıçağıyla dilimlesin.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Tavuklu ve Sebzeli Pilav Tavası',
      description: 'Renkli, hızlı, hepsi tek tavada.',
      prepMinutes: 25,
      costPerPortion: 2.00,
      minChildAge: 1,
      ingredients: [
        '250g pirinç',
        '300g tavuk göğsü',
        '1 biber',
        '1 küçük kabak',
        '2 yemek kaşığı soya sosu',
        'yağ'
      ],
      steps: [
        'Pirinci pişirin.',
        'Tavuğu şeritler hâlinde kesip soteleyin.',
        'Sebzeleri ekleyip 5 dakika kavurun.',
        'Pilavı ekleyin, üzerine soya sosu gezdirin.'
      ],
      allergensFree: ['nuesse', 'ei', 'laktose'],
      season: '',
      tip:
          'Sebzeleri eğlenceli şekillerde kesmek çocukların denemesine yardımcı olur.',
    ),
  ];

  // ─── Kurmancî ────────────────────────────────────────────────────────────
  static const _ku = [
    // PITIK (ji 6 mehî, BLW/pelte) — hilbijartineke ewle ji bo biçûktirîn.
    FamilyRecipe(
      id: '',
      title: 'Pelteya sebze û kartol',
      description: 'Nerm û sivik — ji bo kefçiyên pêşîn îdeal (ji 6 mehî).',
      prepMinutes: 20,
      costPerPortion: 0.80,
      minChildAge: 0,
      ingredients: [
        '2 kartol',
        '1 gêzer',
        '1 kûjeya biçûk',
        '1 kevçîzayê zeytûnê',
        'av'
      ],
      steps: [
        'Kartol, gêzer û kûjeyê qalik bike û biçûk hûr bike.',
        'Di hindik avê de heta nerm bibe bikelîne (nêzî 15 deqe).',
        'Bi rûn re hûrik pelte bike (ji bo pitikan pir nerm).',
        'Nîvgerm pêşkêş bike — hişkiya wê li gorî temen biguherîne.'
      ],
      allergensFree: ['nuesse', 'ei', 'laktose', 'gluten', 'fisch'],
      season: '',
      tip: 'Ji bo zarokên mezintir li şûna pelteyê hûrik bitepisîne.',
    ),
    // GOŞT
    FamilyRecipe(
      id: '',
      title: 'Spaghetti Bolognese',
      description: 'Klasîka klasîkan — yekemîn hezkiriya zarokan li cîhanê.',
      prepMinutes: 30,
      costPerPortion: 2.00,
      minChildAge: 1,
      ingredients: [
        '400g spagetî',
        '300g goştê hûrkirî',
        '1 qûtiya firangoşan',
        '1 gizêr',
        '1 pîvaz',
        'rûnê zeytûnê'
      ],
      steps: [
        'Pîvaz û gizêrê hûr bikin, di rûn de sor bikin.',
        'Goşt lê zêde bikin, heta hûr bibe sor bikin.',
        'Firangoşan lê zêde bikin, 15 deqîqe bikelînin.',
        'Makaronî bikelînin û pêşkêş bikin.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip: 'Bila zarok goşt hûr bike — yê ku alîkariyê dike baştir dixwe.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Nugetên Mirîşkê ji Firnê',
      description: 'Wek a xwaringehê çitir e lê saxlemtir e.',
      prepMinutes: 25,
      costPerPortion: 2.20,
      minChildAge: 1,
      ingredients: [
        '500g sînga mirîşkê',
        '100g arvanê nanî',
        '1 hêk',
        'biberê sor ê hûrkirî',
        'xwê'
      ],
      steps: [
        'Mirîşkê perçe perçe bikin.',
        'Pêşî di hêkê, paşê di arvanê nanî de bigerînin.',
        'Di 200 pileyî de 15 deqîqe bipêjin.',
        'Bi ketçap an perçeyên xiyarê pêşkêş bikin.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip:
          'Zarokên ji 3 salî mezin dikarin di pêçandinê de alîkar bibin — destê xwe kirin kêfê dide!',
    ),
    FamilyRecipe(
      id: '',
      title: 'Mini-Şnîtzel bi Pelûlê Kartolan',
      description: 'Bilez, şêlû, û pelûl wek hembêzkirineke germ e.',
      prepMinutes: 30,
      costPerPortion: 2.50,
      minChildAge: 1,
      ingredients: [
        '4 perçeyên goştê piçûk',
        '100g arvanê nanî',
        '1 hêk',
        '600g kartol',
        '50ml şîr',
        'rûn'
      ],
      steps: [
        'Kartolan bikelînin, bi şîr û rûn pelûl bikin.',
        'Goşt pehn bikin, di hêk û arvanê nanî de bigerînin.',
        'Di tawê de heta zêrîn sor bikin.',
        'Bi pelûl û salata xiyaran pêşkêş bikin.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip:
          'Şnîtzelên piçûk ên ku li destê zarokan tên ji yên mezin xweştir xuya dikin.',
    ),
    // MASÎ
    FamilyRecipe(
      id: '',
      title: 'Çîkên Masî yên Malê',
      description: 'Ji ya cemidî çêtir — û di 20 deqîqeyan de amade ye.',
      prepMinutes: 20,
      costPerPortion: 2.30,
      minChildAge: 1,
      ingredients: [
        '400g fîleyê masî (kabeljau/seelachs)',
        '80g arvanê nanî',
        '1 hêk',
        'leymûn',
        'xwê'
      ],
      steps: [
        'Masî wek çîkan jê bikin.',
        'Di hêkê, paşê di arvanê nanî de bigerînin.',
        'Bi hindik rûn her alî 3-4 deqîqe sor bikin.',
        'Bi leymûn û kartolan pêşkêş bikin.'
      ],
      allergensFree: ['nuesse', 'laktose'],
      season: '',
      tip: 'Şiklê çîkan masî ji fîleyekî tevahî ji bo zarokan balkêştir dike.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Makaroniya Somonê bi Soşa Qeymaxê',
      description: 'Qeymaxî, nerm, ji bo mejiyên piçûk dewlemend bi omega-3.',
      prepMinutes: 20,
      costPerPortion: 3.00,
      minChildAge: 2,
      ingredients: [
        '300g makaronî',
        '200g fîleyê somonê',
        '150ml qeymax',
        '1 kevçî rûn',
        'şiwît',
        'xwê'
      ],
      steps: [
        'Makaronî bikelînin.',
        'Somonê perçe bikin, di rûn de sor bikin.',
        'Qeymaxê lê zêde bikin, kurt bikelînin.',
        'Bi makaroniyê tevlihev bikin, şiwît lê bikin.'
      ],
      allergensFree: ['nuesse', 'ei'],
      season: '',
      tip: 'Somon têra xwe nerm e ji bo zarokên ku ji tama masî hez nakin.',
    ),
    // VEGETARÎ
    FamilyRecipe(
      id: '',
      title: 'Pizza li ser Sênîkê (zarok lê datînin)',
      description: 'Her zarok quncikê xwe datîne — kêf misoger e.',
      prepMinutes: 30,
      costPerPortion: 1.50,
      minChildAge: 1,
      ingredients: [
        '1 hevîrê pizzayê yê amade (an 500g arvan + hevîrtirş)',
        '200ml soşa firangoşan',
        '200g penîr',
        'li gorî dilê xwe: genimok, salam, biber'
      ],
      steps: [
        'Hevîr li ser sênîkê vekin.',
        'Soşê belav bikin.',
        'Bila zarok lê datînin!',
        'Di 220 pileyî de 12-15 deqîqe bipêjin.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip: 'Her endamê malbatê çarêkekê distîne ku bi xwe lê datîne.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Makaroniya Penîr (Mac and Cheese)',
      description:
          'Qeymaxî, bi penîr, timî dixebite. Xwarina rehetiyê ji bo tevahiya malbatê.',
      prepMinutes: 20,
      costPerPortion: 1.30,
      minChildAge: 1,
      ingredients: [
        '400g makaronî',
        '200ml şîr',
        '150g penîrê rendekirî',
        '1 kevçî rûn',
        '1 kevçî arvan',
        'cewz (muskat)'
      ],
      steps: [
        'Makaronî bikelînin.',
        'Rûn bihelînin, arvan lê bikin.',
        'Şîr lê zêde bikin, heta nerm bibe tevlihev bikin.',
        'Penîr lê bikin heta qeymaxî bibe.',
        'Makaroniyê di soşê de bigerînin.'
      ],
      allergensFree: ['nuesse', 'ei'],
      season: '',
      tip: 'Zarok ji penîrê ku dirêj dibe pir hez dikin — ev beşek ji kêfê ye!',
    ),
    FamilyRecipe(
      id: '',
      title: 'Pankek bi Pelûla Sêvan',
      description: 'Şêrîn, bilez, HER zarok jê hez dike.',
      prepMinutes: 15,
      costPerPortion: 0.80,
      minChildAge: 1,
      ingredients: ['200g arvan', '2 hêk', '300ml şîr', 'rûn', 'pelûla sêvan'],
      steps: [
        'Hevîr heta nerm bibe tevlihev bikin.',
        'Tawê germ bikin, rûn lê bikin.',
        'Zok birijînin, heta zêrîn bibe bizivirînin.',
        'Bi pelûla sêvan pêşkêş bikin.'
      ],
      allergensFree: ['nuesse'],
      season: '',
      tip: 'Pankek ji bo ji 4 saliyê ve bi hev re fêrbûna zivirandinê îdeal e.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Şorbeya Kartolan bi Sosîs',
      description: 'Ji hundir germ dike. Zarok ji perçeyên sosîs hez dikin.',
      prepMinutes: 25,
      costPerPortion: 1.40,
      minChildAge: 1,
      ingredients: [
        '600g kartol',
        '1 gizêr',
        '500ml ava goşt',
        '2 sosîs',
        '100ml qeymax'
      ],
      steps: [
        'Kartol û gizêr wek kûp jê bikin, di ava goşt de bikelînin.',
        'Blender bikin (ne tam nerm — bila hin perçe bimînin).',
        'Qeymaxê lê bikin û tevlihev bikin.',
        'Sosîsan perçe bikin û lê zêde bikin.'
      ],
      allergensFree: ['nuesse', 'ei'],
      season: '',
      tip: 'Bila zarok sosîsan bi kêra zarokan jê bike.',
    ),
    FamilyRecipe(
      id: '',
      title: 'Tawa Birincê bi Mirîşk û Sebzeyan',
      description: 'Rengîn, bilez, hemû di yek tawê de.',
      prepMinutes: 25,
      costPerPortion: 2.00,
      minChildAge: 1,
      ingredients: [
        '250g birinc',
        '300g sînga mirîşkê',
        '1 biber',
        '1 kundirê piçûk',
        '2 kevçî soşa soya',
        'rûn'
      ],
      steps: [
        'Birincê bikelînin.',
        'Mirîşkê wek şerîtan jê bikin, sor bikin.',
        'Sebzeyan lê zêde bikin, 5 deqîqe sor bikin.',
        'Birincê lê bikin, soşa soya lê bireşînin.'
      ],
      allergensFree: ['nuesse', 'ei', 'laktose'],
      season: '',
      tip:
          'Gava zarok sebzeyan wek şiklên kêfxweş jê bikin, ev alîkariya ceribandinê dike.',
    ),
  ];
}
