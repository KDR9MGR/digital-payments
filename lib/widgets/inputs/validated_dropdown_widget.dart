import 'package:flutter/material.dart';

import '../../utils/custom_color.dart';
import '../../utils/dimensions.dart';

class ValidatedDropDownInputWidget extends StatefulWidget {
  final String hintText;
  final bool? readOnly;
  final Color? color;
  final double focusedBorderWidth;
  final double enabledBorderWidth;
  final Color borderColor;
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;
  final double width;
  final String? Function(String?)? validator;
  final String? errorText;

  const ValidatedDropDownInputWidget({
    super.key,
    required this.hintText,
    this.readOnly = false,
    this.focusedBorderWidth = 1,
    this.enabledBorderWidth = 2,
    this.color = Colors.white,
    this.borderColor = CustomColor.primaryColor,
    required this.items,
    required this.onChanged,
    this.value,
    this.width = double.infinity,
    this.validator,
    this.errorText,
  });

  @override
  State<ValidatedDropDownInputWidget> createState() => _ValidatedDropDownInputWidgetState();
}

class _ValidatedDropDownInputWidgetState extends State<ValidatedDropDownInputWidget> {
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.radius),
            border: Border.all(
              color: _errorText != null 
                  ? Colors.red.withValues(alpha: 0.8)
                  : CustomColor.primaryColor.withValues(alpha: 0.8),
              style: BorderStyle.solid,
              width: 1,
            ),
          ),
          height: Dimensions.inputBoxHeight,
          width: widget.width,
          child: Theme(
            data: Theme.of(context).copyWith(
              canvasColor: CustomColor.secondaryColor,
              buttonTheme: ButtonTheme.of(context).copyWith(
                alignedDropdown: true,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                hint: Text(
                  widget.hintText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 24,
                ),
                initialValue: widget.value,
                items: widget.items.map(buildMenuItem).toList(),
                onChanged: widget.onChanged,
                validator: (value) {
                  final error = widget.validator?.call(value);
                  setState(() {
                    _errorText = error;
                  });
                  return error;
                },
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Text(
              _errorText!,
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  DropdownMenuItem<String> buildMenuItem(String item) => DropdownMenuItem(
        value: item,
        child: Text(
          item,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}