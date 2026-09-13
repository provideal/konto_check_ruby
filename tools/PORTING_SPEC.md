# Porting specification: konto_check.c check methods -> Ruby

Copyright (C) 2026 tickettoaster GmbH. LGPL 2.1 or later.

This document describes how the check-digit methods of `kto_check_int()` in
`konto_check.c` (konto_check 6.15, Michael Plugge, LGPL) are ported to plain
Ruby inside the gem `konto_check_ruby`. The goal is a **bit-exact port**: for
every input the Ruby code must return the same result code and the same debug
values (`methode`, `pz_methode`, `pz`, `pz_pos`) as the C library compiled with
`DEBUG=1`.

## Files

* Base module (already written, do not change):
  `lib/konto_check_ruby/check_methods.rb` – defines `KontoCheckRuby::CheckMethods`
  with constants `M10H_DIGITS`, `TAB1`, `TAB2`, `W52`, `W24`, `W93`, the struct
  `Retvals` and the dispatcher. All return code constants (`OK`, `FALSE`,
  `OK_NO_CHK`, `INVALID_KTO`, `NOT_DEFINED`, `NOT_IMPLEMENTED`,
  `UNDEFINED_SUBMETHOD`, `OK_TEST_BLZ_USED`, `INVALID_KTO_LENGTH`, ...) are
  defined in `KontoCheckRuby` (`lib/konto_check_ruby/retvals.rb`) with exactly
  the C macro names and values and are visible lexically inside
  `module KontoCheckRuby; module CheckMethods; ... end; end`.
* Method files: `lib/konto_check_ruby/check_methods/partN.rb` (N = 1..5), each
  covering a range of C `case` labels. Each file must have this shape:

```ruby
# frozen_string_literal: true

module KontoCheckRuby
  module CheckMethods
    extend self

    # Methode 13
    def m13(kto, blz, um, rv)
      ...
    end

    # Methode 13a
    def m1013(kto, blz, um, rv)
      ...
    end
  end
end
```

## Mapping of C constructs

The C function has the signature
`kto_check_int(char *x_blz, int pz_methode, char *kto, int untermethode, RETVAL *retvals)`.
After the prolog `kto` is a 10 character string of digits (right aligned, zero
padded). The switch `switch(pz_methode)` has a `case N:` label for every method
and (inside `#if DEBUG>0`) for every sub-method (`case 1013:`, `case 2013:` ...
= 1000 * sub-method + method).

**Every `case N:` label becomes one Ruby method `mN(kto, blz, um, rv)`.**

* `kto` is an `Array` of 10 `Integer` digits. `kto[i]-'0'` in C is `kto[i]`
  in Ruby. `*kto` is `kto[0]`, `*(kto+5)` is `kto[5]`, `kto[7]=='8'` is
  `kto[7] == 8`, `kto[0]<'5'` is `kto[0] < 5`. `strcmp(kto,"0000060000")<0`
  becomes `kto.join < "0000060000"` (or an integer comparison), `strncmp(kto,"777777",6)==0` becomes `kto[0,6] == [7,7,7,7,7,7]`. Where the C code
  modifies `kto` (e.g. method 24: `*kto='0'`), modify the Ruby array in place
  (`kto[0] = 0`); the array is private to the call, so this is safe.
  `atoi(kto)` is `kto.join.to_i`.
* `x_blz` is `blz`: a `String` of digit characters (normally 8) or `nil`.
  `x_blz[4]` (a character) copied into `kto_alt` becomes the digit
  `blz[4].to_i`. `if(!x_blz)` is `if blz.nil?`.
* `untermethode` is `um` (Integer, 0 = no sub-method requested).
* `retvals` is `rv` (a `Retvals` struct or `nil`). `if(retvals){retvals->methode="13a"; retvals->pz_methode=1013;}` becomes
  `if rv; rv.methode = "13a"; rv.pz_methode = 1013; end`. Keep the exact
  strings used in the C code.
* `RETURN(x)` and `return x` are `return x`.
* The `MOD_*` macros are plain modulo: `MOD_11_352`, `MOD_11_176`, ... are
  `pz %= 11`; `MOD_10_*` are `pz %= 10`; `MOD_9_*` are `pz %= 9`; `MOD_7_*` are
  `pz %= 7`. `SUB1_22`/`SUB1_11` are `p1 %= 11`. Be careful: C `%` on
  negative numbers truncates toward zero (result has the sign of the dividend),
  Ruby `%` floors. Wherever a value could be negative before a `%`
  (e.g. method 17 does `pz-=1` before `MOD_11_44`), use `pz = pz.remainder(11)`
  ... but note: the C macros `MOD_x_y` are implemented as repeated
  `if(pz>=x)pz-=x` subtractions, so for a *negative* pz they leave the value
  unchanged! Therefore: `MOD_*` on a possibly negative value must be ported as
  `pz -= 11 while pz >= 11` style semantics, i.e. `pz %= 11 if pz >= 0`
  (a negative pz stays negative). Integer division `/` in C truncates toward
  zero; use `.fdiv` only where the C code uses floating point (it does not).
* The `CHECK_PZ*`/`INVALID_PZ10` macros (DEBUG variant) are:

```c
CHECK_PZ3   -> if rv; rv.pz_pos = 3;  rv.pz = pz; end; return kto[2] == pz ? OK : FALSE
CHECK_PZ6   -> if rv; rv.pz_pos = 6;  rv.pz = pz; end; return kto[5] == pz ? OK : FALSE
CHECK_PZ7   -> if rv; rv.pz_pos = 7;  rv.pz = pz; end; return kto[6] == pz ? OK : FALSE
CHECK_PZ8   -> if rv; rv.pz_pos = 8;  rv.pz = pz; end; return kto[7] == pz ? OK : FALSE
CHECK_PZ9   -> if rv; rv.pz_pos = 9;  rv.pz = pz; end; return kto[8] == pz ? OK : FALSE
CHECK_PZ10  -> if rv; rv.pz_pos = 10; rv.pz = pz; end; return kto[9] == pz ? OK : FALSE
CHECK_PZX7  -> if rv; rv.pz_pos = 7;  rv.pz = pz; end; return OK if kto[6] == pz; return FALSE if um != 0
CHECK_PZX8  -> if rv; rv.pz_pos = 8;  rv.pz = pz; end; return OK if kto[7] == pz; return FALSE if um != 0
CHECK_PZX9  -> if rv; rv.pz_pos = 9;  rv.pz = pz; end; return OK if kto[8] == pz; return FALSE if um != 0
CHECK_PZX10 -> if rv; rv.pz_pos = 10; rv.pz = pz; end; return OK if kto[9] == pz; return FALSE if um != 0
INVALID_PZ10-> if rv; rv.pz_pos = 10; rv.pz = pz; end; return INVALID_KTO if pz == 10
```

  (`CHECK_PZX*` does **not** return when the check fails and no sub-method was
  requested: execution continues with the next statements / the following
  `case` label.)

* **Fall-through.** C `case` blocks fall through into the next label unless
  they `return`. The sub-method labels rely on this heavily, e.g.

```c
case 13:
case 1013:
   if(retvals){retvals->methode="13a"; retvals->pz_methode=1013;}
   ... compute pz ...
   CHECK_PZX8;
   if(kto[0]!='0' || kto[1]!='0')return FALSE;
case 2013:
   if(retvals){retvals->methode="13b"; retvals->pz_methode=2013;}
   ... compute pz ...
   CHECK_PZ10;
```

  becomes

```ruby
def m13(kto, blz, um, rv)
  m1013(kto, blz, um, rv)        # case 13 has no own code, falls into 1013
end

def m1013(kto, blz, um, rv)
  if rv
    rv.methode = "13a"
    rv.pz_methode = 1013
  end
  ... compute pz ...
  # CHECK_PZX8
  if rv
    rv.pz_pos = 8
    rv.pz = pz
  end
  return OK if kto[7] == pz
  return FALSE if um != 0
  return FALSE if kto[0] != 0 || kto[1] != 0
  m2013(kto, blz, um, rv)        # fall through
end

def m2013(kto, blz, um, rv)
  if rv
    rv.methode = "13b"
    rv.pz_methode = 2013
  end
  ... compute pz ...
  if rv
    rv.pz_pos = 10
    rv.pz = pz
  end
  kto[9] == pz ? OK : FALSE
end
```

  Whenever control in C can reach the next `case` label, the Ruby method must
  end with a call to the method of that label, passing `kto, blz, um, rv`
  unchanged (kto modifications made so far are visible to the callee because
  the array is shared). Note that a `case` label can also sit *inside* an
  `if`/`else` block (e.g. method 53, 87); model the exact control flow
  (the label is only an entry point; when entered via the label, the code
  after it runs regardless of the surrounding `if`). Local variables that are
  set before a label and used after it (e.g. `ok`, `pz`, `p1`, `kto_alt`)
  must be handled explicitly (e.g. pass them along or recompute them exactly
  as C would have them at that point). When a sub-method label is entered
  directly (via `um`), such variables have their initial value from the C
  declarations (`p1=0`, `pz1=0`, others undefined – check the C code for what
  is actually read).

* `#if DEBUG>0 ... #endif` blocks are **active** (the reference build uses
  `DEBUG=1`). `#ifdef __ALPHA` blocks are **inactive**; use the `#else`
  branches. `#if BAV_KOMPATIBEL` blocks are inactive (`BAV_KOMPATIBEL` is 0).
* Buffers like `kto_alt[32]`, `konto[11]`, `xkto` become local Ruby arrays of
  digits (or strings where the C code does string operations). `kto_alt` in
  methods 52/53/B6/C0 is filled with digit characters from `x_blz` and `kto`;
  port it as an array of Integer digits (`kto_alt[5]` compared with `pz`).
  `dptr-kto_alt` (a length) is the array length.
* Static tables: `m10h_digits[a][b]` -> `M10H_DIGITS[a][b]`, `tab1`/`tab2` ->
  `TAB1`/`TAB2`, `w52`/`w24`/`w93` -> `W52`/`W24`/`W93`.
* Unused local variables (`ptr`, `dptr`, `i`, `tmp` ...) are just Ruby locals.
* Return codes: use the constant names exactly as in C (`OK`, `FALSE`,
  `OK_NO_CHK`, `INVALID_KTO`, `NOT_DEFINED`, `NOT_IMPLEMENTED`,
  `UNDEFINED_SUBMETHOD`, `OK_TEST_BLZ_USED`, ...). They are already defined.
* The `default:` branch of the switch is already implemented in the dispatcher;
  do not port it. Do not port the prolog (kto normalization) either.
* Keep the German comment header `# Methode NN` (and the original description
  from the C comment block, condensed to a few lines) above each method; do
  not copy the huge banner comments verbatim.
* Ruby style: 2 spaces indentation, `# frozen_string_literal: true`, no
  external gems, plain integer arithmetic. Prefer explicit, C-like code over
  clever Ruby; readability of the correspondence to the C source is the goal.
  Avoid `Integer#digits` etc.; write the weighted sums out like the C code.
  Use `return` for early exits exactly where C returns.

## Testing

The C reference driver `kc_ref` (path is given in the task) reads
`D <pz> <kto> [blz]` lines and prints `result methode pz_methode pz pz_pos`
from `kto_check_pz_dbg()`. The script `tools/difftest_methods.rb` compares it
with the Ruby port:

```
ruby tools/difftest_methods.rb /path/to/kc_ref 0-50 500
```

(methods as numbers: 100 = A0, 110 = B0, 116 = B6, 120 = C0, 130 = D0,
140 = E0, 144 = E4). It prints mismatches and a per-method failure summary;
it must end with `ALL OK` for your range. Run it repeatedly with different
seeds (4th argument) and a high count (e.g. 2000) until everything passes.
`ruby -c` every file you write. Do not modify the test harness, the base
module or any other file than your `partN.rb`.
