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
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 800;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              "assets/logo.png",
              height: isSmall ? 22 : 26,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            Text(
              isSmall ? "T&T Safety" : "T&T Safety Assistant",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),

          child: Column(
            children: [
              // ================= QUICK SUGGESTIONS =================
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: isSmall
                        ? [
                            quickButton("PPE"),
                            quickButton("Ladder"),
                            quickButton("Electrical"),
                            quickButton("Fall"),
                          ]
                        : [
                            quickButton("PPE"),
                            quickButton("Ladder Safety"),
                            quickButton("Scaffolding"),
                            quickButton("Electrical"),
                            quickButton("Excavation"),
                            quickButton("Fall Protection"),
                          ],
                  ),
                ),
              ),

              // ================= CHAT =================
              Expanded(
                child: Container(
                  color: Colors.grey.shade50,
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return buildMessage(messages[index]);
                    },
                  ),
                ),
              ),

              // ================= LOADING =================
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 6),
                      Text(
                        "Searching safety manual...",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),

              // ================= INPUT BAR =================
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        onSubmitted: (_) => sendQuestion(),
                        decoration: InputDecoration(
                          hintText: "Ask a safety question...",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    IconButton(
                      icon: Icon(
                        Icons.send,
                        color: loading ? Colors.grey : Colors.green.shade700,
                      ),
                      onPressed: loading ? null : sendQuestion,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
