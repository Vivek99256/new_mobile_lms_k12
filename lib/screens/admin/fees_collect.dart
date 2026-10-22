import 'package:flutter/material.dart';

import '../kit/kit.dart';
import '../screen_registry.dart';
import 'admin_common.dart';
import 'fee_details.dart';

/// t_feescollect: find a student, then collect fees.
class FeesCollectScreen extends StatelessWidget {
  const FeesCollectScreen({super.key, required this.args});
  final ScreenArgs args;

  @override
  Widget build(BuildContext context) => KitPage(
        title: args.item.label.isEmpty ? 'Fees collect' : args.item.label,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          StudentPicker(
            api: args.api,
            selectable: false,
            needDivision: true,
            openLabel: 'Collect fees',
            onChanged: (_, _, _) {},
            onOpen: (st, _) => push(context, FeeDetailsScreen(args: args, student: st)),
          ),
        ]),
      );
}
