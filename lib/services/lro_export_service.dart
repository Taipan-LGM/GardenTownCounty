import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/lro_case.dart';
import '../models/lro_notice.dart';

/// CSV / PDF / Excel (.xlsx) exports for LRO with optional date-range filter.
class LroExportService {
  final _dateFmt = DateFormat('yyyy-MM-dd');

  List<LroCase> filterCases(
    List<LroCase> cases, {
    DateTime? from,
    DateTime? to,
  }) {
    return cases.where((c) {
      final d = c.submissionDate ?? c.createdAt;
      if (from != null && d.isBefore(from.toUtc())) return false;
      if (to != null && d.isAfter(to.toUtc().add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  List<LroNotice> filterNotices(
    List<LroNotice> notices, {
    DateTime? from,
    DateTime? to,
  }) {
    return notices.where((n) {
      final d = n.publicationDate ?? n.createdAt;
      if (from != null && d.isBefore(from.toUtc())) return false;
      if (to != null && d.isAfter(to.toUtc().add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  String casesToCsv(List<LroCase> cases) {
    final rows = <List<String>>[
      [
        'Case Type',
        'Case Number',
        'Recording Number',
        'Member ID',
        'Subject',
        'Property Address',
        'Property Size',
        'Zoning',
        'Status',
        'Submission Date',
        'Published Date',
        'Approval Date',
        'Assigned Officer',
        'Fee Amount',
        'Notes',
        'Rejection Reason',
      ],
      ...cases.map(
        (c) => [
          c.caseType,
          c.caseNumber,
          c.recordingNumber ?? '',
          c.memberId,
          c.subjectName,
          c.propertyAddress,
          c.propertySize,
          c.zoningType,
          c.statusEnum.label,
          _fmt(c.submissionDate),
          _fmt(c.publishedDate),
          _fmt(c.approvalDate),
          c.assignedOfficer,
          c.feeAmount?.toStringAsFixed(2) ?? '',
          c.notes,
          c.rejectionReason,
        ],
      ),
    ];
    return _toCsv(rows);
  }

  String noticesToCsv(List<LroNotice> notices) {
    final rows = <List<String>>[
      [
        'Title',
        'Content',
        'Status',
        'Publication Date',
        'Expiry Date',
        'Member ID',
        'Related Case ID',
        'Created By',
      ],
      ...notices.map(
        (n) => [
          n.title,
          n.content,
          n.statusEnum.label,
          _fmt(n.publicationDate),
          _fmt(n.expiryDate),
          n.memberId ?? '',
          n.relatedCaseId ?? '',
          n.createdBy,
        ],
      ),
    ];
    return _toCsv(rows);
  }

  Future<Uint8List> casesToPdfSummary(List<LroCase> cases, {String title = 'LRO Cases Report'}) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              title,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text('Generated: ${_fmt(DateTime.now())} · ${cases.length} records'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Type',
              'Case #',
              'Subject',
              'Status',
              'Submitted',
              'Fee',
            ],
            data: cases
                .map(
                  (c) => [
                    c.caseType,
                    c.caseNumber,
                    c.subjectName,
                    c.statusEnum.label,
                    _fmt(c.submissionDate),
                    c.feeAmount?.toStringAsFixed(2) ?? '',
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> caseDetailToPdf(LroCase c, {String? memberName}) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'LRO Case Detail — ${c.caseType}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            _pdfRow('Case Number', c.caseNumber),
            _pdfRow('Recording Number', c.recordingNumber ?? '—'),
            _pdfRow('Member', memberName ?? c.memberId),
            _pdfRow('Subject', c.subjectName),
            _pdfRow('Property Address', c.propertyAddress),
            _pdfRow('Property Size', c.propertySize),
            _pdfRow('Zoning', c.zoningType),
            _pdfRow('Status', c.statusEnum.label),
            _pdfRow('Submission Date', _fmt(c.submissionDate)),
            _pdfRow('Published Date', _fmt(c.publishedDate)),
            _pdfRow('Approval Date', _fmt(c.approvalDate)),
            _pdfRow('Assigned Officer', c.assignedOfficer),
            _pdfRow('Fee Amount', c.feeAmount?.toStringAsFixed(2) ?? '—'),
            _pdfRow('Notes', c.notes),
            if (c.rejectionReason.isNotEmpty)
              _pdfRow('Rejection Reason', c.rejectionReason),
          ],
        ),
      ),
    );
    return doc.save();
  }

  Future<Uint8List> noticesToPdf(List<LroNotice> notices) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'LRO Public Notices Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text('Generated: ${_fmt(DateTime.now())} · ${notices.length} notices'),
          pw.SizedBox(height: 12),
          ...notices.map(
            (n) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    n.title,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '${n.statusEnum.label} · ${_fmt(n.publicationDate)}'
                    '${n.expiryDate != null ? ' → ${_fmt(n.expiryDate)}' : ''}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(n.content, style: const pw.TextStyle(fontSize: 10)),
                  pw.Divider(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Minimal OOXML .xlsx (Excel-compatible).
  Uint8List toXlsx(List<List<String>> rows, {String sheetName = 'Sheet1'}) {
    final sheetData = StringBuffer();
    sheetData.writeln(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
    );
    sheetData.writeln(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );
    sheetData.writeln('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      sheetData.writeln('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final ref = '${_colName(c)}${r + 1}';
        final val = _xmlEscape(rows[r][c]);
        sheetData.writeln(
          '<c r="$ref" t="inlineStr"><is><t>$val</t></is></c>',
        );
      }
      sheetData.writeln('</row>');
    }
    sheetData.writeln('</sheetData></worksheet>');

    final contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';

    final rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

    final wbRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''';

    final workbook = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="${_xmlEscape(sheetName)}" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';

    final archive = Archive();
    void add(String name, String text) {
      final bytes = utf8.encode(text);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('xl/workbook.xml', workbook);
    add('xl/_rels/workbook.xml.rels', wbRels);
    add('xl/worksheets/sheet1.xml', sheetData.toString());

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  Uint8List casesToXlsx(List<LroCase> cases) {
    final rows = <List<String>>[
      [
        'Case Type',
        'Case Number',
        'Subject',
        'Status',
        'Submission Date',
        'Published Date',
        'Fee',
        'Officer',
        'Address',
      ],
      ...cases.map(
        (c) => [
          c.caseType,
          c.caseNumber,
          c.subjectName,
          c.statusEnum.label,
          _fmt(c.submissionDate),
          _fmt(c.publishedDate),
          c.feeAmount?.toStringAsFixed(2) ?? '',
          c.assignedOfficer,
          c.propertyAddress,
        ],
      ),
    ];
    return toXlsx(rows, sheetName: 'LRO Cases');
  }

  Uint8List noticesToXlsx(List<LroNotice> notices) {
    final rows = <List<String>>[
      ['Title', 'Status', 'Publication Date', 'Expiry Date', 'Content'],
      ...notices.map(
        (n) => [
          n.title,
          n.statusEnum.label,
          _fmt(n.publicationDate),
          _fmt(n.expiryDate),
          n.content,
        ],
      ),
    ];
    return toXlsx(rows, sheetName: 'Notices');
  }

  Future<void> saveOrShare({
    required Uint8List bytes,
    required String fileName,
    String? textFallback,
  }) async {
    if (kIsWeb) {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save export',
        fileName: fileName,
        bytes: bytes,
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: fileName,
            mimeType: _mime(fileName),
          ),
        ],
        text: textFallback ?? fileName,
      ),
    );
  }

  Future<void> saveOrShareText({
    required String text,
    required String fileName,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    await saveOrShare(bytes: bytes, fileName: fileName);
  }

  String _fmt(DateTime? d) =>
      d == null ? '' : _dateFmt.format(d.toLocal());

  String _toCsv(List<List<String>> rows) {
    return rows.map((r) => r.map(_csvEscape).join(',')).join('\n');
  }

  String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  String _xmlEscape(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _colName(int index) {
    var n = index;
    var s = '';
    while (n >= 0) {
      s = String.fromCharCode(65 + (n % 26)) + s;
      n = (n ~/ 26) - 1;
    }
    return s;
  }

  String _mime(String name) {
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (name.endsWith('.csv')) return 'text/csv';
    return 'application/octet-stream';
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}
