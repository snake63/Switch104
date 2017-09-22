/*
   @author XoXoXo
   @desc Скрипт, выполняющий переключение соединения с активного на пассивное. 
   @desc Переключение происходит только в том случае, если на активном соединении
   @desc потеряна связь до КЦ, а на пассивном связь есть до всех КЦ. 
   @desc Если на пассивном соединении нет связи хотя бы до одного КЦ, то переключения не произойдет.
*/

// TODO: реализовать контроль входных параметров. Т.е.:
// TODO: 1. Не должно быть одинаковых названий диагностических соединений у коннекшенов к различным КК ()
// TODO: 2. Не должно быть одинаковых названий у соединений в различным КК ()
// TODO: 
// TODO:
// TODO: Если контроль входных параметров нарушен, то скрипт не должен выполняться.

// TODO: проверить, как отработает система при удалении/добавлении новых диагностических точек, соединений

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

/*
   @desc Вариант переключения при реализации схемы 3 (совпадает с правилами в описании всего скрипта)
   @author XoXoXo
   @lastmodified 20-09-2017 v.1.00
*/
void switchOption3()
{
   mapping diagTree; // дерево со всей структурой
   mapping dictDpCon; // словарь вида "Имя переменной" - "Название соединения"
   mapping dictConDataConDiag; // словарь вида "Имя соединения с данными" - "Имя соединения для диагностических точек"
   mapping errReport; // отчет об ошибках
   dyn_dyn_anytype ddaDiagDPs = getValuesDPbyDPT(DPT_NAME);
   // TODO: реализовать заполнение словаря dictConDataConDiag
   createDiag(ddaDiagDPs, diagTree, dictDpCon, dictConDataConDiag);
   while (true)
   {
      updateTree(diagTree, dictDpCon);
      processTree(diagTree, dictDpCon, errReport);
      //TODO: реализовать применение словаря
      switchingArbiter(errReport, dictConDataConDiag);
      delay(DIAG_INTERVAL);
   }   
}

/*
   @desc Формирует двумерный массив формата: (имя точки1, значение1), (имя точки2, значение2),...
   @author XoXoXo
   @param patternDPT - шаблон для выборки точек, задаваемый строкой
   @return - (имя точки1, значение1), (имя точки2, значение2),...
   @lastmodified 20-09-2017 v.1.00
*/
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

/*
   @desc Формирует дерево для анализа состояния соединений до КЦ
   @author XoXoXo
   @param diagDPs - ссылка на двумерный массив с точками данных и их значениями, по которым будет строиться дерево 
   @param tree - дерево-результат
   @param dictDpCon - словарь типа "Имя конфигурационной точки" - "Название соединения"
   @return - код выполнения функции ()
   @lastmodified 20-09-2017 v.1.00
*/
int createDiag(dyn_dyn_anytype &diagDPs, mapping &tree, mapping &dictDpCon, mapping &dictConDataConDiag)
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
   string idx;
   string conNameDiag;
   string dpAddrRef;
   // очистка контейнеров
   mappingClear(tree);
   mappingClear(dictDpCon);
   mappingClear(dictConDataConDiag);
   patternStr = PATTERN_NAME_COUNTERS;
   strchange(patternStr, strlen(PATTERN_NAME_COUNTERS) - 1, 1, "?");
   
   for (int i = 1; i <= dynlen(diagDPs); i++)
   {    
      dpName = diagDPs[i][1];
      nameKC = dpSubStr(dpName, DPSUB_SYS_DP);
      if (strpos(dpName, nameConDataCh) >= 0) // точка с информацией по соединению. По ней строится верхушка дерева
      {
         conName = diagDPs[i][2];   
         dictDpCon[nameKC] = conName; // заполнение словаря   
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
         if (strpos(dpName, nameCounterCh) >= 0) // точка со значением счетчика           
         {
            idx = dpName[strlen(dpName) - 1];
            conName = dictDpCon[nameKC];
            tree[conName][nameKC][idx] = structDiagLink;
            
            // TODO: проверить
            if (!mappingHasKey(dictConDataConDiag, conName))
            {
               dpGet(dpName + ":_address.._reference", dpAddrRef);
               //DebugN(dpAddrRef);
               if (!getNameCon(dpAddrRef, conNameDiag))
               {
                  throwError(makeError("", PRIO_WARNING, ERR_PARAM, 0, "Для точки " + dpName + " задан некорректный адрес подключения.")));
               } 
               else
               {
                  dictConDataConDiag[conName] = conNameDiag; // заполняется именем соединения, которое отвечает за диагностический канал
               }   
            }
            else
            {
               // проверка на правильность конфигурирования соединений для диагностических точек
               // лучше ее сделать до построения дерева...
               // одним запросом считываем все точки и делаем анализ...
               // conNameDiag = dictConDataConDiag[conName];
            }
         }   
   }
   //DebugN(diagDPs);
   //DebugN(tree);
   //DebugN(dictDpCon);
   return 1;
}

/*
   @desc Парсит строку типа IECTARGET-13.0.1.0.0.1
   @author XoXoXo
   @param addrRef - строка типа IECTARGET-13.0.1.0.0.1 
   @param nameCon - имя соединения (IECTARGET)
   @param typeIdent - идентификатор типа точки TI (13)
   @param asdu1 - старший байт адреса ASDU
   @param asdu0 - младший байт адреса ASDU
   @param ioa2 - старший байт адреса IOA
   @param ioa1 - средний байт адреса IOA
   @param ioa0 - младший байт адреса IOA
   @return - код выполнения функции (1 - парсинг успешен, 0 - ошибка формата адреса)
   @lastmodified 20-09-2017 v.1.00
*/
int parseIecAddrRef(string addrRef, string &nameCon, int &typeIdent, int &asdu1, int &asdu0, int &ioa2, int &ioa1, int &ioa0 )
{
   // TODO: проверить
   int idx = strpos(addrRef, "-");
   DebugN(idx);
   addrRef = substr(addrRef, 0, idx); // имя соединения (IECTARGET)
   DebugN(addrRef);
   string tmpS = substr(addrRef, idx + 1, strlen(addrRef) - idx); // все, что справа от тире (13.0.1.0.0.1) 
   DebugN(tmpS);
   dyn_string dsContainer = strsplit(tmpS, ".");
   if (dynlen(dsContainer) != 6)
   {
      return 0;
   }
   typeIdent = dsContainer[1];
   asdu1 = dsContainer[2];
   asdu0 = dsContainer[3];
   ioa2 = dsContainer[4];
   ioa1 = dsContainer[5];
   ioa0 = dsContainer[6];     
   return 1;
}

/*
   @desc Возвращает из строки типа IECTARGET-13.0.1.0.0.1 название соединения
   @author XoXoXo
   @param addrRef - строка типа IECTARGET-13.0.1.0.0.1  
   @param nameCon - имя соединения (IECTARGET)
   @return - код выполнения функции (1 - парсинг успешен, 0 - ошибка формата адреса)
   @lastmodified 20-09-2017 v.1.00
*/
int getNameCon(string addrRef, string &nameCon)
{
   // TODO: проверить
   int ti, asdu1, asdu0, ioa2, ioa1, ioa0;
   return = parseIecAddrRef(addrRef, nameCon, ti, asdu1, asdu0, ioa2, ioa1, ioa0);
}

/*
   @desc Устанавливает имя соединения :address_reference (IECTARGET-13.0.1.0.0.1)
   @author XoXoXo
   @param addrRef - строка типа IECTARGET-13.0.1.0.0.1  
   @param nameCon - новое имя соединения (IECTARGET)
   @return - код выполнения функции (1 - успех, 0 - ошибка формата адреса)
   @lastmodified 20-09-2017 v.1.00
*/
string getNewIecAddrRef(string addrRef, string newNameCon)
{
   // TODO: проверить
   int idx = strpos(addrRef, "-");
   return newNameCon + "-" + substr(addrRef, ids + 1, strlen(addrRef) - idx - 1);
}

/*
   @desc Осуществляет запись значений счетчиков в дерево
   @author XoXoXo
   @param dpName - имя точки 
   @param dpValue - значение точки данных
   @param tree - дерево данных
   @param dictDpCon - словарь типа "Имя конфигурационной точки" - "Название соединения"
   @return - код выполнения функции ()
   @lastmodified 20-09-2017 v.1.00
*/
int writeValueToTree(string dpName, float dpValue, mapping &tree, mapping &dictDpCon)
{
   string nameKC = dpSubStr(dpName, DPSUB_SYS_DP);
   string idx, conName;
   if (strpos(dpName, nameCounterCh) >= 0)            
      {
         idx = dpName[strlen(dpName) - 1];
         if (isTreeHasDp(dpName, tree, dictDpCon))
         {
            conName = dictDpCon[nameKC];
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

/*
   @desc Функция проверяет существование точки в дереве объектов 
   @author XoXoXo
   @param dpName - имя точки 
   @param tree - дерево данных
   @param dictDpCon - словарь типа "Имя конфигурационной точки" - "Название соединения"
   @return - true - точка существует в дереве, false - не существует
   @lastmodified 20-09-2017 v.1.00
*/
bool isTreeHasDp(string dpName, mapping &tree, mapping &dictDpCon)
{
   string nameKC = dpSubStr(dpName, DPSUB_SYS_DP);
   if (!mappingHasKey(dictDpCon, nameKC)) 
   {
      return false;
   }   
   string conName = dictDpCon[nameKC];
   string idx = dpName[strlen(dpName) - 1];
   if (!mappingHasKey(tree, conName) || !mappingHasKey(tree[conName], nameKC) || !mappingHasKey(tree[conName][nameKC], idx))
   {
      return false;
   }
   return true;
}

/*
   @desc Обновляет дерево значениями из точек
   @author XoXoXo
   @param tree - дерево данных
   @param dictDpCon - словарь типа "Имя конфигурационной точки" - "Название соединения"
   @return - код выполнения функции ()
   @lastmodified 20-09-2017 v.1.00
*/
int updateTree(mapping &tree, mapping &dictDpCon)
{
   dyn_dyn_anytype diagDPs = getValuesDPbyDPT(DPT_NAME);
   for (int i = 1; i <= dynlen(diagDPs); i++)
   {
      writeValueToTree(diagDPs[i][1], diagDPs[i][2], tree, dictDpCon);
   }
   return 1;
}

/*
   @desc Обновляет дерево значениями из точек
   @author XoXoXo
   @param tree - дерево данных
   @param dictDpCon - словарь типа "Имя конфигурационной точки" - "Название соединения"
   @param res - отчет по соединениям, у которых нет связи с КЦ, в виде сопоставления вида "Имя соединения" - structDiagCon
   @return - код выполнения функции ()
   @lastmodified 20-09-2017 v.1.00
*/
int processTree(mapping &tree, mapping &dictDpCon, mapping &res)
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

/*
   @desc Арбитор переключения соединений
   @author XoXoXo
   @param errReport - отчет об ошибках формата "Имя соединени" - "Счетчики ошибок в структуре structDiagCon"
   @return - код выполнения функции ()
   @lastmodified 20-09-2017 v.1.00
*/
int switchingArbiter(mapping &errReport, mapping &dictConDataConDiag)
{
   string keyDataConnection;
   string keyDiagConnection;
   dyn_string conNames;
   dyn_int conIDs;
   for (int i = 1; i <= mappinglen(errReport); i++)
   {
      keyDataConnection = mappingGetKey(errReport, i);
      // keyDiagConnection = ?;
      structDiagCon = errReport[keyDataConnection];
      if ((structDiagCon["errCountCh1"] > 0) && (structDiagCon["errCountCh2"] = 0)) // связь с КЦ потеряна на ch1, а на ch2 все в порядке
      {
         // перепривязать диагностические теги на другое соединение
         // TODO: реализовать
         setIecConName();
         // выполнить переключение соединений
         conNames = (keyDataConnection, keyDataConnection + "_2", keyDiagConnection, keyDiagConnection + "_2");
         conIDs = (2, 2, 1, 1);
         setActiveConMulti(conNames, conIDs);
         /*
         setActiveCon(keyDataConnection, 2);
         setActiveCon(keyDataConnection + "_2", 2);
         setActiveCon(keyDiagConnection, 1);
         setActiveCon(keyDiagConnection + "_2", 1);
         */
      } 
      else if ((structDiagCon["errCountCh1"] = 0) && (structDiagCon["errCountCh2"] > 0)) // связь с КЦ потеряна на ch2, а на ch1 все в порядке
      {
         // перепривязать диагностические теги на другое соединение
         // TODO: реализовать
         setIecConName();
         // выполнить переключение соединений
         conNames = (keyDataConnection, keyDataConnection + "_2", keyDiagConnection, keyDiagConnection + "_2");
         conIDs = (1, 1, 2, 2);
         setActiveConMulti(conNames, conIDs);
         /*
         setActiveCon(keyDataConnection, 1);
         setActiveCon(keyDataConnection + "_2", 1);
         setActiveCon(keyDiagConnection, 2);
         setActiveCon(keyDiagConnection + "_2", 2);
         */
      } 
      else
      {
         ;// ничего не делаем
      }
         
      //DebugN(keyDataConnection);
   }
}

/*
   @desc Функция устанавливает соединение для списка точек
   @author XoXoXo
   @param dsDpNames - список имен точек
   @param conName - название соединения, которое будет установлено 
   @return - код выполнения функции (1 - успех, 0 - ошибка установки нового соединения)
   @lastmodified 20-09-2017 v.1.00
*/
int setIecConName(dyn_string dsDpNames, string conName)
{
   // TODO: проверить
   dyn_string dsDpNamesAddr;
   dyn_string dsDpNewAddr;
   dyn_dyn_anytype dpGetRes;
   for (int i = 1; i <= dynlen(dsDpNames); i++)
   {
      dsDpNamesAddr[i] = dsDpNames[i] + ":_address.._reference";
   }
   // если хоть одна точка не существует, то функция возвращает пустое множество
   dpGet(dsDpNamesAddr, dpGetRes);
   if (dynlen(dpGetRes) == 0)
   {
      return 0;
   }
   else
   {
      for (int i = 1; i <= dynlen(dpGetRes); i++)
      {
         dsDpNewAddr[i] = getNewIecAddrRef(dpGetRes[i][1], conName);
      }
      dpSet(dsDpNamesAddr, dsDpNewAddr);
   }
   return 1;
}

/*
   @desc Установка активного соединения внутри подключения
   @author XoXoXo
   @param conName - название подключения
   @param conID - ID соединения, которое делаем активным
   @return - код выполнения функции ()
   @lastmodified 22-09-2017 v.1.00
*/
int setActiveCon(string conName, int conID)
{
   // TODO: проверить
   dpSet(conName + ".Config.ForceActive", conID); 
}

/*
   @desc Установка активного соединения внутри подключения для нескольких соединений в одном запросе dpSet
   @author XoXoXo
   @param conNames - название подключений
   @param conIDs - ID соединений, которые делаем активными
   @return - код выполнения функции ()
   @lastmodified 22-09-2017 v.1.00
*/
int setActiveConMulti(dyn_string conNames, dyn_int conIDs)
{
   if (dynlen(conNames) == dynlen(conIDs))
   {
      dyn_string dpConNames;
      for (int i = 1; i <= dynlen(conNames); i++)
      {
         dpConNames[i] = conNames[i] + ".Config.ForceActive";
      }
      dpSet(conNames, conIDs);

   } 
   else
   {
      // TODO: придумать, как об этом сигнализировать и нужно ли вообще сигналить
      ; // какая-то ошибка при формировании параметров на вход функции
   }
}   




// Раздел с тестовыми функциями
// ***********************************************************************************************************
void testSql()
{
   dyn_dyn_anytype ddaDataSet;
   dpQuery("SELECT '_original.._value' FROM '*' WHERE _DPT = \"_KC_Diag\"", ddaDataSet);
   DebugN(ddaDataSet);
}

/*
//-----------------------------------------------------------------------------------------
// @desc
// @author
// @param
// @param
// @return
// @lastmodified 20-09-2017 v.1.00
//-----------------------------------------------------------------------------------------
// int getErrCnt( string conName, int conID, mapping &diagStruct )
// {
   
   // return 0;
// }
*/
