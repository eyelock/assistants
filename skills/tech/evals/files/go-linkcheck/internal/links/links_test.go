package links

import (
	"strings"
	"testing"
)

func TestExtractLinks(t *testing.T) {
	page := `<a href="intro.html">Intro</a> <a href="/about">About</a> <a href="https://other.org/x">x</a>`
	links, err := ExtractLinks(strings.NewReader(page))
	if err != nil {
		t.Fatal(err)
	}
	if len(links) != 3 {
		t.Fatalf("got %d links, want 3: %v", len(links), links)
	}
}

func TestResolve(t *testing.T) {
	tests := []struct {
		name, base, link, want string
	}{
		{name: "relative", base: "https://example.com/docs/", link: "intro.html", want: "https://example.com/docs/intro.html"},
		{name: "absolute kept", base: "https://example.com/", link: "https://other.org/x", want: "https://other.org/x"},
		{name: "no base", base: "", link: "intro.html", want: "intro.html"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Resolve(tt.base, tt.link); got != tt.want {
				t.Errorf("Resolve(%q, %q) = %q, want %q", tt.base, tt.link, got, tt.want)
			}
		})
	}
}
