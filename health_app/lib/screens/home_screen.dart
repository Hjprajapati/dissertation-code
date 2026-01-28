import 'package:flutter/material.dart';
import '../services/model_service.dart';
import '../services/sentiment_service.dart';
import '../models/sentiment_result.dart';
import 'benchmark_screen.dart';

/// Home screen for sentiment analysis app
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final ModelService _modelService = ModelService();
  SentimentService? _sentimentService;
  SentimentResult? _result;
  bool _isLoading = false;
  bool _isModelLoading = true;
  String? _errorMessage;
  bool _hasInitialized = false;
  ModelType _selectedModelType = ModelType.tiny;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  /// Initialize the model service
  Future<void> _initializeModel({ModelType? modelType}) async {
    final targetModelType = modelType ?? _selectedModelType;
    
    debugPrint('\n=== INITIALIZING MODEL ===');
    debugPrint('Target model type: $targetModelType');
    debugPrint('Current selected: $_selectedModelType');
    debugPrint('ModelService initialized: ${_modelService.isInitialized}');
    debugPrint('ModelService current type: ${_modelService.currentModelType}');
    debugPrint('_hasInitialized: $_hasInitialized');
    
    // If already initialized with the same model, return
    if (_hasInitialized && _modelService.isInitialized && _modelService.currentModelType == targetModelType) {
      debugPrint('Model already initialized with same type, skipping...');
      return;
    }

    // If switching to a different model, reset the initialized flag
    if (_hasInitialized && _modelService.isInitialized && _modelService.currentModelType != targetModelType) {
      debugPrint('Switching models from ${_modelService.currentModelType} to $targetModelType');
      _hasInitialized = false;
    }

    try {
      setState(() {
        _isModelLoading = true;
        _errorMessage = null;
        _result = null; // Clear previous result when switching models
      });

      final success = await _modelService.initialize(modelType: targetModelType);
      
      debugPrint('Model initialization result: $success');
      debugPrint('ModelService current type after init: ${_modelService.currentModelType}');
      debugPrint('ModelService current name: ${_modelService.currentModelName}');
      
      if (success) {
        // Create a new SentimentService instance with the updated model
        _sentimentService = SentimentService(_modelService);
        _selectedModelType = targetModelType;
        debugPrint('Successfully initialized ${_modelService.currentModelName}');
        
        // Test inference with sample text to verify everything works
        try {
          debugPrint('\n=== TESTING SENTIMENT ANALYSIS ===');
          debugPrint('Testing with model: ${_modelService.currentModelName}');
          final testResult = _sentimentService!.analyzeSentiment("I feel a bit anxious but hopeful.");
          debugPrint('Test Result - Label: ${testResult.label}');
          debugPrint('Test Result - Confidence: ${testResult.confidence}');
          debugPrint('Test Result - Latency: ${testResult.latency}ms');
          debugPrint('=== TEST COMPLETE ===\n');
        } catch (e) {
          debugPrint('Test inference failed: $e');
          debugPrint('Stack trace: ${StackTrace.current}');
        }
        
        setState(() {
          _isModelLoading = false;
          _hasInitialized = true;
        });
      } else {
        setState(() {
          _isModelLoading = false;
          _errorMessage = 'Failed to initialize model. Please try again.';
          _hasInitialized = false;
        });
      }
    } catch (e) {
      setState(() {
        _isModelLoading = false;
        _errorMessage = 'Error loading model: $e';
        _hasInitialized = false;
      });
    }
  }

  /// Handle model type change
  Future<void> _onModelTypeChanged(ModelType? newType) async {
    if (newType == null || newType == _selectedModelType) {
      debugPrint('Model type change skipped: newType=$newType, current=$_selectedModelType');
      return;
    }
    
    debugPrint('\n=== MODEL TYPE CHANGED ===');
    debugPrint('From: $_selectedModelType');
    debugPrint('To: $newType');
    
    // Update the selected model type immediately for UI feedback
    setState(() {
      _selectedModelType = newType;
    });
    
    await _initializeModel(modelType: newType);
  }

  /// Analyze sentiment of input text
  Future<void> _analyzeSentiment() async {
    final text = _textController.text;
    
    if (text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter some text to analyze';
        _result = null;
      });
      return;
    }

    if (_sentimentService == null) {
      setState(() {
        _errorMessage = 'Model not initialized. Please wait or retry.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = _sentimentService!.analyzeSentiment(text);
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error analyzing sentiment: $e';
        _isLoading = false;
        _result = null;
      });
    }
  }

  /// Get color scheme based on sentiment
  ColorScheme _getColorScheme(String? label) {
    if (label == 'positive') {
      return ColorScheme.fromSeed(seedColor: Colors.green);
    } else if (label == 'negative') {
      return ColorScheme.fromSeed(seedColor: Colors.red);
    } else {
      return ColorScheme.fromSeed(seedColor: Colors.orange);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while model initializes
    if (_isModelLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sentiment Analysis'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading model...'),
              SizedBox(height: 8),
              Text(
                'This may take a few seconds',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Get color scheme based on current result
    final colorScheme = _getColorScheme(_result?.label);
    final theme = Theme.of(context).copyWith(colorScheme: colorScheme);

    return Theme(
      data: theme,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Sentiment Analysis'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.speed),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BenchmarkScreen()),
              );
            },
            tooltip: 'Performance Benchmark',
          ),
        ],
      ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Model selector section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Model:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ModelType>(
                        value: _selectedModelType,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: ModelType.tiny,
                            child: Text('TinyBERT'),
                          ),
                          DropdownMenuItem(
                            value: ModelType.distil,
                            child: Text('DistilBERT'),
                          ),
                        ],
                        onChanged: _isModelLoading ? null : _onModelTypeChanged,
                      ),
                      if (_hasInitialized) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green[600],
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Current: ${_modelService.currentModelName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Input section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter text to analyze:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _textController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Type your text here...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _analyzeSentiment,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Analyze Sentiment',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Error message section
              if (_errorMessage != null)
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                        if (!_hasInitialized)
                          TextButton(
                            onPressed: _initializeModel,
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ),
                ),

              if (_errorMessage != null) const SizedBox(height: 16),

              // Results section
              if (_result != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Emoji and label
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _result!.emoji,
                              key: ValueKey(_result!.label),
                              style: const TextStyle(fontSize: 64),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _result!.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Confidence score
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.analytics_outlined),
                              const SizedBox(width: 8),
                              Text(
                                'Confidence: ${_result!.confidencePercentage.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Latency
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.speed, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Latency: ${_result!.latency}ms',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Model name
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.model_training, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Model: ${_modelService.currentModelName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),

                          // Probability breakdown (optional, collapsible)
                          if (_result!.probabilities != null) ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            const Text(
                              'Probability Distribution:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._result!.probabilities!.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key.toUpperCase(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: LinearProgressIndicator(
                                        value: entry.value,
                                        backgroundColor: Colors.grey[200],
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          entry.key == 'positive'
                                              ? Colors.green
                                              : entry.key == 'negative'
                                                  ? Colors.red
                                                  : Colors.orange,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        '${(entry.value * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(fontSize: 12),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              // Empty state message
              if (_result == null && _errorMessage == null && !_isLoading)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.sentiment_neutral,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Enter text above and click "Analyze Sentiment" to get started',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

