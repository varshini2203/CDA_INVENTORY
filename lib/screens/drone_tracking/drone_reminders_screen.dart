// lib/screens/drone_tracking/drone_reminders_screen.dart
//
// "Drone Reminders" page — lists every drone that has been OUT for 4+
// hours without being marked back IN. Unlike Admin Notifications (pending
// access requests), this screen is visible to BOTH admins and staff, since
// anyone might be the one who forgot to update the app after bringing the
// drone back.
//
// Data source: DroneService.overdueDronesStream(), which is itself derived
// from the live drones collection (status == 'OUT' AND checked_out_at is
// 4+ hours old). No separate notifications collection to keep in sync —
// the reminder disappears from the badge count automatically the moment
// the drone is marked IN.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/drone.dart';
import '../../services/drone_service.dart';
import 'drone_in_out_screen.dart';

class DroneRemindersScreen extends StatefulWidget {
  const DroneRemindersScreen({super.key});

  @override
  State<DroneRemindersScreen> createState() => _DroneRemindersScreenState();
}

class _DroneRemindersScreenState extends State<DroneRemindersScreen> {
  final DroneService _service = DroneService();

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kCoral = Color(0xFFFF6B6B);
  static const Color kTeal = Color(0xFF00D4AA);
  static const Color kSurface = Color(0xFFF0F4F8);

  String _durationText(DateTime since) {
    final d = DateTime.now().difference(since);
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    if (hours <= 0) return '$mins min';
    return '${hours}h ${mins}m';
  }

  Future<void> _acknowledge(Drone drone) async {
    await _service.acknowledgeReminder(drone.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kNavy,
        elevation: 0,
        title: const Text('Drone Reminders',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Drone>>(
        stream: _service.overdueDronesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: kTeal));
          }
          final drones = snapshot.data ?? const <Drone>[];
          if (drones.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.grey.shade400, size: 48),
                  const SizedBox(height: 12),
                  Text('No overdue drones right now',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    'You\'ll see a reminder here if a drone stays OUT\nfor 4 hours or more.',
                    textAlign: TextAlign.center,
                    style:
                    TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: drones.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ReminderCard(
              drone: drones[i],
              durationText: _durationText(
                  drones[i].checkedOutAt ?? drones[i].lastUpdated ?? DateTime.now()),
              onAcknowledge: () => _acknowledge(drones[i]),
              onOpenFleet: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'Drone In/Out'),
                    builder: (_) => const DroneInOutScreen(),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final Drone drone;
  final String durationText;
  final VoidCallback onAcknowledge;
  final VoidCallback onOpenFleet;

  const _ReminderCard({
    required this.drone,
    required this.durationText,
    required this.onAcknowledge,
    required this.onOpenFleet,
  });

  static const Color kNavy = Color(0xFF0A1628);
  static const Color kAmber = Color(0xFFFFB800);
  static const Color kCoral = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    final since = drone.checkedOutAt ?? drone.lastUpdated;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCoral.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kCoral.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flight_takeoff_rounded,
                    color: kCoral, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(drone.name,
                        style: const TextStyle(
                            color: kNavy,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    Text(drone.model,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kCoral.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('OUT ${durationText}',
                    style: const TextStyle(
                        color: kCoral,
                        fontWeight: FontWeight.w800,
                        fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _InfoChip(
                  icon: Icons.person_outline,
                  label: 'Used by',
                  value: drone.pilotName ?? 'Unknown'),
              _InfoChip(
                  icon: Icons.flag_outlined,
                  label: 'Purpose',
                  value: drone.purpose ?? 'Not specified'),
              if (since != null)
                _InfoChip(
                    icon: Icons.schedule,
                    label: 'Taken out',
                    value: DateFormat('dd MMM, hh:mm a').format(since)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAcknowledge,
                  icon: const Icon(Icons.done, size: 16),
                  label: const Text('Got it'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenFleet,
                  icon: const Icon(Icons.flight_land, size: 16),
                  label: const Text('Mark IN'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAmber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text('$label: ',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: Color(0xFF0A1628),
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}
