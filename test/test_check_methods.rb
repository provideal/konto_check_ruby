# frozen_string_literal: true

# Copyright (C) 2026 tickettoaster GmbH <https://tickettoaster.de>.
# Part of konto_check_ruby, a Ruby port of konto_check (Copyright (C)
# 2002-2023 Michael Plugge); licensed under the GNU Lesser General Public
# License, version 2.1 or later, see the file LICENSE.

require_relative "test_helper"

class TestCheckMethods < Minitest::Test
  include KontoCheckRuby
  CM = KontoCheckRuby::CheckMethods

  def test_normalize_kto
    assert_equal [0, 0, 0, 0, 0, 1, 2, 3, 4, 5], CM.normalize_kto("12345")
    assert_equal [0, 0, 0, 0, 0, 1, 2, 3, 4, 5], CM.normalize_kto("  0012345 ")
    assert_equal [1, 2, 3, 4, 5, 6, 7, 8, 9, 0], CM.normalize_kto("1234567890")
    assert_nil CM.normalize_kto("0")
    assert_nil CM.normalize_kto("")
    assert_nil CM.normalize_kto("12345678901")
  end

  def test_parse_method
    assert_equal [0, 0], CM.parse_method("00")
    assert_equal [1013, 1], CM.parse_method("13a")
    assert_equal [120, 0], CM.parse_method("C0")
    assert_equal [116, 0], CM.parse_method("b6")
    assert_equal [3116, 3], CM.parse_method("B6c")
    assert_nil CM.parse_method("1")
    assert_nil CM.parse_method("1x")
    assert_nil CM.parse_method("13ab")
  end

  def test_method_string
    assert_equal "00", CM.method_string(0)
    assert_equal "13a", CM.method_string(1013)
    assert_equal "B6", CM.method_string(116)
    assert_equal "E4b", CM.method_string(2144)
  end

  # examples from the Bundesbank description of the check digit methods
  def test_bundesbank_examples
    assert_equal OK, CM.check(0, "9290701")
    assert_equal OK, CM.check(0, "539290858")
    assert_equal OK, CM.check(0, "1501824")
    assert_equal FALSE, CM.check(0, "9290702")
    assert_equal OK, CM.check(6, "94012341")
    assert_equal OK, CM.check(6, "5073321010")
    assert_equal OK_NO_CHK, CM.check(9, "1234567890")
    assert_equal OK, CM.check(10, "12345008")
    assert_equal FALSE, CM.check(13, "5281741")
    assert_equal OK, CM.check(13, "532013000")
    assert_equal OK, CM.check(13, "532013001") # sub account digits are not checked
    assert_equal OK, CM.check(52, "43001500", "13051172")
    assert_equal OK_TEST_BLZ_USED, CM.check(52, "43001500", nil)
    assert_equal OK, CM.check(76, "0006543200")
    assert_equal OK, CM.check(76, "9012345600")
    assert_equal INVALID_KTO, CM.check(116, "1900001", "80053762") # B6, ESER account too short
    assert_equal INVALID_KTO_LENGTH, CM.check(0, "12345678901")
    assert_equal NOT_IMPLEMENTED, CM.check(999, "123")
    assert_equal UNDEFINED_SUBMETHOD, CM.check(8000, "123", nil, 8)
    assert_equal NOT_DEFINED, CM.check(12, "123")
  end

  def test_sub_methods_and_retvals
    rv = CM::Retvals.new("(-)", -1, -1, -1)
    assert_equal FALSE, CM.check(13, "123", nil, 0, rv)
    assert_equal "13b", rv.methode
    assert_equal 2013, rv.pz_methode
    assert_equal 10, rv.pz_pos
    rv = CM::Retvals.new("(-)", -1, -1, -1)
    CM.check(1013, "123", nil, 1, rv)
    assert_equal "13a", rv.methode
    assert_equal 8, rv.pz_pos
  end

  def test_all_methods_defined
    (0..144).each do |m|
      next if m == 12 # method 12 is "not defined"
      assert CM.respond_to?(:"m#{m}"), "method #{CM.method_string(m)} (#{m}) is missing"
    end
  end

  # regression vectors recorded from the original C library (kto_check_pz_dbg)
  def test_vectors_from_c_library
    vectors = JSON.parse(File.read(TestFixtures::VECTORS))
    failures = []
    vectors.each do |v|
      methode, um = CM.parse_method(v["method"])
      rv = CM::Retvals.new("(-)", -1, -1, -1)
      blz = v["blz"]
      blz = nil if blz && blz.start_with?("0")
      ret = CM.check(methode, v["kto"], blz, um, rv)
      got = [ret, rv.methode, rv.pz_methode, rv.pz, rv.pz_pos]
      want = [v["result"], v["methode"], v["pz_methode"], v["pz"], v["pz_pos"]]
      failures << "#{v['method']} #{v['kto']}: want #{want.inspect} got #{got.inspect}" if got != want
    end
    assert_empty failures, failures.first(10).join("\n")
    assert_operator vectors.size, :>, 2000
  end

  def test_kto_is_not_modified_for_caller
    kto = "1234567"
    CM.check(24, kto)
    assert_equal "1234567", kto
  end
end
