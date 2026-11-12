import '../../core/localization/lingo_localizations.dart';

import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.enabled = true,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _obscured,
    autocorrect: false,
    enableSuggestions: false,
    validator: (value) => context.l10n.validation(widget.validator(value)),
    textInputAction: TextInputAction.done,
    onFieldSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: widget.label,
      errorMaxLines: 3,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        tooltip: _obscured
            ? context.l10n.text('showPassword')
            : context.l10n.text('uie40123b4e7'),
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}
