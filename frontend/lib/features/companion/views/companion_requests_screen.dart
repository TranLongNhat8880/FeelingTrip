import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../models/companion_request_model.dart';
import '../viewmodels/companion_requests_viewmodel.dart';

class CompanionRequestsScreen extends StatefulWidget {
  const CompanionRequestsScreen({super.key});
  @override
  State<CompanionRequestsScreen> createState() =>
      _CompanionRequestsScreenState();
}

class _CompanionRequestsScreenState extends State<CompanionRequestsScreen> {
  final _vm = CompanionRequestsViewModel();
  final _searchController = TextEditingController();
  final Map<String, String> _posts = {};
  @override
  void initState() {
    super.initState();
    _vm.addListener(_onChanged);
    _vm.load();
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    _searchController.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {
      for (final request in _vm.requests) {
        _posts[request.postId] = request.tripName ?? 'Chuyến đi';
      }
    });
    final message = _vm.errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      _vm.clearMessages();
    }
  }

  Future<void> _review(CompanionRequest request, String status) async {
    if (status == 'ACCEPTED' && !request.requester.isVerified) {
      await AppMessageDialog.show(
        context,
        title: 'Chưa xác minh danh tính',
        message:
            'Người dùng này chưa hoàn thành xác minh CCCD (eKYC). Theo quy định an toàn, chỉ thành viên đã xác minh mới được duyệt vào chuyến đi.',
        tone: AppStatusTone.warning,
      );
      return;
    }
    final confirmed = await AppConfirmDialog.show(
      context,
      title: status == 'ACCEPTED' ? 'Chấp nhận yêu cầu?' : 'Từ chối yêu cầu?',
      message: request.requester.displayName,
      confirmLabel: status == 'ACCEPTED' ? 'Chấp nhận' : 'Từ chối',
    );
    if (mounted && confirmed) await _vm.reviewRequest(request.id, status);
  }

  @override
  Widget build(BuildContext context) {
    final requests = _vm.visibleRequests;
    return AppScaffold(
      title: 'Yêu cầu tham gia',
      padding: EdgeInsets.zero,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.documentMaxWidth,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: AppSearchField(
                    controller: _searchController,
                    hint: 'Tên người gửi yêu cầu',
                    onChanged: (value) => _vm.filterLocal(query: value),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: AppDropdownField<String>(
                    label: 'Lọc theo chuyến đi',
                    value: _vm.selectedPostId,
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Tất cả chuyến đi'),
                      ),
                      for (final post in _posts.entries)
                        DropdownMenuItem(
                          value: post.key,
                          child: Text(
                            post.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => _vm.filterLocal(postId: value),
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final tab in const {
                        'PENDING': 'Chờ duyệt',
                        'ACCEPTED': 'Đã duyệt',
                        'REJECTED': 'Từ chối',
                        '': 'Tất cả',
                      }.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppChoiceChips<String>(
                            options: {tab.key: tab.value},
                            selected: {_vm.filterStatus},
                            onChanged: (_) => _vm.setFilter(tab.key),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _vm.isLoading
                      ? const Center(child: LoadingIndicator())
                      : requests.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.inbox_outlined,
                          title: 'Chưa có yêu cầu nào',
                          message: 'Thử thay đổi trạng thái hoặc chuyến đi.',
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () => _vm.load(refresh: true),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: requests.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _requestRow(requests[index]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _requestRow(CompanionRequest request) {
    final user = request.requester;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AvatarPlaceholder(
                name: user.displayName,
                imageUrl: user.avatarUrl,
                radius: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ] else ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFFB74D),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'Chưa eKYC',
                              style: text.labelSmall?.copyWith(
                                color: const Color(0xFFE65100),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.star,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${user.trustScore.toStringAsFixed(1)} · ${user.reviewCount} đánh giá',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('dd/MM').format(request.createdAt),
                  style: text.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (request.introduction?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: .5),
                ),
              ),
              child: Text(
                request.introduction!,
                style: text.bodySmall?.copyWith(
                  color: const Color(0xFF2C3E50),
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (request.isPending)
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Từ chối',
                    variant: AppButtonVariant.secondary,
                    onPressed: _vm.isReviewing
                        ? null
                        : () => _review(request, 'REJECTED'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CustomButton(
                    text: 'Chấp nhận',
                    onPressed: _vm.isReviewing
                        ? null
                        : () => _review(request, 'ACCEPTED'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                AppStatusBadge(
                  label: request.isAccepted ? 'Đã chấp nhận' : 'Đã từ chối',
                  tone: request.isAccepted
                      ? AppStatusTone.success
                      : AppStatusTone.error,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
