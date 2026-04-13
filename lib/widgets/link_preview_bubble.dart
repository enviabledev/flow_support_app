import 'package:flutter/material.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../utils/link_detector.dart';

class LinkPreviewBubble extends StatefulWidget {
  final String url;
  final bool isOutgoing;

  const LinkPreviewBubble({super.key, required this.url, this.isOutgoing = true});

  @override
  State<LinkPreviewBubble> createState() => _LinkPreviewBubbleState();
}

class _LinkPreviewBubbleState extends State<LinkPreviewBubble> {
  Metadata? _metadata;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _fetchPreview();
  }

  Future<void> _fetchPreview() async {
    try {
      final metadata = await AnyLinkPreview.getMetadata(
        link: LinkDetector.ensureProtocol(widget.url),
        cache: const Duration(hours: 24),
      );
      if (mounted) setState(() { _metadata = metadata; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: ThemeProvider.instance.colors.textSecondary)),
            SizedBox(width: 8),
            Text('Loading preview...', style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    if (_failed || _metadata == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(LinkDetector.ensureProtocol(widget.url));
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: widget.isOutgoing
              ? Colors.black.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_metadata!.image != null)
              Image.network(
                _metadata!.image!,
                width: double.infinity,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_metadata!.title != null)
                    Text(
                      _metadata!.title!,
                      style: TextStyle(color: ThemeProvider.instance.colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (_metadata!.desc != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _metadata!.desc!,
                      style: TextStyle(color: ThemeProvider.instance.colors.textSecondary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    Uri.parse(LinkDetector.ensureProtocol(widget.url)).host,
                    style: TextStyle(color: ThemeProvider.instance.colors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
