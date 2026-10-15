import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/ui_kit.dart';
import '../../companion/views/companion_search_screen.dart';
import '../repositories/itinerary_repository.dart';
import '../viewmodels/itinerary_viewmodel.dart';
import 'public_itineraries_screen.dart';

class PublicItinerarySearchScreen extends StatefulWidget {
  const PublicItinerarySearchScreen({
    super.key,
    this.repository,
    this.destinations = const [],
    this.initialQuery,
  });

  final ItineraryRepository? repository;
  final List<String> destinations;
  final String? initialQuery;

  @override
  State<PublicItinerarySearchScreen> createState() =>
      _PublicItinerarySearchScreenState();
}

class _PublicItinerarySearchScreenState
    extends State<PublicItinerarySearchScreen> {
  final _controller = TextEditingController();
  late final PublicItineraryViewModel _viewModel;
  bool _showResults = false;
  String _submittedQuery = '';

  static const _popularDestinations = [
    'Hà Nội',
    'Đà Nẵng',
    'Đà Lạt',
    'Sa Pa',
    'Phú Quốc',
    'Ninh Bình',
    'Hội An',
    'Nha Trang',
    'TP. Hồ Chí Minh',
  ];

  @override
  void initState() {
    super.initState();
    _viewModel = PublicItineraryViewModel(repository: widget.repository)
      ..addListener(_onChanged);

    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _controller.text = widget.initialQuery!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search(_controller.text);
      });
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    setState(() {
      _showResults = true;
      _submittedQuery = query;
    });
    _viewModel.load(keyword: query);
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = suggestCompanionDestinations(
      _controller.text,
      widget.destinations,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _controller,
            autofocus: widget.initialQuery == null || widget.initialQuery!.isEmpty,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            onChanged: (_) {
              if (_showResults) {
                setState(() => _showResults = false);
              } else {
                setState(() {});
              }
            },
            decoration: InputDecoration(
              hintText: 'Tìm kiếm lịch trình, điểm đến...',
              hintStyle: const TextStyle(
                color: AppColors.textHint,
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppColors.inputSurface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textHint,
                size: 20,
              ),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _showResults = false);
                      },
                    ),
            ),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: .5),
        ),
      ),
      body: _showResults ? _buildResults() : _buildSuggestions(suggestions),
    );
  }

  Widget _buildSuggestions(List<String> suggestions) {
    final text = _controller.text.trim();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        if (text.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.explore_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Gợi ý điểm đến phổ biến',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _popularDestinations.map((dest) {
                return ActionChip(
                  label: Text(dest),
                  avatar: const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  backgroundColor: AppColors.inputSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onPressed: () => _search(dest),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
        ],
        if (text.isNotEmpty) ...[
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
            ),
            title: Text(
              'Tìm “$text”',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Tìm theo tên lịch trình hoặc điểm đến'),
            onTap: () => _search(text),
          ),
          const Divider(height: 1),
        ],
        for (final dest in suggestions)
          ListTile(
            leading: const Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
            ),
            title: Text(dest),
            trailing: const Icon(
              Icons.north_west_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            onTap: () => _search(dest),
          ),
      ],
    );
  }

  Widget _buildResults() {
    if (_viewModel.isLoading) {
      return const Center(
        child: LoadingIndicator(message: 'Đang tìm kiếm lịch trình...'),
      );
    }

    if (_viewModel.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_viewModel.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Thử lại',
                variant: AppButtonVariant.secondary,
                onPressed: () => _search(_submittedQuery),
              ),
            ],
          ),
        ),
      );
    }

    if (_viewModel.plans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyStateWidget(
            icon: Icons.search_off_rounded,
            title: 'Chưa có lịch trình phù hợp',
            message:
                'Không tìm thấy lịch trình nào cho "$_submittedQuery". Hãy thử tìm kiếm với tên địa danh khác.',
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _viewModel.load(keyword: _submittedQuery),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        itemCount: _viewModel.plans.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_viewModel.plans.length} kết quả cho “$_submittedQuery”',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Chọn lọc này'),
                    onPressed: () => Navigator.pop(context, _submittedQuery),
                  ),
                ],
              ),
            );
          }

          final plan = _viewModel.plans[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PublicPlanCard(
              plan: plan,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PublicItineraryDetailScreen(
                    summary: plan,
                    repository: widget.repository,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

