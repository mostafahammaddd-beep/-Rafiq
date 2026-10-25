import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_mode_provider.dart';

class _FeatureInfo {
  const _FeatureInfo(this.icon, this.label);

  final IconData icon;
  final String label;
}

const List<_FeatureInfo> _upcomingFeatures = <_FeatureInfo>[
  _FeatureInfo(Icons.menu_book_rounded, 'المصحف'),
  _FeatureInfo(Icons.psychology_alt_rounded, 'محرك الحفظ'),
  _FeatureInfo(Icons.family_restroom_rounded, 'أوضاع الأعمار'),
  _FeatureInfo(Icons.school_rounded, 'لوحة المعلم'),
];

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle(theme.brightness);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 112,
                    height: 112,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primaryContainer,
                      border: Border.all(color: scheme.secondary, width: 2.5),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 56,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'رَفِيق',
                    style: TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    'RAFIQ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'رفيقك في حفظ كتاب الله',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    elevation: 0,
                    color: scheme.primaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            Icons.volunteer_activism_rounded,
                            color: scheme.onPrimaryContainer,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'تطبيق وقفي مجاني بالكامل، ابتغاء وجه الله تعالى.\n'
                            'بلا إعلانات ولا اشتراكات، ويعمل على جهازك دون إنترنت.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.8,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      for (final _FeatureInfo feature in _upcomingFeatures)
                        Chip(
                          avatar: Icon(feature.icon, size: 18),
                          label: Text(feature.label),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'الواجهة تعمل بنجاح، وخط البناء سليم بإذن الله',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.touch_app_rounded),
                      label: const Text('اختبار الواجهة'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'هذا التطبيق وسيلة مساعدة على الحفظ، ولا يغني عن التلقّي '
                    'والمشافهة من معلّم متقن.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
