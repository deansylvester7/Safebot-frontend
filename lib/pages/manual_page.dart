import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class ManualPage extends StatelessWidget {
  const ManualPage({super.key});

  @override
  Widget build(BuildContext context) {

    const String pdfUrl =
        "https://safebot-backend.onrender.com/manual";

    final String viewId = "manual-pdf-viewer";

    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = pdfUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';

        return iframe;
      },
    );


    return Scaffold(
      appBar: AppBar(
        title: const Text("HSE Manual"),
      ),

      body: HtmlElementView(
        viewType: viewId,
      ),
    );
  }
}