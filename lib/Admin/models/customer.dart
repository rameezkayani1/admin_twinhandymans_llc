class Customer {
  String name, phone, email, address, notes;
  int jobs;
  double spent;
  List<String> properties;
  Customer(
    this.name,
    this.phone,
    this.email,
    this.address,
    this.jobs,
    this.spent, {
    this.notes = '',
    this.properties = const [],
  });
}
