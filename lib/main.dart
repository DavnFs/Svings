import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/sessions.dart';
import 'package:cause_money_record/config/supabase_config.dart';
import 'package:cause_money_record/data/model/user.dart';
import 'package:cause_money_record/presentation/controller/c_home.dart';
import 'package:cause_money_record/presentation/controller/c_settings.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/controller/history/c_detail_history.dart';
import 'package:cause_money_record/presentation/controller/history/c_history.dart';
import 'package:cause_money_record/presentation/controller/history/c_history_form.dart';
import 'package:cause_money_record/presentation/controller/history/c_income_outcome.dart';
import 'package:cause_money_record/presentation/page/auth/login_page.dart';
import 'package:cause_money_record/presentation/page/main_shell.dart';

/// All controllers are created once at startup, so no screen can ever hit a
/// "not found" from a `Get.find` before its `put` ran.
class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(CUser(), permanent: true);
    Get.put(CHome(), permanent: true);
    Get.put(CHistory(), permanent: true);
    Get.put(CIncomeOutcome(), permanent: true);
    Get.put(CDetailHistory(), permanent: true);
    Get.put(CHistoryForm(), permanent: true);
    Get.put(CSettings(), permanent: true);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  // Initialize Supabase before runApp so the first frame can hit the API.
  await SupabaseConfig.initialize();

  // Bindings + settings load before the first frame, so no screen can hit a
  // "not found" from Get.find and the stored theme applies immediately.
  AppBindings().dependencies();
  await Get.find<CSettings>().load();

  runApp(const MyApp());
}

/// Single seed for both schemes. DESIGN.md strict accent: #7C5CFF light.
const _seed = Color(0xFF7C5CFF);

/// Radius scale per DESIGN.md: 10 chips, 14 inputs/buttons, 18 cards/groups,
/// 24 sheets/modals.
const _radiusSmall = 10.0;
const _radiusButton = 14.0;
const _radiusCard = 18.0;
const _radiusSheet = 24.0;

RoundedRectangleBorder _rounded(double radius) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

/// [dynamicScheme] is the wallpaper-derived scheme from `dynamic_color`, present
/// only on Android 12+. Everywhere else the seed is used, so light and dark
/// stay a matched pair in both cases.
ThemeData _buildTheme(Brightness brightness, ColorScheme? dynamicScheme) {
  final scheme = dynamicScheme ??
      ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    // Ripple needs a visible surface tone to read as a Material layer.
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelSmall: base.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.4, fontSize: 11),
    ),
    cardTheme: CardThemeData(shape: _rounded(_radiusCard)),
    dialogTheme: DialogThemeData(shape: _rounded(_radiusSheet)),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: _rounded(_radiusButton),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: _rounded(_radiusSmall),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Wallpaper-derived schemes from `dynamic_color`, when the platform supplies
  /// them (Android 12+). Everywhere else these stay null and the seed is used.
  ColorScheme? _lightDynamic;
  ColorScheme? _darkDynamic;
  bool _dynamicLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadDynamic();
  }

  Future<void> _loadDynamic() async {
    try {
      final core = await DynamicColorPlugin.getCorePalette();
      if (!mounted || core == null) {
        if (mounted) setState(() => _dynamicLoaded = true);
        return;
      }
      // Build Flutter ColorSchemes from the OS palette. We bypass
      // DynamicColorBuilder because it is typed against material_ui's
      // ColorScheme, which conflicts with Flutter's.
      setState(() {
        _lightDynamic = _paletteToScheme(core, Brightness.light);
        _darkDynamic = _paletteToScheme(core, Brightness.dark);
        _dynamicLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _dynamicLoaded = true);
    }
  }

  // ignore: deprecated_member_use
  ColorScheme _paletteToScheme(CorePalette core, Brightness brightness) =>
      ColorScheme.fromSeed(
        // The wallpaper's dominant colour seeds the whole scheme — tone 40 of
        // the primary palette is the standard "primary" surface colour. Dynamic
        // colour therefore reaches every AppColor read without editing any call
        // site.
        seedColor: Color(core.primary.get(40)),
        brightness: brightness,
      );

  @override
  Widget build(BuildContext context) {
    // Wait for the (possibly absent) dynamic palette before painting, so the
    // first frame already has the right scheme.
    if (!_dynamicLoaded) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return _ThemedHost(
      light: _buildTheme(Brightness.light, _lightDynamic),
      dark: _buildTheme(Brightness.dark, _darkDynamic),
    );
  }
}

/// Owns the settings-driven ThemeMode. One GetMaterialApp, rebuilt with the
/// stored mode — theme toggle propagates app-wide with no per-screen state.
class _ThemedHost extends StatefulWidget {
  final ThemeData light;
  final ThemeData dark;
  const _ThemedHost({required this.light, required this.dark});

  @override
  State<_ThemedHost> createState() => _ThemedHostState();
}

class _ThemedHostState extends State<_ThemedHost> {
  late final CSettings _settings;
  final _mode = ValueNotifier(ThemeMode.system);

  @override
  void initState() {
    super.initState();
    _settings = Get.find<CSettings>();
    _mode.value = _settings.themeMode;
    _settings.addListener(_mirror);
  }

  void _mirror() {
    if (_mode.value != _settings.themeMode) _mode.value = _settings.themeMode;
  }

  @override
  void dispose() {
    _settings.removeListener(_mirror);
    _mode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _mode,
      builder: (context, mode, _) => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        // Wide screens: centered 600px column so the mobile UI never stretches.
        builder: (context, child) {
          AppColor.useScheme(Theme.of(context).colorScheme);
          final body = child ?? const SizedBox.shrink();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: body,
            ),
          );
        },
        theme: widget.light,
        darkTheme: widget.dark,
        themeMode: mode,
        home: FutureBuilder(
          future: Session.getUser(),
          builder: (context, AsyncSnapshot<User> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Scaffold(
                backgroundColor: AppColor.surface,
                body: Center(
                  child: CircularProgressIndicator(color: AppColor.accent),
                ),
              );
            }
            if (snapshot.data != null && snapshot.data!.idUser != null) {
              Get.find<CUser>().setData(snapshot.data!);
              return const MainShell();
            }
            return const LoginPage();
          },
        ),
      ),
    );
  }
}
