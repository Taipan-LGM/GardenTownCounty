import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import '../models/lro_status_correction.dart' as sc;
import '../models/lro_notice_template.dart';

/// Parametric Public Notice renderer.
///
/// Builds the notice image entirely from [LroNoticeTemplateStyle] parameters
/// plus the Member's data — replacing the old "upload a template image and
/// overlay text" approach. Admin controls every visual aspect (font, colour,
/// alignment, background, borders, spacing, seal position) via the style.
///
/// Glyphs are drawn **directly** onto the canvas with [img.drawString] (no
/// intermediate transparent temp canvas + alpha composite), which is what
/// previously produced opaque black blocks behind every line of text.
class LroNoticeRenderer {
  // Fixed canvas (portrait). The Admin's design intent scales to this.
  static const int canvasW = 1000;
  static const int canvasH = 1400;
  static const double ptToPx = 3.0; // 1 pt ≈ 3 css px on this canvas

  const LroNoticeRenderer._();

  /// Renders and returns the personalized Public Notice as JPEG bytes.
  static Uint8List render({
    required LroNoticeTemplateStyle style,
    required String countyName,
    required String memberName,
    required String recordingNumber,
    required DateTime paymentDate,
    required List<sc.LroStatusCorrection> statusCorrections,
    Uint8List? sealBytes,
  }) {
    final image = img.Image(width: canvasW, height: canvasH);
    img.fill(image, color: _parseColor(style.backgroundColor));

    final margin = _paddingPx(style.padding);
    final textColor = _parseColor(style.fontColor);
    final placeholderColor = _parseColor(style.placeholderColor);
    final lineH = (style.fontSize * ptToPx * style.lineSpacing).round().clamp(8, 400);

    // Reserve a vertical band for the seal so body text never overlaps it.
    int topBand = 0;
    int bottomBand = 0;
    int sealH = 0;
    if (sealBytes != null && sealBytes.isNotEmpty) {
      sealH = (canvasW * 0.20).round().clamp(40, 400);
      if (style.sealPosition == LroNoticeSealPosition.top) {
        topBand = margin + sealH + 16;
      } else if (style.sealPosition == LroNoticeSealPosition.bottom) {
        bottomBand = margin + sealH + 16;
      }
    }
    final contentTop = margin + topBand;
    final contentBottom = canvasH - margin - bottomBand;

    // ── Outer border ─────────────────────────────────────────────────
    if (style.borderStyle != LroNoticeBorderStyle.none) {
      _drawBorder(image, style, margin, textColor);
    }

    var y = contentTop + (style.fontSize * ptToPx * 0.8).round();

    void drawTitle(String text) {
      final h = (style.fontSize * ptToPx * 1.7).round().clamp(12, 500);
      _drawText(image, text,
          color: textColor, heightPx: h, align: LroNoticeAlignment.center,
          bold: true, x: margin, maxW: canvasW - margin * 2, y: y);
      y += (h * 1.2).round();
    }

    bool _room() => y + lineH <= contentBottom;

    void drawLine(String text,
        {bool placeholder = false, bool checked = false}) {
      if (!_room()) return;
      final h = (style.fontSize * ptToPx).round().clamp(8, 400);
      if (checked) {
        _drawCheck(image, margin + 4, y + h ~/ 2, (h * 0.7).round());
      }
      _drawText(image, text,
          color: placeholder ? placeholderColor : textColor,
          heightPx: h,
          align: style.alignment,
          bold: style.bold,
          underline: style.underline,
          italic: style.italic,
          x: checked ? margin + h : margin,
          maxW: canvasW - margin * 2 - (checked ? h : 0),
          y: y);
      y += lineH;
    }

    // ── Header ───────────────────────────────────────────────────────
    drawTitle('PUBLIC NOTICE');
    y += (lineH * 0.3).round();
    drawLine(countyName);
    drawLine('Land Recording Office');
    y += (lineH * 0.4).round();

    // ── Member details ──────────────────────────────────────────────
    drawLine('This is to confirm that:');
    y += (lineH * 0.2).round();
    drawLine('Member: $memberName (C)');
    drawLine('Recording Number: $recordingNumber');
    drawLine('Date of Registration: ${DateFormat('dd/MM/yyyy').format(paymentDate)}');
    y += (lineH * 0.5).round();

    // ── Status Corrections (descriptions only, no dates) ─────────────
    drawLine('Is Status Corrected - 528:');
    final checked = statusCorrections.where((c) => c.isChecked).toList();
    if (checked.isEmpty) {
      drawLine('  (none)');
    } else {
      for (final c in checked) {
        final desc = c.description.trim();
        if (desc.isEmpty) continue;
        drawLine('  $desc', checked: true);
      }
    }

    // ── County Seal ──────────────────────────────────────────────────
    if (sealBytes != null && sealBytes.isNotEmpty) {
      final seal = img.decodeImage(sealBytes);
      if (seal != null) {
        _drawSeal(image, seal, style, margin, topBand, bottomBand);
      }
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }

  // ── drawing helpers ────────────────────────────────────────────────

  // Bundled bitmap fonts keyed by native pixel height.
  static final Map<int, img.BitmapFont> _fonts = {
    14: img.arial14,
    24: img.arial24,
    48: img.arial48,
  };

  static img.BitmapFont _nearestFont(int px) {
    img.BitmapFont best = img.arial24;
    var bestDiff = 1 << 30;
    for (final e in _fonts.entries) {
      final d = (e.key - px).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = e.value;
      }
    }
    return best;
  }

  static int _fontPx(img.BitmapFont f) {
    if (identical(f, img.arial14)) return 14;
    if (identical(f, img.arial24)) return 24;
    return 48;
  }

  static void _drawText(
    img.Image canvas,
    String text, {
    required img.Color color,
    required int heightPx,
    required LroNoticeAlignment align,
    required int x,
    required int maxW,
    required int y,
    bool bold = false,
    bool italic = false,
    bool underline = false,
  }) {
    if (text.isEmpty) return;
    // Paint glyphs directly onto the canvas (no temp canvas / composite),
    // so the text background stays the page colour.
    final font = _nearestFont(heightPx);
    final fh = _fontPx(font);
    final by = y + ((heightPx - fh) ~/ 2).clamp(0, heightPx);
    final approxW = (text.length * fh * 0.55).round();
    int bx;
    switch (align) {
      case LroNoticeAlignment.left:
        bx = x;
        break;
      case LroNoticeAlignment.right:
        bx = (x + maxW - approxW).clamp(0, canvas.width - 1);
        break;
      case LroNoticeAlignment.center:
        bx = (x + (maxW - approxW) ~/ 2).clamp(0, canvas.width - 1);
        break;
    }
    bx = bx.clamp(0, (canvas.width - 1).clamp(0, canvas.width));
    // Italic approximated with a slight rightward lean via per-glyph shear.
    final shear = italic ? (fh ~/ 8) : 0;
    img.drawString(canvas, text, font: font, x: bx + shear, y: by, color: color);
    if (bold) {
      img.drawString(canvas, text, font: font, x: bx + shear + 1, y: by, color: color);
    }
    if (underline) {
      img.drawLine(canvas,
          x1: bx, y1: by + fh - 2, x2: bx + approxW, y2: by + fh - 2,
          color: color, thickness: (fh / 12).clamp(1, 4).round());
    }
  }

  static void _drawCheck(img.Image canvas, int cx, int cy, int size) {
    final t = (size / 7).round().clamp(2, 5);
    final green = img.ColorRgb8(33, 150, 83);
    img.drawLine(canvas,
        x1: cx - size ~/ 2,
        y1: cy,
        x2: cx - size ~/ 6,
        y2: cy + size ~/ 3,
        color: green,
        thickness: t);
    img.drawLine(canvas,
        x1: cx - size ~/ 6,
        y1: cy + size ~/ 3,
        x2: cx + size ~/ 2,
        y2: cy - size ~/ 3,
        color: green,
        thickness: t);
  }

  static void _drawBorder(img.Image canvas, LroNoticeTemplateStyle style,
      int margin, img.Color color) {
    if (style.borderStyle == LroNoticeBorderStyle.none) return;
    final w = style.borderWidth.clamp(1, 10);
    img.drawRect(canvas,
        x1: margin ~/ 2,
        y1: margin ~/ 2,
        x2: canvasW - margin ~/ 2,
        y2: canvasH - margin ~/ 2,
        color: color,
        thickness: w);
    if (style.borderStyle == LroNoticeBorderStyle.dashed ||
        style.borderStyle == LroNoticeBorderStyle.dotted) {
      final step = style.borderStyle == LroNoticeBorderStyle.dotted ? w * 2 : w * 5;
      final bg = _parseColor(style.backgroundColor);
      for (var d = margin ~/ 2; d < canvasW - margin ~/ 2; d += step) {
        img.drawRect(canvas,
            x1: d, y1: margin ~/ 2, x2: d + step ~/ 2, y2: margin ~/ 2,
            color: bg, thickness: w);
        img.drawRect(canvas,
            x1: d, y1: canvasH - margin ~/ 2, x2: d + step ~/ 2,
            y2: canvasH - margin ~/ 2, color: bg, thickness: w);
      }
      for (var d = margin ~/ 2; d < canvasH - margin ~/ 2; d += step) {
        img.drawRect(canvas,
            x1: margin ~/ 2, y1: d, x2: margin ~/ 2, y2: d + step ~/ 2,
            color: bg, thickness: w);
        img.drawRect(canvas,
            x1: canvasW - margin ~/ 2, y1: d,
            x2: canvasW - margin ~/ 2, y2: d + step ~/ 2, color: bg, thickness: w);
      }
    }
  }

  static void _drawSeal(img.Image canvas, img.Image seal,
      LroNoticeTemplateStyle style, int margin, int topBand, int bottomBand) {
    final maxW = (canvasW * 0.20).round().clamp(40, 400);
    final scale = maxW / seal.width;
    final sealW = maxW;
    final sealH = (seal.height * scale).round();
    final resized = img.copyResize(seal, width: sealW, height: sealH);
    int dstX;
    int dstY;
    switch (style.sealPosition) {
      case LroNoticeSealPosition.top:
        dstX = ((canvasW - sealW) ~/ 2).clamp(0, canvasW - 1);
        dstY = margin;
        break;
      case LroNoticeSealPosition.bottom:
        dstX = ((canvasW - sealW) ~/ 2).clamp(0, canvasW - 1);
        dstY = (canvasH - sealH - margin).clamp(0, canvasH - 1);
        break;
      case LroNoticeSealPosition.left:
        dstX = margin;
        dstY = ((canvasH - sealH) ~/ 2).clamp(0, canvasH - 1);
        break;
      case LroNoticeSealPosition.right:
        dstX = (canvasW - sealW - margin).clamp(0, canvasW - 1);
        dstY = ((canvasH - sealH) ~/ 2).clamp(0, canvasH - 1);
        break;
    }
    img.compositeImage(canvas, resized, dstX: dstX, dstY: dstY, blend: img.BlendMode.alpha);
  }

  static int _paddingPx(String padding) {
    switch (padding) {
      case 'small':
        return 40;
      case 'large':
        return 120;
      case 'medium':
      default:
        return 80;
    }
  }

  static img.Color _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) {
      final r = int.parse(h.substring(0, 2), radix: 16);
      final g = int.parse(h.substring(2, 4), radix: 16);
      final b = int.parse(h.substring(4, 6), radix: 16);
      return img.ColorRgb8(r, g, b);
    }
    if (h.length == 8) {
      final r = int.parse(h.substring(0, 2), radix: 16);
      final g = int.parse(h.substring(2, 4), radix: 16);
      final b = int.parse(h.substring(4, 6), radix: 16);
      final a = int.parse(h.substring(6, 8), radix: 16);
      return img.ColorRgba8(r, g, b, a);
    }
    return img.ColorRgb8(20, 20, 20);
  }
}
