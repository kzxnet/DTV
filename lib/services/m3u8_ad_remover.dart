import 'package:http/http.dart' as http;

class M3U8AdRemover {
  static Future<String> fixAdM3u8Ai(String m3u8Url, [Map<String, String>? headers]) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    headers ??= {};

    print('处理地址: $m3u8Url');

    // Helper functions
    int compareSameLen(String s1, String s2) {
      int length = 0;
      while (length < s1.length && length < s2.length && s1[length] == s2[length]) {
        length++;
      }
      return length;
    }

    String reverseString(String str) => String.fromCharCodes(str.runes.toList().reversed);

    Future<String> fetchM3u8(String url) async {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return response.body.trim();
      }
      throw Exception('Failed to fetch M3U8: ${response.statusCode}');
    }

    String urljoin(String fromPath, String nowPath) {
      fromPath = fromPath;
      nowPath = nowPath;

      try {
        final baseUri = Uri.parse(fromPath);
        final resolvedUri = baseUri.resolve(nowPath);
        return resolvedUri.toString();
      } catch (e) {
        // Fallback for invalid URIs
        if (nowPath.startsWith('http://') || nowPath.startsWith('https://')) {
          return nowPath;
        }
        if (fromPath.isEmpty) return nowPath;

        final separator = fromPath.endsWith('/') || nowPath.startsWith('/') ? '' : '/';
        return '$fromPath$separator$nowPath';
      }
    }

    List<String> resolveUrls(List<String> lines, String baseUrl) {
      return lines.map((line) {
        if (!line.startsWith('#') && !line.startsWith('http://') && !line.startsWith('https://')) {
          return urljoin(baseUrl, line);
        }
        return line;
      }).toList();
    }

    List<String> compressEmptyLines(List<String> lines) {
      final result = <String>[];
      bool lastLineWasEmpty = false;

      for (final line in lines) {
        final isEmpty = line.trim().isEmpty;
        if (!isEmpty || !lastLineWasEmpty) {
          result.add(line);
        }
        lastLineWasEmpty = isEmpty;
      }

      return result;
    }

    Future<List<String>> parseM3u8ToArray(String url) async {
      String content = await fetchM3u8(url);
      List<String> lines = content.split('\n');
      lines = resolveUrls(lines, m3u8Url);
      lines = compressEmptyLines(lines);
      return lines;
    }

    List<String> lines = await parseM3u8ToArray(m3u8Url);

    // Handle nested M3U8
    String lastUrl = lines.isNotEmpty ? lines.last : '';
    if (lastUrl.length < 5 && lines.length > 1) {
      lastUrl = lines[lines.length - 2];
    }
    if (lastUrl.contains('.m3u8') && lastUrl != m3u8Url) {
      m3u8Url = lastUrl;
      if (!lastUrl.startsWith('http://') && !lastUrl.startsWith('https://')) {
        m3u8Url = urljoin(m3u8Url, lastUrl);
      }
      print('嵌套地址: $m3u8Url');
      lines = await parseM3u8ToArray(m3u8Url);
    }

    // Find ad segments
    Map<String, dynamic> findAdSegments(List<String> segments, String baseUrl) {
      final cleanSegments = List<String>.from(segments);
      String firstStr = "";
      String secondStr = "";
      int maxSimilarity = 0;
      int primaryCount = 1;
      int secondaryCount = 0;

      // First pass: determine firstStr
      for (final segment in cleanSegments) {
        if (!segment.startsWith("#")) {
          if (firstStr.isEmpty) {
            firstStr = segment;
          } else {
            final similarity = compareSameLen(firstStr, segment);
            if (maxSimilarity > similarity + 1) {
              if (secondStr.length < 5) secondStr = segment;
              secondaryCount++;
            } else {
              maxSimilarity = similarity;
              primaryCount++;
            }
          }
          if (secondaryCount + primaryCount >= 30) break;
        }
      }
      if (secondaryCount > primaryCount) firstStr = secondStr;

      final firstStrLen = firstStr.length;
      final maxIterations = cleanSegments.length < 10 ? cleanSegments.length : 10;
      final halfLength = (cleanSegments.length ~/ 2).toString().length;

      // Second pass: find lastStr
      int maxc = 0;
      String? lastStr;
      for (final segment in cleanSegments.reversed) {
        if (!segment.startsWith("#")) {
          final reversedFirstStr = reverseString(firstStr);
          final reversedX = reverseString(segment);
          final similarity = compareSameLen(reversedFirstStr, reversedX);
          maxSimilarity = compareSameLen(firstStr, segment);
          maxc++;
          if (firstStrLen - maxSimilarity <= halfLength + similarity || maxc > 10) {
            lastStr = segment;
            break;
          }
        }
      }

      print("最后切片: $lastStr");

      final adSegments = <String>[];
      final cleanedSegments = <String>[];

      // Third pass: process segments
      for (int i = 0; i < cleanSegments.length; i++) {
        final segment = cleanSegments[i];
        if (segment.startsWith("#")) {
          if (segment.contains("URI=")) {
            final uriMatch = RegExp(r'URI="([^"]*)"').firstMatch(segment);
            if (uriMatch != null) {
              final updatedUri = urljoin(baseUrl, uriMatch.group(1)!);
              cleanedSegments.add(
                  segment.replaceFirst(RegExp(r'URI="([^"]*)"'), 'URI="$updatedUri"'));
            } else {
              cleanedSegments.add(segment);
            }
          } else {
            cleanedSegments.add(segment);
          }
        } else {
          if (compareSameLen(firstStr, segment) < maxSimilarity) {
            adSegments.add(segment);
            // Skip the next segment (EXTINF) if it exists
            if (i + 1 < cleanSegments.length && cleanSegments[i + 1].startsWith("#EXTINF")) {
              i++;
            }
          } else {
            cleanedSegments.add(urljoin(baseUrl, segment));
          }
        }
      }

      return {
        'adSegments': adSegments,
        'cleanSegments': cleanedSegments,
      };
    }

    final result = findAdSegments(lines, m3u8Url);
    final cleanSegments = result['cleanSegments'] as List<String>;
    final adSegments = result['adSegments'] as List<String>;

    print('广告分片: $adSegments');
    print('处理耗时: ${DateTime.now().millisecondsSinceEpoch - startTime} ms');
    return cleanSegments.join('\n');
  }
}