package com.muhardin.endy.belajar.container.repository;

import com.muhardin.endy.belajar.container.entity.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {
}
