// lib/data/evacuation_routes_data.dart
// OpsFlood — Static Bihar district evacuation routes & shelters
// All data is baked-in; works fully offline.
library;

class EvacuationShelter {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final int capacity;
  final String phone;

  const EvacuationShelter({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.capacity,
    required this.phone,
  });
}

class EvacuationRoute {
  final String id;
  final String from;
  final String to;
  final String highway;
  final double distanceKm;
  final String description;
  final List<String> waypoints;
  final bool isFloodProne;

  const EvacuationRoute({
    required this.id,
    required this.from,
    required this.to,
    required this.highway,
    required this.distanceKm,
    required this.description,
    required this.waypoints,
    this.isFloodProne = false,
  });
}

class DistrictEvacuationInfo {
  final String district;
  final String division;
  final double lat;
  final double lng;
  final String controlRoomPhone;
  final String dmPhone;
  final List<EvacuationRoute> routes;
  final List<EvacuationShelter> shelters;
  final String floodRisk; // 'HIGH' | 'MEDIUM' | 'LOW'

  const DistrictEvacuationInfo({
    required this.district,
    required this.division,
    required this.lat,
    required this.lng,
    required this.controlRoomPhone,
    required this.dmPhone,
    required this.routes,
    required this.shelters,
    required this.floodRisk,
  });
}

class EvacuationRoutesData {
  static const List<DistrictEvacuationInfo> districts = [
    DistrictEvacuationInfo(
      district: 'Patna',
      division: 'Patna',
      lat: 25.5941,
      lng: 85.1376,
      controlRoomPhone: '0612-2215081',
      dmPhone: '0612-2950181',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'PAT-R1',
          from: 'Patna City (Riverfront)',
          to: 'Patna Sahib Relief Camp',
          highway: 'NH-19 / Ashok Rajpath',
          distanceKm: 12.0,
          description: 'Move east along Ashok Rajpath away from Ganga embankment. Avoid underpasses during peak flood.',
          waypoints: ['Gandhi Maidan', 'Rajendra Nagar', 'Patna Sahib'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'PAT-R2',
          from: 'Phulwarisharif',
          to: 'Khagaul Higher Ground',
          highway: 'NH-30',
          distanceKm: 8.5,
          description: 'South towards NH-30 then west to Khagaul. Recommended for Danapur & Phulwari areas.',
          waypoints: ['Danapur', 'Khagaul'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Patna University Shelter Camp',
          address: 'Patna University Campus, Ashok Rajpath',
          lat: 25.6163,
          lng: 85.1413,
          capacity: 2000,
          phone: '0612-2670077',
        ),
        EvacuationShelter(
          name: 'Gandhi Maidan Relief Centre',
          address: 'Gandhi Maidan, Patna',
          lat: 25.6093,
          lng: 85.1264,
          capacity: 5000,
          phone: '0612-2214226',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Darbhanga',
      division: 'Darbhanga',
      lat: 26.1522,
      lng: 85.8993,
      controlRoomPhone: '06272-222333',
      dmPhone: '06272-222111',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'DBH-R1',
          from: 'Baheri (North Darbhanga)',
          to: 'Darbhanga Town',
          highway: 'NH-57',
          distanceKm: 22.0,
          description: 'Head south on NH-57 toward Darbhanga town which sits on higher ground. Avoid Kamla riverbanks.',
          waypoints: ['Baheri', 'Tardih', 'Darbhanga'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'DBH-R2',
          from: 'Darbhanga East',
          to: 'Samastipur (Safe Zone)',
          highway: 'NH-57 South',
          distanceKm: 35.0,
          description: 'Move south-east to Samastipur for high-risk Kamla-Bagmati inundation events.',
          waypoints: ['Hayaghat', 'Samastipur'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'LN Mithila University Camp',
          address: 'LNMU Campus, Darbhanga',
          lat: 26.1522,
          lng: 85.9000,
          capacity: 3000,
          phone: '06272-252627',
        ),
        EvacuationShelter(
          name: 'Darbhanga Medical College',
          address: 'DMCH, Laheriasarai, Darbhanga',
          lat: 26.1443,
          lng: 85.9124,
          capacity: 1500,
          phone: '06272-222524',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Muzaffarpur',
      division: 'Tirhut',
      lat: 26.1209,
      lng: 85.3647,
      controlRoomPhone: '0621-2212200',
      dmPhone: '0621-2212100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'MUZ-R1',
          from: 'Katra (Bagmati Bank)',
          to: 'Muzaffarpur Town',
          highway: 'SH-74',
          distanceKm: 18.0,
          description: 'South on SH-74 to Muzaffarpur urban area. Katra and Aurai blocks face highest inundation risk.',
          waypoints: ['Katra', 'Aurai', 'Muzaffarpur'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'MUZ-R2',
          from: 'Sitamarhi Border',
          to: 'Muzaffarpur via Sheohar',
          highway: 'NH-77',
          distanceKm: 55.0,
          description: 'For northern Muzaffarpur blocks, move via Sheohar on NH-77.',
          waypoints: ['Sheohar', 'Dholi', 'Muzaffarpur'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'SKMCH Relief Camp',
          address: 'Sri Krishna Medical College, Muzaffarpur',
          lat: 26.1209,
          lng: 85.3800,
          capacity: 2500,
          phone: '0621-2211200',
        ),
        EvacuationShelter(
          name: 'BRA Bihar University Shelter',
          address: 'BRA Bihar University, Muzaffarpur',
          lat: 26.1300,
          lng: 85.3900,
          capacity: 2000,
          phone: '0621-2262007',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Bhagalpur',
      division: 'Bhagalpur',
      lat: 25.2425,
      lng: 86.9842,
      controlRoomPhone: '0641-2400100',
      dmPhone: '0641-2400500',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'BHG-R1',
          from: 'Naugachia (Kosi-Ganga confluence)',
          to: 'Bhagalpur Town',
          highway: 'NH-131A',
          distanceKm: 30.0,
          description: 'Move west-south on NH-131A toward Bhagalpur town away from Kosi-Ganga flood zone.',
          waypoints: ['Naugachia', 'Goradih', 'Bhagalpur'],
          isFloodProne: true,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'TNB College Relief Centre',
          address: 'Tilka Manjhi BU, Bhagalpur',
          lat: 25.2500,
          lng: 86.9900,
          capacity: 2000,
          phone: '0641-2422900',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Sitamarhi',
      division: 'Tirhut',
      lat: 26.5918,
      lng: 85.4863,
      controlRoomPhone: '06226-252222',
      dmPhone: '06226-252100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'STM-R1',
          from: 'Runnisaidpur (North)',
          to: 'Sitamarhi Town',
          highway: 'NH-77',
          distanceKm: 25.0,
          description: 'South on NH-77 to Sitamarhi town. Bagmati and Lakhandei overflow is primary threat.',
          waypoints: ['Runnisaidpur', 'Pupri', 'Sitamarhi'],
          isFloodProne: true,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Sitamarhi Collectorate Camp',
          address: 'DM Office Compound, Sitamarhi',
          lat: 26.5918,
          lng: 85.4900,
          capacity: 1500,
          phone: '06226-252333',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Supaul',
      division: 'Kosi',
      lat: 26.1167,
      lng: 86.6000,
      controlRoomPhone: '06473-222222',
      dmPhone: '06473-222100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'SUP-R1',
          from: 'Birpur (Kosi Barrage)',
          to: 'Supaul Town',
          highway: 'SH-75',
          distanceKm: 20.0,
          description: 'Move south-east away from Kosi barrage area. Birpur is at extreme flood risk.',
          waypoints: ['Birpur', 'Triveniganj', 'Supaul'],
          isFloodProne: true,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Supaul Higher Secondary Relief Camp',
          address: 'District School Campus, Supaul',
          lat: 26.1167,
          lng: 86.6050,
          capacity: 1000,
          phone: '06473-222500',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Madhubani',
      division: 'Darbhanga',
      lat: 26.3531,
      lng: 86.0714,
      controlRoomPhone: '06276-222111',
      dmPhone: '06276-222200',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'MDH-R1',
          from: 'Jhanjharpur (Kamla Bank)',
          to: 'Madhubani Town',
          highway: 'NH-57',
          distanceKm: 28.0,
          description: 'South on NH-57. Jhanjharpur and Phulparas are highest-risk blocks.',
          waypoints: ['Jhanjharpur', 'Phulparas', 'Madhubani'],
          isFloodProne: true,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Madhubani DM Camp',
          address: 'DM Office, Madhubani',
          lat: 26.3531,
          lng: 86.0800,
          capacity: 1200,
          phone: '06276-222300',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Samastipur',
      division: 'Darbhanga',
      lat: 25.8584,
      lng: 85.7818,
      controlRoomPhone: '06274-222111',
      dmPhone: '06274-222200',
      floodRisk: 'MEDIUM',
      routes: [
        EvacuationRoute(
          id: 'SMS-R1',
          from: 'Rosera (Balan Bank)',
          to: 'Samastipur Town',
          highway: 'NH-28',
          distanceKm: 30.0,
          description: 'South on NH-28 to Samastipur. Avoid low-lying Balan and Bagmati flood corridors.',
          waypoints: ['Rosera', 'Tajpur', 'Samastipur'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'RSKD College Shelter',
          address: 'RSKD College, Samastipur',
          lat: 25.8600,
          lng: 85.7900,
          capacity: 1500,
          phone: '06274-240000',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Gopalganj',
      division: 'Saran',
      lat: 26.4672,
      lng: 84.4323,
      controlRoomPhone: '06150-222222',
      dmPhone: '06150-222100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'GPL-R1',
          from: 'Siwan Border (Gandak Bank)',
          to: 'Gopalganj Town',
          highway: 'NH-28A',
          distanceKm: 40.0,
          description: 'East toward Gopalganj on NH-28A. Gandak and Ghaghra overflow threat is primary.',
          waypoints: ['Hathua', 'Kataiya', 'Gopalganj'],
          isFloodProne: true,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Gopalganj Collectorate Camp',
          address: 'Collectorate Road, Gopalganj',
          lat: 26.4672,
          lng: 84.4400,
          capacity: 2000,
          phone: '06150-222333',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Saran',
      division: 'Saran',
      lat: 25.9167,
      lng: 84.7333,
      controlRoomPhone: '06162-240000',
      dmPhone: '06162-240100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'SAR-R1',
          from: 'Revelganj (Ghaghra-Ganga)',
          to: 'Chhapra Town',
          highway: 'NH-19',
          distanceKm: 35.0,
          description: 'East on NH-19 away from Ghaghra-Ganga confluence. Revelganj, Manjhi, Marhaura are high-risk.',
          waypoints: ['Revelganj', 'Marhaura', 'Chhapra'],
          isFloodProne: true,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'JP University Relief Camp',
          address: 'Jai Prakash University, Chhapra',
          lat: 25.7800,
          lng: 84.7300,
          capacity: 2500,
          phone: '06162-242000',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Katihar',
      division: 'Purnea',
      lat: 25.5368,
      lng: 87.5714,
      controlRoomPhone: '06452-240000',
      dmPhone: '06452-240100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'KTH-R1',
          from: 'Manihari (Ganga-Mahananda)',
          to: 'Katihar Town',
          highway: 'NH-31',
          distanceKm: 45.0,
          description: 'West on NH-31 to Katihar. Manihari and Amdabad blocks face severe inundation from Ganga & Mahananda.',
          waypoints: ['Manihari', 'Barari', 'Katihar'],
          isFloodProne: true,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Katihar Medical College Camp',
          address: 'KMCH, Katihar',
          lat: 25.5400,
          lng: 87.5800,
          capacity: 2000,
          phone: '06452-245000',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Araria',
      division: 'Kosi',
      lat: 26.1467,
      lng: 87.4715,
      controlRoomPhone: '06453-222222',
      dmPhone: '06453-222100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'ARA-R1',
          from: 'Jokihat (Nepal Border)',
          to: 'Araria Town',
          highway: 'NH-57',
          distanceKm: 30.0,
          description: 'South on NH-57. Bakra and Bharbharia rivers pose high threat in northern Araria.',
          waypoints: ['Jokihat', 'Raniganj', 'Araria'],
          isFloodProne: true,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Araria Collectorate Relief Camp',
          address: 'Collectorate Campus, Araria',
          lat: 26.1467,
          lng: 87.4800,
          capacity: 1200,
          phone: '06453-222333',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Kishanganj',
      division: 'Purnea',
      lat: 26.0943,
      lng: 87.9430,
      controlRoomPhone: '06456-220000',
      dmPhone: '06456-220100',
      floodRisk: 'MEDIUM',
      routes: [
        EvacuationRoute(
          id: 'KSG-R1',
          from: 'Thakurganj (Mahananda Bank)',
          to: 'Kishanganj Town',
          highway: 'NH-31',
          distanceKm: 22.0,
          description: 'South-west on NH-31. Mahananda and Kankai overflow is primary risk.',
          waypoints: ['Thakurganj', 'Bahadurganj', 'Kishanganj'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Kishanganj Stadium Camp',
          address: 'District Stadium, Kishanganj',
          lat: 26.0943,
          lng: 87.9500,
          capacity: 1000,
          phone: '06456-220500',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Purnea',
      division: 'Purnea',
      lat: 25.7775,
      lng: 87.4753,
      controlRoomPhone: '06454-220000',
      dmPhone: '06454-220100',
      floodRisk: 'MEDIUM',
      routes: [
        EvacuationRoute(
          id: 'PUR-R1',
          from: 'Kasba (Mahananda)',
          to: 'Purnea Town',
          highway: 'NH-31',
          distanceKm: 25.0,
          description: 'South on NH-31 toward Purnea town. Kasba, Banmankhi blocks have high Mahananda risk.',
          waypoints: ['Kasba', 'Banmankhi', 'Purnea'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Purnea University Camp',
          address: 'Purnea University, Purnea',
          lat: 25.7800,
          lng: 87.4800,
          capacity: 2000,
          phone: '06454-221000',
        ),
      ],
    ),
    DistrictEvacuationInfo(
      district: 'Vaishali',
      division: 'Tirhut',
      lat: 25.6949,
      lng: 85.1962,
      controlRoomPhone: '06224-222111',
      dmPhone: '06224-222200',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'VAI-R1',
          from: 'Hajipur (Ganga-Gandak Doab)',
          to: 'Muzaffarpur via NH-57',
          highway: 'NH-57',
          distanceKm: 30.0,
          description: 'North on NH-57 to Muzaffarpur. Doab region floods severely during Ganga-Gandak peak.',
          waypoints: ['Hajipur', 'Lalganj', 'Muzaffarpur'],
          isFloodProne: true,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Hajipur Town Hall Camp',
          address: 'Town Hall, Hajipur',
          lat: 25.6949,
          lng: 85.2100,
          capacity: 1500,
          phone: '06224-222500',
        ),
      ],
    ),
  ];

  static List<String> get districtNames =>
      districts.map((d) => d.district).toList()..sort();

  static DistrictEvacuationInfo? forDistrict(String name) {
    try {
      return districts.firstWhere(
        (d) => d.district.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  static List<DistrictEvacuationInfo> byRisk(String risk) =>
      districts.where((d) => d.floodRisk == risk).toList();
}
