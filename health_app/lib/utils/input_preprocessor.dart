/// Utility class for preprocessing and validating text input
class InputPreprocessor {
  /// Maximum recommended input length (characters)
  /// This is a soft limit - the model will truncate tokens anyway
  static const int maxRecommendedLength = 1000;

  /// Normalize text input
  /// - Trims whitespace
  /// - Converts to lowercase (tokenizer will do this, but good to be consistent)
  static String normalize(String text) {
    if (text.isEmpty) {
      return text;
    }
    return text.trim();
  }

  /// Validate input text
  /// Returns null if valid, error message if invalid
  static String? validate(String? text) {
    if (text == null) {
      return 'Input text cannot be null';
    }

    final normalized = normalize(text);
    
    if (normalized.isEmpty) {
      return 'Input text cannot be empty';
    }

    if (normalized.length > maxRecommendedLength) {
      return 'Input text is too long (max ${maxRecommendedLength} characters recommended)';
    }

    return null;
  }

  /// Check if text is valid (non-null and non-empty after normalization)
  static bool isValid(String? text) {
    return validate(text) == null;
  }

  /// Get length of normalized text
  static int getLength(String? text) {
    if (text == null) {
      return 0;
    }
    return normalize(text).length;
  }

  /// Clean text (basic cleaning - remove excessive whitespace)
  /// This is a simple implementation - can be extended if needed
  static String clean(String text) {
    if (text.isEmpty) {
      return text;
    }
    
    // Normalize whitespace: replace multiple spaces/tabs/newlines with single space
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }
}

