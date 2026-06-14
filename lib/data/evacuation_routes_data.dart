// lib/data/evacuation_routes_data.dart
// OpsFlood — Static Bihar district evacuation routes & shelters
// All 38 districts — works fully offline.
// v2 (14 Jun 2026): complete coverage for all 38 districts.
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

    // ------------------------------------------------------------------ PATNA
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

    // --------------------------------------------------------------- NALANDA
    DistrictEvacuationInfo(
      district: 'Nalanda',
      division: 'Patna',
      lat: 25.1376,
      lng: 85.4440,
      controlRoomPhone: '06112-232100',
      dmPhone: '06112-232200',
      floodRisk: 'LOW',
      routes: [
        EvacuationRoute(
          id: 'NAL-R1',
          from: 'Harnaut (Panchane River)',
          to: 'Bihar Sharif Town',
          highway: 'NH-20',
          distanceKm: 20.0,
          description: 'North-east on NH-20 to Bihar Sharif. Harnaut and Asthawan blocks face Panchane overflow.',
          waypoints: ['Harnaut', 'Asthawan', 'Bihar Sharif'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'NAL-R2',
          from: 'Rajgir',
          to: 'Nalanda (Bada Gaon)',
          highway: 'SH-78',
          distanceKm: 14.0,
          description: 'North-west on SH-78. Rajgir sits on hills and serves as an alternate high-ground refuge.',
          waypoints: ['Rajgir', 'Silao', 'Nalanda'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Bihar Sharif Stadium Camp',
          address: 'District Stadium, Bihar Sharif',
          lat: 25.1980,
          lng: 85.5250,
          capacity: 2000,
          phone: '06112-232333',
        ),
        EvacuationShelter(
          name: 'Nalanda Open University Camp',
          address: 'NAOU, Bihar Sharif Road',
          lat: 25.1900,
          lng: 85.5100,
          capacity: 1000,
          phone: '06112-232500',
        ),
      ],
    ),

    // --------------------------------------------------------------- BHOJPUR
    DistrictEvacuationInfo(
      district: 'Bhojpur',
      division: 'Patna',
      lat: 25.5600,
      lng: 84.4833,
      controlRoomPhone: '06182-232222',
      dmPhone: '06182-232100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'BHJ-R1',
          from: 'Piro (Ganga South Bank)',
          to: 'Ara Town',
          highway: 'NH-30',
          distanceKm: 38.0,
          description: 'East on NH-30 to Ara. Piro, Jagdishpur, Sandesh blocks severely flood from Ganga back-water.',
          waypoints: ['Piro', 'Jagdishpur', 'Sandesh', 'Ara'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'BHJ-R2',
          from: 'Shahpur (Son Doab)',
          to: 'Ara via SH-5',
          highway: 'SH-5',
          distanceKm: 22.0,
          description: 'East on SH-5. Son river doab floods during heavy upstream rainfall.',
          waypoints: ['Shahpur', 'Barhara', 'Ara'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Veer Kunwar Singh University Camp',
          address: 'VKSU Campus, Ara',
          lat: 25.5566,
          lng: 84.6619,
          capacity: 2500,
          phone: '06182-236000',
        ),
        EvacuationShelter(
          name: 'Ara District School Camp',
          address: 'Zila School, Ara',
          lat: 25.5600,
          lng: 84.6650,
          capacity: 1500,
          phone: '06182-232400',
        ),
      ],
    ),

    // ----------------------------------------------------------------- BUXAR
    DistrictEvacuationInfo(
      district: 'Buxar',
      division: 'Patna',
      lat: 25.5643,
      lng: 83.9742,
      controlRoomPhone: '06183-222222',
      dmPhone: '06183-222100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'BXR-R1',
          from: 'Chausa (Ganga Bank)',
          to: 'Buxar Town',
          highway: 'NH-19',
          distanceKm: 18.0,
          description: 'East on NH-19 to Buxar. Chausa and Nawanagar are directly flood-exposed from Ganga.',
          waypoints: ['Chausa', 'Nawanagar', 'Buxar'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'BXR-R2',
          from: 'Dumraon (Son Confluence)',
          to: 'Arrah via NH-30',
          highway: 'NH-30',
          distanceKm: 55.0,
          description: 'South-east on NH-30. Used when Buxar town itself is inundated.',
          waypoints: ['Dumraon', 'Rajpur', 'Arrah'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Buxar Collectorate Camp',
          address: 'DM Office Campus, Buxar',
          lat: 25.5700,
          lng: 83.9800,
          capacity: 2000,
          phone: '06183-222333',
        ),
        EvacuationShelter(
          name: 'Dumraon Raj Palace Camp',
          address: 'Near Dumraon Palace, Dumraon',
          lat: 25.5500,
          lng: 84.1500,
          capacity: 1000,
          phone: '06183-222500',
        ),
      ],
    ),

    // ----------------------------------------------------------------- ROHTAS
    DistrictEvacuationInfo(
      district: 'Rohtas',
      division: 'Patna',
      lat: 24.9500,
      lng: 84.0500,
      controlRoomPhone: '06184-222222',
      dmPhone: '06184-222100',
      floodRisk: 'MEDIUM',
      routes: [
        EvacuationRoute(
          id: 'RHT-R1',
          from: 'Bikramganj (Son Bank)',
          to: 'Sasaram Town',
          highway: 'NH-2 (GT Road)',
          distanceKm: 25.0,
          description: 'North on NH-2 to Sasaram. Son river flooding affects Bikramganj, Nokha, Dinara.',
          waypoints: ['Bikramganj', 'Nokha', 'Sasaram'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'RHT-R2',
          from: 'Dehri-on-Son',
          to: 'Aurangabad via SH-7',
          highway: 'SH-7',
          distanceKm: 50.0,
          description: 'South-west via SH-7 to Aurangabad as alternate safe zone.',
          waypoints: ['Dehri', 'Obra', 'Aurangabad'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Sasaram Medical College Camp',
          address: 'Govt Medical College, Sasaram',
          lat: 24.9478,
          lng: 84.0320,
          capacity: 2000,
          phone: '06184-222400',
        ),
        EvacuationShelter(
          name: 'Rohtas District Stadium',
          address: 'District Stadium, Sasaram',
          lat: 24.9500,
          lng: 84.0400,
          capacity: 1500,
          phone: '06184-222500',
        ),
      ],
    ),

    // --------------------------------------------------------------- KAIMUR
    DistrictEvacuationInfo(
      district: 'Kaimur',
      division: 'Patna',
      lat: 25.0485,
      lng: 83.6000,
      controlRoomPhone: '06189-222222',
      dmPhone: '06189-222100',
      floodRisk: 'MEDIUM',
      routes: [
        EvacuationRoute(
          id: 'KMR-R1',
          from: 'Mohania (Son-Karamnasa Bank)',
          to: 'Bhabua Town',
          highway: 'NH-2',
          distanceKm: 30.0,
          description: 'East on NH-2 to Bhabua. Karamnasa and Son confluence area floods during monsoon peaks.',
          waypoints: ['Mohania', 'Ramgarh', 'Bhabua'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'KMR-R2',
          from: 'Bhabua',
          to: 'Sasaram (Rohtas)',
          highway: 'NH-2',
          distanceKm: 55.0,
          description: 'East on NH-2 to Sasaram for extended high-ground refuge.',
          waypoints: ['Bhabua', 'Mohania', 'Sasaram'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Bhabua Collectorate Camp',
          address: 'DM Office, Bhabua',
          lat: 25.0500,
          lng: 83.6100,
          capacity: 1500,
          phone: '06189-222333',
        ),
        EvacuationShelter(
          name: 'Kaimur District School Camp',
          address: 'Zila School, Bhabua',
          lat: 25.0480,
          lng: 83.6080,
          capacity: 800,
          phone: '06189-222400',
        ),
      ],
    ),

    // --------------------------------------------------------------- GAYA
    DistrictEvacuationInfo(
      district: 'Gaya',
      division: 'Magadh',
      lat: 24.7970,
      lng: 84.9992,
      controlRoomPhone: '0631-2222333',
      dmPhone: '0631-2222100',
      floodRisk: 'MEDIUM',
      routes: [
        EvacuationRoute(
          id: 'GAY-R1',
          from: 'Bodhgaya (Falgu Bank)',
          to: 'Gaya City',
          highway: 'NH-82',
          distanceKm: 12.0,
          description: 'North on NH-82 to Gaya. Falgu river flooding affects Bodhgaya and Dobhi.',
          waypoints: ['Bodhgaya', 'Dobhi', 'Gaya'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'GAY-R2',
          from: 'Tekari (Morhar River)',
          to: 'Gaya via SH-2',
          highway: 'SH-2',
          distanceKm: 28.0,
          description: 'North-east via SH-2 to Gaya city as safe high ground.',
          waypoints: ['Tekari', 'Gurua', 'Gaya'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Gaya Medical College Camp',
          address: 'ANMMCH, Gaya',
          lat: 24.7970,
          lng: 85.0100,
          capacity: 2500,
          phone: '0631-2220001',
        ),
        EvacuationShelter(
          name: 'Magadh University Camp',
          address: 'Magadh University, Bodhgaya',
          lat: 24.7600,
          lng: 84.9900,
          capacity: 2000,
          phone: '0631-2200600',
        ),
      ],
    ),

    // ------------------------------------------------------------ AURANGABAD
    DistrictEvacuationInfo(
      district: 'Aurangabad',
      division: 'Magadh',
      lat: 24.7520,
      lng: 84.3740,
      controlRoomPhone: '06186-222222',
      dmPhone: '06186-222100',
      floodRisk: 'LOW',
      routes: [
        EvacuationRoute(
          id: 'AGB-R1',
          from: 'Rafiganj (Son Bank)',
          to: 'Aurangabad Town',
          highway: 'NH-2',
          distanceKm: 30.0,
          description: 'West on NH-2 to Aurangabad. Rafiganj block faces Son river flooding.',
          waypoints: ['Rafiganj', 'Obra', 'Aurangabad'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'AGB-R2',
          from: 'Aurangabad Town',
          to: 'Gaya via NH-82',
          highway: 'NH-82',
          distanceKm: 55.0,
          description: 'East to Gaya for extended safe ground during Son or Morhar flash floods.',
          waypoints: ['Aurangabad', 'Sherghati', 'Gaya'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Aurangabad Collectorate Camp',
          address: 'DM Office, Aurangabad',
          lat: 24.7520,
          lng: 84.3800,
          capacity: 1500,
          phone: '06186-222333',
        ),
        EvacuationShelter(
          name: 'Aurangabad District School',
          address: 'Zila School, Aurangabad',
          lat: 24.7500,
          lng: 84.3750,
          capacity: 800,
          phone: '06186-222500',
        ),
      ],
    ),

    // --------------------------------------------------------------- NAWADA
    DistrictEvacuationInfo(
      district: 'Nawada',
      division: 'Magadh',
      lat: 24.8872,
      lng: 85.5411,
      controlRoomPhone: '06324-222222',
      dmPhone: '06324-222100',
      floodRisk: 'LOW',
      routes: [
        EvacuationRoute(
          id: 'NWD-R1',
          from: 'Nawada Town (Sakri Bank)',
          to: 'Warisaliganj',
          highway: 'SH-78',
          distanceKm: 20.0,
          description: 'North on SH-78 to Warisaliganj. Sakri and Tilaiya streams flood during heavy monsoon.',
          waypoints: ['Nawada', 'Rajauli', 'Warisaliganj'],
          isFloodProne: false,
        ),
        EvacuationRoute(
          id: 'NWD-R2',
          from: 'Sirdala',
          to: 'Gaya via NH-82',
          highway: 'NH-82',
          distanceKm: 40.0,
          description: 'West to Gaya as extended safe refuge.',
          waypoints: ['Sirdala', 'Sherghati', 'Gaya'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Nawada Collectorate Camp',
          address: 'DM Office, Nawada',
          lat: 24.8900,
          lng: 85.5450,
          capacity: 1200,
          phone: '06324-222333',
        ),
        EvacuationShelter(
          name: 'Nawada District School Camp',
          address: 'Zila School, Nawada',
          lat: 24.8880,
          lng: 85.5430,
          capacity: 700,
          phone: '06324-222500',
        ),
      ],
    ),

    // --------------------------------------------------------------- ARWAL
    DistrictEvacuationInfo(
      district: 'Arwal',
      division: 'Magadh',
      lat: 25.2382,
      lng: 84.6818,
      controlRoomPhone: '06348-222222',
      dmPhone: '06348-222100',
      floodRisk: 'MEDIUM',
      routes: [
        EvacuationRoute(
          id: 'AWL-R1',
          from: 'Arwal Town (Son Bank)',
          to: 'Jehanabad Town',
          highway: 'SH-9',
          distanceKm: 30.0,
          description: 'North on SH-9 to Jehanabad. Son river backwater flooding affects Arwal and Kaler.',
          waypoints: ['Arwal', 'Kaler', 'Jehanabad'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'AWL-R2',
          from: 'Kurtha',
          to: 'Ara (Bhojpur)',
          highway: 'NH-30',
          distanceKm: 40.0,
          description: 'West on NH-30 to Ara as alternate safe ground.',
          waypoints: ['Kurtha', 'Koilwar', 'Ara'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Arwal Collectorate Camp',
          address: 'DM Office, Arwal',
          lat: 25.2400,
          lng: 84.6830,
          capacity: 1000,
          phone: '06348-222333',
        ),
        EvacuationShelter(
          name: 'Arwal High School Camp',
          address: 'Govt High School, Arwal',
          lat: 25.2380,
          lng: 84.6810,
          capacity: 600,
          phone: '06348-222400',
        ),
      ],
    ),

    // ----------------------------------------------------------- JEHANABAD
    DistrictEvacuationInfo(
      district: 'Jehanabad',
      division: 'Magadh',
      lat: 25.2167,
      lng: 84.9833,
      controlRoomPhone: '06114-222222',
      dmPhone: '06114-222100',
      floodRisk: 'MEDIUM',
      routes: [
        EvacuationRoute(
          id: 'JHB-R1',
          from: 'Jehanabad Town (Morhar Bank)',
          to: 'Patna via NH-110',
          highway: 'NH-110',
          distanceKm: 45.0,
          description: 'North on NH-110 to Patna. Morhar overflow is primary risk in Jehanabad and Hulasganj.',
          waypoints: ['Jehanabad', 'Makhdumpur', 'Patna'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'JHB-R2',
          from: 'Ghoshi',
          to: 'Gaya via SH-2',
          highway: 'SH-2',
          distanceKm: 35.0,
          description: 'South on SH-2 to Gaya as alternate high-ground refuge.',
          waypoints: ['Ghoshi', 'Arwal', 'Gaya'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Jehanabad Collectorate Camp',
          address: 'DM Office, Jehanabad',
          lat: 25.2200,
          lng: 84.9850,
          capacity: 1200,
          phone: '06114-222333',
        ),
        EvacuationShelter(
          name: 'Jehanabad Stadium Camp',
          address: 'District Stadium, Jehanabad',
          lat: 25.2180,
          lng: 84.9840,
          capacity: 800,
          phone: '06114-222500',
        ),
      ],
    ),

    // --------------------------------------------------------------- VAISHALI
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
        EvacuationRoute(
          id: 'VAI-R2',
          from: 'Mahua (Gandak Bank)',
          to: 'Patna via NH-19',
          highway: 'NH-19',
          distanceKm: 35.0,
          description: 'South on NH-19 across Mahatma Gandhi Setu to Patna.',
          waypoints: ['Mahua', 'Hajipur', 'Patna'],
          isFloodProne: false,
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
        EvacuationShelter(
          name: 'Vaishali District School Camp',
          address: 'Zila School, Hajipur',
          lat: 25.6960,
          lng: 85.2080,
          capacity: 1000,
          phone: '06224-222600',
        ),
      ],
    ),

    // ----------------------------------------------------------- MUZAFFARPUR
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

    // --------------------------------------------------------------- SITAMARHI
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
        EvacuationRoute(
          id: 'STM-R2',
          from: 'Sitamarhi Town',
          to: 'Muzaffarpur via NH-77',
          highway: 'NH-77',
          distanceKm: 65.0,
          description: 'South on NH-77 all the way to Muzaffarpur during extreme Bagmati flooding.',
          waypoints: ['Sitamarhi', 'Dholi', 'Muzaffarpur'],
          isFloodProne: false,
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
        EvacuationShelter(
          name: 'Sitamarhi Stadium Camp',
          address: 'District Stadium, Sitamarhi',
          lat: 26.5930,
          lng: 85.4880,
          capacity: 1000,
          phone: '06226-252444',
        ),
      ],
    ),

    // --------------------------------------------------------------- SHEOHAR
    DistrictEvacuationInfo(
      district: 'Sheohar',
      division: 'Tirhut',
      lat: 26.5190,
      lng: 85.2980,
      controlRoomPhone: '06228-222222',
      dmPhone: '06228-222100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'SHR-R1',
          from: 'Sheohar Town (Bagmati Bank)',
          to: 'Muzaffarpur via NH-77',
          highway: 'NH-77',
          distanceKm: 45.0,
          description: 'South on NH-77 to Muzaffarpur. Sheohar is among Bihar\'s smallest and most flood-prone districts.',
          waypoints: ['Sheohar', 'Pipra', 'Dholi', 'Muzaffarpur'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'SHR-R2',
          from: 'Purnahiya',
          to: 'Sitamarhi via SH-74',
          highway: 'SH-74',
          distanceKm: 22.0,
          description: 'East to Sitamarhi as alternate refuge when western roads are inundated.',
          waypoints: ['Purnahiya', 'Tariyani', 'Sitamarhi'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Sheohar Collectorate Camp',
          address: 'DM Office, Sheohar',
          lat: 26.5190,
          lng: 85.3000,
          capacity: 800,
          phone: '06228-222333',
        ),
        EvacuationShelter(
          name: 'Sheohar High School Camp',
          address: 'Govt High School, Sheohar',
          lat: 26.5200,
          lng: 85.2990,
          capacity: 500,
          phone: '06228-222400',
        ),
      ],
    ),

    // -------------------------------------------------- WEST CHAMPARAN (Bettiah)
    DistrictEvacuationInfo(
      district: 'West Champaran',
      division: 'Tirhut',
      lat: 27.0200,
      lng: 84.4020,
      controlRoomPhone: '06254-242000',
      dmPhone: '06254-242100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'WCP-R1',
          from: 'Bagaha (Gandak-Narayani Bank)',
          to: 'Bettiah Town',
          highway: 'NH-727',
          distanceKm: 40.0,
          description: 'South-east on NH-727 to Bettiah. Bagaha and Gaunaha blocks face severe Gandak flooding.',
          waypoints: ['Bagaha', 'Gaunaha', 'Narkatiaganj', 'Bettiah'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'WCP-R2',
          from: 'Ramnagar (Nepal Border)',
          to: 'Bettiah via SH-73',
          highway: 'SH-73',
          distanceKm: 55.0,
          description: 'South-east via SH-73. Ramnagar forests and Valmiki Tiger Reserve border face flash flood risk.',
          waypoints: ['Ramnagar', 'Chanpatia', 'Bettiah'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Bettiah Medical College Camp',
          address: 'GMCH, Bettiah',
          lat: 27.0250,
          lng: 84.4050,
          capacity: 2000,
          phone: '06254-242500',
        ),
        EvacuationShelter(
          name: 'Bettiah University Camp',
          address: 'PG College, Bettiah',
          lat: 27.0200,
          lng: 84.4000,
          capacity: 1500,
          phone: '06254-242600',
        ),
      ],
    ),

    // -------------------------------------------------- EAST CHAMPARAN (Motihari)
    DistrictEvacuationInfo(
      district: 'East Champaran',
      division: 'Tirhut',
      lat: 26.6500,
      lng: 84.9167,
      controlRoomPhone: '06252-242000',
      dmPhone: '06252-242100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'ECP-R1',
          from: 'Areraj (Burhi Gandak Bank)',
          to: 'Motihari Town',
          highway: 'NH-28',
          distanceKm: 25.0,
          description: 'South on NH-28 to Motihari. Areraj, Chiraiya and Dhaka blocks face severe Burhi Gandak flooding.',
          waypoints: ['Areraj', 'Chiraiya', 'Motihari'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'ECP-R2',
          from: 'Raxaul (Nepal Border)',
          to: 'Motihari via NH-28',
          highway: 'NH-28',
          distanceKm: 45.0,
          description: 'South on NH-28. Raxaul and Adapur border blocks flood when Nepal releases excess water.',
          waypoints: ['Raxaul', 'Adapur', 'Motihari'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Motihari Medical College Camp',
          address: 'GMCH, Motihari',
          lat: 26.6500,
          lng: 84.9200,
          capacity: 2000,
          phone: '06252-242500',
        ),
        EvacuationShelter(
          name: 'Motihari University Camp',
          address: 'TM Bhagalpur College, Motihari',
          lat: 26.6550,
          lng: 84.9180,
          capacity: 1500,
          phone: '06252-242600',
        ),
      ],
    ),

    // --------------------------------------------------------------- DARBHANGA
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

    // --------------------------------------------------------------- MADHUBANI
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
        EvacuationRoute(
          id: 'MDH-R2',
          from: 'Madhubani Town',
          to: 'Darbhanga via NH-57',
          highway: 'NH-57',
          distanceKm: 45.0,
          description: 'South-west to Darbhanga as alternate safe zone during extreme flooding.',
          waypoints: ['Madhubani', 'Benipatti', 'Darbhanga'],
          isFloodProne: false,
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
        EvacuationShelter(
          name: 'Madhubani Stadium Camp',
          address: 'District Stadium, Madhubani',
          lat: 26.3550,
          lng: 86.0780,
          capacity: 800,
          phone: '06276-222400',
        ),
      ],
    ),

    // --------------------------------------------------------------- SAMASTIPUR
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
        EvacuationRoute(
          id: 'SMS-R2',
          from: 'Dalsinghsarai (Bagmati)',
          to: 'Patna via NH-28',
          highway: 'NH-28',
          distanceKm: 70.0,
          description: 'South-west on NH-28 to Patna for large-scale displacement.',
          waypoints: ['Dalsinghsarai', 'Barauni', 'Patna'],
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
        EvacuationShelter(
          name: 'Samastipur Stadium Camp',
          address: 'District Stadium, Samastipur',
          lat: 25.8580,
          lng: 85.7850,
          capacity: 1000,
          phone: '06274-240100',
        ),
      ],
    ),

    // --------------------------------------------------------------- BEGUSARAI
    DistrictEvacuationInfo(
      district: 'Begusarai',
      division: 'Munger',
      lat: 25.4182,
      lng: 86.1272,
      controlRoomPhone: '06243-222222',
      dmPhone: '06243-222100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'BGS-R1',
          from: 'Teghra (Burhi Gandak)',
          to: 'Begusarai Town',
          highway: 'NH-28',
          distanceKm: 20.0,
          description: 'East on NH-28 to Begusarai. Teghra and Sahebpur Kamal face Burhi Gandak flooding.',
          waypoints: ['Teghra', 'Sahebpur Kamal', 'Begusarai'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'BGS-R2',
          from: 'Begusarai Town',
          to: 'Munger via NH-80',
          highway: 'NH-80',
          distanceKm: 45.0,
          description: 'South-east on NH-80 to Munger as alternate higher-ground refuge.',
          waypoints: ['Begusarai', 'Khagaria', 'Munger'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Begusarai Collectorate Camp',
          address: 'DM Office, Begusarai',
          lat: 25.4200,
          lng: 86.1300,
          capacity: 2000,
          phone: '06243-222333',
        ),
        EvacuationShelter(
          name: 'BNMU Camp, Begusarai',
          address: 'BN Mandal College, Begusarai',
          lat: 25.4190,
          lng: 86.1280,
          capacity: 1500,
          phone: '06243-222500',
        ),
      ],
    ),

    // --------------------------------------------------------------- KHAGARIA
    DistrictEvacuationInfo(
      district: 'Khagaria',
      division: 'Munger',
      lat: 25.5020,
      lng: 86.4720,
      controlRoomPhone: '06244-222222',
      dmPhone: '06244-222100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'KHG-R1',
          from: 'Mansi (Kosi-Kari Doab)',
          to: 'Khagaria Town',
          highway: 'NH-107',
          distanceKm: 18.0,
          description: 'South-west on NH-107 to Khagaria. Mansi and Alauli blocks face extreme Kosi flooding.',
          waypoints: ['Mansi', 'Alauli', 'Khagaria'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'KHG-R2',
          from: 'Khagaria Town',
          to: 'Munger via NH-80',
          highway: 'NH-80',
          distanceKm: 55.0,
          description: 'South on NH-80 to Munger hill zone for large-scale displacement.',
          waypoints: ['Khagaria', 'Begusarai', 'Munger'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Khagaria Collectorate Camp',
          address: 'DM Office, Khagaria',
          lat: 25.5040,
          lng: 86.4750,
          capacity: 1500,
          phone: '06244-222333',
        ),
        EvacuationShelter(
          name: 'Khagaria Stadium Camp',
          address: 'District Stadium, Khagaria',
          lat: 25.5020,
          lng: 86.4730,
          capacity: 1000,
          phone: '06244-222400',
        ),
      ],
    ),

    // --------------------------------------------------------------- MUNGER
    DistrictEvacuationInfo(
      district: 'Munger',
      division: 'Munger',
      lat: 25.3742,
      lng: 86.4733,
      controlRoomPhone: '06344-222222',
      dmPhone: '06344-222100',
      floodRisk: 'MEDIUM',
      routes: [
        EvacuationRoute(
          id: 'MNG-R1',
          from: 'Jamalpur (Ganga South Bank)',
          to: 'Munger Town',
          highway: 'NH-80',
          distanceKm: 12.0,
          description: 'West on NH-80 to Munger fort hillock area. Jamalpur and Tarapur face Ganga flooding.',
          waypoints: ['Jamalpur', 'Munger'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'MNG-R2',
          from: 'Munger Town',
          to: 'Bhagalpur via NH-80',
          highway: 'NH-80',
          distanceKm: 60.0,
          description: 'East on NH-80 to Bhagalpur during extreme Ganga flooding of Munger.',
          waypoints: ['Munger', 'Sultanganj', 'Bhagalpur'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Munger University Camp',
          address: 'Munger University Campus',
          lat: 25.3800,
          lng: 86.4800,
          capacity: 2000,
          phone: '06344-222333',
        ),
        EvacuationShelter(
          name: 'Munger Fort Higher Ground Camp',
          address: 'Near Munger Fort, Kasim Chowk',
          lat: 25.3742,
          lng: 86.4750,
          capacity: 1500,
          phone: '06344-222500',
        ),
      ],
    ),

    // --------------------------------------------------------------- LAKHISARAI
    DistrictEvacuationInfo(
      district: 'Lakhisarai',
      division: 'Munger',
      lat: 25.1600,
      lng: 86.0900,
      controlRoomPhone: '06346-222222',
      dmPhone: '06346-222100',
      floodRisk: 'MEDIUM',
      routes: [
        EvacuationRoute(
          id: 'LKS-R1',
          from: 'Lakhisarai Town (Kiul Bank)',
          to: 'Sheikhpura via NH-80',
          highway: 'NH-80',
          distanceKm: 22.0,
          description: 'West on NH-80 to Sheikhpura higher ground. Kiul river flooding is primary risk.',
          waypoints: ['Lakhisarai', 'Halsi', 'Sheikhpura'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'LKS-R2',
          from: 'Suryagarha',
          to: 'Munger via NH-80',
          highway: 'NH-80',
          distanceKm: 35.0,
          description: 'East on NH-80 to Munger hill zone.',
          waypoints: ['Suryagarha', 'Jamui', 'Munger'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Lakhisarai Collectorate Camp',
          address: 'DM Office, Lakhisarai',
          lat: 25.1620,
          lng: 86.0920,
          capacity: 1000,
          phone: '06346-222333',
        ),
        EvacuationShelter(
          name: 'Lakhisarai High School Camp',
          address: 'Govt High School, Lakhisarai',
          lat: 25.1600,
          lng: 86.0900,
          capacity: 600,
          phone: '06346-222400',
        ),
      ],
    ),

    // --------------------------------------------------------------- SHEIKHPURA
    DistrictEvacuationInfo(
      district: 'Sheikhpura',
      division: 'Munger',
      lat: 25.1400,
      lng: 85.8400,
      controlRoomPhone: '06341-222222',
      dmPhone: '06341-222100',
      floodRisk: 'LOW',
      routes: [
        EvacuationRoute(
          id: 'SKP-R1',
          from: 'Sheikhpura Town',
          to: 'Nalanda via NH-20',
          highway: 'NH-20',
          distanceKm: 30.0,
          description: 'West on NH-20 to Nalanda/Bihar Sharif. Sheikhpura faces seasonal inundation from Kiul.',
          waypoints: ['Sheikhpura', 'Barbigha', 'Bihar Sharif'],
          isFloodProne: false,
        ),
        EvacuationRoute(
          id: 'SKP-R2',
          from: 'Barbigha',
          to: 'Munger via NH-80',
          highway: 'NH-80',
          distanceKm: 40.0,
          description: 'East on NH-80 to Munger as alternate safe zone.',
          waypoints: ['Barbigha', 'Lakhisarai', 'Munger'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Sheikhpura Collectorate Camp',
          address: 'DM Office, Sheikhpura',
          lat: 25.1420,
          lng: 85.8420,
          capacity: 800,
          phone: '06341-222333',
        ),
        EvacuationShelter(
          name: 'Sheikhpura School Camp',
          address: 'Govt School, Sheikhpura',
          lat: 25.1400,
          lng: 85.8400,
          capacity: 500,
          phone: '06341-222400',
        ),
      ],
    ),

    // --------------------------------------------------------------- JAMUI
    DistrictEvacuationInfo(
      district: 'Jamui',
      division: 'Munger',
      lat: 24.9282,
      lng: 86.2248,
      controlRoomPhone: '06345-222222',
      dmPhone: '06345-222100',
      floodRisk: 'LOW',
      routes: [
        EvacuationRoute(
          id: 'JMU-R1',
          from: 'Jhajha (Kiul Bank)',
          to: 'Jamui Town',
          highway: 'NH-80',
          distanceKm: 25.0,
          description: 'North on NH-80 to Jamui. Jhajha and Sono blocks face Kiul river flooding.',
          waypoints: ['Jhajha', 'Sono', 'Jamui'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'JMU-R2',
          from: 'Jamui Town',
          to: 'Nawada via SH-78',
          highway: 'SH-78',
          distanceKm: 40.0,
          description: 'West to Nawada on SH-78 as alternate route.',
          waypoints: ['Jamui', 'Sikandra', 'Nawada'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Jamui Collectorate Camp',
          address: 'DM Office, Jamui',
          lat: 24.9300,
          lng: 86.2270,
          capacity: 1000,
          phone: '06345-222333',
        ),
        EvacuationShelter(
          name: 'Jamui Stadium Camp',
          address: 'District Stadium, Jamui',
          lat: 24.9280,
          lng: 86.2250,
          capacity: 700,
          phone: '06345-222400',
        ),
      ],
    ),

    // --------------------------------------------------------------- BHAGALPUR
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
        EvacuationRoute(
          id: 'BHG-R2',
          from: 'Kahalgaon (Ganga Bank)',
          to: 'Bhagalpur via NH-80',
          highway: 'NH-80',
          distanceKm: 38.0,
          description: 'West on NH-80 to Bhagalpur. Kahalgaon power plant area faces Ganga spill flooding.',
          waypoints: ['Kahalgaon', 'Sultanganj', 'Bhagalpur'],
          isFloodProne: false,
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
        EvacuationShelter(
          name: 'Bhagalpur Medical College Camp',
          address: 'JLNMCH, Bhagalpur',
          lat: 25.2450,
          lng: 86.9880,
          capacity: 1500,
          phone: '0641-2400800',
        ),
      ],
    ),

    // --------------------------------------------------------------- BANKA
    DistrictEvacuationInfo(
      district: 'Banka',
      division: 'Bhagalpur',
      lat: 24.8800,
      lng: 86.9200,
      controlRoomPhone: '06424-222222',
      dmPhone: '06424-222100',
      floodRisk: 'MEDIUM',
      routes: [
        EvacuationRoute(
          id: 'BNK-R1',
          from: 'Amarpur (Chandan Bank)',
          to: 'Banka Town',
          highway: 'SH-91',
          distanceKm: 25.0,
          description: 'North on SH-91. Chandan river floods Amarpur and Katoria blocks frequently.',
          waypoints: ['Amarpur', 'Katoria', 'Banka'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'BNK-R2',
          from: 'Banka Town',
          to: 'Bhagalpur via SH-91',
          highway: 'SH-91',
          distanceKm: 45.0,
          description: 'North on SH-91 to Bhagalpur for major displacement.',
          waypoints: ['Banka', 'Sultanganj', 'Bhagalpur'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Banka Collectorate Camp',
          address: 'DM Office, Banka',
          lat: 24.8820,
          lng: 86.9220,
          capacity: 1000,
          phone: '06424-222333',
        ),
        EvacuationShelter(
          name: 'Banka College Camp',
          address: 'SP College, Banka',
          lat: 24.8800,
          lng: 86.9200,
          capacity: 700,
          phone: '06424-222400',
        ),
      ],
    ),

    // --------------------------------------------------------------- SUPAUL
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
        EvacuationRoute(
          id: 'SUP-R2',
          from: 'Supaul Town',
          to: 'Saharsa via NH-107',
          highway: 'NH-107',
          distanceKm: 40.0,
          description: 'South on NH-107 to Saharsa as alternate refuge.',
          waypoints: ['Supaul', 'Nirmali', 'Saharsa'],
          isFloodProne: false,
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
        EvacuationShelter(
          name: 'Supaul Stadium Camp',
          address: 'District Stadium, Supaul',
          lat: 26.1180,
          lng: 86.6030,
          capacity: 800,
          phone: '06473-222600',
        ),
      ],
    ),

    // --------------------------------------------------------------- SAHARSA
    DistrictEvacuationInfo(
      district: 'Saharsa',
      division: 'Kosi',
      lat: 25.8784,
      lng: 86.5940,
      controlRoomPhone: '06478-222222',
      dmPhone: '06478-222100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'SHS-R1',
          from: 'Salkhua (Kosi East)',
          to: 'Saharsa Town',
          highway: 'NH-107',
          distanceKm: 22.0,
          description: 'West on NH-107 to Saharsa. Salkhua and Simri Bakhtiarpur face extreme Kosi inundation.',
          waypoints: ['Salkhua', 'Simri Bakhtiarpur', 'Saharsa'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'SHS-R2',
          from: 'Saharsa Town',
          to: 'Madhepura via NH-107',
          highway: 'NH-107',
          distanceKm: 30.0,
          description: 'East on NH-107 to Madhepura as alternate safe zone.',
          waypoints: ['Saharsa', 'Sonbarsha', 'Madhepura'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Saharsa Collectorate Camp',
          address: 'DM Office, Saharsa',
          lat: 25.8800,
          lng: 86.5960,
          capacity: 1500,
          phone: '06478-222333',
        ),
        EvacuationShelter(
          name: 'Saharsa Medical Camp',
          address: 'Sadar Hospital, Saharsa',
          lat: 25.8784,
          lng: 86.5940,
          capacity: 1000,
          phone: '06478-222500',
        ),
      ],
    ),

    // --------------------------------------------------------------- MADHEPURA
    DistrictEvacuationInfo(
      district: 'Madhepura',
      division: 'Kosi',
      lat: 25.9216,
      lng: 86.7925,
      controlRoomPhone: '06476-222222',
      dmPhone: '06476-222100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'MDP-R1',
          from: 'Murliganj (Kosi West Bank)',
          to: 'Madhepura Town',
          highway: 'NH-107',
          distanceKm: 25.0,
          description: 'West on NH-107 to Madhepura. Murliganj and Gwalpara blocks flood heavily from Kosi.',
          waypoints: ['Murliganj', 'Gwalpara', 'Madhepura'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'MDP-R2',
          from: 'Madhepura Town',
          to: 'Supaul via NH-107',
          highway: 'NH-107',
          distanceKm: 40.0,
          description: 'North-west on NH-107 to Supaul for large-scale Kosi displacement.',
          waypoints: ['Madhepura', 'Nirmali', 'Supaul'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Madhepura Collectorate Camp',
          address: 'DM Office, Madhepura',
          lat: 25.9230,
          lng: 86.7940,
          capacity: 1500,
          phone: '06476-222333',
        ),
        EvacuationShelter(
          name: 'BNMU Madhepura Camp',
          address: 'BN Mandal University, Madhepura',
          lat: 25.9220,
          lng: 86.7930,
          capacity: 2000,
          phone: '06476-222500',
        ),
      ],
    ),

    // --------------------------------------------------------------- ARARIA
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
        EvacuationRoute(
          id: 'ARA-R2',
          from: 'Araria Town',
          to: 'Purnea via NH-57',
          highway: 'NH-57',
          distanceKm: 55.0,
          description: 'South on NH-57 to Purnea as alternate safe zone.',
          waypoints: ['Araria', 'Forbesganj', 'Purnea'],
          isFloodProne: false,
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
        EvacuationShelter(
          name: 'Araria Stadium Camp',
          address: 'District Stadium, Araria',
          lat: 26.1480,
          lng: 87.4790,
          capacity: 800,
          phone: '06453-222400',
        ),
      ],
    ),

    // --------------------------------------------------------------- KISHANGANJ
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
        EvacuationRoute(
          id: 'KSG-R2',
          from: 'Kishanganj Town',
          to: 'Purnea via NH-31',
          highway: 'NH-31',
          distanceKm: 55.0,
          description: 'South-west on NH-31 to Purnea as alternate safe zone.',
          waypoints: ['Kishanganj', 'Araria', 'Purnea'],
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
        EvacuationShelter(
          name: 'Kishanganj College Camp',
          address: 'Govt College, Kishanganj',
          lat: 26.0950,
          lng: 87.9450,
          capacity: 800,
          phone: '06456-220600',
        ),
      ],
    ),

    // --------------------------------------------------------------- PURNEA
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
        EvacuationRoute(
          id: 'PUR-R2',
          from: 'Rupauli (Saura Bank)',
          to: 'Purnea via SH-57',
          highway: 'SH-57',
          distanceKm: 35.0,
          description: 'South-west on SH-57. Rupauli and Baisi face Saura and Kosi spill flooding.',
          waypoints: ['Rupauli', 'Baisi', 'Purnea'],
          isFloodProne: true,
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
        EvacuationShelter(
          name: 'Purnea Medical College Camp',
          address: 'GMCH, Purnea',
          lat: 25.7790,
          lng: 87.4780,
          capacity: 1500,
          phone: '06454-221200',
        ),
      ],
    ),

    // --------------------------------------------------------------- KATIHAR
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
        EvacuationRoute(
          id: 'KTH-R2',
          from: 'Katihar Town',
          to: 'Purnea via NH-31',
          highway: 'NH-31',
          distanceKm: 50.0,
          description: 'West on NH-31 to Purnea as extended safe zone.',
          waypoints: ['Katihar', 'Manihair', 'Purnea'],
          isFloodProne: false,
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
        EvacuationShelter(
          name: 'Katihar Stadium Camp',
          address: 'District Stadium, Katihar',
          lat: 25.5380,
          lng: 87.5750,
          capacity: 1200,
          phone: '06452-245200',
        ),
      ],
    ),

    // --------------------------------------------------------------- SARAN (Chhapra)
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
        EvacuationRoute(
          id: 'SAR-R2',
          from: 'Sonepur (Ganga-Gandak)',
          to: 'Patna via NH-19',
          highway: 'NH-19',
          distanceKm: 25.0,
          description: 'East across the Ganga-Gandak confluence to Patna during extreme flooding.',
          waypoints: ['Sonepur', 'Hajipur', 'Patna'],
          isFloodProne: false,
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
        EvacuationShelter(
          name: 'Chhapra Stadium Camp',
          address: 'District Stadium, Chhapra',
          lat: 25.7820,
          lng: 84.7320,
          capacity: 1500,
          phone: '06162-242100',
        ),
      ],
    ),

    // --------------------------------------------------------------- SIWAN
    DistrictEvacuationInfo(
      district: 'Siwan',
      division: 'Saran',
      lat: 26.2196,
      lng: 84.3563,
      controlRoomPhone: '06154-242222',
      dmPhone: '06154-242100',
      floodRisk: 'HIGH',
      routes: [
        EvacuationRoute(
          id: 'SWN-R1',
          from: 'Maharajganj (Gandak Bank)',
          to: 'Siwan Town',
          highway: 'NH-727A',
          distanceKm: 30.0,
          description: 'South-east on NH-727A to Siwan town. Maharajganj and Guthni blocks flood severely from Gandak.',
          waypoints: ['Maharajganj', 'Guthni', 'Siwan'],
          isFloodProne: true,
        ),
        EvacuationRoute(
          id: 'SWN-R2',
          from: 'Siwan Town',
          to: 'Chhapra via NH-19',
          highway: 'NH-19',
          distanceKm: 45.0,
          description: 'East on NH-19 to Chhapra for major displacement events.',
          waypoints: ['Siwan', 'Masrakh', 'Chhapra'],
          isFloodProne: false,
        ),
      ],
      shelters: [
        EvacuationShelter(
          name: 'Siwan Collectorate Camp',
          address: 'DM Office, Siwan',
          lat: 26.2200,
          lng: 84.3580,
          capacity: 1500,
          phone: '06154-242333',
        ),
        EvacuationShelter(
          name: 'Siwan Stadium Camp',
          address: 'District Stadium, Siwan',
          lat: 26.2180,
          lng: 84.3560,
          capacity: 1000,
          phone: '06154-242400',
        ),
      ],
    ),

    // --------------------------------------------------------------- GOPALGANJ
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
        EvacuationRoute(
          id: 'GPL-R2',
          from: 'Gopalganj Town',
          to: 'Muzaffarpur via NH-28',
          highway: 'NH-28',
          distanceKm: 65.0,
          description: 'East on NH-28 to Muzaffarpur as alternate large-scale refuge.',
          waypoints: ['Gopalganj', 'Bettiah', 'Muzaffarpur'],
          isFloodProne: false,
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
        EvacuationShelter(
          name: 'Gopalganj Stadium Camp',
          address: 'District Stadium, Gopalganj',
          lat: 26.4680,
          lng: 84.4380,
          capacity: 1200,
          phone: '06150-222400',
        ),
      ],
    ),

    // --------------------------------------------------------------- DARBHANGA (already covered above)
    // --------------------------------------------------------------- SAMASTIPUR (already covered above)

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

  static int get totalShelterCapacity =>
      districts.fold(0, (sum, d) => sum + d.shelters.fold(0, (s, sh) => s + sh.capacity));

  static int get highRiskCount =>
      districts.where((d) => d.floodRisk == 'HIGH').length;
}
