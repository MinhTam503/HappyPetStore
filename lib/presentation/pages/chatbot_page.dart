import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/service_locator.dart';
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_bloc.dart';
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_event.dart';
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_state.dart';
import 'package:pet_shop/domain/entities/chatbot_entity.dart';

class ChatBotPage extends StatefulWidget {
  final String userId;

  const ChatBotPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => serviceLocator<ChatBotBloc>()..add(LoadChatBotHistory(widget.userId)),
      child: Builder(
        builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Pet Assistant'),
          backgroundColor: const Color(0xff08A045),
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            BlocBuilder<ChatBotBloc, ChatBotState>(
              builder: (blocContext, state) {
                return IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: const Text('Clear Chat History'),
                          content: const Text('Are you sure you want to clear all chat history?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                blocContext.read<ChatBotBloc>().add(ClearChatBotHistory(widget.userId));
                                Navigator.of(dialogContext).pop();
                              },
                              child: const Text('Clear'),
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
              child: BlocConsumer<ChatBotBloc, ChatBotState>(
                listener: (context, state) {
                  if (state is ChatBotLoaded || state is ChatBotMessageSent) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
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
                            'Hello! I\'m your Pet Assistant.',
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ask me anything about pets!',
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
            ),
            _buildMessageInput(),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatBotMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: message.isUser ? null : Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[400],
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Typing...',
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
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask about pets...',
                hintStyle: TextStyle(color: Colors.grey[600]),
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
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: isLoading ? null : () {
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
}