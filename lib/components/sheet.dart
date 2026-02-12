import 'package:flutter/material.dart';
import 'package:simple_sheet_music/simple_sheet_music.dart';
import 'package:mucron/util/audio_util.dart' as util;

class MusicSheet extends StatefulWidget {
  final List<util.Note> notes;

  const MusicSheet({super.key, required this.notes});

  @override
  State<MusicSheet> createState() => MusicSheetState();
}

class MusicSheetState extends State<MusicSheet> {
  @override
  Widget build(BuildContext context) {
    final sheetMusicSize = MediaQuery.of(context).size;
    final width = sheetMusicSize.width;
    final height = sheetMusicSize.height / 2;
    final measures = widget.notes
        .map(
          (note) => Measure([
            ChordNote([
              ChordNotePart(
                Pitch.values.firstWhere(
                  (pitch) => pitch.position == note.midi - 29,
                ),
              ),
            ]),
          ]),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Simple Sheet Music')),
      body: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SimpleSheetMusic(
            height: height,
            width: width,
            measures: measures,
          ),
        ),
      ),
    );
  }
}
