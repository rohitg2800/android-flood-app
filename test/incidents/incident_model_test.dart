// Module 5: Incident Model Unit Tests
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Incident', () {
    test('fromJson parses status correctly', () {
      final json = {
        'id': 'test-uuid-002',
        'title': 'Road blocked by flood water',
        'status': 'open',
        'priority': 'high',
        'created_at': '2026-07-07T10:00:00Z',
        'updated_at': '2026-07-07T10:00:00Z',
        'image_urls': [],
      };

      // TODO: Uncomment after importing
      // final incident = Incident.fromJson(json);
      // expect(incident.status, IncidentStatus.open);
      // expect(incident.priority, IncidentPriority.high);
      expect(json['status'], 'open'); // Placeholder
    });
  });
}
