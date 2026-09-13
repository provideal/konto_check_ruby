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

require "zlib"
require_relative "retvals"

module KontoCheckRuby
  # Reader and writer for the LUT2 file format of konto_check
  # ("BLZ Lookup Table/Format 2.0").
  #
  # File layout:
  #
  #   text prolog (several lines, the first one is the signature), ending
  #   with a line "DATA"
  #   2 bytes   number of directory slots (little endian)
  #   slots*12  directory: per slot (type, file offset, compressed length),
  #             each an unsigned 32 bit little endian integer; type 0 = empty
  #   blocks    per block a 16 byte header (type, compressed length,
  #             uncompressed length, adler32 of the uncompressed data)
  #             followed by the (zlib compressed) block data
  #
  # All methods of this module return [return_code, value]; return_code is
  # one of the integer constants of KontoCheckRuby (OK or an error code).
  module LutFile
    SIGNATURE_V2 = "BLZ Lookup Table/Format 2."
    SIGNATURE_V1 = "BLZ Lookup Table/Format 1."
    MAX_SLOTS = 500
    SLOT_CNT_MIN = 60
    DEFAULT_SLOTS = 60
    SET_OFFSET = 100

    COMPRESSION_NAMES = {
      COMPRESSION_NONE => "keine",
      COMPRESSION_ZLIB => "zlib",
      COMPRESSION_BZIP2 => "bzip2",
      COMPRESSION_LZO => "lzo",
      COMPRESSION_LZMA => "lzma"
    }.freeze

    # Names of the block types as used in the info block and in lut_blocks()
    BLOCK_NAME1 = Hash.new("  (unbekannt)").merge(
      1 => "BLZ", 2 => "FILIALEN", 3 => "NAME", 4 => "PLZ", 5 => "ORT", 6 => "NAME_KURZ",
      7 => "PAN", 8 => "BIC", 9 => "PZ", 10 => "NR", 11 => "AENDERUNG", 12 => "LOESCHUNG",
      13 => "NACHFOLGE_BLZ", 14 => "NAME_NAME_KURZ", 15 => "INFO", 16 => "BIC_SORT",
      17 => "NAME_SORT", 18 => "NAME_KURZ_SORT", 19 => "ORT_SORT", 20 => "PLZ_SORT",
      21 => "PZ_SORT", 22 => "OWN_IBAN", 23 => "VOLLTEXT_TXT", 24 => "VOLLTEXT_IDX",
      25 => "IBAN_REGEL", 26 => "IBAN_REGEL_SORT", 27 => "BIC_H_SORT", 28 => "SCL_INFO",
      29 => "SCL_BIC", 30 => "SCL_NAME", 31 => "SCL_FLAGS", 32 => "SCL_FLAGS_ORIG"
    ).freeze

    BLOCK_NAME2 = Hash.new("  (unbekannt)").merge(
      0 => "leer",
      1 => "BLZ", 2 => "Anzahl Fil.", 3 => "Name", 4 => "Plz", 5 => "Ort", 6 => "Name (kurz)",
      7 => "PAN", 8 => "BIC", 9 => "Pruefziffer", 10 => "Lfd. Nr.", 11 => "Aenderung",
      12 => "Loeschung", 13 => "NachfolgeBLZ", 14 => "Name, Kurzn.", 15 => "Infoblock",
      16 => "BIC idx", 17 => "Name idx", 18 => "Kurzname idx", 19 => "Ort idx", 20 => "PLZ idx",
      21 => "PZ idx", 22 => "IBAN Blacklist", 23 => "Volltext txt", 24 => "Volltext idx",
      25 => "IBAN Regel", 26 => "IBAN Regel idx", 27 => "BIC Hauptst.idx", 28 => "SCL Infoblock",
      29 => "SCL BIC", 30 => "SCL Banknamen", 31 => "SCL Flags", 32 => "SCL Flags orig"
    ).freeze

    # Block types for which an index block is generated (lut_block_idx in C)
    BLOCKS_WITH_INDEX = [3, 4, 5, 6, 8, 9, 14].freeze

    # Human readable name of a block type (mode 1: short, 2: with set number,
    # 3: the C macro name)
    def self.block_name(typ, mode = 1)
      base = typ > SET_OFFSET && typ < 400 ? typ - SET_OFFSET : typ
      case mode
      when 2
        return "(Userblock)" if typ >= 400
        return BLOCK_NAME2[0] if typ == 0
        "#{typ > SET_OFFSET ? 2 : 1}. #{BLOCK_NAME2[base]}"
      when 3
        n = LUT_BLOCK_TYPES[typ]
        n ? "LUT2_#{typ > SET_OFFSET ? '2_' : ''}#{n}" : ""
      else
        typ > SET_OFFSET ? "#{BLOCK_NAME1[base]} (2)" : BLOCK_NAME1[base]
      end
    end

    # Adler-32 variant used by konto_check (adler32a in the C source). It
    # differs from the standard zlib adler32 in that the bytes are treated as
    # *signed* chars. It is kept for compatibility with existing LUT files.
    def self.adler32a(data, adler = 1)
      s1 = adler & 0xffff
      s2 = (adler >> 16) & 0xffff
      bytes = data.unpack("c*")
      i = 0
      n = bytes.length
      while i < n
        k = [n - i, 5552].min
        j = 0
        while j < k
          s1 = (s1 + bytes[i + j]) & 0xffffffff
          s2 = (s2 + s1) & 0xffffffff
          j += 1
        end
        i += k
        s1 %= 65521
        s2 %= 65521
      end
      (s2 << 16) | s1
    end

    # Parsed header/directory of a LUT file
    class Directory
      attr_reader :prolog_lines, :compression, :slots, :entries, :data_pos

      # entries: Array of [typ, offset, compressed_len]
      def initialize(prolog_lines, compression, slots, entries, data_pos)
        @prolog_lines = prolog_lines
        @compression = compression
        @slots = slots
        @entries = entries
        @data_pos = data_pos
      end

      # Slot index (0 based) of the *last* block of the given type, or nil
      def slot_of(typ)
        idx = nil
        @entries.each_with_index { |(t, _o, _l), i| idx = i if t == typ }
        idx
      end

      def free_slot
        @entries.index { |(t, _o, _l)| t == 0 }
      end

      def types
        @entries.map(&:first)
      end
    end

    # Reads the prolog and the directory. Returns [code, Directory].
    def self.read_directory(io)
      io.rewind
      first = io.gets
      return [INVALID_LUT_FILE, nil] unless first
      line = first.chomp
      return [LUT1_FILE_USED, nil] if line[0, SIGNATURE_V1.length] == SIGNATURE_V1
      return [INVALID_LUT_FILE, nil] unless line[0, SIGNATURE_V2.length] == SIGNATURE_V2
      prolog = [line]
      compression = 0
      loop do
        l = io.gets
        return [INVALID_LUT_FILE, nil] if l.nil?
        break if l == "DATA\n"
        prolog << l.chomp
        case l
        when "Kompression: keine\n" then compression = COMPRESSION_NONE
        when "Kompression: gzip\n" then compression = COMPRESSION_ZLIB
        when "Kompression: bzip2\n" then compression = COMPRESSION_BZIP2
        when "Kompression: lzo\n" then compression = COMPRESSION_LZO
        when "Kompression: lzma\n" then compression = COMPRESSION_LZMA
        end
      end
      compression = COMPRESSION_ZLIB if compression == 0
      hdr = io.read(2)
      return [LUT2_FILE_CORRUPTED, nil] if hdr.nil? || hdr.bytesize < 2
      slots = hdr.unpack1("v")
      dir_pos = io.pos
      dir = io.read(slots * 12)
      return [LUT2_FILE_CORRUPTED, nil] if dir.nil? || dir.bytesize != slots * 12
      entries = dir.unpack("V*").each_slice(3).to_a
      [OK, Directory.new(prolog, compression, slots, entries, dir_pos)]
    end

    # Reads one block. Either typ (the last block of that type wins) or
    # slot (1 based) must be given. Returns [code, data(binary String)].
    def self.read_block_io(io, dir, typ: nil, slot: nil)
      if slot && slot > 0 && slot <= dir.slots
        typ, read_pos, compressed_len1 = dir.entries[slot - 1]
      else
        read_pos = 0
        compressed_len1 = 0
        dir.entries.each do |t, o, l|
          next unless t == typ
          read_pos = o
          compressed_len1 = l
        end
      end
      return [LUT2_BLOCK_NOT_IN_FILE, nil] if read_pos.nil? || read_pos == 0
      io.seek(read_pos)
      header = io.read(16)
      return [FILE_READ_ERROR, nil] if header.nil? || header.bytesize < 16
      typ2, compressed_len, len, adler = header.unpack("V4")
      return [LUT2_FILE_CORRUPTED, nil] if typ2 != typ || compressed_len != compressed_len1
      raw = io.read(compressed_len)
      return [FILE_READ_ERROR, nil] if raw.nil? || raw.bytesize < compressed_len
      data = case dir.compression
             when COMPRESSION_NONE then raw
             when COMPRESSION_ZLIB
               begin
                 Zlib::Inflate.inflate(raw)
               rescue Zlib::DataError
                 return [LUT2_Z_DATA_ERROR, nil]
               rescue Zlib::BufError
                 return [LUT2_Z_BUF_ERROR, nil]
               rescue Zlib::MemError
                 return [LUT2_Z_MEM_ERROR, nil]
               end
             else
               return [KTO_CHECK_UNSUPPORTED_COMPRESSION, nil]
             end
      return [LUT2_Z_DATA_ERROR, nil] if data.bytesize != len
      return [LUT_CRC_ERROR, nil] if adler32a(data) != adler
      [OK, data]
    end

    def self.read_block(filename, typ)
      return [FILE_READ_ERROR, nil] unless File.file?(filename)
      File.open(filename, "rb") do |io|
        code, dir = read_directory(io)
        return [code, nil] unless code == OK
        read_block_io(io, dir, typ: typ)
      end
    rescue SystemCallError
      [FILE_READ_ERROR, nil]
    end

    def self.read_slot(filename, slot)
      return [FILE_READ_ERROR, nil] unless File.file?(filename)
      File.open(filename, "rb") do |io|
        code, dir = read_directory(io)
        return [code, nil] unless code == OK
        read_block_io(io, dir, slot: slot)
      end
    rescue SystemCallError
      [FILE_READ_ERROR, nil]
    end

    # Reads the directory of a file. Returns [code, Directory].
    def self.directory(filename)
      return [FILE_READ_ERROR, nil] unless File.file?(filename)
      File.open(filename, "rb") { |io| read_directory(io) }
    rescue SystemCallError
      [FILE_READ_ERROR, nil]
    end

    # Creates a new (empty) LUT file with the given prolog and number of
    # directory slots. Returns a return code.
    def self.create(filename, prolog, slots = DEFAULT_SLOTS)
      return TOO_MANY_SLOTS if slots > MAX_SLOTS
      File.open(filename, "wb") do |io|
        io.write(prolog)
        io.write("\nDATA\n")
        io.write([slots].pack("v"))
        io.write("\0" * (slots * 12))
      end
      OK
    rescue SystemCallError
      FILE_WRITE_ERROR
    end

    # Appends a block to an existing LUT file (opened read/write). A slot
    # with the same type is reused (the old block stays in the file but is
    # no longer referenced), otherwise the first free slot is taken.
    def self.write_block_io(io, typ, data)
      code, dir = read_directory(io)
      return code unless code == OK
      slot = dir.slot_of(typ) || dir.free_slot
      return LUT2_NO_SLOT_FREE if slot.nil?
      data = data.b
      compressed = case dir.compression
                   when COMPRESSION_NONE then data
                   when COMPRESSION_ZLIB then Zlib::Deflate.deflate(data, Zlib::BEST_COMPRESSION)
                   else return KTO_CHECK_UNSUPPORTED_COMPRESSION
                   end
      io.seek(0, IO::SEEK_END)
      write_pos = io.pos
      io.write([typ, compressed.bytesize, data.bytesize, adler32a(data)].pack("V4"))
      io.write(compressed)
      io.seek(dir.data_pos + slot * 12)
      io.write([typ, write_pos, compressed.bytesize].pack("V3"))
      io.flush
      OK
    end

    def self.write_block(filename, typ, data)
      return FILE_WRITE_ERROR unless File.file?(filename)
      File.open(filename, "r+b") { |io| write_block_io(io, typ, data) }
    rescue SystemCallError
      FILE_WRITE_ERROR
    end

    # Textual dump of the directory (lut_dir_dump_str in C). Returns [code, String].
    def self.dump(filename)
      return [FILE_READ_ERROR, nil] unless File.file?(filename)
      File.open(filename, "rb") do |io|
        code, dir = read_directory(io)
        return [code, nil] unless code == OK
        out = +" Slot retval   Typ   Inhalt                  Laenge   kompr.   Verh.    Adler32  Test\n"
        len1 = len2 = 0
        dir.entries.each_with_index do |(typ, offset, clen), i|
          if typ == 0
            out << format("%2d/%2d %3d %8d   %-20s %8d %8d%7s   0x%08x   %s\n", i + 1, dir.slots, 1, 0, "   (ungenutzt)", 0, 0, "-", 0, "OK")
            next
          end
          io.seek(offset)
          header = io.read(16)
          typ2, clen2, len, adler = header ? header.unpack("V4") : [0, 0, 0, 0]
          retval = OK
          retval = LUT2_FILE_CORRUPTED if typ2 != typ || clen2 != clen
          if retval == OK
            rc, data = read_block_io(io, dir, slot: i + 1)
            retval = rc
            retval = LUT_CRC_ERROR if rc == OK && adler32a(data) != adler
          end
          out << format("%2d/%2d %3d %8d   %-20s %8d %8d%7.1f%%  0x%08x   %s\n",
                        i + 1, dir.slots, retval, typ, block_name(typ, 2), len, clen,
                        len > 0 ? clen.fdiv(len) * 100 : 0.0, adler, retval == OK ? "OK" : "FEHLER")
          len1 += len
          len2 += clen
        end
        out << format("\nGesamtgroesse unkomprimiert: %d, Gesamtgroesse komprimiert: %d\nKompressionsrate: %1.2f%% (Kompression: %s)\nSlotdir (kurz): ",
                      len1, len2, len1 > 0 ? 100.0 * len2 / len1 : 0.0, COMPRESSION_NAMES[dir.compression] || "???")
        out << dir.entries.map(&:first).reject(&:zero?).map(&:to_s).join(" ") << " \n"
        [OK, out]
      end
    rescue SystemCallError
      [FILE_READ_ERROR, nil]
    end

    # Extracts the validity dates (JJJJMMTT integers) from an info block.
    # Returns [from, to] (0 if missing).
    def self.parse_validity(info)
      return [0, 0] unless info
      first = info.lines.first.to_s
      m = first.match(/(\d+)\D*-?\D*(\d+)?/)
      return [0, 0] unless m
      [m[1].to_i, m[2].to_i]
    end

    # Validity status of an info block for the given date (Integer JJJJMMTT)
    def self.validity(info, current)
      v1, v2 = parse_validity(info)
      return LUT2_NO_VALID_DATE if v1 == 0 || v2 == 0
      return LUT2_VALID if current >= v1 && current <= v2
      return LUT2_NOT_YET_VALID if current < v1
      LUT2_NO_LONGER_VALID
    end

    # Extracts the file id ("Datei-ID ...") from an info block or nil.
    def self.file_id(info)
      return nil unless info
      lines = info.lines.map(&:chomp)
      i = lines.index { |l| l.start_with?("Datei-ID (zuf") }
      i && lines[i + 1]
    end

    # Reads both info blocks of a LUT file. Returns
    # [code, info1, info2, valid1, valid2] (lut_info in C for a file name).
    def self.info(filename, current_date = today_int)
      return [FILE_READ_ERROR, nil, nil, 0, 0] unless File.file?(filename)
      File.open(filename, "rb") do |io|
        code, dir = read_directory(io)
        return [code, nil, nil, code, code] unless code == OK
        c1, i1 = read_block_io(io, dir, typ: LUT2_INFO)
        unless c1 == OK
          # no info block: return the prolog like get_lut_info2()
          prolog = dir.prolog_lines.join("\n") + "\n"
          return [c1, prolog, nil, c1, 0]
        end
        i1 = i1.force_encoding("ISO-8859-1").encode("UTF-8")
        v1 = validity(i1, current_date)
        c2, i2 = read_block_io(io, dir, typ: LUT2_2_INFO)
        if c2 == OK
          i2 = i2.force_encoding("ISO-8859-1").encode("UTF-8")
          v2 = validity(i2, current_date)
          if v2 == LUT2_NO_LONGER_VALID && v1 == LUT2_NO_LONGER_VALID
            # both sets expired: mark the younger one as "better"
            e1 = parse_validity(i1)[1]
            e2 = parse_validity(i2)[1]
            if e2 > e1
              v2 = LUT2_NO_LONGER_VALID_BETTER
            else
              v1 = LUT2_NO_LONGER_VALID_BETTER
            end
          end
        else
          i2 = nil
          v2 = c2
        end
        [OK, i1, i2, v1, v2]
      end
    rescue SystemCallError
      [FILE_READ_ERROR, nil, nil, 0, 0]
    end

    def self.today_int(time = Time.now)
      time.year * 10000 + time.month * 100 + time.day
    end

    # Prolog, system info line and user info line of the file
    # (get_lut_info2 in C). Returns [code, version, prolog, info, user_info].
    def self.prolog_info(filename)
      code, dir = directory(filename)
      if code == LUT1_FILE_USED
        return [OK, 1, "", "", ""]
      end
      return [code, 0, nil, nil, nil] unless code == OK
      lines = dir.prolog_lines
      prolog = lines.join("\n") + "\n"
      info = lines[1] || ""
      user_info = ""
      if info.end_with?("\\")
        info = info.chomp("\\")
        user_info = lines[2] || ""
      end
      [OK, 3, prolog, info, user_info]
    end
  end
end

module KontoCheckRuby
  module LutFile
    # Writes the IBAN blacklist block (LUT2_OWN_IBAN) from a text file with
    # lines "<BLZ>=0" into an existing LUT file (lut_keine_iban_berechnung in
    # C). A line "2718281=0" marks the list as coming from the IBAN service
    # portal; only then the block is evaluated by the IBAN functions.
    def self.write_iban_blacklist(blacklist_file, lutfile, set = 0)
      return FILE_READ_ERROR unless File.file?(blacklist_file)
      blzs = []
      File.foreach(blacklist_file) do |line|
        next unless line =~ /\A(\d{7,8})=0/
        blzs << Regexp.last_match(1).to_i
      end
      blzs.sort!
      data = [blzs.size].pack("V") + blzs.pack("V*")
      offset = set == 2 ? SET_OFFSET : 0
      File.open(lutfile, "r+b") do |io|
        code = write_block_io(io, LUT2_OWN_IBAN + offset, data)
        return code unless code == OK
        c, dir = read_directory(io)
        return c unless c == OK
        c, info = read_block_io(io, dir, typ: LUT2_INFO + offset)
        if c == OK && info =~ /^Enthaltene Felder:.*$/ && !info.include?(", OWN_IBAN")
          info = info.sub(/^(Enthaltene Felder:[^\n]*)/) { "#{Regexp.last_match(1)}, OWN_IBAN" }
          write_block_io(io, LUT2_INFO + offset, info)
        end
      end
      OK
    rescue SystemCallError
      FILE_WRITE_ERROR
    end
  end
end
