import 'package:flutter/material.dart';
import '../facility_catalog.dart';
import '../models.dart';
import '../widgets/common.dart';

class FacilityDirectoryPage extends StatefulWidget {
  const FacilityDirectoryPage({super.key});

  @override
  State<FacilityDirectoryPage> createState() => _FacilityDirectoryPageState();
}

class _FacilityDirectoryPageState extends State<FacilityDirectoryPage> {
  final _search = TextEditingController();
  FacilityClass? _classFilter;
  String? _parishFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Facility> get _filtered {
    final query = _search.text.trim().toLowerCase();
    final results = publicFacilityDirectory.where((facility) {
      final matchesClass = _classFilter == null || facility.classification == _classFilter;
      final matchesParish = _parishFilter == null || facility.parish == _parishFilter;
      final matchesQuery = query.isEmpty ||
          facility.name.toLowerCase().contains(query) ||
          facility.area.toLowerCase().contains(query) ||
          facility.classificationLabel.toLowerCase().contains(query) ||
          (facility.specialty?.toLowerCase().contains(query) ?? false);
      return matchesClass && matchesParish && matchesQuery;
    }).toList();

    results.sort((a, b) {
      final classCompare = a.classification.index.compareTo(b.classification.index);
      if (classCompare != 0) return classCompare;
      return a.name.compareTo(b.name);
    });
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Jamaica facility directory', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          return ListView(
            padding: EdgeInsets.fromLTRB(wide ? 30 : 18, 18, wide ? 30 : 18, 36),
            children: [
              const SoftCard(
                highlighted: true,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.account_tree_outlined, color: medqurBlue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Browse Jamaica’s public hospital and health-centre tiers. This prototype directory is classification metadata, not a live bed-capacity, opening-hours or transfer-acceptance service.',
                      style: TextStyle(height: 1.4),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Search facility, town or specialty',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All tiers'),
                    selected: _classFilter == null,
                    onSelected: (_) => setState(() => _classFilter = null),
                  ),
                  for (final item in FacilityClass.values.where((item) => item != FacilityClass.other))
                    ChoiceChip(
                      label: Text(item.shortLabel),
                      selected: _classFilter == item,
                      onSelected: (_) => setState(() => _classFilter = item),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _parishFilter,
                decoration: const InputDecoration(labelText: 'Parish / service area', prefixIcon: Icon(Icons.place_outlined)),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All parishes')),
                  for (final parish in facilityParishes)
                    DropdownMenuItem<String?>(value: parish, child: Text(parish)),
                ],
                onChanged: (value) => setState(() => _parishFilter = value),
              ),
              const SizedBox(height: 20),
              SectionTitle(
                'Facilities',
                trailing: StatusPill(label: '${results.length} shown', color: medqurBlue),
              ),
              const SizedBox(height: 12),
              if (results.isEmpty)
                const SoftCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: Text('No facilities match these filters.')),
                  ),
                )
              else
                ...results.map((facility) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FacilityDirectoryTile(
                        facility: facility,
                        onTap: () => _showFacility(facility),
                      ),
                    )),
            ],
          );
        }),
      ),
    );
  }

  void _showFacility(Facility facility) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ClassBadge(facility: facility, large: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(facility.name, style: const TextStyle(color: medqurInk, fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(facility.area, style: const TextStyle(color: Color(0xFF65748A), fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            const SizedBox(height: 22),
            _InfoBlock(title: 'Classification', value: facility.classificationLabel),
            _InfoBlock(title: 'Care level', value: facility.careLevel),
            if (facility.populationBand != null)
              _InfoBlock(title: 'Population framework', value: facility.populationBand!),
            if (facility.specialty != null)
              _InfoBlock(title: 'Specialist focus', value: facility.specialty!),
            _InfoBlock(title: 'Typical capabilities', value: facility.capabilitySummary),
            _InfoBlock(title: 'Referral role', value: facility.referralRole),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: medqurLine),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: medqurBlue, size: 20),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Actual services, staffing, equipment, opening hours and transfer acceptance can change. Production Medqur must use an authoritative Ministry/RHA facility registry and live operational status.',
                    style: TextStyle(color: Color(0xFF65748A), fontSize: 12, height: 1.4),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FacilityDirectoryTile extends StatelessWidget {
  const _FacilityDirectoryTile({required this.facility, required this.onTap});
  final Facility facility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(15),
        child: Row(children: [
          _ClassBadge(facility: facility),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                facility.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: medqurInk, fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                '${facility.classificationLabel} • ${facility.area}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF748297), fontSize: 12, height: 1.35),
              ),
              if (facility.specialty != null) ...[
                const SizedBox(height: 4),
                Text(
                  facility.specialty!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: medqurBlue, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ]),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA5B4)),
        ]),
      );
}

class _ClassBadge extends StatelessWidget {
  const _ClassBadge({required this.facility, this.large = false});
  final Facility facility;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final hospital = facility.isHospital;
    return Container(
      width: large ? 62 : 48,
      height: large ? 62 : 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hospital ? medqurBlue.withValues(alpha: .10) : medqurGreen.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(large ? 18 : 14),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          hospital ? Icons.apartment_rounded : Icons.local_hospital_outlined,
          color: hospital ? medqurBlue : medqurGreen,
          size: large ? 25 : 20,
        ),
        const SizedBox(height: 2),
        Text(
          facility.classification.shortLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: hospital ? medqurBlue : medqurGreen,
            fontSize: large ? 10 : 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ]),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFF8793A4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(color: medqurInk, height: 1.42, fontWeight: FontWeight.w600)),
        ]),
      );
}
