import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/pip_mascot.dart';

class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });
  final int step;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: step == 1,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) onBack?.call();
    },
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: onBack == null ? null : BackButton(onPressed: onBack),
        title: Text(context.l10n.text('ui36aa901fe0', {'arg0': (step)})),
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LingoProgress(
              value: step / 3,
              label: context.l10n.text('ui2aa3961a3a', {'arg0': (step)}),
            ),
            const SizedBox(height: LingoSpace.s32),
            const Center(child: PipMascot()),
            const SizedBox(height: LingoSpace.s24),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: LingoSpace.s8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: LingoSpace.s32),
            child,
          ],
        ),
      ),
    ),
  );
}
