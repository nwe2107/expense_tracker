import 'package:flutter/material.dart';

class LoadingOverlay {
  static OverlayEntry? _entry;

  static void show(BuildContext context, {String message = 'Loading…'}) {
    if (_entry != null) return;
    _entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          ModalBarrier(color: Colors.black.withValues(alpha: 0.2), dismissible: false),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(message, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}
