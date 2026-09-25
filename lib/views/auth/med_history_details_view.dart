import 'package:flutter/material.dart';
import 'package:resq/widgets/resq_ui.dart';

/// Result handed back to RegistrationWizView once the donor finishes this
/// follow-up form — see _openMedicalHistoryDetails in registration_wiz_view.dart.
class MedicalHistoryFollowUpResult {
  final String? majorMedicalHistoryDesc;
  final DateTime? transfusionOrSurgeryDate;
  final String? transfusionOrSurgeryDesc;
  final DateTime? travelOrNeedleDate;
  final String? travelOrNeedleDesc;

  const MedicalHistoryFollowUpResult({
    this.majorMedicalHistoryDesc,
    this.transfusionOrSurgeryDate,
    this.transfusionOrSurgeryDesc,
    this.travelOrNeedleDate,
    this.travelOrNeedleDesc,
  });
}

/// Shown right after Step 4 (Medical History) if the donor toggled "yes" on
/// Major Medical History, Transfusions/Surgeries, or Travel/Needle Sticks —
/// collects a date and short description for each flagged item so the
/// decision tree can judge deferral windows against a real date instead of
/// deferring forever just because the toggle was once set to "yes".
class MedicalHistoryDetailsView extends StatefulWidget {
  final bool needsMajorMedical;
  final bool needsTransfusion;
  final bool needsTravel;
  final String? initialMajorMedicalDesc;
  final DateTime? initialTransfusionDate;
  final String? initialTransfusionDesc;
  final DateTime? initialTravelDate;
  final String? initialTravelDesc;

  const MedicalHistoryDetailsView({
    super.key,
    required this.needsMajorMedical,
    required this.needsTransfusion,
    required this.needsTravel,
    this.initialMajorMedicalDesc,
    this.initialTransfusionDate,
    this.initialTransfusionDesc,
    this.initialTravelDate,
    this.initialTravelDesc,
  });

  @override
  State<MedicalHistoryDetailsView> createState() => _MedicalHistoryDetailsViewState();
}

class _MedicalHistoryDetailsViewState extends State<MedicalHistoryDetailsView> {
  late final TextEditingController _majorMedicalController;
  late final TextEditingController _transfusionController;
  late final TextEditingController _travelController;
  DateTime? _transfusionDate;
  DateTime? _travelDate;

  @override
  void initState() {
    super.initState();
    _majorMedicalController = TextEditingController(text: widget.initialMajorMedicalDesc ?? '');
    _transfusionController = TextEditingController(text: widget.initialTransfusionDesc ?? '');
    _travelController = TextEditingController(text: widget.initialTravelDesc ?? '');
    _transfusionDate = widget.initialTransfusionDate;
    _travelDate = widget.initialTravelDate;
  }

  @override
  void dispose() {
    _majorMedicalController.dispose();
    _transfusionController.dispose();
    _travelController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select a date';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _pickDate(ValueChanged<DateTime> onPicked, DateTime? current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: RQColors.blood, onPrimary: Colors.white, onSurface: RQColors.ink),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  void _submit() {
    if (widget.needsTransfusion && _transfusionDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the date of your transfusion/surgery.')),
      );
      return;
    }
    if (widget.needsTravel && _travelDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the date of your travel/needle-stick exposure.')),
      );
      return;
    }
    Navigator.pop(
      context,
      MedicalHistoryFollowUpResult(
        majorMedicalHistoryDesc:
            _majorMedicalController.text.trim().isEmpty ? null : _majorMedicalController.text.trim(),
        transfusionOrSurgeryDate: _transfusionDate,
        transfusionOrSurgeryDesc:
            _transfusionController.text.trim().isEmpty ? null : _transfusionController.text.trim(),
        travelOrNeedleDate: _travelDate,
        travelOrNeedleDesc: _travelController.text.trim().isEmpty ? null : _travelController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Numbered in the order the cards appear, so "1, 2, 3" always matches
    // what's on screen no matter which items were flagged.
    int n = 0;
    final cards = <Widget>[];
    if (widget.needsTransfusion) {
      n++;
      cards.add(_itemCard(
        number: n,
        title: 'Transfusion or surgery',
        isRequired: true,
        children: [
          _dateField(
            label: 'When did it happen?',
            value: _transfusionDate,
            onTap: () => _pickDate((d) => setState(() => _transfusionDate = d), _transfusionDate),
          ),
          const SizedBox(height: 12),
          RQTextField(controller: _transfusionController, label: 'What was it? (e.g. appendectomy)'),
        ],
      ));
    }
    if (widget.needsTravel) {
      n++;
      cards.add(_itemCard(
        number: n,
        title: 'Travel or needle-stick',
        isRequired: true,
        children: [
          _dateField(
            label: 'When did it happen?',
            value: _travelDate,
            onTap: () => _pickDate((d) => setState(() => _travelDate = d), _travelDate),
          ),
          const SizedBox(height: 12),
          RQTextField(controller: _travelController, label: 'Where did you go, or what happened?'),
        ],
      ));
    }
    if (widget.needsMajorMedical) {
      n++;
      cards.add(_itemCard(
        number: n,
        title: 'Major medical history',
        isRequired: false,
        children: [
          TextField(
            controller: _majorMedicalController,
            maxLines: 3,
            style: const TextStyle(fontSize: 15, height: 1.45, color: RQColors.ink),
            decoration: InputDecoration(
              labelText: 'Briefly describe the condition',
              hintText: 'e.g. Type 2 diabetes, diagnosed 2021, controlled with medicine',
              alignLabelWithHint: true,
              labelStyle: const TextStyle(fontSize: 13, color: RQColors.muted),
              floatingLabelStyle: const TextStyle(fontSize: 13, color: RQColors.blood, fontWeight: FontWeight.w500),
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: RQColors.fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: RQColors.blood, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Clinical staff will review this with you. It doesn't automatically stop you from donating.",
            style: TextStyle(fontSize: 12, height: 1.4, color: RQColors.muted),
          ),
        ],
      ));
    }

    return Scaffold(
      backgroundColor: RQColors.surface,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: RQColors.blood,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0x29FFFFFF),
                            fixedSize: const Size(44, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Step 4 of 5 · Follow-up',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('A few more details',
                        style: TextStyle(fontSize: 22, height: 1.35, fontWeight: FontWeight.w600, color: Colors.white)),
                    const Text(
                      'For each item you answered yes to, tell us when it happened so we can work out any waiting period.',
                      style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xE6FFFFFF)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    cards[i],
                  ],
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 15, color: RQColors.success),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Only clinical staff can see these answers.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF555555))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: RQColors.card,
              border: Border(top: BorderSide(color: RQColors.hairline)),
            ),
            child: RQButton(label: 'Continue to final screening', height: 54, onPressed: _submit),
          ),
        ],
      ),
    );
  }

  Widget _itemCard({
    required int number,
    required String title,
    required bool isRequired,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: RQColors.card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: RQColors.blood, shape: BoxShape.circle),
                child: Text('$number',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.ink)),
              ),
              isRequired
                  ? const RQPill(label: 'Date needed', background: RQColors.warningTint, color: RQColors.warning)
                  : const RQPill(label: 'Optional', background: RQColors.surface, color: Color(0xFF555555)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _dateField({required String label, required DateTime? value, required VoidCallback onTap}) {
    return Material(
      color: RQColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: RQColors.fieldBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, color: RQColors.muted)),
                    Text(
                      _formatDate(value),
                      style: TextStyle(fontSize: 15, color: value != null ? RQColors.ink : const Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.calendar_month_outlined, size: 20, color: RQColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}