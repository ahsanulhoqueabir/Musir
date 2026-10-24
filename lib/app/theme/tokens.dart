import 'package:flutter/widgets.dart';

/// Spacing, radius and sizing tokens shared by every screen.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page gutter.
  static const double gutter = 16;
}

abstract final class Corners {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}

abstract final class Sizes {
  /// Minimum touch target (Material guideline).
  static const double touch = 48;
  static const double trackArtwork = 48;
  static const double miniPlayerHeight = 64;
  static const double homeCard = 140;
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
}
