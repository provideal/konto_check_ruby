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
require_relative "collation"

module KontoCheckRuby
  # Search functions of the C library (lut_suche_*): search banks by BIC,
  # name, short name, place, BLZ range, postal code range, check method and
  # IBAN rule, full text search and combined searches.
  #
  # All entries (main offices and branches) are addressed by a "flat index"
  # j in 0...cnt (the index into the per-branch arrays of BankData). Results
  # are returned as [code, hits] where hits is an Array of flat indexes in
  # the natural sort order of the search key (like the C library, whose
  # results are slices of the sort index arrays).
  module Search
    LUT_SUCHE_VOLLTEXT = 1
    LUT_SUCHE_BIC = 2
    LUT_SUCHE_NAMEN = 3
    LUT_SUCHE_NAMEN_KURZ = 4
    LUT_SUCHE_ORT = 5
    LUT_SUCHE_BLZ = 6
    LUT_SUCHE_PLZ = 7
    LUT_SUCHE_PZ = 8
    LUT_SUCHE_REGEL = 9
    LUT_SUCHE_BIC_H = 10

    VOLLTEXT_INVALID = ["-", "'", ",", ".", "+", "/", "&", "(", ")"].freeze

    # BLZ of the flat index j
    def blz_f(j)
      d = @data
      d.blz[d.startidx_r[j]]
    end

    # branch number of the flat index j
    def zweigstelle_f(j)
      @data.startidx_r ? j - @data.startidx[@data.startidx_r[j]] : 0
    end

    # check method of the flat index j
    def pz_f(j)
      @data.pz[@data.startidx_r[j]]
    end

    # [blz, zweigstelle, retval] for a flat index (konto_check_idx2blz in C)
    def idx2blz(j)
      return [0, 0, LUT2_NOT_INITIALIZED] unless @data
      return [0, 0, ARRAY_INDEX_OUT_OF_RANGE] if j < 0 || j >= @data.cnt
      [blz_f(j), zweigstelle_f(j), OK]
    end

    def lut_suche_bic(str)
      suche_str(str, :bic, LUT2_BIC_NOT_INITIALIZED)
    end

    def lut_suche_bic_h(str)
      suche_str(str, :bic_h, LUT2_BIC_NOT_INITIALIZED)
    end

    def lut_suche_namen(str)
      suche_str(str, :name, LUT2_NAME_NOT_INITIALIZED)
    end

    def lut_suche_namen_kurz(str)
      suche_str(str, :name_kurz, LUT2_NAME_KURZ_NOT_INITIALIZED)
    end

    def lut_suche_ort(str)
      suche_str(str, :ort, LUT2_ORT_NOT_INITIALIZED)
    end

    def lut_suche_blz(a1, a2 = 0)
      suche_int(a1, a2, :blz_f_values, nil)
    end

    def lut_suche_plz(a1, a2 = 0)
      return [LUT2_PLZ_NOT_INITIALIZED, []] if @data && @data.plz.nil?
      suche_int(a1, a2, :plz, LUT2_PLZ_NOT_INITIALIZED)
    end

    def lut_suche_pz(a1, a2 = 0)
      suche_int(a1, a2, :pz_f_values, nil)
    end

    # IBAN rule (without version)
    def lut_suche_regel(a1, a2 = 0)
      return [LUT2_NOT_INITIALIZED, []] unless @data
      return [LUT2_IBAN_REGEL_NOT_INITIALIZED, []] unless @data.iban_regel
      a2 = a1 if a2 == 0
      return [INVALID_SEARCH_RANGE, []] if a1 > a2
      suche_int(a1 * 100, a2 * 100 + 99, :iban_regel, LUT2_IBAN_REGEL_NOT_INITIALIZED)
    end

    # Full text search for one word in name, short name and place.
    # Returns [code, hits, words] where words are the matching index words.
    def lut_suche_volltext(word)
      return [LUT2_NOT_INITIALIZED, [], []] unless @data
      return [LUT2_NAME_NOT_INITIALIZED, [], []] if @data.name.nil? || @data.ort.nil? || @data.name_kurz.nil?
      w = word.to_s.strip
      return [LUT2_VOLLTEXT_INVALID_CHAR, [], []] if VOLLTEXT_INVALID.any? { |c| w.include?(c) }
      exact = w.start_with?("!")
      w = w[1..] if exact
      return [LUT2_VOLLTEXT_SINGLE_WORD_ONLY, [], []] unless w =~ /\A[[:alnum:]]+\z/
      key = Collation.sort_key(w)
      idx = volltext_index
      words = idx.keys.select { |k| exact ? k == key : k.start_with?(key) }.sort
      return [KEY_NOT_FOUND, [], []] if words.empty?
      hits = words.flat_map { |k| idx[k][:banks] }
      [OK, hits, words.map { |k| idx[k][:word] }]
    end

    # Combined search (lut_suche_multiple in C). such_str contains one or
    # more search terms separated by blanks, each optionally with an index
    # letter ("a:"), a leading "!" for exact matching, a range ("1000-2000")
    # and a field ("@bic", "@blz", "@name", "@kurz", "@ort", "@plz", "@pz",
    # "@regel", "@volltext"; default is the full text search). such_cmd
    # combines the terms: letters name the terms, "+" is OR, "-" is NOT,
    # e.g. "a b+c-d" = (a AND b) OR c AND NOT d. Without such_cmd all terms
    # are combined with AND.
    # Returns [code, Array of [blz, zweigstelle]] sorted by BLZ; with uniq
    # only one entry per BLZ.
    def lut_suche_multiple(such_str, uniq = false, such_cmd = nil)
      return [LUT2_NOT_INITIALIZED, []] unless @data
      s = such_str.to_s.strip
      return [OK, []] if s.empty?
      terms = {}
      key_not_found = false
      letter = "a"
      s.split(/\s+/).each do |term|
        break if letter > "z"
        exact = false
        if term.start_with?("!")
          exact = true
          term = term[1..]
        end
        idx = letter
        if term =~ /\A([A-Za-z]):(.*)\z/
          idx = Regexp.last_match(1).downcase
          term = Regexp.last_match(2)
        end
        field = "v"
        if term =~ /\A(.*)@([A-Za-z]+)\z/
          term = Regexp.last_match(1)
          field = Regexp.last_match(2).downcase
        end
        typ = case field
              when /\Abl/ then LUT_SUCHE_BLZ
              when /\Abi/ then LUT_SUCHE_BIC
              when /\Abh/ then LUT_SUCHE_BIC_H
              when /\Ak/ then LUT_SUCHE_NAMEN_KURZ
              when /\An/ then LUT_SUCHE_NAMEN
              when /\Ao/ then LUT_SUCHE_ORT
              when /\Apl/ then LUT_SUCHE_PLZ
              when /\Ap[zr]/ then LUT_SUCHE_PZ
              when /\Ar/ then LUT_SUCHE_REGEL
              else LUT_SUCHE_VOLLTEXT
              end
        i1, i2 = term.split("-", 2).map(&:to_i)
        i2 ||= 0
        txt = (exact ? "!" : "") + term.split("-", 2).first.to_s
        code, hits = case typ
                     when LUT_SUCHE_VOLLTEXT then lut_suche_volltext(txt).first(2)
                     when LUT_SUCHE_BIC then lut_suche_bic(txt)
                     when LUT_SUCHE_BIC_H then lut_suche_bic_h(txt)
                     when LUT_SUCHE_NAMEN then lut_suche_namen(txt)
                     when LUT_SUCHE_NAMEN_KURZ then lut_suche_namen_kurz(txt)
                     when LUT_SUCHE_ORT then lut_suche_ort(txt)
                     when LUT_SUCHE_BLZ then lut_suche_blz(i1, i2)
                     when LUT_SUCHE_PLZ then lut_suche_plz(i1, i2)
                     when LUT_SUCHE_PZ then lut_suche_pz(i1, i2)
                     when LUT_SUCHE_REGEL then lut_suche_regel(i1, i2)
                     end
        return [code, []] if code < 0 && code != KEY_NOT_FOUND
        key_not_found = true if code == KEY_NOT_FOUND
        terms[idx] = hits.to_a
        letter = letter.succ
      end
      cmd = such_cmd.to_s.strip
      cmd = terms.keys.join if cmd.empty?
      result = nil
      group = nil
      negate = false
      apply = lambda do
        group ||= []
        result = if result.nil?
                   negate ? (all_indexes - group) : group
                 elsif negate
                   result - group
                 else
                   result | group
                 end
        group = nil
      end
      cmd.each_char do |c|
        case c
        when "+"
          apply.call
          negate = false
        when "-"
          apply.call
          negate = true
        when " "
          next
        else
          return [LUT_SUCHE_INVALID_CMD, []] unless c =~ /[A-Za-z]/
          hits = terms[c.downcase]
          return [LUT_SUCHE_INVALID_CMD, []] if hits.nil?
          group = group.nil? ? hits.dup : (group & hits)
        end
      end
      apply.call
      result = result.to_a.sort
      if uniq
        seen = {}
        result = result.reject { |j| b = blz_f(j); seen.key?(b) ? true : (seen[b] = true; false) }
      end
      out = result.map { |j| [blz_f(j), zweigstelle_f(j)] }
      [key_not_found ? SOME_KEYS_NOT_FOUND : OK, out]
    end

    # Banks with a given BIC (bic_info in C). mode 0: main office BICs first,
    # then all BICs, then with branch code "XXX"; 1: all BICs; 2: main office
    # BICs only. Returns [retval, count, start_idx] where start_idx is an
    # opaque handle for the biq_* functions (positive: main office BIC index,
    # negative: BIC index; 0 = nothing found).
    def bic_info(bic, mode = 0)
      s = bic.to_s
      case mode
      when 1
        code, hits = lut_suche_bic(s)
        return [code, 0, 0] if hits.empty?
        [code, hits.size, -(bic_sort_position(:bic, hits.first) + 1)]
      when 2
        code, hits = lut_suche_bic_h(s)
        return [code, 0, 0] if hits.empty?
        [code, hits.size, bic_sort_position(:bic_h, hits.first) + 1]
      else
        code, hits = lut_suche_bic_h(s)
        return [code, hits.size, bic_sort_position(:bic_h, hits.first) + 1] unless hits.empty?
        code, hits = lut_suche_bic(s)
        return [code, hits.size, -(bic_sort_position(:bic, hits.first) + 1)] unless hits.empty?
        code, hits = lut_suche_bic(s[0, 8].to_s + "XXX")
        return [code, 0, 0] if hits.empty?
        [code >= OK ? OK_SHORT_BIC_USED : code, hits.size, -(bic_sort_position(:bic, hits.first) + 1)]
      end
    end

    # Flat index for a biq handle (see bic_info) or a negative error code
    def biq_index(idx)
      return LUT2_NOT_INITIALIZED unless @data
      return INVALID_BIQ_INDEX if idx == 0
      if idx > 0
        sorted = sort_index(:bic_h)
        return LUT2_INDEX_OUT_OF_RANGE if sorted.nil? || idx - 1 >= sorted.size
        sorted[idx - 1]
      else
        sorted = sort_index(:bic)
        return LUT2_INDEX_OUT_OF_RANGE if sorted.nil? || -idx - 1 >= sorted.size
        sorted[-idx - 1]
      end
    end

    # Field of a bank addressed by biq handle: [value, retval]
    def biq_field(field, idx)
      return [nil, LUT2_NOT_INITIALIZED] unless @data
      j = biq_index(idx)
      return [nil, j] if j < 0
      value = case field
              when :pz then @data.pz[@data.startidx_r[j]]
              when :blz then blz_f(j)
              else
                arr = @data.public_send(field)
                return [nil, field_error(field)] unless arr
                arr[j]
              end
      [value, OK]
    end

    # Field of a bank addressed by BIC: [value, retval]
    def bic_field(field, bic, mode = 0, filiale = 0)
      return [nil, LUT2_NOT_INITIALIZED] unless @data
      return [nil, field_error(field)] if field != :pz && field != :blz && @data.public_send(field).nil?
      ret1, cnt, start = bic_info(bic, mode)
      return [nil, ret1] if ret1 < 0
      return [nil, LUT2_INDEX_OUT_OF_RANGE] if filiale >= cnt
      handle = start > 0 ? start + filiale : start - filiale
      value, ret2 = biq_field(field, handle)
      [value, ret2 < 0 ? ret2 : ret1]
    end

    def reset_search_cache
      @sort_cache = {}
      @volltext_index = nil
      @blz_f_values = nil
      @pz_f_values = nil
    end

    private

    def field_error(field)
      { name: LUT2_NAME_NOT_INITIALIZED, name_kurz: LUT2_NAME_KURZ_NOT_INITIALIZED, ort: LUT2_ORT_NOT_INITIALIZED,
        plz: LUT2_PLZ_NOT_INITIALIZED, pan: LUT2_PAN_NOT_INITIALIZED, bic: LUT2_BIC_NOT_INITIALIZED,
        bic_h: LUT2_BIC_NOT_INITIALIZED, nr: LUT2_NR_NOT_INITIALIZED, aenderung: LUT2_AENDERUNG_NOT_INITIALIZED,
        loeschung: LUT2_LOESCHUNG_NOT_INITIALIZED, nachfolge_blz: LUT2_NACHFOLGE_BLZ_NOT_INITIALIZED,
        iban_regel: LUT2_IBAN_REGEL_NOT_INITIALIZED }[field] || LUT2_NOT_INITIALIZED
    end

    def all_indexes
      (0...@data.cnt).to_a
    end

    def blz_f_values
      @blz_f_values ||= (0...@data.cnt).map { |j| blz_f(j) }
    end

    def pz_f_values
      @pz_f_values ||= (0...@data.cnt).map { |j| pz_f(j) }
    end

    def field_values(field)
      case field
      when :blz_f_values then blz_f_values
      when :pz_f_values then pz_f_values
      else @data.public_send(field)
      end
    end

    # flat indexes sorted by the (folded) field value, stable
    def sort_index(field)
      @sort_cache[field] ||= begin
        values = field_values(field)
        return nil if values.nil?
        if values.first.is_a?(String)
          keys = values.map { |v| Collation.sort_key(v) }
          (0...values.size).sort_by { |i| [keys[i], i] }
        else
          (0...values.size).sort_by { |i| [values[i], i] }
        end
      end
    end

    def sort_keys(field)
      @sort_cache[[:keys, field]] ||= field_values(field).map { |v| Collation.sort_key(v) }
    end

    def bic_sort_position(field, j)
      sort_index(field).index(j)
    end

    # Prefix search in a string field. A leading "!" requests an exact match.
    def suche_str(str, field, error)
      return [LUT2_NOT_INITIALIZED, []] unless @data
      return [error, []] if @data.public_send(field).nil?
      s = str.to_s.lstrip
      exact = false
      if s.start_with?("!")
        exact = true
        s = s[1..]
      end
      key = Collation.sort_key(s)
      keys = sort_keys(field)
      sorted = sort_index(field)
      # binary search for the first key >= search key, then collect the range
      lo = 0
      hi = sorted.size
      while lo < hi
        mid = (lo + hi) / 2
        if keys[sorted[mid]] < key then lo = mid + 1 else hi = mid end
      end
      hits = []
      i = lo
      while i < sorted.size
        k = keys[sorted[i]]
        break unless exact ? k == key : k.start_with?(key)
        hits << sorted[i]
        i += 1
      end
      return [KEY_NOT_FOUND, []] if hits.empty?
      [OK, hits]
    end

    # Range search in an integer field
    def suche_int(a1, a2, field, error)
      return [LUT2_NOT_INITIALIZED, []] unless @data
      a1 = a1.to_i
      a2 = a2.to_i
      a2 = a1 if a2 == 0
      return [INVALID_SEARCH_RANGE, []] if a1 > a2
      values = field_values(field)
      return [error, []] if values.nil?
      sorted = sort_index(field)
      lo = 0
      hi = sorted.size
      while lo < hi
        mid = (lo + hi) / 2
        if values[sorted[mid]] < a1 then lo = mid + 1 else hi = mid end
      end
      hits = []
      i = lo
      while i < sorted.size && values[sorted[i]] <= a2
        hits << sorted[i]
        i += 1
      end
      return [KEY_NOT_FOUND, []] if hits.empty?
      [OK, hits]
    end

    # word key -> { word:, banks: [flat indexes] }
    def volltext_index
      @volltext_index ||= begin
        idx = {}
        d = @data
        d.cnt.times do |j|
          seen = {}
          [d.name[j], d.ort[j], d.name_kurz[j]].each do |field|
            Collation.words(field).each do |w|
              k = Collation.sort_key(w)
              next if seen[k]
              seen[k] = true
              e = (idx[k] ||= { word: w, banks: [] })
              e[:banks] << j
            end
          end
        end
        idx
      end
    end
  end
end
