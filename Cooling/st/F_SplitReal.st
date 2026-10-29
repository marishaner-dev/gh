FUNCTION F_SplitReal : BOOL
VAR_INPUT
    Value : REAL;
END_VAR
VAR_OUTPUT
    Hi : WORD;
    Lo : WORD;
END_VAR
VAR
    tmp : REAL;
    pw : POINTER TO WORD;
END_VAR
(* BODY *)
(* Память ПЛК210 little-endian: первое слово REAL — младшее. *)
tmp := Value;
pw := ADR(tmp);
Lo := pw^;
pw := pw + 1;
Hi := pw^;
F_SplitReal := TRUE;
