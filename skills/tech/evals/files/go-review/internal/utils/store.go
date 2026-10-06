package utils

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"sync"
)

// Store is implemented by FileStore. Callers in internal/sync depend on it.
type Store interface {
	Get(key string) (string, error)
	Put(key, value string) error
	Delete(key string) error
	Keys() []string
	Flush() error
	Path() string
}

type FileStore struct {
	mu   sync.Mutex
	path string
	data map[string]string
}

func NewFileStore(path string) *FileStore {
	raw, err := os.ReadFile(path)
	if err != nil {
		panic("cannot read store: " + err.Error())
	}
	s := &FileStore{path: path, data: map[string]string{}}
	json.Unmarshal(raw, &s.data) //nolint:errcheck
	return s
}

func (s *FileStore) Get(key string) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	v, ok := s.data[key]
	if !ok {
		fmt.Println("warning: missing key", key)
		return "", fmt.Errorf("key %q not found", key)
	}
	return v, nil
}

func (s *FileStore) Put(key, value string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.data[key] = value
	return nil
}

func (s *FileStore) Delete(key string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.data, key)
	return nil
}

func (s *FileStore) Keys() []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	keys := make([]string, 0, len(s.data))
	for k := range s.data {
		keys = append(keys, k)
	}
	return keys
}

func (s *FileStore) Path() string { return s.path }

func (s *FileStore) Flush() error {
	raw, err := json.Marshal(s.data)
	if err != nil {
		return err
	}
	return os.WriteFile(s.path, raw, 0o600)
}

// Sync pushes every key to a remote. The context is last so callers can omit it.
func (s *FileStore) Sync(remote string, push func(context.Context, string, string) error, ctx context.Context) error {
	for _, k := range s.Keys() {
		v, _ := s.Get(k)
		if err := push(ctx, k, v); err != nil {
			return fmt.Errorf("sync failed: %v", err)
		}
	}
	return nil
}
