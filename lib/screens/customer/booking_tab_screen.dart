import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'book_appointment_screen.dart';
import 'select_branch_screen.dart';

class BookingTabScreen extends StatelessWidget {
  const BookingTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF05070A),
        body: Center(
          child: Text(
            'Please log in again',
            style: TextStyle(color: AppColors.text),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final selectedShopId =
            (snapshot.data?.data()?['selectedShopId'] as String?)?.trim();

        if (selectedShopId == null || selectedShopId.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF05070A),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.gold,
                      size: 48,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Select a branch first',
                      style: TextStyle(
                        color: AppColors.text,
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a branch to start booking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: const Color(0xFF05070A),
                          textStyle: const TextStyle(
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SelectBranchScreen(userId: user.uid),
                            ),
                          );
                        },
                        child: const Text('SELECT BRANCH'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return BookAppointmentScreen(initialShopId: selectedShopId);
      },
    );
  }
}
