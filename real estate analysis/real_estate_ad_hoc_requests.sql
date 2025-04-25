/* Проект: анализ данных для агентства недвижимости
 * 
 * 
 * Автор: Шагитова Камила
 * Дата: 24.12.2024
*/

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдем id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits) 
        AND rooms < (SELECT rooms_limit FROM limits) 
        AND balcony < (SELECT balcony_limit FROM limits) 
        AND ceiling_height < (SELECT ceiling_height_limit_h FROM limits) 
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
    )
-- Выведем объявления без выбросов:
SELECT *
FROM real_estate.flats
WHERE id IN (SELECT * FROM filtered_id);


-- Часть 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--Разделяем объявления на категории по количеству дней активности и по региону
category AS (
SELECT 
	CASE 
		WHEN city ='Санкт-Петербург' THEN 'Санкт-Петербург'
		ELSE 'ЛенОбл'
	END AS region,
	CASE 
		WHEN days_exposition >=1 AND days_exposition <=30 THEN 'до 1 месяца'
		WHEN days_exposition >=31 AND days_exposition <=90 THEN 'до 3 месяцев'
		WHEN days_exposition >=91 AND days_exposition <=180 THEN 'до полугода'
		WHEN days_exposition >=181 THEN 'от полугода'
	END AS activity_segment,
	a.id,
	last_price/total_area::NUMERIC AS price_per_metre, --цена за кв. метр
	total_area,
	rooms,
	balcony,
	floor,
	is_apartment
FROM real_estate.city c 
JOIN real_estate.flats f USING (city_id)
JOIN real_estate.advertisement a USING (id)
JOIN real_estate."type" t USING (type_id)
WHERE f.id IN (SELECT * FROM filtered_id) AND days_exposition IS NOT NULL AND t.TYPE ='город' )
--итоговый запрос с расчетом необходимых параметров
SELECT 
	region,
	activity_segment,
	COUNT(id) AS count_advert, --кол-во объявлений по сегментам
	ROUND(COUNT(id)/(SELECT count(id) FROM real_estate.advertisement a )::NUMERIC,4) AS part_of_all_advert, -- доля объявлений по сегментам
	ROUND(AVG(price_per_metre)::NUMERIC,2) AS avg_price_per_metre, --средняя цена за метр
	ROUND(AVG(total_area)::NUMERIC,2) AS avg_area, --средняя площадь кв
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms, --медиана кол-ва комнат
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony, --медиана кол-ва балконов
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor, --медиана этажности
	ROUND(SUM(is_apartment)/count(is_apartment)::NUMERIC,4) AS part_of_apartment --доля апартаментов от общего числа объявлений
FROM category
GROUP BY region, activity_segment
ORDER BY 1 DESC, 2;



-- Часть 2: Сезонность объявлений
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
--опубликованные объявления по месяцам
public_advert AS (
	SELECT 
		EXTRACT(MONTH FROM first_day_exposition) AS month_ad, ----месяц публикации
		COUNT(id) AS count_of_public_advert, ---- кол-во объявлений
		AVG(last_price/total_area)::numeric AS avg_price_per_metre, --средняя цена за метр
		AVG(total_area) AS avg_area --средняя площадь кв
	FROM real_estate.advertisement a 
	JOIN real_estate.flats f USING (id)
	JOIN real_estate."type" t USING (type_id)
	WHERE id IN (SELECT * FROM filtered_id) AND days_exposition IS NOT NULL 
		AND EXTRACT(YEAR FROM a.first_day_exposition) BETWEEN 2015 AND 2018 
		AND t.TYPE='город'
	GROUP BY 1
	ORDER BY 1),
--снятые объявления по месяцам
removed_advert AS (
	SELECT 
		EXTRACT(MONTH FROM (first_day_exposition + INTERVAL '1 day' * days_exposition)) AS month_ad, --месяц снятия с публикации
		COUNT(id) AS count_removed_advert, -- кол-во снятых объявлений
		AVG(last_price/total_area)::numeric AS avg_price_per_metre_removed, --средняя цена за метр
		AVG(total_area) AS avg_area_removed --средняя площадь кв
	FROM real_estate.advertisement a 
	JOIN real_estate.flats f USING (id)
	JOIN real_estate."type" t USING (type_id)
	WHERE id IN (SELECT * FROM filtered_id) AND days_exposition IS NOT NULL 
		AND EXTRACT(YEAR FROM (first_day_exposition + INTERVAL '1 day' * days_exposition)) BETWEEN 2015 AND 2018 
		AND t.TYPE='город'
	GROUP BY 1
	ORDER BY 1)
--Итоговый запрос
SELECT 
	p.month_ad,
	count_of_public_advert,
	count_removed_advert,
	RANK() OVER(ORDER BY count_of_public_advert DESC) AS rank_public, -- ранжирование месяцев по колву выложенных объявлений
	RANK() OVER(ORDER BY count_removed_advert DESC) AS rank_removed, -- ранжирование месяцев по колву снятых объявлений
	avg_price_per_metre,
	avg_area,
	avg_price_per_metre_removed,
	avg_area_removed
FROM public_advert p
JOIN removed_advert r USING (month_ad)
ORDER BY 1;


-- Часть 3: Анализ рынка недвижимости Ленобласти

-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT 
	city,
	COUNT(id) AS total_advert,
	count(id) FILTER (WHERE days_exposition IS NOT NULL) AS removed_advert, --кол-во снятых объявлений
	ROUND(count(id) FILTER (WHERE days_exposition IS NOT NULL)/COUNT(id)::NUMERIC,4) AS percent_of_removed_adv, --их доля от общего числа объявлений
	AVG(last_price/total_area)::numeric AS avg_price_per_metre, --средняя цена за метр
	AVG(total_area) AS avg_area, --средняя площадь кв
	AVG(days_exposition) AS avg_advert_duration, --среднее время продолжительности публикации объявлений (в днях)
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_rooms, --медиана кол-ва комнат
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_balcony, --медиана кол-ва балконов
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor --медиана этажности
FROM real_estate.advertisement a 
JOIN real_estate.flats f USING (id)
JOIN real_estate."type" t USING (type_id)
JOIN real_estate.city USING (city_id)
WHERE id IN (SELECT * FROM filtered_id) AND city <> 'Санкт-Петербург'
GROUP BY city
ORDER BY 2 DESC
LIMIT 15;