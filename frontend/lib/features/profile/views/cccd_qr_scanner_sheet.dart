import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_colors.dart';
import '../models/cccd_qr_model.dart';
import '../scanner/cccd_scanner_platform.dart';

/// Modal quét mã QR trên thẻ CCCD gắn chip Việt Nam.
class CccdQrScannerSheet extends StatefulWidget {
  const CccdQrScannerSheet({super.key});

  /// Mở Scanner dưới dạng Fullscreen Dialog / Sheet và trả về [CccdQrModel] nếu quét thành công.
  static Future<CccdQrModel?> show(BuildContext context) {
    return Navigator.of(context).push<CccdQrModel>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CccdQrScannerSheet(),
      ),
    );
  }

  @override
  State<CccdQrScannerSheet> createState() => _CccdQrScannerSheetState();
}

class _CccdQrScannerSheetState extends State<CccdQrScannerSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  late final Animation<double> _scanLineAnimation;

  bool _isProcessing = false;
  String? _errorMessage;
  bool _isTorchOn = false;
  bool _closing = false;
  bool _disposed = false;
  bool _foreground = true;
  bool _inputOpen = false;
  Future<void> _cameraTask = Future<void>.value();
  Future<void>? _shutdown;

  bool get _wantCamera => !_closing && !_disposed && _foreground && !_inputOpen;

  // Start, switch, stop and dispose must never race the permission request.
  Future<void> _queueCamera(Future<void> Function() operation) {
    return _cameraTask = _cameraTask.then((_) async {
      try {
        await operation();
      } catch (error) {
        debugPrint('CCCD camera operation failed: ${error.runtimeType}');
      }
    });
  }

  Future<void> _syncCamera() => _queueCamera(() async {
    if (_shutdown != null) return;
    if (_wantCamera) {
      await _controller.start();
      if (!_wantCamera) await _controller.stop();
    } else {
      await _controller.stop();
    }
  });

  Future<void> _shutdownCamera() => _shutdown ??= _queueCamera(() async {
    await _controller.stop();
  });

  @override
  void initState() {
    super.initState();
    _foreground =
        (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) ==
        AppLifecycleState.resumed;
    installCccdCameraReleaseFix();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: kIsWeb ? CameraFacing.front : CameraFacing.back,
      torchEnabled: false,
      autoStart: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_closing) unawaited(_syncCamera());
    });
  }

  Future<void> _safeClose([CccdQrModel? result]) async {
    if (_closing || !mounted) return;
    _closing = true;
    _isProcessing = true;
    _animController.stop();
    await _shutdownCamera();
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _closing = true;
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    // The preview still rebuilds during the route's closing animation, so
    // dispose its notifier only after the scanner widget has unmounted.
    unawaited(_shutdownCamera().then((_) => _queueCamera(_controller.dispose)));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_closing) unawaited(_syncCamera());
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || !_wantCamera) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;

      final qrModel = CccdQrModel.parse(rawValue);
      if (qrModel != null) {
        _safeClose(qrModel);
        return;
      } else {
        setState(() {
          _errorMessage =
              'Mã QR không đúng định dạng CCCD gắn chip (12 số). Vui lòng thử lại!';
        });
      }
    }
  }

  void _useSampleQrData() {
    if (_isProcessing) return;

    // Chuỗi mẫu chuẩn định dạng Bộ Công An phục vụ demo & kiểm thử
    const sampleRaw =
        '079099001234||TRẦN LONG NHẬT|20102002|Nam|123 Nguyễn Văn Cừ, Phường 4, Quận 5, TP. Hồ Chí Minh|15042021';
    final sampleModel = CccdQrModel.parse(sampleRaw);
    _safeClose(sampleModel);
  }

  void _pasteOrInputQrString() async {
    if (_closing || _inputOpen) return;
    _inputOpen = true;
    await _syncCamera();
    if (!mounted || _closing) return;
    final textController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Nhập chuỗi QR CCCD',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nếu webcam máy tính khó bắt nét mã QR nhỏ, bạn có thể dán chuỗi quét được từ Zalo hoặc Google Lens vào đây:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  hintText:
                      '001201012345||Họ và tên|ddmmyyyy|Nam|Địa chỉ|ddmmyyyy',
                  hintStyle: TextStyle(fontSize: 11),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, textController.text.trim()),
              child: const Text(
                'Xác nhận',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    textController.dispose();
    _inputOpen = false;
    if (!mounted || _closing) return;
    if (result != null && result.isNotEmpty) {
      final model = CccdQrModel.parse(result);
      if (model != null) {
        await _safeClose(model);
        return;
      } else {
        setState(() {
          _errorMessage =
              'Chuỗi không đúng định dạng CCCD gắn chip (phải chứa các trường phân tách bởi dấu |).';
        });
      }
    }
    if (!_closing) unawaited(_syncCamera());
  }

  void _toggleTorch() async {
    await _queueCamera(() async {
      if (!_wantCamera || !_controller.value.isRunning) return;
      await _controller.toggleTorch();
      if (mounted && !_closing) {
        setState(() {
          _isTorchOn = !_isTorchOn;
        });
      }
    });
  }

  void _switchCamera() async {
    await _queueCamera(() async {
      if (!_wantCamera || !_controller.value.isRunning) return;
      await _controller.switchCamera();
      if (!_wantCamera) await _controller.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    const scanAreaSize = 260.0;

    return PopScope<CccdQrModel>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_safeClose(result));
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Camera Viewfinder
            MobileScanner(
              controller: _controller,
              useAppLifecycleState: false,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.videocam_off_outlined,
                          size: 54,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không thể truy cập camera.\n${error.errorDetails?.message ?? error.toString()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _useSampleQrData,
                          icon: const Icon(Icons.flash_on_rounded),
                          label: const Text('Dùng dữ liệu CCCD mẫu (Demo)'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // 2. Viewfinder Overlay
            CustomPaint(
              painter: _ScannerOverlayPainter(scanAreaSize: scanAreaSize),
            ),

            // 3. Animated Laser Scan Line
            Center(
              child: SizedBox(
                width: scanAreaSize - 20,
                height: scanAreaSize - 20,
                child: AnimatedBuilder(
                  animation: _scanLineAnimation,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        Positioned(
                          top: _scanLineAnimation.value * (scanAreaSize - 24),
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.primaryLight,
                                  Colors.white,
                                  AppColors.primaryLight,
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // 4. Top App Bar Controls
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        tooltip: 'Đóng',
                        onPressed: () => _safeClose(),
                      ),
                      const Text(
                        'Quét mã QR CCCD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isTorchOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color: _isTorchOn ? Colors.amber : Colors.white,
                              size: 24,
                            ),
                            tooltip: 'Bật/tắt đèn flash',
                            onPressed: _toggleTorch,
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.cameraswitch_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            tooltip: 'Đổi camera',
                            onPressed: _switchCamera,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Bottom Instructions & Demo Action
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              'Căn chỉnh mã QR ở góc trên bên phải thẻ CCCD vào khung ngắm.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Hệ thống sẽ tự động giải mã thông tin chỉ sau 0.5 giây.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Các nút hỗ trợ kiểm thử / demo hoặc khi camera laptop khó lấy nét mã nhỏ
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: _useSampleQrData,
                            icon: const Icon(Icons.flash_on_rounded, size: 16),
                            label: const Text(
                              'CCCD mẫu (Demo)',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: _pasteOrInputQrString,
                            icon: const Icon(Icons.paste_rounded, size: 16),
                            label: const Text(
                              'Dán chuỗi / Nhập mã',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vẽ khung ngắm với 4 góc bo tròn nổi bật
class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter({required this.scanAreaSize});

  final double scanAreaSize;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55);
    final borderPaint = Paint()
      ..color = AppColors.primaryLight
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;
    final rect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    // 1. Tô mờ vùng xung quanh
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    // 2. Vẽ 4 góc khung ngắm (Corner brackets)
    const cornerLength = 28.0;
    const radius = 16.0;

    // Góc trên trái
    final topLeft = Path()
      ..moveTo(left, top + cornerLength)
      ..lineTo(left, top + radius)
      ..arcToPoint(
        Offset(left + radius, top),
        radius: const Radius.circular(radius),
      )
      ..lineTo(left + cornerLength, top);
    canvas.drawPath(topLeft, borderPaint);

    // Góc trên phải
    final topRight = Path()
      ..moveTo(left + scanAreaSize - cornerLength, top)
      ..lineTo(left + scanAreaSize - radius, top)
      ..arcToPoint(
        Offset(left + scanAreaSize, top + radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(left + scanAreaSize, top + cornerLength);
    canvas.drawPath(topRight, borderPaint);

    // Góc dưới trái
    final bottomLeft = Path()
      ..moveTo(left, top + scanAreaSize - cornerLength)
      ..lineTo(left, top + scanAreaSize - radius)
      ..arcToPoint(
        Offset(left + radius, top + scanAreaSize),
        radius: const Radius.circular(radius),
      )
      ..lineTo(left + cornerLength, top + scanAreaSize);
    canvas.drawPath(bottomLeft, borderPaint);

    // Góc dưới phải
    final bottomRight = Path()
      ..moveTo(left + scanAreaSize - cornerLength, top + scanAreaSize)
      ..lineTo(left + scanAreaSize - radius, top + scanAreaSize)
      ..arcToPoint(
        Offset(left + scanAreaSize, top + scanAreaSize - radius),
        radius: const Radius.circular(radius),
      )
      ..lineTo(left + scanAreaSize, top + scanAreaSize - cornerLength);
    canvas.drawPath(bottomRight, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
