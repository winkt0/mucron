import 'package:flutter/material.dart';
import 'package:mucron/components/tuner/record_waves.dart';

class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.onRecordStart,
    required this.onRecordStop,
  });
  final void Function() onRecordStart;
  final void Function() onRecordStop;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  final duration = const Duration(milliseconds: 300);

  var _isRecording = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.1;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (_isRecording) RecordWaves(duration: duration, size: width),
        AnimatedContainer(
          width: width,
          height: width,
          duration: duration,
          decoration: BoxDecoration(
            border: Border.all(
              color: _isRecording ? Colors.red : Colors.grey,
              width: _isRecording ? 4 : 1,
            ),
            borderRadius: BorderRadius.circular(width),
          ),
          child: tapButton(width),
        ),
      ],
    );
  }

  Widget tapButton(double size) => Center(
    child: GestureDetector(
      onTap: () {
        setState(() => _isRecording = !_isRecording);
        if (_isRecording) {
          widget.onRecordStart();
        } else {
          widget.onRecordStop();
        }
      },
      child: AnimatedContainer(
        duration: duration,
        width: _isRecording ? size * 0.65 - 30 : size * 0.65,
        height: _isRecording ? size * 0.65 - 30 : size * 0.65,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: _isRecording ? 4 : 8,
          ),
          color: Colors.red,
          borderRadius: BorderRadius.circular(_isRecording ? 20 : 80),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.4),
              blurRadius: _isRecording ? 17.5 : 40.0,
              spreadRadius: _isRecording ? 7.5 : 20.0,
            ),
          ],
        ),
        child: Center(child: Text(_isRecording ? 'STOP' : '')),
      ),
    ),
  );
}
