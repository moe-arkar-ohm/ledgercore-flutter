import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  // The asynchronous network call to our Go Engine
  Future<void> fetchBalance() async {
    setState(() {
      isLoading = true; // Tell the UI to show a spinner
    });

    try {
      // The Architect: We use localhost because we are running natively on Windows.
      // If we were on an Android emulator, this would need to be 10.0.2.2.
      final response = await http.get(
        Uri.parse('http://localhost:8080/balance'),
      );

      if (response.statusCode == 200) {
        // Decode the JSON from Go
        final data = jsonDecode(response.body);
        setState(() {
          // Format the double to 2 decimal places
          balance = "\$${(data['balance'] as double).toStringAsFixed(2)}";
        });
      } else {
        setState(() {
          balance = "Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      // The SRE: Never let the app crash if the Go server is offline.
      setState(() {
        balance = "Server Offline";
      });
      print("Network Error: $e");
    } finally {
      setState(() {
        isLoading = false; // Turn off the spinner
      });
    }
  }

  // This runs exactly once when the screen first loads
  @override
  void initState() {
    super.initState();
    fetchBalance(); // Fetch immediately on boot
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
          ],
        ),
      ),
    );
  }
}
