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
(* BODY *)
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
