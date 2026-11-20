class Quote {
  String id, customer, service, status;
  double labor,
      materials,
      equipment,
      disposal,
      travel,
      discount,
      taxPct,
      depositPct;
  DateTime expires;
  Quote(
    this.id,
    this.customer,
    this.service,
    this.status,
    this.labor,
    this.materials,
    this.equipment,
    this.disposal,
    this.travel,
    this.discount,
    this.taxPct,
    this.depositPct,
    this.expires,
  );
  double get subtotal =>
      labor + materials + equipment + disposal + travel - discount;
  double get total => subtotal + subtotal * taxPct / 100;
  double get deposit => total * depositPct / 100;
  double get balance => total - deposit;
}
