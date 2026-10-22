import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_mobile_lms_k12/core/api_client.dart';
import 'package:new_mobile_lms_k12/core/page_service.dart';
import 'package:new_mobile_lms_k12/core/session.dart';
import 'package:new_mobile_lms_k12/ui/sdui/page_renderer.dart';

Map<String, dynamic> node(String id, String type, double y, Map<String, dynamic> props,
        {double x = 20, double w = 335, double h = 56, List<Map<String, dynamic>>? children}) =>
    {
      'id': id,
      'type': type,
      'position': {'x': x, 'y': y},
      'size': {'width': w, 'height': h},
      'props': props,
      'children': ?children,
    };

void main() {
  final layout = {
    'page': {'name': 'Student Infirmary', 'background': {'type': 'color', 'color': '#FFFFFF'}},
    'components': [
      node('t', 'text', 20, {'content': 'Student Infirmary', 'variant': 'h1'}, h: 40),
      node('i1', 'input', 80, {'label': 'Student ID', 'field': 'student_id', 'inputType': 'text', 'required': true}),
      node('i2', 'input', 146, {'label': 'Open Date', 'field': 'date', 'inputType': 'date'}),
      node('i3', 'input', 212, {
        'label': 'Gender', 'field': 'gender', 'inputType': 'select',
        'options': [{'value': 'm', 'label': 'Male'}, {'value': 'f', 'label': 'Female'}],
      }),
      node('a', 'input', 278, {'label': 'First', 'field': 'first', 'inputType': 'text'}, w: 160),
      node('b', 'input', 278, {'label': 'Last', 'field': 'last', 'inputType': 'text'}, x: 195, w: 160),
      node('d', 'divider', 340, {}, h: 1),
      node('c', 'card', 360, {'padding': 8}, h: 120, children: [
        node('ct', 'text', 0, {'content': 'Inside a card'}, h: 24),
      ]),
      node('l', 'list', 500, {
        'listTitle': 'Roster',
        'searchFields': [{'key': 'class', 'label': 'Class', 'inputType': 'text'}],
        'searchAction': {'method': 'POST', 'endpoint': 'x'},
      }, h: 200),
      node('btn', 'button', 720, {'label': 'Save', 'action': {'type': 'api', 'endpoint': 'x'}}),
      node('unk', 'carousel', 800, {}, h: 10),
    ],
  };

  testWidgets('a builder layout renders natively and inputs feed the form', (tester) async {
    final form = FormValues();
    final session = Session(
      token: 't', userId: 1, subInstituteId: 1, clientId: 1, userProfileId: 1,
      userProfileName: 'Admin', name: 'A', email: 'a@x', schoolName: 'S',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PageScope(
          form: form,
          service: PageService(ApiClient(), session),
          data: null,
          onAction: (_, _) async {},
          child: SingleChildScrollView(child: PageRenderer(layout: layout)),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Student Infirmary'), findsOneWidget);
    expect(find.text('Student ID *'), findsOneWidget);
    expect(find.text('Roster'), findsOneWidget);
    expect(find.text('Search to load records.'), findsOneWidget);
    expect(find.text('Inside a card'), findsOneWidget);
    // Same-band inputs share a row.
    expect(tester.getTopLeft(find.text('First')).dy, tester.getTopLeft(find.text('Last')).dy);

    await tester.enterText(find.widgetWithText(TextField, 'Student ID *'), '42');
    expect(form['student_id'], '42');
  });
}
