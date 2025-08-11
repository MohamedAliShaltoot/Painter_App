import 'package:flutter/material.dart';

enum ToolType {
  pencil('Pencil', Icons.edit),
  eraser('Eraser', Icons.cleaning_services),
  line('Line', Icons.remove),
  rectangle('Rectangle', Icons.crop_square),
  circle('Circle', Icons.circle_outlined),
  text('Text', Icons.text_fields);

  const ToolType(this.displayName, this.icon);
  final String displayName;
  final IconData icon;
}
