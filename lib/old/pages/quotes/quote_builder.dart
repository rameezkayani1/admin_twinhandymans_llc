import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

void openQuoteBuilder(
  BuildContext context, {
  QuoteRequest? request,
  String? customer,
}) {
  showDialog(
    context: context,
    builder: (_) => QuoteBuilder(request: request, customer: customer),
  );
}

class QuoteBuilder extends StatefulWidget {
  final QuoteRequest? request;
  final String? customer;
  const QuoteBuilder({super.key, this.request, this.customer});
  @override
  State<QuoteBuilder> createState() => _QuoteBuilderState();
}

class _QuoteBuilderState extends State<QuoteBuilder> {
  final c = Get.find<AppController>();
  late String customer =
      widget.request?.customer ?? widget.customer ?? c.customers.first.name;
  late String service = widget.request?.service ?? 'Painting';
  final f = <String, TextEditingController>{
    'Labor': TextEditingController(text: '900'),
    'Materials': TextEditingController(text: '350'),
    'Equipment': TextEditingController(text: '0'),
    'Disposal fees': TextEditingController(text: '0'),
    'Travel / service fee': TextEditingController(text: '50'),
    'Discount': TextEditingController(text: '0'),
  };
  late double taxPct = c.defaultTax.value;
  late double depositPct = c.defaultDeposit.value;
  bool fixedDeposit = false;
  final fixedCtl = TextEditingController(text: '500');
  DateTime expires = DateTime(2026, 10, 25);
  final terms = TextEditingController(
    text:
        'Deposit is required to book. Balance due upon completion. Quote valid until the expiration date.',
  );
  final notes = TextEditingController();

  double n(String k) => double.tryParse(f[k]!.text) ?? 0;
  Quote get preview {
    final q = Quote(
      'Q-${2032 + c.quotes.length - 6}',
      customer,
      service,
      'Sent',
      n('Labor'),
      n('Materials'),
      n('Equipment'),
      n('Disposal fees'),
      n('Travel / service fee'),
      n('Discount'),
      taxPct,
      depositPct,
      expires,
    );
    if (fixedDeposit && q.total > 0)
      q.depositPct = ((double.tryParse(fixedCtl.text) ?? 0) / q.total * 100)
          .clamp(0, 100);
    return q;
  }

  @override
  Widget build(BuildContext context) {
    final names = c.customers.map((e) => e.name).toList();
    if (!names.contains(customer)) names.add(customer);
    final services = [
      'Painting',
      'Moving',
      'Cleaning',
      'Assembly',
      'Lawn Services',
      'Waste Disposal',
      'Pressure Washing',
      'General Handyman',
      'Other',
    ];
    if (!services.contains(service)) services.add(service);
    final q = preview;
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: customer,
          decoration: const InputDecoration(labelText: 'Customer'),
          items: [
            for (final e in names) DropdownMenuItem(value: e, child: Text(e)),
          ],
          onChanged: (v) => setState(() => customer = v!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: service,
          decoration: const InputDecoration(labelText: 'Service'),
          items: [
            for (final e in services)
              DropdownMenuItem(value: e, child: Text(e)),
          ],
          onChanged: (v) => setState(() => service = v!),
        ),
        const SizedBox(height: 16),
        Grid(
          minWidth: 170,
          gap: 12,
          children: [
            for (final k in f.keys)
              TextField(
                controller: f[k],
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: k, prefixText: '\$ '),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Tax: ${taxPct.toStringAsFixed(3)}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              flex: 2,
              child: Slider(
                value: taxPct,
                min: 0,
                max: 10,
                divisions: 40,
                activeColor: C.navy,
                onChanged: (v) => setState(() => taxPct = v),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Deposit type',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Percent')),
                ButtonSegment(value: true, label: Text('Fixed \$')),
              ],
              selected: {fixedDeposit},
              onSelectionChanged: (s) => setState(() => fixedDeposit = s.first),
            ),
          ],
        ),
        if (!fixedDeposit)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Deposit: ${depositPct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 2,
                child: Slider(
                  value: depositPct,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: C.navy,
                  onChanged: (v) => setState(() => depositPct = v),
                ),
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: fixedCtl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Fixed deposit amount',
                prefixText: '\$ ',
              ),
            ),
          ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Expiration date',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(fmtDate(expires)),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: expires,
              firstDate: DateTime(2026, 10, 4),
              lastDate: DateTime(2027, 12, 31),
            );
            if (d != null) setState(() => expires = d);
          },
        ),
        TextField(
          controller: terms,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Terms & conditions'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes to customer'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => c.snack('Attachment picker (demo)'),
          icon: const Icon(Icons.attach_file),
          label: const Text('Add attachments'),
        ),
      ],
    );
    final summary = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: C.line),
        color: const Color(0xFFFAFBFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUOTE PREVIEW',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: C.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          totalsView(q),
        ],
      ),
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: Column(
          children: [
            Container(
              color: C.navy,
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.request != null
                          ? 'Create Quote for ${widget.request!.id}'
                          : 'New Quote',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth > 760) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: form,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                            child: summary,
                          ),
                        ),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [form, const SizedBox(height: 16), summary],
                    ),
                  );
                },
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: C.line)),
              ),
              padding: const EdgeInsets.all(14),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      c.snack('Draft saved');
                      Navigator.pop(context);
                    },
                    child: const Text('Save Draft'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      c.addQuote(preview, requestId: widget.request?.id);
                      Navigator.pop(context);
                      c.page.value = 3;
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('SEND TO CUSTOMER'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
