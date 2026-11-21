# Fix ARMv7 BoringCrypto Build Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the Go standard-library RSA patch so the ARMv7 BoringCrypto workflow parses and builds sing-box v1.14.4.

**Architecture:** Keep the existing cross-compilation and BoringCrypto pipeline. Pin the Go toolchain to the version required by sing-box v1.14.4, insert the RSA fallback constant after each file's imports, and parse-check the patched Go files before building.

**Tech Stack:** GitHub Actions YAML, Go 1.25.5, Python 3 for import-aware source patching, `gofmt`, ARM cross-compilers, QEMU.

**Spec:** The current workflow at `.github/workflows/build.yml`, sing-box v1.14.4's [`go.mod`](https://github.com/SagerNet/sing-box/blob/v1.14.4/go.mod), and [failed Actions run #10](https://github.com/baiyunquan/sing-box-armv7-crypto/actions/runs/41891196296).

## Global Constraints

- Keep the target as Linux `GOARCH=arm`, `GOARM=7` with `GOEXPERIMENT=boringcrypto`.
- Use Go 1.25.5, matching sing-box v1.14.4's `go 1.25.5` directive.
- Preserve the existing static link, hardware-instruction check, QEMU run, packaging, and release steps.
- Do not change BoringSSL source or the RSA fallback behavior as part of this fix.

## Review Focus

- The RSA constant must follow the import declarations in both `boring.go` and `notboring.go`; `gofmt` must parse both patched files before `go build` starts.
- The selected Go version must remain aligned with the sing-box module's minimum version and with the standard-library files this workflow patches.
- The resulting ARM binary must still pass the existing `aese`/`aesd`/`pmull` inspection and QEMU version command.

---

## Diagnosis

Run #10 resolved `go-version: ^1.24` to Go 1.26.10. Toolchain installation, BoringSSL compilation, creation of `goboringcrypto_linux_arm.syso`, and source checkout completed. The build then failed at `crypto/rsa/boring.go:10:1` with `imports must appear before other declarations`.

The workflow inserts `const boringEnabled = false` immediately after `package rsa` in both RSA files. In Go, the import block must precede declarations, so this edit makes `boring.go` syntactically invalid. The same insertion also puts the constant before the single import in `notboring.go`. The version selector is a reproducibility issue, not the direct syntax-error cause: v1.14.4 requires Go 1.25.5, while the caret selector allowed the runner to choose 1.26.10.

## Task 1: Fix and guard the standard-library patch

**Files:**
- Modify: `.github/workflows/build.yml`

**Interfaces:**
- Consumes: `GOROOT` from `go env GOROOT` and the existing `boring.go` / `notboring.go` files.
- Produces: valid RSA source files with `boringEnabled` declared after imports, plus a parse check that runs before sing-box compilation.

- [ ] **Step 1: Pin the Go toolchain**

Change `actions/setup-go` from `go-version: ^1.24` to `go-version: 1.25.5` and print `go version` in the setup step. This matches the v1.14.4 module directive and prevents the runner from silently selecting a different Go minor or patch release.

- [ ] **Step 2: Insert the RSA constant after imports**

Replace the two `sed` commands that append after `package rsa` with an import-aware patch. Insert `const boringEnabled = false` after the complete parenthesized import block in `crypto/rsa/boring.go`, and after the single import declaration in `crypto/rsa/notboring.go`. Fail the workflow if either expected import form is not found or the constant is already present, so a future Go source-layout change is visible rather than silently producing a malformed SDK.

- [ ] **Step 3: Parse-check the patched files**

Before compiling sing-box, run `gofmt -d` on both patched RSA files. Expected: command succeeds without Go parser errors. Keep this check in the workflow immediately after applying the standard-library patches.

- [ ] **Step 4: Run the build workflow and inspect all downstream checks**

For sing-box v1.14.4, confirm the build step passes, the binary contains ARMv8 crypto instructions, QEMU prints the expected version, and packaging completes. The current workflow publishes a GitHub Release on `workflow_dispatch` and pushes to `main`; review that release behavior before triggering a remote validation run.

## Self-review

- Coverage: the plan addresses the reported syntax error, the Go version drift, and pre-build validation of the patched files.
- Scope: only `.github/workflows/build.yml` needs modification; the existing architecture, BoringSSL build, binary checks, and packaging remain intact.
- Verification: parsing is checked before compilation, then the workflow's existing binary checks validate the final artifact.
