class Job {
  String id, customer, service, address, time, duration, crew;
  DateTime date;
  int stage;
  double amount;
  int before, after;
  Job(
    this.id,
    this.customer,
    this.service,
    this.address,
    this.date,
    this.time,
    this.duration,
    this.crew,
    this.stage,
    this.amount, {
    this.before = 0,
    this.after = 0,
  });
}
