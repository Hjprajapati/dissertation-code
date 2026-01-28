# Flutter Sentiment Analysis App

A Flutter mobile application that performs on-device sentiment analysis using a BERT-based TensorFlow Lite model. The app analyzes text input and classifies sentiment as positive, neutral, or negative with confidence scores and performance metrics.

## Features

- **On-Device Inference**: Runs entirely on-device using TensorFlow Lite - no internet connection required
- **Real-Time Analysis**: Fast inference with latency typically under 100ms
- **Performance Metrics**: Displays inference latency and confidence scores
- **Performance Benchmarking**: Built-in benchmark tool to test model performance with statistics (mean, median, p90, p99, min, max)
- **Modern UI**: Material Design 3 interface with color-coded sentiment results
- **CSV Export**: Export benchmark results to CSV format

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── sentiment_result.dart    # Data model for sentiment results
├── screens/
│   ├── home_screen.dart         # Main UI for sentiment analysis
│   └── benchmark_screen.dart    # Performance benchmarking screen
├── services/
│   ├── model_service.dart       # TFLite model loading and management
│   ├── tokenizer_service.dart   # WordPiece tokenization (BERT-style)
│   └── sentiment_service.dart   # Sentiment analysis pipeline
└── utils/
    └── input_preprocessor.dart  # Text normalization and validation

assets/
├── models/
│   ├── student_fp32.tflite      # Quantized TensorFlow Lite model (INT32 input, FLOAT32 output)
│   └── label_map.json           # Sentiment labels mapping
└── tokenizer/
    └── vocab.txt                # Vocabulary file for tokenization
```

## Model Specifications

- **Model**: Quantized BERT-based student model (INT32 input, INT8 internal, FLOAT32 output)
- **Input Shape**: `[1, 128]` for both `input_ids` and `attention_mask` (int32)
- **Output**: 3-class logits (float32, no conversion needed)
- **Labels**: `["negative", "neutral", "positive"]`
- **Max Sequence Length**: 128 tokens
- **Target Latency**: <100ms on typical devices

### Expected Performance

- **Mid/High-end devices**: 20-60ms per inference
- **Low-end devices**: 80-120ms per inference

## Setup Instructions

### Prerequisites

- Flutter SDK ^3.9.2
- Dart SDK ^3.9.2
- Android Studio / Xcode (for mobile development)
- TensorFlow Lite model files (already included in `assets/`)

### Installation

1. **Clone the repository** (if applicable) or navigate to the project directory

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify assets are configured**:
   - Ensure `assets/models/student_fp32.tflite` exists
   - Ensure `assets/models/label_map.json` exists
   - Ensure `assets/tokenizer/vocab.txt` exists

4. **Run the app**:
   ```bash
   flutter run
   ```

### Dependencies

- `tflite_flutter: ^0.12.1` - TensorFlow Lite for Flutter
- `flutter` - Flutter SDK
- `cupertino_icons` - iOS-style icons

## How to Use

### Basic Sentiment Analysis

1. Launch the app
2. Wait for the model to load (first launch only)
3. Enter text in the input field
4. Tap "Analyze Sentiment"
5. View results:
   - Sentiment label (positive/neutral/negative)
   - Confidence score (as percentage)
   - Inference latency (in milliseconds)
   - Probability distribution for all classes

### Performance Benchmarking

1. Tap the speed icon (⚡) in the app bar
2. Tap "Run Benchmark"
3. Wait for 50 inference tests to complete
4. View statistics:
   - Mean latency
   - Median (P50) latency
   - P90 and P99 percentiles
   - Min/Max latency
5. Copy CSV data to clipboard for export

## Architecture

### Model Service (Singleton)

The `ModelService` is implemented as a singleton to ensure:
- Model loads only once at app startup
- Vocabulary and labels are cached in memory
- Efficient resource usage

### Tokenization

Uses WordPiece tokenization (BERT-style):
- Converts text to lowercase
- Splits by spaces
- Handles subword tokenization with `##` prefix
- Pads/truncates to exactly 128 tokens
- Generates attention mask

### Inference Pipeline

1. **Input Validation**: Normalize and validate input text
2. **Tokenization**: Convert text to token IDs
3. **Tensor Preparation**: Format inputs as `[1, 128]` tensors (INT32)
4. **Model Inference**: Run TFLite interpreter
5. **Post-processing**: Extract FLOAT32 logits, apply softmax
6. **Result Generation**: Extract label, confidence, and probabilities

## Testing

Run unit tests:
```bash
flutter test
```

Test files:
- `test/services/tokenizer_service_test.dart` - Tokenizer tests
- `test/services/sentiment_service_test.dart` - Sentiment analysis tests

## Performance Optimization

- **Singleton Pattern**: Model service ensures single instance
- **Memory Caching**: Vocabulary and labels cached in memory
- **Efficient Tokenization**: Optimized WordPiece implementation
- **Multi-threading**: Model interpreter uses 4 threads

## Known Issues / Limitations

1. **Model Size**: The model file is 14.4 MB, which may affect initial load time
2. **Sequence Length**: Input text is truncated to 128 tokens maximum
3. **Language Support**: Optimized for English text
4. **Device Compatibility**: Performance varies by device capabilities

## Future Improvements

- [ ] Support for batch inference
- [ ] Additional language models
- [ ] Model quantization optimization
- [ ] Cloud sync for benchmark results
- [ ] History of previous analyses
- [ ] Export results to various formats
- [ ] Custom model loading
- [ ] Real-time streaming analysis

## Troubleshooting

### Model fails to load
- Ensure all asset files are present in `assets/` directory
- Check `pubspec.yaml` has correct asset paths
- Run `flutter clean` and `flutter pub get`

### Slow inference
- Check device capabilities
- Ensure model is loaded (check initialization status)
- Try running benchmark to see actual performance

### App crashes on startup
- Verify Flutter SDK version matches requirements
- Check that `tflite_flutter` dependency is properly installed
- Review device logs for specific error messages

## License

This project is for assessment/educational purposes.

## Acknowledgments

- TensorFlow Lite team for on-device ML support
- Flutter team for the excellent framework
- BERT model architecture for sentiment analysis
