-- Test data for a sample HTML/CSS/JavaScript/MySQL application integrated with Deploy_LGTM.
-- This file is safe for local development. It contains no real user data.

CREATE DATABASE IF NOT EXISTS sample_lgtm;
USE sample_lgtm;

DROP TABLE IF EXISTS frontend_events;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS tutorials;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  external_id VARCHAR(64) NOT NULL UNIQUE,
  display_name VARCHAR(120) NOT NULL,
  email_hash VARCHAR(128) NOT NULL,
  plan_name VARCHAR(32) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tutorials (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  published BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE products (
  id INT AUTO_INCREMENT PRIMARY KEY,
  sku VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(120) NOT NULL,
  price_cents INT NOT NULL,
  stock_quantity INT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_ref VARCHAR(64) NOT NULL UNIQUE,
  user_id INT NOT NULL,
  status VARCHAR(32) NOT NULL,
  total_cents INT NOT NULL,
  trace_id VARCHAR(64) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE order_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  quantity INT NOT NULL,
  unit_price_cents INT NOT NULL,
  CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders(id),
  CONSTRAINT fk_order_items_product FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE TABLE frontend_events (
  id INT AUTO_INCREMENT PRIMARY KEY,
  event_type VARCHAR(64) NOT NULL,
  route VARCHAR(128) NOT NULL,
  severity VARCHAR(16) NOT NULL,
  message VARCHAR(255) NOT NULL,
  trace_id VARCHAR(64) NOT NULL,
  duration_ms INT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (external_id, display_name, email_hash, plan_name) VALUES
  ('usr-demo-001', 'Demo Reader', 'sha256:4f8f-demo-reader', 'free'),
  ('usr-demo-002', 'Demo Admin', 'sha256:91aa-demo-admin', 'pro'),
  ('usr-demo-003', 'Demo Buyer', 'sha256:19cc-demo-buyer', 'team');

INSERT INTO tutorials (title, description, published) VALUES
  ('Deploy LGTM overview', 'Understand Grafana, Loki, Mimir, Tempo and Alloy.', TRUE),
  ('Instrument Node.js', 'Add OpenTelemetry SDK and JSON logs to an Express API.', TRUE),
  ('MySQL observability', 'Expose MySQL metrics and correlate slow queries.', FALSE),
  ('Frontend telemetry', 'Collect browser errors and Web Vitals safely.', TRUE);

INSERT INTO products (sku, name, price_cents, stock_quantity) VALUES
  ('OBS-BOOK-001', 'Observability handbook', 2900, 42),
  ('LGTM-LAB-001', 'LGTM lab access', 9900, 12),
  ('MYSQL-DASH-001', 'MySQL dashboard template', 1900, 200);

INSERT INTO orders (order_ref, user_id, status, total_cents, trace_id) VALUES
  ('ORD-20260706-001', 3, 'paid', 11800, '4bf92f3577b34da6a3ce929d0e0e4736'),
  ('ORD-20260706-002', 2, 'pending', 1900, '6af92f3577b34da6a3ce929d0e0e9841'),
  ('ORD-20260706-003', 1, 'failed', 9900, '7cf92f3577b34da6a3ce929d0e0e1111');

INSERT INTO order_items (order_id, product_id, quantity, unit_price_cents) VALUES
  (1, 1, 1, 2900),
  (1, 2, 1, 9900),
  (2, 3, 1, 1900),
  (3, 2, 1, 9900);

INSERT INTO frontend_events (event_type, route, severity, message, trace_id, duration_ms) VALUES
  ('page_load', '/', 'info', 'Home page loaded', '4bf92f3577b34da6a3ce929d0e0e4736', 182),
  ('api_error', '/tutorials', 'error', 'Tutorial API returned HTTP 500 during test', '7cf92f3577b34da6a3ce929d0e0e1111', 721),
  ('web_vital', '/checkout', 'warn', 'LCP above expected threshold', '6af92f3577b34da6a3ce929d0e0e9841', 2600);
