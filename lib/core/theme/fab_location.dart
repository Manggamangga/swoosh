import 'package:flutter/material.dart';

class FabAboveNavBarLocation extends FloatingActionButtonLocation {
  const FabAboveNavBarLocation(this.clearance);

  final double clearance;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final fabSize = scaffoldGeometry.floatingActionButtonSize;
    const margin = kFloatingActionButtonMargin;
    final x = scaffoldGeometry.scaffoldSize.width - fabSize.width - margin;
    final y = scaffoldGeometry.scaffoldSize.height -
        fabSize.height -
        margin -
        clearance;
    return Offset(x, y);
  }
}
