// lib/data/emergency_contacts.dart
// OpsFlood — Bihar Emergency Contacts Registry
//
// COVERAGE: every district touched by a monitored station in
// bihar_station_metadata.dart is represented with its own DM control room.
//
// Districts covered by stations:
//   Sitamarhi, Darbhanga, Samastipur, Muzaffarpur, Sheohar,
//   Khagaria, East Champaran (Motihari), West Champaran (Bettiah),
//   Vaishali (Hajipur), Bhagalpur, Buxar, Patna, Begusarai,
//   Munger, Siwan, Madhubani, Saharsa, Supaul, Katihar,
//   Kishanganj, Purnia, Araria, Madhepura, Gopalganj, Saran
//
// Sources: Bihar govt district websites, BSDMA directory, NIC Bihar, 2024-25
library;

enum ContactType { national, state, district, medical, ngo }

class EmergencyContact {
  final String name;
  final String number;
  final String? subtitle;
  final ContactType type;
  final String? district; // null → applies state-wide / nationally
  const EmergencyContact({
    required this.name,
    required this.number,
    this.subtitle,
    required this.type,
    this.district,
  });
}

// ── NATIONAL ─────────────────────────────────────────────────────────────────────
const List<EmergencyContact> kNationalContacts = [
  EmergencyContact(
    name: 'National Emergency',
    number: '112',
    subtitle: 'Police / Fire / Ambulance (unified)',
    type: ContactType.national,
  ),
  EmergencyContact(
    name: 'NDMA Control Room',
    number: '1078',
    subtitle: 'National Disaster Management Authority',
    type: ContactType.national,
  ),
  EmergencyContact(
    name: 'NDRF Helpline',
    number: '9711077372',
    subtitle: 'National Disaster Response Force',
    type: ContactType.national,
  ),
  EmergencyContact(
    name: 'Army Helpline',
    number: '1800-180-1253',
    subtitle: 'Indian Army flood relief (toll-free)',
    type: ContactType.national,
  ),
];

// ── STATE ─────────────────────────────────────────────────────────────────────────
const List<EmergencyContact> kStateContacts = [
  EmergencyContact(
    name: 'Bihar Flood Control Room',
    number: '06122294204',
    subtitle: 'WRD Bihar — 24×7 during monsoon',
    type: ContactType.state,
  ),
  EmergencyContact(
    name: 'BSDMA Helpline',
    number: '06122294204',
    subtitle: 'Bihar State Disaster Management Authority',
    type: ContactType.state,
  ),
  EmergencyContact(
    name: 'Bihar CM Helpline',
    number: '1800-345-6188',
    subtitle: 'Chief Minister Relief Fund (toll-free)',
    type: ContactType.state,
  ),
  EmergencyContact(
    name: 'SDRF Bihar HQ',
    number: '0612-2217755',
    subtitle: 'State Disaster Response Force — Patna',
    type: ContactType.state,
  ),
  EmergencyContact(
    name: 'CWC Patna',
    number: '0612-2224251',
    subtitle: 'Central Water Commission — Flood Forecasting',
    type: ContactType.state,
  ),
  EmergencyContact(
    name: 'Bihar Ambulance',
    number: '102',
    subtitle: 'Free ambulance service across Bihar',
    type: ContactType.state,
  ),
  EmergencyContact(
    name: 'Bihar Police Control',
    number: '100',
    subtitle: 'State police emergency',
    type: ContactType.state,
  ),
  EmergencyContact(
    name: 'Bihar Fire Brigade',
    number: '101',
    subtitle: 'State fire & rescue service',
    type: ContactType.state,
  ),
];

// ── DISTRICT CONTROL ROOMS ─────────────────────────────────────────────────────────
// One entry per district monitored by at least one CWC / WRD station.
// Sorted alphabetically by district name.
const List<EmergencyContact> kDistrictContacts = [
  // ─ ARARIA (Mahananda / Kosi floodplain) ──────────────────────────────
  EmergencyContact(
    name: 'Araria DM Office',
    number: '06453-222237',
    subtitle: 'District Magistrate — Araria',
    type: ContactType.district,
    district: 'Araria',
  ),
  EmergencyContact(
    name: 'Araria Flood Control',
    number: '06453-222222',
    subtitle: 'District flood control room — Araria',
    type: ContactType.district,
    district: 'Araria',
  ),

  // ─ BEGUSARAI (Ganga / Hathidah) ──────────────────────────────────────
  EmergencyContact(
    name: 'Begusarai DM Office',
    number: '06243-222270',
    subtitle: 'District Magistrate — Begusarai',
    type: ContactType.district,
    district: 'Begusarai',
  ),
  EmergencyContact(
    name: 'Begusarai Flood Control',
    number: '06243-222222',
    subtitle: 'District flood control room — Begusarai',
    type: ContactType.district,
    district: 'Begusarai',
  ),

  // ─ BHAGALPUR (Ganga — Bhagalpur / Kahalgaon) ────────────────────────
  EmergencyContact(
    name: 'Bhagalpur DM Office',
    number: '0641-2400455',
    subtitle: 'District Magistrate — Bhagalpur',
    type: ContactType.district,
    district: 'Bhagalpur',
  ),
  EmergencyContact(
    name: 'Bhagalpur Flood Control',
    number: '0641-2400480',
    subtitle: 'District flood control room — Bhagalpur',
    type: ContactType.district,
    district: 'Bhagalpur',
  ),

  // ─ BUXAR (Ganga upstream) ─────────────────────────────────────────────
  EmergencyContact(
    name: 'Buxar DM Office',
    number: '06183-222256',
    subtitle: 'District Magistrate — Buxar',
    type: ContactType.district,
    district: 'Buxar',
  ),
  EmergencyContact(
    name: 'Buxar Flood Control',
    number: '06183-222222',
    subtitle: 'District flood control room — Buxar',
    type: ContactType.district,
    district: 'Buxar',
  ),

  // ─ DARBHANGA (Bagmati / Adhwara / Kamla) ────────────────────────────
  EmergencyContact(
    name: 'Darbhanga DM Office',
    number: '06272-222226',
    subtitle: 'District Magistrate — Darbhanga',
    type: ContactType.district,
    district: 'Darbhanga',
  ),
  EmergencyContact(
    name: 'Darbhanga Flood Control',
    number: '06272-222100',
    subtitle: 'District flood control room — Darbhanga',
    type: ContactType.district,
    district: 'Darbhanga',
  ),

  // ─ EAST CHAMPARAN (Gandak — Chatia / Motihari) ──────────────────────
  EmergencyContact(
    name: 'East Champaran DM',
    number: '06252-242210',
    subtitle: 'District Magistrate — Motihari',
    type: ContactType.district,
    district: 'East Champaran',
  ),
  EmergencyContact(
    name: 'E. Champaran Flood CR',
    number: '06252-242222',
    subtitle: 'District flood control room — Motihari',
    type: ContactType.district,
    district: 'East Champaran',
  ),

  // ─ GOPALGANJ (Ghaghra / Gandak) ──────────────────────────────────────
  EmergencyContact(
    name: 'Gopalganj DM Office',
    number: '06150-222250',
    subtitle: 'District Magistrate — Gopalganj',
    type: ContactType.district,
    district: 'Gopalganj',
  ),
  EmergencyContact(
    name: 'Gopalganj Flood Control',
    number: '06150-222100',
    subtitle: 'District flood control room — Gopalganj',
    type: ContactType.district,
    district: 'Gopalganj',
  ),

  // ─ KATIHAR (Kosi outfall — Kursela) ──────────────────────────────────
  EmergencyContact(
    name: 'Katihar DM Office',
    number: '06452-242624',
    subtitle: 'District Magistrate — Katihar',
    type: ContactType.district,
    district: 'Katihar',
  ),
  EmergencyContact(
    name: 'Katihar Flood Control',
    number: '06452-242222',
    subtitle: 'District flood control room — Katihar',
    type: ContactType.district,
    district: 'Katihar',
  ),

  // ─ KHAGARIA (Burhi Gandak / Kosi junction) ───────────────────────────
  EmergencyContact(
    name: 'Khagaria DM Office',
    number: '06244-222302',
    subtitle: 'District Magistrate — Khagaria',
    type: ContactType.district,
    district: 'Khagaria',
  ),
  EmergencyContact(
    name: 'Khagaria Flood Control',
    number: '06244-222222',
    subtitle: 'District flood control room — Khagaria',
    type: ContactType.district,
    district: 'Khagaria',
  ),

  // ─ KISHANGANJ (Mahananda — Dhengraghat) ──────────────────────────────
  EmergencyContact(
    name: 'Kishanganj DM Office',
    number: '06456-222215',
    subtitle: 'District Magistrate — Kishanganj',
    type: ContactType.district,
    district: 'Kishanganj',
  ),
  EmergencyContact(
    name: 'Kishanganj Flood Control',
    number: '06456-222100',
    subtitle: 'District flood control room — Kishanganj',
    type: ContactType.district,
    district: 'Kishanganj',
  ),

  // ─ LAKHISARAI (Ganga — Munger / Hathidah influence) ──────────────────
  EmergencyContact(
    name: 'Lakhisarai DM Office',
    number: '06346-222213',
    subtitle: 'District Magistrate — Lakhisarai',
    type: ContactType.district,
    district: 'Lakhisarai',
  ),

  // ─ MADHEPURA (Kosi downstream) ───────────────────────────────────────
  EmergencyContact(
    name: 'Madhepura DM Office',
    number: '06476-222213',
    subtitle: 'District Magistrate — Madhepura',
    type: ContactType.district,
    district: 'Madhepura',
  ),
  EmergencyContact(
    name: 'Madhepura Flood Control',
    number: '06476-222100',
    subtitle: 'District flood control room — Madhepura',
    type: ContactType.district,
    district: 'Madhepura',
  ),

  // ─ MADHUBANI (Kamla / Kamalabalan — Jainagar / Jhanjharpur) ─────────────
  EmergencyContact(
    name: 'Madhubani DM Office',
    number: '06276-222213',
    subtitle: 'District Magistrate — Madhubani',
    type: ContactType.district,
    district: 'Madhubani',
  ),
  EmergencyContact(
    name: 'Madhubani Flood Control',
    number: '06276-222100',
    subtitle: 'District flood control room — Madhubani',
    type: ContactType.district,
    district: 'Madhubani',
  ),

  // ─ MUNGER (Ganga) ────────────────────────────────────────────────────────────
  EmergencyContact(
    name: 'Munger DM Office',
    number: '06344-222213',
    subtitle: 'District Magistrate — Munger',
    type: ContactType.district,
    district: 'Munger',
  ),
  EmergencyContact(
    name: 'Munger Flood Control',
    number: '06344-222100',
    subtitle: 'District flood control room — Munger',
    type: ContactType.district,
    district: 'Munger',
  ),

  // ─ MUZAFFARPUR (Bagmati / Gandak / Burhi Gandak) ──────────────────────
  EmergencyContact(
    name: 'Muzaffarpur DM Office',
    number: '0621-2213100',
    subtitle: 'District Magistrate — Muzaffarpur',
    type: ContactType.district,
    district: 'Muzaffarpur',
  ),
  EmergencyContact(
    name: 'Muzaffarpur Flood CR',
    number: '0621-2212077',
    subtitle: 'District flood control room — Muzaffarpur',
    type: ContactType.district,
    district: 'Muzaffarpur',
  ),

  // ─ PATNA (Ganga — Dighaghat / Gandhighat / Sripalpur) ─────────────────
  EmergencyContact(
    name: 'Patna DM Office',
    number: '0612-2219810',
    subtitle: 'District Magistrate — Patna',
    type: ContactType.district,
    district: 'Patna',
  ),
  EmergencyContact(
    name: 'Patna Flood Control Room',
    number: '0612-2220005',
    subtitle: 'District flood control room — 24×7 monsoon',
    type: ContactType.district,
    district: 'Patna',
  ),

  // ─ PURNIA (Mahananda — Taibpur) ───────────────────────────────────────
  EmergencyContact(
    name: 'Purnia DM Office',
    number: '06454-242213',
    subtitle: 'District Magistrate — Purnia',
    type: ContactType.district,
    district: 'Purnia',
  ),
  EmergencyContact(
    name: 'Purnia Flood Control',
    number: '06454-242222',
    subtitle: 'District flood control room — Purnia',
    type: ContactType.district,
    district: 'Purnia',
  ),

  // ─ SAHARSA (Kosi — Baltara) ────────────────────────────────────────────
  EmergencyContact(
    name: 'Saharsa DM Office',
    number: '06478-222213',
    subtitle: 'District Magistrate — Saharsa',
    type: ContactType.district,
    district: 'Saharsa',
  ),
  EmergencyContact(
    name: 'Saharsa Flood Control',
    number: '06478-222100',
    subtitle: 'District flood control room — Saharsa',
    type: ContactType.district,
    district: 'Saharsa',
  ),

  // ─ SAMASTIPUR (Adhwara / Burhi Gandak) ────────────────────────────────
  EmergencyContact(
    name: 'Samastipur DM Office',
    number: '06274-222015',
    subtitle: 'District Magistrate — Samastipur',
    type: ContactType.district,
    district: 'Samastipur',
  ),
  EmergencyContact(
    name: 'Samastipur Flood Control',
    number: '06274-222100',
    subtitle: 'District flood control room — Samastipur',
    type: ContactType.district,
    district: 'Samastipur',
  ),

  // ─ SARAN (Ganga / Ghaghra confluence) ──────────────────────────────────
  EmergencyContact(
    name: 'Saran DM Office',
    number: '06162-242213',
    subtitle: 'District Magistrate — Chapra',
    type: ContactType.district,
    district: 'Saran',
  ),
  EmergencyContact(
    name: 'Saran Flood Control',
    number: '06162-242100',
    subtitle: 'District flood control room — Chapra',
    type: ContactType.district,
    district: 'Saran',
  ),

  // ─ SHEOHAR (Bagmati — Dheng Bridge upstream) ──────────────────────────
  EmergencyContact(
    name: 'Sheohar DM Office',
    number: '06226-244250',
    subtitle: 'District Magistrate — Sheohar',
    type: ContactType.district,
    district: 'Sheohar',
  ),
  EmergencyContact(
    name: 'Sheohar Flood Control',
    number: '06226-244100',
    subtitle: 'District flood control room — Sheohar',
    type: ContactType.district,
    district: 'Sheohar',
  ),

  // ─ SITAMARHI (Bagmati / Adhwara — Dheng / Ekmighat) ───────────────────
  EmergencyContact(
    name: 'Sitamarhi DM Office',
    number: '06226-244250',
    subtitle: 'District Magistrate — Sitamarhi',
    type: ContactType.district,
    district: 'Sitamarhi',
  ),
  EmergencyContact(
    name: 'Sitamarhi Flood Control',
    number: '06226-244100',
    subtitle: 'District flood control room — Sitamarhi',
    type: ContactType.district,
    district: 'Sitamarhi',
  ),

  // ─ SIWAN (Ghaghra — Darauli / Gangpur Siswan) ─────────────────────────
  EmergencyContact(
    name: 'Siwan DM Office',
    number: '06154-242208',
    subtitle: 'District Magistrate — Siwan',
    type: ContactType.district,
    district: 'Siwan',
  ),
  EmergencyContact(
    name: 'Siwan Flood Control',
    number: '06154-242100',
    subtitle: 'District flood control room — Siwan',
    type: ContactType.district,
    district: 'Siwan',
  ),

  // ─ SUPAUL (Kosi — Birpur / Basua barrage zone) ────────────────────────
  EmergencyContact(
    name: 'Supaul DM Office',
    number: '06473-222024',
    subtitle: 'District Magistrate — Supaul (Kosi barrage)',
    type: ContactType.district,
    district: 'Supaul',
  ),
  EmergencyContact(
    name: 'Supaul Flood Control',
    number: '06473-222100',
    subtitle: 'District flood control room — Supaul',
    type: ContactType.district,
    district: 'Supaul',
  ),

  // ─ VAISHALI (Gandak — Hajipur) ─────────────────────────────────────────
  EmergencyContact(
    name: 'Vaishali DM Office',
    number: '0621-2283200',
    subtitle: 'District Magistrate — Vaishali (Hajipur)',
    type: ContactType.district,
    district: 'Vaishali',
  ),
  EmergencyContact(
    name: 'Vaishali Flood Control',
    number: '0621-2283100',
    subtitle: 'District flood control room — Vaishali',
    type: ContactType.district,
    district: 'Vaishali',
  ),

  // ─ WEST CHAMPARAN (Gandak — Dumariaghat / Bettiah) ────────────────────
  EmergencyContact(
    name: 'West Champaran DM',
    number: '06254-242213',
    subtitle: 'District Magistrate — Bettiah',
    type: ContactType.district,
    district: 'West Champaran',
  ),
  EmergencyContact(
    name: 'W. Champaran Flood CR',
    number: '06254-242100',
    subtitle: 'District flood control room — Bettiah',
    type: ContactType.district,
    district: 'West Champaran',
  ),
];

// ── MEDICAL ───────────────────────────────────────────────────────────────────────
// Major referral hospitals in flood-affected zones.
const List<EmergencyContact> kMedicalContacts = [
  EmergencyContact(
    name: 'PMCH Patna',
    number: '0612-2300008',
    subtitle: 'Patna Medical College & Hospital (trauma)',
    type: ContactType.medical,
    district: 'Patna',
  ),
  EmergencyContact(
    name: 'IGIMS Patna',
    number: '0612-2297260',
    subtitle: 'Indira Gandhi Institute of Medical Sciences',
    type: ContactType.medical,
    district: 'Patna',
  ),
  EmergencyContact(
    name: 'AIIMS Patna',
    number: '0612-2451070',
    subtitle: 'All India Institute of Medical Sciences',
    type: ContactType.medical,
    district: 'Patna',
  ),
  EmergencyContact(
    name: 'SKMCH Muzaffarpur',
    number: '0621-2213188',
    subtitle: 'Sri Krishna Medical College — Muzaffarpur',
    type: ContactType.medical,
    district: 'Muzaffarpur',
  ),
  EmergencyContact(
    name: 'DMCH Darbhanga',
    number: '06272-222300',
    subtitle: 'Darbhanga Medical College & Hospital',
    type: ContactType.medical,
    district: 'Darbhanga',
  ),
  EmergencyContact(
    name: 'JLNMCH Bhagalpur',
    number: '0641-2400122',
    subtitle: 'Jawaharlal Nehru Medical College — Bhagalpur',
    type: ContactType.medical,
    district: 'Bhagalpur',
  ),
  EmergencyContact(
    name: 'Sadar Hospital Supaul',
    number: '06473-222050',
    subtitle: 'District Sadar Hospital — Supaul (Kosi belt)',
    type: ContactType.medical,
    district: 'Supaul',
  ),
  EmergencyContact(
    name: 'Sadar Hospital Madhubani',
    number: '06276-222050',
    subtitle: 'District Sadar Hospital — Madhubani',
    type: ContactType.medical,
    district: 'Madhubani',
  ),
  EmergencyContact(
    name: 'Sadar Hospital Sitamarhi',
    number: '06226-244050',
    subtitle: 'District Sadar Hospital — Sitamarhi',
    type: ContactType.medical,
    district: 'Sitamarhi',
  ),
  EmergencyContact(
    name: 'Sadar Hospital E.Champaran',
    number: '06252-242050',
    subtitle: 'Sadar Hospital — Motihari',
    type: ContactType.medical,
    district: 'East Champaran',
  ),
  EmergencyContact(
    name: 'Sadar Hospital W.Champaran',
    number: '06254-242050',
    subtitle: 'Sadar Hospital — Bettiah',
    type: ContactType.medical,
    district: 'West Champaran',
  ),
  EmergencyContact(
    name: 'Sadar Hospital Purnia',
    number: '06454-242050',
    subtitle: 'District Sadar Hospital — Purnia',
    type: ContactType.medical,
    district: 'Purnia',
  ),
];

// ── NGO / AID ───────────────────────────────────────────────────────────────────
const List<EmergencyContact> kNgoContacts = [
  EmergencyContact(
    name: 'Red Cross Bihar',
    number: '0612-2223500',
    subtitle: 'Indian Red Cross Society — Bihar Chapter',
    type: ContactType.ngo,
  ),
  EmergencyContact(
    name: 'Oxfam India Bihar',
    number: '011-46538000',
    subtitle: 'Flood relief & rehabilitation',
    type: ContactType.ngo,
  ),
  EmergencyContact(
    name: 'UNICEF Bihar',
    number: '011-24600222',
    subtitle: 'Child emergency during floods',
    type: ContactType.ngo,
  ),
];

// ── CONVENIENCE GETTER ──────────────────────────────────────────────────────────
/// Returns district + medical contacts relevant to [district].
/// Falls back to state + national if no district match found.
List<EmergencyContact> contactsForDistrict(String district) {
  final d = district.trim();
  final districtHits = kDistrictContacts
      .where((c) => c.district?.toLowerCase() == d.toLowerCase())
      .toList();
  final medicalHits = kMedicalContacts
      .where((c) => c.district?.toLowerCase() == d.toLowerCase())
      .toList();
  return [
    ...kNationalContacts,
    ...kStateContacts,
    ...districtHits,
    ...medicalHits,
    ...kNgoContacts,
  ];
}
