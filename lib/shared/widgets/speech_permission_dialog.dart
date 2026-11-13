import 'package:flutter/material.dart';

import '../../core/localization/lingo_localizations.dart';

Future<bool?> showSpeechPermissionDialog(
  BuildContext context, {
  required String bodyKey,
  required String declineKey,
}) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    scrollable: true,
    title: Text(context.l10n.text('speechPermissionTitle')),
    content: Text(context.l10n.text(bodyKey)),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(context.l10n.text(declineKey)),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(context.l10n.text('startRecording')),
      ),
    ],
  ),
);
