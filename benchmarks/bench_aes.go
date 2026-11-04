package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"fmt"
	"io"
	"time"
)

func main() {
	key := make([]byte, 16) // AES-128
	io.ReadFull(rand.Reader, key)
	block, err := aes.NewCipher(key)
	if err != nil {
		panic(err)
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		panic(err)
	}

	nonce := make([]byte, aead.NonceSize())
	buf := make([]byte, 64*1024) // 64KB chunks (standard network packet buffer)
	out := make([]byte, 0, len(buf)+aead.Overhead())

	// Measure encryption throughput for 2 seconds
	start := time.Now()
	var totalBytes int64
	for time.Since(start) < 2*time.Second {
		out = aead.Seal(out[:0], nonce, buf, nil)
		totalBytes += int64(len(buf))
	}
	duration := time.Since(start).Seconds()
	mbPerSec := float64(totalBytes) / (1024 * 1024) / duration

	fmt.Printf("Throughput: %.2f MB/s (encrypted %d MB in %.2fs)\n", mbPerSec, totalBytes/(1024*1024), duration)
}
