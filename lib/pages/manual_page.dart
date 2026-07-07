import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;


class ManualPage extends StatefulWidget {
  const ManualPage({super.key});

  @override
  State<ManualPage> createState() => _ManualPageState();
}


class _ManualPageState extends State<ManualPage> {

  PdfControllerPinch? pdfController;


  @override
  void initState() {
    super.initState();
    loadPdf();
  }


  Future<void> loadPdf() async {

    final response = await http.get(
      Uri.parse(
        "https://safebot-backend.onrender.com/manual",
      ),
    );


    final document = await PdfDocument.openData(
      response.bodyBytes,
    );


    setState(() {
      pdfController = PdfControllerPinch(
        document: Future.value(document),
      );
    });
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("HSE Manual"),
      ),


      body: pdfController == null

          ? const Center(
              child: CircularProgressIndicator(),
            )

          : PdfViewPinch(
              controller: pdfController!,
            ),
    );
  }
}