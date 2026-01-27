import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../services/firestore_service.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirestoreService _firestore = FirestoreService();
  bool _isDeleting = false;

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsPage()),
    );
  }

  Future<void> _logOut() async {
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This action is permanent and will delete your account along with '
            'all of its data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No signed-in account found.')),
          );
        }
        return;
      }

      final locale = Localizations.localeOf(context).toLanguageTag();
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable =
          functions.httpsCallable('queueAccountDeletedEmail');
      await callable.call(<String, dynamic>{'locale': locale});
      debugPrint('Account deletion email queued for $uid');

      await _firestore.deleteUserData(uid);
      await user?.delete();
      if (mounted) {
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);
      }
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        'queueAccountDeletedEmail failed: ${error.code} ${error.message}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Delete email failed: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (error) {
      final message = error.code == 'requires-recent-login'
          ? 'Please log in again to delete your account.'
          : 'Failed to delete account. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete account.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isDeleting ? null : _openSettings,
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Settings'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _isDeleting ? null : _logOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Log out'),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _isDeleting ? null : _deleteAccount,
                          icon: const Icon(Icons.delete_forever),
                          label: Text(
                            _isDeleting ? 'Deleting account...' : 'Delete account',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
