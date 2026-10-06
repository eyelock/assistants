package main

import (
	"flag"
	"fmt"
	"os"

	"example.com/linkcheck/internal/links"
)

func main() {
	base := flag.String("base", "", "base URL that relative links resolve against")
	flag.Parse()
	if flag.NArg() != 1 {
		fmt.Fprintln(os.Stderr, "usage: linkcheck [-base URL] <file.html>")
		os.Exit(2)
	}
	f, err := os.Open(flag.Arg(0))
	if err != nil {
		fmt.Fprintln(os.Stderr, "linkcheck:", err)
		os.Exit(1)
	}
	defer f.Close()

	found, err := links.ExtractLinks(f)
	if err != nil {
		fmt.Fprintln(os.Stderr, "linkcheck:", err)
		os.Exit(1)
	}
	for _, l := range found {
		fmt.Println(links.Resolve(*base, l))
	}
}
