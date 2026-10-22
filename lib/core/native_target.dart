/// Which native screen a menu row opens. There is no WebView: every row either maps to a
/// native target or is shown as "Soon".
enum TargetKind {
  /// A page authored in the Mobile Page Builder (`/api/mobile-page-builder/runtime/{slug}`).
  builderPage,

  /// A read-only stat page (`/api/mobile/dynamic-page/{key}`).
  dynamicPage,

  /// A role dashboard (`/api/{admin|teacher|student}-dashboard/summary`).
  dashboard,

  /// Any ERP endpoint, rendered by the generic data screen.
  apiData,
}

class NativeTarget {
  const NativeTarget(this.kind, this.value, {this.method = 'GET'});

  final TargetKind kind;

  /// slug, page key, or endpoint (path relative to /api/, or an absolute URL).
  final String value;
  final String method;

  const NativeTarget.page(String slug) : this(TargetKind.builderPage, slug);
  const NativeTarget.dynamic(String key) : this(TargetKind.dynamicPage, key);
  const NativeTarget.api(String endpoint, {String method = 'GET'})
      : this(TargetKind.apiData, endpoint, method: method);
  const NativeTarget.dashboard() : this(TargetKind.dashboard, '');

  /// `/mobile/custom/<slug>` is where the web app serves a builder page, so a menu row that
  /// still carries that URL maps straight to the same slug.
  static NativeTarget? fromWebUrl(String webUrl) {
    final uri = Uri.tryParse(webUrl);
    if (uri == null) return null;
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length >= 3 && segs[0] == 'mobile' && segs[1] == 'custom') {
      return NativeTarget.page(segs[2]);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is NativeTarget && other.kind == kind && other.value == value && other.method == method;

  @override
  int get hashCode => Object.hash(kind, value, method);
}
