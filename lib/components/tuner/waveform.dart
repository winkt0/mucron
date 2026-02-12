import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:mucron/service/mic_stream_service.dart';

/// A lightweight, repaint-efficient mic waveform that reads Float32 PCM frames from EventChannel('com.example.mic_stream/audio').
class MicWaveform extends StatefulWidget {
  final double seconds;

  final int sampleRate;

  final double strokeWidth;

  // Vertical gain multiplier (1.0 = raw).
  final double gain;

  final Color waveColor;

  const MicWaveform({
    super.key,
    this.seconds = 2.0,
    this.sampleRate = 44100,
    this.strokeWidth = 1.5,
    this.gain = 1.0,
    this.waveColor = const Color(0xFF62A0EA),
  });

  @override
  State<MicWaveform> createState() => _MicWaveformState();
}

class _MicWaveformState extends State<MicWaveform> {
  late final int _capacity;
  late final Float32List _ring; // circular sample buffer
  int _writeIndex = 0;
  bool _filledOnce = false;

  double _absPeak = 1e-6;
  int _decayCounter = 0;

  @override
  void initState() {
    super.initState();
    _capacity = (widget.sampleRate * widget.seconds).round();
    _ring = Float32List(_capacity);
    MicStreamService.instance.addListener(_onBytes);
  }

  void _onBytes(dynamic data) {
    if (data is! Uint8List) return;
    final bd = ByteData.sublistView(data);
    final n = data.lengthInBytes ~/ 4;
    for (int i = 0; i < n; i++) {
      final s = bd.getFloat32(i * 4, Endian.little);
      _ring[_writeIndex] = s;
      _writeIndex++;
      if (_writeIndex >= _capacity) {
        _writeIndex = 0;
        _filledOnce = true;
      }
      final a = s.abs();
      if (a > _absPeak) _absPeak = a;
    }

    // Mild peak decay so scaling adapts over time
    _decayCounter += n;
    if (_decayCounter > widget.sampleRate ~/ 20) {
      // ~50 ms
      _absPeak *= 0.98;
      if (_absPeak < 1e-3) _absPeak = 1e-3;
      _decayCounter = 0;
    }

    if (mounted) setState(() {}); // Repaint
  }

  @override
  void dispose() {
    MicStreamService.instance.removeListener(_onBytes);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final writeIdx = _writeIndex;
    final filled = _filledOnce;
    final peak = _absPeak;

    return CustomPaint(
      painter: _WavePainter(
        ring: _ring,
        capacity: _capacity,
        writeIndex: writeIdx,
        filledOnce: filled,
        peak: peak,
        gain: widget.gain,
        waveColor: widget.waveColor,
        strokeWidth: widget.strokeWidth,
      ),
      size: Size.infinite,
    );
  }
}

class _WavePainter extends CustomPainter {
  final Float32List ring;
  final int capacity;
  final int writeIndex;
  final bool filledOnce;
  final double peak;
  final double gain;
  final Color waveColor;
  final double strokeWidth;

  const _WavePainter({
    required this.ring,
    required this.capacity,
    required this.writeIndex,
    required this.filledOnce,
    required this.peak,
    required this.gain,
    required this.waveColor,
    required this.strokeWidth,
  });

  (double, double) _findMinMax(int column, int step) {
    final newestIdx = (writeIndex - 1 - column * step);
    int start = newestIdx;
    int end = newestIdx - step + 1;
    int wrap(int i) {
      int r = i % capacity;
      if (r < 0) r += capacity;
      return r;
    }

    double sMin = 1e9, sMax = -1e9;
    for (int i = start; i >= end; i--) {
      final v = ring[wrap(i)];
      if (v < sMin) sMin = v;
      if (v > sMax) sMax = v;
    }

    return (sMin, sMax);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (capacity == 0 || size.width <= 1 || size.height <= 1) return;

    final total = filledOnce ? capacity : writeIndex;
    if (total <= 1) return;

    final width = size.width;
    final height = size.height;
    final cols = width.floor().clamp(1, total);
    final step = math.max(1, total ~/ cols);

    final midY = height / 2;
    final scale = (height * 0.45) / (peak * gain + 1e-6);

    final paint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    final path = Path();
    for (int c = 0; c < cols; c++) {
      var (sMin, sMax) = _findMinMax(c, step);
      final xi = width - 1 - c.toDouble();
      final y1 = (midY - sMin * scale * gain).clamp(0.0, height);
      final y2 = (midY - sMax * scale * gain).clamp(0.0, height);
      path.moveTo(xi, y1);
      path.lineTo(xi, y2);

      if (xi < 0) break;
    }

    final midPaint = Paint()
      ..color = waveColor.withOpacity(0.25)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, midY), Offset(width, midY), midPaint);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) {
    return old.writeIndex != writeIndex ||
        old.filledOnce != filledOnce ||
        old.peak != peak ||
        old.gain != gain ||
        old.waveColor != waveColor ||
        old.strokeWidth != strokeWidth ||
        old.capacity != capacity ||
        old.ring != ring;
  }
}
