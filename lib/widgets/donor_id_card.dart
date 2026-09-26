import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Everything the physical-style donor ID card (front + back) prints.
/// Built by DigitalHealthCardView from the donor's own profile data —
/// the card widgets themselves never fetch anything.
class DonorCardData {
  final String surname;
  final String givenNames;
  final String bloodType;
  final String sex; // "M" | "F" | "—"
  final DateTime? birthDate;
  final int completedDonations;

  /// Human-facing donor code (e.g. "D-1234") — the same value the QR pass
  /// encodes, so scanning either one resolves to the same record.
  final String donorCode;
  final DateTime? issuedAt;
  final String? photoUrl;

  // Back of card
  final String registeredFacility;
  final String registeredAddress;
  final String emergencyContact; // already formatted "NAME · PHONE"
  final List<DonationRecordEntry> recentDonations;
  final DateTime? lastDonationAt;
  final DateTime? nextEligibleAt;

  const DonorCardData({
    required this.surname,
    required this.givenNames,
    required this.bloodType,
    required this.sex,
    required this.birthDate,
    required this.completedDonations,
    required this.donorCode,
    required this.issuedAt,
    required this.photoUrl,
    required this.registeredFacility,
    required this.registeredAddress,
    required this.emergencyContact,
    required this.recentDonations,
    required this.lastDonationAt,
    required this.nextEligibleAt,
  });

  /// Cards are valid for two years from issue.
  DateTime? get validUntil =>
      issuedAt == null ? null : DateTime(issuedAt!.year + 2, issuedAt!.month, issuedAt!.day);

  /// Digits of the donor code, zero-padded to 6 (e.g. "D-4817" -> "004817").
  String get codeDigits {
    final digits = donorCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '000000';
    return digits.length >= 6 ? digits.substring(digits.length - 6) : digits.padLeft(6, '0');
  }
}

class DonationRecordEntry {
  final DateTime date;
  final String place;
  final String code; // e.g. "DON-07"

  const DonationRecordEntry({required this.date, required this.place, required this.code});
}

// ---------------------------------------------------------------------------
// Shared tokens (from Figma: DHC-Screen / DHC2-Screen, ResQKineme file)
// ---------------------------------------------------------------------------

/// Design-space size of both card faces. Faces are laid out at this exact
/// size (the Figma values use sub-pixel type, e.g. 3.767px) and scaled to
/// the available width with a FittedBox, so proportions never drift.
const Size kDonorCardDesignSize = Size(369, 222);

const _cardBg = Color(0xFFFFFDFC);
const _maroon = Color(0xFF7D0B1E);
const _ink = Color(0xFF1A191D);
const _inkBack = Color(0xFF211C1D);
const _label = Color(0xFF706E74);
const _muted = Color(0xFF776B6D);
const _hairline = Color(0xFFDDCFD1);
const _blush = Color(0xFFF7E7EA);

const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

String formatCardDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
}

TextStyle _poppins(double size, FontWeight weight, Color color, {double? spacing, double? height}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, height: height);

TextStyle _mono(double size, FontWeight weight, Color color, {double? spacing}) =>
    GoogleFonts.robotoMono(fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing);

/// Wraps a card face: rounded corners, card shadow, design-size layout
/// scaled to fit the width it's given.
class DonorCardFrame extends StatelessWidget {
  final Widget child;
  final double radius;
  final List<BoxShadow> shadows;

  const DonorCardFrame({super.key, required this.child, required this.radius, required this.shadows});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: kDonorCardDesignSize.width / kDonorCardDesignSize.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / kDonorCardDesignSize.width;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(radius * scale),
              boxShadow: shadows
                  .map((s) => BoxShadow(
                        color: s.color,
                        offset: s.offset * scale,
                        blurRadius: s.blurRadius * scale,
                      ))
                  .toList(),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius * scale),
              child: FittedBox(
                fit: BoxFit.fill,
                // The face is a fixed-size print layout that already scales
                // as a whole — system font scaling on top of that would push
                // fields out of their slots, so it's turned off in here.
                child: MediaQuery.withNoTextScaling(
                  child: SizedBox.fromSize(size: kDonorCardDesignSize, child: child),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Faint concentric guilloché-style rings in the card's bottom-right corner.
class _CardRingsPainter extends CustomPainter {
  final List<Rect> rings;

  const _CardRingsPainter(this.rings);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0xFF9E1C22).withValues(alpha: 0.10);
    for (final r in rings) {
      canvas.drawOval(r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CardRingsPainter oldDelegate) => false;
}

/// Converts Figma's right/bottom/width/height ellipse boxes into rects in
/// card coordinates.
List<Rect> _ringsFromFigma(List<List<double>> boxes) {
  final w = kDonorCardDesignSize.width;
  final h = kDonorCardDesignSize.height;
  return boxes
      .map((b) => Rect.fromLTWH(w - b[0] - b[2], h - b[1] - b[3], b[2], b[3]))
      .toList();
}

// ---------------------------------------------------------------------------
// FRONT
// ---------------------------------------------------------------------------

class DonorIdCardFront extends StatelessWidget {
  final DonorCardData data;

  const DonorIdCardFront({super.key, required this.data});

  // [right, bottom, width, height] from node 1645:1095 … 1645:1101
  static final _rings = _ringsFromFigma(const [
    [-28.25, -28.51, 213.779, 205.774],
    [-20.25, -20.5, 194.002, 185.998],
    [-12.24, -13.44, 173.755, 167.633],
    [-4.24, -5.43, 153.978, 147.856],
    [3.77, 2.57, 133.73, 128.55],
    [11.77, 10.1, 113.953, 109.244],
    [19.78, 17.64, 93.705, 90.409],
  ]);

  @override
  Widget build(BuildContext context) {
    return DonorCardFrame(
      radius: 13.185,
      shadows: const [BoxShadow(color: Color(0x304B2020), offset: Offset(0, 5.651), blurRadius: 14.126)],
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _CardRingsPainter(_rings)),
          Column(
            children: [
              // Return notice band
              Container(
                height: 16.952,
                width: double.infinity,
                color: _maroon,
                alignment: Alignment.center,
                child: Text(
                  'BLOOD DONOR • DONOR NG DUGO • RESQ • BLOOD DONOR • DONOR NG DUGO • RESQ',
                  maxLines: 1,
                  style: _poppins(4.709, FontWeight.w700, Colors.white, spacing: 0.4709),
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _donorStripe(),
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 194.944,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _leftPanel(),
                                Expanded(child: _rightPanel()),
                              ],
                            ),
                          ),
                          Expanded(child: _securityFooter()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _donorStripe() {
    return Container(
      width: 24.486,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFE5E1DD), width: 0.471)),
      ),
      alignment: Alignment.center,
      child: RotatedBox(
        quarterTurns: 3,
        child: Text(
          'DONOR',
          style: GoogleFonts.inter(
            fontSize: 14.126,
            fontWeight: FontWeight.w900,
            color: const Color(0x3B9E1C22),
          ),
        ),
      ),
    );
  }

  Widget _leftPanel() {
    final hasPhoto = data.photoUrl != null && data.photoUrl!.isNotEmpty;
    return SizedBox(
      width: 99.827,
      child: Stack(
        children: [
          // Divider
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Container(
              width: 1.884,
              decoration: BoxDecoration(
                color: const Color(0xFFEEDCDE),
                borderRadius: BorderRadius.circular(0.942),
              ),
            ),
          ),
          // Portrait
          Positioned(
            left: 11.77,
            top: 16.95,
            width: 74.399,
            height: 104.064,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3ECED),
                border: Border.all(color: _hairline, width: 0.942),
                borderRadius: BorderRadius.circular(5.651),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5.651),
                child: hasPhoto
                    ? Image.network(
                        data.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _portraitPlaceholder(),
                      )
                    : _portraitPlaceholder(),
              ),
            ),
          ),
          // Signature area
          Positioned(
            left: 7.06,
            right: 12.24,
            top: 131.38,
            height: 32.02,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _hairline, width: 0.471),
                borderRadius: BorderRadius.circular(3.767),
              ),
              padding: const EdgeInsets.only(top: 18.36, left: 4.24, right: 4.24),
              child: Text(
                'Signature · Lagda',
                textAlign: TextAlign.center,
                style: _poppins(3.767, FontWeight.w400, _muted, spacing: 0.226),
              ),
            ),
          ),
          Positioned(
            left: 7.06,
            right: 12.71,
            top: 167.16,
            child: Text(
              'Keep this card with you. Present at every blood donation.',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _poppins(3.767, FontWeight.w400, const Color(0xFFA89496), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _portraitPlaceholder() {
    return const Center(
      child: Icon(Icons.person_rounded, size: 44, color: Color(0xFFCDBBBE)),
    );
  }

  Widget _rightPanel() {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Header brand
        Positioned(
          left: 13.18,
          top: 15.07,
          child: SizedBox(
            height: 24.015,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 19.3,
                  height: 24.015,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Icon(Icons.water_drop_rounded, color: Color(0xFF9E1C22)),
                  ),
                ),
                const SizedBox(width: 4.24),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text('ResQ', style: GoogleFonts.inter(fontSize: 14.126, fontWeight: FontWeight.w800, color: _ink, height: 1.0)),
                    Positioned(
                      left: 0,
                      top: 16.95,
                      child: Text(
                        'BLOOD DONOR ID CARD • PAGKAKAKILANLAN NG DONOR',
                        maxLines: 1,
                        style: GoogleFonts.inter(fontSize: 3.296, fontWeight: FontWeight.w700, color: _label),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Form fields
        Positioned(
          left: 11.77,
          top: 32.49,
          width: 232.144,
          height: 150,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field('Surname / Apelyido', data.surname, width: 131.846),
                    _field('Blood type / Uri ng dugo', data.bloodType, width: 61.685, wrapLabel: true),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 38.61,
                child: _field('Given names / Pangalan', data.givenNames, gap: 1.413),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 69.22,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _field('Birth date / Kapanganakan', formatCardDate(data.birthDate), width: 75.341),
                    const SizedBox(width: 22.602),
                    _field('Sex / Kasarian', data.sex, width: 37.67),
                    const SizedBox(width: 22.602),
                    _field('Donations / Donasyon', data.completedDonations.toString().padLeft(2, '0'), width: 64.04),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 97.47,
                child: _field('Donor ID / Numero ng donor', data.donorCode),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 123.84,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _field('Issued / Petsa ng pagbigay', formatCardDate(data.issuedAt), width: 103.594),
                    _field('Valid until / Balido hanggang', formatCardDate(data.validUntil), width: 103.594),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String label, String value, {double? width, double gap = 0.942, bool wrapLabel = false}) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: wrapLabel ? 2 : 1,
          softWrap: wrapLabel,
          style: _poppins(5.651, FontWeight.w600, _label),
        ),
        SizedBox(height: gap),
        Text(
          value.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _poppins(8.476, FontWeight.w700, _ink),
        ),
      ],
    );
    return width == null ? column : SizedBox(width: width, child: column);
  }

  Widget _securityFooter() {
    return Container(
      color: _blush,
      padding: const EdgeInsets.symmetric(horizontal: 13.185),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'SAVE A LIFE MAGSAVE NG BUHAY • RESQ SAVE A LIFE MAGSAVE NG BUHAY • RESQ SAVE A LIFE',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: _poppins(3.767, FontWeight.w400, _maroon),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'PHL-RQ • ${data.codeDigits} • ${data.issuedAt?.year ?? DateTime.now().year}',
            style: _mono(3.767, FontWeight.w400, _maroon),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BACK
// ---------------------------------------------------------------------------

class DonorIdCardBack extends StatelessWidget {
  final DonorCardData data;

  /// Payload encoded in the verification QR.
  final String qrData;

  const DonorIdCardBack({super.key, required this.data, required this.qrData});

  // [right, bottom, width, height] from node 1650:1148 … 1650:1154
  static final _rings = _ringsFromFigma(const [
    [-29.5, -30, 227, 218.5],
    [-21, -21.5, 206, 197.5],
    [-12.5, -14, 184.5, 178],
    [-4, -5.5, 163.5, 157],
    [4.5, 3, 142, 136.5],
    [13, 11, 121, 116],
    [21.5, 19, 99.5, 96],
  ]);

  @override
  Widget build(BuildContext context) {
    return DonorCardFrame(
      radius: 14,
      shadows: const [BoxShadow(color: Color(0x214B2020), offset: Offset(0, 6), blurRadius: 15)],
      child: Stack(
        children: [
          // Return notice band
          Positioned(
            left: 0,
            right: 0.5,
            top: 0,
            height: 20,
            child: Container(
              color: _maroon,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'IF FOUND • KUNG NATAGPUAN • RETURN TO ANY RESQ PARTNER BLOOD BANK',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: _poppins(5, FontWeight.w700, Colors.white, spacing: 0.45),
                    ),
                  ),
                  Text(data.donorCode, style: _mono(5, FontWeight.w400, Colors.white)),
                ],
              ),
            ),
          ),
          // Back body
          Positioned(
            left: 0,
            right: 0.5,
            top: 20,
            height: 169,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: 17,
                    right: 18.5,
                    top: 10,
                    height: 89,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _organizationDetails()),
                        const SizedBox(width: 10),
                        _qrVerification(),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 17,
                    right: 18.5,
                    top: 99,
                    height: 57,
                    child: _donationRecord(),
                  ),
                ],
              ),
            ),
          ),
          // Machine-readable strip
          Positioned(
            left: 0,
            right: 0.5,
            top: 182,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F0EE),
                border: Border(top: BorderSide(color: _hairline, width: 0.5)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in _machineReadableLines()) ...[
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: _mono(7.5, FontWeight.w400, _inkBack, spacing: 0.15).copyWith(height: 1.2),
                    ),
                    const SizedBox(height: 1),
                  ],
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _CardRingsPainter(_rings))),
          ),
        ],
      ),
    );
  }

  Widget _organizationDetails() {
    final filled = data.completedDonations.clamp(0, 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REGISTERED AT · NAKATALA SA',
          style: _poppins(4.5, FontWeight.w600, _muted, spacing: 0.45),
        ),
        const SizedBox(height: 2.5),
        Text(
          data.registeredFacility,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _poppins(11, FontWeight.w800, _inkBack, height: 1.15),
        ),
        const SizedBox(height: 2.5),
        Text(
          data.registeredAddress,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _poppins(6, FontWeight.w400, _muted, height: 1.4),
        ),
        const SizedBox(height: 2.5),
        SizedBox(
          height: 21,
          child: Stack(
            children: [
              Text(
                'DONATION RECORD · TALA NG DONASYON',
                style: _poppins(4.5, FontWeight.w600, _muted, spacing: 0.36),
              ),
              for (var i = 0; i < 10; i++)
                Positioned(
                  left: 15.0 * i,
                  top: 9,
                  width: 12,
                  height: 12,
                  child: FittedBox(
                    child: Icon(
                      i < filled ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                      color: i < filled ? const Color(0xFF9E1C22) : const Color(0xFFCDBBBE),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2.5),
        Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(color: _maroon, shape: BoxShape.circle),
            ),
            const SizedBox(width: 3.5),
            Text(
              'EMERGENCY CONTACT · KONTAK SA EMERHENSIYA',
              style: _poppins(5.5, FontWeight.w600, _maroon),
            ),
          ],
        ),
        const SizedBox(height: 2.5),
        Text(
          data.emergencyContact.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _poppins(6.5, FontWeight.w700, _inkBack),
        ),
      ],
    );
  }

  Widget _qrVerification() {
    return SizedBox(
      width: 74,
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _inkBack, width: 1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _inkBack),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: _inkBack,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'SCAN TO VERIFY DONOR · I-SCAN',
            textAlign: TextAlign.center,
            style: _poppins(4.5, FontWeight.w600, _muted, spacing: 0.27),
          ),
        ],
      ),
    );
  }

  Widget _donationRecord() {
    final rows = data.recentDonations.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _hairline, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.hardEdge,
      // The record table is a fixed-height window in the design (57px) —
      // extra rows are cut off by the frame instead of overflowing.
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: _blush,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'RECENT DONATION RECORD · TALA NG DONASYON',
                    style: _poppins(5.5, FontWeight.w800, _maroon, spacing: 0.33),
                  ),
                ),
                Text(
                  '${data.completedDonations.toString().padLeft(2, '0')} lifetime',
                  style: _mono(5.5, FontWeight.w700, _maroon),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _hairline, width: 0.5))),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                'No hospital-recorded donations yet',
                style: _poppins(6, FontWeight.w400, _muted),
              ),
            )
          else
            for (final r in rows)
              Container(
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: _hairline, width: 0.5))),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 65,
                      child: Text(formatCardDate(r.date), style: _mono(6, FontWeight.w400, _inkBack)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _poppins(6, FontWeight.w400, _inkBack),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(r.code, style: _mono(6, FontWeight.w700, _maroon)),
                  ],
                ),
              ),
        ],
        ),
      ),
    );
  }

  /// Passport-style (MRZ-like) lines, 39 chars each, `<` as filler.
  List<String> _machineReadableLines() {
    String clean(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '<');
    String fit(String s) => s.length >= 39 ? s.substring(0, 39) : s.padRight(39, '<');
    String ymd(DateTime? d, {bool full = false}) {
      if (d == null) return full ? '<<<<<<<<' : '<<<<<<';
      final y = full ? d.year.toString() : (d.year % 100).toString().padLeft(2, '0');
      return '$y${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    }

    final sex = data.sex == 'M' || data.sex == 'F' ? data.sex : '<';
    final year = data.issuedAt?.year ?? DateTime.now().year;
    return [
      fit('RQD<PHL<${clean(data.surname)}<<${clean(data.givenNames)}'),
      fit('RQ$year${data.codeDigits}<0<<${ymd(data.birthDate)}$sex${ymd(data.validUntil)}'),
      fit('LAST<${ymd(data.lastDonationAt, full: true)}<<DON<${data.completedDonations.toString().padLeft(2, '0')}'
          '<<NEXT<${ymd(data.nextEligibleAt, full: true)}'),
    ];
  }
}
