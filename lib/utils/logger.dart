import 'dart:developer' as dev;

/// Logs that survive release builds (visible in logcat as flutter tag)
void rlog(String message, {String tag = 'MusicApp'}) {
  dev.log(message, name: tag);
}
