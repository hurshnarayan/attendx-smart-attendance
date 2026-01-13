import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Authentication result with method detection
enum AuthMethod {
  biometric,  // Fingerprint or Face ID used
  fallback,   // Device PIN/pattern used
  failed,     // Authentication failed
  unavailable // No auth available on device
}

class AuthResult {
  final bool success;
  final AuthMethod method;
  final String? error;

  AuthResult({
    required this.success,
    required this.method,
    this.error,
  });

  bool get usedBiometric => method == AuthMethod.biometric;
  bool get usedFallback => method == AuthMethod.fallback;
  bool get shouldFlag => usedFallback; // Flag if fallback was used
}

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if device supports biometrics
  Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics && canAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  /// Check if device has enrolled biometrics (fingerprint/face registered)
  Future<bool> hasBiometricsEnrolled() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Authenticate with BIOMETRIC ONLY (no fallback)
  /// Returns AuthResult with method detection
  Future<AuthResult> authenticateWithBiometricOnly({
    String reason = 'Verify your identity to mark attendance',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      final hasEnrolled = await hasBiometricsEnrolled();

      if (!isAvailable || !hasEnrolled) {
        // Device doesn't support biometrics or none enrolled
        // Must use fallback
        return AuthResult(
          success: false,
          method: AuthMethod.unavailable,
          error: 'Biometric not available',
        );
      }

      // Try biometric ONLY (no fallback allowed)
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true, // IMPORTANT: Only biometric, no PIN/pattern
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        return AuthResult(
          success: true,
          method: AuthMethod.biometric,
        );
      } else {
        return AuthResult(
          success: false,
          method: AuthMethod.failed,
          error: 'Biometric authentication failed',
        );
      }
    } on PlatformException catch (e) {
      // Biometric failed - user may have cancelled or too many attempts
      return AuthResult(
        success: false,
        method: AuthMethod.failed,
        error: e.message ?? 'Biometric error',
      );
    }
  }

  /// Authenticate with FALLBACK allowed (pattern/PIN)
  /// This should ONLY be called after biometric fails
  /// Result will be marked for FLAGGING
  Future<AuthResult> authenticateWithFallback({
    String reason = 'Use device PIN/pattern as fallback',
  }) async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();

      if (!isSupported) {
        return AuthResult(
          success: false,
          method: AuthMethod.unavailable,
          error: 'Device authentication not supported',
        );
      }

      // Allow fallback (PIN/pattern)
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        // Authenticated but with FALLBACK - should be flagged
        return AuthResult(
          success: true,
          method: AuthMethod.fallback, // Mark as fallback
        );
      } else {
        return AuthResult(
          success: false,
          method: AuthMethod.failed,
          error: 'Authentication failed',
        );
      }
    } on PlatformException catch (e) {
      return AuthResult(
        success: false,
        method: AuthMethod.failed,
        error: e.message ?? 'Authentication error',
      );
    }
  }

  /// Full authentication flow:
  /// 1. Try biometric first
  /// 2. If biometric fails/unavailable, offer fallback
  /// 3. Return result with method detection for flagging
  Future<AuthResult> authenticateWithFallbackDetection({
    String biometricReason = 'Verify with fingerprint or Face ID',
    String fallbackReason = 'Use device PIN/pattern (will be flagged for review)',
  }) async {
    // Step 1: Try biometric only
    final biometricResult = await authenticateWithBiometricOnly(
      reason: biometricReason,
    );

    if (biometricResult.success) {
      // Biometric succeeded - mark as PRESENT
      return biometricResult;
    }

    // Step 2: Biometric failed or unavailable - offer fallback
    // This will be FLAGGED
    final fallbackResult = await authenticateWithFallback(
      reason: fallbackReason,
    );

    return fallbackResult;
  }

  /// Get biometric type name for UI
  Future<String> getBiometricTypeName() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris';
    }
    return 'Biometric';
  }
}
