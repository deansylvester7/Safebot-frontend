import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'pages/manual_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/handbook_page.dart';

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
      home: const HomePage(),
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
  bool showSuggestions = true;
  @override
  void initState() {
    super.initState();
    _checkDisclaimer();
  }

  Future<void> _checkDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();

    final hasSeenDisclaimer = prefs.getBool('has_seen_disclaimer') ?? false;

    if (!hasSeenDisclaimer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showDisclaimer();
        }
      });
    }
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
                    "This Company Assistant is provided as a reference tool to help employees locate information from the T&T Industrial Health, Safety, and Environmental (HSE) Manual and the Employee Handbook.",
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
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();

                  await prefs.setBool('has_seen_disclaimer', true);

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
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
      print(data["sources"]);

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

  Future<void> openSource(String document, String title, dynamic pages) async {
    int page = 1;

    try {
      if (pages is List && pages.isNotEmpty) {
        final first = pages.first;

        if (first is int) {
          page = first;
        } else if (first is String) {
          page = int.tryParse(first.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        } else if (first is Map && first["page"] != null) {
          page = int.tryParse(first["page"].toString()) ?? 1;
        }
      } else if (pages is int) {
        page = pages;
      } else if (pages is String) {
        page = int.tryParse(pages.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      }
    } catch (_) {
      page = 1;
    }

    String viewer = "manual-viewer";

    if (document == "Employee Handbook") {
      viewer = "handbook-viewer";
    }

    final url = Uri.parse(
      "https://safebot-backend.onrender.com/$viewer#page=$page",
    );

    await launchUrl(url, mode: LaunchMode.externalApplication);
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

  Widget buildMessage(Map<String, dynamic> msg) {
    final isUser = msg["role"] == "user";
    final sources = msg["sources"];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.green,
                child: Icon(Icons.security, size: 14, color: Colors.white),
              ),

            if (!isUser) const SizedBox(width: 8),

            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message bubble
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.green.shade600 : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      msg["text"] ?? "",
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Source cards
                  if (!isUser && sources is List && sources.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sources.map<Widget>((source) {
                          final String document =
                              (source["document"] ?? "HSE Manual").toString();

                          final String title = (source["title"] ?? "Section")
                              .toString();

                          final int page = source["page"] ?? 1;

                          return GestureDetector(
                            onTap: () => openSource(document, title, [page]),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.description,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          document,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "Page $page",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.open_in_new,
                                    color: Colors.green,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (isUser) const SizedBox(width: 8),
                  if (isUser)
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, size: 14, color: Colors.white),
                    ),
                ],
              ),
            ),
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
              // ================= CHAT =================
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      showSuggestions = !showSuggestions;
                    });
                  },
                  child: Text(
                    showSuggestions ? "Hide suggestions" : "Show suggestions",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              // ================= QUICK SUGGESTIONS =================
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: showSuggestions
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,

                firstChild: Container(
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
                      children: [
                        quickButton("PPE"),
                        quickButton("Attendance Policy"),
                        quickButton("Confined Spaces"),
                        quickButton("Scaffolding"),
                        quickButton("Electrical Safety"),
                        quickButton("Benefits"),
                        quickButton("Pay Period"),
                      ],
                    ),
                  ),
                ),

                secondChild: const SizedBox.shrink(),
              ),
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
                        "Searching company documentation...",
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedPage = 0;

  final pages = const [ChatPage(), ManualPage(), HandbookPage()];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 800;

    return Scaffold(
      body: isMobile
          ? pages[selectedPage]
          : Row(
              children: [
                NavigationRail(
                  extended: true,

                  selectedIndex: selectedPage,

                  onDestinationSelected: (index) {
                    setState(() {
                      selectedPage = index;
                    });
                  },

                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.smart_toy),
                      label: Text("Assistant"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.menu_book),
                      label: Text("Manual"),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.badge),
                      label: Text("Handbook"),
                    ),
                  ],
                ),

                const VerticalDivider(width: 1),

                Expanded(child: pages[selectedPage]),
              ],
            ),

      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: selectedPage,

              onDestinationSelected: (index) {
                setState(() {
                  selectedPage = index;
                });
              },

              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.smart_toy),
                  label: "Assistant",
                ),

                NavigationDestination(
                  icon: Icon(Icons.menu_book),
                  label: "Manual",
                ),

                NavigationDestination(
                  icon: Icon(Icons.badge),
                  label: "Handbook",
                ),
              ],
            )
          : null,
    );
  }
}
