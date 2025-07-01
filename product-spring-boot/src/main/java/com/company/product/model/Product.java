package com.company.product.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import javax.validation.constraints.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

public class Product {    
    private Long id;    
    private String name;    
    private String description;    
    private Double price;    
    private String category;    
    private Long stock;    
    private Boolean active;

    // Getters and Setters    
    public Long getId() {
        return id;
    }
    
    public void setId(Long id) {
        this.id = id;
    }    
    public String getName() {
        return name;
    }
    
    public void setName(String name) {
        this.name = name;
    }    
    public String getDescription() {
        return description;
    }
    
    public void setDescription(String description) {
        this.description = description;
    }    
    public Double getPrice() {
        return price;
    }
    
    public void setPrice(Double price) {
        this.price = price;
    }    
    public String getCategory() {
        return category;
    }
    
    public void setCategory(String category) {
        this.category = category;
    }    
    public Long getStock() {
        return stock;
    }
    
    public void setStock(Long stock) {
        this.stock = stock;
    }    
    public Boolean getActive() {
        return active;
    }
    
    public void setActive(Boolean active) {
        this.active = active;
    }
}