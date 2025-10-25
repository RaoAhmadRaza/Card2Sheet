// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanResultAdapter extends TypeAdapter<ScanResult> {
  @override
  final int typeId = 0;

  @override
  ScanResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanResult(
      rawText: fields[0] as String,
      structured: (fields[1] as Map).cast<String, String>(),
      timestamp: fields[2] as DateTime?,
      schemaVersion: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ScanResult obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.rawText)
      ..writeByte(1)
      ..write(obj.structured)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.schemaVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
