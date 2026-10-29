FUNCTION F_StageTable : ST_Stage
VAR_INPUT
    CoolingType : INT;
    Stage : INT; (* 1 — Д1, 2 — Д2, 3 — ДЦ *)
END_VAR
VAR
    row : ST_Stage;
END_VAR
(* BODY *)
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
