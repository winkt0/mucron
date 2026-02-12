import 'dart:math' as math;
import 'dart:typed_data';
import 'package:mucron/util/yin.dart';

List<double> convertLittleEndianToFloat64(dynamic data) {
  final bd = ByteData.sublistView(data);
  final n = data.lengthInBytes ~/ 4;
  final List<double> frame = List<double>.filled(n, 0.0, growable: false);
  for (int i = 0; i < n; i++) {
    frame[i] = bd.getFloat32(i * 4, Endian.little);
  }
  return frame;
}

(double?, double) detectPitch(List<double> frame, double sampleRate) {

  final nullReturn = (null, 0.0);
  final n = frame.length;
  if (n < 256) return nullReturn;
  if (frame.every((element) => element == 0.0)) return nullReturn;
  final x = frame;

  final minF = 50.0;
  final maxF = 1000.0;
  final minLag = (sampleRate / maxF).floor();
  final maxLag = math.min((sampleRate / minF).floor(), n - 1);
  if (maxLag <= minLag) return nullReturn;

  var (bestLag, cmndf) = Yin.yin(x, maxLag, 0.1);
  if (bestLag <= 0) return nullReturn;

  double refinedLag = Yin.parabolicInterpolation(cmndf, bestLag);
  if (refinedLag <= 0) return nullReturn;
  final freq = sampleRate / refinedLag;

  if (!freq.isFinite || freq.isNaN || freq < 20 || freq > 5000) {
    return nullReturn;
  }
  return (freq, 1 - cmndf[bestLag]);
}

class Note {
  final String name;
  final int octave;
  final double cents;
  final int midi;
  final double freq;
  Note(this.name, this.octave, this.cents, this.midi, this.freq);
}

Note freqToNote(double f, {double a4 = 440.0}) {
  final midi = 69 + 12 * (math.log(f / a4) / math.ln2);
  final nearest = midi.round();
  final cents = (midi - nearest) * 100;
  final name = noteName(nearest);
  final octave = (nearest ~/ 12) - 1;
  final freq = math.exp((nearest - 69) * math.ln2 / 12) * a4;

  return Note(name, octave, cents, nearest, freq);
}

String noteName(int i) {
  const names = [
    "C",
    "C#",
    "D",
    "D#",
    "E",
    "F",
    "F#",
    "G",
    "G#",
    "A",
    "A#",
    "B",
  ];
  return names[(i % 12 + 12) % 12];
}

double median(List<double> xs) {
  final t = [...xs]..sort();
  final m = t.length ~/ 2;
  return t.length.isOdd ? t[m] : 0.5 * (t[m - 1] + t[m]);
}
