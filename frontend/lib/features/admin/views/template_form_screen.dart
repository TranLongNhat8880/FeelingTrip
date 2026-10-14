import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/ui_kit.dart';
import '../models/admin_content_model.dart';
import '../repositories/admin_content_repository.dart';
import '../../map/models/place_model.dart';
import 'template_place_picker_screen.dart';

class _ActivityForm {
  _ActivityForm([Map? item])
    : name = TextEditingController(text: item?['customName'] ?? ''),
      address = TextEditingController(text: item?['customAddress'] ?? ''),
      cost = TextEditingController(text: '${item?['estimatedCost'] ?? 0}'),
      note = TextEditingController(text: item?['note'] ?? ''),
      start = item?['startTime'] ?? '09:00',
      end = item?['endTime'] ?? '10:00',
      category = item?['category'] ?? 'OTHER',
      placeId = item?['placeId'],
      useCatalog =
          item == null || item['customName'] == null || item['placeId'] != null;
  final TextEditingController name, address, cost, note;
  String start, end, category;
  String? placeId;
  bool useCatalog;
  void dispose() {
    name.dispose();
    address.dispose();
    cost.dispose();
    note.dispose();
  }

  Map<String, dynamic> data() => {
    'placeId': useCatalog ? placeId : null,
    'customName': name.text.trim(),
    'customAddress': address.text.trim(),
    'estimatedCost': int.tryParse(cost.text.trim()) ?? 0,
    'note': note.text.trim(),
    'startTime': start,
    'endTime': end,
    'category': category,
  };
}

class _DayForm {
  _DayForm([Map? day])
    : title = day?['title'] as String?,
      items = (day?['items'] as List? ?? [{}])
          .map((i) => _ActivityForm(i))
          .toList();
  final String? title;
  final List<_ActivityForm> items;
  void dispose() {
    for (final item in items) {
      item.dispose();
    }
  }
}

class TemplateFormScreen extends StatefulWidget {
  const TemplateFormScreen({super.key, this.plan});
  final LibraryPlan? plan;
  @override
  State<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<TemplateFormScreen> {
  final form = GlobalKey<FormState>();
  final repo = AdminContentRepository();
  late TextEditingController name, destination, budget, description;
  late List<_DayForm> days;
  bool saving = false;
  String? error;
  Uint8List? cover;
  String? fileName;
  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    name = TextEditingController(text: p?.name);
    destination = TextEditingController(text: p?.destination);
    budget = TextEditingController(text: '${p?.budget ?? 0}');
    description = TextEditingController(text: p?.description);
    days = p == null ? [_DayForm()] : p.days.map(_DayForm.new).toList();
  }

  @override
  void dispose() {
    name.dispose();
    destination.dispose();
    budget.dispose();
    description.dispose();
    for (final day in days) {
      day.dispose();
    }
    super.dispose();
  }

  Future<void> pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('Ảnh bìa tối đa 5 MB');
      }
      if (![
        'jpg',
        'jpeg',
        'png',
        'webp',
      ].contains(image.name.split('.').last.toLowerCase())) {
        throw Exception('Chọn ảnh JPG, PNG hoặc WEBP');
      }
      if (mounted) {
        setState(() {
          cover = bytes;
          fileName = image.name;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> pickPlace(_ActivityForm item) async {
    final place = await Navigator.push<PlaceModel>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TemplatePlacePickerScreen(destination: destination.text.trim()),
      ),
    );
    if (place == null || !mounted) return;
    setState(() {
      item.placeId = place.id;
      item.useCatalog = true;
      item.name.text = place.name;
      item.address.text = place.address ?? '';
      item.category = place.category;
    });
  }

  Future<void> pickTime(_ActivityForm item, bool start) async {
    final value = (start ? item.start : item.end).split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(value[0]),
        minute: int.parse(value[1]),
      ),
    );
    if (time != null && mounted) {
      setState(() {
        final value =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        if (start) {
          item.start = value;
        } else {
          item.end = value;
        }
      });
    }
  }

  Future<void> save() async {
    if (saving) return;
    for (final day in days) {
      for (final item in day.items) {
        if (item.useCatalog && item.placeId == null) {
          setState(
            () =>
                error = 'Hãy chọn địa điểm từ kho hoặc chuyển sang nhập tự do.',
          );
          return;
        }
      }
    }
    if (!form.currentState!.validate()) return;
    for (final day in days) {
      for (var i = 0; i < day.items.length; i++) {
        final item = day.items[i];
        if (item.start.compareTo(item.end) >= 0 ||
            (i > 0 && item.start.compareTo(day.items[i - 1].end) < 0)) {
          setState(
            () => error =
                'Giờ hoạt động phải hợp lệ, không trùng và theo thứ tự.',
          );
          return;
        }
      }
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await repo.save(
        {
          'name': name.text.trim(),
          'destination': destination.text.trim(),
          'estimatedBudget': int.parse(budget.text.trim()),
          'description': description.text.trim(),
          'durationDays': days.length,
          'days': [
            for (var i = 0; i < days.length; i++)
              {
                'dayNumber': i + 1,
                if (days[i].title != null) 'title': days[i].title,
                'items': days[i].items.map((item) => item.data()).toList(),
              },
          ],
        },
        previous: widget.plan,
        cover: cover,
        fileName: fileName,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? requiredText(String? value, int max) {
    final text = value?.trim() ?? '';
    return text.length < 2 || text.length > max
        ? 'Nhập từ 2 đến $max ký tự'
        : null;
  }

  String? money(String? value) {
    final n = int.tryParse(value?.trim() ?? '');
    return n == null || n < 0 || n > 1000000000000
        ? 'Nhập số tiền nguyên từ 0 đến 1.000 tỷ'
        : null;
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: widget.plan == null ? 'Thêm lịch trình mẫu' : 'Sửa lịch trình mẫu',
    scrollable: true,
    bottomAction: CustomButton(
      text: 'Lưu mẫu',
      isLoading: saving,
      onPressed: saving ? null : save,
    ),
    body: AbsorbPointer(
      absorbing: saving,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: name,
              label: 'Tên mẫu',
              validator: (v) => requiredText(v, 255),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: destination,
              label: 'Điểm đến',
              validator: (v) => requiredText(v, 100),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: budget,
              label: 'Chi phí dự kiến (đ)',
              keyboardType: TextInputType.number,
              validator: money,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: description,
              label: 'Mô tả',
              maxLines: 3,
              validator: (v) =>
                  (v?.length ?? 0) > 5000 ? 'Tối đa 5000 ký tự' : null,
            ),
            const SizedBox(height: 12),
            if (cover != null)
              Image.memory(cover!, height: 160, fit: BoxFit.cover)
            else if (widget.plan?.cover != null)
              Image.network(
                widget.plan!.cover!,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(),
              ),
            TextButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Chọn ảnh bìa (không bắt buộc)'),
            ),
            for (var dayIndex = 0; dayIndex < days.length; dayIndex++) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ngày ${dayIndex + 1}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (days.length > 1)
                    IconButton(
                      tooltip: 'Xóa ngày',
                      onPressed: () {
                        setState(() {
                          days.removeAt(dayIndex).dispose();
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              for (
                var itemIndex = 0;
                itemIndex < days[dayIndex].items.length;
                itemIndex++
              )
                activity(days[dayIndex], itemIndex),
              TextButton.icon(
                onPressed: days[dayIndex].items.length >= 50
                    ? null
                    : () {
                        setState(
                          () => days[dayIndex].items.add(_ActivityForm()),
                        );
                      },
                icon: const Icon(Icons.add),
                label: const Text('Thêm hoạt động'),
              ),
            ],
            TextButton.icon(
              onPressed: days.length >= 30
                  ? null
                  : () {
                      setState(() => days.add(_DayForm()));
                    },
              icon: const Icon(Icons.add),
              label: Text('Thêm ngày (${days.length}/30)'),
            ),
            if (error != null)
              AppInlineNotice(message: error!, tone: AppStatusTone.error),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
  Widget activity(_DayForm day, int index) {
    final item = day.items[index];
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text('Hoạt động ${index + 1}')),
                if (index > 0)
                  IconButton(
                    tooltip: 'Đưa lên',
                    onPressed: () {
                      setState(() {
                        day.items.removeAt(index);
                        day.items.insert(index - 1, item);
                      });
                    },
                    icon: const Icon(Icons.arrow_upward),
                  ),
                if (day.items.length > 1)
                  IconButton(
                    tooltip: 'Xóa hoạt động',
                    onPressed: () {
                      setState(() => day.items.removeAt(index).dispose());
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Chọn từ kho'),
                  labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF09143B),
                  ),
                  selected: item.useCatalog,
                  onSelected: (_) => setState(() => item.useCatalog = true),
                ),
                ChoiceChip(
                  label: const Text('Nhập tự do'),
                  labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF09143B),
                  ),
                  selected: !item.useCatalog,
                  onSelected: (_) => setState(() {
                    item.useCatalog = false;
                    item.placeId = null;
                  }),
                ),
              ],
            ),
            if (item.useCatalog)
              TextButton.icon(
                onPressed: () => pickPlace(item),
                icon: const Icon(Icons.place_outlined),
                label: Text(
                  item.placeId == null ? 'Chọn địa điểm' : 'Đổi địa điểm',
                ),
              ),
            const SizedBox(height: 8),
            CustomTextField(
              enabled: !item.useCatalog,
              controller: item.name,
              label: 'Tên hoạt động / địa điểm',
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) || (v?.length ?? 0) > 255
                  ? 'Nhập tên từ 1 đến 255 ký tự'
                  : null,
            ),
            const SizedBox(height: 8),
            CustomTextField(
              enabled: !item.useCatalog,
              controller: item.address,
              label: 'Địa chỉ (không bắt buộc)',
              validator: (v) =>
                  (v?.length ?? 0) > 500 ? 'Tối đa 500 ký tự' : null,
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(item.category),
              initialValue: item.category,
              isExpanded: true,
              items: [
                for (final e in {
                  'ATTRACTION': 'Tham quan',
                  'RESTAURANT': 'Ăn uống',
                  'CAFE': 'Cà phê',
                  'HOTEL': 'Lưu trú',
                  'ENTERTAINMENT': 'Giải trí',
                  'NATURE': 'Thiên nhiên',
                  'CULTURE': 'Văn hóa',
                  'SHOPPING': 'Mua sắm',
                  'OTHER': 'Khác',
                }.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: item.useCatalog
                  ? null
                  : (v) {
                      if (v != null) item.category = v;
                    },
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => pickTime(item, true),
                    child: Text('Bắt đầu ${item.start}'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => pickTime(item, false),
                    child: Text('Kết thúc ${item.end}'),
                  ),
                ),
              ],
            ),
            CustomTextField(
              controller: item.cost,
              label: 'Chi phí dự kiến (đ)',
              keyboardType: TextInputType.number,
              validator: money,
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: item.note,
              label: 'Ghi chú',
              maxLines: 2,
              validator: (v) =>
                  (v?.length ?? 0) > 1000 ? 'Tối đa 1000 ký tự' : null,
            ),
          ],
        ),
      ),
    );
  }
}
