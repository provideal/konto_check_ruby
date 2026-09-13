# frozen_string_literal: true

# Copyright (C) 2026 tickettoaster GmbH <https://tickettoaster.de>.
# Part of konto_check_ruby, a Ruby port of konto_check (Copyright (C)
# 2002-2023 Michael Plugge); licensed under the GNU Lesser General Public
# License, version 2.1 or later, see the file LICENSE.

require_relative "test_helper"

class TestBlzFile < Minitest::Test
  include KontoCheckRuby
  B = KontoCheckRuby::BlzFile

  SAMPLE_LINE_NEW = "370400441Commerzbank                                               50447Köln                               Commerzbank Köln           24370COBADEFFXXX13006102U000000000000503".encode("ISO-8859-1")
  SAMPLE_LINE_OLD = SAMPLE_LINE_NEW[0, 168]

  def test_parse_line
    r = B.parse_line(SAMPLE_LINE_NEW, 2)
    assert_equal 37040044, r.blz
    assert_equal "1", r.hauptstelle
    assert r.hauptstelle?
    assert_equal "Commerzbank", r.name
    assert_equal 50447, r.plz
    assert_equal "Köln", r.ort
    assert_equal Encoding::UTF_8, r.ort.encoding
    assert_equal "Commerzbank Köln", r.name_kurz
    assert_equal 24370, r.pan
    assert_equal "COBADEFFXXX", r.bic
    assert_equal 13, r.pz
    assert_equal "13", r.pz_string
    assert_equal 6102, r.nr
    assert_equal "U", r.aenderung
    assert_equal "0", r.loeschung
    assert_equal 0, r.nachfolge_blz
    assert_equal 503, r.iban_regel
    assert_equal 5, r.regel
    assert_equal 3, r.regel_version
    assert_equal SAMPLE_LINE_NEW.encode("UTF-8"), r.to_line
    old = B.parse_line(SAMPLE_LINE_OLD, 1)
    assert_equal 0, old.iban_regel
  end

  def test_pz_conversion
    assert_equal 0, B.pz_from_string("00")
    assert_equal 99, B.pz_from_string("99")
    assert_equal 100, B.pz_from_string("A0")
    assert_equal 116, B.pz_from_string("B6")
    assert_equal 144, B.pz_from_string("E4")
    assert_equal "B6", B.pz_to_string(116)
    assert_equal "07", B.pz_to_string(7)
  end

  def test_parse_fixture_txt
    code, records, fmt = B.parse_file(TestFixtures::BLZ_TXT)
    assert_equal OK, code
    assert_equal 1, fmt # current Bundesbank files have no IBAN rule column
    assert_equal 13764, records.size
    assert_equal 4, records.count { |r| r.name.start_with?("Testbank") }
    bbk = records.first
    assert_equal 10000000, bbk.blz
    assert_equal "Bundesbank", bbk.name
    assert_equal "MARKDEF1100", bbk.bic
    assert_equal 9, bbk.pz
    assert_equal FILE_READ_ERROR, B.parse_file("/nonexistent")[0]
  end

  def test_parse_string_rejects_wrong_line_length
    code, = B.parse_string(SAMPLE_LINE_NEW + "\r\n" + SAMPLE_LINE_OLD + "\r\n")
    assert_equal INVALID_BLZ_FILE, code
  end

  def test_test_banks_not_duplicated
    line = "130511721Testbank Verfahren 52                                     57368Elsperhusen                        Testbank 52 Elsperhusen    13145TESTDEX987652130000U000000000000000"
    code, records, = B.parse_string(line + "\n")
    assert_equal OK, code
    assert_equal 4, records.size
    assert_equal 1, records.count { |r| r.blz == 13051172 }
  end

  def test_sort_records
    a = B.parse_line(SAMPLE_LINE_NEW)
    b = B.parse_line(SAMPLE_LINE_NEW.sub("370400441", "370400442"))
    c = B.parse_line(SAMPLE_LINE_NEW.sub("37040044", "10000000"))
    sorted = B.sort_records([b, a, c])
    assert_equal [c, a, b], sorted
  end

  def test_csv_and_xml_parsing
    csv = <<~CSV.encode("ISO-8859-1")
      Bankleitzahl;Merkmal;Bezeichnung;PLZ;Ort;Kurzbezeichnung;PAN;BIC;Prüfzifferberechnungsmethode;Datensatznummer;Änderungskennzeichen;Bankleitzahllöschung;Nachfolge-Bankleitzahl
      "10000000";"1";"Bundesbank";"10591";"Berlin";"BBk Berlin";"20100";"MARKDEF1100";"09";"011380";"U";"0";"00000000"
      "37040044";"1";"Commerzbank; Köln";"50447";"Köln";"Commerzbank Köln";"24370";"COBADEFFXXX";"13";"006102";"U";"0";"00000000"
    CSV
    code, records, fmt = B.parse_csv_string(csv, add_test_banks: false)
    assert_equal OK, code
    assert_equal 1, fmt
    assert_equal 2, records.size
    assert_equal "Commerzbank; Köln", records[1].name
    assert_equal 13, records[1].pz
    assert_equal 11380, records[0].nr
    xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?><Document xmlns="urn:BBk:BLZ:xsd:BLZDat"><FileHdr><SndgInst>MARKDEFF</SndgInst><ValidFrom>2026-09-07</ValidFrom><ValidTill>2026-12-06</ValidTill></FileHdr>
      <BLZEintrag><BLZ>10000000</BLZ><Merkmal>1</Merkmal><Bezeichnung>Bundesbank &amp; Co</Bezeichnung><PLZ>10591</PLZ><Ort>Berlin</Ort><Kurzbez>BBk Berlin</Kurzbez><PAN>20100</PAN><BIC>MARKDEF1100</BIC><PruefZiffMeth>09</PruefZiffMeth><DsNr>11380</DsNr><Aenderungskennz>U</Aenderungskennz><BLZLoesch>0</BLZLoesch><NachfolgeBLZ>00000000</NachfolgeBLZ></BLZEintrag>
      <BLZEintrag><BLZ>10010123</BLZ><Merkmal>1</Merkmal><Bezeichnung>Qonto</Bezeichnung><PLZ>10245</PLZ><Ort>Berlin</Ort><Kurzbez>Qonto, Berlin</Kurzbez><BIC>QNTODEB2XXX</BIC><PruefZiffMeth>09</PruefZiffMeth><DsNr>57478</DsNr><Aenderungskennz>M</Aenderungskennz><BLZLoesch>0</BLZLoesch><NachfolgeBLZ>00000000</NachfolgeBLZ></BLZEintrag></Document>
    XML
    code, records, fmt, v1, v2 = B.parse_xml_string(xml, add_test_banks: false)
    assert_equal OK, code
    assert_equal 1, fmt
    assert_equal 20260907, v1
    assert_equal 20261206, v2
    assert_equal "Bundesbank & Co", records[0].name
    assert_equal 0, records[1].pan
    assert_equal "M", records[1].aenderung
    assert_equal :xml, B.detect_format(xml)
    assert_equal :csv, B.detect_format(csv)
    assert_equal :txt, B.detect_format(SAMPLE_LINE_NEW)
  end

  def test_iban_rule_table
    table = B.default_iban_rules
    assert_operator table.size, :>, 1000
    assert_equal 503, table[37040044]
    records = [B.parse_line(SAMPLE_LINE_OLD, 1), B.parse_line(SAMPLE_LINE_OLD.sub("37040044", "99999999"), 1)]
    assert_equal 1, B.apply_iban_rules!(records, table)
    assert_equal 503, records[0].iban_regel
    assert_equal 0, records[1].iban_regel
    assert_nil B.iban_rule_table(false)
    assert_equal({ 1 => 2 }, B.iban_rule_table({ 1 => 2 }))
  end

  def test_generate_lut_and_reload
    Dir.mktmpdir do |dir|
      out = File.join(dir, "gen.lut2")
      code = B.generate_lut(TestFixtures::BLZ_TXT, out, user_info: "Test", gueltigkeit: "20260907-20261206",
                                                        felder: 9, filialen: true)
      assert_equal OK, code
      code, records, = B.parse_file(TestFixtures::BLZ_TXT)
      B.apply_iban_rules!(records, B.default_iban_rules)
      direct = BankData.from_records(records)
      code, loaded = BankData.from_lut(out, required: B::LUT_SETS[9], current_date: 20261001)
      assert_equal OK, code
      assert_equal direct.cnt, loaded.cnt
      assert_equal direct.cnt_hs, loaded.cnt_hs
      assert_equal direct.blz, loaded.blz
      assert_equal direct.pz, loaded.pz
      assert_equal direct.filialen, loaded.filialen
      assert_equal direct.startidx, loaded.startidx
      %i[name name_kurz plz ort pan bic nr aenderung loeschung nachfolge_blz iban_regel].each do |f|
        assert_equal direct.public_send(f), loaded.public_send(f), "field #{f} differs after LUT roundtrip"
      end
      assert_equal 20260907, loaded.valid_from
      assert_equal 20261206, loaded.valid_to
      assert_match(/Test/, loaded.info)
      assert_equal LUT2_INVALID_GUELTIGKEIT, B.generate_lut(TestFixtures::BLZ_TXT, out, gueltigkeit: "2026")
      assert_equal LUT2_GUELTIGKEIT_SWAPPED, B.generate_lut(TestFixtures::BLZ_TXT, out, gueltigkeit: "20261206-20260907")
      # second data set appended
      assert_equal OK, B.generate_lut(TestFixtures::BLZ_TXT, out, gueltigkeit: "20261207-20270301", set: 2, filialen: false)
      code, i1, i2, v1, v2 = LutFile.info(out, 20270101)
      assert_equal OK, code
      assert_match(/Erster Datensatz/, i1)
      assert_match(/Zweiter Datensatz/, i2)
      assert_equal LUT2_NO_LONGER_VALID, v1
      assert_equal LUT2_VALID, v2
      code, set2 = BankData.from_lut(out, required: B::LUT_SETS[9], current_date: 20270101)
      assert_equal OK, code
      assert_equal 2, set2.set
      refute set2.branches?
      assert_equal direct.cnt_hs, set2.cnt
    end
  end

  def test_main_offices_only
    Dir.mktmpdir do |dir|
      out = File.join(dir, "hs.lut2")
      assert_equal OK, B.generate_lut(TestFixtures::BLZ_TXT, out, felder: 3, filialen: false)
      code, data = BankData.from_lut(out, required: B::LUT_SETS[3])
      assert_equal OK, code
      assert_nil data.filialen
      assert_equal data.cnt_hs, data.name.size
      assert_nil data.bic
    end
  end
end
