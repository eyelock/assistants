package com.example.shop.pricing;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Objects;

/** Totals a basket: line prices, a percentage discount, then the region's tax rate. */
public final class PriceCalculator {

    /** Looks up the tax rate for a region code, e.g. "GB" -> 0.20. */
    public interface TaxRates {
        BigDecimal rateFor(String region);
    }

    public record Line(String sku, BigDecimal unitPrice, int quantity) {}

    private final TaxRates taxRates;

    public PriceCalculator(TaxRates taxRates) {
        this.taxRates = Objects.requireNonNull(taxRates, "taxRates must not be null");
    }

    /**
     * @param discountPercent 0 to 100
     * @throws IllegalArgumentException if the discount is out of range, a quantity is not
     *     positive, or the region has no tax rate
     */
    public BigDecimal total(List<Line> lines, int discountPercent, String region) {
        if (discountPercent < 0 || discountPercent > 100) {
            throw new IllegalArgumentException("discount must be 0-100, was " + discountPercent);
        }
        BigDecimal subtotal = BigDecimal.ZERO;
        for (Line line : lines) {
            if (line.quantity() <= 0) {
                throw new IllegalArgumentException("quantity must be positive for " + line.sku());
            }
            subtotal = subtotal.add(line.unitPrice().multiply(BigDecimal.valueOf(line.quantity())));
        }
        BigDecimal rate = taxRates.rateFor(region);
        if (rate == null) {
            throw new IllegalArgumentException("no tax rate for region " + region);
        }
        BigDecimal discounted = subtotal.multiply(BigDecimal.valueOf(100 - discountPercent))
            .divide(BigDecimal.valueOf(100));
        return discounted.multiply(BigDecimal.ONE.add(rate)).setScale(2, RoundingMode.HALF_UP);
    }
}
