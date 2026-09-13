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

require_relative "retvals"

module KontoCheckRuby
  # Port of kto_check_int() from konto_check.c: the check-digit methods
  # 00..E4 of the Deutsche Bundesbank.
  #
  # Every C `case N:` label of the big switch in kto_check_int() becomes a
  # method `mN(kto, blz, um, rv)` in this module (see check_methods/part*.rb).
  #
  #   kto : Array of 10 Integers (digits 0..9), the account number right
  #         aligned and left padded with zeros. Methods may modify it.
  #   blz : String with the bank code (8 digits) or nil
  #   um  : Integer, requested sub-method (0 = none, 1 = 'a', 2 = 'b', ...)
  #   rv  : Retvals struct (methode, pz_methode, pz, pz_pos) or nil
  #
  # Return value is one of the integer return codes (OK, FALSE, INVALID_KTO, ...).
  module CheckMethods
    extend self

    Retvals = Struct.new(:methode, :pz_methode, :pz, :pz_pos)

    # Weights for methods 27, 29 and 69 (m10h_digits in C)
    M10H_DIGITS = [
      [0, 1, 5, 9, 3, 7, 4, 8, 2, 6],
      [0, 1, 7, 6, 9, 8, 3, 2, 5, 4],
      [0, 1, 8, 4, 6, 2, 9, 5, 7, 3],
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    ].freeze

    # Tables for method 87
    TAB1 = [0, 4, 3, 2, 6].freeze
    TAB2 = [7, 1, 5, 9, 8].freeze

    # Weights for methods 24, 52/53/B6/C0 and 93
    W52 = [2, 4, 8, 5, 10, 9, 7, 3, 6, 1, 2, 4, 0, 0, 0, 0].freeze
    W24 = [1, 2, 3, 1, 2, 3, 1, 2, 3].freeze
    W93 = [2, 3, 4, 5, 6, 7, 2, 3, 4].freeze

    # Methods that may contain omitted sub-account numbers (uk_pz_methoden in C)
    UK_PZ_METHODEN = [13, 26, 50, 63, 76, 127].freeze

    # Converts the account number string into an array of 10 digits, exactly
    # as the prolog of kto_check_int() does: leading zeros, blanks and tabs
    # are skipped, the number ends at the first blank/tab, it must have 1..10
    # characters and is right aligned (zero padded) in a 10 digit field.
    # Returns nil if the length is invalid.
    def normalize_kto(kto)
      s = kto.to_s
      i = 0
      i += 1 while i < s.length && (s[i] == "0" || s[i] == " " || s[i] == "\t")
      j = i
      j += 1 while j < s.length && s[j] != " " && s[j] != "\t"
      len = j - i
      return nil if len < 1 || len > 10
      digits = Array.new(10, 0)
      k = 10 - len
      s.byteslice(i, len).each_byte do |b|
        digits[k] = b - 48
        k += 1
      end
      digits
    end

    # Converts a method string like "00", "51", "b6", "13a", "C0" into the
    # numeric method used by the C library (bx2/b1/by4 tables) and the
    # sub-method. Returns [pz_methode, untermethode] or nil for invalid input.
    def parse_method(pz)
      s = pz.to_s
      return nil if s.length < 2 || s.length > 3
      c1 = alnum_value(s[0])
      c2 = s[1] =~ /\A\d\z/ ? s[1].to_i : nil
      return nil if c1.nil? || c2.nil?
      methode = c1 * 10 + c2
      um = 0
      if s.length == 3
        um = letter_value(s[2])
        return nil if um.nil?
        methode += um * 1000
      end
      [methode, um]
    end

    # Numeric method -> two character method string ("00".."99", "A0".."E4")
    def method_string(pz_methode)
      base = pz_methode % 1000
      um = pz_methode / 1000
      s = base < 100 ? format("%02d", base) : ((base / 10) - 10 + 65).chr + (base % 10).to_s
      s += (96 + um).chr if um > 0
      s
    end

    # Runs check method pz_methode (an integer as in the C switch, e.g. 13,
    # 1013, 2013) for the account number kto (String). Returns the result code.
    def check(pz_methode, kto, blz = nil, um = 0, rv = nil)
      digits = normalize_kto(kto)
      return INVALID_KTO_LENGTH unless digits
      check_digits(pz_methode, digits, blz, um, rv)
    end

    # Same as check(), but with an already normalized digit array.
    def check_digits(pz_methode, digits, blz = nil, um = 0, rv = nil)
      meth = :"m#{pz_methode}"
      if respond_to?(meth)
        send(meth, digits, blz, um, rv)
      else
        # default branch of the C switch
        if rv
          rv.methode = "(-)"
          rv.pz_methode = -1
        end
        return UNDEFINED_SUBMETHOD if um && um != 0
        NOT_IMPLEMENTED
      end
    end

    private

    def alnum_value(c)
      case c
      when /\A\d\z/ then c.to_i
      when /\A[a-z]\z/ then c.ord - 97 + 10
      when /\A[A-Z]\z/ then c.ord - 65 + 10
      end
    end

    def letter_value(c)
      case c
      when /\A[a-z]\z/ then c.ord - 96
      when /\A[A-Z]\z/ then c.ord - 64
      end
    end
  end
end

Dir[File.join(__dir__, "check_methods", "*.rb")].sort.each { |f| require f }
