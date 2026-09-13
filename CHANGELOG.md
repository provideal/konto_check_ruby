# Changelog

konto_check_ruby, Copyright (C) 2026 tickettoaster GmbH, LGPL 2.1 or later.

## 1.0.0 (2026-09-11)

First release. Pure Ruby port of konto_check 6.15 (C library by Michael
Plugge, 2023-04-13):

* check digit methods 00 to E4 with all sub-methods
* IBAN rules 0000 to 0057, IBAN generation and validation, iban2bic, BIC,
  creditor identifier and IPI checks
* LUT2 file reader and writer (both data sets, index blocks, info blocks,
  IBAN blacklist block)
* parser for the Bundesbank bank code files (TXT, CSV, XML), direct loading
  without LUT file, built-in IBAN rule table for files without rule column
* bank lookups and searches (name, short name, place, BIC, BLZ, PLZ, check
  method, IBAN rule, full text, combined searches)
* `KontoCheck` and `KontoCheckRaw` modules compatible with the konto_check gem
* command line tool `konto_check_ruby`
* bundled LUT file `data/blz.lut2f` generated from the current Bundesbank
  data (valid 2026-09-07 to 2026-12-06) with the IBAN rules of konto_check
  6.15, used by default
* self update: `KontoCheckRuby::Update` downloads the current Bundesbank file
  into a cache directory (optionally writing a LUT file), `Engine#load_current`
  loads it, CLI commands `update` and `-d current`
