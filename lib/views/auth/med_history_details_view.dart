import 'package:flutter/material.dart';

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
    if (date == null) return 'Select Date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDate(ValueChanged<DateTime> onPicked, DateTime? current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7D1B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'A Few More Details',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2EDFE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You flagged one or more items in your Medical History. Please give us a bit more detail so we can accurately assess your eligibility window.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (widget.needsMajorMedical) ...[
                _buildSectionCard(
                  title: 'Major Medical History',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Please briefly describe the condition(s):',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _majorMedicalController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'e.g., Type 2 Diabetes, diagnosed 2021',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.needsTransfusion) ...[
                _buildSectionCard(
                  title: 'Transfusion or Surgery',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('When did this happen?', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
                      const SizedBox(height: 8),
                      _buildDateButton(
                        _formatDate(_transfusionDate),
                        () => _pickDate((d) => setState(() => _transfusionDate = d), _transfusionDate),
                      ),
                      const SizedBox(height: 12),
                      const Text('Briefly describe:', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _transfusionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g., Appendectomy',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.needsTravel) ...[
                _buildSectionCard(
                  title: 'Travel or Needle Stick',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('When did this happen?', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
                      const SizedBox(height: 8),
                      _buildDateButton(
                        _formatDate(_travelDate),
                        () => _pickDate((d) => setState(() => _travelDate = d), _travelDate),
                      ),
                      const SizedBox(height: 12),
                      const Text('Briefly describe:', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _travelController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'e.g., Travel to a malaria-risk area',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7D1B22),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0,
                  ),
                  child: const Text('CONTINUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7D1B22))),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildDateButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF7D1B22),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
            const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}