package com.example.shop.order;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;
import org.junit.Before;
import org.junit.Test;

public class OrderServiceTest {

    private OrderRepository repository;
    private OrderService service;

    @Before
    public void setUp() {
        repository = mock(OrderRepository.class);
        service = new OrderService(repository, Optional.empty());
    }

    @Test
    public void test1() {
        Order order = new Order("c1", List.of("sku-1"));
        when(repository.findById("o1")).thenReturn(Optional.of(order));
        assertEquals(order, service.findOrder("o1"));
        verify(repository).findById("o1");
    }

    @Test
    public void test2() {
        when(repository.findByCustomer("c1")).thenReturn(List.of());
        assertNull(service.ordersFor("c1"));
    }

    @Test
    public void test3() {
        Order order = new Order("c1", List.of("sku-1"));
        when(repository.save(org.mockito.ArgumentMatchers.any())).thenReturn(order);
        assertEquals(order, service.create("c1", List.of("sku-1")));
        verify(repository).save(org.mockito.ArgumentMatchers.any());
    }
}
