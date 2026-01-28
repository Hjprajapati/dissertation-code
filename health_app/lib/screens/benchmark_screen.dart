import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/sentiment_service.dart';
import '../models/sentiment_result.dart';

/// Benchmark screen for performance testing
class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  final ModelService _modelService = ModelService();
  SentimentService? _sentimentService;
  bool _isRunning = false;
  int _progress = 0;
  int _totalTests = 50;
  List<BenchmarkResult> _results = [];
  BenchmarkStatistics? _statistics;
  ModelType _selectedModelType = ModelType.tiny;

  // Sample texts for benchmarking
  final List<String> _sampleTexts = [
    'I love this product! It works perfectly.',
    'This is terrible. I hate it.',
    'The weather is okay today.',
    'Amazing experience, highly recommended!',
    'Not bad, but could be better.',
    'Absolutely fantastic service!',
    'Very disappointed with the quality.',
    'It is what it is, nothing special.',
    'Best purchase I have ever made!',
    'Worst product ever, do not buy.',
    'Pretty good overall, satisfied.',
    'Excellent quality and fast delivery.',
    'Poor customer service, very slow.',
    'Average product, meets expectations.',
    'Outstanding performance and value!',
    'Completely useless, waste of money.',
    'Good value for the price.',
    'Perfect for my needs, love it!',
    'Not worth the money at all.',
    'Decent product, nothing extraordinary.',
    'Superb quality, exceeded expectations!',
    'Terrible experience, would not recommend.',
    'Fair price, acceptable quality.',
    'Incredible features, very impressed!',
    'Below average, needs improvement.',
    'Great product, very happy with it.',
    'Awful quality, broke immediately.',
    'Satisfactory, does the job.',
    'Exceptional service, five stars!',
    'Very poor quality, avoid this.',
    'Nice design, works as expected.',
    'Brilliant solution to my problem!',
    'Disappointing results, not as advertised.',
    'Okay product, nothing special.',
    'Perfect fit, exactly what I needed!',
    'Waste of time and money.',
    'Good build quality, reliable.',
    'Outstanding customer support!',
    'Mediocre at best, overpriced.',
    'Excellent value, highly satisfied!',
    'Poor design, uncomfortable to use.',
    'Solid product, would buy again.',
    'Amazing features, love everything about it!',
    'Not good, many issues.',
    'Average performance, acceptable.',
    'Top quality, best in class!',
    'Very bad experience, regret buying.',
    'Nice and functional, good purchase.',
    'Exceptional quality, worth every penny!',
    'Subpar product, needs major improvements.',
  ];

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  /// Initialize the sentiment service
  Future<void> _initializeService({ModelType? modelType}) async {
    final targetModelType = modelType ?? _selectedModelType;
    
    // Initialize or switch to the selected model
    if (!_modelService.isInitialized || _modelService.currentModelType != targetModelType) {
      await _modelService.initialize(modelType: targetModelType);
    }
    
    if (_modelService.isInitialized) {
      setState(() {
        _sentimentService = SentimentService(_modelService);
        _selectedModelType = targetModelType;
      });
    }
  }

  /// Handle model type change
  Future<void> _onModelTypeChanged(ModelType? newType) async {
    if (newType == null || newType == _selectedModelType) {
      return;
    }
    
    if (_isRunning) {
      // Don't allow model switching while benchmark is running
      return;
    }
    
    setState(() {
      _results = [];
      _statistics = null;
    });
    
    await _initializeService(modelType: newType);
  }

  /// Run benchmark tests
  Future<void> _runBenchmark() async {
    // Ensure service is initialized with the selected model
    if (_sentimentService == null || _modelService.currentModelType != _selectedModelType) {
      await _initializeService(modelType: _selectedModelType);
      if (_sentimentService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model not initialized. Please try again.')),
        );
        return;
      }
    }

    setState(() {
      _isRunning = true;
      _progress = 0;
      _results = [];
      _statistics = null;
    });

    final List<BenchmarkResult> results = [];

    for (int i = 0; i < _totalTests; i++) {
      // Use sample texts in rotation
      final text = _sampleTexts[i % _sampleTexts.length];
      
      try {
        final startTime = DateTime.now();
        final result = _sentimentService!.analyzeSentiment(text);
        final endTime = DateTime.now();
        final totalTime = endTime.difference(startTime).inMilliseconds;

        results.add(BenchmarkResult(
          text: text,
          latency: result.latency,
          label: result.label,
          confidence: result.confidence,
        ));
      } catch (e) {
        debugPrint('Error in benchmark test $i: $e');
      }

      setState(() {
        _progress = i + 1;
        _results = results;
      });

      // Small delay to avoid overwhelming the system
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // Calculate statistics
    final statistics = _calculateStatistics(results);

    setState(() {
      _isRunning = false;
      _statistics = statistics;
    });
  }

  /// Calculate benchmark statistics
  BenchmarkStatistics _calculateStatistics(List<BenchmarkResult> results) {
    if (results.isEmpty) {
      return BenchmarkStatistics(
        mean: 0,
        median: 0,
        p90: 0,
        p99: 0,
        min: 0,
        max: 0,
        totalTests: 0,
      );
    }

    // Extract latencies and sort
    final latencies = <int>[];
    for (int i = 0; i < results.length; i++) {
      latencies.add(results[i].latency);
    }
    latencies.sort();

    // Calculate mean
    int sum = 0;
    for (int i = 0; i < latencies.length; i++) {
      sum += latencies[i];
    }
    final mean = sum / latencies.length;

    // Calculate median (p50)
    final median = latencies.length % 2 == 0
        ? (latencies[latencies.length ~/ 2 - 1] + latencies[latencies.length ~/ 2]) / 2
        : latencies[latencies.length ~/ 2].toDouble();

    // Calculate percentiles
    final p90Index = (latencies.length * 0.9).ceil() - 1;
    final p90 = latencies[p90Index < 0 ? 0 : p90Index].toDouble();

    final p99Index = (latencies.length * 0.99).ceil() - 1;
    final p99 = latencies[p99Index < 0 ? 0 : p99Index].toDouble();

    return BenchmarkStatistics(
      mean: mean,
      median: median,
      p90: p90,
      p99: p99,
      min: latencies[0].toDouble(),
      max: latencies[latencies.length - 1].toDouble(),
      totalTests: results.length,
    );
  }

  /// Generate CSV content from results
  String _generateCSV() {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('Text,Label,Confidence,Latency(ms)');
    
    // Data rows
    for (int i = 0; i < _results.length; i++) {
      final result = _results[i];
      // Escape quotes in text and wrap in quotes
      final escapedText = result.text.replaceAll('"', '""');
      buffer.writeln('"$escapedText","${result.label}",${result.confidence},${result.latency}');
    }
    
    // Statistics section
    if (_statistics != null) {
      buffer.writeln('');
      buffer.writeln('Statistics,Value');
      buffer.writeln('Total Tests,${_statistics!.totalTests}');
      buffer.writeln('Mean Latency (ms),${_statistics!.mean.toStringAsFixed(2)}');
      buffer.writeln('Median Latency (ms),${_statistics!.median.toStringAsFixed(2)}');
      buffer.writeln('P90 Latency (ms),${_statistics!.p90.toStringAsFixed(2)}');
      buffer.writeln('P99 Latency (ms),${_statistics!.p99.toStringAsFixed(2)}');
      buffer.writeln('Min Latency (ms),${_statistics!.min.toStringAsFixed(2)}');
      buffer.writeln('Max Latency (ms),${_statistics!.max.toStringAsFixed(2)}');
    }
    
    return buffer.toString();
  }

  /// Copy CSV to clipboard
  Future<void> _copyCSVToClipboard() async {
    final csv = _generateCSV();
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV data copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Benchmark'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Model selector card
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
                      onChanged: _isRunning ? null : _onModelTypeChanged,
                    ),
                    if (_modelService.isInitialized && _modelService.currentModelType == _selectedModelType) ...[
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

            // Info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Benchmark Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('This benchmark will run $_totalTests inference tests with sample texts.'),
                    const SizedBox(height: 8),
                    Text('Statistics will be calculated: mean, median, p90, p99, min, max.'),
                    const SizedBox(height: 8),
                    Text(
                      'Model: ${_modelService.isInitialized ? _modelService.currentModelName : "Not loaded"}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Run button
            ElevatedButton(
              onPressed: _isRunning ? null : _runBenchmark,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isRunning
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text('Running... ($_progress/$_totalTests)'),
                      ],
                    )
                  : const Text('Run Benchmark'),
            ),

            if (_isRunning) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress / _totalTests,
              ),
            ],

            // Statistics
            if (_statistics != null) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Statistics',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: _copyCSVToClipboard,
                            tooltip: 'Copy CSV to clipboard',
                          ),
                        ],
                      ),
                      const Divider(),
                      _buildStatRow('Total Tests', '${_statistics!.totalTests}'),
                      _buildStatRow('Mean Latency', '${_statistics!.mean.toStringAsFixed(2)} ms'),
                      _buildStatRow('Median (P50)', '${_statistics!.median.toStringAsFixed(2)} ms'),
                      _buildStatRow('P90 Latency', '${_statistics!.p90.toStringAsFixed(2)} ms'),
                      _buildStatRow('P99 Latency', '${_statistics!.p99.toStringAsFixed(2)} ms'),
                      _buildStatRow('Min Latency', '${_statistics!.min.toStringAsFixed(2)} ms'),
                      _buildStatRow('Max Latency', '${_statistics!.max.toStringAsFixed(2)} ms'),
                    ],
                  ),
                ),
              ),
            ],

            // Results table
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Text')),
                      DataColumn(label: Text('Label')),
                      DataColumn(label: Text('Confidence')),
                      DataColumn(label: Text('Latency (ms)')),
                    ],
                    rows: _results.take(20).map((result) {
                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 200,
                              child: Text(
                                result.text.length > 50
                                    ? '${result.text.substring(0, 50)}...'
                                    : result.text,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(result.label)),
                          DataCell(Text('${(result.confidence * 100).toStringAsFixed(1)}%')),
                          DataCell(Text('${result.latency}')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (_results.length > 20)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Showing first 20 of ${_results.length} results',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Benchmark result data class
class BenchmarkResult {
  final String text;
  final int latency;
  final String label;
  final double confidence;

  BenchmarkResult({
    required this.text,
    required this.latency,
    required this.label,
    required this.confidence,
  });
}

/// Benchmark statistics data class
class BenchmarkStatistics {
  final double mean;
  final double median;
  final double p90;
  final double p99;
  final double min;
  final double max;
  final int totalTests;

  BenchmarkStatistics({
    required this.mean,
    required this.median,
    required this.p90,
    required this.p99,
    required this.min,
    required this.max,
    required this.totalTests,
  });
}

