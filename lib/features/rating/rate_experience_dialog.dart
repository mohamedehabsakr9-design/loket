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

Future<RateResult?> showRateExperienceDialog(BuildContext context, AppStrings s) {
  int quality = 0;
  int sizeFit = 0;
  int delivery = 0;
  int packaging = 0;
  final notesController = TextEditingController();

  return showDialog<RateResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        child: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.rateDialogTitle,
                    style: const TextStyle(
                      fontSize: 19,
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _RatingRow(
                    label: s.rateProductQualityLabel,
                    value: quality,
                    onChanged: (v) => setState(() => quality = v),
                  ),
                  _RatingRow(
                    label: s.rateSizeFitLabel,
                    value: sizeFit,
                    onChanged: (v) => setState(() => sizeFit = v),
                  ),
                  _RatingRow(
                    label: s.rateDeliveryLabel,
                    value: delivery,
                    onChanged: (v) => setState(() => delivery = v),
                  ),
                  _RatingRow(
                    label: s.ratePackagingLabel,
                    value: packaging,
                    onChanged: (v) => setState(() => packaging = v),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.rateNotesLabel,
                    style: const TextStyle(fontSize: 17, color: Colors.black, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    minLines: 3,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: s.rateNotesHint,
                      hintStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: const BorderSide(color: Color(0xFF1D282E)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                RateResult(
                                  productQuality: quality,
                                  sizeFit: sizeFit,
                                  delivery: delivery,
                                  packaging: packaging,
                                  notes: notesController.text.trim(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xFF1D282E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            ),
                            child: Text(
                              s.rateSubmitButton,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1D282E),
                              side: const BorderSide(color: Color(0xFF1D282E)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            ),
                            child: Text(
                              s.rateCancelButton,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
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
      );
    },
  );
}

class _RatingRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _RatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 17, color: Colors.black, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              final filled = index < value;
              return InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onChanged(index + 1),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFFFA000),
                    size: 19,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
