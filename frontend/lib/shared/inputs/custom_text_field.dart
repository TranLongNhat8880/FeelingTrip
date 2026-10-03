import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.readOnly = false,
    this.onChanged,
    this.errorText,
    this.helperText,
    this.inputFormatters,
    this.onTap,
    this.suffixIcon,
    this.textInputAction,
    this.onFieldSubmitted,
  });
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final bool enabled;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final String? helperText;
  final List<TextInputFormatter>? inputFormatters;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    style: Theme.of(context).textTheme.bodyLarge,
    obscureText: widget.isPassword && _obscure,
    enableSuggestions: !widget.isPassword,
    autocorrect: !widget.isPassword,
    keyboardType: widget.keyboardType,
    maxLines: widget.isPassword ? 1 : widget.maxLines,
    validator: widget.validator,
    enabled: widget.enabled,
    readOnly: widget.readOnly,
    onChanged: widget.onChanged,
    inputFormatters: widget.inputFormatters,
    onTap: widget.onTap,
    textInputAction: widget.textInputAction,
    onFieldSubmitted: widget.onFieldSubmitted,
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      errorText: widget.errorText,
      helperText: widget.helperText,
      prefixIcon: widget.prefixIcon == null
          ? null
          : Icon(widget.prefixIcon, size: 20),
      suffixIcon: widget.isPassword
          ? IconButton(
              tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              onPressed: widget.enabled
                  ? () => setState(() => _obscure = !_obscure)
                  : null,
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            )
          : widget.suffixIcon,
    ),
  );
}
