import 'package:workmanager/workmanager.dart';
import '../services/health_service.dart';
import '../services/notion_service.dart';

class BackgroundService {
  static const String syncTaskName = 'syncSleepData';
  static const Duration syncInterval = Duration(days: 1);

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      syncTaskName,
      syncTaskName,
      frequency: syncInterval,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == BackgroundService.syncTaskName) {
      await _syncSleepData();
    }
    return true;
  });
}

Future<void> _syncSleepData() async {
  final healthService = HealthService();
  final notionService = NotionService();

  await notionService.initialize();

  final sleepData = await healthService.getSleepData();
  if (sleepData.isEmpty) {
    return;
  }

  // Process sleep data
  final processedData = _processSleepData(sleepData);

  // Send to Notion
  await notionService.addSleepData(processedData);
}

Map<String, dynamic> _processSleepData(List<dynamic> sleepData) {
  // Calculate total sleep duration and quality
  Duration totalSleep = Duration.zero;
  int deepSleepMinutes = 0;
  int lightSleepMinutes = 0;
  int awakeMinutes = 0;

  for (var data in sleepData) {
    final duration = data.endTime.difference(data.startTime);
    final sleepStage = data.metadata['sleepStage'] as String? ?? 'Unknown';

    if (sleepStage == 'DEEP') {
      deepSleepMinutes += int.parse(duration.inMinutes.toString());
      totalSleep += duration;
    } else if (sleepStage == 'LIGHT') {
      lightSleepMinutes += int.parse(duration.inMinutes.toString());
      totalSleep += duration;
    } else if (sleepStage == 'AWAKE') {
      awakeMinutes += int.parse(duration.inMinutes.toString());
    }
  }

  // Calculate sleep quality based on deep sleep percentage
  final totalSleepMinutes = totalSleep.inMinutes;
  final deepSleepPercentage =
      totalSleepMinutes > 0 ? (deepSleepMinutes / totalSleepMinutes) * 100 : 0;

  String quality;
  if (deepSleepPercentage >= 20) {
    quality = 'Excellent';
  } else if (deepSleepPercentage >= 15) {
    quality = 'Good';
  } else if (deepSleepPercentage >= 10) {
    quality = 'Fair';
  } else {
    quality = 'Poor';
  }

  return {
    'date': DateTime.now().toIso8601String().split('T')[0],
    'duration': totalSleep.inHours + (totalSleep.inMinutes % 60) / 60,
    'quality': quality,
    'notes':
        'Deep: ${deepSleepPercentage.toStringAsFixed(1)}%, Light: ${(lightSleepMinutes / totalSleepMinutes * 100).toStringAsFixed(1)}%, Awake: ${(awakeMinutes / totalSleepMinutes * 100).toStringAsFixed(1)}%'
  };
}
