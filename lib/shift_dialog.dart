// shift_dialog.dart
import 'package:flutter/material.dart';

import 'departman_ayar_model.dart';
import 'personel_model.dart';

void showShiftDialog(
  BuildContext context,
  Personel personel,
  String secilenGun,
  Function(String yeniDurum, bool tumHaftayaUygula) onKaydet, {
  DepartmanAyarlari? departmanAyarlari,
}) {
  final DepartmanAyarlari ayarlar =
      departmanAyarlari ?? DepartmanAyarlari.varsayilan();

  final List<String> vardiyaSaatleri = ayarlar.vardiyaSaatleri;

  final List<OzelDurumAyar> gorunenOzelDurumlar = ayarlar.ozelDurumlar
      .where((durum) => durum.hizliDoldurmadaGoster)
      .toList();

  final TextEditingController ozelSaatController = TextEditingController();

  final List<String> hizliDoldurmaSecenekleri = [
    ...vardiyaSaatleri,
    ...gorunenOzelDurumlar.map((durum) => durum.kod),
  ];

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              personel.gorev.trim().isEmpty
                  ? personel.ad
                  : "${personel.ad} • ${personel.gorev}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "$secilenGun günü için vardiya veya durum seçin",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _KategoriBaslik(baslik: "Vardiya Saatleri"),
                if (vardiyaSaatleri.isEmpty)
                  const Text(
                    "Bu departman için kayıtlı vardiya saati yok.",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: vardiyaSaatleri.map((v) {
                      return ActionChip(
                        label: Text(
                          v,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: Colors.blueGrey.shade50,
                        onPressed: () => onKaydet(v, false),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),

                const _KategoriBaslik(baslik: "İzinler ve Özel Durumlar"),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...gorunenOzelDurumlar.map((durum) {
                      return ActionChip(
                        label: Text(
                          _ozelDurumButonEtiketi(durum),
                          style: TextStyle(
                            fontWeight: durum.kalin
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _hexRenk(durum.yaziHex, Colors.black87),
                          ),
                        ),
                        backgroundColor: _hexRenk(
                          durum.arkaPlanHex,
                          Colors.grey.shade200,
                        ),
                        onPressed: () => onKaydet(durum.kod, false),
                      );
                    }),
                    ActionChip(
                      label: const Text(
                        "Temizle (Boş)",
                        style: TextStyle(color: Colors.grey),
                      ),
                      backgroundColor: Colors.grey.shade200,
                      onPressed: () => onKaydet("Boş", false),
                    ),
                  ],
                ),
                const Divider(height: 32),

                const _KategoriBaslik(baslik: "Haftalık Hızlı Doldurma"),
                const Text(
                  "Seçtiğiniz vardiya veya durum bu personelin tüm haftasına uygulanır.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Tüm haftaya uygulanacak vardiya/durum",
                  ),
                  items: hizliDoldurmaSecenekleri.map((String deger) {
                    return DropdownMenuItem<String>(
                      value: deger,
                      child: Text(
                        _etiketBul(deger, gorunenOzelDurumlar),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (secilen) {
                    if (secilen != null) {
                      onKaydet(secilen, true);
                    }
                  },
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: ozelSaatController,
                  decoration: InputDecoration(
                    labelText: "Farklı Bir Saat/Durum Yaz (Örn: 09:00-17:00)",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () {
                        if (ozelSaatController.text.trim().isNotEmpty) {
                          onKaydet(ozelSaatController.text.trim(), false);
                        }
                      },
                    ),
                  ),
                  onSubmitted: (deger) {
                    if (deger.trim().isNotEmpty) {
                      onKaydet(deger.trim(), false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _etiketBul(String kod, List<OzelDurumAyar> ozelDurumlar) {
  for (final durum in ozelDurumlar) {
    if (durum.kod == kod) {
      return _ozelDurumButonEtiketi(durum);
    }
  }

  return kod;
}

String _ozelDurumButonEtiketi(OzelDurumAyar durum) {
  switch (durum.kod) {
    case 'OFF':
      return 'OFF - Haftalık İzin';
    case 'B':
      return 'B - Çalışılan Resmi Tatil';
    case 'G':
      return 'G - Resmi Tatil İzni';
    case 'R':
      return 'R - Raporlu';
    case 'D':
      return 'D - Devamsızlık';
    case 'Ü':
      return 'Ü - Ücretli İzin';
    case 'Y':
      return 'Y - Yıllık İzin';
    case 'Z':
      return 'Z - Alacak İzin';
    default:
      return durum.etiket;
  }
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

class _KategoriBaslik extends StatelessWidget {
  final String baslik;

  const _KategoriBaslik({
    Key? key,
    required this.baslik,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        baslik,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}