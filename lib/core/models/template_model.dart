class TemplateModel {
  final String id;
  final String name;
  final Map<String, dynamic> mapping;

  TemplateModel({required this.id, required this.name, required this.mapping});

  factory TemplateModel.fromMap(Map<String, dynamic> map) => TemplateModel(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        mapping: Map<String, dynamic>.from(map['mapping'] ?? {}),
      );
}
