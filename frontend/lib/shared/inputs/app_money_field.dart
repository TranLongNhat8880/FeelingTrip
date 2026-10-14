import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'custom_text_field.dart';

/// Cursor stays beside the same digits after insertion/deletion/paste.
class VndInputFormatter extends TextInputFormatter {
  static String format(String digits) => digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]}.',
  );
  static int? parse(String text) {
    if (!RegExp(r'^[0-9.\s]*$').hasMatch(text)) return null;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    if (!RegExp(r'^[0-9.\s]*$').hasMatch(newValue.text)) return oldValue;
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // 15 digits remain exact in Flutter web; business maxima belong to each form.
    if (digits.length > 15) return oldValue;
    final formatted = format(digits);
    final cursor = newValue.selection.extentOffset.clamp(
      0,
      newValue.text.length,
    );
    final before = newValue.text
        .substring(0, cursor)
        .replaceAll(RegExp(r'\D'), '')
        .length;
    var offset = 0, seen = 0;
    while (offset < formatted.length && seen < before) {
      if (formatted[offset] != '.') seen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class AppMoneyField extends StatelessWidget {
  const AppMoneyField({
    super.key,
    required this.label,
    this.controller,
    this.onChanged,
    this.allowZero = true,
    this.enabled = true,
    this.maxAmount,
    this.errorText,
  });
  final String label;
  final TextEditingController? controller;
  final ValueChanged<int?>? onChanged;
  final bool allowZero;
  final bool enabled;
  final int? maxAmount;
  final String? errorText;
  @override
  Widget build(BuildContext context) => CustomTextField(
    label: label,
    prefixIcon: Icons.account_balance_wallet_outlined,
    controller: controller,
    enabled: enabled,
    errorText: errorText,
    keyboardType: TextInputType.number,
    inputFormatters: [VndInputFormatter()],
    suffixIcon: const Padding(padding: EdgeInsets.all(18), child: Text('VND')),
    onChanged: (text) => onChanged?.call(VndInputFormatter.parse(text)),
    validator: (text) {
      final value = VndInputFormatter.parse(text ?? '');
      if (value == null) return 'Vui lòng nhập số tiền';
      if (!allowZero && value == 0) return 'Số tiền phải lớn hơn 0';
      if (maxAmount != null && value > maxAmount!) {
        return 'Số tiền vượt giới hạn cho phép';
      }
      return null;
    },
  );
}
