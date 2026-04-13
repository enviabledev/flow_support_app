import 'package:flutter/material.dart';
import '../config/theme.dart';

class DeliveryTicks extends StatelessWidget {
  final String status;
  final VoidCallback? onRetry;
  final VoidCallback? onUndeliveredTap;

  const DeliveryTicks({super.key, required this.status, this.onRetry, this.onUndeliveredTap});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'queued':
        return const Icon(Icons.access_time, size: 16, color: AppColors.tickGrey);
      case 'sent':
        return const Icon(Icons.check, size: 16, color: AppColors.tickGrey);
      case 'delivered':
        return const Icon(Icons.done_all, size: 16, color: AppColors.tickGrey);
      case 'read':
        return const Icon(Icons.done_all, size: 16, color: AppColors.tickBlue);
      case 'failed':
        return GestureDetector(
          onTap: onRetry,
          child: const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
        );
      case 'undelivered':
        return GestureDetector(
          onTap: onUndeliveredTap,
          child: const Icon(Icons.error, size: 16, color: AppColors.danger),
        );
      default:
        return const Icon(Icons.check, size: 16, color: AppColors.tickGrey);
    }
  }
}
