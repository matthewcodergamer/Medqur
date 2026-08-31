import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/common.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.staff,
    required this.facility,
    required this.onEndShift,
  });

  final StaffProfile staff;
  final Facility facility;
  final VoidCallback onEndShift;

  @override
  Widget build(BuildContext context) {
    final role = staff.role == StaffRole.doctor ? 'Doctor' : 'Nurse';

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text('Staff profile', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Your verified workplace identity, active facility, and session controls.'),
        const SizedBox(height: 22),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 590),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF173F8A), Color(0xFF3474E6)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(color: Color(0x26173F8A), blurRadius: 30, offset: Offset(0, 14)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const MedqurLogo(width: 118),
                      ),
                      const Spacer(),
                      const Icon(Icons.verified_user_rounded, color: Colors.white, size: 28),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: .28)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          staff.name.split(' ').last[0],
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              staff.name,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.4),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '$role • ${staff.title}',
                              style: TextStyle(color: Colors.white.withValues(alpha: .82), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Container(height: 1, color: Colors.white.withValues(alpha: .18)),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 450;
                      final details = [
                        _IdDetail(label: 'STAFF ID', value: staff.id),
                        _IdDetail(label: 'REGISTRATION', value: staff.registration),
                        _IdDetail(label: 'ACTIVE SITE', value: facility.name),
                      ];
                      return compact
                          ? Column(
                              children: [
                                for (final detail in details) ...[
                                  detail,
                                  const SizedBox(height: 16),
                                ],
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(12))),
                                    child: Padding(padding: EdgeInsets.all(8), child: FakeQr(size: 76)),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      for (final detail in details) ...[
                                        detail,
                                        const SizedBox(height: 13),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 18),
                                const DecoratedBox(
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(12))),
                                  child: Padding(padding: EdgeInsets.all(8), child: FakeQr(size: 82)),
                                ),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const SectionTitle('Active shift'),
        const SizedBox(height: 10),
        SoftCard(
          child: Column(
            children: [
              _RowInfo(icon: Icons.apartment_rounded, label: 'Facility', value: facility.name),
              const Divider(height: 26, color: medqurLine),
              _RowInfo(icon: Icons.location_on_outlined, label: 'Location', value: facility.area),
              const Divider(height: 26, color: medqurLine),
              const _RowInfo(icon: Icons.lock_outline_rounded, label: 'Session', value: 'Device-authenticated demo session'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SoftCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.security_rounded, color: medqurGreen),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Production design: the staff ID identifies the employee, while a device-bound passkey and Face ID/fingerprint authorize access. Biometric templates stay on the device.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onEndShift,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('End shift and choose another facility'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            foregroundColor: medqurInk,
            side: const BorderSide(color: medqurLine),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }
}

class _IdDetail extends StatelessWidget {
  const _IdDetail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .62), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          ],
        ),
      );
}

class _RowInfo extends StatelessWidget {
  const _RowInfo({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: medqurBlue.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: medqurBlue, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFF8793A4), fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      );
}
