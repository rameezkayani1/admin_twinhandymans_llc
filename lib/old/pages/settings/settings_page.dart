import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../widgets/widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return PageScaffold(
      title: 'Business Settings',
      subtitle: 'Owner-only settings',
      actions: [
        ElevatedButton(
          onPressed: () => c.snack('Settings saved'),
          child: const Text('SAVE CHANGES'),
        ),
      ],
      children: [
        Panel(
          title: 'Company Profile',
          child: Grid(
            minWidth: 280,
            gap: 12,
            children: [
              TextField(
                controller: TextEditingController(text: 'Twins Handyman LLC'),
                decoration: const InputDecoration(labelText: 'Business name'),
              ),
              TextField(
                controller: TextEditingController(text: 'twinshandymanllc.com'),
                decoration: const InputDecoration(labelText: 'Website'),
              ),
              TextField(
                controller: TextEditingController(
                  text: '1156 Liberty Avenue, Hillside, NJ 07205',
                ),
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: TextEditingController(text: '908-567-9897'),
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextField(
                controller: TextEditingController(
                  text: 'North Jersey & Staten Island',
                ),
                decoration: const InputDecoration(labelText: 'Service area'),
              ),
              TextField(
                controller: TextEditingController(text: '9:00 AM - 9:00 PM'),
                decoration: const InputDecoration(labelText: 'Business hours'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => Panel(
            title: 'Quote Defaults',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Default deposit: ${c.defaultDeposit.value.toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Slider(
                        value: c.defaultDeposit.value,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: C.navy,
                        onChanged: (v) => c.defaultDeposit.value = v,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Default tax: ${c.defaultTax.value.toStringAsFixed(3)}%',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Slider(
                        value: c.defaultTax.value,
                        min: 0,
                        max: 10,
                        divisions: 40,
                        activeColor: C.navy,
                        onChanged: (v) => c.defaultTax.value = v,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => Panel(
            title: 'Notifications',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: C.navy,
                  title: const Text('Push: new quote request'),
                  value: c.pushNewRequest.value,
                  onChanged: (v) => c.pushNewRequest.value = v,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: C.navy,
                  title: const Text('Email: new quote request'),
                  value: c.emailNewRequest.value,
                  onChanged: (v) => c.emailNewRequest.value = v,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: C.navy,
                  title: const Text('Push: payments received / failed'),
                  value: c.pushPayments.value,
                  onChanged: (v) => c.pushPayments.value = v,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: C.navy,
                  title: const Text('Push: new messages'),
                  value: c.pushMessages.value,
                  onChanged: (v) => c.pushMessages.value = v,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Panel(
          title: 'Security',
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.shield_outlined),
                title: Text('Multi-factor authentication'),
                trailing: Chip2('Enabled'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history),
                title: Text('Audit log'),
                subtitle: Text('Last login: Oct 4, 2026 • 8:41 AM'),
                trailing: Icon(Icons.chevron_right),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.backup_outlined),
                title: Text('Data backups'),
                subtitle: Text('Daily • Last backup 3:00 AM'),
                trailing: Chip2('Healthy'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
