#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (C) 2026 tickettoaster GmbH <https://tickettoaster.de>.
# Part of konto_check_ruby, a Ruby port of konto_check (Copyright (C)
# 2002-2023 Michael Plugge); licensed under the GNU Lesser General Public
# License, version 2.1 or later, see the file LICENSE.

# Differential test of the Ruby check methods against the C reference driver
# (kc_ref, built from the original konto_check.c).
#
# Usage:
#   ruby tools/difftest_methods.rb KC_REF_BINARY METHODS [COUNT] [SEED]
#
#   METHODS  comma separated list of numeric methods and/or ranges, e.g.
#            "0-50" or "13,52,116" (100 = A0, 110 = B0, 120 = C0, 130 = D0, 140 = E0)
#   COUNT    random account numbers per method/sub-method (default 300)
#
# Every method is tested without sub-method and with sub-methods a..g. For each
# input the tuple (result, methode, pz_methode, pz, pz_pos) of the C debug
# function kto_check_pz_dbg() is compared with the Ruby port.

require "open3"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "konto_check_ruby/check_methods"

kc_ref = ARGV[0] or abort "usage: difftest_methods.rb KC_REF METHODS [COUNT] [SEED]"
methods = (ARGV[1] || "0-144").split(",").flat_map do |part|
  if part =~ /\A(\d+)-(\d+)\z/ then ($1.to_i..$2.to_i).to_a else [part.to_i] end
end
count = (ARGV[2] || 300).to_i
seed = (ARGV[3] || 4711).to_i
rng = Random.new(seed)

CM = KontoCheckRuby::CheckMethods
BLZ_METHODS = [52, 53, 116, 120].freeze

def random_kto(rng)
  case rng.rand(10)
  when 0 then rng.rand(1..999_999).to_s
  when 1 then format("%010d", rng.rand(10_000_000_000))
  when 2 then "9" + format("%09d", rng.rand(1_000_000_000))
  when 3 then "00" + format("%08d", rng.rand(100_000_000))
  when 4 then format("%0#{rng.rand(1..10)}d", rng.rand(10**rng.rand(1..10)))
  when 5 then rng.rand(1..9).to_s * rng.rand(1..10)
  when 6 then (rng.rand(1..9).to_s + "0" * rng.rand(0..8) + rng.rand(0..9).to_s)[0, 10]
  else rng.rand(1..9_999_999_999).to_s
  end
end

cases = []
methods.each do |m|
  (0..7).each do |um|
    pz = CM.method_string(m + um * 1000)
    count.times do
      kto = random_kto(rng)
      blz = if BLZ_METHODS.include?(m) && rng.rand(3) > 0
              rng.rand(10_000_000..99_999_999).to_s
            else
              "-"
            end
      cases << [m, um, pz, kto, blz]
    end
  end
end

input = cases.map { |_, _, pz, kto, blz| "D #{pz} #{kto} #{blz}" }.join("\n") + "\n"
c_out, c_err, status = Open3.capture3(kc_ref, stdin_data: input)
abort "kc_ref failed: #{c_err}" unless status.success?
c_lines = c_out.lines.map(&:chomp)
abort "kc_ref returned #{c_lines.size} lines for #{cases.size} cases" unless c_lines.size == cases.size

fails = Hash.new(0)
tested = Hash.new(0)
shown = 0
cases.each_with_index do |(m, um, pz, kto, blz), i|
  rv = CM::Retvals.new("(-)", -1, -1, -1)
  b = blz == "-" ? nil : blz
  b = nil if b && b.start_with?("0")
  ret = begin
    CM.check(m + um * 1000, kto, b, um, rv)
  rescue StandardError => e
    "EXC #{e.class}: #{e.message} @ #{e.backtrace.first}"
  end
  rb = "#{ret} #{rv.methode} #{rv.pz_methode} #{rv.pz} #{rv.pz_pos}"
  tested[pz] += 1
  next if rb == c_lines[i]
  fails[pz] += 1
  if shown < 60
    shown += 1
    puts "MISMATCH method #{pz} kto=#{kto} blz=#{blz}: C=[#{c_lines[i]}] Ruby=[#{rb}]"
  end
end

puts "\nTested #{cases.size} cases, #{tested.size} method variants."
if fails.empty?
  puts "ALL OK"
else
  puts "FAILURES per method variant:"
  fails.sort.each { |pz, n| puts "  #{pz}: #{n}/#{tested[pz]}" }
  exit 1
end
