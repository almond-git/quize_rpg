// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Item _$ItemFromJson(Map<String, dynamic> json) => Item(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String,
      iconPath: json['iconPath'] as String,
      type: $enumDecode(_$ItemTypeEnumMap, json['type']),
      value: (json['value'] as num).toInt(),
      price: (json['price'] as num).toInt(),
    );

Map<String, dynamic> _$ItemToJson(Item instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'iconPath': instance.iconPath,
      'type': _$ItemTypeEnumMap[instance.type]!,
      'value': instance.value,
      'price': instance.price,
    };

const _$ItemTypeEnumMap = {
  ItemType.hintCard: 'hintCard',
  ItemType.timeExtension: 'timeExtension',
  ItemType.expBooster: 'expBooster',
  ItemType.shield: 'shield',
  ItemType.retryChance: 'retryChance',
  ItemType.topicChange: 'topicChange',
};
