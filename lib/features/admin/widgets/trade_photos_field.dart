import 'package:flutter/material.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/photo_attach.dart';

/// One row in the dated-photos editor: either an existing saved photo (has an
/// id + url) or a freshly picked one (carries bytes via [photo]).
class TradePhotoRow {
  TradePhotoRow.fresh()
      : id = null,
        existingUrl = null;

  TradePhotoRow.existing(
      {required this.id, required this.existingUrl, required String date}) {
    this.date.text = date;
  }

  final String? id;
  final String? existingUrl;
  final PhotoAttachController photo = PhotoAttachController();
  final TextEditingController date = TextEditingController(
      text: DateTime.now().toIso8601String().split('T').first);
}

/// Holds the dated photos being edited on a trade and persists them back to
/// `trade_photos`. Many per trade; the existing single `trades.image_url` cover
/// is separate and untouched. Mirrors the controller pattern of
/// [UnderlyingLegsController] and reuses [PhotoAttachController.upload].
class TradePhotosController extends ChangeNotifier {
  final List<TradePhotoRow> rows = [];
  final List<String> _deletedIds = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Pick a new photo and, if one was chosen, append a row dated today.
  Future<void> addNew() async {
    final row = TradePhotoRow.fresh();
    await row.photo.pick();
    if (row.photo.hasPhoto) {
      rows.add(row);
      notifyListeners();
    }
  }

  void removeAt(int i) {
    final row = rows[i];
    if (row.id != null) _deletedIds.add(row.id!);
    rows.removeAt(i);
    notifyListeners();
  }

  /// Rebuild after a date field is typed.
  void update() => notifyListeners();

  Future<void> loadFor(String tradeId) async {
    final data = await supabase
        .from('trade_photos')
        .select('id, image_url, photo_date')
        .eq('trade_id', tradeId)
        .order('photo_date', ascending: false);
    rows
      ..clear()
      ..addAll([
        for (final r in data)
          TradePhotoRow.existing(
            id: r['id'] as String,
            existingUrl: r['image_url'] as String,
            date: (r['photo_date'] as String?) ?? '',
          ),
      ]);
    _deletedIds.clear();
    _loaded = true;
    notifyListeners();
  }

  /// null when valid; otherwise a message.
  String? validate() {
    for (final r in rows) {
      if (DateTime.tryParse(r.date.text.trim()) == null) {
        return 'Each photo needs a date (yyyy-mm-dd).';
      }
    }
    return null;
  }

  /// Apply the edits: delete removed rows, upload + insert new ones, and update
  /// dates on the rest. Call after [validate] passes.
  Future<void> persist(String tradeId) async {
    if (_deletedIds.isNotEmpty) {
      await supabase.from('trade_photos').delete().inFilter('id', _deletedIds);
      _deletedIds.clear();
    }
    for (final r in rows) {
      if (r.id == null) {
        final url = await r.photo.upload();
        await supabase.from('trade_photos').insert({
          'trade_id': tradeId,
          'image_url': url,
          'photo_date': r.date.text.trim(),
        });
      } else {
        await supabase
            .from('trade_photos')
            .update({'photo_date': r.date.text.trim()})
            .eq('id', r.id!);
      }
    }
  }
}

/// Add/remove list of dated photos. Tapping the add button picks a photo and
/// drops in a row with a date field (defaulting to today).
class TradePhotosField extends StatelessWidget {
  const TradePhotosField({super.key, required this.controller});

  final TradePhotosController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('PHOTOS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: KColors.memberTextSecondary)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                tooltip: 'Add a dated photo',
                onPressed: controller.addNew,
              ),
            ]),
            if (controller.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('No photos attached.',
                    style: TextStyle(
                        fontSize: 12, color: KColors.memberTextSecondary)),
              ),
            for (var i = 0; i < controller.rows.length; i++) _row(i),
          ],
        );
      },
    );
  }

  Widget _row(int i) {
    final r = controller.rows[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: r.photo.hasPhoto
              ? Image.memory(r.photo.bytes!,
                  width: 48, height: 48, fit: BoxFit.cover)
              : Image.network(r.existingUrl!,
                  width: 48, height: 48, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: r.date,
            decoration: const InputDecoration(
                labelText: 'Date', helperText: 'yyyy-mm-dd'),
            onChanged: (_) => controller.update(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          tooltip: 'Remove',
          onPressed: () => controller.removeAt(i),
        ),
      ]),
    );
  }
}
