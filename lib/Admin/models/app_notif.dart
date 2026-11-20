import 'package:flutter/material.dart';

class AppNotif {
  String title, body, time;
  IconData icon;
  bool unread;
  AppNotif(this.title, this.body, this.time, this.icon, this.unread);
}
