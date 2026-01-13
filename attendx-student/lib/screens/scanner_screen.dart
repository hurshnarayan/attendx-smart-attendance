import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/biometric_service.dart';
import '../utils/constants.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with TickerProviderStateMixin {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  bool _showPinEntry = false;
  String? _scannedToken;
  final _pinController = TextEditingController();
  final _classIdController = TextEditingController(text: 'CS101');
  late AnimationController _scanLineController;
  final BiometricService _biometricService = BiometricService();
  
  // Auth state
  AuthResult? _authResult;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pinController.dispose();
    _classIdController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _showPinEntry) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    HapticFeedback.mediumImpact();
    
    setState(() {
      _isProcessing = true;
      _scannedToken = code;
      _showPinEntry = true;
    });
    
    _controller?.stop();
  }

  /// Main submission flow:
  /// 1. Validate PIN entered
  /// 2. Trigger biometric authentication
  /// 3. Detect if biometric or fallback was used
  /// 4. Submit with auth method (biometric = Present, fallback = Flagged)
  Future<void> _submitAttendance() async {
    // Step 1: Validate PIN
    if (_pinController.text.isEmpty || _pinController.text.length != 4) {
      _showError('Please enter the 4-digit PIN');
      return;
    }

    setState(() => _isAuthenticating = true);
    HapticFeedback.mediumImpact();

    // Step 2: Trigger biometric authentication with fallback detection
    final biometricName = await _biometricService.getBiometricTypeName();
    
    // First try biometric only
    AuthResult authResult = await _biometricService.authenticateWithBiometricOnly(
      reason: 'Verify with $biometricName to mark attendance',
    );

    // If biometric failed or unavailable, offer fallback
    if (!authResult.success) {
      // Show dialog explaining fallback will be flagged
      final useFallback = await _showFallbackDialog();
      
      if (useFallback) {
        authResult = await _biometricService.authenticateWithFallback(
          reason: 'Use device PIN/pattern (will be flagged for teacher review)',
        );
      } else {
        setState(() => _isAuthenticating = false);
        return; // User cancelled
      }
    }

    setState(() {
      _authResult = authResult;
      _isAuthenticating = false;
    });

    // Step 3: Check authentication result
    if (!authResult.success) {
      _showError(authResult.error ?? 'Authentication failed. Please try again.');
      return;
    }

    HapticFeedback.heavyImpact();

    // Step 4: Submit attendance with auth method
    setState(() => _isProcessing = true);
    
    final provider = context.read<AppProvider>();
    
    // Determine auth method string
    final authMethod = authResult.usedBiometric ? 'biometric' : 'fallback';
    
    final result = await provider.markAttendance(
      token: _scannedToken!,
      pin: _pinController.text.trim(),
      authMethod: authMethod, // This determines Present vs Flagged
      classId: _classIdController.text.trim().isNotEmpty 
          ? _classIdController.text.trim() 
          : 'DEFAULT',
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return ResultScreen(
              result: result,
              usedFallback: authResult.usedFallback,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  /// Show dialog when biometric fails, explaining fallback will be flagged
  Future<bool> _showFallbackDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_rounded, color: AppColors.warning, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Biometric Failed'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fingerprint/Face ID verification failed.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'You can use your device PIN/pattern instead, but your attendance will be FLAGGED for teacher review.',
              style: TextStyle(color: AppColors.gray600),
            ),
            SizedBox(height: 8),
            Text(
              '• Biometric = Marked Present instantly\n• PIN/Pattern = Flagged for approval',
              style: TextStyle(fontSize: 13, color: AppColors.gray500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: const Text('Use PIN/Pattern'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showError(String message) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _isProcessing = false;
      _showPinEntry = false;
      _scannedToken = null;
      _authResult = null;
      _isAuthenticating = false;
      _pinController.clear();
    });
    _controller?.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          if (!_showPinEntry) ...[
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
            _buildScanOverlay(),
          ],
          
          // Header
          _buildHeader(),
          
          // PIN Entry
          if (_showPinEntry) _buildPinEntry(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _showPinEntry ? AppColors.gray100 : Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: _showPinEntry ? AppColors.gray700 : Colors.white,
                  size: 24,
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            Text(
              _showPinEntry ? 'Verify Identity' : 'Scan QR Code',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _showPinEntry ? AppColors.gray900 : Colors.white,
              ),
            ),
            
            const Spacer(),
            
            if (!_showPinEntry)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _controller?.toggleTorch();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildScanOverlay() {
    return Stack(
      children: [
        // Darkened corners
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.6),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Frame corners
        Center(
          child: SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              children: [
                _buildCorner(Alignment.topLeft),
                _buildCorner(Alignment.topRight),
                _buildCorner(Alignment.bottomLeft),
                _buildCorner(Alignment.bottomRight),
                
                // Scan line
                AnimatedBuilder(
                  animation: _scanLineController,
                  builder: (context, child) {
                    return Positioned(
                      top: 20 + (_scanLineController.value * 240),
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.primary.withOpacity(0.8),
                              AppColors.primary,
                              AppColors.primary.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        
        // Hint text
        Positioned(
          bottom: 120,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Point camera at QR code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ).animate(delay: 500.ms).fadeIn(duration: 300.ms),
      ],
    );
  }

  Widget _buildCorner(Alignment alignment) {
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    
    return Positioned(
      top: isTop ? 0 : null,
      bottom: !isTop ? 0 : null,
      left: isLeft ? 0 : null,
      right: !isLeft ? 0 : null,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            bottom: !isTop ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            left: isLeft ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            right: !isLeft ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: alignment == Alignment.topLeft ? const Radius.circular(16) : Radius.zero,
            topRight: alignment == Alignment.topRight ? const Radius.circular(16) : Radius.zero,
            bottomLeft: alignment == Alignment.bottomLeft ? const Radius.circular(16) : Radius.zero,
            bottomRight: alignment == Alignment.bottomRight ? const Radius.circular(16) : Radius.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildPinEntry() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 60),
            
            // Success icon
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_rounded,
                size: 48,
                color: AppColors.success,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            
            const SizedBox(height: 24),
            
            const Text(
              'QR Code Scanned!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.gray900,
              ),
            ).animate(delay: 200.ms).fadeIn(),
            
            const SizedBox(height: 8),
            
            const Text(
              'Enter PIN, then verify with biometrics',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.gray500,
              ),
            ).animate(delay: 300.ms).fadeIn(),
            
            const SizedBox(height: 32),
            
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PIN Input
                    const Text(
                      'Enter PIN from teacher\'s screen',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 16,
                        color: AppColors.gray900,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '• • • •',
                        hintStyle: const TextStyle(
                          fontSize: 32,
                          color: AppColors.gray300,
                          letterSpacing: 16,
                        ),
                        filled: true,
                        fillColor: AppColors.gray50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Class ID
                    const Text(
                      'Class ID (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _classIdController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray900,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g., CS101',
                        filled: true,
                        fillColor: AppColors.gray50,
                        prefixIcon: const Icon(Icons.class_rounded, color: AppColors.gray400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.gray200, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Auth info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.fingerprint_rounded,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Biometric Required',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Fingerprint or Face ID will be requested',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, size: 18, color: AppColors.gray500),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Using device PIN/pattern will flag your attendance for teacher review',
                                    style: TextStyle(fontSize: 12, color: AppColors.gray600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 400.ms).fadeIn(),
                  ],
                ),
              ),
            ),
            
            // Submit Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isAuthenticating ? null : _resetScanner,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.gray200, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Rescan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray700,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    flex: 2,
                    child: Consumer<AppProvider>(
                      builder: (context, provider, _) {
                        final isLoading = provider.isLoading || _isAuthenticating;
                        return ElevatedButton.icon(
                          onPressed: isLoading ? null : _submitAttendance,
                          icon: _isAuthenticating 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.fingerprint_rounded, size: 22),
                          label: Text(
                            _isAuthenticating 
                                ? 'Verifying...' 
                                : 'Verify & Mark',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                            disabledForegroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ).animate(delay: 500.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}
