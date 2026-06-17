import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/confidence_badge.dart';

class FormDialogShell extends StatelessWidget {
  const FormDialogShell({
    super.key,
    required this.title,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    this.error,
    this.busy = false,
    this.maxWidth = 560,
  });

  final String title;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback onSubmit;
  final String? error;
  final bool busy;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              ...children,
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    style:
                        const TextStyle(color: KColors.negative, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: KColors.accent,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: busy ? null : onSubmit,
                    child: busy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(submitLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Numeric text field that parses to double on read.
class NumField extends StatelessWidget {
  const NumField(
      {super.key,
      required this.controller,
      required this.label,
      this.hint,
      this.onChanged});

  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: true),
      decoration: InputDecoration(labelText: label, helperText: hint),
      onChanged: onChanged,
    );
  }
}

double? parseNum(TextEditingController c) =>
    double.tryParse(c.text.trim().replaceAll(',', ''));

/// K's conviction grade picker — the confidence she's putting behind the name.
/// [value] is the stored 'low'|'medium'|'high' (or null = ungraded); [onChanged]
/// hands back the same. Ungraded stays a first-class choice so K can defer.
class ConfidenceField extends StatelessWidget {
  const ConfidenceField({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Conviction',
        helperText: 'How much confidence behind the name — and how much risk.',
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Ungraded')),
        for (final c in Conviction.values)
          DropdownMenuItem(value: c.value, child: Text(c.longLabel)),
      ],
      onChanged: onChanged,
    );
  }
}
