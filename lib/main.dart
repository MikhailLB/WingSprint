import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'core/agent_client.dart';
import 'core/attribution_hub.dart';
import 'core/net_sensor.dart';
import 'core/push_center.dart';
import 'core/verdict_gateway.dart';
import 'core/vault.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + App Check are optional at boot: configuration is added
  // later, so failures here are swallowed and the app proceeds.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
  } catch (_) {}

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await agentClient.warmUp();

  final vault = Vault();
  await vault.open();

  final gameStorage = StorageService();
  await gameStorage.init();

  final net = NetSensor();
  final attribution = AttributionHub();
  final gateway = VerdictGateway(vault);
  final push = PushCenter(vault);

  runApp(WingSprintApp(
    vault: vault,
    net: net,
    attribution: attribution,
    gateway: gateway,
    push: push,
    gameStorage: gameStorage,
  ));
}
