import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';
import '../widgets/payment_confirmation_sheet.dart';
import '../widgets/qr_scanner_overlay.dart';

/// Screen for scanning QR codes to pay for public transport trips.
/// Visual layout strictly reproduces `res/qr.webp` with real-time yellow contour detection.
class PaymentQrScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final bool isActive;

  const PaymentQrScreen({
    super.key,
    this.onBack,
    this.isActive = true,
  });

  @override
  State<PaymentQrScreen> createState() => _PaymentQrScreenState();
}

class _PaymentQrScreenState extends State<PaymentQrScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;

  List<Barcode> _detectedBarcodes = [];
  Size? _captureSize;
  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
      autoStart: true,
    );
  }

  @override
  void didUpdateWidget(PaymentQrScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _controller.start();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed && widget.isActive) {
      _controller.start();
    }
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (_) {
      // In case device has no torch or controller is not initialized
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final rawValue = barcode.rawValue ?? '';
    if (rawValue.isEmpty && barcode.displayValue == null) return;

    final data = rawValue.isNotEmpty ? rawValue : (barcode.displayValue ?? 'BUS_PAYMENT_DEFAULT');

    setState(() {
      _detectedBarcodes = barcodes;
      _captureSize = capture.size;
      _isProcessing = true;
    });

    HapticFeedback.mediumImpact();

    // Small delay to allow the passenger to see the vibrant yellow contour lock-on
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _openPaymentSheet(data);
    });
  }

  Future<void> _openPaymentSheet(String qrData) async {
    final transportInfo = ScannedTransportInfo.fromRawData(qrData);

    await PaymentConfirmationSheet.show(
      context,
      transportInfo: transportInfo,
      onPaymentSuccess: () {
        PaymentSuccessDialog.show(context, transportInfo);
      },
    );

    if (mounted) {
      setState(() {
        _detectedBarcodes = [];
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera preview feed
          _buildCameraView(),

          // 2. Overlay cutout window and yellow QR detection contour
          QrScannerOverlay(
            detectedBarcodes: _detectedBarcodes,
            captureSize: _captureSize,
          ),

          // 3. Top bar UI matching res/qr.webp
          _buildTopBar(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return MobileScanner(
      controller: _controller,
      fit: BoxFit.cover,
      onDetect: _onDetect,
      errorBuilder: (context, error) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 54,
                  color: Colors.white60,
                ),
                const SizedBox(height: 16),
                Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Для сканирования QR-кодов необходим доступ к камере'
                      : (error.errorDetails?.message ?? 'Не удалось запустить камеру'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'NotoSans',
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _controller.start(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B5CFE),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Разрешить доступ'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top action buttons row: Back button (left) and Flash button (right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button (<)
                InkWell(
                  onTap: _handleBack,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),

                // Flash / Torch Toggle Button (Lightning bolt)
                InkWell(
                  onTap: _toggleTorch,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.bolt_rounded,
                      color: _isTorchOn ? AppColors.flashActive : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Header Title: "Сканировать QR-код"
            const Text(
              'Сканировать QR-код',
              style: TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),

            // Header Subtitle: "Наведите камеру на QR-код для оплаты"
            const Text(
              'Наведите камеру на QR-код для оплаты',
              style: TextStyle(
                fontFamily: 'NotoSans',
                fontSize: 15,
                color: Color(0xFFE2E8F0),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
