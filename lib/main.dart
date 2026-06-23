import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// SpendGuard Build 24: Final polish. Test notification buttons removed + production GPS notifications.
// Calm opening, natural environment-aware colours, soft card lighting,
// compact Dream Vault, primary goal selector, bilingual Help.

const String googlePlacesApiKey = 'AIzaSyCxvHl7eUjN3GLRWmk45tdXJboXLcSxEFo';
const String spendGuardAppIcon = 'assets/images/spendguard_app_icon.png';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(() {
    rendering.debugPaintSizeEnabled = false;
    rendering.debugPaintBaselinesEnabled = false;
    rendering.debugPaintPointersEnabled = false;
    rendering.debugPaintLayerBordersEnabled = false;
    return true;
  }());
  await NotificationService.init();
  runApp(const SpendGuardApp());

  unawaited(Future<void>.delayed(const Duration(milliseconds: 900), () async {
    await NotificationService.requestPermissions();
  }));
}

class AppColors {
  // SpendGuard Build 13: Living Interface.
  // Natural graphite base with soft environment-aware accents.
  static const bg = Color(0xFF070808);
  static const bgDeep = Color(0xFF020303);

  static const card = Color(0xFF101211);
  static const card2 = Color(0xFF171917);
  static const glass = Color(0xCC101211);

  static const text = Color(0xFFF7F4EA);
  static const muted = Color(0xFFA8A193);

  // Soft premium accents. No artificial gold glow.
  static const gold = Color(0xFFB9A77C);
  static const goldLight = Color(0xFFD8C9A3);
  static const goldDark = Color(0xFF6E634B);
  static const amber = Color(0xFFC2A66D);

  // Legacy aliases kept natural and calm.
  static const teal = Color(0xFF8BAFA4);
  static const blue = Color(0xFF8AA7B8);
  static const neon = Color(0xFFD8C9A3);
  static const purple = Color(0xFF8E8198);

  // Status only.
  static const green = Color(0xFF7DAA82);
  static const red = Color(0xFFC66B5C);
}

enum AmbientKind { home, forest, harbour, sun, clouds, rain, night }

class AmbientPalette {
  final Color top;
  final Color middle;
  final Color bottom;
  final Color accent;
  final Color accentSoft;
  final Color cardTop;
  final Color cardBottom;
  final String label;

  const AmbientPalette({
    required this.top,
    required this.middle,
    required this.bottom,
    required this.accent,
    required this.accentSoft,
    required this.cardTop,
    required this.cardBottom,
    required this.label,
  });

  static AmbientPalette of(AmbientKind kind) {
    switch (kind) {
      case AmbientKind.forest:
        return const AmbientPalette(
          top: Color(0xFF07100C),
          middle: Color(0xFF101914),
          bottom: Color(0xFF050706),
          accent: Color(0xFF8FAF8E),
          accentSoft: Color(0xFFE1DCC4),
          cardTop: Color(0xFF121914),
          cardBottom: Color(0xFF080C09),
          label: 'Forest',
        );
      case AmbientKind.harbour:
        return const AmbientPalette(
          top: Color(0xFF061018),
          middle: Color(0xFF0E1A22),
          bottom: Color(0xFF030608),
          accent: Color(0xFF8CAFC0),
          accentSoft: Color(0xFFD5C7A1),
          cardTop: Color(0xFF10191F),
          cardBottom: Color(0xFF05090D),
          label: 'Harbour',
        );
      case AmbientKind.sun:
        return const AmbientPalette(
          top: Color(0xFF100E09),
          middle: Color(0xFF1A1710),
          bottom: Color(0xFF050505),
          accent: Color(0xFFCBB987),
          accentSoft: Color(0xFFF2E3B8),
          cardTop: Color(0xFF181611),
          cardBottom: Color(0xFF0A0907),
          label: 'Sun',
        );
      case AmbientKind.clouds:
        return const AmbientPalette(
          top: Color(0xFF0B0D0E),
          middle: Color(0xFF16191A),
          bottom: Color(0xFF050606),
          accent: Color(0xFFB8B8AE),
          accentSoft: Color(0xFFE7E2D3),
          cardTop: Color(0xFF171A1A),
          cardBottom: Color(0xFF080909),
          label: 'Clouds',
        );
      case AmbientKind.rain:
        return const AmbientPalette(
          top: Color(0xFF060B10),
          middle: Color(0xFF111820),
          bottom: Color(0xFF030506),
          accent: Color(0xFF92A3B0),
          accentSoft: Color(0xFFD9DEE0),
          cardTop: Color(0xFF121820),
          cardBottom: Color(0xFF05070A),
          label: 'Rain',
        );
      case AmbientKind.night:
        return const AmbientPalette(
          top: Color(0xFF030405),
          middle: Color(0xFF090B0C),
          bottom: Color(0xFF000000),
          accent: Color(0xFF9B927D),
          accentSoft: Color(0xFFD5C6A1),
          cardTop: Color(0xFF0E1010),
          cardBottom: Color(0xFF030303),
          label: 'Night',
        );
      case AmbientKind.home:
        return const AmbientPalette(
          top: Color(0xFF080807),
          middle: Color(0xFF15130F),
          bottom: Color(0xFF040404),
          accent: Color(0xFFB7A883),
          accentSoft: Color(0xFFE0D4B4),
          cardTop: Color(0xFF151410),
          cardBottom: Color(0xFF090807),
          label: 'Home',
        );
    }
  }

  static AmbientPalette fromTime() {
    final hour = DateTime.now().hour;
    if (hour < 6 || hour >= 21) return of(AmbientKind.night);
    if (hour >= 6 && hour < 12) return of(AmbientKind.sun);
    if (hour >= 12 && hour < 18) return of(AmbientKind.home);
    return of(AmbientKind.clouds);
  }

  static AmbientPalette fromStore(StoreInfo? store, String currentStore) {
    final text = '${store?.name ?? ''} ${store?.category ?? ''} $currentStore'.toLowerCase();
    if (text.contains('park') || text.contains('forest') || text.contains('garden') || text.contains('wood')) return of(AmbientKind.forest);
    if (text.contains('harbour') || text.contains('port') || text.contains('pier') || text.contains('marina') || text.contains('sea') || text.contains('beach')) return of(AmbientKind.harbour);
    if (text.contains('home') || text.contains('house')) return of(AmbientKind.home);
    return fromTime();
  }
}

enum AppLanguage { en, it }

class AppText {
  static const Map<AppLanguage, Map<String, String>> _v = {
    AppLanguage.en: {
      'home': 'Home',
      'stores': 'GPS',
      'insights': 'Goals',
      'settings': 'Settings',
      'safeToday': 'Safe Spend Today',
      'remainingToday': 'Remaining today',
      'storeDetected': 'Store detected',
      'noStore': 'No store detected',
      'protect': 'Protect money',
      'setup': 'Setup',
      'futureImpact': 'Dream Impact',
      'addSpending': 'Add spending',
      'keepDream': 'Lock this money',
      'checkGps': 'Check GPS now',
      'language': 'Language',
      'notifications': 'Notifications',
      'enterStoreAlert': 'Store entry alerts',
      'exitStoreAlert': 'Store exit alerts',
      'budget': 'Budget',
      'userName': 'Your name',
      'income': 'Monthly income',
      'expenses': 'Fixed expenses',
      'dreamName': 'Dream name',
      'target': 'Dream target',
      'saved': 'Already saved',
      'months': 'Months to goal',
      'save': 'Save',
      'amount': 'Amount',
      'where': 'Where did you spend?',
      'ready': 'Ready to protect your future?',
      'about': 'SpendGuard helps you know before you buy.',
      'privacy': 'Privacy',
      'version': 'Version',
      'wallet': 'Daily Wallet',
      'history': 'History',
      'todaySpent': 'Spent today',
      'rollover': 'Unspent money rolls over tomorrow.',
      'daysRemaining': 'Days remaining',
      'daysAccumulated': 'Days accumulated',
      'dreamProgress': 'Dream progress',
      'profile': 'Profile',
      'dreamVault': 'Dream Vault',
      'addGoal': 'Add Goal',
      'primaryGoal': 'Primary goal',
      'setPrimary': 'Set primary',
      'viewGoals': 'View goals',
      'accounts': 'Accounts',
      'importStatement': 'Import statement',
      'syncTransactions': 'Sync transactions',
      'recentTransactions': 'Recent transactions',
      'lastImport': 'Last import',
      'newTransactions': 'new transactions',
      'noTransactions': 'No imported transactions yet.',
      'csvHelp': 'Import a CSV bank statement. SpendGuard reads only expenses, detects new transactions and updates your Daily Wallet.',
      'help': 'Help',
      'deleteGoal': 'Delete goal',
      'maxGoalsReached': 'Maximum of 5 goals reached.',
      'autoPrimary': 'Primary goal is selected automatically by the closest date.',
      'forecast': 'Forecast',
      'estimatedDate': 'Estimated date',
    },
    AppLanguage.it: {
      'home': 'Home',
      'stores': 'GPS',
      'insights': 'Goals',
      'settings': 'Impostazioni',
      'safeToday': 'Safe Spend Oggi',
      'remainingToday': 'Disponibile oggi',
      'storeDetected': 'Negozio rilevato',
      'noStore': 'Nessun negozio rilevato',
      'protect': 'Proteggi soldi',
      'setup': 'Imposta',
      'futureImpact': 'Dream Impact',
      'addSpending': 'Aggiungi spesa',
      'keepDream': 'Blocca questi soldi',
      'checkGps': 'Controlla GPS ora',
      'language': 'Lingua',
      'notifications': 'Notifiche',
      'enterStoreAlert': 'Notifica quando entro in un negozio',
      'exitStoreAlert': 'Notifica quando esco da un negozio',
      'budget': 'Budget',
      'userName': 'Il tuo nome',
      'income': 'Entrata mensile',
      'expenses': 'Spese fisse',
      'dreamName': 'Nome obiettivo',
      'target': 'Costo obiettivo',
      'saved': 'Già risparmiato',
      'months': 'Mesi all’obiettivo',
      'save': 'Salva',
      'amount': 'Importo',
      'where': 'Dove hai speso?',
      'ready': 'Pronto a proteggere il futuro?',
      'about': 'SpendGuard ti aiuta a sapere prima di comprare.',
      'privacy': 'Privacy',
      'version': 'Versione',
      'wallet': 'Daily Wallet',
      'history': 'Storico',
      'todaySpent': 'Speso oggi',
      'rollover': 'I soldi non spesi passano a domani.',
      'daysRemaining': 'Giorni rimanenti',
      'daysAccumulated': 'Giorni accumulati',
      'dreamProgress': 'Dream progress',
      'profile': 'Profilo',
      'dreamVault': 'Dream Vault',
      'addGoal': 'Aggiungi obiettivo',
      'primaryGoal': 'Obiettivo principale',
      'setPrimary': 'Imposta principale',
      'viewGoals': 'Vedi goals',
      'accounts': 'Conti',
      'importStatement': 'Importa estratto conto',
      'syncTransactions': 'Sincronizza transazioni',
      'recentTransactions': 'Transazioni recenti',
      'lastImport': 'Ultima importazione',
      'newTransactions': 'nuove transazioni',
      'noTransactions': 'Nessuna transazione importata.',
      'csvHelp': 'Importa un estratto conto CSV. SpendGuard legge solo le spese, riconosce le nuove transazioni e aggiorna il Daily Wallet.',
      'help': 'Aiuto',
      'deleteGoal': 'Cancella goal',
      'maxGoalsReached': 'Massimo 5 goals raggiunto.',
      'autoPrimary': 'L’obiettivo principale viene scelto automaticamente dalla data più vicina.',
      'forecast': 'Previsioni',
      'estimatedDate': 'Data stimata',
    },
  };

  static String t(AppLanguage lang, String key) => _v[lang]?[key] ?? _v[AppLanguage.en]![key] ?? key;
}

class DreamVisual {
  final IconData icon;
  final String label;
  final Color color;
  final String? emoji;

  const DreamVisual(this.icon, this.label, this.color, {this.emoji});

  static DreamVisual fromText(String raw) {
    final text = _clean(raw);
    bool hasAny(List<String> words) => words.any((w) => text.contains(w));

    final country = _countryFlagFor(text);
    if (country != null) return DreamVisual(Icons.flag_rounded, country.$1, AppColors.teal, emoji: country.$2);

    if (hasAny(['house', 'home', 'casa', 'appartamento', 'apartment', 'flat', 'property', 'mortgage', 'mutuo', 'deposit', 'rent', 'affitto', 'villa', 'condo', 'kitchen', 'garden', 'renovation', 'renovate', 'ristrutturare'])) {
      return const DreamVisual(Icons.home_rounded, 'Home', AppColors.green, emoji: '🏠');
    }
    if (hasAny(['furniture', 'mobili', 'sofa', 'couch', 'divano', 'bed', 'letto', 'wardrobe', 'armadio', 'ikea', 'table', 'desk', 'chair', 'sedia', 'lamp', 'materasso', 'mattress'])) {
      return const DreamVisual(Icons.chair_rounded, 'Furniture', AppColors.amber, emoji: '🛋️');
    }
    if (hasAny(['motorcycle', 'moto', 'motorbike', 'bike', 'vespa', 'scooter', 'ducati', 'yamaha', 'honda motor', 'harley'])) {
      return const DreamVisual(Icons.two_wheeler_rounded, 'Motorbike', AppColors.teal, emoji: '🏍️');
    }
    if (hasAny(['bicycle', 'bici', 'bicicletta', 'cycling', 'ebike', 'e-bike', 'mountain bike'])) {
      return const DreamVisual(Icons.directions_bike_rounded, 'Bicycle', AppColors.green, emoji: '🚲');
    }
    if (hasAny(['car', 'auto', 'macchina', 'tesla', 'bmw', 'audi', 'mercedes', 'volkswagen', 'toyota', 'ford', 'fiat', 'range rover', 'jeep', 'van', 'camper'])) {
      return const DreamVisual(Icons.directions_car_rounded, 'Car', AppColors.blue, emoji: '🚗');
    }
    if (hasAny(['holiday', 'vacation', 'vacanze', 'viaggio', 'travel', 'trip', 'mare', 'beach', 'flight', 'volo', 'hotel', 'resort', 'cruise', 'crociera', 'passport', 'passaporto', 'backpacking'])) {
      return const DreamVisual(Icons.flight_takeoff_rounded, 'Travel', AppColors.teal, emoji: '✈️');
    }
    if (hasAny(['sea', 'ocean', 'spiaggia', 'island', 'isola', 'surf', 'boat', 'barca', 'yacht', 'swim', 'swimming'])) {
      return const DreamVisual(Icons.beach_access_rounded, 'Beach', AppColors.blue, emoji: '🏝️');
    }
    if (hasAny(['mountain', 'montagna', 'ski', 'snowboard', 'snow', 'neve', 'hiking', 'trekking', 'camping'])) {
      return const DreamVisual(Icons.terrain_rounded, 'Adventure', AppColors.green, emoji: '⛰️');
    }
    if (hasAny(['macbook', 'laptop', 'computer', 'pc', 'imac', 'desktop', 'monitor', 'keyboard', 'mouse', 'ipad', 'tablet'])) {
      return const DreamVisual(Icons.laptop_mac_rounded, 'Tech', AppColors.blue, emoji: '💻');
    }
    if (hasAny(['iphone', 'phone', 'telefono', 'mobile', 'smartphone', 'samsung', 'android'])) {
      return const DreamVisual(Icons.phone_iphone_rounded, 'Phone', AppColors.teal, emoji: '📱');
    }
    if (hasAny(['camera', 'fotocamera', 'photo', 'foto', 'photography', 'gopro', 'drone', 'lens', 'obiettivo camera'])) {
      return const DreamVisual(Icons.camera_alt_rounded, 'Camera', AppColors.blue, emoji: '📷');
    }
    if (hasAny(['watch', 'apple watch', 'orologio', 'rolex', 'omega'])) {
      return const DreamVisual(Icons.watch_rounded, 'Watch', AppColors.amber, emoji: '⌚');
    }
    if (hasAny(['wedding', 'matrimonio', 'ring', 'anello', 'engagement', 'fidanzamento', 'honeymoon', 'luna di miele'])) {
      return const DreamVisual(Icons.favorite_rounded, 'Wedding', AppColors.purple, emoji: '💍');
    }
    if (hasAny(['baby', 'bambino', 'bambina', 'figlio', 'figlia', 'family', 'famiglia', 'children', 'kids', 'asilo'])) {
      return const DreamVisual(Icons.child_care_rounded, 'Family', AppColors.amber, emoji: '👶');
    }
    if (hasAny(['business', 'startup', 'azienda', 'company', 'shop', 'negozio', 'brand', 'investimento', 'investment', 'stock', 'trading', 'crypto', 'shares'])) {
      return const DreamVisual(Icons.trending_up_rounded, 'Business', AppColors.green, emoji: '📈');
    }
    if (hasAny(['university', 'college', 'school', 'università', 'corso', 'study', 'studiare', 'course', 'master', 'degree', 'exam', 'esame', 'training'])) {
      return const DreamVisual(Icons.school_rounded, 'Study', AppColors.blue, emoji: '🎓');
    }
    if (hasAny(['dog', 'cane', 'cat', 'gatto', 'pet', 'puppy', 'kitten', 'veterinary', 'vet'])) {
      return const DreamVisual(Icons.pets_rounded, 'Pet', AppColors.amber, emoji: '🐾');
    }
    if (hasAny(['playstation', 'ps5', 'xbox', 'nintendo', 'switch', 'game', 'gaming', 'console', 'pc gaming'])) {
      return const DreamVisual(Icons.sports_esports_rounded, 'Gaming', AppColors.purple, emoji: '🎮');
    }
    if (hasAny(['guitar', 'chitarra', 'music', 'musica', 'piano', 'keyboard', 'drums', 'microphone', 'studio', 'amplifier'])) {
      return const DreamVisual(Icons.music_note_rounded, 'Music', AppColors.purple, emoji: '🎸');
    }
    if (hasAny(['gym', 'fitness', 'palestra', 'boxing', 'boxe', 'weights', 'running', 'marathon', 'football', 'soccer', 'sport'])) {
      return const DreamVisual(Icons.fitness_center_rounded, 'Fitness', AppColors.green, emoji: '🏋️');
    }
    if (hasAny(['health', 'salute', 'dentist', 'dental', 'teeth', 'doctor', 'medical', 'operation', 'surgery', 'therapy'])) {
      return const DreamVisual(Icons.health_and_safety_rounded, 'Health', AppColors.red, emoji: '🏥');
    }
    if (hasAny(['clothes', 'vestiti', 'fashion', 'moda', 'shoes', 'scarpe', 'bag', 'borsa', 'jacket', 'giacca', 'zara', 'primark'])) {
      return const DreamVisual(Icons.checkroom_rounded, 'Fashion', AppColors.purple, emoji: '👟');
    }
    if (hasAny(['food', 'cibo', 'restaurant', 'ristorante', 'dinner', 'cena', 'pizza', 'sushi', 'coffee', 'cafe'])) {
      return const DreamVisual(Icons.restaurant_rounded, 'Food', AppColors.amber, emoji: '🍽️');
    }
    if (hasAny(['emergency', 'rainy day', 'savings', 'risparmio', 'save money', 'security', 'sicurezza'])) {
      return const DreamVisual(Icons.savings_rounded, 'Savings', AppColors.green, emoji: '💰');
    }
    return const DreamVisual(Icons.flag_rounded, 'Dream', AppColors.green, emoji: '✨');
  }

  static String _clean(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâä]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9\s\-&]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static (String, String)? _countryFlagFor(String text) {
    const countries = <String, (String, String)>{
      'italy': ('Italy', '🇮🇹'), 'italia': ('Italy', '🇮🇹'), 'rome': ('Italy', '🇮🇹'), 'roma': ('Italy', '🇮🇹'), 'milan': ('Italy', '🇮🇹'), 'milano': ('Italy', '🇮🇹'), 'naples': ('Italy', '🇮🇹'), 'napoli': ('Italy', '🇮🇹'), 'puglia': ('Italy', '🇮🇹'), 'sicily': ('Italy', '🇮🇹'), 'sicilia': ('Italy', '🇮🇹'),
      'ireland': ('Ireland', '🇮🇪'), 'irlanda': ('Ireland', '🇮🇪'), 'dublin': ('Ireland', '🇮🇪'), 'galway': ('Ireland', '🇮🇪'), 'cork': ('Ireland', '🇮🇪'),
      'spain': ('Spain', '🇪🇸'), 'espana': ('Spain', '🇪🇸'), 'barcelona': ('Spain', '🇪🇸'), 'madrid': ('Spain', '🇪🇸'), 'ibiza': ('Spain', '🇪🇸'), 'canary': ('Spain', '🇪🇸'),
      'france': ('France', '🇫🇷'), 'paris': ('France', '🇫🇷'), 'nice': ('France', '🇫🇷'), 'monaco': ('Monaco', '🇲🇨'),
      'england': ('United Kingdom', '🇬🇧'), 'uk': ('United Kingdom', '🇬🇧'), 'united kingdom': ('United Kingdom', '🇬🇧'), 'london': ('United Kingdom', '🇬🇧'), 'scotland': ('United Kingdom', '🇬🇧'), 'edinburgh': ('United Kingdom', '🇬🇧'),
      'germany': ('Germany', '🇩🇪'), 'berlin': ('Germany', '🇩🇪'), 'munich': ('Germany', '🇩🇪'),
      'portugal': ('Portugal', '🇵🇹'), 'lisbon': ('Portugal', '🇵🇹'), 'lisboa': ('Portugal', '🇵🇹'), 'porto': ('Portugal', '🇵🇹'),
      'greece': ('Greece', '🇬🇷'), 'grecia': ('Greece', '🇬🇷'), 'athens': ('Greece', '🇬🇷'), 'mykonos': ('Greece', '🇬🇷'), 'santorini': ('Greece', '🇬🇷'),
      'japan': ('Japan', '🇯🇵'), 'giappone': ('Japan', '🇯🇵'), 'tokyo': ('Japan', '🇯🇵'), 'kyoto': ('Japan', '🇯🇵'), 'osaka': ('Japan', '🇯🇵'),
      'usa': ('United States', '🇺🇸'), 'america': ('United States', '🇺🇸'), 'united states': ('United States', '🇺🇸'), 'new york': ('United States', '🇺🇸'), 'florida': ('United States', '🇺🇸'), 'miami': ('United States', '🇺🇸'), 'california': ('United States', '🇺🇸'), 'los angeles': ('United States', '🇺🇸'), 'washington': ('United States', '🇺🇸'),
      'canada': ('Canada', '🇨🇦'), 'toronto': ('Canada', '🇨🇦'), 'vancouver': ('Canada', '🇨🇦'),
      'australia': ('Australia', '🇦🇺'), 'sydney': ('Australia', '🇦🇺'), 'melbourne': ('Australia', '🇦🇺'),
      'brazil': ('Brazil', '🇧🇷'), 'brasil': ('Brazil', '🇧🇷'), 'rio': ('Brazil', '🇧🇷'),
      'mexico': ('Mexico', '🇲🇽'), 'messico': ('Mexico', '🇲🇽'), 'cancun': ('Mexico', '🇲🇽'),
      'thailand': ('Thailand', '🇹🇭'), 'thai': ('Thailand', '🇹🇭'), 'bangkok': ('Thailand', '🇹🇭'), 'phuket': ('Thailand', '🇹🇭'),
      'bali': ('Indonesia', '🇮🇩'), 'indonesia': ('Indonesia', '🇮🇩'),
      'maldives': ('Maldives', '🇲🇻'), 'maldive': ('Maldives', '🇲🇻'),
      'dubai': ('United Arab Emirates', '🇦🇪'), 'uae': ('United Arab Emirates', '🇦🇪'), 'emirates': ('United Arab Emirates', '🇦🇪'),
      'turkey': ('Turkey', '🇹🇷'), 'turchia': ('Turkey', '🇹🇷'), 'istanbul': ('Turkey', '🇹🇷'),
      'egypt': ('Egypt', '🇪🇬'), 'egitto': ('Egypt', '🇪🇬'), 'cairo': ('Egypt', '🇪🇬'),
      'switzerland': ('Switzerland', '🇨🇭'), 'svizzera': ('Switzerland', '🇨🇭'), 'zurich': ('Switzerland', '🇨🇭'),
      'netherlands': ('Netherlands', '🇳🇱'), 'holland': ('Netherlands', '🇳🇱'), 'amsterdam': ('Netherlands', '🇳🇱'),
      'belgium': ('Belgium', '🇧🇪'), 'brussels': ('Belgium', '🇧🇪'),
      'austria': ('Austria', '🇦🇹'), 'vienna': ('Austria', '🇦🇹'),
      'poland': ('Poland', '🇵🇱'), 'warsaw': ('Poland', '🇵🇱'),
      'norway': ('Norway', '🇳🇴'), 'sweden': ('Sweden', '🇸🇪'), 'denmark': ('Denmark', '🇩🇰'), 'finland': ('Finland', '🇫🇮'), 'iceland': ('Iceland', '🇮🇸'),
      'croatia': ('Croatia', '🇭🇷'), 'croazia': ('Croatia', '🇭🇷'), 'malta': ('Malta', '🇲🇹'), 'cyprus': ('Cyprus', '🇨🇾'),
      'india': ('India', '🇮🇳'), 'china': ('China', '🇨🇳'), 'korea': ('South Korea', '🇰🇷'), 'seoul': ('South Korea', '🇰🇷'),
      'singapore': ('Singapore', '🇸🇬'), 'morocco': ('Morocco', '🇲🇦'), 'marocco': ('Morocco', '🇲🇦'), 'south africa': ('South Africa', '🇿🇦'),
    };

    for (final entry in countries.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }
}

String formatDaysHuman(int days, {bool signed = false}) {
  final sign = days < 0 ? '-' : (signed && days > 0 ? '+' : '');
  final total = days.abs();
  final years = total ~/ 365;
  final rest = total % 365;
  if (years > 0 && rest > 0) return '${sign}${years}y ${rest}d';
  if (years > 0) return '${sign}${years}y';
  return '${sign}${rest}d';
}

String formatDaysHumanLong(int days, {bool signed = false}) {
  final sign = days < 0 ? '-' : (signed && days > 0 ? '+' : '');
  final total = days.abs();
  final years = total ~/ 365;
  final rest = total % 365;
  final y = years == 1 ? '1 year' : '$years years';
  final d = rest == 1 ? '1 day' : '$rest days';
  if (years > 0 && rest > 0) return '$sign$y $d';
  if (years > 0) return '$sign$y';
  return '$sign$d';
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
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.gold, brightness: Brightness.dark),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: AppColors.bgDeep.withOpacity(0.92),
            indicatorColor: AppColors.gold.withOpacity(0.12),
            labelTextStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.gold : AppColors.muted)),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.gold.withOpacity(0.035),
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
              borderSide: const BorderSide(color: AppColors.goldLight, width: 1.2),
            ),
          ),
        ),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final systemScale = mq.textScaler.scale(1.0);
          final safeScale = systemScale.clamp(0.92, 1.10).toDouble();
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(safeScale)),
            child: child ?? const SizedBox.shrink(),
          );
        },
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

String greetingTitle(BuildContext context) {
  final hour = DateTime.now().hour;
  final lang = AppLanguageScope.of(context).language;

  if (lang == AppLanguage.it) {
    if (hour >= 5 && hour < 12) return 'Buongiorno';
    if (hour >= 12 && hour < 18) return 'Buon pomeriggio';
    return 'Buonasera';
  }

  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  static bool _initialised = false;
  static String lastDebug = 'Not checked yet';

  static Future<void> init() async {
    if (kIsWeb || _initialised) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const settings = InitializationSettings(android: android, iOS: ios, macOS: ios);
    await plugin.initialize(settings);
    _initialised = true;
  }

  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    await init();

    try {
      final iosPlugin = plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final macPlugin = plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
      final androidPlugin = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final iosGranted = await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
      final macGranted = await macPlugin?.requestPermissions(alert: true, badge: true, sound: true);
      final androidGranted = await androidPlugin?.requestNotificationsPermission();

      final granted = iosGranted ?? macGranted ?? androidGranted ?? true;
      lastDebug = 'Permission result: ios=$iosGranted mac=$macGranted android=$androidGranted final=$granted';
      return granted;
    } catch (e) {
      debugPrint('SpendGuard notification permission failed: $e');
      return false;
    }
  }

  static Future<bool> show(String title, String body) async {
    if (kIsWeb) return false;

    try {
      await init();
      final granted = await requestPermissions();
      if (!granted) {
        lastDebug = 'Blocked by system permissions. Open iPhone Settings > Notifications > SpendGuard and allow notifications, banners and sounds.';
        return false;
      }

      const android = AndroidNotificationDetails(
        'spendguard_store_alerts_v24_s_icon_fixed',
        'SpendGuard Store Alerts',
        channelDescription: 'Smart GPS spending alerts when you enter shops.',
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
      );

      const ios = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
        threadIdentifier: 'spendguard_store_alerts',
      );

      final id = DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
      await plugin.show(id, title, body, const NotificationDetails(android: android, iOS: ios, macOS: ios));
      lastDebug = 'iOS accepted the notification request, but this does NOT prove the banner appeared. If you do not see it, notifications are disabled/hidden in iPhone Settings, Focus mode, or app notification style.';
      return true;
    } catch (e) {
      lastDebug = 'Notification failed: $e';
      debugPrint('SpendGuard notification failed: $e');
      return false;
    }
  }

  static Future<bool> showTestSequence() async {
    final first = await show(
      'SpendGuard test now',
      'Immediate test notification. If you see this, iOS notifications work.',
    );

    unawaited(Future<void>.delayed(const Duration(seconds: 5), () async {
      await show(
        'SpendGuard test after 5 seconds',
        'Delayed test. This should appear even if you lock the phone.',
      );
    }));

    if (first) {
      lastDebug = '$lastDebug Delayed test scheduled in 5 seconds. Lock the phone now to test background banner.';
    }
    return first;
  }
}


class NativeGeofenceService {
  static const MethodChannel _channel = MethodChannel('spendguard/native_geofence');

  static Future<void> requestAlwaysPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod('requestAlwaysPermission');
    } catch (e) {
      debugPrint('SpendGuard native geofence permission failed: $e');
    }
  }

  static Future<void> startMonitoringStore(StoreInfo store) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod('startMonitoringStore', <String, dynamic>{
        'name': store.name,
        'category': store.category,
        'lat': store.lat,
        'lng': store.lng,
        'radius': store.triggerRadiusMeters.clamp(35.0, 120.0),
      });
    } catch (e) {
      debugPrint('SpendGuard native geofence start failed: $e');
    }
  }
}

class BudgetData {
  final String userName;
  final String dreamName;
  final double income;
  final double fixedExpenses;
  final double dreamTarget;
  final double dreamSaved;
  final double dreamMonths;
  final double dreamVault;
  final String dreamStartDay;
  final int dreamDayAdjustment;

  const BudgetData({
    required this.userName,
    required this.dreamName,
    required this.income,
    required this.fixedExpenses,
    required this.dreamTarget,
    required this.dreamSaved,
    required this.dreamMonths,
    required this.dreamVault,
    required this.dreamStartDay,
    required this.dreamDayAdjustment,
  });

  static const empty = BudgetData(
    userName: '',
    dreamName: '',
    income: 0,
    fixedExpenses: 0,
    dreamTarget: 0,
    dreamSaved: 0,
    dreamMonths: 0,
    dreamVault: 0,
    dreamStartDay: '',
    dreamDayAdjustment: 0,
  );

  bool get isReady => income > 0;
  bool get hasDream => dreamTarget > 0 && dreamMonths > 0;
  double get monthlyRoom => max(0, income - fixedExpenses).toDouble();
  double get baseDailyAmount => monthlyRoom / 30;
  double get dreamDays => max(1, dreamMonths * 30).toDouble();
  int get plannedDreamDays => dreamDays.ceil();
  double get dreamTotalProtected => (dreamSaved + dreamVault).clamp(0, dreamTarget).toDouble();
  double get dreamRemaining => max(0, dreamTarget - dreamTotalProtected).toDouble();
  double get dreamDailyNeed => hasDream ? dreamRemaining / dreamDays : 0;
  double get dailySafeBase => max(0, baseDailyAmount - dreamDailyNeed).toDouble();
  double get dreamProgress => dreamTarget <= 0 ? 0 : (dreamTotalProtected / dreamTarget).clamp(0, 1).toDouble();
  int get dreamProgressPercent => (dreamProgress * 100).round();

  static String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static DateTime? parseDay(String key) {
    try {
      final p = key.split('-').map(int.parse).toList();
      return DateTime(p[0], p[1], p[2]);
    } catch (_) {
      return null;
    }
  }

  int get daysSinceDreamStart {
    final start = parseDay(dreamStartDay);
    if (start == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return max(0, today.difference(start).inDays);
  }

  int get dreamDaysRemaining {
    if (!hasDream) return 0;
    final naturalRemaining = plannedDreamDays - daysSinceDreamStart;
    return max(0, naturalRemaining + dreamDayAdjustment);
  }

  int get dreamDaysShiftFromPlan => dreamDaysRemaining - max(0, plannedDreamDays - daysSinceDreamStart);
  String get dreamDaysShiftLabel {
    if (dreamDaysShiftFromPlan == 0) return '0d';
    return formatDaysHuman(dreamDaysShiftFromPlan, signed: true);
  }

  String get dreamDaysShiftLongLabel {
    if (dreamDaysShiftFromPlan == 0) return '0 days';
    return formatDaysHumanLong(dreamDaysShiftFromPlan, signed: true);
  }

  String get dreamDaysRemainingLabel => formatDaysHuman(dreamDaysRemaining);
  String get dreamDaysRemainingLongLabel => formatDaysHumanLong(dreamDaysRemaining);

  int impactDaysFor(double amount) {
    if (!hasDream || amount <= 0) return 0;
    final plannedDailyNeed = max(1.0, dreamTarget / dreamDays);
    return max(1, (amount / plannedDailyNeed).ceil());
  }

  int delayDaysFor(double amount) => impactDaysFor(amount);

  BudgetData applySpendingToDream(double amount) {
    if (!hasDream || amount <= 0) return this;
    var newVault = dreamVault;
    var newSaved = dreamSaved;
    var remaining = amount;

    final fromVault = min(newVault, remaining);
    newVault -= fromVault;
    remaining -= fromVault;

    if (remaining > 0) {
      final fromSaved = min(newSaved, remaining);
      newSaved -= fromSaved;
    }

    return copyWith(
      dreamVault: max(0, newVault).toDouble(),
      dreamSaved: max(0, newSaved).toDouble(),
      dreamDayAdjustment: dreamDayAdjustment + impactDaysFor(amount),
    );
  }

  BudgetData applyProtectionToDream(double amount) {
    if (!hasDream || amount <= 0) return this;
    return copyWith(
      dreamVault: dreamVault + amount,
      dreamDayAdjustment: dreamDayAdjustment - impactDaysFor(amount),
    );
  }

  BudgetData copyWith({
    String? userName,
    String? dreamName,
    double? income,
    double? fixedExpenses,
    double? dreamTarget,
    double? dreamSaved,
    double? dreamMonths,
    double? dreamVault,
    String? dreamStartDay,
    int? dreamDayAdjustment,
  }) {
    return BudgetData(
      userName: userName ?? this.userName,
      dreamName: dreamName ?? this.dreamName,
      income: income ?? this.income,
      fixedExpenses: fixedExpenses ?? this.fixedExpenses,
      dreamTarget: dreamTarget ?? this.dreamTarget,
      dreamSaved: dreamSaved ?? this.dreamSaved,
      dreamMonths: dreamMonths ?? this.dreamMonths,
      dreamVault: dreamVault ?? this.dreamVault,
      dreamStartDay: dreamStartDay ?? this.dreamStartDay,
      dreamDayAdjustment: dreamDayAdjustment ?? this.dreamDayAdjustment,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('userName', userName);
    await p.setString('dreamName', dreamName);
    await p.setDouble('income', income);
    await p.setDouble('fixedExpenses', fixedExpenses);
    await p.setDouble('dreamTarget', dreamTarget);
    await p.setDouble('dreamSaved', dreamSaved);
    await p.setDouble('dreamMonths', dreamMonths);
    await p.setDouble('dreamVault', dreamVault);
    await p.setString('dreamStartDay', dreamStartDay.isEmpty ? todayKey() : dreamStartDay);
    await p.setInt('dreamDayAdjustment', dreamDayAdjustment);
    await p.setBool('setupDone', true);
  }

  static Future<BudgetData> load() async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool('setupDone') ?? false)) return BudgetData.empty;
    return BudgetData(
      userName: p.getString('userName') ?? '',
      dreamName: p.getString('dreamName') ?? '',
      income: p.getDouble('income') ?? 0,
      fixedExpenses: p.getDouble('fixedExpenses') ?? 0,
      dreamTarget: p.getDouble('dreamTarget') ?? 0,
      dreamSaved: p.getDouble('dreamSaved') ?? 0,
      dreamMonths: p.getDouble('dreamMonths') ?? 0,
      dreamVault: p.getDouble('dreamVault') ?? 0,
      dreamStartDay: p.getString('dreamStartDay') ?? todayKey(),
      dreamDayAdjustment: p.getInt('dreamDayAdjustment') ?? 0,
    );
  }
}

class DreamGoal {
  final String id;
  final String name;
  final double target;
  final double saved;
  final double months;
  final double vault;
  final String startDay;
  final int dayAdjustment;
  final bool primary;

  const DreamGoal({required this.id, required this.name, required this.target, required this.saved, required this.months, required this.vault, required this.startDay, required this.dayAdjustment, required this.primary});

  bool get hasGoal => target > 0 && months > 0;
  double get totalProtected => (saved + vault).clamp(0, target).toDouble();
  double get progress => target <= 0 ? 0 : (totalProtected / target).clamp(0, 1).toDouble();
  int get progressPercent => (progress * 100).round();
  double get plannedDays => max(1, months * 30).toDouble();
  int get plannedGoalDays => plannedDays.ceil();

  int get daysSinceStart {
    final start = BudgetData.parseDay(startDay);
    if (start == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return max(0, today.difference(start).inDays);
  }

  int get daysRemaining {
    if (!hasGoal) return 0;
    final naturalRemaining = plannedGoalDays - daysSinceStart;
    return max(0, naturalRemaining + dayAdjustment);
  }

  String get daysRemainingLabel => formatDaysHuman(daysRemaining);
  String get daysRemainingLongLabel => formatDaysHumanLong(daysRemaining);
  DateTime get estimatedDate => DateTime.now().add(Duration(days: daysRemaining));
  double get remainingAmount => max(0, target - totalProtected).toDouble();

  double dailySafeAmount(double monthlyRoom) {
    if (!hasGoal) return max(0, monthlyRoom / 30).toDouble();
    final need = remainingAmount / plannedDays;
    return max(0, (monthlyRoom / 30) - need).toDouble();
  }

  int impactDaysFor(double amount) {
    if (!hasGoal || amount <= 0) return 0;
    final dailyNeed = max(1.0, target / plannedDays);
    return max(1, (amount / dailyNeed).ceil());
  }

  DreamGoal copyWith({String? id, String? name, double? target, double? saved, double? months, double? vault, String? startDay, int? dayAdjustment, bool? primary}) {
    return DreamGoal(id: id ?? this.id, name: name ?? this.name, target: target ?? this.target, saved: saved ?? this.saved, months: months ?? this.months, vault: vault ?? this.vault, startDay: startDay ?? this.startDay, dayAdjustment: dayAdjustment ?? this.dayAdjustment, primary: primary ?? this.primary);
  }

  DreamGoal applySpending(double amount) => copyWith(dayAdjustment: dayAdjustment + impactDaysFor(amount));
  DreamGoal applyProtection(double amount) => copyWith(vault: vault + amount, dayAdjustment: dayAdjustment - impactDaysFor(amount));

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'target': target, 'saved': saved, 'months': months, 'vault': vault, 'startDay': startDay, 'dayAdjustment': dayAdjustment, 'primary': primary};

  static DreamGoal fromJson(Map<String, dynamic> json) => DreamGoal(
        id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
        name: (json['name'] ?? '').toString(),
        target: ((json['target'] ?? 0) as num).toDouble(),
        saved: ((json['saved'] ?? 0) as num).toDouble(),
        months: ((json['months'] ?? 0) as num).toDouble(),
        vault: ((json['vault'] ?? 0) as num).toDouble(),
        startDay: (json['startDay'] ?? BudgetData.todayKey()).toString(),
        dayAdjustment: ((json['dayAdjustment'] ?? 0) as num).toInt(),
        primary: json['primary'] == true,
      );

  static DreamGoal fromBudget(BudgetData budget) => DreamGoal(id: 'primary', name: budget.dreamName, target: budget.dreamTarget, saved: budget.dreamSaved, months: budget.dreamMonths, vault: budget.dreamVault, startDay: budget.dreamStartDay.isEmpty ? BudgetData.todayKey() : budget.dreamStartDay, dayAdjustment: budget.dreamDayAdjustment, primary: true);

  static Future<List<DreamGoal>> loadAll(BudgetData budget) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('dreamGoals');
    List<DreamGoal> goals = [];
    if (raw != null && raw.isNotEmpty) {
      goals = raw.map((e) {
        try {
          return DreamGoal.fromJson(jsonDecode(e) as Map<String, dynamic>);
        } catch (_) {
          return null;
        }
      }).whereType<DreamGoal>().where((g) => g.name.trim().isNotEmpty || g.target > 0).toList();
    }
    final primary = fromBudget(budget);
    if (primary.name.trim().isNotEmpty || primary.target > 0) {
      final withoutPrimary = goals.where((g) => g.id != 'primary').toList();
      goals = [primary, ...withoutPrimary];
    }
    if (goals.isEmpty) return goals;
    goals = sortByClosestGoal(goals).take(5).toList();
    await saveAll(goals);
    return goals;
  }

  static List<DreamGoal> sortByClosestGoal(List<DreamGoal> goals) {
    final clean = goals.where((g) => g.name.trim().isNotEmpty || g.target > 0).toList();
    clean.sort((a, b) {
      final byDays = a.daysRemaining.compareTo(b.daysRemaining);
      if (byDays != 0) return byDays;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return [
      for (var i = 0; i < clean.length && i < 5; i++) clean[i].copyWith(primary: i == 0),
    ];
  }

  static Future<void> saveAll(List<DreamGoal> goals) async {
    final p = await SharedPreferences.getInstance();
    final clean = sortByClosestGoal(goals).take(5).toList();
    await p.setStringList('dreamGoals', clean.map((g) => jsonEncode(g.toJson())).toList());
  }
}



class BankTransaction {
  final String id;
  final DateTime date;
  final String description;
  final double amount;

  const BankTransaction({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
  });

  String get merchant {
    final cleaned = description
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'CARD PAYMENT TO |VISA |MASTERCARD |REVOLUT \*', caseSensitive: false), '')
        .trim();
    return cleaned.isEmpty ? 'Bank transaction' : cleaned;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'description': description,
        'amount': amount,
      };

  static BankTransaction fromJson(Map<String, dynamic> json) => BankTransaction(
        id: (json['id'] ?? '').toString(),
        date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
        description: (json['description'] ?? 'Bank transaction').toString(),
        amount: ((json['amount'] ?? 0) as num).toDouble(),
      );

  static Future<List<BankTransaction>> loadImported() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('bankTransactions') ?? [];
    return raw.map((e) {
      try {
        return BankTransaction.fromJson(jsonDecode(e) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<BankTransaction>().toList();
  }

  static Future<void> saveImported(List<BankTransaction> transactions) async {
    final p = await SharedPreferences.getInstance();
    final clean = transactions.take(500).toList();
    await p.setStringList('bankTransactions', clean.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList('importedTransactionIds', clean.map((e) => e.id).toSet().toList());
    await p.setString('lastCsvImportAt', DateTime.now().toIso8601String());
  }
}

class CsvImportResult {
  final List<BankTransaction> transactions;
  final int rowsRead;
  final int rowsSkipped;

  const CsvImportResult({required this.transactions, required this.rowsRead, required this.rowsSkipped});
}


class CsvBankParser {
  static CsvImportResult parseBytes(Uint8List bytes) {
    final rawContent = _decodeStatementBytes(bytes).replaceAll('\ufeff', '').replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (rawContent.isEmpty) return const CsvImportResult(transactions: [], rowsRead: 0, rowsSkipped: 0);

    final candidates = <List<List<dynamic>>>[];
    for (final delimiter in [',', ';', '\t', '|']) {
      try {
        final parsed = CsvToListConverter(shouldParseNumbers: false, fieldDelimiter: delimiter).convert(rawContent);
        if (parsed.isNotEmpty) candidates.add(parsed);
      } catch (_) {}
    }
    if (candidates.isEmpty) return const CsvImportResult(transactions: [], rowsRead: 0, rowsSkipped: 0);

    candidates.sort((a, b) => _scoreRows(b).compareTo(_scoreRows(a)));
    final rows = candidates.first.where((r) => r.any((c) => c.toString().trim().isNotEmpty)).toList();
    if (rows.isEmpty) return const CsvImportResult(transactions: [], rowsRead: 0, rowsSkipped: 0);

    final headerIndex = _headerIndex(rows);
    final headers = rows[headerIndex].map((e) => _norm(e.toString())).toList();
    final dataRows = rows.skip(headerIndex + 1).toList();

    final parsedWithHeaders = _parseWithHeaders(headers, dataRows);
    if (parsedWithHeaders.transactions.isNotEmpty) return parsedWithHeaders;

    // Fallback for bank exports with strange column names or no header.
    final fallbackRows = headerIndex == 0 ? rows : dataRows;
    return _parseWithoutHeaders(fallbackRows);
  }

  static String _decodeStatementBytes(Uint8List bytes) {
    if (bytes.length >= 2) {
      final b0 = bytes[0];
      final b1 = bytes[1];
      if (b0 == 0xFF && b1 == 0xFE) return _decodeUtf16(bytes.sublist(2), littleEndian: true);
      if (b0 == 0xFE && b1 == 0xFF) return _decodeUtf16(bytes.sublist(2), littleEndian: false);
      // Excel sometimes exports UTF-16LE without BOM.
      final sample = bytes.take(min(bytes.length, 200)).toList();
      final zerosOdd = [for (var i = 1; i < sample.length; i += 2) if (sample[i] == 0) i].length;
      if (zerosOdd > sample.length / 6) return _decodeUtf16(bytes, littleEndian: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
    final codes = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final code = littleEndian ? (bytes[i] | (bytes[i + 1] << 8)) : ((bytes[i] << 8) | bytes[i + 1]);
      if (code != 0) codes.add(code);
    }
    return String.fromCharCodes(codes);
  }

  static CsvImportResult _parseWithHeaders(List<String> headers, List<List<dynamic>> dataRows) {
    final dateIndex = _find(headers, ['date', 'completed date', 'started date', 'booking date', 'value date', 'transaction date', 'time', 'created at', 'completed at', 'settled date']);
    final descIndex = _find(headers, ['description', 'merchant', 'counterparty', 'name', 'reference', 'details', 'memo', 'narrative', 'beneficiary', 'payee', 'partner', 'cardholder name']);
    final signedAmountIndex = _find(headers, ['amount', 'transaction amount', 'value', 'amount eur', 'amount gbp', 'amount in eur', 'paid', 'original amount']);
    final debitIndex = _find(headers, ['paid out', 'debit', 'money out', 'withdrawal', 'out', 'spent', 'amount debited']);
    final creditIndex = _find(headers, ['paid in', 'credit', 'money in', 'deposit', 'in', 'received', 'amount credited']);

    final transactions = <BankTransaction>[];
    var skipped = 0;

    for (final row in dataRows) {
      if (row.isEmpty || row.every((e) => e.toString().trim().isEmpty)) continue;
      final date = _parseDate(dateIndex >= 0 ? _cell(row, dateIndex) : _findDateCell(row));
      final desc = _bestDescription(row, descIndex, descIndex >= 0 ? descIndex : 1);
      if (date == null || desc.isEmpty) {
        skipped++;
        continue;
      }

      double amount = 0;
      if (debitIndex >= 0 && _cell(row, debitIndex).trim().isNotEmpty) {
        amount = _parseMoney(_cell(row, debitIndex)).abs();
      } else if (signedAmountIndex >= 0) {
        final signed = _parseMoney(_cell(row, signedAmountIndex));
        if (creditIndex >= 0 && _cell(row, creditIndex).trim().isNotEmpty && signed >= 0) {
          skipped++;
          continue;
        }
        amount = signed.abs();
      } else {
        amount = _bestMoney(row).abs();
      }

      if (amount <= 0.009) {
        skipped++;
        continue;
      }
      transactions.add(BankTransaction(id: _makeId(date, desc, amount), date: date, description: desc, amount: amount));
    }

    return _unique(transactions, rowsRead: dataRows.length, skipped: skipped);
  }

  static CsvImportResult _parseWithoutHeaders(List<List<dynamic>> rows) {
    final transactions = <BankTransaction>[];
    var skipped = 0;
    for (final row in rows) {
      if (row.isEmpty || row.every((e) => e.toString().trim().isEmpty)) continue;
      final dateText = _findDateCell(row);
      final date = _parseDate(dateText);
      final amount = _bestMoney(row).abs();
      final desc = _bestDescription(row, -1, 1);
      if (date == null || amount <= 0.009 || desc.isEmpty) {
        skipped++;
        continue;
      }
      transactions.add(BankTransaction(id: _makeId(date, desc, amount), date: date, description: desc, amount: amount));
    }
    return _unique(transactions, rowsRead: rows.length, skipped: skipped);
  }

  static CsvImportResult _unique(List<BankTransaction> transactions, {required int rowsRead, required int skipped}) {
    final unique = <String, BankTransaction>{};
    for (final tx in transactions) {
      unique[tx.id] = tx;
    }
    final sorted = unique.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    return CsvImportResult(transactions: sorted, rowsRead: rowsRead, rowsSkipped: skipped);
  }

  static int _scoreRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) return 0;
    final preview = rows.take(min(12, rows.length)).toList();
    final header = preview.map((r) => r.map((e) => _norm(e.toString())).join(' ')).join(' ');
    var score = preview.fold<int>(0, (sum, r) => sum + min(8, r.length));
    for (final word in ['date', 'amount', 'description', 'merchant', 'debit', 'credit', 'paid out', 'counterparty', 'completed']) {
      if (header.contains(word)) score += 12;
    }
    return score;
  }

  static int _headerIndex(List<List<dynamic>> rows) {
    for (var i = 0; i < min(rows.length, 16); i++) {
      final joined = rows[i].map((e) => _norm(e.toString())).join(' ');
      final hasDate = joined.contains('date') || joined.contains('time') || joined.contains('completed');
      final hasMoney = joined.contains('amount') || joined.contains('debit') || joined.contains('credit') || joined.contains('paid out') || joined.contains('money out') || joined.contains('value');
      if (hasDate && hasMoney) return i;
    }
    return 0;
  }

  static int _find(List<String> headers, List<String> options) {
    for (final option in options) {
      final needle = _norm(option);
      final idx = headers.indexWhere((h) => h == needle || h.contains(needle) || needle.contains(h));
      if (idx >= 0) return idx;
    }
    return -1;
  }

  static String _bestDescription(List<dynamic> row, int descIndex, int fallbackDesc) {
    final primary = _cell(row, descIndex >= 0 ? descIndex : fallbackDesc).trim();
    if (_looksLikeDescription(primary)) return primary;
    var best = '';
    for (final cell in row) {
      final value = cell.toString().trim();
      if (_looksLikeDescription(value) && value.length > best.length) best = value;
    }
    return best.isNotEmpty ? best : primary;
  }

  static bool _looksLikeDescription(String value) {
    if (value.length < 2) return false;
    if (_parseDate(value) != null) return false;
    if (RegExp(r'^[-+€£$0-9,./\s]+$').hasMatch(value)) return false;
    final lower = value.toLowerCase();
    if (['completed', 'declined', 'pending', 'card payment'].contains(lower)) return false;
    return true;
  }

  static String _findDateCell(List<dynamic> row) {
    for (final cell in row) {
      final value = cell.toString().trim();
      if (_parseDate(value) != null) return value;
    }
    return '';
  }

  static double _bestMoney(List<dynamic> row) {
    final values = <double>[];
    for (final cell in row) {
      final raw = cell.toString().trim();
      if (raw.isEmpty) continue;
      if (!RegExp(r'[-+€£$]?\s*\d+[\d,.]*').hasMatch(raw)) continue;
      final money = _parseMoney(raw);
      if (money != 0) values.add(money);
    }
    if (values.isEmpty) return 0;
    final negative = values.where((v) => v < 0).toList();
    if (negative.isNotEmpty) return negative.reduce((a, b) => a.abs() >= b.abs() ? a : b);
    return values.reduce((a, b) => a.abs() >= b.abs() ? a : b);
  }

  static String _cell(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].toString();
  }

  static String _norm(String value) => value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ');

  static double _parseMoney(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return 0;
    var negative = false;
    if (s.startsWith('(') && s.endsWith(')')) {
      negative = true;
      s = s.substring(1, s.length - 1);
    }
    if (s.contains('-')) negative = true;
    s = s.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (s.isEmpty || s == '-') return 0;
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    if (lastComma > lastDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
    final value = double.tryParse(s.replaceAll('-', '')) ?? 0;
    return negative ? -value : value;
  }

  static DateTime? _parseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    final match = RegExp(r'(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})').firstMatch(s);
    if (match != null) {
      final a = int.parse(match.group(1)!);
      final b = int.parse(match.group(2)!);
      var y = int.parse(match.group(3)!);
      if (y < 100) y += 2000;
      final day = a;
      final month = b;
      try { return DateTime(y, month, day); } catch (_) { return null; }
    }

    final monthMatch = RegExp(r'(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{2,4})').firstMatch(s);
    if (monthMatch != null) {
      final day = int.parse(monthMatch.group(1)!);
      final monthName = monthMatch.group(2)!.toLowerCase().substring(0, 3);
      var y = int.parse(monthMatch.group(3)!);
      if (y < 100) y += 2000;
      const months = {'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12};
      final m = months[monthName];
      if (m != null) {
        try { return DateTime(y, m, day); } catch (_) { return null; }
      }
    }
    return null;
  }

  static String _makeId(DateTime date, String description, double amount) {
    final clean = description.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${date.toIso8601String().substring(0, 10)}_${clean}_${amount.toStringAsFixed(2)}';
  }
}


class DailyWallet {
  final String dayKey;
  final double balance;
  final double spentToday;

  const DailyWallet({required this.dayKey, required this.balance, required this.spentToday});

  static String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static DateTime parseKey(String key) {
    final p = key.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static int daysBetween(String from, String to) {
    final a = parseKey(from);
    final b = parseKey(to);
    return b.difference(a).inDays;
  }

  static Future<DailyWallet> loadAndRoll(double dailyAmount) async {
    final p = await SharedPreferences.getInstance();
    final today = todayKey();
    final savedDay = p.getString('walletDay') ?? today;
    var balance = p.getDouble('walletBalance') ?? dailyAmount;
    var spentToday = p.getDouble('walletSpentToday') ?? 0;

    if (savedDay != today) {
      final days = max(1, daysBetween(savedDay, today));
      balance = max(0, balance) + (dailyAmount * days);
      spentToday = 0;
      await p.setString('walletDay', today);
      await p.setDouble('walletBalance', balance);
      await p.setDouble('walletSpentToday', spentToday);
    } else if (!p.containsKey('walletBalance')) {
      await p.setString('walletDay', today);
      await p.setDouble('walletBalance', balance);
      await p.setDouble('walletSpentToday', spentToday);
    }

    return DailyWallet(dayKey: today, balance: balance, spentToday: spentToday);
  }

  Future<DailyWallet> spend(double amount) async {
    final p = await SharedPreferences.getInstance();
    final newBalance = max(0, balance - amount).toDouble();
    final newSpent = spentToday + amount;
    await p.setString('walletDay', dayKey);
    await p.setDouble('walletBalance', newBalance);
    await p.setDouble('walletSpentToday', newSpent);
    return DailyWallet(dayKey: dayKey, balance: newBalance, spentToday: newSpent);
  }

  Future<DailyWallet> addProtected(double amount) async {
    final p = await SharedPreferences.getInstance();
    final newBalance = max(0, balance - amount).toDouble();
    await p.setDouble('walletBalance', newBalance);
    return DailyWallet(dayKey: dayKey, balance: newBalance, spentToday: spentToday);
  }

  static Future<void> resetWithDaily(double dailyAmount) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('walletDay', todayKey());
    await p.setDouble('walletBalance', dailyAmount);
    await p.setDouble('walletSpentToday', 0);
  }
}

class SpendingEntry {
  final double amount;
  final String place;
  final DateTime time;

  const SpendingEntry({required this.amount, required this.place, required this.time});

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'place': place,
        'time': time.toIso8601String(),
      };

  static SpendingEntry fromJson(Map<String, dynamic> json) => SpendingEntry(
        amount: ((json['amount'] ?? 0) as num).toDouble(),
        place: (json['place'] ?? 'Spending').toString(),
        time: DateTime.tryParse((json['time'] ?? '').toString()) ?? DateTime.now(),
      );

  static Future<List<SpendingEntry>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('spendingHistory') ?? [];
    return raw.map((e) {
      try {
        return SpendingEntry.fromJson(jsonDecode(e) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<SpendingEntry>().toList();
  }

  static Future<List<SpendingEntry>> add(SpendingEntry entry) async {
    final p = await SharedPreferences.getInstance();
    final current = await load();
    final updated = [entry, ...current].take(100).toList();
    await p.setStringList('spendingHistory', updated.map((e) => jsonEncode(e.toJson())).toList());
    return updated;
  }
}

class StoreInfo {
  final String name;
  final String category;
  final double lat;
  final double lng;
  final double distanceMeters;
  final int risk;

  const StoreInfo({
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    required this.risk,
  });

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

  double get triggerRadiusMeters {
    final n = name.toLowerCase();
    final c = category.toLowerCase();

    // Build 23: Inside-only mode.
    // Google Places gives the centre point of a shop, not the walls of the building.
    // These radii are intentionally tight so SpendGuard does not say "inside"
    // while the user is still outside or 100m+ away.
    if (n.contains('ikea') || n.contains('shopping centre') || n.contains('shopping center')) return 32;
    if (c.contains('home') || c.contains('furniture')) return 30;
    if (c.contains('grocer') || c.contains('supermarket')) return 22;
    if (c.contains('petrol') || c.contains('gas')) return 22;
    if (c.contains('food') || c.contains('coffee') || c.contains('restaurant')) return 18;
    if (c.contains('clothing') || c.contains('electronics') || c.contains('shopping')) return 22;
    return 20;
  }
}


class StoreVisual {
  final IconData icon;
  final String label;
  final Color color;
  final String emoji;

  const StoreVisual(this.icon, this.label, this.color, this.emoji);

  static StoreVisual fromStore(String name, String category) {
    final n = name.toLowerCase();
    final c = category.toLowerCase();

    bool any(List<String> words) => words.any((w) => n.contains(w));

    if (any(['tesco', 'lidl', 'aldi', 'spar', 'mace', 'centra', 'supervalu', 'dunnes', 'marks', 'm&s', 'waitrose', 'sainsbury', 'asda', 'morrisons', 'whole foods', 'trader joe', 'walmart', 'costco'])) {
      return const StoreVisual(Icons.local_grocery_store_rounded, 'Groceries', AppColors.green, '🛒');
    }
    if (any(['ikea', 'woodies', 'b&q', 'homebase', 'jysk', 'harvey norman', 'argos', 'home store', 'furniture', 'dfs'])) {
      return const StoreVisual(Icons.chair_rounded, 'Home & Furniture', AppColors.amber, '🛋️');
    }
    if (any(['currys', 'apple', 'pc world', 'best buy', 'cex', 'gamestop', 'phone shop', 'vodafone', 'three', 'eir', 'o2'])) {
      return const StoreVisual(Icons.devices_rounded, 'Electronics', AppColors.blue, '💻');
    }
    if (any(['zara', 'primark', 'penneys', 'h&m', 'tk maxx', 'next', 'river island', 'nike', 'adidas', 'jd sports', 'foot locker', 'pull&bear', 'bershka', 'mango', 'gucci', 'louis vuitton'])) {
      return const StoreVisual(Icons.checkroom_rounded, 'Clothing', AppColors.purple, '👕');
    }
    if (any(['starbucks', 'costa', 'nero', 'insomnia', 'pret', 'cafe', 'coffee'])) {
      return const StoreVisual(Icons.local_cafe_rounded, 'Coffee', AppColors.amber, '☕');
    }
    if (any(['mcdonald', 'burger king', 'kfc', 'subway', 'domino', 'pizza', 'restaurant', 'nando', 'five guys', 'burrito', 'sushi', 'takeaway', 'chipotle'])) {
      return const StoreVisual(Icons.restaurant_rounded, 'Food', AppColors.amber, '🍽️');
    }
    if (any(['maxol', 'circle k', 'esso', 'shell', 'bp', 'texaco', 'petrol', 'gas station', 'fuel'])) {
      return const StoreVisual(Icons.local_gas_station_rounded, 'Petrol', AppColors.teal, '⛽');
    }
    if (any(['boots', 'pharmacy', 'chemist', 'holland & barrett', 'health', 'superdrug'])) {
      return const StoreVisual(Icons.local_pharmacy_rounded, 'Health', AppColors.red, '💊');
    }
    if (any(['book', 'eason', 'waterstones', 'library'])) {
      return const StoreVisual(Icons.menu_book_rounded, 'Books', AppColors.blue, '📚');
    }
    if (any(['pet', 'pets', 'maxi zoo', 'petmania', 'veterinary', 'vet'])) {
      return const StoreVisual(Icons.pets_rounded, 'Pets', AppColors.amber, '🐾');
    }
    if (any(['cinema', 'movie', 'odeon', 'vue', 'imax', 'theatre', 'arcade', 'bowling'])) {
      return const StoreVisual(Icons.movie_rounded, 'Entertainment', AppColors.purple, '🎬');
    }
    if (any(['gym', 'fitness', 'puregym', 'flyefit', 'leisure', 'sport'])) {
      return const StoreVisual(Icons.fitness_center_rounded, 'Fitness', AppColors.green, '🏋️');
    }
    if (any(['hotel', 'airbnb', 'hostel', 'travelodge', 'hilton', 'marriott'])) {
      return const StoreVisual(Icons.hotel_rounded, 'Hotel', AppColors.blue, '🏨');
    }
    if (any(['airport', 'ryanair', 'aer lingus', 'flight', 'train station', 'luas', 'dart', 'bus station'])) {
      return const StoreVisual(Icons.flight_takeoff_rounded, 'Travel', AppColors.teal, '✈️');
    }
    if (any(['bank', 'atm', 'revolut', 'aib', 'boi', 'bank of ireland', 'credit union'])) {
      return const StoreVisual(Icons.account_balance_rounded, 'Banking', AppColors.green, '🏦');
    }

    if (c.contains('grocery')) return const StoreVisual(Icons.local_grocery_store_rounded, 'Groceries', AppColors.green, '🛒');
    if (c.contains('home')) return const StoreVisual(Icons.chair_rounded, 'Home & Furniture', AppColors.amber, '🛋️');
    if (c.contains('clothing')) return const StoreVisual(Icons.checkroom_rounded, 'Clothing', AppColors.purple, '👕');
    if (c.contains('electronic')) return const StoreVisual(Icons.devices_rounded, 'Electronics', AppColors.blue, '💻');
    if (c.contains('food') || c.contains('coffee')) return const StoreVisual(Icons.restaurant_rounded, 'Food & Coffee', AppColors.amber, '🍽️');
    if (c.contains('petrol')) return const StoreVisual(Icons.local_gas_station_rounded, 'Petrol', AppColors.teal, '⛽');
    if (c.contains('health')) return const StoreVisual(Icons.local_pharmacy_rounded, 'Health', AppColors.red, '💊');

    return const StoreVisual(Icons.storefront_rounded, 'Shopping', AppColors.teal, '🛍️');
  }
}

class RealStoreService {
  static bool get hasApiKey => googlePlacesApiKey.trim().isNotEmpty;
  static String lastDebug = 'Places not checked yet';

  static const Set<String> _shoppingTypes = {
    'store',
    'shopping_mall',
    'supermarket',
    'grocery_or_supermarket',
    'convenience_store',
    'department_store',
    'clothing_store',
    'electronics_store',
    'furniture_store',
    'home_goods_store',
    'hardware_store',
    'pharmacy',
    'book_store',
    'shoe_store',
    'jewelry_store',
    'pet_store',
    'bakery',
    'cafe',
    'restaurant',
    'meal_takeaway',
    'gas_station',
  };

  static const Set<String> _ignoreTypes = {
    'route',
    'locality',
    'political',
    'postal_code',
    'administrative_area_level_1',
    'administrative_area_level_2',
    'country',
    'parking',
    'lodging',
  };

  static Future<List<Map<String, dynamic>>> _nearbyPlaces(Position position, Map<String, String> extra, {required int radius}) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', {
      'location': '${position.latitude},${position.longitude}',
      'radius': radius.toString(),
      ...extra,
      'key': googlePlacesApiKey,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      lastDebug = 'Places HTTP ${response.statusCode}';
      return const [];
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final status = (decoded['status'] ?? 'UNKNOWN').toString();
    final error = (decoded['error_message'] ?? '').toString();
    final results = ((decoded['results'] as List?) ?? []).whereType<Map<String, dynamic>>().toList();

    if (status != 'OK' && status != 'ZERO_RESULTS') {
      lastDebug = error.isEmpty ? 'Places status: $status' : 'Places status: $status • $error';
      debugPrint('SpendGuard Places error: $lastDebug');
      return const [];
    }

    return results;
  }

  static Future<StoreInfo?> detectNearestStore(Position position, {double searchRadiusMeters = 95}) async {
    if (!hasApiKey) {
      lastDebug = 'Missing Google Places API key';
      return null;
    }

    final radius = searchRadiusMeters.round().clamp(45, 110);
    final all = <String, Map<String, dynamic>>{};

    Future<void> addResults(Map<String, String> params) async {
      final results = await _nearbyPlaces(position, params, radius: radius);
      for (final place in results) {
        final placeId = (place['place_id'] ?? place['name'] ?? DateTime.now().microsecondsSinceEpoch).toString();
        all[placeId] = place;
      }
    }

    try {
      // Multiple small searches work much better than one giant keyword query.
      await addResults({'keyword': 'supermarket grocery shop store'});
      await addResults({'keyword': 'tesco lidl aldi spar centra supervalu dunnes ikea maxol circle k'});
      await addResults({'type': 'store'});
      await addResults({'type': 'supermarket'});
      await addResults({'type': 'shopping_mall'});
      await addResults({'type': 'gas_station'});
      await addResults({'type': 'cafe'});
      await addResults({'type': 'restaurant'});
      await addResults({'type': 'pharmacy'});

      if (all.isEmpty) {
        lastDebug = 'No Places results within ${radius}m';
        return null;
      }

      Map<String, dynamic>? best;
      double bestDistance = double.infinity;
      double bestScore = double.infinity;
      var considered = 0;

      for (final place in all.values) {
        final location = (place['geometry'] as Map<String, dynamic>?)?['location'] as Map<String, dynamic>?;
        if (location == null) continue;

        final name = (place['name'] ?? '').toString();
        if (name.trim().isEmpty) continue;

        final types = ((place['types'] as List?) ?? []).map((e) => e.toString()).toSet();
        if (types.intersection(_ignoreTypes).isNotEmpty && types.intersection(_shoppingTypes).isEmpty && !_looksLikeKnownShop(name)) continue;
        if (types.intersection(_shoppingTypes).isEmpty && !_looksLikeKnownShop(name)) continue;

        final lat = (location['lat'] as num).toDouble();
        final lng = (location['lng'] as num).toDouble();
        final distance = Geolocator.distanceBetween(position.latitude, position.longitude, lat, lng);
        if (distance > radius) continue;
        considered++;

        var score = distance;
        if (_looksLikeKnownShop(name)) score -= 45;
        if (types.contains('supermarket') || types.contains('grocery_or_supermarket')) score -= 18;
        if (types.contains('gas_station')) score -= 10;
        if (types.contains('parking')) score += 70;
        if (types.contains('shopping_mall')) score += 8;

        if (score < bestScore) {
          bestScore = score;
          bestDistance = distance;
          best = place;
        }
      }

      if (best == null) {
        lastDebug = 'No shop inside entry rules • ${all.length} nearby place ignored';
        return null;
      }

      final location = (best['geometry'] as Map<String, dynamic>)['location'] as Map<String, dynamic>;
      final name = (best['name'] ?? 'Nearby store').toString();
      final types = ((best['types'] as List?) ?? []).map((e) => e.toString()).toList();
      final category = _categoryFromTypes(name, types);
      final risk = _riskForCategory(category, name);
      lastDebug = 'Places ok • ${all.length} results • $considered shops • best $name ${bestDistance.toStringAsFixed(0)}m';

      return StoreInfo(
        name: name,
        category: category,
        lat: (location['lat'] as num).toDouble(),
        lng: (location['lng'] as num).toDouble(),
        distanceMeters: bestDistance,
        risk: risk,
      );
    } catch (e) {
      lastDebug = 'Places failed: $e';
      debugPrint('Google Places detection failed: $e');
      return null;
    }
  }

  static bool _looksLikeKnownShop(String name) {
    final n = name.toLowerCase();
    const brands = [
      'ikea', 'tesco', 'lidl', 'aldi', 'spar', 'mace', 'centra', 'supervalu', 'dunnes',
      'maxol', 'circle k', 'apple', 'currys', 'boots', 'penneys', 'primark', 'zara',
      'hm', 'h&m', 'tk maxx', 'starbucks', 'costa', 'mcdonald', 'burger king', 'subway',
      'decathlon', 'woodies', 'b&q', 'next', 'marks', 'm&s', 'dealz', 'eurogiant',
      'harvey norman', 'jysk', 'argos', 'homebase', 'dfs', 'sainsbury', 'asda', 'morrisons',
      'waitrose', 'walmart', 'costco', 'whole foods', 'best buy', 'cex', 'gamestop',
      'vodafone', 'three', 'eir', 'nike', 'adidas', 'jd sports', 'foot locker',
      'pull&bear', 'bershka', 'mango', 'gucci', 'louis vuitton', 'coffee', 'cafe',
      'nero', 'insomnia', 'pret', 'kfc', 'domino', 'nando', 'five guys', 'sushi',
      'shell', 'bp', 'esso', 'texaco', 'pharmacy', 'chemist', 'superdrug', 'eason',
      'waterstones', 'petmania', 'maxi zoo', 'odeon', 'vue', 'puregym', 'flyefit'
    ];
    return brands.any(n.contains);
  }

  static String _categoryFromTypes(String name, List<String> types) {
    final n = name.toLowerCase();

    if (types.contains('gas_station') || n.contains('maxol') || n.contains('circle k') || n.contains('shell') || n.contains('bp') || n.contains('esso') || n.contains('texaco')) return 'Petrol';

    if (types.contains('grocery_or_supermarket') || types.contains('supermarket') || types.contains('convenience_store') ||
        n.contains('tesco') || n.contains('lidl') || n.contains('aldi') || n.contains('spar') || n.contains('mace') || n.contains('centra') ||
        n.contains('supervalu') || n.contains('dunnes') || n.contains('sainsbury') || n.contains('asda') || n.contains('morrisons') ||
        n.contains('waitrose') || n.contains('walmart') || n.contains('costco') || n.contains('whole foods')) return 'Groceries';

    if (types.contains('furniture_store') || types.contains('home_goods_store') || types.contains('hardware_store') ||
        n.contains('ikea') || n.contains('woodies') || n.contains('b&q') || n.contains('homebase') || n.contains('jysk') ||
        n.contains('harvey norman') || n.contains('argos') || n.contains('dfs')) return 'Home';

    if (types.contains('clothing_store') || types.contains('shoe_store') ||
        n.contains('zara') || n.contains('primark') || n.contains('penneys') || n.contains('h&m') || n.contains('tk maxx') ||
        n.contains('next') || n.contains('river island') || n.contains('nike') || n.contains('adidas') || n.contains('jd sports') ||
        n.contains('foot locker') || n.contains('pull&bear') || n.contains('bershka') || n.contains('mango')) return 'Clothing';

    if (types.contains('electronics_store') || n.contains('currys') || n.contains('apple') || n.contains('best buy') || n.contains('cex') ||
        n.contains('gamestop') || n.contains('vodafone') || n.contains('three') || n.contains('eir')) return 'Electronics';

    if (types.contains('restaurant') || types.contains('bakery') || types.contains('meal_takeaway') ||
        n.contains('mcdonald') || n.contains('burger king') || n.contains('kfc') || n.contains('subway') ||
        n.contains('domino') || n.contains('nando') || n.contains('five guys') || n.contains('sushi')) return 'Food';

    if (types.contains('cafe') || n.contains('starbucks') || n.contains('costa') || n.contains('nero') || n.contains('insomnia') || n.contains('pret') || n.contains('coffee')) return 'Coffee';

    if (types.contains('pharmacy') || n.contains('boots') || n.contains('chemist') || n.contains('superdrug') || n.contains('holland & barrett')) return 'Health';

    if (types.contains('book_store') || n.contains('eason') || n.contains('waterstones') || n.contains('book')) return 'Books';
    if (types.contains('pet_store') || n.contains('petmania') || n.contains('maxi zoo') || n.contains('pet')) return 'Pets';
    if (n.contains('cinema') || n.contains('odeon') || n.contains('vue') || n.contains('movie') || n.contains('arcade')) return 'Entertainment';
    if (n.contains('gym') || n.contains('puregym') || n.contains('flyefit') || n.contains('fitness')) return 'Fitness';
    if (n.contains('hotel') || n.contains('travelodge') || n.contains('hilton') || n.contains('marriott')) return 'Hotel';
    if (types.contains('shopping_mall') || n.contains('shopping centre') || n.contains('shopping center') || n.contains('mall')) return 'Shopping Mall';

    return 'Shopping';
  }

  static int _riskForCategory(String category, String name) {
    final n = name.toLowerCase();
    if (n.contains('apple') || n.contains('currys') || n.contains('best buy')) return 86;
    if (n.contains('ikea') || n.contains('harvey norman') || n.contains('dfs')) return 82;
    if (n.contains('zara') || n.contains('primark') || n.contains('nike') || n.contains('adidas')) return 66;

    switch (category) {
      case 'Groceries':
        return 25;
      case 'Health':
        return 35;
      case 'Petrol':
        return 42;
      case 'Coffee':
        return 40;
      case 'Food':
        return 48;
      case 'Books':
        return 35;
      case 'Pets':
        return 45;
      case 'Fitness':
        return 38;
      case 'Hotel':
      case 'Travel':
        return 70;
      case 'Entertainment':
        return 58;
      case 'Clothing':
        return 62;
      case 'Home':
        return 72;
      case 'Electronics':
        return 86;
      case 'Shopping Mall':
        return 68;
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

  String message(BudgetData budget, AppLanguage language) {
    final prefix = budget.userName.trim().isEmpty ? '' : '${budget.userName.trim()}, ';
    final dream = budget.dreamName.isEmpty ? (language == AppLanguage.it ? 'il tuo obiettivo' : 'your dream') : budget.dreamName;

    if (language == AppLanguage.it) {
      if (stop || safeAmount <= 0) return '${prefix}STOP. Proteggi $dream oggi.';
      return '${prefix}sei da ${store.name}. Ti restano €${safeAmount.toStringAsFixed(2)}. Spendere di più può ritardare $dream di $delayDays giorno/i.';
    }

    if (stop || safeAmount <= 0) return '${prefix}STOP. Protect $dream today.';
    return '${prefix}you are at ${store.name}. You have €${safeAmount.toStringAsFixed(2)} left. Extra spending could delay $dream by $delayDays day(s).';
  }
}

class StoreVisit {
  final String storeName;
  final String category;
  final double safeAmount;
  final double distanceMeters;
  final DateTime time;

  const StoreVisit({required this.storeName, required this.category, required this.safeAmount, required this.distanceMeters, required this.time});

  Map<String, dynamic> toJson() => {
        'storeName': storeName,
        'category': category,
        'safeAmount': safeAmount,
        'distanceMeters': distanceMeters,
        'time': time.toIso8601String(),
      };

  static StoreVisit fromJson(Map<String, dynamic> json) => StoreVisit(
        storeName: (json['storeName'] ?? 'Store').toString(),
        category: (json['category'] ?? 'Shopping').toString(),
        safeAmount: ((json['safeAmount'] ?? 0) as num).toDouble(),
        distanceMeters: ((json['distanceMeters'] ?? 0) as num).toDouble(),
        time: DateTime.tryParse((json['time'] ?? '').toString()) ?? DateTime.now(),
      );

  static Future<List<StoreVisit>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('storeVisitHistory') ?? [];
    return raw.map((e) {
      try {
        return StoreVisit.fromJson(jsonDecode(e) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<StoreVisit>().toList();
  }

  static Future<List<StoreVisit>> add(StoreVisit visit) async {
    final p = await SharedPreferences.getInstance();
    final current = await load();
    final alreadySaved = current.isNotEmpty && current.first.storeName == visit.storeName && DateTime.now().difference(current.first.time).inMinutes < 15;
    final updated = alreadySaved ? current : [visit, ...current].take(60).toList();
    await p.setStringList('storeVisitHistory', updated.map((e) => jsonEncode(e.toJson())).toList());
    return updated;
  }
}

class NotificationPrefs {
  final bool onEnter;
  final bool onExit;

  const NotificationPrefs({required this.onEnter, required this.onExit});

  static const defaults = NotificationPrefs(onEnter: true, onExit: true);

  NotificationPrefs copyWith({bool? onEnter, bool? onExit}) {
    return NotificationPrefs(onEnter: onEnter ?? this.onEnter, onExit: onExit ?? this.onExit);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notifyOnEnter', onEnter);
    await p.setBool('notifyOnExit', onExit);
  }

  static Future<NotificationPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    return NotificationPrefs(
      onEnter: p.getBool('notifyOnEnter') ?? defaults.onEnter,
      onExit: p.getBool('notifyOnExit') ?? defaults.onExit,
    );
  }
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
    controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(seconds: 2));
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
    final lang = AppLanguageScope.of(context).language;
    final title = 'SpendGuard';
    final subtitle = lang == AppLanguage.it ? 'Proteggi il futuro prima di spendere.' : 'Protect your future before you spend.';

    return Scaffold(
      body: V6SplashBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final v = Curves.easeOutCubic.transform(controller.value);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 34),
                child: Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - v)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 42,
                            height: 1.02,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 16,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                Text(
                  greetingTitle(context),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 42, height: 1.04, fontWeight: FontWeight.w900, letterSpacing: -1.5),
                ),
                const SizedBox(height: 14),
                Text(
                  tr(context, 'about'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.45, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 26),
                const _OnboardingPoint(icon: Icons.account_balance_wallet_rounded, text: 'Know what is safe today'),
                const _OnboardingPoint(icon: Icons.flag_rounded, text: 'Keep your goals visible'),
                const _OnboardingPoint(icon: Icons.receipt_long_rounded, text: 'Import spending from CSV'),
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

class _OnboardingPoint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _OnboardingPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int index = 0;
  bool loading = true;
  bool gpsReady = false;
  String gpsStatus = 'Location not checked';
  String currentStore = 'No store detected';
  BudgetData budget = BudgetData.empty;
  DailyWallet wallet = const DailyWallet(dayKey: '', balance: 0, spentToday: 0);
  StoreDecision? decision;
  NotificationPrefs notificationPrefs = NotificationPrefs.defaults;
  StreamSubscription<Position>? locationSub;
  bool _isAppForeground = true;
  String? _lastSmartNotificationKey;
  DateTime? _lastSmartNotificationAt;
  String? lastNotifiedStore;
  DateTime? lastNotificationAt;
  String? activeStoreName;
  String? pendingInsideStore;
  int pendingInsideCount = 0;
  List<StoreVisit> visitHistory = const [];
  List<SpendingEntry> spendingHistory = const [];
  List<BankTransaction> bankTransactions = const [];
  List<DreamGoal> goals = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(NotificationService.requestPermissions());
    unawaited(NativeGeofenceService.requestAlwaysPermission());
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    locationSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state == AppLifecycleState.resumed;
  }

  bool _canSendSmartNotification(String key, {Duration cooldown = const Duration(seconds: 60)}) {
    final now = DateTime.now();
    if (_lastSmartNotificationKey == key &&
        _lastSmartNotificationAt != null &&
        now.difference(_lastSmartNotificationAt!) < cooldown) {
      return false;
    }
    _lastSmartNotificationKey = key;
    _lastSmartNotificationAt = now;
    return true;
  }

  String _notificationKey(String type, String storeName) {
    final clean = storeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    return '${type}_$clean';
  }

  void _showInAppBanner(String title, String body) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        backgroundColor: AppColors.card2,
        content: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withOpacity(0.26)),
              ),
              child: const Text('S', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.text)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _sendSmartNotification(
    String key,
    String title,
    String body, {
    Duration cooldown = const Duration(seconds: 60),
    bool forceSystemNotification = false,
  }) async {
    if (!_canSendSmartNotification(key, cooldown: cooldown)) {
      NotificationService.lastDebug = 'Duplicate blocked by SpendGuard anti-duplicate guard: $key';
      return false;
    }

    if (_isAppForeground && !forceSystemNotification) {
      _showInAppBanner(title, body);
      NotificationService.lastDebug = 'App open: shown as SpendGuard in-app banner, not as iOS system notification.';
      return true;
    }

    return NotificationService.show(title, body);
  }

  Future<void> _load() async {
    final data = await BudgetData.load();
    final prefs = await NotificationPrefs.load();
    final visits = await StoreVisit.load();
    final spends = await SpendingEntry.load();
    final loadedBankTransactions = await BankTransaction.loadImported();
    final loadedGoals = await DreamGoal.loadAll(data);
    final loadedWallet = await DailyWallet.loadAndRoll(data.dailySafeBase);
    if (!mounted) return;
    setState(() {
      budget = data;
      notificationPrefs = prefs;
      visitHistory = visits;
      spendingHistory = spends;
      bankTransactions = loadedBankTransactions;
      goals = loadedGoals;
      wallet = loadedWallet;
      loading = false;
    });
    if (loadedGoals.isNotEmpty) {
      await _applyAutomaticPrimary(loadedGoals);
    }
    unawaited(checkLocation());
    if (widget.openSetup || !data.isReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSetup();
      });
    }
  }

  StoreDecision decisionFor(StoreInfo store) {
    double adjusted = wallet.balance;
    if (store.risk >= 75) {
      adjusted = wallet.balance * 0.55;
    } else if (store.risk >= 45) {
      adjusted = wallet.balance * 0.80;
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

  Future<void> _sendExitAlert(String leavingStore) async {
    activeStoreName = null;
    pendingInsideStore = null;
    pendingInsideCount = 0;
    lastNotifiedStore = null;
    lastNotificationAt = null;
    if (!notificationPrefs.onExit) return;
    final exitBody = budget.userName.trim().isEmpty
        ? 'You left $leavingStore. Your remaining Safe Spend is €${wallet.balance.toStringAsFixed(2)}.'
        : '${budget.userName}, you left $leavingStore. Your remaining Safe Spend is €${wallet.balance.toStringAsFixed(2)}.';
    final sent = await _sendSmartNotification(
      _notificationKey('exit', leavingStore),
      'SpendGuard • Exit',
      exitBody,
    );
    if (mounted) {
      setState(() {
        gpsStatus = '${sent ? 'Exit notification sent' : 'Exit notification blocked'} • $leavingStore';
      });
    }
  }

  Future<void> testNotificationNow() async {
    HapticFeedback.heavyImpact();
    final ok = await NotificationService.showTestSequence();
    if (!mounted) return;

    final isIt = AppLanguageScope.of(context).language == AppLanguage.it;
    setState(() {
      gpsStatus = ok
          ? (isIt
              ? 'Test avviato: una notifica subito + una dopo 5 secondi. Blocca lo schermo ora. Debug: ${NotificationService.lastDebug}'
              : 'Test started: one notification now + one after 5 seconds. Lock the screen now. Debug: ${NotificationService.lastDebug}')
          : (isIt
              ? 'Notifica bloccata da iOS. Debug: ${NotificationService.lastDebug}'
              : 'Notification blocked by iOS. Debug: ${NotificationService.lastDebug}');
    });

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(isIt ? 'Diagnosi notifiche' : 'Notification diagnostic'),
        content: Text(
          ok
              ? (isIt
                  ? 'Ho mandato una notifica immediata e una seconda tra 5 secondi. Blocca subito l’iPhone. Se non arriva nemmeno quella, il codice sta chiamando iOS ma il telefono blocca i banner. Vai in Settings > Notifications > SpendGuard e attiva Allow Notifications, Lock Screen, Notification Centre, Banners e Sounds. Disattiva anche Focus/Do Not Disturb.'
                  : 'I sent one notification now and a second one after 5 seconds. Lock the iPhone now. If neither arrives, the code is calling iOS but the phone is hiding the banners. Go to Settings > Notifications > SpendGuard and enable Allow Notifications, Lock Screen, Notification Centre, Banners and Sounds. Also disable Focus/Do Not Disturb.')
              : (isIt
                  ? 'iOS ha rifiutato la notifica. Cancella l’app, reinstallala e accetta il popup notifiche, oppure abilitala da Settings > Notifications > SpendGuard.'
                  : 'iOS refused the notification. Delete the app, reinstall it and accept the notification popup, or enable it from Settings > Notifications > SpendGuard.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> handlePosition(Position position, {bool force = false}) async {
    final store = await RealStoreService.detectNearestStore(position, searchRadiusMeters: 75);
    if (!mounted) return;

    if (store == null) {
      final leavingStore = activeStoreName;
      if (leavingStore != null) {
        await _sendExitAlert(leavingStore);
      }
      if (!mounted) return;
      setState(() {
        gpsReady = true;
        currentStore = tr(context, 'noStore');
        gpsStatus = 'Outside stores • accuracy ${position.accuracy.toStringAsFixed(0)}m • ${RealStoreService.lastDebug}';
        decision = null;
      });
      return;
    }

    // Build 23 Notification Diagnostic Mode:
    // Google Places may find shops nearby, but SpendGuard only says "inside" after
    // the phone is very close to the shop point. Stream updates require confirmation
    // to avoid false entry alerts while walking past or sitting at home nearby.
    final accuracyBoost = position.accuracy <= 10 ? 2.0 : position.accuracy <= 25 ? 4.0 : 0.0;
    final entryRadius = min(34.0, store.triggerRadiusMeters + accuracyBoost);
    final exitRadius = entryRadius + 14.0;
    final gpsAccurateEnough = position.accuracy <= 45;
    final insideCandidate = gpsAccurateEnough && store.distanceMeters <= entryRadius;
    final isOutsideExitZone = !gpsAccurateEnough || store.distanceMeters > exitRadius;
    final d = decisionFor(store);

    if (!insideCandidate) {
      pendingInsideStore = null;
      pendingInsideCount = 0;
      final leavingStore = activeStoreName;
      if (leavingStore != null && (isOutsideExitZone || leavingStore != store.name)) {
        await _sendExitAlert(leavingStore);
      }
      if (!mounted) return;
      setState(() {
        gpsReady = true;
        currentStore = tr(context, 'noStore');
        gpsStatus = 'Outside stores • closest ${store.name} ${store.distanceMeters.toStringAsFixed(0)}m / enter ${entryRadius.toStringAsFixed(0)}m • accuracy ${position.accuracy.toStringAsFixed(0)}m • ${RealStoreService.lastDebug}';
        decision = null;
      });
      return;
    }

    if (activeStoreName != store.name) {
      if (pendingInsideStore == store.name) {
        pendingInsideCount += 1;
      } else {
        pendingInsideStore = store.name;
        pendingInsideCount = 1;
      }

      final confirmedInside = force || pendingInsideCount >= 2;
      if (!confirmedInside) {
        if (!mounted) return;
        setState(() {
          gpsReady = true;
          currentStore = tr(context, 'noStore');
          gpsStatus = 'At entrance of ${store.name} • confirming inside (${pendingInsideCount}/2) • ${store.distanceMeters.toStringAsFixed(0)}m / enter ${entryRadius.toStringAsFixed(0)}m • accuracy ${position.accuracy.toStringAsFixed(0)}m';
          decision = null;
        });
        return;
      }
    }

    final isNewStore = activeStoreName != store.name;
    activeStoreName = store.name;
    unawaited(NativeGeofenceService.startMonitoringStore(store));
    pendingInsideStore = null;
    pendingInsideCount = 0;

    setState(() {
      gpsReady = true;
      currentStore = store.name;
      gpsStatus = 'Inside ${store.name} • ${store.distanceMeters.toStringAsFixed(0)}m / enter ${entryRadius.toStringAsFixed(0)}m • accuracy ${position.accuracy.toStringAsFixed(0)}m • ${RealStoreService.lastDebug}';
      decision = d;
    });

    final updatedVisits = await StoreVisit.add(StoreVisit(
      storeName: store.name,
      category: store.category,
      safeAmount: d.safeAmount,
      distanceMeters: store.distanceMeters,
      time: DateTime.now(),
    ));
    if (mounted) setState(() => visitHistory = updatedVisits);

    final now = DateTime.now();
    final cooldownPassed = lastNotificationAt == null || now.difference(lastNotificationAt!).inMinutes >= 4;
    final shouldSendEnterAlert = notificationPrefs.onEnter && (isNewStore || lastNotifiedStore != store.name || cooldownPassed);

    if (!notificationPrefs.onEnter && mounted) {
      setState(() => gpsStatus = 'Inside ${store.name} • entry alerts are OFF in Settings');
      return;
    }

    if (shouldSendEnterAlert) {
      lastNotifiedStore = store.name;
      lastNotificationAt = now;
      HapticFeedback.selectionClick();
      final sent = await _sendSmartNotification(
        _notificationKey('entry', store.name),
        'SpendGuard • ${store.name}',
        d.message(budget, AppLanguageScope.of(context).language),
      );
      if (mounted) {
        setState(() {
          gpsStatus = '${sent ? 'Entry notification sent' : 'Entry notification blocked: iPhone Settings > SpendGuard > Notifications'} • ${store.name} • ${store.distanceMeters.toStringAsFixed(0)}m / enter ${entryRadius.toStringAsFixed(0)}m • accuracy ${position.accuracy.toStringAsFixed(0)}m';
        });
      }
    }
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

    final notificationsOk = await NotificationService.requestPermissions();

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => gpsStatus = 'Turn on location services');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.whileInUse) {
      // Ask once more so iOS can upgrade to Always when the project Info.plist supports it.
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => gpsStatus = 'Location permission denied. Enable Location Always in iPhone Settings.');
      return;
    }

    setState(() {
      gpsStatus = 'Checking shops nearby… location $permission • notifications ${notificationsOk ? 'on' : 'blocked'}';
    });

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, timeLimit: Duration(seconds: 14)),
    );
    await handlePosition(position, force: true);

    await locationSub?.cancel();
    locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 2),
    ).listen(
      (p) => unawaited(handlePosition(p)),
      onError: (e) {
        if (mounted) setState(() => gpsStatus = 'GPS stream error: $e');
      },
    );
  }

  BudgetData _budgetFromGoal(DreamGoal goal) => budget.copyWith(
        dreamName: goal.name,
        dreamTarget: goal.target,
        dreamSaved: goal.saved,
        dreamMonths: goal.months,
        dreamVault: goal.vault,
        dreamStartDay: goal.startDay,
        dreamDayAdjustment: goal.dayAdjustment,
      );

  Future<void> _applyAutomaticPrimary(List<DreamGoal> updatedGoals) async {
    final clean = DreamGoal.sortByClosestGoal(updatedGoals).take(5).toList();
    await DreamGoal.saveAll(clean);
    BudgetData nextBudget = budget;
    if (clean.isNotEmpty) {
      final primary = clean.first;
      nextBudget = _budgetFromGoal(primary);
      await nextBudget.save();
    }
    if (!mounted) return;
    setState(() {
      goals = clean;
      budget = nextBudget;
    });
  }

  Future<void> _saveGoals(List<DreamGoal> updatedGoals) async {
    await _applyAutomaticPrimary(updatedGoals);
  }

  Future<void> _syncPrimaryGoal(BudgetData updatedBudget) async {
    final primary = DreamGoal.fromBudget(updatedBudget);
    final updatedGoals = goals.isEmpty ? [primary] : [primary, ...goals.skip(1)];
    await _applyAutomaticPrimary(updatedGoals);
  }

  Future<void> addGoal(DreamGoal goal) async {
    if (goals.length >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'maxGoalsReached'))));
      }
      return;
    }
    final updatedGoals = [...goals, goal.copyWith(primary: false)];
    await _saveGoals(updatedGoals);
  }

  Future<void> setPrimaryGoal(DreamGoal selected) async {
    if (selected.primary || selected.id == 'primary') return;

    final oldPrimary = DreamGoal.fromBudget(budget).copyWith(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      primary: false,
    );

    final updatedBudget = budget.copyWith(
      dreamName: selected.name,
      dreamTarget: selected.target,
      dreamSaved: selected.saved,
      dreamMonths: selected.months,
      dreamVault: selected.vault,
      dreamStartDay: selected.startDay,
      dreamDayAdjustment: selected.dayAdjustment,
    );
    await updatedBudget.save();

    final newPrimary = DreamGoal.fromBudget(updatedBudget);
    final rest = goals.where((g) => g.id != selected.id && g.id != 'primary').toList();
    final updatedGoals = [
      newPrimary,
      if (oldPrimary.name.trim().isNotEmpty || oldPrimary.target > 0) oldPrimary,
      ...rest,
    ].take(5).toList();

    await DreamGoal.saveAll(updatedGoals);
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      budget = updatedBudget;
      goals = updatedGoals;
    });
  }

  Future<void> deleteGoal(DreamGoal selected) async {
    if (goals.isEmpty) return;

    if (selected.primary && goals.length <= 1) {
      await DreamGoal.saveAll(const []);
      final cleared = budget.copyWith(
        dreamName: '',
        dreamTarget: 0,
        dreamSaved: 0,
        dreamMonths: 0,
        dreamVault: 0,
        dreamStartDay: BudgetData.todayKey(),
        dreamDayAdjustment: 0,
      );
      await cleared.save();
      if (!mounted) return;
      setState(() {
        budget = cleared;
        goals = const [];
      });
      return;
    }

    final remaining = goals.where((g) => g.id != selected.id).toList();

    if (selected.primary && remaining.isNotEmpty) {
      final next = DreamGoal.sortByClosestGoal(remaining).first;
      final updatedBudget = budget.copyWith(
        dreamName: next.name,
        dreamTarget: next.target,
        dreamSaved: next.saved,
        dreamMonths: next.months,
        dreamVault: next.vault,
        dreamStartDay: next.startDay,
        dreamDayAdjustment: next.dayAdjustment,
      );
      await updatedBudget.save();
      final newPrimary = DreamGoal.fromBudget(updatedBudget);
      final clean = [newPrimary, ...remaining.skip(1).map((g) => g.copyWith(primary: false))].take(5).toList();
      await DreamGoal.saveAll(clean);
      if (!mounted) return;
      setState(() {
        budget = updatedBudget;
        goals = clean;
      });
      return;
    }

    final clean = remaining.map((g) => g.copyWith(primary: g.id == 'primary')).take(5).toList();
    await DreamGoal.saveAll(clean);
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() => goals = clean);
  }

  void _openAddGoal() {
    if (goals.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'maxGoalsReached'))));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => AddGoalSheet(onSave: addGoal),
    );
  }

  Future<void> addSpending(double amount, String place) async {
    if (amount <= 0) return;
    final impactDays = budget.impactDaysFor(amount);
    final updatedWallet = await wallet.spend(amount);
    final updatedBudget = budget.applySpendingToDream(amount);
    await updatedBudget.save();
    final syncedGoals = goals.isEmpty ? <DreamGoal>[DreamGoal.fromBudget(updatedBudget)] : [DreamGoal.fromBudget(updatedBudget), ...goals.skip(1).map((g) => g.applySpending(amount))];
    await DreamGoal.saveAll(syncedGoals);
    final updatedHistory = await SpendingEntry.add(SpendingEntry(amount: amount, place: place.trim().isEmpty ? currentStore : place.trim(), time: DateTime.now()));
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      wallet = updatedWallet;
      budget = updatedBudget;
      spendingHistory = updatedHistory;
      goals = syncedGoals.take(5).toList();
    });
    await NotificationService.show(
      'Dream Impact ${formatDaysHuman(impactDays, signed: true)}',
      budget.userName.trim().isEmpty
          ? '€${amount.toStringAsFixed(2)} spent. ${updatedBudget.dreamDaysRemainingLongLabel} remaining for ${updatedBudget.dreamName.ifEmpty('your dream')}.'
          : '${budget.userName}, €${amount.toStringAsFixed(2)} spent. ${updatedBudget.dreamDaysRemainingLongLabel} remaining for ${updatedBudget.dreamName.ifEmpty('your dream')}.',
    );
  }

  Future<void> protectMoney(double amount, String reason) async {
    if (amount <= 0) return;
    final impactDays = budget.impactDaysFor(amount);
    final updatedBudget = budget.applyProtectionToDream(amount);
    final updatedWallet = await wallet.addProtected(amount);
    await updatedBudget.save();
    final syncedGoals = goals.isEmpty ? <DreamGoal>[DreamGoal.fromBudget(updatedBudget)] : [DreamGoal.fromBudget(updatedBudget), ...goals.skip(1).map((g) => g.applyProtection(amount))];
    await DreamGoal.saveAll(syncedGoals);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      budget = updatedBudget;
      wallet = updatedWallet;
      goals = syncedGoals.take(5).toList();
    });
    await NotificationService.show(
      'Dream Impact -${formatDaysHuman(impactDays)}',
      budget.userName.trim().isEmpty
          ? '€${amount.toStringAsFixed(2)} moved to your Dream Vault. ${updatedBudget.dreamDaysRemainingLongLabel} remaining.'
          : '${budget.userName}, €${amount.toStringAsFixed(2)} moved to your Dream Vault. ${updatedBudget.dreamDaysRemainingLongLabel} remaining.',
    );
  }


  Future<void> importBankStatement() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        allowMultiple: false,
        withData: true,
        withReadStream: true,
      );

      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.single;
      Uint8List? bytes = pickedFile.bytes;
      if (bytes == null && pickedFile.readStream != null) {
        final chunks = <int>[];
        await for (final chunk in pickedFile.readStream!) {
          chunks.addAll(chunk);
        }
        bytes = Uint8List.fromList(chunks);
      }
      if ((bytes == null || bytes.isEmpty) && pickedFile.path != null) {
        bytes = await File(pickedFile.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read the selected statement. Try exporting it as CSV and saving it in Files.')));
        return;
      }

      final parsed = CsvBankParser.parseBytes(bytes);
      final existingIds = bankTransactions.map((e) => e.id).toSet();
      final newTransactions = parsed.transactions.where((tx) => !existingIds.contains(tx.id)).toList();

      if (newTransactions.isEmpty) {
        if (!mounted) return;
        final message = parsed.rowsRead == 0
            ? 'SpendGuard opened the file, but no expenses were recognised. Use the bank CSV export, not PDF or Excel. It can read Date, Description/Merchant and Amount/Debit columns.'
            : 'No new transactions found. ${parsed.rowsRead} rows checked, ${parsed.transactions.length} expenses recognised.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final totalSpend = newTransactions.fold<double>(0, (sum, tx) => sum + tx.amount);
      final updatedWallet = await wallet.spend(totalSpend);
      final updatedBudget = budget.applySpendingToDream(totalSpend);
      await updatedBudget.save();

      final syncedGoals = goals.isEmpty
          ? <DreamGoal>[DreamGoal.fromBudget(updatedBudget)]
          : [DreamGoal.fromBudget(updatedBudget), ...goals.skip(1).map((g) => g.applySpending(totalSpend))];
      await DreamGoal.saveAll(syncedGoals);

      final spendingEntries = newTransactions.map((tx) => SpendingEntry(amount: tx.amount, place: tx.merchant, time: tx.date)).toList();
      final updatedSpendingHistory = [...spendingEntries, ...spendingHistory].take(100).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('spendingHistory', updatedSpendingHistory.map((e) => jsonEncode(e.toJson())).toList());

      final updatedBankTransactions = [...newTransactions, ...bankTransactions]..sort((a, b) => b.date.compareTo(a.date));
      await BankTransaction.saveImported(updatedBankTransactions);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        wallet = updatedWallet;
        budget = updatedBudget;
        goals = syncedGoals.take(5).toList();
        spendingHistory = updatedSpendingHistory;
        bankTransactions = updatedBankTransactions.take(500).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newTransactions.length} ${tr(context, 'newTransactions')} • €${totalSpend.toStringAsFixed(2)} updated'),
        ),
      );
    } catch (e) {
      debugPrint('CSV import failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV import failed: $e')));
    }
  }

  void _openSetup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SetupSheet(
        budget: budget,
        onSave: (b) async {
          final oldDaily = budget.dailySafeBase;
          await b.save();
          if ((oldDaily - b.dailySafeBase).abs() > 0.01) await DailyWallet.resetWithDaily(b.dailySafeBase);
          final newWallet = await DailyWallet.loadAndRoll(b.dailySafeBase);

          // Close the setup sheet before rebuilding the parent screen.
          // This prevents Flutter's _dependents.isEmpty assertion when saving a goal.
          if (sheetContext.mounted) Navigator.pop(sheetContext);
          if (!mounted) return;

          setState(() {
            budget = b;
            wallet = newWallet;
          });
          await _syncPrimaryGoal(b);
        },
      ),
    );
  }

  void _openSpending() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SpendingSheet(currentStore: currentStore, onSave: addSpending),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final pages = [
      HomeScreen(
        budget: budget,
        wallet: wallet,
        currentStore: currentStore,
        gpsStatus: gpsStatus,
        decision: decision,
        onGps: checkLocation,
        onSetup: _openSetup,
        onAddSpending: _openSpending,
        onProtectMoney: protectMoney,
        goals: goals,
        onSelectPrimaryGoal: setPrimaryGoal,
        onDeleteGoal: deleteGoal,
        onSettings: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(
                budget: budget,
                notificationPrefs: notificationPrefs,
                onPrefsChanged: updateNotificationPrefs,
                onSetup: _openSetup,
                goals: goals,
              ),
            ),
          );
        },
        onHelp: () {
          HapticFeedback.selectionClick();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
        },
      ),
      StoresScreen(currentStore: currentStore, gpsStatus: gpsStatus, gpsReady: gpsReady, decision: decision, onGps: checkLocation, visits: visitHistory),
      InsightsScreen(budget: budget, wallet: wallet, spendingHistory: spendingHistory, visits: visitHistory, goals: goals, onAddGoal: _openAddGoal, onSelectPrimaryGoal: setPrimaryGoal, onDeleteGoal: deleteGoal),
      AccountsScreen(transactions: bankTransactions, onImportCsv: importBankStatement, wallet: wallet, budget: budget),
    ];
    if (index > pages.length - 1) index = 0;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: pages[index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: index,
        onDestinationSelected: (v) {
          HapticFeedback.selectionClick();
          setState(() => index = v);
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded, color: AppColors.gold), label: tr(context, 'home')),
          NavigationDestination(icon: const Icon(Icons.storefront_outlined), selectedIcon: const Icon(Icons.storefront_rounded, color: AppColors.gold), label: tr(context, 'stores')),
          NavigationDestination(icon: const Icon(Icons.insights_outlined), selectedIcon: const Icon(Icons.insights_rounded, color: AppColors.gold), label: tr(context, 'insights')),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), selectedIcon: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.gold), label: tr(context, 'accounts')),
        ],
      ),
    );
  }
}

class _FloatingUtilityRail extends StatelessWidget {
  final VoidCallback onGps;
  final VoidCallback onSettings;
  final VoidCallback onHelp;

  const _FloatingUtilityRail({
    required this.onGps,
    required this.onSettings,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppScrollStyle.paletteOf(context);
    final isItalian = AppLanguageScope.of(context).language == AppLanguage.it;

    Widget button({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onPressed,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.26),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: palette.accentSoft.withOpacity(0.16),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: palette.accentSoft, size: 18),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: TextStyle(
                            color: palette.accentSoft.withOpacity(0.82),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(icon: Icons.my_location_rounded, label: 'GPS', onPressed: onGps),
        button(icon: Icons.settings_rounded, label: isItalian ? 'Imp.' : 'Set', onPressed: onSettings),
        button(icon: Icons.question_mark_rounded, label: isItalian ? '?' : 'Help', onPressed: onHelp),
      ],
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
  late final TextEditingController name;
  late final TextEditingController income;
  late final TextEditingController expenses;
  late final TextEditingController dream;
  late final TextEditingController target;
  late final TextEditingController saved;
  late final TextEditingController months;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.budget.userName);
    income = TextEditingController(text: widget.budget.income > 0 ? widget.budget.income.toStringAsFixed(0) : '');
    expenses = TextEditingController(text: widget.budget.fixedExpenses > 0 ? widget.budget.fixedExpenses.toStringAsFixed(0) : '');
    dream = TextEditingController(text: widget.budget.dreamName);
    target = TextEditingController(text: widget.budget.dreamTarget > 0 ? widget.budget.dreamTarget.toStringAsFixed(0) : '');
    saved = TextEditingController(text: widget.budget.dreamSaved > 0 ? widget.budget.dreamSaved.toStringAsFixed(0) : '');
    months = TextEditingController(text: widget.budget.dreamMonths > 0 ? widget.budget.dreamMonths.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    name.dispose();
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
            Header(title: tr(context, 'budget'), subtitle: ''),
            const SizedBox(height: 16),
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(prefixIcon: const Icon(Icons.person_rounded), labelText: tr(context, 'userName'))),
            const SizedBox(height: 12),
            Money(label: tr(context, 'income'), controller: income, icon: Icons.payments_rounded),
            Money(label: tr(context, 'expenses'), controller: expenses, icon: Icons.receipt_long_rounded),
            DreamNameField(controller: dream, label: tr(context, 'dreamName')),
            const SizedBox(height: 12),
            Money(label: tr(context, 'target'), controller: target, icon: Icons.track_changes_rounded),
            Money(label: tr(context, 'saved'), controller: saved, icon: Icons.savings_rounded),
            NumberInput(label: tr(context, 'months'), controller: months, icon: Icons.calendar_month_rounded, bottom: false),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => widget.onSave(BudgetData(
                  userName: name.text.trim(),
                  income: n(income),
                  fixedExpenses: n(expenses),
                  dreamName: dream.text.trim(),
                  dreamTarget: n(target),
                  dreamSaved: n(saved),
                  dreamMonths: n(months),
                  dreamVault: widget.budget.dreamVault,
                  dreamStartDay: widget.budget.dreamStartDay.isEmpty ? BudgetData.todayKey() : widget.budget.dreamStartDay,
                  dreamDayAdjustment: widget.budget.dreamDayAdjustment,
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

class AddGoalSheet extends StatefulWidget {
  final Future<void> Function(DreamGoal) onSave;
  const AddGoalSheet({super.key, required this.onSave});

  @override
  State<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<AddGoalSheet> {
  late final TextEditingController dream;
  late final TextEditingController target;
  late final TextEditingController saved;
  late final TextEditingController months;

  @override
  void initState() {
    super.initState();
    dream = TextEditingController();
    target = TextEditingController();
    saved = TextEditingController();
    months = TextEditingController();
  }

  @override
  void dispose() {
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
            Header(title: tr(context, 'addGoal'), subtitle: 'Add another dream to your Dream Vault.'),
            const SizedBox(height: 16),
            DreamNameField(controller: dream, label: tr(context, 'dreamName')),
            const SizedBox(height: 12),
            Money(label: tr(context, 'target'), controller: target, icon: Icons.track_changes_rounded),
            Money(label: tr(context, 'saved'), controller: saved, icon: Icons.savings_rounded),
            NumberInput(label: tr(context, 'months'), controller: months, icon: Icons.calendar_month_rounded, bottom: false),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final goal = DreamGoal(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    name: dream.text.trim(),
                    target: n(target),
                    saved: n(saved),
                    months: n(months),
                    vault: 0,
                    startDay: BudgetData.todayKey(),
                    dayAdjustment: 0,
                    primary: false,
                  );
                  if (goal.name.isEmpty || goal.target <= 0 || goal.months <= 0) return;
                  await widget.onSave(goal);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(tr(context, 'save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class SpendingSheet extends StatefulWidget {
  final String currentStore;
  final Future<void> Function(double, String) onSave;
  const SpendingSheet({super.key, required this.currentStore, required this.onSave});

  @override
  State<SpendingSheet> createState() => _SpendingSheetState();
}

class _SpendingSheetState extends State<SpendingSheet> {
  late final TextEditingController amount;
  late final TextEditingController place;

  @override
  void initState() {
    super.initState();
    amount = TextEditingController();
    place = TextEditingController(text: widget.currentStore == 'No store detected' ? '' : widget.currentStore);
  }

  @override
  void dispose() {
    amount.dispose();
    place.dispose();
    super.dispose();
  }

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
            Header(title: tr(context, 'addSpending'), subtitle: 'This updates your Safe Spend immediately.'),
            const SizedBox(height: 16),
            Money(label: tr(context, 'amount'), controller: amount, icon: Icons.euro_rounded),
            TextField(controller: place, decoration: InputDecoration(prefixIcon: const Icon(Icons.storefront_rounded), labelText: tr(context, 'where'))),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final value = double.tryParse(amount.text.trim().replaceAll(',', '.')) ?? 0;
                  await widget.onSave(value, place.text);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.remove_circle_rounded),
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
  final DailyWallet wallet;
  final String currentStore;
  final String gpsStatus;
  final StoreDecision? decision;
  final VoidCallback onGps;
  final VoidCallback onSetup;
  final VoidCallback onAddSpending;
  final Future<void> Function(double, String) onProtectMoney;
  final List<DreamGoal> goals;
  final Future<void> Function(DreamGoal) onSelectPrimaryGoal;
  final Future<void> Function(DreamGoal) onDeleteGoal;
  final VoidCallback onSettings;
  final VoidCallback onHelp;

  const HomeScreen({
    super.key,
    required this.budget,
    required this.wallet,
    required this.currentStore,
    required this.gpsStatus,
    required this.decision,
    required this.onGps,
    required this.onSetup,
    required this.onAddSpending,
    required this.onProtectMoney,
    required this.goals,
    required this.onSelectPrimaryGoal,
    required this.onDeleteGoal,
    required this.onSettings,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final safe = decision?.safeAmount ?? wallet.balance;
    final dream = budget.dreamName.isEmpty ? 'your dream' : budget.dreamName;
    final color = decision?.store.color ?? (budget.isReady ? AppColors.gold : AppColors.teal);

    return AppBackground(
      palette: AmbientPalette.fromStore(decision?.store, currentStore),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.userName.trim().isEmpty ? greetingTitle(context) : '${greetingTitle(context)}, ${budget.userName}',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLanguageScope.of(context).language == AppLanguage.it
                            ? 'Oggi puoi spendere in sicurezza'
                            : 'Safe to spend today',
                        style: TextStyle(color: AppScrollStyle.paletteOf(context).accentSoft.withOpacity(0.76), fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (!budget.isReady) SetupPrompt(onTap: onSetup),
            GoalSafeCarousel(budget: budget, wallet: wallet, goals: goals, currentStore: currentStore, decision: decision),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAddSpending,
                    icon: const Icon(Icons.remove_circle_rounded),
                    label: Text(tr(context, 'addSpending')),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.amber, foregroundColor: AppColors.bgDeep, padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: safe > 0 ? () => onProtectMoney(safe, 'Locked instead of spending at $currentStore') : null,
                    icon: const Icon(Icons.lock_rounded),
                    label: Text(tr(context, 'keepDream')),
                    style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: AppColors.bgDeep, padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SpendGuardScoreCard(budget: budget, decision: decision, wallet: wallet, onHelp: onHelp),
            const SizedBox(height: 14),
            GoalFutureCostCarousel(budget: budget, safe: safe, goals: goals, storeName: currentStore, color: color, onSettings: onSettings),
            if (goals.length > 1) ...[
              const SizedBox(height: 14),
              DreamVaultPreview(goals: goals, onSelectPrimaryGoal: onSelectPrimaryGoal, onDeleteGoal: onDeleteGoal),
            ],
          ],
        ),
      ),
    );
  }
}

class GoalSafeCarousel extends StatelessWidget {
  final BudgetData budget;
  final DailyWallet wallet;
  final List<DreamGoal> goals;
  final String currentStore;
  final StoreDecision? decision;

  const GoalSafeCarousel({super.key, required this.budget, required this.wallet, required this.goals, required this.currentStore, required this.decision});

  BudgetData _budgetFor(DreamGoal goal) => budget.copyWith(
        dreamName: goal.name,
        dreamTarget: goal.target,
        dreamSaved: goal.saved,
        dreamMonths: goal.months,
        dreamVault: goal.vault,
        dreamStartDay: goal.startDay,
        dreamDayAdjustment: goal.dayAdjustment,
      );

  @override
  Widget build(BuildContext context) {
    final items = goals.isEmpty ? <DreamGoal>[] : DreamGoal.sortByClosestGoal(goals);
    if (items.isEmpty) {
      final safe = decision?.safeAmount ?? wallet.balance;
      return HeroDecisionCard(budget: budget, safe: safe, wallet: wallet, currentStore: currentStore, decision: decision);
    }
    return SizedBox(
      height: 392,
      child: PageView.builder(
        controller: PageController(viewportFraction: 1.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final goal = items[index];
          var safe = min(wallet.balance, goal.dailySafeAmount(budget.monthlyRoom));
          if (decision?.store.risk != null) {
            if (decision!.store.risk >= 75) safe *= 0.55;
            else if (decision!.store.risk >= 45) safe *= 0.80;
          }
          return SizedBox(
            width: double.infinity,
            child: HeroDecisionCard(budget: _budgetFor(goal), safe: safe, wallet: wallet, currentStore: currentStore, decision: decision),
          );
        },
      ),
    );
  }
}

class GoalFutureCostCarousel extends StatelessWidget {
  final BudgetData budget;
  final double safe;
  final List<DreamGoal> goals;
  final String storeName;
  final Color color;
  final VoidCallback onSettings;

  const GoalFutureCostCarousel({super.key, required this.budget, required this.safe, required this.goals, required this.storeName, required this.color, required this.onSettings});

  BudgetData _budgetFor(DreamGoal goal) => budget.copyWith(
        dreamName: goal.name,
        dreamTarget: goal.target,
        dreamSaved: goal.saved,
        dreamMonths: goal.months,
        dreamVault: goal.vault,
        dreamStartDay: goal.startDay,
        dreamDayAdjustment: goal.dayAdjustment,
      );

  @override
  Widget build(BuildContext context) {
    final items = goals.isEmpty ? <DreamGoal>[] : DreamGoal.sortByClosestGoal(goals);
    if (items.isEmpty) return FutureCostCard(budget: budget, safe: safe, storeName: storeName, color: color, onSettings: onSettings);
    return SizedBox(
      height: 374,
      child: PageView.builder(
        controller: PageController(viewportFraction: 1.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final goal = items[index];
          final goalSafe = min(safe, goal.dailySafeAmount(budget.monthlyRoom));
          return SizedBox(
            width: double.infinity,
            child: FutureCostCard(budget: _budgetFor(goal), safe: goalSafe, storeName: storeName, color: color, onSettings: onSettings),
          );
        },
      ),
    );
  }
}

class HeroDecisionCard extends StatelessWidget {
  final BudgetData budget;
  final double safe;
  final DailyWallet wallet;
  final String currentStore;
  final StoreDecision? decision;

  const HeroDecisionCard({super.key, required this.budget, required this.safe, required this.wallet, required this.currentStore, required this.decision});

  @override
  Widget build(BuildContext context) {
    final status = decision?.store.riskLabel ?? (budget.isReady ? 'SAFE' : 'SETUP');
    final color = decision?.store.color ?? (budget.isReady ? AppColors.gold : AppColors.teal);
    final statusLine = status == 'SAFE'
        ? 'You can safely spend here.'
        : status == 'CAUTION'
            ? 'Think before you buy.'
            : status == 'DANGER'
                ? 'This could hurt your goal.'
                : budget.isReady
                    ? (AppLanguageScope.of(context).language == AppLanguage.it ? 'Il tuo futuro è protetto.' : 'Your future is protected.')
                    : 'Set your budget to start.';

    final scrollTone = AppScrollStyle.of(context).clamp(0.0, 1.0);
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment(-0.85 + (0.28 * scrollTone), -1.0),
          end: Alignment(0.85 - (0.18 * scrollTone), 1.0),
          colors: [
            Color.lerp(AppScrollStyle.paletteOf(context).cardTop, color, 0.10 + (0.06 * scrollTone))!,
            Color.lerp(AppScrollStyle.paletteOf(context).cardBottom, AppColors.bgDeep, 0.18 + (0.10 * scrollTone))!,
          ],
        ),
        border: Border.all(color: color.withOpacity(0.16 + (0.08 * scrollTone)), width: 0.9),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.050 + (0.120 * scrollTone)), blurRadius: 30 + (34 * scrollTone), spreadRadius: -8 + (4 * scrollTone), offset: Offset(0, 10 + (18 * scrollTone))),
          BoxShadow(color: Colors.black.withOpacity(0.26 + (0.18 * scrollTone)), blurRadius: 22 + (28 * scrollTone), offset: Offset(0, 12 + (14 * scrollTone))),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Text(statusLine, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text('€${safe.toStringAsFixed(2)}', style: const TextStyle(fontSize: 74, fontWeight: FontWeight.w900, letterSpacing: -3.2)),
          const SizedBox(height: 6),
          Text(tr(context, 'safeToday'), style: const TextStyle(color: AppColors.muted, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('${tr(context, 'todaySpent')}: €${wallet.spentToday.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(tr(context, 'rollover'), style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text(tr(context, 'storeDetected'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              _StoreVisualBadge(
                visual: StoreVisual.fromStore(currentStore, decision?.store.category ?? ''),
                size: 42,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(currentStore, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class SpendGuardScoreCard extends StatelessWidget {
  final BudgetData budget;
  final StoreDecision? decision;
  final DailyWallet wallet;
  final VoidCallback onHelp;

  const SpendGuardScoreCard({super.key, required this.budget, required this.decision, required this.wallet, required this.onHelp});

  int get score {
    if (!budget.isReady) return 0;
    var value = 70;
    if (budget.hasDream) value += 10;
    value += (budget.dreamProgress * 20).round();
    final risk = decision?.store.risk ?? 25;
    if (risk >= 75) value -= 35;
    if (risk >= 45 && risk < 75) value -= 15;
    if (wallet.balance < 3) value -= 20;
    return value.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final s = score;
    final color = s >= 75 ? AppColors.gold : s >= 45 ? AppColors.amber : AppColors.red;
    return PremiumCard(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 28),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.14), border: Border.all(color: color.withOpacity(0.8), width: 2)),
                  child: Center(child: Text('$s', style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SpendGuard Score', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        s >= 75 ? 'Strong control. Your future is protected.' : s >= 45 ? 'Be careful. One purchase can slow your goal.' : 'High risk. Protect your money today.',
                        style: const TextStyle(color: AppColors.muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(top: 0, right: 0, child: TinyCornerButton(icon: Icons.help_outline_rounded, onTap: onHelp)),
        ],
      ),
    );
  }
}

class TinyCornerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const TinyCornerButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppScrollStyle.paletteOf(context);
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.035),
              border: Border.all(color: palette.accentSoft.withOpacity(0.10), width: 0.6),
            ),
            child: Icon(icon, size: 12, color: palette.accentSoft.withOpacity(0.62)),
          ),
        ),
      ),
    );
  }
}

class FutureCostCard extends StatelessWidget {
  final BudgetData budget;
  final double safe;
  final String storeName;
  final Color color;
  final VoidCallback onSettings;

  const FutureCostCard({super.key, required this.budget, required this.safe, required this.storeName, required this.color, required this.onSettings});

  void _openForecast(BuildContext context, {required bool spendingView, required int impactDays}) {
    final it = AppLanguageScope.of(context).language == AppLanguage.it;
    final newDays = max(0, budget.dreamDaysRemaining + (spendingView ? impactDays : 0));
    final date = DateTime.now().add(Duration(days: newDays));
    final dateText = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(spendingView ? Icons.trending_up_rounded : Icons.hourglass_bottom_rounded, color: spendingView ? AppColors.red : AppColors.green),
                const SizedBox(width: 10),
                Expanded(child: Text(tr(context, 'forecast'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 12),
              Text(budget.dreamName.ifEmpty(it ? 'Il tuo obiettivo' : 'Your dream'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              _MetricRow(label: it ? 'Impatto giorni' : 'Days impact', value: spendingView ? formatDaysHuman(impactDays, signed: true) : budget.dreamDaysShiftLabel),
              _MetricRow(label: tr(context, 'daysRemaining'), value: formatDaysHumanLong(newDays)),
              _MetricRow(label: tr(context, 'estimatedDate'), value: dateText),
              _MetricRow(label: it ? 'Importo simulato' : 'Simulated amount', value: '€${safe.toStringAsFixed(2)}'),
              const SizedBox(height: 10),
              Text(
                it
                    ? 'Questa previsione mostra come una spesa o i giorni accumulati cambiano la data reale del goal.'
                    : 'This forecast shows how spending or accumulated days changes the real goal date.',
                style: const TextStyle(color: AppColors.muted, height: 1.35, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dreamName = budget.dreamName.isEmpty ? (AppLanguageScope.of(context).language == AppLanguage.it ? 'il tuo obiettivo' : 'your dream') : budget.dreamName;
    final impactDays = budget.impactDaysFor(max(1.0, safe));
    final visual = DreamVisual.fromText(dreamName);
    final shiftColor = budget.dreamDaysShiftFromPlan > 0
        ? AppColors.red
        : budget.dreamDaysShiftFromPlan < 0
            ? AppColors.green
            : AppColors.muted;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.timeline_rounded, color: color), const SizedBox(width: 10), Expanded(child: Text(tr(context, 'futureImpact'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), TinyCornerButton(icon: Icons.settings_rounded, onTap: onSettings)]),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: visual.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: visual.color.withOpacity(0.42)),
                  boxShadow: [BoxShadow(color: visual.color.withOpacity(0.16), blurRadius: 22)],
                ),
                child: visual.emoji == null
                    ? Icon(visual.icon, color: visual.color, size: 28)
                    : Center(
                        child: Text(
                          visual.emoji!,
                          style: const TextStyle(fontSize: 27),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(dreamName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 12),
          GradientProgressBar(
            value: budget.dreamProgress,
            height: 12,
            colors: const [AppColors.gold, AppColors.goldLight],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('${budget.dreamProgressPercent}% ${tr(context, 'dreamProgress')}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800))),
              Text(budget.dreamDaysRemainingLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _FutureCostBox(title: 'SPEND NOW', value: formatDaysHuman(impactDays, signed: true), icon: Icons.trending_up_rounded, color: AppColors.red, onTap: () => _openForecast(context, spendingView: true, impactDays: impactDays))),
              const SizedBox(width: 10),
              Expanded(child: _FutureCostBox(title: tr(context, 'daysAccumulated').toUpperCase(), value: budget.dreamDaysShiftLabel, icon: Icons.hourglass_bottom_rounded, color: shiftColor, onTap: () => _openForecast(context, spendingView: false, impactDays: impactDays))),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppLanguageScope.of(context).language == AppLanguage.it
                ? (budget.dreamDaysShiftFromPlan > 0
                    ? 'Le ultime spese hanno allontanato $dreamName. Ogni scelta conta.'
                    : budget.dreamDaysShiftFromPlan < 0
                        ? 'Hai avvicinato $dreamName. Continua così.'
                        : 'Ogni acquisto può avvicinare o allontanare $dreamName.')
                : (budget.dreamDaysShiftFromPlan > 0
                    ? 'Your recent spending cost you time with $dreamName. Every choice matters.'
                    : budget.dreamDaysShiftFromPlan < 0
                        ? 'You moved $dreamName closer. Keep going.'
                        : 'Every purchase can move $dreamName closer or further away.'),
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
  final VoidCallback? onTap;

  const _FutureCostBox({required this.title, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.30))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            FittedBox(child: Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900))),
          ]),
        ),
      ),
    );
  }
}

class DreamVaultPreview extends StatelessWidget {
  final List<DreamGoal> goals;
  final Future<void> Function(DreamGoal) onSelectPrimaryGoal;
  final Future<void> Function(DreamGoal) onDeleteGoal;

  const DreamVaultPreview({super.key, required this.goals, required this.onSelectPrimaryGoal, required this.onDeleteGoal});

  void _showAllGoals(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, controller) => SafeArea(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tr(context, 'dreamVault'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.gold.withOpacity(0.35))),
                    child: Text('${goals.length} goals', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...goals.map((g) => DreamGoalTile(
                    goal: g,
                    showPrimaryAction: true,
                    onMakePrimary: g.primary
                        ? null
                        : () async {
                            await onSelectPrimaryGoal(g);
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          },
                    onDelete: () async {
                      await onDeleteGoal(g);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = goals.firstWhere((g) => g.primary, orElse: () => goals.first);
    return PremiumCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(child: Text(tr(context, 'dreamVault'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          TextButton.icon(
            onPressed: () => _showAllGoals(context),
            icon: const Icon(Icons.folder_special_rounded, size: 18, color: AppColors.gold),
            label: Text('${goals.length} goals', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 12),
        DreamGoalTile(goal: primary, compact: true),
      ]),
    );
  }
}

class DreamGoalTile extends StatelessWidget {
  final DreamGoal goal;
  final bool compact;
  final bool showPrimaryAction;
  final VoidCallback? onMakePrimary;
  final VoidCallback? onDelete;
  const DreamGoalTile({super.key, required this.goal, this.compact = false, this.showPrimaryAction = false, this.onMakePrimary, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final visual = DreamVisual.fromText(goal.name);
    final borderColor = goal.primary ? AppColors.gold : visual.color;
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 8 : 12),
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(color: AppColors.bgDeep.withOpacity(0.34), borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor.withOpacity(goal.primary ? 0.58 : 0.24))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: compact ? 38 : 44,
            height: compact ? 38 : 44,
            decoration: BoxDecoration(color: visual.color.withOpacity(0.13), borderRadius: BorderRadius.circular(15), border: Border.all(color: visual.color.withOpacity(0.32))),
            child: Center(child: Text(visual.emoji ?? '✨', style: TextStyle(fontSize: compact ? 22 : 25))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(goal.name.ifEmpty('Dream'), style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900))),
          if (goal.primary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.13), borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.gold.withOpacity(0.35))),
              child: Text(tr(context, 'primaryGoal'), style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w900)),
            )
          else if (showPrimaryAction && onMakePrimary != null)
            TextButton(
              onPressed: onMakePrimary,
              child: Text(tr(context, 'setPrimary'), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
            ),
          if (showPrimaryAction && onDelete != null)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.red.withOpacity(0.82),
              ),
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: AppColors.card,
                    title: Text(tr(context, 'deleteGoal')),
                    content: Text('Delete "${goal.name.ifEmpty('Dream')}"?', style: const TextStyle(color: AppColors.muted)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          onDelete!();
                        },
                        child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('−', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ),
        ]),
        const SizedBox(height: 10),
        GradientProgressBar(
          value: goal.progress,
          height: compact ? 8 : 10,
          colors: goal.progress >= 0.75 ? const [AppColors.gold, AppColors.goldLight] : const [AppColors.goldDark, AppColors.gold],
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('${goal.progressPercent}% • ${goal.daysRemainingLabel}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800))),
          Text('€${goal.totalProtected.toStringAsFixed(0)} / €${goal.target.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
  }
}


class DreamNameField extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const DreamNameField({super.key, required this.controller, required this.label});

  @override
  State<DreamNameField> createState() => _DreamNameFieldState();
}

class _DreamNameFieldState extends State<DreamNameField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant DreamNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final visual = DreamVisual.fromText(widget.controller.text);
    return TextField(
      controller: widget.controller,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: visual.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: visual.color.withOpacity(0.35)),
              boxShadow: [BoxShadow(color: visual.color.withOpacity(0.12), blurRadius: 14)],
            ),
            child: Center(
              child: visual.emoji == null
                  ? Icon(visual.icon, color: visual.color, size: 20)
                  : Text(visual.emoji!, style: const TextStyle(fontSize: 19)),
            ),
          ),
        ),
        helperText: widget.controller.text.trim().isEmpty ? 'Type your dream and SpendGuard recognises it.' : visual.label,
        helperStyle: TextStyle(color: AppColors.gold.withOpacity(0.88), fontWeight: FontWeight.w800),
      ),
    );
  }
}

class GradientProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final List<Color> colors;

  const GradientProgressBar({super.key, required this.value, required this.height, required this.colors});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.10)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
            ),
          ),
        ),
      ),
    );
  }
}


class StoresScreen extends StatelessWidget {
  final String currentStore;
  final String gpsStatus;
  final bool gpsReady;
  final StoreDecision? decision;
  final VoidCallback onGps;
  final List<StoreVisit> visits;

  const StoresScreen({super.key, required this.currentStore, required this.gpsStatus, required this.gpsReady, required this.decision, required this.onGps, required this.visits});

  @override
  Widget build(BuildContext context) {
    final currentVisual = decision == null
        ? StoreVisual.fromStore(currentStore, '')
        : StoreVisual.fromStore(decision!.store.name, decision!.store.category);

    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Header(title: tr(context, 'stores'), subtitle: 'Global Store Detection: food, furniture, tech, clothes, petrol and worldwide stores.'),
            const SizedBox(height: 16),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StoreVisualBadge(visual: currentVisual, size: 58),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentStore, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text(currentVisual.label, style: TextStyle(color: currentVisual.color, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(gpsStatus, style: const TextStyle(color: AppColors.muted, height: 1.4)),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onGps, icon: const Icon(Icons.my_location_rounded), label: Text(tr(context, 'checkGps')))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, 'history'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (visits.isEmpty)
                    const Text('No store visits saved yet.', style: TextStyle(color: AppColors.muted))
                  else
                    ...visits.take(10).map((v) {
                      final visual = StoreVisual.fromStore(v.storeName, v.category);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _StoreVisualBadge(visual: visual, size: 46),
                        title: Text(v.storeName, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${visual.label} • ${v.distanceMeters.toStringAsFixed(0)}m • €${v.safeAmount.toStringAsFixed(2)} safe'),
                        trailing: Text('${v.time.day}/${v.time.month}', style: const TextStyle(color: AppColors.muted)),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreVisualBadge extends StatelessWidget {
  final StoreVisual visual;
  final double size;

  const _StoreVisualBadge({required this.visual, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: visual.color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(size * 0.33),
        border: Border.all(color: visual.color.withOpacity(0.38)),
        boxShadow: [BoxShadow(color: visual.color.withOpacity(0.16), blurRadius: 20)],
      ),
      child: Center(child: Text(visual.emoji, style: TextStyle(fontSize: size * 0.50))),
    );
  }
}

class InsightsScreen extends StatelessWidget {
  final BudgetData budget;
  final DailyWallet wallet;
  final List<SpendingEntry> spendingHistory;
  final List<StoreVisit> visits;
  final List<DreamGoal> goals;
  final VoidCallback onAddGoal;
  final Future<void> Function(DreamGoal) onSelectPrimaryGoal;
  final Future<void> Function(DreamGoal) onDeleteGoal;

  const InsightsScreen({super.key, required this.budget, required this.wallet, required this.spendingHistory, required this.visits, required this.goals, required this.onAddGoal, required this.onSelectPrimaryGoal, required this.onDeleteGoal});

  @override
  Widget build(BuildContext context) {
    final totalSpent = spendingHistory.fold<double>(0, (a, b) => a + b.amount);
    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Header(title: tr(context, 'insights'), subtitle: 'Your spending, your stores, your dreams.'),
            const SizedBox(height: 16),
            PremiumCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(tr(context, 'dreamVault'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                  FilledButton.icon(onPressed: goals.length >= 5 ? null : onAddGoal, icon: const Icon(Icons.add_rounded), label: Text(tr(context, 'addGoal'))),
                ]),
                if (goals.length >= 5) ...[
                  const SizedBox(height: 8),
                  Text(tr(context, 'maxGoalsReached'), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800)),
                ],
                const SizedBox(height: 8),
                Text(tr(context, 'autoPrimary'), style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, height: 1.3)),
                const SizedBox(height: 12),
                if (goals.isEmpty)
                  const Text('No goals yet. Add your first dream in Setup.', style: TextStyle(color: AppColors.muted))
                else
                  ...goals.map((g) => DreamGoalTile(goal: g, showPrimaryAction: true, onMakePrimary: g.primary ? null : () => onSelectPrimaryGoal(g), onDelete: () => onDeleteGoal(g))),
              ]),
            ),
            const SizedBox(height: 14),
            PremiumCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(context, 'wallet'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                _MetricRow(label: tr(context, 'remainingToday'), value: '€${wallet.balance.toStringAsFixed(2)}'),
                _MetricRow(label: tr(context, 'todaySpent'), value: '€${wallet.spentToday.toStringAsFixed(2)}'),
                _MetricRow(label: 'All recorded spending', value: '€${totalSpent.toStringAsFixed(2)}'),
                _MetricRow(label: tr(context, 'dreamProgress'), value: '${budget.dreamProgressPercent}%'),
                _MetricRow(label: tr(context, 'daysRemaining'), value: budget.dreamDaysRemainingLongLabel),
                _MetricRow(label: tr(context, 'daysAccumulated'), value: budget.dreamDaysShiftLabel),
              ]),
            ),
            const SizedBox(height: 14),
            PremiumCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Recent spending', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (spendingHistory.isEmpty)
                  const Text('No spending recorded yet.', style: TextStyle(color: AppColors.muted))
                else
                  ...spendingHistory.take(10).map((s) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.euro_rounded)),
                        title: Text('€${s.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(s.place),
                        trailing: Text('${s.time.day}/${s.time.month}', style: const TextStyle(color: AppColors.muted)),
                      )),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}


class AccountsScreen extends StatelessWidget {
  final List<BankTransaction> transactions;
  final Future<void> Function() onImportCsv;
  final DailyWallet wallet;
  final BudgetData budget;

  const AccountsScreen({
    super.key,
    required this.transactions,
    required this.onImportCsv,
    required this.wallet,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final lang = AppLanguageScope.of(context).language;
    final palette = AmbientPalette.fromTime();
    final totalMonth = _monthTotal(transactions);
    final topMerchant = _topMerchant(transactions);

    return AppBackground(
      palette: palette,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
          children: [
            Header(
              title: tr(context, 'accounts'),
              subtitle: lang == AppLanguage.it
                  ? 'In fase di sviluppo. La connessione conti arriverà nelle prossime build.'
                  : 'In development. Account connection will arrive in a future build.',
            ),
            const SizedBox(height: 16),
            PremiumCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.accent.withOpacity(0.13),
                      border: Border.all(color: palette.accentSoft.withOpacity(0.18)),
                    ),
                    child: Icon(Icons.upload_file_rounded, color: palette.accentSoft),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang == AppLanguage.it ? 'Conti bancari' : 'Bank accounts',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(lang == AppLanguage.it ? 'Questa sezione è in fase di sviluppo. SpendGuard non è ancora collegato alla banca e non muove denaro.' : 'This section is in development. SpendGuard is not connected to your bank yet and never moves money.', style: const TextStyle(color: AppColors.muted, height: 1.42, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.construction_rounded),
                    label: Text(lang == AppLanguage.it ? 'In fase di sviluppo' : 'In development'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: PremiumCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lang == AppLanguage.it ? 'Speso questo mese' : 'Spent this month', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('€${totalMonth.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lang == AppLanguage.it ? 'Daily Wallet' : 'Daily Wallet', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('€${wallet.balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            if (topMerchant != null)
              PremiumCard(
                child: Row(children: [
                  const Icon(Icons.psychology_alt_rounded, color: AppColors.goldLight),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang == AppLanguage.it
                          ? 'SpendGuard ha notato che spendi spesso da ${topMerchant.key}.'
                          : 'SpendGuard noticed you often spend at ${topMerchant.key}.',
                      style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 18),
            Text(tr(context, 'recentTransactions'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (transactions.isEmpty)
              PremiumCard(
                child: Text(lang == AppLanguage.it ? 'Import CSV e collegamento banca verranno sistemati in una build dedicata.' : 'CSV import and bank connection will be fixed in a dedicated build.', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
              )
            else
              ...transactions.take(25).map((tx) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.accent.withOpacity(0.10),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: AppColors.goldLight, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tx.merchant, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text(_dateLabel(tx.date), style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        Text('-€${tx.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.red)),
                      ]),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  double _monthTotal(List<BankTransaction> items) {
    final now = DateTime.now();
    return items
        .where((tx) => tx.date.year == now.year && tx.date.month == now.month)
        .fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  MapEntry<String, double>? _topMerchant(List<BankTransaction> items) {
    if (items.isEmpty) return null;
    final totals = <String, double>{};
    for (final tx in items) {
      totals[tx.merchant] = (totals[tx.merchant] ?? 0) + tx.amount;
    }
    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first;
  }

  String _dateLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}


class SettingsScreen extends StatefulWidget {
  final BudgetData budget;
  final NotificationPrefs notificationPrefs;
  final Future<void> Function(NotificationPrefs) onPrefsChanged;
  final VoidCallback onSetup;
  final List<DreamGoal> goals;

  const SettingsScreen({super.key, required this.budget, required this.notificationPrefs, required this.onPrefsChanged, required this.onSetup, required this.goals});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late NotificationPrefs localPrefs;
  bool savingPrefs = false;

  @override
  void initState() {
    super.initState();
    localPrefs = widget.notificationPrefs;
  }

  Future<void> _changePrefs(NotificationPrefs prefs) async {
    setState(() {
      localPrefs = prefs;
      savingPrefs = true;
    });
    await widget.onPrefsChanged(prefs);
    if (!mounted) return;
    setState(() => savingPrefs = false);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppLanguageScope.of(context);
    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Header(title: tr(context, 'settings'), subtitle: '', showClose: true),
            const SizedBox(height: 16),
            PremiumCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.person_rounded, color: AppColors.goldLight),
                  const SizedBox(width: 10),
                  Expanded(child: Text(scope.language == AppLanguage.it ? 'Profilo' : 'Profile', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                  IconButton(onPressed: widget.onSetup, icon: const Icon(Icons.edit_rounded, color: AppColors.muted)),
                ]),
                const SizedBox(height: 14),
                Text(widget.budget.userName.isEmpty ? tr(context, 'userName') : widget.budget.userName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                const SizedBox(height: 14),
                _IdentityLine(icon: Icons.flag_rounded, label: scope.language == AppLanguage.it ? 'Obiettivo principale' : 'Primary dream', value: widget.budget.dreamName.isEmpty ? '—' : widget.budget.dreamName),
                _IdentityLine(icon: Icons.savings_rounded, label: scope.language == AppLanguage.it ? 'Protetto' : 'Protected', value: '€${widget.budget.dreamTotalProtected.toStringAsFixed(0)}'),
                _IdentityLine(icon: Icons.hourglass_bottom_rounded, label: scope.language == AppLanguage.it ? 'Tempo rimanente' : 'Remaining', value: widget.budget.hasDream ? widget.budget.dreamDaysRemainingLongLabel : '—'),
                _IdentityLine(icon: Icons.auto_awesome_rounded, label: 'Dream Vault', value: widget.goals.isEmpty ? '0 goals' : '${widget.goals.length} goals'),
              ]),
            ),
            const SizedBox(height: 14),
            PremiumCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(context, 'language'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<AppLanguage>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: AppLanguage.en, label: Text('English')),
                      ButtonSegment(value: AppLanguage.it, label: Text('Italiano')),
                    ],
                    selected: {scope.language},
                    onSelectionChanged: (s) => scope.onChanged(s.first),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            PremiumCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(tr(context, 'notifications'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                  if (savingPrefs) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: localPrefs.onEnter,
                    onChanged: savingPrefs ? null : (v) => _changePrefs(localPrefs.copyWith(onEnter: v)),
                    title: Text(tr(context, 'enterStoreAlert'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.22)),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: localPrefs.onExit,
                    onChanged: savingPrefs ? null : (v) => _changePrefs(localPrefs.copyWith(onExit: v)),
                    title: Text(tr(context, 'exitStoreAlert'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.22)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            PremiumCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(context, 'privacy'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('SpendGuard stores your budget, goals, wallet, CSV imports and visit history on this device. CSV import is read-only and never moves money.', style: TextStyle(color: AppColors.muted, height: 1.35)),
                const SizedBox(height: 12),
                Text('${tr(context, 'version')}: Build 24 Final', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w900)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}


class _IdentityLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _IdentityLine({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppScrollStyle.paletteOf(context).accentSoft),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Flexible(child: Text(value, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final it = AppLanguageScope.of(context).language == AppLanguage.it;
    final cards = it
        ? const [
            ('Home', 'Vedi subito quanto puoi spendere oggi senza rovinare il tuo obiettivo.', Icons.home_rounded),
            ('Goals', 'Aggiungi fino a cinque obiettivi e scegli quello principale.', Icons.flag_rounded),
            ('GPS', 'Quando sei vicino a un negozio, SpendGuard valuta il rischio della spesa.', Icons.storefront_rounded),
            ('Conti', 'Importa un CSV della banca. L’app legge solo le spese e aggiorna il wallet.', Icons.account_balance_wallet_rounded),
            ('Impostazioni', 'Modifica profilo, lingua, budget e notifiche.', Icons.settings_rounded),
          ]
        : const [
            ('Home', 'See how much you can spend today without hurting your main goal.', Icons.home_rounded),
            ('Goals', 'Add up to five goals and choose your main one.', Icons.flag_rounded),
            ('GPS', 'When you are near a shop, SpendGuard checks the spending risk.', Icons.storefront_rounded),
            ('Accounts', 'Import a bank CSV. The app reads expenses only and updates your wallet.', Icons.account_balance_wallet_rounded),
            ('Settings', 'Edit profile, language, budget and notifications.', Icons.settings_rounded),
          ];

    return AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Header(
              title: tr(context, 'help'),
              subtitle: it ? 'Una guida veloce. Niente confusione.' : 'A quick guide. No noise.',
              showClose: true,
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < cards.length; i++)
              _HelpCard(number: '${i + 1}', title: cards[i].$1, text: cards[i].$2, icon: cards[i].$3),
          ],
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  final String number;
  final String title;
  final String text;
  final IconData icon;

  const _HelpCard({required this.number, required this.title, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final palette = AppScrollStyle.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.accentSoft.withOpacity(0.08),
                border: Border.all(color: palette.accent.withOpacity(0.25)),
              ),
              child: Center(child: Text(number, style: TextStyle(color: palette.accentSoft, fontWeight: FontWeight.w900, fontSize: 15))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: palette.accentSoft, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.2))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(text, style: const TextStyle(color: AppColors.muted, height: 1.35, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showClose;
  const Header({super.key, required this.title, required this.subtitle, this.showClose = false});

  @override
  Widget build(BuildContext context) {
    final titleWidget = ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(colors: [AppColors.text, AppColors.goldLight, AppColors.gold]).createShader(bounds),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        children: [
          Expanded(child: titleWidget),
          if (showClose)
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.close_rounded, color: AppColors.muted),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.035),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
        ],
      ),
      if (subtitle.trim().isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 15, height: 1.35, fontWeight: FontWeight.w600)),
      ],
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
      child: PremiumCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Setup required', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Add income, fixed expenses and your dream to activate Safe Spend.', style: TextStyle(color: AppColors.muted, height: 1.35)),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: onTap, icon: const Icon(Icons.tune_rounded), label: Text(tr(context, 'setup')))),
        ]),
      ),
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
        decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label, prefixText: '€ '),
      ),
    );
  }
}

class NumberInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool bottom;

  const NumberInput({super.key, required this.label, required this.controller, required this.icon, this.bottom = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom ? 12 : 0),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
      ),
    );
  }
}

class AppScrollStyle extends InheritedWidget {
  final double glow;
  final AmbientPalette palette;
  const AppScrollStyle({super.key, required this.glow, required this.palette, required super.child});

  static double of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScrollStyle>()?.glow ?? 0.0;
  }

  static AmbientPalette paletteOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScrollStyle>()?.palette ?? AmbientPalette.fromTime();
  }

  @override
  bool updateShouldNotify(AppScrollStyle oldWidget) =>
      (oldWidget.glow - glow).abs() > 0.01 || oldWidget.palette.label != palette.label;
}


class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const PremiumCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    final t = AppScrollStyle.of(context).clamp(0.0, 1.0);
    final palette = AppScrollStyle.paletteOf(context);

    // Soft natural light. No hard middle line, no artificial glow.
    final surface = Color.lerp(palette.cardTop, palette.middle, 0.04 + (0.045 * t))!;
    final mid = Color.lerp(palette.cardTop, palette.cardBottom, 0.42 + (0.08 * t))!;
    final lower = Color.lerp(palette.cardBottom, AppColors.bgDeep, 0.03 + (0.04 * (1 - t)))!;
    final borderLight = 0.060 + (0.018 * t);

    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        padding: padding,
        decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.72 + (0.12 * t), -1.0),
          end: Alignment(0.72 - (0.08 * t), 1.0),
          colors: [
            Color.lerp(surface, palette.accentSoft, 0.018 + (0.012 * t))!,
            mid,
            lower,
          ],
          stops: const [0.0, 0.72, 1.0],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.accentSoft.withOpacity(borderLight), width: 0.8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.22 + (0.18 * t)), blurRadius: 18 + (30 * t), offset: Offset(0, 10 + (14 * t))),
          BoxShadow(color: palette.accent.withOpacity(0.006 + (0.040 * t)), blurRadius: 18 + (34 * t), spreadRadius: -8),
        ],
      ),
        child: child,
      ),
    );
  }
}


class V6SplashBackground extends StatelessWidget {
  final Widget child;
  const V6SplashBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = AmbientPalette.fromTime();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.top,
            palette.middle,
            palette.bottom,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.25, -0.75),
                  radius: 1.1,
                  colors: [
                    palette.accentSoft.withOpacity(0.10),
                    palette.accent.withOpacity(0.045),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.48),
                    Colors.transparent,
                    Colors.black.withOpacity(0.28),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class AppBackground extends StatefulWidget {
  final Widget child;
  final AmbientPalette? palette;
  const AppBackground({super.key, required this.child, this.palette});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  double _scrollGlow = 0;

  bool _onScroll(ScrollNotification notification) {
    final pixels = notification.metrics.pixels;
    final max = notification.metrics.maxScrollExtent <= 0 ? 1.0 : notification.metrics.maxScrollExtent;
    final depth = (pixels / min(max, 520.0)).clamp(0.0, 1.0);

    if ((depth - _scrollGlow).abs() > 0.003) {
      setState(() => _scrollGlow = depth);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeOutCubic.transform(_scrollGlow);
    final palette = widget.palette ?? AmbientPalette.fromTime();

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(palette.top, palette.middle, 0.12 * t)!,
              Color.lerp(palette.middle, palette.cardTop, 0.10 + (0.18 * t))!,
              Color.lerp(palette.bottom, palette.cardBottom, 0.12 * t)!,
            ],
            stops: const [0.0, 0.58, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 420),
                opacity: 0.45,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.35 + (0.45 * t), -0.92 + (0.58 * t)),
                      radius: 1.05,
                      colors: [
                        palette.accentSoft.withOpacity(0.034 + (0.020 * t)),
                        palette.accent.withOpacity(0.012 + (0.012 * t)),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.88, 0.88 - (0.50 * t)),
                    radius: 0.96,
                    colors: [
                      palette.accent.withOpacity(0.010 + (0.010 * (1 - t))),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.42),
                      Colors.transparent,
                      Colors.black.withOpacity(0.46),
                    ],
                  ),
                ),
              ),
            ),
            AppScrollStyle(
              glow: t,
              palette: palette,
              child: Material(
                type: MaterialType.transparency,
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    height: 1.28,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpendGuardAppIcon extends StatelessWidget {
  final double size;
  const SpendGuardAppIcon({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 18, offset: const Offset(0, 10))],
        ),
        child: Image.asset(
        spendGuardAppIcon,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.24),
            gradient: const LinearGradient(colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark]),
          ),
          child: Center(child: Text('S', style: TextStyle(fontSize: size * 0.48, fontWeight: FontWeight.w900, color: Colors.white))),
        ),
      ),
      ),
    );
  }
}

extension StringX on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
