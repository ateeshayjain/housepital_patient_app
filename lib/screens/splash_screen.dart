import 'dart:async';

import 'package:flutter/material.dart';
import 'package:housepital_patient/config/theme.dart';

/// Brand moment shown while the last of startup finishes.
///
/// WHAT THIS USED TO DO
/// `Future.delayed(const Duration(seconds: 2))`, unconditionally, then
/// `pushReplacementNamed('/home')`. Every awaited piece of startup had
/// ALREADY completed before `runApp`, so those two seconds were spent
/// displaying a logo over an app that was sitting ready — a fixed tax added
/// to the end of every cold start, on top of Firebase init, the store
/// migration and the reminder service. The audit's "< 2 s cold" budget was
/// blown by this screen alone.
///
/// WHAT IT DOES NOW
/// Races the remaining startup work against a short minimum beat and leaves
/// as soon as BOTH are done:
///
///  * the beat stops the logo strobing for 80 ms on a fast device, which
///    looks like a defect;
///  * the [warmup] future means the screen still covers real work rather than
///    pretending to;
///  * [_maxWait] means a hung warmup can never trap the user on a splash —
///    reminders failing to initialise must not cost someone access to their
///    care plan.
///
/// Reduced motion shortens the beat rather than removing the screen: the
/// navigation still needs somewhere to come from, and a zero-length splash
/// reads as a flash.
class SplashScreen extends StatefulWidget {
  /// Startup work that may still be running. Completing early is fine;
  /// failing is fine (the caller logs it); hanging is handled by [_maxWait].
  final Future<void>? warmup;

  const SplashScreen({super.key, this.warmup});

  /// Long enough not to strobe, short enough not to be noticed as a wait.
  static const Duration _minimumBeat = Duration(milliseconds: 450);

  /// Reduced-motion users get the shortest beat that still avoids a flash.
  static const Duration _reducedMotionBeat = Duration(milliseconds: 150);

  /// Hard ceiling. Past this the app opens regardless of warmup state.
  static const Duration _maxWait = Duration(seconds: 3);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is only available from here, not initState.
    if (_navigated) return;
    _navigated = true;
    unawaited(_openApp(MediaQuery.disableAnimationsOf(context)));
  }

  Future<void> _openApp(bool reducedMotion) async {
    final beat = reducedMotion
        ? SplashScreen._reducedMotionBeat
        : SplashScreen._minimumBeat;

    final ready = Future.wait<void>([
      Future<void>.delayed(beat),
      if (widget.warmup != null) widget.warmup!.catchError((_) {}),
    ]);

    // Whichever comes first. A warmup that never completes must not strand
    // anyone on a logo.
    await Future.any<void>([
      ready,
      Future<void>.delayed(SplashScreen._maxWait),
    ]);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HousepitalColors.orange,
      body: Center(
        // One node for assistive tech: a screen reader should announce the
        // app, not read a logo, a wordmark and a tagline as three items on a
        // screen that is about to disappear.
        child: Semantics(
          label: 'Housepital. Hospital-like expertise, home-like care. Loading.',
          excludeSemantics: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_hospital,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              const Text(
                'HOUSEPITAL',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hospital-like expertise. Home-like care.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
