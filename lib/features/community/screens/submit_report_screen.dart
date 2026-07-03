import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equinox_flood/features/community/models/community_report.dart';
import 'package:equinox_flood/features/community/providers/community_provider.dart';

class SubmitReportScreen extends ConsumerStatefulWidget {
  const SubmitReportScreen({super.key});

  @override
  ConsumerState<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends ConsumerState<SubmitReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  ReportSeverity _severity = ReportSeverity.medium;
  ReportCategory _category = ReportCategory.flooding;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(submitReportProvider.notifier).submit(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          latitude: double.parse(_latCtrl.text.trim()),
          longitude: double.parse(_lngCtrl.text.trim()),
          severity: _severity,
          category: _category,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(submitReportProvider);
    final isLoading = submitState is AsyncLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Submit Report',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel('Report Title'),
              const SizedBox(height: 8),
              _StyledTextField(
                controller: _titleCtrl,
                hint: 'e.g. Road flooded near Patna junction',
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 20),
              _SectionLabel('Description'),
              const SizedBox(height: 8),
              _StyledTextField(
                controller: _descCtrl,
                hint: 'Describe the situation in detail...',
                maxLines: 4,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Description is required' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('Latitude'),
                        const SizedBox(height: 8),
                        _StyledTextField(
                          controller: _latCtrl,
                          hint: '25.59',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('Longitude'),
                        const SizedBox(height: 8),
                        _StyledTextField(
                          controller: _lngCtrl,
                          hint: '85.13',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionLabel('Severity'),
              const SizedBox(height: 8),
              _SeveritySelector(
                selected: _severity,
                onChanged: (v) => setState(() => _severity = v),
              ),
              const SizedBox(height: 20),
              _SectionLabel('Category'),
              const SizedBox(height: 8),
              _CategoryDropdown(
                selected: _category,
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Submit Report',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4));
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF16161E),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4C4C), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF4C4C), width: 1.5),
        ),
      ),
    );
  }
}

class _SeveritySelector extends StatelessWidget {
  final ReportSeverity selected;
  final ValueChanged<ReportSeverity> onChanged;
  const _SeveritySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final severities = ReportSeverity.values;
    final colors = {
      ReportSeverity.low: const Color(0xFF00E676),
      ReportSeverity.medium: const Color(0xFFFFD600),
      ReportSeverity.high: const Color(0xFFFF6D00),
      ReportSeverity.critical: const Color(0xFFFF4C4C),
    };
    return Row(
      children: severities
          .map(
            (s) => Expanded(
              child: GestureDetector(
                onTap: () => onChanged(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected == s
                        ? colors[s]!.withOpacity(0.18)
                        : const Color(0xFF16161E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected == s
                          ? colors[s]!.withOpacity(0.6)
                          : Colors.white.withOpacity(0.08),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      s.name[0].toUpperCase() + s.name.substring(1),
                      style: TextStyle(
                        color: selected == s
                            ? colors[s]
                            : Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        fontWeight:
                            selected == s ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final ReportCategory selected;
  final ValueChanged<ReportCategory> onChanged;
  const _CategoryDropdown({required this.selected, required this.onChanged});

  String _label(ReportCategory c) {
    switch (c) {
      case ReportCategory.flooding:
        return 'Flooding';
      case ReportCategory.blocked_drain:
        return 'Blocked Drain';
      case ReportCategory.pump_failure:
        return 'Pump Failure';
      case ReportCategory.road_damage:
        return 'Road Damage';
      case ReportCategory.evacuation_needed:
        return 'Evacuation Needed';
      case ReportCategory.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ReportCategory>(
      value: selected,
      dropdownColor: const Color(0xFF16161E),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF16161E),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 1.5),
        ),
      ),
      items: ReportCategory.values
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(_label(c),
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
