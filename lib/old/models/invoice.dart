class Invoice {
  String id, job, customer, status, method;
  double total, paid;
  DateTime due;
  Invoice(
    this.id,
    this.job,
    this.customer,
    this.total,
    this.paid,
    this.due,
    this.status,
    this.method,
  );
  double get balance => total - paid;
}
