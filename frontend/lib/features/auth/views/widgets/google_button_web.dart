import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

Widget buildGoogleWebButton() => google_web.renderButton(
  configuration: google_web.GSIButtonConfiguration(
    text: google_web.GSIButtonText.continueWith,
    size: google_web.GSIButtonSize.large,
    shape: google_web.GSIButtonShape.pill,
  ),
);
