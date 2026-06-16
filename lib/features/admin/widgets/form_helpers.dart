import 'package:flutter/material.dart';

import '../../../core/theme.dart';

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
