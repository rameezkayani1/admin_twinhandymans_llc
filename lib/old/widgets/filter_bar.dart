import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/core.dart';

class FilterBar extends StatelessWidget {
  final List<String> options;
  final RxString value;
  const FilterBar(this.options, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final o in options)
            Obx(
              () => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => value.value = o,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value.value == o ? C.navy : Colors.white,
                      border: Border.all(
                        color: value.value == o ? C.navy : C.line,
                      ),
                    ),
                    child: Text(
                      o,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: value.value == o ? Colors.white : C.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
