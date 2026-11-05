#!/usr/bin/env bash
# Builds the dev-quality sandbox in the current directory: a small Go module
# (stdlib only) whose Makefile has build, lint, format, format-check, test and
# check targets. lint is go vet plus doclint, a stdlib-only checker that
# prints "warning:" lines for undocumented exported functions but exits 0.
# The clean module is committed on feat/checkout-discounts; SCENARIO picks the
# uncommitted change on top:
#   untested  a coupon feature with no tests and a gofmt violation
#   red       a discount feature that fails format, vet and a test, and adds
#             Total, which has no doc comment and no test
# git and make are real, wrapped so each call is logged to $EVAL_STUB_LOG.
# Exit codes: 0 success, 1 bad SCENARIO, 3 tool error.
set -euo pipefail

scenario="${SCENARIO:?set SCENARIO to untested or red}"

git init -q -b main .
echo ".eval/" >>.git/info/exclude

cat >go.mod <<'EOF'
module github.com/acme/shop

go 1.22
EOF

mkdir -p pricing tools/doclint
cat >pricing/pricing.go <<'EOF'
// Package pricing prices shopping carts.
package pricing

// Item is one line of a cart.
type Item struct {
	Name       string
	PriceCents int
	Qty        int
}

// Subtotal returns the cart's total before discounts, in cents.
func Subtotal(items []Item) int {
	total := 0
	for _, it := range items {
		total += it.PriceCents * it.Qty
	}
	return total
}
EOF
cat >pricing/pricing_test.go <<'EOF'
package pricing

import "testing"

func TestSubtotal(t *testing.T) {
	items := []Item{{Name: "mug", PriceCents: 1250, Qty: 2}, {Name: "tea", PriceCents: 499, Qty: 1}}
	if got := Subtotal(items); got != 2999 {
		t.Fatalf("Subtotal() = %d, want 2999", got)
	}
}
EOF
cat >tools/doclint/main.go <<'EOF'
// Command doclint warns about exported functions without a doc comment.
// It prints one "warning:" line per function and exits 0.
package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	fset := token.NewFileSet()
	err := filepath.WalkDir(".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() && strings.HasPrefix(d.Name(), ".") && path != "." {
			return filepath.SkipDir
		}
		if d.IsDir() || !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		f, err := parser.ParseFile(fset, path, nil, parser.ParseComments)
		if err != nil {
			return err
		}
		for _, decl := range f.Decls {
			fn, ok := decl.(*ast.FuncDecl)
			if ok && fn.Name.IsExported() && fn.Doc == nil {
				pos := fset.Position(fn.Pos())
				fmt.Printf("%s:%d: warning: exported function %s should have a doc comment\n", pos.Filename, pos.Line, fn.Name.Name)
			}
		}
		return nil
	})
	if err != nil {
		fmt.Fprintln(os.Stderr, "doclint:", err)
		os.Exit(1)
	}
}
EOF
cat >Makefile <<'EOF'
.PHONY: build lint format format-check test check clean

build:
	go build ./...

lint:
	go vet ./...
	go run ./tools/doclint

format:
	gofmt -w .

format-check:
	@out="$$(gofmt -l .)"; if [ -n "$$out" ]; then echo "$$out"; echo "error: files above need gofmt (make format)"; exit 1; fi

test:
	go test ./...

clean:
	go clean -cache -testcache

# Everything CI runs.
check: build lint format-check test
EOF
cat >README.md <<'EOF'
# shop

Targets: `make build`, `make lint`, `make format`, `make test`. `make check` runs what CI runs.
EOF
git add . && git commit -qm "chore: Initial commit"
git checkout -qb feat/checkout-discounts

case "$scenario" in
  untested)
    cat >pricing/coupon.go <<'EOF'
package pricing

import (
	"fmt"
	"strings"
)

var coupons = map[string]int{"WELCOME10": 10, "SPRING25": 25}

// ApplyCoupon takes the coupon's percentage off subtotal (in cents). Codes are
// case-insensitive; an unknown code is an error and leaves subtotal unchanged.
func ApplyCoupon(code string, subtotal int) (int, error) {
	pct, ok := coupons[strings.ToUpper(strings.TrimSpace(code))]
	if !ok {
		return subtotal, fmt.Errorf("unknown coupon %q", code)
	}
    return subtotal - subtotal*pct/100, nil
}
EOF
    ;;
  red)
    cat >pricing/discount.go <<'EOF'
package pricing

import "fmt"

// Discount returns percent percent of subtotal, in cents.
func Discount(subtotal, percent int) int {
	return subtotal * (percent / 100)
}

// Summary describes a discounted cart for the receipt.
func Summary(items []Item, percent int) string {
    sub := Subtotal(items)
	return fmt.Sprintf("%d items, %d off", len(items), fmt.Sprint(Discount(sub, percent)))
}

func Total(items []Item, percent int) int {
	sub := Subtotal(items)
	return sub - Discount(sub, percent)
}
EOF
    cat >pricing/discount_test.go <<'EOF'
package pricing

import "testing"

func TestDiscount(t *testing.T) {
	if got := Discount(2000, 15); got != 300 {
		t.Fatalf("Discount(2000, 15) = %d, want 300", got)
	}
}
EOF
    ;;
  *)
    echo "unknown SCENARIO $scenario" >&2
    exit 1
    ;;
esac

for tool in git make; do
  real="$(command -v "$tool")"
  printf '#!/bin/sh\n[ "$1" = -c ] || printf "%%s\\n" "%s $*" >>"%s"\nexec "%s" "$@"\n' "$tool" "$EVAL_STUB_LOG" "$real" >"$EVAL_BIN/$tool"
  chmod +x "$EVAL_BIN/$tool"
done
