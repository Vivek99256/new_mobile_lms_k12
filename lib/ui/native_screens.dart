import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_controller.dart';
import '../core/native_target.dart';
import '../core/page_service.dart';
import 'dashboard/dashboard_screen.dart';
import 'sdui/page_renderer.dart';
import 'theme.dart';

PageService? _service(BuildContext context) {
  final auth = context.read<AuthController>();
  final s = auth.session;
  return s == null ? null : PageService(auth.api, s);
}

/// Opens the native screen for [target].
void openTarget(BuildContext context, String title, NativeTarget target) {
  final Widget screen = switch (target.kind) {
    TargetKind.builderPage => NativePageScreen(
      slug: target.value,
      title: title,
    ),
    TargetKind.dynamicPage => DynamicPageScreen(
      pageKey: target.value,
      title: title,
    ),
    TargetKind.dashboard => const DashboardScreen(),
    TargetKind.apiData => DataScreen(
      title: title,
      endpoint: target.value,
      method: target.method,
    ),
  };
  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

class _ScreenFrame extends StatelessWidget {
  const _ScreenFrame({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
    body: child,
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: Brand.muted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------------------
// Mobile Page Builder page
// ---------------------------------------------------------------------------------------

class NativePageScreen extends StatefulWidget {
  const NativePageScreen({super.key, required this.slug, required this.title});
  final String slug;
  final String title;

  @override
  State<NativePageScreen> createState() => _NativePageScreenState();
}

class _NativePageScreenState extends State<NativePageScreen> {
  final _form = FormValues();
  PageService? _svc;
  Map<String, dynamic>? _layout;
  dynamic _data;
  String? _error;
  bool _loading = true;
  ({bool ok, String text})? _banner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final svc = _svc = _service(context);
    if (svc == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await svc.builderPage(widget.slug);
      final layout = Map<String, dynamic>.from(page['layout'] as Map);
      dynamic data;
      final endpoint =
          (((layout['page'] as Map?)?['dataSource']) as Map?)?['endpoint'];
      if (endpoint is String && endpoint.isNotEmpty) {
        try {
          final res = await svc.call(endpoint);
          data = res['data'] ?? res;
        } on ApiException {
          // A missing data source must not blank the page; unbound fields still render.
        }
      }
      if (mounted)
        setState(() => _layout = layout..['__name'] = page['page']?['name']);
      _data = data;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onAction(
    Map<String, dynamic> action,
    Map<String, String> values,
  ) async {
    final type = '${action['type'] ?? 'none'}';
    if (type == 'navigate') {
      _navigate(action['navigate']);
      return;
    }
    if (type != 'api') return;
    final svc = _svc;
    if (svc == null) return;
    try {
      final bodyTemplate = action['body'] is Map
          ? Map<String, dynamic>.from(action['body'] as Map)
          : <String, dynamic>{};
      final body = {
        for (final e in bodyTemplate.entries)
          e.key: resolveTemplate('${e.value}', values),
      };
      await svc.call(
        resolveTemplate('${action['endpoint'] ?? ''}', values),
        method: '${action['method'] ?? 'POST'}',
        body: body,
      );
      if (!mounted) return;
      setState(
        () => _banner = (
          ok: true,
          text: '${action['successMessage'] ?? 'Saved.'}',
        ),
      );
      final onSuccess = action['onSuccess'];
      if (onSuccess is Map) {
        switch ('${onSuccess['type']}') {
          case 'reload':
            await _load();
          case 'goBack':
            if (mounted) Navigator.pop(context);
          case 'navigate':
            _navigate(onSuccess['target']);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _banner = (
            ok: false,
            text: '${action['errorMessage'] ?? e.message}',
          ),
        );
      }
    }
  }

  void _navigate(dynamic target) {
    if (target is! Map) return;
    if (target['kind'] == 'back') {
      Navigator.pop(context);
    } else if (target['slug'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              NativePageScreen(slug: '${target['slug']}', title: widget.title),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    final title = (layout?['__name'] as String?) ?? widget.title;
    return _ScreenFrame(
      title: title,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || layout == null || _svc == null
          ? _Failure(
              message: _error ?? 'This page is not available.',
              onRetry: _load,
            )
          : PageScope(
              form: _form,
              service: _svc!,
              data: _data,
              onAction: _onAction,
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    if (_banner != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        color: _banner!.ok
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF2F2),
                        child: Text(
                          _banner!.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _banner!.ok
                                ? const Color(0xFF047857)
                                : const Color(0xFFB91C1C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    PageRenderer(layout: layout),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------------------
// native_dynamic stat page
// ---------------------------------------------------------------------------------------

String formatIndian(num n, {int decimals = 0}) {
  final negative = n < 0;
  final fixed = n.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  var whole = parts[0];
  if (whole.length > 3) {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    whole = '${groups.join(',')},$last3';
  }
  return '${negative ? '-' : ''}$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String formatTile(dynamic value, String type) {
  if (value == null || '$value'.isEmpty) return '—';
  final n = value is num ? value : num.tryParse('$value');
  if (n == null) return '$value';
  return switch (type) {
    'currency' => '₹${formatIndian(n, decimals: n % 1 == 0 ? 0 : 2)}',
    'percent' => '${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)}%',
    _ => formatIndian(n, decimals: n % 1 == 0 ? 0 : 2),
  };
}

class DynamicPageScreen extends StatefulWidget {
  const DynamicPageScreen({
    super.key,
    required this.pageKey,
    required this.title,
  });
  final String pageKey;
  final String title;

  @override
  State<DynamicPageScreen> createState() => _DynamicPageScreenState();
}

class _DynamicPageScreenState extends State<DynamicPageScreen> {
  Map<String, dynamic>? _page;
  dynamic _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final svc = _service(context);
    if (svc == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await svc.dynamicPage(widget.pageKey);
      final endpoint = '${page['data_endpoint'] ?? ''}';
      final res = endpoint.isEmpty
          ? <String, dynamic>{}
          : await svc.callAuto(endpoint);
      if (mounted) {
        setState(() {
          _page = page;
          _data = res;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final tiles = [
      for (final t in (page?['tiles'] as List? ?? const []))
        if (t is Map) Map<String, dynamic>.from(t),
    ];
    return _ScreenFrame(
      title: '${page?['title'] ?? widget.title}',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _Failure(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                ),
                itemCount: tiles.length,
                itemBuilder: (_, i) {
                  final t = tiles[i];
                  final display = resolveField(
                    _data,
                    '${t['display_key'] ?? ''}',
                  );
                  final raw = resolveField(_data, '${t['field_key'] ?? ''}');
                  final text = display != null && '$display'.isNotEmpty
                      ? '$display'
                      : formatTile(raw, '${t['field_type']}');
                  final drill = t['drill_endpoint'];
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: drill is String && drill.isNotEmpty
                        ? () => openTarget(
                            context,
                            '${t['label']}',
                            NativeTarget.api(drill, method: 'POST'),
                          )
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: Brand.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${t['label']}',
                            style: const TextStyle(
                              color: Brand.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Brand.accent(i).$1,
                              ),
                            ),
                          ),
                          if (drill is String && drill.isNotEmpty)
                            const Align(
                              alignment: Alignment.centerRight,
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: Brand.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------------------
// Generic data screen (role dashboard, API-backed rows, drill-downs)
// ---------------------------------------------------------------------------------------

String humanize(String key) => key
    .replaceAll(RegExp(r'[_\-]+'), ' ')
    .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
    .trim()
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String displayValue(dynamic v) {
  if (v == null || '$v'.isEmpty) return '—';
  if (v is bool) return v ? 'Yes' : 'No';
  if (v is num) return formatIndian(v, decimals: v % 1 == 0 ? 0 : 2);
  return '$v';
}

bool _isScalar(dynamic v) => v == null || v is String || v is num || v is bool;

class DataScreen extends StatefulWidget {
  /// `endpoint == null` means this user's role dashboard.
  const DataScreen({
    super.key,
    required this.title,
    required this.endpoint,
    this.method = 'GET',
    this.loader,
  });
  final String title;
  final String? endpoint;
  final String method;

  /// Custom loader (legacy form-data endpoints); overrides [endpoint].
  final Future<dynamic> Function()? loader;

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  dynamic _data;
  String? _error;
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final svc = _service(context);
    if (svc == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.loader != null) {
        final res = await widget.loader!();
        if (mounted) setState(() => _data = res);
        return;
      }
      final endpoint = widget.endpoint ?? svc.dashboardEndpoint;
      final res = widget.endpoint == null || widget.method == 'POST'
          ? await svc.callAuto(endpoint, preferPost: true)
          : await svc.callAuto(endpoint);
      if (mounted) setState(() => _data = res['data'] ?? res);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final rows = data is List
        ? [
            for (final r in data)
              if (r is Map) Map<String, dynamic>.from(r),
          ]
        : null;
    return _ScreenFrame(
      title: widget.title,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _Failure(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: rows != null ? _rowList(rows) : _sections(data),
            ),
    );
  }

  Widget _rowList(List<Map<String, dynamic>> rows) {
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty
        ? rows
        : rows
              .where(
                (r) => r.values.any(
                  (v) => _isScalar(v) && '$v'.toLowerCase().contains(q),
                ),
              )
              .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (rows.length > 6)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Filter',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No records found.',
                style: TextStyle(color: Brand.muted),
              ),
            ),
          ),
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RowCard(row: shown[i], index: i),
          ),
      ],
    );
  }

  Widget _sections(dynamic data) {
    if (data is! Map) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [Text(displayValue(data))],
      );
    }
    final map = Map<String, dynamic>.from(data);
    const hidden = {'status', 'status_code', 'message', 'token', 'errors'};
    final scalars = [
      for (final e in map.entries)
        if (!hidden.contains(e.key) && _isScalar(e.value) && e.value != null) e,
    ];
    final nested = [
      for (final e in map.entries)
        if (!_isScalar(e.value)) e,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (scalars.isNotEmpty)
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              for (var i = 0; i < scalars.length; i++)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: Brand.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        humanize(scalars[i].key),
                        style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          displayValue(scalars[i].value),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Brand.accent(i).$1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        for (final e in nested) ...[
          const SizedBox(height: 22),
          Text(
            humanize(e.key),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (e.value is List)
            for (var i = 0; i < (e.value as List).length && i < 50; i++)
              if ((e.value as List)[i] is Map)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RowCard(
                    row: Map<String, dynamic>.from((e.value as List)[i] as Map),
                    index: i,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(displayValue((e.value as List)[i])),
                )
          else
            _RowCard(row: Map<String, dynamic>.from(e.value as Map), index: 0),
        ],
        if (scalars.isEmpty && nested.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Nothing to show yet.',
                style: TextStyle(color: Brand.muted),
              ),
            ),
          ),
      ],
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.row, required this.index});
  final Map<String, dynamic> row;
  final int index;

  static const _titleKeys = [
    'name',
    'title',
    'student_name',
    'full_name',
    'subject_name',
    'label',
    'heading',
  ];

  String get _title {
    for (final k in _titleKeys) {
      final v = row[k];
      if (v != null && '$v'.isNotEmpty) return '$v';
    }
    final first = row['first_name'];
    if (first != null)
      return [
        first,
        row['middle_name'],
        row['last_name'],
      ].where((e) => e != null && '$e'.isNotEmpty).join(' ');
    for (final e in row.entries) {
      if (e.value is String &&
          '${e.value}'.isNotEmpty &&
          !e.key.toLowerCase().endsWith('id'))
        return '${e.value}';
    }
    return '#${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final title = _title;
    final fields = [
      for (final e in row.entries)
        if (_isScalar(e.value) &&
            e.value != null &&
            '${e.value}'.isNotEmpty &&
            '${e.value}' != title)
          e,
    ];
    final preview = fields.take(4).toList();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: fields.length > 4 ? () => _showAll(context, title, fields) : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: Brand.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            if (preview.isNotEmpty) const SizedBox(height: 6),
            for (final e in preview)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 118,
                      child: Text(
                        humanize(e.key),
                        style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        displayValue(e.value),
                        style: const TextStyle(fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
            if (fields.length > 4)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Tap for details',
                  style: TextStyle(
                    color: Brand.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAll(
    BuildContext context,
    String title,
    List<MapEntry<String, dynamic>> fields,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final e in fields)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        humanize(e.key),
                        style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        displayValue(e.value),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
