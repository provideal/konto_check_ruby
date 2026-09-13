# frozen_string_literal: true

# Copyright (C) 2026 tickettoaster GmbH <https://tickettoaster.de>.
# Part of konto_check_ruby, a Ruby port of konto_check (Copyright (C)
# 2002-2023 Michael Plugge); licensed under the GNU Lesser General Public
# License, version 2.1 or later, see the file LICENSE.

require_relative "test_helper"

class TestLutFile < Minitest::Test
  include KontoCheckRuby
  L = KontoCheckRuby::LutFile

  def test_adler32a_signed_chars
    assert_equal 1, L.adler32a("")
    assert_equal L.adler32a("abc"), Zlib.adler32("abc") # no high bytes: identical to zlib
    refute_equal L.adler32a("\xE4".b), Zlib.adler32("\xE4".b) # high bytes are signed
    assert_equal 0xffff_0000 & L.adler32a("\xE4".b) >> 16 << 16, L.adler32a("\xE4".b) & 0xffff_0000
  end

  def test_directory_of_fixture
    code, dir = L.directory(TestFixtures::LUT)
    assert_equal OK, code
    assert_equal COMPRESSION_ZLIB, dir.compression
    assert_equal 60, dir.slots
    assert_equal "BLZ Lookup Table/Format 2.0", dir.prolog_lines.first
    assert_includes dir.types, LUT2_BLZ
    assert_includes dir.types, LUT2_2_BLZ
    assert_equal 1, dir.slot_of(LUT2_BLZ)
    assert_equal 53, dir.free_slot
  end

  def test_read_block
    code, data = L.read_block(TestFixtures::LUT, LUT2_BLZ)
    assert_equal OK, code
    cnt_hs, cnt = data.unpack("vv")
    assert_equal 3564, cnt_hs
    assert_equal 14869, cnt
    code, = L.read_block(TestFixtures::LUT, 499)
    assert_equal LUT2_BLOCK_NOT_IN_FILE, code
    code, data = L.read_slot(TestFixtures::LUT, 1)
    assert_equal OK, code
    assert_match(/\AGueltigkeit der Daten: 20230305-20230604/, data)
  end

  def test_info_and_validity
    code, i1, i2, v1, v2 = L.info(TestFixtures::LUT, 20230401)
    assert_equal OK, code
    assert_equal LUT2_VALID, v1
    assert_match(/Erster Datensatz/, i1)
    assert_match(/Zweiter Datensatz/, i2)
    assert_equal LUT2_NOT_YET_VALID, v2
    _, _, _, v1, v2 = L.info(TestFixtures::LUT, 20300101)
    assert_equal LUT2_NO_LONGER_VALID, v1
    assert_equal LUT2_NO_LONGER_VALID_BETTER, v2 # the second set is younger
    assert_equal [20230305, 20230604], L.parse_validity(i1)
    assert_equal "7cd231d76fd3696b288559e070023d1a", L.file_id(i1)
    assert_equal FILE_READ_ERROR, L.info("/nonexistent.lut2")[0]
  end

  def test_prolog_info
    code, version, prolog, info, user_info = L.prolog_info(TestFixtures::LUT)
    assert_equal OK, code
    assert_equal 3, version
    assert_match(/\ABLZ Lookup Table/, prolog)
    assert_match(/generiert am 31.5.2023/, info)
    assert_match(/gueltig vom/, user_info)
  end

  def test_dump
    code, dump = L.dump(TestFixtures::LUT)
    assert_equal OK, code
    assert_match(/1. Infoblock/, dump)
    assert_match(/Kompressionsrate/, dump)
    assert_equal 60 + 5, dump.lines.size
  end

  def test_invalid_files
    Dir.mktmpdir do |dir|
      f = File.join(dir, "x.lut")
      File.binwrite(f, "not a lut file\nDATA\n")
      assert_equal INVALID_LUT_FILE, L.directory(f)[0]
      File.binwrite(f, "BLZ Lookup Table/Format 1.1\n")
      assert_equal LUT1_FILE_USED, L.directory(f)[0]
      File.binwrite(f, "BLZ Lookup Table/Format 2.0\nDATA\n\x05\x00abc")
      assert_equal LUT2_FILE_CORRUPTED, L.directory(f)[0]
    end
  end

  def test_create_write_read_roundtrip
    Dir.mktmpdir do |dir|
      f = File.join(dir, "new.lut2")
      assert_equal OK, L.create(f, "BLZ Lookup Table/Format 2.0\nTest", 60)
      payload = ("Hällo Welt\0" * 1000).b
      assert_equal OK, L.write_block(f, 501, payload)
      assert_equal OK, L.write_block(f, 502, "second".b)
      code, data = L.read_block(f, 501)
      assert_equal OK, code
      assert_equal payload, data
      assert_equal "second".b, L.read_block(f, 502)[1]
      # replacing a block reuses the slot
      assert_equal OK, L.write_block(f, 501, "replaced".b)
      assert_equal "replaced".b, L.read_block(f, 501)[1]
      code, dir_info = L.directory(f)
      assert_equal OK, code
      assert_equal [501, 502], dir_info.types.reject(&:zero?)
      assert_equal TOO_MANY_SLOTS, L.create(File.join(dir, "y.lut2"), "prolog", 501)
    end
  end

  def test_corrupted_block_is_detected
    Dir.mktmpdir do |dir|
      f = File.join(dir, "c.lut2")
      L.create(f, "BLZ Lookup Table/Format 2.0\nTest\nKompression: keine", 60)
      L.write_block(f, 501, "hello world".b)
      code, dir_info = L.directory(f)
      assert_equal COMPRESSION_NONE, dir_info.compression
      _typ, offset, = dir_info.entries[0]
      File.open(f, "r+b") do |io|
        io.seek(offset + 16)
        io.write("X")
      end
      assert_equal LUT_CRC_ERROR, L.read_block(f, 501)[0]
    end
  end

  def test_block_names
    assert_equal "BLZ", L.block_name(LUT2_BLZ)
    assert_equal "BLZ (2)", L.block_name(LUT2_2_BLZ)
    assert_equal "1. Infoblock", L.block_name(LUT2_INFO, 2)
    assert_equal "2. BLZ", L.block_name(LUT2_2_BLZ, 2)
    assert_equal "LUT2_2_BLZ", L.block_name(LUT2_2_BLZ, 3)
    assert_equal "(Userblock)", L.block_name(501, 2)
  end
end
