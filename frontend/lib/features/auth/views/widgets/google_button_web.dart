import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;
import '../../../../core/constants/app_sizes.dart';

Widget buildGoogleWebButton() => LayoutBuilder(
  builder: (context, constraints) {
    // Let GIS report its real iframe size, including its outer spacing.
    // Constraining that iframe to 40 px clips its contents before Flutter fits it.
    const sdkHeight = 40.0;
    const scale = AppSizes.primaryButtonHeight / sdkHeight;
    final sdkWidth = constraints.hasBoundedWidth
        ? (constraints.maxWidth / scale).ceilToDouble().clamp(1.0, 400.0)
        : 400.0;
    return SizedBox(
      width: double.infinity,
      height: AppSizes.primaryButtonHeight,
      child: FittedBox(
        fit: BoxFit.contain,
        child: google_web.renderButton(
          configuration: google_web.GSIButtonConfiguration(
            theme: google_web.GSIButtonTheme.outline,
            text: google_web.GSIButtonText.signinWith,
            size: google_web.GSIButtonSize.large,
            shape: google_web.GSIButtonShape.pill,
            logoAlignment: google_web.GSIButtonLogoAlignment.center,
            minimumWidth: sdkWidth,
            locale: 'vi',
          ),
        ),
      ),
    );
  },
);
