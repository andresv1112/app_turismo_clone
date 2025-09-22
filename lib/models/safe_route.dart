import 'package:flutter/foundation.dart';

@immutable
class SafeRoute {
  const SafeRoute({
    required this.name,
    required this.duration,
    required this.difficulty,
    required this.description,
    required this.pointsOfInterest,
  });

  final String name;
  final String duration;
  final String difficulty;
  final String description;
  final List<String> pointsOfInterest;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'duration': duration,
      'difficulty': difficulty,
      'description': description,
      'pointsOfInterest': pointsOfInterest,
    };
  }

  factory SafeRoute.fromJson(Map<String, dynamic> json) {
    return SafeRoute(
      name: json['name'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      description: json['description'] as String? ?? '',
      pointsOfInterest: (json['pointsOfInterest'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
    );
  }
}