-- Database Schema

-- Drop table if exists
DROP TABLE IF EXISTS products;

-- Create products table
CREATE TABLE products (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    category VARCHAR(100) NOT NULL,
    stock INT NOT NULL,
    active BOOLEAN DEFAULT FALSE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO products (name, description, price, category, stock, active) VALUES
('Laptop Pro 15', 'High-performance laptop with 16GB RAM', 1299.99, 'Electronics', 25, true),
('Wireless Mouse', 'Ergonomic wireless mouse', 29.99, 'Electronics', 150, true),
('Office Chair', 'Comfortable ergonomic office chair', 349.99, 'Furniture', 40, true),
('USB-C Hub', '7-in-1 USB-C hub with HDMI', 49.99, 'Electronics', 80, true),
('Standing Desk', 'Electric height-adjustable desk', 599.99, 'Furniture', 15, true);

