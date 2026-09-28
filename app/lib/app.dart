import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'core/widgets/brand_mark.dart';
import 'data/session.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/connect/connect_screen.dart';
import 'features/setup/setup_wizard.dart';
import 'features/shell/app_shell.dart';
import 'l10n/generated/app_localizations.dart';

class MiseApp extends ConsumerWidget {
  const MiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return MaterialApp(
      // On the app title: `onGenerateTitle` is used rather than `title` because
      // it runs inside the localization scope, so the name is available in the
      // device's language instead of being frozen at build time.
      //
      // `AppStrings.of(context)` is nullable by design — the generated lookup
      // returns null outside a Localizations scope. Inside MaterialApp's own
      // builder that cannot happen, so `!` is correct here; falling back to a
      // literal would hide a real misconfiguration.
      onGenerateTitle: (context) => AppStrings.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,

      // `id` is listed first because it is the primary market; the device's
      // locale decides, and anything unsupported falls back to `en` rather than
      // to a half-translated mix.
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppStrings.supportedLocales,
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return const Locale('id');
        for (final s in supported) {
          if (s.languageCode == locale.languageCode) return s;
        }
        return const Locale('en');
      },

      home: AnimatedSwitcher(
        duration: Motion.normal,
        switchInCurve: Motion.enter,
        switchOutCurve: Motion.exit,
        child: switch (session) {
          SessionBooting() => const _BootScreen(),
          SessionNeedsServer(:final error, :final lastUrl) => ConnectScreen(
              key: const ValueKey('connect'),
              initialError: error,
              initialUrl: lastUrl,
            ),
          SessionNeedsSetup() => const SetupWizard(key: ValueKey('setup')),
          SessionNeedsAuth(:final venueName) => SignInScreen(
              key: const ValueKey('signin'),
              venueName: venueName,
            ),
          SessionReady(:final staff, :final restaurant) => AppShellScreen(
              key: const ValueKey('shell'),
              staff: staff,
              restaurant: restaurant,
            ),
        },
      ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(size: 56),
              SizedBox(height: Space.xl),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ],
          ),
        ),
      );
}
