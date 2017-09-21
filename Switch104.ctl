// 
// @author XoXoXo
// @desc Скрипт, выполняющий переключение соединения с активного на пассивное. 
// @desc Переключение происходит только в том случае, если на активном соединении
// @desc потеряна связь до КЦ, а на пассивном связь есть до всех КЦ. 
// @desc Если на пассивном соединении нет связи хотя бы до одного КЦ, то переключения не произойдет.
//
//--------------------------------------------------------------------------------------------------
mapping structDiagLink = makeMapping("oldValue", 0, "currentValue", 0, "timeoutMs", 0); // имитация объявления структуры
mapping structDiagCon = makeMapping("errCountCh1", 0, "errCountCh2", 0); 
int T_DIAG_LINK_KC = 15; // максимальное время ожидания счетчика, в секундах
int DIAG_INTERVAL = 1; // интервал запуска диагностики, в секундах
string PATTERN_NAME_COUNTERS = "*CounterKC_Con*";
string DPT_NAME = "\"_KC_Diag\"";
string nameConDataCh = "NameConDataCh";
string nameCounterCh = "CounterCh";
main()
{
   DebugN("Start Switch104...");
   switchOption3();
}

// Вариант переключения соединения, когда на одном из 
// соединений нет связи хотя бы до одного КЦ, а на другом соединении есть связь ко всем КЦ.

//-----------------------------------------------------------------------------------------
// @desc Вариант переключения при реализации схемы 3 (совпадает с правилами в описании всего скрипта)
// @author XoXoXo
// @lastmodified 20-09-2017 v.1.00
//-----------------------------------------------------------------------------------------
void switchOption3()
{
   mapping diagTree; // дерево со всей структурой
   mapping diagDict; // словарь вида Имя переменной-Название соединения
   mapping errReport; // отчет об ошибках
   dyn_dyn_anytype ddaDiagDPs = getValuesDPbyDPT(DPT_NAME);
   createDiag(ddaDiagDPs, diagTree, diagDict);
   while (true)
   {
      updateTree(diagTree, diagDict);
      processTree(diagTree, diagDict, errReport);
      switchingArbiter(errReport);
      delay(DIAG_INTERVAL);
   }   
}

void testSql()
{
   dyn_dyn_anytype ddaDataSet;
   dpQuery("SELECT '_original.._value' FROM '*' WHERE _DPT = \"_KC_Diag\"", ddaDataSet);
   DebugN(ddaDataSet);
}

//-----------------------------------------------------------------------------------------
// @desc Формирует двумерный массив формата: (имя точки1, значение1), (имя точки2, значение2),...
// @author XoXoXo
// @param patternDPT - шаблон для выборки точек, задаваемый строкой
// @return - (имя точки1, значение1), (имя точки2, значение2),...
// @lastmodified 20-09-2017 v.1.00
//-----------------------------------------------------------------------------------------
dyn_dyn_anytype getValuesDPbyDPT(string patternDPT)
{
   dyn_dyn_anytype ddaRes;
   dyn_dyn_anytype ddaDataSet;
   dpQuery("SELECT '_original.._value' FROM '*' WHERE _DPT = " + patternDPT, ddaDataSet); // SELECT '_original.._value' FROM '" + pattern + "'"
   for (int i = 2; i <= dynlen(ddaDataSet); i++) // первая срока заголовок таблицы, поэтому пропускаем
   {
      dyn_string dsTemp = strsplit(ddaDataSet[i], ' ');
      ddaRes[i - 1][1] = dsTemp[1]; 
      ddaRes[i - 1][2] = ddaDataSet[i][2];
   }
   return ddaRes;
}

//-----------------------------------------------------------------------------------------
// @desc Формирует дерево для анализа состояния соединений до КЦ
// @author XoXoXo
// @param diagDPs - ссылка на двумерный массив с точками данных и их значениями, по которым будет строиться дерево 
// @param tree - дерево-результат
// @param dict - словарь типа "Имя конфигурационной точки" - "Название соединения"
// @return - код выполнения функции ()
// @lastmodified 20-09-2017 v.1.00
//----------------------------------------------------------------------------------------- 
int createDiag(dyn_dyn_anytype &diagDPs, mapping &tree, mapping &dict)
{
   // формат вывода после выполнения цикла ниже
   // WCCOActrl100:["Start Switch104..."]
   // WCCOActrl100:[mapping 2 items
   // WCCOActrl100:         "IECTARGET_KAZAN_NPS1_KK" : 	mapping 2 items
   // WCCOActrl100:	         "System1:Kazan_PNS_CounterKC" : 		mapping 2 items
   // WCCOActrl100:		         "2" : 			mapping 3 items
   // WCCOActrl100:			         "oldValue" : 0
   // WCCOActrl100:			         "currentValue" : 0
   // WCCOActrl100:			         "timeoutMs" : 0
   // WCCOActrl100:		         "1" : 			mapping 3 items
   // WCCOActrl100:			         "oldValue" : 0
   // WCCOActrl100:			         "currentValue" : 0
   // WCCOActrl100:			         "timeoutMs" : 0
   // WCCOActrl100:	         "System1:Kazan_MNS_CounterKC" : 		mapping 2 items
   // WCCOActrl100:		         "2" : 			mapping 3 items
   // WCCOActrl100:			         "oldValue" : 0
   // WCCOActrl100:			         "currentValue" : 0
   // WCCOActrl100:			         "timeoutMs" : 0
   // WCCOActrl100:		         "1" : 			mapping 3 items
   // WCCOActrl100:			         "oldValue" : 0
   // WCCOActrl100:			         "currentValue" : 0
   // WCCOActrl100:			         "timeoutMs" : 0
   // WCCOActrl100:         "IECTARGET_SAMARA_NPS1_KK" : 	mapping 3 items
   // WCCOActrl100:	         "System1:Samara_RP_CounterKC" : 		mapping 2 items
   // WCCOActrl100:		         "2" : 			mapping 3 items
   // WCCOActrl100:			         "oldValue" : 0
   // WCCOActrl100:			         "currentValue" : 0
   // WCCOActrl100:			         "timeoutMs" : 0
   // WCCOActrl100:		         "1" : 			mapping 3 items
   // WCCOActrl100:			         "oldValue" : 0
   // WCCOActrl100:			         "currentValue" : 0
   // WCCOActrl100:			         "timeoutMs" : 0
   // WCCOActrl100:	         "System1:Samara_MNS_CounterKC" : 		mapping 2 items
   // WCCOActrl100:		         "2" : 			mapping 3 items
   // WCCOActrl100:			         "oldValue" : 0
   // WCCOActrl100:			         "currentValue" : 0
   // WCCOActrl100:			         "timeoutMs" : 0
   // WCCOActrl100:		         "1" : 			mapping 3 items
   // WCCOActrl100:			         "oldValue" : 0
   // WCCOActrl100:			         "currentValue" : 0
   // WCCOActrl100:			         "timeoutMs" : 0
   // WCCOActrl100:	         "System1:Samara_PNS_CounterKC" : 		mapping 2 items
   // WCCOActrl100:		         "2" : 			mapping 3 items
   // WCCOActrl100:			         "oldValue" : 0
   // WCCOActrl100:			         "currentValue" : 0
   // WCCOActrl100:			         "timeoutMs" : 0
   // WCCOActrl100:		         "1" : 			mapping 3 items
   // WCCOActrl100:			         "oldValue" : 0
   // WCCOActrl100:			         "currentValue" : 0
   // WCCOActrl100:			         "timeoutMs" : 0
   // WCCOActrl100:]
   string patternStr;   
   string dpName;
   string nameKC;
   string conName;
   mapping levelCon;
   int fResult = -1;
   // очистка контейнеров
   mappingClear(tree);
   mappingClear(dict);
   patternStr = PATTERN_NAME_COUNTERS;
   strchange(patternStr, strlen(PATTERN_NAME_COUNTERS) - 1, 1, "?");
   
   for (int i = 1; i <= dynlen(diagDPs); i++)
   {    
      dpName = diagDPs[i][1];
      nameKC = dpSubStr(dpName, DPSUB_SYS_DP);
      // sdfsdfsfd
      if (strpos(dpName, nameConDataCh) >= 0) // точка с информацией по соединению. По ней строится верхушка дерева
      {
         conName = diagDPs[i][2];   
         dict[nameKC] = conName; // заполнение словаря   
         if (!mappingHasKey(tree, conName))
         {
            tree[conName] = makeMapping();
         }
         levelCon = tree[conName];
         if (!mappingHasKey(levelCon, nameKC))
         {
            levelCon[nameKC] = makeMapping();
         };
         tree[conName] = levelCon;
      }
      else
         if (strpos(dpName, nameCounterCh) >= 0)            
         {
            string idx = dpName[strlen(dpName) - 1];
            conName = dict[nameKC];
            tree[conName][nameKC][idx] = structDiagLink;
         }   
   }
   fResult = 1;
   //DebugN(tree);
   //DebugN(dict);
   return fResult;
}

//-----------------------------------------------------------------------------------------
// @desc Осуществляет запись значений счетчиков в дерево
// @author XoXoXo
// @param dpName - имя точки 
// @param dpValue - значение точки данных
// @param tree - дерево данных
// @param dict - словарь типа "Имя конфигурационной точки" - "Название соединения"
// @return - код выполнения функции ()
// @lastmodified 20-09-2017 v.1.00
//----------------------------------------------------------------------------------------- 
int writeValueToTree(string dpName, float dpValue, mapping &tree, mapping &dict)
{
   string nameKC = dpSubStr(dpName, DPSUB_SYS_DP);
   string idx, conName;
   if (strpos(dpName, nameCounterCh) >= 0)            
      {
         idx = dpName[strlen(dpName) - 1];
         if (isTreeHasDp(dpName, tree, dict))
         {
            conName = dict[nameKC];
            structDiagLink = tree[conName][nameKC][idx];
            structDiagLink["currentValue"] = dpValue;
            tree[conName][nameKC][idx] = structDiagLink;
         }   
         else
         {
            ; 
            //throwError(makeError("", PRIO_WARNING, ERR_PARAM, 0, "Для точки " + dpName + "не создана структура в дереве. Необходимо перезапустить скрипт для переинициализации."));               
         }
      } 
   return 1;   
}

//-----------------------------------------------------------------------------------------
// @desc Функция проверяет существование точки в дереве объектов 
// @author XoXoXo
// @param dpName - имя точки 
// @param tree - дерево данных
// @param dict - словарь типа "Имя конфигурационной точки" - "Название соединения"
// @return - true - точка существует в дереве, false - не существует
// @lastmodified 20-09-2017 v.1.00
//-----------------------------------------------------------------------------------------
bool isTreeHasDp(string dpName, mapping &tree, mapping &dict)
{
   string nameKC = dpSubStr(dpName, DPSUB_SYS_DP);
   if (!mappingHasKey(dict, nameKC)) 
   {
      return false;
   }   
   string conName = dict[nameKC];
   string idx = dpName[strlen(dpName) - 1];
   if (!mappingHasKey(tree, conName) || !mappingHasKey(tree[conName], nameKC) || !mappingHasKey(tree[conName][nameKC], idx))
   {
      return false;
   }
   return true;
}

//-----------------------------------------------------------------------------------------
// @desc Обновляет дерево значениями из точек
// @author XoXoXo
// @param tree - дерево данных
// @param dict - словарь типа "Имя конфигурационной точки" - "Название соединения"
// @return - код выполнения функции ()
// @lastmodified 20-09-2017 v.1.00
//----------------------------------------------------------------------------------------- 
int updateTree(mapping &tree, mapping &dict)
{
   dyn_dyn_anytype diagDPs = getValuesDPbyDPT(DPT_NAME);
   for (int i = 1; i <= dynlen(diagDPs); i++)
   {
      writeValueToTree(diagDPs[i][1], diagDPs[i][2], tree, dict);
   }
   return 1;
}

//-----------------------------------------------------------------------------------------
// @desc Обновляет дерево значениями из точек
// @author XoXoXo
// @param tree - дерево данных
// @param dict - словарь типа "Имя конфигурационной точки" - "Название соединения"
// @param res - отчет по соединениям, у которых нет связи с КЦ, в виде сопоставления вида "Имя соединения" - structDiagCon
// @return - код выполнения функции ()
// @lastmodified 20-09-2017 v.1.00
//----------------------------------------------------------------------------------------- 
int processTree(mapping &tree, mapping &dict, mapping &res)
{
   mapping connection;
   mapping kc; 
   string keyConnection, keyKC, keyDiagLink;
   int result = 0;
   mappingClear(res);
   for (int i = 1; i <= mappinglen(tree); i++)
   {
      keyConnection = mappingGetKey(tree, i);
      connection = tree[keyConnection];
      for (int j = 1; j <= mappinglen(connection); j++)
      {
         keyKC = mappingGetKey(connection, j);
         kc = connection[keyKC];
         for (int k = 1; k <= mappinglen(kc); k++)
         {
            keyDiagLink = mappingGetKey(kc, k);
            structDiagLink = kc[keyDiagLink];
            if (structDiagLink["currentValue"] == structDiagLink["oldValue"])
            {
               structDiagLink["timeoutMs"] += DIAG_INTERVAL;
            }
            else
            {
               structDiagLink["oldValue"] = structDiagLink["currentValue"];
               structDiagLink["timeoutMs"] = 0;
            }
            if (structDiagLink["timeoutMs"] > T_DIAG_LINK_KC)
            {
               result++;
               if (!mappingHasKey(res, keyConnection))
               {
                  res[keyConnection] = makeMapping();
               }
               structDiagCon = res[keyConnection];
               switch (keyDiagLink) 
               {
                  case "1": ++structDiagCon["errCountCh1"]; break;
                  case "2": ++structDiagCon["errCountCh2"]; break;
               }
               res[keyConnection] = structDiagCon;
            }
            tree[keyConnection][keyKC][keyDiagLink] = structDiagLink;
         }
      }
   }
   return 1;
}

//-----------------------------------------------------------------------------------------
// @desc Арбитор переключения соединений
// @author XoXoXo
// @param errReport - отчет об ошибках формата "Имя соединени" - "Счетчики ошибок в структуре structDiagCon"
// @return - код выполнения функции ()
// @lastmodified 20-09-2017 v.1.00
//----------------------------------------------------------------------------------------- 
int switchingArbiter(mapping &errReport)
{
   string keyConnection;
   for (int i = 1; i <= mappinglen(errReport); i++)
   {
      keyConnection = mappingGetKey(errReport, i);
      structDiagCon = errReport[keyConnection];
      if ((structDiagCon["errCountCh1"] > 0) && (structDiagCon["errCountCh2"] = 0)) // связь с КЦ потеряна на ch1, а на ch2 все в порядке
      {
         
      } 
      else if ((structDiagCon["errCountCh1"] = 0) && (structDiagCon["errCountCh1"] > 0)) // связь с КЦ потеряна на ch2, а на ch1 все в порядке
      {
         
      } 
      else
      {
         ;// ничего не делаем
      }
         
      DebugN(keyConnection);
   }
}

int switchCon(string conName)
{
   
}

//-----------------------------------------------------------------------------------------
// @desc
// @author
// @param
// @param
// @return
// @lastmodified 20-09-2017 v.1.00
//-----------------------------------------------------------------------------------------
int getErrCnt( string conName, int conID, mapping &diagStruct )
{
   
   return 0;
}
