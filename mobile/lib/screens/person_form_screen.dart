import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models/person.dart';
import '../services/matcher.dart';
import '../services/remote_api.dart';
import '../theme.dart';
import '../widgets/person_widgets.dart';
import 'enroll_screen.dart';

const _maxPhotos = 10;

/// A photo holds either a saved sample or a freshly analyzed face.
class _Slot {
  final FaceSample? saved;
  final EnrolledFace? fresh;

  const _Slot.saved(this.saved) : fresh = null;
  const _Slot.fresh(this.fresh) : saved = null;
}

String _currentSchoolYear() {
  final now = DateTime.now();
  final start = now.month >= 9 ? now.year : now.year - 1;
  return '$start-${start + 1}';
}

class PersonFormScreen extends StatefulWidget {
  const PersonFormScreen({super.key, this.existing});

  final Person? existing;

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  late final Person? _p = widget.existing;
  late final _lastName = TextEditingController(text: _p?.lastName);
  late final _firstName = TextEditingController(text: _p?.firstName);
  late final _matricule = TextEditingController(text: _p?.matricule);
  late final _classLevel = TextEditingController(text: _p?.classLevel);
  late final _schoolYear = TextEditingController(
    text: _p?.schoolYear ?? _currentSchoolYear(),
  );
  late final _jobTitle = TextEditingController(text: _p?.jobTitle);
  late final _parentName = TextEditingController(text: _p?.parentName);
  late final _parentPhone = TextEditingController(text: _p?.parentPhone);
  late final _address = TextEditingController(text: _p?.address);
  late final _medical = TextEditingController(text: _p?.medical);
  late final _notes = TextEditingController(text: _p?.notes);
  late String _type = _p?.type ?? 'eleve';
  late String _sex = _p?.sex ?? '';
  late String _status = _p?.status ?? 'actif';
  late String _birthDate = _p?.birthDate ?? '';
  late String _enrollmentDate = _p?.enrollmentDate ?? '';

  late final List<_Slot> _slots = [
    for (final s in _p?.samples ?? const <FaceSample>[]) _Slot.saved(s),
  ];
  bool _analyzing = false;
  bool _saving = false;
  bool _looking = false;

  List<TextEditingController> get _controllers => [
    _lastName,
    _firstName,
    _matricule,
    _classLevel,
    _schoolYear,
    _jobTitle,
    _parentName,
    _parentPhone,
    _address,
    _medical,
    _notes,
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _guided() async {
    final faces = await Navigator.push<List<EnrolledFace>>(
      context,
      MaterialPageRoute(builder: (_) => const EnrollScreen()),
    );
    if (faces == null || faces.isEmpty || !mounted) return;
    // A new guided session replaces the previous photos.
    setState(
      () => _slots
        ..clear()
        ..addAll(faces.map(_Slot.fresh)),
    );
  }

  Future<void> _fromGallery() async {
    if (_slots.length >= _maxPhotos) {
      _message(context.tr('max_photos', {'n': _maxPhotos}));
      return;
    }
    final path = (await ImagePicker().pickImage(source: ImageSource.gallery))
        ?.path;
    if (path == null || !mounted) return;
    setState(() => _analyzing = true);
    try {
      final result = await AppScope.read(context).faces.analyze(path);
      if (!mounted) return;
      if (result.faceCount != 1) {
        _message(
          result.faceCount == 0
              ? context.tr('no_face_in_photo')
              : context.tr('several_faces', {'n': result.faceCount}),
        );
        return;
      }
      setState(
        () => _slots.add(
          _Slot.fresh(EnrolledFace(result.embedding!, result.thumbnailJpg!)),
        ),
      );
    } catch (e) {
      if (mounted) _message('${context.tr('error')} : $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _remove(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('remove_photo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr('remove')),
          ),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _slots.removeAt(index));
  }

  /// Fills the form from the school's management system.
  Future<void> _lookup() async {
    final matricule = _matricule.text.trim();
    if (matricule.isEmpty) {
      _message(context.tr('lookup_enter_matricule'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _looking = true);
    try {
      final r = await AppScope.read(context).lookupStudent(matricule);
      if (!mounted) return;
      if (!r.found) {
        _message(context.tr('lookup_not_found', {'m': matricule}));
        return;
      }
      setState(() => _apply(r.fields));
      _message(context.tr('lookup_found'));
    } on RemoteException catch (e) {
      if (mounted) _message(e.message);
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  /// The management system is the reference: its values replace what was
  /// typed; fields it does not know are left untouched.
  void _apply(Map<String, String> f) {
    String? v(String k) => (f[k]?.trim().isEmpty ?? true) ? null : f[k]!.trim();
    final controllers = {
      'matricule': _matricule,
      'last_name': _lastName,
      'first_name': _firstName,
      'class_level': _classLevel,
      'school_year': _schoolYear,
      'job_title': _jobTitle,
      'parent_name': _parentName,
      'parent_phone': _parentPhone,
      'address': _address,
      'medical': _medical,
      'notes': _notes,
    };
    controllers.forEach((k, c) {
      final value = v(k);
      if (value != null) c.text = value;
    });
    if (personTypes.contains(v('type'))) _type = v('type')!;
    if (personStatuses.contains(v('status'))) _status = v('status')!;
    if (v('sex') == 'M' || v('sex') == 'F') _sex = v('sex')!;
    _birthDate = v('birth_date') ?? _birthDate;
    _enrollmentDate = v('enrollment_date') ?? _enrollmentDate;
  }

  Future<void> _pickDate(String current, ValueChanged<String> set) async {
    final initial = DateTime.tryParse(current) ?? DateTime(2012);
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (d != null) {
      setState(
        () => set(
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        ),
      );
    }
  }

  Person _draft() => Person(
    id: _p?.id ?? '',
    schoolId: 0,
    type: _type,
    matricule: _matricule.text.trim(),
    firstName: _firstName.text.trim(),
    lastName: _lastName.text.trim(),
    sex: _sex,
    birthDate: _birthDate,
    status: _status,
    classLevel: _type == 'eleve' ? _classLevel.text.trim() : '',
    schoolYear: _type == 'eleve' ? _schoolYear.text.trim() : '',
    enrollmentDate: _type == 'eleve' ? _enrollmentDate : '',
    jobTitle: _type == 'eleve' ? '' : _jobTitle.text.trim(),
    parentName: _type == 'eleve' ? _parentName.text.trim() : '',
    parentPhone: _type == 'eleve' ? _parentPhone.text.trim() : '',
    address: _address.text.trim(),
    medical: _medical.text.trim(),
    notes: _notes.text.trim(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Future<void> _save() async {
    final draft = _draft();
    if (draft.name.isEmpty) {
      _message(context.tr('name_required'));
      return;
    }
    if (_slots.isEmpty) {
      _message(context.tr('face_required'));
      return;
    }
    final state = AppScope.read(context);
    final fresh = _slots.map((s) => s.fresh).whereType<EnrolledFace>().toList();

    for (final face in fresh) {
      final m = state.identify(face.embedding, excludePersonId: _p?.id);
      if (m.status == MatchStatus.recognized) {
        final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(c.tr('duplicate_title')),
            content: Text(
              c.tr('duplicate_info', {
                'name': m.person!.name,
                'score': (m.score * 100).round(),
              }),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(c.tr('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(c.tr('save')),
              ),
            ],
          ),
        );
        if (go != true) return;
        break;
      }
    }

    setState(() => _saving = true);
    try {
      await state.savePerson(
        draft: draft,
        keep: _slots.map((s) => s.saved).whereType<FaceSample>().toList(),
        added: fresh,
      );
      if (!mounted) return;
      _message(context.tr('saved_person', {'name': draft.name}));
      Navigator.pop(context);
    } catch (e) {
      _message('${context.tr('error')} : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final sensitive = state.canSeeSensitive;
    final busy = _saving || _analyzing;
    final student = _type == 'eleve';

    Widget field(
      TextEditingController c,
      String label, {
      IconData? icon,
      TextInputType? keyboard,
      int lines = 1,
      TextCapitalization caps = TextCapitalization.none,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 3,
        textCapitalization: caps,
        decoration: InputDecoration(
          labelText: context.tr(label),
          prefixIcon: icon == null ? null : Icon(icon),
          alignLabelWithHint: lines > 1,
        ),
      ),
    );

    Widget dateField(String label, String value, ValueChanged<String> set) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _pickDate(value, set),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: context.tr(label),
                prefixIcon: const Icon(Icons.event_outlined),
                suffixIcon: value.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => set('')),
                      ),
              ),
              child: Text(value.isEmpty ? '—' : formatDate(value)),
            ),
          ),
        );

    Widget section(IconData icon, String title, List<Widget> children) => Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.teal),
                const SizedBox(width: 8),
                Text(
                  context.tr(title),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(_p == null ? 'new_person' : 'edit_person')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          section(Icons.face_retouching_natural, 'face', [
            Text(
              context.tr('guided_info'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_slots.isNotEmpty || _analyzing) ...[
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _slots.length + (_analyzing ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _thumb(i),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: busy ? null : _guided,
              icon: const Icon(Icons.face_retouching_natural),
              label: Text(
                context.tr(_slots.isEmpty ? 'guided_start' : 'guided_redo'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : _fromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(context.tr('add_from_gallery')),
            ),
            const SizedBox(height: 12),
          ]),
          section(Icons.badge_outlined, 'section_identity', [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in personTypes)
                  ChoiceChip(
                    label: Text(context.tr('type_$t')),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _matricule,
                textInputAction: TextInputAction.search,
                onSubmitted: state.managementEnabled ? (_) => _lookup() : null,
                decoration: InputDecoration(
                  labelText: context.tr('matricule'),
                  prefixIcon: const Icon(Icons.tag),
                  helperText: state.managementEnabled
                      ? context.tr('lookup_hint')
                      : null,
                  suffixIcon: !state.managementEnabled
                      ? null
                      : _looking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: context.tr('lookup_matricule'),
                          icon: const Icon(Icons.manage_search),
                          onPressed: busy ? null : _lookup,
                        ),
                ),
              ),
            ),
            field(
              _lastName,
              'last_name',
              icon: Icons.person_outline,
              caps: TextCapitalization.words,
            ),
            field(
              _firstName,
              'first_name',
              icon: Icons.person_outline,
              caps: TextCapitalization.words,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'M', label: Text(context.tr('sex_m'))),
                  ButtonSegment(value: 'F', label: Text(context.tr('sex_f'))),
                ],
                emptySelectionAllowed: true,
                selected: {if (_sex.isNotEmpty) _sex},
                onSelectionChanged: (s) =>
                    setState(() => _sex = s.isEmpty ? '' : s.first),
              ),
            ),
            if (sensitive)
              dateField('birth_date', _birthDate, (v) => _birthDate = v),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: context.tr('status'),
                  prefixIcon: const Icon(Icons.flag_outlined),
                ),
                items: [
                  for (final s in personStatuses)
                    DropdownMenuItem(
                      value: s,
                      child: Text(context.tr('status_$s')),
                    ),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'actif'),
              ),
            ),
          ]),
          if (student)
            section(Icons.school_outlined, 'section_school', [
              field(_classLevel, 'class_level', icon: Icons.class_outlined),
              field(
                _schoolYear,
                'school_year',
                icon: Icons.calendar_month_outlined,
              ),
              dateField(
                'enrollment_date',
                _enrollmentDate,
                (v) => _enrollmentDate = v,
              ),
            ])
          else
            section(Icons.work_outline, 'section_job', [
              field(_jobTitle, 'job_title', icon: Icons.work_outline),
            ]),
          if (sensitive)
            section(
              Icons.family_restroom,
              student ? 'section_parents' : 'section_contact',
              [
                if (student) ...[
                  field(
                    _parentName,
                    'parent_name',
                    icon: Icons.person_outline,
                    caps: TextCapitalization.words,
                  ),
                  field(
                    _parentPhone,
                    'parent_phone',
                    icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                  ),
                ],
                field(_address, 'address', icon: Icons.home_outlined, lines: 2),
              ],
            ),
          if (sensitive)
            section(Icons.medical_information_outlined, 'section_health', [
              field(_medical, 'medical_hint', lines: 3),
            ]),
          section(Icons.notes, 'notes', [field(_notes, 'notes', lines: 3)]),
          FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }

  Widget _thumb(int i) {
    final scheme = Theme.of(context).colorScheme;
    Widget content;
    if (i >= _slots.length) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_slots[i].saved != null) {
      content = Image.file(File(_slots[i].saved!.photoPath), fit: BoxFit.cover);
    } else {
      content = Image.memory(
        Uint8List.fromList(_slots[i].fresh!.thumbnailJpg),
        fit: BoxFit.cover,
      );
    }
    return SizedBox(
      width: 84,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: i >= _slots.length || _saving ? null : () => _remove(i),
          child: SizedBox.expand(child: content),
        ),
      ),
    );
  }
}
