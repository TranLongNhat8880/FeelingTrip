import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/mascot_tooltip.dart';
import '../../../core/constants/app_colors.dart';

// ================================================================================
// VIEW: Trip List (Danh sách chuyến đi)
// MÀN HÌNH DEMO TÍNH NĂNG "APP TOUR" BẰNG LINH VẬT
// ================================================================================

class TripListScreen extends StatelessWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return ShowCaseWidget(
      builder: (context) => const _TripListView(),
    );
  }
}

class _TripListView extends StatefulWidget {
  const _TripListView();

  @override
  State<_TripListView> createState() => _TripListViewState();
}

class _TripListViewState extends State<_TripListView> {
  final GlobalKey _createTripKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: deprecated_member_use
      ShowCaseWidget.of(context).startShowCase([_createTripKey, _profileKey]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF09143B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: .04),
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF09143B)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Chuyến đi của tôi',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF09143B),
            fontSize: 18,
          ),
        ),
        actions: [
          Showcase.withWidget(
            key: _profileKey,
            targetPadding: const EdgeInsets.all(8),
            container: const MascotTooltip(
              message: 'Bạn có thể chỉnh sửa hồ sơ hoặc đăng xuất ở góc này nhé!',
              isArrowTop: false,
            ),
            child: IconButton(
              icon: const Icon(Icons.person_outline, color: Color(0xFF09143B)),
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const EmptyStateWidget(
        icon: Icons.flight_takeoff,
        title: 'Chưa có chuyến đi nào',
        message: 'Hãy bắt đầu lên kế hoạch cho chuyến đi đầu tiên của bạn!',
      ),
      floatingActionButton: Showcase.withWidget(
        key: _createTripKey,
        targetPadding: const EdgeInsets.all(8),
        container: const MascotTooltip(
          message: 'Chào bạn! Mình là Cún Du Lịch. Bấm vào dấu + này để tạo chuyến đi mới nha!',
          isArrowTop: true,
        ),
        child: FloatingActionButton(
          onPressed: () {},
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }
}
