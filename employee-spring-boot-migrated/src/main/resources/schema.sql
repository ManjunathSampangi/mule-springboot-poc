-- Database Schema

-- Drop table if exists
DROP TABLE IF EXISTS employees;

-- Create employees table
CREATE TABLE employees (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(100) UNIQUE,
    department_id VARCHAR(100),
    hire_date VARCHAR(100),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO employees (first_name, last_name, email, department_id, hire_date) VALUES
('John', 'Doe', 'john.doe@example.com', '1', '2023-01-15'),
('Jane', 'Smith', 'jane.smith@example.com', '2', '2023-02-20'),
('Bob', 'Johnson', 'bob.johnson@example.com', '1', '2023-03-10'),
('Alice', 'Williams', 'alice.williams@example.com', '3', '2023-04-05');

