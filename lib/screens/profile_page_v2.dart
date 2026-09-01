import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';

class ProfilePageV2 extends StatelessWidget {
  const ProfilePageV2({super.key, required this.staff, required this.facility, required this.onEndShift});
  final StaffProfile staff;
  final Facility facility;
  final VoidCallback onEndShift;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('Staff ID', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 18),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 590),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [medqurNavy, medqurBlue]),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [BoxShadow(color: Color(0x26173F8A), blurRadius: 30, offset: Offset(0, 14))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: const MedqurLogo(width: 112),
                ),
                const SizedBox(height: 24),
                Row(children: [
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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        staff.name,
                        style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        staff.title,
                        style: TextStyle(color: Colors.white.withValues(alpha: .78), fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 22),
                Container(height: 1, color: Colors.white.withValues(alpha: .18)),
                const SizedBox(height: 18),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _label('STAFF ID', staff.id),
                      const SizedBox(height: 12),
                      _label('REGISTRATION', staff.registration),
                      const SizedBox(height: 12),
                      _label('ACTIVE SITE', facility.name),
                      const SizedBox(height: 12),
                      _label('FACILITY TIER', facility.classificationLabel),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Padding(padding: const EdgeInsets.all(7), child: FakeQr(size: 86, data: staff.badgeToken)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SoftCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(facility.isHealthCentre ? Icons.local_hospital_outlined : Icons.apartment_rounded, color: medqurBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        const SoftCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.security_rounded, color: medqurGreen),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'The badge QR is a real scannable Medqur staff token. Native sign-in still requires device biometrics after the badge is scanned.',
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onEndShift,
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

  Widget _label(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      ]);
}
