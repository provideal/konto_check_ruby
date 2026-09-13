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

# konto_check_ruby - pure Ruby port of the C library konto_check
# (check digit validation of German bank accounts, IBAN generation and
# validation, bank directory lookups) including a Ruby port of the LUT2
# file format and a parser for the Bundesbank bank code files.
#
# The module KontoCheckRuby contains the implementation (Engine, BankData,
# LutFile, BlzFile, CheckMethods); the modules KontoCheckRaw and KontoCheck
# provide the interface of the original konto_check gem.

require_relative "konto_check_ruby/version"
require_relative "konto_check_ruby/retvals"
require_relative "konto_check_ruby/lut_file"
require_relative "konto_check_ruby/blz_file"
require_relative "konto_check_ruby/bank_data"
require_relative "konto_check_ruby/check_methods"
require_relative "konto_check_ruby/engine"
require_relative "konto_check_ruby/update"
require_relative "konto_check_ruby/raw"
require_relative "konto_check_ruby/konto_check"

module KontoCheckRuby
  class << self
    # The engine used by the module level functions of KontoCheckRaw / KontoCheck
    def engine
      @engine ||= Engine.new
    end

    attr_writer :engine
  end
end
