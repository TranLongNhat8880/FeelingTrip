import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'features/auth/viewmodels/auth_viewmodel.dart';
import 'shared/mascot/koharu_controller.dart';
import 'shared/mascot/koharu_host.dart';

class FeelingTripApp extends StatefulWidget {
  const FeelingTripApp({super.key, this.auth});
  final AuthViewModel? auth;
  @override
  State<FeelingTripApp> createState() => _FeelingTripAppState();
}

class _FeelingTripAppState extends State<FeelingTripApp> {
  late final AuthViewModel _auth;
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _koharu = KoharuController();
  late final _koharuObserver = KoharuNavigatorObserver(_koharu);
  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? AuthViewModel();
    _auth.restoreSession();
  }

  @override
  void dispose() {
    _koharu.dispose();
    if (widget.auth == null) _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: _auth,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        navigatorObservers: [_koharuObserver],
        builder: (context, child) => KoharuScope(
          controller: _koharu,
          child: KoharuHost(
            controller: _koharu,
            auth: _auth,
            navigatorKey: _navigatorKey,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        title: 'FeelingTrip',
        debugShowCheckedModeBanner: false,

        // Theme
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,

        // Routes
        initialRoute: kDebugMode && const bool.fromEnvironment('UI_KIT')
            ? AppRoutes.uiKit
            : AppRoutes.home,
        routes: AppRoutes.routes,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
