(* Структуры проекта охлаждения трансформатора.
   Импорт: в CODESYS создать DUT с этими именами или импортировать Cooling.xml. *)

TYPE ST_Stage :
STRUCT
    Used : BOOL;
    TmOn : REAL;   (* °C, масло, включение *)
    TmOff : REAL;
    TwOn : REAL;   (* °C, обмотка *)
    TwOff : REAL;
    LoadOn : REAL; (* % In *)
    LoadOff : REAL;
END_STRUCT
END_TYPE

TYPE ST_Analog :
STRUCT
    Eu : REAL;
    Milliamp : REAL;
    Fault : BOOL;
END_STRUCT
END_TYPE
