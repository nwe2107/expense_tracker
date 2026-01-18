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
  CurrencyOption(code: 'ILS', symbol: '₪', name: 'Israeli Shekel'),
  CurrencyOption(code: 'USD', symbol: '\$', name: 'US Dollar'),
  CurrencyOption(code: 'EUR', symbol: '€', name: 'Euro'),
  CurrencyOption(code: 'GBP', symbol: '£', name: 'British Pound'),
  CurrencyOption(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
  CurrencyOption(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
  CurrencyOption(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
  CurrencyOption(code: 'CHF', symbol: 'CHF', name: 'Swiss Franc'),
  CurrencyOption(code: 'CNY', symbol: '¥', name: 'Chinese Yuan'),
  CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
  CurrencyOption(code: 'BRL', symbol: 'R\$', name: 'Brazilian Real'),
  CurrencyOption(code: 'MXN', symbol: 'MX\$', name: 'Mexican Peso'),
  CurrencyOption(code: 'SEK', symbol: 'kr', name: 'Swedish Krona'),
  CurrencyOption(code: 'NOK', symbol: 'kr', name: 'Norwegian Krone'),
  CurrencyOption(code: 'DKK', symbol: 'kr', name: 'Danish Krone'),
  CurrencyOption(code: 'ZAR', symbol: 'R', name: 'South African Rand'),
  CurrencyOption(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
  CurrencyOption(code: 'SAR', symbol: 'ر.س', name: 'Saudi Riyal'),
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
