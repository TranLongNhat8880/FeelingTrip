import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/storage_helper.dart';
import '../../../shared/ui_kit.dart';
import '../models/place_search_result.dart';
import '../repositories/place_search_repository.dart';

class PlaceLocationPickerScreen extends StatefulWidget {
  const PlaceLocationPickerScreen({super.key, this.initialLocation});

  final PlaceSearchResult? initialLocation;

  @override
  State<PlaceLocationPickerScreen> createState() =>
      _PlaceLocationPickerScreenState();
}

class _PlaceLocationPickerScreenState extends State<PlaceLocationPickerScreen> {
  final _repository = PlaceSearchRepository();
  final _mapController = MapController();
  final _searchController = TextEditingController();

  Timer? _searchTimer;
  Timer? _addressTimer;

  List<PlaceSearchResult> _results = const [];
  PlaceSearchResult? _selected;

  bool _isSearching = false;
  bool _isLookingUpAddress = false;
  String? _searchMessage;
  String? _addressMessage;

  int _searchRequest = 0;
  int _addressRequest = 0;
  bool? _configured;
  String? _configurationError;
  String? _tileErrorMessage;
  bool _tileErrorPending = false;
  int _configurationRequest = 0;
  NetworkTileProvider? _tileProvider;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    final request = ++_configurationRequest;
    setState(() {
      _configured = null;
      _configurationError = null;
      _tileErrorMessage = null;
      _tileErrorPending = false;
      _tileProvider = null;
    });
    try {
      final configured = await _repository.isConfigured();
      if (!mounted || request != _configurationRequest) return;
      if (!configured) {
        setState(() => _configured = false);
        return;
      }
      final token = await StorageHelper.getToken();
      if (!mounted || request != _configurationRequest) return;
      if (token == null || token.trim().isEmpty) {
        throw const PlaceSearchException(
          'Vui lòng đăng nhập lại bằng tài khoản quản trị viên để tải bản đồ.',
        );
      }
      setState(() {
        _configured = true;
        _tileProvider = NetworkTileProvider(
          headers: {'Authorization': 'Bearer ${token.trim()}'},
          httpClient: ApiClient.client,
          // Backend trả lỗi JSON, không phải ảnh PNG cần giải mã.
          attemptDecodeOfHttpErrorResponses: false,
        );
      });
    } catch (error) {
      if (!mounted || request != _configurationRequest) return;
      setState(() => _configurationError = _messageFor(error));
    }
  }

  void _onTileError(Object error, int request) {
    if (!mounted ||
        request != _configurationRequest ||
        _tileErrorPending ||
        _tileErrorMessage != null) {
      return;
    }

    final status = error is NetworkImageLoadException ? error.statusCode : null;
    final message = switch (status) {
      401 || 403 =>
        'Phiên đăng nhập hết hạn hoặc không có quyền tải bản đồ. '
            'Vui lòng đăng nhập lại.',
      429 => 'Dịch vụ bản đồ đang giới hạn lượt gọi. Vui lòng thử lại sau.',
      503 => 'Dịch vụ bản đồ chưa được cấu hình trên máy chủ.',
      _ => 'Không tải được ảnh bản đồ. Kiểm tra kết nối và thử lại.',
    };

    // Nhiều tile có thể cùng báo lỗi trong một khung hình.
    _tileErrorPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || request != _configurationRequest) return;
      setState(() {
        _tileErrorPending = false;
        _tileErrorMessage = message;
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _addressTimer?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();

    final request = ++_searchRequest;
    final query = value.trim();

    setState(() {
      _results = const [];
      _searchMessage = null;
      _isSearching = query.length >= 3;
    });

    if (query.length < 3) return;

    // Đợi người dùng ngừng gõ rồi mới gọi API.
    _searchTimer = Timer(
      const Duration(milliseconds: 600),
      () => _search(query, request),
    );
  }

  Future<void> _search(String query, int request) async {
    try {
      final results = await _repository.searchPlaces(query);

      if (!mounted || request != _searchRequest) return;

      setState(() {
        _results = results;
        _isSearching = false;
        _searchMessage = results.isEmpty
            ? 'Không tìm thấy. Thử thêm tên đường hoặc thành phố.'
            : null;
      });
    } catch (error) {
      if (!mounted || request != _searchRequest) return;

      setState(() {
        _isSearching = false;
        _searchMessage = _messageFor(error);
      });
    }
  }

  void _selectSearchResult(PlaceSearchResult result) {
    _searchTimer?.cancel();
    _addressTimer?.cancel();

    ++_searchRequest;
    ++_addressRequest;

    FocusScope.of(context).unfocus();

    setState(() {
      _selected = result;
      _results = const [];
      _isSearching = false;
      _isLookingUpAddress = false;
      _searchMessage = null;
      _addressMessage = null;
      _searchController.text = result.name;
    });

    _mapController.move(LatLng(result.latitude, result.longitude), 16);
  }

  void _selectMapPoint(LatLng point) {
    _searchTimer?.cancel();
    _addressTimer?.cancel();

    ++_searchRequest;
    final request = ++_addressRequest;

    FocusScope.of(context).unfocus();

    setState(() {
      // Chạm bản đồ chọn tọa độ ngay, không chờ API địa chỉ.
      _selected = PlaceSearchResult(
        id: '${point.latitude},${point.longitude}',
        name: '',
        formattedAddress: '',
        latitude: point.latitude,
        longitude: point.longitude,
      );

      _results = const [];
      _searchController.clear();
      _isSearching = false;
      _isLookingUpAddress = true;
      _searchMessage = null;
      _addressMessage = null;
    });

    // Chỉ tra địa chỉ sau khi người dùng ngừng đổi ghim.
    _addressTimer = Timer(
      const Duration(milliseconds: 600),
      () => _lookupAddress(point, request),
    );
  }

  Future<void> _lookupAddress(LatLng point, int request) async {
    try {
      final result = await _repository.reverseGeocode(
        latitude: point.latitude,
        longitude: point.longitude,
      );

      if (!mounted || request != _addressRequest) return;

      setState(() {
        _isLookingUpAddress = false;

        if (result == null) {
          _addressMessage =
              'Chưa tìm được địa chỉ. Bạn vẫn có thể dùng tọa độ này.';
          return;
        }

        _selected = result.copyWith(
          // Địa chỉ gần ghim không nhất thiết là tên địa điểm.
          name: '',
          latitude: point.latitude,
          longitude: point.longitude,
        );
      });
    } catch (error) {
      if (!mounted || request != _addressRequest) return;

      setState(() {
        _isLookingUpAddress = false;
        _addressMessage =
            '${_messageFor(error)} Bạn vẫn có thể dùng tọa độ đã chọn.';
      });
    }
  }

  String _messageFor(Object error) {
    if (error is PlaceSearchException) return error.message;
    return 'Không thể tra cứu địa điểm. Vui lòng thử lại.';
  }

  void _confirm() {
    final selected = _selected;

    if (selected == null || _isLookingUpAddress) return;

    Navigator.pop(context, selected);
  }

  Widget _sourceLink(String label, String url) {
    return InkWell(
      onTap: () async {
        await launchUrl(Uri.parse(url));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    final selected = _selected;
    final initial = selected;
    final request = _configurationRequest;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initial == null
                ? const LatLng(21.028666, 105.852148)
                : LatLng(initial.latitude, initial.longitude),
            initialZoom: initial == null ? 12 : 16,
            minZoom: 4,
            maxZoom: 20,
            onTap: (_, point) => _selectMapPoint(point),
          ),
          children: [
            TileLayer(
              urlTemplate: PlaceSearchRepository.tileUrlTemplate,
              tileProvider: _tileProvider!,
              maxNativeZoom: 20,
              errorTileCallback: (_, error, _) => _onTileError(error, request),
            ),
            if (selected != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(selected.latitude, selected.longitude),
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      size: 48,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (_results.isNotEmpty)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = _results[index];

                    return ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(
                        result.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        result.formattedAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectSearchResult(result),
                    );
                  },
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ColoredBox(
            color: Colors.white,
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                _sourceLink(
                  '© OpenStreetMap contributors',
                  'https://www.openstreetmap.org/copyright',
                ),
                _sourceLink('Powered by Geoapify', 'https://www.geoapify.com/'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_configurationError != null) {
      return AppScaffold(
        showKoharu: false,
        title: 'Chọn vị trí địa điểm',
        body: ErrorState(
          message: _configurationError!,
          onRetry: _loadConfiguration,
        ),
      );
    }
    if (_configured == null) {
      return const AppScaffold(
        showKoharu: false,
        title: 'Chọn vị trí địa điểm',
        body: LoadingIndicator(message: 'Đang kết nối bản đồ...'),
      );
    }
    if (!_configured!) {
      return AppScaffold(
        showKoharu: false,
        title: 'Chọn vị trí địa điểm',
        body: ErrorState(
          message:
              'Dịch vụ bản đồ chưa sẵn sàng trên máy chủ. '
              'Vui lòng liên hệ quản trị viên hoặc thử lại sau.',
          onRetry: _loadConfiguration,
        ),
      );
    }

    final selected = _selected;

    return AppScaffold(
      showKoharu: false,
      title: 'Chọn vị trí địa điểm',
      padding: const EdgeInsets.all(12),
      bottomAction: CustomButton(
        text: 'Dùng vị trí này',
        icon: Icons.check_rounded,
        onPressed: selected == null || _isLookingUpAddress ? null : _confirm,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            label: 'Tìm địa điểm',
            hint: 'Ví dụ: Hồ Hoàn Kiếm, Hà Nội',
            controller: _searchController,
            prefixIcon: Icons.search_rounded,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
          ),
          const SizedBox(height: 8),
          if (_isSearching)
            const LinearProgressIndicator()
          else if (_searchMessage != null)
            Text(_searchMessage!, style: Theme.of(context).textTheme.bodySmall)
          else
            Text(
              'Nhập ít nhất 3 ký tự. Chạm bản đồ để điều chỉnh ghim.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          if (_tileErrorMessage != null)
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _tileErrorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadConfiguration,
                    child: const Text('Thử lại bản đồ'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildMap(),
            ),
          ),
          const SizedBox(height: 10),
          if (selected == null)
            const Text('Chọn kết quả tìm kiếm hoặc chạm lên bản đồ.')
          else ...[
            if (_isLookingUpAddress)
              const Text('Đang tìm địa chỉ gần vị trí đã chọn...')
            else if (selected.formattedAddress.isNotEmpty)
              Text(
                selected.formattedAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            else
              const Text('Vị trí đã chọn trên bản đồ'),
            const SizedBox(height: 4),
            Text(
              'Vĩ độ: ${selected.latitude.toStringAsFixed(6)} · '
              'Kinh độ: ${selected.longitude.toStringAsFixed(6)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_addressMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                _addressMessage!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
