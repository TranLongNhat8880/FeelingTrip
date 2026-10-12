import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../map/models/place_distance_model.dart';
import '../../map/repositories/api_place_repository.dart';
import '../../../shared/ui_kit.dart';
import '../models/itinerary_model.dart';
import '../repositories/api_itinerary_repository.dart';
import '../repositories/itinerary_repository.dart';
import '../repositories/mock_itinerary_repository.dart';
import 'widgets/itinerary_widgets.dart';

class ItineraryItemFormScreen extends StatefulWidget {
  const ItineraryItemFormScreen({
    super.key,
    this.repository,
    this.destination = '',
    required this.position,
    this.item,
    this.previousItem,
    this.suggestedStartTime,
  });

  final ItineraryRepository? repository;
  final String destination;
  final int position;
  final ItineraryItem? item;
  final ItineraryItem? previousItem;
  final String? suggestedStartTime;

  @override
  State<ItineraryItemFormScreen> createState() =>
      _ItineraryItemFormScreenState();
}

class _ItineraryItemFormScreenState extends State<ItineraryItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ItineraryRepository _repo;
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _note;
  late final TextEditingController _cost;
  late final TextEditingController _search;
  late String _category;
  late String _startTime;
  late String _endTime;
  late bool _useCatalog;
  ItineraryPlaceOption? _selectedPlace;
  List<ItineraryPlaceOption> _places = [];
  Timer? _debounceTimer;
  int _searchRequestId = 0;
  int _distanceRequestId = 0;
  bool _searching = false;
  String? _searchError;
  PlaceDistanceResult? _distanceFromPrevious;
  bool _calculatingDistance = false;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _repo =
        widget.repository ??
        (ApiEndpoints.useMockData
            ? MockItineraryRepository()
            : ApiItineraryRepository());
    final item = widget.item;
    _name = TextEditingController(text: item?.customName);
    _address = TextEditingController(text: item?.customAddress);
    _note = TextEditingController(text: item?.note);
    _cost = TextEditingController(
      text: VndInputFormatter.format('${item?.estimatedCost ?? 0}'),
    );
    _search = TextEditingController();
    _category = item?.category ?? 'ATTRACTION';
    _startTime = item?.startTime ?? widget.suggestedStartTime ?? '08:00';
    _endTime = item?.endTime ?? _addMinutes(_startTime, 90);
    _useCatalog = !_editing;

    // Load initial place options if catalog mode
    if (_useCatalog) {
      _searchPlaces();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    for (final controller in [_name, _address, _note, _cost, _search]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onSearchQueryChanged(String query) {
    _debounceTimer?.cancel();
    final requestId = ++_searchRequestId;
    _distanceRequestId++;
    setState(() {
      _searchError = null;
    });
    _debounceTimer = Timer(
      const Duration(milliseconds: 350),
      () => _searchPlaces(requestId: requestId),
    );
  }

  Future<void> _searchPlaces({int? requestId}) async {
    final currentRequestId = requestId ?? ++_searchRequestId;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final result = await _repo.searchPlaces(
        destination: widget.destination,
        keyword: _search.text.trim(),
      );
      if (!mounted || currentRequestId != _searchRequestId) return;
      setState(() => _places = result);
    } catch (error) {
      if (!mounted || currentRequestId != _searchRequestId) return;
      setState(() => _searchError = '$error'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && currentRequestId == _searchRequestId) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _choosePlace(ItineraryPlaceOption place) async {
    setState(() {
      _selectedPlace = place;
      _name.text = place.name;
      _address.text = place.address ?? place.destination;
      _category = place.category;
    });
    await _calculateDistanceToPrevious(place);
  }

  Future<void> _calculateDistanceToPrevious(ItineraryPlaceOption place) async {
    final requestId = ++_distanceRequestId;
    final previous = widget.previousItem;
    if (previous == null ||
        previous.latitude == null ||
        previous.longitude == null ||
        place.latitude == null ||
        place.longitude == null) {
      if (!mounted) return;
      setState(() {
        _distanceFromPrevious = null;
        _calculatingDistance = false;
      });
      return;
    }

    setState(() {
      _calculatingDistance = true;
      _distanceFromPrevious = null;
    });
    try {
      final result = await ApiPlaceRepository().calculateDistance(
        originLatitude: previous.latitude!,
        originLongitude: previous.longitude!,
        destinationLatitude: place.latitude!,
        destinationLongitude: place.longitude!,
        travelMode: 'driving',
      );
      if (!mounted || requestId != _distanceRequestId) return;
      setState(() => _distanceFromPrevious = result);
    } catch (_) {
      if (!mounted || requestId != _distanceRequestId) return;
      setState(() => _distanceFromPrevious = null);
    } finally {
      if (mounted && requestId == _distanceRequestId) {
        setState(() => _calculatingDistance = false);
      }
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final current = _parseTime(start ? _startTime : _endTime);
    final value = await AppPickers.time(context, initial: current);
    if (value == null) return;
    setState(() {
      if (start) {
        final currentDuration = _minutes(_endTime) - _minutes(_startTime);
        _startTime = _formatTime(value);
        // Giữ nguyên thời lượng nếu hợp lý
        if (currentDuration > 0) {
          _endTime = _addMinutes(_startTime, currentDuration);
        }
      } else {
        _endTime = _formatTime(value);
      }
    });
  }

  void _applyDurationPreset(int minutesToAdd) {
    setState(() {
      _endTime = _addMinutes(_startTime, minutesToAdd);
    });
  }

  String _currentDurationLabel() {
    final diff = _minutes(_endTime) - _minutes(_startTime);
    if (diff <= 0) return 'Giờ kết thúc không hợp lệ';
    final h = diff ~/ 60;
    final m = diff % 60;
    if (h > 0 && m > 0) return '$h giờ $m phút';
    if (h > 0) return '$h giờ';
    return '$m phút';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_useCatalog && !_editing && _selectedPlace == null) {
      AppFeedback.show(
        context,
        'Hãy chọn một địa điểm trong danh sách gợi ý hoặc chuyển sang “Tự nhập”.',
        tone: AppStatusTone.warning,
      );
      return;
    }
    if (_minutes(_startTime) >= _minutes(_endTime)) {
      AppFeedback.show(
        context,
        'Giờ kết thúc phải sau giờ bắt đầu.',
        tone: AppStatusTone.error,
      );
      return;
    }
    Navigator.pop(
      context,
      ItineraryItemDraft(
        placeId: _editing ? widget.item!.placeId : _selectedPlace?.id,
        customName: _name.text.trim(),
        customAddress: _address.text.trim().isEmpty ? null : _address.text.trim(),
        category: _category,
        startTime: _startTime,
        endTime: _endTime,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        estimatedCost: VndInputFormatter.parse(_cost.text) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: _editing
            ? 'Sửa điểm dừng'
            : widget.position == 0
                ? 'Thêm điểm xuất phát'
                : 'Thêm điểm dừng mới',
        scrollable: true,
        bottomAction: CustomButton(
          text: _editing ? 'Lưu thay đổi' : 'Thêm vào lịch trình',
          icon: Icons.check_circle_rounded,
          onPressed: _submit,
        ),
        body: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── INFO BANNER ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.position == 0
                          ? Icons.flag_rounded
                          : Icons.add_location_alt_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.position == 0
                            ? 'Điểm xuất phát đầu tiên trong ngày. Bạn có thể chọn khách sạn, bến xe hoặc điểm đón.'
                            : 'Điểm này sẽ được nối tiếp sau điểm dừng trước. Khoảng cách và giờ đi sẽ được tự động tính.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryDark,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── MODE SELECTOR (ONLY WHEN CREATING) ─────────────────────────
              if (!_editing) ...[
                Row(
                  children: [
                    Expanded(
                      child: _modeTab(
                        title: 'Chọn từ gợi ý',
                        subtitle: 'Kho địa điểm ${widget.destination}',
                        icon: Icons.travel_explore_rounded,
                        isSelected: _useCatalog,
                        onTap: () {
                          setState(() {
                            _useCatalog = true;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _modeTab(
                        title: 'Tự nhập địa điểm',
                        subtitle: 'Tự do điền tên & địa chỉ',
                        icon: Icons.edit_location_alt_rounded,
                        isSelected: !_useCatalog,
                        onTap: () {
                          setState(() {
                            _useCatalog = false;
                            _selectedPlace = null;
                            _distanceFromPrevious = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // ─── CATALOG SECTION ───────────────────────────────────────────
              if (_useCatalog && !_editing) ...[
                if (_selectedPlace == null) ...[
                  // Search input
                  AppSearchField(
                    controller: _search,
                    hint: 'Tìm địa điểm tại ${widget.destination.isNotEmpty ? widget.destination : 'điểm đến'}...',
                    isLoading: _searching,
                    onChanged: _onSearchQueryChanged,
                  ),
                  if (_searchError != null) ...[
                    const SizedBox(height: 10),
                    InlineError(message: _searchError!, onRetry: _searchPlaces),
                  ],
                  const SizedBox(height: 12),
                  // Places list
                  if (!_searching && _places.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 28, color: AppColors.textHint),
                          SizedBox(height: 6),
                          Text(
                            'Chưa tìm thấy địa điểm phù hợp',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Thử tìm từ khóa khác hoặc chuyển sang tab “Tự nhập”.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Text(
                      'Gợi ý địa điểm nổi bật (${_places.length})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._places.map((place) => _placeSuggestionCard(place)),
                  ],
                ] else ...[
                  // Selected place preview card
                  _selectedPlacePreview(),
                ],
                const SizedBox(height: 16),
              ],

              // ─── PLACE DETAILS (ALWAYS EDITABLE) ───────────────────────────
              Text(
                'Thông tin địa điểm',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 10),
              CustomTextField(
                label: widget.position == 0
                    ? 'Tên điểm xuất phát'
                    : 'Tên điểm dừng',
                hint: 'Ví dụ: Khách sạn Mường Thanh, Thung lũng Tình Yêu...',
                controller: _name,
                prefixIcon: Icons.place_rounded,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Vui lòng nhập tên điểm dừng'
                    : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Địa chỉ cụ thể (tùy chọn)',
                hint: 'Ví dụ: 12 Nguyễn Du, Phường 2',
                controller: _address,
                prefixIcon: Icons.map_outlined,
              ),
              const SizedBox(height: 16),

              // ─── CATEGORY CHIPS ────────────────────────────────────────────
              Text(
                'Phân loại điểm đến',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: itineraryCategories.entries.map((entry) {
                  final isChosen = _category == entry.key;
                  final color = getCategoryColor(entry.key);
                  final icon = getCategoryIcon(entry.key);

                  return InkWell(
                    onTap: () => setState(() => _category = entry.key),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isChosen
                            ? color.withValues(alpha: 0.15)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isChosen ? color : AppColors.border,
                          width: isChosen ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon,
                              size: 15,
                              color: isChosen ? color : AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isChosen ? FontWeight.w700 : FontWeight.w500,
                              color: isChosen ? color : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ─── TIME & DURATION SELECTOR ──────────────────────────────────
              Row(
                children: [
                  Text(
                    'Thời gian dự kiến',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          _currentDurationLabel(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppSelectionField(
                      label: 'Giờ bắt đầu',
                      value: _startTime,
                      icon: Icons.schedule_rounded,
                      onTap: () => _pickTime(start: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppSelectionField(
                      label: 'Giờ kết thúc',
                      value: _endTime,
                      icon: Icons.schedule_outlined,
                      onTap: () => _pickTime(start: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Duration quick presets
              Row(
                children: [
                  const Text(
                    'Thêm nhanh: ',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _durationPresetChip('+30p', 30),
                  const SizedBox(width: 6),
                  _durationPresetChip('+1h', 60),
                  const SizedBox(width: 6),
                  _durationPresetChip('+1h30p', 90),
                  const SizedBox(width: 6),
                  _durationPresetChip('+2h', 120),
                  const SizedBox(width: 6),
                  _durationPresetChip('+3h', 180),
                ],
              ),
              const SizedBox(height: 18),

              // ─── ESTIMATED COST ────────────────────────────────────────────
              Text(
                'Chi phí dự toán (VNĐ)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              AppMoneyField(
                label: 'Chi phí dự kiến cho cả nhóm',
                controller: _cost,
              ),
              const SizedBox(height: 8),
              // Cost presets
              Wrap(
                spacing: 6,
                children: [
                  _costPresetChip('Miễn phí', '0'),
                  _costPresetChip('50k', '50000'),
                  _costPresetChip('100k', '100000'),
                  _costPresetChip('200k', '200000'),
                  _costPresetChip('500k', '500000'),
                ],
              ),
              const SizedBox(height: 18),

              // ─── NOTE ──────────────────────────────────────────────────────
              CustomTextField(
                label: 'Ghi chú & Lưu ý',
                hint: 'Vé tham quan, giờ mở cửa, trang phục hoặc đồ cần đem theo...',
                controller: _note,
                prefixIcon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 90),
            ],
          ),
        ),
      );

  Widget _modeTab({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeSuggestionCard(ItineraryPlaceOption place) {
    final catColor = getCategoryColor(place.category);
    final catIcon = getCategoryIcon(place.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _choosePlace(place),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(catIcon, size: 19, color: catColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        place.address ?? place.destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 15, color: Color(0xFFFFB703)),
                    const SizedBox(width: 2),
                    Text(
                      place.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedPlacePreview() {
    final place = _selectedPlace!;
    final catColor = getCategoryColor(place.category);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 12, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'Đã chọn',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  categoryLabel(place.category),
                  style: TextStyle(
                    color: catColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedPlace = null;
                    _distanceFromPrevious = null;
                  });
                },
                child: const Text(
                  'Chọn địa điểm khác',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            place.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (place.address != null) ...[
            const SizedBox(height: 2),
            Text(
              place.address!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (_calculatingDistance) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 6),
                Text(
                  'Đang tính khoảng cách từ điểm trước...',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ] else if (_distanceFromPrevious != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Cách điểm trước ${_distanceFromPrevious!.distanceKm.toStringAsFixed(1)} km (~${_distanceFromPrevious!.estimatedDurationMinutes} phút di chuyển)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _durationPresetChip(String label, int minutes) {
    return InkWell(
      onTap: () => _applyDurationPreset(minutes),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _costPresetChip(String label, String amount) {
    return InkWell(
      onTap: () {
        setState(() {
          _cost.text = VndInputFormatter.format(amount);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.first) ?? 8,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

String _formatTime(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

int _minutes(String value) {
  final time = _parseTime(value);
  return time.hour * 60 + time.minute;
}

String _addMinutes(String value, int addMins) {
  final total = (_minutes(value) + addMins).clamp(0, 23 * 60 + 59);
  return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
}
