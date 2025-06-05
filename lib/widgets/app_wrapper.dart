import 'package:flutter/material.dart';
import 'package:libretv_app/widgets/update_checker.dart';
import 'package:libretv_app/widgets/search_page.dart';

import 'category_page.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    await AppUpdater.checkForUpdate(context);
  }

  @override
  Widget build(BuildContext context) {
    return MovieHomePage();
  }
}
