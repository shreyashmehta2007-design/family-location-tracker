import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    final result = await ApiService.createFamily(_nameCtrl.text.trim());
    setState(() => _loading = false);
    if (!mounted) return;
    if (result['status'] == 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Family created! Invite code: ${result['invite_code']}'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] ?? 'Error'), backgroundColor: Colors.red));
    }
  }

  Future<void> _join() async {
    setState(() => _loading = true);
    final result = await ApiService.joinFamily(_codeCtrl.text.trim());
    setState(() => _loading = false);
    if (!mounted) return;
    if (result['status'] == 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Joined ${result['family_name']}!'), backgroundColor: Colors.green,
      ));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] ?? 'Error'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f2f5),
      appBar: AppBar(title: const Text('Family Setup'), backgroundColor: const Color(0xFF1a1a2e), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.family_restroom, size: 50, color: Color(0xFF4a4ae0)),
                  SizedBox(height: 12),
                  Text('Start tracking your family', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Create a family group or join one with an invite code', style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create a Family', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Family name (e.g. Smith Family)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _create,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4a4ae0), foregroundColor: Colors.white),
                      child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create Family'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Join a Family', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeCtrl,
                    decoration: InputDecoration(
                      hintText: 'Invite code (e.g. ABC123)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _join,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27ae60), foregroundColor: Colors.white),
                      child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Join Family'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}