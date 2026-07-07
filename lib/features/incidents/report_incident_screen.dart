import 'package:flutter/material.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  // TODO: GPS location via geolocator
  // TODO: Photo capture via image_picker
  // TODO: Upload to Firebase Storage
  // TODO: POST to Neon via API
  // TODO: Cache locally with SQLite for offline-first

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Incident')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () {}, child: const Text('Attach Photo')),
            ElevatedButton(onPressed: () {}, child: const Text('Submit Report')),
          ],
        ),
      ),
    );
  }
}
