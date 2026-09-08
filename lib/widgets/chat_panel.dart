import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/ide_providers.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class ChatPanel extends ConsumerStatefulWidget {
  final double width;
  final ValueChanged<double> onWidthChanged;

  const ChatPanel({super.key, required this.width, required this.onWidthChanged});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(aiServiceProvider).streamChat(text);
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  Widget build(BuildContext context) {
    final themeType = ref.watch(themeProvider);
    final theme = AppTheme.fromType(themeType);
    final messages = ref.watch(chatMessagesProvider);
    final isGenerating = messages.isNotEmpty && messages.last.isStreaming;
    
    // Auto scroll when messages change
    ref.listen(chatMessagesProvider, (prev, next) {
      if (next.isNotEmpty && next.last.isStreaming) {
        _scrollToBottom();
      }
    });

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
        color: theme.surface,
        border: Border(left: BorderSide(color: theme.panelBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(-5, 0),
          )
        ],
      ),
      child: Row(
        children: [
          // Resize handle
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                final newWidth = widget.width - details.delta.dx;
                if (newWidth > 250 && newWidth < MediaQuery.of(context).size.width * 0.8) {
                  widget.onWidthChanged(newWidth);
                }
              },
              child: Container(
                width: 6,
                color: Colors.transparent,
              ),
            ),
          ),
          // Content
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.background,
                    border: Border(bottom: BorderSide(color: theme.panelBorder)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.smart_toy_outlined, color: theme.info, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        './ACE AI Assistant',
                        style: theme.uiText.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: theme.textMuted, size: 20),
                        tooltip: 'Clear Chat',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                backgroundColor: theme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: theme.panelBorder),
                                ),
                                title: Text('Clear Chat', style: theme.uiText.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                                content: Text(
                                  'Are you sure you want to clear the current chat? It will delete all previous messages/inquiries/chats.',
                                  style: theme.uiText.copyWith(height: 1.5),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: Text('Cancel', style: theme.uiText.copyWith(color: theme.textSecondary)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: Text('Clear', style: theme.uiText.copyWith(color: theme.error, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirm == true) {
                            ref.read(aiServiceProvider).clearChat();
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: theme.textMuted, size: 20),
                        tooltip: 'Close',
                        onPressed: () {
                          ref.read(isChatPanelOpenProvider.notifier).state = false;
                        },
                      ),
                    ],
                  ),
                ),
                // Messages List
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _ChatMessageBubble(message: msg, theme: theme);
                    },
                  ),
                ),
                // Input Field
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.background,
                    border: Border(top: BorderSide(color: theme.panelBorder)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: theme.neumorphicInner(radius: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            style: theme.uiText,
                            decoration: InputDecoration(
                              hintText: 'Ask a programming question...',
                              hintStyle: theme.uiText.copyWith(color: theme.textMuted),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            maxLines: 4,
                            minLines: 1,
                            onSubmitted: isGenerating ? null : (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: theme.neumorphicOuter(radius: 8),
                        child: isGenerating
                            ? IconButton(
                                icon: Icon(Icons.stop_rounded, color: theme.error),
                                onPressed: () => ref.read(aiServiceProvider).stopChat(),
                              )
                            : IconButton(
                                icon: Icon(Icons.send_rounded, color: theme.info),
                                onPressed: _sendMessage,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final AppTheme theme;

  const _ChatMessageBubble({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isAi = message.role == ChatRole.ai;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAi) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: theme.neumorphicOuter(radius: 8),
              child: Icon(Icons.smart_toy_outlined, size: 16, color: theme.info),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Text(
                  isAi ? 'AI Assistant' : 'You',
                  style: theme.uiTextSmall.copyWith(color: theme.textMuted, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                _ParsedMessageContent(text: message.text, theme: theme, isAi: isAi),
              ],
            ),
          ),
          if (!isAi) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: theme.neumorphicOuter(radius: 8),
              child: Icon(Icons.person_outline, size: 16, color: theme.accent),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParsedMessageContent extends StatelessWidget {
  final String text;
  final AppTheme theme;
  final bool isAi;

  const _ParsedMessageContent({required this.text, required this.theme, required this.isAi});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty && isAi) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: isAi ? theme.neumorphicOuter(radius: 12) : theme.neumorphicInner(radius: 12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: theme.info),
        ),
      );
    }

    final parts = text.split('```');
    final widgets = <Widget>[];

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        // Code block
        var codeContent = parts[i];
        final firstLineEnd = codeContent.indexOf('\n');
        String lang = '';
        if (firstLineEnd != -1) {
          lang = codeContent.substring(0, firstLineEnd).trim();
          codeContent = codeContent.substring(firstLineEnd + 1);
        } else {
           // Fallback if no newline found
           lang = '';
        }

        if (codeContent.endsWith('\n')) {
          codeContent = codeContent.substring(0, codeContent.length - 1);
        }

        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: theme.neumorphicInner(radius: 8),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: theme.background.withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      Text(lang.isNotEmpty ? lang : 'code', style: theme.uiTextSmall.copyWith(color: theme.textSecondary)),
                      const Spacer(),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: codeContent));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Code copied to clipboard', style: theme.uiTextSmall),
                                backgroundColor: theme.surface,
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Icon(Icons.copy_rounded, size: 14, color: theme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    codeContent,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      color: theme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Normal text
        final trimmed = parts[i].trim();
        if (trimmed.isNotEmpty) {
          widgets.add(
            Container(
              padding: const EdgeInsets.all(12),
              decoration: isAi ? theme.neumorphicOuter(radius: 12) : theme.neumorphicInner(radius: 12),
              child: SelectableText(
                trimmed,
                style: theme.uiText.copyWith(color: theme.textPrimary, height: 1.5),
              ),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: widgets,
    );
  }
}
