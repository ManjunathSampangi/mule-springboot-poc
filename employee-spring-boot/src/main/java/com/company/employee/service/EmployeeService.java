package com.company.employee.service;

import com.company.employee.model.Employee;
import com.company.employee.exception.*;
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
 * EmployeeService - Service for Employee management
 */
@Service
public class EmployeeService {
    
    private static final Logger logger = LoggerFactory.getLogger(EmployeeService.class);
    
    @Autowired
    private JdbcTemplate jdbcTemplate;
    
    // Row mapper for Employee
    private final RowMapper<Employee> employeeRowMapper = (rs, rowNum) -> {
        Employee entity = new Employee();
        
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
    public List<Employee> getAllEmployees() {
        String sql = "SELECT * FROM employees";
        return jdbcTemplate.query(sql, employeeRowMapper);
    }    
    // Create new Employee
    public Employee createEmployee(Employee entity) {
        try {
            logger.debug("Creating new Employee: {}", entity);
        String sql = "INSERT INTO employees (first_name, last_name, email, department_id, hire_date) VALUES (?, ?, ?, ?, ?)";
        
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS);
            ps.setObject(1, entity.getFirstName());
            ps.setObject(2, entity.getLastName());
            ps.setObject(3, entity.getEmail());
            ps.setObject(4, entity.getDepartmentId());
            ps.setObject(5, entity.getHireDate());
                return ps;
        }, keyHolder);
        
        if (keyHolder.getKey() != null) {
                Long generatedId = keyHolder.getKey().longValue();
                logger.debug("Generated ID: {}", generatedId);
                entity.setId(generatedId);
            } else {
                logger.warn("No generated key returned for created Employee");
            }
            
            logger.debug("Successfully created Employee with ID: {}", entity.getId());
        return entity;
        } catch (Exception e) {
            logger.error("Error creating Employee: {}", e.getMessage(), e);
            throw new RuntimeException("Error creating Employee: " + e.getMessage(), e);
        }
    }    
    // Get Employee by ID
    public Employee getEmployeeById(Long id) {
        String sql = "SELECT * FROM employees WHERE id = ?";
        try {
            return jdbcTemplate.queryForObject(sql, employeeRowMapper, id);
        } catch (EmptyResultDataAccessException e) {
            throw new ResourceNotFoundException("Employee not found with id: " + id);
        }
    }    
    // Update Employee
    public Employee updateEmployee(Long id, Employee entity) {
        String sql = "UPDATE employees SET first_name = ?, last_name = ?, email = ?, department_id = ? WHERE id = ?";
        int updated = jdbcTemplate.update(sql, 
            entity.getFirstName(),
            entity.getLastName(),
            entity.getEmail(),
            entity.getDepartmentId(),
            id
        );
        
        if (updated == 0) {
            throw new ResourceNotFoundException("Employee not found with id: " + id);
        }
        
        entity.setId(id);
        return entity;
    }    
    // Delete Employee
    public void deleteEmployee(Long id) {
        String sql = "DELETE FROM employees WHERE id = ?";
        int deleted = jdbcTemplate.update(sql, id);
        
        if (deleted == 0) {
            throw new ResourceNotFoundException("Employee not found with id: " + id);
        }
    }}