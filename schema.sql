CREATE DATABASE IF NOT EXISTS college_db;
USE college_db;

--  ───────────────────── TABLES ─────────────────────────
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    'password' VARCHAR(255) NOT NULL,
    role ENUM('student','instructor','admin') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE departments (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    'name' VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE students (
    student_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNIQUE,
   'name' VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    department_id INT,
    CONSTRAINT chk_student_email CHECK (email LIKE '%_@_%._%'),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE SET NULL
);
CREATE TABLE instructors (
    instructor_id INT AUTO_INCREMENT PRIMARY KEY, user_id INT UNIQUE,
    name VARCHAR(100) NOT NULL, email VARCHAR(100) UNIQUE, department_id INT,
    CONSTRAINT chk_instructor_email CHECK (email LIKE '%_@_%._%'),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE SET NULL
);


CREATE TABLE courses (
    course_id INT AUTO_INCREMENT PRIMARY KEY, title VARCHAR(100) NOT NULL,
    credits INT NOT NULL, department_id INT,
    CONSTRAINT chk_credits CHECK (credits BETWEEN 1 AND 3),
    FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE SET NULL
);
CREATE TABLE prerequisites (
    course_id INT, prerequisite_id INT, PRIMARY KEY (course_id, prerequisite_id),
    CONSTRAINT chk_no_self_prereq CHECK (course_id <> prerequisite_id),-- <> means not equal
    FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE,
    FOREIGN KEY (prerequisite_id) REFERENCES courses(course_id) ON DELETE CASCADE
);
CREATE TABLE course_offerings (
    offering_id INT AUTO_INCREMENT PRIMARY KEY, course_id INT NOT NULL,
    instructor_id INT,
    semester ENUM('Spring','Summer','Fall') NOT NULL,
    'year' INT NOT NULL,
    CONSTRAINT chk_offering_year CHECK (year BETWEEN 2000 AND 2100),
    CONSTRAINT uq_offering UNIQUE (course_id, instructor_id, semester, 'year'),
    FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE,
    FOREIGN KEY (instructor_id) REFERENCES instructors(instructor_id) ON DELETE SET NULL
);
CREATE TABLE classrooms (
    room_id INT AUTO_INCREMENT PRIMARY KEY, building VARCHAR(100) NOT NULL, capacity INT NOT NULL,
    CONSTRAINT chk_capacity CHECK (capacity > 0), CONSTRAINT chk_building CHECK (TRIM(building) <> '')
);
CREATE TABLE schedules (
    schedule_id INT AUTO_INCREMENT PRIMARY KEY, offering_id INT, room_id INT,
    `day` ENUM('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'), `time` TIME,
    CONSTRAINT uq_room_slot UNIQUE (room_id, `day`, `time`),
    FOREIGN KEY (offering_id) REFERENCES course_offerings(offering_id) ON DELETE CASCADE,
    FOREIGN KEY (room_id) REFERENCES classrooms(room_id) ON DELETE SET NULL
);
CREATE TABLE enrollments (
    enrollment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL, offering_id INT NOT NULL,
    UNIQUE (student_id, offering_id),
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (offering_id) REFERENCES course_offerings(offering_id) ON DELETE CASCADE
);
CREATE TABLE grades (
    grade_id INT AUTO_INCREMENT PRIMARY KEY, enrollment_id INT UNIQUE,
    letter_grade ENUM('A','A-','B+','B','B-','C+','C','D','F'), grade_points DECIMAL(3,2),
    CONSTRAINT chk_grade_points CHECK (grade_points BETWEEN 0.00 AND 4.00),
    FOREIGN KEY (enrollment_id) REFERENCES enrollments(enrollment_id) ON DELETE CASCADE
);
CREATE TABLE attendance (
    attendance_id INT AUTO_INCREMENT PRIMARY KEY,
     enrollment_id INT,
     'date' DATE,
    'status' ENUM('Present','Absent','Late'),
    CONSTRAINT uq_attendance_record UNIQUE (enrollment_id, 'date'),
    FOREIGN KEY (enrollment_id) REFERENCES enrollments(enrollment_id) ON DELETE CASCADE
);
CREATE TABLE tuition (
    tuition_id INT AUTO_INCREMENT PRIMARY KEY, student_id INT,
    semester ENUM('Spring','Summer','Fall'), year INT, amount DECIMAL(10,2),
    status ENUM('Pending','Paid') DEFAULT 'Pending',
    CONSTRAINT chk_tuition_amount CHECK (amount > 0),
    CONSTRAINT chk_tuition_year   CHECK (year BETWEEN 2000 AND 2100),
    CONSTRAINT uq_student_term    UNIQUE (student_id, semester, year),
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
);
CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY, tuition_id INT,
    amount DECIMAL(10,2), payment_date DATE, method ENUM('Cash','Card','Online'),
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    FOREIGN KEY (tuition_id) REFERENCES tuition(tuition_id) ON DELETE CASCADE
);
CREATE TABLE enrollment_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    enrollment_id INT,
    student_id INT, offering_id INT,
    deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ── INDEXES ──────────────────────────────────────────────────
CREATE INDEX idx_users_username        ON users            (username);
CREATE INDEX idx_students_email        ON students         (email);
CREATE INDEX idx_students_dept         ON students         (department_id);
CREATE INDEX idx_instructors_email     ON instructors      (email);
CREATE INDEX idx_instructors_dept      ON instructors      (department_id);
CREATE INDEX idx_courses_dept          ON courses          (department_id);
CREATE INDEX idx_prereq_course         ON prerequisites    (course_id);
CREATE INDEX idx_prereq_prereq         ON prerequisites    (prerequisite_id);
CREATE INDEX idx_offerings_semester    ON course_offerings (semester, 'year');
CREATE INDEX idx_offerings_course      ON course_offerings (course_id);
CREATE INDEX idx_offerings_instructor  ON course_offerings (instructor_id);
CREATE INDEX idx_schedule_room_day     ON schedules        (room_id, 'day');
CREATE INDEX idx_schedule_offering     ON schedules        (offering_id);
CREATE INDEX idx_enrollments_student   ON enrollments      (student_id);
CREATE INDEX idx_enrollments_offering  ON enrollments      (offering_id);
CREATE INDEX idx_attendance_date       ON attendance       ('date');
CREATE INDEX idx_attendance_enrollment ON attendance       (enrollment_id);
CREATE INDEX idx_tuition_student       ON tuition          (student_id);
CREATE INDEX idx_tuition_status        ON tuition          ('status');
CREATE INDEX idx_payments_tuition      ON payments         (tuition_id);
CREATE INDEX idx_payments_date         ON payments         (payment_date);

-- ------------- VIEWS -----------------------

CREATE OR REPLACE VIEW student_gpa AS
SELECT s.student_id,s.name,
    ROUND(SUM(g.grade_points * c.credits)/SUM(c.credits), 2)
FROM students s
join enrollments e on e.student_id= s.student_id
join grades g on g.enrollment_id =e.enrollment_id
JOIN course_offerings o ON o.offering_id = e.offering_id
JOIN courses c ON c.course_id = o.course_id
GROUP BY s.student_id, s.name;



CREATE OR REPLACE VIEW vw_student_attendance AS
SELECT s.student_id, s.name, COUNT(*) AS total_sessions,
    SUM(a.status='Present') AS present, SUM(a.status='Absent') AS absent, SUM(a.status='Late') AS late,
    ROUND(100.0 * SUM(a.status='Present' OR a.status='Late') / COUNT(*), 2) AS attendance_pct
FROM students s
JOIN enrollments e ON e.student_id = s.student_id
JOIN attendance a ON a.enrollment_id = e.enrollment_id
GROUP BY s.student_id, s.name;

-- --------------------- stored procedures ---------------------------------------
-- 1. Enroll a student in a course offering
--    - Prevents duplicate enrollment
--    - Returns a status message

DELIMITER $$

CREATE PROCEDURE EnrollStudent(
    IN p_student_id INT ,
    IN p_offering_id INT ,
    OUT p_message VARCHAR(100)
)
BEGIN
    IF EXISTS(
        SELECT 1 FROM enrollments
        WHERE student_id=p_student_id AND offering_id=p_offering_id
    )
    THEN
    SET  p_message = 'Error: Student is already enrolled in this offering.';

    ELSE
       INSERT INTO enrollments (student_id,offering_id)
       VALUES (p_student_id, p_offering_id);

        SET p_message = 'Success: Student enrolled successfully.';
    END IF;
END$$

DELIMITER ;




-- 2. Get a student's full grade report
--    - Shows course title, semester, year, and letter grade


DELIMITER $$

CREATE PROCEDURE GetStudentGrades(
    IN p_student_id INT
)
BEGIN
    SELECT c.title as course,co.semester,co.year, g.letter_grade,g.grade_points
    from enrollments e join course_offerings co on e.offering_id=co.offering_id
    JOIN courses          c  ON co.course_id   = c.course_id
    LEFT JOIN grades      g  ON e.enrollment_id = g.enrollment_id
    WHERE e.student_id = p_student_id
    ORDER BY co.year, co.semester;

END$$

DELIMITER ;

-- -------------Triggers-----------------------
--1. AUTO-SET grade_points FROM letter_grade                                  │
--   Keeps grade_points consistent; no manual input needed.

DELIMITER $$

CREATE TRIGGER trg1
BEFORE INSERT ON grades FOR EACH ROW
BEGIN
    SET NEW.grade_points= CASE NEW.letter_grade
     WHEN 'A'  THEN 4.00  WHEN 'A-' THEN 3.70
        WHEN 'B+' THEN 3.30  WHEN 'B'  THEN 3.00   WHEN 'C+' THEN 2.70  WHEN 'C'  THEN 2.40
        WHEN 'D'  THEN 2.00  WHEN 'F'  THEN 0.00
        ELSE NULL
        END;
END$$

DELIMITER ;

--   2. AUDIT LOG ON ENROLLMENT DELETE                                           │
--      Saves deleted enrollments to enrollment_audit for traceability.          │
CREATE TRIGGER trg2
AFTER DELETE ON enrollments FOR EACH ROW
BEGIN
   INSERT INTO enrollment_audit (enrollment_id, student_id, offering_id)
   VALUES (OLD.enrollment_id, OLD.student_id, OLD.offering_id);
END$$

DELIMITER ;

--   3. AUTO-UPDATE tuition.status AFTER PAYMENT
--      Recalculates Pending / Partial / Paid every time a payment is added.

DELIMITER $$
CREATE TRIGGER trg3
after insert on payments for each row
BEGIN
    DECLARE _paid DECIMAL(10,2);
    DECLARE _due DECIMAL (10,2);

    select sum(amount) into _paid from payments where
    tuition_id=NEW.tuition_id;

    SELECT amount INTO _due
    FROM   tuition
    WHERE  tuition_id = NEW.tuition_id;

    UPDATE tuition
    SET status =CASE
                    WHEN _paid>=_due THEN 'Paid'
                    WHEN _paid>0 THEN 'Partial'
                    ELSE     'Pending'
                 END
        where tuition_id=NEW.tuition_id;
        

END$$
DELIMITER ;
