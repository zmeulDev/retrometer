import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrometer/location_disclosure.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Host that invokes [maybeShowLocationDisclosure] on tap and records the
/// result so the test can assert on it.
class _Probe extends StatefulWidget {
  const _Probe({required this.onResult});

  final void Function(bool) onResult;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final ok = await maybeShowLocationDisclosure(context);
            widget.onResult(ok);
          },
          child: const Text('start'),
        ),
      ),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('disclosure dialog appears once, then is acknowledged',
      (WidgetTester tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: _Probe(onResult: (r) => result = r),
    ));

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    // The prominent disclosure dialog is shown before any permission request.
    expect(find.text('Acces la locație'), findsOneWidget);
    expect(find.text('Continuă'), findsOneWidget);
    expect(find.text('Refuză'), findsOneWidget);
    // The privacy policy link and the optional-access note are present.
    expect(find.text('Vezi Politica de confidențialitate'), findsOneWidget);
    expect(find.textContaining('opțional'), findsOneWidget);

    await tester.tap(find.text('Continuă'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    // Second invocation: the flag is set, so the dialog is not shown again.
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.text('Acces la locație'), findsNothing);
  });

  testWidgets('declining the disclosure returns false and does not set the flag',
      (WidgetTester tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: _Probe(onResult: (r) => result = r),
    ));

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refuză'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    // Not acknowledged ⇒ the dialog shows again next time.
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.text('Acces la locație'), findsOneWidget);
  });
}