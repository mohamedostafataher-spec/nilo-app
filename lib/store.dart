import 'i18n.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'world.dart' show Passport;

class _Item {
  final String id, slot, name, ar;
  final int price;
  final Color color;
  const _Item(this.id, this.slot, this.name, this.ar, this.price, this.color);
}

const _items = <_Item>[
  _Item('seal_gold', 'seal', 'Gold wax seal', 'ختم ذهبي', 30, Color(0xFFD9A441)),
  _Item('seal_teal', 'seal', 'Teal wax seal', 'ختم فيروزي', 30, Color(0xFF1F8A8A)),
  _Item('seal_violet', 'seal', 'Violet wax seal', 'ختم بنفسجي', 50, Color(0xFF7A5AA6)),
  _Item('sail_saffron', 'sail', 'Saffron sail', 'شراع زعفراني', 40, Color(0xFFF2B33D)),
  _Item('sail_turquoise', 'sail', 'Turquoise sail', 'شراع تركواز', 40, Color(0xFF5CC8C0)),
  _Item('sail_rose', 'sail', 'Rose sail', 'شراع وردي', 60, Color(0xFFE88AA0)),
];

/// Reeds store: cosmetics for the send animation. Reeds are earned by real actions only. No money, ever.
class StorePage extends StatefulWidget {
  const StorePage({super.key});
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  void _tap(_Item it) {
    final owned = Passport.owned.contains(it.id);
    if (!owned) {
      if (!Passport.spendReeds(it.price)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not enough Reeds. You have ${Passport.reeds}. • رصيدك مش كفاية')));
        return;
      }
      Passport.own(it.id);
    }
    final on = Passport.equipped(it.slot) == it.id;
    Passport.equip(it.slot, on ? '' : it.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(title: Text(L('Store • المتجر')), backgroundColor: kBg),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF12304D), borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🌿 ${Passport.reeds} Reeds • قصب', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(L('Earn Reeds by real actions: send a papyrus (+10), finish a story chapter (+10), post a story (+5), solve the daily puzzle (+5), open the app each day (+5). They only buy looks for your send animation. Kept on this phone.'), style: TextStyle(fontSize: 12, height: 1.4, color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 12),
        for (final it in _items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: it.color, radius: 16),
              title: Text(L('${it.name} • ${it.ar}')),
              subtitle: Text(it.slot == 'seal' ? 'Wax seal on your papyrus' : 'Felucca sail'),
              trailing: FilledButton(
                onPressed: () => _tap(it),
                child: Text(Passport.equipped(it.slot) == it.id ? 'On' : Passport.owned.contains(it.id) ? 'Use' : '${it.price} 🌿'),
              ),
            ),
          ),
        Padding(padding: EdgeInsets.all(12), child: Text(L('More items later. Nothing here costs money.'), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white54))),
      ]),
    );
  }
}
