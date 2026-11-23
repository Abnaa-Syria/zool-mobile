import 'package:flutter/widgets.dart';
import 'package:zool_ui/zool_ui.dart';

/// Amenity code (backend seed: wifi, ac, usb, wc, snack, tv, luggage, vip_seats) → Iconsax icon.
IconData amenityIcon(String code) => switch (code) {
      'wifi' => IconsaxPlusLinear.wifi,
      'ac' => IconsaxPlusLinear.wind,
      'usb' => IconsaxPlusLinear.flash_1,
      'snack' => IconsaxPlusLinear.coffee,
      'tv' => IconsaxPlusLinear.monitor,
      'luggage' => IconsaxPlusLinear.box_1,
      'vip_seats' => IconsaxPlusLinear.shield,
      'wc' => IconsaxPlusLinear.drop,
      _ => IconsaxPlusLinear.tick_circle,
    };
