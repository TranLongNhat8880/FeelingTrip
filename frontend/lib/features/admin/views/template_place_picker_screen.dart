import 'package:flutter/material.dart';
import '../../../shared/ui_kit.dart';
import '../../map/models/place_model.dart';
import '../../map/views/admin_place_form_screen.dart';
import '../repositories/admin_content_repository.dart';

class TemplatePlacePickerScreen extends StatefulWidget {
  const TemplatePlacePickerScreen({super.key, required this.destination});
  final String destination;
  @override
  State<TemplatePlacePickerScreen> createState() =>
      _TemplatePlacePickerScreenState();
}

class _TemplatePlacePickerScreenState extends State<TemplatePlacePickerScreen> {
  final repo = AdminContentRepository();
  final search = TextEditingController();
  List<PlaceModel> places = [];
  bool loading = false, hasMore = false, filterDestination = true;
  int page = 0, requestId = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    if (more && (loading || !hasMore)) return;
    final id = ++requestId;
    setState(() {
      loading = true;
      error = null;
      if (!more) {
        places = [];
        page = 0;
      }
    });
    try {
      final data = await repo.searchTemplatePlaces(
        keyword: search.text.trim(),
        destination: filterDestination ? widget.destination : '',
        page: more ? page + 1 : 1,
      );
      if (!mounted || id != requestId) return;
      setState(() {
        places = more ? [...places, ...data.items] : data.items;
        page = data.page;
        hasMore = data.hasMore;
      });
    } catch (e) {
      if (mounted && id == requestId) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && id == requestId) setState(() => loading = false);
    }
  }

  Future<void> addPlace() async {
    final place = await Navigator.push<PlaceModel>(
      context,
      MaterialPageRoute(builder: (_) => const AdminPlaceFormScreen()),
    );
    if (place == null || !mounted) return;
    setState(() {
      search.text = place.name;
      filterDestination = false;
    });
    await load();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Chọn địa điểm từ kho',
    padding: EdgeInsets.zero,
    body: RefreshIndicator(
      onRefresh: () => load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    hintText: 'Tên địa điểm hoặc địa chỉ',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => load(),
                ),
              ),
              IconButton(
                tooltip: 'Tìm địa điểm',
                onPressed: () => load(),
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          if (widget.destination.isNotEmpty)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Chỉ tìm tại ${widget.destination}'),
              value: filterDestination,
              onChanged: (v) {
                setState(() => filterDestination = v ?? false);
                load();
              },
            ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Thêm địa điểm',
            icon: Icons.add_location_alt_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: loading ? null : addPlace,
          ),
          const SizedBox(height: 12),
          if (error != null) ErrorState(message: error!, onRetry: () => load()),
          if (!loading && error == null && places.isEmpty)
            const EmptyStateWidget(
              title: 'Chưa tìm thấy địa điểm',
              message:
                  'Thử đổi từ khóa, bỏ lọc điểm đến hoặc thêm địa điểm mới.',
              icon: Icons.place_outlined,
            ),
          for (final place in places)
            Card(
              child: ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(place.name),
                subtitle: Text(place.displayLocation),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, place),
              ),
            ),
          if (loading)
            const LoadingIndicator()
          else if (hasMore)
            TextButton(
              onPressed: () => load(more: true),
              child: const Text('Tải thêm địa điểm'),
            ),
        ],
      ),
    ),
  );
}
