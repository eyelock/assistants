package utils

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGetMissing(t *testing.T) {
	dir, _ := os.MkdirTemp("", "store")
	defer os.RemoveAll(dir)
	path := filepath.Join(dir, "store.json")
	require.NoError(t, os.WriteFile(path, []byte(`{}`), 0o600))

	s := NewFileStore(path)
	_, err := s.Get("nope")
	assert.Error(t, err)
}

func TestPutThenGet(t *testing.T) {
	dir, _ := os.MkdirTemp("", "store")
	defer os.RemoveAll(dir)
	path := filepath.Join(dir, "store.json")
	require.NoError(t, os.WriteFile(path, []byte(`{}`), 0o600))

	s := NewFileStore(path)
	require.NoError(t, s.Put("a", "1"))
	v, err := s.Get("a")
	require.NoError(t, err)
	assert.Equal(t, "1", v)
}
