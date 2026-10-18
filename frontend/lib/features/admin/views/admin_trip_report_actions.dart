import 'package:flutter/material.dart';
import '../../../shared/ui_kit.dart';
import '../models/admin_content_model.dart';
import '../models/admin_trip_report_resolution.dart';

/// Select explicit targets; being the trip leader is not proof of a violation.
class AdminTripReportActions extends StatefulWidget {
  const AdminTripReportActions({
    super.key,
    required this.report,
    required this.busy,
    required this.onSubmit,
  });
  final AdminReport report;
  final bool busy;
  final ValueChanged<TripReportResolution> onSubmit;
  @override
  State<AdminTripReportActions> createState() => _AdminTripReportActionsState();
}

class _AdminTripReportActionsState extends State<AdminTripReportActions> {
  final reason = TextEditingController();
  final hiddenPosts = <String>{};
  String userAction = 'NONE';
  String? userId, error;
  List<Map<String, dynamic>> rows(String key) =>
      (widget.report.context[key] as List? ?? [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
  bool get enabled => !widget.busy && widget.report.supportsTripProcessing;

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AdminTripReportActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.id != widget.report.id) {
      hiddenPosts.clear();
      userAction = 'NONE';
      userId = null;
      reason.clear();
      error = null;
    }
    final validUsers = rows('users')
        .where((user) => user['role'] != 'ADMIN')
        .map((user) => user['id'])
        .toSet();
    if (!validUsers.contains(userId)) userId = null;
    final openPosts = rows('posts')
        .where((post) => const ['OPEN', 'FULL'].contains(post['status']))
        .map((post) => post['id'])
        .toSet();
    hiddenPosts.removeWhere((id) => !openPosts.contains(id));
  }

  void submit() {
    if (!enabled) return;
    final actions = <TripReportAction>[];
    final posts = rows('posts');
    for (final id in hiddenPosts) {
      final matches = posts.where(
        (post) =>
            post['id'] == id && const ['OPEN', 'FULL'].contains(post['status']),
      );
      if (matches.length != 1) {
        setState(() => error = 'Bài tuyển đã thay đổi. Hãy tải lại báo cáo.');
        return;
      }
      actions.add(
        TripReportAction(
          type: 'HIDE_POST',
          targetId: id,
          label: 'Ẩn bài: ${matches.single['title'] ?? id}',
        ),
      );
    }
    if (userAction != 'NONE') {
      final users = rows(
        'users',
      ).where((user) => user['id'] == userId && user['role'] != 'ADMIN');
      if (users.length != 1) {
        setState(() => error = 'Hãy chọn rõ tài khoản chịu trách nhiệm.');
        return;
      }
      final user = users.single;
      if (userAction == 'BAN_USER' && user['status'] == 'BANNED') {
        setState(
          () => error = 'Tài khoản đã bị khóa. Hãy chọn hành động khác.',
        );
        return;
      }
      actions.add(
        TripReportAction(
          type: userAction,
          targetId: userId!,
          label:
              '${userAction == 'BAN_USER' ? 'Khóa' : 'Cảnh cáo'} tài khoản: '
              '${user['full_name'] ?? userId}',
        ),
      );
    }
    if (actions.isEmpty || actions.length > 10) {
      setState(() => error = 'Chọn từ 1 đến 10 hành động trước khi kết luận.');
      return;
    }
    if (reason.text.trim().length < 3 || reason.text.trim().length > 500) {
      setState(() => error = 'Nhập nội dung thông báo từ 3 đến 500 ký tự.');
      return;
    }
    setState(() => error = null);
    widget.onSubmit(
      TripReportResolution(reason: reason.text.trim(), actions: actions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = rows(
      'users',
    ).where((user) => user['role'] != 'ADMIN').toList();
    final posts = rows('posts');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Biện pháp xử lý'),
        if (!widget.report.supportsTripProcessing) ...[
          const SizedBox(height: 12),
          const AppInlineNotice(
            message: 'Chưa thể áp dụng biện pháp xử lý. Vui lòng thử lại sau.',
            tone: AppStatusTone.warning,
          ),
        ],
        const SizedBox(height: 12),
        const Text('Bài tuyển liên quan'),
        if (posts.isEmpty) const Text('Chuyến đi không có bài tuyển để ẩn.'),
        for (final post in posts)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(post['title']?.toString() ?? 'Bài tuyển'),
            subtitle: Text(
              const ['OPEN', 'FULL'].contains(post['status'])
                  ? 'Ẩn bài tuyển này'
                  : 'Bài đã đóng/ẩn, không thể chọn lại',
            ),
            value: hiddenPosts.contains(post['id']),
            onChanged:
                enabled && const ['OPEN', 'FULL'].contains(post['status'])
                ? (selected) => setState(() {
                    if (selected == true) {
                      hiddenPosts.add(post['id'].toString());
                    } else {
                      hiddenPosts.remove(post['id']);
                    }
                  })
                : null,
          ),
        const SizedBox(height: 12),
        AppChoiceChips<String>(
          options: const {
            'NONE': 'Không xử lý tài khoản',
            'WARN_USER': 'Cảnh cáo',
            'BAN_USER': 'Khóa tài khoản',
          },
          selected: {userAction},
          enabled: enabled,
          onChanged: (value) => setState(() {
            userAction = value;
            error = null;
          }),
        ),
        if (userAction != 'NONE') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('${widget.report.id}-$userId'),
            initialValue: userId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tài khoản chịu trách nhiệm',
            ),
            hint: const Text('Chọn tài khoản'),
            items: users
                .map(
                  (user) => DropdownMenuItem<String>(
                    value: user['id'].toString(),
                    child: Text(
                      '${user['full_name'] ?? user['id']} · ${user['status'] ?? ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: enabled
                ? (value) => setState(() {
                    userId = value;
                    error = null;
                  })
                : null,
          ),
        ],
        const SizedBox(height: 12),
        CustomTextField(
          label: 'Nội dung thông báo cho đối tượng bị xử lý',
          hint: 'Nhập nội dung gửi đến người bị xử lý…',
          controller: reason,
          enabled: enabled,
          maxLines: 3,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          AppInlineNotice(message: error!, tone: AppStatusTone.error),
        ],
        const SizedBox(height: 12),
        CustomButton(
          text: 'Áp dụng hành động và kết luận',
          isLoading: widget.busy,
          variant: userAction == 'BAN_USER'
              ? AppButtonVariant.destructive
              : AppButtonVariant.primary,
          onPressed: enabled ? submit : null,
        ),
      ],
    );
  }
}
