import 'package:mucron/util/audio_util.dart';
import 'package:mucron/util/yin.dart';

class AudioAnalyzer {
  static List<double> analyze(
    List<double> audio,
    double sampleRate,
    int frameSize,
    int hopSize,
  ) {
    return Pyin.analyze(
      audio,
      sampleRate,
      frameSize: frameSize,
      hopSize: hopSize,
    ).frequencies;
  }

  static List<double> smooth(List<double> frequencies) {
    double current = freqToNote(frequencies[0]).freq;
    List<double> smoothed = List.filled(frequencies.length, current);
    for (int i = 1; i < frequencies.length; i++) {
      double freq = freqToNote(frequencies[i]).freq;
      if (current == freq || _isSmallerMultiple(current.round(), freq.round())) {
        smoothed[i] = current;
      } else if (i < frequencies.length - 1) {
        current = freq;
        smoothed[i] = current;
      } else {
        smoothed[i] = freq;
      }
    }
    return smoothed;
  }

  static bool _isSmallerMultiple(int a, int b) {
    int rest = a > b ? a % b : b % a;
    return rest <= 2 && a > b;
  }
}
