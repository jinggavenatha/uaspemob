import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  static Future<void> init() async {
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
  }
}
