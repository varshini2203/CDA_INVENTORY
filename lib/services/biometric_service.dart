import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Same key Profile already uses for the toggle (`_kBiometric` in
/// profile_screen.dart) — kept identical on purpose so both read/write the
/// exact same SharedPreferences entry with no syncing needed.
const kBiometricEnabledKey = 'profile_biometric';

enum BiometricResult { success, failed, unsupported, notEnrolled, lockedOut }

/// Thin wrapper around `local_auth` — every method fails soft (returns a
/// result enum, never throws) so callers can just branch on the outcome.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kBiometricEnabledKey) ?? false;
  }

  /// True only if the device has the hardware AND something is actually
  /// enrolled (a fingerprint or face) — not just theoretically capable.
  Future<bool> isDeviceSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck && supported;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Shows the native fingerprint/Face ID/PIN sheet and waits for the
  /// result. Use this both when the user turns the toggle ON (to prove the
  /// device can actually do it) and on the app lock screen.
  Future<BiometricResult> authenticate({
    String reason = 'Confirm your identity to continue',
  }) async {
    if (!await isDeviceSupported()) return BiometricResult.unsupported;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // allow device PIN/pattern as a fallback
        persistAcrossBackgrounding: true, // survives brief app backgrounding mid-prompt
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          return BiometricResult.lockedOut;
        case LocalAuthExceptionCode.noBiometricHardware:
          return BiometricResult.unsupported;
        default:
        // TODO: local_auth 3.0.1's "not enrolled" enum member name
        // couldn't be confirmed from docs alone. Put your cursor after
        // "LocalAuthExceptionCode." below, press Ctrl+Space (Cmd+Space
        // on Mac) to see the full member list, then add a case here:
        //   case LocalAuthExceptionCode.<realName>:
        //     return BiometricResult.notEnrolled;
          return BiometricResult.failed;
      }
    } catch (_) {
      return BiometricResult.failed;
    }
  }
}