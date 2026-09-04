import 'package:flutter/material.dart';

import '../models.dart';
import '../services/staff_identity.dart';
import '../widgets/common.dart';
import '../widgets/medqur_design.dart';
import 'signature_vault_page.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSignedBadge();
  }

  @override
  void dispose() {
    _identity.dispose();
    super.dispose();
  }

  Future<void> _loadSignedBadge() async {
    if (!_identity.isConfigured) return;
    setState(() => _loadingBadge = true);
    try {
      final value = await _identity.fetchMyBadge(
        staff: widget.staff,
        facility: widget.facility,
      );
      if (!mounted) return;
      setState(() => _signedBadge = value);
    } on Object {
      if (!mounted) return;
      setState(() => _signedBadge = null);
    } finally {
      if (mounted) setState(() => _loadingBadge = false);
    }
  }

  String get _qrData =>
      _signedBadge?.token ?? StaffBadgeCodec.prototypeToken(widget.staff.id);

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final facility = widget.facility;
    final signed = _signedBadge != null;

    return MedqurPage(
      children: [
        MedqurPageHeader(
          eyebrow: 'Account',
          title: staff.name,
          subtitle: '${staff.title} • ${facility.name}',
          trailing: _loadingBadge
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        const SizedBox(height: 18),
        _StaffCredentialCard(
          staff: staff,
          facility: facility,
          signed: signed,
          qrData: _qrData,
          expiresAt: _signedBadge?.expiresAt,
        ),
        const SizedBox(height: 18),
        const _ProfileSectionLabel('Work'),
        const SizedBox(height: 8),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: Icons.apartment_outlined,
              title: facility.name,
              subtitle: facility.classificationLabel,
            ),
            const Divider(),
            _SettingsRow(
              icon: Icons.badge_outlined,
              title: 'Professional registration',
              subtitle: staff.registration.trim().isEmpty
                  ? 'Not recorded'
                  : staff.registration,
            ),
          ],
        ),
        if (staff.role == StaffRole.doctor) ...[
          const SizedBox(height: 18),
          const _ProfileSectionLabel('Prescribing'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.draw_outlined,
                title: 'Signatures',
                subtitle:
                    'Manage your default and alternate prescription signatures',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SignatureVaultPage(staff: staff),
                  ),
                ),
              ),
              const Divider(),
              const _SettingsRow(
                icon: Icons.print_outlined,
                title: 'Prescription printing',
                subtitle:
                    'Uses the hospital prescription form and system printer',
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        const _ProfileSectionLabel('Security'),
        const SizedBox(height: 8),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: signed
                  ? Icons.verified_user_outlined
                  : Icons.info_outline_rounded,
              title: signed ? 'Signed staff credential' : 'Prototype credential',
              subtitle: signed
                  ? 'Badge signature, expiry and revocation are checked by the identity service'
                  : 'Connect the Medqur identity service for cryptographic badge verification',
              trailing: _identity.isConfigured
                  ? IconButton(
                      tooltip: 'Refresh credential',
                      onPressed: _loadingBadge ? null : _loadSignedBadge,
                      icon: const Icon(Icons.refresh_rounded),
                    )
                  : null,
            ),
            const Divider(),
            const _SettingsRow(
              icon: Icons.fingerprint_rounded,
              title: 'Device authentication',
              subtitle:
                  'Biometric/passkey authentication remains separate from the badge QR',
            ),
          ],
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: widget.onEndShift,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('End shift'),
          style: OutlinedButton.styleFrom(
            foregroundColor: medqurInk,
            minimumSize: const Size(0, 50),
          ),
        ),
      ],
    );
  }
}

class _StaffCredentialCard extends StatelessWidget {
  const _StaffCredentialCard({
    required this.staff,
    required this.facility,
    required this.signed,
    required this.qrData,
    this.expiresAt,
  });

  final StaffProfile staff;
  final Facility facility;
  final bool signed;
  final String qrData;
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: medqurNavy,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1011233F),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const MedqurLogo(width: 102),
                ),
                const Spacer(),
                Text(
                  signed ? 'VERIFIED' : 'PROTOTYPE',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .68),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              staff.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              staff.title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .72),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _credentialLabel('STAFF ID', staff.id, prominent: true),
                      const SizedBox(height: 10),
                      _credentialLabel('FACILITY', facility.name),
                      if (expiresAt != null) ...[
                        const SizedBox(height: 10),
                        _credentialLabel('QR EXPIRES', _date(expiresAt!)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: FakeQr(size: 92, data: qrData),
                ),
              ],
            ),
          ],
        ),
      );

  static Widget _credentialLabel(
    String label,
    String value, {
    bool prominent = false,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFAFC0D7),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: prominent ? 22 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: prominent ? 2.4 : 0,
            ),
          ),
        ],
      );

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF68778A),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: medqurLine),
        ),
        child: Column(children: children),
      );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: medqurBlue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: medqurInk,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF7A8798),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      );
}
