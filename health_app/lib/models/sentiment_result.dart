/// Data model for sentiment analysis results
class SentimentResult {
  /// The predicted sentiment label (negative, neutral, or positive)
  final String label;
  
  /// Confidence score (0.0 to 1.0)
  final double confidence;
  
  /// Inference latency in milliseconds
  final int latency;
  
  /// Raw logits array for debugging (optional)
  final List<double>? rawLogits;
  
  /// Probability distribution for all classes
  final Map<String, double>? probabilities;

  SentimentResult({
    required this.label,
    required this.confidence,
    required this.latency,
    this.rawLogits,
    this.probabilities,
  });

  /// Get confidence as percentage (0-100)
  double get confidencePercentage => confidence * 100.0;

  /// Get emoji indicator for the sentiment
  String get emoji {
    if (label == 'positive') {
      return '😊';
    } else if (label == 'negative') {
      return '😞';
    } else {
      return '😐';
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('SentimentResult:');
    buffer.writeln('  Label: $label $emoji');
    buffer.writeln('  Confidence: ${confidencePercentage.toStringAsFixed(2)}%');
    buffer.writeln('  Latency: ${latency}ms');
    
    if (probabilities != null) {
      buffer.writeln('  Probabilities:');
      probabilities!.forEach((key, value) {
        buffer.writeln('    $key: ${(value * 100).toStringAsFixed(2)}%');
      });
    }
    
    if (rawLogits != null) {
      buffer.writeln('  Raw Logits: $rawLogits');
    }
    
    return buffer.toString();
  }
}

