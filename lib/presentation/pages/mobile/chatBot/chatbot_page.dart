import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:pet_shop/core/service_locator.dart';
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_bloc.dart';
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_event.dart';
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_state.dart';
import 'package:pet_shop/domain/entities/chatbot_entity.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ChatBotPage extends StatefulWidget {
  final String userId;

  const ChatBotPage({
    super.key,
    required this.userId,
  });

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUserScrolling = false;
  bool _autoScrollEnabled = true;
  
  // Speech recognition
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isInitializingListening = false; // Loading state while waiting for mic to start
  bool _speechAvailable = false;
  String _currentLocale = 'vi_VN'; // Default Vietnamese
  
  // Animation for listening indicator
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Listen to scroll events to detect user manual scrolling
    _scrollController.addListener(_scrollListener);
    
    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    _speech = stt.SpeechToText();
    
    try {
      debugPrint('🎤 [Voice] Starting speech initialization...');
      
      // Platform-specific permission handling
      if (Platform.isIOS) {
        // iOS: Let speech_to_text handle all permissions (mic + speech recognition)
        // This is because permission_handler doesn't properly support iOS Speech Recognition
        debugPrint('🎤 [Voice] iOS detected - letting SpeechToText handle permissions...');
        
        _speechAvailable = await _speech.initialize(
          onError: (error) {
            debugPrint('🎤 [Voice] Speech error: ${error.errorMsg}');
            if (error.errorMsg.contains('not_allowed') || error.errorMsg.contains('denied')) {
              if (mounted) {
                _showPermissionDeniedDialog();
              }
            }
            setState(() => _isListening = false);
          },
          onStatus: (status) {
            debugPrint('🎤 [Voice] Speech status: $status');
            if (status == 'listening') {
              // Stop loading indicator when microphone starts listening
              setState(() => _isInitializingListening = false);
            }
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
              _pulseController.stop();
              _pulseController.reset();
            }
          },
        );
      } else {
        // Android: Check microphone permission first
        debugPrint('🎤 [Voice] Android detected - checking microphone permission...');
        
        final micStatus = await Permission.microphone.status;
        debugPrint('🎤 [Voice] Current microphone permission: $micStatus');
        
        if (micStatus.isPermanentlyDenied) {
          debugPrint('🎤 [Voice] ⚠️ Microphone permission permanently denied.');
          if (mounted) {
            _showPermissionDeniedDialog();
          }
          _speechAvailable = false;
          setState(() {});
          return;
        }
        
        PermissionStatus finalMicStatus = micStatus;
        if (!micStatus.isGranted) {
          debugPrint('🎤 [Voice] Requesting microphone permission...');
          finalMicStatus = await Permission.microphone.request();
          debugPrint('🎤 [Voice] Microphone permission status: $finalMicStatus');
        }
        
        if (!finalMicStatus.isGranted) {
          debugPrint('🎤 [Voice] ⚠️ Microphone permission denied by user.');
          _speechAvailable = false;
          setState(() {});
          return;
        }
        
        // Initialize speech recognition
        debugPrint('🎤 [Voice] Microphone permission granted, initializing SpeechToText...');
        _speechAvailable = await _speech.initialize(
          onError: (error) {
            debugPrint('🎤 [Voice] Speech error: ${error.errorMsg}');
            setState(() => _isListening = false);
          },
          onStatus: (status) {
            debugPrint('🎤 [Voice] Speech status: $status');
            if (status == 'listening') {
              // Stop loading indicator when microphone starts listening
              setState(() => _isInitializingListening = false);
            }
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
              _pulseController.stop();
              _pulseController.reset();
            }
          },
        );
      }
      
      // Common code after initialization
      if (_speechAvailable) {
        debugPrint('🎤 [Voice] Both permissions granted, initializing SpeechToText...');
        
        // Initialize speech recognition
        _speechAvailable = await _speech.initialize(
          onError: (error) {
            debugPrint('🎤 [Voice] Speech error: ${error.errorMsg}');
            setState(() => _isListening = false);
          },
          onStatus: (status) {
            debugPrint('🎤 [Voice] Speech status: $status');
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          },
        );
        
        debugPrint('🎤 [Voice] Speech available: $_speechAvailable');
        
        // Get available locales and set based on app locale
        if (_speechAvailable) {
          final locales = await _speech.locales();
          debugPrint('🎤 [Voice] Available locales: ${locales.length}');
          if (locales.isNotEmpty) {
            debugPrint('🎤 [Voice] First few locales: ${locales.take(5).map((l) => l.localeId).join(", ")}');
          }
          
          final currentAppLocale = Localizations.localeOf(context).toString();
          debugPrint('🎤 [Voice] Current app locale: $currentAppLocale');
          
          // Match app locale with speech locale
          if (currentAppLocale.startsWith('vi')) {
            _currentLocale = locales.firstWhere(
              (l) => l.localeId.startsWith('vi'),
              orElse: () => locales.isNotEmpty ? locales.first : stt.LocaleName('vi_VN', 'Vietnamese'),
            ).localeId;
          } else {
            _currentLocale = locales.firstWhere(
              (l) => l.localeId.startsWith('en'),
              orElse: () => locales.isNotEmpty ? locales.first : stt.LocaleName('en_US', 'English'),
            ).localeId;
          }
          
          debugPrint('🎤 [Voice] Selected locale: $_currentLocale');
        } else {
          debugPrint('🎤 [Voice] ❌ Speech recognition not available after initialization');
        }
        
        setState(() {});
      } else {
        debugPrint('🎤 [Voice] ❌ Speech recognition initialization failed');
        _speechAvailable = false;
        setState(() {});
      }
    } catch (e, stackTrace) {
      debugPrint('🎤 [Voice] ❌ Error initializing speech: $e');
      debugPrint('🎤 [Voice] Stack trace: $stackTrace');
      _speechAvailable = false;
      setState(() {});
    }
    
    debugPrint('🎤 [Voice] Initialization complete. Speech available: $_speechAvailable');
  }

  void _startListening() async {
    if (!_speechAvailable) {
      final l10n = AppLocalizations.of(context)!;
      _showSnack(l10n.speechNotAvailable);
      debugPrint('🎤 [Voice] Cannot start listening: speech not available');
      return;
    }

    // Check permissions before starting
    // On iOS, speech_to_text handles permissions internally
    // On Android, we check microphone permission
    if (Platform.isAndroid) {
      final micStatus = await Permission.microphone.status;
      debugPrint('🎤 [Voice] Checking microphone permission before listening: $micStatus');
      
      if (!micStatus.isGranted) {
        final l10n = AppLocalizations.of(context)!;
        _showSnack(l10n.micPermissionDenied);
        debugPrint('🎤 [Voice] Microphone permission not granted, cannot start');
        return;
      }
    }

    setState(() => _isListening = true);
    _pulseController.repeat(); // Start pulse animation
    
    setState(() => _isInitializingListening = true);
    debugPrint('🎤 [Voice] Starting to listen with locale: $_currentLocale');

    try {
      await _speech.listen(
        onResult: (result) {
          // Update UI with every partial result for real-time feedback
          debugPrint('🎤 [Voice] Got result: ${result.recognizedWords} (final: ${result.finalResult})');
          setState(() {
            _messageController.text = result.recognizedWords;
            // Move cursor to end
            _messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: _messageController.text.length),
            );
          });
        },
        localeId: _currentLocale,
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true, // Enable partial results for real-time update
      );
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      final l10n = AppLocalizations.of(context)!;
      _showSnack(l10n.speechError);
      setState(() {
        _isListening = false;
        _isInitializingListening = false;
      });
      _pulseController.stop();
    }
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _isInitializingListening = false;
    });
    _pulseController.stop();
    _pulseController.reset();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      // Check if user is scrolling manually
      final isAtBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100; // 100px threshold

      setState(() {
        // Enable auto scroll when user is near bottom
        _autoScrollEnabled = isAtBottom;

        // Detect if user is scrolling up
        if (!isAtBottom) {
          _isUserScrolling = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    // Only auto scroll if enabled and user is not manually scrolling
    if (_scrollController.hasClients &&
        _autoScrollEnabled &&
        !_isUserScrolling) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients && _autoScrollEnabled) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          serviceLocator<ChatBotBloc>()..add(LoadChatBotHistory(widget.userId)),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            centerTitle: true,
            title: const Text('Trợ lý ảo'),
            backgroundColor: const Color(0xff08A045),
            foregroundColor: Colors.white,
            elevation: 2,
            actions: [
              // // Debug button to check speech status
              // IconButton(
              //   icon: Icon(_speechAvailable ? Icons.mic : Icons.mic_off),
              //   color: _speechAvailable ? Colors.white : Colors.red,
              //   onPressed: () async {
              //     // Get current permission status (platform-specific)
              //     final micStatus = await Permission.microphone.status;
              //     final isIOS = Platform.isIOS;
                  
              //     if (!mounted) return;
                  
              //     showDialog(
              //       context: context,
              //       builder: (context) => AlertDialog(
              //         title: Row(
              //           children: [
              //             Icon(
              //               _speechAvailable ? Icons.check_circle : Icons.error,
              //               color: _speechAvailable ? Colors.green : Colors.red,
              //             ),
              //             const SizedBox(width: 8),
              //             const Text('Speech Status'),
              //           ],
              //         ),
              //         content: Column(
              //           mainAxisSize: MainAxisSize.min,
              //           crossAxisAlignment: CrossAxisAlignment.start,
              //           children: [
              //             _buildStatusRow('Speech Available', _speechAvailable),
              //             _buildStatusRow('Is Listening', _isListening),
              //             const Divider(height: 24),
              //             Text(
              //               'Permissions:',
              //               style: TextStyle(
              //                 fontWeight: FontWeight.bold,
              //                 color: Colors.grey[700],
              //               ),
              //             ),
              //             const SizedBox(height: 8),
              //             _buildPermissionRow('🎤 Microphone', micStatus),
              //             if (!isIOS) 
              //               const Padding(
              //                 padding: EdgeInsets.only(top: 4),
              //                 child: Text(
              //                   'Android: Only microphone permission needed',
              //                   style: TextStyle(fontSize: 11, color: Colors.grey),
              //                 ),
              //               ),
              //             if (isIOS)
              //               const Padding(
              //                 padding: EdgeInsets.only(top: 4),
              //                 child: Text(
              //                   'iOS: Speech permission handled by SpeechToText',
              //                   style: TextStyle(fontSize: 11, color: Colors.grey),
              //                 ),
              //               ),
              //             const Divider(height: 24),
              //             Text(
              //               'Platform: ${isIOS ? "iOS" : "Android"}',
              //               style: const TextStyle(fontSize: 13),
              //             ),
              //             Text(
              //               'Locale: $_currentLocale',
              //               style: const TextStyle(fontSize: 13),
              //             ),
              //             const SizedBox(height: 16),
              //             if (micStatus.isPermanentlyDenied)
              //               Container(
              //                 padding: const EdgeInsets.all(8),
              //                 decoration: BoxDecoration(
              //                   color: Colors.red.withOpacity(0.1),
              //                   borderRadius: BorderRadius.circular(8),
              //                 ),
              //                 child: Row(
              //                   children: [
              //                     Icon(Icons.warning, color: Colors.red[700], size: 20),
              //                     const SizedBox(width: 8),
              //                     const Expanded(
              //                       child: Text(
              //                         'Cần mở Settings để bật quyền',
              //                         style: TextStyle(fontSize: 12),
              //                       ),
              //                     ),
              //                   ],
              //                 ),
              //               ),
              //           ],
              //         ),
              //         actions: [
              //           if (micStatus.isPermanentlyDenied)
              //             TextButton.icon(
              //               onPressed: () async {
              //                 Navigator.pop(context);
              //                 await openAppSettings();
              //               },
              //               icon: const Icon(Icons.settings),
              //               label: const Text('Open Settings'),
              //             ),
              //           TextButton(
              //             onPressed: () async {
              //               Navigator.pop(context);
              //               await _initializeSpeech();
              //             },
              //             child: const Text('Re-initialize'),
              //           ),
              //           TextButton(
              //             onPressed: () => Navigator.pop(context),
              //             child: const Text('Close'),
              //           ),
              //         ],
              //       ),
              //     );
              //   },
              // ),
              BlocBuilder<ChatBotBloc, ChatBotState>(
                builder: (blocContext, state) {
                  return IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: const Text('Xóa lịch sử chat'),
                            content: const Text(
                                'Bạn có chắc chắn muốn xóa toàn bộ lịch sử trò chuyện không?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('Hủy'),
                              ),
                              TextButton(
                                onPressed: () {
                                  blocContext
                                      .read<ChatBotBloc>()
                                      .add(ClearChatBotHistory(widget.userId));
                                  Navigator.of(dialogContext).pop();
                                },
                                child: const Text('Xóa'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    BlocConsumer<ChatBotBloc, ChatBotState>(
                      listener: (context, state) {
                        if (state is ChatBotLoaded ||
                            state is ChatBotMessageSent) {
                          // Only auto scroll for new messages when appropriate
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            // Reset user scrolling flag when new message arrives
                            _isUserScrolling = false;
                            _scrollToBottom();
                          });
                        }
                        if (state is ChatBotError) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(state.message),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      builder: (context, state) {
                        if (state is ChatBotLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        List<ChatBotMessage> messages = [];
                        bool isTyping = false;

                        if (state is ChatBotLoaded) {
                          messages = state.messages;
                          isTyping = state.isTyping;
                        } else if (state is ChatBotError) {
                          messages = state.messages;
                        }

                        if (messages.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.pets,
                                  size: 64,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Xin chào! Tôi là trợ lý thú cưng của bạn.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Hãy hỏi tôi bất cứ điều gì về thú cưng!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          reverse: false, // Normal scroll direction
                          itemCount: messages.length + (isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == messages.length && isTyping) {
                              return _buildTypingIndicator();
                            }

                            final message = messages[index];
                            return _buildMessageBubble(message);
                          },
                        );
                      },
                    ),
                    // Floating Action Button to scroll to bottom
                    if (!_autoScrollEnabled)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton(
                          mini: true,
                          backgroundColor: Theme.of(context).primaryColor,
                          onPressed: () {
                            setState(() {
                              _isUserScrolling = false;
                              _autoScrollEnabled = true;
                            });
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatBotMessage message) {
    // Check if message contains map coordinates (for bot messages only)
    final hasMapCoordinates = !message.isUser && _parseCoordinatesFromText(message.text) != null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: const Icon(Icons.pets, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: _ExpandableMessageText(
                  // If has map coordinates, replace text with friendly message
                  text: hasMapCoordinates ? "Đây là vị trí của cửa hàng" : message.text,
                  isUser: message.isUser,
                ),
              ),
              if (message.isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[400],
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 18),
                ),
              ],
            ],
          ),
          // Display Flutter Map mini preview if message contains coordinates
          if (!message.isUser) ...[
            if (_maybeBuildMapPreview(message.text) != null)
              _maybeBuildMapPreview(message.text)!,
          ],
          // Display pets if available
          if (!message.isUser &&
              message.pets != null &&
              message.pets!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPetsDisplay(message.pets!),
          ],
          // Display quick replies if available
          if (!message.isUser &&
              message.quickReplies != null &&
              message.quickReplies!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildQuickReplies(message.quickReplies!),
          ],
          // Display actions if available (e.g., paginateNext)
          if (!message.isUser &&
              message.actions != null &&
              message.actions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildActions(message.actions!),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).primaryColor,
            child: const Icon(Icons.pets, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Đang trả lời...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Voice Input Button
          if (_speechAvailable)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening 
                        ? Colors.red.withOpacity(0.1)
                        : Theme.of(context).primaryColor.withOpacity(0.1),
                    border: Border.all(
                      color: _isListening 
                          ? Colors.red
                          : Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated pulse effect when listening
                      if (_isListening)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 48 * (1 + _pulseAnimation.value * 0.3),
                              height: 48 * (1 + _pulseAnimation.value * 0.3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withOpacity(0.3 * (1 - _pulseAnimation.value)),
                              ),
                            );
                          },
                        ),
                      // Loading indicator while initializing microphone
                      if (_isInitializingListening)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        )
                      else
                        Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening 
                              ? Colors.red
                              : Theme.of(context).primaryColor,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: _isInitializingListening
                    ? 'Đang khởi động micro...'
                    : (_isListening 
                        ? l10n.listening
                        : 'Hỏi về thú cưng...'),
                hintStyle: TextStyle(
                  color: _isInitializingListening 
                      ? Colors.orange
                      : (_isListening ? Colors.red : Colors.grey[600]),
                  fontStyle: (_isListening || _isInitializingListening) ? FontStyle.italic : FontStyle.normal,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                      color: Theme.of(context).primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              enabled: !_isListening && !_isInitializingListening, // Disable typing when listening or initializing
              onSubmitted: (value) {
                final message = _messageController.text.trim();
                if (message.isNotEmpty) {
                  context.read<ChatBotBloc>().add(
                        SendChatBotMessage(
                          userId: widget.userId,
                          message: message,
                        ),
                      );
                  _messageController.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          BlocBuilder<ChatBotBloc, ChatBotState>(
            builder: (blocContext, state) {
              final isLoading = state is ChatBotLoading ||
                  (state is ChatBotLoaded && state.isTyping);

              return CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: IconButton(
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: (isLoading || _isListening || _isInitializingListening)
                      ? null
                      : () {
                          final message = _messageController.text.trim();
                          if (message.isNotEmpty) {
                            blocContext.read<ChatBotBloc>().add(
                                  SendChatBotMessage(
                                    userId: widget.userId,
                                    message: message,
                                  ),
                                );
                            _messageController.clear();
                          }
                        },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPetsDisplay(List<ChatBotPet> pets) {
    // Only schedule scroll if auto scroll is enabled
    if (_autoScrollEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }

    return Container(
      margin: const EdgeInsets.only(left: 40), // Align with bot message
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pets,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Tìm thấy ${pets.length} thú cưng phù hợp',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: pets.length,
              itemBuilder: (context, index) {
                final pet = pets[index];
                return _buildCompactPetCard(pet);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPetCard(ChatBotPet pet) {
    return GestureDetector(
      onTap: () async {
        try {
          // Fetch pet details from Firestore using the pet's ID
          final petDoc = await FirebaseFirestore.instance
              .collection('Pets')
              .doc(pet.id)
              .get();

          if (!mounted) return;

          // Build pet data map - use Firestore data if available, fallback to model data
          Map<String, dynamic> petData;
          
          if (petDoc.exists && petDoc.data() != null) {
            final firestoreData = petDoc.data()!;
            petData = {
              'id': pet.id,
              'name': firestoreData['name'] ?? pet.name,
              'breed': firestoreData['breed'] ?? pet.breed,
              'category': firestoreData['category'] ?? pet.category,
              'age': firestoreData['age']?.toString() ?? pet.age,
              'sex': firestoreData['sex'] ?? pet.sex,
              'weight': firestoreData['weight']?.toString() ?? pet.weight,
              'price': firestoreData['price'] ?? pet.price,
              'imageUrl': firestoreData['imageUrl'] ?? pet.imageUrl,
              'about': firestoreData['about'] ?? pet.about,
              'health_status': firestoreData['health_status'] ?? pet.healthStatus ?? '',
              'vaccination': firestoreData['vaccination'] ?? pet.vaccination ?? '',
              'location': firestoreData['location'] ?? pet.location ?? '',
            };
          } else {
            // Fallback to model data if Firestore fetch fails
            petData = {
              'id': pet.id,
              'name': pet.name,
              'breed': pet.breed,
              'category': pet.category,
              'age': pet.age,
              'sex': pet.sex,
              'weight': pet.weight,
              'price': pet.price,
              'imageUrl': pet.imageUrl,
              'about': pet.about,
              'health_status': pet.healthStatus ?? '',
              'vaccination': pet.vaccination ?? '',
              'location': pet.location ?? '',
            };
          }

          // Navigate to pet detail page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailPet(pet: petData),
            ),
          );
        } catch (e) {
          debugPrint('Error fetching pet details: $e');
          if (mounted) {
            _showSnack('Không thể tải thông tin thú cưng');
          }
        }
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 0,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pet Image with category icon overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  child: pet.imageUrl.isNotEmpty
                      ? Image.network(
                          pet.imageUrl,
                          height: 75,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderImage(pet.category);
                          },
                        )
                      : _buildPlaceholderImage(pet.category),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      _getCategoryIcon(pet.category),
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            // Pet Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pet.breed != "Không rõ"
                              ? pet.breed
                              : pet.about.split(',')[0],
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    // Price with nice formatting
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatPrice(pet.price),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(String category) {
    return Container(
      height: 75,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[100]!,
            Colors.grey[200]!,
          ],
        ),
      ),
      child: Icon(
        _getCategoryIcon(category),
        size: 24,
        color: Colors.grey[400],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'dog':
      case 'dogs':
        return Icons.pets;
      case 'cat':
      case 'cats':
        return Icons.pets;
      case 'fish':
        return Icons.water;
      case 'bird':
      case 'birds':
        return Icons.flutter_dash;
      default:
        return Icons.pets;
    }
  }

  String _formatPrice(num price) {
    if (price >= 1000000) {
      double millions = price / 1000000;
      if (millions == millions.toInt()) {
        return '${millions.toInt()}M';
      } else {
        return '${millions.toStringAsFixed(1)}M';
      }
    } else if (price >= 1000) {
      double thousands = price / 1000;
      if (thousands == thousands.toInt()) {
        return '${thousands.toInt()}K';
      } else {
        return '${thousands.toStringAsFixed(1)}K';
      }
    }
    return price.toString();
  }

  Widget _buildQuickReplies(List<ChatBotQuickReply> quickReplies) {
    return Container(
      margin: const EdgeInsets.only(left: 40), // Align with bot message
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children:
            quickReplies.map((reply) => _buildQuickReplyChip(reply)).toList(),
      ),
    );
  }

  Widget _buildQuickReplyChip(ChatBotQuickReply quickReply) {
    return BlocBuilder<ChatBotBloc, ChatBotState>(
      builder: (blocContext, state) {
        return GestureDetector(
          onTap: () {
            // Send the quick reply as a message
            blocContext.read<ChatBotBloc>().add(
                  SendChatBotMessage(
                    userId: widget.userId,
                    message: quickReply.text,
                  ),
                );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              quickReply.text,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActions(List<ChatBotAction> actions) {
    return Container(
      margin: const EdgeInsets.only(left: 40), // Align with bot message
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: actions.map((action) => _buildActionChip(action)).toList(),
      ),
    );
  }

  Widget _buildActionChip(ChatBotAction action) {
    return BlocBuilder<ChatBotBloc, ChatBotState>(
      builder: (blocContext, state) {
        final label = action.text.isNotEmpty ? action.text : action.type;
        return GestureDetector(
          onTap: () {
            // Send the action label as a follow-up message
            blocContext.read<ChatBotBloc>().add(
                  SendChatBotMessage(
                    userId: widget.userId,
                    message: label,
                  ),
                );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to parse coordinates from Google Maps URLs or plain text
  LatLng? _parseCoordinatesFromText(String text) {
    try {
      // Pattern 1: https://www.google.com/maps/search/?api=1&query=lat,lng
      final queryPattern = RegExp(r'query=(-?\d+\.?\d*),\s*(-?\d+\.?\d*)');
      final queryMatch = queryPattern.firstMatch(text);
      if (queryMatch != null) {
        final lat = double.parse(queryMatch.group(1)!);
        final lng = double.parse(queryMatch.group(2)!);
        return LatLng(lat, lng);
      }

      // Pattern 2: https://www.google.com/maps?q=lat,lng
      final qPattern = RegExp(r'[?&]q=(-?\d+\.?\d*),\s*(-?\d+\.?\d*)');
      final qMatch = qPattern.firstMatch(text);
      if (qMatch != null) {
        final lat = double.parse(qMatch.group(1)!);
        final lng = double.parse(qMatch.group(2)!);
        return LatLng(lat, lng);
      }

      // Pattern 3: Plain text with coordinates "lat, lng"
      final plainPattern = RegExp(r'(-?\d+\.?\d+)\s*,\s*(-?\d+\.?\d+)');
      final plainMatch = plainPattern.firstMatch(text);
      if (plainMatch != null) {
        final lat = double.parse(plainMatch.group(1)!);
        final lng = double.parse(plainMatch.group(2)!);
        return LatLng(lat, lng);
      }
    } catch (e) {
      debugPrint('Error parsing coordinates: $e');
    }
    return null;
  }

  // Helper method to open coordinates in Google Maps app
  Future<void> _openInGoogleMaps(LatLng coordinates) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${coordinates.latitude},${coordinates.longitude}',
    );
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showSnack('Không thể mở Google Maps');
        }
      }
    } catch (e) {
      debugPrint('Error opening Google Maps: $e');
      if (mounted) {
        _showSnack('Lỗi khi mở Google Maps');
      }
    }
  }

  // Helper method to show snackbar messages
  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Helper method to show permission denied dialog
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.mic_off, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Cần quyền truy cập',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Để sử dụng tính năng nhập giọng nói, bạn cần cho phép:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildPermissionItem('🎤 Microphone', 'Ghi âm giọng nói của bạn'),
            const SizedBox(height: 8),
            _buildPermissionItem('🗣️ Speech Recognition', 'Chuyển giọng nói thành văn bản'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Cách bật quyền:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Chạm "Mở Cài đặt"\n'
                    '2. Tìm mục "Microphone"\n'
                    '3. Bật ON\n'
                    '4. Tìm mục "Speech Recognition"\n'
                    '5. Bật ON\n'
                    '6. Quay lại app',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Để sau',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              // Open app settings
              final opened = await openAppSettings();
              if (!opened) {
                _showSnack('Không thể mở cài đặt');
              }
            },
            icon: const Icon(Icons.settings),
            label: const Text('Mở Cài đặt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? Colors.green : Colors.red,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String label, PermissionStatus status) {
    Color color;
    IconData icon;
    String statusText;

    switch (status) {
      case PermissionStatus.granted:
        color = Colors.green;
        icon = Icons.check_circle;
        statusText = 'Granted';
        break;
      case PermissionStatus.denied:
        color = Colors.orange;
        icon = Icons.warning;
        statusText = 'Denied';
        break;
      case PermissionStatus.permanentlyDenied:
        color = Colors.red;
        icon = Icons.block;
        statusText = 'Permanently Denied';
        break;
      case PermissionStatus.restricted:
        color = Colors.grey;
        icon = Icons.lock;
        statusText = 'Restricted';
        break;
      case PermissionStatus.limited:
        color = Colors.blue;
        icon = Icons.info;
        statusText = 'Limited';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        statusText = 'Unknown';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build mini map preview using Flutter Map (OpenStreetMap)
  Widget? _maybeBuildMapPreview(String text) {
    final coordinates = _parseCoordinatesFromText(text);
    if (coordinates == null) return null;

    return Container(
      height: 180,
      margin: const EdgeInsets.only(top: 8, left: 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: coordinates,
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none, // Disable all interactions
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.pet_shop',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: coordinates,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Overlay button to open in Google Maps
            Positioned(
              bottom: 8,
              right: 8,
              child: ElevatedButton.icon(
                onPressed: () => _openInGoogleMaps(coordinates),
                icon: const Icon(Icons.map, size: 16),
                label: const Text('Mở Google Maps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _ExpandableMessageText extends StatefulWidget {
  final String text;
  final bool isUser;

  const _ExpandableMessageText({
    required this.text,
    required this.isUser,
  });

  @override
  State<_ExpandableMessageText> createState() => _ExpandableMessageTextState();
}

class _ExpandableMessageTextState extends State<_ExpandableMessageText> {
  bool _isExpanded = false;
  static const int _maxLines = 5;
  static const int _maxCharacters = 200;

  bool get _shouldShowToggle {
    return widget.text.length > _maxCharacters ||
        widget.text.split('\n').length > _maxLines;
  }

  String get _displayText {
    if (!_shouldShowToggle || _isExpanded) {
      return widget.text;
    }

    // Truncate by character count
    if (widget.text.length > _maxCharacters) {
      return widget.text.substring(0, _maxCharacters) + '...';
    }

    // Truncate by line count
    final lines = widget.text.split('\n');
    if (lines.length > _maxLines) {
      return lines.take(_maxLines).join('\n') + '...';
    }

    return widget.text;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isUser
            ? Theme.of(context).primaryColor
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: widget.isUser
            ? null
            : Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _displayText,
            style: TextStyle(
              color: widget.isUser ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
          ),
          if (_shouldShowToggle) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Text(
                _isExpanded ? 'Thu gọn' : 'Xem thêm',
                style: TextStyle(
                  color: widget.isUser
                      ? Colors.white.withOpacity(0.8)
                      : Theme.of(context).primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
