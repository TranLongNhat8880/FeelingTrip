import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';

class FeelingTripApp extends StatelessWidget {
  const FeelingTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FeelingTrip',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,

      // Routes
      initialRoute: kDebugMode && const bool.fromEnvironment('UI_KIT')
          ? AppRoutes.uiKit
          : AppRoutes.tripList,
      routes: AppRoutes.routes,
    );
  }
}
