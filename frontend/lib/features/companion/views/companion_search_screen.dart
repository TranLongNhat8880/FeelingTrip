import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../viewmodels/companion_feed_viewmodel.dart';
import 'companion_detail_screen.dart';
import 'widgets/companion_post_card.dart';

// Travel names, not an administrative province directory or available-post list.
const companionDestinations = <String>[
  'Hà Nội',
  'Hà Nam',
  'Hà Giang',
  'Hà Tĩnh',
  'Hạ Long',
  'Hải Phòng',
  'Hải Dương',
  'Hòa Bình',
  'Hồ Hoàn Kiếm',
  'Hồ Tây',
  'Sa Pa',
  'Lào Cai',
  'Ninh Bình',
  'Mộc Châu',
  'Mai Châu',
  'Cao Bằng',
  'Quảng Ninh',
  'Thanh Hóa',
  'Nghệ An',
  'Quảng Bình',
  'Huế',
  'Đà Nẵng',
  'Hội An',
  'Quy Nhơn',
  'Phú Yên',
  'Nha Trang',
  'Đà Lạt',
  'Phan Thiết',
  'Mũi Né',
  'Vũng Tàu',
  'TP. Hồ Chí Minh',
  'Cần Thơ',
  'Phú Quốc',
  'Côn Đảo',
];

String normalizeDestination(String value) {
  var result = value.toLowerCase().trim();
  const groups = <String, String>{
    'àáạảãâầấậẩẫăằắặẳẵ': 'a',
    'èéẹẻẽêềếệểễ': 'e',
    'ìíịỉĩ': 'i',
    'òóọỏõôồốộổỗơờớợởỡ': 'o',
    'ùúụủũưừứựửữ': 'u',
    'ỳýỵỷỹ': 'y',
    'đ': 'd',
  };
  for (final group in groups.entries) {
    for (final rune in group.key.runes) {
      result = result.replaceAll(String.fromCharCode(rune), group.value);
    }
  }
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

List<String> suggestCompanionDestinations(
  String query,
  Iterable<String> extra,
) {
  final term = normalizeDestination(query);
  final seen = <String>{};
  final candidates = [...extra, ...companionDestinations].where((name) {
    final normalized = normalizeDestination(name);
    return normalized.isNotEmpty &&
        seen.add(normalized) &&
        (term.isEmpty || normalized.contains(term));
  }).toList();
  // Stable partition: prefix matches first, keeping supplied destination order.
  return [
    ...candidates.where((d) => normalizeDestination(d).startsWith(term)),
    ...candidates.where((d) => !normalizeDestination(d).startsWith(term)),
  ].take(8).toList();
}

class CompanionSearchScreen extends StatefulWidget {
  const CompanionSearchScreen({
    super.key,
    this.destinations = const [],
    this.sortBy = 'newest',
    this.status = 'OPEN',
    this.genderPreference = '',
  });
  final List<String> destinations;
  final String sortBy, status, genderPreference;
  @override
  State<CompanionSearchScreen> createState() => _CompanionSearchScreenState();
}

class _CompanionSearchScreenState extends State<CompanionSearchScreen> {
  final _controller = TextEditingController();
  final _vm = CompanionFeedViewModel();
  final _scrollController = ScrollController();
  bool _showResults = false;
  String _submittedQuery = '';

  @override
  void initState() {
    super.initState();
    _vm.addListener(_changed);
    _scrollController.addListener(_loadMore);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _loadMore() {
    if (_scrollController.position.extentAfter < 200) _vm.loadMore();
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
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    final sameQuery = _vm.destination == query;
    _vm.applyFilter(
      destination: query,
      sortBy: widget.sortBy,
      status: widget.status,
      genderPreference: widget.genderPreference,
    );
    if (sameQuery && !_vm.isLoading) _vm.load(refresh: true);
  }

  @override
  void dispose() {
    _vm.removeListener(_changed);
    _vm.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            onChanged: (_) => setState(() => _showResults = false),
            decoration: InputDecoration(
              hintText: 'Tìm điểm đến du lịch...',
              filled: true,
              fillColor: AppColors.inputSurface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _controller.text.isEmpty
                  ? const Icon(Icons.search_rounded)
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.close_rounded),
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
      body: _showResults
          ? _results()
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                for (final destination
                    in _controller.text.trim().isEmpty
                        ? <String>[]
                        : suggestions)
                  ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(destination),
                    trailing: const Icon(Icons.north_west_rounded, size: 18),
                    onTap: () => _search(destination),
                  ),
                if (_controller.text.trim().isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.search_rounded),
                    title: Text('Tìm “${_controller.text.trim()}”'),
                    subtitle: const Text(
                      'Tìm theo điểm đến hoặc tiêu đề bài tuyển',
                    ),
                    onTap: () => _search(_controller.text),
                  ),
              ],
            ),
    );
  }

  Widget _results() {
    if (_vm.isLoading) return const Center(child: CircularProgressIndicator());
    if (_vm.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_vm.errorMessage!, textAlign: TextAlign.center),
              TextButton(
                onPressed: () => _vm.load(refresh: true),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (_vm.posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Chưa có bài tuyển phù hợp với “$_submittedQuery”.\nThử một điểm đến hoặc từ khóa khác.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _vm.load(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _vm.posts.length + (_vm.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (context, index) {
          if (index == _vm.posts.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final post = _vm.posts[index];
          return CompanionPostCard(
            post: post,
            onTap: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => CompanionDetailScreen(postId: post.id),
                ),
              );
              if (mounted) _vm.load(refresh: true);
            },
          );
        },
      ),
    );
  }
}
