enum AppLang { fr, ar }

/// App texts in French and Arabic. `{name}` placeholders are replaced by
/// the arguments given to [t].
class L10n {
  const L10n(this.lang);

  final AppLang lang;

  String t(String key, [Map<String, Object> args = const {}]) {
    final entry = strings[key];
    var text = entry == null ? key : (lang == AppLang.ar ? entry.$2 : entry.$1);
    args.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
    return text;
  }

  static const strings = <String, (String, String)>{
    // General
    'ok': ('OK', 'حسنا'),
    'cancel': ('Annuler', 'إلغاء'),
    'save': ('Enregistrer', 'حفظ'),
    'delete': ('Supprimer', 'حذف'),
    'edit': ('Modifier', 'تعديل'),
    'remove': ('Retirer', 'إزالة'),
    'retry': ('Réessayer', 'إعادة المحاولة'),
    'error': ('Erreur', 'خطأ'),
    'all': ('Tous', 'الكل'),
    'done': ('Terminé !', 'تم!'),
    'startup_error': ('Erreur au démarrage :', 'خطأ عند التشغيل:'),
    'tagline': (
      'Reconnaissance faciale pour les écoles',
      'التعرف على الوجه للمدارس',
    ),

    // Login / account
    'login_title': ('Connexion', 'تسجيل الدخول'),
    'login': ('Se connecter', 'دخول'),
    'logout': ('Se déconnecter', 'تسجيل الخروج'),
    'logout_confirm': (
      'Voulez-vous vous déconnecter de ce téléphone ?',
      'هل تريد تسجيل الخروج من هذا الهاتف؟',
    ),
    'logout_pending_warning': (
      '{n} modification(s) ne sont pas encore envoyées au serveur. '
          'Elles seront envoyées à votre prochaine connexion.',
      '{n} تعديل(ات) لم تُرسل بعد إلى الخادم. '
          'ستُرسل عند تسجيل دخولك القادم.',
    ),
    'login_missing': (
      'Saisissez votre identifiant et votre mot de passe.',
      'أدخل اسم المستخدم وكلمة المرور.',
    ),
    'username': ('Identifiant', 'اسم المستخدم'),
    'username_rule': (
      '3 caractères minimum : lettres, chiffres, point, tiret',
      '3 أحرف على الأقل: حروف لاتينية، أرقام، نقطة، شرطة',
    ),
    'password': ('Mot de passe', 'كلمة المرور'),
    'password_confirm': ('Confirmer le mot de passe', 'تأكيد كلمة المرور'),
    'password_rule': (
      'Le mot de passe doit contenir au moins 6 caractères.',
      'يجب أن تحتوي كلمة المرور على 6 أحرف على الأقل.',
    ),
    'password_mismatch': (
      'Les mots de passe ne correspondent pas.',
      'كلمتا المرور غير متطابقتين.',
    ),
    'create_account': ('Créer un compte', 'إنشاء حساب'),
    'register_intro': (
      'Créez votre compte agent. Il restera en attente jusqu’à ce que '
          'l’administrateur de votre école l’autorise.',
      'أنشئ حساب العون الخاص بك. سيبقى في الانتظار حتى يوافق عليه '
          'مدير مدرستك.',
    ),
    'school': ('École', 'المدرسة'),
    'choose_school': ('Choisissez votre école.', 'اختر مدرستك.'),
    'full_name': ('Nom complet', 'الاسم الكامل'),
    'full_name_required': (
      'Le nom complet est obligatoire.',
      'الاسم الكامل إلزامي.',
    ),
    'phone': ('Téléphone', 'الهاتف'),
    'account_created': ('Compte créé', 'تم إنشاء الحساب'),
    'account_pending_info': (
      'Votre compte est en attente. L’administrateur de votre école doit '
          'l’autoriser avant que vous puissiez vous connecter.',
      'حسابك في الانتظار. يجب أن يوافق عليه مدير مدرستك قبل أن '
          'تتمكن من تسجيل الدخول.',
    ),
    'server_settings': ('Paramètres du serveur', 'إعدادات الخادم'),
    'server_address': ('Adresse du serveur', 'عنوان الخادم'),
    'role_admin': ('Administrateur', 'مدير'),
    'role_agent': ('Agent', 'عون'),
    'my_permissions': ('Mes permissions', 'صلاحياتي'),
    'perm_scan': ('Scanner / reconnaître', 'المسح / التعرف'),
    'perm_edit': ('Ajouter et modifier des fiches', 'إضافة وتعديل البطاقات'),
    'perm_delete': ('Supprimer des fiches', 'حذف البطاقات'),
    'perm_sensitive': (
      'Voir les données sensibles (santé, parents)',
      'رؤية البيانات الحساسة (الصحة، الأولياء)',
    ),
    'no_permissions': (
      'Votre compte n’a encore aucune permission. Contactez l’administrateur.',
      'حسابك لا يملك أي صلاحية بعد. اتصل بالمدير.',
    ),

    // Home / settings
    'settings': ('Réglages', 'الإعدادات'),
    'language': ('Langue', 'اللغة'),
    'online': ('Connecté au serveur', 'متصل بالخادم'),
    'offline': ('Hors ligne', 'غير متصل'),
    'connecting': ('Connexion…', 'جارٍ الاتصال…'),
    'connection_ok': (
      'Connexion au serveur réussie.',
      'تم الاتصال بالخادم بنجاح.',
    ),
    'offline_info': (
      'La reconnaissance se fait avec les personnes de ce téléphone.',
      'يتم التعرف باستخدام الأشخاص المسجلين في هذا الهاتف.',
    ),
    'people_on_phone': ('sur ce téléphone', 'في هذا الهاتف'),
    'pending_upload': ('en attente d’envoi', 'في انتظار الإرسال'),
    'all_synced': (
      'Toutes les fiches sont envoyées au serveur.',
      'تم إرسال جميع البطاقات إلى الخادم.',
    ),
    'pending_changes': (
      '{n} modification(s) en attente d’envoi.',
      '{n} تعديل(ات) في انتظار الإرسال.',
    ),
    'sync_now': ('Synchroniser maintenant', 'مزامنة الآن'),
    'save_and_test': ('Enregistrer et tester', 'حفظ واختبار'),
    'device_id': ('Identifiant de l’appareil', 'معرّف الجهاز'),
    'scan_face': ('Scanner un visage', 'مسح وجه'),
    'scan_subtitle': (
      'Identifier une personne en un instant',
      'التعرف على شخص في لحظة',
    ),
    'people': ('Personnes', 'الأشخاص'),
    'add': ('Ajouter', 'إضافة'),

    // People list / record
    'search_hint': ('Nom, matricule, classe…', 'الاسم، الرقم، القسم…'),
    'nobody_yet': (
      'Aucune personne enregistrée sur ce téléphone.',
      'لا يوجد أي شخص مسجل في هذا الهاتف.',
    ),
    'no_results': ('Aucun résultat.', 'لا توجد نتائج.'),
    'person_deleted': ('Cette personne a été supprimée.', 'تم حذف هذا الشخص.'),
    'delete_person_title': ('Supprimer {name} ?', 'حذف {name}؟'),
    'delete_person_info': (
      'Sa fiche et ses photos seront effacées, aussi sur le serveur.',
      'سيتم حذف بطاقته وصوره، وأيضا من الخادم.',
    ),
    'synced': ('Envoyé au serveur', 'أُرسل إلى الخادم'),
    'not_synced': ('En attente d’envoi', 'في انتظار الإرسال'),
    'updated_on': ('modifié le', 'عُدّل في'),
    'sensitive_hidden': (
      'Données sensibles masquées (permission requise).',
      'البيانات الحساسة مخفية (تتطلب صلاحية).',
    ),

    // Person fields
    'type_eleve': ('Élève', 'تلميذ'),
    'type_enseignant': ('Enseignant', 'أستاذ'),
    'type_personnel': ('Personnel', 'موظف'),
    'type_surveillant': ('Surveillant', 'مراقب'),
    'type_autre': ('Autre', 'آخر'),
    'status': ('Statut', 'الحالة'),
    'status_actif': ('Actif', 'نشط'),
    'status_parti': ('Parti', 'غادر'),
    'status_suspendu': ('Suspendu', 'موقوف'),
    'section_identity': ('Identité', 'الهوية'),
    'section_school': ('Scolarité', 'الدراسة'),
    'section_job': ('Fonction', 'الوظيفة'),
    'section_parents': ('Parents / contact', 'الأولياء / الاتصال'),
    'section_contact': ('Contact', 'الاتصال'),
    'section_health': ('Santé', 'الصحة'),
    'last_name': ('Nom', 'اللقب'),
    'first_name': ('Prénom', 'الاسم'),
    'matricule': ('Matricule', 'الرقم التسلسلي'),
    'sex': ('Sexe', 'الجنس'),
    'sex_m': ('Masculin', 'ذكر'),
    'sex_f': ('Féminin', 'أنثى'),
    'birth_date': ('Date de naissance', 'تاريخ الميلاد'),
    'class_level': ('Classe / niveau', 'القسم / المستوى'),
    'school_year': ('Année scolaire', 'السنة الدراسية'),
    'enrollment_date': ('Date d’inscription', 'تاريخ التسجيل'),
    'job_title': ('Fonction', 'الوظيفة'),
    'parent_name': ('Nom du parent', 'اسم الولي'),
    'parent_phone': ('Téléphone du parent', 'هاتف الولي'),
    'address': ('Adresse', 'العنوان'),
    'medical': ('Informations médicales', 'معلومات طبية'),
    'medical_hint': (
      'Allergies, traitements, remarques médicales',
      'الحساسية، العلاج، ملاحظات طبية',
    ),
    'notes': ('Remarques', 'ملاحظات'),

    // Form
    'new_person': ('Nouvelle personne', 'شخص جديد'),
    'edit_person': ('Modifier la fiche', 'تعديل البطاقة'),
    'face': ('Visage', 'الوجه'),
    'guided_info': (
      'L’enregistrement guidé prend automatiquement 5 photos : de face, '
          'à gauche, à droite, en haut et en bas.',
      'التسجيل الموجَّه يلتقط 5 صور تلقائيا: من الأمام، يسارا، يمينا، '
          'إلى الأعلى وإلى الأسفل.',
    ),
    'guided_start': ('Enregistrer le visage (guidé)', 'تسجيل الوجه (موجَّه)'),
    'guided_redo': ('Refaire l’enregistrement guidé', 'إعادة التسجيل الموجَّه'),
    'add_from_gallery': (
      'Ajouter une photo depuis la galerie',
      'إضافة صورة من المعرض',
    ),
    'max_photos': ('Maximum {n} photos.', 'الحد الأقصى {n} صور.'),
    'no_face_in_photo': (
      'Aucun visage détecté sur cette photo.',
      'لم يتم اكتشاف أي وجه في هذه الصورة.',
    ),
    'several_faces': (
      '{n} visages détectés : il en faut un seul.',
      'تم اكتشاف {n} وجوه: يجب وجه واحد فقط.',
    ),
    'remove_photo': ('Retirer cette photo ?', 'إزالة هذه الصورة؟'),
    'name_required': (
      'Le nom ou le prénom est obligatoire.',
      'اللقب أو الاسم إلزامي.',
    ),
    'face_required': ('Enregistrez d’abord le visage.', 'سجّل الوجه أولا.'),
    'duplicate_title': ('Visage déjà enregistré ?', 'وجه مسجل مسبقا؟'),
    'duplicate_info': (
      'Ce visage ressemble à « {name} » ({score} %). Enregistrer quand même ?',
      'هذا الوجه يشبه « {name} » ({score} %). هل تريد الحفظ رغم ذلك؟',
    ),
    'saved_person': ('{name} enregistré(e).', 'تم حفظ {name}.'),

    // Guided enrollment
    'enroll_title': ('Enregistrement du visage', 'تسجيل الوجه'),
    'pose_front': ('Regardez droit devant', 'انظر إلى الأمام مباشرة'),
    'pose_left': (
      'Tournez lentement la tête à gauche',
      'أدر رأسك ببطء إلى اليسار',
    ),
    'pose_right': (
      'Tournez lentement la tête à droite',
      'أدر رأسك ببطء إلى اليمين',
    ),
    'pose_up': ('Levez légèrement la tête', 'ارفع رأسك قليلا'),
    'pose_down': ('Baissez légèrement la tête', 'اخفض رأسك قليلا'),
    'hint_place_face': (
      'Placez votre visage dans le cadre',
      'ضع وجهك داخل الإطار',
    ),
    'hint_one_person': (
      'Une seule personne devant la caméra',
      'شخص واحد فقط أمام الكاميرا',
    ),
    'poses_progress': ('{n} / {total} poses', '{n} / {total} وضعيات'),
    'finish_now': ('Terminer maintenant', 'إنهاء الآن'),
    'switch_camera': ('Changer de caméra', 'تبديل الكاميرا'),
    'camera_none': ('Aucune caméra disponible.', 'لا توجد كاميرا متاحة.'),
    'camera_denied': (
      'Accès à la caméra refusé.\nAutorisez-le dans les paramètres du téléphone.',
      'تم رفض الوصول إلى الكاميرا.\nاسمح به في إعدادات الهاتف.',
    ),
    'camera_unavailable': (
      'Caméra indisponible ({code}).',
      'الكاميرا غير متاحة ({code}).',
    ),

    // Scan
    'from_gallery': ('Depuis la galerie', 'من المعرض'),
    'no_face': ('Aucun visage détecté', 'لم يتم اكتشاف أي وجه'),
    'no_face_tip': (
      'Placez le visage de face, bien éclairé, dans le cadre.',
      'ضع الوجه من الأمام، في إضاءة جيدة، داخل الإطار.',
    ),
    'recognized': ('Personne reconnue', 'تم التعرف على الشخص'),
    'to_check': ('À vérifier', 'يجب التحقق'),
    'unknown': ('INCONNU', 'مجهول'),
    'unknown_info': (
      'Ce visage ne correspond à aucune personne de votre école.',
      'هذا الوجه لا يطابق أي شخص في مدرستك.',
    ),
    'uncertain_info': (
      'Ressemblance partielle. Vérifiez l’identité avant de conclure.',
      'تشابه جزئي. تحقق من الهوية قبل الحكم.',
    ),
    'similarity': ('Similarité', 'التشابه'),
    'online_base': ('Base en ligne', 'القاعدة على الإنترنت'),
    'open_record': ('Voir la fiche complète', 'عرض البطاقة كاملة'),
    'offline_scan_note': (
      'Hors ligne : comparaison avec ce téléphone uniquement.',
      'غير متصل: المقارنة مع هذا الهاتف فقط.',
    ),
    'other_faces': (
      '{n} autre(s) visage(s) sur la photo : seul le plus grand a été analysé.',
      '{n} وجه/وجوه أخرى في الصورة: تم تحليل الأكبر فقط.',
    ),
  };
}
