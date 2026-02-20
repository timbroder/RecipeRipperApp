import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/home_screen.dart';
import 'services/background_processing_service.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  final databaseService = DatabaseService();
  await databaseService.initialize();

  // TODO: DEV HARNESS — remove before release
  await databaseService.clearAllData();

  // Initialize background processing (Android WorkManager, iOS BGTaskScheduler)
  if (Platform.isAndroid || Platform.isIOS) {
    await BackgroundProcessingService.initialize();
  }

  // Create sync provider (depends on database service)
  final syncProvider = SyncProvider(databaseService);
  await syncProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        ChangeNotifierProvider(
          create: (_) => RecipeProvider(databaseService),
        ),
        ChangeNotifierProvider.value(value: syncProvider),
      ],
      child: const RecipeSlurpApp(),
    ),
  );
}

class RecipeSlurpApp extends StatelessWidget {
  const RecipeSlurpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe Slurp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
