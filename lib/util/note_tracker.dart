class NoteTracker {
  final List<double> _recentHz = [];
  bool isActive = false;

  void startRecording() {
    isActive = true;
  }

  void stopRecording() {
    isActive = false;
    _recentHz.clear();
  }

  void process(List<double> frame) {
    if (isActive) {
      _recentHz.addAll(frame);
    }
  }

  List<double> getRecording() {
    List<double> recording = [];
    recording.addAll(_recentHz);
    return recording;
  }
}
