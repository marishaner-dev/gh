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
(* BODY *)
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
