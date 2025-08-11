import 'package:flutter/material.dart';

enum BackgroundType {
  none('None', Icons.close),
  grid('Square Grid', Icons.grid_on),
  dotted('Dotted', Icons.blur_on),
  lines('Horizontal Lines', Icons.line_weight);

  const BackgroundType(this.displayName, this.icon);
  final String displayName;
  final IconData icon;
}
