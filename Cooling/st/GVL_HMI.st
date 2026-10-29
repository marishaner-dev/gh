(* Образ для панели СП307, веб-визуализации и верхнего уровня. *)
VAR_GLOBAL
    Tm : REAL;              (* верхние слои масла *)
    Tnsm : REAL;            (* нижние слои масла *)
    Current : REAL;
    Tw : REAL;              (* температура обмотки To *)
    LoadPercent : REAL;
    Kfactor : REAL;
    DeltaSteady : REAL;
    Theta : REAL;
    TmMilliamp : REAL;
    TnsmMilliamp : REAL;
    IMilliamp : REAL;
    CoolingOff : BOOL;
    CoolingAlarm : BOOL;
    AutoOn : BOOL;
    SensorFaultTnsm : BOOL;
    BlockPumpOn : BOOL;
    BlockFanOn : BOOL;
    StageD1 : BOOL;
    StageD2 : BOOL;
    StageDC : BOOL;
    SensorFaultTm : BOOL;
    SensorFaultI : BOOL;
    ConfigBits : WORD;
    Failsafe : BOOL;
    TransformerOn : BOOL;
    WarnOil : BOOL;
    AlarmOil : BOOL;
    WarnWinding : BOOL;
    AlarmWinding : BOOL;
    Horn : BOOL;
    TmFans : BOOL;
    GroupPump : ARRAY[1..4] OF BOOL;
    FanRun : ARRAY[1..8] OF BOOL;
    PumpRun : ARRAY[1..4] OF BOOL;
    FanHours : ARRAY[1..8] OF REAL;
    FanStarts : ARRAY[1..8] OF UDINT;
    PumpHours : ARRAY[1..4] OF REAL;
    PumpStarts : ARRAY[1..4] OF UDINT;
    FanReason : ARRAY[1..8] OF WORD;
    PumpReason : ARRAY[1..4] OF WORD;
    FanFault : ARRAY[1..8] OF BOOL;
    PumpFault : ARRAY[1..4] OF BOOL;
    CoolerRole : ARRAY[1..4] OF INT;
    CoolerDutyHours : ARRAY[1..4] OF REAL;
    EffFanCount : INT;
    EffPumpCount : INT;
    EffCoolerCount : INT;
    HasD2 : BOOL;
    HasDC : BOOL;
    (* Образ Modbus TCP slave. Сопоставить с holding-регистрами с адреса 0. *)
    MB : ARRAY[0..255] OF WORD;
END_VAR
