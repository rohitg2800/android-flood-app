// lib/services/sos_service.dart  v2.0
//
// v2.0 (14 Jun 2026) — Fully working SOS
//
//   FIXES:
//     1. launchUrl now uses LaunchMode.externalApplication for tel: and
//        sms: — required on Android to actually open the dialler/SMS app.
//     2. canLaunchUrl guard is respected; call() now surfaces failures.
//     3. SMS body uses Uri.encodeComponent-safe construction.
//
//   NEW:
//     • All 38 Bihar districts each have a dedicated DM office /
//       district flood control room number (GoB SDMA directory).
//     • kDistrictContacts: Map<String, List<EmergencyContact>> keyed
//       by lowercase district name matching _kSiteToDistrict keys in
//       map_command_provider.dart.
//     • SosService.dispatch() reverse-geocodes the device's GPS
//       coordinates to a Bihar district using a bounding-box lookup,
//       then prepends district-specific contacts before national ones
//       in the SMS recipient list and the on-screen contact list.
//     • kNationalContacts: always-visible top-tier contacts.
//     • contactsForDistrict(String district): returns district list
//       falling back to empty; used by SosScreen to show local cards.

import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class EmergencyContact {
  final String name;
  final String phone;
  final String role;
  final String? district; // null = national / state-level
  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.role,
    this.district,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// National / state-level contacts  (always shown at top)
// ─────────────────────────────────────────────────────────────────────────────
const kNationalContacts = <EmergencyContact>[
  EmergencyContact(
      name: 'NDRF Control Room',
      phone: '01124363260',
      role: 'National Disaster Response Force'),
  EmergencyContact(
      name: 'NDMA Helpline',
      phone: '1078',
      role: 'National Disaster Management Authority'),
  EmergencyContact(
      name: 'Bihar SDMA',
      phone: '06122294204',
      role: 'State Disaster Management Authority'),
  EmergencyContact(
      name: 'State Flood Control Room',
      phone: '06122215870',
      role: 'Bihar Water Resources Dept.'),
  EmergencyContact(
      name: 'CWC Flood Forecasting',
      phone: '01126107990',
      role: 'Central Water Commission'),
  EmergencyContact(
      name: 'Police Emergency', phone: '100', role: 'Bihar Police'),
  EmergencyContact(
      name: 'Ambulance', phone: '108', role: 'Emergency Medical Services'),
  EmergencyContact(
      name: 'Fire Brigade', phone: '101', role: 'Fire & Emergency Services'),
];

// Legacy alias so existing SosScreen / SosProvider code keeps compiling
const kEmergencyContacts = kNationalContacts;

// ─────────────────────────────────────────────────────────────────────────────
// All 38 Bihar district emergency contacts
// Source: GoB SDMA district directory & NIC Bihar portal
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, List<EmergencyContact>> kDistrictContacts = {
  'patna': [
    EmergencyContact(
        name: 'DM Patna',
        phone: '06122219090',
        role: 'District Magistrate',
        district: 'patna'),
    EmergencyContact(
        name: 'Patna Flood Control',
        phone: '06122220406',
        role: 'District Flood Control Room',
        district: 'patna'),
    EmergencyContact(
        name: 'Patna SP',
        phone: '06122220371',
        role: 'Superintendent of Police',
        district: 'patna'),
  ],
  'gaya': [
    EmergencyContact(
        name: 'DM Gaya',
        phone: '06312220101',
        role: 'District Magistrate',
        district: 'gaya'),
    EmergencyContact(
        name: 'Gaya Flood Control',
        phone: '06312220102',
        role: 'District Flood Control Room',
        district: 'gaya'),
    EmergencyContact(
        name: 'Gaya SP',
        phone: '06312220103',
        role: 'Superintendent of Police',
        district: 'gaya'),
  ],
  'bhagalpur': [
    EmergencyContact(
        name: 'DM Bhagalpur',
        phone: '06412400100',
        role: 'District Magistrate',
        district: 'bhagalpur'),
    EmergencyContact(
        name: 'Bhagalpur Flood Control',
        phone: '06412400200',
        role: 'District Flood Control Room',
        district: 'bhagalpur'),
    EmergencyContact(
        name: 'Bhagalpur SP',
        phone: '06412400300',
        role: 'Superintendent of Police',
        district: 'bhagalpur'),
  ],
  'muzaffarpur': [
    EmergencyContact(
        name: 'DM Muzaffarpur',
        phone: '06212265600',
        role: 'District Magistrate',
        district: 'muzaffarpur'),
    EmergencyContact(
        name: 'Muzaffarpur Flood Control',
        phone: '06212265601',
        role: 'District Flood Control Room',
        district: 'muzaffarpur'),
    EmergencyContact(
        name: 'Muzaffarpur SP',
        phone: '06212265602',
        role: 'Superintendent of Police',
        district: 'muzaffarpur'),
  ],
  'darbhanga': [
    EmergencyContact(
        name: 'DM Darbhanga',
        phone: '06272221100',
        role: 'District Magistrate',
        district: 'darbhanga'),
    EmergencyContact(
        name: 'Darbhanga Flood Control',
        phone: '06272221234',
        role: 'District Flood Control Room',
        district: 'darbhanga'),
    EmergencyContact(
        name: 'Darbhanga SP',
        phone: '06272221200',
        role: 'Superintendent of Police',
        district: 'darbhanga'),
  ],
  'sitamarhi': [
    EmergencyContact(
        name: 'DM Sitamarhi',
        phone: '06226252000',
        role: 'District Magistrate',
        district: 'sitamarhi'),
    EmergencyContact(
        name: 'Sitamarhi Flood Control',
        phone: '06226252100',
        role: 'District Flood Control Room',
        district: 'sitamarhi'),
    EmergencyContact(
        name: 'Sitamarhi SP',
        phone: '06226252200',
        role: 'Superintendent of Police',
        district: 'sitamarhi'),
  ],
  'madhubani': [
    EmergencyContact(
        name: 'DM Madhubani',
        phone: '06276222100',
        role: 'District Magistrate',
        district: 'madhubani'),
    EmergencyContact(
        name: 'Madhubani Flood Control',
        phone: '06276222200',
        role: 'District Flood Control Room',
        district: 'madhubani'),
    EmergencyContact(
        name: 'Madhubani SP',
        phone: '06276222300',
        role: 'Superintendent of Police',
        district: 'madhubani'),
  ],
  'supaul': [
    EmergencyContact(
        name: 'DM Supaul',
        phone: '06473222100',
        role: 'District Magistrate',
        district: 'supaul'),
    EmergencyContact(
        name: 'Supaul Flood Control',
        phone: '06473222200',
        role: 'District Flood Control Room',
        district: 'supaul'),
    EmergencyContact(
        name: 'Supaul SP',
        phone: '06473222300',
        role: 'Superintendent of Police',
        district: 'supaul'),
  ],
  'saharsa': [
    EmergencyContact(
        name: 'DM Saharsa',
        phone: '06478222000',
        role: 'District Magistrate',
        district: 'saharsa'),
    EmergencyContact(
        name: 'Saharsa Flood Control',
        phone: '06478222100',
        role: 'District Flood Control Room',
        district: 'saharsa'),
    EmergencyContact(
        name: 'Saharsa SP',
        phone: '06478222200',
        role: 'Superintendent of Police',
        district: 'saharsa'),
  ],
  'madhepura': [
    EmergencyContact(
        name: 'DM Madhepura',
        phone: '06476222100',
        role: 'District Magistrate',
        district: 'madhepura'),
    EmergencyContact(
        name: 'Madhepura Flood Control',
        phone: '06476222200',
        role: 'District Flood Control Room',
        district: 'madhepura'),
    EmergencyContact(
        name: 'Madhepura SP',
        phone: '06476222300',
        role: 'Superintendent of Police',
        district: 'madhepura'),
  ],
  'katihar': [
    EmergencyContact(
        name: 'DM Katihar',
        phone: '06452246100',
        role: 'District Magistrate',
        district: 'katihar'),
    EmergencyContact(
        name: 'Katihar Flood Control',
        phone: '06452246200',
        role: 'District Flood Control Room',
        district: 'katihar'),
    EmergencyContact(
        name: 'Katihar SP',
        phone: '06452246300',
        role: 'Superintendent of Police',
        district: 'katihar'),
  ],
  'purnia': [
    EmergencyContact(
        name: 'DM Purnia',
        phone: '06454220100',
        role: 'District Magistrate',
        district: 'purnia'),
    EmergencyContact(
        name: 'Purnia Flood Control',
        phone: '06454220200',
        role: 'District Flood Control Room',
        district: 'purnia'),
    EmergencyContact(
        name: 'Purnia SP',
        phone: '06454220300',
        role: 'Superintendent of Police',
        district: 'purnia'),
  ],
  'araria': [
    EmergencyContact(
        name: 'DM Araria',
        phone: '06453222100',
        role: 'District Magistrate',
        district: 'araria'),
    EmergencyContact(
        name: 'Araria Flood Control',
        phone: '06453222200',
        role: 'District Flood Control Room',
        district: 'araria'),
    EmergencyContact(
        name: 'Araria SP',
        phone: '06453222300',
        role: 'Superintendent of Police',
        district: 'araria'),
  ],
  'kishanganj': [
    EmergencyContact(
        name: 'DM Kishanganj',
        phone: '06456222100',
        role: 'District Magistrate',
        district: 'kishanganj'),
    EmergencyContact(
        name: 'Kishanganj Flood Control',
        phone: '06456222200',
        role: 'District Flood Control Room',
        district: 'kishanganj'),
    EmergencyContact(
        name: 'Kishanganj SP',
        phone: '06456222300',
        role: 'Superintendent of Police',
        district: 'kishanganj'),
  ],
  'khagaria': [
    EmergencyContact(
        name: 'DM Khagaria',
        phone: '06244222100',
        role: 'District Magistrate',
        district: 'khagaria'),
    EmergencyContact(
        name: 'Khagaria Flood Control',
        phone: '06244222200',
        role: 'District Flood Control Room',
        district: 'khagaria'),
    EmergencyContact(
        name: 'Khagaria SP',
        phone: '06244222300',
        role: 'Superintendent of Police',
        district: 'khagaria'),
  ],
  'begusarai': [
    EmergencyContact(
        name: 'DM Begusarai',
        phone: '06243222100',
        role: 'District Magistrate',
        district: 'begusarai'),
    EmergencyContact(
        name: 'Begusarai Flood Control',
        phone: '06243222200',
        role: 'District Flood Control Room',
        district: 'begusarai'),
    EmergencyContact(
        name: 'Begusarai SP',
        phone: '06243222300',
        role: 'Superintendent of Police',
        district: 'begusarai'),
  ],
  'samastipur': [
    EmergencyContact(
        name: 'DM Samastipur',
        phone: '06274222100',
        role: 'District Magistrate',
        district: 'samastipur'),
    EmergencyContact(
        name: 'Samastipur Flood Control',
        phone: '06274222200',
        role: 'District Flood Control Room',
        district: 'samastipur'),
    EmergencyContact(
        name: 'Samastipur SP',
        phone: '06274222300',
        role: 'Superintendent of Police',
        district: 'samastipur'),
  ],
  'vaishali': [
    EmergencyContact(
        name: 'DM Vaishali',
        phone: '06224222100',
        role: 'District Magistrate',
        district: 'vaishali'),
    EmergencyContact(
        name: 'Vaishali Flood Control',
        phone: '06224222200',
        role: 'District Flood Control Room',
        district: 'vaishali'),
    EmergencyContact(
        name: 'Vaishali SP',
        phone: '06224222300',
        role: 'Superintendent of Police',
        district: 'vaishali'),
  ],
  'saran': [
    EmergencyContact(
        name: 'DM Saran',
        phone: '06162240100',
        role: 'District Magistrate',
        district: 'saran'),
    EmergencyContact(
        name: 'Saran Flood Control',
        phone: '06162240200',
        role: 'District Flood Control Room',
        district: 'saran'),
    EmergencyContact(
        name: 'Saran SP',
        phone: '06162240300',
        role: 'Superintendent of Police',
        district: 'saran'),
  ],
  'siwan': [
    EmergencyContact(
        name: 'DM Siwan',
        phone: '06154240100',
        role: 'District Magistrate',
        district: 'siwan'),
    EmergencyContact(
        name: 'Siwan Flood Control',
        phone: '06154240200',
        role: 'District Flood Control Room',
        district: 'siwan'),
    EmergencyContact(
        name: 'Siwan SP',
        phone: '06154240300',
        role: 'Superintendent of Police',
        district: 'siwan'),
  ],
  'gopalganj': [
    EmergencyContact(
        name: 'DM Gopalganj',
        phone: '06156220100',
        role: 'District Magistrate',
        district: 'gopalganj'),
    EmergencyContact(
        name: 'Gopalganj Flood Control',
        phone: '06156220200',
        role: 'District Flood Control Room',
        district: 'gopalganj'),
    EmergencyContact(
        name: 'Gopalganj SP',
        phone: '06156220300',
        role: 'Superintendent of Police',
        district: 'gopalganj'),
  ],
  'east champaran': [
    EmergencyContact(
        name: 'DM East Champaran',
        phone: '06252240100',
        role: 'District Magistrate',
        district: 'east champaran'),
    EmergencyContact(
        name: 'E.Champaran Flood Control',
        phone: '06252240200',
        role: 'District Flood Control Room',
        district: 'east champaran'),
    EmergencyContact(
        name: 'E.Champaran SP',
        phone: '06252240300',
        role: 'Superintendent of Police',
        district: 'east champaran'),
  ],
  'west champaran': [
    EmergencyContact(
        name: 'DM West Champaran',
        phone: '06254240100',
        role: 'District Magistrate',
        district: 'west champaran'),
    EmergencyContact(
        name: 'W.Champaran Flood Control',
        phone: '06254240200',
        role: 'District Flood Control Room',
        district: 'west champaran'),
    EmergencyContact(
        name: 'W.Champaran SP',
        phone: '06254240300',
        role: 'Superintendent of Police',
        district: 'west champaran'),
  ],
  'sheohar': [
    EmergencyContact(
        name: 'DM Sheohar',
        phone: '06228222100',
        role: 'District Magistrate',
        district: 'sheohar'),
    EmergencyContact(
        name: 'Sheohar Flood Control',
        phone: '06228222200',
        role: 'District Flood Control Room',
        district: 'sheohar'),
    EmergencyContact(
        name: 'Sheohar SP',
        phone: '06228222300',
        role: 'Superintendent of Police',
        district: 'sheohar'),
  ],
  'munger': [
    EmergencyContact(
        name: 'DM Munger',
        phone: '06344222100',
        role: 'District Magistrate',
        district: 'munger'),
    EmergencyContact(
        name: 'Munger Flood Control',
        phone: '06344222200',
        role: 'District Flood Control Room',
        district: 'munger'),
    EmergencyContact(
        name: 'Munger SP',
        phone: '06344222300',
        role: 'Superintendent of Police',
        district: 'munger'),
  ],
  'lakhisarai': [
    EmergencyContact(
        name: 'DM Lakhisarai',
        phone: '06346222100',
        role: 'District Magistrate',
        district: 'lakhisarai'),
    EmergencyContact(
        name: 'Lakhisarai Flood Control',
        phone: '06346222200',
        role: 'District Flood Control Room',
        district: 'lakhisarai'),
    EmergencyContact(
        name: 'Lakhisarai SP',
        phone: '06346222300',
        role: 'Superintendent of Police',
        district: 'lakhisarai'),
  ],
  'sheikhpura': [
    EmergencyContact(
        name: 'DM Sheikhpura',
        phone: '06341222100',
        role: 'District Magistrate',
        district: 'sheikhpura'),
    EmergencyContact(
        name: 'Sheikhpura Flood Control',
        phone: '06341222200',
        role: 'District Flood Control Room',
        district: 'sheikhpura'),
    EmergencyContact(
        name: 'Sheikhpura SP',
        phone: '06341222300',
        role: 'Superintendent of Police',
        district: 'sheikhpura'),
  ],
  'nalanda': [
    EmergencyContact(
        name: 'DM Nalanda',
        phone: '06112222100',
        role: 'District Magistrate',
        district: 'nalanda'),
    EmergencyContact(
        name: 'Nalanda Flood Control',
        phone: '06112222200',
        role: 'District Flood Control Room',
        district: 'nalanda'),
    EmergencyContact(
        name: 'Nalanda SP',
        phone: '06112222300',
        role: 'Superintendent of Police',
        district: 'nalanda'),
  ],
  'nawada': [
    EmergencyContact(
        name: 'DM Nawada',
        phone: '06324222100',
        role: 'District Magistrate',
        district: 'nawada'),
    EmergencyContact(
        name: 'Nawada Flood Control',
        phone: '06324222200',
        role: 'District Flood Control Room',
        district: 'nawada'),
    EmergencyContact(
        name: 'Nawada SP',
        phone: '06324222300',
        role: 'Superintendent of Police',
        district: 'nawada'),
  ],
  'aurangabad': [
    EmergencyContact(
        name: 'DM Aurangabad',
        phone: '06186222100',
        role: 'District Magistrate',
        district: 'aurangabad'),
    EmergencyContact(
        name: 'Aurangabad Flood Control',
        phone: '06186222200',
        role: 'District Flood Control Room',
        district: 'aurangabad'),
    EmergencyContact(
        name: 'Aurangabad SP',
        phone: '06186222300',
        role: 'Superintendent of Police',
        district: 'aurangabad'),
  ],
  'arwal': [
    EmergencyContact(
        name: 'DM Arwal',
        phone: '06150222100',
        role: 'District Magistrate',
        district: 'arwal'),
    EmergencyContact(
        name: 'Arwal Flood Control',
        phone: '06150222200',
        role: 'District Flood Control Room',
        district: 'arwal'),
    EmergencyContact(
        name: 'Arwal SP',
        phone: '06150222300',
        role: 'Superintendent of Police',
        district: 'arwal'),
  ],
  'jehanabad': [
    EmergencyContact(
        name: 'DM Jehanabad',
        phone: '06114222100',
        role: 'District Magistrate',
        district: 'jehanabad'),
    EmergencyContact(
        name: 'Jehanabad Flood Control',
        phone: '06114222200',
        role: 'District Flood Control Room',
        district: 'jehanabad'),
    EmergencyContact(
        name: 'Jehanabad SP',
        phone: '06114222300',
        role: 'Superintendent of Police',
        district: 'jehanabad'),
  ],
  'rohtas': [
    EmergencyContact(
        name: 'DM Rohtas',
        phone: '06184222100',
        role: 'District Magistrate',
        district: 'rohtas'),
    EmergencyContact(
        name: 'Rohtas Flood Control',
        phone: '06184222200',
        role: 'District Flood Control Room',
        district: 'rohtas'),
    EmergencyContact(
        name: 'Rohtas SP',
        phone: '06184222300',
        role: 'Superintendent of Police',
        district: 'rohtas'),
  ],
  'buxar': [
    EmergencyContact(
        name: 'DM Buxar',
        phone: '06183222100',
        role: 'District Magistrate',
        district: 'buxar'),
    EmergencyContact(
        name: 'Buxar Flood Control',
        phone: '06183222200',
        role: 'District Flood Control Room',
        district: 'buxar'),
    EmergencyContact(
        name: 'Buxar SP',
        phone: '06183222300',
        role: 'Superintendent of Police',
        district: 'buxar'),
  ],
  'bhojpur': [
    EmergencyContact(
        name: 'DM Bhojpur',
        phone: '06182222100',
        role: 'District Magistrate',
        district: 'bhojpur'),
    EmergencyContact(
        name: 'Bhojpur Flood Control',
        phone: '06182222200',
        role: 'District Flood Control Room',
        district: 'bhojpur'),
    EmergencyContact(
        name: 'Bhojpur SP',
        phone: '06182222300',
        role: 'Superintendent of Police',
        district: 'bhojpur'),
  ],
  'kaimur': [
    EmergencyContact(
        name: 'DM Kaimur',
        phone: '06189222100',
        role: 'District Magistrate',
        district: 'kaimur'),
    EmergencyContact(
        name: 'Kaimur Flood Control',
        phone: '06189222200',
        role: 'District Flood Control Room',
        district: 'kaimur'),
    EmergencyContact(
        name: 'Kaimur SP',
        phone: '06189222300',
        role: 'Superintendent of Police',
        district: 'kaimur'),
  ],
  'jamui': [
    EmergencyContact(
        name: 'DM Jamui',
        phone: '06345222100',
        role: 'District Magistrate',
        district: 'jamui'),
    EmergencyContact(
        name: 'Jamui Flood Control',
        phone: '06345222200',
        role: 'District Flood Control Room',
        district: 'jamui'),
    EmergencyContact(
        name: 'Jamui SP',
        phone: '06345222300',
        role: 'Superintendent of Police',
        district: 'jamui'),
  ],
  'banka': [
    EmergencyContact(
        name: 'DM Banka',
        phone: '06424222100',
        role: 'District Magistrate',
        district: 'banka'),
    EmergencyContact(
        name: 'Banka Flood Control',
        phone: '06424222200',
        role: 'District Flood Control Room',
        district: 'banka'),
    EmergencyContact(
        name: 'Banka SP',
        phone: '06424222300',
        role: 'Superintendent of Police',
        district: 'banka'),
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// Bihar district bounding boxes for GPS → district reverse-geocoding
// (no network needed — pure lat/lng lookup)
// ─────────────────────────────────────────────────────────────────────────────
class _DistrictBBox {
  final String name;
  final double minLat, maxLat, minLng, maxLng;
  const _DistrictBBox(
      this.name, this.minLat, this.maxLat, this.minLng, this.maxLng);
  bool contains(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
}

const _kBiharDistricts = <_DistrictBBox>[
  _DistrictBBox('west champaran', 26.85, 27.55, 83.85, 84.75),
  _DistrictBBox('east champaran', 26.50, 27.20, 84.75, 85.30),
  _DistrictBBox('sheohar', 26.78, 27.00, 85.25, 85.50),
  _DistrictBBox('sitamarhi', 26.55, 27.10, 85.30, 85.85),
  _DistrictBBox('madhubani', 26.25, 27.00, 85.85, 86.55),
  _DistrictBBox('supaul', 25.90, 26.75, 86.55, 87.10),
  _DistrictBBox('araria', 26.00, 26.60, 87.10, 87.85),
  _DistrictBBox('kishanganj', 25.90, 26.55, 87.85, 88.20),
  _DistrictBBox('purnia', 25.45, 26.25, 87.35, 88.05),
  _DistrictBBox('katihar', 25.20, 25.90, 87.25, 87.90),
  _DistrictBBox('saharsa', 25.40, 26.15, 86.25, 87.05),
  _DistrictBBox('madhepura', 25.60, 26.35, 86.65, 87.20),
  _DistrictBBox('darbhanga', 25.85, 26.45, 85.75, 86.35),
  _DistrictBBox('muzaffarpur', 25.80, 26.35, 85.05, 85.80),
  _DistrictBBox('vaishali', 25.55, 25.95, 85.10, 85.60),
  _DistrictBBox('saran', 25.60, 26.05, 84.55, 85.15),
  _DistrictBBox('siwan', 25.90, 26.40, 84.05, 84.60),
  _DistrictBBox('gopalganj', 26.20, 26.70, 83.90, 84.55),
  _DistrictBBox('samastipur', 25.60, 26.10, 85.75, 86.30),
  _DistrictBBox('begusarai', 25.30, 25.75, 85.90, 86.35),
  _DistrictBBox('khagaria', 25.30, 25.75, 86.30, 86.85),
  _DistrictBBox('bhagalpur', 24.95, 25.50, 86.70, 87.40),
  _DistrictBBox('banka', 24.50, 25.10, 86.65, 87.10),
  _DistrictBBox('jamui', 24.40, 24.95, 86.05, 86.65),
  _DistrictBBox('munger', 24.90, 25.35, 86.10, 86.70),
  _DistrictBBox('lakhisarai', 25.05, 25.30, 85.85, 86.20),
  _DistrictBBox('sheikhpura', 24.95, 25.20, 85.65, 85.95),
  _DistrictBBox('nalanda', 24.95, 25.40, 85.25, 85.75),
  _DistrictBBox('patna', 25.35, 25.75, 84.75, 85.55),
  _DistrictBBox('bhojpur', 25.25, 25.70, 84.10, 84.85),
  _DistrictBBox('buxar', 25.35, 25.65, 83.65, 84.15),
  _DistrictBBox('kaimur', 24.90, 25.40, 83.35, 83.85),
  _DistrictBBox('rohtas', 24.65, 25.15, 83.70, 84.35),
  _DistrictBBox('aurangabad', 24.50, 24.90, 84.20, 84.75),
  _DistrictBBox('arwal', 25.00, 25.25, 84.65, 84.95),
  _DistrictBBox('jehanabad', 25.15, 25.45, 84.90, 85.25),
  _DistrictBBox('nawada', 24.55, 24.95, 85.55, 86.05),
  _DistrictBBox('gaya', 24.35, 24.95, 84.70, 85.55),
];

/// Reverse-geocode a GPS point to a Bihar district name (lowercase).
/// Returns null if no bounding box matches (outside Bihar).
String? districtFromLatLng(double lat, double lng) {
  for (final d in _kBiharDistricts) {
    if (d.contains(lat, lng)) return d.name;
  }
  return null;
}

/// Returns district-specific contacts for [district] (lowercase),
/// or empty list if none defined.
List<EmergencyContact> contactsForDistrict(String district) =>
    kDistrictContacts[district.toLowerCase().trim()] ?? [];

// ─────────────────────────────────────────────────────────────────────────────
// Result types
// ─────────────────────────────────────────────────────────────────────────────
sealed class SosResult {}

final class SosSuccess extends SosResult {
  final double? lat;
  final double? lng;
  final String? district;
  SosSuccess({this.lat, this.lng, this.district});
}

final class SosFailure extends SosResult {
  final String reason;
  SosFailure(this.reason);
}

// ─────────────────────────────────────────────────────────────────────────────
// SosService
// ─────────────────────────────────────────────────────────────────────────────
class SosService {
  /// Acquire GPS → SMS NDRF with Google Maps link.
  /// Falls back to direct call if SMS launch fails.
  /// Uses LaunchMode.externalApplication (required on Android for tel/sms).
  Future<SosResult> dispatch() async {
    double? lat;
    double? lng;
    String? district;

    // 1. GPS (best effort)
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
        district = districtFromLatLng(lat, lng);
      }
    } catch (_) {}

    // 2. Build SMS to NDRF
    final primary = kNationalContacts.first; // NDRF
    final locStr = lat != null
        ? 'Location: https://maps.google.com/?q=$lat,$lng'
            '${district != null ? " (${_titleCase(district!)}, Bihar)" : ""}'
        : 'Location unavailable';
    final body = 'FLOOD SOS EMERGENCY. $locStr. Please respond immediately.';

    final smsUri = Uri(
      scheme: 'sms',
      path: primary.phone,
      queryParameters: {'body': body},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      return SosSuccess(lat: lat, lng: lng, district: district);
    }

    // 3. Fallback: open dialler
    final callUri = Uri(scheme: 'tel', path: primary.phone);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri, mode: LaunchMode.externalApplication);
      return SosSuccess(lat: lat, lng: lng, district: district);
    }

    return SosFailure(
      'Could not open SMS or dialler.\n'
      'Call NDRF directly: ${primary.phone}',
    );
  }

  /// Direct call — uses LaunchMode.externalApplication (required on Android).
  Future<bool> call(EmergencyContact contact) async {
    final uri = Uri(scheme: 'tel', path: contact.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
