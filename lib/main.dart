import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:libretv_app/services/api.dart';
import 'package:libretv_app/widgets/app_wrapper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化Hive
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);

  await Hive.openBox('sources');
  await Hive.openBox('proxies');
  await Hive.openBox('tags');

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
  final uuid = Uuid();

  final sourcesBox = Hive.box('sources');
  final proxiesBox = Hive.box('proxies');
  final tagsBox = Hive.box('tags');

  // 检查 sources 是否需要初始化
  if (sourcesBox.isEmpty) {
    await _initializeSources(sourcesBox, uuid);
  } else {
    print('sources 已有数据，跳过初始化');
  }

  // 检查 proxies 是否需要初始化
  if (proxiesBox.isEmpty) {
    await _initializeProxies(proxiesBox, uuid);
  } else {
    print('proxies 已有数据，跳过初始化');
  }

  // 检查 tags 是否需要初始化（新增逻辑，不影响已有数据）
  if (tagsBox.isEmpty) {
    await _initializeTags(tagsBox, uuid);
  } else {
    print('tags 已有数据，跳过初始化');
  }
}

/// 初始化 sources
Future<void> _initializeSources(Box sourcesBox, Uuid uuid) async {
  try {
    final dio = Dio();
    print('开始加载 sources 配置...');
    final response = await dio.get(
      'https://ktv.aini.us.kg/config.json',
      options: Options(responseType: ResponseType.json),
    );

    if (response.statusCode == 200) {
      final config = response.data;
      print('成功获取 sources 配置，共${config['sources']?.length ?? 0}个源');

      int savedCount = 0;
      for (final source in config['sources']) {
        try {
          final id = uuid.v4();
          sourcesBox.put(id, {
            ...source,
            'id': id,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
          savedCount++;
          print('成功保存源: ${source['name']}');
        } catch (e) {
          print('保存源${source['name']}失败: $e');
        }
      }
      print('实际保存源数量: $savedCount');
    } else {
      print('获取 sources 配置失败，状态码: ${response.statusCode}');
    }
  } catch (e) {
    print('加载 sources 初始配置失败: $e');
  }
}

/// 初始化 proxies
Future<void> _initializeProxies(Box proxiesBox, Uuid uuid) async {
  try {
    final dio = Dio();
    print('开始加载 proxies 配置...');
    final response = await dio.get(
      'https://ktv.aini.us.kg/config.json',
      options: Options(responseType: ResponseType.json),
    );

    if (response.statusCode == 200) {
      final config = response.data;
      print('成功获取 proxies 配置');

      final pid = uuid.v4();
      proxiesBox.put(pid, {
        "id": pid,
        "url": config['proxy']['url'],
        "name": config['proxy']['name'],
        "enabled": config['proxy']['enabled'],
        "createdAt": DateTime.now().toIso8601String(),
        "updatedAt": DateTime.now().toIso8601String()
      });
      print('成功保存代理配置');
    } else {
      print('获取 proxies 配置失败，状态码: ${response.statusCode}');
    }
  } catch (e) {
    print('加载 proxies 初始配置失败: $e');
  }
}

/// 初始化 tags（新增逻辑）
Future<void> _initializeTags(Box tagsBox, Uuid uuid) async {
  try {
    final dio = Dio();
    print('开始加载 tags 配置...');
    final response = await dio.get(
      'https://ktv.aini.us.kg/config.json',
      options: Options(responseType: ResponseType.json),
    );

    if (response.statusCode == 200) {
      final config = response.data;
      print('成功获取 tags 配置，共${config['tags']?.length ?? 0}个标签');

      int tagCount = 0;
      for (final tag in config['tags']) {
        final tid = uuid.v4();
        tagsBox.put(tid, {
          ...tag,
          'id': tid,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
        tagCount++;
        print('成功保存标签: ${tag['name']}');
      }
      print('实际保存标签数量: $tagCount');
    } else {
      print('获取 tags 配置失败，状态码: ${response.statusCode}');
    }
  } catch (e) {
    print('加载 tags 初始配置失败: $e');
  }
}