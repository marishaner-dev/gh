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
(* BODY *)
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
