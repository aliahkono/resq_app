import 'package:flutter/material.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/widgets/resq_ui.dart';

/// The malaria symptom check (POST /api/donor/me/malaria-check). The app
/// can't check symptoms itself, so a donor with a malaria exposure answers
/// this: at the end of the waiting period to be eligible again, or any time
/// during it to report fever or other symptoms (which restarts the wait:
/// 3 years after they end). Returns true once an answer was saved.
Future<bool> showMalariaCheckSheet(BuildContext context, {required String token, bool waitIsOver = true}) async {
  bool? hadSymptoms;
  bool? symptomsEnded;
  DateTime? endDate;
  bool saving = false;
  String? error;

  Future<void> submit(BuildContext ctx, StateSetter setModalState) async {
    if (hadSymptoms == null) {
      setModalState(() => error = 'Choose Yes or No.');
      return;
    }
    if (hadSymptoms == true && symptomsEnded == null) {
      setModalState(() => error = 'Tell us if your symptoms have ended.');
      return;
    }
    if (hadSymptoms == true && symptomsEnded == true && endDate == null) {
      setModalState(() => error = 'Choose the date your symptoms ended.');
      return;
    }
    setModalState(() {
      saving = true;
      error = null;
    });
    try {
      await ApiService.submitMalariaCheck(
        token,
        hadSymptoms: hadSymptoms!,
        symptomsOngoing: hadSymptoms == true && symptomsEnded == false,
        symptomsEndDate: hadSymptoms == true && symptomsEnded == true ? endDate : null,
      );
      if (ctx.mounted) Navigator.pop(ctx, true);
    } on ApiException catch (e) {
      setModalState(() {
        saving = false;
        error = e.message;
      });
    } catch (_) {
      setModalState(() {
        saving = false;
        error = 'Could not reach the ResQ server.';
      });
    }
  }

  final saved = await showResQSheet<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => ResQSheet(
        icon: Icons.health_and_safety_outlined,
        title: 'Malaria health check',
        subtitle: waitIsOver
            ? 'Your waiting period is over. Answer this to donate again.'
            : 'Tell us if you have felt unwell since your trip.',
        footer: RQButton(
          label: 'Submit',
          loading: saving,
          onPressed: () => submit(ctx, setModalState),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Since your trip or exposure, have you had fever, chills, sweating or a flu-like illness?',
              style: TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w500, color: RQColors.ink),
            ),
            const SizedBox(height: 10),
            _YesNo(
              value: hadSymptoms,
              enabled: !saving,
              onChanged: (v) => setModalState(() {
                hadSymptoms = v;
                error = null;
              }),
            ),
            if (hadSymptoms == true) ...[
              const SizedBox(height: 18),
              const Text(
                'Have the symptoms ended?',
                style: TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w500, color: RQColors.ink),
              ),
              const SizedBox(height: 10),
              _YesNo(
                value: symptomsEnded,
                enabled: !saving,
                onChanged: (v) => setModalState(() {
                  symptomsEnded = v;
                  error = null;
                }),
              ),
              if (symptomsEnded == true) ...[
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: saving
                      ? null
                      : () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: endDate ?? now,
                            firstDate: DateTime(now.year - 5),
                            lastDate: now,
                          );
                          if (picked != null) {
                            setModalState(() {
                              endDate = picked;
                              error = null;
                            });
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: RQColors.fieldBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            endDate == null
                                ? 'Date the symptoms ended'
                                : 'Ended ${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 14,
                              color: endDate == null ? RQColors.muted : RQColors.ink,
                            ),
                          ),
                        ),
                        const Icon(Icons.calendar_today_outlined, size: 18, color: RQColors.muted),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                symptomsEnded == false
                    ? 'Please get checked at a doctor or health center. You can donate 3 years after your symptoms end.'
                    : 'You can donate 3 years after your symptoms ended. If you have not been checked yet, see a doctor or health center.',
                style: const TextStyle(fontSize: 13, height: 1.5, color: RQColors.body),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 14),
              Text(error!, style: const TextStyle(fontSize: 13, color: RQColors.blood)),
            ],
          ],
        ),
      ),
    ),
  );
  return saved == true;
}

class _YesNo extends StatelessWidget {
  final bool? value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _YesNo({required this.value, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool optionValue) {
      final selected = value == optionValue;
      return Expanded(
        child: OutlinedButton(
          onPressed: enabled ? () => onChanged(optionValue) : null,
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? RQColors.bloodTint : Colors.white,
            foregroundColor: selected ? RQColors.bloodText : RQColors.ink,
            side: BorderSide(color: selected ? RQColors.blood : RQColors.hairline, width: 1.5),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Row(
      children: [
        option('Yes', true),
        const SizedBox(width: 12),
        option('No', false),
      ],
    );
  }
}
