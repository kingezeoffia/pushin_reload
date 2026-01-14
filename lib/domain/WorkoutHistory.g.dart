// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'WorkoutHistory.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutHistoryAdapter extends TypeAdapter<WorkoutHistory> {
  @override
  final int typeId = 1;

  @override
  WorkoutHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutHistory(
      id: fields[0] as String,
      workoutType: fields[1] as String,
      repsCompleted: fields[2] as int,
      earnedTimeSeconds: fields[3] as int,
      workoutMode: fields[4] as String,
      completedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutHistory obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.workoutType)
      ..writeByte(2)
      ..write(obj.repsCompleted)
      ..writeByte(3)
      ..write(obj.earnedTimeSeconds)
      ..writeByte(4)
      ..write(obj.workoutMode)
      ..writeByte(5)
      ..write(obj.completedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
