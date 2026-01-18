class CurrencyOption {
  final String code;
  final String symbol;
  final String name;

  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.name,
  });

  String get displayLabel => '$code • $name';
}

const String defaultCurrencyCode = 'ILS';

const List<CurrencyOption> currencyOptions = [
  CurrencyOption(code: 'EUR', symbol: '€', name: 'Euro'),
  CurrencyOption(code: 'USD', symbol: '\$', name: 'US Dollar'),
  CurrencyOption(code: 'ILS', symbol: '₪', name: 'Israeli Shekel'),
  CurrencyOption(code: 'GBP', symbol: '£', name: 'British Pound'),
  CurrencyOption(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
  CurrencyOption(code: 'BGN', symbol: 'лв', name: 'Bulgarian Lev'),
  CurrencyOption(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real'),
  CurrencyOption(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
  CurrencyOption(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc'),
  CurrencyOption(code: 'CNY', symbol: '¥', name: 'Chinese Yuan'),
  CurrencyOption(code: 'CZK', symbol: 'Kč', name: 'Czech Koruna'),
  CurrencyOption(code: 'DKK', symbol: 'kr', name: 'Danish Krone'),
  CurrencyOption(code: 'HKD', symbol: 'HK\$', name: 'Hong Kong Dollar'),
  CurrencyOption(code: 'HUF', symbol: 'Ft', name: 'Hungarian Forint'),
  CurrencyOption(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah'),
  CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
  CurrencyOption(code: 'ISK', symbol: 'kr', name: 'Icelandic Krona'),
  CurrencyOption(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
  CurrencyOption(code: 'KRW', symbol: '₩', name: 'South Korean Won'),
  CurrencyOption(code: 'MXN', symbol: 'MX\$', name: 'Mexican Peso'),
  CurrencyOption(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit'),
  CurrencyOption(code: 'NOK', symbol: 'kr', name: 'Norwegian Krone'),
  CurrencyOption(code: 'NZD', symbol: 'NZ\$', name: 'New Zealand Dollar'),
  CurrencyOption(code: 'PHP', symbol: '₱', name: 'Philippine Peso'),
  CurrencyOption(code: 'PLN', symbol: 'zł', name: 'Polish Zloty'),
  CurrencyOption(code: 'RON', symbol: 'lei', name: 'Romanian Leu'),
  CurrencyOption(code: 'SEK', symbol: 'kr', name: 'Swedish Krona'),
  CurrencyOption(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar'),
  CurrencyOption(code: 'THB', symbol: '฿', name: 'Thai Baht'),
  CurrencyOption(code: 'TRY', symbol: '₺', name: 'Turkish Lira'),
  CurrencyOption(code: 'ZAR', symbol: 'R', name: 'South African Rand'),
];

CurrencyOption currencyOptionByCode(String code) {
  for (final option in currencyOptions) {
    if (option.code == code) return option;
  }
  for (final option in currencyOptions) {
    if (option.code == defaultCurrencyCode) return option;
  }
  return currencyOptions.first;
}
