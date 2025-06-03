import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:libretv_app/services/api.dart';
import 'package:libretv_app/widgets/app_wrapper.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化Hive
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox('sources');
  await Hive.openBox('proxies');

  // 加载并存储初始配置
  await _loadInitialConfig();


  // 启动Web服务
  final server = await startServer();

  runApp(MyApp(server: server));  // 传递server参数
}

class MyApp extends StatelessWidget {

  final HttpServer server;  // 新增server属性

  const MyApp({super.key, required this.server});  // 更新构造函数

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '苹果CMS电影播放器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(const TextTheme(
          displayLarge: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          displayMedium: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          displaySmall: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          headlineMedium: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          headlineSmall: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          titleLarge: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        )).apply(
          displayColor: Colors.white,
          bodyColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 4,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
      ),
      home: const AppWrapper(),
    );
  }
}

Future<void> _loadInitialConfig() async {
  final sourcesBox = Hive.box('sources');
  final proxiesBox = Hive.box('proxies');

  // 检查是否已有配置
  if (sourcesBox.isEmpty || proxiesBox.isEmpty) {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://ktv.aini.us.kg/config.json',
        options: Options(responseType: ResponseType.json),
      );

      if (response.statusCode == 200) {
        final config = response.data;

        // 存储源数据
        for (final source in config['sources']) {
          final id = DateTime.now().millisecondsSinceEpoch.toString();
          sourcesBox.put(id, {
            ...source,
            'id': id,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }

        // 存储代理数据
        final pid = DateTime.now().millisecondsSinceEpoch.toString();
        proxiesBox.put(pid,{"id":pid,"url":config['proxy']['url'],"name": config['proxy']['name'],"enabled":config['proxy']['enabled'],"createdAt":DateTime.now().toIso8601String(),"updatedAt":DateTime.now().toIso8601String()});
      }
    } catch (e) {
      print('加载初始配置失败: $e');
    }
  }
}