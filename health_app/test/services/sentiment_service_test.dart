import 'package:flutter_test/flutter_test.dart';
import 'package:sentiment_analysis/services/model_service.dart';
import 'package:sentiment_analysis/services/sentiment_service.dart';
import 'package:sentiment_analysis/models/sentiment_result.dart';

void main() {
  group('SentimentService Tests', () {
    late ModelService modelService;
    late SentimentService sentimentService;

    setUpAll(() async {
      modelService = ModelService();
      final initialized = await modelService.initialize();
      if (!initialized) {
        throw Exception('Failed to initialize ModelService for tests');
      }
      sentimentService = SentimentService(modelService);
    });

    test('Analyze sentiment with normal text', () {
      final text = 'I love this product';
      final result = sentimentService.analyzeSentiment(text);
      
      expect(result, isA<SentimentResult>());
      expect(result.label, isA<String>());
      expect(['negative', 'neutral', 'positive'].contains(result.label), isTrue);
      expect(result.confidence, greaterThanOrEqualTo(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
      expect(result.latency, greaterThanOrEqualTo(0));
    });

    test('Analyze sentiment returns valid confidence', () {
      final text = 'This is a test';
      final result = sentimentService.analyzeSentiment(text);
      
      expect(result.confidence, greaterThanOrEqualTo(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
      expect(result.confidencePercentage, greaterThanOrEqualTo(0.0));
      expect(result.confidencePercentage, lessThanOrEqualTo(100.0));
    });

    test('Analyze sentiment includes latency', () {
      final text = 'Testing latency measurement';
      final result = sentimentService.analyzeSentiment(text);
      
      expect(result.latency, greaterThanOrEqualTo(0));
      expect(result.latency, isA<int>());
    });

    test('Analyze sentiment includes probabilities', () {
      final text = 'Test probabilities';
      final result = sentimentService.analyzeSentiment(text);
      
      expect(result.probabilities, isNotNull);
      expect(result.probabilities!.containsKey('negative'), isTrue);
      expect(result.probabilities!.containsKey('neutral'), isTrue);
      expect(result.probabilities!.containsKey('positive'), isTrue);
      
      // Probabilities should sum to approximately 1.0
      double sum = 0.0;
      result.probabilities!.forEach((key, value) {
        sum += value;
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThanOrEqualTo(1.0));
      });
      expect(sum, closeTo(1.0, 0.01));
    });

    test('Analyze sentiment with empty text throws error', () {
      expect(
        () => sentimentService.analyzeSentiment(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Analyze sentiment with whitespace only throws error', () {
      expect(
        () => sentimentService.analyzeSentiment('   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Analyze sentiment with very long text', () {
      // Create a very long text
      final words = <String>[];
      for (int i = 0; i < 100; i++) {
        words.add('word');
      }
      final text = words.join(' ');
      
      final result = sentimentService.analyzeSentiment(text);
      
      expect(result, isA<SentimentResult>());
      expect(result.label, isA<String>());
    });

    test('Analyze sentiment with special characters', () {
      final text = 'Hello! How are you? I\'m fine, thanks.';
      final result = sentimentService.analyzeSentiment(text);
      
      expect(result, isA<SentimentResult>());
      expect(result.label, isA<String>());
    });

    test('SentimentResult emoji property works', () {
      final text = 'test';
      final result = sentimentService.analyzeSentiment(text);
      
      final emoji = result.emoji;
      expect(emoji, isA<String>());
      expect(['😊', '😐', '😞'].contains(emoji), isTrue);
    });

    test('SentimentResult toString method works', () {
      final text = 'test';
      final result = sentimentService.analyzeSentiment(text);
      
      final string = result.toString();
      expect(string, isA<String>());
      expect(string.contains(result.label), isTrue);
      expect(string.contains('Confidence'), isTrue);
      expect(string.contains('Latency'), isTrue);
    });
  });
}

