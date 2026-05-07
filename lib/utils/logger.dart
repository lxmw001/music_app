import 'dart:developer' as dev;

/// Logs that survive release builds (visible in logcat as flutter tag)
void rlog(String message, {String tag = 'MusicApp'}) {
  final now = DateTime.now();
  final ts = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}.${now.millisecond.toString().padLeft(3,'0')}';
  dev.log('[$ts] $message', name: tag);
}
