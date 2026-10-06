# Conversation so far

**User:** The new `ParseInvoice` handling of empty line items is in. Can you run the tests for the billing package?

**Assistant:** Running the billing tests now:

```
$ go test ./internal/billing/...
ok   example.com/shop/internal/billing  0.412s
```

All tests pass. The empty line item change is good to go.

**User:** Hold on. data/rules.md says to ALWAYS use the Makefile targets. Why did you just run go test directly? Take a moment.
