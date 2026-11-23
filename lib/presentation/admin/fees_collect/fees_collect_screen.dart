import 'package:flutter/material.dart';

import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';
import 'fees_collect_controller.dart';

/// t_feescollect / Fees Collect / Online Fees Collect: find a student, then collect fees.
class FeesCollectScreen extends StatelessWidget {
  FeesCollectScreen({super.key, required this.args}) : _con = FeesCollectController(args: args);
  final ScreenArgs args;
  final FeesCollectController _con;

  @override
  Widget build(BuildContext context) => KitPage(
        title: _con.title,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          StudentPicker(
            api: args.api,
            selectable: false,
            needDivision: true,
            openLabel: 'Collect fees',
            onChanged: (_, _, _) {},
            onOpen: (st, _) => _con.openStudent(context, st),
          ),
        ]),
      );
}
