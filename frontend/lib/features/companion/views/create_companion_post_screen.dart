import 'package:flutter/material.dart';
import 'package:feeling_trip/core/constants/app_colors.dart';
import 'package:feeling_trip/core/constants/app_sizes.dart';
import 'package:feeling_trip/shared/ui_kit.dart';
import '../repositories/companion_repository.dart';
import '../repositories/mock_companion_repository.dart';
import '../repositories/api_companion_repository.dart';
import '../repositories/companion_trip_repository.dart';
import '../../../core/constants/api_endpoints.dart';

// ================================================================================
// SCREEN: Create Companion Post
// ================================================================================
// Màn hình tạo bài đăng tìm bạn đồng hành cho chuyến đi.
// ================================================================================

class CreateCompanionPostScreen extends StatefulWidget {
  const CreateCompanionPostScreen({
    super.key,
    this.repository,
    this.tripId,
    this.tripName,
    this.tripDestination,
  });

  final CompanionRepository? repository;
  final String? tripId;
  final String? tripName;
  final String? tripDestination;

  @override
  State<CreateCompanionPostScreen> createState() =>
      _CreateCompanionPostScreenState();
}

class _CreateCompanionPostScreenState extends State<CreateCompanionPostScreen> {
  late final CompanionRepository _repo;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _minAgeController = TextEditingController();
  final _maxAgeController = TextEditingController();

  int _targetMembersCount = 3;
  String _genderPreference = 'ANY';
  final Set<String> _selectedTags = {'Phượt', 'Nhiếp ảnh'};
  bool _isSubmitting = false;

  // Danh sách chuyến đi mẫu để leader chọn
  List<Map<String, String>> _availableTrips = [];
  bool _loadingTrips = false;
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
    if (widget.tripId == null && !ApiEndpoints.useMockData) _loadTrips();
    if (widget.tripName != null && widget.tripName!.isNotEmpty) {
      _titleController.text = 'Tìm bạn đồng hành: ${widget.tripName}';
    }
  }

  Future<void> _loadTrips() async {
    setState(() {
      _loadingTrips = true;
      _tripError = null;
    });
    try {
      final trips = await CompanionTripRepository().getMyTrips();
      if (mounted) {
        setState(() {
          _availableTrips = trips.where((trip) => trip['hasCompanionPost'] != 'true').toList();
          _selectedTripId = _availableTrips.isEmpty ? '' : _availableTrips.first['id']!;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tripError = 'Không tải được chuyến đi.');
    } finally {
      if (mounted) setState(() => _loadingTrips = false);
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
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    if (_selectedTripId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy chọn chuyến đi do bạn làm trưởng nhóm.'),
        ),
      );
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
      final newPost = await _repo.createPost(
        tripId: _selectedTripId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim().isNotEmpty
            ? _contentController.text.trim()
            : null,
        targetMembersCount: _targetMembersCount,
        minAge: minAge,
        maxAge: maxAge,
        genderPreference: _genderPreference,
        tags: _selectedTags.toList(),
      );

      if (!mounted) return;
      Navigator.pop(context, newPost);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Đăng bài tìm bạn',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF09143B),
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF09143B),
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: .04),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 16,
            ),
          ],
        ),
        child: SafeArea(
          child: CustomButton(
            text: 'Đăng bài',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ),
      ),
      body: SingleChildScrollView(
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
              if (_tripError != null)
                ErrorState(message: _tripError!, onRetry: _loadTrips),
              if (widget.tripId != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                    border: Border.all(color: AppColors.primaryBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.luggage_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.tripName ?? _selectedTripId,
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
                      const AppStatusBadge(
                        label: 'Đã gắn',
                        tone: AppStatusTone.success,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTripId.isEmpty ? null : _selectedTripId,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.textSecondary,
                      ),
                      items: _availableTrips.map((t) {
                        return DropdownMenuItem<String>(
                          value: t['id'],
                          child: Text(
                            '${t['name']} (${t['destination']})',
                            style: text.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTripId = val);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // ── Tiêu đề bài đăng ────────────────────────────────────────
              CustomTextField(
                label: 'Tiêu đề bài đăng *',
                controller: _titleController,
                hint: 'VD: Tìm 2 bạn nữ đi Sapa săn mây cuối tuần...',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề bài đăng';
                  }
                  if (val.trim().length < 6) {
                    return 'Tiêu đề cần ít nhất 6 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Nội dung chi tiết ───────────────────────────────────────
              CustomTextField(
                label: 'Lời nhắn / Giới thiệu chi tiết *',
                validator: (value) {
                  final content = value?.trim() ?? '';
                  if (content.length < 10) {
                    return 'Nội dung cần ít nhất 10 ký tự';
                  }
                  if (content.length > 5000) {
                    return 'Nội dung tối đa 5000 ký tự';
                  }
                  return null;
                },
                controller: _contentController,
                hint: 'Chia sẻ phong cách du lịch, dự tính chi phí...',
                maxLines: 4,
              ),
              const SizedBox(height: 20),

              // ── Số lượng slot tuyển ─────────────────────────────────────
              Text(
                'Tổng số thành viên (gồm trưởng nhóm) *',
                style: text.titleSmall,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _CounterButton(
                    icon: Icons.remove,
                    onPressed: _targetMembersCount > 1
                        ? () => setState(() => _targetMembersCount--)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$_targetMembersCount người',
                    style: text.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _CounterButton(
                    icon: Icons.add,
                    onPressed: _targetMembersCount < 20
                        ? () => setState(() => _targetMembersCount++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Giới tính ưu tiên ───────────────────────────────────────
              Text('Ưu tiên giới tính', style: text.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  _GenderChip(
                    label: 'Tất cả (Bất kỳ)',
                    value: 'ANY',
                    groupValue: _genderPreference,
                    onSelected: (val) =>
                        setState(() => _genderPreference = val),
                  ),
                  _GenderChip(
                    label: 'Chỉ Nam',
                    value: 'MALE',
                    groupValue: _genderPreference,
                    onSelected: (val) =>
                        setState(() => _genderPreference = val),
                  ),
                  _GenderChip(
                    label: 'Chỉ Nữ',
                    value: 'FEMALE',
                    groupValue: _genderPreference,
                    onSelected: (val) =>
                        setState(() => _genderPreference = val),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Khoảng độ tuổi ──────────────────────────────────────────
              Text('Yêu cầu độ tuổi (tùy chọn)', style: text.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Từ tuổi',
                      controller: _minAgeController,
                      hint: '18',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      label: 'Đến tuổi',
                      controller: _maxAgeController,
                      hint: '35',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Chủ đề / Tags ────────────────────────────────────────────
              Text('Chủ đề chuyến đi', style: text.titleSmall),
              const SizedBox(height: 10),
              Wrap(
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
                      borderRadius: BorderRadius.circular(AppSizes.radiusRound),
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
              const SizedBox(height: 40),
            ],
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
      labelStyle: TextStyle(
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
