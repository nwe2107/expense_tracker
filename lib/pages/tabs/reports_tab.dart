import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../reports_page.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Not signed in'));
    }

    // Reuse the existing reports page without a nested AppBar/Scaffold.
    return ReportsPage(
      uid: uid,
      showAppBar: false,
      useScaffold: false,
    );
  }
}
