import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const SafetyApp());
}

class SafetyApp extends StatelessWidget {
  const SafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'T&T Safety Assistant',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  List<Map<String, dynamic>> messages = [];
  bool loading = false;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDisclaimer();
    });
  }

  void _showDisclaimer() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text("Important Notice"),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "This Safety Assistant is provided as a reference tool to help employees locate information from the T&T Industrial Health, Safety, and Environmental (HSE) Manual.",
                  ),
                  SizedBox(height: 15),
                  Text(
                    "Responses are generated using artificial intelligence and may be incomplete, inaccurate, or not applicable to every work situation.",
                  ),
                  SizedBox(height: 15),
                  Text(
                    "This assistant does not replace official company policies, required safety training, supervisor instructions, job hazard analyses, or professional judgment.",
                  ),
                  SizedBox(height: 15),
                  Text(
                    "If any response differs from the official T&T Industrial HSE Manual, site-specific requirements, or instructions from your supervisor, always follow the official manual and your supervisor's direction.",
                  ),
                  SizedBox(height: 15),
                  Text(
                    "Do not rely on this assistant as the sole source of safety information when performing work. Users remain responsible for following all company safety procedures and applicable regulations.",
                  ),
                  SizedBox(height: 15),
                  Text(
                    "In any emergency or potentially hazardous situation, stop work immediately and follow established emergency procedures.",
                  ),
                  SizedBox(height: 20),
                  Text(
                    "By selecting 'I Understand', you acknowledge that you have read and understood this notice.",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text("I Understand", style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 🔥 controls scrolling behavior
  bool _shouldScroll = false;

  void _scrollIfNeeded() {
    if (!_shouldScroll) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    _shouldScroll = false;
  }

  Future<void> askPresetQuestion(String question) async {
    controller.text = question;
    await sendQuestion();
  }

  Future<void> sendQuestion() async {
    final question = controller.text.trim();
    if (question.isEmpty) return;

    setState(() {
      messages.add({"role": "user", "text": question, "sources": []});

      loading = true;

      // ✅ only trigger scroll ONCE per new user message
      _shouldScroll = true;
    });

    controller.clear();

    // scroll after user message only
    _scrollIfNeeded();

    try {
      final history = messages.map((m) {
        return {"role": m["role"], "content": m["text"]};
      }).toList();

      final response = await http.post(
        Uri.parse("https://safebot-backend.onrender.com/ask"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"question": question, "history": history}),
      );

      final data = jsonDecode(response.body);

      setState(() {
        messages.add({
          "role": "assistant",
          "text": data["answer"] ?? "No response",
          "sources": data["sources"] ?? [],
        });

        loading = false;
      });

      // ❌ IMPORTANT: no scroll here anymore
    } catch (e) {
      setState(() {
        messages.add({"role": "assistant", "text": "Error: $e", "sources": []});

        loading = false;
      });
    }
  }

  Future<void> openSource(String title, List pages) async {
    final page = pages.isNotEmpty ? pages.first : 1;

    final url = Uri.parse(
      "https://safebot-backend.onrender.com/manual#page=$page",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget quickButton(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text),
        onPressed: () => askPresetQuestion(text),
      ),
    );
  }

  Widget buildMessage(Map<String, dynamic> message) {
    final isUser = message["role"] == "user";
    final List sources = message["sources"] ?? [];

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? Colors.green.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message["text"] ?? "", style: const TextStyle(fontSize: 16)),
            if (sources.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const Text(
                "Sources",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...sources.map((source) {
                final title = source["title"] ?? "Unknown";
                final pages = source["pages"] ?? [];

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.menu_book),
                    title: Text(title),
                    subtitle: Text(
                      pages.isNotEmpty ? "Page ${pages.first}" : "No page info",
                    ),
                    onTap: () => openSource(title, pages),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text("T&T Safety Assistant"),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5FBF5), Color(0xFFE4F4E7)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Card(
              margin: const EdgeInsets.all(20),
              elevation: 10,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // HEADER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 25,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade700, Colors.green.shade500],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          "assets/logo.png",
                          width: 340,
                          height: 80,
                          fit: BoxFit.contain,
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          "T&T Industrial Safety Assistant",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          "Powered by AI using the Official T&T Industrial HSE Manual",
                          style: TextStyle(
                            color: Colors.white.withOpacity(.9),
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 18),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                color: Colors.green,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Official HSE Manual",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // QUICK QUESTIONS
                  Container(
                    padding: const EdgeInsets.all(14),
                    color: Colors.grey.shade50,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          quickButton("🦺 PPE"),
                          quickButton("🪜 Ladder Safety"),
                          quickButton("🏗 Scaffolding"),
                          quickButton("⚡ Electrical"),
                          quickButton("🚧 Excavation"),
                          quickButton("🪖 Fall Protection"),
                        ],
                      ),
                    ),
                  ),

                  // CHAT
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return buildMessage(messages[index]);
                      },
                    ),
                  ),

                  if (loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        children: const [
                          LinearProgressIndicator(),
                          SizedBox(height: 8),
                          Text(
                            "Searching the official HSE Manual...",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                  // INPUT BAR
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            onSubmitted: (_) => sendQuestion(),
                            decoration: InputDecoration(
                              hintText: "Ask a safety question...",
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        FloatingActionButton(
                          heroTag: "send",
                          mini: true,
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          onPressed: loading ? null : sendQuestion,
                          child: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),

                  // FOOTER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.green),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Powered by the official T&T Industrial HSE Manual. If you are unsure or an emergency exists, stop work immediately and contact your supervisor.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
