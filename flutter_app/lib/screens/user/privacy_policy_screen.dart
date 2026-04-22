import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../utils/i18n.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(I18n.t(context, 'privacy_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(
            I18n.t(context, 'privacy_last_updated'),
            style: TextStyle(fontSize: 12, color: p.textHint),
          ),
          const SizedBox(height: 14),
          Text(
            I18n.t(context, 'privacy_placeholder').replaceAll('NewsNow', AppConstants.appName),
            style: TextStyle(fontSize: 14, color: p.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 18),
          Text(
            I18n.t(context, 'privacy_collect_title'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            I18n.t(context, 'privacy_collect_body'),
            style: TextStyle(fontSize: 14, color: p.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 18),
          Text(
            I18n.t(context, 'privacy_use_title'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            I18n.t(context, 'privacy_use_body'),
            style: TextStyle(fontSize: 14, color: p.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 18),
          Text(
            I18n.t(context, 'privacy_contact_title'),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            I18n.t(context, 'privacy_contact_body'),
            style: TextStyle(fontSize: 14, color: p.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

