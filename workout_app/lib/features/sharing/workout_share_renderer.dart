import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'workout_share_summary.dart';

abstract interface class WorkoutShareImageRenderer {
  Future<Uint8List> render({
    required WorkoutShareSummary summary,
    required WorkoutShareFormat format,
    Uint8List? photoBytes,
  });
}

/// Draws the final PNG directly, so preview and export use identical bytes.
/// All decoration is original Canvas geometry; catalogue artwork is never read.
class WorkoutShareRenderer implements WorkoutShareImageRenderer {
  const WorkoutShareRenderer();

  @override
  Future<Uint8List> render({
    required WorkoutShareSummary summary,
    required WorkoutShareFormat format,
    Uint8List? photoBytes,
  }) async {
    ui.Image? photo;
    ui.Picture? picture;
    ui.Image? image;
    try {
      if (photoBytes != null) {
        photo = await _decodePhoto(photoBytes);
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      _ShareArtwork(canvas, summary, format, photo).paint();
      picture = recorder.endRecording();
      image = await picture.toImage(format.width, format.height);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('The share image could not be encoded.');
      }
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image?.dispose();
      picture?.dispose();
      photo?.dispose();
    }
  }

  Future<ui.Image> _decodePhoto(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        math.min(1080 / descriptor.width, 1920 / descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}

class _ShareArtwork {
  _ShareArtwork(this.canvas, this.summary, this.format, this.photo);
  final Canvas canvas;
  final WorkoutShareSummary summary;
  final WorkoutShareFormat format;
  final ui.Image? photo;
  bool get story => format == WorkoutShareFormat.story;
  static const margin = 64.0;
  static const contentWidth = 952.0;

  void paint() {
    final bounds = Rect.fromLTWH(0, 0, 1080, format.height.toDouble());
    canvas.drawRect(bounds, Paint()..color = AppColors.background);
    _background();
    _brand();
    _text(
      summary.date.toUpperCase(),
      const Rect.fromLTWH(610, 67, 406, 42),
      fontSize: 27,
      color: AppColors.text,
      align: TextAlign.right,
      weight: FontWeight.w600,
    );
    _text(
      'WORKOUT / RECAP',
      Rect.fromLTWH(margin, story ? 181 : 131, contentWidth, 40),
      fontSize: 26,
      color: AppColors.lime,
      letterSpacing: 4,
      weight: FontWeight.w700,
    );
    _text(
      summary.title.toUpperCase(),
      Rect.fromLTWH(
        margin - 3,
        story ? 245 : 188,
        contentWidth,
        story ? 344 : 156,
      ),
      fontSize: story ? 112 : 78,
      minFontSize: story ? 82 : 62,
      maxLines: story ? 3 : 2,
      weight: FontWeight.w900,
      letterSpacing: -3.2,
      lineHeight: 1.03,
    );
    _stats();
    _highlights();
    _footer();
  }

  void _background() {
    final heroHeight = story ? 970.0 : 600.0;
    if (photo case final photo?) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, 1080, heroHeight),
        image: photo,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 1080, heroHeight),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, heroHeight),
            [
              AppColors.background.withValues(alpha: .68),
              AppColors.background.withValues(alpha: .76),
              AppColors.background,
            ],
            [0, .65, 1],
          ),
      );
    } else {
      // Oversized rep marks give the card an athletic motif without depicting
      // an unrecorded personal best or suggesting a fabricated trend.
      canvas.save();
      canvas.translate(820, story ? 470 : 290);
      canvas.rotate(-.29);
      for (var index = 0; index < 3; index++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(index * 88 - 100, -290, 52, 580),
            const Radius.circular(26),
          ),
          Paint()..color = AppColors.lime.withValues(alpha: .055),
        );
      }
      canvas.restore();
      canvas.drawCircle(
        Offset(1040, story ? 560 : 320),
        380,
        Paint()
          ..color = AppColors.lime.withValues(alpha: .09)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1080, 12),
      Paint()..color = AppColors.lime,
    );
  }

  void _brand() {
    final paint = Paint()..color = AppColors.lime;
    for (var index = 0; index < 3; index++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            margin + index * 11,
            69 + (index == 1 ? 0 : 7),
            6,
            index == 1 ? 29 : 15,
          ),
          const Radius.circular(3),
        ),
        paint,
      );
    }
    _text(
      'DUMBBELL',
      const Rect.fromLTWH(108, 62, 310, 44),
      fontSize: 33,
      weight: FontWeight.w900,
      letterSpacing: 2,
    );
  }

  void _stats() {
    final top = story ? 698.0 : 377.0;
    final height = story ? 224.0 : 177.0;
    final rect = Rect.fromLTWH(margin, top, contentWidth, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(28)),
      Paint()..color = AppColors.surface,
    );
    final columnWidths = [272.0, 334.0, 282.0];
    final values = [
      '${summary.completedSets}',
      summary.volume,
      summary.duration,
    ];
    final labels = [
      'COMPLETED SETS',
      'VOLUME (${summary.volumeUnit.toUpperCase()})',
      'DURATION',
    ];
    var left = margin + 28;
    for (var index = 0; index < values.length; index++) {
      _text(
        values[index],
        Rect.fromLTWH(
          left,
          top + (story ? 39 : 29),
          columnWidths[index] - 20,
          story ? 102 : 82,
        ),
        fontSize: story ? 92 : 72,
        minFontSize: 30,
        color: index == 0 ? AppColors.lime : AppColors.text,
        weight: FontWeight.w900,
        letterSpacing: -2.5,
      );
      _text(
        labels[index],
        Rect.fromLTWH(
          left + 2,
          top + (story ? 159 : 125),
          columnWidths[index] - 22,
          36,
        ),
        fontSize: 20,
        color: AppColors.muted,
        weight: FontWeight.w600,
        letterSpacing: 1.1,
      );
      if (index < values.length - 1) {
        canvas.drawLine(
          Offset(left + columnWidths[index] - 18, top + 35),
          Offset(left + columnWidths[index] - 18, top + height - 35),
          Paint()
            ..color = AppColors.elevated
            ..strokeWidth = 2,
        );
      }
      left += columnWidths[index];
    }
  }

  void _highlights() {
    final top = story ? 1012.0 : 604.0;
    final count = math.min(summary.highlights.length, story ? 5 : 3);
    final heading = !story && summary.highlights.length > count
        ? 'EXERCISE HIGHLIGHTS / $count OF ${summary.highlights.length}'
        : 'EXERCISE HIGHLIGHTS';
    _text(
      heading,
      Rect.fromLTWH(margin, top, contentWidth, 42),
      fontSize: 25,
      color: AppColors.muted,
      letterSpacing: 3,
      weight: FontWeight.w700,
    );
    final rowHeight = story ? 136.0 : 106.0;
    final start = top + 64;
    if (count == 0) {
      _text(
        'No completed sets\nrecorded.',
        Rect.fromLTWH(margin, start + 26, contentWidth, 180),
        fontSize: story ? 57 : 48,
        maxLines: 2,
        color: AppColors.text,
        weight: FontWeight.w700,
      );
      return;
    }
    for (var index = 0; index < count; index++) {
      final highlight = summary.highlights[index];
      final y = start + index * rowHeight;
      _text(
        (index + 1).toString().padLeft(2, '0'),
        Rect.fromLTWH(margin, y + 5, 67, 45),
        fontSize: 26,
        color: AppColors.lime,
        weight: FontWeight.w800,
      );
      _text(
        highlight.name,
        Rect.fromLTWH(margin + 79, y, contentWidth - 79, story ? 51 : 42),
        fontSize: story ? 38 : 32,
        minFontSize: story ? 32 : 28,
        weight: FontWeight.w800,
      );
      _text(
        '${highlight.details}  /  ${highlight.load}',
        Rect.fromLTWH(
          margin + 79,
          y + (story ? 55 : 46),
          contentWidth - 79,
          40,
        ),
        fontSize: story ? 26 : 24,
        minFontSize: 21,
        color: AppColors.muted,
      );
      canvas.drawLine(
        Offset(margin, y + rowHeight - 15),
        Offset(1016, y + rowHeight - 15),
        Paint()
          ..color = AppColors.elevated
          ..strokeWidth = 2,
      );
    }
    final remaining = summary.highlights.length - count;
    if (remaining > 0 && story) {
      _text(
        '+ $remaining more ${remaining == 1 ? 'movement' : 'movements'} logged',
        Rect.fromLTWH(
          margin + 79,
          start + count * rowHeight + 3,
          contentWidth - 79,
          39,
        ),
        fontSize: 24,
        color: AppColors.muted,
      );
    }
  }

  void _footer() {
    final top = format.height - (story ? 102.0 : 76.0);
    canvas.drawRect(
      Rect.fromLTWH(margin, top + 5, 7, 29),
      Paint()..color = AppColors.lime,
    );
    _text(
      'ONE SESSION. MORE MOMENTUM.',
      Rect.fromLTWH(margin + 23, top, contentWidth - 23, 45),
      fontSize: 25,
      weight: FontWeight.w800,
      letterSpacing: .7,
    );
    if (story) {
      _text(
        'COMPLETED SETS ONLY',
        Rect.fromLTWH(margin + 23, top + 47, contentWidth - 23, 34),
        fontSize: 18,
        color: AppColors.muted,
        letterSpacing: 1.6,
      );
    }
  }

  void _text(
    String text,
    Rect box, {
    required double fontSize,
    double? minFontSize,
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w500,
    int maxLines = 1,
    double letterSpacing = 0,
    double lineHeight = 1.15,
    TextAlign align = TextAlign.left,
  }) {
    TextPainter layout(double size) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: color,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          height: lineHeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: box.width);
    var size = fontSize;
    var painter = layout(size);
    while ((painter.didExceedMaxLines || painter.height > box.height) &&
        size > (minFontSize ?? fontSize)) {
      painter.dispose();
      size = math.max(size - 2, minFontSize ?? fontSize);
      painter = layout(size);
    }
    canvas.save();
    canvas.clipRect(box);
    painter.paint(canvas, box.topLeft);
    canvas.restore();
    painter.dispose();
  }
}
