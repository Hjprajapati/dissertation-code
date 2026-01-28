import 'package:flutter_test/flutter_test.dart';
import 'package:sentiment_analysis/services/model_service.dart';
import 'package:sentiment_analysis/services/tokenizer_service.dart';

void main() {
  group('TokenizerService Tests', () {
    late ModelService modelService;
    late TokenizerService tokenizerService;

    setUpAll(() async {
      modelService = ModelService();
      final initialized = await modelService.initialize();
      if (!initialized) {
        throw Exception('Failed to initialize ModelService for tests');
      }
      tokenizerService = TokenizerService(modelService);
    });

    test('Tokenize normal text', () {
      final text = 'I love this product';
      final result = tokenizerService.tokenize(text);
      
      expect(result.containsKey('input_ids'), isTrue);
      expect(result.containsKey('attention_mask'), isTrue);
      expect(result['input_ids']!.length, 128);
      expect(result['attention_mask']!.length, 128);
    });

    test('Tokenize empty text', () {
      final text = '';
      final result = tokenizerService.tokenize(text);
      
      expect(result['input_ids']!.length, 128);
      expect(result['attention_mask']!.length, 128);
    });

    test('Tokenize very long text', () {
      // Create a very long text
      final words = <String>[];
      for (int i = 0; i < 200; i++) {
        words.add('word');
      }
      final text = words.join(' ');
      
      final result = tokenizerService.tokenize(text);
      
      // Should be truncated to 128 tokens
      expect(result['input_ids']!.length, 128);
      expect(result['attention_mask']!.length, 128);
    });

    test('Tokenize text with special characters', () {
      final text = 'Hello! How are you? I\'m fine, thanks.';
      final result = tokenizerService.tokenize(text);
      
      expect(result['input_ids']!.length, 128);
      expect(result['attention_mask']!.length, 128);
    });

    test('Tokenize text with unknown tokens', () {
      // Use text that likely contains unknown words
      final text = 'xyzabc123 unknownword999';
      final result = tokenizerService.tokenize(text);
      
      expect(result['input_ids']!.length, 128);
      expect(result['attention_mask']!.length, 128);
    });

    test('Input IDs contain [CLS] and [SEP] tokens', () {
      final text = 'test';
      final result = tokenizerService.tokenize(text);
      final inputIds = result['input_ids']!;
      
      final clsTokenId = modelService.getClsTokenId();
      final sepTokenId = modelService.getSepTokenId();
      
      // First token should be [CLS]
      expect(inputIds[0], clsTokenId);
      
      // Find [SEP] token (should be after the text tokens)
      bool foundSep = false;
      for (int i = 0; i < inputIds.length; i++) {
        if (inputIds[i] == sepTokenId && i > 0) {
          foundSep = true;
          break;
        }
      }
      expect(foundSep, isTrue);
    });

    test('Attention mask matches padding', () {
      final text = 'short text';
      final result = tokenizerService.tokenize(text);
      final inputIds = result['input_ids']!;
      final attentionMask = result['attention_mask']!;
      final padTokenId = modelService.getPadTokenId();
      
      // Attention mask should be 0 where input_ids is PAD, 1 otherwise
      for (int i = 0; i < inputIds.length; i++) {
        if (inputIds[i] == padTokenId) {
          expect(attentionMask[i], 0);
        } else {
          expect(attentionMask[i], 1);
        }
      }
    });

    test('Tokenize unicode characters', () {
      final text = 'Hello 世界 مرحبا';
      final result = tokenizerService.tokenize(text);
      
      expect(result['input_ids']!.length, 128);
      expect(result['attention_mask']!.length, 128);
    });
  });
}

