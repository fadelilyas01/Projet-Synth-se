import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shieldnet/features/settings/presentation/widgets/auth_bottom_sheet.dart';

void main() {
  testWidgets('AuthBottomSheet overflow check on small 320px screen in login and register mode', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AuthBottomSheet(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AuthBottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Toggle to registration ("Créer mon compte")
    final toggleFinder = find.text("Pas encore de compte ? S'inscrire");
    expect(toggleFinder, findsOneWidget);
    await tester.tap(toggleFinder);
    await tester.pumpAndSettle();

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Toggle back to login ("Se connecter")
    final toggleBackFinder = find.text('Déjà un compte ? Se connecter');
    expect(toggleBackFinder, findsOneWidget);
    await tester.tap(toggleBackFinder);
    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
