import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../models/person.dart';
import '../services/matcher.dart';
import 'enroll_screen.dart';

const _roles = ['Élève', 'Enseignant', 'Personnel', 'Surveillant', 'Parent'];
const _maxPhotos = 10;

/// A photo holds either a saved sample or a freshly analyzed face.
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
  late final List<_Slot> _slots = [
    for (final s in widget.existing?.samples ?? const <FaceSample>[])
      _Slot.saved(s),
  ];
  bool _analyzing = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _desc.dispose();
    super.dispose();
  }

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
      _message('Maximum $_maxPhotos photos.');
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
              ? 'Aucun visage détecté sur cette photo.'
              : '${result.faceCount} visages détectés : il en faut un seul.',
        );
        return;
      }
      setState(
        () => _slots.add(
          _Slot.fresh(EnrolledFace(result.embedding!, result.thumbnailJpg!)),
        ),
      );
    } catch (e) {
      _message('Erreur : $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _remove(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Retirer cette photo ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => _slots.removeAt(index));
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _message('Le nom est obligatoire.');
      return;
    }
    final filled = _slots;
    if (filled.isEmpty) {
      _message('Enregistrez d’abord le visage.');
      return;
    }
    final state = AppScope.read(context);
    final fresh = filled.map((s) => s.fresh).whereType<EnrolledFace>().toList();

    for (final face in fresh) {
      final m = state.identify(
        face.embedding,
        excludePersonId: widget.existing?.id,
      );
      if (m.status == MatchStatus.recognized) {
        final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Visage déjà enregistré ?'),
            content: Text(
              'Ce visage ressemble à « ${m.person!.name} » (${(m.score * 100).round()} %). Enregistrer quand même ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Enregistrer'),
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
    final busy = _saving || _analyzing;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Modifier la fiche' : 'Nouvelle personne'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Visage', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'L’enregistrement guidé prend automatiquement 5 photos : '
            'de face, à gauche, à droite, en haut et en bas.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_slots.isNotEmpty || _analyzing)
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _slots.length + (_analyzing ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _thumb(i),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : _guided,
            icon: const Icon(Icons.face_retouching_natural),
            label: Text(
              _slots.isEmpty
                  ? 'Enregistrer le visage (guidé)'
                  : 'Refaire l’enregistrement guidé',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _fromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Ajouter une photo depuis la galerie'),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom et prénom *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _role,
            decoration: const InputDecoration(
              labelText: 'Fonction / classe',
              border: OutlineInputBorder(),
            ),
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
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: busy ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
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
      width: 88,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: i >= _slots.length || _saving ? null : () => _remove(i),
          child: SizedBox.expand(child: content),
        ),
      ),
    );
  }
}
