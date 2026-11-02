import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/feedback/app_feedback.dart';
import '../../../../shared/widgets/app_status_badge.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../terms_screen.dart';
import 'google_button_platform.dart';

class GoogleLoginButton extends StatefulWidget {
  const GoogleLoginButton({super.key, required this.onBusyChanged});
  final ValueChanged<bool> onBusyChanged;

  @override
  State<GoogleLoginButton> createState() => _GoogleLoginButtonState();
}

class _GoogleLoginButtonState extends State<GoogleLoginButton> {
  static const _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static Future<void>? _initialization;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;
  bool _ready = false;
  bool _busy = false;
  String? _setupError;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      _setupError = 'Đăng nhập Google hiện hỗ trợ Android, iOS và trình duyệt.';
      return;
    }
    if (_webClientId.isEmpty) {
      _setupError = 'Đăng nhập Google chưa được cấu hình cho bản ứng dụng này.';
      return;
    }
    // Consume SDK errors on every platform. On native, authenticate() handles
    // its own result; only web requires sign-in events from the Google button.
    _events = GoogleSignIn.instance.authenticationEvents.listen(
      (event) {
        if (kIsWeb && event is GoogleSignInAuthenticationEventSignIn) {
          unawaited(_complete(event.user));
        }
      },
      onError: (Object error) {
        if (kIsWeb) _showError(error);
      },
    );
    try {
      _initialization ??= GoogleSignIn.instance.initialize(
        clientId: kIsWeb
            ? _webClientId
            : (_iosClientId.isEmpty ? null : _iosClientId),
        serverClientId: kIsWeb ? null : _webClientId,
      );
      await _initialization;
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      _initialization = null;
      if (mounted) {
        setState(
          () => _setupError =
              'Chưa khởi tạo được đăng nhập Google. Vui lòng mở lại màn hình.',
        );
      }
    }
  }

  void _setBusy(bool value) {
    if (!mounted) return;
    setState(() => _busy = value);
    widget.onBusyChanged(value);
  }

  void _showError(Object error) {
    if (!mounted) return;
    if (error is GoogleSignInException &&
        error.code == GoogleSignInExceptionCode.canceled) {
      return;
    }
    AppFeedback.show(
      context,
      error is GoogleSignInException &&
              error.code == GoogleSignInExceptionCode.clientConfigurationError
          ? 'Cấu hình Google chưa đúng. Kiểm tra OAuth Client ID và chữ ký ứng dụng.'
          : 'Chưa kết nối được Google. Vui lòng thử lại.',
      tone: AppStatusTone.error,
    );
  }

  Future<void> _nativeSignIn() async {
    if (_busy || AuthScope.of(context).isLoading) return;
    if (!_ready) {
      AppFeedback.show(
        context,
        _setupError ?? 'Google đang khởi tạo. Vui lòng thử lại.',
        tone: AppStatusTone.warning,
      );
      return;
    }
    _setBusy(true);
    try {
      // End the previous SDK session so logout/login can choose another account.
      await GoogleSignIn.instance.signOut();
      final user = await GoogleSignIn.instance.authenticate();
      if (mounted) await _complete(user, alreadyBusy: true);
    } catch (error) {
      _showError(error);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _complete(
    GoogleSignInAccount user, {
    bool alreadyBusy = false,
  }) async {
    if (!mounted ||
        (!alreadyBusy && (_busy || AuthScope.of(context).isLoading))) {
      return;
    }
    if (!alreadyBusy) _setBusy(true);
    try {
      final token = user.authentication.idToken;
      if (token == null || token.isEmpty) {
        _showError(StateError('Missing Google ID token'));
        return;
      }
      await AuthScope.of(context).googleLogin(
        token,
        termsVersion: TermsScreen.version,
        acceptTerms: () async {
          if (!mounted) return false;
          return await Navigator.push<bool>(
                context,
                MaterialPageRoute<bool>(builder: (_) => const TermsScreen()),
              ) ==
              true;
        },
      );
    } finally {
      if (!alreadyBusy) _setBusy(false);
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _busy || AuthScope.of(context).isLoading;
    if (kIsWeb && _ready) {
      return AbsorbPointer(
        absorbing: disabled,
        child: Opacity(
          opacity: disabled ? .5 : 1,
          child: buildGoogleWebButton(),
        ),
      );
    }
    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.primaryButtonRadius),
          border: Border.all(color: const Color(0xFFDEE4EF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
            BoxShadow(
              color: Color(0x0A1A73E8),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.primaryButtonRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.primaryButtonRadius),
            onTap: disabled ? null : _nativeSignIn,
            splashColor: const Color(0x0D1A73E8),
            highlightColor: const Color(0x061A73E8),
            child: SizedBox(
              height: AppSizes.primaryButtonHeight,
              width: double.infinity,
              child: Center(
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            AppAssets.googleLogo,
                            width: 22,
                            height: 22,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Tiếp tục với Google',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF09143B),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
