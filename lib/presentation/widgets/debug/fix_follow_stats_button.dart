import 'package:flutter/material.dart';
import '../../../data/migrations/fix_follow_stats.dart';

/// Debug button to run stats migration
/// Add this to a debug menu or settings page
class FixFollowStatsButton extends StatefulWidget {
  const FixFollowStatsButton({Key? key}) : super(key: key);

  @override
  State<FixFollowStatsButton> createState() => _FixFollowStatsButtonState();
}

class _FixFollowStatsButtonState extends State<FixFollowStatsButton> {
  bool _isRunning = false;
  String? _result;

  Future<void> _runMigration() async {
    setState(() {
      _isRunning = true;
      _result = null;
    });

    try {
      await runAllMigrations();
      setState(() {
        _result = 'Migration completed successfully!';
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isRunning ? null : _runMigration,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: _isRunning
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Fix Follow Stats'),
        ),
        if (_result != null) ...[
          const SizedBox(height: 8),
          Text(
            _result!,
            style: TextStyle(
              color: _result!.contains('Error') ? Colors.red : Colors.green,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
