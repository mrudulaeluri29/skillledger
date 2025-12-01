CREATE SCHEMA IF NOT EXISTS skillledger;
SET search_path = skillledger;

-- use pgcrypto for SHA-256 in the audit ledger
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Mentor
CREATE TABLE IF NOT EXISTS mentor (
  mentor_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name            VARCHAR(100) NOT NULL,
  email           VARCHAR(255) NOT NULL UNIQUE,
  password_hash   VARCHAR(255) NOT NULL,
  department      VARCHAR(100) NOT NULL,
  designation     VARCHAR(100),
  role            VARCHAR(20)  NOT NULL CHECK (role = 'MENTOR')
);

-- Administrator
CREATE TABLE IF NOT EXISTS administrator (
  admin_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name            VARCHAR(100) NOT NULL,
  email           VARCHAR(255) NOT NULL UNIQUE,
  password_hash   VARCHAR(255) NOT NULL,
  role            VARCHAR(20)  NOT NULL CHECK (role = 'ADMIN')
);

-- Student
CREATE TABLE IF NOT EXISTS student (
  student_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name            VARCHAR(100) NOT NULL,
  email           VARCHAR(255) NOT NULL UNIQUE,
  password_hash   VARCHAR(255) NOT NULL,
  major           VARCHAR(100) NOT NULL,
  year            INT NOT NULL CHECK (year BETWEEN 1 AND 6),
  department      VARCHAR(100) NOT NULL,
  role            VARCHAR(20)  NOT NULL CHECK (role = 'STUDENT'),
  mentor_id       INT NULL,
  CONSTRAINT fk_student_mentor
    FOREIGN KEY (mentor_id)
    REFERENCES mentor(mentor_id)
    ON DELETE SET NULL  
);

-- Skill
CREATE TABLE IF NOT EXISTS skill (
  skill_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  skill_name VARCHAR(100) NOT NULL UNIQUE,
  category   VARCHAR(50)  NOT NULL
);

-- StudentSkill (M:N)
CREATE TABLE IF NOT EXISTS student_skill (
  student_id         INT NOT NULL,
  skill_id           INT NOT NULL,
  proficiency_level  INT NOT NULL CHECK (proficiency_level BETWEEN 1 AND 5),
  PRIMARY KEY (student_id, skill_id),
  CONSTRAINT fk_ss_student FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE,
  CONSTRAINT fk_ss_skill   FOREIGN KEY (skill_id)   REFERENCES skill(skill_id)     ON DELETE CASCADE
);

-- Internship
CREATE TABLE IF NOT EXISTS internship (
  internship_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id     INT NOT NULL,
  organization   VARCHAR(150) NOT NULL,
  position       VARCHAR(150) NOT NULL,
  start_date     DATE NOT NULL,
  end_date       DATE NOT NULL CHECK (end_date >= start_date),
  description    TEXT,
  status         VARCHAR(20) NOT NULL CHECK (status IN ('Draft','Submitted','Verified','Rejected')),
  verified       BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT fk_internship_student
    FOREIGN KEY (student_id) REFERENCES student(student_id)
    ON DELETE CASCADE
);

-- Verification (1:1 with Internship via UNIQUE on internship_id)
CREATE TABLE IF NOT EXISTS verification (
  verification_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  internship_id   INT NOT NULL UNIQUE,
  mentor_id       INT NOT NULL,
  status          VARCHAR(20) NOT NULL CHECK (status IN ('Pending','Approved','Rejected')),
  rating          INT CHECK (rating BETWEEN 1 AND 5),
  comments        TEXT,
  verified_on     TIMESTAMP,
  CONSTRAINT fk_verif_internship FOREIGN KEY (internship_id) REFERENCES internship(internship_id) ON DELETE CASCADE,
  CONSTRAINT fk_verif_mentor     FOREIGN KEY (mentor_id)     REFERENCES mentor(mentor_id)         ON DELETE RESTRICT
);

-- Certificate (belongs to Internship)
CREATE TABLE IF NOT EXISTS certificate (
  certificate_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  internship_id    INT NOT NULL,
  file_link        VARCHAR(500) NOT NULL,
  issue_date       DATE NOT NULL,
  certificate_type VARCHAR(50),
  issuer           VARCHAR(150),
  CONSTRAINT fk_cert_internship
    FOREIGN KEY (internship_id) REFERENCES internship(internship_id)
    ON DELETE CASCADE
);

-- Verification Ledger (append-only, chained hashes)
CREATE TABLE IF NOT EXISTS verification_ledger (
  ledger_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  internship_id INT NOT NULL,
  mentor_id     INT NOT NULL,
  action        VARCHAR(50) NOT NULL CHECK (action IN ('APPROVE','REJECT','CERT_ATTACH')),
  hash_value    CHAR(64) NOT NULL,
  previous_hash CHAR(64),
  "timestamp"   TIMESTAMP NOT NULL,
  CONSTRAINT fk_vl_internship FOREIGN KEY (internship_id) REFERENCES internship(internship_id) ON DELETE CASCADE,
  CONSTRAINT fk_vl_mentor     FOREIGN KEY (mentor_id)     REFERENCES mentor(mentor_id)         ON DELETE RESTRICT
);

-- Company
CREATE TABLE IF NOT EXISTS company (
  company_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name           VARCHAR(150) NOT NULL UNIQUE,
  email          VARCHAR(255) NOT NULL UNIQUE,
  password_hash  VARCHAR(255) NOT NULL,
  industry       VARCHAR(100),
  verified_status VARCHAR(20) NOT NULL CHECK (verified_status IN ('Pending','Verified','Suspended'))
);

-- Internship Posting
CREATE TABLE IF NOT EXISTS internship_posting (
  posting_id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  company_id           INT NOT NULL,
  title                VARCHAR(150) NOT NULL,
  description          TEXT NOT NULL,
  location             VARCHAR(150),
  duration             VARCHAR(100),
  application_deadline DATE,
  is_active            BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT fk_post_company FOREIGN KEY (company_id) REFERENCES company(company_id) ON DELETE CASCADE
);

-- Application
CREATE TABLE IF NOT EXISTS application (
  application_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  posting_id     INT NOT NULL,
  student_id     INT NOT NULL,
  status         VARCHAR(20) NOT NULL CHECK (status IN ('Applied','UnderReview','Interview','Offer','Rejected','Withdrawn')),
  applied_on     TIMESTAMP NOT NULL,
  CONSTRAINT fk_app_posting FOREIGN KEY (posting_id) REFERENCES internship_posting(posting_id) ON DELETE CASCADE,
  CONSTRAINT fk_app_student FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE,
  CONSTRAINT uq_app_unique UNIQUE (posting_id, student_id)
);

-- Post (only for verified internships)
CREATE TABLE IF NOT EXISTS post (
  post_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  internship_id INT NOT NULL,
  student_id    INT NOT NULL,
  content       TEXT NOT NULL,
  visibility    VARCHAR(20) NOT NULL CHECK (visibility IN ('Public','Campus','Private')),
  created_at    TIMESTAMP NOT NULL,
  CONSTRAINT fk_post_internship FOREIGN KEY (internship_id) REFERENCES internship(internship_id) ON DELETE CASCADE,
  CONSTRAINT fk_post_student    FOREIGN KEY (student_id)    REFERENCES student(student_id)       ON DELETE CASCADE
);

-- Comment
CREATE TABLE IF NOT EXISTS comment (
  comment_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  post_id     INT NOT NULL,
  student_id  INT NOT NULL,
  text        TEXT NOT NULL,
  created_at  TIMESTAMP NOT NULL,
  CONSTRAINT fk_comment_post    FOREIGN KEY (post_id)    REFERENCES post(post_id)       ON DELETE CASCADE,
  CONSTRAINT fk_comment_student FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE
);

-- Like (composite PK)
CREATE TABLE IF NOT EXISTS "like" (
  post_id    INT NOT NULL,
  student_id INT NOT NULL,
  liked_on   TIMESTAMP NOT NULL,
  PRIMARY KEY (post_id, student_id),
  CONSTRAINT fk_like_post    FOREIGN KEY (post_id)    REFERENCES post(post_id)       ON DELETE CASCADE,
  CONSTRAINT fk_like_student FOREIGN KEY (student_id) REFERENCES student(student_id) ON DELETE CASCADE
);


-- Business rules (Triggers) 

-- 1) Sync Internship.status & verified based on Verification.status
CREATE OR REPLACE FUNCTION skillledger.trg_sync_internship_from_verification()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS t_sync_verification_aiud ON skillledger.verification;
CREATE TRIGGER t_sync_verification_aiud
AFTER INSERT OR UPDATE ON skillledger.verification
FOR EACH ROW
EXECUTE FUNCTION skillledger.trg_sync_internship_from_verification();

-- 2) Prevent Post insert/update unless Internship.verified = TRUE
CREATE OR REPLACE FUNCTION skillledger.trg_guard_post_on_verified_internship()
RETURNS TRIGGER AS $$
DECLARE
  v_verified BOOLEAN;
  v_student  INT;
BEGIN
  SELECT verified, student_id INTO v_verified, v_student
  FROM skillledger.internship WHERE internship_id = NEW.internship_id;

  IF NOT v_verified THEN
    RAISE EXCEPTION 'Cannot post: internship % is not verified', NEW.internship_id;
  END IF;

  -- Ensure post owner matches internship owner (Phase 1 note)
  IF v_student <> NEW.student_id THEN
    RAISE EXCEPTION 'Post student % must own internship %', NEW.student_id, NEW.internship_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS t_post_verified_bi ON skillledger.post;
CREATE TRIGGER t_post_verified_bi
BEFORE INSERT OR UPDATE ON skillledger.post
FOR EACH ROW
EXECUTE FUNCTION skillledger.trg_guard_post_on_verified_internship();

-- 3) Company verified gate for active postings (when inserting/updating InternshipPosting)
CREATE OR REPLACE FUNCTION skillledger.trg_company_verified_for_active_posting()
RETURNS TRIGGER AS $$
DECLARE
  v_status VARCHAR(20);
BEGIN
  IF (NEW.is_active IS TRUE) THEN
    SELECT verified_status INTO v_status FROM skillledger.company WHERE company_id = NEW.company_id;
    IF v_status <> 'Verified' THEN
      RAISE EXCEPTION 'Company % not verified. Active postings not allowed.', NEW.company_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS t_posting_company_chk_biud ON skillledger.internship_posting;
CREATE TRIGGER t_posting_company_chk_biud
BEFORE INSERT OR UPDATE ON skillledger.internship_posting
FOR EACH ROW
EXECUTE FUNCTION skillledger.trg_company_verified_for_active_posting();

-- 4) Verification Ledger: append-only + auto hash and previous_hash
CREATE OR REPLACE FUNCTION skillledger.trg_verification_ledger_hash()
RETURNS TRIGGER AS $$
DECLARE
  v_prev_hash CHAR(64);
BEGIN
  -- Append-only: block updates/deletes at table level via rule (below), here just in case
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'verification_ledger is append-only';
  END IF;

  -- Previous hash for same internship (most recent by timestamp)
  SELECT hash_value INTO v_prev_hash
  FROM skillledger.verification_ledger
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
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS t_vl_hash_bi ON skillledger.verification_ledger;
CREATE TRIGGER t_vl_hash_bi
BEFORE INSERT ON skillledger.verification_ledger
FOR EACH ROW
EXECUTE FUNCTION skillledger.trg_verification_ledger_hash();

-- Hard-block any UPDATE/DELETE attempts at SQL level
DROP RULE IF EXISTS r_vl_no_update ON skillledger.verification_ledger;
CREATE RULE r_vl_no_update AS ON UPDATE TO skillledger.verification_ledger DO INSTEAD NOTHING;

DROP RULE IF EXISTS r_vl_no_delete ON skillledger.verification_ledger;
CREATE RULE r_vl_no_delete AS ON DELETE TO skillledger.verification_ledger DO INSTEAD NOTHING;