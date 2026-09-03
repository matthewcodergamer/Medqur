import 'package:flutter/material.dart';

import '../models.dart';
import '../services/staff_identity.dart';
import '../widgets/common.dart';

class ProfilePageV2 extends StatefulWidget {
  const ProfilePageV2({
    super.key,
    required this.staff,
    required this.facility,
    required this.onEndShift,
  });

  final StaffProfile staff;
  final Facility facility;
  final VoidCallback onEndShift;

  @override
  State<ProfilePageV2> createState() => _ProfilePageV2State();
}

class _ProfilePageV2State extends State<ProfilePageV2> {
  final _identity = StaffIdentityClient();
  StaffBadgePresentation? _signedBadge;
  bool _loadingBadge = false;
  String? _badgeStatus;

  @override
  void initState() {
    super.initState();
    _loadSignedBadge();
  }

  Future<void> _loadSignedBadge() async {
    if (!_identity.isConfigured) {
      setState(() {
        _signedBadge = null;
        _badgeStatus = 'Identity service not configured in this build.';
      });
      return;
    }
    setState(() {
      _loadingBadge = true;
      _badgeStatus = 'Loading signed credential…';
    });
    try {
      final value = await _identity.fetchMyBadge(
        staff: widget.staff,
        facility: widget.facility,
      );
      if (!mounted) return;
      setState(() {
        _signedBadge = value;
        _badgeStatus = value == null
            ? 'No active signed credential was returned. An authorized identity administrator must issue the badge.'
            : 'Signed credential loaded and ready to scan.';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _signedBadge = null;
        _badgeStatus = 'Unable to load signed staff credential: $error';
      });
    } finally {
      if (mounted) setState(() => _loadingBadge = false);
    }
  }

  String get _qrData {
    final signed = _signedBadge;
    if (signed != null) return signed.token;
    return StaffBadgeCodec.prototypeToken(widget.staff.id);
  }

  @override
  void dispose() {
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final facility = widget.facility;
    final signed = _signedBadge != null;

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Health worker ID', style: Theme.of(context).textTheme.headlineSmall),
            ),
            if (_loadingBadge)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.3),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 590),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [medqurNavy, medqurBlue]),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26173F8A),
                    blurRadius: 30,
                    offset: Offset(0, 14),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const MedqurLogo(width: 112),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: .18)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              signed ? Icons.verified_user_rounded : Icons.science_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              signed ? 'SIGNED ID' : 'PROTOTYPE ID',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 31,
                        backgroundColor: Colors.white.withValues(alpha: .16),
                        foregroundColor: Colors.white,
                        child: Text(
                          staff.name.split(' ').last[0],
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              staff.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              staff.title,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .78),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(height: 1, color: Colors.white.withValues(alpha: .18)),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('6-DIGIT STAFF ID', staff.id, prominent: true),
                            const SizedBox(height: 12),
                            _label('REGISTRATION', staff.registration.isEmpty ? 'Not recorded' : staff.registration),
                            const SizedBox(height: 12),
                            _label('ACTIVE SITE', facility.name),
                            const SizedBox(height: 12),
                            _label('FACILITY TIER', facility.classificationLabel),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: FakeQr(size: 104, data: _qrData),
                        ),
                      ),
                    ],
                  ),
                  if (_signedBadge?.expiresAt != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'QR credential expires ${_date(_signedBadge!.expiresAt!)} • ${_signedBadge!.signingKeyId}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .66),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_badgeStatus != null)
          Text(
            _badgeStatus!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF748297), fontSize: 11.5),
          ),
        if (_identity.isConfigured) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _loadingBadge ? null : _loadSignedBadge,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh staff credential'),
            ),
          ),
        ],
        const SizedBox(height: 18),
        SoftCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                facility.isHealthCentre
                    ? Icons.local_hospital_outlined
                    : Icons.apartment_rounded,
                color: medqurBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facility.classificationLabel,
                      style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(facility.careLevel),
                    const SizedBox(height: 7),
                    Text(
                      facility.referralRole,
                      style: const TextStyle(color: Color(0xFF748297), fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SoftCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                signed ? Icons.security_rounded : Icons.info_outline_rounded,
                color: signed ? medqurGreen : medqurAmber,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  signed
                      ? 'This QR is an Ed25519-signed Medqur staff credential. The QR contains only an opaque credential identifier plus issue/expiry/key metadata. Name, profession, registration and facility are returned only after signature, expiry, revocation and employment checks. Scanning the badge never replaces biometric/passkey sign-in.'
                      : 'This public build is showing a local prototype QR because the signed identity service is not available. It remains scannable for the demo, but it is not treated as cryptographically verified. Production badges are generated and signed only by the protected identity service.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: widget.onEndShift,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('End shift'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            foregroundColor: medqurInk,
            side: const BorderSide(color: medqurLine),
          ),
        ),
      ],
    );
  }

  Widget _label(String label, String value, {bool prominent = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .60),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: prominent ? 24 : 13,
              letterSpacing: prominent ? 3 : 0,
            ),
          ),
        ],
      );

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
