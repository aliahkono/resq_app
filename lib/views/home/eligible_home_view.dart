import 'package:flutter/material.dart';
import 'package:resq/widgets/resq_ui.dart';

class EmergencyBloodRequest {
  final String id;
  final String hospital;
  // The real hospitals.id this broadcast came from (GET /api/donor/requests
  // — see listOpenRequestsForDonor) — needed so "Reserve Slot" can book at
  // the actual hospital instead of dropping the donor into a blank picker.
  final String hospitalId;
  final String bloodType;
  final String urgency;
  final String distance;
  final int unitsNeeded;
  final String timeAgo;

  EmergencyBloodRequest({
    required this.id,
    required this.hospital,
    this.hospitalId = '',
    required this.bloodType,
    required this.urgency,
    required this.distance,
    required this.unitsNeeded,
    required this.timeAgo,
  });
}

class EligibleHomeView extends StatelessWidget {
  final bool isFirstTimeDonor;
  final String donorName;
  final String bloodType;
  final List<EmergencyBloodRequest> activeRequests;
  final Function(EmergencyBloodRequest)? onAcceptRequest;
  final String token;
  // Shared with NoActiveSchedView's booking flow (see home_view.dart) so
  // every "book an appointment" entry point in the app ends up updating the
  // real _confirmedAppointment state from the backend's actual response.
  final void Function(Map<String, dynamic> appointment) onBookingCompleted;
  // Re-fetches both the Priority Request Feed (GET /api/donor/requests) and
  // the notification bell (GET /api/donor/notifications) — see
  // home_view.dart's _refreshBroadcastData.
  final Future<void> Function()? onRefresh;
  // Hospital-verified lifetime donation count (see DonorProfileView's field
  // of the same name) — the impact card derives its stats from this.
  final int totalDonations;
  final bool isVerified;
  // Switches HomeView to the Appointment tab — that tab (NoActiveSchedView)
  // already knows how to show either "book now" or the waiting state.
  final VoidCallback? onSwitchToAppointmentTab;

  const EligibleHomeView({
    super.key,
    this.isFirstTimeDonor = false,
    this.donorName = '',
    this.bloodType = '',
    this.activeRequests = const [],
    this.onAcceptRequest,
    required this.token,
    required this.onBookingCompleted,
    this.onRefresh,
    this.totalDonations = 0,
    this.isVerified = false,
    this.onSwitchToAppointmentTab,
  });

  String get _firstName {
    final n = donorName.trim();
    if (n.isEmpty) return 'there';
    return n.split(RegExp(r'\s+')).first;
  }

  String get _bloodLabel => bloodType.isNotEmpty ? bloodType : '—';

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.only(bottom: 28),
      children: isFirstTimeDonor ? _buildFirstTimeDonorView(context) : _buildActiveDonorView(context),
    );
    return Scaffold(
      backgroundColor: RQColors.surface,
      body: onRefresh != null
          ? RefreshIndicator(color: RQColors.blood, onRefresh: onRefresh!, child: content)
          : content,
    );
  }

  // ===========================================================================
  // RETURNING DONOR
  // ===========================================================================
  List<Widget> _buildActiveDonorView(BuildContext context) {
    return [
      _heroWithBand(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const RQPill(
                  label: 'ELIGIBLE TO DONATE',
                  background: RQColors.successTint,
                  color: RQColors.success,
                  dot: true,
                  uppercase: true,
                ),
                const Spacer(),
                if (isVerified)
                  const Text('Verified donor', style: TextStyle(fontSize: 12, color: RQColors.muted)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _bloodBadgeLarge(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "You're ready to save lives, $_firstName",
                        style: const TextStyle(fontSize: 19, height: 1.35, fontWeight: FontWeight.w600, color: RQColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bloodType.isNotEmpty
                            ? 'Your $bloodType blood is on standby for hospital broadcasts.'
                            : "You're on standby for hospital broadcasts.",
                        style: const TextStyle(fontSize: 13, height: 1.45, color: RQColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _miniTile('DONATIONS', '$totalDonations', 'on record')),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniTile(
                    'ACCOUNT',
                    isVerified ? 'Verified' : 'Not verified',
                    isVerified ? 'ID checked' : 'Verify in Profile',
                    valueColor: isVerified ? RQColors.success : RQColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RQButton(
              label: 'Book a donation',
              icon: Icons.calendar_month_outlined,
              onPressed: onSwitchToAppointmentTab,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _sectionHeader('Urgent requests near you', count: activeRequests.length),
      const SizedBox(height: 10),
      if (activeRequests.isEmpty)
        _buildStandbyEmptyState()
      else
        ...activeRequests.map((req) => _buildRequestCard(req)),
      const SizedBox(height: 16),
      _buildImpactCard(),
      const SizedBox(height: 16),
      _buildLearnCard(context),
    ];
  }

  // ===========================================================================
  // FIRST-TIME DONOR
  // ===========================================================================
  List<Widget> _buildFirstTimeDonorView(BuildContext context) {
    return [
      _heroWithBand(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                RQPill(
                  label: 'ELIGIBLE',
                  background: RQColors.successTint,
                  color: RQColors.success,
                  dot: true,
                  uppercase: true,
                ),
                SizedBox(width: 8),
                RQPill(
                  label: 'FIRST-TIME DONOR',
                  background: RQColors.bloodTint,
                  color: RQColors.bloodText,
                  uppercase: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Welcome, $_firstName. Your first donation starts here.',
              style: const TextStyle(fontSize: 20, height: 1.4, fontWeight: FontWeight.w600, color: RQColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'First-time donors get priority booking. The whole visit takes under 45 minutes.',
              style: TextStyle(fontSize: 13, height: 1.5, color: RQColors.muted),
            ),
            const SizedBox(height: 16),
            RQButton(
              label: 'Book your first donation',
              icon: Icons.calendar_month_outlined,
              onPressed: onSwitchToAppointmentTab,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _sectionHeader('Your donor journey'),
      const SizedBox(height: 10),
      _card(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          children: [
            _journeyStep(state: _StepState.done, title: 'Account created', subtitle: 'Welcome to ResQ', lineDone: true),
            _journeyStep(
              state: _StepState.done,
              title: 'Health screening passed',
              subtitle: 'You meet the donor requirements',
              lineDone: false,
              lineAccent: true,
            ),
            _journeyStep(
              state: _StepState.current,
              title: 'Book your first appointment',
              subtitle: "You're here",
              lineDone: false,
            ),
            _journeyStep(
              state: _StepState.upcoming,
              title: 'Donate and get your donor card',
              subtitle: 'Your Digital Health Card unlocks after',
              last: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _sectionHeader('What to expect'),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _expectTile(Icons.schedule_rounded, 'Under 45 min', 'Includes sign-in and a mini-physical')),
            const SizedBox(width: 10),
            Expanded(child: _expectTile(Icons.water_drop_outlined, '8–10 min draw', 'Just a quick pinch')),
            const SizedBox(width: 10),
            Expanded(child: _expectTile(Icons.local_cafe_outlined, 'Snacks after', 'Rest and refreshments')),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _linkCard(
        icon: Icons.menu_book_outlined,
        title: 'Read the step-by-step guide',
        subtitle: 'Registration, mini-physical, donation, rest',
        onTap: () => _showWalkthroughSheet(context),
      ),
      const SizedBox(height: 24),
      _sectionHeader('Urgent requests near you', count: activeRequests.length),
      const SizedBox(height: 10),
      if (activeRequests.isEmpty)
        _buildStandbyEmptyState()
      else
        ...activeRequests.map((req) => _buildRequestCard(req)),
    ];
  }

  // ===========================================================================
  // Building blocks
  // ===========================================================================

  /// Red band continuing the app bar, with the hero card overlapping it.
  Widget _heroWithBand(Widget child) {
    return Stack(
      children: [
        Container(height: 84, color: RQColors.blood),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: RQColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x0F1B1416), blurRadius: 2, offset: Offset(0, 1)),
                BoxShadow(color: Color(0x1A1B1416), blurRadius: 28, offset: Offset(0, 10)),
              ],
            ),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _bloodBadgeLarge() {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(color: RQColors.blood, borderRadius: BorderRadius.circular(18)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.water_drop_rounded, size: 14, color: Colors.white),
          Text(_bloodLabel, style: const TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _miniTile(String label, String value, String caption, {Color valueColor = RQColors.ink}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: RQColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: RQColors.muted)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: valueColor)),
          Text(caption, style: const TextStyle(fontSize: 12, color: RQColors.muted)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {int? count}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Flexible(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: RQColors.bloodText)),
          ),
          if (count != null && count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: RQColors.blood, borderRadius: BorderRadius.circular(999)),
              child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: padding,
      decoration: BoxDecoration(color: RQColors.card, borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }

  Widget _buildStandbyEmptyState() {
    return _card(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: const Column(
        children: [
          RQIconBox(icon: Icons.sensors_rounded, size: 52),
          SizedBox(height: 12),
          Text('No urgent requests right now',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.ink)),
          SizedBox(height: 4),
          Text(
            "Nearby hospitals have enough blood for now. We'll alert you the moment one needs your type.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: RQColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _urgencyTag(String urgency) {
    final u = urgency.toLowerCase();
    if (u.contains('crit') || u.contains('emerg')) {
      return const RQPill(label: 'CRITICAL', background: RQColors.blood, color: Colors.white, uppercase: true, radius: 6);
    }
    if (u.contains('urg') || u.contains('high')) {
      return const RQPill(label: 'URGENT', background: RQColors.warningTint, color: RQColors.warning, uppercase: true, radius: 6);
    }
    return RQPill(
      label: urgency.isNotEmpty ? urgency.toUpperCase() : 'OPEN',
      background: RQColors.successTint,
      color: RQColors.success,
      uppercase: true,
      radius: 6,
    );
  }

  Widget _buildRequestCard(EmergencyBloodRequest req) {
    final u = req.urgency.toLowerCase();
    final bool critical = u.contains('crit') || u.contains('emerg');
    final subtitle = [req.distance, req.timeAgo].where((s) => s.trim().isNotEmpty).join(' · ');
    final VoidCallback? accept = onAcceptRequest != null ? () => onAcceptRequest!(req) : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: RQColors.card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 60,
                decoration: BoxDecoration(color: RQColors.bloodTint, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(req.bloodType,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: RQColors.bloodText)),
                    Text('${req.unitsNeeded} ${req.unitsNeeded == 1 ? 'unit' : 'units'}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: RQColors.bloodText)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _urgencyTag(req.urgency),
                    const SizedBox(height: 6),
                    Text(req.hospital,
                        style: const TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w600, color: RQColors.ink)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: RQColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          critical
              ? RQButton(label: 'Reserve slot', height: 44, onPressed: accept)
              : RQButton.secondary(label: 'Reserve slot', height: 44, color: RQColors.blood, onPressed: accept),
        ],
      ),
    );
  }

  Widget _buildImpactCard() {
    final n = totalDonations;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RQSectionLabel('Your impact'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _impactStat('$n', n == 1 ? 'donation' : 'donations', RQColors.bloodText)),
              Expanded(child: _impactStat('${(n * 0.45).toStringAsFixed(n == 0 ? 0 : 2)} L', 'blood given', RQColors.bloodText)),
              Expanded(child: _impactStat('${n * 3}', 'lives helped', RQColors.success)),
            ],
          ),
          if (n == 0) ...[
            const SizedBox(height: 8),
            const Text('Your stats grow each time a hospital confirms a donation.',
                style: TextStyle(fontSize: 12, color: RQColors.muted)),
          ],
        ],
      ),
    );
  }

  Widget _impactStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: RQColors.muted)),
      ],
    );
  }

  Widget _buildLearnCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: RQColors.navy,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showWhatHappensSheet(context),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0x24FFFFFF), borderRadius: BorderRadius.all(Radius.circular(14))),
                    child: Icon(Icons.bloodtype_outlined, color: Colors.white, size: 24),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What happens to your blood?',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                      Text('See how one donation helps up to three patients',
                          style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xE6FFFFFF))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _linkCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: RQColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                RQIconBox(icon: icon, background: RQColors.navyTint, color: RQColors.navy),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: RQColors.ink)),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: RQColors.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: RQColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _expectTile(IconData icon, String title, String caption) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(color: RQColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RQIconBox(icon: icon, size: 36),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w600, color: RQColors.ink)),
          const SizedBox(height: 2),
          Text(caption, style: const TextStyle(fontSize: 11, height: 1.35, color: RQColors.muted)),
        ],
      ),
    );
  }

  Widget _journeyStep({
    required _StepState state,
    required String title,
    required String subtitle,
    bool lineDone = false,
    bool lineAccent = false,
    bool last = false,
  }) {
    Widget dot;
    switch (state) {
      case _StepState.done:
        dot = Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: RQColors.success, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
        );
        break;
      case _StepState.current:
        dot = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: RQColors.blood, width: 3),
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: RQColors.blood, shape: BoxShape.circle),
            ),
          ),
        );
        break;
      case _StepState.upcoming:
        dot = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: RQColors.hairline, width: 3),
          ),
        );
        break;
    }

    final Color lineColor = lineDone ? RQColors.success : (lineAccent ? RQColors.blood : RQColors.hairline);
    final bool current = state == _StepState.current;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              dot,
              if (!last) Expanded(child: Container(width: 2, color: lineColor)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: current ? RQColors.blood : (state == _StepState.upcoming ? RQColors.muted : RQColors.ink),
                    ),
                  ),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: RQColors.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Sheets
  // ===========================================================================

  void _showWalkthroughSheet(BuildContext context) {
    const steps = [
      ['Registration', 'Quick ID check and a short intake form.'],
      ['Mini-physical', 'Blood pressure, pulse and a hemoglobin finger-prick.'],
      ['The donation', '8–10 minutes resting comfortably while 1 unit is drawn.'],
      ['Recovery', 'Free snacks and drinks, then a short rest before heading home.'],
    ];
    showResQSheet(
      context: context,
      builder: (ctx) => ResQSheet(
        icon: Icons.menu_book_outlined,
        title: 'Step-by-step walkthrough',
        subtitle: 'What happens at your first donation',
        footer: RQButton(label: 'Got it', onPressed: () => Navigator.pop(ctx)),
        child: Column(
          children: [
            for (int i = 0; i < steps.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: RQColors.blood, shape: BoxShape.circle),
                      child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(steps[i][0],
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.ink)),
                          Text(steps[i][1], style: const TextStyle(fontSize: 13, height: 1.5, color: RQColors.body)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showWhatHappensSheet(BuildContext context) {
    const parts = [
      [Icons.bloodtype_outlined, 'Red blood cells', 'Help patients who lost blood in surgery, childbirth or accidents.'],
      [Icons.opacity_rounded, 'Plasma', 'Used for burns, liver disease and clotting problems.'],
      [Icons.grain_rounded, 'Platelets', 'Help patients with dengue, cancer treatment and bleeding disorders.'],
    ];
    showResQSheet(
      context: context,
      builder: (ctx) => ResQSheet(
        icon: Icons.bloodtype_outlined,
        title: 'What happens to your blood?',
        subtitle: 'One donation is separated into three parts',
        footer: RQButton(label: 'Got it', onPressed: () => Navigator.pop(ctx)),
        child: Column(
          children: [
            for (final p in parts)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RQIconBox(icon: p[0] as IconData, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p[1] as String,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.ink)),
                          Text(p[2] as String, style: const TextStyle(fontSize: 13, height: 1.5, color: RQColors.body)),
                        ],
                      ),
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

enum _StepState { done, current, upcoming }