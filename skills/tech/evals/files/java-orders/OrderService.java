package com.example.shop.order;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public class OrderService {

    private final OrderRepository repository;
    private Optional<DiscountPolicy> discountPolicy;

    public OrderService(OrderRepository repository, Optional<DiscountPolicy> discountPolicy) {
        this.repository = repository;
        this.discountPolicy = discountPolicy;
    }

    public Order findOrder(String id) {
        Optional<Order> order = repository.findById(id);
        return order.get();
    }

    public List<Order> ordersFor(String customerId) {
        List<Order> orders = repository.findByCustomer(customerId);
        if (orders.isEmpty()) {
            return null;
        }
        return orders;
    }

    public Order create(String customerId, List<String> skus) {
        try {
            Order order = new Order(customerId, skus);
            discountPolicy.ifPresent(p -> p.apply(order));
            return repository.save(order);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    public List<String> importSkus(String path) {
        List<String> skus = new ArrayList<>();
        try {
            BufferedReader reader = new BufferedReader(new FileReader(path));
            String line;
            while ((line = reader.readLine()) != null) {
                skus.add(line.trim());
            }
            reader.close();
        } catch (IOException e) {
        }
        return skus;
    }
}
