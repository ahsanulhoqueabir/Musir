import 'package:flutter/material.dart';

/// The Musir logo, used on the splash screen and in headers.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size});

  final double size;

  static const String asset = 'assets/branding/musir_logo.png';

  @override
  Widget build(BuildContext context) {
    // The artwork has a white background, so round it off to sit on dark
    // surfaces without looking like a stray white box.
    return Semantics(
      label: 'Musir logo',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
