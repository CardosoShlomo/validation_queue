import 'package:ui_payload/ui_payload.dart';

/// Controls when validation should stop in a queue.
///
/// Use this to optimize validation by stopping early when a condition is met,
/// or to ensure all validators run regardless of results.
abstract class TerminationStrategy {
  /// Returns true if validation queue should stop after this payload.
  bool shouldStop(UIPayload? payload);
}

/// Never stops - validation continues regardless of result.
///
/// Use when this validation's result shouldn't affect subsequent validations.
///
/// Example:
/// ```dart
/// Validation(
///   validator: MinLength(8),
///   failureMsg: Warning(SimpleText('Weak password')),
///   after: NeverStop(), // Continue even if password is weak
/// )
/// ```
class NeverStop implements TerminationStrategy {
  const NeverStop();
  @override
  bool shouldStop(UIPayload? payload) => false;
}

/// Always stops after the first validator.
///
/// Use when you only want the first validation result.
class AlwaysStop implements TerminationStrategy {
  const AlwaysStop();
  @override
  bool shouldStop(UIPayload? payload) => true;
}

/// Stops immediately when a Failure is encountered.
///
/// Use when you want to stop validation as soon as any failure occurs.
///
/// Example:
/// ```dart
/// Validation(
///   validator: Required(),
///   failureMsg: Failure(SimpleText('Required')),
///   after: StopAfterFailure(), // If this validation returns Failure, stop the queue
/// )
/// ```
class StopAfterFailure implements TerminationStrategy {
  const StopAfterFailure();
  @override
  bool shouldStop(UIPayload? payload) => payload is Failure;
}

/// Stops if the payload contains a Failure anywhere in its structure.
///
/// Checks nested UIPayloads lists for failures.
class StopIfContainsFailure implements TerminationStrategy {
  const StopIfContainsFailure();

  @override
  bool shouldStop(UIPayload? payload) {
    return payload?.containsFailure() ?? false;
  }
}

/// Stops after specific severity levels.
///
/// Example:
/// ```dart
/// // Stop on failure or warning, but continue on info/success
/// StopAfterSeverity(failure: true, warning: true)
/// ```
class StopAfterSeverity implements TerminationStrategy {
  const StopAfterSeverity({
    this.failure = false,
    this.warning = false,
    this.info = false,
    this.success = false
  });

  final bool failure;
  final bool warning;
  final bool info;
  final bool success;

  @override
  bool shouldStop(UIPayload? payload) {
    return switch (payload) {
      Failure() => failure,
      Warning() => warning,
      Info() => info,
      Success() => success,
      _ => false,
    };
  }
}

/// Custom termination logic using a predicate function.
///
/// Example:
/// ```dart
/// StopAfterCustom((payload) => payload is Failure || payload is Warning)
/// ```
class StopAfterCustom implements TerminationStrategy {
  const StopAfterCustom(this.predicate);

  final bool Function(UIPayload? payload) predicate;

  @override
  bool shouldStop(UIPayload? payload) => predicate(payload);
}