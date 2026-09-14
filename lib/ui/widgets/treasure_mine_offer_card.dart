import 'package:flutter/material.dart';
import 'package:parentpeak/l10n/app_localizations.dart';
import 'package:parentpeak/logic/treasure_backend_service.dart';

class TreasureMineOfferCard extends StatelessWidget {
  const TreasureMineOfferCard({
    super.key,
    required this.offer,
    required this.l10n,
    required this.onConfirm,
    required this.onComplete,
  });

  final TreasureOfferSummary offer;
  final AppLocalizations l10n;
  final ValueChanged<TreasureHandoverSummary> onConfirm;
  final ValueChanged<TreasureHandoverSummary> onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE6F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (offer.reservations.isEmpty)
            Text(
              l10n.t('treasureMyListingsEmpty',
                  fallback: 'Noch keine Reservierung.'),
              style: theme.textTheme.bodySmall,
            ),
          for (final reservation in offer.reservations) ...[
            if (offer.reservations.first != reservation)
              const Divider(height: 20),
            Text(
              reservation.status == 'confirmed'
                  ? l10n.t('treasureReservationConfirmed')
                  : l10n.t('treasureReservationOpen'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: reservation.status == 'confirmed'
                    ? const Color(0xFF15803D)
                    : const Color(0xFF1E5CD7),
                fontWeight: FontWeight.w800,
              ),
            ),
            if (reservation.location.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(reservation.location, style: theme.textTheme.bodySmall),
            ],
            if (reservation.notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 3),
              Text(reservation.notes!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            if (reservation.status == 'confirmed')
              FilledButton.icon(
                onPressed: () => onComplete(reservation),
                icon: const Icon(Icons.task_alt_rounded, size: 18),
                label: Text(l10n.t('treasureCompleteHandover')),
              )
            else
              FilledButton.icon(
                onPressed: () => onConfirm(reservation),
                icon: const Icon(Icons.handshake_rounded, size: 18),
                label: Text(l10n.t('treasureConfirmHandover')),
              ),
          ],
        ],
      ),
    );
  }
}
