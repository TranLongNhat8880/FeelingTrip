import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;
import '../../../../core/constants/app_sizes.dart';

Widget buildGoogleWebButton() => LayoutBuilder(
  builder: (context, constraints) {
    // GIS renders its large button at 40 px. Scale the real SDK view, including
    // its hit target, to the shared primary button size without a click overlay.
    const sdkHeight = 40.0;
    const scale = AppSizes.primaryButtonHeight / sdkHeight;
    final sdkWidth = constraints.hasBoundedWidth
        ? (constraints.maxWidth / scale).clamp(1.0, 400.0)
        : 400.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.primaryButtonRadius),
      child: SizedBox(
        width: double.infinity,
        height: AppSizes.primaryButtonHeight,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: sdkWidth,
            height: sdkHeight,
            child: google_web.renderButton(
              configuration: google_web.GSIButtonConfiguration(
                theme: google_web.GSIButtonTheme.outline,
                text: google_web.GSIButtonText.continueWith,
                size: google_web.GSIButtonSize.large,
                shape: google_web.GSIButtonShape.rectangular,
                logoAlignment: google_web.GSIButtonLogoAlignment.center,
                minimumWidth: sdkWidth,
                locale: 'vi',
              ),
            ),
          ),
        ),
      ),
    );
  },
);
