import 'health.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CachedResp {
  final String body;
  CachedResp(this.body);
  List<int> get bodyBytes => utf8.encode(body);
}

/// GET with a small on-phone cache so the same public data is not fetched again and again.
/// Falls back to an older copy when offline. Nothing is stored except the public response.
Future<CachedResp> cachedGet(String url, int freshMinutes, {Map<String, String>? headers, int timeoutSec = 12}) async {
  final p = await SharedPreferences.getInstance();
  final k = 'cg_${url.hashCode}';
  final raw = p.getString(k);
  if (raw != null) {
    try {
      final j = jsonDecode(raw) as Map;
      final age = DateTime.now().millisecondsSinceEpoch - (j['t'] as int);
      if (age < freshMinutes * 60000) return CachedResp(j['b'] as String);
    } catch (e, st) { Health.log(e, st); }
  }
  try {
    final r = await http.get(Uri.parse(url), headers: headers).timeout(Duration(seconds: timeoutSec));
    if (r.statusCode == 200) {
      final b = utf8.decode(r.bodyBytes);
      await p.setString(k, jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'b': b}));
      return CachedResp(b);
    }
  } catch (e, st) { Health.log(e, st); }
  if (raw != null) { try { return CachedResp((jsonDecode(raw) as Map)['b'] as String); } catch (e, st) { Health.log(e, st); } }
  throw Exception('offline');
}
