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

require_relative "engine"

# KontoCheckRaw is the interface of the C extension of the original
# konto_check gem, implemented in pure Ruby on top of KontoCheckRuby::Engine.
# Function names, parameter handling and return values (mostly Arrays of
# [value, status]) follow the C extension konto_check_raw_ruby.c; the module
# KontoCheck (see konto_check.rb) offers the more Ruby-like interface.
#
# Return code constants (OK, FALSE, INVALID_BLZ, ...) are available as
# KontoCheckRaw::OK etc.
module KontoCheckRaw
  include KontoCheckRuby

  UNIQ_DEFAULT = 2
  DEFAULT_INIT_LEVEL = KontoCheckRuby::Engine::DEFAULT_INIT_LEVEL

  class << self
    # The engine behind the module functions (KontoCheckRuby.engine by default)
    def engine
      KontoCheckRuby.engine
    end

    # ---------------------------------------------------------------- init

    # init([p1 [,p2 [,set]]]) - p1/p2 are the LUT file name (String) and the
    # init level (Integer) in any order. Raises RuntimeError on errors.
    def init(*args)
      lut_name = nil
      level = DEFAULT_INIT_LEVEL
      set = 0
      unless args.empty? || args[0].nil?
        a1, a2, a3 = args
        t1 = arg_type(a1)
        t2 = arg_type(a2)
        raise TypeError, "wrong type for filename or init level" unless t1 + t2 == 3 || (t1 == 2 && a2.nil?)
        if t1 == 1
          level = a1.to_i
          lut_name = a2
        else
          lut_name = a1
          level = a2.to_i unless a2.nil?
        end
        set = a3.to_i unless a3.nil?
      end
      retval = engine.init(lut_name, level, set)
      runtime_error(retval) unless retval > 0 || partial_ok?(retval)
      retval
    end

    def current_lutfile_name
      engine.current_lutfile_name
    end

    def free
      engine.free
      true
    end

    def load_bank_data(_path)
      raise RuntimeError, "Perhaps you used the old interface of konto_check.\n" \
                          "Use KontoCheck::init() to initialize the library\n" \
                          "and check the order of function arguments for konto_test(blz,kto)"
    end

    # ------------------------------------------------------------- checks

    def konto_check(*args)
      blz, kto = params_blz_kto(args)
      if (blz.start_with?("0") || blz.length != 8) && engine.lut_blz(kto[2..].to_s, 0) == OK
        raise RuntimeError, "It seems that you use the old interface of konto_check?\n" \
                            "Please check the order of function arguments for konto_test(); should be (blz,kto)"
      end
      retval = engine.kto_check_blz(blz, kto)
      runtime_error(retval) if retval == LUT2_NOT_INITIALIZED || retval == MISSING_PARAMETER
      retval
    end

    def konto_check_pz(*args)
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 2..3)" unless (2..3).cover?(args.size)
      pz = args[0].is_a?(Numeric) ? format("%02d", args[0].to_i) : str_arg(args[0], "Unable to convert given value.")
      kto = kto_arg(args[1])
      blz = args[2].nil? ? nil : (args[2].is_a?(Numeric) ? args[2].to_i.to_s : str_arg(args[2], "Unable to convert given blz."))
      retval = engine.kto_check_pz(pz, kto, blz)
      runtime_error(retval) if retval == LUT2_NOT_INITIALIZED || retval == MISSING_PARAMETER
      retval
    end

    def konto_check_regel(*args)
      blz, kto = params_blz_kto(args)
      retval = engine.kto_check_regel(blz, kto)
      runtime_error(retval) if retval == LUT2_NOT_INITIALIZED || retval == MISSING_PARAMETER
      retval
    end

    # [retval, blz2, kto2, bic, regel, regel_version, methode, pz_methode, pz, pz_pos]
    def konto_check_regel_dbg(*args)
      blz, kto = params_blz_kto(args)
      retval, blz2, kto2, bic, regel, rv = engine.kto_check_regel_dbg(blz, kto)
      runtime_error(retval) if retval == LUT2_NOT_INITIALIZED || retval == MISSING_PARAMETER
      [retval, blz2.to_s, kto2.to_s, bic.to_s, regel / 100, regel % 100, rv.methode, rv.pz_methode, rv.pz, rv.pz_pos]
    end

    def pz_aenderungen_enable(*args)
      mode = args[0].nil? ? -1 : int_arg(args[0])
      engine.pz_aenderungen_enable(mode)
    end

    # ---------------------------------------------------------- bank data

    def bank_valid(*args)
      blz, filiale = params_blz_filiale(args)
      retval = engine.lut_blz(blz, filiale)
      runtime_error(retval) if retval == LUT2_BLZ_NOT_INITIALIZED
      retval
    end

    # [count, retval]
    def bank_filialen(*args)
      blz, = params_blz_filiale(args)
      cnt, retval = engine.lut_filialen(blz)
      runtime_error(retval) if retval == LUT2_BLZ_NOT_INITIALIZED || retval == LUT2_FILIALEN_NOT_INITIALIZED
      [retval <= 0 ? nil : cnt, retval]
    end

    # [retval, cnt, name, name_kurz, plz, ort, pan, bic, pz, nr, aenderung, loeschung, nachfolge_blz]
    def bank_alles(*args)
      blz, filiale = params_blz_filiale(args)
      m = engine.lut_multiple(blz)
      retval = m[:retval]
      runtime_error(retval) if retval == LUT2_BLZ_NOT_INITIALIZED
      return LUT2_INDEX_OUT_OF_RANGE if retval > 0 && (filiale < 0 || (m[:cnt] && filiale >= m[:cnt]))
      return [retval, nil] if retval <= 0 && retval != LUT2_PARTIAL_OK
      f = ->(key) { m[key] ? m[key][filiale] : nil }
      sv = ->(v) { v.nil? || v.to_s.empty? ? nil : engine.encode_out(v) }
      iv = ->(v) { v.nil? || v < 0 ? nil : v }
      [retval, iv.call(m[:cnt]), sv.call(f.call(:name)), sv.call(f.call(:name_kurz)), iv.call(f.call(:plz)),
       sv.call(f.call(:ort)), iv.call(f.call(:pan)), f.call(:bic), iv.call(m[:pz]), iv.call(f.call(:nr)),
       f.call(:aenderung), f.call(:loeschung), iv.call(f.call(:nachfolge_blz))]
    end

    def bank_name(*args)
      field_result(:lut_name, args, LUT2_NAME_NOT_INITIALIZED, encode: true)
    end

    def bank_name_kurz(*args)
      field_result(:lut_name_kurz, args, LUT2_NAME_KURZ_NOT_INITIALIZED, encode: true)
    end

    def bank_ort(*args)
      field_result(:lut_ort, args, LUT2_ORT_NOT_INITIALIZED, encode: true)
    end

    def bank_plz(*args)
      field_result(:lut_plz, args, LUT2_PLZ_NOT_INITIALIZED)
    end

    def bank_pan(*args)
      field_result(:lut_pan, args, LUT2_PAN_NOT_INITIALIZED)
    end

    def bank_bic(*args)
      field_result(:lut_bic, args, LUT2_BIC_NOT_INITIALIZED)
    end

    def bank_nr(*args)
      field_result(:lut_nr, args, LUT2_NR_NOT_INITIALIZED)
    end

    def bank_pz(*args)
      blz, = params_blz_filiale(args)
      pz, retval = engine.lut_pz(blz, 0)
      runtime_error(retval) if retval == LUT2_BLZ_NOT_INITIALIZED || retval == LUT2_PZ_NOT_INITIALIZED
      [retval <= 0 ? nil : pz, retval]
    end

    def bank_aenderung(*args)
      field_result(:lut_aenderung, args, LUT2_AENDERUNG_NOT_INITIALIZED)
    end

    def bank_loeschung(*args)
      field_result(:lut_loeschung, args, LUT2_LOESCHUNG_NOT_INITIALIZED)
    end

    def bank_nachfolge_blz(*args)
      field_result(:lut_nachfolge_blz, args, LUT2_NACHFOLGE_BLZ_NOT_INITIALIZED)
    end

    # -------------------------------------------------- bic_* / biq_* / iban_*

    # bic_info(bic [,mode]) -> [start_idx, cnt, retval]
    def bic_info(*args)
      bic = bic_arg(args[0], 11)
      mode = args[1].nil? ? 0 : int_arg(args[1])
      retval, cnt, start_idx = engine.bic_info(bic, mode)
      runtime_error(retval) if retval < 0 && retval != KEY_NOT_FOUND
      [retval < 0 ? nil : start_idx, cnt, retval]
    end

    %i[name name_kurz plz ort pan bic nr pz aenderung loeschung nachfolge_blz].each do |field|
      define_method(:"bic_#{field}") do |*args|
        bic = bic_arg(args[0], 11)
        mode = args[1].nil? ? 0 : int_arg(args[1])
        filiale = args[2].nil? ? 0 : int_arg(args[2])
        value, retval = engine.bic_field(field, bic, mode, filiale)
        runtime_error(retval) if retval < 0 && retval != KEY_NOT_FOUND
        [retval <= 0 ? nil : out_value(field, value), retval]
      end

      define_method(:"biq_#{field}") do |*args|
        idx = int_arg(args[0])
        value, retval = engine.biq_field(field, idx)
        runtime_error(retval) if retval < 0 && retval != KEY_NOT_FOUND
        [retval <= 0 ? nil : out_value(field, value), retval]
      end

      define_method(:"iban_#{field}") do |*args|
        iban = bic_arg(args[0], 22)
        filiale = args[1].nil? ? 0 : int_arg(args[1])
        unless iban[0, 2].to_s.casecmp("DE").zero?
          return [nil, IBAN_ONLY_GERMAN]
        end
        return [nil, INVALID_IBAN_LENGTH] unless iban.length == 22
        blz = iban[4, 8]
        value, retval = case field
                        when :pz then engine.lut_pz(blz, filiale)
                        else engine.public_send(:"lut_#{field}", blz, filiale)
                        end
        runtime_error(retval) if retval == LUT2_BLZ_NOT_INITIALIZED
        [retval <= 0 ? nil : out_value(field, value), retval]
      end
    end

    # ------------------------------------------------------------ LUT file

    # [dump, retval]
    def dump_lutfile(*args)
      name = str_arg(args[0], "wrong type for filename")
      retval, dump = engine.dump_lutfile(name)
      [retval <= 0 ? nil : dump, retval]
    end

    # lut_blocks([mode]) -> [retval, filename, blocks_ok, blocks_failed]
    def lut_blocks(*args)
      mode = args[0].nil? ? 1 : int_arg(args[0], "lut_blocks() requires an int parameter")
      retval, filename, ok, fail = engine.lut_blocks(mode)
      return [retval, nil, nil, nil] if retval == LUT2_NOT_INITIALIZED
      [retval, filename, ok, fail]
    end

    def lut_blocks1
      engine.lut_blocks(0)[0]
    end

    # lut_info([lutfile]) -> [retval, valid1, valid2, info1, info2]
    def lut_info(*args)
      name = args[0].nil? ? nil : str_arg(args[0], "wrong type for filename")
      retval, info1, info2, valid1, valid2 = engine.lut_info(name)
      runtime_error(retval) if retval < 0
      [retval, valid1, valid2, info1, info2]
    end

    def keep_raw_data(_mode)
      true
    end

    def encoding(*args)
      engine.encoding(enc_mode(args[0]))
    end

    def encoding_str(*args)
      engine.encoding_str(enc_mode(args[0]))
    end

    def retval2txt(retval) = engine.retval2txt(retval.to_i)
    def retval2iso(retval) = engine.retval2iso(retval.to_i)
    def retval2txt_short(retval) = engine.retval2txt_short(retval.to_i)
    def retval2dos(retval) = engine.retval2dos(retval.to_i)
    def retval2html(retval) = engine.retval2html(retval.to_i)
    def retval2utf8(retval) = engine.retval2utf8(retval.to_i)

    # generate_lutfile(inputfile, outputfile [,user_info [,gueltigkeit [,felder [,filialen [,set [,iban_blacklist]]]]]])
    def generate_lutfile(*args)
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 2..8)" unless (2..8).cover?(args.size)
      input = str_arg(args[0], "Unable to convert given input filename.")
      output = str_arg(args[1], "Unable to convert given output filename.")
      user_info = args[2].nil? ? "" : str_arg(args[2], "Unable to convert given user_info string.")
      gueltigkeit = args[3].nil? ? nil : str_arg(args[3], "Unable to convert given gueltigkeit string.")
      felder = args[4].nil? ? 9 : args[4].to_i
      filialen = args[5].nil? ? 0 : args[5].to_i
      set = args[6].nil? ? 0 : args[6].to_i
      retval = engine.generate_lutfile(input, output, user_info, gueltigkeit, felder, filialen, set)
      runtime_error(retval) if retval < 0
      if args[7] && !args[7].to_s.empty?
        KontoCheckRuby::LutFile.write_iban_blacklist(args[7].to_s, output, set)
      end
      retval
    end

    def rebuild_blzfile(*args)
      input = str_arg(args[0], "Unable to convert given input filename.")
      output = str_arg(args[1], "Unable to convert given output filename.")
      set = args[2].nil? ? 1 : args[2].to_i
      engine.rebuild_blzfile(input, output, set)
    end

    # ----------------------------------------------------------- IBAN etc.

    def ci_check(ci)
      return INVALID_PARAMETER_TYPE unless ci.is_a?(String)
      engine.ci_check(ci[0, 35])
    end

    # [retval, cnt]
    def bic_check(bic)
      return INVALID_PARAMETER_TYPE unless bic.is_a?(String)
      engine.bic_check(bic[0, 11])
    end

    # [retval, retval_kc]
    def iban_check(*args)
      iban = str_arg(args[0], "Unable to convert given value.")[0, 128]
      engine.iban_check(iban)
    end

    # [bic, retval, blz, kto]
    def iban2bic(*args)
      iban = str_arg(args[0], "Unable to convert given value.")[0, 128]
      bic, retval, blz, kto = engine.iban2bic(iban)
      [bic.nil? || bic.empty? ? nil : bic, retval, blz.nil? || blz.empty? ? nil : blz, kto.nil? || kto.empty? ? nil : kto]
    end

    # iban_gen(blz, kto) -> [iban, iban_papier, retval, bic, blz2, kto2, regel]
    def iban_gen(*args)
      blz, kto = params_blz_kto(args)
      retval, papier, bic, blz2, kto2 = engine.iban_bic_gen(blz, kto)
      if retval > 0
        regel = engine.lut_iban_regel(blz, 0)[0] / 100
        [papier.delete(" "), papier, retval, bic.to_s, blz2, kto2, regel]
      else
        [nil, nil, retval, nil, nil, nil, -1]
      end
    end

    # [ipi, ipi_papier, retval]
    def ipi_gen(*args)
      zweck = str_arg(args[0], "Unable to convert given value.")[0, 24]
      retval, dst, papier = engine.ipi_gen(zweck)
      retval == OK ? [dst, papier, retval] : [nil, nil, retval]
    end

    def ipi_check(*args)
      zweck = str_arg(args[0], "Unable to convert given value.")[0, 128]
      engine.ipi_check(zweck)
    end

    # ------------------------------------------------------------- search

    # bank_suche_xxx(value [,uniq [,sort]]) -> [values, blz, zweigstellen, retval, anzahl]
    def bank_suche_bic(*args) = suche_str(:lut_suche_bic, :bic, args)
    def bank_suche_namen(*args) = suche_str(:lut_suche_namen, :name, args)
    def bank_suche_namen_kurz(*args) = suche_str(:lut_suche_namen_kurz, :name_kurz, args)
    def bank_suche_ort(*args) = suche_str(:lut_suche_ort, :ort, args)

    def bank_suche_blz(*args) = suche_int(:lut_suche_blz, :blz, args)
    def bank_suche_plz(*args) = suche_int(:lut_suche_plz, :plz, args)
    def bank_suche_pz(*args) = suche_int(:lut_suche_pz, :pz, args)
    def bank_suche_regel(*args) = suche_int(:lut_suche_regel, :regel, args)

    # bank_suche_volltext(word [,uniq [,sort]]) -> [words, blz, zweigstellen, retval, anzahl]
    def bank_suche_volltext(*args)
      word, _cmd, uniq = params_suche(args)
      retval, hits, words = engine.lut_suche_volltext(word)
      return [nil, nil, nil, retval, 0] if retval == KEY_NOT_FOUND
      runtime_error(retval) if retval < 0
      blz, zw = shape_hits(hits, uniq)
      [words.map { |w| engine.encode_out(w) }, blz, zw, retval, blz.size]
    end

    # bank_suche_multiple(such_text [,such_cmd [,uniq]]) -> [nil, blz, zweigstellen, retval, anzahl]
    def bank_suche_multiple(*args)
      text, cmd, uniq = params_suche(args, maxlen: 1280)
      retval, pairs = engine.lut_suche_multiple(text, uniq > 1, cmd)
      return [nil, nil, nil, retval, 0] if retval == KEY_NOT_FOUND || pairs.empty?
      runtime_error(retval) if retval < 0
      [nil, pairs.map(&:first), pairs.map(&:last), retval, pairs.size]
    end

    # ------------------------------------------------------- SCL directory

    # The SCL directory (SEPA Clearer Verzeichnis) is not supported by the
    # Ruby port; the functions return the corresponding error codes.
    def scl_init(*_args) = NO_SCL_BLOCKS_LOADED
    def scl_multi(*_args) = [NO_SCL_BLOCKS_LOADED, nil, nil, nil]
    def scl_multi_blz(*_args) = [NO_SCL_BLOCKS_LOADED, nil, nil, nil]
    %w[sct sdd cor1 b2b scc].each do |flag|
      define_method(:"scl_#{flag}") { |*_args| [nil, NO_SCL_BLOCKS_LOADED] }
      define_method(:"scl_#{flag}_blz") { |*_args| [nil, NO_SCL_BLOCKS_LOADED, nil] }
    end

    def version(*args)
      engine.version(args[0].nil? ? 0 : args[0].to_i)
    end

    private

    def partial_ok?(retval)
      [LUT2_PARTIAL_OK, LUT2_NO_LONGER_VALID_PARTIAL_OK, LUT2_NOT_YET_VALID_PARTIAL_OK, LUT1_SET_LOADED].include?(retval)
    end

    def runtime_error(retval)
      raise RuntimeError, "KontoCheck::#{engine.retval2txt_short(retval)}, #{engine.retval2txt(retval)}"
    end

    def arg_type(v)
      case v
      when Numeric then 1
      when String then 2
      else 0
      end
    end

    def str_arg(v, msg)
      raise TypeError, msg unless v.is_a?(String)
      v
    end

    def int_arg(v, msg = "Unable to convert given value to int")
      raise TypeError, msg unless v.is_a?(Numeric)
      v.to_i
    end

    def bic_arg(v, maxlen)
      raise TypeError, "First parameter must be string." unless v.is_a?(String)
      v[0, maxlen]
    end

    def blz_arg(v)
      case v
      when String then v[0, 9]
      when Numeric then format("%08d", v.to_i)
      else raise TypeError, "Unable to convert given blz."
      end
    end

    def kto_arg(v)
      case v
      when String then v[0, 15]
      when Numeric then format("%010d", v.to_i)
      else raise TypeError, "Unable to convert given kto."
      end
    end

    def params_blz_kto(args)
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 2)" unless args.size == 2
      [blz_arg(args[0]), kto_arg(args[1])]
    end

    def params_blz_filiale(args)
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 1..2)" unless (1..2).cover?(args.size)
      [blz_arg(args[0]), args[1].nil? ? 0 : args[1].to_i]
    end

    def field_result(meth, args, error, encode: false)
      blz, filiale = params_blz_filiale(args)
      value, retval = engine.public_send(meth, blz, filiale)
      runtime_error(retval) if retval == LUT2_BLZ_NOT_INITIALIZED || retval == error
      value = engine.encode_out(value) if encode && value
      [retval <= 0 ? nil : value, retval]
    end

    def out_value(field, value)
      %i[name name_kurz ort].include?(field) ? engine.encode_out(value) : value
    end

    def enc_mode(v)
      return 0 if v.nil?
      case v
      when Numeric then v.to_i
      when String
        return v.to_i if v.to_i > 0
        if v[0] =~ /[mM]/
          case v[1]
          when "i", "I" then 51
          when "u", "U" then 52
          when "h", "H" then 53
          when "d", "D" then 54
          else 52
          end
        else
          v[0].to_s
        end
      else raise TypeError, "Unable to convert given value to int"
      end
    end

    # search parameters: (value [, such_cmd/uniq [, uniq/sort [, sort]]])
    def params_suche(args, maxlen: 128)
      raise ArgumentError, "search value missing" if args.empty?
      value = case args[0]
              when String then args[0][0, maxlen]
              when Numeric then args[0].to_s
              else raise TypeError, "Unable to convert given value."
              end
      cmd = ""
      uniq = -1
      sort = -1
      args[1..].to_a.each do |a|
        case a
        when nil then next
        when String then cmd = a[0, 255]
        when Numeric
          if uniq < 0 then uniq = a.to_i else sort = a.to_i end
        else raise TypeError, "Unable to convert given variable to integer or string"
        end
      end
      uniq = if uniq > 0 then 2
             elsif sort > 0 then 1
             elsif uniq < 0 && sort < 0 then UNIQ_DEFAULT
             else 0
             end
      [value, cmd, uniq]
    end

    # (a1 [, a2 [, uniq [, sort]]]) or ([a1, a2] [, uniq [, sort]]) or ("a1-a2" ...)
    def params_suche_int(args)
      raise ArgumentError, "search value missing" if args.empty?
      a = args.dup
      first = a.shift
      a1 = a2 = 0
      if first.is_a?(Array)
        a1 = first[0].to_i
        a2 = first[1].to_i
      elsif first.is_a?(String) && first.include?("-")
        p1, p2 = first.split("-", 2)
        a1 = p1.to_i
        a2 = p2.to_i
      else
        a1 = first.to_i
        if a.first.is_a?(Numeric) || (a.first.is_a?(String) && a.first =~ /\A\s*\d+\s*\z/)
          a2 = a.shift.to_i
        end
      end
      uniq = -1
      sort = -1
      a.each do |x|
        next if x.nil?
        v = x.to_i
        if uniq < 0 then uniq = v > 0 ? 2 : 0 else sort = v end
      end
      uniq = if uniq > 0 then 2
             elsif sort > 0 then 1
             elsif uniq < 0 && sort < 0 then UNIQ_DEFAULT
             else 0
             end
      [a1, a2, uniq]
    end

    # sorts/uniques flat indexes like lut_suche_sort1(); returns [blz, zweigstellen, ordered hits]
    def shape_hits(hits, uniq)
      ordered = hits
      if uniq > 0
        ordered = hits.sort_by { |j| [engine.blz_f(j), engine.zweigstelle_f(j), j] }
        if uniq > 1
          seen = {}
          ordered = ordered.reject { |j| b = engine.blz_f(j); seen.key?(b) ? true : (seen[b] = true; false) }
        end
      end
      [ordered.map { |j| engine.blz_f(j) }, ordered.map { |j| engine.zweigstelle_f(j) }, ordered]
    end

    def suche_str(meth, field, args)
      value, _cmd, uniq = params_suche(args)
      retval, hits = engine.public_send(meth, value)
      return [nil, nil, nil, retval, 0] if retval == KEY_NOT_FOUND
      runtime_error(retval) if retval < 0
      blz, zw, ordered = shape_hits(hits, uniq)
      values = ordered.map { |j| out_value(field, engine.data.public_send(field)[j]) }
      [values, blz, zw, retval, blz.size]
    end

    def suche_int(meth, field, args)
      a1, a2, uniq = params_suche_int(args)
      retval, hits = engine.public_send(meth, a1, a2)
      return [nil, nil, nil, retval, 0] if retval == KEY_NOT_FOUND
      runtime_error(retval) if retval < 0
      blz, zw, ordered = shape_hits(hits, uniq)
      values = case field
               when :blz then blz
               when :pz then ordered.map { |j| engine.pz_f(j) }
               when :plz then ordered.map { |j| engine.data.plz[j] }
               when :regel then ordered.map { |j| engine.data.iban_regel[j] / 100 }
               end
      [values, blz, zw, retval, blz.size]
    end
  end

  # all return codes as constants of this module (KontoCheckRaw::OK ...)
  KontoCheckRuby.constants.each do |c|
    v = KontoCheckRuby.const_get(c)
    const_set(c, v) if v.is_a?(Integer) && !const_defined?(c, false)
  end
end
