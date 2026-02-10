import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app_shell.dart';
import 'owner_add_barber_screen.dart';
import 'owner_add_service_screen.dart';
import 'owner_appointments_screen.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AppShell()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Owner Tools',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _ActionCard(
            title: 'Manage Barbers',
            subtitle: 'Add, activate, deactivate, and remove barbers',
            icon: Icons.content_cut,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OwnerAddBarberScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'Manage Services',
            subtitle: 'Add, activate, deactivate, and remove services',
            icon: Icons.design_services,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const OwnerAddServiceScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'View Appointments',
            subtitle: 'See all appointments for your shop',
            icon: Icons.calendar_month,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const OwnerAppointmentsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
