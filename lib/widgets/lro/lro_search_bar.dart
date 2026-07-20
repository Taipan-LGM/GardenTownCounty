import 'dart:async';

import 'package:flutter/material.dart';

/// Debounced search field used across LRO list screens.
class LroSearchBar extends StatefulWidget {
  const LroSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = 'Search...',
    this.debounce = const Duration(milliseconds: 300),
  });

  final ValueChanged<String> onChanged;
  final String hintText;
  final Duration debounce;

  @override
  State<LroSearchBar> createState() => _LroSearchBarState();
}

class _LroSearchBarState extends State<LroSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    setState(() {}); // refresh the clear button visibility immediately
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () => widget.onChanged(value));
  }

  void _clear() {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() {});
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _handleChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clear,
              ),
      ),
    );
  }
}
