import 'package:flutter_test/flutter_test.dart';
import 'package:new_mobile_lms_k12/screens/kit/kit.dart';

void main() {
  test('web, mail and phone links are allowed', () {
    expect(isSafeLaunchUri(Uri.parse('https://erp.example.in/file.pdf')), isTrue);
    expect(isSafeLaunchUri(Uri.parse('http://erp.example.in/a')), isTrue);
    expect(isSafeLaunchUri(Uri.parse('mailto:office@school.in')), isTrue);
    expect(isSafeLaunchUri(Uri.parse('tel:+911234567890')), isTrue);
  });

  test('script, intent, file and custom schemes are refused', () {
    for (final u in [
      'javascript:alert(1)',
      'intent://scan/#Intent;scheme=zxing;end',
      'file:///data/data/app/secret',
      'content://sms/inbox',
      'market://details?id=evil',
      'myapp://do-something',
    ]) {
      expect(isSafeLaunchUri(Uri.parse(u)), isFalse, reason: u);
    }
  });

  test('credentials in a web url and empty hosts are refused', () {
    expect(isSafeLaunchUri(Uri.parse('https://erp.example.in@evil.test/x')), isFalse);
    expect(isSafeLaunchUri(Uri.parse('https:///nohost')), isFalse);
    expect(isSafeLaunchUri(null), isFalse);
  });
}
