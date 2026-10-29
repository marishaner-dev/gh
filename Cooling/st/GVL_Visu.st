(* Команды веб-визуализации ПЛК210. Экран Visu_Main пишет сюда кнопки,
   программа снимает их в том же цикле. Числа и лампы веб-экран берёт
   напрямую из GVL_HMI и GVL_Set, второй образ для них не нужен.
   Текст кода BannerCode — в plc/WEBVISU.md, список текстов Text_Banner. *)
VAR_GLOBAL
    BtnAck : BOOL;          (* кнопка «Квитировать», Tap *)
    BtnResetHours : BOOL;   (* кнопка «Сбросить наработку» *)
    BtnResetTheta : BOOL;   (* кнопка «Сбросить нагрев обмотки» *)
    BannerCode : INT;       (* 0…9, текст состояния для WebVisu *)
    Heartbeat : WORD;       (* +1 каждый цикл PRG_Cooling, то же значение в MB[19] *)
END_VAR
