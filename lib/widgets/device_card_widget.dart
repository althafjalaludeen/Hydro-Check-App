// Device Card Components and Widgets
import 'package:flutter/material.dart';
import '../models/device_model.dart';

// Device Status Badge
class DeviceStatusBadge extends StatelessWidget {
  final DeviceStatus status;
  final bool needsAttention;

  const DeviceStatusBadge({
    super.key,
    required this.status,
    required this.needsAttention,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case DeviceStatus.active:
        bgColor = const Color(0xD4F1FDE5);
        textColor = const Color(0xFF059669);
        icon = Icons.check_circle;
        break;
      case DeviceStatus.inactive:
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF6B7280);
        icon = Icons.radio_button_unchecked;
        break;
      case DeviceStatus.maintenance:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        icon = Icons.build;
        break;
      case DeviceStatus.offline:
        bgColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFC5192D);
        icon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: needsAttention
            ? Border.all(color: textColor, width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Device Info Row
class DeviceInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const DeviceInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.grey[800],
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// Main Device Card
class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final VoidCallback? onStatusUpdate;
  final VoidCallback? onDelete;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    this.onStatusUpdate,
    this.onDelete,
  });

  String _getLastReadingText() {
    if (device.lastReadingTime == null) return 'No readings yet';
    
    final now = DateTime.now();
    final difference = now.difference(device.lastReadingTime!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: device.needsAttention
            ? BorderSide(color: Colors.red.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.deviceName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          device.serialNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DeviceStatusBadge(
                    status: device.effectiveStatus,
                    needsAttention: device.needsAttention,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Divider
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 12),

              // Location Info
              DeviceInfoRow(
                icon: Icons.location_on,
                label: 'Location',
                value: '${device.location.building} - Floor ${device.location.floor}',
              ),
              const SizedBox(height: 10),

              // Room Info
              DeviceInfoRow(
                icon: Icons.domain,
                label: 'Room',
                value: device.location.room,
              ),
              const SizedBox(height: 10),

              // Last Reading
              DeviceInfoRow(
                icon: Icons.schedule,
                label: 'Last Reading',
                value: _getLastReadingText(),
              ),
              const SizedBox(height: 10),

              // Firmware Version
              DeviceInfoRow(
                icon: Icons.info,
                label: 'Firmware',
                value: device.firmwareVersion,
              ),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (onStatusUpdate != null)
                    const SizedBox(width: 8),
                  if (onStatusUpdate != null)
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        onPressed: onStatusUpdate,
                        icon: const Icon(Icons.sync),
                        color: const Color(0xFF3B82F6),
                        tooltip: 'Refresh',
                      ),
                    ),
                  if (onDelete != null)
                    const SizedBox(width: 4),
                  if (onDelete != null)
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete),
                        color: Colors.red,
                        tooltip: 'Delete',
                      ),
                    ),
                ],
              ),

              // Warning Banner if needed attention
              if (device.needsAttention)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, size: 16, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getWarningMessage(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWarningMessage() {
    if (device.status == DeviceStatus.offline) {
      return 'Device is offline - check connection';
    } else if (device.status == DeviceStatus.maintenance) {
      return 'Device is under maintenance';
    }
    return 'Device needs attention';
  }
}

// Device List Header
class DeviceListHeader extends StatelessWidget {
  final int deviceCount;
  final int activeDevices;
  final int offlineDevices;


  const DeviceListHeader({
    super.key,
    required this.deviceCount,
    required this.activeDevices,
    required this.offlineDevices,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Devices',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatCard(
                label: 'Total Devices',
                value: deviceCount.toString(),
                icon: Icons.devices,
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Active',
                value: activeDevices.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Offline',
                value: offlineDevices.toString(),
                icon: Icons.error,
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Empty State Widget
class EmptyDevicesWidget extends StatelessWidget {
  final VoidCallback onAddDevice;

  const EmptyDevicesWidget({
    super.key,
    required this.onAddDevice,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No Devices Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You haven\'t registered any devices yet.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddDevice,
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Device'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
