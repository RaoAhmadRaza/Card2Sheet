// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanHistoryAdapter extends TypeAdapter<ScanHistory> {
  @override
  final int typeId = 5;

  @override
  ScanHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanHistory(
      fields[0] as String,
      fields[1] as String,
      fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ScanHistory obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.cardName)
      ..writeByte(1)
      ..write(obj.filePath)
      ..writeByte(2)
      ..write(obj.dateTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
