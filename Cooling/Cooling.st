(* Охлаждение трансформатора, ПЛК210-04, CODESYS 3.5, один файл.
   Секции ниже — отдельные объекты проекта. Имя объекта — заголовок секции.
   В CODESYS проще импортировать plc/Cooling.xml: там те же типы, списки
   GVL_Const, GVL_IO, GVL_Set, GVL_HMI, функции, FB_Cooling и PRG_Cooling.
   Этот текст собран из plc/st. Править нужно исходники и заново запустить
   python3 plc/build_plcopen.py
*)

(* ===== DUT_Types ===== *)
(* Структуры проекта охлаждения трансформатора.
   Импорт: в CODESYS создать DUT с этими именами или импортировать Cooling.xml. *)

TYPE ST_Stage :
STRUCT
    Used : BOOL;
    TmOn : REAL;   (* °C, масло, включение *)
    TmOff : REAL;
    TwOn : REAL;   (* °C, обмотка *)
    TwOff : REAL;
    LoadOn : REAL; (* % In *)
    LoadOff : REAL;
END_STRUCT
END_TYPE

TYPE ST_Analog :
STRUCT
    Eu : REAL;
    Milliamp : REAL;
    Fault : BOOL;
END_STRUCT
END_TYPE

(* ===== GVL_Const ===== *)
(* Константы алгоритма. Числа ступеней — с листа «Алгоритмы СО». *)
VAR_GLOBAL CONSTANT
    CO_MD : INT := 1;          (* М/Д *)
    CO_MD1D2 : INT := 2;       (* М/Д1/Д2 *)
    CO_MD_DC : INT := 3;       (* М/Д/ДЦ *)
    CO_MD1D2_DC : INT := 4;    (* М/Д1/Д2/ДЦ *)
    FAN_MAX : INT := 8;
    PUMP_MAX : INT := 4;
    COOLER_MAX : INT := 4;

    (* Сигнализация, гистерезис 5 °C. Снятие при значении <= уставка − 5. *)
    OIL_WARN_ON : REAL := 95.0;
    OIL_WARN_OFF : REAL := 90.0;
    OIL_ALARM_ON : REAL := 105.0;
    OIL_ALARM_OFF : REAL := 100.0;
    WND_WARN_ON : REAL := 100.0;
    WND_WARN_OFF : REAL := 95.0;
    WND_ALARM_ON : REAL := 115.0;
    WND_ALARM_OFF : REAL := 110.0;

    (* Таблица 4: вентиляторы группы при масле >= 40 °C, снятие при <= 35 °C. *)
    FAN_OIL_ON : REAL := 40.0;
    FAN_OIL_OFF : REAL := 35.0;
    G2_LOAD_ON : REAL := 40.0;
    G2_LOAD_OFF : REAL := 35.0;
    G2_TW_ON : REAL := 75.0;
    G2_TW_OFF : REAL := 70.0;
    G3_LOAD_ON : REAL := 75.0;
    G3_LOAD_OFF : REAL := 70.0;
    G3_TW_ON : REAL := 85.0;
    G3_TW_OFF : REAL := 80.0;
    G4_LOAD_ON : REAL := 105.0;
    G4_LOAD_OFF : REAL := 100.0;
    G4_TW_ON : REAL := 95.0;
    G4_TW_OFF : REAL := 90.0;

    (* Причины пуска двигателя, биты слова Reason. *)
    R_D1 : WORD := 16#0001;
    R_D2 : WORD := 16#0002;
    R_DC : WORD := 16#0004;
    R_GROUP_FAN : WORD := 16#0008;
    R_GROUP_PUMP : WORD := 16#0010;
    R_SENSOR : WORD := 16#0020;
    R_OVERTEMP : WORD := 16#0040;
    R_MANUAL : WORD := 16#0080;
    R_BREAKER : WORD := 16#0100;
    R_THERMAL : WORD := 16#0200;
    R_UNUSED : WORD := 16#0400;

    (* Коды конфигурации. *)
    CFG_FAN_RANGE : WORD := 16#0001;
    CFG_PUMP_RANGE : WORD := 16#0002;
    CFG_COOLER_RANGE : WORD := 16#0004;
    CFG_FANS_FOR_COOLER : WORD := 16#0008;
    CFG_PUMPS_FOR_COOLER : WORD := 16#0010;
    CFG_NOMINAL : WORD := 16#0020;
    CFG_GRADIENT : WORD := 16#0040;

    MB_PROBE : REAL := 25.0; (* регистры 90…91, проверка порядка слов *)
END_VAR

(* ===== GVL_IO ===== *)
(* Клеммы ПЛК210-04-CS по таблице «Входы_Выходы».
   Адресов %IX нет: каналы привязываются по имени на вкладке
   «Сопоставление входов/выходов».

   FDI — режим «определение логического уровня», BOOL, 9…30 В = TRUE.
   DO — реле, режим «переключение логического состояния».
   Тумблер СТАРТ/СТОП на лицевой панели — в положении СТАРТ.

   AI1…AI3: «Ток 4…20 мА», в REAL приходит 0…100 %.
   AI4 выключить: опрос входов идёт по очереди, до 0,6 с на канал.
   Три включённых канала — до 1,8 с между обновлениями. *)
VAR_GLOBAL
    AI_Tvsm : REAL;       (* AI1, верхние слои масла *)
    AI_Tnsm : REAL;       (* AI2, нижние слои масла, дополнительный канал *)
    AI_I : REAL;          (* AI3, ток стороны ВН *)
    DI_Auto : BOOL;       (* FDI1, SA11, автоматический режим *)
    DI_TransOn : BOOL;    (* FDI2, трансформатор введён в работу *)
    DI_Res3 : BOOL;       (* FDI3, резерв *)
    DI_Res4 : BOOL;       (* FDI4, резерв *)
    DI_FanOn1 : BOOL;     (* FDI5, вентилятор 1 включен *)
    DI_FanOn2 : BOOL;     (* FDI6 *)
    DI_FanOn3 : BOOL;     (* FDI7 *)
    DI_FanOn4 : BOOL;     (* FDI8 *)
    DI_FanOn5 : BOOL;     (* FDI9 *)
    DI_FanOn6 : BOOL;     (* FDI10 *)
    DI_FanOn7 : BOOL;     (* FDI11 *)
    DI_FanOn8 : BOOL;     (* FDI12 *)
    DO_CO_Off : BOOL;     (* DO1, система охлаждения отключена *)
    DO_CO_Alarm : BOOL;   (* DO2, система охлаждения неисправна *)
    DO_Res3 : BOOL;       (* DO3, резерв *)
    DO_Res4 : BOOL;       (* DO4, резерв *)
    DO_D1_1 : BOOL;       (* DO5, ступень Д1, первое реле *)
    DO_D1_2 : BOOL;       (* DO6, ступень Д1, второе реле *)
    DO_D2_1 : BOOL;       (* DO7, ступень Д2 *)
    DO_D2_2 : BOOL;       (* DO8, ступень Д2 *)
    DO_DC_1 : BOOL;       (* DO9, ступень ДЦ *)
    DO_DC_2 : BOOL;       (* DO10 *)
    DO_DC_3 : BOOL;       (* DO11 *)
    DO_DC_4 : BOOL;       (* DO12 *)
END_VAR

(* ===== GVL_Set ===== *)
(* Уставки, которые задаёт персонал с СП307 или по Modbus.
   RETAIN PERSISTENT — сохраняются в MRAM ПЛК210. *)
VAR_GLOBAL RETAIN PERSISTENT
    CoolingType : INT := 4;         (* 1 М/Д, 2 М/Д1/Д2, 3 М/Д/ДЦ, 4 М/Д1/Д2/ДЦ *)
    Gradient : REAL := 33.0;        (* превышение ННТ над ВСМ при номинале, К *)
    NominalCurrent : REAL := 316.0; (* In обмотки ВН, А *)
    FanCount : INT := 4;
    PumpCount : INT := 0;
    CoolerCount : INT := 0;
    RotationHours : REAL := 168.0;  (* 0 — без ротации *)
    AiMode : INT := 0;              (* 0: канал 0…100 %, 1: канал уже в мА *)
    TmAt4mA : REAL := 0.0;
    TmAt20mA : REAL := 150.0;
    IAt20mA : REAL := 600.0;        (* пример шкалы тока ВН с экрана АВМ-КОТ *)
    BreakerRequired : BOOL := TRUE;
    UseTable4 : BOOL := FALSE;
    Group1AtIdle : BOOL := TRUE;    (* насосы 1-й группы на холостом ходу *)
    UseMotorFaults : BOOL := FALSE;
    ExponentY : REAL := 1.3;
    TauSec : REAL := 360.0;         (* постоянная ННТ, 6 минут *)
    Simulation : BOOL := FALSE;
    SimTm : REAL := 40.0;
    SimCurrent : REAL := 0.0;
    Manual : BOOL := FALSE;
    ManualFan : ARRAY[1..8] OF BOOL;
    ManualPump : ARRAY[1..4] OF BOOL;
    Ack : BOOL := FALSE;
    ResetHours : BOOL := FALSE;
    ResetTheta : BOOL := FALSE;
    SwapWords : BOOL := FALSE;      (* TRUE, если панель читает REAL наоборот *)
    EnableD1 : BOOL := TRUE;
    EnableD2 : BOOL := TRUE;
    EnableDC : BOOL := TRUE;
    D1_TmOn : REAL := 55.0;
    D1_TmOff : REAL := 50.0;
    D1_TwOn : REAL := 75.0;
    D1_TwOff : REAL := 70.0;
    D1_LdOn : REAL := 80.0;
    D1_LdOff : REAL := 75.0;
    D2_TmOn : REAL := 65.0;
    D2_TmOff : REAL := 60.0;
    D2_TwOn : REAL := 85.0;
    D2_TwOff : REAL := 80.0;
    D2_LdOn : REAL := 90.0;
    D2_LdOff : REAL := 85.0;
    DC_TmOn : REAL := 75.0;
    DC_TmOff : REAL := 70.0;
    DC_TwOn : REAL := 90.0;
    DC_TwOff : REAL := 85.0;
    DC_LdOn : REAL := 105.0;
    DC_LdOff : REAL := 100.0;
    MinLoadPct : REAL := 1.0;
    CmdDelaySec : REAL := 5.0;
    OffDelaySec : REAL := 0.0;
    PauseOnD1 : REAL := 5.0;
    PauseOnD2 : REAL := 5.0;
    PauseOnDC : REAL := 10.0;
    PauseOffD1 : REAL := 5.0;
    PauseOffD2 : REAL := 5.0;
    PauseOffDC : REAL := 15.0;
    SignalDelay : REAL := 5.0;
    SensorDelay : REAL := 5.0;
    FilterSec : REAL := 5.0;
    TauOilSec : REAL := 6360.0;     (* постоянная ВСМ, 106 минут *)
    K21 : REAL := 1.3;
    K22 : REAL := 1.0;
    OilWarnOn : REAL := 95.0;
    OilWarnOff : REAL := 90.0;
    OilAlarmOn : REAL := 105.0;
    OilAlarmOff : REAL := 100.0;
    WndWarnOn : REAL := 100.0;
    WndWarnOff : REAL := 95.0;
    WndAlarmOn : REAL := 115.0;
    WndAlarmOff : REAL := 110.0;
    BlockPumps : BOOL := FALSE;
    BlockFans : BOOL := FALSE;
    BlockTemp : REAL := -25.0;
    BlockHyst : REAL := 5.0;
    CalcWinding : BOOL := TRUE;
    TnsmAt4mA : REAL := 0.0;
    TnsmAt20mA : REAL := 150.0;
    IAt4mA : REAL := 0.0;
    SimTnsm : REAL := 35.0;
    SimTrans : BOOL := TRUE;
    SimAuto : BOOL := TRUE;
    UseFanFeedback : BOOL := TRUE;  (* FALSE, пока FDI5…FDI12 не смонтированы *)
END_VAR

(* ===== GVL_HMI ===== *)
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

(* ===== GVL_Visu ===== *)
(* Команды веб-визуализации ПЛК210. Экран Visu_Main пишет сюда кнопки,
   программа снимает их в том же цикле. Числа и лампы веб-экран берёт
   напрямую из GVL_HMI и GVL_Set, второй образ для них не нужен.
   Текст кода BannerCode — в plc/WEBVISU.md, список текстов Text_Banner. *)
VAR_GLOBAL
    BtnAck : BOOL;          (* кнопка «Квитировать», Tap *)
    BtnResetHours : BOOL;   (* кнопка «Сбросить наработку» *)
    BtnResetTheta : BOOL;   (* кнопка «Сбросить нагрев обмотки» *)
    BannerCode : INT;       (* 0…9, текст состояния для WebVisu *)
    Heartbeat : WORD;       (* +1 каждый цикл PRG_Cooling, то же значение в MB[19] *)
END_VAR

(* ===== F_Delay ===== *)
FUNCTION F_Delay : BOOL
VAR_IN_OUT
    Timer : REAL;
END_VAR
VAR_INPUT
    Prev : BOOL;
    Raw : BOOL;
    dtSec : REAL;
    DelaySec : REAL;
END_VAR
VAR
    elapsed : REAL;
END_VAR

(* Задержка только на появление. Снятие сразу, как только условие пропало. *)
IF NOT Raw THEN
    Timer := 0.0;
    F_Delay := FALSE;
ELSIF Prev OR (DelaySec <= 0.0) THEN
    Timer := 0.0;
    F_Delay := TRUE;
ELSE
    elapsed := Timer;
    IF dtSec > 0.0 THEN
        elapsed := elapsed + dtSec;
    END_IF
    IF elapsed >= DelaySec THEN
        Timer := 0.0;
        F_Delay := TRUE;
    ELSE
        Timer := elapsed;
        F_Delay := FALSE;
    END_IF
END_IF
END_FUNCTION

(* ===== F_Hyst ===== *)
FUNCTION F_Hyst : BOOL
VAR_INPUT
    Prev : BOOL;
    Value : REAL;
    LevelOn : REAL;
    LevelOff : REAL;
END_VAR

IF (NOT Prev) AND (Value >= LevelOn) THEN
    F_Hyst := TRUE;
ELSIF Prev AND (Value <= LevelOff) THEN
    F_Hyst := FALSE;
ELSE
    F_Hyst := Prev;
END_IF
END_FUNCTION

(* ===== F_Scale ===== *)
FUNCTION F_Scale : ST_Analog
VAR_INPUT
    Raw : REAL;
    Mode : INT; (* 0 — проценты диапазона 4…20 мА, 1 — уже миллиамперы *)
    EuAt4 : REAL;
    EuAt20 : REAL;
END_VAR
VAR
    result : ST_Analog;
    percent : REAL;
END_VAR

(* ПЛК210-04, сигнал «Ток 4…20 мА»: канал отдаёт REAL 0…100 %, не миллиамперы.
   Обрыв линии уходит ниже 0 % (порог −1 % ≈ 3,8 мА), перегруз — выше 103 % ≈ 20,5 мА.
   AI4 выключен. AI1…AI3 используются: масло сверху, масло снизу, ток ВН. *)
IF Mode = 1 THEN
    result.Milliamp := Raw;
    percent := ((Raw - 4.0) / 16.0) * 100.0;
ELSE
    percent := Raw;
    result.Milliamp := 4.0 + (percent / 100.0) * 16.0;
END_IF
result.Fault := (percent < -1.0) OR (percent > 103.0);
result.Eu := EuAt4 + (percent / 100.0) * (EuAt20 - EuAt4);
F_Scale := result;
END_FUNCTION

(* ===== F_Theta ===== *)
FUNCTION F_Theta : REAL
VAR_INPUT
    Theta : REAL;
    DeltaSteady : REAL;
    dtSec : REAL;
    TauSec : REAL;
END_VAR
VAR
    alpha : REAL;
END_VAR

(* Шаг формулы To = ΔT·(1 − e^(−t/τ)) + Tm.
   При скачке нагрузки это апериодическое звено, а не время от включения контроллера. *)
IF (dtSec > 0.0) AND (TauSec > 0.0) THEN
    alpha := 1.0 - EXP(-dtSec / TauSec);
    F_Theta := Theta + (DeltaSteady - Theta) * alpha;
ELSE
    F_Theta := Theta;
END_IF
END_FUNCTION

(* ===== F_Stage ===== *)
FUNCTION F_Stage : BOOL
VAR_INPUT
    Prev : BOOL;
    Enabled : BOOL;
    Permit : BOOL;
    Tm : REAL;
    Tw : REAL;
    LoadPct : REAL;
    Limits : ST_Stage;
END_VAR
VAR
    turnOn : BOOL;
    turnOff : BOOL;
END_VAR

(* Включение по любому из трёх условий, отключение когда все три не выше уставок «откл.». *)
IF (NOT Enabled) OR (NOT Permit) OR (NOT Limits.Used) THEN
    F_Stage := FALSE;
    RETURN;
END_IF
turnOn := (Tm >= Limits.TmOn) OR (Tw >= Limits.TwOn) OR (LoadPct >= Limits.LoadOn);
turnOff := (Tm <= Limits.TmOff) AND (Tw <= Limits.TwOff) AND (LoadPct <= Limits.LoadOff);
IF (NOT Prev) AND turnOn THEN
    F_Stage := TRUE;
ELSIF Prev AND turnOff THEN
    F_Stage := FALSE;
ELSE
    F_Stage := Prev;
END_IF
END_FUNCTION

(* ===== F_StageTable ===== *)
FUNCTION F_StageTable : ST_Stage
VAR_INPUT
    CoolingType : INT;
    Stage : INT; (* 1 — Д1, 2 — Д2, 3 — ДЦ *)
END_VAR
VAR
    row : ST_Stage;
END_VAR

row.Used := FALSE;
IF Stage = 1 THEN
    row.Used := TRUE;
    row.TmOn := 55.0;
    row.TmOff := 50.0;
    row.TwOn := 75.0;
    row.TwOff := 70.0;
    row.LoadOn := 80.0;
    row.LoadOff := 75.0;
ELSIF Stage = 2 THEN
    IF CoolingType = CO_MD1D2 THEN
        row.Used := TRUE;
        row.TmOn := 65.0;
        row.TmOff := 60.0;
        row.TwOn := 85.0;
        row.TwOff := 80.0;
        row.LoadOn := 105.0;
        row.LoadOff := 100.0;
    ELSIF CoolingType = CO_MD1D2_DC THEN
        row.Used := TRUE;
        row.TmOn := 65.0;
        row.TmOff := 60.0;
        row.TwOn := 85.0;
        row.TwOff := 80.0;
        row.LoadOn := 90.0;
        row.LoadOff := 85.0;
    END_IF
    (* У М/Д/ДЦ строка Д2 на листе пустая — ступень не используется. *)
ELSIF Stage = 3 THEN
    IF (CoolingType = CO_MD_DC) OR (CoolingType = CO_MD1D2_DC) THEN
        row.Used := TRUE;
        row.TmOn := 75.0;
        row.TmOff := 70.0;
        row.TwOn := 90.0;
        row.TwOff := 85.0;
        row.LoadOn := 105.0;
        row.LoadOff := 100.0;
    END_IF
END_IF
F_StageTable := row;
END_FUNCTION

(* ===== F_SplitReal ===== *)
FUNCTION F_SplitReal : BOOL
VAR_INPUT
    Value : REAL;
END_VAR
VAR_OUTPUT
    Hi : WORD;
    Lo : WORD;
END_VAR
VAR
    tmp : REAL;
    pw : POINTER TO WORD;
END_VAR

(* Память ПЛК210 little-endian: первое слово REAL — младшее. *)
tmp := Value;
pw := ADR(tmp);
Lo := pw^;
pw := pw + 1;
Hi := pw^;
F_SplitReal := TRUE;
END_FUNCTION

(* ===== F_JoinReal ===== *)
FUNCTION F_JoinReal : REAL
VAR_INPUT
    Hi : WORD;
    Lo : WORD;
    Swap : BOOL;
END_VAR
VAR
    tmp : REAL;
    pw : POINTER TO WORD;
END_VAR

tmp := 0.0;
pw := ADR(tmp);
IF Swap THEN
    pw^ := Hi;
    pw := pw + 1;
    pw^ := Lo;
ELSE
    pw^ := Lo;
    pw := pw + 1;
    pw^ := Hi;
END_IF
F_JoinReal := tmp;
END_FUNCTION

(* ===== FB_StageDrive ===== *)
FUNCTION_BLOCK FB_StageDrive
VAR_INPUT
    Want : BOOL;
    Count : INT;
    dtSec : REAL;
    CmdDelay : REAL;
    OffDelay : REAL;
    PauseOn : REAL;
    PauseOff : REAL;
    ForceOn : BOOL;
    ForceOff : BOOL;
END_VAR
VAR_OUTPUT
    Logical : BOOL;
    O1 : BOOL;
    O2 : BOOL;
    O3 : BOOL;
    O4 : BOOL;
END_VAR
VAR
    i : INT;
    guard : INT;
    idx : INT;
    left : REAL;
    need : REAL;
    allOn : BOOL;
    allOff : BOOL;
END_VAR
VAR RETAIN PERSISTENT
    Armed : BOOL;
    CmdTimer : REAL;
    Stagger : REAL;
    OffTimer : REAL;
    LogicalR : BOOL;
    Bits : ARRAY[1..4] OF BOOL;
END_VAR

(* Несколько реле одной ступени. Первое включается сразу после задержки команды,
   каждое следующее — после паузы. Снятие идёт с последнего реле. *)
IF ForceOff THEN
    Armed := FALSE;
    CmdTimer := 0.0;
    Stagger := 0.0;
    OffTimer := 0.0;
    LogicalR := FALSE;
    FOR i := 1 TO 4 DO
        Bits[i] := FALSE;
    END_FOR
ELSIF ForceOn THEN
    Armed := TRUE;
    CmdTimer := 0.0;
    Stagger := 0.0;
    OffTimer := 0.0;
    LogicalR := TRUE;
    FOR i := 1 TO 4 DO
        Bits[i] := i <= Count;
    END_FOR
ELSE
    IF Want THEN
        LogicalR := TRUE;
        OffTimer := 0.0;
    ELSIF LogicalR THEN
        IF dtSec > 0.0 THEN
            OffTimer := OffTimer + dtSec;
        END_IF
        IF OffTimer >= OffDelay THEN
            LogicalR := FALSE;
            OffTimer := 0.0;
        END_IF
    END_IF

    IF dtSec > 0.0 THEN
        left := dtSec;
    ELSE
        left := 0.0;
    END_IF
    guard := 0;
    WHILE guard < 8 DO
        guard := guard + 1;
        allOn := TRUE;
        allOff := TRUE;
        FOR i := 1 TO Count DO
            IF NOT Bits[i] THEN
                allOn := FALSE;
            END_IF
            IF Bits[i] THEN
                allOff := FALSE;
            END_IF
        END_FOR

        IF LogicalR <> Armed THEN
            need := CmdDelay - CmdTimer;
            IF need < 0.0 THEN
                need := 0.0;
            END_IF
            IF need <= left THEN
                Armed := LogicalR;
                CmdTimer := 0.0;
                Stagger := 0.0;
                left := left - need;
            ELSE
                CmdTimer := CmdTimer + left;
                left := -1.0;
            END_IF
        ELSIF Armed AND (NOT allOn) THEN
            IF allOff THEN
                need := 0.0;
            ELSE
                need := PauseOn - Stagger;
                IF need < 0.0 THEN
                    need := 0.0;
                END_IF
            END_IF
            IF need <= left THEN
                idx := 0;
                FOR i := 1 TO Count DO
                    IF (NOT Bits[i]) AND (idx = 0) THEN
                        idx := i;
                    END_IF
                END_FOR
                IF idx > 0 THEN
                    Bits[idx] := TRUE;
                END_IF
                Stagger := 0.0;
                left := left - need;
            ELSE
                Stagger := Stagger + left;
                left := -1.0;
            END_IF
        ELSIF (NOT Armed) AND (NOT allOff) THEN
            IF allOn THEN
                need := 0.0;
            ELSE
                need := PauseOff - Stagger;
                IF need < 0.0 THEN
                    need := 0.0;
                END_IF
            END_IF
            IF need <= left THEN
                idx := 0;
                FOR i := Count TO 1 BY -1 DO
                    IF Bits[i] AND (idx = 0) THEN
                        idx := i;
                    END_IF
                END_FOR
                IF idx > 0 THEN
                    Bits[idx] := FALSE;
                END_IF
                Stagger := 0.0;
                left := left - need;
            ELSE
                Stagger := Stagger + left;
                left := -1.0;
            END_IF
        ELSE
            Stagger := 0.0;
            left := -1.0;
        END_IF

        IF left < 0.0 THEN
            EXIT;
        END_IF
        allOn := TRUE;
        allOff := TRUE;
        FOR i := 1 TO Count DO
            IF NOT Bits[i] THEN
                allOn := FALSE;
            END_IF
            IF Bits[i] THEN
                allOff := FALSE;
            END_IF
        END_FOR
        IF (Armed AND allOn) OR ((NOT Armed) AND allOff) THEN
            EXIT;
        END_IF
    END_WHILE
END_IF

Logical := LogicalR;
O1 := Bits[1];
O2 := Bits[2];
O3 := Bits[3];
O4 := Bits[4];
END_FUNCTION_BLOCK

(* ===== FB_Cooling ===== *)
FUNCTION_BLOCK FB_Cooling
VAR_INPUT
    dtSec : REAL;
END_VAR
VAR
    i : INT;
    hasD2 : BOOL;
    hasDC : BOOL;
    useD1 : BOOL;
    useD2 : BOOL;
    useDC : BOOL;
    permit : BOOL;
    transformerOn : BOOL;
    autoOn : BOOL;
    tmFault : BOOL;
    tnFault : BOOL;
    iFault : BOOL;
    tmMeas : REAL;
    tnMeas : REAL;
    iMeas : REAL;
    oil : REAL;
    k : REAL;
    load : REAL;
    dSteady : REAL;
    tau1 : REAL;
    tau2 : REAL;
    k21 : REAL;
    k22 : REAL;
    lim : ST_Stage;
    analog : ST_Analog;
    failsafe : BOOL;
    anyOut : BOOL;
    anyFault : BOOL;
    rawWarn : BOOL;
    rawAlarm : BOOL;
    rawWndW : BOOL;
    rawWndA : BOOL;
    fanDi : ARRAY[1..8] OF BOOL;
END_VAR
VAR RETAIN PERSISTENT
    H1 : REAL;
    H2 : REAL;
    ThetaR : REAL;
    TmHold : REAL;
    TnHold : REAL;
    IHold : REAL;
    KHold : REAL;
    LoadHold : REAL;
    DeltaHold : REAL;
    StageD1R : BOOL;
    StageD2R : BOOL;
    StageDCR : BOOL;
    WarnOilR : BOOL;
    AlarmOilR : BOOL;
    WarnWndR : BOOL;
    AlarmWndR : BOOL;
    HornR : BOOL;
    WarnT : REAL;
    AlarmT : REAL;
    WndWarnT : REAL;
    WndAlarmT : REAL;
    SensTmT : REAL;
    SensTnT : REAL;
    SensIT : REAL;
    SensTmR : BOOL;
    SensTnR : BOOL;
    SensIR : BOOL;
    BlockPumpR : BOOL;
    BlockFanR : BOOL;
    FanHoursR : ARRAY[1..8] OF REAL;
    FanStartsR : ARRAY[1..8] OF UDINT;
    PrevFan : ARRAY[1..8] OF BOOL;
    FanFaultR : ARRAY[1..8] OF BOOL;
    FanFltT : ARRAY[1..8] OF REAL;
    HornOilW : BOOL;
    HornOilA : BOOL;
    HornWndW : BOOL;
    HornWndA : BOOL;
    HornSens : BOOL;
    HornAlarm : BOOL;
    AckPrev : BOOL;
    ResetHoursPrev : BOOL;
    ResetThetaPrev : BOOL;
    FiltTm : REAL;
    FiltTn : REAL;
    FiltI : REAL;
    FiltReady : BOOL;
    OilMinD : REAL;
    OilMaxD : REAL;
    MarkD : REAL;
    Elapsed : REAL;
END_VAR
VAR
    drvD1 : FB_StageDrive;
    drvD2 : FB_StageDrive;
    drvDC : FB_StageDrive;
END_VAR

IF ResetTheta AND (NOT ResetThetaPrev) THEN
    H1 := 0.0;
    H2 := 0.0;
    ThetaR := 0.0;
END_IF
ResetThetaPrev := ResetTheta;
IF ResetTheta THEN
    ResetTheta := FALSE;
END_IF
IF ResetHours AND (NOT ResetHoursPrev) THEN
    FOR i := 1 TO 8 DO
        FanHoursR[i] := 0.0;
        FanStartsR[i] := 0;
    END_FOR
END_IF
ResetHoursPrev := ResetHours;
IF ResetHours THEN
    ResetHours := FALSE;
END_IF

analog := F_Scale(AI_Tvsm, AiMode, TmAt4mA, TmAt20mA);
tmFault := analog.Fault;
tmMeas := analog.Eu;
TmMilliamp := analog.Milliamp;
analog := F_Scale(AI_Tnsm, AiMode, TnsmAt4mA, TnsmAt20mA);
tnFault := analog.Fault;
tnMeas := analog.Eu;
TnsmMilliamp := analog.Milliamp;
analog := F_Scale(AI_I, AiMode, IAt4mA, IAt20mA);
iFault := analog.Fault;
iMeas := analog.Eu;
IF iMeas < 0.0 THEN
    iMeas := 0.0;
END_IF
IMilliamp := analog.Milliamp;

IF Simulation THEN
    tmMeas := SimTm;
    tnMeas := SimTnsm;
    iMeas := SimCurrent;
    IF iMeas < 0.0 THEN
        iMeas := 0.0;
    END_IF
    tmFault := FALSE;
    tnFault := FALSE;
    iFault := FALSE;
    transformerOn := SimTrans;
    autoOn := SimAuto;
ELSIF FilterSec > 0.0 THEN
    IF FiltReady AND (dtSec > 0.0) THEN
        tmMeas := F_Theta(FiltTm, tmMeas, dtSec, FilterSec);
        tnMeas := F_Theta(FiltTn, tnMeas, dtSec, FilterSec);
        iMeas := F_Theta(FiltI, iMeas, dtSec, FilterSec);
        IF iMeas < 0.0 THEN
            iMeas := 0.0;
        END_IF
    END_IF
    FiltReady := TRUE;
    transformerOn := DI_TransOn;
    autoOn := DI_Auto;
ELSE
    transformerOn := DI_TransOn;
    autoOn := DI_Auto;
END_IF
FiltTm := tmMeas;
FiltTn := tnMeas;
FiltI := iMeas;

SensTmR := F_Delay(Timer := SensTmT, Prev := SensTmR, Raw := tmFault, dtSec := dtSec, DelaySec := SensorDelay);
SensTnR := F_Delay(Timer := SensTnT, Prev := SensTnR, Raw := tnFault, dtSec := dtSec, DelaySec := SensorDelay);
SensIR := F_Delay(Timer := SensIT, Prev := SensIR, Raw := iFault, dtSec := dtSec, DelaySec := SensorDelay);

IF SensTmR THEN
    tmMeas := TmHold;
ELSE
    TmHold := tmMeas;
END_IF
IF SensTnR THEN
    tnMeas := TnHold;
ELSE
    TnHold := tnMeas;
END_IF
IF SensIR THEN
    iMeas := IHold;
    k := KHold;
    load := LoadHold;
ELSE
    IHold := iMeas;
    IF NominalCurrent > 0.0 THEN
        k := iMeas / NominalCurrent;
    ELSE
        k := 0.0;
    END_IF
    load := k * 100.0;
    IF load < MinLoadPct THEN
        k := 0.0;
        load := 0.0;
    END_IF
    KHold := k;
    LoadHold := load;
END_IF

IF SensTmR AND (NOT SensTnR) THEN
    oil := tnMeas;
ELSE
    oil := tmMeas;
END_IF

k21 := K21;
k22 := K22;
IF k21 <= 0.0 THEN
    k21 := 1.0;
END_IF
IF k22 <= 0.0 THEN
    k22 := 1.0;
END_IF
IF SensIR THEN
    dSteady := DeltaHold;
ELSE
    IF (k > 0.0) AND (Gradient > 0.0) THEN
        dSteady := Gradient * EXPT(k, ExponentY);
    ELSE
        dSteady := 0.0;
    END_IF
    DeltaHold := dSteady;
END_IF
IF CalcWinding AND (NOT SensIR) AND (NOT (SensTmR AND SensTnR)) THEN
    tau1 := k22 * TauSec;
    IF tau1 < 0.001 THEN
        tau1 := 0.001;
    END_IF
    tau2 := TauOilSec / k22;
    IF tau2 < 0.001 THEN
        tau2 := 0.001;
    END_IF
    H1 := F_Theta(H1, k21 * dSteady, dtSec, tau1);
    H2 := F_Theta(H2, (k21 - 1.0) * dSteady, dtSec, tau2);
    ThetaR := H1 - H2;
END_IF
Tw := ThetaR + oil;

rawWarn := F_Hyst(WarnOilR, oil, OilWarnOn, OilWarnOff);
rawAlarm := F_Hyst(AlarmOilR, oil, OilAlarmOn, OilAlarmOff);
WarnOilR := F_Delay(Timer := WarnT, Prev := WarnOilR, Raw := rawWarn, dtSec := dtSec, DelaySec := SignalDelay);
AlarmOilR := F_Delay(Timer := AlarmT, Prev := AlarmOilR, Raw := rawAlarm, dtSec := dtSec, DelaySec := SignalDelay);
rawWndW := F_Hyst(WarnWndR, Tw, WndWarnOn, WndWarnOff);
rawWndA := F_Hyst(AlarmWndR, Tw, WndAlarmOn, WndAlarmOff);
WarnWndR := F_Delay(Timer := WndWarnT, Prev := WarnWndR, Raw := rawWndW, dtSec := dtSec, DelaySec := SignalDelay);
AlarmWndR := F_Delay(Timer := WndAlarmT, Prev := AlarmWndR, Raw := rawWndA, dtSec := dtSec, DelaySec := SignalDelay);

IF BlockPumps THEN
    IF (NOT BlockPumpR) AND (oil <= BlockTemp) THEN
        BlockPumpR := TRUE;
    ELSIF BlockPumpR AND (oil >= (BlockTemp + BlockHyst)) THEN
        BlockPumpR := FALSE;
    END_IF
ELSE
    BlockPumpR := FALSE;
END_IF
IF BlockFans THEN
    IF (NOT BlockFanR) AND (oil <= BlockTemp) THEN
        BlockFanR := TRUE;
    ELSIF BlockFanR AND (oil >= (BlockTemp + BlockHyst)) THEN
        BlockFanR := FALSE;
    END_IF
ELSE
    BlockFanR := FALSE;
END_IF

hasD2 := (CoolingType = CO_MD1D2) OR (CoolingType = CO_MD1D2_DC);
hasDC := (CoolingType = CO_MD_DC) OR (CoolingType = CO_MD1D2_DC);
useD1 := EnableD1 AND (NOT BlockFanR);
useD2 := EnableD2 AND hasD2 AND (NOT BlockFanR);
useDC := EnableDC AND hasDC AND (NOT BlockPumpR) AND (NOT BlockFanR);
permit := transformerOn AND autoOn AND (NOT Manual);

lim.Used := TRUE;
lim.TmOn := D1_TmOn;
lim.TmOff := D1_TmOff;
lim.TwOn := D1_TwOn;
lim.TwOff := D1_TwOff;
lim.LoadOn := D1_LdOn;
lim.LoadOff := D1_LdOff;
StageD1R := F_Stage(StageD1R, useD1, permit, oil, Tw, load, lim);
lim.TmOn := D2_TmOn;
lim.TmOff := D2_TmOff;
lim.TwOn := D2_TwOn;
lim.TwOff := D2_TwOff;
lim.LoadOn := D2_LdOn;
lim.LoadOff := D2_LdOff;
StageD2R := F_Stage(StageD2R, useD2, permit, oil, Tw, load, lim);
lim.TmOn := DC_TmOn;
lim.TmOff := DC_TmOff;
lim.TwOn := DC_TwOn;
lim.TwOff := DC_TwOff;
lim.LoadOn := DC_LdOn;
lim.LoadOff := DC_LdOff;
StageDCR := F_Stage(StageDCR, useDC, permit, oil, Tw, load, lim);

failsafe := permit AND (SensTmR OR SensIR OR AlarmOilR OR AlarmWndR);
drvD1(Want := StageD1R, Count := 2, dtSec := dtSec, CmdDelay := CmdDelaySec, OffDelay := OffDelaySec, PauseOn := PauseOnD1, PauseOff := PauseOffD1, ForceOn := failsafe AND useD1, ForceOff := (NOT transformerOn) OR (NOT useD1));
drvD2(Want := StageD2R, Count := 2, dtSec := dtSec, CmdDelay := CmdDelaySec, OffDelay := OffDelaySec, PauseOn := PauseOnD2, PauseOff := PauseOffD2, ForceOn := failsafe AND useD2, ForceOff := (NOT transformerOn) OR (NOT useD2));
drvDC(Want := StageDCR, Count := 4, dtSec := dtSec, CmdDelay := CmdDelaySec, OffDelay := OffDelaySec, PauseOn := PauseOnDC, PauseOff := PauseOffDC, ForceOn := failsafe AND useDC, ForceOff := (NOT transformerOn) OR (NOT useDC));

FanRun[1] := drvD1.O1;
FanRun[2] := drvD1.O2;
FanRun[3] := drvD2.O1;
FanRun[4] := drvD2.O2;
FanRun[5] := drvDC.O1;
FanRun[6] := drvDC.O2;
FanRun[7] := drvDC.O3;
FanRun[8] := drvDC.O4;
IF ((Manual OR (NOT autoOn)) AND transformerOn AND (NOT failsafe)) THEN
    FanRun[1] := ManualFan[1] AND useD1;
    FanRun[2] := ManualFan[2] AND useD1;
    FanRun[3] := ManualFan[3] AND useD2;
    FanRun[4] := ManualFan[4] AND useD2;
    FanRun[5] := ManualFan[5] AND useDC;
    FanRun[6] := ManualFan[6] AND useDC;
    FanRun[7] := ManualFan[7] AND useDC;
    FanRun[8] := ManualFan[8] AND useDC;
END_IF

fanDi[1] := DI_FanOn1;
fanDi[2] := DI_FanOn2;
fanDi[3] := DI_FanOn3;
fanDi[4] := DI_FanOn4;
fanDi[5] := DI_FanOn5;
fanDi[6] := DI_FanOn6;
fanDi[7] := DI_FanOn7;
fanDi[8] := DI_FanOn8;
anyOut := FALSE;
anyFault := FALSE;
FOR i := 1 TO 8 DO
    IF FanRun[i] AND (NOT PrevFan[i]) THEN
        FanStartsR[i] := FanStartsR[i] + 1;
    END_IF
    IF FanRun[i] AND (dtSec > 0.0) THEN
        FanHoursR[i] := FanHoursR[i] + (dtSec / 3600.0);
    END_IF
    PrevFan[i] := FanRun[i];
    FanHours[i] := FanHoursR[i];
    FanStarts[i] := FanStartsR[i];
    IF Simulation OR (NOT UseFanFeedback) THEN
        FanFaultR[i] := FALSE;
        FanFltT[i] := 0.0;
    ELSE
        IF FanRun[i] = fanDi[i] THEN
            FanFaultR[i] := FALSE;
            FanFltT[i] := 0.0;
        ELSIF FanFaultR[i] OR (SignalDelay <= 0.0) THEN
            FanFaultR[i] := TRUE;
            FanFltT[i] := 0.0;
        ELSE
            IF dtSec > 0.0 THEN
                FanFltT[i] := FanFltT[i] + dtSec;
            END_IF
            IF FanFltT[i] >= SignalDelay THEN
                FanFaultR[i] := TRUE;
                FanFltT[i] := 0.0;
            END_IF
        END_IF
    END_IF
    FanFault[i] := FanFaultR[i];
    IF FanRun[i] THEN
        anyOut := TRUE;
    END_IF
    IF FanFaultR[i] THEN
        anyFault := TRUE;
    END_IF
END_FOR
FOR i := 1 TO 4 DO
    PumpRun[i] := FALSE;
END_FOR

CoolingOff := NOT anyOut;
CoolingAlarm := AlarmOilR OR AlarmWndR OR SensTmR OR SensIR OR anyFault;

IF (WarnOilR AND (NOT HornOilW)) OR (AlarmOilR AND (NOT HornOilA)) OR (WarnWndR AND (NOT HornWndW)) OR (AlarmWndR AND (NOT HornWndA)) OR (SensTmR AND (NOT HornSens)) OR (CoolingAlarm AND (NOT HornAlarm)) THEN
    HornR := TRUE;
END_IF
HornOilW := WarnOilR;
HornOilA := AlarmOilR;
HornWndW := WarnWndR;
HornWndA := AlarmWndR;
HornSens := SensTmR;
HornAlarm := CoolingAlarm;
IF Ack AND (NOT AckPrev) THEN
    HornR := FALSE;
END_IF
AckPrev := Ack;
IF Ack THEN
    Ack := FALSE;
END_IF

Tm := tmMeas;
Tnsm := tnMeas;
Current := iMeas;
LoadPercent := load;
Kfactor := k;
DeltaSteady := dSteady;
Theta := ThetaR;
StageD1 := StageD1R;
StageD2 := StageD2R;
StageDC := StageDCR;
SensorFaultTm := SensTmR;
SensorFaultTnsm := SensTnR;
SensorFaultI := SensIR;
WarnOil := WarnOilR;
AlarmOil := AlarmOilR;
WarnWinding := WarnWndR;
AlarmWinding := AlarmWndR;
Horn := HornR;
Failsafe := failsafe;
TransformerOn := transformerOn;
AutoOn := autoOn;
BlockPumpOn := BlockPumpR;
BlockFanOn := BlockFanR;
HasD2 := hasD2;
HasDC := hasDC;
ConfigBits := 0;
IF NominalCurrent <= 0.0 THEN
    ConfigBits := ConfigBits OR WORD#16#0001;
END_IF
IF Gradient < 0.0 THEN
    ConfigBits := ConfigBits OR WORD#16#0002;
END_IF
END_FUNCTION_BLOCK

(* ===== PRG_Cooling ===== *)
PROGRAM PRG_Cooling
VAR
    ctrl : FB_Cooling;
    tNow : DWORD;
    tPrev : DWORD;
    dtMs : DWORD;
    dtSec : REAL;
    first : BOOL := TRUE;
    hi : WORD;
    lo : WORD;
    ok : BOOL;
    i : INT;
    addr : INT;
    bits : WORD;
    flags : WORD;
    strobe : WORD;
END_VAR

(* В задаче Main: только эта программа. Цикл 100 мс.
   Аналоговые входы ПЛК210-04 обновляются сами, до 0,6 с на включённый канал,
   и между опросами держат прошлое значение. Время нагрева обмотки считается
   по циклу задачи, а не по периоду АЦП.
   Среда — CODESYS V3.5 ОВЕН для устройства ПЛК210-04-CS. Пустой цикл
   контроллера около 3 мс, такт 100 мс для реле достаточен: контакт
   переключается до 10 мс. Память RETAIN PERSISTENT лежит в MRAM 64 Кбайт.
   Три клиента смотрят одни и те же переменные:
   веб-браузер — WebVisu, переменные GVL_Visu / GVL_HMI / GVL_Set;
   панель СП307 — Modbus TCP, команды в MB[100];
   верхний уровень — чтение MB[0]…MB[91] и действующих уставок MB[128]…MB[171]. *)

strobe := MB[100];
IF strobe = 1 THEN
    CoolingType := LIMIT(1, WORD_TO_INT(MB[101]), 4);
    Gradient := F_JoinReal(MB[102], MB[103], SwapWords);
    NominalCurrent := F_JoinReal(MB[104], MB[105], SwapWords);
    FanCount := LIMIT(0, WORD_TO_INT(MB[106]), FAN_MAX);
    PumpCount := LIMIT(0, WORD_TO_INT(MB[107]), PUMP_MAX);
    CoolerCount := LIMIT(0, WORD_TO_INT(MB[108]), COOLER_MAX);
    RotationHours := F_JoinReal(MB[109], MB[110], SwapWords);
    TmAt4mA := F_JoinReal(MB[111], MB[112], SwapWords);
    TmAt20mA := F_JoinReal(MB[113], MB[114], SwapWords);
    IAt20mA := F_JoinReal(MB[115], MB[116], SwapWords);
    flags := MB[117];
    BreakerRequired := (flags AND WORD#16#0001) <> WORD#0;
    UseTable4 := (flags AND WORD#16#0002) <> WORD#0;
    Group1AtIdle := (flags AND WORD#16#0004) <> WORD#0;
    UseMotorFaults := (flags AND WORD#16#0008) <> WORD#0;
    Simulation := (flags AND WORD#16#0010) <> WORD#0;
    Manual := (flags AND WORD#16#0020) <> WORD#0;
    IF (flags AND WORD#16#0040) <> WORD#0 THEN
        AiMode := 1;
    ELSE
        AiMode := 0;
    END_IF
    SwapWords := (flags AND WORD#16#0080) <> WORD#0;
    SimTm := F_JoinReal(MB[118], MB[119], SwapWords);
    SimCurrent := F_JoinReal(MB[120], MB[121], SwapWords);
    FOR i := 1 TO FAN_MAX DO
        ManualFan[i] := (MB[122] AND SHL(WORD#1, i - 1)) <> WORD#0;
    END_FOR
    FOR i := 1 TO PUMP_MAX DO
        ManualPump[i] := (MB[123] AND SHL(WORD#1, i - 1)) <> WORD#0;
    END_FOR
    ExponentY := F_JoinReal(MB[124], MB[125], SwapWords);
    TauSec := F_JoinReal(MB[126], MB[127], SwapWords);
    IF ExponentY <= 0.0 THEN
        ExponentY := 1.2;
    END_IF
    IF TauSec <= 0.0 THEN
        TauSec := 480.0;
    END_IF
ELSIF strobe = 2 THEN
    Ack := TRUE;
ELSIF strobe = 3 THEN
    ResetHours := TRUE;
ELSIF strobe = 4 THEN
    ResetTheta := TRUE;
END_IF
IF strobe <> 0 THEN
    MB[100] := 0;
END_IF

(* Кнопки WebVisu. Сброс в этом же цикле, иначе Tap останется нажат. *)
IF BtnAck THEN
    Ack := TRUE;
    BtnAck := FALSE;
END_IF
IF BtnResetHours THEN
    ResetHours := TRUE;
    BtnResetHours := FALSE;
END_IF
IF BtnResetTheta THEN
    ResetTheta := TRUE;
    BtnResetTheta := FALSE;
END_IF

tNow := TIME_TO_DWORD(TIME());
dtMs := tNow - tPrev;
tPrev := tNow;
IF first OR (dtMs > 2000) THEN
    dtSec := 0.0;
    first := FALSE;
ELSE
    dtSec := DWORD_TO_REAL(dtMs) / 1000.0;
END_IF

ctrl(dtSec := dtSec);

DO_CO_Off := CoolingOff;
DO_CO_Alarm := CoolingAlarm;
DO_Res3 := FALSE;
DO_Res4 := FALSE;
DO_D1_1 := FanRun[1];
DO_D1_2 := FanRun[2];
DO_D2_1 := FanRun[3];
DO_D2_2 := FanRun[4];
DO_DC_1 := FanRun[5];
DO_DC_2 := FanRun[6];
DO_DC_3 := FanRun[7];
DO_DC_4 := FanRun[8];

ok := F_SplitReal(Value := Tm, Hi => hi, Lo => lo);
MB[0] := SEL(SwapWords, hi, lo);
MB[1] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := Current, Hi => hi, Lo => lo);
MB[2] := SEL(SwapWords, hi, lo);
MB[3] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := Tw, Hi => hi, Lo => lo);
MB[4] := SEL(SwapWords, hi, lo);
MB[5] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := LoadPercent, Hi => hi, Lo => lo);
MB[6] := SEL(SwapWords, hi, lo);
MB[7] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := Kfactor, Hi => hi, Lo => lo);
MB[8] := SEL(SwapWords, hi, lo);
MB[9] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := DeltaSteady, Hi => hi, Lo => lo);
MB[10] := SEL(SwapWords, hi, lo);
MB[11] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := Theta, Hi => hi, Lo => lo);
MB[12] := SEL(SwapWords, hi, lo);
MB[13] := SEL(SwapWords, lo, hi);

MB[14] := INT_TO_WORD(CoolingType);

bits := 0;
IF SensorFaultTm THEN bits := bits OR WORD#16#0001; END_IF
IF SensorFaultI THEN bits := bits OR WORD#16#0002; END_IF
IF SensorFaultTnsm THEN bits := bits OR WORD#16#0004; END_IF
IF TransformerOn THEN bits := bits OR WORD#16#0008; END_IF
IF Failsafe THEN bits := bits OR WORD#16#0010; END_IF
IF Horn THEN bits := bits OR WORD#16#0020; END_IF
IF Manual OR (NOT AutoOn) THEN bits := bits OR WORD#16#0040; END_IF
IF Simulation THEN bits := bits OR WORD#16#0080; END_IF
IF StageD1 THEN bits := bits OR WORD#16#0100; END_IF
IF StageD2 THEN bits := bits OR WORD#16#0200; END_IF
IF StageDC THEN bits := bits OR WORD#16#0400; END_IF
IF AutoOn THEN bits := bits OR WORD#16#0800; END_IF
IF CoolingOff THEN bits := bits OR WORD#16#1000; END_IF
IF CoolingAlarm THEN bits := bits OR WORD#16#2000; END_IF
IF BlockPumpOn THEN bits := bits OR WORD#16#4000; END_IF
IF BlockFanOn THEN bits := bits OR WORD#16#8000; END_IF
MB[15] := bits;

bits := 0;
IF WarnOil THEN bits := bits OR WORD#16#0001; END_IF
IF AlarmOil THEN bits := bits OR WORD#16#0002; END_IF
IF WarnWinding THEN bits := bits OR WORD#16#0004; END_IF
IF AlarmWinding THEN bits := bits OR WORD#16#0008; END_IF
FOR i := 1 TO FAN_MAX DO
    IF FanFault[i] THEN bits := bits OR WORD#16#0010; END_IF
END_FOR
FOR i := 1 TO PUMP_MAX DO
    IF PumpFault[i] THEN bits := bits OR WORD#16#0010; END_IF
END_FOR
MB[16] := bits;

bits := 0;
FOR i := 1 TO FAN_MAX DO
    IF FanRun[i] THEN bits := bits OR SHL(WORD#1, i - 1); END_IF
END_FOR
MB[17] := bits;
bits := 0;
FOR i := 1 TO PUMP_MAX DO
    IF PumpRun[i] THEN bits := bits OR SHL(WORD#1, i - 1); END_IF
END_FOR
MB[18] := bits;

Heartbeat := DWORD_TO_WORD(WORD_TO_DWORD(Heartbeat) + 1);
MB[19] := Heartbeat;

addr := 20;
FOR i := 1 TO FAN_MAX DO
    ok := F_SplitReal(Value := FanHours[i], Hi => hi, Lo => lo);
    MB[addr] := SEL(SwapWords, hi, lo);
    MB[addr + 1] := SEL(SwapWords, lo, hi);
    addr := addr + 2;
END_FOR
addr := 36;
FOR i := 1 TO FAN_MAX DO
    (* UDINT в двух словах: старшее слово по младшему адресу, как у REAL. *)
    lo := DWORD_TO_WORD(UDINT_TO_DWORD(FanStarts[i]) AND DWORD#16#FFFF);
    hi := DWORD_TO_WORD(SHR(UDINT_TO_DWORD(FanStarts[i]), 16));
    IF SwapWords THEN
        MB[addr] := lo;
        MB[addr + 1] := hi;
    ELSE
        MB[addr] := hi;
        MB[addr + 1] := lo;
    END_IF
    addr := addr + 2;
END_FOR

addr := 52;
FOR i := 1 TO PUMP_MAX DO
    ok := F_SplitReal(Value := PumpHours[i], Hi => hi, Lo => lo);
    MB[addr] := SEL(SwapWords, hi, lo);
    MB[addr + 1] := SEL(SwapWords, lo, hi);
    addr := addr + 2;
END_FOR
addr := 60;
FOR i := 1 TO PUMP_MAX DO
    lo := DWORD_TO_WORD(UDINT_TO_DWORD(PumpStarts[i]) AND DWORD#16#FFFF);
    hi := DWORD_TO_WORD(SHR(UDINT_TO_DWORD(PumpStarts[i]), 16));
    IF SwapWords THEN
        MB[addr] := lo;
        MB[addr + 1] := hi;
    ELSE
        MB[addr] := hi;
        MB[addr + 1] := lo;
    END_IF
    addr := addr + 2;
END_FOR
addr := 68;
FOR i := 1 TO COOLER_MAX DO
    ok := F_SplitReal(Value := CoolerDutyHours[i], Hi => hi, Lo => lo);
    MB[addr] := SEL(SwapWords, hi, lo);
    MB[addr + 1] := SEL(SwapWords, lo, hi);
    addr := addr + 2;
END_FOR
FOR i := 1 TO COOLER_MAX DO
    MB[75 + i] := INT_TO_WORD(CoolerRole[i]);
END_FOR
ok := F_SplitReal(Value := TmMilliamp, Hi => hi, Lo => lo);
MB[80] := SEL(SwapWords, hi, lo);
MB[81] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := IMilliamp, Hi => hi, Lo => lo);
MB[82] := SEL(SwapWords, hi, lo);
MB[83] := SEL(SwapWords, lo, hi);
MB[84] := INT_TO_WORD(EffFanCount);
MB[85] := INT_TO_WORD(EffPumpCount);
MB[86] := INT_TO_WORD(EffCoolerCount);
MB[87] := ConfigBits;
ok := F_SplitReal(Value := MB_PROBE, Hi => hi, Lo => lo);
MB[90] := SEL(SwapWords, hi, lo);
MB[91] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := Tnsm, Hi => hi, Lo => lo);
MB[92] := SEL(SwapWords, hi, lo);
MB[93] := SEL(SwapWords, lo, hi);

(* Действующие уставки. Буфер записи 101…127 программа не перезаписывает,
   чтобы недописанный кадр панели не затирался. Верхний уровень и экран
   «как сейчас» читают 128…155. *)
MB[128] := INT_TO_WORD(CoolingType);
ok := F_SplitReal(Value := Gradient, Hi => hi, Lo => lo);
MB[129] := SEL(SwapWords, hi, lo);
MB[130] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := NominalCurrent, Hi => hi, Lo => lo);
MB[131] := SEL(SwapWords, hi, lo);
MB[132] := SEL(SwapWords, lo, hi);
MB[133] := INT_TO_WORD(FanCount);
MB[134] := INT_TO_WORD(PumpCount);
MB[135] := INT_TO_WORD(CoolerCount);
ok := F_SplitReal(Value := RotationHours, Hi => hi, Lo => lo);
MB[136] := SEL(SwapWords, hi, lo);
MB[137] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := TmAt4mA, Hi => hi, Lo => lo);
MB[138] := SEL(SwapWords, hi, lo);
MB[139] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := TmAt20mA, Hi => hi, Lo => lo);
MB[140] := SEL(SwapWords, hi, lo);
MB[141] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := IAt20mA, Hi => hi, Lo => lo);
MB[142] := SEL(SwapWords, hi, lo);
MB[143] := SEL(SwapWords, lo, hi);
flags := 0;
IF BreakerRequired THEN flags := flags OR WORD#16#0001; END_IF
IF UseTable4 THEN flags := flags OR WORD#16#0002; END_IF
IF Group1AtIdle THEN flags := flags OR WORD#16#0004; END_IF
IF UseMotorFaults THEN flags := flags OR WORD#16#0008; END_IF
IF Simulation THEN flags := flags OR WORD#16#0010; END_IF
IF Manual THEN flags := flags OR WORD#16#0020; END_IF
IF AiMode = 1 THEN flags := flags OR WORD#16#0040; END_IF
IF SwapWords THEN flags := flags OR WORD#16#0080; END_IF
MB[144] := flags;
ok := F_SplitReal(Value := SimTm, Hi => hi, Lo => lo);
MB[145] := SEL(SwapWords, hi, lo);
MB[146] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := SimCurrent, Hi => hi, Lo => lo);
MB[147] := SEL(SwapWords, hi, lo);
MB[148] := SEL(SwapWords, lo, hi);
bits := 0;
FOR i := 1 TO FAN_MAX DO
    IF ManualFan[i] THEN bits := bits OR SHL(WORD#1, i - 1); END_IF
END_FOR
MB[149] := bits;
bits := 0;
FOR i := 1 TO PUMP_MAX DO
    IF ManualPump[i] THEN bits := bits OR SHL(WORD#1, i - 1); END_IF
END_FOR
MB[150] := bits;
ok := F_SplitReal(Value := ExponentY, Hi => hi, Lo => lo);
MB[151] := SEL(SwapWords, hi, lo);
MB[152] := SEL(SwapWords, lo, hi);
ok := F_SplitReal(Value := TauSec, Hi => hi, Lo => lo);
MB[153] := SEL(SwapWords, hi, lo);
MB[154] := SEL(SwapWords, lo, hi);
FOR i := 1 TO FAN_MAX DO
    MB[159 + i] := FanReason[i];
END_FOR
FOR i := 1 TO PUMP_MAX DO
    MB[167 + i] := PumpReason[i];
END_FOR

IF ConfigBits <> 0 THEN
    BannerCode := 7;
ELSIF SensorFaultTm OR SensorFaultI THEN
    BannerCode := 6;
ELSIF AlarmOil THEN
    BannerCode := 2;
ELSIF AlarmWinding THEN
    BannerCode := 3;
ELSIF WarnOil THEN
    BannerCode := 4;
ELSIF WarnWinding THEN
    BannerCode := 5;
ELSIF NOT TransformerOn THEN
    BannerCode := 8;
ELSIF Manual OR (NOT AutoOn) THEN
    BannerCode := 9;
ELSE
    BannerCode := 0;
END_IF
END_PROGRAM
