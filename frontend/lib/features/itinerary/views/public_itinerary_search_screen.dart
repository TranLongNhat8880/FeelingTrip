import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/ui_kit.dart';
import '../../admin/models/admin_content_model.dart';
import '../../admin/repositories/admin_content_repository.dart';
import '../../admin/views/plan_library_screen.dart';
import '../../companion/views/companion_search_screen.dart';
import '../../review/repositories/trip_reviews_repository.dart';
import '../models/itinerary_model.dart';
import '../repositories/itinerary_repository.dart';
import 'public_itineraries_screen.dart';

class PublicItinerarySearchScreen extends StatefulWidget {
  const PublicItinerarySearchScreen({
    super.key,
    this.source = 'COMMUNITY',
    this.repository,
    this.reviewsRepository,
    this.destinations = const [],
    this.initialQuery,
  });

  final String source;
  final ItineraryRepository? repository;
  final TripReviewsRepository? reviewsRepository;
  final List<String> destinations;
  final String? initialQuery;

  @override
  State<PublicItinerarySearchScreen> createState() =>
      _PublicItinerarySearchScreenState();
}

class _PublicItinerarySearchScreenState
    extends State<PublicItinerarySearchScreen> {
  final _controller = TextEditingController();
  final _adminRepo = AdminContentRepository();
  late String _currentSource;
  bool _isLoading = false;
  String? _errorMessage;
  List<LibraryPlan> _results = [];
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
    _currentSource = widget.source;
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _controller.text = widget.initialQuery!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search(_controller.text);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
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
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_currentSource == 'COMMUNITY') {
        if (widget.repository != null) {
          final res = await widget.repository!.getPublicPlans(keyword: query);
          final items = res.items
              .map((p) => LibraryPlan({
                    'id': p.sourceTripId,
                    'name': p.name,
                    'destination': p.destination,
                    'durationDays': p.durationDays,
                    'coverImageUrl': p.coverImageUrl,
                    'description': p.description,
                    'source': 'COMMUNITY',
                    'usageCount': p.cloneCount,
                    'averageRating': p.averageRating,
                    'reviewCount': p.reviewCount,
                    'isActive': true,
                  }))
              .toList();
          if (mounted) setState(() => _results = items);
        } else {
          final list = await _adminRepo.plans(
            source: 'COMMUNITY',
            search: query,
          );
          if (mounted) setState(() => _results = list);
        }
      } else {
        // SYSTEM
        final list = await _adminRepo.plans(
          source: 'SYSTEM',
          search: query,
        );
        if (mounted) setState(() => _results = list);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            autofocus:
                widget.initialQuery == null || widget.initialQuery!.isEmpty,
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
              hintText: _currentSource == 'SYSTEM'
                  ? 'Tìm kiếm mẫu lịch trình hệ thống...'
                  : 'Tìm kiếm lịch trình cộng đồng...',
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
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Mẫu hệ thống'),
                      selected: _currentSource == 'SYSTEM',
                      onSelected: (_) {
                        setState(() => _currentSource = 'SYSTEM');
                        if (_controller.text.trim().isNotEmpty) {
                          _search(_controller.text.trim());
                        }
                      },
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFFE0F2FE),
                      labelStyle: TextStyle(
                        color: _currentSource == 'SYSTEM'
                            ? const Color(0xFF0369A1)
                            : const Color(0xFF334155),
                        fontWeight: _currentSource == 'SYSTEM'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _currentSource == 'SYSTEM'
                              ? const Color(0xFFBAE6FD)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      showCheckmark: true,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Cộng đồng'),
                      selected: _currentSource == 'COMMUNITY',
                      onSelected: (_) {
                        setState(() => _currentSource = 'COMMUNITY');
                        if (_controller.text.trim().isNotEmpty) {
                          _search(_controller.text.trim());
                        }
                      },
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFFE0F2FE),
                      labelStyle: TextStyle(
                        color: _currentSource == 'COMMUNITY'
                            ? const Color(0xFF0369A1)
                            : const Color(0xFF334155),
                        fontWeight: _currentSource == 'COMMUNITY'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _currentSource == 'COMMUNITY'
                              ? const Color(0xFFBAE6FD)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      showCheckmark: true,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: .5),
            ],
          ),
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
              child: const Icon(
                Icons.search_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              'Tìm “$text”',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _currentSource == 'SYSTEM'
                  ? 'Tìm theo tên mẫu lịch trình hoặc điểm đến'
                  : 'Tìm theo tên lịch trình hoặc điểm đến',
            ),
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
    if (_isLoading) {
      return Center(
        child: LoadingIndicator(
          message: _currentSource == 'SYSTEM'
              ? 'Đang tìm kiếm mẫu hệ thống...'
              : 'Đang tìm kiếm lịch trình cộng đồng...',
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
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

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyStateWidget(
            icon: Icons.search_off_rounded,
            title: 'Chưa có lịch trình phù hợp',
            message:
                'Không tìm thấy ${_currentSource == 'SYSTEM' ? 'mẫu hệ thống' : 'lịch trình cộng đồng'} nào cho "$_submittedQuery". Hãy thử tìm kiếm với tên địa danh khác.',
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _search(_submittedQuery),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        itemCount: _results.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_results.length} kết quả cho “$_submittedQuery”',
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
                    onPressed: () => Navigator.pop(
                      context,
                      (query: _submittedQuery, source: _currentSource),
                    ),
                  ),
                ],
              ),
            );
          }

          final plan = _results[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PublicPlanCard(
              plan: PublicItinerarySummary(
                sourceTripId: plan.id,
                name: plan.name,
                destination: plan.destination,
                durationDays: plan.durationDays,
                coverImageUrl: plan.cover,
                description: plan.description,
                averageRating: plan.rating,
                reviewCount: plan.reviews,
                cloneCount: plan.usage,
              ),
              onTap: () {
                if (plan.community) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublicItineraryDetailScreen(
                        summary: PublicItinerarySummary(
                          sourceTripId: plan.id,
                          name: plan.name,
                          destination: plan.destination,
                          durationDays: plan.durationDays,
                          coverImageUrl: plan.cover,
                          description: plan.description,
                          averageRating: plan.rating,
                          reviewCount: plan.reviews,
                          cloneCount: plan.usage,
                        ),
                        repository: widget.repository,
                        reviewsRepository: widget.reviewsRepository,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlanDetailScreen(plan: plan),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
