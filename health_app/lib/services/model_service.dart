import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:convert';

/// Enum for supported model types
enum ModelType {
  tiny,
  distil,
}

/// Service for loading and managing the TFLite model, vocabulary, and labels
/// This is a singleton service that loads resources once and reuses them
class ModelService {
  // Singleton instance
  static final ModelService _instance = ModelService._internal();
  factory ModelService() => _instance;
  ModelService._internal();

  Interpreter? _interpreter;
  Map<String, int>? _vocab;
  List<String>? _labels;
  bool _isInitialized = false;
  ModelType _currentModelType = ModelType.tiny;

  /// Get the TFLite interpreter instance
  Interpreter? get interpreter => _interpreter;

  /// Get the vocabulary map (token -> ID)
  Map<String, int>? get vocab => _vocab;

  /// Get the labels list
  List<String>? get labels => _labels;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get the current model type
  ModelType get currentModelType => _currentModelType;

  /// Get the current model name
  String get currentModelName {
    switch (_currentModelType) {
      case ModelType.tiny:
        return 'TinyBERT';
      case ModelType.distil:
        return 'DistilBERT';
    }
  }

  /// Initialize the model service by loading model, vocab, and labels
  /// [modelType] specifies which model to load (defaults to tiny for backward compatibility)
  /// Returns true if successful, false otherwise
  Future<bool> initialize({ModelType modelType = ModelType.tiny}) async {
    // If already initialized with the same model, return true
    if (_isInitialized && _currentModelType == modelType) {
      return true;
    }

    // If switching models, dispose current resources first
    if (_isInitialized && _currentModelType != modelType) {
      dispose();
    }

    _currentModelType = modelType;

    try {
      // Load and initialize the TFLite interpreter
      await _loadModel();
      
      // Load vocabulary
      await _loadVocab();
      
      // Load labels
      await _loadLabels();
      
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing ModelService: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Switch to a different model
  /// This will dispose the current model and load the new one
  Future<bool> switchModel(ModelType modelType) async {
    return await initialize(modelType: modelType);
  }

  /// Load the TFLite model from assets
  Future<void> _loadModel() async {
    try {
      // Determine model path based on model type
      String modelPath;
      switch (_currentModelType) {
        case ModelType.tiny:
          modelPath = 'assets/models/tiny/student_fp32.tflite';
          break;
        case ModelType.distil:
          modelPath = 'assets/models/distil/distilbert_fp32.tflite';
          break;
      }
      
      // Load model file from assets
      final modelData = await rootBundle.load(modelPath);
      
      // Create interpreter with 4 threads for better performance
      final interpreterOptions = InterpreterOptions()
        ..threads = 4;
      
      _interpreter = Interpreter.fromBuffer(
        modelData.buffer.asUint8List(),
        options: interpreterOptions,
      );
      
      debugPrint('✓ Model loaded successfully: ${currentModelName}');
    } catch (e) {
      debugPrint('Error loading model: $e');
      rethrow;
    }
  }

  /// Load vocabulary from vocab.txt and build token-to-ID map
  Future<void> _loadVocab() async {
    try {
      // Determine vocab path based on model type
      String vocabPath;
      switch (_currentModelType) {
        case ModelType.tiny:
          vocabPath = 'assets/tokenizer/tiny/vocab.txt';
          break;
        case ModelType.distil:
          vocabPath = 'assets/tokenizer/distil/vocab.txt';
          break;
      }
      
      final vocabData = await rootBundle.loadString(vocabPath);
      final vocabLines = vocabData.split('\n');
      
      _vocab = {};
      int index = 0;
      
      // Build vocabulary map: token -> ID
      for (int i = 0; i < vocabLines.length; i++) {
        final line = vocabLines[i].trim();
        if (line.isNotEmpty) {
          _vocab![line] = index;
          index++;
        }
      }
      
      debugPrint('✓ Vocab loaded: ${_vocab!.length} tokens');
    } catch (e) {
      debugPrint('Error loading vocab: $e');
      rethrow;
    }
  }

  /// Load label map from label_map.json
  Future<void> _loadLabels() async {
    try {
      // Determine label map path based on model type
      String labelPath;
      switch (_currentModelType) {
        case ModelType.tiny:
          labelPath = 'assets/models/tiny/label_map.json';
          break;
        case ModelType.distil:
          labelPath = 'assets/models/distil/label_map.json';
          break;
      }
      
      final labelData = await rootBundle.loadString(labelPath);
      final labelMap = jsonDecode(labelData) as Map<String, dynamic>;
      
      // Extract labels array
      final labelsList = labelMap['labels'] as List<dynamic>;
      _labels = [];
      
      for (int i = 0; i < labelsList.length; i++) {
        _labels!.add(labelsList[i] as String);
      }
      
      debugPrint('✓ Labels loaded: $_labels');
    } catch (e) {
      debugPrint('Error loading labels: $e');
      rethrow;
    }
  }

  /// Get token ID for a given token string
  /// Returns [UNK] token ID if token is not found
  int getTokenId(String token) {
    if (_vocab == null) {
      throw StateError('Vocabulary not loaded. Call initialize() first.');
    }
    
    // Check if token exists in vocab
    if (_vocab!.containsKey(token)) {
      return _vocab![token]!;
    }
    
    // Return [UNK] token ID if not found
    if (_vocab!.containsKey('[UNK]')) {
      return _vocab!['[UNK]']!;
    }
    
    // Fallback: return 0 if [UNK] is also not found (shouldn't happen)
    return 0;
  }

  /// Get special token IDs
  int getClsTokenId() {
    return getTokenId('[CLS]');
  }

  int getSepTokenId() {
    return getTokenId('[SEP]');
  }

  int getPadTokenId() {
    return getTokenId('[PAD]');
  }

  int getUnkTokenId() {
    return getTokenId('[UNK]');
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _vocab = null;
    _labels = null;
    _isInitialized = false;
  }
}

