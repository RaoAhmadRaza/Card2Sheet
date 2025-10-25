// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HistoryItemAdapter extends TypeAdapter<HistoryItem> {
  @override
  final int typeId = 3;

  @override
  HistoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HistoryItem(
      id: fields[0] as String,
      structured: (fields[1] as Map).cast<String, String>(),
      destination: fields[2] as SheetDestination,
      rowIndex: fields[3] as int,
      timestamp: fields[4] as DateTime?,
      schemaVersion: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, HistoryItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.structured)
      ..writeByte(2)
      ..write(obj.destination)
      ..writeByte(3)
      ..write(obj.rowIndex)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.schemaVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
