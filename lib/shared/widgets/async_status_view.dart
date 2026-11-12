import '../../core/localization/lingo_localizations.dart';
import '../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';

import 'responsive_body.dart';
import 'pip_mascot.dart';
import 'lingo_components.dart';

class AsyncStatusView extends StatelessWidget {
  const AsyncStatusView({
    super.key,
    required this.message,
    this.onRetry,
    this.loading = false,
  });
  final String message;
  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) => ResponsiveBody(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PipMascot(mood: loading ? PipMood.thinking : PipMood.sad),
        if (loading) ...[
          const LingoSkeleton(),
          const SizedBox(height: LingoSpace.s16),
        ],
        Semantics(
          liveRegion: true,
          child: Text(message, textAlign: TextAlign.center),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: LingoSpace.s16),
          LingoButton.tonal(
            onPressed: onRetry,
            child: Text(context.l10n.text('ui042c862e44')),
          ),
        ],
      ],
    ),
  );
}
