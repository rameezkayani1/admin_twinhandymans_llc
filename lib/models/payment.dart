class Payment {
  String id, invoice, customer, method, status;
  double amount, fee;
  DateTime date;
  Payment(
    this.id,
    this.invoice,
    this.customer,
    this.amount,
    this.method,
    this.date,
    this.status,
    this.fee,
  );
}
