# frozen_string_literal: true

# Copyright (C) 2026 tickettoaster GmbH <https://tickettoaster.de>.
# Part of konto_check_ruby, a Ruby port of konto_check (Copyright (C)
# 2002-2023 Michael Plugge); licensed under the GNU Lesser General Public
# License, version 2.1 or later, see the file LICENSE.

require_relative "test_helper"

class TestUpdate < Minitest::Test
  include KontoCheckRuby
  U = KontoCheckRuby::Update
  PAGE = File.join(TestFixtures::FIXTURES, "bundesbank_download_page.html")

  # fetcher that serves the saved download page and the fixture files
  def fake_fetcher(calls = [])
    lambda do |url|
      calls << url
      case url
      when U::DOWNLOAD_PAGE then File.binread(PAGE)
      when /blz-aktuell-txt-data\.txt\z/ then File.binread(TestFixtures::BLZ_TXT)
      when /blz-aktuell-xml-data\.xml\z/
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?><Document><FileHdr><ValidFrom>2026-09-07</ValidFrom><ValidTill>2026-12-06</ValidTill></FileHdr>
          <BLZEintrag><BLZ>37040044</BLZ><Merkmal>1</Merkmal><Bezeichnung>Commerzbank</Bezeichnung><PLZ>50447</PLZ><Ort>Köln</Ort><Kurzbez>Commerzbank Köln</Kurzbez><PAN>24370</PAN><BIC>COBADEFFXXX</BIC><PruefZiffMeth>13</PruefZiffMeth><DsNr>6102</DsNr><Aenderungskennz>U</Aenderungskennz><BLZLoesch>0</BLZLoesch><NachfolgeBLZ>00000000</NachfolgeBLZ></BLZEintrag></Document>
        XML
      else raise U::Error, "unexpected url #{url}"
      end
    end
  end

  def test_parse_page
    src = U.parse_page(File.binread(PAGE), "blz-aktuell-xml-data.xml", :xml)
    assert_match(%r{\Ahttps://www\.bundesbank\.de/resource/blob/602630/[0-9a-f]{32}/.*/blz-aktuell-xml-data\.xml\z}, src.url)
    assert_equal 32, src.hash.length
    assert_equal 20260907, src.valid_from
    assert_equal 20261206, src.valid_to
    assert_equal "blz-20260907-20261206.xml", src.filename
    csv = U.parse_page(File.binread(PAGE), "blz-aktuell-csv-data.csv", :csv)
    assert_match(/csv\z/, csv.url)
    assert_raises(U::Error) { U.parse_page("<html></html>", "blz-aktuell-xml-data.xml", :xml) }
    assert_raises(ArgumentError) { U.current_source(format: :pdf, fetcher: ->(_u) { "" }) }
  end

  def test_update_downloads_once_and_writes_lut
    Dir.mktmpdir do |dir|
      calls = []
      r = U.update(dir: dir, format: :xml, fetcher: fake_fetcher(calls))
      assert_equal :downloaded, r.status
      assert_equal File.join(dir, "blz-20260907-20261206.xml"), r.path
      assert File.file?(r.path)
      assert File.file?(File.join(dir, "current.json"))
      assert_equal 2, calls.size
      r2 = U.update(dir: dir, format: :xml, fetcher: fake_fetcher(calls))
      assert_equal :current, r2.status
      assert_equal 3, calls.size # only the page was fetched again
      lut = File.join(dir, "blz.lut2f")
      r3 = U.update(dir: dir, format: :txt, lut: lut, fetcher: fake_fetcher(calls))
      assert_equal :downloaded, r3.status
      assert_equal File.join(dir, "blz-20260907-20261206.txt"), r3.path
      assert_equal lut, r3.lut
      code, i1, = LutFile.info(lut, 20261001)
      assert_equal OK, code
      assert_match(/20260907-20261206/, i1)
      e = Engine.new
      assert_equal OK, e.init(lut, 9)
      assert_equal [503, OK], e.lut_iban_regel("37040044") # built-in rule table applied
      assert_match(/blz-20260907-20261206\.(xml|txt)\z/, U.cached_file(dir: dir, current_date: 20261001))
      assert_nil U.cached_file(dir: dir, current_date: 20270101)
      assert_match(/blz-20260907-20261206\.(xml|txt)\z/, U.cached_file(dir: dir))
    end
  end

  def test_engine_load_current
    Dir.mktmpdir do |dir|
      e = Engine.new
      e.current_date = 20261001
      # nothing cached, no network: falls back to the bundled LUT
      assert_equal OK, e.load_current(dir: dir, refresh: :never)
      assert_equal Engine::BUNDLED_LUT, e.current_lutfile_name[0]
      U.update(dir: dir, format: :xml, fetcher: fake_fetcher)
      assert_equal OK, e.load_current(dir: dir, refresh: :never)
      assert_equal File.join(dir, "blz-20260907-20261206.xml"), e.current_lutfile_name[0]
      assert_equal 20260907, e.data.valid_from
      assert_equal ["Commerzbank", OK], e.lut_name("37040044")
      assert_equal LUT2_VALID, e.lut_valid
      assert_nil e.last_update_error
    end
  end

  def test_load_current_offline_fallback
    Dir.mktmpdir do |dir|
      e = Engine.new
      e.current_date = 20270101 # cached file expired -> tries to download -> fails
      U.update(dir: dir, format: :xml, fetcher: fake_fetcher)
      stub_fetch(->(_u) { raise U::Error, "offline" }) do
        assert_equal OK, e.load_current(dir: dir)
      end
      assert_equal "offline", e.last_update_error
      assert_match(/blz-20260907-20261206\.xml\z/, e.current_lutfile_name[0]) # newest cached file used
    end
  end

  def test_cache_dir_from_env
    old = ENV["KONTO_CHECK_RUBY_CACHE"]
    ENV["KONTO_CHECK_RUBY_CACHE"] = "/tmp/kc-cache-test"
    assert_equal "/tmp/kc-cache-test", U.cache_dir
  ensure
    ENV["KONTO_CHECK_RUBY_CACHE"] = old
  end

  # live download; only with KONTO_CHECK_LIVE=1
  def test_live_download
    skip "set KONTO_CHECK_LIVE=1 for the live download test" unless ENV["KONTO_CHECK_LIVE"]
    Dir.mktmpdir do |dir|
      r = U.update(dir: dir)
      assert_equal :downloaded, r.status
      e = Engine.new
      assert_equal OK, e.load_blz_file(r.path)
      assert_operator e.data.cnt_hs, :>, 3000
    end
  end

  private

  def stub_fetch(replacement)
    original = U.method(:fetch)
    U.define_singleton_method(:fetch) { |url, limit = 5| replacement.call(url) }
    yield
  ensure
    U.define_singleton_method(:fetch, original)
  end
end
