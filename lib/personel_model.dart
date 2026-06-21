// personel_model.dart
import 'dart:convert';

class Personel {
  String id;
  String ad;

  // Food & Beverage tarafında boş kalabilir.
  // Housekeeping tarafında MAID, MEYDANCI, HK MANAG gibi görevleri tutacağız.
  String gorev;

  Map<String, String> haftalikShift;

  Personel({
    required this.id,
    required this.ad,
    required this.haftalikShift,
    this.gorev = '',
  });

  Personel copyWith({
    String? id,
    String? ad,
    String? gorev,
    Map<String, String>? haftalikShift,
  }) {
    return Personel(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      gorev: gorev ?? this.gorev,
      haftalikShift: haftalikShift ?? Map<String, String>.from(this.haftalikShift),
    );
  }

  // Veriyi buluta kaydetmek için Harita (Map) formatına çevirir
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ad': ad,
      'gorev': gorev,
      'haftalikShift': haftalikShift,
    };
  }

  // Buluttan okunan veriyi tekrar Personel nesnesine çevirir
  factory Personel.fromMap(Map<String, dynamic> map) {
    return Personel(
      id: (map['id'] ?? '').toString(),
      ad: (map['ad'] ?? '').toString(),
      gorev: (map['gorev'] ?? '').toString(),
      haftalikShift: Map<String, String>.from(map['haftalikShift'] ?? {}),
    );
  }

  // Personel listesini komple tek bir yazı (String) haline getirir
  static String encode(List<Personel> personeller) {
    return json.encode(
      personeller.map<Map<String, dynamic>>((p) => p.toMap()).toList(),
    );
  }

  // Buluttan okunan yazıyı komple Personel listesine geri çevirir
  static List<Personel> decode(String personellerJson) {
    final dynamic cozulenVeri = json.decode(personellerJson);

    if (cozulenVeri is! List) {
      return [];
    }

    return cozulenVeri.map<Personel>((item) {
      if (item is Map<String, dynamic>) {
        return Personel.fromMap(item);
      }

      if (item is Map) {
        return Personel.fromMap(Map<String, dynamic>.from(item));
      }

      return Personel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ad: '',
        gorev: '',
        haftalikShift: {},
      );
    }).where((personel) => personel.ad.trim().isNotEmpty).toList();
  }
}