import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers.dart';
import '../../widgets/glass.dart';

class EmiScreen extends StatefulWidget {
  final int totalAmount;
  final String itemName;

  const EmiScreen({
    super.key,
    required this.totalAmount,
    required this.itemName,
  });

  @override
  State<EmiScreen> createState() => _EmiScreenState();
}

class _EmiScreenState extends State<EmiScreen> {
  int _selectedMonths = 3;

  int get _emiAmount => (widget.totalAmount / _selectedMonths).ceil();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: GlassAppBar(title: const Text('EMI Options')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total amount card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [HousepitalColors.orange, context.hc.orangeDark],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Total Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    DateHelper.formatCurrency(widget.totalAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.itemName,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // EMI plan selector
            const Text('Select EMI Plan', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 12),
            Row(
              children: [3, 6, 9].map((months) {
                final isSelected = _selectedMonths == months;
                final emi = (widget.totalAmount / months).ceil();
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMonths = months),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? context.hc.orangeLight : context.hc.white,
                        border: Border.all(
                          color: isSelected ? HousepitalColors.orange : context.hc.divider,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text('$months', style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w700,
                            color: isSelected ? HousepitalColors.orange : context.hc.grey,
                          )),
                          Text('months', style: TextStyle(fontSize: 12, color: context.hc.greyLight)),
                          const SizedBox(height: 8),
                          Text(
                            DateHelper.formatCurrency(emi),
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: isSelected ? context.hc.orangeText : context.hc.grey,
                            ),
                          ),
                          Text('/month', style: TextStyle(fontSize: 11, color: context.hc.greyLight)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'No-cost EMI - Zero processing fee',
                style: TextStyle(fontSize: 13, color: context.hc.success, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 24),

            // EMI schedule table
            const Text('EMI Schedule', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Column(
                children: [
                  // Header
                  Container(
                    color: context.hc.greyLighter,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Month', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text('Due Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  ...List.generate(_selectedMonths, (i) {
                    final dueDate = DateTime(now.year, now.month + i + 1, 1);
                    return Container(
                      color: i.isEven ? context.hc.white : context.hc.greyLighter.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text('Month ${i + 1}', style: const TextStyle(fontSize: 13))),
                          Expanded(flex: 2, child: Text(
                            '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                            style: TextStyle(fontSize: 13, color: context.hc.grey),
                          )),
                          Expanded(flex: 2, child: Text(
                            DateHelper.formatCurrency(_emiAmount),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.right,
                          )),
                        ],
                      ),
                    );
                  }),
                  // Total row
                  Container(
                    color: context.hc.orangeLight,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Expanded(flex: 4, child: Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                        Expanded(flex: 2, child: Text(
                          DateHelper.formatCurrency(widget.totalAmount),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.hc.orangeText),
                          textAlign: TextAlign.right,
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.hc.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: context.hc.success),
                  SizedBox(width: 8),
                  Text('Processing Fee: FREE', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: context.hc.success,
                  )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Select EMI plan button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'isEmi': true,
                    'emiMonths': _selectedMonths,
                    'emiAmount': _emiAmount,
                  });
                },
                child: const Text('Select EMI Plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
