// ============================================================
// GATEWAY VERDICT — parsed response from the config endpoint
// ============================================================
// Wire shape:
//   portal : { "ok": true,  "url": "https://...", "expires": 1699999999 }
//   game   : { "ok": false, "message": "organic" }
// ============================================================

class GatewayVerdict {
  final bool allowed;
  final String? portalUrl;
  final String? note;
  final int? expiresAt; // Unix seconds

  const GatewayVerdict({
    required this.allowed,
    this.portalUrl,
    this.note,
    this.expiresAt,
  });

  bool get hasPortal => allowed && portalUrl != null && portalUrl!.isNotEmpty;

  factory GatewayVerdict.fromMap(Map<String, dynamic> map) {
    return GatewayVerdict(
      allowed: map['ok'] == true,
      portalUrl: (map['url'] as String?)?.trim(),
      note: map['message'] as String?,
      expiresAt: map['expires'] is int
          ? map['expires'] as int
          : int.tryParse('${map['expires'] ?? ''}'),
    );
  }

  factory GatewayVerdict.failure(String reason) =>
      GatewayVerdict(allowed: false, note: reason);
}
