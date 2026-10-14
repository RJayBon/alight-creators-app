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

  // Bounded image cache — low-end phones (Infinix, Tecno, itel) run out of
  // GPU buffers if we hold too many decoded bitmaps.
  //
  // NOTE: this used to be `maximumSize = 10`. That is *below* the number of
  // thumbnails visible on the tutorials grid at once, so the cache thrashed:
  // every scroll evicted bitmaps that were still on screen and forced a
  // full re-decode on the next frame. The per-widget `cacheWidth` values
  // (200–800px)   are what actually keep memory in check; the count just has
  // to be big enough to hold a screenful plus the RefreshIndicator re-render.
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 * 1024 * 1024;

  runApp(const AlightCreatorsApp());
}