#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (C) 2026 tickettoaster GmbH <https://tickettoaster.de>.
# Part of konto_check_ruby, a Ruby port of konto_check (Copyright (C)
# 2002-2023 Michael Plugge); licensed under the GNU Lesser General Public
# License, version 2.1 or later, see the file LICENSE.

# Differential test of the IBAN rules / IBAN generation against the C
# reference driver kc_ref (built from the original konto_check.c).
#
# Usage:
#   ruby tools/difftest_iban.rb KC_REF LUTFILE [COUNT] [SEED] [C_SOURCE] [RULES]
#
#   COUNT     random account numbers per bank (default 30)
#   C_SOURCE  path to konto_check.c; all numeric literals of the IBAN rule
#             section are used as additional account numbers (recommended)
#   RULES     comma separated list of IBAN rules to restrict the test to
#             (e.g. "5,20,33-35"); default: all banks with a rule plus a
#             sample of banks without rule
#
# For every (blz, kto) pair the outputs of kto_check_regel_dbg() and
# iban_bic_gen() of the C library are compared with the Ruby port.

require "open3"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "konto_check_ruby"

kc_ref = ARGV[0] or abort "usage: difftest_iban.rb KC_REF LUTFILE [COUNT] [SEED] [C_SOURCE] [RULES]"
lut = ARGV[1] or abort "LUT file missing"
count = (ARGV[2] || 30).to_i
seed = (ARGV[3] || 4711).to_i
c_source = ARGV[4]
rules_arg = ARGV[5]
rng = Random.new(seed)

engine = KontoCheckRuby::Engine.new
code = engine.init(lut, 9)
abort "init failed: #{code}" unless code > 0 || code == KontoCheckRuby::LUT2_PARTIAL_OK
data = engine.data

literals = []
if c_source && File.file?(c_source)
  src = File.read(c_source, encoding: "UTF-8", invalid: :replace)
  lines = src.lines
  from = lines.index { |l| l.start_with?("static int iban_regel_cvt(") } || 0
  to = lines.index { |l| l =~ /\A\/\* Funktion lut_multiple\(\)/ } || lines.size
  literals = lines[from...to].join.scan(/\b\d{1,10}\b/).uniq
  literals.reject! { |l| l.length == 8 && data.index(l.to_i) } # BLZs
end

rules = nil
if rules_arg
  rules = rules_arg.split(",").flat_map { |p| p =~ /\A(\d+)-(\d+)\z/ ? ($1.to_i..$2.to_i).to_a : [p.to_i] }
end

banks = []
data.cnt_hs.times do |i|
  regel = data.iban_regel[data.startidx[i]] / 100
  if rules
    banks << i if rules.include?(regel)
  elsif regel != 0 || rng.rand(12) == 0
    banks << i
  end
end

def random_kto(rng)
  case rng.rand(8)
  when 0 then rng.rand(1..99_999).to_s
  when 1 then format("%010d", rng.rand(10_000_000_000))
  when 2 then rng.rand(1..9).to_s + format("%08d", rng.rand(100_000_000))
  when 3 then format("%0#{rng.rand(1..10)}d", rng.rand(10**rng.rand(1..10)))
  when 4 then rng.rand(1..9).to_s + "0" * rng.rand(0..7) + rng.rand(0..99).to_s
  else rng.rand(1..9_999_999_999).to_s
  end
end

# for every bank also try to find a few account numbers that pass the check
def valid_ktos(engine, blz, rng, n)
  out = []
  200.times do
    k = random_kto(rng)
    out << k if engine.kto_check_blz(blz, k) > 0
    break if out.size >= n
  end
  out
end

cases = []
banks.each do |i|
  blz = data.blz[i].to_s
  ktos = Array.new(count) { random_kto(rng) }
  ktos += valid_ktos(engine, blz, rng, 5)
  ktos += literals.sample([literals.size, count * 2].min, random: rng)
  ktos += %w[1 12 123 1234 0 1111 7878 8888 9595 97097 112233 336666 484848 1900 135 500 1000000000 9999999999]
  ktos.uniq.each { |k| cases << [blz, k] }
end

input = cases.map { |b, k| "R #{b} #{k}\nG #{b} #{k}" }.join("\n") + "\n"
c_out, c_err, status = Open3.capture3(kc_ref, lut, "9", stdin_data: input)
abort "kc_ref failed: #{c_err}" unless status.success?
c_lines = c_out.lines.map(&:chomp)
abort "kc_ref returned #{c_lines.size} lines for #{cases.size * 2} commands" unless c_lines.size == cases.size * 2

def s(v)
  v.nil? ? "(null)" : v.to_s
end

fails = Hash.new(0)
tested = Hash.new(0)
shown = 0
cases.each_with_index do |(blz, kto), i|
  regel = data.iban_regel[data.startidx[data.index(blz.to_i)]] / 100
  tested[regel] += 1
  rb_r = begin
    ret, blz2, kto2, bic, rg, rv = engine.kto_check_regel_dbg(blz, kto)
    "#{ret} #{s(blz2)} #{s(kto2)} #{s(bic)} #{rg} #{s(rv.methode)} #{rv.pz_methode} #{rv.pz} #{rv.pz_pos}"
  rescue StandardError => e
    "EXC #{e.class}: #{e.message} @ #{e.backtrace.first}"
  end
  rb_g = begin
    ret, iban, bic, blz2, kto2 = engine.iban_bic_gen(blz, kto)
    "#{ret} #{s(iban)} #{s(bic)} #{s(blz2)} #{s(kto2)}"
  rescue StandardError => e
    "EXC #{e.class}: #{e.message} @ #{e.backtrace.first}"
  end
  c_r = c_lines[2 * i]
  c_g = c_lines[2 * i + 1]
  next if rb_r == c_r && rb_g == c_g
  fails[regel] += 1
  next unless shown < 80
  shown += 1
  puts "MISMATCH rule #{regel} blz=#{blz} kto=#{kto}"
  puts "   R: C=[#{c_r}]" if rb_r != c_r
  puts "      Ruby=[#{rb_r}]" if rb_r != c_r
  puts "   G: C=[#{c_g}]" if rb_g != c_g
  puts "      Ruby=[#{rb_g}]" if rb_g != c_g
end

puts "\nTested #{cases.size} (blz, kto) pairs for #{banks.size} banks, #{tested.size} different IBAN rules."
if fails.empty?
  puts "ALL OK"
else
  puts "FAILURES per IBAN rule:"
  fails.sort.each { |r, n| puts "  rule #{r}: #{n}/#{tested[r]}" }
  exit 1
end
