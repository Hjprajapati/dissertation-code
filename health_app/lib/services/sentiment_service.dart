import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import 'model_service.dart';
import 'tokenizer_service.dart';
import '../models/sentiment_result.dart';
import '../utils/input_preprocessor.dart';

/// Service for performing sentiment analysis on text input
/// Combines tokenization and model inference
class SentimentService {
  final ModelService _modelService;
  final TokenizerService _tokenizerService;

  SentimentService(this._modelService)
      : _tokenizerService = TokenizerService(_modelService);

  /// Analyze sentiment of input text
  /// Returns a SentimentResult object with label, confidence, and latency
  SentimentResult analyzeSentiment(String text) {
    final stopwatch = Stopwatch()..start();

    if (!_modelService.isInitialized) {
      stopwatch.stop();
      throw StateError('ModelService not initialized. Call initialize() first.');
    }

    // Validate input
    final validationError = InputPreprocessor.validate(text);
    if (validationError != null) {
      stopwatch.stop();
      debugPrint('Input validation failed: $validationError');
      throw ArgumentError(validationError);
    }

    final normalizedText = InputPreprocessor.normalize(text);
    debugPrint(
      'Starting sentiment analysis for text: '
      '"${normalizedText.substring(0, normalizedText.length > 50 ? 50 : normalizedText.length)}..."',
    );

    try {
      // Step 1: Tokenize
      debugPrint('Step 1: Tokenizing input text...');
      final tokenized = _tokenizerService.tokenize(normalizedText);
      final inputIds = tokenized['input_ids']!;
      final attentionMask = tokenized['attention_mask']!;

      // Count non-padding tokens
      final padTokenId = _modelService.getPadTokenId();
      int tokenCount = 0;
      for (int i = 0; i < inputIds.length; i++) {
        if (inputIds[i] != padTokenId) tokenCount++;
      }
      debugPrint('Tokenization complete: $tokenCount tokens (padded to ${inputIds.length})');

      // Step 2: Prepare input tensors [1, 128]
      debugPrint('Step 2: Preparing input tensors...');
      
      // Validate input lengths are exactly 128
      if (inputIds.length != 128) {
        stopwatch.stop();
        throw StateError('Input IDs length mismatch: expected 128, got ${inputIds.length}');
      }
      if (attentionMask.length != 128) {
        stopwatch.stop();
        throw StateError('Attention mask length mismatch: expected 128, got ${attentionMask.length}');
      }
      
      debugPrint('Input IDs length: ${inputIds.length}, Attention mask length: ${attentionMask.length}');

      // Get interpreter and tensor info for debugging
      final tfl.Interpreter interpreter = _modelService.interpreter!;
      final inputTensors = interpreter.getInputTensors();
      final outputTensors = interpreter.getOutputTensors();
      debugPrint('Interpreter input[0] shape: ${inputTensors[0].shape}, type: ${inputTensors[0].type}');
      debugPrint('Interpreter input[1] shape: ${inputTensors[1].shape}, type: ${inputTensors[1].type}');
      debugPrint('Interpreter output[0] shape: ${outputTensors[0].shape}, type: ${outputTensors[0].type}');

      // Step 3: Run inference using standard run() method
      debugPrint('Step 3: Running model inference...');
      final inferenceStart = stopwatch.elapsedMilliseconds;

      // Convert inputs to typed data (Int32List) for proper memory alignment
      // Model expects int32 inputs, so use Int32List for native interop
      final inputIdsTyped = Int32List.fromList(inputIds);
      final attentionMaskTyped = Int32List.fromList(attentionMask);
      debugPrint('Converted inputs to typed data: Int32List (length ${inputIdsTyped.length})');

      // Create output buffer for FLOAT32 output
      // Output shape is [1, 3] (batch dimension, 3 logits)
      final outputLogits = [List.filled(3, 0.0)];
      
      // Run inference with typed data inputs and output buffer
      // Typed data ensures proper memory alignment for native TensorFlow Lite code
      try {
        // Allocate tensors before inference to ensure proper initialization
        // This is required to prevent native crashes (SIGSEGV)
        debugPrint('Allocating tensors...');
        interpreter.allocateTensors();
        debugPrint('Tensors allocated successfully');
        
        debugPrint('Calling interpreter.runForMultipleInputs() with typed data...');
        debugPrint('  Inputs: Int32List (length 128 each)');
        debugPrint('  Output: List<List<double>> (shape [1, 3])');
        
        // Use runForMultipleInputs for multiple inputs - this is the correct API
        // Wrap inputs in lists to match batch dimension [1, 128]
        // Output should be a Map<int, Object> where key is output index
        final inputList = [
          [inputIdsTyped],  // Wrap in list for batch dimension [1, 128]
          [attentionMaskTyped],  // Wrap in list for batch dimension [1, 128]
        ];
        final outputMap = {0: outputLogits};  // Map with output index 0
        
        interpreter.runForMultipleInputs(inputList, outputMap);
        debugPrint('Inference completed successfully with runForMultipleInputs');
        
        // Extract output from map - output is already FLOAT32, no dequantization needed
        final outputListResult = outputMap[0] as List<List<double>>;
        
        // Validate output contains non-zero values
        bool hasNonZero = false;
        if (outputListResult.isNotEmpty && outputListResult[0].isNotEmpty) {
          for (int i = 0; i < outputListResult[0].length; i++) {
            if (outputListResult[0][i] != 0.0) {
              hasNonZero = true;
              break;
            }
          }
        }
        if (!hasNonZero) {
          debugPrint('WARNING: Output buffer contains all zeros!');
        }
        
        debugPrint('Raw output values (FLOAT32): ${outputListResult[0]}');
        
        final inferenceTime = stopwatch.elapsedMilliseconds - inferenceStart;
        debugPrint('Inference completed in ${inferenceTime}ms');

        // Step 4: Extract logits (already FLOAT32, no conversion needed)
        debugPrint('Step 4: Extracting logits from FLOAT32 output...');
        final List<double> logits = List.from(outputListResult[0]);
        debugPrint('Logits: $logits');

        // Step 6: Softmax → probabilities
        debugPrint('Step 5: Applying softmax to get probabilities...');
        final probabilities = _softmax(logits);

        // Step 7: Argmax
        int maxIndex = 0;
        double maxProb = probabilities[0];
        for (int i = 1; i < probabilities.length; i++) {
          if (probabilities[i] > maxProb) {
            maxProb = probabilities[i];
            maxIndex = i;
          }
        }

        // Step 8: Map index to label
        final labels = _modelService.labels!;
        if (maxIndex >= labels.length) {
          stopwatch.stop();
          throw StateError('Invalid label index: $maxIndex');
        }

        final label = labels[maxIndex];
        final confidence = maxProb;

        stopwatch.stop();
        final totalLatency = stopwatch.elapsedMilliseconds;

        debugPrint('Step 6: Analysis complete');
        debugPrint('  Label: $label');
        debugPrint('  Confidence: ${(confidence * 100).toStringAsFixed(2)}%');
        debugPrint('  Total latency: ${totalLatency}ms');
        debugPrint(
          '  Probabilities: '
          'negative=${(probabilities[0] * 100).toStringAsFixed(2)}%, '
          'neutral=${(probabilities[1] * 100).toStringAsFixed(2)}%, '
          'positive=${(probabilities[2] * 100).toStringAsFixed(2)}%',
        );

        final probabilitiesMap = <String, double>{
          'negative': probabilities[0],
          'neutral': probabilities[1],
          'positive': probabilities[2],
        };

        return SentimentResult(
          label: label,
          confidence: confidence,
          latency: totalLatency,
          rawLogits: logits,
          probabilities: probabilitiesMap,
        );
      } catch (e) {
        stopwatch.stop();
        debugPrint('Error during interpreter.run(): $e');
        debugPrint('Input IDs type: ${inputIdsTyped.runtimeType}, length: ${inputIdsTyped.length}');
        debugPrint('Attention mask type: ${attentionMaskTyped.runtimeType}, length: ${attentionMaskTyped.length}');
        debugPrint('Output buffer type: ${outputLogits.runtimeType}, shape: [${outputLogits.length}, ${outputLogits[0].length}]');
        rethrow;
      }
    } catch (e) {
      stopwatch.stop();
      debugPrint('Error during sentiment analysis: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Softmax
  List<double> _softmax(List<double> logits) {
    double maxLogit = logits[0];
    for (int i = 1; i < logits.length; i++) {
      if (logits[i] > maxLogit) maxLogit = logits[i];
    }

    final List<double> expVals = [];
    double sumExp = 0.0;
    for (int i = 0; i < logits.length; i++) {
      final v = (logits[i] - maxLogit).clamp(-50.0, 50.0);
      final ev = exp(v);
      expVals.add(ev);
      sumExp += ev;
    }

    final List<double> probs = [];
    for (int i = 0; i < expVals.length; i++) {
      probs.add(expVals[i] / sumExp);
    }
    return probs;
  }
}