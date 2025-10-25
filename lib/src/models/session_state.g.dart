// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionStateAdapter extends TypeAdapter<SessionState> {
  @override
  final int typeId = 2;

  @override
  SessionState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionState(
      lastImagePath: fields[0] as String?,
      lastDestination: fields[1] as SheetDestination?,
      hasCompletedOnboarding: fields[2] as bool,
      schemaVersion: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SessionState obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.lastImagePath)
      ..writeByte(1)
      ..write(obj.lastDestination)
      ..writeByte(2)
      ..write(obj.hasCompletedOnboarding)
      ..writeByte(3)
      ..write(obj.schemaVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
