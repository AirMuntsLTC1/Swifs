import '../cache/local_cache.dart';
import '../data/models.dart';
import '../data/social.dart';

/// Outbox: sends likes, saves, follows and comments to Supabase in the background.
///
/// - The screen updates at once. The action is saved on the phone first, so it survives
///   closing the app or going offline.
/// - Network failures are retried with backoff. Server rejections call onFail so the screen can undo.
/// - A newer action with the same key replaces an unsent one.
class InteractionQueue {
  InteractionQueue._();
  static final InteractionQueue instance = InteractionQueue._();

  static const int _maxAttempts = 8;
  static const List<int> _backoffSeconds = [2, 5, 10, 20, 40, 60];

  final List<_Job> _jobs = [];
  bool _running = false;
  bool _restored = false;

  /// Loads actions saved from last time and sends them. Call once at app start.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final raw = await LocalCache.instance.read('outbox');
    if (raw is List) {
      for (final e in raw) {
        _jobs.add(_Job(OutboxOp.fromJson(Map<String, dynamic>.from(e as Map)), null, null));
      }
    }
    _pump();
  }

  void enqueue(
    OutboxOp op, {
    void Function(dynamic result)? onSuccess,
    void Function(DataException error)? onFail,
  }) {
    _jobs.removeWhere((j) => j.op.key == op.key && !j.inFlight);
    _jobs.add(_Job(op, onSuccess, onFail));
    _save();
    _pump();
  }

  Future<void> _save() => LocalCache.instance.write('outbox', [for (final j in _jobs) j.op.toJson()]);

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (_jobs.isNotEmpty) {
        final now = DateTime.now();
        final ready = _jobs.where((j) => !j.nextAt.isAfter(now)).toList();
        if (ready.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        final job = ready.first;
        job.inFlight = true;
        dynamic result;
        try {
          result = await social.run(job.op);
        } on DataException catch (e) {
          job.inFlight = false;
          if (e.retryable && job.attempts < _maxAttempts - 1) {
            job.attempts++;
            job.nextAt = DateTime.now().add(_backoff(job.attempts));
          } else {
            _jobs.remove(job);
            await _save();
            job.onFail?.call(e);
          }
          continue;
        } catch (e) {
          job.inFlight = false;
          _jobs.remove(job);
          await _save();
          job.onFail?.call(DataException(e.toString()));
          continue;
        }

        _jobs.remove(job);
        await _save();
        job.onSuccess?.call(result);
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
  final OutboxOp op;
  final void Function(dynamic result)? onSuccess;
  final void Function(DataException error)? onFail;
  int attempts = 0;
  bool inFlight = false;
  DateTime nextAt = DateTime.fromMillisecondsSinceEpoch(0);

  _Job(this.op, this.onSuccess, this.onFail);
}


