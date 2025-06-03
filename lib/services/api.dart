import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;  // Add prefix for shelf_router
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化Hive
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox('sources');
  await Hive.openBox('proxies'); // 新增代理存储

  // 启动Web服务
  final server = await startServer();

  runApp(MyApp(server: server));
}


Future<Directory> _copyAssetsToDocuments() async {
  // 获取应用文档目录
  final appDir = await getApplicationDocumentsDirectory();
  final webDir = Directory('${appDir.path}/web');

  // 如果目录不存在则创建
  if (!await webDir.exists()) {
    await webDir.create(recursive: true);
  }

  // 要复制的文件列表
  final assets = [
    'assets/web/index.html'
  ];

  // 复制每个文件
  for (final asset in assets) {
    try {
      final content = await rootBundle.loadString(asset);
      final filename = asset.split('/').last;
      await File('${webDir.path}/$filename').writeAsString(content);
    } catch (e) {
      print('Error copying $asset: $e');
    }
  }

  return webDir;
}

Future<HttpServer> startServer({int port = 8023}) async {

  final webDir = await _copyAssetsToDocuments();

  // 2. 创建静态文件处理器
  final staticHandler = createStaticHandler(
    webDir.path,  // 使用复制后的路径
    defaultDocument: 'index.html',
  );

  final router = shelf_router.Router()
    ..options('/api/<any|.*>', (Request request) => Response.ok(''))
    ..get('/api/sources', _handleGetSources)
    ..post('/api/sources', _handleAddSource)
    ..put('/api/sources/toggle', _handleToggleSource)
    ..delete('/api/sources', _handleDeleteSource)
    ..get('/api/search', _handleSearchRequest)
    ..get('/', staticHandler)
    ..get('/api/proxies', _handleGetProxies)
    ..post('/api/proxies', _handleAddProxy)
    ..put('/api/proxies/toggle', _handleToggleProxy) // 添加切换状态路由
    ..delete('/api/proxies', _handleDeleteProxy)
    ..get('/<any|.*>', staticHandler);


  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router.call);

  return await shelf_io.serve(handler, '0.0.0.0', port);
}

class MyApp extends StatelessWidget {
  final HttpServer server;

  const MyApp({Key? key, required this.server}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '苹果CMS聚合搜索API',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('苹果CMS聚合搜索API')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('服务运行在: http://localhost:${server.port}'),
              const SizedBox(height: 20),
              const Text('API端点:'),
              const Text('/api/sources - 获取源列表'),
              const Text('/api/search?wd=关键词 - 搜索内容'),
            ],
          ),
        ),
      ),
    );
  }
}

// 存储操作类
class SourceStorage {
  static const String _boxName = 'sources';
  static const String _proxyBoxName = 'proxies';

  static Future<List<Source>> getAllSources() async {
    final box = Hive.box(_boxName);
    final sources = box.values.map((e) => Source.fromJson(Map<String, dynamic>.from(e))).toList();
    sources.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sources;
  }

  static Future<Source> addSource(Source source) async {
    final box = Hive.box(_boxName);
    await box.put(source.id, source.toJson());
    return source;
  }

  static Future<Source> toggleSource(String id) async {
    final box = Hive.box(_boxName);
    final sourceJson = box.get(id);
    if (sourceJson == null) throw Exception('Source not found');

    final source = Source.fromJson(Map<String, dynamic>.from(sourceJson));
    source.disabled = !source.disabled;
    source.updatedAt = DateTime.now();
    await box.put(id, source.toJson());
    return source;
  }

  static Future<void> deleteSource(String id) async {
    final box = Hive.box(_boxName);
    await box.delete(id);
  }

  // 代理相关方法

  // 添加代理
  static Future<Proxy> addProxy(Proxy proxy) async {
    final box = Hive.box(_proxyBoxName);
    await box.put(proxy.id, proxy.toJson());
    return proxy;
  }

  static Future<List<Proxy>> getAllProxies() async {
    final box = Hive.box(_proxyBoxName);
    return box.values.map((e) => Proxy.fromJson(Map<String, dynamic>.from(e))).toList();
  }


  static Future<void> deleteProxy(String id) async {
    final box = Hive.box(_proxyBoxName);
    await box.delete(id);
  }

  static Future<Proxy> toggleProxy(String id) async {
    final box = await Hive.openBox(_proxyBoxName);
    final proxyJson = box.get(id);
    if (proxyJson == null) throw Exception('Proxy not found');

    final proxy = Proxy.fromJson(Map<String, dynamic>.from(proxyJson));
    proxy.enabled = !proxy.enabled;
    proxy.updatedAt = DateTime.now();
    await box.put(id, proxy.toJson());
    return proxy;
  }

}

// 源数据模型
class Source {
  final String id;
  final String name;
  final String url;
  final int weight;
  bool disabled;
  DateTime createdAt;
  DateTime updatedAt;

  Source({
    required this.id,
    required this.name,
    required this.url,
    this.weight = 5,
    this.disabled = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) :
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      weight: json['weight'],
      disabled: json['disabled'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'weight': weight,
      'disabled': disabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

// API处理函数
Future<Response> _handleGetSources(Request request) async {
  try {
    final sources = await SourceStorage.getAllSources();
    return _createJsonResponse(sources);
  } catch (e) {
    return _createErrorResponse('获取源列表失败', 500, e);
  }
}

Future<Response> _handleAddSource(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    if (data['name'] == null || data['url'] == null) {
      throw Exception('名称和URL不能为空');
    }

    if (!_isValidUrl(data['url'])) {
      throw Exception('请输入有效的URL地址');
    }

    // 自动补全API路径
    String apiUrl = data['url'].trim();
    if (!apiUrl.endsWith('/')) apiUrl += '/';
    if (!apiUrl.endsWith('api.php/provide/vod')) {
      apiUrl += 'api.php/provide/vod';
    }

    final source = Source(
      id: Uuid().v4(),
      name: data['name'].trim(),
      url: apiUrl,
      weight: data['weight'] != null ? int.parse(data['weight'].toString()) : 5,
    );

    final newSource = await SourceStorage.addSource(source);

    return _createJsonResponse({
      'success': true,
      'message': '源添加成功',
      'data': newSource.toJson(),
    });
  } catch (e) {
    return _createErrorResponse(e.toString(), 400, e);
  }
}

Future<Response> _handleToggleSource(Request request) async {
  try {
    final id = request.url.queryParameters['id'];
    if (id == null) throw Exception('缺少ID参数');

    final updatedSource = await SourceStorage.toggleSource(id);
    return _createJsonResponse({
      'success': true,
      'data': updatedSource.toJson(),
    });
  } catch (e) {
    return _createErrorResponse(e.toString(), 400, e);
  }
}

Future<Response> _handleDeleteSource(Request request) async {
  try {
    final id = request.url.queryParameters['id'];
    if (id == null) throw Exception('缺少ID参数');

    await SourceStorage.deleteSource(id);
    return _createJsonResponse({'success': true});
  } catch (e) {
    return _createErrorResponse(e.toString(), 400, e);
  }
}

Future<Response> _handleAddProxy(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    if (data['url'] == null) {
      throw Exception('URL不能为空');
    }

    if(data['name'] == null) {
      throw Exception('代理名称不能为空');
    }

    // 验证URL格式
    final url = data['url'].toString().trim();
    if (!_isValidUrl(url)) {
      throw Exception('请输入有效的URL地址');
    }

    final proxy = Proxy(
      id: Uuid().v4(),
      url: url,
      name:data['name']
    );

    final newProxy = await SourceStorage.addProxy(proxy);

    return _createJsonResponse({
      'success': true,
      'message': '代理添加成功',
      'data': newProxy.toJson(),
    });
  } catch (e) {
    return _createErrorResponse(e.toString(), 400, e);
  }
}


// 获取所有代理
Future<Response> _handleGetProxies(Request request) async {
  try {
    final proxies = await SourceStorage.getAllProxies();
    return _createJsonResponse(proxies);
  } catch (e) {
    return _createErrorResponse('获取代理列表失败', 500, e);
  }
}

// 添加切换代理状态的处理函数
Future<Response> _handleToggleProxy(Request request) async {
  try {
    final id = request.url.queryParameters['id'];
    if (id == null) throw Exception('缺少ID参数');

    final updatedProxy = await SourceStorage.toggleProxy(id);
    return _createJsonResponse({
      'success': true,
      'data': updatedProxy.toJson(),
    });
  } catch (e) {
    return _createErrorResponse(e.toString(), 400, e);
  }
}

// 删除代理
Future<Response> _handleDeleteProxy(Request request) async {
  try {
    final id = request.url.queryParameters['id'];
    if (id == null) throw Exception('缺少ID参数');

    await SourceStorage.deleteProxy(id);
    return _createJsonResponse({'success': true});
  } catch (e) {
    return _createErrorResponse(e.toString(), 400, e);
  }
}


Future<Response> _handleSearchRequest(Request request) async {
  final wd = request.url.queryParameters['wd'] ?? '';

  try {
    final sources = await SourceStorage.getAllSources();
    final activeSources = sources.where((s) => !s.disabled).toList();

    if (activeSources.isEmpty) {
      return _createJsonResponse({
        'code': 0,
        'msg': "没有可用的源",
        'list': []
      });
    }

    // 获取第一条启用的代理
    final proxyBox = Hive.box(SourceStorage._proxyBoxName);
    final proxyList = proxyBox.values.toList();
    final activeProxy = proxyList.firstWhere(
          (proxy) => proxy['enabled'] == true,
      orElse: () => null,
    );


    // 并行请求所有源
    final results = await Future.wait(
      activeSources.map((source) async {
        // 如果有启用代理，则使用代理URL
        final baseUrl = activeProxy != null ? '${activeProxy['url']}/${source.url}' : source.url;
        final uri = Uri.parse(baseUrl);
        final queryParams = {
          'ac': 'videolist',
          'wd': wd,
        };
        final url = uri.replace(queryParameters: queryParams);

        try {
          final response = await get(url, timeout: const Duration(seconds: 5));

          if (response['statusCode'] == 200) {
            return jsonDecode(response['body']);
          }
          return null;
        } catch (e) {
          print('请求源 ${source.url} 失败: $e');
          return null;
        }
      }),
    );

    // 处理结果
    final validResults = results
        .where((r) => r != null && r['code'] == 1 && r['list'] != null && (r['list'] as List).isNotEmpty)
        .toList();

    if (validResults.isEmpty) {
      return _createJsonResponse({
        'code': 0,
        'msg': "未找到相关内容",
        'list': []
      });
    }

    // 合并列表并去重
    final mergedList = _mergeResults(validResults, activeSources);

    // 构建响应(无分页)
    final response = {
      'code': 1,
      'msg': "数据列表",
      'total': mergedList.length,
      'list': mergedList
    };

    return _createJsonResponse(response);
  } catch (e) {
    return _createErrorResponse("搜索失败: ${e.toString()}", 500, e);
  }
}

List<dynamic> _mergeResults(List<dynamic> results, List<Source> sources) {
  final mergedList = <dynamic>[];
  final seenIds = <String>{};

  for (int i = 0; i < results.length; i++) {
    final result = results[i];
    final sourceWeight = sources[i].weight;

    for (final item in result['list']) {
      final vodId = item['vod_id'].toString();
      if (!seenIds.contains(vodId)) {
        seenIds.add(vodId);

        // 根据源权重调整热度
        final weightedItem = Map<String, dynamic>.from(item);
        if (weightedItem['vod_hits'] != null) {
          weightedItem['vod_hits'] = (weightedItem['vod_hits'] * sourceWeight).round();
        }

        // 添加源信息
        weightedItem['source'] = {
          'name': sources[i].name,
          'weight': sourceWeight,
        };

        mergedList.add(weightedItem);
      }
    }
  }

  // 按热度排序
  mergedList.sort((a, b) => (b['vod_hits'] ?? 0).compareTo(a['vod_hits'] ?? 0));

  return mergedList;
}

// 辅助函数
Response _createJsonResponse(dynamic data, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(data),
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Cache-Control': 'no-store',
    },
  );
}

Response _createErrorResponse(String message, int status, dynamic error) {
  print('Error $status: $message - $error');
  return _createJsonResponse({
    'success': false,
    'message': message,
    'error': error.toString(),
  }, status: status);
}

bool _isValidUrl(String url) {
  try {
    Uri.parse(url);
    return true;
  } catch (e) {
    return false;
  }
}

// 模拟HTTP GET请求，实际应用中可以使用http包
Future<Map<String, dynamic>> get(Uri url, {Duration? timeout}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close().timeout(timeout ?? const Duration(seconds: 5));
    final responseBody = await response.transform(utf8.decoder).join();
    return {'statusCode': response.statusCode, 'body': responseBody};
  } finally {
    client.close();
  }
}

class Proxy {
  final String id;
  final String url; // 仅保留URL字段
  final String name;
  bool enabled;
  DateTime createdAt;
  DateTime updatedAt;

  Proxy({
    required this.id,
    required this.url,
    required this.name,
    this.enabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Proxy.fromJson(Map<String, dynamic> json) {
    return Proxy(
      id: json['id'],
      url: json['url'],
      name:json['name'],
      enabled: json['enabled'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'name': name,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}