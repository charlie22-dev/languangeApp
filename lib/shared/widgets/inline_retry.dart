import 'package:flutter/material.dart';

import '../../core/localization/lingo_localizations.dart';
import '../../core/theme/lingo_tokens.dart';
import 'lingo_components.dart';

/// A compact retry state for a section inside an otherwise usable screen.
class InlineRetry extends StatelessWidget {
  const InlineRetry({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(liveRegion: true, child: Text(message)),
      const SizedBox(height: LingoSpace.s8),
      LingoButton.outlined(
        onPressed: onRetry,
        child: Text(context.l10n.text('ui042c862e44')),
      ),
    ],
  );
}
