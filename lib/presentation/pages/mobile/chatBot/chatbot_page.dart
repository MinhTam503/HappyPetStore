import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pet_shop/core/service_locator.dart';
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_bloc.dart';
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_event.dart';
import 'package:pet_shop/presentation/bloc/chatBot/chatbot_state.dart';
import 'package:pet_shop/domain/entities/chatbot_entity.dart';
import 'package:pet_shop/presentation/pages/mobile/pet/detail_pet.dart';

class ChatBotPage extends StatefulWidget {
  final String userId;

  const ChatBotPage({
    super.key,
    required this.userId,
  });

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUserScrolling = false;
  bool _autoScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    // Listen to scroll events to detect user manual scrolling
    _scrollController.addListener(_scrollListener);
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
                  text: message.text,
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
                hintText: 'Hỏi về thú cưng...',
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
                  onPressed: isLoading
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
      onTap: () {
        // Navigate to pet detail page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailPet(
              pet: {
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
              },
            ),
          ),
        );
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
