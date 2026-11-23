import 'package:flutter/material.dart';

import '../../../../core/api_client.dart';
import '../../../../core/legacy_api.dart';
import '../../../../screens/admin/admin_common.dart';
import '../../../../screens/kit/kit.dart';
import '../../../../screens/screen_registry.dart';

int _amount(dynamic v) => (num.tryParse(s(v)) ?? 0).round();

/// What a Pay Now attempt produced.
class PayNowResult {
  const PayNowResult({required this.ok, required this.message, this.receiptHtml = ''});
  final bool ok;
  final String message;
  final String receiptHtml;
}

/// State and API calls for the fees-details screen (the old app's FeesCollectDetailsController):
/// loads the student's pending / paid fees, tracks the ticked installments and posts the payment.
class FeesCollectDetailsController extends ChangeNotifier {
  FeesCollectDetailsController({required this.args, required this.studentInfo});

  final ScreenArgs args;

  /// The student picked on the previous screen.
  final Map<String, dynamic> studentInfo;

  final bankName = TextEditingController();
  final transactionID = TextEditingController();

  Map<String, dynamic> stuData = {};
  List<Map<String, dynamic>> pending = [];
  List<Map<String, dynamic>> paid = [];
  final ticked = <int>{};
  bool isLoading = true;
  String? error;

  LegacyApi get _api => args.api;

  int amountOf(dynamic v) => _amount(v);

  /// Sum of the ticked installments (the old app's `totalRemain`).
  int get totalRemain => ticked.fold(0, (sum, i) => sum + _amount(pending[i]['remain']));

  int get totalDue => pending.fold(0, (sum, p) => sum + _amount(p['remain']));

  void toggle(int i) {
    ticked.contains(i) ? ticked.remove(i) : ticked.add(i);
    notifyListeners();
  }

  Future<void> callService() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final q = Uri(
        queryParameters: {
          'syear': syearOf(args.session),
          'sub_institute_id': '${args.session.subInstituteId}',
          'student_id': s(studentInfo['id']),
          // The server only accepts this call as an API request carrying the user's token.
          'type': 'API',
          // With `type` the server returns only paid receipts; `detail=full` keeps pending + student data.
          'detail': 'full',
          'token': args.session.token,
        },
      ).query;
      final res = await _api.post('/studentFeesDetailAPI?$q', withIdentity: false);
      if (!submitOk(res)) {
        error = LegacyApi.messageOf(res, 'Could not load fee details.');
      } else {
        final data = m(res['data']);
        stuData = m(data['STU_DATA']);
        pending = rows(data['PENDING']);
        paid = rows(data['PAID']);
        ticked.clear();
      }
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Validation message, or null when the form can be submitted.
  String? validate() {
    if (bankName.text.trim().isEmpty) return 'Please enter the bank name.';
    if (transactionID.text.trim().isEmpty) return 'Please enter the transaction ID.';
    if (totalRemain <= 0) return 'Select at least one installment.';
    return null;
  }

  Future<PayNowResult> callServicePayNow() async {
    final q = Uri(
      queryParameters: {
        'syear': syearOf(args.session),
        'sub_institute_id': '${args.session.subInstituteId}',
        'student_id': s(studentInfo['id']),
        'amount': '$totalRemain',
        'bank_name': bankName.text.trim(),
        'transactionid': transactionID.text.trim(),
        'fine': '0',
        'type': 'API',
        // Staff only: the signed-in user's token, never the payer's own.
        'token': args.session.token,
      },
    ).query;
    final res = await _api.post('/fees/get_online_receipt?$q', withIdentity: false);
    if (!submitOk(res)) {
      return PayNowResult(ok: false, message: LegacyApi.messageOf(res));
    }
    final html = s(res['receipt_html']).isNotEmpty ? s(res['receipt_html']) : s(m(res['data'])['receipt_html']);
    return PayNowResult(ok: true, message: LegacyApi.messageOf(res, 'Payment recorded.'), receiptHtml: html);
  }

  @override
  void dispose() {
    bankName.dispose();
    transactionID.dispose();
    super.dispose();
  }
}
