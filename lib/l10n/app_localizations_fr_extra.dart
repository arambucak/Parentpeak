// Fr Übersetzungen (Kern + Tiefe). Entwurf; Fachtexte (Finanzen) und
// bei RTL das Layout vor breiter Vermarktung von Muttersprachlern prüfen.
// Platzhalter wie {count}, {name} bleiben exakt erhalten.
const appLocalizationsFrExtra = <String, String>{
  'chat_ask_none':
      'Ne pose pas de question de suivi ; les informations suffisent pour des étapes concrètes.',
  'chat_ask_one':
      'Pose à la fin exactement UNE question courte et ouverte pour la prochaine étape utile.',
  'chat_boundary_retry':
      'Ne réponds pas par une formule de limite générale, mais de façon concrète, empathique et orientée vers des solutions pour le quotidien des parents.',
  'chat_coaching_prompt':
      'Demande du parent :\n{message}\n\nPosture : empathique, chaleureuse, sans jugement selon la CNV, Hüther et Juul. Lentille de Hüther : lien ou autonomie ? La relation avant la pression, l\'exemple plutôt que la leçon, l\'enthousiasme d\'apprendre ; les parents se tiennent à côté de l\'enfant au lieu de résoudre tous les obstacles.\nFormat : d\'abord 1 à 2 phrases empathiques ; les sentiments/besoins seulement comme hypothèse. Une courte lecture axée sur le développement et l\'attachement, exactement UNE étape de CNV, 1 à 2 petites options sous forme de proposition. {followUp}\nFocus : {focus}\nD\'autres approches pédagogiques seulement de façon OPTIONNELLE si pertinentes, sans exposé théorique.\nPas de leçon de morale, de formules toutes faites, de jugements hâtifs ni de « Tu dois ». Traduire avec empathie les reproches envers soi-même en sentiment/besoin. Conserver les indications concrètes d\'âge, de moment de la journée et de situation. Paragraphes courts, 3 à 4 phrases au maximum ; pas d\'astérisques/Markdown, ton calme et professionnel, 0 à 2 emojis, listes simples autorisées. {continuation}\nAncre de contexte : {context}\nContexte de l\'historique : {history}',
  'chat_context_retry':
      'Réponds à nouveau et reprends visiblement ces informations importantes : {context}. Reste empathique, concret et proche du quotidien.',
  'chat_continue_context':
      'Reprends les schémas pertinents et les indications d\'âge issus de l\'historique sélectionné ; n\'invente aucun nom réel.',
  'chat_focus_anger':
      'Co-régulation, limites claires sans humiliation et désescalade brève ; Juul : guider avec respect plutôt que d\'imposer l\'obéissance.',
  'chat_focus_general':
      'Soulagement immédiatement utilisable et axé sur l\'attachement ; en option, une lentille adaptée parmi Montessori, Reggio, Froebel, Freinet, Juul ou l\'approche situationnelle.',
  'chat_focus_learning':
      'Montessori : « Aide-moi à faire seul », préparer l\'environnement et voir les tâches du quotidien comme des occasions d\'apprendre ; approche situationnelle : le monde de vie actuel.',
  'chat_focus_media':
      'Des limites claires convenues à l\'avance et des transitions coopératives plutôt qu\'un rapport de force ; Juul : guider avec respect.',
  'chat_focus_play':
      'Froebel : le jeu comme apprentissage ; Reggio : de multiples formes d\'expression, le processus avant le résultat ; Freinet : de vraies expériences du quotidien.',
  'chat_focus_school':
      'Une structure adaptée à l\'enfant et une coopération avec les professionnels ; approche situationnelle : le monde de vie de l\'enfant ; Juul : coopération plutôt qu\'obéissance.',
  'chat_focus_siblings':
      'Séparer sans punir, refléter les sentiments, favoriser un rapprochement/une réparation équitable ; Juul : prendre les deux enfants pleinement au sérieux.',
  'chat_focus_sleep':
      'Un soulagement réaliste, de petits rituels et des étapes qui ménagent l\'énergie ; Juul : accompagner de façon authentique et respectueuse.',
  'chat_new_context':
      'Reste sur la demande actuelle, sans rétrospective inventée.',
  'chat_no_context': 'aucun',
  'chat_quality_retry':
      'Réponds plus concrètement et de façon authentique : l\'empathie d\'abord, une étape de CNV, 1 à 2 petites options, les sentiments/besoins comme hypothèse. Focus : {focus} Des paragraphes courts de 3 à 4 phrases au maximum, pas de mur de texte, de formule de limite ni de « Tu dois ». {followUp}',
  'chat_repair_prompt':
      'Reformule de façon purement non violente, axée sur l\'attachement et selon la CNV. Pas de reproches, de menaces ni de punitions. Donne trois étapes concrètes du quotidien et deux exemples de phrases. Focus : {focus}',
  'chat_system_prompt':
      'Tu es le coach parental ParentPeak, chaleureux et sans jugement, pour le quotidien avec les enfants (0 à 18 ans). Réponds dans la langue demandée, de manière personnelle et sans faire la leçon.\nFondements : Hüther – lien et autonomie, enthousiasme et implication émotionnelle plutôt que pression/peur ; les enfants apprennent par l\'exemple, pas par la leçon. Ne pas faire de l\'enfant l\'objet d\'attentes. Ne pas retirer les obstacles surmontables, les parents se tiennent à côté ; distinguer les vrais besoins des désirs matériels. Relation, présence et exemple plutôt que récompense/punition. CNV de Rosenberg : observation, sentiment, besoin, demande ; des phrases concrètes pour aujourd\'hui. Refléter les sentiments/besoins avec prudence, sans les affirmer comme des faits. Juul : les enfants comme des personnes à part entière, une guidance aimante, la responsabilité de soi plutôt que l\'obéissance.\nEn option si pertinent : Montessori – rythme propre, environnement préparé, autonomie ; Reggio – de multiples formes d\'expression, l\'observation plutôt que le jugement, le processus/la curiosité ; Freinet – de vraies expériences, l\'expression libre, l\'autodétermination ; Froebel – le jeu/la nature/la créativité comme apprentissage ; approche situationnelle – le monde de vie actuel plutôt qu\'un programme rigide.\nBref, concret, 8 à 10 lignes au maximum, de petites étapes immédiatement utilisables. L\'empathie avant la stratégie ; pas de leçon de morale, de jugements ni de murs de texte. Pas de diagnostics/médicaments, nommer les limites honnêtement. En cas de danger aigu, recommander une aide humaine directe ; ne pas inventer de numéros de téléphone spécifiques à un pays non vérifiés. La règle de question de l\'instruction de coaching actuelle s\'applique ; ne pas poser systématiquement une question en plus.',
  'chat_tip_age_known':
      'L\'enfant a {age} années révolues. Adapte les exemples en conséquence.',
  'chat_tip_age_unknown':
      'L\'âge n\'est pas connu. N\'en invente pas ; demande au besoin.',
  'chat_tip_prompt':
      'Les parents souhaitent approfondir ce conseil :\n"{tip}"\n{ageContext}\nExplique brièvement sa pertinence, trois situations concrètes du quotidien et un exercice pour aujourd\'hui. Pratique, non violent, 12 lignes au maximum.',
  'dev_answer_not_yet': 'Pas encore',
  'dev_answer_sometimes': 'Parfois',
  'dev_answer_yes': 'Oui',
  'development_consent_body':
      'Pour le rapport, les réponses de ce bilan de développement sont envoyées à notre service d\'IA (Google Gemini). Le prénom de ton enfant reste sur ton appareil et n\'est pas transmis. Tes informations sont uniquement traitées pour établir le rapport et ne sont pas conservées pour t\'identifier.',
  'development_consent_save_failed':
      'Le consentement n\'a pas pu être enregistré en toute sécurité ou le compte a changé. Aucun rapport d\'IA ne sera créé.',
  'development_report_special_needs':
      '- IMPORTANT : cet enfant a des besoins particuliers. Ne compare PAS aux normes d\'âge. Décris uniquement les progrès individuels. Au lieu de « besoin de soutien », dis « grandit à son propre rythme ». Sois particulièrement bienveillant et encourageant.',
  'finance_content_turkey_note_11': 'Cartable, fournitures, uniforme',
  'pdf_age_years': '{years} ans',
  'pdf_age_years_months': '{years} ans, {months} mois',
  'pdf_ai_report_title': 'Rapport de développement IA',
  'pdf_compare_with': 'Comparaison avec {date}',
  'pdf_created_on': 'Créé le {date}',
  'pdf_default_child_name': 'Enfant',
  'pdf_disclaimer':
      'Remarque : ce rapport repose sur les observations des parents et ne constitue pas un diagnostic médical. En cas d\'inquiétude concernant le développement de ton enfant, adresse-toi à ton pédiatre ou à un centre d\'intervention précoce.',
  'pdf_filename_prefix': 'Rapport de développement',
  'pdf_footer': 'Créé avec Parentpeak — parentpeak.de',
  'pdf_legend_current': 'Actuel',
  'pdf_legend_previous': 'Bilan précédent',
  'pdf_page_of': 'Page {page} sur {total}',
  'pdf_progress_title': 'Évolution du développement',
  'pdf_report_title': 'Rapport de développement',
  'pdf_trend_down': 'en pause',
  'pdf_trend_stable': 'stable',
  'pdf_trend_up': 'progresse',
  'account_suspended_message':
      'Votre compte a été temporairement restreint. Pour toute question, contactez notre support – nous sommes là pour vous aider.',
  'account_suspended_title': 'Compte temporairement restreint',
  'add_friend_code': 'Ajouter un ami par code',
  'add_meal': 'Ajouter un repas',
  'add_person': 'Ajouter une personne',
  'admin_action_failed': 'Action échouée.',
  'admin_cleanup_empty':
      'Tout est propre — aucun enregistrement défectueux trouvé. 🎉',
  'admin_cleanup_failed': 'Échec du nettoyage. Réessaie plus tard.',
  'admin_cleanup_message':
      '{count} entrées de connexion défectueuses ont été trouvées (codes invalides ou orphelins). Elles seront supprimées.\n\nLes vrais utilisateurs, les noms et les chats restent intacts.',
  'admin_cleanup_preview_failed': 'Échec de l\'aperçu. Réessaie plus tard.',
  'admin_cleanup_success':
      '{count} entrées nettoyées. La base de données est propre. ✅',
  'admin_cleanup_title': 'Nettoyer la base de données ?',
  'admin_cleanup_tooltip': 'Nettoyer la base de données',
  'admin_community_safe': 'Tout est calme. Ta communauté est en sécurité.',
  'admin_filter_all': 'Tous',
  'admin_filter_done': 'Traités',
  'admin_filter_open': 'Ouverts',
  'admin_ignore': 'Ignorer',
  'admin_last_reason': 'Dernier motif : {reason}',
  'admin_load_failed':
      'Impossible de charger les signalements. Réessaie plus tard.',
  'admin_locked': 'suspendu',
  'admin_no_access':
      'Pas d\'accès administrateur. Connecte-toi avec un compte admin.',
  'admin_no_reports': 'Aucun signalement ouvert',
  'admin_reason_fraud': 'Fraude / faux',
  'admin_reason_inappropriate': 'Contenu inapproprié',
  'admin_reason_insult': 'Insulte / discours haineux',
  'admin_reason_other': 'Autre',
  'admin_reason_spam': 'Spam / publicité',
  'admin_remove_count': 'Supprimer {count}',
  'admin_reported_count': 'Signalé {count}×',
  'admin_reports_resolved': 'Signalements marqués comme vérifiés.',
  'admin_suspend_action': 'Suspendre',
  'admin_suspend_failed': 'Échec de la suspension.',
  'admin_suspend_message':
      'Le compte sera masqué du réseau et de la découverte. La suspension est réversible — aucune donnée n\'est supprimée.\n\nID utilisateur : {userId}',
  'admin_suspend_title': 'Suspendre le compte ?',
  'admin_suspended': 'Compte suspendu.',
  'admin_title': 'Modération',
  'admin_unlock': 'Lever la suspension',
  'admin_unsuspended': 'Suspension levée.',
  'admin_user_id': 'Utilisateur : {userId}',
  'age_months': '{count} mois',
  'age_years': '{count} ans',
  'age_years_months': '{years} ans, {months} mois',
  'ai_disclosure': 'Note sur l\'utilisation de l\'IA',
  'all_events': 'Tout →',
  'all_seen': 'Tout vu',
  'antrag_ai_description':
      'L\'IA crée pour toi une lettre d\'accompagnement ou une justification, prête à copier.',
  'antrag_ai_disclaimer':
      'Ceci est un modèle, pas un conseil juridique. Adapte le texte à ta situation personnelle.',
  'antrag_ai_failed': 'Impossible de créer le modèle de texte. Réessaie.',
  'antrag_ai_tab': 'Aide IA',
  'antrag_ai_template': 'Modèle de texte IA',
  'antrag_ai_writing': 'L\'IA rédige...',
  'antrag_all_ready': 'Tout est prêt !',
  'antrag_content_limits':
      'Orientation générale, pas un conseil juridique. Tous les documents, délais et détails de procédure ne sont pas vérifiés officiellement. Vérifie les exigences actuelles et les délais de recours auprès du service compétent.',
  'antrag_copied': '📋 Copié dans le presse-papiers !',
  'antrag_copy_failed': 'Échec de la copie. Réessaie.',
  'antrag_documents_count': '{checked} documents sur {total} prêts',
  'antrag_documents_tab': 'Documents',
  'antrag_guide_tab': 'Guide',
  'antrag_need_documents': 'Ce dont tu as besoin',
  'antrag_next_guide': 'Passer au guide',
  'antrag_open_link': 'Ouvrir le lien',
  'antrag_open_online': 'Ouvrir la demande en ligne',
  'antrag_optional': 'Facultatif',
  'antrag_premium_description':
      'Avec Premium, tu obtiens le guide complet, les modèles de texte IA et les rappels.',
  'antrag_premium_soon':
      'Premium arrive bientôt ! Pendant la bêta, tout est gratuit.',
  'antrag_processing_time': '⏱️ Délai de traitement : {time}',
  'antrag_ready_next': 'Tu as réuni tous les documents. Passe à l\'étape 2 !',
  'antrag_regenerate': 'Régénérer',
  'antrag_step_guide': 'Guide étape par étape',
  'antrag_template': 'Modèle',
  'antrag_unlock_premium': 'Débloquer Premium',
  'application_authority': 'Service compétent : {authority}',
  'application_create_template': 'Créer un modèle de texte pour {benefit}',
  'apply_filter': 'Appliquer le filtre',
  'appointments_tasks': 'Rendez-vous et tâches',
  'archive': 'Archives',
  'auth_email_address_label': 'Adresse e-mail',
  'auth_email_confirm_instructions':
      'Cliquez sur le lien dans l\'e-mail. Vous pourrez ensuite vous connecter.',
  'auth_email_confirm_title': 'Confirmez votre e-mail 📬',
  'auth_email_invalid': 'Veuillez saisir une adresse e-mail valide.',
  'auth_email_label': 'E-mail',
  'auth_email_required': 'L\'e-mail est requis.',
  'auth_email_resent': '✅ Un nouveau lien a été envoyé.',
  'auth_email_sent': 'Nous avons envoyé un e-mail de confirmation à\n{email}.',
  'auth_password_label': 'Mot de passe',
  'auth_password_required': 'Le mot de passe est requis.',
  'auth_resend_link': 'Renvoyer le lien',
  'auth_to_login': 'Vers la connexion',
  'auth_url_open_failed': 'Impossible d\'ouvrir {url}.',
  'auto_next': 'Suivant auto',
  'back': 'Retour',
  'backup_exported': 'Sauvegarde exportée',
  'backup_import': 'Importer une sauvegarde',
  'backup_qr': 'Sauvegarde en QR',
  'backup_restored': 'Sauvegarde restaurée',
  'bedtime_actions': 'Voici ce que tu peux faire maintenant :',
  'bedtime_done': 'Bonne nuit ! Routine terminée.',
  'bedtime_how': 'Comment ça marche',
  'bedtime_start': 'Commencer',
  'bedtime_subtitle': 'Au lit, détendus, en 30 min',
  'bedtime_title': 'Routine du soir',
  'benefit_ai_consent_accept': 'Accepter et utiliser l\'IA',
  'benefit_ai_consent_body':
      'Pour une orientation personnalisée, votre texte libre, les éléments de situation sélectionnés, le pays ainsi que l\'âge des enfants existant sont envoyés via le serveur ParentPeak à Google Gemini. Gemini peut utiliser une recherche web à cet effet. Les coordonnées connues sont partiellement supprimées ; ce n\'est pas une anonymisation complète. N\'indiquez ni noms, ni adresses, ni détails de santé. Les informations ne sont pas enregistrées ici comme conversation. Le consentement vaut pour ce compte ou le mode invité. Sans consentement, les informations générales sur les aides restent disponibles, mais aucune requête IA n\'est lancée.',
  'benefit_ai_consent_failed':
      'Impossible d\'enregistrer le consentement. Aucune requête IA n\'a été lancée.',
  'benefit_ai_consent_title': 'Utiliser le guide des aides par IA ?',
  'benefit_ask_action': 'Interroger le guide',
  'benefit_check_link': '🔗 Vérifier ici →',
  'benefit_checklist_title': 'Votre check-list',
  'benefit_chip_income': 'Faibles revenus',
  'benefit_chip_leave': 'Congé parental',
  'benefit_chip_move': 'Déménagement',
  'benefit_chip_salary': 'Baisse de salaire',
  'benefit_chip_second': 'Deuxième enfant à venir',
  'benefit_chip_single': 'Parent solo',
  'benefit_disclaimer':
      'Ceci est une orientation, pas un conseil juridique. Seule l\'autorité compétente fait foi. Les montants y sont calculés au cas par cas.',
  'benefit_fallback_check':
      'Vérifiez les organismes officiels liés pour les détails.',
  'benefit_fallback_notice':
      'La réponse de l\'IA n\'est pas disponible. Ceci est une orientation générale et locale pour votre pays, non adaptée à votre situation.',
  'benefit_fallback_prepare':
      'Préparez votre pièce d\'identité, les justificatifs de revenus et l\'acte de naissance.',
  'benefit_guide_title': 'Guide des aides',
  'benefit_input_required':
      'Décrivez brièvement votre situation ou choisissez une impulsion.',
  'benefit_loading': 'Je regarde ce qui pourrait vous concerner…',
  'benefit_local_only': 'reste sur cet appareil',
  'benefit_matches_title': 'Cela pourrait vous concerner',
  'benefit_next_steps': 'Prochaines étapes',
  'benefit_request_failed':
      'Je n\'ai pas pu répondre à l\'instant. Réessayez dans un moment.',
  'benefit_situation_description':
      'Dans vos propres mots – p. ex. « Deuxième enfant en juin, le partenaire travaille à temps partiel ».',
  'benefit_situation_hint': 'Votre situation…',
  'benefit_situation_title': 'Décrivez brièvement votre situation',
  'benefit_sources': 'Sources',
  'benefit_start_application': 'Démarrer l\'assistant de demande',
  'block_profile': 'Bloquer le profil',
  'breakfast': 'Petit-déjeuner',
  'budget_positions_imported': '{count} postes importés.',
  'cancel_reservation': 'Annuler la réservation',
  'caregiver_role': 'Personne de référence',
  'change_action': 'Modifier',
  'chat_access_unavailable':
      'Cette conversation n\'est pas disponible pour ce compte.',
  'chat_always_here': 'Toujours là pour toi',
  'chat_boundary_diagnosis':
      'Je ne peux pas poser de diagnostic. Je peux offrir une aide du quotidien centrée sur l\'attachement. Pour un éclaircissement diagnostique, adresse-toi à ton pédiatre ou à la psychologie de l\'enfant et de l\'adolescent.',
  'chat_boundary_medical':
      'Je ne donne pas de recommandations médicales ni d\'indications sur les médicaments. Utilise un avis médical ou le service de garde médicale local.',
  'chat_boundary_topic':
      'Je suis là pour un accompagnement parental pédagogique. Décris volontiers ta question de famille ou d\'éducation.',
  'chat_boundary_violence':
      'Je ne donne pas d\'instructions blessantes ou favorisant la violence. Je t\'aide volontiers avec une approche non violente : observation, sentiment, besoin et demande concrète.',
  'chat_claim_action': 'Confirmer la propriété',
  'chat_claim_failed':
      'Impossible de reprendre la statistique de thèmes. Les données existantes sont conservées.',
  'chat_consent_load_failed':
      'Impossible de vérifier le consentement à l\'IA. Sans consentement confirmé, rien n\'est envoyé à l\'IA.',
  'chat_consent_save_failed':
      'Impossible d\'enregistrer le consentement. Aucune requête IA n\'a été lancée. Veuillez réessayer.',
  'chat_daily_limit':
      'Ta limite quotidienne de {limit} requêtes IA est atteinte. Tu pourras reposer des questions demain.',
  'chat_delete': 'Supprimer',
  'chat_delete_failed': 'Échec de la suppression, réessayez plus tard.',
  'chat_delete_for_all': 'Supprimer pour tous',
  'chat_delete_for_all_confirm':
      'Tout l\'historique sera supprimé définitivement pour tous les participants. Action irréversible.',
  'chat_delete_for_all_hint':
      'Retirer l\'historique pour tous les participants',
  'chat_delete_for_me': 'Supprimer pour moi',
  'chat_delete_for_me_confirm':
      'Cette discussion sera retirée uniquement pour vous. L\'autre personne conserve l\'historique.',
  'chat_delete_for_me_hint': 'Disparaît uniquement chez vous',
  'chat_delete_history_confirm':
      'Voulez-vous vraiment supprimer l\'historique de discussion actuel ?',
  'chat_deleted': 'Discussion supprimée.',
  'chat_fallback_anger':
      'D\'abord assurer la sécurité, puis refléter les sentiments avec douceur et proposer une alternative. Par exemple : « Je vois ta colère. Je ne laisserai personne se faire mal. Tu peux taper du pied ou presser le coussin. » Que se passe-t-il juste avant ?',
  'chat_fallback_general':
      'Tu n\'es pas seul·e dans cette situation. Décris volontiers la situation concrète et l\'âge révolu, sans noms ni dates de naissance précises. Observation, sentiment, besoin et demande pourront alors devenir concrets pour le quotidien.',
  'chat_fallback_label':
      'Orientation générale et curée : la réponse de l\'IA n\'était pas adaptée. Ceci n\'est pas une réponse personnalisée fiable.',
  'chat_fallback_sleep':
      'Le soir, tu pourrais réduire les stimulations, proposer un petit choix entre un livre et une chanson, et répéter une formule de clôture apaisante. Par exemple : « Tu voudrais rester éveillé·e. Je t\'accompagne maintenant vers le calme. » Quelle transition vous est la plus difficile ?',
  'chat_feedback_dangerous': 'dangereux',
  'chat_feedback_helpful': 'utile',
  'chat_feedback_inappropriate': 'inapproprié',
  'chat_feedback_not_helpful': 'pas utile',
  'chat_feedback_saved': 'Retour enregistré : {feedback}',
  'chat_greeting_day': 'Bonjour',
  'chat_greeting_evening': 'Bonsoir',
  'chat_greeting_morning': 'Bonjour',
  'chat_greeting_night': 'Bonne nuit',
  'chat_guidelines': 'Règles de la discussion',
  'chat_history_budget':
      'L\'IA reçoit au plus les {rounds} derniers tours de conversation et {characters} caractères d\'historique. Les messages plus anciens restent visibles ici.',
  'chat_how_can_help': 'Comment puis-je aider ?',
  'chat_inappropriate': 'Contenu inapproprié',
  'chat_init_error': 'Erreur : {error}',
  'chat_insight_attachment': 'Attachement et émotions',
  'chat_insight_autonomy': 'Phase d\'autonomie',
  'chat_insight_conflicts': 'Conflits',
  'chat_insight_crisis': 'Crise',
  'chat_insight_media': 'Écrans',
  'chat_insight_nutrition': 'Alimentation',
  'chat_insight_other': 'Autre',
  'chat_insight_school': 'École/crèche',
  'chat_insight_siblings': 'Frères et sœurs',
  'chat_insight_sleep': 'Sommeil',
  'chat_legacy_body':
      'Une ancienne statistique de thèmes sans compte associé se trouve sur cet appareil. Ne la reprenez que si elle vous appartient. La reprise est locale, n\'envoie rien à l\'IA et ne reprend aucun historique de conversation. Les données d\'origine sont conservées.',
  'chat_legacy_title': 'Statistiques de thèmes locales non attribuées',
  'chat_medical_de':
      'En Allemagne, le service de garde médicale est joignable au 116117.',
  'chat_memory_load_failed':
      'Impossible de charger le contexte de mémoire IA. Réessayez dans les réglages de mémoire.',
  'chat_message_hint': 'Dis-moi ce qui te préoccupe…',
  'chat_other': 'Autre',
  'chat_privacy_footer': 'Aucun diagnostic · Traitement par Google Gemini',
  'chat_provider_authorization': 'Le service n\'a pas autorisé la requête.',
  'chat_provider_network': 'La connexion a échoué ou a pris trop de temps.',
  'chat_provider_quota': 'Le quota du service est actuellement atteint.',
  'chat_provider_unavailable':
      'La consultation IA n\'est pas disponible pour le moment. Aucune réponse personnelle fiable n\'est disponible. Réessayez plus tard.',
  'chat_provider_unavailable_reason':
      'Le service n\'a pas pu fournir de réponse valide.',
  'chat_report': 'Signaler',
  'chat_report_message': 'Signaler le message',
  'chat_report_thanks': 'Merci ! Nous allons vérifier.',
  'chat_request_failed':
      'Impossible de charger la réponse. Veuillez réessayer.',
  'chat_retry_later': 'Vous pouvez réessayer plus tard.',
  'chat_retry_missing_question':
      'Aucune question précédente trouvée pour réessayer.',
  'chat_safety_concern': 'Préoccupation de sécurité',
  'chat_spam': 'Spam',
  'chat_terms_accept': 'Accepter le traitement par l\'IA',
  'chat_terms_intro': 'Avant de commencer, lis brièvement ceci :',
  'chat_terms_no_diagnosis_text':
      'L\'IA ne pose aucun diagnostic médical ou psychologique. En cas d\'inquiétude sérieuse, adresse-toi à un professionnel.',
  'chat_terms_no_diagnosis_title': 'Aucun diagnostic',
  'chat_terms_privacy_text':
      'Ton message et l\'historique de discussion actuel sont envoyés via le backend ParentPeak à Google Gemini pour générer la réponse. Le texte libre peut contenir des noms et des données de santé ; l\'anonymisation automatique n\'est pas complète. Uniquement avec un consentement mémoire supplémentaire, le backend ajoute des désignations neutres de l\'enfant, l\'âge révolu et des informations familiales confirmées, y compris des données de santé. N\'envoie que des données dont tu acceptes le traitement. La discussion reste temporairement en mémoire vive, pas comme historique conservé durablement. Les fréquences de thèmes et ton consentement sont enregistrés localement. Ce consentement vaut pour ce compte sur cet appareil ; il ne publie aucune donnée.',
  'chat_terms_privacy_title': 'Traitement par Google Gemini',
  'chat_terms_respect_text':
      'L\'IA ne juge jamais toi ni ton enfant. Elle accompagne sans culpabilisation et sans pression.',
  'chat_terms_respect_title': 'Respectueux et bienveillant',
  'chat_tip_message': '💡 Astuce : « {tip} »',
  'chat_topic_analysis_privacy':
      'Économe en données : seuls des compteurs de thèmes sont enregistrés, aucun texte brut.',
  'chat_topic_analysis_title': 'Analyse des thèmes',
  'chat_topic_overwhelmed_label': 'Je suis à bout',
  'chat_topic_overwhelmed_question':
      'Je suis complètement épuisé·e et je me sens dépassé·e.',
  'chat_topic_school_label': 'École et apprentissage',
  'chat_topic_school_question':
      'Mon enfant est stressé par l\'école. Comment puis-je aider ?',
  'chat_topic_screen_label': 'Trop de temps d\'écran',
  'chat_topic_screen_question':
      'Mon enfant est tout le temps sur le téléphone. Comment gérer cela ?',
  'chat_topic_siblings_label': 'Les frères et sœurs se disputent',
  'chat_topic_siblings_question':
      'Mes enfants se disputent sans cesse. Dois-je intervenir ?',
  'chat_topic_sleep_label': 'Le coucher est un combat',
  'chat_topic_sleep_question':
      'Le coucher est un combat chaque soir. Que puis-je faire ?',
  'chat_topic_tantrum_label': 'Mon enfant fait des crises',
  'chat_topic_tantrum_question':
      'Mon enfant fait sans arrêt des crises et je ne sais plus quoi faire.',
  'chat_topics_load_failed':
      'Impossible de charger la statistique de thèmes. Veuillez recharger ; les données existantes ne sont pas écrasées.',
  'chat_topics_save_failed':
      'Impossible d\'enregistrer la statistique de thèmes. La modification n\'a pas été confirmée ; votre saisie est conservée.',
  'chat_understood': 'Compris',
  'chat_welcome_message':
      'Dis-moi ce qui te préoccupe en ce moment. J\'écoute, sans juger.',
  'child_name_example': 'p. ex. Emma',
  'child_role': 'Enfant',
  'choose_country_region': 'Choisis ton pays et ta région',
  'circle_accept': 'Accepter',
  'circle_decline': 'Refuser',
  'circle_invite': 'Inviter',
  'circle_invite_contact': 'Inviter un contact',
  'circle_no_self_request': 'Tu ne peux pas t\'envoyer une demande à toi-même.',
  'circle_remove': 'Retirer',
  'circle_remove_contact': 'Retirer le contact',
  'circle_send_request': 'Envoyer la demande',
  'circle_title': 'Cercle familial',
  'clipboard': 'Presse-papiers',
  'close': 'Fermer',
  'common_cancel': 'Annuler',
  'common_check_here': '🔗 Vérifier ici →',
  'common_delete_failed': 'Erreur lors de la suppression : {error}',
  'common_error_with_detail': 'Erreur : {error}',
  'common_link_open_failed': 'Impossible d\'ouvrir le lien.',
  'common_not_now': 'Pas maintenant',
  'common_status': 'Statut',
  'common_understood': 'Compris',
  'community_event_ai_recognizes':
      'L\'IA reconnaît automatiquement : le titre, la date, le lieu et la description',
  'community_event_create_anyway': 'Créer quand même',
  'community_event_from_gallery': 'Choisir dans la galerie',
  'community_event_photo_hint':
      'Prends une photo → l\'IA remplit tout automatiquement',
  'community_event_published': '✅ Événement publié !',
  'community_event_scan_flyer': 'Scanner un flyer / une affiche',
  'community_event_similar_found': 'Événement similaire trouvé',
  'community_event_take_photo': 'Prendre une photo',
  'community_flyer_detected': '✅ Flyer reconnu ! Vérifie les informations.',
  'community_title': 'Trouver d\'autres parents',
  'confirm': 'Confirmer',
  'confirm_delete_type': 'Saisissez « SUPPRIMER » pour confirmer :',
  'confirm_logout': 'Se déconnecter ?',
  'confirm_pickup': 'Confirmer le retrait',
  'confirm_reg': 'Confirmer l\'inscription',
  'confirm_registration': 'Confirmer l\'inscription',
  'contact_now': 'Contacter maintenant',
  'contact_support': 'Contact et assistance',
  'conversation_report_reason': 'Pourquoi veux-tu signaler {name} ?',
  'convo_block': 'Bloquer',
  'convo_parent_network': 'Réseau de parents',
  'convo_refresh': 'Actualiser',
  'convo_report_user': 'Signaler l\'utilisateur',
  'cooking_tips_title': 'Conseils repas en famille',
  'copy_code_close': 'Copier le code et fermer',
  'copy_link_close': 'Copier le lien et fermer',
  'country': 'Pays',
  'create_event': 'Planifier un événement',
  'current_status': 'Statut actuel',
  'daily_tip_explain': 'Explique-moi cela en détail',
  'daily_tip_title': 'Conseil du jour',
  'delete_account_title': 'Supprimer le compte',
  'delete_confirm_input': 'Saisissez « SUPPRIMER » pour confirmer :',
  'delete_event_confirm': 'Supprimer le rendez-vous ?',
  'delete_event_title': 'Supprimer le rendez-vous ?',
  'delete_final': 'Supprimer définitivement',
  'delete_permanently': 'Supprimer définitivement',
  'delete_person_confirm':
      'La personne sera retirée du calendrier. Les rendez-vous associés seront déplacés vers « Parents ».',
  'delete_profile': 'Supprimer le profil ?',
  'delete_review_confirm': 'Le bilan sera supprimé définitivement.',
  'details': 'Détails',
  'development_consent_accept': 'D\'accord, créer le rapport',
  'development_consent_title': 'Créer le rapport avec l\'IA',
  'development_conversation_prompt': 'Impulsion de conversation',
  'development_practice_today': 'Pratique pour aujourd\'hui',
  'development_questions_remaining':
      'Encore {count} questions à répondre. Réponds à toutes les questions pour obtenir ton rapport IA personnel.',
  'development_report_error': 'Le rapport n\'a pas pu être créé : {error}',
  'development_report_language_instruction':
      'Rédige l\'intégralité du rapport en français.',
  'development_report_limit_reached':
      'Ton rapport gratuit pour cette année a déjà été créé.',
  'development_report_next_free':
      'Prochain rapport gratuit : à partir de janvier {year}.',
  'development_special_needs': 'Mon enfant a des besoins particuliers',
  'development_special_needs_hint':
      'Par exemple un retard de développement, un handicap ou une maladie chronique. Le rapport se base alors sur les progrès propres de l\'enfant plutôt que sur les normes d\'âge.',
  'dinner': 'Dîner',
  'done': 'Terminé',
  'duration_1_min': '1 min',
  'duration_2_min': '2 min',
  'duration_3_min': '3 min',
  'duration_5_min': '5 min',
  'duration_minutes': '{minutes} min',
  'edit_member': 'Modifier le membre',
  'emergencies': 'Urgences',
  'expert_action_listen': 'Écouter',
  'expert_action_watch': 'Regarder',
  'expert_action_more_info': 'En savoir plus',
  'expert_action_read': 'Lire',
  'expert_library_title': 'Bibliothèque d\'experts',
  'expert_library_subtitle': 'Podcasts, vidéos et livres qui aident vraiment.',
  'expert_library_content_english_notice':
      'Les contenus recommandés sont en anglais. L\'interface et les catégories s\'affichent dans ta langue.',
  'expert_library_filter_all': 'Tout',
  'expert_library_empty': 'Pas encore de recommandations pour cette catégorie.',
  'export_data': 'Exporter mes données',
  'fallback_default_reflection':
      'Qu\'est-ce qui a bien fonctionné aujourd\'hui ? Quel moment avec ton enfant veux-tu retenir ?',
  'fallback_evening_reflection': 'Réflexion du soir',
  'fallback_impulse_1_body':
      'Les limites bienveillantes ne sont pas une contradiction. Les enfants ont besoin des deux : se sentir aimés et avoir des repères clairs. Des limites posées avec lien agissent comme des garde-fous, pas comme des murs.',
  'fallback_impulse_1_reflection':
      'Y a-t-il eu aujourd\'hui une situation où une limite posée calmement a mieux fonctionné qu\'un non criant ?',
  'fallback_impulse_1_tip':
      'Aujourd\'hui, nomme d\'abord l\'émotion de ton enfant, puis la limite : « Je vois que tu es en colère. Et malgré tout : taper, ce n\'est pas possible. »',
  'fallback_impulse_1_title': 'Poser des limites avec bienveillance',
  'fallback_impulse_2_body':
      'Les messages en « tu » déclenchent la défense. Les messages en « je » ouvrent des portes. Les enfants écoutent davantage quand ils ne se sentent pas attaqués.',
  'fallback_impulse_2_reflection':
      'Un message en « je » a-t-il provoqué aujourd\'hui une réaction qui t\'a surpris ?',
  'fallback_impulse_2_tip':
      'Choisis aujourd\'hui une situation où tu dirais d\'habitude « Tu fais toujours… » et remplace-la par « Je ressens…, parce que j\'ai besoin de… »',
  'fallback_impulse_2_title': 'Les messages en « je » au quotidien',
  'fallback_impulse_3_body':
      'Si tout est trop aujourd\'hui : choisis simplement un moment calme avec ton enfant et nomme une émotion sans jugement. Ce bref échange renforce le lien et la sécurité.',
  'fallback_impulse_3_reflection':
      'Quel petit moment aujourd\'hui vous a fait du bien à tous les deux ?',
  'fallback_impulse_3_tip':
      'Respirez trois minutes ensemble. Demande ensuite : « Qu\'est-ce qui a été facile pour toi aujourd\'hui ? »',
  'fallback_impulse_3_title': 'De petits pas, un grand effet',
  'fallback_impulse_4_body':
      'Chaque enfant possède une combinaison unique de forces. On remarque souvent d\'abord les difficultés, alors qu\'on peut aussi reconnaître le potentiel qui se cache derrière.',
  'fallback_impulse_4_reflection':
      'Quelle force de ton enfant t\'a surpris ou impressionné aujourd\'hui ?',
  'fallback_impulse_4_tip':
      'Parle aujourd\'hui à ton enfant de l\'une de ses forces, non comme un compliment mais comme une observation : « J\'ai vu aujourd\'hui comment tu… »',
  'fallback_impulse_4_title': 'Voir les forces plutôt que juger les faiblesses',
  'fallback_impulse_5_body':
      'Les enfants deviennent autonomes lorsqu\'on leur fait confiance. L\'art consiste à transmettre peu à peu plus de responsabilité, sans intervenir trop tôt.',
  'fallback_impulse_5_reflection':
      'Quand avez-vous lâché prise aujourd\'hui, et quel effet cela a-t-il eu ?',
  'fallback_impulse_5_tip':
      'Confie aujourd\'hui à ton enfant une tâche que tu faisais toi-même, et laisse-le l\'accomplir entièrement seul.',
  'fallback_impulse_5_title': 'Autonomie : lâcher prise, c\'est aussi aimer',
  'fallback_impulse_6_body':
      'Les enfants qui savent nommer leurs émotions peuvent exprimer ce dont ils ont besoin. Passer du ressenti à la parole demande de l\'entraînement et ton soutien.',
  'fallback_impulse_6_reflection':
      'Quel moment émotionnel de votre enfant aimeriez-vous retenir aujourd\'hui ?',
  'fallback_impulse_6_tip':
      'Demande ce soir : « Qu\'est-ce qui t\'a rendu heureux ? Qu\'est-ce qui t\'a rendu triste ou en colère ? » Puis écoute simplement.',
  'fallback_impulse_6_title': 'Nommer et reconnaître les émotions',
  'fallback_impulse_7_body':
      'Le cerveau apprend particulièrement bien par l\'erreur. Quand ton enfant échoue et que tu restes calme, tu transmets : échouer est sûr. Je peux le supporter.',
  'fallback_impulse_7_reflection':
      'Y a-t-il eu aujourd\'hui un échec que ton enfant a bien surmonté ? Qu\'est-ce qui a aidé ?',
  'fallback_impulse_7_tip':
      'Raconte aujourd\'hui à ton enfant l\'un de tes propres échecs et ce que tu en as appris.',
  'fallback_impulse_7_title': 'Voir l\'échec comme une occasion d\'apprendre',
  'fallback_impulse_headline': 'Impulsion du jour pour ton quotidien',
  'fallback_understood_summary':
      'Les enfants coopèrent mieux lorsqu\'ils se sentent d\'abord vus. Le lien passe avant la correction.',
  'fallback_understood_title': 'Compris en bref',
  'family_action_not_allowed':
      'Cette action n\'est pas autorisée dans ce rôle.',
  'family_delete_account_error':
      'Erreur lors de la suppression du compte : {error}',
  'family_hub_account_changed':
      'Le compte a changé. Veuillez fermer cette vue.',
  'family_hub_age_years': '{count} ans',
  'family_hub_allergies': '⚠ Allergies',
  'family_hub_allergies_csv': 'Allergies (séparées par des virgules)',
  'family_hub_allergies_hint': 'p. ex. noix, lactose',
  'family_hub_blood_type': '🧬 Groupe sanguin',
  'family_hub_blood_type_hint': 'p. ex. A+',
  'family_hub_blood_type_plain': 'Groupe sanguin',
  'family_hub_child_fallback': 'Enfant',
  'family_hub_child_name': 'Nom de l\'enfant',
  'family_hub_child_name_hint': 'p. ex. Mila',
  'family_hub_children_empty_hint':
      'Créez un profil dans le réseau de parents pour utiliser le dossier enfant.',
  'family_hub_clothing_hint': 'p. ex. 110',
  'family_hub_clothing_size': 'Taille de vêtements',
  'family_hub_clothing_size_short': '👕 Taille',
  'family_hub_daycare_group': 'Groupe / classe',
  'family_hub_daycare_group_hint': 'p. ex. groupe Coccinelles',
  'family_hub_daycare_hint': 'p. ex. crèche Soleil',
  'family_hub_daycare_school': 'Crèche / école',
  'family_hub_daycare_teacher': 'Éducateur·rice / enseignant·e',
  'family_hub_daycare_teacher_hint': 'p. ex. Mme Yılmaz',
  'family_hub_doctor_phone': '📞 Tél. médecin',
  'family_hub_edit_child': 'Modifier {name}',
  'family_hub_emergency_contact': '📱 Contact d\'urgence',
  'family_hub_emergency_contact_hint': 'p. ex. Mamie Helga',
  'family_hub_emergency_contact_name': 'Contact d\'urgence (nom)',
  'family_hub_emergency_phone': '📞 Tél. d\'urgence',
  'family_hub_emergency_phone_hint': '0170…',
  'family_hub_emergency_phone_plain': 'Téléphone d\'urgence',
  'family_hub_exam_due': 'À faire : {exam}',
  'family_hub_legacy_claim': 'Appartient à mon compte – reprendre',
  'family_hub_legacy_confirm':
      'Je confirme que les dossiers enfant stockés jusqu\'ici sur l\'appareil (y compris données de santé et d\'urgence), listes de courses, tâches et allergies de cuisine appartiennent à mon compte actuellement connecté. Ils seront associés uniquement en local à ce compte. Les données de compte existantes sont conservées ; rien n\'est publié.',
  'family_hub_legacy_failed':
      'Impossible de reprendre l\'ancien contenu en toute sécurité. Les données existantes sont conservées.',
  'family_hub_legacy_notice':
      'Un ancien contenu non associé se trouve sur cet appareil. Il n\'est pas utilisé automatiquement. Connectez-vous pour le reprendre après confirmation.',
  'family_hub_legacy_title': 'Reprendre les données locales',
  'family_hub_load_error':
      'Le centre familial n\'a pas pu être entièrement chargé.',
  'family_hub_none_known': 'Aucune connue',
  'family_hub_not_entered': 'Non renseigné',
  'family_hub_notes': 'Notes',
  'family_hub_notes_hint': 'p. ex. particularités, préférences',
  'family_hub_pediatrician': '🏥 Pédiatre',
  'family_hub_pediatrician_hint': 'p. ex. Dr Müller',
  'family_hub_pediatrician_name': 'Nom du pédiatre',
  'family_hub_pediatrician_phone': 'Téléphone du pédiatre',
  'family_hub_phone_hint': '030 123456',
  'family_hub_retry': 'Réessayer',
  'family_hub_save_error':
      'Impossible d\'enregistrer la modification. Veuillez réessayer.',
  'family_hub_shoe_hint': 'p. ex. 28',
  'family_hub_shoe_size': 'Pointure',
  'family_hub_shoe_size_short': '👟 Pointure',
  'family_hub_shopping_hint': 'p. ex. « 3x lait » ou « pâtes 500 g »',
  'family_hub_shopping_list': 'Liste de courses',
  'family_hub_tab_children': 'Enfants',
  'family_hub_tab_shopping': 'Courses',
  'family_hub_tab_todo': 'À faire',
  'family_hub_todo_hint': 'Nouvelle tâche…',
  'family_hub_uexam_done_on': 'Effectué le {date}',
  'family_hub_uexams_open': '{count} encore à faire',
  'family_hub_uexams_title': 'Examens de santé (U)',
  'family_import_invalid': 'Échec de l\'import. JSON non valide.',
  'family_min_member': 'Au moins un membre doit rester.',
  'family_name_desc':
      'Votre prénom ou nom de famille, pour pouvoir vous accueillir personnellement.',
  'family_name_exists': 'Ce nom existe déjà.',
  'family_name_hint': 'p. ex. Famille Müller ou Anna',
  'family_ok': 'OK',
  'family_recipe_delete_confirm':
      'Voulez-vous vraiment supprimer « {title} » ?',
  'family_recipe_delete_title': 'Supprimer la recette ?',
  'family_recipe_deleted': 'Recette supprimée.',
  'family_recipe_description_hint': 'Pourquoi vos enfants l\'aiment ?',
  'family_recipe_description_label': 'Courte description',
  'family_recipe_ingredients_hint': '500 g de pommes de terre\n1 oignon\n…',
  'family_recipe_ingredients_label': 'Ingrédients (un par ligne)',
  'family_recipe_minutes_hint': 'p. ex. 25',
  'family_recipe_minutes_label': 'Temps de préparation en minutes',
  'family_recipe_name_hint': 'p. ex. salade de pommes de terre de mamie',
  'family_recipe_name_label': 'Nom du plat',
  'family_recipe_name_required': 'Donnez un nom à votre recette.',
  'family_recipe_photo_optional': 'Ajouter une photo (facultatif)',
  'family_recipe_photo_pick_failed': 'Impossible de choisir la photo.',
  'family_recipe_save_failed':
      'Impossible d\'enregistrer, réessayez plus tard.',
  'family_recipe_share_action': 'Partager',
  'family_recipe_share_success': 'Recette partagée. Merci du partage ! 🍳',
  'family_recipe_share_title': 'Partager la recette',
  'family_recipe_steps_hint':
      'Cuire les pommes de terre.\nÉmincer l\'oignon.\n…',
  'family_recipe_steps_label': 'Préparation (une étape par ligne)',
  'family_recipe_visibility_friends': 'Seulement mes amis',
  'family_recipe_visibility_friends_hint':
      'Recommandé – seules les familles connectées la voient.',
  'family_recipe_visibility_private': 'Seulement pour moi',
  'family_recipe_visibility_private_hint':
      'Reste privée – vous seul·e la voyez.',
  'family_recipe_visibility_public': 'Pour toutes les familles',
  'family_recipe_visibility_public_hint':
      'Toutes les familles Parentpeak peuvent la découvrir.',
  'family_recipe_visibility_title': 'Qui peut voir votre recette ?',
  'family_scan_qr': 'Scanner le QR',
  'feedback_thanks': '❤️ Merci pour votre retour !',
  'fill_again': 'Remplir à nouveau',
  'filter_all': 'Tous',
  'filter_family_circle': 'Cercle familial',
  'filter_invited': 'Invités',
  'filter_public': 'Public',
  'filter_search': 'Filtrer la recherche',
  'filter_title': 'Filtres',
  'finance_add_care': 'Ajouter une activité de care',
  'finance_add_manual': 'Poste manuel',
  'finance_add_position_manual': 'Ajouter un poste manuellement',
  'finance_add_saving': 'Ajouter une occasion d\'économie',
  'finance_amount_per_month': '~{amount}/mois',
  'finance_amount_per_year': '{amount}/an',
  'finance_amounts_disclaimer':
      'Les montants et liens ne servent que d\'orientation, sans garantie. Seules certaines informations ont été vérifiées auprès de sources officielles ; l\'actualité n\'est pas garantie pour tous les détails. Le service compétent calcule le montant exact.',
  'finance_application_bildungTeilhabe_aiTemplatePrompt_5':
      'Rédige une courte demande informelle de prestations Éducation et Participation. Un enfant doit participer à un cours de sport. La famille perçoit le supplément pour enfant. Factuel, 3 à 4 phrases.',
  'finance_application_bildungTeilhabe_benefitName_0':
      'Éducation et Participation (BuT)',
  'finance_application_bildungTeilhabe_description_14':
      'Le BuT comprend : fournitures scolaires (195 €/an), repas de midi, sorties, soutien scolaire, sport/culture (15 €/mois), transport scolaire.',
  'finance_application_bildungTeilhabe_description_16':
      'Récupère le formulaire BuT au Jobcenter ou au service social (ou fais une demande libre par courrier). Certaines villes ont des formulaires en ligne.',
  'finance_application_bildungTeilhabe_description_18':
      'Joins la décision de prestations + le certificat de scolarité + le cas échéant la facture du club.',
  'finance_application_bildungTeilhabe_description_20':
      'Tu reçois soit un bon (p. ex. pour le club), soit l\'argent est versé directement au prestataire.',
  'finance_application_bildungTeilhabe_name_10':
      'Justificatif des frais (p. ex. cotisation de club)',
  'finance_application_bildungTeilhabe_name_6':
      'Justificatif de perception de prestations',
  'finance_application_bildungTeilhabe_name_8': 'Certificat de scolarité',
  'finance_application_bildungTeilhabe_proTip_4':
      'Le BuT couvre aussi les cours de natation, l\'école de musique et le soutien scolaire — pas seulement les fournitures ! Jusqu\'à 15 €/mois pour le sport/la culture/les loisirs.',
  'finance_application_bildungTeilhabe_processingTime_2': '2 à 6 semaines',
  'finance_application_bildungTeilhabe_renewalNote_3':
      'À redemander chaque année scolaire (fournitures scolaires). Frais de club/cours : tous les 6 mois.',
  'finance_application_bildungTeilhabe_responsibleAuthority_1':
      'Jobcenter ou service social de ta ville/commune',
  'finance_application_bildungTeilhabe_title_13':
      'Vérifier ce qui est possible',
  'finance_application_bildungTeilhabe_title_15':
      'Demande informelle ou formulaire',
  'finance_application_bildungTeilhabe_title_17': 'Joindre les justificatifs',
  'finance_application_bildungTeilhabe_title_19': 'Bon ou paiement direct',
  'finance_application_bildungTeilhabe_whereToGet_11':
      'Formulaire d\'inscription ou facture du club/cours',
  'finance_application_bildungTeilhabe_whereToGet_7':
      'Décision de supplément pour enfant, d\'allocation logement, de Bürgergeld ou d\'aide sociale',
  'finance_application_bildungTeilhabe_whereToGet_9':
      'Secrétariat de l\'école de ton enfant',
  'finance_application_eingliederungshilfe_aiTemplatePrompt_5':
      'Rédige une courte demande informelle d\'aide à l\'intégration pour un enfant. L\'enfant a un handicap et a besoin d\'un soutien à la participation (p. ex. accompagnement scolaire, intervention précoce). Factuel, 3 à 4 phrases.',
  'finance_application_eingliederungshilfe_benefitName_0':
      'Aide à l\'intégration',
  'finance_application_eingliederungshilfe_description_15':
      'Handicap psychique (autisme, TDAH, anxiété) → service de la jeunesse. Handicap physique/mental → service social. En cas de doute : demander au service de la jeunesse.',
  'finance_application_eingliederungshilfe_description_17':
      'Un courrier suffit : « Je demande une aide à l\'intégration pour mon enfant [Nom] en raison de [Diagnostic]. » Joins-y l\'avis médical.',
  'finance_application_eingliederungshilfe_description_19':
      'Le service t\'invite à un entretien. On y discute de l\'aide dont ton enfant a besoin (intervention précoce, accompagnement scolaire, thérapie, etc.).',
  'finance_application_eingliederungshilfe_description_21':
      'Après l\'approbation, l\'aide commence. En cas de refus : faire un recours (dans un délai de 4 semaines, gratuit).',
  'finance_application_eingliederungshilfe_name_10':
      'Rapport de développement (crèche/école)',
  'finance_application_eingliederungshilfe_name_12':
      'Avis de l\'école (pour l\'accompagnement scolaire)',
  'finance_application_eingliederungshilfe_name_6': 'Avis médical / diagnostic',
  'finance_application_eingliederungshilfe_name_8':
      'Demande informelle d\'aide à l\'intégration',
  'finance_application_eingliederungshilfe_proTip_4':
      'Pour un handicap psychique (p. ex. autisme, TDAH), c\'est le service de la jeunesse qui est compétent (§35a SGB VIII). Pour un handicap physique/mental, le service social.',
  'finance_application_eingliederungshilfe_processingTime_2': '4 à 12 semaines',
  'finance_application_eingliederungshilfe_renewalNote_3':
      'Accordée pour une période déterminée. Dépose la demande de renouvellement à temps.',
  'finance_application_eingliederungshilfe_responsibleAuthority_1':
      'Service social ou service de la jeunesse (selon le type de handicap)',
  'finance_application_eingliederungshilfe_title_14': 'Clarifier la compétence',
  'finance_application_eingliederungshilfe_title_16':
      'Déposer une demande informelle',
  'finance_application_eingliederungshilfe_title_18':
      'Entretien sur le plan d\'aide',
  'finance_application_eingliederungshilfe_title_20':
      'Approbation + début de l\'aide',
  'finance_application_eingliederungshilfe_whereToGet_11':
      'Un bref rapport rédigé par l\'éducateur ou l\'enseignant',
  'finance_application_eingliederungshilfe_whereToGet_13':
      'Direction de l\'école ou enseignant référent',
  'finance_application_eingliederungshilfe_whereToGet_7':
      'Pédiatre, SPZ (centre de pédiatrie sociale) ou spécialiste',
  'finance_application_eingliederungshilfe_whereToGet_9':
      'Un courrier personnel au service social/service de la jeunesse',
  'finance_application_elterngeld_aiTemplatePrompt_5':
      'Rédige une courte lettre d\'accompagnement pour une demande d\'allocation parentale. Un parent demande l\'allocation parentale de base après la naissance du premier enfant et prévoit de répartir les mois avec son partenaire. Factuel et clair.',
  'finance_application_elterngeld_benefitName_0':
      'Allocation parentale (Elterngeld)',
  'finance_application_elterngeld_description_18':
      'Avec le calculateur officiel, estime le montant de l\'allocation parentale et la meilleure répartition (Basis/Plus/bonus de partenariat).',
  'finance_application_elterngeld_description_20':
      'Chaque Land a son propre formulaire. Le plus simple est de passer par ElterngeldDigital (disponible dans de nombreux Länder).',
  'finance_application_elterngeld_description_22':
      'Copie l\'acte de naissance, les justificatifs de revenus, l\'attestation d\'indemnité de maternité et les pièces d\'identité.',
  'finance_application_elterngeld_description_24':
      'Soumets par courrier ou en ligne. Le délai de traitement varie beaucoup (4 à 12 semaines). Conseil : relance après 6 semaines si rien n\'arrive.',
  'finance_application_elterngeld_name_10':
      'Attestation de l\'employeur sur le complément à l\'indemnité de maternité',
  'finance_application_elterngeld_name_12':
      'Justificatifs de revenus des 12 mois précédant la naissance',
  'finance_application_elterngeld_name_14':
      'Cartes d\'identité des deux parents (copies)',
  'finance_application_elterngeld_name_15':
      'Confirmation du temps de travail prévu (pour Elterngeld Plus)',
  'finance_application_elterngeld_name_6':
      'Acte de naissance de l\'enfant (original ou copie certifiée)',
  'finance_application_elterngeld_name_8':
      'Attestation de l\'assurance maladie concernant l\'indemnité de maternité',
  'finance_application_elterngeld_proTip_4':
      'Tu peux préparer la demande AVANT la naissance — seul l\'acte de naissance manquera alors. Fait gagner des semaines !',
  'finance_application_elterngeld_processingTime_2':
      '4 à 12 semaines (selon le Land)',
  'finance_application_elterngeld_renewalNote_3':
      'Pas de nouvelle demande. Attribution unique pour 12 à 14 mois (Basis) ou 24 à 28 mois (Plus).',
  'finance_application_elterngeld_responsibleAuthority_1':
      'Service d\'allocation parentale de ton Land',
  'finance_application_elterngeld_title_17':
      'Utiliser le calculateur d\'allocation parentale',
  'finance_application_elterngeld_title_19':
      'Remplir la demande (en ligne ou papier)',
  'finance_application_elterngeld_title_21': 'Rassembler les documents',
  'finance_application_elterngeld_title_23': 'Soumettre + patience',
  'finance_application_elterngeld_whereToGet_11':
      'Service des ressources humaines de ton employeur',
  'finance_application_elterngeld_whereToGet_13':
      'Fiches de paie ou avis d\'imposition',
  'finance_application_elterngeld_whereToGet_16':
      'Employeur (si tu travailles à temps partiel)',
  'finance_application_elterngeld_whereToGet_7': 'Service d\'état civil',
  'finance_application_elterngeld_whereToGet_9':
      'Ton assurance maladie (à demander après la naissance)',
  'finance_application_kindergeld_aiTemplatePrompt_5':
      'Rédige une courte lettre d\'accompagnement, aimable, pour une demande d\'allocations familiales. Un parent demande pour la première fois les allocations après la naissance. Reste simple et factuel.',
  'finance_application_kindergeld_benefitName_0':
      'Allocations familiales (Kindergeld)',
  'finance_application_kindergeld_description_15':
      'Remplis le formulaire « KG1 » en ligne sur le site de la caisse des allocations familiales. Env. 10 minutes.',
  'finance_application_kindergeld_description_17':
      'Téléverse les scans de l\'acte de naissance et des numéros fiscaux, ou envoie-les par courrier à ta caisse des allocations familiales.',
  'finance_application_kindergeld_description_19':
      'Tu reçois une décision par courrier (4 à 6 semaines). Le premier versement arrive ensuite chaque mois.',
  'finance_application_kindergeld_name_10': 'Numéro fiscal du parent demandeur',
  'finance_application_kindergeld_name_12':
      'Carte d\'identité ou passeport (copie)',
  'finance_application_kindergeld_name_13': 'Coordonnées bancaires (IBAN)',
  'finance_application_kindergeld_name_6': 'Acte de naissance de l\'enfant',
  'finance_application_kindergeld_name_8': 'Numéro fiscal de l\'enfant',
  'finance_application_kindergeld_proTip_4':
      'Dépose la demande juste après la naissance — les allocations sont versées rétroactivement pour 6 mois maximum.',
  'finance_application_kindergeld_processingTime_2': '4 à 6 semaines',
  'finance_application_kindergeld_renewalNote_3':
      'Aucune nouvelle demande nécessaire. Versé automatiquement jusqu\'au 18e (ou 25e) anniversaire.',
  'finance_application_kindergeld_responsibleAuthority_1':
      'Caisse des allocations familiales de l\'Agence fédérale pour l\'emploi',
  'finance_application_kindergeld_title_14': 'Remplir la demande en ligne',
  'finance_application_kindergeld_title_16':
      'Téléverser les documents ou envoyer par courrier',
  'finance_application_kindergeld_title_18': 'Attendre la confirmation',
  'finance_application_kindergeld_whereToGet_11':
      'Figure sur ton avis d\'imposition ou ta fiche de paie',
  'finance_application_kindergeld_whereToGet_7':
      'Service d\'état civil (souvent remis à la maternité)',
  'finance_application_kindergeld_whereToGet_9':
      'Envoyé par courrier par l\'Office fédéral central des impôts (env. 2 à 3 semaines après la naissance)',
  'finance_application_kinderzuschlag_aiTemplatePrompt_5':
      'Rédige une courte justification factuelle pour une demande de supplément pour enfant. La famille a de faibles revenus et a besoin de soutien pour les enfants. Mentionne que le loyer représente une grande part du revenu.',
  'finance_application_kinderzuschlag_benefitName_0':
      'Supplément pour enfant (KiZ)',
  'finance_application_kinderzuschlag_description_17':
      'Vérifie avec le guide en ligne si tu as probablement droit à l\'aide. Cela t\'évite de perdre du temps.',
  'finance_application_kinderzuschlag_description_19':
      'Remplis la demande sur le site de la caisse des allocations familiales. Garde à portée de main les justificatifs de revenus et les frais de loyer.',
  'finance_application_kinderzuschlag_description_21':
      'Téléverse les fiches de paie, le contrat de location et les relevés bancaires, ou envoie-les par courrier.',
  'finance_application_kinderzuschlag_description_23':
      'La décision arrive après 4 à 8 semaines. Important : n\'oublie pas la demande de prolongation après 6 mois !',
  'finance_application_kinderzuschlag_name_10':
      'Relevés bancaires des 3 derniers mois',
  'finance_application_kinderzuschlag_name_12':
      'Décision d\'allocations familiales',
  'finance_application_kinderzuschlag_name_14':
      'Acte(s) de naissance des enfants',
  'finance_application_kinderzuschlag_name_15': 'Carte d\'identité (copie)',
  'finance_application_kinderzuschlag_name_6':
      'Justificatifs de revenus des 6 derniers mois',
  'finance_application_kinderzuschlag_name_8':
      'Contrat de location ou justificatif des frais de logement',
  'finance_application_kinderzuschlag_proTip_4':
      'Avec le guide KiZ de la caisse des allocations familiales, tu peux vérifier ton droit en 2 minutes — avant de remplir la demande complète.',
  'finance_application_kinderzuschlag_processingTime_2': '4 à 8 semaines',
  'finance_application_kinderzuschlag_renewalNote_3':
      'À redemander tous les 6 mois (demande de prolongation).',
  'finance_application_kinderzuschlag_title_16':
      'Utiliser le guide KiZ (2 min.)',
  'finance_application_kinderzuschlag_title_20': 'Soumettre les documents',
  'finance_application_kinderzuschlag_title_22': 'Décision + prolongation',
  'finance_application_kinderzuschlag_whereToGet_11':
      'Banque en ligne → imprimer le PDF',
  'finance_application_kinderzuschlag_whereToGet_13':
      'Reçue par courrier de la caisse des allocations familiales',
  'finance_application_kinderzuschlag_whereToGet_7':
      'Fiches de paie de l\'employeur, décision d\'allocation parentale ou avis d\'imposition',
  'finance_application_kinderzuschlag_whereToGet_9':
      'Copie de ton contrat de location + dernier décompte des charges',
  'finance_application_pflegegeld_aiTemplatePrompt_5':
      'Rédige une courte demande informelle de prestations de dépendance pour un enfant. L\'enfant a un handicap/une maladie chronique et a besoin d\'un soutien quotidien. Factuel, 3 à 4 phrases.',
  'finance_application_pflegegeld_benefitName_0':
      'Allocation de dépendance (Pflegegeld)',
  'finance_application_pflegegeld_description_13':
      'Un appel suffit comme demande ! Dis : « Je souhaite demander des prestations de dépendance pour mon enfant. » La date de l\'appel compte.',
  'finance_application_pflegegeld_description_15':
      'Note chaque jour l\'aide dont ton enfant a besoin : toilette, habillage, repas, nuit, surveillance. Plus c\'est précis, mieux c\'est pour l\'évaluation.',
  'finance_application_pflegegeld_description_17':
      'Le Service médical se rend chez vous. Montre ouvertement les besoins de ton enfant — pas seulement un « bon jour » !',
  'finance_application_pflegegeld_description_19':
      'En principe, la décision intervient dans un délai de 25 jours ouvrés (§18c SGB XI ; exceptions possibles). Pour le recours, le délai est en principe d\'un mois à compter de la notification, de trois mois en cas de notification à l\'étranger (§84 SGG). Vérifie l\'indication des voies de recours.',
  'finance_application_pflegegeld_name_10':
      'Journal de soins (2 semaines avant l\'évaluation)',
  'finance_application_pflegegeld_name_6':
      'Demande informelle (par téléphone ou courrier)',
  'finance_application_pflegegeld_name_8': 'Documents médicaux / diagnostics',
  'finance_application_pflegegeld_proTip_4':
      'Fais la demande de façon informelle par téléphone — un appel à la caisse de dépendance suffit ! La date compte pour le versement rétroactif.',
  'finance_application_pflegegeld_processingTime_2':
      'En principe 25 jours ouvrés ; vérifier les exceptions légales (§18c SGB XI).',
  'finance_application_pflegegeld_renewalNote_3':
      'Pas de nouvelle demande. En cas d\'aggravation : demander un degré supérieur.',
  'finance_application_pflegegeld_responsibleAuthority_1':
      'Caisse de dépendance (auprès de ton assurance maladie)',
  'finance_application_pflegegeld_title_12': 'Appeler la caisse de dépendance',
  'finance_application_pflegegeld_title_14':
      'Tenir un journal de soins (2 semaines)',
  'finance_application_pflegegeld_title_16':
      'Évaluation du Service médical (visite à domicile)',
  'finance_application_pflegegeld_title_18': 'Décision + recours éventuel',
  'finance_application_pflegegeld_whereToGet_11':
      'Modèle fourni par la caisse de dépendance ou en ligne',
  'finance_application_pflegegeld_whereToGet_7':
      'Un appel à ton assurance maladie/caisse de dépendance suffit',
  'finance_application_pflegegeld_whereToGet_9':
      'Pédiatre, spécialiste ou hôpital',
  'finance_application_unterhaltsvorschuss_aiTemplatePrompt_5':
      'Rédige une courte demande factuelle d\'avance sur pension alimentaire. Un parent isolé ne reçoit aucune pension de l\'autre parent. Reste factuel et clair, 3 à 4 phrases.',
  'finance_application_unterhaltsvorschuss_benefitName_0':
      'Avance sur pension alimentaire',
  'finance_application_unterhaltsvorschuss_description_16':
      'Appelle ton service de la jeunesse ou rends-toi sur place. Ils t\'aident directement à remplir le formulaire.',
  'finance_application_unterhaltsvorschuss_description_18':
      'Tu obtiens le formulaire au service de la jeunesse. Certaines villes le proposent aussi en ligne en PDF.',
  'finance_application_unterhaltsvorschuss_description_20':
      'Joins l\'acte de naissance, l\'attestation de domicile et le justificatif de l\'absence de pension.',
  'finance_application_unterhaltsvorschuss_description_22':
      'La décision arrive après 4 à 8 semaines. Le versement est mensuel et rétroactif à partir de la date de demande.',
  'finance_application_unterhaltsvorschuss_name_11':
      'Justificatif de l\'absence de pension alimentaire',
  'finance_application_unterhaltsvorschuss_name_13':
      'Reconnaissance de paternité ou acte de naissance mentionnant le père',
  'finance_application_unterhaltsvorschuss_name_9':
      'Attestation de domicile (logement seul)',
  'finance_application_unterhaltsvorschuss_proTip_4':
      'Tu peux aussi demander l\'avance rétroactivement pour 1 mois. Alors n\'attends pas — dépose la demande tout de suite !',
  'finance_application_unterhaltsvorschuss_renewalNote_3':
      'Aucune nouvelle demande nécessaire. Versé automatiquement jusqu\'à 18 ans (tant que les conditions sont remplies).',
  'finance_application_unterhaltsvorschuss_responsibleAuthority_1':
      'Service de la jeunesse (Jugendamt) de ta ville/commune',
  'finance_application_unterhaltsvorschuss_title_15':
      'Contacter le service de la jeunesse',
  'finance_application_unterhaltsvorschuss_title_17': 'Remplir la demande',
  'finance_application_unterhaltsvorschuss_title_21': 'Attendre la décision',
  'finance_application_unterhaltsvorschuss_whereToGet_10':
      'Bureau des citoyens — montre que tu vis seul(e) avec l\'enfant',
  'finance_application_unterhaltsvorschuss_whereToGet_12':
      'p. ex. courrier à l\'ex resté sans réponse, titre de pension alimentaire, ou déclaration personnelle',
  'finance_application_unterhaltsvorschuss_whereToGet_14':
      'Service d\'état civil ou service de la jeunesse',
  'finance_application_wohngeld_aiTemplatePrompt_5':
      'Rédige une courte lettre d\'accompagnement pour une demande d\'allocation logement. Une famille avec enfants demande l\'allocation pour la première fois car le loyer représente une grande part du revenu. Factuel et aimable.',
  'finance_application_wohngeld_benefitName_0':
      'Allocation logement (Wohngeld)',
  'finance_application_wohngeld_description_16':
      'Avec le calculateur officiel Wohngeld-Plus du BMWSB, vérifie si et combien d\'allocation logement te revient.',
  'finance_application_wohngeld_description_18':
      'Tu obtiens le formulaire à la mairie/au bureau des citoyens ou en ligne en PDF. Certaines communes proposent aussi des demandes en ligne.',
  'finance_application_wohngeld_description_20':
      'Joins le contrat de location, les justificatifs de revenus et le décompte des charges. En cas de doute, envoie plutôt trop que pas assez.',
  'finance_application_wohngeld_description_22':
      'La décision arrive après 3 à 8 semaines. Programme un rappel pour la demande de prolongation (10 mois après l\'attribution).',
  'finance_application_wohngeld_name_10': 'Décompte des charges',
  'finance_application_wohngeld_name_12':
      'Cartes d\'identité de tous les membres du ménage (copies)',
  'finance_application_wohngeld_name_13': 'Attestation de domicile',
  'finance_application_wohngeld_name_6':
      'Justificatifs de revenus de tous les membres du ménage',
  'finance_application_wohngeld_name_8': 'Contrat de location (copie)',
  'finance_application_wohngeld_name_9':
      'Dernière quittance de loyer ou relevé bancaire montrant le paiement du loyer',
  'finance_application_wohngeld_proTip_4':
      'Depuis la réforme de l\'allocation logement de 2023, bien plus de familles y ont droit — même avec un revenu moyen. À vérifier !',
  'finance_application_wohngeld_processingTime_2':
      '3 à 8 semaines (selon la commune)',
  'finance_application_wohngeld_renewalNote_3':
      'Période d\'attribution : 12 mois. Dépose la demande de prolongation à temps (2 mois avant).',
  'finance_application_wohngeld_responsibleAuthority_1':
      'Service d\'allocation logement de ta ville/commune',
  'finance_application_wohngeld_title_15':
      'Utiliser le calculateur d\'allocation logement',
  'finance_application_wohngeld_title_17':
      'Faire la demande auprès de ton service d\'allocation logement',
  'finance_application_wohngeld_title_19': 'Joindre les documents',
  'finance_application_wohngeld_title_21':
      'Attendre la décision + programmer un rappel',
  'finance_application_wohngeld_whereToGet_11':
      'Du propriétaire (chaque année)',
  'finance_application_wohngeld_whereToGet_14':
      'Bureau des citoyens / service des déclarations de résidence',
  'finance_application_wohngeld_whereToGet_7':
      'Fiches de paie, décision de retraite, décision d\'allocation parentale',
  'finance_apply_positions': 'Appliquer les postes',
  'finance_average_amount': 'Moyenne : ~{amount}',
  'finance_based_on_children_age': 'En fonction de l\'âge de vos enfants :',
  'finance_benefit_de_but':
      'Éducation et Participation (BuT)|Fournitures scolaires, sorties, soutien scolaire, repas de midi, club de sport.|prestations en nature + 195 €/an pour les fournitures|Familles percevant le KiZ, l\'allocation logement ou le Bürgergeld.',
  'finance_benefit_de_eingliederungshilfe':
      'Aide à l\'intégration|Soutien aux enfants handicapés : thérapie, accompagnement scolaire, intervention précoce.|Individuel (prestations en nature)|Enfants présentant un handicap avéré ou menaçant.',
  'finance_benefit_de_elterngeld':
      'Allocation parentale (Elterngeld)|Compensation de revenu après la naissance ; les versions Basis et Plus ont des durées différentes.|Basis : 300 €–1 800 €/mois ; Plus : 150 €–900 €/mois (hors suppléments)|Ménage commun, garde personnelle de l\'enfant et pas d\'activité à temps plein ; vérifier les autres conditions et exceptions.',
  'finance_benefit_de_kindergeld':
      'Allocations familiales (Kindergeld)|Versement mensuel pour les enfants ; des conditions supplémentaires s\'appliquent aux majeurs.|259 €/enfant|En principe pour les mineurs ; vérifier la prise en charge, le ménage, le domicile et les cas particuliers.',
  'finance_benefit_de_kinderzuschlag':
      'Supplément pour enfant (KiZ)|Aide supplémentaire pour les familles à faibles revenus.|jusqu\'à 297 €/enfant/mois|Enfant de moins de 25 ans dans le ménage, perception des allocations familiales ; revenus, patrimoine et besoins familiaux à évaluer individuellement.',
  'finance_benefit_de_pflegegeld':
      'Allocation de dépendance (Pflegegeld)|Pour les enfants en situation de handicap ou atteints de maladie chronique nécessitant des soins.|347 / 599 / 800 / 990 €/mois (degré de dépendance 2 / 3 / 4 / 5)|Degré de dépendance 2 à 5 ; les soins à domicile doivent être assurés de manière appropriée.',
  'finance_benefit_de_unterhaltsvorschuss':
      'Avance sur pension alimentaire|Lorsque l\'autre parent ne verse aucune pension, ou de façon irrégulière ou insuffisante.|227 / 299 / 394 €/mois (0–5 / 6–11 / 12–17 ans)|L\'enfant vit chez un parent isolé ; des conditions supplémentaires s\'appliquent de 12 à 17 ans.',
  'finance_benefit_de_wohngeld':
      'Allocation logement (Wohngeld)|Aide au loyer pour les familles à faibles revenus.|calculé individuellement|Dépend de la taille du ménage, du loyer ou des charges pris en compte et du revenu total.',
  'finance_benefits_country_intro':
      'Ces aides pourraient être pertinentes pour vous en {country}.',
  'finance_benefits_filtered':
      'Informations enregistrées. Toutes les aides restent visibles ; le revenu et l\'activité professionnelle ne constituent pas une évaluation des droits.',
  'finance_camera': 'Appareil photo',
  'finance_care_activities': 'Activités de care',
  'finance_care_removed': 'Activité de care supprimée.',
  'finance_care_saved': 'Activité de care enregistrée.',
  'finance_care_updated': 'Activité de care mise à jour.',
  'finance_category_essen': 'Alimentation',
  'finance_category_freizeit': 'Loisirs et cours',
  'finance_category_gesundheit': 'Santé',
  'finance_category_kita': 'Crèche / garde',
  'finance_category_kleidung': 'Vêtements',
  'finance_category_mobilität': 'Mobilité',
  'finance_category_sonstiges': 'Divers',
  'finance_category_wohnen': 'Logement (part de l\'enfant)',
  'finance_close': 'Fermer',
  'finance_content_austria_amount_10':
      'Modèle au compte : 17,65–41,14 €/jour ; lié au revenu : 80 % des derniers revenus, max. 80,12 €/jour',
  'finance_content_austria_amount_3':
      '138,40 / 148 / 171,80 / 200,40 €/mois (à partir de 0 / 3 / 10 / 19 ans ; hors suppléments)',
  'finance_content_austria_amount_6': '70,90 €/enfant/mois',
  'finance_content_austria_description_2':
      'Soutien mensuel par enfant, échelonné selon l\'âge.',
  'finance_content_austria_description_5': 'Crédit d\'impôt par enfant.',
  'finance_content_austria_description_9':
      'Après la naissance, selon différents modèles.',
  'finance_content_austria_eligibility_7':
      'Versé avec l\'allocation familiale ; aucune demande distincte.',
  'finance_content_austria_name_1': 'Allocation familiale (Familienbeihilfe)',
  'finance_content_austria_name_4':
      'Crédit d\'impôt pour enfant (Kinderabsetzbetrag)',
  'finance_content_austria_name_8':
      'Allocation de garde d\'enfant (Kinderbetreuungsgeld)',
  'finance_content_generic_description_2':
      'La plupart des pays versent des prestations familiales mensuelles. Vérifie auprès de ton administration locale.',
  'finance_content_generic_description_4':
      'De nombreux pays proposent des aides au loyer pour les familles.',
  'finance_content_generic_description_6':
      'Vérifie si ton pays subventionne la garde d\'enfants.',
  'finance_content_generic_name_1': 'Allocations familiales / Child Benefit',
  'finance_content_generic_name_3': 'Aide au logement',
  'finance_content_generic_name_5': 'Aide à la garde d\'enfants',
  'finance_content_switzerland_amount_3':
      'au moins 215 Fr./enfant/mois ; éventuellement plus selon le canton',
  'finance_content_switzerland_amount_6':
      'au moins 268 Fr./enfant/mois ; éventuellement plus selon le canton',
  'finance_content_switzerland_description_2':
      'Variable selon le canton, par enfant.',
  'finance_content_switzerland_description_5':
      'Formation post-obligatoire, au plus tôt dès 15 ans et au plus tard jusqu\'à 25 ans ; vérifier les limites mensuelles exactes.',
  'finance_content_switzerland_name_1': 'Allocation pour enfant (Kinderzulage)',
  'finance_content_switzerland_name_4':
      'Allocation de formation (Ausbildungszulage)',
  'finance_content_turkey_amount_3':
      '1er enfant : 5 000 ₺ une fois ; 2e : 1 500 ₺/mois ; 3e et + : 5 000 ₺/mois',
  'finance_content_turkey_amount_7': 'soumis au revenu',
  'finance_content_turkey_description_2':
      'Nouveau programme d\'aide à la naissance pour les naissances à partir du 01.01.2025 ; versements réguliers de la demande jusqu\'au 60e mois inclus.',
  'finance_content_turkey_description_6':
      'Allocation familiale mensuelle pour les familles.',
  'finance_content_turkey_description_9':
      'Soutien social et économique via l\'İl Müdürlüğü/Sosyal Hizmet Merkezi.',
  'finance_content_turkey_eligibility_10':
      'Évaluation sociale individuelle de la situation familiale, économique et régionale.',
  'finance_content_turkey_eligibility_4':
      'Nationalité turque et résidence en Türkiye ; vérifier les autres conditions officielles de demande.',
  'finance_content_turkey_name_1': 'Dogum Yardimi',
  'finance_content_turkey_name_5': 'Cocuk Parasi',
  'finance_content_turkey_name_8': 'Aide sociale et économique (SED)',
  'finance_content_uk_amount_3':
      '27,05 £/semaine (aîné ou enfant unique), 17,90 £/semaine (enfants suivants)',
  'finance_content_uk_amount_6':
      '303,94 £/mois par enfant ; en plus 47,94 £ pour le premier enfant né avant le 6 avril 2017',
  'finance_content_uk_amount_9':
      'jusqu\'à 500 £/3 mois (2 000 £/an) ; enfant handicapé : 1 000 £/3 mois (4 000 £/an)',
  'finance_content_uk_description_2':
      'Versement hebdomadaire pour chaque enfant.',
  'finance_content_uk_description_5':
      'Soutien supplémentaire pour les familles à faibles revenus.',
  'finance_content_uk_description_8':
      'L\'État ajoute 2 £ pour chaque 8 £ versés sur le compte de garde.',
  'finance_content_uk_name_1': 'Child Benefit',
  'finance_content_uk_name_4': 'Universal Credit (Child Element)',
  'finance_content_uk_name_7': 'Tax-Free Childcare',
  'finance_content_uk_note_10': 'Uniforme, cartable, chaussures, fournitures',
  'finance_copy_data': 'Copier les données',
  'finance_country_at': 'Autriche',
  'finance_country_ch': 'Suisse',
  'finance_country_de': 'Allemagne',
  'finance_country_gb': 'Royaume-Uni',
  'finance_country_generic': 'Autre pays',
  'finance_country_tr': 'Turquie',
  'finance_create_profile_for_milestones':
      'Crée un profil dans le réseau de parents pour voir des étapes personnalisées.',
  'finance_delete_care': 'Supprimer l\'activité de care',
  'finance_delete_expense': 'Supprimer la dépense',
  'finance_edit_care': 'Modifier l\'activité de care',
  'finance_edit_expense': 'Modifier la dépense',
  'finance_enter_childcare_de':
      'Saisis tes frais de crèche ci-dessus — je calculerai ensuite ton économie d\'impôt.',
  'finance_enter_childcare_generic':
      'Saisis tes frais de garde — je te montrerai ensuite la part déductible.',
  'finance_entries_in': 'Entrées en',
  'finance_estimated_months': 'Estimé dans {months} mois ({year})',
  'finance_estimated_one_month': 'Estimé dans un mois ({year})',
  'finance_expense_removed': 'Dépense supprimée.',
  'finance_expense_updated': 'Dépense mise à jour.',
  'finance_export_csv': 'Exporter en CSV',
  'finance_export_pdf': 'Partager le PDF',
  'finance_fair_settlement': 'Partage mensuel équitable',
  'finance_familienbonus_body':
      'En Autriche, il existe le Familienbonus Plus — un crédit d\'impôt par enfant (jusqu\'à 2 000 €/an jusqu\'au 18e anniversaire). Il se demande via la déclaration d\'impôts ou auprès de l\'employeur.',
  'finance_familienbonus_title': 'Bonus familial Plus',
  'finance_five_year_recommendation':
      'Au cours des 5 prochaines années, environ {total} vous attendent. Avec ~{monthly}/mois, vous êtes prêts.',
  'finance_free_support_in': 'Points d\'accueil gratuits en {country} :',
  'finance_gallery': 'Galerie',
  'finance_goal_in_one_year': 'Dans 1 an · ~{amount}',
  'finance_goal_in_years': 'Dans {years} ans · ~{amount}',
  'finance_goal_months_on_time':
      'Avec {amount}/mois, tu es en bonne voie pour atteindre l\'objectif estimé dans {months} mois.',
  'finance_goal_months_shortfall':
      'Avec {amount}/mois, ce ne sera probablement pas encore suffisant pour l\'objectif estimé dans {months} mois.',
  'finance_goal_projection_almost':
      'Avec {amount}/mois, tu atteindras presque l\'objectif dans {years} ans.',
  'finance_goal_projection_on_time':
      'Avec {amount}/mois, tu atteindras l\'objectif à temps dans {years} ans.',
  'finance_guide_subtitle': 'Décrivez votre situation – le guide vous oriente.',
  'finance_guide_title': 'À quoi avons-nous droit ?',
  'finance_hero_subtitle':
      'Moins de tableaux, plus de temps avec les enfants : partage OCR, équité des soins et détecteur d\'économies dans un seul tableau de bord.',
  'finance_hero_title': 'Les finances familiales, repensées',
  'finance_in_years': 'Dans {years} ans ({year})',
  'finance_in_years_short': 'dans {years} ans',
  'finance_income_high': 'Plus de 4 000 €',
  'finance_income_low': 'Moins de 2 000 €',
  'finance_income_medium': '2 000–4 000 €',
  'finance_individual_split': '100 % individuel',
  'finance_label_amount': 'Montant',
  'finance_label_care_type': 'Type de care',
  'finance_label_category': 'Catégorie',
  'finance_label_credit_value': 'Valeur de crédit',
  'finance_label_distance': 'Distance (km)',
  'finance_label_hours': 'Heures',
  'finance_label_marketplace': 'Place de marché',
  'finance_label_note': 'Note',
  'finance_label_paid_by': 'Payé par',
  'finance_label_parent': 'Parent',
  'finance_label_product_goal': 'Produit / objectif',
  'finance_label_retail_price': 'Prix neuf (€)',
  'finance_label_secondhand_price': 'Prix d\'occasion (€)',
  'finance_label_split_type': 'Type de partage',
  'finance_label_title': 'Titre',
  'finance_legacy_confirm':
      'Les valeurs financières, le guide des aides et les listes de demandes présents sur cet appareil t\'appartiennent-ils ? Avec ta confirmation, ils seront associés à ce compte. Les valeurs existantes du compte sont prioritaires ; les listes sont fusionnées. Les valeurs d\'un autre pays ne sont pas importées comme nouvelle devise. Les données d\'origine restent localement. Rien n\'est publié.',
  'finance_legacy_notice':
      'Cet appareil contient des données financières et des listes non associées. Elles ne sont pas utilisées automatiquement. Connecte-toi pour les reprendre après confirmation de propriété.',
  'finance_legacy_title': 'Reprendre les données financières locales',
  'finance_legal_disclaimer':
      'Ceci n\'est pas un conseil juridique. Vérifie tes droits auprès du service compétent ou d\'un centre de conseil.',
  'finance_link_open_failed':
      'Le lien n\'a pas pu être ouvert. Réessaie plus tard.',
  'finance_load_failed':
      'Les données financières locales n\'ont pas pu être chargées. Réessaie.',
  'finance_mama': 'Maman',
  'finance_milestone_ausbildung': 'Formation/études',
  'finance_milestone_ausbildung_note':
      'Premier équipement, déménagement, caution',
  'finance_milestone_fahrrad': 'Premier vélo',
  'finance_milestone_fahrrad_note': 'Vélo pour enfant + casque',
  'finance_milestone_fuehrerschein': 'Permis de conduire',
  'finance_milestone_fuehrerschein_note': 'Leçons de conduite + examens',
  'finance_milestone_klassenfahrt': 'Premier voyage scolaire',
  'finance_milestone_klassenfahrt_note': '3 à 5 jours, argent de poche inclus',
  'finance_milestone_schulstart': 'Entrée à l\'école',
  'finance_milestone_schulstart_note':
      'Cartable, stylos, sac de sport, cornet de rentrée',
  'finance_milestone_smartphone': 'Premier smartphone',
  'finance_milestone_smartphone_note': 'Appareil + coque + premier forfait',
  'finance_month': 'Mois :',
  'finance_monthly_mix': 'Votre bilan du mois en un coup d\'œil',
  'finance_monthly_recommendation':
      'Recommandation : mettre de côté {amount}/mois.',
  'finance_next_year': 'L\'année prochaine ({year})',
  'finance_no_items_recognized': 'Aucun poste exploitable reconnu.',
  'finance_no_parental_leave': 'Non / congé parental',
  'finance_not_entered': 'Pas encore renseigné',
  'finance_number_invalid':
      'Saisis un montant valide, non négatif, avec au maximum deux décimales.',
  'finance_ocr_failed': 'L\'import du ticket a échoué. Réessaie.',
  'finance_ocr_split': 'Partage OCR (60/40)',
  'finance_orientation_only':
      'Orientation uniquement, sans évaluation des droits. Le revenu, l\'activité professionnelle et la situation familiale n\'excluent ici aucune aide. Le service compétent examine votre cas individuel.',
  'finance_papa': 'Papa',
  'finance_qr_copied': 'Données QR copiées.',
  'finance_qr_settlement': 'Règlement par QR',
  'finance_quick_start': 'Démarrage rapide',
  'finance_recent_ocr': 'Derniers postes scannés',
  'finance_save_orientation':
      'Enregistrer les informations à titre d\'orientation',
  'finance_saved_so_far': 'Épargné jusqu\'ici',
  'finance_saving_tip_de':
      'Frais de garde déductibles : 80 %, au maximum 4 800 €/an par enfant, en charge spéciale (§10 EStG, Allemagne). Vérifie les conditions.',
  'finance_saving_tip_generic':
      'Vérifie si les frais de garde d\'enfants sont déductibles des impôts dans ton pays.',
  'finance_savings_rate_month': 'Taux d\'épargne/mois',
  'finance_scan_receipt': 'Scanner le ticket',
  'finance_scan_running': 'Analyse en cours...',
  'finance_share_failed': 'L\'aperçu n\'a pas pu être partagé. Réessaie.',
  'finance_share_footer': '📱 Créé avec ParentPeak – votre compagnon parental',
  'finance_share_monthly_costs':
      '💰 Coûts mensuels pour l\'enfant : ~{amount}/mois',
  'finance_share_next_milestones': '🎯 Prochaines étapes :',
  'finance_share_possible_benefits': '📋 Aides possibles :',
  'finance_share_subject': 'Aperçu Budget Familial',
  'finance_share_title': '{flag} Aperçu Budget Familial – {country}',
  'finance_share_yearly_costs': '   {amount}/an',
  'finance_standard_split': 'Partage standard',
  'finance_start_application_helper': 'Lancer l\'assistant de demande',
  'finance_status_check_required': 'Vérification nécessaire',
  'finance_status_income_dependent': 'Soumis au revenu',
  'finance_status_universal': 'Aide générale · vérifier les conditions',
  'finance_support_at_food': 'Aide alimentaire – Tafel Autriche',
  'finance_support_caritas': 'Centres de conseil Caritas',
  'finance_support_de_clothing': 'Vestiaire – Caritas',
  'finance_support_de_debt':
      'Conseil gratuit en matière de dettes (centre de consommateurs)',
  'finance_support_de_education': 'Demander Éducation et Participation (BuT)',
  'finance_support_de_food': 'Aide alimentaire – Tafel Allemagne',
  'finance_support_debt': 'Conseil gratuit en matière de dettes',
  'finance_support_family_advice': 'Aide et conseil aux familles',
  'finance_support_food_bank': 'Trouver une banque alimentaire locale',
  'finance_tab_benefits': 'Aides',
  'finance_tab_milestones': 'Étapes',
  'finance_tab_overview': 'Aperçu',
  'finance_tax_actual_deductible': 'Charge spéciale dans l\'exemple',
  'finance_tax_childcare_year': 'Frais de crèche/an',
  'finance_tax_deductible_share': 'Part éligible (80 %)',
  'finance_tax_estimated_saving': 'Économie estimée (30 %)',
  'finance_tax_example_limits':
      'Exemple pour un enfant, sans évaluation des droits ni répartition des frais entre enfants. Frais de garde éligibles : enfant dans le ménage et de moins de 14 ans ou exception légale liée au handicap ; facture et paiement sur le compte du prestataire requis. Les cours, le sport et les loisirs ne sont pas éligibles. 30 % n\'est qu\'un taux d\'imposition supposé.',
  'finance_tax_max_expense': 'Charge spéciale max.',
  'finance_tax_more_info': '🔗 Plus d\'infos auprès du centre des impôts →',
  'finance_tax_saving_potential': 'Potentiel d\'économie d\'impôt',
  'finance_tax_saving_summary':
      'Exemple : {deductible} de charge spéciale → environ {savings} d\'économie d\'impôt/an pour un taux supposé de 30 %',
  'finance_title': 'Finances et budget',
  'finish': 'Terminer',
  'food_empty_nearby_subtitle':
      'Soyez le premier ! Appuyez en bas sur « J\'ai cuisiné en plus ! »',
  'food_empty_nearby_title': 'Pas encore d\'offres près de chez vous',
  'food_for_you': 'Pour toi',
  'food_moderation_note_hint': 'Facultatif : courte note pour la modération',
  'food_parent_notes': 'Informations pour les parents',
  'for_holidays_info':
      'Pour les jours fériés, les vacances scolaires et les aides régionales.',
  'format_practice': 'Pratique',
  'format_reflection': 'Réflexion',
  'format_understand': 'Comprendre',
  'found': 'Trouvé',
  'fridge_add_ingredient_hint': 'Ajouter un ingrédient…',
  'fridge_add_missing_many': 'Ingrédients manquants sur la liste de courses',
  'fridge_add_missing_one': 'Ingrédient manquant sur la liste de courses',
  'fridge_choose_photo': 'Choisir',
  'fridge_consent_accept': 'D\'accord, analyser la photo',
  'fridge_consent_body':
      'Pour la reconnaissance des ingrédients, votre photo est envoyée via le backend ParentPeak à Google Gemini. Le contenu des images n\'est pas anonymisé ; ne montrez pas de personnes, de notes privées ni d\'adresses. Pour la recette qui suit, les ingrédients confirmés, l\'âge de l\'enfant et les informations d\'allergie existantes sont envoyés à Google Gemini. L\'application n\'enregistre pas la photo comme brouillon durable. Ce consentement facultatif vaut pour ce flux IA du frigo et est enregistré pour votre compte actuel ou le mode invité sur cet appareil. Il ne publie ni la photo ni la recette. Sans consentement, aucune requête IA n\'est lancée.',
  'fridge_consent_failed':
      'Le consentement à l\'IA du frigo n\'a pas pu être confirmé. Sans consentement confirmé, aucune nouvelle requête IA n\'est lancée.',
  'fridge_consent_title': 'Analyser la photo avec l\'IA',
  'fridge_detected_ingredients': 'Ingrédients reconnus',
  'fridge_edit_ingredients_hint':
      'Touchez le ✕ pour retirer quelque chose, ou ajoutez ci-dessous.',
  'fridge_generating_recipe': 'Je concocte une recette…',
  'fridge_ingredients_required': 'Veuillez ajouter au moins un ingrédient.',
  'fridge_ingredients_title': 'Ingrédients',
  'fridge_inspecting_photo': 'Je regarde ta photo…',
  'fridge_intro':
      'Prends une photo de tes aliments – je reconnais les ingrédients et propose une recette adaptée aux enfants.',
  'fridge_missing_title': 'Il manque encore',
  'fridge_new_photo': 'Nouvelle photo',
  'fridge_no_ingredients': 'Pas encore d\'ingrédients – ajoutez-en ci-dessous.',
  'fridge_no_ingredients_detected':
      'Je n\'ai pas pu reconnaître d\'ingrédients avec certitude. Vous pouvez simplement les ajouter vous-même ci-dessous.',
  'fridge_photo_processing_failed': 'Impossible de traiter la photo.',
  'fridge_photo_question': 'Qu\'y a-t-il dans le frigo ?',
  'fridge_preparation_title': 'Préparation',
  'fridge_recipe_generation_failed':
      'Je n\'ai pas pu créer de recette à l\'instant. Réessayez dans un moment.',
  'fridge_restart': 'Recommencer',
  'fridge_save_success': 'Recette {destination}. 🍳',
  'fridge_saved_friends': 'partagée avec vos amis',
  'fridge_saved_private': 'enregistrée dans vos recettes de famille',
  'fridge_saved_public': 'partagée avec toutes les familles',
  'fridge_share_to_family': 'Partager dans les recettes de famille',
  'fridge_shared_to_family': 'Enregistré dans les recettes de famille',
  'fridge_shopping_added_many':
      '{count} ingrédients ajoutés à la liste de courses. 🛒',
  'fridge_shopping_added_one': '1 ingrédient ajouté à la liste de courses. 🛒',
  'fridge_suggest_recipe': 'Proposer une recette',
  'fridge_take_photo': 'Prendre une photo',
  'fridge_title': 'Avec ce qu\'il y a',
  'friend_chat_request_failed':
      'La demande de chat a échoué. Vérifie ta connexion et réessaie.',
  'hide_action': 'Masquer',
  'hide_offer': 'Masquer l\'offre ?',
  'holiday_settings_title': 'Jours fériés et vacances scolaires',
  'holidays_title': 'Jours fériés et vacances scolaires',
  'home_activity_baby_10_materials': 'Ballon mou',
  'home_activity_baby_10_tip':
      'Faire rouler un ballon : asseyez-vous face à face et faites rouler un ballon mou.',
  'home_activity_baby_11_materials': 'Rien de nécessaire',
  'home_activity_baby_11_tip':
      'Chanson bercée : bercez votre enfant sur vos genoux en fredonnant un air calme.',
  'home_activity_baby_12_materials': 'Rien de nécessaire',
  'home_activity_baby_12_tip':
      'Jeu des parties du corps : demandez « Où est ton nez ? » et nommez les parties du corps ensemble.',
  'home_activity_baby_13_materials': 'Bouteille en plastique, riz ou lentilles',
  'home_activity_baby_13_tip':
      'Fabriquer une bouteille à secouer : versez du riz ou des lentilles dans une bouteille en plastique vide.',
  'home_activity_baby_14_materials': 'Porte-bébé ou poussette',
  'home_activity_baby_14_tip':
      'Promenade émerveillée : marchez lentement et nommez tout ce que vous voyez et entendez.',
  'home_activity_baby_15_materials': 'Rien de nécessaire',
  'home_activity_baby_15_tip':
      'Rythme en tapant des mains : apprenez ensemble un jeu de mains simple.',
  'home_activity_baby_1_materials': 'Foulards, couverture',
  'home_activity_baby_1_tip':
      'Cache-cache avec des foulards : vous vous cachez, votre bébé cherche. Cela développe la permanence de l\'objet.',
  'home_activity_baby_2_materials': 'Rien de nécessaire',
  'home_activity_baby_2_tip':
      'Course à quatre pattes : rampez ensemble dans la maison. Fous rires garantis.',
  'home_activity_baby_3_materials': 'Casseroles, cuillères en bois',
  'home_activity_baby_3_tip':
      'Orchestre de casseroles : casseroles et cuillères en bois deviennent des instruments et développent le sens du rythme.',
  'home_activity_baby_4_materials': 'Bulles de savon',
  'home_activity_baby_4_tip':
      'Chasse aux bulles de savon : entraînez la coordination œil-main de façon ludique, à l\'intérieur ou dehors.',
  'home_activity_baby_5_materials': 'Rien de nécessaire',
  'home_activity_baby_5_tip':
      'Jeux de doigts chantés : accompagnez une comptine de gestes simples des doigts.',
  'home_activity_baby_6_materials': 'Gobelets en plastique ou cubes',
  'home_activity_baby_6_tip':
      'Construire et renverser une tour : empilez des gobelets, votre enfant renverse la tour.',
  'home_activity_baby_7_materials': 'Miroir',
  'home_activity_baby_7_tip':
      'Jeu du miroir : installez-vous devant un miroir et imitez ensemble des expressions du visage.',
  'home_activity_baby_8_materials': 'Bol, eau, gobelets, cuillères',
  'home_activity_baby_8_tip':
      'Plaisir de l\'eau : plongez gobelets et cuillères dans un bol d\'eau tiède.',
  'home_activity_baby_9_materials':
      'Papier journal, papier aluminium, tissu doux',
  'home_activity_baby_9_tip':
      'Explorer le papier froissé : touchez et froissez ensemble différents papiers et tissus.',
  'home_activity_school_10_materials':
      'Pot de fleurs, terreau, graines, petit carnet',
  'home_activity_school_10_tip':
      'Projet plante : semez des graines et notez chaque jour la croissance.',
  'home_activity_school_11_materials': 'Papier, enveloppe, stylo',
  'home_activity_school_11_tip':
      'Lettre au futur : écrivez aujourd\'hui une lettre à votre moi dans cinq ans.',
  'home_activity_school_12_materials': 'Contenu du frigo, ustensiles',
  'home_activity_school_12_tip':
      'Défi cuisine : chaque membre de la famille prépare un plat ou une partie du repas.',
  'home_activity_school_13_materials':
      'Petit carnet, crayons, crayons de couleur',
  'home_activity_school_13_tip':
      'Carnet nature : dessinez et nommez dehors oiseaux, insectes et plantes.',
  'home_activity_school_14_materials': 'Papier, crayons, objets du quotidien',
  'home_activity_school_14_tip':
      'Escape game familial : inventez et résolvez ensemble des énigmes avec des objets du quotidien.',
  'home_activity_school_15_materials': 'Appli ciel étoilé, couverture',
  'home_activity_school_15_tip':
      'Observer le ciel étoilé : cherchez le soir des constellations avec une appli.',
  'home_activity_school_1_materials': 'Papier, crayons, petit trésor',
  'home_activity_school_1_tip':
      'Chasse au trésor au parc : écrivez des indices, planifiez un parcours et cachez un trésor.',
  'home_activity_school_2_materials': 'Papier, crayons',
  'home_activity_school_2_tip':
      'Quiz familial : chacun écrit cinq questions sur soi. Qui connaît le mieux les autres ?',
  'home_activity_school_3_materials': 'Smartphone avec appli de géocaching',
  'home_activity_school_3_tip':
      'Géocaching : cherchez de vraies caches dehors avec une appli gratuite.',
  'home_activity_school_4_materials': 'Papier, crayons, crayons de couleur',
  'home_activity_school_4_tip':
      'Dessiner une BD : racontez ensemble une courte histoire sous forme de bande dessinée.',
  'home_activity_school_5_materials': 'Smartphone, liste imprimée',
  'home_activity_school_5_tip':
      'Safari photo : cherchez avec l\'appareil photo des choses rouges, rondes ou douces.',
  'home_activity_school_6_materials':
      'Bicarbonate, vinaigre, citron, verre, cotons-tiges',
  'home_activity_school_6_tip':
      'Labo de sciences : essayez un volcan au bicarbonate ou de l\'encre invisible au jus de citron.',
  'home_activity_school_7_materials':
      'Couvertures, coussins, guirlande lumineuse, lampe de poche',
  'home_activity_school_7_tip':
      'Campement au salon : montez une tente en couvertures et coussins pour une nuit à l\'intérieur.',
  'home_activity_school_8_materials': 'Jeux de société, en-cas',
  'home_activity_school_8_tip':
      'Tournoi de jeux de société : jouez trois manches et comptez les points ensemble.',
  'home_activity_school_9_materials': 'Smartphone, déguisements en option',
  'home_activity_school_9_tip':
      'Tourner un court-métrage : inventez une histoire, répartissez les rôles et filmez-la.',
  'home_activity_toddler_10_materials': 'Matériaux naturels',
  'home_activity_toddler_10_tip':
      'Mandala nature : disposez feuilles, galets et brindilles en cercle sur le sol.',
  'home_activity_toddler_11_materials': 'Chaises, couvertures, coussins',
  'home_activity_toddler_11_tip':
      'Parcours d\'obstacles : construisez tunnels et ponts avec chaises, couvertures et coussins.',
  'home_activity_toddler_12_materials': 'Gouache, gobelets, eau, papier',
  'home_activity_toddler_12_tip':
      'Expériences de couleurs : mélangez des gouaches et découvrez ensemble de nouvelles couleurs.',
  'home_activity_toddler_13_materials': 'Petit carnet, crayons',
  'home_activity_toddler_13_tip':
      'Carnet météo : dessinez chaque jour le soleil, les nuages ou la pluie dans un carnet.',
  'home_activity_toddler_14_materials': 'Bol, eau, matériaux naturels',
  'home_activity_toddler_14_tip':
      'Cuisine de boue dehors : préparez une soupe imaginaire avec eau, terre et feuilles.',
  'home_activity_toddler_15_materials': 'Feutres adaptés à la peau, mains',
  'home_activity_toddler_15_tip':
      'Théâtre de doigts : dessinez des visages sur les doigts et inventez une histoire ensemble.',
  'home_activity_toddler_1_materials': 'Papier, crayons, cinq petits objets',
  'home_activity_toddler_1_tip':
      'Chasse au trésor dans le salon : cachez cinq objets et dessinez une carte au trésor.',
  'home_activity_toddler_2_materials': 'Vieux vêtements, accessoires',
  'home_activity_toddler_2_tip':
      'Se déguiser avec l\'armoire : jouez au théâtre avec de vieux vêtements, chapeaux et foulards.',
  'home_activity_toddler_3_materials':
      'Coussins, serviettes, film, couvertures',
  'home_activity_toddler_3_tip':
      'Parcours pieds nus : ressentez avec les pieds coussins, serviettes et autres surfaces.',
  'home_activity_toddler_4_materials': 'Galets, gouache, pinceau',
  'home_activity_toddler_4_tip':
      'Peindre des galets : ramassez des galets dehors et décorez-les à la gouache à l\'intérieur.',
  'home_activity_toddler_5_materials': 'Grands cartons, ruban adhésif, crayons',
  'home_activity_toddler_5_tip':
      'Château en carton : transformez de grands cartons en maisons, voitures ou fusées.',
  'home_activity_toddler_6_materials':
      'Farine, sel, eau, huile, colorant alimentaire',
  'home_activity_toddler_6_tip':
      'Pâte à modeler maison : mélangez farine, sel, eau et colorant alimentaire.',
  'home_activity_toddler_7_materials': 'Bottes en caoutchouc, imperméable',
  'home_activity_toddler_7_tip':
      'Sauter dans les flaques : après la pluie, enfilez les bottes et sautez !',
  'home_activity_toddler_8_materials': 'Farine, œufs, sucre, beurre, moule',
  'home_activity_toddler_8_tip':
      'Pâtisserie : préparez ensemble un gâteau simple.',
  'home_activity_toddler_9_materials': 'Lampe de poche, pièce sombre',
  'home_activity_toddler_9_tip':
      'Théâtre d\'ombres : formez des animaux sur le mur avec les mains et une lampe de poche.',
  'home_best_moment_hint': 'Un moment avec mon enfant…',
  'home_best_moment_question':
      'Quel a été votre plus beau moment aujourd\'hui ?',
  'home_evening_reassurance': 'Vous êtes là. Demain est un nouveau jour.',
  'home_greeting_name': '{greeting}, {name}u00a0!',
  'home_hello_name': 'Bonjour {name}u00a0!',
  'home_match_new_many': '{count} nouvelles mises en relation',
  'home_match_new_one': '1 nouvelle mise en relation',
  'home_mood_good': 'Bien',
  'home_mood_grateful': 'Reconnaissant·e',
  'home_mood_great': 'Super',
  'home_mood_okay': 'Correct',
  'home_mood_tough': 'Difficile',
  'home_open_calendar_hint': 'Touchez pour ouvrir le calendrier',
  'home_quick_ai_chat': 'Chat IA',
  'home_quick_ask': 'Demande-moi',
  'home_quick_calendar': 'Calendrier',
  'home_quick_events': 'Événements',
  'home_quick_impulses': 'Impulsions',
  'home_quick_lists': 'Listes',
  'home_quick_network': 'Réseau',
  'home_quick_recipes': 'Recettes',
  'home_today_event_many': 'Aujourd\'huiu00a0: {count} rendez-vous',
  'home_today_event_one': 'Aujourd\'huiu00a0: 1 rendez-vous',
  'home_weekly_review_question': 'Comment s\'est passée votre semaineu00a0?',
  'home_welcome_back': 'Ravis de vous revoir',
  'home_your_features': 'Vos fonctionnalités',
  'host_activities': 'Activités',
  'host_approve': 'Approuver',
  'host_dashboard_title': 'Mon tableau de bord d\'organisateur',
  'host_decline': 'Refuser',
  'host_my_activities': 'Mes activités',
  'host_no_activities': 'Tu n\'as encore créé aucune activité',
  'host_participants': 'Participants',
  'host_pending': 'En attente',
  'host_pending_requests': 'Demandes en attente',
  'host_request_approved': 'Demande approuvée !',
  'host_request_declined': 'Demande refusée',
  'host_requested_at': 'Demandé le : {date}',
  'host_sign_in_required':
      'Connecte-toi pour voir ton tableau de bord d\'hôte.',
  'host_statistics': 'Statistiques',
  'host_user_label': 'Utilisateur : {name}',
  'how_was_week': 'Comment s\'est passée ta semaine ?',
  'import_action': 'Importer',
  'important_know': 'Bon à savoir :',
  'important_to_know': 'Bon à savoir :',
  'impressum': 'Mentions légales',
  'instant_notifications': 'Notifications instantanées',
  'jump_to_today': 'Aller à aujourd\'hui',
  'jump_today': 'Aller à aujourd\'hui',
  'kitchen_add_ingredients_count': 'Ajouter {count} ingrédients',
  'kitchen_age_months': 'dès 6 mois',
  'kitchen_age_years': 'dès {age} ans',
  'kitchen_buy_only_needed':
      'Choisissez seulement ce que vous devez vraiment acheter.',
  'kitchen_cost_per_portion': '~{cost}€/portion',
  'kitchen_error': 'Erreur : {error}',
  'kitchen_family_recipes_tooltip':
      'Recettes de famille (partager et découvrir)',
  'kitchen_fridge_subtitle':
      'Prenez une photo du frigo – je vous propose une recette.',
  'kitchen_fridge_title': 'Avec ce qu\'il y a',
  'kitchen_ingredients_added':
      '✅ {count} ingrédients ajoutés à la liste de courses',
  'kitchen_ingredients_preparation': '🍳 Ingrédients et préparation',
  'kitchen_kids_hits_subtitle':
      'Ce que vos enfants ont aimé jusqu\'ici. Touchez pour des recettes similaires.',
  'kitchen_kids_hits_title': 'Les hits des enfants',
  'kitchen_kids_hits_tooltip': 'Trouver des recettes similaires',
  'kitchen_minutes': '{minutes} min',
  'kitchen_no_safe_recipe_body':
      'En raison des allergies indiquées, nous n\'avons pas pu proposer une recette sûre à l\'instant. Vérifiez les allergies dans le dossier enfant ou réessayez.',
  'kitchen_no_safe_recipe_title': 'La sécurité d\'abord',
  'kitchen_rating_liked': '⭐ Ajouté à la liste des hits des enfants.',
  'kitchen_rating_not_liked': '👍 On le note.',
  'kitchen_saved_recipes_count': '❤ Recettes enregistrées ({count})',
  'kitchen_search_hint':
      'Vous cherchez une recette précise ? (p. ex. crêpes, pâtes)',
  'kitchen_table_moment_evening_subtitle':
      'Notez ensemble ce qui était beau aujourd\'hui.',
  'kitchen_table_moment_evening_title':
      'C\'est l\'heure de votre moment à table 🕯️',
  'kitchen_table_moment_subtitle':
      'Un doux rituel du soir à la table familiale.',
  'kitchen_table_moment_title': 'Notre moment à table',
  'kitchen_tip_budget':
      'Astuce budget|Les légumineuses sont bon marché, saines et rassasiantes. Parfaites pour les familles.',
  'kitchen_tip_cook_together':
      'Cuisiner ensemble|Les enfants qui participent mangent plus volontiers ce qui est dans l\'assiette. Dès 2 ans : mélanger et laver. Dès 4 ans : couper avec un couteau pour enfant.',
  'kitchen_tip_drinking':
      'Ne pas oublier de boire|Une gourde colorée et des moments de boisson fixes aident les enfants à boire assez.',
  'kitchen_tip_family_ritual':
      'Rituel familial|Une fois par semaine, cuisinez ensemble ; les enfants choisissent le plat. Cela renforce la cohésion et l\'appétit.',
  'kitchen_tip_frozen_pizza':
      'Pizza surgelée aujourd\'hui ?|Tout à fait d\'accord. Chaque jour ne doit pas être parfait. Demain, on cuisine frais.',
  'kitchen_tip_frozen_vegetables':
      'Les légumes surgelés, c\'est bien|Petits pois et brocolis surgelés ont autant de vitamines que les frais et sont prêts en 5 minutes.',
  'kitchen_tip_healthy_sweets':
      'Grignoter sain|Raisins congelés, glace à la banane ou boules d\'énergie : sucré sans pic de glycémie.',
  'kitchen_tip_hidden_vegetables':
      'Cacher les légumes|Râper de la courgette dans la bolognaise, des carottes dans les crêpes. Les enfants ne le remarquent pas, vous si.',
  'kitchen_tip_leftovers':
      'Utiliser les restes avec créativité|Les restes deviennent wraps, gratins ou riz sauté. Moins de gaspillage, plus de variété.',
  'kitchen_tip_meal_prep':
      'Astuce meal-prep|Le dimanche, cuisinez en double et congelez. En semaine, un repas sain est prêt en 10 minutes.',
  'kitchen_tip_morning':
      'Astuce du matin|Préparez le petit-déjeuner la veille : overnight oats, tartines coupées, fruits lavés. Le matin est plus serein.',
  'kitchen_tip_nature':
      'Enfants et nature|Faites pousser des herbes sur le rebord de la fenêtre. Qui récolte soi-même goûte plus volontiers, même le persil.',
  'kitchen_tip_no_food_battle':
      'Pas de bataille à table|Proposer la nourriture, ne pas forcer. Les enfants régulent eux-mêmes leur quantité. Confiance plutôt que pression.',
  'kitchen_tip_picky_eater':
      'Enfant difficile ?|Les enfants ont besoin de jusqu\'à 15 essais avant d\'aimer un nouvel aliment. Proposez encore et encore, sans jamais forcer.',
  'kitchen_tip_season_autumn':
      'Astuce de saison|Courge, pommes et poires sont sucrées, bon marché et polyvalentes. La soupe de courge se fait en 20 minutes.',
  'kitchen_tip_season_spring':
      'Astuce de saison|Asperges, radis et épinards sont frais du marché. Les radis récoltés soi-même, les enfants les goûtent plus volontiers.',
  'kitchen_tip_season_summer':
      'Astuce de saison|Fraises, cerises et tomates sont fraîches et bon marché en ce moment. Parfaites en en-cas sans cuisson.',
  'kitchen_tip_season_winter':
      'Astuce de saison|Chou-rave, carottes et pommes de terre : le pot-au-feu réchauffe, est bon marché et se prépare bien à l\'avance.',
  'kitchen_tip_snack':
      'Idée d\'en-cas|Tranches de pomme avec beurre de cacahuète ou bâtonnets de concombre au fromage frais : rapide, sain, presque sans effort.',
  'kitchen_try_again': 'Réessayer',
  'kitchen_view_ingredients_preparation': '🍳 Voir ingrédients et préparation',
  'kitchen_without': '🚫 Sans :',
  'knowledge_content_language_notice':
      'Les questions et réponses sont traduites. La recherche fonctionne encore avec des mots-clés allemands : saisis un mot allemand ou choisis une carte thématique.',
  'knowledge_search_hint':
      'Qu\'est-ce qui te préoccupe ? (p. ex. « frappe », « ne dort pas »)',
  'knowledge_tab': 'Savoirs',
  'knowledge_topic_anger_label': 'Colère & opposition',
  'knowledge_topic_anger_hint': 'Crises, coups',
  'knowledge_topic_sleep_label': 'Sommeil',
  'knowledge_topic_sleep_hint': 'Endormissement, nuit',
  'knowledge_topic_boundaries_label': 'Limites',
  'knowledge_topic_boundaries_hint': 'Dire non, règles',
  'knowledge_topic_eating_label': 'Alimentation',
  'knowledge_topic_eating_hint': 'Enfant difficile à table',
  'knowledge_topic_siblings_label': 'Fratrie',
  'knowledge_topic_siblings_hint': 'Disputes, jalousie',
  'knowledge_topic_media_label': 'Écrans',
  'knowledge_topic_media_hint': 'Temps d\'écran',
  'knowledge_ui_language_notice':
      'Les traductions manquantes des éléments d\'interface s\'affichent en anglais.',
  'language_select': 'Choisir la langue',
  'legal_info_tmg': 'Informations selon le TMG / MStV (Allemagne)',
  'lets_go': 'C\'est parti !',
  'loading': 'Chargement…',
  'location_onboarding_detect': 'Détecter ma position',
  'location_onboarding_explanation':
      'Une localisation approximative t\'aide à trouver des activités à proximité. Le choix du lieu est facultatif.',
  'location_onboarding_manual_hint': 'Ville ou code postal',
  'location_onboarding_manual_title': 'Saisir une ville ou un code postal',
  'location_onboarding_privacy':
      'Ta localisation n\'est enregistrée que de manière approximative (2 décimales, environ 1 km). Pour le nom du lieu, nous envoyons des coordonnées GPS arrondies ou ta saisie à OpenStreetMap Nominatim.',
  'location_onboarding_skip': 'Ignorer',
  'location_osm_notice':
      'La recherche de lieu envoie le texte saisi ou des coordonnées arrondies à environ 1 km à OpenStreetMap Nominatim. La carte charge des tuiles depuis OpenStreetMap.',
  'location_search_failed': 'La recherche de lieu a échoué. Réessaie.',
  'login_brand_tagline': 'Sûr. Clair. Pensé pour les familles.',
  'login_create_account': 'Créer un compte',
  'login_failed': 'La connexion a échoué. Veuillez réessayer.',
  'login_forgot_password': 'Mot de passe oublié ?',
  'login_google_error': 'Connexion Google : {message}',
  'login_google_failed': 'La connexion Google a échoué. Veuillez réessayer.',
  'login_google_popup_blocked':
      'Les pop-ups sont bloquées. Utilisez e-mail + mot de passe ou ouvrez la page dans Safari.',
  'login_google_retry':
      'Connexion Google : réessayez ou utilisez e-mail + mot de passe.',
  'login_new_prompt': 'Nouveau sur Parentpeak ? ',
  'login_provider_coming_soon':
      'La connexion {provider} arrive dans la prochaine version.',
  'login_submit': 'Se connecter',
  'login_subtitle': 'Connectez-vous pour ouvrir votre espace familial.',
  'login_technical_error':
      'Erreur technique lors de la connexion. Veuillez réessayer.',
  'login_welcome_back': 'Bon retour',
  'logout_action': 'Se déconnecter',
  'logout_confirm': 'Se déconnecter ?',
  'logout_question': 'Se déconnecter ?',
  'looking_forward': 'De quoi te réjouis-tu la semaine prochaine ?',
  'lunch': 'Déjeuner',
  'market_contact': 'Contact',
  'market_details': 'Détails',
  'market_filter': 'Filtre',
  'market_no_categories': 'Aucune catégorie disponible',
  'marketplace': 'Place de marché',
  'matching_block_profiles': 'Bloquer des profils',
  'matching_blocked_info': 'Les profils bloqués ne sont plus affichés.',
  'matching_confirmed': 'Match confirmé avec {name} ({score}%)',
  'matching_current_status': 'Statut actuel',
  'matching_enter_name': 'Veuillez saisir un nom.',
  'matching_enter_otp': 'Veuillez saisir le code OTP à 6 chiffres.',
  'matching_enter_phone': 'Veuillez saisir un numéro de téléphone.',
  'matching_filter': 'Filtre de matching',
  'matching_load_failed': 'Impossible de charger le matching intelligent',
  'matching_no_new_connections':
      'Aucune nouvelle connexion confirmée pour le moment.',
  'matching_otp_sent': 'Code OTP envoyé. Veuillez saisir le code.',
  'matching_phone_verified': 'Téléphone vérifié avec succès.',
  'matching_profile': 'Mon profil de matching',
  'matching_report_profiles': 'Signaler des profils',
  'matching_request_sent':
      'Demande envoyée. La connexion est en cours de confirmation.',
  'matching_reset': 'Réinitialiser',
  'matching_safety_check': 'Vérification de sécurité',
  'matching_safety_queue': 'File de sécurité',
  'meetup_activity_count': '{count} activités',
  'meetup_filter_description':
      'Filtres de visibilité clairs, à affiner par âge si besoin.',
  'meetup_less_filters': 'Moins de filtres',
  'meetup_more_filters': 'Plus de filtres',
  'meetup_nearby': 'Activités près de chez toi',
  'meetup_title': 'Activités et rencontres',
  'memory_add_child': 'Ajouter un enfant',
  'memory_children': 'Profils enfant',
  'memory_confirmed_count': '{count} informations confirmées',
  'memory_consent_accept':
      'Autoriser l\'enregistrement et l\'utilisation par l\'IA',
  'memory_consent_body':
      'Facultatif : les informations familiales confirmées, y compris les données de santé, sont enregistrées par compte dans le backend ParentPeak et transmises à Google Gemini pour les requêtes de chat pertinentes. Les nouveaux prénoms d\'enfants restent uniquement sur cet appareil ; l\'IA reçoit des espaces réservés neutres et l\'âge révolu au lieu du nom et de la date de naissance. Le texte libre peut toujours contenir des informations personnelles. Les anciennes données d\'origine sont conservées. Sans consentement, les nouvelles entrées mémoire et les transmissions mémoire sont bloquées ; le chat normal avec son propre consentement reste possible. La désactivation met fin à l\'utilisation, mais ne supprime pas les données existantes. Les requêtes déjà envoyées ne sont pas récupérables. Les données locales ne sont pas chiffrées en plus par l\'application.',
  'memory_consent_required':
      'Veuillez activer la mémoire avec le consentement supplémentaire avant d\'enregistrer de nouvelles données.',
  'memory_consent_title': 'Consentement supplémentaire à la mémoire IA',
  'memory_delete_body':
      'Toutes les informations IA enregistrées sur {name} seront supprimées.',
  'memory_delete_title': 'Supprimer le profil enfant ?',
  'memory_edit_child': 'Modifier le profil enfant',
  'memory_empty_info': 'Aucune information enregistrée pour l\'instant.',
  'memory_enable': 'Activer la mémoire IA',
  'memory_gender': 'Genre (facultatif)',
  'memory_load_failed':
      'Impossible de charger les données. Veuillez réessayer.',
  'memory_local_name': 'Nom affiché (seulement sur cet appareil)',
  'memory_name_required': 'Veuillez saisir un nom local.',
  'memory_name_save_failed':
      'Le profil neutre a été enregistré dans le backend, mais le nom affiché local n\'a pas pu être confirmé. La liste est rechargée ; évitez de créer un doublon.',
  'memory_no_children': 'Aucun profil enfant créé pour l\'instant.',
  'memory_none_confirmed': 'Aucune information confirmée',
  'memory_operation_failed':
      'La modification n\'a pas été entièrement confirmée. La mémoire est revérifiée ; veuillez réessayer.',
  'memory_storage_info':
      'Les données d\'origine existantes sont conservées dans le backend. La désactivation bloque le nouvel enregistrement et l\'utilisation par l\'IA, pas la lecture ni la suppression. Les nouveaux noms affichés restent locaux et liés au compte ; pas de chiffrement supplémentaire par l\'application.',
  'memory_title': 'Mémoire IA et enfants',
  'memory_transfer_info':
      'Uniquement avec consentement supplémentaire : valeurs confirmées via le backend vers Google Gemini. Les désignations d\'enfant et l\'âge sont réduits.',
  'money_once_hint':
      'À saisir une seule fois — aucune saisie quotidienne nécessaire.',
  'mood_exhausted': 'Épuisé·e',
  'mood_great': 'Au top',
  'mood_level_1': 'Épuisant',
  'mood_level_2': 'Difficile',
  'mood_level_3': 'Correct',
  'mood_level_4': 'Bien',
  'mood_level_5': 'Merveilleux',
  'mood_okay': 'Correct',
  'mood_support_action': 'Parler avec le conseil IA',
  'mood_support_message':
      'Vous faites de votre mieux chaque jour. Voulez-vous un petit conseil ou parler avec l\'IA ?',
  'mood_support_title': 'Les jours difficiles, c\'est normal',
  'mood_tip_1':
      'Les jours difficiles font partie du chemin. Soyez particulièrement doux avec vous aujourd\'hui.',
  'mood_tip_2':
      'Demain est un nouveau jour. Une petite pause ce soir fera du bien.',
  'mood_tip_3': 'Solide ! Tous les jours ne doivent pas être parfaits.',
  'mood_tip_4': 'Belle journée ! Profitez de l\'instant.',
  'mood_tip_5': 'Quelle superbe journée ! Gardez ce sentiment.',
  'mood_today_prefix': 'Aujourd\'hui : ',
  'mood_today_title': 'Énergie familiale aujourd\'hui',
  'my_profile': 'Mon profil',
  'network_add_members': 'Ajouter des membres',
  'network_age_mixed': '{years} a. {months} m.',
  'network_age_months': '{months} mois',
  'network_age_years': '{years} ans',
  'network_all_friends_in_group': 'Tous vos amis sont déjà dans ce groupe.',
  'network_availability_heading': 'Quand avez-vous du temps ?',
  'network_availability_hint':
      'p. ex. seulement en vacances, seulement les jours fériés…',
  'network_back': 'Retour',
  'network_block': 'Bloquer',
  'network_blocked': '{name} a été bloqué.',
  'network_chat': 'Discussion',
  'network_chats_empty_desc':
      'Connectez-vous avec d\'autres parents et démarrez votre première discussion, en individuel ou en groupe.',
  'network_chats_empty_title': 'Pas encore de conversations',
  'network_child_custom_hint': 'Qu\'aime encore votre enfant ?',
  'network_child_example': 'p. ex. Mia',
  'network_child_name_local': 'Nom / surnom (seulement sur cet appareil)',
  'network_child_number': 'Enfant {number}',
  'network_choose_members': 'Choisir les membres',
  'network_code_copied': 'Code copié ✓!',
  'network_coming_soon': 'Bientôt disponible',
  'network_connect_confirm': 'Voulez-vous vous connecter avec {name} ?',
  'network_connected_count': '{count} connectés',
  'network_copy_bio_hint':
      'Parlez un peu de vous : qu\'est-ce qui rend votre famille unique ? Que recherchez-vous ?',
  'network_copy_bio_title': 'Courte bio',
  'network_copy_cancel': 'Annuler',
  'network_copy_connect': 'Se connecter ?',
  'network_copy_connect_button': 'Se connecter',
  'network_copy_create_profile': 'Créer un profil',
  'network_copy_custom': 'Personnalisée',
  'network_copy_custom_example':
      'p. ex. famille choisie, multigénérationnelle…',
  'network_copy_custom_family': 'Votre forme de famille',
  'network_copy_empty_description':
      'Votre profil est actif et visible. Dès que d\'autres familles près de chez vous participent, elles apparaissent ici automatiquement. Invitez voisins et amis : c\'est ainsi que votre réseau grandit le plus vite.',
  'network_copy_empty_title': 'Soyez la première famille de votre région',
  'network_copy_family_form': 'Forme de famille',
  'network_copy_invite_hero_description':
      'Partagez votre lien personnel ou votre code QR – un tap et vous êtes connectés.',
  'network_copy_invite_hero_title': 'Inviter des amis',
  'network_copy_invite_playmates': 'Inviter des copains de jeu',
  'network_copy_location_hint': 'Choisir votre quartier / code postal',
  'network_copy_login_required':
      'Connectez-vous pour publier votre profil de rencontres entre enfants.',
  'network_copy_name_example': 'p. ex. Sarah, Les Müller',
  'network_copy_name_hint': 'Votre prénom / surnom',
  'network_copy_no_gender': 'Non précisé',
  'network_copy_playmates': 'Copains de jeu',
  'network_copy_reason_nearby': 'À proximité',
  'network_copy_reason_shared_family_form': 'Forme de famille similaire',
  'network_copy_reason_shared_interests': 'Intérêts communs',
  'network_copy_reason_shared_languages': 'Langues communes',
  'network_copy_reason_shared_values': 'Valeurs éducatives similaires',
  'network_copy_reason_similar_child_age': 'Enfants d\'âge similaire',
  'network_copy_request_failed':
      'Votre demande n\'a pas pu être envoyée. Veuillez réessayer plus tard.',
  'network_copy_request_sent': 'Votre demande a été envoyée à {name}.',
  'network_copy_same_city': 'Dans votre ville',
  'network_copy_save': 'Enregistrement…',
  'network_copy_setup_hint':
      'En 5 étapes rapides, trouvez des familles qui vous ressemblent.',
  'network_copy_share': 'Partager',
  'network_copy_step_1': 'Étape 1 : votre famille',
  'network_copy_step_2': 'Étape 2 : vos enfants',
  'network_copy_step_3': 'Étape 3 : valeurs et style',
  'network_copy_step_4': 'Étape 4 : que cherchez-vous ?',
  'network_copy_step_5': 'Étape 5 : langues et plus',
  'network_copy_values_tip':
      'Astuce : les familles aux valeurs proches s\'entendent le mieux. Choisissez ce qui compte pour vous.',
  'network_create_group': 'Créer un groupe',
  'network_create_group_hint':
      'p. ex. groupe de la crèche ou rencontre au parc',
  'network_custom_add': 'Personnalisé',
  'network_delete_failed':
      'Impossible de supprimer le profil. Il reste enregistré. Veuillez réessayer.',
  'network_delete_profile_confirm':
      'Votre profil de rencontres entre enfants sera supprimé définitivement. Vous pouvez en créer un nouveau à tout moment.',
  'network_discovery_auth_failed':
      'La recherche de familles n\'est pas autorisée pour cette session. Vérifiez votre compte et votre connexion.',
  'network_discovery_failed':
      'Impossible de charger les familles. Ce n\'est pas un résultat de recherche vide confirmé. Veuillez réessayer.',
  'network_discovery_retry': 'Relancer la recherche',
  'network_district_hint': 'Tapez p. ex. Kreuzberg, 10997…',
  'network_district_label': 'Quartier ou code postal',
  'network_draft_assign': 'Associer le brouillon à mon compte',
  'network_draft_assign_body':
      'Confirmez que l\'ancien brouillon de famille local appartient à votre compte « {account} ». Il sera associé uniquement en local à ce compte et sera ensuite disponible aussi pour le calendrier, la cuisine et les autres fonctions familiales. Aucune donnée n\'est téléversée. Une publication nécessite une confirmation séparée.',
  'network_draft_assign_failed':
      'Impossible d\'associer le brouillon. Veuillez réessayer.',
  'network_draft_assign_title': 'Associer le brouillon local à ce compte ?',
  'network_draft_unassigned':
      'Un ancien profil sans compte associé se trouve sur cet appareil. Il n\'est ni utilisé ni publié automatiquement.',
  'network_families_nearby': 'Familles près de chez vous',
  'network_family_fallback': 'cette famille',
  'network_family_name': 'Famille {name}',
  'network_found': 'Trouvé ✓',
  'network_group': 'Groupe',
  'network_group_chat_empty':
      'Pas encore de messages. Écrivez le premier et lancez la conversation !',
  'network_group_create_failed':
      'Impossible de créer le groupe, réessayez plus tard.',
  'network_group_name': 'Nom du groupe',
  'network_group_name_hint': 'p. ex. groupe crèche Soleil',
  'network_group_name_required': 'Veuillez saisir un nom de groupe.',
  'network_group_needs_friends':
      'Ajoutez d\'abord des amis pour créer un groupe.',
  'network_group_not_member': 'Vous n\'êtes pas membre de ce groupe.',
  'network_group_photo_hint': 'Ajouter une photo de groupe (facultatif)',
  'network_group_select_member': 'Veuillez choisir au moins un membre.',
  'network_invalid_invite': 'Invitation non valide ou expirée.',
  'network_languages_heading': 'Quelles langues parlez-vous ?',
  'network_leave_group': 'Quitter le groupe',
  'network_leave_group_confirm':
      'Voulez-vous vraiment quitter ce groupe ? Vous ne verrez plus les messages.',
  'network_legacy_link_inactive':
      'Ce lien n\'est plus actif. Utilisez le lien d\'invitation de l\'autre famille.',
  'network_link_create_failed':
      'Impossible de créer le lien, réessayez plus tard.',
  'network_looking_custom_hint': 'Que souhaitez-vous d\'autre ?',
  'network_looking_heading': 'Que cherchez-vous ?',
  'network_match_score': '{score}% de correspondance',
  'network_matching_suggestions': 'Profils de rencontres publiés',
  'network_members': 'Membres',
  'network_members_add_failed': 'Impossible d\'ajouter les membres.',
  'network_members_added': 'Membres ajoutés.',
  'network_message_hint': 'Écrire un message…',
  'network_new_chat': 'Nouvelle discussion',
  'network_no_messages_yet': 'Pas encore de messages',
  'network_option_child_basteln': '✂ Bricolage',
  'network_option_child_bauen': '🧱 Construire et assembler',
  'network_option_child_bücher': '📚 Livres',
  'network_option_child_experimente': '🔬 Expériences',
  'network_option_child_fahrrad': '🚲 Vélo et trottinette',
  'network_option_child_kochen_backen': '🍪 Cuisine et pâtisserie',
  'network_option_child_malen': '🎨 Peinture',
  'network_option_child_musik': '🎵 Musique',
  'network_option_child_natur': '🌿 Découvrir la nature',
  'network_option_child_rollenspiel': '🎭 Jeu de rôle',
  'network_option_child_spielplatz': '🎠 Aire de jeux',
  'network_option_child_sport': '⚽ Sport',
  'network_option_child_tanzen': '💃 Danse',
  'network_option_child_theater': '🎬 Théâtre et déguisements',
  'network_option_child_tiere': '🐶 Animaux',
  'network_option_child_wasser': '💦 Eau et éclaboussures',
  'network_option_days_dienstag': 'Mar',
  'network_option_days_donnerstag': 'Jeu',
  'network_option_days_freitag': 'Ven',
  'network_option_days_mittwoch': 'Mer',
  'network_option_days_montag': 'Lun',
  'network_option_days_samstag': 'Sam',
  'network_option_days_sonntag': 'Dim',
  'network_option_family_alleinerziehend': '💪 Parent solo',
  'network_option_family_co_parenting': '🤝 Coparentalité',
  'network_option_family_grosseltern': '🧓 Foyer avec grands-parents',
  'network_option_family_grossfamilie': '🏠 Famille nombreuse',
  'network_option_family_kernfamilie': '👪 Famille nucléaire',
  'network_option_family_patchwork': '🧩 Famille recomposée',
  'network_option_family_pflegefamilie': '❤ Famille d\'accueil',
  'network_option_family_regenbogen': '🌈 Famille arc-en-ciel',
  'network_option_family_wg_familie': '🏡 Colocation familiale',
  'network_option_gender_divers': '🌟 Divers',
  'network_option_gender_maennlich': '👦 Garçon',
  'network_option_gender_weiblich': '👧 Fille',
  'network_option_language_ar': '🇸🇦 العربية',
  'network_option_language_bg': '🇧🇬 Български',
  'network_option_language_bs': '🇧🇦 Bosanski',
  'network_option_language_de': '🇩🇪 Deutsch',
  'network_option_language_el': '🇬🇷 Ελληνικά',
  'network_option_language_en': '🇬🇧 English',
  'network_option_language_es': '🇪🇸 Español',
  'network_option_language_fa': '🇮🇷 فارسی',
  'network_option_language_fr': '🇫🇷 Français',
  'network_option_language_hi': '🇮🇳 हिन्दी',
  'network_option_language_hr': '🇭🇷 Hrvatski',
  'network_option_language_it': '🇮🇹 Italiano',
  'network_option_language_ja': '🇯🇵 日本語',
  'network_option_language_ko': '🇰🇷 한국어',
  'network_option_language_ku': 'Kurdî',
  'network_option_language_nl': '🇳🇱 Nederlands',
  'network_option_language_pl': '🇵🇱 Polski',
  'network_option_language_pt': '🇵🇹 Português',
  'network_option_language_ro': '🇷🇴 Română',
  'network_option_language_ru': '🇷🇺 Русский',
  'network_option_language_sq': '🇦🇱 Shqip',
  'network_option_language_sr': '🇷🇸 Srpski',
  'network_option_language_sw': '🇰🇪 Kiswahili',
  'network_option_language_tr': '🇹🇷 Türkçe',
  'network_option_language_uk': '🇺🇦 Українська',
  'network_option_language_vi': '🇻🇳 Tiếng Việt',
  'network_option_language_zh': '🇨🇳 中文',
  'network_option_looking_ausflug': '🏞 Sorties et voyages',
  'network_option_looking_babysitting_tausch': '🤝 Échange de babysitting',
  'network_option_looking_eltern_austausch': '☕ Échange entre parents',
  'network_option_looking_indoor_treffen': '🏠 Rencontres en intérieur',
  'network_option_looking_kindergeburtstage': '🎂 Anniversaires d\'enfants',
  'network_option_looking_kita_fahrgemeinschaft': '🚗 Covoiturage crèche',
  'network_option_looking_kochen': '🍳 Cuisiner ensemble',
  'network_option_looking_kreativ': '🎨 Rencontres créatives',
  'network_option_looking_musik': '🎵 Musique et chant',
  'network_option_looking_natur': '🌳 Forêt et nature',
  'network_option_looking_online_austausch': '💬 Échange en ligne',
  'network_option_looking_regelmaessig': '🔄 Groupe régulier',
  'network_option_looking_spielplatz': '🎠 Sorties à l\'aire de jeux',
  'network_option_looking_spontan': '⚡ Rencontres spontanées',
  'network_option_looking_sport': '⚽ Sport et mouvement',
  'network_option_looking_vorlesen': '📖 Lecture et histoires',
  'network_option_specials_allergien': '⚠ Allergies/intolérances',
  'network_option_specials_behinderung': '♿ Enfant en situation de handicap',
  'network_option_specials_chronisch_krank': '🏥 Maladie chronique',
  'network_option_specials_fruehchen': '💪 Parents de prématuré',
  'network_option_specials_hochsensibel': '🌼 Hypersensible',
  'network_option_specials_mehrlinge': '👯 Multiples',
  'network_option_specials_neurodivergent': '🧠 Neurodivergent (TDAH/autisme)',
  'network_option_specials_pflegekind': '❤ Enfant placé',
  'network_option_specials_schreibaby':
      '👶 Bébé aux pleurs intenses/trouble de la régulation',
  'network_option_times_abends': '🌙 Soir (17–21 h)',
  'network_option_times_flexibel': '💫 Flexible',
  'network_option_times_morgens': '🌅 Tôt (6–9 h)',
  'network_option_times_nach_kita': '🏫 Après la crèche/l\'école',
  'network_option_times_nachmittags': '🌞 Après-midi (12–17 h)',
  'network_option_times_vormittags': '☀ Matinée (9–12 h)',
  'network_option_values_attachment_parenting':
      '🤗 Parentalité par l\'attachement',
  'network_option_values_bedürfnisorientiert': '💛 Centré sur les besoins',
  'network_option_values_demokratisch': '🗳 Démocratique',
  'network_option_values_feministisch': '♀ Féministe',
  'network_option_values_freilernend': '📚 Apprentissage libre',
  'network_option_values_gfk': '💚 Communication NonViolente (CNV)',
  'network_option_values_interkulturell': '🌍 Interculturel',
  'network_option_values_montessori': '🔬 Montessori',
  'network_option_values_naturverbunden': '🌳 Proche de la nature',
  'network_option_values_offen': '✨ Ouvert à tout',
  'network_option_values_pikler': '👶 Pikler',
  'network_option_values_religioes': '🕌 Religieux/spirituel',
  'network_option_values_respektvoll': '🙏 Respectueux',
  'network_option_values_strukturiert': '📋 Structuré',
  'network_option_values_unerzogen': '🌱 Sans éducation imposée',
  'network_option_values_waldorf': '🌿 Waldorf',
  'network_outgoing_requests': 'Demandes envoyées',
  'network_owner_label': 'Admin',
  'network_photo_camera': 'Prendre une photo',
  'network_photo_gallery': 'Choisir dans la galerie',
  'network_profile_active': 'Profil confirmé actif par le serveur.',
  'network_profile_draft':
      'Aucun profil actif confirmé sur le serveur. Les brouillons locaux ne sont pas publiés automatiquement.',
  'network_profile_retry': 'Revérifier l\'état',
  'network_profile_unverified':
      'Impossible de vérifier l\'état du profil. La visibilité n\'est pas confirmée.',
  'network_publish_accept': 'Publier le profil',
  'network_publish_body':
      'Votre nom affiché, votre ville, votre localisation grossièrement arrondie (si disponible), l\'âge approximatif des enfants, les langues, la forme de famille, les valeurs, les activités souhaitées et votre bio sont enregistrés sur notre backend et montrés aux autres familles du réseau. Les prénoms des enfants, dates de naissance et particularités restent sur cet appareil. N\'indiquez pas de prénoms d\'enfants, d\'adresse ni de données de santé dans votre bio publique. Le matching n\'utilise pas d\'IA. Vous pouvez supprimer votre profil à tout moment.',
  'network_publish_failed':
      'Impossible de publier le profil. Veuillez réessayer.',
  'network_publish_title': 'Publier le profil de rencontres entre enfants ?',
  'network_qr_code': 'Code QR',
  'network_qr_create_failed':
      'Impossible de créer le code QR, réessayez plus tard.',
  'network_radius': 'Dans un rayon d\'environ {distance} km',
  'network_report': 'Signaler',
  'network_requests_count': 'Demandes ({count})',
  'network_save_error': 'Erreur lors de l\'enregistrement : {error}',
  'network_say_hello': 'Dire bonjour',
  'network_scan_to_connect': 'Scannez à la rencontre – connectés aussitôt !',
  'network_search_hint': 'Rechercher…',
  'network_sending': 'Envoi…',
  'network_share_code_hint':
      'Partagez votre code – un tap et vous êtes connectés !',
  'network_share_message':
      'Hé ! 👋 Connecte-toi avec moi sur ParentPeak :\n{link}',
  'network_specials_heading': 'Particularités (facultatif)',
  'network_specials_hint':
      'Note sur les particularités (seulement sur cet appareil)',
  'network_specials_local':
      'Ces informations restent uniquement sur votre appareil. Elles ne sont pas publiées ni utilisées pour le matching backend.',
  'network_start_direct_chat': 'Écrire à un ami',
  'network_start_direct_chat_hint':
      'Choisissez un ami dans l\'onglet Réseau et démarrez la discussion.',
  'network_suggestions_count': '{count} suggestions',
  'network_tab_chats': 'Discussions',
  'network_tab_network': 'Réseau',
  'network_validation_district': 'Veuillez saisir votre quartier (étape 1)',
  'network_validation_name': 'Veuillez saisir votre nom (étape 1)',
  'network_values_custom_hint': 'Qu\'est-ce qui compte encore pour vous ?',
  'network_values_heading': 'Qu\'est-ce que vous vivez ?',
  'network_waiting_confirmation': '{name} — en attente de confirmation',
  'network_wants_to_connect': '{name} souhaite se connecter',
  'network_wide_radius': 'Dans un rayon d\'environ 1200 km',
  'network_withdraw': 'Retirer',
  'network_wizard_activities': 'Choisissez les activités qui vous plaisent :',
  'network_wizard_choose':
      'Choisissez ce qui convient le mieux, ou écrivez le vôtre :',
  'network_wizard_for_whom': 'Pour qui cherchez-vous des copains de jeu ?',
  'network_wizard_languages':
      'Toutes les langues de votre famille, y compris celles des enfants :',
  'network_wizard_location': 'Pour vous proposer des familles adaptées :',
  'network_yesterday': 'Hier',
  'network_you_label': 'Vous',
  'network_you_prefix': 'Vous :',
  'new_entry': 'Nouveau',
  'new_features': 'Nouvelles fonctions et informations',
  'new_name': 'Nouveau nom',
  'new_person': 'Nouvelle personne…',
  'no_answer': 'Non',
  'no_events_this_week':
      'Aucun rendez-vous cette semaine — place à la spontanéité !',
  'no_offers': 'Aucune offre trouvée',
  'no_reviews_yet': 'Pas encore de bilans',
  'not_available': 'Non disponible',
  'onboarding_family_name': 'Comment s\'appelle votre familleu00a0?',
  'onboarding_phase': 'À quelle étape êtes-vousu00a0?',
  'onboarding_priorities': 'Qu\'est-ce qui compte pour vousu00a0?',
  'onboarding_ready': 'C\'est partiu00a0!',
  'onboarding_subtitle':
      'Votre quotidien familial. Une appli.\nDécouvrons ensemble ce qui vous aide le plus.',
  'onboarding_where': 'Où vit votre familleu00a0?',
  'open_room': 'Ouvrir l\'espace',
  'open_source_licenses': 'Licences open source',
  'organisation_title': 'Organisation',
  'organization_add_shopping_hint':
      'Ajouter un article à la liste de courses ...',
  'organization_add_todo_hint': 'Ajouter une nouvelle tâche ...',
  'organization_category_general': 'Général',
  'organization_local_mode': 'Mode local actif',
  'organization_no_shopping_items': 'Aucun article de courses pour l\'instant.',
  'organization_no_todos': 'Aucune tâche pour l\'instant.',
  'organization_offline_notice':
      'Mode hors ligne — les modifications sont enregistrées localement et envoyées lors de la prochaine synchronisation.',
  'organization_title': 'Organisation',
  'parent_role': 'Parent',
  'password_reset_instructions':
      'Saisis ton adresse e-mail. Nous t\'enverrons un lien de réinitialisation.',
  'password_reset_send_link': 'Envoyer le lien',
  'password_reset_sent': 'E-mail envoyé ! Vérifie ta boîte de réception.',
  'password_reset_title': 'Réinitialiser le mot de passe',
  'payment_accept_agb': 'Accepter les CGU et la politique de confidentialité',
  'payment_accept_terms': 'Merci d\'accepter les conditions',
  'payment_complete': 'Finaliser le paiement',
  'payment_link_failed': 'Impossible d\'ouvrir le lien.',
  'payment_publish_fee': 'Frais de publication',
  'payment_success': 'Paiement réussi !',
  'payment_view_agb': 'Voir les CGU',
  'payment_view_privacy': 'Voir la politique de confidentialité',
  'person': 'Personne',
  'phase_multiselect':
      'Sélection multiple possible — nous adaptons le contenu.',
  'planner_capture_moment': 'Capturer un moment en famille',
  'planner_import': 'Importer',
  'planner_moment_saved': 'Moment en famille enregistré.',
  'planner_no_moments':
      'Aucun moment en famille enregistré pour l\'instant. Capturez aujourd\'hui votre premier temps fort.',
  'planner_no_weekday':
      'Aucun jour de la semaine valide détecté. Vérifie le format.',
  'planner_title': 'Planificateur de repas Pro',
  'planner_tone_clear': 'Ton : clair',
  'planner_tone_premium': 'Ton : calme premium',
  'planner_tone_warm': 'Ton : chaleureux',
  'planner_update_pantry': 'Mettre à jour le garde-manger',
  'product_updates': 'Mises à jour du produit',
  'profile_account_failed':
      'Impossible de charger ou d\'enregistrer les données du compte. Réessaie ; les données existantes sont conservées.',
  'profile_account_retry': 'Réessayer',
  'profile_ai_notice': 'Note sur l\'utilisation de l\'IA',
  'profile_blocked_contacts': 'Contacts bloqués',
  'profile_choose_language': 'Choisir la langue',
  'profile_claim_confirm': 'Associer à mon compte',
  'profile_claim_explanation':
      'Confirme uniquement si ces données locales précédentes t\'appartiennent. Elles seront associées uniquement au compte actuellement connecté. Aucune donnée n\'est publiée ni téléversée. Les données existantes du compte ne sont pas écrasées.',
  'profile_claim_title': 'Associer les données locales ?',
  'profile_confirm': 'Confirmer',
  'profile_confirm_delete':
      'Saisissez «u00a0SUPPRIMERu00a0» pour confirmeru00a0:',
  'profile_confirm_login': 'Confirmer la connexion',
  'profile_delete_final': 'Supprimer définitivement',
  'profile_export_sign_in_required':
      'Connectez-vous pour exporter vos données.',
  'profile_important_info': 'Bon à savoiru00a0:',
  'profile_imprint': 'Mentions légales',
  'profile_legacy_children': 'Ancienne liste d\'enfants locale',
  'profile_legacy_location': 'Ancienne localisation locale',
  'profile_legacy_onboarding': 'Ancienne configuration locale',
  'profile_legacy_unassigned':
      'Données locales anciennes non associées. Jamais reprises automatiquement.',
  'profile_legal_info': 'Informations selon § 5 TMG / § 25 MStV',
  'profile_logout_title': 'Se déconnecteru00a0?',
  'profile_no_blocked': 'Aucun contact bloqué',
  'profile_sync_failed':
      'Configuration enregistrée localement. La synchronisation du compte a échoué ; réessaie plus tard.',
  'profile_unblock': 'Débloquer',
  'public_holiday': 'Jour férié',
  'publish_event': 'Publier l\'événement',
  'quick_activity_empty': 'Aucune activité dans cette catégorie',
  'quick_activity_idea': 'Une idée pour vous',
  'quick_activity_needs': 'Ce qu\'il vous faut',
  'quick_activity_title': 'Que faisons-nous aujourd\'hui ?',
  'recipe_ai_consent_accept': 'D\'accord, utiliser les recettes par IA',
  'recipe_ai_consent_body':
      'Pour les recettes par IA, l\'âge de l\'enfant ainsi que les informations sur les allergies de vos dossiers enfant locaux et de vos réglages de cuisine sont envoyés via notre backend au service d\'IA (Google Gemini). Lors d\'une recherche de plat, votre texte de recherche est aussi transmis. Les noms, données médecin et d\'urgence des dossiers ne sont pas transmis automatiquement. Sans consentement, l\'inspiration de recettes reste locale ; aucune requête IA n\'est envoyée.',
  'recipe_ai_consent_failed':
      'Le consentement n\'a pas pu être enregistré en toute sécurité. L\'IA reste désactivée.',
  'recipe_ai_consent_title': 'Créer des recettes de famille avec l\'IA',
  'recipe_ai_local_notice':
      'Inspiration de recettes locale : aucune donnée n\'a été envoyée à l\'IA.',
  'recipe_ai_request_failed':
      'Impossible de lancer la création de la recette. Veuillez réessayer.',
  'recipe_generate': 'Nouvelle recette',
  'recipe_ingredients': 'Ingrédients',
  'recipe_steps': 'Préparation',
  'region': 'Région',
  'register_accept_terms_required':
      'Veuillez accepter les conditions d\'utilisation.',
  'register_already_registered': 'Déjà inscrit·e ? ',
  'register_back_to_login': 'Retour à la connexion',
  'register_beta_description':
      'Après le lancement officiel : 1 mois d\'essai gratuit.',
  'register_beta_title': 'Actuellement gratuit en bêta',
  'register_display_name_helper':
      'C\'est ainsi que les autres parents vous voient.',
  'register_display_name_label':
      'Votre nom affiché (p. ex. Anna ou Famille Martin)',
  'register_display_name_required': 'Le nom est requis.',
  'register_failed': 'L\'inscription a échoué. Veuillez réessayer.',
  'register_login_link': 'Se connecter',
  'register_password_confirm_label': 'Confirmer le mot de passe',
  'register_password_hint_length': 'Au moins 8 caractères',
  'register_password_hint_number': 'Au moins un chiffre (0–9)',
  'register_password_hint_uppercase': 'Au moins une majuscule (A–Z)',
  'register_password_min_length': 'Au moins 8 caractères.',
  'register_password_mismatch': 'Les mots de passe ne correspondent pas.',
  'register_password_number': 'Au moins un chiffre.',
  'register_password_requirements': 'Exigences du mot de passe',
  'register_password_uppercase': 'Au moins une majuscule.',
  'register_submit': 'Commencer gratuitement',
  'register_subtitle': 'Prêt pour votre quotidien familial en 2 minutes.',
  'register_technical_error':
      'Erreur technique lors de l\'inscription. Veuillez réessayer.',
  'register_terms_and': ' et ',
  'register_terms_prefix': 'J\'accepte les ',
  'register_terms_suffix': ' de Parentpeak.',
  'register_title': 'Créer un compte',
  'register_url_not_configured': 'URL pas encore configurée.',
  'reload': 'Recharger',
  'reminders': 'Rappels',
  'remove_action': 'Retirer',
  'remove_member': 'Retirer le membre ?',
  'report_action': 'Signaler',
  'report_offer': 'Signaler l\'offre',
  'report_profile': 'Signaler le profil',
  'reset': 'Réinitialiser',
  'reset_filter': 'Réinitialiser le filtre',
  'review_delete': 'Supprimer',
  'review_delete_confirm': 'Ce bilan sera définitivement supprimé.',
  'review_delete_title': 'Supprimer {week} ?',
  'review_fill_again': 'Remplir à nouveau',
  'review_next_week': 'De quoi te réjouis-tu la semaine prochaine ?',
  'review_no_reviews': 'Aucun bilan pour l\'instant',
  'review_talk_to_ai': 'Parler de ma semaine avec l\'IA',
  'ritualRuheTileSubtitle': 'Un moment de calme pour votre quotidien familial',
  'ritualRuheTitle': 'Rituel & calme',
  'ritual_add': 'Ajouter',
  'ritual_add_step': 'Ajouter une étape',
  'ritual_afternoon': 'Après-midi',
  'ritual_age_growing': '5–7 ans : image + courte phrase',
  'ritual_age_notice':
      '{name} a maintenant {age} ans — souhaitez-vous adapter les rituels ensemble ?',
  'ritual_age_older': '10–14 ans : auto-organisation et réflexion',
  'ritual_age_school': '6–10 ans : agenda du jour',
  'ritual_age_young': '2–5 ans : cartes images et mouvement',
  'ritual_all_done': 'Pour aujourd\'hui, c\'est suffisant. Place au calme.',
  'ritual_cancel': 'Annuler',
  'ritual_card_subtitle':
      'Rien ne doit être parfait. Prenez ce qui convient aujourd\'hui.',
  'ritual_child': 'Votre enfant',
  'ritual_close': 'Fermer',
  'ritual_done': 'Terminé',
  'ritual_edit': 'Modifier',
  'ritual_edit_title': 'Modifier {title}',
  'ritual_empty_action': 'Vers le profil familial',
  'ritual_empty_description':
      'Dès qu\'un profil enfant est créé, ParentPeak peut accompagner les rituels de façon adaptée à l\'âge.',
  'ritual_empty_title': 'Pas encore de profil enfant',
  'ritual_evening': 'Bonne nuit',
  'ritual_fallback_name_afternoon': 'Arriver l\'après-midi',
  'ritual_fallback_name_morning': 'Matin tout en douceur',
  'ritual_fallback_story':
      'Le soir, quand {name} regardait par la fenêtre, une petite étoile scintillait. Elle rappelait que chaque jour a de bons moments : un sourire et un foyer où l\'on peut simplement être soi. Le vent murmurait : pour aujourd\'hui, c\'est suffisant. Puis tout devint calme et paisible.',
  'ritual_gratitude_hint': 'Aujourd\'hui, c\'était bien que…',
  'ritual_gratitude_placeholder': 'Une petite phrase suffit',
  'ritual_gratitude_title': 'Un bon moment',
  'ritual_morning': 'Bonjour',
  'ritual_name': 'Nom du rituel',
  'ritual_night_title': 'Votre moment du soir',
  'ritual_quiet_mode': 'Mode calme',
  'ritual_reminder_body':
      'Petit rappel pour « {name} ». Accordez-vous un moment de calme.',
  'ritual_reminder_title': 'C\'est l\'heure de votre rituel 🌙',
  'ritual_remove_step': 'Supprimer l\'étape',
  'ritual_save': 'Enregistrer',
  'ritual_section_evening': 'Soir',
  'ritual_section_morning': 'Matin',
  'ritual_step': 'Étape',
  'ritual_step_arrive_sub': 'Enlever les chaussures et d\'abord se poser',
  'ritual_step_arrive_title': 'Arriver',
  'ritual_step_breakfast_sub': 'Commencer la journée ensemble',
  'ritual_step_breakfast_title': 'Petit-déjeuner',
  'ritual_step_close_sub': 'Que peut-on laisser aller pour aujourd\'hui ?',
  'ritual_step_close_title': 'Clore la journée',
  'ritual_step_cuddle_sub': 'Encore un moment tendre',
  'ritual_step_cuddle_title': 'Câlins',
  'ritual_step_daymoment_sub': 'Qu\'est-ce qui était bien aujourd\'hui ?',
  'ritual_step_daymoment_title': 'Moment de la journée',
  'ritual_step_dress_sub': 'Trouver quelque chose de confortable',
  'ritual_step_dress_title': 'S\'habiller',
  'ritual_step_free_sub': 'Qu\'est-ce qui vous fait du bien maintenant ?',
  'ritual_step_free_title': 'Temps libre',
  'ritual_step_goodmoment_sub': 'Une phrase pour vous-même',
  'ritual_step_goodmoment_title': 'Un bon moment',
  'ritual_step_morning_sub': 'Arriver tout doucement',
  'ritual_step_morning_title': 'Bonjour',
  'ritual_step_pause_breathe_sub': 'D\'abord, respirer un bon coup',
  'ritual_step_pause_relax_sub': 'Boire, grignoter, se détendre',
  'ritual_step_pause_short_title': 'Pause',
  'ritual_step_pause_sub': 'Boire un peu et respirer',
  'ritual_step_pause_title': 'Petite pause',
  'ritual_step_prep_bag_sub': 'Préparer le sac et les vêtements',
  'ritual_step_prep_clothes_sub': 'Préparer les vêtements préférés',
  'ritual_step_prep_full_sub': 'Sac, vêtements et réveil',
  'ritual_step_prep_tomorrow_title': 'Préparer pour demain',
  'ritual_step_ready_sub': 'De quoi avons-nous besoin aujourd\'hui ?',
  'ritual_step_ready_title': 'Prêts pour la journée',
  'ritual_step_story_sub': 'Une histoire tranquille vous attend',
  'ritual_step_story_title': 'Choisir une histoire',
  'ritual_step_subtitle': 'Courte phrase',
  'ritual_step_teeth_calm_sub': 'Terminer tranquillement',
  'ritual_step_teeth_circles_sub': 'De petits cercles, tout en douceur',
  'ritual_step_teeth_night_sub': 'La bouche reçoit ses soins du soir',
  'ritual_step_teeth_title': 'Se brosser les dents',
  'ritual_step_tidy_sub': 'Un petit geste pour demain',
  'ritual_step_tidy_title': 'Un peu de rangement',
  'ritual_step_title': 'Titre',
  'ritual_step_wash_calm_sub': 'Le visage et les mains s\'apaisent',
  'ritual_step_wash_cozy_sub': 'Devenir frais et douillet',
  'ritual_step_wash_title': 'Se laver',
  'ritual_story_generate': 'Raconter une histoire',
  'ritual_story_hint': 'Une histoire tranquille pour {name}.',
  'ritual_story_new': 'Nouvelle histoire',
  'ritual_story_title': 'Une histoire pour aujourd\'hui',
  'ritual_suggestion': 'Suggestion pour {age} ans, {section}',
  'ritual_time': 'Heure',
  'ritual_timer': 'Minuteur tranquille',
  'ritual_timer_hint': '0 = sans minuteur',
  'ritual_timer_seconds': 'Minuteur en secondes',
  'ritual_timer_start': 'Démarrer un minuteur tranquille',
  'ritual_weekdays': 'Lu|Ma|Me|Je|Ve|Sa|Di',
  'ritual_welcome_child': '{section} avec {name}',
  'ritual_welcome_night': 'Le moment de se détendre',
  'ritual_welcome_question':
      'Qu\'est-ce qui vous ferait du bien aujourd\'hui ?',
  'ritual_welcome_relaxed': 'Un petit pas tranquille après l\'autre.',
  'ritual_your_section': 'Votre {section}',
  'safety_check': 'Vérification de sécurité',
  'safety_guide_emergency': 'En cas d\'urgence',
  'safety_guide_priority': 'Ta sécurité est notre priorité !',
  'safety_guide_title': 'Guide de sécurité',
  'safety_guide_understand': 'Je comprends ces consignes',
  'satt_add': 'Ajouter',
  'satt_choose_emoji': 'Choisir un emoji',
  'satt_difficulty': 'Difficulté',
  'satt_hide': 'Masquer',
  'satt_hide_from_feed': 'Masquer du fil',
  'satt_hide_offer': 'Masquer l\'offre ?',
  'satt_ingredients': 'Ingrédients (un par ligne)',
  'satt_parent_hints': 'Conseils pour les parents',
  'satt_preparation_steps':
      'Préparation (étape par étape, une ligne par étape)',
  'satt_recipe_name': 'Nom de la recette',
  'satt_report': 'Signaler',
  'satt_report_offer': 'Signaler l\'offre',
  'satt_servings': 'Portions',
  'satt_share_hint': 'Partagez votre recette préférée avec d\'autres parents',
  'satt_share_recipe': 'Partager la recette 📖',
  'satt_short_description': 'Courte description',
  'satt_time_min': 'Temps (min)',
  'save_share_title': 'Économiser et partager',
  'school_holiday': 'Vacances scolaires',
  'security': 'Sécurité',
  'select_language': 'Choisir la langue',
  'send_anyway': 'Envoyer quand même',
  'share_recipe': 'Partager la recette',
  'signed_backups': 'Sauvegardes signées',
  'snack': 'Goûter',
  'soon': 'Bientôt',
  'status_done': 'Terminé',
  'status_full': 'Complet',
  'status_open': 'Ouvert',
  'sync_failed': 'Échec de la synchronisation avec le serveur',
  'table_moment_delete_message':
      'Ce moment sera définitivement retiré de votre coffre à trésors.',
  'table_moment_delete_title': 'Supprimer le moment ?',
  'table_moment_empty': 'Votre coffre à trésors est encore vide.',
  'table_moment_empty_hint': 'Capturez ce soir votre premier moment partagé.',
  'table_moment_for_whom': 'Pour qui ?',
  'table_moment_how_was_it': 'Comment était ce moment ?',
  'table_moment_local_only': 'Reste uniquement sur cet appareil',
  'table_moment_new': 'Capturer un nouveau moment',
  'table_moment_note_hint': 'p. ex. « Nous avons fait des crêpes ensemble. »',
  'table_moment_note_label': 'Une phrase à ce sujet (facultatif)',
  'table_moment_save': 'Enregistrer le moment',
  'table_moment_saved': 'Gardé dans votre coffre à trésors. 🕯️',
  'table_moment_select_feeling':
      'Choisis un symbole en forme de cœur pour capturer votre moment.',
  'table_moment_title': 'Notre moment à table',
  'table_moment_treasure': 'Coffre à trésors',
  'table_moment_whole_family': 'Toute la famille',
  'table_moment_yours': 'Vos moments',
  'talk_ai_week': 'Parler de ma semaine avec l\'IA',
  'tips_title': 'Conseils et savoir',
  'tooltip_accept': 'Accepter',
  'tooltip_ai_memory': 'Mémoire de l\'IA',
  'tooltip_change_country': 'Changer de pays',
  'tooltip_copy': 'Copier',
  'tooltip_delete_chat': 'Supprimer le chat',
  'tooltip_options': 'Options',
  'tooltip_recheck': 'Vérifier à nouveau',
  'tooltip_reject': 'Refuser',
  'tooltip_reload': 'Recharger',
  'tooltip_remove': 'Retirer',
  'tooltip_remove_contact': 'Retirer le contact',
  'tooltip_save_pdf': 'Enregistrer en PDF',
  'tooltip_saved_recipes': 'Recettes enregistrées',
  'tooltip_search': 'Rechercher',
  'tooltip_share_list': 'Partager la liste',
  'tooltip_share_overview': 'Partager l\'aperçu',
  'tooltip_shopping_list': 'Liste de courses',
  'tooltip_sync': 'Synchroniser',
  'tooltip_tone': 'Style d\'écriture',
  'tooltip_topic_analysis': 'Analyse des thèmes',
  'treasureAddMorePhotos': 'Plus de photos',
  'treasureAiAccept': 'Utiliser la suggestion',
  'treasureAiHelper': 'On te suggère tout de suite la catégorie et la couleur.',
  'treasureAiTitle': 'Reconnu en un clin d\'œil',
  'treasureBlockAction': 'Masquer',
  'treasureBlockSuccess': 'L\'annonce a été masquée de ton fil.',
  'treasureBlockText':
      'Cette annonce est masquée localement et n\'apparaît plus dans le fil.',
  'treasureBlockTitle': 'Masquer l\'annonce ?',
  'treasureCancelReservation': 'Annuler la réservation',
  'treasureCategoryBooks': 'Livres',
  'treasureCategoryClothing': 'Vêtements',
  'treasureCategoryEquipment': 'Équipement',
  'treasureCategoryLabel': 'Catégorie',
  'treasureCategoryOther': 'Autre',
  'treasureCategoryToys': 'Jouets',
  'treasureCategoryVehicles': 'Véhicules',
  'treasureChooseFromLibrary': 'Depuis la galerie',
  'treasureCoffeeSlotHint':
      'Choisissez un horaire qui convient aux deux familles.',
  'treasureColorLabel': 'Couleur',
  'treasureColorLine': 'Couleur : {color}',
  'treasureColorPlaceholder': 'p. ex. rouge, sauge, bois naturel',
  'treasureCompleteHandover': 'Marquer comme remis',
  'treasureConditionGood': 'Bien utilisé',
  'treasureConditionGoodHint':
      'Visiblement utilisé, tout à fait prêt à servir.',
  'treasureConditionHelper': 'L\'honnêteté, c\'est parfait.',
  'treasureConditionLabel': 'État',
  'treasureConditionLikeNew': 'Comme neuf',
  'treasureConditionLikeNewHint': 'Très bien entretenu, presque comme neuf.',
  'treasureConditionLine': '',
  'treasureConditionRaider': 'Avec des traces',
  'treasureConditionRaiderHint':
      'Avec des traces d\'usage, mais prêt pour la prochaine aventure.',
  'treasureConfirmHandover': 'Confirmer la remise',
  'treasureContactlessHint': 'Sans contact possible',
  'treasureContactlessPointLabel': 'Point de récupération',
  'treasureCoverPhotoLabel': 'Couverture',
  'treasureCurrentRadius': 'Rayon de recherche actuel : {radius}',
  'treasureDateOrSwap': 'Rencontre rapide ou échange discret',
  'treasureDefaultColor': 'Rouge',
  'treasureDefaultSizeAge': '2-4 ans',
  'treasureDefaultTitle': 'Draisienne rouge',
  'treasureDeleteAction': 'Supprimer l\'annonce',
  'treasureDeleteFailed': 'Impossible de supprimer l\'annonce.',
  'treasureDeleteSuccess': 'Votre annonce a été supprimée.',
  'treasureDeleteText':
      'L\'annonce sera retirée définitivement. Les réservations existantes seront annulées.',
  'treasureDeleteTitle': 'Supprimer l\'annonce ?',
  'treasureDetailSectionAbout': 'En un coup d\'œil',
  'treasureDetailSectionPickup': 'Récupération et remise',
  'treasureDetailSelectedHint':
      'Ce trésor est actuellement réservé pour ta remise.',
  'treasureDiscard': 'Abandonner',
  'treasureDiscardDraftText':
      'L\'état actuel de ton formulaire et le brouillon enregistré localement seront supprimés.',
  'treasureDiscardDraftTitle': 'Abandonner le brouillon ?',
  'treasureDiscoveryInvite':
      'Invitez des amis ou partagez vos propres offres pour qu\'il y ait plus de trésors près de chez vous.',
  'treasureDiscoveryScopeInvite':
      'Portée actuelle : {radius}. Invitez des amis pour trouver plus de trésors près de chez vous.',
  'treasureDistanceApproximate': 'À environ {distance}',
  'treasureDistanceAway': 'à {distance}',
  'treasureDistanceNearby': 'Près de chez vous',
  'treasureDistanceUnknown': 'Distance inconnue',
  'treasureDraftDiscarded': 'Brouillon abandonné.',
  'treasureDraftRestored': 'Votre dernier brouillon est de retour.',
  'treasureDraftSaved':
      'Brouillon enregistré. Vous pourrez continuer plus tard.',
  'treasureDropKitaLocker': 'Vestiaire de la crèche (casier « Mouette »)',
  'treasureDropMailbox': 'Boîte aux lettres à l\'entrée',
  'treasureDropPointHint':
      'Choisissez un point de retrait sans contact qui vous semble sûr.',
  'treasureDropRetterBox': 'Boîte de dépôt devant la porte',
  'treasureFamilyNoteTitle': 'Mot de la famille',
  'treasureFeedEmptyText':
      'Commence simplement par le premier objet que ta famille est prête à transmettre.',
  'treasureFeedEmptyTitle': 'Pas encore de trésors près de chez toi',
  'treasureFeedSubtitle': 'Local, honnête, tout de suite compréhensible',
  'treasureFeedTitle': 'Trésors près de chez toi',
  'treasureFilterAll': 'Tous',
  'treasureFilterDistance250': 'Jusqu\'à 250 m',
  'treasureFilterDistance500': 'Jusqu\'à 500 m',
  'treasureFilterDistanceAll': 'Toute distance',
  'treasureFreshToday': 'Nouveau aujourd\'hui',
  'treasureGlobalMode': 'Vue : mode numérique global',
  'treasureGuidelineCommunity':
      'Ça rend le partage dans le quartier tout simple.',
  'treasureGuidelineHonest':
      'Partager honnêtement plutôt que de viser la perfection.',
  'treasureGuidelineNoPressure': 'Les traces d\'usage sont tout à fait okay.',
  'treasureGuidelineTempo':
      'C\'est vous qui décidez : rencontre rapide ou échange discret.',
  'treasureHandoverCoffeeMode': 'Rencontre rapide',
  'treasureHandoverCoffeeModeText':
      'Un petit bonjour, on se remet l\'objet, c\'est fait.',
  'treasureHandoverFlyingSwap': 'Échange discret',
  'treasureHandoverFlyingSwapText':
      'Récupération sans contact quand ça t\'arrange.',
  'treasureHandoverQuestion': 'Comment voulez-vous faire la remise ?',
  'treasureHandoverUpdateFailed': 'Impossible de mettre à jour la remise.',
  'treasureHandoverUpdated': 'La remise a été mise à jour.',
  'treasureHoursAgoShort': 'il y a {count} h',
  'treasureImageUploadFailed':
      'L\'envoi de l\'image a échoué. Réessaie, s\'il te plaît.',
  'treasureInsertNoteSuggestion': 'Insérer une suggestion de texte',
  'treasureJustListed': 'Vient d\'être publié',
  'treasureLegalNotice':
      'Mention légale : dans le marché du don, Parentpeak n\'est qu\'un intermédiaire. L\'état, la sécurité et la remise des articles relèvent exclusivement de la responsabilité des utilisateurs concernés.',
  'treasureListedAgoLine': 'Publié : {time}',
  'treasureLoadingHint':
      'On charge en ce moment les annonces qui te correspondent près de chez toi.',
  'treasureMinutesAgoShort': 'il y a {count} min',
  'treasureMyListings': 'Mes annonces',
  'treasureMyListingsEmpty': 'Vous n\'avez encore ni annonces ni réservations.',
  'treasureNetworkError':
      'La connexion a été interrompue. Réessaie dans un instant.',
  'treasureNeutralColor': 'Neutre',
  'treasureNoResultsText':
      'Essaie une plus grande distance ou reviens voir plus tard.',
  'treasureNoResultsTitle': 'Rien qui convienne pour le moment',
  'treasureNoteEditable': 'Note insérée. Vous pouvez la modifier.',
  'treasureNoteSuggestion':
      '{title}, {sizeAge}. Vous pouvez ajouter ici d\'autres informations sur la remise.',
  'treasureNoteSuggestionHint':
      'Insère un modèle de texte modifiable et remplace la note actuelle. Pas d\'enregistrement vocal.',
  'treasureOpenGallery': 'Ouvrir la galerie',
  'treasureOptionalNoteHelper':
      'Une phrase honnête aide tout de suite les familles proches.',
  'treasureOptionalNoteLabel': 'Petite note',
  'treasureOptionalNotePlaceholder': 'p. ex. taille 92, taille un peu petit.',
  'treasurePhotoAnalyzing': 'La photo est en cours d\'analyse…',
  'treasurePhotoCount': '{count} photos',
  'treasurePhotoGalleryHint':
      'Choisis une image de couverture ou retire les extras.',
  'treasurePhotoMissing':
      'Ajoute d\'abord une photo pour que les familles voient tout de suite de quoi il s\'agit.',
  'treasurePhotoReady': 'Photo prête',
  'treasurePhotoSectionHint':
      'Montre l\'objet simplement tel qu\'il est en ce moment.',
  'treasurePickupAreaLine': '',
  'treasurePickupLocationHint':
      'Ton emplacement détermine quelles familles voient ton annonce.',
  'treasurePickupLocationTitle': 'Zone de récupération',
  'treasurePreviewNoteLabel': 'Mot de la famille',
  'treasurePreviewTitle': 'Aperçu du fil',
  'treasurePublishNow': 'Partager maintenant',
  'treasureRatingLine': '',
  'treasureReportAction': 'Signaler',
  'treasureReportLocalOnly':
      'Signalement marqué localement. La synchronisation serveur suivra dès que possible.',
  'treasureReportNoteHint': 'Facultatif : petite note pour la modération',
  'treasureReportReason_false_info': 'Informations erronées',
  'treasureReportReason_hostile': 'Comportement hostile',
  'treasureReportReason_inappropriate': 'Contenu inapproprié',
  'treasureReportReason_other': 'Autre',
  'treasureReportSubmit': 'Signaler',
  'treasureReportSuccess': 'Merci, nous vérifions ce signalement.',
  'treasureReportTitle': 'Signaler l\'annonce',
  'treasureReportedFlag': 'Signalé',
  'treasureReservationConfirmed': 'Remise confirmée',
  'treasureReservationOpen': 'Réservation en attente',
  'treasureReservationSuccessDetail':
      '✅ {title} est réservé pour vous ! {detailType} : {detail}. La famille qui offre est prévenue.',
  'treasureReservations': 'Réservations',
  'treasureReserveAndPickup': 'Voir et réserver',
  'treasureReserveCoffeeMode': 'Fixer la rencontre',
  'treasureReserveFlyingSwap': 'Réserver l\'échange discret',
  'treasureReserveTitle': 'Planifier la remise',
  'treasureReserved': 'Réservé ✓',
  'treasureReservedByYou': 'Réservé par vous',
  'treasureSaveDraft': 'Enregistrer le brouillon',
  'treasureSelectForHandover': 'Choisir pour la remise',
  'treasureSelectedForHandover': 'Réservé',
  'treasureSelectionConfirmed':
      '{title} est maintenant réservé pour ta remise.',
  'treasureShareRadiusHelper':
      'Déterminez dans quel rayon les familles voient votre offre. Le calcul utilise des localisations grossièrement arrondies et n\'est qu\'approximatif ; au maximum 25 km.',
  'treasureShareRadiusKm': 'Rayon d\'environ {radius} km',
  'treasureShareRadiusLabel': 'Rayon de publication',
  'treasureSizeAgeLabel': 'Taille ou âge',
  'treasureSizeAgeLine': '',
  'treasureSizeAgePlaceholder': 'p. ex. taille 92 ou âge 2 à 3 ans',
  'treasureSlotMonday': 'Lundi, 17h30 – 18h15',
  'treasureSlotSunday': 'Dimanche, 10h00 – 11h30',
  'treasureSlotTuesday': 'Mardi, 08h15 – 08h45',
  'treasureSyncHintFallback':
      'La synchro en direct est un peu limitée en ce moment. Tire vers le bas pour actualiser.',
  'treasureTakePhoto': 'Prendre une photo',
  'treasureTileSubtitle': 'Donner, échanger, relier les parents',
  'treasureTileTitle': 'Marché du don',
  'treasureTimeWindowLabel': 'Horaires disponibles',
  'treasureTitleLabel': 'Titre',
  'treasureTitlePlaceholder': 'p. ex. draisienne rouge',
  'treasureUploadHeadline':
      'Partage ce dont vous n\'avez plus besoin chez vous',
  'treasureUploadSubline': 'Une photo, un petit check, c\'est fait',
  'treasureUploadSubtitle': 'Une photo suffit pour commencer',
  'treasureUploadSuccess': 'Votre trésor est maintenant visible.',
  'treasureUploadTitle': 'Partager un trésor',
  'treasureViewsLine': '',
  'treasure_account_changed': 'Le compte a changé. Veuillez fermer cette vue.',
  'treasure_cancel_local_failed':
      'Le serveur a confirmé l\'annulation, mais la marque locale n\'a pas pu être retirée. Elle peut encore s\'afficher de façon obsolète.',
  'treasure_created_archived':
      'Votre annonce a été enregistrée, mais archivée par le serveur. Elle n\'est pas disponible dans le marché. Vérifiez « Mes annonces ».',
  'treasure_created_local_failed':
      'Le serveur a enregistré l\'annonce, mais pas confirmée comme disponible. Le suivi local a échoué ; les photos sont conservées. Vérifiez « Mes annonces » avant de réessayer.',
  'treasure_created_not_available':
      'Votre annonce a été enregistrée, mais pas confirmée comme disponible. Vérifiez « Mes annonces ».',
  'treasure_draft_images_missing':
      'Les textes du brouillon ont été chargés, mais les photos précédentes ne sont plus disponibles. Veuillez les rajouter.',
  'treasure_legacy_body':
      'Les brouillons locaux, marques de réservation et de sécurité n\'appartiennent encore à aucun compte. Après connexion, vous pouvez en confirmer la propriété.',
  'treasure_legacy_claim': 'Confirmer la propriété',
  'treasure_legacy_confirm':
      'Confirmez-vous que ces données vous appartiennent ? Elles seront associées à ce compte. Un brouillon de compte existant est prioritaire. Les données d\'origine sont conservées ; rien n\'est publié.',
  'treasure_legacy_title': 'Données locales non attribuées',
  'treasure_location_required':
      'Une localisation est nécessaire pour les offres près de chez vous.',
  'treasure_market_unavailable':
      'Le marché du don n\'est pas disponible pour le moment. Votre offre n\'a pas été publiée.',
  'treasure_photo_analysis_failed':
      'L\'analyse de la photo n\'a pas pu être terminée. La photo et les saisies manuelles sont conservées.',
  'treasure_photo_consent_accept': 'Accepter et analyser la photo',
  'treasure_photo_consent_body':
      'Pour des suggestions sur votre objet, cette photo est envoyée via le backend ParentPeak à Google Gemini. Le contenu de l\'image n\'est pas anonymisé. N\'utilisez que des photos d\'objets sans personnes, documents privés ni adresses reconnaissables. L\'analyse est facultative ; sans consentement, vous pouvez conserver la photo et remplir l\'annonce manuellement. Ce consentement vaut seulement pour l\'IA photo du marché du don et est enregistré pour ce compte. Il ne publie ni la photo ni l\'annonce.',
  'treasure_photo_consent_failed':
      'Impossible d\'enregistrer le consentement. Aucune photo n\'a été envoyée à l\'IA.',
  'treasure_photo_consent_title': 'Analyser la photo avec l\'IA ?',
  'treasure_photos_public_info':
      'À la publication, les photos sont téléversées publiquement. Même en cas d\'erreur ensuite, elles peuvent rester accessibles. Ne montrez pas de personnes, de documents privés ni d\'adresses.',
  'treasure_publish_unavailable':
      'Pour publier, il faut un compte connecté et un serveur du marché disponible. Aucune photo n\'a été téléversée.',
  'treasure_publish_uncertain':
      'La création n\'a pas pu être confirmée. Les photos téléversées peuvent être accessibles publiquement. Vérifiez « Mes annonces » avant de réessayer.',
  'treasure_published_local_failed':
      'Le serveur a créé l\'annonce, mais les données locales n\'ont pas pu être mises à jour. Vérifiez « Mes annonces » ; ne republiez pas.',
  'treasure_reservation_offline':
      'Sans connexion au serveur du marché, rien n\'a été réservé. Réessayez en ligne.',
  'treasure_reserve_local_failed':
      'Le serveur a confirmé la réservation, mais la marque locale n\'a pas pu être enregistrée. Vérifiez « Mes annonces » avant de réserver à nouveau.',
  'treasure_signin_required':
      'Connectez-vous pour effectuer cette action dans le marché du don.',
  'treasure_storage_failed':
      'Impossible de charger ou d\'enregistrer les données du marché. Veuillez réessayer.',
  'treasure_upload_batch_failed':
      'Toutes les photos n\'ont pas pu être téléversées. Les photos téléversées ont été retirées ; aucune annonce n\'a été envoyée.',
  'treasure_upload_cleanup_failed':
      'Le téléversement des photos a échoué. Aucune annonce n\'a été envoyée, mais certaines photos téléversées n\'ont pas pu être retirées et peuvent rester accessibles publiquement.',
  'uexam_window_j1': '12e–14e année',
  'uexam_window_j2': '16e–17e année',
  'uexam_window_u1': 'juste après la naissance',
  'uexam_window_u2': '3e–10e jour de vie',
  'uexam_window_u3': '4e–5e semaine',
  'uexam_window_u4': '3e–4e mois',
  'uexam_window_u5': '6e–7e mois',
  'uexam_window_u6': '10e–12e mois',
  'uexam_window_u7': '21e–24e mois',
  'uexam_window_u7a': '34e–36e mois',
  'uexam_window_u8': '46e–48e mois',
  'uexam_window_u9': '60e–64e mois',
  'used_for_greeting': 'Utilisé pour l\'accueil et dans le réseau.',
  'view_it': 'Voir →',
  'weekly_kita_imported': '{count} entrées de crèche importées.',
  'weekly_review': 'Bilan de la semaine',
  'welcome_title': 'Bienvenue sur\nParentpeak',
  'what_concerns_you': 'Qu\'est-ce qui te préoccupe ?',
  'what_did_you_learn': 'Qu\'est-ce que tu en as appris ?',
  'what_was_challenging': 'Qu\'est-ce qui a été difficile ?',
  'what_went_well': 'Qu\'est-ce qui s\'est bien passé ?',
  'where_family_lives': 'Où vit votre famille ?',
  'your_code': 'Ton code :',
  'your_link': 'Ton lien :',
  'your_weekly_review': 'Ton bilan de la semaine',
};
