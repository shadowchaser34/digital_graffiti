import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/canvas_widget.dart';
import '../widgets/toolbar.dart';
import '../widgets/participants_indicator.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Digital Graffiti Wall')),
      body: Stack(children: [
        const CanvasWidget(),
        // show other users' presence on top of the canvas
        const ParticipantsIndicator(),
        const Positioned(top: 8, left: 8, child: ToolBar()),
      ]),
    );
  }
}
