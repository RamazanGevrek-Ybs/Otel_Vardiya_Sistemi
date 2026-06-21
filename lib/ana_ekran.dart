// ana_ekran.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'personel_model.dart';
import 'shift_dialog.dart';
import 'personel_ekle_dialog.dart';
import 'paylas_ekrani.dart';
import 'departman_ayar_model.dart';
import 'puantaj_ekrani.dart';

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _HaftaKaydi {
  final String id;
  final DateTime baslangicTarihi;
  final String baslik;
  final int personelSayisi;
  final DateTime? sonGuncelleme;

  const _HaftaKaydi({
    required this.id,
    required this.baslangicTarihi,
    required this.baslik,
    required this.personelSayisi,
    required this.sonGuncelleme,
  });
}

class _AnaEkranState extends State<AnaEkran> {
  final List<String> gunler = [
    "Pazartesi",
    "Salı",
    "Çarşamba",
    "Perşembe",
    "Cuma",
    "Cumartesi",
    "Pazar"
  ];

  List<Personel> personelListesi = [];
  List<_HaftaKaydi> haftaKayitlari = [];

  bool _yukleniyor = true;
  bool _kaydediliyor = false;
  bool _haftaKayitlariYukleniyor = false;

  final double personelHucreGenisligi = 180.0;
  final double gorevHucreGenisligi = 90.0;
  final double gunHucreGenisligi = 130.0;
  final double imzaHucreGenisligi = 90.0;
  final double hucreYuksekligi = 60.0;
  final double paxHucreYuksekligi = 24.0;

  final Map<String, String> _gunTarihleri = {};

  late DateTime _aktifHaftaBaslangic;

  DepartmanAyarlari _departmanAyarlari = DepartmanAyarlari.varsayilan();

  String paxBaslik = "KAHVALTI SAYISI (PAX)";
  Map<String, String> paxVerileri = {};

  @override
  void initState() {
    super.initState();
    _aktifHaftaBaslangic = _varsayilanHaftaBaslangici();
    _tarihleriHesapla(_aktifHaftaBaslangic);
    _verileriBuluttanYukle();
  }

  DateTime _sadeceTarih(DateTime tarih) {
    return DateTime(tarih.year, tarih.month, tarih.day);
  }

  DateTime _varsayilanHaftaBaslangici() {
    final DateTime bugun = _sadeceTarih(DateTime.now());

    if (bugun.weekday >= 5) {
      return bugun.add(Duration(days: 8 - bugun.weekday));
    }

    return bugun.subtract(Duration(days: bugun.weekday - 1));
  }

  String _ikiHane(int sayi) => sayi.toString().padLeft(2, '0');

  String _tarihKisa(DateTime tarih) {
    return "${_ikiHane(tarih.day)}.${_ikiHane(tarih.month)}";
  }

  String _tarihUzun(DateTime tarih) {
    return "${tarih.year}-${_ikiHane(tarih.month)}-${_ikiHane(tarih.day)}";
  }

  DateTime? _tarihUzunCoz(String? deger) {
    if (deger == null) return null;

    try {
      final List<String> parcalar = deger.split('-');
      if (parcalar.length != 3) return null;

      return DateTime(
        int.parse(parcalar[0]),
        int.parse(parcalar[1]),
        int.parse(parcalar[2]),
      );
    } catch (_) {
      return null;
    }
  }

  String _haftaIdOlustur(DateTime baslangic) {
    final DateTime bitis = baslangic.add(const Duration(days: 6));
    return "${_tarihUzun(baslangic)}_${_tarihUzun(bitis)}";
  }

  String get _aktifHaftaId => _haftaIdOlustur(_aktifHaftaBaslangic);

  String get _aktifHaftaBaslik {
    final DateTime bitis = _aktifHaftaBaslangic.add(const Duration(days: 6));
    return "${_tarihKisa(_aktifHaftaBaslangic)} - ${_tarihKisa(bitis)}";
  }

  String get _ekranBasligi => "Haftalık Shift Programı ($_aktifHaftaBaslik)";

  double get _gorevSutunuGenisligi =>
      _departmanAyarlari.gorevSutunuGoster ? gorevHucreGenisligi : 0.0;

  double get _imzaSutunuGenisligi =>
      _departmanAyarlari.imzaSutunuGoster ? imzaHucreGenisligi : 0.0;

  double get _solBilgiGenisligi => personelHucreGenisligi + _gorevSutunuGenisligi;

  double get _tabloToplamGenisligi =>
      personelHucreGenisligi +
      _gorevSutunuGenisligi +
      (gunHucreGenisligi * 7) +
      _imzaSutunuGenisligi;

  void _tarihleriHesapla(DateTime baslangicPazartesi) {
    _gunTarihleri.clear();

    for (int i = 0; i < 7; i++) {
      DateTime gunTarihi = baslangicPazartesi.add(Duration(days: i));
      _gunTarihleri[gunler[i]] = _tarihKisa(gunTarihi);
    }
  }

  DocumentReference<Map<String, dynamic>> _kullaniciDoc(User user) {
    return FirebaseFirestore.instance.collection('shift_verileri').doc(user.uid);
  }

  CollectionReference<Map<String, dynamic>> _haftalarCollection(User user) {
    return _kullaniciDoc(user).collection('haftalar');
  }

  DocumentReference<Map<String, dynamic>> _kullaniciAyarDoc(User user) {
    return FirebaseFirestore.instance.collection('kullanici_ayarlari').doc(user.uid);
  }

  Map<String, String> _stringMapeCevir(dynamic veri) {
    if (veri is! Map) return {};

    return veri.map<String, String>((key, value) {
      return MapEntry(key.toString(), value?.toString() ?? "");
    });
  }

  List<Personel> _personelListesiCoz(dynamic veri) {
    if (veri is! String || veri.trim().isEmpty) return [];

    try {
      return Personel.decode(veri);
    } catch (_) {
      return [];
    }
  }

  int _personelSayisiCoz(dynamic veri) {
    return _personelListesiCoz(veri).length;
  }

  Future<void> _departmanAyarlariniYukle(User user) async {
    try {
      final doc = await _kullaniciAyarDoc(user).get();

      if (doc.exists && doc.data() != null) {
        _departmanAyarlari = DepartmanAyarlari.fromMap(doc.data()!);
      } else {
        _departmanAyarlari = DepartmanAyarlari.varsayilan();
      }
    } catch (e) {
      debugPrint("Departman ayarları yüklenemedi, varsayılan ayarlar kullanılacak: $e");
      _departmanAyarlari = DepartmanAyarlari.varsayilan();
    }

    if (_departmanAyarlari.paxBaslik.trim().isNotEmpty) {
      paxBaslik = _departmanAyarlari.paxBaslik;
    }
  }

  void _haftaVerisiniStateIcindeYukle(Map<String, dynamic> data) {
    personelListesi = _personelListesiCoz(data['veri']);

    if (data['pax_baslik'] is String && data['pax_baslik'].toString().trim().isNotEmpty) {
      paxBaslik = data['pax_baslik'].toString();
    } else if (_departmanAyarlari.paxBaslik.trim().isNotEmpty) {
      paxBaslik = _departmanAyarlari.paxBaslik;
    } else {
      paxBaslik = "KAHVALTI SAYISI (PAX)";
    }

    paxVerileri = _stringMapeCevir(data['pax_verileri']);
  }

  void _bosHaftaStateIcindeAc() {
    personelListesi = [];
    paxBaslik = _departmanAyarlari.paxBaslik.trim().isNotEmpty
        ? _departmanAyarlari.paxBaslik
        : "KAHVALTI SAYISI (PAX)";
    paxVerileri = {};
  }

  DateTime _haftaBaslangiciniDatadanBul(String docId, Map<String, dynamic> data) {
    final DateTime? tarih = _tarihUzunCoz(data['baslangic_tarihi']?.toString());
    if (tarih != null) return tarih;

    final List<String> idParcalari = docId.split('_');
    if (idParcalari.isNotEmpty) {
      final DateTime? idTarihi = _tarihUzunCoz(idParcalari.first);
      if (idTarihi != null) return idTarihi;
    }

    return _varsayilanHaftaBaslangici();
  }

  String _haftaBasligiOlustur(DateTime baslangic) {
    final DateTime bitis = baslangic.add(const Duration(days: 6));
    return "${_tarihKisa(baslangic)} - ${_tarihKisa(bitis)}";
  }

  DateTime? _timestampCoz(dynamic veri) {
    if (veri is Timestamp) return veri.toDate();
    return null;
  }

  String _sonGuncellemeYazisi(DateTime? tarih) {
    if (tarih == null) return "";

    return "Son güncelleme: ${_ikiHane(tarih.day)}.${_ikiHane(tarih.month)}.${tarih.year} ${_ikiHane(tarih.hour)}:${_ikiHane(tarih.minute)}";
  }

  Future<List<_HaftaKaydi>> _haftaKayitlariniGetir(User user) async {
    final snapshot = await _haftalarCollection(user).get();

    final List<_HaftaKaydi> kayitlar = snapshot.docs.map((doc) {
      final data = doc.data();
      final DateTime baslangic = _haftaBaslangiciniDatadanBul(doc.id, data);
      final String baslikRaw = data['baslik']?.toString().trim() ?? "";
      final String baslik = baslikRaw.isNotEmpty
          ? baslikRaw
          : _haftaBasligiOlustur(baslangic);

      return _HaftaKaydi(
        id: doc.id,
        baslangicTarihi: baslangic,
        baslik: baslik,
        personelSayisi: _personelSayisiCoz(data['veri']),
        sonGuncelleme: _timestampCoz(data['son_guncelleme']),
      );
    }).toList();

    kayitlar.sort((a, b) => b.baslangicTarihi.compareTo(a.baslangicTarihi));
    return kayitlar;
  }

  Future<void> _haftaKayitlariniYenile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _haftaKayitlariYukleniyor = true);

    try {
      final List<_HaftaKaydi> kayitlar = await _haftaKayitlariniGetir(user);
      if (!mounted) return;

      setState(() {
        haftaKayitlari = kayitlar;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Haftalık kayıtlar yüklenirken hata oluştu: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _haftaKayitlariYukleniyor = false);
    }
  }

  Future<void> _verileriBuluttanYukle() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) setState(() => _yukleniyor = false);
      return;
    }

    bool eskiVeriyiYeniHaftayaTasi = false;

    try {
      await _departmanAyarlariniYukle(user);

      final List<_HaftaKaydi> kayitlar = await _haftaKayitlariniGetir(user);
      final haftaDoc = await _haftalarCollection(user).doc(_aktifHaftaId).get();

      Map<String, dynamic>? yuklenecekData;

      if (haftaDoc.exists && haftaDoc.data() != null) {
        yuklenecekData = haftaDoc.data();
      } else if (kayitlar.isEmpty) {
        final eskiDoc = await _kullaniciDoc(user).get();
        if (eskiDoc.exists && eskiDoc.data() != null) {
          final eskiData = eskiDoc.data()!;
          if (eskiData['veri'] is String && eskiData['veri'].toString().trim().isNotEmpty) {
            yuklenecekData = eskiData;
            eskiVeriyiYeniHaftayaTasi = true;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        haftaKayitlari = kayitlar;

        if (yuklenecekData != null) {
          _haftaVerisiniStateIcindeYukle(yuklenecekData!);
        } else {
          _bosHaftaStateIcindeAc();
        }
      });

      if (eskiVeriyiYeniHaftayaTasi) {
        await _verileriBulutaKaydet();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Veriler yüklenirken hata oluştu: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<bool> _verileriBulutaKaydet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final String jsonStr = Personel.encode(personelListesi);
      final DateTime bitis = _aktifHaftaBaslangic.add(const Duration(days: 6));

      final Map<String, dynamic> haftaData = {
        'hafta_id': _aktifHaftaId,
        'baslik': _aktifHaftaBaslik,
        'baslangic_tarihi': _tarihUzun(_aktifHaftaBaslangic),
        'bitis_tarihi': _tarihUzun(bitis),
        'departman_kodu': _departmanAyarlari.departmanKodu,
        'departman_basligi': _departmanAyarlari.departmanBasligi,
        'veri': jsonStr,
        'pax_baslik': paxBaslik,
        'pax_verileri': paxVerileri,
        'personel_sayisi': personelListesi.length,
        'son_guncelleme': FieldValue.serverTimestamp(),
      };

      await _haftalarCollection(user).doc(_aktifHaftaId).set(
            haftaData,
            SetOptions(merge: true),
          );

      await _kullaniciDoc(user).set(
        {
          'aktif_hafta_id': _aktifHaftaId,
          'departman_kodu': _departmanAyarlari.departmanKodu,
          'departman_basligi': _departmanAyarlari.departmanBasligi,
          'veri': jsonStr,
          'pax_baslik': paxBaslik,
          'pax_verileri': paxVerileri,
          'son_guncelleme': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await _haftaKaydiniYereldeGuncelle();
      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Buluta kaydetme hatası: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }
  }

  Future<void> _haftaKaydiniYereldeGuncelle() async {
    if (!mounted) return;

    final DateTime simdi = DateTime.now();
    final _HaftaKaydi guncelKayit = _HaftaKaydi(
      id: _aktifHaftaId,
      baslangicTarihi: _aktifHaftaBaslangic,
      baslik: _aktifHaftaBaslik,
      personelSayisi: personelListesi.length,
      sonGuncelleme: simdi,
    );

    setState(() {
      final int index = haftaKayitlari.indexWhere((kayit) => kayit.id == _aktifHaftaId);
      if (index >= 0) {
        haftaKayitlari[index] = guncelKayit;
      } else {
        haftaKayitlari.add(guncelKayit);
      }

      haftaKayitlari.sort((a, b) => b.baslangicTarihi.compareTo(a.baslangicTarihi));
    });
  }

  Future<void> _aktifHaftayiManuelKaydet() async {
    setState(() => _kaydediliyor = true);

    final bool basarili = await _verileriBulutaKaydet();

    if (!mounted) return;

    setState(() => _kaydediliyor = false);

    if (!basarili) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$_aktifHaftaBaslik haftası kaydedildi."),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  Future<void> _haftayiTarihleAc(DateTime yeniBaslangic) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _verileriBulutaKaydet();

    if (!mounted) return;
    setState(() => _yukleniyor = true);

    final DateTime temizBaslangic = _sadeceTarih(yeniBaslangic);
    final String yeniHaftaId = _haftaIdOlustur(temizBaslangic);

    try {
      final haftaDoc = await _haftalarCollection(user).doc(yeniHaftaId).get();

      if (!mounted) return;

      setState(() {
        _aktifHaftaBaslangic = temizBaslangic;
        _tarihleriHesapla(_aktifHaftaBaslangic);

        if (haftaDoc.exists && haftaDoc.data() != null) {
          _haftaVerisiniStateIcindeYukle(haftaDoc.data()!);
        } else {
          _bosHaftaStateIcindeAc();
        }
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hafta açılırken hata oluştu: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _kayitliHaftayiAc(_HaftaKaydi kayit) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _verileriBulutaKaydet();

    if (!mounted) return;
    setState(() => _yukleniyor = true);

    try {
      final haftaDoc = await _haftalarCollection(user).doc(kayit.id).get();

      if (!haftaDoc.exists || haftaDoc.data() == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bu haftanın kaydı bulunamadı."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final data = haftaDoc.data()!;
      final DateTime baslangic = _haftaBaslangiciniDatadanBul(kayit.id, data);

      if (!mounted) return;

      setState(() {
        _aktifHaftaBaslangic = baslangic;
        _tarihleriHesapla(_aktifHaftaBaslangic);
        _haftaVerisiniStateIcindeYukle(data);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hafta açılırken hata oluştu: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _mevcutHaftayiSonrakiHaftayaKopyala() async {
    final DateTime hedefHafta = _aktifHaftaBaslangic.add(const Duration(days: 7));
    final String hedefBaslik = _haftaBasligiOlustur(hedefHafta);

    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.copy, color: Colors.blueGrey),
              SizedBox(width: 10),
              Text("Sonraki Haftaya Kopyala"),
            ],
          ),
          content: Text(
            "$_aktifHaftaBaslik haftasındaki personel, vardiya ve PAX bilgileri $hedefBaslik haftasına kopyalansın mı?\n\nHedef haftada eski kayıt varsa üzerine yazılır.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("İptal"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.copy, color: Colors.white),
              label: const Text(
                "Kopyala",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (onay != true) return;

    await _verileriBulutaKaydet();

    if (!mounted) return;

    setState(() {
      _aktifHaftaBaslangic = hedefHafta;
      _tarihleriHesapla(_aktifHaftaBaslangic);

      personelListesi = personelListesi.map((p) {
        return Personel(
          id: p.id,
          ad: p.ad,
          gorev: p.gorev,
          haftalikShift: Map<String, String>.from(p.haftalikShift),
        );
      }).toList();

      paxVerileri = Map<String, String>.from(paxVerileri);
    });

    await _aktifHaftayiManuelKaydet();
  }

  Future<void> _haftaSilDialog(_HaftaKaydi kayit) async {
    final bool aktifHaftaMi = kayit.id == _aktifHaftaId;

    final bool? silinsinMi = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.redAccent),
              SizedBox(width: 10),
              Text("Hafta Silinsin mi?"),
            ],
          ),
          content: Text(
            "${kayit.baslik} haftalık shift kaydını silmek istediğinize emin misiniz?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("İptal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Sil",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (silinsinMi != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _haftalarCollection(user).doc(kayit.id).delete();

      if (!mounted) return;

      setState(() {
        haftaKayitlari.removeWhere((item) => item.id == kayit.id);

        if (aktifHaftaMi) {
          _bosHaftaStateIcindeAc();
        }
      });

      if (aktifHaftaMi) {
        await _kullaniciDoc(user).set(
          {
            'aktif_hafta_id': _aktifHaftaId,
            'veri': Personel.encode([]),
            'pax_baslik': _departmanAyarlari.paxBaslik.trim().isNotEmpty
                ? _departmanAyarlari.paxBaslik
                : "KAHVALTI SAYISI (PAX)",
            'pax_verileri': {},
            'son_guncelleme': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${kayit.baslik} haftası silindi.")),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hafta silinirken hata oluştu: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _yeniPersonelEkle(String ad) {
    _yeniPersonelEkleDetayli(ad, '');
  }

  void _yeniPersonelEkleDetayli(String ad, String gorev) {
    setState(() {
      personelListesi.add(
        Personel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          ad: ad,
          gorev: gorev,
          haftalikShift: {},
        ),
      );
    });

    _verileriBulutaKaydet();
  }

  Future<void> _personelSilDialog(Personel personel) async {
    final bool? silinsinMi = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_forever, color: Colors.redAccent),
              SizedBox(width: 10),
              Text("Silinsin mi?"),
            ],
          ),
          content: Text(
            "${personel.ad} isimli personeli listeden silmek istediğinize emin misiniz?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "İptal",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Sil",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (silinsinMi == true) {
      setState(() {
        personelListesi.removeWhere((p) => p.id == personel.id);
      });

      await _verileriBulutaKaydet();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${personel.ad} silindi."),
        ),
      );
    }
  }

  Future<void> _personelGorevDuzenle(Personel personel) async {
    if (!_departmanAyarlari.gorevSutunuGoster) return;

    final TextEditingController ctrl = TextEditingController(text: personel.gorev);
    String secilenGorev = personel.gorev.trim().isNotEmpty
        ? personel.gorev
        : (_departmanAyarlari.gorevSecenekleri.isNotEmpty
            ? _departmanAyarlari.gorevSecenekleri.first
            : '');

    final String? yeniGorev = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text("${personel.ad} - ${_departmanAyarlari.gorevBaslik}"),
              content: SizedBox(
                width: 360,
                child: _departmanAyarlari.gorevSecenekleri.isEmpty
                    ? TextField(
                        controller: ctrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: _departmanAyarlari.gorevBaslik,
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        value: _departmanAyarlari.gorevSecenekleri.contains(secilenGorev)
                            ? secilenGorev
                            : _departmanAyarlari.gorevSecenekleri.first,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: _departmanAyarlari.gorevBaslik,
                        ),
                        items: _departmanAyarlari.gorevSecenekleri.map((gorev) {
                          return DropdownMenuItem<String>(
                            value: gorev,
                            child: Text(gorev),
                          );
                        }).toList(),
                        onChanged: (deger) {
                          if (deger == null) return;
                          setDialogState(() => secilenGorev = deger);
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("İptal"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String sonuc = _departmanAyarlari.gorevSecenekleri.isEmpty
                        ? ctrl.text.trim()
                        : secilenGorev.trim();
                    Navigator.pop(context, sonuc);
                  },
                  child: const Text("Kaydet"),
                ),
              ],
            );
          },
        );
      },
    );

    if (yeniGorev == null) return;

    setState(() {
      personel.gorev = yeniGorev;
    });

    await _verileriBulutaKaydet();
  }

  void _paxBaslikDuzenle() {
    TextEditingController ctrl = TextEditingController(text: paxBaslik);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Alt Satır Başlığını Düzenle"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Örn: KAHVALTI SAYISI (PAX)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                paxBaslik = ctrl.text.trim().isEmpty
                    ? "KAHVALTI SAYISI (PAX)"
                    : ctrl.text.trim();
              });

              _verileriBulutaKaydet();
              Navigator.pop(ctx);
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  void _paxDegerGir(String gun) {
    TextEditingController ctrl = TextEditingController(text: paxVerileri[gun] ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$gun - $paxBaslik"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Sayı girin (Örn: 198)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (ctrl.text.trim().isEmpty) {
                  paxVerileri.remove(gun);
                } else {
                  paxVerileri[gun] = ctrl.text.trim();
                }
              });

              _verileriBulutaKaydet();
              Navigator.pop(ctx);
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }


  void _puantajEkraniniAc() {
    if (!_departmanAyarlari.puantajGoster) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bu departman için puantaj ekranı şu anda kapalı."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuantajEkrani(
          departmanAyarlari: _departmanAyarlari,
        ),
      ),
    );
  }

  Widget _buildSolMenu() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              color: Colors.blueGrey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_month, color: Colors.white, size: 30),
                      SizedBox(width: 10),
                      Text(
                        "Haftalık Kayıtlar",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _departmanAyarlari.departmanBasligi,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Aktif hafta",
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _aktifHaftaBaslik,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _kaydediliyor ? null : _aktifHaftayiManuelKaydet,
                      icon: _kaydediliyor
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save, color: Colors.white),
                      label: Text(
                        _kaydediliyor ? "Kaydediliyor..." : "Bu Haftayı Kaydet",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _haftayiTarihleAc(_aktifHaftaBaslangic.subtract(const Duration(days: 7)));
                          },
                          icon: const Icon(Icons.chevron_left),
                          label: const Text("Önceki"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _haftayiTarihleAc(_aktifHaftaBaslangic.add(const Duration(days: 7)));
                          },
                          icon: const Icon(Icons.chevron_right),
                          label: const Text("Sonraki"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _mevcutHaftayiSonrakiHaftayaKopyala();
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text("Bu Haftayı Sonraki Haftaya Kopyala"),
                    ),
                  ),
                  if (_departmanAyarlari.puantajGoster) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _puantajEkraniniAc();
                        },
                        icon: const Icon(Icons.receipt_long, color: Colors.white),
                        label: const Text(
                          "Puantaj Oluştur",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Kayıtlı Haftalar",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  IconButton(
                    tooltip: "Kayıtları yenile",
                    onPressed: _haftaKayitlariYukleniyor ? null : _haftaKayitlariniYenile,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _haftaKayitlariYukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : haftaKayitlari.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              "Henüz kayıtlı hafta yok.\nTabloyu hazırlayıp 'Bu Haftayı Kaydet' butonuna basın.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: haftaKayitlari.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final kayit = haftaKayitlari[index];
                            final bool aktif = kayit.id == _aktifHaftaId;
                            final String altYazi = [
                              "${kayit.personelSayisi} personel",
                              _sonGuncellemeYazisi(kayit.sonGuncelleme),
                            ].where((e) => e.trim().isNotEmpty).join(" • ");

                            return ListTile(
                              selected: aktif,
                              selectedTileColor: Colors.blueGrey.shade50,
                              leading: Icon(
                                aktif ? Icons.check_circle : Icons.folder_copy,
                                color: aktif ? Colors.green.shade600 : Colors.blueGrey,
                              ),
                              title: Text(
                                kayit.baslik,
                                style: TextStyle(
                                  fontWeight: aktif ? FontWeight.bold : FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(altYazi),
                              onTap: () {
                                Navigator.pop(context);
                                if (!aktif) _kayitliHaftayiAc(kayit);
                              },
                              trailing: PopupMenuButton<String>(
                                tooltip: "Hafta işlemleri",
                                onSelected: (deger) {
                                  if (deger == 'sil') {
                                    _haftaSilDialog(kayit);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem<String>(
                                    value: 'sil',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text("Sil"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildSolMenu(),
      appBar: AppBar(
        title: Text(_ekranBasligi),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: "Bu Haftayı Kaydet",
            onPressed: _kaydediliyor ? null : _aktifHaftayiManuelKaydet,
          ),
          if (_departmanAyarlari.puantajGoster)
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: "Puantaj Oluştur",
              onPressed: _puantajEkraniniAc,
            ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: "Tabloyu Paylaş",
            onPressed: () {
              if (personelListesi.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Paylaşacak kimse yok!"),
                  ),
                );
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaylasEkrani(
                    personelListesi: personelListesi,
                    paxBaslik: paxBaslik,
                    paxVerileri: paxVerileri,
                    gunTarihleri: Map<String, String>.from(_gunTarihleri),
                    haftalikBaslik: _ekranBasligi,
                    departmanAyarlari: _departmanAyarlari,
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : personelListesi.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_view_week, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        "$_aktifHaftaBaslik haftasında henüz personel yok.\nSağ alttaki butondan ekleyebilirsiniz.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (scaffoldContext) {
                          return TextButton.icon(
                            onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
                            icon: const Icon(Icons.menu),
                            label: const Text("Haftalık kayıtları aç"),
                          );
                        },
                      ),
                    ],
                  ),
                )
              : Center(
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  color: Colors.blueGrey.shade50,
                                  child: Row(
                                    children: [
                                      _buildHeaderCell(
                                        _departmanAyarlari.personelBaslik,
                                        personelHucreGenisligi,
                                      ),
                                      if (_departmanAyarlari.gorevSutunuGoster)
                                        _buildHeaderCell(
                                          _departmanAyarlari.gorevBaslik,
                                          gorevHucreGenisligi,
                                        ),
                                      ...gunler.map(
                                        (g) => _buildHeaderCell(
                                          g,
                                          gunHucreGenisligi,
                                          altMetin: _gunTarihleri[g],
                                        ),
                                      ),
                                      if (_departmanAyarlari.imzaSutunuGoster)
                                        _buildHeaderCell(
                                          "İMZA",
                                          imzaHucreGenisligi,
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: _tabloToplamGenisligi,
                                  height: 24.0,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDED9C4),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _departmanAyarlari.departmanBasligi,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                ...personelListesi.map((personel) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildPersonelNameCell(personel),
                                        if (_departmanAyarlari.gorevSutunuGoster)
                                          _buildGorevCell(personel),
                                        ...gunler.map(
                                          (gun) => _buildVardiyaCell(
                                            personel,
                                            gun,
                                          ),
                                        ),
                                        if (_departmanAyarlari.imzaSutunuGoster)
                                          _buildImzaCell(),
                                      ],
                                    ),
                                  );
                                }),
                                if (_departmanAyarlari.paxGoster) _buildPaxSatiri(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPersonelEkleDialog(
          context,
          _yeniPersonelEkle,
          departmanAyarlari: _departmanAyarlari,
          onPersonelEkleDetayli: _yeniPersonelEkleDetayli,
        ),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          "Personel Ekle",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blueGrey,
      ),
    );
  }

  Widget _buildPaxSatiri() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.blueGrey.shade300,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _paxBaslikDuzenle,
            child: Container(
              width: _solBilgiGenisligi,
              height: paxHucreYuksekligi,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(
                  right: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit,
                    size: 12,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      paxBaslik,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...gunler.map(
            (gun) => GestureDetector(
              onTap: () => _paxDegerGir(gun),
              child: Container(
                width: gunHucreGenisligi,
                height: paxHucreYuksekligi,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    right: BorderSide(
                      color: Colors.grey.shade300,
                    ),
                  ),
                ),
                child: Text(
                  paxVerileri[gun] ?? "-",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          if (_departmanAyarlari.imzaSutunuGoster)
            Container(
              width: imzaHucreGenisligi,
              height: paxHucreYuksekligi,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width, {String? altMetin}) {
    return Container(
      width: width,
      height: hucreYuksekligi,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (altMetin != null)
            Text(
              altMetin,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blueGrey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonelNameCell(Personel personel) {
    return Tooltip(
      message: "Silmek için basılı tut",
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _personelSilDialog(personel),
        child: Container(
          width: personelHucreGenisligi,
          height: hucreYuksekligi,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _departmanAyarlari.gorevSutunuGoster
                ? const Color(0xFFFAF7FF)
                : Colors.transparent,
            border: Border(
              right: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.person,
                size: 18,
                color: Colors.blueGrey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  personel.ad,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGorevCell(Personel personel) {
    return Tooltip(
      message: "Görevi düzenlemek için tıkla",
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _personelGorevDuzenle(personel),
        child: Container(
          width: gorevHucreGenisligi,
          height: hucreYuksekligi,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            border: Border(
              right: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Text(
            personel.gorev.trim().isEmpty ? "-" : personel.gorev,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildImzaCell() {
    return Container(
      width: imzaHucreGenisligi,
      height: hucreYuksekligi,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildVardiyaCell(Personel personel, String gun) {
    String durum = personel.haftalikShift[gun] ?? "Boş";
    Color hucreRengi = Colors.transparent;
    Color yaziRengi = Colors.black87;
    bool kalinYazi = false;

    final OzelDurumAyar? durumAyar = _ozelDurumAyariniBul(durum);

    if (durum == "Boş") {
      hucreRengi = Colors.transparent;
      yaziRengi = Colors.black87;
      kalinYazi = false;
    } else if (durumAyar != null) {
      hucreRengi = _hexRenk(durumAyar.arkaPlanHex, Colors.grey.shade200);
      yaziRengi = _hexRenk(durumAyar.yaziHex, Colors.black87);
      kalinYazi = durumAyar.kalin;
    } else {
      hucreRengi = Colors.white;
      yaziRengi = Colors.blueGrey.shade900;
      kalinYazi = true;
    }

    return GestureDetector(
      onTap: () {
        showShiftDialog(
          context,
          personel,
          gun,
          (secilenDurum, tumHaftayaUygula) {
            setState(() {
              if (tumHaftayaUygula) {
                for (String g in gunler) {
                  secilenDurum == "Boş"
                      ? personel.haftalikShift.remove(g)
                      : personel.haftalikShift[g] = secilenDurum;
                }
              } else {
                secilenDurum == "Boş"
                    ? personel.haftalikShift.remove(gun)
                    : personel.haftalikShift[gun] = secilenDurum;
              }
            });

            _verileriBulutaKaydet();
            Navigator.pop(context);
          },
          departmanAyarlari: _departmanAyarlari,
        );
      },
      child: Container(
        width: gunHucreGenisligi,
        height: hucreYuksekligi,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hucreRengi,
          border: Border(
            right: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Text(
          durum == "Boş" ? "-" : _durumEtiketi(durum),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: yaziRengi,
            fontWeight: kalinYazi ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  OzelDurumAyar? _ozelDurumAyariniBul(String kod) {
    for (final durum in _departmanAyarlari.ozelDurumlar) {
      if (durum.kod == kod) return durum;
    }
    return null;
  }

  String _durumEtiketi(String kod) {
    final OzelDurumAyar? durum = _ozelDurumAyariniBul(kod);
    return durum?.etiket ?? kod;
  }

  Color _hexRenk(String hex, Color varsayilan) {
    String temiz = hex.trim().replaceAll('#', '');

    if (temiz.length == 6) {
      temiz = 'FF$temiz';
    }

    if (temiz.length != 8) {
      return varsayilan;
    }

    final int? deger = int.tryParse(temiz, radix: 16);
    if (deger == null) return varsayilan;

    return Color(deger);
  }
}
