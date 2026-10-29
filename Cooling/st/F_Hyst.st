FUNCTION F_Hyst : BOOL
VAR_INPUT
    Prev : BOOL;
    Value : REAL;
    LevelOn : REAL;
    LevelOff : REAL;
END_VAR
(* BODY *)
IF (NOT Prev) AND (Value >= LevelOn) THEN
    F_Hyst := TRUE;
ELSIF Prev AND (Value <= LevelOff) THEN
    F_Hyst := FALSE;
ELSE
    F_Hyst := Prev;
END_IF
