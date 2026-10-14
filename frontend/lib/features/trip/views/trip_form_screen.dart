import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/ui_kit.dart';
import '../../map/models/place_search_result.dart';
import '../../map/views/place_location_picker_screen.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../viewmodels/trip_viewmodel.dart';

class TripFormScreen extends StatefulWidget {
  const TripFormScreen({super.key, this.repository, this.trip});
  final TripRepository? repository;
  final TripModel? trip;

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  static const int _maxImageSize = 5 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final TripViewModel _viewModel;
  late final TextEditingController _name;
  late final TextEditingController _destination;
  late final TextEditingController _budget;
  late final TextEditingController _description;
  late final TextEditingController _startLabel;
  late final TextEditingController _endLabel;
  late DateTime _startDate;
  late DateTime _endDate;
  late bool _isPublic;
  Uint8List? _coverImageBytes;
  String? _coverImageFileName;
  bool _removeExistingCover = false;
  bool _showExtras = false;
  String? _destinationProvider;
  String? _destinationExternalId;
  double? _destinationLatitude;
  double? _destinationLongitude;

  bool get _editing => widget.trip != null;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    _showExtras = _editing;
    _viewModel = TripViewModel(repository: widget.repository)
      ..addListener(_onChanged);
    _name = TextEditingController(text: trip?.name);
    _destination = TextEditingController(text: trip?.destination);
    _destinationProvider = trip?.destinationProvider;
    _destinationExternalId = trip?.destinationExternalId;
    _destinationLatitude = trip?.destinationLatitude;
    _destinationLongitude = trip?.destinationLongitude;
    _budget = TextEditingController(
      text: VndInputFormatter.format('${trip?.estimatedBudget ?? 0}'),
    );
    _description = TextEditingController(text: trip?.description);
    final today = DateUtils.dateOnly(DateTime.now());
    _startDate = trip?.startDate != null
        ? DateUtils.dateOnly(trip!.startDate)
        : today.add(const Duration(days: 7));
    _endDate = trip?.endDate != null
        ? DateUtils.dateOnly(trip!.endDate)
        : _startDate.add(const Duration(days: 2));
    if (_endDate.isBefore(_startDate)) {
      _endDate = _startDate;
    }
    _startLabel = TextEditingController(text: AppUtils.formatDate(_startDate));
    _endLabel = TextEditingController(text: AppUtils.formatDate(_endDate));
    _isPublic = trip?.isPublic ?? false;
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    for (final controller in [
      _name,
      _destination,
      _budget,
      _description,
      _startLabel,
      _endLabel,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    if (_viewModel.isSubmitting) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh mới'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    XFile? picked;
    try {
      picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        error.code == 'camera_access_denied'
            ? 'Ứng dụng chưa được cấp quyền sử dụng camera.'
            : 'Không thể mở trình chọn ảnh trên thiết bị này.',
        tone: AppStatusTone.error,
      );
      return;
    }
    if (picked == null) return;

    final extension = picked.name.split('.').last.toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        'Ảnh phải có định dạng JPG, JPEG, PNG hoặc WEBP.',
        tone: AppStatusTone.error,
      );
      return;
    }

    final fileName = picked.name;
    final bytes = await picked.readAsBytes();
    if (bytes.length > _maxImageSize) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        'Dung lượng ảnh không được vượt quá 5 MB.',
        tone: AppStatusTone.error,
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _coverImageBytes = bytes;
      _coverImageFileName = fileName;
      _removeExistingCover = false;
    });
  }

  void _removeCoverImage() {
    if (_viewModel.isSubmitting) return;
    setState(() {
      if (_coverImageBytes != null) {
        _coverImageBytes = null;
        _coverImageFileName = null;
      } else {
        _removeExistingCover = true;
      }
    });
  }

  Widget? _coverPreview() {
    if (_coverImageBytes != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.memory(_coverImageBytes!, fit: BoxFit.cover),
            ),
          ),
          AttachmentPreview(
            name: _coverImageFileName ?? 'Ảnh bìa chuyến đi',
            onRemove: _removeCoverImage,
          ),
        ],
      );
    }
    final existing = widget.trip?.coverImageUrl;
    if (!_removeExistingCover && existing?.isNotEmpty == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppImage(
            url: existing,
            aspectRatio: 16 / 9,
            semanticLabel: 'Ảnh bìa hiện tại của chuyến đi',
          ),
          AttachmentPreview(
            name: 'Ảnh bìa hiện tại',
            onRemove: _removeCoverImage,
          ),
        ],
      );
    }
    return null;
  }

  Future<void> _pickDestinationFromMap() async {
    PlaceSearchResult? initial;
    if (_destinationLatitude != null && _destinationLongitude != null) {
      initial = PlaceSearchResult(
        id: _destinationExternalId ?? '',
        name: _destination.text,
        formattedAddress: _destination.text,
        latitude: _destinationLatitude!,
        longitude: _destinationLongitude!,
      );
    }
    final result = await Navigator.push<PlaceSearchResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceLocationPickerScreen(initialLocation: initial),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _destination.text = result.name;
      _destinationProvider = 'GEOAPIFY';
      _destinationExternalId = result.id;
      _destinationLatitude = result.latitude;
      _destinationLongitude = result.longitude;
    });
  }

  Widget _destinationCoordinatesBadge() {
    if (_destinationLatitude == null || _destinationLongitude == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pin_drop_rounded,
                    size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Tọa độ: ${_destinationLatitude!.toStringAsFixed(4)}, ${_destinationLongitude!.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    setState(() {
                      _destinationProvider = null;
                      _destinationExternalId = null;
                      _destinationLatitude = null;
                      _destinationLongitude = null;
                    });
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool start}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final minStartDate =
        (_editing &&
            widget.trip != null &&
            DateUtils.dateOnly(widget.trip!.startDate).isBefore(today))
        ? DateUtils.dateOnly(widget.trip!.startDate)
        : today;

    final firstDate = start ? minStartDate : _startDate;
    final lastDate = today.add(const Duration(days: 730));

    final currentInitial = start ? _startDate : _endDate;
    final initialDate = currentInitial.isBefore(firstDate)
        ? firstDate
        : (currentInitial.isAfter(lastDate) ? lastDate : currentInitial);

    final value = await AppPickers.date(
      context,
      initial: initialDate,
      first: firstDate,
      last: lastDate,
    );
    if (value == null) return;
    setState(() {
      if (start) {
        _startDate = value;
        if (_endDate.isBefore(value)) {
          _endDate = value;
        }
      } else {
        _endDate = value;
      }
      _startLabel.text = AppUtils.formatDate(_startDate);
      _endLabel.text = AppUtils.formatDate(_endDate);
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _showExtras = true);
      return;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    if (!_editing && _startDate.isBefore(today)) {
      AppFeedback.show(
        context,
        'Ngày bắt đầu chuyến đi không thể ở trong quá khứ.',
        tone: AppStatusTone.error,
      );
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      AppFeedback.show(
        context,
        'Ngày kết thúc không thể trước ngày bắt đầu.',
        tone: AppStatusTone.error,
      );
      return;
    }
    final data = TripFormData(
      name: _name.text.trim().isEmpty ? null : _name.text,
      destination: _destination.text,
      startDate: _startDate,
      endDate: _endDate,
      estimatedBudget: VndInputFormatter.parse(_budget.text) ?? 0,
      privacyType: _isPublic ? 'PUBLIC' : 'PRIVATE',
      description: _description.text.isEmpty ? null : _description.text,
      coverImageUrl: _removeExistingCover ? '' : widget.trip?.coverImageUrl,
      coverImageBytes: _coverImageBytes,
      coverImageFileName: _coverImageFileName,
      destinationProvider: _destinationProvider,
      destinationExternalId: _destinationExternalId,
      destinationLatitude: _destinationLatitude,
      destinationLongitude: _destinationLongitude,
    );
    final result = _editing
        ? await _viewModel.updateTrip(widget.trip!, data)
        : await _viewModel.createTrip(data);
    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context, result);
    } else {
      AppFeedback.show(
        context,
        _viewModel.errorMessage ?? 'Chưa lưu được chuyến đi.',
        tone: AppStatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: _editing ? 'Chỉnh sửa chuyến đi' : 'Tạo chuyến đi',
    scrollable: true,
    bottomAction: CustomButton(
      text: _editing ? 'Lưu thay đổi' : 'Tạo chuyến đi',
      isLoading: _viewModel.isSubmitting,
      onPressed: _viewModel.isSubmitting ? null : _save,
    ),
    body: AbsorbPointer(
      absorbing: _viewModel.isSubmitting,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _editing
                  ? 'Cập nhật thông tin chung của hành trình.'
                  : 'Chỉ cần điểm đến và thời gian. Các thông tin còn lại có thể bổ sung sau.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: 'Thông tin cơ bản',
              subtitle: 'Điểm đến và thời gian giúp nhóm bắt đầu lên kế hoạch.',
            ),
            const SizedBox(height: 10),
            CustomTextField(
              label: _editing ? 'Tên chuyến đi' : 'Tên chuyến đi (tùy chọn)',
              hint: 'Bỏ trống để hệ thống tự đặt tên',
              controller: _name,
              prefixIcon: Icons.luggage_outlined,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty && !_editing) return null;
                return text.length < 2
                    ? 'Tên chuyến đi cần ít nhất 2 ký tự'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Điểm đến',
              hint: 'Ví dụ: Đà Lạt, Phú Quốc, Hội An',
              controller: _destination,
              prefixIcon: Icons.location_on_outlined,
              suffixIcon: IconButton(
                tooltip: 'Chọn trên bản đồ',
                icon: const Icon(
                  Icons.map_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                onPressed: _pickDestinationFromMap,
              ),
              validator: (value) => (value ?? '').trim().length < 2
                  ? 'Vui lòng nhập điểm đến'
                  : null,
            ),
            _destinationCoordinatesBadge(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Ngày đi',
                    controller: _startLabel,
                    readOnly: true,
                    onTap: () => _pickDate(start: true),
                    prefixIcon: Icons.flight_takeoff_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'Ngày về',
                    controller: _endLabel,
                    readOnly: true,
                    onTap: () => _pickDate(start: false),
                    prefixIcon: Icons.flight_land_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppInlineNotice(
              message:
                  '${_endDate.difference(_startDate).inDays + 1} ngày · ${AppUtils.formatDate(_startDate)} – ${AppUtils.formatDate(_endDate)}',
            ),
            const SizedBox(height: 24),
            Text(
              'Ai có thể xem chuyến đi?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.lock_outline_rounded),
                  label: Text('Nhóm riêng tư'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.public_rounded),
                  label: Text('Nhóm công khai'),
                ),
              ],
              selected: {_isPublic},
              onSelectionChanged: (values) {
                setState(() => _isPublic = values.first);
              },
            ),
            const SizedBox(height: 10),
            AppInlineNotice(
              message: _isPublic
                  ? 'Nhóm công khai yêu cầu trưởng nhóm đã xác minh eKYC. Sau khi tạo, bạn có thể đăng bài tìm bạn đồng hành.'
                  : 'Nhóm riêng tư chỉ nhận thành viên qua mã hoặc lời mời.',
              tone: _isPublic ? AppStatusTone.warning : AppStatusTone.info,
            ),
            const SizedBox(height: 20),
            AppCard(
              outlined: true,
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                key: ValueKey(_showExtras),
                initiallyExpanded: _showExtras,
                onExpansionChanged: (value) => _showExtras = value,
                title: const Text('Thiết lập thêm (tùy chọn)'),
                subtitle: const Text('Ngân sách, mô tả và ảnh bìa'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                children: [
                  AppMoneyField(
                    label: 'Ngân sách dự kiến',
                    controller: _budget,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Mô tả',
                    hint: 'Mục tiêu, phong cách hoặc ghi chú cho cả nhóm',
                    controller: _description,
                    maxLines: 4,
                    prefixIcon: Icons.notes_outlined,
                  ),
                  const SizedBox(height: 14),
                  ImagePickerField(
                    label:
                        _coverImageBytes == null &&
                            (widget.trip?.coverImageUrl == null ||
                                _removeExistingCover)
                        ? 'Chọn ảnh bìa'
                        : 'Chọn ảnh bìa khác',
                    enabled: !_viewModel.isSubmitting,
                    onPick: _pickCoverImage,
                    preview: _coverPreview(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const AppInlineNotice(
              message:
                  'Thành viên, lịch trình và chi phí được thiết lập sau khi chuyến đi được tạo thành công.',
            ),
            if (_viewModel.errorMessage != null) ...[
              const SizedBox(height: 12),
              AppInlineNotice(
                message: _viewModel.errorMessage!,
                tone: AppStatusTone.error,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}
