import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/health_service.dart';
import 'services/notion_service.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sleep Tracker',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _healthService = HealthService();
  final _notionService = NotionService();
  bool _isAuthorized = false;
  String _notionApiKey = '';
  String _notionDatabaseId = '';
  final _formKey = GlobalKey<FormState>();
  String _sleepData = 'No data fetched yet';

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _checkAuthorization();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notionApiKey = prefs.getString('notion_api_key') ?? '';
      _notionDatabaseId = prefs.getString('notion_database_id') ?? '';
    });
  }

  Future<void> _checkAuthorization() async {
    final authorized = await _healthService.requestPermissions();
    setState(() {
      _isAuthorized = authorized;
    });
  }

  Future<void> _saveNotionCredentials() async {
    if (_formKey.currentState!.validate()) {
      await _notionService.saveCredentials(_notionApiKey, _notionDatabaseId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notion credentials saved successfully')),
      );
    }
  }

  Future<void> _fetchSleepData() async {
    try {
      final sleepData = await _healthService.getSleepData();
      setState(() {
        if (sleepData.isEmpty) {
          _sleepData = 'No sleep data found';
        } else {
          final buffer = StringBuffer();
          buffer.writeln('Sleep data for the last 24 hours:');
          buffer.writeln('');

          for (var data in sleepData) {
            final from = data.startTime;
            final to = data.endTime;
            final duration = to.difference(from);
            final type = data.metadata['sleepStage'] ?? 'Unknown';

            buffer.writeln(
                '${from.hour}:${from.minute} - ${to.hour}:${to.minute}');
            buffer.writeln('Type: $type');
            buffer.writeln(
                'Duration: ${duration.inHours}h ${duration.inMinutes % 60}m');
            buffer.writeln('');
          }

          _sleepData = buffer.toString();
        }
      });
    } catch (e) {
      setState(() {
        _sleepData = 'Error fetching sleep data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: const Text('Sleep Tracker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Health Connect Status: ${_isAuthorized ? 'Authorized' : 'Not Authorized'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isAuthorized ? _fetchSleepData : null,
                child: const Text('Fetch Sleep Data'),
              ),
              const SizedBox(height: 20),
              Text(
                'Sleep Data:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_sleepData),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notion Integration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Notion API Key',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _notionApiKey,
                      onChanged: (value) => _notionApiKey = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your Notion API key';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Notion Database ID',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _notionDatabaseId,
                      onChanged: (value) => _notionDatabaseId = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your Notion Database ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _saveNotionCredentials,
                      child: const Text('Save Notion Credentials'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
