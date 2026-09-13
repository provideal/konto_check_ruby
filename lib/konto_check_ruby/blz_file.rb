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

require "set"
require_relative "retvals"
require_relative "lut_file"

module KontoCheckRuby
  # Parser for the "Bankleitzahlendatei" of the Deutsche Bundesbank (the
  # fixed width text format, ISO-8859-1, 168 characters per record in the
  # old format without IBAN rules or 174 characters with IBAN rules) and
  # generator for LUT2 files from it.
  #
  # Record layout (0 based character positions):
  #
  #   0- 7  BLZ                         8- 8  Merkmal (1 = Hauptstelle, 2 = Zweigstelle)
  #   9-66  Bezeichnung                67-71  PLZ
  #  72-106 Ort                       107-133 Kurzbezeichnung
  # 134-138 PAN                       139-149 BIC
  # 150-151 Prüfzifferberechnungsmethode
  # 152-157 Datensatznummer           158     Änderungskennzeichen (A, D, M, U)
  # 159     Bankleitzahllöschung      160-167 Nachfolge-BLZ
  # 168-173 IBAN-Regel (Regel 4 Stellen + Version 2 Stellen)
  module BlzFile
    LINE_LEN_OLD = 168
    LINE_LEN_NEW = 174

    # One record of the Bundesbank file. All strings are UTF-8, numbers are
    # Integers. hauptstelle is the character "1" or "2" (or "3" for test banks
    # of old files), aenderung/loeschung single characters.
    BankRecord = Struct.new(:blz, :hauptstelle, :name, :plz, :ort, :name_kurz, :pan, :bic, :pz,
                            :nr, :aenderung, :loeschung, :nachfolge_blz, :iban_regel, keyword_init: true) do
      def hauptstelle?
        hauptstelle == "1"
      end

      # IBAN rule number without version
      def regel
        iban_regel / 100
      end

      def regel_version
        iban_regel % 100
      end

      # Formats the record as a line of the Bundesbank file (174 characters,
      # without line terminator, UTF-8; convert to ISO-8859-1 for a real file).
      def to_line(with_iban_rule: true)
        s = format("%08d%1s%-58s%05d%-35s%-27s%5s%-11s%02s%6s%1s%1s%08d",
                   blz, hauptstelle, name[0, 58], plz, ort[0, 35], name_kurz[0, 27],
                   pan.zero? ? "" : format("%05d", pan), bic,
                   pz_string, nr.zero? ? "" : format("%06d", nr),
                   aenderung, loeschung, nachfolge_blz)
        s += format("%06d", iban_regel) if with_iban_rule
        s
      end

      def pz_string
        BlzFile.pz_to_string(pz)
      end
    end

    # The Bundesbank file does not contain the test banks used in the
    # description of the check methods 52, 53 and B6; konto_check adds them.
    TEST_BANK_LINES = [
      "130511721Testbank Verfahren 52                                     57368Elsperhusen                        Testbank 52 Elsperhusen    13145TESTDEX987652130000U000000000000000",
      "160520721Testbank Verfahren 53                                     57368Elsperhusen                        Testbank 53 Elsperhusen    13145TESTDEX987653130000U000000000000000",
      "800537721Testbank Verfahren B6                                     57368Elsperhusen                        Testbank B6 Elsperhusen    13145TESTDEX9876B6130000U000000000000000",
      "800537821Testbank Verfahren B6                                     57368Elsperhusen                        Testbank B6 Elsperhusen    13145TESTDEX9876B6130000U000000000000000"
    ].freeze

    # "00".."99", "A0".."Z9" -> 0..359 (bx2/bx1 tables in C)
    def self.pz_from_string(s)
      c1 = s[0]
      c2 = s[1]
      v1 = if c1 =~ /\d/ then c1.to_i elsif c1 =~ /[A-Za-z]/ then c1.upcase.ord - 65 + 10 else 0 end
      v2 = c2 =~ /\d/ ? c2.to_i : 0
      v1 * 10 + v2
    end

    def self.pz_to_string(pz)
      pz < 100 ? format("%02d", pz) : ((pz / 10) - 10 + 65).chr + (pz % 10).to_s
    end

    # Parses the content of a Bundesbank file (binary/ISO-8859-1 String).
    # Returns [code, records, file_format] where file_format is 1 (old format
    # without IBAN rules), 2 (with IBAN rules) or 0 (unknown line length).
    def self.parse_string(content, add_test_banks: true)
      data = content.b
      first_eol = data.index(/\r|\n/) || data.bytesize
      case first_eol
      when LINE_LEN_OLD then file_format = 1
      when LINE_LEN_NEW then file_format = 2
      else file_format = 0
      end
      records = []
      data.each_line do |line|
        line = line.chomp
        next if line.empty? && records.any?
        return [INVALID_BLZ_FILE, nil, file_format] if line.bytesize != first_eol
        records << parse_line(line, file_format)
      end
      if add_test_banks
        present = records.map(&:blz).to_set
        TEST_BANK_LINES.each do |l|
          l = l[0, LINE_LEN_OLD] if file_format == 1
          rec = parse_line(l, file_format)
          records << rec unless present.include?(rec.blz)
        end
      end
      [OK, records, file_format]
    end

    def self.parse_file(filename, add_test_banks: true)
      return [FILE_READ_ERROR, nil, 0] unless File.file?(filename)
      parse_string(File.binread(filename), add_test_banks: add_test_banks)
    rescue SystemCallError
      [FILE_READ_ERROR, nil, 0]
    end

    # Parses one (binary, ISO-8859-1) line of the file
    def self.parse_line(line, file_format = 2)
      l = line.b
      BankRecord.new(
        blz: l[0, 8].to_i,
        hauptstelle: l[8, 1],
        name: iso(l[9, 58]),
        plz: l[67, 5].to_i,
        ort: iso(l[72, 35]),
        name_kurz: iso(l[107, 27]),
        pan: l[134, 5].strip.empty? ? 0 : l[134, 5].to_i,
        bic: l[139, 11].rstrip,
        pz: pz_from_string(l[150, 2]),
        nr: l[152, 6].to_i,
        aenderung: l[158, 1],
        loeschung: l[159, 1],
        nachfolge_blz: l[160, 8].to_i,
        iban_regel: file_format == 2 && l.bytesize >= LINE_LEN_NEW ? l[168, 6].to_i : 0
      )
    end

    def self.iso(s)
      s.rstrip.force_encoding("ISO-8859-1").encode("UTF-8")
    end

    # Sorts the records like konto_check does: by BLZ, then main office
    # before branches, then by original position (stable).
    def self.sort_records(records)
      records.each_with_index.sort_by { |r, i| [r.blz, r.hauptstelle, i] }.map(&:first)
    end

    # Field sets for the init levels 0..9 (lut_set_0 .. lut_set_9 in C)
    LUT_SETS = [
      [LUT2_BLZ, LUT2_PZ],
      [LUT2_BLZ, LUT2_PZ, LUT2_AENDERUNG, LUT2_NAME_KURZ],
      [LUT2_BLZ, LUT2_PZ, LUT2_AENDERUNG, LUT2_NAME_KURZ, LUT2_BIC],
      [LUT2_BLZ, LUT2_PZ, LUT2_AENDERUNG, LUT2_NAME, LUT2_PLZ, LUT2_ORT],
      [LUT2_BLZ, LUT2_PZ, LUT2_AENDERUNG, LUT2_NAME, LUT2_PLZ, LUT2_ORT, LUT2_IBAN_REGEL, LUT2_BIC],
      [LUT2_BLZ, LUT2_PZ, LUT2_AENDERUNG, LUT2_NAME_NAME_KURZ, LUT2_PLZ, LUT2_ORT, LUT2_IBAN_REGEL, LUT2_BIC],
      [LUT2_BLZ, LUT2_PZ, LUT2_AENDERUNG, LUT2_NAME_NAME_KURZ, LUT2_PLZ, LUT2_ORT, LUT2_IBAN_REGEL, LUT2_BIC, LUT2_NACHFOLGE_BLZ],
      [LUT2_BLZ, LUT2_PZ, LUT2_AENDERUNG, LUT2_NAME_NAME_KURZ, LUT2_PLZ, LUT2_ORT, LUT2_IBAN_REGEL, LUT2_BIC, LUT2_NACHFOLGE_BLZ, LUT2_LOESCHUNG],
      [LUT2_BLZ, LUT2_PZ, LUT2_AENDERUNG, LUT2_NAME_NAME_KURZ, LUT2_PLZ, LUT2_ORT, LUT2_IBAN_REGEL, LUT2_BIC, LUT2_NACHFOLGE_BLZ, LUT2_LOESCHUNG, LUT2_PAN],
      [LUT2_BLZ, LUT2_PZ, LUT2_AENDERUNG, LUT2_NAME_NAME_KURZ, LUT2_PLZ, LUT2_ORT, LUT2_IBAN_REGEL, LUT2_BIC, LUT2_NACHFOLGE_BLZ, LUT2_LOESCHUNG, LUT2_PAN, LUT2_NR]
    ].freeze

    # Blocks needed for the IBAN functions (lut_set_iban in C)
    LUT_SET_IBAN = [LUT2_BLZ, LUT2_PZ, LUT2_AENDERUNG, LUT2_BIC, LUT2_NACHFOLGE_BLZ, LUT2_LOESCHUNG, LUT2_IBAN_REGEL].freeze

    # Generates a LUT2 file from a Bundesbank file (generate_lut2 /
    # generate_lut2_p in C).
    #
    #   input        Bundesbank text file
    #   output       LUT file to write (created for set 0/1, appended for set 2)
    #   user_info    free text stored in the prolog and the info block
    #   gueltigkeit  validity "JJJJMMTT-JJJJMMTT" or nil
    #   felder       0..9 (field set, see LUT_SETS) or an Array of block types
    #   filialen     true: include branches, false: main offices only
    #   slots        number of directory slots (default 60)
    #   set          0 = new file, 1 = new file (primary set), 2 = append secondary set
    #   add_index    write the sort index blocks (default true)
    #   iban_rules   :default applies the built-in IBAN rule table to files
    #                without IBAN rule column (see default_iban_rules), false
    #                disables that, a Hash or a file name supplies own rules
    #
    # Returns a return code (OK or an error).
    def self.generate_lut(input, output, user_info: "", gueltigkeit: nil, felder: 9, filialen: true,
                          slots: LutFile::DEFAULT_SLOTS, set: 0, add_index: true, now: Time.now, iban_rules: :default)
      code, records, file_format, v1, v2 = parse_any(input)
      return code unless code == OK
      if file_format != 2 && (table = iban_rule_table(iban_rules))
        file_format = 2 if apply_iban_rules!(records, table) > 0
      end
      gueltigkeit = format("%08d-%08d", v1, v2) if gueltigkeit.nil? && v1 != 0 && v2 != 0
      generate_lut_from_records(records, output, input_name: input, file_format: file_format,
                                                 user_info: user_info, gueltigkeit: gueltigkeit,
                                                 felder: felder, filialen: filialen, slots: slots,
                                                 set: set, add_index: add_index, now: now)
    end

    def self.generate_lut_from_records(records, output, input_name: "blz.txt", file_format: 2, user_info: "",
                                       gueltigkeit: nil, felder: 9, filialen: true,
                                       slots: LutFile::DEFAULT_SLOTS, set: 0, add_index: true, now: Time.now)
      ok = OK
      g1 = g2 = 0
      if gueltigkeit && !gueltigkeit.empty?
        return LUT2_INVALID_GUELTIGKEIT unless gueltigkeit =~ /\A(\d{8})[ -](\d{8})\z/
        g1 = Regexp.last_match(1).to_i
        g2 = Regexp.last_match(2).to_i
        return LUT2_GUELTIGKEIT_SWAPPED if g2 < g1
      end
      fields = if felder.is_a?(Array)
                 felder.dup
               else
                 base = LUT_SETS[felder.to_i] || LUT_SETS[9]
                 f = [LUT2_BLZ, LUT2_PZ]
                 f += [LUT2_FILIALEN, LUT2_VOLLTEXT_TXT] if filialen
                 f + base
               end
      fields.uniq!
      fields.delete(LUT2_IBAN_REGEL) unless file_format == 2
      fields.reject! { |f| f < 1 || f > LAST_LUT_BLOCK || f == LUT2_OWN_IBAN }
      slots = LutFile::DEFAULT_SLOTS if slots.nil? || slots == 0
      if slots < LutFile::SLOT_CNT_MIN
        slots = LutFile::SLOT_CNT_MIN
        ok = OK_SLOT_CNT_MIN_USED
      end
      auch_filialen = fields.include?(LUT2_FILIALEN)
      have_iban_rules = fields.include?(LUT2_IBAN_REGEL)
      sorted = sort_records(records)
      hs_cnt = sorted.count(&:hauptstelle?)
      user_info = user_info.to_s.tr("\r\n", "  ")

      info = format("Gueltigkeit der Daten: %08d-%08d (%s Datensatz)\nEnthaltene Felder:", g1, g2, set < 2 ? "Erster" : "Zweiter")
      info << " " << fields.map { |f| LutFile.block_name(f) + (add_index && LutFile::BLOCKS_WITH_INDEX.include?(f) ? "+" : "") }.join(", ")
      info << "\n\n"
      file_id = Array.new(8) { format("%04x", rand(32768)) }.join
      prolog = format("BLZ Lookup Table/Format 2.0\nLUT-Datei generiert am %d.%d.%d, %d:%02d aus %s%s%s\n" \
                      "Anzahl Banken: %d, davon Hauptstellen: %d (inkl. %d Testbanken)\n" \
                      "dieser Datensatz enthaelt %s, %s und %sIBAN-Regeln\n" \
                      "Kompression: %s\nDatei-ID (zufaellig, fuer inkrementelle Initialisierung):\n%s\n",
                      now.day, now.month, now.year, now.hour, now.min, input_name,
                      user_info.empty? ? "" : "\\\n", user_info,
                      sorted.size, hs_cnt, TEST_BANK_LINES.size,
                      auch_filialen ? "auch die Filialen" : "nur die Hauptstellen",
                      add_index ? "sowie Indexblocks" : "keine Indexblocks",
                      have_iban_rules ? "" : "keine ", "zlib", file_id)
      info << prolog
      info = info.encode("ISO-8859-1", undef: :replace)
      prolog_iso = prolog.chomp.encode("ISO-8859-1", undef: :replace)

      set = 0 if set > 0 && !File.file?(output)
      if set == 0
        code = LutFile.create(output, prolog_iso, slots)
        return code unless code == OK
      end
      offset = set == 2 ? LutFile::SET_OFFSET : 0
      begin
        File.open(output, "r+b") do |io|
          code = LutFile.write_block_io(io, LUT2_INFO + offset, info)
          return code unless code == OK
          blocks = BlockBuilder.new(sorted, auch_filialen).build(fields, add_index)
          blocks.each do |typ, data|
            code = LutFile.write_block_io(io, typ + offset, data)
            return code unless code == OK
          end
        end
      rescue SystemCallError
        return FILE_WRITE_ERROR
      end
      ok
    end

    # Encodes the sorted records into the binary LUT block formats
    # (write_lutfile_entry_de in C).
    class BlockBuilder
      def initialize(sorted, auch_filialen)
        @recs = sorted
        @auch_filialen = auch_filialen
        @sel = auch_filialen ? sorted : sorted.select(&:hauptstelle?)
      end

      def u16(v) = [v].pack("v")
      def u24(v) = [v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff].pack("C3")
      def u32(v) = [v].pack("V")

      def iso(s)
        s.encode("ISO-8859-1", undef: :replace, invalid: :replace)
      end

      # returns Array of [typ, data]
      def build(fields, add_index)
        out = []
        fields.each do |f|
          case f
          when LUT2_BLZ then out << [f, blz_block]
          when LUT2_FILIALEN then out << [f, filialen_block] if @auch_filialen
          when LUT2_NAME
            names = @sel.map(&:name)
            out << [f, name_block(names)]
            out << [LUT2_NAME_SORT, sort_block_str(names)] if add_index
          when LUT2_NAME_KURZ
            v = @sel.map(&:name_kurz)
            out << [f, string_block(v)]
            out << [LUT2_NAME_KURZ_SORT, sort_block_str(v)] if add_index
          when LUT2_NAME_NAME_KURZ
            out << [f, name_name_kurz_block]
            if add_index
              out << [LUT2_NAME_SORT, sort_block_str(@sel.map(&:name))]
              out << [LUT2_NAME_KURZ_SORT, sort_block_str(@sel.map(&:name_kurz))]
            end
          when LUT2_PLZ
            v = @sel.map(&:plz)
            out << [f, v.map { |x| u24(x) }.join]
            out << [LUT2_PLZ_SORT, sort_block_int(v)] if add_index
          when LUT2_ORT
            v = @sel.map(&:ort)
            out << [f, string_block(v)]
            out << [LUT2_ORT_SORT, sort_block_str(v)] if add_index
          when LUT2_PAN then out << [f, @sel.map { |r| u24(r.pan) }.join]
          when LUT2_BIC
            out << [f, bic_block]
            if add_index
              out << [LUT2_BIC_SORT, sort_block_str(@sel.map(&:bic))]
              out << [LUT2_BIC_H_SORT, sort_block_str(bic_h_list)]
            end
          when LUT2_PZ
            # one check method per BLZ (the C library writes one entry per
            # main office record, which is the same for well-formed files)
            v = pz_per_blz
            out << [f, v.pack("C*")]
            out << [LUT2_PZ_SORT, sort_block_int(v)] if add_index
          when LUT2_NR then out << [f, @sel.map { |r| u24(r.nr) }.join]
          when LUT2_AENDERUNG then out << [f, @sel.map(&:aenderung).join.b]
          when LUT2_LOESCHUNG then out << [f, @sel.map(&:loeschung).join.b]
          when LUT2_NACHFOLGE_BLZ then out << [f, @sel.map { |r| u32(r.nachfolge_blz) }.join]
          when LUT2_IBAN_REGEL
            v = @sel.map(&:iban_regel)
            out << [f, v.map { |x| u24(x) }.join]
            out << [LUT2_IBAN_REGEL_SORT, sort_block_int(v)] if add_index
          when LUT2_VOLLTEXT_TXT
            txt, idx = volltext_blocks
            out << [f, txt]
            out << [LUT2_VOLLTEXT_IDX, idx]
          end
        end
        out
      end

      def blz_block
        data = +"".b
        prev = 0
        cnt = 0
        @recs.each do |r|
          diff = r.blz - prev
          prev = r.blz
          next if diff == 0
          if diff <= 253
            data << diff.chr
          elsif diff < 65536
            data << 254.chr << u16(diff)
          else
            data << 255.chr << u32(r.blz)
          end
          cnt += 1
        end
        u16(cnt) + u16(@recs.size) + data
      end

      def pz_per_blz
        out = []
        last = nil
        fixed = false
        @recs.each do |r|
          hs = r.hauptstelle == "1" || r.hauptstelle == "3"
          if r.blz != last
            out << r.pz
            fixed = hs
            last = r.blz
          elsif hs && !fixed
            out[-1] = r.pz
            fixed = true
          end
        end
        out
      end

      def filialen_block
        counts = []
        last = nil
        @recs.each do |r|
          if r.blz == last
            counts[-1] += 1
          else
            counts << 1
            last = r.blz
          end
        end
        counts.map { |c| c & 255 }.pack("C*")
      end

      # Names: a main office name is prefixed with byte 1, a branch with the
      # same name as its main office is stored as an empty string.
      def name_block(names)
        data = +"".b
        hs_name = nil
        @sel.each_with_index do |r, i|
          if r.hauptstelle? && @auch_filialen
            hs_name = names[i]
            data << 1.chr << iso(names[i]) << 0.chr
          elsif r.hauptstelle == "2" && hs_name == names[i]
            data << 0.chr
          else
            data << iso(names[i]) << 0.chr
          end
        end
        data
      end

      def name_name_kurz_block
        data = +"".b
        hs_name = nil
        @sel.each do |r|
          if r.hauptstelle? && @auch_filialen
            hs_name = r.name
            data << 1.chr << iso(r.name) << 0.chr
          elsif r.hauptstelle == "2" && hs_name == r.name
            data << 0.chr
          else
            data << iso(r.name) << 0.chr
          end
          data << iso(r.name_kurz) << 0.chr
        end
        data
      end

      def string_block(values)
        values.map { |v| iso(v) + 0.chr }.join.b
      end

      # BIC: German BICs are stored without the "DE" at positions 5/6 (9 bytes),
      # foreign BICs with a leading byte 1 (11 bytes), missing BICs as a 0 byte.
      def bic_block
        data = +"".b
        @sel.each do |r|
          b = r.bic
          if b.empty?
            data << 0.chr
          elsif b[4, 2] == "DE" && b.length == 11
            data << b[0, 4] << b[6, 5]
          else
            data << 1.chr << b.ljust(11)[0, 11]
          end
        end
        data
      end

      def bic_h_list
        hs_bic = ""
        @sel.map do |r|
          hs_bic = r.bic if r.hauptstelle?
          r.hauptstelle? ? r.bic : hs_bic
        end
      end

      def sort_block_int(values)
        idx = (0...values.size).sort_by { |i| [values[i], i] }
        u16(values.size) + idx.pack("v*")
      end

      def sort_block_str(values)
        keys = values.map { |v| Collation.sort_key(v) }
        idx = (0...values.size).sort_by { |i| [keys[i], i] }
        u16(values.size) + idx.pack("v*")
      end

      # Full text index: all words of name, ort and name_kurz
      def volltext_blocks
        words = Hash.new { |h, k| h[k] = [] }
        @sel.each_with_index do |r, j|
          [r.name, r.ort, r.name_kurz].each do |field|
            Collation.words(field).each do |w|
              key = Collation.sort_key(w)
              list = words[key]
              list << [w, j] if list.empty? || list.last[1] != j
            end
          end
        end
        keys = words.keys.sort
        txt = keys.map { |k| iso(words[k].first[0]) + 0.chr }.join.b
        counts = keys.map { |k| words[k].size }
        banks = keys.flat_map { |k| words[k].map { |_w, j| j } }
        idx = u32(keys.size) + u32(banks.size) + counts.pack("v*") + banks.pack("v*")
        [txt, idx]
      end
    end
  end
end

module KontoCheckRuby
  module BlzFile
    # ------------------------------------------------- other Bundesbank formats

    # Detects the format of a Bundesbank file by its content:
    # :xml, :csv or :txt (fixed width).
    def self.detect_format(content)
      head = content.b[0, 4096].lstrip
      return :xml if head.start_with?("<?xml") || head.start_with?("<Document")
      return :csv if head.lines.first.to_s.include?(";")
      :txt
    end

    # Parses a Bundesbank file in any of the published formats (fixed width
    # TXT, CSV, XML). Returns [code, records, file_format, valid_from, valid_to]
    # (validity only from XML files, else 0).
    def self.parse_any(filename, add_test_banks: true)
      return [FILE_READ_ERROR, nil, 0, 0, 0] unless File.file?(filename)
      content = File.binread(filename)
      case detect_format(content)
      when :xml then parse_xml_string(content, add_test_banks: add_test_banks)
      when :csv
        code, records, fmt = parse_csv_string(content, add_test_banks: add_test_banks)
        [code, records, fmt, 0, 0]
      else
        code, records, fmt = parse_string(content, add_test_banks: add_test_banks)
        [code, records, fmt, 0, 0]
      end
    rescue SystemCallError
      [FILE_READ_ERROR, nil, 0, 0, 0]
    end

    CSV_COLUMNS = %w[blz hauptstelle name plz ort name_kurz pan bic pz nr aenderung loeschung nachfolge_blz iban_regel].freeze

    # Parses the CSV variant (semicolon separated, quoted fields, ISO-8859-1,
    # first line is the header). Returns [code, records, file_format].
    def self.parse_csv_string(content, add_test_banks: true)
      text = content.b.force_encoding("ISO-8859-1").encode("UTF-8")
      lines = text.lines.map(&:chomp).reject(&:empty?)
      return [INVALID_BLZ_FILE, nil, 0] if lines.empty?
      header = csv_fields(lines.shift)
      has_rules = header.any? { |h| h =~ /IBAN/i }
      records = []
      lines.each do |line|
        f = csv_fields(line)
        return [INVALID_BLZ_FILE, nil, 0] if f.size < 13
        records << BankRecord.new(
          blz: f[0].to_i, hauptstelle: f[1], name: f[2].strip, plz: f[3].to_i, ort: f[4].strip,
          name_kurz: f[5].strip, pan: f[6].strip.empty? ? 0 : f[6].to_i, bic: f[7].strip,
          pz: pz_from_string(f[8].strip.ljust(2, "0")), nr: f[9].to_i, aenderung: f[10].strip[0, 1] || " ",
          loeschung: f[11].strip[0, 1] || "0", nachfolge_blz: f[12].to_i,
          iban_regel: has_rules && f[13] ? f[13].to_i : 0
        )
      end
      add_test_bank_records(records, has_rules ? 2 : 1) if add_test_banks
      [OK, records, has_rules ? 2 : 1]
    end

    def self.csv_fields(line)
      fields = []
      cur = +""
      quoted = false
      i = 0
      while i < line.length
        c = line[i]
        if quoted
          if c == '"'
            if line[i + 1] == '"'
              cur << '"'
              i += 1
            else
              quoted = false
            end
          else
            cur << c
          end
        elsif c == '"'
          quoted = true
        elsif c == ";"
          fields << cur
          cur = +""
        else
          cur << c
        end
        i += 1
      end
      fields << cur
      fields
    end

    XML_FIELDS = {
      "BLZ" => :blz, "Merkmal" => :hauptstelle, "Bezeichnung" => :name, "PLZ" => :plz, "Ort" => :ort,
      "Kurzbez" => :name_kurz, "PAN" => :pan, "BIC" => :bic, "PruefZiffMeth" => :pz, "DsNr" => :nr,
      "Aenderungskennz" => :aenderung, "BLZLoesch" => :loeschung, "NachfolgeBLZ" => :nachfolge_blz,
      "IBANRegel" => :iban_regel
    }.freeze

    # Parses the XML variant (UTF-8). Returns [code, records, file_format, valid_from, valid_to].
    def self.parse_xml_string(content, add_test_banks: true)
      xml = content.b.force_encoding("UTF-8")
      xml = xml.encode("UTF-8", "ISO-8859-1") unless xml.valid_encoding?
      v1 = xml[%r{<ValidFrom>(\d{4})-(\d{2})-(\d{2})</ValidFrom>}] ? ($1 + $2 + $3).to_i : 0
      v2 = xml[%r{<ValidTill>(\d{4})-(\d{2})-(\d{2})</ValidTill>}] ? ($1 + $2 + $3).to_i : 0
      records = []
      has_rules = false
      xml.scan(%r{<BLZEintrag>(.*?)</BLZEintrag>}m) do |(entry)|
        h = {}
        entry.scan(%r{<([A-Za-z]+)>(.*?)</\1>}m) do |tag, value|
          key = XML_FIELDS[tag]
          h[key] = xml_unescape(value) if key
        end
        has_rules = true if h.key?(:iban_regel)
        records << BankRecord.new(
          blz: h[:blz].to_i, hauptstelle: h[:hauptstelle].to_s, name: h[:name].to_s.strip, plz: h[:plz].to_i,
          ort: h[:ort].to_s.strip, name_kurz: h[:name_kurz].to_s.strip, pan: h[:pan].to_i, bic: h[:bic].to_s.strip,
          pz: pz_from_string(h[:pz].to_s.ljust(2, "0")), nr: h[:nr].to_i, aenderung: h[:aenderung].to_s[0, 1] || " ",
          loeschung: h[:loeschung].to_s[0, 1] || "0", nachfolge_blz: h[:nachfolge_blz].to_i,
          iban_regel: h[:iban_regel].to_i
        )
      end
      return [INVALID_BLZ_FILE, nil, 0, 0, 0] if records.empty?
      add_test_bank_records(records, has_rules ? 2 : 1) if add_test_banks
      [OK, records, has_rules ? 2 : 1, v1, v2]
    end

    def self.xml_unescape(s)
      s.gsub(/&(amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);/) do
        case Regexp.last_match(1)
        when "amp" then "&"
        when "lt" then "<"
        when "gt" then ">"
        when "quot" then '"'
        when "apos" then "'"
        when /\A#x(.*)/ then Regexp.last_match(1).to_i(16).chr(Encoding::UTF_8)
        when /\A#(.*)/ then Regexp.last_match(1).to_i.chr(Encoding::UTF_8)
        end
      end
    end

    def self.add_test_bank_records(records, file_format)
      present = records.map(&:blz).to_set
      TEST_BANK_LINES.each do |l|
        l = l[0, LINE_LEN_OLD] if file_format == 1
        rec = parse_line(l, file_format)
        records << rec unless present.include?(rec.blz)
      end
    end

    # ------------------------------------------------------ IBAN rule table

    # The current Bundesbank files do not contain the IBAN rule column any
    # more. This table (data/iban_regeln.txt, BLZ -> rule*100+version) was
    # extracted from the LUT file shipped with konto_check 6.15 and can be
    # applied to records that carry no IBAN rule.
    def self.default_iban_rules
      @default_iban_rules ||= load_iban_rules(File.join(__dir__, "..", "..", "data", "iban_regeln.txt"))
    end

    # Loads a rule table from a text file with lines "BLZ;regel_version"
    # (or "BLZ regel_version"); "#" starts a comment.
    def self.load_iban_rules(filename)
      table = {}
      File.foreach(filename) do |line|
        next if line.start_with?("#")
        blz, rule = line.split(/[;\s]+/)
        next unless blz && rule
        table[blz.to_i] = rule.to_i
      end
      table
    end

    # Sets the IBAN rule of all records without a rule from the table
    # (Hash BLZ -> rule*100+version). Returns the number of records changed.
    def self.apply_iban_rules!(records, table)
      changed = 0
      records.each do |r|
        next unless r.iban_regel == 0
        v = table[r.blz]
        next unless v && v != 0
        r.iban_regel = v
        changed += 1
      end
      changed
    end

    # Resolves the iban_rules option (:default, true, false/nil, a Hash or a
    # file name) to a Hash or nil.
    def self.iban_rule_table(option)
      case option
      when nil, false then nil
      when true, :default then default_iban_rules
      when Hash then option
      when String then load_iban_rules(option)
      else raise ArgumentError, "invalid iban_rules option #{option.inspect}"
      end
    end
  end
end
