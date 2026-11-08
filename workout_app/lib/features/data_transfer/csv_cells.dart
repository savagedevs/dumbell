import 'package:csv/csv.dart';

/// Escape spreadsheet formulas and escape the escape character itself, so
/// restoring a backup never changes an original leading apostrophe.
String safeSpreadsheetCell(String value) =>
    _needsEscape(value) ? "'$value" : value;

bool _needsEscape(String value) =>
    value.startsWith("'") ||
    RegExp(r'^[\s\x00-\x1f]*[=+@-]').hasMatch(value) ||
    value.startsWith('\t') ||
    value.startsWith('\r') ||
    value.startsWith('\n');

String restoreSpreadsheetCell(String value) {
  if (value.startsWith("'") && _needsEscape(value.substring(1))) {
    return value.substring(1);
  }
  if (_needsEscape(value)) {
    throw const FormatException(
      'An unsafe or invalid spreadsheet cell was found.',
    );
  }
  return value;
}

String encodeCsvRows(List<List<String>> rows) => Csv(autoDetect: false)
    .encode(rows.map((row) => row.map(safeSpreadsheetCell).toList()).toList());

/// Strict RFC4180 quoting. Some spreadsheet decoders silently accept truncated
/// quoted cells; backup imports must reject them before any data is offered.
List<List<String>> decodeCsvRows(String input, {int maxRows = 100000}) {
  final rows = <List<String>>[];
  var row = <String>[];
  var cell = StringBuffer();
  var quoted = false;
  var closedQuote = false;
  var started = false;
  void endCell() {
    if (cell.length > 16384) {
      throw const FormatException('A CSV cell is too long.');
    }
    row.add(restoreSpreadsheetCell(cell.toString()));
    cell = StringBuffer();
    closedQuote = false;
    started = false;
  }

  void endRow() {
    endCell();
    rows.add(row);
    row = <String>[];
    if (rows.length > maxRows) {
      throw const FormatException('This CSV has too many rows.');
    }
  }

  if (input.startsWith('\ufeff')) input = input.substring(1);
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
          closedQuote = true;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == ',') {
      endCell();
    } else if (ch == '\r' || ch == '\n') {
      if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      endRow();
    } else if (ch == '"' && !started && !closedQuote) {
      quoted = true;
      started = true;
    } else {
      if (closedQuote || ch == '"') {
        throw const FormatException('Invalid CSV quoting.');
      }
      cell.write(ch);
      started = true;
    }
  }
  if (quoted) throw const FormatException('The CSV ends inside a quoted cell.');
  if (started || closedQuote || cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}
