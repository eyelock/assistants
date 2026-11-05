// Package links extracts and resolves the links in an HTML document.
package links

import (
	"fmt"
	"io"
	"net/url"
	"regexp"
)

var hrefPattern = regexp.MustCompile(`href="([^"]+)"`)

// ExtractLinks returns every href value in an HTML document, in order.
func ExtractLinks(r io.Reader) ([]string, error) {
	raw, err := io.ReadAll(r)
	if err != nil {
		return nil, fmt.Errorf("reading html: %w", err)
	}
	var links []string
	for _, m := range hrefPattern.FindAllSubmatch(raw, -1) {
		links = append(links, string(m[1]))
	}
	return links, nil
}

// Resolve makes link absolute against base. A link that is already absolute,
// or a base that does not parse, returns link unchanged.
func Resolve(base, link string) string {
	b, err := url.Parse(base)
	if err != nil || base == "" {
		return link
	}
	l, err := url.Parse(link)
	if err != nil {
		return link
	}
	return b.ResolveReference(l).String()
}
