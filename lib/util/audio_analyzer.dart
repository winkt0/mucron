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
    double currentSmoothedFreq = freqToNote(frequencies[0]).freq;
    List<double> smoothed = List.filled(frequencies.length, currentSmoothedFreq);
    for (int i = 1; i < frequencies.length; i++) {
      double freq = freqToNote(frequencies[i]).freq;
      if (isProbablySameNote(currentSmoothedFreq, freq, frequencies, i)) {
        smoothed[i] = currentSmoothedFreq;
      } else if (i < frequencies.length - 1) {
        currentSmoothedFreq = freq;
        smoothed[i] = currentSmoothedFreq;
      } else {
        smoothed[i] = freq;
      }
    }
    return smoothed;
  }

  static bool isProbablySameNote(double currentSmoothedFreq, double freq, List<double> frequencies, int i) {
    return currentSmoothedFreq == freq ||
        _isSmallerMultiple(currentSmoothedFreq.round(), freq.round()) || 
        _isNoisyJump(freq, frequencies, i);
  }

  static bool _isSmallerMultiple(int a, int b) {
    int rest = a > b ? a % b : b % a;
    return rest <= 2 && a > b;
  }
  static bool _isNoisyJump(double freq, List<double> frequencies, int i) {
    return i + 2 < frequencies.length && _nextFrequenciesAreNotTheSame(freq, frequencies, i, 2);
  }

  static bool _nextFrequenciesAreNotTheSame(
    double freq,
    List<double> frequencies,
    int i,
    int nextAmount,
  ) {
    for (int testI = i; testI < i + nextAmount; testI++) {
      if (freqToNote(frequencies[testI]).freq != freq) return true;
    }
    return false;
  }
}
