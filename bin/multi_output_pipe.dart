import 'dart:io';

class MultiOutputPipe {
  String _lastPrintOneMessage = '';

  /// Print a message that changes over time, rewriting the line.
  void printOne(String message) {
    _lastPrintOneMessage = message;
    stdout.write('\r$message');
  }

  /// Print an arbitrary message that should stay one line above the printOne message.
  void printRecurring(String message) {
    stdout.write('\r$message\n');
    stdout.write('\r$_lastPrintOneMessage');
  }

  void end() {
    stdout.write('\n');
  }
}
