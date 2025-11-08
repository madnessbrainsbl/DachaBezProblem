import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'loginauth/auth_screen.dart';
import 'homepage/home_screen.dart';
import 'loginauth/name_input_screen.dart';
import 'loginauth/region_select_screen.dart';
import 'services/user_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Инициализация WidgetsBinding
  WidgetsFlutterBinding.ensureInitialized();

  // Настройка системных UI элементов (статус бар и навигация)
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge, // Включаем edge-to-edge режим
  );

  // Глобальные перехватчики ошибок, чтобы не оставаться на пустом экране без логов
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    developer.log(
      details.exceptionAsString(),
      name: 'FLUTTER',
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    developer.log('Uncaught platform error: $error', name: 'FLUTTER', stackTrace: stack);
    return true; // предотвратить фатал на вебе
  };

  // Инициализация Firebase (на Web временно пропускаем)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, st) {
      developer.log('Firebase initializeApp FAILED: $e', name: 'FIREBASE', stackTrace: st);
    }
  }

  print('🚀 === ЗАПУСК ПРИЛОЖЕНИЯ ДАЧА БЕЗ ПРОБЛЕМ ===');
  print('📱 Версия приложения: модернизированная под новую структуру данных');
  print('🌱 Поддержка automation данных для напоминаний: ✅');
  print('🔍 Детальная диагностика проблем растений: ✅');
  print('🌡️ Новая структура температурных данных: ✅');
  print('📊 Подробное логирование: ✅');
  print('🚀 === ГОТОВ К РАБОТЕ ===\n');

  // Настраиваем фильтрацию логов перед запуском приложения
  if (kDebugMode) {
    // Отключаем логи от эмулятора
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && !message.contains('EGL_emulation')) {
        developer.log(message, name: 'APP');
      }
    };

    // Устанавливаем свой префикс для логов
    debugPrintStack(label: 'Приложение запущено в режиме отладки');
  }

  runZonedGuarded(
    () => runApp(const MyApp()),
    (error, stack) => developer.log('Uncaught zone error: $error', name: 'ZONE', stackTrace: stack),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Дача без проблем',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Gilroy',
        primarySwatch: Colors.green,
        primaryColor: const Color(0xFF63A36C),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: AuthCheckScreen(),
      routes: {
        '/auth': (context) => AuthScreen(),
        '/name_input': (context) => NameInputScreen(),
        '/home': (context) => HomeScreen(),
      },
      // Для экранов, требующих параметры, используем onGenerateRoute
      onGenerateRoute: (settings) {
        if (settings.name == '/region_select') {
          // Получение userName из аргументов, передаваемых через Navigator.pushNamed
          final args = settings.arguments as Map<String, dynamic>?;
          final userName = args?['userName'] ?? '';
          final initialCity = args?['initialCity'] ?? '';

          return MaterialPageRoute(
            builder: (context) => RegionSelectScreen(
              userName: userName,
              initialCity: initialCity,
            ),
          );
        }
        return null; // Позволяет использовать стандартные routes
      },
    );
  }
}

/// Экран проверки авторизации при запуске приложения
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({Key? key}) : super(key: key);

  @override
  _AuthCheckScreenState createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  /// Проверяет состояние авторизации пользователя
  Future<void> _checkAuth() async {
    try {
      final authState = await UserPreferencesService.getAuthState();

      // Навигация после первого кадра, чтобы исключить проблемы раннего вызова Navigator
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = authState['isLoggedIn'] == true ? '/home' : '/auth';
        Navigator.of(context).pushReplacementNamed(target);
      });
    } catch (e) {
      // На вебе возможны ошибки чтения локального хранилища/инициализации
      // В таком случае безопасно уводим на экран авторизации
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/auth');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Показываем заставку приложения пока идет проверка авторизации
    return Scaffold(
      backgroundColor: const Color(0xFF63A36C),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Запуск приложения...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
