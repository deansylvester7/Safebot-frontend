import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

class HandbookPage extends StatelessWidget {
  const HandbookPage({super.key});

  static bool _registered = false;

  @override
  Widget build(BuildContext context) {
    const viewType = 'handbook-viewer';

    if (!_registered) {
      ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final iframe = html.IFrameElement()
          ..src = 'https://safebot-backend.onrender.com/handbook-viewer'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';

        return iframe;
      });

      _registered = true;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text("Employee Handbook")),
      body: const HtmlElementView(viewType: viewType),
    );
  }
}
