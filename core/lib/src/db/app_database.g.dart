// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CycleEventsTable extends CycleEvents
    with TableInfo<$CycleEventsTable, CycleEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CycleEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CycleEventType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CycleEventType>($CycleEventsTable.$convertertype);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, type, date, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cycle_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<CycleEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CycleEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CycleEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: $CycleEventsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CycleEventsTable createAlias(String alias) {
    return $CycleEventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CycleEventType, String, String> $convertertype =
      const EnumNameConverter<CycleEventType>(CycleEventType.values);
}

class CycleEvent extends DataClass implements Insertable<CycleEvent> {
  final int id;
  final CycleEventType type;
  final DateTime date;
  final DateTime createdAt;
  const CycleEvent({
    required this.id,
    required this.type,
    required this.date,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['type'] = Variable<String>(
        $CycleEventsTable.$convertertype.toSql(type),
      );
    }
    map['date'] = Variable<DateTime>(date);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CycleEventsCompanion toCompanion(bool nullToAbsent) {
    return CycleEventsCompanion(
      id: Value(id),
      type: Value(type),
      date: Value(date),
      createdAt: Value(createdAt),
    );
  }

  factory CycleEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CycleEvent(
      id: serializer.fromJson<int>(json['id']),
      type: $CycleEventsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      date: serializer.fromJson<DateTime>(json['date']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(
        $CycleEventsTable.$convertertype.toJson(type),
      ),
      'date': serializer.toJson<DateTime>(date),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CycleEvent copyWith({
    int? id,
    CycleEventType? type,
    DateTime? date,
    DateTime? createdAt,
  }) => CycleEvent(
    id: id ?? this.id,
    type: type ?? this.type,
    date: date ?? this.date,
    createdAt: createdAt ?? this.createdAt,
  );
  CycleEvent copyWithCompanion(CycleEventsCompanion data) {
    return CycleEvent(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      date: data.date.present ? data.date.value : this.date,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CycleEvent(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, date, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CycleEvent &&
          other.id == this.id &&
          other.type == this.type &&
          other.date == this.date &&
          other.createdAt == this.createdAt);
}

class CycleEventsCompanion extends UpdateCompanion<CycleEvent> {
  final Value<int> id;
  final Value<CycleEventType> type;
  final Value<DateTime> date;
  final Value<DateTime> createdAt;
  const CycleEventsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.date = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CycleEventsCompanion.insert({
    this.id = const Value.absent(),
    required CycleEventType type,
    required DateTime date,
    this.createdAt = const Value.absent(),
  }) : type = Value(type),
       date = Value(date);
  static Insertable<CycleEvent> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<DateTime>? date,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (date != null) 'date': date,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CycleEventsCompanion copyWith({
    Value<int>? id,
    Value<CycleEventType>? type,
    Value<DateTime>? date,
    Value<DateTime>? createdAt,
  }) {
    return CycleEventsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $CycleEventsTable.$convertertype.toSql(type.value),
      );
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CycleEventsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('date: $date, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PeriodsTable extends Periods with TableInfo<$PeriodsTable, Period> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeriodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startDate,
    endDate,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'periods';
  @override
  VerificationContext validateIntegrity(
    Insertable<Period> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Period map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Period(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PeriodsTable createAlias(String alias) {
    return $PeriodsTable(attachedDatabase, alias);
  }
}

class Period extends DataClass implements Insertable<Period> {
  final int id;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Period({
    required this.id,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PeriodsCompanion toCompanion(bool nullToAbsent) {
    return PeriodsCompanion(
      id: Value(id),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Period.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Period(
      id: serializer.fromJson<int>(json['id']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Period copyWith({
    int? id,
    DateTime? startDate,
    Value<DateTime?> endDate = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Period(
    id: id ?? this.id,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Period copyWithCompanion(PeriodsCompanion data) {
    return Period(
      id: data.id.present ? data.id.value : this.id,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Period(')
          ..write('id: $id, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, startDate, endDate, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Period &&
          other.id == this.id &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PeriodsCompanion extends UpdateCompanion<Period> {
  final Value<int> id;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const PeriodsCompanion({
    this.id = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PeriodsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startDate,
    this.endDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : startDate = Value(startDate);
  static Insertable<Period> custom({
    Expression<int>? id,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PeriodsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? startDate,
    Value<DateTime?>? endDate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return PeriodsCompanion(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeriodsCompanion(')
          ..write('id: $id, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DailyFlowsTable extends DailyFlows
    with TableInfo<$DailyFlowsTable, DailyFlow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyFlowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FlowIntensity, String> intensity =
      GeneratedColumn<String>(
        'intensity',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FlowIntensity>($DailyFlowsTable.$converterintensity);
  @override
  late final GeneratedColumnWithTypeConverter<ClotSize?, String> clotSize =
      GeneratedColumn<String>(
        'clot_size',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<ClotSize?>($DailyFlowsTable.$converterclotSizen);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    intensity,
    clotSize,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_flows';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyFlow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  DailyFlow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyFlow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      intensity: $DailyFlowsTable.$converterintensity.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}intensity'],
        )!,
      ),
      clotSize: $DailyFlowsTable.$converterclotSizen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}clot_size'],
        ),
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DailyFlowsTable createAlias(String alias) {
    return $DailyFlowsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FlowIntensity, String, String> $converterintensity =
      const EnumNameConverter<FlowIntensity>(FlowIntensity.values);
  static JsonTypeConverter2<ClotSize, String, String> $converterclotSize =
      const EnumNameConverter<ClotSize>(ClotSize.values);
  static JsonTypeConverter2<ClotSize?, String?, String?> $converterclotSizen =
      JsonTypeConverter2.asNullable($converterclotSize);
}

class DailyFlow extends DataClass implements Insertable<DailyFlow> {
  /// Calendar date, time-of-day zeroed on write. Primary key.
  final DateTime date;
  final FlowIntensity intensity;
  final ClotSize? clotSize;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DailyFlow({
    required this.date,
    required this.intensity,
    this.clotSize,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    {
      map['intensity'] = Variable<String>(
        $DailyFlowsTable.$converterintensity.toSql(intensity),
      );
    }
    if (!nullToAbsent || clotSize != null) {
      map['clot_size'] = Variable<String>(
        $DailyFlowsTable.$converterclotSizen.toSql(clotSize),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DailyFlowsCompanion toCompanion(bool nullToAbsent) {
    return DailyFlowsCompanion(
      date: Value(date),
      intensity: Value(intensity),
      clotSize: clotSize == null && nullToAbsent
          ? const Value.absent()
          : Value(clotSize),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DailyFlow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyFlow(
      date: serializer.fromJson<DateTime>(json['date']),
      intensity: $DailyFlowsTable.$converterintensity.fromJson(
        serializer.fromJson<String>(json['intensity']),
      ),
      clotSize: $DailyFlowsTable.$converterclotSizen.fromJson(
        serializer.fromJson<String?>(json['clotSize']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'intensity': serializer.toJson<String>(
        $DailyFlowsTable.$converterintensity.toJson(intensity),
      ),
      'clotSize': serializer.toJson<String?>(
        $DailyFlowsTable.$converterclotSizen.toJson(clotSize),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DailyFlow copyWith({
    DateTime? date,
    FlowIntensity? intensity,
    Value<ClotSize?> clotSize = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DailyFlow(
    date: date ?? this.date,
    intensity: intensity ?? this.intensity,
    clotSize: clotSize.present ? clotSize.value : this.clotSize,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DailyFlow copyWithCompanion(DailyFlowsCompanion data) {
    return DailyFlow(
      date: data.date.present ? data.date.value : this.date,
      intensity: data.intensity.present ? data.intensity.value : this.intensity,
      clotSize: data.clotSize.present ? data.clotSize.value : this.clotSize,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyFlow(')
          ..write('date: $date, ')
          ..write('intensity: $intensity, ')
          ..write('clotSize: $clotSize, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(date, intensity, clotSize, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyFlow &&
          other.date == this.date &&
          other.intensity == this.intensity &&
          other.clotSize == this.clotSize &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DailyFlowsCompanion extends UpdateCompanion<DailyFlow> {
  final Value<DateTime> date;
  final Value<FlowIntensity> intensity;
  final Value<ClotSize?> clotSize;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DailyFlowsCompanion({
    this.date = const Value.absent(),
    this.intensity = const Value.absent(),
    this.clotSize = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyFlowsCompanion.insert({
    required DateTime date,
    required FlowIntensity intensity,
    this.clotSize = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       intensity = Value(intensity);
  static Insertable<DailyFlow> custom({
    Expression<DateTime>? date,
    Expression<String>? intensity,
    Expression<String>? clotSize,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (intensity != null) 'intensity': intensity,
      if (clotSize != null) 'clot_size': clotSize,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyFlowsCompanion copyWith({
    Value<DateTime>? date,
    Value<FlowIntensity>? intensity,
    Value<ClotSize?>? clotSize,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DailyFlowsCompanion(
      date: date ?? this.date,
      intensity: intensity ?? this.intensity,
      clotSize: clotSize ?? this.clotSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (intensity.present) {
      map['intensity'] = Variable<String>(
        $DailyFlowsTable.$converterintensity.toSql(intensity.value),
      );
    }
    if (clotSize.present) {
      map['clot_size'] = Variable<String>(
        $DailyFlowsTable.$converterclotSizen.toSql(clotSize.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyFlowsCompanion(')
          ..write('date: $date, ')
          ..write('intensity: $intensity, ')
          ..write('clotSize: $clotSize, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SymptomTypesTable extends SymptomTypes
    with TableInfo<$SymptomTypesTable, SymptomType> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SymptomTypesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sortOrder,
    isBuiltIn,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'symptom_types';
  @override
  VerificationContext validateIntegrity(
    Insertable<SymptomType> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SymptomType map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SymptomType(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SymptomTypesTable createAlias(String alias) {
    return $SymptomTypesTable(attachedDatabase, alias);
  }
}

class SymptomType extends DataClass implements Insertable<SymptomType> {
  final int id;
  final String name;

  /// Ascending display order in the pickers and the manage screen.
  final int sortOrder;

  /// `true` for the names seeded by [kBuiltInSymptomNames]. Purely cosmetic —
  /// built-ins can still be renamed, reordered and archived.
  final bool isBuiltIn;

  /// Set when the user removes the symptom; `null` while it is active.
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SymptomType({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isBuiltIn,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SymptomTypesCompanion toCompanion(bool nullToAbsent) {
    return SymptomTypesCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
      isBuiltIn: Value(isBuiltIn),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SymptomType.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SymptomType(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SymptomType copyWith({
    int? id,
    String? name,
    int? sortOrder,
    bool? isBuiltIn,
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SymptomType(
    id: id ?? this.id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SymptomType copyWithCompanion(SymptomTypesCompanion data) {
    return SymptomType(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SymptomType(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sortOrder,
    isBuiltIn,
    archivedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SymptomType &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.isBuiltIn == this.isBuiltIn &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SymptomTypesCompanion extends UpdateCompanion<SymptomType> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<bool> isBuiltIn;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SymptomTypesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SymptomTypesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int sortOrder,
    this.isBuiltIn = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name),
       sortOrder = Value(sortOrder);
  static Insertable<SymptomType> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<bool>? isBuiltIn,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SymptomTypesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<bool>? isBuiltIn,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return SymptomTypesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SymptomTypesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DailySymptomEntriesTable extends DailySymptomEntries
    with TableInfo<$DailySymptomEntriesTable, DailySymptomEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailySymptomEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _symptomTypeIdMeta = const VerificationMeta(
    'symptomTypeId',
  );
  @override
  late final GeneratedColumn<int> symptomTypeId = GeneratedColumn<int>(
    'symptom_type_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [date, symptomTypeId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_symptom_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailySymptomEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('symptom_type_id')) {
      context.handle(
        _symptomTypeIdMeta,
        symptomTypeId.isAcceptableOrUnknown(
          data['symptom_type_id']!,
          _symptomTypeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_symptomTypeIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date, symptomTypeId};
  @override
  DailySymptomEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailySymptomEntry(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      symptomTypeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}symptom_type_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DailySymptomEntriesTable createAlias(String alias) {
    return $DailySymptomEntriesTable(attachedDatabase, alias);
  }
}

class DailySymptomEntry extends DataClass
    implements Insertable<DailySymptomEntry> {
  /// Calendar date, time-of-day zeroed on write.
  final DateTime date;
  final int symptomTypeId;
  final DateTime createdAt;
  const DailySymptomEntry({
    required this.date,
    required this.symptomTypeId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    map['symptom_type_id'] = Variable<int>(symptomTypeId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DailySymptomEntriesCompanion toCompanion(bool nullToAbsent) {
    return DailySymptomEntriesCompanion(
      date: Value(date),
      symptomTypeId: Value(symptomTypeId),
      createdAt: Value(createdAt),
    );
  }

  factory DailySymptomEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailySymptomEntry(
      date: serializer.fromJson<DateTime>(json['date']),
      symptomTypeId: serializer.fromJson<int>(json['symptomTypeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'symptomTypeId': serializer.toJson<int>(symptomTypeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DailySymptomEntry copyWith({
    DateTime? date,
    int? symptomTypeId,
    DateTime? createdAt,
  }) => DailySymptomEntry(
    date: date ?? this.date,
    symptomTypeId: symptomTypeId ?? this.symptomTypeId,
    createdAt: createdAt ?? this.createdAt,
  );
  DailySymptomEntry copyWithCompanion(DailySymptomEntriesCompanion data) {
    return DailySymptomEntry(
      date: data.date.present ? data.date.value : this.date,
      symptomTypeId: data.symptomTypeId.present
          ? data.symptomTypeId.value
          : this.symptomTypeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailySymptomEntry(')
          ..write('date: $date, ')
          ..write('symptomTypeId: $symptomTypeId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, symptomTypeId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailySymptomEntry &&
          other.date == this.date &&
          other.symptomTypeId == this.symptomTypeId &&
          other.createdAt == this.createdAt);
}

class DailySymptomEntriesCompanion extends UpdateCompanion<DailySymptomEntry> {
  final Value<DateTime> date;
  final Value<int> symptomTypeId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DailySymptomEntriesCompanion({
    this.date = const Value.absent(),
    this.symptomTypeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailySymptomEntriesCompanion.insert({
    required DateTime date,
    required int symptomTypeId,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       symptomTypeId = Value(symptomTypeId);
  static Insertable<DailySymptomEntry> custom({
    Expression<DateTime>? date,
    Expression<int>? symptomTypeId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (symptomTypeId != null) 'symptom_type_id': symptomTypeId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailySymptomEntriesCompanion copyWith({
    Value<DateTime>? date,
    Value<int>? symptomTypeId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DailySymptomEntriesCompanion(
      date: date ?? this.date,
      symptomTypeId: symptomTypeId ?? this.symptomTypeId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (symptomTypeId.present) {
      map['symptom_type_id'] = Variable<int>(symptomTypeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailySymptomEntriesCompanion(')
          ..write('date: $date, ')
          ..write('symptomTypeId: $symptomTypeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CycleEventsTable cycleEvents = $CycleEventsTable(this);
  late final $PeriodsTable periods = $PeriodsTable(this);
  late final $DailyFlowsTable dailyFlows = $DailyFlowsTable(this);
  late final $SymptomTypesTable symptomTypes = $SymptomTypesTable(this);
  late final $DailySymptomEntriesTable dailySymptomEntries =
      $DailySymptomEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cycleEvents,
    periods,
    dailyFlows,
    symptomTypes,
    dailySymptomEntries,
  ];
}

typedef $$CycleEventsTableCreateCompanionBuilder =
    CycleEventsCompanion Function({
      Value<int> id,
      required CycleEventType type,
      required DateTime date,
      Value<DateTime> createdAt,
    });
typedef $$CycleEventsTableUpdateCompanionBuilder =
    CycleEventsCompanion Function({
      Value<int> id,
      Value<CycleEventType> type,
      Value<DateTime> date,
      Value<DateTime> createdAt,
    });

class $$CycleEventsTableFilterComposer
    extends Composer<_$AppDatabase, $CycleEventsTable> {
  $$CycleEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CycleEventType, CycleEventType, String>
  get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CycleEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $CycleEventsTable> {
  $$CycleEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CycleEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CycleEventsTable> {
  $$CycleEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CycleEventType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CycleEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CycleEventsTable,
          CycleEvent,
          $$CycleEventsTableFilterComposer,
          $$CycleEventsTableOrderingComposer,
          $$CycleEventsTableAnnotationComposer,
          $$CycleEventsTableCreateCompanionBuilder,
          $$CycleEventsTableUpdateCompanionBuilder,
          (
            CycleEvent,
            BaseReferences<_$AppDatabase, $CycleEventsTable, CycleEvent>,
          ),
          CycleEvent,
          PrefetchHooks Function()
        > {
  $$CycleEventsTableTableManager(_$AppDatabase db, $CycleEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CycleEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CycleEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CycleEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<CycleEventType> type = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CycleEventsCompanion(
                id: id,
                type: type,
                date: date,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required CycleEventType type,
                required DateTime date,
                Value<DateTime> createdAt = const Value.absent(),
              }) => CycleEventsCompanion.insert(
                id: id,
                type: type,
                date: date,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CycleEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CycleEventsTable,
      CycleEvent,
      $$CycleEventsTableFilterComposer,
      $$CycleEventsTableOrderingComposer,
      $$CycleEventsTableAnnotationComposer,
      $$CycleEventsTableCreateCompanionBuilder,
      $$CycleEventsTableUpdateCompanionBuilder,
      (
        CycleEvent,
        BaseReferences<_$AppDatabase, $CycleEventsTable, CycleEvent>,
      ),
      CycleEvent,
      PrefetchHooks Function()
    >;
typedef $$PeriodsTableCreateCompanionBuilder =
    PeriodsCompanion Function({
      Value<int> id,
      required DateTime startDate,
      Value<DateTime?> endDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$PeriodsTableUpdateCompanionBuilder =
    PeriodsCompanion Function({
      Value<int> id,
      Value<DateTime> startDate,
      Value<DateTime?> endDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$PeriodsTableFilterComposer
    extends Composer<_$AppDatabase, $PeriodsTable> {
  $$PeriodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeriodsTableOrderingComposer
    extends Composer<_$AppDatabase, $PeriodsTable> {
  $$PeriodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeriodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeriodsTable> {
  $$PeriodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PeriodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeriodsTable,
          Period,
          $$PeriodsTableFilterComposer,
          $$PeriodsTableOrderingComposer,
          $$PeriodsTableAnnotationComposer,
          $$PeriodsTableCreateCompanionBuilder,
          $$PeriodsTableUpdateCompanionBuilder,
          (Period, BaseReferences<_$AppDatabase, $PeriodsTable, Period>),
          Period,
          PrefetchHooks Function()
        > {
  $$PeriodsTableTableManager(_$AppDatabase db, $PeriodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeriodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeriodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeriodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PeriodsCompanion(
                id: id,
                startDate: startDate,
                endDate: endDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime startDate,
                Value<DateTime?> endDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PeriodsCompanion.insert(
                id: id,
                startDate: startDate,
                endDate: endDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeriodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeriodsTable,
      Period,
      $$PeriodsTableFilterComposer,
      $$PeriodsTableOrderingComposer,
      $$PeriodsTableAnnotationComposer,
      $$PeriodsTableCreateCompanionBuilder,
      $$PeriodsTableUpdateCompanionBuilder,
      (Period, BaseReferences<_$AppDatabase, $PeriodsTable, Period>),
      Period,
      PrefetchHooks Function()
    >;
typedef $$DailyFlowsTableCreateCompanionBuilder =
    DailyFlowsCompanion Function({
      required DateTime date,
      required FlowIntensity intensity,
      Value<ClotSize?> clotSize,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$DailyFlowsTableUpdateCompanionBuilder =
    DailyFlowsCompanion Function({
      Value<DateTime> date,
      Value<FlowIntensity> intensity,
      Value<ClotSize?> clotSize,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DailyFlowsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyFlowsTable> {
  $$DailyFlowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FlowIntensity, FlowIntensity, String>
  get intensity => $composableBuilder(
    column: $table.intensity,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<ClotSize?, ClotSize, String> get clotSize =>
      $composableBuilder(
        column: $table.clotSize,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyFlowsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyFlowsTable> {
  $$DailyFlowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intensity => $composableBuilder(
    column: $table.intensity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clotSize => $composableBuilder(
    column: $table.clotSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyFlowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyFlowsTable> {
  $$DailyFlowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FlowIntensity, String> get intensity =>
      $composableBuilder(column: $table.intensity, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ClotSize?, String> get clotSize =>
      $composableBuilder(column: $table.clotSize, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DailyFlowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyFlowsTable,
          DailyFlow,
          $$DailyFlowsTableFilterComposer,
          $$DailyFlowsTableOrderingComposer,
          $$DailyFlowsTableAnnotationComposer,
          $$DailyFlowsTableCreateCompanionBuilder,
          $$DailyFlowsTableUpdateCompanionBuilder,
          (
            DailyFlow,
            BaseReferences<_$AppDatabase, $DailyFlowsTable, DailyFlow>,
          ),
          DailyFlow,
          PrefetchHooks Function()
        > {
  $$DailyFlowsTableTableManager(_$AppDatabase db, $DailyFlowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyFlowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyFlowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyFlowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<FlowIntensity> intensity = const Value.absent(),
                Value<ClotSize?> clotSize = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyFlowsCompanion(
                date: date,
                intensity: intensity,
                clotSize: clotSize,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required FlowIntensity intensity,
                Value<ClotSize?> clotSize = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyFlowsCompanion.insert(
                date: date,
                intensity: intensity,
                clotSize: clotSize,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyFlowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyFlowsTable,
      DailyFlow,
      $$DailyFlowsTableFilterComposer,
      $$DailyFlowsTableOrderingComposer,
      $$DailyFlowsTableAnnotationComposer,
      $$DailyFlowsTableCreateCompanionBuilder,
      $$DailyFlowsTableUpdateCompanionBuilder,
      (DailyFlow, BaseReferences<_$AppDatabase, $DailyFlowsTable, DailyFlow>),
      DailyFlow,
      PrefetchHooks Function()
    >;
typedef $$SymptomTypesTableCreateCompanionBuilder =
    SymptomTypesCompanion Function({
      Value<int> id,
      required String name,
      required int sortOrder,
      Value<bool> isBuiltIn,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$SymptomTypesTableUpdateCompanionBuilder =
    SymptomTypesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> sortOrder,
      Value<bool> isBuiltIn,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$SymptomTypesTableFilterComposer
    extends Composer<_$AppDatabase, $SymptomTypesTable> {
  $$SymptomTypesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SymptomTypesTableOrderingComposer
    extends Composer<_$AppDatabase, $SymptomTypesTable> {
  $$SymptomTypesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SymptomTypesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SymptomTypesTable> {
  $$SymptomTypesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SymptomTypesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SymptomTypesTable,
          SymptomType,
          $$SymptomTypesTableFilterComposer,
          $$SymptomTypesTableOrderingComposer,
          $$SymptomTypesTableAnnotationComposer,
          $$SymptomTypesTableCreateCompanionBuilder,
          $$SymptomTypesTableUpdateCompanionBuilder,
          (
            SymptomType,
            BaseReferences<_$AppDatabase, $SymptomTypesTable, SymptomType>,
          ),
          SymptomType,
          PrefetchHooks Function()
        > {
  $$SymptomTypesTableTableManager(_$AppDatabase db, $SymptomTypesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SymptomTypesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SymptomTypesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SymptomTypesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SymptomTypesCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                isBuiltIn: isBuiltIn,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int sortOrder,
                Value<bool> isBuiltIn = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SymptomTypesCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                isBuiltIn: isBuiltIn,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SymptomTypesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SymptomTypesTable,
      SymptomType,
      $$SymptomTypesTableFilterComposer,
      $$SymptomTypesTableOrderingComposer,
      $$SymptomTypesTableAnnotationComposer,
      $$SymptomTypesTableCreateCompanionBuilder,
      $$SymptomTypesTableUpdateCompanionBuilder,
      (
        SymptomType,
        BaseReferences<_$AppDatabase, $SymptomTypesTable, SymptomType>,
      ),
      SymptomType,
      PrefetchHooks Function()
    >;
typedef $$DailySymptomEntriesTableCreateCompanionBuilder =
    DailySymptomEntriesCompanion Function({
      required DateTime date,
      required int symptomTypeId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$DailySymptomEntriesTableUpdateCompanionBuilder =
    DailySymptomEntriesCompanion Function({
      Value<DateTime> date,
      Value<int> symptomTypeId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$DailySymptomEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DailySymptomEntriesTable> {
  $$DailySymptomEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get symptomTypeId => $composableBuilder(
    column: $table.symptomTypeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailySymptomEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DailySymptomEntriesTable> {
  $$DailySymptomEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get symptomTypeId => $composableBuilder(
    column: $table.symptomTypeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailySymptomEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailySymptomEntriesTable> {
  $$DailySymptomEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get symptomTypeId => $composableBuilder(
    column: $table.symptomTypeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DailySymptomEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailySymptomEntriesTable,
          DailySymptomEntry,
          $$DailySymptomEntriesTableFilterComposer,
          $$DailySymptomEntriesTableOrderingComposer,
          $$DailySymptomEntriesTableAnnotationComposer,
          $$DailySymptomEntriesTableCreateCompanionBuilder,
          $$DailySymptomEntriesTableUpdateCompanionBuilder,
          (
            DailySymptomEntry,
            BaseReferences<
              _$AppDatabase,
              $DailySymptomEntriesTable,
              DailySymptomEntry
            >,
          ),
          DailySymptomEntry,
          PrefetchHooks Function()
        > {
  $$DailySymptomEntriesTableTableManager(
    _$AppDatabase db,
    $DailySymptomEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailySymptomEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailySymptomEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DailySymptomEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<int> symptomTypeId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailySymptomEntriesCompanion(
                date: date,
                symptomTypeId: symptomTypeId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required int symptomTypeId,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailySymptomEntriesCompanion.insert(
                date: date,
                symptomTypeId: symptomTypeId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailySymptomEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailySymptomEntriesTable,
      DailySymptomEntry,
      $$DailySymptomEntriesTableFilterComposer,
      $$DailySymptomEntriesTableOrderingComposer,
      $$DailySymptomEntriesTableAnnotationComposer,
      $$DailySymptomEntriesTableCreateCompanionBuilder,
      $$DailySymptomEntriesTableUpdateCompanionBuilder,
      (
        DailySymptomEntry,
        BaseReferences<
          _$AppDatabase,
          $DailySymptomEntriesTable,
          DailySymptomEntry
        >,
      ),
      DailySymptomEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CycleEventsTableTableManager get cycleEvents =>
      $$CycleEventsTableTableManager(_db, _db.cycleEvents);
  $$PeriodsTableTableManager get periods =>
      $$PeriodsTableTableManager(_db, _db.periods);
  $$DailyFlowsTableTableManager get dailyFlows =>
      $$DailyFlowsTableTableManager(_db, _db.dailyFlows);
  $$SymptomTypesTableTableManager get symptomTypes =>
      $$SymptomTypesTableTableManager(_db, _db.symptomTypes);
  $$DailySymptomEntriesTableTableManager get dailySymptomEntries =>
      $$DailySymptomEntriesTableTableManager(_db, _db.dailySymptomEntries);
}
