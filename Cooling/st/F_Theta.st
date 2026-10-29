FUNCTION F_Theta : REAL
VAR_INPUT
    Theta : REAL;
    DeltaSteady : REAL;
    dtSec : REAL;
    TauSec : REAL;
END_VAR
VAR
    alpha : REAL;
END_VAR
(* BODY *)
(* Шаг формулы To = ΔT·(1 − e^(−t/τ)) + Tm.
   При скачке нагрузки это апериодическое звено, а не время от включения контроллера. *)
IF (dtSec > 0.0) AND (TauSec > 0.0) THEN
    alpha := 1.0 - EXP(-dtSec / TauSec);
    F_Theta := Theta + (DeltaSteady - Theta) * alpha;
ELSE
    F_Theta := Theta;
END_IF
