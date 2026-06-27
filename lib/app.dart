import 'package:flutter/material.dart';
import 'core/attribution_hub.dart';
import 'core/net_sensor.dart';
import 'core/push_center.dart';
import 'core/verdict_gateway.dart';
import 'core/vault.dart';
import 'flow/boot_gate.dart';
import 'services/storage_service.dart';

class WingSprintApp extends StatelessWidget {
  final Vault vault;
  final NetSensor net;
  final AttributionHub attribution;
  final VerdictGateway gateway;
  final PushCenter push;
  final StorageService gameStorage;

  const WingSprintApp({
    super.key,
    required this.vault,
    required this.net,
    required this.attribution,
    required this.gateway,
    required this.push,
    required this.gameStorage,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wing Sprint',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3C6CFF),
          brightness: Brightness.light,
        ),
      ),
      home: BootGate(
        vault: vault,
        net: net,
        attribution: attribution,
        gateway: gateway,
        push: push,
        gameStorage: gameStorage,
      ),
    );
  }
}
