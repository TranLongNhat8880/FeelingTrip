import 'package:flutter/material.dart';

import '../../../shared/ui_kit.dart';
import 'admin_place_management_content.dart';

// ============================================================================
// VIEW: Màn bọc để chạy thử nội dung quản lý kho địa điểm.
//
// Sau này Tùng chỉ cần nhúng AdminPlaceManagementContent vào Admin shell.
// ============================================================================

class AdminPlaceManagementScreen extends StatelessWidget {
  const AdminPlaceManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Quản lý địa điểm',
      body: AdminPlaceManagementContent(),
    );
  }
}
