import 'package:flutter/material.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../home/views/home_screen.dart';
import 'login_screen.dart';
import 'blocked_account_screen.dart';
import '../../admin/views/admin_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    if (!auth.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.blockedEmail != null || auth.sessionInvalidated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      });
    }
    if (auth.blockedEmail != null || auth.user?.status == 'BANNED') {
      return BlockedAccountScreen(email: auth.blockedEmail ?? auth.user!.email);
    }
    if (!auth.isLoggedIn) return const LoginScreen();
    return auth.user!.isAdmin ? const AdminScreen() : const HomeScreen();
  }
}
