# Validation Queue

Composable validation system with const support for Flutter and Dart.

Chain validators with termination strategies, handle cross-field validation, and compose results. All with const constructors for zero runtime overhead.

## Features

- **Const validators**: Define validation at compile-time
- **Composable queues**: Chain multiple validations
- **Termination strategies**: Control when validation stops
- **Cross-field validation**: Validate based on other field values
- **UI framework agnostic**: Returns UIPayload for any rendering layer

## Installation
```yaml
dependencies:
  validation_queue: ^0.1.0
```
## Usage
### Simple Validation
```dart
const validation = Validation(
  validator: Validator.required(),
  failureMsg: Failure(SimpleText('This field is required')),
);

final result = validation.validate('', []);
// Returns: Failure(SimpleText('This field is required'))
```
### Validation Queue
```dart
const emailValidation = Validation.queue([
  Validation(
    validator: Validator.required(),
    failureMsg: Failure(SimpleText('Email required')),
  ),
  Validation(
    validator: Validator.minLength(5),
    failureMsg: Failure(SimpleText('Email too short')),
  ),
  Validation(
    validator: AllowPatternValidator(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'),
    failureMsg: Failure(SimpleText('Invalid email format')),
  ),
]);

final result = emailValidation.validate('user@example.com', []);
```
### Cross-Field Validation
```dart
const passwordValidation = Validation(
  key: 'password',  // Store this field's value
  validator: Validator.minLength(8),
  failureMsg: Failure(SimpleText('Password too short')),
);

const confirmValidation = Validation.relatedTo(
  'password',  // Reference the stored password value
  validator: IsSameAsValidator(),
  failureMsg: Failure(SimpleText('Passwords must match')),
);

final history = <ValidationState>[];
passwordValidation.validate('mypassword', history);
confirmValidation.validate('different', history);
// Returns: Failure(SimpleText('Passwords must match'))
```
### Architecture
```
Validation → Validator → UIPayload
   (rule)     (logic)     (result)
```
Validations are const and can be defined once and reused throughout your app.
