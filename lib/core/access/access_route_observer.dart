// lib/core/access/access_route_observer.dart
//
// Drop this into MaterialApp(navigatorObservers: [AccessRouteObserver()])
// and every screen push in the ENTIRE app is logged automatically for the
// admin's live activity feed — no need to touch each of the 100+ screens.
//
// THROTTLED: screen-visit logging was firing one Firestore write per
// navigation event (push/pop/replace), which multiplies fast during normal
// use and burns through the Firestore free-tier daily write quota. This
// version:
//   1. Skips logging if the SAME screen was just logged within
//      [_throttleWindow] (default 5s) — collapses rapid back-and-forth
//      navigation (e.g. opening/closing a detail screen a few times) into
//      a single write.
//   2. Skips logging if the label is identical to the immediately previous
//      logged visit, regardless of timing — avoids duplicate consecutive
//      entries like the same screen being re-pushed by a rebuild.

import 'package:flutter/material.dart';
import '../../services/activity_log_service.dart';

class AccessRouteObserver extends NavigatorObserver {
  // Widened from 5s to 60s. 5s only collapsed rapid back-and-forth taps;
  // in normal use, everyday navigation across the app's 100+ screens still
  // produced a steady stream of writes all day, which was the primary
  // driver of the write-quota overage. A screen-visit log is only useful
  // at "which screens does this person use" granularity, not "every visit,
  // every few seconds" — 60s still captures that while cutting the write
  // volume by roughly 10x for typical usage.
  AccessRouteObserver({Duration throttleWindow = const Duration(seconds: 60)})
      : _throttleWindow = throttleWindow;

  final Duration _throttleWindow;

  String? _lastLabel;
  DateTime? _lastLoggedAt;

  String _labelFor(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    // Screens pushed as `MaterialPageRoute(builder: (_) => Screen())` with
    // no `settings: RouteSettings(name: ...)` don't expose their widget
    // type at this layer, so they fall back to a generic label. Add
    // `settings: const RouteSettings(name: 'Screen Name')` to any push
    // call to get a precise label in the admin activity feed.
    return 'Unnamed screen';
  }

  void _log(Route<dynamic>? route) {
    if (route == null) return;
    if (route.settings.name == '/') return; // splash, not useful
    // Dialogs, bottom sheets, menus, and other popups (DialogRoute,
    // ModalBottomSheetRoute, etc.) are NOT PageRoutes — they were being
    // logged as "Unnamed screen" on every open/close, drowning out real
    // page visits and CRUD actions in the feed. Only full-page
    // navigations should show up here; the actual operation performed
    // inside a dialog (add/edit/delete) is logged separately, with full
    // detail, via ActivityLogService.logAdd/logEdit/logDelete.
    if (route is! PageRoute) return;

    final label = _labelFor(route);
    final now = DateTime.now();

    // Skip if this is the same screen as the last logged visit and we're
    // still inside the throttle window. Covers rapid nav bouncing and
    // duplicate didPush/didReplace/didPop firings for the same route.
    if (label == _lastLabel &&
        _lastLoggedAt != null &&
        now.difference(_lastLoggedAt!) < _throttleWindow) {
      return;
    }

    _lastLabel = label;
    _lastLoggedAt = now;
    ActivityLogService.logScreenVisit(label);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log(previousRoute);
  }
}