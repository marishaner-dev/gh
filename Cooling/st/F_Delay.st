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
(* BODY *)
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
