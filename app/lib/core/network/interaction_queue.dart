import '../data/models.dart';

/// Background sender for likes, saves, follows and comments.
///
/// The screen updates at once. The task runs here, in order.
/// - Network failures (DataException.retryable) are retried with backoff.
/// - Server rejections call onFail so the screen can undo the change.
/// - A newer task with the same key replaces an unsent one. Tasks describe the
///   desired state, so the final state is always the last one the user chose.
///
/// Pending tasks live in memory. If the app closes while they are waiting, they are lost.
class InteractionQueue {
  InteractionQueue._();
  static final InteractionQueue instance = InteractionQueue._();

  static const int _maxAttempts = 6;
  static const List<int> _backoffSeconds = [1, 2, 4, 8, 15];

  final List<_Job> _jobs = [];
  bool _running = false;

  void enqueue<T>(
    String key,
    Future<T> Function() task, {
    void Function(T result)? onSuccess,
    void Function(DataException error)? onFail,
  }) {
    _jobs.removeWhere((j) => j.key == key && !j.inFlight);
    _jobs.add(_Job(
      key: key,
      task: () => task(),
      onOk: (r) => onSuccess?.call(r as T),
      onErr: (e) => onFail?.call(e),
    ));
    _pump();
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (_jobs.isNotEmpty) {
        final now = DateTime.now();
        final ready = _jobs.where((j) => !j.nextAt.isAfter(now)).toList();
        if (ready.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        }

        final job = ready.first;
        job.inFlight = true;
        dynamic result;
        try {
          result = await job.task();
        } on DataException catch (e) {
          job.inFlight = false;
          if (e.retryable && job.attempts < _maxAttempts - 1) {
            job.attempts++;
            job.nextAt = DateTime.now().add(_backoff(job.attempts));
          } else {
            _jobs.remove(job);
            job.onErr(e);
          }
          continue;
        } catch (e) {
          job.inFlight = false;
          _jobs.remove(job);
          job.onErr(DataException(e.toString()));
          continue;
        }

        _jobs.remove(job);
        job.onOk(result);
      }
    } finally {
      _running = false;
    }
  }

  static Duration _backoff(int attempt) {
    final index = (attempt - 1).clamp(0, _backoffSeconds.length - 1).toInt();
    return Duration(seconds: _backoffSeconds[index]);
  }
}

class _Job {
  final String key;
  final Future<dynamic> Function() task;
  final void Function(dynamic result) onOk;
  final void Function(DataException error) onErr;
  int attempts = 0;
  bool inFlight = false;
  DateTime nextAt = DateTime.fromMillisecondsSinceEpoch(0);

  _Job({required this.key, required this.task, required this.onOk, required this.onErr});
}
