import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/ui_kit.dart';
import '../models/itinerary_model.dart';
import '../repositories/api_itinerary_repository.dart';
import '../repositories/itinerary_repository.dart';
import '../repositories/mock_itinerary_repository.dart';
import 'widgets/itinerary_widgets.dart';

class ItineraryPlaceSearchScreen extends StatefulWidget {
  const ItineraryPlaceSearchScreen({
    super.key,
    required this.destination,
    this.repository,
  });

  final String destination;
  final ItineraryRepository? repository;

  @override
  State<ItineraryPlaceSearchScreen> createState() =>
      _ItineraryPlaceSearchScreenState();
}

class _ItineraryPlaceSearchScreenState
    extends State<ItineraryPlaceSearchScreen> {
  final _searchController = TextEditingController();
  late final ItineraryRepository _repo;
  Timer? _debounceTimer;

  bool _isLoading = false;
  String? _errorMessage;
  List<ItineraryPlaceOption> _allPlaces = [];
  String? _selectedCategory; // null = Tất cả

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ??
        (ApiEndpoints.useMockData
            ? MockItineraryRepository()
            : ApiItineraryRepository());
    _fetchPlaces();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchPlaces(keyword: query.trim());
    });
  }

  List<String> _extractDestinationCandidates(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    final candidates = <String>[];

    void addCandidate(String s) {
      final c = s.trim();
      if (c.isNotEmpty && !candidates.contains(c)) {
        candidates.add(c);
      }
    }

    addCandidate(trimmed);

    if (trimmed.contains(',')) {
      final segments = trimmed
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (segments.isNotEmpty) {
        final lastSeg = segments.last;
        addCandidate(lastSeg);

        // Bỏ tiền tố hành chính (Tỉnh, Thành phố, TP)
        final cleanProvince = lastSeg.replaceAll(
          RegExp(r'^(tỉnh|thành phố|tp\.?)\s+', caseSensitive: false),
          '',
        ).trim();
        addCandidate(cleanProvince);
      }

      for (int i = segments.length - 2; i >= 0; i--) {
        final seg = segments[i];
        final clean = seg.replaceAll(
          RegExp(r'^(quận|huyện|thị xã|thành phố|phường|xã)\s+', caseSensitive: false),
          '',
        ).trim();
        addCandidate(clean);
      }
    } else {
      final clean = trimmed.replaceAll(
        RegExp(r'^(tỉnh|thành phố|tp\.?)\s+', caseSensitive: false),
        '',
      ).trim();
      addCandidate(clean);
    }

    return candidates;
  }

  Future<void> _fetchPlaces({String? keyword}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final kw = keyword ?? _searchController.text.trim();
      List<ItineraryPlaceOption> result = const [];
      final candidates = _extractDestinationCandidates(widget.destination);

      if (candidates.isEmpty) {
        result = await _repo.searchPlaces(
          destination: '',
          keyword: kw.isNotEmpty ? kw : null,
        );
      } else {
        for (final candidate in candidates) {
          result = await _repo.searchPlaces(
            destination: candidate,
            keyword: kw.isNotEmpty ? kw : null,
          );
          if (result.isNotEmpty) break;
        }
      }

      if (!mounted) return;
      setState(() {
        _allPlaces = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$e'.replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<ItineraryPlaceOption> get _filteredPlaces {
    if (_selectedCategory == null) return _allPlaces;
    return _allPlaces
        .where((p) => p.category.toUpperCase() == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final places = _filteredPlaces;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.inputSurface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (text) {
                setState(() {});
                _onSearchChanged(text);
              },
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: widget.destination.isNotEmpty
                    ? 'Tìm địa điểm tại ${widget.destination}...'
                    : 'Tìm địa điểm trong kho gợi ý...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.cancel_rounded,
                          size: 18,
                          color: AppColors.textHint,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          _fetchPlaces(keyword: '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 0.5, color: AppColors.border),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── CATEGORY FILTER CHIPS ──────────────────────────────────────
          _buildCategoryFilterBar(),

          // ─── CONTENT / RESULT LIST ──────────────────────────────────────
          Expanded(
            child: _buildBody(places),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterBar() {
    final categories = [
      null, // Tất cả
      ...itineraryCategories.keys,
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategory == cat;
          final label = cat == null ? 'Tất cả' : categoryLabel(cat);
          final icon = cat == null ? Icons.apps_rounded : getCategoryIcon(cat);
          final color = cat == null ? AppColors.primary : getCategoryColor(cat);

          return InkWell(
            onTap: () {
              setState(() {
                _selectedCategory = cat;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: isSelected ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: isSelected ? color : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? color : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(List<ItineraryPlaceOption> places) {
    if (_isLoading) {
      return const Center(child: LoadingIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _fetchPlaces(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (places.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 32,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Không tìm thấy địa điểm phù hợp',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _searchController.text.isNotEmpty
                    ? 'Không có kết quả cho từ khóa "${_searchController.text.trim()}". Thử tìm từ khóa khác hoặc chuyển phân loại.'
                    : 'Kho gợi ý chưa có địa điểm mẫu tại khu vực này. Bạn có thể quay lại và dùng tab "Tự nhập" để thêm bất kỳ điểm dừng nào nhé!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      itemCount: places.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              'Gợi ý địa điểm (${places.length})',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final place = places[index - 1];
        return _buildPlaceItem(place);
      },
    );
  }

  Widget _buildPlaceItem(ItineraryPlaceOption place) {
    final catColor = getCategoryColor(place.category);
    final catIcon = getCategoryIcon(place.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => Navigator.pop(context, place),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(catIcon, size: 20, color: catColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              place.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (place.rating > 0) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: Color(0xFFFFB703),
                            ),
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
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        place.address ?? place.destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          categoryLabel(place.category),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
