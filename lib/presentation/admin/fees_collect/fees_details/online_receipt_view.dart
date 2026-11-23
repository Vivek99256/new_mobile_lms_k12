import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../../screens/kit/kit.dart';

/// Renders a fee receipt's HTML (the old app's OnlineReceiptView).
class OnlineReceiptView extends StatelessWidget {
  const OnlineReceiptView({super.key, required this.html});
  final String html;

  @override
  Widget build(BuildContext context) => KitPage(
        title: 'Fees receipt',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: ColoredBox(color: Colors.white, child: HtmlWidget(html)),
        ),
      );
}
