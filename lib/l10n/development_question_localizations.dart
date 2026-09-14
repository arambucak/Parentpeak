import 'package:parentpeak/models/child_development_data.dart';

/// Localized copy for the development check-in question bank.
/// Covers every age group in [DevelopmentQuestionBank] for en/tr/ku.
List<DevDomain> localizeDevelopmentDomains(
  List<DevDomain> domains,
  String language,
  String ageGroupId,
) {
  final ageMap = _translations[language]?[ageGroupId];
  if (ageMap == null) return domains;

  return domains.map((domain) {
    final text = ageMap[domain.id];
    if (text == null) return domain;
    return DevDomain(
      id: domain.id,
      title: text.title,
      emoji: domain.emoji,
      color: domain.color,
      description: text.description,
      questions: text.questions,
      tips: text.tips,
    );
  }).toList();
}

class _DomainText {
  const _DomainText(this.title, this.description, this.questions, this.tips);

  final String title;
  final String description;
  final List<String> questions;
  final List<String> tips;
}

const Map<String, Map<String, Map<String, _DomainText>>> _translations = {
  'en': _en,
  'tr': _tr,
  'ku': _ku,
};

// ═══════════════════════════════════════════════════════════════════════
// ENGLISH
// ═══════════════════════════════════════════════════════════════════════
const Map<String, Map<String, _DomainText>> _en = {
  '0-12m': {
    'motorik': _DomainText(
      'Movement & Senses',
      'Grasping, rolling, crawling & first steps',
      [
        'Does your baby reach for objects intentionally?',
        'Does your baby roll from back to tummy (or the other way)?',
        'Can your baby sit (with or without support)?',
        'Does your baby crawl or scoot?',
        'Does your baby pull up on furniture?',
      ],
      [
        'Offer grasping toys with different textures',
        'Practice tummy time daily — it strengthens neck and back',
      ],
    ),
    'sprache': _DomainText(
      'Sounds & Understanding',
      'First sounds, response to speech & communication',
      [
        'Does your baby make different sounds (babbling, squealing)?',
        'Does your baby react to their name?',
        'Does your baby turn toward sounds?',
        'Does your baby laugh or squeal when you talk to them?',
        'Does your baby understand simple words like "no" or "wave bye-bye"?',
      ],
      [
        'Talk to your baby a lot — even during diaper changes and feeding',
        'Sing songs and repeat the sounds your baby makes',
      ],
    ),
    'denken': _DomainText(
      'Discovering & Understanding',
      'Curiosity, cause and effect & object permanence',
      [
        'Does your baby explore objects with hands and mouth?',
        'Does your baby look for things you hide?',
        'Does your baby bang or shake toys to make sounds?',
        'Does your baby watch faces and movements attentively?',
        'Does your baby point at things that interest them?',
      ],
      [
        'Play peekaboo — it trains object permanence',
        'Let your baby explore different materials (safely!)',
      ],
    ),
    'sozial': _DomainText(
      'Bonding & Feelings',
      'Attachment behavior, smiling & stranger anxiety',
      [
        'Does your baby smile at you intentionally?',
        'Does your baby seek eye contact with you?',
        'Does your baby show discomfort around strangers?',
        'Does your baby calm down when you pick them up?',
        'Does your baby reach out their arms to be picked up?',
      ],
      [
        'Respond reliably to crying — this builds secure attachment',
        'Physical closeness and skin contact matter most at this age',
      ],
    ),
    'selbst': _DomainText(
      'First Steps to Independence',
      'Eating, sleeping & simple self-directed activity',
      [
        'Can your baby hold and eat a cracker or piece of fruit by themselves?',
        'Does your baby drink from a cup (with help)?',
        'Does your baby show a sleep-wake rhythm?',
        'Can your baby occupy themselves alone for a short while?',
        'Does your baby show preferences (a certain toy, a certain person)?',
      ],
      [
        'Offer finger food — it supports fine motor skills and autonomy',
        'Fixed rituals (sleep, meals) provide security',
      ],
    ),
  },
  '1-2y': {
    'motorik': _DomainText(
      'Movement & Body',
      'Walking, climbing & first fine motor skills',
      [
        'Can your child walk unaided?',
        'Can your child bend down and stand back up?',
        'Does your child climb onto low furniture or stairs?',
        'Can your child scribble with a crayon?',
        'Does your child stack 2-3 blocks?',
        'Can your child roll or throw a ball?',
      ],
      [
        'Let your child walk barefoot often',
        'Offer stairs to practice on (supervised)',
        'Sand play and pouring water support fine motor skills',
      ],
    ),
    'sprache': _DomainText(
      'Language & Expression',
      'First words, pointing & understanding',
      [
        'Does your child say at least 10 recognizable words?',
        'Does your child point at things they want or want to show?',
        'Does your child understand simple instructions (come here, give me)?',
        'Does your child name familiar people (mama, papa)?',
        'Does your child shake or nod their head for yes/no?',
        'Does your child try to repeat words?',
      ],
      [
        'Name everything in everyday life — repetition is key',
        'Look at picture books daily and name what you see',
        'Don\'t correct, just repeat correctly: Child: "Woof!" — You: "Yes, a dog!"',
      ],
    ),
    'denken': _DomainText(
      'Thinking & Play',
      'Imitation, sorting & pretend play',
      [
        'Does your child imitate everyday actions (phoning, cooking)?',
        'Does your child understand what objects are for (comb = hair)?',
        'Can your child solve simple insert puzzles (1-3 pieces)?',
        'Does your child point at pictures in books when asked?',
        'Does your child actively search for hidden objects?',
        'Does your child sort things by size or shape?',
      ],
      [
        'Encourage pretend play: cooking doll food, changing teddy\'s diaper',
        'Let your child "help" in everyday tasks (loading the washing machine, stirring)',
      ],
    ),
    'sozial': _DomainText(
      'Feelings & Connection',
      'Showing emotions, comforting & first empathy',
      [
        'Does your child clearly show joy (clapping, jumping)?',
        'Does your child come to you when they need comfort?',
        'Does your child react when another child cries?',
        'Can your child show or say "no"?',
        'Does your child enjoy playing near other children?',
        'Does your child show pride when they accomplish something?',
      ],
      [
        'Name feelings: "You\'re happy!" / "That startled you"',
        'Comfort instead of distracting — feelings are allowed',
      ],
    ),
    'selbst': _DomainText(
      'Independence',
      'Eating, dressing & "doing it myself!"',
      [
        'Does your child eat independently with a spoon?',
        'Does your child drink alone from a cup?',
        'Does your child take off a hat or socks?',
        'Does your child show the wish to do things alone?',
        'Does your child put away toys (when asked)?',
        'Does your child show interest in the potty or toilet?',
      ],
      [
        'Be patient with the "myself!" wish — even if it takes longer',
        'Give small tasks: bringing shoes to the door, helping peel a banana',
      ],
    ),
  },
  '2-3y': {
    'motorik': _DomainText(
      'Movement & Body',
      'Gross motor, fine motor and body awareness',
      [
        'Can your child climb stairs safely (while holding on)?',
        'Can your child stand briefly on one leg?',
        'Can your child catch or throw a ball?',
        'Can your child copy simple shapes (circle, line)?',
        'Can your child eat independently with a spoon or fork?',
        'Does your child jump or hop spontaneously (for example over puddles)?',
      ],
      [
        'Build climbing opportunities into everyday life (playground, cushions)',
        'Playdough, threading beads or sand play support fine motor skills',
        'Let your child walk barefoot — it strengthens balance and body awareness',
      ],
    ),
    'sprache': _DomainText(
      'Language & Understanding',
      'Vocabulary, sentences and language comprehension',
      [
        'Does your child form two- or three-word sentences?',
        'Can your child answer simple questions (What? Where?)?',
        'Does your child name everyday objects correctly?',
        'Does your child understand simple instructions (Bring me the book)?',
        'Does your child sing or hum along to songs or melodies?',
        'Does your child tell you about experiences (even if not perfectly yet)?',
      ],
      [
        'Speak slowly and in short sentences — repeat words often',
        'Read aloud for 5-10 minutes every day and point at pictures',
        'Name everything you do: "I\'m cutting the banana"',
      ],
    ),
    'denken': _DomainText(
      'Thinking & Exploring',
      'Problem solving, curiosity and attention',
      [
        'Can your child solve simple puzzles (3-6 pieces)?',
        'Does your child sort things by color or size?',
        'Can your child stay with a task for longer than 2-3 minutes?',
        'Does your child show interest in looking at books?',
        'Does your child try to figure things out (What happens if...)?',
        'Can your child name or point to body parts?',
      ],
      [
        'Offer open-ended play materials (building blocks, sand, water)',
        'Turn why-questions back: "What do YOU think?" instead of just answering',
        'Don\'t interrupt focused play — even if it\'s "just" squishing mud',
      ],
    ),
    'sozial': _DomainText(
      'Feelings & Togetherness',
      'Emotions, empathy and social behavior',
      [
        'Does your child clearly show joy, anger or sadness?',
        'Does your child seek comfort from you when sad or hurt?',
        'Can your child tolerate short waiting times (with support)?',
        'Does your child play alongside or with other children?',
        'Does your child show empathy when someone cries or gets hurt?',
        'Does your child accept simple boundaries (even when protesting)?',
      ],
      [
        'Name feelings out loud: "You\'re angry because..." — this teaches emotional vocabulary',
        'Stay calm during tantrums — your calm is the model for regulation',
        'Parallel play (side by side) is completely normal and valuable at 2-3 years',
      ],
    ),
    'selbst': _DomainText(
      'Independence',
      'Everyday skills and doing things independently',
      [
        'Can your child partly dress independently (shoes, hat, jacket)?',
        'Can your child wash their hands independently?',
        'Does your child help with simple tasks (setting the table, tidying up)?',
        'Does your child show a wish to do things independently?',
        'Does your child know simple daily routines (first eat, then play)?',
        'Can your child say their name when asked?',
      ],
      [
        'Offer choices instead of instructions: "Red or blue jacket?"',
        'Allow mistakes — spilled milk is a learning moment, not a disaster',
        'Rituals provide security: the same routine morning and evening',
      ],
    ),
  },
  '3-4y': {
    'motorik': _DomainText(
      'Movement & Skill',
      'Balance, climbing & fine motor skills',
      [
        'Can your child ride a tricycle or balance bike?',
        'Can your child stand briefly on one leg?',
        'Can your child use scissors (simple cuts)?',
        'Does your child draw recognizable shapes (circle, cross)?',
        'Can your child thread beads or open buttons?',
        'Does your child jump off the ground with both feet?',
      ],
      [
        'Outdoor movement games: balancing on logs, hopping games',
        'Crafting with scissors and glue — even if it\'s not perfect',
      ],
    ),
    'sprache': _DomainText(
      'Language & Storytelling',
      'Sentences, asking questions & stories',
      [
        'Does your child speak in full sentences (4-5 words)?',
        'Does your child ask why-questions?',
        'Can your child tell you about experiences (even if jumbled)?',
        'Does your child understand prepositions (on, under, next to)?',
        'Does your child use plurals correctly (cars, balls)?',
        'Can your child recite simple rhymes or songs?',
      ],
      [
        'Take why-questions seriously — even if it\'s the 50th one',
        'Make up stories together: "And then...?"',
      ],
    ),
    'denken': _DomainText(
      'Thinking & Imagination',
      'Pretend play, counting & connections',
      [
        'Does your child play pretend (doctor, shop, family)?',
        'Can your child count to 5 or 10?',
        'Does your child understand simple connections (rain = wet)?',
        'Can your child name 3-4 colors?',
        'Does your child solve puzzles with 6-12 pieces?',
        'Does your child recognize patterns and continue them?',
      ],
      [
        'Pretend play is THE way of learning at this age — join in!',
        'Count in everyday life: stairs, apples, shoes',
      ],
    ),
    'sozial': _DomainText(
      'Feelings & Friendship',
      'Sharing, conflicts & frustration tolerance',
      [
        'Can your child play with other children (not just alongside them)?',
        'Can your child wait briefly for something they want?',
        'Can your child share toys (sometimes)?',
        'Does your child show empathy and comfort others?',
        'Can your child express disappointment without hitting?',
        'Does your child have first playmate friendships?',
      ],
      [
        'Sharing doesn\'t need to be forced — it comes with social maturity',
        'Support children through conflicts instead of solving them for them',
      ],
    ),
    'selbst': _DomainText(
      'Everyday Life & Responsibility',
      'Dressing, hygiene & small tasks',
      [
        'Can your child dress themselves for the most part?',
        'Does your child use the toilet independently (mostly)?',
        'Can your child brush their teeth (with follow-up brushing)?',
        'Does your child help with tasks (setting the table, watering flowers)?',
        'Does your child know daily routines and can name them?',
        'Can your child say their first and last name?',
      ],
      [
        'Let your child help with real tasks — not just play tasks',
        'Make routines visual: a picture schedule for morning/evening',
      ],
    ),
  },
  '4-6y': {
    'motorik': _DomainText(
      'Body & Coordination',
      'Sports, writing & dexterity',
      [
        'Can your child ride a bicycle (with or without training wheels)?',
        'Can your child write their name?',
        'Can your child cut along a line?',
        'Can your child catch a ball on purpose?',
        'Does your child hop on one leg several times?',
        'Can your child close small buttons?',
      ],
      [
        'Fine motor skills: beads, ironing, origami — fun instead of drilling',
        'At least 1 hour of outdoor movement daily',
      ],
    ),
    'sprache': _DomainText(
      'Language & Comprehension',
      'Storytelling, grammar & vocabulary',
      [
        'Does your child tell stories with a beginning, middle and end?',
        'Does your child use correct grammar (mostly)?',
        'Can your child understand or tell jokes?',
        'Does your child understand complex instructions (First..., then...)?',
        'Is your child interested in letters or reading?',
        'Can your child form rhymes or clap out syllables?',
      ],
      [
        'Reading aloud stays important — even if the child wants to "read" themselves',
        'Rhyming games and clapping syllables prepare for school',
      ],
    ),
    'denken': _DomainText(
      'Thinking & School Readiness',
      'Logic, concentration & preschool skills',
      [
        'Can your child stay with a task for 20 minutes?',
        'Does your child understand time concepts (yesterday, tomorrow, later)?',
        'Can your child compare simple quantities (more/less)?',
        'Does your child increasingly solve problems on their own?',
        'Can your child understand and follow rules in board games?',
        'Does your child show interest in numbers and counting?',
      ],
      [
        'Board games are ideal training for frustration tolerance and rules',
        'Don\'t push academics too early — playing IS learning',
      ],
    ),
    'sozial': _DomainText(
      'Social Skills & Empathy',
      'Friendships, rules & perspective-taking',
      [
        'Does your child have steady friendships?',
        'Can your child put themselves in someone else\'s shoes?',
        'Does your child follow rules (mostly)?',
        'Can your child resolve conflicts verbally (sometimes)?',
        'Does your child show a sense of responsibility for younger children or animals?',
        'Can your child lose without crying for more than 2-3 minutes?',
      ],
      [
        'Practice losing: play board games without deliberately letting them win',
        'Strengthen empathy: "How do you think the other child feels right now?"',
      ],
    ),
    'selbst': _DomainText(
      'Independence & Maturity',
      'Responsibility, planning & everyday skills',
      [
        'Can your child dress completely on their own?',
        'Can your child prepare simple meals (spreading bread)?',
        'Does your child know their address or phone number?',
        'Can your child go to the toilet alone (including wiping)?',
        'Can your child walk a short distance alone (e.g. to a neighbor\'s)?',
        'Can your child clearly communicate their own needs?',
      ],
      [
        'Give real responsibility: feeding a pet, tidying their room',
        'Practice the school route — step by step more autonomy',
      ],
    ),
  },
  '6-10y': {
    'motorik': _DomainText(
      'Body & Sports',
      'Coordination, stamina & fine motor skills',
      [
        'Can your child write fluently?',
        'Does your child enjoy sports or move with stamina?',
        'Can your child tie a bow?',
        'Does your child have good body coordination (swimming, climbing)?',
        'Can your child sit still for more than 30 minutes (at school)?',
      ],
      [
        'Sports should be fun — not about performance',
        'Limiting screen time = more natural movement',
      ],
    ),
    'sprache': _DomainText(
      'Language & Reading',
      'Reading, writing & expression',
      [
        'Does your child read age-appropriate texts fluently?',
        'Can your child tell stories in writing?',
        'Does your child express themselves in a nuanced way?',
        'Does your child understand irony or figurative meanings?',
        'Does your child tell you about school and experiences?',
      ],
      [
        'Read together — even if the child can already read alone',
        'Talk about the day: not just "How was school?"',
      ],
    ),
    'denken': _DomainText(
      'Learning & Thinking',
      'School, concentration & problem solving',
      [
        'Can your child mostly do homework independently?',
        'Does your child show curiosity and ask questions?',
        'Can your child explain connections logically?',
        'Does your child plan ahead (packing, time management)?',
        'Does your child handle mistakes constructively?',
      ],
      [
        'Mistakes are learning opportunities — discuss them instead of punishing',
        'Allow their own solution paths, even if they seem roundabout',
      ],
    ),
    'sozial': _DomainText(
      'Friendship & Feelings',
      'Friend group, conflicts & self-regulation',
      [
        'Does your child have stable friendships?',
        'Can your child resolve conflicts without violence?',
        'Can your child cope with disappointment and frustration?',
        'Does your child show empathy and willingness to help?',
        'Can your child name and explain their own feelings?',
      ],
      [
        'Not every situation needs to be solved for them — kids need their own conflict solutions too',
        'Validate feelings: "I understand that this bothers you"',
      ],
    ),
    'selbst': _DomainText(
      'Responsibility & Everyday Life',
      'Duties, sense of time & self-organization',
      [
        'Does your child regularly take on household chores?',
        'Can your child organize their school things themselves?',
        'Does your child have a sense of time (keeping to agreements)?',
        'Can your child walk to school alone?',
        'Does your child make age-appropriate decisions independently?',
      ],
      [
        'Pocket money from age 6-7 teaches responsibility for money',
        'Setting their own alarm, packing their own bag',
      ],
    ),
  },
  '10-14y': {
    'motorik': _DomainText(
      'Body & Health',
      'Puberty, body image & movement',
      [
        'Does your child move regularly (sports, biking, outdoors)?',
        'Does your child have a healthy relationship with their body?',
        'Does your child sleep enough (8-10 hours)?',
        'Does your child eat a mostly healthy diet?',
        'Does your child take care of body hygiene independently?',
      ],
      [
        'Lead by example: move together instead of giving instructions',
        'Normalize body changes — talk about them openly',
      ],
    ),
    'sprache': _DomainText(
      'Expression & Communication',
      'Arguing, reflecting & media literacy',
      [
        'Can your child express their opinion with reasons?',
        'Does your child read voluntarily (books, articles, comics)?',
        'Can your child discuss things objectively (mostly)?',
        'Does your child use media reflectively?',
        'Can your child talk about feelings when they want to?',
      ],
      [
        'Allow discussions — teenagers learn through counter-arguments',
        'Develop media literacy together, not just ban things',
      ],
    ),
    'denken': _DomainText(
      'Thinking & Learning',
      'Abstract thinking, planning & learning strategies',
      [
        'Can your child think abstractly (What if...)?',
        'Does your child organize schoolwork independently?',
        'Does your child have own interests they pursue in depth?',
        'Can your child think through consequences in advance?',
        'Does your child show intrinsic motivation for at least one topic?',
      ],
      [
        'Support their interests — even if not school-relevant',
        'Offer planning tools: calendar, to-do lists',
      ],
    ),
    'sozial': _DomainText(
      'Identity & Relationships',
      'Friend group, identity & boundaries',
      [
        'Does your child have stable friendships?',
        'Can your child resist peer pressure?',
        'Does your child show empathy for others (including strangers)?',
        'Can your child set and communicate boundaries?',
        'Is your child beginning to develop their own identity?',
      ],
      [
        'Puberty means pulling away. That\'s healthy, not disrespectful.',
        'Listen without immediately trying to fix things — presence is often enough',
      ],
    ),
    'selbst': _DomainText(
      'Autonomy & Responsibility',
      'Self-organization, money & decisions',
      [
        'Does your child take responsibility for their own tasks?',
        'Can your child handle money (pocket money)?',
        'Does your child make own decisions and bear the consequences?',
        'Can your child be out and about alone (city, public transport)?',
        'Does your child show reliability with agreements?',
      ],
      [
        'More freedom with more responsibility — negotiate instead of dictate',
        'Let them make mistakes — as long as safety is assured',
      ],
    ),
  },
  '14-18y': {
    'motorik': _DomainText(
      'Health & Wellbeing',
      'Body, sleep, nutrition & movement',
      [
        'Does your teenager move regularly?',
        'Does your teenager have a healthy sleep rhythm?',
        'Does your teenager eat mindfully?',
        'Does your teenager use substances responsibly (no misuse)?',
        'Does your teenager pay attention to mental health?',
      ],
      [
        'Don\'t control — lead by example',
        'Talk openly about mental health — remove the stigma',
      ],
    ),
    'sprache': _DomainText(
      'Expression & Reflection',
      'Self-reflection, argumentation & communication',
      [
        'Can your teenager express their thoughts clearly?',
        'Does your teenager reflect on their own behavior?',
        'Can your teenager accept feedback constructively?',
        'Does your teenager communicate respectfully (mostly)?',
        'Can your teenager take different perspectives?',
      ],
      [
        'Model respectful communication — even in conflicts',
        'Ask questions instead of accusations: "What do you need?" instead of "Why do you...?"',
      ],
    ),
    'denken': _DomainText(
      'Future & Orientation',
      'Career orientation, values & own goals',
      [
        'Does your teenager have ideas about their own future?',
        'Does your teenager show initiative (internships, projects)?',
        'Can your teenager name their own values?',
        'Does your teenager set their own goals?',
        'Can your teenager weigh up complex decisions?',
      ],
      [
        'Future plans don\'t have to be fixed — direction is enough',
        'Enable practical experience: internships, part-time jobs, volunteering',
      ],
    ),
    'sozial': _DomainText(
      'Relationships & Identity',
      'Partnership, identity & role in society',
      [
        'Does your teenager maintain healthy friendships?',
        'Can your teenager say no to peer pressure?',
        'Does your teenager treat relationships respectfully?',
        'Does your teenager show a stable self-image?',
        'Is your teenager engaged in something (social, political, creative)?',
      ],
      [
        'Finding an identity needs room — not every phase needs a comment',
        'Respect relationships — even if you don\'t like them',
      ],
    ),
    'selbst': _DomainText(
      'Independence & Maturity',
      'Life skills, finances & responsibility',
      [
        'Can your teenager run a household independently (cooking, laundry)?',
        'Does your teenager handle money responsibly?',
        'Can your teenager handle official errands or doctor\'s appointments alone?',
        'Does your teenager reliably keep commitments?',
        'Is your teenager ready for an increasingly independent life?',
      ],
      [
        'Actively teach life skills: cooking, tax returns, laundry',
        'Practice letting go — for both of you',
      ],
    ),
  },
};

// ═══════════════════════════════════════════════════════════════════════
// TÜRKÇE
// ═══════════════════════════════════════════════════════════════════════
const Map<String, Map<String, _DomainText>> _tr = {
  '0-12m': {
    'motorik': _DomainText(
      'Hareket ve Duyular',
      'Kavrama, dönme, emekleme ve ilk adımlar',
      [
        'Bebeğiniz eşyalara amaçlı bir şekilde uzanıyor mu?',
        'Bebeğiniz sırtüstünden yüzükoyuna (veya tersi) dönüyor mu?',
        'Bebeğiniz oturabiliyor mu (destekli veya desteksiz)?',
        'Bebeğiniz emekliyor veya sürünüyor mu?',
        'Bebeğiniz mobilyalara tutunarak ayağa kalkıyor mu?',
      ],
      [
        'Farklı dokularda kavrama oyuncakları sunun',
        'Her gün yüzükoyun pozisyonu uygulayın — boyun ve sırtı güçlendirir',
      ],
    ),
    'sprache': _DomainText(
      'Sesler ve Anlama',
      'İlk sesler, konuşmaya tepki ve iletişim',
      [
        'Bebeğiniz farklı sesler çıkarıyor mu (mırıldanma, ciyaklama)?',
        'Bebeğiniz adına tepki veriyor mu?',
        'Bebeğiniz seslere doğru dönüyor mu?',
        'Siz onunla konuşurken bebeğiniz gülüyor ya da sevinç sesleri çıkarıyor mu?',
        'Bebeğiniz "hayır" veya "bay bay" gibi basit kelimeleri anlıyor mu?',
      ],
      [
        'Bebeğinizle çok konuşun — bez değiştirirken ve beslerken de',
        'Şarkılar söyleyin ve bebeğinizin çıkardığı sesleri tekrarlayın',
      ],
    ),
    'denken': _DomainText(
      'Keşfetme ve Kavrama',
      'Merak, neden-sonuç ilişkisi ve nesne devamlılığı',
      [
        'Bebeğiniz eşyaları elleri ve ağzıyla inceliyor mu?',
        'Bebeğiniz sizin sakladığınız şeyleri arıyor mu?',
        'Bebeğiniz ses çıkarmak için oyuncaklara vuruyor veya sallıyor mu?',
        'Bebeğiniz yüzleri ve hareketleri dikkatle izliyor mu?',
        'Bebeğiniz ilgisini çeken şeyleri işaret ediyor mu?',
      ],
      [
        '"Ce-e" oyunu oynayın — bu nesne devamlılığını geliştirir',
        'Bebeğinizin farklı materyalleri keşfetmesine izin verin (güvenli şekilde!)',
      ],
    ),
    'sozial': _DomainText(
      'Bağlanma ve Duygular',
      'Bağlanma davranışı, gülümseme ve yabancı kaygısı',
      [
        'Bebeğiniz size bilinçli olarak gülümsüyor mu?',
        'Bebeğiniz sizinle göz teması arıyor mu?',
        'Bebeğiniz yabancı kişilerin yanında rahatsızlık gösteriyor mu?',
        'Bebeğiniz onu kucağınıza aldığınızda sakinleşiyor mu?',
        'Bebeğiniz kucağa alınmak için kollarını uzatıyor mu?',
      ],
      [
        'Ağlamaya güvenilir şekilde tepki verin — bu güvenli bağlanmayı destekler',
        'Bu yaşta en önemli şey fiziksel yakınlık ve ten teması',
      ],
    ),
    'selbst': _DomainText(
      'İlk Bağımsızlık Adımları',
      'Yeme, uyku ve basit bağımsız etkinlikler',
      [
        'Bebeğiniz bir bisküviyi veya meyve parçasını kendi başına tutup yiyebiliyor mu?',
        'Bebeğiniz bir bardaktan (yardımla) içebiliyor mu?',
        'Bebeğinizde bir uyku-uyanıklık ritmi var mı?',
        'Bebeğiniz kısa süreliğine kendi başına oyalanabiliyor mu?',
        'Bebeğiniz tercihler gösteriyor mu (belirli bir oyuncak, belirli bir kişi)?',
      ],
      [
        'Parmak yiyecekleri sunun — ince motor becerileri ve bağımsızlığı destekler',
        'Sabit ritüeller (uyku, yemek) güven verir',
      ],
    ),
  },
  '1-2y': {
    'motorik': _DomainText(
      'Hareket ve Vücut',
      'Yürüme, tırmanma ve ilk ince motor beceriler',
      [
        'Çocuğunuz serbestçe yürüyebiliyor mu?',
        'Çocuğunuz eğilip tekrar doğrulabiliyor mu?',
        'Çocuğunuz alçak mobilyalara veya merdivenlere tırmanıyor mu?',
        'Çocuğunuz bir kalemle karalama yapabiliyor mu?',
        'Çocuğunuz 2-3 küpü üst üste dizebiliyor mu?',
        'Çocuğunuz bir topu yuvarlayabiliyor veya atabiliyor mu?',
      ],
      [
        'Çocuğunuzun sık sık yalın ayak yürümesine izin verin',
        'Alıştırma için merdiven sunun (gözetim altında)',
        'Kum oyunu ve su dökme ince motor becerileri destekler',
      ],
    ),
    'sprache': _DomainText(
      'Dil ve İfade',
      'İlk kelimeler, işaret etme ve anlama',
      [
        'Çocuğunuz en az 10 tanınabilir kelime söylüyor mu?',
        'Çocuğunuz istediği veya göstermek istediği şeyleri işaret ediyor mu?',
        'Çocuğunuz basit talimatları anlıyor mu (buraya gel, bana ver)?',
        'Çocuğunuz tanıdık kişileri adlandırıyor mu (anne, baba)?',
        'Çocuğunuz evet/hayır için başını sallıyor veya öne eğiyor mu?',
        'Çocuğunuz kelimeleri tekrarlamaya çalışıyor mu?',
      ],
      [
        'Günlük hayatta her şeyi adlandırın — tekrar en önemli anahtardır',
        'Her gün resimli kitaplara bakın ve resimleri adlandırın',
        'Düzeltmek yerine doğrusunu tekrarlayın: Çocuk: "Hav hav!" — Siz: "Evet, bir köpek!"',
      ],
    ),
    'denken': _DomainText(
      'Düşünme ve Oyun',
      'Taklit, sıralama ve rol yapma',
      [
        'Çocuğunuz günlük eylemleri taklit ediyor mu (telefon etmek, yemek pişirmek)?',
        'Çocuğunuz eşyaların ne işe yaradığını anlıyor mu (tarak = saç)?',
        'Çocuğunuz basit yerleştirme yapbozlarını (1-3 parça) çözebiliyor mu?',
        'Sorduğunuzda çocuğunuz kitaplardaki resimleri işaret ediyor mu?',
        'Çocuğunuz saklanan eşyaları aktif olarak arıyor mu?',
        'Çocuğunuz eşyaları büyüklüğüne veya şekline göre sıralıyor mu?',
      ],
      [
        'Rol yapma oyununu destekleyin: bebeğe yemek pişirme, oyuncak ayıyı değiştirme',
        'Çocuğunuzun günlük işlerde "yardım etmesine" izin verin (çamaşır makinesini doldurmak, karıştırmak)',
      ],
    ),
    'sozial': _DomainText(
      'Duygular ve İletişim',
      'Duyguları gösterme, teselli etme ve ilk empati',
      [
        'Çocuğunuz sevincini açıkça gösteriyor mu (alkışlamak, zıplamak)?',
        'Çocuğunuz teselliye ihtiyaç duyduğunda size geliyor mu?',
        'Başka bir çocuk ağladığında çocuğunuz tepki veriyor mu?',
        'Çocuğunuz "hayır" diyebiliyor veya gösterebiliyor mu?',
        'Çocuğunuz diğer çocukların yanında oynamaktan hoşlanıyor mu?',
        'Çocuğunuz bir şeyi başardığında gurur gösteriyor mu?',
      ],
      [
        'Duyguları adlandırın: "Sen mutlusun!" / "Bu seni korkuttu"',
        'Dikkatini dağıtmak yerine teselli edin — duygulara izin verilmeli',
      ],
    ),
    'selbst': _DomainText(
      'Bağımsızlık',
      'Yeme, giyinme ve "kendim yaparım!"',
      [
        'Çocuğunuz kaşıkla kendi başına yemek yiyebiliyor mu?',
        'Çocuğunuz tek başına bir bardaktan içebiliyor mu?',
        'Çocuğunuz şapkasını veya çoraplarını çıkarabiliyor mu?',
        'Çocuğunuz bir şeyleri tek başına yapma isteği gösteriyor mu?',
        'Çocuğunuz (istendiğinde) oyuncakları topluyor mu?',
        'Çocuğunuz lazımlığa veya tuvalete ilgi gösteriyor mu?',
      ],
      [
        '"Kendim yaparım!" isteğine karşı sabırlı olun — daha uzun sürse de',
        'Küçük görevler verin: ayakkabıları kapıya getirmek, muz soymaya yardım etmek',
      ],
    ),
  },
  '2-3y': {
    'motorik': _DomainText(
      'Hareket ve Beden',
      'Kaba motor, ince motor ve beden farkındalığı',
      [
        'Çocuğunuz merdivenleri güvenli bir şekilde (tutunarak) çıkabiliyor mu?',
        'Çocuğunuz kısa süre tek ayak üzerinde durabiliyor mu?',
        'Çocuğunuz topu yakalayabiliyor veya atabiliyor mu?',
        'Çocuğunuz basit şekilleri (daire, çizgi) çizebiliyor mu?',
        'Çocuğunuz kaşık veya çatalla kendi başına yemek yiyebiliyor mu?',
        'Çocuğunuz kendiliğinden zıplıyor veya sıçrıyor mu (örneğin su birikintilerinin üzerinden)?',
      ],
      [
        'Günlük hayata tırmanma fırsatları ekleyin (oyun parkı, minderler)',
        'Oyun hamuru, boncuk dizme veya kum oyunu ince motor becerileri destekler',
        'Çocuğunuzun yalın ayak yürümesine izin verin — bu dengeyi ve beden farkındalığını güçlendirir',
      ],
    ),
    'sprache': _DomainText(
      'Dil ve Anlama',
      'Kelime dağarcığı, cümle kurma ve dil anlama',
      [
        'Çocuğunuz iki veya üç kelimelik cümleler kurabiliyor mu?',
        'Çocuğunuz basit soruları (Ne? Nerede?) yanıtlayabiliyor mu?',
        'Çocuğunuz günlük eşyaların adlarını doğru söyleyebiliyor mu?',
        'Çocuğunuz basit yönergeleri (Kitabı bana getir) anlayabiliyor mu?',
        'Çocuğunuz şarkılara veya melodilere eşlik ederek şarkı söylüyor ya da mırıldanıyor mu?',
        'Çocuğunuz yaşadıklarını anlatabiliyor mu (henüz tam düzgün olmasa da)?',
      ],
      [
        'Yavaş ve kısa cümlelerle konuşun — kelimeleri sık sık tekrarlayın',
        'Her gün 5-10 dakika kitap okuyun ve resimleri gösterin',
        'Yaptığınız her şeyi adlandırın: "Muzu kesiyorum"',
      ],
    ),
    'denken': _DomainText(
      'Düşünme ve Keşfetme',
      'Problem çözme, merak ve dikkat',
      [
        'Çocuğunuz basit yapbozları (3–6 parça) çözebiliyor mu?',
        'Çocuğunuz eşyaları renklerine veya boyutlarına göre ayırabiliyor mu?',
        'Çocuğunuz bir göreve 2–3 dakikadan uzun süre odaklanabiliyor mu?',
        'Çocuğunuz kitaplara bakmaya ilgi gösteriyor mu?',
        'Çocuğunuz bir şeyleri keşfetmeye çalışıyor mu (Ne olur acaba...)?',
        'Çocuğunuz vücut bölümlerini söyleyebiliyor veya gösterebiliyor mu?',
      ],
      [
        'Açık uçlu oyun malzemeleri sunun (yapı blokları, kum, su)',
        'Neden sorularını yanıtlamak yerine geri sorun: "SEN ne düşünüyorsun?"',
        'Yoğunlaşmış oyunu bölmeyin — "sadece" çamurla oynasa bile',
      ],
    ),
    'sozial': _DomainText(
      'Duygular ve Birlikte Yaşam',
      'Duygular, empati ve sosyal davranış',
      [
        'Çocuğunuz sevinç, öfke veya üzüntüsünü açıkça gösteriyor mu?',
        'Çocuğunuz üzgün veya yaralı olduğunda sizden teselli istiyor mu?',
        'Çocuğunuz kısa bekleme sürelerine (destekle) dayanabiliyor mu?',
        'Çocuğunuz diğer çocukların yanında veya onlarla birlikte oynuyor mu?',
        'Çocuğunuz biri ağladığında veya canı yandığında empati gösteriyor mu?',
        'Çocuğunuz basit sınırları (itiraz etse bile) kabul ediyor mu?',
      ],
      [
        'Duyguları yüksek sesle adlandırın: "Kızgınsın çünkü..." — bu duygu kelime dağarcığını öğretir',
        'Öfke nöbetlerinde sakin kalın — sakinliğiniz düzenleme için örnektir',
        'Paralel oyun (yan yana oynama) 2-3 yaş için tamamen normal ve değerlidir',
      ],
    ),
    'selbst': _DomainText(
      'Bağımsızlık',
      'Günlük yaşam becerileri ve kendi başına yapma',
      [
        'Çocuğunuz kısmen kendi başına giyinebiliyor mu (ayakkabı, şapka, ceket)?',
        'Çocuğunuz ellerini kendi başına yıkayabiliyor mu?',
        'Çocuğunuz basit işlere yardım ediyor mu (masa kurmak, toplamak)?',
        'Çocuğunuz bazı şeyleri kendi başına yapmak istediğini gösteriyor mu?',
        'Çocuğunuz basit günlük rutinleri biliyor mu (önce yemek, sonra oyun)?',
        'Çocuğunuz sorulduğunda adını söyleyebiliyor mu?',
      ],
      [
        'Talimat yerine seçenek sunun: "Kırmızı mı mavi mi ceket?"',
        'Hatalara izin verin — dökülen süt bir felaket değil, bir öğrenme anıdır',
        'Ritüeller güven verir: sabah ve akşam aynı rutin',
      ],
    ),
  },
  '3-4y': {
    'motorik': _DomainText(
      'Hareket ve Beceri',
      'Denge, tırmanma ve ince motor beceriler',
      [
        'Çocuğunuz üç tekerlekli bisiklet veya denge bisikleti sürebiliyor mu?',
        'Çocuğunuz kısa süre tek ayak üzerinde durabiliyor mu?',
        'Çocuğunuz makas kullanabiliyor mu (basit kesimler)?',
        'Çocuğunuz tanınabilir şekiller çiziyor mu (daire, artı)?',
        'Çocuğunuz boncuk dizebiliyor veya düğme açabiliyor mu?',
        'Çocuğunuz her iki ayağıyla birden yerden zıplayabiliyor mu?',
      ],
      [
        'Dışarıda hareket oyunları: ağaç gövdelerinde denge kurma, zıplama oyunları',
        'Makas ve yapıştırıcıyla el işi — mükemmel olmasa bile',
      ],
    ),
    'sprache': _DomainText(
      'Dil ve Anlatma',
      'Cümleler, soru sorma ve hikayeler',
      [
        'Çocuğunuz tam cümlelerle konuşuyor mu (4-5 kelime)?',
        'Çocuğunuz neden sorularını soruyor mu?',
        'Çocuğunuz yaşadıklarını anlatabiliyor mu (karışık olsa da)?',
        'Çocuğunuz edatları anlıyor mu (üstünde, altında, yanında)?',
        'Çocuğunuz çoğul eki doğru kullanıyor mu (arabalar, toplar)?',
        'Çocuğunuz basit tekerlemeler veya şarkılar söyleyebiliyor mu?',
      ],
      [
        'Neden sorularını ciddiye alın — 50. neden sorusu olsa bile',
        'Birlikte hikaye uydurun: "Ve sonra...?"',
      ],
    ),
    'denken': _DomainText(
      'Düşünme ve Hayal Gücü',
      'Rol yapma, sayma ve ilişkiler',
      [
        'Çocuğunuz rol yapma oyunları oynuyor mu (doktor, market, aile)?',
        'Çocuğunuz 5\'e veya 10\'a kadar sayabiliyor mu?',
        'Çocuğunuz basit ilişkileri anlıyor mu (yağmur yağarsa = ıslanır)?',
        'Çocuğunuz 3-4 rengi adlandırabiliyor mu?',
        'Çocuğunuz 6-12 parçalı yapbozları çözebiliyor mu?',
        'Çocuğunuz desenleri tanıyor ve devam ettirebiliyor mu?',
      ],
      [
        'Rol yapma oyunu bu yaşta ASIL öğrenme biçimidir — siz de katılın!',
        'Günlük hayatta sayın: merdiven basamakları, elmalar, ayakkabılar',
      ],
    ),
    'sozial': _DomainText(
      'Duygular ve Arkadaşlık',
      'Paylaşma, çatışmalar ve hayal kırıklığına tahammül',
      [
        'Çocuğunuz diğer çocuklarla oynayabiliyor mu (sadece yan yana değil)?',
        'Çocuğunuz istediği bir şey için kısa süre bekleyebiliyor mu?',
        'Çocuğunuz oyuncaklarını paylaşabiliyor mu (bazen)?',
        'Çocuğunuz empati gösteriyor ve başkalarını teselli ediyor mu?',
        'Çocuğunuz vurmadan hayal kırıklığını ifade edebiliyor mu?',
        'Çocuğunuzun ilk oyun arkadaşlıkları var mı?',
      ],
      [
        'Paylaşmayı zorlamaya gerek yok — bu, sosyal olgunlukla gelir',
        'Çocuklar arasındaki çatışmalara eşlik edin, onları sizin için çözmeyin',
      ],
    ),
    'selbst': _DomainText(
      'Günlük Yaşam ve Sorumluluk',
      'Giyinme, hijyen ve küçük görevler',
      [
        'Çocuğunuz büyük ölçüde kendi kendine giyinebiliyor mu?',
        'Çocuğunuz tuvalete bağımsız olarak gidiyor mu (çoğunlukla)?',
        'Çocuğunuz dişlerini fırçalayabiliyor mu (sonradan yardımla)?',
        'Çocuğunuz görevlerde yardım ediyor mu (masa kurmak, çiçek sulamak)?',
        'Çocuğunuz günlük rutinleri biliyor ve adlandırabiliyor mu?',
        'Çocuğunuz adını ve soyadını söyleyebiliyor mu?',
      ],
      [
        'Çocuğunuzun sadece oyun görevlerinde değil, gerçek görevlerde de yardım etmesine izin verin',
        'Rutinleri görsel hale getirin: sabah/akşam için resimli plan',
      ],
    ),
  },
  '4-6y': {
    'motorik': _DomainText(
      'Vücut ve Koordinasyon',
      'Spor, yazma ve beceri',
      [
        'Çocuğunuz bisiklet sürebiliyor mu (yardımcı tekerlekli veya tekerleksiz)?',
        'Çocuğunuz kendi adını yazabiliyor mu?',
        'Çocuğunuz bir çizgi boyunca kesebiliyor mu?',
        'Çocuğunuz bir topu bilerek yakalayabiliyor mu?',
        'Çocuğunuz tek ayak üzerinde birkaç kez zıplayabiliyor mu?',
        'Çocuğunuz küçük düğmeleri ilikleyebiliyor mu?',
      ],
      [
        'İnce motor beceriler: boncuk, ütü, origami — baskı yerine eğlence',
        'Her gün en az 1 saat dışarıda hareket',
      ],
    ),
    'sprache': _DomainText(
      'Dil ve Anlama',
      'Anlatma, dil bilgisi ve kelime dağarcığı',
      [
        'Çocuğunuz başı, ortası ve sonu olan hikayeler anlatıyor mu?',
        'Çocuğunuz doğru dil bilgisi kullanıyor mu (çoğunlukla)?',
        'Çocuğunuz şakaları anlayabiliyor veya anlatabiliyor mu?',
        'Çocuğunuz karmaşık talimatları anlıyor mu (Önce..., sonra...)?',
        'Çocuğunuz harflere veya okumaya ilgi duyuyor mu?',
        'Çocuğunuz kafiyeler oluşturabiliyor veya hece alkışlayabiliyor mu?',
      ],
      [
        'Sesli okuma önemini koruyor — çocuk kendisi "okumak" istese bile',
        'Kafiye oyunları ve hece alkışlama okula hazırlar',
      ],
    ),
    'denken': _DomainText(
      'Düşünme ve Okul Olgunluğu',
      'Mantık, dikkat ve okul öncesi beceriler',
      [
        'Çocuğunuz bir görevde 20 dakika kalabiliyor mu?',
        'Çocuğunuz zaman kavramlarını anlıyor mu (dün, yarın, sonra)?',
        'Çocuğunuz basit miktarları karşılaştırabiliyor mu (daha çok/daha az)?',
        'Çocuğunuz sorunları giderek daha fazla kendi başına çözüyor mu?',
        'Çocuğunuz masa oyunlarındaki kuralları anlayıp uyabiliyor mu?',
        'Çocuğunuz sayılara ve saymaya ilgi gösteriyor mu?',
      ],
      [
        'Masa oyunları, hayal kırıklığına tahammül ve kurallar için ideal antrenmandır',
        'Çok erken akademik baskı yapmayın — oyun oynamak öğrenmenin ta kendisidir',
      ],
    ),
    'sozial': _DomainText(
      'Sosyal Beceriler ve Empati',
      'Arkadaşlıklar, kurallar ve bakış açısı alma',
      [
        'Çocuğunuzun sabit arkadaşlıkları var mı?',
        'Çocuğunuz kendini başkasının yerine koyabiliyor mu?',
        'Çocuğunuz kurallara uyuyor mu (çoğunlukla)?',
        'Çocuğunuz çatışmaları sözlü olarak çözebiliyor mu (bazen)?',
        'Çocuğunuz küçükler veya hayvanlar için sorumluluk duygusu gösteriyor mu?',
        'Çocuğunuz 2-3 dakikadan uzun ağlamadan kaybedebiliyor mu?',
      ],
      [
        'Kaybetmeyi alıştırın: masa oyunları oynayın, bilerek kaybetmesine izin vermeyin',
        'Empatiyi güçlendirin: "Diğer çocuk şu anda nasıl hissediyor olabilir?"',
      ],
    ),
    'selbst': _DomainText(
      'Bağımsızlık ve Olgunluk',
      'Sorumluluk, planlama ve günlük beceriler',
      [
        'Çocuğunuz tamamen kendi başına giyinebiliyor mu?',
        'Çocuğunuz basit yemekler hazırlayabiliyor mu (ekmeğe bir şey sürmek)?',
        'Çocuğunuz adresini veya telefon numarasını biliyor mu?',
        'Çocuğunuz tek başına tuvalete gidebiliyor mu (temizlenme dahil)?',
        'Çocuğunuz tek başına kısa bir yolu yürüyebiliyor mu (örneğin komşuya)?',
        'Çocuğunuz kendi ihtiyaçlarını açıkça ifade edebiliyor mu?',
      ],
      [
        'Gerçek sorumluluk verin: evcil hayvanı beslemek, odasını toplamak',
        'Okul yolunu alıştırın — adım adım daha fazla bağımsızlık',
      ],
    ),
  },
  '6-10y': {
    'motorik': _DomainText(
      'Vücut ve Spor',
      'Koordinasyon, dayanıklılık ve ince motor beceriler',
      [
        'Çocuğunuz akıcı bir şekilde yazabiliyor mu?',
        'Çocuğunuz spor yapmaktan hoşlanıyor mu veya dayanıklı bir şekilde hareket ediyor mu?',
        'Çocuğunuz fiyonk bağlayabiliyor mu?',
        'Çocuğunuzun vücut koordinasyonu iyi mi (yüzme, tırmanma)?',
        'Çocuğunuz 30 dakikadan uzun süre yerinde oturabiliyor mu (okulda)?',
      ],
      [
        'Spor eğlenceli olmalı — performans için değil',
        'Ekran süresini sınırlamak = daha doğal hareket',
      ],
    ),
    'sprache': _DomainText(
      'Dil ve Okuma',
      'Okuma, yazma ve ifade',
      [
        'Çocuğunuz yaşına uygun metinleri akıcı okuyor mu?',
        'Çocuğunuz hikayeleri yazılı olarak anlatabiliyor mu?',
        'Çocuğunuz kendini ayrıntılı bir şekilde ifade ediyor mu?',
        'Çocuğunuz ironi veya mecazi anlamları anlıyor mu?',
        'Çocuğunuz okuldan ve yaşadıklarından bahsediyor mu?',
      ],
      [
        'Birlikte okuyun — çocuk kendi başına okuyabiliyor olsa bile',
        'Gün hakkında konuşun: sadece "Okul nasıldı?" değil',
      ],
    ),
    'denken': _DomainText(
      'Öğrenme ve Düşünme',
      'Okul, dikkat ve problem çözme',
      [
        'Çocuğunuz ödevlerini büyük ölçüde kendi başına yapabiliyor mu?',
        'Çocuğunuz merak gösteriyor ve sorular soruyor mu?',
        'Çocuğunuz ilişkileri mantıklı bir şekilde açıklayabiliyor mu?',
        'Çocuğunuz önceden plan yapıyor mu (eşya hazırlama, zaman yönetimi)?',
        'Çocuğunuz hatalarla yapıcı bir şekilde başa çıkıyor mu?',
      ],
      [
        'Hatalar öğrenme fırsatlarıdır — cezalandırmak yerine konuşun',
        'Dolambaçlı görünse bile kendi çözüm yollarına izin verin',
      ],
    ),
    'sozial': _DomainText(
      'Arkadaşlık ve Duygular',
      'Arkadaş çevresi, çatışmalar ve öz düzenleme',
      [
        'Çocuğunuzun sağlam arkadaşlıkları var mı?',
        'Çocuğunuz çatışmaları şiddet olmadan çözebiliyor mu?',
        'Çocuğunuz hayal kırıklığı ve öfkeyle başa çıkabiliyor mu?',
        'Çocuğunuz empati ve yardımseverlik gösteriyor mu?',
        'Çocuğunuz kendi duygularını adlandırıp açıklayabiliyor mu?',
      ],
      [
        'Her durumu çözmeyin — çocukların kendi çatışma çözümlerine de ihtiyacı var',
        'Duyguları onaylayın: "Bunun seni rahatsız ettiğini anlıyorum"',
      ],
    ),
    'selbst': _DomainText(
      'Sorumluluk ve Günlük Yaşam',
      'Görevler, zaman duygusu ve kendi kendini organize etme',
      [
        'Çocuğunuz düzenli olarak ev işlerinde sorumluluk alıyor mu?',
        'Çocuğunuz okul eşyalarını kendi başına düzenleyebiliyor mu?',
        'Çocuğunuzda zaman duygusu var mı (anlaşmalara uyma)?',
        'Çocuğunuz tek başına okula gidebiliyor mu?',
        'Çocuğunuz yaşına uygun kararları kendisi alıyor mu?',
      ],
      [
        '6-7 yaşından itibaren harçlık, para sorumluluğunu öğretir',
        'Kendi alarmını kurmak, kendi çantasını hazırlamak',
      ],
    ),
  },
  '10-14y': {
    'motorik': _DomainText(
      'Vücut ve Sağlık',
      'Ergenlik, beden algısı ve hareket',
      [
        'Çocuğunuz düzenli olarak hareket ediyor mu (spor, bisiklet, dışarıda)?',
        'Çocuğunuzun bedeniyle sağlıklı bir ilişkisi var mı?',
        'Çocuğunuz yeterince uyuyor mu (8-10 saat)?',
        'Çocuğunuz büyük ölçüde sağlıklı besleniyor mu?',
        'Çocuğunuz kendi başına vücut hijyenine dikkat ediyor mu?',
      ],
      [
        'Örnek olun: talimat vermek yerine birlikte hareket edin',
        'Beden değişikliklerini normalleştirin — bunlar hakkında açıkça konuşun',
      ],
    ),
    'sprache': _DomainText(
      'İfade ve İletişim',
      'Tartışma, öz yansıtma ve medya okuryazarlığı',
      [
        'Çocuğunuz görüşünü gerekçelendirerek ifade edebiliyor mu?',
        'Çocuğunuz gönüllü olarak okuyor mu (kitaplar, makaleler, çizgi romanlar)?',
        'Çocuğunuz nesnel bir şekilde tartışabiliyor mu (çoğunlukla)?',
        'Çocuğunuz medyayı sorgulayarak kullanıyor mu?',
        'Çocuğunuz istediğinde duygular hakkında konuşabiliyor mu?',
      ],
      [
        'Tartışmalara izin verin — gençler karşı görüşle öğrenir',
        'Medya okuryazarlığını sadece yasaklamak yerine birlikte geliştirin',
      ],
    ),
    'denken': _DomainText(
      'Düşünme ve Öğrenme',
      'Soyut düşünme, planlama ve öğrenme stratejileri',
      [
        'Çocuğunuz soyut düşünebiliyor mu (Ya ... olsaydı)?',
        'Çocuğunuz okul çalışmasını kendi başına organize ediyor mu?',
        'Çocuğunuzun derinlemesine ilgilendiği kendi ilgi alanları var mı?',
        'Çocuğunuz sonuçları önceden düşünebiliyor mu?',
        'Çocuğunuz en az bir konu için içsel motivasyon gösteriyor mu?',
      ],
      [
        'İlgi alanlarını destekleyin — okulla ilgili olmasa bile',
        'Planlama araçları sunun: takvim, yapılacaklar listesi',
      ],
    ),
    'sozial': _DomainText(
      'Kimlik ve İlişkiler',
      'Arkadaş çevresi, kimlik ve sınır koyma',
      [
        'Çocuğunuzun sağlam arkadaşlıkları var mı?',
        'Çocuğunuz grup baskısına direnebiliyor mu?',
        'Çocuğunuz başkalarına (yabancılar dahil) empati gösteriyor mu?',
        'Çocuğunuz sınırlar koyup bunları iletebiliyor mu?',
        'Çocuğunuz kendi kimliğini geliştirmeye başlıyor mu?',
      ],
      [
        'Ergenlik = sınır koyma. Bu saygısızlık değil, sağlıklıdır.',
        'Hemen çözüm üretmeden dinleyin — genellikle sadece orada olmak yeterlidir',
      ],
    ),
    'selbst': _DomainText(
      'Özerklik ve Sorumluluk',
      'Kendi kendini organize etme, para ve kararlar',
      [
        'Çocuğunuz kendi görevleri için sorumluluk alıyor mu?',
        'Çocuğunuz parayla başa çıkabiliyor mu (harçlık)?',
        'Çocuğunuz kendi kararlarını alıp sonuçlarına katlanıyor mu?',
        'Çocuğunuz tek başına dışarıda olabiliyor mu (şehir, toplu taşıma)?',
        'Çocuğunuz anlaşmalara güvenilirlik gösteriyor mu?',
      ],
      [
        'Daha fazla sorumlulukla daha fazla özgürlük — dikte etmek yerine müzakere edin',
        'Güvenlik sağlandığı sürece hata yapmalarına izin verin',
      ],
    ),
  },
  '14-18y': {
    'motorik': _DomainText(
      'Sağlık ve İyi Oluş',
      'Beden, uyku, beslenme ve hareket',
      [
        'Ergeniniz düzenli olarak hareket ediyor mu?',
        'Ergeninizin sağlıklı bir uyku düzeni var mı?',
        'Ergeniniz bilinçli besleniyor mu?',
        'Ergeniniz sorumlu bir şekilde tüketiyor mu (kötüye kullanım yok)?',
        'Ergeniniz ruh sağlığına dikkat ediyor mu?',
      ],
      [
        'Kontrol etmek yerine örnek olun',
        'Ruh sağlığı hakkında açıkça konuşun — damgalamayı ortadan kaldırın',
      ],
    ),
    'sprache': _DomainText(
      'İfade ve Öz Yansıtma',
      'Öz yansıtma, tartışma ve iletişim',
      [
        'Ergeniniz düşüncelerini net bir şekilde ifade edebiliyor mu?',
        'Ergeniniz kendi davranışını değerlendirebiliyor mu?',
        'Ergeniniz geri bildirimi yapıcı bir şekilde kabul edebiliyor mu?',
        'Ergeniniz saygılı bir şekilde iletişim kuruyor mu (çoğunlukla)?',
        'Ergeniniz farklı bakış açıları alabiliyor mu?',
      ],
      [
        'Çatışmalarda bile saygılı iletişime örnek olun',
        'Suçlama yerine soru sorun: "Neye ihtiyacın var?" yerine "Neden ... yapıyorsun?"',
      ],
    ),
    'denken': _DomainText(
      'Gelecek ve Yönelim',
      'Meslek yönelimi, değerler ve kendi hedefleri',
      [
        'Ergeninizin kendi geleceğiyle ilgili fikirleri var mı?',
        'Ergeniniz kendi inisiyatifini gösteriyor mu (stajlar, projeler)?',
        'Ergeniniz kendi değerlerini adlandırabiliyor mu?',
        'Ergeniniz kendi hedeflerini belirliyor mu?',
        'Ergeniniz karmaşık kararları tartabiliyor mu?',
      ],
      [
        'Gelecek planlarının kesin olması gerekmez — yön yeterlidir',
        'Pratik deneyimlere olanak tanıyın: stajlar, yarı zamanlı işler, gönüllülük',
      ],
    ),
    'sozial': _DomainText(
      'İlişkiler ve Kimlik',
      'Partnerlik, kimlik ve toplumsal rol',
      [
        'Ergeniniz sağlıklı arkadaşlıklar sürdürüyor mu?',
        'Ergeniniz grup baskısına hayır diyebiliyor mu?',
        'Ergeniniz ilişkilere saygılı bir şekilde yaklaşıyor mu?',
        'Ergeniniz istikrarlı bir öz imgeye sahip mi?',
        'Ergeniniz bir şey için (sosyal, siyasi, yaratıcı) kendini adıyor mu?',
      ],
      [
        'Kimlik arayışı alan gerektirir — her aşamayı yorumlamayın',
        'İlişkilere saygı gösterin — hoşunuza gitmese bile',
      ],
    ),
    'selbst': _DomainText(
      'Bağımsızlık ve Olgunluk',
      'Yaşam becerileri, finans ve sorumluluk',
      [
        'Ergeniniz bağımsız olarak bir ev idare edebiliyor mu (yemek, çamaşır)?',
        'Ergeniniz parayla sorumlu bir şekilde başa çıkıyor mu?',
        'Ergeniniz resmi işleri veya doktor randevularını tek başına halledebiliyor mu?',
        'Ergeniniz taahhütlerini güvenilir bir şekilde yerine getiriyor mu?',
        'Ergeniniz giderek daha bağımsız bir hayata hazır mı?',
      ],
      [
        'Yaşam becerilerini aktif olarak öğretin: yemek pişirme, vergi beyannamesi, çamaşır',
        'Bırakmayı alıştırın — ikiniz için de',
      ],
    ),
  },
};

// ═══════════════════════════════════════════════════════════════════════
// KURMANCÎ
// ═══════════════════════════════════════════════════════════════════════
const Map<String, Map<String, _DomainText>> _ku = {
  '0-12m': {
    'motorik': _DomainText(
      'Tevger û Hest',
      'Girtin, zivirîn, xwe kişandin û gavên ewilî',
      [
        'Pitikê te bi armanc dest datîne ser tiştan?',
        'Pitikê te ji pişt ber diçe ser zik (an berevajî)?',
        'Pitikê te dikare rûne (bi alîkarî an bêyî alîkarî)?',
        'Pitikê te dixize an xwe dikişîne?',
        'Pitikê te xwe li mobîlyayan hildikişîne?',
      ],
      [
        'Listikên girtinê yên bi cûrbicûr tekstûran pêşkêş bike',
        'Rojane rewşa li ser zikê biceribîne — stûyê û pişt xurt dike',
      ],
    ),
    'sprache': _DomainText(
      'Deng û Fêmkirin',
      'Dengên ewilî, bersiva zimanî û ragihandin',
      [
        'Pitikê te dengên cihê derdixe (mirmirandin, qîrîn)?',
        'Pitikê te li ser navê xwe bersiv dide?',
        'Pitikê te xwe berbi dengan vedizivirîne?',
        'Pitikê te dema tu pê re diaxivî dikene an bi kêfxweşî diqîre?',
        'Pitikê te peyvên hêsan mîna "Na" an "Bi xatirê te" fêm dike?',
      ],
      [
        'Pir bi pitikê xwe re biaxive — di guherandina pêçekê û xwarinê de jî',
        'Stranan bibêje û dengên ku pitikê te derdixe dubare bike',
      ],
    ),
    'denken': _DomainText(
      'Vedîtin û Têgihiştin',
      'Meraq, sedem-encam û mayîna heyberan',
      [
        'Pitikê te tiştan bi dest û devê xwe lêkolîn dike?',
        'Pitikê te li tiştên ku tu veşêrî digere?',
        'Pitikê te listikan lêdixe an dihejîne da ku deng çêbike?',
        'Pitikê te bi baldarî li rû û tevgeran temaşe dike?',
        'Pitikê te tiştên eleqedar nîşan dide?',
      ],
      [
        'Listika "Kuko" bilîze — ev mayîna heyberan hîn dike',
        'Bihêle pitikê te materyalên cihê (bi ewlehî!) keşif bike',
      ],
    ),
    'sozial': _DomainText(
      'Girêdan û Hest',
      'Tevgera girêdanê, kenandin û tirsa ji biyaniyan',
      [
        'Pitikê te bi armanc li te dikene?',
        'Pitikê te lêgerîna çavan bi te re dike?',
        'Pitikê te li ba kesên biyanî nerehetiyê nîşan dide?',
        'Pitikê te dema tu wî hildigirî aram dibe?',
        'Pitikê te destan dirêj dike da ku were hildan?',
      ],
      [
        'Bi baweriyekê li giriyê bersiv bide — ev girêdana ewle ava dike',
        'Nêzîkbûna laşî û pêwendiya çermî di vê temenê de herî girîng in',
      ],
    ),
    'selbst': _DomainText(
      'Serbixwebûna Ewilî',
      'Xwarin, xew û çalakiya xwe ya sade',
      [
        'Pitikê te dikare bîskuît an perçeyekî fêkî bi serê xwe bigire û bixwe?',
        'Pitikê te (bi alîkarî) ji kasekê vedixwe?',
        'Pitikê te rîtmek xew-hişyariyê nîşan dide?',
        'Pitikê te dikare demek kurt bi serê xwe mijûl bibe?',
        'Pitikê te tercîhan nîşan dide (listikek an kesek diyar)?',
      ],
      [
        'Xwarina tiliyan pêşkêş bike — motorîka biçûk û serbixwebûnê xurt dike',
        'Rîtûelên sabit (xew, xwarin) ewlehiyê didin',
      ],
    ),
  },
  '1-2y': {
    'motorik': _DomainText(
      'Tevger û Laş',
      'Meşîn, hilkişîn û motorîka biçûk a ewilî',
      [
        'Zarokê te dikare azad bimeşe?',
        'Zarokê te dikare xwe xar bike û dîsa rabe?',
        'Zarokê te li mobîlyayên nizm an derencan hildikişe?',
        'Zarokê te dikare bi qelemê xêzan bike?',
        'Zarokê te dikare 2-3 kubîkan li ser hev bike?',
        'Zarokê te dikare topê bigerîne an bavêje?',
      ],
      [
        'Bihêle zarokê te pir bi lingên xwe yên vala bimeşe',
        'Ji bo pratîkê derenceyan pêşkêş bike (bi çavdêriyê)',
        'Listika qûm û rijandina avê motorîka biçûk xurt dike',
      ],
    ),
    'sprache': _DomainText(
      'Ziman û Vegotin',
      'Peyvên ewilî, nîşandan û fêmkirin',
      [
        'Zarokê te herî kêm 10 peyvên nas dibêje?',
        'Zarokê te tiştên ku dixwaze an dixwaze nîşan bide, nîşan dide?',
        'Zarokê te rêwerzên hêsan fêm dike (were vir, bide min)?',
        'Zarokê te kesên nas bi nav dike (dayik, bav)?',
        'Zarokê te serê xwe ji bo erê/na dihejîne?',
        'Zarokê te hewl dide peyvan dubare bike?',
      ],
      [
        'Di jiyana rojane de her tiştî bi nav bike — dubarekirin sereke ye',
        'Rojane li pirtûkên wêneyî binêre û wan bi nav bike',
        'Rast neke, tenê rastiya wê dubare bike: Zarok: "Haw haw!" — Tu: "Erê, kûçikek!"',
      ],
    ),
    'denken': _DomainText(
      'Fikirîn û Lîstin',
      'Teqlîdkirin, rêzkirin û ji xwe re bi hev anîn',
      [
        'Zarokê te tevgerên rojane teqlîd dike (têlefon kirin, xwarin çêkirin)?',
        'Zarokê te fêm dike ka heyber ji bo çi ne (kêr = mû)?',
        'Zarokê te dikare puzzleyên hêsan (1-3 perçe) çareser bike?',
        'Dema tu dipirsî zarokê te wêneyên di pirtûkan de nîşan dide?',
        'Zarokê te bi çalakî li tiştên veşartî digere?',
        'Zarokê te tiştan li gorî mezinahî an şeklê rêz dike?',
      ],
      [
        'Lîstika "wek ku" xurt bike: xwarina bûkê çêke, tediya heywanê biguherîne',
        'Bihêle zarokê te di jiyana rojane de "alîkarî" bike (dagirtina makîneya cilşuştinê, tevlihev kirin)',
      ],
    ),
    'sozial': _DomainText(
      'Hest û Têkilî',
      'Nîşandana hestan, teselîkirin û empatiya ewilî',
      [
        'Zarokê te bi eşkere kêfxweşiyê nîşan dide (kef lêdide, dipengize)?',
        'Zarokê te tê ba te dema teselîyê hewce dike?',
        'Zarokê te bersiv dide dema zarokek din digirî?',
        'Zarokê te dikare "na" nîşan bide an bibêje?',
        'Zarokê te ji lîstina li kêleka zarokên din hez dike?',
        'Zarokê te serbilindiyê nîşan dide dema tiştek serkeftî dike?',
      ],
      [
        'Hestan bi nav bike: "Tu kêfxweş î!" / "Vê tirsand"',
        'Teselî bike li şûna ku bala wî bidî cihekî din — hest divê hebin',
      ],
    ),
    'selbst': _DomainText(
      'Serbixwebûn',
      'Xwarin, cilûberg û "bi serê xwe bikim!"',
      [
        'Zarokê te bi qeşiqê bi serê xwe dixwe?',
        'Zarokê te bi serê xwe ji kasekê vedixwe?',
        'Zarokê te kûlîk an gore ji xwe derdixe?',
        'Zarokê te dixwaze tiştan bi serê xwe bike?',
        'Zarokê te (dema jê were xwestin) listikan kom dike?',
        'Zarokê te eleqeyê bi kirsî an tuwaletê nîşan dide?',
      ],
      [
        'Li dijî xwesteka "Bi serê xwe!" sebir bike — her çend dirêjtir bikişîne jî',
        'Karên biçûk bide: pêlavan bîne ber derî, alîkariya çîkirina mûzê bike',
      ],
    ),
  },
  '2-3y': {
    'motorik': _DomainText(
      'Tevger û Laş',
      'Motorîka mezin, motorîka biçûk û haydariya laş',
      [
        'Zarokê te dikare bi ewlehî derencewanan hilkişe (bi girtinê)?',
        'Zarokê te dikare demekê kurt li ser yek lingê raweste?',
        'Zarokê te dikare topê bigire an bavêje?',
        'Zarokê te dikare şêweyên hêsan (dor, xêz) kopî bike?',
        'Zarokê te dikare bi qefç an çengalê bi serê xwe bixwe?',
        'Zarokê te bi xweber dikêşe an bazdide (mînak li ser golan)?',
      ],
      [
        'Di jiyana rojane de derfetên hilkişînê çêbike (parka lîstikê, balgih)',
        'Xemla, dizîkirina dendikan an lîstina qûmê motorîka biçûk xurt dike',
        'Bihêle zarokê te bi lingên vala bimeşe — ev bîlansê û haydariya laş xurt dike',
      ],
    ),
    'sprache': _DomainText(
      'Ziman û Fêmkirin',
      'Ferheng, çêkirina hevokan û fêmkirina zimanê',
      [
        'Zarokê te hevokên du an sê peyvan çêdike?',
        'Zarokê te dikare bersiva pirsên hêsan bide (Çi? Li ku ye)?',
        'Zarokê te navên tiştên rojane rast dibêje?',
        'Zarokê te fermanên hêsan (Pirtûkê bîne) fêm dike?',
        'Zarokê te bi stran an melodiyan re distirê an stran dike?',
        'Zarokê te dikare serpêhatiyên xwe bibêje (her çiqas ne temam be jî)?',
      ],
      [
        'Hêdî û bi hevokên kurt biaxive — peyvan bi carinan dubare bike',
        'Her roj 5-10 deqîqe bixwîne û li wêneyan nîşan bide',
        'Her tiştê ku tu dikî bi nav bike: "Ez mûzê dibirim"',
      ],
    ),
    'denken': _DomainText(
      'Fikirîn û Vedîtin',
      'Çareserkirina pirsgirêkan, meraq û baldarî',
      [
        'Zarokê te dikare puzzleyên hêsan (3-6 perçe) çareser bike?',
        'Zarokê te tiştan li gorî reng an mezinahiyê rêz dike?',
        'Zarokê te dikare ji 2-3 deqîqeyan zêdetir li ser karekî bimîne?',
        'Zarokê te eleqeya xwe bi dîtina pirtûkan nîşan dide?',
        'Zarokê te hewl dide tiştan fêm bike (Heke... çi dibe)?',
        'Zarokê te dikare beşên laşê bibêje an nîşan bide?',
      ],
      [
        'Materyalên lîstikê yên vekirî pêşkêş bike (kubîkên avakirinê, qûm, av)',
        'Li şûna bersivdanê pirsên "çima" vegerîne: "Tu çi difikirî?"',
        'Lîstika baldar li navîne — her çend "tenê" tevlihevkirin be jî',
      ],
    ),
    'sozial': _DomainText(
      'Hest û Bihevrebûn',
      'Hest, empati û tevgera civakî',
      [
        'Zarokê te kêf, hêrs an xemgînî bi eşkere nîşan dide?',
        'Dema xemgîn an birîndar be zarokê te ji te teselî dixwaze?',
        'Zarokê te dikare demên bendewariyê yên kurt (bi piştgirî) ragire?',
        'Zarokê te li kêleka an bi zarokên din re dilîze?',
        'Dema kesek digirî an diêşe zarokê te empatiyê nîşan dide?',
        'Zarokê te sînorên hêsan qebûl dike (her çiqas nerazî be jî)?',
      ],
      [
        'Hestan bi dengekî bilind bi nav bike: "Tu hêrs î ji ber ku..." — ev ferhenga hestan hîn dike',
        'Di dema hêrsê de aram bimîne — arambûna te modela birêvebirinê ye',
        'Lîstika paralel (li kêleka hev) ji bo temenê 2-3 salî tam normal û bihagiran e',
      ],
    ),
    'selbst': _DomainText(
      'Serbixwebûn',
      'Jêhatîbûnên rojane û bi serê xwe kirin',
      [
        'Zarokê te dikare hinekî bi serê xwe cil û berg li xwe bike (pêlav, kûlîk, çakêt)?',
        'Zarokê te dikare destên xwe bi serê xwe bişo?',
        'Zarokê te di karên hêsan de alîkar dibe (mase amade kirin, kom kirin)?',
        'Zarokê te dixwaze hin tiştan bi serê xwe bike?',
        'Zarokê te rêbazên rojane yên hêsan dizane (pêşî xwarin, paşê lîstin)?',
        'Dema jê were pirsîn zarokê te dikare navê xwe bibêje?',
      ],
      [
        'Li şûna fermanan hilbijartinan pêşkêş bike: "Kirasê sor an şîn?"',
        'Bihêle çewtî çêbibe — şîrê rijiyayî kêliyeke fêrbûnê ye, ne felaketek',
        'Rîtûel ewlehiyê didin: heman rêzik sibe û êvarê',
      ],
    ),
  },
  '3-4y': {
    'motorik': _DomainText(
      'Tevger û Jêhatîbûn',
      'Bîlans, hilkişîn û motorîka biçûk',
      [
        'Zarokê te dikare bisîkletê sê-tekerkî an bisîkleta bîlansê bajo?',
        'Zarokê te dikare demeke kurt li ser yek lingî raweste?',
        'Zarokê te dikare meqesê bikar bîne (birrînên hêsan)?',
        'Zarokê te şeklên nas dikêşe (dor, xaç)?',
        'Zarokê te dikare dendikan bikişîne an bişkokan veke?',
        'Zarokê te bi her du lingan ji erdê dipengize?',
      ],
      [
        'Listikên tevgerê li derve: bîlanskirin li ser darikan, listikên pengizînê',
        'Hunerê bi meqes û çewalê bike — her çend ne bêkêmasî be jî',
      ],
    ),
    'sprache': _DomainText(
      'Ziman û Vegotin',
      'Hevok, pirsan kirin û çîrok',
      [
        'Zarokê te bi hevokên tam diaxive (4-5 peyv)?',
        'Zarokê te pirsên "çima" dike?',
        'Zarokê te dikare serpêhatiyên xwe bibêje (her çend tevlihev be jî)?',
        'Zarokê te daçekan fêm dike (li ser, li jêr, li kêleka)?',
        'Zarokê te pirjimariyê rast bikar tîne (erebe, top)?',
        'Zarokê te dikare qafiyeyên hêsan an stranan bibêje?',
      ],
      [
        'Pirsên "çima" bi ciddî bigire — her çend pirsa 50-an be jî',
        'Bi hev re çîrokan çêke: "Û paşê...?"',
      ],
    ),
    'denken': _DomainText(
      'Fikirîn û Xeyal',
      'Rola lîstinê, jimartin û têkilî',
      [
        'Zarokê te rolên lîstinê dike (bijîşk, dikan, malbat)?',
        'Zarokê te dikare heta 5 an 10 bijmêre?',
        'Zarokê te têkiliyên hêsan fêm dike (baran = şil)?',
        'Zarokê te dikare 3-4 rengan bi nav bike?',
        'Zarokê te puzzleyên bi 6-12 perçeyan çareser dike?',
        'Zarokê te nexşan nas dike û dikare wan berdewam bike?',
      ],
      [
        'Lîstika rolê di vê temenê de rêbaza fêrbûnê ya ESASÎ ye — beşdar be!',
        'Di jiyana rojane de bijmêre: gavên derence, sêv, pêlav',
      ],
    ),
    'sozial': _DomainText(
      'Hest û Hevaltî',
      'Parvekirin, pevçûn û tehemûla dilşikestinê',
      [
        'Zarokê te dikare bi zarokên din re bilîze (ne tenê li kêleka wan)?',
        'Zarokê te dikare demeke kurt li benda tiştekî bimîne?',
        'Zarokê te dikare listikan parve bike (carinan)?',
        'Zarokê te hevgirtinê nîşan dide û yên din teselî dike?',
        'Zarokê te dikare dilşikestinê bêyî lêdan îfade bike?',
        'Zarokê te hevaltiyên lîstinê yên ewilî hene?',
      ],
      [
        'Ne hewce ye ku parvekirin were zorkirin — ew bi mezinbûna civakî tê',
        'Di pevçûnên di navbera zarokan de hevrê be, ne çareserkir',
      ],
    ),
    'selbst': _DomainText(
      'Jiyana Rojane û Berpirsyarî',
      'Cilûberg, paqijî û karên biçûk',
      [
        'Zarokê te bi piranî dikare bi serê xwe cilûberg li xwe bike?',
        'Zarokê te bi serê xwe diçe tuwaletê (bi piranî)?',
        'Zarokê te dikare diranên xwe bişo (bi alîkariya paşîn)?',
        'Zarokê te di karan de alîkarî dike (mase amade kirin, kulîlkan avdan)?',
        'Zarokê te rêzikên rojane dizane û dikare wan bi nav bike?',
        'Zarokê te dikare navê xwe û paşnavê xwe bibêje?',
      ],
      [
        'Bihêle zarokê te ne tenê di karên lîstinê de, di karên rastîn de jî alîkarî bike',
        'Rêzikan bi wêne çêke: plana wêneyî ji bo sibe/êvarê',
      ],
    ),
  },
  '4-6y': {
    'motorik': _DomainText(
      'Laş û Hevahengî',
      'Werzîş, nivîsandin û jêhatîbûn',
      [
        'Zarokê te dikare bisîkletê bajo (bi an bêyî tekerên piştgirî)?',
        'Zarokê te dikare navê xwe binivîse?',
        'Zarokê te dikare li ser xêzekê birrîne?',
        'Zarokê te dikare bi armanc topê bigire?',
        'Zarokê te çend caran li ser yek lingî dipengize?',
        'Zarokê te dikare bişkokên biçûk bigire?',
      ],
      [
        'Motorîka biçûk: dendik, ûtîkirin, orîgamî — kêf li şûna talîmê',
        'Rojane herî kêm 1 saet tevgera li derve',
      ],
    ),
    'sprache': _DomainText(
      'Ziman û Têgihiştin',
      'Vegotin, rêziman û ferheng',
      [
        'Zarokê te çîrokên bi destpêk, nîvî û dawî vedibêje?',
        'Zarokê te rêzimana rast bikar tîne (bi piranî)?',
        'Zarokê te dikare henekan fêm bike an bibêje?',
        'Zarokê te rêwerzên tevlihev fêm dike (Pêşî..., paşê...)?',
        'Zarokê te eleqeyê bi tîpan an xwendinê nîşan dide?',
        'Zarokê te dikare qafiyeyan çêbike an kevaran bi destan lêde?',
      ],
      [
        'Bilind xwendin girîng dimîne — her çend zarok bixwaze bi xwe "bixwîne"',
        'Lîstikên qafiyeyê û lêdana kevaran ji bo dibistanê amade dike',
      ],
    ),
    'denken': _DomainText(
      'Fikirîn û Amadebûna Dibistanê',
      'Mantiq, baldarî û jêhatîbûna pêş-dibistanê',
      [
        'Zarokê te dikare 20 deqîqeyan li ser karekî bimîne?',
        'Zarokê te têgehên demê fêm dike (duh, sibe, paşê)?',
        'Zarokê te dikare mîqdarên hêsan bide ber hev (zêdetir/kêmtir)?',
        'Zarokê te bêtir bi serê xwe pirsgirêkan çareser dike?',
        'Zarokê te dikare qaîdeyên di lîstikên taxteyê de fêm bike û bişopîne?',
        'Zarokê te eleqeyê bi hejmar û jimartinê nîşan dide?',
      ],
      [
        'Lîstikên taxteyê perwerdehiyek îdeal in ji bo tehemûl û qaîdeyan',
        'Zû perwerdehiya dibistanê meke — lîstin bi xwe fêrbûn e',
      ],
    ),
    'sozial': _DomainText(
      'Civakî û Empatî',
      'Hevaltî, qaîde û dîtina ji alîyê din',
      [
        'Zarokê te hevaltiyên domdar hene?',
        'Zarokê te dikare xwe li şûna yên din deyne?',
        'Zarokê te qaîdeyan dişopîne (bi piranî)?',
        'Zarokê te dikare pevçûnan bi devkî çareser bike (carinan)?',
        'Zarokê te hestê berpirsyariyê ji bo biçûktir an heywanan nîşan dide?',
        'Zarokê te dikare bêyî ku ji 2-3 deqîqeyan zêdetir bigirî winda bike?',
      ],
      [
        'Windakirinê pratîk bike: lîstikên taxteyê bilîze, bi zanebûn winda neke',
        'Empatiyê xurt bike: "Zarokê din niha çawa hîs dike?"',
      ],
    ),
    'selbst': _DomainText(
      'Serbixwebûn û Mezinbûn',
      'Berpirsyarî, plansazî û jêhatîbûna rojane',
      [
        'Zarokê te dikare bi tevahî bi serê xwe cilûberg li xwe bike?',
        'Zarokê te dikare xwarinên hêsan amade bike (tiştekî li ser nên belav bike)?',
        'Zarokê te navnîşan an hejmara têlefonê dizane?',
        'Zarokê te dikare bi serê xwe biçe tuwaletê (paqijkirin jî tê de)?',
        'Zarokê te dikare rêyeke kurt bi serê xwe bimeşe (mînak cîranî)?',
        'Zarokê te dikare hewcedariyên xwe bi zelalî ragihîne?',
      ],
      [
        'Berpirsyariya rastîn bide: xwarina heywanê malê, rêzkirina jûreya xwe',
        'Rêya dibistanê pratîk bike — gav bi gav zêdetir serbixwebûn',
      ],
    ),
  },
  '6-10y': {
    'motorik': _DomainText(
      'Laş û Werzîş',
      'Hevahengî, tehemûl û motorîka biçûk',
      [
        'Zarokê te dikare bi rêkûpêkî binivîse?',
        'Zarokê te ji werzîşê hez dike an bi tehemûlî tevdigere?',
        'Zarokê te dikare kevanekê girê bide?',
        'Hevahengiya laşê zarokê te baş e (avjenî, hilkişîn)?',
        'Zarokê te dikare ji 30 deqîqeyan zêdetir rûne (li dibistanê)?',
      ],
      [
        'Werzîş divê kêfxweş be — ne performansê',
        'Sînordarkirina dema ekranê = tevgera xwezayî ya zêdetir',
      ],
    ),
    'sprache': _DomainText(
      'Ziman û Xwendin',
      'Xwendin, nivîsandin û vegotin',
      [
        'Zarokê te nivîsarên li gorî temenê xwe bi rêkûpêkî dixwîne?',
        'Zarokê te dikare çîrokan bi nivîskî vebêje?',
        'Zarokê te xwe bi awayekî berfireh îfade dike?',
        'Zarokê te îronî an wateyên veşartî fêm dike?',
        'Zarokê te ji dibistanê û serpêhatiyên xwe re dibêje?',
      ],
      [
        'Bi hev re bixwîne — her çend zarok bi xwe dikare bixwîne',
        'Li ser rojê biaxive: ne tenê "Dibistan çawa bû?"',
      ],
    ),
    'denken': _DomainText(
      'Fêrbûn û Fikirîn',
      'Dibistan, baldarî û çareserkirina pirsgirêkan',
      [
        'Zarokê te bi piranî bi serê xwe erkên malê temam dike?',
        'Zarokê te meraqê nîşan dide û pirsan dike?',
        'Zarokê te dikare têkiliyan bi mantiqî rave bike?',
        'Zarokê te tiştan pêşiyê plansaz dike (pakêtkirin, rêveberiya demê)?',
        'Zarokê te bi awayekî avakerane bi çewtiyan re mijûl dibe?',
      ],
      [
        'Çewtî derfetên fêrbûnê ne — li şûna cezakirinê li ser wan biaxive',
        'Bihêle rêyên çareseriyê yên taybet, her çend dûrûdirêj xuya bikin',
      ],
    ),
    'sozial': _DomainText(
      'Hevaltî û Hest',
      'Hevalgeh, pevçûn û xweregulasyon',
      [
        'Zarokê te hevaltiyên domdar hene?',
        'Zarokê te dikare pevçûnan bêyî tundûtûjî çareser bike?',
        'Zarokê te dikare bi dilşikestin û hêrsê re mijûl bibe?',
        'Zarokê te hevgirtin û amadebûna alîkariyê nîşan dide?',
        'Zarokê te dikare hestên xwe bi nav bike û rave bike?',
      ],
      [
        'Ne her rewşê çareser bike — zarokan jî hewceyî çareseriyên xwe yên pevçûnê ne',
        'Hestan piştrast bike: "Ez fêm dikim ku vê tiştê te aciz kir"',
      ],
    ),
    'selbst': _DomainText(
      'Berpirsyarî û Jiyana Rojane',
      'Erk, hesta demê û xweorganîzekirin',
      [
        'Zarokê te bi rêkûpêk erkên malê hildigire ser xwe?',
        'Zarokê te dikare tiştên dibistanê yên xwe bi serê xwe organîze bike?',
        'Hesta demê ya zarokê te heye (li peymanan pabend bimîne)?',
        'Zarokê te dikare bi serê xwe biçe dibistanê?',
        'Zarokê te biryarên li gorî temenê xwe bi serê xwe digire?',
      ],
      [
        'Ji temenê 6-7 saliyê û pê ve pereyê berçavkî berpirsyariya pere hîn dike',
        'Saeta xwe ya şiyar bike, çenteyê xwe bi serê xwe amade bike',
      ],
    ),
  },
  '10-14y': {
    'motorik': _DomainText(
      'Laş û Tenduristî',
      'Mezinbûna cinsî, wêneya laş û tevger',
      [
        'Zarokê te bi rêkûpêkî tevdigere (werzîş, bisîklet, li derve)?',
        'Zarokê te têkiliyeke tendurist bi laşê xwe re heye?',
        'Zarokê te bes radizê (8-10 saet)?',
        'Zarokê te bi piranî bi tenduristî xwe dixwe?',
        'Zarokê te bi serê xwe li paqijiya laşê xwe miqate dibe?',
      ],
      [
        'Nimûne be: li şûna fermanan bi hev re tevbigere',
        'Guherînên laşî normal bike — bi eşkereyî li ser wan biaxive',
      ],
    ),
    'sprache': _DomainText(
      'Îfade û Ragihandin',
      'Nîqaşkirin, xwenirxandin û jêhatîbûna medyayê',
      [
        'Zarokê te dikare nêrîna xwe bi delîl îfade bike?',
        'Zarokê te bi dilxwazî dixwîne (pirtûk, gotar, komîk)?',
        'Zarokê te dikare bi rengekî objektîf nîqaş bike (bi piranî)?',
        'Zarokê te medyayê bi awayekî fikrî bikar tîne?',
        'Zarokê te dema bixwaze li ser hestan diaxive?',
      ],
      [
        'Bihêle nîqaş bibin — ciwan bi nêrînên dijber fêr dibin',
        'Jêhatîbûna medyayê bi hev re pêş bixe, ne tenê qedexe bike',
      ],
    ),
    'denken': _DomainText(
      'Fikirîn û Fêrbûn',
      'Fikra razber, plansazî û stratejiyên fêrbûnê',
      [
        'Zarokê te dikare bi awayekî razber bifikire (Eger ... bûya çi?)?',
        'Zarokê te karê dibistanê bi serê xwe organîze dike?',
        'Zarokê te eleqeyên xwe yên taybet hene ku kûr dibe tê de?',
        'Zarokê te dikare encaman pêşiyê bifikire?',
        'Zarokê te ji bo herî kêm mijarekê motîvasyona hundirîn nîşan dide?',
      ],
      [
        'Eleqeyan piştgirî bike — her çend bi dibistanê ve girêdayî nebe',
        'Amûrên plansaziyê pêşkêş bike: salname, lîsteya karan',
      ],
    ),
    'sozial': _DomainText(
      'Nasname û Têkilî',
      'Hevalgeh, nasname û sînor danîn',
      [
        'Zarokê te hevaltiyên domdar hene?',
        'Zarokê te dikare li dijî zextê komê bisekine?',
        'Zarokê te empatiyê ji bo yên din (biyanî jî) nîşan dide?',
        'Zarokê te dikare sînoran deyne û ragihîne?',
        'Zarokê te dest bi pêşxistina nasnameya xwe ya taybet dike?',
      ],
      [
        'Mezinbûna cinsî têkçûn e — ev tendurist e, ne bêrêzî',
        'Bêyî ku tavilê çareser bike guhdarî bike — hebûn bi tenê bes e gelek caran',
      ],
    ),
    'selbst': _DomainText(
      'Serbixwebûn û Berpirsyarî',
      'Xweorganîzekirin, pere û biryar',
      [
        'Zarokê te berpirsyariya erkên xwe hildigire ser xwe?',
        'Zarokê te dikare bi pereyan re mijûl bibe (pereyê berçavkî)?',
        'Zarokê te biryarên xwe digire û encaman hildigire ser xwe?',
        'Zarokê te dikare bi serê xwe li derve be (bajar, veguhastina giştî)?',
        'Zarokê te di peymanan de pêbawerî nîşan dide?',
      ],
      [
        'Bi zêdebûna berpirsyariyê azadiyeke zêdetir — li şûna fermankirinê danûstandin bike',
        'Bihêle çewtî çêbibe — heta ku ewlehî were misogerkirin',
      ],
    ),
  },
  '14-18y': {
    'motorik': _DomainText(
      'Tenduristî û Başbûn',
      'Laş, xew, xwarin û tevger',
      [
        'Ciwanê te bi rêkûpêkî tevdigere?',
        'Ciwanê te rîtmek xew a tendurist heye?',
        'Ciwanê te bi hişmendî xwe dixwe?',
        'Ciwanê te bi berpirsyarî xwe bikar tîne (bêyî xerakirin)?',
        'Ciwanê te li tenduristiya derûnî miqate dibe?',
      ],
      [
        'Kontrol neke, nimûne be',
        'Bi eşkereyî li ser tenduristiya derûnî biaxive — dûrî dawîlêanîna şerm',
      ],
    ),
    'sprache': _DomainText(
      'Îfade û Xwenirxandin',
      'Xwenirxandin, gotûbêj û ragihandin',
      [
        'Ciwanê te dikare ramanên xwe bi zelalî îfade bike?',
        'Ciwanê te tevgera xwe ya taybet nirxandin dike?',
        'Ciwanê te dikare pêşnûman bi awayekî avakerane qebûl bike?',
        'Ciwanê te bi rêz ragihîne (bi piranî)?',
        'Ciwanê te dikare dîtinên cihê bigire?',
      ],
      [
        'Ragihandina bi rêz nimûne be — di pevçûnan de jî',
        'Li şûna sûcdarkirinê pirsan bike: "Tu çi hewce dikî?" li şûna "Tu çima ... dikî?"',
      ],
    ),
    'denken': _DomainText(
      'Pêşerojê û Rêon',
      'Rêona pîşeyî, nirx û armancên taybet',
      [
        'Ciwanê te ramanên li ser pêşeroja xwe hene?',
        'Ciwanê te înîsiyatîfa xwe nîşan dide (staj, projeyan)?',
        'Ciwanê te dikare nirxên xwe yên taybet bi nav bike?',
        'Ciwanê te armancên xwe yên taybet datîne?',
        'Ciwanê te dikare biryarên tevlihev bikişîne?',
      ],
      [
        'Ne hewce ye plansaziyên pêşerojê sabit bin — rêon bes e',
        'Rê bide ezmûnên pratîkî: staj, karên demjimêrî, dilxwazî',
      ],
    ),
    'sozial': _DomainText(
      'Têkilî û Nasname',
      'Hevaltî, nasname û rola civakî',
      [
        'Ciwanê te hevaltiyên tendurist diparêze?',
        'Ciwanê te dikare li dijî zextê komê na bibêje?',
        'Ciwanê te bi rêz li têkiliyan dinêre?',
        'Ciwanê te wêneyeke xwe ya sabit nîşan dide?',
        'Ciwanê te ji bo tiştekî (civakî, siyasî, afirîner) tevdigere?',
      ],
      [
        'Dîtina nasnameyê cih hewce dike — ne her qonaxê şirove bike',
        'Rêzê bide têkiliyan — her çend ji te re xweş nebin jî',
      ],
    ),
    'selbst': _DomainText(
      'Serbixwebûn û Mezinbûn',
      'Jêhatîbûna jiyanê, dara mal û berpirsyarî',
      [
        'Ciwanê te dikare bi serê xwe malekê bi rê ve bibe (xwarin, cilşuştin)?',
        'Ciwanê te bi berpirsyarî li pereyan miqate dibe?',
        'Ciwanê te dikare karên fermî an randevûyên bijîşkî bi serê xwe bike?',
        'Ciwanê te bi pêbawerî peymanan digire ser xwe?',
        'Ciwanê te ji bo jiyaneke bêtir serbixwe amade ye?',
      ],
      [
        'Jêhatîbûnên jiyanê bi çalakî hîn bike: xwarinpêjî, daxuyaniya bacê, cilşuştin',
        'Berdana destan pratîk bike — ji bo herduyan',
      ],
    ),
  },
};
