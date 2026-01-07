--
-- PostgreSQL database dump
--

\restrict qdbQqGL5GxgTf4XPivo01ar0rJQ8jhwCQhoHvpBxy00HJrzEoBpmzizBuxIC0h4

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
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


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

SET default_tablespace = '';

SET default_table_access_method = heap;

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
-- Name: actor_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.actor_types (
    actor_type_id integer NOT NULL,
    type character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.actor_types OWNER TO postgres;

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
    updated_by integer
);


ALTER TABLE public.actors OWNER TO postgres;

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
    actor_id integer NOT NULL
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
    event_id integer NOT NULL
);


ALTER TABLE public.events_notes OWNER TO postgres;

--
-- Name: finresource_owners; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.finresource_owners (
    finresource_id integer NOT NULL,
    actor_id integer NOT NULL
);


ALTER TABLE public.finresource_owners OWNER TO postgres;

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
    updated_by integer
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
    updated_by integer
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
    idea_id integer NOT NULL
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
    attachment character varying(255)
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
-- Name: matresource_owners; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.matresource_owners (
    matresource_id integer NOT NULL,
    actor_id integer NOT NULL
);


ALTER TABLE public.matresource_owners OWNER TO postgres;

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
    matresource_id integer NOT NULL
);


ALTER TABLE public.matresources_notes OWNER TO postgres;

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
    CONSTRAINT persons_gender_check CHECK (((gender)::text = ANY ((ARRAY['муж.'::character varying, 'жен.'::character varying])::text[])))
);


ALTER TABLE public.persons OWNER TO postgres;

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
-- Name: project_statuses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.project_statuses (
    project_status_id integer NOT NULL,
    status character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.project_statuses OWNER TO postgres;

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
    CONSTRAINT chk_project_dates CHECK ((start_date <= end_date))
);


ALTER TABLE public.projects OWNER TO postgres;

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
    project_id integer NOT NULL
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
-- Name: services_notes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.services_notes (
    note_id integer NOT NULL,
    service_id integer NOT NULL
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
    updated_by integer
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
-- Name: venue_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.venue_types (
    venue_type_id integer NOT NULL,
    type character varying(100) NOT NULL
);


ALTER TABLE public.venue_types OWNER TO postgres;

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
-- Name: communities community_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.communities ALTER COLUMN community_id SET DEFAULT nextval('public.communities_community_id_seq'::regclass);


--
-- Name: directions direction_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.directions ALTER COLUMN direction_id SET DEFAULT nextval('public.directions_direction_id_seq'::regclass);


--
-- Name: event_types event_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_types ALTER COLUMN event_type_id SET DEFAULT nextval('public.event_types_event_type_id_seq'::regclass);


--
-- Name: events event_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events ALTER COLUMN event_id SET DEFAULT nextval('public.events_event_id_seq'::regclass);


--
-- Name: finresource_types finresource_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresource_types ALTER COLUMN finresource_type_id SET DEFAULT nextval('public.finresource_types_finresource_type_id_seq'::regclass);


--
-- Name: finresources finresource_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources ALTER COLUMN finresource_id SET DEFAULT nextval('public.finresources_finresource_id_seq'::regclass);


--
-- Name: functions function_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.functions ALTER COLUMN function_id SET DEFAULT nextval('public.functions_function_id_seq'::regclass);


--
-- Name: idea_categories idea_category_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_categories ALTER COLUMN idea_category_id SET DEFAULT nextval('public.idea_categories_idea_category_id_seq'::regclass);


--
-- Name: idea_types idea_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.idea_types ALTER COLUMN idea_type_id SET DEFAULT nextval('public.idea_types_idea_type_id_seq'::regclass);


--
-- Name: ideas idea_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ideas ALTER COLUMN idea_id SET DEFAULT nextval('public.ideas_idea_id_seq'::regclass);


--
-- Name: local_events local_event_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.local_events ALTER COLUMN local_event_id SET DEFAULT nextval('public.local_events_local_event_id_seq'::regclass);


--
-- Name: locations location_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.locations ALTER COLUMN location_id SET DEFAULT nextval('public.locations_location_id_seq'::regclass);


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
-- Name: organizations organization_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizations ALTER COLUMN organization_id SET DEFAULT nextval('public.organizations_organization_id_seq'::regclass);


--
-- Name: persons person_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persons ALTER COLUMN person_id SET DEFAULT nextval('public.persons_person_id_seq'::regclass);


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
-- Name: services service_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services ALTER COLUMN service_id SET DEFAULT nextval('public.services_service_id_seq'::regclass);


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
-- Name: task_types task_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.task_types ALTER COLUMN task_type_id SET DEFAULT nextval('public.task_types_task_type_id_seq'::regclass);


--
-- Name: tasks task_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tasks ALTER COLUMN task_id SET DEFAULT nextval('public.tasks_task_id_seq'::regclass);


--
-- Name: templates template_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.templates ALTER COLUMN template_id SET DEFAULT nextval('public.templates_template_id_seq'::regclass);


--
-- Name: theme_comments theme_comment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments ALTER COLUMN theme_comment_id SET DEFAULT nextval('public.theme_comments_theme_comment_id_seq'::regclass);


--
-- Name: theme_types theme_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_types ALTER COLUMN theme_type_id SET DEFAULT nextval('public.theme_types_theme_type_id_seq'::regclass);


--
-- Name: themes theme_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.themes ALTER COLUMN theme_id SET DEFAULT nextval('public.themes_theme_id_seq'::regclass);


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
1	$2a$06$SOavCPazUFSP3dTdn57RdupbzbGjfzy.4qwJtcjDFzEdSknZU5NTS	2026-01-07 00:25:22.340005+08
3	$2a$06$t6mpTbIKed4dfSPvatmxseoQlCwq8PadsEVl10mxfmOZ0H4Bmyxde	2026-01-07 00:33:36.783392+08
4	$2a$06$/JNeBoIj9ovrD15IX54tweZ8z5wbCjC/DGOV4Rg.TI8C9dDdD.Xci	2026-01-07 00:35:06.117987+08
6	$2a$06$7myHR3svzsLaChZUG9pLp.CMM1g/fiPraXrU1DwKFSznXKppxqe7O	2026-01-07 00:55:30.892876+08
8	$2a$06$2k68VQEoAeVANy/I7F8mKuMJtI1oW7fLZ9hifCRgZsUucS2HuNcYu	2026-01-07 00:58:24.155874+08
\.


--
-- Data for Name: actor_current_statuses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actor_current_statuses (actor_current_status_id, actor_id, actor_status_id, created_at, updated_at, created_by, updated_by) FROM stdin;
1	3	7	2026-01-07 00:33:36.783392+08	2026-01-07 00:33:36.783392+08	1	1
2	4	7	2026-01-07 00:35:06.117987+08	2026-01-07 00:35:06.117987+08	1	1
4	6	7	2026-01-07 00:55:30.892876+08	2026-01-07 00:55:30.892876+08	1	1
5	8	7	2026-01-07 00:58:24.155874+08	2026-01-07 00:58:24.155874+08	1	1
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

COPY public.actors (actor_id, nickname, actor_type_id, icon, keywords, account, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
1	Администратор системы	1	\N	\N	000000000001	\N	2026-01-06 23:53:40.210239+08	2026-01-06 23:53:40.210239+08	1	1
3	НовыйПользователь	1	\N	\N	U00000000001	\N	2026-01-07 00:33:36.783392+08	2026-01-07 00:33:36.783392+08	1	1
4	ВторойЮзер	1	\N	\N	U00000000002	\N	2026-01-07 00:35:06.117987+08	2026-01-07 00:35:06.117987+08	1	1
6	УспешныйПользователь	1	\N	\N	U00000000003	\N	2026-01-07 00:55:30.892876+08	2026-01-07 00:55:30.892876+08	1	1
8	test	1	\N	\N	U00000000004	\N	2026-01-07 00:58:24.155874+08	2026-01-07 00:58:24.155874+08	1	1
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
1	1
3	1
1	2
3	2
\.


--
-- Data for Name: actors_locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_locations (actor_id, location_id) FROM stdin;
\.


--
-- Data for Name: actors_messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_messages (message_id, actor_id) FROM stdin;
\.


--
-- Data for Name: actors_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_notes (note_id, actor_id) FROM stdin;
\.


--
-- Data for Name: actors_projects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_projects (actor_id, project_id, created_at, updated_at, created_by, updated_by) FROM stdin;
1	1	2026-01-07 00:36:58.406222+08	2026-01-07 00:36:58.406222+08	1	1
\.


--
-- Data for Name: actors_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.actors_tasks (task_id, actor_id) FROM stdin;
1	3
\.


--
-- Data for Name: communities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.communities (community_id, title, full_title, email, email_2, participant_name, participant_lastname, location_id, post_code, address, phone_number, phone_number_2, bank_title, bank_bik, bank_account, community_info, vk_page, ok_page, tt_page, tg_page, ig_page, fb_page, max_page, web_page, attachment, actor_id, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
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

COPY public.events (event_id, title, description, date, start_time, end_time, event_type_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
1	Читка пьесы "Гамлет"	Первая читка сценария с актерами	2026-01-14	18:00:00	20:00:00	1	\N	\N	2026-01-07 00:38:38.62948+08	2026-01-07 00:38:38.62948+08	1	1
2	Открытая репетиция демо-проекта	Приглашаем всех желающих посмотреть на процесс создания арт-проекта	2026-01-14	19:00:00	21:00:00	1	\N	\N	2026-01-07 00:59:05.014783+08	2026-01-07 00:59:05.014783+08	1	1
\.


--
-- Data for Name: events_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.events_notes (note_id, event_id) FROM stdin;
\.


--
-- Data for Name: finresource_owners; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.finresource_owners (finresource_id, actor_id) FROM stdin;
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

COPY public.finresources (finresource_id, title, description, finresource_type_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
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
-- Data for Name: functions_directions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.functions_directions (function_id, direction_id) FROM stdin;
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
-- Data for Name: idea_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.idea_types (idea_type_id, type) FROM stdin;
1	Коммерческая
2	Некоммерческая
\.


--
-- Data for Name: ideas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ideas (idea_id, title, short_description, full_description, detail_description, idea_category_id, idea_type_id, actor_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
1	Идея документального фильма о театре	Документальный фильм о современном театральном искусстве	Полное описание идеи документального фильма, который расскажет о современных театральных постановках и актерах	\N	1	2	3	\N	\N	2026-01-07 00:46:46.360682+08	2026-01-07 00:46:46.360682+08	1	1
2	Идея для музыкального фестиваля	Организация летнего музыкального фестиваля под открытым небом	\N	\N	1	2	3	\N	2026-01-07 00:49:50.594317+08	2026-01-07 00:49:50.594317+08	2026-01-07 00:49:50.594317+08	1	1
\.


--
-- Data for Name: ideas_directions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ideas_directions (idea_id, direction_id) FROM stdin;
\.


--
-- Data for Name: ideas_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ideas_notes (note_id, idea_id) FROM stdin;
\.


--
-- Data for Name: ideas_projects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ideas_projects (idea_id, project_id) FROM stdin;
\.


--
-- Data for Name: local_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.local_events (local_event_id, title, description, date, start_time, end_time, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
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
-- Data for Name: matresource_owners; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresource_owners (matresource_id, actor_id) FROM stdin;
\.


--
-- Data for Name: matresource_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresource_types (matresource_type_id, category, sub_category, title) FROM stdin;
\.


--
-- Data for Name: matresources; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresources (matresource_id, title, description, matresource_type_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: matresources_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.matresources_notes (note_id, matresource_id) FROM stdin;
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
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notifications (notification_id, notification, recipient, is_read, created_at, updated_at, created_by, updated_by) FROM stdin;
1	У вас новая задача: "Подготовить сценарий для читки"	3	f	2026-01-07 00:53:42.30984+08	2026-01-07 00:53:42.30984+08	1	1
\.


--
-- Data for Name: organizations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.organizations (organization_id, title, full_title, email, email_2, staff_name, staff_lastname, location_id, post_code, address, phone_number, phone_number_2, dir_name, dir_lastname, ogrn, inn, kpp, bank_title, bank_bik, bank_account, org_info, vk_page, ok_page, tt_page, tg_page, ig_page, fb_page, max_page, web_page, attachment, actor_id, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: persons; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.persons (person_id, name, patronymic, last_name, gender, birth_date, email, email_2, location_id, post_code, address, phone_number, phone_number_2, personal_info, web_page, whatsapp, viber, vk_page, ok_page, tt_page, tg_page, ig_page, fb_page, max_page, pp_number, pp_date, pp_auth, inn, snils, bank_bik, bank_account, bank_info, ya_account, wm_account, pp_account, qiwi_account, attachment, actor_id, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
1	Иван	\N	Иванов	\N	\N	admin@example.com	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	1	\N	2026-01-06 23:53:40.210239+08	2026-01-06 23:53:40.210239+08	1	1
2	Сергей	\N	Сергеев	\N	\N	newuser@example.com	\N	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	3	\N	2026-01-07 00:33:36.783392+08	2026-01-07 00:33:36.783392+08	1	1
3	Андрей	\N	Андреев	\N	\N	seconduser@example.com	\N	2	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	4	\N	2026-01-07 00:35:06.117987+08	2026-01-07 00:35:06.117987+08	1	1
5	Успех	\N	Тестовый	\N	\N	success_user@example.com	\N	2	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	6	\N	2026-01-07 00:55:30.892876+08	2026-01-07 00:55:30.892876+08	1	1
7	test	\N	test	\N	\N	test_final@test.com	\N	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	8	\N	2026-01-07 00:58:24.155874+08	2026-01-07 00:58:24.155874+08	1	1
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

COPY public.projects (project_id, title, full_title, description, author_id, director_id, tutor_id, project_status_id, start_date, end_date, project_type_id, account, keywords, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
2	Театральная постановка "Гамлет"	\N	Современная интерпретация классической пьесы Шекспира	3	\N	\N	1	\N	\N	2	\N	\N	\N	\N	2026-01-07 00:36:28.559383+08	2026-01-07 00:36:28.559383+08	1	1
3	Кинофестиваль "Новое кино"	\N	Ежегодный фестиваль независимого кино с участием молодых режиссеров	3	\N	\N	1	\N	\N	2	\N	\N	\N	\N	2026-01-07 00:46:46.360682+08	2026-01-07 00:46:46.360682+08	1	1
4	Фотовыставка "Городские пейзажи"	\N	Выставка фотографий городской архитектуры и жизни	3	\N	\N	4	\N	\N	2	\N	\N	\N	\N	2026-01-07 00:50:58.999395+08	2026-01-07 00:50:58.999395+08	1	1
1	Театральный фестиваль	Международный театральный фестиваль современного искусства	Организация и проведение ежегодного театрального фестиваля	1	\N	\N	4	2025-12-28	2026-01-27	2	000000000001	\N	\N	\N	2026-01-06 23:53:40.210239+08	2026-01-07 00:51:10.056171+08	1	1
5	Демонстрационный арт-проект	\N	Мультидисциплинарный проект, объединяющий театр, музыку и визуальное искусство	3	\N	\N	4	2025-12-08	2026-03-08	2	\N	\N	\N	\N	2026-01-07 00:59:05.014783+08	2026-01-07 00:59:05.014783+08	1	1
\.


--
-- Data for Name: projects_directions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_directions (project_id, direction_id) FROM stdin;
1	1
5	1
5	9
\.


--
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

COPY public.projects_notes (note_id, project_id) FROM stdin;
\.


--
-- Data for Name: projects_tasks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects_tasks (task_id, project_id) FROM stdin;
1	1
\.


--
-- Data for Name: services; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services (service_id, title, description, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: services_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.services_notes (note_id, service_id) FROM stdin;
\.


--
-- Data for Name: stage_architecture; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_architecture (stage_architecture_id, architecture) FROM stdin;
1	просцениум (сцена коробка)
2	амфитеатр (открытая сцена)
3	трансформирующаяся сцена
4	Black box (закрытый "черный ящик")
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
1	Стационарная
2	Выездная (мобильная)
3	Пространственная
\.


--
-- Data for Name: stage_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stage_types (stage_type_id, type) FROM stdin;
1	театральная
2	концертная
3	многофункциональная
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

COPY public.stages (stage_id, title, full_title, stage_type_id, stage_architecture_id, stage_mobility_id, capacity, width, depth, height, description, location_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
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
1	Подготовить сценарий для читки	1	2026-01-10	3	\N	2026-01-07 00:52:59.278201+08	2026-01-07 00:52:59.278201+08	1	1
\.


--
-- Data for Name: templates; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates (template_id, title, description, direction_id, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
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
-- Data for Name: templates_venues; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.templates_venues (template_id, venue_id) FROM stdin;
\.


--
-- Data for Name: theme_comments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.theme_comments (theme_comment_id, comment, theme_id, actor_id, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: theme_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.theme_types (theme_type_id, type) FROM stdin;
1	Публичная
2	Проектная
\.


--
-- Data for Name: themes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.themes (theme_id, title, description, theme_type_id, actor_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: venue_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venue_types (venue_type_id, type) FROM stdin;
1	сценическая площадка
2	офис
3	зал
4	помещение
\.


--
-- Data for Name: venues; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venues (venue_id, title, full_title, venue_type_id, description, actor_id, location_id, attachment, deleted_at, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: venues_stages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.venues_stages (venue_id, stage_id) FROM stdin;
\.


--
-- Name: actor_current_statuses_actor_current_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.actor_current_statuses_actor_current_status_id_seq', 5, true);


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

SELECT pg_catalog.setval('public.actors_actor_id_seq', 8, true);


--
-- Name: communities_community_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.communities_community_id_seq', 1, false);


--
-- Name: directions_direction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.directions_direction_id_seq', 1, false);


--
-- Name: event_types_event_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.event_types_event_type_id_seq', 1, false);


--
-- Name: events_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.events_event_id_seq', 2, true);


--
-- Name: finresource_types_finresource_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.finresource_types_finresource_type_id_seq', 1, false);


--
-- Name: finresources_finresource_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.finresources_finresource_id_seq', 1, false);


--
-- Name: functions_function_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.functions_function_id_seq', 1, false);


--
-- Name: idea_categories_idea_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.idea_categories_idea_category_id_seq', 1, false);


--
-- Name: idea_types_idea_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.idea_types_idea_type_id_seq', 1, false);


--
-- Name: ideas_idea_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ideas_idea_id_seq', 2, true);


--
-- Name: local_events_local_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.local_events_local_event_id_seq', 1, false);


--
-- Name: locations_location_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.locations_location_id_seq', 1, false);


--
-- Name: matresource_types_matresource_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.matresource_types_matresource_type_id_seq', 1, false);


--
-- Name: matresources_matresource_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.matresources_matresource_id_seq', 1, false);


--
-- Name: messages_message_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.messages_message_id_seq', 1, false);


--
-- Name: notes_note_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notes_note_id_seq', 1, false);


--
-- Name: notifications_notification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notifications_notification_id_seq', 1, true);


--
-- Name: organizations_organization_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.organizations_organization_id_seq', 1, false);


--
-- Name: persons_person_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.persons_person_id_seq', 7, true);


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

SELECT pg_catalog.setval('public.projects_project_id_seq', 5, true);


--
-- Name: services_service_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.services_service_id_seq', 1, false);


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
-- Name: task_types_task_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.task_types_task_type_id_seq', 1, false);


--
-- Name: tasks_task_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tasks_task_id_seq', 1, true);


--
-- Name: templates_template_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.templates_template_id_seq', 1, false);


--
-- Name: theme_comments_theme_comment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.theme_comments_theme_comment_id_seq', 1, false);


--
-- Name: theme_types_theme_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.theme_types_theme_type_id_seq', 1, false);


--
-- Name: themes_theme_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.themes_theme_id_seq', 1, false);


--
-- Name: venue_types_venue_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.venue_types_venue_type_id_seq', 1, false);


--
-- Name: venues_venue_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.venues_venue_id_seq', 1, false);


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
-- Name: directions directions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.directions
    ADD CONSTRAINT directions_pkey PRIMARY KEY (direction_id);


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
-- Name: services_notes services_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services_notes
    ADD CONSTRAINT services_notes_pkey PRIMARY KEY (note_id, service_id);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (service_id);


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
-- Name: theme_comments theme_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.theme_comments
    ADD CONSTRAINT theme_comments_pkey PRIMARY KEY (theme_comment_id);


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
-- Name: idx_directions_description_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_directions_description_gin ON public.directions USING gin (to_tsvector('russian'::regconfig, description));


--
-- Name: idx_directions_title_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_directions_title_gin ON public.directions USING gin (to_tsvector('russian'::regconfig, (title)::text));


--
-- Name: idx_events_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_date ON public.events USING btree (date);


--
-- Name: idx_events_deleted; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_deleted ON public.events USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- Name: idx_events_title_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_title_gin ON public.events USING gin (to_tsvector('russian'::regconfig, (title)::text));


--
-- Name: idx_events_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_type ON public.events USING btree (event_type_id);


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
-- Name: idx_ideas_title_gin; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ideas_title_gin ON public.ideas USING gin (to_tsvector('russian'::regconfig, (title)::text));


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
-- Name: idx_projects_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_projects_author ON public.projects USING btree (author_id);


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
-- Name: unique_human_nickname; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX unique_human_nickname ON public.actors USING btree (nickname, actor_type_id) WHERE ((actor_type_id = 1) AND (nickname IS NOT NULL));


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
-- Name: events events_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


--
-- Name: events events_event_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_event_type_id_fkey FOREIGN KEY (event_type_id) REFERENCES public.event_types(event_type_id);


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
-- Name: events events_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


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
-- Name: finresources finresources_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.finresources
    ADD CONSTRAINT finresources_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


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
-- Name: services services_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.actors(actor_id) ON DELETE SET NULL;


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

\unrestrict qdbQqGL5GxgTf4XPivo01ar0rJQ8jhwCQhoHvpBxy00HJrzEoBpmzizBuxIC0h4

