import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/nids_test_credential.dart';
import '../widgets/common.dart';

class NidsTestCredentialPage extends StatefulWidget {
  const NidsTestCredentialPage({super.key});

  @override
  State<NidsTestCredentialPage> createState() => _NidsTestCredentialPageState();
}

class _NidsTestCredentialPageState extends State<NidsTestCredentialPage> {
  final _givenNames = TextEditingController(text: 'Alicia Marie');
  final _surname = TextEditingController(text: 'Morgan');
  final _dob = TextEditingController(text: '2000-03-09');
  final _nin = TextEditingController(text: 'TEST-687264892');
  NidsTestCredential? _credential;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void dispose() {
    _givenNames.dispose();
    _surname.dispose();
    _dob.dispose();
    _nin.dispose();
    super.dispose();
  }

  void _generate() {
    final given = _givenNames.text.trim();
    final surname = _surname.text.trim();
    final dob = _dob.text.trim();
    var nin = _nin.text.trim().toUpperCase();
    if (given.isEmpty || surname.isEmpty || DateTime.tryParse(dob) == null || nin.isEmpty) {
      setState(() {
        _credential = null;
        _error = 'Enter a test name, ISO date of birth (YYYY-MM-DD), and test NIN.';
      });
      return;
    }
    if (!nin.startsWith('TEST-')) nin = 'TEST-$nin';
    _nin.text = nin;
    setState(() {
      _error = null;
      _credential = NidsTestCredential(
        givenNames: given,
        surname: surname,
        dateOfBirth: dob,
        nationalIdNumber: nin,
      );
    });
  }

  Future<void> _copyPayload() async {
    final value = _credential?.encode();
    if (value == null) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Compact test QR payload copied.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final credential = _credential;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('NIDS test QR generator', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
        children: [
          const SoftCard(
            highlighted: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.science_outlined, color: medqurBlue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Prototype tool only. The V2 test code uses a much shorter payload and low QR error correction so it has fewer modules and is easier for phone cameras to resolve on ID-sized cards. It is not NIRA verification and must not be used with real identity data.',
                  style: TextStyle(height: 1.42),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Text('Test cardholder data', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _givenNames,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Given names', prefixIcon: Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _surname,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Surname'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dob,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(labelText: 'Date of birth', hintText: 'YYYY-MM-DD', prefixIcon: Icon(Icons.cake_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nin,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'TEST National ID number', hintText: 'TEST-000000000', prefixIcon: Icon(Icons.badge_outlined)),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.qr_code_2_rounded), label: const Text('Generate compact test QR')),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: medqurRed, fontWeight: FontWeight.w700)),
          ],
          if (credential != null) ...[
            const SizedBox(height: 24),
            const SectionTitle('Back-of-card test code'),
            const SizedBox(height: 10),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SoftCard(
                  child: Column(children: [
                    const Row(children: [
                      MedqurLogo(width: 112),
                      Spacer(),
                      StatusPill(label: 'TEST ONLY', color: medqurAmber, icon: Icons.warning_amber_rounded),
                    ]),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: medqurLine),
                      ),
                      child: QrImageView(
                        data: credential.encode(),
                        version: QrVersions.auto,
                        errorCorrectionLevel: QrErrorCorrectLevel.L,
                        size: 224,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Keep a clear white quiet zone around the code. Do not crop it tightly when printing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF748297), fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    Text(credential.fullName, style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 5),
                    Text('DOB ${credential.dateOfBirth} • ${credential.nationalIdNumber}', style: const TextStyle(color: Color(0xFF65748A), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    const Text(
                      'MEDQUR NIDS INTEGRATION TEST • NOT VALID • NOT GOVERNMENT IDENTIFICATION',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: medqurRed, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .5),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _copyPayload, icon: const Icon(Icons.copy_rounded), label: const Text('Copy compact test payload')),
          ],
        ],
      ),
    );
  }
}
