import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

Widget buildGoogleWebButton() => LayoutBuilder(
  builder: (context, constraints) {
    // GIS supports widths up to 400 px. Keep the real SDK button clickable
    // while matching the form width on phones and its Vietnamese copy.
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth.clamp(1.0, 400.0)
        : 400.0;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Center(
        child: google_web.renderButton(
          configuration: google_web.GSIButtonConfiguration(
            theme: google_web.GSIButtonTheme.outline,
            text: google_web.GSIButtonText.continueWith,
            size: google_web.GSIButtonSize.large,
            shape: google_web.GSIButtonShape.rectangular,
            logoAlignment: google_web.GSIButtonLogoAlignment.center,
            minimumWidth: width,
            locale: 'vi',
          ),
        ),
      ),
    );
  },
);
