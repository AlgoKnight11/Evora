import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/evora_theme.dart';
import 'routes/app_router.dart';
import 'services/logging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env)
  try {
    await dotenv.load(fileName: ".env");
    LoggingService.logBreadcrumb('.env environment variables loaded successfully.');
  } catch (e) {
    LoggingService.logBreadcrumb(
      '.env file not found or failed to load. Using fallback environment definitions.',
    );
  }

  // Configure System Navigation & Status Bars for Edge-to-Edge display
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Attempt Firebase Initialization
  try {
    await Firebase.initializeApp();
    LoggingService.logBreadcrumb('Firebase Core initialized successfully.');
  } catch (e) {
    LoggingService.logBreadcrumb(
      'Firebase config not detected yet (development mock mode enabled). '
      'Place google-services.json in android/app/ to connect live project.',
    );
  }

  // Set up global Flutter error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    LoggingService.logError(
      'Flutter framework error: ${details.exceptionAsString()}',
      stackTrace: details.stack,
    );
  };

  runApp(
    const ProviderScope(
      child: EvoraApp(),
    ),
  );
}

class EvoraApp extends StatelessWidget {
  final String initialRoute;
  const EvoraApp({super.key, this.initialRoute = '/splash'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EVORA',
      debugShowCheckedModeBanner: false,
      theme: EvoraTheme.lightTheme(isHindi: false),
      routerConfig: createAppRouter(initialLocation: initialRoute),
    );
  }
}
