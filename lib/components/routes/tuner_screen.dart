import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mucron/components/tuner/record_button.dart';
import 'package:mucron/components/routes/notes_screen.dart';
import 'package:mucron/components/tuner/waveform.dart';
import 'package:mucron/service/mic_stream_service.dart';
import 'package:mucron/util/audio_util.dart';
import 'package:mucron/util/note_tracker.dart';

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});
  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  static const _sr = 44100.0;
  double _a4 = 440.0;
  NoteTracker tracker = NoteTracker();
  double? _freq;
  double? _cents;
  String? _note;
  int? _octave;

  // Smoother (median over last N estimates)
  final _recent = <double>[];
  final _recentLen = 5;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndStart();
  }

  Future<void> _requestPermissionAndStart() async {
    MicStreamService.instance.addListener(_onAudioBytes);
  }

  @override
  void dispose() {
    MicStreamService.instance.removeListener(_onAudioBytes);
    super.dispose();
  }

  void _onAudioBytes(dynamic data) {
    if (data is! Uint8List) return;
    final frame = convertLittleEndianToFloat64(data);
    final (f, conf) = detectPitch(frame, _sr);
    if (f == null || f.isNaN || f <= 0) {
      setState(() {
        _freq = null;
        _note = null;
        _cents = null;
        _octave = null;
      });
      return;
    }

    tracker.process(frame);
    // Smoothing
    _recent.add(f);
    if (_recent.length > _recentLen) _recent.removeAt(0);
    final fMed = _median(_recent);

    final nn = freqToNote(fMed, a4: _a4);
    setState(() {
      _freq = fMed;
      _note = nn.name;
      _octave = nn.octave;
      _cents = nn.cents;
    });
  }

  void _onRecordStart() {
    tracker.startRecording();
  }

  void _onRecordStop() {
    var recorded = tracker.getRecording();
    tracker.stopRecording();
    Navigator.push(
      context,
      CupertinoPageRoute<void>(
        builder: (context) => NotesScreen(audio: recorded),
      ),
    );
  }

  static double _median(List<double> xs) {
    final tmp = [...xs]..sort();
    final m = tmp.length ~/ 2;
    return tmp.length.isOdd ? tmp[m] : 0.5 * (tmp[m - 1] + tmp[m]);
  }

  @override
  Widget build(BuildContext context) {
    final locked =
        _cents != null && _freq != null && _note != null && _cents!.abs() < 5;
    return Scaffold(
      appBar: AppBar(title: const Text('Note Tuner')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Padding(padding: EdgeInsets.all(12), child: _createWaveForm()),
            _createCurrentNoteDisplay(locked),
            // A4 calibration
            _createA4Slider(),
            _createRecordButton(),
          ],
        ),
      ),
    );
  }

  Widget _createWaveForm() {
    return AspectRatio(
      aspectRatio: 7,
      child: MicWaveform(
        seconds: 2.0,
        sampleRate: 44100,
        strokeWidth: 1.2,
        gain: 1.0,
      ),
    );
  }

  Widget _createCurrentNoteDisplay(bool locked) {
    return Expanded(
      child: Center(
        child: _note == null
            ? const Text(
                "No microphone input detected",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${_note!}${_octave ?? ''}",
                    style: TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: locked ? Colors.green : null,
                    ),
                  ),
                  Text(
                    _freq != null ? "${_freq!.toStringAsFixed(1)} Hz" : "--",
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  if (_cents != null)
                    _CentsMeter(
                      cents: _cents!.clamp(-50, 50).toDouble(),
                      locked: locked,
                    ),
                  const SizedBox(height: 8),
                  if (_cents != null)
                    Text(
                      "${_cents!.round()} cents",
                      style: const TextStyle(fontSize: 18),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _createA4Slider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("A4 calibration: ${_a4.toStringAsFixed(1)} Hz"),
        Slider(
          value: _a4,
          min: 435,
          max: 445,
          divisions: 20,
          label: _a4.toStringAsFixed(1),
          onChanged: (v) => setState(() => _a4 = v),
        ),
      ],
    );
  }

  Widget _createRecordButton() {
    return RecordButton(
      onRecordStart: _onRecordStart,
      onRecordStop: _onRecordStop,
    );
  }
}


class _CentsMeter extends StatelessWidget {
  final double cents; // -50..+50
  final bool locked;
  const _CentsMeter({required this.cents, required this.locked});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      width: 300,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black26),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(width: 2, color: Colors.black26),
          ),
          Positioned(
            left: ((cents + 50) / 100) * 300 - 5,
            top: 0,
            bottom: 0,
            child: Container(
              width: 10,
              decoration: BoxDecoration(
                color: locked ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
