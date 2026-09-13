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

module KontoCheckRuby
  # In-memory representation of the bank directory: the arrays of the C
  # library (blz, pz_methoden, filialen, startidx, name, ort, ...) plus a hash
  # for the BLZ lookup. The data can be loaded either from a LUT2 file (block
  # by block, like kto_check_init() in C) or directly from the records of a
  # Bundesbank file (BlzFile.parse_file).
  #
  # Indexing follows the C library: the "main office" arrays (blz, pz,
  # filialen, startidx) are indexed 0...cnt_hs, the per-branch arrays (name,
  # name_kurz, plz, ort, pan, bic, nr, aenderung, loeschung, nachfolge_blz,
  # iban_regel) are indexed startidx[idx] + zweigstelle (0...cnt).
  class BankData
    # main office arrays
    attr_reader :cnt_hs, :cnt, :blz, :pz, :filialen, :startidx
    # per branch arrays (nil if the block was not loaded)
    attr_reader :name, :name_kurz, :plz, :ort, :pan, :bic, :bic_h, :nr, :aenderung, :loeschung,
                :nachfolge_blz, :iban_regel, :hs_idx, :startidx_r
    # IBAN blacklist (Array of BLZ Integers, first element 2718281 marks the list) or nil
    attr_reader :own_iban
    # meta data
    attr_reader :info, :valid_from, :valid_to, :lut_id, :block_status, :source, :set
    attr_accessor :level

    EMPTY_BIC = "           " # 11 blanks, like the C library for a missing BIC

    def initialize
      @cnt_hs = 0
      @cnt = 0
      @blz = []
      @pz = nil
      @filialen = nil
      @startidx = []
      @hs_idx = []
      @startidx_r = []
      @block_status = {}
      @info = nil
      @valid_from = 0
      @valid_to = 0
      @lut_id = ""
      @source = nil
      @set = 0
      @level = -1
      @index = {}
    end

    # ---------------------------------------------------------------- lookup

    # Index of a BLZ (Integer) in the main office arrays, or nil
    def index(blz_int)
      @index[blz_int]
    end

    def loaded?(typ)
      @block_status[typ] == OK
    end

    def branches?
      !@filialen.nil?
    end

    # Number of branches of the bank at idx (1 if the file has no branches)
    def filialen_at(idx)
      @filialen ? @filialen[idx] : 1
    end

    # Validity of the loaded data set for the given date (Integer JJJJMMTT)
    def valid(current_date)
      return LUT2_NO_VALID_DATE if @valid_from == 0 || @valid_to == 0
      return LUT2_VALID if current_date >= @valid_from && current_date <= @valid_to
      return LUT2_NOT_YET_VALID if current_date < @valid_from
      LUT2_NO_LONGER_VALID
    end

    # Info text of the loaded set plus the list of loaded blocks (lut_info in C)
    def info_text
      return nil unless @info
      loaded = (1..LutFile::SET_OFFSET - 1).select { |t| @block_status[t] == OK }.map { |t| LutFile.block_name(t) }
      "#{@info}\nin den Speicher geladene Blocks:\n    #{loaded.join(', ')}\n"
    end

    # ------------------------------------------------------ loading from LUT

    # Loads the requested blocks from a LUT2 file. required is an Array of
    # block types (the mandatory blocks BLZ, FILIALEN, PZ and AENDERUNG are
    # always added), set 0 selects the currently valid data set.
    # Returns [code, BankData]; code is OK, LUT2_PARTIAL_OK (some requested
    # blocks are missing) or an error code.
    def self.from_lut(filename, required: BlzFile::LUT_SETS[5], set: 0, current_date: LutFile.today_int)
      data = new
      code = data.load_lut(filename, required: required, set: set, current_date: current_date)
      [code, data]
    end

    def load_lut(filename, required:, set: 0, current_date: LutFile.today_int)
      return FILE_READ_ERROR unless File.file?(filename)
      code, info1, info2, v1, v2 = LutFile.info(filename, current_date)
      return code if [FILE_READ_ERROR, INVALID_LUT_FILE, LUT1_FILE_USED].include?(code)
      if code == OK
        if set == 0
          # the valid set; if none is valid the younger one (the C library
          # always falls back to the first set)
          set = if v1 == LUT2_VALID then 1
                elsif v2 == LUT2_VALID then 2
                elsif v1 == LUT2_NO_VALID_DATE then 1
                elsif v2 == LUT2_NO_VALID_DATE then 2
                elsif v2 == LUT2_NO_LONGER_VALID_BETTER then 2
                else 1
                end
        end
        @info = set == 1 ? info1 : info2
        return LUT2_BLOCK_NOT_IN_FILE unless @info
        @valid_from, @valid_to = LutFile.parse_validity(@info)
        @lut_id = LutFile.file_id(@info) || ""
      else
        set = 1 if set == 0
        @info = nil
        @valid_from = @valid_to = 0
        @lut_id = ""
      end
      @source = filename
      @set = set
      load_blocks(required)
    end

    # Loads further blocks from the LUT file the data came from (incremental
    # initialisation). Returns OK, LUT2_PARTIAL_OK or an error code.
    def load_blocks(required)
      return LUT2_NOT_INITIALIZED unless @source && File.file?(@source)
      offset = @set == 2 ? LutFile::SET_OFFSET : 0
      wanted = [LUT2_BLZ, LUT2_FILIALEN, LUT2_PZ, LUT2_AENDERUNG]
      required.each { |t| wanted << (t > LutFile::SET_OFFSET ? t - LutFile::SET_OFFSET : t) }
      wanted.uniq!
      alles_ok = true
      File.open(@source, "rb") do |io|
        code, dir = LutFile.read_directory(io)
        return code unless code == OK
        queue = wanted.dup
        until queue.empty?
          typ1 = queue.shift
          next if @block_status[typ1] == OK
          typ = typ1 + offset
          code, data = LutFile.read_block_io(io, dir, typ: typ)
          case code
          when OK
            @block_status[typ] = @block_status[typ1] = OK
            parse_block(typ1, data)
          when LUT2_BLOCK_NOT_IN_FILE
            if typ1 == LUT2_NAME_NAME_KURZ
              # name and short name may be stored in separate blocks
              queue.unshift(LUT2_NAME_KURZ)
              c2, d2 = LutFile.read_block_io(io, dir, typ: LUT2_NAME + offset)
              if c2 == OK
                @block_status[LUT2_NAME + offset] = @block_status[LUT2_NAME] = OK
                parse_block(LUT2_NAME, d2)
                next
              end
            elsif typ1 == LUT2_NAME || typ1 == LUT2_NAME_KURZ
              c2, d2 = LutFile.read_block_io(io, dir, typ: LUT2_NAME_NAME_KURZ + offset)
              if c2 == OK
                @block_status[LUT2_NAME_NAME_KURZ + offset] = @block_status[LUT2_NAME_NAME_KURZ] = OK
                parse_block(LUT2_NAME_NAME_KURZ, d2)
                next
              end
            elsif typ1 == LUT2_OWN_IBAN
              # the blacklist may be stored in the other set
              other = typ == LUT2_OWN_IBAN ? LUT2_2_OWN_IBAN : LUT2_OWN_IBAN
              c2, d2 = LutFile.read_block_io(io, dir, typ: other)
              if c2 == OK
                @block_status[typ] = @block_status[typ1] = OK
                parse_block(LUT2_OWN_IBAN, d2)
                next
              end
            end
            @block_status[typ] = @block_status[typ1] = code
            # missing branch counts or blacklist are not an error
            alles_ok = false unless [LUT2_FILIALEN, LUT2_OWN_IBAN].include?(typ1)
          when LUT2_FILE_CORRUPTED, KTO_CHECK_UNSUPPORTED_COMPRESSION
            @block_status[typ] = @block_status[typ1] = code
            return code
          else
            @block_status[typ] = @block_status[typ1] = code
            alles_ok = false
          end
        end
      end
      return LUT2_NOT_INITIALIZED if @blz.empty? || @pz.nil?
      finish_indexes
      return OK if alles_ok
      case valid(LutFile.today_int)
      when LUT2_NO_LONGER_VALID then LUT2_NO_LONGER_VALID_PARTIAL_OK
      when LUT2_NOT_YET_VALID then LUT2_NOT_YET_VALID_PARTIAL_OK
      else LUT2_PARTIAL_OK
      end
    rescue SystemCallError
      FILE_READ_ERROR
    end

    def parse_block(typ, data)
      case typ
      when LUT2_BLZ then parse_blz(data)
      when LUT2_FILIALEN then parse_filialen(data)
      when LUT2_PZ then @pz = data.unpack("C*")
      when LUT2_NAME
        strings = split_strings(data)
        @name = resolve_hs_names(strings)
      when LUT2_NAME_KURZ then @name_kurz = split_strings(data).map { |s| iso(s) }
      when LUT2_NAME_NAME_KURZ
        strings = split_strings(data)
        names = []
        kurz = []
        strings.each_slice(2) do |n, k|
          names << n
          kurz << (k || "")
        end
        @name = resolve_hs_names(names)
        @name_kurz = kurz.map { |s| iso(s) }
        @block_status[LUT2_NAME] = OK
        @block_status[LUT2_NAME_KURZ] = OK
      when LUT2_PLZ then @plz = unpack_u24(data)
      when LUT2_ORT then @ort = split_strings(data).map { |s| iso(s) }
      when LUT2_IBAN_REGEL then @iban_regel = unpack_u24(data)
      when LUT2_PAN then @pan = unpack_u24(data)
      when LUT2_BIC then parse_bic(data)
      when LUT2_NR then @nr = unpack_u24(data)
      when LUT2_AENDERUNG then @aenderung = data.chars.map { |c| c.force_encoding("UTF-8") }
      when LUT2_LOESCHUNG then @loeschung = data.chars.map { |c| c.force_encoding("UTF-8") }
      when LUT2_NACHFOLGE_BLZ then @nachfolge_blz = data.unpack("V*")
      when LUT2_OWN_IBAN
        cnt = data.unpack1("V")
        @own_iban = data.byteslice(4, cnt * 4).unpack("V*")
      end
    end

    private

    def iso(s)
      s.force_encoding("ISO-8859-1").encode("UTF-8")
    end

    def split_strings(data)
      # strings are NUL terminated; a trailing NUL produces no extra element
      parts = data.split("\0", -1)
      parts.pop if parts.last == ""
      parts
    end

    # Byte 1 at the start marks a main office name, an empty string means
    # "same name as the main office".
    def resolve_hs_names(strings)
      hs = ""
      strings.map do |s|
        if s.getbyte(0) == 1
          hs = iso(s.byteslice(1..))
          hs
        elsif s.empty?
          hs
        else
          iso(s)
        end
      end
    end

    def unpack_u24(data)
      out = []
      i = 0
      n = data.bytesize
      while i + 2 < n
        out << (data.getbyte(i) | (data.getbyte(i + 1) << 8) | (data.getbyte(i + 2) << 16))
        i += 3
      end
      out
    end

    def parse_blz(data)
      @cnt_hs, @cnt = data.unpack("vv")
      @blz = []
      pos = 4
      prev = 0
      while @blz.size < @cnt_hs && pos < data.bytesize
        j = data.getbyte(pos)
        pos += 1
        case j
        when 254
          prev += data.byteslice(pos, 2).unpack1("v")
          pos += 2
        when 255
          prev = data.byteslice(pos, 4).unpack1("V")
          pos += 4
        else
          prev += j
        end
        @blz << prev
      end
      @startidx = (0...@cnt_hs).to_a
      @index = {}
      @blz.each_with_index { |b, i| @index[b] = i }
    end

    def parse_filialen(data)
      @filialen = data.unpack("C*")
      j = 0
      @filialen.each_with_index do |f, i|
        @startidx[i] = i + j
        j += f - 1
      end
    end

    def parse_bic(data)
      @bic = []
      pos = 0
      n = data.bytesize
      while pos < n && @bic.size < [@cnt, 1].max
        c = data.getbyte(pos)
        if c == 0
          @bic << EMPTY_BIC
          pos += 1
        elsif c == 1
          @bic << data.byteslice(pos + 1, 11).force_encoding("UTF-8")
          pos += 12
        else
          s = data.byteslice(pos, 9)
          @bic << (s[0, 4] + "DE" + s[4, 5]).force_encoding("UTF-8")
          pos += 9
        end
      end
    end

    # Builds the reciprocal indexes (hs_idx, startidx_r) and bic_h.
    def finish_indexes
      # without the FILIALEN block only the main offices are in the arrays
      @cnt = @cnt_hs if @filialen.nil?
      @hs_idx = Array.new(@cnt, 0)
      @startidx_r = Array.new(@cnt, 0)
      @cnt_hs.times do |i|
        f = filialen_at(i)
        s = @startidx[i]
        f.times do |k|
          @hs_idx[s + k] = s
          @startidx_r[s + k] = i
        end
      end
      @bic_h = @bic ? @bic.each_index.map { |j| @bic[@hs_idx[j] || j] || EMPTY_BIC } : nil
    end

    public

    # ------------------------------------------- loading from Bundesbank data

    # Builds the data set directly from BankRecords (see BlzFile). All blocks
    # are available afterwards.
    def self.from_records(records, source: nil, info: nil, valid_from: 0, valid_to: 0)
      data = new
      data.load_records(records, source: source, info: info, valid_from: valid_from, valid_to: valid_to)
      data
    end

    def load_records(records, source: nil, info: nil, valid_from: 0, valid_to: 0)
      sorted = BlzFile.sort_records(records)
      @source = source
      @set = 1
      @cnt = sorted.size
      @blz = []
      @pz = []
      @filialen = []
      @startidx = []
      @index = {}
      sorted.each_with_index do |r, i|
        if @blz.last == r.blz
          @filialen[-1] += 1
          @pz[-1] = r.pz if @pz_from_branch && (r.hauptstelle == "1" || r.hauptstelle == "3")
        else
          @index[r.blz] = @blz.size
          @blz << r.blz
          @pz << r.pz
          @pz_from_branch = !(r.hauptstelle == "1" || r.hauptstelle == "3")
          @filialen << 1
          @startidx << i
        end
      end
      @pz_from_branch = nil
      @cnt_hs = @blz.size
      @name = sorted.map(&:name)
      @name_kurz = sorted.map(&:name_kurz)
      @plz = sorted.map(&:plz)
      @ort = sorted.map(&:ort)
      @pan = sorted.map(&:pan)
      @bic = sorted.map { |r| r.bic.empty? ? EMPTY_BIC : r.bic.ljust(11) }
      @nr = sorted.map(&:nr)
      @aenderung = sorted.map(&:aenderung)
      @loeschung = sorted.map(&:loeschung)
      @nachfolge_blz = sorted.map(&:nachfolge_blz)
      @iban_regel = sorted.map(&:iban_regel)
      [LUT2_BLZ, LUT2_FILIALEN, LUT2_PZ, LUT2_NAME, LUT2_NAME_KURZ, LUT2_NAME_NAME_KURZ, LUT2_PLZ, LUT2_ORT,
       LUT2_PAN, LUT2_BIC, LUT2_NR, LUT2_AENDERUNG, LUT2_LOESCHUNG, LUT2_NACHFOLGE_BLZ,
       LUT2_IBAN_REGEL].each { |t| @block_status[t] = OK }
      @valid_from = valid_from
      @valid_to = valid_to
      @info = info || format("Gueltigkeit der Daten: %08d-%08d (Erster Datensatz)\nEnthaltene Felder: BLZ, PZ, FILIALEN, AENDERUNG, NAME_NAME_KURZ, PLZ, ORT, IBAN_REGEL, BIC, NACHFOLGE_BLZ, LOESCHUNG, PAN, NR\n\nDatensatz aus %s\nAnzahl Banken: %d, davon Hauptstellen: %d\n",
                              valid_from, valid_to, source || "Bundesbank-Datei", @cnt, @cnt_hs)
      @lut_id = ""
      finish_indexes
      OK
    end
  end
end
