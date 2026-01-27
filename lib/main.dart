import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class ThemeColorOption {
  const ThemeColorOption(this.label, this.color);

  final String label;
  final Color color;
}

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;
  Color _seedColor = Colors.teal;

  ThemeMode get mode => _mode;
  bool get isDarkMode => _mode == ThemeMode.dark;
  Color get seedColor => _seedColor;
  List<ThemeColorOption> get colorOptions => _colorOptions;

  static const List<ThemeColorOption> _colorOptions = [
    ThemeColorOption('Teal', Colors.teal),
    ThemeColorOption('Indigo', Colors.indigo),
    ThemeColorOption('Purple', Colors.deepPurple),
    ThemeColorOption('Orange', Colors.deepOrange),
    ThemeColorOption('Green', Colors.green),
  ];

  void setDarkMode(bool value) {
    final nextMode = value ? ThemeMode.dark : ThemeMode.light;
    if (nextMode == _mode) return;
    _mode = nextMode;
    notifyListeners();
  }

  void setSeedColor(Color color) {
    if (color == _seedColor) return;
    _seedColor = color;
    notifyListeners();
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in widget tree.');
    return scope!.notifier!;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return ThemeScope(
          controller: _themeController,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: _themeController.mode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: _themeController.seedColor,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: _themeController.seedColor,
                brightness: Brightness.dark,
              ),
            ),
            home: const AuthGate(),
          ),
        );
      },
    );
  }
}
