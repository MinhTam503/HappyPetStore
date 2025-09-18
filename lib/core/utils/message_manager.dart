class MessageManager {
  static final MessageManager _instance = MessageManager._internal();
  factory MessageManager() => _instance;
  MessageManager._internal();

  String? _lastMessage;
  DateTime? _lastMessageTime;
  static const Duration _messageThreshold = Duration(milliseconds: 1000);

  bool shouldShowMessage(String message) {
    final now = DateTime.now();
    
    // If it's the same message and within the threshold time, don't show
    if (_lastMessage == message && 
        _lastMessageTime != null && 
        now.difference(_lastMessageTime!) < _messageThreshold) {
      return false;
    }
    
    // Update the last message and time
    _lastMessage = message;
    _lastMessageTime = now;
    return true;
  }

  void clearMessage() {
    _lastMessage = null;
    _lastMessageTime = null;
  }
}