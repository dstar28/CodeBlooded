import 'package:flutter/material.dart';

import '../../state/safety_circle_store.dart';
import '../../theme/app_colors.dart';

/// Join Safety Circle form (Prompt #9).
///
/// This only checks the entered code against a small local list of mock
/// codes in [SafetyCircleStore] — there is no real backend lookup yet.
class JoinSafetyCircleScreen extends StatefulWidget {
  const JoinSafetyCircleScreen({super.key});

  @override
  State<JoinSafetyCircleScreen> createState() =>
      _JoinSafetyCircleScreenState();
}

class _JoinSafetyCircleScreenState extends State<JoinSafetyCircleScreen> {
  final _codeController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a Safety Circle code');
      return;
    }

    final joined = SafetyCircleStore.instance.joinGroup(code);
    if (!joined) {
      setState(() => _error = 'Invalid Safety Circle Code');
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Safety Circle')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Safety Circle Code',
                  hintText: 'SG-4821',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error == 'Invalid Safety Circle Code'
                      ? '$_error\nPlease check the code and try again.'
                      : _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Join Circle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
