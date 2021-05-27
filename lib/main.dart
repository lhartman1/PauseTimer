import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:intl/intl.dart';
import 'package:synchronized/synchronized.dart';
import 'package:duration_picker/duration_picker.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pause Timer',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.green,
      ),
      home: MyHomePage(title: 'Pause Timer'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  final lock = Lock();

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Timer? _pauseTimer;
  Duration _duration = Duration.zero;

  @override
  Widget build(BuildContext context) {
    Widget durationPicker = DurationPicker(
      duration: _duration,
      onChange: (val) {
        setState(() => _duration = val);
      },
    );

    // While a pause timer is active, make the durationPicker "inactive".
    if (_pauseTimer != null) {
      durationPicker = AbsorbPointer(
        child: Theme(
          data: ThemeData(primarySwatch: Colors.grey),
          child: durationPicker,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(child: durationPicker),
      floatingActionButton: _pauseTimer == null
          ? FloatingActionButton.extended(
              onPressed: () => createMediaPauseTimer(context, _duration),
              label: Text('Start Pause Timer'),
              icon: Icon(Icons.schedule),
            )
          : FloatingActionButton.extended(
              onPressed: cancelMediaPauseTimer,
              label: Text('Stop Pause Timer'),
              icon: Icon(Icons.stop),
            ),
    );
  }

  void pauseMedia() {
    debugPrint('Pausing media');
    AudioSession.instance.then((session) => session.setActive(true));
  }

  void cancelMediaPauseTimer() {
    debugPrint('Canceling pause timer');
    setState(() {
      widget.lock.synchronized(() {
        _pauseTimer?.cancel();
        _pauseTimer = null;
      });
    });
    FlutterBackground.disableBackgroundExecution();
  }

  void showErrorSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Background permission must be granted. Please try again.'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void createMediaPauseTimer(BuildContext context, Duration duration) async {
    // First call to initialize asks for permission.
    if (!await FlutterBackground.initialize()) {
      showErrorSnackBar(context);
      return;
    }

    final pauseTime = DateTime.now().add(duration);
    final pauseTimeStr = DateFormat.jm().format(pauseTime);
    final androidConfig = FlutterBackgroundAndroidConfig(
      notificationTitle: 'Will pause media at approx. $pauseTimeStr',
      notificationText: 'Return to app to cancel',
      notificationImportance: AndroidNotificationImportance.Default,
    );

    // Call initialize again. This time will accurate time in notification.
    if (!await FlutterBackground.initialize(androidConfig: androidConfig)) {
      showErrorSnackBar(context);
      return;
    }

    if (await FlutterBackground.enableBackgroundExecution()) {
      debugPrint('Pausing media at $pauseTime (Duration: $duration)');
      setState(() {
        widget.lock.synchronized(() {
          _pauseTimer = Timer(duration, () {
            pauseMedia();
            FlutterBackground.disableBackgroundExecution();
            setState(() {
              widget.lock.synchronized(() => _pauseTimer = null);
            });
          });
        });
      });
    }
  }
}
