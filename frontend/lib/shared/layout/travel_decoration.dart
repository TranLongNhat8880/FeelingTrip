import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// Decorative assets never receive input or duplicate screen-reader content.
class TravelBackdrop extends StatelessWidget {
  const TravelBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      // Light sky blue background gradient
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8F6FF), Color(0xFFF3FAFF), Color(0xFFFFFFFF)],
            ),
          ),
        ),
      ),

      // Bottom footer wave with map pin and flight trail
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: 105,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Image.asset(AppAssets.travelFooter, fit: BoxFit.fill),
          ),
        ),
      ),

      // Tropical leaves in bottom-left corner
      Positioned(
        bottom: 0,
        left: 0,
        width: 120,
        height: 135,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Image.asset(AppAssets.leaves, fit: BoxFit.contain),
          ),
        ),
      ),

      // Foreground content
      Positioned.fill(child: child),
    ],
  );
}

class TravelBrand extends StatelessWidget {
  const TravelBrand({super.key, this.width = 170});
  final double width;

  @override
  Widget build(BuildContext context) => Image.asset(
    AppAssets.logo,
    width: width,
    fit: BoxFit.contain,
    semanticLabel: 'FeelingTrip',
  );
}

/// Wave underline painter matching template doodle
class _WaveUnderlinePainter extends CustomPainter {
  const _WaveUnderlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF13B5FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(
      size.width * 0.25,
      0,
      size.width * 0.5,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height,
      size.width,
      size.height * 0.5,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Sun sparkle rays painter matching the 3 yellow doodle rays in the template
class _SunRaysPainter extends CustomPainter {
  const _SunRaysPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    // Top diagonal ray
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.32),
      Offset(size.width * 0.9, size.height * 0.08),
      paint,
    );
    // Middle horizontal ray
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.52),
      Offset(size.width * 1.0, size.height * 0.52),
      paint,
    );
    // Bottom diagonal ray
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.72),
      Offset(size.width * 0.9, size.height * 0.96),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shared responsive auth canvas; the form stays scrollable above the keyboard.
class TravelAuthLayout extends StatelessWidget {
  const TravelAuthLayout({
    super.key,
    required this.child,
    required this.title,
    this.subtitle,
    this.onBack,
    this.welcome = false,
    this.footer,
  });

  final Widget child;
  final Widget? footer;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool welcome;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: TravelBackdrop(
        child: SafeArea(
          top: !welcome,
          bottom: true,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.formMaxWidth,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: welcome
                    ? _buildWelcomeLayout(context, topPadding)
                    : _buildStandardLayout(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeLayout(BuildContext context, double topPadding) {
    // The scenery and luggage background extends ~90px past where the card starts
    final sceneryHeight = topPadding + 295.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Scenery and Luggage (Behind the white card)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: sceneryHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Coastal background full-bleed
              Positioned.fill(
                child: Image.asset(
                  AppAssets.coastalBackground,
                  fit: BoxFit.cover,
                ),
              ),

              // Soft bottom blend so background dissolves into sky blue
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.65, 1.0],
                      colors: [
                        Color(0x33F0FAFF),
                        Colors.transparent,
                        Color(0xFFE8F6FF),
                      ],
                    ),
                  ),
                ),
              ),

              // Airplane with contrail top right
              Positioned(
                top: topPadding + 8,
                right: 8,
                width: 140,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Image.asset(
                      AppAssets.flightTrail,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // Orange luggage with hat
              // Positioned so the top is visible and bottom 90px is covered by the white card!
              Positioned(
                top: topPadding + 55,
                right: 10,
                width: 175,
                height: 255,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Image.asset(
                      AppAssets.luggage,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Foreground content (Header text, Floating Card, Footer)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topPadding + 14),

            // Left Header Info
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 155),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TravelBrand(width: 170),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Chào mừng\ntrở lại ',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF09143B),
                          height: 1.15,
                          letterSpacing: -0.6,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: CustomPaint(
                          size: const Size(18, 20),
                          painter: const _SunRaysPainter(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Lên kế hoạch du lịch và\nkết nối nhóm dễ dàng',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF5D6889),
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const CustomPaint(
                    size: Size(65, 5),
                    painter: _WaveUnderlinePainter(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Floating White Card (Covers the bottom of the suitcase!)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF003E7E).withValues(alpha: 0.10),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: child,
            ),

            // Footer outside the card
            if (footer != null) ...[
              const SizedBox(height: 20),
              footer!,
              const SizedBox(height: 36),
            ] else
              const SizedBox(height: 36),
          ],
        ),
      ],
    );
  }

  Widget _buildStandardLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStandardHero(context),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF003E7E).withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF09143B),
                  letterSpacing: -0.5,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5D6889),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: 20),
          footer!,
          const SizedBox(height: 36),
        ] else
          const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildStandardHero(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(AppAssets.coastalBackground, fit: BoxFit.cover),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xE6F0FAFF), Color(0xB3F0FAFF)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    tooltip: 'Quay lại',
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: Color(0xFF09143B),
                    ),
                  ),
                const SizedBox(width: 8),
                const TravelBrand(width: 150),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
