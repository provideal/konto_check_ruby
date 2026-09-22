# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`konto_check_ruby` is a **pure Ruby port of Michael Plugge's C library konto_check 6.15**
(German bank account check digits, IBAN generation/validation, bank directory
lookups). No C extension, no runtime dependencies, Ruby >= 3.0, LGPL 2.1+.

The overriding constraint: the port must be **bit-exact with the C library**.
Every behavioural difference is a bug unless it is listed under "Differences to
the C library / original gem" in `README.md`. When changing ported code, do not
"improve", refactor or idiomatise the algorithm — mirror `konto_check.c`.

## Commands

```sh
bundle install
rake test                                              # full suite (~4 s, 61 runs)
ruby -Ilib -Itest test/test_engine.rb                   # one file
ruby -Ilib -Itest test/test_engine.rb -n test_bundled_lut   # one test
KONTO_CHECK_LIVE=1 rake test                            # also runs the live Bundesbank download test
ruby -Ilib bin/konto_check_ruby check 37040044 532013000    # CLI from the working tree
```

There is no linter configured. Minitest only; no RSpec.

### Differential tests against the C library

The real correctness net lives in `tools/` and is **not** part of `rake test`;
it needs the original C sources compiled into a reference driver:

```sh
unzip konto_check-6.15.zip && cd konto_check-6.15
cc -O2 -w -DDEBUG=1 -o kc_ref ../tools/kc_ref.c konto_check.c -lz

ruby tools/difftest_methods.rb PATH/kc_ref 0-144 1000                       # check digit methods
ruby tools/difftest_iban.rb PATH/kc_ref test/fixtures/blz.lut2f 30 1 PATH/konto_check.c
ruby tools/difftest_lookup.rb PATH/kc_ref test/fixtures/blz.lut2f            # lut_* lookups
```

Run these after touching `check_methods/`, `iban_rules.rb` or the lookup paths.
`tools/README.md` documents the one known, accepted deviation (`lut_bic` with an
out-of-range branch index).

## Architecture

Everything is layered on one class, `KontoCheckRuby::Engine`, which owns exactly
one loaded bank directory and implements the C API on top of it.

```
KontoCheck            Ruby-ish API, taken verbatim from the original gem (German docs)
KontoCheckRaw         1:1 interface of the old C extension, [value, status] arrays
   └── KontoCheckRuby.engine   default process-wide Engine singleton
KontoCheckRuby::Engine       init/lut_*/kto_check_*/iban_* — ports of konto_check.c
   ├── include IbanRules     iban_regel_cvt(): Bundesbank IBAN rules 0000..0057
   ├── include Search        lut_suche_* (name, place, BIC, BLZ/PLZ ranges, full text)
   └── BankData              the loaded directory: parallel arrays, not objects
CheckMethods          standalone module, no Engine needed: methods 00..E4
LutFile / BlzFile     file formats: LUT2 read+write, Bundesbank TXT/CSV/XML parse
Update                downloads the current Bundesbank file into a cache dir
```

Key conventions inherited from C:

* Functions that return a value *plus* a status return `[value, status]`
  (the C function took an `int *retval`). Status codes are the integer
  constants in `retvals.rb`, kept under their **exact C names**
  (`OK`, `FALSE`, `INVALID_KTO`, `LUT2_NOT_INITIALIZED`, ...). `OK` is 0,
  errors are negative, some positive/negative codes are informational.
* `BankData` mirrors the C library's memory layout: parallel arrays indexed by
  bank index (`blz`, `pz`, `name`, `bic`, `filialen`, `startidx`, ...), with
  main offices and branches in separate index spaces. Arrays are `nil` when the
  corresponding LUT block was not loaded — `level` (0..9) selects which blocks
  `init` loads, so a missing array means "not requested", not "absent".
* Check methods live in `check_methods/part1..5.rb`: each C `case N:` of the
  giant switch in `kto_check_int()` is a method `mN(kto, blz, um, rv)`, found by
  the dispatcher via `respond_to?(:"m#{pz_methode}")`. `kto` is an **Array of 10
  Integer digits** here (right aligned, zero padded), and methods may modify it.
  Sub-methods 'a'..'g' are encoded as `um * 1000 + method` (13a == 1013).
* In `iban_rules.rb` the same account is a **mutable String of 10 characters**,
  modified in place, because the C code does `strcpy`/`memcpy` on it. Do not
  confuse the two representations.
* `rv` / `retvals` is a `CheckMethods::Retvals` struct (`methode`, `pz_methode`,
  `pz`, `pz_pos`) or `nil`, filled only by the `*_dbg` entry points.

`tools/PORTING_SPEC.md` and `tools/IBAN_PORTING_SPEC.md` state precisely how C
constructs were translated (macros, `switch` fall-through, string vs. digit
semantics, `#if DEBUG` blocks). Read the relevant one before porting or fixing
anything in `check_methods/` or `iban_rules.rb`.

## Bank data

Three ways to get a directory into an Engine, all ending in `BankData`:

1. `init(lut_file, level, set)` — LUT2 file (`blz.lut2f`), the original binary
   format; blocks are loaded incrementally and a re-`init` of the same file only
   adds missing blocks. Without a filename the **bundled** `data/blz.lut2f` is used.
2. `load_blz_file(path)` — Bundesbank "Bankleitzahlendatei" directly, TXT (fixed
   width), CSV or XML, auto-detected.
3. `load_current` — cached download via `Update`, falling back to the newest
   cached file and then to the bundled LUT.

Current Bundesbank files no longer carry the IBAN rule column, so
`data/iban_regeln.txt` (extracted from konto_check 6.15) is applied to them by
default; `iban_rules: false` disables that.

A LUT file can hold two data sets with different validity periods; `set: 0`
picks the one valid for `current_date` (tests pin `Engine#current_date` to a
date inside the fixture's validity — see `test/test_helper.rb`, `VALID_DATE`).

Test fixtures in `test/fixtures/` are a 2023-era LUT file and Bundesbank TXT
file plus `check_method_vectors.json`, ~23k vectors captured from the C library.
Extend that JSON from `tools/difftest_methods.rb` output rather than hand-writing
expectations.

## Style

2 space indent, `# frozen_string_literal: true` (except `konto_check.rb`, which
is the unmodified upstream file), no `require` beyond stdlib. German comment
headers in ported code (`# Methode 13`, rule descriptions) are deliberate —
keep them. Every file carries the LGPL header; new files need it too.
