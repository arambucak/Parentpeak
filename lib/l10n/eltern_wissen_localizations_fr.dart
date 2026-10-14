import 'package:parentpeak/l10n/eltern_wissen_localizations.dart';

/// French translations for parent-knowledge FAQ entries.
const Map<String, ElternWissenText> elternWissenFr = {
  // ═══════════════════════════════════════════════════════════════════════════
  // BÉBÉ (0-1 an)
  // ═══════════════════════════════════════════════════════════════════════════
  'baby_01': ElternWissenText(
    question: 'Mon bébé pleure et je ne sais pas pourquoi',
    akut:
        'Prends ton bébé dans les bras, garde-le tout contre toi. Ton calme, c\'est sa sécurité.',
    beduerfnis:
        'Les bébés pleurent pour communiquer. Ton bébé a un besoin non comblé : faim, besoin de proximité, trop de stimulation, fatigue ou douleur.',
    gfkSatz:
        'Je suis là. Je t\'entends. On va trouver ensemble ce dont tu as besoin.',
    aktion: [
      'Établir le contact physique (peau à peau)',
      'Passer en revue les besoins de base : faim ? couche ? fatigue ?',
      'Réduire les stimulations : moins de bruit, moins de lumière, plus de calme',
    ],
    ermutigung:
        'Tu n\'as pas besoin de savoir tout de suite ce dont il a besoin. Ta présence est déjà la moitié de la solution.',
  ),
  'baby_02': ElternWissenText(
    question: 'Mon bébé ne s\'endort pas',
    akut:
        'Reste calme. Ton bébé ressent ta tension. Respire lentement et garde-le contre toi.',
    beduerfnis:
        'Les bébés ont besoin de corégulation. Ils ne savent pas encore se calmer seuls — ton système nerveux est leur ancre.',
    gfkSatz:
        'Tu es en sécurité. Je suis là. Ton corps a le droit de se reposer maintenant.',
    aktion: [
      'Créer des rituels : le même déroulé chaque soir',
      'Réduire les stimulations 30 min avant le coucher',
      'Offrir la proximité physique (porter, bercer, allaiter)',
    ],
    ermutigung:
        'Le sommeil est un processus de développement, pas le résultat d\'un entraînement. Ça va s\'améliorer.',
  ),
  'baby_03': ElternWissenText(
    question: 'Mon bébé ne veut que moi et pas l\'autre parent',
    akut:
        'C\'est normal et sain. Ton bébé montre un attachement sécurisant — ce n\'est pas un rejet.',
    beduerfnis:
        'Les bébés construisent souvent d\'abord un attachement privilégié avec une personne. Le deuxième parent a besoin de ses propres rituels et de temps.',
    gfkSatz:
        'Tu nous aimes tous les deux. En ce moment tu as besoin de moi — et c\'est tout à fait okay.',
    aktion: [
      'Offrir à l\'autre parent des moments de câlins à lui, sans concurrence',
      'Ne rien forcer — la confiance grandit par des expériences positives',
      'Augmenter peu à peu de courts moments seul à seul (5 min)',
    ],
    ermutigung:
        'C\'est une phase qui montre que l\'attachement fonctionne. Les deux parents sont importants.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // PETIT ENFANT (1-3 ans)
  // ═══════════════════════════════════════════════════════════════════════════
  'klein_01': ElternWissenText(
    question: 'Mon enfant tape les autres enfants',
    akut:
        'Approche-toi calmement. Ne crie pas. Dis : stop, je ne laisse pas faire que tu tapes.',
    beduerfnis:
        'Ton enfant n\'est pas méchant. Il a des émotions fortes (frustration, débordement) et pas encore les mots pour les dire. Taper, c\'est de la communication.',
    gfkSatz:
        'Je vois que tu es en colère. Taper, ça fait mal. Viens, on va trouver ensemble ce dont tu as besoin.',
    aktion: [
      'Intervenir tout de suite avec calme, consoler l\'autre enfant',
      'Plus tard : proposer des alternatives (taper du pied, frapper un coussin)',
      'Repérer le déclencheur : fatigue ? faim ? trop de stimulation ?',
    ],
    ermutigung:
        'C\'est une phase. Ton enfant est en train d\'apprendre le contrôle de ses impulsions — ça prend jusqu\'à 4-5 ans.',
  ),
  'klein_02': ElternWissenText(
    question: 'Mon enfant fait des crises de colère',
    akut:
        'Reste à proximité. Ne dis rien. Laisse la tempête passer. Ton enfant a besoin de toi APRÈS.',
    beduerfnis:
        'Les crises de colère sont neurologiques : le cerveau n\'est pas encore assez mûr pour réguler les émotions. Ton enfant est submergé et a besoin de corégulation.',
    gfkSatz:
        'Tu as le droit d\'être en colère. Je suis là. Quand tu auras fini, je te prendrai dans mes bras.',
    aktion: [
      'Garantir la sécurité (ne pas laisser lancer des choses qui blessent)',
      'Ne pas argumenter, ne pas gronder, ne pas s\'en aller',
      'Après la crise : offrir du contact physique, sans faire la morale',
    ],
    ermutigung:
        'Ce n\'est pas de ta faute. Les crises de colère font partie du développement et ne sont PAS un signe de mauvaise éducation.',
  ),
  'klein_03': ElternWissenText(
    question: 'Mon enfant ne veut pas partager',
    akut:
        'Ne force pas. Partager est une capacité qui MÛRIT — elle ne peut pas être imposée.',
    beduerfnis:
        'Avant 3-4 ans, les enfants comprennent la possession autrement que les adultes. Partager demande de l\'empathie — qui se développe seulement peu à peu.',
    gfkSatz: 'C\'est à toi. C\'est toi qui décides quand tu veux le donner.',
    aktion: [
      'Ne pas faire honte (pas de « ne sois pas aussi égoïste ! »)',
      'Montrer l\'exemple : partager à voix haute soi-même (« tu veux un morceau de ma pomme ? »)',
      'Ranger le jouet préféré AVANT la visite (ça réduit le stress)',
    ],
    ermutigung:
        'Un enfant qui se sent en sécurité dans ses possessions deviendra généreux de lui-même.',
  ),
  'klein_04': ElternWissenText(
    question: 'Mon enfant dit non à tout',
    akut:
        'C\'est sain ! Ton enfant est en train de découvrir : je suis une personne à part entière, avec ma propre volonté.',
    beduerfnis:
        'L\'autonomie est un besoin fondamental. Dire « non » est la première forme d\'autodétermination.',
    gfkSatz:
        'J\'entends ton non. Certaines choses doivent quand même se faire — regardons comment.',
    aktion: [
      'Offrir des choix plutôt que des ordres (« la veste rouge ou la bleue ? »)',
      'Éviter les luttes de pouvoir inutiles (est-ce que ça doit VRAIMENT être maintenant ?)',
      'Respecter le non quand c\'est possible — ça renforce la confiance en soi',
    ],
    ermutigung:
        'Un enfant qui a le droit de dire non à la maison saura plus tard dire non aux inconnus.',
  ),
  'klein_05': ElternWissenText(
    question: 'Mon enfant ne veut pas manger',
    akut:
        'Pas de pression. Pas de contrainte. Pas de repas en le distrayant. Fais confiance : aucun enfant ne se laisse avoir faim volontairement.',
    beduerfnis:
        'Le repas est un terrain d\'autonomie. Les enfants régulent eux-mêmes leur faim — la pression crée de la résistance.',
    gfkSatz:
        'Ton ventre sait quand il a faim. Le repas est là si tu en as envie.',
    aktion: [
      'S\'asseoir ensemble à table (sans forcer à manger)',
      'Toujours proposer au moins 1 aliment familier',
      'Proposer les nouveautés 10 à 15 fois sans faire de commentaire',
    ],
    ermutigung:
        'Les enfants difficiles à table, c\'est normal et ça passe. Ton enfant mange assez — même si ça ne te semble pas être le cas.',
  ),
  'klein_06': ElternWissenText(
    question: 'Quand ma voix monte plus que je ne le voudrais',
    akut:
        'Ton corps te montre justement : je suis à ma limite. C\'est un signal — pas un échec.',
    beduerfnis:
        'Derrière le volume de ta voix se cache un besoin : être entendu·e, du calme, du soutien. Tu as le droit de le ressentir.',
    gfkSatz:
        'Je remarque que mon corps est tendu. J\'ai besoin d\'un petit moment pour moi, pour retrouver ma clarté.',
    aktion: [
      'Apprends à reconnaître tes signaux avant-coureurs (mâchoire, épaules, respiration courte) — ils arrivent quelques secondes AVANT le cri',
      'Dis à ton enfant : « j\'ai besoin d\'une petite pause » — ce n\'est pas partir, c\'est montrer l\'exemple du soin de soi',
      'Ensuite : répare le lien (« je suis désolé·e, je n\'étais pas moi-même à l\'instant. Je t\'aime. »)',
    ],
    ermutigung:
        'Le fait que tu lises ceci montre que tu veux faire autrement. Cela à soi seul change déjà tout.',
  ),
  'klein_07': ElternWissenText(
    question: 'Mon enfant ne veut pas aller à la crèche',
    akut:
        'Prends sa peine au sérieux. Dis : je comprends que tu préférerais rester avec moi. Je viendrai te chercher plus tard.',
    beduerfnis:
        'L\'angoisse de la séparation est un signe d\'attachement sécurisant. Ton enfant te manque — et c\'est SAIN.',
    gfkSatz:
        'Je vois que tu es triste. Tu voudrais rester avec moi. Je reviens après le déjeuner.',
    aktion: [
      'Mettre en place un rituel d\'au revoir (toujours le même, court, affectueux)',
      'Ne jamais partir en cachette — ça détruit la confiance',
      'Donner un objet de transition (ton écharpe, une photo)',
    ],
    ermutigung:
        'L\'adaptation prend du temps. Des semaines, parfois des mois. Ce n\'est pas un recul.',
  ),
  'klein_08': ElternWissenText(
    question:
        'Mon enfant est jaloux du nouveau petit frère ou de la nouvelle petite sœur',
    akut:
        'Ne compare pas. Ne dis pas « tu es déjà grand ». Ton aîné fait un deuil — celui de ton attention partagée.',
    beduerfnis:
        'La jalousie est une peur de perdre : m\'aimez-vous encore autant ? Suis-je encore important ?',
    gfkSatz:
        'Tu es tout aussi important qu\'avant. C\'est okay d\'être triste ou en colère en ce moment.',
    aktion: [
      'Un temps exclusif maman/papa RIEN que pour l\'aîné (10 min/jour suffisent)',
      'Impliquer l\'aîné dans les soins du bébé (apporter la couche, chanter)',
      'Nommer les émotions sans juger : « tu es fâché contre le bébé — je le comprends »',
    ],
    ermutigung:
        'L\'amour entre frères et sœurs ne pousse pas tout de suite. Donne à l\'aîné du temps et de la sécurité.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // ENFANT EN MATERNELLE (3-6 ans)
  // ═══════════════════════════════════════════════════════════════════════════
  'kita_01': ElternWissenText(
    question: 'Mon enfant ment',
    akut:
        'Ne punis pas. Ne fais pas honte. Avant 6 ans, les enfants « mentent » souvent par imagination, par peur ou par désir.',
    beduerfnis:
        'Les enfants mentent quand la vérité leur semble dangereuse. Demande-toi : mon enfant se sent-il assez en sécurité pour être honnête ?',
    gfkSatz:
        'Je veux comprendre ce qui s\'est passé. Tu n\'auras pas d\'ennuis — raconte-moi ta version.',
    aktion: [
      'Créer de la sécurité : ne PAS punir l\'honnêteté',
      'Distinguer le mensonge d\'imagination (normal, 3-5 ans) du mensonge de protection (la peur)',
      'Montrer l\'exemple : être honnête soi-même, même quand c\'est inconfortable',
    ],
    ermutigung:
        'Les enfants qui peuvent être honnêtes en sécurité deviennent des adultes honnêtes.',
  ),
  'kita_02': ElternWissenText(
    question: 'Mon enfant a peur dans le noir',
    akut:
        'La peur est réelle. Ne la minimise pas. Dis : je te crois. Regardons ensemble comment te sentir en sécurité.',
    beduerfnis:
        'La peur du noir fait partie du développement (3-8 ans). Le cerveau peut désormais SE REPRÉSENTER les dangers — c\'est un progrès cognitif.',
    gfkSatz:
        'Je vois que tu as peur. L\'obscurité te semble inquiétante. Je suis dans la pièce d\'à côté — tu es en sécurité.',
    aktion: [
      'Une veilleuse (ça redonne du contrôle)',
      'Un spray anti-monstres (de l\'eau dans un vaporisateur — l\'enfant vaporise lui-même)',
      'Utiliser un doudou comme protecteur (« l\'ours veille sur toi »)',
    ],
    ermutigung:
        'Ton enfant n\'a pas de trouble. Il a de l\'imagination. C\'est une force.',
  ),
  'kita_03': ElternWissenText(
    question: 'Mon enfant veut toujours tout décider quand il joue',
    akut:
        'C\'est normal entre 4 et 6 ans. Les enfants s\'exercent au leadership — sans encore les subtilités sociales.',
    beduerfnis:
        'Ton enfant a besoin de sentiment d\'efficacité. Il veut vivre : mes idées comptent.',
    gfkSatz:
        'Tu as de super idées. Ton copain en a aussi. Et si vous faisiez chacun votre tour ?',
    aktion: [
      'Ne pas intervenir tout de suite — les enfants résolvent plus de choses qu\'on ne le croit',
      'Si nécessaire : proposer un changement de rôle, ne pas l\'ordonner',
      'À la maison : créer des situations où l\'enfant a le DROIT de mener (chef du jeu)',
    ],
    ermutigung:
        'Vouloir décider est un potentiel de leadership. Ça deviendra plus tard une force.',
  ),
  'kita_04': ElternWissenText(
    question: 'Mon enfant fait encore pipi au lit',
    akut:
        'Ne fais pas honte. L\'énurésie n\'est PAS de la paresse — c\'est un contrôle de la vessie encore immature.',
    beduerfnis:
        'Le corps de ton enfant n\'est pas encore prêt. Chez certains enfants, l\'hormone antidiurétique ne mûrit qu\'à 6-7 ans.',
    gfkSatz:
        'Ce n\'est pas de ta faute. Ton corps apprend encore. On va trouver une solution ensemble.',
    aktion: [
      'Une alèse imperméable (sans en faire un drame)',
      'Refaire le lit ensemble (impliquer l\'enfant, ne pas le punir)',
      'En cas d\'inquiétude : consulter le pédiatre à partir de 7 ans',
    ],
    ermutigung:
        'Près de 15 % des enfants de 5 ans font encore pipi au lit. Ton enfant n\'est pas seul.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // ENFANT EN PRIMAIRE (6-10 ans)
  // ═══════════════════════════════════════════════════════════════════════════
  'grund_01': ElternWissenText(
    question: 'Mon enfant ne veut pas faire ses devoirs',
    akut:
        'Ne te bats pas. Dis : je vois que tu n\'as pas envie. De quoi as-tu besoin pour commencer ?',
    beduerfnis:
        'Le refus des devoirs est rarement de la paresse. Souvent, il cache : un débordement, de l\'ennui, de l\'épuisement après la journée d\'école.',
    gfkSatz:
        'Je remarque que les devoirs te semblent pénibles. On regarde ensemble où ça coince ?',
    aktion: [
      '30 min de pause après l\'école (bouger, un en-cas, du calme)',
      'De petites portions (5 min de concentration, puis une pause)',
      'Pas de menaces — mais du soutien : « je t\'aide à démarrer »',
    ],
    ermutigung:
        'La motivation vient par la réussite, pas par la pression. De petits pas suffisent.',
  ),
  'grund_02': ElternWissenText(
    question: 'Mon enfant est mis à l\'écart à l\'école',
    akut:
        'Écoute. Crois ton enfant. Dis : je suis désolé·e. Tu mérites des amis qui sont gentils avec toi.',
    beduerfnis:
        'L\'appartenance est un besoin fondamental. L\'exclusion fait physiquement mal aux enfants — le cerveau la traite comme une douleur physique.',
    gfkSatz:
        'J\'entends que ça te rend très triste. Tu es digne d\'être aimé·e — peu importe ce que disent les autres.',
    aktion: [
      'Ne pas vouloir tout « résoudre » tout de suite — d\'abord reconnaître les émotions',
      'Demander : qu\'est-ce que tu souhaites ? (certains veulent de l\'aide, d\'autres juste être écoutés)',
      'En cas de harcèlement : informer l\'école (l\'enseignant·e responsable de la classe)',
    ],
    ermutigung:
        'Ton enfant n\'a pas besoin de beaucoup d\'amis. Un seul bon ami suffit pour un développement sain.',
  ),
  'grund_03': ElternWissenText(
    question: 'Mon enfant passe trop de temps devant les écrans',
    akut:
        'Ne retire pas l\'appareil au moment du conflit. Annonce les transitions : « encore 5 minutes, puis c\'est fini. »',
    beduerfnis:
        'Les écrans comblent des besoins : l\'ennui, l\'appartenance sociale, la stimulation. Demande : de quoi mon enfant a-t-il besoin À LA PLACE ?',
    gfkSatz:
        'Je vois que tu aimes ce jeu. Notre règle, c\'est 30 minutes. Qu\'aimerais-tu faire après ?',
    aktion: [
      'Convenir de règles claires À L\'AVANCE (pas sur le moment)',
      'Proposer des alternatives tout aussi attirantes (pas « va jouer dehors »)',
      'Montrer l\'exemple soi-même : combien de fois regardes-TU ton téléphone ?',
    ],
    ermutigung:
        'Tu n\'es pas un mauvais parent parce que ton enfant a du temps d\'écran. L\'équilibre, voilà le but.',
  ),
  'grund_04': ElternWissenText(
    question: 'Mon enfant a peur des examens',
    akut:
        'Normalise : l\'appréhension avant une épreuve est humaine. Dis : ta valeur ne dépend pas d\'une note.',
    beduerfnis:
        'La peur des examens apparaît quand la performance est liée à l\'amour : « si je suis mauvais, je ne suis pas assez bien. »',
    gfkSatz:
        'Je t\'aime tout autant — quelle que soit la note. Tu es bien plus qu\'un chiffre.',
    aktion: [
      'Ne pas demander « as-tu assez révisé ? » — mais « comment te sens-tu avec ça ? »',
      'Montrer un exercice de détente (la respiration 4-7-8)',
      'Après l\'épreuve : ne JAMAIS demander la note en premier',
    ],
    ermutigung:
        'Les enfants qui savent qu\'ils sont aimés sans condition ont moins peur.',
  ),
  'grund_05': ElternWissenText(
    question: 'Mon enfant dit qu\'il me déteste',
    akut:
        'Ça fait mal. Mais ton enfant veut dire : je suis tellement en colère que je ne sais pas où mettre tout ça.',
    beduerfnis:
        'Les enfants testent si le lien tient — même quand ils disent le pire. Ton enfant a besoin de vivre l\'expérience : tu ne t\'en vas pas.',
    gfkSatz:
        'J\'entends que tu es très en colère en ce moment. Je t\'aime — même quand tu es fâché contre moi.',
    aktion: [
      'Ne pas répliquer (« alors va-t\'en ! »)',
      'Ne pas s\'en aller vexé·e',
      'En reparler plus tard : « ça m\'a blessé·e. Qu\'est-ce qui t\'a mis·e aussi en colère ? »',
    ],
    ermutigung:
        'Un enfant qui te dit ce qu\'il ressent (même du moche) te fait confiance. Ça, c\'est le lien.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // ADOLESCENT (10-16 ans)
  // ═══════════════════════════════════════════════════════════════════════════
  'teen_01': ElternWissenText(
    question: 'Mon ado ne me parle plus',
    akut:
        'N\'insiste pas. Ne sois pas vexé·e. Montre ta présence sans attente. Reste disponible.',
    beduerfnis:
        'Les ados ont besoin de se démarquer pour construire leur identité. Le repli n\'est pas un rejet, c\'est du développement.',
    gfkSatz:
        'Je suis là si tu veux parler. Aucune pression. Je ne pose pas de questions — mais j\'écoute quand tu viens.',
    aktion: [
      'Proposer des activités communes SANS pression de conversation (cuisiner ensemble, un trajet en voiture)',
      'Ne pas combler chaque silence',
      'Partager tes propres émotions : « nos discussions me manquent parfois »',
    ],
    ermutigung:
        'Ton ado t\'aime. En ce moment il a besoin d\'espace. Garde la porte ouverte — il reviendra.',
  ),
  'teen_02': ElternWissenText(
    question: 'Mon ado ne respecte aucune règle',
    akut:
        'Moins de règles, mais plus claires. Demande-toi : quelles 3 règles sont VRAIMENT importantes ?',
    beduerfnis:
        'Les ados ont besoin d\'une autonomie grandissante. Trop de règles sont vécues comme du contrôle — et le contrôle crée de la résistance.',
    gfkSatz:
        'Je m\'inquiète parce que tu n\'étais pas à la maison à 23 h. Ta sécurité compte pour moi — pas le contrôle.',
    aktion: [
      'Négocier les règles ENSEMBLE (ne pas les dicter)',
      'Discuter des conséquences à l\'avance (pas sous le coup de l\'émotion)',
      'Distinguer : qu\'est-ce qui relève de la sécurité (non négociable) et qu\'est-ce qui relève des goûts (négociable) ?',
    ],
    ermutigung:
        'Les ados qui enfreignent les règles ne deviennent pas des délinquants. Ils deviennent adultes.',
  ),
  'teen_03': ElternWissenText(
    question: 'Je m\'inquiète pour l\'image que mon ado a de lui-même',
    akut:
        'Écoute sans relativiser. Pas : « mais tu es beau/belle ! » Mais : « raconte-moi en plus. »',
    beduerfnis:
        'À l\'adolescence, l\'image de soi est fragile. Les réseaux sociaux amplifient les comparaisons. Ton ado a besoin de mots-ancres qui NE jugent PAS l\'apparence.',
    gfkSatz:
        'Tu as de la valeur — non pas pour ton apparence mais pour ce que tu es.',
    aktion: [
      'Ne jamais commenter le corps (même positivement !)',
      'Nommer des forces qui n\'ont rien à voir avec l\'apparence',
      'Montrer l\'exemple soi-même : comment parles-TU de ton propre corps ?',
    ],
    ermutigung:
        'Ta voix deviendra la voix intérieure de ton enfant. Rends-la bienveillante.',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // GÉNÉRAL (tous les âges)
  // ═══════════════════════════════════════════════════════════════════════════
  'allg_01': ElternWissenText(
    question: 'Comment poser des limites sans punir',
    akut:
        'Une limite = ce dont TU as besoin, pas ce que l\'enfant fait de mal. « C\'est important pour moi que... » plutôt que « tu n\'as pas le droit ! »',
    beduerfnis:
        'Les enfants ont besoin de limites — mais bienveillantes. Les limites donnent des repères, les punitions créent de la peur.',
    gfkSatz:
        'Je ne laisse pas faire que tu me frappes. Non parce que tu es méchant — mais parce que mon corps compte pour moi.',
    aktion: [
      'Formuler les limites en message-JE (pas en reproche-TU)',
      'Des conséquences plutôt que des punitions (naturelles, pas arbitraires)',
      'Poser la limite ET reconnaître l\'émotion (« tu es fâché ET on y va maintenant »)',
    ],
    ermutigung:
        'Poser des limites, c\'EST de l\'amour. Ton enfant a besoin de ton guidage.',
  ),
  'allg_02': ElternWissenText(
    question: 'J\'ai l\'impression d\'être un mauvais parent',
    akut:
        'Tu es là. Tu cherches des réponses. C\'est tout le contraire d\'un mauvais parent.',
    beduerfnis:
        'La culpabilité parentale est partout. Les réseaux sociaux montrent des familles parfaites — qui n\'existent pas. Ton ressenti est humain.',
    gfkSatz:
        'Je suis assez bien. Mon enfant n\'a pas besoin de parfait — il a besoin de vrai.',
    aktion: [
      'Réduire les comparaisons (limiter les réseaux sociaux)',
      'Demander de l\'aide est une force (conseil, échange, soulagement)',
      'Chaque jour, nommer 1 chose qui s\'est bien passée',
    ],
    ermutigung:
        'Les parents parfaits, ça n\'existe pas. Les bons parents sont ceux qui réessaient encore et encore.',
  ),
  'allg_03': ElternWissenText(
    question: 'Mon enfant ne m\'écoute pas',
    akut:
        'Les enfants « écoutent » quand ils se SENTENT entendus. Mets-toi à sa hauteur. Touche son épaule. Puis parle.',
    beduerfnis:
        'Ne pas écouter est rarement du manque de respect. Souvent : l\'enfant est absorbé, surstimulé, ou la demande était trop complexe.',
    gfkSatz:
        'Hé, j\'ai besoin de ton attention un instant. Regarde-moi — je voudrais te dire quelque chose.',
    aktion: [
      'Se rapprocher plutôt que crier à travers la pièce',
      'Des phrases courtes et claires (pas « est-ce que tu rangerais un jour, s\'il te plaît... »)',
      'Prévenir : « dans 5 minutes on part — prépare-toi »',
    ],
    ermutigung:
        'Les enfants à qui l\'on s\'adresse à leur hauteur coopèrent 80 % mieux.',
  ),
  'allg_04': ElternWissenText(
    question: 'Comment expliquer une séparation à mon enfant',
    akut:
        'Le dire ensemble si possible. Message central : tu n\'y es pour rien. On t\'aime tous les deux.',
    beduerfnis:
        'Les enfants ont besoin : de sécurité (« où vais-je habiter ? »), d\'amour (« est-ce que les deux m\'aiment encore ? »), de prévisibilité (« qu\'est-ce qui change ? »).',
    gfkSatz:
        'Maman et papa ont décidé d\'habiter séparément. Ça n\'a rien à voir avec toi. On t\'aime tous les deux tout autant.',
    aktion: [
      'Adapté à l\'âge : des mots simples, peu de détails sur les raisons',
      'Du concret : qu\'est-ce qui reste pareil ? (l\'école, les amis, le doudou)',
      'Autoriser les émotions : « tu as le droit d\'être triste et en colère »',
    ],
    ermutigung:
        'Les enfants surmontent les séparations — quand les parents se traitent avec respect.',
  ),
  'allg_05': ElternWissenText(
    question: 'Comment renforcer la confiance en soi de mon enfant',
    akut:
        'Ne félicite pas CE qu\'il fait (« joli dessin ! ») — mais COMMENT il le vit (« tu es vraiment fier de ton dessin ! »).',
    beduerfnis:
        'La confiance en soi naît : du sentiment d\'efficacité (je SAIS faire), de l\'appartenance (j\'EN fais partie), de l\'autonomie (j\'ai le DROIT de décider).',
    gfkSatz:
        'Je vois à quel point tu t\'es appliqué. Comment ça se sent, pour toi ?',
    aktion: [
      'Laisser l\'enfant faire les choses TOUT SEUL (même si ça prend plus de temps)',
      'Féliciter le processus plutôt que le résultat (« tu n\'as pas abandonné — c\'était courageux »)',
      'Normaliser l\'erreur : « oups ! qu\'est-ce qu\'on pourrait faire autrement la prochaine fois ? »',
    ],
    ermutigung:
        'La confiance en soi grandit par l\'expérience — pas par les mots. Laisse ton enfant échouer et se relever.',
  ),
  'allg_06': ElternWissenText(
    question: 'Mon enfant a peur de l\'école',
    akut:
        'Prends la peur au sérieux. Pas : « ne fais pas tant d\'histoires. » Mais : « raconte-moi ce qui te préoccupe. »',
    beduerfnis:
        'La peur de l\'école peut avoir de nombreuses causes : conflits sociaux, débordement, l\'enseignant·e, la pression de la performance.',
    gfkSatz:
        'J\'entends que l\'école te semble difficile en ce moment. On va trouver une solution ensemble.',
    aktion: [
      'Demander précisément : QU\'est-ce qui fait peur ? (une matière ? une personne ? la récré ?)',
      'Impliquer l\'enseignant·e (sans mettre l\'enfant mal à l\'aise)',
      'Un rituel du matin qui rassure (un déroulé fixe, le petit-déjeuner préféré)',
    ],
    ermutigung:
        'La peur de l\'école se résout. Souvent, de petits changements suffisent pour un grand soulagement.',
  ),
  'allg_07': ElternWissenText(
    question: 'Comment amener mon enfant à se brosser les dents',
    akut:
        'Ne te bats pas. En jouant : « je peux brosser les dents du crocodile ? » ou « qui trouve le sucre caché ? »',
    beduerfnis:
        'Le brossage des dents est une lutte d\'autonomie (la bouche = la zone la plus intime). Ton enfant veut décider lui-même.',
    gfkSatz:
        'Tes dents ont besoin d\'aide. Tu veux commencer toi-même ou je commence ?',
    aktion: [
      'Des choix : quelle brosse à dents ? quelle chanson pendant ce temps ?',
      'Un minuteur / une chanson (une chanson de brossage de 2 minutes)',
      'Présenter le brossage de fin comme un rituel, pas comme une lutte de pouvoir',
    ],
    ermutigung:
        'Un jour, chaque enfant se brosse les dents de lui-même. En attendant : rester créatif.',
  ),
  'allg_08': ElternWissenText(
    question: 'Mon enfant s\'endort mal (enfant scolarisé)',
    akut:
        'La routine du soir est primordiale : la même heure, le même rituel, aucun écran 45 min avant.',
    beduerfnis:
        'Les enfants scolarisés sont souvent surstimulés par la journée. Leur tête a besoin d\'une transition entre « actif » et « repos ».',
    gfkSatz:
        'Ton corps a besoin de sommeil pour être fort demain. Qu\'est-ce qui t\'aide à redescendre ?',
    aktion: [
      'Une heure de coucher fixe (même le week-end, 1 h d\'écart maxi)',
      'Une routine : bain / brossage des dents / lecture / câlin / lumière éteinte',
      'Un temps pour les soucis : 5 min AVANT le lit « qu\'est-ce qui te préoccupe ? »',
    ],
    ermutigung:
        'Les problèmes de sommeil chez les enfants scolarisés sont souvent passagers (poussée de croissance, stress scolaire).',
  ),
  'allg_09': ElternWissenText(
    question: 'Mes enfants se disputent sans arrêt',
    akut:
        'Ne joue pas tout de suite l\'arbitre. Demande : avez-vous besoin de mon aide ou vous y arrivez tout seuls ?',
    beduerfnis:
        'Les disputes entre frères et sœurs sont NORMALES et importantes. Les enfants y apprennent : négocier, faire des compromis, changer de perspective.',
    gfkSatz:
        'Je vois que vous êtes frustrés tous les deux. De quoi chacun de vous a-t-il besoin en ce moment ?',
    aktion: [
      'N\'intervenir que si ça devient physique',
      'Ne prendre aucun parti (« qui a commencé ? » ne sert à rien)',
      'Valider l\'émotion de chaque enfant AVANT de chercher une solution',
    ],
    ermutigung:
        'Les frères et sœurs qui se disputent apprennent à résoudre les conflits. C\'est une compétence pour la vie.',
  ),
};
