// puantaj_model.dart
import 'personel_model.dart';

class PuantajPersonelSatiri {
  final String personelAnahtari;
  final Personel personel;
  final Map<int, String> gunKodlari;
  final Map<String, int> toplamlar;
  final int sskGunu;
  final int ayGunu;

  const PuantajPersonelSatiri({
    required this.personelAnahtari,
    required this.personel,
    required this.gunKodlari,
    required this.toplamlar,
    required this.sskGunu,
    required this.ayGunu,
  });

  String gunKodu(int gun) {
    return gunKodlari[gun] ?? '';
  }

  int toplam(String kod) {
    return toplamlar[kod] ?? 0;
  }
}

class PuantajAySonucu {
  final int yil;
  final int ay;
  final List<PuantajPersonelSatiri> satirlar;

  const PuantajAySonucu({
    required this.yil,
    required this.ay,
    required this.satirlar,
  });

  int get ayGunSayisi {
    return DateTime(yil, ay + 1, 0).day;
  }

  bool get bosMu => satirlar.isEmpty;
}