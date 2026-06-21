// departman_ayar_model.dart
//
// Kullanıcıya/departmana göre arayüz, vardiya, özel durum ve puantaj ayarları.
//
// Mantık:
// - Food & Beverage: Babanın vardiya/PAX/puantaj sistemi
// - Housekeeping: Annenin görev sütunlu, imzalı, PAX'siz sistemi
//
// Firestore yapısı:
// kullanici_ayarlari / kullaniciUid

class OzelDurumAyar {
  final String kod;
  final String etiket;
  final String puantajKodu;
  final String arkaPlanHex;
  final String yaziHex;
  final bool kalin;
  final bool hizliDoldurmadaGoster;

  const OzelDurumAyar({
    required this.kod,
    required this.etiket,
    this.puantajKodu = '',
    required this.arkaPlanHex,
    required this.yaziHex,
    this.kalin = true,
    this.hizliDoldurmadaGoster = true,
  });

  factory OzelDurumAyar.fromMap(Map<String, dynamic> map) {
    return OzelDurumAyar(
      kod: (map['kod'] ?? '').toString(),
      etiket: (map['etiket'] ?? map['kod'] ?? '').toString(),
      puantajKodu: (map['puantaj_kodu'] ?? '').toString(),
      arkaPlanHex: (map['arka_plan_hex'] ?? '#FFFFFF').toString(),
      yaziHex: (map['yazi_hex'] ?? '#000000').toString(),
      kalin: map['kalin'] is bool ? map['kalin'] as bool : true,
      hizliDoldurmadaGoster: map['hizli_doldurmada_goster'] is bool
          ? map['hizli_doldurmada_goster'] as bool
          : true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kod': kod,
      'etiket': etiket,
      'puantaj_kodu': puantajKodu,
      'arka_plan_hex': arkaPlanHex,
      'yazi_hex': yaziHex,
      'kalin': kalin,
      'hizli_doldurmada_goster': hizliDoldurmadaGoster,
    };
  }
}

class PuantajKolonAyar {
  final String kod;
  final String baslik;
  final String aciklama;

  const PuantajKolonAyar({
    required this.kod,
    required this.baslik,
    required this.aciklama,
  });

  factory PuantajKolonAyar.fromMap(Map<String, dynamic> map) {
    return PuantajKolonAyar(
      kod: (map['kod'] ?? '').toString(),
      baslik: (map['baslik'] ?? map['kod'] ?? '').toString(),
      aciklama: (map['aciklama'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kod': kod,
      'baslik': baslik,
      'aciklama': aciklama,
    };
  }
}

class DepartmanAyarlari {
  final String departmanKodu;
  final String departmanBasligi;

  final String personelBaslik;
  final String gorevBaslik;
  final bool gorevSutunuGoster;
  final bool imzaSutunuGoster;

  final bool paxGoster;
  final String paxBaslik;

  final bool puantajGoster;
  final String puantajBasligi;
  final String normalCalismaKodu;

  final List<String> vardiyaSaatleri;
  final List<String> gorevSecenekleri;
  final List<OzelDurumAyar> ozelDurumlar;
  final List<PuantajKolonAyar> puantajKolonlari;

  const DepartmanAyarlari({
    required this.departmanKodu,
    required this.departmanBasligi,
    required this.personelBaslik,
    required this.gorevBaslik,
    required this.gorevSutunuGoster,
    required this.imzaSutunuGoster,
    required this.paxGoster,
    required this.paxBaslik,
    required this.puantajGoster,
    required this.puantajBasligi,
    required this.normalCalismaKodu,
    required this.vardiyaSaatleri,
    required this.gorevSecenekleri,
    required this.ozelDurumlar,
    required this.puantajKolonlari,
  });

  factory DepartmanAyarlari.fromMap(Map<String, dynamic> map) {
    final String departmanKodu =
        (map['departman_kodu'] ?? 'food_beverage').toString();

    final DepartmanAyarlari sablon = sablonOlustur(departmanKodu);
    final bool housekeepingMi = _housekeepingMi(departmanKodu);

    return DepartmanAyarlari(
      departmanKodu: departmanKodu,
      departmanBasligi:
          (map['departman_basligi'] ?? sablon.departmanBasligi).toString(),
      personelBaslik:
          (map['personel_baslik'] ?? sablon.personelBaslik).toString(),
      gorevBaslik: (map['gorev_baslik'] ?? sablon.gorevBaslik).toString(),
      gorevSutunuGoster: map['gorev_sutunu_goster'] is bool
          ? map['gorev_sutunu_goster'] as bool
          : sablon.gorevSutunuGoster,
      imzaSutunuGoster: map['imza_sutunu_goster'] is bool
          ? map['imza_sutunu_goster'] as bool
          : sablon.imzaSutunuGoster,
      paxGoster: map['pax_goster'] is bool
          ? map['pax_goster'] as bool
          : sablon.paxGoster,
      paxBaslik: (map['pax_baslik'] ?? sablon.paxBaslik).toString(),
      puantajGoster: map['puantaj_goster'] is bool
          ? map['puantaj_goster'] as bool
          : sablon.puantajGoster,
      puantajBasligi:
          (map['puantaj_basligi'] ?? sablon.puantajBasligi).toString(),
      normalCalismaKodu:
          (map['normal_calisma_kodu'] ?? sablon.normalCalismaKodu).toString(),

      // Bunlar Firestore'dan gelirse kullanılabilir.
      vardiyaSaatleri: _stringListedenOku(
        map['vardiya_saatleri'],
        varsayilan: sablon.vardiyaSaatleri,
      ),
      gorevSecenekleri: _stringListedenOku(
        map['gorev_secenekleri'],
        varsayilan: sablon.gorevSecenekleri,
      ),

      // Housekeeping özel durumlarını burada sabitliyoruz.
      // Böylece Firestore'da eski ozel_durumlar alanı kalsa bile annenin yeni kodları gelir.
      ozelDurumlar: housekeepingMi
          ? List<OzelDurumAyar>.from(sablon.ozelDurumlar)
          : _ozelDurumListedenOku(
              map['ozel_durumlar'],
              varsayilan: sablon.ozelDurumlar,
            ),

      puantajKolonlari: _puantajKolonListedenOku(
        map['puantaj_kolonlari'],
        varsayilan: sablon.puantajKolonlari,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'departman_kodu': departmanKodu,
      'departman_basligi': departmanBasligi,
      'personel_baslik': personelBaslik,
      'gorev_baslik': gorevBaslik,
      'gorev_sutunu_goster': gorevSutunuGoster,
      'imza_sutunu_goster': imzaSutunuGoster,
      'pax_goster': paxGoster,
      'pax_baslik': paxBaslik,
      'puantaj_goster': puantajGoster,
      'puantaj_basligi': puantajBasligi,
      'normal_calisma_kodu': normalCalismaKodu,
      'vardiya_saatleri': vardiyaSaatleri,
      'gorev_secenekleri': gorevSecenekleri,
      'ozel_durumlar': ozelDurumlar.map((e) => e.toMap()).toList(),
      'puantaj_kolonlari': puantajKolonlari.map((e) => e.toMap()).toList(),
    };
  }

  DepartmanAyarlari copyWith({
    String? departmanKodu,
    String? departmanBasligi,
    String? personelBaslik,
    String? gorevBaslik,
    bool? gorevSutunuGoster,
    bool? imzaSutunuGoster,
    bool? paxGoster,
    String? paxBaslik,
    bool? puantajGoster,
    String? puantajBasligi,
    String? normalCalismaKodu,
    List<String>? vardiyaSaatleri,
    List<String>? gorevSecenekleri,
    List<OzelDurumAyar>? ozelDurumlar,
    List<PuantajKolonAyar>? puantajKolonlari,
  }) {
    return DepartmanAyarlari(
      departmanKodu: departmanKodu ?? this.departmanKodu,
      departmanBasligi: departmanBasligi ?? this.departmanBasligi,
      personelBaslik: personelBaslik ?? this.personelBaslik,
      gorevBaslik: gorevBaslik ?? this.gorevBaslik,
      gorevSutunuGoster: gorevSutunuGoster ?? this.gorevSutunuGoster,
      imzaSutunuGoster: imzaSutunuGoster ?? this.imzaSutunuGoster,
      paxGoster: paxGoster ?? this.paxGoster,
      paxBaslik: paxBaslik ?? this.paxBaslik,
      puantajGoster: puantajGoster ?? this.puantajGoster,
      puantajBasligi: puantajBasligi ?? this.puantajBasligi,
      normalCalismaKodu: normalCalismaKodu ?? this.normalCalismaKodu,
      vardiyaSaatleri: vardiyaSaatleri ?? this.vardiyaSaatleri,
      gorevSecenekleri: gorevSecenekleri ?? this.gorevSecenekleri,
      ozelDurumlar: ozelDurumlar ?? this.ozelDurumlar,
      puantajKolonlari: puantajKolonlari ?? this.puantajKolonlari,
    );
  }

  String puantajKodunaCevir(String durum) {
    final String temiz = durum.trim();

    if (temiz.isEmpty || temiz == 'Boş' || temiz == '-') {
      return '';
    }

    for (final OzelDurumAyar ozelDurum in ozelDurumlar) {
      if (ozelDurum.kod == temiz || ozelDurum.etiket == temiz) {
        return ozelDurum.puantajKodu.trim().isEmpty
            ? ozelDurum.etiket
            : ozelDurum.puantajKodu;
      }
    }

    if (_vardiyaSaatineBenziyor(temiz)) {
      return normalCalismaKodu;
    }

    return temiz;
  }

  bool puantajdaGunSayilirMi(String puantajKodu) {
    return puantajKodu.trim().isNotEmpty;
  }

  static bool _vardiyaSaatineBenziyor(String deger) {
    final RegExp saatAraligi =
        RegExp(r'^\d{1,2}[:.]\d{2}\s*-\s*\d{1,2}[:.]\d{2}$');

    return saatAraligi.hasMatch(deger.trim());
  }

  static DepartmanAyarlari foodBeverage() {
    return const DepartmanAyarlari(
      departmanKodu: 'food_beverage',
      departmanBasligi: 'Food And Beverage Service Team',
      personelBaslik: 'Personel',
      gorevBaslik: 'Görevi',
      gorevSutunuGoster: false,
      imzaSutunuGoster: false,
      paxGoster: true,
      paxBaslik: 'KAHVALTI SAYISI (PAX)',
      puantajGoster: true,
      puantajBasligi: 'RESTORAN PUANTAJ',
      normalCalismaKodu: 'X',
      vardiyaSaatleri: [
        '06:30-16:30',
        '07:00-12:00',
        '07:00-15:00',
        '08:00-16:00',
        '12:30-22:30',
        '13:00-23:00',
        '14:00-22:00',
        '15:00-23:00',
      ],
      gorevSecenekleri: [],
      ozelDurumlar: [
        OzelDurumAyar(
          kod: 'OFF',
          etiket: 'OFF',
          puantajKodu: 'OFF',
          arkaPlanHex: '#FFEE58',
          yaziHex: '#111111',
        ),
        OzelDurumAyar(
          kod: 'RESMİ TATİL',
          etiket: 'RESMİ TATİL',
          puantajKodu: 'H',
          arkaPlanHex: '#E53935',
          yaziHex: '#FFFFFF',
        ),
        OzelDurumAyar(
          kod: 'YILLIK İZİN',
          etiket: 'YILLIK İZİN',
          puantajKodu: 'Y',
          arkaPlanHex: '#1565C0',
          yaziHex: '#FFFFFF',
        ),
        OzelDurumAyar(
          kod: 'ÜCRETLİ İZİN',
          etiket: 'ÜCRETLİ İZİN',
          puantajKodu: 'P',
          arkaPlanHex: '#00B0F0',
          yaziHex: '#111111',
        ),
        OzelDurumAyar(
          kod: 'RAPORLU',
          etiket: 'RAPORLU',
          puantajKodu: 'S',
          arkaPlanHex: '#C00000',
          yaziHex: '#FFFFFF',
        ),
        OzelDurumAyar(
          kod: 'ALACAK İZİN',
          etiket: 'ALACAK İZİN',
          puantajKodu: 'R',
          arkaPlanHex: '#F4B183',
          yaziHex: '#111111',
        ),
        OzelDurumAyar(
          kod: 'ÜCRETSİZ İZİN',
          etiket: 'ÜCRETSİZ İZİN',
          puantajKodu: 'A',
          arkaPlanHex: '#BFBFBF',
          yaziHex: '#111111',
        ),
        OzelDurumAyar(
          kod: 'GÖREVLİ',
          etiket: 'GÖREVLİ',
          puantajKodu: 'M',
          arkaPlanHex: '#70AD47',
          yaziHex: '#111111',
        ),
        OzelDurumAyar(
          kod: 'SERBEST ZAMAN',
          etiket: 'SERBEST ZAMAN',
          puantajKodu: 'F',
          arkaPlanHex: '#FCE4D6',
          yaziHex: '#111111',
        ),
        OzelDurumAyar(
          kod: 'MAZERETSİZ GELMEME',
          etiket: 'MAZERETSİZ GELMEME',
          puantajKodu: 'O',
          arkaPlanHex: '#7F0000',
          yaziHex: '#FFFFFF',
        ),
      ],
      puantajKolonlari: [
        PuantajKolonAyar(kod: 'X', baslik: 'X', aciklama: 'Normal Çalışma'),
        PuantajKolonAyar(kod: 'XT', baslik: 'XT', aciklama: 'Extra Time'),
        PuantajKolonAyar(kod: 'OFF', baslik: 'OFF', aciklama: 'Hafta Tatili'),
        PuantajKolonAyar(kod: 'P', baslik: 'P', aciklama: 'Ücretli İzin'),
        PuantajKolonAyar(kod: 'Y', baslik: 'Y', aciklama: 'Yıllık İzin'),
        PuantajKolonAyar(kod: 'M', baslik: 'M', aciklama: 'Görevli'),
        PuantajKolonAyar(
          kod: 'H',
          baslik: 'H',
          aciklama: 'Genel ve Resmi Tatil',
        ),
        PuantajKolonAyar(kod: 'R', baslik: 'R', aciklama: 'Alacak İzin'),
        PuantajKolonAyar(kod: 'F', baslik: 'F', aciklama: 'Serbest Zaman'),
        PuantajKolonAyar(kod: 'A', baslik: 'A', aciklama: 'Ücretsiz İzin'),
        PuantajKolonAyar(kod: 'S', baslik: 'S', aciklama: 'Raporlu / Hasta'),
        PuantajKolonAyar(
          kod: 'O',
          baslik: 'O',
          aciklama: 'Mazeretsiz Gelmeme',
        ),
      ],
    );
  }

  static DepartmanAyarlari housekeeping() {
    return const DepartmanAyarlari(
      departmanKodu: 'housekeeping',
      departmanBasligi: 'Housekeeping Team',
      personelBaslik: 'Adı Soyadı',
      gorevBaslik: 'Görevi',
      gorevSutunuGoster: true,
      imzaSutunuGoster: true,
      paxGoster: false,
      paxBaslik: '',
      puantajGoster: false,
      puantajBasligi: 'HOUSEKEEPING PUANTAJ',
      normalCalismaKodu: 'X',
      vardiyaSaatleri: [
        '07:00-16:00',
        '07:00-15:00',
        '07:00-10:00',
        '15:00-23:00',
      ],
      gorevSecenekleri: [
        'MAID',
        'MEYDANCI',
        'HK MANAGER',
      ],
      ozelDurumlar: [
        OzelDurumAyar(
          kod: 'OFF',
          etiket: 'OFF',
          puantajKodu: 'OFF',
          arkaPlanHex: '#C6E0B4',
          yaziHex: '#111111',
        ),
        OzelDurumAyar(
          kod: 'B',
          etiket: 'B',
          puantajKodu: 'B',
          arkaPlanHex: '#00B050',
          yaziHex: '#FFFFFF',
        ),
        OzelDurumAyar(
          kod: 'G',
          etiket: 'G',
          puantajKodu: 'G',
          arkaPlanHex: '#F4CCCC',
          yaziHex: '#111111',
        ),
        OzelDurumAyar(
          kod: 'R',
          etiket: 'R',
          puantajKodu: 'R',
          arkaPlanHex: '#E53935',
          yaziHex: '#FFFFFF',
        ),
        OzelDurumAyar(
          kod: 'D',
          etiket: 'D',
          puantajKodu: 'D',
          arkaPlanHex: '#7F0000',
          yaziHex: '#FFFFFF',
        ),
        OzelDurumAyar(
          kod: 'Ü',
          etiket: 'Ü',
          puantajKodu: 'Ü',
          arkaPlanHex: '#D9EAD3',
          yaziHex: '#111111',
        ),
        OzelDurumAyar(
          kod: 'Y',
          etiket: 'Y',
          puantajKodu: 'Y',
          arkaPlanHex: '#1565C0',
          yaziHex: '#FFFFFF',
        ),
        OzelDurumAyar(
          kod: 'Z',
          etiket: 'Z',
          puantajKodu: 'Z',
          arkaPlanHex: '#FCE4D6',
          yaziHex: '#111111',
        ),

        // Eski kayıtlarda RT varsa bozmasın diye gizli destek.
        // Shift seçim ekranında gösterilmeyecek.
        OzelDurumAyar(
          kod: 'RT',
          etiket: 'RT',
          puantajKodu: 'G',
          arkaPlanHex: '#C6E0B4',
          yaziHex: '#111111',
          hizliDoldurmadaGoster: false,
        ),
      ],
      puantajKolonlari: [],
    );
  }

  static DepartmanAyarlari varsayilan() {
    return foodBeverage();
  }

  static DepartmanAyarlari sablonOlustur(String departmanKodu) {
    if (_housekeepingMi(departmanKodu)) {
      return housekeeping();
    }

    return foodBeverage();
  }

  static bool _housekeepingMi(String departmanKodu) {
    final String kod = departmanKodu.trim().toLowerCase();

    return kod == 'housekeeping' || kod == 'hk' || kod == 'kat';
  }

  static List<String> _stringListedenOku(
    dynamic veri, {
    required List<String> varsayilan,
  }) {
    if (veri is! List) return List<String>.from(varsayilan);

    final List<String> sonuc = veri
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return sonuc.isEmpty ? List<String>.from(varsayilan) : sonuc;
  }

  static List<OzelDurumAyar> _ozelDurumListedenOku(
    dynamic veri, {
    required List<OzelDurumAyar> varsayilan,
  }) {
    if (veri is! List) return List<OzelDurumAyar>.from(varsayilan);

    final List<OzelDurumAyar> sonuc = [];

    for (final item in veri) {
      if (item is Map<String, dynamic>) {
        sonuc.add(OzelDurumAyar.fromMap(item));
      } else if (item is Map) {
        sonuc.add(OzelDurumAyar.fromMap(Map<String, dynamic>.from(item)));
      }
    }

    return sonuc.isEmpty ? List<OzelDurumAyar>.from(varsayilan) : sonuc;
  }

  static List<PuantajKolonAyar> _puantajKolonListedenOku(
    dynamic veri, {
    required List<PuantajKolonAyar> varsayilan,
  }) {
    if (veri is! List) return List<PuantajKolonAyar>.from(varsayilan);

    final List<PuantajKolonAyar> sonuc = [];

    for (final item in veri) {
      if (item is Map<String, dynamic>) {
        sonuc.add(PuantajKolonAyar.fromMap(item));
      } else if (item is Map) {
        sonuc.add(PuantajKolonAyar.fromMap(Map<String, dynamic>.from(item)));
      }
    }

    return sonuc.isEmpty ? List<PuantajKolonAyar>.from(varsayilan) : sonuc;
  }
}