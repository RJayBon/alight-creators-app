import 'package:flutter/material.dart';

Color accentForCategory(String category) {
  switch (category) {
    case 'Beginner':      return const Color(0xFF2DD4BF);
    case 'Intermediate':  return const Color(0xFFA78BFA);
    case 'Advanced':      return const Color(0xFFF472B6);
    case 'Tips & Tricks': return const Color(0xFF38BDF8);
    default:              return const Color(0xFF00D2FF);
  }
}