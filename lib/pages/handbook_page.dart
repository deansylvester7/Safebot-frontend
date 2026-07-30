import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HandbookPage extends StatelessWidget {
  const HandbookPage({super.key});

  Future<void> openHandbook() async {
    final url = Uri.parse(
      "https://safebot-backend.onrender.com/handbook-viewer",
    );

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Employee Handbook")),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.menu_book),
          label: const Text("Open Handbook"),
          onPressed: openHandbook,
        ),
      ),
    );
  }
}
