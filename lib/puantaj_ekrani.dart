// puantaj_ekrani.dart
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'departman_ayar_model.dart';
import 'personel_model.dart';
import 'puantaj_model.dart';

class PuantajEkrani extends StatefulWidget {
  final DepartmanAyarlari? departmanAyarlari;

  const PuantajEkrani({
    super.key,
    this.departmanAyarlari,
  });

  @override
  State<PuantajEkrani> createState() => _PuantajEkraniState();
}

class _PuantajEkraniState extends State<PuantajEkrani> {
  final GlobalKey _puantajKey = GlobalKey();

  final List<String> gunler = const [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  final List<String> ayAdlari = const [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  final double siraNoGenisligi = 58;
  final double isimGenisligi = 180;
  final double imzaGenisligi = 95;
  final double gunGenisligi = 24;
  final double toplamGenisligi = 26;
  final double ekToplamGenisligi = 34;

  static const List<_EkToplamKolonu> _ekToplamKolonlari = [
    _EkToplamKolonu(
      kod: 'SSK',
      baslik: 'SSK GÜNÜ',
    ),
    _EkToplamKolonu(
      kod: 'RT72',
      baslik: '72-RESMİ TATİL MESAİSİ',
    ),
    _EkToplamKolonu(
      kod: 'NM',
      baslik: 'NORMAL MESAİ (HAFTA İÇİ)',
    ),
  ];

  late int secilenAy;
  late int secilenYil;

  bool yukleniyor = false;
  bool indiriliyor = false;
  bool yazdiriliyor = false;

  PuantajAySonucu? sonuc;

  DepartmanAyarlari get ayarlar {
    return widget.departmanAyarlari ?? DepartmanAyarlari.foodBeverage();
  }

  @override
  void initState() {
    super.initState();

    final DateTime simdi = DateTime.now();
    secilenAy = simdi.month;
    secilenYil = simdi.year;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _puantajOlustur();
    });
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

  DateTime? _haftaBaslangiciniBul(String docId, Map<String, dynamic> data) {
    final DateTime? datadan = _tarihUzunCoz(
      data['baslangic_tarihi']?.toString(),
    );

    if (datadan != null) return datadan;

    final List<String> idParcalari = docId.split('_');
    if (idParcalari.isEmpty) return null;

    return _tarihUzunCoz(idParcalari.first);
  }

  String _personelAnahtari(Personel personel) {
    String ad = personel.ad.trim().toLowerCase();

    ad = ad
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');

    ad = ad.replaceAll(RegExp(r'\s+'), ' ');
    return ad;
  }

  String _dosyaAdi() {
    return 'Puantaj_${ayAdlari[secilenAy - 1]}_$secilenYil.png';
  }

  Future<void> _puantajOlustur() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _mesajGoster(
        'Oturum bulunamadı. Lütfen tekrar giriş yapın.',
        hata: true,
      );
      return;
    }

    if (!ayarlar.puantajGoster) {
      setState(() {
        sonuc = PuantajAySonucu(
          yil: secilenYil,
          ay: secilenAy,
          satirlar: const [],
        );
      });

      _mesajGoster(
        'Bu departman için puantaj ekranı şu anda kapalı.',
        hata: true,
      );
      return;
    }

    setState(() => yukleniyor = true);

    try {
      final DateTime ayBaslangic = DateTime(secilenYil, secilenAy, 1);
      final DateTime ayBitis = DateTime(secilenYil, secilenAy + 1, 0);
      final int ayGunSayisi = ayBitis.day;

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('shift_verileri')
              .doc(user.uid)
              .collection('haftalar')
              .get();

      final List<_HaftaKaydi> haftalar = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final DateTime? haftaBaslangic = _haftaBaslangiciniBul(doc.id, data);

        if (haftaBaslangic == null) continue;

        final DateTime haftaBitis = haftaBaslangic.add(
          const Duration(days: 6),
        );

        final bool aylaKesisiyor =
            !haftaBitis.isBefore(ayBaslangic) &&
            !haftaBaslangic.isAfter(ayBitis);

        if (!aylaKesisiyor) continue;

        final dynamic veri = data['veri'];
        if (veri is! String || veri.trim().isEmpty) continue;

        final List<Personel> personeller = Personel.decode(veri);

        haftalar.add(
          _HaftaKaydi(
            baslangic: haftaBaslangic,
            personeller: personeller,
          ),
        );
      }

      haftalar.sort((a, b) => a.baslangic.compareTo(b.baslangic));

      final Map<String, _PuantajToplayici> toplayicilar = {};
      int siralamaSayaci = 0;

      for (final _HaftaKaydi hafta in haftalar) {
        for (final Personel personel in hafta.personeller) {
          final String anahtar = _personelAnahtari(personel);
          if (anahtar.trim().isEmpty) continue;

          final _PuantajToplayici toplayici = toplayicilar.putIfAbsent(
            anahtar,
            () {
              siralamaSayaci++;

              return _PuantajToplayici(
                personelAnahtari: anahtar,
                personel: personel,
                ayGunSayisi: ayGunSayisi,
                siralama: siralamaSayaci,
              );
            },
          );

          for (int i = 0; i < 7; i++) {
            final DateTime tarih = hafta.baslangic.add(Duration(days: i));

            if (tarih.year != secilenYil || tarih.month != secilenAy) {
              continue;
            }

            final String gunAdi = gunler[i];
            final String durum = personel.haftalikShift[gunAdi] ?? 'Boş';
            final String puantajKodu = ayarlar.puantajKodunaCevir(durum).trim();

            if (puantajKodu.isEmpty) continue;

            toplayici.gunKodlari[tarih.day] = puantajKodu;
          }
        }
      }

      final List<PuantajPersonelSatiri> satirlar =
          toplayicilar.values.map((toplayici) {
        final Map<String, int> toplamlar = {
          for (final PuantajKolonAyar kolon in ayarlar.puantajKolonlari)
            kolon.kod: 0,
        };

        int sskGunu = 0;

        for (int gun = 1; gun <= ayGunSayisi; gun++) {
          final String kod = toplayici.gunKodlari[gun] ?? '';

          if (kod.trim().isEmpty) continue;

          sskGunu++;
          toplamlar[kod] = (toplamlar[kod] ?? 0) + 1;
        }

        return PuantajPersonelSatiri(
          personelAnahtari: toplayici.personelAnahtari,
          personel: toplayici.personel,
          gunKodlari: Map<int, String>.from(toplayici.gunKodlari),
          toplamlar: toplamlar,
          sskGunu: sskGunu,
          ayGunu: ayGunSayisi,
        );
      }).toList();

      satirlar.sort((a, b) {
        final int aSira = toplayicilar[a.personelAnahtari]?.siralama ?? 999999;
        final int bSira = toplayicilar[b.personelAnahtari]?.siralama ?? 999999;

        return aSira.compareTo(bSira);
      });

      if (!mounted) return;

      setState(() {
        sonuc = PuantajAySonucu(
          yil: secilenYil,
          ay: secilenAy,
          satirlar: satirlar,
        );
      });

      if (satirlar.isEmpty) {
        _mesajGoster(
          '${ayAdlari[secilenAy - 1]} $secilenYil için kayıtlı shift bulunamadı.',
          hata: true,
        );
      }
    } catch (e) {
      debugPrint('Puantaj oluşturma hatası: $e');

      _mesajGoster(
        'Puantaj oluşturulurken hata oluştu: $e',
        hata: true,
      );
    } finally {
      if (mounted) setState(() => yukleniyor = false);
    }
  }

  Future<Uint8List?> _puantajiPngOlarakAl() async {
    try {
      await Future.delayed(const Duration(milliseconds: 250));

      final BuildContext? puantajContext = _puantajKey.currentContext;
      if (puantajContext == null) return null;

      final RenderObject? renderObject = puantajContext.findRenderObject();

      if (renderObject == null || renderObject is! RenderRepaintBoundary) {
        return null;
      }

      final ui.Image image = await renderObject.toImage(pixelRatio: 2.5);

      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) return null;

      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Puantaj görseli hazırlanamadı: $e');
      return null;
    }
  }

  void _pngIndir(Uint8List pngBytes) {
    final html.Blob blob = html.Blob([pngBytes], 'image/png');
    final String url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', _dosyaAdi())
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  Future<void> _resimOlarakIndir() async {
    setState(() => indiriliyor = true);

    try {
      final Uint8List? pngBytes = await _puantajiPngOlarakAl();

      if (pngBytes == null) {
        _mesajGoster(
          'Puantaj görseli oluşturulamadı.',
          hata: true,
        );
        return;
      }

      _pngIndir(pngBytes);
    } catch (e) {
      debugPrint('Puantaj indirme hatası: $e');

      _mesajGoster(
        'Puantaj indirilirken hata oluştu.',
        hata: true,
      );
    } finally {
      if (mounted) setState(() => indiriliyor = false);
    }
  }

  Future<void> _yazdir() async {
    setState(() => yazdiriliyor = true);

    try {
      final Uint8List? pngBytes = await _puantajiPngOlarakAl();

      if (pngBytes == null) {
        _mesajGoster(
          'Yazdırılacak puantaj görseli oluşturulamadı.',
          hata: true,
        );
        return;
      }

      final String base64Image = base64Encode(pngBytes);
      final String baslik = htmlEscape.convert(
        '${ayAdlari[secilenAy - 1]} $secilenYil Puantaj',
      );

      final String yazdirmaHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>$baslik</title>
  <style>
    @page { size: A4 landscape; margin: 4mm; }
    html, body { margin: 0; padding: 0; background: white; font-family: Arial, sans-serif; }
    img { width: 100%; height: auto; display: block; }
    @media print { body { -webkit-print-color-adjust: exact; print-color-adjust: exact; } }
  </style>
</head>
<body>
  <img src="data:image/png;base64,$base64Image" onload="setTimeout(function(){ window.focus(); window.print(); }, 350);" />
</body>
</html>
''';

      final html.Blob blob = html.Blob(
        [yazdirmaHtml],
        'text/html;charset=utf-8',
      );

      final String url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');

      Future.delayed(const Duration(seconds: 30), () {
        html.Url.revokeObjectUrl(url);
      });
    } catch (e) {
      debugPrint('Puantaj yazdırma hatası: $e');

      _mesajGoster(
        'Yazdırma ekranı açılamadı.',
        hata: true,
      );
    } finally {
      if (mounted) setState(() => yazdiriliyor = false);
    }
  }

  void _mesajGoster(String mesaj, {bool hata = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: hata ? Colors.redAccent : Colors.blueGrey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int mevcutYil = DateTime.now().year;

    final List<int> yillar = List<int>.generate(
      5,
      (index) => mevcutYil - 2 + index,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puantaj Oluştur'),
      ),
      body: Column(
        children: [
          _buildKontrolPaneli(yillar),
          const Divider(height: 1),
          Expanded(
            child: yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : sonuc == null
                    ? const Center(
                        child: Text(
                          'Puantaj oluşturmak için ay/yıl seçip butona basın.',
                        ),
                      )
                    : sonuc!.bosMu
                        ? _buildBosDurum()
                        : _buildPuantajOnizleme(sonuc!),
          ),
        ],
      ),
      floatingActionButton:
          sonuc == null || sonuc!.bosMu ? null : _buildIslemButonlari(),
    );
  }

  Widget _buildKontrolPaneli(List<int> yillar) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int>(
              value: secilenAy,
              decoration: const InputDecoration(
                labelText: 'Ay',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: List<int>.generate(12, (index) => index + 1).map((ay) {
                return DropdownMenuItem<int>(
                  value: ay,
                  child: Text(ayAdlari[ay - 1]),
                );
              }).toList(),
              onChanged: (deger) {
                if (deger == null) return;
                setState(() => secilenAy = deger);
              },
            ),
          ),
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<int>(
              value: yillar.contains(secilenYil)
                  ? secilenYil
                  : DateTime.now().year,
              decoration: const InputDecoration(
                labelText: 'Yıl',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: yillar.map((yil) {
                return DropdownMenuItem<int>(
                  value: yil,
                  child: Text(yil.toString()),
                );
              }).toList(),
              onChanged: (deger) {
                if (deger == null) return;
                setState(() => secilenYil = deger);
              },
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
            onPressed: yukleniyor ? null : _puantajOlustur,
            icon: const Icon(Icons.calculate),
            label: const Text('Puantaj Oluştur'),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueGrey.shade100),
            ),
            child: Text(
              ayarlar.puantajBasligi,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBosDurum() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              '${ayAdlari[secilenAy - 1]} $secilenYil için puantaj verisi bulunamadı.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu ayın haftalık shiftlerini kaydettiğinizden emin olun.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuantajOnizleme(PuantajAySonucu sonuc) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: RepaintBoundary(
            key: _puantajKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPuantajBaslik(sonuc),
                  const SizedBox(height: 4),
                  _buildUstKodSeridi(sonuc),
                  const SizedBox(height: 5),
                  _buildPuantajTablosu(sonuc),
                  const SizedBox(height: 5),
                  _buildAltAciklamalar(sonuc),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPuantajBaslik(PuantajAySonucu sonuc) {
    return SizedBox(
      width: _tabloToplamGenisligi(sonuc),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '${ayarlar.puantajBasligi} ${ayAdlari[sonuc.ay - 1].toUpperCase()} ${sonuc.yil}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const Text(
            'SIGNATURE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUstKodSeridi(PuantajAySonucu sonuc) {
    return SizedBox(
      width: _tabloToplamGenisligi(sonuc),
      height: 30,
      child: Row(
        children: [
          _legendMiniCell(
            kod: 'X',
            aciklama: 'Normal Çalışma',
            width: 122,
            arkaPlan: Colors.white,
            yaziRengi: Colors.black87,
          ),
          ...ayarlar.ozelDurumlar.map((durum) {
            final String kod = durum.puantajKodu.trim().isEmpty
                ? durum.etiket
                : durum.puantajKodu;

            return _legendMiniCell(
              kod: kod,
              aciklama: durum.etiket,
              width: _legendGenisligi(kod),
              arkaPlan: _hexRenk(durum.arkaPlanHex, Colors.white),
              yaziRengi: _hexRenk(durum.yaziHex, Colors.black87),
            );
          }),
          const Spacer(),
        ],
      ),
    );
  }

  double _legendGenisligi(String kod) {
    switch (kod) {
      case 'OFF':
        return 76;
      case 'H':
        return 92;
      case 'Y':
        return 88;
      case 'P':
        return 88;
      case 'S':
        return 78;
      case 'R':
        return 86;
      case 'A':
        return 86;
      case 'M':
        return 74;
      case 'F':
        return 92;
      case 'O':
        return 112;
      default:
        return 82;
    }
  }

  Widget _legendMiniCell({
    required String kod,
    required String aciklama,
    required double width,
    required Color arkaPlan,
    required Color yaziRengi,
  }) {
    return Container(
      width: width,
      height: 28,
      alignment: Alignment.center,
      margin: const EdgeInsets.only(right: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: arkaPlan,
        border: Border.all(color: Colors.black87, width: 0.65),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '($kod) $aciklama',
          maxLines: 1,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: yaziRengi,
          ),
        ),
      ),
    );
  }

  Widget _buildPuantajTablosu(PuantajAySonucu sonuc) {
    final List<TableRow> satirlar = [];

    satirlar.add(_buildHeaderSatiri(sonuc));

    for (int i = 0; i < sonuc.satirlar.length; i++) {
      satirlar.add(
        _buildPersonelSatiri(i + 1, sonuc.satirlar[i], sonuc),
      );
    }

    final int bosSatirSayisi =
        sonuc.satirlar.length < 16 ? 16 - sonuc.satirlar.length : 0;

    for (int i = 0; i < bosSatirSayisi; i++) {
      satirlar.add(_buildBosSatir(sonuc));
    }

    return Table(
      columnWidths: _kolonGenislikleri(sonuc),
      border: TableBorder.all(
        color: Colors.black87,
        width: 0.65,
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: satirlar,
    );
  }

  Map<int, TableColumnWidth> _kolonGenislikleri(PuantajAySonucu sonuc) {
    final Map<int, TableColumnWidth> genislikler = {};
    int index = 0;

    genislikler[index++] = FixedColumnWidth(siraNoGenisligi);
    genislikler[index++] = FixedColumnWidth(isimGenisligi);
    genislikler[index++] = FixedColumnWidth(imzaGenisligi);

    for (int i = 0; i < sonuc.ayGunSayisi; i++) {
      genislikler[index++] = FixedColumnWidth(gunGenisligi);
    }

    for (int i = 0; i < ayarlar.puantajKolonlari.length; i++) {
      genislikler[index++] = FixedColumnWidth(toplamGenisligi);
    }

    for (int i = 0; i < _ekToplamKolonlari.length; i++) {
      genislikler[index++] = FixedColumnWidth(ekToplamGenisligi);
    }

    return genislikler;
  }

  TableRow _buildHeaderSatiri(PuantajAySonucu sonuc) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.green.shade100),
      children: [
        _normalHeaderCell(
          'BORAX\nSIRA NO',
          height: 78,
          fontSize: 8,
        ),
        _normalHeaderCell(
          'ADMINISTRATION',
          height: 78,
          fontSize: 9,
        ),
        _normalHeaderCell(
          'SIGNATURE',
          height: 78,
          fontSize: 9,
        ),
        ...List<int>.generate(sonuc.ayGunSayisi, (index) => index + 1).map(
          (gun) => _normalHeaderCell(
            gun.toString(),
            height: 78,
            fontSize: 9,
          ),
        ),
        ...ayarlar.puantajKolonlari.map(
          (kolon) => _verticalHeaderCell(
            _puantajKolonBasligi(kolon),
            height: 78,
          ),
        ),
        ..._ekToplamKolonlari.map(
          (kolon) => _verticalHeaderCell(
            kolon.baslik,
            height: 78,
            renk: kolon.kod == 'SSK'
                ? Colors.black87
                : kolon.kod == 'RT72'
                    ? Colors.blue.shade900
                    : Colors.red.shade700,
          ),
        ),
      ],
    );
  }

  String _puantajKolonBasligi(PuantajKolonAyar kolon) {
    return '(${kolon.kod}) ${kolon.aciklama}';
  }

  Widget _normalHeaderCell(
    String text, {
    required double height,
    double fontSize = 9,
    Color? color,
  }) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }

  Widget _verticalHeaderCell(
    String text, {
    required double height,
    Color? renk,
  }) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(1),
      child: RotatedBox(
        quarterTurns: 3,
        child: SizedBox(
          width: height - 4,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: renk ?? Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableRow _buildPersonelSatiri(
    int sira,
    PuantajPersonelSatiri satir,
    PuantajAySonucu sonuc,
  ) {
    return TableRow(
      children: [
        _cell(
          sira.toString(),
          height: 24,
          fontSize: 8,
        ),
        _cell(
          satir.personel.ad.toUpperCase(),
          height: 24,
          bold: true,
          alignLeft: true,
          fontSize: 8.5,
        ),
        _cell('', height: 24, fontSize: 8),
        ...List<int>.generate(sonuc.ayGunSayisi, (index) => index + 1).map(
          (gun) {
            final String kod = satir.gunKodu(gun);

            return _cell(
              kod,
              height: 24,
              bold: kod.isNotEmpty,
              fontSize: 8,
              backgroundColor: _kodArkaPlanRengi(kod),
              color: _kodYaziRengi(kod),
            );
          },
        ),
        ...ayarlar.puantajKolonlari.map((kolon) {
          return _cell(
            satir.toplam(kolon.kod).toString(),
            height: 24,
            fontSize: 8,
          );
        }),
        ..._ekToplamKolonlari.map((kolon) {
          return _cell(
            _ekToplamDegeri(kolon, satir),
            height: 24,
            bold: kolon.kod == 'SSK',
            fontSize: 8,
            color: kolon.kod == 'SSK'
                ? Colors.black87
                : kolon.kod == 'RT72'
                    ? Colors.blue.shade900
                    : Colors.red.shade700,
          );
        }),
      ],
    );
  }

  String _ekToplamDegeri(
    _EkToplamKolonu kolon,
    PuantajPersonelSatiri satir,
  ) {
    switch (kolon.kod) {
      case 'SSK':
        return satir.sskGunu.toString();

      case 'RT72':
        return '0';

      case 'NM':
        return '0';

      default:
        return '0';
    }
  }

  TableRow _buildBosSatir(PuantajAySonucu sonuc) {
    return TableRow(
      children: [
        _cell('', height: 22),
        _cell('', height: 22),
        _cell('', height: 22),
        ...List<Widget>.generate(
          sonuc.ayGunSayisi,
          (_) => _cell('', height: 22),
        ),
        ...ayarlar.puantajKolonlari.map(
          (_) => _cell('0', height: 22, fontSize: 8),
        ),
        ..._ekToplamKolonlari.map(
          (_) => _cell('0', height: 22, fontSize: 8),
        ),
      ],
    );
  }

  Widget _cell(
    String text, {
    required double height,
    bool bold = false,
    bool alignLeft = false,
    double fontSize = 9,
    Color? backgroundColor,
    Color? color,
  }) {
    final TextStyle style = TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: color ?? Colors.black87,
    );

    return Container(
      height: height,
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: alignLeft ? 4 : 1),
      color: backgroundColor,
      child: alignLeft
          ? FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                maxLines: 1,
                style: style,
              ),
            )
          : Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
    );
  }

  Widget _buildAltAciklamalar(PuantajAySonucu sonuc) {
    return SizedBox(
      width: _tabloToplamGenisligi(sonuc),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black87, width: 0.7),
            ),
            child: const Text(
              'AÇIKLAMALAR',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              const Text(
                '(X) Normal Çalışma',
                style: TextStyle(fontSize: 9),
              ),
              ...ayarlar.puantajKolonlari
                  .where((kolon) => kolon.kod != 'X')
                  .map((kolon) {
                return Text(
                  '(${kolon.kod}) ${kolon.aciklama}',
                  style: const TextStyle(fontSize: 9),
                );
              }),
              const Text(
                'SSK Günü',
                style: TextStyle(fontSize: 9),
              ),
              const Text(
                '72-Resmi Tatil Mesaisi',
                style: TextStyle(fontSize: 9),
              ),
              const Text(
                'Normal Mesai (Hafta İçi)',
                style: TextStyle(fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIslemButonlari() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'puantaj_yazdir_btn',
          onPressed: yazdiriliyor ? null : _yazdir,
          icon: yazdiriliyor
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.print),
          label: Text(yazdiriliyor ? 'Hazırlanıyor...' : 'Yazdır'),
          backgroundColor: Colors.indigo,
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: 'puantaj_indir_btn',
          onPressed: indiriliyor ? null : _resimOlarakIndir,
          icon: indiriliyor
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.download),
          label: Text(indiriliyor ? 'İndiriliyor...' : 'Resim Olarak İndir'),
          backgroundColor: Colors.green,
        ),
      ],
    );
  }

  double _tabloToplamGenisligi(PuantajAySonucu sonuc) {
    return siraNoGenisligi +
        isimGenisligi +
        imzaGenisligi +
        (sonuc.ayGunSayisi * gunGenisligi) +
        (ayarlar.puantajKolonlari.length * toplamGenisligi) +
        (_ekToplamKolonlari.length * ekToplamGenisligi);
  }

  Color _kodArkaPlanRengi(String kod) {
    final String temiz = kod.trim();

    if (temiz.isEmpty || temiz == 'X') {
      return Colors.white;
    }

    for (final OzelDurumAyar durum in ayarlar.ozelDurumlar) {
      final String puantajKodu = durum.puantajKodu.trim().isEmpty
          ? durum.kod
          : durum.puantajKodu;

      if (puantajKodu == temiz ||
          durum.kod == temiz ||
          durum.etiket == temiz) {
        return _hexRenk(durum.arkaPlanHex, Colors.white);
      }
    }

    return Colors.white;
  }

  Color _kodYaziRengi(String kod) {
    final String temiz = kod.trim();

    if (temiz.isEmpty) {
      return Colors.black87;
    }

    for (final OzelDurumAyar durum in ayarlar.ozelDurumlar) {
      final String puantajKodu = durum.puantajKodu.trim().isEmpty
          ? durum.kod
          : durum.puantajKodu;

      if (puantajKodu == temiz ||
          durum.kod == temiz ||
          durum.etiket == temiz) {
        return _hexRenk(durum.yaziHex, Colors.black87);
      }
    }

    return Colors.black87;
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

    if (deger == null) {
      return varsayilan;
    }

    return Color(deger);
  }
}

class _HaftaKaydi {
  final DateTime baslangic;
  final List<Personel> personeller;

  const _HaftaKaydi({
    required this.baslangic,
    required this.personeller,
  });
}

class _PuantajToplayici {
  final String personelAnahtari;
  final Personel personel;
  final int ayGunSayisi;
  final int siralama;
  final Map<int, String> gunKodlari = {};

  _PuantajToplayici({
    required this.personelAnahtari,
    required this.personel,
    required this.ayGunSayisi,
    required this.siralama,
  });
}

class _EkToplamKolonu {
  final String kod;
  final String baslik;

  const _EkToplamKolonu({
    required this.kod,
    required this.baslik,
  });
}