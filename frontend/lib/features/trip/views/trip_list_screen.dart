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
    // Phải bọc màn hình trong ShowCaseWidget để quản lý lớp màn xám
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
  // Tạo các "Chìa khóa" (Key) để đánh dấu những chỗ cần linh vật chỉ vào
  final GlobalKey _createTripKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Tự động bật hướng dẫn ngay khi vừa vào màn hình lần đầu
    // (Thực tế sau này: Check local storage xem user đã xem bao giờ chưa, chưa thì mới bật)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShowCaseWidget.of(context).startShowCase([_createTripKey, _profileKey]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chuyến đi của tôi'),
        // Tắt nút back vì đây là trang chủ (giả lập)
        automaticallyImplyLeading: false, 
        actions: [
          // === HƯỚNG DẪN SỐ 2: Nút Hồ sơ ===
          Showcase.withWidget(
            key: _profileKey,
            targetPadding: const EdgeInsets.all(8),
            container: const MascotTooltip(
              message: 'Bạn có thể chỉnh sửa hồ sơ hoặc đăng xuất ở góc này nhé!',
              isArrowTop: false,
            ),
            child: IconButton(
              icon: const Icon(Icons.person_outline),
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
      floatingActionButton: 
        // === HƯỚNG DẪN SỐ 1: Nút Dấu Cộng ===
        Showcase.withWidget(
          key: _createTripKey,
          targetPadding: const EdgeInsets.all(8),
          container: const MascotTooltip(
            message: 'Chào bạn! Mình là Cún Du Lịch. Bấm vào dấu + này để tạo chuyến đi mới nha!',
            isArrowTop: true,
          ),
          child: FloatingActionButton(
            onPressed: () {},
            // Màu nút lấy theo màu Accent (Cam san hô) cho nổi bật
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add, size: 28),
          ),
      ),
    );
  }
}
