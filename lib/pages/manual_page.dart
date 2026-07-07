import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';


class ManualPage extends StatefulWidget {
  const ManualPage({super.key});

  @override
  State<ManualPage> createState() => _ManualPageState();
}


class _ManualPageState extends State<ManualPage> {

  late final WebViewController controller;


  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..loadRequest(
        Uri.parse(
          "https://safebot-backend.onrender.com/manual",
        ),
      );
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("HSE Manual"),
      ),

      body: WebViewWidget(
        controller: controller,
      ),
    );
  }
}