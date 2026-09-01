import 'models.dart';

String _slug(String value) => value
    .toUpperCase()
    .replaceAll('&', ' AND ')
    .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

Facility _facility(
  String name,
  String town,
  String parish,
  FacilityClass classification, {
  String? specialty,
  bool suggested = false,
}) {
  final type = classification.isHealthCentre ? 'Health Centre' : 'Hospital';
  return Facility(
    id: '${classification.shortLabel.replaceAll(' ', '').toUpperCase()}-${_slug(name)}',
    name: name,
    area: town == parish ? parish : '$town, $parish',
    parish: parish,
    type: type,
    classification: classification,
    specialty: specialty,
    suggested: suggested,
  );
}

/// Prototype Jamaica public-facility directory seeded from the classification
/// information supplied for Medqur V0.4. It is deliberately data-driven so a
/// Ministry/RHA authoritative registry can replace this seed without changing
/// the clinical UI.
final List<Facility> publicFacilityDirectory = <Facility>[
  // Type A hospitals.
  _facility('Kingston Public Hospital', 'Kingston', 'Kingston & St. Andrew', FacilityClass.typeAHospital),
  _facility('Cornwall Regional Hospital', 'Montego Bay', 'St. James', FacilityClass.typeAHospital),
  _facility('University Hospital of the West Indies', 'Mona', 'Kingston & St. Andrew', FacilityClass.typeAHospital),

  // Type B hospitals.
  _facility('Spanish Town Hospital', 'Spanish Town', 'St. Catherine', FacilityClass.typeBHospital),
  _facility('Mandeville Regional Hospital', 'Mandeville', 'Manchester', FacilityClass.typeBHospital, suggested: true),
  _facility('St. Ann’s Bay Regional Hospital', 'St. Ann’s Bay', 'St. Ann', FacilityClass.typeBHospital),
  _facility('May Pen Hospital', 'May Pen', 'Clarendon', FacilityClass.typeBHospital),
  _facility('Savanna-la-Mar Public General Hospital', 'Savanna-la-Mar', 'Westmoreland', FacilityClass.typeBHospital),
  _facility('Princess Margaret Hospital', 'Morant Bay', 'St. Thomas', FacilityClass.typeBHospital),

  // Type C hospitals.
  _facility('Annotto Bay Hospital', 'Annotto Bay', 'St. Mary', FacilityClass.typeCHospital),
  _facility('Port Maria Hospital', 'Port Maria', 'St. Mary', FacilityClass.typeCHospital),
  _facility('Port Antonio Hospital', 'Port Antonio', 'Portland', FacilityClass.typeCHospital),
  _facility('Buff Bay Hospital', 'Buff Bay', 'Portland', FacilityClass.typeCHospital),
  _facility('Falmouth Hospital', 'Falmouth', 'Trelawny', FacilityClass.typeCHospital),
  _facility('Lucea Hospital', 'Lucea', 'Hanover', FacilityClass.typeCHospital),
  _facility('Black River Hospital', 'Black River', 'St. Elizabeth', FacilityClass.typeCHospital),
  _facility('Percy Junor Hospital', 'Spalding', 'Manchester / Clarendon', FacilityClass.typeCHospital),
  _facility('Lionel Town Hospital', 'Lionel Town', 'Clarendon', FacilityClass.typeCHospital),
  _facility('Linstead Hospital', 'Linstead', 'St. Catherine', FacilityClass.typeCHospital),

  // National / non-letter specialist institutions.
  _facility('Bustamante Hospital for Children', 'Kingston', 'Kingston & St. Andrew', FacilityClass.specialistHospital, specialty: 'Paediatrics'),
  _facility('Victoria Jubilee Hospital', 'Kingston', 'Kingston & St. Andrew', FacilityClass.specialistHospital, specialty: 'Maternity, obstetrics and gynaecology'),
  _facility('National Chest Hospital', 'Kingston', 'Kingston & St. Andrew', FacilityClass.specialistHospital, specialty: 'Thoracic and respiratory medicine'),
  _facility('Bellevue Hospital', 'Kingston', 'Kingston & St. Andrew', FacilityClass.specialistHospital, specialty: 'Psychiatric and mental-health care'),
  _facility('Sir John Golding Rehabilitation Centre', 'Kingston', 'Kingston & St. Andrew', FacilityClass.specialistHospital, specialty: 'Physical rehabilitation'),
  _facility('Hope Institute', 'Kingston', 'Kingston & St. Andrew', FacilityClass.specialistHospital, specialty: 'Oncology and palliative care'),
  _facility('Chapelton Community Hospital', 'Chapelton', 'Clarendon', FacilityClass.specialistHospital, specialty: 'Sub-acute and convalescent general care'),

  // Type 5 health centres.
  _facility('Comprehensive Health Centre (Slipe Pen Road)', 'Kingston', 'Kingston & St. Andrew', FacilityClass.type5HealthCentre),
  _facility('Montego Bay Type 5 Health Centre', 'Montego Bay', 'St. James', FacilityClass.type5HealthCentre),
  _facility('Alexandria Community Hospital / Type 5 Centre', 'Alexandria', 'St. Ann', FacilityClass.type5HealthCentre),

  // Type 4 health centres.
  _facility('St. Jago Park Health Centre', 'Spanish Town', 'St. Catherine', FacilityClass.type4HealthCentre),
  _facility('St. Ann’s Bay Health Centre', 'St. Ann’s Bay', 'St. Ann', FacilityClass.type4HealthCentre),
  _facility('Savanna-la-Mar Type 4 Health Centre', 'Savanna-la-Mar', 'Westmoreland', FacilityClass.type4HealthCentre),
  _facility('Falmouth Type 4 Health Centre', 'Falmouth', 'Trelawny', FacilityClass.type4HealthCentre),
  _facility('Morant Bay Health Centre', 'Morant Bay', 'St. Thomas', FacilityClass.type4HealthCentre),
  _facility('Port Antonio Health Centre', 'Port Antonio', 'Portland', FacilityClass.type4HealthCentre),

  // Type 3 health centres — Kingston & St. Andrew.
  _facility('Duhaney Park Health Centre', 'Duhaney Park', 'Kingston & St. Andrew', FacilityClass.type3HealthCentre),
  _facility('Maxfield Park Health Centre', 'Maxfield Park', 'Kingston & St. Andrew', FacilityClass.type3HealthCentre),
  _facility('Stony Hill Health Centre', 'Stony Hill', 'Kingston & St. Andrew', FacilityClass.type3HealthCentre),
  _facility('Windward Road Health Centre', 'Windward Road', 'Kingston & St. Andrew', FacilityClass.type3HealthCentre),
  _facility('Constant Spring Health Centre', 'Constant Spring', 'Kingston & St. Andrew', FacilityClass.type3HealthCentre),
  _facility('Sunrise Health Centre', 'Kingston', 'Kingston & St. Andrew', FacilityClass.type3HealthCentre),
  _facility('Hagley Park Health Centre', 'Hagley Park', 'Kingston & St. Andrew', FacilityClass.type3HealthCentre),
  _facility('Lawrence Tavern Health Centre', 'Lawrence Tavern', 'Kingston & St. Andrew', FacilityClass.type3HealthCentre),
  _facility('Olympic Gardens Health Centre', 'Olympic Gardens', 'Kingston & St. Andrew', FacilityClass.type3HealthCentre),
  _facility('Pembroke Hall Health Centre', 'Pembroke Hall', 'Kingston & St. Andrew', FacilityClass.type3HealthCentre),

  // Type 3 — St. Catherine.
  _facility('Greater Portmore Health Centre', 'Greater Portmore', 'St. Catherine', FacilityClass.type3HealthCentre),
  _facility('Linstead Health Centre', 'Linstead', 'St. Catherine', FacilityClass.type3HealthCentre),
  _facility('Old Harbour Health Centre', 'Old Harbour', 'St. Catherine', FacilityClass.type3HealthCentre),
  _facility('Sydenham Health Centre', 'Sydenham', 'St. Catherine', FacilityClass.type3HealthCentre),
  _facility('Riversdale Health Centre', 'Riversdale', 'St. Catherine', FacilityClass.type3HealthCentre),
  _facility('Christian Pen Health Centre', 'Christian Pen', 'St. Catherine', FacilityClass.type3HealthCentre),
  _facility('Ewarton Health Centre', 'Ewarton', 'St. Catherine', FacilityClass.type3HealthCentre),
  _facility('Bog Walk Health Centre', 'Bog Walk', 'St. Catherine', FacilityClass.type3HealthCentre),
  _facility('Guys Hill Health Centre', 'Guys Hill', 'St. Catherine', FacilityClass.type3HealthCentre),

  // Type 3 — central and western parishes.
  _facility('May Pen Health Centre', 'May Pen', 'Clarendon', FacilityClass.type3HealthCentre),
  _facility('Spalding Health Centre', 'Spalding', 'Clarendon', FacilityClass.type3HealthCentre),
  _facility('Chapelton Health Centre', 'Chapelton', 'Clarendon', FacilityClass.type3HealthCentre),
  _facility('Kellits Health Centre', 'Kellits', 'Clarendon', FacilityClass.type3HealthCentre),
  _facility('Christiana Health Centre', 'Christiana', 'Manchester', FacilityClass.type3HealthCentre),
  _facility('Mandeville Comprehensive Clinic', 'Mandeville', 'Manchester', FacilityClass.type3HealthCentre),
  _facility('Porus Health Centre', 'Porus', 'Manchester', FacilityClass.type3HealthCentre),
  _facility('Santa Cruz Health Centre', 'Santa Cruz', 'St. Elizabeth', FacilityClass.type3HealthCentre),
  _facility('Black River Health Centre', 'Black River', 'St. Elizabeth', FacilityClass.type3HealthCentre),
  _facility('Malvern Health Centre', 'Malvern', 'St. Elizabeth', FacilityClass.type3HealthCentre),
  _facility('Grange Hill Health Centre', 'Grange Hill', 'Westmoreland', FacilityClass.type3HealthCentre),
  _facility('Whitehouse Health Centre', 'Whitehouse', 'Westmoreland', FacilityClass.type3HealthCentre),
  _facility('Darliston Health Centre', 'Darliston', 'Westmoreland', FacilityClass.type3HealthCentre),
  _facility('Bluefields Health Centre', 'Bluefields', 'Westmoreland', FacilityClass.type3HealthCentre),
  _facility('Bethel Town Health Centre', 'Bethel Town', 'Westmoreland', FacilityClass.type3HealthCentre),
  _facility('Granville Health Centre', 'Granville', 'St. James', FacilityClass.type3HealthCentre),
  _facility('Catherine Hall Health Centre', 'Catherine Hall', 'St. James', FacilityClass.type3HealthCentre),
  _facility('Cambridge Health Centre', 'Cambridge', 'St. James', FacilityClass.type3HealthCentre),
  _facility('Lucea Health Centre', 'Lucea', 'Hanover', FacilityClass.type3HealthCentre),
  _facility('Hopewell Health Centre', 'Hopewell', 'Hanover', FacilityClass.type3HealthCentre),
  _facility('Albert Town Health Centre', 'Albert Town', 'Trelawny', FacilityClass.type3HealthCentre),
  _facility('Wakefield Health Centre', 'Wakefield', 'Trelawny', FacilityClass.type3HealthCentre),

  // Type 3 — north-east and south-east.
  _facility('Brown’s Town Health Centre', 'Brown’s Town', 'St. Ann', FacilityClass.type3HealthCentre),
  _facility('Ocho Rios Health Centre', 'Ocho Rios', 'St. Ann', FacilityClass.type3HealthCentre),
  _facility('Claremont Health Centre', 'Claremont', 'St. Ann', FacilityClass.type3HealthCentre),
  _facility('Highgate Health Centre', 'Highgate', 'St. Mary', FacilityClass.type3HealthCentre),
  _facility('Port Maria Health Centre', 'Port Maria', 'St. Mary', FacilityClass.type3HealthCentre),
  _facility('Annotto Bay Health Centre', 'Annotto Bay', 'St. Mary', FacilityClass.type3HealthCentre),
  _facility('Buff Bay Health Centre', 'Buff Bay', 'Portland', FacilityClass.type3HealthCentre),
  _facility('Manchioneal Health Centre', 'Manchioneal', 'Portland', FacilityClass.type3HealthCentre),
  _facility('Yallahs Health Centre', 'Yallahs', 'St. Thomas', FacilityClass.type3HealthCentre),
  _facility('Seaforth Health Centre', 'Seaforth', 'St. Thomas', FacilityClass.type3HealthCentre),
  _facility('Trinityville Health Centre', 'Trinityville', 'St. Thomas', FacilityClass.type3HealthCentre),

  // Type 2 — Clarendon.
  _facility('York Town Health Centre', 'York Town', 'Clarendon', FacilityClass.type2HealthCentre),
  _facility('Race Course Health Centre', 'Race Course', 'Clarendon', FacilityClass.type2HealthCentre),
  _facility('Hayes Health Centre', 'Hayes', 'Clarendon', FacilityClass.type2HealthCentre),
  _facility('Mocho Health Centre', 'Mocho', 'Clarendon', FacilityClass.type2HealthCentre),
  _facility('Croft’s Hill Health Centre', 'Croft’s Hill', 'Clarendon', FacilityClass.type2HealthCentre),
  _facility('Baillieston Health Centre', 'Baillieston', 'Clarendon', FacilityClass.type2HealthCentre),
  _facility('Thompson Town Health Centre', 'Thompson Town', 'Clarendon', FacilityClass.type2HealthCentre),
  _facility('Rock River Health Centre', 'Rock River', 'Clarendon', FacilityClass.type2HealthCentre),

  // Type 2 — Manchester and St. Elizabeth.
  _facility('Downs Health Centre', 'Downs', 'Manchester', FacilityClass.type2HealthCentre),
  _facility('Mile Gully Health Centre', 'Mile Gully', 'Manchester', FacilityClass.type2HealthCentre),
  _facility('Newport Health Centre', 'Newport', 'Manchester', FacilityClass.type2HealthCentre),
  _facility('Cross Keys Health Centre', 'Cross Keys', 'Manchester', FacilityClass.type2HealthCentre),
  _facility('Williamsfield Health Centre', 'Williamsfield', 'Manchester', FacilityClass.type2HealthCentre),
  _facility('Craighead Health Centre', 'Craighead', 'Manchester', FacilityClass.type2HealthCentre),
  _facility('Balaclava Health Centre', 'Balaclava', 'St. Elizabeth', FacilityClass.type2HealthCentre),
  _facility('Maggotty Health Centre', 'Maggotty', 'St. Elizabeth', FacilityClass.type2HealthCentre),
  _facility('New Market Health Centre', 'New Market', 'St. Elizabeth', FacilityClass.type2HealthCentre),
  _facility('Southfield Health Centre', 'Southfield', 'St. Elizabeth', FacilityClass.type2HealthCentre),
  _facility('Pedro Plains Health Centre', 'Pedro Plains', 'St. Elizabeth', FacilityClass.type2HealthCentre),
  _facility('Junction Health Centre', 'Junction', 'St. Elizabeth', FacilityClass.type2HealthCentre),
  _facility('Siloah Health Centre', 'Siloah', 'St. Elizabeth', FacilityClass.type2HealthCentre),

  // Type 2 — western parishes.
  _facility('Sheffield Health Centre', 'Sheffield', 'Westmoreland', FacilityClass.type2HealthCentre),
  _facility('Negril Health Centre', 'Negril', 'Westmoreland', FacilityClass.type2HealthCentre),
  _facility('Little London Health Centre', 'Little London', 'Westmoreland', FacilityClass.type2HealthCentre),
  _facility('Maroon Town Health Centre', 'Maroon Town', 'St. James', FacilityClass.type2HealthCentre),
  _facility('Adelphi Health Centre', 'Adelphi', 'St. James', FacilityClass.type2HealthCentre),
  _facility('Flanker Health Centre', 'Flanker', 'St. James', FacilityClass.type2HealthCentre),
  _facility('Barrett Town Health Centre', 'Barrett Town', 'St. James', FacilityClass.type2HealthCentre),
  _facility('Mount Carey Health Centre', 'Mount Carey', 'St. James', FacilityClass.type2HealthCentre),
  _facility('Green Island Health Centre', 'Green Island', 'Hanover', FacilityClass.type2HealthCentre),
  _facility('Sandy Bay Health Centre', 'Sandy Bay', 'Hanover', FacilityClass.type2HealthCentre),
  _facility('Ramble Health Centre', 'Ramble', 'Hanover', FacilityClass.type2HealthCentre),
  _facility('Cascade Health Centre', 'Cascade', 'Hanover', FacilityClass.type2HealthCentre),
  _facility('Ulster Spring Health Centre', 'Ulster Spring', 'Trelawny', FacilityClass.type2HealthCentre),
  _facility('Duncans Health Centre', 'Duncans', 'Trelawny', FacilityClass.type2HealthCentre),
  _facility('Jackson Town Health Centre', 'Jackson Town', 'Trelawny', FacilityClass.type2HealthCentre),
  _facility('Rio Bueno Health Centre', 'Rio Bueno', 'Trelawny', FacilityClass.type2HealthCentre),

  // Type 2 — northern/eastern parishes.
  _facility('Runaway Bay Health Centre', 'Runaway Bay', 'St. Ann', FacilityClass.type2HealthCentre),
  _facility('Calderwood Health Centre', 'Calderwood', 'St. Ann', FacilityClass.type2HealthCentre),
  _facility('Bamboo Health Centre', 'Bamboo', 'St. Ann', FacilityClass.type2HealthCentre),
  _facility('Cave Valley Health Centre', 'Cave Valley', 'St. Ann', FacilityClass.type2HealthCentre),
  _facility('Moneague Health Centre', 'Moneague', 'St. Ann', FacilityClass.type2HealthCentre),
  _facility('Watt Town Health Centre', 'Watt Town', 'St. Ann', FacilityClass.type2HealthCentre),
  _facility('Gayle Health Centre', 'Gayle', 'St. Mary', FacilityClass.type2HealthCentre),
  _facility('Richmond Health Centre', 'Richmond', 'St. Mary', FacilityClass.type2HealthCentre),
  _facility('Oracabessa Health Centre', 'Oracabessa', 'St. Mary', FacilityClass.type2HealthCentre),
  _facility('Islington Health Centre', 'Islington', 'St. Mary', FacilityClass.type2HealthCentre),
  _facility('Castleton Health Centre', 'Castleton', 'St. Mary', FacilityClass.type2HealthCentre),
  _facility('Guys Hill Health Centre (St. Mary)', 'Guys Hill', 'St. Mary', FacilityClass.type2HealthCentre),
  _facility('Hope Bay Health Centre', 'Hope Bay', 'Portland', FacilityClass.type2HealthCentre),
  _facility('Fellowship Health Centre', 'Fellowship', 'Portland', FacilityClass.type2HealthCentre),
  _facility('Fair Prospect Health Centre', 'Fair Prospect', 'Portland', FacilityClass.type2HealthCentre),
  _facility('Danver’s Pen Health Centre', 'Danver’s Pen', 'St. Thomas', FacilityClass.type2HealthCentre),
  _facility('White Horses Health Centre', 'White Horses', 'St. Thomas', FacilityClass.type2HealthCentre),
  _facility('Bath Health Centre', 'Bath', 'St. Thomas', FacilityClass.type2HealthCentre),
  _facility('Port Morant Health Centre', 'Port Morant', 'St. Thomas', FacilityClass.type2HealthCentre),
  _facility('Cedar Valley Health Centre', 'Cedar Valley', 'St. Thomas', FacilityClass.type2HealthCentre),

  // Type 2 — St. Catherine and Kingston/St. Andrew.
  _facility('Point Hill Health Centre', 'Point Hill', 'St. Catherine', FacilityClass.type2HealthCentre),
  _facility('Kitson Town Health Centre', 'Kitson Town', 'St. Catherine', FacilityClass.type2HealthCentre),
  _facility('Gregory Park Health Centre', 'Gregory Park', 'St. Catherine', FacilityClass.type2HealthCentre),
  _facility('Braeton Health Centre', 'Braeton', 'St. Catherine', FacilityClass.type2HealthCentre),
  _facility('Sligoville Health Centre', 'Sligoville', 'St. Catherine', FacilityClass.type2HealthCentre),
  _facility('Browns Hall Health Centre', 'Browns Hall', 'St. Catherine', FacilityClass.type2HealthCentre),
  _facility('Glengoffe Health Centre', 'Glengoffe', 'St. Catherine', FacilityClass.type2HealthCentre),
  _facility('Rae Town Health Centre', 'Rae Town', 'Kingston & St. Andrew', FacilityClass.type2HealthCentre),
  _facility('Harbour View Health Centre', 'Harbour View', 'Kingston & St. Andrew', FacilityClass.type2HealthCentre),
  _facility('Bull Bay Health Centre', 'Bull Bay', 'Kingston & St. Andrew', FacilityClass.type2HealthCentre),
  _facility('Vineyard Town Health Centre', 'Vineyard Town', 'Kingston & St. Andrew', FacilityClass.type2HealthCentre),
  _facility('Half Way Tree Health Centre', 'Half Way Tree', 'Kingston & St. Andrew', FacilityClass.type2HealthCentre),
  _facility('Gordon Town Health Centre', 'Gordon Town', 'Kingston & St. Andrew', FacilityClass.type2HealthCentre),
  _facility('Mavis Bank Health Centre', 'Mavis Bank', 'Kingston & St. Andrew', FacilityClass.type2HealthCentre),

  // Type 1 — Clarendon.
  _facility('Halse Hall Health Centre', 'Halse Hall', 'Clarendon', FacilityClass.type1HealthCentre),
  _facility('Alston Health Centre', 'Alston', 'Clarendon', FacilityClass.type1HealthCentre),
  _facility('Toll Gate Health Centre', 'Toll Gate', 'Clarendon', FacilityClass.type1HealthCentre),
  _facility('Milk River Health Centre', 'Milk River', 'Clarendon', FacilityClass.type1HealthCentre),
  _facility('Portland Cottage Health Centre', 'Portland Cottage', 'Clarendon', FacilityClass.type1HealthCentre),
  _facility('Alley Health Centre', 'Alley', 'Clarendon', FacilityClass.type1HealthCentre),
  _facility('Tweedside Health Centre', 'Tweedside', 'Clarendon', FacilityClass.type1HealthCentre),
  _facility('Crooked River Health Centre', 'Crooked River', 'Clarendon', FacilityClass.type1HealthCentre),
  _facility('Farenough Health Centre', 'Farenough', 'Clarendon', FacilityClass.type1HealthCentre),
  _facility('Smithville Health Centre', 'Smithville', 'Clarendon', FacilityClass.type1HealthCentre),
  _facility('Brixton Hill Health Centre', 'Brixton Hill', 'Clarendon', FacilityClass.type1HealthCentre),

  // Type 1 — Manchester and St. Elizabeth.
  _facility('Moravia Health Centre', 'Moravia', 'Manchester', FacilityClass.type1HealthCentre),
  _facility('Aenon Town Health Centre', 'Aenon Town', 'Manchester', FacilityClass.type1HealthCentre),
  _facility('Cumberland Health Centre', 'Cumberland', 'Manchester', FacilityClass.type1HealthCentre),
  _facility('Pratville Health Centre', 'Pratville', 'Manchester', FacilityClass.type1HealthCentre),
  _facility('Harmons Health Centre', 'Harmons', 'Manchester', FacilityClass.type1HealthCentre),
  _facility('Lincoln Health Centre', 'Lincoln', 'Manchester', FacilityClass.type1HealthCentre),
  _facility('Comfort Health Centre', 'Comfort', 'Manchester', FacilityClass.type1HealthCentre),
  _facility('Mile Gully Outreach', 'Mile Gully', 'Manchester', FacilityClass.type1HealthCentre),
  _facility('Medina Health Centre', 'Medina', 'Manchester', FacilityClass.type1HealthCentre),
  _facility('Rose Hill Health Centre', 'Rose Hill', 'Manchester', FacilityClass.type1HealthCentre),
  _facility('Rose Hall Health Centre', 'Rose Hall', 'St. Elizabeth', FacilityClass.type1HealthCentre),
  _facility('Myersville Health Centre', 'Myersville', 'St. Elizabeth', FacilityClass.type1HealthCentre),
  _facility('Mountainside Health Centre', 'Mountainside', 'St. Elizabeth', FacilityClass.type1HealthCentre),
  _facility('Top Hill Health Centre', 'Top Hill', 'St. Elizabeth', FacilityClass.type1HealthCentre),
  _facility('Bellevue Health Centre (St. Elizabeth)', 'Bellevue', 'St. Elizabeth', FacilityClass.type1HealthCentre),
  _facility('Ginger Hill Health Centre', 'Ginger Hill', 'St. Elizabeth', FacilityClass.type1HealthCentre),
  _facility('Fyffes Pen Health Centre', 'Fyffes Pen', 'St. Elizabeth', FacilityClass.type1HealthCentre),
  _facility('Aberdeen Health Centre', 'Aberdeen', 'St. Elizabeth', FacilityClass.type1HealthCentre),
  _facility('Lacovia Health Centre', 'Lacovia', 'St. Elizabeth', FacilityClass.type1HealthCentre),
  _facility('Braes River Health Centre', 'Braes River', 'St. Elizabeth', FacilityClass.type1HealthCentre),

  // Type 1 — Westmoreland, St. James, Hanover and Trelawny.
  _facility('Petersfield Health Centre', 'Petersfield', 'Westmoreland', FacilityClass.type1HealthCentre),
  _facility('Content Health Centre', 'Content', 'Westmoreland', FacilityClass.type1HealthCentre),
  _facility('Beeston Spring Health Centre', 'Beeston Spring', 'Westmoreland', FacilityClass.type1HealthCentre),
  _facility('Ashton Health Centre', 'Ashton', 'Westmoreland', FacilityClass.type1HealthCentre),
  _facility('Townhead Health Centre', 'Townhead', 'Westmoreland', FacilityClass.type1HealthCentre),
  _facility('Saint Pauls Health Centre', 'Saint Pauls', 'Westmoreland', FacilityClass.type1HealthCentre),
  _facility('Welcome Hall Health Centre', 'Welcome Hall', 'St. James', FacilityClass.type1HealthCentre),
  _facility('Johns Hall Health Centre', 'Johns Hall', 'St. James', FacilityClass.type1HealthCentre),
  _facility('Lottery Health Centre', 'Lottery', 'St. James', FacilityClass.type1HealthCentre),
  _facility('Salt Spring Health Centre', 'Salt Spring', 'St. James', FacilityClass.type1HealthCentre),
  _facility('Somerton Health Centre', 'Somerton', 'St. James', FacilityClass.type1HealthCentre),
  _facility('Roehampton Health Centre', 'Roehampton', 'St. James', FacilityClass.type1HealthCentre),
  _facility('Bickersteth Health Centre', 'Bickersteth', 'St. James', FacilityClass.type1HealthCentre),
  _facility('Chester Castle Health Centre', 'Chester Castle', 'Hanover', FacilityClass.type1HealthCentre),
  _facility('Great Valley Health Centre', 'Great Valley', 'Hanover', FacilityClass.type1HealthCentre),
  _facility('Miles Town Health Centre', 'Miles Town', 'Hanover', FacilityClass.type1HealthCentre),
  _facility('Askenish Health Centre', 'Askenish', 'Hanover', FacilityClass.type1HealthCentre),
  _facility('Chigwell Health Centre', 'Chigwell', 'Hanover', FacilityClass.type1HealthCentre),
  _facility('Deeside Health Centre', 'Deeside', 'Trelawny', FacilityClass.type1HealthCentre),
  _facility('Duanvale Health Centre', 'Duanvale', 'Trelawny', FacilityClass.type1HealthCentre),
  _facility('Troy Health Centre', 'Troy', 'Trelawny', FacilityClass.type1HealthCentre),
  _facility('Wait-a-Bit Health Centre', 'Wait-a-Bit', 'Trelawny', FacilityClass.type1HealthCentre),
  _facility('Lowe River Health Centre', 'Lowe River', 'Trelawny', FacilityClass.type1HealthCentre),
  _facility('Clark’s Town Health Centre', 'Clark’s Town', 'Trelawny', FacilityClass.type1HealthCentre),

  // Type 1 — St. Ann and St. Mary.
  _facility('Lime Hall Health Centre', 'Lime Hall', 'St. Ann', FacilityClass.type1HealthCentre),
  _facility('Muirhouse Health Centre', 'Muirhouse', 'St. Ann', FacilityClass.type1HealthCentre),
  _facility('Cascade Health Centre (St. Ann)', 'Cascade', 'St. Ann', FacilityClass.type1HealthCentre),
  _facility('Epworth Health Centre', 'Epworth', 'St. Ann', FacilityClass.type1HealthCentre),
  _facility('Bensonton Health Centre', 'Bensonton', 'St. Ann', FacilityClass.type1HealthCentre),
  _facility('Borobridge Health Centre', 'Borobridge', 'St. Ann', FacilityClass.type1HealthCentre),
  _facility('Keith Health Centre', 'Keith', 'St. Ann', FacilityClass.type1HealthCentre),
  _facility('Gibraltar Health Centre', 'Gibraltar', 'St. Ann', FacilityClass.type1HealthCentre),
  _facility('York Castle Health Centre', 'York Castle', 'St. Ann', FacilityClass.type1HealthCentre),
  _facility('Belfield Health Centre', 'Belfield', 'St. Mary', FacilityClass.type1HealthCentre),
  _facility('Albany Health Centre', 'Albany', 'St. Mary', FacilityClass.type1HealthCentre),
  _facility('Whitehall Health Centre', 'Whitehall', 'St. Mary', FacilityClass.type1HealthCentre),
  _facility('Bailey’s Vale Health Centre', 'Bailey’s Vale', 'St. Mary', FacilityClass.type1HealthCentre),
  _facility('Tremolsworth Health Centre', 'Tremolsworth', 'St. Mary', FacilityClass.type1HealthCentre),
  _facility('Lucky Hill Health Centre', 'Lucky Hill', 'St. Mary', FacilityClass.type1HealthCentre),
  _facility('Jacks River Health Centre', 'Jacks River', 'St. Mary', FacilityClass.type1HealthCentre),
  _facility('Free Hill Health Centre', 'Free Hill', 'St. Mary', FacilityClass.type1HealthCentre),
  _facility('Enfield Health Centre', 'Enfield', 'St. Mary', FacilityClass.type1HealthCentre),
  _facility('Robins Bay Health Centre', 'Robins Bay', 'St. Mary', FacilityClass.type1HealthCentre),

  // Type 1 — Portland and St. Thomas.
  _facility('Skibo Health Centre', 'Skibo', 'Portland', FacilityClass.type1HealthCentre),
  _facility('Swift River Health Centre', 'Swift River', 'Portland', FacilityClass.type1HealthCentre),
  _facility('Fruitful Vale Health Centre', 'Fruitful Vale', 'Portland', FacilityClass.type1HealthCentre),
  _facility('Long Bay Health Centre', 'Long Bay', 'Portland', FacilityClass.type1HealthCentre),
  _facility('Comfort Castle Health Centre', 'Comfort Castle', 'Portland', FacilityClass.type1HealthCentre),
  _facility('Moore Town Health Centre', 'Moore Town', 'Portland', FacilityClass.type1HealthCentre),
  _facility('Dalvey Health Centre', 'Dalvey', 'St. Thomas', FacilityClass.type1HealthCentre),
  _facility('Leith Hall Health Centre', 'Leith Hall', 'St. Thomas', FacilityClass.type1HealthCentre),
  _facility('Retreat Health Centre', 'Retreat', 'St. Thomas', FacilityClass.type1HealthCentre),
  _facility('Hillside Health Centre', 'Hillside', 'St. Thomas', FacilityClass.type1HealthCentre),
  _facility('Wheelerfield Health Centre', 'Wheelerfield', 'St. Thomas', FacilityClass.type1HealthCentre),
  _facility('Barking Lodge Health Centre', 'Barking Lodge', 'St. Thomas', FacilityClass.type1HealthCentre),
  _facility('Lloyds Health Centre', 'Lloyds', 'St. Thomas', FacilityClass.type1HealthCentre),

  // Type 1 — St. Catherine and Kingston/St. Andrew.
  _facility('Mount Rosser Health Centre', 'Mount Rosser', 'St. Catherine', FacilityClass.type1HealthCentre),
  _facility('McCook’s Pen Health Centre', 'McCook’s Pen', 'St. Catherine', FacilityClass.type1HealthCentre),
  _facility('Hellshire Health Centre', 'Hellshire', 'St. Catherine', FacilityClass.type1HealthCentre),
  _facility('Caymanas Health Centre', 'Caymanas', 'St. Catherine', FacilityClass.type1HealthCentre),
  _facility('Spring Village Health Centre', 'Spring Village', 'St. Catherine', FacilityClass.type1HealthCentre),
  _facility('Lluidas Vale Health Centre', 'Lluidas Vale', 'St. Catherine', FacilityClass.type1HealthCentre),
  _facility('Watermount Health Centre', 'Watermount', 'St. Catherine', FacilityClass.type1HealthCentre),
  _facility('Bartons Health Centre', 'Bartons', 'St. Catherine', FacilityClass.type1HealthCentre),
  _facility('Bellas Gate Health Centre', 'Bellas Gate', 'St. Catherine', FacilityClass.type1HealthCentre),
  _facility('Troja Health Centre', 'Troja', 'St. Catherine', FacilityClass.type1HealthCentre),
  _facility('Bermaddy Health Centre', 'Bermaddy', 'St. Catherine', FacilityClass.type1HealthCentre),
  _facility('Golden Spring Health Centre', 'Golden Spring', 'Kingston & St. Andrew', FacilityClass.type1HealthCentre),
  _facility('Dallas Castle Health Centre', 'Dallas Castle', 'Kingston & St. Andrew', FacilityClass.type1HealthCentre),
  _facility('Woodford Health Centre', 'Woodford', 'Kingston & St. Andrew', FacilityClass.type1HealthCentre),
  _facility('Mount Airy Health Centre', 'Mount Airy', 'Kingston & St. Andrew', FacilityClass.type1HealthCentre),
  _facility('Content Gap Health Centre', 'Content Gap', 'Kingston & St. Andrew', FacilityClass.type1HealthCentre),
];

Facility facilityByName(String name) => publicFacilityDirectory.firstWhere(
      (facility) => facility.name == name,
      orElse: () => throw StateError('Facility not found: $name'),
    );

List<Facility> facilitiesForClass(FacilityClass classification) =>
    publicFacilityDirectory.where((facility) => facility.classification == classification).toList(growable: false);

List<String> get facilityParishes {
  final values = publicFacilityDirectory.map((facility) => facility.parish).where((value) => value.isNotEmpty).toSet().toList()..sort();
  return values;
}
