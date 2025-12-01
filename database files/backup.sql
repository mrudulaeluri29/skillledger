--
-- PostgreSQL database dump
--

\restrict dHBgf6CcaxyyZTIPG6LELcgdSMCDdph40czwiq48X2RsElrYevrdhBmA14A6vuj

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.6

-- Started on 2025-12-01 15:30:10

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
-- TOC entry 7 (class 2615 OID 17020)
-- Name: skillledger; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA skillledger;


ALTER SCHEMA skillledger OWNER TO postgres;

--
-- TOC entry 2 (class 3079 OID 17021)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA skillledger;


--
-- TOC entry 5115 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 284 (class 1255 OID 17291)
-- Name: trg_company_verified_for_active_posting(); Type: FUNCTION; Schema: skillledger; Owner: postgres
--

CREATE FUNCTION skillledger.trg_company_verified_for_active_posting() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_status VARCHAR(20);
BEGIN
  IF (NEW.is_active IS TRUE) THEN
    SELECT verified_status INTO v_status FROM company WHERE company_id = NEW.company_id;
    IF v_status <> 'Verified' THEN
      RAISE EXCEPTION 'Company % not verified. Active postings not allowed.', NEW.company_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION skillledger.trg_company_verified_for_active_posting() OWNER TO postgres;

--
-- TOC entry 283 (class 1255 OID 17289)
-- Name: trg_guard_post_on_verified_internship(); Type: FUNCTION; Schema: skillledger; Owner: postgres
--

CREATE FUNCTION skillledger.trg_guard_post_on_verified_internship() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_verified BOOLEAN;
  v_student  INT;
BEGIN
  SELECT verified, student_id INTO v_verified, v_student
  FROM internship WHERE internship_id = NEW.internship_id;

  IF NOT v_verified THEN
    RAISE EXCEPTION 'Cannot post: internship % is not verified', NEW.internship_id;
  END IF;

  -- Ensure post owner matches internship owner (Phase 1 note)
  IF v_student <> NEW.student_id THEN
    RAISE EXCEPTION 'Post student % must own internship %', NEW.student_id, NEW.internship_id;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION skillledger.trg_guard_post_on_verified_internship() OWNER TO postgres;

--
-- TOC entry 297 (class 1255 OID 19873)
-- Name: trg_sync_internship_from_verification(); Type: FUNCTION; Schema: skillledger; Owner: postgres
--

CREATE FUNCTION skillledger.trg_sync_internship_from_verification() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.status = 'Approved' THEN
    UPDATE skillledger.internship
      SET status = 'Verified', verified = TRUE
      WHERE internship_id = NEW.internship_id;
    NEW.verified_on := COALESCE(NEW.verified_on, NOW());
  ELSIF NEW.status = 'Rejected' THEN
    UPDATE skillledger.internship
      SET status = 'Rejected', verified = FALSE
      WHERE internship_id = NEW.internship_id;
    NEW.verified_on := COALESCE(NEW.verified_on, NOW());
  ELSE
    UPDATE skillledger.internship
      SET status = 'Submitted', verified = FALSE
      WHERE internship_id = NEW.internship_id;
    NEW.verified_on := NULL;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION skillledger.trg_sync_internship_from_verification() OWNER TO postgres;

--
-- TOC entry 285 (class 1255 OID 17293)
-- Name: trg_verification_ledger_hash(); Type: FUNCTION; Schema: skillledger; Owner: postgres
--

CREATE FUNCTION skillledger.trg_verification_ledger_hash() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_prev_hash CHAR(64);
BEGIN
  -- Append-only: block updates/deletes at table level via rule (below), here just in case
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'verification_ledger is append-only';
  END IF;

  -- Previous hash for same internship (most recent by timestamp)
  SELECT hash_value INTO v_prev_hash
  FROM verification_ledger
  WHERE internship_id = NEW.internship_id
  ORDER BY "timestamp" DESC, ledger_id DESC
  LIMIT 1;

  NEW.previous_hash := v_prev_hash;

  -- Compute SHA-256 over canonical string
  NEW.hash_value := encode(
    digest(
      concat_ws('|',
        NEW.internship_id::text,
        NEW.mentor_id::text,
        NEW.action,
        COALESCE(TO_CHAR(NEW."timestamp", 'YYYY-MM-DD"T"HH24:MI:SS.MS'), '')
      ),
      'sha256'
    ),
    'hex'
  )::char(64);

  RETURN NEW;
END;
$$;


ALTER FUNCTION skillledger.trg_verification_ledger_hash() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 17070)
-- Name: administrator; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.administrator (
    admin_id integer NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(20) NOT NULL,
    CONSTRAINT administrator_role_check CHECK (((role)::text = 'ADMIN'::text))
);


ALTER TABLE skillledger.administrator OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 17069)
-- Name: administrator_admin_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.administrator ALTER COLUMN admin_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.administrator_admin_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 241 (class 1259 OID 17217)
-- Name: application; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.application (
    application_id integer NOT NULL,
    posting_id integer NOT NULL,
    student_id integer NOT NULL,
    status character varying(20) NOT NULL,
    applied_on timestamp without time zone NOT NULL,
    CONSTRAINT application_status_check CHECK (((status)::text = ANY ((ARRAY['Applied'::character varying, 'UnderReview'::character varying, 'Interview'::character varying, 'Offer'::character varying, 'Rejected'::character varying, 'Withdrawn'::character varying])::text[])))
);


ALTER TABLE skillledger.application OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 17216)
-- Name: application_application_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.application ALTER COLUMN application_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.application_application_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 233 (class 1259 OID 17160)
-- Name: certificate; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.certificate (
    certificate_id integer NOT NULL,
    internship_id integer NOT NULL,
    file_link character varying(500) NOT NULL,
    issue_date date NOT NULL,
    certificate_type character varying(50),
    issuer character varying(150)
);


ALTER TABLE skillledger.certificate OWNER TO postgres;

--
-- TOC entry 232 (class 1259 OID 17159)
-- Name: certificate_certificate_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.certificate ALTER COLUMN certificate_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.certificate_certificate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 245 (class 1259 OID 17255)
-- Name: comment; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.comment (
    comment_id integer NOT NULL,
    post_id integer NOT NULL,
    student_id integer NOT NULL,
    text text NOT NULL,
    created_at timestamp without time zone NOT NULL
);


ALTER TABLE skillledger.comment OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 17254)
-- Name: comment_comment_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.comment ALTER COLUMN comment_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.comment_comment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 237 (class 1259 OID 17190)
-- Name: company; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.company (
    company_id integer NOT NULL,
    name character varying(150) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    industry character varying(100),
    verified_status character varying(20) NOT NULL,
    CONSTRAINT company_verified_status_check CHECK (((verified_status)::text = ANY ((ARRAY['Pending'::character varying, 'Verified'::character varying, 'Suspended'::character varying])::text[])))
);


ALTER TABLE skillledger.company OWNER TO postgres;

--
-- TOC entry 236 (class 1259 OID 17189)
-- Name: company_company_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.company ALTER COLUMN company_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.company_company_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 229 (class 1259 OID 17122)
-- Name: internship; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.internship (
    internship_id integer NOT NULL,
    student_id integer NOT NULL,
    organization character varying(150) NOT NULL,
    "position" character varying(150) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    description text,
    status character varying(20) NOT NULL,
    verified boolean DEFAULT false NOT NULL,
    CONSTRAINT internship_check CHECK ((end_date >= start_date)),
    CONSTRAINT internship_status_check CHECK (((status)::text = ANY ((ARRAY['Draft'::character varying, 'Submitted'::character varying, 'Verified'::character varying, 'Rejected'::character varying])::text[])))
);


ALTER TABLE skillledger.internship OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 17121)
-- Name: internship_internship_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.internship ALTER COLUMN internship_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.internship_internship_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 239 (class 1259 OID 17203)
-- Name: internship_posting; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.internship_posting (
    posting_id integer NOT NULL,
    company_id integer NOT NULL,
    title character varying(150) NOT NULL,
    description text NOT NULL,
    location character varying(150),
    duration character varying(100),
    application_deadline date,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE skillledger.internship_posting OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 17202)
-- Name: internship_posting_posting_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.internship_posting ALTER COLUMN posting_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.internship_posting_posting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 246 (class 1259 OID 17272)
-- Name: like; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger."like" (
    post_id integer NOT NULL,
    student_id integer NOT NULL,
    liked_on timestamp without time zone NOT NULL
);


ALTER TABLE skillledger."like" OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 17059)
-- Name: mentor; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.mentor (
    mentor_id integer NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    department character varying(100) NOT NULL,
    designation character varying(100),
    role character varying(20) NOT NULL,
    CONSTRAINT mentor_role_check CHECK (((role)::text = 'MENTOR'::text))
);


ALTER TABLE skillledger.mentor OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 17058)
-- Name: mentor_mentor_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.mentor ALTER COLUMN mentor_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.mentor_mentor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 243 (class 1259 OID 17236)
-- Name: post; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.post (
    post_id integer NOT NULL,
    internship_id integer NOT NULL,
    student_id integer NOT NULL,
    content text NOT NULL,
    visibility character varying(20) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    CONSTRAINT post_visibility_check CHECK (((visibility)::text = ANY ((ARRAY['Public'::character varying, 'Campus'::character varying, 'Private'::character varying])::text[])))
);


ALTER TABLE skillledger.post OWNER TO postgres;

--
-- TOC entry 242 (class 1259 OID 17235)
-- Name: post_post_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.post ALTER COLUMN post_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.post_post_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 226 (class 1259 OID 17098)
-- Name: skill; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.skill (
    skill_id integer NOT NULL,
    skill_name character varying(100) NOT NULL,
    category character varying(50) NOT NULL
);


ALTER TABLE skillledger.skill OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 17097)
-- Name: skill_skill_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.skill ALTER COLUMN skill_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.skill_skill_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 224 (class 1259 OID 17081)
-- Name: student; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.student (
    student_id integer NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    major character varying(100) NOT NULL,
    year integer NOT NULL,
    department character varying(100) NOT NULL,
    role character varying(20) NOT NULL,
    mentor_id integer,
    CONSTRAINT student_role_check CHECK (((role)::text = 'STUDENT'::text)),
    CONSTRAINT student_year_check CHECK (((year >= 1) AND (year <= 6)))
);


ALTER TABLE skillledger.student OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 17105)
-- Name: student_skill; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.student_skill (
    student_id integer NOT NULL,
    skill_id integer NOT NULL,
    proficiency_level integer NOT NULL,
    CONSTRAINT student_skill_proficiency_level_check CHECK (((proficiency_level >= 1) AND (proficiency_level <= 5)))
);


ALTER TABLE skillledger.student_skill OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 17080)
-- Name: student_student_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.student ALTER COLUMN student_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.student_student_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 231 (class 1259 OID 17138)
-- Name: verification; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.verification (
    verification_id integer NOT NULL,
    internship_id integer NOT NULL,
    mentor_id integer NOT NULL,
    status character varying(20) NOT NULL,
    rating integer,
    comments text,
    verified_on timestamp without time zone,
    CONSTRAINT verification_rating_check CHECK (((rating >= 1) AND (rating <= 5))),
    CONSTRAINT verification_status_check CHECK (((status)::text = ANY ((ARRAY['Pending'::character varying, 'Approved'::character varying, 'Rejected'::character varying])::text[])))
);


ALTER TABLE skillledger.verification OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 17173)
-- Name: verification_ledger; Type: TABLE; Schema: skillledger; Owner: postgres
--

CREATE TABLE skillledger.verification_ledger (
    ledger_id integer NOT NULL,
    internship_id integer NOT NULL,
    mentor_id integer NOT NULL,
    action character varying(50) NOT NULL,
    hash_value character(64) NOT NULL,
    previous_hash character(64),
    "timestamp" timestamp without time zone NOT NULL,
    CONSTRAINT verification_ledger_action_check CHECK (((action)::text = ANY ((ARRAY['APPROVE'::character varying, 'REJECT'::character varying, 'CERT_ATTACH'::character varying])::text[])))
);


ALTER TABLE skillledger.verification_ledger OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 17172)
-- Name: verification_ledger_ledger_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.verification_ledger ALTER COLUMN ledger_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.verification_ledger_ledger_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 230 (class 1259 OID 17137)
-- Name: verification_verification_id_seq; Type: SEQUENCE; Schema: skillledger; Owner: postgres
--

ALTER TABLE skillledger.verification ALTER COLUMN verification_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME skillledger.verification_verification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 5085 (class 0 OID 17070)
-- Dependencies: 222
-- Data for Name: administrator; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.administrator (admin_id, name, email, password_hash, role) FROM stdin;
1	Admin Team	admin@skillledger.edu	hashAdmin	ADMIN
5	Admin User	admin@skillledger.com	scrypt:32768:8:1$WkcIIu9IjEiu3Mmk$4ed16a732e6a92400c7b36e7215130966d081dd681901ad5b53d045927711fd9ceec68e2a186db2a3bc454aa665ab564c8cc9ea67a5b03d320565f57c4999042	ADMIN
\.


--
-- TOC entry 5104 (class 0 OID 17217)
-- Dependencies: 241
-- Data for Name: application; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.application (application_id, posting_id, student_id, status, applied_on) FROM stdin;
1	5	1	Applied	2025-11-08 20:51:19.135319
2	11	1	UnderReview	2025-11-08 20:51:19.135319
3	3	1	UnderReview	2025-11-08 20:51:19.135319
4	6	1	Offer	2025-11-08 20:51:19.135319
5	2	1	Offer	2025-11-08 20:51:19.135319
6	4	1	Offer	2025-11-08 20:51:19.135319
7	7	1	Offer	2025-11-08 20:51:19.135319
8	1	1	Offer	2025-11-08 20:51:19.135319
9	10	1	Offer	2025-11-08 20:51:19.135319
10	8	1	Offer	2025-11-08 20:51:19.135319
11	9	1	Offer	2025-11-08 20:51:19.135319
12	12	1	Rejected	2025-11-08 20:51:19.135319
13	1	3	Applied	2025-11-08 22:23:33.741522
15	1	4	Applied	2025-11-09 12:12:56.861371
16	1	6	Applied	2025-11-09 12:21:38.289531
17	1	34	Applied	2025-12-01 04:44:31.103999
18	2	34	Applied	2025-12-01 04:49:15.380726
19	3	34	Applied	2025-12-01 04:51:50.406953
20	25	34	UnderReview	2025-12-01 05:28:24.951935
\.


--
-- TOC entry 5096 (class 0 OID 17160)
-- Dependencies: 233
-- Data for Name: certificate; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.certificate (certificate_id, internship_id, file_link, issue_date, certificate_type, issuer) FROM stdin;
1	1	https://files.example/cert_1.pdf	2025-11-08	Completion	HR - CloudForge
2	2	https://files.example/cert_2.pdf	2025-11-08	Completion	HR - CloudForge
3	3	https://files.example/cert_3.pdf	2025-11-08	Completion	HR - CloudForge
4	4	https://files.example/cert_4.pdf	2025-11-08	Completion	HR - CloudForge
5	5	https://files.example/cert_5.pdf	2025-11-08	Completion	HR - CloudForge
6	6	https://files.example/cert_6.pdf	2025-11-08	Completion	HR - CloudForge
7	7	https://files.example/cert_7.pdf	2025-11-08	Completion	HR - CloudForge
8	8	https://files.example/cert_8.pdf	2025-11-08	Completion	HR - CloudForge
9	21	https://example.com/certificate.pdf	2025-01-01	Completion Certificate	Amazon
10	22	https://example.com/certificate.pdf	2025-11-27	Completion Certificate	Microsoft
11	23	https://example.com/certificate.pdf	2025-07-22	Completion Certificate	Techsolutions
\.


--
-- TOC entry 5108 (class 0 OID 17255)
-- Dependencies: 245
-- Data for Name: comment; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.comment (comment_id, post_id, student_id, text, created_at) FROM stdin;
1	1	4	Congrats!	2025-11-08 21:01:13.970047
5	3	24	Great learning!	2025-11-08 21:01:13.970047
6	3	30	Nice work!	2025-11-08 21:01:13.970047
7	4	25	Congrats!	2025-11-08 21:01:13.970047
8	4	17	Great learning!	2025-11-08 21:01:13.970047
9	5	16	Congrats!	2025-11-08 21:01:13.970047
10	5	28	Nice work!	2025-11-08 21:01:13.970047
11	6	10	Nice work!	2025-11-08 21:01:13.970047
12	6	1	Congrats!	2025-11-08 21:01:13.970047
13	7	19	Great learning!	2025-11-08 21:01:13.970047
14	7	12	Great learning!	2025-11-08 21:01:13.970047
15	8	24	Great learning!	2025-11-08 21:01:13.970047
16	8	5	Nice work!	2025-11-08 21:01:13.970047
17	4	34	Amazing!	2025-12-01 05:09:01.554333
\.


--
-- TOC entry 5100 (class 0 OID 17190)
-- Dependencies: 237
-- Data for Name: company; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.company (company_id, name, email, password_hash, industry, verified_status) FROM stdin;
1	DataNest	hr@datanest.io	hashC1	Analytics	Verified
2	CloudForge	talent@cloudforge.dev	hashC2	Cloud	Verified
4	NeoRetail	jobs@neoretail.com	hashC4	E-commerce	Verified
5	HealthGrid	work@healthgrid.ai	hashC5	Healthcare	Verified
6	FlexLogix	team@flexlogix.io	hashC6	Logistics	Suspended
7	FinSight	hire@finsight.co	hashC7	FinTech	Verified
9	DemoWorks	hello@demoworks.io	hashDW	EdTech	Verified
10	TATA consultancy 	tata@gmail.com	scrypt:32768:8:1$TAqURmOHk8cVF6yQ$e9a612a09d86588c0a296f7b02dc2918ebdc7646a41489ab3bfd96687fdec40918b0f7eca2bf4f7c453484e603dab358f862bad6806aa4558708e18b3ccc6e1d	Technology and Finance 	Verified
3	GreenByte	careers@greenbyte.org	hashC3	Energy-Tech	Verified
8	AeroWorks	join@aeroworks.aero	hashC8	Aerospace	Verified
\.


--
-- TOC entry 5092 (class 0 OID 17122)
-- Dependencies: 229
-- Data for Name: internship; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.internship (internship_id, student_id, organization, "position", start_date, end_date, description, status, verified) FROM stdin;
14	14	CloudForge	ML Intern	2024-07-25	2024-08-21	Internship experience	Draft	f
15	5	CloudForge	ML Intern	2024-08-10	2024-11-02	Internship experience	Draft	f
16	26	CloudForge	ML Intern	2024-08-15	2024-09-17	Internship experience	Submitted	f
17	6	CloudForge	ML Intern	2024-08-09	2024-08-27	Internship experience	Draft	f
18	21	CloudForge	ML Intern	2024-05-22	2024-09-15	Internship experience	Submitted	f
19	18	CloudForge	BI Intern	2024-08-11	2024-09-25	Internship experience	Draft	f
20	15	CloudForge	BI Intern	2024-07-06	2024-11-22	Internship experience	Draft	f
1	12	CloudForge	Data Analyst	2024-06-21	2024-11-12	Internship experience	Verified	t
2	22	CloudForge	Data Analyst	2024-08-06	2024-10-10	Internship experience	Verified	t
3	16	CloudForge	Backend Dev	2024-06-16	2024-08-25	Internship experience	Verified	t
4	29	CloudForge	Backend Dev	2024-07-28	2024-10-11	Internship experience	Verified	t
5	8	CloudForge	Backend Dev	2024-07-04	2024-12-03	Internship experience	Verified	t
6	4	CloudForge	Backend Dev	2024-06-05	2024-09-22	Internship experience	Verified	t
7	24	CloudForge	Backend Dev	2024-06-21	2024-10-26	Internship experience	Verified	t
8	10	CloudForge	Backend Dev	2024-07-19	2024-09-14	Internship experience	Verified	t
12	1	CloudForge	ML Intern	2024-07-02	2024-10-04	Internship experience	Verified	t
9	19	CloudForge	Backend Dev	2024-06-01	2024-10-21	Internship experience	Verified	t
10	25	CloudForge	Backend Dev	2024-06-07	2024-09-04	Internship experience	Verified	t
11	27	CloudForge	Backend Dev	2024-08-02	2024-12-12	Internship experience	Verified	t
13	2	CloudForge	ML Intern	2024-08-03	2024-10-29	Internship experience	Verified	t
21	34	Amazon	Software engineering Intern	2024-06-06	2024-12-31	Worked on AWS Lambda serverless functions	Draft	t
22	34	Microsoft	AI engineer inter	2025-09-04	2025-11-25	trained AI models	Verified	t
23	34	Techsolutions	Creative Engineer	2024-12-01	2025-03-20	made some creative decisions	Submitted	f
\.


--
-- TOC entry 5102 (class 0 OID 17203)
-- Dependencies: 239
-- Data for Name: internship_posting; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.internship_posting (posting_id, company_id, title, description, location, duration, application_deadline, is_active) FROM stdin;
1	1	Data Analyst Intern	Dashboards & SQL	Phoenix, AZ	12 weeks	2025-04-15	t
2	1	ML Intern	Model prototypes	Remote	10 weeks	2025-05-01	t
3	2	Backend Intern	APIs & microservices	Remote	10 weeks	2025-04-25	t
4	2	SRE Intern	Infra & reliability	Seattle, WA	12 weeks	2025-05-05	t
5	4	BI Intern	Power BI & DAX	Tempe, AZ	8 weeks	2025-04-20	t
6	4	Data Eng Intern	Pipelines & Airflow	Tempe, AZ	12 weeks	2025-05-10	t
7	5	Health Data Intern	HL7/FHIR analytics	Remote	10 weeks	2025-04-30	t
8	5	NLP Intern	Clinical text mining	Boston, MA	12 weeks	2025-05-12	t
9	7	Fin Data Intern	Risk & pricing models	NYC, NY	12 weeks	2025-05-20	t
10	7	Quant Intern	Time-series research	NYC, NY	10 weeks	2025-05-18	t
11	3	Sustainability Analyst	Energy metrics	Tempe, AZ	12 weeks	2025-04-22	f
12	6	Logistics Analyst	Ops & routing	Dallas, TX	10 weeks	2025-04-28	f
13	1	Data Analyst Intern	Dashboards & SQL	Phoenix, AZ	12 weeks	2025-04-15	t
14	1	ML Intern	Model prototypes	Remote	10 weeks	2025-05-01	t
15	2	Backend Intern	APIs & microservices	Remote	10 weeks	2025-04-25	t
16	2	SRE Intern	Infra & reliability	Seattle, WA	12 weeks	2025-05-05	t
17	4	BI Intern	Power BI & DAX	Tempe, AZ	8 weeks	2025-04-20	t
18	4	Data Eng Intern	Pipelines & Airflow	Tempe, AZ	12 weeks	2025-05-10	t
19	5	Health Data Intern	HL7/FHIR analytics	Remote	10 weeks	2025-04-30	t
20	5	NLP Intern	Clinical text mining	Boston, MA	12 weeks	2025-05-12	t
21	7	Fin Data Intern	Risk & pricing models	NYC, NY	12 weeks	2025-05-20	t
22	7	Quant Intern	Time-series research	NYC, NY	10 weeks	2025-05-18	t
23	3	Sustainability Analyst	Energy metrics	Tempe, AZ	12 weeks	2025-04-22	f
24	6	Logistics Analyst	Ops & routing	Dallas, TX	10 weeks	2025-04-28	f
25	10	Data Science Intern 	Expectations: \r\nable to perform data cleaning and analysis	Remote 	Summer 2026	2025-12-25	t
\.


--
-- TOC entry 5109 (class 0 OID 17272)
-- Dependencies: 246
-- Data for Name: like; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger."like" (post_id, student_id, liked_on) FROM stdin;
1	28	2025-11-08 21:01:13.970047
1	9	2025-11-08 21:01:13.970047
2	6	2025-11-08 21:01:13.970047
2	17	2025-11-08 21:01:13.970047
3	5	2025-11-08 21:01:13.970047
3	22	2025-11-08 21:01:13.970047
4	20	2025-11-08 21:01:13.970047
4	18	2025-11-08 21:01:13.970047
5	7	2025-11-08 21:01:13.970047
5	24	2025-11-08 21:01:13.970047
6	12	2025-11-08 21:01:13.970047
6	8	2025-11-08 21:01:13.970047
7	25	2025-11-08 21:01:13.970047
7	14	2025-11-08 21:01:13.970047
8	24	2025-11-08 21:01:13.970047
8	12	2025-11-08 21:01:13.970047
4	34	2025-12-01 05:08:02.059498
\.


--
-- TOC entry 5083 (class 0 OID 17059)
-- Dependencies: 220
-- Data for Name: mentor; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.mentor (mentor_id, name, email, password_hash, department, designation, role) FROM stdin;
1	Mentor 1	mentor1@univ.edu	hash1	Information Systems	Associate Prof	MENTOR
2	Mentor 2	mentor2@univ.edu	hash2	Electrical Eng	Professor	MENTOR
3	Mentor 3	mentor3@univ.edu	hash3	Data Science	Assistant Prof	MENTOR
4	Mentor 4	mentor4@univ.edu	hash4	Computer Science	Associate Prof	MENTOR
5	Mentor 5	mentor5@univ.edu	hash5	Information Systems	Professor	MENTOR
6	Mentor 6	mentor6@univ.edu	hash6	Electrical Eng	Assistant Prof	MENTOR
7	Mentor 7	mentor7@univ.edu	hash7	Data Science	Associate Prof	MENTOR
8	Mentor 8	mentor8@univ.edu	hash8	Computer Science	Professor	MENTOR
9	Mentor 9	mentor9@univ.edu	hash9	Information Systems	Assistant Prof	MENTOR
10	Mentor 10	mentor10@univ.edu	hash10	Electrical Eng	Associate Prof	MENTOR
12	Dr. Smith	mentor@asu.edu	scrypt:32768:8:1$ASXLmg8vwp8nfKr5$2930f0e00e58950ee22ac748cc6d6bac4755fbef4032679259678d7467c4d74025031dd834e8b1ab0cdf0e03b64b97acb2c61e1b00ff5c7d8872bec4f3e21596	Computer Science	Associate Professor	MENTOR
13	mentor_asu	mentor16@asu.edu	scrypt:32768:8:1$JchTZJSFpPJBhPmU$45c01d3fdbb63ccea11dbbc0bd0666523b214302d452f2196382fae91e798d3c7001f9091ec57fc495b073af8b852387c35113735b7bd51cef189b470c228373	Ira fulton	Professor	MENTOR
\.


--
-- TOC entry 5106 (class 0 OID 17236)
-- Dependencies: 243
-- Data for Name: post; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.post (post_id, internship_id, student_id, content, visibility, created_at) FROM stdin;
1	1	12	Learned a lot on Data Analyst at CloudForge	Campus	2025-11-08 21:00:05.88867
2	2	22	Learned a lot on Data Analyst at CloudForge	Private	2025-11-08 21:00:05.88867
3	3	16	Learned a lot on Backend Dev at CloudForge	Campus	2025-11-08 21:00:05.88867
4	4	29	Learned a lot on Backend Dev at CloudForge	Public	2025-11-08 21:00:05.88867
5	5	8	Learned a lot on Backend Dev at CloudForge	Public	2025-11-08 21:00:05.88867
6	6	4	Learned a lot on Backend Dev at CloudForge	Public	2025-11-08 21:00:05.88867
7	7	24	Learned a lot on Backend Dev at CloudForge	Campus	2025-11-08 21:00:05.88867
8	8	10	Learned a lot on Backend Dev at CloudForge	Campus	2025-11-08 21:00:05.88867
9	21	34	I am proud to say that I have completed my internship at Amazon. Greatful for this experience. 	Public	2025-12-01 05:00:32.496859
\.


--
-- TOC entry 5089 (class 0 OID 17098)
-- Dependencies: 226
-- Data for Name: skill; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.skill (skill_id, skill_name, category) FROM stdin;
1	Python	Programming
2	Java	Programming
3	JavaScript	Programming
4	TypeScript	Programming
5	C	Programming
6	C++	Programming
7	C#	Programming
8	Go	Programming
9	Rust	Programming
10	Kotlin	Programming
11	Swift	Programming
12	R	Programming
13	Scala	Programming
14	PHP	Programming
15	Ruby	Programming
16	MATLAB	Programming
17	SQL	Programming
18	NoSQL	Programming
19	HTML	Programming
20	CSS	Programming
21	Bash	Programming
22	Pandas	Analytics
23	NumPy	Analytics
24	Scikit-learn	Analytics
25	TensorFlow	Analytics
26	PyTorch	Analytics
27	XGBoost	Analytics
28	Statistics	Analytics
29	Probability	Analytics
30	A/B Testing	Analytics
31	Time Series	Analytics
32	Regression	Analytics
33	Classification	Analytics
34	Clustering	Analytics
35	NLP	Analytics
36	Computer Vision	Analytics
37	Tableau	Analytics
38	Power BI	Analytics
39	Excel	Analytics
40	Data Modeling	Analytics
41	Data Visualization	Analytics
42	PostgreSQL	Data
43	MySQL	Data
44	SQLite	Data
45	MongoDB	Data
46	Snowflake	Data
47	Redshift	Data
48	BigQuery	Data
49	Hadoop	Data
50	Spark	Data
51	Kafka	Data
52	Airflow	Data
53	dbt	Data
54	Databricks	Data
55	Git	Tools
56	GitHub	Tools
57	GitLab	Tools
58	Jenkins	Tools
59	CI/CD	Tools
60	Docker	Tools
61	Kubernetes	Tools
62	Terraform	Tools
63	Ansible	Tools
64	Linux	Tools
65	REST APIs	Tools
66	GraphQL	Tools
67	Postman	Tools
68	AWS	Cloud
69	Azure	Cloud
70	GCP	Cloud
71	Microservices	Architecture
72	Event-Driven Design	Architecture
73	UML	Process
74	Agile	Process
75	Scrum	Process
76	Communication	Soft
77	Collaboration	Soft
78	Problem Solving	Soft
79	Leadership	Soft
80	Time Management	Soft
81	bash	Programming
82	data analysis	Data Science
\.


--
-- TOC entry 5087 (class 0 OID 17081)
-- Dependencies: 224
-- Data for Name: student; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.student (student_id, name, email, password_hash, major, year, department, role, mentor_id) FROM stdin;
1	Student 1	student1@asu.edu	hashS1	Computer Science	2	Fulton Engineering	STUDENT	2
2	Student 2	student2@asu.edu	hashS2	Information Systems	3	W. P. Carey	STUDENT	3
3	Student 3	student3@asu.edu	hashS3	Software Engineering	4	Fulton Engineering	STUDENT	4
4	Student 4	student4@asu.edu	hashS4	Supply Chain Mgmt	1	W. P. Carey	STUDENT	5
5	Student 5	student5@asu.edu	hashS5	Business Data Analytics	2	Fulton Engineering	STUDENT	\N
6	Student 6	student6@asu.edu	hashS6	Computer Science	3	W. P. Carey	STUDENT	7
7	Student 7	student7@asu.edu	hashS7	Information Systems	4	Fulton Engineering	STUDENT	8
8	Student 8	student8@asu.edu	hashS8	Software Engineering	1	W. P. Carey	STUDENT	9
9	Student 9	student9@asu.edu	hashS9	Supply Chain Mgmt	2	Fulton Engineering	STUDENT	10
10	Student 10	student10@asu.edu	hashS10	Business Data Analytics	3	W. P. Carey	STUDENT	\N
11	Student 11	student11@asu.edu	hashS11	Computer Science	4	Fulton Engineering	STUDENT	2
12	Student 12	student12@asu.edu	hashS12	Information Systems	1	W. P. Carey	STUDENT	3
13	Student 13	student13@asu.edu	hashS13	Software Engineering	2	Fulton Engineering	STUDENT	4
14	Student 14	student14@asu.edu	hashS14	Supply Chain Mgmt	3	W. P. Carey	STUDENT	5
15	Student 15	student15@asu.edu	hashS15	Business Data Analytics	4	Fulton Engineering	STUDENT	\N
16	Student 16	student16@asu.edu	hashS16	Computer Science	1	W. P. Carey	STUDENT	7
17	Student 17	student17@asu.edu	hashS17	Information Systems	2	Fulton Engineering	STUDENT	8
18	Student 18	student18@asu.edu	hashS18	Software Engineering	3	W. P. Carey	STUDENT	9
19	Student 19	student19@asu.edu	hashS19	Supply Chain Mgmt	4	Fulton Engineering	STUDENT	10
20	Student 20	student20@asu.edu	hashS20	Business Data Analytics	1	W. P. Carey	STUDENT	\N
21	Student 21	student21@asu.edu	hashS21	Computer Science	2	Fulton Engineering	STUDENT	2
22	Student 22	student22@asu.edu	hashS22	Information Systems	3	W. P. Carey	STUDENT	3
23	Student 23	student23@asu.edu	hashS23	Software Engineering	4	Fulton Engineering	STUDENT	4
24	Student 24	student24@asu.edu	hashS24	Supply Chain Mgmt	1	W. P. Carey	STUDENT	5
25	Student 25	student25@asu.edu	hashS25	Business Data Analytics	2	Fulton Engineering	STUDENT	\N
26	Student 26	student26@asu.edu	hashS26	Computer Science	3	W. P. Carey	STUDENT	7
27	Student 27	student27@asu.edu	hashS27	Information Systems	4	Fulton Engineering	STUDENT	8
28	Student 28	student28@asu.edu	hashS28	Software Engineering	1	W. P. Carey	STUDENT	9
29	Student 29	student29@asu.edu	hashS29	Supply Chain Mgmt	2	Fulton Engineering	STUDENT	10
33	Mrudula Eluri	mluri1@asu.edu	scrypt:32768:8:1$KKR0akaxUc2m73tK$5ca110f4e771a35ed3e07cc565c2ba38d1919f0920947f8bd1b1e869c3195b3eb9178ef71755b905e84526e2b1f136ca04217bceb9f6a79f11096438f6c0b92d	Computer Science	4	Ira fulton	STUDENT	\N
32	Mrudula Eluri	meluri1@asu.edu	scrypt:32768:8:1$yku5qrCxsdhkmp96$3cedc8e8a8df2a34f90c4e70d3eec9b3594ba158eae2d23e47d043ec86fe6874a9a058735f70051f5fc1f48d26b1cf0b45a74bb1ba78ebd3fc473ac79dc00f92	Computer Science	4	Ira fulton	STUDENT	13
34	Tanmai	tpotla@asu.edu	scrypt:32768:8:1$tpBg18aBqp5QriCA$b86432ace1a22ddd2cc1520c1626a144034fef97588525e75b3d4cebdb9b80c800da5c1899b9655c520a6d5bd1a6cab2031c1d62548c676e47c3dd0dd90fa998	Business	2	Ira fulton	STUDENT	13
31	bhavya vemareddy	919989017444@gmail.com	scrypt:32768:8:1$ETZ8aPS4IerNpgA5$7988657557208bcc969f6a1e03187b271a996d5da7c108ff41bc652ed4ca81b0242e0191513f46804bb681a9b55c233ae6523f18f29e70fe4ba6a24f2c8d2a3d	Computer Science	3	Ira fulton	STUDENT	8
30	Student 30	student30@asu.edu	hashS30	Business Data Analytics	3	W. P. Carey	STUDENT	7
\.


--
-- TOC entry 5090 (class 0 OID 17105)
-- Dependencies: 227
-- Data for Name: student_skill; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.student_skill (student_id, skill_id, proficiency_level) FROM stdin;
1	14	4
1	77	2
1	43	3
1	72	4
1	7	5
2	14	4
2	77	2
2	43	5
2	72	2
2	7	4
3	14	3
3	77	2
3	43	3
3	72	4
3	7	5
4	14	2
4	77	5
4	43	2
4	72	4
4	7	4
5	14	2
5	77	5
5	43	3
5	72	3
5	7	2
6	14	4
6	77	4
6	43	2
6	72	3
6	7	2
7	14	2
7	77	4
7	43	5
7	72	4
7	7	3
8	14	4
8	77	4
8	43	4
8	72	4
8	7	4
9	14	4
9	77	3
9	43	4
9	72	2
9	7	3
10	14	3
10	77	5
10	43	2
10	72	2
10	7	5
11	14	3
11	77	3
11	43	3
11	72	3
11	7	4
12	14	4
12	77	3
12	43	4
12	72	4
12	7	3
13	14	2
13	77	2
13	43	5
13	72	4
13	7	2
14	14	2
14	77	4
14	43	4
14	72	3
14	7	3
15	14	3
15	77	4
15	43	4
15	72	4
15	7	5
16	14	5
16	77	4
16	43	3
16	72	3
16	7	4
17	14	3
17	77	3
17	43	3
17	72	2
17	7	3
18	14	4
18	77	4
18	43	3
18	72	2
18	7	2
19	14	2
19	77	4
19	43	3
19	72	3
19	7	3
20	14	4
20	77	3
20	43	4
20	72	3
20	7	4
21	14	3
21	77	4
21	43	3
21	72	4
21	7	3
22	14	4
22	77	5
22	43	5
22	72	3
22	7	3
23	14	3
23	77	4
23	43	3
23	72	3
23	7	3
24	14	4
24	77	2
24	43	5
24	72	4
24	7	3
25	14	2
25	77	2
25	43	4
25	72	3
25	7	2
26	14	3
26	77	2
26	43	3
26	72	4
26	7	4
27	14	3
27	77	3
27	43	3
27	72	4
27	7	4
28	14	4
28	77	4
28	43	3
28	72	3
28	7	3
29	14	3
29	77	2
29	43	4
29	72	2
29	7	4
30	14	4
30	77	2
30	43	5
30	72	4
30	7	5
34	5	1
34	6	2
34	15	4
\.


--
-- TOC entry 5094 (class 0 OID 17138)
-- Dependencies: 231
-- Data for Name: verification; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.verification (verification_id, internship_id, mentor_id, status, rating, comments, verified_on) FROM stdin;
1	1	8	Approved	4	Good work	2025-11-08 20:56:01.809515
2	2	8	Approved	3	Good work	2025-11-08 20:56:01.809515
3	3	7	Approved	4	Good work	2025-11-08 20:56:01.809515
4	4	3	Approved	5	Good work	2025-11-08 20:56:01.809515
5	5	6	Approved	4	Good work	2025-11-08 20:56:01.809515
6	6	2	Approved	5	Good work	2025-11-08 20:56:01.809515
7	7	3	Approved	4	Good work	2025-11-08 20:56:01.809515
8	8	1	Approved	3	Good work	2025-11-08 20:56:01.809515
12	12	8	Approved	4	Insufficient evidence	2025-11-08 22:28:07.770111
9	9	6	Approved	4	Insufficient evidence	2025-11-08 22:29:45.698384
10	10	2	Approved	4	Insufficient evidence	2025-11-09 12:08:30.194781
11	11	4	Approved	4	Insufficient evidence	2025-11-09 12:10:22.451678
13	13	1	Approved	4	Insufficient evidence	2025-11-09 12:22:07.614885
14	22	12	Approved	4	good work!	2025-12-01 06:23:29.084751
18	23	13	Pending	\N	\N	\N
\.


--
-- TOC entry 5098 (class 0 OID 17173)
-- Dependencies: 235
-- Data for Name: verification_ledger; Type: TABLE DATA; Schema: skillledger; Owner: postgres
--

COPY skillledger.verification_ledger (ledger_id, internship_id, mentor_id, action, hash_value, previous_hash, "timestamp") FROM stdin;
1	1	8	APPROVE	43a738cd55ac7c8742d5943e08e27dadb4a8580d193e8c96007957091d92daa5	\N	2025-11-08 21:04:43.389142
2	2	8	APPROVE	4eadc915589711159a8f5a7ee9f29d77db13e77965e56e03fc5e655ce31c01b3	\N	2025-11-08 21:04:43.389142
3	3	7	APPROVE	22eccd9e810eb525ba5a5407ea2d7dce06a4f84127309ca8e6f8f69cf2468861	\N	2025-11-08 21:04:43.389142
4	4	3	APPROVE	f559f47f371b8befc317e44596d7f5cfe57c4b335439958ca0384a1eca88e165	\N	2025-11-08 21:04:43.389142
5	5	6	APPROVE	d0f8085f8e89320b6fd6a33ff67cdfe2bee78bb5703093a27e8cb80782c93322	\N	2025-11-08 21:04:43.389142
6	6	2	APPROVE	ad70b44ec0be0ede3d610700bce528c224a975c58e6d9cc5b881ba255573e458	\N	2025-11-08 21:04:43.389142
7	7	3	APPROVE	71f99324b14932a390d4b97370a3e5dddc98df59266887c8d611688e95525ac1	\N	2025-11-08 21:04:43.389142
8	8	1	APPROVE	df9f114963bce1b1baa7445cc6ffb7f8d4f3df82638b0d6436a83b4d409dce82	\N	2025-11-08 21:04:43.389142
9	9	6	REJECT	85a2a07fd73f8c51bbf98c357dccbb83e2b3664c6db592a45d3c8ba8eb0dcdff	\N	2025-11-08 21:04:43.389142
10	10	2	REJECT	412a6912e20233ed7f565384218235875b6c2aaa8785ddfd9ccc320daaa62490	\N	2025-11-08 21:04:43.389142
11	11	4	REJECT	fdfeecb573da209fcabd26754a1d88c29e34aef0108025ee1438c51b1578dd07	\N	2025-11-08 21:04:43.389142
12	12	8	REJECT	47495a2d7282dae6eeb40e33fd3885e03b557379b1e4b477475be417ec78cc22	\N	2025-11-08 21:04:43.389142
13	13	1	REJECT	903fcd3423da012e53d6eab1c18a17c3af38ee89edc9ad318d16d66417067020	\N	2025-11-08 21:04:43.389142
14	22	12	APPROVE	56984ea72be00e6b42b4f3d688f34a2702cc7bf1d879b74f33b76e50824c2559	\N	2025-12-01 06:23:29.095487
\.


--
-- TOC entry 5116 (class 0 OID 0)
-- Dependencies: 221
-- Name: administrator_admin_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.administrator_admin_id_seq', 5, true);


--
-- TOC entry 5117 (class 0 OID 0)
-- Dependencies: 240
-- Name: application_application_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.application_application_id_seq', 20, true);


--
-- TOC entry 5118 (class 0 OID 0)
-- Dependencies: 232
-- Name: certificate_certificate_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.certificate_certificate_id_seq', 11, true);


--
-- TOC entry 5119 (class 0 OID 0)
-- Dependencies: 244
-- Name: comment_comment_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.comment_comment_id_seq', 17, true);


--
-- TOC entry 5120 (class 0 OID 0)
-- Dependencies: 236
-- Name: company_company_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.company_company_id_seq', 10, true);


--
-- TOC entry 5121 (class 0 OID 0)
-- Dependencies: 228
-- Name: internship_internship_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.internship_internship_id_seq', 23, true);


--
-- TOC entry 5122 (class 0 OID 0)
-- Dependencies: 238
-- Name: internship_posting_posting_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.internship_posting_posting_id_seq', 25, true);


--
-- TOC entry 5123 (class 0 OID 0)
-- Dependencies: 219
-- Name: mentor_mentor_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.mentor_mentor_id_seq', 13, true);


--
-- TOC entry 5124 (class 0 OID 0)
-- Dependencies: 242
-- Name: post_post_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.post_post_id_seq', 9, true);


--
-- TOC entry 5125 (class 0 OID 0)
-- Dependencies: 225
-- Name: skill_skill_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.skill_skill_id_seq', 82, true);


--
-- TOC entry 5126 (class 0 OID 0)
-- Dependencies: 223
-- Name: student_student_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.student_student_id_seq', 34, true);


--
-- TOC entry 5127 (class 0 OID 0)
-- Dependencies: 234
-- Name: verification_ledger_ledger_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.verification_ledger_ledger_id_seq', 14, true);


--
-- TOC entry 5128 (class 0 OID 0)
-- Dependencies: 230
-- Name: verification_verification_id_seq; Type: SEQUENCE SET; Schema: skillledger; Owner: postgres
--

SELECT pg_catalog.setval('skillledger.verification_verification_id_seq', 18, true);


--
-- TOC entry 4872 (class 2606 OID 17079)
-- Name: administrator administrator_email_key; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.administrator
    ADD CONSTRAINT administrator_email_key UNIQUE (email);


--
-- TOC entry 4874 (class 2606 OID 17077)
-- Name: administrator administrator_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.administrator
    ADD CONSTRAINT administrator_pkey PRIMARY KEY (admin_id);


--
-- TOC entry 4904 (class 2606 OID 17222)
-- Name: application application_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.application
    ADD CONSTRAINT application_pkey PRIMARY KEY (application_id);


--
-- TOC entry 4892 (class 2606 OID 17166)
-- Name: certificate certificate_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.certificate
    ADD CONSTRAINT certificate_pkey PRIMARY KEY (certificate_id);


--
-- TOC entry 4910 (class 2606 OID 17261)
-- Name: comment comment_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.comment
    ADD CONSTRAINT comment_pkey PRIMARY KEY (comment_id);


--
-- TOC entry 4896 (class 2606 OID 17201)
-- Name: company company_email_key; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.company
    ADD CONSTRAINT company_email_key UNIQUE (email);


--
-- TOC entry 4898 (class 2606 OID 17199)
-- Name: company company_name_key; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.company
    ADD CONSTRAINT company_name_key UNIQUE (name);


--
-- TOC entry 4900 (class 2606 OID 17197)
-- Name: company company_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.company
    ADD CONSTRAINT company_pkey PRIMARY KEY (company_id);


--
-- TOC entry 4886 (class 2606 OID 17131)
-- Name: internship internship_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.internship
    ADD CONSTRAINT internship_pkey PRIMARY KEY (internship_id);


--
-- TOC entry 4902 (class 2606 OID 17210)
-- Name: internship_posting internship_posting_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.internship_posting
    ADD CONSTRAINT internship_posting_pkey PRIMARY KEY (posting_id);


--
-- TOC entry 4912 (class 2606 OID 17276)
-- Name: like like_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger."like"
    ADD CONSTRAINT like_pkey PRIMARY KEY (post_id, student_id);


--
-- TOC entry 4868 (class 2606 OID 17068)
-- Name: mentor mentor_email_key; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.mentor
    ADD CONSTRAINT mentor_email_key UNIQUE (email);


--
-- TOC entry 4870 (class 2606 OID 17066)
-- Name: mentor mentor_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.mentor
    ADD CONSTRAINT mentor_pkey PRIMARY KEY (mentor_id);


--
-- TOC entry 4908 (class 2606 OID 17243)
-- Name: post post_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.post
    ADD CONSTRAINT post_pkey PRIMARY KEY (post_id);


--
-- TOC entry 4880 (class 2606 OID 17102)
-- Name: skill skill_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.skill
    ADD CONSTRAINT skill_pkey PRIMARY KEY (skill_id);


--
-- TOC entry 4882 (class 2606 OID 17104)
-- Name: skill skill_skill_name_key; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.skill
    ADD CONSTRAINT skill_skill_name_key UNIQUE (skill_name);


--
-- TOC entry 4876 (class 2606 OID 17091)
-- Name: student student_email_key; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.student
    ADD CONSTRAINT student_email_key UNIQUE (email);


--
-- TOC entry 4878 (class 2606 OID 17089)
-- Name: student student_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.student
    ADD CONSTRAINT student_pkey PRIMARY KEY (student_id);


--
-- TOC entry 4884 (class 2606 OID 17110)
-- Name: student_skill student_skill_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.student_skill
    ADD CONSTRAINT student_skill_pkey PRIMARY KEY (student_id, skill_id);


--
-- TOC entry 4906 (class 2606 OID 17224)
-- Name: application uq_app_unique; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.application
    ADD CONSTRAINT uq_app_unique UNIQUE (posting_id, student_id);


--
-- TOC entry 4888 (class 2606 OID 17148)
-- Name: verification verification_internship_id_key; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.verification
    ADD CONSTRAINT verification_internship_id_key UNIQUE (internship_id);


--
-- TOC entry 4894 (class 2606 OID 17178)
-- Name: verification_ledger verification_ledger_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.verification_ledger
    ADD CONSTRAINT verification_ledger_pkey PRIMARY KEY (ledger_id);


--
-- TOC entry 4890 (class 2606 OID 17146)
-- Name: verification verification_pkey; Type: CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.verification
    ADD CONSTRAINT verification_pkey PRIMARY KEY (verification_id);


--
-- TOC entry 5081 (class 2618 OID 17296)
-- Name: verification_ledger r_vl_no_delete; Type: RULE; Schema: skillledger; Owner: postgres
--

CREATE RULE r_vl_no_delete AS
    ON DELETE TO skillledger.verification_ledger DO INSTEAD NOTHING;


--
-- TOC entry 5080 (class 2618 OID 17295)
-- Name: verification_ledger r_vl_no_update; Type: RULE; Schema: skillledger; Owner: postgres
--

CREATE RULE r_vl_no_update AS
    ON UPDATE TO skillledger.verification_ledger DO INSTEAD NOTHING;


--
-- TOC entry 4934 (class 2620 OID 17290)
-- Name: post t_post_verified_bi; Type: TRIGGER; Schema: skillledger; Owner: postgres
--

CREATE TRIGGER t_post_verified_bi BEFORE INSERT OR UPDATE ON skillledger.post FOR EACH ROW EXECUTE FUNCTION skillledger.trg_guard_post_on_verified_internship();


--
-- TOC entry 4933 (class 2620 OID 17292)
-- Name: internship_posting t_posting_company_chk_biud; Type: TRIGGER; Schema: skillledger; Owner: postgres
--

CREATE TRIGGER t_posting_company_chk_biud BEFORE INSERT OR UPDATE ON skillledger.internship_posting FOR EACH ROW EXECUTE FUNCTION skillledger.trg_company_verified_for_active_posting();


--
-- TOC entry 4931 (class 2620 OID 19874)
-- Name: verification t_sync_verification_aiud; Type: TRIGGER; Schema: skillledger; Owner: postgres
--

CREATE TRIGGER t_sync_verification_aiud AFTER INSERT OR UPDATE ON skillledger.verification FOR EACH ROW EXECUTE FUNCTION skillledger.trg_sync_internship_from_verification();


--
-- TOC entry 4932 (class 2620 OID 17294)
-- Name: verification_ledger t_vl_hash_bi; Type: TRIGGER; Schema: skillledger; Owner: postgres
--

CREATE TRIGGER t_vl_hash_bi BEFORE INSERT ON skillledger.verification_ledger FOR EACH ROW EXECUTE FUNCTION skillledger.trg_verification_ledger_hash();


--
-- TOC entry 4923 (class 2606 OID 17225)
-- Name: application fk_app_posting; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.application
    ADD CONSTRAINT fk_app_posting FOREIGN KEY (posting_id) REFERENCES skillledger.internship_posting(posting_id) ON DELETE CASCADE;


--
-- TOC entry 4924 (class 2606 OID 17230)
-- Name: application fk_app_student; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.application
    ADD CONSTRAINT fk_app_student FOREIGN KEY (student_id) REFERENCES skillledger.student(student_id) ON DELETE CASCADE;


--
-- TOC entry 4919 (class 2606 OID 17167)
-- Name: certificate fk_cert_internship; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.certificate
    ADD CONSTRAINT fk_cert_internship FOREIGN KEY (internship_id) REFERENCES skillledger.internship(internship_id) ON DELETE CASCADE;


--
-- TOC entry 4927 (class 2606 OID 17262)
-- Name: comment fk_comment_post; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.comment
    ADD CONSTRAINT fk_comment_post FOREIGN KEY (post_id) REFERENCES skillledger.post(post_id) ON DELETE CASCADE;


--
-- TOC entry 4928 (class 2606 OID 17267)
-- Name: comment fk_comment_student; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.comment
    ADD CONSTRAINT fk_comment_student FOREIGN KEY (student_id) REFERENCES skillledger.student(student_id) ON DELETE CASCADE;


--
-- TOC entry 4916 (class 2606 OID 17132)
-- Name: internship fk_internship_student; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.internship
    ADD CONSTRAINT fk_internship_student FOREIGN KEY (student_id) REFERENCES skillledger.student(student_id) ON DELETE CASCADE;


--
-- TOC entry 4929 (class 2606 OID 17277)
-- Name: like fk_like_post; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger."like"
    ADD CONSTRAINT fk_like_post FOREIGN KEY (post_id) REFERENCES skillledger.post(post_id) ON DELETE CASCADE;


--
-- TOC entry 4930 (class 2606 OID 17282)
-- Name: like fk_like_student; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger."like"
    ADD CONSTRAINT fk_like_student FOREIGN KEY (student_id) REFERENCES skillledger.student(student_id) ON DELETE CASCADE;


--
-- TOC entry 4922 (class 2606 OID 17211)
-- Name: internship_posting fk_post_company; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.internship_posting
    ADD CONSTRAINT fk_post_company FOREIGN KEY (company_id) REFERENCES skillledger.company(company_id) ON DELETE CASCADE;


--
-- TOC entry 4925 (class 2606 OID 17244)
-- Name: post fk_post_internship; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.post
    ADD CONSTRAINT fk_post_internship FOREIGN KEY (internship_id) REFERENCES skillledger.internship(internship_id) ON DELETE CASCADE;


--
-- TOC entry 4926 (class 2606 OID 17249)
-- Name: post fk_post_student; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.post
    ADD CONSTRAINT fk_post_student FOREIGN KEY (student_id) REFERENCES skillledger.student(student_id) ON DELETE CASCADE;


--
-- TOC entry 4914 (class 2606 OID 17116)
-- Name: student_skill fk_ss_skill; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.student_skill
    ADD CONSTRAINT fk_ss_skill FOREIGN KEY (skill_id) REFERENCES skillledger.skill(skill_id) ON DELETE CASCADE;


--
-- TOC entry 4915 (class 2606 OID 17111)
-- Name: student_skill fk_ss_student; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.student_skill
    ADD CONSTRAINT fk_ss_student FOREIGN KEY (student_id) REFERENCES skillledger.student(student_id) ON DELETE CASCADE;


--
-- TOC entry 4913 (class 2606 OID 17092)
-- Name: student fk_student_mentor; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.student
    ADD CONSTRAINT fk_student_mentor FOREIGN KEY (mentor_id) REFERENCES skillledger.mentor(mentor_id) ON DELETE SET NULL;


--
-- TOC entry 4917 (class 2606 OID 17149)
-- Name: verification fk_verif_internship; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.verification
    ADD CONSTRAINT fk_verif_internship FOREIGN KEY (internship_id) REFERENCES skillledger.internship(internship_id) ON DELETE CASCADE;


--
-- TOC entry 4918 (class 2606 OID 17154)
-- Name: verification fk_verif_mentor; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.verification
    ADD CONSTRAINT fk_verif_mentor FOREIGN KEY (mentor_id) REFERENCES skillledger.mentor(mentor_id) ON DELETE RESTRICT;


--
-- TOC entry 4920 (class 2606 OID 17179)
-- Name: verification_ledger fk_vl_internship; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.verification_ledger
    ADD CONSTRAINT fk_vl_internship FOREIGN KEY (internship_id) REFERENCES skillledger.internship(internship_id) ON DELETE CASCADE;


--
-- TOC entry 4921 (class 2606 OID 17184)
-- Name: verification_ledger fk_vl_mentor; Type: FK CONSTRAINT; Schema: skillledger; Owner: postgres
--

ALTER TABLE ONLY skillledger.verification_ledger
    ADD CONSTRAINT fk_vl_mentor FOREIGN KEY (mentor_id) REFERENCES skillledger.mentor(mentor_id) ON DELETE RESTRICT;


-- Completed on 2025-12-01 15:30:11

--
-- PostgreSQL database dump complete
--

\unrestrict dHBgf6CcaxyyZTIPG6LELcgdSMCDdph40czwiq48X2RsElrYevrdhBmA14A6vuj

