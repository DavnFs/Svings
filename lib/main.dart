import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cause_money_record/config/app_color.dart';
import 'package:cause_money_record/config/sessions.dart';
import 'package:cause_money_record/config/supabase_config.dart';
import 'package:cause_money_record/data/model/user.dart';
import 'package:cause_money_record/presentation/controller/c_user.dart';
import 'package:cause_money_record/presentation/page/auth/login_page.dart';
import 'package:cause_money_record/presentation/page/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  // Initialize Supabase before runApp so the first frame can hit the API.
  await SupabaseConfig.initialize();

  runApp(const MyApp());
}

/// Single seed for both schemes. MD3 derives all ~30 color roles from this,
/// replacing the hand-written palette where only 3 roles used to be set.
const _seed = Color(0xFF6C63FF);

/// Radius scale, derived from the values the screens already used inline.
/// Flutter exposes shapes per component rather than as a global token set, so
/// these are applied to each component theme below — one place to change
/// instead of 84 scattered `BorderRadius.circular()` literals.
const _radiusSmall = 12.0;   // inputs, chips, outlined buttons
const _radiusButton = 14.0;  // primary action buttons
const _radiusCard = 16.0;    // cards and panels
const _radiusSheet = 20.0;   // dialogs and sheets

RoundedRectangleBorder _rounded(double radius) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    // Fallback only — every page sets its own Scaffold background from
    // AppColor.surface. Read from the scheme, not the palette: the palette's
    // static brightness is not set until the widget tree builds, and both
    // themes are constructed before that.
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      // Runs on every rebuild, before the page tree builds, so AppColor reads
      // the brightness of the theme actually in effect.
      builder: (context, child) {
        AppColor.useBrightness(Theme.of(context).brightness);
        return child ?? const SizedBox.shrink();
      },
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
            Get.put(CUser()).setData(snapshot.data!);
            return const HomePage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}
