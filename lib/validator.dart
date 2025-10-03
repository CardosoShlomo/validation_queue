/// Mixin for objects that hold state to be validated.
/// Used internally for related validation.
mixin ValidatorTarget<S> {
  S get state;
}

/// Base class for all validators.
///
/// Validators check if a state value meets certain criteria.
/// They return true for valid, false for invalid.
///
/// Example:
/// ```dart
/// const validator = Validator.required();
/// validator.isValid('hello'); // true
/// validator.isValid('');      // false
/// ```
sealed class Validator<S> {
  const Validator();

  /// Returns true if the state is valid according to this validator's rules.
  bool isValid(S state);

  /// Creates a validator with custom logic.
  const factory Validator.custom(bool Function(S state) isValidCallback) = CustomValidator<S>;

  /// Validates that the value is not empty/null.
  const factory Validator.required() = RequiredValidator<S>;

  /// Validates exact length for strings/iterables.
  const factory Validator.exactLength(int value) = ExactLengthValidator<S>;

  /// Validates minimum length for strings/iterables.
  const factory Validator.minLength(int value) = MinLengthValidator<S>;

  /// Validates maximum length for strings/iterables.
  const factory Validator.maxLength(int value) = MaxLengthValidator<S>;
}

/// Validator with custom validation logic.
class CustomValidator<S> extends Validator<S> {
  const CustomValidator(this.isValidCallback);

  final bool Function(S state) isValidCallback;

  @override
  bool isValid(S state) => isValidCallback(state);
}

/// Validates that a value is not empty or null.
///
/// - Strings: must not be empty
/// - Iterables: must not be empty
/// - Booleans: must be true (unless nullable)
/// - Other types: must not be null
class RequiredValidator<S> extends Validator<S> {
  const RequiredValidator();

  @override
  bool isValid(S state) {
    return switch (state) {
      String() => state.isNotEmpty,
      Iterable() => state.isNotEmpty,
      bool() => null is S || state,
      _ => state != null,
    };
  }
}

/// Base class for length validators.
sealed class LengthValidator<S> extends Validator<S> {
  const LengthValidator(this.value);
  final int value;
}

/// Validates exact length.
class ExactLengthValidator<S> extends LengthValidator<S> {
  const ExactLengthValidator(super.value);

  @override
  bool isValid(S state) {
    return switch (state) {
      String() => state.length == value,
      Iterable() => state.length == value,
      _ => false,
    };
  }
}

/// Validates minimum length.
class MinLengthValidator<S> extends LengthValidator<S> {
  const MinLengthValidator(super.value);

  @override
  bool isValid(S state) {
    return switch (state) {
      String() => state.length >= value,
      Iterable() => state.length >= value,
      _ => false,
    };
  }
}

/// Validates maximum length.
class MaxLengthValidator<S> extends LengthValidator<S> {
  const MaxLengthValidator(super.value);

  @override
  bool isValid(S state) {
    return switch (state) {
      String() => state.length <= value,
      Iterable() => state.length <= value,
      _ => false,
    };
  }
}

/// Base class for pattern-based validators (regex).
sealed class PatternValidator extends Validator<String> {
  const PatternValidator(this.pattern);
  final Pattern pattern;
}

/// Validates that string matches the pattern.
class AllowPatternValidator extends PatternValidator {
  const AllowPatternValidator(super.pattern);

  @override
  bool isValid(String state) => pattern.allMatches(state).isNotEmpty;
}

/// Validates that string does NOT match the pattern.
class DenyPatternValidator extends PatternValidator {
  const DenyPatternValidator(super.pattern);

  @override
  bool isValid(String state) => pattern.allMatches(state).isEmpty;
}

/// Base class for validators that depend on another field's value.
///
/// Used for "password confirmation" style validation where one field
/// must match or differ from another.
sealed class RelatedValidator<S> {
  const RelatedValidator();

  /// Builds a concrete validator given a target field's state.
  DependantValidator<S, ValidatorTarget> build(ValidatorTarget target);
}

/// Base class for validators that depend on a specific target value.
sealed class DependantValidator<S, SS extends ValidatorTarget> extends Validator<S> {
  const DependantValidator(this.target);
  final SS target;
}

/// Validates that value equals another field's value.
///
/// Example: Password confirmation must match password.
class IsSameAsValidator<S> extends DependantValidator<S, ValidatorTarget> {
  const IsSameAsValidator(super.target);

  @override
  bool isValid(S state) => state == target.state;
}

/// Validates that value differs from another field's value.
///
/// Example: New password must differ from old password.
class IsDifferentFromValidator<S> extends DependantValidator<S, ValidatorTarget> {
  const IsDifferentFromValidator(super.target);

  @override
  bool isValid(S state) => state != target.state;
}