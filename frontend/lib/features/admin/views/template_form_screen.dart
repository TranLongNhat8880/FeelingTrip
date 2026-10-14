import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/ui_kit.dart';
import '../../../core/constants/app_colors.dart';
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
  int selectedTab = 0;
  int expandedItem = 0;
  final scroll = ScrollController();
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
    scroll.dispose();
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
    final current = start ? item.start : item.end;
    final value = (validTime(current) ? current : '09:00').split(':');
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
    if (requiredText(name.text, 255) != null ||
        requiredText(destination.text, 100) != null ||
        money(budget.text) != null ||
        description.text.length > 5000) {
      setState(() {
        selectedTab = 0;
        error = 'Kiểm tra tên mẫu, điểm đến, ngân sách và mô tả.';
      });
      return;
    }
    for (var d = 0; d < days.length; d++) {
      for (var i = 0; i < days[d].items.length; i++) {
        final item = days[d].items[i];
        String? message;
        if (item.useCatalog && item.placeId == null) {
          message = 'Chọn địa điểm từ kho hoặc chuyển sang nhập tự do.';
        } else if (item.name.text.trim().isEmpty ||
            item.name.text.trim().length > 255 ||
            item.address.text.length > 500 ||
            money(item.cost.text) != null ||
            item.note.text.length > 1000) {
          message = 'Kiểm tra tên hoạt động, địa chỉ, chi phí và ghi chú.';
        } else if (!validTime(item.start) ||
            !validTime(item.end) ||
            item.start.compareTo(item.end) >= 0 ||
            (i > 0 && item.start.compareTo(days[d].items[i - 1].end) < 0)) {
          message =
              'Nhập giờ HH:mm; giờ kết thúc phải sau bắt đầu và không trùng hoạt động trước.';
        }
        if (message != null) {
          setState(() {
            selectedTab = d + 1;
            expandedItem = i;
            error = 'Ngày ${d + 1} · Hoạt động ${i + 1}: $message';
          });
          if (scroll.hasClients) scroll.jumpTo(0);
          return;
        }
      }
    }
    if (!(form.currentState?.validate() ?? false)) return;
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

  bool validTime(String value) =>
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

  void selectTab(int index) {
    FocusScope.of(context).unfocus();
    setState(() {
      error = null;
      selectedTab = index;
      expandedItem = 0;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: widget.plan == null ? 'Thêm lịch trình mẫu' : 'Sửa lịch trình mẫu',
    padding: EdgeInsets.zero,
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
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index <= days.length; index++)
                      InkWell(
                        onTap: () => selectTab(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: selectedTab == index
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Text(
                            index == 0 ? 'Thông tin chung' : 'Ngày $index',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: selectedTab == index
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: selectedTab == index
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Thêm ngày',
                      icon: const Icon(Icons.add),
                      onPressed: days.length >= 30
                          ? null
                          : () {
                              setState(() {
                                days.add(_DayForm());
                                selectedTab = days.length;
                                expandedItem = 0;
                              });
                              if (scroll.hasClients) scroll.jumpTo(0);
                            },
                    ),
                  ],
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: AppInlineNotice(
                  message: error!,
                  tone: AppStatusTone.error,
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                child: selectedTab == 0 ? _information() : _day(),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _information() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Thông tin của mẫu', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(
        '${days.length} ngày · ${days.fold<int>(0, (total, day) => total + day.items.length)} hoạt động',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
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
        minLines: 3,
        maxLines: null,
        validator: (v) => (v?.length ?? 0) > 5000 ? 'Tối đa 5000 ký tự' : null,
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
      CustomButton(
        text: 'Chọn ảnh bìa (không bắt buộc)',
        onPressed: pickImage,
        icon: Icons.image_outlined,
        variant: AppButtonVariant.secondary,
      ),
      const SizedBox(height: 12),
      CustomButton(
        text: 'Tiếp tục · Ngày 1',
        variant: AppButtonVariant.secondary,
        onPressed: () => selectTab(1),
      ),
    ],
  );

  Widget _day() {
    final day = days[selectedTab - 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lịch hoạt động · ngày $selectedTab',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${day.items.length} hoạt động · Chạm một dòng để chỉnh sửa',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (days.length > 1)
              IconButton(
                tooltip: 'Xóa ngày',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final yes = await AppConfirmDialog.show(
                    context,
                    title: 'Xóa ngày $selectedTab?',
                    message:
                        'Các hoạt động trong ngày này sẽ bị xóa khỏi bản đang soạn.',
                    confirmLabel: 'Xóa ngày',
                  );
                  if (yes && mounted) {
                    setState(() {
                      days.removeAt(selectedTab - 1).dispose();
                      selectedTab = selectedTab > days.length
                          ? days.length
                          : selectedTab;
                      expandedItem = 0;
                    });
                  }
                },
              ),
          ],
        ),
        for (var i = 0; i < day.items.length; i++) activity(day, i),
        const SizedBox(height: 12),
        CustomButton(
          text: 'Thêm hoạt động',
          icon: Icons.add,
          variant: AppButtonVariant.secondary,
          onPressed: day.items.length >= 50
              ? null
              : () => setState(() {
                  final item = _ActivityForm();
                  if (day.items.isNotEmpty && validTime(day.items.last.end)) {
                    item.start = day.items.last.end;
                    final parts = item.start.split(':');
                    final minutes =
                        int.parse(parts[0]) * 60 + int.parse(parts[1]) + 60;
                    final end = minutes > 1439 ? 1439 : minutes;
                    item.end =
                        '${(end ~/ 60).toString().padLeft(2, '0')}:${(end % 60).toString().padLeft(2, '0')}';
                  }
                  day.items.add(item);
                  expandedItem = day.items.length - 1;
                }),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.inputSurface,
              ),
              onPressed: () => selectTab(selectedTab - 1),
              icon: const Icon(Icons.chevron_left),
              label: Text(
                selectedTab == 1
                    ? 'Thông tin chung'
                    : 'Ngày ${selectedTab - 1}',
              ),
            ),
            if (selectedTab < days.length)
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.inputSurface,
                ),
                onPressed: () => selectTab(selectedTab + 1),
                icon: const Icon(Icons.chevron_right),
                label: Text('Ngày ${selectedTab + 1}'),
              ),
          ],
        ),
      ],
    );
  }

  Widget activity(_DayForm day, int index) {
    final item = day.items[index];
    return Card(
      key: ObjectKey(item),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(
                      () => expandedItem = expandedItem == index ? -1 : index,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.start} – ${item.end}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.name.text.isEmpty
                                ? 'Hoạt động ${index + 1} · Chưa nhập'
                                : item.name.text,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: expandedItem == index ? 'Thu gọn' : 'Chỉnh sửa',
                  onPressed: () => setState(
                    () => expandedItem = expandedItem == index ? -1 : index,
                  ),
                  icon: Icon(
                    expandedItem == index
                        ? Icons.expand_less
                        : Icons.edit_outlined,
                  ),
                ),
                if (index > 0)
                  IconButton(
                    tooltip: 'Đưa lên',
                    onPressed: () {
                      setState(() {
                        day.items.removeAt(index);
                        day.items.insert(index - 1, item);
                        expandedItem = index - 1;
                      });
                    },
                    icon: const Icon(Icons.arrow_upward),
                  ),
                if (day.items.length > 1)
                  IconButton(
                    tooltip: 'Xóa hoạt động',
                    onPressed: () {
                      setState(() {
                        day.items.removeAt(index).dispose();
                        expandedItem = -1;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            if (expandedItem == index) ...[
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Chọn từ kho'),
                    labelStyle: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: const Color(0xFF09143B)),
                    selected: item.useCatalog,
                    onSelected: (_) => setState(() => item.useCatalog = true),
                  ),
                  ChoiceChip(
                    label: const Text('Nhập tự do'),
                    labelStyle: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: const Color(0xFF09143B)),
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
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.inputSurface,
                  ),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: timeField(item, true)),
                  const SizedBox(width: 12),
                  Expanded(child: timeField(item, false)),
                ],
              ),
              const SizedBox(height: 12),
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
                minLines: 2,
                maxLines: null,
                validator: (v) =>
                    (v?.length ?? 0) > 1000 ? 'Tối đa 1000 ký tự' : null,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.inputSurface,
                  ),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    setState(() => expandedItem = -1);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Xong hoạt động'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget timeField(_ActivityForm item, bool start) {
    final value = start ? item.start : item.end;
    return TextFormField(
      key: ValueKey('${identityHashCode(item)}-$start-$value'),
      initialValue: value,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: start ? 'Bắt đầu' : 'Kết thúc',
        hintText: 'HH:mm',
        suffixIcon: IconButton(
          tooltip: 'Chọn giờ',
          icon: const Icon(Icons.schedule, size: 20),
          onPressed: () => pickTime(item, start),
        ),
      ),
      validator: (v) => validTime(v ?? '') ? null : 'Nhập giờ HH:mm',
      onChanged: (v) {
        if (start) {
          item.start = v;
        } else {
          item.end = v;
        }
      },
    );
  }
}
