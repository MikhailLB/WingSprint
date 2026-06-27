import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow all orientations so the loading screen can show in both
  // portrait and landscape. The game screen locks itself to portrait.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  final storage = StorageService();
  await storage.init();

  runApp(WingSprintApp(storage: storage));
}
