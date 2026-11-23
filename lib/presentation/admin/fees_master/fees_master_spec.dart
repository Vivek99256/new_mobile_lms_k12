import 'package:flutter/material.dart' show IconData, Icons;

import '../../../core/legacy_api.dart';
import '../../../screens/kit/kit.dart';

/// How a master's form field is drawn and sent.
enum MKind { text, number, date, dropdown, multi, toggle }

/// One input of a master's Add / Edit form.
class MField {
  const MField(
    this.key,
    this.label, {
    this.kind = MKind.text,
    this.required = false,
    this.options,
    this.initial,
    this.addOnly = false,
    this.editOnly = false,
    this.lines = 1,
    this.recordKey,
    this.dependsOn,
    this.readOnly = false,
    this.section,
    this.hint,
  });

  /// The card this field sits in on the form (fields with the same name are grouped).
  final String? section;

  /// A small helper line under the field.
  final String? hint;

  /// The key to read the saved value from when it differs from [key] (e.g. `standard` is stored as `standard_id`).
  final String? recordKey;

  /// For a multi list that depends on another: the [key] of the multi it follows (standards follow grades).
  final String? dependsOn;

  /// Shown but not editable (a number the server generates).
  final bool readOnly;

  /// The name the server expects.
  final String key;
  final String label;
  final MKind kind;
  final bool required;

  /// Name of the option list returned by [FeesMasterSpec.loadOptions] (dropdown / multi).
  final String? options;

  /// Starting value on Add ('1' / '0' for a toggle).
  final String? initial;
  final bool addOnly;
  final bool editOnly;
  final int lines;
}

/// A Fees (Master) screen's data rules: where it lives on the server and what its form holds. Each master is
/// one of these, so Add / Edit / Delete behave the same everywhere (and the same as the web page).
class FeesMasterSpec {
  const FeesMasterSpec({
    required this.title,
    required this.resource,
    required this.fields,
    this.canAdd = true,
    this.canEdit = true,
    this.canDelete = true,
    this.loadOptions,
    this.needsClass = false,
    this.bare = false,
    this.rowTitle,
    this.idKey = 'id',
    this.loadRecord,
    this.loadDependent,
    this.updateViaStore = false,
    this.extraBody,
    this.icon = Icons.tune_rounded,
    this.subtitle = '',
  });

  /// The master's icon and a one-line description, shown in the form header.
  final IconData icon;
  final String subtitle;

  /// The row key that names it on the server (`receipt_id` for receipt books).
  final String idKey;

  /// Loads the full saved record for Edit (the list rows can be partial or split in several rows).
  final Future<Map<String, dynamic>> Function(LegacyApi api, Map<String, dynamic> row)? loadRecord;

  /// Options of a dependent multi (by its option name) for the chosen parent ids.
  final Future<List<Opt>> Function(LegacyApi api, String optionsName, Set<String> parentIds)? loadDependent;

  /// Edit posts to the store route (not PUT), like the receipt book: the server replaces the old rows.
  final bool updateViaStore;

  /// Extra fixed fields (such as `submit`), by whether the form is editing.
  final Map<String, dynamic> Function(bool editing)? extraBody;

  final String title;

  /// Laravel resource name under /fees, e.g. `fees_late_master`.
  final String resource;
  final List<MField> fields;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;

  /// Option lists for dropdowns (named by [MField.options]).
  final Future<Map<String, List<Opt>>> Function(LegacyApi api)? loadOptions;

  /// Also asks for a section + standard, sent as `grade` and `standard` (the circular master).
  final bool needsClass;

  /// The server stores every field it receives (mass assignment), so the call must carry only this form's
  /// fields: no identity extras. The school and year travel in the query string instead (like the web).
  final bool bare;

  /// A short name for a row, used in the delete confirmation.
  final String Function(Map<String, dynamic> row)? rowTitle;
}
