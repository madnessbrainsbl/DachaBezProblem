import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

/// Безопасная мини-иконка. Пытается декодировать PNG в памяти.
/// Если декодер падает (значит файл несовместим с конкретным GPU/драйвером),
/// показывает резервный [fallback]-виджет.
class SafeAssetIcon extends StatefulWidget {
  final String assetPath;
  final double size;
  final Widget fallback;
  final BoxFit fit;

  const SafeAssetIcon({
    Key? key,
    required this.assetPath,
    this.size = 16,
    required this.fallback,
    this.fit = BoxFit.contain,
  }) : super(key: key);

  @override
  State<SafeAssetIcon> createState() => _SafeAssetIconState();
}

class _SafeAssetIconState extends State<SafeAssetIcon> {
  bool _broken = false;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    try {
      final data = await rootBundle.load(widget.assetPath);
      final ok = img.decodeImage(data.buffer.asUint8List()) != null;
      if (!ok && mounted) setState(() => _broken = true);
    } catch (_) {
      if (mounted) setState(() => _broken = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_broken) return widget.fallback;
    return Image.asset(
      widget.assetPath,
      width: widget.size,
      height: widget.size,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => widget.fallback,
    );
  }
} 