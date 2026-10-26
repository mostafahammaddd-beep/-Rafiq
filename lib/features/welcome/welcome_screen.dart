import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio_engine/engine_providers.dart';
import '../../core/database/database_providers.dart';
import '../../core/profile/profile_repository.dart';
import '../../core/profile/reminder_service.dart';
import '../../core/profile/user_profile.dart';
import '../home/home_shell.dart';
import '../onboarding/onboarding_screen.dart';

/// App gate: starts preparing the acoustic model in the background, shows
/// the first-run onboarding when there is no profile, then the preparation
/// progress, then the app.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _navigated = false;
  bool _remindersSynced = false;

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

  void _syncReminders(UserProfile profile) {
    if (_remindersSynced) {
      return;
    }
    _remindersSynced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReminderService.scheduleDaily(profile);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<UserProfile?> profileAsync = ref.watch(profileProvider);

    if (profileAsync.value == null && profileAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final UserProfile? profile = profileAsync.value;
    if (profile == null) {
      return const OnboardingScreen();
    }
    _syncReminders(profile);

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

    final bool canContinueWithoutModel = dbReady &&
        (prep.stage == PrepStage.modelMissing || prep.stage == PrepStage.failed);

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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 130,
                      height: 130,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'أهلاً بك يا ${profile.name}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تطبيق وقفي مجاني لحفظ كتاب الله',
                    style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
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
