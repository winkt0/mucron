import 'dart:math';
import 'dart:typed_data';

Uint8List frequenciesToPcmBytes(
  List<double> frequencies, {
  double durationSeconds = 0.5,
  int sampleRate = 44100,
  int volume = 10000,
}) {
  final List<int> byteList = [];
  final int sampleCount = (sampleRate * durationSeconds).floor();

  double freq;
  int freqIndex = -1;
  for (int i = 0; freqIndex + 1 < frequencies.length; i++) {
    if (i % (sampleCount / frequencies.length).ceil() == 0) freqIndex++;
    freq = frequencies[freqIndex];
    final t = i / sampleRate;
    double phase = 2 * pi * freq * t;
    if (freqIndex > 0) {
      phase = smoothFrequencyTransition(frequencies, freqIndex, freq, phase, t);
    }
    final double sample = volume * sin(phase);

    // Little-endian bytes
    byteList.add(sample.round() & 0xFF);
    byteList.add((sample.round() >> 8) & 0xFF);
  }

  return Uint8List.fromList(byteList);
}

// Sudden transitions between frequencies create crackling sounds or loud bips ()
double smoothFrequencyTransition(List<double> frequencies, int freqIndex, double freq, double phase, double t) {
  final oldFreq = frequencies[freqIndex - 1];
  if (freq != oldFreq) {
    phase += 2 * pi * oldFreq * t;
  }
  return phase;
}

Uint8List makeWav(
  Uint8List pcm, {
  int sampleRate = 44100,
  int bitRate = 16,
  int numChannels = 1,
}) {
  final dataSize = pcm.length;
  final numHeaderBytes = 44;
  final riffSize = numHeaderBytes + dataSize - 8; // - 8 is obligatory

  final header = BytesBuilder();

  header.add("RIFF".codeUnits);
  header.add([
    riffSize & 0xFF,
    (riffSize >> 8) & 0xFF,
    (riffSize >> 16) & 0xFF,
    (riffSize >> 24) & 0xFF,
  ]);

  header.add("WAVE".codeUnits);
  header.add("fmt ".codeUnits);
  header.add([0x10, 0x00, 0x00, 0x00]); // PCM fmt chunk size
  header.add([0x01, 0x00]); // PCM format
  header.add([numChannels & 0xFF, (numChannels & 0xFF00) >> 8]);

  header.add([
    sampleRate & 0xFF,
    (sampleRate >> 8) & 0xFF,
    (sampleRate >> 16) & 0xFF,
    (sampleRate >> 24) & 0xFF,
  ]);

  final byteRate = sampleRate * numChannels * bitRate ~/ 8;
  header.add([
    byteRate & 0xFF,
    (byteRate >> 8) & 0xFF,
    (byteRate >> 16) & 0xFF,
    (byteRate >> 24) & 0xFF,
  ]);

  final blockAlign = numChannels * bitRate ~/ 8;
  header.add([blockAlign & 0xFF, (blockAlign & 0xFF00) >> 8]);

  header.add([bitRate & 0xFF, (bitRate & 0xFF00) >> 8]);
  header.add("data".codeUnits);

  header.add([
    dataSize & 0xFF,
    (dataSize >> 8) & 0xFF,
    (dataSize >> 16) & 0xFF,
    (dataSize >> 24) & 0xFF,
  ]);

  return Uint8List.fromList([...header.toBytes(), ...pcm]);
}

Uint8List frequenciesToWavBytes(
  List<double> frequencies, {
  double durationSeconds = 0.5,
  int sampleRate = 44100,
}) {
  final pcmData = frequenciesToPcmBytes(
    frequencies,
    durationSeconds: durationSeconds,
    sampleRate: sampleRate,
  );

  return makeWav(pcmData, bitRate: 16);
}
