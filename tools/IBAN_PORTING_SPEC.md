# Porting specification: iban_regel_cvt() -> Ruby

Copyright (C) 2026 tickettoaster GmbH. LGPL 2.1 or later.

`iban_regel_cvt()` in `konto_check.c` (konto_check 6.15, lines 5137..8305,
about 3200 lines) applies the IBAN rules of the Deutsche Bundesbank to a
BLZ / account number pair: depending on the rule the BLZ and/or the account
number is replaced, the IBAN calculation is forbidden, or a BIC is
prescribed. The goal is a **bit-exact port** to Ruby: for every input the
Ruby code must return the same result code, the same modified BLZ/account
and the same BIC as the C library.

## File

`lib/konto_check_ruby/iban_rules.rb` currently contains a stub that only
implements rules 0 and 1. **Replace the whole file.** Keep exactly this frame:

```ruby
# frozen_string_literal: true

require_relative "retvals"

module KontoCheckRuby
  module IbanRules
    def iban_regel_cvt(blz, kto, regel_version, retvals = nil)
      ...
    end

    private

    # helper methods for single rules, if you want to split the huge switch
    def iban_regel_5(...) ... end
  end
end
```

The module is included into `KontoCheckRuby::Engine`, so `self` is the
engine; all constants of `KontoCheckRuby` (`OK`, `FALSE`, `OK_BLZ_REPLACED`,
`OK_KTO_REPLACED`, `OK_BLZ_KTO_REPLACED`, `OK_KTO_REPLACED_NO_PZ`,
`OK_IBAN_WITHOUT_KC_TEST`, `OK_UNTERKONTO_ATTACHED`, `OK_NO_CHK`,
`NO_IBAN_CALCULATION`, `IBAN_INVALID_RULE`, `IBAN_RULE_UNKNOWN`,
`IBAN_RULE_NOT_IMPLEMENTED`, `IBAN_AMBIGUOUS_KTO`, `BLZ_MARKED_AS_DELETED`,
`INVALID_KTO`, `INVALID_BLZ`, `FALSE_UNTERKONTO_ATTACHED`, ...) are visible
with their C names (see `lib/konto_check_ruby/retvals.rb`).

## Signature and conventions

C: `static int iban_regel_cvt(char *blz, char *kto, const char **bicp, int regel_version, RETVAL *retvals)`

Ruby: `iban_regel_cvt(blz, kto, regel_version, retvals = nil)` returns
`[ret, bic]` where `ret` is the integer result code and `bic` the
prescribed BIC String or `nil` (C `*bicp`, initialised to NULL).

* `blz` is a mutable Ruby `String` with 8 digit characters, `kto` a mutable
  `String` with 10 digit characters (zero padded). Both are **modified in
  place** where the C code modifies them (the caller reads them back):
  * `strcpy(kto,"0990021440")` -> `kto.replace("0990021440")`
  * `strcpy(blz,"50020200")` -> `blz.replace("50020200")`
  * `sprintf(blz,"%08d",b_neu)` / `sprintf(blz,"%d",...)` -> `blz.replace(format("%08d", b_neu))`
  * `kto[1]=kto[4]` (character copy) -> `kto[1] = kto[4]`
  * `kto[7]='0'` -> `kto[7] = "0"`
  * `memcpy(tmp_buffer,kto,10); memcpy(kto,tmp_buffer+4,6); memcpy(kto+6,tmp_buffer,4);`
    -> `tmp = kto.dup; kto.replace(tmp[4, 6] + tmp[0, 4])`
  * `*kto=='0'` / `kto[7]=='8'` -> `kto[0] == "0"` / `kto[7] == "8"`
    (**kto is a String of characters here, not a digit array!**)
  * `blz[3]=='4'` -> `blz[3] == "4"`
  * `strcmp(kto,"6161604670")==0` -> `kto == "6161604670"`; `strcmp(kto,"1000000000")>=0` -> `kto >= "1000000000"` (fixed width, so String comparison equals strcmp)
  * `strncmp(kto,"123",3)==0` -> `kto.start_with?("123")`
* `*bicp="COBADEFFXXX"` -> `bic = "COBADEFFXXX"` (a local variable that is
  returned with every `return`). Every C `return X;` becomes `return [X, bic]`.
  The macros `RETURN_OK` and `RETURN_OK_KTO_REPLACED` are:
  * `RETURN_OK` -> `return [b != b_alt ? OK_BLZ_REPLACED : OK, bic]`
  * `RETURN_OK_KTO_REPLACED` -> `return [b != b_alt ? OK_BLZ_KTO_REPLACED : OK_KTO_REPLACED, bic]`
* Integer locals: `regel`, `version`, `b`, `b_alt`, `b_neu`, `k1`, `k2`,
  `k3`, `not_ok`, `i`, `ret`, `loesch`, `idx`, `pz_methode`, `tmp` are plain
  Ruby locals. C integer division truncates toward zero and `%` keeps the
  sign of the dividend; all values here are non-negative, so Ruby `/` and
  `%` are fine.
* `retvals` (`RETVAL *`) is `retvals` (a `KontoCheckRuby::CheckMethods::Retvals`
  struct with the fields `methode`, `pz_methode`, `pz`, `pz_pos`, or `nil`).
  `if(retvals){retvals->methode="c7b"; retvals->pz_methode=2127;}` ->
  `if retvals; retvals.methode = "c7b"; retvals.pz_methode = 2127; end`.
* C `switch` statements: most `case` blocks end with `return`; where a
  `case` falls through into the next one or `break`s out of the switch and
  continues, model that control flow exactly (Ruby `case/when` has no
  fall-through; duplicate or restructure the code as needed, but keep the
  semantics). `switch(k2){ case 135: ...; case 1111: ... default: RETURN_OK; }`
  where every branch returns can become a Ruby `case k2 when 135 ... end`.
  Note the C idiom `if(!k1)switch(k2){...}` (only when k1 == 0).
* `#if`/`#ifdef` blocks: there are none that matter inside the function
  (check while reading; `DEBUG` is 1, `BAV_KOMPATIBEL` is 0).

## Prolog (port exactly)

```c
   if((init_status&7)!=7)RETURN(LUT2_NOT_INITIALIZED);
   for(not_ok=i=0;i<8;i++)not_ok|=is_not_digit[I blz[i]];
   if(not_ok)return INVALID_BLZ;
   for(i=0;i<10 && kto[i];i++)not_ok|=is_not_digit[I kto[i]];
   if(not_ok)return INVALID_KTO;
   if((ret=iban_init())<OK)return ret;
   regel=regel_version/100;
   version=regel_version%100;
   *bicp=NULL;
   ret=OK;
   k1=b2[I kto[0]]+b1[I kto[1]];                     /* first two digits as number */
   k2=b8[I kto[2]]+...+b1[I kto[9]];                 /* last eight digits as number */
   b_alt=b=b8[I blz[0]]+...+b1[I blz[7]];            /* BLZ as number */
   if(lut_aenderung_i(b,0,NULL)=='D' && !(b=lut_nachfolge_blz_i(b,0,NULL)))return BLZ_MARKED_AS_DELETED;
```

Ruby:

```ruby
return [LUT2_NOT_INITIALIZED, nil] unless @data
return [INVALID_BLZ, nil] unless blz =~ /\A\d{8}\z/
return [INVALID_KTO, nil] unless kto =~ /\A\d{1,10}\z/
ret = iban_init
return [ret, nil] if ret < OK
regel = regel_version / 100
version = regel_version % 100
bic = nil
ret = OK
k1 = kto[0, 2].to_i
k2 = kto[2, 8].to_i
b_alt = b = blz.to_i
if lut_aenderung_i(b) == "D"
  b = lut_nachfolge_blz_i(b)
  return [BLZ_MARKED_AS_DELETED, bic] if b == 0
end
```

Note: `b` may now differ from `b_alt` (successor BLZ) while the `blz`
String still holds the old BLZ. Mirror the C code exactly regarding when
the numeric `b`/`b_neu` is written back into the `blz` string (it does so
explicitly with `sprintf`/`strcpy` where required).

## Engine helpers available (`self` is the Engine)

| C call | Ruby |
|---|---|
| `lut_index(blz)` (idx or negative error) | `lut_index(blz)` -> Integer (>= 0) or negative error code |
| `pz_methoden[idx]` | `@data.pz[idx]` |
| `kto_check_pz("13a",kto,NULL)` | `kto_check_pz("13a", kto, nil)` -> Integer |
| `kto_check_blz(blz,kto)` | `kto_check_blz(blz, kto)` -> Integer |
| `lut_loeschung(blz,0,&ret)=='1'?1:0` (then `if(ret<OK)return ret;`) | `l, ret = lut_loeschung(blz, 0); loesch = l == 1 ? 1 : 0` |
| `lut_bic_int(blz,0,NULL)` | `lut_bic_int(blz, 0)[0]` -> String (11 chars) or nil |
| `lut_name(blz,0,NULL)` | `lut_name(blz, 0)[0]` |
| `lut_aenderung_i(b,0,NULL)` | `lut_aenderung_i(b)` -> one character String (e.g. "D") or nil |
| `lut_nachfolge_blz_i(b,0,NULL)` | `lut_nachfolge_blz_i(b)` -> Integer, 0 if none |
| `iban_init()` | `iban_init` -> Integer code |
| `iban_regel_cvt(blz,kto,bicp,rv,retvals)` (recursive call) | `r, bic2 = iban_regel_cvt(blz, kto, rv, retvals)` |

Everything else (tables of BLZs, account numbers, k2 ranges) is literal data
in the C source and must be transcribed exactly (double check every digit!).
Prefer Ruby `case`/`when` with integer literals and ranges over long
`if`/`elsif` chains where the C code uses `switch`.

## Style

2 spaces, `# frozen_string_literal: true`, no external gems. Keep a short
German comment `# IBAN-Regel NNNN.VV  Bankname` before each rule as in the C
source (`/* Iban-Regel 0005.03 */ /* Commerzbank AG */`); do not copy the
long explanatory comment blocks, but keep short comments that explain
non-obvious behaviour. A method longer than a few hundred lines is fine here
(the C function is one function), but you may split rules into private
methods `iban_regel_N(blz, kto, ...)`; if you do, take care that `b`, `k1`,
`k2`, `bic`, `version` etc. are passed in and that in-place String changes
and the `[ret, bic]` return value propagate correctly.

## Testing

The C reference driver `kc_ref` and the harness `tools/difftest_iban.rb`
compare `kto_check_regel_dbg()` and `iban_bic_gen()` of the C library with
the Ruby engine for many (blz, kto) pairs of all banks that have an IBAN
rule (the LUT file `test/fixtures/blz.lut2f` contains the rules):

```
ruby tools/difftest_iban.rb KC_REF test/fixtures/blz.lut2f 30 1 C_SOURCE
ruby tools/difftest_iban.rb KC_REF test/fixtures/blz.lut2f 30 2 C_SOURCE 5,20
```

(the last argument restricts the test to some rules). The numeric literals
of the C source are used as account numbers, so the special cases of the
rules are exercised. It must end with `ALL OK`. Run it with several seeds
and counts until it does. The C output is the ground truth. Do not modify
the harness, the engine or any other file than `iban_rules.rb`; if you
believe the engine has a bug that causes a mismatch (rather than your
port), report it with the exact case instead of working around it.
