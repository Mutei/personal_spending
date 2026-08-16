import 'package:intl/intl.dart';

import '../providers/spending_provider.dart';

enum FinancialAssistantActionType {
  addSpending,
  addIncome,
  editSpending,
  deleteSpending,
  mergeDuplicateSpendingQuantity,
  addBank,
  updateBankBalance,
  renameBank,
  removeBank,
  addRecurringPayment,
  updateRecurringPayment,
  removeRecurringPayment,
  undoLastAction,
  openExportOptions,
}

class FinancialAssistantFact {
  const FinancialAssistantFact({
    required this.label,
    required this.value,
    this.note,
  });

  final String label;
  final String value;
  final String? note;
}

class FinancialAssistantSpendingSelection {
  const FinancialAssistantSpendingSelection({
    required this.date,
    required this.index,
    required this.entry,
  });

  final DateTime date;
  final int index;
  final SpendingEntry entry;
}

enum _AssistantQueryKind { affordability, spendingHistory }

class _AssistantDateRange {
  const _AssistantDateRange({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;
}

class _SpendingHistoryQuery {
  const _SpendingHistoryQuery({
    this.dateRange,
    this.category,
    this.bank,
    this.needsPeriodClarification = false,
    this.wantsEntryBreakdown = false,
  });

  final _AssistantDateRange? dateRange;
  final String? category;
  final BankAccount? bank;
  final bool needsPeriodClarification;
  final bool wantsEntryBreakdown;
}

class FinancialAssistantConversationContext {
  const FinancialAssistantConversationContext({
    this.lastCategory,
    this.lastBankName,
    this.lastPendingAction,
    this.lastSpendingSelection,
    this.lastUndoAction,
    this.lastIncomeSource,
    this.lastRecurringPaymentId,
    this.lastRecurringPaymentTitle,
    this.lastQueryKind,
    this.lastQueryStart,
    this.lastQueryEnd,
    this.lastQueryLabel,
    this.lastRequestedAmount,
  });

  final String? lastCategory;
  final String? lastBankName;
  final FinancialAssistantPendingAction? lastPendingAction;
  final FinancialAssistantSpendingSelection? lastSpendingSelection;
  final FinancialAssistantPendingAction? lastUndoAction;
  final String? lastIncomeSource;
  final String? lastRecurringPaymentId;
  final String? lastRecurringPaymentTitle;
  final _AssistantQueryKind? lastQueryKind;
  final DateTime? lastQueryStart;
  final DateTime? lastQueryEnd;
  final String? lastQueryLabel;
  final double? lastRequestedAmount;

  FinancialAssistantConversationContext copyWith({
    String? lastCategory,
    String? lastBankName,
    FinancialAssistantPendingAction? lastPendingAction,
    FinancialAssistantSpendingSelection? lastSpendingSelection,
    FinancialAssistantPendingAction? lastUndoAction,
    String? lastIncomeSource,
    String? lastRecurringPaymentId,
    String? lastRecurringPaymentTitle,
    _AssistantQueryKind? lastQueryKind,
    DateTime? lastQueryStart,
    DateTime? lastQueryEnd,
    String? lastQueryLabel,
    double? lastRequestedAmount,
    bool clearCategory = false,
    bool clearBank = false,
    bool clearPendingAction = false,
    bool clearSpendingSelection = false,
    bool clearUndoAction = false,
    bool clearIncomeSource = false,
    bool clearRecurring = false,
    bool clearQuery = false,
  }) {
    return FinancialAssistantConversationContext(
      lastCategory: clearCategory ? null : (lastCategory ?? this.lastCategory),
      lastBankName: clearBank ? null : (lastBankName ?? this.lastBankName),
      lastPendingAction: clearPendingAction
          ? null
          : (lastPendingAction ?? this.lastPendingAction),
      lastSpendingSelection: clearSpendingSelection
          ? null
          : (lastSpendingSelection ?? this.lastSpendingSelection),
      lastUndoAction: clearUndoAction
          ? null
          : (lastUndoAction ?? this.lastUndoAction),
      lastIncomeSource: clearIncomeSource
          ? null
          : (lastIncomeSource ?? this.lastIncomeSource),
      lastRecurringPaymentId: clearRecurring
          ? null
          : (lastRecurringPaymentId ?? this.lastRecurringPaymentId),
      lastRecurringPaymentTitle: clearRecurring
          ? null
          : (lastRecurringPaymentTitle ?? this.lastRecurringPaymentTitle),
      lastQueryKind: clearQuery ? null : (lastQueryKind ?? this.lastQueryKind),
      lastQueryStart: clearQuery
          ? null
          : (lastQueryStart ?? this.lastQueryStart),
      lastQueryEnd: clearQuery ? null : (lastQueryEnd ?? this.lastQueryEnd),
      lastQueryLabel: clearQuery
          ? null
          : (lastQueryLabel ?? this.lastQueryLabel),
      lastRequestedAmount: clearQuery
          ? null
          : (lastRequestedAmount ?? this.lastRequestedAmount),
    );
  }
}

class FinancialAssistantPendingAction {
  const FinancialAssistantPendingAction({
    required this.type,
    required this.title,
    required this.summary,
    required this.data,
    this.destructive = false,
    this.requiresConfirmation = true,
  });

  final FinancialAssistantActionType type;
  final String title;
  final String summary;
  final Map<String, Object?> data;
  final bool destructive;
  final bool requiresConfirmation;

  FinancialAssistantPendingAction copyWith({
    FinancialAssistantActionType? type,
    String? title,
    String? summary,
    Map<String, Object?>? data,
    bool? destructive,
    bool? requiresConfirmation,
  }) {
    return FinancialAssistantPendingAction(
      type: type ?? this.type,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      data: data ?? this.data,
      destructive: destructive ?? this.destructive,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
    );
  }
}

class FinancialAssistantReply {
  const FinancialAssistantReply({
    required this.message,
    required this.context,
    this.facts = const <FinancialAssistantFact>[],
    this.pendingAction,
  });

  final String message;
  final List<FinancialAssistantFact> facts;
  final FinancialAssistantPendingAction? pendingAction;
  final FinancialAssistantConversationContext context;
}

class FinancialAssistantExecutionResult {
  const FinancialAssistantExecutionResult({
    required this.message,
    this.facts = const <FinancialAssistantFact>[],
    this.undoAction,
  });

  final String message;
  final List<FinancialAssistantFact> facts;
  final FinancialAssistantPendingAction? undoAction;
}

class _AddSpendingQuestion {
  const _AddSpendingQuestion({required this.field, required this.message});

  final String field;
  final String message;
}

class _AddIncomeQuestion {
  const _AddIncomeQuestion({required this.field, required this.message});

  final String field;
  final String message;
}

class _MerchantMemoryMatch {
  const _MerchantMemoryMatch({
    this.category,
    this.bankName,
    this.bankAccountId,
  });

  final String? category;
  final String? bankName;
  final String? bankAccountId;
}

class FinancialAssistantService {
  const FinancialAssistantService();

  static const List<String> quickPrompts = <String>[
    "Today's Budget",
    'Monthly Spending',
    'Add Spending',
    'Add Income',
    'Can I Afford This?',
    'My Banks',
    'Undo Last Action',
    'Budget Status',
    'Upcoming Recurring',
  ];

  List<String> suggestionsForInput(
    String input,
    SpendingProvider provider, {
    FinancialAssistantConversationContext context =
        const FinancialAssistantConversationContext(),
  }) {
    final normalized = _normalize(input);
    final catalog = _buildSuggestionCatalog(provider, context);
    if (normalized.isEmpty) return catalog.take(8).toList();

    final queryTokens = _suggestionTokens(normalized);
    final scored = <MapEntry<String, double>>[];
    for (final suggestion in catalog) {
      final normalizedSuggestion = _normalize(suggestion);
      final suggestionTokens = _suggestionTokens(normalizedSuggestion);
      var score = 0.0;

      if (normalizedSuggestion.contains(normalized)) {
        score += 14;
      }

      for (final token in queryTokens) {
        if (token.isEmpty) continue;
        if (normalizedSuggestion.contains(token)) {
          score += 6;
        }
        for (final suggestionToken in suggestionTokens) {
          if (suggestionToken.startsWith(token) ||
              token.startsWith(suggestionToken)) {
            score += 3;
          } else if (_isLooseTokenMatch(token, suggestionToken)) {
            score += 2;
          }
        }
      }

      if (normalized.startsWith('h') &&
          normalizedSuggestion.startsWith('how')) {
        score += 2;
      }
      if (normalized.contains('budget') &&
          normalizedSuggestion.contains('budget')) {
        score += 4;
      }
      if (normalized.contains('recurring') &&
          normalizedSuggestion.contains('recurring')) {
        score += 4;
      }

      if (score > 0) {
        scored.add(MapEntry<String, double>(suggestion, score));
      }
    }

    scored.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) return byScore;
      return a.key.length.compareTo(b.key.length);
    });

    final ordered = <String>[];
    final seen = <String>{};
    for (final item in scored) {
      if (seen.add(item.key)) {
        ordered.add(item.key);
      }
      if (ordered.length >= 8) break;
    }
    return ordered;
  }

  List<String> _buildSuggestionCatalog(
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
  ) {
    final suggestions = <String>[
      'How much can I spend today?',
      'How much did I spend today?',
      'How much did I spend yesterday?',
      'How much did I spend this week?',
      'How much did I spend this month?',
      'What did I spend today?',
      'Show my spending from August 1 to August 5.',
      'How much am I over budget?',
      'Am I currently over budget?',
      'How can I recover from my overspending?',
      'How many days until my daily allowance is positive again?',
      "If I don't spend anything tomorrow, how much can I spend the following day?",
      'How much should I reduce my daily spending to stay within budget?',
      'How much money should I keep for upcoming payments?',
      'How much will I have left after recurring payments?',
      'What recurring payments do I have left this month?',
      'Can I afford 100 SAR today?',
      'Can I spend 100 SAR today?',
      'Can I pay 100 SAR today?',
      'What happens if I spend 150 SAR today?',
      'Which category did I spend the most on this month?',
      'Compare this month with last month.',
      'Generate a spending summary.',
      'Show my banks.',
      'What is my total bank balance?',
      'Open the spending report export options.',
      'Add spending',
      'Add income',
      'Undo my last action',
    ];

    for (final category in provider.getAllUsedCategories().take(5)) {
      suggestions.add('How much did I spend on $category this month?');
      suggestions.add('How much did I spend on $category yesterday?');
    }

    for (final bank in provider.bankAccounts.take(4)) {
      suggestions.add('How much did I spend using ${bank.name} this week?');
      suggestions.add('Show my spending using ${bank.name} this month.');
    }

    if (provider.getUpcomingRecurringPayments().isNotEmpty) {
      suggestions.add('What bills are coming up?');
      suggestions.add('How much can I safely spend after recurring payments?');
    }

    if (context.lastQueryKind == _AssistantQueryKind.affordability) {
      suggestions.addAll(<String>['What about 150?', 'What about 200?']);
    }
    if (context.lastQueryKind == _AssistantQueryKind.spendingHistory) {
      suggestions.addAll(<String>[
        'What about last month?',
        'What about this week?',
      ]);
    }

    final unique = <String>{};
    return suggestions.where(unique.add).toList();
  }

  List<String> _suggestionTokens(String text) {
    return text
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  bool _isLooseTokenMatch(String query, String candidate) {
    if (query.length < 2 || candidate.length < 2) return false;
    if (query == candidate) return true;
    if ((query.length - candidate.length).abs() > 2) return false;

    var qi = 0;
    var ci = 0;
    var matches = 0;
    while (qi < query.length && ci < candidate.length) {
      if (query[qi] == candidate[ci]) {
        matches++;
        qi++;
      }
      ci++;
    }
    return matches >= query.length - 1;
  }

  Map<String, Object?> encodeConversationContext(
    FinancialAssistantConversationContext context,
  ) {
    return <String, Object?>{
      'lastCategory': context.lastCategory,
      'lastBankName': context.lastBankName,
      'lastPendingAction': context.lastPendingAction == null
          ? null
          : encodePendingAction(context.lastPendingAction!),
      'lastSpendingSelection': context.lastSpendingSelection == null
          ? null
          : _encodeSpendingSelection(context.lastSpendingSelection!),
      'lastUndoAction': context.lastUndoAction == null
          ? null
          : encodePendingAction(context.lastUndoAction!),
      'lastIncomeSource': context.lastIncomeSource,
      'lastRecurringPaymentId': context.lastRecurringPaymentId,
      'lastRecurringPaymentTitle': context.lastRecurringPaymentTitle,
      'lastQueryKind': context.lastQueryKind?.name,
      'lastQueryStart': context.lastQueryStart?.toIso8601String(),
      'lastQueryEnd': context.lastQueryEnd?.toIso8601String(),
      'lastQueryLabel': context.lastQueryLabel,
      'lastRequestedAmount': context.lastRequestedAmount,
    };
  }

  FinancialAssistantConversationContext decodeConversationContext(
    Map<String, dynamic> raw,
  ) {
    _AssistantQueryKind? queryKind;
    final queryKindName = raw['lastQueryKind'] as String?;
    if (queryKindName != null) {
      for (final value in _AssistantQueryKind.values) {
        if (value.name == queryKindName) {
          queryKind = value;
          break;
        }
      }
    }

    return FinancialAssistantConversationContext(
      lastCategory: raw['lastCategory'] as String?,
      lastBankName: raw['lastBankName'] as String?,
      lastPendingAction: raw['lastPendingAction'] is Map<String, dynamic>
          ? decodePendingAction(
              raw['lastPendingAction'] as Map<String, dynamic>,
            )
          : raw['lastPendingAction'] is Map
          ? decodePendingAction(
              Map<String, dynamic>.from(raw['lastPendingAction'] as Map),
            )
          : null,
      lastSpendingSelection:
          raw['lastSpendingSelection'] is Map<String, dynamic>
          ? _decodeSpendingSelection(
              raw['lastSpendingSelection'] as Map<String, dynamic>,
            )
          : raw['lastSpendingSelection'] is Map
          ? _decodeSpendingSelection(
              Map<String, dynamic>.from(raw['lastSpendingSelection'] as Map),
            )
          : null,
      lastUndoAction: raw['lastUndoAction'] is Map<String, dynamic>
          ? decodePendingAction(raw['lastUndoAction'] as Map<String, dynamic>)
          : raw['lastUndoAction'] is Map
          ? decodePendingAction(
              Map<String, dynamic>.from(raw['lastUndoAction'] as Map),
            )
          : null,
      lastIncomeSource: raw['lastIncomeSource'] as String?,
      lastRecurringPaymentId: raw['lastRecurringPaymentId'] as String?,
      lastRecurringPaymentTitle: raw['lastRecurringPaymentTitle'] as String?,
      lastQueryKind: queryKind,
      lastQueryStart: raw['lastQueryStart'] == null
          ? null
          : DateTime.tryParse(raw['lastQueryStart'] as String),
      lastQueryEnd: raw['lastQueryEnd'] == null
          ? null
          : DateTime.tryParse(raw['lastQueryEnd'] as String),
      lastQueryLabel: raw['lastQueryLabel'] as String?,
      lastRequestedAmount: (raw['lastRequestedAmount'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> encodePendingAction(
    FinancialAssistantPendingAction action,
  ) {
    return <String, Object?>{
      'type': action.type.name,
      'title': action.title,
      'summary': action.summary,
      'data': _encodeDynamic(action.data),
      'destructive': action.destructive,
      'requiresConfirmation': action.requiresConfirmation,
    };
  }

  FinancialAssistantPendingAction decodePendingAction(
    Map<String, dynamic> raw,
  ) {
    final typeName =
        raw['type'] as String? ?? FinancialAssistantActionType.addSpending.name;
    final type = FinancialAssistantActionType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => FinancialAssistantActionType.addSpending,
    );
    return FinancialAssistantPendingAction(
      type: type,
      title: raw['title'] as String? ?? '',
      summary: raw['summary'] as String? ?? '',
      data: Map<String, Object?>.from(_decodeDynamic(raw['data']) as Map),
      destructive: raw['destructive'] as bool? ?? false,
      requiresConfirmation: raw['requiresConfirmation'] as bool? ?? true,
    );
  }

  dynamic _encodeDynamic(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return <String, Object?>{
        '__type': 'dateTime',
        'value': value.toIso8601String(),
      };
    }
    if (value is SpendingEntry) {
      return <String, Object?>{
        '__type': 'spendingEntry',
        'value': value.toJson(),
      };
    }
    if (value is FinancialAssistantSpendingSelection) {
      return <String, Object?>{
        '__type': 'spendingSelection',
        'value': _encodeSpendingSelection(value),
      };
    }
    if (value is FinancialAssistantPendingAction) {
      return <String, Object?>{
        '__type': 'pendingAction',
        'value': encodePendingAction(value),
      };
    }
    if (value is List) {
      return value.map(_encodeDynamic).toList();
    }
    if (value is Map) {
      return value.map(
        (key, entryValue) =>
            MapEntry(key.toString(), _encodeDynamic(entryValue)),
      );
    }
    return value.toString();
  }

  dynamic _decodeDynamic(dynamic value) {
    if (value is List) {
      return value.map(_decodeDynamic).toList();
    }
    if (value is! Map) return value;

    final map = Map<String, dynamic>.from(value);
    final type = map['__type'] as String?;
    if (type == 'dateTime') {
      return DateTime.tryParse(map['value'] as String? ?? '');
    }
    if (type == 'spendingEntry') {
      return SpendingEntry.fromJson(
        Map<String, dynamic>.from(map['value'] as Map),
      );
    }
    if (type == 'spendingSelection') {
      return _decodeSpendingSelection(
        Map<String, dynamic>.from(map['value'] as Map),
      );
    }
    if (type == 'pendingAction') {
      return decodePendingAction(
        Map<String, dynamic>.from(map['value'] as Map),
      );
    }

    return map.map(
      (key, entryValue) => MapEntry(key, _decodeDynamic(entryValue)),
    );
  }

  Map<String, Object?> _encodeSpendingSelection(
    FinancialAssistantSpendingSelection selection,
  ) {
    return <String, Object?>{
      'date': selection.date.toIso8601String(),
      'index': selection.index,
      'entry': selection.entry.toJson(),
    };
  }

  FinancialAssistantSpendingSelection _decodeSpendingSelection(
    Map<String, dynamic> raw,
  ) {
    return FinancialAssistantSpendingSelection(
      date: DateTime.parse(raw['date'] as String),
      index: (raw['index'] as num?)?.toInt() ?? 0,
      entry: SpendingEntry.fromJson(
        Map<String, dynamic>.from(raw['entry'] as Map),
      ),
    );
  }

  FinancialAssistantReply handleMessage(
    String rawMessage,
    SpendingProvider provider, {
    FinancialAssistantConversationContext context =
        const FinancialAssistantConversationContext(),
  }) {
    final message = rawMessage.trim();
    final normalized = _normalize(message);
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final budgetGuidance = provider.getBudgetGuidanceSnapshotForDate(now);

    if (normalized.isEmpty) {
      return FinancialAssistantReply(
        message:
            'Ask me about your budget, spending, banks, recurring payments, or tell me to add, edit, or delete something.',
        context: context,
      );
    }

    final followUpReply = _tryHandlePendingActionFollowUp(
      normalized,
      provider,
      context,
    );
    if (followUpReply != null) {
      return followUpReply;
    }

    if (_looksLikeExportRequest(normalized)) {
      return _replyWithAction(
        message:
            'I can open the existing export flow for you. Choose open below to continue.',
        context: context,
        action: const FinancialAssistantPendingAction(
          type: FinancialAssistantActionType.openExportOptions,
          title: 'Open export options',
          summary: 'Open the existing PDF and CSV export sheet.',
          data: <String, Object?>{},
          requiresConfirmation: false,
        ),
      );
    }

    final undoAction = _tryBuildUndoReply(normalized, context);
    if (undoAction != null) {
      return undoAction;
    }

    final editSpendingAction = _tryParseEditSpending(
      normalized,
      provider,
      context,
      now,
    );
    if (editSpendingAction != null) {
      final selectionOptions =
          editSpendingAction.data['selectionOptions']
              as List<FinancialAssistantSpendingSelection>?;
      if (selectionOptions != null && selectionOptions.isNotEmpty) {
        return FinancialAssistantReply(
          message: _buildSelectionOptionsMessage(
            selectionOptions,
            actionLabel: 'edit',
          ),
          context: context.copyWith(lastPendingAction: editSpendingAction),
        );
      }
      return _replyWithAction(
        message: 'I found a spending edit request.',
        context: context.copyWith(
          lastPendingAction: editSpendingAction,
          lastSpendingSelection:
              editSpendingAction.data['selection']
                  as FinancialAssistantSpendingSelection?,
          lastCategory: editSpendingAction.data['category'] as String?,
          lastBankName: editSpendingAction.data['bankName'] as String?,
        ),
        action: editSpendingAction,
      );
    }

    final deleteSpendingAction = _tryParseDeleteSpending(
      normalized,
      provider,
      context,
      now,
    );
    if (deleteSpendingAction != null) {
      final selectionOptions =
          deleteSpendingAction.data['selectionOptions']
              as List<FinancialAssistantSpendingSelection>?;
      if (selectionOptions != null && selectionOptions.isNotEmpty) {
        return FinancialAssistantReply(
          message: _buildSelectionOptionsMessage(
            selectionOptions,
            actionLabel: 'delete',
          ),
          context: context.copyWith(lastPendingAction: deleteSpendingAction),
        );
      }
      return _replyWithAction(
        message:
            'Deleting a spending is a sensitive action, so I need your confirmation first.',
        context: context.copyWith(
          lastPendingAction: deleteSpendingAction,
          lastSpendingSelection:
              deleteSpendingAction.data['selection']
                  as FinancialAssistantSpendingSelection?,
        ),
        action: deleteSpendingAction,
      );
    }

    final addIncomeAction = _tryParseAddIncome(
      normalized,
      provider,
      context,
      now,
    );
    if (addIncomeAction != null) {
      final nextQuestion = _nextAddIncomeQuestion(addIncomeAction.data);
      if (nextQuestion != null) {
        return FinancialAssistantReply(
          message: nextQuestion.message,
          context: context.copyWith(
            lastPendingAction: addIncomeAction.copyWith(
              data: <String, Object?>{
                ...addIncomeAction.data,
                'expectedField': nextQuestion.field,
              },
            ),
            lastIncomeSource: addIncomeAction.data['source'] as String?,
          ),
        );
      }

      return _replyWithAction(
        message: 'I have everything I need. Please confirm the income entry.',
        context: context.copyWith(
          lastPendingAction: addIncomeAction,
          lastIncomeSource: addIncomeAction.data['source'] as String?,
        ),
        action: addIncomeAction,
      );
    }

    final addBankAction = _tryParseAddBank(normalized, message, provider);
    if (addBankAction != null) {
      return _replyWithAction(
        message: 'I understood this as a new bank account.',
        context: context.copyWith(
          lastPendingAction: addBankAction,
          lastBankName: addBankAction.data['name'] as String?,
        ),
        action: addBankAction,
      );
    }

    final updateBankBalanceAction = _tryParseUpdateBankBalance(
      normalized,
      provider,
    );
    if (updateBankBalanceAction != null) {
      return _replyWithAction(
        message: 'I found a bank balance update request.',
        context: context.copyWith(
          lastPendingAction: updateBankBalanceAction,
          lastBankName: updateBankBalanceAction.data['name'] as String?,
        ),
        action: updateBankBalanceAction,
      );
    }

    final renameBankAction = _tryParseRenameBank(normalized, provider);
    if (renameBankAction != null) {
      return _replyWithAction(
        message: 'I found a bank rename request.',
        context: context.copyWith(
          lastPendingAction: renameBankAction,
          lastBankName: renameBankAction.data['newName'] as String?,
        ),
        action: renameBankAction,
      );
    }

    final removeBankAction = _tryParseRemoveBank(normalized, provider, context);
    if (removeBankAction != null) {
      return _replyWithAction(
        message:
            'Deleting a bank is a sensitive action, so I need your confirmation first.',
        context: context.copyWith(lastPendingAction: removeBankAction),
        action: removeBankAction,
      );
    }

    final addRecurringAction = _tryParseAddRecurringPayment(
      normalized,
      message,
      provider,
    );
    if (addRecurringAction != null) {
      return _replyWithAction(
        message: 'I understood this as a new recurring payment.',
        context: context.copyWith(
          lastPendingAction: addRecurringAction,
          lastCategory: addRecurringAction.data['category'] as String?,
          lastBankName: addRecurringAction.data['bankName'] as String?,
        ),
        action: addRecurringAction,
      );
    }

    final updateRecurringAction = _tryParseUpdateRecurringPayment(
      normalized,
      provider,
      context,
    );
    if (updateRecurringAction != null) {
      return _replyWithAction(
        message: 'I found a recurring payment update request.',
        context: context.copyWith(
          lastPendingAction: updateRecurringAction,
          lastRecurringPaymentId: updateRecurringAction.data['id'] as String?,
          lastRecurringPaymentTitle:
              updateRecurringAction.data['title'] as String?,
          lastCategory: updateRecurringAction.data['category'] as String?,
          lastBankName: updateRecurringAction.data['bankName'] as String?,
        ),
        action: updateRecurringAction,
      );
    }

    final removeRecurringAction = _tryParseRemoveRecurringPayment(
      normalized,
      provider,
      context,
    );
    if (removeRecurringAction != null) {
      return _replyWithAction(
        message:
            'Deleting a recurring payment is destructive, so I need your confirmation first.',
        context: context.copyWith(
          lastPendingAction: removeRecurringAction,
          lastRecurringPaymentId: removeRecurringAction.data['id'] as String?,
          lastRecurringPaymentTitle:
              removeRecurringAction.data['title'] as String?,
        ),
        action: removeRecurringAction,
      );
    }

    final addSpendingAction = _tryParseAddSpending(
      normalized,
      provider,
      context,
      now,
    );
    if (addSpendingAction != null) {
      final nextQuestion = _nextAddSpendingQuestion(
        addSpendingAction.data,
        provider,
      );
      if (nextQuestion != null) {
        return FinancialAssistantReply(
          message: nextQuestion.message,
          context: context.copyWith(
            lastPendingAction: addSpendingAction.copyWith(
              data: <String, Object?>{
                ...addSpendingAction.data,
                'expectedField': nextQuestion.field,
              },
            ),
            lastCategory: addSpendingAction.data['category'] as String?,
            lastBankName: addSpendingAction.data['bankName'] as String?,
          ),
        );
      }
      return _replyWithAction(
        message: 'I interpreted this as a new spending entry.',
        context: context.copyWith(
          lastPendingAction: addSpendingAction,
          lastCategory: addSpendingAction.data['category'] as String?,
          lastBankName: addSpendingAction.data['bankName'] as String?,
        ),
        action: addSpendingAction,
      );
    }

    final naturalReadOnlyReply = _tryHandleFlexibleReadOnlyQuery(
      normalized,
      provider,
      context,
      now,
      budgetGuidance,
    );
    if (naturalReadOnlyReply != null) {
      return naturalReadOnlyReply;
    }

    if (_matchesAny(normalized, const <String>[
      'show my banks',
      'my banks',
      'list banks',
      'show banks',
    ])) {
      if (provider.bankAccounts.isEmpty) {
        return FinancialAssistantReply(
          message: 'You do not have any saved bank accounts yet.',
          context: context,
        );
      }

      return FinancialAssistantReply(
        message: 'Here are your saved bank accounts.',
        facts: provider.bankAccounts
            .map(
              (account) => FinancialAssistantFact(
                label: account.name,
                value: '${account.balance.toStringAsFixed(2)} SAR',
              ),
            )
            .toList(),
        context: context,
      );
    }

    if (_matchesAny(normalized, const <String>[
      'total balance',
      'bank total',
      'sum of my banks',
    ])) {
      return FinancialAssistantReply(
        message: 'This is the total across your saved bank accounts.',
        facts: <FinancialAssistantFact>[
          FinancialAssistantFact(
            label: 'Total balance',
            value: '${provider.totalBankBalance.toStringAsFixed(2)} SAR',
            note: '${provider.bankAccounts.length} bank account(s)',
          ),
        ],
        context: context,
      );
    }

    if (_matchesAny(normalized, const <String>[
      'what recurring payments do i have left this month',
      'what recurring payments are left this month',
      'what bills are coming up',
      'what bills do i have coming up',
      'bills are coming up',
      'upcoming bills',
      'how much money should i keep for upcoming payments',
      'how much should i keep for upcoming payments',
      'how much will i have left after my recurring payments',
      'how much will i have left after recurring payments',
      'how much can i safely spend until the end of the month',
      'how much can i safely spend until the end of the period',
      'safe to spend until the end of the month',
      'safe to spend until the end of the period',
    ])) {
      return _buildRecurringCommitmentReply(
        guidance: budgetGuidance,
        context: context,
      );
    }

    if (_matchesAny(normalized, const <String>[
      'show recurring payments',
      'recurring payments',
      'list recurring payments',
      'upcoming recurring payments',
      'upcoming recurring',
    ])) {
      final upcoming = provider.getUpcomingRecurringPayments();
      if (upcoming.isEmpty && provider.recurringPayments.isEmpty) {
        return FinancialAssistantReply(
          message: 'You do not have any recurring payments yet.',
          context: context.copyWith(clearRecurring: true),
        );
      }

      final payments = upcoming.isNotEmpty
          ? upcoming
          : provider.recurringPayments.take(5).toList();
      final first = payments.isEmpty ? null : payments.first;
      return FinancialAssistantReply(
        message: upcoming.isNotEmpty
            ? 'These recurring payments are coming up soon.'
            : 'Here are your saved recurring payments.',
        facts: payments
            .map(
              (payment) => FinancialAssistantFact(
                label: payment.title,
                value: '${payment.amount.toStringAsFixed(2)} SAR',
                note:
                    'Due ${DateFormat('yyyy-MM-dd').format(provider.getNextDueDate(payment))}',
              ),
            )
            .toList(),
        context: context.copyWith(
          lastRecurringPaymentId: first?.id,
          lastRecurringPaymentTitle: first?.title,
          lastCategory: first?.category,
          lastBankName: first?.bank,
        ),
      );
    }

    if (_matchesAny(normalized, const <String>[
      'how can i recover from my overspending',
      'how can i recover from overspending',
      'recover from my overspending',
      'recover from overspending',
      'how many days will it take until i have a positive daily allowance again',
      'how many days until i have a positive daily allowance again',
      'how many days until my daily allowance is positive again',
      "if i don't spend anything tomorrow, how much can i spend the following day",
      "if i dont spend anything tomorrow how much can i spend the following day",
      'how much should i reduce my daily spending to stay within budget',
      'reduce my daily spending to stay within budget',
    ])) {
      return _buildRecoveryReply(
        normalized,
        guidance: budgetGuidance,
        context: context,
      );
    }

    if ((_matchesAny(normalized, const <String>[
              'can i afford',
              'can i spend',
            ]) &&
            normalized.contains('today')) ||
        normalized.contains('afford')) {
      final amount = _parseFirstAmount(normalized);
      if (amount != null) {
        return _buildAffordabilityReply(
          amount: amount,
          guidance: budgetGuidance,
          context: context,
        );
      }
    }

    if (_matchesAny(normalized, const <String>[
      'how much budget do i have left',
      'budget left',
      'remaining budget',
      'how much am i over budget',
    ])) {
      return _buildRemainingBudgetReply(
        guidance: budgetGuidance,
        context: context,
      );
    }

    if (_matchesAny(normalized, const <String>[
      'how much can i spend today',
      "today's budget",
      'daily allowance',
      'spend today',
    ])) {
      return _buildTodayAllowanceReply(
        guidance: budgetGuidance,
        context: context,
      );
    }

    if (_matchesAny(normalized, const <String>[
      'how much did i spend this month',
      'monthly spending',
      'spent this month',
    ])) {
      return FinancialAssistantReply(
        message: 'This is your spending total for the active budget period.',
        facts: <FinancialAssistantFact>[
          FinancialAssistantFact(
            label: 'Spent this period',
            value: '${provider.periodTotal.toStringAsFixed(2)} SAR',
            note: 'Budget: ${provider.monthlyBudget.toStringAsFixed(2)} SAR',
          ),
        ],
        context: context,
      );
    }

    if (_matchesAny(normalized, const <String>[
      'which category did i spend the most on',
      'top category',
      'highest category',
      'most on',
    ])) {
      final totals = provider.getCategoryTotalsForPeriod();
      if (totals.isEmpty) {
        return FinancialAssistantReply(
          message:
              'There are no categorized spendings in the current period yet.',
          context: context.copyWith(clearCategory: true),
        );
      }
      final top = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return FinancialAssistantReply(
        message:
            'This is your highest spending category for the current period.',
        facts: <FinancialAssistantFact>[
          FinancialAssistantFact(
            label: top.key,
            value: '${top.value.toStringAsFixed(2)} SAR',
          ),
        ],
        context: context.copyWith(lastCategory: top.key),
      );
    }

    if (_matchesAny(normalized, const <String>[
      'am i currently over budget',
      'over budget',
      'budget status',
      'ahead of or behind my budget',
    ])) {
      return _buildBudgetStatusReply(
        guidance: budgetGuidance,
        context: context,
      );
    }

    if (_matchesAny(normalized, const <String>[
      'highest spending day',
      'biggest spending day',
    ])) {
      final highest = _findHighestSpendingDay(provider);
      if (highest == null) {
        return FinancialAssistantReply(
          message: 'There is no spending data in the current period yet.',
          context: context,
        );
      }
      return FinancialAssistantReply(
        message: 'This day had the highest spending in the current period.',
        facts: <FinancialAssistantFact>[
          FinancialAssistantFact(
            label: DateFormat('yyyy-MM-dd').format(highest.key),
            value: '${highest.value.toStringAsFixed(2)} SAR',
          ),
        ],
        context: context,
      );
    }

    if (_matchesAny(normalized, const <String>[
      'compare this month with last month',
      'compare this month and last month',
    ])) {
      final thisMonthTotal = _sumForMonth(provider, now.year, now.month);
      final lastMonthTotal = _sumForMonth(
        provider,
        lastMonth.year,
        lastMonth.month,
      );
      final diff = thisMonthTotal - lastMonthTotal;
      return FinancialAssistantReply(
        message: diff >= 0
            ? 'You spent more this month than last month.'
            : 'You spent less this month than last month.',
        facts: <FinancialAssistantFact>[
          FinancialAssistantFact(
            label: 'This month',
            value: '${thisMonthTotal.toStringAsFixed(2)} SAR',
          ),
          FinancialAssistantFact(
            label: 'Last month',
            value: '${lastMonthTotal.toStringAsFixed(2)} SAR',
          ),
          FinancialAssistantFact(
            label: 'Difference',
            value: '${diff.abs().toStringAsFixed(2)} SAR',
            note: diff >= 0 ? 'Higher this month' : 'Lower this month',
          ),
        ],
        context: context,
      );
    }

    final category =
        _resolveCategory(provider, normalized) ?? context.lastCategory;
    if (category != null &&
        (_matchesAny(normalized, const <String>[
              'how much did i spend on',
              'spending for',
            ]) ||
            (normalized.contains('last month') &&
                context.lastCategory != null))) {
      final useLastMonth = normalized.contains('last month');
      final total = useLastMonth
          ? _sumForMonth(
              provider,
              lastMonth.year,
              lastMonth.month,
              category: category,
            )
          : _sumForPeriod(provider, category: category);
      return FinancialAssistantReply(
        message: useLastMonth
            ? 'Here is your spending for that category last month.'
            : 'Here is your spending for that category in the current period.',
        facts: <FinancialAssistantFact>[
          FinancialAssistantFact(
            label: category,
            value: '${total.toStringAsFixed(2)} SAR',
            note: useLastMonth ? 'Last month' : 'Current period',
          ),
        ],
        context: context.copyWith(lastCategory: category),
      );
    }

    final specificDate = _extractSpecificDate(normalized, now);
    if (specificDate != null &&
        _matchesAny(normalized, const <String>[
          'show my spending',
          'how much did i spend',
          'spent on',
          'spending for',
        ])) {
      final total = provider.getSpendingForDate(specificDate);
      final entries = provider.getEntriesForDate(specificDate);
      final selection = entries.isNotEmpty
          ? FinancialAssistantSpendingSelection(
              date: specificDate,
              index: entries.length - 1,
              entry: entries.last,
            )
          : null;
      return FinancialAssistantReply(
        message: 'Here is your spending for that date.',
        facts: <FinancialAssistantFact>[
          FinancialAssistantFact(
            label: DateFormat('yyyy-MM-dd').format(specificDate),
            value: '${total.toStringAsFixed(2)} SAR',
            note: '${entries.length} entr${entries.length == 1 ? 'y' : 'ies'}',
          ),
        ],
        context: context.copyWith(lastSpendingSelection: selection),
      );
    }

    if (_matchesAny(normalized, const <String>[
      'explain why my available daily budget increased',
      'explain why my available daily budget decreased',
      'why did my daily budget change',
      'why did my available budget change',
    ])) {
      final adjustment = provider.getDailyBudgetAdjustmentForDate(now);
      if (adjustment == null) {
        return FinancialAssistantReply(
          message:
              'I can explain daily budget adjustments after the first tracked day in the active budget period.',
          context: context,
        );
      }
      final delta = adjustment.currentAllowance - adjustment.previousAllowance;
      return FinancialAssistantReply(
        message: delta >= 0
            ? 'Your available daily budget increased because you spent less than the previous day allowed.'
            : 'Your available daily budget decreased because you spent more than the previous day allowed.',
        facts: <FinancialAssistantFact>[
          FinancialAssistantFact(
            label: 'Previous allowance',
            value: '${adjustment.previousAllowance.toStringAsFixed(2)} SAR',
          ),
          FinancialAssistantFact(
            label: 'Previous spent',
            value: '${adjustment.previousSpent.toStringAsFixed(2)} SAR',
          ),
          FinancialAssistantFact(
            label: 'Current allowance',
            value: '${adjustment.currentAllowance.toStringAsFixed(2)} SAR',
          ),
        ],
        context: context,
      );
    }

    if (_matchesAny(normalized, const <String>[
      'generate a spending summary',
      'spending summary',
      'summary',
    ])) {
      final totals = provider.getCategoryTotalsForPeriod();
      final topCategory = totals.isEmpty
          ? null
          : totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return FinancialAssistantReply(
        message: 'Here is a quick summary of your current financial position.',
        facts: <FinancialAssistantFact>[
          FinancialAssistantFact(
            label: 'Budget',
            value: '${provider.monthlyBudget.toStringAsFixed(2)} SAR',
          ),
          FinancialAssistantFact(
            label: 'Spent',
            value: '${provider.periodTotal.toStringAsFixed(2)} SAR',
          ),
          FinancialAssistantFact(
            label: 'Today available',
            value:
                '${provider.getDailyAllowanceForDate(now).toStringAsFixed(2)} SAR',
          ),
          if (topCategory != null)
            FinancialAssistantFact(
              label: 'Top category',
              value: topCategory.key,
              note: '${topCategory.value.toStringAsFixed(2)} SAR',
            ),
        ],
        context: context.copyWith(lastCategory: topCategory?.key),
      );
    }

    return FinancialAssistantReply(
      message:
          "I couldn't confidently understand that yet. Try something like 'Change yesterday's Uber to 18 SAR', 'Delete the metro ticket from today', 'Add income 2500 SAR from salary', 'Undo my last action', or 'Use SNB instead.'",
      context: context,
    );
  }

  Future<FinancialAssistantExecutionResult> executeAction(
    FinancialAssistantPendingAction action,
    SpendingProvider provider,
  ) async {
    switch (action.type) {
      case FinancialAssistantActionType.addSpending:
        final date = action.data['date'] as DateTime;
        final amount = action.data['amount'] as double;
        final category = action.data['category'] as String?;
        final bankName = action.data['bankName'] as String?;
        final bankAccountId = action.data['bankAccountId'] as String?;
        final item = action.data['item'] as String?;
        final qty = action.data['qty'] as int?;
        await provider.addSpendingForDate(
          date,
          amount,
          item: item,
          category: category,
          bank: bankName,
          bankAccountId: bankAccountId,
          qty: qty,
        );
        final addedEntries = provider.getEntriesForDate(date);
        final addedIndex = addedEntries.isEmpty ? -1 : addedEntries.length - 1;
        return FinancialAssistantExecutionResult(
          message: 'The spending was added successfully.',
          facts: _buildSpendingFacts(
            date: date,
            amount: amount,
            category: category,
            bankName: bankName,
            item: item,
            qty: qty,
          ),
          undoAction: addedIndex < 0
              ? null
              : _buildUndoAction(
                  _buildDeleteSpendingAction(
                    FinancialAssistantSpendingSelection(
                      date: date,
                      index: addedIndex,
                      entry: addedEntries[addedIndex],
                    ),
                  ),
                  'Undo add spending',
                ),
        );
      case FinancialAssistantActionType.addIncome:
        final date = action.data['date'] as DateTime;
        final amount = action.data['amount'] as double;
        final source = action.data['source'] as String?;
        final note = action.data['note'] as String?;
        await provider.addIncomeForDate(
          date,
          amount,
          source: source,
          note: note,
        );
        final entries = provider.getIncomeEntriesForDate(date);
        final addedIndex = entries.isEmpty ? -1 : entries.length - 1;
        return FinancialAssistantExecutionResult(
          message: 'The income entry was added successfully.',
          facts: _buildIncomeFacts(
            date: date,
            amount: amount,
            source: source,
            note: note,
          ),
          undoAction: addedIndex < 0
              ? null
              : _buildUndoAction(
                  FinancialAssistantPendingAction(
                    type: FinancialAssistantActionType.undoLastAction,
                    title: 'Remove income entry',
                    summary:
                        'Remove ${amount.toStringAsFixed(2)} SAR income from ${DateFormat('yyyy-MM-dd').format(date)}',
                    data: <String, Object?>{
                      'undoKind': 'removeIncomeEntry',
                      'date': date,
                      'index': addedIndex,
                    },
                  ),
                  'Undo add income',
                ),
        );
      case FinancialAssistantActionType.editSpending:
        final selection =
            action.data['selection'] as FinancialAssistantSpendingSelection;
        final date = action.data['date'] as DateTime;
        final amount = action.data['amount'] as double;
        final category = action.data['category'] as String?;
        final bankName = action.data['bankName'] as String?;
        final bankAccountId = action.data['bankAccountId'] as String?;
        final item = action.data['item'] as String?;
        final qty = action.data['qty'] as int?;
        await provider.saveEditedEntryForDate(
          originalDate: selection.date,
          newDate: date,
          index: selection.index,
          amount: amount,
          item: item,
          category: category,
          bank: bankName,
          bankAccountId: bankAccountId,
          qty: qty,
        );
        final editedEntries = provider.getEntriesForDate(date);
        final editedIndex = selection.date == date
            ? selection.index
            : editedEntries.length - 1;
        return FinancialAssistantExecutionResult(
          message: 'The spending entry was updated successfully.',
          facts: _buildSpendingFacts(
            date: date,
            amount: amount,
            category: category,
            bankName: bankName,
            item: item,
            qty: qty,
          ),
          undoAction: editedIndex < 0 || editedIndex >= editedEntries.length
              ? null
              : _buildUndoAction(
                  _buildEditSpendingAction(
                    selection: FinancialAssistantSpendingSelection(
                      date: date,
                      index: editedIndex,
                      entry: editedEntries[editedIndex],
                    ),
                    amount:
                        selection.entry.amount /
                        ((selection.entry.qty == null ||
                                selection.entry.qty! <= 0)
                            ? 1
                            : selection.entry.qty!),
                    date: selection.date,
                    category: selection.entry.category,
                    bankName: selection.entry.bank,
                    bankAccountId: selection.entry.bankAccountId,
                    item: selection.entry.item,
                    qty: selection.entry.qty,
                  ),
                  'Undo edit spending',
                ),
        );
      case FinancialAssistantActionType.mergeDuplicateSpendingQuantity:
        final duplicateDate = action.data['duplicateDate'] as DateTime;
        final duplicateIndex = action.data['duplicateIndex'] as int;
        final existingEntries = provider.getEntriesForDate(duplicateDate);
        if (duplicateIndex < 0 || duplicateIndex >= existingEntries.length) {
          return const FinancialAssistantExecutionResult(
            message:
                'I could not find the original spending entry to increase its quantity.',
          );
        }
        final existingEntry = existingEntries[duplicateIndex];
        final previousSelection = FinancialAssistantSpendingSelection(
          date: duplicateDate,
          index: duplicateIndex,
          entry: existingEntry,
        );
        final addedQty = _effectiveAssistantQty(action.data['qty'] as int?);
        final mergedQty = (existingEntry.qty ?? 1) + addedQty;
        final mergedUnitAmount = action.data['amount'] as double;
        await provider.updateEntryForDate(
          date: duplicateDate,
          index: duplicateIndex,
          amount: mergedUnitAmount,
          item: existingEntry.item,
          bank: existingEntry.bank,
          bankAccountId: existingEntry.bankAccountId,
          qty: mergedQty,
          category: existingEntry.category,
        );
        return FinancialAssistantExecutionResult(
          message:
              'I increased the quantity on the existing spending entry instead of adding a duplicate.',
          facts: _buildSpendingFacts(
            date: duplicateDate,
            amount: mergedUnitAmount,
            category: existingEntry.category,
            bankName: existingEntry.bank,
            item: existingEntry.item,
            qty: mergedQty,
          ),
          undoAction: _buildUndoAction(
            _buildEditSpendingAction(
              selection: FinancialAssistantSpendingSelection(
                date: duplicateDate,
                index: duplicateIndex,
                entry: provider.getEntriesForDate(
                  duplicateDate,
                )[duplicateIndex],
              ),
              amount:
                  existingEntry.amount /
                  ((existingEntry.qty == null || existingEntry.qty! <= 0)
                      ? 1
                      : existingEntry.qty!),
              date: duplicateDate,
              category: existingEntry.category,
              bankName: existingEntry.bank,
              bankAccountId: existingEntry.bankAccountId,
              item: existingEntry.item,
              qty: existingEntry.qty,
            ),
            'Undo quantity increase',
          ),
        );
      case FinancialAssistantActionType.deleteSpending:
        final selection =
            action.data['selection'] as FinancialAssistantSpendingSelection;
        await provider.removeEntryForDate(
          date: selection.date,
          index: selection.index,
        );
        return FinancialAssistantExecutionResult(
          message: 'The spending entry was deleted successfully.',
          facts: <FinancialAssistantFact>[
            FinancialAssistantFact(
              label: 'Deleted',
              value:
                  '${selection.entry.item ?? selection.entry.category ?? 'Spending'} • ${selection.entry.amount.toStringAsFixed(2)} SAR',
              note: DateFormat('yyyy-MM-dd').format(selection.date),
            ),
          ],
          undoAction: _buildUndoAction(
            _buildAddSpendingAction(
              amount:
                  selection.entry.amount /
                  ((selection.entry.qty == null || selection.entry.qty! <= 0)
                      ? 1
                      : selection.entry.qty!),
              date: selection.date,
              category: selection.entry.category,
              bankName: selection.entry.bank,
              bankAccountId: selection.entry.bankAccountId,
              item: selection.entry.item,
              qty: selection.entry.qty,
            ),
            'Undo delete spending',
          ),
        );
      case FinancialAssistantActionType.addBank:
        final name = action.data['name'] as String;
        final balance = action.data['balance'] as double;
        if (provider.findBankAccountId(bankName: name) != null) {
          return const FinancialAssistantExecutionResult(
            message: 'A bank with that name already exists.',
          );
        }
        await provider.setBankAccounts(<BankAccount>[
          ...provider.bankAccounts,
          BankAccount(
            id:
                (action.data['bankAccountId'] as String?) ??
                BankAccount.newId(),
            name: name,
            balance: balance,
          ),
        ]);
        return FinancialAssistantExecutionResult(
          message: 'The bank account was added successfully.',
          facts: <FinancialAssistantFact>[
            FinancialAssistantFact(
              label: name,
              value: '${balance.toStringAsFixed(2)} SAR',
            ),
          ],
          undoAction: _buildUndoAction(
            FinancialAssistantPendingAction(
              type: FinancialAssistantActionType.removeBank,
              title: 'Remove bank',
              summary: 'Remove $name from the saved bank list',
              data: <String, Object?>{
                'bankAccountId': provider.findBankAccountId(bankName: name),
                'name': name,
              },
              destructive: true,
            ),
            'Undo add bank',
          ),
        );
      case FinancialAssistantActionType.updateBankBalance:
        final id = action.data['bankAccountId'] as String;
        final updatedBalance = action.data['balance'] as double;
        final previousAccount = provider.bankAccounts.firstWhere(
          (account) => account.id == id,
        );
        final updatedAccounts = provider.bankAccounts
            .map(
              (account) => account.id == id
                  ? account.copyWith(balance: updatedBalance)
                  : account,
            )
            .toList();
        await provider.setBankAccounts(updatedAccounts);
        return FinancialAssistantExecutionResult(
          message: 'The bank balance was updated.',
          facts: <FinancialAssistantFact>[
            FinancialAssistantFact(
              label: action.data['name'] as String,
              value: '${updatedBalance.toStringAsFixed(2)} SAR',
            ),
          ],
          undoAction: _buildUndoAction(
            FinancialAssistantPendingAction(
              type: FinancialAssistantActionType.updateBankBalance,
              title: 'Update bank balance',
              summary:
                  'Set ${previousAccount.name} to ${previousAccount.balance.toStringAsFixed(2)} SAR',
              data: <String, Object?>{
                'bankAccountId': previousAccount.id,
                'name': previousAccount.name,
                'balance': previousAccount.balance,
              },
            ),
            'Undo bank balance update',
          ),
        );
      case FinancialAssistantActionType.renameBank:
        final id = action.data['bankAccountId'] as String;
        final oldName = action.data['name'] as String;
        final newName = action.data['newName'] as String;
        if (provider.findBankAccountId(bankName: newName) != null) {
          return const FinancialAssistantExecutionResult(
            message: 'Another bank already uses that name.',
          );
        }
        final updatedAccounts = provider.bankAccounts
            .map(
              (account) =>
                  account.id == id ? account.copyWith(name: newName) : account,
            )
            .toList();
        await provider.setBankAccounts(updatedAccounts);
        return FinancialAssistantExecutionResult(
          message:
              'The bank was renamed. Existing historical entries keep their saved bank label unless you edit them later.',
          facts: <FinancialAssistantFact>[
            FinancialAssistantFact(label: 'Renamed to', value: newName),
          ],
          undoAction: _buildUndoAction(
            FinancialAssistantPendingAction(
              type: FinancialAssistantActionType.renameBank,
              title: 'Rename bank',
              summary: 'Rename $newName to $oldName',
              data: <String, Object?>{
                'bankAccountId': id,
                'name': newName,
                'newName': oldName,
              },
            ),
            'Undo bank rename',
          ),
        );
      case FinancialAssistantActionType.removeBank:
        final id = action.data['bankAccountId'] as String;
        final removedBank = provider.bankAccounts.firstWhere(
          (account) => account.id == id,
        );
        final updatedAccounts = provider.bankAccounts
            .where((account) => account.id != id)
            .toList();
        await provider.setBankAccounts(updatedAccounts);
        return FinancialAssistantExecutionResult(
          message:
              'The bank was removed from your saved bank list. Existing spending records were left untouched.',
          facts: <FinancialAssistantFact>[
            FinancialAssistantFact(
              label: 'Removed bank',
              value: action.data['name'] as String,
            ),
          ],
          undoAction: _buildUndoAction(
            FinancialAssistantPendingAction(
              type: FinancialAssistantActionType.addBank,
              title: 'Add bank account',
              summary:
                  '${removedBank.name} with a starting balance of ${removedBank.balance.toStringAsFixed(2)} SAR',
              data: <String, Object?>{
                'bankAccountId': removedBank.id,
                'name': removedBank.name,
                'balance': removedBank.balance,
              },
            ),
            'Undo remove bank',
          ),
        );
      case FinancialAssistantActionType.addRecurringPayment:
        await provider.addRecurringPayment(
          title: action.data['title'] as String,
          amount: action.data['amount'] as double,
          dayOfMonth: action.data['dayOfMonth'] as int,
          category: action.data['category'] as String?,
          bank: action.data['bankName'] as String?,
          bankAccountId: action.data['bankAccountId'] as String?,
          autoAdd: (action.data['autoAdd'] as bool?) ?? false,
        );
        return FinancialAssistantExecutionResult(
          message: 'The recurring payment was added successfully.',
          facts: _buildRecurringFacts(
            title: action.data['title'] as String,
            amount: action.data['amount'] as double,
            dayOfMonth: action.data['dayOfMonth'] as int,
            category: action.data['category'] as String?,
            bankName: action.data['bankName'] as String?,
            autoAdd: (action.data['autoAdd'] as bool?) ?? false,
          ),
        );
      case FinancialAssistantActionType.updateRecurringPayment:
        await provider.updateRecurringPayment(
          id: action.data['id'] as String,
          title: action.data['title'] as String,
          amount: action.data['amount'] as double,
          dayOfMonth: action.data['dayOfMonth'] as int,
          frequency: RecurringFrequency.monthly,
          startDate: action.data['startDate'] as DateTime? ?? DateTime.now(),
          category: action.data['category'] as String?,
          bank: action.data['bankName'] as String?,
          bankAccountId: action.data['bankAccountId'] as String?,
          autoAdd: (action.data['autoAdd'] as bool?) ?? false,
        );
        return FinancialAssistantExecutionResult(
          message: 'The recurring payment was updated successfully.',
          facts: _buildRecurringFacts(
            title: action.data['title'] as String,
            amount: action.data['amount'] as double,
            dayOfMonth: action.data['dayOfMonth'] as int,
            category: action.data['category'] as String?,
            bankName: action.data['bankName'] as String?,
            autoAdd: (action.data['autoAdd'] as bool?) ?? false,
          ),
        );
      case FinancialAssistantActionType.removeRecurringPayment:
        await provider.removeRecurringPayment(action.data['id'] as String);
        return FinancialAssistantExecutionResult(
          message: 'The recurring payment was removed successfully.',
          facts: <FinancialAssistantFact>[
            FinancialAssistantFact(
              label: 'Removed recurring payment',
              value: action.data['title'] as String,
            ),
          ],
        );
      case FinancialAssistantActionType.undoLastAction:
        final undoKind = action.data['undoKind'] as String?;
        if (undoKind == 'removeIncomeEntry') {
          await provider.removeIncomeEntryForDate(
            date: action.data['date'] as DateTime,
            index: action.data['index'] as int,
          );
          return const FinancialAssistantExecutionResult(
            message: 'The last assistant action was undone.',
          );
        }
        final nested =
            action.data['action'] as FinancialAssistantPendingAction?;
        if (nested == null) {
          return const FinancialAssistantExecutionResult(
            message: 'There is nothing available to undo right now.',
          );
        }
        final nestedResult = await executeAction(nested, provider);
        return FinancialAssistantExecutionResult(
          message: 'The last assistant action was undone.',
          facts: nestedResult.facts,
        );
      case FinancialAssistantActionType.openExportOptions:
        return const FinancialAssistantExecutionResult(
          message: 'Opening the export options.',
        );
    }
  }

  FinancialAssistantReply _replyWithAction({
    required String message,
    required FinancialAssistantConversationContext context,
    required FinancialAssistantPendingAction action,
  }) {
    return FinancialAssistantReply(
      message: message,
      pendingAction: action,
      context: context,
    );
  }

  FinancialAssistantReply? _tryHandlePendingActionFollowUp(
    String normalized,
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
  ) {
    final pending = context.lastPendingAction;
    if (pending == null) return null;

    if (pending.type == FinancialAssistantActionType.addSpending) {
      return _continueAddSpendingDraft(normalized, provider, context, pending);
    }

    if (pending.type == FinancialAssistantActionType.addIncome) {
      return _continueAddIncomeDraft(normalized, context, pending);
    }

    final selectionOptions =
        pending.data['selectionOptions']
            as List<FinancialAssistantSpendingSelection>?;
    if (selectionOptions != null &&
        selectionOptions.isNotEmpty &&
        (pending.type == FinancialAssistantActionType.editSpending ||
            pending.type == FinancialAssistantActionType.deleteSpending)) {
      return _continueSpendingSelectionChoice(
        normalized,
        context,
        pending,
        selectionOptions,
      );
    }

    final supported = <FinancialAssistantActionType>{
      FinancialAssistantActionType.editSpending,
      FinancialAssistantActionType.addRecurringPayment,
      FinancialAssistantActionType.updateRecurringPayment,
    };
    if (!supported.contains(pending.type)) return null;

    final amount = _extractReplacementAmount(normalized);
    final bank = _resolveBank(provider, normalized);
    final category = _extractCategoryFromCommand(provider, normalized);
    final date = _extractSpecificDate(normalized, DateTime.now());
    final dayOfMonth = _parseRecurringDayOfMonth(normalized);

    if (amount == null &&
        bank == null &&
        category == null &&
        date == null &&
        dayOfMonth == null) {
      return null;
    }

    final nextData = Map<String, Object?>.from(pending.data);
    if (amount != null) nextData['amount'] = amount;
    if (bank != null) {
      nextData['bankName'] = bank.name;
      nextData['bankAccountId'] = bank.id;
    }
    if (category != null) nextData['category'] = category;
    if (date != null &&
        (pending.type == FinancialAssistantActionType.addSpending ||
            pending.type == FinancialAssistantActionType.editSpending)) {
      nextData['date'] = date;
    }
    if (dayOfMonth != null &&
        (pending.type == FinancialAssistantActionType.addRecurringPayment ||
            pending.type ==
                FinancialAssistantActionType.updateRecurringPayment)) {
      nextData['dayOfMonth'] = dayOfMonth;
    }

    final updatedAction = _rebuildActionWithUpdatedData(
      pending.type,
      nextData,
      pending.destructive,
      pending.requiresConfirmation,
    );

    final updatedContext = context.copyWith(
      lastPendingAction: updatedAction,
      lastCategory: nextData['category'] as String?,
      lastBankName: nextData['bankName'] as String?,
    );

    return FinancialAssistantReply(
      message: 'I updated the pending action with your latest instruction.',
      pendingAction: updatedAction,
      context: updatedContext,
    );
  }

  FinancialAssistantReply _continueAddIncomeDraft(
    String normalized,
    FinancialAssistantConversationContext context,
    FinancialAssistantPendingAction pending,
  ) {
    final nextData = Map<String, Object?>.from(pending.data);
    final expectedField = nextData['expectedField'] as String?;
    final wantsSkip = _isSkipResponse(normalized);

    if (wantsSkip && expectedField != null) {
      switch (expectedField) {
        case 'source':
          nextData['source'] = null;
          nextData['askedSource'] = true;
          break;
        case 'note':
          nextData['note'] = null;
          nextData['askedNote'] = true;
          break;
      }
    }

    final date = _extractSpecificDate(normalized, DateTime.now());
    double? amount;
    String? source;
    String? note;

    switch (expectedField) {
      case 'amount':
        amount = _extractReplacementAmount(normalized);
        break;
      case 'source':
        source = wantsSkip ? null : _plainTextAnswer(normalized);
        break;
      case 'note':
        note = wantsSkip ? null : _plainTextAnswer(normalized);
        break;
      default:
        amount = _extractReplacementAmount(normalized);
        source = wantsSkip ? null : _plainTextAnswer(normalized);
        break;
    }

    if (amount != null) nextData['amount'] = amount;
    if (date != null) nextData['date'] = date;
    if (source != null || wantsSkip && expectedField == 'source') {
      nextData['source'] = source;
      nextData['askedSource'] = true;
    }
    if (note != null || wantsSkip && expectedField == 'note') {
      nextData['note'] = note;
      nextData['askedNote'] = true;
    }

    final nextQuestion = _nextAddIncomeQuestion(nextData);
    final updatedContext = context.copyWith(
      lastPendingAction: pending.copyWith(data: nextData),
      lastIncomeSource: nextData['source'] as String?,
    );

    if (nextQuestion != null) {
      nextData['expectedField'] = nextQuestion.field;
      return FinancialAssistantReply(
        message: nextQuestion.message,
        context: updatedContext.copyWith(
          lastPendingAction: pending.copyWith(data: nextData),
        ),
      );
    }

    final completedAction = _buildAddIncomeAction(
      amount: nextData['amount'] as double,
      date: nextData['date'] as DateTime,
      source: nextData['source'] as String?,
      note: nextData['note'] as String?,
    );
    return FinancialAssistantReply(
      message: 'I have everything I need. Please confirm the income entry.',
      pendingAction: completedAction,
      context: updatedContext.copyWith(lastPendingAction: completedAction),
    );
  }

  FinancialAssistantReply _continueSpendingSelectionChoice(
    String normalized,
    FinancialAssistantConversationContext context,
    FinancialAssistantPendingAction pending,
    List<FinancialAssistantSpendingSelection> options,
  ) {
    final selected = _resolveSpendingOptionSelection(normalized, options);
    if (selected == null) {
      return FinancialAssistantReply(
        message:
            'Please choose one of the listed transactions by number, like 1 or 2.',
        context: context,
      );
    }

    FinancialAssistantPendingAction resolvedAction;
    if (pending.type == FinancialAssistantActionType.editSpending) {
      resolvedAction = _buildEditSpendingAction(
        selection: selected,
        amount: pending.data['amount'] as double,
        date: pending.data['date'] as DateTime,
        category: pending.data['category'] as String?,
        bankName: pending.data['bankName'] as String?,
        bankAccountId: pending.data['bankAccountId'] as String?,
        item: pending.data['item'] as String?,
        qty: pending.data['qty'] as int? ?? selected.entry.qty,
      );
    } else {
      resolvedAction = _buildDeleteSpendingAction(selected);
    }

    return FinancialAssistantReply(
      message:
          'Thanks, I found the exact transaction. Please confirm the action.',
      pendingAction: resolvedAction,
      context: context.copyWith(
        lastPendingAction: resolvedAction,
        lastSpendingSelection: selected,
      ),
    );
  }

  FinancialAssistantReply _continueAddSpendingDraft(
    String normalized,
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
    FinancialAssistantPendingAction pending,
  ) {
    final nextData = Map<String, Object?>.from(pending.data);
    final expectedField = nextData['expectedField'] as String?;
    final wantsSkip = _isSkipResponse(normalized);

    if (wantsSkip && expectedField != null) {
      switch (expectedField) {
        case 'category':
          nextData['category'] = null;
          nextData['askedCategory'] = true;
          break;
        case 'item':
          nextData['item'] = null;
          nextData['askedItem'] = true;
          break;
        case 'qty':
          nextData['qty'] = null;
          nextData['askedQty'] = true;
          break;
        case 'bank':
          return FinancialAssistantReply(
            message:
                'I need a bank account for this spending. Please choose one of your saved banks.',
            context: context,
          );
      }
    }

    final date = _extractSpecificDate(normalized, DateTime.now());
    double? amount;
    BankAccount? bank;
    String? category;
    String? item;
    int? qty;

    switch (expectedField) {
      case 'amount':
        amount = _extractReplacementAmount(normalized);
        break;
      case 'category':
        category =
            _extractCategoryFromCommand(provider, normalized) ??
            (wantsSkip ? null : _plainTextAnswer(normalized));
        break;
      case 'item':
        item = _extractSpendingItem(
          normalized,
          nextData['category'] as String?,
        );
        if (!wantsSkip && (item == null || item.isEmpty)) {
          item = _plainTextAnswer(normalized);
        }
        break;
      case 'qty':
        qty = _parseQuantity(normalized);
        break;
      case 'bank':
        bank = _resolveBank(provider, normalized);
        if (bank == null) {
          final explicitBankName = _extractBankNameFromCommand(normalized);
          if (explicitBankName != null) {
            nextData['bankName'] = explicitBankName;
            nextData['bankAccountId'] = null;
            nextData['askedBank'] = true;
          }
        }
        break;
      default:
        amount = _extractReplacementAmount(normalized);
        bank = _resolveBank(provider, normalized);
        category = _extractCategoryFromCommand(provider, normalized);
        item = _extractSpendingItem(
          normalized,
          category ?? nextData['category'] as String?,
        );
        qty = _parseQuantity(normalized);
        break;
    }

    if (amount != null) nextData['amount'] = amount;
    if (bank != null) {
      nextData['bankName'] = bank.name;
      nextData['bankAccountId'] = bank.id;
      nextData['askedBank'] = true;
    }
    if (bank == null) {
      final explicitBankName = _extractBankNameFromCommand(normalized);
      if (explicitBankName != null) {
        nextData['bankName'] = explicitBankName;
        nextData['bankAccountId'] = null;
        nextData['askedBank'] = true;
      }
    }
    if (category != null) {
      nextData['category'] = category;
      nextData['askedCategory'] = true;
    }
    if (date != null) nextData['date'] = date;
    if (item != null) {
      nextData['item'] = item;
      nextData['askedItem'] = true;
    }
    final merchantMemory = (nextData['item'] as String?) == null
        ? null
        : _findMerchantMemory(provider, nextData['item'] as String);
    if ((nextData['category'] as String?) == null &&
        merchantMemory?.category != null) {
      nextData['category'] = merchantMemory!.category;
      nextData['askedCategory'] = true;
    }
    if ((nextData['bankName'] as String?) == null &&
        merchantMemory?.bankName != null) {
      nextData['bankName'] = merchantMemory!.bankName;
      nextData['bankAccountId'] = merchantMemory.bankAccountId;
      nextData['askedBank'] = true;
    }
    if (qty != null) {
      nextData['qty'] = qty;
      nextData['askedQty'] = true;
    }

    final nextQuestion = _nextAddSpendingQuestion(nextData, provider);
    final updatedContext = context.copyWith(
      lastPendingAction: pending.copyWith(data: nextData),
      lastCategory: nextData['category'] as String?,
      lastBankName: nextData['bankName'] as String?,
    );

    if (nextQuestion != null) {
      nextData['expectedField'] = nextQuestion.field;
      return FinancialAssistantReply(
        message: nextQuestion.message,
        context: updatedContext.copyWith(
          lastPendingAction: pending.copyWith(data: nextData),
        ),
      );
    }

    final completedAction = _withDuplicateWarning(
      provider,
      _buildAddSpendingAction(
        amount: nextData['amount'] as double,
        date: nextData['date'] as DateTime,
        category: nextData['category'] as String?,
        bankName: nextData['bankName'] as String?,
        bankAccountId: nextData['bankAccountId'] as String?,
        item: nextData['item'] as String?,
        qty: nextData['qty'] as int?,
      ),
    );

    return FinancialAssistantReply(
      message: _buildAddSpendingConfirmationMessage(completedAction),
      pendingAction: completedAction,
      context: updatedContext.copyWith(lastPendingAction: completedAction),
    );
  }

  FinancialAssistantPendingAction _rebuildActionWithUpdatedData(
    FinancialAssistantActionType type,
    Map<String, Object?> data,
    bool destructive,
    bool requiresConfirmation,
  ) {
    switch (type) {
      case FinancialAssistantActionType.addSpending:
        return _buildAddSpendingAction(
          amount: data['amount'] as double,
          date: data['date'] as DateTime,
          category: data['category'] as String?,
          bankName: data['bankName'] as String?,
          bankAccountId: data['bankAccountId'] as String?,
          item: data['item'] as String?,
          qty: data['qty'] as int?,
        );
      case FinancialAssistantActionType.addIncome:
        return _buildAddIncomeAction(
          amount: data['amount'] as double,
          date: data['date'] as DateTime,
          source: data['source'] as String?,
          note: data['note'] as String?,
        );
      case FinancialAssistantActionType.editSpending:
        return _buildEditSpendingAction(
          selection: data['selection'] as FinancialAssistantSpendingSelection,
          amount: data['amount'] as double,
          date: data['date'] as DateTime,
          category: data['category'] as String?,
          bankName: data['bankName'] as String?,
          bankAccountId: data['bankAccountId'] as String?,
          item: data['item'] as String?,
          qty: data['qty'] as int?,
        );
      case FinancialAssistantActionType.addRecurringPayment:
        return _buildRecurringAction(
          type: type,
          title: data['title'] as String,
          amount: data['amount'] as double,
          dayOfMonth: data['dayOfMonth'] as int,
          category: data['category'] as String?,
          bankName: data['bankName'] as String?,
          bankAccountId: data['bankAccountId'] as String?,
          autoAdd: (data['autoAdd'] as bool?) ?? false,
        );
      case FinancialAssistantActionType.updateRecurringPayment:
        return _buildRecurringAction(
          type: type,
          title: data['title'] as String,
          amount: data['amount'] as double,
          dayOfMonth: data['dayOfMonth'] as int,
          category: data['category'] as String?,
          bankName: data['bankName'] as String?,
          bankAccountId: data['bankAccountId'] as String?,
          autoAdd: (data['autoAdd'] as bool?) ?? false,
          id: data['id'] as String?,
          startDate: data['startDate'] as DateTime?,
        );
      default:
        return FinancialAssistantPendingAction(
          type: type,
          title: 'Pending action',
          summary: pendingSummaryFallback(data),
          data: data,
          destructive: destructive,
          requiresConfirmation: requiresConfirmation,
        );
    }
  }

  String pendingSummaryFallback(Map<String, Object?> data) =>
      data.entries.map((e) => '${e.key}: ${e.value}').join(', ');

  FinancialAssistantPendingAction? _tryParseAddSpending(
    String normalized,
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
    DateTime now,
  ) {
    final looksLikeStructuredSpending = _looksLikeStructuredSpendingMessage(
      normalized,
      provider,
    );
    final hasAddIntent =
        _matchesAny(normalized, const <String>[
          'add spending',
          'add a spending',
          'add ',
          'i did a spending',
          'i did spending',
          'i did an expense',
          'i made a spending',
          'record expense',
          'log spending',
          'record spending',
          'add expense',
          'i spent',
          'spent ',
          'i paid',
          'paid ',
        ]) ||
        RegExp(
          r'^(add|spent|paid)\s+\d',
          caseSensitive: false,
        ).hasMatch(normalized) ||
        looksLikeStructuredSpending;
    if (!hasAddIntent) return null;

    final amount = _parseFirstAmount(normalized);
    final explicitBankName = _extractBankNameFromCommand(normalized);
    final bank =
        _resolveBank(provider, normalized) ??
        (explicitBankName != null
            ? _findBankByName(provider, explicitBankName)
            : null) ??
        (context.lastBankName != null
            ? _findBankByName(provider, context.lastBankName!)
            : null);
    final category =
        _extractCategoryFromCommand(provider, normalized) ??
        context.lastCategory;
    final date = _extractSpecificDate(normalized, now) ?? now;
    final item = _extractSpendingItem(normalized, category);
    final merchantMemory = item == null
        ? null
        : _findMerchantMemory(provider, item);
    final qty = _parseQuantity(normalized);
    final draftData = <String, Object?>{
      'amount': amount,
      'date': date,
      'category': category ?? merchantMemory?.category,
      'bankName': bank?.name ?? explicitBankName ?? merchantMemory?.bankName,
      'bankAccountId': bank?.id ?? merchantMemory?.bankAccountId,
      'item': item,
      'qty': qty,
      'askedCategory': (category ?? merchantMemory?.category) != null,
      'askedItem': item != null,
      'askedQty': qty != null,
      'askedBank':
          bank != null ||
          explicitBankName != null ||
          merchantMemory?.bankName != null ||
          provider.bankAccounts.isEmpty,
    };

    final nextQuestion = _nextAddSpendingQuestion(draftData, provider);
    if (nextQuestion != null) {
      return FinancialAssistantPendingAction(
        type: FinancialAssistantActionType.addSpending,
        title: 'Add spending',
        summary: 'Waiting for the missing spending details.',
        data: <String, Object?>{
          ...draftData,
          'expectedField': nextQuestion.field,
        },
      );
    }

    return _withDuplicateWarning(
      provider,
      _buildAddSpendingAction(
        amount: amount!,
        date: date,
        category: category ?? merchantMemory?.category,
        bankName: bank?.name ?? explicitBankName ?? merchantMemory?.bankName,
        bankAccountId: bank?.id ?? merchantMemory?.bankAccountId,
        item: item,
        qty: qty,
      ),
    );
  }

  FinancialAssistantPendingAction? _tryParseAddIncome(
    String normalized,
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
    DateTime now,
  ) {
    if (_looksLikeStructuredSpendingMessage(normalized, provider)) {
      return null;
    }

    final hasAddIntent =
        _matchesAny(normalized, const <String>[
          'add income',
          'record income',
          'log income',
          'i did an income',
          'i did income',
          'received ',
          'i received',
          'got paid',
          'salary',
          'bonus',
        ]) ||
        RegExp(
          r'^(income|received)\s+\d',
          caseSensitive: false,
        ).hasMatch(normalized);
    if (!hasAddIntent) return null;

    final amount = _parseFirstAmount(normalized);
    final date = _extractSpecificDate(normalized, now) ?? now;
    final source = _extractIncomeSource(normalized) ?? context.lastIncomeSource;
    final note = _extractIncomeNote(normalized, source);
    final draftData = <String, Object?>{
      'amount': amount,
      'date': date,
      'source': source,
      'note': note,
      'askedSource': source != null,
      'askedNote': note != null,
    };

    final nextQuestion = _nextAddIncomeQuestion(draftData);
    if (nextQuestion != null) {
      return FinancialAssistantPendingAction(
        type: FinancialAssistantActionType.addIncome,
        title: 'Add income',
        summary: 'Waiting for the missing income details.',
        data: <String, Object?>{
          ...draftData,
          'expectedField': nextQuestion.field,
        },
      );
    }

    return _buildAddIncomeAction(
      amount: amount!,
      date: date,
      source: source,
      note: note,
    );
  }

  FinancialAssistantPendingAction _buildAddSpendingAction({
    required double amount,
    required DateTime date,
    String? category,
    String? bankName,
    String? bankAccountId,
    String? item,
    int? qty,
  }) {
    final summaryLines = <String>[
      'Amount: ${amount.toStringAsFixed(2)} SAR',
      'Category: ${category == null || category.trim().isEmpty ? 'Not specified' : category}',
      'Item: ${item == null || item.trim().isEmpty ? 'Not specified' : item}',
      'Quantity: ${qty ?? 1}',
      'Bank: ${bankName == null || bankName.trim().isEmpty ? 'Not specified' : bankName}',
      'Date: ${DateFormat('yyyy-MM-dd').format(date)}',
    ];

    return FinancialAssistantPendingAction(
      type: FinancialAssistantActionType.addSpending,
      title: 'Add spending',
      summary: summaryLines.join('\n'),
      data: <String, Object?>{
        'amount': amount,
        'date': date,
        'category': category,
        'bankName': bankName,
        'bankAccountId': bankAccountId,
        'item': item,
        'qty': qty,
      },
    );
  }

  String _buildAddSpendingConfirmationMessage(
    FinancialAssistantPendingAction action,
  ) {
    if (action.data['duplicateDate'] != null) {
      return 'I found a very similar spending already recorded for this date. Please confirm only if this is a separate transaction.';
    }
    return 'Please review the spending details below and confirm if everything looks correct.';
  }

  FinancialAssistantPendingAction _withDuplicateWarning(
    SpendingProvider provider,
    FinancialAssistantPendingAction action,
  ) {
    final duplicate = _findPotentialDuplicateSpending(
      provider,
      date: action.data['date'] as DateTime,
      amount: action.data['amount'] as double,
      category: action.data['category'] as String?,
      bankName: action.data['bankName'] as String?,
      item: action.data['item'] as String?,
      qty: action.data['qty'] as int?,
    );
    if (duplicate == null) return action;

    return action.copyWith(
      title: 'Possible duplicate spending',
      summary:
          '${action.summary}\n\nSimilar existing spending:\n${_formatSpendingSelectionForDuplicate(duplicate, provider)}',
      data: <String, Object?>{
        ...action.data,
        'duplicateDate': duplicate.date,
        'duplicateIndex': duplicate.index,
      },
    );
  }

  FinancialAssistantSpendingSelection? _findPotentialDuplicateSpending(
    SpendingProvider provider, {
    required DateTime date,
    required double amount,
    String? category,
    String? bankName,
    String? item,
    int? qty,
  }) {
    final entries = provider.getEntriesForDate(date);
    if (entries.isEmpty) return null;

    final targetQty = _effectiveAssistantQty(qty);
    final targetAmount = amount * targetQty;
    final normalizedItem = item?.trim().toLowerCase();
    final normalizedCategory = category?.trim().toLowerCase();
    final normalizedBank = bankName?.trim().toLowerCase();

    FinancialAssistantSpendingSelection? best;
    var bestScore = -1;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if ((entry.amount - targetAmount).abs() > 0.001) continue;

      var score = 0;
      if (normalizedItem != null &&
          normalizedItem.isNotEmpty &&
          entry.item?.trim().toLowerCase() == normalizedItem) {
        score += 4;
      }
      if (normalizedCategory != null &&
          normalizedCategory.isNotEmpty &&
          provider.categoryLabelOf(entry).trim().toLowerCase() ==
              normalizedCategory) {
        score += 3;
      }
      if (normalizedBank != null &&
          normalizedBank.isNotEmpty &&
          entry.bank?.trim().toLowerCase() == normalizedBank) {
        score += 2;
      }
      if ((entry.qty ?? 1) == targetQty) {
        score += 1;
      }

      if (score > bestScore) {
        bestScore = score;
        best = FinancialAssistantSpendingSelection(
          date: date,
          index: i,
          entry: entry,
        );
      }
    }

    return bestScore >= 3 ? best : null;
  }

  String _formatSpendingSelectionForDuplicate(
    FinancialAssistantSpendingSelection selection,
    SpendingProvider provider,
  ) {
    return <String>[
      'Amount: ${selection.entry.amount.toStringAsFixed(2)} SAR',
      'Category: ${provider.categoryLabelOf(selection.entry)}',
      'Item: ${selection.entry.item ?? 'Not specified'}',
      'Quantity: ${selection.entry.qty ?? 1}',
      'Bank: ${selection.entry.bank ?? 'Not specified'}',
      'Date: ${DateFormat('yyyy-MM-dd').format(selection.date)}',
    ].join('\n');
  }

  int _effectiveAssistantQty(int? qty) {
    if (qty == null || qty <= 0) return 1;
    return qty;
  }

  FinancialAssistantPendingAction _buildAddIncomeAction({
    required double amount,
    required DateTime date,
    String? source,
    String? note,
  }) {
    final summary = StringBuffer()
      ..write('${amount.toStringAsFixed(2)} SAR')
      ..write(' on ${DateFormat('yyyy-MM-dd').format(date)}');
    if (source != null) summary.write(' from $source');
    if (note != null) summary.write(' ($note)');

    return FinancialAssistantPendingAction(
      type: FinancialAssistantActionType.addIncome,
      title: 'Add income',
      summary: summary.toString(),
      data: <String, Object?>{
        'amount': amount,
        'date': date,
        'source': source,
        'note': note,
      },
    );
  }

  _AddSpendingQuestion? _nextAddSpendingQuestion(
    Map<String, Object?> data,
    SpendingProvider provider,
  ) {
    final amount = data['amount'] as double?;
    final category = data['category'] as String?;
    final bankName = data['bankName'] as String?;
    final askedCategory = (data['askedCategory'] as bool?) ?? false;
    final askedItem = (data['askedItem'] as bool?) ?? false;
    final askedQty = (data['askedQty'] as bool?) ?? false;
    final askedBank = (data['askedBank'] as bool?) ?? false;

    if (amount == null || amount <= 0) {
      return const _AddSpendingQuestion(
        field: 'amount',
        message: 'What amount should I record for this spending?',
      );
    }
    if (!askedCategory) {
      return const _AddSpendingQuestion(
        field: 'category',
        message:
            "What category should I use for this spending? You can say 'skip' if you don't want to specify it.",
      );
    }
    if (!askedItem) {
      return const _AddSpendingQuestion(
        field: 'item',
        message:
            "What item did you purchase? You can say 'skip' if you don't want to specify it.",
      );
    }
    if (!askedQty) {
      return const _AddSpendingQuestion(
        field: 'qty',
        message:
            "What was the quantity? You can say 'skip' if you don't want to specify it.",
      );
    }
    if (!askedBank &&
        provider.bankAccounts.isNotEmpty &&
        (bankName == null || bankName.trim().isEmpty)) {
      final suggestions = provider.bankAccounts
          .take(3)
          .map((account) => account.name)
          .join(', ');
      return _AddSpendingQuestion(
        field: 'bank',
        message: suggestions.isEmpty
            ? 'Which bank account did you use?'
            : 'Which bank account did you use? For example: $suggestions.',
      );
    }
    return null;
  }

  _AddIncomeQuestion? _nextAddIncomeQuestion(Map<String, Object?> data) {
    final amount = data['amount'] as double?;
    final askedSource = (data['askedSource'] as bool?) ?? false;
    final askedNote = (data['askedNote'] as bool?) ?? false;

    if (amount == null || amount <= 0) {
      return const _AddIncomeQuestion(
        field: 'amount',
        message: 'What amount should I record for this income?',
      );
    }
    if (!askedSource) {
      return const _AddIncomeQuestion(
        field: 'source',
        message:
            "What was the income source? You can say 'skip' if you don't want to specify it.",
      );
    }
    if (!askedNote) {
      return const _AddIncomeQuestion(
        field: 'note',
        message:
            "Would you like to add a note for this income? You can say 'skip' if not.",
      );
    }
    return null;
  }

  FinancialAssistantPendingAction? _tryParseEditSpending(
    String normalized,
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
    DateTime now,
  ) {
    final hasEditIntent = _matchesAny(normalized, const <String>[
      'change ',
      'edit ',
      'update ',
      'modify ',
    ]);
    if (!hasEditIntent) return null;

    final replacementAmount = _extractReplacementAmount(normalized);
    if (replacementAmount == null) return null;

    final matches = _findSpendingSelectionMatches(
      provider,
      normalized,
      context,
      now,
    );
    final selection = matches.isNotEmpty ? matches.first : null;
    if (selection == null) return null;

    if (matches.length > 1) {
      final category =
          _extractCategoryFromCommand(provider, normalized) ??
          selection.entry.category;
      final bank =
          _resolveBank(provider, normalized) ??
          (selection.entry.bank != null
              ? _findBankByName(provider, selection.entry.bank!)
              : null);
      return FinancialAssistantPendingAction(
        type: FinancialAssistantActionType.editSpending,
        title: 'Choose spending to edit',
        summary: 'Waiting for you to choose the exact transaction to edit.',
        data: <String, Object?>{
          'selectionOptions': matches.take(3).toList(),
          'amount': replacementAmount,
          'date': _extractSpecificDate(normalized, now) ?? selection.date,
          'category': category,
          'bankName': bank?.name ?? selection.entry.bank,
          'bankAccountId': bank?.id ?? selection.entry.bankAccountId,
          'item':
              _extractSpendingItem(normalized, category) ??
              selection.entry.item,
          'qty': selection.entry.qty,
        },
      );
    }

    final bank =
        _resolveBank(provider, normalized) ??
        (selection.entry.bank != null
            ? _findBankByName(provider, selection.entry.bank!)
            : null);
    final category =
        _extractCategoryFromCommand(provider, normalized) ??
        selection.entry.category;
    final item =
        _extractSpendingItem(normalized, category) ?? selection.entry.item;
    final date = _extractSpecificDate(normalized, now) ?? selection.date;

    return _buildEditSpendingAction(
      selection: selection,
      amount: replacementAmount,
      date: date,
      category: category,
      bankName: bank?.name ?? selection.entry.bank,
      bankAccountId: bank?.id ?? selection.entry.bankAccountId,
      item: item,
      qty: selection.entry.qty,
    );
  }

  FinancialAssistantPendingAction _buildEditSpendingAction({
    required FinancialAssistantSpendingSelection selection,
    required double amount,
    required DateTime date,
    String? category,
    String? bankName,
    String? bankAccountId,
    String? item,
    int? qty,
  }) {
    final originalLabel =
        selection.entry.item ?? selection.entry.category ?? 'spending entry';
    final summary = StringBuffer()
      ..write('Update $originalLabel to ${amount.toStringAsFixed(2)} SAR')
      ..write(' on ${DateFormat('yyyy-MM-dd').format(date)}');
    if (category != null) summary.write(' in $category');
    if (bankName != null) summary.write(' using $bankName');

    return FinancialAssistantPendingAction(
      type: FinancialAssistantActionType.editSpending,
      title: 'Edit spending',
      summary: summary.toString(),
      data: <String, Object?>{
        'selection': selection,
        'amount': amount,
        'date': date,
        'category': category,
        'bankName': bankName,
        'bankAccountId': bankAccountId,
        'item': item,
        'qty': qty,
      },
    );
  }

  FinancialAssistantPendingAction _buildDeleteSpendingAction(
    FinancialAssistantSpendingSelection selection,
  ) {
    final label =
        selection.entry.item ?? selection.entry.category ?? 'spending entry';
    return FinancialAssistantPendingAction(
      type: FinancialAssistantActionType.deleteSpending,
      title: 'Delete spending',
      summary:
          'Delete $label • ${selection.entry.amount.toStringAsFixed(2)} SAR from ${DateFormat('yyyy-MM-dd').format(selection.date)}',
      data: <String, Object?>{'selection': selection},
      destructive: true,
    );
  }

  FinancialAssistantPendingAction? _tryParseDeleteSpending(
    String normalized,
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
    DateTime now,
  ) {
    final hasDeleteIntent = _matchesAny(normalized, const <String>[
      'delete ',
      'remove ',
    ]);
    if (!hasDeleteIntent || normalized.contains('bank')) return null;

    final matches = _findSpendingSelectionMatches(
      provider,
      normalized,
      context,
      now,
    );
    final selection = matches.isNotEmpty ? matches.first : null;
    if (selection == null) return null;
    if (matches.length > 1) {
      return FinancialAssistantPendingAction(
        type: FinancialAssistantActionType.deleteSpending,
        title: 'Choose spending to delete',
        summary: 'Waiting for you to choose the exact transaction to delete.',
        data: <String, Object?>{'selectionOptions': matches.take(3).toList()},
      );
    }
    return _buildDeleteSpendingAction(selection);
  }

  FinancialAssistantPendingAction? _tryParseAddBank(
    String normalized,
    String original,
    SpendingProvider provider,
  ) {
    if (!normalized.startsWith('add ') || !normalized.contains('balance')) {
      return null;
    }

    final amount = _parseFirstAmount(normalized);
    final match = RegExp(
      r'^add\s+(.+?)\s+(?:with\s+(?:a\s+)?)?balance(?:\s+of)?\s+',
      caseSensitive: false,
    ).firstMatch(original);
    if (amount == null || match == null) return null;

    final name = match.group(1)?.trim();
    if (name == null || name.isEmpty) return null;
    if (provider.findBankAccountId(bankName: name) != null) return null;

    return FinancialAssistantPendingAction(
      type: FinancialAssistantActionType.addBank,
      title: 'Add bank account',
      summary:
          '$name with a starting balance of ${amount.toStringAsFixed(2)} SAR',
      data: <String, Object?>{'name': name, 'balance': amount},
    );
  }

  FinancialAssistantPendingAction? _tryParseUpdateBankBalance(
    String normalized,
    SpendingProvider provider,
  ) {
    if (!_matchesAny(normalized, const <String>[
          'update bank balance',
          'set bank balance',
          'change bank balance',
        ]) &&
        !(normalized.contains('balance') && normalized.contains(' to '))) {
      return null;
    }

    final bank = _resolveBank(provider, normalized);
    final amount = _parseFirstAmount(normalized);
    if (bank == null || amount == null) return null;

    return FinancialAssistantPendingAction(
      type: FinancialAssistantActionType.updateBankBalance,
      title: 'Update bank balance',
      summary: 'Set ${bank.name} to ${amount.toStringAsFixed(2)} SAR',
      data: <String, Object?>{
        'bankAccountId': bank.id,
        'name': bank.name,
        'balance': amount,
      },
    );
  }

  FinancialAssistantPendingAction? _tryParseRenameBank(
    String normalized,
    SpendingProvider provider,
  ) {
    if (!normalized.startsWith('rename ')) return null;

    final match = RegExp(
      r'^rename\s+(.+?)\s+to\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match == null) return null;

    final oldName = match.group(1)?.trim();
    final newName = match.group(2)?.trim();
    if (oldName == null || newName == null || newName.isEmpty) return null;
    final bank = _findBankByName(provider, oldName);
    if (bank == null) return null;

    return FinancialAssistantPendingAction(
      type: FinancialAssistantActionType.renameBank,
      title: 'Rename bank',
      summary: 'Rename ${bank.name} to $newName',
      data: <String, Object?>{
        'bankAccountId': bank.id,
        'name': bank.name,
        'newName': newName,
      },
    );
  }

  FinancialAssistantPendingAction? _tryParseRemoveBank(
    String normalized,
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
  ) {
    if (!_matchesAny(normalized, const <String>[
      'remove bank',
      'delete bank',
    ])) {
      return null;
    }

    final bank =
        _resolveBank(provider, normalized) ??
        (context.lastBankName != null
            ? _findBankByName(provider, context.lastBankName!)
            : null);
    if (bank == null) return null;

    return FinancialAssistantPendingAction(
      type: FinancialAssistantActionType.removeBank,
      title: 'Remove bank',
      summary: 'Remove ${bank.name} from the saved bank list',
      data: <String, Object?>{'bankAccountId': bank.id, 'name': bank.name},
      destructive: true,
    );
  }

  FinancialAssistantPendingAction? _tryParseAddRecurringPayment(
    String normalized,
    String original,
    SpendingProvider provider,
  ) {
    final hasIntent = _matchesAny(normalized, const <String>[
      'add recurring',
      'add recurring payment',
      'add subscription',
      'add bill',
    ]);
    if (!hasIntent) return null;

    final amount = _parseFirstAmount(normalized);
    final dayOfMonth = _parseRecurringDayOfMonth(normalized);
    if (amount == null || dayOfMonth == null) return null;

    final title = _extractRecurringTitle(original);
    if (title == null || title.isEmpty) return null;
    final bank = _resolveBank(provider, normalized);
    final category = _extractCategoryFromCommand(provider, normalized);
    final autoAdd = normalized.contains('auto');

    return _buildRecurringAction(
      type: FinancialAssistantActionType.addRecurringPayment,
      title: title,
      amount: amount,
      dayOfMonth: dayOfMonth,
      category: category,
      bankName: bank?.name,
      bankAccountId: bank?.id,
      autoAdd: autoAdd,
    );
  }

  FinancialAssistantPendingAction? _tryParseUpdateRecurringPayment(
    String normalized,
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
  ) {
    final hasIntent = _matchesAny(normalized, const <String>[
      'update recurring',
      'edit recurring',
      'change recurring',
      'update subscription',
      'edit subscription',
    ]);
    if (!hasIntent) return null;

    final payment = _findRecurringPayment(provider, normalized, context);
    if (payment == null) return null;

    final amount = _extractReplacementAmount(normalized) ?? payment.amount;
    final dayOfMonth =
        _parseRecurringDayOfMonth(normalized) ?? payment.dayOfMonth;
    final bank =
        _resolveBank(provider, normalized) ??
        (payment.bank != null
            ? _findBankByName(provider, payment.bank!)
            : null);
    final category =
        _extractCategoryFromCommand(provider, normalized) ?? payment.category;

    return _buildRecurringAction(
      type: FinancialAssistantActionType.updateRecurringPayment,
      id: payment.id,
      title: payment.title,
      amount: amount,
      dayOfMonth: dayOfMonth,
      category: category,
      bankName: bank?.name ?? payment.bank,
      bankAccountId: bank?.id ?? payment.bankAccountId,
      autoAdd: payment.autoAdd,
      startDate: payment.startDate,
    );
  }

  FinancialAssistantPendingAction _buildRecurringAction({
    required FinancialAssistantActionType type,
    String? id,
    required String title,
    required double amount,
    required int dayOfMonth,
    String? category,
    String? bankName,
    String? bankAccountId,
    required bool autoAdd,
    DateTime? startDate,
  }) {
    final summary = StringBuffer()
      ..write('$title • ${amount.toStringAsFixed(2)} SAR')
      ..write(' on day $dayOfMonth each month');
    if (category != null) summary.write(' in $category');
    if (bankName != null) summary.write(' using $bankName');
    if (autoAdd) summary.write(' with auto-add enabled');

    return FinancialAssistantPendingAction(
      type: type,
      title: type == FinancialAssistantActionType.addRecurringPayment
          ? 'Add recurring payment'
          : 'Update recurring payment',
      summary: summary.toString(),
      data: <String, Object?>{
        'id': id,
        'title': title,
        'amount': amount,
        'dayOfMonth': dayOfMonth,
        'category': category,
        'bankName': bankName,
        'bankAccountId': bankAccountId,
        'autoAdd': autoAdd,
        'startDate': startDate,
      },
    );
  }

  FinancialAssistantPendingAction? _tryParseRemoveRecurringPayment(
    String normalized,
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
  ) {
    final hasIntent = _matchesAny(normalized, const <String>[
      'delete recurring',
      'remove recurring',
      'delete subscription',
      'remove subscription',
    ]);
    if (!hasIntent) return null;

    final payment = _findRecurringPayment(provider, normalized, context);
    if (payment == null) return null;

    return FinancialAssistantPendingAction(
      type: FinancialAssistantActionType.removeRecurringPayment,
      title: 'Remove recurring payment',
      summary: 'Delete recurring payment ${payment.title}',
      data: <String, Object?>{'id': payment.id, 'title': payment.title},
      destructive: true,
    );
  }

  FinancialAssistantSpendingSelection? _findSpendingSelection(
    SpendingProvider provider,
    String normalized,
    FinancialAssistantConversationContext context,
    DateTime now,
  ) {
    final matches = _findSpendingSelectionMatches(
      provider,
      normalized,
      context,
      now,
    );
    return matches.isEmpty ? null : matches.first;
  }

  List<FinancialAssistantSpendingSelection> _findSpendingSelectionMatches(
    SpendingProvider provider,
    String normalized,
    FinancialAssistantConversationContext context,
    DateTime now,
  ) {
    if (_matchesAny(normalized, const <String>['it', 'this', 'that']) &&
        context.lastSpendingSelection != null) {
      return <FinancialAssistantSpendingSelection>[
        context.lastSpendingSelection!,
      ];
    }

    final targetDate = _extractSpecificDate(normalized, now) ?? now;
    final dates = _dateHints(normalized, now)
        ? <DateTime>[targetDate]
        : provider.getRecordedSpendingDates();

    final amount = _parseFirstAmount(normalized);
    final category = _resolveCategory(provider, normalized);
    final bank = _resolveBank(provider, normalized);
    final itemPhrase = _extractReferencedSpendingPhrase(normalized);

    final scored = <MapEntry<FinancialAssistantSpendingSelection, int>>[];

    for (final date in dates) {
      final entries = provider.getEntriesForDate(date);
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        var score = 0;
        if (amount != null && (entry.amount - amount).abs() < 0.001) {
          score += 4;
        }
        if (category != null &&
            provider.categoryLabelOf(entry).toLowerCase() ==
                category.toLowerCase()) {
          score += 3;
        }
        if (bank != null &&
            (entry.bankAccountId == bank.id ||
                (entry.bank?.toLowerCase() == bank.name.toLowerCase()))) {
          score += 2;
        }
        if (itemPhrase != null &&
            entry.item != null &&
            entry.item!.toLowerCase().contains(itemPhrase)) {
          score += 5;
        }
        if (score > 0) {
          scored.add(
            MapEntry(
              FinancialAssistantSpendingSelection(
                date: date,
                index: i,
                entry: entry,
              ),
              score,
            ),
          );
        }
      }
    }

    if (scored.isEmpty) {
      return context.lastSpendingSelection == null
          ? const <FinancialAssistantSpendingSelection>[]
          : <FinancialAssistantSpendingSelection>[
              context.lastSpendingSelection!,
            ];
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    final bestScore = scored.first.value;
    final closeMatches = scored
        .where((entry) => entry.value == bestScore)
        .map((entry) => entry.key)
        .take(3)
        .toList();
    return closeMatches;
  }

  RecurringPayment? _findRecurringPayment(
    SpendingProvider provider,
    String normalized,
    FinancialAssistantConversationContext context,
  ) {
    if (_matchesAny(normalized, const <String>['it', 'this', 'that']) &&
        context.lastRecurringPaymentId != null) {
      for (final payment in provider.recurringPayments) {
        if (payment.id == context.lastRecurringPaymentId) return payment;
      }
    }

    RecurringPayment? best;
    var bestLength = -1;
    for (final payment in provider.recurringPayments) {
      final lower = payment.title.toLowerCase();
      if (normalized.contains(lower) && lower.length > bestLength) {
        best = payment;
        bestLength = lower.length;
      }
    }
    return best;
  }

  String? _extractReferencedSpendingPhrase(String normalized) {
    final match = RegExp(
      r"(?:change|edit|update|delete|remove)\s+(?:the\s+)?(.+?)(?:\s+to\s+\d|\s+from\s+\d|$)",
      caseSensitive: false,
    ).firstMatch(normalized);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    if (_matchesAny(value, const <String>['it', 'this', 'that'])) return null;
    return value;
  }

  String? _extractSpendingItem(String normalized, String? category) {
    final explicitMatch = RegExp(
      r'(?:the\s+)?(?:item|title|description)\s*(?:is|:)\s*([a-z0-9][a-z0-9\s&/-]{1,40}?)(?=(?:,\s*|\s+(?:and\s+)?(?:quantity|qty|category|bank)\s*(?:is|:)|$))',
      caseSensitive: false,
    ).firstMatch(normalized);
    final phraseMatch = RegExp(
      r'(?:for|on)\s+([a-z][a-z\s&/-]{2,40})',
      caseSensitive: false,
    ).firstMatch(normalized);
    final raw =
        explicitMatch?.group(1)?.trim() ?? phraseMatch?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (category != null && raw.toLowerCase() == category.toLowerCase()) {
      return null;
    }
    final cleaned = raw
        .split(RegExp(r'\s+(?:using|with|quantity|qty|category|bank)\s+'))
        .first
        .trim();
    if (cleaned.isEmpty) return null;
    return toBeginningOfSentenceCase(cleaned);
  }

  FinancialAssistantPendingAction preparePendingActionForEditing(
    FinancialAssistantPendingAction action,
  ) {
    switch (action.type) {
      case FinancialAssistantActionType.addSpending:
        return action.copyWith(
          data: <String, Object?>{
            ...action.data,
            'askedCategory': true,
            'askedItem': true,
            'askedQty': true,
            'askedBank': true,
          },
        );
      case FinancialAssistantActionType.addIncome:
        return action.copyWith(
          data: <String, Object?>{
            ...action.data,
            'askedSource': true,
            'askedNote': true,
          },
        );
      default:
        return action;
    }
  }

  String? _plainTextAnswer(String normalized) {
    final cleaned = normalized
        .replaceAll(RegExp(r'[^a-zA-Z0-9\\s&/-]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return null;
    return toBeginningOfSentenceCase(cleaned);
  }

  String? _extractRecurringTitle(String original) {
    final match = RegExp(
      r'(?:for|payment for|subscription for)\s+(.+?)(?:\s+\d|\s+on day|\s+using|$)',
      caseSensitive: false,
    ).firstMatch(original);
    final title = match?.group(1)?.trim();
    return title == null || title.isEmpty ? null : title;
  }

  int? _parseRecurringDayOfMonth(String normalized) {
    final dayMatch = RegExp(
      r'(?:on day|day)\s+(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(normalized);
    final value = int.tryParse(dayMatch?.group(1) ?? '');
    if (value != null && value >= 1 && value <= 31) return value;
    return null;
  }

  DateTime? _extractSpecificDate(String normalized, DateTime now) {
    final dateMatch = RegExp(
      r'\b(\d{4})-(\d{2})-(\d{2})\b',
    ).firstMatch(normalized);
    if (dateMatch != null) {
      final year = int.parse(dateMatch.group(1)!);
      final month = int.parse(dateMatch.group(2)!);
      final day = int.parse(dateMatch.group(3)!);
      return DateTime(year, month, day);
    }
    if (normalized.contains('yesterday')) {
      return DateTime(now.year, now.month, now.day - 1);
    }
    if (normalized.contains('today')) {
      return DateTime(now.year, now.month, now.day);
    }
    if (normalized.contains('last month')) {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      return DateTime(lastMonth.year, lastMonth.month, 1);
    }
    final naturalDateMatch = RegExp(
      r'\b(?:january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|october|oct|november|nov|december|dec)\s+\d{1,2}(?:,\s*\d{4})?\b',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (naturalDateMatch != null) {
      return _parseNaturalDateToken(naturalDateMatch.group(0)!, now);
    }
    return null;
  }

  bool _dateHints(String normalized, DateTime now) {
    return normalized.contains('today') ||
        normalized.contains('yesterday') ||
        normalized.contains('this week') ||
        normalized.contains('last week') ||
        normalized.contains('this month') ||
        normalized.contains('last month') ||
        RegExp(r'\b\d{4}-\d{2}-\d{2}\b').hasMatch(normalized) ||
        RegExp(
          r'\b(?:january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|october|oct|november|nov|december|dec)\s+\d{1,2}(?:,\s*\d{4})?\b',
          caseSensitive: false,
        ).hasMatch(normalized);
  }

  double? _parseFirstAmount(String input) {
    final match = RegExp(r'(\d[\d,]*(?:\.\d+)?)').firstMatch(input);
    final value = match?.group(1)?.replaceAll(',', '');
    if (value == null) return null;
    return double.tryParse(value);
  }

  double? _extractReplacementAmount(String normalized) {
    final toMatch = RegExp(
      r'(?:to|for)\s+(\d[\d,]*(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(normalized);
    final fromTo = toMatch?.group(1)?.replaceAll(',', '');
    if (fromTo != null) return double.tryParse(fromTo);
    return _parseFirstAmount(normalized);
  }

  String? _resolveCategory(SpendingProvider provider, String normalized) {
    String? best;
    for (final category in provider.getAllUsedCategories()) {
      final lower = category.toLowerCase();
      if (!normalized.contains(lower)) continue;
      if (best == null || lower.length > best.length) {
        best = category;
      }
    }
    return best;
  }

  String? _extractCategoryFromCommand(
    SpendingProvider provider,
    String normalized,
  ) {
    final explicitMatch = RegExp(
      r'(?:the\s+)?category\s*(?:is|:)\s*([a-z0-9][a-z0-9\s&/-]{1,40}?)(?=(?:,\s*|\s+(?:and\s+)?(?:item|title|description|quantity|qty|bank)\s*(?:is|:)|$))',
      caseSensitive: false,
    ).firstMatch(normalized);
    final explicit = explicitMatch?.group(1)?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return toBeginningOfSentenceCase(explicit);
    }

    final resolved = _resolveCategory(provider, normalized);
    if (resolved != null) return resolved;

    final match = RegExp(
      r'\b(?:for|on)\s+([a-z][a-z\s&/-]{1,30})',
      caseSensitive: false,
    ).firstMatch(normalized);
    final raw = match?.group(1)?.trim();
    if (raw != null && raw.isNotEmpty) {
      if (raw.contains('using ') ||
          raw.contains('with ') ||
          raw.contains('from ')) {
        return toBeginningOfSentenceCase(
          raw.split(RegExp(r'\s+(?:using|with|from)\s+')).first.trim(),
        );
      }
      return toBeginningOfSentenceCase(raw);
    }
    return null;
  }

  String? _extractBankNameFromCommand(String normalized) {
    final explicitMatch = RegExp(
      r'(?:the\s+)?bank\s*(?:is|:)\s*([a-z0-9][a-z0-9\s&/-]{1,40}?)(?=(?:,\s*|$))',
      caseSensitive: false,
    ).firstMatch(normalized);
    final explicit = explicitMatch?.group(1)?.trim();
    if (explicit == null || explicit.isEmpty) return null;
    return toBeginningOfSentenceCase(explicit);
  }

  BankAccount? _resolveBank(SpendingProvider provider, String normalized) {
    BankAccount? best;
    for (final bank in provider.bankAccounts) {
      final bankName = bank.name.toLowerCase();
      if (normalized.contains(bankName)) {
        if (best == null || bankName.length > best.name.length) {
          best = bank;
        }
      }
    }
    return best;
  }

  BankAccount? _findBankByName(SpendingProvider provider, String name) {
    final normalized = name.trim().toLowerCase();
    for (final bank in provider.bankAccounts) {
      if (bank.name.trim().toLowerCase() == normalized) return bank;
    }
    return null;
  }

  _MerchantMemoryMatch? _findMerchantMemory(
    SpendingProvider provider,
    String item,
  ) {
    final normalizedItem = item.trim().toLowerCase();
    if (normalizedItem.isEmpty) return null;

    final dates = provider.getRecordedSpendingDates().toList()
      ..sort((a, b) => b.compareTo(a));

    for (final date in dates) {
      final entries = provider.getEntriesForDate(date);
      for (var i = entries.length - 1; i >= 0; i--) {
        final entry = entries[i];
        final entryItem = entry.item?.trim().toLowerCase();
        if (entryItem == null || entryItem.isEmpty) continue;
        if (entryItem != normalizedItem) continue;
        return _MerchantMemoryMatch(
          category: provider.categoryLabelOf(entry),
          bankName: entry.bank,
          bankAccountId: entry.bankAccountId,
        );
      }
    }

    return null;
  }

  MapEntry<DateTime, double>? _findHighestSpendingDay(
    SpendingProvider provider,
  ) {
    final totals = provider.getDailyTotalsForPeriod();
    if (totals.isEmpty) return null;
    return totals.reduce((a, b) => a.value >= b.value ? a : b);
  }

  double _sumForPeriod(SpendingProvider provider, {String? category}) {
    if (!provider.hasPeriod ||
        provider.periodStart == null ||
        provider.periodEnd == null) {
      return 0;
    }
    final dates = provider.getRecordedSpendingDates(
      start: provider.periodStart!,
      end: provider.periodEnd!,
    );
    var total = 0.0;
    for (final date in dates) {
      for (final entry in provider.getEntriesForDate(date)) {
        if (category != null &&
            provider.categoryLabelOf(entry).toLowerCase() !=
                category.toLowerCase()) {
          continue;
        }
        total += entry.amount;
      }
    }
    return total;
  }

  double _sumForMonth(
    SpendingProvider provider,
    int year,
    int month, {
    String? category,
  }) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final dates = provider.getRecordedSpendingDates(start: start, end: end);
    var total = 0.0;
    for (final date in dates) {
      for (final entry in provider.getEntriesForDate(date)) {
        if (category != null &&
            provider.categoryLabelOf(entry).toLowerCase() !=
                category.toLowerCase()) {
          continue;
        }
        total += entry.amount;
      }
    }
    return total;
  }

  List<FinancialAssistantFact> _buildSpendingFacts({
    required DateTime date,
    required double amount,
    String? category,
    String? bankName,
    String? item,
    int? qty,
  }) {
    return <FinancialAssistantFact>[
      FinancialAssistantFact(
        label: 'Amount',
        value: '${amount.toStringAsFixed(2)} SAR',
      ),
      if (item != null) FinancialAssistantFact(label: 'Title', value: item),
      if (category != null)
        FinancialAssistantFact(label: 'Category', value: category),
      FinancialAssistantFact(
        label: 'Quantity',
        value: qty == null ? '1 (default)' : '$qty',
      ),
      FinancialAssistantFact(
        label: 'Date',
        value: DateFormat('yyyy-MM-dd').format(date),
      ),
      if (bankName != null)
        FinancialAssistantFact(label: 'Bank', value: bankName),
    ];
  }

  List<FinancialAssistantFact> _buildIncomeFacts({
    required DateTime date,
    required double amount,
    String? source,
    String? note,
  }) {
    return <FinancialAssistantFact>[
      FinancialAssistantFact(
        label: 'Amount',
        value: '${amount.toStringAsFixed(2)} SAR',
      ),
      if (source != null)
        FinancialAssistantFact(label: 'Source', value: source),
      if (note != null) FinancialAssistantFact(label: 'Note', value: note),
      FinancialAssistantFact(
        label: 'Date',
        value: DateFormat('yyyy-MM-dd').format(date),
      ),
    ];
  }

  List<FinancialAssistantFact> _buildRecurringFacts({
    required String title,
    required double amount,
    required int dayOfMonth,
    String? category,
    String? bankName,
    required bool autoAdd,
  }) {
    return <FinancialAssistantFact>[
      FinancialAssistantFact(label: 'Title', value: title),
      FinancialAssistantFact(
        label: 'Amount',
        value: '${amount.toStringAsFixed(2)} SAR',
      ),
      FinancialAssistantFact(label: 'Day of month', value: '$dayOfMonth'),
      if (category != null)
        FinancialAssistantFact(label: 'Category', value: category),
      if (bankName != null)
        FinancialAssistantFact(label: 'Bank', value: bankName),
      FinancialAssistantFact(
        label: 'Auto add',
        value: autoAdd ? 'Enabled' : 'Disabled',
      ),
    ];
  }

  FinancialAssistantReply? _tryHandleFlexibleReadOnlyQuery(
    String normalized,
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
    DateTime now,
    BudgetGuidanceSnapshot guidance,
  ) {
    final affordabilityReply = _tryHandleNaturalAffordabilityQuery(
      normalized,
      context,
      guidance,
    );
    if (affordabilityReply != null) return affordabilityReply;

    final spendingHistoryReply = _tryHandleNaturalSpendingHistoryQuery(
      normalized,
      provider,
      context,
      now,
    );
    if (spendingHistoryReply != null) return spendingHistoryReply;

    final recurringReply = _tryHandleNaturalRecurringGuidanceQuery(
      normalized,
      context,
      guidance,
    );
    if (recurringReply != null) return recurringReply;

    final budgetReply = _tryHandleNaturalBudgetGuidanceQuery(
      normalized,
      context,
      guidance,
    );
    if (budgetReply != null) return budgetReply;

    return null;
  }

  FinancialAssistantReply? _tryHandleNaturalAffordabilityQuery(
    String normalized,
    FinancialAssistantConversationContext context,
    BudgetGuidanceSnapshot guidance,
  ) {
    final hasAmount = _parseFirstAmount(normalized) != null;
    final isFollowUpAmount =
        RegExp(r'^(?:what about|how about)\s+\d').hasMatch(normalized) ||
        (context.lastQueryKind == _AssistantQueryKind.affordability &&
            RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized));
    final hasAffordabilityCue =
        normalized.contains('afford') ||
        normalized.contains('enough') ||
        normalized.contains('okay if i') ||
        normalized.contains('what happens if i spend') ||
        normalized.contains('what happens if i pay') ||
        normalized.contains('put me over budget') ||
        normalized.contains('over budget') ||
        normalized.contains('can i pay') ||
        normalized.contains('can i spend') ||
        normalized.contains('would spending') ||
        normalized.contains('would paying');

    if (!(hasAmount && hasAffordabilityCue) && !isFollowUpAmount) {
      return null;
    }

    final amount = _parseFirstAmount(normalized) ?? context.lastRequestedAmount;
    if (amount == null) return null;

    return _buildAffordabilityReply(
      amount: amount,
      guidance: guidance,
      context: context.copyWith(
        lastQueryKind: _AssistantQueryKind.affordability,
        lastRequestedAmount: amount,
        lastQueryLabel: 'today',
      ),
    );
  }

  FinancialAssistantReply? _tryHandleNaturalRecurringGuidanceQuery(
    String normalized,
    FinancialAssistantConversationContext context,
    BudgetGuidanceSnapshot guidance,
  ) {
    final asksAboutRecurringCommitments =
        normalized.contains('recurring') ||
        normalized.contains('bills') ||
        normalized.contains('upcoming payments') ||
        normalized.contains('upcoming payment') ||
        normalized.contains('reserve for') ||
        normalized.contains('keep for') ||
        normalized.contains('left after recurring') ||
        normalized.contains('safely spend until');
    if (!asksAboutRecurringCommitments) return null;

    return _buildRecurringCommitmentReply(
      guidance: guidance,
      context: context.copyWith(
        lastQueryKind: _AssistantQueryKind.spendingHistory,
        lastQueryLabel: 'recurring commitments',
      ),
    );
  }

  FinancialAssistantReply? _tryHandleNaturalBudgetGuidanceQuery(
    String normalized,
    FinancialAssistantConversationContext context,
    BudgetGuidanceSnapshot guidance,
  ) {
    final asksAboutTodayAllowance =
        normalized.contains('today') &&
        (normalized.contains('how much can i') ||
            normalized.contains('what can i') ||
            normalized.contains('how much do i have') ||
            normalized.contains('how much is left') ||
            normalized.contains('today budget') ||
            normalized.contains('today available') ||
            normalized.contains('daily allowance'));
    if (asksAboutTodayAllowance) {
      return _buildTodayAllowanceReply(
        guidance: guidance,
        context: context.copyWith(
          lastQueryKind: _AssistantQueryKind.affordability,
          lastQueryLabel: 'today',
        ),
      );
    }

    final asksAboutRemainingBudget =
        normalized.contains('remaining budget') ||
        normalized.contains('budget left') ||
        normalized.contains('how much am i over budget') ||
        (normalized.contains('how much') && normalized.contains('over budget'));
    if (asksAboutRemainingBudget) {
      return _buildRemainingBudgetReply(
        guidance: guidance,
        context: context.copyWith(
          lastQueryKind: _AssistantQueryKind.affordability,
          lastQueryLabel: 'budget status',
        ),
      );
    }

    final asksAboutBudgetStatus =
        normalized.contains('am i over budget') ||
        normalized.contains('am i within budget') ||
        normalized.contains('am i on track') ||
        normalized.contains('budget status') ||
        normalized.contains('ahead of budget') ||
        normalized.contains('behind my budget');
    if (asksAboutBudgetStatus) {
      return _buildBudgetStatusReply(
        guidance: guidance,
        context: context.copyWith(
          lastQueryKind: _AssistantQueryKind.affordability,
          lastQueryLabel: 'budget status',
        ),
      );
    }

    final asksAboutRecovery =
        normalized.contains('recover from') ||
        normalized.contains('overspending') ||
        normalized.contains('overspent') ||
        normalized.contains('positive daily allowance') ||
        normalized.contains('allowance becomes positive again') ||
        normalized.contains('allowance is positive again') ||
        normalized.contains('reduce my daily spending') ||
        (normalized.contains('following day') &&
            normalized.contains('tomorrow'));
    if (asksAboutRecovery) {
      return _buildRecoveryReply(
        normalized,
        guidance: guidance,
        context: context.copyWith(
          lastQueryKind: _AssistantQueryKind.affordability,
          lastQueryLabel: 'recovery',
        ),
      );
    }

    return null;
  }

  FinancialAssistantReply? _tryHandleNaturalSpendingHistoryQuery(
    String normalized,
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
    DateTime now,
  ) {
    final mentionsSpending =
        normalized.contains('spent') ||
        normalized.contains('spending') ||
        normalized.contains('pay') ||
        normalized.contains('paid') ||
        normalized.contains('purchase') ||
        normalized.contains('bought') ||
        normalized.contains("today's spending") ||
        normalized.contains('yesterday spending');
    final isFollowUp =
        normalized.startsWith('what about') ||
        normalized.startsWith('how about');
    if (!mentionsSpending &&
        !(isFollowUp &&
            context.lastQueryKind == _AssistantQueryKind.spendingHistory)) {
      return null;
    }

    final query = _buildSpendingHistoryQuery(
      normalized,
      provider,
      context,
      now,
    );
    if (query == null) return null;

    if (query.needsPeriodClarification) {
      return FinancialAssistantReply(
        message:
            'Which period would you like to check: today, yesterday, this week, last week, this month, or a specific date?',
        context: context,
      );
    }

    final range = query.dateRange;
    if (range == null) return null;

    final matches = _collectMatchingSpendings(
      provider,
      start: range.start,
      end: range.end,
      category: query.category,
      bankName: query.bank?.name,
    );
    final total = matches.fold(0.0, (sum, entry) => sum + entry.entry.amount);
    final descriptor = _describeSpendingQuery(
      range: range,
      category: query.category,
      bankName: query.bank?.name,
    );

    final updatedContext = context.copyWith(
      lastCategory: query.category,
      lastBankName: query.bank?.name,
      lastQueryKind: _AssistantQueryKind.spendingHistory,
      lastQueryStart: range.start,
      lastQueryEnd: range.end,
      lastQueryLabel: range.label,
    );

    if (matches.isEmpty) {
      return FinancialAssistantReply(
        message: 'I could not find any recorded spending for $descriptor.',
        context: updatedContext,
      );
    }

    final facts = <FinancialAssistantFact>[
      FinancialAssistantFact(
        label: 'Total spent',
        value: '${total.toStringAsFixed(2)} SAR',
        note:
            '${matches.length} entr${matches.length == 1 ? 'y' : 'ies'} in $descriptor',
      ),
      if (query.category != null)
        FinancialAssistantFact(label: 'Category', value: query.category!),
      if (query.bank != null)
        FinancialAssistantFact(label: 'Bank', value: query.bank!.name),
    ];

    if (query.wantsEntryBreakdown) {
      facts.addAll(
        matches
            .take(4)
            .map(
              (selection) => FinancialAssistantFact(
                label:
                    selection.entry.item ??
                    provider.categoryLabelOf(selection.entry),
                value: '${selection.entry.amount.toStringAsFixed(2)} SAR',
                note: DateFormat('yyyy-MM-dd').format(selection.date),
              ),
            ),
      );
    }

    return FinancialAssistantReply(
      message: query.wantsEntryBreakdown
          ? 'Here is the spending I found for $descriptor.'
          : 'You spent ${total.toStringAsFixed(2)} SAR for $descriptor.',
      facts: facts,
      context: updatedContext.copyWith(
        lastSpendingSelection: matches.isEmpty ? null : matches.last,
        clearSpendingSelection: matches.isEmpty,
      ),
    );
  }

  _SpendingHistoryQuery? _buildSpendingHistoryQuery(
    String normalized,
    SpendingProvider provider,
    FinancialAssistantConversationContext context,
    DateTime now,
  ) {
    final range = _extractDateRange(normalized, now, context: context);
    final category =
        _resolveCategory(provider, normalized) ??
        (normalized.startsWith('what about') ? context.lastCategory : null);
    final bank =
        _resolveBank(provider, normalized) ??
        ((normalized.startsWith('what about') ||
                    normalized.startsWith('how about')) &&
                context.lastBankName != null
            ? _findBankByName(provider, context.lastBankName!)
            : null);
    final wantsEntryBreakdown =
        normalized.contains('what did i spend') ||
        normalized.contains('show my spending') ||
        normalized.contains("today's spending") ||
        normalized.contains("yesterday's spending");

    final missingRange =
        range == null &&
        (normalized.contains('how much did i spend') ||
            normalized.contains('what did i spend') ||
            normalized.contains('show my spending') ||
            normalized.contains('spent on') ||
            normalized.contains('spending on') ||
            normalized.contains("today's spending") ||
            normalized.contains("yesterday's spending"));
    if (missingRange) {
      return const _SpendingHistoryQuery(needsPeriodClarification: true);
    }

    if (range == null &&
        context.lastQueryKind == _AssistantQueryKind.spendingHistory &&
        context.lastQueryStart != null &&
        context.lastQueryEnd != null &&
        (category != null || bank != null)) {
      return _SpendingHistoryQuery(
        dateRange: _AssistantDateRange(
          start: context.lastQueryStart!,
          end: context.lastQueryEnd!,
          label: context.lastQueryLabel ?? 'the same period',
        ),
        category: category ?? context.lastCategory,
        bank: bank,
        wantsEntryBreakdown: wantsEntryBreakdown,
      );
    }

    if (range == null) return null;
    return _SpendingHistoryQuery(
      dateRange: range,
      category: category,
      bank: bank,
      wantsEntryBreakdown: wantsEntryBreakdown,
    );
  }

  _AssistantDateRange? _extractDateRange(
    String normalized,
    DateTime now, {
    FinancialAssistantConversationContext? context,
  }) {
    final today = DateTime(now.year, now.month, now.day);

    if (normalized.contains('today')) {
      return _AssistantDateRange(start: today, end: today, label: 'today');
    }
    if (normalized.contains('yesterday')) {
      final yesterday = today.subtract(const Duration(days: 1));
      return _AssistantDateRange(
        start: yesterday,
        end: yesterday,
        label: 'yesterday',
      );
    }
    if (normalized.contains('this week')) {
      final start = today.subtract(Duration(days: today.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return _AssistantDateRange(start: start, end: end, label: 'this week');
    }
    if (normalized.contains('last week')) {
      final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
      final start = thisWeekStart.subtract(const Duration(days: 7));
      final end = start.add(const Duration(days: 6));
      return _AssistantDateRange(start: start, end: end, label: 'last week');
    }
    if (normalized.contains('this month')) {
      final start = DateTime(today.year, today.month, 1);
      final end = DateTime(today.year, today.month + 1, 0);
      return _AssistantDateRange(start: start, end: end, label: 'this month');
    }
    if (normalized.contains('last month')) {
      final start = DateTime(today.year, today.month - 1, 1);
      final end = DateTime(today.year, today.month, 0);
      return _AssistantDateRange(start: start, end: end, label: 'last month');
    }

    final explicitRangeMatch = RegExp(
      r'(?:from\s+)?((?:\d{4}-\d{2}-\d{2})|(?:[a-z]+\s+\d{1,2}(?:,\s*\d{4})?))\s+(?:to|through|until|-)\s+((?:\d{4}-\d{2}-\d{2})|(?:[a-z]+\s+\d{1,2}(?:,\s*\d{4})?))',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (explicitRangeMatch != null) {
      final start = _parseNaturalDateToken(explicitRangeMatch.group(1)!, now);
      final end = _parseNaturalDateToken(explicitRangeMatch.group(2)!, now);
      if (start != null && end != null) {
        final normalizedStart = start.isBefore(end) ? start : end;
        final normalizedEnd = start.isBefore(end) ? end : start;
        return _AssistantDateRange(
          start: normalizedStart,
          end: normalizedEnd,
          label:
              '${DateFormat('yyyy-MM-dd').format(normalizedStart)} to ${DateFormat('yyyy-MM-dd').format(normalizedEnd)}',
        );
      }
    }

    final specificDate = _extractSpecificDate(normalized, now);
    if (specificDate != null) {
      final dateOnly = DateTime(
        specificDate.year,
        specificDate.month,
        specificDate.day,
      );
      return _AssistantDateRange(
        start: dateOnly,
        end: dateOnly,
        label: DateFormat('yyyy-MM-dd').format(dateOnly),
      );
    }

    if ((normalized.startsWith('what about') ||
            normalized.startsWith('how about')) &&
        context?.lastQueryKind == _AssistantQueryKind.spendingHistory &&
        context?.lastQueryStart != null &&
        context?.lastQueryEnd != null) {
      return _AssistantDateRange(
        start: context!.lastQueryStart!,
        end: context.lastQueryEnd!,
        label: context.lastQueryLabel ?? 'the same period',
      );
    }

    return null;
  }

  DateTime? _parseNaturalDateToken(String raw, DateTime now) {
    final trimmed = raw.trim().toLowerCase();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return DateTime.tryParse(trimmed);
    }

    final match = RegExp(
      r'^(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|october|oct|november|nov|december|dec)\s+(\d{1,2})(?:,\s*(\d{4}))?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (match == null) return null;

    const months = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };
    final month = months[match.group(1)!.toLowerCase()];
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3) ?? '') ?? now.year;
    if (month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  List<FinancialAssistantSpendingSelection> _collectMatchingSpendings(
    SpendingProvider provider, {
    required DateTime start,
    required DateTime end,
    String? category,
    String? bankName,
  }) {
    final matches = <FinancialAssistantSpendingSelection>[];
    final dates = provider.getRecordedSpendingDates(start: start, end: end);
    for (final date in dates) {
      final entries = provider.getEntriesForDate(date);
      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        if (category != null &&
            provider.categoryLabelOf(entry).toLowerCase() !=
                category.toLowerCase()) {
          continue;
        }
        if (bankName != null &&
            (entry.bank ?? '').trim().toLowerCase() !=
                bankName.trim().toLowerCase()) {
          continue;
        }
        matches.add(
          FinancialAssistantSpendingSelection(
            date: date,
            index: i,
            entry: entry,
          ),
        );
      }
    }
    matches.sort((a, b) => b.date.compareTo(a.date));
    return matches;
  }

  String _describeSpendingQuery({
    required _AssistantDateRange range,
    String? category,
    String? bankName,
  }) {
    final parts = <String>[range.label];
    if (category != null) {
      parts.add('for ${category.toLowerCase()}');
    }
    if (bankName != null) {
      parts.add('using $bankName');
    }
    return parts.join(' ');
  }

  FinancialAssistantReply _buildRemainingBudgetReply({
    required BudgetGuidanceSnapshot guidance,
    required FinancialAssistantConversationContext context,
  }) {
    final remainingLabel = guidance.remainingBudget >= 0
        ? 'Remaining budget'
        : 'Over budget by';
    final message = guidance.remainingBudget >= 0
        ? guidance.upcomingRecurringTotal > 0
              ? 'You still have room in this budget period, but part of it should stay reserved for upcoming recurring payments.'
              : 'You still have room in this budget period.'
        : 'You are currently over your planned budget, so keeping the next few days lighter would help you recover.';

    final facts = <FinancialAssistantFact>[
      FinancialAssistantFact(
        label: remainingLabel,
        value: '${guidance.remainingBudget.abs().toStringAsFixed(2)} SAR',
        note: '${guidance.remainingDays} day(s) left in the active period',
      ),
      if (guidance.upcomingRecurringTotal > 0)
        FinancialAssistantFact(
          label: 'Reserved for upcoming payments',
          value: '${guidance.upcomingRecurringTotal.toStringAsFixed(2)} SAR',
          note:
              '${guidance.discretionaryRemaining.toStringAsFixed(2)} SAR left for flexible spending',
        ),
    ];

    return FinancialAssistantReply(
      message: message,
      facts: facts,
      context: context,
    );
  }

  FinancialAssistantReply _buildTodayAllowanceReply({
    required BudgetGuidanceSnapshot guidance,
    required FinancialAssistantConversationContext context,
  }) {
    final message = guidance.safeToSpendToday > 0
        ? guidance.upcomingRecurringTotal > 0
              ? 'Today you can still spend a little, and I am also keeping your upcoming recurring payments in mind.'
              : 'Today you still have some safe spending room.'
        : guidance.remainingTodayAllowance < 0
        ? 'You have already used today\'s allowance, so the safest move is to pause spending for the rest of the day.'
        : 'There is no extra room to spend today after keeping your remaining budget and upcoming payments in balance.';

    return FinancialAssistantReply(
      message: message,
      facts: <FinancialAssistantFact>[
        FinancialAssistantFact(
          label: 'Safe to spend today',
          value: '${guidance.safeToSpendToday.toStringAsFixed(2)} SAR',
          note:
              'Allowance: ${guidance.dailyAllowance.toStringAsFixed(2)} SAR • Spent today: ${guidance.spentToday.toStringAsFixed(2)} SAR',
        ),
        if (guidance.upcomingRecurringTotal > 0)
          FinancialAssistantFact(
            label: 'Upcoming payments to reserve',
            value: '${guidance.upcomingRecurringTotal.toStringAsFixed(2)} SAR',
            note:
                '${guidance.discretionaryRemaining.toStringAsFixed(2)} SAR remains for other spending this period',
          ),
      ],
      context: context,
    );
  }

  FinancialAssistantReply _buildBudgetStatusReply({
    required BudgetGuidanceSnapshot guidance,
    required FinancialAssistantConversationContext context,
  }) {
    final message = guidance.remainingBudget >= 0
        ? guidance.upcomingRecurringTotal > 0
              ? 'You are still within budget, although some of that room should stay reserved for upcoming recurring payments.'
              : 'You are currently within budget and still have some flexibility left.'
        : guidance.overBudgetAmount >= guidance.baseDailyBudget * 2
        ? 'You are meaningfully over budget right now, so cutting back on discretionary spending for a few days would help.'
        : 'You are slightly over budget right now, and a lighter couple of days should help you recover.';

    return FinancialAssistantReply(
      message: message,
      facts: <FinancialAssistantFact>[
        FinancialAssistantFact(
          label: guidance.remainingBudget >= 0
              ? 'Budget remaining'
              : 'Over budget by',
          value: '${guidance.remainingBudget.abs().toStringAsFixed(2)} SAR',
        ),
        FinancialAssistantFact(
          label: 'Safe today',
          value: '${guidance.safeToSpendToday.toStringAsFixed(2)} SAR',
          note: '${guidance.remainingDays} day(s) left in the active period',
        ),
        if (guidance.upcomingRecurringTotal > 0)
          FinancialAssistantFact(
            label: 'Upcoming recurring payments',
            value: '${guidance.upcomingRecurringTotal.toStringAsFixed(2)} SAR',
          ),
      ],
      context: context,
    );
  }

  FinancialAssistantReply _buildRecurringCommitmentReply({
    required BudgetGuidanceSnapshot guidance,
    required FinancialAssistantConversationContext context,
  }) {
    if (guidance.upcomingRecurringPayments.isEmpty) {
      return FinancialAssistantReply(
        message:
            'There are no upcoming recurring payments left in the active budget period, so your remaining budget is fully flexible.',
        facts: <FinancialAssistantFact>[
          FinancialAssistantFact(
            label: 'Flexible remaining budget',
            value: '${guidance.remainingBudget.toStringAsFixed(2)} SAR',
          ),
        ],
        context: context,
      );
    }

    final facts = <FinancialAssistantFact>[
      FinancialAssistantFact(
        label: 'Keep reserved',
        value: '${guidance.upcomingRecurringTotal.toStringAsFixed(2)} SAR',
        note:
            '${guidance.discretionaryRemaining.toStringAsFixed(2)} SAR stays available for other spending',
      ),
      ...guidance.upcomingRecurringPayments
          .take(4)
          .map(
            (payment) => FinancialAssistantFact(
              label: payment.title,
              value: '${payment.amount.toStringAsFixed(2)} SAR',
              note: 'Due ${DateFormat('yyyy-MM-dd').format(payment.dueDate)}',
            ),
          ),
    ];

    return FinancialAssistantReply(
      message:
          'You still have recurring payments coming up this period, so it is worth reserving that money before planning extra spending.',
      facts: facts,
      context: context.copyWith(
        lastRecurringPaymentId:
            guidance.upcomingRecurringPayments.first.paymentId,
        lastRecurringPaymentTitle:
            guidance.upcomingRecurringPayments.first.title,
        lastCategory: guidance.upcomingRecurringPayments.first.category,
        lastBankName: guidance.upcomingRecurringPayments.first.bank,
      ),
    );
  }

  FinancialAssistantReply _buildRecoveryReply(
    String normalized, {
    required BudgetGuidanceSnapshot guidance,
    required FinancialAssistantConversationContext context,
  }) {
    if (normalized.contains('following day')) {
      return FinancialAssistantReply(
        message:
            'If you avoid spending tomorrow, your allowance should recover further the day after.',
        facts: <FinancialAssistantFact>[
          FinancialAssistantFact(
            label: 'Tomorrow allowance',
            value:
                '${guidance.tomorrowAllowanceIfNoMoreSpending.toStringAsFixed(2)} SAR',
          ),
          FinancialAssistantFact(
            label: 'Following day allowance',
            value:
                '${guidance.followingDayAllowanceIfNoSpendingTomorrow.toStringAsFixed(2)} SAR',
          ),
        ],
        context: context,
      );
    }

    if (normalized.contains('reduce my daily spending')) {
      return FinancialAssistantReply(
        message: guidance.recommendedDailyCap > 0
            ? 'To stay on track, try keeping your average flexible spending around this level for the rest of the period.'
            : 'Right now there is no flexible room left after covering your budget position and upcoming commitments, so cutting discretionary spending to zero would be the safest path.',
        facts: <FinancialAssistantFact>[
          FinancialAssistantFact(
            label: 'Recommended daily cap',
            value: '${guidance.recommendedDailyCap.toStringAsFixed(2)} SAR',
          ),
          FinancialAssistantFact(
            label: 'Reduction from normal daily budget',
            value: '${guidance.dailyReductionNeeded.toStringAsFixed(2)} SAR',
            note:
                'Base daily budget: ${guidance.baseDailyBudget.toStringAsFixed(2)} SAR',
          ),
        ],
        context: context,
      );
    }

    final recoveryMessage = guidance.safeToSpendToday > 0
        ? 'You already have positive spending room today, so recovery has effectively started.'
        : guidance.recoveryDays == null
        ? 'Even if you pause discretionary spending, this budget period may stay tight because the current deficit is larger than the remaining daily recovery room.'
        : guidance.recoveryDays == 1
        ? 'A light day should help your allowance turn positive again tomorrow.'
        : 'It will take a few lighter days for your allowance to turn positive again.';

    return FinancialAssistantReply(
      message: recoveryMessage,
      facts: <FinancialAssistantFact>[
        FinancialAssistantFact(
          label: 'Current deficit',
          value:
              '${(guidance.remainingTodayAllowance < 0 ? -guidance.remainingTodayAllowance : 0).toStringAsFixed(2)} SAR',
          note:
              'Today allowance remaining after spending: ${guidance.remainingTodayAllowance.toStringAsFixed(2)} SAR',
        ),
        FinancialAssistantFact(
          label: 'Normal daily budget',
          value: '${guidance.baseDailyBudget.toStringAsFixed(2)} SAR',
        ),
        FinancialAssistantFact(
          label: 'Safe to spend today',
          value: '${guidance.safeToSpendToday.toStringAsFixed(2)} SAR',
        ),
        FinancialAssistantFact(
          label: 'Recovery time',
          value: guidance.recoveryDays == null
              ? 'Not within this period'
              : '${guidance.recoveryDays} day(s)',
          note:
              'Allowance after recovery: ${guidance.projectedAllowanceAfterRecovery.toStringAsFixed(2)} SAR',
        ),
      ],
      context: context,
    );
  }

  FinancialAssistantReply _buildAffordabilityReply({
    required double amount,
    required BudgetGuidanceSnapshot guidance,
    required FinancialAssistantConversationContext context,
  }) {
    final canAffordToday = amount <= guidance.safeToSpendToday + 0.001;
    final message = canAffordToday
        ? guidance.upcomingRecurringTotal > 0
              ? 'Yes, that amount fits today without pushing past the room left after reserving your upcoming recurring payments.'
              : 'Yes, that amount fits within today\'s safe spending room.'
        : guidance.safeToSpendToday <= 0
        ? 'That would push you beyond the safe room available today.'
        : 'That amount is higher than the safe room available today.';

    return FinancialAssistantReply(
      message: message,
      facts: <FinancialAssistantFact>[
        FinancialAssistantFact(
          label: 'Requested amount',
          value: '${amount.toStringAsFixed(2)} SAR',
        ),
        FinancialAssistantFact(
          label: 'Safe to spend today',
          value: '${guidance.safeToSpendToday.toStringAsFixed(2)} SAR',
          note: canAffordToday
              ? '${(guidance.safeToSpendToday - amount).toStringAsFixed(2)} SAR would still remain today'
              : 'Short by ${(amount - guidance.safeToSpendToday).toStringAsFixed(2)} SAR',
        ),
        if (guidance.upcomingRecurringTotal > 0)
          FinancialAssistantFact(
            label: 'Reserved for upcoming payments',
            value: '${guidance.upcomingRecurringTotal.toStringAsFixed(2)} SAR',
          ),
      ],
      context: context,
    );
  }

  FinancialAssistantReply? _tryBuildUndoReply(
    String normalized,
    FinancialAssistantConversationContext context,
  ) {
    if (!_matchesAny(normalized, const <String>['undo', 'revert'])) {
      return null;
    }
    final undoAction = context.lastUndoAction;
    if (undoAction == null) {
      return FinancialAssistantReply(
        message: 'There is no recent assistant action available to undo.',
        context: context,
      );
    }
    return _replyWithAction(
      message:
          'I can undo the last assistant action. Please confirm to continue.',
      context: context.copyWith(lastPendingAction: undoAction),
      action: undoAction,
    );
  }

  FinancialAssistantPendingAction _buildUndoAction(
    FinancialAssistantPendingAction action,
    String summary,
  ) {
    return FinancialAssistantPendingAction(
      type: FinancialAssistantActionType.undoLastAction,
      title: 'Undo last action',
      summary: summary,
      data: <String, Object?>{'action': action},
      destructive: true,
    );
  }

  FinancialAssistantSpendingSelection? _resolveSpendingOptionSelection(
    String normalized,
    List<FinancialAssistantSpendingSelection> options,
  ) {
    final numericMatch = RegExp(r'(\d+)').firstMatch(normalized);
    if (numericMatch != null) {
      final selectedIndex = int.tryParse(numericMatch.group(1)!);
      if (selectedIndex != null &&
          selectedIndex >= 1 &&
          selectedIndex <= options.length) {
        return options[selectedIndex - 1];
      }
    }

    for (final option in options) {
      final item = option.entry.item?.toLowerCase();
      final category = option.entry.category?.toLowerCase();
      if (item != null && normalized.contains(item)) return option;
      if (category != null && normalized.contains(category)) return option;
    }
    return null;
  }

  String _buildSelectionOptionsMessage(
    List<FinancialAssistantSpendingSelection> options, {
    required String actionLabel,
  }) {
    final lines = <String>[
      'I found more than one matching transaction. Which one would you like to $actionLabel?',
    ];
    for (var i = 0; i < options.length; i++) {
      final option = options[i];
      final label =
          option.entry.item ?? option.entry.category ?? 'Spending entry';
      lines.add(
        '${i + 1}. $label - ${option.entry.amount.toStringAsFixed(2)} SAR on ${DateFormat('yyyy-MM-dd').format(option.date)}',
      );
    }
    return lines.join('\n');
  }

  bool _looksLikeStructuredSpendingMessage(
    String normalized,
    SpendingProvider provider,
  ) {
    if (_parseFirstAmount(normalized) == null) return false;

    final hasCategoryCue =
        normalized.contains('category') ||
        _resolveCategory(provider, normalized) != null;
    final hasItemCue = normalized.contains('item');
    final hasQuantityCue =
        normalized.contains('quantity') ||
        normalized.contains('qty') ||
        RegExp(r'\bx\d+\b').hasMatch(normalized);
    final hasBankCue =
        normalized.contains('bank') ||
        _resolveBank(provider, normalized) != null;

    final cueCount = <bool>[
      hasCategoryCue,
      hasItemCue,
      hasQuantityCue,
      hasBankCue,
    ].where((value) => value).length;

    return cueCount >= 2;
  }

  bool _looksLikeExportRequest(String normalized) {
    return (normalized.contains('export') || normalized.contains('pdf')) &&
        normalized.contains('report');
  }

  bool _matchesAny(String text, List<String> patterns) {
    for (final pattern in patterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isSkipResponse(String normalized) {
    return normalized == 'skip' ||
        normalized == 'skip it' ||
        normalized == 'no' ||
        normalized == 'none';
  }

  String? _extractIncomeSource(String normalized) {
    final match = RegExp(
      r'(?:from|salary from|income from)\s+([a-z][a-z0-9\s&/-]{1,40})',
      caseSensitive: false,
    ).firstMatch(normalized);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;
    final cleaned = raw.split(RegExp(r'\s+(?:note|for)\s+')).first.trim();
    return cleaned.isEmpty ? null : toBeginningOfSentenceCase(cleaned);
  }

  String? _extractIncomeNote(String normalized, String? source) {
    final match = RegExp(
      r'(?:note|for)\s+([a-z][a-z0-9\s&/-]{1,60})',
      caseSensitive: false,
    ).firstMatch(normalized);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (source != null && raw.toLowerCase() == source.toLowerCase())
      return null;
    return toBeginningOfSentenceCase(raw);
  }

  int? _parseQuantity(String normalized, {bool allowBareNumber = false}) {
    final explicit = RegExp(
      r'(?:qty|quantity)\s*(?:is|:)?\s*(\d+)|\bx\s*(\d+)\b',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (explicit != null) {
      return int.tryParse(explicit.group(1) ?? explicit.group(2) ?? '');
    }

    if (allowBareNumber && RegExp(r'^\d+$').hasMatch(normalized)) {
      final parsed = int.tryParse(normalized);
      if (parsed != null && parsed > 0) return parsed;
    }

    final numericPhrase = RegExp(
      r'\b(\d+)\s+[a-z]',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (numericPhrase != null) {
      final parsed = int.tryParse(numericPhrase.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }

    const words = <String, int>{
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
    };
    for (final entry in words.entries) {
      if (normalized.contains('${entry.key} ')) return entry.value;
    }
    return null;
  }
}
