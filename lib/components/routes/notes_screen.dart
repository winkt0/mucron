import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mucron/components/graph.dart';
import 'package:mucron/util/freq2wav.dart';
import 'package:mucron/util/audio_analyzer.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.audio});
  final List<double> audio;
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  int frameSize = 2048;
  int hopSize = 512;

  final TextEditingController frameSizeController = TextEditingController(
    text: "2048",
  );
  final TextEditingController hopSizeController = TextEditingController(
    text: "512",
  );

  Future<Widget> runAnalyzer() async {
    final localFrameSize = frameSize;
    final localHopSize = hopSize;

    List<FlSpot> buildSpots(
      List<double> frequenciesYIN,
      List<double> audio,
      double sampleRate,
    ) {
      final spots = <FlSpot>[];
      for (int i = 0; i < frequenciesYIN.length; i++) {
        var f = frequenciesYIN[i];
        if (!f.isFinite || f <= 0) f = 0;
        spots.add(
          FlSpot(i * audio.length / (sampleRate * frequenciesYIN.length), f),
        );
      }
      return spots;
    }

    void addBars(
      LineChart graph,
      List<double> frequencies,
      List<double> audio,
      double sampleRate,
    ) {
      List<FlSpot> spots = buildSpots(frequencies, audio, sampleRate);
      graph.data.lineBarsData.add(
        LineChartBarData(
          spots: spots,
          isCurved: false,
          dotData: FlDotData(show: true),
          color: Color.fromARGB(0, 191, 23, 23),
          barWidth: 16,
          belowBarData: BarAreaData(
            show: true, // Fills area under the line
            color: Colors.red.withOpacity(0.1), // Light blue fill
          ),
        ),
      );
    }

    return await compute(
      (params) {
        final audio = params["audio"] as List<double>;
        final sampleRate = 44100.0;
        final frameSize = params["frameSize"] as int;
        final hopSize = params["hopSize"] as int;

        final frequencies = AudioAnalyzer.analyze(
          audio,
          sampleRate,
          frameSize,
          hopSize,
        );

        double maxFreq = frequencies.where((f) => f.isFinite).fold(0.0, max);
        double yMax = maxFreq * 1.2;
        var lenInSeconds = audio.length / sampleRate;
        final smoothed = AudioAnalyzer.smooth(frequencies);
        List<FlSpot> spots = buildSpots(smoothed, audio, sampleRate);

        LineChart graph = Graph.build(
          spots: spots,
          xMax: lenInSeconds,
          yMax: yMax,
          interval: lenInSeconds / 10,
        );

        addBars(graph, frequencies, audio, sampleRate);
        final bytes = frequenciesToWavBytes(
          smoothed,
          durationSeconds: lenInSeconds,
        );
        final widget = Padding(
          padding: const EdgeInsets.all(15.0),
          child: graph,
        ); //Stack(children: [MusicSheet(notes: notes),graph],));
        return (widget, bytes);
      },
      {
        "audio": widget.audio,
        "frameSize": localFrameSize,
        "hopSize": localHopSize,
      },
    ).then((result) async {
      final (widget, bytes) = result;
      final player = AudioPlayer();
      await player.play(BytesSource(bytes, mimeType: "audio/wav"));
      return widget;
    });
  }

  @override
  Widget build(BuildContext context) {
    var audioLength = widget.audio.length;
    return Scaffold(
      appBar: AppBar(title: const Text("Analyzer")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: frameSizeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          "Frame Size ($audioLength data points => ${audioLength / hopSize} frames)",
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: hopSizeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Hop Size",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      frameSize =
                          int.tryParse(frameSizeController.text) ?? 2048;
                      hopSize = int.tryParse(hopSizeController.text) ?? 512;
                    });
                  },
                  child: const Text("Update"),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<Widget>(
              future: runAnalyzer(), // reruns on setState
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingAnimation();
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                } else {
                  return snapshot.data!;
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingAnimation extends StatelessWidget {
  const LoadingAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        spacing: 16.0,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const <Widget>[
          Text('Running Analyzer'),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }
}
