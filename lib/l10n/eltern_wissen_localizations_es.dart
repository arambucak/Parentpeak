import 'package:parentpeak/l10n/eltern_wissen_localizations.dart';

/// Spanish translations for parent-knowledge FAQ entries.
const Map<String, ElternWissenText> elternWissenEs = {
  // ───────────────────────────── BEBÉ (0-1 año) ─────────────────────────────
  'baby_01': ElternWissenText(
    question: 'Mi bebé llora y no sé por qué',
    akut:
        'Coge a tu bebé en brazos y mantenlo cerca. Tu calma es su seguridad.',
    beduerfnis:
        'Los bebés lloran para comunicarse. Tiene una necesidad sin cubrir: hambre, cercanía, exceso de estímulos, cansancio o dolor.',
    gfkSatz: 'Estoy aquí. Te escucho. Juntos vamos a descubrir qué necesitas.',
    aktion: [
      'Buscar contacto físico (piel con piel)',
      'Repasar las necesidades básicas: ¿hambre?, ¿pañal?, ¿sueño?',
      'Reducir estímulos: menos ruido, menos luz, más calma',
    ],
    ermutigung:
        'No tienes que saber al instante qué necesita. Tu presencia ya es la mitad de la solución.',
  ),
  'baby_02': ElternWissenText(
    question: 'Mi bebé no se duerme',
    akut:
        'Mantén la calma. Tu bebé percibe tu tensión. Respira despacio y sostenlo.',
    beduerfnis:
        'Los bebés necesitan corregulación. Todavía no pueden calmarse solos: tu sistema nervioso es su ancla.',
    gfkSatz: 'Estás a salvo. Estoy aquí. Tu cuerpo ya puede descansar.',
    aktion: [
      'Crear rutinas: la misma secuencia cada noche',
      'Reducir los estímulos 30 minutos antes de dormir',
      'Ofrecer cercanía física (llevarlo en brazos, mecerlo, amamantar)',
    ],
    ermutigung:
        'El sueño es un proceso de desarrollo, no el resultado de un entrenamiento. Va a mejorar.',
  ),
  'baby_03': ElternWissenText(
    question: 'Mi bebé solo me quiere a mí y no al otro progenitor',
    akut: 'Es normal y sano. Tu bebé muestra un apego seguro, no un rechazo.',
    beduerfnis:
        'Los bebés suelen crear el apego primario primero con una persona. El otro progenitor necesita sus propios rituales y tiempo.',
    gfkSatz:
        'Nos quieres a los dos. Ahora mismo me necesitas a mí, y eso está bien.',
    aktion: [
      'Dar al otro progenitor momentos propios de mimos, sin competencia',
      'No forzar: la confianza crece con experiencias positivas',
      'Aumentar poco a poco ratos a solas breves (5 minutos)',
    ],
    ermutigung:
        'Es una etapa que demuestra que el apego funciona. Ambos progenitores son importantes.',
  ),

  // ──────────────────────── NIÑO PEQUEÑO (1-3 años) ─────────────────────────
  'klein_01': ElternWissenText(
    question: 'Mi hijo pega a otros niños',
    akut:
        'Acércate con calma. No grites. Di: Alto, no voy a permitir que pegues.',
    beduerfnis:
        'Tu hijo no es malo. Tiene emociones intensas (frustración, agobio) y todavía no tiene palabras para ellas. Pegar es una forma de comunicación.',
    gfkSatz:
        'Veo que estás enfadado. Pegar hace daño. Ven, juntos descubrimos qué necesitas.',
    aktion: [
      'Acercarse enseguida con calma y consolar al otro niño',
      'Más tarde: ofrecer alternativas (patear el suelo, boxear un cojín)',
      'Reconocer los desencadenantes: ¿cansancio?, ¿hambre?, ¿sobreestimulación?',
    ],
    ermutigung:
        'Es una etapa. Tu hijo está aprendiendo a controlar sus impulsos, y eso dura hasta los 4 o 5 años.',
  ),
  'klein_02': ElternWissenText(
    question: 'Mi hijo tiene rabietas',
    akut:
        'Quédate cerca. No digas nada. Deja que pase la tormenta. Tu hijo te necesita DESPUÉS.',
    beduerfnis:
        'Las rabietas son neurológicas: la corteza cerebral aún no está lo bastante madura para regular las emociones. Tu hijo se ve desbordado y necesita corregulación.',
    gfkSatz: 'Puedes estar enfadado. Estoy aquí. Cuando termines, te abrazo.',
    aktion: [
      'Garantizar la seguridad (no dejar que tire algo que pueda hacer daño)',
      'No discutir, no reñir, no marcharse',
      'Después de la rabieta: ofrecer contacto físico, sin moralizar',
    ],
    ermutigung:
        'No es culpa tuya. Las rabietas son propias del desarrollo y NO son señal de una mala crianza.',
  ),
  'klein_03': ElternWissenText(
    question: 'Mi hijo no quiere compartir',
    akut:
        'No le obligues. Compartir es una capacidad que MADURA, no se puede forzar.',
    beduerfnis:
        'Los niños menores de 3 o 4 años entienden la pertenencia de forma distinta a los adultos. Compartir requiere empatía, y esta se desarrolla más adelante.',
    gfkSatz: 'Esto es tuyo. Tú puedes decidir cuándo quieres dejarlo.',
    aktion: [
      'No avergonzar (nada de «¡No seas tan egoísta!»)',
      'Dar ejemplo: compartir en voz alta («¿Quieres de mi manzana?»)',
      'Guardar el juguete favorito ANTES de la visita (reduce el estrés)',
    ],
    ermutigung:
        'Un niño que se siente seguro con lo que es suyo acaba siendo generoso por voluntad propia.',
  ),
  'klein_04': ElternWissenText(
    question: 'Mi hijo dice que no a todo',
    akut:
        '¡Es sano! Tu hijo está descubriendo: soy una persona con voluntad propia.',
    beduerfnis:
        'La autonomía es una necesidad básica. Decir «no» es la primera forma de autodeterminación.',
    gfkSatz:
        'Escucho tu no. Aun así, algunas cosas tienen que ser. Veamos cómo.',
    aktion: [
      'Dar opciones en lugar de órdenes («¿Chaqueta roja o azul?»)',
      'Evitar luchas de poder innecesarias (¿tiene que ser DE VERDAD ahora?)',
      'Respetar el no cuando sea posible: refuerza la confianza en sí mismo',
    ],
    ermutigung:
        'Un niño que puede decir no en casa también podrá decir no a desconocidos más adelante.',
  ),
  'klein_05': ElternWissenText(
    question: 'Mi hijo no quiere comer',
    akut:
        'Sin presión. Sin obligar. Sin alimentar con distracciones. Confía: ningún niño pasa hambre por voluntad propia.',
    beduerfnis:
        'La comida es un terreno de autonomía. Los niños regulan su propio hambre: la presión genera resistencia.',
    gfkSatz:
        'Tu barriga sabe cuándo tiene hambre. La comida está aquí por si te apetece.',
    aktion: [
      'Sentarse juntos a la mesa (sin obligar a comer)',
      'Ofrecer siempre al menos un alimento conocido',
      'Ofrecer cosas nuevas de 10 a 15 veces sin comentarios',
    ],
    ermutigung:
        'La selectividad con la comida es normal y pasa. Tu hijo recibe suficiente, aunque no lo parezca.',
  ),
  'klein_06': ElternWissenText(
    question: 'Cuando mi voz sube más de lo que quiero',
    akut:
        'Tu cuerpo te está mostrando: estoy en mi límite. Es una señal, no un fracaso.',
    beduerfnis:
        'Detrás de tu volumen hay una necesidad: de ser escuchada, de calma, de apoyo. Puedes sentirlo.',
    gfkSatz:
        'Noto que mi cuerpo está tenso. Necesito un momento para mí para volver a estar en calma.',
    aktion: [
      'Conoce tus señales de aviso (mandíbula, hombros, respiración entrecortada): llegan segundos ANTES de gritar',
      'Dile a tu hijo: «Necesito una pausa un momento»; no es irse, es dar ejemplo de autocuidado',
      'Después: repara el vínculo («Lo siento, no estaba bien conmigo. Te quiero.»)',
    ],
    ermutigung:
        'Que estés leyendo esto demuestra que quieres hacerlo de otra manera. Eso por sí solo ya lo cambia todo.',
  ),
  'klein_07': ElternWissenText(
    question: 'Mi hijo no quiere ir a la guardería',
    akut:
        'Toma en serio su dolor. Di: Entiendo que preferirías quedarte conmigo. Luego te recojo.',
    beduerfnis:
        'La angustia por la separación es señal de un apego seguro. Tu hijo te echa de menos, y eso es SANO.',
    gfkSatz:
        'Veo que estás triste. Quieres quedarte conmigo. Vuelvo después de comer.',
    aktion: [
      'Crear un ritual de despedida (siempre igual, breve y cariñoso)',
      'No marcharse nunca a escondidas: eso destruye la confianza',
      'Dar un objeto de transición (tu bufanda, una foto)',
    ],
    ermutigung:
        'La adaptación lleva su tiempo. Semanas, a veces meses. No es un retroceso.',
  ),
  'klein_08': ElternWissenText(
    question: 'Mi hijo tiene celos del nuevo hermanito',
    akut:
        'No compares. No digas «si ya eres mayor». Tu hijo mayor está en duelo: por la atención ahora compartida.',
    beduerfnis:
        'Los celos son miedo a la pérdida: ¿me seguís queriendo igual?, ¿sigo siendo importante?',
    gfkSatz:
        'Eres igual de importante que antes. Está bien que ahora estés triste o enfadado.',
    aktion: [
      'Tiempo exclusivo de mamá o papá SOLO para el hijo mayor (con 10 min al día basta)',
      'Incluir al mayor en el cuidado del bebé (traer el pañal, cantar)',
      'Nombrar las emociones sin juzgar: «Estás enfadado con el bebé, lo entiendo»',
    ],
    ermutigung:
        'El cariño entre hermanos no surge de inmediato. Dale al hijo mayor tiempo y seguridad.',
  ),

  // ───────────────────── NIÑO DE PREESCOLAR (3-6 años) ──────────────────────
  'kita_01': ElternWissenText(
    question: 'Mi hijo miente',
    akut:
        'No castigues. No avergüences. Los niños menores de 6 años suelen «mentir» por fantasía, miedo o deseo.',
    beduerfnis:
        'Los niños mienten cuando la verdad les parece peligrosa. Pregúntate: ¿mi hijo se siente lo bastante seguro para ser sincero?',
    gfkSatz:
        'Quiero entender qué ha pasado. No vas a tener problemas: cuéntame tu versión.',
    aktion: [
      'Dar seguridad: NO castigar la sinceridad',
      'Distinguir entre mentira de fantasía (normal, de 3 a 5 años) y mentira de protección (miedo)',
      'Dar ejemplo: ser sincero uno mismo, aunque resulte incómodo',
    ],
    ermutigung:
        'Los niños que pueden ser sinceros en un entorno seguro se convierten en adultos sinceros.',
  ),
  'kita_02': ElternWissenText(
    question: 'Mi hijo tiene miedo a la oscuridad',
    akut:
        'El miedo es real. No lo minimices. Di: Te creo. Vamos a ver cómo puedes sentirte seguro.',
    beduerfnis:
        'El miedo a la oscuridad es propio del desarrollo (de 3 a 8 años). El cerebro ya puede IMAGINAR peligros: es un avance cognitivo.',
    gfkSatz:
        'Veo que tienes miedo. La oscuridad te parece inquietante. Estoy en la habitación de al lado: estás a salvo.',
    aktion: [
      'Luz nocturna (le devuelve el control)',
      'Espray antimonstruos (agua en un pulverizador que el niño rocía él mismo)',
      'Usar un peluche como protector («El osito te cuida»)',
    ],
    ermutigung:
        'Tu hijo no tiene ningún trastorno. Tiene imaginación. Eso es una fortaleza.',
  ),
  'kita_03': ElternWissenText(
    question: 'Mi hijo siempre quiere mandar cuando juega',
    akut:
        'Es normal entre los 4 y los 6 años. Están practicando el liderazgo, aún sin matices sociales.',
    beduerfnis:
        'Tu hijo necesita sentirse eficaz. Quiere experimentar: mis ideas cuentan.',
    gfkSatz:
        'Tienes ideas estupendas. Tu amigo también tiene las suyas. ¿Qué tal si os turnáis?',
    aktion: [
      'No intervenir enseguida: los niños resuelven más de lo que creemos',
      'Si hace falta: proponer un cambio de rol, no ordenarlo',
      'En casa: crear situaciones en las que el niño PUEDA dirigir (ser el guía del juego)',
    ],
    ermutigung:
        'Querer mandar es potencial de liderazgo. Más adelante se convertirá en una fortaleza.',
  ),
  'kita_04': ElternWissenText(
    question: 'Mi hijo todavía se hace pis en la cama',
    akut:
        'No avergüences. Mojar la cama NO es pereza: es un control de la vejiga aún inmaduro.',
    beduerfnis:
        'El cuerpo de tu hijo todavía no está preparado. La hormona antidiurética madura en algunos niños hasta los 6 o 7 años.',
    gfkSatz:
        'No es culpa tuya. Tu cuerpo todavía está aprendiendo. Encontraremos una solución juntos.',
    aktion: [
      'Protector impermeable (sin dramas)',
      'Cambiar la cama juntos (incluir al niño, no castigar)',
      'Si hay preocupación: consultar al pediatra a partir de los 7 años',
    ],
    ermutigung:
        'Casi el 15 % de los niños de 5 años todavía se hacen pis. Tu hijo no está solo.',
  ),

  // ─────────────────── NIÑO DE PRIMARIA (6-10 años) ────────────────────────
  'grund_01': ElternWissenText(
    question: 'Mi hijo no quiere hacer los deberes',
    akut:
        'No pelees. Di: Veo que no tienes ganas. ¿Qué necesitas para empezar?',
    beduerfnis:
        'Negarse a hacer los deberes rara vez es pereza. A menudo detrás hay agobio, aburrimiento o agotamiento tras la jornada escolar.',
    gfkSatz:
        'Noto que las tareas te resultan agotadoras. ¿Vemos juntos dónde se atasca?',
    aktion: [
      '30 minutos de pausa al salir del cole (moverse, merendar, descansar)',
      'Pequeñas porciones (5 minutos de concentración y luego pausa)',
      'Nada de amenazas, sino apoyo: «Te ayudo a empezar»',
    ],
    ermutigung:
        'La motivación llega con el éxito, no con la presión. Bastan pequeños pasos.',
  ),
  'grund_02': ElternWissenText(
    question: 'A mi hijo lo excluyen en el colegio',
    akut:
        'Escucha. Cree a tu hijo. Di: Lo siento. Mereces amigos que te traten bien.',
    beduerfnis:
        'La pertenencia es una necesidad básica. La exclusión duele físicamente a los niños: el cerebro la procesa como un dolor físico.',
    gfkSatz:
        'Escucho que esto te pone muy triste. Eres digno de cariño, digan lo que digan los demás.',
    aktion: [
      'No querer «solucionarlo» de inmediato: primero reconocer las emociones',
      'Preguntar: ¿qué te gustaría? (unos quieren ayuda, otros solo que les escuchen)',
      'Si hay acoso: informar al colegio (tutor o tutora)',
    ],
    ermutigung:
        'Tu hijo no necesita muchos amigos. Un único buen amigo basta para un desarrollo sano.',
  ),
  'grund_03': ElternWissenText(
    question: 'Mi hijo pasa demasiado tiempo frente a la pantalla',
    akut:
        'No le quites el aparato en pleno conflicto. Anuncia las transiciones: «5 minutos más y luego se acaba».',
    beduerfnis:
        'Las pantallas satisfacen necesidades: aburrimiento, pertenencia social, estimulación. Pregunta: ¿qué necesita mi hijo EN SU LUGAR?',
    gfkSatz:
        'Veo que te gusta el juego. Nuestra regla son 30 minutos. ¿Qué quieres hacer después?',
    aktion: [
      'Acordar reglas claras DE ANTEMANO (no en el momento)',
      'Ofrecer alternativas igual de atractivas (no un «vete a jugar fuera»)',
      'Dar ejemplo: ¿con qué frecuencia miras TÚ el móvil?',
    ],
    ermutigung:
        'No eres un mal progenitor porque tu hijo tenga tiempo de pantalla. El objetivo es el equilibrio.',
  ),
  'grund_04': ElternWissenText(
    question: 'Mi hijo tiene miedo a los exámenes',
    akut:
        'Normalízalo: ponerse nervioso antes de un examen es humano. Di: Tu valor no depende de una nota.',
    beduerfnis:
        'El miedo a los exámenes aparece cuando el rendimiento se vincula al cariño: «Si lo hago mal, no soy lo bastante bueno».',
    gfkSatz:
        'Te quiero igual, da igual la nota que pongan ahí. Eres mucho más que un número.',
    aktion: [
      'No preguntar «¿Has estudiado suficiente?», sino «¿Cómo te sientes con esto?»',
      'Enseñar un ejercicio de relajación (respiración 4-7-8)',
      'Después del examen: NUNCA preguntar primero por la nota',
    ],
    ermutigung:
        'Los niños que saben que se les quiere de forma incondicional tienen menos miedo.',
  ),
  'grund_05': ElternWissenText(
    question: 'Mi hijo dice que me odia',
    akut:
        'Duele. Pero tu hijo quiere decir: ahora mismo estoy tan enfadado que no sé qué hacer con esto.',
    beduerfnis:
        'Los niños ponen a prueba si el vínculo aguanta, aunque digan lo peor. Tu hijo necesita la experiencia de que no te marchas.',
    gfkSatz:
        'Escucho que ahora mismo estás muy enfadado. Te quiero, aunque estés molesto conmigo.',
    aktion: [
      'No responder con lo mismo («¡Pues vete!»)',
      'No marcharse ofendido',
      'Hablarlo después: «Eso me ha dolido. ¿Qué te ha puesto tan enfadado?»',
    ],
    ermutigung:
        'Un niño que te dice lo que siente (aunque sea feo) confía en ti. Eso es vínculo.',
  ),

  // ─────────────────── ADOLESCENTE (10-16 años) ────────────────────────────
  'teen_01': ElternWissenText(
    question: 'Mi adolescente ya no habla conmigo',
    akut:
        'No insistas. No te ofendas. Muestra presencia sin expectativas. Está disponible.',
    beduerfnis:
        'Los adolescentes necesitan separarse para construir su identidad. El retraimiento no es rechazo, sino desarrollo.',
    gfkSatz:
        'Estoy aquí si quieres hablar. Sin presión. No pregunto, pero te escucho cuando vengas.',
    aktion: [
      'Ofrecer actividades juntos SIN presión por hablar (cocinar, ir en coche)',
      'No llenar cada silencio',
      'Compartir tus propias emociones: «A veces echo de menos nuestras conversaciones»',
    ],
    ermutigung:
        'Tu adolescente te quiere. Ahora mismo necesita espacio. Deja la puerta abierta: volverá.',
  ),
  'teen_02': ElternWissenText(
    question: 'Mi adolescente no respeta ninguna regla',
    akut:
        'Menos reglas, pero más claras. Pregúntate: ¿qué 3 reglas son DE VERDAD importantes?',
    beduerfnis:
        'Los adolescentes necesitan una autonomía creciente. Demasiadas reglas se viven como control, y el control genera resistencia.',
    gfkSatz:
        'Me preocupo porque a las 23 h no estabas en casa. Me importa tu seguridad, no controlarte.',
    aktion: [
      'Negociar las reglas EN COMÚN (no dictarlas)',
      'Hablar las consecuencias de antemano (no en caliente)',
      'Distinguir: ¿qué es seguridad (no negociable) y qué es gusto (negociable)?',
    ],
    ermutigung:
        'Los adolescentes que rompen reglas no se vuelven delincuentes. Se hacen adultos.',
  ),
  'teen_03': ElternWissenText(
    question: 'Me preocupa la autoimagen de mi adolescente',
    akut:
        'Escucha sin relativizar. No digas: «¡Pero si eres guapo!». Di: «Cuéntame más».',
    beduerfnis:
        'En la adolescencia la autoimagen es frágil. Las redes sociales intensifican las comparaciones. Tu hijo necesita palabras ancla que NO valoren lo externo.',
    gfkSatz: 'Tienes valor, no por tu aspecto, sino por quien eres.',
    aktion: [
      'No comentar nunca el cuerpo (ni siquiera en positivo)',
      'Nombrar fortalezas que no tengan nada que ver con el aspecto',
      'Dar ejemplo: ¿cómo hablas TÚ de tu propio cuerpo?',
    ],
    ermutigung:
        'Tu voz se convierte en la voz interior de tu hijo. Hazla cariñosa.',
  ),

  // ───────────────────── GENERAL (todas las edades) ────────────────────────
  'allg_01': ElternWissenText(
    question: 'Cómo poner límites sin castigar',
    akut:
        'Límite = lo que TÚ necesitas, no lo que el niño hace mal. «Para mí es importante que...» en vez de «¡No puedes!».',
    beduerfnis:
        'Los niños necesitan límites, pero cariñosos. Los límites dan orientación; los castigos generan miedo.',
    gfkSatz:
        'No voy a permitir que me pegues. No porque seas malo, sino porque mi cuerpo me importa.',
    aktion: [
      'Formular los límites como un mensaje en primera persona (no como un reproche)',
      'Consecuencias en lugar de castigos (naturales, no arbitrarias)',
      'Poner el límite Y reconocer la emoción («Estás molesto Y ahora nos vamos»)',
    ],
    ermutigung: 'Poner límites ES amor. Tu hijo necesita tu guía.',
  ),
  'allg_02': ElternWissenText(
    question: 'Me siento un mal progenitor',
    akut: 'Estás aquí. Buscas respuestas. Eso es lo contrario de ser malo.',
    beduerfnis:
        'La culpa parental está por todas partes. Las redes sociales muestran familias perfectas que no existen. Tu sentimiento es humano.',
    gfkSatz:
        'Soy suficientemente bueno. Mi hijo no me necesita perfecto, me necesita auténtico.',
    aktion: [
      'Reducir las comparaciones (limitar las redes sociales)',
      'Pedir ayuda es una fortaleza (asesoramiento, apoyo mutuo, descarga)',
      'Nombrar cada día 1 cosa que ha salido bien',
    ],
    ermutigung:
        'Los padres perfectos no existen. Los buenos padres son los que lo vuelven a intentar una y otra vez.',
  ),
  'allg_03': ElternWissenText(
    question: 'Mi hijo no me hace caso',
    akut:
        'Los niños «hacen caso» cuando se SIENTEN escuchados. Ponte a su altura. Tócale el hombro. Luego habla.',
    beduerfnis:
        'No hacer caso rara vez es falta de respeto. A menudo: el niño está absorto, sobreestimulado, o la petición era demasiado compleja.',
    gfkSatz:
        'Oye, necesito un momento tu atención. Mírame: quiero decirte algo.',
    aktion: [
      'Acercarse en lugar de gritar de un lado al otro de la habitación',
      'Frases cortas y claras (no «¿Recoges, por favor, en algún momento...?»)',
      'Avisar: «En 5 minutos nos vamos, ve preparándote»',
    ],
    ermutigung:
        'Los niños a los que se habla a su altura cooperan un 80 % mejor.',
  ),
  'allg_04': ElternWissenText(
    question: 'Cómo le explico a mi hijo una separación',
    akut:
        'Contadlo juntos si es posible. Mensaje central: no es culpa tuya. Los dos te queremos.',
    beduerfnis:
        'Los niños necesitan: seguridad («¿Dónde voy a vivir?»), amor («¿Me siguen queriendo los dos?») y previsibilidad («¿Qué va a cambiar?»).',
    gfkSatz:
        'Mamá y papá han decidido vivir separados. Esto no tiene nada que ver contigo. Los dos te queremos exactamente igual.',
    aktion: [
      'Adaptado a la edad: palabras sencillas, pocos detalles sobre los motivos',
      'Concreto: ¿qué se mantiene igual? (el cole, los amigos, el peluche)',
      'Permitir las emociones: «Puedes estar triste y enfadado»',
    ],
    ermutigung:
        'Los niños superan las separaciones si los padres se tratan con respeto.',
  ),
  'allg_05': ElternWissenText(
    question: 'Cómo refuerzo la confianza en sí mismo de mi hijo',
    akut:
        'No elogies LO que hace («¡Qué bien has dibujado!»), sino CÓMO lo vive («¡Estás muy orgulloso de tu dibujo!»).',
    beduerfnis:
        'La confianza en uno mismo surge de: eficacia personal (sé hacer cosas), pertenencia (formo parte) y autonomía (puedo decidir).',
    gfkSatz: 'Veo cuánto te has esforzado. ¿Cómo te hace sentir eso?',
    aktion: [
      'Dejar que el niño haga las cosas SOLO (aunque tarde más)',
      'Elogiar el proceso en vez del resultado («No te rendiste, eso fue valiente»)',
      'Normalizar los errores: «¡Vaya! ¿Qué podríamos hacer distinto la próxima vez?»',
    ],
    ermutigung:
        'La confianza crece con la experiencia, no con las palabras. Deja que tu hijo fracase y se vuelva a levantar.',
  ),
  'allg_06': ElternWissenText(
    question: 'Mi hijo tiene miedo al colegio',
    akut:
        'Toma en serio el miedo. No digas: «No exageres». Di: «Cuéntame qué te preocupa».',
    beduerfnis:
        'El miedo al colegio puede tener muchas causas: conflictos sociales, agobio, la figura del profesor o la presión por el rendimiento.',
    gfkSatz:
        'Escucho que el colegio se te hace cuesta arriba ahora mismo. Encontraremos juntos una solución.',
    aktion: [
      'Preguntar con detalle: ¿QUÉ le da miedo? (¿una asignatura?, ¿una persona?, ¿el recreo?)',
      'Implicar a la profesora (sin dejar al niño en evidencia)',
      'Un ritual matutino que dé seguridad (una secuencia fija, el desayuno favorito)',
    ],
    ermutigung:
        'El miedo al colegio tiene solución. A menudo bastan pequeños cambios para un gran alivio.',
  ),
  'allg_07': ElternWissenText(
    question: 'Cómo consigo que mi hijo se lave los dientes',
    akut:
        'No pelees. De forma lúdica: «¿Puedo cepillar los dientes de cocodrilo?» o «¿Quién encuentra el azúcar escondido?».',
    beduerfnis:
        'Lavarse los dientes es una lucha de autonomía (la boca es la zona más íntima). Tu hijo quiere decidir por sí mismo.',
    gfkSatz:
        'Tus dientes necesitan ayuda. ¿Quieres empezar tú primero o empiezo yo?',
    aktion: [
      'Opciones: ¿qué cepillo?, ¿qué canción mientras?',
      'Temporizador o canción (una canción de 2 minutos para cepillarse)',
      'Plantear el repaso final como un ritual, no como una lucha de poder',
    ],
    ermutigung:
        'Antes o después, todos los niños se cepillan por voluntad propia. Hasta entonces: sigue siendo creativo.',
  ),
  'allg_08': ElternWissenText(
    question: 'Mi hijo se duerme mal (niño de primaria)',
    akut:
        'La rutina de la noche lo es todo: la misma hora, el mismo ritual, nada de pantallas 45 minutos antes.',
    beduerfnis:
        'Los niños de primaria suelen estar sobreestimulados por el día. Su cabeza necesita una transición de «activo» a «calma».',
    gfkSatz:
        'Tu cuerpo necesita dormir para estar fuerte mañana. ¿Qué te ayuda a tranquilizarte?',
    aktion: [
      'Una hora de dormir fija (incluso el fin de semana, con 1 h de margen como máximo)',
      'Rutina: baño, dientes, leer un cuento, mimos, apagar la luz',
      'Rato de preocupaciones: 5 minutos ANTES de la cama, «¿Qué te ronda la cabeza?»',
    ],
    ermutigung:
        'Los problemas de sueño en niños de primaria suelen ser pasajeros (un estirón, el estrés escolar).',
  ),
  'allg_09': ElternWissenText(
    question: 'Mis hijos se pelean constantemente',
    akut:
        'No hagas de árbitro enseguida. Pregunta: ¿necesitáis mi ayuda o lo resolvéis vosotros?',
    beduerfnis:
        'Las peleas entre hermanos son NORMALES e importantes. Con ellas los niños aprenden a negociar, a ceder y a cambiar de perspectiva.',
    gfkSatz:
        'Veo que los dos estáis frustrados. ¿Qué necesita cada uno ahora mismo?',
    aktion: [
      'Intervenir solo cuando se vuelve físico',
      'No tomar partido («¿Quién empezó?» no sirve de nada)',
      'Validar la emoción de cada niño ANTES de buscar una solución',
    ],
    ermutigung:
        'Los hermanos que se pelean aprenden a resolver conflictos. Es una competencia para la vida.',
  ),
};
