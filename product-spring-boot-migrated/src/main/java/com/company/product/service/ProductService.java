package com.company.product.service;

import com.company.product.model.Product;
import com.company.product.exception.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * ProductService - Service for Product management
 */
@Service
public class ProductService {
    
    private static final Logger logger = LoggerFactory.getLogger(ProductService.class);
    
    @Autowired
    private JdbcTemplate jdbcTemplate;
    
    // Row mapper for Product
    private final RowMapper<Product> productRowMapper = (rs, rowNum) -> {
        Product entity = new Product();
        
        // Use reflection to map fields dynamically
        java.lang.reflect.Field[] fields = entity.getClass().getDeclaredFields();
        for (java.lang.reflect.Field field : fields) {
            field.setAccessible(true);
            String fieldName = field.getName();
            String columnName = camelToSnake(fieldName);
            
            try {
                // Check if column exists
                rs.findColumn(columnName);
                
                // Map based on field type
                Class<?> fieldType = field.getType();
                if (fieldType == Long.class || fieldType == long.class) {
                    field.set(entity, rs.getLong(columnName));
                } else if (fieldType == Integer.class || fieldType == int.class) {
                    field.set(entity, rs.getInt(columnName));
                } else if (fieldType == String.class) {
                    field.set(entity, rs.getString(columnName));
                } else if (fieldType == Boolean.class || fieldType == boolean.class) {
                    field.set(entity, rs.getBoolean(columnName));
                } else if (fieldType == LocalDate.class) {
                    java.sql.Date date = rs.getDate(columnName);
                    if (date != null) {
                        field.set(entity, date.toLocalDate());
                    }
                } else if (fieldType == LocalDateTime.class) {
                    java.sql.Timestamp timestamp = rs.getTimestamp(columnName);
                    if (timestamp != null) {
                        field.set(entity, timestamp.toLocalDateTime());
                    }
                } else if (fieldType == Double.class || fieldType == double.class) {
                    field.set(entity, rs.getDouble(columnName));
                } else if (fieldType == Float.class || fieldType == float.class) {
                    field.set(entity, rs.getFloat(columnName));
                }
            } catch (Exception e) {
                // Column doesn't exist or mapping failed, skip this field
            }
        }
        
        return entity;
    };
    
    // Convert camelCase to snake_case
    private String camelToSnake(String camelCase) {
        return camelCase.replaceAll("([a-z])([A-Z]+)", "$1_$2").toLowerCase();
    }    
    // Get all s
    public List<Product> getAllProducts() {
        // Note: This query has parameters in Mule flow, defaulting to no filter
        String sql = "SELECT * FROM products";
        return jdbcTemplate.query(sql, productRowMapper);
    }
    
    // Get s with filter
    public List<Product> getProductsByStatus(String status) {
        String sql = "SELECT * FROM products WHERE (? IS NULL OR category = ?) AND (? IS NULL OR active = ?)";
        return jdbcTemplate.query(sql, productRowMapper, status);
    }    
    // Create new Product
    public Product createProduct(Product entity) {
        // TODO: Implement based on your schema
        throw new UnsupportedOperationException("Create operation not implemented in Mule flows");
    }    
    // Get Product by ID
    public Product getProductById(Long id) {
        String sql = "SELECT * FROM products WHERE id = ?";
        try {
            return jdbcTemplate.queryForObject(sql, productRowMapper, id);
        } catch (EmptyResultDataAccessException e) {
            throw new ResourceNotFoundException("Product not found with id: " + id);
        }
    }    
    // Update Product
    public Product updateProduct(Long id, Product entity) {
        // Generate UPDATE query dynamically based on entity fields
        java.lang.reflect.Field[] fields = entity.getClass().getDeclaredFields();
        java.util.List<String> setClause = new java.util.ArrayList<>();
        java.util.List<Object> parameters = new java.util.ArrayList<>();
        
        for (java.lang.reflect.Field field : fields) {
            if ("id".equals(field.getName()) || "serialVersionUID".equals(field.getName())) {
                continue; // Skip ID and serialVersionUID
            }
            
            field.setAccessible(true);
            String columnName = camelToSnake(field.getName());
            setClause.add(columnName + " = ?");
            
            try {
                parameters.add(field.get(entity));
            } catch (IllegalAccessException e) {
                parameters.add(null);
            }
        }
        
        parameters.add(id); // Add ID for WHERE clause
        
        String sql = "UPDATE products SET " + String.join(", ", setClause) + " WHERE id = ?";
        int updated = jdbcTemplate.update(sql, parameters.toArray());
        
        if (updated == 0) {
            throw new ResourceNotFoundException("Product not found with id: " + id);
        }
        
        entity.setId(id);
        return entity;
    }    
    // Delete Product
    public void deleteProduct(Long id) {
        String sql = "DELETE FROM products WHERE id = ?";
        int deleted = jdbcTemplate.update(sql, id);
        
        if (deleted == 0) {
            throw new ResourceNotFoundException("Product not found with id: " + id);
        }
    }}