import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:feeling_trip/core/constants/app_colors.dart';
import 'package:feeling_trip/core/constants/app_sizes.dart';
import 'package:feeling_trip/shared/ui_kit.dart';
import '../repositories/companion_repository.dart';
import '../models/companion_post_model.dart';
import '../repositories/mock_companion_repository.dart';
import '../repositories/api_companion_repository.dart';
import '../repositories/companion_trip_repository.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

// ================================================================================
// SCREEN: Create Companion Post
// ================================================================================
// Màn hình tạo bài đăng tìm bạn đồng hành cho chuyến đi.
// ================================================================================

class CreateCompanionPostScreen extends StatefulWidget {
  const CreateCompanionPostScreen({
    super.key,
    this.repository,
    this.tripRepository,
    this.post,
    this.tripId,
    this.tripName,
    this.tripDestination,
  });

  final CompanionRepository? repository;
  final CompanionTripRepository? tripRepository;
  final CompanionPost? post;
  final String? tripId;
  final String? tripName;
  final String? tripDestination;

  @override
  State<CreateCompanionPostScreen> createState() =>
      _CreateCompanionPostScreenState();
}

class _CreateCompanionPostScreenState extends State<CreateCompanionPostScreen> {
  late final CompanionRepository _repo;
  late final _tripRepo = widget.tripRepository ?? CompanionTripRepository();

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _minAgeController = TextEditingController();
  final _maxAgeController = TextEditingController();

  int _recruitmentCount = 1;
  int _currentMembersCount = 1;
  String? _tripImage;
  String _genderPreference = 'ANY';
  final Set<String> _selectedTags = {};
  bool _isSubmitting = false;

  // Danh sách chuyến đi mẫu để leader chọn
  List<Map<String, String>> _availableTrips = [];
  bool _loadingTrips = false;
  bool _alreadyPosted = false;
  bool _privateTrip = false;
  String? _tripError;
  static const List<Map<String, String>> _mockTrips = [
    {
      'id': 'trip-1',
      'name': 'Hành trình di sản Hội An – Đà Nẵng 4N3Đ',
      'destination': 'Hội An, Quảng Nam',
    },
    {
      'id': 'trip-2',
      'name': 'Fansipan – Nóc nhà Đông Dương',
      'destination': 'Sapa, Lào Cai',
    },
    {
      'id': 'trip-3',
      'name': 'Chinh phục Mã Pí Lèng & Đồng Văn',
      'destination': 'Hà Giang',
    },
    {
      'id': 'trip-4',
      'name': 'Kỳ nghỉ biển đảo Phú Quốc',
      'destination': 'Phú Quốc, Kiên Giang',
    },
    {
      'id': 'trip-5',
      'name': 'Săn mây Đà Lạt 3 ngày cuối tuần',
      'destination': 'Đà Lạt, Lâm Đồng',
    },
  ];
  String _selectedTripId = '';

  final List<String> _availableTags = [
    'Phượt',
    'Nhiếp ảnh',
    'Văn hóa',
    'Ẩm thực',
    'Leo núi',
    'Biển đảo',
    'Tiết kiệm',
    'Chill',
    'Khám phá',
  ];

  @override
  void initState() {
    super.initState();
    _repo =
        widget.repository ??
        (ApiEndpoints.useMockData
            ? MockCompanionRepository()
            : ApiCompanionRepository());
    _availableTrips = ApiEndpoints.useMockData ? List.of(_mockTrips) : [];
    _selectedTripId =
        widget.tripId ??
        (_availableTrips.isEmpty ? '' : _availableTrips.first['id']!);
    if (widget.post == null) _loadTrips();
    final post = widget.post;
    if (post != null) {
      _selectedTripId = post.trip.id;
      _titleController.text = post.title ?? '';
      _contentController.text = post.content ?? '';
      _minAgeController.text = post.minAge?.toString() ?? '';
      _maxAgeController.text = post.maxAge?.toString() ?? '';
      _currentMembersCount = post.currentMembersCount;
      _recruitmentCount = post.slotsLeft.clamp(0, 49);
      _tripImage = post.trip.coverImageUrl;
      _genderPreference = post.genderPreference;
      _selectedTags
        ..clear()
        ..addAll(post.tags);
    }
  }

  Future<void> _loadTrips() async {
    setState(() {
      _loadingTrips = true;
      _tripError = null;
    });
    try {
      if (widget.tripId != null) {
        final exists = await _tripRepo.hasPostForTrip(widget.tripId!);
        final trip = await _tripRepo.getTrip(widget.tripId!);
        if (mounted) {
          setState(() {
            _alreadyPosted = exists;
            _privateTrip = trip['privacyType'] != 'PUBLIC';
            _currentMembersCount = int.tryParse(trip['memberCount'] ?? '') ?? 1;
            _tripImage = trip['image'];
          });
        }
      } else {
        final trips = ApiEndpoints.useMockData
            ? List<Map<String, String>>.of(_mockTrips)
            : await _tripRepo.getMyTrips();
        final available = <Map<String, String>>[];
        for (final trip in trips) {
          final posted = ApiEndpoints.useMockData
              ? await _tripRepo.hasPostForTrip(trip['id']!)
              : trip['hasCompanionPost'] == 'true';
          if (!posted) available.add(trip);
        }
        if (mounted) {
          setState(() {
            _availableTrips = available;
            if (!available.any((t) => t['id'] == _selectedTripId)) {
              _selectedTripId = available.isEmpty ? '' : available.first['id']!;
            }
            _updateSelectedTrip();
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _tripError = 'Không tải được chuyến đi.');
    } finally {
      if (mounted) setState(() => _loadingTrips = false);
    }
  }

  void _updateSelectedTrip() {
    final trip = _availableTrips
        .where((trip) => trip['id'] == _selectedTripId)
        .firstOrNull;
    _privateTrip = trip?['privacyType'] == 'PRIVATE';
    _currentMembersCount = int.tryParse(trip?['memberCount'] ?? '') ?? 1;
    _tripImage = trip?['image'];
  }

  String? _validateAge(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final age = int.tryParse(value.trim());
    if (age == null || age < 16 || age > 100) return 'Nhập tuổi từ 16 đến 100';
    return null;
  }

  String? _validateMaxAge(String? value) {
    final error = _validateAge(value);
    if (error != null) return error;
    final minAge = int.tryParse(_minAgeController.text.trim());
    final maxAge = int.tryParse(value?.trim() ?? '');
    if (minAge != null && maxAge != null && minAge > maxAge) {
      return 'Tuổi tối đa phải từ $minAge trở lên';
    }
    return null;
  }

  Future<void> _makePublic() async {
    if (_isSubmitting || _loadingTrips || _selectedTripId.isEmpty) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Chuyển chuyến đi sang công khai?',
      message:
          'Đổi quyền riêng tư của chuyến đi để đăng bài tìm bạn đồng hành. Sau khi đổi, bạn có thể tiếp tục hoàn thiện và đăng bài tuyển.',
      confirmLabel: 'Chuyển sang công khai',
    );
    if (!confirmed || !mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await _tripRepo.makePublic(_selectedTripId);
      if (!mounted) return;
      await _loadTrips();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : 'Không đổi được quyền riêng tư. Hãy thử lại.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting ||
        _loadingTrips ||
        _alreadyPosted ||
        _privateTrip ||
        _tripError != null ||
        !_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedTripId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy chọn chuyến đi do bạn làm trưởng nhóm.'),
        ),
      );
      return;
    }

    final ageError =
        _validateAge(_minAgeController.text) ??
        _validateAge(_maxAgeController.text);
    if (ageError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ageError)));
      return;
    }
    final minAge = int.tryParse(_minAgeController.text.trim());
    final maxAge = int.tryParse(_maxAgeController.text.trim());

    if (minAge != null && maxAge != null && minAge > maxAge) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tuổi tối thiểu không được lớn hơn tuổi tối đa!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.post != null) {
        await _repo.updatePost(widget.post!.id, {
          'title': _titleController.text.trim(),
          if (_contentController.text.trim().isNotEmpty)
            'content': _contentController.text.trim(),
          'recruitmentCount': _recruitmentCount,
          'minAge': minAge,
          'maxAge': maxAge,
          'genderPreference': _genderPreference,
          'tags': _selectedTags.isEmpty ? null : _selectedTags.toList(),
        });
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final newPost = await _repo.createPost(
        tripId: _selectedTripId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim().isNotEmpty
            ? _contentController.text.trim()
            : null,
        recruitmentCount: _recruitmentCount,
        minAge: minAge,
        maxAge: maxAge,
        genderPreference: _genderPreference,
        tags: _selectedTags.toList(),
      );

      if (!mounted) return;
      Navigator.pop(context, newPost);
    } catch (e) {
      if (!mounted) return;
      if (widget.post == null && e is ApiException && e.statusCode == 409) {
        await _loadTrips();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppScaffold(
      title: widget.post == null ? 'Đăng bài tìm bạn' : 'Sửa bài tìm bạn',
      padding: EdgeInsets.zero,
      bottomAction: CustomButton(
        text: _alreadyPosted
            ? 'Đã đăng bài'
            : _privateTrip
            ? 'Chuyển sang công khai'
            : widget.post == null
            ? 'Đăng bài'
            : 'Lưu thay đổi',
        isLoading: _isSubmitting,
        onPressed:
            _loadingTrips ||
                _alreadyPosted ||
                _tripError != null ||
                (widget.post == null && _selectedTripId.isEmpty)
            ? null
            : _privateTrip
            ? _makePublic
            : _submit,
      ),
      body: ColoredBox(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Chọn chuyến đi ──────────────────────────────────────────
                Text('Chuyến đi gắn liền *', style: text.titleSmall),
                const SizedBox(height: 8),
                if (_loadingTrips) const LoadingIndicator(),
                if (_alreadyPosted)
                  const AppInlineNotice(
                    message:
                        'Chuyến đi này đã có bài tuyển đang hoạt động. Bạn có thể sửa hoặc đóng bài trong Bài tuyển của tôi.',
                    tone: AppStatusTone.info,
                  ),
                if (_tripError != null)
                  ErrorState(message: _tripError!, onRetry: _loadTrips),
                if (widget.tripId != null || widget.post != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: Row(
                      children: [
                        if (_tripImage?.trim().isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _tripImage!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.tripName ??
                                    widget.post?.trip.name ??
                                    _selectedTripId,
                                style: text.titleSmall?.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.tripDestination != null)
                                Text(
                                  widget.tripDestination!,
                                  style: text.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        AppStatusBadge(
                          label: _privateTrip ? 'Riêng tư' : 'Công khai',
                          tone: _privateTrip
                              ? AppStatusTone.neutral
                              : AppStatusTone.success,
                        ),
                      ],
                    ),
                  )
                else
                  AppDropdownField<String>(
                    label: 'Chọn chuyến đi',
                    isDense: false,
                    value: _selectedTripId.isEmpty ? null : _selectedTripId,
                    items: _availableTrips.map((t) {
                      return DropdownMenuItem<String>(
                        value: t['id'],
                        child: Row(
                          children: [
                            if (t['image']?.trim().isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    t['image']!,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t['name'] ?? '',
                                    maxLines: 1,
                                    style: text.titleSmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    "${t['destination']}${t['privacyType'] == 'PRIVATE' ? ' · Riêng tư' : ''}",
                                    maxLines: 1,
                                    style: text.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedTripId = val;
                          _updateSelectedTrip();
                        });
                      }
                    },
                  ),
                const SizedBox(height: 16),

                // ── Tiêu đề bài đăng ────────────────────────────────────────
                CustomTextField(
                  label: 'Tiêu đề bài đăng *',
                  controller: _titleController,
                  hint: 'VD: Tìm 2 bạn nữ đi Sapa săn mây cuối tuần...',
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập tiêu đề bài đăng';
                    }
                    if (val.trim().length < 5) {
                      return 'Tiêu đề cần ít nhất 5 ký tự';
                    }
                    if (val.trim().length > 255) {
                      return 'Tiêu đề tối đa 255 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Nội dung chi tiết ───────────────────────────────────────
                CustomTextField(
                  label: 'Lời nhắn *',
                  validator: (value) {
                    final content = value?.trim() ?? '';
                    if (content.length < 3) {
                      return 'Nội dung cần ít nhất 3 ký tự';
                    }
                    if (content.length > 5000) {
                      return 'Nội dung tối đa 5000 ký tự';
                    }
                    return null;
                  },
                  controller: _contentController,
                  hint: 'Chia sẻ phong cách du lịch, dự tính chi phí...',
                  minLines: 3,
                  maxLines: null,
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Số người muốn tuyển *',
                        style: text.titleSmall,
                      ),
                    ),
                    _CounterButton(
                      icon: Icons.remove,
                      onPressed:
                          _recruitmentCount > (widget.post == null ? 1 : 0)
                          ? () => setState(() => _recruitmentCount--)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$_recruitmentCount',
                        style: text.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _CounterButton(
                      icon: Icons.add,
                      onPressed: _currentMembersCount + _recruitmentCount < 50
                          ? () => setState(() => _recruitmentCount++)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Nhóm hiện có $_currentMembersCount thành viên',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),

                // ── Giới tính ưu tiên ───────────────────────────────────────
                _PreferenceSection(
                  title: 'Ưu tiên giới tính',
                  value: _genderPreference == 'MALE'
                      ? 'Nam'
                      : _genderPreference == 'FEMALE'
                      ? 'Nữ'
                      : 'Bất kỳ',
                  child: Wrap(
                    spacing: 10,
                    children: [
                      _GenderChip(
                        label: 'Bất kỳ',
                        value: 'ANY',
                        groupValue: _genderPreference,
                        onSelected: (val) =>
                            setState(() => _genderPreference = val),
                      ),
                      _GenderChip(
                        label: 'Nam',
                        value: 'MALE',
                        groupValue: _genderPreference,
                        onSelected: (val) =>
                            setState(() => _genderPreference = val),
                      ),
                      _GenderChip(
                        label: 'Nữ',
                        value: 'FEMALE',
                        groupValue: _genderPreference,
                        onSelected: (val) =>
                            setState(() => _genderPreference = val),
                      ),
                    ],
                  ),
                ),

                // ── Khoảng độ tuổi ──────────────────────────────────────────
                _PreferenceSection(
                  title: 'Yêu cầu độ tuổi',
                  value:
                      _minAgeController.text.isEmpty &&
                          _maxAgeController.text.isEmpty
                      ? 'Không giới hạn'
                      : _validateAge(_minAgeController.text) != null ||
                            _validateMaxAge(_maxAgeController.text) != null
                      ? 'Cần kiểm tra độ tuổi'
                      : '${_minAgeController.text.isEmpty ? '…' : _minAgeController.text} – ${_maxAgeController.text.isEmpty ? '…' : _maxAgeController.text}',
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Từ tuổi',
                          controller: _minAgeController,
                          errorText: _validateAge(_minAgeController.text),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          hint: 'Không giới hạn',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          label: 'Đến tuổi',
                          controller: _maxAgeController,
                          errorText: _validateMaxAge(_maxAgeController.text),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          hint: 'Không giới hạn',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Chủ đề / Tags ────────────────────────────────────────────
                _PreferenceSection(
                  title: 'Chủ đề chuyến đi',
                  value: _selectedTags.isEmpty
                      ? 'Chưa chọn'
                      : _selectedTags.join(', '),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        selectedColor: AppColors.primarySurface,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusRound,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        backgroundColor: AppColors.inputSurface,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isEnabled ? AppColors.primarySurface : AppColors.inputSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEnabled ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isEnabled ? AppColors.primary : AppColors.textHint,
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.inputSurface,
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusRound),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
      onSelected: (_) => onSelected(value),
    );
  }
}

class _PreferenceSection extends StatelessWidget {
  const _PreferenceSection({
    required this.title,
    required this.value,
    required this.child,
  });
  final String title;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    maintainState: true,
    expandedCrossAxisAlignment: CrossAxisAlignment.start,
    expandedAlignment: Alignment.centerLeft,
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(top: 8, bottom: 12),
    shape: const Border(),
    collapsedShape: const Border(),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    subtitle: Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
    ),
    children: [child],
  );
}
