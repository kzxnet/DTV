import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class AppUpdater {
  static final Dio _dio = Dio();
  static const String _githubReleasesUrl =
      'https://api.github.com/repos/laopaoer-wallet/DTV/releases/latest';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _dio.get(_githubReleasesUrl);
      final latestRelease = response.data;
      final latestVersion = latestRelease['tag_name'].replaceAll('v', '');
      final releaseUrl = latestRelease['html_url'];
      final releaseNotes = latestRelease['body'];

      if (_compareVersions(currentVersion, latestVersion) < 0) {
        _showUpdateDialog(context, releaseUrl, latestVersion, releaseNotes);
      }
    } catch (e) {
      debugPrint('检查更新失败: $e');
    }
  }

  static int _compareVersions(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (var i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;

      if (currentPart < latestPart) return -1;
      if (currentPart > latestPart) return 1;
    }
    return 0;
  }

  static void _showUpdateDialog(
      BuildContext context,
      String url,
      String version,
      String notes,
      ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('发现新版本 v$version'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('更新内容:'),
              const SizedBox(height: 8),
              Text(notes.isNotEmpty ? notes : '暂无更新说明'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后再说'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }
}