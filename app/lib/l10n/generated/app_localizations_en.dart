// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppStringsEn extends AppStrings {
  AppStringsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mise';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDone => 'Done';

  @override
  String get commonSave => 'Save changes';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonName => 'Name';

  @override
  String get commonAddress => 'Address';

  @override
  String get commonPort => 'Port';

  @override
  String get commonPrice => 'Price';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonSubtotal => 'Subtotal';

  @override
  String get commonNote => 'Note';

  @override
  String get commonReason => 'Reason';

  @override
  String get commonAmount => 'Amount';

  @override
  String get commonReference => 'Reference';

  @override
  String get commonDescription => 'Description';

  @override
  String get commonCategory => 'Category';

  @override
  String get commonPhoto => 'Photo';

  @override
  String get commonOptions => 'Options';

  @override
  String get commonTags => 'Tags';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonCouldNotLoad => 'Could not load this';

  @override
  String get commonTest => 'Test';

  @override
  String get commonEarlier => 'Earlier';

  @override
  String get commonLater => 'Later';

  @override
  String get commonAll => 'All';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInUsername => 'Username';

  @override
  String get signInPin => 'PIN';

  @override
  String get signInUseDifferentServer => 'Use a different server';

  @override
  String get connectTitle => 'Connect to your server';

  @override
  String get connectAction => 'Connect';

  @override
  String get connectOnThisNetwork => 'On this network';

  @override
  String get connectSubtitle => 'Restaurant management';

  @override
  String get connectSubtitleLong =>
      'Point this device at the computer running your restaurant.';

  @override
  String get connectFooter =>
      'Free forever. Your data stays on your own machine.';

  @override
  String get connectServerHelper =>
      'Running the server on this computer? Leave this as it is.';

  @override
  String get connectRunOnThisComputer => 'Run the restaurant on this computer';

  @override
  String get connectRunOnThisComputerHint =>
      'Sets everything up here. Tablets and the kitchen screen then join this machine over your wi-fi.';

  @override
  String get connectScanCode => 'Scan the code';

  @override
  String get connectServerAddress => 'Server address';

  @override
  String get connectOr => 'or';

  @override
  String get connectScanPointAtCode => 'Point at the code';

  @override
  String get connectScanTypeInstead => 'Type it instead';

  @override
  String get setupTitle => 'Set up your restaurant';

  @override
  String get kdsOnThePass => 'On the pass';

  @override
  String get kdsNothingOnThePass => 'Nothing on the pass';

  @override
  String kdsCouldNotUpdate(String error) {
    return 'Could not update: $error';
  }

  @override
  String get navPos => 'Till';

  @override
  String get navKds => 'Kitchen';

  @override
  String get navManager => 'Manager';

  @override
  String get navSignOut => 'Sign out';

  @override
  String get navSwitchShell => 'Switch shell';

  @override
  String get floorTitle => 'Floor';

  @override
  String get floorHint => 'Tap a table to open or pick up its bill.';

  @override
  String get floorNoTables => 'No tables set up';

  @override
  String get floorTakeaway => 'Takeaway';

  @override
  String get floorOpenBill => 'Open bill';

  @override
  String get floorHowManyGuests => 'How many guests?';

  @override
  String floorSeatTable(String label) {
    return 'Seat $label';
  }

  @override
  String floorCouldNotOpen(String error) {
    return 'Could not open the table: $error';
  }

  @override
  String floorCouldNotStart(String error) {
    return 'Could not start the order: $error';
  }

  @override
  String get floorInUse => 'In use';

  @override
  String get orderBackToFloor => 'Back to the floor';

  @override
  String get orderNothingHere => 'Nothing in here';

  @override
  String get orderMenuEmpty => 'The menu is empty';

  @override
  String get orderBillGone => 'This bill is gone';

  @override
  String orderCouldNotAdd(String error) {
    return 'Could not add that: $error';
  }

  @override
  String get orderSoldOut => '86';

  @override
  String get orderAddToBill => 'Add to bill';

  @override
  String get orderNoteForKitchen => 'Note for the kitchen';

  @override
  String orderUpTo(int count) {
    return 'up to $count';
  }

  @override
  String moveBillTitle(String number) {
    return 'Move bill #$number';
  }

  @override
  String get moveBillNowhere => 'There is nowhere else to move it to.';

  @override
  String get moveBillWhereTo => 'Where to?';

  @override
  String get discountTitle => 'Discount';

  @override
  String get discountAmountOff => 'Amount off';

  @override
  String get discountNewSubtotal => 'New subtotal';

  @override
  String get discountReasonHint => 'Service and tax are worked out from this.';

  @override
  String get discountClear => 'Clear';

  @override
  String get paymentTitle => 'How are they paying?';

  @override
  String get paymentCashReceived => 'Cash received';

  @override
  String get paymentChangeDue => 'Change due';

  @override
  String get paymentPaid => 'Paid';

  @override
  String paymentTake(String amount) {
    return 'Take $amount';
  }

  @override
  String get paymentTakenSoFar => 'Taken so far';

  @override
  String get paymentRemovePayment => 'Remove this payment';

  @override
  String get paymentReceipt => 'Receipt';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String receiptPrintTo(String printer) {
    return 'Print to $printer';
  }

  @override
  String get shiftCloseTitle => 'Close your shift';

  @override
  String get shiftCashInDrawer => 'Cash in the drawer';

  @override
  String get shiftCashTaken => 'Cash taken';

  @override
  String get shiftCounted => 'Counted';

  @override
  String get shiftOpeningFloat => 'Opening float';

  @override
  String get shiftShouldBeInDrawer => 'Should be in the drawer';

  @override
  String get shiftHereIsWhat => 'Here is what it came to.';

  @override
  String get shiftClosed => 'Shift closed';

  @override
  String get summaryTakings => 'Takings';

  @override
  String get summaryHowItAddsUp => 'How it adds up';

  @override
  String get summaryHowItWasPaid => 'How it was paid';

  @override
  String get summaryTheDrawer => 'The drawer';

  @override
  String get summaryCancelled => 'Cancelled';

  @override
  String get menuItemsTitle => 'Items';

  @override
  String get menuItemsSubtitle => 'Everything you sell, and what it costs.';

  @override
  String get menuItemsNew => 'New item';

  @override
  String get menuItemsNone => 'No items yet';

  @override
  String get menuItemsNoMatch => 'Nothing matches';

  @override
  String get menuItemsAddFirst => 'Add your first item';

  @override
  String get menuItemsAddCategoryFirst => 'Add a category first';

  @override
  String get menuCategoriesTitle => 'Categories';

  @override
  String get menuCategoriesSubtitle =>
      'Sections of your menu. Their order is the order on the till.';

  @override
  String get menuCategoriesNew => 'New category';

  @override
  String get menuCategoriesNone => 'No categories yet';

  @override
  String get menuCategoriesAddFirst => 'Add your first category';

  @override
  String get menuCategoriesHidden => 'Hidden';

  @override
  String get menuCategoriesTileColour => 'Tile colour';

  @override
  String get menuCategoriesTileColourHint =>
      'Shown on the till so staff can find this section fast.';

  @override
  String get menuCategoriesVisible => 'Visible on the till';

  @override
  String get menuCategoriesStation => 'Who makes it';

  @override
  String get menuCategoriesStationHint =>
      'Dockets for this section print at that station.';

  @override
  String get menuItemOnTheMenu => 'On the menu';

  @override
  String get menuItemInStock => 'In stock';

  @override
  String get menuItemCode => 'Item code';

  @override
  String get menuItemPrepTime => 'Prep time';

  @override
  String get modifiersTitle => 'Modifiers';

  @override
  String get modifiersSubtitle =>
      'Choices you can attach to items. Define once, reuse everywhere.';

  @override
  String get modifiersNewGroup => 'New group';

  @override
  String get modifiersNone => 'No modifier groups yet';

  @override
  String get modifiersCreateFirst => 'Create your first group';

  @override
  String get modifiersAddOption => 'Add option';

  @override
  String get modifiersNoOptions => 'No options yet.';

  @override
  String get modifiersAllowMoreThanOne => 'Allow more than one';

  @override
  String get modifiersMustBeAnswered => 'Must be answered';

  @override
  String get modifiersMaxSelectable => 'Most that can be picked';

  @override
  String get modifiersPriceChange => 'Price change';

  @override
  String get modifiersOffered => 'Offered';

  @override
  String get tablesTitle => 'Tables';

  @override
  String get tablesSubtitle =>
      'Your floor. Group them into zones if the room has sections.';

  @override
  String get tablesNew => 'New table';

  @override
  String get tablesNone => 'No tables yet';

  @override
  String get tablesAddFirst => 'Add your first table';

  @override
  String get tablesNameOrNumber => 'Name or number';

  @override
  String get tablesSeats => 'Seats';

  @override
  String get tablesZone => 'Zone';

  @override
  String get tablesInUse => 'In use';

  @override
  String get tablesCodes => 'Table codes';

  @override
  String get tablesCodesNone => 'No tables in use yet.';

  @override
  String tablesDeleteConfirm(String label) {
    return 'Delete $label?';
  }

  @override
  String get staffTitle => 'Staff';

  @override
  String get staffSubtitle =>
      'Who can sign in, and what they are allowed to do.';

  @override
  String get staffAddSomeone => 'Add someone';

  @override
  String get staffNobodyYet => 'Nobody here yet';

  @override
  String get staffCanSignIn => 'Can sign in';

  @override
  String get staffWhatTheyCanDo => 'What they can do';

  @override
  String get staffYou => 'you';

  @override
  String get staffCannotDisableSelf =>
      'You cannot switch off your own account.';

  @override
  String get staffGiveNewPin => 'Give them a new PIN';

  @override
  String staffNewPinFor(String name) {
    return 'New PIN for $name';
  }

  @override
  String get staffSetPin => 'Set PIN';

  @override
  String staffRemoveConfirm(String name) {
    return 'Remove $name?';
  }

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsSubtitle => 'What each day came to.';

  @override
  String get reportsWhatSold => 'What sold';

  @override
  String get reportsWhoServedIt => 'Who served it';

  @override
  String get reportsByHour => 'BY HOUR';

  @override
  String get reportsExportCsv => 'Export CSV';

  @override
  String get reportsSaved => 'Report saved.';

  @override
  String reportsCouldNotSave(String error) {
    return 'Could not save: $error';
  }

  @override
  String get activityTitle => 'Activity';

  @override
  String get activitySubtitle =>
      'Discounts, voids and cancellations, with a name against each.';

  @override
  String get activityMoneyLeavingOnly => 'Money leaving only';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsRestaurant => 'Restaurant';

  @override
  String get settingsRestaurantHint =>
      'How your restaurant identifies itself and what it charges.';

  @override
  String get settingsCharges => 'Charges';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get settingsTaxRate => 'Tax rate';

  @override
  String get settingsTaxIncluded => 'Menu prices include tax';

  @override
  String get settingsServiceCharge => 'Service charge';

  @override
  String get settingsPrinters => 'Printers';

  @override
  String get settingsReceipts => 'Receipts';

  @override
  String get settingsHeader => 'Header';

  @override
  String get settingsFooter => 'Footer';

  @override
  String get settingsServer => 'Server';

  @override
  String get settingsThisDevice => 'This device';

  @override
  String get settingsAddTablet => 'Add a tablet';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsDisconnect => 'Disconnect';

  @override
  String get settingsDisconnectConfirm => 'Disconnect this device?';

  @override
  String get printerNew => 'Add a printer';

  @override
  String get printerPaperWidth => 'Paper width';

  @override
  String get printerWhatItPrints => 'What it prints';

  @override
  String get printerInUse => 'In use';

  @override
  String printerRemoveConfirm(String name) {
    return 'Remove $name?';
  }

  @override
  String get guestScanTitle => 'Scan to order';

  @override
  String get guestMenuTitle => 'Menu';

  @override
  String get signInErrorNoUsername => 'Enter your username.';

  @override
  String get signInErrorShortPin => 'Your PIN is at least 4 digits.';
}
