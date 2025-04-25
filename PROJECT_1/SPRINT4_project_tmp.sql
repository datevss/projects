/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 *
 * Автор: Шагитова Камила
 * Дата: 03.12.2024
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT 
	COUNT(id) AS total_users, --общее кол-во игроков
	SUM(payer) AS count_payer_user, --кол-во платящих игроков
	ROUND(SUM(payer)::numeric/COUNT(id),4) AS part_of_payer_users --доля платящих игроков от общего числа users
FROM fantasy.users u ;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT 
	r.race,	
	SUM(u.payer) AS count_payer_user, --кол-во платящих игроков
	COUNT(u.id) AS total_users,--общее кол-во игроков
	ROUND(SUM(u.payer)::numeric/COUNT(u.id) ,4) AS part_of_payer_users --доля платящих игроков от общего кол-ва польз-й, 
	--зарегистрированных в игре в разрезе каждой расы персонажа
FROM fantasy.users u 
LEFT JOIN fantasy.race r USING (race_id)
GROUP BY r.race 
ORDER BY part_of_payer_users DESC;


-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT 
	COUNT(amount) AS total_events, --общее количество покупок
	SUM(amount) AS total_amount, --суммарная стоимость всех покупок
	MIN(amount) AS min_amount, --мин стоимость покупки
	MAX(amount) AS max_amount, --макс стоимость покупки
	AVG(amount) AS avg_amount, --ср знач стоимости покупки
	percentile_cont(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount, --медиана стоимости покупки
	STDDEV(amount) AS sttdev_amount -- станд откл стоимости покупки
FROM fantasy.events e ;

-- 2.2: Аномальные нулевые покупки:
SELECT
	COUNT(amount) FILTER (WHERE amount=0) AS null_amount, --кол-во покупок с нулевой стоимостью
	COUNT(amount) FILTER (WHERE amount=0)/COUNT(amount)::NUMERIC AS part_of_null_amount --доля нулевых покупок от общего числа покупок
FROM fantasy.events e ;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
WITH event_stats AS (
	SELECT 
		id,
		COUNT(transaction_id) AS count_transact,
		SUM(amount) AS sum_amount
	FROM fantasy.events e 
	WHERE e.amount > 0
	GROUP BY id)
SELECT
	CASE 
		WHEN payer = 1 THEN 'payers'
		WHEN payer = 0 THEN 'non-payers'
	END AS payer,
	COUNT(id) AS total_users, --общее кол-во игроков
	AVG(count_transact) AS avg_count_events, -- среднее кол-во покупок на 1 игрока
	AVG(sum_amount) AS avg_sum_amount -- сред суммарная стоимость покупок на 1 игрока
FROM event_stats
JOIN fantasy.users u USING (id)
GROUP BY payer;


-- 2.4: Популярные эпические предметы:
SELECT 
	game_items,
	COUNT(transaction_id) AS total_sell, --общее кол-во продаж в абсолютном значении
	COUNT(transaction_id)::numeric/(SELECT COUNT(transaction_id) FROM fantasy.events e ) AS relative_sell, --общее кол-во продаж в относительном зн-ии
	COUNT(DISTINCT id)::numeric/(SELECT COUNT(DISTINCT id) FROM fantasy.events e2)  AS user_events --доля игроков, которые хотя бы раз покупали этот предмет
FROM fantasy.items i 
LEFT JOIN fantasy.events e USING (item_code)
WHERE e.amount > 0
GROUP BY game_items
ORDER BY total_sell DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH total_user AS (
	SELECT 
		race_id,
		race,
		COUNT(DISTINCT u.id) AS total_users--общее количество зарегистрированных игроков	
	FROM fantasy.race r 
	JOIN fantasy.users u USING (race_id)
	GROUP BY r.race, race_id),
ingame_payers_stats AS (
	SELECT 
		race,
		total_users,
		COUNT(DISTINCT e.id) AS ingame_payer, --количество игроков, которые совершают внутриигровые покупки	
		ROUND(COUNT(DISTINCT e.id)::NUMERIC/total_users,4) AS part_of_ingame_payer,-- доля игроков, которые совершают внутриигровые покупки от общего числа
		ROUND(COUNT(DISTINCT e.id) FILTER (WHERE payer = 1)/COUNT(DISTINCT e.id)::numeric,4) AS part_of_buyer --доля платящих игроков от количества игроков, которые совершили покупки
	FROM total_user r 
	JOIN fantasy.users u USING (race_id)
	JOIN fantasy.events e USING (id)
	WHERE e.amount>0
	GROUP BY race_id, race, total_users),
transaction_stat AS (
	SELECT 
		race,
		ROUND(COUNT(transaction_id)::NUMERIC/COUNT(DISTINCT e.id),2) AS avg_transact_per_user, --среднее количество покупок на одного игрока
		ROUND(AVG(amount)::numeric,2) AS avg_amount, --средняя стоимость одной покупки на одного игрока
		ROUND(SUM(amount)::numeric/COUNT(DISTINCT e.id),2) AS avg_sum_amount --средняя суммарная стоимость всех покупок на одного игрока
	FROM fantasy.race r
	JOIN fantasy.users u USING (race_id)
	JOIN fantasy.events e USING (id)
	WHERE e.amount>0
	GROUP BY race)
SELECT
	race,
	total_users,
	ingame_payer,
	part_of_ingame_payer,
	part_of_buyer,
	avg_transact_per_user,
	avg_amount,
	avg_sum_amount
FROM ingame_payers_stats
JOIN transaction_stat USING (race)
ORDER BY race;


-- Задача 2: Частота покупок
WITH date_difference AS (
SELECT 
	transaction_id,
	id,
	date,
	(date::date-LAG(date) OVER(PARTITION BY id ORDER BY date)::date) AS transact_interval --кол-во дней между покупками
FROM fantasy.events e 
WHERE amount>0 ),
player_stats AS (
	SELECT
		dd.id,
		COUNT(transaction_id) AS total_purchase, --общее кол-во покупок
		AVG(transact_interval) AS avg_purch_interval, -- среднее кол-во дней между покупками
		payer
	FROM date_difference dd
	JOIN fantasy.users USING (id)
	GROUP BY dd.id, payer
	HAVING COUNT(transaction_id)>=25
	ORDER BY total_purchase DESC),
purchase_freq_group AS (
	SELECT 
		id,
		total_purchase,
		avg_purch_interval,
		payer,
		NTILE(3) OVER(ORDER BY avg_purch_interval) AS freq_group --3 groups
	FROM player_stats)
SELECT
	CASE
		WHEN freq_group = 1 THEN 'высокая частота'
		WHEN freq_group = 2 THEN 'умеренная частота'
		WHEN freq_group = 3 THEN 'низкая частота'
	END AS freq_group,
	COUNT(id) AS total_users, --количество игроков, которые совершили покупки
	SUM(payer) AS payer_users, --количество платящих игроков, совершивших покупки
	SUM(payer)::NUMERIC/COUNT(id) AS part_of_payer_users, -- их доля от общего количества игроков, совершивших покупку
	AVG(total_purchase) AS avg_tot_purchase, --среднее количество покупок на одного игрока
	AVG(avg_purch_interval) AS avg_day_diff --среднее количество дней между покупками на одного игрока
FROM purchase_freq_group
GROUP BY freq_group;