import 'dart:convert';

class PasswordPolicy {
  static List<String> missing(String value) => [
    if (value.length < 8) 'Ít nhất 8 ký tự',
    if (value.length > 72 || utf8.encode(value).length > 72)
      'Không vượt quá 72 ký tự và 72 byte UTF-8',
    if (!RegExp(r'[A-Z]').hasMatch(value)) 'Ít nhất 1 chữ hoa (A–Z)',
    if (!RegExp(r'[a-z]').hasMatch(value)) 'Ít nhất 1 chữ thường (a–z)',
    if (!RegExp(r'[0-9]').hasMatch(value)) 'Ít nhất 1 chữ số (0–9)',
    if (!RegExp(r'[!-/:-@\[-`{-~]').hasMatch(value))
      'Ít nhất 1 ký tự đặc biệt (ví dụ: ! @ #)',
  ];
}
