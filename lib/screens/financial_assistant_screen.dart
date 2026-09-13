import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/language_constants.dart';
import '../providers/spending_provider.dart';
import '../services/auth_service.dart';
import '../services/financial_assistant_service.dart';
import '../sheets/home_sheets.dart';

class FinancialAssistantScreen extends StatefulWidget {
  const FinancialAssistantScreen({super.key});

  @override
  State<FinancialAssistantScreen> createState() =>
      _FinancialAssistantScreenState();
}

class _FinancialAssistantScreenState extends State<FinancialAssistantScreen>
    with WidgetsBindingObserver {
  final _service = const FinancialAssistantService();
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  FinancialAssistantConversationContext _conversationContext =
      const FinancialAssistantConversationContext();
  List<String> _inlineSuggestions = const <String>[];
  bool _suggestionsDismissed = false;
  Timer? _midnightTimer;
  String? _activeSessionDateKey;
  bool _isProcessing = false;
  bool _didSeedWelcomeMessage = false;
  bool _isHydratingSession = true;
  int? _editingUserMessageIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSeedWelcomeMessage) return;
    _didSeedWelcomeMessage = true;
    unawaited(_restoreOrCreateSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_rolloverIfNeeded());
    }
  }

  void _seedWelcomeMessage() {
    final provider = context.read<SpendingProvider>();
    final initialContext = const FinancialAssistantConversationContext();
    _messages
      ..clear()
      ..add(
        _ChatMessage.assistant(
          text:
              'Your financial assistant is ready. I can answer questions about your budget, spending, banks, recurring payments, and prepare actions for you to confirm.',
          facts: <FinancialAssistantFact>[
            FinancialAssistantFact(
              label: getTranslated(context, 'Budget'),
              value: '${provider.monthlyBudget.toStringAsFixed(2)} SAR',
            ),
            FinancialAssistantFact(
              label: 'Spent this period',
              value: '${provider.periodTotal.toStringAsFixed(2)} SAR',
            ),
            FinancialAssistantFact(
              label: 'Today available',
              value: '${provider.dailyAllowance.toStringAsFixed(2)} SAR',
            ),
          ],
          contextSnapshot: initialContext,
        ),
      );
  }

  Future<void> _restoreOrCreateSession() async {
    final restored = await _restoreSessionForToday();
    if (!mounted) return;
    if (!restored) {
      setState(() {
        _seedWelcomeMessage();
        _conversationContext = const FinancialAssistantConversationContext();
        _isHydratingSession = false;
      });
      await _persistSession();
    } else {
      setState(() {
        _isHydratingSession = false;
      });
    }
    _updateInlineSuggestions();
    _scheduleMidnightRefresh();
    _scrollToBottom();
  }

  Future<bool> _restoreSessionForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _sessionKeyForToday();
    _activeSessionDateKey = _todayKey();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return false;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if ((decoded['sessionDate'] as String?) != _todayKey()) {
        return false;
      }

      final restoredMessages =
          (decoded['messages'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) => _ChatMessage.fromJson(
                  Map<String, dynamic>.from(item),
                  _service,
                ),
              )
              .toList();
      final restoredContext = decoded['context'] is Map
          ? _service.decodeConversationContext(
              Map<String, dynamic>.from(decoded['context'] as Map),
            )
          : const FinancialAssistantConversationContext();

      setState(() {
        _messages
          ..clear()
          ..addAll(restoredMessages);
        _conversationContext = restoredContext;
      });
      return restoredMessages.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, Object?>{
      'sessionDate': _todayKey(),
      'messages': _messages.map((message) => message.toJson(_service)).toList(),
      'context': _service.encodeConversationContext(_conversationContext),
    };
    await prefs.setString(_sessionKeyForToday(), jsonEncode(payload));
  }

  Future<void> _rolloverIfNeeded() async {
    final todayKey = _todayKey();
    if (_activeSessionDateKey == todayKey) {
      _scheduleMidnightRefresh();
      return;
    }

    if (!mounted) return;
    setState(() {
      _activeSessionDateKey = todayKey;
      _messages.clear();
      _conversationContext = const FinancialAssistantConversationContext();
      _inlineSuggestions = const <String>[];
      _seedWelcomeMessage();
    });
    await _persistSession();
    _scheduleMidnightRefresh();
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () => unawaited(_rolloverIfNeeded()),
    );
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _sessionKeyForToday() {
    final uid = context.read<AuthService>().currentUser?.uid ?? 'guest';
    return 'financial_assistant_session_${uid}_${_todayKey()}';
  }

  bool get _hasStartedConversation =>
      _messages.any((message) => message.isUser);

  bool _shouldShowHeaderPrompts(bool keyboardVisible) {
    return !_hasStartedConversation && !keyboardVisible;
  }

  bool _shouldShowInlineSuggestions() {
    final hasTypedInput = _inputController.text.trim().isNotEmpty;
    if (!_hasStartedConversation && !hasTypedInput) return false;
    return _inlineSuggestions.isNotEmpty && !_suggestionsDismissed;
  }

  List<String> get _primaryInlineSuggestions {
    final hasTypedInput = _inputController.text.trim().isNotEmpty;
    final limit = hasTypedInput ? 4 : (_hasStartedConversation ? 3 : 5);
    return _inlineSuggestions.take(limit).toList();
  }

  bool get _hasMoreInlineSuggestions =>
      _inlineSuggestions.length > _primaryInlineSuggestions.length;

  Future<void> _showAllSuggestionsSheet() async {
    final suggestions = List<String>.from(_inlineSuggestions);
    if (suggestions.isEmpty) return;

    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.auto_awesome_rounded, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Suggested questions',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) => Divider(
                      color: cs.outlineVariant.withValues(alpha: 0.45),
                    ),
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        leading: Icon(
                          _suggestionIconFor(suggestion),
                          color: cs.primary,
                        ),
                        title: _SuggestionText(
                          suggestion: suggestion,
                          query: _inputController.text.trim(),
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _insertSuggestion(suggestion);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateInlineSuggestions([String? rawInput]) {
    if (!mounted) return;
    final query = rawInput ?? _inputController.text;
    final provider = context.read<SpendingProvider>();
    final nextSuggestions = _service.suggestionsForInput(
      query,
      provider,
      context: _conversationContext,
    );
    setState(() {
      _inlineSuggestions = nextSuggestions;
      if (query.trim().isNotEmpty) {
        _suggestionsDismissed = false;
      }
    });
  }

  void _insertSuggestion(String suggestion) {
    _inputController
      ..text = suggestion
      ..selection = TextSelection.collapsed(offset: suggestion.length);
    _updateInlineSuggestions(suggestion);
    _inputFocusNode.requestFocus();
  }

  Future<void> _submitComposer() async {
    if (_editingUserMessageIndex != null) {
      await _saveEditedUserMessage();
      return;
    }
    await _sendMessage();
  }

  Future<void> _sendMessage([String? preset]) async {
    await _rolloverIfNeeded();
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _isProcessing) return;

    FocusScope.of(context).unfocus();
    _inputController.clear();

    setState(() {
      _inlineSuggestions = const <String>[];
      _messages.add(_ChatMessage.user(text));
      _isProcessing = true;
    });
    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 260));

    final provider = context.read<SpendingProvider>();
    final reply = _service.handleMessage(
      text,
      provider,
      context: _conversationContext,
    );

    if (!mounted) return;
    setState(() {
      _conversationContext = reply.context;
      _inlineSuggestions = _service.suggestionsForInput(
        '',
        provider,
        context: _conversationContext,
      );
      _messages.add(
        _ChatMessage.assistant(
          text: reply.message,
          facts: reply.facts,
          pendingAction: reply.pendingAction,
          contextSnapshot: reply.context,
        ),
      );
      _isProcessing = false;
    });
    await _persistSession();
    _scrollToBottom();
  }

  bool _canEditUserMessage(int index) {
    if (index < 0 || index >= _messages.length) return false;
    final message = _messages[index];
    if (!message.isUser) return false;

    for (var i = index + 1; i < _messages.length; i++) {
      final current = _messages[i];
      if (current.isUser) continue;
      if (current.pendingAction != null && current.isResolved) {
        return false;
      }
    }

    return _contextBeforeUserMessage(index) != null;
  }

  FinancialAssistantConversationContext? _contextBeforeUserMessage(int index) {
    for (var i = index - 1; i >= 0; i--) {
      final message = _messages[i];
      if (message.isUser) continue;
      if (message.contextSnapshot != null) {
        return message.contextSnapshot;
      }
    }

    if (index == 0) {
      return const FinancialAssistantConversationContext();
    }
    return null;
  }

  void _startEditingUserMessage(int index) {
    if (!_canEditUserMessage(index)) return;
    final message = _messages[index];
    _editingUserMessageIndex = index;
    _insertSuggestion(message.text);
    setState(() {});
  }

  void _cancelEditingUserMessage() {
    _editingUserMessageIndex = null;
    _inputController.clear();
    _updateInlineSuggestions('');
    setState(() {});
  }

  Future<void> _saveEditedUserMessage() async {
    await _rolloverIfNeeded();
    final index = _editingUserMessageIndex;
    final updatedText = _inputController.text.trim();
    if (index == null || updatedText.isEmpty || _isProcessing) return;

    final baseContext = _contextBeforeUserMessage(index);
    if (baseContext == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This message can no longer be edited safely because its conversation context is unavailable.',
          ),
        ),
      );
      return;
    }

    final suffixHasResolvedAction = _messages
        .skip(index + 1)
        .where((message) => !message.isUser)
        .any((message) => message.pendingAction != null && message.isResolved);
    if (suffixHasResolvedAction) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Messages tied to confirmed financial actions cannot be edited automatically.',
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    final provider = context.read<SpendingProvider>();
    final replayInputs = <String>[
      updatedText,
      ..._messages
          .skip(index + 1)
          .where((message) => message.isUser)
          .map((message) => message.text),
    ];
    final preservedPrefix = List<_ChatMessage>.from(_messages.take(index));

    setState(() {
      _isProcessing = true;
      _editingUserMessageIndex = null;
      _inlineSuggestions = const <String>[];
    });

    var runningContext = baseContext;
    final rebuiltMessages = List<_ChatMessage>.from(preservedPrefix);
    for (final input in replayInputs) {
      rebuiltMessages.add(_ChatMessage.user(input));
      final reply = _service.handleMessage(
        input,
        provider,
        context: runningContext,
      );
      runningContext = reply.context;
      rebuiltMessages.add(
        _ChatMessage.assistant(
          text: reply.message,
          facts: reply.facts,
          pendingAction: reply.pendingAction,
          contextSnapshot: runningContext,
        ),
      );
    }

    if (!mounted) return;
    _inputController.clear();
    setState(() {
      _messages
        ..clear()
        ..addAll(rebuiltMessages);
      _conversationContext = runningContext;
      _inlineSuggestions = _service.suggestionsForInput(
        '',
        provider,
        context: _conversationContext,
      );
      _isProcessing = false;
    });
    await _persistSession();
    _scrollToBottom();
  }

  Future<void> _confirmAction(_ChatMessage message) async {
    await _rolloverIfNeeded();
    final action = message.pendingAction;
    if (action == null) return;

    if (action.type == FinancialAssistantActionType.openExportOptions) {
      HomeSheets.showExportOptionsSheet(
        context,
        context.read<SpendingProvider>(),
      );
      setState(() {
        message.isResolved = true;
        _conversationContext = _conversationContext.copyWith(
          clearPendingAction: true,
        );
        _messages.add(
          _ChatMessage.assistant(
            text:
                'The export sheet is open. You can continue with PDF or CSV from there.',
            contextSnapshot: _conversationContext,
          ),
        );
      });
      await _persistSession();
      _scrollToBottom();
      return;
    }

    setState(() {
      _isProcessing = true;
      message.isResolved = true;
    });
    _scrollToBottom();

    final result = await _service.executeAction(
      action,
      context.read<SpendingProvider>(),
    );

    if (!mounted) return;
    final nextContext = _contextAfterAction(action, result);
    setState(() {
      _isProcessing = false;
      _conversationContext = nextContext;
      _messages.add(
        _ChatMessage.assistant(
          text: result.message,
          facts: result.facts,
          contextSnapshot: nextContext,
        ),
      );
    });
    await _persistSession();
    _scrollToBottom();
  }

  Future<void> _increaseDuplicateQuantity(_ChatMessage message) async {
    await _rolloverIfNeeded();
    final action = message.pendingAction;
    if (action == null) return;

    setState(() {
      _isProcessing = true;
      message.isResolved = true;
    });
    _scrollToBottom();

    final mergeAction = FinancialAssistantPendingAction(
      type: FinancialAssistantActionType.mergeDuplicateSpendingQuantity,
      title: 'Increase quantity',
      summary: action.summary,
      data: action.data,
    );

    final result = await _service.executeAction(
      mergeAction,
      context.read<SpendingProvider>(),
    );

    if (!mounted) return;
    final nextContext = _contextAfterAction(mergeAction, result);
    setState(() {
      _isProcessing = false;
      _conversationContext = nextContext;
      _messages.add(
        _ChatMessage.assistant(
          text: result.message,
          facts: result.facts,
          contextSnapshot: nextContext,
        ),
      );
    });
    await _persistSession();
    _scrollToBottom();
  }

  Future<void> _cancelAction(_ChatMessage message) async {
    await _rolloverIfNeeded();
    setState(() {
      message.isResolved = true;
      _conversationContext = _conversationContext.copyWith(
        clearPendingAction: true,
      );
      _messages.add(
        _ChatMessage.assistant(
          text: 'Cancelled. No changes were made.',
          contextSnapshot: _conversationContext,
        ),
      );
    });
    await _persistSession();
    _scrollToBottom();
  }

  Future<void> _editAction(_ChatMessage message) async {
    await _rolloverIfNeeded();
    final action = message.pendingAction;
    if (action == null) return;

    final preparedAction = _service.preparePendingActionForEditing(action);
    final helperText = _editPromptForAction(preparedAction);

    setState(() {
      _conversationContext = _conversationContext.copyWith(
        lastPendingAction: preparedAction,
      );
      _messages.add(
        _ChatMessage.assistant(
          text: helperText,
          contextSnapshot: _conversationContext,
        ),
      );
    });

    await _persistSession();
    _scrollToBottom();
    _inputFocusNode.requestFocus();
  }

  String _editPromptForAction(FinancialAssistantPendingAction action) {
    switch (action.type) {
      case FinancialAssistantActionType.addSpending:
      case FinancialAssistantActionType.editSpending:
        return 'Tell me what you want to change. For example: amount 12.50, category Food, item Burger, quantity 2, bank SNB, or date 2026-08-12.';
      case FinancialAssistantActionType.addIncome:
        return 'Tell me what you want to change. For example: amount 2500, source Salary, note August payroll, or date 2026-08-12.';
      case FinancialAssistantActionType.addRecurringPayment:
      case FinancialAssistantActionType.updateRecurringPayment:
        return 'Tell me what you want to change. For example: amount 99, day 15, category Utilities, or bank Al Rajhi.';
      default:
        return 'Tell me what you want to change in this pending action.';
    }
  }

  bool _canEditPendingAction(FinancialAssistantPendingAction? action) {
    if (action == null) return false;
    switch (action.type) {
      case FinancialAssistantActionType.addSpending:
      case FinancialAssistantActionType.addIncome:
      case FinancialAssistantActionType.editSpending:
      case FinancialAssistantActionType.addRecurringPayment:
      case FinancialAssistantActionType.updateRecurringPayment:
        return true;
      default:
        return false;
    }
  }

  bool _canIncreaseDuplicateQuantity(FinancialAssistantPendingAction? action) {
    return action?.type == FinancialAssistantActionType.addSpending &&
        action?.data['duplicateDate'] != null &&
        action?.data['duplicateIndex'] != null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  FinancialAssistantConversationContext _contextAfterAction(
    FinancialAssistantPendingAction action,
    FinancialAssistantExecutionResult result,
  ) {
    switch (action.type) {
      case FinancialAssistantActionType.addIncome:
        return _conversationContext.copyWith(
          clearPendingAction: true,
          clearSpendingSelection: true,
          lastUndoAction: result.undoAction,
          lastIncomeSource: action.data['source'] as String?,
        );
      case FinancialAssistantActionType.addRecurringPayment:
      case FinancialAssistantActionType.updateRecurringPayment:
        return _conversationContext.copyWith(
          clearPendingAction: true,
          lastUndoAction: result.undoAction,
          lastRecurringPaymentTitle: action.data['title'] as String?,
          lastCategory: action.data['category'] as String?,
          lastBankName: action.data['bankName'] as String?,
        );
      case FinancialAssistantActionType.removeRecurringPayment:
        return _conversationContext.copyWith(
          clearPendingAction: true,
          lastUndoAction: result.undoAction,
          clearRecurring: true,
        );
      case FinancialAssistantActionType.addSpending:
      case FinancialAssistantActionType.editSpending:
      case FinancialAssistantActionType.deleteSpending:
        return _conversationContext.copyWith(
          clearPendingAction: true,
          lastUndoAction: result.undoAction,
          lastCategory: action.data['category'] as String?,
          lastBankName: action.data['bankName'] as String?,
        );
      case FinancialAssistantActionType.addBank:
      case FinancialAssistantActionType.updateBankBalance:
      case FinancialAssistantActionType.renameBank:
      case FinancialAssistantActionType.removeBank:
        return _conversationContext.copyWith(
          clearPendingAction: true,
          lastUndoAction: result.undoAction,
          lastBankName:
              action.data['name'] as String? ??
              action.data['newName'] as String?,
        );
      case FinancialAssistantActionType.undoLastAction:
        return _conversationContext.copyWith(
          clearPendingAction: true,
          clearUndoAction: true,
        );
      default:
        return _conversationContext.copyWith(
          clearPendingAction: true,
          lastUndoAction: result.undoAction,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mediaQuery = MediaQuery.of(context);
    final keyboardVisible = mediaQuery.viewInsets.bottom > 0;
    final bottomSafePadding = mediaQuery.viewPadding.bottom;
    final chipBackground = cs.surfaceContainerHigh;
    final chipForeground = cs.onSurface;
    final chipBorder = cs.outlineVariant;

    return Scaffold(
      appBar: AppBar(
        title: Text(getTranslated(context, 'Financial Assistant')),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[cs.surface, cs.surfaceContainerLowest, cs.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: _isHydratingSession
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: <Widget>[
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          keyboardVisible ? 8 : 12,
                          16,
                          keyboardVisible ? 4 : 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Talk to your spending data naturally.',
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: keyboardVisible ? 4 : 6),
                            Text(
                              'Read-only questions answer immediately. Any action that changes data will ask for confirmation first.',
                              style: text.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                            if (_shouldShowHeaderPrompts(
                              keyboardVisible,
                            )) ...<Widget>[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 40,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: FinancialAssistantService
                                      .quickPrompts
                                      .length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final prompt = FinancialAssistantService
                                        .quickPrompts[index];
                                    return ActionChip(
                                      label: Text(prompt),
                                      labelStyle: text.labelLarge?.copyWith(
                                        color: chipForeground,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      side: BorderSide(color: chipBorder),
                                      backgroundColor: chipBackground,
                                      disabledColor: chipBackground.withValues(
                                        alpha: 0.6,
                                      ),
                                      pressElevation: 0,
                                      color:
                                          WidgetStateProperty.resolveWith<
                                            Color?
                                          >((states) {
                                            if (states.contains(
                                              WidgetState.pressed,
                                            )) {
                                              return cs.surfaceContainerHighest;
                                            }
                                            if (states.contains(
                                              WidgetState.hovered,
                                            )) {
                                              return cs.surfaceContainer;
                                            }
                                            if (states.contains(
                                              WidgetState.disabled,
                                            )) {
                                              return chipBackground.withValues(
                                                alpha: 0.6,
                                              );
                                            }
                                            return chipBackground;
                                          }),
                                      iconTheme: IconThemeData(
                                        color: chipForeground,
                                      ),
                                      onPressed: () =>
                                          _insertSuggestion(prompt),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _messages.length + (_isProcessing ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isProcessing && index == _messages.length) {
                            return const _TypingBubble();
                          }
                          final message = _messages[index];
                          return _ChatBubble(
                            message: message,
                            onEditUserMessage:
                                message.isUser && _canEditUserMessage(index)
                                ? () => _startEditingUserMessage(index)
                                : null,
                            onIncreaseDuplicateQuantity:
                                message.pendingAction == null ||
                                    message.isResolved ||
                                    !_canIncreaseDuplicateQuantity(
                                      message.pendingAction,
                                    )
                                ? null
                                : () => _increaseDuplicateQuantity(message),
                            onEdit:
                                message.pendingAction == null ||
                                    message.isResolved ||
                                    !_canEditPendingAction(
                                      message.pendingAction,
                                    )
                                ? null
                                : () => _editAction(message),
                            onConfirm:
                                message.pendingAction == null ||
                                    message.isResolved
                                ? null
                                : () => _confirmAction(message),
                            onCancel:
                                message.pendingAction == null ||
                                    message.isResolved
                                ? null
                                : () => _cancelAction(message),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        bottomSafePadding + 12,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: cs.outlineVariant),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: cs.shadow.withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    if (_shouldShowInlineSuggestions()) ...<
                                      Widget
                                    >[
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: AnimatedSize(
                                          duration: const Duration(
                                            milliseconds: 160,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                children: <Widget>[
                                                  Icon(
                                                    Icons.auto_awesome_rounded,
                                                    size: 16,
                                                    color: cs.primary,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _hasStartedConversation
                                                        ? 'Smart suggestions'
                                                        : 'Suggested questions',
                                                    style: text.labelMedium
                                                        ?.copyWith(
                                                          color: cs
                                                              .onSurfaceVariant,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  const Spacer(),
                                                  if (_hasMoreInlineSuggestions)
                                                    TextButton(
                                                      onPressed: _isProcessing
                                                          ? null
                                                          : _showAllSuggestionsSheet,
                                                      style: TextButton.styleFrom(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        minimumSize: Size.zero,
                                                        tapTargetSize:
                                                            MaterialTapTargetSize
                                                                .shrinkWrap,
                                                      ),
                                                      child: const Text('More'),
                                                    ),
                                                  IconButton(
                                                    tooltip: 'Hide suggestions',
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    iconSize: 18,
                                                    onPressed: () {
                                                      setState(() {
                                                        _suggestionsDismissed =
                                                            true;
                                                      });
                                                    },
                                                    icon: const Icon(
                                                      Icons.close_rounded,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                height: 40,
                                                child: ListView.separated(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  itemCount:
                                                      _primaryInlineSuggestions
                                                          .length,
                                                  separatorBuilder: (_, __) =>
                                                      const SizedBox(width: 8),
                                                  itemBuilder: (context, index) {
                                                    final suggestion =
                                                        _primaryInlineSuggestions[index];
                                                    return ActionChip(
                                                      avatar: Icon(
                                                        _suggestionIconFor(
                                                          suggestion,
                                                        ),
                                                        size: 16,
                                                        color: cs.primary,
                                                      ),
                                                      label: ConstrainedBox(
                                                        constraints: BoxConstraints(
                                                          maxWidth:
                                                              _hasStartedConversation
                                                              ? 210
                                                              : 240,
                                                        ),
                                                        child: _SuggestionText(
                                                          suggestion:
                                                              suggestion,
                                                          query:
                                                              _inputController
                                                                  .text
                                                                  .trim(),
                                                        ),
                                                      ),
                                                      onPressed: _isProcessing
                                                          ? null
                                                          : () =>
                                                                _insertSuggestion(
                                                                  suggestion,
                                                                ),
                                                      side: BorderSide(
                                                        color:
                                                            cs.outlineVariant,
                                                      ),
                                                      backgroundColor: cs
                                                          .surfaceContainerLowest,
                                                      pressElevation: 0,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (_editingUserMessageIndex !=
                                        null) ...<Widget>[
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: cs.outlineVariant,
                                            ),
                                          ),
                                          child: Row(
                                            children: <Widget>[
                                              Icon(
                                                Icons.edit_rounded,
                                                size: 16,
                                                color: cs.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Editing your message',
                                                  style: text.bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            cs.onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    _cancelEditingUserMessage,
                                                style: TextButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    TextField(
                                      controller: _inputController,
                                      focusNode: _inputFocusNode,
                                      minLines: 1,
                                      maxLines: 4,
                                      textInputAction: TextInputAction.send,
                                      onChanged: _updateInlineSuggestions,
                                      onSubmitted: (_) => _submitComposer(),
                                      decoration: InputDecoration(
                                        hintText:
                                            _editingUserMessageIndex == null
                                            ? 'Ask about your budget, spending, or tell me what to do'
                                            : 'Update your question before sending it again',
                                        border: InputBorder.none,
                                        hintStyle: text.bodyMedium?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _submitComposer(),
                                style: FilledButton.styleFrom(
                                  shape: const CircleBorder(),
                                  padding: const EdgeInsets.all(14),
                                ),
                                child: Icon(
                                  _editingUserMessageIndex == null
                                      ? Icons.arrow_upward_rounded
                                      : Icons.check_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  IconData _suggestionIconFor(String suggestion) {
    final normalized = suggestion.toLowerCase();
    if (normalized.contains('bank')) return Icons.account_balance_outlined;
    if (normalized.contains('recurring') || normalized.contains('bill')) {
      return Icons.event_repeat_outlined;
    }
    if (normalized.contains('budget') ||
        normalized.contains('allowance') ||
        normalized.contains('over budget')) {
      return Icons.pie_chart_outline_rounded;
    }
    if (normalized.contains('report') || normalized.contains('summary')) {
      return Icons.description_outlined;
    }
    if (normalized.contains('add spending') || normalized.contains('income')) {
      return Icons.add_circle_outline_rounded;
    }
    return Icons.chat_bubble_outline_rounded;
  }
}

class _ChatMessage {
  _ChatMessage.user(this.text)
    : isUser = true,
      facts = const <FinancialAssistantFact>[],
      pendingAction = null,
      contextSnapshot = null;

  _ChatMessage.assistant({
    required this.text,
    this.facts = const <FinancialAssistantFact>[],
    this.pendingAction,
    this.contextSnapshot,
  }) : isUser = false;

  final bool isUser;
  final String text;
  final List<FinancialAssistantFact> facts;
  final FinancialAssistantPendingAction? pendingAction;
  final FinancialAssistantConversationContext? contextSnapshot;
  bool isResolved = false;

  Map<String, Object?> toJson(FinancialAssistantService service) {
    return <String, Object?>{
      'isUser': isUser,
      'text': text,
      'facts': facts
          .map(
            (fact) => <String, Object?>{
              'label': fact.label,
              'value': fact.value,
              'note': fact.note,
            },
          )
          .toList(),
      'pendingAction': pendingAction == null
          ? null
          : service.encodePendingAction(pendingAction!),
      'contextSnapshot': contextSnapshot == null
          ? null
          : service.encodeConversationContext(contextSnapshot!),
      'isResolved': isResolved,
    };
  }

  factory _ChatMessage.fromJson(
    Map<String, dynamic> json,
    FinancialAssistantService service,
  ) {
    final isUser = json['isUser'] as bool? ?? false;
    final facts = (json['facts'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (fact) => FinancialAssistantFact(
            label: fact['label'] as String? ?? '',
            value: fact['value'] as String? ?? '',
            note: fact['note'] as String?,
          ),
        )
        .toList();
    final pendingAction = json['pendingAction'] is Map
        ? service.decodePendingAction(
            Map<String, dynamic>.from(json['pendingAction'] as Map),
          )
        : null;
    final contextSnapshot = json['contextSnapshot'] is Map
        ? service.decodeConversationContext(
            Map<String, dynamic>.from(json['contextSnapshot'] as Map),
          )
        : null;

    final message = isUser
        ? _ChatMessage.user(json['text'] as String? ?? '')
        : _ChatMessage.assistant(
            text: json['text'] as String? ?? '',
            facts: facts,
            pendingAction: pendingAction,
            contextSnapshot: contextSnapshot,
          );
    message.isResolved = json['isResolved'] as bool? ?? false;
    return message;
  }
}

class _SuggestionText extends StatelessWidget {
  const _SuggestionText({required this.suggestion, required this.query});

  final String suggestion;
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final baseStyle = theme.textTheme.bodySmall?.copyWith(color: cs.onSurface);

    final highlightStyle = baseStyle?.copyWith(
      color: cs.primary,
      fontWeight: FontWeight.w800,
    );

    final normalizedSuggestion = suggestion.toLowerCase();
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return Text(
        suggestion,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final spans = <TextSpan>[];
    var cursor = 0;

    while (cursor < suggestion.length) {
      var bestStart = suggestion.length;
      var bestToken = '';

      for (final token in tokens) {
        final index = normalizedSuggestion.indexOf(token, cursor);

        if (index >= 0 && index < bestStart) {
          bestStart = index;
          bestToken = token;
        }
      }

      if (bestToken.isEmpty) {
        spans.add(
          TextSpan(text: suggestion.substring(cursor), style: baseStyle),
        );
        break;
      }

      if (bestStart > cursor) {
        spans.add(
          TextSpan(
            text: suggestion.substring(cursor, bestStart),
            style: baseStyle,
          ),
        );
      }

      spans.add(
        TextSpan(
          text: suggestion.substring(bestStart, bestStart + bestToken.length),
          style: highlightStyle,
        ),
      );

      cursor = bestStart + bestToken.length;
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.onEditUserMessage,
    this.onIncreaseDuplicateQuantity,
    this.onEdit,
    this.onConfirm,
    this.onCancel,
  });

  final _ChatMessage message;
  final VoidCallback? onEditUserMessage;
  final VoidCallback? onIncreaseDuplicateQuantity;
  final VoidCallback? onEdit;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final align = message.isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleColor = message.isUser
        ? cs.primary
        : cs.surfaceContainerHighest.withValues(alpha: 0.72);
    final foreground = message.isUser ? cs.onPrimary : cs.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: <Widget>[
          Row(
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              // if (message.isUser && onEditUserMessage != null)
              //   Padding(
              //     padding: const EdgeInsets.only(right: 6, bottom: 4),
              //     child: IconButton(
              //       onPressed: onEditUserMessage,
              //       tooltip: 'Edit message',
              //       visualDensity: VisualDensity.compact,
              //       iconSize: 18,
              //       style: IconButton.styleFrom(
              //         backgroundColor: cs.surfaceContainerHighest,
              //         foregroundColor: cs.onSurfaceVariant,
              //       ),
              //       icon: const Icon(Icons.edit_outlined),
              //     ),
              //   ),
              Flexible(
                child: GestureDetector(
                  onLongPress: onEditUserMessage == null
                      ? null
                      : () async {
                          final action = await showModalBottomSheet<String>(
                            context: context,
                            showDragHandle: true,
                            builder: (sheetContext) {
                              final sheetText = Theme.of(
                                sheetContext,
                              ).textTheme;
                              return SafeArea(
                                top: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    20,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Message options',
                                        style: sheetText.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.edit_outlined,
                                        ),
                                        title: const Text('Edit sent message'),
                                        subtitle: const Text(
                                          'Update this question and generate a new answer.',
                                        ),
                                        onTap: () {
                                          Navigator.of(
                                            sheetContext,
                                          ).pop('edit');
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                          if (action == 'edit') {
                            onEditUserMessage!();
                          }
                        },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 560),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(22),
                        topRight: const Radius.circular(22),
                        bottomLeft: Radius.circular(message.isUser ? 22 : 8),
                        bottomRight: Radius.circular(message.isUser ? 8 : 22),
                      ),
                      border: message.isUser
                          ? null
                          : Border.all(color: cs.outlineVariant),
                    ),
                    child: Text(
                      message.text,
                      style: text.bodyMedium?.copyWith(
                        color: foreground,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // if (message.isUser && onEditUserMessage != null)
          //   Padding(
          //     padding: const EdgeInsets.only(top: 4),
          //     child: TextButton.icon(
          //       onPressed: onEditUserMessage,
          //       style: TextButton.styleFrom(
          //         padding: const EdgeInsets.symmetric(
          //           horizontal: 10,
          //           vertical: 6,
          //         ),
          //         minimumSize: Size.zero,
          //         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          //         foregroundColor: cs.onSurfaceVariant,
          //       ),
          //       icon: const Icon(Icons.edit_outlined, size: 16),
          //       label: const Text('Edit'),
          //     ),
          //   ),
          if (message.facts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.facts
                    .map((fact) => _FactCard(fact: fact))
                    .toList(),
              ),
            ),
          if (message.pendingAction != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _PendingActionCard(
                action: message.pendingAction!,
                isResolved: message.isResolved,
                onIncreaseDuplicateQuantity: onIncreaseDuplicateQuantity,
                onEdit: onEdit,
                onConfirm: onConfirm,
                onCancel: onCancel,
              ),
            ),
        ],
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.fact});

  final FinancialAssistantFact fact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            fact.label,
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            fact.value,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (fact.note != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              fact.note!,
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingActionCard extends StatelessWidget {
  const _PendingActionCard({
    required this.action,
    required this.isResolved,
    this.onIncreaseDuplicateQuantity,
    this.onEdit,
    this.onConfirm,
    this.onCancel,
  });

  final FinancialAssistantPendingAction action;
  final bool isResolved;
  final VoidCallback? onIncreaseDuplicateQuantity;
  final VoidCallback? onEdit;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = action.destructive ? cs.error : cs.primary;

    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            action.title,
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(action.summary, style: text.bodyMedium?.copyWith(height: 1.4)),
          const SizedBox(height: 12),
          if (isResolved)
            Text(
              'Handled',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (onIncreaseDuplicateQuantity != null)
                  FilledButton.tonal(
                    onPressed: onIncreaseDuplicateQuantity,
                    child: const Text('Increase Quantity'),
                  ),
                if (onEdit != null)
                  OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
                FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: action.destructive
                        ? cs.onError
                        : cs.onPrimary,
                  ),
                  child: Text(action.requiresConfirmation ? 'Confirm' : 'Open'),
                ),
                OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final step = (_controller.value * 3).floor() % 3;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List<Widget>.generate(3, (index) {
                final active = index == step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 12 : 8,
                  height: active ? 12 : 8,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: active ? 0.95 : 0.35),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
