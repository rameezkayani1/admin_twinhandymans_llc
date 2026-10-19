import 'package:flutter/material.dart';

class NavItem {
  final String label;
  final IconData icon;
  const NavItem(this.label, this.icon);
}

const navItems = [
  NavItem('Dashboard', Icons.dashboard_outlined),
  NavItem('Customers', Icons.people_outline),
  NavItem('Quote Requests', Icons.inbox_outlined),
  NavItem('Quotes', Icons.request_quote_outlined),
  NavItem('Jobs', Icons.construction_outlined),
  NavItem('Calendar', Icons.calendar_month_outlined),
  NavItem('Invoices', Icons.receipt_long_outlined),
  NavItem('Payments', Icons.payments_outlined),
  NavItem('Messages', Icons.chat_bubble_outline),
  NavItem('Documents', Icons.folder_open_outlined),
  NavItem('Reviews', Icons.star_outline),
  NavItem('Reports', Icons.bar_chart_outlined),
  NavItem('Users & Permissions', Icons.admin_panel_settings_outlined),
  NavItem('Settings', Icons.settings_outlined),
];
