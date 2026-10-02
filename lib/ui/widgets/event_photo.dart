import 'package:flutter/material.dart';
import 'package:parentpeak/logic/user_profile_service.dart';

class EventPhoto extends StatelessWidget {
  const EventPhoto({super.key, required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = UserProfileService.resolveAvatarUrl(photoUrl);
    final fallback = SizedBox(
      key: const Key('event-photo-fallback'),
      height: 80,
      width: double.infinity,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.celebration_outlined, size: 32)),
      ),
    );
    if (url == null) return fallback;
    return Image.network(
      url,
      width: double.infinity,
      height: 80,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      frameBuilder: (context, child, frame, synchronous) =>
          synchronous || frame != null
          ? child
          : SizedBox(
              key: const Key('event-photo-loading'),
              height: 80,
              width: double.infinity,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
