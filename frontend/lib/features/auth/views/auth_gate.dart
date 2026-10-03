import 'package:flutter/material.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../home/views/home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    if (!auth.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}
