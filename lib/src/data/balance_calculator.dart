/// Inputs already resolved by the operator/backend according to the existing
/// Excel/SQL rules. This client does not infer shifts or holiday coverage.
class BalanceInputs {
  final String localUserId;
  final int dasInitial;
  final int dasGenerated;
  final int dasTaken;
  final Iterable<HolidayEntitlement> holidayEntitlements;

  const BalanceInputs({
    required this.localUserId,
    required this.dasInitial,
    required this.dasGenerated,
    required this.dasTaken,
    required this.holidayEntitlements,
  });
}

/// A holiday entitlement after applying the source rules.
/// `enjoyed` is nullable when coverage has not been resolved.
class HolidayEntitlement {
  final DateTime date;
  final String scope;
  final bool? enjoyed;

  const HolidayEntitlement({
    required this.date,
    required this.scope,
    required this.enjoyed,
  });
}

class ComputedBalance {
  final int dasAvailable;
  final int? dfAvailable;

  const ComputedBalance({
    required this.dasAvailable,
    required this.dfAvailable,
  });
}

/// Computes balances without changing the existing snapshot read path.
/// Missing holiday coverage deliberately produces an unknown DF value.
ComputedBalance computeBalance(BalanceInputs input) {
  if (input.localUserId == 'u5' && input.dasInitial != 0) {
    throw ArgumentError('La baseline DAS de u5 debe ser 0.');
  }
  if (input.dasInitial < 0 || input.dasGenerated < 0 || input.dasTaken < 0) {
    throw ArgumentError('Los valores DAS no pueden ser negativos.');
  }
  final holidays = input.holidayEntitlements.toList(growable: false);
  final hasUnknownCoverage = holidays.any((holiday) => holiday.enjoyed == null);
  return ComputedBalance(
    dasAvailable: input.dasInitial + input.dasGenerated - input.dasTaken,
    dfAvailable: hasUnknownCoverage
        ? null
        : holidays.where((holiday) => holiday.enjoyed == false).length,
  );
}
