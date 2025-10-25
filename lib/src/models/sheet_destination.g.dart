// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sheet_destination.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SheetDestinationAdapter extends TypeAdapter<SheetDestination> {
  @override
  final int typeId = 1;

  @override
  SheetDestination read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SheetDestination(
      type: fields[0] as SheetType,
      path: fields[1] as String,
      sheetName: fields[2] as String?,
      templateHeaders: (fields[3] as List).cast<String>(),
      schemaVersion: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SheetDestination obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.path)
      ..writeByte(2)
      ..write(obj.sheetName)
      ..writeByte(3)
      ..write(obj.templateHeaders)
      ..writeByte(4)
      ..write(obj.schemaVersion);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SheetDestinationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SheetTypeAdapter extends TypeAdapter<SheetType> {
  @override
  final int typeId = 4;

  @override
  SheetType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SheetType.csv;
      case 1:
        return SheetType.xlsx;
      default:
        return SheetType.csv;
    }
  }

  @override
  void write(BinaryWriter writer, SheetType obj) {
    switch (obj) {
      case SheetType.csv:
        writer.writeByte(0);
        break;
      case SheetType.xlsx:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SheetTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
