import 'package:flutter/material.dart';
import '../../app/app_strings.dart';

class RateResult {
  final int productQuality;
  final int sizeFit;
  final int delivery;
  final int packaging;
  final String notes;

  RateResult({
    required this.productQuality,
    required this.sizeFit,
    required this.delivery,
    required this.packaging,
    required this.notes,
  });
}

Future<RateResult?> showRateExperienceDialog(
    BuildContext context, AppStrings s) {
  int quality = 0;
  int sizeFit = 0;
  int delivery = 0;
  int packaging = 0;
  final notesController = TextEditingController();

  return showDialog<RateResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: StatefulBuilder(
            builder: (context, setState) {
              Widget buildRow(String label, int value, ValueChanged<int> onSet) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (index) {
                          final filled = index < value;
                          return IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              filled ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            ),
                            onPressed: () => setState(() => onSet(index + 1)),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.rateDialogTitle, // "How Was Your Experience?"
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildRow(
                      s.rateProductQualityLabel,
                      quality,
                      (v) => quality = v,
                    ),
                    buildRow(
                      s.rateSizeFitLabel,
                      sizeFit,
                      (v) => sizeFit = v,
                    ),
                    buildRow(
                      s.rateDeliveryLabel,
                      delivery,
                      (v) => delivery = v,
                    ),
                    buildRow(
                      s.ratePackagingLabel,
                      packaging,
                      (v) => packaging = v,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.rateNotesLabel, // "Notes"
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: s.rateNotesHint,
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(
                                  context,
                                  RateResult(
                                    productQuality: quality,
                                    sizeFit: sizeFit,
                                    delivery: delivery,
                                    packaging: packaging,
                                    notes: notesController.text,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(s.rateSubmitButton), // "Submit"
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(s.rateCancelButton), // "Cancel"
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
