import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ManualPage extends StatelessWidget {
  const ManualPage({super.key});

  final String manualUrl =
      "https://safebot-backend.onrender.com/manual";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HSE Manual"),
      ),
      body: SfPdfViewer.network(
        manualUrl,
      ),
    );
  }
}