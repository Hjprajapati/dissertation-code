import 'model_service.dart';

/// Service for tokenizing text input using WordPiece tokenization (BERT style)
class TokenizerService {
  final ModelService _modelService;
  
  // Maximum sequence length (128 tokens)
  static const int maxLength = 128;

  TokenizerService(this._modelService);

  /// Tokenize text input and return input_ids and attention_mask
  /// Returns a map with input_ids and attention_mask as List of int
  Map<String, List<int>> tokenize(String text) {
    if (!_modelService.isInitialized) {
      throw StateError('ModelService not initialized. Call initialize() first.');
    }

    // Convert text to lowercase
    final lowerText = text.toLowerCase();
    
    // Split by spaces to get words
    final words = lowerText.split(' ');
    
    // Get special token IDs
    final clsTokenId = _modelService.getClsTokenId();
    final sepTokenId = _modelService.getSepTokenId();
    final padTokenId = _modelService.getPadTokenId();
    final unkTokenId = _modelService.getUnkTokenId();
    
    // Start with [CLS] token
    final List<int> tokenIds = [clsTokenId];
    
    // Tokenize each word
    for (int i = 0; i < words.length; i++) {
      final word = words[i].trim();
      if (word.isEmpty) {
        continue;
      }
      
      // Try to find the word in vocabulary
      final wordTokenId = _modelService.getTokenId(word);
      
      // If word is found and not [UNK], add it
      if (wordTokenId != unkTokenId || word == '[UNK]') {
        tokenIds.add(wordTokenId);
      } else {
        // Word not found, try WordPiece subword tokenization
        // For simplicity, we'll try the whole word first, then split if needed
        final subwordIds = _wordPieceTokenize(word);
        tokenIds.addAll(subwordIds);
      }
    }
    
    // Add [SEP] token at the end
    tokenIds.add(sepTokenId);
    
    // Pad or truncate to maxLength (128)
    final List<int> inputIds = _padOrTruncate(tokenIds, maxLength, padTokenId);
    
    // Build attention mask (1 for real tokens, 0 for padding)
    final List<int> attentionMask = _buildAttentionMask(inputIds, padTokenId);
    
    return {
      'input_ids': inputIds,
      'attention_mask': attentionMask,
    };
  }

  /// WordPiece tokenization: try to find word, if not found, split into subwords
  List<int> _wordPieceTokenize(String word) {
    final unkTokenId = _modelService.getUnkTokenId();
    
    // First, try the whole word
    if (_modelService.vocab!.containsKey(word)) {
      return [_modelService.vocab![word]!];
    }
    
    // If word not found, try to split it
    // Start from the beginning and find the longest matching subword
    final List<int> subwordIds = [];
    int start = 0;
    
    while (start < word.length) {
      bool found = false;
      int end = word.length;
      
      // Try to find the longest matching subword from start position
      while (end > start) {
        String subword = word.substring(start, end);
        
        // Try with ## prefix (BERT WordPiece style for subwords)
        String subwordWithPrefix = '##$subword';
        
        if (_modelService.vocab!.containsKey(subword)) {
          subwordIds.add(_modelService.vocab![subword]!);
          found = true;
          start = end;
          break;
        } else if (start > 0 && _modelService.vocab!.containsKey(subwordWithPrefix)) {
          subwordIds.add(_modelService.vocab![subwordWithPrefix]!);
          found = true;
          start = end;
          break;
        }
        
        end--;
      }
      
      // If no subword found, use [UNK]
      if (!found) {
        subwordIds.add(unkTokenId);
        start++;
      }
    }
    
    // If no subwords were found, return [UNK]
    if (subwordIds.isEmpty) {
      return [unkTokenId];
    }
    
    return subwordIds;
  }

  /// Pad or truncate token sequence to specified length
  List<int> _padOrTruncate(List<int> tokens, int targetLength, int padTokenId) {
    final List<int> result = [];
    
    if (tokens.length >= targetLength) {
      // Truncate to target length
      for (int i = 0; i < targetLength; i++) {
        result.add(tokens[i]);
      }
    } else {
      // Copy all tokens
      for (int i = 0; i < tokens.length; i++) {
        result.add(tokens[i]);
      }
      
      // Pad with [PAD] tokens
      int paddingNeeded = targetLength - tokens.length;
      for (int i = 0; i < paddingNeeded; i++) {
        result.add(padTokenId);
      }
    }
    
    return result;
  }

  /// Build attention mask: 1 for real tokens, 0 for padding
  List<int> _buildAttentionMask(List<int> inputIds, int padTokenId) {
    final List<int> attentionMask = [];
    
    for (int i = 0; i < inputIds.length; i++) {
      if (inputIds[i] == padTokenId) {
        attentionMask.add(0);
      } else {
        attentionMask.add(1);
      }
    }
    
    return attentionMask;
  }
}

