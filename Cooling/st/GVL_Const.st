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
