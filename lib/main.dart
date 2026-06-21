// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase çekirdeği eklendi
import 'firebase_options.dart'; // Terminalin az önce ürettiği sihirli dosya
import 'giris_ekrani.dart'; // Artık ana ekran yerine önce giriş ekranı açılacak

void main() async {
  // Firebase'i başlatmak için Flutter motorunu güvenceye alıyoruz
  WidgetsFlutterBinding.ensureInitialized();
  
  // Bulut sistemini ayağa kaldıran kod
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const ShiftAsistaniApp());
}

class ShiftAsistaniApp extends StatelessWidget {
  const ShiftAsistaniApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Haftalık Shift Programı',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: Colors.grey[100], // Göz yormayan arka plan
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      // KRAL DETAY: Uygulama artık AnaEkran'dan değil, Giriş Ekranından başlıyor!
      home: const GirisEkrani(), 
    );
  }
}