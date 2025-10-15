class CardDataModel {
  final String name;
  final String title;
  final String company;
  final String email;
  final String phone;

  CardDataModel(
      {required this.name,
      required this.title,
      required this.company,
      required this.email,
      required this.phone});

  factory CardDataModel.fromMap(Map<String, dynamic> map) {
    return CardDataModel(
      name: map['name'] ?? '',
      title: map['title'] ?? '',
      company: map['company'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'title': title,
        'company': company,
        'email': email,
        'phone': phone,
      };
}
