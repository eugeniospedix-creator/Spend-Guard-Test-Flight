import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String appLogo = 'assets/images/spendguard_logo.png';
const String appIcon = 'assets/images/spendguard_icon.png';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const SpendGuardApp());
}

class AppColors {
  static const bg = Color(0xFF07111F);
  static const bgDeep = Color(0xFF030712);
  static const card = Color(0xFF0F1B2D);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF9CA3AF);
  static const teal = Color(0xFF2DD4BF);
  static const blue = Color(0xFF38BDF8);
  static const purple = Color(0xFF8B5CF6);
  static const amber = Color(0xFFFBBF24);
  static const red = Color(0xFFFB7185);
  static const green = Color(0xFF22C55E);
}

class SpendGuardApp extends StatelessWidget {
  const SpendGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpendGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.teal,
          brightness: Brightness.dark,
        ),
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
    );
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await plugin.initialize(settings);
  }

  static Future<void> show(String title, String body) async {
    if (kIsWeb) return;
    const android = AndroidNotificationDetails(
      'spendguard_alerts',
      'SpendGuard Alerts',
      channelDescription: 'GPS and DreamGuard spending alerts.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const details = NotificationDetails(android: android);
    await plugin.show(1001, title, body, details);
  }
}

class BudgetData {
  final double income;
  final double fixedExpenses;
  final double monthlySavings;
  final double groceriesLimit;
  final double clothingLimit;
  final double electronicsLimit;
  final String dreamName;
  final double dreamTarget;
  final double dreamSaved;
  final double dreamMonths;
  final double dreamVault;

  const BudgetData({
    required this.income,
    required this.fixedExpenses,
    required this.monthlySavings,
    required this.groceriesLimit,
    required this.clothingLimit,
    required this.electronicsLimit,
    required this.dreamName,
    required this.dreamTarget,
    required this.dreamSaved,
    required this.dreamMonths,
    required this.dreamVault,
  });

  static const empty = BudgetData(
    income: 0,
    fixedExpenses: 0,
    monthlySavings: 0,
    groceriesLimit: 0,
    clothingLimit: 0,
    electronicsLimit: 0,
    dreamName: '',
    dreamTarget: 0,
    dreamSaved: 0,
    dreamMonths: 0,
    dreamVault: 0,
  );

  bool get isReady => income > 0;
  bool get hasDream => dreamTarget > 0 && dreamMonths > 0;
  double get monthlyRoom => max(0, income - fixedExpenses - monthlySavings).toDouble();
  double get safeToday => monthlyRoom / 30;
  double get dreamDays => max(1, dreamMonths * 30).toDouble();
  double get dreamTotalProtected => dreamSaved + dreamVault;
  double get dreamRemaining => max(0, dreamTarget - dreamTotalProtected).toDouble();
  double get dreamDailyNeed => hasDream ? dreamRemaining / dreamDays : 0;
  double get safeTodayAfterDream => max(0, safeToday - dreamDailyNeed).toDouble();
  double get dreamProgress => dreamTarget <= 0 ? 0 : (dreamTotalProtected / dreamTarget).clamp(0, 1).toDouble();
  int get daysRemaining => hasDream ? max(0, (dreamDays * (1 - dreamProgress)).ceil()) : 0;

  double get lifeFreedom {
    if (!isReady) return 0;
    final roomScore = income <= 0 ? 0 : (monthlyRoom / income) * 45;
    final saveScore = income <= 0 ? 0 : (monthlySavings / income) * 30;
    final dreamScore = hasDream ? dreamProgress * 25 : 10;
    return (roomScore + saveScore + dreamScore).clamp(0, 100).toDouble();
  }

  double categoryMonthlyLimit(String category) {
    if (category == 'Groceries') return groceriesLimit;
    if (category == 'Clothing') return clothingLimit;
    if (category == 'Electronics') return electronicsLimit;
    return monthlyRoom;
  }

  int delayDaysFor(double amount) {
    if (amount <= 0 || dreamDailyNeed <= 0) return 0;
    return (amount / dreamDailyNeed).ceil();
  }

  BudgetData copyWith({
    double? income,
    double? fixedExpenses,
    double? monthlySavings,
    double? groceriesLimit,
    double? clothingLimit,
    double? electronicsLimit,
    String? dreamName,
    double? dreamTarget,
    double? dreamSaved,
    double? dreamMonths,
    double? dreamVault,
  }) {
    return BudgetData(
      income: income ?? this.income,
      fixedExpenses: fixedExpenses ?? this.fixedExpenses,
      monthlySavings: monthlySavings ?? this.monthlySavings,
      groceriesLimit: groceriesLimit ?? this.groceriesLimit,
      clothingLimit: clothingLimit ?? this.clothingLimit,
      electronicsLimit: electronicsLimit ?? this.electronicsLimit,
      dreamName: dreamName ?? this.dreamName,
      dreamTarget: dreamTarget ?? this.dreamTarget,
      dreamSaved: dreamSaved ?? this.dreamSaved,
      dreamMonths: dreamMonths ?? this.dreamMonths,
      dreamVault: dreamVault ?? this.dreamVault,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('income', income);
    await p.setDouble('fixedExpenses', fixedExpenses);
    await p.setDouble('monthlySavings', monthlySavings);
    await p.setDouble('groceriesLimit', groceriesLimit);
    await p.setDouble('clothingLimit', clothingLimit);
    await p.setDouble('electronicsLimit', electronicsLimit);
    await p.setString('dreamName', dreamName);
    await p.setDouble('dreamTarget', dreamTarget);
    await p.setDouble('dreamSaved', dreamSaved);
    await p.setDouble('dreamMonths', dreamMonths);
    await p.setDouble('dreamVault', dreamVault);
    await p.setBool('setupDone', true);
  }

  static Future<BudgetData> load() async {
    final p = await SharedPreferences.getInstance();
    final done = p.getBool('setupDone') ?? false;
    if (!done) return BudgetData.empty;
    return BudgetData(
      income: p.getDouble('income') ?? 0,
      fixedExpenses: p.getDouble('fixedExpenses') ?? 0,
      monthlySavings: p.getDouble('monthlySavings') ?? 0,
      groceriesLimit: p.getDouble('groceriesLimit') ?? 0,
      clothingLimit: p.getDouble('clothingLimit') ?? 0,
      electronicsLimit: p.getDouble('electronicsLimit') ?? 0,
      dreamName: p.getString('dreamName') ?? '',
      dreamTarget: p.getDouble('dreamTarget') ?? 0,
      dreamSaved: p.getDouble('dreamSaved') ?? 0,
      dreamMonths: p.getDouble('dreamMonths') ?? 0,
      dreamVault: p.getDouble('dreamVault') ?? 0,
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
  final IconData icon;
  final Color color;
  final String advice;

  const StoreInfo({
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.radius,
    required this.risk,
    required this.icon,
    required this.color,
    required this.advice,
  });

  String get riskLabel {
    if (risk >= 75) return 'DANGER';
    if (risk >= 45) return 'CAUTION';
    return 'SAFE';
  }
}

const trialStores = [
  StoreInfo(
    name: 'Tesco O\'Connell Street',
    category: 'Groceries',
    lat: 53.3498,
    lng: -6.2603,
    radius: 130,
    risk: 25,
    icon: Icons.shopping_basket_rounded,
    color: AppColors.green,
    advice: 'Essentials are safe. Avoid unplanned offers and impulse snacks.',
  ),
  StoreInfo(
    name: 'Zara Henry Street',
    category: 'Clothing',
    lat: 53.3495,
    lng: -6.2637,
    radius: 120,
    risk: 60,
    icon: Icons.checkroom_rounded,
    color: AppColors.amber,
    advice: 'Use the 24-hour rule before buying clothes.',
  ),
  StoreInfo(
    name: 'Currys Jervis',
    category: 'Electronics',
    lat: 53.3477,
    lng: -6.2667,
    radius: 150,
    risk: 85,
    icon: Icons.devices_rounded,
    color: AppColors.red,
    advice: 'Electronics can delay your dream quickly.',
  ),
];

class StoreDecision {
  final StoreInfo store;
  final double safeAmount;
  final int delayDays;
  final bool stop;

  const StoreDecision({
    required this.store,
    required this.safeAmount,
    required this.delayDays,
    required this.stop,
  });

  String get message {
    if (stop || safeAmount <= 0) {
      return 'Stop spending today. Protect your dream and reset tomorrow.';
    }
    final delay = delayDays > 0
        ? ' Overspending here could delay your dream by $delayDays day(s).'
        : '';
    return 'Safe spend here: €${safeAmount.toStringAsFixed(2)}.$delay';
  }
}

class ActivityItem {
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  final bool positive;

  const ActivityItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.positive,
  });
}

class SocialRequest {
  final String person;
  final String purpose;
  final double amount;
  final DateTime date;
  final bool incoming;

  const SocialRequest({
    required this.person,
    required this.purpose,
    required this.amount,
    required this.date,
    required this.incoming,
  });
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final p = await SharedPreferences.getInstance();
    final done = p.getBool('onboardingDone') ?? false;
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => done ? const MainScreen() : const OnboardingScreen(),
      ),
    );
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
            builder: (context, child) {
              final v = controller.value;
              final logoProgress = Curves.easeOutBack.transform((v / 0.62).clamp(0.0, 1.0));
              final textProgress = Curves.easeOut.transform(((v - 0.30) / 0.40).clamp(0.0, 1.0));
              final checkProgress = Curves.easeOut.transform(((v - 0.72) / 0.28).clamp(0.0, 1.0));

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: 0.45 + (logoProgress * 1.08),
                        child: Opacity(
                          opacity: (0.08 + logoProgress).clamp(0.0, 1.0),
                          child: Container(
                            width: 190,
                            height: 190,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.teal.withOpacity(0.26),
                                  AppColors.blue.withOpacity(0.10),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: (1 - logoProgress) * -0.18,
                        child: Transform.scale(
                          scale: 0.55 + (logoProgress * 0.45),
                          child: Opacity(
                            opacity: logoProgress.clamp(0.0, 1.0),
                            child: const AppMark(size: 118),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Transform.translate(
                    offset: Offset(0, 18 * (1 - textProgress)),
                    child: Opacity(
                      opacity: textProgress,
                      child: const Column(
                        children: [
                          Text(
                            'SpendGuard',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'See the future cost before you spend',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Transform.scale(
                    scale: 0.88 + (checkProgress * 0.12),
                    child: Opacity(
                      opacity: checkProgress,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.green.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.green.withOpacity(0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, color: AppColors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Dream Protected',
                              style: TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen(openSetup: true)),
    );
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _finish(context),
                    child: const Text('Skip'),
                  ),
                ),
                const Spacer(),
                const AppMark(size: 128),
                const SizedBox(height: 28),
                const Text(
                  'The GPS-powered Dream Protection App',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'SpendGuard shows how every purchase affects your dream, your daily freedom and your future self.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    height: 1.45,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _finish(context),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Start trial setup'),
                  ),
                ),
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
  BudgetData budget = BudgetData.empty;
  bool loading = true;
  bool gpsReady = false;
  String currentStore = 'No store detected';
  String gpsStatus = 'Location not checked';
  StoreDecision? lastDecision;
  StreamSubscription<Position>? locationSub;
  String? lastNotifiedStore;
  final List<ActivityItem> activity = [];
  final List<SocialRequest> socialRequests = [];

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
    if (!mounted) return;
    setState(() {
      budget = data;
      loading = false;
    });
    unawaited(checkLocation());
    if (widget.openSetup || !data.isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openQuickSetup();
      });
    }
  }

  Future<void> saveBudget(BudgetData data) async {
    await data.save();
    if (!mounted) return;
    setState(() => budget = data);
  }

  Future<void> protectMoney(double amount, String reason) async {
    if (amount <= 0) return;
    final updated = budget.copyWith(dreamVault: budget.dreamVault + amount);
    await updated.save();
    if (!mounted) return;
    setState(() {
      budget = updated;
      activity.insert(
        0,
        ActivityItem(
          title: 'Dream Vault protected',
          subtitle: reason,
          amount: amount,
          date: DateTime.now(),
          positive: true,
        ),
      );
    });
  }

  Future<void> createSocialRequest({
    required String person,
    required String purpose,
    required double amount,
    required bool incoming,
  }) async {
    if (amount <= 0 || person.trim().isEmpty) return;
    if (!mounted) return;
    setState(() {
      socialRequests.insert(
        0,
        SocialRequest(
          person: person.trim(),
          purpose: purpose.trim().isEmpty ? 'Shared purchase' : purpose.trim(),
          amount: amount,
          date: DateTime.now(),
          incoming: incoming,
        ),
      );
      activity.insert(
        0,
        ActivityItem(
          title: incoming ? 'Money request received' : 'Money request created',
          subtitle: '${incoming ? person.trim() : 'You'} requested €${amount.toStringAsFixed(2)} for ${purpose.trim().isEmpty ? 'a shared purchase' : purpose.trim()}',
          amount: amount,
          date: DateTime.now(),
          positive: false,
        ),
      );
    });
  }

  StoreDecision decisionFor(StoreInfo store) {
    if (!budget.isReady) {
      return StoreDecision(store: store, safeAmount: 0, delayDays: 0, stop: true);
    }
    final categoryDaily = budget.categoryMonthlyLimit(store.category) > 0
        ? budget.categoryMonthlyLimit(store.category) / 30
        : budget.safeToday;
    final dreamSafe = budget.hasDream ? budget.safeTodayAfterDream : budget.safeToday;
    final baseSafe = min(categoryDaily, dreamSafe).toDouble();
    final riskAdjusted = store.risk >= 75
        ? baseSafe * 0.55
        : store.risk >= 45
            ? baseSafe * 0.8
            : baseSafe;
    final delay = budget.delayDaysFor(max(0, riskAdjusted));
    final stop = riskAdjusted < 3 || budget.lifeFreedom < 25;
    return StoreDecision(
      store: store,
      safeAmount: riskAdjusted,
      delayDays: delay,
      stop: stop,
    );
  }

  StoreInfo? nearestStore(Position p) {
    StoreInfo? best;
    double bestDistance = double.infinity;
    for (final s in trialStores) {
      final d = Geolocator.distanceBetween(p.latitude, p.longitude, s.lat, s.lng);
      if (d < bestDistance) {
        bestDistance = d;
        best = s;
      }
    }
    if (best != null && bestDistance <= best.radius) return best;
    return null;
  }

  Future<void> handlePosition(Position position, {bool force = false}) async {
    final store = nearestStore(position);
    if (!mounted) return;

    if (store == null) {
      setState(() {
        gpsReady = true;
        currentStore = 'No store detected';
        gpsStatus =
            'Radar active: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
      return;
    }

    final decision = decisionFor(store);
    setState(() {
      gpsReady = true;
      currentStore = store.name;
      gpsStatus = 'Inside ${store.name} area • ${store.riskLabel}';
      lastDecision = decision;
      activity.insert(
        0,
        ActivityItem(
          title: store.name,
          subtitle: decision.message,
          amount: decision.safeAmount,
          date: DateTime.now(),
          positive: !decision.stop,
        ),
      );
      if (activity.length > 20) activity.removeLast();
    });

    if (force || lastNotifiedStore != store.name) {
      lastNotifiedStore = store.name;
      await NotificationService.show('SpendGuard detected ${store.name}', decision.message);
    }
  }

  Future<void> checkLocation() async {
    if (kIsWeb) {
      final store = trialStores.first;
      final d = decisionFor(store);
      if (!mounted) return;
      setState(() {
        gpsReady = true;
        currentStore = store.name;
        gpsStatus = 'Web demo mode. GPS works on Android/iPhone builds.';
        lastDecision = d;
      });
      return;
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (!mounted) return;
      setState(() => gpsStatus = 'Turn on location services');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() => gpsStatus = 'Location permission denied');
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    await handlePosition(position, force: true);

    locationSub ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 35,
      ),
    ).listen((p) => unawaited(handlePosition(p)));
  }

  void _openQuickSetup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => QuickSetupSheet(
        budget: budget,
        onSave: (b) async {
          await saveBudget(b);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final pages = [
      HomeScreen(
        budget: budget,
        currentStore: currentStore,
        gpsStatus: gpsStatus,
        gpsReady: gpsReady,
        decision: lastDecision,
        activity: activity,
        onGps: checkLocation,
        onSetup: _openQuickSetup,
        onProtectMoney: protectMoney,
      ),
      DreamScreen(budget: budget, onSetup: _openQuickSetup),
      RadarScreen(
        budget: budget,
        onTest: (s) async {
          final d = decisionFor(s);
          setState(() {
            currentStore = s.name;
            gpsStatus = 'Manual trial test • ${s.riskLabel}';
            lastDecision = d;
            activity.insert(
              0,
              ActivityItem(
                title: s.name,
                subtitle: d.message,
                amount: d.safeAmount,
                date: DateTime.now(),
                positive: !d.stop,
              ),
            );
          });
          await NotificationService.show('SpendGuard detected ${s.name}', d.message);
        },
      ),
      GuardScreen(
        budget: budget,
        activity: activity,
        onProtect: protectMoney,
        onSetup: _openQuickSetup,
      ),
      SocialScreen(
        budget: budget,
        requests: socialRequests,
        onCreateRequest: createSocialRequest,
        onProtect: protectMoney,
      ),
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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.flight_takeoff_rounded), label: 'Dream'),
          NavigationDestination(icon: Icon(Icons.storefront_rounded), label: 'Radar'),
          NavigationDestination(icon: Icon(Icons.psychology_alt_rounded), label: 'Guard'),
          NavigationDestination(icon: Icon(Icons.group_rounded), label: 'Circle'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openQuickSetup,
        icon: const Icon(Icons.tune_rounded),
        label: const Text('Setup'),
      ),
    );
  }
}

class QuickSetupSheet extends StatefulWidget {
  final BudgetData budget;
  final Future<void> Function(BudgetData) onSave;

  const QuickSetupSheet({super.key, required this.budget, required this.onSave});

  @override
  State<QuickSetupSheet> createState() => _QuickSetupSheetState();
}

class _QuickSetupSheetState extends State<QuickSetupSheet> {
  late final TextEditingController income;
  late final TextEditingController fixed;
  late final TextEditingController savings;
  late final TextEditingController groceries;
  late final TextEditingController clothing;
  late final TextEditingController electronics;
  late final TextEditingController dream;
  late final TextEditingController target;
  late final TextEditingController saved;
  late final TextEditingController months;

  @override
  void initState() {
    super.initState();
    income = TextEditingController(text: widget.budget.income > 0 ? widget.budget.income.toStringAsFixed(0) : '');
    fixed = TextEditingController(text: widget.budget.fixedExpenses > 0 ? widget.budget.fixedExpenses.toStringAsFixed(0) : '');
    savings = TextEditingController(text: widget.budget.monthlySavings > 0 ? widget.budget.monthlySavings.toStringAsFixed(0) : '');
    groceries = TextEditingController(text: widget.budget.groceriesLimit > 0 ? widget.budget.groceriesLimit.toStringAsFixed(0) : '');
    clothing = TextEditingController(text: widget.budget.clothingLimit > 0 ? widget.budget.clothingLimit.toStringAsFixed(0) : '');
    electronics = TextEditingController(text: widget.budget.electronicsLimit > 0 ? widget.budget.electronicsLimit.toStringAsFixed(0) : '');
    dream = TextEditingController(text: widget.budget.dreamName);
    target = TextEditingController(text: widget.budget.dreamTarget > 0 ? widget.budget.dreamTarget.toStringAsFixed(0) : '');
    saved = TextEditingController(text: widget.budget.dreamSaved > 0 ? widget.budget.dreamSaved.toStringAsFixed(0) : '');
    months = TextEditingController(text: widget.budget.dreamMonths > 0 ? widget.budget.dreamMonths.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    for (final c in [income, fixed, savings, groceries, clothing, electronics, dream, target, saved, months]) {
      c.dispose();
    }
    super.dispose();
  }

  double n(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20))),
            const SizedBox(height: 16),
            const Header(
              title: 'Smart setup',
              subtitle: 'Add only the essentials. SpendGuard creates smart limits automatically.',
            ),
            const SizedBox(height: 16),
            const SmartSetupInfoCard(),
            const SizedBox(height: 14),
            Money(label: 'Monthly income', controller: income, icon: Icons.payments_rounded),
            Money(label: 'Fixed expenses', controller: fixed, icon: Icons.receipt_long_rounded),
            TextField(
              controller: dream,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.flag_rounded),
                labelText: 'Dream name e.g. Japan, Ibiza, New Car',
              ),
            ),
            const SizedBox(height: 14),
            Money(label: 'Dream target', controller: target, icon: Icons.flight_takeoff_rounded),
            Money(label: 'Already saved', controller: saved, icon: Icons.account_balance_wallet_rounded),
            Money(label: 'Months to goal', controller: months, icon: Icons.calendar_month_rounded, bottom: false),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final incomeValue = n(income);
                  final fixedValue = n(fixed);
                  final monthlyRoom = max(0, incomeValue - fixedValue).toDouble();

                  final smartSavings = monthlyRoom * 0.20;
                  final smartGroceries = monthlyRoom * 0.35;
                  final smartClothing = monthlyRoom * 0.12;
                  final smartElectronics = monthlyRoom * 0.08;

                  final b = widget.budget.copyWith(
                    income: incomeValue,
                    fixedExpenses: fixedValue,
                    monthlySavings: smartSavings,
                    groceriesLimit: smartGroceries,
                    clothingLimit: smartClothing,
                    electronicsLimit: smartElectronics,
                    dreamName: dream.text.trim(),
                    dreamTarget: n(target),
                    dreamSaved: n(saved),
                    dreamMonths: n(months),
                  );
                  await widget.onSave(b);
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Activate SpendGuard'),
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
  final bool gpsReady;
  final StoreDecision? decision;
  final List<ActivityItem> activity;
  final VoidCallback onGps;
  final VoidCallback onSetup;
  final Future<void> Function(double, String) onProtectMoney;

  const HomeScreen({
    super.key,
    required this.budget,
    required this.currentStore,
    required this.gpsStatus,
    required this.gpsReady,
    required this.decision,
    required this.activity,
    required this.onGps,
    required this.onSetup,
    required this.onProtectMoney,
  });

  @override
  Widget build(BuildContext context) {
    final safe = budget.hasDream ? budget.safeTodayAfterDream : budget.safeToday;
    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const AppMark(size: 58),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SpendGuard',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      Text(
                        'See the future cost before you spend',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onGps,
                  icon: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!budget.isReady) SetupPrompt(onTap: onSetup) else FreedomCard(budget: budget),
            if (budget.isReady) ...[
              const SizedBox(height: 14),
              DreamProgressHomeCard(budget: budget),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Safe today',
                    value: budget.isReady ? '€${safe.toStringAsFixed(2)}' : '—',
                    icon: Icons.today_rounded,
                    color: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: 'Dream Vault',
                    value: budget.isReady ? '€${budget.dreamVault.toStringAsFixed(0)}' : '—',
                    icon: Icons.lock_rounded,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            StoreCard(
              currentStore: currentStore,
              gpsStatus: gpsStatus,
              gpsReady: gpsReady,
              decision: decision,
            ),
            const SizedBox(height: 14),
            SpendGuardMomentCard(
              budget: budget,
              decision: decision,
              onProtectMoney: onProtectMoney,
            ),
            const SizedBox(height: 14),
            FutureSelfCard(
              message: budget.hasDream
                  ? 'Future you says: ${budget.dreamName} is ${(budget.dreamProgress * 100).toStringAsFixed(0)}% protected. Keep today under control.'
                  : 'Future you says: set one dream and let SpendGuard protect it.',
            ),
            const SizedBox(height: 14),
            ProtectionStreakCard(activity: activity),
          ],
        ),
      ),
    );
  }
}

class DreamScreen extends StatelessWidget {
  final BudgetData budget;
  final VoidCallback onSetup;

  const DreamScreen({super.key, required this.budget, required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Header(
              title: 'DreamGuard',
              subtitle: 'Your spending becomes time gained or delayed.',
            ),
            const SizedBox(height: 16),
            if (!budget.isReady)
              SetupPrompt(onTap: onSetup)
            else
              PremiumCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.dreamName.isEmpty ? 'Your Dream' : budget.dreamName,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(budget.dreamProgress * 100).toStringAsFixed(0)}% complete • ${budget.daysRemaining} days remaining',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: budget.dreamProgress,
                        minHeight: 16,
                        backgroundColor: Colors.white12,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Pill(title: 'Target', value: '€${budget.dreamTarget.toStringAsFixed(0)}', color: AppColors.blue),
                        Pill(title: 'Saved + Vault', value: '€${budget.dreamTotalProtected.toStringAsFixed(0)}', color: AppColors.teal),
                        Pill(title: 'Needed/day', value: '€${budget.dreamDailyNeed.toStringAsFixed(2)}', color: AppColors.purple),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            DreamTimelineCard(budget: budget),
            const SizedBox(height: 14),
            ProtectionBadgesCard(budget: budget),
            const SizedBox(height: 14),
            DreamPulseCard(budget: budget),
          ],
        ),
      ),
    );
  }
}

class RadarScreen extends StatelessWidget {
  final BudgetData budget;
  final Future<void> Function(StoreInfo) onTest;

  const RadarScreen({super.key, required this.budget, required this.onTest});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Header(
              title: 'GPS Radar',
              subtitle: 'Store risk made simple: SAFE, CAUTION, DANGER.',
            ),
            const SizedBox(height: 16),
            ...trialStores.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PremiumCard(
                  child: Row(
                    children: [
                      IconBadge(icon: s.icon, color: s.color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            Text('${s.category} • ${s.riskLabel}', style: TextStyle(color: s.color, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text(s.advice, style: const TextStyle(color: AppColors.muted, height: 1.3)),
                          ],
                        ),
                      ),
                      TextButton(onPressed: () => onTest(s), child: const Text('Test')),
                    ],
                  ),
                ),
              ),
            ),
            const PremiumCard(
              child: Text(
                'Trial version: fixed Dublin geofences. Production upgrade: connect Google Places, Apple Maps, or your own store database.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GuardScreen extends StatefulWidget {
  final BudgetData budget;
  final List<ActivityItem> activity;
  final Future<void> Function(double, String) onProtect;
  final VoidCallback onSetup;

  const GuardScreen({
    super.key,
    required this.budget,
    required this.activity,
    required this.onProtect,
    required this.onSetup,
  });

  @override
  State<GuardScreen> createState() => _GuardScreenState();
}

class _GuardScreenState extends State<GuardScreen> {
  final amount = TextEditingController();
  String mood = 'Impulse';

  double get value => double.tryParse(amount.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  String decision() {
    if (!widget.budget.isReady) return 'Set your budget first.';
    if (value <= 0) return 'Type the amount you are about to spend.';
    final safe = widget.budget.hasDream
        ? widget.budget.safeTodayAfterDream
        : widget.budget.safeToday;
    if (value <= safe) return 'Approved with control. You remain inside today’s safe spend.';
    final over = value - safe;
    final d = widget.budget.delayDaysFor(over);
    return 'Not recommended. €${over.toStringAsFixed(2)} over today’s safe spend may delay your dream by about $d day(s).';
  }

  int get protectedDays {
    if (widget.activity.isEmpty) return 0;
    return widget.activity.where((a) => a.positive).length;
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Header(
              title: 'Future Self Guard',
              subtitle: 'Panic Spend, Emotional Mode, DNA and Streaks in one place.',
            ),
            const SizedBox(height: 16),
            if (!widget.budget.isReady) SetupPrompt(onTap: widget.onSetup),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Panic Spend Button', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                    decoration: const InputDecoration(
                      prefixText: '€ ',
                      prefixIcon: Icon(Icons.flash_on_rounded),
                      labelText: 'I am about to spend',
                    ),
                  ),
                  const SizedBox(height: 12),
                  AlertCard(message: decision()),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: value > 0
                        ? () async {
                            await widget.onProtect(value, 'Skipped because mood was $mood. Future Self approved.');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('€${value.toStringAsFixed(2)} protected in Dream Vault')),
                              );
                            }
                          }
                        : null,
                    icon: const Icon(Icons.lock_rounded),
                    label: const Text('I skipped it: protect this money'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TimeCurrencyCard(budget: widget.budget, amount: max(1, value)),
            const SizedBox(height: 14),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Emotional Spending Mode', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Impulse', 'Stress', 'Boredom', 'Reward', 'Planned']
                        .map((m) => ChoiceChip(
                              label: Text(m),
                              selected: mood == m,
                              onSelected: (_) => setState(() => mood = m),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mood == 'Planned'
                        ? 'Planned purchase: compare price, then decide.'
                        : 'Pause 10 minutes. Most impulse purchases lose power when you create distance.',
                    style: const TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SpendGuard DNA™', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  DnaRow(
                    icon: Icons.local_fire_department_rounded,
                    text: '$protectedDays protected decision(s) tracked.',
                  ),
                  const SizedBox(height: 10),
                  const DnaRow(
                    icon: Icons.storefront_rounded,
                    text: 'Highest trial risk: electronics and clothing stores.',
                  ),
                  const SizedBox(height: 10),
                  DnaRow(
                    icon: Icons.flag_rounded,
                    text: widget.budget.hasDream
                        ? 'DreamGuard active for ${widget.budget.dreamName}.'
                        : 'Add a dream to activate pattern intelligence.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}





class DreamTimelineCard extends StatelessWidget {
  final BudgetData budget;

  const DreamTimelineCard({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    final progress = budget.dreamProgress.clamp(0, 1).toDouble();
    final dream = budget.dreamName.isEmpty ? 'Your dream' : budget.dreamName;

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dream Timeline™', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            budget.hasDream
                ? 'Today to $dream: ${budget.daysRemaining} days remaining.'
                : 'Add a dream to see your timeline.',
            style: const TextStyle(color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text('Today', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment(-1 + (progress * 2), 0),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.teal,
                            border: Border.all(color: AppColors.text, width: 2),
                            boxShadow: [BoxShadow(color: AppColors.teal.withOpacity(0.35), blurRadius: 14)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(dream, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class ProtectionBadgesCard extends StatelessWidget {
  final BudgetData budget;

  const ProtectionBadgesCard({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    final protected = budget.dreamVault;
    final badges = [
      ('First Protection', protected > 0, Icons.lock_rounded),
      ('€100 Protected', protected >= 100, Icons.savings_rounded),
      ('€500 Protected', protected >= 500, Icons.workspace_premium_rounded),
      ('Dream Master', budget.dreamProgress >= 1, Icons.emoji_events_rounded),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Protection Badges™', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
            'Unlock badges when you protect money instead of spending impulsively.',
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: badges.map((b) {
              final unlocked = b.$2;
              return Container(
                width: 145,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (unlocked ? AppColors.teal : AppColors.muted).withOpacity(unlocked ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: (unlocked ? AppColors.teal : AppColors.muted).withOpacity(0.22)),
                ),
                child: Column(
                  children: [
                    Icon(b.$3, color: unlocked ? AppColors.teal : AppColors.muted),
                    const SizedBox(height: 8),
                    Text(
                      b.$1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: unlocked ? AppColors.text : AppColors.muted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class ProtectionStreakCard extends StatelessWidget {
  final List<ActivityItem> activity;

  const ProtectionStreakCard({super.key, required this.activity});

  int get protectedCount => activity.where((a) => a.positive).length;

  @override
  Widget build(BuildContext context) {
    final count = protectedCount;
    final title = count == 0 ? 'Start your protection streak' : '$count Protected Decision${count == 1 ? '' : 's'}';
    final subtitle = count == 0
        ? 'Skip one impulse purchase to start building your Dream Vault.'
        : 'Every protected decision keeps your future closer.';

    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: Icons.local_fire_department_rounded, color: AppColors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: AppColors.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class SpendGuardMomentCard extends StatelessWidget {
  final BudgetData budget;
  final StoreDecision? decision;
  final Future<void> Function(double, String) onProtectMoney;

  const SpendGuardMomentCard({
    super.key,
    required this.budget,
    required this.decision,
    required this.onProtectMoney,
  });

  @override
  Widget build(BuildContext context) {
    final safe = decision?.safeAmount ?? (budget.hasDream ? budget.safeTodayAfterDream : budget.safeToday);
    final storeName = decision?.store.name ?? 'Current purchase';
    final delay = budget.delayDaysFor(max(1, safe));
    final hasBudget = budget.isReady;

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.bolt_rounded, color: AppColors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SpendGuard Moment™', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      hasBudget
                          ? '$storeName • choose what happens before you spend'
                          : 'Set your budget to unlock spend decisions',
                      style: const TextStyle(color: AppColors.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MomentChoice(
                  title: 'Spend',
                  value: hasBudget ? '+$delay days' : '—',
                  subtitle: 'Dream waits',
                  icon: Icons.shopping_bag_rounded,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MomentChoice(
                  title: 'Protect',
                  value: hasBudget ? '-$delay days' : '—',
                  subtitle: 'Dream closer',
                  icon: Icons.lock_rounded,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MomentChoice(
                  title: 'Delay',
                  value: '24h',
                  subtitle: 'Think first',
                  icon: Icons.schedule_rounded,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: hasBudget && safe > 0
                  ? () => onProtectMoney(
                        safe,
                        'SpendGuard Moment: protected instead of spending at $storeName.',
                      )
                  : null,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(hasBudget ? 'Protect €${safe.toStringAsFixed(2)} now' : 'Set up SpendGuard first'),
            ),
          ),
        ],
      ),
    );
  }
}

class MomentChoice extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const MomentChoice({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900))),
          const SizedBox(height: 2),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class TimeCurrencyCard extends StatelessWidget {
  final BudgetData budget;
  final double amount;

  const TimeCurrencyCard({super.key, required this.budget, required this.amount});

  @override
  Widget build(BuildContext context) {
    final days = budget.delayDaysFor(amount);
    final label = days <= 0 ? 'No dream impact yet' : '$days Dream Day${days == 1 ? '' : 's'}';
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: Icons.hourglass_bottom_rounded, color: AppColors.purple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Time Currency™', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  '€${amount.toStringAsFixed(2)} equals $label. SpendGuard makes money feel like time.',
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class BetaFeatureCard extends StatelessWidget {
  const BetaFeatureCard({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: Icons.workspace_premium_rounded, color: AppColors.purple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Beta concept', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text(
                  'This tests the social money experience without moving real money yet. Perfect for App Store beta feedback.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class SocialScreen extends StatefulWidget {
  final BudgetData budget;
  final List<SocialRequest> requests;
  final Future<void> Function({
    required String person,
    required String purpose,
    required double amount,
    required bool incoming,
  }) onCreateRequest;
  final Future<void> Function(double, String) onProtect;

  const SocialScreen({
    super.key,
    required this.budget,
    required this.requests,
    required this.onCreateRequest,
    required this.onProtect,
  });

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final person = TextEditingController();
  final purpose = TextEditingController();
  final amount = TextEditingController();

  double get value => double.tryParse(amount.text.trim().replaceAll(',', '.')) ?? 0;

  @override
  void dispose() {
    person.dispose();
    purpose.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friends = [
      {'name': 'You', 'progress': (widget.budget.dreamProgress * 100).clamp(0, 100).toInt()},
      {'name': 'Anna', 'progress': 61},
      {'name': 'Marco', 'progress': 55},
      {'name': 'Sara', 'progress': 43},
    ];

    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Header(
              title: 'Dream Circle™',
              subtitle: 'Save with friends, request money, split goals and turn dreams into a race.',
            ),
            const SizedBox(height: 16),
            const BetaFeatureCard(),
            const SizedBox(height: 14),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dream Race™', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  ...friends.map((f) {
                    final progress = (f['progress'] as int) / 100;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(f['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800))),
                              Text('${f['progress']}%', style: const TextStyle(color: AppColors.muted)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: Colors.white12,
                              color: AppColors.teal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Request or split money (trial)', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text(
                    'Trial mode: create requests and split purchases inside SpendGuard. Real transfers can be added later with a regulated payment partner.',
                    style: TextStyle(color: AppColors.muted, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: person,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_rounded),
                      labelText: 'Friend name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: purpose,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.shopping_bag_rounded),
                      labelText: 'Purpose e.g. hotel, dinner, shared gift',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Money(label: 'Amount', controller: amount, icon: Icons.euro_rounded, bottom: false),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: value > 0
                              ? () => widget.onCreateRequest(
                                    person: person.text,
                                    purpose: purpose.text,
                                    amount: value,
                                    incoming: false,
                                  )
                              : null,
                          icon: const Icon(Icons.call_received_rounded),
                          label: const Text('Request'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: value > 0
                              ? () => widget.onProtect(
                                    value,
                                    'Social split protected for ${purpose.text.trim().isEmpty ? 'shared goal' : purpose.text.trim()}.',
                                  )
                              : null,
                          icon: const Icon(Icons.lock_rounded),
                          label: const Text('Protect'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (widget.requests.isEmpty)
              const PremiumCard(
                child: Text(
                  'No requests yet. Create your first shared request to test Dream Circle.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
              )
            else
              ...widget.requests.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PremiumCard(
                    child: Row(
                      children: [
                        IconBadge(
                          icon: r.incoming ? Icons.call_made_rounded : Icons.call_received_rounded,
                          color: r.incoming ? AppColors.amber : AppColors.teal,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.person, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(r.purpose, style: const TextStyle(color: AppColors.muted)),
                            ],
                          ),
                        ),
                        Text('€${r.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class DreamProgressHomeCard extends StatelessWidget {
  final BudgetData budget;

  const DreamProgressHomeCard({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    final title = budget.dreamName.isEmpty ? 'Your dream' : budget.dreamName;
    final progress = budget.dreamProgress.clamp(0, 1).toDouble();

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.flight_takeoff_rounded, color: AppColors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      budget.hasDream
                          ? '${(progress * 100).toStringAsFixed(0)}% protected • ${budget.daysRemaining} days remaining'
                          : 'Add a dream goal to unlock your timeline',
                      style: const TextStyle(color: AppColors.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 15,
              backgroundColor: Colors.white.withOpacity(0.08),
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MiniStat(
                  title: 'Protected',
                  value: budget.hasDream ? '€${budget.dreamTotalProtected.toStringAsFixed(0)}' : '—',
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MiniStat(
                  title: 'Target',
                  value: budget.hasDream ? '€${budget.dreamTarget.toStringAsFixed(0)}' : '—',
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MiniStat(
                  title: 'Need/day',
                  value: budget.hasDream ? '€${budget.dreamDailyNeed.toStringAsFixed(2)}' : '—',
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MiniStat extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const MiniStat({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}



class SmartSetupInfoCard extends StatelessWidget {
  const SmartSetupInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.teal.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.teal.withOpacity(0.22)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppColors.teal),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No complicated setup. Add income, fixed expenses and one dream. SpendGuard automatically builds your daily safe spend, category limits and DreamGuard plan.',
              style: TextStyle(color: AppColors.text, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class FreedomCard extends StatelessWidget {
  final BudgetData budget;

  const FreedomCard({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(colors: [AppColors.teal, AppColors.blue]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DREAM HEALTH', style: TextStyle(color: Color(0xFF06323A), fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Text('${budget.lifeFreedom.toStringAsFixed(0)}%', style: const TextStyle(color: Color(0xFF031014), fontSize: 52, fontWeight: FontWeight.w900)),
          Text(
            budget.hasDream
                ? '${budget.dreamName} is ${(budget.dreamProgress * 100).toStringAsFixed(0)}% protected'
                : 'Set a dream to activate DreamGuard',
            style: const TextStyle(color: Color(0xFF083344), fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: budget.lifeFreedom / 100,
              minHeight: 10,
              backgroundColor: Colors.black26,
              color: const Color(0xFF031014),
            ),
          ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const Pill({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 5),
          FittedBox(child: Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class StoreCard extends StatelessWidget {
  final String currentStore;
  final String gpsStatus;
  final bool gpsReady;
  final StoreDecision? decision;

  const StoreCard({
    super.key,
    required this.currentStore,
    required this.gpsStatus,
    required this.gpsReady,
    this.decision,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: gpsReady ? Icons.radar_rounded : Icons.location_off_rounded,
            color: gpsReady ? AppColors.teal : AppColors.amber,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentStore, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(gpsStatus, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                if (decision != null) ...[
                  const SizedBox(height: 8),
                  Text(decision!.message, style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800, height: 1.35)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FutureSelfCard extends StatelessWidget {
  final String message;

  const FutureSelfCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: Icons.self_improvement_rounded, color: AppColors.purple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Future Self AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(message, style: const TextStyle(color: AppColors.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityList extends StatelessWidget {
  final List<ActivityItem> activity;

  const ActivityList({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Protection Activity', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (activity.isEmpty)
            const Text('No alerts yet. GPS radar and skipped purchases will appear here.', style: TextStyle(color: AppColors.muted))
          else
            ...activity.take(5).map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          a.positive ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: a.positive ? AppColors.teal : AppColors.amber,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(a.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(a.amount > 0 ? '€${a.amount.toStringAsFixed(0)}' : '—', style: const TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class DreamPulseCard extends StatelessWidget {
  final BudgetData budget;

  const DreamPulseCard({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    final message = budget.hasDream
        ? 'DreamGuard Pulse: protect €${budget.dreamDailyNeed.toStringAsFixed(2)} today to keep ${budget.dreamName} on time.'
        : 'Add a dream goal to activate DreamGuard Pulse.';
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: Icons.monitor_heart_rounded, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.muted, height: 1.4))),
        ],
      ),
    );
  }
}

class DnaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const DnaRow({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.teal),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.muted, height: 1.35))),
      ],
    );
  }
}

class Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const Header({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: AppColors.muted, height: 1.35)),
      ],
    );
  }
}

class SetupPrompt extends StatelessWidget {
  final VoidCallback onTap;

  const SetupPrompt({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_open_rounded, color: AppColors.teal, size: 34),
          const SizedBox(height: 12),
          const Text('Set up SpendGuard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
            'Add your budget and one dream goal to activate GPS, DreamGuard and Future Self decisions.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Start setup'),
            ),
          ),
        ],
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  final String message;

  const AlertCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.amber.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }
}

class Money extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool bottom;

  const Money({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.bottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom ? 14 : 0),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
        decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label, prefixText: '€ '),
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const IconBadge({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.13),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class AppMark extends StatelessWidget {
  final double size;

  const AppMark({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      appIcon,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.24),
          gradient: const LinearGradient(colors: [AppColors.teal, AppColors.blue]),
          boxShadow: [
            BoxShadow(
              color: AppColors.teal.withOpacity(0.24),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(Icons.shield_rounded, color: const Color(0xFF031014), size: size * 0.54),
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bgDeep, AppColors.bg, Color(0xFF0B2A35)],
        ),
      ),
      child: Stack(
        children: [
          const AmbientOrbs(),
          child,
        ],
      ),
    );
  }
}

class AmbientOrbs extends StatefulWidget {
  const AmbientOrbs({super.key});

  @override
  State<AmbientOrbs> createState() => _AmbientOrbsState();
}

class _AmbientOrbsState extends State<AmbientOrbs> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final v = controller.value;
          return Stack(
            children: [
              Positioned(top: 70 + v * 18, left: -45, child: Orb(size: 150, color: AppColors.teal)),
              Positioned(top: 240 - v * 16, right: -70, child: Orb(size: 190, color: AppColors.blue)),
              Positioned(bottom: 90 + v * 14, left: 70, child: Orb(size: 120, color: AppColors.purple)),
            ],
          );
        },
      ),
    );
  }
}

class Orb extends StatelessWidget {
  final double size;
  final Color color;

  const Orb({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withOpacity(0.14), Colors.transparent]),
      ),
    );
  }
}
