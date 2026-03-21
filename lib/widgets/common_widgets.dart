import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

class HousepitalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const HousepitalCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
    return Card(
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: content,
            )
          : content,
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $text',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vital status with accessible text label (not color-only)
String _statusLabel(Color statusColor) {
  if (statusColor == HousepitalColors.vitalNormal || statusColor == HousepitalColors.success) {
    return 'Normal';
  } else if (statusColor == HousepitalColors.vitalBorderline || statusColor == HousepitalColors.warning) {
    return 'Borderline';
  } else if (statusColor == HousepitalColors.vitalAlert || statusColor == HousepitalColors.error) {
    return 'Alert';
  }
  return '';
}

IconData _statusIcon(Color statusColor) {
  if (statusColor == HousepitalColors.vitalNormal || statusColor == HousepitalColors.success) {
    return Icons.check_circle;
  } else if (statusColor == HousepitalColors.vitalBorderline || statusColor == HousepitalColors.warning) {
    return Icons.warning_amber_rounded;
  }
  return Icons.error;
}

class VitalCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color statusColor;
  final VoidCallback? onTap;

  const VitalCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(statusColor);
    return Semantics(
      label: '$label: $value ${unit ?? ''}, $status',
      button: onTap != null,
      child: Material(
        color: HousepitalColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 90,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HousepitalColors.divider),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: HousepitalColors.greyLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: HousepitalColors.black,
                  ),
                ),
                if (unit != null)
                  Text(
                    unit!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: HousepitalColors.greyLight,
                    ),
                  ),
                const SizedBox(height: 4),
                // Accessible status: icon + text label instead of color-only dot
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon(statusColor), size: 12, color: statusColor),
                    const SizedBox(width: 2),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: HousepitalColors.black,
            ),
          ),
          if (actionText != null)
            // 44pt minimum touch target
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text(
                  actionText!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: HousepitalColors.orangeText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LoadingWidget extends StatelessWidget {
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: HousepitalColors.orange),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(color: HousepitalColors.grey),
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorRetryWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetryWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: HousepitalColors.greyLight),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: HousepitalColors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class SOSButton extends StatelessWidget {
  final VoidCallback onTap;

  const SOSButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Emergency SOS. Double-tap to open emergency contacts',
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: HousepitalColors.sos,
          borderRadius: BorderRadius.circular(12),
          elevation: 4,
          shadowColor: HousepitalColors.sos.withValues(alpha: 0.3),
          child: InkWell(
            onTap: () {
              HapticFeedback.heavyImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.white24,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emergency, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Emergency Help',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
