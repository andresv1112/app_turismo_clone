import 'package:flutter/foundation.dart';

@immutable
class UserPreferences {
  const UserPreferences({
    this.preferredReportTypeId,
    this.shareLocation = true,
  });

  final String? preferredReportTypeId;
  final bool shareLocation;

  static const UserPreferences defaults = UserPreferences();

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'preferredReportTypeId': preferredReportTypeId,
      'shareLocation': shareLocation,
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      preferredReportTypeId: json['preferredReportTypeId'] as String?,
      shareLocation: json['shareLocation'] as bool? ?? true,
    );
  }

  UserPreferences copyWith({
    String? preferredReportTypeId,
    bool? shareLocation,
    bool clearPreferredReportType = false,
  }) {
    return UserPreferences(
      preferredReportTypeId:
          clearPreferredReportType ? null : preferredReportTypeId ?? this.preferredReportTypeId,
      shareLocation: shareLocation ?? this.shareLocation,
    );
  }
}