# Otel Personel Vardiya Yönetim Sistemi 🏨

## Proje Hakkında
Bu proje, otel çalışanlarının haftalık vardiya programlarını, departman bazlı özel durumlarını ve puantaj (maaş/hakediş) hesaplamalarını dijital ortama taşıyan, bulut tabanlı bir yönetim otomasyonudur. Sistemin temel amacı; operasyonel kaosu engellemek, departman yöneticilerinin vardiya yazma sürecini hızlandırmak ve personelin aylık çalışma verilerini hatasız bir şekilde raporlamaktır.

## 🚀 Temel Özellikler

* **Dinamik Departman Yönetimi:** Housekeeping (Kat Hizmetleri) ve Food & Beverage (Yiyecek-İçecek) gibi farklı operasyonel departmanların ihtiyaçlarına (Görev dağılımı, PAX hesaplaması, imza sirküleri) göre özelleşebilen dinamik arayüz.
* **Otomatik Puantaj (Payroll) Sistemi:** Personelin haftalık shift kayıtlarından yola çıkarak aylık puantaj tablosunu (Normal mesai, Resmi Tatil, Yıllık İzin vb.) otomatik hesaplama ve görselleştirme.
* **Hızlı Atama ve Şablonlama:** Tek tıkla önceki haftanın programını kopyalama veya bir personelin vardiyasını tüm haftaya hızlı doldurma (Auto-fill) özellikleri.
* **Export ve Raporlama:** Oluşturulan haftalık programları ve aylık puantaj tablolarını yüksek çözünürlüklü PNG olarak indirme ve doğrudan yazdırma (Print) desteği.
* **Canlı Veritabanı Senkronizasyonu:** Tüm verilerin Firebase Firestore üzerinde anlık olarak saklanması ve yetkilendirilmiş kullanıcı girişi (Firebase Auth).

## 🛠 Kullanılan Teknolojiler & Mimari

* **Frontend:** Flutter & Dart
* **Backend (BaaS):** Firebase (Authentication & Cloud Firestore)
* **Mimari:** Modüler MVC tabanlı state ve veri yönetimi (`DepartmanAyarlari`, `PersonelModel`, `PuantajModel`)
* **Veri İşleme:** Gelişmiş JSON Encode/Decode yapılandırması

## 📸 Geliştirici Notu
Sistem, otelcilik sektöründeki gerçek operasyonel ihtiyaçlar ve departman şeflerinin geri bildirimleri doğrultusunda, karmaşık Excel tablolarının yerini alması amacıyla tasarlanmış ve geliştirilmiştir.
