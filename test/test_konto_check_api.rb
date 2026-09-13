# frozen_string_literal: true

# Copyright (C) 2026 tickettoaster GmbH <https://tickettoaster.de>.
# Part of konto_check_ruby, a Ruby port of konto_check (Copyright (C)
# 2002-2023 Michael Plugge); licensed under the GNU Lesser General Public
# License, version 2.1 or later, see the file LICENSE.

require_relative "test_helper"

# Tests of the compatibility layer (KontoCheckRaw / KontoCheck) of the
# original konto_check gem.
class TestKontoCheckApi < Minitest::Test
  include KontoCheckRuby

  def setup
    KontoCheckRuby.engine = TestFixtures.lut_engine
  end

  def teardown
    KontoCheckRuby.engine = nil
  end

  def test_constants
    assert_equal 1, KontoCheckRaw::OK
    assert_equal -4, KontoCheckRaw::INVALID_BLZ
    assert_equal 0, KontoCheckRaw::FALSE
    assert_equal -133, KontoCheckRaw::BLZ_MARKED_AS_DELETED
  end

  def test_init_variants
    KontoCheckRuby.engine = Engine.new.tap { |x| x.current_date = TestFixtures::VALID_DATE }
    assert_equal OK, KontoCheckRaw.init(TestFixtures::LUT, 5)
    assert_equal OK, KontoCheck.init(3, TestFixtures::LUT)
    assert_equal 5, KontoCheck.current_init_level
    assert_equal TestFixtures::LUT, KontoCheck.current_lutfile_name
    assert_equal 1, KontoCheck.current_lutfile_set
    assert_raises(TypeError) { KontoCheckRaw.init(:sym, 5) }
    assert_raises(RuntimeError) { KontoCheckRaw.init("/nonexistent.lut2") }
    assert_equal OK, KontoCheck.init # bundled LUT file
    assert_equal Engine::BUNDLED_LUT, KontoCheck.current_lutfile_name
    assert_equal OK, KontoCheck.init(3, TestFixtures::LUT)
    assert_equal OK, KontoCheck.lut_blocks
    assert KontoCheck.free
    assert_raises(RuntimeError) { KontoCheck.konto_check("37040044", "532013000") }
    assert_raises(RuntimeError) { KontoCheckRaw.load_bank_data("x") }
  end

  def test_konto_check
    assert_equal OK, KontoCheck.konto_check("37040044", "532013000")
    assert_equal OK, KontoCheck.konto_check(37040044, 532013000)
    assert KontoCheck.konto_check?("37040044", "532013000")
    assert KontoCheck.valid?(37040044, 532013000)
    refute KontoCheck.valid?("37040044", "532013100")
    assert_equal INVALID_BLZ, KontoCheck.valid("12345678", "1")
    assert_raises(RuntimeError) { KontoCheck.konto_check(532013000, 37040044) } # swapped arguments (old interface)
    assert_raises(TypeError) { KontoCheck.konto_check(nil, "1") }
  end

  def test_konto_check_pz
    assert_equal OK, KontoCheck.konto_check_pz("00", "9290701")
    assert_equal OK, KontoCheck.konto_check_pz(0, 9290701)
    assert KontoCheck.konto_check_pz?("13", "532013000")
    refute KontoCheck.konto_check_pz?("13a", "5281741")
    assert KontoCheck.valid_pz?("06", 94012341)
    assert_equal OK, KontoCheck.valid_pz("52", "43001500", "13051172")
    assert_equal OK_TEST_BLZ_USED, KontoCheck.valid_pz("52", "43001500")
  end

  def test_konto_check_regel
    assert_equal OK_KTO_REPLACED, KontoCheck.konto_check_regel("10050000", "1111")
    assert KontoCheck.konto_check_regel?("37040044", "532013000")
    r = KontoCheckRaw.konto_check_regel_dbg("10050000", "1111")
    assert_equal 10, r.size
    assert_equal OK_KTO_REPLACED, r[0]
    assert_equal "10050000", r[1]
    assert_equal "6600012020", r[2]
    assert_equal "BELADEBEXXX", r[3]
    assert_equal 4, r[4]
    assert_equal 0, r[5]
  end

  def test_bank_functions
    assert_equal OK, KontoCheck.bank_valid("37040044")
    assert KontoCheck.bank_valid?("37040044", 16)
    refute KontoCheck.bank_valid?("37040044", 17)
    refute KontoCheck.bank_valid?("12345678")
    assert_equal 17, KontoCheck.bank_filialen("37040044")
    assert_equal [17, OK], KontoCheckRaw.bank_filialen("37040044")
    assert_equal [nil, INVALID_BLZ], KontoCheckRaw.bank_filialen("12345678")
    assert_equal "Commerzbank", KontoCheck.bank_name("37040044")
    assert_equal "Commerzbank Köln", KontoCheck.bank_name_kurz(37040044)
    assert_equal 50447, KontoCheck.bank_plz("37040044")
    assert_equal "Bergisch Gladbach", KontoCheck.bank_ort("37040044", 1)
    assert_equal 24370, KontoCheck.bank_pan("37040044")
    assert_equal "COBADEFFXXX", KontoCheck.bank_bic("37040044")
    assert_equal 6143, KontoCheck.bank_nr("37040044")
    assert_equal 13, KontoCheck.bank_pz("37040044")
    assert_equal "U", KontoCheck.bank_aenderung("37040044")
    assert_equal 0, KontoCheck.bank_loeschung("37040044")
    assert_equal 0, KontoCheck.bank_nachfolge_blz("37040044")
    assert_nil KontoCheck.bank_name("12345678")
    assert_equal [nil, LUT2_INDEX_OUT_OF_RANGE], KontoCheckRaw.bank_name("37040044", 99)
    alles = KontoCheck.bank_alles("37040044")
    assert_equal 13, alles.size
    assert_equal [OK, 17, "Commerzbank", "Commerzbank Köln", 50447, "Köln", 24370, "COBADEFFXXX", 13, 6143, "U", "0", 0], alles
    assert_equal [INVALID_BLZ, nil], KontoCheck.bank_alles("12345678")
    assert_equal LUT2_INDEX_OUT_OF_RANGE, KontoCheck.bank_alles("37040044", 50)
  end

  def test_iban_functions
    assert_equal OK, KontoCheck.iban_check("DE89370400440532013000")
    assert_equal [OK, OK], KontoCheckRaw.iban_check("DE89 3704 0044 0532 0130 00")
    assert_equal "DE89370400440532013000", KontoCheck.iban_gen("37040044", "532013000")
    assert_equal "DE89370400440532013000", KontoCheck.iban_gen(37040044, 532013000)
    assert_nil KontoCheck.iban_gen("37040044", "532013100")
    r = KontoCheckRaw.iban_gen("37040044", "532013000")
    assert_equal ["DE89370400440532013000", "DE89 3704 0044 0532 0130 00", OK, "COBADEFFXXX", "37040044", "0532013000", 5], r
    assert_equal [nil, nil, FALSE, nil, nil, nil, -1], KontoCheckRaw.iban_gen("37040044", "532013100")
    assert_equal "COBADEFFXXX", KontoCheck.iban2bic("DE89370400440532013000")
    assert_equal ["COBADEFFXXX", OK, "37040044", "0532013000"], KontoCheckRaw.iban2bic("DE89370400440532013000")
    assert_equal OK, KontoCheck.ci_check("DE98ZZZ09999999999")
    assert_equal INVALID_PARAMETER_TYPE, KontoCheck.ci_check(123)
    assert_equal OK, KontoCheck.bic_check("PBNKDEFFXXX")
    assert_equal [OK, 17], KontoCheckRaw.bic_check("PBNKDEFFXXX")
    assert_equal "92000000001234567890", KontoCheck.ipi_gen("1234567890")
    assert_equal ["92000000001234567890", "9200 0000 0012 3456 7890", OK], KontoCheckRaw.ipi_gen("1234567890")
    assert KontoCheck.ipi_check("92000000001234567890")
    refute KontoCheck.ipi_check("92000000001234567891")
  end

  def test_texts_and_misc
    assert_equal "die Bankleitzahl ist ungültig", KontoCheck.retval2txt(-4)
    assert_equal "INVALID_BLZ", KontoCheck.retval2txt_short(-4)
    assert_equal "INVALID_BLZ", KontoCheck.retval2txt_kurz(-4)
    assert_equal "die Bankleitzahl ist ung&uuml;ltig", KontoCheck.retval2html(-4)
    assert_equal "UTF-8", KontoCheck.encoding_str
    assert_equal 2, KontoCheck.encoding
    assert_match(/konto_check_ruby/, KontoCheck.version)
    assert_equal 1, KontoCheck.pz_aenderungen_enable
    assert_match(/Gueltigkeit der Daten/, KontoCheck.lut_info)
    assert_match(/Erster Datensatz/, KontoCheck.lut_info1(TestFixtures::LUT))
    assert_match(/Zweiter Datensatz/, KontoCheck.lut_info2(TestFixtures::LUT))
    assert_match(/Infoblock/, KontoCheck.dump_lutfile(TestFixtures::LUT))
    assert_nil KontoCheck.dump_lutfile("/nonexistent")
    r = KontoCheckRaw.lut_blocks(1)
    assert_equal OK, r[0]
    assert_match(/BLZ/, r[2])
    assert_equal NO_SCL_BLOCKS_LOADED, KontoCheckRaw.scl_init
    assert_nil KontoCheck.scl_sct("PBNKDEFFXXX")
  end

  def test_search_raw
    values, blz, zw, retval, anzahl = KontoCheckRaw.bank_suche_namen("Postbank")
    assert_equal OK, retval
    assert_operator anzahl, :>, 100
    assert_equal anzahl, values.size
    assert_equal anzahl, blz.size
    assert_equal blz, blz.uniq # uniq by default
    assert_equal blz, blz.sort
    assert(zw.all?(0))
    assert_match(/\APostbank/, values.first)
    values, blz, zw, retval, anzahl = KontoCheckRaw.bank_suche_ort("Köln", 0)
    assert_equal OK, retval
    assert_operator anzahl, :>, 50
    assert(values.all? { |v| v =~ /\AKöln/i })
    assert_equal [nil, nil, nil, KEY_NOT_FOUND, 0], KontoCheckRaw.bank_suche_ort("Zzzzz")
    values, blz, = KontoCheckRaw.bank_suche_plz(50667)
    assert(values.all?(50667))
    assert_operator blz.size, :>, 3
    values, blz, = KontoCheckRaw.bank_suche_blz(37040044, 37049999)
    assert_equal [37040044, 37040048, 37040060, 37040061], blz
    assert_equal blz, values
    values, blz, = KontoCheckRaw.bank_suche_blz("37040044-37049999")
    assert_equal 4, blz.size
    values, blz, = KontoCheckRaw.bank_suche_blz([37040044, 37049999])
    assert_equal 4, blz.size
    values, blz, = KontoCheckRaw.bank_suche_pz(52)
    assert_equal [52], values
    assert_equal [13051172], blz
    values, blz, = KontoCheckRaw.bank_suche_regel(5)
    assert(values.all?(5))
    assert_includes blz, 37040044
    values, blz, zw, retval, anzahl = KontoCheckRaw.bank_suche_bic("COBADEFF")
    assert_equal OK, retval
    assert(values.all? { |v| v.start_with?("COBADEFF") })
    words, blz, zw, retval, anzahl = KontoCheckRaw.bank_suche_volltext("Sparkasse")
    assert_equal OK, retval
    assert_includes words, "Sparkasse"
    assert_equal anzahl, blz.size
    _, blz, zw, retval, anzahl = KontoCheckRaw.bank_suche_multiple("Sparkasse Köln")
    assert_equal OK, retval
    assert_equal [37050198], blz
    assert_equal [0], zw
    assert_equal 1, anzahl
    assert_equal [nil, nil, nil, SOME_KEYS_NOT_FOUND, 0], KontoCheckRaw.bank_suche_multiple("Zzzzz Yyyyy")
  end

  def test_search_high_level
    assert_equal [37050198], KontoCheck.suche(multiple: "Sparkasse Köln")
    assert_includes KontoCheck.suche(ort: "Köln"), 37040044
    assert_includes KontoCheck.suche(city: "Köln"), 37040044
    assert_includes KontoCheck.suche(namen: "Commerzbank"), 37040044
    assert_includes KontoCheck.suche(plz: 50447), 37040044
    assert_includes KontoCheck.suche(bic: "COBADEFF"), 37040044
    assert_equal [13051172], KontoCheck.suche(pz: 52)
    assert_raises(RuntimeError) { KontoCheck.suche(foo: 1) }
  end

  def test_bic_biq_iban_field_functions
    assert_equal "Commerzbank", KontoCheckRaw.bic_name("COBADEFFXXX")[0][0, 11]
    assert_equal OK, KontoCheckRaw.bic_name("COBADEFFXXX")[1]
    start, cnt, retval = KontoCheckRaw.bic_info("COBADEFFXXX")
    assert_equal OK, retval
    assert_operator cnt, :>, 100
    assert_equal KontoCheckRaw.bic_ort("COBADEFFXXX")[0], KontoCheckRaw.biq_ort(start)[0]
    assert_raises(RuntimeError) { KontoCheckRaw.biq_name(0) } # like the C extension
    assert_equal ["Commerzbank", OK], KontoCheckRaw.iban_name("DE89370400440532013000")
    assert_equal [50447, OK], KontoCheckRaw.iban_plz("DE89370400440532013000")
    assert_equal [13, OK], KontoCheckRaw.iban_pz("DE89370400440532013000")
    assert_equal [nil, IBAN_ONLY_GERMAN], KontoCheckRaw.iban_name("GB82WEST12345698765432")
    assert_raises(TypeError) { KontoCheckRaw.bic_name(123) }
  end
end
