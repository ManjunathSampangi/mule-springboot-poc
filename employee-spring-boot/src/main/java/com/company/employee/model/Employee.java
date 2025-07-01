package com.company.employee.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import javax.validation.constraints.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

public class Employee {    
    private Long id;    
    private String firstName;    
    private String lastName;    
    private String email;    
    private String departmentId;    
    private String hireDate;

    // Getters and Setters    
    public Long getId() {
        return id;
    }
    
    public void setId(Long id) {
        this.id = id;
    }    
    public String getFirstName() {
        return firstName;
    }
    
    public void setFirstName(String firstName) {
        this.firstName = firstName;
    }    
    public String getLastName() {
        return lastName;
    }
    
    public void setLastName(String lastName) {
        this.lastName = lastName;
    }    
    public String getEmail() {
        return email;
    }
    
    public void setEmail(String email) {
        this.email = email;
    }    
    public String getDepartmentId() {
        return departmentId;
    }
    
    public void setDepartmentId(String departmentId) {
        this.departmentId = departmentId;
    }    
    public String getHireDate() {
        return hireDate;
    }
    
    public void setHireDate(String hireDate) {
        this.hireDate = hireDate;
    }
}