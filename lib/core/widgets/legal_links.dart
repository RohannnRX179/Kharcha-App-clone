import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] externally, or tells the user it isn't published yet if
/// empty (spec F-15/F-18, T-M3.1/T-M3.6 — [AppConfig.privacyPolicyUrl]/
/// [AppConfig.termsUrl] stay blank until T-M3.1 actually publishes them).
/// Shared by the sign-up screen's Terms/Privacy line and Settings' About
/// section so both stay in sync automatically once a URL is configured.
Future<void> openLegalPage(
  BuildContext context, {
  required String url,
  required String label,
}) async {
  if (url.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("The $label aren't published yet.")));
    return;
  }
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
