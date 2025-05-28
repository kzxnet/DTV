import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class AppUpdater {
  static final Dio _dio = Dio();
  static const String _githubReleasesUrl =
      'https://api.github.com/repos/laopaoer-wallet/DTV/releases/latest';

  static bool _isDownloading = false;
  static double _downloadProgress = 0;
  static CancelToken? _cancelToken;

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await _dio.get(_githubReleasesUrl);
      final latestRelease = response.data;
      final latestVersion = latestRelease['tag_name'].replaceAll('v', '');
      final releaseUrl = latestRelease['html_url'];
      final releaseNotes = latestRelease['body'];
      final apkUrl = _findApkDownloadUrl(latestRelease['assets']);

      if (_compareVersions(currentVersion, latestVersion) < 0 && context.mounted) {
        _showUpdateDialog(
          context,
          releaseUrl,
          latestVersion,
          releaseNotes,
          apkUrl: apkUrl,
        );
      }
    } catch (e) {
      debugPrint('检查更新失败: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: ${e.toString()}')),
        );
      }
    }
  }

  static String? _findApkDownloadUrl(List<dynamic> assets) {
    for (final asset in assets) {
      if (asset['name'].toString().endsWith('.apk')) {
        return asset['browser_download_url'];
      }
    }
    return null;
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
      String notes, {
        String? apkUrl,
      }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('发现新版本 v$version'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('更新内容:'),
                  const SizedBox(height: 8),
                  Text(notes.isNotEmpty ? notes : '暂无更新说明'),
                  if (_isDownloading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Colors.grey[200],
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '下载中: ${(_downloadProgress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (!_isDownloading) ...[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('稍后再说'),
                ),
                if (apkUrl != null)
                  TextButton(
                    onPressed: () => _downloadAndInstallApk(context, apkUrl, setState),
                    child: const Text('自动更新'),
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
                  child: const Text('手动更新'),
                ),
              ] else ...[
                TextButton(
                  onPressed: _cancelDownload,
                  child: const Text('取消下载'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static Future<void> _downloadAndInstallApk(
      BuildContext context,
      String apkUrl,
      StateSetter setState,
      ) async {
    try {
      // 请求存储权限
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要存储权限才能下载更新')),
          );
        }
        return;
      }

      // 请求安装未知来源应用的权限
      if (Platform.isAndroid) {
        if (!await Permission.requestInstallPackages.isGranted) {
          await Permission.requestInstallPackages.request();
        }
      }

      setState(() {
        _isDownloading = true;
        _downloadProgress = 0;
      });

      _cancelToken = CancelToken();
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/update_${DateTime.now().millisecondsSinceEpoch}.apk';

      await _dio.download(
        apkUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      setState(() {
        _isDownloading = false;
      });

      if (context.mounted) {
        Navigator.pop(context);
      }

      // 安装APK
      if (Platform.isAndroid) {
        await _installApk(savePath);
      }

    } catch (e) {
      debugPrint('下载失败: $e');
      setState(() {
        _isDownloading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: ${e.toString()}')),
        );
      }
    }
  }

  static Future<void> _installApk(String apkPath) async {
    if (await File(apkPath).exists()) {
      try {
        if (Platform.isAndroid) {
          final intent = AndroidIntent(
            action: 'action_view',
            type: 'application/vnd.android.package-archive',
            data: Uri.file(apkPath).toString(),  // 使用 Uri.file 替代 Uri.fromFile
            flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
          );
          await intent.launch();
        }
      } catch (e) {
        debugPrint('安装失败: $e');
        // 如果使用intent失败，尝试使用open_file
        await OpenFile.open(apkPath);
      }
    }
  }

  static void _cancelDownload() {
    _cancelToken?.cancel('用户取消下载');
    _isDownloading = false;
    _downloadProgress = 0;
  }
}