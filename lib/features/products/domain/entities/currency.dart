// Values mirror the backend's `Currency` constants, so `.name` is exactly what
// the API accepts. [displayName] and [symbol] are for display only.
// ignore_for_file: constant_identifier_names

enum Currency {
  USD('United States Dollar', r'$'),
  EUR('Euro', '€'),
  GBP('British Pound', '£'),
  JPY('Japanese Yen', '¥'),
  CHF('Swiss Franc', 'CHf'),
  CAD('Canadian Dollar', r'C$'),
  AUD('Australian Dollar', r'A$'),
  NZD('New Zealand Dollar', r'NZ$'),

  SEK('Swedish Krona', 'kr'),
  NOK('Norwegian Krone', 'kr'),
  DKK('Danish Krone', 'kr'),
  PLN('Polish Zloty', 'zł'),
  CZK('Czech Koruna', 'Kč'),
  HUF('Hungarian Forint', 'Ft'),
  RON('Romanian Leu', 'lei'),
  BGN('Bulgarian Lev', 'лв'),

  MXN('Mexican Peso', r'$'),
  BRL('Brazilian Real', r'R$'),
  ARS('Argentine Peso', r'$'),
  CLP('Chilean Peso', r'$'),
  COP('Colombian Peso', r'$'),
  PEN('Peruvian Sol', 'S/'),
  UYU('Uruguayan Peso', r'$U'),

  CNY('Chinese Yuan', '¥'),
  HKD('Hong Kong Dollar', r'HK$'),
  SGD('Singapore Dollar', r'S$'),
  INR('Indian Rupee', '₹'),
  KRW('South Korean Won', '₩'),
  THB('Thai Baht', '฿'),
  IDR('Indonesian Rupiah', 'Rp'),
  MYR('Malaysian Ringgit', 'RM'),
  PHP('Philippine Peso', '₱'),
  VND('Vietnamese Dong', '₫'),

  AED('UAE Dirham', 'د.إ'),
  SAR('Saudi Riyal', 'ر.س'),
  ILS('Israeli New Shekel', '₪'),
  TRY('Turkish Lira', '₺'),
  ZAR('South African Rand', 'R'),
  EGP('Egyptian Pound', 'E£'),
  NGN('Nigerian Naira', '₦'),

  UAH('Ukrainian Hryvnia', '₴'),
  RUB('Russian Ruble', '₽');

  const Currency(this.displayName, this.symbol);

  final String displayName;
  final String symbol;

  /// "EUR — Euro (€)".
  String get label => '$name — $displayName ($symbol)';

  /// Null if [value] is not a known constant.
  static Currency? tryParse(String? value) {
    for (final currency in values) {
      if (currency.name == value) return currency;
    }
    return null;
  }
}
