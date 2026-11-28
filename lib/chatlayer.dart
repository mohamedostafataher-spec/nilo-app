import 'package:flutter/material.dart';
import 'bottles.dart';
import 'health.dart';
import 'i18n.dart';

/// Shared pieces of the status layer used by friends chat, papyrus conversations and groups.
/// All state lives on the server (see supabase/migrations/0003 and 0004); this file only draws it.
class ChatLayer {
  static String hm(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// One grey tick = sent, two grey = delivered, two blue = read. Blue only shows when the server says both people allow receipts.
  static Widget ticks({required bool delivered, required bool read, required bool receipts}) {
    final blue = read && receipts;
    return Icon(delivered || blue ? Icons.done_all : Icons.done, size: 15, color: blue ? const Color(0xFF53BDEB) : Colors.white54);
  }

  /// Status line of one person: typing, online, or last seen (only what the server allows to be shown).
  static String line(Map st) {
    if (st['typing'] == true) return L('typing… • بيكتب…');
    if (st['online'] == true) return L('online • متصل');
    final sec = st['seen_s'];
    if (sec is num) {
      final m = sec ~/ 60;
      if (m < 60) return L('last seen $m min ago • اخر ظهور من $m د');
      if (m < 1440) return L('last seen ${m ~/ 60} h ago • اخر ظهور من ${m ~/ 60} ساعة');
      return L('last seen ${m ~/ 1440} d ago • اخر ظهور من ${m ~/ 1440} يوم');
    }
    return '';
  }

  static Future<void> privacyDialog(BuildContext context) async {
    var on = true, rc = true, ons = false, rcs = false;
    try {
      final v = await Sb.rpc('my_chat_privacy', {});
      if (v is Map) { on = v['online'] != false; rc = v['receipts'] != false; ons = v['online_str'] == true; rcs = v['receipts_str'] == true; }
    } catch (e, st) { Health.log(e, st); }
    if (!context.mounted) return;
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text(L('Chat privacy • خصوصية الشات')),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(L('Friends • الأصدقاء'), style: const TextStyle(fontWeight: FontWeight.w800)),
        SwitchListTile(dense: true, value: on, onChanged: (v) => set(() => on = v), title: Text(L('Show when I am online • اظهر إني متصل'))),
        SwitchListTile(dense: true, value: rc, onChanged: (v) => set(() => rc = v), title: Text(L('Read receipts (blue ticks) • علامة القراءة'))),
        const SizedBox(height: 8),
        Text(L('Strangers (papyrus and groups) • الغرباء'), style: const TextStyle(fontWeight: FontWeight.w800)),
        SwitchListTile(dense: true, value: ons, onChanged: (v) => set(() => ons = v), title: Text(L('Show when I am online • اظهر إني متصل'))),
        SwitchListTile(dense: true, value: rcs, onChanged: (v) => set(() => rcs = v), title: Text(L('Read receipts • علامة القراءة'))),
        Text(L('Off by default for strangers. Like WhatsApp: if you turn one off, you also cannot see it for others. Typing is shown only inside an open conversation.'), style: const TextStyle(fontSize: 11, color: Colors.white60)),
      ])),
      actions: [TextButton(onPressed: () async {
        try { await Sb.rpc('set_chat_privacy', {'p_online': on, 'p_receipts': rc, 'p_online_str': ons, 'p_receipts_str': rcs}); } catch (e, st) { Health.log(e, st); }
        if (ctx.mounted) Navigator.pop(ctx);
      }, child: Text(L('Save • حفظ')))],
    )));
  }
}
