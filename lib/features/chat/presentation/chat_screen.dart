import 'package:flutter/material.dart';

import '../../../core/localization/lingo_localizations.dart';
import '../../../shared/widgets/lingo_components.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/pip_mascot.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.text('chat'))),
    body: ResponsiveBody(
      child: LingoEmptyState(
        title: context.l10n.text('chatTitle'),
        message: context.l10n.text('chatUnavailable'),
        mood: PipMood.thinking,
      ),
    ),
  );
}
