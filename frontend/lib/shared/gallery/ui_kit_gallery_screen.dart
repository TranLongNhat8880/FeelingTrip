import '../../core/constants/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../ui_kit.dart';

/// Internal design playground; only registered in debug builds.
class UiKitGalleryScreen extends StatefulWidget {
  const UiKitGalleryScreen({super.key});
  @override
  State<UiKitGalleryScreen> createState() => _UiKitGalleryScreenState();
}

class _UiKitGalleryScreenState extends State<UiKitGalleryScreen> {
  final _search = TextEditingController();
  final _money = TextEditingController(text: '1.500.000');
  bool _disabled = false, _loading = false, _error = false, _longText = false;
  bool _showFiltered = true;
  Set<String> _selected = {'Ăn uống'};
  int _tab = 0;
  int? _rawMoney = 1500000;
  String _date = '21/10/2026';
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _search.dispose();
    _money.dispose();
    super.dispose();
  }

  void _feedback(String text) =>
      AppFeedback.show(context, text, tone: AppStatusTone.success);

  Widget _section(
    String title,
    String subtitle,
    Widget child,
    String snippet,
  ) => RepaintBoundary(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 14),
          child,
          const SizedBox(height: 12),
          _CodeSample(code: snippet),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final label = _longText
        ? 'Lưu kế hoạch chuyến đi cùng nhóm bạn của bạn'
        : 'Lưu kế hoạch';
    return AppScaffold(
      title: 'FeelingTrip · UI Kit',
      scrollable: true,
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: _tab,
        onSelected: (index) => setState(() => _tab = index),
        items: const [
          AppNavigationItem(label: 'Khám phá', icon: Icons.explore_outlined),
          AppNavigationItem(
            label: 'Chuyến đi',
            icon: Icons.calendar_month_outlined,
          ),
          AppNavigationItem(
            label: 'Thông báo',
            icon: Icons.notifications_none,
            unreadCount: 3,
          ),
          AppNavigationItem(label: 'Hồ sơ', icon: Icons.person_outline),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Đi cùng nhau.\nNhẹ mọi kế hoạch.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              const Text(
                'Bộ giao diện Travel Modern: Trắng · Charcoal · Xanh Cốm (Lime)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thử các trạng thái',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Disabled'),
                      value: _disabled,
                      onChanged: (v) => setState(() => _disabled = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Loading'),
                      value: _loading,
                      onChanged: (v) => setState(() => _loading = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Error'),
                      value: _error,
                      onChanged: (v) => setState(() => _error = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Văn bản dài'),
                      value: _longText,
                      onChanged: (v) => setState(() => _longText = v),
                    ),
                    const Text(
                      'Nhấn giữ nút để xem phản hồi pressed; chọn chip để thử selected.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _section(
                '01 / Hành động',
                'Nút chính đen, nút phụ có viền, vùng chạm rộng.',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomButton(
                      text: label,
                      icon: Icons.add_rounded,
                      isLoading: _loading,
                      onPressed: _disabled
                          ? null
                          : () => _feedback('Đã nhấn nút chính'),
                    ),
                    const SizedBox(height: 10),
                    CustomButton(
                      text: 'Xem lịch trình',
                      isOutline: true,
                      onPressed: _disabled
                          ? null
                          : () => _feedback('Đã nhấn nút phụ'),
                    ),
                    const SizedBox(height: 10),
                    CustomButton(
                      text: 'Xóa khoản chi',
                      variant: AppButtonVariant.destructive,
                      onPressed: _disabled
                          ? null
                          : () async {
                              final accepted = await AppConfirmDialog.show(
                                context,
                                title: 'Xóa khoản chi?',
                                message:
                                    'Đây là ví dụ xác nhận. Không có dữ liệu thật bị thay đổi.',
                                confirmLabel: 'Xóa khoản chi',
                                destructive: true,
                              );
                              if (accepted && mounted) {
                                _feedback('Đã xác nhận trong bản mẫu');
                              }
                            },
                    ),
                    CustomButton(
                      text: 'Bỏ qua',
                      variant: AppButtonVariant.text,
                      onPressed: _disabled
                          ? null
                          : () => _feedback('Đã bỏ qua'),
                    ),
                    Wrap(
                      spacing: 10,
                      children: [
                        AppIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Quay lại',
                          onPressed: _disabled
                              ? null
                              : () => _feedback('Nút quay lại'),
                        ),
                        AppIconButton(
                          icon: Icons.favorite_border,
                          tooltip: 'Yêu thích',
                          onPressed: _disabled
                              ? null
                              : () => _feedback('Đã chọn yêu thích'),
                        ),
                      ],
                    ),
                  ],
                ),
                "CustomButton(text: 'Tạo chuyến đi', onPressed: handleCreate)",
              ),
              _section(
                '02 / Biểu mẫu',
                'Bo góc 18, focus xanh olive; tiền trả về int?.',
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'Email',
                        hint: 'ban@example.com',
                        enabled: !_disabled,
                        prefixIcon: Icons.mail_outline,
                        errorText: _error ? 'Email chưa đúng định dạng' : null,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        label: 'Mật khẩu',
                        isPassword: true,
                        enabled: !_disabled,
                        helperText: 'Dùng nút mắt để hiện hoặc ẩn mật khẩu',
                      ),
                      const SizedBox(height: 14),
                      AppMoneyField(
                        label: 'Ngân sách dự kiến',
                        controller: _money,
                        enabled: !_disabled,
                        onChanged: (value) => setState(() => _rawMoney = value),
                      ),
                      const SizedBox(height: 8),
                      Text('Giá trị gửi API: ${_rawMoney ?? 'chưa nhập'}'),
                      const SizedBox(height: 14),
                      CustomButton(
                        text: 'Kiểm tra biểu mẫu',
                        isOutline: true,
                        onPressed: _disabled
                            ? null
                            : () => _form.currentState!.validate(),
                      ),
                    ],
                  ),
                ),
                "AppMoneyField(label: 'Ngân sách', allowZero: true, onChanged: (int? value) { /* ViewModel */ })",
              ),
              _section(
                '03 / Tìm kiếm & lựa chọn',
                'Chip nhẹ, bộ lọc bỏ được, chọn ngày qua sheet chuẩn.',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSearchField(
                      controller: _search,
                      hint: 'Tìm chuyến đi hoặc địa điểm',
                      enabled: !_disabled,
                      isLoading: _loading,
                    ),
                    const SizedBox(height: 14),
                    AppChoiceChips<String>(
                      options: const {
                        'Ăn uống': 'Ăn uống',
                        'Khám phá': 'Khám phá',
                        'Nghỉ ngơi': 'Nghỉ ngơi',
                      },
                      selected: _selected,
                      enabled: !_disabled,
                      onChanged: (value) => setState(() {
                        _selected = {..._selected};
                        _selected.contains(value)
                            ? _selected.remove(value)
                            : _selected.add(value);
                      }),
                    ),
                    const SizedBox(height: 12),
                    FilterBar(
                      children: [
                        if (_showFiltered)
                          AppFilterChip(
                            label: 'Đà Lạt',
                            icon: Icons.location_on_outlined,
                            onDeleted: _disabled
                                ? null
                                : () => setState(() => _showFiltered = false),
                          ),
                        TextButton(
                          onPressed: () => setState(() => _showFiltered = true),
                          child: const Text('Đặt lại lọc'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppSelectionField(
                      label: 'Ngày khởi hành',
                      value: _date,
                      enabled: !_disabled,
                      icon: Icons.calendar_today_outlined,
                      onTap: () async {
                        final date = await AppPickers.date(
                          context,
                          first: DateTime(2020),
                          last: DateTime(2040),
                        );
                        if (date != null && mounted) {
                          setState(() => _date = AppUtils.formatDate(date));
                        }
                      },
                    ),
                  ],
                ),
                "AppChoiceChips<String>(options: options, selected: selected, onChanged: select)",
              ),
              _section(
                '04 / Thẻ & thông tin',
                'Thẻ trắng 24, khoảng trắng thoáng, trạng thái có chữ và icon.',
                Column(
                  children: [
                    AppCard(
                      softShadow: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const AvatarPlaceholder(name: 'Nhật'),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _longText
                                      ? 'Chuyến đi Đà Lạt cùng những người bạn thân thiết'
                                      : 'Đà Lạt cùng nhau',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const AppStatusBadge(
                            label: 'Sắp khởi hành',
                            tone: AppStatusTone.info,
                          ),
                          const SizedBox(height: 12),
                          const InfoRow(
                            label: 'Ngày đi',
                            value: '21 – 23/10/2026',
                            icon: Icons.calendar_today_outlined,
                          ),
                          const InfoRow(
                            label: 'Địa điểm',
                            value: 'Đà Lạt, Lâm Đồng',
                            icon: Icons.location_on_outlined,
                          ),
                          const Divider(),
                          const SizedBox(height: 16),
                          const AvatarGroup(
                            people: [
                              AppAvatarData(name: 'Nhật'),
                              AppAvatarData(name: 'Phú'),
                              AppAvatarData(name: 'Thành'),
                              AppAvatarData(name: 'Tùng'),
                              AppAvatarData(name: 'Lan'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppStatusBadge(
                          label: 'Đã thanh toán',
                          tone: AppStatusTone.success,
                        ),
                        AppStatusBadge(
                          label: 'Đang chờ',
                          tone: AppStatusTone.warning,
                        ),
                        AppStatusBadge(
                          label: 'Đã hủy',
                          tone: AppStatusTone.error,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const SummaryTile(
                      label: 'Ngân sách còn lại',
                      value: '2.400.000 đ',
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.primarySurface,
                    ),
                    const SizedBox(height: 16),
                    const SectionHeader(
                      title: 'Khám phá địa điểm du lịch',
                      subtitle:
                          'Phong cách Travel Modern: Danh mục bo tròn & Thẻ tràn viền có thanh frosted glass.',
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          AppCategoryPill(
                            label: 'Parks',
                            icon: Icons.park_outlined,
                            selected: true,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          AppCategoryPill(
                            label: 'Shops',
                            icon: Icons.storefront_outlined,
                            selected: false,
                            onTap: () {},
                          ),
                          const SizedBox(width: 8),
                          AppCategoryPill(
                            label: 'Cafes',
                            icon: Icons.coffee_outlined,
                            selected: false,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppPlaceCard(
                      title: 'Jardim do Torel',
                      location: 'Praça da Estrela, 1200-667',
                      distance: '4.0 km',
                      rating: 4.1,
                      isFavorite: true,
                      onTap: () => _feedback('Mở địa điểm Jardim do Torel'),
                      onFavoriteTap: () =>
                          _feedback('Đã thêm Jardim do Torel vào yêu thích!'),
                    ),
                  ],
                ),
                "AppPlaceCard(title: 'Jardim do Torel', distance: '4.0 km', rating: 4.1)",
              ),
              _section(
                '05 / Dialog & bottom sheet',
                'Thử mở, đóng, hủy và xác nhận.',
                Column(
                  children: [
                    CustomButton(
                      text: 'Mở thông báo thành công',
                      onPressed: () => AppMessageDialog.show(
                        context,
                        title: 'Đã lưu kế hoạch',
                        message: 'Mọi thứ đã sẵn sàng cho chuyến đi tiếp theo.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    CustomButton(
                      text: 'Mở bottom sheet',
                      isOutline: true,
                      onPressed: () => AppBottomSheet.show<void>(
                        context,
                        title: 'Chọn cách chia tiền',
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final method in [
                              'Chia đều',
                              'Số tiền cụ thể',
                              'Theo phần trăm',
                            ])
                              ListTile(
                                title: Text(method),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.pop(context);
                                  _feedback('Đã chọn $method');
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    CustomButton(
                      text: 'Hiện thông báo lỗi',
                      variant: AppButtonVariant.text,
                      onPressed: () => AppFeedback.show(
                        context,
                        'Chưa kết nối được máy chủ. Thử lại sau.',
                        tone: AppStatusTone.error,
                      ),
                    ),
                  ],
                ),
                "final confirmed = await AppConfirmDialog.show(context, title: 'Rời chuyến đi?', message: 'Bạn muốn tiếp tục?');",
              ),
              _section(
                '06 / Loading, dữ liệu rỗng & lỗi',
                'Không suy ra thành công khi mất mạng.',
                Column(
                  children: [
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: LoadingIndicator(message: 'Đang tải chuyến đi…'),
                      ),
                    const AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(height: 100, radius: 18),
                          SizedBox(height: 12),
                          Skeleton(width: 180),
                          SizedBox(height: 8),
                          Skeleton(width: 110),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_error)
                      InlineError(
                        message: 'Chưa lưu được khoản chi.',
                        onRetry: () => _feedback('Đang thử lại'),
                      ),
                    EmptyStateWidget(
                      icon: Icons.explore_outlined,
                      title: 'Chuyến đi đầu tiên đang chờ',
                      message:
                          'Lên kế hoạch và rủ những người bạn cùng khám phá.',
                      buttonText: 'Tạo chuyến đi',
                      onButtonPressed: () =>
                          _feedback('Mở chức năng tạo chuyến đi'),
                    ),
                    ErrorState(
                      message: 'Kiểm tra kết nối rồi thử lại.',
                      onRetry: () => _feedback('Đang tải lại'),
                    ),
                    PaginationFooter(
                      isLoading: _loading,
                      hasMore: true,
                      errorMessage: _error
                          ? 'Chưa tải được trang tiếp theo'
                          : null,
                      onLoadMore: () => _feedback('Đang tải thêm'),
                    ),
                  ],
                ),
                "ErrorState(message: 'Mất kết nối', onRetry: reload)",
              ),
              _section(
                '07 / Ảnh & tệp',
                'Phần giao diện nhận callback chọn/upload từ feature.',
                Column(
                  children: [
                    ImagePickerField(
                      label: 'Chọn ảnh chuyến đi',
                      enabled: !_disabled,
                      onPick: () =>
                          _feedback('Nối callback chọn ảnh trong feature'),
                      preview: const AppImage(),
                    ),
                    const SizedBox(height: 14),
                    AttachmentPreview(
                      name: 'hoa-don-bua-toi.jpg',
                      progress: _loading ? .45 : null,
                      error: _error ? 'Upload chưa hoàn tất' : null,
                      onRemove: () => _feedback('Xóa ảnh trong bản mẫu'),
                      onRetry: () => _feedback('Thử upload lại'),
                    ),
                  ],
                ),
                "ImagePickerField(label: 'Ảnh hóa đơn', onPick: pickImage, preview: preview)",
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeSample extends StatelessWidget {
  const _CodeSample({required this.code});
  final String code;
  @override
  Widget build(BuildContext context) => AppCard(
    color: AppColors.background,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Ví dụ sử dụng',
                style: TextStyle(fontSize: AppSizes.fontCaption),
              ),
            ),
            IconButton(
              tooltip: 'Copy đoạn mẫu',
              icon: const Icon(Icons.copy_outlined, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  AppFeedback.show(
                    context,
                    'Đã copy đoạn mẫu',
                    tone: AppStatusTone.success,
                  );
                }
              },
            ),
          ],
        ),
        SelectableText(
          code,
          style: const TextStyle(fontSize: AppSizes.fontCaption),
        ),
      ],
    ),
  );
}
