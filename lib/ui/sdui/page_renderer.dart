import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/page_service.dart';
import '../theme.dart';

/// Current value of every input on a page, by field key. Search fields and list rows share
/// it exactly as lms_k12's renderer does (rows are namespaced `<listId>.<itemId>`).
class FormValues extends ChangeNotifier {
  final Map<String, String> values = {};

  String? operator [](String key) => values[key];

  void set(String key, String value) {
    if (key.isEmpty || values[key] == value) return;
    values[key] = value;
    notifyListeners();
  }

  /// Seeds a value without overwriting what the user already typed.
  void seed(String key, String value) {
    if (key.isEmpty || values.containsKey(key) || value.isEmpty) return;
    values[key] = value;
    notifyListeners();
  }
}

typedef ActionHandler =
    Future<void> Function(
      Map<String, dynamic> action,
      Map<String, String> values,
    );

class PageScope extends InheritedWidget {
  const PageScope({
    super.key,
    required this.form,
    required this.service,
    required this.data,
    required this.onAction,
    required super.child,
  });

  final FormValues form;
  final PageService service;
  final dynamic data;
  final ActionHandler onAction;

  static PageScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageScope>()!;

  @override
  bool updateShouldNotify(PageScope old) =>
      old.data != data || old.form != form;
}

// ---------------------------------------------------------------------------------------
// Helpers over the loosely typed layout JSON.
// ---------------------------------------------------------------------------------------

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};
List<dynamic> _list(dynamic v) => v is List ? v : const [];
String _str(dynamic v, [String fallback = '']) => v == null ? fallback : '$v';
double? _num(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

Color? parseColor(dynamic v) {
  final s = _str(v).trim();
  if (!s.startsWith('#')) return null;
  var hex = s.substring(1);
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length == 6) hex = 'FF$hex';
  final n = int.tryParse(hex, radix: 16);
  return n == null ? null : Color(n);
}

class _Node {
  _Node(Map<String, dynamic> j)
    : type = _str(j['type']),
      id = _str(j['id']),
      props = _map(j['props']),
      x = _num(_map(j['position'])['x']) ?? 0,
      y = _num(_map(j['position'])['y']) ?? 0,
      w = _num(_map(j['size'])['width']),
      h = _num(_map(j['size'])['height']),
      children = [
        for (final c in _list(j['children']))
          if (c is Map) _Node(Map<String, dynamic>.from(c)),
      ];

  final String type;
  final String id;
  final Map<String, dynamic> props;
  final double x, y;
  final double? w, h;
  final List<_Node> children;
}

// ---------------------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------------------

/// Renders a Mobile Page Builder layout as real Flutter widgets.
class PageRenderer extends StatelessWidget {
  const PageRenderer({super.key, required this.layout});
  final Map<String, dynamic> layout;

  @override
  Widget build(BuildContext context) {
    final nodes = [
      for (final c in _list(layout['components']))
        if (c is Map) _Node(Map<String, dynamic>.from(c)),
    ];
    final bg = parseColor(_map(_map(layout['page'])['background'])['color']);
    return Container(
      color: bg,
      padding: const EdgeInsets.all(16),
      child: _Flow(nodes: nodes, direction: Axis.vertical, gap: 12),
    );
  }
}

/// Lays absolutely-positioned design nodes out as a flow: sorted top-to-bottom, with nodes
/// that share a band of the canvas (same row on the design) placed side by side.
class _Flow extends StatelessWidget {
  const _Flow({required this.nodes, required this.direction, this.gap = 12});
  final List<_Node> nodes;
  final Axis direction;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) return const SizedBox.shrink();
    final sorted = [...nodes]
      ..sort((a, b) => a.y != b.y ? a.y.compareTo(b.y) : a.x.compareTo(b.x));

    if (direction == Axis.horizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              flex: ((sorted[i].w ?? 100).round()).clamp(1, 1000),
              child: _NodeView(node: sorted[i]),
            ),
          ],
        ],
      );
    }

    // Group nodes whose vertical extents overlap into one row.
    final rows = <List<_Node>>[];
    double rowBottom = double.negativeInfinity;
    for (final n in sorted) {
      if (rows.isNotEmpty && n.y < rowBottom - 1) {
        rows.last.add(n);
        rowBottom = rowBottom > n.y + (n.h ?? 40)
            ? rowBottom
            : n.y + (n.h ?? 40);
      } else {
        rows.add([n]);
        rowBottom = n.y + (n.h ?? 40);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          if (rows[i].length == 1)
            _NodeView(node: rows[i].first)
          else
            _Flow(
              nodes: rows[i]..sort((a, b) => a.x.compareTo(b.x)),
              direction: Axis.horizontal,
              gap: 8,
            ),
        ],
      ],
    );
  }
}

class _NodeView extends StatelessWidget {
  const _NodeView({required this.node});
  final _Node node;

  @override
  Widget build(BuildContext context) {
    switch (node.type) {
      case 'text':
      case 'heading':
        return _TextBlock(node: node);
      case 'image':
        return _ImageBlock(node: node);
      case 'divider':
        return Divider(
          height: 1,
          thickness: (_num(node.props['thickness']) ?? 1),
          color: parseColor(node.props['color']) ?? const Color(0xFFE5E7EB),
        );
      case 'spacer':
        return SizedBox(height: node.h ?? 16);
      case 'input':
        return _InputBlock(node: node);
      case 'button':
        return _ButtonBlock(node: node);
      case 'container':
      case 'card':
        return _ContainerBlock(node: node);
      case 'list':
        return _ListBlock(node: node);
      default:
        // A component type this version does not know: show its children, never crash.
        return node.children.isEmpty
            ? const SizedBox.shrink()
            : _Flow(nodes: node.children, direction: Axis.vertical);
    }
  }
}

// ---------------------------------------------------------------------------------------
// Blocks
// ---------------------------------------------------------------------------------------

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.node});
  final _Node node;

  @override
  Widget build(BuildContext context) {
    final p = node.props;
    final bound = resolveField(
      PageScope.of(context).data,
      _str(_map(p['dataBinding'])['field']),
    );
    final text = bound != null ? '$bound' : _str(p['content']);
    final variant = _str(p['variant'], 'body');
    final base = _num(p['fontSize']) ?? 16;
    final size = variant == 'h1'
        ? (base < 28 ? 28.0 : base)
        : variant == 'h2'
        ? (base < 20 ? 20.0 : base)
        : base;
    final bold = variant != 'body' || _str(p['fontWeight']) == 'bold';
    final align = switch (_str(p['alignment'])) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: parseColor(p['color']) ?? Brand.text,
        height: 1.3,
      ),
    );
  }
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({required this.node});
  final _Node node;

  @override
  Widget build(BuildContext context) {
    final p = node.props;
    final bound = resolveField(
      PageScope.of(context).data,
      _str(_map(p['dataBinding'])['field']),
    );
    final src = bound != null ? '$bound' : _str(p['src']);
    final fit = _str(p['objectFit']) == 'contain'
        ? BoxFit.contain
        : BoxFit.cover;
    final placeholder = Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFFCBD5E1)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(_num(p['borderRadius']) ?? 0),
      child: SizedBox(
        height: node.h ?? 160,
        width: double.infinity,
        child: src.isEmpty
            ? placeholder
            : Image.network(
                src,
                fit: fit,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _ContainerBlock extends StatelessWidget {
  const _ContainerBlock({required this.node});
  final _Node node;

  @override
  Widget build(BuildContext context) {
    final p = node.props;
    final border = _num(p['borderWidth']) ?? 0;
    return Container(
      padding: EdgeInsets.all(_num(p['padding']) ?? 0),
      decoration: BoxDecoration(
        color:
            parseColor(p['backgroundColor']) ??
            (node.type == 'card' ? Colors.white : null),
        borderRadius: BorderRadius.circular(
          _num(p['borderRadius']) ?? (node.type == 'card' ? 12 : 0),
        ),
        border: border > 0
            ? Border.all(
                color: parseColor(p['borderColor']) ?? Brand.border,
                width: border,
              )
            : null,
      ),
      child: _Flow(
        nodes: node.children,
        direction: _str(p['direction']) == 'row'
            ? Axis.horizontal
            : Axis.vertical,
        gap: _num(p['gap']) ?? 8,
      ),
    );
  }
}

class _ButtonBlock extends StatefulWidget {
  const _ButtonBlock({required this.node});
  final _Node node;

  @override
  State<_ButtonBlock> createState() => _ButtonBlockState();
}

class _ButtonBlockState extends State<_ButtonBlock> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.node.props;
    final scope = PageScope.of(context);
    final action = _map(p['action']);
    final bg = parseColor(p['backgroundColor']) ?? const Color(0xFF0D6EFD);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: parseColor(p['color']) ?? Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_num(p['borderRadius']) ?? 12),
        ),
      ),
      onPressed: _busy || _str(action['type'], 'none') == 'none'
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await scope.onAction(
                  action,
                  Map<String, String>.from(scope.form.values),
                );
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      child: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(_str(p['label'], 'Button')),
    );
  }
}

// ---- inputs ---------------------------------------------------------------------------

class SelectOption {
  SelectOption(this.value, this.label);
  final String value;
  final String label;
}

List<SelectOption> parseOptions(dynamic raw) => [
  for (final o in _list(raw))
    if (o is Map &&
        (o['value'] ?? o['id']) != null &&
        (o['label'] ?? o['name']) != null)
      SelectOption('${o['value'] ?? o['id']}', '${o['label'] ?? o['name']}'),
];

/// Static options, replaced by a live list when `optionsSource` loads.
class _OptionsLoader extends StatefulWidget {
  const _OptionsLoader({
    required this.staticOptions,
    required this.source,
    required this.builder,
  });
  final List<SelectOption> staticOptions;
  final Map<String, dynamic> source;
  final Widget Function(List<SelectOption>) builder;

  @override
  State<_OptionsLoader> createState() => _OptionsLoaderState();
}

class _OptionsLoaderState extends State<_OptionsLoader> {
  List<SelectOption>? _fetched;

  @override
  void initState() {
    super.initState();
    final endpoint = _str(widget.source['endpoint']);
    if (endpoint.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final res = await PageScope.of(context).service.call(endpoint);
          final rows = resolveField(res, _str(widget.source['path'], 'data'));
          final opts = parseOptions(rows);
          if (mounted && opts.isNotEmpty) setState(() => _fetched = opts);
        } on ApiException {
          // keep the static options
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(_fetched ?? widget.staticOptions);
}

class _InputBlock extends StatefulWidget {
  const _InputBlock({required this.node});
  final _Node node;

  @override
  State<_InputBlock> createState() => _InputBlockState();
}

class _InputBlockState extends State<_InputBlock> {
  final _controller = TextEditingController();
  bool _seeded = false;

  String get _field => _str(widget.node.props['field']);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final scope = PageScope.of(context);
    final bound = resolveField(
      scope.data,
      _str(_map(widget.node.props['dataBinding'])['field']),
    );
    final initial =
        scope.form[_field] ??
        (bound != null ? '$bound' : _str(widget.node.props['defaultValue']));
    _controller.text = initial;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scope.form.seed(_field, initial),
    );
  }

  Future<void> _pick(String type) async {
    final form = PageScope.of(context).form;
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    String result = '';
    if (type == 'time') {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now),
      );
      if (t != null) result = '${two(t.hour)}:${two(t.minute)}';
    } else {
      final d = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(1950),
        lastDate: DateTime(2100),
      );
      if (d == null) return;
      result = '${d.year}-${two(d.month)}-${two(d.day)}';
      if (type == 'datetime-local' || type == 'datetime') {
        if (!mounted) return;
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(now),
        );
        if (t != null) result = '${result}T${two(t.hour)}:${two(t.minute)}';
      }
    }
    if (result.isEmpty) return;
    _controller.text = result;
    form.set(_field, result);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.node.props;
    final form = PageScope.of(context).form;
    final type = _str(p['inputType'], 'text');
    final label = _str(p['label']);
    final required = p['required'] == true;
    final decoration = InputDecoration(
      labelText: label.isEmpty ? null : (required ? '$label *' : label),
      hintText: _str(p['placeholder']),
      helperText: _str(p['helpText']).isEmpty ? null : _str(p['helpText']),
    );

    if (type == 'select') {
      return _OptionsLoader(
        staticOptions: parseOptions(p['options']),
        source: _map(p['optionsSource']),
        builder: (options) => ListenableBuilder(
          listenable: form,
          builder: (_, _) {
            final value = form[_field];
            return DropdownButtonFormField<String>(
              initialValue: options.any((o) => o.value == value) ? value : null,
              isExpanded: true,
              decoration: decoration,
              items: [
                for (final o in options)
                  DropdownMenuItem(
                    value: o.value,
                    child: Text(o.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => form.set(_field, v ?? ''),
            );
          },
        ),
      );
    }

    if (type == 'checkbox' || type == 'switch') {
      return ListenableBuilder(
        listenable: form,
        builder: (_, _) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: form[_field] == '1',
          onChanged: (v) => form.set(_field, v ? '1' : '0'),
        ),
      );
    }

    if (const {'date', 'time', 'datetime-local', 'datetime'}.contains(type)) {
      return TextField(
        controller: _controller,
        readOnly: true,
        decoration: decoration.copyWith(
          suffixIcon: Icon(
            type == 'time' ? Icons.access_time : Icons.calendar_today_outlined,
            size: 20,
          ),
        ),
        onTap: () => _pick(type),
      );
    }

    final keyboard = switch (type) {
      'number' => TextInputType.number,
      'email' => TextInputType.emailAddress,
      'tel' || 'phone' => TextInputType.phone,
      'textarea' => TextInputType.multiline,
      _ => TextInputType.text,
    };
    return TextField(
      controller: _controller,
      keyboardType: keyboard,
      obscureText: type == 'password',
      minLines: type == 'textarea' ? 3 : 1,
      maxLines: type == 'textarea' ? 6 : 1,
      readOnly: p['readOnly'] == true,
      decoration: decoration,
      onChanged: (v) => form.set(_field, v),
    );
  }
}

// ---- list: search, rows, save -----------------------------------------------------------

class _ListBlock extends StatefulWidget {
  const _ListBlock({required this.node});
  final _Node node;

  @override
  State<_ListBlock> createState() => _ListBlockState();
}

class _ListBlockState extends State<_ListBlock> {
  List<Map<String, dynamic>> _items = [];
  bool _searching = false;
  bool _searched = false;
  bool _saving = false;
  String? _error;

  Map<String, dynamic> get _p => widget.node.props;
  String get _itemId => _str(_p['itemIdField'], 'id');
  Map<String, dynamic> get _rowControl => _p['rowControl'] is Map
      ? _map(_p['rowControl'])
      : {
          'type': 'toggle',
          'trueLabel': 'Yes',
          'trueValue': '1',
          'falseLabel': 'No',
          'falseValue': '0',
        };

  String _rowKey(String id, [String? suffix]) =>
      '${widget.node.id}.$id${suffix == null ? '' : '.$suffix'}';

  /// "first_name last_name" joins several fields into one label.
  String _label(Map<String, dynamic> item, String spec) => spec
      .split(RegExp(r'\s+'))
      .where((k) => k.isNotEmpty)
      .map((k) => item[k])
      .where((v) => v != null && '$v'.isNotEmpty)
      .join(' ');

  Future<void> _search() async {
    final scope = PageScope.of(context);
    final action = _map(_p['searchAction']);
    final endpoint = _str(action['endpoint']);
    if (endpoint.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final values = Map<String, String>.from(scope.form.values);
      final searchBody = _p['searchBody'];
      final body = searchBody is Map
          ? {
              for (final e in searchBody.entries)
                '${e.key}': resolveTemplate('${e.value}', values),
            }
          : {
              for (final f in _list(_p['searchFields']))
                _str(_map(f)['key']): values[_str(_map(f)['key'])] ?? '',
            };
      final res = await scope.service.call(
        resolveTemplate(endpoint, values),
        method: _str(action['method'], 'POST'),
        body: body,
      );
      final rows = resolveField(res, _str(_p['itemsPath'], 'data'));
      final list = [
        for (final r in _list(rows))
          if (r is Map) Map<String, dynamic>.from(r),
      ];
      final rc = _rowControl;
      for (final item in list) {
        final id = _str(item[_itemId]);
        if (id.isEmpty) continue;
        if (_str(rc['type']) == 'toggle') {
          scope.form.seed(_rowKey(id), _str(rc['trueValue'], '1'));
        } else if (_str(rc['type']) == 'checkbox_amount') {
          final max = rc['maxField'] == null
              ? null
              : item[_str(rc['maxField'])];
          scope.form.seed(_rowKey(id, 'amount'), max != null ? '$max' : '0');
        }
      }
      if (mounted) {
        setState(() {
          _items = list;
          _searched = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    final scope = PageScope.of(context);
    final submit = _map(_p['submitAction']);
    if (_str(submit['endpoint']).isEmpty) return;
    setState(() => _saving = true);
    try {
      final rc = _rowControl;
      final rowBody = <String, dynamic>{};
      for (final item in _items) {
        final id = _str(item[_itemId]);
        if (id.isEmpty) continue;
        // Unchecked checkbox_amount rows contribute nothing, like an unticked HTML checkbox.
        final included =
            _str(rc['type']) != 'checkbox_amount' ||
            scope.form[_rowKey(id, 'checked')] == '1';
        if (!included) continue;
        for (final rk in _list(submit['rowKeys'])) {
          final k = _map(rk);
          final key = _str(k['key']).replaceAll('{itemId}', id);
          final source = _str(k['source']);
          rowBody[key] = switch (source) {
            'value' => scope.form[_rowKey(id)] ?? '',
            'checked' => 'on',
            'amount' => scope.form[_rowKey(id, 'amount')] ?? '',
            _ => _str(item[source]),
          };
        }
      }
      await scope.onAction({
        'type': 'api',
        'method': _str(submit['method'], 'POST'),
        'endpoint': submit['endpoint'],
        'body': {...rowBody, ..._map(submit['extraBody'])},
        'successMessage': submit['successMessage'],
        'errorMessage': submit['errorMessage'],
        'onSuccess': submit['onSuccess'],
      }, Map<String, String>.from(scope.form.values));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = PageScope.of(context).form;
    final searchFields = _list(_p['searchFields']);
    final title = _str(_p['listTitle']);
    final hasSubmit = _str(_map(_p['submitAction'])['endpoint']).isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Brand.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          for (final f in searchFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SearchField(field: _map(f)),
            ),
          if (searchFields.isNotEmpty ||
              _str(_map(_p['searchAction'])['endpoint']).isNotEmpty)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: _searching ? null : _search,
              child: Text(_searching ? 'Searching…' : 'Search'),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
              ),
            ),
          const SizedBox(height: 10),
          if (!_searched)
            const Text(
              'Search to load records.',
              style: TextStyle(color: Brand.muted, fontSize: 13),
            )
          else if (_items.isEmpty)
            const Text(
              'No records found.',
              style: TextStyle(color: Brand.muted, fontSize: 13),
            )
          else
            ListenableBuilder(
              listenable: form,
              builder: (_, _) => Column(
                children: [
                  for (final item in _items)
                    _RowView(
                      label: _label(
                        item,
                        _str(_p['itemLabelField'], 'name'),
                      ).ifEmpty(_str(item[_itemId])),
                      subLabel: _p['itemSubLabelField'] == null
                          ? null
                          : _label(item, _str(_p['itemSubLabelField'])),
                      control: _rowControl,
                      id: _str(item[_itemId]),
                      keyOf: _rowKey,
                      max:
                          _str(_rowControl['type']) == 'checkbox_amount' &&
                              _rowControl['maxField'] != null
                          ? _str(item[_str(_rowControl['maxField'])])
                          : null,
                    ),
                ],
              ),
            ),
          if (hasSubmit && _items.isNotEmpty) ...[
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D6EFD),
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.field});
  final Map<String, dynamic> field;

  @override
  Widget build(BuildContext context) {
    final form = PageScope.of(context).form;
    final key = _str(field['key']);
    final type = _str(field['inputType'], 'text');
    final decoration = InputDecoration(
      labelText: _str(field['label']),
      hintText: _str(field['placeholder']),
    );

    if (type == 'select') {
      return _OptionsLoader(
        staticOptions: parseOptions(field['options']),
        source: _map(field['optionsSource']),
        builder: (options) => ListenableBuilder(
          listenable: form,
          builder: (_, _) => DropdownButtonFormField<String>(
            initialValue: options.any((o) => o.value == form[key])
                ? form[key]
                : null,
            isExpanded: true,
            decoration: decoration,
            items: [
              for (final o in options)
                DropdownMenuItem(
                  value: o.value,
                  child: Text(o.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => form.set(key, v ?? ''),
          ),
        ),
      );
    }
    if (type == 'date') {
      return _DateField(fieldKey: key, decoration: decoration);
    }
    return TextField(
      keyboardType: type == 'number'
          ? TextInputType.number
          : (type == 'email' ? TextInputType.emailAddress : TextInputType.text),
      decoration: decoration,
      controller: TextEditingController(text: form[key] ?? '')
        ..selection = TextSelection.collapsed(offset: (form[key] ?? '').length),
      onChanged: (v) => form.set(key, v),
    );
  }
}

class _DateField extends StatefulWidget {
  const _DateField({required this.fieldKey, required this.decoration});
  final String fieldKey;
  final InputDecoration decoration;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = PageScope.of(context).form;
    _c.text = form[widget.fieldKey] ?? '';
    return TextField(
      controller: _c,
      readOnly: true,
      decoration: widget.decoration.copyWith(
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
      ),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
        );
        if (d == null) return;
        String two(int n) => n.toString().padLeft(2, '0');
        final v = '${d.year}-${two(d.month)}-${two(d.day)}';
        _c.text = v;
        form.set(widget.fieldKey, v);
      },
    );
  }
}

class _RowView extends StatelessWidget {
  const _RowView({
    required this.label,
    required this.subLabel,
    required this.control,
    required this.id,
    required this.keyOf,
    required this.max,
  });

  final String label;
  final String? subLabel;
  final Map<String, dynamic> control;
  final String id;
  final String Function(String id, [String? suffix]) keyOf;
  final String? max;

  @override
  Widget build(BuildContext context) {
    final form = PageScope.of(context).form;
    final type = _str(control['type']);
    final value = form[keyOf(id)] ?? '';

    Widget trailing;
    if (type == 'toggle') {
      final tv = _str(control['trueValue'], '1');
      final fv = _str(control['falseValue'], '0');
      Widget chip(String text, String v, Color on) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: ChoiceChip(
          label: Text(
            text,
            style: TextStyle(
              color: value == v ? Colors.white : Brand.muted,
              fontSize: 12,
            ),
          ),
          selected: value == v,
          selectedColor: on,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => form.set(keyOf(id), v),
        ),
      );
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chip(_str(control['trueLabel'], 'Yes'), tv, const Color(0xFF059669)),
          chip(_str(control['falseLabel'], 'No'), fv, const Color(0xFFDC2626)),
        ],
      );
    } else if (type == 'checkbox_amount') {
      final checked = form[keyOf(id, 'checked')] == '1';
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: checked,
            onChanged: (v) =>
                form.set(keyOf(id, 'checked'), v == true ? '1' : ''),
          ),
          SizedBox(
            width: 84,
            child: TextField(
              enabled: checked,
              keyboardType: TextInputType.number,
              controller:
                  TextEditingController(text: form[keyOf(id, 'amount')] ?? '')
                    ..selection = TextSelection.collapsed(
                      offset: (form[keyOf(id, 'amount')] ?? '').length,
                    ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.all(10),
              ),
              onChanged: (v) => form.set(keyOf(id, 'amount'), v),
            ),
          ),
        ],
      );
    } else {
      trailing = SizedBox(
        width: 110,
        child: TextField(
          controller: TextEditingController(text: value)
            ..selection = TextSelection.collapsed(offset: value.length),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.all(10),
          ),
          onChanged: (v) => form.set(keyOf(id), v),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subLabel != null && subLabel!.isNotEmpty)
                  Text(
                    subLabel!,
                    style: const TextStyle(color: Brand.muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
