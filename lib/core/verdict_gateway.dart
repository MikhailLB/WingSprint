import 'dart:convert';
import '../env/runtime_config.dart';
import '../state/gateway_verdict.dart';
import 'agent_client.dart';
import 'vault.dart';

// ============================================================
// VERDICT GATEWAY — talks to the config endpoint
// ============================================================
// POSTs the attribution payload and parses the routing verdict.
// On a portal verdict the URL + expiry are cached so a returning
// launch (or a failed re-check) can still reach content.
//
// Re-check policy: the caller queries this on EVERY launch. The
// backend may rotate the landing URL, so a fresh ok+url always wins
// over the cached value. The cache is only a fallback for failures.
// ============================================================

class VerdictGateway {
  final Vault _vault;

  VerdictGateway(this._vault);

  Future<GatewayVerdict> resolve(Map<String, dynamic> payload) async {
    final endpoint = RuntimeConfig.gatewayUrl;
    if (endpoint.isEmpty) {
      return GatewayVerdict.failure('no-endpoint');
    }

    try {
      final res = await agentClient
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(RuntimeConfig.gatewayTimeout);

      if (res.statusCode != 200) {
        return GatewayVerdict.failure('http-${res.statusCode}');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        return GatewayVerdict.failure('bad-shape');
      }
      final verdict =
          GatewayVerdict.fromMap(decoded.map((k, v) => MapEntry('$k', v)));

      if (verdict.hasPortal) {
        await _vault.writePortalUrl(verdict.portalUrl!);
        if (verdict.expiresAt != null) {
          await _vault.writeExpiry(verdict.expiresAt!);
        }
      }
      return verdict;
    } catch (e) {
      return GatewayVerdict.failure(e.toString());
    }
  }

  /// Last known-good portal URL (may be expired — still better than blank).
  Future<String?> cachedPortalUrl() => _vault.readPortalUrl();
}
