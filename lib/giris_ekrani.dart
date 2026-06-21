// giris_ekrani.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ana_ekran.dart';

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({Key? key}) : super(key: key);

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _kullaniciAdiController = TextEditingController();
  final _sifreController = TextEditingController();
  bool _yukleniyor = false;

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _girisYap() async {
    final girdi = _kullaniciAdiController.text.trim();
    final sifre = _sifreController.text.trim();

    if (girdi.isEmpty || sifre.isEmpty) {
      _hataGoster("Lütfen kullanıcı adı ve şifre alanlarını doldurun!");
      return;
    }

    setState(() => _yukleniyor = true);

    final String kullaniciAdi = girdi.trim().toLowerCase();

    final String email = kullaniciAdi.contains('@')
        ? kullaniciAdi
        : '$kullaniciAdi@otelsistemi.local';

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: sifre,
      );
      
      // Giriş başarılıysa ana tabloya uçur
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const AnaEkran())
      );
    } on FirebaseAuthException {
      _hataGoster("Hatalı kullanıcı adı veya şifre girdiniz!");
    } catch (e) {
      _hataGoster("Bağlantı hatası oluştu!");
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      body: Center(
        child: Container(
          width: 400, // Bilgisayar ekranında kibar dursun diye sabit genişlik
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security, size: 64, color: Colors.blueGrey),
                  const SizedBox(height: 16),
                  const Text(
                    "Kurumsal Giriş Paneli", 
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey)
                  ),
                  const SizedBox(height: 24),
                  // KULLANICI ADI GİRDİSİ
                  TextField(
                    controller: _kullaniciAdiController,
                    decoration: const InputDecoration(
                      labelText: "Kullanıcı Adı", 
                      border: OutlineInputBorder(), 
                      prefixIcon: Icon(Icons.account_circle)
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ŞİFRE GİRDİSİ
                  TextField(
                    controller: _sifreController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Şifre", 
                      border: OutlineInputBorder(), 
                      prefixIcon: Icon(Icons.lock)
                    ),
                  ),
                  const SizedBox(height: 24),
                  _yukleniyor
                      ? const CircularProgressIndicator()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey, 
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              onPressed: _girisYap,
                              child: const Text("Giriş Yap", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}