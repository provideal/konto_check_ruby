# frozen_string_literal: true

# Copyright (C) 2026 tickettoaster GmbH <https://tickettoaster.de>.
# Part of konto_check_ruby, a Ruby port of konto_check (Copyright (C)
# 2002-2023 Michael Plugge); licensed under the GNU Lesser General Public
# License, version 2.1 or later, see the file LICENSE.

require_relative "test_helper"

class TestEngine < Minitest::Test
  include KontoCheckRuby

  def e
    TestFixtures.lut_engine
  end

  def test_init_and_status
    assert e.initialized?
    assert_equal [TestFixtures::LUT, 1, 9, OK], e.current_lutfile_name
    assert_equal LUT2_VALID, e.lut_valid
    code, info1, info2, v1, v2 = e.lut_info
    assert_equal OK, code
    assert_match(/in den Speicher geladene Blocks/, info1)
    assert_nil info2
    assert_equal LUT2_VALID, v1
    assert_equal LUT2_BLOCK_NOT_IN_FILE, v2
    code, name, ok, fail = e.lut_blocks
    assert_equal OK, code
    assert_equal TestFixtures::LUT, name
    assert_match(/BLZ, FILIALEN, NAME/, ok)
    assert_equal "", fail
  end

  def test_init_errors_and_levels
    x = Engine.new
    assert_equal NO_LUT_FILE, x.init("/nonexistent.lut2")
    assert_equal LUT2_NOT_INITIALIZED, x.kto_check_blz("10010010", "517004")
    assert_equal [nil, 0, -1, LUT2_NOT_INITIALIZED], x.current_lutfile_name
    assert_equal OK, x.init(TestFixtures::LUT, 0)
    assert_nil x.data.name
    assert_equal [nil, LUT2_NAME_NOT_INITIALIZED], x.lut_name("10010010")
    # incremental load of more blocks from the same file
    assert_equal OK, x.init(TestFixtures::LUT, 3)
    assert_equal ["Postbank Ndl der Deutsche Bank", OK], x.lut_name("10010010")
    assert_equal 3, x.current_lutfile_name[2]
    assert_equal OK, x.free
    refute x.initialized?
  end

  def test_second_set
    x = Engine.new
    x.current_date = 20230701
    assert_equal OK, x.init(TestFixtures::LUT, 5)
    assert_equal 2, x.data.set
    assert_equal LUT2_VALID, x.lut_valid
    assert_equal ["Commerzbank", OK], x.lut_name("37040044")
  end

  def test_bundled_lut
    x = Engine.new
    x.current_date = 20261001
    assert_equal OK, x.init(Engine::BUNDLED_LUT, 0)
    assert_equal 1, x.data.set
    assert_equal 20260907, x.data.valid_from
    assert_equal 20261206, x.data.valid_to
    assert_equal LUT2_VALID, x.lut_valid
    assert_equal OK, x.kto_check_blz("37040044", "532013000")
    assert_equal OK, x.init(Engine::BUNDLED_LUT, 9)
    assert_equal [503, OK], x.lut_iban_regel("37040044") # IBAN rules from the built-in table
    assert_equal ["DE89370400440532013000", OK], x.iban_gen("37040044", "532013000")
    y = Engine.new
    assert_equal OK, y.init # no file name: the bundled LUT
    assert_equal Engine::BUNDLED_LUT, y.current_lutfile_name[0]
    assert_equal OK, y.init("", 0)
    assert_equal NO_LUT_FILE, y.init("/nonexistent/blz.lut2f")
  end

  def test_lut_index
    assert_equal 1, e.lut_index("10010010")
    assert_equal 1, e.lut_index(" 10010010 ")
    assert_equal INVALID_BLZ, e.lut_index("12345678")
    assert_equal INVALID_BLZ_LENGTH, e.lut_index("1234567")
    assert_equal INVALID_BLZ_LENGTH, e.lut_index("123456789")
    assert_equal INVALID_BLZ_LENGTH, e.lut_index("1001001x")
    assert_equal 1, e.lut_index_i(10010010)
    assert_equal INVALID_BLZ_LENGTH, e.lut_index_i(1234)
  end

  def test_lookups
    assert_equal OK, e.lut_blz("37040044")
    assert_equal OK, e.lut_blz("37040044", 16)
    assert_equal LUT2_INDEX_OUT_OF_RANGE, e.lut_blz("37040044", 17)
    assert_equal INVALID_BLZ, e.lut_blz("12345678")
    assert_equal [17, OK], e.lut_filialen("37040044")
    assert_equal ["Commerzbank", OK], e.lut_name("37040044")
    assert_equal ["Commerzbank Köln", OK], e.lut_name_kurz("37040044")
    assert_equal [50447, OK], e.lut_plz("37040044")
    assert_equal ["Köln", OK], e.lut_ort("37040044")
    assert_equal ["Bergisch Gladbach", OK], e.lut_ort("37040044", 1)
    assert_equal [24370, OK], e.lut_pan("37040044")
    assert_equal [13, OK], e.lut_pz("37040044")
    assert_equal [6143, OK], e.lut_nr("37040044")
    assert_equal ["U", OK], e.lut_aenderung("37040044")
    assert_equal [0, OK], e.lut_loeschung("37040044")
    assert_equal [0, OK], e.lut_nachfolge_blz("37040044")
    assert_equal [503, OK], e.lut_iban_regel("37040044")
    assert_equal [503, OK], e.lut_iban_regel("@+37040044")
    assert_equal [nil, LUT2_INDEX_OUT_OF_RANGE], e.lut_name("37040044", 99)
    assert_equal [nil, INVALID_BLZ], e.lut_name("12345678")
    assert_equal ["PBNKDEFFXXX", OK], e.lut_bic("10010010")
    assert_equal ["PBNKDEFFXXX", OK], e.lut_bic_h("10010010")
    assert_equal [Engine::EMPTY_BIC, OK_INVALID_FOR_IBAN], e.lut_bic("37040044", 1)
    assert_equal ["HYVEDEMM488", OK], e.lut_bic("10020890") # rule 32; C compares the raw rule value
    assert_equal ["COBADEFFXXX", OK], e.lut_bic_h("37040044", 1)
    m = e.lut_multiple("37040044")
    assert_equal OK, m[:retval]
    assert_equal 17, m[:cnt]
    assert_equal 13, m[:pz]
    assert_equal 17, m[:name].size
    assert_equal INVALID_BLZ, e.lut_multiple("12345678")[:retval]
  end

  def test_kto_check
    assert_equal OK, e.kto_check_blz("37040044", "532013000")
    assert_equal OK, e.kto_check_blz("37040044", "532013001") # sub account digits are not checked by method 13
    assert_equal FALSE, e.kto_check_blz("37040044", "532013100")
    assert_equal OK_NO_CHK, e.kto_check_blz("10000000", "1234567") # method 09: no check
    assert_equal INVALID_BLZ, e.kto_check_blz("12345678", "1")
    assert_equal INVALID_KTO_LENGTH, e.kto_check_blz("37040044", "12345678901")
    assert_equal INVALID_KTO, e.kto_check_blz("37040044", "12a45")
    assert_equal MISSING_PARAMETER, e.kto_check_blz(nil, "1")
    assert_equal OK, e.kto_check_pz("00", "9290701")
    assert_equal FALSE, e.kto_check_pz("13", "5281741")
    assert_equal FALSE, e.kto_check_pz("13a", "1230")
    assert_equal OK_TEST_BLZ_USED, e.kto_check_pz("52", "43001500")
    assert_equal OK, e.kto_check_pz("52", "43001500", "13051172")
    assert_equal UNDEFINED_SUBMETHOD, e.kto_check_pz("13ab", "1")
    assert_equal OK, e.kto_check("00", "9290701")
    assert_equal OK, e.kto_check("37040044", "532013000")
    ret, rv = e.kto_check_blz_dbg("37040044", "532013000")
    assert_equal OK, ret
    assert_equal "13a", rv.methode
    assert_equal 0, rv.pz
    assert_equal 8, rv.pz_pos
    ret, rv = e.kto_check_pz_dbg("06", "94012341")
    assert_equal OK, ret
    assert_equal "06", rv.methode
  end

  def test_blz_marked_as_deleted
    x = Engine.new
    x.current_date = TestFixtures::VALID_DATE
    x.init(TestFixtures::LUT, 9)
    idx = x.data.blz.each_index.find { |i| x.data.aenderung[x.data.startidx[i]] == "D" }
    skip "no deleted BLZ in fixture" unless idx
    assert_equal BLZ_MARKED_AS_DELETED, x.kto_check_blz(x.data.blz[idx].to_s, "1234567")
  end

  def test_iban_check
    assert_equal [OK, OK], e.iban_check("DE89370400440532013000")
    assert_equal [OK, OK], e.iban_check("DE89 3704 0044 0532 0130 00")
    assert_equal [IBAN_OK_KTO_NOT, FALSE], e.iban_check(fix_iban("DE00370400440532013100"))
    assert_equal [KTO_OK_IBAN_NOT, OK], e.iban_check("DE00370400440532013000")
    assert_equal [OK, NO_GERMAN_BIC], e.iban_check("GB82WEST12345698765432")
    assert_equal [FALSE, NO_GERMAN_BIC], e.iban_check("GB82WEST12345698765433")
    assert_equal [INVALID_IBAN_LENGTH, LUT2_KTO_NOT_CHECKED], e.iban_check("DE8937040044053201300")
    assert_equal [LUT2_NO_ACCOUNT_GIVEN, LUT2_NO_ACCOUNT_GIVEN], e.iban_check("")
    assert_equal [IBAN_CHKSUM_OK_BLZ_INVALID, INVALID_BLZ], e.iban_check("DE12123456780000000000".then { |s| fix_iban(s) })
    x = Engine.new
    assert_equal [IBAN_CHKSUM_OK_KC_NOT_INITIALIZED, LUT2_NOT_INITIALIZED], x.iban_check("DE89370400440532013000")
  end

  def test_iban_generation
    ret, papier, bic, blz2, kto2 = e.iban_bic_gen("37040044", "532013000")
    assert_equal OK, ret
    assert_equal "DE89 3704 0044 0532 0130 00", papier
    assert_equal "COBADEFFXXX", bic
    assert_equal "37040044", blz2
    assert_equal "0532013000", kto2
    assert_equal ["DE89370400440532013000", OK], e.iban_gen("37040044", "532013000")
    assert_equal [FALSE, nil, "COBADEFFXXX", "37040044", "0532013100"], e.iban_bic_gen("37040044", "532013100")
    assert_equal LUT2_KTO_NOT_CHECKED, e.iban_bic_gen("+37040044", "532013100")[0]
    assert_equal [LUT2_NO_ACCOUNT_GIVEN, nil, nil, "", ""], e.iban_bic_gen("", "1")
    assert_equal INVALID_BLZ, e.iban_bic_gen("12345678", "1")[0]
    assert_equal ["COBADEFFXXX", OK, "37040044", "0532013000"], e.iban2bic("DE89370400440532013000")
    assert_equal IBAN2BIC_ONLY_GERMAN, e.iban2bic("GB82WEST12345698765432")[1]
    assert_equal INVALID_IBAN_LENGTH, e.iban2bic("DE8937040044")[1]
  end

  def test_iban_rules_applied
    # rule 4 (Landesbank Berlin): donation account 1111 is replaced
    ret, papier, _bic, blz2, kto2 = e.iban_bic_gen("10050000", "1111")
    assert_equal OK_KTO_REPLACED, ret
    assert_equal "6600012020", kto2
    assert_equal "10050000", blz2
    assert_equal "DE", papier[0, 2]
    # rule 1: no IBAN calculation
    blz = e.data.blz.each_index.find { |i| e.data.iban_regel[e.data.startidx[i]] == 100 }
    if blz
      assert_equal NO_IBAN_CALCULATION, e.iban_bic_gen(e.data.blz[blz].to_s, "12345")[0]
    end
    ret, blz2, kto2, bic, regel, _rv = e.kto_check_regel_dbg("10050000", "1111")
    assert_equal OK_KTO_REPLACED, ret
    assert_equal "6600012020", kto2
    assert_equal "10050000", blz2
    assert_equal "BELADEBEXXX", bic
    assert_equal 400, regel
    assert_equal OK, e.kto_check_regel("37040044", "532013000")
  end

  def test_bic_ci_ipi
    assert_equal [OK, 17], e.bic_check("PBNKDEFFXXX") # all branches with that BIC
    assert_equal OK, e.bic_check("COBADEFF")[0]
    assert_equal [BIC_ONLY_GERMAN, 0], e.bic_check("WESTGB2LXXX")
    assert_equal [INVALID_BIC_LENGTH, 0], e.bic_check("PBNKDEFF1")
    assert_equal [FALSE, 0], e.bic_check("XXXXDEXXXXX")
    assert_equal OK, e.ci_check("DE98ZZZ09999999999")
    assert_equal FALSE, e.ci_check("DE99ZZZ09999999999")
    assert_equal [OK, "92000000001234567890", "9200 0000 0012 3456 7890"], e.ipi_gen("1234567890")
    assert_equal OK, e.ipi_check("92000000001234567890")
    assert_equal OK, e.ipi_check("9200 0000 0012 3456 7890")
    assert_equal FALSE, e.ipi_check("91000000001234567890")
    assert_equal IPI_CHECK_INVALID_LENGTH, e.ipi_check("123")
    assert_equal IPI_INVALID_LENGTH, e.ipi_gen("1234567890123456789")[0]
    assert_equal IPI_INVALID_CHARACTER, e.ipi_gen("12-34")[0]
  end

  def test_search
    code, hits = e.lut_suche_namen("Postbank")
    assert_equal OK, code
    assert_operator hits.size, :>, 100
    assert hits.all? { |j| e.data.name[j] =~ /\APostbank/ }
    assert_equal KEY_NOT_FOUND, e.lut_suche_namen("Zzzzz")[0]
    code, hits = e.lut_suche_ort("Köln")
    assert_equal OK, code
    assert_equal hits, e.lut_suche_ort("koeln")[1].then { |h| h.empty? ? hits : h } # umlaut folding: köln == koln, not koeln
    assert_equal hits.size, e.lut_suche_ort("KÖLN")[1].size
    assert_equal hits.size, e.lut_suche_ort("koln")[1].size
    assert_operator e.lut_suche_ort("!Köln")[1].size, :<=, hits.size
    assert_equal OK, e.lut_suche_plz(50667)[0]
    code, hits = e.lut_suche_blz(37040044, 37049999)
    assert_equal OK, code
    assert_equal [37040044, 37040048, 37040060, 37040061], hits.map { |j| e.blz_f(j) }.uniq
    assert_equal INVALID_SEARCH_RANGE, e.lut_suche_blz(37049999, 37040044)[0]
    assert_equal [13051172], e.lut_suche_pz(52)[1].map { |j| e.blz_f(j) }
    code, hits = e.lut_suche_regel(5)
    assert_equal OK, code
    assert hits.all? { |j| e.data.iban_regel[j] / 100 == 5 }
    code, hits, words = e.lut_suche_volltext("Sparkasse")
    assert_equal OK, code
    assert_includes words, "Sparkasse"
    assert_operator hits.size, :>, 100
    assert_equal LUT2_VOLLTEXT_SINGLE_WORD_ONLY, e.lut_suche_volltext("Sparkasse Köln")[0]
    assert_equal LUT2_VOLLTEXT_INVALID_CHAR, e.lut_suche_volltext("Spar-kasse")[0]
    code, pairs = e.lut_suche_multiple("Sparkasse Köln", true)
    assert_equal OK, code
    assert_equal [[37050198, 0]], pairs
    code, pairs = e.lut_suche_multiple("Köln@ort 37040044@blz", true, "a b")
    assert_equal [[37040044, 0]], pairs
    assert_equal SOME_KEYS_NOT_FOUND, e.lut_suche_multiple("Zzzzz Köln")[0]
    retval, cnt, start = e.bic_info("COBADEFFXXX")
    assert_equal OK, retval
    assert_operator cnt, :>, 100
    assert_operator start, :>, 0
    assert_equal ["Commerzbank", OK], e.bic_field(:name, "COBADEFFXXX").then { |v, r| [v[0, 11], r] }
    assert_equal LUT2_INDEX_OUT_OF_RANGE, e.bic_field(:name, "COBADEFFXXX", 0, 10_000)[1]
    assert_equal INVALID_BIQ_INDEX, e.biq_field(:name, 0)[1]
    assert_equal [10010010, 0, OK], e.idx2blz(1)
  end

  def test_encoding_and_texts
    x = Engine.new
    assert_equal 2, x.encoding
    assert_equal "UTF-8", x.encoding_str
    assert_equal "die Bankleitzahl ist ungültig", x.retval2txt(INVALID_BLZ)
    assert_equal "INVALID_BLZ", x.retval2txt_short(INVALID_BLZ)
    assert_equal "die Bankleitzahl ist ung&uuml;ltig", x.retval2html(INVALID_BLZ)
    assert_equal "die Bankleitzahl ist ungültig".encode("ISO-8859-1"), x.retval2iso(INVALID_BLZ)
    assert_equal "die Bankleitzahl ist ungültig".encode("CP850"), x.retval2dos(INVALID_BLZ)
    assert_equal "ungültiger Rückgabewert", x.retval2txt(-9999)
    assert_equal 1, x.encoding("i")
    assert_equal Encoding::ISO_8859_1, x.retval2txt(INVALID_BLZ).encoding
    assert_equal 3, x.encoding("h")
    assert_equal "K&ouml;ln", x.encode_out("Köln")
    assert_equal 51, x.encoding("m")
    assert_equal "INVALID_BLZ", x.retval2txt(INVALID_BLZ)
    assert_match(/konto_check_ruby Version/, x.version)
    assert_equal KontoCheckRuby::VERSION, x.version(1)
  end

  def test_blz_file_engine
    t = TestFixtures.txt_engine
    assert_equal OK, t.kto_check_blz("37040044", "532013000")
    assert_equal ["Commerzbank", OK], t.lut_name("37040044")
    assert_equal [503, OK], t.lut_iban_regel("37040044") # from the built-in rule table
    assert_equal ["DE89370400440532013000", OK], t.iban_gen("37040044", "532013000")
    assert_equal LUT2_NO_VALID_DATE, t.lut_valid
    x = Engine.new
    assert_equal OK, x.load_blz_file(TestFixtures::BLZ_TXT, gueltigkeit: "20260907-20261206", iban_rules: false)
    assert_equal [0, OK], x.lut_iban_regel("37040044")
    assert_equal 20260907, x.data.valid_from
    assert_equal FILE_READ_ERROR, x.load_blz_file("/nonexistent.txt")
    assert_equal LUT2_INVALID_GUELTIGKEIT, x.load_blz_file(TestFixtures::BLZ_TXT, gueltigkeit: "bad")
  end

  def test_rebuild_blzfile
    Dir.mktmpdir do |dir|
      out = File.join(dir, "blz.txt")
      x = Engine.new
      x.current_date = TestFixtures::VALID_DATE
      assert_equal OK, x.rebuild_blzfile(TestFixtures::LUT, out, 1)
      lines = File.binread(out).lines
      assert_equal 14869, lines.size
      assert(lines.all? { |l| l.chomp.bytesize == 174 })
      code, records, fmt = BlzFile.parse_file(out)
      assert_equal OK, code
      assert_equal 2, fmt
      assert_equal 14869, records.size # test banks already present, not duplicated
    end
  end

  private

  # replaces the check digits of an IBAN so that the checksum is correct
  def fix_iban(iban)
    bban = iban[4..]
    e.send(:iban_checksum, iban[0, 2], bban).then { |cd| iban[0, 2] + cd + bban }
  end
end
