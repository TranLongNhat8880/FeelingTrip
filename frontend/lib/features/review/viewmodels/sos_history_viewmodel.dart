import 'package:flutter/foundation.dart';
import '../models/sos_model.dart';
import '../repositories/sos_repository.dart';

class SosHistoryViewModel extends ChangeNotifier {
  SosHistoryViewModel({SosHistoryRepository? repository})
    : _repository = repository ?? ApiSosRepository();
  final SosHistoryRepository _repository;
  List<SosAlert> _items = [];
  List<SosAlert> get items => List.unmodifiable(_items);
  bool loading = false, hasMore = false;
  String? error;
  int _offset = 0;
  bool _disposed = false;

  Future<void> load({bool more = false}) async {
    if (_disposed || loading || (more && !hasMore)) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await _repository
          .getHistory(offset: more ? _offset : 0)
          .timeout(const Duration(seconds: 20));
      if (_disposed) return;
      final merged = more ? [..._items, ...page.items] : page.items;
      // A new record between pages may shift offsets; don't show duplicates.
      _items = {for (final item in merged) item.id: item}.values.toList();
      _offset = (more ? _offset : 0) + page.items.length;
      hasMore = page.hasMore;
    } catch (_) {
      if (_disposed) return;
      error = 'Chưa tải được lịch sử SOS. Hãy thử lại.';
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
