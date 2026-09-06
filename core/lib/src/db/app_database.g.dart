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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    date,
    intensity,
    clotSize,
    source,
    externalId,
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
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
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
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
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

  /// Provenance (schema v7, p6.1). `'manual'` for a value the user logged in
  /// olf; `'appleHealth'` / `'healthConnect'` for a day imported over a
  /// `HealthPlatformGateway`. Stored as the `HealthDataSource` enum name; kept
  /// as plain text so the DB layer stays decoupled from the health model.
  final String source;

  /// The health platform's stable identifier for the imported sample, so a
  /// later sync matches instead of duplicating. `null` for manual rows.
  /// (schema v7, p6.1)
  final String? externalId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DailyFlow({
    required this.date,
    required this.intensity,
    this.clotSize,
    required this.source,
    this.externalId,
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
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || externalId != null) {
      map['external_id'] = Variable<String>(externalId);
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
      source: Value(source),
      externalId: externalId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalId),
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
      source: serializer.fromJson<String>(json['source']),
      externalId: serializer.fromJson<String?>(json['externalId']),
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
      'source': serializer.toJson<String>(source),
      'externalId': serializer.toJson<String?>(externalId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DailyFlow copyWith({
    DateTime? date,
    FlowIntensity? intensity,
    Value<ClotSize?> clotSize = const Value.absent(),
    String? source,
    Value<String?> externalId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DailyFlow(
    date: date ?? this.date,
    intensity: intensity ?? this.intensity,
    clotSize: clotSize.present ? clotSize.value : this.clotSize,
    source: source ?? this.source,
    externalId: externalId.present ? externalId.value : this.externalId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DailyFlow copyWithCompanion(DailyFlowsCompanion data) {
    return DailyFlow(
      date: data.date.present ? data.date.value : this.date,
      intensity: data.intensity.present ? data.intensity.value : this.intensity,
      clotSize: data.clotSize.present ? data.clotSize.value : this.clotSize,
      source: data.source.present ? data.source.value : this.source,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
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
          ..write('source: $source, ')
          ..write('externalId: $externalId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    date,
    intensity,
    clotSize,
    source,
    externalId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyFlow &&
          other.date == this.date &&
          other.intensity == this.intensity &&
          other.clotSize == this.clotSize &&
          other.source == this.source &&
          other.externalId == this.externalId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DailyFlowsCompanion extends UpdateCompanion<DailyFlow> {
  final Value<DateTime> date;
  final Value<FlowIntensity> intensity;
  final Value<ClotSize?> clotSize;
  final Value<String> source;
  final Value<String?> externalId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DailyFlowsCompanion({
    this.date = const Value.absent(),
    this.intensity = const Value.absent(),
    this.clotSize = const Value.absent(),
    this.source = const Value.absent(),
    this.externalId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyFlowsCompanion.insert({
    required DateTime date,
    required FlowIntensity intensity,
    this.clotSize = const Value.absent(),
    this.source = const Value.absent(),
    this.externalId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       intensity = Value(intensity);
  static Insertable<DailyFlow> custom({
    Expression<DateTime>? date,
    Expression<String>? intensity,
    Expression<String>? clotSize,
    Expression<String>? source,
    Expression<String>? externalId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (intensity != null) 'intensity': intensity,
      if (clotSize != null) 'clot_size': clotSize,
      if (source != null) 'source': source,
      if (externalId != null) 'external_id': externalId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyFlowsCompanion copyWith({
    Value<DateTime>? date,
    Value<FlowIntensity>? intensity,
    Value<ClotSize?>? clotSize,
    Value<String>? source,
    Value<String?>? externalId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DailyFlowsCompanion(
      date: date ?? this.date,
      intensity: intensity ?? this.intensity,
      clotSize: clotSize ?? this.clotSize,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
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
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
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
          ..write('source: $source, ')
          ..write('externalId: $externalId, ')
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

class $BbtEntriesTable extends BbtEntries
    with TableInfo<$BbtEntriesTable, BbtEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BbtEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tempCelsiusMeta = const VerificationMeta(
    'tempCelsius',
  );
  @override
  late final GeneratedColumn<double> tempCelsius = GeneratedColumn<double>(
    'temp_celsius',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    date,
    tempCelsius,
    source,
    externalId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bbt_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BbtEntry> instance, {
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
    if (data.containsKey('temp_celsius')) {
      context.handle(
        _tempCelsiusMeta,
        tempCelsius.isAcceptableOrUnknown(
          data['temp_celsius']!,
          _tempCelsiusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tempCelsiusMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
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
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  BbtEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BbtEntry(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      tempCelsius: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temp_celsius'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
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
  $BbtEntriesTable createAlias(String alias) {
    return $BbtEntriesTable(attachedDatabase, alias);
  }
}

class BbtEntry extends DataClass implements Insertable<BbtEntry> {
  /// Calendar date, time-of-day zeroed on write. Primary key.
  final DateTime date;

  /// Basal temperature in °C. Plausible range is enforced in the repository
  /// (`validateCelsius`), not by a DB constraint.
  final double tempCelsius;

  /// Provenance (schema v7, p6.1). `'manual'` for a value the user logged in
  /// olf; `'appleHealth'` / `'healthConnect'` for a reading imported over a
  /// `HealthPlatformGateway`. Stored as the `HealthDataSource` enum name; kept
  /// as plain text so the DB layer stays decoupled from the health model.
  final String source;

  /// The health platform's stable identifier for the imported sample, so a
  /// later sync matches instead of duplicating. `null` for manual rows.
  /// (schema v7, p6.1)
  final String? externalId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BbtEntry({
    required this.date,
    required this.tempCelsius,
    required this.source,
    this.externalId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    map['temp_celsius'] = Variable<double>(tempCelsius);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || externalId != null) {
      map['external_id'] = Variable<String>(externalId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BbtEntriesCompanion toCompanion(bool nullToAbsent) {
    return BbtEntriesCompanion(
      date: Value(date),
      tempCelsius: Value(tempCelsius),
      source: Value(source),
      externalId: externalId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BbtEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BbtEntry(
      date: serializer.fromJson<DateTime>(json['date']),
      tempCelsius: serializer.fromJson<double>(json['tempCelsius']),
      source: serializer.fromJson<String>(json['source']),
      externalId: serializer.fromJson<String?>(json['externalId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<DateTime>(date),
      'tempCelsius': serializer.toJson<double>(tempCelsius),
      'source': serializer.toJson<String>(source),
      'externalId': serializer.toJson<String?>(externalId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BbtEntry copyWith({
    DateTime? date,
    double? tempCelsius,
    String? source,
    Value<String?> externalId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BbtEntry(
    date: date ?? this.date,
    tempCelsius: tempCelsius ?? this.tempCelsius,
    source: source ?? this.source,
    externalId: externalId.present ? externalId.value : this.externalId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BbtEntry copyWithCompanion(BbtEntriesCompanion data) {
    return BbtEntry(
      date: data.date.present ? data.date.value : this.date,
      tempCelsius: data.tempCelsius.present
          ? data.tempCelsius.value
          : this.tempCelsius,
      source: data.source.present ? data.source.value : this.source,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BbtEntry(')
          ..write('date: $date, ')
          ..write('tempCelsius: $tempCelsius, ')
          ..write('source: $source, ')
          ..write('externalId: $externalId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(date, tempCelsius, source, externalId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BbtEntry &&
          other.date == this.date &&
          other.tempCelsius == this.tempCelsius &&
          other.source == this.source &&
          other.externalId == this.externalId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BbtEntriesCompanion extends UpdateCompanion<BbtEntry> {
  final Value<DateTime> date;
  final Value<double> tempCelsius;
  final Value<String> source;
  final Value<String?> externalId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BbtEntriesCompanion({
    this.date = const Value.absent(),
    this.tempCelsius = const Value.absent(),
    this.source = const Value.absent(),
    this.externalId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BbtEntriesCompanion.insert({
    required DateTime date,
    required double tempCelsius,
    this.source = const Value.absent(),
    this.externalId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       tempCelsius = Value(tempCelsius);
  static Insertable<BbtEntry> custom({
    Expression<DateTime>? date,
    Expression<double>? tempCelsius,
    Expression<String>? source,
    Expression<String>? externalId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (tempCelsius != null) 'temp_celsius': tempCelsius,
      if (source != null) 'source': source,
      if (externalId != null) 'external_id': externalId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BbtEntriesCompanion copyWith({
    Value<DateTime>? date,
    Value<double>? tempCelsius,
    Value<String>? source,
    Value<String?>? externalId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BbtEntriesCompanion(
      date: date ?? this.date,
      tempCelsius: tempCelsius ?? this.tempCelsius,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
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
    if (tempCelsius.present) {
      map['temp_celsius'] = Variable<double>(tempCelsius.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
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
    return (StringBuffer('BbtEntriesCompanion(')
          ..write('date: $date, ')
          ..write('tempCelsius: $tempCelsius, ')
          ..write('source: $source, ')
          ..write('externalId: $externalId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CervicalMucusEntriesTable extends CervicalMucusEntries
    with TableInfo<$CervicalMucusEntriesTable, CervicalMucusEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CervicalMucusEntriesTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumnWithTypeConverter<CervicalMucusType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CervicalMucusType>(
        $CervicalMucusEntriesTable.$convertertype,
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
  List<GeneratedColumn> get $columns => [date, type, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cervical_mucus_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CervicalMucusEntry> instance, {
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
  CervicalMucusEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CervicalMucusEntry(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      type: $CervicalMucusEntriesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
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
  $CervicalMucusEntriesTable createAlias(String alias) {
    return $CervicalMucusEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CervicalMucusType, String, String> $convertertype =
      const EnumNameConverter<CervicalMucusType>(CervicalMucusType.values);
}

class CervicalMucusEntry extends DataClass
    implements Insertable<CervicalMucusEntry> {
  /// Calendar date, time-of-day zeroed on write. Primary key.
  final DateTime date;
  final CervicalMucusType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CervicalMucusEntry({
    required this.date,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    {
      map['type'] = Variable<String>(
        $CervicalMucusEntriesTable.$convertertype.toSql(type),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CervicalMucusEntriesCompanion toCompanion(bool nullToAbsent) {
    return CervicalMucusEntriesCompanion(
      date: Value(date),
      type: Value(type),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CervicalMucusEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CervicalMucusEntry(
      date: serializer.fromJson<DateTime>(json['date']),
      type: $CervicalMucusEntriesTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
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
      'type': serializer.toJson<String>(
        $CervicalMucusEntriesTable.$convertertype.toJson(type),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CervicalMucusEntry copyWith({
    DateTime? date,
    CervicalMucusType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CervicalMucusEntry(
    date: date ?? this.date,
    type: type ?? this.type,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CervicalMucusEntry copyWithCompanion(CervicalMucusEntriesCompanion data) {
    return CervicalMucusEntry(
      date: data.date.present ? data.date.value : this.date,
      type: data.type.present ? data.type.value : this.type,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CervicalMucusEntry(')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, type, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CervicalMucusEntry &&
          other.date == this.date &&
          other.type == this.type &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CervicalMucusEntriesCompanion
    extends UpdateCompanion<CervicalMucusEntry> {
  final Value<DateTime> date;
  final Value<CervicalMucusType> type;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CervicalMucusEntriesCompanion({
    this.date = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CervicalMucusEntriesCompanion.insert({
    required DateTime date,
    required CervicalMucusType type,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       type = Value(type);
  static Insertable<CervicalMucusEntry> custom({
    Expression<DateTime>? date,
    Expression<String>? type,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (type != null) 'type': type,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CervicalMucusEntriesCompanion copyWith({
    Value<DateTime>? date,
    Value<CervicalMucusType>? type,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CervicalMucusEntriesCompanion(
      date: date ?? this.date,
      type: type ?? this.type,
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
    if (type.present) {
      map['type'] = Variable<String>(
        $CervicalMucusEntriesTable.$convertertype.toSql(type.value),
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
    return (StringBuffer('CervicalMucusEntriesCompanion(')
          ..write('date: $date, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
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
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({String? key, String? value, DateTime? updatedAt}) =>
      AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
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
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MedicationsTable extends Medications
    with TableInfo<$MedicationsTable, Medication> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MedicationsTable(this.attachedDatabase, [this._alias]);
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
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dosageMeta = const VerificationMeta('dosage');
  @override
  late final GeneratedColumn<String> dosage = GeneratedColumn<String>(
    'dosage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    dosage,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'medications';
  @override
  VerificationContext validateIntegrity(
    Insertable<Medication> instance, {
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
    if (data.containsKey('dosage')) {
      context.handle(
        _dosageMeta,
        dosage.isAcceptableOrUnknown(data['dosage']!, _dosageMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
  Medication map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Medication(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      dosage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dosage'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
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
  $MedicationsTable createAlias(String alias) {
    return $MedicationsTable(attachedDatabase, alias);
  }
}

class Medication extends DataClass implements Insertable<Medication> {
  final int id;
  final String name;

  /// Free text, e.g. "50 mg", "2 tablets". Optional.
  final String? dosage;
  final String? notes;

  /// Set when the user removes the medication; `null` while it is active.
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Medication({
    required this.id,
    required this.name,
    this.dosage,
    this.notes,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || dosage != null) {
      map['dosage'] = Variable<String>(dosage);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MedicationsCompanion toCompanion(bool nullToAbsent) {
    return MedicationsCompanion(
      id: Value(id),
      name: Value(name),
      dosage: dosage == null && nullToAbsent
          ? const Value.absent()
          : Value(dosage),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Medication.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Medication(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      dosage: serializer.fromJson<String?>(json['dosage']),
      notes: serializer.fromJson<String?>(json['notes']),
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
      'dosage': serializer.toJson<String?>(dosage),
      'notes': serializer.toJson<String?>(notes),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Medication copyWith({
    int? id,
    String? name,
    Value<String?> dosage = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Medication(
    id: id ?? this.id,
    name: name ?? this.name,
    dosage: dosage.present ? dosage.value : this.dosage,
    notes: notes.present ? notes.value : this.notes,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Medication copyWithCompanion(MedicationsCompanion data) {
    return Medication(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      dosage: data.dosage.present ? data.dosage.value : this.dosage,
      notes: data.notes.present ? data.notes.value : this.notes,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Medication(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('dosage: $dosage, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, dosage, notes, archivedAt, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Medication &&
          other.id == this.id &&
          other.name == this.name &&
          other.dosage == this.dosage &&
          other.notes == this.notes &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MedicationsCompanion extends UpdateCompanion<Medication> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> dosage;
  final Value<String?> notes;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const MedicationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.dosage = const Value.absent(),
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  MedicationsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.dosage = const Value.absent(),
    this.notes = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Medication> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? dosage,
    Expression<String>? notes,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (dosage != null) 'dosage': dosage,
      if (notes != null) 'notes': notes,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  MedicationsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? dosage,
    Value<String?>? notes,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return MedicationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      notes: notes ?? this.notes,
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
    if (dosage.present) {
      map['dosage'] = Variable<String>(dosage.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
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
    return (StringBuffer('MedicationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('dosage: $dosage, ')
          ..write('notes: $notes, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BirthControlEntriesTable extends BirthControlEntries
    with TableInfo<$BirthControlEntriesTable, BirthControlEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BirthControlEntriesTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumnWithTypeConverter<BirthControlMethod, String>
  method =
      GeneratedColumn<String>(
        'method',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BirthControlMethod>(
        $BirthControlEntriesTable.$convertermethod,
      );
  static const VerificationMeta _startedOnMeta = const VerificationMeta(
    'startedOn',
  );
  @override
  late final GeneratedColumn<DateTime> startedOn = GeneratedColumn<DateTime>(
    'started_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedOnMeta = const VerificationMeta(
    'endedOn',
  );
  @override
  late final GeneratedColumn<DateTime> endedOn = GeneratedColumn<DateTime>(
    'ended_on',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    method,
    startedOn,
    endedOn,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'birth_control_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BirthControlEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_on')) {
      context.handle(
        _startedOnMeta,
        startedOn.isAcceptableOrUnknown(data['started_on']!, _startedOnMeta),
      );
    } else if (isInserting) {
      context.missing(_startedOnMeta);
    }
    if (data.containsKey('ended_on')) {
      context.handle(
        _endedOnMeta,
        endedOn.isAcceptableOrUnknown(data['ended_on']!, _endedOnMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
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
  BirthControlEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BirthControlEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      method: $BirthControlEntriesTable.$convertermethod.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}method'],
        )!,
      ),
      startedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_on'],
      )!,
      endedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_on'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
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
  $BirthControlEntriesTable createAlias(String alias) {
    return $BirthControlEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BirthControlMethod, String, String>
  $convertermethod = const EnumNameConverter<BirthControlMethod>(
    BirthControlMethod.values,
  );
}

class BirthControlEntry extends DataClass
    implements Insertable<BirthControlEntry> {
  final int id;
  final BirthControlMethod method;
  final DateTime startedOn;
  final DateTime? endedOn;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BirthControlEntry({
    required this.id,
    required this.method,
    required this.startedOn,
    this.endedOn,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['method'] = Variable<String>(
        $BirthControlEntriesTable.$convertermethod.toSql(method),
      );
    }
    map['started_on'] = Variable<DateTime>(startedOn);
    if (!nullToAbsent || endedOn != null) {
      map['ended_on'] = Variable<DateTime>(endedOn);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BirthControlEntriesCompanion toCompanion(bool nullToAbsent) {
    return BirthControlEntriesCompanion(
      id: Value(id),
      method: Value(method),
      startedOn: Value(startedOn),
      endedOn: endedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(endedOn),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BirthControlEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BirthControlEntry(
      id: serializer.fromJson<int>(json['id']),
      method: $BirthControlEntriesTable.$convertermethod.fromJson(
        serializer.fromJson<String>(json['method']),
      ),
      startedOn: serializer.fromJson<DateTime>(json['startedOn']),
      endedOn: serializer.fromJson<DateTime?>(json['endedOn']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'method': serializer.toJson<String>(
        $BirthControlEntriesTable.$convertermethod.toJson(method),
      ),
      'startedOn': serializer.toJson<DateTime>(startedOn),
      'endedOn': serializer.toJson<DateTime?>(endedOn),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BirthControlEntry copyWith({
    int? id,
    BirthControlMethod? method,
    DateTime? startedOn,
    Value<DateTime?> endedOn = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BirthControlEntry(
    id: id ?? this.id,
    method: method ?? this.method,
    startedOn: startedOn ?? this.startedOn,
    endedOn: endedOn.present ? endedOn.value : this.endedOn,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BirthControlEntry copyWithCompanion(BirthControlEntriesCompanion data) {
    return BirthControlEntry(
      id: data.id.present ? data.id.value : this.id,
      method: data.method.present ? data.method.value : this.method,
      startedOn: data.startedOn.present ? data.startedOn.value : this.startedOn,
      endedOn: data.endedOn.present ? data.endedOn.value : this.endedOn,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BirthControlEntry(')
          ..write('id: $id, ')
          ..write('method: $method, ')
          ..write('startedOn: $startedOn, ')
          ..write('endedOn: $endedOn, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, method, startedOn, endedOn, notes, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BirthControlEntry &&
          other.id == this.id &&
          other.method == this.method &&
          other.startedOn == this.startedOn &&
          other.endedOn == this.endedOn &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BirthControlEntriesCompanion extends UpdateCompanion<BirthControlEntry> {
  final Value<int> id;
  final Value<BirthControlMethod> method;
  final Value<DateTime> startedOn;
  final Value<DateTime?> endedOn;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const BirthControlEntriesCompanion({
    this.id = const Value.absent(),
    this.method = const Value.absent(),
    this.startedOn = const Value.absent(),
    this.endedOn = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BirthControlEntriesCompanion.insert({
    this.id = const Value.absent(),
    required BirthControlMethod method,
    required DateTime startedOn,
    this.endedOn = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : method = Value(method),
       startedOn = Value(startedOn);
  static Insertable<BirthControlEntry> custom({
    Expression<int>? id,
    Expression<String>? method,
    Expression<DateTime>? startedOn,
    Expression<DateTime>? endedOn,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (method != null) 'method': method,
      if (startedOn != null) 'started_on': startedOn,
      if (endedOn != null) 'ended_on': endedOn,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BirthControlEntriesCompanion copyWith({
    Value<int>? id,
    Value<BirthControlMethod>? method,
    Value<DateTime>? startedOn,
    Value<DateTime?>? endedOn,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return BirthControlEntriesCompanion(
      id: id ?? this.id,
      method: method ?? this.method,
      startedOn: startedOn ?? this.startedOn,
      endedOn: endedOn ?? this.endedOn,
      notes: notes ?? this.notes,
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
    if (method.present) {
      map['method'] = Variable<String>(
        $BirthControlEntriesTable.$convertermethod.toSql(method.value),
      );
    }
    if (startedOn.present) {
      map['started_on'] = Variable<DateTime>(startedOn.value);
    }
    if (endedOn.present) {
      map['ended_on'] = Variable<DateTime>(endedOn.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
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
    return (StringBuffer('BirthControlEntriesCompanion(')
          ..write('id: $id, ')
          ..write('method: $method, ')
          ..write('startedOn: $startedOn, ')
          ..write('endedOn: $endedOn, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumnWithTypeConverter<ReminderKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ReminderKind>($RemindersTable.$converterkind);
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
    'hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    kind,
    hour,
    minute,
    enabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('hour')) {
      context.handle(
        _hourMeta,
        hour.isAcceptableOrUnknown(data['hour']!, _hourMeta),
      );
    } else if (isInserting) {
      context.missing(_hourMeta);
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    } else if (isInserting) {
      context.missing(_minuteMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
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
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: $RemindersTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      hour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hour'],
      )!,
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
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
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReminderKind, String, String> $converterkind =
      const EnumNameConverter<ReminderKind>(ReminderKind.values);
}

class Reminder extends DataClass implements Insertable<Reminder> {
  final int id;
  final ReminderKind kind;

  /// 0–23. Range is enforced in the repository (`validateReminderTime`).
  final int hour;

  /// 0–59. Range is enforced in the repository (`validateReminderTime`).
  final int minute;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Reminder({
    required this.id,
    required this.kind,
    required this.hour,
    required this.minute,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['kind'] = Variable<String>(
        $RemindersTable.$converterkind.toSql(kind),
      );
    }
    map['hour'] = Variable<int>(hour);
    map['minute'] = Variable<int>(minute);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      kind: Value(kind),
      hour: Value(hour),
      minute: Value(minute),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Reminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      id: serializer.fromJson<int>(json['id']),
      kind: $RemindersTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      hour: serializer.fromJson<int>(json['hour']),
      minute: serializer.fromJson<int>(json['minute']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(
        $RemindersTable.$converterkind.toJson(kind),
      ),
      'hour': serializer.toJson<int>(hour),
      'minute': serializer.toJson<int>(minute),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Reminder copyWith({
    int? id,
    ReminderKind? kind,
    int? hour,
    int? minute,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Reminder(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Reminder copyWithCompanion(RemindersCompanion data) {
    return Reminder(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      hour: data.hour.present ? data.hour.value : this.hour,
      minute: data.minute.present ? data.minute.value : this.minute,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, hour, minute, enabled, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.hour == this.hour &&
          other.minute == this.minute &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RemindersCompanion extends UpdateCompanion<Reminder> {
  final Value<int> id;
  final Value<ReminderKind> kind;
  final Value<int> hour;
  final Value<int> minute;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RemindersCompanion.insert({
    this.id = const Value.absent(),
    required ReminderKind kind,
    required int hour,
    required int minute,
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : kind = Value(kind),
       hour = Value(hour),
       minute = Value(minute);
  static Insertable<Reminder> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<int>? hour,
    Expression<int>? minute,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (hour != null) 'hour': hour,
      if (minute != null) 'minute': minute,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RemindersCompanion copyWith({
    Value<int>? id,
    Value<ReminderKind>? kind,
    Value<int>? hour,
    Value<int>? minute,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
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
    if (kind.present) {
      map['kind'] = Variable<String>(
        $RemindersTable.$converterkind.toSql(kind.value),
      );
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
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
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PainEntriesTable extends PainEntries
    with TableInfo<$PainEntriesTable, PainEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PainEntriesTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumnWithTypeConverter<SymptomSeverity, String>
  intensity = GeneratedColumn<String>(
    'intensity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<SymptomSeverity>($PainEntriesTable.$converterintensity);
  @override
  late final GeneratedColumnWithTypeConverter<PainRegion?, String> region =
      GeneratedColumn<String>(
        'region',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<PainRegion?>($PainEntriesTable.$converterregionn);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFlareMeta = const VerificationMeta(
    'isFlare',
  );
  @override
  late final GeneratedColumn<bool> isFlare = GeneratedColumn<bool>(
    'is_flare',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_flare" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    date,
    intensity,
    region,
    note,
    isFlare,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pain_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PainEntry> instance, {
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
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('is_flare')) {
      context.handle(
        _isFlareMeta,
        isFlare.isAcceptableOrUnknown(data['is_flare']!, _isFlareMeta),
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
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  PainEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PainEntry(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      intensity: $PainEntriesTable.$converterintensity.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}intensity'],
        )!,
      ),
      region: $PainEntriesTable.$converterregionn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}region'],
        ),
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      isFlare: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_flare'],
      )!,
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
  $PainEntriesTable createAlias(String alias) {
    return $PainEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SymptomSeverity, String, String>
  $converterintensity = const EnumNameConverter<SymptomSeverity>(
    SymptomSeverity.values,
  );
  static JsonTypeConverter2<PainRegion, String, String> $converterregion =
      const EnumNameConverter<PainRegion>(PainRegion.values);
  static JsonTypeConverter2<PainRegion?, String?, String?> $converterregionn =
      JsonTypeConverter2.asNullable($converterregion);
}

class PainEntry extends DataClass implements Insertable<PainEntry> {
  /// Calendar date, time-of-day zeroed on write. Primary key.
  final DateTime date;

  /// Ordered pain intensity, stored as the [SymptomSeverity] enum name (`mild` /
  /// `moderate` / `severe` in practice; the repository never writes `none`).
  final SymptomSeverity intensity;

  /// Optional coarse location, stored as the [PainRegion] enum name, or `null`.
  final PainRegion? region;

  /// Optional free-text note. Lives only in the SQLCipher-encrypted database and
  /// is **never** placed in a notification (same rule as [Medications.notes]).
  final String? note;

  /// Whether the user marked this day a flare (a distinct bad episode), as
  /// opposed to background pain. Drives the flare-vs-cycle-phase view.
  final bool isFlare;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PainEntry({
    required this.date,
    required this.intensity,
    this.region,
    this.note,
    required this.isFlare,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    {
      map['intensity'] = Variable<String>(
        $PainEntriesTable.$converterintensity.toSql(intensity),
      );
    }
    if (!nullToAbsent || region != null) {
      map['region'] = Variable<String>(
        $PainEntriesTable.$converterregionn.toSql(region),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_flare'] = Variable<bool>(isFlare);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PainEntriesCompanion toCompanion(bool nullToAbsent) {
    return PainEntriesCompanion(
      date: Value(date),
      intensity: Value(intensity),
      region: region == null && nullToAbsent
          ? const Value.absent()
          : Value(region),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isFlare: Value(isFlare),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PainEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PainEntry(
      date: serializer.fromJson<DateTime>(json['date']),
      intensity: $PainEntriesTable.$converterintensity.fromJson(
        serializer.fromJson<String>(json['intensity']),
      ),
      region: $PainEntriesTable.$converterregionn.fromJson(
        serializer.fromJson<String?>(json['region']),
      ),
      note: serializer.fromJson<String?>(json['note']),
      isFlare: serializer.fromJson<bool>(json['isFlare']),
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
        $PainEntriesTable.$converterintensity.toJson(intensity),
      ),
      'region': serializer.toJson<String?>(
        $PainEntriesTable.$converterregionn.toJson(region),
      ),
      'note': serializer.toJson<String?>(note),
      'isFlare': serializer.toJson<bool>(isFlare),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PainEntry copyWith({
    DateTime? date,
    SymptomSeverity? intensity,
    Value<PainRegion?> region = const Value.absent(),
    Value<String?> note = const Value.absent(),
    bool? isFlare,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PainEntry(
    date: date ?? this.date,
    intensity: intensity ?? this.intensity,
    region: region.present ? region.value : this.region,
    note: note.present ? note.value : this.note,
    isFlare: isFlare ?? this.isFlare,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PainEntry copyWithCompanion(PainEntriesCompanion data) {
    return PainEntry(
      date: data.date.present ? data.date.value : this.date,
      intensity: data.intensity.present ? data.intensity.value : this.intensity,
      region: data.region.present ? data.region.value : this.region,
      note: data.note.present ? data.note.value : this.note,
      isFlare: data.isFlare.present ? data.isFlare.value : this.isFlare,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PainEntry(')
          ..write('date: $date, ')
          ..write('intensity: $intensity, ')
          ..write('region: $region, ')
          ..write('note: $note, ')
          ..write('isFlare: $isFlare, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(date, intensity, region, note, isFlare, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PainEntry &&
          other.date == this.date &&
          other.intensity == this.intensity &&
          other.region == this.region &&
          other.note == this.note &&
          other.isFlare == this.isFlare &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PainEntriesCompanion extends UpdateCompanion<PainEntry> {
  final Value<DateTime> date;
  final Value<SymptomSeverity> intensity;
  final Value<PainRegion?> region;
  final Value<String?> note;
  final Value<bool> isFlare;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PainEntriesCompanion({
    this.date = const Value.absent(),
    this.intensity = const Value.absent(),
    this.region = const Value.absent(),
    this.note = const Value.absent(),
    this.isFlare = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PainEntriesCompanion.insert({
    required DateTime date,
    required SymptomSeverity intensity,
    this.region = const Value.absent(),
    this.note = const Value.absent(),
    this.isFlare = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       intensity = Value(intensity);
  static Insertable<PainEntry> custom({
    Expression<DateTime>? date,
    Expression<String>? intensity,
    Expression<String>? region,
    Expression<String>? note,
    Expression<bool>? isFlare,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (intensity != null) 'intensity': intensity,
      if (region != null) 'region': region,
      if (note != null) 'note': note,
      if (isFlare != null) 'is_flare': isFlare,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PainEntriesCompanion copyWith({
    Value<DateTime>? date,
    Value<SymptomSeverity>? intensity,
    Value<PainRegion?>? region,
    Value<String?>? note,
    Value<bool>? isFlare,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PainEntriesCompanion(
      date: date ?? this.date,
      intensity: intensity ?? this.intensity,
      region: region ?? this.region,
      note: note ?? this.note,
      isFlare: isFlare ?? this.isFlare,
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
        $PainEntriesTable.$converterintensity.toSql(intensity.value),
      );
    }
    if (region.present) {
      map['region'] = Variable<String>(
        $PainEntriesTable.$converterregionn.toSql(region.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isFlare.present) {
      map['is_flare'] = Variable<bool>(isFlare.value);
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
    return (StringBuffer('PainEntriesCompanion(')
          ..write('date: $date, ')
          ..write('intensity: $intensity, ')
          ..write('region: $region, ')
          ..write('note: $note, ')
          ..write('isFlare: $isFlare, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PmddRatingsTable extends PmddRatings
    with TableInfo<$PmddRatingsTable, PmddRating> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PmddRatingsTable(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumnWithTypeConverter<PmddSymptom, String> item =
      GeneratedColumn<String>(
        'item',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PmddSymptom>($PmddRatingsTable.$converteritem);
  @override
  late final GeneratedColumnWithTypeConverter<SymptomSeverity, String> rating =
      GeneratedColumn<String>(
        'rating',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SymptomSeverity>($PmddRatingsTable.$converterrating);
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
    item,
    rating,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pmdd_ratings';
  @override
  VerificationContext validateIntegrity(
    Insertable<PmddRating> instance, {
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
  Set<GeneratedColumn> get $primaryKey => {date, item};
  @override
  PmddRating map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PmddRating(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      item: $PmddRatingsTable.$converteritem.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}item'],
        )!,
      ),
      rating: $PmddRatingsTable.$converterrating.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}rating'],
        )!,
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
  $PmddRatingsTable createAlias(String alias) {
    return $PmddRatingsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PmddSymptom, String, String> $converteritem =
      const EnumNameConverter<PmddSymptom>(PmddSymptom.values);
  static JsonTypeConverter2<SymptomSeverity, String, String> $converterrating =
      const EnumNameConverter<SymptomSeverity>(SymptomSeverity.values);
}

class PmddRating extends DataClass implements Insertable<PmddRating> {
  /// Calendar date, time-of-day zeroed on write.
  final DateTime date;

  /// Which rated item this row is, stored as the [PmddSymptom] enum name.
  final PmddSymptom item;

  /// The rating on the shared ordered scale, stored as the [SymptomSeverity]
  /// enum name — `none` included ("rated, nothing today").
  final SymptomSeverity rating;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PmddRating({
    required this.date,
    required this.item,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<DateTime>(date);
    {
      map['item'] = Variable<String>(
        $PmddRatingsTable.$converteritem.toSql(item),
      );
    }
    {
      map['rating'] = Variable<String>(
        $PmddRatingsTable.$converterrating.toSql(rating),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PmddRatingsCompanion toCompanion(bool nullToAbsent) {
    return PmddRatingsCompanion(
      date: Value(date),
      item: Value(item),
      rating: Value(rating),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PmddRating.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PmddRating(
      date: serializer.fromJson<DateTime>(json['date']),
      item: $PmddRatingsTable.$converteritem.fromJson(
        serializer.fromJson<String>(json['item']),
      ),
      rating: $PmddRatingsTable.$converterrating.fromJson(
        serializer.fromJson<String>(json['rating']),
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
      'item': serializer.toJson<String>(
        $PmddRatingsTable.$converteritem.toJson(item),
      ),
      'rating': serializer.toJson<String>(
        $PmddRatingsTable.$converterrating.toJson(rating),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PmddRating copyWith({
    DateTime? date,
    PmddSymptom? item,
    SymptomSeverity? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PmddRating(
    date: date ?? this.date,
    item: item ?? this.item,
    rating: rating ?? this.rating,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PmddRating copyWithCompanion(PmddRatingsCompanion data) {
    return PmddRating(
      date: data.date.present ? data.date.value : this.date,
      item: data.item.present ? data.item.value : this.item,
      rating: data.rating.present ? data.rating.value : this.rating,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PmddRating(')
          ..write('date: $date, ')
          ..write('item: $item, ')
          ..write('rating: $rating, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, item, rating, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PmddRating &&
          other.date == this.date &&
          other.item == this.item &&
          other.rating == this.rating &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PmddRatingsCompanion extends UpdateCompanion<PmddRating> {
  final Value<DateTime> date;
  final Value<PmddSymptom> item;
  final Value<SymptomSeverity> rating;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PmddRatingsCompanion({
    this.date = const Value.absent(),
    this.item = const Value.absent(),
    this.rating = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PmddRatingsCompanion.insert({
    required DateTime date,
    required PmddSymptom item,
    required SymptomSeverity rating,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       item = Value(item),
       rating = Value(rating);
  static Insertable<PmddRating> custom({
    Expression<DateTime>? date,
    Expression<String>? item,
    Expression<String>? rating,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (item != null) 'item': item,
      if (rating != null) 'rating': rating,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PmddRatingsCompanion copyWith({
    Value<DateTime>? date,
    Value<PmddSymptom>? item,
    Value<SymptomSeverity>? rating,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PmddRatingsCompanion(
      date: date ?? this.date,
      item: item ?? this.item,
      rating: rating ?? this.rating,
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
    if (item.present) {
      map['item'] = Variable<String>(
        $PmddRatingsTable.$converteritem.toSql(item.value),
      );
    }
    if (rating.present) {
      map['rating'] = Variable<String>(
        $PmddRatingsTable.$converterrating.toSql(rating.value),
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
    return (StringBuffer('PmddRatingsCompanion(')
          ..write('date: $date, ')
          ..write('item: $item, ')
          ..write('rating: $rating, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
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
  late final $BbtEntriesTable bbtEntries = $BbtEntriesTable(this);
  late final $CervicalMucusEntriesTable cervicalMucusEntries =
      $CervicalMucusEntriesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $MedicationsTable medications = $MedicationsTable(this);
  late final $BirthControlEntriesTable birthControlEntries =
      $BirthControlEntriesTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $PainEntriesTable painEntries = $PainEntriesTable(this);
  late final $PmddRatingsTable pmddRatings = $PmddRatingsTable(this);
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
    bbtEntries,
    cervicalMucusEntries,
    appSettings,
    medications,
    birthControlEntries,
    reminders,
    painEntries,
    pmddRatings,
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
      Value<String> source,
      Value<String?> externalId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$DailyFlowsTableUpdateCompanionBuilder =
    DailyFlowsCompanion Function({
      Value<DateTime> date,
      Value<FlowIntensity> intensity,
      Value<ClotSize?> clotSize,
      Value<String> source,
      Value<String?> externalId,
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

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
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

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
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

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

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
                Value<String> source = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyFlowsCompanion(
                date: date,
                intensity: intensity,
                clotSize: clotSize,
                source: source,
                externalId: externalId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required FlowIntensity intensity,
                Value<ClotSize?> clotSize = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyFlowsCompanion.insert(
                date: date,
                intensity: intensity,
                clotSize: clotSize,
                source: source,
                externalId: externalId,
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
typedef $$BbtEntriesTableCreateCompanionBuilder =
    BbtEntriesCompanion Function({
      required DateTime date,
      required double tempCelsius,
      Value<String> source,
      Value<String?> externalId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$BbtEntriesTableUpdateCompanionBuilder =
    BbtEntriesCompanion Function({
      Value<DateTime> date,
      Value<double> tempCelsius,
      Value<String> source,
      Value<String?> externalId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BbtEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BbtEntriesTable> {
  $$BbtEntriesTableFilterComposer({
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

  ColumnFilters<double> get tempCelsius => $composableBuilder(
    column: $table.tempCelsius,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
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

class $$BbtEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BbtEntriesTable> {
  $$BbtEntriesTableOrderingComposer({
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

  ColumnOrderings<double> get tempCelsius => $composableBuilder(
    column: $table.tempCelsius,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
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

class $$BbtEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BbtEntriesTable> {
  $$BbtEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get tempCelsius => $composableBuilder(
    column: $table.tempCelsius,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BbtEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BbtEntriesTable,
          BbtEntry,
          $$BbtEntriesTableFilterComposer,
          $$BbtEntriesTableOrderingComposer,
          $$BbtEntriesTableAnnotationComposer,
          $$BbtEntriesTableCreateCompanionBuilder,
          $$BbtEntriesTableUpdateCompanionBuilder,
          (BbtEntry, BaseReferences<_$AppDatabase, $BbtEntriesTable, BbtEntry>),
          BbtEntry,
          PrefetchHooks Function()
        > {
  $$BbtEntriesTableTableManager(_$AppDatabase db, $BbtEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BbtEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BbtEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BbtEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<double> tempCelsius = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BbtEntriesCompanion(
                date: date,
                tempCelsius: tempCelsius,
                source: source,
                externalId: externalId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required double tempCelsius,
                Value<String> source = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BbtEntriesCompanion.insert(
                date: date,
                tempCelsius: tempCelsius,
                source: source,
                externalId: externalId,
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

typedef $$BbtEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BbtEntriesTable,
      BbtEntry,
      $$BbtEntriesTableFilterComposer,
      $$BbtEntriesTableOrderingComposer,
      $$BbtEntriesTableAnnotationComposer,
      $$BbtEntriesTableCreateCompanionBuilder,
      $$BbtEntriesTableUpdateCompanionBuilder,
      (BbtEntry, BaseReferences<_$AppDatabase, $BbtEntriesTable, BbtEntry>),
      BbtEntry,
      PrefetchHooks Function()
    >;
typedef $$CervicalMucusEntriesTableCreateCompanionBuilder =
    CervicalMucusEntriesCompanion Function({
      required DateTime date,
      required CervicalMucusType type,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$CervicalMucusEntriesTableUpdateCompanionBuilder =
    CervicalMucusEntriesCompanion Function({
      Value<DateTime> date,
      Value<CervicalMucusType> type,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CervicalMucusEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CervicalMucusEntriesTable> {
  $$CervicalMucusEntriesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<CervicalMucusType, CervicalMucusType, String>
  get type => $composableBuilder(
    column: $table.type,
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

class $$CervicalMucusEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CervicalMucusEntriesTable> {
  $$CervicalMucusEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
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

class $$CervicalMucusEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CervicalMucusEntriesTable> {
  $$CervicalMucusEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CervicalMucusType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CervicalMucusEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CervicalMucusEntriesTable,
          CervicalMucusEntry,
          $$CervicalMucusEntriesTableFilterComposer,
          $$CervicalMucusEntriesTableOrderingComposer,
          $$CervicalMucusEntriesTableAnnotationComposer,
          $$CervicalMucusEntriesTableCreateCompanionBuilder,
          $$CervicalMucusEntriesTableUpdateCompanionBuilder,
          (
            CervicalMucusEntry,
            BaseReferences<
              _$AppDatabase,
              $CervicalMucusEntriesTable,
              CervicalMucusEntry
            >,
          ),
          CervicalMucusEntry,
          PrefetchHooks Function()
        > {
  $$CervicalMucusEntriesTableTableManager(
    _$AppDatabase db,
    $CervicalMucusEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CervicalMucusEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CervicalMucusEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CervicalMucusEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<CervicalMucusType> type = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CervicalMucusEntriesCompanion(
                date: date,
                type: type,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required CervicalMucusType type,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CervicalMucusEntriesCompanion.insert(
                date: date,
                type: type,
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

typedef $$CervicalMucusEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CervicalMucusEntriesTable,
      CervicalMucusEntry,
      $$CervicalMucusEntriesTableFilterComposer,
      $$CervicalMucusEntriesTableOrderingComposer,
      $$CervicalMucusEntriesTableAnnotationComposer,
      $$CervicalMucusEntriesTableCreateCompanionBuilder,
      $$CervicalMucusEntriesTableUpdateCompanionBuilder,
      (
        CervicalMucusEntry,
        BaseReferences<
          _$AppDatabase,
          $CervicalMucusEntriesTable,
          CervicalMucusEntry
        >,
      ),
      CervicalMucusEntry,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
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

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$MedicationsTableCreateCompanionBuilder =
    MedicationsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> dosage,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$MedicationsTableUpdateCompanionBuilder =
    MedicationsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> dosage,
      Value<String?> notes,
      Value<DateTime?> archivedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$MedicationsTableFilterComposer
    extends Composer<_$AppDatabase, $MedicationsTable> {
  $$MedicationsTableFilterComposer({
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

  ColumnFilters<String> get dosage => $composableBuilder(
    column: $table.dosage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
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

class $$MedicationsTableOrderingComposer
    extends Composer<_$AppDatabase, $MedicationsTable> {
  $$MedicationsTableOrderingComposer({
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

  ColumnOrderings<String> get dosage => $composableBuilder(
    column: $table.dosage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
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

class $$MedicationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MedicationsTable> {
  $$MedicationsTableAnnotationComposer({
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

  GeneratedColumn<String> get dosage =>
      $composableBuilder(column: $table.dosage, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MedicationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MedicationsTable,
          Medication,
          $$MedicationsTableFilterComposer,
          $$MedicationsTableOrderingComposer,
          $$MedicationsTableAnnotationComposer,
          $$MedicationsTableCreateCompanionBuilder,
          $$MedicationsTableUpdateCompanionBuilder,
          (
            Medication,
            BaseReferences<_$AppDatabase, $MedicationsTable, Medication>,
          ),
          Medication,
          PrefetchHooks Function()
        > {
  $$MedicationsTableTableManager(_$AppDatabase db, $MedicationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MedicationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MedicationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MedicationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> dosage = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => MedicationsCompanion(
                id: id,
                name: name,
                dosage: dosage,
                notes: notes,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> dosage = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => MedicationsCompanion.insert(
                id: id,
                name: name,
                dosage: dosage,
                notes: notes,
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

typedef $$MedicationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MedicationsTable,
      Medication,
      $$MedicationsTableFilterComposer,
      $$MedicationsTableOrderingComposer,
      $$MedicationsTableAnnotationComposer,
      $$MedicationsTableCreateCompanionBuilder,
      $$MedicationsTableUpdateCompanionBuilder,
      (
        Medication,
        BaseReferences<_$AppDatabase, $MedicationsTable, Medication>,
      ),
      Medication,
      PrefetchHooks Function()
    >;
typedef $$BirthControlEntriesTableCreateCompanionBuilder =
    BirthControlEntriesCompanion Function({
      Value<int> id,
      required BirthControlMethod method,
      required DateTime startedOn,
      Value<DateTime?> endedOn,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$BirthControlEntriesTableUpdateCompanionBuilder =
    BirthControlEntriesCompanion Function({
      Value<int> id,
      Value<BirthControlMethod> method,
      Value<DateTime> startedOn,
      Value<DateTime?> endedOn,
      Value<String?> notes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$BirthControlEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BirthControlEntriesTable> {
  $$BirthControlEntriesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<BirthControlMethod, BirthControlMethod, String>
  get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get startedOn => $composableBuilder(
    column: $table.startedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedOn => $composableBuilder(
    column: $table.endedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
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

class $$BirthControlEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BirthControlEntriesTable> {
  $$BirthControlEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedOn => $composableBuilder(
    column: $table.startedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedOn => $composableBuilder(
    column: $table.endedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
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

class $$BirthControlEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BirthControlEntriesTable> {
  $$BirthControlEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BirthControlMethod, String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<DateTime> get startedOn =>
      $composableBuilder(column: $table.startedOn, builder: (column) => column);

  GeneratedColumn<DateTime> get endedOn =>
      $composableBuilder(column: $table.endedOn, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BirthControlEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BirthControlEntriesTable,
          BirthControlEntry,
          $$BirthControlEntriesTableFilterComposer,
          $$BirthControlEntriesTableOrderingComposer,
          $$BirthControlEntriesTableAnnotationComposer,
          $$BirthControlEntriesTableCreateCompanionBuilder,
          $$BirthControlEntriesTableUpdateCompanionBuilder,
          (
            BirthControlEntry,
            BaseReferences<
              _$AppDatabase,
              $BirthControlEntriesTable,
              BirthControlEntry
            >,
          ),
          BirthControlEntry,
          PrefetchHooks Function()
        > {
  $$BirthControlEntriesTableTableManager(
    _$AppDatabase db,
    $BirthControlEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BirthControlEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BirthControlEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$BirthControlEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<BirthControlMethod> method = const Value.absent(),
                Value<DateTime> startedOn = const Value.absent(),
                Value<DateTime?> endedOn = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BirthControlEntriesCompanion(
                id: id,
                method: method,
                startedOn: startedOn,
                endedOn: endedOn,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required BirthControlMethod method,
                required DateTime startedOn,
                Value<DateTime?> endedOn = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BirthControlEntriesCompanion.insert(
                id: id,
                method: method,
                startedOn: startedOn,
                endedOn: endedOn,
                notes: notes,
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

typedef $$BirthControlEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BirthControlEntriesTable,
      BirthControlEntry,
      $$BirthControlEntriesTableFilterComposer,
      $$BirthControlEntriesTableOrderingComposer,
      $$BirthControlEntriesTableAnnotationComposer,
      $$BirthControlEntriesTableCreateCompanionBuilder,
      $$BirthControlEntriesTableUpdateCompanionBuilder,
      (
        BirthControlEntry,
        BaseReferences<
          _$AppDatabase,
          $BirthControlEntriesTable,
          BirthControlEntry
        >,
      ),
      BirthControlEntry,
      PrefetchHooks Function()
    >;
typedef $$RemindersTableCreateCompanionBuilder =
    RemindersCompanion Function({
      Value<int> id,
      required ReminderKind kind,
      required int hour,
      required int minute,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$RemindersTableUpdateCompanionBuilder =
    RemindersCompanion Function({
      Value<int> id,
      Value<ReminderKind> kind,
      Value<int> hour,
      Value<int> minute,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
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

  ColumnWithTypeConverterFilters<ReminderKind, ReminderKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
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

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
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

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReminderKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          Reminder,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
          Reminder,
          PrefetchHooks Function()
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<ReminderKind> kind = const Value.absent(),
                Value<int> hour = const Value.absent(),
                Value<int> minute = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                kind: kind,
                hour: hour,
                minute: minute,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required ReminderKind kind,
                required int hour,
                required int minute,
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                kind: kind,
                hour: hour,
                minute: minute,
                enabled: enabled,
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

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      Reminder,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
      Reminder,
      PrefetchHooks Function()
    >;
typedef $$PainEntriesTableCreateCompanionBuilder =
    PainEntriesCompanion Function({
      required DateTime date,
      required SymptomSeverity intensity,
      Value<PainRegion?> region,
      Value<String?> note,
      Value<bool> isFlare,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PainEntriesTableUpdateCompanionBuilder =
    PainEntriesCompanion Function({
      Value<DateTime> date,
      Value<SymptomSeverity> intensity,
      Value<PainRegion?> region,
      Value<String?> note,
      Value<bool> isFlare,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PainEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PainEntriesTable> {
  $$PainEntriesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<SymptomSeverity, SymptomSeverity, String>
  get intensity => $composableBuilder(
    column: $table.intensity,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<PainRegion?, PainRegion, String> get region =>
      $composableBuilder(
        column: $table.region,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFlare => $composableBuilder(
    column: $table.isFlare,
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

class $$PainEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PainEntriesTable> {
  $$PainEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get region => $composableBuilder(
    column: $table.region,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFlare => $composableBuilder(
    column: $table.isFlare,
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

class $$PainEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PainEntriesTable> {
  $$PainEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SymptomSeverity, String> get intensity =>
      $composableBuilder(column: $table.intensity, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PainRegion?, String> get region =>
      $composableBuilder(column: $table.region, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isFlare =>
      $composableBuilder(column: $table.isFlare, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PainEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PainEntriesTable,
          PainEntry,
          $$PainEntriesTableFilterComposer,
          $$PainEntriesTableOrderingComposer,
          $$PainEntriesTableAnnotationComposer,
          $$PainEntriesTableCreateCompanionBuilder,
          $$PainEntriesTableUpdateCompanionBuilder,
          (
            PainEntry,
            BaseReferences<_$AppDatabase, $PainEntriesTable, PainEntry>,
          ),
          PainEntry,
          PrefetchHooks Function()
        > {
  $$PainEntriesTableTableManager(_$AppDatabase db, $PainEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PainEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PainEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PainEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<SymptomSeverity> intensity = const Value.absent(),
                Value<PainRegion?> region = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isFlare = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PainEntriesCompanion(
                date: date,
                intensity: intensity,
                region: region,
                note: note,
                isFlare: isFlare,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required SymptomSeverity intensity,
                Value<PainRegion?> region = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isFlare = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PainEntriesCompanion.insert(
                date: date,
                intensity: intensity,
                region: region,
                note: note,
                isFlare: isFlare,
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

typedef $$PainEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PainEntriesTable,
      PainEntry,
      $$PainEntriesTableFilterComposer,
      $$PainEntriesTableOrderingComposer,
      $$PainEntriesTableAnnotationComposer,
      $$PainEntriesTableCreateCompanionBuilder,
      $$PainEntriesTableUpdateCompanionBuilder,
      (PainEntry, BaseReferences<_$AppDatabase, $PainEntriesTable, PainEntry>),
      PainEntry,
      PrefetchHooks Function()
    >;
typedef $$PmddRatingsTableCreateCompanionBuilder =
    PmddRatingsCompanion Function({
      required DateTime date,
      required PmddSymptom item,
      required SymptomSeverity rating,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PmddRatingsTableUpdateCompanionBuilder =
    PmddRatingsCompanion Function({
      Value<DateTime> date,
      Value<PmddSymptom> item,
      Value<SymptomSeverity> rating,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PmddRatingsTableFilterComposer
    extends Composer<_$AppDatabase, $PmddRatingsTable> {
  $$PmddRatingsTableFilterComposer({
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

  ColumnWithTypeConverterFilters<PmddSymptom, PmddSymptom, String> get item =>
      $composableBuilder(
        column: $table.item,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<SymptomSeverity, SymptomSeverity, String>
  get rating => $composableBuilder(
    column: $table.rating,
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

class $$PmddRatingsTableOrderingComposer
    extends Composer<_$AppDatabase, $PmddRatingsTable> {
  $$PmddRatingsTableOrderingComposer({
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

  ColumnOrderings<String> get item => $composableBuilder(
    column: $table.item,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rating => $composableBuilder(
    column: $table.rating,
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

class $$PmddRatingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PmddRatingsTable> {
  $$PmddRatingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PmddSymptom, String> get item =>
      $composableBuilder(column: $table.item, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SymptomSeverity, String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PmddRatingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PmddRatingsTable,
          PmddRating,
          $$PmddRatingsTableFilterComposer,
          $$PmddRatingsTableOrderingComposer,
          $$PmddRatingsTableAnnotationComposer,
          $$PmddRatingsTableCreateCompanionBuilder,
          $$PmddRatingsTableUpdateCompanionBuilder,
          (
            PmddRating,
            BaseReferences<_$AppDatabase, $PmddRatingsTable, PmddRating>,
          ),
          PmddRating,
          PrefetchHooks Function()
        > {
  $$PmddRatingsTableTableManager(_$AppDatabase db, $PmddRatingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PmddRatingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PmddRatingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PmddRatingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> date = const Value.absent(),
                Value<PmddSymptom> item = const Value.absent(),
                Value<SymptomSeverity> rating = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PmddRatingsCompanion(
                date: date,
                item: item,
                rating: rating,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime date,
                required PmddSymptom item,
                required SymptomSeverity rating,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PmddRatingsCompanion.insert(
                date: date,
                item: item,
                rating: rating,
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

typedef $$PmddRatingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PmddRatingsTable,
      PmddRating,
      $$PmddRatingsTableFilterComposer,
      $$PmddRatingsTableOrderingComposer,
      $$PmddRatingsTableAnnotationComposer,
      $$PmddRatingsTableCreateCompanionBuilder,
      $$PmddRatingsTableUpdateCompanionBuilder,
      (
        PmddRating,
        BaseReferences<_$AppDatabase, $PmddRatingsTable, PmddRating>,
      ),
      PmddRating,
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
  $$BbtEntriesTableTableManager get bbtEntries =>
      $$BbtEntriesTableTableManager(_db, _db.bbtEntries);
  $$CervicalMucusEntriesTableTableManager get cervicalMucusEntries =>
      $$CervicalMucusEntriesTableTableManager(_db, _db.cervicalMucusEntries);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$MedicationsTableTableManager get medications =>
      $$MedicationsTableTableManager(_db, _db.medications);
  $$BirthControlEntriesTableTableManager get birthControlEntries =>
      $$BirthControlEntriesTableTableManager(_db, _db.birthControlEntries);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$PainEntriesTableTableManager get painEntries =>
      $$PainEntriesTableTableManager(_db, _db.painEntries);
  $$PmddRatingsTableTableManager get pmddRatings =>
      $$PmddRatingsTableTableManager(_db, _db.pmddRatings);
}
