import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'theme.dart';

final Future<PackageInfo> _info = PackageInfo.fromPlatform();

/// "Version 1.0.1 (build 3)", read from the installed app.
class AppVersionText extends StatelessWidget {
  const AppVersionText({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: _info,
        builder: (_, snap) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            snap.hasData ? 'Version ${snap.data!.version} (build ${snap.data!.buildNumber})' : '',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.33, color: Brand.ink3),
          ),
        ),
      );
}
