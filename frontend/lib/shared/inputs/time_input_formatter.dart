import 'package:flutter/services.dart';

/// Formats four digits as HH:mm while allowing incomplete edits.
class TimeInputFormatter extends TextInputFormatter {
  const TimeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!RegExp(r'^[0-9:]*$').hasMatch(newValue.text)) return oldValue;
    final digits = newValue.text.replaceAll(':', '');
    final previous = oldValue.text.replaceAll(':', '');
    if (digits.length > 4) return oldValue;
    if (digits == previous &&
        oldValue.text.contains(':') &&
        !newValue.text.contains(':')) {
      // Backspace over the separator moves before it instead of getting stuck.
      return oldValue.copyWith(
        selection: TextSelection.collapsed(
          offset: newValue.selection.baseOffset.clamp(0, oldValue.text.length),
        ),
        composing: TextRange.empty,
      );
    }
    final deleting =
        digits.length < previous.length &&
        oldValue.selection.isCollapsed &&
        oldValue.text.length - newValue.text.length == 1;
    if (!deleting || digits.length == 4) {
      if (digits.isNotEmpty && int.parse(digits[0]) > 2) return oldValue;
      if (digits.length >= 2 && int.parse(digits.substring(0, 2)) > 23) {
        return oldValue;
      }
      if (digits.length >= 3 && int.parse(digits[2]) > 5) return oldValue;
    }
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}:${digits.substring(2)}';
    int position(int offset) {
      if (offset < 0) return text.length;
      final prefix = newValue.text.substring(
        0,
        offset.clamp(0, newValue.text.length),
      );
      final count = prefix.replaceAll(':', '').length;
      final afterSeparator = count == 2 && prefix.endsWith(':');
      return (count +
              (text.contains(':') && (count > 2 || afterSeparator) ? 1 : 0))
          .clamp(0, text.length);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: position(newValue.selection.baseOffset),
        extentOffset: position(newValue.selection.extentOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }
}
