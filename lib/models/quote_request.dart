class QuoteRequest {
  String id,
      customer,
      phone,
      email,
      service,
      description,
      address,
      time,
      status;
  DateTime date;
  double budget;
  int photos, videos;
  QuoteRequest(
    this.id,
    this.customer,
    this.phone,
    this.email,
    this.service,
    this.description,
    this.address,
    this.date,
    this.time,
    this.budget,
    this.photos,
    this.videos,
    this.status,
  );
}
