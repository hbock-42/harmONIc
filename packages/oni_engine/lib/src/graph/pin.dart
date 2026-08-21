import '../model/units.dart';

/// The single thing the user fixes; everything else is derived from it.
sealed class Pin {
  const Pin({required this.nodeId});

  factory Pin.fromJson(Map<String, dynamic> json) {
    final nodeId = json['nodeId'] as String;
    return switch (json['type'] as String) {
      'buildingCount' =>
        BuildingCountPin(nodeId: nodeId, count: (json['count'] as num).toDouble()),
      'portRate' => PortRatePin(
          nodeId: nodeId,
          portId: json['portId'] as String,
          ratePerSecond: (json['ratePerSecond'] as num).toDouble(),
        ),
      'stock' => StockPin(
          nodeId: nodeId,
          portId: json['portId'] as String,
          amount: (json['amount'] as num).toDouble(),
          durationSeconds: (json['durationSeconds'] as num).toDouble(),
        ),
      final other => throw FormatException('Unknown pin type "$other"'),
    };
  }

  final String nodeId;

  /// Human-readable, for the UI badge.
  String describe();

  Map<String, dynamic> toJson();
}

/// "I have 3 Electrolyzers." Also "I have 20 dupes", "I have 6 Sleet Wheat".
class BuildingCountPin extends Pin {
  const BuildingCountPin({required super.nodeId, required this.count});

  final double count;

  @override
  String describe() => '${count.toStringAsFixed(2)} ×';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'buildingCount',
        'nodeId': nodeId,
        'count': count,
      };
}

/// "I have 10 kg/s of water here" or "I want 1000 g/s of oxygen out of here".
class PortRatePin extends Pin {
  const PortRatePin({
    required super.nodeId,
    required this.portId,
    required this.ratePerSecond,
  });

  final String portId;
  final double ratePerSecond;

  @override
  String describe() => '$portId = $ratePerSecond/s';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'portRate',
        'nodeId': nodeId,
        'portId': portId,
        'ratePerSecond': ratePerSecond,
      };
}

/// "I have 20 t of algae and I want it to last 30 cycles." Converted to a rate.
class StockPin extends Pin {
  const StockPin({
    required super.nodeId,
    required this.portId,
    required this.amount,
    required this.durationSeconds,
  });

  /// In the item's base unit (grams for mass).
  final double amount;
  final String portId;
  final double durationSeconds;

  double get ratePerSecond => amount / durationSeconds;

  @override
  String describe() =>
      '$amount over ${(durationSeconds / secondsPerCycle).toStringAsFixed(1)} cycles';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'stock',
        'nodeId': nodeId,
        'portId': portId,
        'amount': amount,
        'durationSeconds': durationSeconds,
      };
}
