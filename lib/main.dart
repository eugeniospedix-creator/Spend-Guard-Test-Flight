import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

// Google Places API key for real store detection.
// Restrict this key in Google Cloud to your iOS bundle ID before public release.
const String googlePlacesApiKey = 'AIzaSyCxvHl7eUjN3GLRWmk45tdXJboXLcSxEFo';
const String spendGuardAppIcon = 'assets/images/spendguard_app_icon.png';

bool firebaseReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.init();
  runApp(const SpendGuardApp());

  unawaited(_startFirebaseSafely());
}

Future<void> _startFirebaseSafely() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase startup skipped: $e');
  }
}

class AppColors {
  static const bg = Color(0xFF06111F);
  static const bgDeep = Color(0xFF020617);
  static const card = Color(0xFF0E1A2D);
  static const card2 = Color(0xFF111F34);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const teal = Color(0xFF2DD4BF);
  static const blue = Color(0xFF38BDF8);
  static const purple = Color(0xFF8B5CF6);
  static const amber = Color(0xFFFBBF24);
  static const red = Color(0xFFFB7185);
  static const green = Color(0xFF22C55E);
}

enum AppLanguage { en, it, es, fr }

class AppText {
  static const Map<AppLanguage, Map<String, String>> _v = {
    AppLanguage.en: {
      'home': 'Home',
      'gps': 'GPS',
      'friends': 'Friends',
      'goals': 'Goals',
      'settings': 'Settings',
      'safeToday': 'Safe to spend today',
      'storeDetected': 'Store detected',
      'noStore': 'No store detected',
      'protect': 'Protect money',
      'setup': 'Setup',
      'futureImpact': 'Future impact',
      'buyNow': 'Buy anyway',
      'keepDream': 'Lock this money',
      'gpsRadar': 'GPS Radar',
      'checkGps': 'Check GPS now',
      'inviteFriends': 'Invite friends',
      'friendRequests': 'Friend requests',
      'chat': 'Chat',
      'send': 'Send',
      'message': 'Message',
      'language': 'Language',
      'notifications': 'Notifications',
      'enterStoreAlert': 'When I enter a store',
      'exitStoreAlert': 'When I leave a store',
      'beforeBuyAlert': 'Before I buy',
      'afterBuyAlert': 'After I buy',
      'highRiskOnly': 'High-risk stores only',
      'gpsSensitivity': 'GPS sensitivity',
      'budget': 'Budget',
      'income': 'Monthly income',
      'expenses': 'Fixed expenses',
      'dreamName': 'Dream name',
      'target': 'Dream target',
      'saved': 'Already saved',
      'months': 'Months to goal',
      'save': 'Save',
      'ready': 'Ready to protect your future?',
      'about': 'SpendGuard helps you know before you buy.',
    },
    AppLanguage.it: {
      'home': 'Home',
      'gps': 'GPS',
      'friends': 'Amici',
      'goals': 'Obiettivi',
      'settings': 'Impostazioni',
      'safeToday': 'Puoi spendere oggi',
      'storeDetected': 'Negozio rilevato',
      'noStore': 'Nessun negozio rilevato',
      'protect': 'Proteggi soldi',
      'setup': 'Imposta',
      'futureImpact': 'Impatto futuro',
      'buyNow': 'Compra comunque',
      'keepDream': 'Blocca questi soldi',
      'gpsRadar': 'Radar GPS',
      'checkGps': 'Controlla GPS ora',
      'inviteFriends': 'Invita amici',
      'friendRequests': 'Richieste amicizia',
      'chat': 'Chat',
      'send': 'Invia',
      'message': 'Messaggio',
      'language': 'Lingua',
      'notifications': 'Notifiche',
      'enterStoreAlert': 'Quando entro in un negozio',
      'exitStoreAlert': 'Quando esco da un negozio',
      'beforeBuyAlert': 'Prima di comprare',
      'afterBuyAlert': 'Dopo aver comprato',
      'highRiskOnly': 'Solo negozi ad alto rischio',
      'gpsSensitivity': 'Sensibilità GPS',
      'budget': 'Budget',
      'income': 'Entrata mensile',
      'expenses': 'Spese fisse',
      'dreamName': 'Nome obiettivo',
      'target': 'Costo obiettivo',
      'saved': 'Già risparmiato',
      'months': 'Mesi all’obiettivo',
      'save': 'Salva',
      'ready': 'Pronto a proteggere il futuro?',
      'about': 'SpendGuard ti aiuta a sapere prima di comprare.',
    },
    AppLanguage.es: {
      'home': 'Inicio',
      'gps': 'GPS',
      'friends': 'Amigos',
      'goals': 'Metas',
      'settings': 'Ajustes',
      'safeToday': 'Seguro para gastar hoy',
      'storeDetected': 'Tienda detectada',
      'noStore': 'Ninguna tienda detectada',
      'protect': 'Proteger dinero',
      'setup': 'Configurar',
      'futureImpact': 'Impacto futuro',
      'buyNow': 'Comprar igual',
      'keepDream': 'Bloquear este dinero',
      'gpsRadar': 'Radar GPS',
      'checkGps': 'Comprobar GPS',
      'inviteFriends': 'Invitar amigos',
      'friendRequests': 'Solicitudes',
      'chat': 'Chat',
      'send': 'Enviar',
      'message': 'Mensaje',
      'language': 'Idioma',
      'notifications': 'Notificaciones',
      'enterStoreAlert': 'Al entrar en una tienda',
      'exitStoreAlert': 'Al salir de una tienda',
      'beforeBuyAlert': 'Antes de comprar',
      'afterBuyAlert': 'Después de comprar',
      'highRiskOnly': 'Solo tiendas de alto riesgo',
      'gpsSensitivity': 'Sensibilidad GPS',
      'budget': 'Presupuesto',
      'income': 'Ingreso mensual',
      'expenses': 'Gastos fijos',
      'dreamName': 'Nombre de la meta',
      'target': 'Objetivo',
      'saved': 'Ya ahorrado',
      'months': 'Meses',
      'save': 'Guardar',
      'ready': '¿Listo para proteger tu futuro?',
      'about': 'SpendGuard te ayuda a saber antes de comprar.',
    },
    AppLanguage.fr: {
      'home': 'Accueil',
      'gps': 'GPS',
      'friends': 'Amis',
      'goals': 'Objectifs',
      'settings': 'Réglages',
      'safeToday': 'Sûr à dépenser aujourd’hui',
      'storeDetected': 'Magasin détecté',
      'noStore': 'Aucun magasin détecté',
      'protect': 'Protéger l’argent',
      'setup': 'Configurer',
      'futureImpact': 'Impact futur',
      'buyNow': 'Acheter quand même',
      'keepDream': 'Verrouiller cet argent',
      'gpsRadar': 'Radar GPS',
      'checkGps': 'Vérifier GPS',
      'inviteFriends': 'Inviter des amis',
      'friendRequests': 'Demandes d’amis',
      'chat': 'Chat',
      'send': 'Envoyer',
      'message': 'Message',
      'language': 'Langue',
      'notifications': 'Notifications',
      'enterStoreAlert': 'Quand j’entre dans un magasin',
      'exitStoreAlert': 'Quand je quitte un magasin',
      'beforeBuyAlert': 'Avant d’acheter',
      'afterBuyAlert': 'Après achat',
      'highRiskOnly': 'Magasins à haut risque seulement',
      'gpsSensitivity': 'Sensibilité GPS',
      'budget': 'Budget',
      'income': 'Revenu mensuel',
      'expenses': 'Dépenses fixes',
      'dreamName': 'Nom de l’objectif',
      'target': 'Objectif',
      'saved': 'Déjà économisé',
      'months': 'Mois',
      'save': 'Enregistrer',
      'ready': 'Prêt à protéger ton futur ?',
      'about': 'SpendGuard t’aide à savoir avant d’acheter.',
    },
  };

  static String t(AppLanguage lang, String key) => _v[lang]?[key] ?? _v[AppLanguage.en]![key] ?? key;
}

class SpendGuardApp extends StatefulWidget {
  const SpendGuardApp({super.key});

  @override
  State<SpendGuardApp> createState() => _SpendGuardAppState();
}

class _SpendGuardAppState extends State<SpendGuardApp> {
  AppLanguage language = AppLanguage.en;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final p = await SharedPreferences.getInstance();
    final name = p.getString('language') ?? 'en';
    setState(() {
      language = AppLanguage.values.firstWhere((e) => e.name == name, orElse: () => AppLanguage.en);
      loaded = true;
    });
  }

  Future<void> _setLanguage(AppLanguage value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('language', value.name);
    setState(() => language = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const SizedBox.shrink();
    return AppLanguageScope(
      language: language,
      onChanged: _setLanguage,
      child: MaterialApp(
        title: 'SpendGuard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.bg,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.teal, brightness: Brightness.dark),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withOpacity(0.07),
            labelStyle: const TextStyle(color: AppColors.muted),
            hintStyle: TextStyle(color: AppColors.muted.withOpacity(0.75)),
            prefixIconColor: AppColors.muted,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}


class AppLanguageScope extends InheritedWidget {
  final AppLanguage language;
  final Future<void> Function(AppLanguage) onChanged;

  const AppLanguageScope({super.key, required this.language, required this.onChanged, required super.child});

  static AppLanguageScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppLanguageScope>()!;
  static String text(BuildContext context, String key) => AppText.t(of(context).language, key);

  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) => language != oldWidget.language;
}

String tr(BuildContext context, String key) => AppLanguageScope.text(context, key);

class NotificationService {
  static final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await plugin.initialize(settings);
  }

  static Future<void> show(String title, String body) async {
    if (kIsWeb) return;
    const android = AndroidNotificationDetails(
      'spendguard_alerts',
      'SpendGuard Alerts',
      channelDescription: 'GPS spending alerts.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const ios = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
    await plugin.show(1001, title, body, const NotificationDetails(android: android, iOS: ios));
  }
}

class BudgetData {
  final double income;
  final double fixedExpenses;
  final double dreamTarget;
  final double dreamSaved;
  final double dreamMonths;
  final double dreamVault;
  final String dreamName;

  const BudgetData({
    required this.income,
    required this.fixedExpenses,
    required this.dreamTarget,
    required this.dreamSaved,
    required this.dreamMonths,
    required this.dreamVault,
    required this.dreamName,
  });

  static const empty = BudgetData(
    income: 0,
    fixedExpenses: 0,
    dreamTarget: 0,
    dreamSaved: 0,
    dreamMonths: 0,
    dreamVault: 0,
    dreamName: '',
  );

  bool get isReady => income > 0;
  bool get hasDream => dreamTarget > 0 && dreamMonths > 0;
  double get monthlyRoom => max(0, income - fixedExpenses).toDouble();
  double get baseSafeToday => monthlyRoom / 30;
  double get dreamDays => max(1, dreamMonths * 30).toDouble();
  double get dreamTotalProtected => dreamSaved + dreamVault;
  double get dreamRemaining => max(0, dreamTarget - dreamTotalProtected).toDouble();
  double get dreamDailyNeed => hasDream ? dreamRemaining / dreamDays : 0;
  double get safeToday => max(0, baseSafeToday - dreamDailyNeed).toDouble();
  double get dreamProgress => dreamTarget <= 0 ? 0 : (dreamTotalProtected / dreamTarget).clamp(0, 1).toDouble();
  int get daysRemaining => hasDream ? max(0, (dreamDays * (1 - dreamProgress)).ceil()) : 0;

  int delayDaysFor(double amount) {
    if (!hasDream || amount <= 0 || dreamDailyNeed <= 0) return 0;
    return (amount / dreamDailyNeed).ceil();
  }

  BudgetData copyWith({
    double? income,
    double? fixedExpenses,
    double? dreamTarget,
    double? dreamSaved,
    double? dreamMonths,
    double? dreamVault,
    String? dreamName,
  }) {
    return BudgetData(
      income: income ?? this.income,
      fixedExpenses: fixedExpenses ?? this.fixedExpenses,
      dreamTarget: dreamTarget ?? this.dreamTarget,
      dreamSaved: dreamSaved ?? this.dreamSaved,
      dreamMonths: dreamMonths ?? this.dreamMonths,
      dreamVault: dreamVault ?? this.dreamVault,
      dreamName: dreamName ?? this.dreamName,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('income', income);
    await p.setDouble('fixedExpenses', fixedExpenses);
    await p.setDouble('dreamTarget', dreamTarget);
    await p.setDouble('dreamSaved', dreamSaved);
    await p.setDouble('dreamMonths', dreamMonths);
    await p.setDouble('dreamVault', dreamVault);
    await p.setString('dreamName', dreamName);
    await p.setBool('setupDone', true);
  }

  static Future<BudgetData> load() async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool('setupDone') ?? false)) return BudgetData.empty;
    return BudgetData(
      income: p.getDouble('income') ?? 0,
      fixedExpenses: p.getDouble('fixedExpenses') ?? 0,
      dreamTarget: p.getDouble('dreamTarget') ?? 0,
      dreamSaved: p.getDouble('dreamSaved') ?? 0,
      dreamMonths: p.getDouble('dreamMonths') ?? 0,
      dreamVault: p.getDouble('dreamVault') ?? 0,
      dreamName: p.getString('dreamName') ?? '',
    );
  }
}


class NotificationPrefs {
  final bool onEnter;
  final bool onExit;
  final bool beforeBuying;
  final bool afterBuying;
  final bool highRiskOnly;
  final double detectionRadiusMeters;

  const NotificationPrefs({
    required this.onEnter,
    required this.onExit,
    required this.beforeBuying,
    required this.afterBuying,
    required this.highRiskOnly,
    required this.detectionRadiusMeters,
  });

  static const defaults = NotificationPrefs(
    onEnter: true,
    onExit: true,
    beforeBuying: true,
    afterBuying: true,
    highRiskOnly: false,
    detectionRadiusMeters: 25,
  );

  NotificationPrefs copyWith({
    bool? onEnter,
    bool? onExit,
    bool? beforeBuying,
    bool? afterBuying,
    bool? highRiskOnly,
    double? detectionRadiusMeters,
  }) {
    return NotificationPrefs(
      onEnter: onEnter ?? this.onEnter,
      onExit: onExit ?? this.onExit,
      beforeBuying: beforeBuying ?? this.beforeBuying,
      afterBuying: afterBuying ?? this.afterBuying,
      highRiskOnly: highRiskOnly ?? this.highRiskOnly,
      detectionRadiusMeters: detectionRadiusMeters ?? this.detectionRadiusMeters,
    );
  }

  bool allows(StoreInfo store) => !highRiskOnly || store.risk >= 45;

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notifyOnEnter', onEnter);
    await p.setBool('notifyOnExit', onExit);
    await p.setBool('notifyBeforeBuying', beforeBuying);
    await p.setBool('notifyAfterBuying', afterBuying);
    await p.setBool('notifyHighRiskOnly', highRiskOnly);
    await p.setDouble('detectionRadiusMeters', detectionRadiusMeters);
  }

  static Future<NotificationPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    return NotificationPrefs(
      onEnter: p.getBool('notifyOnEnter') ?? defaults.onEnter,
      onExit: p.getBool('notifyOnExit') ?? defaults.onExit,
      beforeBuying: p.getBool('notifyBeforeBuying') ?? defaults.beforeBuying,
      afterBuying: p.getBool('notifyAfterBuying') ?? defaults.afterBuying,
      highRiskOnly: p.getBool('notifyHighRiskOnly') ?? defaults.highRiskOnly,
      detectionRadiusMeters: p.getDouble('detectionRadiusMeters') ?? defaults.detectionRadiusMeters,
    );
  }
}

class StoreInfo {
  final String name;
  final String category;
  final double lat;
  final double lng;
  final double radius;
  final int risk;

  const StoreInfo({required this.name, required this.category, required this.lat, required this.lng, required this.radius, required this.risk});

  String get riskLabel {
    if (risk >= 75) return 'DANGER';
    if (risk >= 45) return 'CAUTION';
    return 'SAFE';
  }

  Color get color {
    if (risk >= 75) return AppColors.red;
    if (risk >= 45) return AppColors.amber;
    return AppColors.green;
  }
}


class RealStoreService {
  static bool get hasApiKey => googlePlacesApiKey.trim().isNotEmpty;

  static Future<StoreInfo?> detectNearestStore(Position position, {double radiusMeters = 25}) async {
    if (!hasApiKey) return null;

    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', {
      'location': '${position.latitude},${position.longitude}',
      'radius': radiusMeters.round().clamp(10, 50).toString(),
      'type': 'store',
      'key': googlePlacesApiKey,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (decoded['results'] as List?) ?? [];
      if (results.isEmpty) return null;

      Map<String, dynamic>? best;
      double bestDistance = double.infinity;

      for (final item in results.take(10)) {
        final place = item as Map<String, dynamic>;
        final location = (place['geometry'] as Map<String, dynamic>?)?['location'] as Map<String, dynamic>?;
        if (location == null) continue;

        final lat = (location['lat'] as num).toDouble();
        final lng = (location['lng'] as num).toDouble();
        final distance = Geolocator.distanceBetween(position.latitude, position.longitude, lat, lng);

        if (distance < bestDistance) {
          bestDistance = distance;
          best = place;
        }
      }

      if (best == null || bestDistance > radiusMeters) return null;

      final location = (best['geometry'] as Map<String, dynamic>)['location'] as Map<String, dynamic>;
      final name = (best['name'] ?? 'Nearby store').toString();
      final types = ((best['types'] as List?) ?? []).map((e) => e.toString()).toList();
      final category = _categoryFromTypes(name, types);
      final risk = _riskForCategory(category);

      return StoreInfo(
        name: name,
        category: category,
        lat: (location['lat'] as num).toDouble(),
        lng: (location['lng'] as num).toDouble(),
        radius: radiusMeters,
        risk: risk,
      );
    } catch (_) {
      return null;
    }
  }

  static String _categoryFromTypes(String name, List<String> types) {
    final n = name.toLowerCase();
    if (types.contains('grocery_or_supermarket') || n.contains('supermarket') || n.contains('tesco') || n.contains('lidl') || n.contains('aldi') || n.contains('spar')) return 'Groceries';
    if (types.contains('clothing_store') || n.contains('zara') || n.contains('primark') || n.contains('h&m') || n.contains('tk maxx')) return 'Clothing';
    if (types.contains('electronics_store') || n.contains('currys') || n.contains('apple')) return 'Electronics';
    if (types.contains('restaurant') || types.contains('cafe') || types.contains('bakery') || types.contains('meal_takeaway')) return 'Food & Coffee';
    if (types.contains('pharmacy')) return 'Health';
    return 'Shopping';
  }

  static int _riskForCategory(String category) {
    switch (category) {
      case 'Groceries':
        return 25;
      case 'Health':
        return 35;
      case 'Food & Coffee':
        return 45;
      case 'Clothing':
        return 62;
      case 'Electronics':
        return 86;
      default:
        return 55;
    }
  }
}

class StoreDecision {
  final StoreInfo store;
  final double safeAmount;
  final int delayDays;
  final bool stop;

  const StoreDecision({required this.store, required this.safeAmount, required this.delayDays, required this.stop});

  String message(String dreamName) {
    if (stop || safeAmount <= 0) return 'STOP. Protect ${dreamName.isEmpty ? 'your dream' : dreamName} today.';
    return 'Safe here: €${safeAmount.toStringAsFixed(2)}. Extra spending could delay your dream by $delayDays day(s).';
  }
}

class FriendRequest {
  final String name;
  final String status;
  const FriendRequest(this.name, this.status);
}

class ChatMessage {
  final String sender;
  final String text;
  final DateTime time;
  const ChatMessage(this.sender, this.text, this.time);
}


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..forward();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final p = await SharedPreferences.getInstance();
    final done = p.getBool('onboardingDone') ?? false;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => done ? const MainScreen() : const OnboardingScreen()));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final v = controller.value;
              final first = Curves.easeOut.transform((v / .35).clamp(0.0, 1.0));
              final second = Curves.easeOut.transform(((v - .25) / .35).clamp(0.0, 1.0));
              final third = Curves.easeOut.transform(((v - .55) / .35).clamp(0.0, 1.0));
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: 0.85 + (third * 0.25),
                    child: Opacity(
                      opacity: (0.12 + third * 0.42).clamp(0.0, 0.55),
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.green.withOpacity(0.75),
                              blurRadius: 90,
                              spreadRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: 0.78 + (first * 0.22),
                        child: Opacity(
                          opacity: first,
                          child: const SpendGuardAppIcon(size: 132),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: first,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.green, AppColors.teal, AppColors.blue],
                          ).createShader(bounds),
                          child: const Text(
                            'SPENDGUARD',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 46,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                              shadows: [
                                Shadow(color: AppColors.green, blurRadius: 22),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Transform.translate(
                        offset: Offset(0, 16 * (1 - second)),
                        child: Opacity(
                          opacity: second,
                          child: const Text(
                            'YOUR MONEY. YOUR FUTURE.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Transform.translate(
                        offset: Offset(0, 16 * (1 - third)),
                        child: Opacity(
                          opacity: third,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.green.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AppColors.green.withOpacity(0.45)),
                            ),
                            child: const Text(
                              'BEFORE YOU BUY... SEE YOUR FUTURE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.green,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                                shadows: [Shadow(color: AppColors.green, blurRadius: 16)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _finish(BuildContext context) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboardingDone', true);
    if (!context.mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen(openSetup: true)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                const Spacer(),
                const SpendGuardAppIcon(size: 124),
                const SizedBox(height: 18),
                const Text('SPENDGUARD', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 1.4, shadows: [Shadow(color: AppColors.green, blurRadius: 18)])),
                const SizedBox(height: 12),
                Text(tr(context, 'ready'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Text(tr(context, 'about'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.45, fontSize: 16)),
                const Spacer(),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: () => _finish(context), child: const Text('Start'))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool openSetup;
  const MainScreen({super.key, this.openSetup = false});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int index = 0;
  bool loading = true;
  bool gpsReady = false;
  String gpsStatus = 'Location not checked';
  String currentStore = 'No store detected';
  BudgetData budget = BudgetData.empty;
  StoreDecision? decision;
  NotificationPrefs notificationPrefs = NotificationPrefs.defaults;
  StreamSubscription<Position>? locationSub;
  String? lastNotifiedStore;
  String? activeStoreName;
  final friendRequests = <FriendRequest>[const FriendRequest('Anna', 'Pending'), const FriendRequest('Marco', 'Pending')];
  final friends = <String>['Anna', 'Marco'];
  final messages = <ChatMessage>[
    ChatMessage('Anna', 'I protected €20 today 💪', DateTime(2026, 1, 1, 12, 0)),
    ChatMessage('You', 'Nice! I am trying to protect my dream too.', DateTime(2026, 1, 1, 12, 1)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    locationSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await BudgetData.load();
    final prefs = await NotificationPrefs.load();
    if (!mounted) return;
    setState(() {
      budget = data;
      notificationPrefs = prefs;
      loading = false;
    });
    unawaited(checkLocation());
    if (widget.openSetup || !data.isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSetup();
      });
    }
  }

  StoreDecision decisionFor(StoreInfo store) {
    final double safe = budget.isReady ? budget.safeToday : 0.0;
    double adjusted = safe;
    if (store.risk >= 75) {
      adjusted = safe * 0.55;
    } else if (store.risk >= 45) {
      adjusted = safe * 0.80;
    }
    return StoreDecision(
      store: store,
      safeAmount: adjusted,
      delayDays: budget.delayDaysFor(max(1.0, adjusted)),
      stop: adjusted < 3,
    );
  }

  Future<void> updateNotificationPrefs(NotificationPrefs prefs) async {
    await prefs.save();
    if (!mounted) return;
    setState(() => notificationPrefs = prefs);
  }

  Future<void> notifyBeforeBuying() async {
    final d = decision;
    if (d == null || !notificationPrefs.beforeBuying || !notificationPrefs.allows(d.store)) return;
    await NotificationService.show('Before you buy at ${d.store.name}', d.message(budget.dreamName));
  }

  Future<void> notifyAfterBuying() async {
    final d = decision;
    if (d == null || !notificationPrefs.afterBuying || !notificationPrefs.allows(d.store)) return;
    await NotificationService.show('Purchase reflection', 'Check if this purchase still protects ${budget.dreamName.isEmpty ? 'your dream' : budget.dreamName}.');
  }

  Future<void> handlePosition(Position position, {bool force = false}) async {
    final store = await RealStoreService.detectNearestStore(
      position,
      radiusMeters: notificationPrefs.detectionRadiusMeters,
    );
    if (!mounted) return;

    if (store == null) {
      final leavingStore = activeStoreName;
      if (leavingStore != null) {
        activeStoreName = null;
        lastNotifiedStore = null;
        if (notificationPrefs.onExit) {
          await NotificationService.show('Leaving $leavingStore', 'SpendGuard stopped tracking this store. Great job staying aware.');
        }
      }
      setState(() {
        gpsReady = true;
        currentStore = tr(context, 'noStore');
        gpsStatus = 'Precise radar active: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        decision = null;
      });
      return;
    }

    final d = decisionFor(store);
    final isNewStore = activeStoreName != store.name;
    activeStoreName = store.name;

    setState(() {
      gpsReady = true;
      currentStore = store.name;
      gpsStatus = 'Inside ${store.name} • ${store.riskLabel} • ${notificationPrefs.detectionRadiusMeters.toStringAsFixed(0)}m precision';
      decision = d;
    });

    if ((force || isNewStore || lastNotifiedStore != store.name) && notificationPrefs.onEnter && notificationPrefs.allows(store)) {
      lastNotifiedStore = store.name;
      if (d.stop || store.risk >= 75) {
        HapticFeedback.heavyImpact();
        _showStopWarning(d);
      }
      await NotificationService.show('${store.riskLabel}: ${store.name}', d.message(budget.dreamName));
    }
  }

  void _showStopWarning(StoreDecision d) {
    if (!mounted) return;
    final dream = budget.dreamName.isEmpty ? 'your dream' : budget.dreamName;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.82),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.red.withOpacity(0.52),
                AppColors.card,
                AppColors.bgDeep,
              ],
            ),
            border: Border.all(color: AppColors.red.withOpacity(0.95), width: 2.4),
            boxShadow: [
              BoxShadow(color: AppColors.red.withOpacity(0.55), blurRadius: 48, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STOP.',
                style: TextStyle(
                  color: AppColors.red,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: [Shadow(color: AppColors.red, blurRadius: 24)],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                d.store.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                'This purchase may delay $dream by ${d.delayDays} day(s).',
                style: const TextStyle(color: AppColors.text, fontSize: 18, height: 1.35, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.lock_rounded),
                  label: const Text('Protect my money'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> checkLocation() async {
    if (kIsWeb) {
      setState(() {
        gpsReady = false;
        currentStore = tr(context, 'noStore');
        gpsStatus = 'Real GPS store detection works on iPhone and Android only.';
        decision = null;
      });
      return;
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => gpsStatus = 'Turn on location services');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => gpsStatus = 'Location permission denied. Enable Location Always in iPhone Settings.');
      return;
    }
    if (permission == LocationPermission.whileInUse) {
      setState(() => gpsStatus = 'Location works only while app is open. Enable Always for shop alerts.');
    }
    final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation));
    await handlePosition(position, force: true);
    locationSub ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5),
    ).listen((p) => unawaited(handlePosition(p)));
  }

  Future<void> protectMoney(double amount, String reason) async {
    if (amount <= 0) return;
    final updated = budget.copyWith(dreamVault: budget.dreamVault + amount);
    await updated.save();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => budget = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('+€${amount.toStringAsFixed(2)} protected in your Dream Vault'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await NotificationService.show('Money protected', '€${amount.toStringAsFixed(2)} moved to your Dream Vault.');
  }

  void _openSetup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SetupSheet(
        budget: budget,
        onSave: (b) async {
          await b.save();
          if (!mounted) return;
          setState(() => budget = b);
          Navigator.pop(context);
        },
      ),
    );
  }

  void addFriendRequest(String name) {
    if (name.trim().isEmpty) return;
    setState(() => friendRequests.insert(0, FriendRequest(name.trim(), 'Sent')));
  }

  void acceptFriend(int i) {
    final request = friendRequests[i];
    setState(() {
      if (!friends.contains(request.name)) friends.add(request.name);
      friendRequests.removeAt(i);
    });
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() => messages.add(ChatMessage('You', text.trim(), DateTime.now())));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pages = [
      HomeScreen(budget: budget, currentStore: currentStore, gpsStatus: gpsStatus, decision: decision, onGps: checkLocation, onSetup: _openSetup, onProtectMoney: protectMoney, onBeforeBuy: notifyBeforeBuying, onAfterBuy: notifyAfterBuying),
      GpsScreen(budget: budget, currentStore: currentStore, gpsStatus: gpsStatus, gpsReady: gpsReady, decision: decision, onGps: checkLocation),
      const FriendsScreen(),
      GoalsScreen(budget: budget, onSetup: _openSetup),
      SettingsScreen(budget: budget, notificationPrefs: notificationPrefs, onPrefsChanged: updateNotificationPrefs, onSetup: _openSetup),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: index,
        onDestinationSelected: (v) {
          HapticFeedback.selectionClick();
          setState(() => index = v);
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_rounded), label: tr(context, 'home')),
          NavigationDestination(icon: const Icon(Icons.my_location_rounded), label: tr(context, 'gps')),
          NavigationDestination(icon: const Icon(Icons.group_rounded), label: tr(context, 'friends')),
          NavigationDestination(icon: const Icon(Icons.flag_rounded), label: tr(context, 'goals')),
          NavigationDestination(icon: const Icon(Icons.settings_rounded), label: tr(context, 'settings')),
        ],
      ),
    );
  }
}

class SetupSheet extends StatefulWidget {
  final BudgetData budget;
  final Future<void> Function(BudgetData) onSave;
  const SetupSheet({super.key, required this.budget, required this.onSave});

  @override
  State<SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<SetupSheet> {
  late final TextEditingController income;
  late final TextEditingController expenses;
  late final TextEditingController dream;
  late final TextEditingController target;
  late final TextEditingController saved;
  late final TextEditingController months;

  @override
  void initState() {
    super.initState();
    income = TextEditingController(text: widget.budget.income > 0 ? widget.budget.income.toStringAsFixed(0) : '');
    expenses = TextEditingController(text: widget.budget.fixedExpenses > 0 ? widget.budget.fixedExpenses.toStringAsFixed(0) : '');
    dream = TextEditingController(text: widget.budget.dreamName);
    target = TextEditingController(text: widget.budget.dreamTarget > 0 ? widget.budget.dreamTarget.toStringAsFixed(0) : '');
    saved = TextEditingController(text: widget.budget.dreamSaved > 0 ? widget.budget.dreamSaved.toStringAsFixed(0) : '');
    months = TextEditingController(text: widget.budget.dreamMonths > 0 ? widget.budget.dreamMonths.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    income.dispose();
    expenses.dispose();
    dream.dispose();
    target.dispose();
    saved.dispose();
    months.dispose();
    super.dispose();
  }

  double n(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 18, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20))),
            const SizedBox(height: 16),
            Header(title: tr(context, 'budget'), subtitle: 'Only the essentials. No confusion.'),
            const SizedBox(height: 16),
            Money(label: tr(context, 'income'), controller: income, icon: Icons.payments_rounded),
            Money(label: tr(context, 'expenses'), controller: expenses, icon: Icons.receipt_long_rounded),
            TextField(controller: dream, decoration: InputDecoration(prefixIcon: const Icon(Icons.flag_rounded), labelText: tr(context, 'dreamName'))),
            const SizedBox(height: 12),
            Money(label: tr(context, 'target'), controller: target, icon: Icons.flight_takeoff_rounded),
            Money(label: tr(context, 'saved'), controller: saved, icon: Icons.savings_rounded),
            Money(label: tr(context, 'months'), controller: months, icon: Icons.calendar_month_rounded, bottom: false),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => widget.onSave(BudgetData(
                  income: n(income),
                  fixedExpenses: n(expenses),
                  dreamName: dream.text.trim(),
                  dreamTarget: n(target),
                  dreamSaved: n(saved),
                  dreamMonths: n(months),
                  dreamVault: widget.budget.dreamVault,
                )),
                icon: const Icon(Icons.save_rounded),
                label: Text(tr(context, 'save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final BudgetData budget;
  final String currentStore;
  final String gpsStatus;
  final StoreDecision? decision;
  final VoidCallback onGps;
  final VoidCallback onSetup;
  final Future<void> Function(double, String) onProtectMoney;
  final Future<void> Function() onBeforeBuy;
  final Future<void> Function() onAfterBuy;

  const HomeScreen({
    super.key,
    required this.budget,
    required this.currentStore,
    required this.gpsStatus,
    required this.decision,
    required this.onGps,
    required this.onSetup,
    required this.onProtectMoney,
    required this.onBeforeBuy,
    required this.onAfterBuy,
  });

  @override
  Widget build(BuildContext context) {
    final safe = decision?.safeAmount ?? budget.safeToday;
    final dream = budget.dreamName.isEmpty ? 'your dream' : budget.dreamName;
    final delay = budget.delayDaysFor(max(1.0, safe));
    final Color actionColor = decision?.store.color ?? (budget.isReady ? AppColors.green : AppColors.teal);

    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const SpendGuardAppIcon(size: 46),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'SpendGuard',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onGps,
                  icon: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!budget.isReady) SetupPrompt(onTap: onSetup),
            HeroDecisionCard(
              budget: budget,
              safe: safe,
              currentStore: currentStore,
              decision: decision,
            ),
            const SizedBox(height: 14),
            SpendGuardScoreCard(budget: budget, decision: decision),
            const SizedBox(height: 14),
            FutureCostCard(
              dreamName: dream,
              safe: safe,
              delay: delay,
              storeName: currentStore,
              color: actionColor,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await onBeforeBuy();
                      await onAfterBuy();
                    },
                    icon: const Icon(Icons.shopping_bag_rounded),
                    label: Text(tr(context, 'buyNow')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: BorderSide(color: AppColors.red.withOpacity(0.65), width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: safe > 0
                        ? () => onProtectMoney(safe, 'Locked instead of spending at $currentStore')
                        : null,
                    icon: const Icon(Icons.lock_rounded),
                    label: Text(tr(context, 'keepDream')),
                    style: FilledButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: AppColors.bgDeep,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      elevation: 10,
                      shadowColor: actionColor.withOpacity(0.55),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HeroDecisionCard extends StatelessWidget {
  final BudgetData budget;
  final double safe;
  final String currentStore;
  final StoreDecision? decision;

  const HeroDecisionCard({
    super.key,
    required this.budget,
    required this.safe,
    required this.currentStore,
    required this.decision,
  });

  @override
  Widget build(BuildContext context) {
    final status = decision?.store.riskLabel ?? (budget.isReady ? 'READY' : 'SETUP');
    final color = decision?.store.color ?? (budget.isReady ? AppColors.green : AppColors.teal);
    final statusLine = status == 'SAFE'
        ? 'You can safely spend here.'
        : status == 'CAUTION'
            ? 'Think before you buy.'
            : status == 'DANGER'
                ? 'This could hurt your goal.'
                : 'Set your budget to start.';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.48),
            color.withOpacity(0.20),
            AppColors.card,
          ],
        ),
        border: Border.all(color: color.withOpacity(0.95), width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.55),
            blurRadius: 42,
            spreadRadius: 4,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
              shadows: [Shadow(color: color, blurRadius: 20)],
            ),
          ),
          const SizedBox(height: 6),
          Text(statusLine, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            '€${safe.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2),
          ),
          Text(tr(context, 'safeToday'), style: const TextStyle(color: AppColors.muted, fontSize: 16)),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withOpacity(0.10)),
          const SizedBox(height: 10),
          Text(tr(context, 'storeDetected'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 4),
          Text(currentStore, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class SpendGuardScoreCard extends StatelessWidget {
  final BudgetData budget;
  final StoreDecision? decision;

  const SpendGuardScoreCard({super.key, required this.budget, required this.decision});

  int get score {
    if (!budget.isReady) return 0;
    var value = 70;
    if (budget.hasDream) value += 10;
    value += (budget.dreamProgress * 20).round();
    final risk = decision?.store.risk ?? 25;
    if (risk >= 75) value -= 35;
    if (risk >= 45 && risk < 75) value -= 15;
    if ((decision?.safeAmount ?? budget.safeToday) < 3) value -= 20;
    return value.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final s = score;
    final color = s >= 75 ? AppColors.green : s >= 45 ? AppColors.amber : AppColors.red;

    return PremiumCard(
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.14),
              border: Border.all(color: color.withOpacity(0.8), width: 2),
              boxShadow: [BoxShadow(color: color.withOpacity(0.28), blurRadius: 24)],
            ),
            child: Center(
              child: Text(
                '$s',
                style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SpendGuard Score', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  s >= 75
                      ? 'Strong control. Your future is protected.'
                      : s >= 45
                          ? 'Be careful. One bad purchase can slow your goal.'
                          : 'High risk. Protect your money today.',
                  style: const TextStyle(color: AppColors.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FutureCostCard extends StatelessWidget {
  final String dreamName;
  final double safe;
  final int delay;
  final String storeName;
  final Color color;

  const FutureCostCard({
    super.key,
    required this.dreamName,
    required this.safe,
    required this.delay,
    required this.storeName,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, color: color),
              const SizedBox(width: 10),
              Text(tr(context, 'futureImpact'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            storeName,
            style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FutureCostBox(
                  title: 'TODAY',
                  value: '€${safe.toStringAsFixed(2)}',
                  icon: Icons.euro_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FutureCostBox(
                  title: 'OR',
                  value: '$delay day(s)',
                  icon: Icons.flight_takeoff_rounded,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This is the future cost of spending instead of protecting $dreamName.',
            style: const TextStyle(color: AppColors.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _FutureCostBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _FutureCostBox({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class GpsScreen extends StatelessWidget {
  final BudgetData budget;
  final String currentStore;
  final String gpsStatus;
  final bool gpsReady;
  final StoreDecision? decision;
  final VoidCallback onGps;

  const GpsScreen({
    super.key,
    required this.budget,
    required this.currentStore,
    required this.gpsStatus,
    required this.gpsReady,
    required this.decision,
    required this.onGps,
  });

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Header(
              title: tr(context, 'gpsRadar'),
              subtitle: googlePlacesApiKey.isEmpty
                  ? 'Google Places API key missing. Real store detection is off.'
                  : 'Google Places live detection active. Demo stores removed.',
            ),
            const SizedBox(height: 16),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.radar_rounded, color: decision?.store.color ?? AppColors.teal, size: 34),
                      const SizedBox(width: 12),
                      Expanded(child: Text(currentStore, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(gpsStatus, style: const TextStyle(color: AppColors.muted, height: 1.4)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onGps,
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(tr(context, 'checkGps')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final invite = TextEditingController();
  final message = TextEditingController();
  final name = TextEditingController();
  String? selectedFriendUid;
  String? selectedFriendName;

  User? get user => firebaseReady ? FirebaseAuth.instance.currentUser : null;
  String get uid => user?.uid ?? 'offline';
  String get shortId => uid.length <= 8 ? uid : uid.substring(0, 8);

  CollectionReference<Map<String, dynamic>> get usersRef =>
      FirebaseFirestore.instance.collection('spendguard_users');
  CollectionReference<Map<String, dynamic>> get requestsRef =>
      FirebaseFirestore.instance.collection('spendguard_friend_requests');
  CollectionReference<Map<String, dynamic>> get friendshipsRef =>
      FirebaseFirestore.instance.collection('spendguard_friendships');
  CollectionReference<Map<String, dynamic>> get chatsRef =>
      FirebaseFirestore.instance.collection('spendguard_private_chats');

  @override
  void initState() {
    super.initState();
    _ensureProfile();
  }

  @override
  void dispose() {
    invite.dispose();
    message.dispose();
    name.dispose();
    super.dispose();
  }

  String _chatId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _ensureProfile() async {
    if (!firebaseReady || user == null) return;
    final doc = await usersRef.doc(uid).get();
    final existingName = (doc.data()?['displayName'] ?? '').toString();
    if (existingName.isNotEmpty) {
      name.text = existingName;
      return;
    }
    final generated = 'SpendGuard User $shortId';
    name.text = generated;
    await usersRef.doc(uid).set({
      'uid': uid,
      'displayName': generated,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> _displayName() async {
    final doc = await usersRef.doc(uid).get();
    final data = doc.data();
    return (data?['displayName'] ?? name.text.trim().ifEmpty('SpendGuard User $shortId')).toString();
  }

  Future<void> _saveName() async {
    if (user == null) return;
    final clean = name.text.trim().ifEmpty('SpendGuard User $shortId');
    await usersRef.doc(uid).set({
      'uid': uid,
      'displayName': clean,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  Future<void> _sendFriendRequest() async {
    final targetUid = invite.text.trim();
    if (targetUid.isEmpty || user == null) return;
    if (targetUid == uid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You cannot add yourself')));
      return;
    }
    final targetDoc = await usersRef.doc(targetUid).get();
    if (!targetDoc.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ID not found. Ask your friend to open SpendGuard first.')));
      return;
    }
    final senderName = await _displayName();
    final targetName = (targetDoc.data()?['displayName'] ?? 'SpendGuard User').toString();
    final requestId = _chatId(uid, targetUid);
    await requestsRef.doc(requestId).set({
      'fromUid': uid,
      'fromName': senderName,
      'toUid': targetUid,
      'toName': targetName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    invite.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent')));
  }

  Future<void> _acceptRequest(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final fromUid = (data['fromUid'] ?? '').toString();
    final fromName = (data['fromName'] ?? 'Friend').toString();
    final meName = await _displayName();
    if (fromUid.isEmpty || user == null) return;
    final chatId = _chatId(uid, fromUid);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(requestsRef.doc(doc.id), {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(friendshipsRef.doc(chatId), {
        'members': [uid, fromUid],
        'names': {uid: meName, fromUid: fromName},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(chatsRef.doc(chatId), {
        'members': [uid, fromUid],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    setState(() {
      selectedFriendUid = fromUid;
      selectedFriendName = fromName;
    });
  }

  Future<void> _sendMessage() async {
    final text = message.text.trim();
    final friendUid = selectedFriendUid;
    if (text.isEmpty || user == null || friendUid == null) return;
    final chatId = _chatId(uid, friendUid);
    final senderName = await _displayName();
    await chatsRef.doc(chatId).collection('messages').add({
      'text': text,
      'senderId': uid,
      'senderName': senderName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await chatsRef.doc(chatId).set({
      'members': [uid, friendUid],
      'lastMessage': text,
      'lastSenderId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    message.clear();
  }

  Widget _profileCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your beta profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Your private ID: $uid', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_rounded), labelText: 'Your display name'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saveName,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save name'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: uid));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your ID copied')));
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy ID'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inviteCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add a friend', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Ask your friend to copy their SpendGuard ID from this screen, then paste it here.', style: TextStyle(color: AppColors.muted, height: 1.35)),
          const SizedBox(height: 12),
          TextField(
            controller: invite,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.person_add_alt_1_rounded), labelText: 'Friend SpendGuard ID'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sendFriendRequest,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send friend request'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestsCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Incoming requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: requestsRef.where('toUid', isEqualTo: uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator());
              final docs = (snapshot.data?.docs ?? []).where((d) => (d.data()['status'] ?? 'pending') == 'pending').toList();
              if (docs.isEmpty) return const Text('No pending requests', style: TextStyle(color: AppColors.muted));
              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final from = (data['fromName'] ?? 'Someone').toString();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                    title: Text(from),
                    subtitle: Text((data['fromUid'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: FilledButton(onPressed: () => _acceptRequest(doc), child: const Text('Accept')),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _friendsCard() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Friends', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: friendshipsRef.where('members', arrayContains: uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator());
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Text('No friends yet. Add a tester using their SpendGuard ID.', style: TextStyle(color: AppColors.muted));
              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final members = ((data['members'] as List?) ?? []).map((e) => e.toString()).toList();
                  final friendUid = members.firstWhere((id) => id != uid, orElse: () => '');
                  final names = (data['names'] as Map?) ?? {};
                  final friendName = (names[friendUid] ?? 'Friend').toString();
                  final selected = selectedFriendUid == friendUid;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: selected,
                    leading: CircleAvatar(
                      backgroundColor: selected ? AppColors.green.withOpacity(.20) : AppColors.teal.withOpacity(.16),
                      child: const Icon(Icons.shield_rounded),
                    ),
                    title: Text(friendName),
                    subtitle: Text(friendUid, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chat_bubble_rounded),
                    onTap: () => setState(() {
                      selectedFriendUid = friendUid;
                      selectedFriendName = friendName;
                    }),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _chatCard() {
    final friendUid = selectedFriendUid;
    if (friendUid == null) {
      return const PremiumCard(
        child: Text('Select a friend to start a private beta chat.', style: TextStyle(color: AppColors.muted)),
      );
    }
    final chatId = _chatId(uid, friendUid);
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(selectedFriendName ?? 'Private chat', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: chatsRef.doc(chatId).collection('messages').orderBy('createdAt', descending: true).limit(40).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator());
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('No messages yet. Send the first private message.', style: TextStyle(color: AppColors.muted)));
              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final senderId = (data['senderId'] ?? '').toString();
                  final senderName = (data['senderName'] ?? 'User').toString();
                  final text = (data['text'] ?? '').toString();
                  final mine = senderId == uid;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: const BoxConstraints(maxWidth: 290),
                      decoration: BoxDecoration(
                        color: mine ? AppColors.green.withOpacity(.20) : Colors.white.withOpacity(.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: mine ? AppColors.green.withOpacity(.25) : Colors.white.withOpacity(.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mine ? 'You' : senderName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(text),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: message, decoration: InputDecoration(labelText: tr(context, 'message')))),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _sendMessage, icon: const Icon(Icons.send_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady) {
      return AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              Header(title: 'Friends', subtitle: 'Firebase is starting. Please reopen this screen in a moment.'),
            ],
          ),
        ),
      );
    }

    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Header(title: tr(context, 'friends'), subtitle: 'Private beta friends and real-time Firestore chat.'),
            const SizedBox(height: 16),
            _profileCard(),
            const SizedBox(height: 14),
            _inviteCard(),
            const SizedBox(height: 14),
            _requestsCard(),
            const SizedBox(height: 14),
            _friendsCard(),
            const SizedBox(height: 14),
            _chatCard(),
          ],
        ),
      ),
    );
  }
}

extension _SpendGuardStringX on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}


class GoalsScreen extends StatelessWidget {
  final BudgetData budget;
  final VoidCallback onSetup;
  const GoalsScreen({super.key, required this.budget, required this.onSetup});

  @override
  Widget build(BuildContext context) {
    final dream = budget.dreamName.isEmpty ? 'Your dream' : budget.dreamName;
    return AppBackground(
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Header(title: tr(context, 'goals'), subtitle: 'Dream, progress and protected money in one simple place.'),
          const SizedBox(height: 16),
          if (!budget.isReady) SetupPrompt(onTap: onSetup),
          PremiumCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dream, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('${(budget.dreamProgress * 100).toStringAsFixed(0)}% complete • ${budget.daysRemaining} days remaining', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 18),
            ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: budget.dreamProgress, minHeight: 16, backgroundColor: Colors.white12, color: AppColors.teal)),
            const SizedBox(height: 20),
            Wrap(spacing: 10, runSpacing: 10, children: [
              Pill(title: 'Target', value: '€${budget.dreamTarget.toStringAsFixed(0)}', color: AppColors.blue),
              Pill(title: 'Protected', value: '€${budget.dreamTotalProtected.toStringAsFixed(0)}', color: AppColors.teal),
              Pill(title: 'Safe today', value: '€${budget.safeToday.toStringAsFixed(2)}', color: AppColors.purple),
            ]),
          ])),
        ]),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final BudgetData budget;
  final NotificationPrefs notificationPrefs;
  final Future<void> Function(NotificationPrefs) onPrefsChanged;
  final VoidCallback onSetup;

  const SettingsScreen({
    super.key,
    required this.budget,
    required this.notificationPrefs,
    required this.onPrefsChanged,
    required this.onSetup,
  });

  Future<void> _set(NotificationPrefs value) => onPrefsChanged(value);

  @override
  Widget build(BuildContext context) {
    final scope = AppLanguageScope.of(context);
    return AppBackground(
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Header(title: tr(context, 'settings'), subtitle: 'Language, budget, precise GPS and smart alert controls.'),
          const SizedBox(height: 16),
          PremiumCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(context, 'language'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: AppLanguage.values.map((l) {
              final label = switch (l) { AppLanguage.en => 'English', AppLanguage.it => 'Italiano', AppLanguage.es => 'Español', AppLanguage.fr => 'Français' };
              return ChoiceChip(label: Text(label), selected: scope.language == l, onSelected: (_) => scope.onChanged(l));
            }).toList()),
          ])),
          const SizedBox(height: 14),
          PremiumCard(child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune_rounded),
            title: Text(tr(context, 'budget')),
            subtitle: Text('Income €${budget.income.toStringAsFixed(0)} • Expenses €${budget.fixedExpenses.toStringAsFixed(0)}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onSetup,
          )),
          const SizedBox(height: 14),
          PremiumCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.notifications_active_rounded, color: AppColors.teal),
                const SizedBox(width: 10),
                Text(tr(context, 'notifications'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 8),
              const Text('Choose exactly when SpendGuard should alert you.', style: TextStyle(color: AppColors.muted, height: 1.35)),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: notificationPrefs.onEnter,
                onChanged: (v) => _set(notificationPrefs.copyWith(onEnter: v)),
                title: Text(tr(context, 'enterStoreAlert')),
                subtitle: const Text('Alert when you actually enter a detected store.', style: TextStyle(color: AppColors.muted)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: notificationPrefs.onExit,
                onChanged: (v) => _set(notificationPrefs.copyWith(onExit: v)),
                title: Text(tr(context, 'exitStoreAlert')),
                subtitle: const Text('Alert when you leave the store area.', style: TextStyle(color: AppColors.muted)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: notificationPrefs.beforeBuying,
                onChanged: (v) => _set(notificationPrefs.copyWith(beforeBuying: v)),
                title: Text(tr(context, 'beforeBuyAlert')),
                subtitle: const Text('Used when you press “Buy anyway”. Bank detection comes later.', style: TextStyle(color: AppColors.muted)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: notificationPrefs.afterBuying,
                onChanged: (v) => _set(notificationPrefs.copyWith(afterBuying: v)),
                title: Text(tr(context, 'afterBuyAlert')),
                subtitle: const Text('Reflection alert after choosing to buy anyway.', style: TextStyle(color: AppColors.muted)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: notificationPrefs.highRiskOnly,
                onChanged: (v) => _set(notificationPrefs.copyWith(highRiskOnly: v)),
                title: Text(tr(context, 'highRiskOnly')),
                subtitle: const Text('Only notify for caution/danger stores.', style: TextStyle(color: AppColors.muted)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          PremiumCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.gps_fixed_rounded, color: AppColors.green),
                const SizedBox(width: 10),
                Text(tr(context, 'gpsSensitivity'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 8),
              Text(
                'Current detection field: ${notificationPrefs.detectionRadiusMeters.toStringAsFixed(0)} meters. Lower means alerts closer to the shop entrance.',
                style: const TextStyle(color: AppColors.muted, height: 1.35),
              ),
              Slider(
                value: notificationPrefs.detectionRadiusMeters.clamp(10, 50),
                min: 10,
                max: 50,
                divisions: 4,
                label: '${notificationPrefs.detectionRadiusMeters.toStringAsFixed(0)}m',
                onChanged: (v) => _set(notificationPrefs.copyWith(detectionRadiusMeters: v)),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ultra precise', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  Text('Relaxed', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 14),
          PremiumCard(child: Text(tr(context, 'about'), style: const TextStyle(color: AppColors.muted, height: 1.4))),
        ]),
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.bgDeep,
            AppColors.bg,
            Color(0xFF082F3A),
          ],
        ),
      ),
      child: child,
    );
  }
}

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const PremiumCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 18, offset: const Offset(0, 12))],
      ),
      child: child,
    );
  }
}


class SpendGuardAppIcon extends StatelessWidget {
  final double size;
  const SpendGuardAppIcon({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        spendGuardAppIcon,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class Header extends StatelessWidget {
  final String title;
  final String subtitle;
  const Header({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: AppColors.muted, height: 1.35)),
    ]);
  }
}

class SetupPrompt extends StatelessWidget {
  final VoidCallback onTap;
  const SetupPrompt({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PremiumCard(child: Row(children: [
        const CircleAvatar(backgroundColor: AppColors.teal, child: Icon(Icons.tune_rounded, color: AppColors.bgDeep)),
        const SizedBox(width: 12),
        Expanded(child: Text(tr(context, 'ready'), style: const TextStyle(fontWeight: FontWeight.w900))),
        TextButton(onPressed: onTap, child: Text(tr(context, 'setup'))),
      ])),
    );
  }
}

class Money extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool bottom;
  const Money({super.key, required this.label, required this.controller, required this.icon, this.bottom = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom ? 12 : 0),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
        decoration: InputDecoration(prefixText: label.toLowerCase().contains('month') || label.toLowerCase().contains('mesi') || label.toLowerCase().contains('meses') || label.toLowerCase().contains('mois') ? null : '€ ', prefixIcon: Icon(icon), labelText: label),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const Pill({super.key, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
      ]),
    );
  }
}
