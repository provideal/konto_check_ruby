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

require "net/http"
require "uri"
require "fileutils"
require "json"
require_relative "retvals"
require_relative "blz_file"

module KontoCheckRuby
  # Self update of the bank data: fetches the current bank code file
  # ("Bankleitzahlendatei") from the download page of the Deutsche
  # Bundesbank, keeps it in a local cache directory and optionally writes a
  # LUT file from it.
  #
  #   result = KontoCheckRuby::Update.update            # download if a new file is available
  #   result.path                                       # => "~/.cache/konto_check_ruby/blz-20260907-20261206.xml"
  #   engine.load_current                               # cached current file, downloaded on demand
  #
  # The Bundesbank publishes a new file every quarter (validity periods
  # start in March, June, September and December); the download links are
  # content addressed (a hash in the URL, immutable), so a changed link means
  # a new file. The XML variant is used by default because it carries its
  # validity period; TXT and CSV are supported as well (the validity is then
  # taken from the download page).
  module Update
    DOWNLOAD_PAGE = "https://www.bundesbank.de/de/aufgaben/unbarer-zahlungsverkehr/serviceangebot/bankleitzahlen/download-bankleitzahlen-602592"
    FORMATS = { xml: "blz-aktuell-xml-data.xml", txt: "blz-aktuell-txt-data.txt", csv: "blz-aktuell-csv-data.csv" }.freeze
    USER_AGENT = "konto_check_ruby/#{VERSION} (+https://rubygems.org/gems/konto_check_ruby)"
    MAX_REDIRECTS = 5

    class Error < StandardError; end

    # Description of the current file on the download page
    Source = Struct.new(:url, :hash, :format, :valid_from, :valid_to, keyword_init: true) do
      # local file name: blz-<valid_from>-<valid_to>.<format>, or with the hash
      # if the validity is unknown
      def filename
        if valid_from && valid_to && valid_from != 0
          Kernel.format("blz-%08d-%08d.%s", valid_from, valid_to, self.format)
        else
          "blz-#{hash}.#{self.format}"
        end
      end
    end

    # Result of an update: status is :downloaded, :current (cached file is
    # up to date) or :offline (network failed, cached file used); path is the
    # local file, lut the generated LUT file (if requested).
    Result = Struct.new(:status, :path, :valid_from, :valid_to, :lut, :message, keyword_init: true)

    class << self
      # Cache directory: $KONTO_CHECK_RUBY_CACHE, else $XDG_CACHE_HOME/konto_check_ruby,
      # else ~/.cache/konto_check_ruby
      def cache_dir
        ENV["KONTO_CHECK_RUBY_CACHE"] ||
          File.join(ENV["XDG_CACHE_HOME"] || File.join(Dir.home, ".cache"), "konto_check_ruby")
      end

      # Parses the download page and returns the Source of the current file
      # of the given format. fetcher is a callable url -> body (for tests).
      def current_source(format: :xml, fetcher: method(:fetch))
        name = FORMATS.fetch(format.to_sym) { raise ArgumentError, "format must be one of #{FORMATS.keys.join(', ')}" }
        page = fetcher.call(DOWNLOAD_PAGE)
        parse_page(page, name, format.to_sym)
      end

      # Extracts link and validity of a file from the page HTML
      def parse_page(html, filename, format)
        html = html.dup.force_encoding("UTF-8")
        html = html.encode("UTF-8", "ISO-8859-1") unless html.valid_encoding?
        m = html.match(%r{href="(/resource/blob/(\d+)/([0-9a-f]{32})/[^"]*/#{Regexp.escape(filename)})"})
        raise Error, "download link for #{filename} not found on #{DOWNLOAD_PAGE}" unless m
        url = URI.join(DOWNLOAD_PAGE, m[1]).to_s
        v1 = v2 = 0
        if (vm = html.match(/g(?:ü|&uuml;|\\u00fc)ltig vom\s+(\d{2})\.(\d{2})\.(\d{4})\s+bis\s+(\d{2})\.(\d{2})\.(\d{4})/))
          v1 = (vm[3] + vm[2] + vm[1]).to_i
          v2 = (vm[6] + vm[5] + vm[4]).to_i
        end
        Source.new(url: url, hash: m[3], format: format, valid_from: v1, valid_to: v2)
      end

      # Downloads the current file into dir (default: cache_dir) unless it
      # is already there. With lut: PATH a LUT file is generated from it
      # (validity and IBAN rules included). force: true downloads again.
      # Raises Update::Error (network problems, unexpected page layout).
      def update(dir: cache_dir, format: :xml, force: false, lut: nil, iban_rules: :default, fetcher: method(:fetch))
        src = current_source(format: format, fetcher: fetcher)
        FileUtils.mkdir_p(dir)
        path = File.join(dir, src.filename)
        status = :current
        unless File.file?(path) && !force
          body = fetcher.call(src.url)
          if format.to_sym == :xml
            v1, v2 = xml_validity(body)
            if v1 != 0
              src.valid_from = v1
              src.valid_to = v2
              path = File.join(dir, src.filename)
            end
          end
          tmp = "#{path}.part"
          File.binwrite(tmp, body)
          File.rename(tmp, path)
          File.write(File.join(dir, "current.json"), JSON.pretty_generate(url: src.url, hash: src.hash, file: File.basename(path),
                                                                        valid_from: src.valid_from, valid_to: src.valid_to,
                                                                        downloaded: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")))
          status = :downloaded
        end
        lut_path = nil
        if lut
          code = BlzFile.generate_lut(path, lut, gueltigkeit: validity_string(src), filialen: true, felder: 9,
                                                 iban_rules: iban_rules,
                                                 user_info: "Bundesbank #{File.basename(path)}, konto_check_ruby #{VERSION}")
          raise Error, "LUT file could not be written: #{RETVAL_SHORT[code]}" if code < 0
          lut_path = lut
        end
        Result.new(status: status, path: path, valid_from: src.valid_from, valid_to: src.valid_to, lut: lut_path)
      end

      # The cached file with the latest validity (or nil). current_date
      # (JJJJMMTT) restricts the result to files valid on that date.
      def cached_file(dir: cache_dir, current_date: nil)
        files = Dir.glob(File.join(dir, "blz-*.{xml,txt,csv}")).map do |f|
          v1, v2 = File.basename(f).scan(/\d{8}/).first(2).map(&:to_i)
          [f, v1 || 0, v2 || 0]
        end
        files = files.select { |_f, v1, v2| v1 <= current_date && current_date <= v2 } if current_date
        best = files.max_by { |_f, v1, _v2| v1 }
        best && best.first
      end

      # Fetches an URL (following redirects). Returns the body as binary String.
      def fetch(url, limit = MAX_REDIRECTS)
        raise Error, "too many redirects for #{url}" if limit <= 0
        uri = URI.parse(url)
        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = USER_AGENT
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 20, read_timeout: 120) do |http|
          http.request(req)
        end
        case res
        when Net::HTTPSuccess then res.body.b
        when Net::HTTPRedirection then fetch(URI.join(url, res["location"]).to_s, limit - 1)
        else raise Error, "download of #{url} failed: #{res.code} #{res.message}"
        end
      rescue SocketError, SystemCallError, Timeout::Error, IOError, OpenSSL::SSL::SSLError => e
        raise Error, "download of #{url} failed: #{e.class}: #{e.message}"
      end

      private

      def xml_validity(body)
        head = body.b[0, 4096]
        v1 = head[%r{<ValidFrom>(\d{4})-(\d{2})-(\d{2})</ValidFrom>}] ? ($1 + $2 + $3).to_i : 0
        v2 = head[%r{<ValidTill>(\d{4})-(\d{2})-(\d{2})</ValidTill>}] ? ($1 + $2 + $3).to_i : 0
        [v1, v2]
      end

      def validity_string(src)
        return nil if src.valid_from.to_i == 0 || src.valid_to.to_i == 0
        format("%08d-%08d", src.valid_from, src.valid_to)
      end
    end
  end
end
