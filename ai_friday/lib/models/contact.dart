class Contact {
  final String id;
  final String displayName;
  final List<String> phones;
  final String? alias;

  const Contact({
    required this.id,
    required this.displayName,
    required this.phones,
    this.alias,
  });

  String get primaryPhone => phones.isNotEmpty ? phones.first : '';
}
