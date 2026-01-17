--
-- PostgreSQL database dump
--

\restrict ooBMadl75pESfvp88GNTibLAXSqQozCPcUT0dk4oAkCOvelcWP5dPomPVvIxZ0M

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

-- Started on 2026-01-18 00:36:31

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
-- TOC entry 6153 (class 1262 OID 16388)
-- Name: creative_center_base; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE creative_center_base WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Russian_Russia.1251';


ALTER DATABASE creative_center_base OWNER TO postgres;

\unrestrict ooBMadl75pESfvp88GNTibLAXSqQozCPcUT0dk4oAkCOvelcWP5dPomPVvIxZ0M
\connect creative_center_base
\restrict ooBMadl75pESfvp88GNTibLAXSqQozCPcUT0dk4oAkCOvelcWP5dPomPVvIxZ0M

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
-- TOC entry 2 (class 3079 OID 16389)
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- TOC entry 6154 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- TOC entry 3 (class 3079 OID 16470)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 6155 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 4 (class 3079 OID 16508)
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- TOC entry 6156 (class 0 OID 0)
-- Dependencies: 4
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- TOC entry 441 (class 1255 OID 16519)
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
-- TOC entry 439 (class 1255 OID 16520)
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
-- TOC entry 407 (class 1255 OID 16521)
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
-- TOC entry 380 (class 1255 OID 18340)
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
-- TOC entry 423 (class 1255 OID 16522)
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
-- TOC entry 416 (class 1255 OID 16523)
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
-- TOC entry 427 (class 1255 OID 16524)
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
-- TOC entry 368 (class 1255 OID 16525)
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
-- TOC entry 377 (class 1255 OID 16526)
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
-- TOC entry 397 (class 1255 OID 16527)
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
-- TOC entry 433 (class 1255 OID 16528)
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
-- TOC entry 425 (class 1255 OID 18335)
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
-- TOC entry 417 (class 1255 OID 18352)
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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 16529)
-- Name: actor_credentials; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actor_credentials (
    actor_id integer NOT NULL,
    password_hash character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.actor_credentials OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16535)
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
-- TOC entry 224 (class 1259 OID 16545)
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
-- TOC entry 6157 (class 0 OID 0)
-- Dependencies: 224
-- Name: actor_current_statuses_actor_current_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.actor_current_statuses_actor_current_status_id_seq OWNED BY public.actor_current_statuses.actor_current_status_id;


--
-- TOC entry 225 (class 1259 OID 16546)
-- Name: actor_statuses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actor_statuses (
    actor_status_id integer NOT NULL,
    status character varying(100) NOT NULL,
    description text
);


ALTER TABLE public.actor_statuses OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16562)
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
    color_frame character varying(20)
);


ALTER TABLE public.actors OWNER TO postgres;

--
-- TOC entry 6158 (class 0 OID 0)
-- Dependencies: 229
-- Name: COLUMN actors.color_frame; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.actors.color_frame IS 'Цвет рамки скруглённого прямоугольника значка Участника';


--
-- TOC entry 238 (class 1259 OID 16613)
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
    CONSTRAINT chk_community_email_2_format CHECK (((email_2 IS NULL) OR ((email_2)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))),
    CONSTRAINT chk_community_email_format CHECK (((email IS NULL) OR ((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)))
);


ALTER TABLE public.communities OWNER TO postgres;

--
-- TOC entry 281 (class 1259 OID 16828)
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
    CONSTRAINT chk_org_email_2_format CHECK (((email_2 IS NULL) OR ((email_2)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text))),
    CONSTRAINT chk_org_email_format CHECK (((email IS NULL) OR ((email)::text ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text)))
);


ALTER TABLE public.organizations OWNER TO postgres;

--
-- TOC entry 283 (class 1259 OID 16842)
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
-- TOC entry 354 (class 1259 OID 18346)
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
-- TOC entry 227 (class 1259 OID 16554)
-- Name: actor_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actor_types (
    actor_type_id integer NOT NULL,
    type character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.actor_types OWNER TO postgres;

--
-- TOC entry 352 (class 1259 OID 18330)
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
-- TOC entry 353 (class 1259 OID 18341)
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
-- TOC entry 226 (class 1259 OID 16553)
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
-- TOC entry 6159 (class 0 OID 0)
-- Dependencies: 226
-- Name: actor_statuses_actor_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.actor_statuses_actor_status_id_seq OWNED BY public.actor_statuses.actor_status_id;


--
-- TOC entry 228 (class 1259 OID 16561)
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
-- TOC entry 6160 (class 0 OID 0)
-- Dependencies: 228
-- Name: actor_types_actor_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.actor_types_actor_type_id_seq OWNED BY public.actor_types.actor_type_id;


--
-- TOC entry 230 (class 1259 OID 16573)
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
-- TOC entry 6161 (class 0 OID 0)
-- Dependencies: 230
-- Name: actors_actor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.actors_actor_id_seq OWNED BY public.actors.actor_id;


--
-- TOC entry 231 (class 1259 OID 16574)
-- Name: actors_directions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_directions (
    actor_id integer NOT NULL,
    direction_id integer NOT NULL
);


ALTER TABLE public.actors_directions OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 16579)
-- Name: actors_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_events (
    actor_id integer NOT NULL,
    event_id integer NOT NULL
);


ALTER TABLE public.actors_events OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 16584)
-- Name: actors_locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_locations (
    actor_id integer NOT NULL,
    location_id integer NOT NULL
);


ALTER TABLE public.actors_locations OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 16589)
-- Name: actors_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_messages (
    message_id integer NOT NULL,
    actor_id integer NOT NULL
);


ALTER TABLE public.actors_messages OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16594)
-- Name: actors_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_notes (
    note_id integer NOT NULL,
    actor_id integer NOT NULL,
    author_id integer
);


ALTER TABLE public.actors_notes OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 16599)
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
-- TOC entry 237 (class 1259 OID 16608)
-- Name: actors_tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actors_tasks (
    task_id integer NOT NULL,
    actor_id integer NOT NULL
);


ALTER TABLE public.actors_tasks OWNER TO postgres;

--
-- TOC entry 362 (class 1259 OID 18415)
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
-- TOC entry 361 (class 1259 OID 18414)
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
-- TOC entry 6162 (class 0 OID 0)
-- Dependencies: 361
-- Name: bookmarks_bookmark_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.bookmarks_bookmark_id_seq OWNED BY public.bookmarks.bookmark_id;


--
-- TOC entry 239 (class 1259 OID 16626)
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
-- TOC entry 6163 (class 0 OID 0)
-- Dependencies: 239
-- Name: communities_community_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.communities_community_id_seq OWNED BY public.communities.community_id;


--
-- TOC entry 351 (class 1259 OID 18292)
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
-- TOC entry 240 (class 1259 OID 16627)
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
-- TOC entry 241 (class 1259 OID 16633)
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
-- TOC entry 6164 (class 0 OID 0)
-- Dependencies: 241
-- Name: directions_direction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.directions_direction_id_seq OWNED BY public.directions.direction_id;


--
-- TOC entry 242 (class 1259 OID 16634)
-- Name: event_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_types (
    event_type_id integer NOT NULL,
    type character varying(50) NOT NULL
);


ALTER TABLE public.event_types OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 16639)
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
-- TOC entry 6165 (class 0 OID 0)
-- Dependencies: 243
-- Name: event_types_event_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.event_types_event_type_id_seq OWNED BY public.event_types.event_type_id;


--
-- TOC entry 244 (class 1259 OID 16640)
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
    CONSTRAINT chk_event_times CHECK ((start_time <= end_time))
);


ALTER TABLE public.events OWNER TO postgres;

--
-- TOC entry 245 (class 1259 OID 16653)
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
-- TOC entry 6166 (class 0 OID 0)
-- Dependencies: 245
-- Name: events_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.events_event_id_seq OWNED BY public.events.event_id;


--
-- TOC entry 246 (class 1259 OID 16654)
-- Name: events_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.events_notes (
    note_id integer NOT NULL,
    event_id integer NOT NULL
);


ALTER TABLE public.events_notes OWNER TO postgres;

--
-- TOC entry 360 (class 1259 OID 18395)
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
-- TOC entry 6167 (class 0 OID 0)
-- Dependencies: 360
-- Name: TABLE favorites; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.favorites IS 'Универсальная таблица для избранного (проекты, идеи, участники и т.д.)';


--
-- TOC entry 359 (class 1259 OID 18394)
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
-- TOC entry 6168 (class 0 OID 0)
-- Dependencies: 359
-- Name: favorites_favorite_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.favorites_favorite_id_seq OWNED BY public.favorites.favorite_id;


--
-- TOC entry 247 (class 1259 OID 16659)
-- Name: finresource_owners; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.finresource_owners (
    finresource_id integer NOT NULL,
    actor_id integer NOT NULL
);


ALTER TABLE public.finresource_owners OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 16664)
-- Name: finresource_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.finresource_types (
    finresource_type_id integer NOT NULL,
    type character varying(100) NOT NULL
);


ALTER TABLE public.finresource_types OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 16669)
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
-- TOC entry 6169 (class 0 OID 0)
-- Dependencies: 249
-- Name: finresource_types_finresource_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.finresource_types_finresource_type_id_seq OWNED BY public.finresource_types.finresource_type_id;


--
-- TOC entry 250 (class 1259 OID 16670)
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
    updated_by integer
);


ALTER TABLE public.finresources OWNER TO postgres;

--
-- TOC entry 251 (class 1259 OID 16681)
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
-- TOC entry 6170 (class 0 OID 0)
-- Dependencies: 251
-- Name: finresources_finresource_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.finresources_finresource_id_seq OWNED BY public.finresources.finresource_id;


--
-- TOC entry 252 (class 1259 OID 16682)
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
-- TOC entry 253 (class 1259 OID 16689)
-- Name: functions_directions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.functions_directions (
    function_id integer NOT NULL,
    direction_id integer NOT NULL
);


ALTER TABLE public.functions_directions OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 16694)
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
-- TOC entry 6171 (class 0 OID 0)
-- Dependencies: 254
-- Name: functions_function_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.functions_function_id_seq OWNED BY public.functions.function_id;


--
-- TOC entry 255 (class 1259 OID 16695)
-- Name: group_tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.group_tasks (
    task_id integer NOT NULL,
    project_group_id integer NOT NULL
);


ALTER TABLE public.group_tasks OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 16700)
-- Name: idea_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.idea_categories (
    idea_category_id integer NOT NULL,
    category character varying(50) NOT NULL
);


ALTER TABLE public.idea_categories OWNER TO postgres;

--
-- TOC entry 257 (class 1259 OID 16705)
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
-- TOC entry 6172 (class 0 OID 0)
-- Dependencies: 257
-- Name: idea_categories_idea_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.idea_categories_idea_category_id_seq OWNED BY public.idea_categories.idea_category_id;


--
-- TOC entry 258 (class 1259 OID 16706)
-- Name: idea_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.idea_types (
    idea_type_id integer NOT NULL,
    type character varying(50) NOT NULL
);


ALTER TABLE public.idea_types OWNER TO postgres;

--
-- TOC entry 259 (class 1259 OID 16711)
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
-- TOC entry 6173 (class 0 OID 0)
-- Dependencies: 259
-- Name: idea_types_idea_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.idea_types_idea_type_id_seq OWNED BY public.idea_types.idea_type_id;


--
-- TOC entry 260 (class 1259 OID 16712)
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
    updated_by integer
);


ALTER TABLE public.ideas OWNER TO postgres;

--
-- TOC entry 261 (class 1259 OID 16723)
-- Name: ideas_directions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ideas_directions (
    idea_id integer NOT NULL,
    direction_id integer NOT NULL
);


ALTER TABLE public.ideas_directions OWNER TO postgres;

--
-- TOC entry 262 (class 1259 OID 16728)
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
-- TOC entry 6174 (class 0 OID 0)
-- Dependencies: 262
-- Name: ideas_idea_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ideas_idea_id_seq OWNED BY public.ideas.idea_id;


--
-- TOC entry 263 (class 1259 OID 16729)
-- Name: ideas_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ideas_notes (
    note_id integer NOT NULL,
    idea_id integer NOT NULL
);


ALTER TABLE public.ideas_notes OWNER TO postgres;

--
-- TOC entry 264 (class 1259 OID 16734)
-- Name: ideas_projects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ideas_projects (
    idea_id integer NOT NULL,
    project_id integer NOT NULL
);


ALTER TABLE public.ideas_projects OWNER TO postgres;

--
-- TOC entry 265 (class 1259 OID 16739)
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
-- TOC entry 266 (class 1259 OID 16752)
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
-- TOC entry 6175 (class 0 OID 0)
-- Dependencies: 266
-- Name: local_events_local_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.local_events_local_event_id_seq OWNED BY public.local_events.local_event_id;


--
-- TOC entry 267 (class 1259 OID 16753)
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
    attachment character varying(255)
);


ALTER TABLE public.locations OWNER TO postgres;

--
-- TOC entry 268 (class 1259 OID 16760)
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
-- TOC entry 6176 (class 0 OID 0)
-- Dependencies: 268
-- Name: locations_location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.locations_location_id_seq OWNED BY public.locations.location_id;


--
-- TOC entry 269 (class 1259 OID 16761)
-- Name: matresource_owners; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.matresource_owners (
    matresource_id integer NOT NULL,
    actor_id integer NOT NULL
);


ALTER TABLE public.matresource_owners OWNER TO postgres;

--
-- TOC entry 270 (class 1259 OID 16766)
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
-- TOC entry 271 (class 1259 OID 16770)
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
-- TOC entry 6177 (class 0 OID 0)
-- Dependencies: 271
-- Name: matresource_types_matresource_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.matresource_types_matresource_type_id_seq OWNED BY public.matresource_types.matresource_type_id;


--
-- TOC entry 272 (class 1259 OID 16771)
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
    updated_by integer
);


ALTER TABLE public.matresources OWNER TO postgres;

--
-- TOC entry 273 (class 1259 OID 16782)
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
-- TOC entry 6178 (class 0 OID 0)
-- Dependencies: 273
-- Name: matresources_matresource_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.matresources_matresource_id_seq OWNED BY public.matresources.matresource_id;


--
-- TOC entry 274 (class 1259 OID 16783)
-- Name: matresources_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.matresources_notes (
    note_id integer NOT NULL,
    matresource_id integer NOT NULL
);


ALTER TABLE public.matresources_notes OWNER TO postgres;

--
-- TOC entry 275 (class 1259 OID 16788)
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
-- TOC entry 276 (class 1259 OID 16800)
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
-- TOC entry 6179 (class 0 OID 0)
-- Dependencies: 276
-- Name: messages_message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.messages_message_id_seq OWNED BY public.messages.message_id;


--
-- TOC entry 277 (class 1259 OID 16801)
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
-- TOC entry 278 (class 1259 OID 16813)
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
-- TOC entry 6180 (class 0 OID 0)
-- Dependencies: 278
-- Name: notes_note_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notes_note_id_seq OWNED BY public.notes.note_id;


--
-- TOC entry 279 (class 1259 OID 16814)
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
-- TOC entry 280 (class 1259 OID 16827)
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
-- TOC entry 6181 (class 0 OID 0)
-- Dependencies: 280
-- Name: notifications_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notifications_notification_id_seq OWNED BY public.notifications.notification_id;


--
-- TOC entry 282 (class 1259 OID 16841)
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
-- TOC entry 6182 (class 0 OID 0)
-- Dependencies: 282
-- Name: organizations_organization_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.organizations_organization_id_seq OWNED BY public.organizations.organization_id;


--
-- TOC entry 284 (class 1259 OID 16858)
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
-- TOC entry 6183 (class 0 OID 0)
-- Dependencies: 284
-- Name: persons_person_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.persons_person_id_seq OWNED BY public.persons.person_id;


--
-- TOC entry 285 (class 1259 OID 16859)
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
-- TOC entry 6184 (class 0 OID 0)
-- Dependencies: 285
-- Name: TABLE project_actor_roles; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.project_actor_roles IS 'Хранит роли акторов в конкретных проектах (руководитель, администратор, участник, куратор)';


--
-- TOC entry 6185 (class 0 OID 0)
-- Dependencies: 285
-- Name: COLUMN project_actor_roles.role_type; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.project_actor_roles.role_type IS 'Тип роли: leader-руководитель, admin-администратор, member-участник, curator-проектный куратор';


--
-- TOC entry 6186 (class 0 OID 0)
-- Dependencies: 285
-- Name: COLUMN project_actor_roles.assigned_at; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.project_actor_roles.assigned_at IS 'Дата и время назначения роли';


--
-- TOC entry 6187 (class 0 OID 0)
-- Dependencies: 285
-- Name: COLUMN project_actor_roles.assigned_by; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.project_actor_roles.assigned_by IS 'Кто назначил эту роль (ссылка на actors)';


--
-- TOC entry 286 (class 1259 OID 16870)
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
-- TOC entry 6188 (class 0 OID 0)
-- Dependencies: 286
-- Name: project_actor_roles_project_actor_role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.project_actor_roles_project_actor_role_id_seq OWNED BY public.project_actor_roles.project_actor_role_id;


--
-- TOC entry 287 (class 1259 OID 16871)
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
-- TOC entry 288 (class 1259 OID 16881)
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
-- TOC entry 6189 (class 0 OID 0)
-- Dependencies: 288
-- Name: project_groups_project_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.project_groups_project_group_id_seq OWNED BY public.project_groups.project_group_id;


--
-- TOC entry 289 (class 1259 OID 16882)
-- Name: project_statuses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.project_statuses (
    project_status_id integer NOT NULL,
    status character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.project_statuses OWNER TO postgres;

--
-- TOC entry 290 (class 1259 OID 16889)
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
-- TOC entry 6190 (class 0 OID 0)
-- Dependencies: 290
-- Name: project_statuses_project_status_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.project_statuses_project_status_id_seq OWNED BY public.project_statuses.project_status_id;


--
-- TOC entry 291 (class 1259 OID 16890)
-- Name: project_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.project_types (
    project_type_id integer NOT NULL,
    type character varying(50) NOT NULL
);


ALTER TABLE public.project_types OWNER TO postgres;

--
-- TOC entry 292 (class 1259 OID 16895)
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
-- TOC entry 6191 (class 0 OID 0)
-- Dependencies: 292
-- Name: project_types_project_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.project_types_project_type_id_seq OWNED BY public.project_types.project_type_id;


--
-- TOC entry 293 (class 1259 OID 16896)
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
    CONSTRAINT chk_project_dates CHECK ((start_date <= end_date))
);


ALTER TABLE public.projects OWNER TO postgres;

--
-- TOC entry 294 (class 1259 OID 16908)
-- Name: projects_directions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects_directions (
    project_id integer NOT NULL,
    direction_id integer NOT NULL
);


ALTER TABLE public.projects_directions OWNER TO postgres;

--
-- TOC entry 295 (class 1259 OID 16913)
-- Name: projects_functions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects_functions (
    project_id integer NOT NULL,
    function_id integer NOT NULL
);


ALTER TABLE public.projects_functions OWNER TO postgres;

--
-- TOC entry 296 (class 1259 OID 16918)
-- Name: projects_local_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects_local_events (
    project_id integer NOT NULL,
    local_event_id integer NOT NULL
);


ALTER TABLE public.projects_local_events OWNER TO postgres;

--
-- TOC entry 297 (class 1259 OID 16923)
-- Name: projects_locations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects_locations (
    project_id integer NOT NULL,
    location_id integer NOT NULL
);


ALTER TABLE public.projects_locations OWNER TO postgres;

--
-- TOC entry 298 (class 1259 OID 16928)
-- Name: projects_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects_notes (
    note_id integer NOT NULL,
    project_id integer NOT NULL
);


ALTER TABLE public.projects_notes OWNER TO postgres;

--
-- TOC entry 299 (class 1259 OID 16933)
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
-- TOC entry 6192 (class 0 OID 0)
-- Dependencies: 299
-- Name: projects_project_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.projects_project_id_seq OWNED BY public.projects.project_id;


--
-- TOC entry 300 (class 1259 OID 16934)
-- Name: projects_tasks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects_tasks (
    task_id integer NOT NULL,
    project_id integer NOT NULL
);


ALTER TABLE public.projects_tasks OWNER TO postgres;

--
-- TOC entry 356 (class 1259 OID 18357)
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
-- TOC entry 355 (class 1259 OID 18356)
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
-- TOC entry 6193 (class 0 OID 0)
-- Dependencies: 355
-- Name: rating_types_rating_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rating_types_rating_type_id_seq OWNED BY public.rating_types.rating_type_id;


--
-- TOC entry 358 (class 1259 OID 18372)
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
-- TOC entry 6194 (class 0 OID 0)
-- Dependencies: 358
-- Name: TABLE ratings; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.ratings IS 'Хранит основные записи оценок, привязка к сущностям через rating_id в их таблицах';


--
-- TOC entry 357 (class 1259 OID 18371)
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
-- TOC entry 6195 (class 0 OID 0)
-- Dependencies: 357
-- Name: ratings_rating_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ratings_rating_id_seq OWNED BY public.ratings.rating_id;


--
-- TOC entry 301 (class 1259 OID 16939)
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
    updated_by integer
);


ALTER TABLE public.services OWNER TO postgres;

--
-- TOC entry 302 (class 1259 OID 16950)
-- Name: services_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.services_notes (
    note_id integer NOT NULL,
    service_id integer NOT NULL
);


ALTER TABLE public.services_notes OWNER TO postgres;

--
-- TOC entry 303 (class 1259 OID 16955)
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
-- TOC entry 6196 (class 0 OID 0)
-- Dependencies: 303
-- Name: services_service_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.services_service_id_seq OWNED BY public.services.service_id;


--
-- TOC entry 304 (class 1259 OID 16956)
-- Name: stage_architecture; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_architecture (
    stage_architecture_id integer NOT NULL,
    architecture character varying(100) NOT NULL
);


ALTER TABLE public.stage_architecture OWNER TO postgres;

--
-- TOC entry 305 (class 1259 OID 16961)
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
-- TOC entry 6197 (class 0 OID 0)
-- Dependencies: 305
-- Name: stage_architecture_stage_architecture_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_architecture_stage_architecture_id_seq OWNED BY public.stage_architecture.stage_architecture_id;


--
-- TOC entry 306 (class 1259 OID 16962)
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
-- TOC entry 307 (class 1259 OID 16973)
-- Name: stage_audio_set; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_audio_set (
    stage_id integer NOT NULL,
    stage_audio_id integer NOT NULL
);


ALTER TABLE public.stage_audio_set OWNER TO postgres;

--
-- TOC entry 308 (class 1259 OID 16978)
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
-- TOC entry 6198 (class 0 OID 0)
-- Dependencies: 308
-- Name: stage_audio_stage_audio_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_audio_stage_audio_id_seq OWNED BY public.stage_audio.stage_audio_id;


--
-- TOC entry 309 (class 1259 OID 16979)
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
-- TOC entry 310 (class 1259 OID 16990)
-- Name: stage_effects_set; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_effects_set (
    stage_id integer NOT NULL,
    stage_effects_id integer NOT NULL
);


ALTER TABLE public.stage_effects_set OWNER TO postgres;

--
-- TOC entry 311 (class 1259 OID 16995)
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
-- TOC entry 6199 (class 0 OID 0)
-- Dependencies: 311
-- Name: stage_effects_stage_effects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_effects_stage_effects_id_seq OWNED BY public.stage_effects.stage_effects_id;


--
-- TOC entry 312 (class 1259 OID 16996)
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
-- TOC entry 313 (class 1259 OID 17007)
-- Name: stage_light_set; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_light_set (
    stage_id integer NOT NULL,
    stage_light_id integer NOT NULL
);


ALTER TABLE public.stage_light_set OWNER TO postgres;

--
-- TOC entry 314 (class 1259 OID 17012)
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
-- TOC entry 6200 (class 0 OID 0)
-- Dependencies: 314
-- Name: stage_light_stage_light_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_light_stage_light_id_seq OWNED BY public.stage_light.stage_light_id;


--
-- TOC entry 315 (class 1259 OID 17013)
-- Name: stage_mobility; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_mobility (
    stage_mobility_id integer NOT NULL,
    mobility character varying(100) NOT NULL
);


ALTER TABLE public.stage_mobility OWNER TO postgres;

--
-- TOC entry 316 (class 1259 OID 17018)
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
-- TOC entry 6201 (class 0 OID 0)
-- Dependencies: 316
-- Name: stage_mobility_stage_mobility_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_mobility_stage_mobility_id_seq OWNED BY public.stage_mobility.stage_mobility_id;


--
-- TOC entry 317 (class 1259 OID 17019)
-- Name: stage_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_types (
    stage_type_id integer NOT NULL,
    type character varying(100) NOT NULL
);


ALTER TABLE public.stage_types OWNER TO postgres;

--
-- TOC entry 318 (class 1259 OID 17024)
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
-- TOC entry 6202 (class 0 OID 0)
-- Dependencies: 318
-- Name: stage_types_stage_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_types_stage_type_id_seq OWNED BY public.stage_types.stage_type_id;


--
-- TOC entry 319 (class 1259 OID 17025)
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
-- TOC entry 320 (class 1259 OID 17036)
-- Name: stage_video_set; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stage_video_set (
    stage_id integer NOT NULL,
    stage_video_id integer NOT NULL
);


ALTER TABLE public.stage_video_set OWNER TO postgres;

--
-- TOC entry 321 (class 1259 OID 17041)
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
-- TOC entry 6203 (class 0 OID 0)
-- Dependencies: 321
-- Name: stage_video_stage_video_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stage_video_stage_video_id_seq OWNED BY public.stage_video.stage_video_id;


--
-- TOC entry 322 (class 1259 OID 17042)
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
    CONSTRAINT stages_capacity_check CHECK ((capacity > 0)),
    CONSTRAINT stages_depth_check CHECK ((depth > (0)::numeric)),
    CONSTRAINT stages_height_check CHECK ((height >= (0)::numeric)),
    CONSTRAINT stages_width_check CHECK ((width > (0)::numeric))
);


ALTER TABLE public.stages OWNER TO postgres;

--
-- TOC entry 323 (class 1259 OID 17057)
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
-- TOC entry 6204 (class 0 OID 0)
-- Dependencies: 323
-- Name: stages_stage_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stages_stage_id_seq OWNED BY public.stages.stage_id;


--
-- TOC entry 324 (class 1259 OID 17058)
-- Name: task_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.task_types (
    task_type_id integer NOT NULL,
    type character varying(50) NOT NULL
);


ALTER TABLE public.task_types OWNER TO postgres;

--
-- TOC entry 325 (class 1259 OID 17063)
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
-- TOC entry 6205 (class 0 OID 0)
-- Dependencies: 325
-- Name: task_types_task_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.task_types_task_type_id_seq OWNED BY public.task_types.task_type_id;


--
-- TOC entry 326 (class 1259 OID 17064)
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
-- TOC entry 327 (class 1259 OID 17076)
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
-- TOC entry 6206 (class 0 OID 0)
-- Dependencies: 327
-- Name: tasks_task_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tasks_task_id_seq OWNED BY public.tasks.task_id;


--
-- TOC entry 328 (class 1259 OID 17077)
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
    updated_by integer
);


ALTER TABLE public.templates OWNER TO postgres;

--
-- TOC entry 329 (class 1259 OID 17088)
-- Name: templates_finresources; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.templates_finresources (
    template_id integer NOT NULL,
    finresource_id integer NOT NULL
);


ALTER TABLE public.templates_finresources OWNER TO postgres;

--
-- TOC entry 330 (class 1259 OID 17093)
-- Name: templates_functions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.templates_functions (
    template_id integer NOT NULL,
    function_id integer NOT NULL
);


ALTER TABLE public.templates_functions OWNER TO postgres;

--
-- TOC entry 331 (class 1259 OID 17098)
-- Name: templates_matresources; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.templates_matresources (
    template_id integer NOT NULL,
    matresource_id integer NOT NULL
);


ALTER TABLE public.templates_matresources OWNER TO postgres;

--
-- TOC entry 332 (class 1259 OID 17103)
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
-- TOC entry 6207 (class 0 OID 0)
-- Dependencies: 332
-- Name: templates_template_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.templates_template_id_seq OWNED BY public.templates.template_id;


--
-- TOC entry 333 (class 1259 OID 17104)
-- Name: templates_venues; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.templates_venues (
    template_id integer NOT NULL,
    venue_id integer NOT NULL
);


ALTER TABLE public.templates_venues OWNER TO postgres;

--
-- TOC entry 334 (class 1259 OID 17109)
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
-- TOC entry 335 (class 1259 OID 17122)
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
-- TOC entry 6208 (class 0 OID 0)
-- Dependencies: 335
-- Name: theme_comments_theme_comment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.theme_comments_theme_comment_id_seq OWNED BY public.theme_comments.theme_comment_id;


--
-- TOC entry 336 (class 1259 OID 17123)
-- Name: theme_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.theme_types (
    theme_type_id integer NOT NULL,
    type character varying(50) NOT NULL
);


ALTER TABLE public.theme_types OWNER TO postgres;

--
-- TOC entry 337 (class 1259 OID 17128)
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
-- TOC entry 6209 (class 0 OID 0)
-- Dependencies: 337
-- Name: theme_types_theme_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.theme_types_theme_type_id_seq OWNED BY public.theme_types.theme_type_id;


--
-- TOC entry 338 (class 1259 OID 17129)
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
    updated_by integer
);


ALTER TABLE public.themes OWNER TO postgres;

--
-- TOC entry 339 (class 1259 OID 17140)
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
-- TOC entry 6210 (class 0 OID 0)
-- Dependencies: 339
-- Name: themes_theme_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.themes_theme_id_seq OWNED BY public.themes.theme_id;


--
-- TOC entry 340 (class 1259 OID 17141)
-- Name: venue_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.venue_types (
    venue_type_id integer NOT NULL,
    type character varying(100) NOT NULL
);


ALTER TABLE public.venue_types OWNER TO postgres;

--
-- TOC entry 341 (class 1259 OID 17146)
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
-- TOC entry 6211 (class 0 OID 0)
-- Dependencies: 341
-- Name: venue_types_venue_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.venue_types_venue_type_id_seq OWNED BY public.venue_types.venue_type_id;


--
-- TOC entry 342 (class 1259 OID 17147)
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
    updated_by integer
);


ALTER TABLE public.venues OWNER TO postgres;

--
-- TOC entry 363 (class 1259 OID 18447)
-- Name: venues_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.venues_notes (
    note_id integer NOT NULL,
    venue_id integer NOT NULL,
    author_id integer
);


ALTER TABLE public.venues_notes OWNER TO postgres;

--
-- TOC entry 343 (class 1259 OID 17158)
-- Name: venues_stages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.venues_stages (
    venue_id integer NOT NULL,
    stage_id integer NOT NULL
);


ALTER TABLE public.venues_stages OWNER TO postgres;

--
-- TOC entry 344 (class 1259 OID 17163)
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
-- TOC entry 6212 (class 0 OID 0)
-- Dependencies: 344
-- Name: venues_venue_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.venues_venue_id_seq OWNED BY public.venues.venue_id;


--
-- TOC entry 345 (class 1259 OID 17164)
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
-- TOC entry 346 (class 1259 OID 17169)
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
-- TOC entry 347 (class 1259 OID 17173)
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
-- TOC entry 348 (class 1259 OID 17177)
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
-- TOC entry 349 (class 1259 OID 17182)
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
-- TOC entry 350 (class 1259 OID 17187)
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
-- TOC entry 5282 (class 2604 OID 17192)
-- Name: actor_current_statuses actor_current_status_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_current_statuses ALTER COLUMN actor_current_status_id SET DEFAULT nextval('public.actor_current_statuses_actor_current_status_id_seq'::regclass);


--
-- TOC entry 5285 (class 2604 OID 17193)
-- Name: actor_statuses actor_status_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_statuses ALTER COLUMN actor_status_id SET DEFAULT nextval('public.actor_statuses_actor_status_id_seq'::regclass);


--
-- TOC entry 5286 (class 2604 OID 17194)
-- Name: actor_types actor_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_types ALTER COLUMN actor_type_id SET DEFAULT nextval('public.actor_types_actor_type_id_seq'::regclass);


--
-- TOC entry 5287 (class 2604 OID 17195)
-- Name: actors actor_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors ALTER COLUMN actor_id SET DEFAULT nextval('public.actors_actor_id_seq'::regclass);


--
-- TOC entry 5389 (class 2604 OID 18418)
-- Name: bookmarks bookmark_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookmarks ALTER COLUMN bookmark_id SET DEFAULT nextval('public.bookmarks_bookmark_id_seq'::regclass);


--
-- TOC entry 5292 (class 2604 OID 17196)
-- Name: communities community_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities ALTER COLUMN community_id SET DEFAULT nextval('public.communities_community_id_seq'::regclass);


--
-- TOC entry 5295 (class 2604 OID 17197)
-- Name: directions direction_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.directions ALTER COLUMN direction_id SET DEFAULT nextval('public.directions_direction_id_seq'::regclass);


--
-- TOC entry 5296 (class 2604 OID 17198)
-- Name: event_types event_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_types ALTER COLUMN event_type_id SET DEFAULT nextval('public.event_types_event_type_id_seq'::regclass);


--
-- TOC entry 5297 (class 2604 OID 17199)
-- Name: events event_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events ALTER COLUMN event_id SET DEFAULT nextval('public.events_event_id_seq'::regclass);


--
-- TOC entry 5387 (class 2604 OID 18398)
-- Name: favorites favorite_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites ALTER COLUMN favorite_id SET DEFAULT nextval('public.favorites_favorite_id_seq'::regclass);


--
-- TOC entry 5300 (class 2604 OID 17200)
-- Name: finresource_types finresource_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_types ALTER COLUMN finresource_type_id SET DEFAULT nextval('public.finresource_types_finresource_type_id_seq'::regclass);


--
-- TOC entry 5301 (class 2604 OID 17201)
-- Name: finresources finresource_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources ALTER COLUMN finresource_id SET DEFAULT nextval('public.finresources_finresource_id_seq'::regclass);


--
-- TOC entry 5304 (class 2604 OID 17202)
-- Name: functions function_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.functions ALTER COLUMN function_id SET DEFAULT nextval('public.functions_function_id_seq'::regclass);


--
-- TOC entry 5305 (class 2604 OID 17203)
-- Name: idea_categories idea_category_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_categories ALTER COLUMN idea_category_id SET DEFAULT nextval('public.idea_categories_idea_category_id_seq'::regclass);


--
-- TOC entry 5306 (class 2604 OID 17204)
-- Name: idea_types idea_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_types ALTER COLUMN idea_type_id SET DEFAULT nextval('public.idea_types_idea_type_id_seq'::regclass);


--
-- TOC entry 5307 (class 2604 OID 17205)
-- Name: ideas idea_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas ALTER COLUMN idea_id SET DEFAULT nextval('public.ideas_idea_id_seq'::regclass);


--
-- TOC entry 5310 (class 2604 OID 17206)
-- Name: local_events local_event_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_events ALTER COLUMN local_event_id SET DEFAULT nextval('public.local_events_local_event_id_seq'::regclass);


--
-- TOC entry 5313 (class 2604 OID 17207)
-- Name: locations location_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations ALTER COLUMN location_id SET DEFAULT nextval('public.locations_location_id_seq'::regclass);


--
-- TOC entry 5314 (class 2604 OID 17208)
-- Name: matresource_types matresource_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_types ALTER COLUMN matresource_type_id SET DEFAULT nextval('public.matresource_types_matresource_type_id_seq'::regclass);


--
-- TOC entry 5315 (class 2604 OID 17209)
-- Name: matresources matresource_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources ALTER COLUMN matresource_id SET DEFAULT nextval('public.matresources_matresource_id_seq'::regclass);


--
-- TOC entry 5318 (class 2604 OID 17210)
-- Name: messages message_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages ALTER COLUMN message_id SET DEFAULT nextval('public.messages_message_id_seq'::regclass);


--
-- TOC entry 5321 (class 2604 OID 17211)
-- Name: notes note_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notes ALTER COLUMN note_id SET DEFAULT nextval('public.notes_note_id_seq'::regclass);


--
-- TOC entry 5324 (class 2604 OID 17212)
-- Name: notifications notification_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications ALTER COLUMN notification_id SET DEFAULT nextval('public.notifications_notification_id_seq'::regclass);


--
-- TOC entry 5328 (class 2604 OID 17213)
-- Name: organizations organization_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations ALTER COLUMN organization_id SET DEFAULT nextval('public.organizations_organization_id_seq'::regclass);


--
-- TOC entry 5331 (class 2604 OID 17214)
-- Name: persons person_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons ALTER COLUMN person_id SET DEFAULT nextval('public.persons_person_id_seq'::regclass);


--
-- TOC entry 5334 (class 2604 OID 17215)
-- Name: project_actor_roles project_actor_role_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_actor_roles ALTER COLUMN project_actor_role_id SET DEFAULT nextval('public.project_actor_roles_project_actor_role_id_seq'::regclass);


--
-- TOC entry 5336 (class 2604 OID 17216)
-- Name: project_groups project_group_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_groups ALTER COLUMN project_group_id SET DEFAULT nextval('public.project_groups_project_group_id_seq'::regclass);


--
-- TOC entry 5339 (class 2604 OID 17217)
-- Name: project_statuses project_status_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_statuses ALTER COLUMN project_status_id SET DEFAULT nextval('public.project_statuses_project_status_id_seq'::regclass);


--
-- TOC entry 5340 (class 2604 OID 17218)
-- Name: project_types project_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_types ALTER COLUMN project_type_id SET DEFAULT nextval('public.project_types_project_type_id_seq'::regclass);


--
-- TOC entry 5341 (class 2604 OID 17219)
-- Name: projects project_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects ALTER COLUMN project_id SET DEFAULT nextval('public.projects_project_id_seq'::regclass);


--
-- TOC entry 5383 (class 2604 OID 18360)
-- Name: rating_types rating_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rating_types ALTER COLUMN rating_type_id SET DEFAULT nextval('public.rating_types_rating_type_id_seq'::regclass);


--
-- TOC entry 5385 (class 2604 OID 18375)
-- Name: ratings rating_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings ALTER COLUMN rating_id SET DEFAULT nextval('public.ratings_rating_id_seq'::regclass);


--
-- TOC entry 5344 (class 2604 OID 17220)
-- Name: services service_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services ALTER COLUMN service_id SET DEFAULT nextval('public.services_service_id_seq'::regclass);


--
-- TOC entry 5347 (class 2604 OID 17221)
-- Name: stage_architecture stage_architecture_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_architecture ALTER COLUMN stage_architecture_id SET DEFAULT nextval('public.stage_architecture_stage_architecture_id_seq'::regclass);


--
-- TOC entry 5348 (class 2604 OID 17222)
-- Name: stage_audio stage_audio_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio ALTER COLUMN stage_audio_id SET DEFAULT nextval('public.stage_audio_stage_audio_id_seq'::regclass);


--
-- TOC entry 5351 (class 2604 OID 17223)
-- Name: stage_effects stage_effects_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects ALTER COLUMN stage_effects_id SET DEFAULT nextval('public.stage_effects_stage_effects_id_seq'::regclass);


--
-- TOC entry 5354 (class 2604 OID 17224)
-- Name: stage_light stage_light_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light ALTER COLUMN stage_light_id SET DEFAULT nextval('public.stage_light_stage_light_id_seq'::regclass);


--
-- TOC entry 5357 (class 2604 OID 17225)
-- Name: stage_mobility stage_mobility_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_mobility ALTER COLUMN stage_mobility_id SET DEFAULT nextval('public.stage_mobility_stage_mobility_id_seq'::regclass);


--
-- TOC entry 5358 (class 2604 OID 17226)
-- Name: stage_types stage_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_types ALTER COLUMN stage_type_id SET DEFAULT nextval('public.stage_types_stage_type_id_seq'::regclass);


--
-- TOC entry 5359 (class 2604 OID 17227)
-- Name: stage_video stage_video_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video ALTER COLUMN stage_video_id SET DEFAULT nextval('public.stage_video_stage_video_id_seq'::regclass);


--
-- TOC entry 5362 (class 2604 OID 17228)
-- Name: stages stage_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages ALTER COLUMN stage_id SET DEFAULT nextval('public.stages_stage_id_seq'::regclass);


--
-- TOC entry 5365 (class 2604 OID 17229)
-- Name: task_types task_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_types ALTER COLUMN task_type_id SET DEFAULT nextval('public.task_types_task_type_id_seq'::regclass);


--
-- TOC entry 5366 (class 2604 OID 17230)
-- Name: tasks task_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks ALTER COLUMN task_id SET DEFAULT nextval('public.tasks_task_id_seq'::regclass);


--
-- TOC entry 5369 (class 2604 OID 17231)
-- Name: templates template_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates ALTER COLUMN template_id SET DEFAULT nextval('public.templates_template_id_seq'::regclass);


--
-- TOC entry 5372 (class 2604 OID 17232)
-- Name: theme_comments theme_comment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments ALTER COLUMN theme_comment_id SET DEFAULT nextval('public.theme_comments_theme_comment_id_seq'::regclass);


--
-- TOC entry 5375 (class 2604 OID 17233)
-- Name: theme_types theme_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_types ALTER COLUMN theme_type_id SET DEFAULT nextval('public.theme_types_theme_type_id_seq'::regclass);


--
-- TOC entry 5376 (class 2604 OID 17234)
-- Name: themes theme_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes ALTER COLUMN theme_id SET DEFAULT nextval('public.themes_theme_id_seq'::regclass);


--
-- TOC entry 5379 (class 2604 OID 17235)
-- Name: venue_types venue_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_types ALTER COLUMN venue_type_id SET DEFAULT nextval('public.venue_types_venue_type_id_seq'::regclass);


--
-- TOC entry 5380 (class 2604 OID 17236)
-- Name: venues venue_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues ALTER COLUMN venue_id SET DEFAULT nextval('public.venues_venue_id_seq'::regclass);


--
-- TOC entry 6015 (class 0 OID 16529)
-- Dependencies: 222
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
-- TOC entry 6016 (class 0 OID 16535)
-- Dependencies: 223
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
-- TOC entry 6018 (class 0 OID 16546)
-- Dependencies: 225
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
\.


--
-- TOC entry 6020 (class 0 OID 16554)
-- Dependencies: 227
-- Data for Name: actor_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actor_types (actor_type_id, type, description) FROM stdin;
1	Человек	\N
2	Сообщество	\N
3	Организация	\N
\.


--
-- TOC entry 6022 (class 0 OID 16562)
-- Dependencies: 229
-- Data for Name: actors; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors (actor_id, nickname, actor_type_id, icon, keywords, account, deleted_at, created_at, updated_at, created_by, updated_by, color_frame) FROM stdin;
1	Администратор системы	1	\N	\N	000000000001	\N	2026-01-06 23:53:40.21+08	2026-01-06 23:53:40.21+08	1	1	\N
3	НовыйПользователь	1	\N	\N	U00000000001	\N	2026-01-07 00:33:36.783+08	2026-01-07 00:33:36.783+08	1	1	\N
4	ВторойЮзер	1	\N	\N	U00000000002	\N	2026-01-07 00:35:06.117+08	2026-01-07 00:35:06.117+08	1	1	\N
6	УспешныйПользователь	1	\N	\N	U00000000003	\N	2026-01-07 00:55:30.892+08	2026-01-07 00:55:30.892+08	1	1	\N
8	test	1	\N	\N	U00000000004	\N	2026-01-07 00:58:24.155+08	2026-01-07 00:58:24.155+08	1	1	\N
9	Разработчик	1	\N	\N	D00000000001	\N	2026-01-07 03:30:43.464+08	2026-01-07 03:30:43.464+08	1	1	\N
10	ТестовыйРегистрация	1	\N	\N	U00000000005	\N	2026-01-07 14:28:38.158+08	2026-01-07 14:28:38.158+08	1	1	\N
11	TestUser	1	\N	\N	U00000000006	\N	2026-01-07 17:42:35.47+08	2026-01-07 17:42:35.47+08	1	1	\N
12	NewUser	1	\N	\N	U00000000007	\N	2026-01-07 17:48:45.819+08	2026-01-07 17:48:45.819+08	1	1	\N
13	User0926	1	\N	\N	U00000000008	\N	2026-01-07 21:19:52.291+08	2026-01-07 21:19:52.291+08	1	1	\N
14	cabotin	1	\N	\N	U00000000009	\N	2026-01-07 22:33:55.441+08	2026-01-07 22:33:55.441+08	1	1	\N
17	new	1	\N	\N	U00000000010	\N	2026-01-07 23:24:36.665+08	2026-01-07 23:24:36.665+08	1	1	\N
21	new2026	1	\N	\N	U10095478347	\N	2026-01-10 03:01:57.54+08	2026-01-10 03:01:57.54+08	1	1	#118AB2
\.


--
-- TOC entry 6024 (class 0 OID 16574)
-- Dependencies: 231
-- Data for Name: actors_directions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_directions (actor_id, direction_id) FROM stdin;
\.


--
-- TOC entry 6025 (class 0 OID 16579)
-- Dependencies: 232
-- Data for Name: actors_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_events (actor_id, event_id) FROM stdin;
1	1
3	1
1	2
3	2
\.


--
-- TOC entry 6026 (class 0 OID 16584)
-- Dependencies: 233
-- Data for Name: actors_locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_locations (actor_id, location_id) FROM stdin;
\.


--
-- TOC entry 6027 (class 0 OID 16589)
-- Dependencies: 234
-- Data for Name: actors_messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_messages (message_id, actor_id) FROM stdin;
\.


--
-- TOC entry 6028 (class 0 OID 16594)
-- Dependencies: 235
-- Data for Name: actors_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_notes (note_id, actor_id, author_id) FROM stdin;
\.


--
-- TOC entry 6029 (class 0 OID 16599)
-- Dependencies: 236
-- Data for Name: actors_projects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_projects (actor_id, project_id, created_at, updated_at, created_by, updated_by) FROM stdin;
1	1	2026-01-07 00:36:58.406+08	2026-01-07 00:36:58.406+08	1	1
\.


--
-- TOC entry 6030 (class 0 OID 16608)
-- Dependencies: 237
-- Data for Name: actors_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_tasks (task_id, actor_id) FROM stdin;
1	3
\.


--
-- TOC entry 6146 (class 0 OID 18415)
-- Dependencies: 362
-- Data for Name: bookmarks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bookmarks (bookmark_id, actor_id, theme_id, created_at) FROM stdin;
\.


--
-- TOC entry 6031 (class 0 OID 16613)
-- Dependencies: 238
-- Data for Name: communities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.communities (community_id, title, full_title, email, email_2, participant_name, participant_lastname, location_id, post_code, address, phone_number, phone_number_2, bank_title, bank_bik, bank_account, community_info, vk_page, ok_page, tt_page, tg_page, ig_page, fb_page, max_page, web_page, attachment, actor_id, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6138 (class 0 OID 18292)
-- Dependencies: 351
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
-- TOC entry 6033 (class 0 OID 16627)
-- Dependencies: 240
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
\.


--
-- TOC entry 6035 (class 0 OID 16634)
-- Dependencies: 242
-- Data for Name: event_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.event_types (event_type_id, type) FROM stdin;
1	Публичное
2	Непубличное
\.


--
-- TOC entry 6037 (class 0 OID 16640)
-- Dependencies: 244
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.events (event_id, title, description, date, start_time, end_time, event_type_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
1	Читка пьесы "Гамлет"	Первая читка сценария с актерами	2026-01-14	18:00:00	20:00:00	1	\N	\N	2026-01-07 00:38:38.629+08	2026-01-07 00:38:38.629+08	1	1
2	Открытая репетиция демо-проекта	Приглашаем всех желающих посмотреть на процесс создания арт-проекта	2026-01-14	19:00:00	21:00:00	1	\N	\N	2026-01-07 00:59:05.014+08	2026-01-07 00:59:05.014+08	1	1
\.


--
-- TOC entry 6039 (class 0 OID 16654)
-- Dependencies: 246
-- Data for Name: events_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.events_notes (note_id, event_id) FROM stdin;
\.


--
-- TOC entry 6144 (class 0 OID 18395)
-- Dependencies: 360
-- Data for Name: favorites; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.favorites (favorite_id, actor_id, entity_type, entity_id, created_at) FROM stdin;
\.


--
-- TOC entry 6040 (class 0 OID 16659)
-- Dependencies: 247
-- Data for Name: finresource_owners; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.finresource_owners (finresource_id, actor_id) FROM stdin;
\.


--
-- TOC entry 6041 (class 0 OID 16664)
-- Dependencies: 248
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
-- TOC entry 6043 (class 0 OID 16670)
-- Dependencies: 250
-- Data for Name: finresources; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.finresources (finresource_id, title, description, finresource_type_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6045 (class 0 OID 16682)
-- Dependencies: 252
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
11	Актер озвучивания	Озвучивает персонажей, рекламу, аудиокниги.	\N
12	Аналитик	Анализирует данные, тренды, эффективность проектов.	\N
13	Аниматор	Создает анимацию для кино, игр, мультфильмов.	\N
14	Аниматор 2D	Работает с двумерной анимацией.	\N
15	Аниматор 3D	Создает трёхмерную анимацию.	\N
16	Архитектор	Проектирует здания и сооружения.	\N
17	Арт-директор	Определяет визуальную стратегию проекта.	\N
18	Ассистент режиссёра	Помогает режиссёру на съёмках/репетициях.	\N
19	Бухгалтер	Ведёт финансовый учёт и отчётность.	\N
20	Ведущий	Ведёт мероприятия, концерты, церемонии.	\N
\.


--
-- TOC entry 6046 (class 0 OID 16689)
-- Dependencies: 253
-- Data for Name: functions_directions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.functions_directions (function_id, direction_id) FROM stdin;
\.


--
-- TOC entry 6048 (class 0 OID 16695)
-- Dependencies: 255
-- Data for Name: group_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.group_tasks (task_id, project_group_id) FROM stdin;
\.


--
-- TOC entry 6049 (class 0 OID 16700)
-- Dependencies: 256
-- Data for Name: idea_categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.idea_categories (idea_category_id, category) FROM stdin;
1	Возмездная
2	Безвозмездная
\.


--
-- TOC entry 6051 (class 0 OID 16706)
-- Dependencies: 258
-- Data for Name: idea_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.idea_types (idea_type_id, type) FROM stdin;
1	Коммерческая
2	Некоммерческая
\.


--
-- TOC entry 6053 (class 0 OID 16712)
-- Dependencies: 260
-- Data for Name: ideas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ideas (idea_id, title, short_description, full_description, detail_description, idea_category_id, idea_type_id, actor_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
1	Идея документального фильма о театре	Документальный фильм о современном театральном искусстве	Полное описание идеи документального фильма, который расскажет о современных театральных постановках и актерах	\N	1	2	3	\N	\N	2026-01-07 00:46:46.36+08	2026-01-07 00:46:46.36+08	1	1
2	Идея для музыкального фестиваля	Организация летнего музыкального фестиваля под открытым небом	\N	\N	1	2	3	\N	2026-01-07 00:49:50.594+08	2026-01-07 00:49:50.594+08	2026-01-07 00:49:50.594+08	1	1
\.


--
-- TOC entry 6054 (class 0 OID 16723)
-- Dependencies: 261
-- Data for Name: ideas_directions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ideas_directions (idea_id, direction_id) FROM stdin;
\.


--
-- TOC entry 6056 (class 0 OID 16729)
-- Dependencies: 263
-- Data for Name: ideas_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ideas_notes (note_id, idea_id) FROM stdin;
\.


--
-- TOC entry 6057 (class 0 OID 16734)
-- Dependencies: 264
-- Data for Name: ideas_projects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ideas_projects (idea_id, project_id) FROM stdin;
\.


--
-- TOC entry 6058 (class 0 OID 16739)
-- Dependencies: 265
-- Data for Name: local_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.local_events (local_event_id, title, description, date, start_time, end_time, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6060 (class 0 OID 16753)
-- Dependencies: 267
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.locations (location_id, name, type, district, region, country, main_postcode, description, population, attachment) FROM stdin;
1	Москва	город	\N	Москва	Россия	\N	\N	12678079	\N
2	Санкт-Петербург	город	\N	Санкт-Петербург	Россия	\N	\N	5398064	\N
3	Улан-Удэ	город	\N	Бурятия	Россия	\N	\N	437565	\N
4	Иркутск	город	\N	Иркутская область	Россия	\N	\N	617264	\N
5	Кяхта	город	\N	Бурятия	Россия	\N	\N	20013	\N
\.


--
-- TOC entry 6062 (class 0 OID 16761)
-- Dependencies: 269
-- Data for Name: matresource_owners; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresource_owners (matresource_id, actor_id) FROM stdin;
\.


--
-- TOC entry 6063 (class 0 OID 16766)
-- Dependencies: 270
-- Data for Name: matresource_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresource_types (matresource_type_id, category, sub_category, title) FROM stdin;
\.


--
-- TOC entry 6065 (class 0 OID 16771)
-- Dependencies: 272
-- Data for Name: matresources; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresources (matresource_id, title, description, matresource_type_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6067 (class 0 OID 16783)
-- Dependencies: 274
-- Data for Name: matresources_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresources_notes (note_id, matresource_id) FROM stdin;
\.


--
-- TOC entry 6068 (class 0 OID 16788)
-- Dependencies: 275
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.messages (message_id, message, author_id, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6070 (class 0 OID 16801)
-- Dependencies: 277
-- Data for Name: notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notes (note_id, note, author_id, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6072 (class 0 OID 16814)
-- Dependencies: 279
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notifications (notification_id, notification, recipient, is_read, created_at, updated_at, created_by, updated_by) FROM stdin;
1	У вас новая задача: "Подготовить сценарий для читки"	3	f	2026-01-07 00:53:42.309+08	2026-01-07 00:53:42.309+08	1	1
\.


--
-- TOC entry 6074 (class 0 OID 16828)
-- Dependencies: 281
-- Data for Name: organizations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.organizations (organization_id, title, full_title, email, email_2, staff_name, staff_lastname, location_id, post_code, address, phone_number, phone_number_2, dir_name, dir_lastname, ogrn, inn, kpp, bank_title, bank_bik, bank_account, org_info, vk_page, ok_page, tt_page, tg_page, ig_page, fb_page, max_page, web_page, attachment, actor_id, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6076 (class 0 OID 16842)
-- Dependencies: 283
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
-- TOC entry 6078 (class 0 OID 16859)
-- Dependencies: 285
-- Data for Name: project_actor_roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.project_actor_roles (project_actor_role_id, actor_id, project_id, role_type, assigned_at, assigned_by, note) FROM stdin;
7	1	1	member	2026-01-09 03:54:45.944+08	\N	\N
8	3	2	leader	2026-01-09 04:10:14.195+08	3	\N
9	3	3	leader	2026-01-09 04:10:14.195+08	3	\N
10	3	4	leader	2026-01-09 04:10:14.195+08	3	\N
12	3	5	leader	2026-01-09 04:10:14.195+08	3	\N
13	4	1	admin	2026-01-09 04:10:34.652+08	1	\N
14	6	1	member	2026-01-09 04:10:34.652+08	1	\N
15	9	1	curator	2026-01-09 04:10:34.652+08	1	\N
16	10	1	member	2026-01-09 04:10:34.652+08	1	\N
17	4	2	member	2026-01-09 04:10:34.652+08	3	\N
18	6	2	admin	2026-01-09 04:10:34.652+08	3	\N
\.


--
-- TOC entry 6080 (class 0 OID 16871)
-- Dependencies: 287
-- Data for Name: project_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.project_groups (project_group_id, title, project_id, actor_id, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6082 (class 0 OID 16882)
-- Dependencies: 289
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
-- TOC entry 6084 (class 0 OID 16890)
-- Dependencies: 291
-- Data for Name: project_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.project_types (project_type_id, type) FROM stdin;
1	Коммерческий
2	Некоммерческий
\.


--
-- TOC entry 6086 (class 0 OID 16896)
-- Dependencies: 293
-- Data for Name: projects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects (project_id, title, full_title, description, author_id, director_id, tutor_id, project_status_id, start_date, end_date, project_type_id, account, keywords, attachment, deleted_at, created_at, updated_at, created_by, updated_by, rating_id) FROM stdin;
1	Театральный фестиваль	Международный театральный фестиваль современного искусства	Организация и проведение ежегодного театрального фестиваля	1	\N	\N	4	2025-12-28	2026-01-27	2	000000000001	\N	\N	\N	2026-01-06 23:53:40.21+08	2026-01-07 00:51:10.056+08	1	1	\N
2	Театральная постановка "Гамлет"	\N	Современная интерпретация классической пьесы Шекспира	3	\N	\N	1	\N	\N	2	\N	\N	\N	\N	2026-01-07 00:36:28.559+08	2026-01-07 00:36:28.559+08	1	1	\N
3	Кинофестиваль "Новое кино"	\N	Ежегодный фестиваль независимого кино с участием молодых режиссеров	3	\N	\N	1	\N	\N	2	\N	\N	\N	\N	2026-01-07 00:46:46.36+08	2026-01-07 00:46:46.36+08	1	1	\N
4	Фотовыставка "Городские пейзажи"	\N	Выставка фотографий городской архитектуры и жизни	3	\N	\N	4	\N	\N	2	\N	\N	\N	\N	2026-01-07 00:50:58.999+08	2026-01-07 00:50:58.999+08	1	1	\N
5	Демонстрационный арт-проект	\N	Мультидисциплинарный проект, объединяющий театр, музыку и визуальное искусство	3	\N	\N	4	2025-12-08	2026-03-08	2	\N	\N	\N	\N	2026-01-07 00:59:05.014+08	2026-01-07 00:59:05.014+08	1	1	\N
\.


--
-- TOC entry 6087 (class 0 OID 16908)
-- Dependencies: 294
-- Data for Name: projects_directions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_directions (project_id, direction_id) FROM stdin;
1	1
5	1
5	9
\.


--
-- TOC entry 6088 (class 0 OID 16913)
-- Dependencies: 295
-- Data for Name: projects_functions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_functions (project_id, function_id) FROM stdin;
1	8
1	18
5	8
5	13
5	17
\.


--
-- TOC entry 6089 (class 0 OID 16918)
-- Dependencies: 296
-- Data for Name: projects_local_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_local_events (project_id, local_event_id) FROM stdin;
\.


--
-- TOC entry 6090 (class 0 OID 16923)
-- Dependencies: 297
-- Data for Name: projects_locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_locations (project_id, location_id) FROM stdin;
\.


--
-- TOC entry 6091 (class 0 OID 16928)
-- Dependencies: 298
-- Data for Name: projects_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_notes (note_id, project_id) FROM stdin;
\.


--
-- TOC entry 6093 (class 0 OID 16934)
-- Dependencies: 300
-- Data for Name: projects_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_tasks (task_id, project_id) FROM stdin;
1	1
\.


--
-- TOC entry 6140 (class 0 OID 18357)
-- Dependencies: 356
-- Data for Name: rating_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rating_types (rating_type_id, type, description, created_at) FROM stdin;
1	положительно	Положительная оценка (лайк)	2026-01-15 20:59:11.433599+08
2	отрицательно	Отрицательная оценка	2026-01-15 20:59:11.433599+08
\.


--
-- TOC entry 6142 (class 0 OID 18372)
-- Dependencies: 358
-- Data for Name: ratings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ratings (rating_id, actor_id, rating_type_id, created_at) FROM stdin;
\.


--
-- TOC entry 6094 (class 0 OID 16939)
-- Dependencies: 301
-- Data for Name: services; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services (service_id, title, description, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6095 (class 0 OID 16950)
-- Dependencies: 302
-- Data for Name: services_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services_notes (note_id, service_id) FROM stdin;
\.


--
-- TOC entry 6097 (class 0 OID 16956)
-- Dependencies: 304
-- Data for Name: stage_architecture; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_architecture (stage_architecture_id, architecture) FROM stdin;
\.


--
-- TOC entry 6099 (class 0 OID 16962)
-- Dependencies: 306
-- Data for Name: stage_audio; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_audio (stage_audio_id, title, description, attachment, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6100 (class 0 OID 16973)
-- Dependencies: 307
-- Data for Name: stage_audio_set; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_audio_set (stage_id, stage_audio_id) FROM stdin;
\.


--
-- TOC entry 6102 (class 0 OID 16979)
-- Dependencies: 309
-- Data for Name: stage_effects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_effects (stage_effects_id, title, description, attachment, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6103 (class 0 OID 16990)
-- Dependencies: 310
-- Data for Name: stage_effects_set; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_effects_set (stage_id, stage_effects_id) FROM stdin;
\.


--
-- TOC entry 6105 (class 0 OID 16996)
-- Dependencies: 312
-- Data for Name: stage_light; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_light (stage_light_id, title, description, attachment, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6106 (class 0 OID 17007)
-- Dependencies: 313
-- Data for Name: stage_light_set; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_light_set (stage_id, stage_light_id) FROM stdin;
\.


--
-- TOC entry 6108 (class 0 OID 17013)
-- Dependencies: 315
-- Data for Name: stage_mobility; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_mobility (stage_mobility_id, mobility) FROM stdin;
\.


--
-- TOC entry 6110 (class 0 OID 17019)
-- Dependencies: 317
-- Data for Name: stage_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_types (stage_type_id, type) FROM stdin;
\.


--
-- TOC entry 6112 (class 0 OID 17025)
-- Dependencies: 319
-- Data for Name: stage_video; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_video (stage_video_id, title, description, attachment, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6113 (class 0 OID 17036)
-- Dependencies: 320
-- Data for Name: stage_video_set; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_video_set (stage_id, stage_video_id) FROM stdin;
\.


--
-- TOC entry 6115 (class 0 OID 17042)
-- Dependencies: 322
-- Data for Name: stages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stages (stage_id, title, full_title, stage_type_id, stage_architecture_id, stage_mobility_id, capacity, width, depth, height, description, location_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6117 (class 0 OID 17058)
-- Dependencies: 324
-- Data for Name: task_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.task_types (task_type_id, type) FROM stdin;
1	Планируется
2	В работе
3	Приостановлено
4	Завершено
\.


--
-- TOC entry 6119 (class 0 OID 17064)
-- Dependencies: 326
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tasks (task_id, task, task_type_id, due_date, priority, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
1	Подготовить сценарий для читки	1	2026-01-10	3	\N	2026-01-07 00:52:59.278+08	2026-01-07 00:52:59.278+08	1	1
\.


--
-- TOC entry 6121 (class 0 OID 17077)
-- Dependencies: 328
-- Data for Name: templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates (template_id, title, description, direction_id, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6122 (class 0 OID 17088)
-- Dependencies: 329
-- Data for Name: templates_finresources; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates_finresources (template_id, finresource_id) FROM stdin;
\.


--
-- TOC entry 6123 (class 0 OID 17093)
-- Dependencies: 330
-- Data for Name: templates_functions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates_functions (template_id, function_id) FROM stdin;
\.


--
-- TOC entry 6124 (class 0 OID 17098)
-- Dependencies: 331
-- Data for Name: templates_matresources; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates_matresources (template_id, matresource_id) FROM stdin;
\.


--
-- TOC entry 6126 (class 0 OID 17104)
-- Dependencies: 333
-- Data for Name: templates_venues; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates_venues (template_id, venue_id) FROM stdin;
\.


--
-- TOC entry 6127 (class 0 OID 17109)
-- Dependencies: 334
-- Data for Name: theme_comments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.theme_comments (theme_comment_id, comment, theme_id, actor_id, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6129 (class 0 OID 17123)
-- Dependencies: 336
-- Data for Name: theme_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.theme_types (theme_type_id, type) FROM stdin;
\.


--
-- TOC entry 6131 (class 0 OID 17129)
-- Dependencies: 338
-- Data for Name: themes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.themes (theme_id, title, description, theme_type_id, actor_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6133 (class 0 OID 17141)
-- Dependencies: 340
-- Data for Name: venue_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venue_types (venue_type_id, type) FROM stdin;
\.


--
-- TOC entry 6135 (class 0 OID 17147)
-- Dependencies: 342
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venues (venue_id, title, full_title, venue_type_id, description, actor_id, location_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- TOC entry 6147 (class 0 OID 18447)
-- Dependencies: 363
-- Data for Name: venues_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venues_notes (note_id, venue_id, author_id) FROM stdin;
\.


--
-- TOC entry 6136 (class 0 OID 17158)
-- Dependencies: 343
-- Data for Name: venues_stages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venues_stages (venue_id, stage_id) FROM stdin;
\.


--
-- TOC entry 6213 (class 0 OID 0)
-- Dependencies: 224
-- Name: actor_current_statuses_actor_current_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.actor_current_statuses_actor_current_status_id_seq', 1, false);


--
-- TOC entry 6214 (class 0 OID 0)
-- Dependencies: 226
-- Name: actor_statuses_actor_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.actor_statuses_actor_status_id_seq', 1, false);


--
-- TOC entry 6215 (class 0 OID 0)
-- Dependencies: 228
-- Name: actor_types_actor_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.actor_types_actor_type_id_seq', 1, false);


--
-- TOC entry 6216 (class 0 OID 0)
-- Dependencies: 230
-- Name: actors_actor_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.actors_actor_id_seq', 3, true);


--
-- TOC entry 6217 (class 0 OID 0)
-- Dependencies: 361
-- Name: bookmarks_bookmark_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.bookmarks_bookmark_id_seq', 1, false);


--
-- TOC entry 6218 (class 0 OID 0)
-- Dependencies: 239
-- Name: communities_community_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.communities_community_id_seq', 1, false);


--
-- TOC entry 6219 (class 0 OID 0)
-- Dependencies: 241
-- Name: directions_direction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.directions_direction_id_seq', 1, false);


--
-- TOC entry 6220 (class 0 OID 0)
-- Dependencies: 243
-- Name: event_types_event_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.event_types_event_type_id_seq', 1, false);


--
-- TOC entry 6221 (class 0 OID 0)
-- Dependencies: 245
-- Name: events_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.events_event_id_seq', 1, false);


--
-- TOC entry 6222 (class 0 OID 0)
-- Dependencies: 359
-- Name: favorites_favorite_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.favorites_favorite_id_seq', 1, false);


--
-- TOC entry 6223 (class 0 OID 0)
-- Dependencies: 249
-- Name: finresource_types_finresource_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.finresource_types_finresource_type_id_seq', 1, false);


--
-- TOC entry 6224 (class 0 OID 0)
-- Dependencies: 251
-- Name: finresources_finresource_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.finresources_finresource_id_seq', 1, false);


--
-- TOC entry 6225 (class 0 OID 0)
-- Dependencies: 254
-- Name: functions_function_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.functions_function_id_seq', 1, false);


--
-- TOC entry 6226 (class 0 OID 0)
-- Dependencies: 257
-- Name: idea_categories_idea_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.idea_categories_idea_category_id_seq', 1, false);


--
-- TOC entry 6227 (class 0 OID 0)
-- Dependencies: 259
-- Name: idea_types_idea_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.idea_types_idea_type_id_seq', 1, false);


--
-- TOC entry 6228 (class 0 OID 0)
-- Dependencies: 262
-- Name: ideas_idea_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ideas_idea_id_seq', 1, false);


--
-- TOC entry 6229 (class 0 OID 0)
-- Dependencies: 266
-- Name: local_events_local_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.local_events_local_event_id_seq', 1, false);


--
-- TOC entry 6230 (class 0 OID 0)
-- Dependencies: 268
-- Name: locations_location_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.locations_location_id_seq', 1, false);


--
-- TOC entry 6231 (class 0 OID 0)
-- Dependencies: 271
-- Name: matresource_types_matresource_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.matresource_types_matresource_type_id_seq', 1, false);


--
-- TOC entry 6232 (class 0 OID 0)
-- Dependencies: 273
-- Name: matresources_matresource_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.matresources_matresource_id_seq', 1, false);


--
-- TOC entry 6233 (class 0 OID 0)
-- Dependencies: 276
-- Name: messages_message_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.messages_message_id_seq', 1, false);


--
-- TOC entry 6234 (class 0 OID 0)
-- Dependencies: 278
-- Name: notes_note_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notes_note_id_seq', 1, false);


--
-- TOC entry 6235 (class 0 OID 0)
-- Dependencies: 280
-- Name: notifications_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notifications_notification_id_seq', 1, false);


--
-- TOC entry 6236 (class 0 OID 0)
-- Dependencies: 282
-- Name: organizations_organization_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.organizations_organization_id_seq', 1, false);


--
-- TOC entry 6237 (class 0 OID 0)
-- Dependencies: 284
-- Name: persons_person_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.persons_person_id_seq', 1, true);


--
-- TOC entry 6238 (class 0 OID 0)
-- Dependencies: 286
-- Name: project_actor_roles_project_actor_role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.project_actor_roles_project_actor_role_id_seq', 1, false);


--
-- TOC entry 6239 (class 0 OID 0)
-- Dependencies: 288
-- Name: project_groups_project_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.project_groups_project_group_id_seq', 1, false);


--
-- TOC entry 6240 (class 0 OID 0)
-- Dependencies: 290
-- Name: project_statuses_project_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.project_statuses_project_status_id_seq', 1, false);


--
-- TOC entry 6241 (class 0 OID 0)
-- Dependencies: 292
-- Name: project_types_project_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.project_types_project_type_id_seq', 1, false);


--
-- TOC entry 6242 (class 0 OID 0)
-- Dependencies: 299
-- Name: projects_project_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.projects_project_id_seq', 1, false);


--
-- TOC entry 6243 (class 0 OID 0)
-- Dependencies: 355
-- Name: rating_types_rating_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rating_types_rating_type_id_seq', 2, true);


--
-- TOC entry 6244 (class 0 OID 0)
-- Dependencies: 357
-- Name: ratings_rating_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ratings_rating_id_seq', 1, false);


--
-- TOC entry 6245 (class 0 OID 0)
-- Dependencies: 303
-- Name: services_service_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.services_service_id_seq', 1, false);


--
-- TOC entry 6246 (class 0 OID 0)
-- Dependencies: 305
-- Name: stage_architecture_stage_architecture_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_architecture_stage_architecture_id_seq', 1, false);


--
-- TOC entry 6247 (class 0 OID 0)
-- Dependencies: 308
-- Name: stage_audio_stage_audio_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_audio_stage_audio_id_seq', 1, false);


--
-- TOC entry 6248 (class 0 OID 0)
-- Dependencies: 311
-- Name: stage_effects_stage_effects_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_effects_stage_effects_id_seq', 1, false);


--
-- TOC entry 6249 (class 0 OID 0)
-- Dependencies: 314
-- Name: stage_light_stage_light_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_light_stage_light_id_seq', 1, false);


--
-- TOC entry 6250 (class 0 OID 0)
-- Dependencies: 316
-- Name: stage_mobility_stage_mobility_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_mobility_stage_mobility_id_seq', 1, false);


--
-- TOC entry 6251 (class 0 OID 0)
-- Dependencies: 318
-- Name: stage_types_stage_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_types_stage_type_id_seq', 1, false);


--
-- TOC entry 6252 (class 0 OID 0)
-- Dependencies: 321
-- Name: stage_video_stage_video_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stage_video_stage_video_id_seq', 1, false);


--
-- TOC entry 6253 (class 0 OID 0)
-- Dependencies: 323
-- Name: stages_stage_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stages_stage_id_seq', 1, false);


--
-- TOC entry 6254 (class 0 OID 0)
-- Dependencies: 325
-- Name: task_types_task_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.task_types_task_type_id_seq', 1, false);


--
-- TOC entry 6255 (class 0 OID 0)
-- Dependencies: 327
-- Name: tasks_task_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tasks_task_id_seq', 1, false);


--
-- TOC entry 6256 (class 0 OID 0)
-- Dependencies: 332
-- Name: templates_template_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.templates_template_id_seq', 1, false);


--
-- TOC entry 6257 (class 0 OID 0)
-- Dependencies: 335
-- Name: theme_comments_theme_comment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.theme_comments_theme_comment_id_seq', 1, false);


--
-- TOC entry 6258 (class 0 OID 0)
-- Dependencies: 337
-- Name: theme_types_theme_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.theme_types_theme_type_id_seq', 1, false);


--
-- TOC entry 6259 (class 0 OID 0)
-- Dependencies: 339
-- Name: themes_theme_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.themes_theme_id_seq', 1, false);


--
-- TOC entry 6260 (class 0 OID 0)
-- Dependencies: 341
-- Name: venue_types_venue_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.venue_types_venue_type_id_seq', 1, false);


--
-- TOC entry 6261 (class 0 OID 0)
-- Dependencies: 344
-- Name: venues_venue_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.venues_venue_id_seq', 1, false);


--
-- TOC entry 5411 (class 2606 OID 17238)
-- Name: actor_credentials actor_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_credentials
    ADD CONSTRAINT actor_credentials_pkey PRIMARY KEY (actor_id);


--
-- TOC entry 5413 (class 2606 OID 17240)
-- Name: actor_current_statuses actor_current_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_current_statuses
    ADD CONSTRAINT actor_current_statuses_pkey PRIMARY KEY (actor_current_status_id);


--
-- TOC entry 5415 (class 2606 OID 17242)
-- Name: actor_statuses actor_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_statuses
    ADD CONSTRAINT actor_statuses_pkey PRIMARY KEY (actor_status_id);


--
-- TOC entry 5417 (class 2606 OID 17244)
-- Name: actor_statuses actor_statuses_status_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_statuses
    ADD CONSTRAINT actor_statuses_status_key UNIQUE (status);


--
-- TOC entry 5419 (class 2606 OID 17246)
-- Name: actor_types actor_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_types
    ADD CONSTRAINT actor_types_pkey PRIMARY KEY (actor_type_id);


--
-- TOC entry 5421 (class 2606 OID 17248)
-- Name: actor_types actor_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_types
    ADD CONSTRAINT actor_types_type_key UNIQUE (type);


--
-- TOC entry 5423 (class 2606 OID 17250)
-- Name: actors actors_account_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT actors_account_key UNIQUE (account);


--
-- TOC entry 5433 (class 2606 OID 17252)
-- Name: actors_directions actors_directions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_directions
    ADD CONSTRAINT actors_directions_pkey PRIMARY KEY (actor_id, direction_id);


--
-- TOC entry 5436 (class 2606 OID 17254)
-- Name: actors_events actors_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_events
    ADD CONSTRAINT actors_events_pkey PRIMARY KEY (actor_id, event_id);


--
-- TOC entry 5438 (class 2606 OID 17256)
-- Name: actors_locations actors_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_locations
    ADD CONSTRAINT actors_locations_pkey PRIMARY KEY (actor_id, location_id);


--
-- TOC entry 5440 (class 2606 OID 17258)
-- Name: actors_messages actors_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_messages
    ADD CONSTRAINT actors_messages_pkey PRIMARY KEY (message_id, actor_id);


--
-- TOC entry 5442 (class 2606 OID 17260)
-- Name: actors_notes actors_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_notes
    ADD CONSTRAINT actors_notes_pkey PRIMARY KEY (note_id, actor_id);


--
-- TOC entry 5425 (class 2606 OID 17262)
-- Name: actors actors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT actors_pkey PRIMARY KEY (actor_id);


--
-- TOC entry 5444 (class 2606 OID 17264)
-- Name: actors_projects actors_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_projects
    ADD CONSTRAINT actors_projects_pkey PRIMARY KEY (actor_id, project_id);


--
-- TOC entry 5448 (class 2606 OID 17266)
-- Name: actors_tasks actors_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_tasks
    ADD CONSTRAINT actors_tasks_pkey PRIMARY KEY (task_id, actor_id);


--
-- TOC entry 5665 (class 2606 OID 18426)
-- Name: bookmarks bookmarks_actor_id_theme_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_actor_id_theme_id_key UNIQUE (actor_id, theme_id);


--
-- TOC entry 5667 (class 2606 OID 18424)
-- Name: bookmarks bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_pkey PRIMARY KEY (bookmark_id);


--
-- TOC entry 5450 (class 2606 OID 17268)
-- Name: communities communities_actor_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_actor_id_key UNIQUE (actor_id);


--
-- TOC entry 5452 (class 2606 OID 17270)
-- Name: communities communities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_pkey PRIMARY KEY (community_id);


--
-- TOC entry 5454 (class 2606 OID 17272)
-- Name: directions directions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.directions
    ADD CONSTRAINT directions_pkey PRIMARY KEY (direction_id);


--
-- TOC entry 5458 (class 2606 OID 17274)
-- Name: event_types event_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_types
    ADD CONSTRAINT event_types_pkey PRIMARY KEY (event_type_id);


--
-- TOC entry 5460 (class 2606 OID 17276)
-- Name: event_types event_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_types
    ADD CONSTRAINT event_types_type_key UNIQUE (type);


--
-- TOC entry 5468 (class 2606 OID 17278)
-- Name: events_notes events_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events_notes
    ADD CONSTRAINT events_notes_pkey PRIMARY KEY (note_id, event_id);


--
-- TOC entry 5462 (class 2606 OID 17280)
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (event_id);


--
-- TOC entry 5660 (class 2606 OID 18407)
-- Name: favorites favorites_actor_id_entity_type_entity_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_actor_id_entity_type_entity_id_key UNIQUE (actor_id, entity_type, entity_id);


--
-- TOC entry 5663 (class 2606 OID 18405)
-- Name: favorites favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (favorite_id);


--
-- TOC entry 5470 (class 2606 OID 17282)
-- Name: finresource_owners finresource_owners_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_owners
    ADD CONSTRAINT finresource_owners_pkey PRIMARY KEY (finresource_id, actor_id);


--
-- TOC entry 5472 (class 2606 OID 17284)
-- Name: finresource_types finresource_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_types
    ADD CONSTRAINT finresource_types_pkey PRIMARY KEY (finresource_type_id);


--
-- TOC entry 5474 (class 2606 OID 17286)
-- Name: finresource_types finresource_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_types
    ADD CONSTRAINT finresource_types_type_key UNIQUE (type);


--
-- TOC entry 5476 (class 2606 OID 17288)
-- Name: finresources finresources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources
    ADD CONSTRAINT finresources_pkey PRIMARY KEY (finresource_id);


--
-- TOC entry 5480 (class 2606 OID 17290)
-- Name: functions_directions functions_directions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.functions_directions
    ADD CONSTRAINT functions_directions_pkey PRIMARY KEY (function_id, direction_id);


--
-- TOC entry 5478 (class 2606 OID 17292)
-- Name: functions functions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.functions
    ADD CONSTRAINT functions_pkey PRIMARY KEY (function_id);


--
-- TOC entry 5482 (class 2606 OID 17294)
-- Name: group_tasks group_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_tasks
    ADD CONSTRAINT group_tasks_pkey PRIMARY KEY (task_id, project_group_id);


--
-- TOC entry 5484 (class 2606 OID 17296)
-- Name: idea_categories idea_categories_category_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_categories
    ADD CONSTRAINT idea_categories_category_key UNIQUE (category);


--
-- TOC entry 5486 (class 2606 OID 17298)
-- Name: idea_categories idea_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_categories
    ADD CONSTRAINT idea_categories_pkey PRIMARY KEY (idea_category_id);


--
-- TOC entry 5488 (class 2606 OID 17300)
-- Name: idea_types idea_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_types
    ADD CONSTRAINT idea_types_pkey PRIMARY KEY (idea_type_id);


--
-- TOC entry 5490 (class 2606 OID 17302)
-- Name: idea_types idea_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_types
    ADD CONSTRAINT idea_types_type_key UNIQUE (type);


--
-- TOC entry 5499 (class 2606 OID 17304)
-- Name: ideas_directions ideas_directions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_directions
    ADD CONSTRAINT ideas_directions_pkey PRIMARY KEY (idea_id, direction_id);


--
-- TOC entry 5501 (class 2606 OID 17306)
-- Name: ideas_notes ideas_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_notes
    ADD CONSTRAINT ideas_notes_pkey PRIMARY KEY (note_id, idea_id);


--
-- TOC entry 5492 (class 2606 OID 17308)
-- Name: ideas ideas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_pkey PRIMARY KEY (idea_id);


--
-- TOC entry 5503 (class 2606 OID 17310)
-- Name: ideas_projects ideas_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_projects
    ADD CONSTRAINT ideas_projects_pkey PRIMARY KEY (idea_id, project_id);


--
-- TOC entry 5505 (class 2606 OID 17312)
-- Name: local_events local_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_events
    ADD CONSTRAINT local_events_pkey PRIMARY KEY (local_event_id);


--
-- TOC entry 5507 (class 2606 OID 17314)
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (location_id);


--
-- TOC entry 5509 (class 2606 OID 17316)
-- Name: matresource_owners matresource_owners_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_owners
    ADD CONSTRAINT matresource_owners_pkey PRIMARY KEY (matresource_id, actor_id);


--
-- TOC entry 5511 (class 2606 OID 17318)
-- Name: matresource_types matresource_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_types
    ADD CONSTRAINT matresource_types_pkey PRIMARY KEY (matresource_type_id);


--
-- TOC entry 5515 (class 2606 OID 17320)
-- Name: matresources_notes matresources_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources_notes
    ADD CONSTRAINT matresources_notes_pkey PRIMARY KEY (note_id, matresource_id);


--
-- TOC entry 5513 (class 2606 OID 17322)
-- Name: matresources matresources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources
    ADD CONSTRAINT matresources_pkey PRIMARY KEY (matresource_id);


--
-- TOC entry 5517 (class 2606 OID 17324)
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (message_id);


--
-- TOC entry 5519 (class 2606 OID 17326)
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (note_id);


--
-- TOC entry 5524 (class 2606 OID 17328)
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (notification_id);


--
-- TOC entry 5526 (class 2606 OID 17330)
-- Name: organizations organizations_actor_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_actor_id_key UNIQUE (actor_id);


--
-- TOC entry 5528 (class 2606 OID 17332)
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (organization_id);


--
-- TOC entry 5535 (class 2606 OID 17334)
-- Name: persons persons_actor_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_actor_id_key UNIQUE (actor_id);


--
-- TOC entry 5537 (class 2606 OID 17336)
-- Name: persons persons_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_pkey PRIMARY KEY (person_id);


--
-- TOC entry 5543 (class 2606 OID 17338)
-- Name: project_actor_roles project_actor_roles_actor_id_project_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_actor_roles
    ADD CONSTRAINT project_actor_roles_actor_id_project_id_key UNIQUE (actor_id, project_id);


--
-- TOC entry 5545 (class 2606 OID 17340)
-- Name: project_actor_roles project_actor_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_actor_roles
    ADD CONSTRAINT project_actor_roles_pkey PRIMARY KEY (project_actor_role_id);


--
-- TOC entry 5547 (class 2606 OID 17342)
-- Name: project_groups project_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_groups
    ADD CONSTRAINT project_groups_pkey PRIMARY KEY (project_group_id);


--
-- TOC entry 5549 (class 2606 OID 17344)
-- Name: project_statuses project_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_statuses
    ADD CONSTRAINT project_statuses_pkey PRIMARY KEY (project_status_id);


--
-- TOC entry 5551 (class 2606 OID 17346)
-- Name: project_statuses project_statuses_status_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_statuses
    ADD CONSTRAINT project_statuses_status_key UNIQUE (status);


--
-- TOC entry 5553 (class 2606 OID 17348)
-- Name: project_types project_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_types
    ADD CONSTRAINT project_types_pkey PRIMARY KEY (project_type_id);


--
-- TOC entry 5555 (class 2606 OID 17350)
-- Name: project_types project_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_types
    ADD CONSTRAINT project_types_type_key UNIQUE (type);


--
-- TOC entry 5565 (class 2606 OID 17352)
-- Name: projects projects_account_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_account_key UNIQUE (account);


--
-- TOC entry 5570 (class 2606 OID 17354)
-- Name: projects_directions projects_directions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_directions
    ADD CONSTRAINT projects_directions_pkey PRIMARY KEY (project_id, direction_id);


--
-- TOC entry 5572 (class 2606 OID 17356)
-- Name: projects_functions projects_functions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_functions
    ADD CONSTRAINT projects_functions_pkey PRIMARY KEY (project_id, function_id);


--
-- TOC entry 5574 (class 2606 OID 17358)
-- Name: projects_local_events projects_local_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_local_events
    ADD CONSTRAINT projects_local_events_pkey PRIMARY KEY (project_id, local_event_id);


--
-- TOC entry 5577 (class 2606 OID 17360)
-- Name: projects_locations projects_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_locations
    ADD CONSTRAINT projects_locations_pkey PRIMARY KEY (project_id, location_id);


--
-- TOC entry 5579 (class 2606 OID 17362)
-- Name: projects_notes projects_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_notes
    ADD CONSTRAINT projects_notes_pkey PRIMARY KEY (note_id, project_id);


--
-- TOC entry 5567 (class 2606 OID 17364)
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (project_id);


--
-- TOC entry 5581 (class 2606 OID 17366)
-- Name: projects_tasks projects_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_tasks
    ADD CONSTRAINT projects_tasks_pkey PRIMARY KEY (task_id, project_id);


--
-- TOC entry 5652 (class 2606 OID 18368)
-- Name: rating_types rating_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rating_types
    ADD CONSTRAINT rating_types_pkey PRIMARY KEY (rating_type_id);


--
-- TOC entry 5654 (class 2606 OID 18370)
-- Name: rating_types rating_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rating_types
    ADD CONSTRAINT rating_types_type_key UNIQUE (type);


--
-- TOC entry 5656 (class 2606 OID 18383)
-- Name: ratings ratings_actor_id_rating_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_actor_id_rating_id_key UNIQUE (actor_id, rating_id);


--
-- TOC entry 5658 (class 2606 OID 18381)
-- Name: ratings ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_pkey PRIMARY KEY (rating_id);


--
-- TOC entry 5585 (class 2606 OID 17368)
-- Name: services_notes services_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_notes
    ADD CONSTRAINT services_notes_pkey PRIMARY KEY (note_id, service_id);


--
-- TOC entry 5583 (class 2606 OID 17370)
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (service_id);


--
-- TOC entry 5587 (class 2606 OID 17372)
-- Name: stage_architecture stage_architecture_architecture_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_architecture
    ADD CONSTRAINT stage_architecture_architecture_key UNIQUE (architecture);


--
-- TOC entry 5589 (class 2606 OID 17374)
-- Name: stage_architecture stage_architecture_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_architecture
    ADD CONSTRAINT stage_architecture_pkey PRIMARY KEY (stage_architecture_id);


--
-- TOC entry 5591 (class 2606 OID 17376)
-- Name: stage_audio stage_audio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio
    ADD CONSTRAINT stage_audio_pkey PRIMARY KEY (stage_audio_id);


--
-- TOC entry 5593 (class 2606 OID 17378)
-- Name: stage_audio_set stage_audio_set_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio_set
    ADD CONSTRAINT stage_audio_set_pkey PRIMARY KEY (stage_id, stage_audio_id);


--
-- TOC entry 5595 (class 2606 OID 17380)
-- Name: stage_effects stage_effects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects
    ADD CONSTRAINT stage_effects_pkey PRIMARY KEY (stage_effects_id);


--
-- TOC entry 5597 (class 2606 OID 17382)
-- Name: stage_effects_set stage_effects_set_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects_set
    ADD CONSTRAINT stage_effects_set_pkey PRIMARY KEY (stage_id, stage_effects_id);


--
-- TOC entry 5599 (class 2606 OID 17384)
-- Name: stage_light stage_light_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light
    ADD CONSTRAINT stage_light_pkey PRIMARY KEY (stage_light_id);


--
-- TOC entry 5601 (class 2606 OID 17386)
-- Name: stage_light_set stage_light_set_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light_set
    ADD CONSTRAINT stage_light_set_pkey PRIMARY KEY (stage_id, stage_light_id);


--
-- TOC entry 5603 (class 2606 OID 17388)
-- Name: stage_mobility stage_mobility_mobility_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_mobility
    ADD CONSTRAINT stage_mobility_mobility_key UNIQUE (mobility);


--
-- TOC entry 5605 (class 2606 OID 17390)
-- Name: stage_mobility stage_mobility_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_mobility
    ADD CONSTRAINT stage_mobility_pkey PRIMARY KEY (stage_mobility_id);


--
-- TOC entry 5607 (class 2606 OID 17392)
-- Name: stage_types stage_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_types
    ADD CONSTRAINT stage_types_pkey PRIMARY KEY (stage_type_id);


--
-- TOC entry 5609 (class 2606 OID 17394)
-- Name: stage_types stage_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_types
    ADD CONSTRAINT stage_types_type_key UNIQUE (type);


--
-- TOC entry 5611 (class 2606 OID 17396)
-- Name: stage_video stage_video_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video
    ADD CONSTRAINT stage_video_pkey PRIMARY KEY (stage_video_id);


--
-- TOC entry 5613 (class 2606 OID 17398)
-- Name: stage_video_set stage_video_set_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video_set
    ADD CONSTRAINT stage_video_set_pkey PRIMARY KEY (stage_id, stage_video_id);


--
-- TOC entry 5615 (class 2606 OID 17400)
-- Name: stages stages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_pkey PRIMARY KEY (stage_id);


--
-- TOC entry 5617 (class 2606 OID 17402)
-- Name: task_types task_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_types
    ADD CONSTRAINT task_types_pkey PRIMARY KEY (task_type_id);


--
-- TOC entry 5619 (class 2606 OID 17404)
-- Name: task_types task_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_types
    ADD CONSTRAINT task_types_type_key UNIQUE (type);


--
-- TOC entry 5624 (class 2606 OID 17406)
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (task_id);


--
-- TOC entry 5628 (class 2606 OID 17408)
-- Name: templates_finresources templates_finresources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_finresources
    ADD CONSTRAINT templates_finresources_pkey PRIMARY KEY (template_id, finresource_id);


--
-- TOC entry 5630 (class 2606 OID 17410)
-- Name: templates_functions templates_functions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_functions
    ADD CONSTRAINT templates_functions_pkey PRIMARY KEY (template_id, function_id);


--
-- TOC entry 5632 (class 2606 OID 17412)
-- Name: templates_matresources templates_matresources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_matresources
    ADD CONSTRAINT templates_matresources_pkey PRIMARY KEY (template_id, matresource_id);


--
-- TOC entry 5626 (class 2606 OID 17414)
-- Name: templates templates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_pkey PRIMARY KEY (template_id);


--
-- TOC entry 5634 (class 2606 OID 17416)
-- Name: templates_venues templates_venues_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_venues
    ADD CONSTRAINT templates_venues_pkey PRIMARY KEY (template_id, venue_id);


--
-- TOC entry 5636 (class 2606 OID 17418)
-- Name: theme_comments theme_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments
    ADD CONSTRAINT theme_comments_pkey PRIMARY KEY (theme_comment_id);


--
-- TOC entry 5638 (class 2606 OID 17420)
-- Name: theme_types theme_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_types
    ADD CONSTRAINT theme_types_pkey PRIMARY KEY (theme_type_id);


--
-- TOC entry 5640 (class 2606 OID 17422)
-- Name: theme_types theme_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_types
    ADD CONSTRAINT theme_types_type_key UNIQUE (type);


--
-- TOC entry 5642 (class 2606 OID 17424)
-- Name: themes themes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_pkey PRIMARY KEY (theme_id);


--
-- TOC entry 5644 (class 2606 OID 17426)
-- Name: venue_types venue_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_types
    ADD CONSTRAINT venue_types_pkey PRIMARY KEY (venue_type_id);


--
-- TOC entry 5646 (class 2606 OID 17428)
-- Name: venue_types venue_types_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venue_types
    ADD CONSTRAINT venue_types_type_key UNIQUE (type);


--
-- TOC entry 5669 (class 2606 OID 18453)
-- Name: venues_notes venues_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_notes
    ADD CONSTRAINT venues_notes_pkey PRIMARY KEY (note_id, venue_id);


--
-- TOC entry 5648 (class 2606 OID 17430)
-- Name: venues venues_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_pkey PRIMARY KEY (venue_id);


--
-- TOC entry 5650 (class 2606 OID 17432)
-- Name: venues_stages venues_stages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_stages
    ADD CONSTRAINT venues_stages_pkey PRIMARY KEY (venue_id, stage_id);


--
-- TOC entry 5661 (class 1259 OID 18413)
-- Name: favorites_entity_type_entity_id_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX favorites_entity_type_entity_id_idx ON public.favorites USING btree (entity_type, entity_id);


--
-- TOC entry 5426 (class 1259 OID 17433)
-- Name: idx_actors_account; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_account ON public.actors USING btree (account);


--
-- TOC entry 5427 (class 1259 OID 17434)
-- Name: idx_actors_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_created_at ON public.actors USING btree (created_at);


--
-- TOC entry 5428 (class 1259 OID 17435)
-- Name: idx_actors_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_deleted ON public.actors USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5434 (class 1259 OID 17436)
-- Name: idx_actors_directions_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_directions_actor ON public.actors_directions USING btree (actor_id);


--
-- TOC entry 5429 (class 1259 OID 17437)
-- Name: idx_actors_keywords_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_keywords_gin ON public.actors USING gin (keywords public.gin_trgm_ops);


--
-- TOC entry 5445 (class 1259 OID 17438)
-- Name: idx_actors_projects_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_projects_actor ON public.actors_projects USING btree (actor_id);


--
-- TOC entry 5446 (class 1259 OID 17439)
-- Name: idx_actors_projects_project; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_projects_project ON public.actors_projects USING btree (project_id);


--
-- TOC entry 5430 (class 1259 OID 17440)
-- Name: idx_actors_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_actors_type ON public.actors USING btree (actor_type_id);


--
-- TOC entry 5455 (class 1259 OID 17441)
-- Name: idx_directions_description_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_directions_description_gin ON public.directions USING gin (to_tsvector('russian'::regconfig, description));


--
-- TOC entry 5456 (class 1259 OID 17442)
-- Name: idx_directions_title_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_directions_title_gin ON public.directions USING gin (to_tsvector('russian'::regconfig, (title)::text));


--
-- TOC entry 5463 (class 1259 OID 17443)
-- Name: idx_events_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_date ON public.events USING btree (date);


--
-- TOC entry 5464 (class 1259 OID 17444)
-- Name: idx_events_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_deleted ON public.events USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5465 (class 1259 OID 17445)
-- Name: idx_events_title_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_title_gin ON public.events USING gin (to_tsvector('russian'::regconfig, (title)::text));


--
-- TOC entry 5466 (class 1259 OID 17446)
-- Name: idx_events_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_type ON public.events USING btree (event_type_id);


--
-- TOC entry 5493 (class 1259 OID 17447)
-- Name: idx_ideas_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ideas_actor ON public.ideas USING btree (actor_id);


--
-- TOC entry 5494 (class 1259 OID 17448)
-- Name: idx_ideas_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ideas_category ON public.ideas USING btree (idea_category_id);


--
-- TOC entry 5495 (class 1259 OID 17449)
-- Name: idx_ideas_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ideas_deleted ON public.ideas USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5496 (class 1259 OID 17450)
-- Name: idx_ideas_description_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ideas_description_gin ON public.ideas USING gin (to_tsvector('russian'::regconfig, full_description));


--
-- TOC entry 5497 (class 1259 OID 17451)
-- Name: idx_ideas_title_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ideas_title_gin ON public.ideas USING gin (to_tsvector('russian'::regconfig, (title)::text));


--
-- TOC entry 5520 (class 1259 OID 17452)
-- Name: idx_notifications_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_created ON public.notifications USING btree (created_at);


--
-- TOC entry 5521 (class 1259 OID 17453)
-- Name: idx_notifications_read; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_read ON public.notifications USING btree (is_read);


--
-- TOC entry 5522 (class 1259 OID 17454)
-- Name: idx_notifications_recipient; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_recipient ON public.notifications USING btree (recipient);


--
-- TOC entry 5529 (class 1259 OID 17455)
-- Name: idx_persons_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_persons_actor ON public.persons USING btree (actor_id);


--
-- TOC entry 5530 (class 1259 OID 17456)
-- Name: idx_persons_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_persons_deleted ON public.persons USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5531 (class 1259 OID 17457)
-- Name: idx_persons_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_persons_email ON public.persons USING btree (email);


--
-- TOC entry 5532 (class 1259 OID 17458)
-- Name: idx_persons_name_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_persons_name_gin ON public.persons USING gin (to_tsvector('russian'::regconfig, (((name)::text || ' '::text) || (last_name)::text)));


--
-- TOC entry 5533 (class 1259 OID 17459)
-- Name: idx_persons_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_persons_phone ON public.persons USING btree (phone_number);


--
-- TOC entry 5538 (class 1259 OID 17460)
-- Name: idx_project_actor_roles_actor; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_project_actor_roles_actor ON public.project_actor_roles USING btree (actor_id);


--
-- TOC entry 5539 (class 1259 OID 17461)
-- Name: idx_project_actor_roles_actor_project; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_project_actor_roles_actor_project ON public.project_actor_roles USING btree (actor_id, project_id);


--
-- TOC entry 5540 (class 1259 OID 17462)
-- Name: idx_project_actor_roles_project; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_project_actor_roles_project ON public.project_actor_roles USING btree (project_id);


--
-- TOC entry 5541 (class 1259 OID 17463)
-- Name: idx_project_actor_roles_role; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_project_actor_roles_role ON public.project_actor_roles USING btree (role_type);


--
-- TOC entry 5556 (class 1259 OID 17464)
-- Name: idx_projects_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_author ON public.projects USING btree (author_id);


--
-- TOC entry 5557 (class 1259 OID 17465)
-- Name: idx_projects_dates; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_dates ON public.projects USING btree (start_date, end_date);


--
-- TOC entry 5558 (class 1259 OID 17466)
-- Name: idx_projects_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_deleted ON public.projects USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5559 (class 1259 OID 17467)
-- Name: idx_projects_description_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_description_gin ON public.projects USING gin (to_tsvector('russian'::regconfig, description));


--
-- TOC entry 5568 (class 1259 OID 17468)
-- Name: idx_projects_directions_project; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_directions_project ON public.projects_directions USING btree (project_id);


--
-- TOC entry 5560 (class 1259 OID 17469)
-- Name: idx_projects_keywords_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_keywords_gin ON public.projects USING gin (keywords public.gin_trgm_ops);


--
-- TOC entry 5575 (class 1259 OID 17470)
-- Name: idx_projects_locations_project; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_locations_project ON public.projects_locations USING btree (project_id);


--
-- TOC entry 5561 (class 1259 OID 17471)
-- Name: idx_projects_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_status ON public.projects USING btree (project_status_id);


--
-- TOC entry 5562 (class 1259 OID 17472)
-- Name: idx_projects_title_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_title_gin ON public.projects USING gin (to_tsvector('russian'::regconfig, (title)::text));


--
-- TOC entry 5563 (class 1259 OID 17473)
-- Name: idx_projects_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_type ON public.projects USING btree (project_type_id);


--
-- TOC entry 5620 (class 1259 OID 17474)
-- Name: idx_tasks_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tasks_deleted ON public.tasks USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- TOC entry 5621 (class 1259 OID 17475)
-- Name: idx_tasks_due_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tasks_due_date ON public.tasks USING btree (due_date);


--
-- TOC entry 5622 (class 1259 OID 17476)
-- Name: idx_tasks_priority; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tasks_priority ON public.tasks USING btree (priority);


--
-- TOC entry 5431 (class 1259 OID 17477)
-- Name: unique_human_nickname; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX unique_human_nickname ON public.actors USING btree (nickname, actor_type_id) WHERE ((actor_type_id = 1) AND (nickname IS NOT NULL));


--
-- TOC entry 6007 (class 2618 OID 17172)
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
-- TOC entry 6008 (class 2618 OID 17176)
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
-- TOC entry 5852 (class 2620 OID 17481)
-- Name: persons check_persons_email_unique; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_persons_email_unique BEFORE INSERT OR UPDATE ON public.persons FOR EACH ROW EXECUTE FUNCTION public.check_unique_for_active_records();


--
-- TOC entry 5844 (class 2620 OID 18339)
-- Name: actors trg_validate_actor_type_integrity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validate_actor_type_integrity BEFORE INSERT OR UPDATE OF actor_type_id ON public.actors FOR EACH ROW EXECUTE FUNCTION public.validate_actor_integrity();


--
-- TOC entry 5846 (class 2620 OID 18354)
-- Name: communities trg_validate_community_integrity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validate_community_integrity BEFORE INSERT OR UPDATE ON public.communities FOR EACH ROW EXECUTE FUNCTION public.validate_actor_type_integrity();


--
-- TOC entry 5850 (class 2620 OID 18355)
-- Name: organizations trg_validate_organization_integrity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validate_organization_integrity BEFORE INSERT OR UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.validate_actor_type_integrity();


--
-- TOC entry 5853 (class 2620 OID 18353)
-- Name: persons trg_validate_person_integrity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validate_person_integrity BEFORE INSERT OR UPDATE ON public.persons FOR EACH ROW EXECUTE FUNCTION public.validate_actor_type_integrity();


--
-- TOC entry 5845 (class 2620 OID 17482)
-- Name: actors update_actors_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_actors_updated_at BEFORE UPDATE ON public.actors FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5847 (class 2620 OID 17483)
-- Name: communities update_communities_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_communities_updated_at BEFORE UPDATE ON public.communities FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5848 (class 2620 OID 17484)
-- Name: events update_events_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5849 (class 2620 OID 17485)
-- Name: ideas update_ideas_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_ideas_updated_at BEFORE UPDATE ON public.ideas FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5851 (class 2620 OID 17486)
-- Name: organizations update_organizations_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5854 (class 2620 OID 17487)
-- Name: persons update_persons_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_persons_updated_at BEFORE UPDATE ON public.persons FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5855 (class 2620 OID 17488)
-- Name: project_actor_roles update_project_actor_roles_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_project_actor_roles_updated_at BEFORE UPDATE ON public.project_actor_roles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5856 (class 2620 OID 17489)
-- Name: projects update_projects_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5857 (class 2620 OID 17490)
-- Name: tasks update_tasks_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5858 (class 2620 OID 17491)
-- Name: templates update_templates_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_templates_updated_at BEFORE UPDATE ON public.templates FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- TOC entry 5670 (class 2606 OID 17492)
-- Name: actor_credentials actor_credentials_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_credentials
    ADD CONSTRAINT actor_credentials_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5671 (class 2606 OID 17497)
-- Name: actor_current_statuses actor_current_statuses_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_current_statuses
    ADD CONSTRAINT actor_current_statuses_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id);


--
-- TOC entry 5672 (class 2606 OID 17502)
-- Name: actor_current_statuses actor_current_statuses_actor_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_current_statuses
    ADD CONSTRAINT actor_current_statuses_actor_status_id_fkey FOREIGN KEY (actor_status_id) REFERENCES public.actor_statuses(actor_status_id);


--
-- TOC entry 5673 (class 2606 OID 17507)
-- Name: actor_current_statuses actor_current_statuses_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_current_statuses
    ADD CONSTRAINT actor_current_statuses_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id);


--
-- TOC entry 5674 (class 2606 OID 17512)
-- Name: actor_current_statuses actor_current_statuses_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actor_current_statuses
    ADD CONSTRAINT actor_current_statuses_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id);


--
-- TOC entry 5675 (class 2606 OID 17517)
-- Name: actors actors_actor_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT actors_actor_type_id_fkey FOREIGN KEY (actor_type_id) REFERENCES public.actor_types(actor_type_id);


--
-- TOC entry 5676 (class 2606 OID 17522)
-- Name: actors actors_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT actors_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id);


--
-- TOC entry 5679 (class 2606 OID 17527)
-- Name: actors_directions actors_directions_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_directions
    ADD CONSTRAINT actors_directions_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5680 (class 2606 OID 17532)
-- Name: actors_directions actors_directions_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_directions
    ADD CONSTRAINT actors_directions_direction_id_fkey FOREIGN KEY (direction_id) REFERENCES public.directions(direction_id) ON DELETE CASCADE;


--
-- TOC entry 5681 (class 2606 OID 17537)
-- Name: actors_events actors_events_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_events
    ADD CONSTRAINT actors_events_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5682 (class 2606 OID 17542)
-- Name: actors_events actors_events_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_events
    ADD CONSTRAINT actors_events_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id) ON DELETE CASCADE;


--
-- TOC entry 5683 (class 2606 OID 17547)
-- Name: actors_locations actors_locations_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_locations
    ADD CONSTRAINT actors_locations_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5684 (class 2606 OID 17552)
-- Name: actors_locations actors_locations_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_locations
    ADD CONSTRAINT actors_locations_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id) ON DELETE CASCADE;


--
-- TOC entry 5685 (class 2606 OID 17557)
-- Name: actors_messages actors_messages_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_messages
    ADD CONSTRAINT actors_messages_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5686 (class 2606 OID 17562)
-- Name: actors_messages actors_messages_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_messages
    ADD CONSTRAINT actors_messages_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(message_id) ON DELETE CASCADE;


--
-- TOC entry 5687 (class 2606 OID 17567)
-- Name: actors_notes actors_notes_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_notes
    ADD CONSTRAINT actors_notes_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5688 (class 2606 OID 18442)
-- Name: actors_notes actors_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_notes
    ADD CONSTRAINT actors_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- TOC entry 5689 (class 2606 OID 17572)
-- Name: actors_notes actors_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_notes
    ADD CONSTRAINT actors_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- TOC entry 5690 (class 2606 OID 17577)
-- Name: actors_projects actors_projects_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_projects
    ADD CONSTRAINT actors_projects_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5691 (class 2606 OID 17582)
-- Name: actors_projects actors_projects_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_projects
    ADD CONSTRAINT actors_projects_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5692 (class 2606 OID 17587)
-- Name: actors_projects actors_projects_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_projects
    ADD CONSTRAINT actors_projects_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- TOC entry 5693 (class 2606 OID 17592)
-- Name: actors_projects actors_projects_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_projects
    ADD CONSTRAINT actors_projects_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5694 (class 2606 OID 17597)
-- Name: actors_tasks actors_tasks_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_tasks
    ADD CONSTRAINT actors_tasks_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5695 (class 2606 OID 17602)
-- Name: actors_tasks actors_tasks_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors_tasks
    ADD CONSTRAINT actors_tasks_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(task_id) ON DELETE CASCADE;


--
-- TOC entry 5677 (class 2606 OID 17607)
-- Name: actors actors_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT actors_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id);


--
-- TOC entry 5839 (class 2606 OID 18427)
-- Name: bookmarks bookmarks_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5840 (class 2606 OID 18432)
-- Name: bookmarks bookmarks_theme_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.themes(theme_id) ON DELETE CASCADE;


--
-- TOC entry 5696 (class 2606 OID 17612)
-- Name: communities communities_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5697 (class 2606 OID 17617)
-- Name: communities communities_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5698 (class 2606 OID 17622)
-- Name: communities communities_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id);


--
-- TOC entry 5699 (class 2606 OID 17627)
-- Name: communities communities_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5701 (class 2606 OID 17632)
-- Name: events events_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5702 (class 2606 OID 17637)
-- Name: events events_event_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_event_type_id_fkey FOREIGN KEY (event_type_id) REFERENCES public.event_types(event_type_id);


--
-- TOC entry 5704 (class 2606 OID 17642)
-- Name: events_notes events_notes_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events_notes
    ADD CONSTRAINT events_notes_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(event_id) ON DELETE CASCADE;


--
-- TOC entry 5705 (class 2606 OID 17647)
-- Name: events_notes events_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events_notes
    ADD CONSTRAINT events_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- TOC entry 5703 (class 2606 OID 17652)
-- Name: events events_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5838 (class 2606 OID 18408)
-- Name: favorites favorites_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5706 (class 2606 OID 17657)
-- Name: finresource_owners finresource_owners_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_owners
    ADD CONSTRAINT finresource_owners_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5707 (class 2606 OID 17662)
-- Name: finresource_owners finresource_owners_finresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_owners
    ADD CONSTRAINT finresource_owners_finresource_id_fkey FOREIGN KEY (finresource_id) REFERENCES public.finresources(finresource_id) ON DELETE CASCADE;


--
-- TOC entry 5708 (class 2606 OID 17667)
-- Name: finresources finresources_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources
    ADD CONSTRAINT finresources_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5709 (class 2606 OID 17672)
-- Name: finresources finresources_finresource_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources
    ADD CONSTRAINT finresources_finresource_type_id_fkey FOREIGN KEY (finresource_type_id) REFERENCES public.finresource_types(finresource_type_id);


--
-- TOC entry 5710 (class 2606 OID 17677)
-- Name: finresources finresources_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources
    ADD CONSTRAINT finresources_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5678 (class 2606 OID 18325)
-- Name: actors fk_actors_actor_types; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.actors
    ADD CONSTRAINT fk_actors_actor_types FOREIGN KEY (actor_type_id) REFERENCES public.actor_types(actor_type_id);


--
-- TOC entry 5700 (class 2606 OID 18315)
-- Name: communities fk_communities_actors; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT fk_communities_actors FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5744 (class 2606 OID 18320)
-- Name: organizations fk_organizations_actors; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT fk_organizations_actors FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5749 (class 2606 OID 18310)
-- Name: persons fk_persons_actors; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT fk_persons_actors FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5711 (class 2606 OID 17682)
-- Name: functions_directions functions_directions_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.functions_directions
    ADD CONSTRAINT functions_directions_direction_id_fkey FOREIGN KEY (direction_id) REFERENCES public.directions(direction_id) ON DELETE CASCADE;


--
-- TOC entry 5712 (class 2606 OID 17687)
-- Name: functions_directions functions_directions_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.functions_directions
    ADD CONSTRAINT functions_directions_function_id_fkey FOREIGN KEY (function_id) REFERENCES public.functions(function_id) ON DELETE CASCADE;


--
-- TOC entry 5713 (class 2606 OID 17692)
-- Name: group_tasks group_tasks_project_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_tasks
    ADD CONSTRAINT group_tasks_project_group_id_fkey FOREIGN KEY (project_group_id) REFERENCES public.project_groups(project_group_id) ON DELETE CASCADE;


--
-- TOC entry 5714 (class 2606 OID 17697)
-- Name: group_tasks group_tasks_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.group_tasks
    ADD CONSTRAINT group_tasks_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(task_id) ON DELETE CASCADE;


--
-- TOC entry 5715 (class 2606 OID 17702)
-- Name: ideas ideas_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5716 (class 2606 OID 17707)
-- Name: ideas ideas_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5720 (class 2606 OID 17712)
-- Name: ideas_directions ideas_directions_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_directions
    ADD CONSTRAINT ideas_directions_direction_id_fkey FOREIGN KEY (direction_id) REFERENCES public.directions(direction_id) ON DELETE CASCADE;


--
-- TOC entry 5721 (class 2606 OID 17717)
-- Name: ideas_directions ideas_directions_idea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_directions
    ADD CONSTRAINT ideas_directions_idea_id_fkey FOREIGN KEY (idea_id) REFERENCES public.ideas(idea_id) ON DELETE CASCADE;


--
-- TOC entry 5717 (class 2606 OID 17722)
-- Name: ideas ideas_idea_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_idea_category_id_fkey FOREIGN KEY (idea_category_id) REFERENCES public.idea_categories(idea_category_id);


--
-- TOC entry 5718 (class 2606 OID 17727)
-- Name: ideas ideas_idea_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_idea_type_id_fkey FOREIGN KEY (idea_type_id) REFERENCES public.idea_types(idea_type_id);


--
-- TOC entry 5722 (class 2606 OID 17732)
-- Name: ideas_notes ideas_notes_idea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_notes
    ADD CONSTRAINT ideas_notes_idea_id_fkey FOREIGN KEY (idea_id) REFERENCES public.ideas(idea_id) ON DELETE CASCADE;


--
-- TOC entry 5723 (class 2606 OID 17737)
-- Name: ideas_notes ideas_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_notes
    ADD CONSTRAINT ideas_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- TOC entry 5724 (class 2606 OID 17742)
-- Name: ideas_projects ideas_projects_idea_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_projects
    ADD CONSTRAINT ideas_projects_idea_id_fkey FOREIGN KEY (idea_id) REFERENCES public.ideas(idea_id) ON DELETE CASCADE;


--
-- TOC entry 5725 (class 2606 OID 17747)
-- Name: ideas_projects ideas_projects_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas_projects
    ADD CONSTRAINT ideas_projects_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- TOC entry 5719 (class 2606 OID 17752)
-- Name: ideas ideas_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas
    ADD CONSTRAINT ideas_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5726 (class 2606 OID 17757)
-- Name: local_events local_events_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_events
    ADD CONSTRAINT local_events_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5727 (class 2606 OID 17762)
-- Name: local_events local_events_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_events
    ADD CONSTRAINT local_events_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5728 (class 2606 OID 17767)
-- Name: matresource_owners matresource_owners_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_owners
    ADD CONSTRAINT matresource_owners_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5729 (class 2606 OID 17772)
-- Name: matresource_owners matresource_owners_matresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresource_owners
    ADD CONSTRAINT matresource_owners_matresource_id_fkey FOREIGN KEY (matresource_id) REFERENCES public.matresources(matresource_id) ON DELETE CASCADE;


--
-- TOC entry 5730 (class 2606 OID 17777)
-- Name: matresources matresources_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources
    ADD CONSTRAINT matresources_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5731 (class 2606 OID 17782)
-- Name: matresources matresources_matresource_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources
    ADD CONSTRAINT matresources_matresource_type_id_fkey FOREIGN KEY (matresource_type_id) REFERENCES public.matresource_types(matresource_type_id);


--
-- TOC entry 5733 (class 2606 OID 17787)
-- Name: matresources_notes matresources_notes_matresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources_notes
    ADD CONSTRAINT matresources_notes_matresource_id_fkey FOREIGN KEY (matresource_id) REFERENCES public.matresources(matresource_id) ON DELETE CASCADE;


--
-- TOC entry 5734 (class 2606 OID 17792)
-- Name: matresources_notes matresources_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources_notes
    ADD CONSTRAINT matresources_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- TOC entry 5732 (class 2606 OID 17797)
-- Name: matresources matresources_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matresources
    ADD CONSTRAINT matresources_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5735 (class 2606 OID 17802)
-- Name: messages messages_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5736 (class 2606 OID 17807)
-- Name: messages messages_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5737 (class 2606 OID 17812)
-- Name: messages messages_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5738 (class 2606 OID 17817)
-- Name: notes notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5739 (class 2606 OID 17822)
-- Name: notes notes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5740 (class 2606 OID 17827)
-- Name: notes notes_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5741 (class 2606 OID 17832)
-- Name: notifications notifications_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5742 (class 2606 OID 17837)
-- Name: notifications notifications_recipient_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_recipient_fkey FOREIGN KEY (recipient) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5743 (class 2606 OID 17842)
-- Name: notifications notifications_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5745 (class 2606 OID 17847)
-- Name: organizations organizations_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5746 (class 2606 OID 17852)
-- Name: organizations organizations_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5747 (class 2606 OID 17857)
-- Name: organizations organizations_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id);


--
-- TOC entry 5748 (class 2606 OID 17862)
-- Name: organizations organizations_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5750 (class 2606 OID 17867)
-- Name: persons persons_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5751 (class 2606 OID 17872)
-- Name: persons persons_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5752 (class 2606 OID 17877)
-- Name: persons persons_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id);


--
-- TOC entry 5753 (class 2606 OID 17882)
-- Name: persons persons_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons
    ADD CONSTRAINT persons_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5754 (class 2606 OID 17887)
-- Name: project_actor_roles project_actor_roles_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_actor_roles
    ADD CONSTRAINT project_actor_roles_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5755 (class 2606 OID 17892)
-- Name: project_actor_roles project_actor_roles_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_actor_roles
    ADD CONSTRAINT project_actor_roles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.actors(actor_id);


--
-- TOC entry 5756 (class 2606 OID 17897)
-- Name: project_actor_roles project_actor_roles_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_actor_roles
    ADD CONSTRAINT project_actor_roles_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- TOC entry 5757 (class 2606 OID 17902)
-- Name: project_groups project_groups_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_groups
    ADD CONSTRAINT project_groups_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5758 (class 2606 OID 17907)
-- Name: project_groups project_groups_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_groups
    ADD CONSTRAINT project_groups_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5759 (class 2606 OID 17912)
-- Name: project_groups project_groups_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_groups
    ADD CONSTRAINT project_groups_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- TOC entry 5760 (class 2606 OID 17917)
-- Name: project_groups project_groups_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_groups
    ADD CONSTRAINT project_groups_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5761 (class 2606 OID 17922)
-- Name: projects projects_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5762 (class 2606 OID 17927)
-- Name: projects projects_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5769 (class 2606 OID 17932)
-- Name: projects_directions projects_directions_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_directions
    ADD CONSTRAINT projects_directions_direction_id_fkey FOREIGN KEY (direction_id) REFERENCES public.directions(direction_id) ON DELETE CASCADE;


--
-- TOC entry 5770 (class 2606 OID 17937)
-- Name: projects_directions projects_directions_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_directions
    ADD CONSTRAINT projects_directions_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- TOC entry 5763 (class 2606 OID 17942)
-- Name: projects projects_director_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_director_id_fkey FOREIGN KEY (director_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5771 (class 2606 OID 17947)
-- Name: projects_functions projects_functions_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_functions
    ADD CONSTRAINT projects_functions_function_id_fkey FOREIGN KEY (function_id) REFERENCES public.functions(function_id) ON DELETE CASCADE;


--
-- TOC entry 5772 (class 2606 OID 17952)
-- Name: projects_functions projects_functions_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_functions
    ADD CONSTRAINT projects_functions_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- TOC entry 5773 (class 2606 OID 17957)
-- Name: projects_local_events projects_local_events_local_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_local_events
    ADD CONSTRAINT projects_local_events_local_event_id_fkey FOREIGN KEY (local_event_id) REFERENCES public.local_events(local_event_id) ON DELETE CASCADE;


--
-- TOC entry 5774 (class 2606 OID 17962)
-- Name: projects_local_events projects_local_events_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_local_events
    ADD CONSTRAINT projects_local_events_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- TOC entry 5775 (class 2606 OID 17967)
-- Name: projects_locations projects_locations_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_locations
    ADD CONSTRAINT projects_locations_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id) ON DELETE CASCADE;


--
-- TOC entry 5776 (class 2606 OID 17972)
-- Name: projects_locations projects_locations_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_locations
    ADD CONSTRAINT projects_locations_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- TOC entry 5777 (class 2606 OID 17977)
-- Name: projects_notes projects_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_notes
    ADD CONSTRAINT projects_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- TOC entry 5778 (class 2606 OID 17982)
-- Name: projects_notes projects_notes_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_notes
    ADD CONSTRAINT projects_notes_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- TOC entry 5764 (class 2606 OID 17987)
-- Name: projects projects_project_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_project_status_id_fkey FOREIGN KEY (project_status_id) REFERENCES public.project_statuses(project_status_id);


--
-- TOC entry 5765 (class 2606 OID 17992)
-- Name: projects projects_project_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_project_type_id_fkey FOREIGN KEY (project_type_id) REFERENCES public.project_types(project_type_id);


--
-- TOC entry 5766 (class 2606 OID 18437)
-- Name: projects projects_rating_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_rating_id_fkey FOREIGN KEY (rating_id) REFERENCES public.ratings(rating_id) ON DELETE SET NULL;


--
-- TOC entry 5779 (class 2606 OID 17997)
-- Name: projects_tasks projects_tasks_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_tasks
    ADD CONSTRAINT projects_tasks_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(project_id) ON DELETE CASCADE;


--
-- TOC entry 5780 (class 2606 OID 18002)
-- Name: projects_tasks projects_tasks_task_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects_tasks
    ADD CONSTRAINT projects_tasks_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.tasks(task_id) ON DELETE CASCADE;


--
-- TOC entry 5767 (class 2606 OID 18007)
-- Name: projects projects_tutor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_tutor_id_fkey FOREIGN KEY (tutor_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5768 (class 2606 OID 18012)
-- Name: projects projects_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5836 (class 2606 OID 18384)
-- Name: ratings ratings_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5837 (class 2606 OID 18389)
-- Name: ratings ratings_rating_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ratings
    ADD CONSTRAINT ratings_rating_type_id_fkey FOREIGN KEY (rating_type_id) REFERENCES public.rating_types(rating_type_id);


--
-- TOC entry 5781 (class 2606 OID 18017)
-- Name: services services_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5783 (class 2606 OID 18022)
-- Name: services_notes services_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_notes
    ADD CONSTRAINT services_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- TOC entry 5784 (class 2606 OID 18027)
-- Name: services_notes services_notes_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_notes
    ADD CONSTRAINT services_notes_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(service_id) ON DELETE CASCADE;


--
-- TOC entry 5782 (class 2606 OID 18032)
-- Name: services services_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5785 (class 2606 OID 18037)
-- Name: stage_audio stage_audio_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio
    ADD CONSTRAINT stage_audio_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5787 (class 2606 OID 18042)
-- Name: stage_audio_set stage_audio_set_stage_audio_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio_set
    ADD CONSTRAINT stage_audio_set_stage_audio_id_fkey FOREIGN KEY (stage_audio_id) REFERENCES public.stage_audio(stage_audio_id) ON DELETE CASCADE;


--
-- TOC entry 5788 (class 2606 OID 18047)
-- Name: stage_audio_set stage_audio_set_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio_set
    ADD CONSTRAINT stage_audio_set_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.stages(stage_id) ON DELETE CASCADE;


--
-- TOC entry 5786 (class 2606 OID 18052)
-- Name: stage_audio stage_audio_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_audio
    ADD CONSTRAINT stage_audio_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5789 (class 2606 OID 18057)
-- Name: stage_effects stage_effects_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects
    ADD CONSTRAINT stage_effects_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5791 (class 2606 OID 18062)
-- Name: stage_effects_set stage_effects_set_stage_effects_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects_set
    ADD CONSTRAINT stage_effects_set_stage_effects_id_fkey FOREIGN KEY (stage_effects_id) REFERENCES public.stage_effects(stage_effects_id) ON DELETE CASCADE;


--
-- TOC entry 5792 (class 2606 OID 18067)
-- Name: stage_effects_set stage_effects_set_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects_set
    ADD CONSTRAINT stage_effects_set_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.stages(stage_id) ON DELETE CASCADE;


--
-- TOC entry 5790 (class 2606 OID 18072)
-- Name: stage_effects stage_effects_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_effects
    ADD CONSTRAINT stage_effects_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5793 (class 2606 OID 18077)
-- Name: stage_light stage_light_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light
    ADD CONSTRAINT stage_light_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5795 (class 2606 OID 18082)
-- Name: stage_light_set stage_light_set_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light_set
    ADD CONSTRAINT stage_light_set_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.stages(stage_id) ON DELETE CASCADE;


--
-- TOC entry 5796 (class 2606 OID 18087)
-- Name: stage_light_set stage_light_set_stage_light_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light_set
    ADD CONSTRAINT stage_light_set_stage_light_id_fkey FOREIGN KEY (stage_light_id) REFERENCES public.stage_light(stage_light_id) ON DELETE CASCADE;


--
-- TOC entry 5794 (class 2606 OID 18092)
-- Name: stage_light stage_light_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_light
    ADD CONSTRAINT stage_light_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5797 (class 2606 OID 18097)
-- Name: stage_video stage_video_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video
    ADD CONSTRAINT stage_video_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5799 (class 2606 OID 18102)
-- Name: stage_video_set stage_video_set_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video_set
    ADD CONSTRAINT stage_video_set_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.stages(stage_id) ON DELETE CASCADE;


--
-- TOC entry 5800 (class 2606 OID 18107)
-- Name: stage_video_set stage_video_set_stage_video_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video_set
    ADD CONSTRAINT stage_video_set_stage_video_id_fkey FOREIGN KEY (stage_video_id) REFERENCES public.stage_video(stage_video_id) ON DELETE CASCADE;


--
-- TOC entry 5798 (class 2606 OID 18112)
-- Name: stage_video stage_video_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stage_video
    ADD CONSTRAINT stage_video_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5801 (class 2606 OID 18117)
-- Name: stages stages_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5802 (class 2606 OID 18122)
-- Name: stages stages_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id) ON DELETE SET NULL;


--
-- TOC entry 5803 (class 2606 OID 18127)
-- Name: stages stages_stage_architecture_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_stage_architecture_id_fkey FOREIGN KEY (stage_architecture_id) REFERENCES public.stage_architecture(stage_architecture_id);


--
-- TOC entry 5804 (class 2606 OID 18132)
-- Name: stages stages_stage_mobility_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_stage_mobility_id_fkey FOREIGN KEY (stage_mobility_id) REFERENCES public.stage_mobility(stage_mobility_id);


--
-- TOC entry 5805 (class 2606 OID 18137)
-- Name: stages stages_stage_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_stage_type_id_fkey FOREIGN KEY (stage_type_id) REFERENCES public.stage_types(stage_type_id);


--
-- TOC entry 5806 (class 2606 OID 18142)
-- Name: stages stages_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5807 (class 2606 OID 18147)
-- Name: tasks tasks_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5808 (class 2606 OID 18152)
-- Name: tasks tasks_task_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_task_type_id_fkey FOREIGN KEY (task_type_id) REFERENCES public.task_types(task_type_id);


--
-- TOC entry 5809 (class 2606 OID 18157)
-- Name: tasks tasks_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5810 (class 2606 OID 18162)
-- Name: templates templates_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5811 (class 2606 OID 18167)
-- Name: templates templates_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_direction_id_fkey FOREIGN KEY (direction_id) REFERENCES public.directions(direction_id) ON DELETE SET NULL;


--
-- TOC entry 5813 (class 2606 OID 18172)
-- Name: templates_finresources templates_finresources_finresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_finresources
    ADD CONSTRAINT templates_finresources_finresource_id_fkey FOREIGN KEY (finresource_id) REFERENCES public.finresources(finresource_id) ON DELETE CASCADE;


--
-- TOC entry 5814 (class 2606 OID 18177)
-- Name: templates_finresources templates_finresources_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_finresources
    ADD CONSTRAINT templates_finresources_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.templates(template_id) ON DELETE CASCADE;


--
-- TOC entry 5815 (class 2606 OID 18182)
-- Name: templates_functions templates_functions_function_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_functions
    ADD CONSTRAINT templates_functions_function_id_fkey FOREIGN KEY (function_id) REFERENCES public.functions(function_id) ON DELETE CASCADE;


--
-- TOC entry 5816 (class 2606 OID 18187)
-- Name: templates_functions templates_functions_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_functions
    ADD CONSTRAINT templates_functions_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.templates(template_id) ON DELETE CASCADE;


--
-- TOC entry 5817 (class 2606 OID 18192)
-- Name: templates_matresources templates_matresources_matresource_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_matresources
    ADD CONSTRAINT templates_matresources_matresource_id_fkey FOREIGN KEY (matresource_id) REFERENCES public.matresources(matresource_id) ON DELETE CASCADE;


--
-- TOC entry 5818 (class 2606 OID 18197)
-- Name: templates_matresources templates_matresources_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_matresources
    ADD CONSTRAINT templates_matresources_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.templates(template_id) ON DELETE CASCADE;


--
-- TOC entry 5812 (class 2606 OID 18202)
-- Name: templates templates_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates
    ADD CONSTRAINT templates_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5819 (class 2606 OID 18207)
-- Name: templates_venues templates_venues_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_venues
    ADD CONSTRAINT templates_venues_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.templates(template_id) ON DELETE CASCADE;


--
-- TOC entry 5820 (class 2606 OID 18212)
-- Name: templates_venues templates_venues_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates_venues
    ADD CONSTRAINT templates_venues_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(venue_id) ON DELETE CASCADE;


--
-- TOC entry 5821 (class 2606 OID 18217)
-- Name: theme_comments theme_comments_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments
    ADD CONSTRAINT theme_comments_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE CASCADE;


--
-- TOC entry 5822 (class 2606 OID 18222)
-- Name: theme_comments theme_comments_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments
    ADD CONSTRAINT theme_comments_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5823 (class 2606 OID 18227)
-- Name: theme_comments theme_comments_theme_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments
    ADD CONSTRAINT theme_comments_theme_id_fkey FOREIGN KEY (theme_id) REFERENCES public.themes(theme_id) ON DELETE CASCADE;


--
-- TOC entry 5824 (class 2606 OID 18232)
-- Name: theme_comments theme_comments_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments
    ADD CONSTRAINT theme_comments_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5825 (class 2606 OID 18237)
-- Name: themes themes_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5826 (class 2606 OID 18242)
-- Name: themes themes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5827 (class 2606 OID 18247)
-- Name: themes themes_theme_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_theme_type_id_fkey FOREIGN KEY (theme_type_id) REFERENCES public.theme_types(theme_type_id);


--
-- TOC entry 5828 (class 2606 OID 18252)
-- Name: themes themes_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5829 (class 2606 OID 18257)
-- Name: venues venues_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5830 (class 2606 OID 18262)
-- Name: venues venues_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5831 (class 2606 OID 18267)
-- Name: venues venues_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(location_id) ON DELETE SET NULL;


--
-- TOC entry 5841 (class 2606 OID 18464)
-- Name: venues_notes venues_notes_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_notes
    ADD CONSTRAINT venues_notes_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.actors(actor_id);


--
-- TOC entry 5842 (class 2606 OID 18454)
-- Name: venues_notes venues_notes_note_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_notes
    ADD CONSTRAINT venues_notes_note_id_fkey FOREIGN KEY (note_id) REFERENCES public.notes(note_id) ON DELETE CASCADE;


--
-- TOC entry 5843 (class 2606 OID 18459)
-- Name: venues_notes venues_notes_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_notes
    ADD CONSTRAINT venues_notes_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(venue_id) ON DELETE CASCADE;


--
-- TOC entry 5834 (class 2606 OID 18272)
-- Name: venues_stages venues_stages_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_stages
    ADD CONSTRAINT venues_stages_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.stages(stage_id) ON DELETE CASCADE;


--
-- TOC entry 5835 (class 2606 OID 18277)
-- Name: venues_stages venues_stages_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues_stages
    ADD CONSTRAINT venues_stages_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(venue_id) ON DELETE CASCADE;


--
-- TOC entry 5832 (class 2606 OID 18282)
-- Name: venues venues_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- TOC entry 5833 (class 2606 OID 18287)
-- Name: venues venues_venue_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_venue_type_id_fkey FOREIGN KEY (venue_type_id) REFERENCES public.venue_types(venue_type_id);


-- Completed on 2026-01-18 00:36:31

--
-- PostgreSQL database dump complete
--

\unrestrict ooBMadl75pESfvp88GNTibLAXSqQozCPcUT0dk4oAkCOvelcWP5dPomPVvIxZ0M

