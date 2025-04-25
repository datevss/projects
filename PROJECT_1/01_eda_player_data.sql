--Разведочный анализ данных

--названия всех таблиц схемы fantasy
SELECT distinct table_name
FROM information_schema.tables
WHERE table_schema = 'fantasy'

--Данные в таблице users
SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    data_type,
    constraint_name
FROM information_schema.columns c
LEFT JOIN information_schema.key_column_usage k USING (table_schema, table_name, column_name)
WHERE c.table_name = 'users' AND c.table_schema = 'fantasy'

--Вывод первых строк таблицы users
SELECT *,
    COUNT(*) OVER() AS row_count
FROM fantasy.users
LIMIT 5;

--Проверка пропусков в таблице users
SELECT COUNT(*) AS row_count
FROM fantasy.users
WHERE class_id IS NULL OR
      ch_id IS NULL OR
      pers_gender IS NULL OR
      server IS NULL OR
      race_id IS NULL OR
      payer IS NULL OR
      loc_id IS NULL;
--Пропусков нет
	  
--Знакомство с категориальными данными таблицы users
SELECT
    server,
    COUNT(*) AS row_count
FROM fantasy.users
GROUP BY server;

--Знакомство с таблицей events
-- Выводим названия полей, их тип данных и метку о ключевом поле таблицы events
SELECT c.table_schema,
       c.table_name,
       c.column_name,
       c.data_type,
       k.constraint_name
FROM information_schema.columns AS c 
-- Присоединяем данные с ограничениями полей
LEFT JOIN information_schema.key_column_usage AS k 
    USING(table_name, column_name, table_schema)
-- Фильтруем результат по названию схемы и таблицы
WHERE table_name = 'events' AND table_schema = 'fantasy'-- Напишите критерии фильтрации данных здесь
ORDER BY c.table_name;

--Выведите первые пять строк таблицы events
SELECT *,
       COUNT(*) OVER() AS row_count
FROM fantasy.events
LIMIT 5;

--Проверка пропусков в таблице events
SELECT COUNT(*) AS row_count
FROM fantasy.events
WHERE date IS NULL OR
      time IS NULL OR
      amount IS NULL OR
      seller_id IS NULL;
--508186 строк с пропусками хотя бы в одном из полей

--Изучаем пропуски в таблице events
-- Считаем количество строк с данными в каждом поле
SELECT 
    COUNT(date) AS data_count,
    COUNT(time) AS data_time,
    COUNT(amount) AS data_amount,
    COUNT(seller_id) AS data_seller_id
FROM fantasy.events
WHERE date IS NULL
  OR time IS NULL
  OR amount IS NULL
  OR seller_id IS NULL;
 --Все 508186 пропусков содержатся только в поле seller_id, 
 --то есть в данных нет информации о продавце.
 
 --Знакомство с таблицей country
-- Выводим названия полей, их тип данных и метку о ключевом поле таблицы country
SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    data_type,
    constraint_name
FROM information_schema.columns c
LEFT JOIN information_schema.key_column_usage k USING (table_schema, table_name, column_name)
WHERE c.table_name = 'country' AND c.table_schema = 'fantasy'; 
--2 column: loc_id, location

--Выводим все страны, в которых зарегистрированы игроки
SELECT 
	DISTINCT location
FROM fantasy.country c; 

SELECT COUNT(*) AS row_count
FROM fantasy.country c 
WHERE location IS NULL;
--0 empty fields

--Знакомство с таблицей classes
-- Выводим названия полей, их тип данных и метку о ключевом поле таблицы classes
SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    data_type,
    constraint_name
FROM information_schema.columns c
LEFT JOIN information_schema.key_column_usage k USING (table_schema, table_name, column_name)
WHERE c.table_name = 'classes' AND c.table_schema = 'fantasy'; 
--2 поля: class_id, class

--Выводим существующие в игре классах игрового персонажа
SELECT DISTINCT class
FROM fantasy.classes c ;
--всего 13 классов

SELECT COUNT(*) AS row_count
FROM fantasy.classes c 
WHERE class IS NULL;
--0 пропусков

--Знакомство с таблицей race
-- Выводим названия полей, их тип данных и метку о ключевом поле таблицы race
SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    data_type,
    constraint_name
FROM information_schema.columns c
LEFT JOIN information_schema.key_column_usage k USING (table_schema, table_name, column_name)
WHERE c.table_name = 'race' AND c.table_schema = 'fantasy'; 
--2 column: race_id, race

SELECT DISTINCT race
FROM fantasy.race r ;
--Для игрока доступно 7 рас

SELECT COUNT(*) AS row_count
FROM fantasy.race r 
WHERE race IS NULL;
--0 empty fields

--Знакомство с таблицей skills
-- Выводим названия полей, их тип данных и метку о ключевом поле таблицы skills
SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    data_type,
    constraint_name
FROM information_schema.columns c
LEFT JOIN information_schema.key_column_usage k USING (table_schema, table_name, column_name)
WHERE c.table_name = 'skills' AND c.table_schema = 'fantasy'; 
--2 column: ch_id, legendary_skill

SELECT 
	COUNT( DISTINCT legendary_skill) AS count_skill
FROM fantasy.skills s ;
--167 skills

SELECT 
	DISTINCT legendary_skill
FROM fantasy.skills s 
ORDER BY 1;

SELECT COUNT(*) AS row_count
FROM fantasy.skills c 
WHERE legendary_skill IS NULL;
--0 empty fields

--Знакомство с таблицей items
-- Выводим названия полей, их тип данных и метку о ключевом поле таблицы items
SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    data_type,
    constraint_name
FROM information_schema.columns c
LEFT JOIN information_schema.key_column_usage k USING (table_schema, table_name, column_name)
WHERE c.table_name = 'items' AND c.table_schema = 'fantasy'; 
--2 columns: item_code (pk), game_items

SELECT DISTINCT game_items
FROM fantasy.items i ;

SELECT COUNT(DISTINCT game_items) AS count_items
FROM fantasy.items i ;
-182 предмета

SELECT COUNT(*) AS row_count
FROM fantasy.items i 
WHERE game_items IS NULL;
--0 empty fields