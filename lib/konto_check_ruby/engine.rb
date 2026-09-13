# frozen_string_literal: true

# This file is part of konto_check_ruby, a Ruby port of the C library
# konto_check, Copyright (C) 2002-2023 Michael Plugge <konto_check@yahoo.com>.
# Ruby port Copyright (C) 2026 tickettoaster GmbH <https://tickettoaster.de>.
#
# konto_check_ruby is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2.1 of the License, or (at
# your option) any later version. It is distributed WITHOUT ANY WARRANTY; see
# the file LICENSE for details.

require_relative "retvals"
require_relative "lut_file"
require_relative "blz_file"
require_relative "bank_data"
require_relative "check_methods"
require_relative "collation"
require_relative "iban_rules"
require_relative "search"
require_relative "update"

module KontoCheckRuby
  # The Engine holds one loaded bank directory (BankData) and implements the
  # functions of the C library konto_check on top of it: account number
  # checks, IBAN generation/validation, lookups and searches.
  #
  # Method names and return conventions follow the C library closely; the
  # modules KontoCheckRaw and KontoCheck (see konto_check_ruby.rb) provide the
  # interface of the original Ruby gem on top of a default Engine instance.
  #
  # Functions that return a value plus a status return [value, status]
  # (the C functions take an `int *retval` parameter for the status).
  class Engine
    include IbanRules
    include Search

    DEFAULT_INIT_LEVEL = 5
    # The LUT file shipped with the gem; used whenever no file is given
    # explicitly (the C library searches ./blz.lut2f, /etc/blz.lut2f ...
    # instead).
    BUNDLED_LUT = File.expand_path("../../data/blz.lut2f", __dir__)
    EMPTY_BIC = BankData::EMPTY_BIC

    # Date of the check digit methods / IBAN rules implemented (from konto_check 6.15)
    PZ_METHODS_DATE = "09.12.2019"
    IBAN_RULES_DATE = "09.09.2019"
    C_LIBRARY_DATE = "13. April 2023"

    attr_reader :data
    # Fixed "current date" (Integer JJJJMMTT) for validity tests, nil = today
    attr_accessor :current_date

    def initialize
      @data = nil
      @encoding = 2 # UTF-8
      @pz_aenderungen_2019_12 = true
      @extra_init_done = 0
      @current_date = nil
      @level = -1
      reset_search_cache
    end

    # ------------------------------------------------------------ initialisation

    def initialized?
      !@data.nil?
    end

    # Loads a LUT file (lut_init in C). Without a file name the LUT file
    # bundled with the gem (BUNDLED_LUT) is loaded. level 0..9 selects the
    # blocks to load (see BlzFile::LUT_SETS), set 0 = automatically choose
    # the valid data set.
    # If the same file (by file id) is already loaded, only missing blocks are
    # loaded incrementally. Returns OK, LUT2_PARTIAL_OK, ... or an error code.
    def init(lut_name = nil, level = DEFAULT_INIT_LEVEL, set = 0)
      level = DEFAULT_INIT_LEVEL if level.nil?
      set = 0 if set.nil?
      lut_name = BUNDLED_LUT if lut_name.nil? || lut_name.to_s.empty?
      return NO_LUT_FILE unless File.file?(lut_name)
      required = required_blocks(level)
      if @data && @data.source == lut_name && !@data.lut_id.empty?
        id = file_id_of(lut_name, set)
        if id == @data.lut_id && (set == 0 || set == @data.set)
          return OK if level <= @level
          code = @data.load_blocks(required)
          @level = level if code > 0 || code == LUT2_PARTIAL_OK
          @extra_init_done = 0
          return code
        end
      end
      # (unlike the C library the previously loaded data is kept if the new
      # file cannot be loaded)
      code, data = BankData.from_lut(lut_name, required: required, set: set, current_date: today)
      if code > 0 || [LUT2_PARTIAL_OK, LUT2_NO_LONGER_VALID_PARTIAL_OK, LUT2_NOT_YET_VALID_PARTIAL_OK].include?(code)
        free
        @data = data
        @data.level = level
        @level = level
      end
      code
    end

    # Loads the bank directory directly from a Bundesbank file (TXT fixed
    # width, CSV or XML; no LUT file needed).
    #   gueltigkeit  validity "JJJJMMTT-JJJJMMTT" (optional; XML files carry
    #                their validity themselves)
    #   iban_rules   :default (built-in table of konto_check 6.15) applies
    #                IBAN rules to files without the IBAN rule column, false
    #                disables that, a Hash {blz => rule*100+version} or a
    #                file name supplies own rules
    def load_blz_file(filename, gueltigkeit: nil, iban_rules: :default)
      code, records, file_format, v1, v2 = BlzFile.parse_any(filename)
      return code unless code == OK
      if gueltigkeit && !gueltigkeit.empty?
        return LUT2_INVALID_GUELTIGKEIT unless gueltigkeit =~ /\A(\d{8})[ -](\d{8})\z/
        v1 = Regexp.last_match(1).to_i
        v2 = Regexp.last_match(2).to_i
        return LUT2_GUELTIGKEIT_SWAPPED if v2 < v1
      end
      if file_format != 2 && (table = BlzFile.iban_rule_table(iban_rules))
        BlzFile.apply_iban_rules!(records, table)
      end
      load_records(records, source: filename, valid_from: v1, valid_to: v2)
    end

    # Loads the current Bundesbank file from the local cache (see Update),
    # downloading it first if no cached file is valid for today (or for
    # current_date). If the download fails, the newest cached file is used,
    # and if there is none, the bundled LUT file. Returns the load status
    # (OK ...) or a negative code; the reason of a failed download is
    # available in #last_update_error.
    #   dir:     cache directory (default Update.cache_dir)
    #   format:  :xml (default), :txt or :csv
    #   refresh: :auto (download only if nothing valid is cached, default),
    #            :always (check the download page every time), :never
    def load_current(dir: Update.cache_dir, format: :xml, refresh: :auto, iban_rules: :default)
      @last_update_error = nil
      file = refresh == :always ? nil : Update.cached_file(dir: dir, current_date: today)
      if file.nil? && refresh != :never
        begin
          file = Update.update(dir: dir, format: format).path
        rescue Update::Error => e
          @last_update_error = e.message
          file = nil
        end
      end
      file ||= Update.cached_file(dir: dir)
      return init(BUNDLED_LUT, 9) if file.nil?
      load_blz_file(file, iban_rules: iban_rules)
    end

    # Message of the last failed download in load_current, or nil
    attr_reader :last_update_error

    # Loads the bank directory from an Array of BlzFile::BankRecord
    def load_records(records, source: nil, valid_from: 0, valid_to: 0)
      free
      @data = BankData.from_records(records, source: source, valid_from: valid_from, valid_to: valid_to)
      @data.level = 9
      @level = 9
      OK
    end

    # Releases the loaded data (lut_cleanup in C)
    def free
      @data = nil
      @level = -1
      @extra_init_done = 0
      reset_search_cache
      OK
    end

    # [filename, set, level, retval]
    def current_lutfile_name
      return [nil, 0, -1, LUT2_NOT_INITIALIZED] unless @data
      [@data.source, @data.set, @level, OK]
    end

    # Validity of the loaded data set for the current date
    def lut_valid
      return LUT2_NOT_INITIALIZED unless @data
      @data.valid(today)
    end

    # Info blocks: [code, info1, info2, valid1, valid2]. Without a file name
    # the info of the loaded data set is returned.
    def lut_info(lut_name = nil)
      if lut_name.nil? || lut_name.empty?
        return [LUT2_NOT_INITIALIZED, nil, nil, LUT2_NOT_INITIALIZED, LUT2_NOT_INITIALIZED] unless @data
        return [OK, @data.info_text, nil, @data.valid(today), LUT2_BLOCK_NOT_IN_FILE]
      end
      LutFile.info(lut_name, today)
    end

    # Status of the loaded blocks: [code, filename, blocks_ok, blocks_failed]
    def lut_blocks(mode = 1)
      return [LUT2_NOT_INITIALIZED, nil, nil, nil] unless @data
      ok = []
      fail = []
      offset = @data.set == 2 ? LutFile::SET_OFFSET : 0
      (1...LutFile::SET_OFFSET).each do |t|
        st = @data.block_status[t + offset] || @data.block_status[t]
        next if st.nil?
        name = LutFile.block_name(t + offset, mode)
        if st == OK
          ok << name
        else
          fail << name
        end
      end
      [fail.empty? ? OK : LUT2_BLOCKS_MISSING, @data.source, ok.join(", "), fail.join(", ")]
    end

    def dump_lutfile(lut_name)
      LutFile.dump(lut_name)
    end

    # generate_lut2_p in C
    def generate_lutfile(input, output, user_info = "", gueltigkeit = nil, felder = 9, filialen = false, set = 0)
      BlzFile.generate_lut(input, output, user_info: user_info.to_s, gueltigkeit: gueltigkeit,
                                          felder: felder.to_i, filialen: filialen.to_i != 0, set: set.to_i)
    end

    # Rebuilds a Bundesbank text file from the loaded data (rebuild_blzfile in C).
    # set 0: input is a Bundesbank file, 1/2: input is a LUT file (set 1/2).
    def rebuild_blzfile(input, output, set = 0)
      set = set.to_i
      if set == 0
        code = load_blz_file(input)
      else
        code = init(input, 9, set > 2 ? 2 : set)
      end
      return code if code <= 0 && code != LUT2_PARTIAL_OK
      d = @data
      File.open(output, "wb") do |out|
        d.cnt_hs.times do |i|
          s = d.startidx[i]
          d.filialen_at(i).times do |k|
            j = s + k
            regel = d.iban_regel ? d.iban_regel[j] : nil
            pan = (d.pan && d.pan[j] != 0) ? format("%05d", d.pan[j]) : ""
            nr = (d.nr && d.nr[j] != 0) ? format("%06d", d.nr[j]) : ""
            line = format("%8d%1s%-58s%05d%-35s%-27s%5s%-11s%2s%6s%1s%1s%08d",
                          d.blz[i], k == 0 ? "1" : "2", d.name ? d.name[j] : "", d.plz ? d.plz[j] : 0,
                          d.ort ? d.ort[j] : "", d.name_kurz ? d.name_kurz[j] : "", pan,
                          d.bic ? d.bic[j] : "", BlzFile.pz_to_string(d.pz[i]), nr,
                          d.aenderung ? d.aenderung[j] : " ", d.loeschung ? d.loeschung[j] : " ",
                          d.nachfolge_blz ? d.nachfolge_blz[j] : 0)
            line += format("%06d", regel) if regel
            out.write(line.encode("ISO-8859-1", undef: :replace) + "\n")
          end
        end
      end
      OK
    rescue SystemCallError
      FILE_WRITE_ERROR
    end

    # ------------------------------------------------------------- BLZ lookup

    # Index of a BLZ (String) in the main office arrays or a negative error
    # code (lut_index in C). Leading blanks/tabs are skipped, exactly 8 digits
    # followed by end of string, blank or tab are required.
    def lut_index(blz)
      return LUT2_NOT_INITIALIZED unless @data
      s = blz.to_s.sub(/\A[ \t]+/, "")
      m = s.match(/\A(\d{8})(?:[ \t]|\z)/)
      return INVALID_BLZ_LENGTH unless m
      @data.index(m[1].to_i) || INVALID_BLZ
    end

    def lut_index_i(blz_int)
      return LUT2_NOT_INITIALIZED unless @data
      return INVALID_BLZ_LENGTH if blz_int < 10_000_000 || blz_int > 99_999_999
      @data.index(blz_int) || INVALID_BLZ
    end

    # Tests whether a BLZ (and branch) exists (lut_blz in C)
    def lut_blz(blz, zweigstelle = 0)
      return LUT2_BLZ_NOT_INITIALIZED unless @data
      idx = lut_index(blz)
      return idx if idx < 0
      return LUT2_INDEX_OUT_OF_RANGE unless branch_ok?(idx, zweigstelle)
      OK
    end

    # [count, retval]
    def lut_filialen(blz)
      return [0, LUT2_BLZ_NOT_INITIALIZED] unless @data
      return [0, LUT2_FILIALEN_NOT_INITIALIZED] unless @data.filialen
      idx = lut_index(blz)
      return [0, idx] if idx < 0
      [@data.filialen[idx], OK]
    end

    def lut_name(blz, zweigstelle = 0)
      field_s(:name, LUT2_NAME_NOT_INITIALIZED, blz, zweigstelle)
    end

    def lut_name_kurz(blz, zweigstelle = 0)
      field_s(:name_kurz, LUT2_NAME_KURZ_NOT_INITIALIZED, blz, zweigstelle)
    end

    def lut_ort(blz, zweigstelle = 0)
      field_s(:ort, LUT2_ORT_NOT_INITIALIZED, blz, zweigstelle)
    end

    def lut_plz(blz, zweigstelle = 0)
      field_i(:plz, LUT2_PLZ_NOT_INITIALIZED, blz, zweigstelle)
    end

    def lut_pan(blz, zweigstelle = 0)
      field_i(:pan, LUT2_PAN_NOT_INITIALIZED, blz, zweigstelle)
    end

    def lut_nr(blz, zweigstelle = 0)
      field_i(:nr, LUT2_NR_NOT_INITIALIZED, blz, zweigstelle)
    end

    def lut_nachfolge_blz(blz, zweigstelle = 0)
      field_i(:nachfolge_blz, LUT2_NACHFOLGE_BLZ_NOT_INITIALIZED, blz, zweigstelle)
    end

    # [character "A"/"D"/"M"/"U", retval]
    def lut_aenderung(blz, zweigstelle = 0)
      v, r = field_s(:aenderung, LUT2_AENDERUNG_NOT_INITIALIZED, blz, zweigstelle)
      [v.nil? || v.empty? ? nil : v, r]
    end

    # [0/1, retval]
    def lut_loeschung(blz, zweigstelle = 0)
      v, r = field_s(:loeschung, LUT2_LOESCHUNG_NOT_INITIALIZED, blz, zweigstelle)
      [v.nil? || v.empty? ? nil : v.to_i, r]
    end

    # [check method (Integer), retval]
    def lut_pz(blz, zweigstelle = 0)
      return [0, LUT2_BLZ_NOT_INITIALIZED] unless @data
      return [0, LUT2_PZ_NOT_INITIALIZED] unless @data.pz
      idx = lut_index(blz)
      return [0, idx] if idx < 0
      return [0, LUT2_INDEX_OUT_OF_RANGE] unless branch_ok?(idx, zweigstelle)
      [@data.pz[idx], OK]
    end

    # [rule*100+version, retval]. Leading "@" or "+" in the BLZ are ignored.
    def lut_iban_regel(blz, zweigstelle = 0)
      ret = iban_init
      return [0, ret] if ret < OK
      return [0, LUT2_IBAN_REGEL_NOT_INITIALIZED] unless @data.iban_regel
      b = blz.to_s.sub(/\A[@+]+/, "")
      idx = lut_index(b)
      return [0, idx] if idx < 0
      return [0, LUT2_INDEX_OUT_OF_RANGE] unless branch_ok?(idx, zweigstelle)
      [@data.iban_regel[@data.startidx[idx] + zweigstelle], OK]
    end

    def lut_iban_regel_i(blz_int, zweigstelle = 0)
      return [0, LUT2_NOT_INITIALIZED] unless @data
      return [0, LUT2_IBAN_REGEL_NOT_INITIALIZED] unless @data.iban_regel
      idx = lut_index_i(blz_int)
      return [0, idx] if idx < 0
      return [0, LUT2_INDEX_OUT_OF_RANGE] unless branch_ok?(idx, zweigstelle)
      [@data.iban_regel[@data.startidx[idx] + zweigstelle], OK]
    end

    # BIC of a bank: [bic, retval]. If the BLZ has a successor BLZ, the BIC of
    # the successor is returned (retval OK_NACHFOLGE_BLZ_USED) unless the BLZ
    # starts with "!". retval is OK_INVALID_FOR_IBAN if an IBAN rule replaces
    # the BIC, OK_HYPO_REQUIRES_KTO for the rules 31..35.
    def lut_bic(blz, zweigstelle = 0)
      ret = iban_init
      return [nil, ret] if ret < OK
      bic, retval = lut_bic_int(blz, zweigstelle)
      regel, ret = lut_iban_regel(blz, 0)
      # like the C library the rule check is done even if the lookup failed
      # (the C function returns "" instead of NULL then)
      if ret == OK
        # The C library compares the raw value (rule * 100 + version) with
        # 31..35, so OK_HYPO_REQUIRES_KTO is practically never returned; this
        # is reproduced for compatibility.
        if regel >= 31 && regel <= 35
          retval = OK_HYPO_REQUIRES_KTO
        else
          b2 = blz.to_s.sub(/\A[!@+]+/, "").dup
          k2 = +"0000000000"
          _r, bic_neu = iban_regel_cvt(b2, k2, regel, nil)
          retval = OK_INVALID_FOR_IBAN if bic_neu && (bic || "").casecmp(bic_neu) != 0
        end
      end
      [bic, retval]
    end

    # BIC from the LUT data without IBAN rule check (lut_bic_int in C)
    def lut_bic_int(blz, zweigstelle = 0)
      return [nil, LUT2_BLZ_NOT_INITIALIZED] unless @data
      return [nil, LUT2_BIC_NOT_INITIALIZED] unless @data.bic
      b = blz.to_s
      force_old = false
      if b.start_with?("!")
        b = b[1..]
        force_old = true
      end
      idx = lut_index(b)
      return [nil, idx] if idx < 0
      return [nil, LUT2_INDEX_OUT_OF_RANGE] unless branch_ok?(idx, zweigstelle)
      return [nil, LUT2_NACHFOLGE_BLZ_NOT_INITIALIZED] if @data.nachfolge_blz.nil? && !force_old
      retval = OK
      if !force_old && @data.nachfolge_blz && (nb = @data.nachfolge_blz[@data.startidx[idx]]) != 0
        idx2 = lut_index_i(nb)
        return [nil, idx2] if idx2 < 0
        idx = idx2
        retval = OK_NACHFOLGE_BLZ_USED
      end
      [@data.bic[@data.startidx[idx] + zweigstelle], retval]
    end

    # BIC of the main office (lut_bic_h in C)
    def lut_bic_h(blz, zweigstelle = 0)
      return [nil, LUT2_BLZ_NOT_INITIALIZED] unless @data
      return [nil, LUT2_BIC_NOT_INITIALIZED] unless @data.bic_h
      b = blz.to_s
      force_old = false
      if b.start_with?("!")
        b = b[1..]
        force_old = true
      end
      idx = lut_index(b)
      return [nil, idx] if idx < 0
      return [nil, LUT2_INDEX_OUT_OF_RANGE] unless branch_ok?(idx, zweigstelle)
      return [nil, LUT2_NACHFOLGE_BLZ_NOT_INITIALIZED] if @data.nachfolge_blz.nil? && !force_old
      retval = OK
      if !force_old && @data.nachfolge_blz && (nb = @data.nachfolge_blz[@data.startidx[idx]]) != 0
        idx2 = lut_index_i(nb)
        return [nil, idx2] if idx2 < 0
        idx = idx2
        retval = OK_NACHFOLGE_BLZ_USED
      end
      [@data.bic_h[@data.startidx[idx] + zweigstelle], retval]
    end

    # Integer variants used by the IBAN rules
    def lut_aenderung_i(blz_int)
      return nil unless @data && @data.aenderung
      idx = lut_index_i(blz_int)
      return nil if idx < 0
      @data.aenderung[@data.startidx[idx]]
    end

    def lut_nachfolge_blz_i(blz_int)
      return 0 unless @data && @data.nachfolge_blz
      idx = lut_index_i(blz_int)
      return 0 if idx < 0
      @data.nachfolge_blz[@data.startidx[idx]]
    end

    # All fields of a bank (lut_multiple in C). Returns a Hash with
    # :retval, :cnt (branches), :idx and per field an Array over the branches
    # (:name, :name_kurz, :plz, :ort, :pan, :bic, :nr, :aenderung, :loeschung,
    # :nachfolge_blz, :iban_regel) plus :pz (one value). Fields of blocks that
    # are not loaded are nil (then :retval is LUT2_PARTIAL_OK).
    def lut_multiple(blz)
      return { retval: LUT2_NOT_INITIALIZED } unless @data
      idx = lut_index(blz)
      return { retval: idx } if idx < 0
      cnt = @data.filialen_at(idx)
      s = @data.startidx[idx]
      res = { retval: OK, cnt: cnt, idx: idx, blz: @data.blz[idx], pz: @data.pz ? @data.pz[idx] : nil }
      res[:retval] = LUT2_PARTIAL_OK if @data.pz.nil?
      %i[name name_kurz plz ort pan bic nr aenderung loeschung nachfolge_blz iban_regel].each do |f|
        arr = @data.public_send(f)
        if arr
          res[f] = arr[s, cnt]
        else
          res[f] = nil
          res[:retval] = LUT2_PARTIAL_OK
        end
      end
      res
    end

    # -------------------------------------------------------- account checks

    # Checks an account number with the check method of the given BLZ
    # (kto_check_blz in C).
    def kto_check_blz(blz, kto)
      return MISSING_PARAMETER if blz.nil? || kto.nil?
      return LUT2_NOT_INITIALIZED unless @data && @data.pz
      idx = lut_index(blz)
      return idx if idx < 0
      return BLZ_MARKED_AS_DELETED if @data.aenderung && @data.aenderung[@data.startidx[idx]] == "D"
      check_int(blz.to_s.strip, @data.pz[idx], kto, 0, nil)
    end

    # Same with debug information: [retval, Retvals]
    def kto_check_blz_dbg(blz, kto)
      rv = CheckMethods::Retvals.new("(-)", -1, -1, -1)
      return [MISSING_PARAMETER, rv] if blz.nil? || kto.nil?
      return [LUT2_NOT_INITIALIZED, rv] unless @data && @data.pz
      idx = lut_index(blz)
      return [idx, rv] if idx < 0
      [check_int(blz.to_s.strip, @data.pz[idx], kto, 0, rv), rv]
    end

    # Checks an account number with an explicitly given check method
    # ("00".."E4", optionally with sub-method letter, e.g. "51c"). The BLZ is
    # only needed for the methods 52, 53, B6 and C0 (kto_check_pz in C).
    def kto_check_pz(pz, kto, blz = nil, rv = nil)
      return MISSING_PARAMETER if pz.nil? || kto.nil?
      s = pz.to_s
      return UNDEFINED_SUBMETHOD if s.length > 3
      parsed = CheckMethods.parse_method(s)
      unless parsed
        return UNDEFINED_SUBMETHOD if s.length == 3
        return NOT_IMPLEMENTED
      end
      methode, um = parsed
      b = blz.to_s
      b = nil if b.empty? || b.start_with?("0")
      check_int(b, methode, kto, um, rv)
    end

    # [retval, Retvals]
    def kto_check_pz_dbg(pz, kto, blz = nil)
      rv = CheckMethods::Retvals.new("(-)", -1, -1, -1)
      [kto_check_pz(pz, kto, blz, rv), rv]
    end

    # Universal check (kto_check in C): pz_or_blz with 2 or 3 characters is a
    # check method, otherwise a BLZ.
    def kto_check(pz_or_blz, kto, lut_name = nil)
      return MISSING_PARAMETER if pz_or_blz.nil? || kto.nil?
      s = pz_or_blz.to_s
      if s.length == 2 || s.length == 3
        parsed = CheckMethods.parse_method(s)
        return NOT_IMPLEMENTED unless parsed
        return check_int(nil, parsed[0], kto, parsed[1], nil)
      end
      unless @data
        code = init(lut_name, 1, 0)
        return code if code <= 0 && code != LUT2_PARTIAL_OK && code != LUT1_SET_LOADED
        return LUT2_NOT_INITIALIZED unless @data
      end
      kto_check_blz(s, kto)
    end

    # Check with IBAN rules applied first (kto_check_regel in C)
    def kto_check_regel(blz, kto)
      kto_check_regel_dbg(blz, kto)[0]
    end

    # [retval, blz2, kto2, bic, regel*100+version, Retvals]
    def kto_check_regel_dbg(blz, kto)
      rv = CheckMethods::Retvals.new("-", -1, -1, -1)
      return [MISSING_PARAMETER, nil, nil, nil, 0, rv] if blz.nil? || kto.nil?
      k = kto.to_s
      return [INVALID_KTO_LENGTH, nil, nil, nil, 0, rv] if k.length > 10
      blz_n = blz.to_s[0, 8].dup
      kto_n = k.rjust(10, "0")
      blz_o = blz_n.dup
      kto_o = kto_n.dup
      regel, ret = lut_iban_regel(blz_n, 0)
      regel_out = ret > 0 ? regel : 0
      ret_regel, bic = iban_regel_cvt(blz_n, kto_n, regel, rv)
      bic ||= lut_bic(blz_n, 0)[0]
      return [ret_regel, blz_n, kto_n, bic, regel_out, rv] if ret_regel < OK
      ret, = kto_check_blz_dbg(blz_n, kto_n).then { |r, rv2| rv.methode = rv2.methode; rv.pz_methode = rv2.pz_methode; rv.pz = rv2.pz; rv.pz_pos = rv2.pz_pos; [r] }
      if blz_n != blz_o || kto_n != kto_o
        result = ret_regel > 3 ? ret_regel : ret
      else
        result = ret
      end
      [result, blz_n, kto_n, bic, regel_out, rv]
    end

    # ----------------------------------------------------------- IBAN, BIC

    # Generates the IBAN for a German bank account (iban_bic_gen in C).
    # Returns [retval, iban ("DE89 3704 0044 0532 0130 00" with blanks) or nil,
    # bic, blz2, kto2]. blz2/kto2 are the BLZ and account actually used
    # (they may have been replaced by IBAN rules). Prefixes for the BLZ:
    # "+" skip the account check, "@" ignore the blacklist, "!" do not
    # replace the BLZ by its successor.
    def iban_bic_gen(blz, kto)
      return [LUT2_NO_ACCOUNT_GIVEN, nil, nil, "", ""] if blz.nil? || kto.nil? || blz.to_s.empty? || kto.to_s.empty?
      ret = iban_init
      return [ret, nil, nil, nil, nil] if ret < OK
      b = blz.to_s
      flags = 0
      b.each_char do |c|
        break if c =~ /\d/
        flags |= 1 if c == "+"
        flags |= 2 if c == "@"
        flags |= 4 if c == "!"
      end
      b = b.sub(/\A[@+!]+/, "")
      blz2 = b.dup
      kto2 = kto.to_s.dup
      k = kto.to_s
      return [INVALID_KTO_LENGTH, nil, nil, blz2, kto2] if k.length > 10
      blz_i = b =~ /\A\d{8}\z/ ? b.to_i : 100_000_000
      blz_n = b.dup
      kto_n = k.rjust(10, "0")
      regel, ret = lut_iban_regel_i(blz_i, 0)
      if ret <= 0 && ret != LUT2_IBAN_REGEL_NOT_INITIALIZED
        return [ret, nil, nil, blz2, kto2]
      end
      bic = nil
      if ret != LUT2_IBAN_REGEL_NOT_INITIALIZED
        if regel == 0 && (flags & 2) == 0 && @data.own_iban && @data.own_iban.first == 2718281 && @data.own_iban.include?(blz_i)
          return [BLZ_BLACKLISTED, nil, nil, blz2, kto2]
        end
        ret_regel, bic = iban_regel_cvt(blz_n, kto_n, regel, nil)
        if ret_regel < OK
          bic ||= lut_bic(blz_n, 0)[0]
          bic = "" if bic.nil? || bic.start_with?("        ")
          return [ret_regel, nil, bic, blz_n, kto_n]
        end
      else
        regel = 0
        ret_regel = OK
      end
      flags |= 1 if ret_regel == OK_IBAN_WITHOUT_KC_TEST || ret_regel == OK_KTO_REPLACED_NO_PZ
      nb, ret = lut_nachfolge_blz(blz_n, 0)
      if regel == 0 && (flags & 4) == 0 && ret == OK && nb > 0
        ret_old = kto_check_blz(blz_n, kto_n)
        blz_n = format("%8d", nb)
        ret_neu = kto_check_blz(blz_n, kto_n)
        return [OLD_BLZ_OK_NEW_NOT, nil, nil, blz2, kto2] if ret_old == OK && ret_neu < OK
      end
      bic ||= lut_bic(blz_n, 0)[0]
      bic = "" if bic.nil? || bic.start_with?("        ")
      blz2 = blz_n
      kto2 = kto_n
      if (flags & 1) == 0
        ret = kto_check_blz(blz_n, kto_n)
        return [ret, nil, bic, blz2, kto2] if ret <= 0
      elsif ret_regel != OK_IBAN_WITHOUT_KC_TEST && ret_regel != OK_KTO_REPLACED_NO_PZ
        ret_regel = LUT2_KTO_NOT_CHECKED
      end
      bban = format("%8s%10s", blz_n, kto_n).tr(" ", "0")
      iban = "DE" + iban_checksum("DE", bban) + bban
      [ret_regel, iban.scan(/.{1,4}/).join(" "), bic, blz2, kto2]
    end

    # IBAN without blanks or nil (iban_gen in C): [iban, retval]
    def iban_gen(blz, kto)
      ret, iban, = iban_bic_gen(blz, kto)
      [iban&.delete(" "), ret]
    end

    # Checks an IBAN (checksum, length by country and for German IBANs also
    # the account number and the IBAN rules). Returns [retval, retval_kc]
    # where retval_kc is the result of the account check.
    def iban_check(iban)
      return [LUT2_NO_ACCOUNT_GIVEN, LUT2_NO_ACCOUNT_GIVEN] if iban.nil? || iban.to_s.empty?
      s = iban.to_s.gsub(/[^A-Za-z0-9]/, "")
      country = s[0, 2].to_s.upcase
      retval = LUT2_KTO_NOT_CHECKED
      expected = IBAN_LENGTHS[country]
      return [INVALID_IBAN_LENGTH, retval] if expected && s.length != expected
      test = iban_checksum_ok?(s) ? 1 : 0
      ret_kc = 0
      if country == "DE"
        digits = s[4..].to_s.gsub(/\D/, "")
        blz2 = digits[0, 8].to_s
        kto2 = digits[8, 10].to_s
        ret = ret_kc = kto_check_blz(blz2, kto2)
        test |= 2 if ret > 0
        retval = ret
        if test & 1 == 1
          j = lut_index(blz2)
          if j >= 0
            ret = iban_init
            return [ret, retval] if ret < OK
            uk = CheckMethods::UK_PZ_METHODEN.include?(@data.pz[j])
            nachfolge = @data.nachfolge_blz ? @data.nachfolge_blz[@data.startidx[j]] : 0
            regel = @data.iban_regel ? @data.iban_regel[@data.startidx[j]] : 0
            if uk || nachfolge != 0 || regel != 0
              ret, papier2, = iban_bic_gen(blz2, kto2)
              return [IBAN_CHKSUM_OK_NO_IBAN_CALCULATION, retval] if ret == NO_IBAN_CALCULATION
              test = 4 if ret == OK_IBAN_WITHOUT_KC_TEST || ret == OK_KTO_REPLACED_NO_PZ
              if papier2
                iban2 = papier2.delete(" ")
                if s.casecmp(iban2) != 0
                  if regel > 0
                    return [IBAN_CHKSUM_OK_RULE_IGNORED_BLZ, retval] if s[12..] == iban2[12..]
                    return [IBAN_CHKSUM_OK_RULE_IGNORED, retval]
                  elsif nachfolge != 0
                    return [IBAN_CHKSUM_OK_NACHFOLGE_BLZ_DEFINED, retval]
                  else
                    return [IBAN_CHKSUM_OK_UNTERKTO_MISSING, retval]
                  end
                end
              end
            end
          end
        end
      else
        test |= 2 if test != 0
        retval = NO_GERMAN_BIC
      end
      case test
      when 1
        if ret_kc == INVALID_BLZ
          [IBAN_CHKSUM_OK_BLZ_INVALID, retval]
        elsif ret_kc == LUT2_NOT_INITIALIZED
          [IBAN_CHKSUM_OK_KC_NOT_INITIALIZED, retval]
        else
          [IBAN_OK_KTO_NOT, retval]
        end
      when 2 then [KTO_OK_IBAN_NOT, retval]
      when 3 then [OK, retval]
      when 4 then [OK_IBAN_WITHOUT_KC_TEST, OK_NO_CHK]
      else [FALSE, retval]
      end
    end

    # BIC for a German IBAN: [bic, retval, blz, kto]
    def iban2bic(iban)
      s = iban.to_s.gsub(/[^A-Za-z0-9]/, "")
      return ["", IBAN2BIC_ONLY_GERMAN, "", ""] unless s[0, 2].to_s.casecmp("DE").zero?
      return ["", INVALID_IBAN_LENGTH, nil, nil] if s.length != 22
      digits = s[4..].gsub(/\D/, "")
      blz2 = digits[0, 8].to_s
      kto2 = digits[8, 10].to_s
      retval = OK
      j = lut_index(blz2)
      return ["", j, blz2, kto2] if j < 0
      if j > 0
        uk = CheckMethods::UK_PZ_METHODEN.include?(@data.pz[j])
        regel = @data.iban_regel ? @data.iban_regel[@data.startidx[j]] : 0
        if uk || regel != 0
          ret, papier, bic, = iban_bic_gen(blz2, kto2)
          retval = ret
          return [bic, OK, blz2, kto2] if ret == NO_IBAN_CALCULATION
          if papier
            iban2 = papier.delete(" ")
            if s.casecmp(iban2) != 0
              retval = regel > 0 ? IBAN_CHKSUM_OK_RULE_IGNORED : IBAN_CHKSUM_OK_UNTERKTO_MISSING
            end
          end
          return [bic, retval, blz2, kto2]
        end
      end
      bic, retval = lut_bic(blz2, 0)
      bic = "" if bic.nil? || bic.start_with?("        ")
      [bic, retval, blz2, kto2]
    end

    # Tests whether a German BIC exists: [retval, count]
    def bic_check(bic)
      s = bic.to_s
      return [BIC_ONLY_GERMAN, 0] unless s[4, 2].to_s.casecmp("DE").zero?
      return [INVALID_BIC_LENGTH, 0] unless s.length == 8 || s.length == 11
      code, hits = lut_suche_bic(s)
      return [FALSE, 0] if code == KEY_NOT_FOUND
      return [code, 0] if code < 0
      [OK, hits.size]
    end

    # Checks a SEPA creditor identifier (Gläubiger-Identifikationsnummer)
    def ci_check(ci)
      return MISSING_PARAMETER if ci.nil?
      s = ci.to_s.gsub(/[^A-Za-z0-9]/, "")
      return FALSE if s.length < 7
      numeric = to_numeric(s[7..].to_s) + to_numeric(s[0, 2]) + s[2, 2].to_s
      numeric.to_i % 97 == 1 ? OK : FALSE
    end

    # Generates a structured remittance information (IPI): [retval, ipi, ipi_papier]
    def ipi_gen(zweck)
      z = zweck.to_s
      return [IPI_INVALID_LENGTH, nil, nil] if z.length > 18
      return [IPI_INVALID_CHARACTER, nil, nil] unless z =~ /\A[0-9A-Za-z]*\z/
      body = z.upcase.rjust(18, "0")
      rest = (to_numeric(body) + "00").to_i % 97
      pz = 98 - rest
      dst = format("%02d%s", pz, body)
      [OK, dst, dst.scan(/.{1,4}/).join(" ")]
    end

    def ipi_check(zweck)
      s = zweck.to_s.delete(" \t")
      return IPI_CHECK_INVALID_LENGTH if s.length != 20
      numeric = to_numeric(s[2..]) + s[0, 2]
      numeric.to_i % 97 == 1 ? OK : FALSE
    end

    # IBAN length per country (ISO 3166 code)
    IBAN_LENGTHS = {
      "AL" => 28, "AD" => 24, "AZ" => 28, "BH" => 22, "BR" => 29, "BE" => 16, "BA" => 20, "BG" => 22,
      "CR" => 21, "DK" => 18, "DE" => 22, "DO" => 28, "EE" => 20, "FO" => 18, "FI" => 18, "FR" => 27,
      "GF" => 27, "PF" => 27, "TF" => 27, "GE" => 22, "GI" => 23, "GR" => 27, "GL" => 18, "GP" => 27,
      "GT" => 28, "HK" => 16, "IE" => 22, "IS" => 26, "IL" => 23, "IT" => 27, "VG" => 24, "KZ" => 20,
      "QA" => 29, "HR" => 21, "KW" => 30, "LV" => 21, "LB" => 28, "LI" => 21, "LT" => 20, "LU" => 20,
      "MT" => 31, "MA" => 24, "MQ" => 27, "MR" => 27, "MU" => 30, "YT" => 27, "MK" => 19, "MD" => 24,
      "MC" => 27, "ME" => 22, "NC" => 27, "NL" => 18, "NO" => 15, "AT" => 20, "PK" => 24, "PS" => 29,
      "PL" => 28, "PT" => 25, "RE" => 27, "RO" => 24, "BL" => 27, "MF" => 27, "SM" => 27, "SA" => 24,
      "SE" => 24, "CH" => 21, "RS" => 22, "SK" => 24, "SI" => 19, "ES" => 24, "PM" => 27, "CZ" => 24,
      "TN" => 24, "TR" => 26, "HU" => 28, "AE" => 23, "GB" => 22, "WF" => 27, "CY" => 28
    }.freeze

    # ------------------------------------------------------------- encoding

    # Output encoding of the descriptive texts (retval2txt) and of the fields
    # name, name_kurz, ort: 1 = ISO-8859-1, 2 = UTF-8 (default), 3 = HTML
    # entities, 4 = DOS CP850, 51..54 = short macro names for retval2txt with
    # the field encoding 1..4. mode 0 returns the current encoding.
    def encoding(mode = 0)
      case mode
      when 0 then return @encoding
      when 1, "i", "I" then @encoding = 1
      when 2, "u", "U" then @encoding = 2
      when 3, "h", "H" then @encoding = 3
      when 4, "d", "D" then @encoding = 4
      when 51, 52, 53, 54, "m", "M" then @encoding = mode.is_a?(Integer) ? mode : 51
      end
      @encoding
    end

    def encoding_str(mode = 0)
      case encoding(mode)
      when 1 then "ISO-8859-1"
      when 2 then "UTF-8"
      when 3 then "HTML entities"
      when 4 then "DOS CP-850"
      when 51 then "Makro/ISO-8859-1"
      when 52 then "Makro/UTF-8"
      when 53 then "Makro/HTML"
      when 54 then "Makro/DOS CP-850"
      else "Unbekannte Kodierung"
      end
    end

    # Converts a (UTF-8) string to the current output encoding
    def encode_out(str, enc = @encoding)
      return str if str.nil?
      case enc % 10
      when 1 then str.encode("ISO-8859-1", undef: :replace)
      when 3 then str.gsub(/[äöüÄÖÜß]/, HTML_ENTITIES)
      when 4 then str.encode("CP850", undef: :replace)
      else str
      end
    end

    HTML_ENTITIES = { "ä" => "&auml;", "ö" => "&ouml;", "ü" => "&uuml;", "Ä" => "&Auml;",
                      "Ö" => "&Ouml;", "Ü" => "&Uuml;", "ß" => "&szlig;" }.freeze

    def retval2txt(retval)
      return retval2txt_short(retval) if @encoding >= 50
      encode_out(retval2utf8(retval))
    end

    def retval2utf8(retval)
      RETVAL_TEXT.fetch(retval, RETVAL_UNKNOWN_TEXT)
    end

    def retval2iso(retval)
      retval2utf8(retval).encode("ISO-8859-1", undef: :replace)
    end

    def retval2dos(retval)
      retval2utf8(retval).encode("CP850", undef: :replace)
    end

    def retval2html(retval)
      RETVAL_HTML.fetch(retval) { retval2utf8(retval).gsub(/[äöüÄÖÜß]/, HTML_ENTITIES) }
    end

    def retval2txt_short(retval)
      RETVAL_SHORT.fetch(retval, RETVAL_UNKNOWN_SHORT)
    end

    # Enables/disables the check method changes of 2019-12-09 (only affects
    # the version string; the methods themselves are implemented).
    def pz_aenderungen_enable(set = -1)
      @pz_aenderungen_2019_12 = (set == 1) if set == 0 || set == 1
      @pz_aenderungen_2019_12 ? 1 : 0
    end

    def version(mode = 0)
      case mode
      when 1 then VERSION
      when 2 then VERSION_DATE
      when 3 then "#{VERSION_DATE}, 00:00:00"
      when 4 then @pz_aenderungen_2019_12 ? PZ_METHODS_DATE : "09.09.2019 (Aenderungen vom 09.12.2019 enthalten aber noch nicht aktiviert)"
      when 5 then IBAN_RULES_DATE
      when 6 then C_LIBRARY_DATE
      when 7 then "final"
      when 8 then VERSION.split(".")[0]
      when 9 then VERSION.split(".")[1]
      else "konto_check_ruby Version #{VERSION} vom #{VERSION_DATE}, Copyright (C) 2026 tickettoaster GmbH (Ruby-Port von konto_check #{C_LIBRARY_VERSION} vom #{C_LIBRARY_DATE}, Copyright (C) 2002-2023 Michael Plugge)"
      end
    end

    # ------------------------------------------------------------- internals

    # Loads the blocks needed for the IBAN functions if necessary (iban_init in C)
    def iban_init
      return LUT2_NOT_INITIALIZED unless @data
      return LUT2_NOT_ALL_IBAN_BLOCKS_LOADED if @extra_init_done < 0
      return OK if @extra_init_done > 0
      d = @data
      if d.loeschung.nil? || d.aenderung.nil? || d.iban_regel.nil? || d.bic.nil? || d.nachfolge_blz.nil?
        @extra_init_done = 1
        code = d.load_blocks(BlzFile::LUT_SET_IBAN + [LUT2_OWN_IBAN])
        reset_search_cache
        # Deviation from the C library: a missing IBAN_REGEL block is not
        # fatal here (the C library refuses all IBAN and BIC functions then);
        # without the block the standard rule 0 is used for all banks.
        if code < 0 && (d.loeschung.nil? || d.aenderung.nil? || d.bic.nil? || d.nachfolge_blz.nil?)
          @extra_init_done = -1
          return LUT2_NOT_ALL_IBAN_BLOCKS_LOADED
        end
      end
      @extra_init_done = 1
      OK
    end

    def today
      @current_date || LutFile.today_int
    end

    private

    def required_blocks(level)
      BlzFile::LUT_SETS[level] || BlzFile::LUT_SETS[9]
    end

    def file_id_of(lut_name, set)
      code, i1, i2, v1, v2 = LutFile.info(lut_name, today)
      return nil unless code == OK
      info = case set
             when 1 then i1
             when 2 then i2
             else
               if v1 == LUT2_VALID then i1
               elsif v2 == LUT2_VALID then i2
               elsif v1 == LUT2_NO_LONGER_VALID_BETTER then i1
               elsif v2 == LUT2_NO_LONGER_VALID_BETTER then i2
               else i1
               end
             end
      LutFile.file_id(info)
    end

    def branch_ok?(idx, zweigstelle)
      return false if zweigstelle < 0
      if @data.filialen
        zweigstelle < @data.filialen[idx]
      else
        zweigstelle == 0
      end
    end

    def field_s(field, error, blz, zweigstelle)
      return [nil, LUT2_BLZ_NOT_INITIALIZED] unless @data
      arr = @data.public_send(field)
      return [nil, error] unless arr
      idx = lut_index(blz)
      return [nil, idx] if idx < 0
      return [nil, LUT2_INDEX_OUT_OF_RANGE] unless branch_ok?(idx, zweigstelle)
      [arr[@data.startidx[idx] + zweigstelle], OK]
    end

    def field_i(field, error, blz, zweigstelle)
      return [0, LUT2_BLZ_NOT_INITIALIZED] unless @data
      arr = @data.public_send(field)
      return [0, error] unless arr
      idx = lut_index(blz)
      return [0, idx] if idx < 0
      return [0, LUT2_INDEX_OUT_OF_RANGE] unless branch_ok?(idx, zweigstelle)
      [arr[@data.startidx[idx] + zweigstelle], OK]
    end

    # kto_check_int prolog + dispatch
    def check_int(blz, pz_methode, kto, um, rv)
      digits = CheckMethods.normalize_kto(kto)
      return INVALID_KTO_LENGTH unless digits
      return INVALID_KTO if digits.any? { |d| d < 0 || d > 9 }
      CheckMethods.check_digits(pz_methode, digits, blz, um, rv)
    end

    # letters -> two digits (A=10 ... Z=35), digits unchanged, others dropped
    def to_numeric(str)
      str.each_char.map do |c|
        if c =~ /\d/ then c
        elsif c =~ /[A-Za-z]/ then (c.upcase.ord - 55).to_s
        else ""
        end
      end.join
    end

    def iban_checksum(country, bban)
      rest = (to_numeric(bban) + to_numeric(country) + "00").to_i % 97
      format("%02d", 98 - rest)
    end

    def iban_checksum_ok?(iban)
      return false if iban.length < 5
      (to_numeric(iban[4..]) + to_numeric(iban[0, 2]) + iban[2, 2]).to_i % 97 == 1
    end
  end
end
