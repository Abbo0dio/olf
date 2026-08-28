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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CycleEventsTable cycleEvents = $CycleEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cycleEvents];
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CycleEventsTableTableManager get cycleEvents =>
      $$CycleEventsTableTableManager(_db, _db.cycleEvents);
}
