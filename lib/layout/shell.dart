import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../pages/calendar/calendar_page.dart';
import '../pages/customers/customers_page.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../pages/documents/documents_page.dart';
import '../pages/invoices/invoices_page.dart';
import '../pages/jobs/jobs_page.dart';
import '../pages/messages/messages_page.dart';
import '../pages/payments/payments_page.dart';
import '../pages/quotes/quotes_page.dart';
import '../pages/reports/reports_page.dart';
import '../pages/requests/requests_page.dart';
import '../pages/reviews/reviews_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/users/users_page.dart';
import 'side_nav.dart';
import 'top_bar.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});
  Widget _page(int i) {
    switch (i) {
      case 0:
        return const DashboardPage();
      case 1:
        return const CustomersView();
      case 2:
        return const RequestsPage();
      case 3:
        return const QuotesPage();
      case 4:
        return const JobsPage();
      case 5:
        return const CalendarPage();
      case 6:
        return const InvoicesPage();
      case 7:
        return const PaymentsPage();
      case 8:
        return const MessagesPage();
      case 9:
        return const DocumentsPage();
      case 10:
        return const ReviewsPage();
      case 11:
        return const ReportsPage();
      case 12:
        return const UsersPage();
      default:
        return const SettingsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final mobile = w < 760;
        final extended = w >= 1150;
        return Scaffold(
          drawer: mobile
              ? const Drawer(
                  shape: RoundedRectangleBorder(),
                  child: SideNav(extended: true, inDrawer: true),
                )
              : null,
          body: Row(
            children: [
              if (!mobile) SideNav(extended: extended),
              Expanded(
                child: Column(
                  children: [
                    TopBar(mobile: mobile),
                    Expanded(child: Obx(() => _page(c.page.value))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
