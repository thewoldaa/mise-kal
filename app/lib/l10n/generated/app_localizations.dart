import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppStrings
/// returned by `AppStrings.of(context)`.
///
/// Applications need to include `AppStrings.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppStrings.localizationsDelegates,
///   supportedLocales: AppStrings.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppStrings.supportedLocales
/// property.
abstract class AppStrings {
  AppStrings(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppStrings? of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings);
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('id'),
    Locale('en'),
  ];

  /// Nama produk. Jangan diterjemahkan.
  ///
  /// In id, this message translates to:
  /// **'Mise'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get commonDelete;

  /// No description provided for @commonRemove.
  ///
  /// In id, this message translates to:
  /// **'Singkirkan'**
  String get commonRemove;

  /// No description provided for @commonClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get commonClose;

  /// No description provided for @commonDone.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get commonDone;

  /// No description provided for @commonSave.
  ///
  /// In id, this message translates to:
  /// **'Simpan perubahan'**
  String get commonSave;

  /// No description provided for @commonAdd.
  ///
  /// In id, this message translates to:
  /// **'Tambah'**
  String get commonAdd;

  /// No description provided for @commonName.
  ///
  /// In id, this message translates to:
  /// **'Nama'**
  String get commonName;

  /// No description provided for @commonAddress.
  ///
  /// In id, this message translates to:
  /// **'Alamat'**
  String get commonAddress;

  /// No description provided for @commonPort.
  ///
  /// In id, this message translates to:
  /// **'Port'**
  String get commonPort;

  /// No description provided for @commonPrice.
  ///
  /// In id, this message translates to:
  /// **'Harga'**
  String get commonPrice;

  /// No description provided for @commonTotal.
  ///
  /// In id, this message translates to:
  /// **'Total'**
  String get commonTotal;

  /// No description provided for @commonSubtotal.
  ///
  /// In id, this message translates to:
  /// **'Subtotal'**
  String get commonSubtotal;

  /// No description provided for @commonNote.
  ///
  /// In id, this message translates to:
  /// **'Catatan'**
  String get commonNote;

  /// No description provided for @commonReason.
  ///
  /// In id, this message translates to:
  /// **'Alasan'**
  String get commonReason;

  /// No description provided for @commonAmount.
  ///
  /// In id, this message translates to:
  /// **'Jumlah'**
  String get commonAmount;

  /// No description provided for @commonReference.
  ///
  /// In id, this message translates to:
  /// **'Referensi'**
  String get commonReference;

  /// No description provided for @commonDescription.
  ///
  /// In id, this message translates to:
  /// **'Deskripsi'**
  String get commonDescription;

  /// No description provided for @commonCategory.
  ///
  /// In id, this message translates to:
  /// **'Kategori'**
  String get commonCategory;

  /// No description provided for @commonPhoto.
  ///
  /// In id, this message translates to:
  /// **'Foto'**
  String get commonPhoto;

  /// No description provided for @commonOptions.
  ///
  /// In id, this message translates to:
  /// **'Pilihan'**
  String get commonOptions;

  /// No description provided for @commonTags.
  ///
  /// In id, this message translates to:
  /// **'Label'**
  String get commonTags;

  /// No description provided for @commonTryAgain.
  ///
  /// In id, this message translates to:
  /// **'Coba lagi'**
  String get commonTryAgain;

  /// No description provided for @commonCouldNotLoad.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa memuat ini'**
  String get commonCouldNotLoad;

  /// No description provided for @commonTest.
  ///
  /// In id, this message translates to:
  /// **'Uji'**
  String get commonTest;

  /// No description provided for @commonEarlier.
  ///
  /// In id, this message translates to:
  /// **'Lebih awal'**
  String get commonEarlier;

  /// No description provided for @commonLater.
  ///
  /// In id, this message translates to:
  /// **'Lebih baru'**
  String get commonLater;

  /// No description provided for @commonAll.
  ///
  /// In id, this message translates to:
  /// **'Semua'**
  String get commonAll;

  /// No description provided for @commonOn.
  ///
  /// In id, this message translates to:
  /// **'Aktif'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In id, this message translates to:
  /// **'Mati'**
  String get commonOff;

  /// No description provided for @signInTitle.
  ///
  /// In id, this message translates to:
  /// **'Masuk'**
  String get signInTitle;

  /// No description provided for @signInUsername.
  ///
  /// In id, this message translates to:
  /// **'Nama pengguna'**
  String get signInUsername;

  /// No description provided for @signInPin.
  ///
  /// In id, this message translates to:
  /// **'PIN'**
  String get signInPin;

  /// No description provided for @signInUseDifferentServer.
  ///
  /// In id, this message translates to:
  /// **'Ganti server'**
  String get signInUseDifferentServer;

  /// No description provided for @connectTitle.
  ///
  /// In id, this message translates to:
  /// **'Sambungkan ke server Anda'**
  String get connectTitle;

  /// No description provided for @connectAction.
  ///
  /// In id, this message translates to:
  /// **'Sambungkan'**
  String get connectAction;

  /// No description provided for @connectOnThisNetwork.
  ///
  /// In id, this message translates to:
  /// **'Di jaringan ini'**
  String get connectOnThisNetwork;

  /// No description provided for @connectSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Manajemen restoran'**
  String get connectSubtitle;

  /// No description provided for @connectRunOnThisComputer.
  ///
  /// In id, this message translates to:
  /// **'Jalankan restoran di komputer ini'**
  String get connectRunOnThisComputer;

  /// No description provided for @connectScanCode.
  ///
  /// In id, this message translates to:
  /// **'Pindai kode'**
  String get connectScanCode;

  /// No description provided for @connectServerAddress.
  ///
  /// In id, this message translates to:
  /// **'Alamat server'**
  String get connectServerAddress;

  /// No description provided for @connectOr.
  ///
  /// In id, this message translates to:
  /// **'atau'**
  String get connectOr;

  /// No description provided for @connectScanPointAtCode.
  ///
  /// In id, this message translates to:
  /// **'Arahkan ke kode'**
  String get connectScanPointAtCode;

  /// No description provided for @connectScanTypeInstead.
  ///
  /// In id, this message translates to:
  /// **'Ketik manual'**
  String get connectScanTypeInstead;

  /// No description provided for @setupTitle.
  ///
  /// In id, this message translates to:
  /// **'Siapkan restoran Anda'**
  String get setupTitle;

  /// No description provided for @kdsOnThePass.
  ///
  /// In id, this message translates to:
  /// **'Di pass'**
  String get kdsOnThePass;

  /// No description provided for @kdsNothingOnThePass.
  ///
  /// In id, this message translates to:
  /// **'Pass kosong'**
  String get kdsNothingOnThePass;

  /// No description provided for @kdsCouldNotUpdate.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa memperbarui: {error}'**
  String kdsCouldNotUpdate(String error);

  /// No description provided for @navPos.
  ///
  /// In id, this message translates to:
  /// **'Kasir'**
  String get navPos;

  /// No description provided for @navKds.
  ///
  /// In id, this message translates to:
  /// **'Dapur'**
  String get navKds;

  /// No description provided for @navManager.
  ///
  /// In id, this message translates to:
  /// **'Manajer'**
  String get navManager;

  /// No description provided for @navSignOut.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get navSignOut;

  /// No description provided for @navSwitchShell.
  ///
  /// In id, this message translates to:
  /// **'Ganti tampilan'**
  String get navSwitchShell;

  /// No description provided for @floorTitle.
  ///
  /// In id, this message translates to:
  /// **'Lantai'**
  String get floorTitle;

  /// No description provided for @floorHint.
  ///
  /// In id, this message translates to:
  /// **'Ketuk meja untuk membuka atau melanjutkan bonnya.'**
  String get floorHint;

  /// No description provided for @floorNoTables.
  ///
  /// In id, this message translates to:
  /// **'Belum ada meja'**
  String get floorNoTables;

  /// No description provided for @floorTakeaway.
  ///
  /// In id, this message translates to:
  /// **'Bawa pulang'**
  String get floorTakeaway;

  /// No description provided for @floorOpenBill.
  ///
  /// In id, this message translates to:
  /// **'Bon terbuka'**
  String get floorOpenBill;

  /// No description provided for @floorHowManyGuests.
  ///
  /// In id, this message translates to:
  /// **'Berapa tamu?'**
  String get floorHowManyGuests;

  /// No description provided for @floorSeatTable.
  ///
  /// In id, this message translates to:
  /// **'Dudukkan {label}'**
  String floorSeatTable(String label);

  /// No description provided for @floorCouldNotOpen.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa membuka meja: {error}'**
  String floorCouldNotOpen(String error);

  /// No description provided for @floorCouldNotStart.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa memulai pesanan: {error}'**
  String floorCouldNotStart(String error);

  /// No description provided for @floorInUse.
  ///
  /// In id, this message translates to:
  /// **'Terpakai'**
  String get floorInUse;

  /// No description provided for @orderBackToFloor.
  ///
  /// In id, this message translates to:
  /// **'Kembali ke lantai'**
  String get orderBackToFloor;

  /// No description provided for @orderNothingHere.
  ///
  /// In id, this message translates to:
  /// **'Belum ada isi'**
  String get orderNothingHere;

  /// No description provided for @orderMenuEmpty.
  ///
  /// In id, this message translates to:
  /// **'Menu masih kosong'**
  String get orderMenuEmpty;

  /// No description provided for @orderBillGone.
  ///
  /// In id, this message translates to:
  /// **'Bon ini sudah tidak ada'**
  String get orderBillGone;

  /// No description provided for @orderCouldNotAdd.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa menambah: {error}'**
  String orderCouldNotAdd(String error);

  /// No description provided for @orderSoldOut.
  ///
  /// In id, this message translates to:
  /// **'Habis'**
  String get orderSoldOut;

  /// No description provided for @orderAddToBill.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan ke bon'**
  String get orderAddToBill;

  /// No description provided for @orderNoteForKitchen.
  ///
  /// In id, this message translates to:
  /// **'Catatan untuk dapur'**
  String get orderNoteForKitchen;

  /// No description provided for @orderUpTo.
  ///
  /// In id, this message translates to:
  /// **'maksimal {count}'**
  String orderUpTo(int count);

  /// No description provided for @moveBillTitle.
  ///
  /// In id, this message translates to:
  /// **'Pindahkan bon #{number}'**
  String moveBillTitle(String number);

  /// No description provided for @moveBillNowhere.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada tujuan lain.'**
  String get moveBillNowhere;

  /// No description provided for @moveBillWhereTo.
  ///
  /// In id, this message translates to:
  /// **'Ke mana?'**
  String get moveBillWhereTo;

  /// No description provided for @discountTitle.
  ///
  /// In id, this message translates to:
  /// **'Diskon'**
  String get discountTitle;

  /// No description provided for @discountAmountOff.
  ///
  /// In id, this message translates to:
  /// **'Potongan jumlah'**
  String get discountAmountOff;

  /// No description provided for @discountNewSubtotal.
  ///
  /// In id, this message translates to:
  /// **'Subtotal baru'**
  String get discountNewSubtotal;

  /// No description provided for @discountReasonHint.
  ///
  /// In id, this message translates to:
  /// **'Layanan dan pajak dihitung dari angka ini.'**
  String get discountReasonHint;

  /// No description provided for @discountClear.
  ///
  /// In id, this message translates to:
  /// **'Hapus'**
  String get discountClear;

  /// No description provided for @paymentTitle.
  ///
  /// In id, this message translates to:
  /// **'Bagaimana mereka membayar?'**
  String get paymentTitle;

  /// No description provided for @paymentCashReceived.
  ///
  /// In id, this message translates to:
  /// **'Uang diterima'**
  String get paymentCashReceived;

  /// No description provided for @paymentChangeDue.
  ///
  /// In id, this message translates to:
  /// **'Kembalian'**
  String get paymentChangeDue;

  /// No description provided for @paymentPaid.
  ///
  /// In id, this message translates to:
  /// **'Sudah dibayar'**
  String get paymentPaid;

  /// No description provided for @paymentTake.
  ///
  /// In id, this message translates to:
  /// **'Terima {amount}'**
  String paymentTake(String amount);

  /// No description provided for @paymentTakenSoFar.
  ///
  /// In id, this message translates to:
  /// **'Sudah diterima'**
  String get paymentTakenSoFar;

  /// No description provided for @paymentRemovePayment.
  ///
  /// In id, this message translates to:
  /// **'Hapus pembayaran ini'**
  String get paymentRemovePayment;

  /// No description provided for @paymentReceipt.
  ///
  /// In id, this message translates to:
  /// **'Struk'**
  String get paymentReceipt;

  /// No description provided for @receiptTitle.
  ///
  /// In id, this message translates to:
  /// **'Struk'**
  String get receiptTitle;

  /// No description provided for @receiptPrintTo.
  ///
  /// In id, this message translates to:
  /// **'Cetak ke {printer}'**
  String receiptPrintTo(String printer);

  /// No description provided for @shiftCloseTitle.
  ///
  /// In id, this message translates to:
  /// **'Tutup shift Anda'**
  String get shiftCloseTitle;

  /// No description provided for @shiftCashInDrawer.
  ///
  /// In id, this message translates to:
  /// **'Uang di laci'**
  String get shiftCashInDrawer;

  /// No description provided for @shiftCashTaken.
  ///
  /// In id, this message translates to:
  /// **'Uang masuk'**
  String get shiftCashTaken;

  /// No description provided for @shiftCounted.
  ///
  /// In id, this message translates to:
  /// **'Hasil hitung'**
  String get shiftCounted;

  /// No description provided for @shiftOpeningFloat.
  ///
  /// In id, this message translates to:
  /// **'Modal awal'**
  String get shiftOpeningFloat;

  /// No description provided for @shiftShouldBeInDrawer.
  ///
  /// In id, this message translates to:
  /// **'Seharusnya ada di laci'**
  String get shiftShouldBeInDrawer;

  /// No description provided for @shiftHereIsWhat.
  ///
  /// In id, this message translates to:
  /// **'Berikut hasilnya.'**
  String get shiftHereIsWhat;

  /// No description provided for @shiftClosed.
  ///
  /// In id, this message translates to:
  /// **'Shift ditutup'**
  String get shiftClosed;

  /// No description provided for @summaryTakings.
  ///
  /// In id, this message translates to:
  /// **'Pendapatan'**
  String get summaryTakings;

  /// No description provided for @summaryHowItAddsUp.
  ///
  /// In id, this message translates to:
  /// **'Rincian'**
  String get summaryHowItAddsUp;

  /// No description provided for @summaryHowItWasPaid.
  ///
  /// In id, this message translates to:
  /// **'Cara pembayaran'**
  String get summaryHowItWasPaid;

  /// No description provided for @summaryTheDrawer.
  ///
  /// In id, this message translates to:
  /// **'Laci'**
  String get summaryTheDrawer;

  /// No description provided for @summaryCancelled.
  ///
  /// In id, this message translates to:
  /// **'Dibatalkan'**
  String get summaryCancelled;

  /// No description provided for @menuItemsTitle.
  ///
  /// In id, this message translates to:
  /// **'Menu'**
  String get menuItemsTitle;

  /// No description provided for @menuItemsSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Semua yang Anda jual, dan harganya.'**
  String get menuItemsSubtitle;

  /// No description provided for @menuItemsNew.
  ///
  /// In id, this message translates to:
  /// **'Menu baru'**
  String get menuItemsNew;

  /// No description provided for @menuItemsNone.
  ///
  /// In id, this message translates to:
  /// **'Belum ada menu'**
  String get menuItemsNone;

  /// No description provided for @menuItemsNoMatch.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada yang cocok'**
  String get menuItemsNoMatch;

  /// No description provided for @menuItemsAddFirst.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan menu pertama'**
  String get menuItemsAddFirst;

  /// No description provided for @menuItemsAddCategoryFirst.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan kategori dulu'**
  String get menuItemsAddCategoryFirst;

  /// No description provided for @menuCategoriesTitle.
  ///
  /// In id, this message translates to:
  /// **'Kategori'**
  String get menuCategoriesTitle;

  /// No description provided for @menuCategoriesSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Bagian-bagian menu Anda. Urutannya mengikuti urutan di kasir.'**
  String get menuCategoriesSubtitle;

  /// No description provided for @menuCategoriesNew.
  ///
  /// In id, this message translates to:
  /// **'Kategori baru'**
  String get menuCategoriesNew;

  /// No description provided for @menuCategoriesNone.
  ///
  /// In id, this message translates to:
  /// **'Belum ada kategori'**
  String get menuCategoriesNone;

  /// No description provided for @menuCategoriesAddFirst.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan kategori pertama'**
  String get menuCategoriesAddFirst;

  /// No description provided for @menuCategoriesHidden.
  ///
  /// In id, this message translates to:
  /// **'Disembunyikan'**
  String get menuCategoriesHidden;

  /// No description provided for @menuCategoriesTileColour.
  ///
  /// In id, this message translates to:
  /// **'Warna kartu'**
  String get menuCategoriesTileColour;

  /// No description provided for @menuCategoriesTileColourHint.
  ///
  /// In id, this message translates to:
  /// **'Ditampilkan di kasir supaya staf cepat menemukan bagian ini.'**
  String get menuCategoriesTileColourHint;

  /// No description provided for @menuCategoriesVisible.
  ///
  /// In id, this message translates to:
  /// **'Tampil di kasir'**
  String get menuCategoriesVisible;

  /// No description provided for @menuCategoriesStation.
  ///
  /// In id, this message translates to:
  /// **'Siapa yang membuat'**
  String get menuCategoriesStation;

  /// No description provided for @menuCategoriesStationHint.
  ///
  /// In id, this message translates to:
  /// **'Bon dari bagian ini dicetak di stasiun tersebut.'**
  String get menuCategoriesStationHint;

  /// No description provided for @menuItemOnTheMenu.
  ///
  /// In id, this message translates to:
  /// **'Ada di menu'**
  String get menuItemOnTheMenu;

  /// No description provided for @menuItemInStock.
  ///
  /// In id, this message translates to:
  /// **'Stok tersedia'**
  String get menuItemInStock;

  /// No description provided for @menuItemCode.
  ///
  /// In id, this message translates to:
  /// **'Kode menu'**
  String get menuItemCode;

  /// No description provided for @menuItemPrepTime.
  ///
  /// In id, this message translates to:
  /// **'Waktu siap'**
  String get menuItemPrepTime;

  /// No description provided for @modifiersTitle.
  ///
  /// In id, this message translates to:
  /// **'Pilihan tambahan'**
  String get modifiersTitle;

  /// No description provided for @modifiersSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Pilihan yang bisa ditempel ke menu. Tentukan sekali, pakai berulang.'**
  String get modifiersSubtitle;

  /// No description provided for @modifiersNewGroup.
  ///
  /// In id, this message translates to:
  /// **'Grup baru'**
  String get modifiersNewGroup;

  /// No description provided for @modifiersNone.
  ///
  /// In id, this message translates to:
  /// **'Belum ada grup pilihan'**
  String get modifiersNone;

  /// No description provided for @modifiersCreateFirst.
  ///
  /// In id, this message translates to:
  /// **'Buat grup pertama'**
  String get modifiersCreateFirst;

  /// No description provided for @modifiersAddOption.
  ///
  /// In id, this message translates to:
  /// **'Tambah pilihan'**
  String get modifiersAddOption;

  /// No description provided for @modifiersNoOptions.
  ///
  /// In id, this message translates to:
  /// **'Belum ada pilihan.'**
  String get modifiersNoOptions;

  /// No description provided for @modifiersAllowMoreThanOne.
  ///
  /// In id, this message translates to:
  /// **'Boleh pilih lebih dari satu'**
  String get modifiersAllowMoreThanOne;

  /// No description provided for @modifiersMustBeAnswered.
  ///
  /// In id, this message translates to:
  /// **'Wajib dijawab'**
  String get modifiersMustBeAnswered;

  /// No description provided for @modifiersMaxSelectable.
  ///
  /// In id, this message translates to:
  /// **'Maksimal yang bisa dipilih'**
  String get modifiersMaxSelectable;

  /// No description provided for @modifiersPriceChange.
  ///
  /// In id, this message translates to:
  /// **'Perubahan harga'**
  String get modifiersPriceChange;

  /// No description provided for @modifiersOffered.
  ///
  /// In id, this message translates to:
  /// **'Ditawarkan'**
  String get modifiersOffered;

  /// No description provided for @tablesTitle.
  ///
  /// In id, this message translates to:
  /// **'Meja'**
  String get tablesTitle;

  /// No description provided for @tablesSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Denah Anda. Kelompokkan per zona kalau ruangannya bersekat.'**
  String get tablesSubtitle;

  /// No description provided for @tablesNew.
  ///
  /// In id, this message translates to:
  /// **'Meja baru'**
  String get tablesNew;

  /// No description provided for @tablesNone.
  ///
  /// In id, this message translates to:
  /// **'Belum ada meja'**
  String get tablesNone;

  /// No description provided for @tablesAddFirst.
  ///
  /// In id, this message translates to:
  /// **'Tambahkan meja pertama'**
  String get tablesAddFirst;

  /// No description provided for @tablesNameOrNumber.
  ///
  /// In id, this message translates to:
  /// **'Nama atau nomor'**
  String get tablesNameOrNumber;

  /// No description provided for @tablesSeats.
  ///
  /// In id, this message translates to:
  /// **'Kursi'**
  String get tablesSeats;

  /// No description provided for @tablesZone.
  ///
  /// In id, this message translates to:
  /// **'Zona'**
  String get tablesZone;

  /// No description provided for @tablesInUse.
  ///
  /// In id, this message translates to:
  /// **'Terpakai'**
  String get tablesInUse;

  /// No description provided for @tablesCodes.
  ///
  /// In id, this message translates to:
  /// **'Kode meja'**
  String get tablesCodes;

  /// No description provided for @tablesCodesNone.
  ///
  /// In id, this message translates to:
  /// **'Belum ada meja yang dipakai.'**
  String get tablesCodesNone;

  /// No description provided for @tablesDeleteConfirm.
  ///
  /// In id, this message translates to:
  /// **'Hapus {label}?'**
  String tablesDeleteConfirm(String label);

  /// No description provided for @staffTitle.
  ///
  /// In id, this message translates to:
  /// **'Staf'**
  String get staffTitle;

  /// No description provided for @staffSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Siapa yang bisa masuk, dan apa yang boleh mereka lakukan.'**
  String get staffSubtitle;

  /// No description provided for @staffAddSomeone.
  ///
  /// In id, this message translates to:
  /// **'Tambah orang'**
  String get staffAddSomeone;

  /// No description provided for @staffNobodyYet.
  ///
  /// In id, this message translates to:
  /// **'Belum ada siapa-siapa'**
  String get staffNobodyYet;

  /// No description provided for @staffCanSignIn.
  ///
  /// In id, this message translates to:
  /// **'Bisa masuk'**
  String get staffCanSignIn;

  /// No description provided for @staffWhatTheyCanDo.
  ///
  /// In id, this message translates to:
  /// **'Hak akses'**
  String get staffWhatTheyCanDo;

  /// No description provided for @staffYou.
  ///
  /// In id, this message translates to:
  /// **'Anda'**
  String get staffYou;

  /// No description provided for @staffCannotDisableSelf.
  ///
  /// In id, this message translates to:
  /// **'Anda tidak bisa menonaktifkan akun sendiri.'**
  String get staffCannotDisableSelf;

  /// No description provided for @staffGiveNewPin.
  ///
  /// In id, this message translates to:
  /// **'Beri PIN baru'**
  String get staffGiveNewPin;

  /// No description provided for @staffNewPinFor.
  ///
  /// In id, this message translates to:
  /// **'PIN baru untuk {name}'**
  String staffNewPinFor(String name);

  /// No description provided for @staffSetPin.
  ///
  /// In id, this message translates to:
  /// **'Simpan PIN'**
  String get staffSetPin;

  /// No description provided for @staffRemoveConfirm.
  ///
  /// In id, this message translates to:
  /// **'Keluarkan {name}?'**
  String staffRemoveConfirm(String name);

  /// No description provided for @reportsTitle.
  ///
  /// In id, this message translates to:
  /// **'Laporan'**
  String get reportsTitle;

  /// No description provided for @reportsSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Hasil penjualan tiap hari.'**
  String get reportsSubtitle;

  /// No description provided for @reportsWhatSold.
  ///
  /// In id, this message translates to:
  /// **'Yang terjual'**
  String get reportsWhatSold;

  /// No description provided for @reportsWhoServedIt.
  ///
  /// In id, this message translates to:
  /// **'Yang melayani'**
  String get reportsWhoServedIt;

  /// No description provided for @reportsByHour.
  ///
  /// In id, this message translates to:
  /// **'PER JAM'**
  String get reportsByHour;

  /// No description provided for @reportsExportCsv.
  ///
  /// In id, this message translates to:
  /// **'Ekspor CSV'**
  String get reportsExportCsv;

  /// No description provided for @reportsSaved.
  ///
  /// In id, this message translates to:
  /// **'Laporan tersimpan.'**
  String get reportsSaved;

  /// No description provided for @reportsCouldNotSave.
  ///
  /// In id, this message translates to:
  /// **'Tidak bisa menyimpan: {error}'**
  String reportsCouldNotSave(String error);

  /// No description provided for @activityTitle.
  ///
  /// In id, this message translates to:
  /// **'Aktivitas'**
  String get activityTitle;

  /// No description provided for @activitySubtitle.
  ///
  /// In id, this message translates to:
  /// **'Diskon, pembatalan, dan void — lengkap dengan namanya.'**
  String get activitySubtitle;

  /// No description provided for @activityMoneyLeavingOnly.
  ///
  /// In id, this message translates to:
  /// **'Hanya uang keluar'**
  String get activityMoneyLeavingOnly;

  /// No description provided for @settingsTitle.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get settingsTitle;

  /// No description provided for @settingsRestaurant.
  ///
  /// In id, this message translates to:
  /// **'Restoran'**
  String get settingsRestaurant;

  /// No description provided for @settingsRestaurantHint.
  ///
  /// In id, this message translates to:
  /// **'Identitas restoran Anda dan biaya yang dikenakan.'**
  String get settingsRestaurantHint;

  /// No description provided for @settingsCharges.
  ///
  /// In id, this message translates to:
  /// **'Biaya'**
  String get settingsCharges;

  /// No description provided for @settingsCurrency.
  ///
  /// In id, this message translates to:
  /// **'Mata uang'**
  String get settingsCurrency;

  /// No description provided for @settingsTaxRate.
  ///
  /// In id, this message translates to:
  /// **'Tarif pajak'**
  String get settingsTaxRate;

  /// No description provided for @settingsTaxIncluded.
  ///
  /// In id, this message translates to:
  /// **'Harga menu sudah termasuk pajak'**
  String get settingsTaxIncluded;

  /// No description provided for @settingsServiceCharge.
  ///
  /// In id, this message translates to:
  /// **'Biaya layanan'**
  String get settingsServiceCharge;

  /// No description provided for @settingsPrinters.
  ///
  /// In id, this message translates to:
  /// **'Printer'**
  String get settingsPrinters;

  /// No description provided for @settingsReceipts.
  ///
  /// In id, this message translates to:
  /// **'Struk'**
  String get settingsReceipts;

  /// No description provided for @settingsHeader.
  ///
  /// In id, this message translates to:
  /// **'Kepala'**
  String get settingsHeader;

  /// No description provided for @settingsFooter.
  ///
  /// In id, this message translates to:
  /// **'Kaki'**
  String get settingsFooter;

  /// No description provided for @settingsServer.
  ///
  /// In id, this message translates to:
  /// **'Server'**
  String get settingsServer;

  /// No description provided for @settingsThisDevice.
  ///
  /// In id, this message translates to:
  /// **'Perangkat ini'**
  String get settingsThisDevice;

  /// No description provided for @settingsAddTablet.
  ///
  /// In id, this message translates to:
  /// **'Tambah tablet'**
  String get settingsAddTablet;

  /// No description provided for @settingsSignOut.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get settingsSignOut;

  /// No description provided for @settingsDisconnect.
  ///
  /// In id, this message translates to:
  /// **'Putuskan'**
  String get settingsDisconnect;

  /// No description provided for @settingsDisconnectConfirm.
  ///
  /// In id, this message translates to:
  /// **'Putuskan perangkat ini?'**
  String get settingsDisconnectConfirm;

  /// No description provided for @printerNew.
  ///
  /// In id, this message translates to:
  /// **'Tambah printer'**
  String get printerNew;

  /// No description provided for @printerPaperWidth.
  ///
  /// In id, this message translates to:
  /// **'Lebar kertas'**
  String get printerPaperWidth;

  /// No description provided for @printerWhatItPrints.
  ///
  /// In id, this message translates to:
  /// **'Fungsi cetak'**
  String get printerWhatItPrints;

  /// No description provided for @printerInUse.
  ///
  /// In id, this message translates to:
  /// **'Terpakai'**
  String get printerInUse;

  /// No description provided for @printerRemoveConfirm.
  ///
  /// In id, this message translates to:
  /// **'Hapus {name}?'**
  String printerRemoveConfirm(String name);

  /// No description provided for @guestScanTitle.
  ///
  /// In id, this message translates to:
  /// **'Pindai untuk memesan'**
  String get guestScanTitle;

  /// No description provided for @guestMenuTitle.
  ///
  /// In id, this message translates to:
  /// **'Menu'**
  String get guestMenuTitle;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(lookupAppStrings(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

AppStrings lookupAppStrings(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppStringsEn();
    case 'id':
      return AppStringsId();
  }

  throw FlutterError(
    'AppStrings.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
