import 'package:ui_payload/ui_payload.dart';
import 'package:validation_queue/termination_strategy.dart';
import 'package:validation_queue/validator.dart';

/// Stores validation state with a key for related validation.
class ValidationState<S, K extends Object> with ValidatorTarget<S> {
  const ValidationState(this.key, this.state);

  final K key;
  @override
  final S state;
}

/// A validation rule that can be applied to state.
///
/// Validations can be:
/// - Simple: Single validator with success/failure messages
/// - Queued: Multiple validations run in sequence
/// - Related: Validation that depends on other field values
///
/// Example:
/// ```dart
/// const emailValidation = Validation(
///   validator: Validator.required(),
///   failureMsg: Failure(SimpleText('Email required')),
/// );
///
/// const passwordMatch = Validation.relatedTo('password',
///   validator: IsSameAsValidator(),
///   failureMsg: Failure(SimpleText('Passwords must match')),
/// );
/// ```
sealed class Validation<S, K extends Object> {
  const Validation._({
    this.key,
    this.after = const StopAfterFailure(),
  });

  /// Optional key to store this validation's state in history.
  /// Used for related validation.
  final K? key;

  /// Strategy for when to stop validating in a queue.
  final TerminationStrategy after;

  /// Creates a validation that always passes.
  const factory Validation.valid({K? key}) = ValidValidation<S, K>;

  /// Creates a validation with a single validator and messages.
  const factory Validation({
    K? key,
    TerminationStrategy after,
    required Validator<S> validator,
    UIPayload? successMsg,
    UIPayload failureMsg,
  }) = MessageValidation<S, K>;

  /// Creates a queue of validations that run in sequence.
  const factory Validation.queue(List<Validation<S, K>> list, {
    K? key,
    TerminationStrategy after,
  }) = QueueValidation<S, K>;

  /// Creates a validation that depends on another field's value.
  ///
  /// The [key] identifies which previous validation state to use.
  const factory Validation.relatedTo(K key, {
    TerminationStrategy after,
    required RelatedValidator<S> validator,
    UIPayload? successMsg,
    UIPayload failureMsg,
  }) = RelatedValidation<S, K>;

  /// Validates the state and optionally records it in history.
  UIPayload? validate(final S state, final List<ValidationState> history) {
    final result = _validate(state, history);
    if (key != null) {
      history.add(ValidationState(key!, state));
    }
    return result;
  }

  UIPayload? _validate(S state, final List<ValidationState> history);
}

/// Validation that always passes (no-op).
class ValidValidation<S, K extends Object> extends Validation<S, K> {
  const ValidValidation({
    super.key,
    super.after = const NeverStop(),
  }) : super._();

  @override
  UIPayload? _validate(_, _) => null;
}

/// Validation with a single validator and messages.
class MessageValidation<S, K extends Object> extends Validation<S, K> {
  const MessageValidation({
    super.key,
    super.after,
    required this.validator,
    this.successMsg,
    this.failureMsg = const Failure(),
  }) : super._();

  final Validator<S> validator;
  final UIPayload? successMsg;
  final UIPayload failureMsg;

  @override
  UIPayload? _validate(S state, _) {
    return validator.isValid(state) ? successMsg : failureMsg;
  }
}

/// Queue of validations that run in sequence.
///
/// Each validation's `after` strategy controls if the queue continues.
/// The queue itself has an `after` for when nested in another queue.
///
/// Example:
/// ```dart
/// Validation.queue([
///   Validation(
///     validator: Required(),
///     after: StopAfterFailure(), // Stop queue if this fails
///   ),
///   Validation(
///     validator: MinLength(8),
///     after: NeverStop(), // Continue even if this fails
///   ),
/// ], after: StopIfContainsFailure()) // Stop parent queue if any failure
/// ```
class QueueValidation<S, K extends Object> extends Validation<S, K> {
  const QueueValidation(this.validations, {
    super.key,
    super.after = const StopIfContainsFailure(),
    this.compositeStrategy = const DefaultUIPayloadCompositeStrategy(),
  }) : super._();

  final List<Validation<S, K>> validations;
  final UIPayloadCompositeStrategy compositeStrategy;

  @override
  UIPayload? _validate(S state, final List<ValidationState> history) {
    UIPayload? payload;

    for (final validation in validations) {
      final result = validation.validate(state, history);
      payload = compositeStrategy.compose(payload, result);
      if (validation.after.shouldStop(result)) {
        break;
      }
    }

    return payload;
  }
}

/// Validation that depends on another field's value from history.
///
/// Looks up previous validation states by key and creates validators
/// that compare against those values.
class RelatedValidation<S, K extends Object> extends Validation<S, K> {
  const RelatedValidation(K key, {
    super.after,
    required this.validator,
    this.successMsg,
    this.failureMsg = const Failure(),
  }) : super._(key: key);

  final RelatedValidator<S> validator;
  final UIPayload? successMsg;
  final UIPayload failureMsg;

  @override
  UIPayload? _validate(S state, final List<ValidationState> history) {
    return Validation.queue([
      for (final validationState in history)
        if (validationState.key == key)
          Validation(
            after: after,
            validator: validator.build(validationState),
            successMsg: successMsg,
            failureMsg: failureMsg,
          ),
    ])._validate(state, history);
  }
}