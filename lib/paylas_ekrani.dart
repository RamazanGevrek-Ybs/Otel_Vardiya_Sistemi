// paylas_ekrani.dart
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'departman_ayar_model.dart';
import 'personel_model.dart';

class PaylasEkrani extends StatefulWidget {
  final List<Personel> personelListesi;
  final String paxBaslik;
  final Map<String, String> paxVerileri;

  final Map<String, String>? gunTarihleri;
  final String? haftalikBaslik;
  final DepartmanAyarlari? departmanAyarlari;

  const PaylasEkrani({
    super.key,
    required this.personelListesi,
    required this.paxBaslik,
    required this.paxVerileri,
    this.gunTarihleri,
    this.haftalikBaslik,
    this.departmanAyarlari,
  });

  @override
  State<PaylasEkrani> createState() => _PaylasEkraniState();
}

class _PaylasEkraniState extends State<PaylasEkrani> {
  final List<String> gunler = [
    "Pazartesi",
    "Salı",
    "Çarşamba",
    "Perşembe",
    "Cuma",
    "Cumartesi",
    "Pazar",
  ];

  final double personelHucreGenisligi = 180.0;
  final double gorevHucreGenisligi = 100.0;
  final double gunHucreGenisligi = 130.0;
  final double imzaHucreGenisligi = 85.0;

  final double hucreYuksekligi = 60.0;
  final double paxHucreYuksekligi = 24.0;
  final double departmanSeridiYuksekligi = 24.0;

  final GlobalKey _tabloKey = GlobalKey();

  bool _indiriliyor = false;
  bool _yazdiriliyor = false;

  final Map<String, String> _gunTarihleri = {};

  DepartmanAyarlari get ayarlar {
    return widget.departmanAyarlari ?? DepartmanAyarlari.varsayilan();
  }

  bool get _gorevGoster => ayarlar.gorevSutunuGoster;
  bool get _imzaGoster => ayarlar.imzaSutunuGoster;
  bool get _paxGoster => ayarlar.paxGoster;

  double get _solTarafGenisligi {
    return personelHucreGenisligi + (_gorevGoster ? gorevHucreGenisligi : 0);
  }

  double get _tabloGenisligi {
    return personelHucreGenisligi +
        (_gorevGoster ? gorevHucreGenisligi : 0) +
        (gunHucreGenisligi * 7) +
        (_imzaGoster ? imzaHucreGenisligi : 0);
  }

  @override
  void initState() {
    super.initState();
    _tarihleriHazirla();
  }

  String _ikiHane(int sayi) => sayi.toString().padLeft(2, '0');

  String _tarihKisa(DateTime tarih) {
    return "${_ikiHane(tarih.day)}.${_ikiHane(tarih.month)}";
  }

  void _tarihleriHazirla() {
    _gunTarihleri.clear();

    if (widget.gunTarihleri != null && widget.gunTarihleri!.isNotEmpty) {
      _gunTarihleri.addAll(widget.gunTarihleri!);
      return;
    }

    DateTime bugun = DateTime.now();
    DateTime baslangicPazartesi = (bugun.weekday >= 5)
        ? bugun.add(Duration(days: 8 - bugun.weekday))
        : bugun.subtract(Duration(days: bugun.weekday - 1));

    for (int i = 0; i < 7; i++) {
      DateTime gunTarihi = baslangicPazartesi.add(Duration(days: i));
      _gunTarihleri[gunler[i]] = _tarihKisa(gunTarihi);
    }
  }

  String get _haftalikBaslik {
    if (widget.haftalikBaslik != null &&
        widget.haftalikBaslik!.trim().isNotEmpty) {
      return widget.haftalikBaslik!;
    }

    return "Haftalık Shift Programı (${_gunTarihleri['Pazartesi']} - ${_gunTarihleri['Pazar']})";
  }

  String get _paxBaslik {
    if (widget.paxBaslik.trim().isNotEmpty) {
      return widget.paxBaslik.trim();
    }

    if (ayarlar.paxBaslik.trim().isNotEmpty) {
      return ayarlar.paxBaslik.trim();
    }

    return "KAHVALTI SAYISI (PAX)";
  }

  String _dosyaAdiOlustur() {
    final String baslangic =
        (_gunTarihleri['Pazartesi'] ?? "Hafta").replaceAll('.', '-');
    final String bitis = (_gunTarihleri['Pazar'] ?? "").replaceAll('.', '-');

    return "Shift_${baslangic}_$bitis.png";
  }

  Future<Uint8List?> _tabloyuPngOlarakAl() async {
    try {
      await Future.delayed(const Duration(milliseconds: 250));

      final BuildContext? tabloContext = _tabloKey.currentContext;
      if (tabloContext == null) return null;

      final RenderObject? renderObject = tabloContext.findRenderObject();

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
      debugPrint("Tablo görseli hazırlanamadı: $e");
      return null;
    }
  }

  void _pngBytesIndir(Uint8List pngBytes) {
    final html.Blob blob = html.Blob([pngBytes], 'image/png');
    final String url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute("download", _dosyaAdiOlustur())
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  Future<void> _resimOlarakIndir() async {
    setState(() => _indiriliyor = true);

    try {
      final Uint8List? pngBytes = await _tabloyuPngOlarakAl();

      if (pngBytes == null) {
        _mesajGoster(
          "Tablo resmi oluşturulamadı.",
          hata: true,
        );
        return;
      }

      _pngBytesIndir(pngBytes);
    } catch (e) {
      debugPrint("İndirme hatası: $e");

      _mesajGoster(
        "Resim indirilirken hata oluştu.",
        hata: true,
      );
    } finally {
      if (mounted) {
        setState(() => _indiriliyor = false);
      }
    }
  }

  Future<void> _yazdir() async {
    setState(() => _yazdiriliyor = true);

    try {
      final Uint8List? pngBytes = await _tabloyuPngOlarakAl();

      if (pngBytes == null) {
        _mesajGoster(
          "Yazdırılacak tablo resmi oluşturulamadı.",
          hata: true,
        );
        return;
      }

      final String base64Image = base64Encode(pngBytes);
      final String baslikEscaped = htmlEscape.convert(_haftalikBaslik);

      final String yazdirmaHtml = """
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>$baslikEscaped</title>
  <style>
    @page {
      size: A4 landscape;
      margin: 10mm;
    }

    html, body {
      margin: 0;
      padding: 0;
      background: white;
      font-family: Arial, sans-serif;
    }

    .page {
      width: 100%;
      box-sizing: border-box;
      padding: 0;
    }

    img {
      width: 100%;
      height: auto;
      display: block;
    }

    @media print {
      body {
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
    }
  </style>
</head>
<body>
  <div class="page">
    <img
      src="data:image/png;base64,$base64Image"
      onload="setTimeout(function(){ window.focus(); window.print(); }, 350);"
    />
  </div>
</body>
</html>
""";

      final html.Blob blob = html.Blob(
        [yazdirmaHtml],
        'text/html;charset=utf-8',
      );

      final String url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, "_blank");

      Future.delayed(const Duration(seconds: 30), () {
        html.Url.revokeObjectUrl(url);
      });
    } catch (e) {
      debugPrint("Yazdırma hatası: $e");

      _mesajGoster(
        "Yazdırma ekranı açılamadı.",
        hata: true,
      );
    } finally {
      if (mounted) {
        setState(() => _yazdiriliyor = false);
      }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tablo Önizleme'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: RepaintBoundary(
                key: _tabloKey,
                child: Container(
                  color: Colors.blueGrey.shade50,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _haftalikBaslik,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Container(
                              color: Colors.blueGrey.shade50,
                              child: Row(
                                children: [
                                  _buildHeaderCell(
                                    ayarlar.personelBaslik,
                                    personelHucreGenisligi,
                                  ),
                                  if (_gorevGoster)
                                    _buildHeaderCell(
                                      ayarlar.gorevBaslik,
                                      gorevHucreGenisligi,
                                    ),
                                  ...gunler.map(
                                    (g) => _buildHeaderCell(
                                      g,
                                      gunHucreGenisligi,
                                      altMetin: _gunTarihleri[g],
                                    ),
                                  ),
                                  if (_imzaGoster)
                                    _buildHeaderCell(
                                      "İMZA",
                                      imzaHucreGenisligi,
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              width: _tabloGenisligi,
                              height: departmanSeridiYuksekligi,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDED9C4),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              child: Text(
                                ayarlar.departmanBasligi,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            ...widget.personelListesi.map(
                              (p) => Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildPersonelNameCell(p),
                                    if (_gorevGoster) _buildGorevCell(p),
                                    ...gunler.map(
                                      (g) => _buildVardiyaCell(p, g),
                                    ),
                                    if (_imzaGoster) _buildImzaCell(),
                                  ],
                                ),
                              ),
                            ),
                            if (_paxGoster) _buildPaxSatiri(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildIslemButonlari(),
    );
  }

  Widget _buildIslemButonlari() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: "yazdir_btn",
          onPressed: _yazdiriliyor ? null : _yazdir,
          icon: _yazdiriliyor
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.print),
          label: Text(_yazdiriliyor ? "Hazırlanıyor..." : "Yazdır"),
          backgroundColor: Colors.indigo,
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: "indir_btn",
          onPressed: _indiriliyor ? null : _resimOlarakIndir,
          icon: _indiriliyor
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.download),
          label: Text(_indiriliyor ? "İndiriliyor..." : "Resim Olarak İndir"),
          backgroundColor: Colors.green,
        ),
      ],
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
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blueGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonelNameCell(Personel p) {
    return Container(
      width: personelHucreGenisligi,
      height: hucreYuksekligi,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
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
              p.ad,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGorevCell(Personel p) {
    return Container(
      width: gorevHucreGenisligi,
      height: hucreYuksekligi,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Text(
        p.gorev.trim().isEmpty ? "-" : p.gorev.trim(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }

  Widget _buildImzaCell() {
    return Container(
      width: imzaHucreGenisligi,
      height: hucreYuksekligi,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildPaxSatiri() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade400,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: _solTarafGenisligi,
            height: paxHucreYuksekligi,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              _paxBaslik,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.black54,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...gunler.map(
            (gun) => Container(
              width: gunHucreGenisligi,
              height: paxHucreYuksekligi,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Text(
                widget.paxVerileri[gun] ?? "-",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          if (_imzaGoster)
            Container(
              width: imzaHucreGenisligi,
              height: paxHucreYuksekligi,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVardiyaCell(Personel p, String gun) {
    final String durum = p.haftalikShift[gun] ?? "Boş";
    final _DurumStili stil = _durumStiliBul(durum);

    return Container(
      width: gunHucreGenisligi,
      height: hucreYuksekligi,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: stil.arkaPlan,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Text(
        durum == "Boş" ? "-" : stil.etiket,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: stil.yaziRengi,
          fontWeight: stil.kalin ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }

  _DurumStili _durumStiliBul(String durum) {
    if (durum == "Boş") {
      return const _DurumStili(
        etiket: "-",
        arkaPlan: Colors.transparent,
        yaziRengi: Colors.black87,
        kalin: false,
      );
    }

    for (final OzelDurumAyar ozelDurum in ayarlar.ozelDurumlar) {
      if (ozelDurum.kod == durum || ozelDurum.etiket == durum) {
        return _DurumStili(
          etiket: ozelDurum.etiket,
          arkaPlan: _hexRenk(ozelDurum.arkaPlanHex, Colors.white),
          yaziRengi: _hexRenk(ozelDurum.yaziHex, Colors.black87),
          kalin: ozelDurum.kalin,
        );
      }
    }

    return _DurumStili(
      etiket: durum,
      arkaPlan: Colors.white,
      yaziRengi: Colors.black87,
      kalin: true,
    );
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

class _DurumStili {
  final String etiket;
  final Color arkaPlan;
  final Color yaziRengi;
  final bool kalin;

  const _DurumStili({
    required this.etiket,
    required this.arkaPlan,
    required this.yaziRengi,
    required this.kalin,
  });
}