import 'package:flutter/material.dart';
import '../core/services/user_manager.dart';
import 'create_sample_interactions.dart';

class SampleInteractionsDemo extends StatefulWidget {
  const SampleInteractionsDemo({super.key});

  @override
  State<SampleInteractionsDemo> createState() => _SampleInteractionsDemoState();
}

class _SampleInteractionsDemoState extends State<SampleInteractionsDemo> {
  String? userId;
  bool isLoading = false;
  String statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userManager = UserManager();
    setState(() {
      userId = userManager.currentUserId;
    });
  }

  Future<void> _createSampleInteractions() async {
    if (userId == null) {
      setState(() {
        statusMessage = '❌ No user logged in';
      });
      return;
    }

    setState(() {
      isLoading = true;
      statusMessage = '🔧 Creating sample interactions...';
    });

    try {
      await SampleInteractionCreator.createSampleInteractions(userId!);
      setState(() {
        statusMessage = '✅ Sample interactions created successfully!';
      });
    } catch (e) {
      setState(() {
        statusMessage = '❌ Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _checkInteractions() async {
    if (userId == null) {
      setState(() {
        statusMessage = '❌ No user logged in';
      });
      return;
    }

    setState(() {
      isLoading = true;
      statusMessage = '📊 Checking user interactions...';
    });

    try {
      await SampleInteractionCreator.checkUserInteractions(userId!);
      setState(() {
        statusMessage = '✅ Check console for interaction details';
      });
    } catch (e) {
      setState(() {
        statusMessage = '❌ Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sample Interactions Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current User',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userId ?? 'No user logged in',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : _createSampleInteractions,
              child: isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Creating...'),
                      ],
                    )
                  : const Text('Create Sample Interactions'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: isLoading ? null : _checkInteractions,
              child: const Text('Check Current Interactions'),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusMessage.isEmpty ? 'Ready' : statusMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Instructions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Make sure you are logged in'),
                    Text('2. Click "Create Sample Interactions" to generate test data'),
                    Text('3. Click "Check Current Interactions" to verify'),
                    Text('4. Go back to home and test recommendations'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}