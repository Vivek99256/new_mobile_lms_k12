import 'package:flutter_test/flutter_test.dart';
import 'package:new_mobile_lms_k12/core/api_client.dart';

void main() {
  const base = 'https://erp.example.in';

  test('the ERP host is trusted, case-insensitively', () {
    expect(isTrustedErpHost('erp.example.in', apiBase: base), isTrue);
    expect(isTrustedErpHost('ERP.Example.IN', apiBase: base), isTrue);
  });

  test('lookalike and unrelated hosts are not trusted', () {
    expect(isTrustedErpHost('erp.example.in.evil.net', apiBase: base), isFalse);
    expect(isTrustedErpHost('evil-erp.example.in', apiBase: base), isFalse);
    expect(isTrustedErpHost('attacker.test', apiBase: base), isFalse);
    expect(isTrustedErpHost('', apiBase: base), isFalse);
  });

  test('an unusable api base trusts nothing', () {
    expect(isTrustedErpHost('erp.example.in', apiBase: ''), isFalse);
  });
}
