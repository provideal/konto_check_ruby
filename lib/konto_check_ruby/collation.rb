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

module KontoCheckRuby
  # Case and accent insensitive collation used for the search functions and
  # the sort index blocks (get_sortc / stri_cmp in the C source): letters are
  # folded to lower case and accented letters are compared like their base
  # letter (ä -> a, ß -> s, é -> e ...).
  module Collation
    FOLD = {
      "ä" => "a", "à" => "a", "á" => "a", "â" => "a", "ã" => "a", "å" => "a",
      "ö" => "o", "ò" => "o", "ó" => "o", "ô" => "o", "õ" => "o", "ø" => "o",
      "ü" => "u", "ù" => "u", "ú" => "u", "û" => "u",
      "è" => "e", "é" => "e", "ê" => "e", "ë" => "e",
      "ì" => "i", "í" => "i", "î" => "i", "ï" => "i",
      "ç" => "c", "ñ" => "n", "ý" => "y", "ÿ" => "y", "ß" => "s"
    }.freeze

    FOLD_RE = Regexp.union(FOLD.keys).freeze

    # Sort key of a string: lower case, accents removed. Non-letters are kept.
    def self.sort_key(str)
      s = str.to_s
      s = s.encode("UTF-8", invalid: :replace, undef: :replace) unless s.encoding == Encoding::UTF_8 && s.valid_encoding?
      s.downcase.gsub(FOLD_RE, FOLD)
    end

    # Words (alphanumeric sequences) of a string, for the full text search
    def self.words(str)
      s = str.to_s
      s = s.encode("UTF-8", invalid: :replace, undef: :replace) unless s.encoding == Encoding::UTF_8 && s.valid_encoding?
      s.scan(/[[:alnum:]]+/)
    end

    # Prefix comparison like strni_cmp(): 0 if a is a prefix of b (after folding)
    def self.prefix_cmp(a, b)
      ka = sort_key(a)
      kb = sort_key(b)
      return 0 if kb.start_with?(ka)
      ka <=> kb
    end
  end
end
