# konto_check_ruby

Copyright (C) 2026 tickettoaster GmbH. LGPL 2.1 or later.
Source: <https://github.com/provideal/konto_check_ruby>

A pure Ruby port of [konto_check](https://sourceforge.net/projects/kontocheck/),
Michael Plugge's C library for validating German bank accounts.
No C extension, no native dependencies.

* all check digit methods of the Deutsche Bundesbank (00 to E4, including
  all sub-methods) for German account numbers,
* IBAN generation and validation for German accounts including the
  Bundesbank IBAN rules (rules 0000 to 0057 as of konto_check 6.15),
  IBAN checksum validation for all countries,
* BIC, creditor identifier (Gläubiger-ID) and structured remittance (IPI)
  checks,
* bank directory lookups (name, BIC, place, postal code, successor BLZ, ...)
  and searches (by name, place, BIC, BLZ/PLZ ranges, full text),
* reads the **LUT files** of the original library (`blz.lut2f`, LUT format 2.x)
  and writes them (including the second data set and the index blocks),
* reads the **bank code files of the Deutsche Bundesbank** directly, in all
  three published formats (fixed width TXT, CSV, XML),
* drop-in compatible `KontoCheck` and `KontoCheckRaw` modules for users of
  the original [konto_check gem](https://rubygems.org/gems/konto_check).

The port is verified bit for bit against the C library: differential tests
compare millions of randomly generated account numbers for every check
method and sub-method, all IBAN rules and all bank lookups with the results
of the original code (see `tools/`).

## Installation

```ruby
gem "konto_check_ruby"
```

Requires Ruby >= 3.0, no other dependencies.

The version of the ported C library is available as
`KontoCheckRuby::C_LIBRARY_VERSION` (currently 6.15.0).

## Bank data

The library needs the bank directory of the Deutsche Bundesbank. Two sources
are supported:

1. **Bundesbank bank code files** ("Bankleitzahlendatei"), downloadable from
   [bundesbank.de](https://www.bundesbank.de/de/aufgaben/unbarer-zahlungsverkehr/serviceangebot/bankleitzahlen/download-bankleitzahlen-602592)
   as TXT (fixed width), CSV or XML. They are published quarterly and can be
   loaded directly:

   ```ruby
   engine = KontoCheckRuby::Engine.new
   engine.load_blz_file("blz-aktuell-txt-data.txt")     # or .csv / .xml
   ```

   Note: the current Bundesbank files no longer contain the IBAN rule
   column. konto_check_ruby therefore applies a built-in table of IBAN rules
   per BLZ (`data/iban_regeln.txt`, extracted from the LUT file of
   konto_check 6.15 with bank data of December 2025) to such files. Pass `iban_rules: false` to disable that
   or `iban_rules: "my_rules.txt"` / a Hash `{blz => rule * 100 + version}`
   to supply your own table.

2. **LUT files** of the original library (`blz.lut2f`). A LUT file is a
   compressed block format; it may contain two data sets with different
   validity periods, and the currently valid one is chosen automatically.
   The gem ships a LUT file generated from the current Bundesbank data
   (`data/blz.lut2f`, valid from 2026-09-07 to 2026-12-06, IBAN rules from
   the built-in table, see `data/README.md`). **It is the default:** `init`
   without a file name (or `KontoCheck.init` without arguments) loads it.
   You can also use the files distributed with konto_check or generate them
   yourself from a Bundesbank file:

   ```ruby
   KontoCheckRuby::BlzFile.generate_lut("blz-aktuell-txt-data.txt", "blz.lut2f",
                                        gueltigkeit: "20260907-20261206")
   engine.init("blz.lut2f")           # level 5 by default, 0..9 = amount of data loaded
   engine.init                        # the bundled data/blz.lut2f
   ```

   Files written by konto_check_ruby are readable by the C library and vice
   versa. XML files carry their validity period, for TXT/CSV files pass it
   with `gueltigkeit:` (format `JJJJMMTT-JJJJMMTT`).

Data older than its validity period still works; `lut_valid` (or
`KontoCheck.lut_info`) tells whether the loaded data set is current. The
test fixtures contain a LUT file from 2023 and a Bundesbank TXT file.

### Keeping the data current (self update)

The Bundesbank publishes a new bank code file every quarter (validity starts
in March, June, September and December). `KontoCheckRuby::Update` fetches the
current file from the
[download page](https://www.bundesbank.de/de/aufgaben/unbarer-zahlungsverkehr/serviceangebot/bankleitzahlen/download-bankleitzahlen-602592)
into a local cache directory (`$KONTO_CHECK_RUBY_CACHE`, else
`~/.cache/konto_check_ruby`) and the engine loads it directly:

```ruby
engine = KontoCheckRuby::Engine.new
engine.load_current                 # cached file valid today, downloaded if there is none
engine.lut_valid                    # => 4 (LUT2_VALID)

result = KontoCheckRuby::Update.update                   # download only if the file changed
result.status                                            # => :downloaded or :current
result.path                                              # => ".../blz-20260907-20261206.xml"
KontoCheckRuby::Update.update(lut: "blz.lut2f")          # additionally write a LUT file
```

`load_current(refresh: :auto)` (default) contacts the server only when no
cached file is valid for today; `refresh: :always` checks the download page
on every call, `refresh: :never` works offline. If a download fails, the
newest cached file is used, and without any cached file the bundled LUT
file; `engine.last_update_error` holds the reason. Network access uses only
the standard library (`net/http`); the download is about 5 MB for the XML
file (`format: :txt` or `:csv` are smaller but need the validity from the
download page).

On the command line: `konto_check_ruby update [LUTFILE]` downloads the
current file (and optionally writes a LUT file), `konto_check_ruby -d current
...` uses the cached current file for any command.

**LUT file or Bundesbank file?** For a pure Ruby application the LUT format
brings no advantage any more: loading the Bundesbank XML directly takes about
as long as loading a level 9 LUT file (70 ms), and all functions work the
same. The LUT format is still useful to exchange data with the C library or
its other ports, to bundle the data compactly (1 MB instead of 5 MB) and to
keep two data sets with different validity periods in one file, which is why
reading and writing it remains supported. The only thing the Bundesbank files
lack is the IBAN rule column, which the built-in rule table compensates.

## Usage

### Ruby API (`KontoCheckRuby::Engine`)

```ruby
require "konto_check_ruby"

engine = KontoCheckRuby::Engine.new
engine.init                                      # bundled data; or init("blz.lut2f", 9), load_blz_file("blz.txt")

engine.kto_check_blz("37040044", "532013000")    # => 1 (OK)
engine.kto_check_pz("13", "532013000")           # check with an explicit method
engine.kto_check_regel("10050000", "1111")       # with IBAN rules => 18 (OK_KTO_REPLACED)

engine.iban_check("DE89 3704 0044 0532 0130 00") # => [1, 1]  (IBAN status, account status)
engine.iban_gen("37040044", "532013000")         # => ["DE89370400440532013000", 1]
engine.iban_bic_gen("37040044", "532013000")     # => [1, "DE89 3704 0044 0532 0130 00", "COBADEFFXXX", "37040044", "0532013000"]
engine.iban2bic("DE89370400440532013000")        # => ["COBADEFFXXX", 1, "37040044", "0532013000"]
engine.bic_check("COBADEFFXXX")                  # => [1, count]
engine.ci_check("DE98ZZZ09999999999")            # creditor identifier => 1

engine.lut_name("37040044")                      # => ["Commerzbank", 1]
engine.lut_ort("37040044", 2)                    # branch 2 => ["Dormagen", 1]
engine.lut_bic("37040044")                       # => ["COBADEFFXXX", 1]
engine.lut_multiple("37040044")                  # Hash with all fields of all branches
engine.lut_suche_namen("Sparkasse")              # => [1, [flat indexes...]]
engine.lut_suche_multiple("Sparkasse Köln", true) # => [1, [[37050198, 0]]]

engine.retval2txt(-4)                            # => "die Bankleitzahl ist ungültig"
engine.retval2txt_short(-4)                      # => "INVALID_BLZ"
```

All return codes are integer constants in `KontoCheckRuby` (`OK = 1`,
`FALSE = 0`, `OK_NO_CHK = 2`, `INVALID_BLZ = -4`, ...), identical to the C
library. Values greater than 0 mean "ok" (possibly with a remark), 0 means
"wrong", negative values are errors. Functions that return a value and a
status return `[value, status]`.

Several engines with different data sets can be used side by side.

### Compatible API (`KontoCheck` / `KontoCheckRaw`)

The modules `KontoCheck` (Ruby-like, mostly plain values) and
`KontoCheckRaw` (arrays of `[value, status]`, like the C extension) have the
same functions, parameters and return values as the original gem, so
existing code keeps working:

```ruby
require "konto_check_ruby"

KontoCheck.init                                    # bundled data, or KontoCheck.init("blz.lut2f", 9)
KontoCheck.konto_check?("37040044", "532013000")   # => true
KontoCheck.konto_check("37040044", 532013000)      # => 1
KontoCheck.bank_name("37040044")                   # => "Commerzbank"
KontoCheck.bank_alles("37040044")                  # => [1, 17, "Commerzbank", "Commerzbank Köln", 50447, "Köln", ...]
KontoCheck.iban_gen(37040044, 532013000)           # => "DE89370400440532013000"
KontoCheck.iban_check("DE89370400440532013000")    # => 1
KontoCheck.suche(ort: "Köln", uniq: 1)             # => [37040044, ...]
KontoCheckRaw.bank_suche_namen("Postbank")         # => [names, blzs, branches, status, count]
KontoCheckRaw.iban_gen("37040044", "532013000")    # => [iban, iban_papier, status, bic, blz2, kto2, regel]
```

Both modules use a shared default engine (`KontoCheckRuby.engine`).

### Command line

```
konto_check_ruby check 37040044 532013000              # uses the bundled data, -d FILE for another
konto_check_ruby -d blz-aktuell-txt-data.txt iban DE89370400440532013000
konto_check_ruby iban-gen 10050000 1111
konto_check_ruby bank 37040044
konto_check_ruby search "Sparkasse Köln"
konto_check_ruby -g 20260907-20261206 generate-lut blz-aktuell-txt-data.txt blz.lut2f
konto_check_ruby dump blz.lut2f
```

## Performance

Measured in-process on the same 2023 LUT file (level 9), C library compiled
with `-O2`, Ruby 3.3 with and without YJIT, Apple Silicon.

One-time costs:

| | C library | Ruby port |
|---|---|---|
| `require "konto_check_ruby"` | – | 24 ms |
| init level 9 (all blocks) | 6 ms | 67 ms |
| init level 0 (BLZ and check methods only) | 0.5 ms | 5 ms |
| load a Bundesbank TXT file directly | – | 72 ms |
| first name search (builds the sort index once) | – | 35 ms |

Per call, microseconds (200,000 calls each):

| Function | C | Ruby | Ruby + YJIT |
|---|---|---|---|
| `kto_check_blz` (account check) | 0.03 | 2.8 | 1.5 |
| `kto_check_pz` | 0.02 | 2.8 | 1.5 |
| `iban_check` (German IBAN incl. rules) | 0.33 | 22 | 18 |
| `iban_bic_gen` | 0.14 | 12 | 8 |
| `lut_name` | 0.004 | 0.6 | 0.4 |
| `lut_bic` (with rule check) | 0.04 | 3.2 | 2.1 |
| `lut_suche_namen("Sparkasse")` | 55 | 126 | 48 |
| `KontoCheck.konto_check?` (compatibility layer) | – | 3.2 | 1.7 |

In relative terms the Ruby port is 50 to 100 times slower per call, in
absolute terms a single operation costs a few microseconds: an account
check takes about 3 µs, a complete IBAN check about 20 µs, which is not
noticeable next to a request or a database query. 1,000 account checks take
about 3 ms (C: 0.03 ms), 1,000 IBAN checks about 22 ms (C: 0.3 ms). The only
cost you can feel is initialisation (67 ms versus 6 ms), so load the data
once per process, as the default engine does, not per request. The C
figures are pure library calls; the C extension of the original gem adds
Ruby-to-C argument conversion on top, so the gap inside a Ruby application
is somewhat smaller.

## Differences to the C library / original gem

* Default output encoding is UTF-8 (the C library defaults to ISO-8859-1).
  `encoding("i")` etc. still switches the encoding of texts and names.
* Bank names, places etc. are returned as proper UTF-8 Ruby strings.
* The SCL directory functions (`scl_*`) are not implemented; they return
  `NO_SCL_BLOCKS_LOADED`.
* A missing IBAN rule block in a LUT file does not disable the IBAN functions
  (the C library refuses them); the standard rule is used instead.
* LUT files of the old format 1.x are not supported (`LUT1_FILE_USED`).
* Only zlib compressed (and uncompressed) LUT files are supported; bzip2,
  lzo and lzma compressed files return `KTO_CHECK_UNSUPPORTED_COMPRESSION`.
* Account numbers containing non-digit characters return `INVALID_KTO`
  (the C library computes with undefined values there).
* `lut_bic` with a branch index beyond the number of branches always returns
  `LUT2_INDEX_OUT_OF_RANGE` (the C library may return `OK_INVALID_FOR_IBAN`
  for banks with IBAN rules 31..35 due to an unterminated buffer).
* A failed `init` keeps the previously loaded data (the C library drops it).
* `init` without a file name loads the bundled LUT file (the C library
  searches `./blz.lut2f`, `/etc/blz.lut2f`, ... instead).
* If neither data set of a LUT file is currently valid, the younger one is
  loaded (the C library always falls back to the first set).

## Development

```
bundle install
rake test
```

The differential tests in `tools/` need the C library compiled as a small
test driver; see `tools/README.md`. `tools/PORTING_SPEC.md` and
`tools/IBAN_PORTING_SPEC.md` describe the porting rules that were followed.

## Copyright and license

Copyright (C) 2026 tickettoaster GmbH, <https://tickettoaster.de>.

konto_check_ruby is a derivative work of konto_check, Copyright (C)
2002-2023 Michael Plugge, and is licensed like the original under the GNU
Lesser General Public License, version 2.1 or (at your option) any later
version (see LICENSE and COPYRIGHT). The `KontoCheck` module is taken from the original
konto_check gem. The bank data in `data/` comes from the Deutsche Bundesbank
(see `data/README.md`).

Using the gem in your own application, also a closed source one, is
permitted by the LGPL as long as konto_check_ruby stays a separate library
(a gem dependency) whose source and license are available to the recipients
of your application; changes to konto_check_ruby itself must be published
under the LGPL. This is not legal advice.
