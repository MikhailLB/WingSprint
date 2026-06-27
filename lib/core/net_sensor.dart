import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

// ============================================================
// NET SENSOR — connectivity + reachability probe
// ============================================================
// Two-stage check: first the OS interface state, then a real DNS
// lookup so captive portals / dead Wi-Fi are caught.
//
// Pitfall guards baked in:
//   • VPN (and bluetooth/other) count as a live interface — otherwise
//     toggling a VPN flashes the offline screen on a healthy link.
//   • DNS lookup timeout is 7s, not 3s: a genuine "no route" throws a
//     SocketException instantly, so the longer ceiling is free and it
//     stops VPN tunnels from timing out into a false negative.
// ============================================================

const Set<ConnectivityResult> _liveInterfaces = {
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

const List<String> _probeHosts = ['cloudflare.com', 'google.com'];

class NetSensor {
  final Connectivity _connectivity = Connectivity();

  /// True when at least one interface is up AND a DNS lookup resolves.
  Future<bool> isReachable() async {
    final states = await _connectivity.checkConnectivity();
    if (!states.any(_liveInterfaces.contains)) return false;

    for (final host in _probeHosts) {
      try {
        final records = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 7));
        if (records.isNotEmpty && records.first.rawAddress.isNotEmpty) {
          return true;
        }
      } on SocketException {
        return false;
      } catch (_) {
        // try the next host before giving up
      }
    }
    return false;
  }

  /// Raw interface-change stream (used by the portal to react to drops).
  Stream<List<ConnectivityResult>> get changes =>
      _connectivity.onConnectivityChanged;

  /// Convenience: did the latest snapshot report a total blackout?
  static bool isBlackout(List<ConnectivityResult> states) =>
      states.every((s) => s == ConnectivityResult.none);
}
