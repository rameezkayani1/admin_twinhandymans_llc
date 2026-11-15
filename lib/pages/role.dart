import 'package:get/get.dart';

const kAdminRoles = {'owner', 'admin'};
const kManagerRoles = {'manager'};
const kCrewRoles = {'crew'};
const kStaffRoles = {'owner', 'admin', 'manager', 'crew'};

/// Page indexes (match Shell._page)
class Pg {
  static const dashboard = 0, customers = 1, requests = 2, quotes = 3;
  static const jobs = 4, calendar = 5, invoices = 6, payments = 7;
  static const messages = 8, documents = 9, reviews = 10, reports = 11;
  static const users = 12, settings = 13;
}

class RoleController extends GetxController {
  final role = ''.obs;

  bool get isAdmin => kAdminRoles.contains(role.value);
  bool get isManager => kManagerRoles.contains(role.value);
  bool get isCrew => kCrewRoles.contains(role.value);

  static const _manager = {
    Pg.dashboard,
    Pg.customers,
    Pg.requests,
    Pg.quotes,
    Pg.jobs,
    Pg.calendar,
  };
  static const _crew = {Pg.dashboard, Pg.jobs, Pg.calendar};

  bool canOpen(int page) {
    if (isAdmin) return true;
    if (isManager) return _manager.contains(page);
    if (isCrew) return _crew.contains(page);
    return false;
  }

  bool get canSeeMoney => isAdmin;
  bool get canCreateQuotes => isAdmin || isManager;

  /// Assign / remove people and reschedule jobs (admin + manager, not crew).
  bool get canManageJobs => isAdmin || isManager;

  static RoleController ensure() => Get.isRegistered<RoleController>()
      ? Get.find<RoleController>()
      : Get.put(RoleController(), permanent: true);
}
