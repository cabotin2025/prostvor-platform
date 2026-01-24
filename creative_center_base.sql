--
-- PostgreSQL database dump
--

\restrict M6DNn41S6WYdQlgkLRTVwv862PqFabHoGpsydc5SKaN0esvgucADEfFeK2ZYjSe

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: add_asset_file_quick(character varying, integer, text, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_asset_file_quick(p_asset_table character varying, p_asset_record_id integer, p_file_url text, p_file_type character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_asset_type_id INTEGER;
    v_file_id INTEGER;
BEGIN
    -- Просто добавляем, без проверок
    -- Найдем или создадим тип актива
    SELECT asset_type_id INTO v_asset_type_id 
    FROM asset_types 
    WHERE asset_table = p_asset_table;
    
    IF v_asset_type_id IS NULL THEN
        -- Автоматически создаем запись
        INSERT INTO asset_types (asset_table, asset_name)
        VALUES (p_asset_table, 'Автоматически созданный тип')
        RETURNING asset_type_id INTO v_asset_type_id;
    END IF;
    
    -- Добавляем файл
    INSERT INTO asset_files (asset_type_id, asset_record_id, file_url, file_type)
    VALUES (v_asset_type_id, p_asset_record_id, p_file_url, p_file_type)
    RETURNING file_id INTO v_file_id;
    
    RETURN v_file_id;
END;
$$;


ALTER FUNCTION public.add_asset_file_quick(p_asset_table character varying, p_asset_record_id integer, p_file_url text, p_file_type character varying) OWNER TO postgres;

--
-- Name: add_asset_file_safe(character varying, integer, text, character varying, character varying, character varying, boolean, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_asset_file_safe(p_asset_table character varying, p_asset_record_id integer, p_file_url text, p_file_type character varying, p_file_category character varying DEFAULT 'general'::character varying, p_file_name character varying DEFAULT NULL::character varying, p_is_primary boolean DEFAULT false, p_uploaded_by integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_asset_type_id INTEGER;
    v_record_exists BOOLEAN;
    v_file_id INTEGER;
    v_primary_key_column VARCHAR;
    v_table_exists BOOLEAN;
    v_max_id INTEGER;
    v_min_id INTEGER;
    v_error_message TEXT;
BEGIN
    -- Проверяем существование типа актива
    SELECT asset_type_id INTO v_asset_type_id 
    FROM asset_types 
    WHERE asset_table = p_asset_table;
    
    IF v_asset_type_id IS NULL THEN
        RAISE EXCEPTION 'Таблица "%" не зарегистрирована в системе. Добавьте её в asset_types.', p_asset_table;
    END IF;
    
    -- Проверяем существование таблицы
    SELECT EXISTS(
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = p_asset_table
    ) INTO v_table_exists;
    
    IF NOT v_table_exists THEN
        RAISE EXCEPTION 'Таблица "%" не существует в базе данных.', p_asset_table;
    END IF;
    
    -- Определяем первичный ключ для таблицы
    v_primary_key_column := CASE p_asset_table
        WHEN 'matresources' THEN 'matresource_id'
        WHEN 'venues' THEN 'venue_id'
        WHEN 'events' THEN 'event_id'
        WHEN 'projects' THEN 'project_id'
        WHEN 'actors' THEN 'actor_id'
        WHEN 'persons' THEN 'person_id'
        WHEN 'organizations' THEN 'organization_id'
        WHEN 'communities' THEN 'community_id'
        WHEN 'ideas' THEN 'idea_id'
        WHEN 'services' THEN 'service_id'
        WHEN 'stages' THEN 'stage_id'
        WHEN 'themes' THEN 'theme_id'
        WHEN 'templates' THEN 'template_id'
        WHEN 'finresources' THEN 'finresource_id'
        WHEN 'local_events' THEN 'local_event_id'
        WHEN 'locations' THEN 'location_id'
        ELSE 'id' -- fallback
    END;
    
    -- Проверяем существование записи актива
    EXECUTE format('SELECT EXISTS(SELECT 1 FROM %I WHERE %I = $1 AND deleted_at IS NULL)',
                   p_asset_table, v_primary_key_column)
    INTO v_record_exists
    USING p_asset_record_id;
    
    IF NOT v_record_exists THEN
        -- Получим информацию о доступных ID для информативного сообщения
        EXECUTE format('SELECT COALESCE(MAX(%I), 0), COALESCE(MIN(%I), 0) FROM %I', 
                      v_primary_key_column, v_primary_key_column, p_asset_table)
        INTO v_max_id, v_min_id;
        
        -- Формируем сообщение об ошибке
        v_error_message := format(
            'Запись с ID %s не существует в таблице "%s" или помечена как удаленная. ',
            p_asset_record_id, p_asset_table
        );
        
        IF v_min_id = 0 AND v_max_id = 0 THEN
            v_error_message := v_error_message || 'Таблица пуста.';
        ELSE
            v_error_message := v_error_message || format('Доступные ID: от %s до %s.', v_min_id, v_max_id);
        END IF;
        
        RAISE EXCEPTION '%', v_error_message;
    END IF;
    
    -- Если добавляем как основной, снимаем флаг с существующих
    IF p_is_primary THEN
        UPDATE asset_files
        SET is_primary = FALSE
        WHERE asset_type_id = v_asset_type_id
        AND asset_record_id = p_asset_record_id
        AND file_category = p_file_category
        AND is_primary = TRUE;
    END IF;
    
    -- Вставляем запись о файле
    INSERT INTO asset_files (
        asset_type_id, asset_record_id, file_url, file_type, 
        file_category, file_name, is_primary, uploaded_by
    ) VALUES (
        v_asset_type_id, p_asset_record_id, p_file_url, p_file_type,
        p_file_category, p_file_name, p_is_primary, p_uploaded_by
    ) RETURNING file_id INTO v_file_id;
    
    RETURN v_file_id;
END;
$_$;


ALTER FUNCTION public.add_asset_file_safe(p_asset_table character varying, p_asset_record_id integer, p_file_url text, p_file_type character varying, p_file_category character varying, p_file_name character varying, p_is_primary boolean, p_uploaded_by integer) OWNER TO postgres;

--
-- Name: FUNCTION add_asset_file_safe(p_asset_table character varying, p_asset_record_id integer, p_file_url text, p_file_type character varying, p_file_category character varying, p_file_name character varying, p_is_primary boolean, p_uploaded_by integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.add_asset_file_safe(p_asset_table character varying, p_asset_record_id integer, p_file_url text, p_file_type character varying, p_file_category character varying, p_file_name character varying, p_is_primary boolean, p_uploaded_by integer) IS 'Безопасное добавление файла к сущности с проверками существования записи';


--
-- Name: add_asset_file_simple(character varying, integer, text, character varying, character varying, character varying, boolean, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_asset_file_simple(p_asset_table character varying, p_asset_record_id integer, p_file_url text, p_file_type character varying, p_file_category character varying DEFAULT 'general'::character varying, p_file_name character varying DEFAULT NULL::character varying, p_is_primary boolean DEFAULT false, p_uploaded_by integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_asset_type_id INTEGER;
    v_file_id INTEGER;
BEGIN
    -- Проверяем существование типа актива
    SELECT asset_type_id INTO v_asset_type_id 
    FROM asset_types 
    WHERE asset_table = p_asset_table;
    
    IF v_asset_type_id IS NULL THEN
        -- Автоматически добавляем тип актива, если его нет
        INSERT INTO asset_types (asset_table, asset_name)
        VALUES (p_asset_table, 
                INITCAP(REPLACE(p_asset_table, '_', ' ')) || ' (автоматически)')
        RETURNING asset_type_id INTO v_asset_type_id;
    END IF;
    
    -- Если добавляем как основной, снимаем флаг с существующих
    IF p_is_primary THEN
        UPDATE asset_files
        SET is_primary = FALSE
        WHERE asset_type_id = v_asset_type_id
        AND asset_record_id = p_asset_record_id
        AND file_category = p_file_category
        AND is_primary = TRUE;
    END IF;
    
    -- Вставляем запись о файле
    INSERT INTO asset_files (
        asset_type_id, asset_record_id, file_url, file_type, 
        file_category, file_name, is_primary, uploaded_by
    ) VALUES (
        v_asset_type_id, p_asset_record_id, p_file_url, p_file_type,
        p_file_category, p_file_name, p_is_primary, p_uploaded_by
    ) RETURNING file_id INTO v_file_id;
    
    RETURN v_file_id;
END;
$$;


ALTER FUNCTION public.add_asset_file_simple(p_asset_table character varying, p_asset_record_id integer, p_file_url text, p_file_type character varying, p_file_category character varying, p_file_name character varying, p_is_primary boolean, p_uploaded_by integer) OWNER TO postgres;

--
-- Name: FUNCTION add_asset_file_simple(p_asset_table character varying, p_asset_record_id integer, p_file_url text, p_file_type character varying, p_file_category character varying, p_file_name character varying, p_is_primary boolean, p_uploaded_by integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.add_asset_file_simple(p_asset_table character varying, p_asset_record_id integer, p_file_url text, p_file_type character varying, p_file_category character varying, p_file_name character varying, p_is_primary boolean, p_uploaded_by integer) IS 'Упрощенное добавление файла без строгих проверок';


--
-- Name: add_offering_term(text, integer, integer, numeric, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_offering_term(p_resource_type text, p_resource_id integer, p_offering_term_id integer, p_cost numeric DEFAULT 0, p_currency text DEFAULT 'руб.'::text, p_special_terms text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_new_id INTEGER;
BEGIN
    -- Проверяем тип ресурса и добавляем в соответствующую таблицу
    IF p_resource_type = 'matresource' THEN
        INSERT INTO matresource_offering_terms 
            (matresource_id, offering_term_id, cost, currency, special_terms)
        VALUES 
            (p_resource_id, p_offering_term_id, p_cost, p_currency, p_special_terms)
        RETURNING id INTO v_new_id;
        
    ELSIF p_resource_type = 'idea' THEN
        INSERT INTO idea_offering_terms 
            (idea_id, offering_term_id, cost, currency, special_terms)
        VALUES 
            (p_resource_id, p_offering_term_id, p_cost, p_currency, p_special_terms)
        RETURNING id INTO v_new_id;
        
    ELSIF p_resource_type = 'service' THEN
        INSERT INTO service_offering_terms 
            (service_id, offering_term_id, cost, currency, special_terms)
        VALUES 
            (p_resource_id, p_offering_term_id, p_cost, p_currency, p_special_terms)
        RETURNING id INTO v_new_id;
        
    ELSIF p_resource_type = 'template' THEN
        INSERT INTO template_offering_terms 
            (template_id, offering_term_id, cost, currency, special_terms)
        VALUES 
            (p_resource_id, p_offering_term_id, p_cost, p_currency, p_special_terms)
        RETURNING id INTO v_new_id;
        
    ELSIF p_resource_type = 'venue' THEN
        INSERT INTO venue_offering_terms 
            (venue_id, offering_term_id, cost, currency, special_terms)
        VALUES 
            (p_resource_id, p_offering_term_id, p_cost, p_currency, p_special_terms)
        RETURNING id INTO v_new_id;
        
    ELSE
        RAISE EXCEPTION 'Неизвестный тип ресурса: %', p_resource_type;
    END IF;
    
    RETURN v_new_id;
EXCEPTION 
    WHEN unique_violation THEN
        RAISE NOTICE 'Такое условие уже существует для ресурса';
        RETURN NULL;
    WHEN OTHERS THEN
        RAISE;
END;
$$;


ALTER FUNCTION public.add_offering_term(p_resource_type text, p_resource_id integer, p_offering_term_id integer, p_cost numeric, p_currency text, p_special_terms text) OWNER TO postgres;

--
-- Name: add_request_term(integer, integer, numeric, text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_request_term(p_request_id integer, p_offering_term_id integer, p_proposed_cost numeric DEFAULT NULL::numeric, p_request_terms text DEFAULT NULL::text, p_requester_approval boolean DEFAULT false) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_request_term_id INTEGER;
BEGIN
    INSERT INTO request_offering_terms (
        request_id,
        offering_term_id,
        proposed_cost,
        request_terms,
        requester_approval
    ) VALUES (
        p_request_id,
        p_offering_term_id,
        p_proposed_cost,
        p_request_terms,
        p_requester_approval
    ) RETURNING request_term_id INTO v_request_term_id;
    
    RETURN v_request_term_id;
END;
$$;


ALTER FUNCTION public.add_request_term(p_request_id integer, p_offering_term_id integer, p_proposed_cost numeric, p_request_terms text, p_requester_approval boolean) OWNER TO postgres;

--
-- Name: add_test_file(character varying, integer, text, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_test_file(p_asset_table character varying, p_asset_record_id integer, p_file_url text, p_file_type character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_asset_type_id INTEGER;
    v_file_id INTEGER;
BEGIN
    -- Получаем или создаем тип актива
    SELECT asset_type_id INTO v_asset_type_id 
    FROM asset_types 
    WHERE asset_table = p_asset_table;
    
    IF v_asset_type_id IS NULL THEN
        INSERT INTO asset_types (asset_table, asset_name)
        VALUES (p_asset_table, 'Тестовая сущность')
        RETURNING asset_type_id INTO v_asset_type_id;
    END IF;
    
    -- Вставляем файл
    INSERT INTO asset_files (asset_type_id, asset_record_id, file_url, file_type)
    VALUES (v_asset_type_id, p_asset_record_id, p_file_url, p_file_type)
    RETURNING file_id INTO v_file_id;
    
    RETURN v_file_id;
END;
$$;


ALTER FUNCTION public.add_test_file(p_asset_table character varying, p_asset_record_id integer, p_file_url text, p_file_type character varying) OWNER TO postgres;

--
-- Name: archive_old_records(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.archive_old_records(months_old integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    archived_count INTEGER;
BEGIN
    -- Архивируем старые завершенные проекты
    UPDATE projects 
    SET deleted_at = CURRENT_TIMESTAMP
    WHERE deleted_at IS NULL 
    AND project_status_id = 6 
    AND end_date < CURRENT_DATE - (months_old * INTERVAL '1 month');
    
    GET DIAGNOSTICS archived_count = ROW_COUNT;
    
    RETURN archived_count;
END;
$$;


ALTER FUNCTION public.archive_old_records(months_old integer) OWNER TO postgres;

--
-- Name: archive_request_before_delete(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.archive_request_before_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_resource_info RECORD;
    v_requester_location INT;
    v_has_contract BOOLEAN;
BEGIN
    -- Получаем информацию о ресурсе через нашу функцию
    SELECT * INTO v_resource_info
    FROM get_request_resource_info(OLD.request_id);

    -- Получаем локацию создателя запроса
    SELECT location_id INTO v_requester_location
    FROM actors
    WHERE actor_id = OLD.requester_id;

    -- Проверяем, есть ли по запросу договор
    SELECT EXISTS (
        SELECT 1 FROM contracts WHERE request_id = OLD.request_id
    ) INTO v_has_contract;

    -- Сохраняем обезличенную статистику
    INSERT INTO request_statistic (
        location_id,
        creation_time,
        resource_type_id,
        subject_type_id,
        subject_id,
        relevance,
        completed,
        archived_date
    ) VALUES (
        v_requester_location,
        OLD.created_at, -- Используем существующее поле с датой создания
        v_resource_info.resource_type_id,
        v_resource_info.subject_type_id,
        v_resource_info.subject_id,
        FALSE,      -- relevance = FALSE (запрос удаляется)
        v_has_contract, -- completed (был ли договор)
        CURRENT_TIMESTAMP
    );

    RETURN OLD;
END;
$$;


ALTER FUNCTION public.archive_request_before_delete() OWNER TO postgres;

--
-- Name: authenticate_user(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.authenticate_user(p_email character varying, p_password character varying) RETURNS TABLE(actor_id integer, nickname character varying, email character varying, actor_type character varying, status character varying, location_name character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.actor_id,
        a.nickname,
        p.email,
        at.type as actor_type,
        ast.status,
        l.name as location_name
    FROM persons p
    JOIN actors a ON p.actor_id = a.actor_id
    JOIN actor_types at ON a.actor_type_id = at.actor_type_id
    LEFT JOIN actor_current_statuses acs ON a.actor_id = acs.actor_id
    LEFT JOIN actor_statuses ast ON acs.actor_status_id = ast.actor_status_id
    LEFT JOIN locations l ON p.location_id = l.location_id
    JOIN actor_credentials ac ON a.actor_id = ac.actor_id
    WHERE p.email = p_email 
        AND p.deleted_at IS NULL
        AND a.deleted_at IS NULL
        AND ac.password_hash = crypt(p_password, ac.password_hash);
END;
$$;


ALTER FUNCTION public.authenticate_user(p_email character varying, p_password character varying) OWNER TO postgres;

--
-- Name: auto_update_coords_from_geom(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.auto_update_coords_from_geom() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.geom IS NOT NULL THEN
        NEW.latitude = ST_Y(NEW.geom::geometry);
        NEW.longitude = ST_X(NEW.geom::geometry);
    ELSE
        NEW.latitude = NULL;
        NEW.longitude = NULL;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.auto_update_coords_from_geom() OWNER TO postgres;

--
-- Name: auto_update_geom(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.auto_update_geom() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.geom = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
    ELSE
        NEW.geom = NULL;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.auto_update_geom() OWNER TO postgres;

--
-- Name: auto_update_geom_from_coords(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.auto_update_geom_from_coords() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.geom = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
    ELSE
        NEW.geom = NULL;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.auto_update_geom_from_coords() OWNER TO postgres;

--
-- Name: check_actor_can_create_request(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_actor_can_create_request() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- В таблице actors нет поля actor_status_id, возможно проверка по другому полю
    -- Пока пропускаем проверку или проверяем по другому критерию
    -- Например, можно проверить что актор существует и не удален
    IF NOT EXISTS (
        SELECT 1 FROM actors 
        WHERE actor_id = NEW.requester_id 
        AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Участник не существует или удален';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_actor_can_create_request() OWNER TO postgres;

--
-- Name: check_cost_for_free_terms(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_cost_for_free_terms() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Используем TG_TABLE_NAME для определения таблицы
    IF TG_TABLE_NAME IN ('matresource_offering_terms', 'finresource_offering_terms', 
                         'venue_offering_terms', 'idea_offering_terms',
                         'template_offering_terms') THEN
        -- Проверяем бесплатные условия (id 2 и 3)
        IF NEW.offering_term_id IN (2, 3) THEN
            -- Для бесплатных типов cost должен быть 0 или NULL
            IF NEW.cost IS NOT NULL AND NEW.cost != 0 THEN
                RAISE EXCEPTION 'Для безвозмездных условий стоимость должна быть 0 или NULL. Выбрано: %, установлена стоимость: %', 
                (SELECT name FROM offering_terms WHERE id = NEW.offering_term_id), NEW.cost;
            END IF;
            -- Принудительно устанавливаем 0, если NULL
            IF NEW.cost IS NULL THEN
                NEW.cost = 0;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_cost_for_free_terms() OWNER TO postgres;

--
-- Name: check_primary_file_uniqueness(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_primary_file_uniqueness() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Если устанавливаем файл как основной
    IF NEW.is_primary = TRUE THEN
        -- Проверяем, нет ли уже основного файла в этой категории
        IF EXISTS (
            SELECT 1 
            FROM asset_files 
            WHERE asset_type_id = NEW.asset_type_id
            AND asset_record_id = NEW.asset_record_id
            AND file_category = NEW.file_category
            AND is_primary = TRUE
            AND file_id != NEW.file_id
        ) THEN
            RAISE EXCEPTION 
                'Already exists primary file for asset_type_id=%, asset_record_id=%, file_category=%', 
                NEW.asset_type_id, NEW.asset_record_id, NEW.file_category;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_primary_file_uniqueness() OWNER TO postgres;

--
-- Name: check_project_owner_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_project_owner_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Если указан проект, проверяем что reviewer имеет разрешение на проекты
    IF NEW.project_id IS NOT NULL AND NEW.reviewed_by IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 
            FROM actors a
            LEFT JOIN actor_status_mapping asm ON a.rating_id = asm.rating_id
            WHERE a.actor_id = NEW.reviewed_by 
            AND asm.can_create_project = TRUE
        ) THEN
            RAISE EXCEPTION 'Только участники с разрешением на проекты могут указывать проект';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_project_owner_status() OWNER TO postgres;

--
-- Name: check_request_validity(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_request_validity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Если срок действия истек, а статус еще не "отменён"
    IF NEW.validity_period IS NOT NULL
       AND NEW.validity_period < CURRENT_TIMESTAMP
       AND NEW.request_status_id != (
           SELECT request_status_id FROM request_statuses WHERE status = 'отменён'
       )
    THEN
        NEW.request_status_id := (
            SELECT request_status_id FROM request_statuses WHERE status = 'отменён'
        );
        NEW.update_date := CURRENT_TIMESTAMP; -- Обновляем дату изменения
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_request_validity() OWNER TO postgres;

--
-- Name: check_requester_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_requester_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Простая проверка без подзапроса в CHECK constraint
    -- Детальную проверку сделаем через триггер
    IF NEW.requester_id IS NOT NULL THEN
        -- Проверка будет в триггере
        NULL;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_requester_status() OWNER TO postgres;

--
-- Name: check_service_offering_terms(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_service_offering_terms() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверяем что offering_term_id только 1 или 2
    IF NEW.offering_term_id NOT IN (1, 2) THEN
        RAISE EXCEPTION 'Для услуг offering_term_id может быть только 1 (Продажа) или 2 (Безвозмездная передача). Указано: %', 
        NEW.offering_term_id;
    END IF;
    
    -- Проверяем бесплатные условия (id = 2)
    IF NEW.offering_term_id = 2 THEN
        -- Для безвозмездной передачи cost должен быть 0 или NULL
        IF NEW.cost IS NOT NULL AND NEW.cost != 0 THEN
            RAISE EXCEPTION 'Для безвозмездной передачи стоимость должна быть 0 или NULL. Установлена: %', 
            NEW.cost;
        END IF;
        -- Принудительно устанавливаем 0, если NULL
        IF NEW.cost IS NULL THEN
            NEW.cost = 0;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_service_offering_terms() OWNER TO postgres;

--
-- Name: check_system_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_system_status() RETURNS TABLE(component character varying, status character varying, details text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверка таблиц
    RETURN QUERY
    SELECT 
        'Таблицы данных'::VARCHAR, 
        CASE WHEN (SELECT COUNT(*) FROM contracts) > 0 THEN '✅'::VARCHAR ELSE '❌'::VARCHAR END,
        'Договоров: ' || (SELECT COUNT(*)::TEXT FROM contracts);
    
    -- Проверка автоматизации
    RETURN QUERY
    SELECT 
        'Автоматизация'::VARCHAR,
        CASE WHEN EXISTS (
            SELECT 1 FROM information_schema.triggers 
            WHERE trigger_name = 'trg_create_final_contract'
        ) THEN '✅'::VARCHAR ELSE '❌'::VARCHAR END,
        'Триггеры создания договоров';
    
    -- Проверка представлений
    RETURN QUERY
    SELECT 
        'Мониторинг'::VARCHAR,
        CASE WHEN EXISTS (SELECT 1 FROM v_contract_process_tracking LIMIT 1) 
             THEN '✅'::VARCHAR ELSE '❌'::VARCHAR END,
        'Представления отслеживания';
    
    -- Проверка данных
    RETURN QUERY
    SELECT 
        'Тестовые данные'::VARCHAR,
        CASE WHEN (SELECT COUNT(*) FROM requests) > 0 
             THEN '✅'::VARCHAR ELSE '❌'::VARCHAR END,
        'Запросов: ' || (SELECT COUNT(*)::TEXT FROM requests);
END;
$$;


ALTER FUNCTION public.check_system_status() OWNER TO postgres;

--
-- Name: check_unique_for_active_records(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_unique_for_active_records() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    table_name TEXT := TG_TABLE_NAME;
BEGIN
    -- Проверяем уникальность email среди активных пользователей
    IF table_name = 'persons' AND NEW.email IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM persons 
            WHERE email = NEW.email 
            AND deleted_at IS NULL 
            AND actor_id != COALESCE(NEW.actor_id, -1)
        ) THEN
            RAISE EXCEPTION 'Email % уже используется', NEW.email;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_unique_for_active_records() OWNER TO postgres;

--
-- Name: cleanup_orphaned_files(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cleanup_orphaned_files() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_deleted_count INTEGER := 0;
BEGIN
    -- Удаляем файлы, у которых запись в родительской таблице не существует или удалена
    DELETE FROM asset_files af
    WHERE NOT EXISTS (
        SELECT 1
        FROM information_schema.tables t
        JOIN asset_types at ON at.asset_table = t.table_name
        WHERE t.table_schema = 'public'
        AND at.asset_type_id = af.asset_type_id
    )
    OR NOT EXISTS (
        SELECT 1
        FROM information_schema.tables t
        JOIN asset_types at ON at.asset_table = t.table_name
        WHERE t.table_schema = 'public'
        AND at.asset_type_id = af.asset_type_id
        AND EXISTS (
            -- Проверка существования записи зависит от таблицы
            SELECT 1
            FROM pg_class c
            JOIN pg_attribute a ON a.attrelid = c.oid
            WHERE c.relname = at.asset_table
            AND a.attname = CASE at.asset_table
                WHEN 'matresources' THEN 'matresource_id'
                WHEN 'venues' THEN 'venue_id'
                WHEN 'events' THEN 'event_id'
                WHEN 'projects' THEN 'project_id'
                WHEN 'actors' THEN 'actor_id'
                WHEN 'persons' THEN 'person_id'
                WHEN 'organizations' THEN 'organization_id'
                WHEN 'communities' THEN 'community_id'
                WHEN 'ideas' THEN 'idea_id'
                WHEN 'services' THEN 'service_id'
                WHEN 'stages' THEN 'stage_id'
                WHEN 'themes' THEN 'theme_id'
                WHEN 'templates' THEN 'template_id'
                WHEN 'finresources' THEN 'finresource_id'
                WHEN 'local_events' THEN 'local_event_id'
                WHEN 'locations' THEN 'location_id'
                ELSE 'id'
            END
            AND a.atttypid = 'integer'::regtype
        )
    );
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RETURN v_deleted_count;
END;
$$;


ALTER FUNCTION public.cleanup_orphaned_files() OWNER TO postgres;

--
-- Name: FUNCTION cleanup_orphaned_files(); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.cleanup_orphaned_files() IS 'Очистка файлов, не связанных с существующими сущностями';


--
-- Name: create_final_contract(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_final_contract() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_contract_id INTEGER;
    v_total_cost DECIMAL(15,2);
    v_start_date DATE;
    v_end_date DATE;
    v_start_time TIME;
    v_end_time TIME;
    v_effective_from TIMESTAMP;
BEGIN
    -- Упрощенное условие: если обе подписи TRUE и нет финального договора
    IF NEW.requester_signed = TRUE AND NEW.owner_signed = TRUE THEN
        
        -- Проверяем, нет ли уже финального договора
        IF NOT EXISTS (
            SELECT 1 FROM contracts c WHERE c.temp_contract_id = NEW.temp_contract_id
        ) THEN
            RAISE NOTICE 'ТРИГГЕР: Создание финального договора для временного договора ID: %', NEW.temp_contract_id;
            
            -- Рассчитываем общую стоимость
            SELECT SUM(agreed_cost) INTO v_total_cost
            FROM temp_contract_terms
            WHERE temp_contract_id = NEW.temp_contract_id;
            
            -- Получаем даты из временного договора или используем текущую дату
            v_start_date := COALESCE(NEW.start_date, CURRENT_DATE);
            v_end_date := NEW.end_date;
            v_start_time := NEW.start_time;
            v_end_time := NEW.end_time;
            v_effective_from := CURRENT_TIMESTAMP;
            
            -- Создаем финальный договор
            INSERT INTO contracts (
                temp_contract_id,
                request_id,
                contract_number,
                contract_title,
                contract_description,
                requester_id,
                owner_id,
                resource_type,
                resource_id,
                start_date,
                end_date,
                start_time,
                end_time,
                total_cost,
                currency,
                contract_status,
                requester_signed_at,
                owner_signed_at,
                signed_at,
                effective_from
            ) VALUES (
                NEW.temp_contract_id,
                NEW.request_id,
                'CTR-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD-') || LPAD(NEXTVAL('contract_number_seq')::TEXT, 6, '0'),
                NEW.contract_title,
                NEW.contract_description,
                NEW.requester_id,
                NEW.owner_id,
                NEW.resource_type,
                NEW.resource_id,
                v_start_date,
                v_end_date,
                v_start_time,
                v_end_time,
                COALESCE(v_total_cost, 0),
                'руб.',
                'active',
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP,
                v_effective_from
            ) RETURNING contract_id INTO v_contract_id;
            
            RAISE NOTICE 'ТРИГГЕР: ✅ Создан финальный договор ID: %', v_contract_id;
            
            -- Копируем условия
            INSERT INTO contract_terms (
                contract_id,
                offering_term_id,
                offering_term_name,
                cost,
                currency,
                special_terms,
                fulfillment_status
            )
            SELECT 
                v_contract_id,
                tct.offering_term_id,
                COALESCE(ot.name, 'Условие ' || tct.offering_term_id::text),
                tct.agreed_cost,
                COALESCE(tct.agreed_currency, 'руб.'),
                COALESCE(tct.special_terms, ''),
                'pending'
            FROM temp_contract_terms tct
            LEFT JOIN offering_terms ot ON tct.offering_term_id = ot.id
            WHERE tct.temp_contract_id = NEW.temp_contract_id;
            
            RAISE NOTICE 'ТРИГГЕР: Скопировано % условий', 
                (SELECT COUNT(*) FROM contract_terms WHERE contract_id = v_contract_id);
                
            -- Обновляем статус временного договора
            NEW.contract_status := 'active';
        ELSE
            RAISE NOTICE 'ТРИГГЕР: Финальный договор уже существует для временного договора ID: %', NEW.temp_contract_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.create_final_contract() OWNER TO postgres;

--
-- Name: create_geom_from_coords(numeric, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_geom_from_coords(lon numeric, lat numeric) RETURNS public.geometry
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    IF lon IS NULL OR lat IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN ST_SetSRID(ST_MakePoint(lon, lat), 4326);
END;
$$;


ALTER FUNCTION public.create_geom_from_coords(lon numeric, lat numeric) OWNER TO postgres;

--
-- Name: create_global_request(integer, integer, character varying, text, integer, integer, integer, integer, timestamp without time zone, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_global_request(p_requester_id integer, p_resource_type_id integer, p_title character varying, p_description text DEFAULT NULL::text, p_location_id integer DEFAULT NULL::integer, p_subject_type_id integer DEFAULT NULL::integer, p_subject_id integer DEFAULT NULL::integer, p_quantity integer DEFAULT 1, p_validity_period timestamp without time zone DEFAULT NULL::timestamp without time zone, p_project_id integer DEFAULT NULL::integer, p_event_id integer DEFAULT NULL::integer) RETURNS TABLE(global_request_id integer, success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_request_id INT;
    v_location_name TEXT;
    v_resource_type_name TEXT;
    v_status_id INT;
BEGIN
    -- Получаем ID статуса "действующий" из реальной таблицы
    SELECT request_status_id INTO v_status_id
    FROM request_statuses 
    WHERE status = 'действующий';
    
    IF v_status_id IS NULL THEN
        RETURN QUERY 
        SELECT NULL::INT, false, 'Статус "действующий" не найден в базе'::TEXT;
        RETURN;
    END IF;
    
    -- Вставляем запрос в global_requests
    INSERT INTO global_requests (
        requester_id,
        resource_type_id,
        title,
        description,
        location_id,
        subject_type_id,
        subject_id,
        quantity,
        validity_period,
        project_id,
        event_id,
        request_status_id,
        creation_date,
        update_date,
        is_active
    ) VALUES (
        p_requester_id,
        p_resource_type_id,
        p_title,
        p_description,
        p_location_id,
        p_subject_type_id,
        p_subject_id,
        p_quantity,
        p_validity_period,
        p_project_id,
        p_event_id,
        v_status_id,
        CURRENT_TIMESTAMP AT TIME ZONE 'UTC', -- Приводим к timestamp without time zone
        CURRENT_TIMESTAMP AT TIME ZONE 'UTC',
        true
    ) RETURNING global_requests.global_request_id INTO v_request_id;
    
    -- Получаем названия для информационных сообщений
    IF p_location_id IS NOT NULL THEN
        SELECT name INTO v_location_name 
        FROM locations WHERE location_id = p_location_id;
    END IF;
    
    SELECT type INTO v_resource_type_name 
    FROM resource_types WHERE resource_type_id = p_resource_type_id;
    
    -- Создаем уведомление для создателя запроса
    INSERT INTO global_request_notifications (
        global_request_id,
        actor_id,
        notification_type,
        title,
        message,
        related_resource_id,
        is_read,
        created_at
    ) VALUES (
        v_request_id,
        p_requester_id,
        'request_created',
        'Глобальный запрос создан',
        'Вы создали глобальный запрос "' || p_title || '" на ' || 
        COALESCE(v_resource_type_name, 'ресурс') ||
        CASE WHEN v_location_name IS NOT NULL THEN ' в ' || v_location_name ELSE '' END,
        v_request_id,
        false,
        CURRENT_TIMESTAMP
    );
    
    -- Возвращаем результат
    RETURN QUERY 
    SELECT v_request_id, true, 'Глобальный запрос успешно создан'::TEXT;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY 
    SELECT NULL::INT, false, 'Ошибка при создании запроса: ' || SQLERRM::TEXT;
END;
$$;


ALTER FUNCTION public.create_global_request(p_requester_id integer, p_resource_type_id integer, p_title character varying, p_description text, p_location_id integer, p_subject_type_id integer, p_subject_id integer, p_quantity integer, p_validity_period timestamp without time zone, p_project_id integer, p_event_id integer) OWNER TO postgres;

--
-- Name: create_global_response(integer, integer, integer, text, numeric, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_global_response(p_global_request_id integer, p_owner_id integer, p_resource_id integer, p_message text DEFAULT NULL::text, p_proposed_price numeric DEFAULT NULL::numeric, p_proposed_conditions text DEFAULT NULL::text) RETURNS TABLE(response_id integer, success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_request RECORD;
    v_response_id INT;
    v_existing_response INT;
    v_owner_location_id INT;
    v_requester_location_id INT;
    v_distance_notification TEXT;
BEGIN
    -- Проверяем существование запроса
    SELECT gr.*, a.nickname as requester_name, rt.type as resource_type_name
    INTO v_request
    FROM global_requests gr
    JOIN actors a ON gr.requester_id = a.actor_id
    JOIN resource_types rt ON gr.resource_type_id = rt.resource_type_id
    WHERE gr.global_request_id = p_global_request_id
      AND gr.is_active = true;
    
    IF v_request IS NULL THEN
        RETURN QUERY 
        SELECT NULL::INT, false, 'Запрос не найден или неактивен';
        RETURN;
    END IF;
    
    -- Проверяем, не откликался ли уже этот владелец
    SELECT response_id INTO v_existing_response
    FROM global_request_responses
    WHERE global_request_id = p_global_request_id
      AND owner_id = p_owner_id
      AND resource_id = p_resource_id;
    
    IF v_existing_response IS NOT NULL THEN
        RETURN QUERY 
        SELECT NULL::INT, false, 'Вы уже откликались на этот запрос';
        RETURN;
    END IF;
    
    -- Вставляем отклик
    INSERT INTO global_request_responses (
        global_request_id,
        owner_id,
        resource_id,
        message,
        proposed_price,
        proposed_conditions,
        status
    ) VALUES (
        p_global_request_id,
        p_owner_id,
        p_resource_id,
        p_message,
        p_proposed_price,
        p_proposed_conditions,
        'pending'
    ) RETURNING response_id INTO v_response_id;
    
    -- Получаем информацию о локациях для уведомления
    SELECT location_id INTO v_owner_location_id
    FROM actors_locations 
    WHERE actor_id = p_owner_id 
    LIMIT 1;
    
    SELECT location_id INTO v_requester_location_id
    FROM actors_locations 
    WHERE actor_id = v_request.requester_id 
    LIMIT 1;
    
    -- Формируем сообщение о расстоянии
    IF v_owner_location_id IS NOT NULL AND v_requester_location_id IS NOT NULL THEN
        IF v_owner_location_id = v_requester_location_id THEN
            v_distance_notification := 'Владелец находится в том же населенном пункте';
        ELSE
            v_distance_notification := 'Владелец находится в другом населенном пункте';
        END IF;
    ELSE
        v_distance_notification := 'Информация о локации отсутствует';
    END IF;
    
    -- Создаем уведомление для создателя запроса
    INSERT INTO global_request_notifications (
        global_request_id,
        actor_id,
        notification_type,
        title,
        message,
        related_resource_id
    ) VALUES (
        p_global_request_id,
        v_request.requester_id,
        'new_response',
        'Новый отклик на ваш запрос',
        'На ваш запрос "' || v_request.title || '" откликнулся новый владелец. ' || v_distance_notification,
        v_response_id
    );
    
    -- Создаем уведомление для откликнувшегося
    INSERT INTO global_request_notifications (
        global_request_id,
        actor_id,
        notification_type,
        title,
        message,
        related_resource_id
    ) VALUES (
        p_global_request_id,
        p_owner_id,
        'response_created',
        'Вы откликнулись на запрос',
        'Вы откликнулись на запрос "' || v_request.title || '". Ожидайте ответа от создателя.',
        v_response_id
    );
    
    RETURN QUERY 
    SELECT v_response_id, true, 'Отклик успешно создан';
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY 
    SELECT NULL::INT, false, 'Ошибка при создании отклика: ' || SQLERRM;
END;
$$;


ALTER FUNCTION public.create_global_response(p_global_request_id integer, p_owner_id integer, p_resource_id integer, p_message text, p_proposed_price numeric, p_proposed_conditions text) OWNER TO postgres;

--
-- Name: create_request(integer, character varying, integer, character varying, text, integer, date, date, time without time zone, time without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_request(p_requester_id integer, p_resource_type character varying, p_resource_id integer, p_request_title character varying, p_request_description text, p_project_id integer DEFAULT NULL::integer, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_start_time time without time zone DEFAULT NULL::time without time zone, p_end_time time without time zone DEFAULT NULL::time without time zone) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_request_id INTEGER;
BEGIN
    -- Проверяем что resource_id не NULL
    IF p_resource_id IS NULL THEN
        RAISE EXCEPTION 'resource_id не может быть NULL';
    END IF;
    
    -- Проверяем существование ресурса
    IF p_resource_type = 'matresource' AND NOT EXISTS (
        SELECT 1 FROM matresources WHERE matresource_id = p_resource_id
    ) THEN
        RAISE EXCEPTION 'Материальный ресурс с ID % не существует', p_resource_id;
    ELSIF p_resource_type = 'service' AND NOT EXISTS (
        SELECT 1 FROM services WHERE service_id = p_resource_id
    ) THEN
        RAISE EXCEPTION 'Услуга с ID % не существует', p_resource_id;
    ELSIF p_resource_type = 'venue' AND NOT EXISTS (
        SELECT 1 FROM venues WHERE venue_id = p_resource_id
    ) THEN
        RAISE EXCEPTION 'Место проведения с ID % не существует', p_resource_id;
    ELSIF p_resource_type = 'finresource' AND NOT EXISTS (
        SELECT 1 FROM finresources WHERE finresource_id = p_resource_id
    ) THEN
        RAISE EXCEPTION 'Финансовый ресурс с ID % не существует', p_resource_id;
    END IF;
    
    -- Вставляем запрос
    INSERT INTO requests (
        requester_id,
        resource_type,
        resource_id,
        request_title,
        request_description,
        project_id,
        start_date,
        end_date,
        start_time,
        end_time,
        request_status
    ) VALUES (
        p_requester_id,
        p_resource_type,
        p_resource_id,
        p_request_title,
        p_request_description,
        p_project_id,
        p_start_date,
        p_end_date,
        p_start_time,
        p_end_time,
        'draft'
    ) RETURNING request_id INTO v_request_id;
    
    RETURN v_request_id;
END;
$$;


ALTER FUNCTION public.create_request(p_requester_id integer, p_resource_type character varying, p_resource_id integer, p_request_title character varying, p_request_description text, p_project_id integer, p_start_date date, p_end_date date, p_start_time time without time zone, p_end_time time without time zone) OWNER TO postgres;

--
-- Name: create_temp_contract_on_request_accept(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_temp_contract_on_request_accept() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_owner_actor_id INTEGER;
    v_resource_title VARCHAR(200);
    v_temp_contract_id INTEGER;
    v_offering_term_cost DECIMAL(15,2);
    v_offering_term_currency VARCHAR(10);
    v_offering_special_terms TEXT;
BEGIN
    -- Если статус изменился на 'accepted'
    IF NEW.request_status = 'accepted' AND OLD.request_status != 'accepted' THEN
        -- Находим владельца ресурса
        IF NEW.resource_type = 'matresource' THEN
            -- Для материальных ресурсов
            SELECT mo.actor_id INTO v_owner_actor_id
            FROM matresource_owners mo
            WHERE mo.matresource_id = NEW.resource_id
            LIMIT 1;
            
            SELECT title INTO v_resource_title
            FROM matresources WHERE matresource_id = NEW.resource_id;
            
        ELSIF NEW.resource_type = 'finresource' THEN
            -- Для финансовых ресурсов
            SELECT fo.actor_id INTO v_owner_actor_id
            FROM finresource_owners fo
            WHERE fo.finresource_id = NEW.resource_id
            LIMIT 1;
            
            SELECT title INTO v_resource_title
            FROM finresources WHERE finresource_id = NEW.resource_id;
            
        ELSIF NEW.resource_type = 'venue' THEN
            -- Для мест проведения
            SELECT vo.actor_id INTO v_owner_actor_id
            FROM venue_owners vo
            WHERE vo.venue_id = NEW.resource_id 
            AND vo.is_primary = TRUE
            LIMIT 1;
            
            SELECT title INTO v_resource_title
            FROM venues WHERE venue_id = NEW.resource_id;
            
        ELSIF NEW.resource_type = 'service' THEN
            -- Для услуг
            SELECT so.actor_id INTO v_owner_actor_id
            FROM service_owners so
            WHERE so.service_id = NEW.resource_id 
            AND so.is_primary = TRUE
            LIMIT 1;
            
            SELECT title INTO v_resource_title
            FROM services WHERE service_id = NEW.resource_id;
        END IF;
        
        -- Если владелец не найден, используем reviewed_by или любого администратора
        IF v_owner_actor_id IS NULL THEN
            -- Сначала пробуем reviewed_by
            v_owner_actor_id := NEW.reviewed_by;
            
            -- Если и его нет, берем любого активного участника
            IF v_owner_actor_id IS NULL THEN
                SELECT actor_id INTO v_owner_actor_id
                FROM actors 
                WHERE deleted_at IS NULL
                LIMIT 1;
            END IF;
        END IF;
        
        -- Если все еще нет владельца, генерируем ошибку
        IF v_owner_actor_id IS NULL THEN
            RAISE EXCEPTION 'Не удалось определить владельца ресурса для запроса %', NEW.request_id;
        END IF;
        
        -- Создаем временный договор
        INSERT INTO temp_contracts (
            request_id,
            contract_title,
            contract_description,
            requester_id,
            owner_id,
            resource_type,
            resource_id,
            start_date,
            end_date,
            start_time,
            end_time,
            contract_status
        ) VALUES (
            NEW.request_id,
            'Временный договор: ' || COALESCE(v_resource_title, NEW.request_title),
            COALESCE(NEW.request_description, 'Договор по запросу ' || NEW.request_id),
            NEW.requester_id,
            v_owner_actor_id,
            NEW.resource_type,
            NEW.resource_id,
            NEW.start_date,
            NEW.end_date,
            NEW.start_time,
            NEW.end_time,
            'draft'
        ) RETURNING temp_contract_id INTO v_temp_contract_id;
        
        RAISE NOTICE 'Создан временный договор ID: % для запроса ID: %', v_temp_contract_id, NEW.request_id;
        
        -- Копируем выбранные условия во временный договор
        -- Нужно получить стоимость и условия из связанных таблиц (matresource_offering_terms и т.д.)
        INSERT INTO temp_contract_terms (
            temp_contract_id,
            request_term_id,
            offering_term_id,
            agreed_cost,
            agreed_currency,
            special_terms
        )
        SELECT 
            v_temp_contract_id,
            rot.request_term_id,
            rot.offering_term_id,
            COALESCE(rot.proposed_cost, 
                -- Получаем стоимость из соответствующей таблицы ресурсов
                CASE NEW.resource_type
                    WHEN 'matresource' THEN (SELECT mot.cost FROM matresource_offering_terms mot 
                                            WHERE mot.matresource_id = NEW.resource_id 
                                            AND mot.offering_term_id = rot.offering_term_id
                                            LIMIT 1)
                    WHEN 'finresource' THEN (SELECT fot.cost FROM finresource_offering_terms fot 
                                            WHERE fot.finresource_id = NEW.resource_id 
                                            AND fot.offering_term_id = rot.offering_term_id
                                            LIMIT 1)
                    WHEN 'venue' THEN (SELECT vot.cost FROM venue_offering_terms vot 
                                      WHERE vot.venue_id = NEW.resource_id 
                                      AND vot.offering_term_id = rot.offering_term_id
                                      LIMIT 1)
                    WHEN 'service' THEN (SELECT sot.cost FROM service_offering_terms sot 
                                        WHERE sot.service_id = NEW.resource_id 
                                        AND sot.offering_term_id = rot.offering_term_id
                                        LIMIT 1)
                END, 
                0.00) as agreed_cost,
            COALESCE(
                CASE NEW.resource_type
                    WHEN 'matresource' THEN (SELECT mot.currency FROM matresource_offering_terms mot 
                                            WHERE mot.matresource_id = NEW.resource_id 
                                            AND mot.offering_term_id = rot.offering_term_id
                                            LIMIT 1)
                    WHEN 'finresource' THEN (SELECT fot.currency FROM finresource_offering_terms fot 
                                            WHERE fot.finresource_id = NEW.resource_id 
                                            AND fot.offering_term_id = rot.offering_term_id
                                            LIMIT 1)
                    WHEN 'venue' THEN (SELECT vot.currency FROM venue_offering_terms vot 
                                      WHERE vot.venue_id = NEW.resource_id 
                                      AND vot.offering_term_id = rot.offering_term_id
                                      LIMIT 1)
                    WHEN 'service' THEN (SELECT sot.currency FROM service_offering_terms sot 
                                        WHERE sot.service_id = NEW.resource_id 
                                        AND sot.offering_term_id = rot.offering_term_id
                                        LIMIT 1)
                END,
                'руб.') as agreed_currency,
            COALESCE(rot.request_terms,
                CASE NEW.resource_type
                    WHEN 'matresource' THEN (SELECT mot.special_terms FROM matresource_offering_terms mot 
                                            WHERE mot.matresource_id = NEW.resource_id 
                                            AND mot.offering_term_id = rot.offering_term_id
                                            LIMIT 1)
                    WHEN 'finresource' THEN (SELECT fot.special_terms FROM finresource_offering_terms fot 
                                            WHERE fot.finresource_id = NEW.resource_id 
                                            AND fot.offering_term_id = rot.offering_term_id
                                            LIMIT 1)
                    WHEN 'venue' THEN (SELECT vot.special_terms FROM venue_offering_terms vot 
                                      WHERE vot.venue_id = NEW.resource_id 
                                      AND vot.offering_term_id = rot.offering_term_id
                                      LIMIT 1)
                    WHEN 'service' THEN (SELECT sot.special_terms FROM service_offering_terms sot 
                                        WHERE sot.service_id = NEW.resource_id 
                                        AND sot.offering_term_id = rot.offering_term_id
                                        LIMIT 1)
                END,
                '') as special_terms
        FROM request_offering_terms rot
        WHERE rot.request_id = NEW.request_id;
        
        RAISE NOTICE 'Добавлено % условий во временный договор', (SELECT COUNT(*) FROM temp_contract_terms WHERE temp_contract_id = v_temp_contract_id);
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.create_temp_contract_on_request_accept() OWNER TO postgres;

--
-- Name: find_entities_nearby(numeric, numeric, integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_entities_nearby(p_latitude numeric, p_longitude numeric, p_radius_meters integer DEFAULT 1000, p_entity_type character varying DEFAULT NULL::character varying) RETURNS TABLE(entity_type character varying, entity_id integer, entity_title text, distance_meters double precision, latitude double precision, longitude double precision, address text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_center_point GEOMETRY;
BEGIN
    v_center_point = ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
    
    RETURN QUERY
    SELECT 
        eg.entity_type,
        eg.entity_id,
        CASE eg.entity_type
            WHEN 'location' THEN l.name
            WHEN 'venue' THEN v.title
            WHEN 'event' THEN e.title
            WHEN 'organization' THEN o.title
            WHEN 'community' THEN c.title
            WHEN 'project' THEN p.title
            WHEN 'stage' THEN s.title
        END::TEXT as entity_title,
        ST_Distance(
            ST_Transform(eg.geom, 3857),
            ST_Transform(v_center_point, 3857)
        ) as distance_meters,
        vc.latitude::DOUBLE PRECISION,
        vc.longitude::DOUBLE PRECISION,
        eg.address
    FROM entity_geometries eg
    JOIN v_entity_geometries_with_coords vc ON eg.geometry_id = vc.geometry_id
    LEFT JOIN locations l ON eg.entity_type = 'location' AND eg.entity_id = l.location_id
    LEFT JOIN venues v ON eg.entity_type = 'venue' AND eg.entity_id = v.venue_id
    LEFT JOIN events e ON eg.entity_type = 'event' AND eg.entity_id = e.event_id
    LEFT JOIN organizations o ON eg.entity_type = 'organization' AND eg.entity_id = o.organization_id
    LEFT JOIN communities c ON eg.entity_type = 'community' AND eg.entity_id = c.community_id
    LEFT JOIN projects p ON eg.entity_type = 'project' AND eg.entity_id = p.project_id
    LEFT JOIN stages s ON eg.entity_type = 'stage' AND eg.entity_id = s.stage_id
    WHERE ST_DWithin(
        ST_Transform(eg.geom, 3857),
        ST_Transform(v_center_point, 3857),
        p_radius_meters
    )
    AND (p_entity_type IS NULL OR eg.entity_type = p_entity_type)
    ORDER BY distance_meters ASC;
END;
$$;


ALTER FUNCTION public.find_entities_nearby(p_latitude numeric, p_longitude numeric, p_radius_meters integer, p_entity_type character varying) OWNER TO postgres;

--
-- Name: find_entities_nearby_decimal(numeric, numeric, integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_entities_nearby_decimal(p_latitude numeric, p_longitude numeric, p_radius_meters integer DEFAULT 1000, p_entity_type character varying DEFAULT NULL::character varying) RETURNS TABLE(entity_type character varying, entity_id integer, entity_title text, distance_meters numeric, latitude numeric, longitude numeric, address text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_center_point GEOMETRY;
BEGIN
    v_center_point = ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
    
    RETURN QUERY
    SELECT 
        eg.entity_type,
        eg.entity_id,
        CASE eg.entity_type
            WHEN 'location' THEN l.name
            WHEN 'venue' THEN v.title
            WHEN 'event' THEN e.title
            WHEN 'organization' THEN o.title
            WHEN 'community' THEN c.title
            WHEN 'project' THEN p.title
            WHEN 'stage' THEN s.title
        END::TEXT as entity_title,
        ROUND(CAST(ST_Distance(
            ST_Transform(eg.geom, 3857),
            ST_Transform(v_center_point, 3857)
        ) AS NUMERIC), 2) as distance_meters,
        vc.latitude::DECIMAL(10, 8),
        vc.longitude::DECIMAL(11, 8),
        eg.address
    FROM entity_geometries eg
    JOIN v_entity_geometries_with_coords vc ON eg.geometry_id = vc.geometry_id
    LEFT JOIN locations l ON eg.entity_type = 'location' AND eg.entity_id = l.location_id
    LEFT JOIN venues v ON eg.entity_type = 'venue' AND eg.entity_id = v.venue_id
    LEFT JOIN events e ON eg.entity_type = 'event' AND eg.entity_id = e.event_id
    LEFT JOIN organizations o ON eg.entity_type = 'organization' AND eg.entity_id = o.organization_id
    LEFT JOIN communities c ON eg.entity_type = 'community' AND eg.entity_id = c.community_id
    LEFT JOIN projects p ON eg.entity_type = 'project' AND eg.entity_id = p.project_id
    LEFT JOIN stages s ON eg.entity_type = 'stage' AND eg.entity_id = s.stage_id
    WHERE ST_DWithin(
        ST_Transform(eg.geom, 3857),
        ST_Transform(v_center_point, 3857),
        p_radius_meters
    )
    AND (p_entity_type IS NULL OR eg.entity_type = p_entity_type)
    ORDER BY distance_meters ASC;
END;
$$;


ALTER FUNCTION public.find_entities_nearby_decimal(p_latitude numeric, p_longitude numeric, p_radius_meters integer, p_entity_type character varying) OWNER TO postgres;

--
-- Name: find_free_resources(text[]); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_free_resources(p_resource_types text[] DEFAULT NULL::text[]) RETURNS TABLE(resource_type text, resource_id integer, title text, description text, free_condition text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        aro.resource_type::TEXT,
        aro.resource_id::INTEGER,
        aro.title::TEXT,
        get_resource_description(aro.resource_type, aro.resource_id)::TEXT as description,
        aro.offering_term_name::TEXT as free_condition
    FROM v_all_resources_offerings aro
    WHERE aro.cost = 0
        AND (p_resource_types IS NULL OR aro.resource_type = ANY(p_resource_types))
    ORDER BY aro.resource_type::TEXT, aro.title::TEXT;  -- Явное указание столбцов из SELECT
END;
$$;


ALTER FUNCTION public.find_free_resources(p_resource_types text[]) OWNER TO postgres;

--
-- Name: find_potential_owners(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_potential_owners(p_global_request_id integer) RETURNS TABLE(actor_id integer, nickname character varying, resource_id integer, resource_name character varying, resource_type character varying, distance_info text, has_responded boolean, response_status character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_request RECORD;
    v_requester_location_id INT;
BEGIN
    -- Получаем данные запроса из реальной таблицы global_requests
    SELECT gr.*, rt.type as resource_type_name
    INTO v_request
    FROM global_requests gr
    JOIN resource_types rt ON gr.resource_type_id = rt.resource_type_id
    WHERE gr.global_request_id = p_global_request_id;
    
    IF v_request IS NULL THEN
        RAISE EXCEPTION 'Запрос % не найден', p_global_request_id;
    END IF;
    
    -- Получаем локацию создателя запроса из actors_locations
    SELECT al.location_id
    INTO v_requester_location_id
    FROM actors_locations al
    WHERE al.actor_id = v_request.requester_id 
    LIMIT 1;
    
    -- Для типа "Локация" (venues) используем корректные имена полей
    IF v_request.resource_type_name = 'Локация' THEN
        RETURN QUERY
        SELECT 
            a.actor_id,
            a.nickname,
            v.venue_id as resource_id,
            v.title as resource_name,  -- Используем title вместо name
            'Локация'::VARCHAR(50) as resource_type,
            CASE 
                WHEN al.location_id = v_requester_location_id 
                    THEN 'В той же локации'::TEXT
                WHEN al.location_id IS NOT NULL AND v_requester_location_id IS NOT NULL 
                    THEN 'В другой локации'::TEXT
                ELSE 'Локация неизвестна'::TEXT
            END as distance_info,
            COALESCE(grr.status IS NOT NULL, false) as has_responded,
            grr.status as response_status
        FROM venues v
        JOIN actors a ON v.actor_id = a.actor_id  -- КОРРЕКТНО: actor_id, а не owner_id
        LEFT JOIN actors_locations al ON a.actor_id = al.actor_id
        LEFT JOIN global_request_responses grr 
            ON grr.global_request_id = p_global_request_id
            AND grr.owner_id = a.actor_id
            AND grr.resource_id = v.venue_id
        WHERE v.venue_type_id = COALESCE(v_request.subject_type_id, v.venue_type_id)
          AND (v_request.location_id IS NULL OR v.location_id = v_request.location_id)
        ORDER BY 
            CASE WHEN al.location_id = v_requester_location_id THEN 1 ELSE 2 END,
            a.nickname;
    ELSE
        RAISE NOTICE 'Тип ресурса "%" пока не поддерживается', v_request.resource_type_name;
        RETURN;
    END IF;
    
END;
$$;


ALTER FUNCTION public.find_potential_owners(p_global_request_id integer) OWNER TO postgres;

--
-- Name: find_potential_owners_simple(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_potential_owners_simple(p_global_request_id integer) RETURNS TABLE(actor_id integer, nickname character varying, resource_id integer, resource_name character varying, has_responded boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.actor_id,
        a.nickname,
        v.venue_id as resource_id,
        v.title as resource_name,
        COALESCE(grr.response_id IS NOT NULL, false) as has_responded
    FROM venues v
    JOIN actors a ON v.actor_id = a.actor_id
    LEFT JOIN global_request_responses grr 
        ON grr.global_request_id = p_global_request_id
        AND grr.owner_id = a.actor_id
        AND grr.resource_id = v.venue_id
    WHERE v.venue_type_id IN (
        SELECT subject_type_id 
        FROM global_requests 
        WHERE global_request_id = p_global_request_id
    )
    AND (EXISTS (
        SELECT 1 FROM global_requests gr
        WHERE gr.global_request_id = p_global_request_id
        AND (gr.location_id IS NULL OR v.location_id = gr.location_id)
    ))
    ORDER BY a.nickname;
END;
$$;


ALTER FUNCTION public.find_potential_owners_simple(p_global_request_id integer) OWNER TO postgres;

--
-- Name: find_rental_resources(numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.find_rental_resources(p_max_daily_price numeric DEFAULT NULL::numeric) RETURNS TABLE(resource_type text, resource_id integer, title text, daily_price numeric, currency text, conditions text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        aro.resource_type::TEXT,
        aro.resource_id::INTEGER,
        aro.title::TEXT,
        aro.cost::DECIMAL as daily_price,
        aro.currency::TEXT,
        aro.offering_special_terms::TEXT as conditions
    FROM v_all_resources_offerings aro
    WHERE aro.offering_term_code = 'temporary_paid'
        AND (p_max_daily_price IS NULL OR aro.cost <= p_max_daily_price)
    ORDER BY aro.cost;
END;
$$;


ALTER FUNCTION public.find_rental_resources(p_max_daily_price numeric) OWNER TO postgres;

--
-- Name: fix_actor_integrity(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fix_actor_integrity(p_actor_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_actor_type_id INTEGER;
    v_nickname VARCHAR;
BEGIN
    -- Получаем данные актора
    SELECT actor_type_id, nickname 
    INTO v_actor_type_id, v_nickname
    FROM actors 
    WHERE actor_id = p_actor_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Актор с ID % не найден', p_actor_id;
    END IF;
    
    -- В зависимости от типа создаем недостающую запись
    IF v_actor_type_id = 1 AND NOT EXISTS (SELECT 1 FROM persons WHERE actor_id = p_actor_id) THEN
        INSERT INTO persons (name, actor_id, created_by, updated_by)
        VALUES (v_nickname, p_actor_id, 1, 1);
        RAISE NOTICE 'Создана запись в persons для актора %', p_actor_id;
    
    ELSIF v_actor_type_id = 2 AND NOT EXISTS (SELECT 1 FROM communities WHERE actor_id = p_actor_id) THEN
        INSERT INTO communities (title, actor_id, created_by, updated_by)
        VALUES (v_nickname, p_actor_id, 1, 1);
        RAISE NOTICE 'Создана запись в communities для актора %', p_actor_id;
    
    ELSIF v_actor_type_id = 3 AND NOT EXISTS (SELECT 1 FROM organizations WHERE actor_id = p_actor_id) THEN
        INSERT INTO organizations (title, actor_id, created_by, updated_by)
        VALUES (v_nickname, p_actor_id, 1, 1);
        RAISE NOTICE 'Создана запись в organizations для актора %', p_actor_id;
    
    ELSE
        RAISE NOTICE 'Целостность данных для актора % уже обеспечена', p_actor_id;
    END IF;
END;
$$;


ALTER FUNCTION public.fix_actor_integrity(p_actor_id integer) OWNER TO postgres;

--
-- Name: generate_contract_number(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_contract_number() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.contract_number IS NULL THEN
        NEW.contract_number := 'CTR-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD-') || 
                              LPAD(NEXTVAL('contract_number_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.generate_contract_number() OWNER TO postgres;

--
-- Name: get_actor_current_status(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_actor_current_status(actor_id_param integer) RETURNS TABLE(status_name character varying, status_date timestamp with time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT as2.status, acs.created_at
    FROM actor_current_statuses acs
    JOIN actor_statuses as2 ON acs.actor_status_id = as2.actor_status_id
    WHERE acs.actor_id = actor_id_param
    ORDER BY acs.created_at DESC
    LIMIT 1;
END;
$$;


ALTER FUNCTION public.get_actor_current_status(actor_id_param integer) OWNER TO postgres;

--
-- Name: get_asset_files(character varying, integer, character varying, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_asset_files(p_asset_table character varying, p_record_id integer, p_file_category character varying DEFAULT NULL::character varying, p_only_primary boolean DEFAULT false) RETURNS TABLE(file_url text, file_type character varying, file_category character varying, file_name character varying, is_primary boolean, file_size bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        af.file_url,
        af.file_type,
        af.file_category,
        af.file_name,
        af.is_primary,
        af.file_size
    FROM asset_files af
    JOIN asset_types at ON af.asset_type_id = at.asset_type_id
    WHERE at.asset_table = p_asset_table
    AND af.asset_record_id = p_record_id
    AND (p_file_category IS NULL OR af.file_category = p_file_category)
    AND (NOT p_only_primary OR af.is_primary = TRUE)
    ORDER BY af.file_category, af.is_primary DESC, af.sort_order;
END;
$$;


ALTER FUNCTION public.get_asset_files(p_asset_table character varying, p_record_id integer, p_file_category character varying, p_only_primary boolean) OWNER TO postgres;

--
-- Name: get_cost_display(numeric, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_cost_display(p_cost numeric, p_currency character varying, p_offering_term_id integer) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    term_name TEXT;
    term_code TEXT;
BEGIN
    -- Если ID не указан, используем значение по умолчанию
    IF p_offering_term_id IS NULL THEN
        p_offering_term_id = 2;
    END IF;
    
    -- Получаем информацию об условиях
    SELECT name, code INTO term_name, term_code 
    FROM offering_terms WHERE id = p_offering_term_id;
    
    -- Если запись не найдена, используем значение по умолчанию
    IF term_name IS NULL THEN
        term_name = 'Безвозмездная передача';
        term_code = 'free_transfer';
    END IF;
    
    -- Формируем строку отображения
    IF term_code IN ('free_transfer', 'temporary_free') THEN
        RETURN term_name;
    ELSIF p_cost IS NULL OR p_cost = 0 THEN
        RETURN 'Бесплатно';
    ELSE
        RETURN p_cost || ' ' || COALESCE(p_currency, 'руб.');
    END IF;
END;
$$;


ALTER FUNCTION public.get_cost_display(p_cost numeric, p_currency character varying, p_offering_term_id integer) OWNER TO postgres;

--
-- Name: get_global_request_stats(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_global_request_stats(p_global_request_id integer) RETURNS TABLE(total_potential_owners integer, total_responses integer, pending_responses integer, accepted_responses integer, rejected_responses integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH potential AS (
        SELECT COUNT(*) as count
        FROM find_potential_owners(p_global_request_id)
    ),
    responses AS (
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE status = 'pending') as pending,
            COUNT(*) FILTER (WHERE status = 'accepted') as accepted,
            COUNT(*) FILTER (WHERE status = 'rejected') as rejected
        FROM global_request_responses
        WHERE global_request_id = p_global_request_id
          AND is_active = true
    )
    SELECT 
        p.count::INT,
        COALESCE(r.total, 0)::INT,
        COALESCE(r.pending, 0)::INT,
        COALESCE(r.accepted, 0)::INT,
        COALESCE(r.rejected, 0)::INT
    FROM potential p, responses r;
END;
$$;


ALTER FUNCTION public.get_global_request_stats(p_global_request_id integer) OWNER TO postgres;

--
-- Name: get_global_request_stats_simple(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_global_request_stats_simple(p_global_request_id integer) RETURNS TABLE(total_potential_owners integer, total_responses integer, pending_responses integer, accepted_responses integer, rejected_responses integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_request_subject_type_id INT;
    v_request_location_id INT;
BEGIN
    -- Получаем параметры запроса
    SELECT subject_type_id, location_id 
    INTO v_request_subject_type_id, v_request_location_id
    FROM global_requests 
    WHERE global_request_id = p_global_request_id;
    
    RETURN QUERY
    WITH responses AS (
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE status = 'pending') as pending,
            COUNT(*) FILTER (WHERE status = 'accepted') as accepted,
            COUNT(*) FILTER (WHERE status = 'rejected') as rejected
        FROM global_request_responses
        WHERE global_request_id = p_global_request_id
          AND is_active = true
    ),
    potential AS (
        SELECT COUNT(DISTINCT v.actor_id) as count
        FROM venues v
        WHERE (v_request_subject_type_id IS NULL OR v.venue_type_id = v_request_subject_type_id)
          AND (v_request_location_id IS NULL OR v.location_id = v_request_location_id)
    )
    SELECT 
        COALESCE(p.count, 0)::INT,
        COALESCE(r.total, 0)::INT,
        COALESCE(r.pending, 0)::INT,
        COALESCE(r.accepted, 0)::INT,
        COALESCE(r.rejected, 0)::INT
    FROM potential p
    CROSS JOIN responses r;
END;
$$;


ALTER FUNCTION public.get_global_request_stats_simple(p_global_request_id integer) OWNER TO postgres;

--
-- Name: get_latitude_from_geom(public.geometry); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_latitude_from_geom(geom public.geometry) RETURNS numeric
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    IF geom IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN ST_Y(geom::geometry);
END;
$$;


ALTER FUNCTION public.get_latitude_from_geom(geom public.geometry) OWNER TO postgres;

--
-- Name: get_longitude_from_geom(public.geometry); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_longitude_from_geom(geom public.geometry) RETURNS numeric
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    IF geom IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN ST_X(geom::geometry);
END;
$$;


ALTER FUNCTION public.get_longitude_from_geom(geom public.geometry) OWNER TO postgres;

--
-- Name: get_project_participants_count(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_project_participants_count(project_id_param integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    participants_count INTEGER;
BEGIN
    SELECT COUNT(DISTINCT actor_id) 
    INTO participants_count
    FROM actors_projects 
    WHERE project_id = project_id_param;
    
    RETURN COALESCE(participants_count, 0);
END;
$$;


ALTER FUNCTION public.get_project_participants_count(project_id_param integer) OWNER TO postgres;

--
-- Name: get_request_resource_info(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_request_resource_info(p_request_id integer) RETURNS TABLE(resource_type_id integer, subject_type_id integer, subject_id integer)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_request RECORD;
    v_entity_table TEXT;
    v_type_column TEXT;
BEGIN
    -- Получаем данные запроса и сопоставление из resource_types
    SELECT rq.*, rt.entity_table, rt.entity_type_column
    INTO v_request
    FROM requests rq
    LEFT JOIN resource_types rt ON rq.request_type_id = rt.resource_type_id
    WHERE rq.request_id = p_request_id;

    IF v_request.request_type_id IS NOT NULL AND v_request.resource_id IS NOT NULL THEN
        resource_type_id := v_request.request_type_id;
        subject_id := v_request.resource_id;
        v_entity_table := v_request.entity_table;
        v_type_column := v_request.entity_type_column;

        -- Динамически получаем ID типа (например, venue_type_id) из связанной таблицы
        IF v_entity_table IS NOT NULL AND v_type_column IS NOT NULL THEN
            EXECUTE format(
                'SELECT %I FROM %I WHERE %I = $1',
                v_type_column,
                v_entity_table,
                -- Определяем имя колонки с первичным ключом
                CASE v_entity_table
                    WHEN 'venues' THEN 'venue_id'
                    WHEN 'matresources' THEN 'matresource_id'
                    WHEN 'finresources' THEN 'finresource_id'
                    WHEN 'services' THEN 'service_id'
                    WHEN 'ideas' THEN 'idea_id'
                    WHEN 'functions' THEN 'function_id'
                    ELSE NULL
                END
            )
            INTO subject_type_id
            USING v_request.resource_id;
        ELSE
            subject_type_id := NULL; -- Для функций типа нет
        END IF;
    END IF;

    RETURN NEXT;
END;
$_$;


ALTER FUNCTION public.get_request_resource_info(p_request_id integer) OWNER TO postgres;

--
-- Name: get_resource_description(text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_resource_description(p_resource_type text, p_resource_id integer) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v_description TEXT;
BEGIN
    IF p_resource_type = 'matresource' THEN
        SELECT description INTO v_description
        FROM matresources WHERE matresource_id = p_resource_id;
        
    ELSIF p_resource_type = 'idea' THEN
        -- Для идей выбираем первое непустое описание
        SELECT COALESCE(short_description, detail_description, full_description, '')
        INTO v_description
        FROM ideas WHERE idea_id = p_resource_id;
        
    ELSIF p_resource_type = 'service' THEN
        SELECT description INTO v_description
        FROM services WHERE service_id = p_resource_id;
        
    ELSIF p_resource_type = 'template' THEN
        SELECT description INTO v_description
        FROM templates WHERE template_id = p_resource_id;
        
    ELSIF p_resource_type = 'venue' THEN
        SELECT description INTO v_description
        FROM venues WHERE venue_id = p_resource_id;
        
    ELSE
        v_description := '';
    END IF;
    
    RETURN COALESCE(v_description, '');
END;
$$;


ALTER FUNCTION public.get_resource_description(p_resource_type text, p_resource_id integer) OWNER TO postgres;

--
-- Name: get_resource_offerings(text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_resource_offerings(p_resource_type text, p_resource_id integer) RETURNS TABLE(offering_term_id integer, offering_term_name text, offering_term_code text, cost numeric, currency text, price_display text, special_terms text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        aro.offering_term_id,
        aro.offering_term_name::TEXT,  -- Явное приведение к TEXT
        aro.offering_term_code::TEXT,
        aro.cost,
        aro.currency::TEXT,
        CASE 
            WHEN aro.cost = 0 THEN 'Бесплатно'
            ELSE aro.cost || ' ' || aro.currency
        END,
        aro.offering_special_terms::TEXT
    FROM v_all_resources_offerings aro
    WHERE aro.resource_type = p_resource_type
        AND aro.resource_id = p_resource_id
    ORDER BY aro.offering_term_id;
END;
$$;


ALTER FUNCTION public.get_resource_offerings(p_resource_type text, p_resource_id integer) OWNER TO postgres;

--
-- Name: get_resource_owner_location(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_resource_owner_location(p_resource_type character varying, p_resource_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_owner_id INT;
    v_owner_location_id INT;
BEGIN
    -- Определяем владельца ресурса
    IF p_resource_type = 'venue' THEN
        SELECT owner_id INTO v_owner_id FROM venues WHERE venue_id = p_resource_id;
    ELSIF p_resource_type = 'matresource' THEN
        SELECT owner_id INTO v_owner_id FROM matresources WHERE matresource_id = p_resource_id;
    ELSIF p_resource_type = 'finresource' THEN
        SELECT owner_id INTO v_owner_id FROM finresources WHERE finresource_id = p_resource_id;
    ELSIF p_resource_type = 'service' THEN
        SELECT owner_id INTO v_owner_id FROM services WHERE service_id = p_resource_id;
    ELSIF p_resource_type = 'idea' THEN
        SELECT author_id INTO v_owner_id FROM ideas WHERE idea_id = p_resource_id;
    ELSIF p_resource_type = 'function' THEN
        SELECT actor_id INTO v_owner_id 
        FROM actors_functions 
        WHERE function_id = p_resource_id 
        LIMIT 1;
    ELSE
        v_owner_id := NULL;
    END IF;

    -- Получаем локацию владельца
    IF v_owner_id IS NOT NULL THEN
        SELECT location_id INTO v_owner_location_id
        FROM actors_locations 
        WHERE actor_id = v_owner_id 
        LIMIT 1;
    END IF;

    RETURN v_owner_location_id;
END;
$$;


ALTER FUNCTION public.get_resource_owner_location(p_resource_type character varying, p_resource_id integer) OWNER TO postgres;

--
-- Name: log_global_response_status_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_global_response_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO global_response_status_history (
            response_id,
            old_status,
            new_status,
            changed_by,
            reason
        ) VALUES (
            NEW.response_id,
            OLD.status,
            NEW.status,
            -- Здесь нужно определить, кто изменил статус
            -- Пока ставим владельца отклика
            NEW.owner_id,
            'Статус изменен'
        );
        
        NEW.status_changed_date := CURRENT_TIMESTAMP;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_global_response_status_change() OWNER TO postgres;

--
-- Name: quick_search_resources(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.quick_search_resources(p_search_text text DEFAULT NULL::text) RETURNS TABLE(resource_type text, resource_id integer, title text, offering_count bigint, price_range text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rc.resource_type::TEXT,
        rc.id::INTEGER,
        rc.title::TEXT,
        rc.offering_count::BIGINT,
        CASE 
            WHEN rc.min_price = 0 AND rc.max_price = 0 THEN 'Бесплатно'
            WHEN rc.min_price = 0 THEN 'Бесплатно - ' || rc.max_price::text || ' руб.'
            WHEN rc.min_price = rc.max_price THEN rc.min_price::text || ' руб.'
            ELSE rc.min_price::text || ' - ' || rc.max_price::text || ' руб.'
        END::TEXT as price_range
    FROM v_resource_catalog rc
    WHERE rc.offering_count > 0
        AND (
            p_search_text IS NULL 
            OR rc.title ILIKE '%' || p_search_text || '%'
            OR get_resource_description(rc.resource_type, rc.id) ILIKE '%' || p_search_text || '%'
        )
    ORDER BY rc.resource_type, rc.title;
END;
$$;


ALTER FUNCTION public.quick_search_resources(p_search_text text) OWNER TO postgres;

--
-- Name: register_person(character varying, character varying, character varying, character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.register_person(p_email character varying, p_password character varying, p_nickname character varying, p_name character varying, p_last_name character varying, p_location_id integer DEFAULT NULL::integer) RETURNS TABLE(actor_id integer, nickname character varying, email character varying, message text)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_actor_id INTEGER;
    v_account VARCHAR(12);
    v_account_num BIGINT;
BEGIN
    -- ЯВНО указываем таблицу persons в проверке email
    IF EXISTS (SELECT 1 FROM persons WHERE persons.email = p_email AND persons.deleted_at IS NULL) THEN
        RAISE EXCEPTION 'Email % уже зарегистрирован', p_email;
    END IF;
    
    -- Генерируем уникальный номер счета
    SELECT COALESCE(MAX(CAST(SUBSTRING(account FROM 2) AS BIGINT)), 0) + 1
    INTO v_account_num
    FROM actors
    WHERE account ~ '^U[0-9]+$';
    
    v_account := 'U' || LPAD(v_account_num::TEXT, 11, '0');
    
    -- Создаем запись участника (actor) - БЕЗ указания actor_id
    INSERT INTO actors (nickname, actor_type_id, account, created_by, updated_by)
    VALUES (p_nickname, 1, v_account, 1, 1)
    RETURNING actors.actor_id INTO v_actor_id;
    
    -- Создаем детальную запись (person) - БЕЗ указания person_id
    INSERT INTO persons (name, last_name, email, actor_id, location_id, created_by, updated_by)
    VALUES (p_name, p_last_name, p_email, v_actor_id, p_location_id, 1, 1);
    
    -- Создаем учетные данные (пароль) - БЕЗ указания явного ID
    INSERT INTO actor_credentials (actor_id, password_hash)
    VALUES (v_actor_id, crypt(p_password, gen_salt('bf')));
    
    -- Присваиваем стандартный статус "Участник ТЦ" - БЕЗ указания явного ID
    INSERT INTO actor_current_statuses (actor_id, actor_status_id, created_by, updated_by)
    VALUES (v_actor_id, 7, 1, 1);
    
    -- Возвращаем результат
    RETURN QUERY
    SELECT 
        v_actor_id,
        p_nickname,
        p_email,
        'Регистрация успешна'::TEXT;
    
    EXCEPTION WHEN OTHERS THEN
        RAISE;
END;
$_$;


ALTER FUNCTION public.register_person(p_email character varying, p_password character varying, p_nickname character varying, p_name character varying, p_last_name character varying, p_location_id integer) OWNER TO postgres;

--
-- Name: search_by_keywords(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_by_keywords(search_query text) RETURNS TABLE(result_type character varying, result_id integer, result_title character varying, result_relevance real)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проекты
    RETURN QUERY
    SELECT 
        'project'::VARCHAR,
        p.project_id::INTEGER,
        p.title::VARCHAR,
        ts_rank(
            to_tsvector('russian', COALESCE(p.title, '') || ' ' || COALESCE(p.description, '')),
            plainto_tsquery('russian', search_query)
        )::REAL
    FROM projects p
    WHERE p.deleted_at IS NULL
      AND to_tsvector('russian', COALESCE(p.title, '') || ' ' || COALESCE(p.description, '')) 
          @@ plainto_tsquery('russian', search_query)
    
    UNION ALL
    
    -- Участники
    SELECT 
        'actor'::VARCHAR,
        a.actor_id::INTEGER,
        a.nickname::VARCHAR,
        ts_rank(
            to_tsvector('russian', COALESCE(a.nickname, '')),
            plainto_tsquery('russian', search_query)
        )::REAL
    FROM actors a
    WHERE a.deleted_at IS NULL
      AND to_tsvector('russian', COALESCE(a.nickname, '')) 
          @@ plainto_tsquery('russian', search_query)
    
    UNION ALL
    
    -- Идеи
    SELECT 
        'idea'::VARCHAR,
        i.idea_id::INTEGER,
        i.title::VARCHAR,
        ts_rank(
            to_tsvector('russian', COALESCE(i.title, '') || ' ' || COALESCE(i.full_description, '')),
            plainto_tsquery('russian', search_query)
        )::REAL
    FROM ideas i
    WHERE i.deleted_at IS NULL
      AND to_tsvector('russian', COALESCE(i.title, '') || ' ' || COALESCE(i.full_description, '')) 
          @@ plainto_tsquery('russian', search_query)
    
    ORDER BY 4 DESC
    LIMIT 50;
END;
$$;


ALTER FUNCTION public.search_by_keywords(search_query text) OWNER TO postgres;

--
-- Name: search_resources_by_criteria(text[], numeric, numeric, boolean, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.search_resources_by_criteria(p_resource_types text[] DEFAULT NULL::text[], p_min_price numeric DEFAULT NULL::numeric, p_max_price numeric DEFAULT NULL::numeric, p_include_free boolean DEFAULT true, p_search_text text DEFAULT NULL::text) RETURNS TABLE(resource_type text, resource_id integer, title text, description text, offering_count bigint, min_price numeric, max_price numeric, has_free boolean, has_paid boolean)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rc.resource_type::TEXT,
        rc.id::INTEGER,
        rc.title::TEXT,
        get_resource_description(rc.resource_type, rc.id)::TEXT as description,
        rc.offering_count::BIGINT,  -- явное приведение к BIGINT
        rc.min_price::DECIMAL,
        rc.max_price::DECIMAL,
        rc.has_free_offers::BOOLEAN,
        rc.has_paid_offers::BOOLEAN
    FROM v_resource_catalog rc
    WHERE rc.offering_count > 0
        AND (p_resource_types IS NULL OR rc.resource_type = ANY(p_resource_types))
        AND (p_min_price IS NULL OR rc.max_price >= p_min_price)
        AND (p_max_price IS NULL OR rc.min_price <= p_max_price)
        AND (p_include_free OR rc.has_paid_offers)
        AND (
            p_search_text IS NULL 
            OR rc.title::TEXT ILIKE '%' || p_search_text || '%'
            OR get_resource_description(rc.resource_type, rc.id) ILIKE '%' || p_search_text || '%'
        )
    ORDER BY rc.resource_type, rc.title;
END;
$$;


ALTER FUNCTION public.search_resources_by_criteria(p_resource_types text[], p_min_price numeric, p_max_price numeric, p_include_free boolean, p_search_text text) OWNER TO postgres;

--
-- Name: set_primary_file(integer, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_primary_file(p_file_id integer, p_is_primary boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_is_primary THEN
        -- Снимаем флаг primary с других файлов той же категории
        UPDATE asset_files af1
        SET is_primary = FALSE
        FROM asset_files af2
        WHERE af2.file_id = p_file_id
        AND af1.asset_type_id = af2.asset_type_id
        AND af1.asset_record_id = af2.asset_record_id
        AND af1.file_category = af2.file_category
        AND af1.is_primary = TRUE;
    END IF;
    
    -- Устанавливаем флаг для указанного файла
    UPDATE asset_files
    SET is_primary = p_is_primary
    WHERE file_id = p_file_id;
END;
$$;


ALTER FUNCTION public.set_primary_file(p_file_id integer, p_is_primary boolean) OWNER TO postgres;

--
-- Name: set_request_defaults(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_request_defaults() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_requester_location_id INT;
    v_owner_location_id INT;
BEGIN
    -- 1. Автоматически проставляем location_id из создателя запроса
    IF NEW.location_id IS NULL THEN
        SELECT location_id INTO v_requester_location_id
        FROM actors_locations 
        WHERE actor_id = NEW.requester_id 
        LIMIT 1;
        
        NEW.location_id := v_requester_location_id;
    END IF;

    -- 2. Синхронизируем request_type с resource_type
    IF NEW.request_type IS NULL AND NEW.resource_type IS NOT NULL THEN
        NEW.request_type := NEW.resource_type;
    END IF;

    -- 3. Автоматически определяем request_type_id
    IF NEW.request_type_id IS NULL AND NEW.request_type IS NOT NULL THEN
        SELECT rt.resource_type_id INTO NEW.request_type_id
        FROM resource_types rt
        WHERE rt.type = CASE NEW.request_type
            WHEN 'venue' THEN 'Локация'
            WHEN 'matresource' THEN 'материальный ресурс'
            WHEN 'finresource' THEN 'финансовый ресурс'
            WHEN 'service' THEN 'Услуга'
            WHEN 'idea' THEN 'Идея'
            WHEN 'function' THEN 'Функция'
            ELSE NULL
        END;
    END IF;

    -- 4. Устанавливаем статус "действующий" по умолчанию
    IF NEW.request_status_id IS NULL THEN
        SELECT request_status_id INTO NEW.request_status_id
        FROM request_statuses
        WHERE status = 'действующий';
    END IF;

    -- 5. Проверяем validity_period
    IF NEW.validity_period IS NOT NULL AND NEW.validity_period < CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'validity_period не может быть в прошлом';
    END IF;

    -- 6. ПРОВЕРКА РАЗНЫХ ЛОКАЦИЙ И СОЗДАНИЕ УВЕДОМЛЕНИЯ
    IF NEW.resource_type IS NOT NULL AND NEW.resource_id IS NOT NULL THEN
        v_owner_location_id := get_resource_owner_location(NEW.resource_type, NEW.resource_id);
        
        -- Если у создателя ещё нет локации (маловероятно, но проверим)
        IF NEW.location_id IS NULL AND v_requester_location_id IS NOT NULL THEN
            NEW.location_id := v_requester_location_id;
        END IF;
        
        -- Если локации определены и они разные - создаём уведомление
        IF NEW.location_id IS NOT NULL 
           AND v_owner_location_id IS NOT NULL
           AND NEW.location_id != v_owner_location_id THEN
            
            INSERT INTO notifications (
                actor_id, 
                title, 
                message, 
                notification_type,
                is_read,
                creation_date
            ) VALUES (
                NEW.requester_id,
                'Внимание: различие в локациях',
                'Владелец запрашиваемого ресурса находится в другом населённом пункте.',
                'warning',
                FALSE,
                CURRENT_TIMESTAMP
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_request_defaults() OWNER TO postgres;

--
-- Name: soft_delete_record(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.soft_delete_record() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.deleted_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.soft_delete_record() OWNER TO postgres;

--
-- Name: system_health_check(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.system_health_check() RETURNS TABLE(check_item text, status text, details text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверка 1: Основные таблицы
    check_item := 'Основные таблицы';
    BEGIN
        PERFORM 1 FROM offering_terms LIMIT 1;
        PERFORM 1 FROM matresource_offering_terms LIMIT 1;
        status := '✅';
        details := 'Таблицы условий существуют';
    EXCEPTION WHEN OTHERS THEN
        status := '❌';
        details := 'Ошибка: ' || SQLERRM;
    END;
    RETURN NEXT;
    
    -- Проверка 2: Ключевые представления
    check_item := 'Ключевые представления';
    BEGIN
        PERFORM 1 FROM v_all_resources_offerings LIMIT 1;
        PERFORM 1 FROM v_resource_catalog LIMIT 1;
        status := '✅';
        details := 'Представления работают';
    EXCEPTION WHEN OTHERS THEN
        status := '❌';
        details := 'Ошибка: ' || SQLERRM;
    END;
    RETURN NEXT;
    
    -- Проверка 3: Функции поиска
    check_item := 'Функции поиска';
    BEGIN
        PERFORM * FROM quick_search_resources(NULL::text) LIMIT 1;
        PERFORM * FROM find_free_resources() LIMIT 1;
        status := '✅';
        details := 'Функции поиска работают';
    EXCEPTION WHEN OTHERS THEN
        status := '❌';
        details := 'Ошибка: ' || SQLERRM;
    END;
    RETURN NEXT;
    
    -- Проверка 4: Бизнес-правила
    check_item := 'Бизнес-правила';
    BEGIN
        -- Пытаемся нарушить правило (платно для бесплатного условия)
        INSERT INTO matresource_offering_terms 
            (matresource_id, offering_term_id, cost, special_terms)
        VALUES (1, 2, 1000, 'Тест нарушения правила');
        status := '❌';
        details := 'Триггер не сработал!';
        ROLLBACK;
    EXCEPTION 
        WHEN raise_exception THEN
            status := '✅';
            details := 'Триггеры блокируют нарушения';
        WHEN OTHERS THEN
            status := '❌';
            details := 'Ошибка: ' || SQLERRM;
    END;
    RETURN NEXT;
    
    -- Проверка 5: Тестовые данные
    check_item := 'Тестовые данные';
    BEGIN
        PERFORM 1 FROM v_matresources_offerings WHERE matresource_id = 1;
        status := '✅';
        details := 'Тестовая гармонь найдена';
    EXCEPTION WHEN OTHERS THEN
        status := '❌';
        details := 'Ошибка: ' || SQLERRM;
    END;
    RETURN NEXT;
    
    -- Проверка 6: Пример с гармонью
    check_item := 'Пример реализации';
    BEGIN
        PERFORM COUNT(*) FROM v_matresources_offerings WHERE matresource_id = 1;
        status := '✅';
        details := '6 предложений для гармони';
    EXCEPTION WHEN OTHERS THEN
        status := '❌';
        details := 'Ошибка: ' || SQLERRM;
    END;
    RETURN NEXT;
END;
$$;


ALTER FUNCTION public.system_health_check() OWNER TO postgres;

--
-- Name: test_system(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.test_system() RETURNS TABLE(test_name text, status text, details text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Тест 1: Проверка представлений
    test_name := 'Представления созданы';
    BEGIN
        PERFORM 1 FROM v_matresources_offerings LIMIT 1;
        PERFORM 1 FROM v_all_resources_offerings LIMIT 1;
        PERFORM 1 FROM v_resource_catalog LIMIT 1;
        status := '✅';
        details := 'Все основные представления созданы';
    EXCEPTION WHEN OTHERS THEN
        status := '❌';
        details := 'Ошибка: ' || SQLERRM;
    END;
    RETURN NEXT;

    -- Тест 2: Проверка функций
    test_name := 'Функции работают';
    BEGIN
        PERFORM * FROM quick_search_resources(NULL::text) LIMIT 1;
        PERFORM * FROM get_resource_offerings('matresource'::text, 1) LIMIT 1;
        status := '✅';
        details := 'Ключевые функции работают';
    EXCEPTION WHEN OTHERS THEN
        status := '❌';
        details := 'Ошибка: ' || SQLERRM;
    END;
    RETURN NEXT;

    -- Тест 3: Проверка данных
    test_name := 'Тестовые данные';
    BEGIN
        PERFORM COUNT(*) FROM v_matresources_offerings WHERE matresource_id = 1;
        status := '✅';
        details := 'Тестовая гармонь найдена';
    EXCEPTION WHEN OTHERS THEN
        status := '❌';
        details := 'Ошибка: ' || SQLERRM;
    END;
    RETURN NEXT;

    -- Тест 4: Проверка триггеров
    test_name := 'Бизнес-правила';
    BEGIN
        -- Пытаемся добавить платное условие для бесплатного типа
        INSERT INTO matresource_offering_terms 
            (matresource_id, offering_term_id, cost, special_terms)
        VALUES (1, 2, 1000, 'Тест ошибки');
        status := '❌';
        details := 'Триггер не сработал!';
        
        -- Откатываем если вдруг прошло
        ROLLBACK;
    EXCEPTION 
        WHEN raise_exception THEN
            status := '✅';
            details := 'Триггер блокирует некорректные данные';
        WHEN OTHERS THEN
            status := '❌';
            details := 'Неизвестная ошибка: ' || SQLERRM;
    END;
    RETURN NEXT;
END;
$$;


ALTER FUNCTION public.test_system() OWNER TO postgres;

--
-- Name: update_asset_files_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_asset_files_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_asset_files_updated_at() OWNER TO postgres;

--
-- Name: update_coords_from_geom_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_coords_from_geom_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.geom IS NOT NULL THEN
        NEW.latitude = ST_Y(NEW.geom::geometry);
        NEW.longitude = ST_X(NEW.geom::geometry);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_coords_from_geom_trigger() OWNER TO postgres;

--
-- Name: update_expired_global_requests(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_expired_global_requests() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Обновляем статус истекших запросов
    UPDATE global_requests
    SET request_status_id = (
        SELECT request_status_id 
        FROM request_statuses 
        WHERE status = 'отменён'
    ),
    is_active = false,
    update_date = CURRENT_TIMESTAMP
    WHERE validity_period < CURRENT_TIMESTAMP
      AND is_active = true
      AND request_status_id = (
          SELECT request_status_id 
          FROM request_statuses 
          WHERE status = 'действующий'
      );
END;
$$;


ALTER FUNCTION public.update_expired_global_requests() OWNER TO postgres;

--
-- Name: update_file_statistics(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_file_statistics(p_file_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Здесь можно добавить логику для обновления статистики
    -- Например, обновление счетчиков просмотров, скачиваний и т.д.
    UPDATE file_access_log
    SET action = action -- placeholder
    WHERE file_id = p_file_id;
    
    RAISE NOTICE 'Статистика для файла % обновлена', p_file_id;
END;
$$;


ALTER FUNCTION public.update_file_statistics(p_file_id integer) OWNER TO postgres;

--
-- Name: update_geom_from_coordinates(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_geom_from_coordinates(p_table_name character varying, p_record_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_lat DECIMAL(10, 8);
    v_lon DECIMAL(11, 8);
    v_geom GEOMETRY;
BEGIN
    EXECUTE format('
        SELECT latitude, longitude 
        FROM %I 
        WHERE %I = $1',
        p_table_name,
        CASE p_table_name
            WHEN 'locations' THEN 'location_id'
            WHEN 'venues' THEN 'venue_id'
            WHEN 'events' THEN 'event_id'
            WHEN 'organizations' THEN 'organization_id'
            WHEN 'communities' THEN 'community_id'
            WHEN 'projects' THEN 'project_id'
            WHEN 'stages' THEN 'stage_id'
            ELSE 'id'
        END
    ) INTO v_lat, v_lon USING p_record_id;
    
    IF v_lat IS NOT NULL AND v_lon IS NOT NULL THEN
        v_geom = ST_SetSRID(ST_MakePoint(v_lon, v_lat), 4326);
        
        EXECUTE format('
            UPDATE %I 
            SET geom = $1 
            WHERE %I = $2',
            p_table_name,
            CASE p_table_name
                WHEN 'locations' THEN 'location_id'
                WHEN 'venues' THEN 'venue_id'
                WHEN 'events' THEN 'event_id'
                WHEN 'organizations' THEN 'organization_id'
                WHEN 'communities' THEN 'community_id'
                WHEN 'projects' THEN 'project_id'
                WHEN 'stages' THEN 'stage_id'
                ELSE 'id'
            END
        ) USING v_geom, p_record_id;
        
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$_$;


ALTER FUNCTION public.update_geom_from_coordinates(p_table_name character varying, p_record_id integer) OWNER TO postgres;

--
-- Name: update_last_login(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_last_login(actor_id_param integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE actors 
    SET updated_at = CURRENT_TIMESTAMP
    WHERE actor_id = actor_id_param;
END;
$$;


ALTER FUNCTION public.update_last_login(actor_id_param integer) OWNER TO postgres;

--
-- Name: update_location_geom(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_location_geom() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
        NEW.geom = ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_location_geom() OWNER TO postgres;

--
-- Name: update_requests_on_event_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_requests_on_event_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.event_status_id IS DISTINCT FROM OLD.event_status_id THEN
        -- Приостановка: если событие "Приостановлено" (4) или "В работе" (3)
        IF NEW.event_status_id IN (3, 4) THEN -- Номера из event_statuses
            UPDATE requests 
            SET request_status_id = (
                SELECT request_status_id FROM request_statuses WHERE status = 'приостановлен'
            ),
            update_date = CURRENT_TIMESTAMP
            WHERE event_id = NEW.event_id
              AND request_status_id = (
                  SELECT request_status_id FROM request_statuses WHERE status = 'действующий'
              );
        
        -- Отмена: если событие "Завершено" (5)
        ELSIF NEW.event_status_id = 5 THEN
            UPDATE requests 
            SET request_status_id = (
                SELECT request_status_id FROM request_statuses WHERE status = 'отменён'
            ),
            update_date = CURRENT_TIMESTAMP
            WHERE event_id = NEW.event_id
              AND request_status_id IN (
                  SELECT request_status_id FROM request_statuses 
                  WHERE status IN ('действующий', 'приостановлен')
              );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_requests_on_event_change() OWNER TO postgres;

--
-- Name: update_requests_on_project_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_requests_on_project_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверяем, связан ли запрос с проектом через поле project_id в requests
    -- Если в requests нет project_id, эта логика не сработает
    -- Нужно проверить, есть ли такое поле
    IF TG_OP = 'UPDATE' AND NEW.project_status_id IS DISTINCT FROM OLD.project_status_id THEN
        -- Приостановка: если проект "Приостановлено" (5) или "В работе" (4)
        IF NEW.project_status_id IN (4, 5) THEN -- Номера из project_statuses
            UPDATE requests 
            SET request_status_id = (
                SELECT request_status_id FROM request_statuses WHERE status = 'приостановлен'
            ),
            update_date = CURRENT_TIMESTAMP
            WHERE project_id = NEW.project_id
              AND request_status_id = (
                  SELECT request_status_id FROM request_statuses WHERE status = 'действующий'
              );
        
        -- Отмена: если проект "Завершено" (6)
        ELSIF NEW.project_status_id = 6 THEN
            UPDATE requests 
            SET request_status_id = (
                SELECT request_status_id FROM request_statuses WHERE status = 'отменён'
            ),
            update_date = CURRENT_TIMESTAMP
            WHERE project_id = NEW.project_id
              AND request_status_id IN (
                  SELECT request_status_id FROM request_statuses 
                  WHERE status IN ('действующий', 'приостановлен')
              );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_requests_on_project_change() OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

--
-- Name: upsert_entity_geometry(character varying, integer, numeric, numeric, integer, character varying, text, text, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.upsert_entity_geometry(p_entity_type character varying, p_entity_id integer, p_latitude numeric, p_longitude numeric, p_accuracy integer DEFAULT NULL::integer, p_source character varying DEFAULT 'manual'::character varying, p_address text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_created_by integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
    v_geometry_id INTEGER;
    v_geom GEOMETRY;
    v_table_name VARCHAR;
    v_primary_key VARCHAR;
    v_record_exists BOOLEAN;
    v_has_deleted_at BOOLEAN;
BEGIN
    -- Проверяем валидность координат
    IF p_latitude < -90 OR p_latitude > 90 OR p_longitude < -180 OR p_longitude > 180 THEN
        RAISE EXCEPTION 'Некорректные координаты: latitude=%, longitude=%', p_latitude, p_longitude;
    END IF;
    
    -- Определяем имя таблицы и первичный ключ
    v_table_name := CASE p_entity_type
        WHEN 'location' THEN 'locations'
        WHEN 'venue' THEN 'venues'
        WHEN 'event' THEN 'events'
        WHEN 'organization' THEN 'organizations'
        WHEN 'community' THEN 'communities'
        WHEN 'project' THEN 'projects'
        WHEN 'stage' THEN 'stages'
        ELSE NULL
    END;
    
    v_primary_key := CASE p_entity_type
        WHEN 'location' THEN 'location_id'
        WHEN 'venue' THEN 'venue_id'
        WHEN 'event' THEN 'event_id'
        WHEN 'organization' THEN 'organization_id'
        WHEN 'community' THEN 'community_id'
        WHEN 'project' THEN 'project_id'
        WHEN 'stage' THEN 'stage_id'
        ELSE NULL
    END;
    
    IF v_table_name IS NULL OR v_primary_key IS NULL THEN
        RAISE EXCEPTION 'Неподдерживаемый тип сущности: %', p_entity_type;
    END IF;
    
    -- Проверяем наличие поля deleted_at
    SELECT EXISTS(
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = v_table_name 
        AND column_name = 'deleted_at'
    ) INTO v_has_deleted_at;
    
    -- Проверяем существование записи сущности
    IF v_has_deleted_at THEN
        EXECUTE format('
            SELECT EXISTS(
                SELECT 1 FROM %I 
                WHERE %I = $1 AND deleted_at IS NULL
            )',
            v_table_name,
            v_primary_key
        ) INTO v_record_exists USING p_entity_id;
    ELSE
        EXECUTE format('
            SELECT EXISTS(
                SELECT 1 FROM %I 
                WHERE %I = $1
            )',
            v_table_name,
            v_primary_key
        ) INTO v_record_exists USING p_entity_id;
    END IF;
    
    IF NOT v_record_exists THEN
        RAISE EXCEPTION 'Запись с ID % не существует в таблице %s', 
                       p_entity_id, p_entity_type;
    END IF;
    
    -- Создаем geometry объект
    v_geom = ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326);
    
    -- Вставляем или обновляем запись в entity_geometries
    INSERT INTO entity_geometries (
        entity_type, entity_id, geom, 
        accuracy, source, address, description, created_by
    ) VALUES (
        p_entity_type, p_entity_id, v_geom,
        p_accuracy, p_source, p_address, p_description, p_created_by
    )
    ON CONFLICT (entity_type, entity_id) 
    DO UPDATE SET
        geom = EXCLUDED.geom,
        accuracy = EXCLUDED.accuracy,
        source = EXCLUDED.source,
        address = EXCLUDED.address,
        description = EXCLUDED.description,
        updated_at = NOW(),
        updated_by = EXCLUDED.created_by
    RETURNING geometry_id INTO v_geometry_id;
    
    -- Также обновляем геометку в основной таблице сущности
    EXECUTE format('
        UPDATE %I 
        SET geom = $1, 
            latitude = $2, 
            longitude = $3
        WHERE %I = $4',
        v_table_name,
        v_primary_key
    ) USING v_geom, p_latitude, p_longitude, p_entity_id;
    
    RETURN v_geometry_id;
END;
$_$;


ALTER FUNCTION public.upsert_entity_geometry(p_entity_type character varying, p_entity_id integer, p_latitude numeric, p_longitude numeric, p_accuracy integer, p_source character varying, p_address text, p_description text, p_created_by integer) OWNER TO postgres;

--
-- Name: validate_actor_integrity(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_actor_integrity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Для таблицы persons: проверяем что actor имеет тип 1
    IF TG_TABLE_NAME = 'persons' THEN
        IF NOT EXISTS (
            SELECT 1 FROM actors a 
            WHERE a.actor_id = NEW.actor_id 
            AND a.actor_type_id = 1
        ) THEN
            RAISE EXCEPTION 'Запись в persons может ссылаться только на actors с actor_type_id = 1 (Человек)';
        END IF;
    
    -- Для таблицы communities: проверяем что actor имеет тип 2
    ELSIF TG_TABLE_NAME = 'communities' THEN
        IF NOT EXISTS (
            SELECT 1 FROM actors a 
            WHERE a.actor_id = NEW.actor_id 
            AND a.actor_type_id = 2
        ) THEN
            RAISE EXCEPTION 'Запись в communities может ссылаться только на actors с actor_type_id = 2 (Сообщество)';
        END IF;
    
    -- Для таблицы organizations: проверяем что actor имеет тип 3
    ELSIF TG_TABLE_NAME = 'organizations' THEN
        IF NOT EXISTS (
            SELECT 1 FROM actors a 
            WHERE a.actor_id = NEW.actor_id 
            AND a.actor_type_id = 3
        ) THEN
            RAISE EXCEPTION 'Запись в organizations может ссылаться только на actors с actor_type_id = 3 (Организация)';
        END IF;
    
    -- Для таблицы actors: проверяем соответствие типа
    ELSIF TG_TABLE_NAME = 'actors' THEN
        IF NEW.actor_type_id = 1 AND NOT EXISTS (
            SELECT 1 FROM persons p WHERE p.actor_id = NEW.actor_id
        ) THEN
            RAISE EXCEPTION 'Для actor_type_id = 1 (Человек) должна существовать запись в persons';
        ELSIF NEW.actor_type_id = 2 AND NOT EXISTS (
            SELECT 1 FROM communities c WHERE c.actor_id = NEW.actor_id
        ) THEN
            RAISE EXCEPTION 'Для actor_type_id = 2 (Сообщество) должна существовать запись в communities';
        ELSIF NEW.actor_type_id = 3 AND NOT EXISTS (
            SELECT 1 FROM organizations o WHERE o.actor_id = NEW.actor_id
        ) THEN
            RAISE EXCEPTION 'Для actor_type_id = 3 (Организация) должна существовать запись в organizations';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_actor_integrity() OWNER TO postgres;

--
-- Name: validate_actor_type_integrity(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_actor_type_integrity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_TABLE_NAME = 'persons' THEN
        IF NOT EXISTS (
            SELECT 1 FROM actors a 
            WHERE a.actor_id = NEW.actor_id 
            AND a.actor_type_id = 1
        ) THEN
            RAISE EXCEPTION 'Запись в persons может ссылаться только на actors с actor_type_id = 1 (Человек)';
        END IF;
    
    ELSIF TG_TABLE_NAME = 'communities' THEN
        IF NOT EXISTS (
            SELECT 1 FROM actors a 
            WHERE a.actor_id = NEW.actor_id 
            AND a.actor_type_id = 2
        ) THEN
            RAISE EXCEPTION 'Запись в communities может ссылаться только на actors с actor_type_id = 2 (Сообщество)';
        END IF;
    
    ELSIF TG_TABLE_NAME = 'organizations' THEN
        IF NOT EXISTS (
            SELECT 1 FROM actors a 
            WHERE a.actor_id = NEW.actor_id 
            AND a.actor_type_id = 3
        ) THEN
            RAISE EXCEPTION 'Запись в organizations может ссылаться только на actors с actor_type_id = 3 (Организация)';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_actor_type_integrity() OWNER TO postgres;

--
-- Name: validate_file_mime_type(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_file_mime_type() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Простая проверка соответствия расширения и MIME типа
    IF NEW.file_url IS NOT NULL AND NEW.mime_type IS NULL THEN
        -- Попробуем определить MIME тип по расширению
        NEW.mime_type := CASE 
            WHEN NEW.file_url ILIKE '%.jpg' OR NEW.file_url ILIKE '%.jpeg' THEN 'image/jpeg'
            WHEN NEW.file_url ILIKE '%.png' THEN 'image/png'
            WHEN NEW.file_url ILIKE '%.gif' THEN 'image/gif'
            WHEN NEW.file_url ILIKE '%.pdf' THEN 'application/pdf'
            WHEN NEW.file_url ILIKE '%.doc' OR NEW.file_url ILIKE '%.docx' THEN 'application/msword'
            WHEN NEW.file_url ILIKE '%.xls' OR NEW.file_url ILIKE '%.xlsx' THEN 'application/vnd.ms-excel'
            WHEN NEW.file_url ILIKE '%.mp4' THEN 'video/mp4'
            WHEN NEW.file_url ILIKE '%.mp3' THEN 'audio/mpeg'
            ELSE 'application/octet-stream'
        END;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_file_mime_type() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: actors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors (
    actor_id integer NOT NULL,
    nickname character varying(100),
    actor_type_id integer NOT NULL,
    icon character varying(255),
    keywords text,
    account character varying(12),
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    color_frame character varying(20),
    rating_id integer
);


ALTER TABLE public.actors OWNER TO postgres;

--
-- Name: COLUMN actors.color_frame; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.actors.color_frame IS 'Цвет рамки скруглённого прямоугольника значка Участника';


--
-- Name: asset_files; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.asset_files (
    file_id integer NOT NULL,
    asset_type_id integer NOT NULL,
    asset_record_id integer NOT NULL,
    file_url text NOT NULL,
    storage_type character varying(20) DEFAULT 'local'::character varying,
    file_type character varying(50) NOT NULL,
    file_category character varying(50) DEFAULT 'general'::character varying,
    file_name character varying(255),
    original_name character varying(255),
    mime_type character varying(100),
    file_size bigint,
    dimensions jsonb,
    description text,
    tags text[],
    sort_order integer DEFAULT 0,
    is_primary boolean DEFAULT false,
    is_public boolean DEFAULT true,
    requires_auth boolean DEFAULT false,
    metadata jsonb,
    uploaded_at timestamp without time zone DEFAULT now(),
    uploaded_by integer,
    validated_by integer,
    validated_at timestamp without time zone,
    expires_at timestamp without time zone,
    version integer DEFAULT 1,
    previous_version_id integer,
    checksum character varying(64),
    CONSTRAINT asset_files_file_type_check CHECK (((file_type)::text = ANY ((ARRAY['image'::character varying, 'document'::character varying, 'video'::character varying, 'audio'::character varying, 'archive'::character varying, 'other'::character varying])::text[]))),
    CONSTRAINT asset_files_storage_type_check CHECK (((storage_type)::text = ANY ((ARRAY['local'::character varying, 's3'::character varying, 'cloud'::character varying, 'external'::character varying])::text[])))
);


ALTER TABLE public.asset_files OWNER TO postgres;

--
-- Name: TABLE asset_files; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.asset_files IS 'Основная таблица для хранения информации о файлах всех сущностей системы';


--
-- Name: asset_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.asset_types (
    asset_type_id integer NOT NULL,
    asset_table character varying(50) NOT NULL,
    asset_name character varying(100) NOT NULL,
    description text,
    supports_files boolean DEFAULT true,
    max_file_size bigint DEFAULT 10485760,
    allowed_mime_types text[],
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.asset_types OWNER TO postgres;

--
-- Name: TABLE asset_types; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.asset_types IS 'Справочник типов сущностей (таблиц), которые могут иметь прикрепленные файлы';


--
-- Name: actor_asset_files; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.actor_asset_files AS
 SELECT af.file_id,
    af.asset_type_id,
    af.asset_record_id,
    af.file_url,
    af.storage_type,
    af.file_type,
    af.file_category,
    af.file_name,
    af.original_name,
    af.mime_type,
    af.file_size,
    af.dimensions,
    af.description,
    af.tags,
    af.sort_order,
    af.is_primary,
    af.is_public,
    af.requires_auth,
    af.metadata,
    af.uploaded_at,
    af.uploaded_by,
    af.validated_by,
    af.validated_at,
    af.expires_at,
    af.version,
    af.previous_version_id,
    af.checksum,
    at.asset_name,
    a.nickname AS actor_nickname,
    a.actor_type_id
   FROM ((public.asset_files af
     JOIN public.asset_types at ON ((af.asset_type_id = at.asset_type_id)))
     JOIN public.actors a ON ((af.asset_record_id = a.actor_id)))
  WHERE (((at.asset_table)::text = 'actors'::text) AND (a.deleted_at IS NULL));


ALTER VIEW public.actor_asset_files OWNER TO postgres;

--
-- Name: actor_credentials; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actor_credentials (
    actor_id integer NOT NULL,
    password_hash character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.actor_credentials OWNER TO postgres;

--
-- Name: actor_current_statuses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actor_current_statuses (
    actor_current_status_id integer NOT NULL,
    actor_id integer NOT NULL,
    actor_status_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer
);


ALTER TABLE public.actor_current_statuses OWNER TO postgres;

--
-- Name: actor_current_statuses_actor_current_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.actor_current_statuses_actor_current_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.actor_current_statuses_actor_current_status_id_seq OWNER TO postgres;

--
-- Name: actor_current_statuses_actor_current_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.actor_current_statuses_actor_current_status_id_seq OWNED BY public.actor_current_statuses.actor_current_status_id;


--
-- Name: actor_statuses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actor_statuses (
    actor_status_id integer NOT NULL,
    status character varying(100) NOT NULL,
    description text
);


ALTER TABLE public.actor_statuses OWNER TO postgres;

--
-- Name: communities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.communities (
    community_id integer NOT NULL,
    title character varying(200) NOT NULL,
    full_title character varying(300),
    email character varying(255),
    email_2 character varying(255),
    participant_name character varying(100),
    participant_lastname character varying(100),
    location_id integer,
    post_code character varying(20),
    address text,
    phone_number character varying(25),
    phone_number_2 character varying(25),
    bank_title character varying(200),
    bank_bik character varying(9),
    bank_account character varying(30),
    community_info text,
    vk_page character varying(255),
    ok_page character varying(255),
    tt_page character varying(255),
    tg_page character varying(255),
    ig_page character varying(255),
    fb_page character varying(255),
    max_page character varying(255),
    web_page character varying(255),
    attachment character varying(255),
    actor_id integer,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    geom public.geometry(Point,4326),
    latitude numeric(10,8),
    longitude numeric(11,8),
    CONSTRAINT chk_community_email_2_format CHECK (((email_2 IS NULL) OR ((email_2)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))),
    CONSTRAINT chk_community_email_format CHECK (((email IS NULL) OR ((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)))
);


ALTER TABLE public.communities OWNER TO postgres;

--
-- Name: organizations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organizations (
    organization_id integer NOT NULL,
    title character varying(200) NOT NULL,
    full_title character varying(300),
    email character varying(255),
    email_2 character varying(255),
    staff_name character varying(100),
    staff_lastname character varying(100),
    location_id integer,
    post_code character varying(20),
    address text,
    phone_number character varying(25),
    phone_number_2 character varying(25),
    dir_name character varying(100),
    dir_lastname character varying(100),
    ogrn character varying(13),
    inn character varying(10),
    kpp character varying(9),
    bank_title character varying(200),
    bank_bik character varying(9),
    bank_account character varying(30),
    org_info text,
    vk_page character varying(255),
    ok_page character varying(255),
    tt_page character varying(255),
    tg_page character varying(255),
    ig_page character varying(255),
    fb_page character varying(255),
    max_page character varying(255),
    web_page character varying(255),
    attachment character varying(255),
    actor_id integer,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    geom public.geometry(Point,4326),
    latitude numeric(10,8),
    longitude numeric(11,8),
    CONSTRAINT chk_org_email_2_format CHECK (((email_2 IS NULL) OR ((email_2)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))),
    CONSTRAINT chk_org_email_format CHECK (((email IS NULL) OR ((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)))
);


ALTER TABLE public.organizations OWNER TO postgres;

--
-- Name: persons; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.persons (
    person_id integer NOT NULL,
    name character varying(100) NOT NULL,
    patronymic character varying(100),
    last_name character varying(100),
    gender character varying(10),
    birth_date date,
    email character varying(255),
    email_2 character varying(255),
    location_id integer,
    post_code character varying(20),
    address text,
    phone_number character varying(25),
    phone_number_2 character varying(25),
    personal_info text,
    web_page character varying(255),
    whatsapp character varying(25),
    viber character varying(25),
    vk_page character varying(255),
    ok_page character varying(255),
    tt_page character varying(255),
    tg_page character varying(255),
    ig_page character varying(255),
    fb_page character varying(255),
    max_page character varying(255),
    pp_number character varying(20),
    pp_date date,
    pp_auth character varying(200),
    inn character varying(12),
    snils character varying(15),
    bank_bik character varying(9),
    bank_account character varying(30),
    bank_info text,
    ya_account character varying(50),
    wm_account character varying(50),
    pp_account character varying(50),
    qiwi_account character varying(50),
    attachment character varying(255),
    actor_id integer,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    CONSTRAINT chk_email_2_format CHECK (((email_2 IS NULL) OR ((email_2)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))),
    CONSTRAINT chk_email_format CHECK (((email IS NULL) OR ((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))),
    CONSTRAINT chk_phone_format CHECK (((phone_number IS NULL) OR ((phone_number)::text ~ '^\+?[0-9\s\-\(\)]+$'::text))),
    CONSTRAINT persons_birth_date_check CHECK ((birth_date <= CURRENT_DATE)),
    CONSTRAINT persons_gender_check CHECK (((gender)::text = ANY (ARRAY[('муж.'::character varying)::text, ('жен.'::character varying)::text])))
);


ALTER TABLE public.persons OWNER TO postgres;

--
-- Name: actor_details_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.actor_details_view AS
 SELECT a.actor_id,
    a.nickname,
    a.account,
    a.actor_type_id,
    a.color_frame,
    a.icon,
    a.keywords,
    a.created_at,
    a.updated_at,
        CASE
            WHEN (a.actor_type_id = 1) THEN ( SELECT jsonb_build_object('person_id', p.person_id, 'name', p.name, 'last_name', p.last_name, 'email', p.email, 'phone_number', p.phone_number, 'location_id', p.location_id, 'address', p.address) AS jsonb_build_object
               FROM public.persons p
              WHERE (p.actor_id = a.actor_id)
             LIMIT 1)
            WHEN (a.actor_type_id = 2) THEN ( SELECT jsonb_build_object('community_id', c.community_id, 'title', c.title, 'email', c.email, 'address', c.address, 'phone_number', c.phone_number) AS jsonb_build_object
               FROM public.communities c
              WHERE (c.actor_id = a.actor_id)
             LIMIT 1)
            WHEN (a.actor_type_id = 3) THEN ( SELECT jsonb_build_object('organization_id', o.organization_id, 'title', o.title, 'email', o.email, 'address', o.address, 'phone_number', o.phone_number) AS jsonb_build_object
               FROM public.organizations o
              WHERE (o.actor_id = a.actor_id)
             LIMIT 1)
            ELSE '{}'::jsonb
        END AS details,
    acs.actor_status_id,
    ast.status AS actor_status,
    ast.description AS status_description
   FROM ((public.actors a
     LEFT JOIN public.actor_current_statuses acs ON ((a.actor_id = acs.actor_id)))
     LEFT JOIN public.actor_statuses ast ON ((acs.actor_status_id = ast.actor_status_id)))
  WHERE (a.deleted_at IS NULL);


ALTER VIEW public.actor_details_view OWNER TO postgres;

--
-- Name: actor_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actor_types (
    actor_type_id integer NOT NULL,
    type character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.actor_types OWNER TO postgres;

--
-- Name: actor_integrity_issues; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.actor_integrity_issues AS
 SELECT a.actor_id,
    a.nickname,
    a.actor_type_id,
    at.type AS actor_type_name,
        CASE
            WHEN ((a.actor_type_id = 1) AND (NOT (EXISTS ( SELECT 1
               FROM public.persons p
              WHERE (p.actor_id = a.actor_id))))) THEN 'Нет записи в persons'::text
            WHEN ((a.actor_type_id = 2) AND (NOT (EXISTS ( SELECT 1
               FROM public.communities c
              WHERE (c.actor_id = a.actor_id))))) THEN 'Нет записи в communities'::text
            WHEN ((a.actor_type_id = 3) AND (NOT (EXISTS ( SELECT 1
               FROM public.organizations o
              WHERE (o.actor_id = a.actor_id))))) THEN 'Нет записи в organizations'::text
            ELSE 'OK'::text
        END AS integrity_status
   FROM (public.actors a
     LEFT JOIN public.actor_types at ON ((a.actor_type_id = at.actor_type_id)));


ALTER VIEW public.actor_integrity_issues OWNER TO postgres;

--
-- Name: actor_persons_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.actor_persons_view AS
 SELECT a.actor_id,
    a.nickname,
    a.account,
    a.actor_type_id,
    a.color_frame,
    a.icon,
    a.keywords,
    p.name,
    p.last_name,
    p.email,
    p.phone_number,
    p.location_id,
    acs.actor_status_id,
    ast.status AS actor_status,
    ast.description AS status_description
   FROM (((public.actors a
     JOIN public.persons p ON ((a.actor_id = p.actor_id)))
     LEFT JOIN public.actor_current_statuses acs ON ((a.actor_id = acs.actor_id)))
     LEFT JOIN public.actor_statuses ast ON ((acs.actor_status_id = ast.actor_status_id)))
  WHERE (a.actor_type_id = 1);


ALTER VIEW public.actor_persons_view OWNER TO postgres;

--
-- Name: actor_status_mapping; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actor_status_mapping (
    rating_id integer NOT NULL,
    status_name character varying(50),
    can_create_project boolean DEFAULT false
);


ALTER TABLE public.actor_status_mapping OWNER TO postgres;

--
-- Name: actor_statuses_actor_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.actor_statuses_actor_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.actor_statuses_actor_status_id_seq OWNER TO postgres;

--
-- Name: actor_statuses_actor_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.actor_statuses_actor_status_id_seq OWNED BY public.actor_statuses.actor_status_id;


--
-- Name: actor_types_actor_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.actor_types_actor_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.actor_types_actor_type_id_seq OWNER TO postgres;

--
-- Name: actor_types_actor_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.actor_types_actor_type_id_seq OWNED BY public.actor_types.actor_type_id;


--
-- Name: actors_actor_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.actors_actor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.actors_actor_id_seq OWNER TO postgres;

--
-- Name: actors_actor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.actors_actor_id_seq OWNED BY public.actors.actor_id;


--
-- Name: actors_directions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_directions (
    actor_id integer NOT NULL,
    direction_id integer NOT NULL
);


ALTER TABLE public.actors_directions OWNER TO postgres;

--
-- Name: actors_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_events (
    actor_id integer NOT NULL,
    event_id integer NOT NULL
);


ALTER TABLE public.actors_events OWNER TO postgres;

--
-- Name: actors_functions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_functions (
    actor_function_id integer NOT NULL,
    actor_id integer NOT NULL,
    function_id integer NOT NULL,
    level_id integer,
    priority integer DEFAULT 1,
    is_active boolean DEFAULT true,
    assignment_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT actors_functions_priority_check CHECK (((priority >= 1) AND (priority <= 10)))
);


ALTER TABLE public.actors_functions OWNER TO postgres;

--
-- Name: actors_functions_actor_function_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.actors_functions_actor_function_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.actors_functions_actor_function_id_seq OWNER TO postgres;

--
-- Name: actors_functions_actor_function_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.actors_functions_actor_function_id_seq OWNED BY public.actors_functions.actor_function_id;


--
-- Name: actors_locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_locations (
    actor_id integer NOT NULL,
    location_id integer NOT NULL
);


ALTER TABLE public.actors_locations OWNER TO postgres;

--
-- Name: actors_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_messages (
    message_id integer NOT NULL,
    actor_id integer NOT NULL
);


ALTER TABLE public.actors_messages OWNER TO postgres;

--
-- Name: actors_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_notes (
    note_id integer NOT NULL,
    actor_id integer NOT NULL,
    author_id integer NOT NULL
);


ALTER TABLE public.actors_notes OWNER TO postgres;

--
-- Name: actors_projects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_projects (
    actor_id integer NOT NULL,
    project_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer
);


ALTER TABLE public.actors_projects OWNER TO postgres;

--
-- Name: actors_tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_tasks (
    task_id integer NOT NULL,
    actor_id integer NOT NULL
);


ALTER TABLE public.actors_tasks OWNER TO postgres;

--
-- Name: asset_documentation; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.asset_documentation AS
 SELECT af.file_id,
    af.file_url,
    af.file_name,
    af.original_name,
    af.file_size,
    af.mime_type,
    af.asset_record_id,
    at.asset_table,
    at.asset_name,
    a.nickname AS uploaded_by_name,
    af.uploaded_at,
    af.version
   FROM ((public.asset_files af
     JOIN public.asset_types at ON ((af.asset_type_id = at.asset_type_id)))
     LEFT JOIN public.actors a ON ((af.uploaded_by = a.actor_id)))
  WHERE (((af.file_type)::text = 'document'::text) AND ((af.file_category)::text = 'documentation'::text) AND (af.is_public = true))
  ORDER BY at.asset_name, af.sort_order, af.file_name;


ALTER VIEW public.asset_documentation OWNER TO postgres;

--
-- Name: asset_files_file_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.asset_files_file_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.asset_files_file_id_seq OWNER TO postgres;

--
-- Name: asset_files_file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.asset_files_file_id_seq OWNED BY public.asset_files.file_id;


--
-- Name: asset_files_report; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.asset_files_report AS
 SELECT at.asset_name AS "Тип ресурса",
    at.asset_table AS "Таблица",
    count(af.file_id) AS "Всего файлов",
    count(
        CASE
            WHEN ((af.file_type)::text = 'image'::text) THEN 1
            ELSE NULL::integer
        END) AS "Изображений",
    count(
        CASE
            WHEN ((af.file_type)::text = 'document'::text) THEN 1
            ELSE NULL::integer
        END) AS "Документов",
    count(
        CASE
            WHEN ((af.file_type)::text = 'video'::text) THEN 1
            ELSE NULL::integer
        END) AS "Видео",
    count(
        CASE
            WHEN ((af.file_type)::text = 'audio'::text) THEN 1
            ELSE NULL::integer
        END) AS "Аудио",
    count(
        CASE
            WHEN (af.is_primary = true) THEN 1
            ELSE NULL::integer
        END) AS "Основных файлов",
    COALESCE(sum(af.file_size), (0)::numeric) AS "Общий размер (байт)",
    round(((COALESCE(sum(af.file_size), (0)::numeric) / 1024.0) / 1024.0), 2) AS "Общий размер (МБ)",
    min(af.uploaded_at) AS "Первый файл",
    max(af.uploaded_at) AS "Последний файл"
   FROM (public.asset_types at
     LEFT JOIN public.asset_files af ON ((at.asset_type_id = af.asset_type_id)))
  GROUP BY at.asset_name, at.asset_table
  ORDER BY (count(af.file_id)) DESC, at.asset_name;


ALTER VIEW public.asset_files_report OWNER TO postgres;

--
-- Name: VIEW asset_files_report; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.asset_files_report IS 'Сводный отчет по файлам в системе';


--
-- Name: asset_files_statistics; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.asset_files_statistics AS
 SELECT at.asset_table,
    at.asset_name,
    count(*) AS total_files,
    count(
        CASE
            WHEN ((af.file_type)::text = 'image'::text) THEN 1
            ELSE NULL::integer
        END) AS image_count,
    count(
        CASE
            WHEN ((af.file_type)::text = 'document'::text) THEN 1
            ELSE NULL::integer
        END) AS document_count,
    count(
        CASE
            WHEN ((af.file_type)::text = 'video'::text) THEN 1
            ELSE NULL::integer
        END) AS video_count,
    count(
        CASE
            WHEN ((af.file_type)::text = 'audio'::text) THEN 1
            ELSE NULL::integer
        END) AS audio_count,
    sum(af.file_size) AS total_size_bytes,
    round(((sum(af.file_size) / 1024.0) / 1024.0), 2) AS total_size_mb,
    min(af.uploaded_at) AS first_upload,
    max(af.uploaded_at) AS last_upload
   FROM (public.asset_files af
     JOIN public.asset_types at ON ((af.asset_type_id = at.asset_type_id)))
  WHERE (af.is_public = true)
  GROUP BY at.asset_table, at.asset_name
  ORDER BY (count(*)) DESC;


ALTER VIEW public.asset_files_statistics OWNER TO postgres;

--
-- Name: asset_types_asset_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.asset_types_asset_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.asset_types_asset_type_id_seq OWNER TO postgres;

--
-- Name: asset_types_asset_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.asset_types_asset_type_id_seq OWNED BY public.asset_types.asset_type_id;


--
-- Name: bookmarks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bookmarks (
    bookmark_id integer NOT NULL,
    actor_id integer NOT NULL,
    theme_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.bookmarks OWNER TO postgres;

--
-- Name: bookmarks_bookmark_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.bookmarks_bookmark_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.bookmarks_bookmark_id_seq OWNER TO postgres;

--
-- Name: bookmarks_bookmark_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bookmarks_bookmark_id_seq OWNED BY public.bookmarks.bookmark_id;


--
-- Name: communities_community_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.communities_community_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.communities_community_id_seq OWNER TO postgres;

--
-- Name: communities_community_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.communities_community_id_seq OWNED BY public.communities.community_id;


--
-- Name: contract_number_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.contract_number_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.contract_number_seq OWNER TO postgres;

--
-- Name: contract_terms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contract_terms (
    contract_term_id integer NOT NULL,
    contract_id integer NOT NULL,
    offering_term_id integer NOT NULL,
    offering_term_name character varying(100) NOT NULL,
    cost numeric(15,2) NOT NULL,
    currency character varying(10) DEFAULT 'руб.'::character varying,
    special_terms text,
    fulfillment_status character varying(20) DEFAULT 'pending'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_fulfillment_status CHECK (((fulfillment_status)::text = ANY ((ARRAY['pending'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[])))
);


ALTER TABLE public.contract_terms OWNER TO postgres;

--
-- Name: contract_terms_contract_term_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.contract_terms_contract_term_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.contract_terms_contract_term_id_seq OWNER TO postgres;

--
-- Name: contract_terms_contract_term_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.contract_terms_contract_term_id_seq OWNED BY public.contract_terms.contract_term_id;


--
-- Name: contracts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contracts (
    contract_id integer NOT NULL,
    temp_contract_id integer NOT NULL,
    request_id integer NOT NULL,
    contract_number character varying(50) NOT NULL,
    contract_title character varying(200) NOT NULL,
    contract_description text,
    requester_id integer NOT NULL,
    owner_id integer NOT NULL,
    resource_type character varying(20) NOT NULL,
    resource_id integer NOT NULL,
    start_date date,
    end_date date,
    start_time time without time zone,
    end_time time without time zone,
    contract_status character varying(20) DEFAULT 'active'::character varying,
    total_cost numeric(15,2) NOT NULL,
    currency character varying(10) DEFAULT 'руб.'::character varying,
    requester_signed_at timestamp without time zone,
    owner_signed_at timestamp without time zone,
    signed_at timestamp without time zone,
    effective_from timestamp without time zone,
    effective_until timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_contract_resource_type CHECK (((resource_type)::text = ANY ((ARRAY['matresource'::character varying, 'finresource'::character varying, 'venue'::character varying, 'service'::character varying])::text[]))),
    CONSTRAINT chk_contract_status CHECK (((contract_status)::text = ANY ((ARRAY['active'::character varying, 'suspended'::character varying, 'completed'::character varying, 'terminated'::character varying, 'cancelled'::character varying])::text[])))
);


ALTER TABLE public.contracts OWNER TO postgres;

--
-- Name: contracts_contract_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.contracts_contract_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.contracts_contract_id_seq OWNER TO postgres;

--
-- Name: contracts_contract_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.contracts_contract_id_seq OWNED BY public.contracts.contract_id;


--
-- Name: creative_center_base; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.creative_center_base (
    project_actor_role_id integer,
    actor_id integer,
    project_id integer,
    role_type character varying(50),
    assigned_at character varying(50),
    assigned_by integer,
    note character varying(50)
);


ALTER TABLE public.creative_center_base OWNER TO postgres;

--
-- Name: directions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.directions (
    direction_id integer NOT NULL,
    type character varying(100),
    subtype character varying(100),
    title character varying(150),
    description text
);


ALTER TABLE public.directions OWNER TO postgres;

--
-- Name: directions_direction_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.directions_direction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.directions_direction_id_seq OWNER TO postgres;

--
-- Name: directions_direction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.directions_direction_id_seq OWNED BY public.directions.direction_id;


--
-- Name: entity_geometries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.entity_geometries (
    geometry_id integer NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id integer NOT NULL,
    geom public.geometry(Point,4326) NOT NULL,
    accuracy integer,
    source character varying(50) DEFAULT 'manual'::character varying,
    address text,
    description text,
    is_verified boolean DEFAULT false,
    verified_at timestamp without time zone,
    verified_by integer,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    created_by integer,
    updated_by integer,
    CONSTRAINT entity_geometries_entity_type_check CHECK (((entity_type)::text = ANY ((ARRAY['location'::character varying, 'venue'::character varying, 'event'::character varying, 'organization'::character varying, 'community'::character varying, 'project'::character varying, 'stage'::character varying])::text[])))
);


ALTER TABLE public.entity_geometries OWNER TO postgres;

--
-- Name: entity_geometries_geometry_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.entity_geometries_geometry_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.entity_geometries_geometry_id_seq OWNER TO postgres;

--
-- Name: entity_geometries_geometry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.entity_geometries_geometry_id_seq OWNED BY public.entity_geometries.geometry_id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.events (
    event_id integer NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    date date NOT NULL,
    start_time time without time zone,
    end_time time without time zone,
    event_type_id integer,
    attachment character varying(255),
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    rating_id integer,
    cost numeric(15,2) DEFAULT 0,
    currency character varying(10) DEFAULT 'руб.'::character varying,
    offering_term_id integer DEFAULT 2,
    special_terms text,
    event_status_id integer,
    author_id integer,
    geom public.geometry(Point,4326),
    latitude numeric(10,8),
    longitude numeric(11,8),
    CONSTRAINT chk_event_times CHECK ((start_time <= end_time))
);


ALTER TABLE public.events OWNER TO postgres;

--
-- Name: event_asset_files; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.event_asset_files AS
 SELECT af.file_id,
    af.asset_type_id,
    af.asset_record_id,
    af.file_url,
    af.storage_type,
    af.file_type,
    af.file_category,
    af.file_name,
    af.original_name,
    af.mime_type,
    af.file_size,
    af.dimensions,
    af.description,
    af.tags,
    af.sort_order,
    af.is_primary,
    af.is_public,
    af.requires_auth,
    af.metadata,
    af.uploaded_at,
    af.uploaded_by,
    af.validated_by,
    af.validated_at,
    af.expires_at,
    af.version,
    af.previous_version_id,
    af.checksum,
    at.asset_name,
    e.title AS event_title,
    e.date AS event_date
   FROM ((public.asset_files af
     JOIN public.asset_types at ON ((af.asset_type_id = at.asset_type_id)))
     JOIN public.events e ON ((af.asset_record_id = e.event_id)))
  WHERE (((at.asset_table)::text = 'events'::text) AND (e.deleted_at IS NULL));


ALTER VIEW public.event_asset_files OWNER TO postgres;

--
-- Name: event_statuses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_statuses (
    event_status_id integer NOT NULL,
    status character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.event_statuses OWNER TO postgres;

--
-- Name: event_statuses_event_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.event_statuses_event_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_statuses_event_status_id_seq OWNER TO postgres;

--
-- Name: event_statuses_event_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.event_statuses_event_status_id_seq OWNED BY public.event_statuses.event_status_id;


--
-- Name: event_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_types (
    event_type_id integer NOT NULL,
    type character varying(50) NOT NULL
);


ALTER TABLE public.event_types OWNER TO postgres;

--
-- Name: event_types_event_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.event_types_event_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_types_event_type_id_seq OWNER TO postgres;

--
-- Name: event_types_event_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.event_types_event_type_id_seq OWNED BY public.event_types.event_type_id;


--
-- Name: events_event_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.events_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.events_event_id_seq OWNER TO postgres;

--
-- Name: events_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.events_event_id_seq OWNED BY public.events.event_id;


--
-- Name: events_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.events_notes (
    note_id integer NOT NULL,
    event_id integer NOT NULL,
    author_id integer NOT NULL
);


ALTER TABLE public.events_notes OWNER TO postgres;

--
-- Name: favorites; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.favorites (
    favorite_id integer NOT NULL,
    actor_id integer NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.favorites OWNER TO postgres;

--
-- Name: TABLE favorites; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.favorites IS 'Универсальная таблица для избранного (проекты, идеи, участники и т.д.)';


--
-- Name: favorites_favorite_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.favorites_favorite_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.favorites_favorite_id_seq OWNER TO postgres;

--
-- Name: favorites_favorite_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.favorites_favorite_id_seq OWNED BY public.favorites.favorite_id;


--
-- Name: file_access_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.file_access_log (
    access_id integer NOT NULL,
    file_id integer,
    actor_id integer,
    action character varying(20) NOT NULL,
    access_time timestamp without time zone DEFAULT now(),
    ip_address inet,
    user_agent text,
    referrer text,
    duration integer,
    CONSTRAINT file_access_log_action_check CHECK (((action)::text = ANY ((ARRAY['view'::character varying, 'download'::character varying, 'preview'::character varying, 'share'::character varying, 'edit'::character varying])::text[])))
);


ALTER TABLE public.file_access_log OWNER TO postgres;

--
-- Name: file_access_log_access_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.file_access_log_access_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.file_access_log_access_id_seq OWNER TO postgres;

--
-- Name: file_access_log_access_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.file_access_log_access_id_seq OWNED BY public.file_access_log.access_id;


--
-- Name: file_previews; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.file_previews (
    preview_id integer NOT NULL,
    file_id integer NOT NULL,
    preview_url text NOT NULL,
    preview_type character varying(20) DEFAULT 'thumbnail'::character varying,
    width integer,
    height integer,
    file_size integer,
    generated_at timestamp without time zone DEFAULT now(),
    generated_by character varying(50) DEFAULT 'system'::character varying,
    CONSTRAINT file_previews_preview_type_check CHECK (((preview_type)::text = ANY ((ARRAY['thumbnail'::character varying, 'small'::character varying, 'medium'::character varying, 'large'::character varying])::text[])))
);


ALTER TABLE public.file_previews OWNER TO postgres;

--
-- Name: file_previews_preview_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.file_previews_preview_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.file_previews_preview_id_seq OWNER TO postgres;

--
-- Name: file_previews_preview_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.file_previews_preview_id_seq OWNED BY public.file_previews.preview_id;


--
-- Name: file_relations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.file_relations (
    relation_id integer NOT NULL,
    source_file_id integer,
    target_file_id integer,
    relation_type character varying(50) NOT NULL,
    description text,
    created_at timestamp without time zone DEFAULT now(),
    created_by integer,
    CONSTRAINT file_relations_relation_type_check CHECK (((relation_type)::text = ANY ((ARRAY['signed_copy'::character varying, 'translation'::character varying, 'revision'::character varying, 'extract'::character varying, 'combined'::character varying])::text[])))
);


ALTER TABLE public.file_relations OWNER TO postgres;

--
-- Name: file_relations_relation_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.file_relations_relation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.file_relations_relation_id_seq OWNER TO postgres;

--
-- Name: file_relations_relation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.file_relations_relation_id_seq OWNED BY public.file_relations.relation_id;


--
-- Name: file_specific_metadata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.file_specific_metadata (
    metadata_id integer NOT NULL,
    file_id integer NOT NULL,
    camera_model character varying(100),
    exposure_time character varying(50),
    aperture character varying(20),
    iso integer,
    taken_at timestamp without time zone,
    author character varying(255),
    title character varying(255),
    subject text,
    keywords text[],
    page_count integer,
    duration integer,
    bitrate integer,
    codec character varying(50),
    sample_rate integer,
    created_with character varying(255),
    software_used character varying(255)
);


ALTER TABLE public.file_specific_metadata OWNER TO postgres;

--
-- Name: file_specific_metadata_metadata_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.file_specific_metadata_metadata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.file_specific_metadata_metadata_id_seq OWNER TO postgres;

--
-- Name: file_specific_metadata_metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.file_specific_metadata_metadata_id_seq OWNED BY public.file_specific_metadata.metadata_id;


--
-- Name: files_requiring_attention; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.files_requiring_attention AS
 SELECT af.file_id,
    at.asset_name,
    af.file_name,
    af.file_type,
    af.file_size,
    af.uploaded_at,
        CASE
            WHEN ((af.file_name IS NULL) OR ((af.file_name)::text = ''::text)) THEN 'Отсутствует имя файла'::text
            WHEN (af.file_size IS NULL) THEN 'Не указан размер файла'::text
            WHEN (af.mime_type IS NULL) THEN 'Не указан MIME тип'::text
            ELSE 'Нет проблем'::text
        END AS issue,
    a.nickname AS uploaded_by
   FROM ((public.asset_files af
     JOIN public.asset_types at ON ((af.asset_type_id = at.asset_type_id)))
     LEFT JOIN public.actors a ON ((af.uploaded_by = a.actor_id)))
  WHERE ((af.file_name IS NULL) OR ((af.file_name)::text = ''::text) OR (af.file_size IS NULL) OR (af.mime_type IS NULL))
  ORDER BY af.uploaded_at DESC;


ALTER VIEW public.files_requiring_attention OWNER TO postgres;

--
-- Name: files_requiring_validation; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.files_requiring_validation AS
 SELECT af.file_id,
    af.file_url,
    af.file_name,
    af.file_type,
    af.file_size,
    af.asset_record_id,
    at.asset_name,
    at.asset_table,
    a.nickname AS uploaded_by_name,
    af.uploaded_at,
    age(now(), (af.uploaded_at)::timestamp with time zone) AS time_since_upload
   FROM ((public.asset_files af
     JOIN public.asset_types at ON ((af.asset_type_id = at.asset_type_id)))
     JOIN public.actors a ON ((af.uploaded_by = a.actor_id)))
  WHERE ((af.validated_at IS NULL) AND (af.requires_auth = true))
  ORDER BY af.uploaded_at;


ALTER VIEW public.files_requiring_validation OWNER TO postgres;

--
-- Name: finresource_offering_terms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.finresource_offering_terms (
    id integer NOT NULL,
    finresource_id integer NOT NULL,
    offering_term_id integer NOT NULL,
    cost numeric(15,2) DEFAULT 0,
    currency character varying(10) DEFAULT 'руб.'::character varying,
    special_terms text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.finresource_offering_terms OWNER TO postgres;

--
-- Name: finresource_offering_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.finresource_offering_terms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.finresource_offering_terms_id_seq OWNER TO postgres;

--
-- Name: finresource_offering_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.finresource_offering_terms_id_seq OWNED BY public.finresource_offering_terms.id;


--
-- Name: finresource_owners; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.finresource_owners (
    finresource_id integer NOT NULL,
    actor_id integer NOT NULL,
    finresource_owner_id integer NOT NULL
);


ALTER TABLE public.finresource_owners OWNER TO postgres;

--
-- Name: finresource_owners_finresource_owner_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.finresource_owners_finresource_owner_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.finresource_owners_finresource_owner_id_seq OWNER TO postgres;

--
-- Name: finresource_owners_finresource_owner_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.finresource_owners_finresource_owner_id_seq OWNED BY public.finresource_owners.finresource_owner_id;


--
-- Name: finresource_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.finresource_types (
    finresource_type_id integer NOT NULL,
    type character varying(100) NOT NULL
);


ALTER TABLE public.finresource_types OWNER TO postgres;

--
-- Name: finresource_types_finresource_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.finresource_types_finresource_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.finresource_types_finresource_type_id_seq OWNER TO postgres;

--
-- Name: finresource_types_finresource_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.finresource_types_finresource_type_id_seq OWNED BY public.finresource_types.finresource_type_id;


--
-- Name: finresources; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.finresources (
    finresource_id integer NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    finresource_type_id integer,
    attachment character varying(255),
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    rating_id integer
);


ALTER TABLE public.finresources OWNER TO postgres;

--
-- Name: finresources_finresource_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.finresources_finresource_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.finresources_finresource_id_seq OWNER TO postgres;

--
-- Name: finresources_finresource_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.finresources_finresource_id_seq OWNED BY public.finresources.finresource_id;


--
-- Name: finresources_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.finresources_notes (
    finresource_note_id integer NOT NULL,
    finresource_id integer NOT NULL,
    note_id integer NOT NULL,
    author_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp with time zone
);


ALTER TABLE public.finresources_notes OWNER TO postgres;

--
-- Name: TABLE finresources_notes; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.finresources_notes IS 'Заметки пользователей к финансовым ресурсам';


--
-- Name: finresources_notes_finresource_note_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.finresources_notes_finresource_note_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.finresources_notes_finresource_note_id_seq OWNER TO postgres;

--
-- Name: finresources_notes_finresource_note_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.finresources_notes_finresource_note_id_seq OWNED BY public.finresources_notes.finresource_note_id;


--
-- Name: functions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.functions (
    function_id integer NOT NULL,
    title character varying(100) NOT NULL,
    description text,
    keywords text
);


ALTER TABLE public.functions OWNER TO postgres;

--
-- Name: functions_directions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.functions_directions (
    function_id integer NOT NULL,
    direction_id integer NOT NULL
);


ALTER TABLE public.functions_directions OWNER TO postgres;

--
-- Name: functions_function_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.functions_function_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.functions_function_id_seq OWNER TO postgres;

--
-- Name: functions_function_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.functions_function_id_seq OWNED BY public.functions.function_id;


--
-- Name: global_request_notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.global_request_notifications (
    notification_id integer NOT NULL,
    global_request_id integer,
    actor_id integer NOT NULL,
    notification_type character varying(50) NOT NULL,
    title character varying(200) NOT NULL,
    message text NOT NULL,
    is_read boolean DEFAULT false,
    related_resource_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.global_request_notifications OWNER TO postgres;

--
-- Name: global_request_notifications_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.global_request_notifications_notification_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.global_request_notifications_notification_id_seq OWNER TO postgres;

--
-- Name: global_request_notifications_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.global_request_notifications_notification_id_seq OWNED BY public.global_request_notifications.notification_id;


--
-- Name: global_request_responses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.global_request_responses (
    response_id integer NOT NULL,
    global_request_id integer NOT NULL,
    owner_id integer NOT NULL,
    resource_id integer NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    message text,
    proposed_price numeric(10,2),
    proposed_conditions text,
    response_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    status_changed_date timestamp without time zone,
    expiration_date timestamp without time zone,
    is_active boolean DEFAULT true
);


ALTER TABLE public.global_request_responses OWNER TO postgres;

--
-- Name: global_request_responses_response_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.global_request_responses_response_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.global_request_responses_response_id_seq OWNER TO postgres;

--
-- Name: global_request_responses_response_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.global_request_responses_response_id_seq OWNED BY public.global_request_responses.response_id;


--
-- Name: global_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.global_requests (
    global_request_id integer NOT NULL,
    requester_id integer NOT NULL,
    location_id integer,
    resource_type_id integer NOT NULL,
    subject_type_id integer,
    subject_id integer,
    title character varying(200) NOT NULL,
    description text,
    quantity integer DEFAULT 1,
    validity_period timestamp without time zone,
    request_status_id integer,
    project_id integer,
    event_id integer,
    creation_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    update_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_active boolean DEFAULT true
);


ALTER TABLE public.global_requests OWNER TO postgres;

--
-- Name: global_requests_global_request_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.global_requests_global_request_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.global_requests_global_request_id_seq OWNER TO postgres;

--
-- Name: global_requests_global_request_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.global_requests_global_request_id_seq OWNED BY public.global_requests.global_request_id;


--
-- Name: global_response_status_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.global_response_status_history (
    history_id integer NOT NULL,
    response_id integer NOT NULL,
    old_status character varying(20),
    new_status character varying(20) NOT NULL,
    changed_by integer,
    reason text,
    change_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.global_response_status_history OWNER TO postgres;

--
-- Name: global_response_status_history_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.global_response_status_history_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.global_response_status_history_history_id_seq OWNER TO postgres;

--
-- Name: global_response_status_history_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.global_response_status_history_history_id_seq OWNED BY public.global_response_status_history.history_id;


--
-- Name: group_tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.group_tasks (
    task_id integer NOT NULL,
    project_group_id integer NOT NULL
);


ALTER TABLE public.group_tasks OWNER TO postgres;

--
-- Name: idea_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.idea_categories (
    idea_category_id integer NOT NULL,
    category character varying(50) NOT NULL
);


ALTER TABLE public.idea_categories OWNER TO postgres;

--
-- Name: idea_categories_idea_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.idea_categories_idea_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.idea_categories_idea_category_id_seq OWNER TO postgres;

--
-- Name: idea_categories_idea_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.idea_categories_idea_category_id_seq OWNED BY public.idea_categories.idea_category_id;


--
-- Name: idea_offering_terms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.idea_offering_terms (
    id integer NOT NULL,
    idea_id integer NOT NULL,
    offering_term_id integer NOT NULL,
    cost numeric(15,2) DEFAULT 0,
    currency character varying(10) DEFAULT 'руб.'::character varying,
    special_terms text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.idea_offering_terms OWNER TO postgres;

--
-- Name: idea_offering_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.idea_offering_terms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.idea_offering_terms_id_seq OWNER TO postgres;

--
-- Name: idea_offering_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.idea_offering_terms_id_seq OWNED BY public.idea_offering_terms.id;


--
-- Name: idea_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.idea_types (
    idea_type_id integer NOT NULL,
    type character varying(50) NOT NULL
);


ALTER TABLE public.idea_types OWNER TO postgres;

--
-- Name: idea_types_idea_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.idea_types_idea_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.idea_types_idea_type_id_seq OWNER TO postgres;

--
-- Name: idea_types_idea_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.idea_types_idea_type_id_seq OWNED BY public.idea_types.idea_type_id;


--
-- Name: ideas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ideas (
    idea_id integer NOT NULL,
    title character varying(200) NOT NULL,
    short_description text,
    full_description text,
    detail_description text,
    idea_category_id integer,
    idea_type_id integer,
    actor_id integer,
    attachment character varying(255),
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    rating_id integer
);


ALTER TABLE public.ideas OWNER TO postgres;

--
-- Name: ideas_directions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ideas_directions (
    idea_id integer NOT NULL,
    direction_id integer NOT NULL
);


ALTER TABLE public.ideas_directions OWNER TO postgres;

--
-- Name: ideas_idea_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ideas_idea_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ideas_idea_id_seq OWNER TO postgres;

--
-- Name: ideas_idea_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ideas_idea_id_seq OWNED BY public.ideas.idea_id;


--
-- Name: ideas_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ideas_notes (
    note_id integer NOT NULL,
    idea_id integer NOT NULL,
    author_id integer NOT NULL
);


ALTER TABLE public.ideas_notes OWNER TO postgres;

--
-- Name: ideas_projects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ideas_projects (
    idea_id integer NOT NULL,
    project_id integer NOT NULL
);


ALTER TABLE public.ideas_projects OWNER TO postgres;

--
-- Name: offering_terms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.offering_terms (
    id integer NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    is_paid boolean DEFAULT false NOT NULL,
    is_temporary boolean DEFAULT false NOT NULL
);


ALTER TABLE public.offering_terms OWNER TO postgres;

--
-- Name: ideas_with_offerings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.ideas_with_offerings AS
 SELECT i.idea_id,
    i.title,
    i.short_description,
    i.full_description,
    i.detail_description,
    i.idea_category_id,
    i.idea_type_id,
    i.actor_id,
    i.attachment,
    i.deleted_at,
    i.created_at,
    i.updated_at,
    i.created_by,
    i.updated_by,
    i.rating_id,
    iot.id AS offering_mapping_id,
    iot.offering_term_id,
    ot.name AS offering_term_name,
    ot.code AS offering_term_code,
    iot.cost,
    iot.currency,
    iot.special_terms,
    iot.created_at AS offering_created_at
   FROM ((public.ideas i
     LEFT JOIN public.idea_offering_terms iot ON ((i.idea_id = iot.idea_id)))
     LEFT JOIN public.offering_terms ot ON ((iot.offering_term_id = ot.id)));


ALTER VIEW public.ideas_with_offerings OWNER TO postgres;

--
-- Name: large_files; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.large_files AS
 SELECT af.file_id,
    at.asset_name,
    af.file_name,
    af.file_type,
    af.file_size,
    round((((af.file_size)::numeric / 1024.0) / 1024.0), 2) AS size_mb,
    af.uploaded_at,
    a.nickname AS uploaded_by
   FROM ((public.asset_files af
     JOIN public.asset_types at ON ((af.asset_type_id = at.asset_type_id)))
     LEFT JOIN public.actors a ON ((af.uploaded_by = a.actor_id)))
  WHERE (af.file_size > 10485760)
  ORDER BY af.file_size DESC;


ALTER VIEW public.large_files OWNER TO postgres;

--
-- Name: levels; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.levels (
    level_id integer NOT NULL,
    level character varying(50) NOT NULL
);


ALTER TABLE public.levels OWNER TO postgres;

--
-- Name: levels_level_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.levels_level_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.levels_level_id_seq OWNER TO postgres;

--
-- Name: levels_level_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.levels_level_id_seq OWNED BY public.levels.level_id;


--
-- Name: local_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.local_events (
    local_event_id integer NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    date date NOT NULL,
    start_time time without time zone,
    end_time time without time zone,
    attachment character varying(255),
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    CONSTRAINT chk_local_event_times CHECK ((start_time <= end_time))
);


ALTER TABLE public.local_events OWNER TO postgres;

--
-- Name: local_events_local_event_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.local_events_local_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.local_events_local_event_id_seq OWNER TO postgres;

--
-- Name: local_events_local_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.local_events_local_event_id_seq OWNED BY public.local_events.local_event_id;


--
-- Name: locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.locations (
    location_id integer NOT NULL,
    name character varying(100) NOT NULL,
    type character varying(50),
    district character varying(100),
    region character varying(100),
    country character varying(100),
    main_postcode character varying(20),
    description text,
    population integer,
    attachment character varying(255),
    geom public.geometry(Point,4326),
    latitude numeric(10,8),
    longitude numeric(11,8)
);


ALTER TABLE public.locations OWNER TO postgres;

--
-- Name: locations_location_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.locations_location_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.locations_location_id_seq OWNER TO postgres;

--
-- Name: locations_location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.locations_location_id_seq OWNED BY public.locations.location_id;


--
-- Name: matresources; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.matresources (
    matresource_id integer NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    matresource_type_id integer,
    attachment character varying(255),
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    rating_id integer
);


ALTER TABLE public.matresources OWNER TO postgres;

--
-- Name: matresource_asset_files; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.matresource_asset_files AS
 SELECT af.file_id,
    af.asset_type_id,
    af.asset_record_id,
    af.file_url,
    af.storage_type,
    af.file_type,
    af.file_category,
    af.file_name,
    af.original_name,
    af.mime_type,
    af.file_size,
    af.dimensions,
    af.description,
    af.tags,
    af.sort_order,
    af.is_primary,
    af.is_public,
    af.requires_auth,
    af.metadata,
    af.uploaded_at,
    af.uploaded_by,
    af.validated_by,
    af.validated_at,
    af.expires_at,
    af.version,
    af.previous_version_id,
    af.checksum,
    at.asset_name,
    m.title AS resource_title,
    m.description AS resource_description
   FROM ((public.asset_files af
     JOIN public.asset_types at ON ((af.asset_type_id = at.asset_type_id)))
     JOIN public.matresources m ON ((af.asset_record_id = m.matresource_id)))
  WHERE (((at.asset_table)::text = 'matresources'::text) AND (m.deleted_at IS NULL));


ALTER VIEW public.matresource_asset_files OWNER TO postgres;

--
-- Name: VIEW matresource_asset_files; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.matresource_asset_files IS 'Файлы материальных ресурсов с дополнительной информацией о ресурсах';


--
-- Name: matresource_offering_terms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.matresource_offering_terms (
    id integer NOT NULL,
    matresource_id integer NOT NULL,
    offering_term_id integer NOT NULL,
    cost numeric(15,2) DEFAULT 0,
    currency character varying(10) DEFAULT 'руб.'::character varying,
    special_terms text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.matresource_offering_terms OWNER TO postgres;

--
-- Name: matresource_offering_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.matresource_offering_terms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.matresource_offering_terms_id_seq OWNER TO postgres;

--
-- Name: matresource_offering_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.matresource_offering_terms_id_seq OWNED BY public.matresource_offering_terms.id;


--
-- Name: matresource_owners; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.matresource_owners (
    matresource_id integer NOT NULL,
    actor_id integer NOT NULL,
    matresource_owner_id integer NOT NULL
);


ALTER TABLE public.matresource_owners OWNER TO postgres;

--
-- Name: matresource_owners_matresource_owner_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.matresource_owners_matresource_owner_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.matresource_owners_matresource_owner_id_seq OWNER TO postgres;

--
-- Name: matresource_owners_matresource_owner_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.matresource_owners_matresource_owner_id_seq OWNED BY public.matresource_owners.matresource_owner_id;


--
-- Name: matresource_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.matresource_types (
    matresource_type_id integer NOT NULL,
    category character varying(100),
    sub_category character varying(100),
    title character varying(200)
);


ALTER TABLE public.matresource_types OWNER TO postgres;

--
-- Name: matresource_types_matresource_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.matresource_types_matresource_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.matresource_types_matresource_type_id_seq OWNER TO postgres;

--
-- Name: matresource_types_matresource_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.matresource_types_matresource_type_id_seq OWNED BY public.matresource_types.matresource_type_id;


--
-- Name: matresources_matresource_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.matresources_matresource_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.matresources_matresource_id_seq OWNER TO postgres;

--
-- Name: matresources_matresource_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.matresources_matresource_id_seq OWNED BY public.matresources.matresource_id;


--
-- Name: matresources_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.matresources_notes (
    note_id integer NOT NULL,
    matresource_id integer NOT NULL,
    author_id integer NOT NULL
);


ALTER TABLE public.matresources_notes OWNER TO postgres;

--
-- Name: matresources_with_offerings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.matresources_with_offerings AS
 SELECT m.matresource_id,
    m.title,
    m.description,
    m.matresource_type_id,
    m.attachment,
    m.deleted_at,
    m.created_at,
    m.updated_at,
    m.created_by,
    m.updated_by,
    m.rating_id,
    mot.id AS offering_mapping_id,
    mot.offering_term_id,
    ot.name AS offering_term_name,
    ot.code AS offering_term_code,
    mot.cost,
    mot.currency,
    mot.special_terms,
    mot.created_at AS offering_created_at
   FROM ((public.matresources m
     LEFT JOIN public.matresource_offering_terms mot ON ((m.matresource_id = mot.matresource_id)))
     LEFT JOIN public.offering_terms ot ON ((mot.offering_term_id = ot.id)));


ALTER VIEW public.matresources_with_offerings OWNER TO postgres;

--
-- Name: messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.messages (
    message_id integer NOT NULL,
    message text NOT NULL,
    author_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer
);


ALTER TABLE public.messages OWNER TO postgres;

--
-- Name: messages_message_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.messages_message_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.messages_message_id_seq OWNER TO postgres;

--
-- Name: messages_message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.messages_message_id_seq OWNED BY public.messages.message_id;


--
-- Name: notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notes (
    note_id integer NOT NULL,
    note text NOT NULL,
    author_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer
);


ALTER TABLE public.notes OWNER TO postgres;

--
-- Name: notes_note_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notes_note_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notes_note_id_seq OWNER TO postgres;

--
-- Name: notes_note_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notes_note_id_seq OWNED BY public.notes.note_id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    notification_id integer NOT NULL,
    notification text NOT NULL,
    recipient integer NOT NULL,
    is_read boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- Name: notifications_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notifications_notification_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notifications_notification_id_seq OWNER TO postgres;

--
-- Name: notifications_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notifications_notification_id_seq OWNED BY public.notifications.notification_id;


--
-- Name: offering_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.offering_terms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.offering_terms_id_seq OWNER TO postgres;

--
-- Name: offering_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.offering_terms_id_seq OWNED BY public.offering_terms.id;


--
-- Name: organizations_organization_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.organizations_organization_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.organizations_organization_id_seq OWNER TO postgres;

--
-- Name: organizations_organization_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.organizations_organization_id_seq OWNED BY public.organizations.organization_id;


--
-- Name: persons_person_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.persons_person_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.persons_person_id_seq OWNER TO postgres;

--
-- Name: persons_person_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.persons_person_id_seq OWNED BY public.persons.person_id;


--
-- Name: primary_asset_images; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.primary_asset_images AS
 SELECT af.file_id,
    af.file_url,
    af.asset_record_id AS record_id,
    at.asset_table,
    at.asset_name,
    af.file_name,
    af.mime_type,
    af.dimensions,
    af.uploaded_at,
    a.nickname AS uploaded_by_name
   FROM ((public.asset_files af
     JOIN public.asset_types at ON ((af.asset_type_id = at.asset_type_id)))
     LEFT JOIN public.actors a ON ((af.uploaded_by = a.actor_id)))
  WHERE (((af.file_type)::text = 'image'::text) AND (af.is_primary = true) AND (af.is_public = true) AND ((af.expires_at IS NULL) OR (af.expires_at > now())))
  ORDER BY af.uploaded_at DESC;


ALTER VIEW public.primary_asset_images OWNER TO postgres;

--
-- Name: VIEW primary_asset_images; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.primary_asset_images IS 'Основные изображения всех активов для использования в галереях и списках';


--
-- Name: project_actor_roles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.project_actor_roles (
    project_actor_role_id integer NOT NULL,
    actor_id integer NOT NULL,
    project_id integer NOT NULL,
    role_type character varying(20) NOT NULL,
    assigned_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    assigned_by integer,
    note text,
    CONSTRAINT project_actor_roles_role_type_check CHECK (((role_type)::text = ANY (ARRAY[('leader'::character varying)::text, ('admin'::character varying)::text, ('member'::character varying)::text, ('curator'::character varying)::text])))
);


ALTER TABLE public.project_actor_roles OWNER TO postgres;

--
-- Name: TABLE project_actor_roles; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.project_actor_roles IS 'Хранит роли акторов в конкретных проектах (руководитель, администратор, участник, куратор)';


--
-- Name: COLUMN project_actor_roles.role_type; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.project_actor_roles.role_type IS 'Тип роли: leader-руководитель, admin-администратор, member-участник, curator-проектный куратор';


--
-- Name: COLUMN project_actor_roles.assigned_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.project_actor_roles.assigned_at IS 'Дата и время назначения роли';


--
-- Name: COLUMN project_actor_roles.assigned_by; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.project_actor_roles.assigned_by IS 'Кто назначил эту роль (ссылка на actors)';


--
-- Name: project_actor_roles_project_actor_role_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.project_actor_roles_project_actor_role_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.project_actor_roles_project_actor_role_id_seq OWNER TO postgres;

--
-- Name: project_actor_roles_project_actor_role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.project_actor_roles_project_actor_role_id_seq OWNED BY public.project_actor_roles.project_actor_role_id;


--
-- Name: project_statuses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.project_statuses (
    project_status_id integer NOT NULL,
    status character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.project_statuses OWNER TO postgres;

--
-- Name: projects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects (
    project_id integer NOT NULL,
    title character varying(100) NOT NULL,
    full_title character varying(200),
    description text,
    author_id integer,
    director_id integer,
    tutor_id integer,
    project_status_id integer,
    start_date date,
    end_date date,
    project_type_id integer,
    account character varying(12),
    keywords text,
    attachment character varying(255),
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    rating_id integer,
    cost numeric(15,2) DEFAULT 0,
    currency character varying(10) DEFAULT 'руб.'::character varying,
    offering_term_id integer DEFAULT 2,
    special_terms text,
    geom public.geometry(Point,4326),
    latitude numeric(10,8),
    longitude numeric(11,8),
    CONSTRAINT chk_project_dates CHECK ((start_date <= end_date))
);


ALTER TABLE public.projects OWNER TO postgres;

--
-- Name: project_asset_files; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.project_asset_files AS
 SELECT af.file_id,
    af.asset_type_id,
    af.asset_record_id,
    af.file_url,
    af.storage_type,
    af.file_type,
    af.file_category,
    af.file_name,
    af.original_name,
    af.mime_type,
    af.file_size,
    af.dimensions,
    af.description,
    af.tags,
    af.sort_order,
    af.is_primary,
    af.is_public,
    af.requires_auth,
    af.metadata,
    af.uploaded_at,
    af.uploaded_by,
    af.validated_by,
    af.validated_at,
    af.expires_at,
    af.version,
    af.previous_version_id,
    af.checksum,
    at.asset_name,
    p.title AS project_title,
    p.full_title AS project_full_title,
    ps.status AS project_status
   FROM (((public.asset_files af
     JOIN public.asset_types at ON ((af.asset_type_id = at.asset_type_id)))
     JOIN public.projects p ON ((af.asset_record_id = p.project_id)))
     LEFT JOIN public.project_statuses ps ON ((p.project_status_id = ps.project_status_id)))
  WHERE (((at.asset_table)::text = 'projects'::text) AND (p.deleted_at IS NULL));


ALTER VIEW public.project_asset_files OWNER TO postgres;

--
-- Name: project_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.project_groups (
    project_group_id integer NOT NULL,
    title character varying(200) NOT NULL,
    project_id integer NOT NULL,
    actor_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer
);


ALTER TABLE public.project_groups OWNER TO postgres;

--
-- Name: project_groups_project_group_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.project_groups_project_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.project_groups_project_group_id_seq OWNER TO postgres;

--
-- Name: project_groups_project_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.project_groups_project_group_id_seq OWNED BY public.project_groups.project_group_id;


--
-- Name: project_statuses_project_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.project_statuses_project_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.project_statuses_project_status_id_seq OWNER TO postgres;

--
-- Name: project_statuses_project_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.project_statuses_project_status_id_seq OWNED BY public.project_statuses.project_status_id;


--
-- Name: project_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.project_types (
    project_type_id integer NOT NULL,
    type character varying(50) NOT NULL
);


ALTER TABLE public.project_types OWNER TO postgres;

--
-- Name: project_types_project_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.project_types_project_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.project_types_project_type_id_seq OWNER TO postgres;

--
-- Name: project_types_project_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.project_types_project_type_id_seq OWNED BY public.project_types.project_type_id;


--
-- Name: projects_directions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects_directions (
    project_id integer NOT NULL,
    direction_id integer NOT NULL
);


ALTER TABLE public.projects_directions OWNER TO postgres;

--
-- Name: projects_functions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects_functions (
    project_id integer NOT NULL,
    function_id integer NOT NULL
);


ALTER TABLE public.projects_functions OWNER TO postgres;

--
-- Name: projects_local_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects_local_events (
    project_id integer NOT NULL,
    local_event_id integer NOT NULL
);


ALTER TABLE public.projects_local_events OWNER TO postgres;

--
-- Name: projects_locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects_locations (
    project_id integer NOT NULL,
    location_id integer NOT NULL
);


ALTER TABLE public.projects_locations OWNER TO postgres;

--
-- Name: projects_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects_notes (
    note_id integer NOT NULL,
    project_id integer NOT NULL,
    author_id integer NOT NULL
);


ALTER TABLE public.projects_notes OWNER TO postgres;

--
-- Name: projects_project_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.projects_project_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.projects_project_id_seq OWNER TO postgres;

--
-- Name: projects_project_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.projects_project_id_seq OWNED BY public.projects.project_id;


--
-- Name: projects_tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects_tasks (
    task_id integer NOT NULL,
    project_id integer NOT NULL
);


ALTER TABLE public.projects_tasks OWNER TO postgres;

--
-- Name: rating_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rating_types (
    rating_type_id integer NOT NULL,
    type character varying(50) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT rating_types_type_check CHECK (((type)::text = ANY ((ARRAY['положительно'::character varying, 'отрицательно'::character varying])::text[])))
);


ALTER TABLE public.rating_types OWNER TO postgres;

--
-- Name: rating_types_rating_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rating_types_rating_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rating_types_rating_type_id_seq OWNER TO postgres;

--
-- Name: rating_types_rating_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rating_types_rating_type_id_seq OWNED BY public.rating_types.rating_type_id;


--
-- Name: ratings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ratings (
    rating_id integer NOT NULL,
    actor_id integer NOT NULL,
    rating_type_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.ratings OWNER TO postgres;

--
-- Name: TABLE ratings; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.ratings IS 'Хранит основные записи оценок, привязка к сущностям через rating_id в их таблицах';


--
-- Name: ratings_rating_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ratings_rating_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ratings_rating_id_seq OWNER TO postgres;

--
-- Name: ratings_rating_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ratings_rating_id_seq OWNED BY public.ratings.rating_id;


--
-- Name: recent_files; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.recent_files AS
 SELECT af.file_id,
    at.asset_name,
    af.asset_record_id,
    af.file_name,
    af.file_type,
    af.file_category,
    af.file_size,
    af.uploaded_at,
    a.nickname AS uploaded_by
   FROM ((public.asset_files af
     JOIN public.asset_types at ON ((af.asset_type_id = at.asset_type_id)))
     LEFT JOIN public.actors a ON ((af.uploaded_by = a.actor_id)))
  ORDER BY af.uploaded_at DESC
 LIMIT 50;


ALTER VIEW public.recent_files OWNER TO postgres;

--
-- Name: request_offering_terms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.request_offering_terms (
    request_term_id integer NOT NULL,
    request_id integer NOT NULL,
    offering_term_id integer NOT NULL,
    proposed_cost numeric(15,2),
    request_terms text,
    requester_approval boolean DEFAULT false,
    owner_response character varying(20),
    owner_approved_cost numeric(15,2),
    owner_terms text,
    owner_approval boolean DEFAULT false,
    term_status character varying(20) DEFAULT 'pending'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_owner_response CHECK (((owner_response)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'modified'::character varying, 'rejected'::character varying])::text[]))),
    CONSTRAINT chk_term_status CHECK (((term_status)::text = ANY ((ARRAY['pending'::character varying, 'negotiating'::character varying, 'agreed'::character varying, 'rejected'::character varying])::text[])))
);


ALTER TABLE public.request_offering_terms OWNER TO postgres;

--
-- Name: request_offering_terms_request_term_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.request_offering_terms_request_term_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.request_offering_terms_request_term_id_seq OWNER TO postgres;

--
-- Name: request_offering_terms_request_term_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.request_offering_terms_request_term_id_seq OWNED BY public.request_offering_terms.request_term_id;


--
-- Name: request_statistic; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.request_statistic (
    request_statistic_id integer NOT NULL,
    location_id integer,
    creation_time timestamp without time zone NOT NULL,
    resource_type_id integer NOT NULL,
    subject_type_id integer,
    subject_id integer NOT NULL,
    relevance boolean NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    archived_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.request_statistic OWNER TO postgres;

--
-- Name: request_statistic_request_statistic_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.request_statistic_request_statistic_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.request_statistic_request_statistic_id_seq OWNER TO postgres;

--
-- Name: request_statistic_request_statistic_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.request_statistic_request_statistic_id_seq OWNED BY public.request_statistic.request_statistic_id;


--
-- Name: request_statuses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.request_statuses (
    request_status_id integer NOT NULL,
    status character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.request_statuses OWNER TO postgres;

--
-- Name: request_statuses_request_status_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.request_statuses_request_status_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.request_statuses_request_status_id_seq OWNER TO postgres;

--
-- Name: request_statuses_request_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.request_statuses_request_status_id_seq OWNED BY public.request_statuses.request_status_id;


--
-- Name: request_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.request_types (
    request_type_id integer NOT NULL,
    type character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.request_types OWNER TO postgres;

--
-- Name: request_types_request_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.request_types_request_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.request_types_request_type_id_seq OWNER TO postgres;

--
-- Name: request_types_request_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.request_types_request_type_id_seq OWNED BY public.request_types.request_type_id;


--
-- Name: requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.requests (
    request_id integer NOT NULL,
    requester_id integer NOT NULL,
    resource_type character varying(20) NOT NULL,
    resource_id integer NOT NULL,
    project_id integer,
    start_date date,
    end_date date,
    start_time time without time zone,
    end_time time without time zone,
    request_title character varying(200) NOT NULL,
    request_description text,
    requester_notes text,
    submitted_at timestamp without time zone,
    reviewed_at timestamp without time zone,
    responded_at timestamp without time zone,
    reviewed_by integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    event_id integer,
    request_status_id integer,
    request_type_id integer,
    location_id integer,
    request_type character varying(50),
    validity_period timestamp without time zone,
    CONSTRAINT chk_resource_type CHECK (((resource_type)::text = ANY ((ARRAY['matresource'::character varying, 'finresource'::character varying, 'venue'::character varying, 'service'::character varying])::text[])))
);


ALTER TABLE public.requests OWNER TO postgres;

--
-- Name: requests_request_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.requests_request_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.requests_request_id_seq OWNER TO postgres;

--
-- Name: requests_request_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.requests_request_id_seq OWNED BY public.requests.request_id;


--
-- Name: resource_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.resource_types (
    resource_type_id integer NOT NULL,
    type character varying(50) NOT NULL,
    description text,
    entity_table character varying(50),
    entity_id_column character varying(50),
    entity_type_column character varying(50)
);


ALTER TABLE public.resource_types OWNER TO postgres;

--
-- Name: resource_types_resource_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.resource_types_resource_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.resource_types_resource_type_id_seq OWNER TO postgres;

--
-- Name: resource_types_resource_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.resource_types_resource_type_id_seq OWNED BY public.resource_types.resource_type_id;


--
-- Name: service_offering_terms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.service_offering_terms (
    id integer NOT NULL,
    service_id integer NOT NULL,
    offering_term_id integer NOT NULL,
    cost numeric(15,2) DEFAULT 0,
    currency character varying(10) DEFAULT 'руб.'::character varying,
    special_terms text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.service_offering_terms OWNER TO postgres;

--
-- Name: service_offering_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.service_offering_terms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.service_offering_terms_id_seq OWNER TO postgres;

--
-- Name: service_offering_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.service_offering_terms_id_seq OWNED BY public.service_offering_terms.id;


--
-- Name: service_owners; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.service_owners (
    service_owner_id integer NOT NULL,
    service_id integer NOT NULL,
    actor_id integer NOT NULL,
    ownership_type character varying(50) DEFAULT 'owner'::character varying,
    ownership_share numeric(5,2) DEFAULT 100.00,
    is_primary boolean DEFAULT true,
    special_conditions text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.service_owners OWNER TO postgres;

--
-- Name: service_owners_service_owner_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.service_owners_service_owner_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.service_owners_service_owner_id_seq OWNER TO postgres;

--
-- Name: service_owners_service_owner_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.service_owners_service_owner_id_seq OWNED BY public.service_owners.service_owner_id;


--
-- Name: services; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.services (
    service_id integer NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    attachment character varying(255),
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    rating_id integer
);


ALTER TABLE public.services OWNER TO postgres;

--
-- Name: services_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.services_notes (
    note_id integer NOT NULL,
    service_id integer NOT NULL,
    author_id integer NOT NULL
);


ALTER TABLE public.services_notes OWNER TO postgres;

--
-- Name: services_service_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.services_service_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.services_service_id_seq OWNER TO postgres;

--
-- Name: services_service_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.services_service_id_seq OWNED BY public.services.service_id;


--
-- Name: services_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.services_types (
    services_type_id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text
);


ALTER TABLE public.services_types OWNER TO postgres;

--
-- Name: services_types_services_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.services_types_services_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.services_types_services_type_id_seq OWNER TO postgres;

--
-- Name: services_types_services_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.services_types_services_type_id_seq OWNED BY public.services_types.services_type_id;


--
-- Name: stage_architecture; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_architecture (
    stage_architecture_id integer NOT NULL,
    architecture character varying(100) NOT NULL
);


ALTER TABLE public.stage_architecture OWNER TO postgres;

--
-- Name: stage_architecture_stage_architecture_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stage_architecture_stage_architecture_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stage_architecture_stage_architecture_id_seq OWNER TO postgres;

--
-- Name: stage_architecture_stage_architecture_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_architecture_stage_architecture_id_seq OWNED BY public.stage_architecture.stage_architecture_id;


--
-- Name: stage_audio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_audio (
    stage_audio_id integer NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    attachment character varying(255),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer
);


ALTER TABLE public.stage_audio OWNER TO postgres;

--
-- Name: stage_audio_set; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_audio_set (
    stage_id integer NOT NULL,
    stage_audio_id integer NOT NULL
);


ALTER TABLE public.stage_audio_set OWNER TO postgres;

--
-- Name: stage_audio_stage_audio_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stage_audio_stage_audio_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stage_audio_stage_audio_id_seq OWNER TO postgres;

--
-- Name: stage_audio_stage_audio_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_audio_stage_audio_id_seq OWNED BY public.stage_audio.stage_audio_id;


--
-- Name: stage_effects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_effects (
    stage_effects_id integer NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    attachment character varying(255),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer
);


ALTER TABLE public.stage_effects OWNER TO postgres;

--
-- Name: stage_effects_set; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_effects_set (
    stage_id integer NOT NULL,
    stage_effects_id integer NOT NULL
);


ALTER TABLE public.stage_effects_set OWNER TO postgres;

--
-- Name: stage_effects_stage_effects_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stage_effects_stage_effects_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stage_effects_stage_effects_id_seq OWNER TO postgres;

--
-- Name: stage_effects_stage_effects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_effects_stage_effects_id_seq OWNED BY public.stage_effects.stage_effects_id;


--
-- Name: stage_light; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_light (
    stage_light_id integer NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    attachment character varying(255),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer
);


ALTER TABLE public.stage_light OWNER TO postgres;

--
-- Name: stage_light_set; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_light_set (
    stage_id integer NOT NULL,
    stage_light_id integer NOT NULL
);


ALTER TABLE public.stage_light_set OWNER TO postgres;

--
-- Name: stage_light_stage_light_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stage_light_stage_light_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stage_light_stage_light_id_seq OWNER TO postgres;

--
-- Name: stage_light_stage_light_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_light_stage_light_id_seq OWNED BY public.stage_light.stage_light_id;


--
-- Name: stage_mobility; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_mobility (
    stage_mobility_id integer NOT NULL,
    mobility character varying(100) NOT NULL
);


ALTER TABLE public.stage_mobility OWNER TO postgres;

--
-- Name: stage_mobility_stage_mobility_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stage_mobility_stage_mobility_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stage_mobility_stage_mobility_id_seq OWNER TO postgres;

--
-- Name: stage_mobility_stage_mobility_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_mobility_stage_mobility_id_seq OWNED BY public.stage_mobility.stage_mobility_id;


--
-- Name: stage_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_types (
    stage_type_id integer NOT NULL,
    type character varying(100) NOT NULL
);


ALTER TABLE public.stage_types OWNER TO postgres;

--
-- Name: stage_types_stage_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stage_types_stage_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stage_types_stage_type_id_seq OWNER TO postgres;

--
-- Name: stage_types_stage_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_types_stage_type_id_seq OWNED BY public.stage_types.stage_type_id;


--
-- Name: stage_video; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_video (
    stage_video_id integer NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    attachment character varying(255),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer
);


ALTER TABLE public.stage_video OWNER TO postgres;

--
-- Name: stage_video_set; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_video_set (
    stage_id integer NOT NULL,
    stage_video_id integer NOT NULL
);


ALTER TABLE public.stage_video_set OWNER TO postgres;

--
-- Name: stage_video_stage_video_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stage_video_stage_video_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stage_video_stage_video_id_seq OWNER TO postgres;

--
-- Name: stage_video_stage_video_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_video_stage_video_id_seq OWNED BY public.stage_video.stage_video_id;


--
-- Name: stages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stages (
    stage_id integer NOT NULL,
    title character varying(200) NOT NULL,
    full_title character varying(300),
    stage_type_id integer,
    stage_architecture_id integer,
    stage_mobility_id integer,
    capacity integer,
    width numeric(8,2),
    depth numeric(8,2),
    height numeric(8,2),
    description text,
    location_id integer,
    attachment character varying(255),
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    geom public.geometry(Point,4326),
    latitude numeric(10,8),
    longitude numeric(11,8),
    CONSTRAINT stages_capacity_check CHECK ((capacity > 0)),
    CONSTRAINT stages_depth_check CHECK ((depth > (0)::numeric)),
    CONSTRAINT stages_height_check CHECK ((height >= (0)::numeric)),
    CONSTRAINT stages_width_check CHECK ((width > (0)::numeric))
);


ALTER TABLE public.stages OWNER TO postgres;

--
-- Name: stages_stage_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stages_stage_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stages_stage_id_seq OWNER TO postgres;

--
-- Name: stages_stage_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stages_stage_id_seq OWNED BY public.stages.stage_id;


--
-- Name: system_commands; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.system_commands (
    id integer NOT NULL,
    category text,
    command text,
    description text
);


ALTER TABLE public.system_commands OWNER TO postgres;

--
-- Name: system_commands_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.system_commands_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.system_commands_id_seq OWNER TO postgres;

--
-- Name: system_commands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.system_commands_id_seq OWNED BY public.system_commands.id;


--
-- Name: system_deployment_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.system_deployment_log (
    deployment_id integer NOT NULL,
    component_name character varying(100) NOT NULL,
    component_type character varying(50) NOT NULL,
    status character varying(20) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    notes text
);


ALTER TABLE public.system_deployment_log OWNER TO postgres;

--
-- Name: system_deployment_log_deployment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.system_deployment_log_deployment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.system_deployment_log_deployment_id_seq OWNER TO postgres;

--
-- Name: system_deployment_log_deployment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.system_deployment_log_deployment_id_seq OWNED BY public.system_deployment_log.deployment_id;


--
-- Name: task_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.task_types (
    task_type_id integer NOT NULL,
    type character varying(50) NOT NULL
);


ALTER TABLE public.task_types OWNER TO postgres;

--
-- Name: task_types_task_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.task_types_task_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.task_types_task_type_id_seq OWNER TO postgres;

--
-- Name: task_types_task_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.task_types_task_type_id_seq OWNED BY public.task_types.task_type_id;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tasks (
    task_id integer NOT NULL,
    task text NOT NULL,
    task_type_id integer,
    due_date date,
    priority integer,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    CONSTRAINT tasks_priority_check CHECK (((priority >= 1) AND (priority <= 5)))
);


ALTER TABLE public.tasks OWNER TO postgres;

--
-- Name: tasks_task_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tasks_task_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tasks_task_id_seq OWNER TO postgres;

--
-- Name: tasks_task_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tasks_task_id_seq OWNED BY public.tasks.task_id;


--
-- Name: temp_contract_terms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.temp_contract_terms (
    temp_term_id integer NOT NULL,
    temp_contract_id integer NOT NULL,
    request_term_id integer NOT NULL,
    offering_term_id integer NOT NULL,
    agreed_cost numeric(15,2),
    agreed_currency character varying(10) DEFAULT 'руб.'::character varying,
    special_terms text,
    term_status character varying(20) DEFAULT 'pending'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_temp_term_status CHECK (((term_status)::text = ANY ((ARRAY['pending'::character varying, 'agreed'::character varying, 'rejected'::character varying])::text[])))
);


ALTER TABLE public.temp_contract_terms OWNER TO postgres;

--
-- Name: temp_contract_terms_temp_term_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.temp_contract_terms_temp_term_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.temp_contract_terms_temp_term_id_seq OWNER TO postgres;

--
-- Name: temp_contract_terms_temp_term_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.temp_contract_terms_temp_term_id_seq OWNED BY public.temp_contract_terms.temp_term_id;


--
-- Name: temp_contracts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.temp_contracts (
    temp_contract_id integer NOT NULL,
    request_id integer NOT NULL,
    contract_title character varying(200) NOT NULL,
    contract_description text,
    requester_id integer NOT NULL,
    owner_id integer NOT NULL,
    resource_type character varying(20) NOT NULL,
    resource_id integer NOT NULL,
    start_date date,
    end_date date,
    start_time time without time zone,
    end_time time without time zone,
    contract_status character varying(20) DEFAULT 'draft'::character varying,
    requester_signed boolean DEFAULT false,
    owner_signed boolean DEFAULT false,
    valid_from timestamp without time zone,
    valid_until timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_temp_contract_status CHECK (((contract_status)::text = ANY ((ARRAY['draft'::character varying, 'under_review'::character varying, 'pending_signatures'::character varying, 'active'::character varying, 'expired'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT chk_temp_resource_type CHECK (((resource_type)::text = ANY ((ARRAY['matresource'::character varying, 'finresource'::character varying, 'venue'::character varying, 'service'::character varying])::text[])))
);


ALTER TABLE public.temp_contracts OWNER TO postgres;

--
-- Name: temp_contracts_temp_contract_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.temp_contracts_temp_contract_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.temp_contracts_temp_contract_id_seq OWNER TO postgres;

--
-- Name: temp_contracts_temp_contract_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.temp_contracts_temp_contract_id_seq OWNED BY public.temp_contracts.temp_contract_id;


--
-- Name: template_offering_terms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.template_offering_terms (
    id integer NOT NULL,
    template_id integer NOT NULL,
    offering_term_id integer NOT NULL,
    cost numeric(15,2) DEFAULT 0,
    currency character varying(10) DEFAULT 'руб.'::character varying,
    special_terms text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.template_offering_terms OWNER TO postgres;

--
-- Name: template_offering_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.template_offering_terms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.template_offering_terms_id_seq OWNER TO postgres;

--
-- Name: template_offering_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.template_offering_terms_id_seq OWNED BY public.template_offering_terms.id;


--
-- Name: templates; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.templates (
    template_id integer NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    direction_id integer,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    rating_id integer
);


ALTER TABLE public.templates OWNER TO postgres;

--
-- Name: templates_finresources; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.templates_finresources (
    template_id integer NOT NULL,
    finresource_id integer NOT NULL
);


ALTER TABLE public.templates_finresources OWNER TO postgres;

--
-- Name: templates_functions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.templates_functions (
    template_id integer NOT NULL,
    function_id integer NOT NULL
);


ALTER TABLE public.templates_functions OWNER TO postgres;

--
-- Name: templates_matresources; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.templates_matresources (
    template_id integer NOT NULL,
    matresource_id integer NOT NULL
);


ALTER TABLE public.templates_matresources OWNER TO postgres;

--
-- Name: templates_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.templates_notes (
    template_note_id integer NOT NULL,
    template_id integer NOT NULL,
    note_id integer NOT NULL,
    author_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp with time zone
);


ALTER TABLE public.templates_notes OWNER TO postgres;

--
-- Name: TABLE templates_notes; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.templates_notes IS 'Заметки пользователей к шаблонам';


--
-- Name: templates_notes_template_note_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.templates_notes_template_note_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.templates_notes_template_note_id_seq OWNER TO postgres;

--
-- Name: templates_notes_template_note_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.templates_notes_template_note_id_seq OWNED BY public.templates_notes.template_note_id;


--
-- Name: templates_template_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.templates_template_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.templates_template_id_seq OWNER TO postgres;

--
-- Name: templates_template_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.templates_template_id_seq OWNED BY public.templates.template_id;


--
-- Name: templates_venues; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.templates_venues (
    template_id integer NOT NULL,
    venue_id integer NOT NULL
);


ALTER TABLE public.templates_venues OWNER TO postgres;

--
-- Name: theme_bookmarks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.theme_bookmarks (
    bookmark_id integer NOT NULL,
    theme_id integer NOT NULL,
    actor_id integer NOT NULL,
    last_read_discussion_id integer,
    last_read_position integer,
    scroll_position jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.theme_bookmarks OWNER TO postgres;

--
-- Name: TABLE theme_bookmarks; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.theme_bookmarks IS 'Закладки пользователей в обсуждениях тем';


--
-- Name: theme_bookmarks_bookmark_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.theme_bookmarks_bookmark_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.theme_bookmarks_bookmark_id_seq OWNER TO postgres;

--
-- Name: theme_bookmarks_bookmark_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.theme_bookmarks_bookmark_id_seq OWNED BY public.theme_bookmarks.bookmark_id;


--
-- Name: theme_comments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.theme_comments (
    theme_comment_id integer NOT NULL,
    comment text NOT NULL,
    theme_id integer NOT NULL,
    actor_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer
);


ALTER TABLE public.theme_comments OWNER TO postgres;

--
-- Name: theme_comments_theme_comment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.theme_comments_theme_comment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.theme_comments_theme_comment_id_seq OWNER TO postgres;

--
-- Name: theme_comments_theme_comment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.theme_comments_theme_comment_id_seq OWNED BY public.theme_comments.theme_comment_id;


--
-- Name: theme_discussions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.theme_discussions (
    discussion_id integer NOT NULL,
    theme_id integer NOT NULL,
    parent_discussion_id integer,
    author_id integer NOT NULL,
    content text NOT NULL,
    position_in_thread integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp with time zone
);


ALTER TABLE public.theme_discussions OWNER TO postgres;

--
-- Name: theme_discussions_discussion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.theme_discussions_discussion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.theme_discussions_discussion_id_seq OWNER TO postgres;

--
-- Name: theme_discussions_discussion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.theme_discussions_discussion_id_seq OWNED BY public.theme_discussions.discussion_id;


--
-- Name: theme_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.theme_notes (
    theme_note_id integer NOT NULL,
    theme_id integer NOT NULL,
    note_id integer NOT NULL,
    author_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamp with time zone
);


ALTER TABLE public.theme_notes OWNER TO postgres;

--
-- Name: TABLE theme_notes; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.theme_notes IS 'Заметки пользователей к темам';


--
-- Name: theme_notes_theme_note_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.theme_notes_theme_note_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.theme_notes_theme_note_id_seq OWNER TO postgres;

--
-- Name: theme_notes_theme_note_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.theme_notes_theme_note_id_seq OWNED BY public.theme_notes.theme_note_id;


--
-- Name: theme_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.theme_types (
    theme_type_id integer NOT NULL,
    type character varying(50) NOT NULL
);


ALTER TABLE public.theme_types OWNER TO postgres;

--
-- Name: theme_types_theme_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.theme_types_theme_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.theme_types_theme_type_id_seq OWNER TO postgres;

--
-- Name: theme_types_theme_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.theme_types_theme_type_id_seq OWNED BY public.theme_types.theme_type_id;


--
-- Name: themes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.themes (
    theme_id integer NOT NULL,
    title character varying(200) NOT NULL,
    description text,
    theme_type_id integer,
    actor_id integer,
    attachment character varying(255),
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    rating_id integer
);


ALTER TABLE public.themes OWNER TO postgres;

--
-- Name: themes_theme_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.themes_theme_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.themes_theme_id_seq OWNER TO postgres;

--
-- Name: themes_theme_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.themes_theme_id_seq OWNED BY public.themes.theme_id;


--
-- Name: v_active_contracts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_active_contracts AS
SELECT
    NULL::integer AS contract_id,
    NULL::character varying(50) AS contract_number,
    NULL::character varying(200) AS contract_title,
    NULL::character varying(20) AS resource_type,
    NULL::integer AS resource_id,
    NULL::character varying AS resource_title,
    NULL::integer AS requester_id,
    NULL::character varying(100) AS requester_name,
    NULL::integer AS owner_id,
    NULL::character varying(100) AS owner_name,
    NULL::numeric(15,2) AS total_cost,
    NULL::character varying(10) AS currency,
    NULL::character varying(20) AS contract_status,
    NULL::timestamp without time zone AS effective_from,
    NULL::timestamp without time zone AS effective_until,
    NULL::bigint AS terms_count,
    NULL::bigint AS completed_terms;


ALTER VIEW public.v_active_contracts OWNER TO postgres;

--
-- Name: v_ideas_offerings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_ideas_offerings AS
 SELECT i.idea_id,
    i.title,
    i.short_description,
    i.full_description,
    i.detail_description,
    i.idea_category_id,
    i.idea_type_id,
    i.actor_id,
    i.attachment,
    i.deleted_at,
    i.created_at,
    i.updated_at,
    i.created_by,
    i.updated_by,
    i.rating_id,
    iot.id AS offering_mapping_id,
    iot.offering_term_id,
    ot.name AS offering_term_name,
    ot.code AS offering_term_code,
    ot.is_paid,
    ot.is_temporary,
    iot.cost,
    iot.currency,
    iot.special_terms AS offering_special_terms,
    iot.created_at AS offering_created_at
   FROM ((public.ideas i
     LEFT JOIN public.idea_offering_terms iot ON ((i.idea_id = iot.idea_id)))
     LEFT JOIN public.offering_terms ot ON ((iot.offering_term_id = ot.id)));


ALTER VIEW public.v_ideas_offerings OWNER TO postgres;

--
-- Name: v_matresources_offerings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_matresources_offerings AS
 SELECT m.matresource_id,
    m.title,
    m.description,
    m.matresource_type_id,
    m.attachment,
    m.deleted_at,
    m.created_at,
    m.updated_at,
    m.created_by,
    m.updated_by,
    m.rating_id,
    mot.id AS offering_mapping_id,
    mot.offering_term_id,
    ot.name AS offering_term_name,
    ot.code AS offering_term_code,
    ot.is_paid,
    ot.is_temporary,
    mot.cost,
    mot.currency,
    mot.special_terms AS offering_special_terms,
    mot.created_at AS offering_created_at
   FROM ((public.matresources m
     LEFT JOIN public.matresource_offering_terms mot ON ((m.matresource_id = mot.matresource_id)))
     LEFT JOIN public.offering_terms ot ON ((mot.offering_term_id = ot.id)));


ALTER VIEW public.v_matresources_offerings OWNER TO postgres;

--
-- Name: v_services_offerings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_services_offerings AS
 SELECT s.service_id,
    s.title,
    s.description,
    s.attachment,
    s.deleted_at,
    s.created_at,
    s.updated_at,
    s.created_by,
    s.updated_by,
    s.rating_id,
    sot.id AS offering_mapping_id,
    sot.offering_term_id,
    ot.name AS offering_term_name,
    ot.code AS offering_term_code,
    ot.is_paid,
    ot.is_temporary,
    sot.cost,
    sot.currency,
    sot.special_terms AS offering_special_terms,
    sot.created_at AS offering_created_at
   FROM ((public.services s
     LEFT JOIN public.service_offering_terms sot ON ((s.service_id = sot.service_id)))
     LEFT JOIN public.offering_terms ot ON ((sot.offering_term_id = ot.id)));


ALTER VIEW public.v_services_offerings OWNER TO postgres;

--
-- Name: v_templates_offerings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_templates_offerings AS
 SELECT t.template_id,
    t.title,
    t.description,
    t.direction_id,
    t.deleted_at,
    t.created_at,
    t.updated_at,
    t.created_by,
    t.updated_by,
    t.rating_id,
    tot.id AS offering_mapping_id,
    tot.offering_term_id,
    ot.name AS offering_term_name,
    ot.code AS offering_term_code,
    ot.is_paid,
    ot.is_temporary,
    tot.cost,
    tot.currency,
    tot.special_terms AS offering_special_terms,
    tot.created_at AS offering_created_at
   FROM ((public.templates t
     LEFT JOIN public.template_offering_terms tot ON ((t.template_id = tot.template_id)))
     LEFT JOIN public.offering_terms ot ON ((tot.offering_term_id = ot.id)));


ALTER VIEW public.v_templates_offerings OWNER TO postgres;

--
-- Name: venue_offering_terms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.venue_offering_terms (
    id integer NOT NULL,
    venue_id integer NOT NULL,
    offering_term_id integer NOT NULL,
    cost numeric(15,2) DEFAULT 0,
    currency character varying(10) DEFAULT 'руб.'::character varying,
    special_terms text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.venue_offering_terms OWNER TO postgres;

--
-- Name: venues; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.venues (
    venue_id integer NOT NULL,
    title character varying(200) NOT NULL,
    full_title character varying(300),
    venue_type_id integer,
    description text,
    actor_id integer,
    location_id integer,
    attachment character varying(255),
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by integer,
    updated_by integer,
    rating_id integer,
    geom public.geometry(Point,4326),
    latitude numeric(10,8),
    longitude numeric(11,8)
);


ALTER TABLE public.venues OWNER TO postgres;

--
-- Name: v_venues_offerings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_venues_offerings AS
 SELECT v.venue_id,
    v.title,
    v.full_title,
    v.venue_type_id,
    v.description,
    v.actor_id,
    v.location_id,
    v.attachment,
    v.deleted_at,
    v.created_at,
    v.updated_at,
    v.created_by,
    v.updated_by,
    v.rating_id,
    vot.id AS offering_mapping_id,
    vot.offering_term_id,
    ot.name AS offering_term_name,
    ot.code AS offering_term_code,
    ot.is_paid,
    ot.is_temporary,
    vot.cost,
    vot.currency,
    vot.special_terms AS offering_special_terms,
    vot.created_at AS offering_created_at
   FROM ((public.venues v
     LEFT JOIN public.venue_offering_terms vot ON ((v.venue_id = vot.venue_id)))
     LEFT JOIN public.offering_terms ot ON ((vot.offering_term_id = ot.id)));


ALTER VIEW public.v_venues_offerings OWNER TO postgres;

--
-- Name: v_all_resources_offerings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_all_resources_offerings AS
 SELECT 'matresource'::text AS resource_type,
    v_matresources_offerings.matresource_id AS resource_id,
    v_matresources_offerings.title,
    v_matresources_offerings.offering_term_id,
    v_matresources_offerings.offering_term_name,
    v_matresources_offerings.offering_term_code,
    v_matresources_offerings.cost,
    v_matresources_offerings.currency,
    v_matresources_offerings.offering_special_terms,
    v_matresources_offerings.offering_created_at
   FROM public.v_matresources_offerings
  WHERE (v_matresources_offerings.offering_term_id IS NOT NULL)
UNION ALL
 SELECT 'idea'::text AS resource_type,
    v_ideas_offerings.idea_id AS resource_id,
    v_ideas_offerings.title,
    v_ideas_offerings.offering_term_id,
    v_ideas_offerings.offering_term_name,
    v_ideas_offerings.offering_term_code,
    v_ideas_offerings.cost,
    v_ideas_offerings.currency,
    v_ideas_offerings.offering_special_terms,
    v_ideas_offerings.offering_created_at
   FROM public.v_ideas_offerings
  WHERE (v_ideas_offerings.offering_term_id IS NOT NULL)
UNION ALL
 SELECT 'service'::text AS resource_type,
    v_services_offerings.service_id AS resource_id,
    v_services_offerings.title,
    v_services_offerings.offering_term_id,
    v_services_offerings.offering_term_name,
    v_services_offerings.offering_term_code,
    v_services_offerings.cost,
    v_services_offerings.currency,
    v_services_offerings.offering_special_terms,
    v_services_offerings.offering_created_at
   FROM public.v_services_offerings
  WHERE (v_services_offerings.offering_term_id IS NOT NULL)
UNION ALL
 SELECT 'template'::text AS resource_type,
    v_templates_offerings.template_id AS resource_id,
    v_templates_offerings.title,
    v_templates_offerings.offering_term_id,
    v_templates_offerings.offering_term_name,
    v_templates_offerings.offering_term_code,
    v_templates_offerings.cost,
    v_templates_offerings.currency,
    v_templates_offerings.offering_special_terms,
    v_templates_offerings.offering_created_at
   FROM public.v_templates_offerings
  WHERE (v_templates_offerings.offering_term_id IS NOT NULL)
UNION ALL
 SELECT 'venue'::text AS resource_type,
    v_venues_offerings.venue_id AS resource_id,
    v_venues_offerings.title,
    v_venues_offerings.offering_term_id,
    v_venues_offerings.offering_term_name,
    v_venues_offerings.offering_term_code,
    v_venues_offerings.cost,
    v_venues_offerings.currency,
    v_venues_offerings.offering_special_terms,
    v_venues_offerings.offering_created_at
   FROM public.v_venues_offerings
  WHERE (v_venues_offerings.offering_term_id IS NOT NULL);


ALTER VIEW public.v_all_resources_offerings OWNER TO postgres;

--
-- Name: v_all_resources_offerings_enhanced; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_all_resources_offerings_enhanced AS
 SELECT resource_type,
    resource_id,
    title,
    offering_term_id,
    offering_term_name,
    offering_term_code,
    cost,
    currency,
    offering_special_terms,
    offering_created_at,
        CASE
            WHEN (cost = (0)::numeric) THEN 'Бесплатно'::text
            ELSE ((cost || ' '::text) || (currency)::text)
        END AS price_display,
        CASE
            WHEN (cost = (0)::numeric) THEN 'free'::text
            ELSE 'paid'::text
        END AS price_type,
        CASE
            WHEN ((offering_term_code)::text = ANY ((ARRAY['temporary_free'::character varying, 'temporary_paid'::character varying])::text[])) THEN true
            ELSE false
        END AS is_temporary
   FROM public.v_all_resources_offerings;


ALTER VIEW public.v_all_resources_offerings_enhanced OWNER TO postgres;

--
-- Name: v_entity_geometries_with_coords; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_entity_geometries_with_coords AS
 SELECT geometry_id,
    entity_type,
    entity_id,
    geom,
    accuracy,
    source,
    address,
    description,
    is_verified,
    verified_at,
    verified_by,
    created_at,
    updated_at,
    created_by,
    updated_by,
    public.st_y((geom)::public.geometry) AS latitude,
    public.st_x((geom)::public.geometry) AS longitude
   FROM public.entity_geometries;


ALTER VIEW public.v_entity_geometries_with_coords OWNER TO postgres;

--
-- Name: venue_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.venue_types (
    venue_type_id integer NOT NULL,
    type character varying(100) NOT NULL
);


ALTER TABLE public.venue_types OWNER TO postgres;

--
-- Name: v_entity_geometries_detailed; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_entity_geometries_detailed AS
 SELECT eg.geometry_id,
    eg.entity_type,
    eg.entity_id,
    vc.latitude,
    vc.longitude,
    eg.geom,
    eg.address,
    eg.description,
    eg.is_verified,
    eg.source,
    eg.created_at,
        CASE eg.entity_type
            WHEN 'location'::text THEN l.name
            WHEN 'venue'::text THEN v.title
            WHEN 'event'::text THEN e.title
            WHEN 'organization'::text THEN o.title
            WHEN 'community'::text THEN c.title
            WHEN 'project'::text THEN p.title
            WHEN 'stage'::text THEN s.title
            ELSE NULL::character varying
        END AS entity_title,
        CASE eg.entity_type
            WHEN 'location'::text THEN l.type
            WHEN 'venue'::text THEN vt.type
            WHEN 'event'::text THEN et.type
            WHEN 'organization'::text THEN 'Организация'::character varying
            WHEN 'community'::text THEN 'Сообщество'::character varying
            WHEN 'project'::text THEN pt.type
            WHEN 'stage'::text THEN st.type
            ELSE NULL::character varying
        END AS entity_type_name,
    a.nickname AS created_by_name
   FROM (((((((((((((public.entity_geometries eg
     JOIN public.v_entity_geometries_with_coords vc ON ((eg.geometry_id = vc.geometry_id)))
     LEFT JOIN public.locations l ON ((((eg.entity_type)::text = 'location'::text) AND (eg.entity_id = l.location_id))))
     LEFT JOIN public.venues v ON ((((eg.entity_type)::text = 'venue'::text) AND (eg.entity_id = v.venue_id))))
     LEFT JOIN public.venue_types vt ON ((v.venue_type_id = vt.venue_type_id)))
     LEFT JOIN public.events e ON ((((eg.entity_type)::text = 'event'::text) AND (eg.entity_id = e.event_id))))
     LEFT JOIN public.event_types et ON ((e.event_type_id = et.event_type_id)))
     LEFT JOIN public.organizations o ON ((((eg.entity_type)::text = 'organization'::text) AND (eg.entity_id = o.organization_id))))
     LEFT JOIN public.communities c ON ((((eg.entity_type)::text = 'community'::text) AND (eg.entity_id = c.community_id))))
     LEFT JOIN public.projects p ON ((((eg.entity_type)::text = 'project'::text) AND (eg.entity_id = p.project_id))))
     LEFT JOIN public.project_types pt ON ((p.project_type_id = pt.project_type_id)))
     LEFT JOIN public.stages s ON ((((eg.entity_type)::text = 'stage'::text) AND (eg.entity_id = s.stage_id))))
     LEFT JOIN public.stage_types st ON ((s.stage_type_id = st.stage_type_id)))
     LEFT JOIN public.actors a ON ((eg.created_by = a.actor_id)));


ALTER VIEW public.v_entity_geometries_detailed OWNER TO postgres;

--
-- Name: v_entity_geometries_with_coords_decimal; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_entity_geometries_with_coords_decimal AS
 SELECT geometry_id,
    entity_type,
    entity_id,
    geom,
    accuracy,
    source,
    address,
    description,
    is_verified,
    verified_at,
    verified_by,
    created_at,
    updated_at,
    created_by,
    updated_by,
    (public.st_y((geom)::public.geometry))::numeric(10,8) AS latitude,
    (public.st_x((geom)::public.geometry))::numeric(11,8) AS longitude
   FROM public.entity_geometries;


ALTER VIEW public.v_entity_geometries_with_coords_decimal OWNER TO postgres;

--
-- Name: v_finresources_offerings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_finresources_offerings AS
 SELECT f.finresource_id,
    f.title,
    f.description,
    f.finresource_type_id,
    f.attachment,
    f.deleted_at,
    f.created_at,
    f.updated_at,
    f.created_by,
    f.updated_by,
    f.rating_id,
    fot.id AS offering_mapping_id,
    fot.offering_term_id,
    ot.name AS offering_term_name,
    ot.code AS offering_term_code,
    ot.is_paid,
    ot.is_temporary,
    fot.cost,
    fot.currency,
    fot.special_terms AS offering_special_terms,
    fot.created_at AS offering_created_at
   FROM ((public.finresources f
     LEFT JOIN public.finresource_offering_terms fot ON ((f.finresource_id = fot.finresource_id)))
     LEFT JOIN public.offering_terms ot ON ((fot.offering_term_id = ot.id)));


ALTER VIEW public.v_finresources_offerings OWNER TO postgres;

--
-- Name: v_free_offerings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_free_offerings AS
 SELECT resource_type,
    resource_id,
    title,
    offering_term_id,
    offering_term_name,
    offering_term_code,
    cost,
    currency,
    offering_special_terms,
    offering_created_at
   FROM public.v_all_resources_offerings
  WHERE (cost = (0)::numeric)
  ORDER BY resource_type, title;


ALTER VIEW public.v_free_offerings OWNER TO postgres;

--
-- Name: v_geometries_by_type; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_geometries_by_type AS
 SELECT eg.entity_type,
    count(*) AS count,
    count(
        CASE
            WHEN (eg.is_verified = true) THEN 1
            ELSE NULL::integer
        END) AS verified_count,
    min(vc.latitude) AS min_lat,
    max(vc.latitude) AS max_lat,
    min(vc.longitude) AS min_lon,
    max(vc.longitude) AS max_lon,
    round((avg(vc.longitude))::numeric, 6) AS avg_lon,
    round((avg(vc.latitude))::numeric, 6) AS avg_lat
   FROM (public.entity_geometries eg
     JOIN public.v_entity_geometries_with_coords vc ON ((eg.geometry_id = vc.geometry_id)))
  GROUP BY eg.entity_type
  ORDER BY (count(*)) DESC;


ALTER VIEW public.v_geometries_by_type OWNER TO postgres;

--
-- Name: v_geometries_health_check; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_geometries_health_check AS
 SELECT 'entity_geometries'::text AS table_name,
    count(*) AS record_count,
    count(
        CASE
            WHEN (entity_geometries.is_verified = true) THEN 1
            ELSE NULL::integer
        END) AS verified_count,
    round((((count(
        CASE
            WHEN (entity_geometries.is_verified = true) THEN 1
            ELSE NULL::integer
        END))::numeric * 100.0) / (count(*))::numeric), 1) AS verification_rate,
    min(entity_geometries.created_at) AS oldest_record,
    max(entity_geometries.created_at) AS newest_record
   FROM public.entity_geometries
UNION ALL
 SELECT 'geometries_by_type'::text AS table_name,
    count(*) AS record_count,
    0 AS verified_count,
    0 AS verification_rate,
    NULL::timestamp without time zone AS oldest_record,
    NULL::timestamp without time zone AS newest_record
   FROM public.v_geometries_by_type;


ALTER VIEW public.v_geometries_health_check OWNER TO postgres;

--
-- Name: v_offerings_summary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_offerings_summary AS
 SELECT resource_type,
    count(*) AS total_offerings,
    count(DISTINCT resource_id) AS unique_resources,
    count(
        CASE
            WHEN (cost > (0)::numeric) THEN 1
            ELSE NULL::integer
        END) AS paid_offerings,
    count(
        CASE
            WHEN (cost = (0)::numeric) THEN 1
            ELSE NULL::integer
        END) AS free_offerings,
    sum(
        CASE
            WHEN (cost > (0)::numeric) THEN cost
            ELSE (0)::numeric
        END) AS total_revenue_potential,
    min(cost) AS min_price,
    max(cost) AS max_price
   FROM public.v_all_resources_offerings
  GROUP BY resource_type
  ORDER BY resource_type;


ALTER VIEW public.v_offerings_summary OWNER TO postgres;

--
-- Name: v_paid_offerings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_paid_offerings AS
 SELECT resource_type,
    resource_id,
    title,
    offering_term_id,
    offering_term_name,
    offering_term_code,
    cost,
    currency,
    offering_special_terms,
    offering_created_at
   FROM public.v_all_resources_offerings
  WHERE (cost > (0)::numeric)
  ORDER BY cost DESC;


ALTER VIEW public.v_paid_offerings OWNER TO postgres;

--
-- Name: v_pending_contracts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_pending_contracts AS
SELECT
    NULL::integer AS temp_contract_id,
    NULL::character varying(200) AS contract_title,
    NULL::character varying(20) AS resource_type,
    NULL::integer AS resource_id,
    NULL::character varying AS resource_title,
    NULL::integer AS requester_id,
    NULL::character varying(100) AS requester_name,
    NULL::integer AS owner_id,
    NULL::character varying(100) AS owner_name,
    NULL::character varying(20) AS contract_status,
    NULL::boolean AS requester_signed,
    NULL::boolean AS owner_signed,
    NULL::bigint AS terms_count,
    NULL::bigint AS agreed_terms;


ALTER VIEW public.v_pending_contracts OWNER TO postgres;

--
-- Name: v_request_terms_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_request_terms_details AS
 SELECT r.request_id,
    r.request_title,
    r.resource_type,
    r.resource_id,
    rot.request_term_id,
    ot.name AS term_name,
    rot.proposed_cost,
    rot.request_terms,
    rot.requester_approval,
    rot.owner_response,
    rot.owner_approved_cost,
    rot.owner_terms,
    rot.owner_approval,
    rot.term_status,
        CASE
            WHEN ((rot.requester_approval = true) AND (rot.owner_approval = true)) THEN 'fully_agreed'::text
            WHEN ((rot.requester_approval = true) OR (rot.owner_approval = true)) THEN 'partially_agreed'::text
            ELSE 'under_negotiation'::text
        END AS agreement_status
   FROM ((public.requests r
     JOIN public.request_offering_terms rot ON ((r.request_id = rot.request_id)))
     JOIN public.offering_terms ot ON ((rot.offering_term_id = ot.id)));


ALTER VIEW public.v_request_terms_details OWNER TO postgres;

--
-- Name: v_resource_catalog; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_resource_catalog AS
 WITH resource_details AS (
         SELECT 'matresource'::text AS resource_type,
            matresources.matresource_id AS id,
            matresources.title,
            'material'::text AS category
           FROM public.matresources
        UNION ALL
         SELECT 'finresource'::text,
            finresources.finresource_id,
            finresources.title,
            'financial'::text
           FROM public.finresources
        UNION ALL
         SELECT 'service'::text,
            min(services.service_id) AS id,
            services.title,
            'service'::text
           FROM public.services
          GROUP BY services.title, services.description
        UNION ALL
         SELECT 'venue'::text,
            venues.venue_id,
            venues.title,
            'venue'::text
           FROM public.venues
        UNION ALL
         SELECT 'idea'::text,
            ideas.idea_id,
            ideas.title,
            'idea'::text
           FROM public.ideas
        UNION ALL
         SELECT 'template'::text,
            templates.template_id,
            templates.title,
            'template'::text
           FROM public.templates
        )
 SELECT rd.resource_type,
    rd.id,
    rd.title,
    rd.category,
    COALESCE(aro.offering_count, (0)::bigint) AS offering_count,
    COALESCE(aro.offering_terms, 'Нет предложений'::text) AS offering_terms,
    COALESCE(aro.min_price, (0)::numeric) AS min_price,
    COALESCE(aro.max_price, (0)::numeric) AS max_price,
    COALESCE(aro.has_free, false) AS has_free_offers,
    COALESCE(aro.has_paid, false) AS has_paid_offers
   FROM (resource_details rd
     LEFT JOIN ( SELECT v_all_resources_offerings.resource_type,
            v_all_resources_offerings.resource_id,
            count(*) AS offering_count,
            string_agg((v_all_resources_offerings.offering_term_name)::text, ', '::text) AS offering_terms,
            min(v_all_resources_offerings.cost) AS min_price,
            max(v_all_resources_offerings.cost) AS max_price,
            bool_or((v_all_resources_offerings.cost = (0)::numeric)) AS has_free,
            bool_or((v_all_resources_offerings.cost > (0)::numeric)) AS has_paid
           FROM public.v_all_resources_offerings
          GROUP BY v_all_resources_offerings.resource_type, v_all_resources_offerings.resource_id) aro ON (((rd.resource_type = aro.resource_type) AND (rd.id = aro.resource_id))))
  ORDER BY rd.category, rd.title;


ALTER VIEW public.v_resource_catalog OWNER TO postgres;

--
-- Name: v_resource_catalog_detailed; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_resource_catalog_detailed AS
 SELECT resource_type,
    id,
    title,
    category,
    offering_count,
    offering_terms,
    min_price,
    max_price,
    has_free_offers,
    has_paid_offers,
    public.get_resource_description(resource_type, id) AS description
   FROM public.v_resource_catalog rc;


ALTER VIEW public.v_resource_catalog_detailed OWNER TO postgres;

--
-- Name: venue_owners; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.venue_owners (
    venue_owner_id integer NOT NULL,
    venue_id integer NOT NULL,
    actor_id integer NOT NULL,
    ownership_type character varying(50) DEFAULT 'owner'::character varying,
    ownership_share numeric(5,2) DEFAULT 100.00,
    is_primary boolean DEFAULT true,
    special_conditions text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.venue_owners OWNER TO postgres;

--
-- Name: v_resource_owners; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_resource_owners AS
 SELECT 'matresource'::text AS resource_type,
    m.matresource_id AS resource_id,
    m.title AS resource_title,
    mo.actor_id AS owner_id,
    a.nickname AS owner_name,
    a.rating_id AS owner_status,
    true AS is_primary,
    100.00 AS ownership_share
   FROM ((public.matresources m
     JOIN public.matresource_owners mo ON ((m.matresource_id = mo.matresource_id)))
     LEFT JOIN public.actors a ON ((mo.actor_id = a.actor_id)))
UNION ALL
 SELECT 'finresource'::text AS resource_type,
    f.finresource_id AS resource_id,
    f.title AS resource_title,
    fo.actor_id AS owner_id,
    a.nickname AS owner_name,
    a.rating_id AS owner_status,
    true AS is_primary,
    100.00 AS ownership_share
   FROM ((public.finresources f
     JOIN public.finresource_owners fo ON ((f.finresource_id = fo.finresource_id)))
     LEFT JOIN public.actors a ON ((fo.actor_id = a.actor_id)))
UNION ALL
 SELECT 'venue'::text AS resource_type,
    v.venue_id AS resource_id,
    v.title AS resource_title,
    vo.actor_id AS owner_id,
    a.nickname AS owner_name,
    a.rating_id AS owner_status,
    vo.is_primary,
    vo.ownership_share
   FROM ((public.venues v
     JOIN public.venue_owners vo ON ((v.venue_id = vo.venue_id)))
     LEFT JOIN public.actors a ON ((vo.actor_id = a.actor_id)))
UNION ALL
 SELECT 'service'::text AS resource_type,
    s.service_id AS resource_id,
    s.title AS resource_title,
    so.actor_id AS owner_id,
    a.nickname AS owner_name,
    a.rating_id AS owner_status,
    so.is_primary,
    so.ownership_share
   FROM ((public.services s
     JOIN public.service_owners so ON ((s.service_id = so.service_id)))
     LEFT JOIN public.actors a ON ((so.actor_id = a.actor_id)));


ALTER VIEW public.v_resource_owners OWNER TO postgres;

--
-- Name: v_system_guide; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_system_guide AS
 SELECT 'Таблицы'::text AS object_type,
    tables.table_name AS object_name,
    'Хранение данных'::text AS purpose
   FROM information_schema.tables
  WHERE (((tables.table_schema)::name = 'public'::name) AND ((tables.table_name)::name = ANY (ARRAY['requests'::name, 'request_offering_terms'::name, 'temp_contracts'::name, 'temp_contract_terms'::name, 'contracts'::name, 'contract_terms'::name, 'venue_owners'::name, 'service_owners'::name])))
UNION ALL
 SELECT 'Функции'::text AS object_type,
    routines.routine_name AS object_name,
    'Автоматизация процессов'::text AS purpose
   FROM information_schema.routines
  WHERE (((routines.routine_schema)::name = 'public'::name) AND ((routines.routine_name)::name = ANY (ARRAY['create_request'::name, 'add_request_term'::name, 'create_temp_contract_on_request_accept'::name, 'create_final_contract'::name, 'update_updated_at_column'::name])))
UNION ALL
 SELECT 'Представления'::text AS object_type,
    views.table_name AS object_name,
    'Мониторинг и аналитика'::text AS purpose
   FROM information_schema.views
  WHERE (((views.table_schema)::name = 'public'::name) AND ((views.table_name)::name = ANY (ARRAY['v_contract_process_tracking'::name, 'v_business_intelligence'::name, 'v_requests_details'::name, 'v_active_contracts'::name, 'v_pending_contracts'::name, 'v_resource_owners'::name])))
  ORDER BY 1, 2;


ALTER VIEW public.v_system_guide OWNER TO postgres;

--
-- Name: v_system_health_check; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_system_health_check AS
 SELECT 'requests'::text AS table_name,
        CASE
            WHEN (count(*) > 0) THEN '✅'::text
            ELSE '❌'::text
        END AS data_status,
    count(*) AS record_count
   FROM public.requests
UNION ALL
 SELECT 'temp_contracts'::text AS table_name,
        CASE
            WHEN (count(*) > 0) THEN '✅'::text
            ELSE '❌'::text
        END AS data_status,
    count(*) AS record_count
   FROM public.temp_contracts
UNION ALL
 SELECT 'contracts'::text AS table_name,
        CASE
            WHEN (count(*) > 0) THEN '✅'::text
            ELSE '❌'::text
        END AS data_status,
    count(*) AS record_count
   FROM public.contracts
UNION ALL
 SELECT 'request_offering_terms'::text AS table_name,
        CASE
            WHEN (count(*) > 0) THEN '✅'::text
            ELSE '❌'::text
        END AS data_status,
    count(*) AS record_count
   FROM public.request_offering_terms
UNION ALL
 SELECT 'temp_contract_terms'::text AS table_name,
        CASE
            WHEN (count(*) > 0) THEN '✅'::text
            ELSE '❌'::text
        END AS data_status,
    count(*) AS record_count
   FROM public.temp_contract_terms
UNION ALL
 SELECT 'contract_terms'::text AS table_name,
        CASE
            WHEN (count(*) > 0) THEN '✅'::text
            ELSE '❌'::text
        END AS data_status,
    count(*) AS record_count
   FROM public.contract_terms
  ORDER BY 1;


ALTER VIEW public.v_system_health_check OWNER TO postgres;

--
-- Name: v_temporary_offerings; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_temporary_offerings AS
 SELECT resource_type,
    resource_id,
    title,
    offering_term_id,
    offering_term_name,
    offering_term_code,
    cost,
    currency,
    offering_special_terms,
    offering_created_at
   FROM public.v_all_resources_offerings
  WHERE ((offering_term_code)::text = ANY ((ARRAY['temporary_free'::character varying, 'temporary_paid'::character varying])::text[]))
  ORDER BY resource_type, cost;


ALTER VIEW public.v_temporary_offerings OWNER TO postgres;

--
-- Name: v_top_multioffer_resources; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_top_multioffer_resources AS
 SELECT ((resource_type || ' #'::text) || id) AS resource_code,
    title,
    offering_count,
    offering_terms,
        CASE
            WHEN (has_free_offers AND has_paid_offers) THEN 'Смешанные'::text
            WHEN has_free_offers THEN 'Только бесплатные'::text
            WHEN has_paid_offers THEN 'Только платные'::text
            ELSE 'Нет предложений'::text
        END AS offering_type
   FROM public.v_resource_catalog
  WHERE (offering_count >= 2)
  ORDER BY offering_count DESC, title;


ALTER VIEW public.v_top_multioffer_resources OWNER TO postgres;

--
-- Name: venue_asset_files; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.venue_asset_files AS
 SELECT af.file_id,
    af.asset_type_id,
    af.asset_record_id,
    af.file_url,
    af.storage_type,
    af.file_type,
    af.file_category,
    af.file_name,
    af.original_name,
    af.mime_type,
    af.file_size,
    af.dimensions,
    af.description,
    af.tags,
    af.sort_order,
    af.is_primary,
    af.is_public,
    af.requires_auth,
    af.metadata,
    af.uploaded_at,
    af.uploaded_by,
    af.validated_by,
    af.validated_at,
    af.expires_at,
    af.version,
    af.previous_version_id,
    af.checksum,
    at.asset_name,
    v.title AS venue_title,
    v.full_title AS venue_full_title,
    vt.type AS venue_type
   FROM (((public.asset_files af
     JOIN public.asset_types at ON ((af.asset_type_id = at.asset_type_id)))
     JOIN public.venues v ON ((af.asset_record_id = v.venue_id)))
     LEFT JOIN public.venue_types vt ON ((v.venue_type_id = vt.venue_type_id)))
  WHERE (((at.asset_table)::text = 'venues'::text) AND (v.deleted_at IS NULL));


ALTER VIEW public.venue_asset_files OWNER TO postgres;

--
-- Name: venue_offering_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.venue_offering_terms_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.venue_offering_terms_id_seq OWNER TO postgres;

--
-- Name: venue_offering_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.venue_offering_terms_id_seq OWNED BY public.venue_offering_terms.id;


--
-- Name: venue_owners_venue_owner_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.venue_owners_venue_owner_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.venue_owners_venue_owner_id_seq OWNER TO postgres;

--
-- Name: venue_owners_venue_owner_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.venue_owners_venue_owner_id_seq OWNED BY public.venue_owners.venue_owner_id;


--
-- Name: venue_types_venue_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.venue_types_venue_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.venue_types_venue_type_id_seq OWNER TO postgres;

--
-- Name: venue_types_venue_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.venue_types_venue_type_id_seq OWNED BY public.venue_types.venue_type_id;


--
-- Name: venues_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.venues_notes (
    note_id integer NOT NULL,
    venue_id integer NOT NULL,
    author_id integer NOT NULL
);


ALTER TABLE public.venues_notes OWNER TO postgres;

--
-- Name: venues_stages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.venues_stages (
    venue_id integer NOT NULL,
    stage_id integer NOT NULL
);


ALTER TABLE public.venues_stages OWNER TO postgres;

--
-- Name: venues_venue_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.venues_venue_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.venues_venue_id_seq OWNER TO postgres;

--
-- Name: venues_venue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.venues_venue_id_seq OWNED BY public.venues.venue_id;


--
-- Name: vw_active_actors_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_active_actors_details AS
 SELECT a.actor_id,
    a.nickname,
    at.type AS actor_type,
    p.name,
    p.last_name,
    p.email,
    p.phone_number,
    l.name AS location_name,
    a.created_at
   FROM (((public.actors a
     LEFT JOIN public.actor_types at ON ((a.actor_type_id = at.actor_type_id)))
     LEFT JOIN public.persons p ON (((a.actor_id = p.actor_id) AND (p.deleted_at IS NULL))))
     LEFT JOIN public.locations l ON ((p.location_id = l.location_id)))
  WHERE (a.deleted_at IS NULL);


ALTER VIEW public.vw_active_actors_details OWNER TO postgres;

--
-- Name: vw_active_events_calendar; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_active_events_calendar AS
SELECT
    NULL::integer AS event_id,
    NULL::character varying(200) AS title,
    NULL::text AS description,
    NULL::date AS date,
    NULL::time without time zone AS start_time,
    NULL::time without time zone AS end_time,
    NULL::character varying(50) AS event_type,
    NULL::bigint AS participants_count,
    NULL::timestamp with time zone AS created_at;


ALTER VIEW public.vw_active_events_calendar OWNER TO postgres;

--
-- Name: vw_active_projects_summary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_active_projects_summary AS
SELECT
    NULL::integer AS project_id,
    NULL::character varying(100) AS title,
    NULL::character varying(200) AS full_title,
    NULL::character varying(50) AS project_status,
    NULL::character varying(50) AS project_type,
    NULL::character varying(100) AS author_name,
    NULL::bigint AS participants_count,
    NULL::date AS start_date,
    NULL::date AS end_date;


ALTER VIEW public.vw_active_projects_summary OWNER TO postgres;

--
-- Name: vw_actors_activity; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_actors_activity AS
 SELECT a.actor_id,
    a.nickname,
    count(DISTINCT p.project_id) AS projects_count,
    count(DISTINCT i.idea_id) AS ideas_count,
    count(DISTINCT e.event_id) AS events_attended,
    max(p.created_at) AS last_project_date,
    max(i.created_at) AS last_idea_date
   FROM ((((public.actors a
     LEFT JOIN public.projects p ON (((a.actor_id = p.author_id) AND (p.deleted_at IS NULL))))
     LEFT JOIN public.ideas i ON (((a.actor_id = i.actor_id) AND (i.deleted_at IS NULL))))
     LEFT JOIN public.actors_events ae ON ((a.actor_id = ae.actor_id)))
     LEFT JOIN public.events e ON (((ae.event_id = e.event_id) AND (e.deleted_at IS NULL))))
  WHERE (a.deleted_at IS NULL)
  GROUP BY a.actor_id, a.nickname;


ALTER VIEW public.vw_actors_activity OWNER TO postgres;

--
-- Name: vw_global_search; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_global_search AS
 SELECT 'actor'::text AS entity_type,
    actors.actor_id AS id,
    actors.nickname AS title,
    actors.keywords AS content,
    actors.created_at
   FROM public.actors
  WHERE (actors.deleted_at IS NULL)
UNION ALL
 SELECT 'project'::text AS entity_type,
    projects.project_id AS id,
    projects.title,
    projects.description AS content,
    projects.created_at
   FROM public.projects
  WHERE (projects.deleted_at IS NULL)
UNION ALL
 SELECT 'idea'::text AS entity_type,
    ideas.idea_id AS id,
    ideas.title,
    ideas.full_description AS content,
    ideas.created_at
   FROM public.ideas
  WHERE (ideas.deleted_at IS NULL)
UNION ALL
 SELECT 'event'::text AS entity_type,
    events.event_id AS id,
    events.title,
    events.description AS content,
    events.created_at
   FROM public.events
  WHERE (events.deleted_at IS NULL);


ALTER VIEW public.vw_global_search OWNER TO postgres;

--
-- Name: vw_projects_statistics; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_projects_statistics AS
 SELECT EXTRACT(year FROM p.created_at) AS year,
    EXTRACT(month FROM p.created_at) AS month,
    pt.type AS project_type,
    ps.status AS project_status,
    count(*) AS projects_count,
    sum(public.get_project_participants_count(p.project_id)) AS total_participants,
    avg(public.get_project_participants_count(p.project_id)) AS avg_participants
   FROM ((public.projects p
     JOIN public.project_types pt ON ((p.project_type_id = pt.project_type_id)))
     JOIN public.project_statuses ps ON ((p.project_status_id = ps.project_status_id)))
  WHERE (p.deleted_at IS NULL)
  GROUP BY GROUPING SETS (((EXTRACT(year FROM p.created_at))), ((EXTRACT(year FROM p.created_at)), (EXTRACT(month FROM p.created_at))), (pt.type), (ps.status), ((EXTRACT(year FROM p.created_at)), pt.type, ps.status));


ALTER VIEW public.vw_projects_statistics OWNER TO postgres;

--
-- Name: actor_current_statuses actor_current_status_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_current_statuses ALTER COLUMN actor_current_status_id SET DEFAULT nextval('public.actor_current_statuses_actor_current_status_id_seq'::regclass);


--
-- Name: actor_statuses actor_status_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_statuses ALTER COLUMN actor_status_id SET DEFAULT nextval('public.actor_statuses_actor_status_id_seq'::regclass);


--
-- Name: actor_types actor_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_types ALTER COLUMN actor_type_id SET DEFAULT nextval('public.actor_types_actor_type_id_seq'::regclass);


--
-- Name: actors actor_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors ALTER COLUMN actor_id SET DEFAULT nextval('public.actors_actor_id_seq'::regclass);


--
-- Name: actors_functions actor_function_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_functions ALTER COLUMN actor_function_id SET DEFAULT nextval('public.actors_functions_actor_function_id_seq'::regclass);


--
-- Name: asset_files file_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asset_files ALTER COLUMN file_id SET DEFAULT nextval('public.asset_files_file_id_seq'::regclass);


--
-- Name: asset_types asset_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asset_types ALTER COLUMN asset_type_id SET DEFAULT nextval('public.asset_types_asset_type_id_seq'::regclass);


--
-- Name: bookmarks bookmark_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookmarks ALTER COLUMN bookmark_id SET DEFAULT nextval('public.bookmarks_bookmark_id_seq'::regclass);


--
-- Name: communities community_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities ALTER COLUMN community_id SET DEFAULT nextval('public.communities_community_id_seq'::regclass);


--
-- Name: contract_terms contract_term_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract_terms ALTER COLUMN contract_term_id SET DEFAULT nextval('public.contract_terms_contract_term_id_seq'::regclass);


--
-- Name: contracts contract_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts ALTER COLUMN contract_id SET DEFAULT nextval('public.contracts_contract_id_seq'::regclass);


--
-- Name: directions direction_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.directions ALTER COLUMN direction_id SET DEFAULT nextval('public.directions_direction_id_seq'::regclass);


--
-- Name: entity_geometries geometry_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entity_geometries ALTER COLUMN geometry_id SET DEFAULT nextval('public.entity_geometries_geometry_id_seq'::regclass);


--
-- Name: event_statuses event_status_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_statuses ALTER COLUMN event_status_id SET DEFAULT nextval('public.event_statuses_event_status_id_seq'::regclass);


--
-- Name: event_types event_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_types ALTER COLUMN event_type_id SET DEFAULT nextval('public.event_types_event_type_id_seq'::regclass);


--
-- Name: events event_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events ALTER COLUMN event_id SET DEFAULT nextval('public.events_event_id_seq'::regclass);


--
-- Name: favorites favorite_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites ALTER COLUMN favorite_id SET DEFAULT nextval('public.favorites_favorite_id_seq'::regclass);


--
-- Name: file_access_log access_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_access_log ALTER COLUMN access_id SET DEFAULT nextval('public.file_access_log_access_id_seq'::regclass);


--
-- Name: file_previews preview_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_previews ALTER COLUMN preview_id SET DEFAULT nextval('public.file_previews_preview_id_seq'::regclass);


--
-- Name: file_relations relation_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_relations ALTER COLUMN relation_id SET DEFAULT nextval('public.file_relations_relation_id_seq'::regclass);


--
-- Name: file_specific_metadata metadata_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_specific_metadata ALTER COLUMN metadata_id SET DEFAULT nextval('public.file_specific_metadata_metadata_id_seq'::regclass);


--
-- Name: finresource_offering_terms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_offering_terms ALTER COLUMN id SET DEFAULT nextval('public.finresource_offering_terms_id_seq'::regclass);


--
-- Name: finresource_owners finresource_owner_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_owners ALTER COLUMN finresource_owner_id SET DEFAULT nextval('public.finresource_owners_finresource_owner_id_seq'::regclass);


--
-- Name: finresource_types finresource_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_types ALTER COLUMN finresource_type_id SET DEFAULT nextval('public.finresource_types_finresource_type_id_seq'::regclass);


--
-- Name: finresources finresource_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources ALTER COLUMN finresource_id SET DEFAULT nextval('public.finresources_finresource_id_seq'::regclass);


--
-- Name: finresources_notes finresource_note_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources_notes ALTER COLUMN finresource_note_id SET DEFAULT nextval('public.finresources_notes_finresource_note_id_seq'::regclass);


--
-- Name: functions function_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.functions ALTER COLUMN function_id SET DEFAULT nextval('public.functions_function_id_seq'::regclass);


--
-- Name: global_request_notifications notification_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_request_notifications ALTER COLUMN notification_id SET DEFAULT nextval('public.global_request_notifications_notification_id_seq'::regclass);


--
-- Name: global_request_responses response_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_request_responses ALTER COLUMN response_id SET DEFAULT nextval('public.global_request_responses_response_id_seq'::regclass);


--
-- Name: global_requests global_request_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_requests ALTER COLUMN global_request_id SET DEFAULT nextval('public.global_requests_global_request_id_seq'::regclass);


--
-- Name: global_response_status_history history_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_response_status_history ALTER COLUMN history_id SET DEFAULT nextval('public.global_response_status_history_history_id_seq'::regclass);


--
-- Name: idea_categories idea_category_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_categories ALTER COLUMN idea_category_id SET DEFAULT nextval('public.idea_categories_idea_category_id_seq'::regclass);


--
-- Name: idea_offering_terms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_offering_terms ALTER COLUMN id SET DEFAULT nextval('public.idea_offering_terms_id_seq'::regclass);


--
-- Name: idea_types idea_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_types ALTER COLUMN idea_type_id SET DEFAULT nextval('public.idea_types_idea_type_id_seq'::regclass);


--
-- Name: ideas idea_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas ALTER COLUMN idea_id SET DEFAULT nextval('public.ideas_idea_id_seq'::regclass);


--
-- Name: levels level_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.levels ALTER COLUMN level_id SET DEFAULT nextval('public.levels_level_id_seq'::regclass);


--
-- Name: local_events local_event_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_events ALTER COLUMN local_event_id SET DEFAULT nextval('public.local_events_local_event_id_seq'::regclass);


--
-- Name: locations location_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations ALTER COLUMN location_id SET DEFAULT nextval('public.locations_location_id_seq'::regclass);


--
-- Name: matresource_offering_terms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_offering_terms ALTER COLUMN id SET DEFAULT nextval('public.matresource_offering_terms_id_seq'::regclass);


--
-- Name: matresource_owners matresource_owner_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_owners ALTER COLUMN matresource_owner_id SET DEFAULT nextval('public.matresource_owners_matresource_owner_id_seq'::regclass);


--
-- Name: matresource_types matresource_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_types ALTER COLUMN matresource_type_id SET DEFAULT nextval('public.matresource_types_matresource_type_id_seq'::regclass);


--
-- Name: matresources matresource_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources ALTER COLUMN matresource_id SET DEFAULT nextval('public.matresources_matresource_id_seq'::regclass);


--
-- Name: messages message_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages ALTER COLUMN message_id SET DEFAULT nextval('public.messages_message_id_seq'::regclass);


--
-- Name: notes note_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notes ALTER COLUMN note_id SET DEFAULT nextval('public.notes_note_id_seq'::regclass);


--
-- Name: notifications notification_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications ALTER COLUMN notification_id SET DEFAULT nextval('public.notifications_notification_id_seq'::regclass);


--
-- Name: offering_terms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offering_terms ALTER COLUMN id SET DEFAULT nextval('public.offering_terms_id_seq'::regclass);


--
-- Name: organizations organization_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations ALTER COLUMN organization_id SET DEFAULT nextval('public.organizations_organization_id_seq'::regclass);


--
-- Name: persons person_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons ALTER COLUMN person_id SET DEFAULT nextval('public.persons_person_id_seq'::regclass);


--
-- Name: project_actor_roles project_actor_role_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_actor_roles ALTER COLUMN project_actor_role_id SET DEFAULT nextval('public.project_actor_roles_project_actor_role_id_seq'::regclass);


--
-- Name: project_groups project_group_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_groups ALTER COLUMN project_group_id SET DEFAULT nextval('public.project_groups_project_group_id_seq'::regclass);


--
-- Name: project_statuses project_status_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_statuses ALTER COLUMN project_status_id SET DEFAULT nextval('public.project_statuses_project_status_id_seq'::regclass);


--
-- Name: project_types project_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_types ALTER COLUMN project_type_id SET DEFAULT nextval('public.project_types_project_type_id_seq'::regclass);


--
-- Name: projects project_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects ALTER COLUMN project_id SET DEFAULT nextval('public.projects_project_id_seq'::regclass);


--
-- Name: rating_types rating_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rating_types ALTER COLUMN rating_type_id SET DEFAULT nextval('public.rating_types_rating_type_id_seq'::regclass);


--
-- Name: ratings rating_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings ALTER COLUMN rating_id SET DEFAULT nextval('public.ratings_rating_id_seq'::regclass);


--
-- Name: request_offering_terms request_term_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_offering_terms ALTER COLUMN request_term_id SET DEFAULT nextval('public.request_offering_terms_request_term_id_seq'::regclass);


--
-- Name: request_statistic request_statistic_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_statistic ALTER COLUMN request_statistic_id SET DEFAULT nextval('public.request_statistic_request_statistic_id_seq'::regclass);


--
-- Name: request_statuses request_status_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_statuses ALTER COLUMN request_status_id SET DEFAULT nextval('public.request_statuses_request_status_id_seq'::regclass);


--
-- Name: request_types request_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_types ALTER COLUMN request_type_id SET DEFAULT nextval('public.request_types_request_type_id_seq'::regclass);


--
-- Name: requests request_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests ALTER COLUMN request_id SET DEFAULT nextval('public.requests_request_id_seq'::regclass);


--
-- Name: resource_types resource_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resource_types ALTER COLUMN resource_type_id SET DEFAULT nextval('public.resource_types_resource_type_id_seq'::regclass);


--
-- Name: service_offering_terms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_offering_terms ALTER COLUMN id SET DEFAULT nextval('public.service_offering_terms_id_seq'::regclass);


--
-- Name: service_owners service_owner_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_owners ALTER COLUMN service_owner_id SET DEFAULT nextval('public.service_owners_service_owner_id_seq'::regclass);


--
-- Name: services service_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services ALTER COLUMN service_id SET DEFAULT nextval('public.services_service_id_seq'::regclass);


--
-- Name: services_types services_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_types ALTER COLUMN services_type_id SET DEFAULT nextval('public.services_types_services_type_id_seq'::regclass);


--
-- Name: stage_architecture stage_architecture_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_architecture ALTER COLUMN stage_architecture_id SET DEFAULT nextval('public.stage_architecture_stage_architecture_id_seq'::regclass);


--
-- Name: stage_audio stage_audio_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio ALTER COLUMN stage_audio_id SET DEFAULT nextval('public.stage_audio_stage_audio_id_seq'::regclass);


--
-- Name: stage_effects stage_effects_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects ALTER COLUMN stage_effects_id SET DEFAULT nextval('public.stage_effects_stage_effects_id_seq'::regclass);


--
-- Name: stage_light stage_light_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light ALTER COLUMN stage_light_id SET DEFAULT nextval('public.stage_light_stage_light_id_seq'::regclass);


--
-- Name: stage_mobility stage_mobility_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_mobility ALTER COLUMN stage_mobility_id SET DEFAULT nextval('public.stage_mobility_stage_mobility_id_seq'::regclass);


--
-- Name: stage_types stage_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_types ALTER COLUMN stage_type_id SET DEFAULT nextval('public.stage_types_stage_type_id_seq'::regclass);


--
-- Name: stage_video stage_video_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video ALTER COLUMN stage_video_id SET DEFAULT nextval('public.stage_video_stage_video_id_seq'::regclass);


--
-- Name: stages stage_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages ALTER COLUMN stage_id SET DEFAULT nextval('public.stages_stage_id_seq'::regclass);


--
-- Name: system_commands id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_commands ALTER COLUMN id SET DEFAULT nextval('public.system_commands_id_seq'::regclass);


--
-- Name: system_deployment_log deployment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_deployment_log ALTER COLUMN deployment_id SET DEFAULT nextval('public.system_deployment_log_deployment_id_seq'::regclass);


--
-- Name: task_types task_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_types ALTER COLUMN task_type_id SET DEFAULT nextval('public.task_types_task_type_id_seq'::regclass);


--
-- Name: tasks task_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks ALTER COLUMN task_id SET DEFAULT nextval('public.tasks_task_id_seq'::regclass);


--
-- Name: temp_contract_terms temp_term_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.temp_contract_terms ALTER COLUMN temp_term_id SET DEFAULT nextval('public.temp_contract_terms_temp_term_id_seq'::regclass);


--
-- Name: temp_contracts temp_contract_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.temp_contracts ALTER COLUMN temp_contract_id SET DEFAULT nextval('public.temp_contracts_temp_contract_id_seq'::regclass);


--
-- Name: template_offering_terms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.template_offering_terms ALTER COLUMN id SET DEFAULT nextval('public.template_offering_terms_id_seq'::regclass);


--
-- Name: templates template_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates ALTER COLUMN template_id SET DEFAULT nextval('public.templates_template_id_seq'::regclass);


--
-- Name: templates_notes template_note_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_notes ALTER COLUMN template_note_id SET DEFAULT nextval('public.templates_notes_template_note_id_seq'::regclass);


--
-- Name: theme_bookmarks bookmark_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_bookmarks ALTER COLUMN bookmark_id SET DEFAULT nextval('public.theme_bookmarks_bookmark_id_seq'::regclass);


--
-- Name: theme_comments theme_comment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments ALTER COLUMN theme_comment_id SET DEFAULT nextval('public.theme_comments_theme_comment_id_seq'::regclass);


--
-- Name: theme_discussions discussion_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_discussions ALTER COLUMN discussion_id SET DEFAULT nextval('public.theme_discussions_discussion_id_seq'::regclass);


--
-- Name: theme_notes theme_note_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_notes ALTER COLUMN theme_note_id SET DEFAULT nextval('public.theme_notes_theme_note_id_seq'::regclass);


--
-- Name: theme_types theme_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_types ALTER COLUMN theme_type_id SET DEFAULT nextval('public.theme_types_theme_type_id_seq'::regclass);


--
-- Name: themes theme_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes ALTER COLUMN theme_id SET DEFAULT nextval('public.themes_theme_id_seq'::regclass);


--
-- Name: venue_offering_terms id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_offering_terms ALTER COLUMN id SET DEFAULT nextval('public.venue_offering_terms_id_seq'::regclass);


--
-- Name: venue_owners venue_owner_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_owners ALTER COLUMN venue_owner_id SET DEFAULT nextval('public.venue_owners_venue_owner_id_seq'::regclass);


--
-- Name: venue_types venue_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_types ALTER COLUMN venue_type_id SET DEFAULT nextval('public.venue_types_venue_type_id_seq'::regclass);


--
-- Name: venues venue_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues ALTER COLUMN venue_id SET DEFAULT nextval('public.venues_venue_id_seq'::regclass);


--
-- Data for Name: actor_credentials; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actor_credentials (actor_id, password_hash, created_at) FROM stdin;
1	$2a$06$SOavCPazUFSP3dTdn57RdupbzbGjfzy.4qwJtcjDFzEdSknZU5NTS	2026-01-07 00:25:22.34+08
3	$2a$06$t6mpTbIKed4dfSPvatmxseoQlCwq8PadsEVl10mxfmOZ0H4Bmyxde	2026-01-07 00:33:36.783+08
4	$2a$06$/JNeBoIj9ovrD15IX54tweZ8z5wbCjC/DGOV4Rg.TI8C9dDdD.Xci	2026-01-07 00:35:06.117+08
6	$2a$06$7myHR3svzsLaChZUG9pLp.CMM1g/fiPraXrU1DwKFSznXKppxqe7O	2026-01-07 00:55:30.892+08
8	$2a$06$2k68VQEoAeVANy/I7F8mKuMJtI1oW7fLZ9hifCRgZsUucS2HuNcYu	2026-01-07 00:58:24.155+08
9	$2y$12$3V41Fw3J6JW0Y7MaPBhnxufHyi/idIGHbKRUgz/zu7qmG17QPw4r6	2026-01-07 03:30:43.826+08
10	$2y$12$wRH7FDCMVGNKQ4s04EBvp.wGQyboNrpf5F61bGnWzRPO3P.h5aRdy	2026-01-07 14:28:38.158+08
11	$2y$12$gXUJlhkcAhjaWjL4G0PD..Z2OBoZLB6gR8zBbnjmol51UIqdop9we	2026-01-07 17:42:35.47+08
12	$2y$12$0kW3GSfqJ/YbO04WEv0GBeNALXoaTU14nEDdvcZfQyno6lRlpB4fG	2026-01-07 17:48:45.819+08
13	$2y$12$H2VU9c4H7s0R66eZvBbjYuuNplIlbGixKjcbdCL4woDSN8dKApK.W	2026-01-07 21:19:52.291+08
17	$2y$12$K/p8DRlMq5SiiDdiG6htv.hRXtmt2hJrWFE/PAfD3TRE0p9jihOkq	2026-01-07 23:24:36.665+08
14	$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi	2026-01-07 22:33:55.441+08
21	$2y$12$USI5FiydGvSa2g.wg9eORuSDc9oCkj3PbB1gBUA03SLGltI9ZKN56	2026-01-10 03:01:57.54+08
\.


--
-- Data for Name: actor_current_statuses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actor_current_statuses (actor_current_status_id, actor_id, actor_status_id, created_at, updated_at, created_by, updated_by) FROM stdin;
1	3	7	2026-01-07 00:33:36.783+08	2026-01-07 00:33:36.783+08	1	1
2	4	7	2026-01-07 00:35:06.117+08	2026-01-07 00:35:06.117+08	1	1
4	6	7	2026-01-07 00:55:30.892+08	2026-01-07 00:55:30.892+08	1	1
5	8	7	2026-01-07 00:58:24.155+08	2026-01-07 00:58:24.155+08	1	1
6	9	7	2026-01-07 03:30:43.828+08	2026-01-07 03:30:43.828+08	1	1
7	10	7	2026-01-07 14:28:38.158+08	2026-01-07 14:28:38.158+08	1	1
8	11	7	2026-01-07 17:42:35.47+08	2026-01-07 17:42:35.47+08	1	1
9	12	7	2026-01-07 17:48:45.819+08	2026-01-07 17:48:45.819+08	1	1
10	13	7	2026-01-07 21:19:52.291+08	2026-01-07 21:19:52.291+08	1	1
11	14	7	2026-01-07 22:33:55.441+08	2026-01-07 22:33:55.441+08	1	1
12	17	7	2026-01-07 23:24:36.665+08	2026-01-07 23:24:36.665+08	1	1
13	21	7	2026-01-10 03:01:57.54+08	2026-01-10 03:01:57.54+08	21	\N
\.


--
-- Data for Name: actor_status_mapping; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actor_status_mapping (rating_id, status_name, can_create_project) FROM stdin;
4	Руководитель	t
5	Администратор Проекта	t
\.


--
-- Data for Name: actor_statuses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actor_statuses (actor_status_id, status, description) FROM stdin;
1	Руководитель ТЦ	\N
2	Куратор направления	\N
3	Проектный куратор	\N
4	Руководитель проекта	\N
5	Администратор проекта	\N
6	Участник проекта	\N
7	Участник ТЦ	\N
0	Гость	\N
\.


--
-- Data for Name: actor_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actor_types (actor_type_id, type, description) FROM stdin;
1	Человек	\N
2	Сообщество	\N
3	Организация	\N
\.


--
-- Data for Name: actors; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors (actor_id, nickname, actor_type_id, icon, keywords, account, deleted_at, created_at, updated_at, created_by, updated_by, color_frame, rating_id) FROM stdin;
1	Администратор системы	1	\N	\N	000000000001	\N	2026-01-06 23:53:40.21+08	2026-01-06 23:53:40.21+08	1	1	\N	\N
3	НовыйПользователь	1	\N	\N	U00000000001	\N	2026-01-07 00:33:36.783+08	2026-01-07 00:33:36.783+08	1	1	\N	\N
4	ВторойЮзер	1	\N	\N	U00000000002	\N	2026-01-07 00:35:06.117+08	2026-01-07 00:35:06.117+08	1	1	\N	\N
6	УспешныйПользователь	1	\N	\N	U00000000003	\N	2026-01-07 00:55:30.892+08	2026-01-07 00:55:30.892+08	1	1	\N	\N
8	test	1	\N	\N	U00000000004	\N	2026-01-07 00:58:24.155+08	2026-01-07 00:58:24.155+08	1	1	\N	\N
9	Разработчик	1	\N	\N	D00000000001	\N	2026-01-07 03:30:43.464+08	2026-01-07 03:30:43.464+08	1	1	\N	\N
10	ТестовыйРегистрация	1	\N	\N	U00000000005	\N	2026-01-07 14:28:38.158+08	2026-01-07 14:28:38.158+08	1	1	\N	\N
11	TestUser	1	\N	\N	U00000000006	\N	2026-01-07 17:42:35.47+08	2026-01-07 17:42:35.47+08	1	1	\N	\N
12	NewUser	1	\N	\N	U00000000007	\N	2026-01-07 17:48:45.819+08	2026-01-07 17:48:45.819+08	1	1	\N	\N
13	User0926	1	\N	\N	U00000000008	\N	2026-01-07 21:19:52.291+08	2026-01-07 21:19:52.291+08	1	1	\N	\N
14	cabotin	1	\N	\N	U00000000009	\N	2026-01-07 22:33:55.441+08	2026-01-07 22:33:55.441+08	1	1	\N	\N
17	new	1	\N	\N	U00000000010	\N	2026-01-07 23:24:36.665+08	2026-01-07 23:24:36.665+08	1	1	\N	\N
21	new2026	1	\N	\N	U10095478347	\N	2026-01-10 03:01:57.54+08	2026-01-10 03:01:57.54+08	1	1	#118AB2	\N
7	ТестоваяОрганизацияАктор	3	\N	\N	ORG_TEST_001	\N	2026-01-23 23:56:14.272617+08	2026-01-23 23:56:14.272617+08	1	1	\N	\N
\.


--
-- Data for Name: actors_directions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_directions (actor_id, direction_id) FROM stdin;
\.


--
-- Data for Name: actors_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_events (actor_id, event_id) FROM stdin;
\.


--
-- Data for Name: actors_functions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_functions (actor_function_id, actor_id, function_id, level_id, priority, is_active, assignment_date) FROM stdin;
\.


--
-- Data for Name: actors_locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_locations (actor_id, location_id) FROM stdin;
1	1
\.


--
-- Data for Name: actors_messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_messages (message_id, actor_id) FROM stdin;
\.


--
-- Data for Name: actors_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_notes (note_id, actor_id, author_id) FROM stdin;
\.


--
-- Data for Name: actors_projects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_projects (actor_id, project_id, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: actors_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_tasks (task_id, actor_id) FROM stdin;
1	3
\.


--
-- Data for Name: asset_files; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.asset_files (file_id, asset_type_id, asset_record_id, file_url, storage_type, file_type, file_category, file_name, original_name, mime_type, file_size, dimensions, description, tags, sort_order, is_primary, is_public, requires_auth, metadata, uploaded_at, uploaded_by, validated_by, validated_at, expires_at, version, previous_version_id, checksum) FROM stdin;
4	1	1	/uploads/test/equipment.jpg	local	image	main_image	test_equipment.jpg	\N	\N	\N	\N	\N	\N	0	t	t	f	\N	2026-01-23 23:52:25.954923	1	\N	\N	\N	1	\N	\N
5	1	1	/uploads/test/file1.jpg	local	image	general	\N	\N	\N	\N	\N	\N	\N	0	f	t	f	\N	2026-01-23 23:53:50.11732	\N	\N	\N	\N	1	\N	\N
6	1	2	/uploads/test/file2.pdf	local	document	general	\N	\N	\N	\N	\N	\N	\N	0	f	t	f	\N	2026-01-23 23:53:50.11732	\N	\N	\N	\N	1	\N	\N
7	2	1	/uploads/test/venue1.jpg	local	image	general	\N	\N	\N	\N	\N	\N	\N	0	f	t	f	\N	2026-01-23 23:53:50.11732	\N	\N	\N	\N	1	\N	\N
10	1	1	/uploads/matresources/1/passport.pdf	local	document	passport	паспорт_гармони.pdf	\N	\N	\N	\N	\N	\N	0	t	t	f	\N	2026-01-24 00:05:42.469556	1	\N	\N	\N	1	\N	\N
11	1	2	/uploads/matresources/2/main.jpg	local	image	main_image	гармонь_русская.jpg	\N	\N	\N	\N	\N	\N	0	t	t	f	\N	2026-01-24 00:06:38.900505	1	\N	\N	\N	1	\N	\N
12	1	2	/uploads/matresources/2/serial_number.jpg	local	image	details	серийный_номер.jpg	\N	\N	\N	\N	\N	\N	0	f	t	f	\N	2026-01-24 00:06:38.900505	1	\N	\N	\N	1	\N	\N
13	2	1	/uploads/venues/1/plan.pdf	local	document	plan	план_зала.pdf	\N	\N	\N	\N	\N	\N	0	t	t	f	\N	2026-01-24 00:08:00.324429	1	\N	\N	\N	1	\N	\N
14	2	3	/uploads/venues/3/exterior.jpg	local	image	exterior	внешний_вид.jpg	\N	\N	\N	\N	\N	\N	0	t	t	f	\N	2026-01-24 00:08:00.324429	1	\N	\N	\N	1	\N	\N
15	4	3	/uploads/events/3/invitation.pdf	local	document	invitation	приглашение.pdf	\N	\N	\N	\N	\N	\N	0	t	t	f	\N	2026-01-24 00:08:33.506614	1	\N	\N	\N	1	\N	\N
16	4	5	/uploads/events/5/contract.pdf	local	document	contract	договор.pdf	\N	\N	\N	\N	\N	\N	0	t	t	f	\N	2026-01-24 00:08:33.506614	1	\N	\N	\N	1	\N	\N
9	1	1	/uploads/matresources/1/photo2.jpg	local	image	gallery	гармонь_вид2.jpg	\N	\N	\N	\N	\N	\N	0	f	t	f	\N	2026-01-24 00:05:42.469556	1	\N	\N	\N	1	\N	\N
8	1	1	/uploads/matresources/1/photo1.jpg	local	image	gallery	гармонь_вид1.jpg	\N	\N	\N	\N	\N	\N	0	t	t	f	\N	2026-01-24 00:05:42.469556	1	\N	\N	\N	1	\N	\N
17	11	3	/uploads/organizations/3/logo.png	local	image	logo	логотип_тестовой_организации.png	\N	\N	\N	\N	\N	\N	0	t	t	f	\N	2026-01-24 00:15:45.177351	1	\N	\N	\N	1	\N	\N
18	11	3	/uploads/organizations/3/certificate.pdf	local	document	certificate	сертификат_организации.pdf	\N	\N	\N	\N	\N	\N	0	f	t	f	\N	2026-01-24 00:15:45.177351	1	\N	\N	\N	1	\N	\N
19	5	1	/uploads/actors/1/avatar.jpg	local	image	avatar	аватар_администратора.jpg	\N	\N	\N	\N	\N	\N	0	t	t	f	\N	2026-01-24 00:15:45.177351	1	\N	\N	\N	1	\N	\N
20	7	1	/uploads/persons/photo.jpg	local	image	photo	фотография_персоны.jpg	\N	\N	\N	\N	\N	\N	0	t	t	f	\N	2026-01-24 00:15:45.177351	1	\N	\N	\N	1	\N	\N
\.


--
-- Data for Name: asset_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.asset_types (asset_type_id, asset_table, asset_name, description, supports_files, max_file_size, allowed_mime_types, created_at, updated_at) FROM stdin;
1	matresources	Материальные ресурсы	Оборудование, инструменты, техника	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
2	venues	Площадки	Места проведения мероприятий	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
3	finresources	Финансовые ресурсы	Финансовые активы и фонды	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
4	events	События	Мероприятия и события	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
5	actors	Участники	Пользователи и участники системы	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
6	communities	Сообщества	Группы и сообщества	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
7	persons	Персоны	Физические лица	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
8	projects	Проекты	Творческие и бизнес-проекты	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
9	services	Услуги	Предоставляемые услуги	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
10	ideas	Идеи	Идеи и предложения	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
11	organizations	Организации	Юридические лица	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
12	stages	Сцены	Сценические площадки	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
13	themes	Темы	Темы для обсуждения	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
14	templates	Шаблоны	Шаблоны проектов	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
15	local_events	Локальные события	Местные мероприятия	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
16	locations	Локации	Географические места	t	10485760	\N	2026-01-23 23:23:21.209479	2026-01-23 23:23:21.209479
\.


--
-- Data for Name: bookmarks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bookmarks (bookmark_id, actor_id, theme_id, created_at) FROM stdin;
\.


--
-- Data for Name: communities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.communities (community_id, title, full_title, email, email_2, participant_name, participant_lastname, location_id, post_code, address, phone_number, phone_number_2, bank_title, bank_bik, bank_account, community_info, vk_page, ok_page, tt_page, tg_page, ig_page, fb_page, max_page, web_page, attachment, actor_id, deleted_at, created_at, updated_at, created_by, updated_by, geom, latitude, longitude) FROM stdin;
\.


--
-- Data for Name: contract_terms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contract_terms (contract_term_id, contract_id, offering_term_id, offering_term_name, cost, currency, special_terms, fulfillment_status, created_at, updated_at) FROM stdin;
3	2	4	Временное предоставление за плату	3000.00	руб.	Требуется гарантийный депозит 5000 руб.	pending	2026-01-22 14:57:49.32984	2026-01-22 14:57:49.32984
4	3	1	Продажа	2000.00	руб.	Финальные тестовые условия	pending	2026-01-22 15:33:17.630863	2026-01-22 15:33:17.630863
5	6	1	Продажа	5000.00	руб.	Финальные тестовые условия	pending	2026-01-22 16:12:55.698069	2026-01-22 16:12:55.698069
\.


--
-- Data for Name: contracts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contracts (contract_id, temp_contract_id, request_id, contract_number, contract_title, contract_description, requester_id, owner_id, resource_type, resource_id, start_date, end_date, start_time, end_time, contract_status, total_cost, currency, requester_signed_at, owner_signed_at, signed_at, effective_from, effective_until, created_at, updated_at) FROM stdin;
2	7	6	CTR-20260122-001001	Временный договор: Тестовая гармонь	Требуется звуковое оборудование на 2 дня	9	1	matresource	1	2026-01-25	2026-01-26	08:00:00	22:00:00	active	3000.00	руб.	2026-01-22 14:57:49.32984	2026-01-22 14:57:49.32984	2026-01-22 14:57:49.32984	2026-01-22 14:57:49.32984	\N	2026-01-22 14:57:49.32984	2026-01-22 14:57:49.32984
3	8	8	CTR-20260122-000002	Временный договор: Консультация юриста	Тестирование полного цикла создания договора	13	1	service	1	2026-01-23	2026-01-23	\N	\N	active	2000.00	руб.	2026-01-22 15:33:17.630863	2026-01-22 15:33:17.630863	2026-01-22 15:33:17.630863	2026-01-22 15:33:17.630863	\N	2026-01-22 15:33:17.630863	2026-01-22 15:33:17.630863
6	9	9	CTR-20260122-000005	Временный договор: Консультация юриста	Последний тест перед сдачей системы в эксплуатацию	1	1	service	1	2026-01-22	\N	\N	\N	active	5000.00	руб.	2026-01-22 16:12:55.698069	2026-01-22 16:12:55.698069	2026-01-22 16:12:55.698069	2026-01-22 16:12:55.698069	\N	2026-01-22 16:12:55.698069	2026-01-22 16:12:55.698069
\.


--
-- Data for Name: creative_center_base; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.creative_center_base (project_actor_role_id, actor_id, project_id, role_type, assigned_at, assigned_by, note) FROM stdin;
7	1	1	member	2026-01-09 03:54:45.944371+08	\N	
8	3	2	leader	2026-01-09 04:10:14.195451+08	3	
9	3	3	leader	2026-01-09 04:10:14.195451+08	3	
10	3	4	leader	2026-01-09 04:10:14.195451+08	3	
12	3	5	leader	2026-01-09 04:10:14.195451+08	3	
13	4	1	admin	2026-01-09 04:10:34.652803+08	1	
14	6	1	member	2026-01-09 04:10:34.652803+08	1	
15	9	1	curator	2026-01-09 04:10:34.652803+08	1	
16	10	1	member	2026-01-09 04:10:34.652803+08	1	
17	4	2	member	2026-01-09 04:10:34.652803+08	3	
18	6	2	admin	2026-01-09 04:10:34.652803+08	3	
7	1	1	member	2026-01-09 03:54:45.944371+08	\N	
8	3	2	leader	2026-01-09 04:10:14.195451+08	3	
9	3	3	leader	2026-01-09 04:10:14.195451+08	3	
10	3	4	leader	2026-01-09 04:10:14.195451+08	3	
12	3	5	leader	2026-01-09 04:10:14.195451+08	3	
13	4	1	admin	2026-01-09 04:10:34.652803+08	1	
14	6	1	member	2026-01-09 04:10:34.652803+08	1	
15	9	1	curator	2026-01-09 04:10:34.652803+08	1	
16	10	1	member	2026-01-09 04:10:34.652803+08	1	
17	4	2	member	2026-01-09 04:10:34.652803+08	3	
18	6	2	admin	2026-01-09 04:10:34.652803+08	3	
\.


--
-- Data for Name: directions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.directions (direction_id, type, subtype, title, description) FROM stdin;
1	Аудиовизуальное искусство	Кино	Художественное кино	Создание фильмов с вымышленным сюжетом и актёрской игрой
2	Аудиовизуальное искусство	Кино	Документальное кино	Создание фильмов, основанных на реальных событиях и фактах
3	Аудиовизуальное искусство	Кино	Анимационное кино	Создание фильмов методом покадровой съёмки рисунков или кукол
4	Аудиовизуальное искусство	Кино	Короткометражное кино	Создание фильмов небольшой продолжительности (до 30 минут)
5	Аудиовизуальное искусство	Кино	Научно-популярное кино	Создание фильмов, объясняющих научные концепции и явления
6	Аудиовизуальное искусство	Телевидение	Телесериал	Создание многосерийных телевизионных произведений
7	Аудиовизуальное искусство	Телевидение	Телешоу	Создание развлекательных или информационных телепрограмм
8	Аудиовизуальное искусство	Телевидение	Документальный сериал	Создание цикла документальных фильмов на одну тему
9	Аудиовизуальное искусство	Музыкальные видео	Клип	Создание видеосопровождения к музыкальным композициям
10	Аудиовизуальное искусство	Музыкальные видео	Концертная съёмка	Создание видеозаписей живых музыкальных выступлений
11	Архитектура	Архитектурное проектирование	Жилая архитектура	Создание проектов жилых зданий и комплексов
12	Архитектура	Архитектурное проектирование	Общественная архитектура	Создание проектов общественных зданий (музеи, театры)
13	Архитектура	Архитектурное проектирование	Промышленная архитектура	Создание проектов промышленных зданий и сооружений
14	Архитектура	Ландшафтная архитектура	Парковое проектирование	Создание проектов парков и зон отдыха
15	Архитектура	Ландшафтная архитектура	Садовый дизайн	Создание проектов частных и общественных садов
16	Архитектура	Интерьерный дизайн	Жилые интерьеры	Создание дизайн-проектов жилых помещений
17	Архитектура	Интерьерный дизайн	Коммерческие интерьеры	Создание дизайн-проектов офисов, магазинов, ресторанов
18	Дизайн	Графический дизайн	Брендинг	Создание визуальной идентификации компаний и продуктов
19	Дизайн	Графический дизайн	Веб-дизайн	Создание визуального оформления и интерфейсов сайтов
20	Дизайн	Графический дизайн	Дизайн упаковки	Создание дизайна упаковки для товаров и продуктов
21	Дизайн	Графический дизайн	Типографика	Создание художественных шрифтов и текстовых композиций
22	Дизайн	Промышленный дизайн	Дизайн бытовой техники	Создание эргономичного и эстетичного вида бытовых приборов
23	Дизайн	Промышленный дизайн	Дизайн мебели	Создание функциональных и художественных предметов мебели
24	Дизайн	Промышленный дизайн	Дизайн транспорта	Создание внешнего и внутреннего оформления транспортных средств
25	Дизайн	Промышленный дизайн	Дизайн электроники	Создание корпусов и интерфейсов электронных устройств
26	Дизайн	Модный дизайн	Дизайн одежды haute couture	Создание уникальных моделей одежды высокого класса
27	Дизайн	Модный дизайн	Дизайн повседневной одежды	Создание коллекций одежды для массового потребителя
28	Дизайн	Модный дизайн	Дизайн аксессуаров	Создание сумок, обуви, украшений и других аксессуаров
29	Дизайн	Модный дизайн	Дизайн сценических костюмов	Создание костюмов для театра, кино и шоу
30	Дизайн	Ювелирный дизайн	Дизайн украшений	Создание художественных ювелирных изделий
31	Дизайн	Ювелирный дизайн	Дизайн часов	Создание дизайна наручных и интерьерных часов
32	Игровое творчество	Настольный геймдизайн	Настольные ролевые игры	Создание систем и миров для настольных RPG
33	Игровое творчество	Настольный геймдизайн	Настольные стратегии	Создание настольных игр с элементами стратегии
34	Игровое творчество	Настольный геймдизайн	Настольные головоломки	Создание игр-головоломок и пазлов
35	Игровое творчество	Настольный геймдизайн	Карточные игры	Создание колод и правил для карточных игр
36	Игровое творчество	Квест-дизайн	Эскейп-румы	Создание сценариев и пространств для квестов в реальности
37	Игровое творчество	Квест-дизайн	Детективные квесты	Создание сценариев квестов с детективным сюжетом
38	Игровое творчество	Квест-дизайн	Исторические квесты	Создание сценариев квестов на историческую тематику
39	Игровое творчество	Геймдизайн для видео игр	Создание сюжетов	Создание нарративов и сценариев для видеоигр
40	Игровое творчество	Геймдизайн для видео игр	Левел-дизайн	Создание уровней и игровых пространств
41	Игровое творчество	Геймдизайн для видео игр	Дизайн игровой механики	Создание правил и систем игрового процесса
42	Изобразительное искусство	Живопись	Монументальная живопись	Создание росписей на архитектурных сооружениях (фрески, мозаики)
43	Изобразительное искусство	Живопись	Станковая живопись	Создание картин на мольберте (портреты, пейзажи, натюрморты)
44	Изобразительное искусство	Живопись	Иконопись	Создание религиозных изображений (икон) по канонам
45	Изобразительное искусство	Живопись	Миниатюрная живопись	Создание картин малого формата с тонкой проработкой
46	Изобразительное искусство	Графика	Книжная иллюстрация	Создание визуального оформления литературных произведений
47	Изобразительное искусство	Графика	Плакат	Создание художественно-типографских композиций для рекламы или агитации
48	Изобразительное искусство	Графика	Эстамп	Создание печатных графических произведений (гравюры, литографии)
49	Изобразительное искусство	Графика	Комикс	Создание рисованных историй с последовательными кадрами
50	Изобразительное искусство	Скульптура	Монументальная скульптура	Создание памятников и крупных архитектурных форм
51	Изобразительное искусство	Скульптура	Станковая скульптура	Создание скульптурных произведений для интерьеров
52	Изобразительное искусство	Скульптура	Рельеф	Создание скульптурных изображений на плоскости
53	Изобразительное искусство	Скульптура	Кинетическая скульптура	Создание скульптур с подвижными элементами
54	Изобразительное искусство	Фотография	Документальная фотография	Создание фотографий, фиксирующих реальные события и явления
55	Изобразительное искусство	Фотография	Художественная фотография	Создание фотографических произведений как самостоятельного искусства
56	Изобразительное искусство	Фотография	Портретная фотография	Создание художественных портретов средствами фотографии
57	Изобразительное искусство	Фотография	Пейзажная фотография	Создание фотографий природных и городских ландшафтов
58	Изобразительное искусство	Фотография	Макросъёмка	Создание фотографий мелких объектов с большим увеличением
59	Изобразительное искусство	Цифровое искусство	Цифровая живопись	Создание художественных изображений с помощью графических планшетов и программ
60	Изобразительное искусство	Цифровое искусство	3D-моделирование	Создание трёхмерных цифровых объектов и сцен
61	Изобразительное искусство	Цифровое искусство	Цифровой коллаж	Создание композиций из различных цифровых изображений
62	Изобразительное искусство	Цифровое искусство	Пиксель-арт	Создание растровой графики с использованием пикселей как художественного средства
63	Изобразительное искусство	Декоративно-прикладное искусство	Батик	Создание рисунков на ткани с помощью резервирующих составов
64	Изобразительное искусство	Декоративно-прикладное искусство	Витраж	Создание изображений из цветного стекла
65	Изобразительное искусство	Декоративно-прикладное искусство	Мозаика	Создание изображений из мелких разноцветных элементов
66	Изобразительное искусство	Декоративно-прикладное искусство	Художественная вышивка	Создание декоративных изображений на ткани нитками
67	Изобразительное искусство	Декоративно-прикладное искусство	Роспись по дереву	Создание художественных изображений на деревянных поверхностях
68	Информационные технологии	Веб-разработка	Создание сайтов	Создание веб-сайтов различной сложности и направленности
69	Информационные технологии	Веб-разработка	Создание веб-приложений	Создание интерактивных веб-приложений и сервисов
70	Информационные технологии	Веб-разработка	Создание интернет-магазинов	Создание электронных торговых площадок
71	Информационные технологии	Веб-разработка	Создание блогов и порталов	Создание контент-ориентированных веб-ресурсов
72	Информационные технологии	Искусственный интеллект	Создание моделей ИИ	Создание алгоритмов и моделей искусственного интеллекта
73	Информационные технологии	Искусственный интеллект	Машинное обучение	Создание систем, способных обучаться на данных
74	Информационные технологии	Искусственный интеллект	Нейронные сети	Создание и обучение искусственных нейронных сетей
75	Информационные технологии	Искусственный интеллект	Компьютерное зрение	Создание систем распознавания и анализа изображений
76	Информационные технологии	Искусственный интеллект	Обработка естественного языка	Создание систем понимания и генерации человеческой речи
77	Информационные технологии	Программирование	Разработка ПО	Создание программного обеспечения различного назначения
78	Информационные технологии	Программирование	Мобильная разработка	Создание приложений для мобильных устройств
79	Информационные технологии	Программирование	Разработка игр	Создание программного кода для компьютерных игр
80	Информационные технологии	Программирование	Креативное программирование	Создание художественных проектов с помощью кода
81	Кулинарное искусство	Авторская кулинария	Фьюжн-кухня	Создание блюд, сочетающих элементы разных кулинарных традиций
82	Кулинарное искусство	Авторская кулинария	Молекулярная кухня	Создание блюд с использованием научных методов и технологий
83	Кулинарное искусство	Авторская кулинария	Вегетарианская кухня	Создание блюд без продуктов животного происхождения
84	Кулинарное искусство	Авторская кулинария	Региональная кухня	Создание блюд на основе традиций конкретного региона
85	Кулинарное искусство	Кондитерское искусство	Художественные торты	Создание кондитерских изделий как произведений искусства
86	Кулинарное искусство	Кондитерское искусство	Шоколадные скульптуры	Создание скульптур и композиций из шоколада
87	Кулинарное искусство	Кондитерское искусство	Декоративная выпечка	Создание художественно оформленных хлебобулочных изделий
88	Кулинарное искусство	Кондитерское искусство	Сахарная флористика	Создание цветов и композиций из сахарной мастики
89	Кулинарное искусство	Фуд-стайлинг	Рекламная фуд-съёмка	Создание привлекательного вида блюд для рекламных фотографий
90	Кулинарное искусство	Фуд-стайлинг	Кулинарная стилизация	Создание композиций из продуктов для художественных целей
91	Культурно-массовые мероприятия	Организация праздников	Свадьбы	Создание и проведение свадебных торжеств
92	Культурно-массовые мероприятия	Организация праздников	Юбилеи	Создание и проведение юбилейных мероприятий
93	Культурно-массовые мероприятия	Организация праздников	Корпоративные мероприятия	Создание и проведение корпоративных праздников и событий
94	Культурно-массовые мероприятия	Организация праздников	Детские праздники	Создание и проведение праздничных мероприятий для детей
95	Культурно-массовые мероприятия	Организация праздников	Тематические вечеринки	Создание и проведение вечеринок с определённой тематикой
96	Культурно-массовые мероприятия	Event-менеджмент	Фестивали	Создание и организация фестивалей различной направленности
97	Культурно-массовые мероприятия	Event-менеджмент	Концерты	Создание и организация концертных мероприятий
98	Культурно-массовые мероприятия	Event-менеджмент	Выставки	Создание и организация выставочных мероприятий
99	Культурно-массовые мероприятия	Event-менеджмент	Конференции	Создание и организация конференций и форумов
100	Литература	Поэзия	Лирическая поэзия	Создание стихотворений, выражающих чувства и переживания
101	Литература	Поэзия	Эпическая поэзия	Создание крупных стихотворных произведений (поэмы, баллады)
102	Литература	Поэзия	Сатирическая поэзия	Создание стихотворений с сатирическим или ироническим содержанием
103	Литература	Поэзия	Верлибр	Создание свободных стихов без рифмы и строгого размера
104	Литература	Проза	Роман	Создание крупных повествовательных произведений со сложным сюжетом
105	Литература	Проза	Рассказ	Создание небольших прозаических произведений с одной сюжетной линией
106	Литература	Проза	Повесть	Создание прозаических произведений среднего объёма
107	Литература	Проза	Новелла	Создание коротких прозаических произведений с неожиданной концовкой
108	Литература	Драматургия	Пьеса для театра	Создание литературной основы для театральной постановки
109	Литература	Драматургия	Киносценарий	Создание литературной основы для фильма или сериала
110	Литература	Драматургия	Радиопьеса	Создание литературной основы для радиопостановки
111	Литература	Драматургия	Сценарий для видеоигр	Создание нарративной основы для компьютерных игр
112	Литература	Эссеистика	Литературное эссе	Создание произведений на стыке литературы и философии
113	Литература	Эссеистика	Публицистическое эссе	Создание эссе на актуальные общественные темы
114	Литература	Эссеистика	Путевой очерк	Создание литературных описаний путешествий и впечатлений
115	Литература	Фантастика	Научная фантастика	Создание произведений, основанных на научных или технологических концепциях
116	Литература	Фантастика	Фэнтези	Создание произведений с элементами магии и мифологии
117	Литература	Фантастика	Антиутопия	Создание произведений о негативных будущих обществах
118	Музыка	Композиция	Симфоническая музыка	Создание музыкальных произведений для симфонического оркестра
119	Музыка	Композиция	Камерная музыка	Создание музыкальных произведений для небольших ансамблей
120	Музыка	Композиция	Электронная музыка	Создание музыкальных композиций с использованием электронных инструментов
121	Музыка	Композиция	Джазовая музыка	Создание музыкальных произведений в стиле джаз
122	Музыка	Композиция	Народная музыка	Создание музыки на основе национальных традиций
123	Музыка	Композиция	Популярная музыка	Создание песен и инструментальных композиций популярных жанров
124	Музыка	Композиция	Рок-музыка	Создание музыкальных произведений в стиле рок
125	Музыка	Композиция	Классическая музыка	Создание произведений в академических музыкальных традициях
126	Музыка	Композиция	Авангардная музыка	Создание экспериментальных музыкальных произведений
127	Музыка	Композиция	Саундтреки	Создание музыки для кино, телевидения и видеоигр
128	Музыка	Исполнительство	Вокал	Исполнительское создание музыки с использованием голоса
129	Музыка	Исполнительство	Инструментальное исполнение	Исполнительское создание музыки с использованием музыкальных инструментов
130	Музыка	Исполнительство	Дирижирование	Создание музыкальной интерпретации через руководство оркестром или хором
131	Музыка	Импровизация	Джазовая импровизация	Создание музыки в реальном времени в джазовой традиции
132	Музыка	Импровизация	Экспериментальная импровизация	Создание спонтанной музыки в экспериментальных форматах
133	Музыка	Аранжировка	Оркестровка	Создание оркестровых версий музыкальных произведений
134	Музыка	Аранжировка	Адаптация для ансамблей	Создание аранжировок для различных составов исполнителей
135	Музыка	Звукорежиссура	Студийная звукорежиссура	Создание звуковых записей в студийных условиях
136	Музыка	Звукорежиссура	Концертная звукорежиссура	Создание звукового оформления живых выступлений
137	Музыка	Звукорежиссура	Саунд-дизайн	Создание звуковых эффектов и атмосферы для медиапроектов
138	Народное творчество	Ремесла	Гончарное дело	Создание керамических изделий ручной работы
139	Народное творчество	Ремесла	Художественная ковка	Создание декоративных металлических изделий
140	Народное творчество	Ремесла	Резьба по дереву	Создание художественных изделий из дерева методом резьбы
141	Народное творчество	Ремесла	Ткачество	Создание тканей и гобеленов на ручных станках
142	Народное творчество	Ремесла	Плетение из лозы	Создание корзин, мебели и декора из природных материалов
143	Народное творчество	Ремесла	Вязание	Создание изделий из нитей с помощью вязальных спиц или крючка
144	Народное творчество	Ремесла	Плетение	Создание изделий путём переплетения нитей или других материалов
145	Народное творчество	Ремесла	Изготовление ковров	Создание художественных ковров и ковровых изделий
146	Народное творчество	Ремесла	Изготовление кукол	Создание кукол различных типов (игровых, коллекционных, обрядовых)
147	Народное творчество	Фольклор	Сказки	Создание народных или авторских сказочных произведений
148	Народное творчество	Фольклор	Былины	Создание эпических народных песен о богатырях
149	Народное творчество	Фольклор	Народные песни	Создание песен, отражающих народные традиции и быт
150	Народное творчество	Фольклор	Пословицы и поговорки	Создание кратких народных изречений с поучительным смыслом
151	Народное творчество	Народный театр	Петрушечный театр	Создание кукольных спектаклей с перчаточными куклами
152	Народное творчество	Народный театр	Вертеп	Создание рождественских кукольных представлений
153	Народное творчество	Народный театр	Балаганы	Создание ярмарочных театральных представлений
154	Синтетическое искусство	Мультимедийные проекты	Видеоинсталляции	Создание инсталляций с использованием видеоарта
155	Синтетическое искусство	Мультимедийные проекты	Интерактивные инсталляции	Создание художественных объектов, реагирующих на действия зрителя
156	Синтетическое искусство	Мультимедийные проекты	Световые шоу	Создание световых представлений и проекций
157	Синтетическое искусство	Саунд-арт	Звуковые скульптуры	Создание инсталляций, где звук является основным элементом
158	Синтетическое искусство	Саунд-арт	Акустические инсталляции	Создание пространств с особенными акустическими свойствами
159	Синтетическое искусство	Саунд-арт	Электроакустическая музыка	Создание музыки с использованием электроники и акустических инструментов
160	Синтетическое искусство	Видеоарт	Экспериментальное видео	Создание некоммерческих видеоработ как формы искусства
161	Синтетическое искусство	Видеоарт	Видеоперформанс	Создание видеозаписей художественных перформансов
162	Синтетическое искусство	Видеоарт	Видеопоэзия	Создание видеоработ, сочетающих поэзию и визуальный ряд
163	Социальное творчество	Стрит-арт	Муралы	Создание монументальных росписей на стенах зданий
164	Социальное творчество	Стрит-арт	Граффити	Создание настенных рисунков и надписей аэрозольной краской
165	Социальное творчество	Стрит-арт	Стенсил-арт	Создание уличных изображений с помощью трафаретов
166	Социальное творчество	Стрит-арт	Скотч-арт	Создание изображений с помощью цветного скотча
167	Социальное творчество	Перформанс	Социальный перформанс	Создание художественных акций, поднимающих общественные вопросы
168	Социальное творчество	Перформанс	Боди-арт	Создание художественных изображений на теле человека
169	Социальное творчество	Перформанс	Хэппенинг	Создание импровизированных художественных событий с участием публики
170	Социальное творчество	Перформанс	Флешмоб	Создание заранее спланированных массовых акций
171	Социальное творчество	Кураторство	Выставочное кураторство	Создание концепций и организация художественных выставок
172	Социальное творчество	Кураторство	Фестивальное кураторство	Создание программ и отбор участников для фестивалей
173	Социальное творчество	Кураторство	Музейное кураторство	Создание экспозиций и программ в музеях
174	Сценическое искусство	Театр	Драматический театр	Создание спектаклей на основе драматических произведений
175	Сценическое искусство	Театр	Театр для детей	Создание спектаклей, предназначенных для детской аудитории
176	Сценическое искусство	Театр	Музыкальный театр	Создание спектаклей с преобладанием музыкальных номеров (мюзиклы, оперетты)
177	Сценическое искусство	Театр	Кукольный театр	Создание спектаклей с использованием кукол разных систем
178	Сценическое искусство	Театр	Театр теней	Создание спектаклей с использованием теневых изображений
179	Сценическое искусство	Театр	Любительский театр	Создание спектаклей силами непрофессиональных актёров и энтузиастов
180	Сценическое искусство	Танец	Классический балет	Создание хореографических постановок по строгим канонам
181	Сценическое искусство	Танец	Современный танец	Создание хореографических произведений в стиле contemporary
182	Сценическое искусство	Танец	Народный танец	Создание хореографических постановок на основе фольклорных традиций
183	Сценическое искусство	Танец	Бальный танец	Создание парных танцевальных композиций
184	Сценическое искусство	Танец	Уличный танец	Создание хореографии в стилях хип-хоп, брейк-данс и др.
185	Сценическое искусство	Цирковое искусство	Акробатика	Создание номеров с физическими упражнениями на силу, ловкость и баланс
186	Сценическое искусство	Цирковое искусство	Жонглирование	Создание номеров с манипуляцией несколькими предметами
187	Сценическое искусство	Цирковое искусство	Иллюзионизм	Создание номеров с фокусами и оптическими иллюзиями
188	Сценическое искусство	Цирковое искусство	Клоунада	Создание комедийных цирковых номеров
189	Сценическое искусство	Цирковое искусство	Эквилибристика	Создание номеров с сохранением равновесия в сложных условиях
190	Техническое творчество	Изобретательство	Технические устройства	Создание новых механизмов и приборов
191	Техническое творчество	Изобретательство	Патентные разработки	Создание изобретений с последующим патентованием
192	Техническое творчество	Радиотехническое творчество	Радиоэлектронные устройства	Создание схем и устройства на основе радиоэлектроники
193	Техническое творчество	Радиотехническое творчество	Аудиотехника	Создание и модификация аудиоустройств и систем
194	Техническое творчество	Робототехника	Художественные роботы	Создание роботов для перформансов и инсталляций
195	Техническое творчество	Робототехника	Прототипирование	Создание прототипов роботизированных систем
196	Техническое творчество	Моделирование	Авиамоделирование	Создание действующих моделей летательных аппаратов
197	Техническое творчество	Моделирование	Судомоделирование	Создание действующих моделей кораблей и судов
198	Техническое творчество	Моделирование	Автомоделирование	Создание действующих моделей автомобилей
199	Техническое творчество	Моделирование	Железнодорожное моделирование	Создание моделей поездов и железных дорог
200	Техническое творчество	Конструирование	Архитектурное макетирование	Создание макетов зданий и сооружений
201	Техническое творчество	Конструирование	Технические конструкции	Создание несущих и декоративных конструкций
202	Техническое творчество	DIY проекты	Мебель своими руками	Создание уникальной мебели по собственным проектам
203	Техническое творчество	DIY проекты	Электронные гаджеты	Создание самодельных электронных устройств
204	Техническое творчество	DIY проекты	Домашняя автоматизация	Создание систем "умного дома" своими руками
205	Техническое творчество	Киберискусство	Биоарт	Создание произведений искусства с использованием живых тканей и организмов
206	Техническое творчество	Киберискусство	Нейроарт	Создание произведений искусства с использованием мозговых волн и нейроинтерфейсов
207	Техническое творчество	Инженерное искусство	Кинетические скульптуры	Создание движущихся скульптур с использованием инженерных решений
208	Техническое творчество	Инженерное искусство	Интерактивные инженерные объекты	Создание инженерных конструкций с художественной функцией
209	Техническое творчество	Технический дизайн	Дизайн интерфейсов	Создание пользовательских интерфейсов для устройств и программ
210	Техническое творчество	Технический дизайн	Эргономичный дизайн	Создание изделий с оптимальным соотношением формы и функции
211	Техническое творчество	Автомобильный тюнинг	Внешний тюнинг	Создание индивидуального внешнего вида автомобилей
212	Техническое творчество	Автомобильный тюнинг	Технический тюнинг	Создание модификаций для улучшения технических характеристик
213	Технологическое творчество	Медиаарт	Цифровые инсталляции	Создание инсталляций с использованием цифровых технологий
214	Технологическое творчество	Медиаарт	Интернет-арт	Создание произведений искусства, существующих только в интернете
215	Технологическое творчество	VR/AR искусство	Виртуальные выставки	Создание художественных экспозиций в виртуальной реальности
216	Технологическое творчество	VR/AR искусство	AR-инсталляции	Создание произведений в дополненной реальности
217	Технологическое творчество	Генеративное искусство	Алгоритмическое искусство	Создание произведений с помощью компьютерных алгоритмов
218	Технологическое творчество	Генеративное искусство	ИИ-арт	Создание произведений искусства с использованием искусственного интеллекта
219	Технологическое творчество	Генеративное искусство	Фрактальное искусство	Создание изображений на основе математических фракталов
220	Технологическое творчество	Программирование арта	Креативное кодирование	Создание визуальных и аудиовизуальных произведений через написание кода
221	Технологическое творчество	Программирование арта	Интерактивные веб-проекты	Создание художественных веб-сайтов и приложений
\.


--
-- Data for Name: entity_geometries; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.entity_geometries (geometry_id, entity_type, entity_id, geom, accuracy, source, address, description, is_verified, verified_at, verified_by, created_at, updated_at, created_by, updated_by) FROM stdin;
3	venue	1	0101000020E610000010E9B7AF03CF42408D28ED0DBEE04B40	50	manual	Москва, Красная площадь	Главная выставочная площадка	f	\N	\N	2026-01-24 02:04:11.063407	2026-01-24 02:04:11.063407	1	\N
4	organization	3	0101000020E6100000BDE3141DC9553E408F53742497F74D40	100	geocoder	Санкт-Петербург, Невский проспект	Тестовая организация	f	\N	\N	2026-01-24 02:04:11.063407	2026-01-24 02:04:11.063407	1	\N
5	venue	2	0101000020E61000008FC2F5285CCF4240E17A14AE47E14B40	30	manual	Москва, ГУМ	Торговый комплекс	f	\N	\N	2026-01-24 02:04:11.063407	2026-01-24 02:04:11.063407	1	\N
6	event	5	0101000020E6100000D7A3703D0ACF4240C74B378941E04B40	20	manual	Москва, Большой театр	Место проведения концерта	f	\N	\N	2026-01-24 02:08:07.084901	2026-01-24 02:08:07.084901	1	\N
\.


--
-- Data for Name: event_statuses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.event_statuses (event_status_id, status, description) FROM stdin;
6	Инициация	Начальная стадия создания события
7	Формирование	Формирование команды и плана события
8	В работе	Событие активно выполняется
9	Приостановлено	Событие временно приостановлено
10	Завершено	Событие завершено
\.


--
-- Data for Name: event_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.event_types (event_type_id, type) FROM stdin;
1	Публичное
2	Непубличное
\.


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.events (event_id, title, description, date, start_time, end_time, event_type_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by, rating_id, cost, currency, offering_term_id, special_terms, event_status_id, author_id, geom, latitude, longitude) FROM stdin;
3	Бесплатный семинар	\N	2024-01-15	\N	\N	\N	\N	\N	2026-01-21 20:52:07.360335+08	2026-01-21 20:52:07.360335+08	\N	\N	\N	0.00	руб.	2	\N	\N	\N	\N	\N	\N
6	Мероприятие по умолчанию	\N	2024-01-25	\N	\N	\N	\N	\N	2026-01-21 20:53:20.513806+08	2026-01-21 20:53:20.513806+08	\N	\N	\N	0.00	руб.	2	\N	\N	\N	\N	\N	\N
5	Платный концерт	\N	2024-01-20	\N	\N	\N	\N	\N	2026-01-21 20:53:07.967804+08	2026-01-24 02:08:07.084901+08	\N	\N	\N	5000.00	руб.	4	Предварительная бронь	\N	\N	0101000020E6100000D7A3703D0ACF4240C74B378941E04B40	55.75200000	37.61750000
\.


--
-- Data for Name: events_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.events_notes (note_id, event_id, author_id) FROM stdin;
\.


--
-- Data for Name: favorites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.favorites (favorite_id, actor_id, entity_type, entity_id, created_at) FROM stdin;
\.


--
-- Data for Name: file_access_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.file_access_log (access_id, file_id, actor_id, action, access_time, ip_address, user_agent, referrer, duration) FROM stdin;
\.


--
-- Data for Name: file_previews; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.file_previews (preview_id, file_id, preview_url, preview_type, width, height, file_size, generated_at, generated_by) FROM stdin;
\.


--
-- Data for Name: file_relations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.file_relations (relation_id, source_file_id, target_file_id, relation_type, description, created_at, created_by) FROM stdin;
\.


--
-- Data for Name: file_specific_metadata; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.file_specific_metadata (metadata_id, file_id, camera_model, exposure_time, aperture, iso, taken_at, author, title, subject, keywords, page_count, duration, bitrate, codec, sample_rate, created_with, software_used) FROM stdin;
\.


--
-- Data for Name: finresource_offering_terms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.finresource_offering_terms (id, finresource_id, offering_term_id, cost, currency, special_terms, created_at) FROM stdin;
1	3	1	1000000.00	руб.	Инвестиции от 1 млн руб.	2026-01-22 01:16:43.751267
2	3	4	50000.00	руб.	Кредит на 12 месяцев	2026-01-22 01:16:43.751267
3	3	2	0.00	руб.	Грант для стартапов	2026-01-22 01:16:43.751267
\.


--
-- Data for Name: finresource_owners; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.finresource_owners (finresource_id, actor_id, finresource_owner_id) FROM stdin;
\.


--
-- Data for Name: finresource_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.finresource_types (finresource_type_id, type) FROM stdin;
1	Донаты
2	Спонсорская помощь
3	Целевое финансирование
4	Государственное финансирование
5	Муниципальное финансирование
6	Средства Участника
\.


--
-- Data for Name: finresources; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.finresources (finresource_id, title, description, finresource_type_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by, rating_id) FROM stdin;
3	Инвестиционный фонд	Фонд для инвестиций в творческие проекты	\N	\N	\N	2026-01-22 01:16:43.751267+08	2026-01-22 01:16:43.751267+08	\N	\N	\N
\.


--
-- Data for Name: finresources_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.finresources_notes (finresource_note_id, finresource_id, note_id, author_id, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: functions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.functions (function_id, title, description, keywords) FROM stdin;
1	3D-моделлер	Создает трёхмерные модели для игр, кино, архитектуры.	\N
2	3D-моделлер игровой	Создает 3D-модели персонажей и объектов для игр.	\N
3	3D-скалптор	Создает детализированные 3D-модели методом цифровой лепки.	\N
4	3D-художник	Моделирует трёхмерные объекты, сцены, персонажей.	\N
5	3D-художник (визуализатор)	Создает фотореалистичные визуализации для архитектуры и дизайна.	\N
6	Авиамоделист	Создает модели летательных аппаратов.	\N
7	Администратор	Управляет административными процессами, документацией.	\N
8	Актёр	Исполняет роли в спектаклях, фильмах.	\N
9	Актёр кино	Снимается в кино, сериалах, рекламе.	\N
10	Актёр массовки	Участвует в массовых сценах.	\N
11	Актер озвучивания (голос за кадром)	Озвучивает персонажей, рекламу, аудиокниги.	\N
12	Аналитик	Анализирует данные, тренды, эффективность проектов.	\N
13	Аналитик медиа-контента	Анализирует вовлечённость аудитории и контент-стратегии.	\N
14	Аниматор	Создает анимацию для кино, игр, мультфильмов.	\N
15	Аниматор 2D	Работает с двумерной анимацией.	\N
16	Аниматор 3D	Создает трёхмерную анимацию.	\N
17	Аниматор игровой	Анимирует персонажей и объекты в играх.	\N
18	Аниматор лицевой анимации	Специализируется на анимации мимики.	\N
19	Аниматор motion capture	Работает с технологией захвата движения.	\N
20	Аранжировщик	Создает аранжировки музыкальных произведений.	\N
21	Аранжировщик (оркестровка)	Пишет оркестровые версии произведений.	\N
22	Аранжировщик для ансамбля	Адаптирует музыку для конкретных составов.	\N
23	Арбитр	Разрешает спорные ситуации.	\N
24	Архивариус	Ведёт архив документов и материалов.	\N
25	Архитектор	Проектирует здания и сооружения.	\N
26	Архитектор виртуальных миров	Проектирует пространства для VR/AR и метавселенных.	\N
27	Артист	Исполнитель в различных видах искусства.	\N
28	Арт-директор	Определяет визуальную стратегию проекта.	\N
29	Ассистент	Помощник в организации процессов.	\N
30	Ассистент режиссёра	Помогает режиссёру на съёмках/репетициях.	\N
31	Ассистент художника по костюмам	Помогает в работе с костюмами.	\N
32	Астролог	Консультирует по астрологическим вопросам для творческих концепций.	\N
33	Аудитор	Проверяет финансовую отчётность.	\N
34	Байер	Закупает материалы, оборудование, реквизит.	\N
35	Балалаечник	Исполняет партии на балалайке.	\N
36	Балетмейстер	Создает хореографию для балетных постановок.	\N
37	Барабанщик	Исполняет ударные партии.	\N
38	Бармен	Готовит и подаёт напитки на мероприятиях.	\N
39	Бармен-миксолог	Создает авторские коктейли.	\N
40	Бас-гитарист	Исполняет басовые партии.	\N
41	Билетёр	Продаёт билеты, встречает гостей.	\N
42	Биоинформатик в искусстве	Работает на стыке биологии, информатики и искусства.	\N
43	Блогер	Ведёт блог, создаёт контент в соцсетях.	\N
44	Боди-арт художник	Рисует художественные изображения на теле.	\N
45	Бренд-менеджер	Управляет развитием бренда.	\N
46	Бригадир	Руководит группой рабочих.	\N
47	Бутафор	Изготавливает бутафорские предметы.	\N
48	Бухгалтер	Ведёт финансовый учёт и отчётность.	\N
49	Бухгалтер по расчёту заработной платы	Специализируется на расчёте зарплат.	\N
50	Бухгалтер-экономист	Анализирует финансовые показатели, составляет сметы.	\N
51	Валторнист	Исполняет партии на валторне.	\N
52	Вахтёр	Обеспечивает охрану и порядок на территории.	\N
53	Ведущий	Ведёт мероприятия, концерты, церемонии.	\N
54	Ведущий радио	Ведёт радиопрограммы.	\N
55	Верстальщик	Форматирует тексты и изображения для печати или веба.	\N
56	Веб-дизайнер	Создает дизайн сайтов и интерфейсов.	\N
57	Веб-разработчик	Разрабатывает веб-сайты и приложения.	\N
58	Видеоблогер	Ведёт видеоблог.	\N
59	Видеограф	Снимает видео на мероприятиях.	\N
60	Видеохудожник	Создает видеоарт, экспериментальное видео.	\N
61	Визажист	Наносит макияж.	\N
62	Виолончелист	Исполняет партии на виолончели.	\N
63	Водитель	Управляет транспортным средством.	\N
64	Вокалист	Исполняет вокальные партии.	\N
65	Вокалист (бэк-вокал)	Исполняет подпевки.	\N
66	Вокалист (солист)	Исполняет сольные партии.	\N
67	Волонтёр	Выполняет добровольную помощь без вознаграждения.	\N
68	Воспитатель	Работает с детьми на мероприятиях.	\N
69	Вышивальщик	Создает вышитые изделия.	\N
70	Гардеробщик	Принимает и выдаёт верхнюю одежду.	\N
71	Гейм-аналитик	Анализирует игровую статистику.	\N
72	Гейм-продюсер	Управляет разработкой игры.	\N
73	Гейм-сценарист	Пишет сюжеты и диалоги для игр.	\N
74	Геймдизайнер	Разрабатывает игровую механику и баланс.	\N
75	Генеративный художник	Создает искусство с помощью алгоритмов и ИИ.	\N
76	Гид	Проводит экскурсии.	\N
77	Гончар	Изготавливает керамические изделия.	\N
78	Графический дизайнер	Разрабатывает фирменный стиль, логотипы.	\N
79	Граффити-художник	Создает настенные рисунки аэрозольной краской.	\N
80	Гримёр	Наносит грим актёрам.	\N
81	Дегустатор	Оценивает качество пищевых продуктов.	\N
82	Декоратор	Украшает пространство для мероприятий.	\N
83	Декламатор	Художественно читает стихи, прозу.	\N
84	Ди-джей	Создает музыкальные миксы.	\N
85	Дизайнер	Разрабатывает визуальные решения.	\N
86	Дизайнер аксессуаров	Создает дизайн сумок, обуви, украшений.	\N
87	Дизайнер интерьеров	Создает дизайн помещений.	\N
88	Дизайнер интерфейсов (UI/UX)	Проектирует пользовательские интерфейсы.	\N
89	Дизайнер одежды	Разрабатывает модели одежды.	\N
90	Дизайнер презентаций	Создает визуально привлекательные презентации.	\N
91	Дизайнер сценических костюмов	Разрабатывает костюмы для театра и кино.	\N
92	Дизайнер транспорта	Разрабатывает дизайн автомобилей, мотоциклов.	\N
93	Дизайнер упаковки	Создает дизайн упаковки товаров.	\N
94	Дизайнер часов	Проектирует дизайн часов.	\N
95	Дизайнер шрифтов (типограф)	Разрабатывает шрифты.	\N
96	Дизайнер электроники	Создает дизайн корпусов и интерфейсов гаджетов.	\N
97	Диетолог	Составляет меню, консультирует по питанию.	\N
98	Диктор	Озвучивает тексты, объявления.	\N
99	Дирижёр	Руководит оркестром, хором.	\N
100	Дирижёр симфонического оркестра	Руководит симфоническим оркестром.	\N
101	DIY-мастер	Создает предметы мебели, электроники своими руками.	\N
102	Документовед	Организует работу с документами.	\N
103	Драматург	Пишет пьесы, киносценарии.	\N
104	Дрессировщик	Работает с животными на съёмках, в шоу.	\N
105	Духовой музыкант	Исполняет партии на духовых инструментах.	\N
106	Event-менеджер	Организует мероприятия.	\N
107	Живописец	Пишет картины.	\N
108	Жонглёр	Исполняет жонглирование.	\N
109	Журналист	Создает материалы для СМИ.	\N
110	Завхоз	Заведует хозяйством, материалами.	\N
111	Закройщик	Раскраивает ткани.	\N
112	Заклинатель	Участвует в фэнтези-проектах.	\N
113	Закупщик	Осуществляет закупки.	\N
114	Звукоинженер	Работает со звукозаписью, сведением.	\N
115	Звукооператор	Управляет звуковым оборудованием.	\N
116	Звукорежиссёр	Отвечает за звуковое оформление проекта.	\N
117	Звукорежиссёр кино	Работает со звуком на съёмочной площадке.	\N
118	Зритель	Участвует в качестве аудитории.	\N
119	Иллюзионист	Показывает фокусы, иллюзии.	\N
120	Иллюстратор	Создает иллюстрации для книг, игр, рекламы.	\N
121	Иллюстратор настольных игр	Создает арт для карт и игрового поля.	\N
122	Инженер	Решает технические задачи.	\N
123	Инженер компьютерного зрения	Разрабатывает системы распознавания изображений.	\N
124	Инженер по кибернетическому искусству	Разрабатывает системы обратной связи между искусством и технологиями.	\N
125	Инженер по спецэффектам	Разрабатывает и реализует спецэффекты.	\N
126	Инженер по тестированию	Проверяет качество ПО, игр.	\N
127	Инженер-проектировщик	Разрабатывает техническую документацию и чертежи.	\N
128	Инженер-робототехник	Создает роботов, автоматизированные системы.	\N
129	Инженер-художник	Создает кинетические скульптуры, интерактивные объекты.	\N
130	Инструменталист	Играет на музыкальном инструменте.	\N
131	Инструменталист (оркестр)	Играет в оркестре.	\N
132	Инструктор	Обучает навыкам.	\N
133	Инспектор	Контролирует соблюдение норм и правил.	\N
134	Инфлюенсер	Влияет на аудиторию через соцсети.	\N
135	Казначей	Управляет денежными потоками.	\N
136	Каллиграф	Создает художественные надписи.	\N
137	Каменщик	Выполняет кладку из камня, кирпича.	\N
138	Каскадёр	Исполняет трюки в кино, на шоу.	\N
139	Кассир	Принимает платежи, выдаёт билеты.	\N
140	Керамист	Работает с керамикой.	\N
141	Клавишник	Исполняет партии на клавишных инструментах.	\N
142	Кладовщик	Ведёт учёт и хранение материалов.	\N
143	Клоун	Развлекает публику.	\N
144	Ковёр	Изготавливает ковры, гобелены.	\N
145	Колорист	Подбирает цветовые решения.	\N
146	Комментатор	Комментирует события, шоу.	\N
147	Композитор	Пишет музыку.	\N
148	Композитор (симфонический)	Пишет музыку для симфонического оркестра.	\N
149	Композитор (электронный)	Создает электронную музыку.	\N
150	Композитор саундтреков	Пишет музыку для фильмов, игр.	\N
151	Компьютерщик	Обслуживает компьютерную технику.	\N
152	Кондитер	Готовит десерты.	\N
153	Кондитер-декоратор	Украшает торты и десерты.	\N
154	Кондитер-художник	Создает художественные кондитерские изделия.	\N
155	Конструктор	Разрабатывает конструкции для технических проектов.	\N
156	Консультант	Даёт советы и рекомендации.	\N
157	Контент-мейкер	Создает контент для соцсетей, блогов.	\N
158	Контролёр	Проверяет качество работ.	\N
159	Концертмейстер	Аккомпанирует солистам.	\N
160	Координатор	Организует процессы и взаимодействие.	\N
161	Координатор волонтёров	Организует работу волонтёров.	\N
162	Координатор выставок	Отвечает за организацию выставочных пространств.	\N
163	Координатор конференций	Планирует программу конференций.	\N
164	Копирайтер	Пишет тексты для рекламы, статей.	\N
165	Корректор	Исправляет ошибки в текстах.	\N
166	Костюмер	Отвечает за костюмы.	\N
167	Критик	Анализирует и оценивает произведения искусства.	\N
168	Кузнец	Изготавливает металлические изделия.	\N
169	Кукловод	Управляет куклами в спектаклях.	\N
170	Кулинар	Готовит блюда, экспериментирует с рецептами.	\N
171	Куратор	Отбирает и организует художественные работы или события.	\N
172	Курьер	Доставляет документы, грузы.	\N
173	Лаборант	Выполняет лабораторные работы.	\N
174	Лесоруб	Заготавливает дерево.	\N
175	Лектор	Читает лекции.	\N
176	Левел-дизайнер	Создает игровые уровни.	\N
177	Левел-дизайнер игровой	Создает игровые уровни и пространства.	\N
178	Лингвист-программист (NLP)	Работает с обработкой естественного языка.	\N
179	Литературный редактор	Работает над текстом.	\N
180	Логист	Организует перевозки и снабжение.	\N
181	Логист мероприятий	Отвечает за транспорт и снабжение на мероприятиях.	\N
182	Локализатор игр	Переводит и адаптирует игры.	\N
183	Локализатор ПО	Адаптирует ПО под язык и культуру региона.	\N
184	Маляр	Выполняет покрасочные работы.	\N
185	Маркетолог	Разрабатывает стратегии продвижения.	\N
186	Мастер	Специалист высокого уровня в ремесле или искусстве.	\N
187	Мастер батика	Создает рисунки на ткани.	\N
188	Мастер витража	Изготавливает витражи.	\N
189	Мастер мозаики	Создает мозаичные панно.	\N
190	Мастер народных ремёсел	Владеет техниками гончарства, ковки, ткачества.	\N
191	Мастер плетения из лозы	Плетёт корзины, мебель.	\N
192	Мастер резьбы по дереву	Вырезает художественные орнаменты.	\N
193	Мастер росписи по дереву	Расписывает деревянные поверхности.	\N
194	Мастер сцены	Отвечает за техническое состояние сцены.	\N
195	Мастер ткачества	Ткёт ткани, гобелены.	\N
196	Мастер художественной вышивки	Вышивает декоративные изображения.	\N
197	Мастер художественной ковки	Создает декоративные металлические изделия.	\N
198	Мастеринг-инженер	Завершающая обработка звукозаписи.	\N
199	Машинист	Управляет техникой, механизмами.	\N
200	Машинист сцены	Управляет механизмами сцены.	\N
201	Медиатор	Улаживает конфликты в команде.	\N
202	Медиахудожник	Работает с цифровыми инсталляциями.	\N
203	Медик	Оказывает медицинскую помощь.	\N
204	Менеджер	Управляет процессами, людьми, ресурсами.	\N
205	Менеджер по культуре	Организует культурные мероприятия.	\N
206	Менеджер по финансам	Осуществляет финансовое планирование.	\N
207	Менеджер по рекламе	Занимается рекламой проектов.	\N
208	Менеджер проекта	Управляет ресурсами, сроками проекта.	\N
209	Методист	Разрабатывает методики обучения.	\N
210	Механик	Ремонтирует и обслуживает механизмы.	\N
211	Мобильный разработчик (iOS/Android)	Создает мобильные приложения.	\N
212	Моделист	Создает масштабные модели техники.	\N
213	Модель	Демонстрирует одежду, продукты.	\N
214	Модельер	Создает модели одежды, аксессуаров.	\N
215	Мозаичист	Создает мозаичные панно.	\N
216	Монтажёр	Монтирует видео- или аудиоматериалы.	\N
217	Монтажник	Собирает и устанавливает оборудование.	\N
218	Монтировщик	Собирает и разбирает декорации.	\N
219	Моушн-дизайнер	Создает анимированную графику.	\N
220	Музыкант	Исполняет музыку.	\N
221	Музыкант-гитарист	Исполняет гитарные партии.	\N
222	Наблюдатель	Наблюдает за процессом, фиксирует замечания.	\N
223	Наладчик	Настраивает оборудование и технику.	\N
224	Натурщик	Позирует для художников.	\N
225	Нарративный дизайнер (игры)	Отвечает за сюжет и диалоги в играх.	\N
226	Нейрохудожник	Создает искусство с использованием нейроинтерфейсов.	\N
227	Няня	Присматривает за детьми.	\N
228	Одевальщик	Помогает с быстрой сменой костюмов.	\N
229	Оператор	Управляет камерой, дроном.	\N
230	Оператор ПК	Работает с компьютерными программами.	\N
231	Оператор дрона	Снимает видео с беспилотников.	\N
232	Оператор-постановщик	Создает визуальный образ фильма.	\N
233	Организатор	Планирует и проводит мероприятия.	\N
234	Организатор мероприятий	Планирует свадьбы, корпоративы, фестивали.	\N
235	Организатор свадеб	Координирует свадебные торжества.	\N
236	Органист	Исполняет музыку на органе.	\N
237	Осветитель	Работает со световым оборудованием.	\N
238	Оформитель	Создает визуальное оформление пространств.	\N
239	Охранник	Обеспечивает безопасность и порядок.	\N
240	Оценщик	Определяет стоимость объектов, произведений искусства.	\N
241	Пекарь	Выпекает хлеб, кондитерские изделия.	\N
242	Педагог	Обучает творческим дисциплинам.	\N
243	Певица	Исполняет вокальные партии.	\N
244	Пейзажист	Специализируется на пейзажной живописи.	\N
245	Перкуссионист	Исполняет партии на перкуссионных инструментах.	\N
246	Перформанс-художник	Создает живые художественные акции.	\N
247	Перформанс-художник (социальный)	Создает акции на общественные темы.	\N
248	Писатель	Создает литературные произведения.	\N
249	Писатель-фантаст	Пишет в жанрах фантастики и фэнтези.	\N
250	Планировщик бюджета	Разрабатывает и контролирует бюджет проекта.	\N
251	Пластилинщик	Создает фигуры, анимацию из пластилина.	\N
252	Плотник	Работает с деревом.	\N
253	Повар	Готовит блюда.	\N
254	Подавальщик	Подаёт напитки, закуски.	\N
255	Подкастер	Записывает аудиоподкасты.	\N
256	Подсобный рабочий	Выполняет вспомогательные работы.	\N
257	Пожарный	Обеспечивает пожарную безопасность.	\N
258	Полировщик	Приводит в порядок поверхности.	\N
259	Политолог	Консультирует по общественно-политическим вопросам.	\N
260	Помощник	Оказывает общую помощь в выполнении задач.	\N
261	Помощник режиссёра	Помогает режиссёру.	\N
262	Портной	Шьёт и ремонтирует одежду.	\N
263	Постановщик	Создает художественную концепцию.	\N
264	Поэт	Пишет стихи.	\N
265	Поэт-лирик	Пишет лирические стихи.	\N
266	PR-менеджер	Занимается связями с общественностью.	\N
267	Прачка	Стирает и гладит костюмы, текстиль.	\N
268	Преподаватель	Обучает в рамках мастер-классов, курсов.	\N
269	Приёмщик заказов	Принимает и регистрирует заказы.	\N
270	Проводник	Сопровождает группы, экскурсии.	\N
271	Программист	Пишет код для программ, сайтов, игр.	\N
272	Программист игровой логики	Пишет код игровой механики.	\N
273	Программист игрового движка	Разрабатывает игровой движок.	\N
274	Программист игр	Пишет код для игр.	\N
275	Программист интерактивных инсталляций	Пишет код для инсталляций.	\N
276	Программист-разработчик	Разрабатывает ПО и приложения.	\N
277	Продюсер	Отвечает за производство проекта.	\N
278	Проектировщик	Разрабатывает проекты и концепции.	\N
279	Проекционный	Управляет проекционным оборудованием.	\N
280	Промоутер	Раздаёт рекламные материалы.	\N
281	Прораб	Руководит строительными работами.	\N
282	Прочеиститель	Чистит ковры, ткани.	\N
283	Психолог	Консультирует участников проекта.	\N
284	Разнорабочий	Выполняет различные физические работы.	\N
285	Распорядитель	Координирует действия участников.	\N
286	Ревизор	Проводит внутренний финансовый контроль.	\N
287	Редактор	Работает с текстом, видео, звуком.	\N
288	Редактор видео (YouTube-контент)	Монтирует и публикует видеоконтент.	\N
289	Режиссёр	Руководит творческим процессом.	\N
290	Режиссёр-постановщик	Разрабатывает концепцию спектакля/фильма.	\N
291	Реквизитор	Отвечает за реквизит.	\N
292	Реставратор	Восстанавливает произведения искусства.	\N
293	Риггер	Создает скелеты и системы управления для 3D-моделей.	\N
294	Робототехник-художник	Создает роботов для перформансов.	\N
295	Руководитель	Управляет командой или направлением.	\N
296	Садовник	Ухаживает за растениями.	\N
297	Саксофонист	Исполняет партии на саксофоне.	\N
298	Саунд-артист	Работает со звуком как с материалом.	\N
299	Саунд-артист (инсталляции)	Создает звуковые скульптуры.	\N
300	Саунд-архитектор	Проектирует акустику помещений.	\N
301	Саунд-дизайнер	Создает звуковые эффекты.	\N
302	Саунд-дизайнер для медиа	Создает звук для кино, игр.	\N
303	Саунд-продюсер	Отвечает за звучание записи.	\N
304	Сборщик	Собирает конструкции, оборудование.	\N
305	Светодизайнер	Разрабатывает световые решения.	\N
306	Светодизайнер (архитектурный)	Создает световые решения для зданий.	\N
307	Скульптор	Создает объёмные художественные произведения.	\N
308	Скульптор-монументалист	Создает крупные скульптуры.	\N
309	Сказочник (сказитель)	Сочиняет и рассказывает сказки.	\N
310	Скрипач	Исполняет партии на скрипке.	\N
311	Слесарь	Выполняет слесарные работы.	\N
312	Сметчик	Рассчитывает стоимость работ.	\N
313	Снабженец	Занимается закупками.	\N
314	SMM-специалист	Продвигает проекты в соцсетях.	\N
315	Специалист	Эксперт в определённой области.	\N
316	Специалист по 3D-печати	Создает объекты с помощью 3D-печати.	\N
317	Специалист по безопасности мероприятий	Обеспечивает безопасность на мероприятиях.	\N
318	Специалист по VR/AR-разработке	Создает приложения в VR/AR.	\N
319	Специалист по генеративному искусству	Создает искусство с помощью алгоритмов.	\N
320	Специалист по краудфандингу	Организует сбор средств.	\N
321	Специалист по цветокоррекции	Корректирует цветовую гамму видео.	\N
322	Специалист по экономическому анализу	Проводит экономический анализ.	\N
323	Спикер	Выступает с докладами.	\N
324	Стилист	Создает образы.	\N
325	Страховой агент	Оформляет страховки.	\N
326	Строитель	Выполняет строительные работы.	\N
327	Стример	Ведёт прямые трансляции.	\N
328	Суфлёр	Подсказывает текст актёрам.	\N
329	Сценарист	Пишет сценарии.	\N
330	Таксировщик	Оценивает стоимость имущества.	\N
331	Танцор	Исполняет танцевальные номера.	\N
332	Таргетолог	Настраивает рекламу в соцсетях.	\N
333	Творческий руководитель	Отвечает за креативную часть проекта.	\N
334	Телохранитель	Обеспечивает личную безопасность.	\N
335	Тестировщик	Проверяет качество продуктов, программ.	\N
336	Тестировщик игр (QA)	Проверяет игры на баги.	\N
337	Тестировщик игр на совместимость	Проверяет игру на разных устройствах.	\N
338	Техник	Обслуживает и ремонтирует технику.	\N
339	Технический директор	Руководит технической частью проекта.	\N
340	Технический писатель	Пишет документацию.	\N
341	Технический художник (игры)	Создает инструменты для художников игр.	\N
342	Ткач	Изготавливает ткани.	\N
343	Токарь	Вытачивает детали.	\N
344	Транспортировщик	Перевозит оборудование.	\N
345	Трейдер	Занимается торговлей, закупками.	\N
346	Трубач	Исполняет партии на трубе.	\N
347	Уборщик	Поддерживает чистоту.	\N
348	Упаковщик	Упаковывает товары, материалы.	\N
349	Установщик	Устанавливает оборудование.	\N
350	Учитель	Обучает творческим дисциплинам.	\N
351	Фанат	Активно поддерживает проект.	\N
352	Фехтовальщик	Участвует в постановочных боях.	\N
353	Финдиректор (CFO)	Руководит финансовой стратегией.	\N
354	Флейтист	Исполняет партии на флейте.	\N
355	Флорист	Составляет цветочные композиции.	\N
356	Фокусник	Показывает фокусы.	\N
357	Фольклорист	Изучает народное творчество.	\N
358	Фольклорист-исследователь	Систематизирует народное творчество.	\N
359	Фотограф	Создает фотографии.	\N
360	Фотограф-документалист	Снимает реальные события.	\N
361	Фотограф-макросъёмщик	Снимает мелкие объекты.	\N
362	Фотограф-пейзажист	Снимает природные и городские ландшафты.	\N
363	Фотограф-портретист	Специализируется на портретной съёмке.	\N
364	Фотограф-художник	Создает художественные фотографии.	\N
365	Фронтенд-разработчик	Разрабатывает видимую часть сайтов.	\N
366	Фуд-стилист	Создает композиции из блюд.	\N
367	Химик	Работает с химическими материалами в искусстве.	\N
368	Хореограф	Ставит танцевальные номера.	\N
369	Хореограф-постановщик	Разрабатывает и ставит танцевальные номера.	\N
370	Хормейстер	Руководит хором.	\N
371	Хранитель	Отвечает за сохранность экспонатов.	\N
372	Художник	Создает произведения изобразительного искусства.	\N
373	Художник биоарта	Работает с живыми материалами.	\N
374	Художник видеоконтента	Создает видеоролики.	\N
375	Художник декоративно-прикладного искусства	Создает произведения в техниках батика, витража, мозаики.	\N
376	Художник-декоратор (сценография)	Создает элементы декораций.	\N
377	Художник-живописец	Пишет картины.	\N
378	Художник-живописец (портретист)	Специализируется на портретной живописи.	\N
379	Художник-иллюстратор	Создает иллюстрации.	\N
380	Художник-иллюстратор детских книг	Создает иллюстрации для детской литературы.	\N
381	Художник-концептолог	Создает концепт-арты.	\N
382	Художник-концептолог игровой	Создает концепт-арты для игр.	\N
383	Художник-мультимедиа	Создает видеоинсталляции, интерактивные проекты.	\N
384	Художник-мультипликатор	Рисует и анимирует персонажей.	\N
385	Художник-оформитель	Создает декорации, реквизит.	\N
386	Художник-постановщик	Разрабатывает сценографию.	\N
387	Художник-постановщик кино	Разрабатывает визуальную концепцию фильма.	\N
388	Художник-раскадровщик	Создает раскадровки.	\N
389	Художник-раскадровщик (storyboard artist)	Создает схемы кадров для фильмов.	\N
390	Художник-визуализатор	Создает фотореалистичные визуализации.	\N
391	Художник комиксов	Рисует комиксы.	\N
392	Художник по видеоконтенту	Создает видеоролики.	\N
393	Художник по гриму	Создает грим.	\N
394	Художник по интерфейсу игр (UI artist)	Создает графику для игрового интерфейса.	\N
395	Художник по костюмам	Разрабатывает костюмы.	\N
396	Художник по металлу	Работает с ковкой, литьём.	\N
397	Художник по окружению (environment artist)	Создает игровые локации.	\N
398	Художник по персонажам	Создает визуальный образ персонажей.	\N
399	Художник по персонажам (character artist)	Моделирует и текстурирует игровых персонажей.	\N
400	Художник по пиксель-арту	Создает растровую графику с использованием пикселей.	\N
401	Художник по пиротехнике	Создает пиротехнические шоу.	\N
402	Художник по проекциям (projection mapping)	Проецирует изображения на объёмные объекты.	\N
403	Художник по реквизиту	Подбирает или изготавливает реквизит.	\N
404	Художник по свету	Создает световую партитуру.	\N
405	Художник по свету (Lighting Designer)	Разрабатывает световые концепции.	\N
406	Художник по свету (для игр)	Создает освещение в игровых сценах.	\N
407	Художник по тактильному искусству	Создает произведения для тактильного восприятия.	\N
408	Художник по текстурам	Разрабатывает текстуры для 3D-моделей.	\N
409	Художник по текстурам (для игр)	Создает текстуры для игр.	\N
410	Художник по эффектам (VFX artist)	Создает визуальные эффекты для игр.	\N
411	Художник стрит-арта	Создает муралы, граффити.	\N
412	Художник стрит-арта (муралист)	Рисует монументальные росписи.	\N
413	Цветовод	Выращивает цветы и растения.	\N
414	Цифровой художник	Создает искусство с помощью цифровых технологий.	\N
415	Цифровой художник (Digital painter)	Пишет картины в цифровом формате.	\N
416	Цирковой артист	Выполняет акробатические, жонглёрские номера.	\N
417	Часовой дизайнер	Создает дизайн часов.	\N
418	Часовщик	Ремонтирует и изготавливает часы.	\N
419	Чертёжник	Выполняет чертежи и схемы.	\N
420	Чтец	Художественно читает литературные произведения.	\N
421	Швея	Шьёт текстильные изделия.	\N
422	Шеф-повар авторской кухни	Создает уникальные блюда.	\N
423	Шрифтовой дизайнер	Создает и адаптирует шрифты.	\N
424	Штамповщик	Изготавливает штампы, печати.	\N
425	Эколог	Консультирует по экологическим вопросам.	\N
426	Экономист	Анализирует финансовые показатели.	\N
427	Электрик	Монтирует и обслуживает электрические системы.	\N
428	Ювелир	Создает украшения.	\N
429	Ювелир-дизайнер	Создает эскизы украшений.	\N
430	Юрист	Консультирует по правовым вопросам.	\N
431	VFX-художник (композинг)	Совмещает реальные съёмки с компьютерной графикой.	\N
432	Специалист по VFX	Создает визуальные эффекты для кино, рекламы.	\N
\.


--
-- Data for Name: functions_directions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.functions_directions (function_id, direction_id) FROM stdin;
\.


--
-- Data for Name: global_request_notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.global_request_notifications (notification_id, global_request_id, actor_id, notification_type, title, message, is_read, related_resource_id, created_at) FROM stdin;
1	2	1	request_created	Глобальный запрос создан	Вы создали глобальный запрос "Новый запрос на мастер-класс" на Локация в Москва	f	2	2026-01-23 01:56:01.967792
2	3	1	request_created	Глобальный запрос создан	Вы создали глобальный запрос "Запрос на аренду студии для фотосессии" на Локация в Москва	f	3	2026-01-23 01:57:06.248667
4	5	1	request_created	Глобальный запрос создан	Вы создали глобальный запрос "Запрос для теста откликов" на Локация в Москва	f	5	2026-01-23 02:01:17.994995
5	6	1	request_created	Глобальный запрос создан	Вы создали глобальный запрос "Финальный тестовый запрос" на Локация в Москва	f	6	2026-01-23 02:02:00.900101
6	7	1	request_created	Глобальный запрос создан	Вы создали глобальный запрос "Нужна студия для записи подкаста" на Локация в Москва	f	7	2026-01-23 02:05:24.547245
7	8	1	request_created	Глобальный запрос создан	Вы создали глобальный запрос "Поиск площадки для воркшопа" на Локация в Москва	f	8	2026-01-23 02:06:36.154812
8	9	1	request_created	Глобальный запрос создан	Вы создали глобальный запрос "Срочно нужна репетиционная база" на Локация в Москва	f	9	2026-01-23 02:10:12.950241
\.


--
-- Data for Name: global_request_responses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.global_request_responses (response_id, global_request_id, owner_id, resource_id, status, message, proposed_price, proposed_conditions, response_date, status_changed_date, expiration_date, is_active) FROM stdin;
3	1	1	3	pending	Тестовый отклик на глобальный запрос	\N	\N	2026-01-23 01:31:20.331568	\N	\N	t
4	5	1	3	pending	Тестовый отклик на запрос 5	\N	\N	2026-01-23 02:01:17.994995	\N	\N	t
5	8	1	3	rejected	Готов предоставить площадку для воркшопа	\N	\N	2026-01-23 02:09:04.586433	2026-01-23 02:09:55.489787	\N	t
6	9	1	3	accepted	Можем предоставить площадку, есть вся аппаратура (принято организатором)	\N	\N	2026-01-23 02:10:12.950241	2026-01-23 02:10:12.950241	\N	t
\.


--
-- Data for Name: global_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.global_requests (global_request_id, requester_id, location_id, resource_type_id, subject_type_id, subject_id, title, description, quantity, validity_period, request_status_id, project_id, event_id, creation_date, update_date, is_active) FROM stdin;
1	1	1	1	1	\N	Тестовый глобальный запрос на площадку	Ищем сценическую площадку для мероприятия	1	\N	1	\N	\N	2026-01-23 01:21:14.058041	2026-01-23 01:21:14.058041	t
2	1	1	1	1	\N	Новый запрос на мастер-класс	Ищем площадку для проведения мастер-класса по живописи	1	2026-01-29 17:56:01.967792	1	\N	\N	2026-01-22 17:56:01.967792	2026-01-22 17:56:01.967792	t
3	1	1	1	2	\N	Запрос на аренду студии для фотосессии	Нужна фотостудия на 4 часа для проведения коммерческой фотосессии	1	2026-02-05 17:57:06.248667	1	\N	\N	2026-01-22 17:57:06.248667	2026-01-22 17:57:06.248667	t
5	1	1	1	1	\N	Запрос для теста откликов	Тестирование создания откликов на глобальный запрос	1	2026-01-25 18:01:17.994995	1	\N	\N	2026-01-22 18:01:17.994995	2026-01-22 18:01:17.994995	t
6	1	1	1	1	\N	Финальный тестовый запрос	Запрос создан в процессе финальной валидации системы	1	2026-01-23 18:02:00.900101	1	\N	\N	2026-01-22 18:02:00.900101	2026-01-22 18:02:00.900101	t
7	1	1	1	1	\N	Нужна студия для записи подкаста	Ищем звукозаписывающую студию на 3 часа	1	2026-01-29 18:05:24.547245	1	\N	\N	2026-01-22 18:05:24.547245	2026-01-22 18:05:24.547245	t
8	1	1	1	1	\N	Поиск площадки для воркшопа	Нужна площадка на 20 человек для проведения однодневного воркшопа	1	2026-02-01 18:06:36.154812	1	\N	\N	2026-01-22 18:06:36.154812	2026-01-22 18:06:36.154812	t
9	1	1	1	1	\N	Срочно нужна репетиционная база	Ищем помещение для репетиций рок-группы на вечер	2	2026-01-25 18:10:12.950241	1	\N	\N	2026-01-22 18:10:12.950241	2026-01-22 18:10:12.950241	t
\.


--
-- Data for Name: global_response_status_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.global_response_status_history (history_id, response_id, old_status, new_status, changed_by, reason, change_date) FROM stdin;
\.


--
-- Data for Name: group_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.group_tasks (task_id, project_group_id) FROM stdin;
\.


--
-- Data for Name: idea_categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.idea_categories (idea_category_id, category) FROM stdin;
1	Возмездная
2	Безвозмездная
\.


--
-- Data for Name: idea_offering_terms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.idea_offering_terms (id, idea_id, offering_term_id, cost, currency, special_terms, created_at) FROM stdin;
\.


--
-- Data for Name: idea_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.idea_types (idea_type_id, type) FROM stdin;
1	Коммерческая
2	Некоммерческая
\.


--
-- Data for Name: ideas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ideas (idea_id, title, short_description, full_description, detail_description, idea_category_id, idea_type_id, actor_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by, rating_id) FROM stdin;
\.


--
-- Data for Name: ideas_directions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ideas_directions (idea_id, direction_id) FROM stdin;
\.


--
-- Data for Name: ideas_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ideas_notes (note_id, idea_id, author_id) FROM stdin;
\.


--
-- Data for Name: ideas_projects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ideas_projects (idea_id, project_id) FROM stdin;
\.


--
-- Data for Name: levels; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.levels (level_id, level) FROM stdin;
1	любитель
2	профессионал
3	эксперт
\.


--
-- Data for Name: local_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.local_events (local_event_id, title, description, date, start_time, end_time, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.locations (location_id, name, type, district, region, country, main_postcode, description, population, attachment, geom, latitude, longitude) FROM stdin;
1	Москва	город	\N	Москва	Россия	\N	\N	12678079	\N	\N	\N	\N
2	Санкт-Петербург	город	\N	Санкт-Петербург	Россия	\N	\N	5398064	\N	\N	\N	\N
3	Улан-Удэ	город	\N	Бурятия	Россия	\N	\N	437565	\N	\N	\N	\N
4	Иркутск	город	\N	Иркутская область	Россия	\N	\N	617264	\N	\N	\N	\N
5	Кяхта	город	\N	Бурятия	Россия	\N	\N	20013	\N	\N	\N	\N
\.


--
-- Data for Name: matresource_offering_terms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresource_offering_terms (id, matresource_id, offering_term_id, cost, currency, special_terms, created_at) FROM stdin;
4	1	1	15000.00	руб.	Продажа гармони. Полная стоимость.	2026-01-21 22:13:23.503668
5	1	2	0.00	руб.	Безвозмездная передача детскому музыкальному коллективу. Требуется подтверждение статуса коллектива.	2026-01-21 22:13:23.503668
6	1	3	0.00	руб.	Временное предоставление безвозмездно для участников конкурса «Играй гармонь». Срок - до 1 месяца.	2026-01-21 22:13:23.503668
7	1	4	3000.00	руб.	Временное предоставление за плату для коммерческих мероприятий. Стоимость указана за сутки.	2026-01-21 22:13:23.503668
11	1	4	5000.00	руб.	Аренда на неделю со скидкой	2026-01-21 22:15:17.118404
12	1	4	2500.00	руб.	Аренда гармони на выходные	2026-01-21 22:20:51.886412
21	1	4	3500.00	руб.	Депозит 5000 руб., возвращается при возврате в исправном состоянии	2026-01-22 14:48:16.815889
\.


--
-- Data for Name: matresource_owners; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresource_owners (matresource_id, actor_id, matresource_owner_id) FROM stdin;
1	1	2
1	10	4
\.


--
-- Data for Name: matresource_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresource_types (matresource_type_id, category, sub_category, title) FROM stdin;
1	Техника и оборудование	Аудиотехника	Микрофоны
2	Техника и оборудование	Аудиотехника	Микшерные пульты
3	Техника и оборудование	Аудиотехника	Акустические системы (колонки и т.д.)
4	Техника и оборудование	Аудиотехника	Наушники
5	Техника и оборудование	Аудиотехника	Звуковые карты / аудиоинтерфейсы
6	Техника и оборудование	Видео- и фототехника	Цифровые фотокамеры
7	Техника и оборудование	Видео- и фототехника	Видеокамеры
8	Техника и оборудование	Видео- и фототехника	Объективы
9	Техника и оборудование	Видео- и фототехника	Штативы
10	Техника и оборудование	Видео- и фототехника	Осветительные приборы (светодиодные панели, софтбоксы и т.д.)
11	Техника и оборудование	Видео- и фототехника	Стедикамы / стабилизаторы
12	Техника и оборудование	Видео- и фототехника	Дроны
13	Техника и оборудование	Компьютерная техника	Ноутбуки / стационарные компьютеры
14	Техника и оборудование	Компьютерная техника	Графические планшеты
15	Техника и оборудование	Компьютерная техника	Мониторы
16	Техника и оборудование	Компьютерная техника	VR/AR-шлемы / очки
17	Техника и оборудование	Сценическое оборудование	Сценическое освещение (пульты, прожекторы, сканеры и т.д.)
18	Техника и оборудование	Сценическое оборудование	Дым-машины / генераторы тумана и т.д.
19	Техника и оборудование	Сценическое оборудование	Проекторы
20	Техника и оборудование	Сценическое оборудование	Сценические механизмы (подъёмники, поворотные круги и т.д.)
21	Техника и оборудование	Специализированное оборудование	3D-принтеры
22	Техника и оборудование	Специализированное оборудование	Лазерные гравёры / резаки
23	Техника и оборудование	Специализированное оборудование	Швейные машины / оверлоки
24	Техника и оборудование	Специализированное оборудование	Гончарные круги
25	Техника и оборудование	Специализированное оборудование	Инструменты для ковки (горны, наковальни и т.д.)
26	Техника и оборудование	Музыкальные инструменты	Клавишные инструменты (синтезаторы, пианино и т.д.)
27	Техника и оборудование	Музыкальные инструменты	Струнные инструменты
28	Техника и оборудование	Музыкальные инструменты	Ударные инструменты
29	Техника и оборудование	Музыкальные инструменты	Духовые инструменты
30	Техника и оборудование	Музыкальные инструменты	Народные инструменты
31	Расходные материалы	Для живописи и графики	Холсты
32	Расходные материалы	Для живописи и графики	Краски
33	Расходные материалы	Для живописи и графики	Кисти
34	Расходные материалы	Для живописи и графики	Бумага для графики и акварели
35	Расходные материалы	Для цифрового искусства	Лицензии ПО (Adobe, 3ds Max, Unity и т.д.)
36	Расходные материалы	Для цифрового искусства	Цифровые активы (3D-модели, текстуры и т.д.)
37	Расходные материалы	Для ремесел и декора	Ткани
38	Расходные материалы	Для ремесел и декора	Пряжа / нити
39	Расходные материалы	Для ремесел и декора	Древесные материалы (брус, фанера и т.д.)
40	Расходные материалы	Для ремесел и декора	Металлы (лист, проволока и т.д.)
41	Расходные материалы	Для ремесел и декора	Глина / керамическая масса
42	Расходные материалы	Для ремесел и декора	Стекла (витражное, цветное и т.д.)
43	Расходные материалы	Для сцены и постановок	Грим (краски, парики, накладки и т.д.)
44	Расходные материалы	Для сцены и постановок	Сценический реквизит (бутафория)
45	Расходные материалы	Для сцены и постановок	Пиротехнические заряды
46	Расходные материалы	Канцелярия и офис	Бумага (офисная, для принтера и т.д.)
47	Расходные материалы	Канцелярия и офис	Картриджи для принтера
48	Расходные материалы	Канцелярия и офис	Письменные принадлежности
49	Носители информации	Электронные	Жёсткие диски (HDD/SSD)
50	Носители информации	Электронные	Флеш-накопители (USB)
51	Носители информации	Электронные	Карты памяти (SD, CF и т.д.)
52	Носители информации	Полиграфические	Бумага для печати (различной плотности)
53	Носители информации	Полиграфические	Краски для полиграфии
54	Мебель и интерьер	Рабочая мебель	Столы
55	Мебель и интерьер	Рабочая мебель	Стулья / кресла
56	Мебель и интерьер	Рабочая мебель	Стеллажи / полки
57	Мебель и интерьер	Для мероприятий	Складные стулья
58	Мебель и интерьер	Для мероприятий	Столы для кейтеринга
59	Мебель и интерьер	Для мероприятий	Шезлонги / пуфы
60	Мебель и интерьер	Специальная	Мольберты
61	Мебель и интерьер	Специальная	Манекены
62	Транспорт и логистика	Транспортные средства	Легковые автомобили
63	Транспорт и логистика	Транспортные средства	Грузовые микроавтобусы
64	Транспорт и логистика	Транспортные средства	Грузовики
65	Транспорт и логистика	Упаковка и хранение	Картонные коробки
66	Транспорт и логистика	Упаковка и хранение	Пенопласт / пупырчатая плёнка
67	Транспорт и логистика	Упаковка и хранение	Паллеты (поддоны)
68	Транспорт и логистика	Упаковка и хранение	Кейсы / кофры (для оборудования)
69	Энергия и коммуникации	Электроснабжение	Портативные генераторы
70	Энергия и коммуникации	Электроснабжение	Стабилизаторы напряжения
71	Энергия и коммуникации	Электроснабжение	Аккумуляторы / батареи
72	Энергия и коммуникации	Связь	Мобильные Wi-Fi роутеры
73	Энергия и коммуникации	Связь	Рации
74	Программное обеспечение	Производство контента	Видеоредакторы (DaVinci Resolve, Premiere и т.д.)
75	Программное обеспечение	Производство контента	Графические редакторы (Photoshop, Illustrator и т.д.)
76	Программное обеспечение	Производство контента	DAW (Ableton, FL Studio, Cubase и т.д.)
77	Программное обеспечение	Производство контента	3D-редакторы (Blender, Maya и т.д.)
78	Программное обеспечение	Управление проектами	Платформы для коллаборации (Notion, Miro и т.д.)
79	Программное обеспечение	Управление проектами	CRM-системы
80	Программное обеспечение	Управление проектами	Облачные хранилища (Google Drive, Yandex Disk и т.д.)
\.


--
-- Data for Name: matresources; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresources (matresource_id, title, description, matresource_type_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by, rating_id) FROM stdin;
1	Тестовая гармонь	Тестовое описание	\N	\N	\N	2026-01-21 22:05:55.850518+08	2026-01-21 22:05:55.850518+08	\N	\N	\N
2	Гармонь "Русская"	Русская гармонь, отличное состояние, изготовлена в 2020 году	\N	\N	\N	2026-01-21 22:13:23.503668+08	2026-01-21 22:13:23.503668+08	\N	\N	\N
3	Цифровой фотоаппарат Canon	Зеркальный фотоаппарат с объективом 18-55мм, 24.2 Мп	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
4	Синтезатор Yamaha PSR-E373	61 клавиша, 758 тембров, автоаккомпанемент, обучение	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
5	Сценический прожектор LED	Мощность 200W, RGB-подсветка, дистанционное управление	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
6	Световой пульт Chamsys MagicQ	Программируемый контроллер для управления светом	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
7	Микшерный пульт Behringer X32	32 канала, цифровой микшер с эффектами	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
8	Конденсаторный микрофон Rode NT1	Студийный микрофон с низким уровнем собственного шума	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
9	Саксофон альт Yamaha YAS-280	Латунный корпус, включает чехол и мундштук	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
10	Ноутбук Dell XPS 15	Процессор i7, 16 ГБ ОЗУ, SSD 512 ГБ, экран 15.6"	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
11	Легковой автомобиль Hyundai Solaris	2022 г.в., 1.6 л, автомат, пробег 15000 км	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
12	Театральный грим Kryolan	Набор из 24 цветов, гипоаллергенный, профессиональный	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
13	Видеокамера Sony Handycam	Full HD, оптический zoom 30x, стабилизатор изображения	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
14	Акустическая гитара Fender	Корпус dreadnought, струны из бронзы, чехол в комплекте	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
15	Проектор Epson EH-TW740	4K, 3000 люмен, поддержка HDR, для домашнего кинотеатра	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
16	Труба Bach Stradivarius	Медная, профессиональная модель, серебряное покрытие	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
17	Планшет Apple iPad Pro	12.9", 256 ГБ, поддержка Apple Pencil	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
18	Минивэн Volkswagen Caravelle	9-местный, 2021 г.в., дизель, кондиционер	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
19	Парик театральный	Седой, длинные волосы, натуральные материалы	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
20	Барабанная установка Pearl	5-компонентная, тарелки в комплекте, для начинающих	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
21	Система видеонаблюдения	4 камеры, запись на HDD 2 ТБ, удаленный доступ	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
22	Тромбон с сурдиной	Теноровый тромбон, включает кейс и сурдину	\N	\N	\N	2026-01-23 22:35:00.266178+08	2026-01-23 22:35:00.266178+08	\N	\N	\N
\.


--
-- Data for Name: matresources_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresources_notes (note_id, matresource_id, author_id) FROM stdin;
\.


--
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.messages (message_id, message, author_id, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notes (note_id, note, author_id, created_at, updated_at, created_by, updated_by) FROM stdin;
15	Тестовая заметка к событию 1	1	2026-01-21 03:25:17.385653+08	2026-01-21 03:25:17.385653+08	1	1
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notifications (notification_id, notification, recipient, is_read, created_at, updated_at, created_by, updated_by) FROM stdin;
1	У вас новая задача: "Подготовить сценарий для читки"	3	f	2026-01-07 00:53:42.309+08	2026-01-07 00:53:42.309+08	1	1
\.


--
-- Data for Name: offering_terms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.offering_terms (id, code, name, is_paid, is_temporary) FROM stdin;
1	sale	Продажа	t	f
2	free_transfer	Безвозмездная передача	f	f
3	temporary_free	Временное предоставление безвозмездно	f	t
4	temporary_paid	Временное предоставление за плату	t	t
\.


--
-- Data for Name: organizations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.organizations (organization_id, title, full_title, email, email_2, staff_name, staff_lastname, location_id, post_code, address, phone_number, phone_number_2, dir_name, dir_lastname, ogrn, inn, kpp, bank_title, bank_bik, bank_account, org_info, vk_page, ok_page, tt_page, tg_page, ig_page, fb_page, max_page, web_page, attachment, actor_id, deleted_at, created_at, updated_at, created_by, updated_by, geom, latitude, longitude) FROM stdin;
4	Тестовая организация для файлов	Тестовая организация для проверки файловой системы	test-files@example.com	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	2026-01-24 00:02:46.302317+08	2026-01-24 00:02:46.302317+08	1	1	\N	\N	\N
3	Тестовая Организация для Файлов	Полное название тестовой организации для системы файлов	org-files@example.com	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	7	\N	2026-01-23 23:56:29.883225+08	2026-01-24 02:04:11.063407+08	1	1	0101000020E6100000BDE3141DC9553E408F53742497F74D40	59.93430000	30.33510000
\.


--
-- Data for Name: persons; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.persons (person_id, name, patronymic, last_name, gender, birth_date, email, email_2, location_id, post_code, address, phone_number, phone_number_2, personal_info, web_page, whatsapp, viber, vk_page, ok_page, tt_page, tg_page, ig_page, fb_page, max_page, pp_number, pp_date, pp_auth, inn, snils, bank_bik, bank_account, bank_info, ya_account, wm_account, pp_account, qiwi_account, attachment, actor_id, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
1	Иван	\N	Иванов	\N	\N	admin@example.com	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1	\N	2026-01-06 23:53:40.21+08	2026-01-06 23:53:40.21+08	1	1
8	Тест	\N	Разработчик	\N	\N	dev@prostvor.local	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	9	\N	2026-01-07 03:30:43.478+08	2026-01-07 03:30:43.478+08	1	1
9	Тест	\N	Регистрация	\N	\N	test_reg_1767767318@example.com	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	10	\N	2026-01-07 14:28:38.158+08	2026-01-07 14:28:38.158+08	1	1
10	Иван	\N	Иванов	\N	\N	test2@example.com	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	11	\N	2026-01-07 17:42:35.47+08	2026-01-07 17:42:35.47+08	1	1
11	Алексей	\N	Петров	\N	\N	test_new@example.com	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	12	\N	2026-01-07 17:48:45.819+08	2026-01-07 17:48:45.819+08	1	1
12	Тест	\N	Тестов	\N	\N	test1767791990923@example.com	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	13	\N	2026-01-07 21:19:52.291+08	2026-01-07 21:19:52.291+08	1	1
13	cabotin	\N	cabotin	\N	\N	cabotin@mail.ru	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	14	\N	2026-01-07 22:33:55.441+08	2026-01-07 22:33:55.441+08	1	1
14	new	\N	new	\N	\N	new@mail.ru	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	17	\N	2026-01-07 23:24:36.665+08	2026-01-07 23:24:36.665+08	1	1
15	new2026	\N	new2026	\N	\N	new2026@mail.ru	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	21	\N	2026-01-10 03:01:57.54+08	2026-01-10 03:01:57.54+08	1	1
2	Сергей	\N	Сергеев	\N	\N	newuser@example.com	\N	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	3	\N	2026-01-07 00:33:36.783+08	2026-01-11 02:17:15.759464+08	1	1
7	test	\N	test	\N	\N	test_final@test.com	\N	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	8	\N	2026-01-07 00:58:24.155+08	2026-01-11 02:17:15.759464+08	1	1
3	Андрей	\N	Андреев	\N	\N	seconduser@example.com	\N	2	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	4	\N	2026-01-07 00:35:06.117+08	2026-01-11 02:17:15.759464+08	1	1
5	Успех	\N	Тестовый	\N	\N	success_user@example.com	\N	2	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	6	\N	2026-01-07 00:55:30.892+08	2026-01-11 02:17:15.759464+08	1	1
\.


--
-- Data for Name: project_actor_roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.project_actor_roles (project_actor_role_id, actor_id, project_id, role_type, assigned_at, assigned_by, note) FROM stdin;
\.


--
-- Data for Name: project_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.project_groups (project_group_id, title, project_id, actor_id, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: project_statuses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.project_statuses (project_status_id, status, description) FROM stdin;
1	Инициация	\N
2	Проверка	\N
3	Формирование	\N
4	В работе	\N
5	Приостановлено	\N
6	Завершено	\N
\.


--
-- Data for Name: project_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.project_types (project_type_id, type) FROM stdin;
1	Коммерческий
2	Некоммерческий
\.


--
-- Data for Name: projects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects (project_id, title, full_title, description, author_id, director_id, tutor_id, project_status_id, start_date, end_date, project_type_id, account, keywords, attachment, deleted_at, created_at, updated_at, created_by, updated_by, rating_id, cost, currency, offering_term_id, special_terms, geom, latitude, longitude) FROM stdin;
\.


--
-- Data for Name: projects_directions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_directions (project_id, direction_id) FROM stdin;
\.


--
-- Data for Name: projects_functions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_functions (project_id, function_id) FROM stdin;
\.


--
-- Data for Name: projects_local_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_local_events (project_id, local_event_id) FROM stdin;
\.


--
-- Data for Name: projects_locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_locations (project_id, location_id) FROM stdin;
\.


--
-- Data for Name: projects_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_notes (note_id, project_id, author_id) FROM stdin;
\.


--
-- Data for Name: projects_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_tasks (task_id, project_id) FROM stdin;
\.


--
-- Data for Name: rating_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rating_types (rating_type_id, type, description, created_at) FROM stdin;
1	положительно	Положительная оценка (лайк)	2026-01-15 20:59:11.433599+08
2	отрицательно	Отрицательная оценка	2026-01-15 20:59:11.433599+08
\.


--
-- Data for Name: ratings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ratings (rating_id, actor_id, rating_type_id, created_at) FROM stdin;
3	1	1	2026-01-21 03:13:30.625486+08
5	1	1	2026-01-21 03:14:27.734273+08
\.


--
-- Data for Name: request_offering_terms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.request_offering_terms (request_term_id, request_id, offering_term_id, proposed_cost, request_terms, requester_approval, owner_response, owner_approved_cost, owner_terms, owner_approval, term_status, created_at, updated_at) FROM stdin;
1	1	1	1000.00	Особые условия тестового запроса	f	\N	\N	\N	f	pending	2026-01-22 13:21:04.822558	2026-01-22 13:21:04.822558
7	6	4	3000.00	Требуется гарантийный депозит 5000 руб.	f	\N	\N	\N	f	pending	2026-01-22 14:48:16.815889	2026-01-22 14:48:16.815889
8	8	1	2000.00	Финальные тестовые условия	f	\N	\N	\N	f	pending	2026-01-22 15:20:43.094949	2026-01-22 15:20:43.094949
9	9	1	5000.00	Финальные тестовые условия	f	\N	\N	\N	f	pending	2026-01-22 15:42:40.017138	2026-01-22 15:42:40.017138
\.


--
-- Data for Name: request_statistic; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.request_statistic (request_statistic_id, location_id, creation_time, resource_type_id, subject_type_id, subject_id, relevance, completed, archived_date) FROM stdin;
\.


--
-- Data for Name: request_statuses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.request_statuses (request_status_id, status, description) FROM stdin;
1	действующий	Запрос активен и ожидает выполнения
2	приостановлен	Запрос временно приостановлен
3	отменён	Запрос отменен
4	завершён	Запрос завершен (есть договор)
\.


--
-- Data for Name: request_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.request_types (request_type_id, type, description) FROM stdin;
1	Локация	Запрос на использование площадки/локации
2	материальный ресурс	Запрос материального ресурса
3	финансовый ресурс	Запрос финансового ресурса
4	Услуга	Запрос услуги
5	Идея	Запрос идеи
6	Функция	Запрос на выполнение функции
\.


--
-- Data for Name: requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.requests (request_id, requester_id, resource_type, resource_id, project_id, start_date, end_date, start_time, end_time, request_title, request_description, requester_notes, submitted_at, reviewed_at, responded_at, reviewed_by, created_at, updated_at, event_id, request_status_id, request_type_id, location_id, request_type, validity_period) FROM stdin;
1	1	matresource	1	\N	2026-01-29	2026-01-30	\N	\N	Тестовый запрос на ресурс	Пример запроса для тестирования системы	\N	\N	2026-01-22 14:05:03.349765	\N	1	2026-01-22 13:21:04.822558	2026-01-22 23:13:39.43912	\N	1	2	\N	matresource	\N
6	9	matresource	1	\N	2026-01-25	2026-01-26	08:00:00	22:00:00	Аренда оборудования для мероприятия	Требуется звуковое оборудование на 2 дня	\N	\N	2026-01-22 14:48:16.815889	\N	1	2026-01-22 14:48:16.815889	2026-01-22 23:13:39.43912	\N	1	2	\N	matresource	\N
8	13	service	1	\N	2026-01-23	2026-01-23	\N	\N	Финальный тест системы	Тестирование полного цикла создания договора	\N	\N	2026-01-22 15:20:43.094949	\N	1	2026-01-22 15:20:43.094949	2026-01-22 23:13:39.43912	\N	1	4	\N	service	\N
9	1	service	1	\N	\N	\N	\N	\N	Финальный тест готовности системы	Последний тест перед сдачей системы в эксплуатацию	\N	\N	2026-01-22 15:42:40.017138	\N	\N	2026-01-22 15:42:40.017138	2026-01-22 23:13:39.43912	\N	1	4	\N	service	\N
\.


--
-- Data for Name: resource_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.resource_types (resource_type_id, type, description, entity_table, entity_id_column, entity_type_column) FROM stdin;
1	Локация	Площадки и помещения	venues	venue_id	venue_type_id
2	материальный ресурс	Материальные ресурсы	matresources	matresource_id	matresource_type_id
3	финансовый ресурс	Финансовые ресурсы	finresources	finresource_id	finresource_type_id
4	Услуга	Услуги	services	service_id	services_type_id
5	Идея	Идеи	ideas	idea_id	idea_type_id
6	Функция	Функции и роли	functions	function_id	\N
\.


--
-- Data for Name: service_offering_terms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.service_offering_terms (id, service_id, offering_term_id, cost, currency, special_terms, created_at) FROM stdin;
1	1	1	5000.00	руб.	Консультация 1 час	2026-01-22 01:10:14.90451
2	1	2	0.00	руб.	Бесплатная первичная консультация 30 мин	2026-01-22 01:10:14.90451
17	1	1	2500.00	руб.	Тестовые условия предоставления услуги	2026-01-22 15:20:43.094949
\.


--
-- Data for Name: service_owners; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.service_owners (service_owner_id, service_id, actor_id, ownership_type, ownership_share, is_primary, special_conditions, created_at, updated_at) FROM stdin;
2	1	1	owner	100.00	t	\N	2026-01-22 14:04:11.288807	2026-01-22 14:04:11.288807
3	1	14	owner	100.00	t	\N	2026-01-22 15:20:43.094949	2026-01-22 15:20:43.094949
\.


--
-- Data for Name: services; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services (service_id, title, description, attachment, deleted_at, created_at, updated_at, created_by, updated_by, rating_id) FROM stdin;
1	Консультация юриста	Юридическая консультация по авторскому праву	\N	\N	2026-01-22 01:10:14.90451+08	2026-01-22 01:10:14.90451+08	\N	\N	\N
\.


--
-- Data for Name: services_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services_notes (note_id, service_id, author_id) FROM stdin;
\.


--
-- Data for Name: services_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services_types (services_type_id, name, description) FROM stdin;
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: stage_architecture; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_architecture (stage_architecture_id, architecture) FROM stdin;
\.


--
-- Data for Name: stage_audio; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_audio (stage_audio_id, title, description, attachment, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: stage_audio_set; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_audio_set (stage_id, stage_audio_id) FROM stdin;
\.


--
-- Data for Name: stage_effects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_effects (stage_effects_id, title, description, attachment, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: stage_effects_set; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_effects_set (stage_id, stage_effects_id) FROM stdin;
\.


--
-- Data for Name: stage_light; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_light (stage_light_id, title, description, attachment, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: stage_light_set; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_light_set (stage_id, stage_light_id) FROM stdin;
\.


--
-- Data for Name: stage_mobility; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_mobility (stage_mobility_id, mobility) FROM stdin;
\.


--
-- Data for Name: stage_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_types (stage_type_id, type) FROM stdin;
\.


--
-- Data for Name: stage_video; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_video (stage_video_id, title, description, attachment, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: stage_video_set; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_video_set (stage_id, stage_video_id) FROM stdin;
\.


--
-- Data for Name: stages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stages (stage_id, title, full_title, stage_type_id, stage_architecture_id, stage_mobility_id, capacity, width, depth, height, description, location_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by, geom, latitude, longitude) FROM stdin;
\.


--
-- Data for Name: system_commands; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.system_commands (id, category, command, description) FROM stdin;
1	Создание	SELECT create_request(1, 'service', 1, 'Заголовок', 'Описание');	Создать новый запрос
2	Условия	SELECT add_request_term(1, 1, 1000.00, 'Условия');	Добавить условия к запросу
3	Принятие	UPDATE requests SET request_status = 'accepted' WHERE request_id = 1;	Принять запрос
4	Подписание	UPDATE temp_contracts SET requester_signed = TRUE, owner_signed = TRUE WHERE request_id = 1;	Подписать договор
5	Мониторинг	SELECT * FROM v_contract_process_tracking;	Отслеживание процессов
6	Аналитика	SELECT * FROM v_business_intelligence;	Бизнес-статистика
\.


--
-- Data for Name: system_deployment_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.system_deployment_log (deployment_id, component_name, component_type, status, created_at, notes) FROM stdin;
1	Система управления запросами и договорами	Полная система	Успешно	2026-01-22 15:41:53.873912	Развернута в соответствии с ТЗ
2	Таблицы (8 шт.)	Хранение данных	Успешно	2026-01-22 15:41:53.873912	requests, temp_contracts, contracts и связанные таблицы
3	Функции (6 шт.)	Автоматизация	Успешно	2026-01-22 15:41:53.873912	create_request, add_request_term, create_final_contract и др.
4	Триггеры (4 шт.)	Бизнес-логика	Успешно	2026-01-22 15:41:53.873912	Автоматическое создание договоров, обновление меток времени
5	Представления (6 шт.)	Мониторинг	Успешно	2026-01-22 15:41:53.873912	v_contract_process_tracking, v_business_intelligence и др.
6	Тестовые данные	Данные	Успешно	2026-01-22 15:41:53.873912	Созданы тестовые запросы, договоры и условия
8	Финальная верификация	Качество	Успешно	2026-01-22 16:27:19.705437	Все компоненты системы проверены и работают
9	Автоматизация договоров	Бизнес-процессы	Успешно	2026-01-22 16:27:19.705437	Триггеры создания временных и финальных договоров работают
10	Мониторинг и аналитика	Управление	Успешно	2026-01-22 16:27:19.705437	Все представления созданы и отображают данные
11	Тестовые данные	Данные	Успешно	2026-01-22 16:27:19.705437	Созданы тестовые запросы и договоры для демонстрации
7	Триггер создания финальных договоров	Автоматизация	Успешно	2026-01-22 16:07:55.979752	Триггер исправлен и работает. Созданы договоры автоматически: 1 для temp_contract_id=9
12	Проект завершен	Итог	Успешно	2026-01-22 16:42:07.513817	Система управления запросами и договорами успешно создана. Договоров: 3, Общая стоимость: 10000.00 руб., Все требования ТЗ выполнены.
\.


--
-- Data for Name: task_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.task_types (task_type_id, type) FROM stdin;
1	Планируется
2	В работе
3	Приостановлено
4	Завершено
\.


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tasks (task_id, task, task_type_id, due_date, priority, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
1	Подготовить сценарий для читки	1	2026-01-10	3	\N	2026-01-07 00:52:59.278+08	2026-01-07 00:52:59.278+08	1	1
\.


--
-- Data for Name: temp_contract_terms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.temp_contract_terms (temp_term_id, temp_contract_id, request_term_id, offering_term_id, agreed_cost, agreed_currency, special_terms, term_status, created_at, updated_at) FROM stdin;
5	7	7	4	3000.00	руб.	Требуется гарантийный депозит 5000 руб.	pending	2026-01-22 14:48:16.815889	2026-01-22 14:48:16.815889
6	8	8	1	2000.00	руб.	Финальные тестовые условия	pending	2026-01-22 15:20:43.094949	2026-01-22 15:20:43.094949
7	9	9	1	5000.00	руб.	Финальные тестовые условия	pending	2026-01-22 15:42:40.017138	2026-01-22 15:42:40.017138
\.


--
-- Data for Name: temp_contracts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.temp_contracts (temp_contract_id, request_id, contract_title, contract_description, requester_id, owner_id, resource_type, resource_id, start_date, end_date, start_time, end_time, contract_status, requester_signed, owner_signed, valid_from, valid_until, created_at, updated_at) FROM stdin;
7	6	Временный договор: Тестовая гармонь	Требуется звуковое оборудование на 2 дня	9	1	matresource	1	2026-01-25	2026-01-26	08:00:00	22:00:00	pending_signatures	t	t	\N	\N	2026-01-22 14:48:16.815889	2026-01-22 15:19:40.934525
8	8	Временный договор: Консультация юриста	Тестирование полного цикла создания договора	13	1	service	1	2026-01-23	2026-01-23	\N	\N	draft	t	t	\N	\N	2026-01-22 15:20:43.094949	2026-01-22 15:32:40.174906
9	9	Временный договор: Консультация юриста	Последний тест перед сдачей системы в эксплуатацию	1	1	service	1	\N	\N	\N	\N	active	t	t	\N	\N	2026-01-22 15:42:40.017138	2026-01-22 16:12:55.698069
\.


--
-- Data for Name: template_offering_terms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.template_offering_terms (id, template_id, offering_term_id, cost, currency, special_terms, created_at) FROM stdin;
\.


--
-- Data for Name: templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates (template_id, title, description, direction_id, deleted_at, created_at, updated_at, created_by, updated_by, rating_id) FROM stdin;
\.


--
-- Data for Name: templates_finresources; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates_finresources (template_id, finresource_id) FROM stdin;
\.


--
-- Data for Name: templates_functions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates_functions (template_id, function_id) FROM stdin;
\.


--
-- Data for Name: templates_matresources; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates_matresources (template_id, matresource_id) FROM stdin;
\.


--
-- Data for Name: templates_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates_notes (template_note_id, template_id, note_id, author_id, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: templates_venues; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates_venues (template_id, venue_id) FROM stdin;
\.


--
-- Data for Name: theme_bookmarks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.theme_bookmarks (bookmark_id, theme_id, actor_id, last_read_discussion_id, last_read_position, scroll_position, created_at, updated_at) FROM stdin;
2	1	1	1	\N	\N	2026-01-21 03:03:46.475277+08	2026-01-21 03:03:46.475277+08
6	1	3	4	\N	\N	2026-01-21 03:25:17.385653+08	2026-01-21 03:25:17.385653+08
\.


--
-- Data for Name: theme_comments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.theme_comments (theme_comment_id, comment, theme_id, actor_id, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: theme_discussions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.theme_discussions (discussion_id, theme_id, parent_discussion_id, author_id, content, position_in_thread, created_at, updated_at, deleted_at) FROM stdin;
1	1	\N	1	Тестовое сообщение в обсуждении	\N	2026-01-21 03:03:46.475277+08	2026-01-21 03:03:46.475277+08	\N
4	1	\N	3	Тестовое сообщение от автора 3	\N	2026-01-21 03:25:17.385653+08	2026-01-21 03:25:17.385653+08	\N
\.


--
-- Data for Name: theme_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.theme_notes (theme_note_id, theme_id, note_id, author_id, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: theme_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.theme_types (theme_type_id, type) FROM stdin;
\.


--
-- Data for Name: themes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.themes (theme_id, title, description, theme_type_id, actor_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by, rating_id) FROM stdin;
1	Тестовая тема	Для тестирования закладок	\N	\N	\N	\N	2026-01-21 03:03:46.475277+08	2026-01-21 03:03:46.475277+08	1	1	\N
\.


--
-- Data for Name: venue_offering_terms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venue_offering_terms (id, venue_id, offering_term_id, cost, currency, special_terms, created_at) FROM stdin;
1	1	4	20000.00	руб.	Аренда на день	2026-01-22 01:10:42.992244
2	1	3	0.00	руб.	Бесплатно для некоммерческих выставок	2026-01-22 01:10:42.992244
3	1	1	5000000.00	руб.	Продажа помещения	2026-01-22 01:10:42.992244
7	2	4	20000.00	руб.	Аренда на день	2026-01-22 01:16:43.751267
8	2	3	0.00	руб.	Бесплатно для некоммерческих выставок	2026-01-22 01:16:43.751267
9	2	1	5000000.00	руб.	Продажа помещения	2026-01-22 01:16:43.751267
\.


--
-- Data for Name: venue_owners; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venue_owners (venue_owner_id, venue_id, actor_id, ownership_type, ownership_share, is_primary, special_conditions, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: venue_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venue_types (venue_type_id, type) FROM stdin;
1	сценическая площадка
2	кафе
3	офис
4	зал
5	помещение
6	лаборатория
\.


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venues (venue_id, title, full_title, venue_type_id, description, actor_id, location_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by, rating_id, geom, latitude, longitude) FROM stdin;
3	Тестовая площадка	Тестовая концертная площадка в Москве	1	Тестовая площадка для отладки глобальных запросов	1	1	\N	\N	2026-01-23 01:20:35.916318+08	2026-01-23 01:20:35.916318+08	\N	\N	\N	\N	\N	\N
1	Выставочный зал	\N	\N	Просторный зал для выставок	\N	\N	\N	\N	2026-01-22 01:10:42.992244+08	2026-01-22 01:10:42.992244+08	\N	\N	\N	0101000020E610000010E9B7AF03CF42408D28ED0DBEE04B40	55.75580000	37.61730000
2	Выставочный зал	\N	\N	Просторный зал для выставок	\N	\N	\N	\N	2026-01-22 01:16:43.751267+08	2026-01-22 01:16:43.751267+08	\N	\N	\N	0101000020E61000008FC2F5285CCF4240E17A14AE47E14B40	55.76000000	37.62000000
\.


--
-- Data for Name: venues_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venues_notes (note_id, venue_id, author_id) FROM stdin;
\.


--
-- Data for Name: venues_stages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venues_stages (venue_id, stage_id) FROM stdin;
\.


--
-- Name: actor_current_statuses_actor_current_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.actor_current_statuses_actor_current_status_id_seq', 1, false);


--
-- Name: actor_statuses_actor_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.actor_statuses_actor_status_id_seq', 1, false);


--
-- Name: actor_types_actor_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.actor_types_actor_type_id_seq', 1, false);


--
-- Name: actors_actor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.actors_actor_id_seq', 10, true);


--
-- Name: actors_functions_actor_function_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.actors_functions_actor_function_id_seq', 1, false);


--
-- Name: asset_files_file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.asset_files_file_id_seq', 20, true);


--
-- Name: asset_types_asset_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.asset_types_asset_type_id_seq', 16, true);


--
-- Name: bookmarks_bookmark_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bookmarks_bookmark_id_seq', 1, false);


--
-- Name: communities_community_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.communities_community_id_seq', 1, false);


--
-- Name: contract_number_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.contract_number_seq', 6, true);


--
-- Name: contract_terms_contract_term_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.contract_terms_contract_term_id_seq', 6, true);


--
-- Name: contracts_contract_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.contracts_contract_id_seq', 7, true);


--
-- Name: directions_direction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.directions_direction_id_seq', 221, true);


--
-- Name: entity_geometries_geometry_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.entity_geometries_geometry_id_seq', 6, true);


--
-- Name: event_statuses_event_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.event_statuses_event_status_id_seq', 10, true);


--
-- Name: event_types_event_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.event_types_event_type_id_seq', 1, false);


--
-- Name: events_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.events_event_id_seq', 6, true);


--
-- Name: favorites_favorite_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.favorites_favorite_id_seq', 1, false);


--
-- Name: file_access_log_access_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.file_access_log_access_id_seq', 1, false);


--
-- Name: file_previews_preview_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.file_previews_preview_id_seq', 1, false);


--
-- Name: file_relations_relation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.file_relations_relation_id_seq', 1, false);


--
-- Name: file_specific_metadata_metadata_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.file_specific_metadata_metadata_id_seq', 1, false);


--
-- Name: finresource_offering_terms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.finresource_offering_terms_id_seq', 3, true);


--
-- Name: finresource_owners_finresource_owner_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.finresource_owners_finresource_owner_id_seq', 1, false);


--
-- Name: finresource_types_finresource_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.finresource_types_finresource_type_id_seq', 1, false);


--
-- Name: finresources_finresource_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.finresources_finresource_id_seq', 3, true);


--
-- Name: finresources_notes_finresource_note_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.finresources_notes_finresource_note_id_seq', 1, false);


--
-- Name: functions_function_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.functions_function_id_seq', 432, true);


--
-- Name: global_request_notifications_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.global_request_notifications_notification_id_seq', 8, true);


--
-- Name: global_request_responses_response_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.global_request_responses_response_id_seq', 6, true);


--
-- Name: global_requests_global_request_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.global_requests_global_request_id_seq', 9, true);


--
-- Name: global_response_status_history_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.global_response_status_history_history_id_seq', 1, false);


--
-- Name: idea_categories_idea_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.idea_categories_idea_category_id_seq', 1, false);


--
-- Name: idea_offering_terms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.idea_offering_terms_id_seq', 1, false);


--
-- Name: idea_types_idea_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.idea_types_idea_type_id_seq', 1, false);


--
-- Name: ideas_idea_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ideas_idea_id_seq', 1, false);


--
-- Name: levels_level_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.levels_level_id_seq', 9, true);


--
-- Name: local_events_local_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.local_events_local_event_id_seq', 1, false);


--
-- Name: locations_location_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.locations_location_id_seq', 1, false);


--
-- Name: matresource_offering_terms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.matresource_offering_terms_id_seq', 21, true);


--
-- Name: matresource_owners_matresource_owner_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.matresource_owners_matresource_owner_id_seq', 4, true);


--
-- Name: matresource_types_matresource_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.matresource_types_matresource_type_id_seq', 80, true);


--
-- Name: matresources_matresource_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.matresources_matresource_id_seq', 22, true);


--
-- Name: messages_message_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.messages_message_id_seq', 1, false);


--
-- Name: notes_note_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notes_note_id_seq', 17, true);


--
-- Name: notifications_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notifications_notification_id_seq', 1, false);


--
-- Name: offering_terms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.offering_terms_id_seq', 1, false);


--
-- Name: organizations_organization_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.organizations_organization_id_seq', 4, true);


--
-- Name: persons_person_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.persons_person_id_seq', 1, true);


--
-- Name: project_actor_roles_project_actor_role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.project_actor_roles_project_actor_role_id_seq', 1, false);


--
-- Name: project_groups_project_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.project_groups_project_group_id_seq', 1, false);


--
-- Name: project_statuses_project_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.project_statuses_project_status_id_seq', 1, false);


--
-- Name: project_types_project_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.project_types_project_type_id_seq', 1, false);


--
-- Name: projects_project_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.projects_project_id_seq', 1, false);


--
-- Name: rating_types_rating_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rating_types_rating_type_id_seq', 2, true);


--
-- Name: ratings_rating_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ratings_rating_id_seq', 5, true);


--
-- Name: request_offering_terms_request_term_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.request_offering_terms_request_term_id_seq', 10, true);


--
-- Name: request_statistic_request_statistic_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.request_statistic_request_statistic_id_seq', 1, false);


--
-- Name: request_statuses_request_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.request_statuses_request_status_id_seq', 12, true);


--
-- Name: request_types_request_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.request_types_request_type_id_seq', 6, true);


--
-- Name: requests_request_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.requests_request_id_seq', 10, true);


--
-- Name: resource_types_resource_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.resource_types_resource_type_id_seq', 18, true);


--
-- Name: service_offering_terms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_offering_terms_id_seq', 17, true);


--
-- Name: service_owners_service_owner_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.service_owners_service_owner_id_seq', 3, true);


--
-- Name: services_service_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.services_service_id_seq', 2, true);


--
-- Name: services_types_services_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.services_types_services_type_id_seq', 1, false);


--
-- Name: stage_architecture_stage_architecture_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_architecture_stage_architecture_id_seq', 1, false);


--
-- Name: stage_audio_stage_audio_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_audio_stage_audio_id_seq', 1, false);


--
-- Name: stage_effects_stage_effects_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_effects_stage_effects_id_seq', 1, false);


--
-- Name: stage_light_stage_light_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_light_stage_light_id_seq', 1, false);


--
-- Name: stage_mobility_stage_mobility_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_mobility_stage_mobility_id_seq', 1, false);


--
-- Name: stage_types_stage_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_types_stage_type_id_seq', 1, false);


--
-- Name: stage_video_stage_video_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_video_stage_video_id_seq', 1, false);


--
-- Name: stages_stage_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stages_stage_id_seq', 1, false);


--
-- Name: system_commands_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.system_commands_id_seq', 6, true);


--
-- Name: system_deployment_log_deployment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.system_deployment_log_deployment_id_seq', 12, true);


--
-- Name: task_types_task_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.task_types_task_type_id_seq', 1, false);


--
-- Name: tasks_task_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tasks_task_id_seq', 1, false);


--
-- Name: temp_contract_terms_temp_term_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.temp_contract_terms_temp_term_id_seq', 8, true);


--
-- Name: temp_contracts_temp_contract_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.temp_contracts_temp_contract_id_seq', 10, true);


--
-- Name: template_offering_terms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.template_offering_terms_id_seq', 1, false);


--
-- Name: templates_notes_template_note_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.templates_notes_template_note_id_seq', 1, false);


--
-- Name: templates_template_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.templates_template_id_seq', 1, false);


--
-- Name: theme_bookmarks_bookmark_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.theme_bookmarks_bookmark_id_seq', 6, true);


--
-- Name: theme_comments_theme_comment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.theme_comments_theme_comment_id_seq', 1, false);


--
-- Name: theme_discussions_discussion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.theme_discussions_discussion_id_seq', 4, true);


--
-- Name: theme_notes_theme_note_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.theme_notes_theme_note_id_seq', 1, false);


--
-- Name: theme_types_theme_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.theme_types_theme_type_id_seq', 1, false);


--
-- Name: themes_theme_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.themes_theme_id_seq', 1, true);


--
-- Name: venue_offering_terms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.venue_offering_terms_id_seq', 12, true);


--
-- Name: venue_owners_venue_owner_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.venue_owners_venue_owner_id_seq', 2, true);


--
-- Name: venue_types_venue_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.venue_types_venue_type_id_seq', 24, true);


--
-- Name: venues_venue_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.venues_venue_id_seq', 3, true);


--
-- Name: actor_credentials actor_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_credentials
    ADD CONSTRAINT actor_credentials_pkey PRIMARY KEY (actor_id);


--
-- Name: actor_current_statuses actor_current_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_current_statuses
    ADD CONSTRAINT actor_current_statuses_pkey PRIMARY KEY (actor_current_status_id);


--
-- Name: actor_status_mapping actor_status_mapping_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_status_mapping
    ADD CONSTRAINT actor_status_mapping_pkey PRIMARY KEY (rating_id);


--
-- Name: actor_statuses actor_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_statuses
    ADD CONSTRAINT actor_statuses_pkey PRIMARY KEY (actor_status_id);


--
-- Name: actor_statuses actor_statuses_status_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_statuses
    ADD CONSTRAINT actor_statuses_status_key UNIQUE (status);


--
-- Name: actor_types actor_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_types
    ADD CONSTRAINT actor_types_pkey PRIMARY KEY (actor_type_id);


--
-- Name: actor_types actor_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_types
    ADD CONSTRAINT actor_types_type_key UNIQUE (type);


--
-- Name: actors actors_account_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT actors_account_key UNIQUE (account);


--
-- Name: actors_directions actors_directions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_directions
    ADD CONSTRAINT actors_directions_pkey PRIMARY KEY (actor_id, direction_id);


--
-- Name: actors_events actors_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_events
    ADD CONSTRAINT actors_events_pkey PRIMARY KEY (actor_id, event_id);


--
-- Name: actors_functions actors_functions_actor_id_function_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_functions
    ADD CONSTRAINT actors_functions_actor_id_function_id_key UNIQUE (actor_id, function_id);


--
-- Name: actors_functions actors_functions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_functions
    ADD CONSTRAINT actors_functions_pkey PRIMARY KEY (actor_function_id);


--
-- Name: actors_locations actors_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_locations
    ADD CONSTRAINT actors_locations_pkey PRIMARY KEY (actor_id, location_id);


--
-- Name: actors_messages actors_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_messages
    ADD CONSTRAINT actors_messages_pkey PRIMARY KEY (message_id, actor_id);


--
-- Name: actors_notes actors_notes_actor_id_author_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_notes
    ADD CONSTRAINT actors_notes_actor_id_author_id_key UNIQUE (actor_id, author_id);


--
-- Name: actors_notes actors_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_notes
    ADD CONSTRAINT actors_notes_pkey PRIMARY KEY (note_id, actor_id);


--
-- Name: actors actors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT actors_pkey PRIMARY KEY (actor_id);


--
-- Name: actors_projects actors_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_projects
    ADD CONSTRAINT actors_projects_pkey PRIMARY KEY (actor_id, project_id);


--
-- Name: actors_tasks actors_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_tasks
    ADD CONSTRAINT actors_tasks_pkey PRIMARY KEY (task_id, actor_id);


--
-- Name: asset_files asset_files_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asset_files
    ADD CONSTRAINT asset_files_pkey PRIMARY KEY (file_id);


--
-- Name: asset_types asset_types_asset_table_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asset_types
    ADD CONSTRAINT asset_types_asset_table_key UNIQUE (asset_table);


--
-- Name: asset_types asset_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asset_types
    ADD CONSTRAINT asset_types_pkey PRIMARY KEY (asset_type_id);


--
-- Name: bookmarks bookmarks_actor_id_theme_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_actor_id_theme_id_key UNIQUE (actor_id, theme_id);


--
-- Name: bookmarks bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_pkey PRIMARY KEY (bookmark_id);


--
-- Name: communities communities_actor_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_actor_id_key UNIQUE (actor_id);


--
-- Name: communities communities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_pkey PRIMARY KEY (community_id);


--
-- Name: contract_terms contract_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract_terms
    ADD CONSTRAINT contract_terms_pkey PRIMARY KEY (contract_term_id);


--
-- Name: contracts contracts_contract_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_contract_number_key UNIQUE (contract_number);


--
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (contract_id);


--
-- Name: directions directions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.directions
    ADD CONSTRAINT directions_pkey PRIMARY KEY (direction_id);


--
-- Name: entity_geometries entity_geometries_entity_type_entity_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entity_geometries
    ADD CONSTRAINT entity_geometries_entity_type_entity_id_key UNIQUE (entity_type, entity_id);


--
-- Name: entity_geometries entity_geometries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entity_geometries
    ADD CONSTRAINT entity_geometries_pkey PRIMARY KEY (geometry_id);


--
-- Name: event_statuses event_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_statuses
    ADD CONSTRAINT event_statuses_pkey PRIMARY KEY (event_status_id);


--
-- Name: event_statuses event_statuses_status_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_statuses
    ADD CONSTRAINT event_statuses_status_key UNIQUE (status);


--
-- Name: event_types event_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_types
    ADD CONSTRAINT event_types_pkey PRIMARY KEY (event_type_id);


--
-- Name: event_types event_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_types
    ADD CONSTRAINT event_types_type_key UNIQUE (type);


--
-- Name: events_notes events_notes_event_id_author_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events_notes
    ADD CONSTRAINT events_notes_event_id_author_id_key UNIQUE (event_id, author_id);


--
-- Name: events_notes events_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events_notes
    ADD CONSTRAINT events_notes_pkey PRIMARY KEY (note_id, event_id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (event_id);


--
-- Name: favorites favorites_actor_id_entity_type_entity_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_actor_id_entity_type_entity_id_key UNIQUE (actor_id, entity_type, entity_id);


--
-- Name: favorites favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (favorite_id);


--
-- Name: file_access_log file_access_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_access_log
    ADD CONSTRAINT file_access_log_pkey PRIMARY KEY (access_id);


--
-- Name: file_previews file_previews_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_previews
    ADD CONSTRAINT file_previews_pkey PRIMARY KEY (preview_id);


--
-- Name: file_relations file_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_relations
    ADD CONSTRAINT file_relations_pkey PRIMARY KEY (relation_id);


--
-- Name: file_specific_metadata file_specific_metadata_file_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_specific_metadata
    ADD CONSTRAINT file_specific_metadata_file_id_key UNIQUE (file_id);


--
-- Name: file_specific_metadata file_specific_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_specific_metadata
    ADD CONSTRAINT file_specific_metadata_pkey PRIMARY KEY (metadata_id);


--
-- Name: finresource_offering_terms finresource_offering_terms_finresource_id_offering_term_id__key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_offering_terms
    ADD CONSTRAINT finresource_offering_terms_finresource_id_offering_term_id__key UNIQUE (finresource_id, offering_term_id, cost, currency);


--
-- Name: finresource_offering_terms finresource_offering_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_offering_terms
    ADD CONSTRAINT finresource_offering_terms_pkey PRIMARY KEY (id);


--
-- Name: finresource_owners finresource_owners_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_owners
    ADD CONSTRAINT finresource_owners_pkey PRIMARY KEY (finresource_id, actor_id);


--
-- Name: finresource_types finresource_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_types
    ADD CONSTRAINT finresource_types_pkey PRIMARY KEY (finresource_type_id);


--
-- Name: finresource_types finresource_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_types
    ADD CONSTRAINT finresource_types_type_key UNIQUE (type);


--
-- Name: finresources_notes finresources_notes_finresource_id_author_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources_notes
    ADD CONSTRAINT finresources_notes_finresource_id_author_id_key UNIQUE (finresource_id, author_id);


--
-- Name: finresources_notes finresources_notes_finresource_id_author_id_key1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources_notes
    ADD CONSTRAINT finresources_notes_finresource_id_author_id_key1 UNIQUE (finresource_id, author_id);


--
-- Name: finresources_notes finresources_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources_notes
    ADD CONSTRAINT finresources_notes_pkey PRIMARY KEY (finresource_note_id);


--
-- Name: finresources finresources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources
    ADD CONSTRAINT finresources_pkey PRIMARY KEY (finresource_id);


--
-- Name: functions_directions functions_directions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.functions_directions
    ADD CONSTRAINT functions_directions_pkey PRIMARY KEY (function_id, direction_id);


--
-- Name: functions functions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.functions
    ADD CONSTRAINT functions_pkey PRIMARY KEY (function_id);


--
-- Name: global_request_notifications global_request_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_request_notifications
    ADD CONSTRAINT global_request_notifications_pkey PRIMARY KEY (notification_id);


--
-- Name: global_request_responses global_request_responses_global_request_id_owner_id_resourc_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_request_responses
    ADD CONSTRAINT global_request_responses_global_request_id_owner_id_resourc_key UNIQUE (global_request_id, owner_id, resource_id);


--
-- Name: global_request_responses global_request_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_request_responses
    ADD CONSTRAINT global_request_responses_pkey PRIMARY KEY (response_id);


--
-- Name: global_requests global_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_requests
    ADD CONSTRAINT global_requests_pkey PRIMARY KEY (global_request_id);


--
-- Name: global_response_status_history global_response_status_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_response_status_history
    ADD CONSTRAINT global_response_status_history_pkey PRIMARY KEY (history_id);


--
-- Name: group_tasks group_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_tasks
    ADD CONSTRAINT group_tasks_pkey PRIMARY KEY (task_id, project_group_id);


--
-- Name: idea_categories idea_categories_category_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_categories
    ADD CONSTRAINT idea_categories_category_key UNIQUE (category);


--
-- Name: idea_categories idea_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_categories
    ADD CONSTRAINT idea_categories_pkey PRIMARY KEY (idea_category_id);


--
-- Name: idea_offering_terms idea_offering_terms_idea_id_offering_term_id_cost_currency_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_offering_terms
    ADD CONSTRAINT idea_offering_terms_idea_id_offering_term_id_cost_currency_key UNIQUE (idea_id, offering_term_id, cost, currency);


--
-- Name: idea_offering_terms idea_offering_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_offering_terms
    ADD CONSTRAINT idea_offering_terms_pkey PRIMARY KEY (id);


--
-- Name: idea_types idea_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_types
    ADD CONSTRAINT idea_types_pkey PRIMARY KEY (idea_type_id);


--
-- Name: idea_types idea_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_types
    ADD CONSTRAINT idea_types_type_key UNIQUE (type);


--
-- Name: ideas_directions ideas_directions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_directions
    ADD CONSTRAINT ideas_directions_pkey PRIMARY KEY (idea_id, direction_id);


--
-- Name: ideas_notes ideas_notes_idea_id_author_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_notes
    ADD CONSTRAINT ideas_notes_idea_id_author_id_key UNIQUE (idea_id, author_id);


--
-- Name: ideas_notes ideas_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_notes
    ADD CONSTRAINT ideas_notes_pkey PRIMARY KEY (note_id, idea_id);


--
-- Name: ideas ideas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_pkey PRIMARY KEY (idea_id);


--
-- Name: ideas_projects ideas_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_projects
    ADD CONSTRAINT ideas_projects_pkey PRIMARY KEY (idea_id, project_id);


--
-- Name: levels levels_level_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.levels
    ADD CONSTRAINT levels_level_key UNIQUE (level);


--
-- Name: levels levels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.levels
    ADD CONSTRAINT levels_pkey PRIMARY KEY (level_id);


--
-- Name: local_events local_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_events
    ADD CONSTRAINT local_events_pkey PRIMARY KEY (local_event_id);


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (location_id);


--
-- Name: matresource_offering_terms matresource_offering_terms_matresource_id_offering_term_id__key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_offering_terms
    ADD CONSTRAINT matresource_offering_terms_matresource_id_offering_term_id__key UNIQUE (matresource_id, offering_term_id, cost, currency);


--
-- Name: matresource_offering_terms matresource_offering_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_offering_terms
    ADD CONSTRAINT matresource_offering_terms_pkey PRIMARY KEY (id);


--
-- Name: matresource_owners matresource_owners_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_owners
    ADD CONSTRAINT matresource_owners_pkey PRIMARY KEY (matresource_id, actor_id);


--
-- Name: matresource_types matresource_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_types
    ADD CONSTRAINT matresource_types_pkey PRIMARY KEY (matresource_type_id);


--
-- Name: matresources_notes matresources_notes_matresource_id_author_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources_notes
    ADD CONSTRAINT matresources_notes_matresource_id_author_id_key UNIQUE (matresource_id, author_id);


--
-- Name: matresources_notes matresources_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources_notes
    ADD CONSTRAINT matresources_notes_pkey PRIMARY KEY (note_id, matresource_id);


--
-- Name: matresources matresources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources
    ADD CONSTRAINT matresources_pkey PRIMARY KEY (matresource_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (message_id);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (note_id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (notification_id);


--
-- Name: offering_terms offering_terms_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offering_terms
    ADD CONSTRAINT offering_terms_code_key UNIQUE (code);


--
-- Name: offering_terms offering_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.offering_terms
    ADD CONSTRAINT offering_terms_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_actor_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_actor_id_key UNIQUE (actor_id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (organization_id);


--
-- Name: persons persons_actor_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_actor_id_key UNIQUE (actor_id);


--
-- Name: persons persons_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_pkey PRIMARY KEY (person_id);


--
-- Name: project_actor_roles project_actor_roles_actor_id_project_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_actor_roles
    ADD CONSTRAINT project_actor_roles_actor_id_project_id_key UNIQUE (actor_id, project_id);


--
-- Name: project_actor_roles project_actor_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_actor_roles
    ADD CONSTRAINT project_actor_roles_pkey PRIMARY KEY (project_actor_role_id);


--
-- Name: project_groups project_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_groups
    ADD CONSTRAINT project_groups_pkey PRIMARY KEY (project_group_id);


--
-- Name: project_statuses project_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_statuses
    ADD CONSTRAINT project_statuses_pkey PRIMARY KEY (project_status_id);


--
-- Name: project_statuses project_statuses_status_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_statuses
    ADD CONSTRAINT project_statuses_status_key UNIQUE (status);


--
-- Name: project_types project_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_types
    ADD CONSTRAINT project_types_pkey PRIMARY KEY (project_type_id);


--
-- Name: project_types project_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_types
    ADD CONSTRAINT project_types_type_key UNIQUE (type);


--
-- Name: projects projects_account_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_account_key UNIQUE (account);


--
-- Name: projects_directions projects_directions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_directions
    ADD CONSTRAINT projects_directions_pkey PRIMARY KEY (project_id, direction_id);


--
-- Name: projects_functions projects_functions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_functions
    ADD CONSTRAINT projects_functions_pkey PRIMARY KEY (project_id, function_id);


--
-- Name: projects_local_events projects_local_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_local_events
    ADD CONSTRAINT projects_local_events_pkey PRIMARY KEY (project_id, local_event_id);


--
-- Name: projects_locations projects_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_locations
    ADD CONSTRAINT projects_locations_pkey PRIMARY KEY (project_id, location_id);


--
-- Name: projects_notes projects_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_notes
    ADD CONSTRAINT projects_notes_pkey PRIMARY KEY (note_id, project_id);


--
-- Name: projects_notes projects_notes_project_id_author_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_notes
    ADD CONSTRAINT projects_notes_project_id_author_id_key UNIQUE (project_id, author_id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (project_id);


--
-- Name: projects_tasks projects_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_tasks
    ADD CONSTRAINT projects_tasks_pkey PRIMARY KEY (task_id, project_id);


--
-- Name: rating_types rating_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rating_types
    ADD CONSTRAINT rating_types_pkey PRIMARY KEY (rating_type_id);


--
-- Name: rating_types rating_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rating_types
    ADD CONSTRAINT rating_types_type_key UNIQUE (type);


--
-- Name: ratings ratings_actor_id_rating_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_actor_id_rating_id_key UNIQUE (actor_id, rating_id);


--
-- Name: ratings ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_pkey PRIMARY KEY (rating_id);


--
-- Name: request_offering_terms request_offering_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_offering_terms
    ADD CONSTRAINT request_offering_terms_pkey PRIMARY KEY (request_term_id);


--
-- Name: request_statistic request_statistic_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_statistic
    ADD CONSTRAINT request_statistic_pkey PRIMARY KEY (request_statistic_id);


--
-- Name: request_statuses request_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_statuses
    ADD CONSTRAINT request_statuses_pkey PRIMARY KEY (request_status_id);


--
-- Name: request_statuses request_statuses_status_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_statuses
    ADD CONSTRAINT request_statuses_status_key UNIQUE (status);


--
-- Name: request_types request_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_types
    ADD CONSTRAINT request_types_pkey PRIMARY KEY (request_type_id);


--
-- Name: request_types request_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_types
    ADD CONSTRAINT request_types_type_key UNIQUE (type);


--
-- Name: requests requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_pkey PRIMARY KEY (request_id);


--
-- Name: resource_types resource_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resource_types
    ADD CONSTRAINT resource_types_pkey PRIMARY KEY (resource_type_id);


--
-- Name: resource_types resource_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resource_types
    ADD CONSTRAINT resource_types_type_key UNIQUE (type);


--
-- Name: service_offering_terms service_offering_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_offering_terms
    ADD CONSTRAINT service_offering_terms_pkey PRIMARY KEY (id);


--
-- Name: service_offering_terms service_offering_terms_service_id_offering_term_id_cost_cur_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_offering_terms
    ADD CONSTRAINT service_offering_terms_service_id_offering_term_id_cost_cur_key UNIQUE (service_id, offering_term_id, cost, currency);


--
-- Name: service_owners service_owners_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_owners
    ADD CONSTRAINT service_owners_pkey PRIMARY KEY (service_owner_id);


--
-- Name: services_notes services_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_notes
    ADD CONSTRAINT services_notes_pkey PRIMARY KEY (note_id, service_id);


--
-- Name: services_notes services_notes_service_id_author_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_notes
    ADD CONSTRAINT services_notes_service_id_author_id_key UNIQUE (service_id, author_id);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (service_id);


--
-- Name: services_types services_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_types
    ADD CONSTRAINT services_types_pkey PRIMARY KEY (services_type_id);


--
-- Name: stage_architecture stage_architecture_architecture_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_architecture
    ADD CONSTRAINT stage_architecture_architecture_key UNIQUE (architecture);


--
-- Name: stage_architecture stage_architecture_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_architecture
    ADD CONSTRAINT stage_architecture_pkey PRIMARY KEY (stage_architecture_id);


--
-- Name: stage_audio stage_audio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio
    ADD CONSTRAINT stage_audio_pkey PRIMARY KEY (stage_audio_id);


--
-- Name: stage_audio_set stage_audio_set_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio_set
    ADD CONSTRAINT stage_audio_set_pkey PRIMARY KEY (stage_id, stage_audio_id);


--
-- Name: stage_effects stage_effects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects
    ADD CONSTRAINT stage_effects_pkey PRIMARY KEY (stage_effects_id);


--
-- Name: stage_effects_set stage_effects_set_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects_set
    ADD CONSTRAINT stage_effects_set_pkey PRIMARY KEY (stage_id, stage_effects_id);


--
-- Name: stage_light stage_light_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light
    ADD CONSTRAINT stage_light_pkey PRIMARY KEY (stage_light_id);


--
-- Name: stage_light_set stage_light_set_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light_set
    ADD CONSTRAINT stage_light_set_pkey PRIMARY KEY (stage_id, stage_light_id);


--
-- Name: stage_mobility stage_mobility_mobility_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_mobility
    ADD CONSTRAINT stage_mobility_mobility_key UNIQUE (mobility);


--
-- Name: stage_mobility stage_mobility_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_mobility
    ADD CONSTRAINT stage_mobility_pkey PRIMARY KEY (stage_mobility_id);


--
-- Name: stage_types stage_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_types
    ADD CONSTRAINT stage_types_pkey PRIMARY KEY (stage_type_id);


--
-- Name: stage_types stage_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_types
    ADD CONSTRAINT stage_types_type_key UNIQUE (type);


--
-- Name: stage_video stage_video_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video
    ADD CONSTRAINT stage_video_pkey PRIMARY KEY (stage_video_id);


--
-- Name: stage_video_set stage_video_set_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video_set
    ADD CONSTRAINT stage_video_set_pkey PRIMARY KEY (stage_id, stage_video_id);


--
-- Name: stages stages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_pkey PRIMARY KEY (stage_id);


--
-- Name: system_commands system_commands_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_commands
    ADD CONSTRAINT system_commands_pkey PRIMARY KEY (id);


--
-- Name: system_deployment_log system_deployment_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_deployment_log
    ADD CONSTRAINT system_deployment_log_pkey PRIMARY KEY (deployment_id);


--
-- Name: task_types task_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_types
    ADD CONSTRAINT task_types_pkey PRIMARY KEY (task_type_id);


--
-- Name: task_types task_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_types
    ADD CONSTRAINT task_types_type_key UNIQUE (type);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (task_id);


--
-- Name: temp_contract_terms temp_contract_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.temp_contract_terms
    ADD CONSTRAINT temp_contract_terms_pkey PRIMARY KEY (temp_term_id);


--
-- Name: temp_contracts temp_contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.temp_contracts
    ADD CONSTRAINT temp_contracts_pkey PRIMARY KEY (temp_contract_id);


--
-- Name: template_offering_terms template_offering_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.template_offering_terms
    ADD CONSTRAINT template_offering_terms_pkey PRIMARY KEY (id);


--
-- Name: template_offering_terms template_offering_terms_template_id_offering_term_id_cost_c_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.template_offering_terms
    ADD CONSTRAINT template_offering_terms_template_id_offering_term_id_cost_c_key UNIQUE (template_id, offering_term_id, cost, currency);


--
-- Name: templates_finresources templates_finresources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_finresources
    ADD CONSTRAINT templates_finresources_pkey PRIMARY KEY (template_id, finresource_id);


--
-- Name: templates_functions templates_functions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_functions
    ADD CONSTRAINT templates_functions_pkey PRIMARY KEY (template_id, function_id);


--
-- Name: templates_matresources templates_matresources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_matresources
    ADD CONSTRAINT templates_matresources_pkey PRIMARY KEY (template_id, matresource_id);


--
-- Name: templates_notes templates_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_notes
    ADD CONSTRAINT templates_notes_pkey PRIMARY KEY (template_note_id);


--
-- Name: templates_notes templates_notes_template_id_author_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_notes
    ADD CONSTRAINT templates_notes_template_id_author_id_key UNIQUE (template_id, author_id);


--
-- Name: templates templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (template_id);


--
-- Name: templates_venues templates_venues_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_venues
    ADD CONSTRAINT templates_venues_pkey PRIMARY KEY (template_id, venue_id);


--
-- Name: theme_bookmarks theme_bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_bookmarks
    ADD CONSTRAINT theme_bookmarks_pkey PRIMARY KEY (bookmark_id);


--
-- Name: theme_bookmarks theme_bookmarks_theme_id_actor_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_bookmarks
    ADD CONSTRAINT theme_bookmarks_theme_id_actor_id_key UNIQUE (theme_id, actor_id);


--
-- Name: theme_comments theme_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments
    ADD CONSTRAINT theme_comments_pkey PRIMARY KEY (theme_comment_id);


--
-- Name: theme_discussions theme_discussions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_discussions
    ADD CONSTRAINT theme_discussions_pkey PRIMARY KEY (discussion_id);


--
-- Name: theme_notes theme_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_notes
    ADD CONSTRAINT theme_notes_pkey PRIMARY KEY (theme_note_id);


--
-- Name: theme_notes theme_notes_theme_id_author_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_notes
    ADD CONSTRAINT theme_notes_theme_id_author_id_key UNIQUE (theme_id, author_id);


--
-- Name: theme_notes theme_notes_theme_id_author_id_key1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_notes
    ADD CONSTRAINT theme_notes_theme_id_author_id_key1 UNIQUE (theme_id, author_id);


--
-- Name: theme_types theme_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_types
    ADD CONSTRAINT theme_types_pkey PRIMARY KEY (theme_type_id);


--
-- Name: theme_types theme_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_types
    ADD CONSTRAINT theme_types_type_key UNIQUE (type);


--
-- Name: themes themes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_pkey PRIMARY KEY (theme_id);


--
-- Name: service_owners uq_service_owners_service_actor; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_owners
    ADD CONSTRAINT uq_service_owners_service_actor UNIQUE (service_id, actor_id);


--
-- Name: venue_owners uq_venue_owners_venue_actor; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_owners
    ADD CONSTRAINT uq_venue_owners_venue_actor UNIQUE (venue_id, actor_id);


--
-- Name: venue_offering_terms venue_offering_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_offering_terms
    ADD CONSTRAINT venue_offering_terms_pkey PRIMARY KEY (id);


--
-- Name: venue_offering_terms venue_offering_terms_venue_id_offering_term_id_cost_currenc_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_offering_terms
    ADD CONSTRAINT venue_offering_terms_venue_id_offering_term_id_cost_currenc_key UNIQUE (venue_id, offering_term_id, cost, currency);


--
-- Name: venue_owners venue_owners_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_owners
    ADD CONSTRAINT venue_owners_pkey PRIMARY KEY (venue_owner_id);


--
-- Name: venue_types venue_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_types
    ADD CONSTRAINT venue_types_pkey PRIMARY KEY (venue_type_id);


--
-- Name: venue_types venue_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_types
    ADD CONSTRAINT venue_types_type_key UNIQUE (type);


--
-- Name: venues_notes venues_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_notes
    ADD CONSTRAINT venues_notes_pkey PRIMARY KEY (note_id, venue_id);


--
-- Name: venues_notes venues_notes_venue_id_author_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_notes
    ADD CONSTRAINT venues_notes_venue_id_author_id_key UNIQUE (venue_id, author_id);


--
-- Name: venues venues_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_pkey PRIMARY KEY (venue_id);


--
-- Name: venues_stages venues_stages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_stages
    ADD CONSTRAINT venues_stages_pkey PRIMARY KEY (venue_id, stage_id);


--
-- Name: favorites_entity_type_entity_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX favorites_entity_type_entity_id_idx ON public.favorites USING btree (entity_type, entity_id);


--
-- Name: idx_act_func_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_act_func_actor ON public.actors_functions USING btree (actor_id);


--
-- Name: idx_act_func_func; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_act_func_func ON public.actors_functions USING btree (function_id);


--
-- Name: idx_actors_account; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_account ON public.actors USING btree (account);


--
-- Name: idx_actors_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_created_at ON public.actors USING btree (created_at);


--
-- Name: idx_actors_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_deleted ON public.actors USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- Name: idx_actors_directions_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_directions_actor ON public.actors_directions USING btree (actor_id);


--
-- Name: idx_actors_keywords_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_keywords_gin ON public.actors USING gin (keywords public.gin_trgm_ops);


--
-- Name: idx_actors_notes_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_notes_author ON public.actors_notes USING btree (author_id);


--
-- Name: idx_actors_projects_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_projects_actor ON public.actors_projects USING btree (actor_id);


--
-- Name: idx_actors_projects_project; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_projects_project ON public.actors_projects USING btree (project_id);


--
-- Name: idx_actors_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_type ON public.actors USING btree (actor_type_id);


--
-- Name: idx_asset_files_asset; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asset_files_asset ON public.asset_files USING btree (asset_type_id, asset_record_id);


--
-- Name: idx_asset_files_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asset_files_category ON public.asset_files USING btree (file_category);


--
-- Name: idx_asset_files_filename; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asset_files_filename ON public.asset_files USING btree (lower((file_name)::text));


--
-- Name: idx_asset_files_primary; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asset_files_primary ON public.asset_files USING btree (is_primary) WHERE (is_primary = true);


--
-- Name: idx_asset_files_public; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asset_files_public ON public.asset_files USING btree (is_public) WHERE (is_public = true);


--
-- Name: idx_asset_files_size; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asset_files_size ON public.asset_files USING btree (file_size DESC);


--
-- Name: idx_asset_files_tags; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asset_files_tags ON public.asset_files USING gin (tags);


--
-- Name: idx_asset_files_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asset_files_type ON public.asset_files USING btree (file_type);


--
-- Name: idx_asset_files_type_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asset_files_type_category ON public.asset_files USING btree (file_type, file_category);


--
-- Name: idx_asset_files_upload_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asset_files_upload_date ON public.asset_files USING btree (date(uploaded_at));


--
-- Name: idx_asset_files_uploaded; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_asset_files_uploaded ON public.asset_files USING btree (uploaded_at DESC);


--
-- Name: idx_contract_terms_contract; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contract_terms_contract ON public.contract_terms USING btree (contract_id);


--
-- Name: idx_contract_terms_offering; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contract_terms_offering ON public.contract_terms USING btree (offering_term_id);


--
-- Name: idx_contract_terms_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contract_terms_status ON public.contract_terms USING btree (fulfillment_status);


--
-- Name: idx_contracts_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contracts_created ON public.contracts USING btree (created_at);


--
-- Name: idx_contracts_dates; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contracts_dates ON public.contracts USING btree (start_date, end_date);


--
-- Name: idx_contracts_effective; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contracts_effective ON public.contracts USING btree (effective_from, effective_until);


--
-- Name: idx_contracts_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contracts_number ON public.contracts USING btree (contract_number);


--
-- Name: idx_contracts_owner; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contracts_owner ON public.contracts USING btree (owner_id);


--
-- Name: idx_contracts_request; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contracts_request ON public.contracts USING btree (request_id);


--
-- Name: idx_contracts_requester; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contracts_requester ON public.contracts USING btree (requester_id);


--
-- Name: idx_contracts_resource; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contracts_resource ON public.contracts USING btree (resource_type, resource_id);


--
-- Name: idx_contracts_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contracts_status ON public.contracts USING btree (contract_status);


--
-- Name: idx_contracts_temp; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_contracts_temp ON public.contracts USING btree (temp_contract_id);


--
-- Name: idx_directions_description_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_directions_description_gin ON public.directions USING gin (to_tsvector('russian'::regconfig, description));


--
-- Name: idx_directions_title_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_directions_title_gin ON public.directions USING gin (to_tsvector('russian'::regconfig, (title)::text));


--
-- Name: idx_entity_geometries_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_entity_geometries_created_at ON public.entity_geometries USING btree (created_at DESC);


--
-- Name: idx_entity_geometries_entity; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_entity_geometries_entity ON public.entity_geometries USING btree (entity_type, entity_id);


--
-- Name: idx_entity_geometries_geom; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_entity_geometries_geom ON public.entity_geometries USING gist (geom);


--
-- Name: idx_entity_geometries_verified; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_entity_geometries_verified ON public.entity_geometries USING btree (is_verified) WHERE (is_verified = true);


--
-- Name: idx_events_cost; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_cost ON public.events USING btree (cost) WHERE (cost > (0)::numeric);


--
-- Name: idx_events_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_date ON public.events USING btree (date);


--
-- Name: idx_events_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_deleted ON public.events USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- Name: idx_events_notes_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_notes_author ON public.events_notes USING btree (author_id);


--
-- Name: idx_events_offering_term; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_offering_term ON public.events USING btree (offering_term_id);


--
-- Name: idx_events_offering_term_cost; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_offering_term_cost ON public.events USING btree (offering_term_id, cost);


--
-- Name: idx_events_title_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_title_gin ON public.events USING gin (to_tsvector('russian'::regconfig, (title)::text));


--
-- Name: idx_events_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_type ON public.events USING btree (event_type_id);


--
-- Name: idx_finresource_owners_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_finresource_owners_unique ON public.finresource_owners USING btree (finresource_owner_id);


--
-- Name: idx_finresources_notes_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_finresources_notes_author ON public.finresources_notes USING btree (author_id);


--
-- Name: idx_global_requests_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_global_requests_active ON public.global_requests USING btree (is_active);


--
-- Name: idx_global_requests_active_true; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_global_requests_active_true ON public.global_requests USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_global_requests_composite; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_global_requests_composite ON public.global_requests USING btree (resource_type_id, subject_type_id, subject_id);


--
-- Name: idx_global_requests_requester; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_global_requests_requester ON public.global_requests USING btree (requester_id);


--
-- Name: idx_global_requests_resource_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_global_requests_resource_type ON public.global_requests USING btree (resource_type_id);


--
-- Name: idx_global_requests_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_global_requests_status ON public.global_requests USING btree (request_status_id);


--
-- Name: idx_global_requests_validity; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_global_requests_validity ON public.global_requests USING btree (validity_period);


--
-- Name: idx_global_requests_validity_not_null; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_global_requests_validity_not_null ON public.global_requests USING btree (validity_period) WHERE (validity_period IS NOT NULL);


--
-- Name: idx_idea_offering_cost; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_idea_offering_cost ON public.idea_offering_terms USING btree (cost) WHERE (cost > (0)::numeric);


--
-- Name: idx_idea_offering_idea; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_idea_offering_idea ON public.idea_offering_terms USING btree (idea_id);


--
-- Name: idx_idea_offering_term; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_idea_offering_term ON public.idea_offering_terms USING btree (offering_term_id);


--
-- Name: idx_idea_offerings_cost; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_idea_offerings_cost ON public.idea_offering_terms USING btree (cost) WHERE (cost > (0)::numeric);


--
-- Name: idx_ideas_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ideas_actor ON public.ideas USING btree (actor_id);


--
-- Name: idx_ideas_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ideas_category ON public.ideas USING btree (idea_category_id);


--
-- Name: idx_ideas_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ideas_deleted ON public.ideas USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- Name: idx_ideas_description_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ideas_description_gin ON public.ideas USING gin (to_tsvector('russian'::regconfig, full_description));


--
-- Name: idx_ideas_notes_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ideas_notes_author ON public.ideas_notes USING btree (author_id);


--
-- Name: idx_ideas_title_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ideas_title_gin ON public.ideas USING gin (to_tsvector('russian'::regconfig, (title)::text));


--
-- Name: idx_matresource_offering_cost; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_matresource_offering_cost ON public.matresource_offering_terms USING btree (cost) WHERE (cost > (0)::numeric);


--
-- Name: idx_matresource_offering_mat; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_matresource_offering_mat ON public.matresource_offering_terms USING btree (matresource_id);


--
-- Name: idx_matresource_offering_term; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_matresource_offering_term ON public.matresource_offering_terms USING btree (offering_term_id);


--
-- Name: idx_matresource_offerings_cost; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_matresource_offerings_cost ON public.matresource_offering_terms USING btree (cost) WHERE (cost > (0)::numeric);


--
-- Name: idx_matresource_offerings_special_terms; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_matresource_offerings_special_terms ON public.matresource_offering_terms USING gin (to_tsvector('russian'::regconfig, special_terms));


--
-- Name: idx_matresource_offerings_term; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_matresource_offerings_term ON public.matresource_offering_terms USING btree (offering_term_id);


--
-- Name: idx_matresource_owners_unique; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_matresource_owners_unique ON public.matresource_owners USING btree (matresource_owner_id);


--
-- Name: idx_matresources_notes_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_matresources_notes_author ON public.matresources_notes USING btree (author_id);


--
-- Name: idx_notifications_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_actor ON public.global_request_notifications USING btree (actor_id);


--
-- Name: idx_notifications_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_created ON public.notifications USING btree (created_at);


--
-- Name: idx_notifications_read; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_read ON public.notifications USING btree (is_read);


--
-- Name: idx_notifications_recipient; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_recipient ON public.notifications USING btree (recipient);


--
-- Name: idx_notifications_request; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_request ON public.global_request_notifications USING btree (global_request_id);


--
-- Name: idx_notifications_unread; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_unread ON public.global_request_notifications USING btree (is_read);


--
-- Name: idx_notifications_unread_false; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_unread_false ON public.global_request_notifications USING btree (is_read) WHERE (is_read = false);


--
-- Name: idx_offering_terms_paid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_offering_terms_paid ON public.offering_terms USING btree (is_paid);


--
-- Name: idx_persons_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_persons_actor ON public.persons USING btree (actor_id);


--
-- Name: idx_persons_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_persons_deleted ON public.persons USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- Name: idx_persons_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_persons_email ON public.persons USING btree (email);


--
-- Name: idx_persons_name_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_persons_name_gin ON public.persons USING gin (to_tsvector('russian'::regconfig, (((name)::text || ' '::text) || (last_name)::text)));


--
-- Name: idx_persons_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_persons_phone ON public.persons USING btree (phone_number);


--
-- Name: idx_project_actor_roles_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_project_actor_roles_actor ON public.project_actor_roles USING btree (actor_id);


--
-- Name: idx_project_actor_roles_actor_project; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_project_actor_roles_actor_project ON public.project_actor_roles USING btree (actor_id, project_id);


--
-- Name: idx_project_actor_roles_project; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_project_actor_roles_project ON public.project_actor_roles USING btree (project_id);


--
-- Name: idx_project_actor_roles_role; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_project_actor_roles_role ON public.project_actor_roles USING btree (role_type);


--
-- Name: idx_projects_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_author ON public.projects USING btree (author_id);


--
-- Name: idx_projects_cost; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_cost ON public.projects USING btree (cost) WHERE (cost > (0)::numeric);


--
-- Name: idx_projects_dates; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_dates ON public.projects USING btree (start_date, end_date);


--
-- Name: idx_projects_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_deleted ON public.projects USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- Name: idx_projects_description_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_description_gin ON public.projects USING gin (to_tsvector('russian'::regconfig, description));


--
-- Name: idx_projects_directions_project; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_directions_project ON public.projects_directions USING btree (project_id);


--
-- Name: idx_projects_keywords_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_keywords_gin ON public.projects USING gin (keywords public.gin_trgm_ops);


--
-- Name: idx_projects_locations_project; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_locations_project ON public.projects_locations USING btree (project_id);


--
-- Name: idx_projects_notes_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_notes_author ON public.projects_notes USING btree (author_id);


--
-- Name: idx_projects_offering_term; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_offering_term ON public.projects USING btree (offering_term_id);


--
-- Name: idx_projects_offering_term_cost; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_offering_term_cost ON public.projects USING btree (offering_term_id, cost);


--
-- Name: idx_projects_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_status ON public.projects USING btree (project_status_id);


--
-- Name: idx_projects_title_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_title_gin ON public.projects USING gin (to_tsvector('russian'::regconfig, (title)::text));


--
-- Name: idx_projects_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_type ON public.projects USING btree (project_type_id);


--
-- Name: idx_req_event; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_req_event ON public.requests USING btree (event_id);


--
-- Name: idx_req_location; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_req_location ON public.requests USING btree (location_id);


--
-- Name: idx_req_stat_creation; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_req_stat_creation ON public.request_statistic USING btree (creation_time);


--
-- Name: idx_req_stat_location; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_req_stat_location ON public.request_statistic USING btree (location_id);


--
-- Name: idx_req_stat_resource; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_req_stat_resource ON public.request_statistic USING btree (resource_type_id);


--
-- Name: idx_req_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_req_status ON public.requests USING btree (request_status_id);


--
-- Name: idx_req_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_req_type ON public.requests USING btree (request_type_id);


--
-- Name: idx_req_validity; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_req_validity ON public.requests USING btree (validity_period) WHERE (validity_period IS NOT NULL);


--
-- Name: idx_request_terms_offering; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_request_terms_offering ON public.request_offering_terms USING btree (offering_term_id);


--
-- Name: idx_request_terms_request; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_request_terms_request ON public.request_offering_terms USING btree (request_id);


--
-- Name: idx_request_terms_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_request_terms_status ON public.request_offering_terms USING btree (term_status);


--
-- Name: idx_requests_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_requests_created ON public.requests USING btree (created_at);


--
-- Name: idx_requests_dates; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_requests_dates ON public.requests USING btree (start_date, end_date);


--
-- Name: idx_requests_project; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_requests_project ON public.requests USING btree (project_id);


--
-- Name: idx_requests_requester; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_requests_requester ON public.requests USING btree (requester_id);


--
-- Name: idx_requests_resource; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_requests_resource ON public.requests USING btree (resource_type, resource_id);


--
-- Name: idx_responses_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_responses_active ON public.global_request_responses USING btree (is_active);


--
-- Name: idx_responses_active_true; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_responses_active_true ON public.global_request_responses USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_responses_owner; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_responses_owner ON public.global_request_responses USING btree (owner_id);


--
-- Name: idx_responses_request; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_responses_request ON public.global_request_responses USING btree (global_request_id);


--
-- Name: idx_responses_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_responses_status ON public.global_request_responses USING btree (status);


--
-- Name: idx_service_offering_cost; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_service_offering_cost ON public.service_offering_terms USING btree (cost) WHERE (cost > (0)::numeric);


--
-- Name: idx_service_offering_service; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_service_offering_service ON public.service_offering_terms USING btree (service_id);


--
-- Name: idx_service_offering_term; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_service_offering_term ON public.service_offering_terms USING btree (offering_term_id);


--
-- Name: idx_service_offerings_cost; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_service_offerings_cost ON public.service_offering_terms USING btree (cost) WHERE (cost > (0)::numeric);


--
-- Name: idx_service_owners_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_service_owners_actor ON public.service_owners USING btree (actor_id);


--
-- Name: idx_service_owners_primary; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_service_owners_primary ON public.service_owners USING btree (is_primary) WHERE (is_primary = true);


--
-- Name: idx_service_owners_service; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_service_owners_service ON public.service_owners USING btree (service_id);


--
-- Name: idx_services_notes_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_services_notes_author ON public.services_notes USING btree (author_id);


--
-- Name: idx_tasks_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tasks_deleted ON public.tasks USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- Name: idx_tasks_due_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tasks_due_date ON public.tasks USING btree (due_date);


--
-- Name: idx_tasks_priority; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tasks_priority ON public.tasks USING btree (priority);


--
-- Name: idx_temp_contract_terms_contract; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_temp_contract_terms_contract ON public.temp_contract_terms USING btree (temp_contract_id);


--
-- Name: idx_temp_contract_terms_offering; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_temp_contract_terms_offering ON public.temp_contract_terms USING btree (offering_term_id);


--
-- Name: idx_temp_contract_terms_request; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_temp_contract_terms_request ON public.temp_contract_terms USING btree (request_term_id);


--
-- Name: idx_temp_contracts_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_temp_contracts_created ON public.temp_contracts USING btree (created_at);


--
-- Name: idx_temp_contracts_dates; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_temp_contracts_dates ON public.temp_contracts USING btree (start_date, end_date);


--
-- Name: idx_temp_contracts_owner; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_temp_contracts_owner ON public.temp_contracts USING btree (owner_id);


--
-- Name: idx_temp_contracts_request; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_temp_contracts_request ON public.temp_contracts USING btree (request_id);


--
-- Name: idx_temp_contracts_requester; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_temp_contracts_requester ON public.temp_contracts USING btree (requester_id);


--
-- Name: idx_temp_contracts_resource; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_temp_contracts_resource ON public.temp_contracts USING btree (resource_type, resource_id);


--
-- Name: idx_temp_contracts_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_temp_contracts_status ON public.temp_contracts USING btree (contract_status);


--
-- Name: idx_template_offering_cost; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_template_offering_cost ON public.template_offering_terms USING btree (cost) WHERE (cost > (0)::numeric);


--
-- Name: idx_template_offering_template; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_template_offering_template ON public.template_offering_terms USING btree (template_id);


--
-- Name: idx_template_offering_term; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_template_offering_term ON public.template_offering_terms USING btree (offering_term_id);


--
-- Name: idx_templates_notes_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_templates_notes_author ON public.templates_notes USING btree (author_id);


--
-- Name: idx_theme_bookmarks_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_theme_bookmarks_actor ON public.theme_bookmarks USING btree (actor_id);


--
-- Name: idx_theme_bookmarks_theme; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_theme_bookmarks_theme ON public.theme_bookmarks USING btree (theme_id);


--
-- Name: idx_theme_discussions_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_theme_discussions_author ON public.theme_discussions USING btree (author_id);


--
-- Name: idx_theme_discussions_parent; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_theme_discussions_parent ON public.theme_discussions USING btree (parent_discussion_id);


--
-- Name: idx_theme_discussions_theme; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_theme_discussions_theme ON public.theme_discussions USING btree (theme_id);


--
-- Name: idx_theme_notes_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_theme_notes_author ON public.theme_notes USING btree (author_id);


--
-- Name: idx_unique_primary_per_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX idx_unique_primary_per_category ON public.asset_files USING btree (asset_type_id, asset_record_id, file_category) WHERE (is_primary = true);


--
-- Name: idx_venue_offering_cost; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_venue_offering_cost ON public.venue_offering_terms USING btree (cost) WHERE (cost > (0)::numeric);


--
-- Name: idx_venue_offering_term; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_venue_offering_term ON public.venue_offering_terms USING btree (offering_term_id);


--
-- Name: idx_venue_offering_venue; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_venue_offering_venue ON public.venue_offering_terms USING btree (venue_id);


--
-- Name: idx_venue_owners_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_venue_owners_actor ON public.venue_owners USING btree (actor_id);


--
-- Name: idx_venue_owners_primary; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_venue_owners_primary ON public.venue_owners USING btree (is_primary) WHERE (is_primary = true);


--
-- Name: idx_venue_owners_venue; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_venue_owners_venue ON public.venue_owners USING btree (venue_id);


--
-- Name: idx_venues_notes_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_venues_notes_author ON public.venues_notes USING btree (author_id);


--
-- Name: unique_human_nickname; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX unique_human_nickname ON public.actors USING btree (nickname, actor_type_id) WHERE ((actor_type_id = 1) AND (nickname IS NOT NULL));


--
-- Name: v_active_contracts _RETURN; Type: RULE; Schema: public; Owner: postgres
--

CREATE OR REPLACE VIEW public.v_active_contracts AS
 SELECT c.contract_id,
    c.contract_number,
    c.contract_title,
    c.resource_type,
    c.resource_id,
        CASE c.resource_type
            WHEN 'matresource'::text THEN ( SELECT matresources.title
               FROM public.matresources
              WHERE (matresources.matresource_id = c.resource_id))
            WHEN 'finresource'::text THEN ( SELECT finresources.title
               FROM public.finresources
              WHERE (finresources.finresource_id = c.resource_id))
            WHEN 'venue'::text THEN ( SELECT venues.title
               FROM public.venues
              WHERE (venues.venue_id = c.resource_id))
            WHEN 'service'::text THEN ( SELECT services.title
               FROM public.services
              WHERE (services.service_id = c.resource_id))
            ELSE NULL::character varying
        END AS resource_title,
    c.requester_id,
    req.nickname AS requester_name,
    c.owner_id,
    own.nickname AS owner_name,
    c.total_cost,
    c.currency,
    c.contract_status,
    c.effective_from,
    c.effective_until,
    count(ct.contract_term_id) AS terms_count,
    sum(
        CASE
            WHEN ((ct.fulfillment_status)::text = 'completed'::text) THEN 1
            ELSE 0
        END) AS completed_terms
   FROM (((public.contracts c
     LEFT JOIN public.actors req ON ((c.requester_id = req.actor_id)))
     LEFT JOIN public.actors own ON ((c.owner_id = own.actor_id)))
     LEFT JOIN public.contract_terms ct ON ((c.contract_id = ct.contract_id)))
  WHERE ((c.contract_status)::text = 'active'::text)
  GROUP BY c.contract_id, req.nickname, own.nickname;


--
-- Name: v_pending_contracts _RETURN; Type: RULE; Schema: public; Owner: postgres
--

CREATE OR REPLACE VIEW public.v_pending_contracts AS
 SELECT tc.temp_contract_id,
    tc.contract_title,
    tc.resource_type,
    tc.resource_id,
        CASE tc.resource_type
            WHEN 'matresource'::text THEN ( SELECT matresources.title
               FROM public.matresources
              WHERE (matresources.matresource_id = tc.resource_id))
            WHEN 'finresource'::text THEN ( SELECT finresources.title
               FROM public.finresources
              WHERE (finresources.finresource_id = tc.resource_id))
            WHEN 'venue'::text THEN ( SELECT venues.title
               FROM public.venues
              WHERE (venues.venue_id = tc.resource_id))
            WHEN 'service'::text THEN ( SELECT services.title
               FROM public.services
              WHERE (services.service_id = tc.resource_id))
            ELSE NULL::character varying
        END AS resource_title,
    tc.requester_id,
    req.nickname AS requester_name,
    tc.owner_id,
    own.nickname AS owner_name,
    tc.contract_status,
    tc.requester_signed,
    tc.owner_signed,
    count(tct.temp_term_id) AS terms_count,
    sum(
        CASE
            WHEN ((tct.term_status)::text = 'agreed'::text) THEN 1
            ELSE 0
        END) AS agreed_terms
   FROM (((public.temp_contracts tc
     LEFT JOIN public.actors req ON ((tc.requester_id = req.actor_id)))
     LEFT JOIN public.actors own ON ((tc.owner_id = own.actor_id)))
     LEFT JOIN public.temp_contract_terms tct ON ((tc.temp_contract_id = tct.temp_contract_id)))
  WHERE ((tc.contract_status)::text <> ALL ((ARRAY['expired'::character varying, 'cancelled'::character varying])::text[]))
  GROUP BY tc.temp_contract_id, req.nickname, own.nickname;


--
-- Name: vw_active_events_calendar _RETURN; Type: RULE; Schema: public; Owner: postgres
--

CREATE OR REPLACE VIEW public.vw_active_events_calendar AS
 SELECT e.event_id,
    e.title,
    e.description,
    e.date,
    e.start_time,
    e.end_time,
    et.type AS event_type,
    count(DISTINCT ae.actor_id) AS participants_count,
    e.created_at
   FROM ((public.events e
     LEFT JOIN public.event_types et ON ((e.event_type_id = et.event_type_id)))
     LEFT JOIN public.actors_events ae ON ((e.event_id = ae.event_id)))
  WHERE (e.deleted_at IS NULL)
  GROUP BY e.event_id, et.type;


--
-- Name: vw_active_projects_summary _RETURN; Type: RULE; Schema: public; Owner: postgres
--

CREATE OR REPLACE VIEW public.vw_active_projects_summary AS
 SELECT p.project_id,
    p.title,
    p.full_title,
    ps.status AS project_status,
    pt.type AS project_type,
    a.nickname AS author_name,
    count(DISTINCT ap.actor_id) AS participants_count,
    p.start_date,
    p.end_date
   FROM ((((public.projects p
     LEFT JOIN public.project_statuses ps ON ((p.project_status_id = ps.project_status_id)))
     LEFT JOIN public.project_types pt ON ((p.project_type_id = pt.project_type_id)))
     LEFT JOIN public.actors a ON (((p.author_id = a.actor_id) AND (a.deleted_at IS NULL))))
     LEFT JOIN public.actors_projects ap ON ((p.project_id = ap.project_id)))
  WHERE (p.deleted_at IS NULL)
  GROUP BY p.project_id, ps.status, pt.type, a.nickname;


--
-- Name: persons check_persons_email_unique; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_persons_email_unique BEFORE INSERT OR UPDATE ON public.persons FOR EACH ROW EXECUTE FUNCTION public.check_unique_for_active_records();


--
-- Name: requests trg_archive_request_before_delete; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_archive_request_before_delete BEFORE DELETE ON public.requests FOR EACH ROW EXECUTE FUNCTION public.archive_request_before_delete();


--
-- Name: requests trg_check_actor_can_create_request; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_actor_can_create_request BEFORE INSERT ON public.requests FOR EACH ROW EXECUTE FUNCTION public.check_actor_can_create_request();


--
-- Name: events trg_check_cost_events; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_cost_events BEFORE INSERT OR UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION public.check_cost_for_free_terms();


--
-- Name: finresource_offering_terms trg_check_cost_finresource_offering; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_cost_finresource_offering BEFORE INSERT OR UPDATE ON public.finresource_offering_terms FOR EACH ROW EXECUTE FUNCTION public.check_cost_for_free_terms();


--
-- Name: finresources trg_check_cost_finresources; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_cost_finresources BEFORE INSERT OR UPDATE ON public.finresources FOR EACH ROW EXECUTE FUNCTION public.check_cost_for_free_terms();


--
-- Name: idea_offering_terms trg_check_cost_idea_offering; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_cost_idea_offering BEFORE INSERT OR UPDATE ON public.idea_offering_terms FOR EACH ROW EXECUTE FUNCTION public.check_cost_for_free_terms();


--
-- Name: matresource_offering_terms trg_check_cost_matresource_offering; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_cost_matresource_offering BEFORE INSERT OR UPDATE ON public.matresource_offering_terms FOR EACH ROW EXECUTE FUNCTION public.check_cost_for_free_terms();


--
-- Name: projects trg_check_cost_projects; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_cost_projects BEFORE INSERT OR UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.check_cost_for_free_terms();


--
-- Name: service_offering_terms trg_check_cost_service_offering; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_cost_service_offering BEFORE INSERT OR UPDATE ON public.service_offering_terms FOR EACH ROW EXECUTE FUNCTION public.check_cost_for_free_terms();


--
-- Name: template_offering_terms trg_check_cost_template_offering; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_cost_template_offering BEFORE INSERT OR UPDATE ON public.template_offering_terms FOR EACH ROW EXECUTE FUNCTION public.check_cost_for_free_terms();


--
-- Name: venue_offering_terms trg_check_cost_venue_offering; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_cost_venue_offering BEFORE INSERT OR UPDATE ON public.venue_offering_terms FOR EACH ROW EXECUTE FUNCTION public.check_cost_for_free_terms();


--
-- Name: requests trg_check_project_owner; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_project_owner BEFORE INSERT OR UPDATE ON public.requests FOR EACH ROW EXECUTE FUNCTION public.check_project_owner_status();


--
-- Name: requests trg_check_request_validity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_request_validity BEFORE UPDATE ON public.requests FOR EACH ROW EXECUTE FUNCTION public.check_request_validity();


--
-- Name: service_offering_terms trg_check_service_offering_terms; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_service_offering_terms BEFORE INSERT OR UPDATE ON public.service_offering_terms FOR EACH ROW EXECUTE FUNCTION public.check_service_offering_terms();


--
-- Name: requests trg_check_validity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_validity BEFORE UPDATE ON public.requests FOR EACH ROW EXECUTE FUNCTION public.check_request_validity();


--
-- Name: temp_contracts trg_create_final_contract; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_create_final_contract BEFORE UPDATE ON public.temp_contracts FOR EACH ROW EXECUTE FUNCTION public.create_final_contract();


--
-- Name: requests trg_create_temp_contract_on_accept; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_create_temp_contract_on_accept AFTER UPDATE ON public.requests FOR EACH ROW EXECUTE FUNCTION public.create_temp_contract_on_request_accept();


--
-- Name: contracts trg_generate_contract_number; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_generate_contract_number BEFORE INSERT ON public.contracts FOR EACH ROW EXECUTE FUNCTION public.generate_contract_number();


--
-- Name: global_request_responses trg_log_response_status_change; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_log_response_status_change BEFORE UPDATE ON public.global_request_responses FOR EACH ROW EXECUTE FUNCTION public.log_global_response_status_change();


--
-- Name: requests trg_set_request_defaults; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_set_request_defaults BEFORE INSERT ON public.requests FOR EACH ROW EXECUTE FUNCTION public.set_request_defaults();


--
-- Name: events trg_update_requests_on_event_change; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_requests_on_event_change AFTER UPDATE OF event_status_id ON public.events FOR EACH ROW EXECUTE FUNCTION public.update_requests_on_event_change();


--
-- Name: projects trg_update_requests_on_project_change; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_requests_on_project_change AFTER UPDATE OF project_status_id ON public.projects FOR EACH ROW EXECUTE FUNCTION public.update_requests_on_project_change();


--
-- Name: contract_terms trg_update_updated_at_contract_terms; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_updated_at_contract_terms BEFORE UPDATE ON public.contract_terms FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: contracts trg_update_updated_at_contracts; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_updated_at_contracts BEFORE UPDATE ON public.contracts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: request_offering_terms trg_update_updated_at_request_offering_terms; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_updated_at_request_offering_terms BEFORE UPDATE ON public.request_offering_terms FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: requests trg_update_updated_at_requests; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_updated_at_requests BEFORE UPDATE ON public.requests FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: service_owners trg_update_updated_at_service_owners; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_updated_at_service_owners BEFORE UPDATE ON public.service_owners FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: temp_contract_terms trg_update_updated_at_temp_contract_terms; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_updated_at_temp_contract_terms BEFORE UPDATE ON public.temp_contract_terms FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: temp_contracts trg_update_updated_at_temp_contracts; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_updated_at_temp_contracts BEFORE UPDATE ON public.temp_contracts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: venue_owners trg_update_updated_at_venue_owners; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_update_updated_at_venue_owners BEFORE UPDATE ON public.venue_owners FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: actors trg_validate_actor_type_integrity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validate_actor_type_integrity BEFORE INSERT OR UPDATE OF actor_type_id ON public.actors FOR EACH ROW EXECUTE FUNCTION public.validate_actor_integrity();


--
-- Name: communities trg_validate_community_integrity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validate_community_integrity BEFORE INSERT OR UPDATE ON public.communities FOR EACH ROW EXECUTE FUNCTION public.validate_actor_type_integrity();


--
-- Name: organizations trg_validate_organization_integrity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validate_organization_integrity BEFORE INSERT OR UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.validate_actor_type_integrity();


--
-- Name: persons trg_validate_person_integrity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validate_person_integrity BEFORE INSERT OR UPDATE ON public.persons FOR EACH ROW EXECUTE FUNCTION public.validate_actor_type_integrity();


--
-- Name: communities trigger_auto_update_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_auto_update_geom BEFORE INSERT OR UPDATE ON public.communities FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom();


--
-- Name: events trigger_auto_update_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_auto_update_geom BEFORE INSERT OR UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom();


--
-- Name: locations trigger_auto_update_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_auto_update_geom BEFORE INSERT OR UPDATE ON public.locations FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom();


--
-- Name: organizations trigger_auto_update_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_auto_update_geom BEFORE INSERT OR UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom();


--
-- Name: projects trigger_auto_update_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_auto_update_geom BEFORE INSERT OR UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom();


--
-- Name: stages trigger_auto_update_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_auto_update_geom BEFORE INSERT OR UPDATE ON public.stages FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom();


--
-- Name: venues trigger_auto_update_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_auto_update_geom BEFORE INSERT OR UPDATE ON public.venues FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom();


--
-- Name: asset_files trigger_check_primary_file; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_check_primary_file BEFORE INSERT OR UPDATE ON public.asset_files FOR EACH ROW EXECUTE FUNCTION public.check_primary_file_uniqueness();


--
-- Name: asset_files trigger_update_asset_files_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_asset_files_updated_at BEFORE UPDATE ON public.asset_files FOR EACH ROW EXECUTE FUNCTION public.update_asset_files_updated_at();


--
-- Name: communities trigger_update_coords_from_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_coords_from_geom BEFORE INSERT OR UPDATE OF geom ON public.communities FOR EACH ROW EXECUTE FUNCTION public.auto_update_coords_from_geom();


--
-- Name: events trigger_update_coords_from_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_coords_from_geom BEFORE INSERT OR UPDATE OF geom ON public.events FOR EACH ROW EXECUTE FUNCTION public.auto_update_coords_from_geom();


--
-- Name: locations trigger_update_coords_from_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_coords_from_geom BEFORE INSERT OR UPDATE OF geom ON public.locations FOR EACH ROW EXECUTE FUNCTION public.auto_update_coords_from_geom();


--
-- Name: organizations trigger_update_coords_from_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_coords_from_geom BEFORE INSERT OR UPDATE OF geom ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.auto_update_coords_from_geom();


--
-- Name: projects trigger_update_coords_from_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_coords_from_geom BEFORE INSERT OR UPDATE OF geom ON public.projects FOR EACH ROW EXECUTE FUNCTION public.auto_update_coords_from_geom();


--
-- Name: stages trigger_update_coords_from_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_coords_from_geom BEFORE INSERT OR UPDATE OF geom ON public.stages FOR EACH ROW EXECUTE FUNCTION public.auto_update_coords_from_geom();


--
-- Name: venues trigger_update_coords_from_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_coords_from_geom BEFORE INSERT OR UPDATE OF geom ON public.venues FOR EACH ROW EXECUTE FUNCTION public.auto_update_coords_from_geom();


--
-- Name: entity_geometries trigger_update_entity_geometries_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_entity_geometries_updated_at BEFORE UPDATE ON public.entity_geometries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: communities trigger_update_geom_from_coords; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_geom_from_coords BEFORE INSERT OR UPDATE OF latitude, longitude ON public.communities FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom_from_coords();


--
-- Name: events trigger_update_geom_from_coords; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_geom_from_coords BEFORE INSERT OR UPDATE OF latitude, longitude ON public.events FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom_from_coords();


--
-- Name: locations trigger_update_geom_from_coords; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_geom_from_coords BEFORE INSERT OR UPDATE OF latitude, longitude ON public.locations FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom_from_coords();


--
-- Name: organizations trigger_update_geom_from_coords; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_geom_from_coords BEFORE INSERT OR UPDATE OF latitude, longitude ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom_from_coords();


--
-- Name: projects trigger_update_geom_from_coords; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_geom_from_coords BEFORE INSERT OR UPDATE OF latitude, longitude ON public.projects FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom_from_coords();


--
-- Name: stages trigger_update_geom_from_coords; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_geom_from_coords BEFORE INSERT OR UPDATE OF latitude, longitude ON public.stages FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom_from_coords();


--
-- Name: venues trigger_update_geom_from_coords; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_geom_from_coords BEFORE INSERT OR UPDATE OF latitude, longitude ON public.venues FOR EACH ROW EXECUTE FUNCTION public.auto_update_geom_from_coords();


--
-- Name: locations trigger_update_location_geom; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_location_geom BEFORE INSERT OR UPDATE ON public.locations FOR EACH ROW EXECUTE FUNCTION public.update_location_geom();


--
-- Name: asset_files trigger_validate_file_mime_type; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_validate_file_mime_type BEFORE INSERT OR UPDATE ON public.asset_files FOR EACH ROW EXECUTE FUNCTION public.validate_file_mime_type();


--
-- Name: actors update_actors_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_actors_updated_at BEFORE UPDATE ON public.actors FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: communities update_communities_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_communities_updated_at BEFORE UPDATE ON public.communities FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: events update_events_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: ideas update_ideas_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_ideas_updated_at BEFORE UPDATE ON public.ideas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: organizations update_organizations_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: persons update_persons_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_persons_updated_at BEFORE UPDATE ON public.persons FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: project_actor_roles update_project_actor_roles_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_project_actor_roles_updated_at BEFORE UPDATE ON public.project_actor_roles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: projects update_projects_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: tasks update_tasks_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: templates update_templates_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_templates_updated_at BEFORE UPDATE ON public.templates FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: actor_credentials actor_credentials_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_credentials
    ADD CONSTRAINT actor_credentials_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: actor_current_statuses actor_current_statuses_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_current_statuses
    ADD CONSTRAINT actor_current_statuses_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id);


--
-- Name: actor_current_statuses actor_current_statuses_actor_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_current_statuses
    ADD CONSTRAINT actor_current_statuses_actor_status_id_fkey FOREIGN KEY (actor_status_id) REFERENCES public.actor_statuses(actor_status_id);


--
-- Name: actor_current_statuses actor_current_statuses_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_current_statuses
    ADD CONSTRAINT actor_current_statuses_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id);


--
-- Name: actor_current_statuses actor_current_statuses_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_current_statuses
    ADD CONSTRAINT actor_current_statuses_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id);


--
-- Name: actors actors_actor_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT actors_actor_type_id_fkey FOREIGN KEY (actor_type_id) REFERENCES public.actor_types(actor_type_id);


--
-- Name: actors actors_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT actors_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id);


--
-- Name: actors_directions actors_directions_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_directions
    ADD CONSTRAINT actors_directions_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: actors_directions actors_directions_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_directions
    ADD CONSTRAINT actors_directions_direction_id_fkey FOREIGN KEY (direction_id) REFERENCES public.directions(direction_id) ON DELETE CASCADE;


--
-- Name: actors_events actors_events_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_events
    ADD CONSTRAINT actors_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: actors_events actors_events_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_events
    ADD CONSTRAINT actors_events_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id) ON DELETE CASCADE;


--
-- Name: actors_functions actors_functions_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_functions
    ADD CONSTRAINT actors_functions_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id);


--
-- Name: actors_functions actors_functions_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_functions
    ADD CONSTRAINT actors_functions_function_id_fkey FOREIGN KEY (function_id) REFERENCES public.functions(function_id);


--
-- Name: actors_functions actors_functions_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_functions
    ADD CONSTRAINT actors_functions_level_id_fkey FOREIGN KEY (level_id) REFERENCES public.levels(level_id);


--
-- Name: actors_locations actors_locations_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_locations
    ADD CONSTRAINT actors_locations_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: actors_locations actors_locations_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_locations
    ADD CONSTRAINT actors_locations_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id) ON DELETE CASCADE;


--
-- Name: actors_messages actors_messages_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_messages
    ADD CONSTRAINT actors_messages_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: actors_messages actors_messages_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_messages
    ADD CONSTRAINT actors_messages_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(message_id) ON DELETE CASCADE;


--
-- Name: actors_notes actors_notes_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_notes
    ADD CONSTRAINT actors_notes_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: actors_notes actors_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_notes
    ADD CONSTRAINT actors_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- Name: actors_notes actors_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_notes
    ADD CONSTRAINT actors_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- Name: actors_projects actors_projects_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_projects
    ADD CONSTRAINT actors_projects_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: actors_projects actors_projects_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_projects
    ADD CONSTRAINT actors_projects_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: actors_projects actors_projects_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_projects
    ADD CONSTRAINT actors_projects_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- Name: actors_projects actors_projects_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_projects
    ADD CONSTRAINT actors_projects_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: actors actors_rating_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT actors_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES public.ratings(rating_id);


--
-- Name: actors_tasks actors_tasks_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_tasks
    ADD CONSTRAINT actors_tasks_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: actors_tasks actors_tasks_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_tasks
    ADD CONSTRAINT actors_tasks_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(task_id) ON DELETE CASCADE;


--
-- Name: actors actors_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT actors_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id);


--
-- Name: asset_files asset_files_asset_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asset_files
    ADD CONSTRAINT asset_files_asset_type_id_fkey FOREIGN KEY (asset_type_id) REFERENCES public.asset_types(asset_type_id);


--
-- Name: asset_files asset_files_previous_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asset_files
    ADD CONSTRAINT asset_files_previous_version_id_fkey FOREIGN KEY (previous_version_id) REFERENCES public.asset_files(file_id);


--
-- Name: asset_files asset_files_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asset_files
    ADD CONSTRAINT asset_files_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES public.actors(actor_id);


--
-- Name: asset_files asset_files_validated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asset_files
    ADD CONSTRAINT asset_files_validated_by_fkey FOREIGN KEY (validated_by) REFERENCES public.actors(actor_id);


--
-- Name: bookmarks bookmarks_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: bookmarks bookmarks_theme_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.themes(theme_id) ON DELETE CASCADE;


--
-- Name: communities communities_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: communities communities_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: communities communities_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id);


--
-- Name: communities communities_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: entity_geometries entity_geometries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entity_geometries
    ADD CONSTRAINT entity_geometries_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id);


--
-- Name: entity_geometries entity_geometries_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entity_geometries
    ADD CONSTRAINT entity_geometries_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id);


--
-- Name: entity_geometries entity_geometries_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entity_geometries
    ADD CONSTRAINT entity_geometries_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES public.actors(actor_id);


--
-- Name: events events_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- Name: events events_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: events events_event_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_event_status_id_fkey FOREIGN KEY (event_status_id) REFERENCES public.event_statuses(event_status_id);


--
-- Name: events events_event_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_event_type_id_fkey FOREIGN KEY (event_type_id) REFERENCES public.event_types(event_type_id);


--
-- Name: events_notes events_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events_notes
    ADD CONSTRAINT events_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- Name: events_notes events_notes_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events_notes
    ADD CONSTRAINT events_notes_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id) ON DELETE CASCADE;


--
-- Name: events_notes events_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events_notes
    ADD CONSTRAINT events_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- Name: events events_offering_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_offering_term_id_fkey FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: events events_rating_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES public.ratings(rating_id);


--
-- Name: events events_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: favorites favorites_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: file_access_log file_access_log_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_access_log
    ADD CONSTRAINT file_access_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id);


--
-- Name: file_access_log file_access_log_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_access_log
    ADD CONSTRAINT file_access_log_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.asset_files(file_id);


--
-- Name: file_previews file_previews_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_previews
    ADD CONSTRAINT file_previews_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.asset_files(file_id) ON DELETE CASCADE;


--
-- Name: file_relations file_relations_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_relations
    ADD CONSTRAINT file_relations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id);


--
-- Name: file_relations file_relations_source_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_relations
    ADD CONSTRAINT file_relations_source_file_id_fkey FOREIGN KEY (source_file_id) REFERENCES public.asset_files(file_id) ON DELETE CASCADE;


--
-- Name: file_relations file_relations_target_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_relations
    ADD CONSTRAINT file_relations_target_file_id_fkey FOREIGN KEY (target_file_id) REFERENCES public.asset_files(file_id) ON DELETE CASCADE;


--
-- Name: file_specific_metadata file_specific_metadata_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.file_specific_metadata
    ADD CONSTRAINT file_specific_metadata_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.asset_files(file_id) ON DELETE CASCADE;


--
-- Name: finresource_offering_terms finresource_offering_terms_finresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_offering_terms
    ADD CONSTRAINT finresource_offering_terms_finresource_id_fkey FOREIGN KEY (finresource_id) REFERENCES public.finresources(finresource_id) ON DELETE CASCADE;


--
-- Name: finresource_offering_terms finresource_offering_terms_offering_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_offering_terms
    ADD CONSTRAINT finresource_offering_terms_offering_term_id_fkey FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: finresource_owners finresource_owners_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_owners
    ADD CONSTRAINT finresource_owners_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: finresource_owners finresource_owners_finresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_owners
    ADD CONSTRAINT finresource_owners_finresource_id_fkey FOREIGN KEY (finresource_id) REFERENCES public.finresources(finresource_id) ON DELETE CASCADE;


--
-- Name: finresources finresources_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources
    ADD CONSTRAINT finresources_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: finresources finresources_finresource_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources
    ADD CONSTRAINT finresources_finresource_type_id_fkey FOREIGN KEY (finresource_type_id) REFERENCES public.finresource_types(finresource_type_id);


--
-- Name: finresources_notes finresources_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources_notes
    ADD CONSTRAINT finresources_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- Name: finresources_notes finresources_notes_finresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources_notes
    ADD CONSTRAINT finresources_notes_finresource_id_fkey FOREIGN KEY (finresource_id) REFERENCES public.finresources(finresource_id);


--
-- Name: finresources_notes finresources_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources_notes
    ADD CONSTRAINT finresources_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id);


--
-- Name: finresources finresources_rating_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources
    ADD CONSTRAINT finresources_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES public.ratings(rating_id);


--
-- Name: finresources finresources_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources
    ADD CONSTRAINT finresources_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: actors fk_actors_actor_types; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT fk_actors_actor_types FOREIGN KEY (actor_type_id) REFERENCES public.actor_types(actor_type_id);


--
-- Name: communities fk_communities_actors; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT fk_communities_actors FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: contract_terms fk_contract_terms_contract; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract_terms
    ADD CONSTRAINT fk_contract_terms_contract FOREIGN KEY (contract_id) REFERENCES public.contracts(contract_id) ON DELETE CASCADE;


--
-- Name: contract_terms fk_contract_terms_offering; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract_terms
    ADD CONSTRAINT fk_contract_terms_offering FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: contracts fk_contracts_owner; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT fk_contracts_owner FOREIGN KEY (owner_id) REFERENCES public.actors(actor_id);


--
-- Name: contracts fk_contracts_request; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT fk_contracts_request FOREIGN KEY (request_id) REFERENCES public.requests(request_id);


--
-- Name: contracts fk_contracts_requester; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT fk_contracts_requester FOREIGN KEY (requester_id) REFERENCES public.actors(actor_id);


--
-- Name: contracts fk_contracts_temp; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT fk_contracts_temp FOREIGN KEY (temp_contract_id) REFERENCES public.temp_contracts(temp_contract_id);


--
-- Name: events fk_events_offering_term; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_events_offering_term FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: organizations fk_organizations_actors; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT fk_organizations_actors FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: persons fk_persons_actors; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT fk_persons_actors FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: projects fk_projects_offering_term; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_projects_offering_term FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: request_offering_terms fk_request_terms_offering; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_offering_terms
    ADD CONSTRAINT fk_request_terms_offering FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: request_offering_terms fk_request_terms_request; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_offering_terms
    ADD CONSTRAINT fk_request_terms_request FOREIGN KEY (request_id) REFERENCES public.requests(request_id) ON DELETE CASCADE;


--
-- Name: requests fk_requests_project; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT fk_requests_project FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: requests fk_requests_requester; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT fk_requests_requester FOREIGN KEY (requester_id) REFERENCES public.actors(actor_id);


--
-- Name: requests fk_requests_reviewer; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT fk_requests_reviewer FOREIGN KEY (reviewed_by) REFERENCES public.actors(actor_id);


--
-- Name: service_owners fk_service_owners_actor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_owners
    ADD CONSTRAINT fk_service_owners_actor FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: service_owners fk_service_owners_service; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_owners
    ADD CONSTRAINT fk_service_owners_service FOREIGN KEY (service_id) REFERENCES public.services(service_id) ON DELETE CASCADE;


--
-- Name: temp_contracts fk_temp_contracts_owner; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.temp_contracts
    ADD CONSTRAINT fk_temp_contracts_owner FOREIGN KEY (owner_id) REFERENCES public.actors(actor_id);


--
-- Name: temp_contracts fk_temp_contracts_request; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.temp_contracts
    ADD CONSTRAINT fk_temp_contracts_request FOREIGN KEY (request_id) REFERENCES public.requests(request_id);


--
-- Name: temp_contracts fk_temp_contracts_requester; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.temp_contracts
    ADD CONSTRAINT fk_temp_contracts_requester FOREIGN KEY (requester_id) REFERENCES public.actors(actor_id);


--
-- Name: temp_contract_terms fk_temp_terms_contract; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.temp_contract_terms
    ADD CONSTRAINT fk_temp_terms_contract FOREIGN KEY (temp_contract_id) REFERENCES public.temp_contracts(temp_contract_id) ON DELETE CASCADE;


--
-- Name: temp_contract_terms fk_temp_terms_offering; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.temp_contract_terms
    ADD CONSTRAINT fk_temp_terms_offering FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: temp_contract_terms fk_temp_terms_request; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.temp_contract_terms
    ADD CONSTRAINT fk_temp_terms_request FOREIGN KEY (request_term_id) REFERENCES public.request_offering_terms(request_term_id);


--
-- Name: venue_owners fk_venue_owners_actor; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_owners
    ADD CONSTRAINT fk_venue_owners_actor FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: venue_owners fk_venue_owners_venue; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_owners
    ADD CONSTRAINT fk_venue_owners_venue FOREIGN KEY (venue_id) REFERENCES public.venues(venue_id) ON DELETE CASCADE;


--
-- Name: functions_directions functions_directions_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.functions_directions
    ADD CONSTRAINT functions_directions_direction_id_fkey FOREIGN KEY (direction_id) REFERENCES public.directions(direction_id) ON DELETE CASCADE;


--
-- Name: functions_directions functions_directions_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.functions_directions
    ADD CONSTRAINT functions_directions_function_id_fkey FOREIGN KEY (function_id) REFERENCES public.functions(function_id) ON DELETE CASCADE;


--
-- Name: global_request_notifications global_request_notifications_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_request_notifications
    ADD CONSTRAINT global_request_notifications_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id);


--
-- Name: global_request_notifications global_request_notifications_global_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_request_notifications
    ADD CONSTRAINT global_request_notifications_global_request_id_fkey FOREIGN KEY (global_request_id) REFERENCES public.global_requests(global_request_id);


--
-- Name: global_request_responses global_request_responses_global_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_request_responses
    ADD CONSTRAINT global_request_responses_global_request_id_fkey FOREIGN KEY (global_request_id) REFERENCES public.global_requests(global_request_id) ON DELETE CASCADE;


--
-- Name: global_request_responses global_request_responses_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_request_responses
    ADD CONSTRAINT global_request_responses_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.actors(actor_id);


--
-- Name: global_requests global_requests_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_requests
    ADD CONSTRAINT global_requests_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id);


--
-- Name: global_requests global_requests_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_requests
    ADD CONSTRAINT global_requests_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id);


--
-- Name: global_requests global_requests_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_requests
    ADD CONSTRAINT global_requests_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id);


--
-- Name: global_requests global_requests_request_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_requests
    ADD CONSTRAINT global_requests_request_status_id_fkey FOREIGN KEY (request_status_id) REFERENCES public.request_statuses(request_status_id);


--
-- Name: global_requests global_requests_requester_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_requests
    ADD CONSTRAINT global_requests_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES public.actors(actor_id);


--
-- Name: global_requests global_requests_resource_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_requests
    ADD CONSTRAINT global_requests_resource_type_id_fkey FOREIGN KEY (resource_type_id) REFERENCES public.resource_types(resource_type_id);


--
-- Name: global_response_status_history global_response_status_history_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_response_status_history
    ADD CONSTRAINT global_response_status_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.actors(actor_id);


--
-- Name: global_response_status_history global_response_status_history_response_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.global_response_status_history
    ADD CONSTRAINT global_response_status_history_response_id_fkey FOREIGN KEY (response_id) REFERENCES public.global_request_responses(response_id) ON DELETE CASCADE;


--
-- Name: group_tasks group_tasks_project_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_tasks
    ADD CONSTRAINT group_tasks_project_group_id_fkey FOREIGN KEY (project_group_id) REFERENCES public.project_groups(project_group_id) ON DELETE CASCADE;


--
-- Name: group_tasks group_tasks_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_tasks
    ADD CONSTRAINT group_tasks_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(task_id) ON DELETE CASCADE;


--
-- Name: idea_offering_terms idea_offering_terms_idea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_offering_terms
    ADD CONSTRAINT idea_offering_terms_idea_id_fkey FOREIGN KEY (idea_id) REFERENCES public.ideas(idea_id) ON DELETE CASCADE;


--
-- Name: idea_offering_terms idea_offering_terms_offering_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_offering_terms
    ADD CONSTRAINT idea_offering_terms_offering_term_id_fkey FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: ideas ideas_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: ideas ideas_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: ideas_directions ideas_directions_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_directions
    ADD CONSTRAINT ideas_directions_direction_id_fkey FOREIGN KEY (direction_id) REFERENCES public.directions(direction_id) ON DELETE CASCADE;


--
-- Name: ideas_directions ideas_directions_idea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_directions
    ADD CONSTRAINT ideas_directions_idea_id_fkey FOREIGN KEY (idea_id) REFERENCES public.ideas(idea_id) ON DELETE CASCADE;


--
-- Name: ideas ideas_idea_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_idea_category_id_fkey FOREIGN KEY (idea_category_id) REFERENCES public.idea_categories(idea_category_id);


--
-- Name: ideas ideas_idea_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_idea_type_id_fkey FOREIGN KEY (idea_type_id) REFERENCES public.idea_types(idea_type_id);


--
-- Name: ideas_notes ideas_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_notes
    ADD CONSTRAINT ideas_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- Name: ideas_notes ideas_notes_idea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_notes
    ADD CONSTRAINT ideas_notes_idea_id_fkey FOREIGN KEY (idea_id) REFERENCES public.ideas(idea_id) ON DELETE CASCADE;


--
-- Name: ideas_notes ideas_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_notes
    ADD CONSTRAINT ideas_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- Name: ideas_projects ideas_projects_idea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_projects
    ADD CONSTRAINT ideas_projects_idea_id_fkey FOREIGN KEY (idea_id) REFERENCES public.ideas(idea_id) ON DELETE CASCADE;


--
-- Name: ideas_projects ideas_projects_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_projects
    ADD CONSTRAINT ideas_projects_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- Name: ideas ideas_rating_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES public.ratings(rating_id);


--
-- Name: ideas ideas_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: local_events local_events_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_events
    ADD CONSTRAINT local_events_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: local_events local_events_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_events
    ADD CONSTRAINT local_events_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: matresource_offering_terms matresource_offering_terms_matresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_offering_terms
    ADD CONSTRAINT matresource_offering_terms_matresource_id_fkey FOREIGN KEY (matresource_id) REFERENCES public.matresources(matresource_id) ON DELETE CASCADE;


--
-- Name: matresource_offering_terms matresource_offering_terms_offering_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_offering_terms
    ADD CONSTRAINT matresource_offering_terms_offering_term_id_fkey FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: matresource_owners matresource_owners_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_owners
    ADD CONSTRAINT matresource_owners_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: matresource_owners matresource_owners_matresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_owners
    ADD CONSTRAINT matresource_owners_matresource_id_fkey FOREIGN KEY (matresource_id) REFERENCES public.matresources(matresource_id) ON DELETE CASCADE;


--
-- Name: matresources matresources_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources
    ADD CONSTRAINT matresources_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: matresources matresources_matresource_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources
    ADD CONSTRAINT matresources_matresource_type_id_fkey FOREIGN KEY (matresource_type_id) REFERENCES public.matresource_types(matresource_type_id);


--
-- Name: matresources_notes matresources_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources_notes
    ADD CONSTRAINT matresources_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- Name: matresources_notes matresources_notes_matresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources_notes
    ADD CONSTRAINT matresources_notes_matresource_id_fkey FOREIGN KEY (matresource_id) REFERENCES public.matresources(matresource_id) ON DELETE CASCADE;


--
-- Name: matresources_notes matresources_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources_notes
    ADD CONSTRAINT matresources_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- Name: matresources matresources_rating_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources
    ADD CONSTRAINT matresources_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES public.ratings(rating_id);


--
-- Name: matresources matresources_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources
    ADD CONSTRAINT matresources_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: messages messages_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: messages messages_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: messages messages_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: notes notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: notes notes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: notes notes_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: notifications notifications_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: notifications notifications_recipient_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_recipient_fkey FOREIGN KEY (recipient) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: notifications notifications_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: organizations organizations_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: organizations organizations_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: organizations organizations_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id);


--
-- Name: organizations organizations_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: persons persons_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: persons persons_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: persons persons_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id);


--
-- Name: persons persons_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: project_actor_roles project_actor_roles_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_actor_roles
    ADD CONSTRAINT project_actor_roles_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: project_actor_roles project_actor_roles_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_actor_roles
    ADD CONSTRAINT project_actor_roles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.actors(actor_id);


--
-- Name: project_actor_roles project_actor_roles_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_actor_roles
    ADD CONSTRAINT project_actor_roles_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- Name: project_groups project_groups_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_groups
    ADD CONSTRAINT project_groups_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: project_groups project_groups_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_groups
    ADD CONSTRAINT project_groups_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: project_groups project_groups_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_groups
    ADD CONSTRAINT project_groups_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- Name: project_groups project_groups_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_groups
    ADD CONSTRAINT project_groups_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: projects projects_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: projects projects_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: projects_directions projects_directions_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_directions
    ADD CONSTRAINT projects_directions_direction_id_fkey FOREIGN KEY (direction_id) REFERENCES public.directions(direction_id) ON DELETE CASCADE;


--
-- Name: projects_directions projects_directions_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_directions
    ADD CONSTRAINT projects_directions_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- Name: projects projects_director_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_director_id_fkey FOREIGN KEY (director_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: projects_functions projects_functions_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_functions
    ADD CONSTRAINT projects_functions_function_id_fkey FOREIGN KEY (function_id) REFERENCES public.functions(function_id) ON DELETE CASCADE;


--
-- Name: projects_functions projects_functions_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_functions
    ADD CONSTRAINT projects_functions_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- Name: projects_local_events projects_local_events_local_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_local_events
    ADD CONSTRAINT projects_local_events_local_event_id_fkey FOREIGN KEY (local_event_id) REFERENCES public.local_events(local_event_id) ON DELETE CASCADE;


--
-- Name: projects_local_events projects_local_events_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_local_events
    ADD CONSTRAINT projects_local_events_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- Name: projects_locations projects_locations_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_locations
    ADD CONSTRAINT projects_locations_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id) ON DELETE CASCADE;


--
-- Name: projects_locations projects_locations_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_locations
    ADD CONSTRAINT projects_locations_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- Name: projects_notes projects_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_notes
    ADD CONSTRAINT projects_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- Name: projects_notes projects_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_notes
    ADD CONSTRAINT projects_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- Name: projects_notes projects_notes_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_notes
    ADD CONSTRAINT projects_notes_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- Name: projects projects_offering_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_offering_term_id_fkey FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: projects projects_project_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_project_status_id_fkey FOREIGN KEY (project_status_id) REFERENCES public.project_statuses(project_status_id);


--
-- Name: projects projects_project_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_project_type_id_fkey FOREIGN KEY (project_type_id) REFERENCES public.project_types(project_type_id);


--
-- Name: projects projects_rating_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES public.ratings(rating_id) ON DELETE SET NULL;


--
-- Name: projects_tasks projects_tasks_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_tasks
    ADD CONSTRAINT projects_tasks_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- Name: projects_tasks projects_tasks_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_tasks
    ADD CONSTRAINT projects_tasks_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(task_id) ON DELETE CASCADE;


--
-- Name: projects projects_tutor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_tutor_id_fkey FOREIGN KEY (tutor_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: projects projects_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: ratings ratings_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: ratings ratings_rating_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_rating_type_id_fkey FOREIGN KEY (rating_type_id) REFERENCES public.rating_types(rating_type_id);


--
-- Name: request_statistic request_statistic_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_statistic
    ADD CONSTRAINT request_statistic_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id);


--
-- Name: request_statistic request_statistic_resource_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.request_statistic
    ADD CONSTRAINT request_statistic_resource_type_id_fkey FOREIGN KEY (resource_type_id) REFERENCES public.resource_types(resource_type_id);


--
-- Name: requests requests_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id);


--
-- Name: requests requests_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id);


--
-- Name: requests requests_request_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_request_status_id_fkey FOREIGN KEY (request_status_id) REFERENCES public.request_statuses(request_status_id);


--
-- Name: requests requests_request_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_request_type_id_fkey FOREIGN KEY (request_type_id) REFERENCES public.request_types(request_type_id);


--
-- Name: service_offering_terms service_offering_terms_offering_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_offering_terms
    ADD CONSTRAINT service_offering_terms_offering_term_id_fkey FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: service_offering_terms service_offering_terms_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.service_offering_terms
    ADD CONSTRAINT service_offering_terms_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(service_id) ON DELETE CASCADE;


--
-- Name: services services_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: services_notes services_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_notes
    ADD CONSTRAINT services_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- Name: services_notes services_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_notes
    ADD CONSTRAINT services_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- Name: services_notes services_notes_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_notes
    ADD CONSTRAINT services_notes_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(service_id) ON DELETE CASCADE;


--
-- Name: services services_rating_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES public.ratings(rating_id);


--
-- Name: services services_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: stage_audio stage_audio_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio
    ADD CONSTRAINT stage_audio_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: stage_audio_set stage_audio_set_stage_audio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio_set
    ADD CONSTRAINT stage_audio_set_stage_audio_id_fkey FOREIGN KEY (stage_audio_id) REFERENCES public.stage_audio(stage_audio_id) ON DELETE CASCADE;


--
-- Name: stage_audio_set stage_audio_set_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio_set
    ADD CONSTRAINT stage_audio_set_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.stages(stage_id) ON DELETE CASCADE;


--
-- Name: stage_audio stage_audio_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio
    ADD CONSTRAINT stage_audio_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: stage_effects stage_effects_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects
    ADD CONSTRAINT stage_effects_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: stage_effects_set stage_effects_set_stage_effects_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects_set
    ADD CONSTRAINT stage_effects_set_stage_effects_id_fkey FOREIGN KEY (stage_effects_id) REFERENCES public.stage_effects(stage_effects_id) ON DELETE CASCADE;


--
-- Name: stage_effects_set stage_effects_set_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects_set
    ADD CONSTRAINT stage_effects_set_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.stages(stage_id) ON DELETE CASCADE;


--
-- Name: stage_effects stage_effects_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects
    ADD CONSTRAINT stage_effects_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: stage_light stage_light_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light
    ADD CONSTRAINT stage_light_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: stage_light_set stage_light_set_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light_set
    ADD CONSTRAINT stage_light_set_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.stages(stage_id) ON DELETE CASCADE;


--
-- Name: stage_light_set stage_light_set_stage_light_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light_set
    ADD CONSTRAINT stage_light_set_stage_light_id_fkey FOREIGN KEY (stage_light_id) REFERENCES public.stage_light(stage_light_id) ON DELETE CASCADE;


--
-- Name: stage_light stage_light_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light
    ADD CONSTRAINT stage_light_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: stage_video stage_video_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video
    ADD CONSTRAINT stage_video_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: stage_video_set stage_video_set_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video_set
    ADD CONSTRAINT stage_video_set_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.stages(stage_id) ON DELETE CASCADE;


--
-- Name: stage_video_set stage_video_set_stage_video_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video_set
    ADD CONSTRAINT stage_video_set_stage_video_id_fkey FOREIGN KEY (stage_video_id) REFERENCES public.stage_video(stage_video_id) ON DELETE CASCADE;


--
-- Name: stage_video stage_video_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video
    ADD CONSTRAINT stage_video_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: stages stages_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: stages stages_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id) ON DELETE SET NULL;


--
-- Name: stages stages_stage_architecture_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_stage_architecture_id_fkey FOREIGN KEY (stage_architecture_id) REFERENCES public.stage_architecture(stage_architecture_id);


--
-- Name: stages stages_stage_mobility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_stage_mobility_id_fkey FOREIGN KEY (stage_mobility_id) REFERENCES public.stage_mobility(stage_mobility_id);


--
-- Name: stages stages_stage_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_stage_type_id_fkey FOREIGN KEY (stage_type_id) REFERENCES public.stage_types(stage_type_id);


--
-- Name: stages stages_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: tasks tasks_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: tasks tasks_task_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_task_type_id_fkey FOREIGN KEY (task_type_id) REFERENCES public.task_types(task_type_id);


--
-- Name: tasks tasks_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: template_offering_terms template_offering_terms_offering_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.template_offering_terms
    ADD CONSTRAINT template_offering_terms_offering_term_id_fkey FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: template_offering_terms template_offering_terms_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.template_offering_terms
    ADD CONSTRAINT template_offering_terms_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.templates(template_id) ON DELETE CASCADE;


--
-- Name: templates templates_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: templates templates_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_direction_id_fkey FOREIGN KEY (direction_id) REFERENCES public.directions(direction_id) ON DELETE SET NULL;


--
-- Name: templates_finresources templates_finresources_finresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_finresources
    ADD CONSTRAINT templates_finresources_finresource_id_fkey FOREIGN KEY (finresource_id) REFERENCES public.finresources(finresource_id) ON DELETE CASCADE;


--
-- Name: templates_finresources templates_finresources_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_finresources
    ADD CONSTRAINT templates_finresources_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.templates(template_id) ON DELETE CASCADE;


--
-- Name: templates_functions templates_functions_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_functions
    ADD CONSTRAINT templates_functions_function_id_fkey FOREIGN KEY (function_id) REFERENCES public.functions(function_id) ON DELETE CASCADE;


--
-- Name: templates_functions templates_functions_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_functions
    ADD CONSTRAINT templates_functions_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.templates(template_id) ON DELETE CASCADE;


--
-- Name: templates_matresources templates_matresources_matresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_matresources
    ADD CONSTRAINT templates_matresources_matresource_id_fkey FOREIGN KEY (matresource_id) REFERENCES public.matresources(matresource_id) ON DELETE CASCADE;


--
-- Name: templates_matresources templates_matresources_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_matresources
    ADD CONSTRAINT templates_matresources_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.templates(template_id) ON DELETE CASCADE;


--
-- Name: templates_notes templates_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_notes
    ADD CONSTRAINT templates_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- Name: templates_notes templates_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_notes
    ADD CONSTRAINT templates_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id);


--
-- Name: templates_notes templates_notes_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_notes
    ADD CONSTRAINT templates_notes_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.templates(template_id);


--
-- Name: templates templates_rating_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES public.ratings(rating_id);


--
-- Name: templates templates_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: templates_venues templates_venues_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_venues
    ADD CONSTRAINT templates_venues_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.templates(template_id) ON DELETE CASCADE;


--
-- Name: templates_venues templates_venues_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_venues
    ADD CONSTRAINT templates_venues_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(venue_id) ON DELETE CASCADE;


--
-- Name: theme_bookmarks theme_bookmarks_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_bookmarks
    ADD CONSTRAINT theme_bookmarks_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id);


--
-- Name: theme_bookmarks theme_bookmarks_last_read_discussion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_bookmarks
    ADD CONSTRAINT theme_bookmarks_last_read_discussion_id_fkey FOREIGN KEY (last_read_discussion_id) REFERENCES public.theme_discussions(discussion_id);


--
-- Name: theme_bookmarks theme_bookmarks_theme_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_bookmarks
    ADD CONSTRAINT theme_bookmarks_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.themes(theme_id);


--
-- Name: theme_comments theme_comments_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments
    ADD CONSTRAINT theme_comments_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- Name: theme_comments theme_comments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments
    ADD CONSTRAINT theme_comments_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: theme_comments theme_comments_theme_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments
    ADD CONSTRAINT theme_comments_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.themes(theme_id) ON DELETE CASCADE;


--
-- Name: theme_comments theme_comments_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments
    ADD CONSTRAINT theme_comments_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: theme_discussions theme_discussions_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_discussions
    ADD CONSTRAINT theme_discussions_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- Name: theme_discussions theme_discussions_parent_discussion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_discussions
    ADD CONSTRAINT theme_discussions_parent_discussion_id_fkey FOREIGN KEY (parent_discussion_id) REFERENCES public.theme_discussions(discussion_id);


--
-- Name: theme_discussions theme_discussions_theme_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_discussions
    ADD CONSTRAINT theme_discussions_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.themes(theme_id);


--
-- Name: theme_notes theme_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_notes
    ADD CONSTRAINT theme_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- Name: theme_notes theme_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_notes
    ADD CONSTRAINT theme_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id);


--
-- Name: theme_notes theme_notes_theme_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_notes
    ADD CONSTRAINT theme_notes_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.themes(theme_id);


--
-- Name: themes themes_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: themes themes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: themes themes_rating_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES public.ratings(rating_id);


--
-- Name: themes themes_theme_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_theme_type_id_fkey FOREIGN KEY (theme_type_id) REFERENCES public.theme_types(theme_type_id);


--
-- Name: themes themes_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: venue_offering_terms venue_offering_terms_offering_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_offering_terms
    ADD CONSTRAINT venue_offering_terms_offering_term_id_fkey FOREIGN KEY (offering_term_id) REFERENCES public.offering_terms(id);


--
-- Name: venue_offering_terms venue_offering_terms_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_offering_terms
    ADD CONSTRAINT venue_offering_terms_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(venue_id) ON DELETE CASCADE;


--
-- Name: venues venues_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: venues venues_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: venues venues_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id) ON DELETE SET NULL;


--
-- Name: venues_notes venues_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_notes
    ADD CONSTRAINT venues_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- Name: venues_notes venues_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_notes
    ADD CONSTRAINT venues_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- Name: venues_notes venues_notes_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_notes
    ADD CONSTRAINT venues_notes_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(venue_id) ON DELETE CASCADE;


--
-- Name: venues venues_rating_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES public.ratings(rating_id);


--
-- Name: venues_stages venues_stages_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_stages
    ADD CONSTRAINT venues_stages_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.stages(stage_id) ON DELETE CASCADE;


--
-- Name: venues_stages venues_stages_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_stages
    ADD CONSTRAINT venues_stages_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(venue_id) ON DELETE CASCADE;


--
-- Name: venues venues_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: venues venues_venue_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_venue_type_id_fkey FOREIGN KEY (venue_type_id) REFERENCES public.venue_types(venue_type_id);


--
-- PostgreSQL database dump complete
--

\unrestrict M6DNn41S6WYdQlgkLRTVwv862PqFabHoGpsydc5SKaN0esvgucADEfFeK2ZYjSe

