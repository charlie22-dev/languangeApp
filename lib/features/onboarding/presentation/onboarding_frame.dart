import 'package:flutter/material.dart';

import '../../../shared/widgets/responsive_body.dart';

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
        title: Text('Step $step of 3'),
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: step / 3,
              semanticsLabel: 'Onboarding step $step of 3',
            ),
            const SizedBox(height: 32),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 32),
            child,
          ],
        ),
      ),
    ),
  );
}
