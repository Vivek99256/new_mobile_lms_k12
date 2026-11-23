import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/legacy_api.dart';
import '../../../screens/admin/admin_common.dart';
import '../../../screens/kit/kit.dart';
import '../../../screens/screen_registry.dart';

/// One receipt returned by `POST /api/fees-cancel/search`.
class CancelReceipt {
  CancelReceipt(Map<String, dynamic> r)
      : feesType = s(r['fees_type']).toUpperCase() == 'OTHER' ? 'OTHER' : 'REGULAR',
        receiptNo = s(r['receipt_no']),
        studentId = s(r['student_id']),
        studentName = s(r['student_name']),
        enrollmentNo = s(r['enrollment_no']),
        standard = s(r['standard_name']),
        division = s(r['division_name']),
        totalAmount = num.tryParse(s(r['total_amount']).replaceAll(',', '')) ?? 0,
        receiptDate = s(r['receiptdate']),
        paymentMode = s(r['payment_mode']),
        bankBranch = s(r['bank_branch']),
        monthId = s(r['month_id']);

  final String feesType, receiptNo, studentId, studentName, enrollmentNo, standard, division;
  final num totalAmount;
  final String receiptDate, paymentMode, bankBranch, monthId;

  String get key => '$receiptNo/$studentId/$feesType';

  /// Receipts paid through the online portal cannot be cancelled from here (same rule as the web).
  bool get cancellable => !(paymentMode == 'Online' && bankBranch.isEmpty);
}

/// A refundable fee head from `POST /api/fees-refund/detail/{id}`.
class RefundHead {
  RefundHead(this.key, this.label, this.paid) : amount = TextEditingController(text: paid.toString());
  final String key, label;
  final num paid;
  final TextEditingController amount;
}

/// State and API calls for Fees Cancel/Refund (same two workflows as the web page).
class FeesCancelRefundController extends ChangeNotifier {
  FeesCancelRefundController({required this.args});
  final ScreenArgs args;
  LegacyApi get _api => args.api;

  bool busy = false;
  String? message;
  bool messageIsError = false;

  void _say(String? text, {bool error = false}) {
    message = text;
    messageIsError = error;
  }

  // ------------------------------ Cancel ------------------------------
  final enrollment = TextEditingController();
  final receiptNo = TextEditingController();
  DateTime? from;
  DateTime? to;

  List<CancelReceipt> receipts = [];
  List<String> cancelTypes = [];
  bool searched = false;
  final selected = <String>{};
  final cancelType = <String, String>{}; // receipt key -> chosen cancel type
  final cancelRemark = <String, TextEditingController>{};

  void setFrom(DateTime? d) {
    from = d;
    notifyListeners();
  }

  void setTo(DateTime? d) {
    to = d;
    notifyListeners();
  }

  Future<void> searchReceipts() async {
    busy = true;
    searched = true;
    receipts = [];
    selected.clear();
    _say(null);
    notifyListeners();
    try {
      final res = await _api.post('/api/fees-cancel/search', body: {
        if (enrollment.text.trim().isNotEmpty) 'enrollment_no': enrollment.text.trim(),
        if (receiptNo.text.trim().isNotEmpty) 'receipt_no': receiptNo.text.trim(),
        if (from != null) 'from_date': ymd(from!),
        if (to != null) 'to_date': ymd(to!),
      });
      if (statusOf(res) != '1') {
        _say(LegacyApi.messageOf(res, 'No fees receipt found. Please search again.'), error: true);
      } else {
        receipts = rows(res['fees_data']).map(CancelReceipt.new).toList();
        final t = res['fees_cancel_type'];
        cancelTypes = (t is List ? t : (t is Map ? t.values.toList() : const [])).map(s).where((e) => e.isNotEmpty).toList();
        _say('Found ${receipts.length} receipt${receipts.length == 1 ? '' : 's'}.');
      }
    } on ApiException catch (e) {
      _say(e.message, error: true);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void toggle(CancelReceipt r) {
    if (!r.cancellable) return;
    selected.contains(r.key) ? selected.remove(r.key) : selected.add(r.key);
    notifyListeners();
  }

  void pickType(CancelReceipt r, String? v) {
    cancelType[r.key] = v ?? '';
    notifyListeners();
  }

  TextEditingController remarkOf(CancelReceipt r) => cancelRemark.putIfAbsent(r.key, TextEditingController.new);

  List<CancelReceipt> get chosen => receipts.where((r) => selected.contains(r.key)).toList();

  num get chosenTotal => chosen.fold<num>(0, (a, r) => a + r.totalAmount);

  /// The same checks the web makes before cancelling; null when OK.
  String? validateCancel() {
    if (chosen.isEmpty) return 'Please select receipt no to cancel fees.';
    for (final r in chosen) {
      if (!r.cancellable) return 'Receipt ${r.receiptNo} cannot be cancelled because it was paid via the Online Portal.';
      if (r.feesType != 'REGULAR') continue;
      if ((cancelType[r.key] ?? '').isEmpty) return 'Please select cancel type for receipt ${r.receiptNo}.';
      if (remarkOf(r).text.trim().isEmpty) return 'Please enter cancel remark for receipt ${r.receiptNo}.';
    }
    return null;
  }

  Future<bool> submitCancel() async {
    busy = true;
    _say(null);
    notifyListeners();
    try {
      final body = <String, dynamic>{'submit': 'Cancel'};
      var i = 0;
      for (final r in chosen) {
        body['receipt_no[${i++}]'] = '${r.receiptNo}####${r.studentId}';
        body['student_id[${r.studentId}]'] = r.studentId;
        body['totAmt[${r.receiptNo}]'] = '${r.totalAmount}';
        body['month_id'] = r.monthId;
        if (r.feesType == 'REGULAR') {
          body['cancel_type[${r.receiptNo}/${r.studentId}]'] = '${cancelType[r.key] ?? ''}/';
          body['cancel_remark[${r.receiptNo}/${r.studentId}]'] = remarkOf(r).text.trim();
        }
      }
      final res = await _api.post('/fees/fees_cancel', body: body);
      if (statusOf(res) != '1') {
        _say(LegacyApi.messageOf(res, "Couldn't cancel selected fees. Try again."), error: true);
        return false;
      }
      final done = selected.toSet();
      receipts = receipts.where((r) => !done.contains(r.key)).toList();
      selected.clear();
      _say(LegacyApi.messageOf(res, 'Fees cancelled successfully.'));
      return true;
    } on ApiException catch (e) {
      _say(e.message, error: true);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  // ------------------------------ Refund ------------------------------
  final refundEnrollment = TextEditingController();
  final refundRemark = TextEditingController();
  static const paymentModes = ['Cash', 'Cheque', 'Bank Transfer'];
  String paymentMode = 'Cash';
  List<Map<String, String>> refundStudents = [];
  Map<String, String>? refundStudent; // student_id, enrollment, name
  List<RefundHead> heads = [];

  void setPaymentMode(String? v) {
    paymentMode = v ?? 'Cash';
    notifyListeners();
  }

  Future<void> searchRefundStudent() async {
    if (refundEnrollment.text.trim().isEmpty) {
      _say('Enter an enrollment number before searching.', error: true);
      notifyListeners();
      return;
    }
    busy = true;
    refundStudent = null;
    heads = [];
    _say(null);
    notifyListeners();
    try {
      final res = await _api.post('/api/fees-refund/search', body: {'enrollment_no': refundEnrollment.text.trim()});
      if (statusOf(res) != '1') {
        refundStudents = [];
        _say(LegacyApi.messageOf(res, 'No refundable fee receipts found.'), error: true);
      } else {
        refundStudents = [
          for (final r in rows(res['fees_data']))
            if (s(r['student_id']).isNotEmpty) {'student_id': s(r['student_id']), 'name': s(r['student_name']), 'enrollment': s(r['enrollment_no'])},
        ];
        _say('Found ${refundStudents.length} student${refundStudents.length == 1 ? '' : 's'}. Select one to load paid fee heads.');
      }
    } on ApiException catch (e) {
      _say(e.message, error: true);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> loadRefundDetail(String id) async {
    busy = true;
    _say(null);
    notifyListeners();
    try {
      final res = await _api.post('/api/fees-refund/detail/$id');
      if (statusOf(res) != '1') {
        _say(LegacyApi.messageOf(res, "Couldn't load refundable fee heads. Try again."), error: true);
      } else {
        final fh = res['fee_heads'];
        heads = [
          if (fh is Map)
            for (final e in fh.entries)
              if (e.value is Map)
                RefundHead('${e.key}', s((e.value as Map)['label']).isEmpty ? '${e.key}' : s((e.value as Map)['label']),
                    num.tryParse(s((e.value as Map)['amount']).replaceAll(',', '')) ?? 0),
        ];
        final st = m(res['student']);
        refundStudent = {
          'student_id': s(st['student_id']).isEmpty ? id : s(st['student_id']),
          'enrollment': s(st['enrollment']),
          'name': s(st['name']),
        };
      }
    } on ApiException catch (e) {
      _say(e.message, error: true);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  num get refundTotal => heads.fold<num>(0, (a, h) => a + (num.tryParse(h.amount.text) ?? 0));

  String? validateRefund() {
    if (refundStudent == null) return 'Select a student first.';
    for (final h in heads) {
      final v = num.tryParse(h.amount.text) ?? 0;
      if (v > h.paid) return '${h.label}: refund cannot be more than the paid amount (${h.paid}).';
    }
    if (refundTotal <= 0) return 'Enter at least one refund amount.';
    return null;
  }

  Future<bool> submitRefund() async {
    final st = refundStudent!;
    busy = true;
    _say(null);
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'student_id': st['student_id'],
        'enrollment': st['enrollment'],
        'PAYMENT_MODE': paymentMode,
        'receiptdate': ymd(DateTime.now()),
        'refund_remark': refundRemark.text.trim(),
        for (final h in heads)
          if ((num.tryParse(h.amount.text) ?? 0) > 0) 'refund_amount[${h.key}]': h.amount.text.trim(),
      };
      final res = await _api.post('/api/fees-refund/save', body: body);
      if (statusOf(res) != '1') {
        _say(LegacyApi.messageOf(res, "Couldn't save refund. Try again."), error: true);
        return false;
      }
      _say(LegacyApi.messageOf(res, 'Fees refund saved successfully.'));
      return true;
    } on ApiException catch (e) {
      _say(e.message, error: true);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    enrollment.dispose();
    receiptNo.dispose();
    refundEnrollment.dispose();
    refundRemark.dispose();
    for (final c in cancelRemark.values) {
      c.dispose();
    }
    for (final h in heads) {
      h.amount.dispose();
    }
    super.dispose();
  }
}
