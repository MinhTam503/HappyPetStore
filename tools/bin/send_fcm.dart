import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;

// Sends an FCM HTTP v1 message using a Google service account. Do NOT run this in a client app.
// Usage:
//   dart run tools/bin/send_fcm.dart \
//     --project-id YOUR_PROJECT_ID \
//     --token YOUR_DEVICE_FCM_TOKEN \
//     --title "Title" \
//     --body "Body" \
//     [--route "/orders/123"]
// Requires GOOGLE_APPLICATION_CREDENTIALS env pointing to a service account JSON with Firebase Admin permissions.

const _scopes = [
  'https://www.googleapis.com/auth/firebase.messaging',
];

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('project-id', help: 'Firebase project ID', mandatory: true)
    ..addOption('token', help: 'Device FCM token', mandatory: true)
    ..addOption('title', help: 'Notification title', defaultsTo: 'Thông báo')
    ..addOption('body', help: 'Notification body', defaultsTo: '')
    ..addOption('route', help: 'Optional route payload', defaultsTo: '');

  final results = parser.parse(args);
  final projectId = results['project-id'] as String;
  final token = results['token'] as String;
  final title = results['title'] as String;
  final body = results['body'] as String;
  final route = results['route'] as String;

  final credsPath = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];
  if (credsPath == null || credsPath.isEmpty) {
    stderr.writeln('GOOGLE_APPLICATION_CREDENTIALS env var is not set');
    exit(1);
  }

  final serviceAccount = File(credsPath);
  if (!await serviceAccount.exists()) {
    stderr.writeln('Service account file not found at $credsPath');
    exit(1);
  }

  final credentials = auth.ServiceAccountCredentials.fromJson(
    jsonDecode(await serviceAccount.readAsString()) as Map<String, dynamic>,
  );

  final client = await auth.clientViaServiceAccount(credentials, _scopes);

  final url = Uri.parse(
      'https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

  final payload = {
    'message': {
      'token': token,
      'notification': {
        'title': title,
        'body': body,
      },
      'data': {
        'route': route,
      }
    }
  };

  final resp = await client.post(
    url,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
    },
    body: jsonEncode(payload),
  );

  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    stdout.writeln('✅ Sent: ${resp.body}');
  } else {
    stderr.writeln('❌ Error ${resp.statusCode}: ${resp.body}');
    exit(2);
  }
}
