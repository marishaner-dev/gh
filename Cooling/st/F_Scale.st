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
(* BODY *)
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
