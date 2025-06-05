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
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  await Hive.openBox('sources');
  await Hive.openBox('proxies');
  await Hive.openBox('tags'); // Add tags box

  // Start web server
  final server = await startServer();

  runApp(MyApp(server: server));
}

Future<Directory> _copyAssetsToDocuments() async {
  final appDir = await getApplicationDocumentsDirectory();
  final webDir = Directory('${appDir.path}/web');

  if (!await webDir.exists()) {
    await webDir.create(recursive: true);
  }

  final assets = [
    'assets/web/index.html'
  ];

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

  final staticHandler = createStaticHandler(
    webDir.path,
    defaultDocument: 'index.html',
  );

  final router = shelf_router.Router()
    ..options('/api/<any|.*>', (Request request) => Response.ok(''))
  // Sources endpoints
    ..get('/api/sources', _handleGetSources)
    ..post('/api/sources', _handleAddSource)
    ..put('/api/sources/toggle', _handleToggleSource)
    ..delete('/api/sources', _handleDeleteSource)
  // Proxies endpoints
    ..get('/api/proxies', _handleGetProxies)
    ..post('/api/proxies', _handleAddProxy)
    ..put('/api/proxies/toggle', _handleToggleProxy)
    ..delete('/api/proxies', _handleDeleteProxy)
  // Tags endpoints
    ..get('/api/tags', _handleGetTags)
    ..post('/api/tags', _handleAddTag)
    ..put('/api/tags', _handleUpdateTag)
    ..put('/api/tags/order', _handleUpdateTagOrder)
    ..delete('/api/tags', _handleDeleteTag)
  // Search endpoint
    ..get('/api/search', _handleSearchRequest)
  // Static files
    ..get('/', staticHandler)
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
              const Text('/api/tags - 标签管理'),
              const Text('/api/proxies - 代理管理'),
              const Text('/api/search?wd=关键词 - 搜索内容'),
            ],
          ),
        ),
      ),
    );
  }
}

// Storage class
class SourceStorage {
  static const String _boxName = 'sources';
  static const String _proxyBoxName = 'proxies';
  static const String _tagBoxName = 'tags';

  // Source methods
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

  // Proxy methods
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

  // Tag methods
  static Future<List<Tag>> getAllTags() async {
    final box = Hive.box(_tagBoxName);
    final tags = box.values.map((e) => Tag.fromJson(Map<String, dynamic>.from(e))).toList();
    tags.sort((a, b) => a.order.compareTo(b.order));
    return tags;
  }

  static Future<Tag> addTag(Tag tag) async {
    final box = Hive.box(_tagBoxName);
    await box.put(tag.id, tag.toJson());
    return tag;
  }

  static Future<Tag> updateTag(Tag tag) async {
    final box = Hive.box(_tagBoxName);
    await box.put(tag.id, tag.toJson());
    return tag;
  }

  static Future<void> deleteTag(String id) async {
    final box = Hive.box(_tagBoxName);
    await box.delete(id);
  }

  static Future<void> updateTagOrder(List<String> tagIds) async {
    final box = Hive.box(_tagBoxName);
    for (int i = 0; i < tagIds.length; i++) {
      final tagJson = box.get(tagIds[i]);
      if (tagJson != null) {
        final tag = Tag.fromJson(Map<String, dynamic>.from(tagJson));
        tag.order = i;
        await box.put(tag.id, tag.toJson());
      }
    }
  }
}

// Source model
class Source {
  final String id;
  final String name;
  final String url;
  final int weight;
  bool disabled;
  List<String> tagIds;
  DateTime createdAt;
  DateTime updatedAt;

  Source({
    required this.id,
    required this.name,
    required this.url,
    this.weight = 5,
    this.disabled = false,
    this.tagIds = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      weight: json['weight'],
      disabled: json['disabled'],
      tagIds: List<String>.from(json['tagIds'] ?? []),
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
      'tagIds': tagIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

// Proxy model
class Proxy {
  final String id;
  final String url;
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
      name: json['name'],
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

// Tag model
class Tag {
  final String id;
  String name;
  String color;
  int order;
  DateTime createdAt;
  DateTime updatedAt;

  Tag({
    required this.id,
    required this.name,
    this.color = '#4285F4',
    required this.order,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'],
      name: json['name'],
      color: json['color'] ?? '#4285F4',
      order: json['order'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

// API handlers for sources
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
      tagIds: List<String>.from(data['tagIds'] ?? []),
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

// API handlers for proxies
Future<Response> _handleGetProxies(Request request) async {
  try {
    final proxies = await SourceStorage.getAllProxies();
    return _createJsonResponse(proxies);
  } catch (e) {
    return _createErrorResponse('获取代理列表失败', 500, e);
  }
}

Future<Response> _handleAddProxy(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    if (data['url'] == null) {
      throw Exception('URL不能为空');
    }

    if (data['name'] == null) {
      throw Exception('代理名称不能为空');
    }

    final url = data['url'].toString().trim();
    if (!_isValidUrl(url)) {
      throw Exception('请输入有效的URL地址');
    }

    final proxy = Proxy(
      id: Uuid().v4(),
      url: url,
      name: data['name'],
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

// API handlers for tags
Future<Response> _handleGetTags(Request request) async {
  try {
    final tags = await SourceStorage.getAllTags();
    return _createJsonResponse(tags);
  } catch (e) {
    return _createErrorResponse('获取标签列表失败', 500, e);
  }
}

Future<Response> _handleAddTag(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    if (data['name'] == null) {
      throw Exception('标签名称不能为空');
    }

    final tags = await SourceStorage.getAllTags();
    final maxOrder = tags.isEmpty ? 0 : tags.map((t) => t.order).reduce((a, b) => a > b ? a : b);

    final tag = Tag(
      id: Uuid().v4(),
      name: data['name'].toString().trim(),
      color: data['color']?.toString() ?? '#4285F4',
      order: maxOrder + 1,
    );

    final newTag = await SourceStorage.addTag(tag);

    return _createJsonResponse({
      'success': true,
      'message': '标签添加成功',
      'data': newTag.toJson(),
    });
  } catch (e) {
    return _createErrorResponse(e.toString(), 400, e);
  }
}

Future<Response> _handleUpdateTag(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    if (data['id'] == null || data['name'] == null) {
      throw Exception('ID和名称不能为空');
    }

    final tags = await SourceStorage.getAllTags();
    final existingTag = tags.firstWhere((t) => t.id == data['id'], orElse: () => throw Exception('标签不存在'));

    final updatedTag = Tag(
      id: existingTag.id,
      name: data['name'].toString().trim(),
      color: data['color']?.toString() ?? existingTag.color,
      order: existingTag.order,
      createdAt: existingTag.createdAt,
      updatedAt: DateTime.now(),
    );

    await SourceStorage.updateTag(updatedTag);

    return _createJsonResponse({
      'success': true,
      'message': '标签更新成功',
      'data': updatedTag.toJson(),
    });
  } catch (e) {
    return _createErrorResponse(e.toString(), 400, e);
  }
}

Future<Response> _handleUpdateTagOrder(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body);

    if (data['tagIds'] == null || data['tagIds'] is! List) {
      throw Exception('需要标签ID数组');
    }

    final tagIds = List<String>.from(data['tagIds']);
    await SourceStorage.updateTagOrder(tagIds);

    return _createJsonResponse({
      'success': true,
      'message': '标签顺序更新成功',
    });
  } catch (e) {
    return _createErrorResponse(e.toString(), 400, e);
  }
}

Future<Response> _handleDeleteTag(Request request) async {
  try {
    final id = request.url.queryParameters['id'];
    if (id == null) throw Exception('缺少ID参数');

    await SourceStorage.deleteTag(id);
    return _createJsonResponse({'success': true});
  } catch (e) {
    return _createErrorResponse(e.toString(), 400, e);
  }
}

// Search handler
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

    final proxyBox = Hive.box(SourceStorage._proxyBoxName);
    final proxyList = proxyBox.values.toList();
    final activeProxy = proxyList.firstWhere(
          (proxy) => proxy['enabled'] == true,
      orElse: () => null,
    );

    final results = await Future.wait(
      activeSources.map((source) async {
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

    final mergedList = _mergeResults(validResults, activeSources);

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

// Helper functions
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

        final weightedItem = Map<String, dynamic>.from(item);
        if (weightedItem['vod_hits'] != null) {
          weightedItem['vod_hits'] = (weightedItem['vod_hits'] * sourceWeight).round();
        }

        weightedItem['source'] = {
          'name': sources[i].name,
          'weight': sourceWeight,
        };

        mergedList.add(weightedItem);
      }
    }
  }

  mergedList.sort((a, b) => (b['vod_hits'] ?? 0).compareTo(a['vod_hits'] ?? 0));

  return mergedList;
}

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