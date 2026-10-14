import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Aggressively small image cache — low-end phones (Infinix, Tecno,
  // itel) run out of GPU buffers if we hold too many decoded bitmaps.
  PaintingBinding.instance.imageCache.maximumSize = 10;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 8 * 1024 * 1024;
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();

  runApp(const AlightCreatorsApp());
}