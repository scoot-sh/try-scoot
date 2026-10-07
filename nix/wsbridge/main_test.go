package main

import (
	"bytes"
	"crypto/rand"
	"encoding/binary"
	"io"
	"net"
	"net/http"
	"testing"
	"time"
)

func mkReq(host, conn, upgrade, origin, version string) *http.Request {
	r, _ := http.NewRequest("GET", "http://"+host+"/websockify", nil)
	r.Host = host
	if conn != "" {
		r.Header.Set("Connection", conn)
	}
	if upgrade != "" {
		r.Header.Set("Upgrade", upgrade)
	}
	if origin != "" {
		r.Header.Set("Origin", origin)
	}
	if version != "" {
		r.Header.Set("Sec-WebSocket-Version", version)
	}
	return r
}

func TestIsWSUpgrade(t *testing.T) {
	good := mkReq("h", "Upgrade", "websocket", "", "")
	if !isWSUpgrade(good) {
		t.Fatal("plain Upgrade+websocket should qualify")
	}
	// Precedence bug: Connection Upgrade + Upgrade h2c must NOT qualify.
	h2c := mkReq("h", "Upgrade", "h2c", "", "")
	if isWSUpgrade(h2c) {
		t.Fatal("Upgrade: h2c must not be treated as WebSocket")
	}
	lower := mkReq("h", "keep-alive, Upgrade", "WebSocket", "", "")
	if !isWSUpgrade(lower) {
		t.Fatal("token list with Upgrade should qualify")
	}
	plain := mkReq("h", "", "", "", "")
	if isWSUpgrade(plain) {
		t.Fatal("plain HTTP must not qualify")
	}
	keepOnly := mkReq("h", "keep-alive", "websocket", "", "")
	if isWSUpgrade(keepOnly) {
		t.Fatal("missing upgrade token must not qualify")
	}
}

func TestOriginAllowed(t *testing.T) {
	cases := []struct {
		host, origin string
		want         bool
	}{
		{"localhost:6080", "", true}, // non-browser: allow
		{"localhost:6080", "http://localhost:6080", true},
		{"localhost:6080", "http://localhost:6080/", true},
		{"localhost:6080", "http://127.0.0.1:6080", true}, // loopback spelling, same port
		{"localhost:6080", "http://[::1]:6080", true},
		{"127.0.0.1:6080", "http://localhost:6080", true},
		{"localhost:6080", "https://localhost:6080", true},
		{"localhost:6080", "http://localhost:3000", false}, // wrong port
		{"localhost:6080", "http://evil.example", false},
		{"localhost:6080", "http://evil.example:6080", false},
		{"localhost:6080", "http://localhost.evil.example:6080", false},
		{"localhost:6080", "null", false},
		{"localhost:6080", "http://localhost", false}, // port 80 != 6080
		{"localhost:6080", "file://localhost:6080", false},
		{"example.com:6080", "http://example.com:6080", true}, // own host
	}
	for _, c := range cases {
		if got := originAllowed(c.host, c.origin); got != c.want {
			t.Errorf("originAllowed(%q,%q)=%v want %v", c.host, c.origin, got, c.want)
		}
	}
}

// frameBytes builds a client (masked) frame for tests.
func frameBytes(fin bool, op byte, payload []byte, mask [4]byte, rsv byte) []byte {
	var out []byte
	b0 := op
	if fin {
		b0 |= 0x80
	}
	b0 |= rsv << 4
	out = append(out, b0)
	n := len(payload)
	switch {
	case n < 126:
		out = append(out, 0x80|byte(n))
	case n < 65536:
		out = append(out, 0x80|126, byte(n>>8), byte(n))
	default:
		out = append(out, 0x80|127, 0, 0, 0, 0, byte(n>>24), byte(n>>16), byte(n>>8), byte(n))
	}
	out = append(out, mask[:]...)
	masked := make([]byte, n)
	for i := range payload {
		masked[i] = payload[i] ^ mask[i%4]
	}
	return append(out, masked...)
}

func readOne(t *testing.T, raw []byte) (bool, byte, []byte, uint16, error) {
	t.Helper()
	c1, c2 := net.Pipe()
	defer c1.Close()
	defer c2.Close()
	go func() {
		_, _ = c2.Write(raw)
	}()
	_ = c1.SetReadDeadline(time.Now().Add(5 * time.Second))
	return readFrame(c1)
}

func TestReadFrameRoundTrip(t *testing.T) {
	var mask [4]byte
	_, _ = rand.Read(mask[:])
	payload := []byte("hello-rfb")
	fin, op, got, code, err := mustRead(t, frameBytes(true, 0x2, payload, mask, 0))
	if err != nil || code != 0 || !fin || op != 0x2 || !bytes.Equal(got, payload) {
		t.Fatalf("roundtrip: %v %v %v %q", fin, op, code, got)
	}
}

func mustRead(t *testing.T, raw []byte) (bool, byte, []byte, uint16, error) {
	t.Helper()
	return readOne(t, raw)
}

func TestReadFrameRejects(t *testing.T) {
	var mask [4]byte
	mk := func(b0extra byte, op byte, n int) []byte {
		p := bytes.Repeat([]byte("x"), n)
		f := frameBytes(true, op, p, mask, 0)
		f[0] |= b0extra
		return f
	}
	// RSV bits -> 1002.
	if _, _, _, code, err := mustRead(t, mk(0x40, 0x2, 3)); err == nil || code != 1002 {
		t.Errorf("RSV must close 1002, got %v %v", code, err)
	}
	// Unknown opcode 0x3 -> 1003.
	if _, _, _, code, err := mustRead(t, frameBytes(true, 0x3, []byte("x"), mask, 0)); err == nil || code != 1003 {
		t.Errorf("unknown opcode must close 1003, got %v %v", code, err)
	}
	// Unmasked -> 1002.
	raw := frameBytes(true, 0x2, []byte("hi"), mask, 0)
	raw[1] &^= 0x80
	if _, _, _, code, err := mustRead(t, raw); err == nil || code != 1002 {
		t.Errorf("unmasked must close 1002, got %v %v", code, err)
	}
	// Fragmented control -> 1002.
	if _, _, _, code, err := mustRead(t, frameBytes(false, 0x9, []byte("p"), mask, 0)); err == nil || code != 1002 {
		t.Errorf("fragmented ping must close 1002, got %v %v", code, err)
	}
	// Oversized control (126) -> 1002.
	if _, _, _, code, err := mustRead(t, frameBytes(true, 0x9, bytes.Repeat([]byte("p"), 126), mask, 0)); err == nil || code != 1002 {
		t.Errorf("big ping must close 1002, got %v %v", code, err)
	}
	// Oversized data frame (declares 2^63-1) -> 1009 without allocating.
	evil := []byte{0x82, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 1, 2, 3, 4}
	if _, _, _, code, err := mustRead(t, evil); err == nil || code != 1009 {
		t.Errorf("huge frame must close 1009, got %v %v", code, err)
	}
	// 2 MiB data frame (> 1 MiB cap) -> 1009.
	big := make([]byte, 8)
	binary.BigEndian.PutUint64(big, 2<<20)
	hdr := append([]byte{0x82, 0xFF}, big...)
	hdr = append(hdr, 1, 2, 3, 4)
	if _, _, _, code, err := mustRead(t, hdr); err == nil || code != 1009 {
		t.Errorf("2MiB frame must close 1009, got %v %v", code, err)
	}
}

func TestReadMessageReassemblyAndCap(t *testing.T) {
	var mask [4]byte
	// Fragmented message reassembles.
	c1, c2 := net.Pipe()
	defer c1.Close()
	defer c2.Close()
	go func() {
		_, _ = c2.Write(frameBytes(false, 0x2, []byte("hel"), mask, 0))
		_, _ = c2.Write(frameBytes(true, 0x0, []byte("lo"), mask, 0))
	}()
	_ = c1.SetReadDeadline(time.Now().Add(5 * time.Second))
	op, msg, code, err := readMessage(c1)
	if err != nil || code != 0 || op != 0x2 || string(msg) != "hello" {
		t.Fatalf("reassembly: %v %v %q %v", op, code, msg, err)
	}
	// Ping answered inline, then data follows.
	c3, c4 := net.Pipe()
	defer c3.Close()
	defer c4.Close()
	go func() {
		_, _ = c4.Write(frameBytes(true, 0x9, []byte("p"), mask, 0))
		// Answer the pong the server sends before sending data
		// (net.Pipe is synchronous: no interleaved write/read).
		buf := make([]byte, 16)
		_, _ = io.ReadFull(c4, buf[:3]) // pong hdr (2) + payload (1)
		_, _ = c4.Write(frameBytes(true, 0x2, []byte("d"), mask, 0))
	}()
	_ = c3.SetReadDeadline(time.Now().Add(5 * time.Second))
	_ = c3.SetWriteDeadline(time.Now().Add(5 * time.Second))
	op, msg, _, err = readMessage(c3)
	if err != nil || op != 0x2 || string(msg) != "d" {
		t.Fatalf("ping-inline: %v %q %v", op, msg, err)
	}
}

func TestParseHeaderFuzzSeed(t *testing.T) {
	// Minimal valid masked binary header + key.
	inputs := [][]byte{
		{0x82, 0x80, 1, 2, 3, 4},
		{0x82, 0xFE, 0, 5, 9, 9, 9, 9},
		{0x89, 0x80, 1, 2, 3, 4},
	}
	for _, in := range inputs {
		if _, err := parseFrameHeader(in); err != nil {
			t.Errorf("seed %x: %v", in, err)
		}
	}
	bads := [][]byte{
		{0xC2, 0x80, 1, 2, 3, 4}, // RSV
		{0x83, 0x80, 1, 2, 3, 4}, // unknown opcode
		{0x82, 0x00},             // unmasked
	}
	for _, in := range bads {
		if _, err := parseFrameHeader(in); err == nil {
			t.Errorf("bad seed %x accepted", in)
		}
	}
}

// FuzzParseFrameHeader: the header parser must never panic; size lies must
// map to errTooLarge, RSV to errProtocol, unknown opcodes to errBadOp.
func FuzzParseFrameHeader(f *testing.F) {
	seeds := [][]byte{
		{0x82, 0x80, 1, 2, 3, 4},
		{0x82, 0xFE, 0, 5, 9, 9, 9, 9},
		{0x82, 0xFF, 0, 0, 0, 0, 0, 0, 0, 5, 9, 9, 9, 9},
		{0x89, 0x80, 1, 2, 3, 4},
		{0x8A, 0x80, 1, 2, 3, 4},
		{0x88, 0x80, 1, 2, 3, 4},
		{0xC2, 0x80, 1, 2, 3, 4},
		{0x83, 0x80, 1, 2, 3, 4},
		{0x82, 0x00},
		{0x82, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 9, 9, 9, 9},
	}
	for _, s := range seeds {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, data []byte) {
		fh, err := parseFrameHeader(data)
		if err != nil {
			return
		}
		if fh.headerLen < 0 || fh.headerLen > len(data) {
			t.Fatalf("bad headerLen %d for %d bytes", fh.headerLen, len(data))
		}
		if fh.payloadLen > maxFramePayload && fh.op < 0x8 {
			t.Fatalf("cap bypass: op=%x len=%d", fh.op, fh.payloadLen)
		}
	})
}
