// lib/services/bulk_import/pdf_table_extractor.dart
//
// Geometry-only half of PDF support for the Dynamic Bulk Import Engine.
// Turns a text-based, table-formatted PDF into the exact same shape the
// rest of the engine already understands — `List<List<String>>`, one
// inner list per table row, cell text in column order — so
// `DynamicImportParser` can run its EXISTING header-detection, alias
// matching and row-building against it exactly like it already does for
// Excel sheets and CSV rows (see `parsePdf` in dynamic_import_parser.dart).
// This file knows nothing about `ModuleImportConfig`, Firestore, or field
// aliases — it only knows how to go from PDF bytes to a plain table of
// strings.
//
// No native/platform-specific code: `syncfusion_flutter_pdf` is pure Dart,
// so this works on Flutter Web and Windows desktop exactly like the rest
// of this app's bulk-import (same reach as the `excel` package already
// used for the Excel path). Add to pubspec.yaml:
//   syncfusion_flutter_pdf: ^28.1.33
//
// ── Approach ("stream"/gap-based table reconstruction — the same idea
//    tools like `pdftotext -layout` / Camelot's stream mode use) ─────────
//   1. Read every page's text as lines-of-words, each word carrying its
//      bounding box (Syncfusion's `PdfTextExtractor` gives us this
//      without any OCR — it's reading the PDF's real text layer).
//   2. Look at the lines that "look tabular" (>= 3 words, at least one
//      numeric/currency token) and take the union of every word's
//      horizontal span across ALL of them. The gaps left over in that
//      union are the column separators. This works even though numeric
//      columns are right-aligned (so a word's *left* edge alone isn't a
//      reliable column signal on its own — the *occupied span*, unioned
//      across every row, is).
//   3. Every line in the document (not just the "tabular-looking" ones,
//      so short continuation lines aren't excluded) has its words
//      bucketed into those column spans, producing one row per line.
//   4. Continuation lines — a wrapped product name spilling onto the next
//      line with every other column blank — are merged back into the row
//      above (multiline product names).
//   5. Page-number and "Total"/"Subtotal" footer lines are dropped here,
//      since they're a PDF-specific artifact Excel/CSV files don't have.
//      Repeated per-page column headers are deliberately left for the
//      caller (`DynamicImportParser.parsePdf`) to strip, since only it
//      knows — via the module's own alias matching — which row the real
//      header is.
//
// This is a best-effort heuristic reconstruction, not a full PDF table
// grammar. It's tuned against standard single-table reports like this
// project's Stock Summary Report exports. `_columnMergeGapPt` is the one
// knob to widen/narrow if a differently-formatted PDF ever splits a
// single column in two, or merges two columns into one.

import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Thrown when a PDF has no extractable text at all (i.e. it's a scan /
/// image-only PDF, or every page failed to yield a text layer). Caught by
/// `DynamicImportParser.parsePdf`, which turns it into the exact
/// user-facing message the import screen shows.
class ScannedPdfException implements Exception {
  final String message;
  const ScannedPdfException(this.message);
  @override
  String toString() => message;
}

class PdfTableExtractor {
  PdfTableExtractor._();

  /// Two words' horizontal spans are merged into the same "occupied
  /// block" if the gap between them is under this many PDF points
  /// (1 pt = 1/72"). Whatever whitespace is left over BETWEEN blocks is
  /// read as a real column separator.
  static const double _columnMergeGapPt = 10.0;

  /// Total non-whitespace characters, across the whole document, below
  /// which the PDF is treated as having no real text layer (i.e. a
  /// scanned/image PDF with no OCR text layer at all).
  static const int _minExtractableChars = 20;

  static final RegExp _numericToken =
  RegExp(r'^[₹$€£]?\s*-?[\d,]+(\.\d+)?%?$');
  static final RegExp _pageNumberRow =
  RegExp(r'^page\s*\d+(\s*(of|/)\s*\d+)?$', caseSensitive: false);
  static final RegExp _totalRowLabel =
  RegExp(r'^(grand\s+)?(sub\s*)?total:?$', caseSensitive: false);

  // ── Letterhead / company-header noise ───────────────────────────────────
  // Business report exports (like this project's Stock Summary Report)
  // routinely print a company letterhead — name, address, phone, email,
  // GSTIN/tax ID — above the actual table. Those lines often contain
  // numeric-looking tokens (a 10-digit phone number, a tax ID) that used to
  // get misread as table data: they'd count as "looks tabular" and feed
  // `_detectColumns`, whose spans then merge with the real table's
  // price/quantity columns and collapse what should be 6-7 distinct
  // columns into far fewer. Once that happens, header labels that used to
  // sit in their own column (e.g. "Item Name") get bucketed together with
  // neighboring labels, and nothing downstream can tell them apart.
  // Recognizing and dropping letterhead lines outright — the same way
  // page-number/Total footer lines already are — fixes this at the source
  // instead of trying to patch around it after the fact.
  static final RegExp _emailToken = RegExp(r'\S+@\S+\.\S+');
  static final RegExp _longDigitRun =
  RegExp(r'(?<![\d.,])\d{7,}(?![\d.,])'); // phone numbers, not ₹ amounts
  static final RegExp _gstinWord = RegExp(r'\bgstin\b', caseSensitive: false);
  static final RegExp _phoneLabel =
  RegExp(r'\bphone\s*no\b', caseSensitive: false);

  static bool _isLetterheadRow(List<_Word> words) {
    final text = words.map((w) => w.text).join(' ');
    return _emailToken.hasMatch(text) ||
        _gstinWord.hasMatch(text) ||
        _phoneLabel.hasMatch(text) ||
        _longDigitRun.hasMatch(text);
  }

  /// Entry point. Throws [ScannedPdfException] if [bytes] has no usable
  /// text layer. Otherwise returns one `List<String>` per detected table
  /// row, in document (page, then top-to-bottom) order, with:
  ///  - page-number / total / grand-total footer rows already removed
  ///  - multi-line product/item cells already merged into one row
  /// Repeated per-page column headers are intentionally NOT removed here
  /// — see file header comment.
  static List<List<String>> extractRows(Uint8List bytes) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);

      // ── Scanned-PDF guard ────────────────────────────────────────────
      final fullText = _safeExtractFullText(extractor, document);
      if (fullText.replaceAll(RegExp(r'\s'), '').length <
          _minExtractableChars) {
        throw const ScannedPdfException(
          'Scanned PDFs are not supported. Please upload a text-based PDF '
              'or Excel/CSV file.',
        );
      }

      // ── Gather every line (with word bounding boxes) from every page ──
      final List<List<_Word>> lines = [];
      for (var p = 0; p < document.pages.count; p++) {
        final pageLines = extractor.extractTextLines(
          startPageIndex: p,
          endPageIndex: p,
        );
        for (final line in pageLines) {
          final words = <_Word>[];
          for (final w in line.wordCollection) {
            final t = w.text.trim();
            if (t.isEmpty) continue;
            words.add(_Word(
              text: t,
              x0: w.bounds.left,
              x1: w.bounds.right,
            ));
          }
          if (words.isNotEmpty && !_isLetterheadRow(words)) lines.add(words);
        }
      }

      if (lines.isEmpty) {
        throw const ScannedPdfException(
          'Scanned PDFs are not supported. Please upload a text-based PDF '
              'or Excel/CSV file.',
        );
      }

      // ── Derive column spans from lines that look like table rows ──────
      final columns = _detectColumns(lines);

      // ── Bucket every line's words into those column spans ─────────────
      final rawRows = <List<String>>[
        for (final words in lines) _wordsToRow(words, columns),
      ];

      // ── Drop page-number / total footer rows (PDF-specific artifact) ──
      final withoutFooters = rawRows.where((r) => !_isFooterRow(r)).toList();

      // ── Merge wrapped multi-line product names back into their row ────
      return _mergeContinuationRows(withoutFooters, columns.length);
    } finally {
      document.dispose();
    }
  }

  static String _safeExtractFullText(
      PdfTextExtractor extractor,
      PdfDocument document,
      ) {
    try {
      return extractor.extractText();
    } catch (_) {
      // Some malformed/edge-case PDFs throw on whole-document extraction
      // but still yield text per page — fall back page-by-page before
      // concluding there's really no text layer at all.
      final buffer = StringBuffer();
      for (var p = 0; p < document.pages.count; p++) {
        try {
          buffer.write(
            extractor.extractText(startPageIndex: p, endPageIndex: p),
          );
        } catch (_) {
          // Ignore this single unreadable page — judged by the rest of
          // the document.
        }
      }
      return buffer.toString();
    }
  }

  // ── Column detection (gap / "stream" method) ────────────────────────────
  static List<_Interval> _detectColumns(List<List<_Word>> lines) {
    final spans = <_Interval>[];
    for (final words in lines) {
      // Requiring at least TWO numeric-looking tokens (not just one) is
      // deliberate: a genuine table row in a report like this has several
      // numeric columns (price, quantity, stock value, ...), while a
      // letterhead/address line usually carries at most one incidental
      // number (a street number, a lone digit) alongside plain text. A
      // single-numeric-token line's word spread — the address block's
      // comma-separated text is a real example — can otherwise span the
      // exact gap between two legitimate table columns and cause them to
      // be merged into one, which then makes the header row's cells
      // combine multiple field labels together (see file header comment).
      final numericTokenCount =
          words.where((w) => _numericToken.hasMatch(w.text)).length;
      final looksTabular = words.length >= 3 && numericTokenCount >= 2;
      if (!looksTabular) continue;
      for (final w in words) {
        spans.add(_Interval(w.x0, w.x1));
      }
    }

    // Fallback for an unusually sparse table where no single line looked
    // "tabular enough" — use every word in the document instead of giving
    // up on column detection entirely.
    final source = spans.isNotEmpty
        ? spans
        : [
      for (final words in lines)
        for (final w in words) _Interval(w.x0, w.x1),
    ];

    if (source.isEmpty) return const [];

    source.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_Interval>[source.first.copy()];
    for (final iv in source.skip(1)) {
      final last = merged.last;
      if (iv.start <= last.end + _columnMergeGapPt) {
        if (iv.end > last.end) last.end = iv.end;
      } else {
        merged.add(iv.copy());
      }
    }
    return merged;
  }

  static List<String> _wordsToRow(List<_Word> words, List<_Interval> columns) {
    if (columns.isEmpty) {
      return [words.map((w) => w.text).join(' ')];
    }
    final cells = List<StringBuffer>.generate(
      columns.length,
          (_) => StringBuffer(),
    );
    for (final w in words) {
      final center = (w.x0 + w.x1) / 2;
      final col = _columnIndexFor(center, columns);
      if (cells[col].isNotEmpty) cells[col].write(' ');
      cells[col].write(w.text);
    }
    return cells.map((b) => b.toString().trim()).toList();
  }

  static int _columnIndexFor(double x, List<_Interval> columns) {
    for (var i = 0; i < columns.length; i++) {
      if (x >= columns[i].start && x <= columns[i].end) return i;
    }
    // Landed in the whitespace gutter between two columns (e.g. a
    // currency symbol sitting just outside its number's block) — assign
    // to whichever column's center it's closest to.
    var nearest = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < columns.length; i++) {
      final mid = (columns[i].start + columns[i].end) / 2;
      final dist = (x - mid).abs();
      if (dist < bestDist) {
        bestDist = dist;
        nearest = i;
      }
    }
    return nearest;
  }

  // ── Footer / page-number stripping ──────────────────────────────────────
  static bool _isFooterRow(List<String> cells) {
    final nonEmpty = cells.where((c) => c.trim().isNotEmpty).toList();
    if (nonEmpty.isEmpty) return true; // blank row

    if (nonEmpty.length == 1 &&
        _pageNumberRow.hasMatch(nonEmpty.first.trim())) {
      return true;
    }
    // A "Total" row: first non-empty cell is a total label, and the row's
    // remaining content is otherwise entirely numeric (matches e.g. a
    // trailing "Total 2329.5 2329.5 0 ₹18,05,964.00" summary line).
    if (_totalRowLabel.hasMatch(nonEmpty.first.trim()) &&
        nonEmpty
            .skip(1)
            .every((c) => _numericToken.hasMatch(c.trim()) || c.trim().isEmpty)) {
      return true;
    }
    return false;
  }

  // ── Multi-line product-name merging ─────────────────────────────────────
  // A row is treated as a continuation of the row above it when exactly
  // one column has content, that content doesn't itself look like a
  // number (a lone number is far more likely to be a genuine short row
  // than wrapped text), and the row above already looks "complete" (at
  // least half its columns are filled) — so a continuation line never
  // merges into an already-broken row.
  static List<List<String>> _mergeContinuationRows(
      List<List<String>> rows,
      int columnCount,
      ) {
    final minFilledForComplete = (columnCount * 0.5).ceil();
    final result = <List<String>>[];

    for (final row in rows) {
      final nonEmptyIdx = <int>[
        for (var i = 0; i < row.length; i++)
          if (row[i].trim().isNotEmpty) i,
      ];

      final previousLooksComplete = result.isNotEmpty &&
          result.last.where((c) => c.trim().isNotEmpty).length >=
              minFilledForComplete;

      final isContinuation = result.isNotEmpty &&
          nonEmptyIdx.length == 1 &&
          !_numericToken.hasMatch(row[nonEmptyIdx.first].trim()) &&
          previousLooksComplete;

      if (isContinuation) {
        final target = result.last;
        final idx = nonEmptyIdx.first;
        if (idx < target.length) {
          target[idx] =
          target[idx].isEmpty ? row[idx] : '${target[idx]} ${row[idx]}';
          continue;
        }
      }

      result.add(List<String>.from(row));
    }
    return result;
  }
}

class _Word {
  final String text;
  final double x0;
  final double x1;
  const _Word({required this.text, required this.x0, required this.x1});
}

class _Interval {
  double start;
  double end;
  _Interval(this.start, this.end);
  _Interval copy() => _Interval(start, end);
}