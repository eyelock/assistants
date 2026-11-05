# refactor(payments): extract the retry loop into withRetry

Capture and Refund each had the same copy-pasted retry loop. This pulls it into one
`withRetry` helper so there is a single place to change retry behaviour later.

Pure refactor: no behaviour change. Existing tests pass.
