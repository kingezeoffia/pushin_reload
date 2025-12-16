// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'DailyUsage.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyUsageAdapter extends TypeAdapter<DailyUsage> {
  @override
  final int typeId = 0;

  @override
  DailyUsage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyUsage(
      date: fields[0] as String,
      earnedSeconds: fields[1] as int,
      consumedSeconds: fields[2] as int,
      planTier: fields[3] as String,
      lastUpdated: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DailyUsage obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.earnedSeconds)
      ..writeByte(2)
      ..write(obj.consumedSeconds)
      ..writeByte(3)
      ..write(obj.planTier)
      ..writeByte(4)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyUsageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
