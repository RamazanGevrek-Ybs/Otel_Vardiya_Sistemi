// personel_ekle_dialog.dart
import 'package:flutter/material.dart';
import 'departman_ayar_model.dart';

// Yeni personel eklemek için açılan ufak pencere.
// Eski kullanım bozulmasın diye onPersonelEkle(String ad) aynen duruyor.
// Housekeeping gibi görev sütunu olan departmanlarda onPersonelEkleDetayli(ad, gorev)
// kullanacağız.
void showPersonelEkleDialog(
  BuildContext context,
  Function(String) onPersonelEkle, {
  DepartmanAyarlari? departmanAyarlari,
  Function(String ad, String gorev)? onPersonelEkleDetayli,
}) {
  final DepartmanAyarlari ayarlar = departmanAyarlari ?? DepartmanAyarlari.varsayilan();
  final TextEditingController adController = TextEditingController();
  String secilenGorev = ayarlar.gorevSecenekleri.isNotEmpty ? ayarlar.gorevSecenekleri.first : '';

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Yeni Personel Ekle"),
                if (ayarlar.departmanBasligi.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ayarlar.departmanBasligi,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: adController,
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: "Personelin Adı Soyadı",
                      hintText: "Örn: Caner Yılmaz",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    onSubmitted: (_) {
                      _personelEkleVeKapat(
                        context: context,
                        adController: adController,
                        gorev: secilenGorev,
                        gorevGerekli: ayarlar.gorevSutunuGoster,
                        onPersonelEkle: onPersonelEkle,
                        onPersonelEkleDetayli: onPersonelEkleDetayli,
                      );
                    },
                  ),
                  if (ayarlar.gorevSutunuGoster) ...[
                    const SizedBox(height: 14),
                    ayarlar.gorevSecenekleri.isEmpty
                        ? TextField(
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: ayarlar.gorevBaslik,
                              hintText: "Örn: MAID",
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.badge),
                            ),
                            onChanged: (deger) => secilenGorev = deger.trim(),
                          )
                        : DropdownButtonFormField<String>(
                            value: secilenGorev,
                            decoration: InputDecoration(
                              labelText: ayarlar.gorevBaslik,
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.badge),
                            ),
                            items: ayarlar.gorevSecenekleri.map((gorev) {
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
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("İptal", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                onPressed: () {
                  _personelEkleVeKapat(
                    context: context,
                    adController: adController,
                    gorev: secilenGorev,
                    gorevGerekli: ayarlar.gorevSutunuGoster,
                    onPersonelEkle: onPersonelEkle,
                    onPersonelEkleDetayli: onPersonelEkleDetayli,
                  );
                },
                child: const Text("Ekle", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}

void _personelEkleVeKapat({
  required BuildContext context,
  required TextEditingController adController,
  required String gorev,
  required bool gorevGerekli,
  required Function(String) onPersonelEkle,
  required Function(String ad, String gorev)? onPersonelEkleDetayli,
}) {
  final String ad = adController.text.trim();
  final String temizGorev = gorev.trim();

  if (ad.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Personel adı boş olamaz."),
        backgroundColor: Colors.redAccent,
      ),
    );
    return;
  }

  if (gorevGerekli && temizGorev.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Lütfen personelin görevini seçin veya yazın."),
        backgroundColor: Colors.redAccent,
      ),
    );
    return;
  }

  if (onPersonelEkleDetayli != null) {
    onPersonelEkleDetayli(ad, temizGorev);
  } else {
    onPersonelEkle(ad);
  }

  Navigator.pop(context);
}