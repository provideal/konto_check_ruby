# frozen_string_literal: true

# Copyright (C) 2026 tickettoaster GmbH <https://tickettoaster.de>.
# Part of konto_check_ruby, a Ruby port of konto_check (Copyright (C)
# 2002-2023 Michael Plugge); licensed under the GNU Lesser General Public
# License, version 2.1 or later, see the file LICENSE.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
require "tmpdir"
require "json"
require "konto_check_ruby"

module TestFixtures
  FIXTURES = File.expand_path("fixtures", __dir__)
  LUT = File.join(FIXTURES, "blz.lut2f")
  BLZ_TXT = File.join(FIXTURES, "blz-aktuell-txt-data.txt")
  VECTORS = File.join(FIXTURES, "check_method_vectors.json")

  # a date inside the validity period of the LUT fixture (JJJJMMTT)
  VALID_DATE = 20230401

  def self.lut_engine
    @lut_engine ||= begin
      e = KontoCheckRuby::Engine.new
      e.current_date = VALID_DATE
      code = e.init(LUT, 9)
      raise "fixture LUT could not be loaded: #{code}" unless code == KontoCheckRuby::OK
      e
    end
  end

  def self.txt_engine
    @txt_engine ||= begin
      e = KontoCheckRuby::Engine.new
      code = e.load_blz_file(BLZ_TXT)
      raise "fixture BLZ file could not be loaded: #{code}" unless code == KontoCheckRuby::OK
      e
    end
  end
end
