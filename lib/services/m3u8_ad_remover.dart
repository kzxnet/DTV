import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class M3U8AdRemover {
  // 配置参数
  int _tsNameLen = 0;
  int _tsNameLenExtend = 1;
  String _firstExtinfRow = '';
  int _extinfJudgeCount = 0;
  int _sameExtinfNameCount = 0;
  final int _extinfBenchmark = 5;
  int _prevTsNameIndex = -1;
  int _firstTsNameIndex = -1;
  int _tsType = 0;
  int _extXMode = 0;
  bool _violentMode = false;

  // 广告日志记录
  final List<String> _adLogs = [];
  bool _enableLogging = true;

  /// 主方法：修复包含广告的M3U8文件
  static Future<String> fixAdM3u8Ai(String m3u8Url,
      {Map<String, String>? headers, bool enableLogging = true}) async {
    final instance = M3U8AdRemover();
    instance._enableLogging = enableLogging;
    return instance._processM3u8(m3u8Url, headers ?? {});
  }

  /// 获取广告日志
  static List<String> getAdLogs() {
    return M3U8AdRemover()._adLogs;
  }

  /// 处理M3U8的核心流程
  Future<String> _processM3u8(String m3u8Url, Map<String, String> headers) async {
    _log('开始处理M3U8: $m3u8Url');

    // 1. 获取并解析M3U8内容
    List<String> lines = await _fetchAndParseM3u8(m3u8Url, headers);
    _log('原始M3U8行数: ${lines.length}');

    // 2. 处理嵌套M3U8
    m3u8Url = await _handleNestedM3u8(lines, m3u8Url);
    if (m3u8Url != lines.last) {
      _log('发现嵌套M3U8，重新获取: $m3u8Url');
      lines = await _fetchAndParseM3u8(m3u8Url, headers);
    }

    // 3. 过滤广告片段
    final filteredLines = _filterAdSegments(lines, m3u8Url);
    _log('过滤完成，剩余行数: ${filteredLines.length}');
    _log('共过滤广告片段: ${_adLogs.where((log) => log.contains("过滤广告")).length}个');

    return filteredLines.join('\n');
  }

  /// 记录日志
  void _log(String message, {bool isAdLog = false}) {
    if (!_enableLogging) return;

    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final logMsg = '[$timestamp] $message';

    if (isAdLog) {
      _adLogs.add(logMsg);
    }
    debugPrint(logMsg);
  }

  /// 获取并解析M3U8文件
  Future<List<String>> _fetchAndParseM3u8(String url, Map<String, String> headers) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch M3U8: ${response.statusCode}');
      }

      String content = response.body.trim();
      List<String> lines = content.split('\n');
      _log('成功获取M3U8内容，行数: ${lines.length}');

      // 解析URL并处理相对路径
      return lines.map((line) => _resolveUrl(line, url)).toList();
    } catch (e) {
      _log('获取M3U8失败: $e', isAdLog: true);
      rethrow;
    }
  }

  /// 解析URL，处理相对路径
  String _resolveUrl(String line, String baseUrl) {
    if (line.startsWith('#') || line.startsWith('http')) {
      return line;
    }

    try {
      final baseUri = Uri.parse(baseUrl);
      final resolvedUri = baseUri.resolve(line);
      return resolvedUri.toString();
    } catch (e) {
      _log('URL解析失败，使用简单拼接: $e', isAdLog: true);
      final separator = baseUrl.endsWith('/') || line.startsWith('/') ? '' : '/';
      return '$baseUrl$separator$line';
    }
  }

  /// 处理嵌套的M3U8文件
  Future<String> _handleNestedM3u8(List<String> lines, String currentUrl) async {
    if (lines.length < 2) return currentUrl;

    String lastUrl = lines.last;
    if (lastUrl.length < 5) {
      lastUrl = lines[lines.length - 2];
    }

    if (lastUrl.contains('.m3u8') && lastUrl != currentUrl) {
      _log('发现嵌套M3U8文件: $lastUrl');
      return lastUrl.startsWith('http') ? lastUrl : _resolveUrl(lastUrl, currentUrl);
    }

    return currentUrl;
  }

  /// 核心广告过滤逻辑
  List<String> _filterAdSegments(List<String> lines, String baseUrl) {
    // 1. 自动检测TS片段类型
    _detectTsSegmentType(lines);

    List<String> result = [];
    int adCount = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      bool isAd = false;
      String? adType;

      // 2. 根据检测到的类型应用不同的过滤规则
      switch (_tsType) {
        case 0: // 数字递增模式
          isAd = _handleNumberIncrementMode(line, lines, i, (type) => adType = type);
          break;
        case 1: // 固定命名模式
          isAd = _handleFixedNameMode(line, lines, i, (type) => adType = type);
          break;
        case 2: // 暴力拆解模式
          isAd = _handleViolentMode(line, lines, i, (type) => adType = type);
          break;
      }

      if (isAd && adType != null) {
        adCount++;
        _logAdSegment(adType!, line, lines, i);
        continue;
      }

      // 3. 处理特殊标签（如URI=）
      if (line.startsWith('#') && line.contains('URI=')) {
        result.add(_processUriTag(line, baseUrl));
      } else {
        result.add(line);
      }
    }

    _log('共过滤广告片段: $adCount个');
    return result;
  }

  /// 记录广告片段日志
  void _logAdSegment(String type, String line, List<String> lines, int index) {
    final adInfo = StringBuffer();
    adInfo.writeln('发现广告片段 [$type]');
    adInfo.writeln('当前行: $line');

    // 记录上下文信息
    if (index > 0) {
      adInfo.writeln('前一行: ${lines[index - 1]}');
    }
    if (index < lines.length - 1) {
      adInfo.writeln('后一行: ${lines[index + 1]}');
    }

    _log(adInfo.toString(), isAdLog: true);
  }

  /// 检测TS片段类型
  void _detectTsSegmentType(List<String> lines) {
    if (_violentMode) {
      _tsType = 2;
      _log('使用暴力拆解模式');
      return;
    }

    int normalIntTsCount = 0;
    int diffIntTsCount = 0;
    int lastTsNameLen = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 初始化firstExtinfRow
      if (_extinfJudgeCount == 0 && line.startsWith('#EXTINF')) {
        _firstExtinfRow = line;
        _extinfJudgeCount++;
        _log('初始化第一EXTINF行: $_firstExtinfRow');
      } else if (_extinfJudgeCount == 1 && line.startsWith('#EXTINF')) {
        if (line != _firstExtinfRow) {
          _firstExtinfRow = '';
          _log('EXTINF行不一致，重置第一EXTINF行');
        }
        _extinfJudgeCount++;
      }

      // 判断ts模式
      final tsNameLen = line.indexOf('.ts');
      if (tsNameLen > 0) {
        if (_extinfJudgeCount == 1) {
          _tsNameLen = tsNameLen;
          _log('设置TS名称长度: $_tsNameLen');
        }
        lastTsNameLen = tsNameLen;

        final tsNameIndex = _extractNumberBeforeTs(line);
        if (tsNameIndex == null) {
          if (_extinfJudgeCount == 1) {
            _tsType = 1;
            _log('检测到TS模式1: 固定命名模式');
          } else if (_extinfJudgeCount == 2 && (_tsType == 1 || tsNameLen == _tsNameLen)) {
            _tsType = 1;
            _log('确认TS模式1: 固定命名模式');
            break;
          } else {
            diffIntTsCount++;
          }
        } else {
          if (normalIntTsCount == 0) {
            _prevTsNameIndex = tsNameIndex;
            _firstTsNameIndex = tsNameIndex;
            _prevTsNameIndex = _firstTsNameIndex - 1;
            _log('初始化TS序号: 当前=$tsNameIndex, 上一个=$_prevTsNameIndex');
          }

          if (tsNameLen != _tsNameLen) {
            if (tsNameLen == lastTsNameLen + 1 && tsNameIndex == _prevTsNameIndex + 1) {
              if (diffIntTsCount > 0) {
                if (tsNameIndex == _prevTsNameIndex + 1) {
                  _tsType = 0;
                  _prevTsNameIndex = _firstTsNameIndex - 1;
                  _log('检测到TS模式0: 数字递增模式');
                  break;
                } else {
                  _tsType = 2;
                  _log('检测到TS模式2: 暴力拆解模式');
                  break;
                }
              }
              normalIntTsCount++;
              _prevTsNameIndex = tsNameIndex;
            } else {
              diffIntTsCount++;
            }
          } else {
            if (diffIntTsCount > 0) {
              if (tsNameIndex == _prevTsNameIndex + 1) {
                _tsType = 0;
                _prevTsNameIndex = _firstTsNameIndex - 1;
                _log('检测到TS模式0: 数字递增模式');
                break;
              } else {
                _tsType = 2;
                _log('检测到TS模式2: 暴力拆解模式');
                break;
              }
            }
            normalIntTsCount++;
            _prevTsNameIndex = tsNameIndex;
          }
        }
      }

      if (i == lines.length - 1) {
        _tsType = 2;
        _log('自动切换到暴力拆解模式');
      }
    }
  }

  /// 处理数字递增模式
  bool _handleNumberIncrementMode(String line, List<String> lines, int i,
      void Function(String) setAdType) {
    if (line.startsWith('#EXT-X-DISCONTINUITY') && i + 2 < lines.length) {
      if (i > 0 && lines[i - 1].startsWith('#EXT-X-')) {
        return false;
      }

      final tsNameLen = lines[i + 2].indexOf('.ts');
      if (tsNameLen > 0) {
        if (tsNameLen - _tsNameLen > _tsNameLenExtend) {
          setAdType('数字递增模式-文件名长度不符');
          return true;
        }

        final tsNameIndex = _extractNumberBeforeTs(lines[i + 2]);
        if (tsNameIndex != _prevTsNameIndex + 1) {
          setAdType('数字递增模式-序号不连续');
          return true;
        }
      }
    }

    if (line.startsWith('#EXTINF') && i + 1 < lines.length) {
      final tsNameLen = lines[i + 1].indexOf('.ts');
      if (tsNameLen > 0) {
        if (tsNameLen - _tsNameLen > _tsNameLenExtend) {
          setAdType('数字递增模式-文件名长度不符');
          return true;
        }

        final tsNameIndex = _extractNumberBeforeTs(lines[i + 1]);
        if (tsNameIndex != _prevTsNameIndex + 1) {
          setAdType('数字递增模式-序号不连续');
          return true;
        }
        _prevTsNameIndex++;
      }
    }

    return false;
  }

  /// 处理固定命名模式
  bool _handleFixedNameMode(String line, List<String> lines, int i,
      void Function(String) setAdType) {
    if (line.startsWith('#EXTINF')) {
      if (line == _firstExtinfRow && _sameExtinfNameCount <= _extinfBenchmark && _extXMode == 0) {
        _sameExtinfNameCount++;
      } else {
        _extXMode = 1;
      }

      if (_sameExtinfNameCount > _extinfBenchmark) {
        _extXMode = 1;
      }
    }

    if (line.startsWith('#EXT-X-DISCONTINUITY')) {
      if (i > 0 && lines[i - 1].startsWith('#EXT-X-PLAYLIST-TYPE')) {
        return false;
      }

      if (i + 2 < lines.length &&
          lines[i + 1].startsWith('#EXTINF') &&
          lines[i + 2].indexOf('.ts') > 0) {

        bool isAd = false;
        if (_extXMode == 1) {
          isAd = lines[i + 1] != _firstExtinfRow && _sameExtinfNameCount > _extinfBenchmark;
          if (isAd) {
            setAdType('固定命名模式-EXTINF不一致');
          }
        }

        return isAd;
      }
    }

    return false;
  }

  /// 处理暴力拆解模式
  bool _handleViolentMode(String line, List<String> lines, int i,
      void Function(String) setAdType) {
    if (line.startsWith('#EXT-X-DISCONTINUITY') &&
        !(i > 0 && lines[i - 1].startsWith('#EXT-X-PLAYLIST-TYPE'))) {
      setAdType('暴力拆解模式-EXT-X-DISCONTINUITY');
      return true;
    }
    return false;
  }

  /// 处理URI标签
  String _processUriTag(String line, String baseUrl) {
    final uriMatch = RegExp(r'URI="([^"]*)"').firstMatch(line);
    if (uriMatch != null) {
      final updatedUri = _resolveUrl(uriMatch.group(1)!, baseUrl);
      return line.replaceFirst(RegExp(r'URI="([^"]*)"'), 'URI="$updatedUri"');
    }
    return line;
  }

  /// 提取.ts前面的数字
  int? _extractNumberBeforeTs(String str) {
    final match = RegExp(r'(\d+)\.ts').firstMatch(str);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }
}