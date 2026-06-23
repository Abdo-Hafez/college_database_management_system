-- 1. Students with their departments
SELECT s.student_id, s.`name` AS student_name, s.email, d.`name` AS department_name
FROM students s
LEFT JOIN departments d ON s.department_id = d.department_id
ORDER BY d.`name`, s.`name`;

-- 2. Number of students per department
SELECT d.`name` AS department_name, COUNT(s.student_id) AS total_students
FROM departments d
LEFT JOIN students s ON d.department_id = s.department_id
GROUP BY d.department_id, d.`name`
ORDER BY total_students DESC;

-- 3. Student GPA using CTE
WITH student_grades AS (
  SELECT s.student_id, s.`name`, g.grade_points
  FROM students s
  JOIN enrollments e ON s.student_id = e.student_id
  JOIN grades g ON e.enrollment_id = g.enrollment_id
)
SELECT student_id, `name` AS student_name, ROUND(AVG(grade_points), 2) AS gpa
FROM student_grades
GROUP BY student_id, `name`
ORDER BY gpa DESC;

-- 4. Rank students by GPA
WITH gpa_list AS (
  SELECT s.student_id, s.`name` AS student_name, ROUND(AVG(g.grade_points), 2) AS gpa
  FROM students s
  JOIN enrollments e ON s.student_id = e.student_id
  JOIN grades g ON e.enrollment_id = g.enrollment_id
  GROUP BY s.student_id, s.`name`
)
SELECT student_name, gpa, RANK() OVER (ORDER BY gpa DESC) AS gpa_rank
FROM gpa_list;

-- 5. Top student in each department
WITH ranked_students AS (
  SELECT
    d.`name` AS department_name,
    s.`name` AS student_name,
    ROUND(AVG(g.grade_points), 2) AS gpa,
    ROW_NUMBER() OVER (
      PARTITION BY d.department_id
      ORDER BY AVG(g.grade_points) DESC
    ) AS row_num
  FROM students s
  JOIN departments d ON s.department_id = d.department_id
  JOIN enrollments e ON s.student_id = e.student_id
  JOIN grades g ON e.enrollment_id = g.enrollment_id
  GROUP BY d.department_id, d.`name`, s.student_id, s.`name`
)
SELECT department_name, student_name, gpa
FROM ranked_students
WHERE row_num = 1;

-- 6. Courses that have prerequisites
SELECT c.title AS course_title, p.title AS prerequisite_title
FROM prerequisites pr
JOIN courses c ON pr.course_id = c.course_id
JOIN courses p ON pr.prerequisite_id = p.course_id
ORDER BY c.title;

-- 7. Attendance summary for each student
SELECT
  s.`name` AS student_name,
  SUM(CASE WHEN a.`status` = 'Present' THEN 1 ELSE 0 END) AS present_days,
  SUM(CASE WHEN a.`status` = 'Absent' THEN 1 ELSE 0 END) AS absent_days,
  SUM(CASE WHEN a.`status` = 'Late' THEN 1 ELSE 0 END) AS late_days
FROM students s
JOIN enrollments e ON s.student_id = e.student_id
LEFT JOIN attendance a ON e.enrollment_id = a.enrollment_id
GROUP BY s.student_id, s.`name`
ORDER BY absent_days DESC;

-- 8. Unpaid tuition with total paid
SELECT
  s.`name` AS student_name,
  t.semester,
  t.`year`,
  t.amount AS tuition_amount,
  COALESCE(SUM(p.amount), 0) AS total_paid,
  t.amount - COALESCE(SUM(p.amount), 0) AS remaining_amount
FROM tuition t
JOIN students s ON t.student_id = s.student_id
LEFT JOIN payments p ON t.tuition_id = p.tuition_id
WHERE t.`status` = 'Pending'
GROUP BY t.tuition_id, s.`name`, t.semester, t.`year`, t.amount
HAVING remaining_amount > 0
ORDER BY remaining_amount DESC;
