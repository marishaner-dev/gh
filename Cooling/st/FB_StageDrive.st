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
(* BODY *)
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
