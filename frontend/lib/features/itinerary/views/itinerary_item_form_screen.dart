import 'package:flutter/material.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/ui_kit.dart';
import '../models/itinerary_model.dart';
import '../repositories/api_itinerary_repository.dart';
import '../repositories/itinerary_repository.dart';
import '../repositories/mock_itinerary_repository.dart';

class ItineraryItemFormScreen extends StatefulWidget {
  const ItineraryItemFormScreen({
    super.key,
    this.repository,
    this.destination = '',
    required this.position,
    this.item,
    this.suggestedStartTime,
  });

  final ItineraryRepository? repository;
  final String destination;
  final int position;
  final ItineraryItem? item;
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
  bool _searching = false;
  String? _searchError;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ??
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
    _endTime = item?.endTime ?? _addHour(_startTime);
    _useCatalog = !_editing;
    if (!_editing) _searchPlaces();
  }

  @override
  void dispose() {
    for (final controller in [_name, _address, _note, _cost, _search]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _searchPlaces() async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final result = await _repo.searchPlaces(
        destination: widget.destination,
        keyword: _search.text,
      );
      if (!mounted) return;
      setState(() => _places = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _searchError = '$error'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _choosePlace(ItineraryPlaceOption place) {
    setState(() {
      _selectedPlace = place;
      _name.text = place.name;
      _address.text = place.address ?? '';
      _category = place.category;
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final current = _parseTime(start ? _startTime : _endTime);
    final value = await AppPickers.time(context, initial: current);
    if (value == null) return;
    setState(() {
      if (start) {
        _startTime = _formatTime(value);
      } else {
        _endTime = _formatTime(value);
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_useCatalog && !_editing && _selectedPlace == null) {
      AppFeedback.show(
        context,
        'Hãy chọn một địa điểm trong kho hoặc chuyển sang tự nhập.',
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
        customName: _name.text,
        customAddress: _address.text.isEmpty ? null : _address.text,
        category: _category,
        startTime: _startTime,
        endTime: _endTime,
        note: _note.text.isEmpty ? null : _note.text,
        estimatedCost: VndInputFormatter.parse(_cost.text) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: _editing
        ? 'Sửa điểm dừng'
        : widget.position == 0
        ? 'Thêm điểm bắt đầu'
        : 'Thêm điểm tiếp theo',
    scrollable: true,
    bottomAction: CustomButton(
      text: _editing ? 'Lưu thay đổi' : 'Thêm vào lịch trình',
      onPressed: _submit,
    ),
    body: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInlineNotice(
            message: widget.position == 0
                ? 'Đây là điểm xuất phát đầu tiên trong ngày. Giờ bắt đầu và kết thúc là khoảng thời gian bạn ở điểm này.'
                : 'Điểm này sẽ được thêm sau điểm dừng hiện tại. Bạn có thể đổi thứ tự ở màn hình lịch trình.',
          ),
          const SizedBox(height: 18),
          if (!_editing) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.travel_explore_rounded),
                  label: Text('Chọn từ kho'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.edit_location_alt_outlined),
                  label: Text('Tự nhập'),
                ),
              ],
              selected: {_useCatalog},
              onSelectionChanged: (value) {
                setState(() {
                  _useCatalog = value.first;
                  if (!_useCatalog) _selectedPlace = null;
                });
              },
            ),
            const SizedBox(height: 18),
          ],
          if (_useCatalog && !_editing) ...[
            AppSearchField(
              controller: _search,
              hint: 'Tìm địa điểm tại ${widget.destination}',
              isLoading: _searching,
              onChanged: (_) {},
            ),
            const SizedBox(height: 10),
            CustomButton(
              text: 'Tìm địa điểm',
              icon: Icons.search_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: _searching ? null : _searchPlaces,
            ),
            if (_searchError != null) ...[
              const SizedBox(height: 10),
              InlineError(message: _searchError!, onRetry: _searchPlaces),
            ],
            const SizedBox(height: 12),
            if (!_searching && _places.isEmpty)
              const AppInlineNotice(
                message:
                    'Không có địa điểm phù hợp. Bạn có thể chọn “Tự nhập”.',
                tone: AppStatusTone.warning,
              )
            else
              ..._places.map(
                (place) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    outlined: _selectedPlace?.id != place.id,
                    color: _selectedPlace?.id == place.id
                        ? AppColors.primarySurface
                        : AppColors.surface,
                    onTap: () => _choosePlace(place),
                    child: Row(
                      children: [
                        Icon(
                          _selectedPlace?.id == place.id
                              ? Icons.check_circle_rounded
                              : Icons.place_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                place.address ?? place.destination,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text('★ ${place.rating.toStringAsFixed(1)}'),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
          if (!_useCatalog || _editing) ...[
            CustomTextField(
              label: widget.position == 0 ? 'Điểm bắt đầu' : 'Tên điểm dừng',
              hint: 'Ví dụ: Bến xe, khách sạn, Hồ Xuân Hương',
              controller: _name,
              prefixIcon: Icons.place_outlined,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Vui lòng nhập tên điểm dừng'
                  : null,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              label: 'Địa chỉ',
              controller: _address,
              prefixIcon: Icons.map_outlined,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Loại địa điểm',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: itineraryCategories.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 16),
          ],
          Text('Thời gian', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppSelectionField(
                  label: 'Bắt đầu',
                  value: _startTime,
                  icon: Icons.schedule_rounded,
                  onTap: () => _pickTime(start: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppSelectionField(
                  label: 'Kết thúc',
                  value: _endTime,
                  icon: Icons.schedule_outlined,
                  onTap: () => _pickTime(start: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppMoneyField(label: 'Chi phí dự kiến', controller: _cost),
          const SizedBox(height: 14),
          CustomTextField(
            label: 'Ghi chú',
            hint: 'Vé, giờ mở cửa hoặc việc cần chuẩn bị',
            controller: _note,
            prefixIcon: Icons.notes_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 90),
        ],
      ),
    ),
  );
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

String _addHour(String value) {
  final total = (_minutes(value) + 60).clamp(0, 23 * 60 + 59);
  return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
}
