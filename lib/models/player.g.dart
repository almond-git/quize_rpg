// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Player _$PlayerFromJson(Map<String, dynamic> json) => Player(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String,
      level: (json['level'] as num?)?.toInt() ?? 1,
      experience: (json['experience'] as num?)?.toInt() ?? 0,
      requiredExperience: (json['requiredExperience'] as num?)?.toInt() ?? 100,
      itemInventory: (json['itemInventory'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      wrongQuestions: (json['wrongQuestions'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$PlayerToJson(Player instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'level': instance.level,
      'experience': instance.experience,
      'requiredExperience': instance.requiredExperience,
      'itemInventory': instance.itemInventory,
      'wrongQuestions': instance.wrongQuestions,
    };
