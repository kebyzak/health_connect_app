import 'package:flutter_health_connect/flutter_health_connect.dart';

class HealthService {
  final List<HealthConnectDataType> _types = [
    HealthConnectDataType.SleepSession,
    HealthConnectDataType.SleepStage,
  ];

  Future<bool> checkAvailability() async {
    try {
      // Check if Health Connect is available
      final isAvailable = await HealthConnectFactory.isAvailable();
      if (!isAvailable) {
        print('Health Connect is not available');
        // Try to install Health Connect
        await HealthConnectFactory.installHealthConnect();
        return false;
      }

      print('Health Connect is available');
      return true;
    } catch (e) {
      print('Error checking availability: $e');
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final isAvailable = await checkAvailability();
      if (!isAvailable) {
        return false;
      }

      print('Requesting permissions for types: $_types');
      final granted = await HealthConnectFactory.requestPermissions(
        _types,
        readOnly: true,
      );
      print('Permissions granted: $granted');
      return granted;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<List<dynamic>> getSleepData() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final yesterday = midnight.subtract(const Duration(days: 1));

    try {
      // First check if Health Connect is available and permissions are granted
      final isAvailable = await checkAvailability();
      if (!isAvailable) {
        print('Health Connect is not available');
        return [];
      }

      final hasPermissions = await HealthConnectFactory.hasPermissions(
        _types,
        readOnly: true,
      );

      if (!hasPermissions) {
        print('Permissions not granted');
        final granted = await requestPermissions();
        if (!granted) {
          return [];
        }
      }

      // Fetch sleep sessions
      final sleepSessions = await HealthConnectFactory.getRecord(
        type: HealthConnectDataType.SleepSession,
        startTime: yesterday,
        endTime: now,
      );

      // Fetch sleep stages
      final sleepStages = await HealthConnectFactory.getRecord(
        type: HealthConnectDataType.SleepStage,
        startTime: yesterday,
        endTime: now,
      );

      final sessions =
          sleepSessions[HealthConnectDataType.SleepSession.name] ?? [];
      final stages = sleepStages[HealthConnectDataType.SleepStage.name] ?? [];

      print('Found ${sessions.length} sleep sessions');
      print('Found ${stages.length} sleep stages');

      // Combine sleep sessions with their stages
      for (var session in sessions) {
        final sessionStart = session.startTime;
        final sessionEnd = session.endTime;
        final sessionStages = stages
            .where((stage) =>
                stage.startTime.isAfter(sessionStart) &&
                stage.endTime.isBefore(sessionEnd))
            .toList();
        session.metadata['stages'] = sessionStages;
      }

      return sessions;
    } catch (e) {
      print('Error fetching sleep data: $e');
      return [];
    }
  }
}
