import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../map/models/place_distance_model.dart';
import '../../map/models/place_search_result.dart';
import '../../map/repositories/api_place_repository.dart';
import '../../map/repositories/place_search_repository.dart';
import '../../../shared/ui_kit.dart';
import '../models/itinerary_model.dart';
import '../repositories/api_itinerary_repository.dart';
import '../repositories/itinerary_repository.dart';
import '../repositories/mock_itinerary_repository.dart';
import 'itinerary_place_search_screen.dart';
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
  late String _category;
  late String _startTime;
  late String _endTime;
  late String _locationSource; // CATALOG, GEOAPIFY, MANUAL
  ItineraryPlaceOption? _selectedPlace;
  PlaceSearchResult? _selectedGeoapifyPlace;
  double? _latitude;
  double? _longitude;
  String? _externalProvider;
  String? _externalPlaceId;
  String? _suggestedArrivalMessage;
  final _placeSearchRepository = PlaceSearchRepository();
  List<PlaceSearchResult> _geoapifyResults = const [];
  Timer? _geoapifyDebounceTimer;
  int _geoapifySearchRequestId = 0;
  int _distanceRequestId = 0;
  bool _geoapifySearching = false;
  String? _geoapifySearchError;
  PlaceDistanceResult? _distanceFromPrevious;
  bool _calculatingDistance = false;

  bool get _editing => widget.item != null;
  bool get _isCatalogSource => _locationSource == 'CATALOG';

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
    _category = item?.category ?? 'ATTRACTION';
    _startTime = item?.startTime ?? widget.suggestedStartTime ?? '08:00';
    _endTime = item?.endTime ?? _addMinutes(_startTime, 90);

    if (item != null) {
      _locationSource = item.locationSource;
      _latitude = item.latitude;
      _longitude = item.longitude;
      _externalProvider = item.externalProvider;
      _externalPlaceId = item.externalPlaceId;
      if (item.locationSource == 'GEOAPIFY' &&
          _latitude != null &&
          _longitude != null) {
        _selectedGeoapifyPlace = PlaceSearchResult(
          id: item.externalPlaceId ?? '',
          name: item.customName,
          formattedAddress: item.customAddress ?? '',
          latitude: item.latitude!,
          longitude: item.longitude!,
        );
      }
      if (_latitude != null && _longitude != null) {
        _calculateDistanceToPrevious(lat: _latitude, lng: _longitude);
      }
    } else {
      _locationSource = 'CATALOG';
    }
  }

  @override
  void dispose() {
    _geoapifyDebounceTimer?.cancel();
    for (final controller in [_name, _address, _note, _cost]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _openCatalogPlaceSearch() async {
    final place = await Navigator.push<ItineraryPlaceOption>(
      context,
      MaterialPageRoute(
        builder: (_) => ItineraryPlaceSearchScreen(
          destination: widget.destination,
          repository: _repo,
        ),
      ),
    );
    if (place != null && mounted) {
      await _choosePlace(place);
    }
  }

  Future<void> _choosePlace(ItineraryPlaceOption place) async {
    setState(() {
      _selectedPlace = place;
      _selectedGeoapifyPlace = null;
      _locationSource = 'CATALOG';
      _name.text = place.name;
      _address.text = place.address ?? place.destination;
      _category = place.category;
      _latitude = place.latitude;
      _longitude = place.longitude;
      _externalProvider = null;
      _externalPlaceId = null;
      _suggestedArrivalMessage = null;
    });
    await _calculateDistanceToPrevious(
      lat: place.latitude,
      lng: place.longitude,
    );
  }

  void _onGeoapifyQueryChanged(String query) {
    _geoapifyDebounceTimer?.cancel();
    final requestId = ++_geoapifySearchRequestId;
    _distanceRequestId++;

    setState(() {
      _selectedPlace = null;
      _selectedGeoapifyPlace = null;
      _locationSource = 'MANUAL';
      _latitude = null;
      _longitude = null;
      _externalProvider = null;
      _externalPlaceId = null;
      _geoapifySearchError = null;
      _geoapifyResults = const [];
      _geoapifySearching = false;
      _distanceFromPrevious = null;
      _suggestedArrivalMessage = null;
    });

    if (query.trim().length < 3) return;
    _geoapifyDebounceTimer = Timer(
      const Duration(milliseconds: 400),
      () => _searchGeoapify(query.trim(), requestId),
    );
  }

  Future<void> _searchGeoapify(String query, int requestId) async {
    if (!mounted || requestId != _geoapifySearchRequestId) return;
    setState(() {
      _geoapifySearching = true;
      _geoapifySearchError = null;
    });
    try {
      final results = await _placeSearchRepository.searchPlaces(query);
      if (!mounted || requestId != _geoapifySearchRequestId) return;
      setState(() => _geoapifyResults = results);
    } catch (error) {
      if (!mounted || requestId != _geoapifySearchRequestId) return;
      setState(() {
        _geoapifySearchError = '$error'.replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted && requestId == _geoapifySearchRequestId) {
        setState(() => _geoapifySearching = false);
      }
    }
  }

  Future<void> _chooseGeoapifyPlace(PlaceSearchResult place) async {
    _geoapifyDebounceTimer?.cancel();
    ++_geoapifySearchRequestId;
    setState(() {
      _selectedGeoapifyPlace = place;
      _selectedPlace = null;
      _locationSource = 'GEOAPIFY';
      _name.text = place.name;
      _address.text = place.formattedAddress;
      _latitude = place.latitude;
      _longitude = place.longitude;
      _externalProvider = 'GEOAPIFY';
      _externalPlaceId = place.id;
      _geoapifyResults = const [];
      _geoapifySearchError = null;
      _geoapifySearching = false;
      _suggestedArrivalMessage = null;
    });
    await _calculateDistanceToPrevious(
      lat: place.latitude,
      lng: place.longitude,
    );
  }

  Future<void> _calculateDistanceToPrevious({double? lat, double? lng}) async {
    final targetLat = lat ?? _latitude;
    final targetLng = lng ?? _longitude;
    final requestId = ++_distanceRequestId;
    final previous = widget.previousItem;
    if (previous == null ||
        previous.latitude == null ||
        previous.longitude == null ||
        targetLat == null ||
        targetLng == null) {
      if (!mounted) return;
      setState(() {
        _distanceFromPrevious = null;
        _calculatingDistance = false;
        _suggestedArrivalMessage = null;
      });
      return;
    }

    setState(() {
      _calculatingDistance = true;
      _distanceFromPrevious = null;
      _suggestedArrivalMessage = null;
    });
    try {
      final result = await ApiPlaceRepository().calculateDistance(
        originLatitude: previous.latitude!,
        originLongitude: previous.longitude!,
        destinationLatitude: targetLat,
        destinationLongitude: targetLng,
        travelMode: 'driving',
      );
      if (!mounted || requestId != _distanceRequestId) return;
      setState(() {
        _distanceFromPrevious = result;
      });
      if (!_editing && result.estimatedDurationMinutes > 0) {
        _applyCalculatedArrivalTime(result.estimatedDurationMinutes);
      }
    } catch (_) {
      if (!mounted || requestId != _distanceRequestId) return;
      setState(() => _distanceFromPrevious = null);
    } finally {
      if (mounted && requestId == _distanceRequestId) {
        setState(() => _calculatingDistance = false);
      }
    }
  }

  void _applyCalculatedArrivalTime(int durationMinutes) {
    final previous = widget.previousItem;
    if (previous == null) return;
    final newStart = _addMinutes(previous.endTime, durationMinutes);
    final duration = _minutes(_endTime) - _minutes(_startTime);
    final newEnd = duration > 0
        ? _addMinutes(newStart, duration)
        : _addMinutes(newStart, 90);
    setState(() {
      _startTime = newStart;
      _endTime = newEnd;
      _suggestedArrivalMessage =
          'Đã tự động tính giờ đến: $_startTime (~$durationMinutes phút di chuyển từ điểm trước)';
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final current = _parseTime(start ? _startTime : _endTime);
    final value = await AppPickers.time(context, initial: current);
    if (value == null) return;
    setState(() {
      if (start) {
        final currentDuration = _minutes(_endTime) - _minutes(_startTime);
        _startTime = _formatTime(value);
        if (currentDuration > 0) {
          _endTime = _addMinutes(_startTime, currentDuration);
        }
      } else {
        _endTime = _formatTime(value);
      }
      _suggestedArrivalMessage = null;
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
    if (_locationSource == 'CATALOG' && !_editing && _selectedPlace == null) {
      AppFeedback.show(
        context,
        'Hãy chọn một địa điểm trong danh sách gợi ý hoặc chuyển sang tab khác.',
        tone: AppStatusTone.warning,
      );
      return;
    }
    if (_locationSource == 'GEOAPIFY' &&
        (_selectedGeoapifyPlace == null ||
            _latitude == null ||
            _longitude == null ||
            (_externalPlaceId ?? '').isEmpty)) {
      AppFeedback.show(
        context,
        'Hãy chọn một gợi ý địa điểm hoặc chuyển sang tự nhập.',
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

    String? placeId;
    String? externalProvider;
    String? externalPlaceId;
    double? latitude;
    double? longitude;

    if (_locationSource == 'CATALOG') {
      placeId = _selectedPlace?.id ?? (_editing ? widget.item?.placeId : null);
      latitude =
          _selectedPlace?.latitude ?? (_editing ? widget.item?.latitude : null);
      longitude =
          _selectedPlace?.longitude ??
          (_editing ? widget.item?.longitude : null);
      externalProvider = null;
      externalPlaceId = null;
    } else if (_locationSource == 'GEOAPIFY') {
      placeId = null;
      externalProvider = _externalProvider ?? 'GEOAPIFY';
      externalPlaceId =
          _selectedGeoapifyPlace?.id ??
          _externalPlaceId ??
          (_editing ? widget.item?.externalPlaceId : null);
      latitude =
          _selectedGeoapifyPlace?.latitude ??
          _latitude ??
          (_editing ? widget.item?.latitude : null);
      longitude =
          _selectedGeoapifyPlace?.longitude ??
          _longitude ??
          (_editing ? widget.item?.longitude : null);
    } else {
      placeId = null;
      externalProvider = null;
      externalPlaceId = null;
      latitude = null;
      longitude = null;
    }

    Navigator.pop(
      context,
      ItineraryItemDraft(
        placeId: placeId,
        customName: _name.text.trim(),
        customAddress: _address.text.trim().isEmpty
            ? null
            : _address.text.trim(),
        category: _category,
        startTime: _startTime,
        endTime: _endTime,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        estimatedCost: VndInputFormatter.parse(_cost.text) ?? 0,
        locationSource: _locationSource,
        externalProvider: externalProvider,
        externalPlaceId: externalPlaceId,
        latitude: latitude,
        longitude: longitude,
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

          // ─── SOURCE SELECTOR (3 TABS) ──────────────────────────────────
          _buildSourceSelector(),
          const SizedBox(height: 16),

          // ─── CATALOG SECTION ───────────────────────────────────────────
          if (_locationSource == 'CATALOG') ...[
            if (_selectedPlace == null) ...[
              // Search launcher button (tương tự ô tìm kiếm ở Trang chủ)
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _openCatalogPlaceSearch,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.destination.isNotEmpty
                                    ? 'Tìm địa điểm tại ${widget.destination}...'
                                    : 'Tìm địa điểm trong kho gợi ý...',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Chạm để mở trang tìm kiếm trong kho gợi ý',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Selected place preview card
              _selectedPlacePreview(),
            ],
            const SizedBox(height: 16),
          ],

          // ─── MAP SECTION (GEOAPIFY) ────────────────────────────────────
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
            helperText: _isCatalogSource
                ? null
                : 'Nhập ít nhất 3 ký tự để nhận gợi ý địa điểm.',
            onChanged: _isCatalogSource ? null : _onGeoapifyQueryChanged,
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) return 'Vui lòng nhập tên điểm dừng';
              if (text.length > 255) {
                return 'Tên điểm dừng không được vượt quá 255 ký tự';
              }
              return null;
            },
          ),
          if (!_isCatalogSource) ...[
            const SizedBox(height: 8),
            _geoapifySuggestionList(),
          ],
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
                    horizontal: 10,
                    vertical: 7,
                  ),
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
                      Icon(
                        icon,
                        size: 15,
                        color: isChosen ? color : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isChosen
                              ? FontWeight.w700
                              : FontWeight.w500,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: AppColors.primary,
                    ),
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
            hint:
                'Vé tham quan, giờ mở cửa, trang phục hoặc đồ cần đem theo...',
            controller: _note,
            prefixIcon: Icons.notes_rounded,
            maxLines: 3,
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isNotEmpty && text.length > 1000) {
                return 'Ghi chú không được vượt quá 1000 ký tự';
              }
              return null;
            },
          ),
          const SizedBox(height: 90),
        ],
      ),
    ),
  );

  Widget _buildSourceSelector() {
    return Row(
      children: [
        Expanded(
          child: _modeTab(
            title: 'Kho gợi ý',
            subtitle: 'Kho địa điểm',
            icon: Icons.travel_explore_rounded,
            isSelected: _locationSource == 'CATALOG',
            onTap: () {
              setState(() {
                _locationSource = 'CATALOG';
                _selectedGeoapifyPlace = null;
                _externalProvider = null;
                _externalPlaceId = null;
                _geoapifyResults = const [];
                _geoapifySearchError = null;
              });
              if (_selectedPlace != null) {
                _calculateDistanceToPrevious(
                  lat: _selectedPlace!.latitude,
                  lng: _selectedPlace!.longitude,
                );
              } else {
                setState(() {
                  _latitude = null;
                  _longitude = null;
                  _distanceFromPrevious = null;
                });
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _modeTab(
            title: 'Tự nhập',
            subtitle: 'Có gợi ý địa điểm',
            icon: Icons.edit_location_alt_rounded,
            isSelected: _locationSource != 'CATALOG',
            onTap: () {
              setState(() {
                _distanceRequestId++;
                _locationSource = 'MANUAL';
                _selectedPlace = null;
                _selectedGeoapifyPlace = null;
                _latitude = null;
                _longitude = null;
                _externalProvider = null;
                _externalPlaceId = null;
                _geoapifyResults = const [];
                _geoapifySearchError = null;
                _distanceFromPrevious = null;
                _suggestedArrivalMessage = null;
              });
            },
          ),
        ),
      ],
    );
  }

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.primaryDark
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
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
                onTap: _openCatalogPlaceSearch,
                child: const Text(
                  'Đổi địa điểm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedPlace = null;
                    _distanceFromPrevious = null;
                  });
                },
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
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
          _distancePreviewWidget(),
        ],
      ),
    );
  }

  Widget _geoapifySuggestionList() {
    if (_geoapifySearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Đang tìm địa điểm...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_geoapifySearchError != null) {
      return InlineError(
        message: _geoapifySearchError!,
        onRetry: () {
          final query = _name.text.trim();
          if (query.length < 3) return;
          _searchGeoapify(query, ++_geoapifySearchRequestId);
        },
      );
    }

    if (_selectedGeoapifyPlace != null) {
      final place = _selectedGeoapifyPlace!;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppColors.success,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đã chọn gợi ý Geoapify: ${place.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedGeoapifyPlace = null;
                  _locationSource = 'MANUAL';
                  _latitude = null;
                  _longitude = null;
                  _externalProvider = null;
                  _externalPlaceId = null;
                  _distanceFromPrevious = null;
                  _suggestedArrivalMessage = null;
                });
              },
              child: const Text('Nhập tay'),
            ),
          ],
        ),
      );
    }

    if (_geoapifyResults.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _geoapifyResults.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final place = _geoapifyResults[index];
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
            ),
            title: Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              place.formattedAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () => _chooseGeoapifyPlace(place),
          );
        },
      ),
    );
  }

  Widget _distancePreviewWidget() {
    if (_calculatingDistance) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(
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
      );
    }
    if (_distanceFromPrevious != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                const Icon(
                  Icons.directions_car_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
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
          if (_suggestedArrivalMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _suggestedArrivalMessage!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ] else if (widget.previousItem != null &&
              _distanceFromPrevious!.estimatedDurationMinutes > 0) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _applyCalculatedArrivalTime(
                _distanceFromPrevious!.estimatedDurationMinutes,
              ),
              child: Text(
                'Tự động áp dụng giờ đến: ${_addMinutes(widget.previousItem!.endTime, _distanceFromPrevious!.estimatedDurationMinutes)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      );
    }
    return const SizedBox.shrink();
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
