import 'package:flutter/material.dart';

class BrowserSearchBar extends StatefulWidget {
  const BrowserSearchBar({
    required this.initialText,
    required this.onChanged,
    super.key,
  });

  final String initialText;
  final ValueChanged<String> onChanged;

  @override
  State<BrowserSearchBar> createState() => _BrowserSearchBarState();
}

class _BrowserSearchBarState extends State<BrowserSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(covariant BrowserSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        widget.initialText != _controller.text) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              )
            : null,
        hintText: 'Search filenames, titles, tags…',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
