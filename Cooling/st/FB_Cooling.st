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
(* BODY *)
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
