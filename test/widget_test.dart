import 'package:flutter_test/flutter_test.dart';
import 'package:personal_spendings/providers/spending_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('spending mutations keep linked bank balances in sync', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = SpendingProvider();
    const account = BankAccount(id: 'bank_1', name: 'Main Bank', balance: 1000);

    await provider.setBankAccounts([account]);
    await provider.addSpendingForDate(
      DateTime(2026, 5, 18),
      100,
      bank: account.name,
      bankAccountId: account.id,
    );

    expect(provider.getBankAccountById(account.id)?.balance, 900);

    await provider.updateEntryForDate(
      date: DateTime(2026, 5, 18),
      index: 0,
      amount: 150,
      bank: account.name,
      bankAccountId: account.id,
    );

    expect(provider.getBankAccountById(account.id)?.balance, 850);

    await provider.removeEntryForDate(date: DateTime(2026, 5, 18), index: 0);

    expect(provider.getBankAccountById(account.id)?.balance, 1000);
  });
}
