import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart'; // NEW IMPORT

void main() {
  runApp(const LedgerCoreApp());
}

class LedgerCoreApp extends StatelessWidget {
  const LedgerCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LedgerCore',
      theme: ThemeData(primarySwatch: Colors.blue, brightness: Brightness.dark),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // State variables
  String balance = "Loading...";
  bool isLoading = false;

  // 1. Declare the persistent WebSocket channel
  late WebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    fetchBalance(); // Fetch initial state via REST

    // 2. Dial the WebSocket phone number on boot
    // The Architect: Notice we use 'ws://' instead of 'http://'
    channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8080/ws'));

    // 3. Keep the ear to the phone forever
    channel.stream.listen((message) {
      if (message == "REFRESH_BALANCE") {
        print("WebSocket ping received! Updating UI silently...");
        fetchBalance();
      }
    });
  }

  // 4. The SRE: Always hang up the phone when the user closes the app
  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  Future<void> fetchBalance() async {
    // We removed isLoading = true here so the UI doesn't flash a spinner
    // when a background WebSocket update happens. It feels like magic.
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/balance'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // balance = "\$${(data['balance'] as double).toStringAsFixed(2)}";
          // 'num' can be either int or double. We let Dart figure it out, then convert it.
          balance =
              "\$${(data['balance'] as num).toDouble().toStringAsFixed(2)}";
        });
      }
    } catch (e) {
      print("Network Error: $e");
    }
  }

  Future<void> executeTransfer() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/transfer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "sender_id": "a1111111-1111-1111-1111-111111111111",
          "receiver_id": "b2222222-2222-2222-2222-222222222222",
          "amount": 10.00,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Transfer Secure!"),
            backgroundColor: Colors.green,
          ),
        );
        // 5. Fire the event down the WebSocket instead of awaiting fetchBalance() here
        channel.sink.add("REFRESH_BALANCE");
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LedgerCore System')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "User A Balance",
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            // Show a spinner if fetching, otherwise show the text
            isLoading
                ? const CircularProgressIndicator()
                : Text(
                    balance,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: isLoading ? null : fetchBalance,
              icon: const Icon(Icons.refresh),
              label: const Text("Sync with Database"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              // If we are currently loading, disable the button so the user can't double-click
              onPressed: isLoading ? null : executeTransfer,
              icon: const Icon(Icons.send),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              label: const Text("Send \$10 to User B"),
            ),
          ],
        ),
      ),
    );
  }
}
