// It Übersetzungen (Kern + Tiefe). Entwurf; Fachtexte (Finanzen) und
// bei RTL das Layout vor breiter Vermarktung von Muttersprachlern prüfen.
// Platzhalter wie {count}, {name} bleiben exakt erhalten.
const appLocalizationsItExtra = <String, String>{
  'chat_ask_none':
      'Non porre domande di approfondimento; le informazioni bastano per passi concreti.',
  'chat_ask_one':
      'Poni alla fine esattamente UNA domanda breve e aperta per il prossimo passo utile.',
  'chat_boundary_retry':
      'Non rispondere con una formula di confine generica, ma in modo concreto, empatico e orientato alle soluzioni per la vita quotidiana dei genitori.',
  'chat_coaching_prompt':
      'Richiesta del genitore:\n{message}\n\nAtteggiamento: empatico, caldo, senza giudizio secondo la CNV, Hüther e Juul. Lente di Hüther: legame o autonomia? La relazione prima della pressione, l\'esempio invece della predica, l\'entusiasmo per l\'apprendimento; i genitori stanno accanto al bambino invece di risolvere tutti gli ostacoli.\nFormato: prima 1-2 frasi empatiche; i sentimenti/bisogni solo come ipotesi. Una breve lettura orientata allo sviluppo e all\'attaccamento, esattamente UN passo di CNV, 1-2 piccole opzioni in forma di proposta. {followUp}\nFocus: {focus}\nAltre prospettive pedagogiche solo in modo OPZIONALE quando pertinenti, senza lezioni teoriche.\nNiente prediche, frasi fatte, giudizi affrettati o «Devi». Traduci con empatia i rimproveri verso se stessi in sentimento/bisogno. Mantieni le indicazioni concrete di età, momento della giornata e situazione. Paragrafi brevi, al massimo 3-4 frasi; niente asterischi/Markdown, tono calmo e professionale, 0-2 emoji, elenchi semplici ammessi. {continuation}\nAncora di contesto: {context}\nContesto della cronologia: {history}',
  'chat_context_retry':
      'Rispondi di nuovo e riprendi in modo visibile queste informazioni importanti: {context}. Resta empatico, concreto e vicino alla quotidianità.',
  'chat_continue_context':
      'Collegati ai modelli rilevanti e alle indicazioni di età della cronologia selezionata; non inventare nomi reali.',
  'chat_focus_anger':
      'Co-regolazione, confini chiari senza umiliazione e breve de-escalation; Juul: guidare con rispetto invece di imporre l\'obbedienza.',
  'chat_focus_general':
      'Sollievo immediatamente utilizzabile e orientato all\'attaccamento; facoltativamente una lente adatta tra Montessori, Reggio, Froebel, Freinet, Juul o l\'approccio situazionale.',
  'chat_focus_learning':
      'Montessori: «Aiutami a fare da solo», preparare l\'ambiente e vedere i compiti quotidiani come occasioni di apprendimento; approccio situazionale: il mondo di vita attuale.',
  'chat_focus_media':
      'Confini chiari concordati in anticipo e transizioni collaborative invece di una lotta di potere; Juul: guidare con rispetto.',
  'chat_focus_play':
      'Froebel: il gioco come apprendimento; Reggio: molte forme di espressione, il processo prima del risultato; Freinet: esperienze reali della quotidianità.',
  'chat_focus_school':
      'Una struttura adatta al bambino e la collaborazione con i professionisti; approccio situazionale: il mondo di vita del bambino; Juul: cooperazione invece di obbedienza.',
  'chat_focus_siblings':
      'Separare senza punizione, rispecchiare i sentimenti, favorire un riavvicinamento/una riparazione equa; Juul: prendere pienamente sul serio entrambi i bambini.',
  'chat_focus_sleep':
      'Sollievo realistico, piccole routine e passi che risparmiano energia; Juul: accompagnare in modo autentico e rispettoso.',
  'chat_new_context':
      'Resta sulla richiesta attuale, senza una retrospettiva inventata.',
  'chat_no_context': 'nessuno',
  'chat_quality_retry':
      'Rispondi in modo più concreto e autentico: prima l\'empatia, un passo di CNV, 1-2 piccole opzioni, i sentimenti/bisogni come ipotesi. Focus: {focus} Paragrafi brevi di al massimo 3-4 frasi, niente muri di testo, formule di confine o «Devi». {followUp}',
  'chat_repair_prompt':
      'Riformula in modo puramente non violento, orientato all\'attaccamento e secondo la CNV. Niente rimproveri, minacce o punizioni. Fornisci tre passi concreti della quotidianità e due frasi di esempio. Focus: {focus}',
  'chat_system_prompt':
      'Sei il coach genitoriale di ParentPeak, caldo e senza giudizio, per la vita quotidiana con i bambini (0-18 anni). Rispondi nella lingua richiesta, in modo personale e senza fare la predica.\nFondamenti: Hüther – legame e autonomia, entusiasmo e coinvolgimento emotivo invece di pressione/paura; i bambini imparano con l\'esempio, non con le prediche. Non fare del bambino l\'oggetto di aspettative. Non togliere gli ostacoli superabili, i genitori stanno accanto; distingui i bisogni reali dai desideri materiali. Relazione, presenza ed esempio invece di premio/punizione. CNV di Rosenberg: osservazione, sentimento, bisogno, richiesta; frasi concrete per oggi. Rispecchia i sentimenti/bisogni con prudenza, senza affermarli come fatti. Juul: i bambini come persone a pieno titolo, una guida amorevole, la responsabilità di sé invece dell\'obbedienza.\nFacoltativo se pertinente: Montessori – ritmo proprio, ambiente preparato, autonomia; Reggio – molte forme di espressione, l\'osservazione invece del giudizio, il processo/la curiosità; Freinet – esperienze reali, libera espressione, autodeterminazione; Froebel – il gioco/la natura/la creatività come apprendimento; approccio situazionale – il mondo di vita attuale invece di un programma rigido.\nBreve, concreto, al massimo 8-10 righe, piccoli passi subito utilizzabili. L\'empatia prima della strategia; niente prediche, giudizi o muri di testo. Niente diagnosi/farmaci, nomina i limiti con onestà. In caso di pericolo acuto raccomanda un aiuto umano diretto; non inventare numeri di telefono specifici per paese non verificati. Vale la regola delle domande dell\'istruzione di coaching attuale; non aggiungere sempre una domanda in più.',
  'chat_tip_age_known':
      'Il bambino ha {age} anni compiuti. Adatta gli esempi di conseguenza.',
  'chat_tip_age_unknown': 'L\'età non è nota. Non inventarla; chiedi se serve.',
  'chat_tip_prompt':
      'I genitori vogliono approfondire questo consiglio:\n"{tip}"\n{ageContext}\nSpiega brevemente la sua rilevanza, tre situazioni concrete della quotidianità e un esercizio per oggi. Pratico, non violento, al massimo 12 righe.',
  'dev_answer_not_yet': 'Non ancora',
  'dev_answer_sometimes': 'A volte',
  'dev_answer_yes': 'Sì',
  'development_consent_body':
      'Per il report, le risposte di questo controllo dello sviluppo vengono inviate al nostro servizio di IA (Google Gemini). Il nome del tuo bambino resta sul tuo dispositivo e non viene trasmesso. I tuoi dati vengono elaborati solo per creare il report e non vengono conservati per identificarti.',
  'development_consent_save_failed':
      'Il consenso non è stato salvato in modo sicuro oppure l\'account è cambiato. Non verrà creato alcun report IA.',
  'development_report_special_needs':
      '- IMPORTANTE: questo bambino ha bisogni speciali. NON confrontarlo con le norme di età. Descrivi solo il progresso individuale. Invece di «bisogno di sostegno» di\' «cresce al proprio ritmo». Sii particolarmente apprezzante e incoraggiante.',
  'finance_content_turkey_note_11': 'Zaino, cancelleria, uniforme',
  'pdf_age_years': '{years} anni',
  'pdf_age_years_months': '{years} anni, {months} mesi',
  'pdf_ai_report_title': 'Report di sviluppo con IA',
  'pdf_compare_with': 'Confronto con {date}',
  'pdf_created_on': 'Creato il {date}',
  'pdf_default_child_name': 'Bambino',
  'pdf_disclaimer':
      'Nota: questo report si basa sulle osservazioni dei genitori e non è una diagnosi medica. In caso di dubbi sullo sviluppo del tuo bambino, rivolgiti al pediatra o a un centro di intervento precoce.',
  'pdf_filename_prefix': 'Report di sviluppo',
  'pdf_footer': 'Creato con Parentpeak — parentpeak.de',
  'pdf_legend_current': 'Attuale',
  'pdf_legend_previous': 'Controllo precedente',
  'pdf_page_of': 'Pagina {page} di {total}',
  'pdf_progress_title': 'Andamento dello sviluppo',
  'pdf_report_title': 'Report di sviluppo',
  'pdf_trend_down': 'in pausa',
  'pdf_trend_stable': 'stabile',
  'pdf_trend_up': 'cresce',
  'account_suspended_message':
      'Il tuo account è stato temporaneamente limitato. Per domande, contatta il nostro supporto: siamo qui per aiutarti.',
  'account_suspended_title': 'Account temporaneamente limitato',
  'add_friend_code': 'Aggiungi amico tramite codice',
  'add_meal': 'Aggiungi pasto',
  'add_person': 'Aggiungi persona',
  'admin_action_failed': 'Azione non riuscita.',
  'admin_cleanup_empty':
      'Tutto in ordine: nessuna voce danneggiata trovata. 🎉',
  'admin_cleanup_failed': 'Pulizia non riuscita. Riprova più tardi.',
  'admin_cleanup_message':
      'Sono state trovate {count} voci di connessione danneggiate (codici errati o orfani). Verranno rimosse.\n\nUtenti reali, nomi e chat restano intatti.',
  'admin_cleanup_preview_failed': 'Anteprima non riuscita. Riprova più tardi.',
  'admin_cleanup_success': '{count} voci ripulite. Il database è in ordine. ✅',
  'admin_cleanup_title': 'Pulire il database?',
  'admin_cleanup_tooltip': 'Pulisci il database',
  'admin_community_safe': 'Tutto tranquillo. La tua community è al sicuro.',
  'admin_filter_all': 'Tutte',
  'admin_filter_done': 'Chiuse',
  'admin_filter_open': 'Aperte',
  'admin_ignore': 'Ignora',
  'admin_last_reason': 'Ultimo motivo: {reason}',
  'admin_load_failed':
      'Non è stato possibile caricare le segnalazioni. Riprova più tardi.',
  'admin_locked': 'sospeso',
  'admin_no_access':
      'Nessun accesso amministratore. Accedi con un account amministratore.',
  'admin_no_reports': 'Nessuna segnalazione aperta',
  'admin_reason_fraud': 'Truffa / falso',
  'admin_reason_inappropriate': 'Contenuti inappropriati',
  'admin_reason_insult': 'Insulto / incitamento all\'odio',
  'admin_reason_other': 'Altro',
  'admin_reason_spam': 'Spam / pubblicità',
  'admin_remove_count': 'Rimuovi {count}',
  'admin_reported_count': 'Segnalato {count}×',
  'admin_reports_resolved': 'Segnalazioni contrassegnate come esaminate.',
  'admin_suspend_action': 'Sospendi',
  'admin_suspend_failed': 'Sospensione non riuscita.',
  'admin_suspend_message':
      'L\'account verrà nascosto dalla rete e dalla ricerca. La sospensione è reversibile e nessun dato verrà eliminato.\n\nID utente: {userId}',
  'admin_suspend_title': 'Sospendere l\'account?',
  'admin_suspended': 'Account sospeso.',
  'admin_title': 'Moderazione',
  'admin_unlock': 'Revoca sospensione',
  'admin_unsuspended': 'Sospensione rimossa.',
  'admin_user_id': 'Utente: {userId}',
  'age_months': '{count} mesi',
  'age_years': '{count} anni',
  'age_years_months': '{years} anni, {months} mesi',
  'ai_disclosure': 'Informativa sull\'uso dell\'IA',
  'all_events': 'Tutti →',
  'all_seen': 'Visto tutto',
  'antrag_ai_description':
      'L\'IA ti prepara una lettera di accompagnamento o una motivazione, pronta da copiare.',
  'antrag_ai_disclaimer':
      'Questo è un modello, non una consulenza legale. Adatta il testo alla tua situazione personale.',
  'antrag_ai_failed':
      'Non è stato possibile creare il modello di testo. Riprova.',
  'antrag_ai_tab': 'Aiuto IA',
  'antrag_ai_template': 'Modello di testo IA',
  'antrag_ai_writing': 'L\'IA sta scrivendo...',
  'antrag_all_ready': 'Tutto pronto!',
  'antrag_content_limits':
      'Orientamento generale, non consulenza legale. Non tutti i documenti, le scadenze e i dettagli procedurali sono verificati ufficialmente. Verifica i requisiti attuali e i termini di ricorso presso l\'ente competente.',
  'antrag_copied': '📋 Copiato negli appunti!',
  'antrag_copy_failed': 'Copia non riuscita. Riprova.',
  'antrag_documents_count': '{checked} di {total} documenti pronti',
  'antrag_documents_tab': 'Documenti',
  'antrag_guide_tab': 'Guida',
  'antrag_need_documents': 'Ecco cosa ti serve',
  'antrag_next_guide': 'Vai alla guida',
  'antrag_open_link': 'Apri il link',
  'antrag_open_online': 'Apri la domanda online',
  'antrag_optional': 'Facoltativo',
  'antrag_premium_description':
      'Con Premium ottieni la guida completa, i modelli di testo IA e i promemoria.',
  'antrag_premium_soon':
      'Il Premium arriva presto! Durante la beta è tutto gratuito.',
  'antrag_processing_time': '⏱️ Tempi di elaborazione: {time}',
  'antrag_ready_next': 'Hai tutti i documenti. Vai al passaggio 2!',
  'antrag_regenerate': 'Genera di nuovo',
  'antrag_step_guide': 'Guida passo dopo passo',
  'antrag_template': 'Modello',
  'antrag_unlock_premium': 'Sblocca Premium',
  'application_authority': 'Competente: {authority}',
  'application_create_template': 'Crea un modello di testo per {benefit}',
  'apply_filter': 'Applica filtro',
  'appointments_tasks': 'Appuntamenti e attività',
  'archive': 'Archivio',
  'auth_email_address_label': 'Indirizzo e-mail',
  'auth_email_confirm_instructions':
      'Tocca il link nell\'e-mail. Dopodiché potrai accedere.',
  'auth_email_confirm_title': 'Conferma la tua e-mail 📬',
  'auth_email_invalid': 'Inserisci un indirizzo e-mail valido.',
  'auth_email_label': 'E-mail',
  'auth_email_required': 'L\'e-mail è obbligatoria.',
  'auth_email_resent': '✅ È stato inviato un nuovo link.',
  'auth_email_sent': 'Abbiamo inviato un\'e-mail di conferma a\n{email}.',
  'auth_password_label': 'Password',
  'auth_password_required': 'La password è obbligatoria.',
  'auth_resend_link': 'Invia di nuovo il link',
  'auth_to_login': 'Vai all\'accesso',
  'auth_url_open_failed': 'Impossibile aprire {url}.',
  'auto_next': 'Avanzamento automatico',
  'back': 'Indietro',
  'backup_exported': 'Backup esportato',
  'backup_import': 'Importa backup',
  'backup_qr': 'Backup come QR',
  'backup_restored': 'Backup ripristinato',
  'bedtime_actions': 'Ecco cosa puoi fare adesso:',
  'bedtime_done': 'Buonanotte! Routine completata.',
  'bedtime_how': 'Come funziona?',
  'bedtime_start': 'Inizia',
  'bedtime_subtitle': 'A letto, rilassati, in 30 min',
  'bedtime_title': 'Routine della sera',
  'benefit_ai_consent_accept': 'Accetto e uso l\'IA',
  'benefit_ai_consent_body':
      'Per l\'orientamento personale, il tuo testo libero, le informazioni sulla situazione selezionate, il paese e l\'età dei bambini disponibile vengono inviati tramite il server ParentPeak a Google Gemini. Per farlo Gemini può usare una ricerca sul web. Alcuni dati di contatto riconosciuti vengono in parte rimossi; non si tratta di un\'anonimizzazione completa. Non inserire nomi, indirizzi o dettagli sulla salute. Qui le informazioni non vengono salvate come conversazione. Il consenso vale per questo account o per la modalità ospite. Senza consenso restano disponibili le informazioni generali sulle prestazioni, ma non viene avviata alcuna richiesta all\'IA.',
  'benefit_ai_consent_failed':
      'Non è stato possibile salvare il consenso. Nessuna richiesta all\'IA è stata avviata.',
  'benefit_ai_consent_title': 'Usare la guida agli aiuti con l\'IA?',
  'benefit_ask_action': 'Chiedi alla guida',
  'benefit_check_link': '🔗 Verifica qui →',
  'benefit_checklist_title': 'La vostra checklist',
  'benefit_chip_income': 'Reddito basso',
  'benefit_chip_leave': 'Congedo parentale',
  'benefit_chip_move': 'Trasloco',
  'benefit_chip_salary': 'Lo stipendio cala',
  'benefit_chip_second': 'Arriva il secondo figlio',
  'benefit_chip_single': 'Genitore single',
  'benefit_disclaimer':
      'Questo è un orientamento, non una consulenza legale. Fa fede sempre l\'ente competente. Gli importi vengono calcolati lì caso per caso.',
  'benefit_fallback_check':
      'Controlla gli enti ufficiali collegati per i dettagli.',
  'benefit_fallback_notice':
      'La risposta dell\'IA non è disponibile. Questo è un orientamento generale e locale per il tuo paese, non adattato alla tua situazione.',
  'benefit_fallback_prepare':
      'Tieni pronti documento d\'identità, prove del reddito e certificato di nascita.',
  'benefit_guide_title': 'Guida agli aiuti',
  'benefit_input_required':
      'Descrivi brevemente la vostra situazione o scegli uno spunto.',
  'benefit_loading': 'Sto controllando cosa può andar bene per voi …',
  'benefit_local_only': 'resta su questo dispositivo',
  'benefit_matches_title': 'Questo potrebbe riguardarvi',
  'benefit_next_steps': 'Prossimi passi',
  'benefit_request_failed':
      'Non sono riuscito a rispondere in questo momento. Riprova tra poco.',
  'benefit_situation_description':
      'Con parole tue, per esempio: «Il secondo figlio arriva a giugno, il mio partner lavora part-time».',
  'benefit_situation_hint': 'La vostra situazione …',
  'benefit_situation_title': 'Descrivete brevemente la vostra situazione',
  'benefit_sources': 'Fonti',
  'benefit_start_application': 'Avvia l\'assistente alle domande',
  'block_profile': 'Blocca profilo',
  'breakfast': 'Colazione',
  'budget_positions_imported': '{count} voci importate.',
  'cancel_reservation': 'Annulla la prenotazione',
  'caregiver_role': 'Persona di riferimento',
  'change_action': 'Modifica',
  'chat_access_unavailable':
      'Questa conversazione non è disponibile per questo account.',
  'chat_always_here': 'Sempre qui per te',
  'chat_boundary_diagnosis':
      'Non posso formulare una diagnosi. Posso offrirti un aiuto quotidiano orientato all\'attaccamento. Per un chiarimento diagnostico rivolgiti al pediatra o alla psicologia dell\'età evolutiva.',
  'chat_boundary_medical':
      'Non fornisco raccomandazioni mediche o indicazioni sui farmaci. Rivolgiti a un consulto medico o al servizio medico di guardia della tua zona.',
  'chat_boundary_topic':
      'Sono qui per offrirti una consulenza educativa per genitori. Descrivi pure la tua domanda sulla famiglia o sull\'educazione.',
  'chat_boundary_violence':
      'Non fornisco istruzioni che facciano del male o che incoraggino la violenza. Posso invece aiutarti con un approccio nonviolento: osservazione, sentimento, bisogno e richiesta concreta.',
  'chat_claim_action': 'Conferma la proprietà',
  'chat_claim_failed':
      'Non è stato possibile acquisire le statistiche sui temi. I dati precedenti restano intatti.',
  'chat_consent_load_failed':
      'Non è stato possibile verificare il consenso all\'IA. Senza un consenso confermato, nulla viene inviato all\'IA.',
  'chat_consent_save_failed':
      'Non è stato possibile salvare il consenso. Nessuna richiesta all\'IA è stata avviata. Riprova.',
  'chat_daily_limit':
      'Hai raggiunto il tuo limite giornaliero di {limit} richieste all\'IA. Potrai chiedere di nuovo domani.',
  'chat_delete': 'Elimina',
  'chat_delete_failed': 'Eliminazione non riuscita, riprova più tardi.',
  'chat_delete_for_all': 'Elimina per tutti',
  'chat_delete_for_all_confirm':
      'L\'intera cronologia verrà eliminata in modo permanente per tutti i partecipanti. L\'operazione non può essere annullata.',
  'chat_delete_for_all_hint': 'Rimuovi la cronologia per tutti i partecipanti',
  'chat_delete_for_me': 'Elimina per me',
  'chat_delete_for_me_confirm':
      'Questa chat verrà rimossa solo per te. L\'altra persona conserva la cronologia.',
  'chat_delete_for_me_hint': 'Sparisce solo per te',
  'chat_delete_history_confirm':
      'Vuoi davvero eliminare la cronologia attuale della chat?',
  'chat_deleted': 'Chat eliminata.',
  'chat_fallback_anger':
      'Prima metti in sicurezza, poi rispecchia con delicatezza i sentimenti e offri un\'alternativa. Per esempio: «Vedo la tua rabbia. Non permetto che qualcuno si faccia male. Puoi pestare i piedi o premere contro il cuscino.» Cosa succede subito prima?',
  'chat_fallback_general':
      'Non sei solo in questo. Descrivi pure la situazione concreta e l\'età compiuta, senza nomi o date di nascita precise. Così osservazione, sentimento, bisogno e richiesta possono diventare passi concreti per la vita di tutti i giorni.',
  'chat_fallback_label':
      'Orientamento generale e curato: la risposta dell\'IA non era adatta. Questa non è una risposta personalizzata affidabile.',
  'chat_fallback_sleep':
      'La sera potresti ridurre gli stimoli, offrire una piccola scelta tra un libro e una canzone e ripetere una frase di chiusura tranquilla. Per esempio: «Vorresti restare ancora sveglio. Ora ti accompagno verso la calma.» Quale passaggio è più difficile per voi?',
  'chat_feedback_dangerous': 'pericoloso',
  'chat_feedback_helpful': 'utile',
  'chat_feedback_inappropriate': 'inappropriato',
  'chat_feedback_not_helpful': 'non utile',
  'chat_feedback_saved': 'Feedback salvato: {feedback}',
  'chat_greeting_day': 'Ciao',
  'chat_greeting_evening': 'Buonasera',
  'chat_greeting_morning': 'Buongiorno',
  'chat_greeting_night': 'Buonanotte',
  'chat_guidelines': 'Regole della chat',
  'chat_history_budget':
      'L\'IA riceve al massimo gli ultimi {rounds} scambi di conversazione e {characters} caratteri di cronologia. I messaggi più vecchi restano visibili qui.',
  'chat_how_can_help': 'Come posso aiutarti?',
  'chat_inappropriate': 'Contenuto inappropriato',
  'chat_init_error': 'Errore: {error}',
  'chat_insight_attachment': 'Legame e sentimenti',
  'chat_insight_autonomy': 'Fase di autonomia',
  'chat_insight_conflicts': 'Conflitti',
  'chat_insight_crisis': 'Crisi',
  'chat_insight_media': 'Media',
  'chat_insight_nutrition': 'Alimentazione',
  'chat_insight_other': 'Altro',
  'chat_insight_school': 'Scuola/asilo',
  'chat_insight_siblings': 'Fratelli',
  'chat_insight_sleep': 'Sonno',
  'chat_legacy_body':
      'Su questo dispositivo ci sono vecchie statistiche sui temi senza assegnazione a un account. Acquisiscile solo se ti appartengono. L\'acquisizione è locale, non invia nulla all\'IA e non importa la cronologia delle conversazioni. I dati originali restano intatti.',
  'chat_legacy_title': 'Statistiche dei temi locali non assegnate',
  'chat_medical_de':
      'In Germania puoi contattare il servizio medico di guardia al numero 116117.',
  'chat_memory_load_failed':
      'Non è stato possibile caricare il contesto della memoria dell\'IA. Riprova nelle impostazioni della memoria.',
  'chat_message_hint': 'Raccontami cosa ti sta a cuore...',
  'chat_other': 'Altro',
  'chat_privacy_footer':
      'Nessuna diagnosi · Elaborazione tramite Google Gemini',
  'chat_provider_authorization':
      'Il servizio non ha autorizzato questa richiesta.',
  'chat_provider_network':
      'La connessione non è riuscita o ha richiesto troppo tempo.',
  'chat_provider_quota': 'Il contingente del servizio è attualmente esaurito.',
  'chat_provider_unavailable':
      'La consulenza con l\'IA al momento non è disponibile. Non c\'è una risposta personale affidabile. Riprova più tardi.',
  'chat_provider_unavailable_reason':
      'Il servizio non è riuscito a fornire una risposta valida.',
  'chat_report': 'Segnala',
  'chat_report_message': 'Segnala messaggio',
  'chat_report_thanks': 'Grazie! Lo esamineremo.',
  'chat_request_failed': 'Non è stato possibile caricare la risposta. Riprova.',
  'chat_retry_later': 'Puoi riprovare più tardi.',
  'chat_retry_missing_question': 'Nessuna domanda precedente da riprovare.',
  'chat_safety_concern': 'Problema di sicurezza',
  'chat_spam': 'Spam',
  'chat_terms_accept': 'Accetta il trattamento tramite IA',
  'chat_terms_intro': 'Prima di iniziare, leggi un momento:',
  'chat_terms_no_diagnosis_text':
      'L\'IA non formula diagnosi mediche o psicologiche. In caso di preoccupazioni serie, rivolgiti a un professionista.',
  'chat_terms_no_diagnosis_title': 'Nessuna diagnosi',
  'chat_terms_privacy_text':
      'Il tuo messaggio e la cronologia della chat vengono inviati tramite il backend ParentPeak a Google Gemini per generare una risposta. Il testo libero può contenere nomi e informazioni sulla salute; l\'anonimizzazione automatica non è completa. Solo con il consenso aggiuntivo alla memoria il backend aggiunge indicazioni neutre sul bambino, l\'età compiuta e le informazioni familiari confermate, comprese quelle sulla salute. Invia solo dati di cui accetti il trattamento. La chat resta temporaneamente in memoria, non viene conservata come cronologia permanente delle conversazioni. La frequenza dei temi e il tuo consenso vengono salvati localmente. Questo consenso vale per questo account su questo dispositivo e non pubblica alcun dato.',
  'chat_terms_privacy_title': 'Elaborazione tramite Google Gemini',
  'chat_terms_respect_text':
      'L\'IA non giudica mai te o tuo figlio. Ti accompagna senza colpevolizzare e senza pressioni.',
  'chat_terms_respect_title': 'Rispettoso e accogliente',
  'chat_tip_message': '💡 Consiglio: «{tip}»',
  'chat_topic_analysis_privacy':
      'Rispettoso della privacy: vengono salvati solo i conteggi dei temi, mai i testi.',
  'chat_topic_analysis_title': 'Analisi dei temi',
  'chat_topic_overwhelmed_label': 'Sono al limite',
  'chat_topic_overwhelmed_question':
      'Sono completamente esausto e mi sento sopraffatto.',
  'chat_topic_school_label': 'Scuola e apprendimento',
  'chat_topic_school_question':
      'Mio figlio è stressato per la scuola. Come posso aiutarlo?',
  'chat_topic_screen_label': 'Troppo tempo davanti allo schermo',
  'chat_topic_screen_question':
      'Mio figlio è sempre attaccato al telefono. Come posso gestirlo?',
  'chat_topic_siblings_label': 'I fratelli litigano',
  'chat_topic_siblings_question':
      'I miei figli litigano di continuo. Devo intervenire?',
  'chat_topic_sleep_label': 'Dormire è una lotta',
  'chat_topic_sleep_question':
      'Mettere a letto è una lotta ogni sera. Cosa posso fare?',
  'chat_topic_tantrum_label': 'Mio figlio perde il controllo',
  'chat_topic_tantrum_question':
      'Mio figlio perde continuamente il controllo e non so più cosa fare.',
  'chat_topics_load_failed':
      'Non è stato possibile caricare le statistiche sui temi. Ricarica; i dati esistenti non vengono sovrascritti.',
  'chat_topics_save_failed':
      'Non è stato possibile salvare le statistiche sui temi. La modifica non è stata confermata; ciò che hai inserito resta intatto.',
  'chat_understood': 'Ho capito',
  'chat_welcome_message':
      'Raccontami cosa ti preoccupa in questo momento. Ti ascolto, senza giudicare.',
  'child_name_example': 'es. Emma',
  'child_role': 'Bambino',
  'choose_country_region': 'Scegli il tuo paese e la tua regione',
  'circle_accept': 'Accetta',
  'circle_decline': 'Rifiuta',
  'circle_invite': 'Invita',
  'circle_invite_contact': 'Invita un contatto',
  'circle_no_self_request': 'Non puoi inviare una richiesta a te stesso.',
  'circle_remove': 'Rimuovi',
  'circle_remove_contact': 'Rimuovi contatto',
  'circle_send_request': 'Invia richiesta',
  'circle_title': 'Cerchia familiare',
  'clipboard': 'Appunti',
  'close': 'Chiudi',
  'common_cancel': 'Annulla',
  'common_check_here': '🔗 Verifica qui →',
  'common_delete_failed': 'Errore durante l\'eliminazione: {error}',
  'common_error_with_detail': 'Errore: {error}',
  'common_link_open_failed': 'Non è stato possibile aprire il link.',
  'common_not_now': 'Non ora',
  'common_status': 'Stato',
  'common_understood': 'Ho capito',
  'community_event_ai_recognizes':
      'L\'IA riconosce automaticamente: titolo, data, luogo, descrizione',
  'community_event_create_anyway': 'Crea comunque',
  'community_event_from_gallery': 'Scegli dalla galleria',
  'community_event_photo_hint':
      'Scatta una foto → l\'IA compila tutto automaticamente',
  'community_event_published': '✅ Evento pubblicato!',
  'community_event_scan_flyer': 'Scansiona volantino / poster',
  'community_event_similar_found': 'Trovato un evento simile',
  'community_event_take_photo': 'Scatta una foto',
  'community_flyer_detected':
      '✅ Volantino riconosciuto! Controlla le informazioni.',
  'community_title': 'Trova altri genitori',
  'confirm': 'Conferma',
  'confirm_delete_type': 'Scrivi «ELIMINA» per confermare:',
  'confirm_logout': 'Disconnettersi?',
  'confirm_pickup': 'Conferma il ritiro',
  'confirm_reg': 'Conferma la registrazione',
  'confirm_registration': 'Conferma la registrazione',
  'contact_now': 'Contatta ora',
  'contact_support': 'Contatti e supporto',
  'conversation_report_reason': 'Perché vuoi segnalare {name}?',
  'convo_block': 'Blocca',
  'convo_parent_network': 'Rete dei genitori',
  'convo_refresh': 'Aggiorna',
  'convo_report_user': 'Segnala utente',
  'cooking_tips_title': 'Consigli per i pasti in famiglia',
  'copy_code_close': 'Copia il codice e chiudi',
  'copy_link_close': 'Copia il link e chiudi',
  'country': 'Paese',
  'create_event': 'Pianifica evento',
  'current_status': 'Stato attuale',
  'daily_tip_explain': 'Spiegamelo meglio',
  'daily_tip_title': 'Consiglio del giorno',
  'delete_account_title': 'Elimina l\'account',
  'delete_confirm_input': 'Scrivi «ELIMINA» per confermare:',
  'delete_event_confirm': 'Eliminare l\'appuntamento?',
  'delete_event_title': 'Eliminare l\'appuntamento?',
  'delete_final': 'Elimina definitivamente',
  'delete_permanently': 'Elimina definitivamente',
  'delete_person_confirm':
      'La persona verrà rimossa dal calendario. Gli appuntamenti associati verranno spostati su «Genitori».',
  'delete_profile': 'Eliminare il profilo?',
  'delete_review_confirm':
      'Il riepilogo verrà eliminato in modo irreversibile.',
  'details': 'Dettagli',
  'development_consent_accept': 'Accetto, crea il rapporto',
  'development_consent_title': 'Creare il report con l\'IA',
  'development_conversation_prompt': 'Spunto di conversazione',
  'development_practice_today': 'Pratica per oggi',
  'development_questions_remaining':
      'Ancora {count} domande aperte. Rispondi a tutte le domande per ricevere il tuo rapporto IA personale.',
  'development_report_error':
      'Non è stato possibile creare il rapporto: {error}',
  'development_report_language_instruction':
      'Scrivi l\'intero rapporto in italiano.',
  'development_report_limit_reached':
      'Il tuo rapporto gratuito per quest\'anno è già stato creato.',
  'development_report_next_free':
      'Prossimo rapporto gratuito: da gennaio {year}.',
  'development_special_needs': 'Mio figlio ha bisogni particolari',
  'development_special_needs_hint':
      'Per esempio ritardo nello sviluppo, disabilità o malattia cronica. Il rapporto si baserà allora sui progressi individuali anziché sulle norme per età.',
  'dinner': 'Cena',
  'done': 'Fatto',
  'duration_1_min': '1 min.',
  'duration_2_min': '2 min.',
  'duration_3_min': '3 min.',
  'duration_5_min': '5 min.',
  'duration_minutes': '{minutes} min.',
  'edit_member': 'Modifica membro',
  'emergencies': 'Emergenze',
  'expert_action_listen': 'Ascolta',
  'expert_action_watch': 'Guarda',
  'expert_action_more_info': 'Maggiori informazioni',
  'expert_action_read': 'Leggi',
  'expert_library_title': 'Biblioteca degli esperti',
  'expert_library_subtitle': 'Podcast, video e libri che aiutano davvero.',
  'expert_library_content_english_notice':
      'I contenuti consigliati sono in inglese. L\'interfaccia e le categorie vengono mostrate nella tua lingua.',
  'expert_library_filter_all': 'Tutti',
  'expert_library_empty': 'Ancora nessun consiglio per questa categoria.',
  'export_data': 'Esporta i miei dati',
  'fallback_default_reflection':
      'Cosa ha funzionato bene oggi? Quale momento con tuo figlio vuoi conservare?',
  'fallback_evening_reflection': 'Riflessione della sera',
  'fallback_impulse_1_body':
      'I confini amorevoli non sono una contraddizione. I bambini hanno bisogno di entrambe le cose: sentirsi amati e avere un orientamento chiaro. I confini posti con il legame funzionano come guardrail, non come muri.',
  'fallback_impulse_1_reflection':
      'Oggi c\'è stata una situazione in cui un confine posto con calma ha funzionato meglio di un no urlato?',
  'fallback_impulse_1_tip':
      'Oggi nomina prima il sentimento di tuo figlio, poi il confine: «Vedo che sei arrabbiato. E comunque, picchiare non si fa.»',
  'fallback_impulse_1_title': 'Porre limiti con affetto',
  'fallback_impulse_2_body':
      'I messaggi in "tu" suscitano difesa. I messaggi in "io" aprono le porte. I bambini ascoltano di più quando non si sentono attaccati.',
  'fallback_impulse_2_reflection':
      'Oggi un messaggio in "io" ha suscitato una reazione che ti ha sorpreso?',
  'fallback_impulse_2_tip':
      'Oggi scegli una situazione in cui di solito diresti «Tu sempre …» e sostituiscila con «Io mi sento …, perché ho bisogno di …».',
  'fallback_impulse_2_title': 'I messaggi in prima persona nella quotidianità',
  'fallback_impulse_3_body':
      'Se oggi è tutto troppo: scegli un solo momento tranquillo con tuo figlio e nomina un sentimento senza giudicare. Questo breve contatto rafforza il legame e la sicurezza.',
  'fallback_impulse_3_reflection':
      'Quale piccolo momento di oggi ha fatto bene a entrambi?',
  'fallback_impulse_3_tip':
      'Respirate insieme per tre minuti. Poi chiedi: «Cosa è stato facile per te oggi?»',
  'fallback_impulse_3_title': 'Piccoli passi, grande effetto',
  'fallback_impulse_4_body':
      'Ogni bambino ha una combinazione unica di punti di forza. Spesso notiamo prima le difficoltà, anche se possiamo riconoscere pure il potenziale che c\'è dietro.',
  'fallback_impulse_4_reflection':
      'Quale punto di forza di tuo figlio ti ha sorpreso o colpito oggi?',
  'fallback_impulse_4_tip':
      'Oggi parla con tuo figlio di uno dei suoi punti di forza, non come lode ma come osservazione: «Oggi ho visto come tu …»',
  'fallback_impulse_4_title':
      'Vedere i punti di forza invece di giudicare le debolezze',
  'fallback_impulse_5_body':
      'I bambini diventano autonomi quando ci fidiamo di loro. L\'arte sta nell\'affidare più responsabilità passo dopo passo, senza intervenire troppo presto.',
  'fallback_impulse_5_reflection':
      'Quando oggi avete lasciato andare, e come ci si è sentiti?',
  'fallback_impulse_5_tip':
      'Oggi affida a tuo figlio un compito che finora facevi tu e lascia che lo porti a termine completamente da solo.',
  'fallback_impulse_5_title': 'Autonomia: lasciar andare è anche amore',
  'fallback_impulse_6_body':
      'I bambini che sanno dare un nome ai propri sentimenti riescono a comunicare ciò di cui hanno bisogno. Il passo dal sentire al parlare richiede pratica e il tuo sostegno.',
  'fallback_impulse_6_reflection':
      'Quale momento emotivo di vostro figlio vorreste conservare oggi?',
  'fallback_impulse_6_tip':
      'Stasera chiedi: «Cosa ti ha reso felice? Cosa ti ha reso triste o arrabbiato?» Poi ascolta e basta.',
  'fallback_impulse_6_title': 'Nominare e riconoscere le emozioni',
  'fallback_impulse_7_body':
      'Il cervello impara in modo particolarmente intenso dagli errori. Quando tuo figlio sbaglia e tu resti calmo, gli trasmetti: sbagliare è sicuro. Lo so sopportare.',
  'fallback_impulse_7_reflection':
      'Oggi c\'è stato un insuccesso che tuo figlio ha gestito bene? Cosa è stato d\'aiuto?',
  'fallback_impulse_7_tip':
      'Oggi racconta a tuo figlio di un tuo insuccesso e di cosa hai imparato da esso.',
  'fallback_impulse_7_title': 'Vedere il fallimento come occasione di crescita',
  'fallback_impulse_headline':
      'Spunto del giorno per la vita di tutti i giorni',
  'fallback_understood_summary':
      'I bambini collaborano meglio quando prima si sentono visti. Il legame viene prima della correzione.',
  'fallback_understood_title': 'In breve',
  'family_action_not_allowed':
      'Questa azione non è consentita con questo ruolo.',
  'family_delete_account_error':
      'Errore durante l\'eliminazione dell\'account: {error}',
  'family_hub_account_changed':
      'L\'account è cambiato. Chiudi questa schermata.',
  'family_hub_age_years': '{count} anni',
  'family_hub_allergies': '⚠️ Allergie',
  'family_hub_allergies_csv': 'Allergie (separate da virgola)',
  'family_hub_allergies_hint': 'es. noci, lattosio',
  'family_hub_blood_type': '🧬 Gruppo sanguigno',
  'family_hub_blood_type_hint': 'es. A+',
  'family_hub_blood_type_plain': 'Gruppo sanguigno',
  'family_hub_child_fallback': 'Bambino',
  'family_hub_child_name': 'Nome del bambino',
  'family_hub_child_name_hint': 'es. Mila',
  'family_hub_children_empty_hint':
      'Crea un profilo nella rete dei genitori per usare il profilo del bambino.',
  'family_hub_clothing_hint': 'es. 110',
  'family_hub_clothing_size': 'Taglia dei vestiti',
  'family_hub_clothing_size_short': '👕 Tg.',
  'family_hub_daycare_group': 'Gruppo / classe',
  'family_hub_daycare_group_hint': 'es. Gruppo Coccinelle',
  'family_hub_daycare_hint': 'es. Asilo Girasole',
  'family_hub_daycare_school': 'Asilo / scuola',
  'family_hub_daycare_teacher': 'Educatrice / insegnante',
  'family_hub_daycare_teacher_hint': 'es. Signora Yılmaz',
  'family_hub_doctor_phone': '📞 Tel. medico',
  'family_hub_edit_child': 'Modifica {name}',
  'family_hub_emergency_contact': '📱 Contatto di emergenza',
  'family_hub_emergency_contact_hint': 'es. Nonna Elena',
  'family_hub_emergency_contact_name': 'Contatto di emergenza (nome)',
  'family_hub_emergency_phone': '📞 Tel. emergenza',
  'family_hub_emergency_phone_hint': '0170 ...',
  'family_hub_emergency_phone_plain': 'Telefono di emergenza',
  'family_hub_exam_due': 'In scadenza: {exam}',
  'family_hub_legacy_claim': 'Appartiene al mio account, acquisisci',
  'family_hub_legacy_confirm':
      'Confermo che i profili dei bambini (comprese le informazioni sulla salute e di emergenza), le liste della spesa, le cose da fare e le allergie in cucina salvate finora su questo dispositivo appartengono all\'account con cui ho effettuato l\'accesso. Verranno associati solo localmente a questo account. I dati esistenti dell\'account restano intatti; nulla viene pubblicato.',
  'family_hub_legacy_failed':
      'Non è stato possibile acquisire i dati precedenti in modo sicuro. I dati originali restano intatti.',
  'family_hub_legacy_notice':
      'Su questo dispositivo ci sono dati precedenti non assegnati. Non vengono usati automaticamente. Accedi per acquisirli dopo averne confermato la proprietà.',
  'family_hub_legacy_title': 'Adottare i dati locali precedenti',
  'family_hub_load_error':
      'Non è stato possibile caricare completamente la Centrale di Famiglia.',
  'family_hub_none_known': 'Nessuna nota',
  'family_hub_not_entered': 'Non inserito',
  'family_hub_notes': 'Note',
  'family_hub_notes_hint': 'es. particolarità, preferenze',
  'family_hub_pediatrician': '🏥 Pediatra',
  'family_hub_pediatrician_hint': 'es. Dott. Rossi',
  'family_hub_pediatrician_name': 'Nome del pediatra',
  'family_hub_pediatrician_phone': 'Telefono del pediatra',
  'family_hub_phone_hint': '030 123456',
  'family_hub_retry': 'Riprova',
  'family_hub_save_error':
      'Non è stato possibile salvare la modifica. Riprova.',
  'family_hub_shoe_hint': 'es. 28',
  'family_hub_shoe_size': 'Numero di scarpe',
  'family_hub_shoe_size_short': '👟 Scarpe',
  'family_hub_shopping_hint': 'es. «3x latte» oppure «pasta 500 g»',
  'family_hub_shopping_list': 'Lista della spesa',
  'family_hub_tab_children': 'Bambini',
  'family_hub_tab_shopping': 'Spesa',
  'family_hub_tab_todo': 'Da fare',
  'family_hub_todo_hint': 'Nuova attività ...',
  'family_hub_uexam_done_on': 'Completato il {date}',
  'family_hub_uexams_open': '{count} ancora da fare',
  'family_hub_uexams_title': 'Visite di controllo (U)',
  'family_import_invalid': 'Importazione non riuscita. JSON non valido.',
  'family_min_member': 'Deve restare almeno un membro.',
  'family_name_desc':
      'Il tuo nome o il nome della famiglia, così possiamo salutarti in modo personale.',
  'family_name_exists': 'Questo nome esiste già.',
  'family_name_hint': 'es. Famiglia Rossi o Anna',
  'family_ok': 'OK',
  'family_recipe_delete_confirm': 'Vuoi davvero eliminare «{title}»?',
  'family_recipe_delete_title': 'Eliminare la ricetta?',
  'family_recipe_deleted': 'Ricetta eliminata.',
  'family_recipe_description_hint': 'Perché piace ai vostri bambini?',
  'family_recipe_description_label': 'Breve descrizione',
  'family_recipe_ingredients_hint': '500 g di patate\n1 cipolla\n…',
  'family_recipe_ingredients_label': 'Ingredienti (uno per riga)',
  'family_recipe_minutes_hint': 'es. 25',
  'family_recipe_minutes_label': 'Tempo di preparazione in minuti',
  'family_recipe_name_hint': 'es. L\'insalata di patate della nonna',
  'family_recipe_name_label': 'Nome del piatto',
  'family_recipe_name_required': 'Dai un nome alla tua ricetta.',
  'family_recipe_photo_optional': 'Aggiungi una foto (facoltativo)',
  'family_recipe_photo_pick_failed':
      'Non è stato possibile selezionare la foto.',
  'family_recipe_save_failed': 'Impossibile salvare, riprova più tardi.',
  'family_recipe_share_action': 'Condividi',
  'family_recipe_share_success':
      'Ricetta condivisa. Grazie per aver condiviso! 🍳',
  'family_recipe_share_title': 'Condividi la ricetta',
  'family_recipe_steps_hint':
      'Lessa le patate.\nTaglia la cipolla a dadini.\n…',
  'family_recipe_steps_label': 'Preparazione (un passaggio per riga)',
  'family_recipe_visibility_friends': 'Solo i miei amici',
  'family_recipe_visibility_friends_hint':
      'Consigliato, la vedono solo le famiglie collegate.',
  'family_recipe_visibility_private': 'Solo per me',
  'family_recipe_visibility_private_hint': 'Resta privata, la vedi solo tu.',
  'family_recipe_visibility_public': 'Per tutte le famiglie',
  'family_recipe_visibility_public_hint':
      'Tutte le famiglie Parentpeak possono scoprirla.',
  'family_recipe_visibility_title': 'Chi può vedere la tua ricetta?',
  'family_scan_qr': 'Scansiona QR',
  'feedback_thanks': '❤️ Grazie per il tuo riscontro!',
  'fill_again': 'Compila di nuovo',
  'filter_all': 'Tutti',
  'filter_family_circle': 'Cerchia familiare',
  'filter_invited': 'Invitati',
  'filter_public': 'Pubblico',
  'filter_search': 'Filtra la ricerca',
  'filter_title': 'Filtri',
  'finance_add_care': 'Aggiungi voce di cura',
  'finance_add_manual': 'Voce manuale',
  'finance_add_position_manual': 'Aggiungi una voce manualmente',
  'finance_add_saving': 'Aggiungi occasione di risparmio',
  'finance_amount_per_month': '~{amount}/mese',
  'finance_amount_per_year': '{amount}/anno',
  'finance_amounts_disclaimer':
      'Importi e link servono solo come orientamento, senza garanzia. Solo alcune informazioni sono state verificate ufficialmente; non c\'è una verifica completa dell\'attualità. L\'importo esatto lo calcola l\'ente competente.',
  'finance_application_bildungTeilhabe_aiTemplatePrompt_5':
      'Scrivi una breve domanda informale per le prestazioni di Istruzione e Partecipazione. Un bambino deve partecipare a un corso sportivo. La famiglia riceve il supplemento per i figli. Concreta, 3-4 frasi.',
  'finance_application_bildungTeilhabe_benefitName_0':
      'Istruzione e Partecipazione (BuT)',
  'finance_application_bildungTeilhabe_description_14':
      'Il BuT comprende: materiale scolastico (195€/anno), pranzo, gite, ripetizioni, sport/cultura (15€/mese), trasporto scolastico.',
  'finance_application_bildungTeilhabe_description_16':
      'Ritira il modulo BuT presso il Jobcenter o l\'ufficio dei servizi sociali (oppure fai domanda in forma libera per lettera). Alcune città hanno moduli online.',
  'finance_application_bildungTeilhabe_description_18':
      'Allega la decisione sulle prestazioni + il certificato scolastico + eventualmente la fattura dell\'associazione.',
  'finance_application_bildungTeilhabe_description_20':
      'Ricevi un buono (es. per l\'associazione) oppure il denaro viene versato direttamente al fornitore.',
  'finance_application_bildungTeilhabe_name_10':
      'Prova dei costi (es. quota associativa)',
  'finance_application_bildungTeilhabe_name_6':
      'Prova della percezione di prestazioni',
  'finance_application_bildungTeilhabe_name_8':
      'Certificato di iscrizione scolastica',
  'finance_application_bildungTeilhabe_proTip_4':
      'Il BuT copre anche corsi di nuoto, scuola di musica e ripetizioni, non solo il materiale scolastico! Fino a 15€/mese per sport/cultura/tempo libero.',
  'finance_application_bildungTeilhabe_processingTime_2': '2–6 settimane',
  'finance_application_bildungTeilhabe_renewalNote_3':
      'Va richiesta di nuovo per ogni anno scolastico (per il materiale scolastico). Costi di associazione/corsi: ogni 6 mesi.',
  'finance_application_bildungTeilhabe_responsibleAuthority_1':
      'Jobcenter o ufficio dei servizi sociali della tua città/comune',
  'finance_application_bildungTeilhabe_title_13': 'Verifica cosa è possibile',
  'finance_application_bildungTeilhabe_title_15': 'Domanda informale o modulo',
  'finance_application_bildungTeilhabe_title_17': 'Allega le prove',
  'finance_application_bildungTeilhabe_title_19': 'Buono o pagamento diretto',
  'finance_application_bildungTeilhabe_whereToGet_11':
      'Modulo di iscrizione o fattura dell\'associazione/corso',
  'finance_application_bildungTeilhabe_whereToGet_7':
      'Decisione su Kinderzuschlag, Wohngeld, Bürgergeld o assistenza sociale',
  'finance_application_bildungTeilhabe_whereToGet_9':
      'Segreteria della scuola di tuo figlio',
  'finance_application_eingliederungshilfe_aiTemplatePrompt_5':
      'Scrivi una breve domanda informale di aiuto all\'integrazione per un bambino. Il bambino ha una disabilità e ha bisogno di sostegno per la partecipazione (es. assistenza scolastica, intervento precoce). Concreta, 3-4 frasi.',
  'finance_application_eingliederungshilfe_benefitName_0':
      'Aiuto all\'integrazione (Eingliederungshilfe)',
  'finance_application_eingliederungshilfe_description_15':
      'Disabilità psichica (autismo, ADHD, ansie) → Jugendamt. Disabilità fisica/intellettiva → ufficio dei servizi sociali. Nel dubbio: chiedi al Jugendamt.',
  'finance_application_eingliederungshilfe_description_17':
      'Basta una lettera: "Richiedo l\'aiuto all\'integrazione per mio figlio [Nome] per [diagnosi]." Allega il parere medico.',
  'finance_application_eingliederungshilfe_description_19':
      'L\'ufficio ti invita a un colloquio. Lì si discute di quale aiuto ha bisogno tuo figlio (intervento precoce, assistenza scolastica, terapia ecc.).',
  'finance_application_eingliederungshilfe_description_21':
      'Dopo la concessione inizia l\'aiuto. In caso di rifiuto: presenta ricorso (entro 4 settimane, gratuito).',
  'finance_application_eingliederungshilfe_name_10':
      'Relazione sullo sviluppo (asilo/scuola)',
  'finance_application_eingliederungshilfe_name_12':
      'Dichiarazione della scuola (per l\'assistenza scolastica)',
  'finance_application_eingliederungshilfe_name_6': 'Parere medico / diagnosi',
  'finance_application_eingliederungshilfe_name_8':
      'Domanda informale di aiuto all\'integrazione',
  'finance_application_eingliederungshilfe_proTip_4':
      'Per la disabilità psichica (es. autismo, ADHD) è competente il Jugendamt (§35a SGB VIII). Per la disabilità fisica/intellettiva l\'ufficio dei servizi sociali.',
  'finance_application_eingliederungshilfe_processingTime_2': '4–12 settimane',
  'finance_application_eingliederungshilfe_renewalNote_3':
      'Viene concesso per un periodo definito. Presenta per tempo la domanda di rinnovo.',
  'finance_application_eingliederungshilfe_responsibleAuthority_1':
      'Ufficio dei servizi sociali o Jugendamt (a seconda del tipo di disabilità)',
  'finance_application_eingliederungshilfe_title_14': 'Chiarisci la competenza',
  'finance_application_eingliederungshilfe_title_16':
      'Presenta una domanda informale',
  'finance_application_eingliederungshilfe_title_18':
      'Colloquio sul piano di aiuto',
  'finance_application_eingliederungshilfe_title_20':
      'Concessione + inizio dell\'aiuto',
  'finance_application_eingliederungshilfe_whereToGet_11':
      'L\'educatrice o l\'insegnante scrive una breve relazione',
  'finance_application_eingliederungshilfe_whereToGet_13':
      'Dirigenza scolastica o insegnante di classe',
  'finance_application_eingliederungshilfe_whereToGet_7':
      'Pediatra, SPZ (centro sociopediatrico) o specialista',
  'finance_application_eingliederungshilfe_whereToGet_9':
      'Una tua lettera all\'ufficio dei servizi sociali/Jugendamt',
  'finance_application_elterngeld_aiTemplatePrompt_5':
      'Scrivi una breve lettera di accompagnamento per una domanda di Elterngeld. Un genitore richiede l\'Elterngeld base dopo la nascita del primo figlio e pianifica la ripartizione dei mesi con il partner. Concreta e chiara.',
  'finance_application_elterngeld_benefitName_0':
      'Indennità di maternità/paternità (Elterngeld)',
  'finance_application_elterngeld_description_18':
      'Con il calcolatore ufficiale calcola quanto Elterngeld ti spetta e quale ripartizione (base/Plus/bonus di coppia) è la più adatta.',
  'finance_application_elterngeld_description_20':
      'Ogni Land ha un proprio modulo. Il modo più semplice è ElterngeldDigital (disponibile in molti Land).',
  'finance_application_elterngeld_description_22':
      'Fai copia di certificato di nascita, prove del reddito, attestazione dell\'indennità di maternità e documenti d\'identità.',
  'finance_application_elterngeld_description_24':
      'Presenta per posta o in formato digitale. I tempi di elaborazione variano molto (4–12 settimane). Consiglio: sollecita dopo 6 settimane se non ricevi notizie.',
  'finance_application_elterngeld_name_10':
      'Attestazione del datore di lavoro sull\'integrazione all\'indennità di maternità',
  'finance_application_elterngeld_name_12':
      'Prove del reddito degli ultimi 12 mesi prima della nascita',
  'finance_application_elterngeld_name_14':
      'Carta d\'identità di entrambi i genitori (copia)',
  'finance_application_elterngeld_name_15':
      'Conferma dell\'orario di lavoro previsto (per l\'Elterngeld Plus)',
  'finance_application_elterngeld_name_6':
      'Certificato di nascita del bambino (originale o copia autenticata)',
  'finance_application_elterngeld_name_8':
      'Attestazione della cassa malattia sull\'indennità di maternità',
  'finance_application_elterngeld_proTip_4':
      'La domanda puoi prepararla già PRIMA della nascita: mancherà solo il certificato di nascita. Risparmi settimane!',
  'finance_application_elterngeld_processingTime_2':
      '4–12 settimane (a seconda del Land)',
  'finance_application_elterngeld_renewalNote_3':
      'Nessuna domanda di rinnovo. Una tantum per 12–14 mesi (base) o 24–28 mesi (Plus).',
  'finance_application_elterngeld_responsibleAuthority_1':
      'Ufficio Elterngeld del tuo Land',
  'finance_application_elterngeld_title_17':
      'Usa il calcolatore dell\'Elterngeld',
  'finance_application_elterngeld_title_19':
      'Compila la domanda (online o cartacea)',
  'finance_application_elterngeld_title_21': 'Prepara i documenti',
  'finance_application_elterngeld_title_23': 'Presenta + pazienza',
  'finance_application_elterngeld_whereToGet_11':
      'Ufficio del personale del tuo datore di lavoro',
  'finance_application_elterngeld_whereToGet_13':
      'Busta paga o cartella esattoriale',
  'finance_application_elterngeld_whereToGet_16':
      'Datore di lavoro (se lavori part-time)',
  'finance_application_elterngeld_whereToGet_7': 'Anagrafe',
  'finance_application_elterngeld_whereToGet_9':
      'La tua cassa malattia (richiedila dopo la nascita)',
  'finance_application_kindergeld_aiTemplatePrompt_5':
      'Scrivi una breve e cordiale lettera di accompagnamento per una domanda di assegno familiare. Un genitore richiede per la prima volta l\'assegno familiare dopo la nascita. Mantienila semplice e concreta.',
  'finance_application_kindergeld_benefitName_0':
      'Assegno familiare (Kindergeld)',
  'finance_application_kindergeld_description_15':
      'Sul sito della Familienkasse compila online il modulo "KG1". Richiede circa 10 minuti.',
  'finance_application_kindergeld_description_17':
      'Carica la scansione del certificato di nascita e dei codici fiscali, oppure inviali per posta alla tua Familienkasse competente.',
  'finance_application_kindergeld_description_19':
      'Ricevi una decisione per posta (4–6 settimane). Il primo pagamento arriva poi ogni mese.',
  'finance_application_kindergeld_name_10':
      'Codice fiscale del genitore richiedente',
  'finance_application_kindergeld_name_12':
      'Carta d\'identità o passaporto (copia)',
  'finance_application_kindergeld_name_13': 'Coordinate bancarie (IBAN)',
  'finance_application_kindergeld_name_6': 'Certificato di nascita del bambino',
  'finance_application_kindergeld_name_8': 'Codice fiscale del bambino',
  'finance_application_kindergeld_proTip_4':
      'Presenta la domanda subito dopo la nascita: l\'assegno familiare viene pagato al massimo retroattivo di 6 mesi.',
  'finance_application_kindergeld_processingTime_2': '4–6 settimane',
  'finance_application_kindergeld_renewalNote_3':
      'Non serve una domanda di rinnovo. Viene pagato automaticamente fino al 18° (o 25°) compleanno.',
  'finance_application_kindergeld_responsibleAuthority_1':
      'Cassa per gli assegni familiari dell\'Agenzia federale per il lavoro (Familienkasse der Bundesagentur für Arbeit)',
  'finance_application_kindergeld_title_14': 'Compila la domanda online',
  'finance_application_kindergeld_title_16':
      'Carica i documenti o invia per posta',
  'finance_application_kindergeld_title_18': 'Attendi la conferma',
  'finance_application_kindergeld_whereToGet_11':
      'È riportato sulla tua cartella esattoriale o sulla busta paga',
  'finance_application_kindergeld_whereToGet_7':
      'Anagrafe (di solito te lo danno in ospedale)',
  'finance_application_kindergeld_whereToGet_9':
      'Arriva per posta dall\'Ufficio centrale federale delle imposte (circa 2–3 settimane dopo la nascita)',
  'finance_application_kinderzuschlag_aiTemplatePrompt_5':
      'Scrivi una breve motivazione concreta per una domanda di supplemento per i figli. La famiglia ha un reddito basso e ha bisogno di sostegno per i bambini. Menziona che l\'affitto rappresenta una parte importante del reddito.',
  'finance_application_kinderzuschlag_benefitName_0':
      'Supplemento per i figli (Kinderzuschlag, KiZ)',
  'finance_application_kinderzuschlag_description_17':
      'Verifica con il navigatore online se è probabile che tu abbia diritto. In caso contrario, risparmi tempo.',
  'finance_application_kinderzuschlag_description_19':
      'Compila la domanda sul sito della Familienkasse. Tieni a portata di mano le prove del reddito e i costi dell\'affitto.',
  'finance_application_kinderzuschlag_description_21':
      'Carica buste paga, contratto d\'affitto ed estratti conto, oppure inviali per posta.',
  'finance_application_kinderzuschlag_description_23':
      'Dopo 4–8 settimane arriva la decisione. Importante: dopo 6 mesi non dimenticare la domanda di rinnovo!',
  'finance_application_kinderzuschlag_name_10':
      'Estratti conto degli ultimi 3 mesi',
  'finance_application_kinderzuschlag_name_12':
      'Decisione sull\'assegno familiare',
  'finance_application_kinderzuschlag_name_14':
      'Certificato/i di nascita dei bambini',
  'finance_application_kinderzuschlag_name_15': 'Carta d\'identità (copia)',
  'finance_application_kinderzuschlag_name_6':
      'Prove del reddito degli ultimi 6 mesi',
  'finance_application_kinderzuschlag_name_8':
      'Contratto d\'affitto o prova dei costi dell\'abitazione',
  'finance_application_kinderzuschlag_proTip_4':
      'Con il navigatore KiZ della Familienkasse puoi verificare in 2 minuti se hai diritto, prima di compilare la domanda completa.',
  'finance_application_kinderzuschlag_processingTime_2': '4–8 settimane',
  'finance_application_kinderzuschlag_renewalNote_3':
      'Va richiesto di nuovo ogni 6 mesi (domanda di rinnovo).',
  'finance_application_kinderzuschlag_title_16':
      'Usa il navigatore KiZ (2 min.)',
  'finance_application_kinderzuschlag_title_20': 'Presenta i documenti',
  'finance_application_kinderzuschlag_title_22': 'Decisione + rinnovo',
  'finance_application_kinderzuschlag_whereToGet_11':
      'Online banking → stampa il PDF',
  'finance_application_kinderzuschlag_whereToGet_13':
      'L\'hai ricevuta per posta dalla Familienkasse',
  'finance_application_kinderzuschlag_whereToGet_7':
      'Busta paga del datore di lavoro, decisione sull\'Elterngeld o cartella esattoriale',
  'finance_application_kinderzuschlag_whereToGet_9':
      'Copia del tuo contratto d\'affitto + ultimo conguaglio delle spese accessorie',
  'finance_application_pflegegeld_aiTemplatePrompt_5':
      'Scrivi una breve domanda informale per prestazioni di assistenza per un bambino. Il bambino ha una disabilità/malattia cronica e ha bisogno di sostegno quotidiano. Concreta, 3-4 frasi.',
  'finance_application_pflegegeld_benefitName_0':
      'Indennità di assistenza (Pflegegeld)',
  'finance_application_pflegegeld_description_13':
      'Una chiamata basta come domanda! Di\': "Vorrei richiedere prestazioni di assistenza per mio figlio." La data della chiamata conta.',
  'finance_application_pflegegeld_description_15':
      'Annota ogni giorno di quale aiuto ha bisogno tuo figlio: lavarsi, vestirsi, mangiare, la notte, la sorveglianza. Più sei preciso, meglio è per la valutazione.',
  'finance_application_pflegegeld_description_17':
      'Il Servizio Medico viene a casa vostra. Mostra apertamente di cosa ha bisogno tuo figlio, non mostrare la "giornata buona"!',
  'finance_application_pflegegeld_description_19':
      'In linea di principio la decisione arriva entro 25 giorni lavorativi (§18c SGB XI; eccezioni possibili). Per il ricorso vale di norma un mese dalla notifica, tre mesi in caso di notifica all\'estero (§84 SGG). Verifica le istruzioni sui mezzi di ricorso.',
  'finance_application_pflegegeld_name_10':
      'Diario dell\'assistenza (2 settimane prima della valutazione)',
  'finance_application_pflegegeld_name_6':
      'Domanda informale (basta per telefono o lettera)',
  'finance_application_pflegegeld_name_8': 'Documentazione medica / diagnosi',
  'finance_application_pflegegeld_proTip_4':
      'Presenta la domanda in forma libera per telefono: una chiamata alla cassa per l\'assistenza è sufficiente! La data vale per il pagamento retroattivo.',
  'finance_application_pflegegeld_processingTime_2':
      'In linea di principio 25 giorni lavorativi; verifica le eccezioni di legge (§18c SGB XI).',
  'finance_application_pflegegeld_renewalNote_3':
      'Nessuna domanda di rinnovo. In caso di peggioramento: presenta una domanda di aumento del livello.',
  'finance_application_pflegegeld_responsibleAuthority_1':
      'Cassa per l\'assistenza (presso la tua cassa malattia)',
  'finance_application_pflegegeld_title_12':
      'Chiama la cassa per l\'assistenza',
  'finance_application_pflegegeld_title_14':
      'Tieni un diario dell\'assistenza (2 settimane)',
  'finance_application_pflegegeld_title_16':
      'Valutazione del MD (visita a domicilio)',
  'finance_application_pflegegeld_title_18': 'Decisione + eventuale ricorso',
  'finance_application_pflegegeld_whereToGet_11':
      'Modello della cassa per l\'assistenza o online',
  'finance_application_pflegegeld_whereToGet_7':
      'È sufficiente una chiamata alla tua cassa malattia/cassa per l\'assistenza',
  'finance_application_pflegegeld_whereToGet_9':
      'Pediatra, specialista o ospedale',
  'finance_application_unterhaltsvorschuss_aiTemplatePrompt_5':
      'Scrivi una breve domanda concreta per l\'anticipo sugli alimenti. Un genitore single non riceve alcun mantenimento dall\'altro genitore. Mantienila concreta e chiara, 3-4 frasi.',
  'finance_application_unterhaltsvorschuss_benefitName_0':
      'Anticipo sugli alimenti (Unterhaltsvorschuss)',
  'finance_application_unterhaltsvorschuss_description_16':
      'Telefona al tuo Jugendamt o vai di persona. Ti aiutano direttamente a compilare.',
  'finance_application_unterhaltsvorschuss_description_18':
      'Il modulo lo trovi presso il Jugendamt. Alcune città lo offrono anche online come PDF.',
  'finance_application_unterhaltsvorschuss_description_20':
      'Allega certificato di nascita, certificato di residenza e prova del mancato versamento degli alimenti.',
  'finance_application_unterhaltsvorschuss_description_22':
      'Dopo 4–8 settimane arriva la decisione. Il pagamento è mensile e retroattivo dalla data della domanda.',
  'finance_application_unterhaltsvorschuss_name_11':
      'Prova del mancato versamento degli alimenti',
  'finance_application_unterhaltsvorschuss_name_13':
      'Riconoscimento di paternità o certificato di nascita con il padre',
  'finance_application_unterhaltsvorschuss_name_9':
      'Certificato di residenza (abitazione da solo)',
  'finance_application_unterhaltsvorschuss_proTip_4':
      'Puoi richiedere l\'anticipo sugli alimenti anche retroattivo di 1 mese. Quindi non aspettare: fai domanda subito!',
  'finance_application_unterhaltsvorschuss_renewalNote_3':
      'Non serve una domanda di rinnovo. Viene pagato automaticamente fino ai 18 anni (finché sussistono le condizioni).',
  'finance_application_unterhaltsvorschuss_responsibleAuthority_1':
      'Ufficio per la tutela dei minori (Jugendamt) della tua città/comune',
  'finance_application_unterhaltsvorschuss_title_15': 'Contatta il Jugendamt',
  'finance_application_unterhaltsvorschuss_title_17': 'Compila la domanda',
  'finance_application_unterhaltsvorschuss_title_21': 'Attendi la decisione',
  'finance_application_unterhaltsvorschuss_whereToGet_10':
      'Ufficio del cittadino: dimostra che vivi da solo con il bambino',
  'finance_application_unterhaltsvorschuss_whereToGet_12':
      'Es. una lettera all\'ex rimasta senza risposta, un titolo per gli alimenti o una tua dichiarazione',
  'finance_application_unterhaltsvorschuss_whereToGet_14':
      'Anagrafe o Jugendamt',
  'finance_application_wohngeld_aiTemplatePrompt_5':
      'Scrivi una breve lettera di accompagnamento per una domanda di contributo per l\'affitto. Una famiglia con figli richiede per la prima volta il Wohngeld perché l\'affitto rappresenta una parte importante del reddito. Concreta e cordiale.',
  'finance_application_wohngeld_benefitName_0':
      'Contributo per l\'affitto (Wohngeld)',
  'finance_application_wohngeld_description_16':
      'Con il calcolatore ufficiale Wohngeld-Plus del BMWSB verifica se e quanto Wohngeld ti spetta.',
  'finance_application_wohngeld_description_18':
      'Il modulo lo trovi presso il municipio/ufficio del cittadino o come PDF online. Alcuni comuni offrono anche domande online.',
  'finance_application_wohngeld_description_20':
      'Allega contratto d\'affitto, prove del reddito e conguaglio delle spese accessorie. Nel dubbio, meglio inviare troppo che troppo poco.',
  'finance_application_wohngeld_description_22':
      'Dopo 3–8 settimane arriva la decisione. Imposta un promemoria per la domanda di rinnovo (10 mesi dopo la concessione).',
  'finance_application_wohngeld_name_10': 'Conguaglio delle spese accessorie',
  'finance_application_wohngeld_name_12':
      'Carte d\'identità di tutti i membri del nucleo (copie)',
  'finance_application_wohngeld_name_13': 'Certificato di residenza',
  'finance_application_wohngeld_name_6':
      'Prove del reddito di tutti i membri del nucleo',
  'finance_application_wohngeld_name_8': 'Contratto d\'affitto (copia)',
  'finance_application_wohngeld_name_9':
      'Ultima ricevuta dell\'affitto o estratto conto con il pagamento dell\'affitto',
  'finance_application_wohngeld_proTip_4':
      'Dopo la riforma del Wohngeld del 2023 molte più famiglie ne hanno diritto, anche con reddito medio. Prova a verificarlo!',
  'finance_application_wohngeld_processingTime_2':
      '3–8 settimane (a seconda del comune)',
  'finance_application_wohngeld_renewalNote_3':
      'Periodo di concessione: 12 mesi. Presenta per tempo la domanda di rinnovo (2 mesi prima).',
  'finance_application_wohngeld_responsibleAuthority_1':
      'Ufficio Wohngeld della tua città/comune',
  'finance_application_wohngeld_title_15': 'Usa il calcolatore del Wohngeld',
  'finance_application_wohngeld_title_17':
      'Fai domanda al tuo ufficio Wohngeld',
  'finance_application_wohngeld_title_19': 'Allega i documenti',
  'finance_application_wohngeld_title_21':
      'Attendi la decisione + imposta un promemoria',
  'finance_application_wohngeld_whereToGet_11': 'Dal proprietario (ogni anno)',
  'finance_application_wohngeld_whereToGet_14':
      'Ufficio del cittadino / anagrafe',
  'finance_application_wohngeld_whereToGet_7':
      'Busta paga, decisione sulla pensione, decisione sull\'Elterngeld',
  'finance_apply_positions': 'Applica le voci',
  'finance_average_amount': 'Media: ~{amount}',
  'finance_based_on_children_age': 'In base all\'età dei vostri bambini:',
  'finance_benefit_de_but':
      'Istruzione e Partecipazione (BuT)|Materiale scolastico, gite, ripetizioni, pranzo, associazione sportiva.|Prestazioni in natura + 195€/anno per il materiale scolastico|Famiglie con KiZ, Wohngeld o Bürgergeld.',
  'finance_benefit_de_eingliederungshilfe':
      'Aiuto all\'integrazione (Eingliederungshilfe)|Sostegno per bambini con disabilità: terapia, assistenza scolastica, intervento precoce.|Individuale (prestazioni in natura)|Bambini con disabilità presente o a rischio.',
  'finance_benefit_de_elterngeld':
      'Indennità di maternità/paternità (Elterngeld)|Sostituzione del reddito dopo la nascita; la versione base e la Plus hanno periodi di erogazione diversi.|Base: 300€–1.800€/mese; Plus: 150€–900€/mese (senza supplementi)|Nucleo in comune, assistenza diretta al figlio e nessuna attività lavorativa a tempo pieno; verifica ulteriori condizioni ed eccezioni.',
  'finance_benefit_de_kindergeld':
      'Assegno familiare (Kindergeld)|Pagamento mensile per i figli; per i maggiorenni valgono condizioni aggiuntive.|259€/bambino|In linea di principio per i minorenni; verifica mantenimento, nucleo familiare e residenza, oltre ai casi particolari.',
  'finance_benefit_de_kinderzuschlag':
      'Supplemento per i figli (Kinderzuschlag, KiZ)|Sostegno aggiuntivo per famiglie con reddito basso.|fino a 297€/bambino/mese|Figlio sotto i 25 anni nel nucleo, con assegno familiare; reddito, patrimonio e bisogni della famiglia da verificare caso per caso.',
  'finance_benefit_de_pflegegeld':
      'Indennità di assistenza (Pflegegeld)|Per bambini con disabilità o malattia cronica che necessitano di assistenza.|347 / 599 / 800 / 990€/mese (livello di assistenza 2 / 3 / 4 / 5)|Livello di assistenza da 2 a 5; l\'assistenza domiciliare deve essere garantita in modo adeguato.',
  'finance_benefit_de_unterhaltsvorschuss':
      'Anticipo sugli alimenti (Unterhaltsvorschuss)|Quando l\'altro genitore non versa gli alimenti, oppure li versa in modo irregolare o insufficiente.|227 / 299 / 394€/mese (0–5 / 6–11 / 12–17 anni)|Il figlio vive con il genitore single; per i 12-17 anni valgono condizioni aggiuntive.',
  'finance_benefit_de_wohngeld':
      'Contributo per l\'affitto (Wohngeld)|Sostegno all\'affitto per famiglie con reddito basso.|calcolato individualmente|Dipende dalla dimensione del nucleo, dall\'affitto/onere considerato e dal reddito complessivo.',
  'finance_benefits_country_intro':
      'Queste prestazioni potrebbero essere rilevanti per voi in {country}.',
  'finance_benefits_filtered':
      'Informazioni salvate. Tutte le prestazioni restano visibili; reddito e attività lavorativa non sono una verifica del diritto.',
  'finance_camera': 'Fotocamera',
  'finance_care_activities': 'Attività di cura',
  'finance_care_removed': 'Voce di cura rimossa.',
  'finance_care_saved': 'Voce di cura salvata.',
  'finance_care_updated': 'Voce di cura aggiornata.',
  'finance_category_essen': 'Cibo e bevande',
  'finance_category_freizeit': 'Tempo libero e corsi',
  'finance_category_gesundheit': 'Salute',
  'finance_category_kita': 'Asilo / assistenza',
  'finance_category_kleidung': 'Abbigliamento',
  'finance_category_mobilität': 'Mobilità',
  'finance_category_sonstiges': 'Altro',
  'finance_category_wohnen': 'Casa (quota del bambino)',
  'finance_close': 'Chiudi',
  'finance_content_austria_amount_10':
      'Conto: 17,65–41,14€/giorno; in base al reddito: 80% degli ultimi redditi, max. 80,12€/giorno',
  'finance_content_austria_amount_3':
      '138,40 / 148 / 171,80 / 200,40€/mese (dai 0 / 3 / 10 / 19 anni; senza supplementi)',
  'finance_content_austria_amount_6': '70,90€/bambino/mese',
  'finance_content_austria_description_2':
      'Sostegno mensile per figlio, graduato in base all\'età.',
  'finance_content_austria_description_5': 'Detrazione fiscale per figlio.',
  'finance_content_austria_description_9':
      'Dopo la nascita, con diversi modelli.',
  'finance_content_austria_eligibility_7':
      'Viene pagata insieme all\'assegno familiare; nessuna domanda separata.',
  'finance_content_austria_name_1': 'Assegno familiare (Familienbeihilfe)',
  'finance_content_austria_name_4':
      'Detrazione per i figli (Kinderabsetzbetrag)',
  'finance_content_austria_name_8':
      'Assegno per l\'assistenza all\'infanzia (Kinderbetreuungsgeld)',
  'finance_content_generic_description_2':
      'La maggior parte dei paesi paga prestazioni familiari mensili. Verifica presso la tua autorità locale.',
  'finance_content_generic_description_4':
      'Molti paesi offrono contributi per l\'affitto alle famiglie.',
  'finance_content_generic_description_6':
      'Verifica se il tuo paese sovvenziona l\'assistenza all\'infanzia.',
  'finance_content_generic_name_1': 'Assegno familiare / Child Benefit',
  'finance_content_generic_name_3': 'Sostegno per l\'abitazione',
  'finance_content_generic_name_5': 'Contributo per l\'assistenza',
  'finance_content_switzerland_amount_3':
      'almeno 215 Fr./bambino/mese; a livello cantonale eventualmente di più',
  'finance_content_switzerland_amount_6':
      'almeno 268 Fr./bambino/mese; a livello cantonale eventualmente di più',
  'finance_content_switzerland_description_2':
      'Varia da cantone a cantone, per figlio.',
  'finance_content_switzerland_description_5':
      'Formazione post-obbligatoria, dai 15 anni al più presto fino ai 25 al più tardi; verifica i limiti mensili esatti.',
  'finance_content_switzerland_name_1': 'Assegno per i figli (Kinderzulage)',
  'finance_content_switzerland_name_4':
      'Assegno di formazione (Ausbildungszulage)',
  'finance_content_turkey_amount_3':
      '1° figlio: 5.000₺ una tantum; 2°: 1.500₺/mese; 3°+: 5.000₺/mese',
  'finance_content_turkey_amount_7': 'in base al reddito',
  'finance_content_turkey_description_2':
      'Nuovo programma di sostegno alla nascita per i nati dal 01.01.2025; pagamenti ricorrenti dalla domanda fino al 60° mese incluso.',
  'finance_content_turkey_description_6':
      'Assegno familiare mensile per le famiglie.',
  'finance_content_turkey_description_9':
      'Sostegno sociale ed economico tramite İl Müdürlüğü/Sosyal Hizmet Merkezi.',
  'finance_content_turkey_eligibility_10':
      'Valutazione sociale individuale della situazione familiare, economica e regionale.',
  'finance_content_turkey_eligibility_4':
      'Cittadinanza turca e residenza in Türkiye; verifica ufficialmente le ulteriori condizioni della domanda.',
  'finance_content_turkey_name_1': 'Dogum Yardimi',
  'finance_content_turkey_name_5': 'Cocuk Parasi',
  'finance_content_turkey_name_8': 'Sostegno sociale ed economico (SED)',
  'finance_content_uk_amount_3':
      '£27,05/settimana (figlio maggiore o unico), £17,90/settimana (figli successivi)',
  'finance_content_uk_amount_6':
      '£303,94/mese per figlio; in più £47,94 per il primo figlio nato prima del 6 aprile 2017',
  'finance_content_uk_amount_9':
      'fino a £500/3 mesi (£2.000/anno); figlio con disabilità: £1.000/3 mesi (£4.000/anno)',
  'finance_content_uk_description_2': 'Pagamento settimanale per ogni figlio.',
  'finance_content_uk_description_5':
      'Sostegno aggiuntivo per famiglie con reddito basso.',
  'finance_content_uk_description_8':
      'Lo Stato aggiunge £2 ogni £8 versate sul conto per l\'assistenza all\'infanzia.',
  'finance_content_uk_name_1': 'Child Benefit',
  'finance_content_uk_name_4': 'Universal Credit (Child Element)',
  'finance_content_uk_name_7': 'Tax-Free Childcare',
  'finance_content_uk_note_10': 'Divisa, borsa, scarpe, cancelleria',
  'finance_copy_data': 'Copia i dati',
  'finance_country_at': 'Austria',
  'finance_country_ch': 'Svizzera',
  'finance_country_de': 'Germania',
  'finance_country_gb': 'Regno Unito',
  'finance_country_generic': 'Altro paese',
  'finance_country_tr': 'Turchia',
  'finance_create_profile_for_milestones':
      'Crea un profilo nella rete dei genitori per vedere i traguardi personalizzati.',
  'finance_delete_care': 'Elimina voce di cura',
  'finance_delete_expense': 'Elimina spesa',
  'finance_edit_care': 'Modifica voce di cura',
  'finance_edit_expense': 'Modifica spesa',
  'finance_enter_childcare_de':
      'Inserisci sopra i costi dell\'asilo: calcolerò il tuo risparmio fiscale.',
  'finance_enter_childcare_generic':
      'Inserisci i tuoi costi di assistenza all\'infanzia: ti mostrerò la deducibilità.',
  'finance_entries_in': 'Voci in',
  'finance_estimated_months': 'Stimato tra {months} mesi ({year})',
  'finance_estimated_one_month': 'Stimato tra un mese ({year})',
  'finance_expense_removed': 'Spesa rimossa.',
  'finance_expense_updated': 'Spesa aggiornata.',
  'finance_export_csv': 'Esporta CSV',
  'finance_export_pdf': 'Condividi PDF',
  'finance_fair_settlement': 'Pareggio mensile equo',
  'finance_familienbonus_body':
      'In Austria esiste il Familienbonus Plus, una detrazione fiscale per figlio (fino a 2.000 €/anno fino al 18° compleanno). Si richiede con la dichiarazione dei redditi o tramite il datore di lavoro.',
  'finance_familienbonus_title': 'Bonus famiglia Plus',
  'finance_five_year_recommendation':
      'Nei prossimi 5 anni vi aspettano circa {total}. Con ~{monthly}/mese siete preparati.',
  'finance_free_support_in': 'Punti di supporto gratuiti in {country}:',
  'finance_gallery': 'Galleria',
  'finance_goal_in_one_year': 'Tra 1 anno · ~{amount}',
  'finance_goal_in_years': 'Tra {years} anni · ~{amount}',
  'finance_goal_months_on_time':
      'Con {amount}/mese dovresti raggiungere l\'obiettivo stimato entro {months} mesi.',
  'finance_goal_months_shortfall':
      'Con {amount}/mese probabilmente non basta ancora per l\'obiettivo stimato tra {months} mesi.',
  'finance_goal_projection_almost':
      'Con {amount}/mese raggiungi quasi l\'obiettivo tra {years} anni.',
  'finance_goal_projection_on_time':
      'Con {amount}/mese raggiungi l\'obiettivo in tempo tra {years} anni.',
  'finance_guide_subtitle':
      'Descrivete la vostra situazione: la guida vi orienta.',
  'finance_guide_title': 'A cosa abbiamo diritto?',
  'finance_hero_subtitle':
      'Meno tabelle, più tempo con i figli: suddivisione OCR, equità nelle cure e rilevatore di risparmio in un\'unica dashboard.',
  'finance_hero_title': 'Le finanze familiari, ripensate',
  'finance_in_years': 'Tra {years} anni ({year})',
  'finance_in_years_short': 'tra {years} anni',
  'finance_income_high': 'Più di 4.000€',
  'finance_income_low': 'Meno di 2.000€',
  'finance_income_medium': '2.000–4.000€',
  'finance_individual_split': '100% individuale',
  'finance_label_amount': 'Importo',
  'finance_label_care_type': 'Tipo di cura',
  'finance_label_category': 'Categoria',
  'finance_label_credit_value': 'Valore del credito',
  'finance_label_distance': 'Distanza (km)',
  'finance_label_hours': 'Ore',
  'finance_label_marketplace': 'Mercatino',
  'finance_label_note': 'Nota',
  'finance_label_paid_by': 'Pagato da',
  'finance_label_parent': 'Genitore',
  'finance_label_product_goal': 'Prodotto / obiettivo',
  'finance_label_retail_price': 'Prezzo da nuovo (€)',
  'finance_label_secondhand_price': 'Prezzo di seconda mano (€)',
  'finance_label_split_type': 'Tipo di divisione',
  'finance_label_title': 'Titolo',
  'finance_legacy_confirm':
      'I valori finanziari, le liste di controllo della guida e delle domande presenti finora su questo dispositivo sono tuoi? Con la tua conferma vengono assegnati a questo account. I valori già presenti nell\'account hanno la precedenza; le liste di controllo vengono unite. I valori di un altro paese non vengono acquisiti come nuova valuta. I dati originali precedenti restano in locale. Non viene pubblicato nulla.',
  'finance_legacy_notice':
      'Su questo dispositivo ci sono dati finanziari e liste di controllo non assegnati. Non vengono usati automaticamente. Accedi per acquisirli dopo aver confermato la proprietà.',
  'finance_legacy_title': 'Adottare i dati finanziari locali',
  'finance_legal_disclaimer':
      'Questa non è una consulenza legale. Verifica i tuoi diritti presso l\'ufficio competente o un centro di consulenza.',
  'finance_link_open_failed':
      'Non è stato possibile aprire il link. Riprova più tardi.',
  'finance_load_failed':
      'Non è stato possibile caricare i dati finanziari locali. Riprova.',
  'finance_mama': 'Mamma',
  'finance_milestone_ausbildung': 'Formazione/università',
  'finance_milestone_ausbildung_note': 'Primo corredo, trasloco, cauzione',
  'finance_milestone_fahrrad': 'Prima bicicletta',
  'finance_milestone_fahrrad_note': 'Bicicletta per bambini + casco',
  'finance_milestone_fuehrerschein': 'Patente di guida',
  'finance_milestone_fuehrerschein_note': 'Lezioni di guida + esami',
  'finance_milestone_klassenfahrt': 'Prima gita scolastica',
  'finance_milestone_klassenfahrt_note':
      '3–5 giorni, inclusi i soldi per le piccole spese',
  'finance_milestone_schulstart': 'Inizio della scuola',
  'finance_milestone_schulstart_note':
      'Zaino, penne, sacca da ginnastica, cono di dolciumi per il primo giorno',
  'finance_milestone_smartphone': 'Primo smartphone',
  'finance_milestone_smartphone_note':
      'Dispositivo + custodia + primo contratto',
  'finance_month': 'Mese:',
  'finance_monthly_mix': 'Il mix del mese a colpo d\'occhio',
  'finance_monthly_recommendation': 'Consiglio: metti da parte {amount}/mese.',
  'finance_next_year': 'L\'anno prossimo ({year})',
  'finance_no_items_recognized': 'Nessuna voce elaborabile riconosciuta.',
  'finance_no_parental_leave': 'No / congedo parentale',
  'finance_not_entered': 'Non ancora indicato',
  'finance_number_invalid':
      'Inserisci un importo valido, non negativo e con al massimo due cifre decimali.',
  'finance_ocr_failed': 'Importazione dello scontrino non riuscita. Riprova.',
  'finance_ocr_split': 'Divisione OCR (60/40)',
  'finance_orientation_only':
      'Solo orientamento, non una verifica del diritto. Qui reddito, attività lavorativa e stato familiare non escludono alcuna prestazione. L\'ente competente valuta il tuo caso specifico.',
  'finance_papa': 'Papà',
  'finance_qr_copied': 'Dati QR copiati.',
  'finance_qr_settlement': 'Pareggio con QR',
  'finance_quick_start': 'Avvio rapido',
  'finance_recent_ocr': 'Ultime voci da scansione',
  'finance_save_orientation': 'Salva le informazioni per l\'orientamento',
  'finance_saved_so_far': 'Risparmiato finora',
  'finance_saving_tip_de':
      'Spese di assistenza all\'infanzia agevolate: 80%, al massimo 4.800€/anno per bambino, come onere deducibile (§10 EStG). Verifica le condizioni.',
  'finance_saving_tip_generic':
      'Verifica se nel tuo paese le spese di assistenza all\'infanzia sono deducibili dalle tasse.',
  'finance_savings_rate_month': 'Quota di risparmio/mese',
  'finance_scan_receipt': 'Scansiona lo scontrino',
  'finance_scan_running': 'Scansione in corso...',
  'finance_share_failed':
      'Non è stato possibile condividere il riepilogo. Riprova.',
  'finance_share_footer':
      '📱 Creato con ParentPeak: il tuo compagno genitoriale',
  'finance_share_monthly_costs': '💰 Costi mensili per figlio: ~{amount}/mese',
  'finance_share_next_milestones': '🎯 Prossime tappe:',
  'finance_share_possible_benefits': '📋 Aiuti possibili:',
  'finance_share_subject': 'Panoramica del budget familiare',
  'finance_share_title': '{flag} Panoramica del budget familiare – {country}',
  'finance_share_yearly_costs': '   {amount}/anno',
  'finance_standard_split': 'Divisione standard',
  'finance_start_application_helper': 'Avvia l\'assistente alle domande',
  'finance_status_check_required': 'Verifica necessaria',
  'finance_status_income_dependent': 'In base al reddito',
  'finance_status_universal': 'Prestazione generale · verifica le condizioni',
  'finance_support_at_food': 'Aiuto alimentare – Tafel Austria',
  'finance_support_caritas': 'Centri di consulenza Caritas',
  'finance_support_de_clothing': 'Guardaroba solidale – Caritas',
  'finance_support_de_debt':
      'Consulenza gratuita sui debiti (centro consumatori)',
  'finance_support_de_education': 'Richiedi Istruzione e Partecipazione (BuT)',
  'finance_support_de_food': 'Aiuto alimentare – Tafel Germania',
  'finance_support_debt': 'Consulenza gratuita sui debiti',
  'finance_support_family_advice': 'Aiuto e consulenza per le famiglie',
  'finance_support_food_bank': 'Trova un banco alimentare locale',
  'finance_tab_benefits': 'Aiuti',
  'finance_tab_milestones': 'Tappe',
  'finance_tab_overview': 'Panoramica',
  'finance_tax_actual_deductible': 'Onere deducibile nell\'esempio',
  'finance_tax_childcare_year': 'Costi asilo/anno',
  'finance_tax_deductible_share': 'Quota agevolata (80%)',
  'finance_tax_estimated_saving': 'Risparmio stimato (30%)',
  'finance_tax_example_limits':
      'Esempio per un bambino, non è una verifica del diritto né una ripartizione dei costi tra i figli. Spese di assistenza agevolate: bambino nel nucleo e sotto i 14 anni oppure eccezione di legge per disabilità; sono necessari fattura e pagamento sul conto del fornitore. Lezioni, sport e tempo libero non sono agevolati. Il 30% è solo un\'aliquota ipotizzata.',
  'finance_tax_max_expense': 'Onere deducibile max.',
  'finance_tax_more_info':
      '🔗 Maggiori informazioni presso l\'Agenzia delle Entrate →',
  'finance_tax_saving_potential': 'Potenziale di risparmio fiscale',
  'finance_tax_saving_summary':
      'Esempio: {deductible} di onere deducibile → circa {savings} di risparmio fiscale/anno ipotizzando il 30%',
  'finance_title': 'Finanze e budget',
  'finish': 'Concludi',
  'food_empty_nearby_subtitle':
      'Sii il primo! Premi in basso su «Ho cucinato in più!»',
  'food_empty_nearby_title': 'Ancora nessuna offerta vicino a te',
  'food_for_you': 'Per te',
  'food_moderation_note_hint': 'Facoltativo: breve nota per la moderazione',
  'food_parent_notes': 'Note per i genitori',
  'for_holidays_info':
      'Per festività, vacanze scolastiche e prestazioni regionali.',
  'format_practice': 'Pratica',
  'format_reflection': 'Riflessione',
  'format_understand': 'Capire',
  'found': 'Trovato',
  'fridge_add_ingredient_hint': 'Aggiungi ingrediente …',
  'fridge_add_missing_many':
      'Aggiungi gli ingredienti mancanti alla lista della spesa',
  'fridge_add_missing_one':
      'Aggiungi l\'ingrediente mancante alla lista della spesa',
  'fridge_choose_photo': 'Scegli',
  'fridge_consent_accept': 'Accetto, analizza la foto',
  'fridge_consent_body':
      'Per il riconoscimento degli ingredienti la tua foto viene inviata tramite il backend ParentPeak a Google Gemini. I contenuti delle immagini non vengono anonimizzati; non mostrare persone, note private o indirizzi. Per la ricetta successiva vengono inviati a Google Gemini gli ingredienti confermati, l\'età del bambino e le informazioni sulle allergie disponibili. L\'app non salva la foto come bozza permanente. Questo consenso facoltativo vale per il flusso IA del frigo e viene salvato per il tuo account attuale o per la modalità ospite su questo dispositivo. Non pubblica né la foto né la ricetta. Senza consenso non viene avviata alcuna richiesta all\'IA.',
  'fridge_consent_failed':
      'Non è stato possibile confermare il consenso all\'IA del frigo. Senza un consenso confermato non viene avviata alcuna nuova richiesta all\'IA.',
  'fridge_consent_title': 'Analizzare la foto con l\'IA',
  'fridge_detected_ingredients': 'Ingredienti riconosciuti',
  'fridge_edit_ingredients_hint':
      'Tocca ✕ per rimuovere qualcosa, oppure aggiungi qui sotto.',
  'fridge_generating_recipe': 'Sto preparando una ricetta …',
  'fridge_ingredients_required': 'Aggiungi almeno un ingrediente.',
  'fridge_ingredients_title': 'Ingredienti',
  'fridge_inspecting_photo': 'Sto guardando la tua foto …',
  'fridge_intro':
      'Scatta una foto dei tuoi alimenti: riconosco gli ingredienti e ti propongo una ricetta adatta ai bambini.',
  'fridge_missing_title': 'Manca ancora',
  'fridge_new_photo': 'Nuova foto',
  'fridge_no_ingredients':
      'Ancora nessun ingrediente: aggiungine qualcuno qui sotto.',
  'fridge_no_ingredients_detected':
      'Non sono riuscito a riconoscere con certezza alcun ingrediente. Puoi aggiungerli facilmente qui sotto.',
  'fridge_photo_processing_failed': 'Non è stato possibile elaborare la foto.',
  'fridge_photo_question': 'Cosa c\'è nel frigo?',
  'fridge_preparation_title': 'Preparazione',
  'fridge_recipe_generation_failed':
      'Non sono riuscito a creare una ricetta in questo momento. Riprova tra poco.',
  'fridge_restart': 'Ricomincia',
  'fridge_save_success': 'Ricetta {destination}. 🍳',
  'fridge_saved_friends': 'condivisa con i tuoi amici',
  'fridge_saved_private': 'salvata nelle tue ricette di famiglia',
  'fridge_saved_public': 'condivisa con tutte le famiglie',
  'fridge_share_to_family': 'Condividi nelle ricette di famiglia',
  'fridge_shared_to_family': 'Salvata nelle ricette di famiglia',
  'fridge_shopping_added_many':
      '{count} ingredienti aggiunti alla lista della spesa. 🛒',
  'fridge_shopping_added_one':
      '1 ingrediente aggiunto alla lista della spesa. 🛒',
  'fridge_suggest_recipe': 'Proponi una ricetta',
  'fridge_take_photo': 'Scatta una foto',
  'fridge_title': 'Con quello che c\'è',
  'friend_chat_request_failed':
      'La richiesta di chat non è riuscita. Controlla il tuo accesso e riprova.',
  'hide_action': 'Nascondi',
  'hide_offer': 'Nascondere l\'offerta?',
  'holiday_settings_title': 'Festività e vacanze scolastiche',
  'holidays_title': 'Festività e vacanze scolastiche',
  'home_activity_baby_10_materials': 'Palla morbida',
  'home_activity_baby_10_tip':
      'Far rotolare la palla: sedetevi uno di fronte all\'altro e fate rotolare una palla morbida.',
  'home_activity_baby_11_materials': 'Niente di necessario',
  'home_activity_baby_11_tip':
      'Ninna nanna: culla il tuo bambino sulle ginocchia e canticchia un motivo tranquillo.',
  'home_activity_baby_12_materials': 'Niente di necessario',
  'home_activity_baby_12_tip':
      'Gioco delle parti del corpo: chiedi «Dov\'è il tuo naso?» e nominatele insieme.',
  'home_activity_baby_13_materials': 'Bottiglia di plastica, riso o lenticchie',
  'home_activity_baby_13_tip':
      'Bottiglia sonaglio: metti riso o lenticchie in una bottiglia di plastica vuota.',
  'home_activity_baby_14_materials': 'Marsupio o passeggino',
  'home_activity_baby_14_tip':
      'Passeggiata della meraviglia: camminate piano e nominate tutto ciò che vedete e sentite.',
  'home_activity_baby_15_materials': 'Niente di necessario',
  'home_activity_baby_15_tip':
      'Ritmo con le mani: imparate insieme un semplice gioco di battito di mani.',
  'home_activity_baby_1_materials': 'Fazzoletti, coperta',
  'home_activity_baby_1_tip':
      'Nascondino con i fazzoletti: ti nascondi, il tuo bambino cerca. Favorisce la permanenza dell\'oggetto.',
  'home_activity_baby_2_materials': 'Niente di necessario',
  'home_activity_baby_2_tip':
      'Gara a gattoni: gattonate insieme per casa. Risate garantite.',
  'home_activity_baby_3_materials': 'Pentole, cucchiai di legno',
  'home_activity_baby_3_tip':
      'Orchestra di pentole: pentole e cucchiai di legno diventano strumenti e sviluppano il senso del ritmo.',
  'home_activity_baby_4_materials': 'Bolle di sapone',
  'home_activity_baby_4_tip':
      'Caccia alle bolle: allenate in modo giocoso la coordinazione occhio-mano, dentro o fuori.',
  'home_activity_baby_5_materials': 'Niente di necessario',
  'home_activity_baby_5_tip':
      'Giochi di dita cantati: accompagnate una filastrocca con semplici movimenti delle dita.',
  'home_activity_baby_6_materials': 'Bicchieri di plastica o cubi',
  'home_activity_baby_6_tip':
      'Costruire e abbattere una torre: impila bicchieri e lascia che il bambino li faccia cadere.',
  'home_activity_baby_7_materials': 'Specchio',
  'home_activity_baby_7_tip':
      'Gioco dello specchio: sedetevi davanti a uno specchio e imitate insieme le espressioni del viso.',
  'home_activity_baby_8_materials': 'Ciotola, acqua, bicchieri, cucchiai',
  'home_activity_baby_8_tip':
      'Divertimento con l\'acqua: immergete bicchieri e cucchiai in una ciotola con acqua tiepida.',
  'home_activity_baby_9_materials':
      'Carta di giornale, alluminio, panno morbido',
  'home_activity_baby_9_tip':
      'Esplorare la carta che fruscia: toccate e accartocciate insieme carte e tessuti diversi.',
  'home_activity_school_10_materials': 'Vaso, terra, semi, piccolo quaderno',
  'home_activity_school_10_tip':
      'Progetto pianta: seminate e annotate ogni giorno la crescita.',
  'home_activity_school_11_materials': 'Carta, busta, penna',
  'home_activity_school_11_tip':
      'Lettera al futuro: scrivete oggi una lettera al vostro io tra cinque anni.',
  'home_activity_school_12_materials': 'Contenuto del frigo, utensili',
  'home_activity_school_12_tip':
      'Sfida in cucina: ogni membro della famiglia prepara un piatto o parte del pasto.',
  'home_activity_school_13_materials':
      'Piccolo quaderno, matite, matite colorate',
  'home_activity_school_13_tip':
      'Diario della natura: disegnate e nominate fuori uccelli, insetti e piante.',
  'home_activity_school_14_materials': 'Carta, matite, oggetti quotidiani',
  'home_activity_school_14_tip':
      'Escape room familiare: inventate e risolvete insieme enigmi con oggetti di tutti i giorni.',
  'home_activity_school_15_materials': 'App del cielo stellato, coperta',
  'home_activity_school_15_tip':
      'Osservare il cielo stellato: cercate la sera le costellazioni con un\'app.',
  'home_activity_school_1_materials': 'Carta, matite, piccolo tesoro',
  'home_activity_school_1_tip':
      'Caccia al tesoro al parco: scrivete indizi, pianificate un percorso e nascondete un tesoro.',
  'home_activity_school_2_materials': 'Carta, matite',
  'home_activity_school_2_tip':
      'Quiz di famiglia: ognuno scrive cinque domande su di sé. Chi conosce meglio gli altri?',
  'home_activity_school_3_materials': 'Smartphone con app di geocaching',
  'home_activity_school_3_tip':
      'Geocaching: cercate fuori nascondigli reali con un\'app gratuita.',
  'home_activity_school_4_materials': 'Carta, matite, matite colorate',
  'home_activity_school_4_tip':
      'Disegnare un fumetto: raccontate insieme una breve storia come striscia a fumetti.',
  'home_activity_school_5_materials': 'Smartphone, lista stampata',
  'home_activity_school_5_tip':
      'Safari fotografico: cercate con la fotocamera cose rosse, rotonde o morbide.',
  'home_activity_school_6_materials':
      'Bicarbonato, aceto, limone, bicchiere, cotton fioc',
  'home_activity_school_6_tip':
      'Laboratorio di scienze: provate un vulcano al bicarbonato o scrittura segreta con succo di limone.',
  'home_activity_school_7_materials': 'Coperte, cuscini, luci, torcia',
  'home_activity_school_7_tip':
      'Campeggio in salotto: montate una tenda con coperte e cuscini per una notte in casa.',
  'home_activity_school_8_materials': 'Giochi da tavolo, snack',
  'home_activity_school_8_tip':
      'Torneo di giochi da tavolo: giocate tre turni e contate insieme i punti.',
  'home_activity_school_9_materials': 'Smartphone, travestimenti facoltativi',
  'home_activity_school_9_tip':
      'Girare un cortometraggio: inventate una storia, assegnate i ruoli e filmatela.',
  'home_activity_toddler_10_materials': 'Materiali naturali',
  'home_activity_toddler_10_tip':
      'Mandala di natura: disponete foglie, sassi e rametti in cerchio sul pavimento.',
  'home_activity_toddler_11_materials': 'Sedie, coperte, cuscini',
  'home_activity_toddler_11_tip':
      'Percorso a ostacoli: costruite tunnel e ponti con sedie, coperte e cuscini.',
  'home_activity_toddler_12_materials': 'Acquerelli, bicchieri, acqua, carta',
  'home_activity_toddler_12_tip':
      'Esperimenti di colore: mescolate gli acquerelli e scoprite insieme nuovi colori.',
  'home_activity_toddler_13_materials': 'Piccolo quaderno, matite',
  'home_activity_toddler_13_tip':
      'Quaderno del tempo: disegnate ogni giorno sole, nuvole o pioggia in un quaderno.',
  'home_activity_toddler_14_materials': 'Ciotola, acqua, materiali naturali',
  'home_activity_toddler_14_tip':
      'Cucina di fango fuori: preparate una zuppa immaginaria con acqua, terra e foglie.',
  'home_activity_toddler_15_materials': 'Pennarelli adatti alla pelle, mani',
  'home_activity_toddler_15_tip':
      'Teatro delle dita: disegnate volti sulle dita e inventate insieme una storia.',
  'home_activity_toddler_1_materials': 'Carta, matite, cinque piccoli oggetti',
  'home_activity_toddler_1_tip':
      'Caccia al tesoro in salotto: nascondete cinque cose e disegnate una mappa del tesoro.',
  'home_activity_toddler_2_materials': 'Vestiti vecchi, accessori',
  'home_activity_toddler_2_tip':
      'Travestirsi con l\'armadio: fate teatro con vestiti vecchi, cappelli e fazzoletti.',
  'home_activity_toddler_3_materials':
      'Cuscini, asciugamani, pellicola, coperte',
  'home_activity_toddler_3_tip':
      'Percorso a piedi nudi: sentite con i piedi cuscini, asciugamani e altre superfici.',
  'home_activity_toddler_4_materials': 'Sassi, acquerelli, pennello',
  'home_activity_toddler_4_tip':
      'Dipingere i sassi: raccogliete sassi fuori e decorateli dentro con gli acquerelli.',
  'home_activity_toddler_5_materials':
      'Scatoloni grandi, nastro adesivo, matite',
  'home_activity_toddler_5_tip':
      'Castello di cartone: trasformate scatoloni grandi in case, auto o razzi.',
  'home_activity_toddler_6_materials':
      'Farina, sale, acqua, olio, colorante alimentare',
  'home_activity_toddler_6_tip':
      'Pasta modellabile fatta in casa: mescolate farina, sale, acqua e colorante alimentare.',
  'home_activity_toddler_7_materials': 'Stivali di gomma, giacca antipioggia',
  'home_activity_toddler_7_tip':
      'Saltare nelle pozzanghere: dopo la pioggia, mettete gli stivali e via!',
  'home_activity_toddler_8_materials': 'Farina, uova, zucchero, burro, stampo',
  'home_activity_toddler_8_tip':
      'Pasticceria: preparate insieme una torta semplice.',
  'home_activity_toddler_9_materials': 'Torcia, stanza buia',
  'home_activity_toddler_9_tip':
      'Teatro delle ombre: formate animali sul muro con le mani e una torcia.',
  'home_best_moment_hint': 'Un momento con il mio bambino…',
  'home_best_moment_question': 'Qual è stato il tuo momento più bello oggi?',
  'home_evening_reassurance': 'Ci sei. Domani è un nuovo giorno.',
  'home_greeting_name': '{greeting}, {name}!',
  'home_hello_name': 'Ciao {name}!',
  'home_match_new_many': '{count} nuove conferme',
  'home_match_new_one': '1 nuova conferma',
  'home_mood_good': 'Bene',
  'home_mood_grateful': 'Grato/a',
  'home_mood_great': 'Alla grande',
  'home_mood_okay': 'Così così',
  'home_mood_tough': 'Faticoso',
  'home_open_calendar_hint': 'Tocca per aprire il calendario',
  'home_quick_ai_chat': 'Chat IA',
  'home_quick_ask': 'Chiedimi',
  'home_quick_calendar': 'Calendario',
  'home_quick_events': 'Eventi',
  'home_quick_impulses': 'Spunti',
  'home_quick_lists': 'Liste',
  'home_quick_network': 'Rete',
  'home_quick_recipes': 'Ricette',
  'home_today_event_many': 'Oggi: {count} appuntamenti',
  'home_today_event_one': 'Oggi: 1 appuntamento',
  'home_weekly_review_question': 'Com\'è andata la tua settimana?',
  'home_welcome_back': 'Che bello avervi qui',
  'home_your_features': 'Le tue funzioni',
  'host_activities': 'Attività',
  'host_approve': 'Approva',
  'host_dashboard_title': 'La mia dashboard da organizzatore',
  'host_decline': 'Rifiuta',
  'host_my_activities': 'Le mie attività',
  'host_no_activities': 'Non hai ancora creato attività',
  'host_participants': 'Partecipanti',
  'host_pending': 'In sospeso',
  'host_pending_requests': 'Richieste in sospeso',
  'host_request_approved': 'Richiesta approvata!',
  'host_request_declined': 'Richiesta rifiutata',
  'host_requested_at': 'Richiesto: {date}',
  'host_sign_in_required': 'Accedi per vedere la tua dashboard da host.',
  'host_statistics': 'Statistiche',
  'host_user_label': 'Utente: {name}',
  'how_was_week': 'Com\'è andata la tua settimana?',
  'import_action': 'Importa',
  'important_know': 'Importante da sapere:',
  'important_to_know': 'Importante da sapere:',
  'impressum': 'Note legali',
  'instant_notifications': 'Notifiche immediate',
  'jump_to_today': 'Vai a oggi',
  'jump_today': 'Vai a oggi',
  'kitchen_add_ingredients_count': 'Aggiungi {count} ingredienti',
  'kitchen_age_months': 'da 6 mesi',
  'kitchen_age_years': 'da {age} anni',
  'kitchen_buy_only_needed': 'Seleziona solo ciò che devi davvero comprare.',
  'kitchen_cost_per_portion': '~{cost}€/porzione',
  'kitchen_error': 'Errore: {error}',
  'kitchen_family_recipes_tooltip': 'Ricette di famiglia (condividi e scopri)',
  'kitchen_fridge_subtitle': 'Fai una foto al frigo e ti propongo una ricetta.',
  'kitchen_fridge_title': 'Con quello che c\'è',
  'kitchen_ingredients_added':
      '✅ {count} ingredienti aggiunti alla lista della spesa',
  'kitchen_ingredients_preparation': '🍳 Ingredienti e preparazione',
  'kitchen_kids_hits_subtitle':
      'Ciò che è piaciuto ai tuoi figli finora. Tocca per ricette simili.',
  'kitchen_kids_hits_title': 'I successi dei bambini',
  'kitchen_kids_hits_tooltip': 'Trova ricette simili',
  'kitchen_minutes': '{minutes} min.',
  'kitchen_no_safe_recipe_body':
      'A causa delle allergie salvate non siamo riusciti a proporti una ricetta sicura in questo momento. Controlla le allergie nel profilo del bambino o riprova.',
  'kitchen_no_safe_recipe_title': 'Prima la sicurezza',
  'kitchen_rating_liked':
      '⭐ Aggiunto alla lista dei piatti preferiti dai bambini.',
  'kitchen_rating_not_liked': '👍 Ce lo ricordiamo.',
  'kitchen_saved_recipes_count': '❤️ Ricette salvate ({count})',
  'kitchen_search_hint':
      'Cerchi una ricetta in particolare? (es. frittelle, pasta)',
  'kitchen_table_moment_evening_subtitle':
      'Annotate insieme ciò che è stato bello oggi.',
  'kitchen_table_moment_evening_title':
      'È l\'ora del vostro momento a tavola 🕯️',
  'kitchen_table_moment_subtitle':
      'Un dolce rituale serale alla tavola di famiglia.',
  'kitchen_table_moment_title': 'Il nostro momento a tavola',
  'kitchen_tip_budget':
      'Consiglio per il budget|I legumi sono economici, sani e saziano. Perfetti per le famiglie.',
  'kitchen_tip_cook_together':
      'Cucinare insieme|I bambini che danno una mano mangiano più volentieri ciò che hanno nel piatto. Dai 2 anni: mescolare e lavare. Dai 4: tagliare con un coltellino per bambini.',
  'kitchen_tip_drinking':
      'Non dimenticare di bere|Una borraccia colorata e orari fissi per bere aiutano i bambini a idratarsi a sufficienza.',
  'kitchen_tip_family_ritual':
      'Rito di famiglia|Una volta a settimana cucinate insieme e lascia scegliere il piatto ai bambini. Rafforza l\'unione e l\'appetito.',
  'kitchen_tip_frozen_pizza':
      'Oggi pizza surgelata?|Va benissimo. Non ogni giorno deve essere perfetto. Domani si cucina qualcosa di fresco.',
  'kitchen_tip_frozen_vegetables':
      'Le verdure surgelate vanno bene|Piselli e broccoli surgelati hanno gli stessi nutrienti di quelli freschi e sono pronti in 5 minuti.',
  'kitchen_tip_healthy_sweets':
      'Dolci sani|Uva congelata, gelato alla banana o palline energetiche: dolce senza il crollo da zuccheri.',
  'kitchen_tip_hidden_vegetables':
      'Nascondi le verdure|Grattugia le zucchine nel ragù o le carote nelle frittelle. I bambini non se ne accorgono, tu sì.',
  'kitchen_tip_leftovers':
      'Avanzi creativi|Trasforma gli avanzi in wrap, sformati o riso saltato. Meno sprechi, più varietà.',
  'kitchen_tip_meal_prep':
      'Trucco meal-prep|La domenica cucina il doppio e congela. Durante la settimana un pasto sano è pronto in 10 minuti.',
  'kitchen_tip_morning':
      'Trucco del mattino|Prepara la colazione la sera: overnight oats, pane già tagliato, frutta lavata. La mattina sarà più serena.',
  'kitchen_tip_nature':
      'Bambini e natura|Coltiva le erbe aromatiche sul davanzale. Chi raccoglie da solo assaggia più volentieri, anche il prezzemolo.',
  'kitchen_tip_no_food_battle':
      'Niente lotte a tavola|Offri il cibo senza forzare. I bambini regolano da soli le porzioni. Fiducia invece di pressione.',
  'kitchen_tip_picky_eater':
      'Difficile a tavola?|I bambini possono aver bisogno fino a 15 tentativi prima di gradire qualcosa di nuovo. Continua a proporglielo senza mai forzarli.',
  'kitchen_tip_season_autumn':
      'Consiglio di stagione|Zucca, mele e pere sono dolci, convenienti e versatili. La vellutata di zucca è pronta in 20 minuti.',
  'kitchen_tip_season_spring':
      'Consiglio di stagione|Asparagi, ravanelli e spinaci sono freschi al mercato. I ravanelli raccolti da soli i bambini li assaggiano più volentieri.',
  'kitchen_tip_season_summer':
      'Consiglio di stagione|Fragole, ciliegie e pomodori sono freschi e convenienti proprio ora. Perfetti come spuntino senza cucinare.',
  'kitchen_tip_season_winter':
      'Consiglio di stagione|Cavolo rapa, carote e patate: una zuppa calda, economica e facile da preparare in anticipo.',
  'kitchen_tip_snack':
      'Idea per uno spuntino|Fette di mela con burro di arachidi o bastoncini di cetriolo con formaggio spalmabile: veloce, sano e senza fatica.',
  'kitchen_try_again': 'Riprova',
  'kitchen_view_ingredients_preparation': '🍳 Vedi ingredienti e preparazione',
  'kitchen_without': '🚫 Senza:',
  'knowledge_content_language_notice':
      'Le domande e le risposte sono tradotte. La ricerca funziona ancora con parole chiave in tedesco: digita una parola tedesca o scegli una scheda tematica.',
  'knowledge_search_hint': 'Cosa ti sta a cuore? (es. «picchia», «non dorme»)',
  'knowledge_tab': 'Sapere',
  'knowledge_topic_anger_label': 'Rabbia & opposizione',
  'knowledge_topic_anger_hint': 'Capricci, colpi',
  'knowledge_topic_sleep_label': 'Sonno',
  'knowledge_topic_sleep_hint': 'Addormentarsi, notte',
  'knowledge_topic_boundaries_label': 'Limiti',
  'knowledge_topic_boundaries_hint': 'Dire no, regole',
  'knowledge_topic_eating_label': 'Cibo',
  'knowledge_topic_eating_hint': 'Mangiare schizzinoso',
  'knowledge_topic_siblings_label': 'Fratelli',
  'knowledge_topic_siblings_hint': 'Litigi, gelosia',
  'knowledge_topic_media_label': 'Schermi',
  'knowledge_topic_media_hint': 'Tempo davanti allo schermo',
  'knowledge_ui_language_notice':
      'Le traduzioni mancanti dei comandi vengono mostrate in inglese.',
  'language_select': 'Scegli la lingua',
  'legal_info_tmg': 'Informazioni ai sensi del § 5 TMG / § 25 MStV',
  'lets_go': 'Si parte!',
  'loading': 'Caricamento…',
  'location_onboarding_detect': 'Rileva la posizione',
  'location_onboarding_explanation':
      'Con una posizione approssimativa trovi proposte vicine a te. Scegliere la posizione è facoltativo.',
  'location_onboarding_manual_hint': 'Città o codice postale',
  'location_onboarding_manual_title': 'Inserisci città o codice postale',
  'location_onboarding_privacy':
      'La tua posizione viene salvata solo in modo approssimativo (2 cifre decimali, circa 1 km). Per il nome del luogo inviamo coordinate GPS arrotondate o il luogo che inserisci a OpenStreetMap Nominatim.',
  'location_onboarding_skip': 'Salta',
  'location_osm_notice':
      'La ricerca dei luoghi invia i testi di ricerca o coordinate arrotondate a circa 1 km a OpenStreetMap Nominatim. La mappa carica i riquadri da OpenStreetMap.',
  'location_search_failed': 'La ricerca del luogo non è riuscita. Riprova.',
  'login_brand_tagline': 'Sicuro. Chiaro. Pensato per le famiglie.',
  'login_create_account': 'Crea un account',
  'login_failed': 'Accesso non riuscito. Riprova.',
  'login_forgot_password': 'Password dimenticata?',
  'login_google_error': 'Accesso con Google: {message}',
  'login_google_failed': 'Accesso con Google non riuscito. Riprova.',
  'login_google_popup_blocked':
      'I popup sono bloccati. Usa e-mail + password oppure apri la pagina in Safari.',
  'login_google_retry': 'Accesso con Google: riprova o usa e-mail + password.',
  'login_new_prompt': 'Nuovo su Parentpeak? ',
  'login_provider_coming_soon':
      'L\'accesso con {provider} arriverà nella prossima versione.',
  'login_submit': 'Accedi',
  'login_subtitle': 'Accedi per aprire il tuo spazio famiglia.',
  'login_technical_error': 'Errore tecnico durante l\'accesso. Riprova.',
  'login_welcome_back': 'Bentornato/a',
  'logout_action': 'Disconnetti',
  'logout_confirm': 'Disconnettersi?',
  'logout_question': 'Disconnettersi?',
  'looking_forward': 'Cosa aspetti con piacere la prossima settimana?',
  'lunch': 'Pranzo',
  'market_contact': 'Contatto',
  'market_details': 'Dettagli',
  'market_filter': 'Filtro',
  'market_no_categories': 'Nessuna categoria disponibile',
  'marketplace': 'Mercatino',
  'matching_block_profiles': 'Blocca profili',
  'matching_blocked_info': 'I profili bloccati non verranno più mostrati.',
  'matching_confirmed': 'Abbinamento confermato con {name} ({score}%)',
  'matching_current_status': 'Stato attuale',
  'matching_enter_name': 'Inserisci un nome.',
  'matching_enter_otp': 'Inserisci il codice OTP di 6 cifre.',
  'matching_enter_phone': 'Inserisci un numero di telefono.',
  'matching_filter': 'Filtro di abbinamento',
  'matching_load_failed': 'Non è stato possibile caricare Smart Matching',
  'matching_no_new_connections':
      'Al momento nessuna nuova connessione confermata.',
  'matching_otp_sent': 'OTP inviato. Inserisci il codice.',
  'matching_phone_verified': 'Numero di telefono verificato con successo.',
  'matching_profile': 'Il mio profilo di abbinamento',
  'matching_report_profiles': 'Segnala profili',
  'matching_request_sent':
      'Richiesta inviata. La connessione è in fase di conferma.',
  'matching_reset': 'Reimposta',
  'matching_safety_check': 'Controllo di sicurezza',
  'matching_safety_queue': 'Coda di sicurezza',
  'meetup_activity_count': '{count} attività',
  'meetup_filter_description':
      'Filtri chiari per la visibilità, da affinare facoltativamente per età.',
  'meetup_less_filters': 'Meno filtri',
  'meetup_more_filters': 'Più filtri',
  'meetup_nearby': 'Attività vicine a te',
  'meetup_title': 'Attività e incontri',
  'memory_add_child': 'Aggiungi un bambino',
  'memory_children': 'Profili dei bambini',
  'memory_confirmed_count': '{count} informazioni confermate',
  'memory_consent_accept': 'Consenti il salvataggio e l\'uso dell\'IA',
  'memory_consent_body':
      'Facoltativo: le informazioni familiari confermate, comprese quelle sulla salute, vengono salvate per account nel backend ParentPeak e trasmesse a Google Gemini per le richieste di chat pertinenti. I nuovi nomi dei bambini restano solo su questo dispositivo; l\'IA riceve segnaposto neutri ed età compiuta invece di nome e data di nascita. Il testo libero può comunque contenere informazioni personali. I vecchi dati originali restano intatti. Senza consenso le nuove voci di memoria e le relative trasmissioni sono bloccate; chattare normalmente con il relativo consenso resta possibile. La disattivazione interrompe l\'uso ma non elimina i dati esistenti. Le richieste già inviate non sono recuperabili. I dati locali non sono ulteriormente cifrati dall\'app.',
  'memory_consent_required':
      'Attiva la memoria con il consenso aggiuntivo prima di salvare nuovi dati.',
  'memory_consent_title': 'Consenso aggiuntivo per la memoria IA',
  'memory_delete_body':
      'Tutte le informazioni IA salvate su {name} verranno eliminate.',
  'memory_delete_title': 'Eliminare il profilo del bambino?',
  'memory_edit_child': 'Modifica il profilo del bambino',
  'memory_empty_info': 'Ancora nessuna informazione salvata.',
  'memory_enable': 'Attiva la memoria dell\'IA',
  'memory_gender': 'Sesso (facoltativo)',
  'memory_load_failed': 'Non è stato possibile caricare i dati. Riprova.',
  'memory_local_name': 'Nome visualizzato (solo su questo dispositivo)',
  'memory_name_required': 'Inserisci un nome locale.',
  'memory_name_save_failed':
      'Il profilo neutro è stato salvato nel backend, ma il nome visualizzato locale non è stato confermato. L\'elenco viene ricaricato; non creare una voce doppia.',
  'memory_no_children': 'Ancora nessun profilo del bambino creato.',
  'memory_none_confirmed': 'Nessuna informazione confermata',
  'memory_operation_failed':
      'La modifica non è stata confermata del tutto. La memoria viene verificata di nuovo; riprova.',
  'memory_storage_info':
      'I dati originali esistenti restano nel backend. La disattivazione blocca il nuovo salvataggio e l\'uso dell\'IA, non la lettura o l\'eliminazione. I nuovi nomi visualizzati restano locali per account; nessuna cifratura aggiuntiva dell\'app.',
  'memory_title': 'Memoria IA e bambini',
  'memory_transfer_info':
      'Solo con consenso aggiuntivo: i valori confermati vengono inviati a Google Gemini tramite il backend. Indicazioni sul bambino ed età vengono ridotte al minimo.',
  'money_once_hint': 'Inseriscilo una volta: non serve inserirlo ogni giorno.',
  'mood_exhausted': 'Esausto/a',
  'mood_great': 'Al top',
  'mood_level_1': 'Faticoso',
  'mood_level_2': 'Difficile',
  'mood_level_3': 'Così così',
  'mood_level_4': 'Bene',
  'mood_level_5': 'Meraviglioso',
  'mood_okay': 'Così così',
  'mood_support_action': 'Parla con la consulenza IA',
  'mood_support_message':
      'Ogni giorno dai il meglio. Vuoi un breve consiglio o parlare con l\'IA?',
  'mood_support_title': 'I giorni difficili vanno bene',
  'mood_tip_1':
      'I giorni difficili fanno parte del percorso. Oggi sii particolarmente gentile con te.',
  'mood_tip_2': 'Domani è un nuovo giorno. Una piccola pausa stasera fa bene.',
  'mood_tip_3': 'Solido! Non ogni giorno deve essere perfetto.',
  'mood_tip_4': 'Bella giornata! Goditi il momento.',
  'mood_tip_5': 'Che giornata fantastica! Conserva questa sensazione.',
  'mood_today_prefix': 'Oggi: ',
  'mood_today_title': 'Energia familiare oggi',
  'my_profile': 'Il mio profilo',
  'network_add_members': 'Aggiungi membri',
  'network_age_mixed': '{years} a. {months} m.',
  'network_age_months': '{months} mesi',
  'network_age_years': '{years} anni',
  'network_all_friends_in_group':
      'Tutti i tuoi amici sono già in questo gruppo.',
  'network_availability_heading': 'Quando avete tempo?',
  'network_availability_hint': 'es. Solo in vacanza, Solo festivi...',
  'network_back': 'Indietro',
  'network_block': 'Blocca',
  'network_blocked': '{name} è stato bloccato.',
  'network_chat': 'Chat',
  'network_chats_empty_desc':
      'Mettiti in contatto con altri genitori e avvia la tua prima chat, singola o di gruppo.',
  'network_chats_empty_title': 'Ancora nessuna conversazione',
  'network_child_custom_hint': 'Cos\'altro piace a tuo figlio?',
  'network_child_example': 'es. Mia',
  'network_child_name_local': 'Nome / soprannome (solo su questo dispositivo)',
  'network_child_number': 'Bambino {number}',
  'network_choose_members': 'Scegli i membri',
  'network_code_copied': 'Codice copiato ✓!',
  'network_coming_soon': 'Presto disponibile',
  'network_connect_confirm': 'Vuoi collegarti con {name}?',
  'network_connected_count': '{count} collegati',
  'network_copy_bio_hint':
      'Raccontate qualcosa di voi: cosa rende speciale la vostra famiglia? Cosa cercate?',
  'network_copy_bio_title': 'Bio breve',
  'network_copy_cancel': 'Annulla',
  'network_copy_connect': 'Collegarsi?',
  'network_copy_connect_button': 'Collega',
  'network_copy_create_profile': 'Crea profilo',
  'network_copy_custom': 'Personalizzato',
  'network_copy_custom_example': 'es. famiglia scelta, più generazioni...',
  'network_copy_custom_family': 'Il vostro tipo di famiglia',
  'network_copy_empty_description':
      'Il tuo profilo è attivo e visibile. Appena altre famiglie vicine a te si uniranno, compariranno qui automaticamente. Invita vicini e amici: è così che la tua rete cresce più in fretta.',
  'network_copy_empty_title': 'Sii la prima famiglia della tua zona',
  'network_copy_family_form': 'Tipo di famiglia',
  'network_copy_invite_hero_description':
      'Condividi il tuo link personale o il codice QR: un tocco e siete collegati.',
  'network_copy_invite_hero_title': 'Invita amici',
  'network_copy_invite_playmates': 'Invita compagni di gioco',
  'network_copy_location_hint': 'Scegli il vostro quartiere / CAP',
  'network_copy_login_required':
      'Accedi per pubblicare il tuo profilo per compagni di gioco.',
  'network_copy_name_example': 'es. Sara, I Rossi',
  'network_copy_name_hint': 'Il vostro nome / soprannome',
  'network_copy_no_gender': 'Preferisco non dirlo',
  'network_copy_playmates': 'Compagni di gioco',
  'network_copy_reason_nearby': 'Nelle vicinanze',
  'network_copy_reason_shared_family_form': 'Tipo di famiglia simile',
  'network_copy_reason_shared_interests': 'Interessi in comune',
  'network_copy_reason_shared_languages': 'Lingue in comune',
  'network_copy_reason_shared_values': 'Valori educativi simili',
  'network_copy_reason_similar_child_age': 'Bambini di età simile',
  'network_copy_request_failed':
      'Non è stato possibile inviare la tua richiesta. Riprova più tardi.',
  'network_copy_request_sent': 'La tua richiesta è stata inviata a {name}.',
  'network_copy_same_city': 'Nella tua città',
  'network_copy_save': 'Salvataggio...',
  'network_copy_setup_hint':
      'In 5 brevi passaggi troverete famiglie in sintonia con voi.',
  'network_copy_share': 'Condividi',
  'network_copy_step_1': 'Passaggio 1: la vostra famiglia',
  'network_copy_step_2': 'Passaggio 2: i vostri bambini',
  'network_copy_step_3': 'Passaggio 3: valori e stile',
  'network_copy_step_4': 'Passaggio 4: cosa cercate?',
  'network_copy_step_5': 'Passaggio 5: lingue e altro',
  'network_copy_values_tip':
      'Consiglio: le famiglie con valori simili si capiscono meglio. Scegli ciò che per te conta.',
  'network_create_group': 'Crea un gruppo',
  'network_create_group_hint':
      'es. gruppo dell\'asilo o incontro al parco giochi',
  'network_custom_add': 'Personalizzato',
  'network_delete_failed':
      'Non è stato possibile eliminare il profilo. Resta salvato. Riprova.',
  'network_delete_profile_confirm':
      'Il tuo profilo per compagni di gioco verrà eliminato in modo permanente. Puoi crearne uno nuovo in qualsiasi momento.',
  'network_discovery_auth_failed':
      'La ricerca delle famiglie non è consentita per questa sessione. Controlla il tuo account e l\'accesso.',
  'network_discovery_failed':
      'Non è stato possibile caricare le famiglie. Questo non è un risultato di ricerca vuoto confermato. Riprova.',
  'network_discovery_retry': 'Riprova la ricerca',
  'network_district_hint': 'Digita es. Kreuzberg, 10997...',
  'network_district_label': 'Quartiere o CAP',
  'network_draft_assign': 'Assegna la bozza al mio account',
  'network_draft_assign_body':
      'Conferma che la vecchia bozza di famiglia salvata localmente appartiene al tuo account «{account}». Verrà assegnata solo localmente a questo account e sarà poi disponibile anche per calendario, cucina e le altre funzioni di famiglia. Nessun dato viene caricato. La pubblicazione richiede una conferma separata.',
  'network_draft_assign_failed':
      'Non è stato possibile assegnare la bozza. Riprova.',
  'network_draft_assign_title': 'Assegnare la bozza locale a questo account?',
  'network_draft_unassigned':
      'Su questo dispositivo c\'è un vecchio profilo senza assegnazione a un account. Non viene usato né pubblicato automaticamente.',
  'network_families_nearby': 'Famiglie vicine a te',
  'network_family_fallback': 'questa famiglia',
  'network_family_name': 'Famiglia {name}',
  'network_found': 'Trovato ✓',
  'network_group': 'Gruppo',
  'network_group_chat_empty':
      'Ancora nessun messaggio. Scrivi il primo e fai partire la conversazione del gruppo!',
  'network_group_create_failed':
      'Non è stato possibile creare il gruppo, riprova più tardi.',
  'network_group_name': 'Nome del gruppo',
  'network_group_name_hint': 'es. Gruppo asilo Girasole',
  'network_group_name_required': 'Inserisci un nome per il gruppo.',
  'network_group_needs_friends':
      'Aggiungi prima degli amici per creare un gruppo.',
  'network_group_not_member': 'Non sei un membro di questo gruppo.',
  'network_group_photo_hint': 'Aggiungi una foto del gruppo (facoltativo)',
  'network_group_select_member': 'Seleziona almeno un membro.',
  'network_invalid_invite': 'Invito non valido o scaduto.',
  'network_languages_heading': 'Quali lingue parlate?',
  'network_leave_group': 'Esci dal gruppo',
  'network_leave_group_confirm':
      'Vuoi davvero uscire da questo gruppo? Non vedrai più i suoi messaggi.',
  'network_legacy_link_inactive':
      'Questo link non è più attivo. Usa il link di invito dell\'altra famiglia.',
  'network_link_create_failed':
      'Non è stato possibile creare il link, riprova più tardi.',
  'network_looking_custom_hint': 'Cos\'altro desiderate?',
  'network_looking_heading': 'Cosa cercate?',
  'network_match_score': '{score}% di affinità',
  'network_matching_suggestions': 'Profili per compagni di gioco pubblicati',
  'network_members': 'Membri',
  'network_members_add_failed': 'Non è stato possibile aggiungere i membri.',
  'network_members_added': 'Membri aggiunti.',
  'network_message_hint': 'Scrivi un messaggio…',
  'network_new_chat': 'Nuova chat',
  'network_no_messages_yet': 'Ancora nessun messaggio',
  'network_option_child_basteln': '✂️ Lavoretti',
  'network_option_child_bauen': '🧱 Costruire e assemblare',
  'network_option_child_bücher': '📚 Libri',
  'network_option_child_experimente': '🔬 Esperimenti',
  'network_option_child_fahrrad': '🚲 Bici e monopattino',
  'network_option_child_kochen_backen': '🍪 Cucinare e sfornare',
  'network_option_child_malen': '🎨 Disegnare',
  'network_option_child_musik': '🎵 Musica',
  'network_option_child_natur': '🌿 Scoprire la natura',
  'network_option_child_rollenspiel': '🎭 Gioco di ruolo',
  'network_option_child_spielplatz': '🎠 Parco giochi',
  'network_option_child_sport': '⚽ Sport',
  'network_option_child_tanzen': '💃 Ballare',
  'network_option_child_theater': '🎬 Teatro e travestimenti',
  'network_option_child_tiere': '🐶 Animali',
  'network_option_child_wasser': '💦 Giochi d\'acqua',
  'network_option_days_dienstag': 'Mar',
  'network_option_days_donnerstag': 'Gio',
  'network_option_days_freitag': 'Ven',
  'network_option_days_mittwoch': 'Mer',
  'network_option_days_montag': 'Lun',
  'network_option_days_samstag': 'Sab',
  'network_option_days_sonntag': 'Dom',
  'network_option_family_alleinerziehend': '💪 Genitore single',
  'network_option_family_co_parenting': '🤝 Co-genitorialità',
  'network_option_family_grosseltern': '🧓 Nucleo con i nonni',
  'network_option_family_grossfamilie': '🏠 Famiglia numerosa',
  'network_option_family_kernfamilie': '👪 Famiglia nucleare',
  'network_option_family_patchwork': '🧩 Famiglia allargata',
  'network_option_family_pflegefamilie': '❤️ Famiglia affidataria',
  'network_option_family_regenbogen': '🌈 Famiglia arcobaleno',
  'network_option_family_wg_familie': '🏡 Casa condivisa tra famiglie',
  'network_option_gender_divers': '🌟 Non binario',
  'network_option_gender_maennlich': '👦 Maschio',
  'network_option_gender_weiblich': '👧 Femmina',
  'network_option_language_ar': '🇸🇦 العربية',
  'network_option_language_bg': '🇧🇬 Bulgarski',
  'network_option_language_bs': '🇧🇦 Bosanski',
  'network_option_language_de': '🇩🇪 Deutsch',
  'network_option_language_el': '🇬🇷 Ellinika',
  'network_option_language_en': '🇬🇧 English',
  'network_option_language_es': '🇪🇸 Espanol',
  'network_option_language_fa': '🇮🇷 Farsi',
  'network_option_language_fr': '🇫🇷 Francais',
  'network_option_language_hi': '🇮🇳 Hindi',
  'network_option_language_hr': '🇭🇷 Hrvatski',
  'network_option_language_it': '🇮🇹 Italiano',
  'network_option_language_ja': '🇯🇵 Nihongo',
  'network_option_language_ko': '🇰🇷 Hangugeo',
  'network_option_language_ku': 'Kurdi',
  'network_option_language_nl': '🇳🇱 Nederlands',
  'network_option_language_pl': '🇵🇱 Polski',
  'network_option_language_pt': '🇵🇹 Portugues',
  'network_option_language_ro': '🇷🇴 Romana',
  'network_option_language_ru': '🇷🇺 Russkij',
  'network_option_language_sq': '🇦🇱 Shqip',
  'network_option_language_sr': '🇷🇸 Srpski',
  'network_option_language_sw': '🇰🇪 Kiswahili',
  'network_option_language_tr': '🇹🇷 Tuerkce',
  'network_option_language_uk': '🇺🇦 Ukrainska',
  'network_option_language_vi': '🇻🇳 Tieng Viet',
  'network_option_language_zh': '🇨🇳 Zhongwen',
  'network_option_looking_ausflug': '🏞️ Gite e viaggi',
  'network_option_looking_babysitting_tausch': '🤝 Scambio di babysitting',
  'network_option_looking_eltern_austausch': '☕ Scambio tra genitori',
  'network_option_looking_indoor_treffen': '🏠 Incontri al coperto',
  'network_option_looking_kindergeburtstage':
      '🎂 Feste di compleanno dei bambini',
  'network_option_looking_kita_fahrgemeinschaft': '🚗 Car pooling per l\'asilo',
  'network_option_looking_kochen': '🍳 Cucinare insieme',
  'network_option_looking_kreativ': '🎨 Incontri creativi',
  'network_option_looking_musik': '🎵 Musica e canto',
  'network_option_looking_natur': '🌳 Bosco e natura',
  'network_option_looking_online_austausch': '💬 Scambio online',
  'network_option_looking_regelmaessig': '🔄 Gruppo regolare',
  'network_option_looking_spielplatz': '🎠 Incontri al parco giochi',
  'network_option_looking_spontan': '⚡ Incontri spontanei',
  'network_option_looking_sport': '⚽ Sport e movimento',
  'network_option_looking_vorlesen': '📖 Lettura e storie',
  'network_option_specials_allergien': '⚠️ Allergie/intolleranze',
  'network_option_specials_behinderung': '♿ Bambino con disabilità',
  'network_option_specials_chronisch_krank': '🏥 Malattia cronica',
  'network_option_specials_fruehchen': '💪 Genitori di prematuri',
  'network_option_specials_hochsensibel': '🌼 Molto sensibile',
  'network_option_specials_mehrlinge': '👯 Parti plurimi',
  'network_option_specials_neurodivergent': '🧠 Neurodivergente (ADHD/autismo)',
  'network_option_specials_pflegekind': '❤️ Bambino in affido',
  'network_option_specials_schreibaby':
      '👶 Bimbo che piange molto/difficoltà di regolazione',
  'network_option_times_abends': '🌙 Sera (17–21)',
  'network_option_times_flexibel': '💫 Flessibile',
  'network_option_times_morgens': '🌅 Presto (6–09)',
  'network_option_times_nach_kita': '🏫 Dopo asilo/scuola',
  'network_option_times_nachmittags': '🌞 Pomeriggio (12–17)',
  'network_option_times_vormittags': '☀️ Mattina (9–12)',
  'network_option_values_attachment_parenting': '🤗 Attachment parenting',
  'network_option_values_bedürfnisorientiert': '💛 Orientata ai bisogni',
  'network_option_values_demokratisch': '🗳️ Democratica',
  'network_option_values_feministisch': '♀️ Femminista',
  'network_option_values_freilernend': '📚 Apprendimento libero',
  'network_option_values_gfk': '💚 Comunicazione nonviolenta (CNV)',
  'network_option_values_interkulturell': '🌍 Interculturale',
  'network_option_values_montessori': '🔬 Montessori',
  'network_option_values_naturverbunden': '🌳 Legata alla natura',
  'network_option_values_offen': '✨ Aperta a tutto',
  'network_option_values_pikler': '👶 Pikler',
  'network_option_values_religioes': '🕌 Religiosa/spirituale',
  'network_option_values_respektvoll': '🙏 Rispettosa',
  'network_option_values_strukturiert': '📋 Strutturata',
  'network_option_values_unerzogen': '🌱 Educazione non direttiva',
  'network_option_values_waldorf': '🌿 Waldorf',
  'network_outgoing_requests': 'Richieste inviate',
  'network_owner_label': 'Admin',
  'network_photo_camera': 'Scatta una foto',
  'network_photo_gallery': 'Scegli dalla galleria',
  'network_profile_active': 'Il server ha confermato che il profilo è attivo.',
  'network_profile_draft':
      'Nessun profilo attivo confermato sul server. Le bozze locali non vengono pubblicate automaticamente.',
  'network_profile_retry': 'Verifica di nuovo lo stato',
  'network_profile_unverified':
      'Non è stato possibile verificare lo stato del profilo. La visibilità non è confermata.',
  'network_publish_accept': 'Pubblica il profilo',
  'network_publish_body':
      'Il tuo nome visualizzato, la zona, la posizione approssimata e arrotondata (se disponibile), l\'età indicativa dei bambini, le lingue, il tipo di famiglia, i valori, le attività che cercate e la tua bio vengono salvati sul nostro backend e mostrati alle altre famiglie della rete. I nomi dei bambini, le date di nascita e le particolarità restano su questo dispositivo. Non inserire nomi dei bambini, indirizzo o dati sulla salute nella tua bio pubblica. L\'abbinamento non usa l\'IA. Puoi eliminare il tuo profilo in qualsiasi momento.',
  'network_publish_failed':
      'Non è stato possibile pubblicare il profilo. Riprova.',
  'network_publish_title': 'Pubblicare il profilo per incontri tra bambini?',
  'network_qr_code': 'Codice QR',
  'network_qr_create_failed':
      'Non è stato possibile creare il codice QR, riprova più tardi.',
  'network_radius': 'Nel raggio di ~{distance} km',
  'network_report': 'Segnala',
  'network_requests_count': 'Richieste ({count})',
  'network_save_error': 'Errore durante il salvataggio: {error}',
  'network_say_hello': 'Saluta',
  'network_scan_to_connect':
      'Quando vi incontrate basta scansionare: collegati all\'istante!',
  'network_search_hint': 'Cerca…',
  'network_sending': 'Invio…',
  'network_share_code_hint':
      'Condividi il tuo codice: un tocco e siete collegati!',
  'network_share_message': 'Ehi! 👋 Collegati con me su ParentPeak:\n{link}',
  'network_specials_heading': 'Particolarità (facoltativo)',
  'network_specials_hint':
      'Nota sulle particolarità (solo su questo dispositivo)',
  'network_specials_local':
      'Queste informazioni restano solo sul tuo dispositivo. Non vengono pubblicate né usate per l\'abbinamento sul backend.',
  'network_start_direct_chat': 'Scrivi a un amico',
  'network_start_direct_chat_hint':
      'Scegli un amico nella scheda Rete e avvia la chat.',
  'network_suggestions_count': '{count} suggerimenti',
  'network_tab_chats': 'Chat',
  'network_tab_network': 'Rete',
  'network_validation_district': 'Inserisci il vostro quartiere (passaggio 1)',
  'network_validation_name': 'Inserisci il vostro nome (passaggio 1)',
  'network_values_custom_hint': 'Cos\'altro è importante per voi?',
  'network_values_heading': 'Quali valori vivete?',
  'network_waiting_confirmation': '{name} — in attesa di conferma',
  'network_wants_to_connect': '{name} vuole collegarsi',
  'network_wide_radius': 'Nel raggio di ~1200 km',
  'network_withdraw': 'Ritira',
  'network_wizard_activities': 'Scegli le attività che vi divertono:',
  'network_wizard_choose':
      'Scegli ciò che si adatta meglio, oppure scrivi la tua:',
  'network_wizard_for_whom': 'Per chi cercate dei compagni di gioco?',
  'network_wizard_languages':
      'Tutte le lingue della vostra famiglia, anche quelle dei bambini:',
  'network_wizard_location':
      'Così possiamo proporti famiglie che si adattano bene:',
  'network_yesterday': 'Ieri',
  'network_you_label': 'Tu',
  'network_you_prefix': 'Tu:',
  'new_entry': 'Nuovo',
  'new_features': 'Nuove funzioni e avvisi',
  'new_name': 'Nuovo nome',
  'new_person': 'Nuova persona…',
  'no_answer': 'No',
  'no_events_this_week':
      'Nessun appuntamento questa settimana: spazio allo spontaneo!',
  'no_offers': 'Nessuna offerta trovata',
  'no_reviews_yet': 'Ancora nessun riepilogo',
  'not_available': 'Non disponibile',
  'onboarding_family_name': 'Come si chiama la vostra famiglia?',
  'onboarding_phase': 'In che fase siete?',
  'onboarding_priorities': 'Cosa è importante per te?',
  'onboarding_ready': 'Si parte!',
  'onboarding_subtitle':
      'La vostra quotidianità familiare. Un\'app.\nScopriamo insieme cosa vi aiuta di più.',
  'onboarding_where': 'Dove vive la vostra famiglia?',
  'open_room': 'Apri stanza',
  'open_source_licenses': 'Licenze open source',
  'organisation_title': 'Organizzazione',
  'organization_add_shopping_hint': 'Aggiungi un nuovo articolo alla spesa ...',
  'organization_add_todo_hint': 'Aggiungi una nuova attività ...',
  'organization_category_general': 'Generale',
  'organization_local_mode': 'Modalità locale attiva',
  'organization_no_shopping_items': 'Ancora nessun articolo nella spesa.',
  'organization_no_todos': 'Ancora nessuna attività.',
  'organization_offline_notice':
      'Modalità offline: le modifiche vengono salvate localmente e inviate alla prossima sincronizzazione.',
  'organization_title': 'Organizzazione',
  'parent_role': 'Genitore',
  'password_reset_instructions':
      'Inserisci il tuo indirizzo email. Ti invieremo un link per reimpostarla.',
  'password_reset_send_link': 'Invia il link',
  'password_reset_sent': 'Email inviata! Controlla la tua casella di posta.',
  'password_reset_title': 'Reimposta la password',
  'payment_accept_agb': 'Accetta Condizioni e Informativa sulla privacy',
  'payment_accept_terms': 'Accetta le condizioni',
  'payment_complete': 'Completa il pagamento',
  'payment_link_failed': 'Non è stato possibile aprire il link.',
  'payment_publish_fee': 'Costo di pubblicazione',
  'payment_success': 'Pagamento riuscito!',
  'payment_view_agb': 'Vedi le Condizioni',
  'payment_view_privacy': 'Vedi l\'Informativa sulla privacy',
  'person': 'Persona',
  'phase_multiselect': 'Puoi fare più scelte: adattiamo i contenuti.',
  'planner_capture_moment': 'Cattura un momento di famiglia',
  'planner_import': 'Importa',
  'planner_moment_saved': 'Momento di famiglia salvato.',
  'planner_no_moments':
      'Ancora nessun momento di famiglia salvato. Iniziate oggi con il vostro primo momento speciale.',
  'planner_no_weekday':
      'Nessun giorno della settimana valido riconosciuto. Controlla il formato.',
  'planner_title': 'Pianificatore pasti Pro',
  'planner_tone_clear': 'Tono: chiaro',
  'planner_tone_premium': 'Tono: Premium pacato',
  'planner_tone_warm': 'Tono: caloroso',
  'planner_update_pantry': 'Aggiorna la dispensa',
  'product_updates': 'Novità del prodotto',
  'profile_account_failed':
      'Non è stato possibile caricare o salvare i dati dell\'account. Riprova; i dati esistenti restano intatti.',
  'profile_account_retry': 'Riprova',
  'profile_ai_notice': 'Nota sull\'uso dell\'IA',
  'profile_blocked_contacts': 'Contatti bloccati',
  'profile_choose_language': 'Scegli la lingua',
  'profile_claim_confirm': 'Assegna al mio account',
  'profile_claim_explanation':
      'Conferma solo se questi dati locali precedenti ti appartengono. Verranno assegnati esclusivamente all\'account con cui hai effettuato l\'accesso. Nessun dato verrà pubblicato o caricato. I dati esistenti dell\'account non verranno sovrascritti.',
  'profile_claim_title': 'Assegnare i dati locali?',
  'profile_confirm': 'Conferma',
  'profile_confirm_delete': 'Scrivi «ELIMINA» per confermare:',
  'profile_confirm_login': 'Conferma l\'accesso',
  'profile_delete_final': 'Elimina definitivamente',
  'profile_export_sign_in_required': 'Accedi per esportare i tuoi dati.',
  'profile_important_info': 'Importante sapere:',
  'profile_imprint': 'Note legali',
  'profile_legacy_children': 'Elenco dei bambini locale precedente',
  'profile_legacy_location': 'Posizione locale precedente',
  'profile_legacy_onboarding': 'Configurazione locale precedente',
  'profile_legacy_unassigned':
      'Dati locali precedenti non assegnati. Nessuna acquisizione automatica.',
  'profile_legal_info': 'Informazioni ai sensi del § 5 TMG / § 25 MStV',
  'profile_logout_title': 'Disconnettersi?',
  'profile_no_blocked': 'Nessun contatto bloccato',
  'profile_sync_failed':
      'Configurazione salvata localmente. La sincronizzazione dell\'account non è riuscita; riprova più tardi.',
  'profile_unblock': 'Sblocca',
  'public_holiday': 'Festività nazionale',
  'publish_event': 'Pubblica evento',
  'quick_activity_empty': 'Nessuna attività in questa categoria',
  'quick_activity_idea': 'Un\'idea per voi',
  'quick_activity_needs': 'Cosa vi serve',
  'quick_activity_title': 'Cosa facciamo oggi?',
  'recipe_ai_consent_accept': 'Accetto, usa le ricette IA',
  'recipe_ai_consent_body':
      'Per le ricette con l\'IA, l\'età del bambino e le informazioni sulle allergie dai tuoi profili dei bambini e dalle impostazioni della cucina salvati localmente vengono inviati tramite il nostro backend al servizio IA (Google Gemini). In caso di ricerca di un piatto viene trasmesso anche il tuo testo di ricerca. Nomi, dati del medico e contatti di emergenza presenti nei profili non vengono trasmessi automaticamente. Senza consenso l\'ispirazione per le ricette resta locale e non viene inviata alcuna richiesta all\'IA.',
  'recipe_ai_consent_failed':
      'Non è stato possibile salvare il consenso in modo sicuro. L\'IA resta disattivata.',
  'recipe_ai_consent_title': 'Creare ricette di famiglia con l\'IA',
  'recipe_ai_local_notice':
      'Ispirazione locale per le ricette: nessun dato è stato inviato all\'IA.',
  'recipe_ai_request_failed':
      'Non è stato possibile avviare la creazione della ricetta. Riprova.',
  'recipe_generate': 'Nuova ricetta',
  'recipe_ingredients': 'Ingredienti',
  'recipe_steps': 'Preparazione',
  'region': 'Regione',
  'register_accept_terms_required': 'Accetta le condizioni d\'uso.',
  'register_already_registered': 'Hai già un account? ',
  'register_back_to_login': 'Torna all\'accesso',
  'register_beta_description':
      'Dopo il lancio ufficiale: 1 mese di prova gratuito.',
  'register_beta_title': 'Attualmente gratis in beta',
  'register_display_name_helper': 'Così ti vedono gli altri genitori.',
  'register_display_name_label':
      'Il tuo nome visibile (es. Anna o Famiglia Rossi)',
  'register_display_name_required': 'Il nome è obbligatorio.',
  'register_failed': 'Registrazione non riuscita. Riprova.',
  'register_login_link': 'Accedi',
  'register_password_confirm_label': 'Conferma la password',
  'register_password_hint_length': 'Almeno 8 caratteri',
  'register_password_hint_number': 'Almeno un numero (0–9)',
  'register_password_hint_uppercase': 'Almeno una maiuscola (A–Z)',
  'register_password_min_length': 'Almeno 8 caratteri.',
  'register_password_mismatch': 'Le password non coincidono.',
  'register_password_number': 'Almeno un numero.',
  'register_password_requirements': 'Requisiti della password',
  'register_password_uppercase': 'Almeno una maiuscola.',
  'register_submit': 'Inizia gratis',
  'register_subtitle': 'Pronto per la tua quotidianità familiare in 2 minuti.',
  'register_technical_error':
      'Errore tecnico durante la registrazione. Riprova.',
  'register_terms_and': ' e ',
  'register_terms_prefix': 'Accetto le ',
  'register_terms_suffix': ' di Parentpeak.',
  'register_title': 'Crea un account',
  'register_url_not_configured': 'URL non ancora configurato.',
  'reload': 'Ricarica',
  'reminders': 'Promemoria',
  'remove_action': 'Rimuovi',
  'remove_member': 'Rimuovere il membro?',
  'report_action': 'Segnala',
  'report_offer': 'Segnala offerta',
  'report_profile': 'Segnala profilo',
  'reset': 'Reimposta',
  'reset_filter': 'Reimposta filtro',
  'review_delete': 'Elimina',
  'review_delete_confirm':
      'Questo bilancio settimanale verrà eliminato in modo permanente.',
  'review_delete_title': 'Eliminare {week}?',
  'review_fill_again': 'Compila di nuovo',
  'review_next_week': 'Cosa aspetti con piacere la prossima settimana?',
  'review_no_reviews': 'Ancora nessun bilancio',
  'review_talk_to_ai': 'Parla con l\'IA della mia settimana',
  'ritualRuheTileSubtitle':
      'Un momento di calma per la vostra quotidianità familiare',
  'ritualRuheTitle': 'Rituale e calma',
  'ritual_add': 'Aggiungi',
  'ritual_add_step': 'Aggiungi passo',
  'ritual_afternoon': 'Pomeriggio',
  'ritual_age_growing': '5–7 anni: immagine + frase breve',
  'ritual_age_notice':
      '{name} ora ha {age} anni. Volete adattare insieme i rituali?',
  'ritual_age_older': '10–14 anni: auto-organizzazione e riflessione',
  'ritual_age_school': '6–10 anni: agenda del giorno',
  'ritual_age_young': '2–5 anni: carte con immagini e movimento',
  'ritual_all_done': 'Per oggi è abbastanza. Ora può arrivare la calma.',
  'ritual_cancel': 'Annulla',
  'ritual_card_subtitle':
      'Niente deve essere perfetto. Prendete ciò che va bene oggi.',
  'ritual_child': 'Il vostro bambino',
  'ritual_close': 'Chiudi',
  'ritual_done': 'Fatto',
  'ritual_edit': 'Modifica',
  'ritual_edit_title': 'Modifica {title}',
  'ritual_empty_action': 'Al profilo familiare',
  'ritual_empty_description':
      'Non appena viene creato un profilo bambino, ParentPeak può accompagnare i rituali in modo adatto all\'età.',
  'ritual_empty_title': 'Ancora nessun profilo bambino',
  'ritual_evening': 'Buonanotte',
  'ritual_fallback_name_afternoon': 'Arrivare nel pomeriggio',
  'ritual_fallback_name_morning': 'Mattina tranquilla',
  'ritual_fallback_story':
      'Quando {name} guardò fuori dalla finestra la sera, brillava una piccola stella. Ricordava che ogni giorno ha buoni momenti: un sorriso e una casa in cui si può semplicemente essere. Il vento sussurrò: per oggi è abbastanza. Poi tutto divenne quieto e sereno.',
  'ritual_gratitude_hint': 'Oggi è stato bello che…',
  'ritual_gratitude_placeholder': 'Basta una piccola frase',
  'ritual_gratitude_title': 'Un buon momento',
  'ritual_morning': 'Buongiorno',
  'ritual_name': 'Nome del rituale',
  'ritual_night_title': 'Il vostro momento della sera',
  'ritual_quiet_mode': 'Modalità calma',
  'ritual_reminder_body':
      'Promemoria gentile di «{name}». Prendetevi un momento di calma.',
  'ritual_reminder_title': 'È l\'ora del vostro rituale 🌙',
  'ritual_remove_step': 'Rimuovi passo',
  'ritual_save': 'Salva',
  'ritual_section_evening': 'Sera',
  'ritual_section_morning': 'Mattina',
  'ritual_step': 'Passo',
  'ritual_step_arrive_sub': 'Togliere le scarpe e prima arrivare',
  'ritual_step_arrive_title': 'Arrivare',
  'ritual_step_breakfast_sub': 'Iniziare la giornata insieme',
  'ritual_step_breakfast_title': 'Colazione',
  'ritual_step_close_sub': 'Cosa si può lasciar andare per oggi?',
  'ritual_step_close_title': 'Chiudere la giornata',
  'ritual_step_cuddle_sub': 'Ancora un momento affettuoso',
  'ritual_step_cuddle_title': 'Coccole',
  'ritual_step_daymoment_sub': 'Cosa è stato bello oggi?',
  'ritual_step_daymoment_title': 'Momento del giorno',
  'ritual_step_dress_sub': 'Trovare qualcosa di comodo',
  'ritual_step_dress_title': 'Vestirsi',
  'ritual_step_free_sub': 'Cosa vi fa bene ora?',
  'ritual_step_free_title': 'Tempo libero',
  'ritual_step_goodmoment_sub': 'Una frase per te stesso/a',
  'ritual_step_goodmoment_title': 'Un buon momento',
  'ritual_step_morning_sub': 'Arrivare pian piano',
  'ritual_step_morning_title': 'Buongiorno',
  'ritual_step_pause_breathe_sub': 'Prima, respirare a fondo',
  'ritual_step_pause_relax_sub': 'Bere, fare uno spuntino, rilassarsi',
  'ritual_step_pause_short_title': 'Pausa',
  'ritual_step_pause_sub': 'Bere qualcosa e respirare',
  'ritual_step_pause_title': 'Piccola pausa',
  'ritual_step_prep_bag_sub': 'Preparare borsa e vestiti',
  'ritual_step_prep_clothes_sub': 'Preparare i vestiti preferiti',
  'ritual_step_prep_full_sub': 'Borsa, vestiti e sveglia',
  'ritual_step_prep_tomorrow_title': 'Preparare per domani',
  'ritual_step_ready_sub': 'Cosa ci serve oggi?',
  'ritual_step_ready_title': 'Pronti per la giornata',
  'ritual_step_story_sub': 'Una storia tranquilla aspetta',
  'ritual_step_story_title': 'Scegliere una storia',
  'ritual_step_subtitle': 'Frase breve',
  'ritual_step_teeth_calm_sub': 'Finire con calma',
  'ritual_step_teeth_circles_sub': 'Piccoli cerchi, con calma',
  'ritual_step_teeth_night_sub': 'La bocca riceve la sua cura notturna',
  'ritual_step_teeth_title': 'Lavare i denti',
  'ritual_step_tidy_sub': 'Un piccolo gesto per domani',
  'ritual_step_tidy_title': 'Mettere un po\' in ordine',
  'ritual_step_title': 'Titolo',
  'ritual_step_wash_calm_sub': 'Viso e mani si calmano',
  'ritual_step_wash_cozy_sub': 'Diventare freschi e a proprio agio',
  'ritual_step_wash_title': 'Lavarsi',
  'ritual_story_generate': 'Raccontare una storia',
  'ritual_story_hint': 'Una storia tranquilla per {name}.',
  'ritual_story_new': 'Nuova storia',
  'ritual_story_title': 'Una storia per oggi',
  'ritual_suggestion': 'Suggerimento per {age} anni, {section}',
  'ritual_time': 'Ora',
  'ritual_timer': 'Timer tranquillo',
  'ritual_timer_hint': '0 = senza timer',
  'ritual_timer_seconds': 'Timer in secondi',
  'ritual_timer_start': 'Avvia un timer tranquillo',
  'ritual_weekdays': 'Lu|Ma|Me|Gi|Ve|Sa|Do',
  'ritual_welcome_child': '{section} con {name}',
  'ritual_welcome_night': 'È ora di rallentare',
  'ritual_welcome_question': 'Cosa vi farebbe bene oggi?',
  'ritual_welcome_relaxed': 'Un piccolo passo tranquillo dopo l\'altro.',
  'ritual_your_section': 'Il vostro {section}',
  'safety_check': 'Controllo di sicurezza',
  'safety_guide_emergency': 'In caso di emergenza',
  'safety_guide_priority': 'La tua sicurezza è la nostra priorità!',
  'safety_guide_title': 'Guida alla sicurezza',
  'safety_guide_understand': 'Ho capito queste regole',
  'satt_add': 'Aggiungi',
  'satt_choose_emoji': 'Scegli emoji',
  'satt_difficulty': 'Difficoltà',
  'satt_hide': 'Nascondi',
  'satt_hide_from_feed': 'Nascondi dal feed',
  'satt_hide_offer': 'Nascondere l\'offerta?',
  'satt_ingredients': 'Ingredienti (uno per riga)',
  'satt_parent_hints': 'Note per i genitori',
  'satt_preparation_steps':
      'Preparazione (passo dopo passo, una riga per passaggio)',
  'satt_recipe_name': 'Nome della ricetta',
  'satt_report': 'Segnala',
  'satt_report_offer': 'Segnala offerta',
  'satt_servings': 'Porzioni',
  'satt_share_hint': 'Condividi la tua ricetta preferita con altri genitori',
  'satt_share_recipe': 'Condividi ricetta 📖',
  'satt_short_description': 'Breve descrizione',
  'satt_time_min': 'Tempo (min)',
  'save_share_title': 'Risparmiare e condividere',
  'school_holiday': 'Vacanze scolastiche',
  'security': 'Sicurezza',
  'select_language': 'Scegli la lingua',
  'send_anyway': 'Invia comunque',
  'share_recipe': 'Condividi ricetta',
  'signed_backups': 'Backup firmati',
  'snack': 'Spuntino',
  'soon': 'Presto',
  'status_done': 'Fatto',
  'status_full': 'Al completo',
  'status_open': 'Aperto',
  'sync_failed': 'Sincronizzazione con il server non riuscita',
  'table_moment_delete_message':
      'Questo momento verrà rimosso in modo permanente dal vostro scrigno dei ricordi.',
  'table_moment_delete_title': 'Rimuovere il momento?',
  'table_moment_empty': 'Il vostro scrigno dei ricordi è ancora vuoto.',
  'table_moment_empty_hint': 'Fissate stasera il vostro primo momento insieme.',
  'table_moment_for_whom': 'Per chi?',
  'table_moment_how_was_it': 'Com\'è stato questo momento?',
  'table_moment_local_only': 'Resta solo su questo dispositivo',
  'table_moment_new': 'Fissa un nuovo momento',
  'table_moment_note_hint': 'es. «Abbiamo fatto le frittelle insieme.»',
  'table_moment_note_label': 'Una frase a riguardo (facoltativo)',
  'table_moment_save': 'Fissa il momento',
  'table_moment_saved': 'Conservato nel vostro scrigno dei ricordi. 🕯️',
  'table_moment_select_feeling':
      'Scegli un simbolo a cuore per fissare il vostro momento.',
  'table_moment_title': 'Il nostro momento a tavola',
  'table_moment_treasure': 'Scrigno dei ricordi',
  'table_moment_whole_family': 'Tutta la famiglia',
  'table_moment_yours': 'I vostri momenti',
  'talk_ai_week': 'Parla con l\'IA della mia settimana',
  'tips_title': 'Consigli e sapere',
  'tooltip_accept': 'Accetta',
  'tooltip_ai_memory': 'Memoria dell\'IA',
  'tooltip_change_country': 'Cambia paese',
  'tooltip_copy': 'Copia',
  'tooltip_delete_chat': 'Elimina chat',
  'tooltip_options': 'Opzioni',
  'tooltip_recheck': 'Verifica di nuovo',
  'tooltip_reject': 'Rifiuta',
  'tooltip_reload': 'Ricarica',
  'tooltip_remove': 'Rimuovi',
  'tooltip_remove_contact': 'Rimuovi contatto',
  'tooltip_save_pdf': 'Salva come PDF',
  'tooltip_saved_recipes': 'Ricette salvate',
  'tooltip_search': 'Cerca',
  'tooltip_share_list': 'Condividi la lista',
  'tooltip_share_overview': 'Condividi il riepilogo',
  'tooltip_shopping_list': 'Lista della spesa',
  'tooltip_sync': 'Sincronizza',
  'tooltip_tone': 'Stile del linguaggio',
  'tooltip_topic_analysis': 'Analisi dei temi',
  'treasureAddMorePhotos': 'Più foto',
  'treasureAiAccept': 'Usa il suggerimento',
  'treasureAiHelper': 'Ti suggeriamo subito categoria e colore.',
  'treasureAiTitle': 'Riconosciuto in un attimo',
  'treasureBlockAction': 'Nascondi',
  'treasureBlockSuccess': 'L\'annuncio è stato nascosto dal tuo feed.',
  'treasureBlockText':
      'Questo annuncio viene nascosto in locale e non comparirà più nel feed.',
  'treasureBlockTitle': 'Vuoi nascondere l\'annuncio?',
  'treasureCancelReservation': 'Annulla la prenotazione',
  'treasureCategoryBooks': 'Libri',
  'treasureCategoryClothing': 'Abbigliamento',
  'treasureCategoryEquipment': 'Attrezzatura',
  'treasureCategoryLabel': 'Categoria',
  'treasureCategoryOther': 'Altro',
  'treasureCategoryToys': 'Giocattoli',
  'treasureCategoryVehicles': 'Veicoli',
  'treasureChooseFromLibrary': 'Dalla galleria',
  'treasureCoffeeSlotHint':
      'Scegliete un orario che vada bene per entrambe le famiglie.',
  'treasureColorLabel': 'Colore',
  'treasureColorLine': 'Colore: {color}',
  'treasureColorPlaceholder': 'es. rosso, salvia, legno naturale',
  'treasureCompleteHandover': 'Segna come consegnato',
  'treasureConditionGood': 'Seconda vita',
  'treasureConditionGoodHint':
      'Visibilmente usato, perfettamente pronto all\'uso.',
  'treasureConditionHelper': 'L\'onestà è la cosa migliore.',
  'treasureConditionLabel': 'Condizione',
  'treasureConditionLikeNew': 'Come nuovo',
  'treasureConditionLikeNewHint': 'Molto curato, quasi come nuovo.',
  'treasureConditionLine': '',
  'treasureConditionRaider': 'Con qualche segno',
  'treasureConditionRaiderHint':
      'Qualche segno d\'uso, ma pronto per la prossima avventura.',
  'treasureConfirmHandover': 'Conferma la consegna',
  'treasureContactlessHint': 'Senza contatto possibile',
  'treasureContactlessPointLabel': 'Punto di ritiro',
  'treasureCoverPhotoLabel': 'Copertina',
  'treasureCurrentRadius': 'Raggio di ricerca attuale: {radius}',
  'treasureDateOrSwap': 'Incontro veloce o scambio discreto',
  'treasureDefaultColor': 'Rosso',
  'treasureDefaultSizeAge': '2-4 anni',
  'treasureDefaultTitle': 'Bici senza pedali rossa',
  'treasureDeleteAction': 'Elimina annuncio',
  'treasureDeleteFailed': 'Non è stato possibile eliminare l\'annuncio.',
  'treasureDeleteSuccess': 'Il tuo annuncio è stato eliminato.',
  'treasureDeleteText':
      'L\'annuncio verrà rimosso in modo permanente. Le prenotazioni esistenti verranno annullate.',
  'treasureDeleteTitle': 'Eliminare l\'annuncio?',
  'treasureDetailSectionAbout': 'In breve',
  'treasureDetailSectionPickup': 'Ritiro e consegna',
  'treasureDetailSelectedHint':
      'Questo tesoro è attualmente selezionato per la tua consegna.',
  'treasureDiscard': 'Annulla',
  'treasureDiscardDraftText':
      'Lo stato attuale del modulo e la bozza salvata in locale verranno rimossi.',
  'treasureDiscardDraftTitle': 'Vuoi annullare la bozza?',
  'treasureDiscoveryInvite':
      'Invita amici o condividi le tue offerte, così ci saranno più tesori vicino a te.',
  'treasureDiscoveryScopeInvite':
      'Portata attuale: {radius}. Invita amici per trovare più tesori vicino a te.',
  'treasureDistanceApproximate': 'A circa {distance}',
  'treasureDistanceAway': 'a {distance}',
  'treasureDistanceNearby': 'Vicino a te',
  'treasureDistanceUnknown': 'Distanza sconosciuta',
  'treasureDraftDiscarded': 'Bozza annullata.',
  'treasureDraftRestored': 'La tua ultima bozza è di nuovo qui.',
  'treasureDraftSaved': 'Bozza salvata. Puoi continuare più tardi.',
  'treasureDropKitaLocker': 'Guardaroba dell\'asilo (scomparto «Gabbiano»)',
  'treasureDropMailbox': 'Scatola presso la cassetta della posta all\'ingresso',
  'treasureDropPointHint':
      'Scegli un punto di ritiro senza contatto che ti faccia sentire al sicuro.',
  'treasureDropRetterBox': 'Scatola dono davanti alla porta di casa',
  'treasureFamilyNoteTitle': 'Nota della famiglia',
  'treasureFeedEmptyText':
      'Inizia semplicemente con il primo oggetto che a casa vostra può passare a qualcun altro.',
  'treasureFeedEmptyTitle': 'Ancora nessun tesoro vicino a te',
  'treasureFeedSubtitle': 'Locale, onesto, subito chiaro',
  'treasureFeedTitle': 'Tesori vicino a te',
  'treasureFilterAll': 'Tutti',
  'treasureFilterDistance250': 'Fino a 250 m',
  'treasureFilterDistance500': 'Fino a 500 m',
  'treasureFilterDistanceAll': 'Qualsiasi distanza',
  'treasureFreshToday': 'Nuovo oggi',
  'treasureGlobalMode': 'Vista: modalità digitale globale',
  'treasureGuidelineCommunity':
      'Così condividere nel quartiere diventa facile.',
  'treasureGuidelineHonest':
      'Condividi con onestà invece di puntare alla perfezione.',
  'treasureGuidelineNoPressure': 'I segni d\'uso vanno benissimo.',
  'treasureGuidelineTempo': 'Decidete voi: incontro veloce o scambio discreto.',
  'treasureHandoverCoffeeMode': 'Incontro veloce',
  'treasureHandoverCoffeeModeText': 'Un saluto veloce, la consegna e via.',
  'treasureHandoverFlyingSwap': 'Scambio discreto',
  'treasureHandoverFlyingSwapText':
      'Ritiro senza contatto quando ti fa comodo.',
  'treasureHandoverQuestion': 'Come volete fare la consegna?',
  'treasureHandoverUpdateFailed':
      'Non è stato possibile aggiornare la consegna.',
  'treasureHandoverUpdated': 'La consegna è stata aggiornata.',
  'treasureHoursAgoShort': '{count} h fa',
  'treasureImageUploadFailed':
      'Caricamento dell\'immagine non riuscito. Riprova.',
  'treasureInsertNoteSuggestion': 'Inserisci il suggerimento di testo',
  'treasureJustListed': 'Appena pubblicato',
  'treasureLegalNotice':
      'Avviso legale: nel Mercatino del dono Parentpeak funge solo da intermediario. Della condizione, della sicurezza e della consegna degli articoli rispondono esclusivamente gli utenti coinvolti.',
  'treasureListedAgoLine': 'Pubblicato: {time}',
  'treasureLoadingHint': 'Stiamo caricando le offerte adatte dalla tua zona.',
  'treasureMinutesAgoShort': '{count} min fa',
  'treasureMyListings': 'I miei annunci',
  'treasureMyListingsEmpty': 'Non hai ancora annunci o prenotazioni.',
  'treasureNetworkError':
      'La connessione è saltata un attimo. Riprova tra poco.',
  'treasureNeutralColor': 'Neutro',
  'treasureNoResultsText':
      'Prova con una distanza più ampia o torna a dare un\'occhiata più tardi.',
  'treasureNoResultsTitle': 'Al momento niente di adatto',
  'treasureNoteEditable': 'Nota inserita. Puoi modificarla.',
  'treasureNoteSuggestion':
      '{title}, {sizeAge}. Qui puoi aggiungere altre indicazioni per la consegna.',
  'treasureNoteSuggestionHint':
      'Inserisce un modello di testo modificabile e sostituisce la nota attuale. Nessuna registrazione vocale.',
  'treasureOpenGallery': 'Apri la galleria',
  'treasureOptionalNoteHelper':
      'Una frase onesta aiuta subito le famiglie vicine.',
  'treasureOptionalNoteLabel': 'Nota breve',
  'treasureOptionalNotePlaceholder': 'es. taglia 92, veste un po\' piccola.',
  'treasurePhotoAnalyzing': 'La foto viene analizzata...',
  'treasurePhotoCount': '{count} foto',
  'treasurePhotoGalleryHint':
      'Scegli un\'immagine di copertina o rimuovi quelle extra.',
  'treasurePhotoMissing':
      'Aggiungi prima una foto, così le famiglie vedono subito di cosa si tratta.',
  'treasurePhotoReady': 'Foto pronta',
  'treasurePhotoSectionHint': 'Mostra l\'oggetto semplicemente com\'è adesso.',
  'treasurePickupAreaLine': '',
  'treasurePickupLocationHint':
      'La tua posizione determina quali famiglie vedono la tua offerta.',
  'treasurePickupLocationTitle': 'Zona di ritiro',
  'treasurePreviewNoteLabel': 'Nota della famiglia',
  'treasurePreviewTitle': 'Anteprima del feed',
  'treasurePublishNow': 'Condividi ora',
  'treasureRatingLine': '',
  'treasureReportAction': 'Segnala',
  'treasureReportLocalOnly':
      'Segnalazione contrassegnata in locale. La sincronizzazione con il server seguirà appena disponibile.',
  'treasureReportNoteHint': 'Facoltativo: breve nota per la moderazione',
  'treasureReportReason_false_info': 'Informazioni false',
  'treasureReportReason_hostile': 'Comportamento scortese',
  'treasureReportReason_inappropriate': 'Contenuto inappropriato',
  'treasureReportReason_other': 'Altro',
  'treasureReportSubmit': 'Segnala',
  'treasureReportSuccess': 'Grazie, controlliamo questa segnalazione.',
  'treasureReportTitle': 'Segnala l\'annuncio',
  'treasureReportedFlag': 'Segnalato',
  'treasureReservationConfirmed': 'Consegna confermata',
  'treasureReservationOpen': 'Prenotazione aperta',
  'treasureReservationSuccessDetail':
      '✅ {title} è prenotato per te! {detailType}: {detail}. La famiglia che dona verrà avvisata.',
  'treasureReservations': 'Prenotazioni',
  'treasureReserveAndPickup': 'Guarda e salva',
  'treasureReserveCoffeeMode': 'Fissa un incontro',
  'treasureReserveFlyingSwap': 'Salva lo scambio discreto',
  'treasureReserveTitle': 'Pianifica la consegna',
  'treasureReserved': 'Prenotato ✓',
  'treasureReservedByYou': 'Prenotato da te',
  'treasureSaveDraft': 'Salva bozza',
  'treasureSelectForHandover': 'Scegli per la consegna',
  'treasureSelectedForHandover': 'Salvato',
  'treasureSelectionConfirmed':
      '{title} ora è selezionato per la tua consegna.',
  'treasureShareRadiusHelper':
      'Stabilisci entro quale raggio le famiglie vedono la tua offerta. Il calcolo usa posizioni arrotondate in modo approssimativo ed è solo indicativo; massimo 25 km.',
  'treasureShareRadiusKm': 'Raggio circa {radius} km',
  'treasureShareRadiusLabel': 'Raggio di pubblicazione',
  'treasureSizeAgeLabel': 'Taglia o età',
  'treasureSizeAgeLine': '',
  'treasureSizeAgePlaceholder': 'es. taglia 92 o età da 2 a 3 anni',
  'treasureSlotMonday': 'Lunedì, 17:30 - 18:15',
  'treasureSlotSunday': 'Domenica, 10:00 - 11:30',
  'treasureSlotTuesday': 'Martedì, 08:15 - 08:45',
  'treasureSyncHintFallback':
      'La sincronizzazione in tempo reale è limitata al momento. Tira verso il basso per aggiornare.',
  'treasureTakePhoto': 'Scatta una foto',
  'treasureTileSubtitle': 'Regalare, scambiare, mettere in contatto i genitori',
  'treasureTileTitle': 'Mercatino dei regali',
  'treasureTimeWindowLabel': 'Orari disponibili',
  'treasureTitleLabel': 'Titolo',
  'treasureTitlePlaceholder': 'es. bici senza pedali rossa',
  'treasureUploadHeadline': 'Condividi ciò che a casa vostra non serve più',
  'treasureUploadSubline': 'Una foto, un controllo veloce, fatto',
  'treasureUploadSubtitle': 'Una foto basta per iniziare',
  'treasureUploadSuccess': 'Il tuo tesoro ora è visibile.',
  'treasureUploadTitle': 'Condividi un tesoro',
  'treasureViewsLine': '',
  'treasure_account_changed':
      'L\'account è stato cambiato. Chiudi questa schermata.',
  'treasure_cancel_local_failed':
      'Il server ha confermato l\'annullamento, ma il contrassegno locale non è stato rimosso. Potrebbe risultare ancora obsoleto.',
  'treasure_created_archived':
      'Il tuo annuncio è stato salvato, ma archiviato dal server. Non è disponibile nel mercatino. Controlla «I miei annunci».',
  'treasure_created_local_failed':
      'Il server ha salvato l\'annuncio, ma non ne ha confermato la disponibilità. La rielaborazione locale non è riuscita; le foto restano intatte. Controlla «I miei annunci» prima di riprovare.',
  'treasure_created_not_available':
      'Il tuo annuncio è stato salvato, ma la disponibilità non è stata confermata. Controlla «I miei annunci».',
  'treasure_draft_images_missing':
      'I testi della bozza sono stati caricati, ma le foto precedenti non sono più disponibili. Aggiungile di nuovo.',
  'treasure_legacy_body':
      'Le bozze locali, i contrassegni di prenotazione e di sicurezza non appartengono ancora a nessun account. Dopo l\'accesso puoi confermarne la proprietà.',
  'treasure_legacy_claim': 'Conferma la proprietà',
  'treasure_legacy_confirm':
      'Confermi che questi dati ti appartengono? Verranno assegnati a questo account. Una bozza già presente nell\'account ha la precedenza. I dati originali restano intatti; nulla viene pubblicato.',
  'treasure_legacy_title': 'Dati locali non assegnati',
  'treasure_location_required':
      'Serve una posizione per le offerte vicine a te.',
  'treasure_market_unavailable':
      'Il Mercatino del dono al momento non è disponibile. La tua offerta non è stata pubblicata.',
  'treasure_photo_analysis_failed':
      'Non è stato possibile completare l\'analisi della foto. La foto e ciò che hai inserito manualmente restano intatti.',
  'treasure_photo_consent_accept': 'Accetto e analizza la foto',
  'treasure_photo_consent_body':
      'Per avere suggerimenti sul tuo oggetto questa foto viene inviata tramite il backend ParentPeak a Google Gemini. I contenuti dell\'immagine non vengono anonimizzati. Usa solo foto dell\'oggetto senza persone, documenti privati o indirizzi riconoscibili. L\'analisi è facoltativa; senza consenso puoi conservare la foto e compilare l\'annuncio manualmente. Questo consenso vale solo per la foto-IA del Mercatino del dono e viene salvato per questo account. Non pubblica né la foto né l\'annuncio.',
  'treasure_photo_consent_failed':
      'Non è stato possibile salvare il consenso. Nessuna foto è stata inviata all\'IA.',
  'treasure_photo_consent_title': 'Analizzare la foto con l\'IA?',
  'treasure_photos_public_info':
      'Al momento della pubblicazione le foto vengono caricate pubblicamente. Anche in caso di errore successivo possono restare accessibili. Non mostrare persone, documenti privati o indirizzi.',
  'treasure_publish_unavailable':
      'Per pubblicare servono un account con accesso effettuato e un server del mercatino disponibile. Nessuna foto è stata caricata.',
  'treasure_publish_uncertain':
      'Non è stato possibile confermare la creazione. Le foto caricate potrebbero essere accessibili pubblicamente. Controlla «I miei annunci» prima di riprovare.',
  'treasure_published_local_failed':
      'Il server ha creato l\'annuncio, ma i dati locali non sono stati aggiornati. Controlla «I miei annunci»; non ripubblicare.',
  'treasure_reservation_offline':
      'Senza connessione al server del mercatino non è stato prenotato nulla. Riprova quando sei online.',
  'treasure_reserve_local_failed':
      'Il server ha confermato la prenotazione, ma il contrassegno locale non è stato salvato. Controlla «I miei annunci» prima di prenotare di nuovo.',
  'treasure_signin_required':
      'Accedi per eseguire questa azione nel Mercatino del dono.',
  'treasure_storage_failed':
      'Non è stato possibile caricare o salvare i dati del mercatino. Riprova.',
  'treasure_upload_batch_failed':
      'Non è stato possibile caricare tutte le foto. Le foto caricate sono state rimosse; nessun annuncio è stato inviato.',
  'treasure_upload_cleanup_failed':
      'Il caricamento delle foto non è riuscito. Nessun annuncio è stato inviato, ma alcune foto caricate non sono state rimosse e potrebbero restare accessibili pubblicamente.',
  'uexam_window_j1': '12°–14° anno di età',
  'uexam_window_j2': '16°–17° anno di età',
  'uexam_window_u1': 'subito dopo la nascita',
  'uexam_window_u2': '3°–10° giorno di vita',
  'uexam_window_u3': '4ª–5ª settimana',
  'uexam_window_u4': '3°–4° mese',
  'uexam_window_u5': '6°–7° mese',
  'uexam_window_u6': '10°–12° mese',
  'uexam_window_u7': '21°–24° mese',
  'uexam_window_u7a': '34°–36° mese',
  'uexam_window_u8': '46°–48° mese',
  'uexam_window_u9': '60°–64° mese',
  'used_for_greeting': 'Viene usato per il saluto e nella rete.',
  'view_it': 'Vedi →',
  'weekly_kita_imported': '{count} voci dell\'asilo importate.',
  'weekly_review': 'Bilancio della settimana',
  'welcome_title': 'Benvenuto/a su\nParentpeak',
  'what_concerns_you': 'Cosa ti sta a cuore?',
  'what_did_you_learn': 'Cosa hai imparato?',
  'what_was_challenging': 'Cosa è stato impegnativo?',
  'what_went_well': 'Cosa è andato davvero bene?',
  'where_family_lives': 'Dove vive la vostra famiglia?',
  'your_code': 'Il tuo codice:',
  'your_link': 'Il tuo link:',
  'your_weekly_review': 'Il tuo bilancio della settimana',
};
