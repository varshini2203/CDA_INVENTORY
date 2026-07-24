import 'package:flutter/material.dart';
import 'package:cda_inventory/services/biometric_service.dart';

/// Wrap your authenticated app content with this — e.g. around whatever
/// widget your '/dashboard' route builds — to require a biometric/PIN
/// unlock on cold start and every time the app returns from the
/// background. Does nothing (renders `child` straight through) if the
/// user hasn't turned "Biometric Login" on in Profile.
class BiometricGate extends StatefulWidget {
  final Widget child;
  const BiometricGate({super.key, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _checking = true;
  bool _authenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_checking) {
      _checkLockOnStart();
    } else if (state == AppLifecycleState.paused) {
      // Re-arm the lock the instant the app is backgrounded, so switching
      // back in always demands a fresh unlock.
      BiometricService.instance.isEnabled.then((enabled) {
        if (enabled && mounted) setState(() => _locked = true);
      });
    }
  }

  Future<void> _checkLockOnStart() async {
    final enabled = await BiometricService.instance.isEnabled;
    if (!mounted) return;
    setState(() {
      _locked = enabled;
      _checking = false;
    });
    if (enabled) _unlock();
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    final result = await BiometricService.instance.authenticate(reason: 'Unlock CDA Inventory');
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      switch (result) {
        case BiometricResult.success:
          _locked = false;
          break;
        case BiometricResult.notEnrolled:
          _error = 'No fingerprint/face is enrolled on this device.';
          break;
        case BiometricResult.lockedOut:
          _error = 'Too many attempts. Try again later.';
          break;
        case BiometricResult.unsupported:
          _error = 'Biometric auth is not available on this device.';
          break;
        case BiometricResult.failed:
          _error = 'Authentication failed. Try again.';
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const _LockScaffold(child: CircularProgressIndicator(color: Color(0xFF3A7AE8)));
    }
    if (!_locked) return widget.child;

    return _LockScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E5FC8).withOpacity(0.14),
              border: Border.all(color: const Color(0xFF1E5FC8).withOpacity(0.4), width: 1.5),
            ),
            child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF3A7AE8), size: 44),
          ),
          const SizedBox(height: 20),
          const Text('CDA Inventory Locked',
              style: TextStyle(color: Color(0xFFF0F6FF), fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Verify your identity to continue',
              style: TextStyle(color: Color(0xFFA0B8D0), fontSize: 12.5)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Color(0xFFE8374A), fontSize: 11.5), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          _authenticating
              ? const CircularProgressIndicator(color: Color(0xFF3A7AE8))
              : ElevatedButton.icon(
            onPressed: _unlock,
            icon: const Icon(Icons.lock_open_rounded, size: 16),
            label: const Text('Unlock'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E5FC8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockScaffold extends StatelessWidget {
  final Widget child;
  const _LockScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A14),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: child)),
    );
  }
}