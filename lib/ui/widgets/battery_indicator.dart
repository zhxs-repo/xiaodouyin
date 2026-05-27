import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_provider.dart';

class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, dp, _) => Text('${dp.batteryLevel}%', style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );
  }
}
