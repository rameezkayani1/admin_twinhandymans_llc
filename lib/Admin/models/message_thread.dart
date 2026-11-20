class Msg {
  String text;
  bool mine;
  String time;
  Msg(this.text, this.mine, this.time);
}

class Thread {
  String customer, job;
  int unread;
  List<Msg> msgs;
  Thread(this.customer, this.job, this.unread, this.msgs);
}
