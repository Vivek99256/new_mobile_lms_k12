import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_controller.dart';
import '../core/config.dart';
import '../core/mobile_auth.dart';
import 'app_version_text.dart';
import 'design.dart';
import 'login_page.dart';
import 'theme.dart';
import 'app_loader.dart';

enum _Step { booting, mobile, otp, createPin, pin, profiles, email }

/// Sign in with a mobile number and an mPIN (or Face ID / fingerprint).
///
/// One number can open several profiles: a teacher whose children study at the same school signs in
/// once and then picks who to open. The first time a number is used (and after a forgotten mPIN) it is
/// proven with an SMS code; after that it is the mPIN, or the phone's biometrics.
class MobileLoginPage extends StatefulWidget {
  const MobileLoginPage({super.key});

  @override
  State<MobileLoginPage> createState() => _MobileLoginPageState();
}

class _MobileLoginPageState extends State<MobileLoginPage> {
  _Step _step = _Step.booting;
  final _mobileCtl = TextEditingController();
  final _otpCtl = TextEditingController();

  String _mobile = '';
  String _pin = '';
  String _firstPin = '';
  String? _setupToken;
  String? _error;
  bool _busy = false;
  bool _confirming = false; // create-mPIN: second entry
  bool _resetting = false; // the code flow was started from "Forgot mPIN"
  bool _viaSms = false; // the code was asked for by SMS (otherwise WhatsApp)

  BiometricKind? _bio;
  bool _hasDevice = false;
  MobileSignIn? _sign;

  int _resendIn = 0;
  Timer? _timer;

  MobileAuthService get _svc => context.read<MobileAuthService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mobileCtl.dispose();
    _otpCtl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- boot

  Future<void> _boot() async {
    final last = await _svc.lastMobile();
    if (!mounted) return;
    if (last != null && RegExp(r'^\d{10}$').hasMatch(last)) {
      _mobile = last;
      _mobileCtl.text = last;
      await _enterPinStep(auto: true);
    } else {
      setState(() => _step = _Step.mobile);
    }
  }

  /// Shows the mPIN keypad for [_mobile]; when biometrics are on for it, asks for them straight away.
  Future<void> _enterPinStep({bool auto = false}) async {
    final bio = await _svc.availableBiometric();
    final token = await _svc.deviceToken(_mobile);
    if (!mounted) return;
    setState(() {
      _bio = bio;
      _hasDevice = bio != null && token != null && token.isNotEmpty;
      _pin = '';
      _error = null;
      _step = _Step.pin;
    });
    if (auto && _hasDevice) _biometricLogin();
  }

  // -------------------------------------------------------------- mobile

  Future<void> _continueMobile() async {
    final m = _mobileCtl.text.replaceAll(RegExp(r'\D'), '');
    if (m.length != 10) {
      setState(() => _error = 'Enter your 10 digit mobile number.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _mobile = m;
    });
    try {
      final state = await _svc.status(m);
      if (!mounted) return;
      if (state == 'pin') {
        await _enterPinStep();
      } else {
        _resetting = false;
        await _startOtp();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ----------------------------------------------------------------- otp

  Future<void> _startOtp({bool sms = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _svc.sendOtp(_mobile, sms: sms);
      if (!mounted) return;
      _otpCtl.clear();
      _startResendTimer();
      setState(() {
        _viaSms = sms;
        _step = _Step.otp;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          if (e.statusCode == 429) {
            _step = _Step.otp;
          }
        });
        if (e.message.startsWith('Please wait a few seconds')) {
          _startResendTimer();
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) t.cancel();
    });
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtl.text.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6 digit code.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await _svc.verifyOtp(_mobile, code);
      if (!mounted) return;
      setState(() {
        _setupToken = token;
        _pin = '';
        _firstPin = '';
        _confirming = false;
        _step = _Step.createPin;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ----------------------------------------------------------------- pin

  void _onDigit(String d) {
    if (_busy || _pin.length >= MobileAuthService.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == MobileAuthService.pinLength) _pinComplete();
  }

  void _onBackspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _pinComplete() async {
    if (_step == _Step.createPin) {
      if (!_confirming) {
        // First entry: remember it and ask again.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _confirming = true;
        });
        return;
      }
      if (_pin != _firstPin) {
        HapticFeedback.heavyImpact();
        setState(() {
          _error = 'The two mPINs do not match. Start again.';
          _pin = '';
          _firstPin = '';
          _confirming = false;
        });
        return;
      }
      await _createPin(_pin);
      return;
    }
    await _pinLogin(_pin);
  }

  Future<void> _createPin(String pin) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sign = await _svc.setPin(_mobile, pin, _setupToken ?? '');
      if (!mounted) return;
      await _afterProof(sign, offerBiometric: true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _pin = '';
          _firstPin = '';
          _confirming = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pinLogin(String pin) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sign = await _svc.pinLogin(_mobile, pin);
      if (!mounted) return;
      await _afterProof(sign, offerBiometric: true);
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _error = e.message;
          _pin = '';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ----------------------------------------------------------- biometrics

  Future<void> _biometricLogin() async {
    final bio = _bio;
    if (bio == null || _busy) return;
    final ok = await _svc.authenticate('Sign in to ${AppConfig.appName}');
    if (!ok || !mounted) return;
    final token = await _svc.deviceToken(_mobile);
    if (token == null || token.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sign = await _svc.deviceLogin(_mobile, token);
      if (!mounted) return;
      await _afterProof(sign, offerBiometric: false);
    } on ApiException catch (e) {
      // The server no longer trusts this phone (mPIN was reset, or it was removed): use the mPIN.
      await _svc.clearDeviceToken(_mobile);
      if (mounted) {
        setState(() {
          _hasDevice = false;
          _error = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Offers to turn biometrics on, once, right after a successful mPIN sign-in.
  Future<void> _maybeOfferBiometric(MobileSignIn sign) async {
    final bio = await _svc.availableBiometric();
    if (bio == null || !mounted) return;
    if (await _svc.deviceToken(_mobile) != null ||
        await _svc.biometricDeclined(_mobile))
      return;
    if (!mounted) return;
    final enable = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (_) => _BiometricOffer(kind: bio),
    );
    if (enable != true) {
      await _svc.declineBiometric(_mobile);
      return;
    }
    if (!await _svc.authenticate('Confirm to turn on ${bio.label}')) return;
    try {
      final token = await _svc.registerDevice(sign.ticket);
      if (token.isNotEmpty) await _svc.saveDeviceToken(_mobile, token);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  // ------------------------------------------------------------ profiles

  Future<void> _afterProof(
    MobileSignIn sign, {
    required bool offerBiometric,
  }) async {
    await _svc.saveLastMobile(_mobile);
    if (offerBiometric) await _maybeOfferBiometric(sign);
    if (!mounted) return;
    if (sign.profiles.length == 1) {
      await _select(sign, sign.profiles.first);
    } else {
      setState(() {
        _sign = sign;
        _step = _Step.profiles;
        _error = null;
      });
    }
  }

  Future<void> _select(MobileSignIn sign, MobileProfile p) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await context.read<AuthController>().signInWithProfile(
      sign.ticket,
      p.key,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
        // An expired ticket needs the mPIN again; a refused profile can simply be retried.
        if (err.toLowerCase().contains('expired')) _step = _Step.pin;
      });
    }
    // On success the app swaps this screen for Home.
  }

  // ------------------------------------------------------------ navigation

  void _changeNumber() {
    _svc.forgetLastMobile();
    setState(() {
      _mobileCtl.clear();
      _mobile = '';
      _pin = '';
      _error = null;
      _hasDevice = false;
      _step = _Step.mobile;
    });
  }

  void _forgotPin() {
    _resetting = true;
    _startOtp();
  }

  void _back() {
    setState(() {
      _error = null;
      _pin = '';
      switch (_step) {
        case _Step.otp:
          _step = _resetting ? _Step.pin : _Step.mobile;
        case _Step.createPin:
          _step = _Step.otp;
        case _Step.profiles:
          _step = _Step.pin;
        case _Step.email:
          _step = _Step.mobile;
        default:
          break;
      }
    });
  }

  // ----------------------------------------------------------------- build

  String get _masked => _mobile.length == 10
      ? '+91 ${_mobile.substring(0, 2)}XXX XXX${_mobile.substring(8)}'
      : '';

  ({String title, String sub}) get _heading => switch (_step) {
    _Step.mobile => (
      title: 'Welcome',
      sub: 'Enter your mobile number to continue.',
    ),
    _Step.otp => (
      title: 'Verify your number',
      sub: _viaSms
          ? 'If this number is registered, check SMS for a code sent to $_masked.'
          : 'If this number is registered, check WhatsApp first. SMS may be used if WhatsApp delivery is unavailable. $_masked.',
    ),
    _Step.createPin => (
      title: _confirming ? 'Confirm your mPIN' : 'Create your mPIN',
      sub: _confirming
          ? 'Enter the same ${MobileAuthService.pinLength} digits again.'
          : 'Choose ${MobileAuthService.pinLength} digits you will remember.',
    ),
    _Step.pin => (title: 'Enter your mPIN', sub: _masked),
    _Step.profiles => (
      title: 'Who is signing in?',
      sub: 'This number has more than one profile.',
    ),
    _ => (title: 'Welcome', sub: ''),
  };

  @override
  Widget build(BuildContext context) {
    if (_step == _Step.email) {
      return LoginPage(onUseMobile: _back);
    }
    final h = _heading;
    final canLeave =
        _step == _Step.mobile || _step == _Step.pin || _step == _Step.booting;
    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Brand.navy,
          resizeToAvoidBottomInset: true,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  28,
                  MediaQuery.paddingOf(context).top + 22,
                  28,
                  22,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const LogoTile(),
                        const Spacer(),
                        if (!canLeave)
                          IconButton(
                            onPressed: _busy ? null : _back,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                            tooltip: 'Back',
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppConfig.appName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -.2,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Brand.card,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: _step == _Step.booting
                      ? const AppLoader()
                      : SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            24,
                            28,
                            24,
                            24 + MediaQuery.paddingOf(context).bottom,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                              key: ValueKey('$_step$_confirming'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    h.title,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Brand.ink,
                                    ),
                                  ),
                                  if (h.sub.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      h.sub,
                                      style: TextStyle(
                                        color: Brand.ink2,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  if (_error != null) _ErrorBanner(_error!),
                                  _body(),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() => switch (_step) {
    _Step.mobile => _mobileBody(),
    _Step.otp => _otpBody(),
    _Step.createPin || _Step.pin => _pinBody(),
    _Step.profiles => _profilesBody(),
    _ => const SizedBox.shrink(),
  };

  Widget _mobileBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _mobileCtl,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumberNational],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _continueMobile(),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
        decoration: InputDecoration(
          labelText: 'Mobile number',
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: 16, right: 8),
            child: Center(
              widthFactor: 1,
              child: Text(
                '+91',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Brand.ink2,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _busy ? null : _continueMobile,
        child: _busy ? const _Spinner() : const Text('Continue'),
      ),
      const SizedBox(height: 14),
      TextButton(
        onPressed: _busy ? null : () => setState(() => _step = _Step.email),
        child: const Text('Sign in with email and password instead'),
      ),
      const SizedBox(height: 10),
      Text(
        'One number can open a teacher and children profiles. You will choose who to open after you sign in.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, height: 1.4, color: Brand.ink3),
      ),
      const AppVersionText(),
    ],
  );

  Widget _otpBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _otpCtl,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        textAlign: TextAlign.center,
        onSubmitted: (_) => _verifyOtp(),
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: 10,
        ),
        decoration: const InputDecoration(labelText: '6 digit code'),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _busy ? null : _verifyOtp,
        child: _busy ? const _Spinner() : const Text('Verify'),
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: _busy || _resendIn > 0
            ? null
            : () => _startOtp(sms: _viaSms),
        child: Text(
          _resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code',
        ),
      ),
      if (!_viaSms)
        TextButton(
          onPressed: _busy || _resendIn > 0 ? null : () => _startOtp(sms: true),
          child: const Text('Send the code by SMS instead'),
        ),
      TextButton(
        onPressed: _busy ? null : _changeNumber,
        child: const Text('Use a different number'),
      ),
    ],
  );

  Widget _pinBody() {
    final creating = _step == _Step.createPin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        _PinDots(
          filled: _pin.length,
          total: MobileAuthService.pinLength,
          busy: _busy,
        ),
        const SizedBox(height: 24),
        _Keypad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          biometric: !creating && _hasDevice ? _bio : null,
          onBiometric: _biometricLogin,
        ),
        const SizedBox(height: 14),
        if (!creating) ...[
          TextButton(
            onPressed: _busy ? null : _forgotPin,
            child: const Text('Forgot mPIN?'),
          ),
          TextButton(
            onPressed: _busy ? null : _changeNumber,
            child: const Text('Not you? Use a different number'),
          ),
        ],
      ],
    );
  }

  Widget _profilesBody() {
    final sign = _sign;
    if (sign == null) return const SizedBox.shrink();
    final staff = sign.profiles.where((p) => !p.isStudent).toList();
    final kids = sign.profiles.where((p) => p.isStudent).toList();
    Widget group(String title, List<MobileProfile> list) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 0, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: Brand.ink3,
            ),
          ),
        ),
        for (final p in list)
          _ProfileCard(profile: p, busy: _busy, onTap: () => _select(sign, p)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (staff.isNotEmpty)
          group(staff.length == 1 ? 'Staff' : 'Staff profiles', staff),
        if (staff.isNotEmpty && kids.isNotEmpty) const SizedBox(height: 10),
        if (kids.isNotEmpty)
          group(kids.length == 1 ? 'Child' : 'Children', kids),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: const AppLoader(),
          ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Brand.err0,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFCA5A5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: Brand.err),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Brand.err,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The four dots that fill as the mPIN is typed.
class _PinDots extends StatelessWidget {
  const _PinDots({
    required this.filled,
    required this.total,
    required this.busy,
  });
  final int filled, total;
  final bool busy;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$filled of $total digits entered',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 9),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled
                  ? (busy ? Brand.ink3 : Brand.primary)
                  : Colors.transparent,
              border: Border.all(
                color: i < filled
                    ? (busy ? Brand.ink3 : Brand.primary)
                    : Brand.border,
                width: 2,
              ),
            ),
          ),
      ],
    ),
  );
}

/// A numeric keypad; the lower-left key is the biometric button when biometrics are on.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.biometric,
    required this.onBiometric,
  });
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace, onBiometric;
  final BiometricKind? biometric;

  Widget _key(Widget child, VoidCallback? onTap, String label) => Semantics(
    button: true,
    label: label,
    child: InkResponse(
      onTap: onTap,
      radius: 40,
      child: Container(
        width: 74,
        height: 74,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap == null ? Colors.transparent : Brand.surface,
        ),
        child: child,
      ),
    ),
  );

  Widget _digit(String d) => _key(
    Text(
      d,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: Brand.ink,
      ),
    ),
    () => onDigit(d),
    d,
  );

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> keys) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys,
      ),
    );
    final bio = biometric;
    return Column(
      children: [
        row([_digit('1'), _digit('2'), _digit('3')]),
        row([_digit('4'), _digit('5'), _digit('6')]),
        row([_digit('7'), _digit('8'), _digit('9')]),
        row([
          bio == null
              ? const SizedBox(width: 74, height: 74)
              : _key(
                  Icon(
                    bio == BiometricKind.face
                        ? Icons.face_retouching_natural_rounded
                        : Icons.fingerprint_rounded,
                    size: 32,
                    color: Brand.primary,
                  ),
                  onBiometric,
                  'Sign in with ${bio.label}',
                ),
          _digit('0'),
          _key(
            Icon(Icons.backspace_outlined, size: 24, color: Brand.ink2),
            onBackspace,
            'Delete',
          ),
        ]),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.onTap,
    required this.busy,
  });
  final MobileProfile profile;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final student = profile.isStudent;
    final accent = student ? const Color(0xFF0EA5E9) : Brand.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Brand.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Brand.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent.withValues(alpha: 0.85), accent],
                    ),
                  ),
                  child: Text(
                    profile.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Brand.ink,
                        ),
                      ),
                      if (profile.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          profile.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ],
                      if (profile.school.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          profile.school,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Brand.ink3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Brand.ink3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The one-time "turn on Face ID / fingerprint?" offer.
class _BiometricOffer extends StatelessWidget {
  const _BiometricOffer({required this.kind});
  final BiometricKind kind;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      4,
      24,
      24 + MediaQuery.paddingOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Brand.tint,
          ),
          child: Icon(
            kind == BiometricKind.face
                ? Icons.face_retouching_natural_rounded
                : Icons.fingerprint_rounded,
            size: 34,
            color: Brand.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Turn on ${kind.label}?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Brand.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Next time, sign in with ${kind.label} instead of typing your mPIN. You can always use your mPIN.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Brand.ink2, height: 1.4),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Turn on ${kind.label}'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
      ],
    ),
  );
}
