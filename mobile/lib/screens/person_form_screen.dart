import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models/person.dart';
import '../services/matcher.dart';
import 'capture_screen.dart';

const _roles = ['Élève', 'Enseignant', 'Personnel', 'Surveillant', 'Parent'];
const _slotCount = 3;

/// A photo slot holds either a saved sample or a freshly analyzed face.
class _Slot {
  final FaceSample? saved;
  final EnrolledFace? fresh;

  const _Slot.saved(this.saved) : fresh = null;
  const _Slot.fresh(this.fresh) : saved = null;
}

class PersonFormScreen extends StatefulWidget {
  const PersonFormScreen({super.key, this.existing});

  final Person? existing;

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _role = TextEditingController(text: widget.existing?.role);
  late final _desc = TextEditingController(text: widget.existing?.description);
  late final List<_Slot?> _slots = List.generate(_slotCount, (i) {
    final samples = widget.existing?.samples ?? const [];
    return i < samples.length ? _Slot.saved(samples[i]) : null;
  });
  int? _analyzing;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pick(int index) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(c, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(c, 'gallery'),
            ),
            if (_slots[index] != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Retirer cette photo'),
                onTap: () => Navigator.pop(c, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    if (source == 'remove') {
      setState(() => _slots[index] = null);
      return;
    }

    String? path;
    if (source == 'camera') {
      path = await Navigator.push<String>(
        context,
        MaterialPageRoute(
            builder: (_) => CaptureScreen(title: 'Photo ${index + 1}')),
      );
    } else {
      path = (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;
    }
    if (path == null || !mounted) return;

    setState(() => _analyzing = index);
    try {
      final result = await AppScope.read(context).faces.analyze(path);
      if (!mounted) return;
      if (result.faceCount != 1) {
        _message(result.faceCount == 0
            ? 'Aucun visage détecté sur cette photo.'
            : '${result.faceCount} visages détectés : il en faut un seul.');
        return;
      }
      setState(() => _slots[index] =
          _Slot.fresh(EnrolledFace(result.embedding!, result.thumbnailJpg!)));
    } catch (e) {
      _message('Erreur : $e');
    } finally {
      if (mounted) setState(() => _analyzing = null);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _message('Le nom est obligatoire.');
      return;
    }
    final filled = _slots.whereType<_Slot>().toList();
    if (filled.isEmpty) {
      _message('Ajoutez au moins une photo du visage.');
      return;
    }
    final state = AppScope.read(context);
    final fresh = filled.map((s) => s.fresh).whereType<EnrolledFace>().toList();

    for (final face in fresh) {
      final m = state.identify(face.embedding,
          excludePersonId: widget.existing?.id);
      if (m.status == MatchStatus.recognized) {
        final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Visage déjà enregistré ?'),
            content: Text(
                'Ce visage ressemble à « ${m.person!.name} » (${(m.score * 100).round()} %). Enregistrer quand même ?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Annuler')),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Enregistrer')),
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
        existing: widget.existing,
        name: name,
        role: _role.text.trim(),
        description: _desc.text.trim(),
        keep: filled.map((s) => s.saved).whereType<FaceSample>().toList(),
        added: fresh,
      );
      if (!mounted) return;
      _message('$name enregistré(e).');
      Navigator.pop(context);
    } catch (e) {
      _message('Erreur : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
          title: Text(editing ? 'Modifier la fiche' : 'Nouvelle personne')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Photos du visage', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('3 photos de face recommandées (lumière différente, avec/sans lunettes…).',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < _slotCount; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _slotTile(i)),
              ],
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Nom et prénom *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _role,
            decoration: const InputDecoration(
                labelText: 'Fonction / classe', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final r in _roles)
                ActionChip(
                  label: Text(r),
                  onPressed: () => setState(() => _role.text = r),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _desc,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
                labelText: 'Description / remarques',
                alignLabelWithHint: true,
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving || _analyzing != null ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Enregistrer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotTile(int i) {
    final slot = _slots[i];
    final scheme = Theme.of(context).colorScheme;
    Widget content;
    if (_analyzing == i) {
      content = const Center(child: CircularProgressIndicator());
    } else if (slot?.saved != null) {
      content = Image.file(File(slot!.saved!.photoPath), fit: BoxFit.cover);
    } else if (slot?.fresh != null) {
      content = Image.memory(Uint8List.fromList(slot!.fresh!.thumbnailJpg),
          fit: BoxFit.cover);
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, color: scheme.primary),
          const SizedBox(height: 4),
          Text('Photo ${i + 1}', style: TextStyle(color: scheme.primary)),
        ],
      );
    }
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _analyzing != null || _saving ? null : () => _pick(i),
          child: SizedBox.expand(child: content),
        ),
      ),
    );
  }
}
