import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio_engine/engine_providers.dart';
import '../../core/database/database_providers.dart';
import '../home/home_shell.dart';

/// Splash / bootstrap screen: opens the database, prepares the acoustic
/// model and then moves on to the app.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(modelPrepProvider.notifier).prepare();
      }
    });
  }

  void _goHome() {
    if (_navigated) {
      return;
    }
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (BuildContext context) => const HomeShell()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final PrepState prep = ref.watch(modelPrepProvider);
    final AsyncValue<Object> db = ref.watch(databaseProvider);

    final bool dbReady = db.hasValue;
    final bool dbFailed = db.hasError;

    if (dbReady && prep.stage == PrepStage.ready) {
      _goHome();
    }

    String message = prep.message;
    if (dbFailed) {
      message = 'تعذّر فتح قاعدة البيانات: ${db.error}';
    } else if (!dbReady && prep.stage == PrepStage.ready) {
      message = 'جارٍ تجهيز قاعدة البيانات…';
    } else if (message.isEmpty) {
      message = 'جارٍ التجهيز…';
    }

    final bool canContinueWithoutModel =
        dbReady && (prep.stage == PrepStage.modelMissing || prep.stage == PrepStage.failed);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 104,
                    height: 104,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primaryContainer,
                      border: Border.all(color: scheme.secondary, width: 2.5),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 52,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'رَفِيق',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    'تطبيق وقفي مجاني لحفظ كتاب الله',
                    style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: prep.stage == PrepStage.working ? prep.progress : null,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.7, color: scheme.onSurface),
                  ),
                  if (prep.stage == PrepStage.failed) ...<Widget>[
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () {
                        ref.read(modelPrepProvider.notifier).prepare(force: true);
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                  if (canContinueWithoutModel) ...<Widget>[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _goHome,
                      child: const Text('متابعة بدون التصحيح الصوتي'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
