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
  module CheckMethods
    extend self

    # Methode 51
    # Modulus 11, Gewichtung 7,6,5,4,3,2 (Variante A); bei Mißerfolg
    # Varianten B (6,5,4,3,2), C (Luhn) und D (Modulus 7). Falls die dritte
    # Stelle eine 9 ist, werden stattdessen die Ausnahmevarianten E und F
    # gerechnet.
    def m51(kto, blz, um, rv)
      if kto[2] == 9 # Ausnahme
        return m5051(kto, blz, um, rv)
      end
      m1051(kto, blz, um, rv)
    end

    # Methode 51e (Ausnahme, Variante 1)
    def m5051(kto, blz, um, rv)
      if rv
        rv.methode = "51e"
        rv.pz_methode = 5051
      end
      pz = 9 * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      if pz <= 1
        pz = 0
      else
        pz = 11 - pz
      end
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m6051(kto, blz, um, rv)
    end

    # Methode 51f (Ausnahme, Variante 2)
    def m6051(kto, blz, um, rv)
      if rv
        rv.methode = "51f"
        rv.pz_methode = 6051
      end
      pz = kto[0] * 10 +
           kto[1] * 9 +
           9 * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      if pz <= 1
        pz = 0
      else
        pz = 11 - pz
      end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 51a (Modulus 11, Gewichtung 7,6,5,4,3,2)
    def m1051(kto, blz, um, rv)
      if rv
        rv.methode = "51a"
        rv.pz_methode = 1051
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      if pz <= 1
        pz = 0
      else
        pz = 11 - pz
      end
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2051(kto, blz, um, rv)
    end

    # Methode 51b (Modulus 11, Gewichtung 6,5,4,3,2)
    def m2051(kto, blz, um, rv)
      if rv
        rv.methode = "51b"
        rv.pz_methode = 2051
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      if pz <= 1
        pz = 0
      else
        pz = 11 - pz
      end
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m3051(kto, blz, um, rv)
    end

    # Methode 51c (Modulus 10, Gewichtung 2,1,2,1,2,1)
    def m3051(kto, blz, um, rv)
      if rv
        rv.methode = "51c"
        rv.pz_methode = 3051
      end
      pz = kto[3] + kto[5] + kto[7]
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m4051(kto, blz, um, rv)
    end

    # Methode 51d (Modulus 7, Gewichtung 6,5,4,3,2)
    def m4051(kto, blz, um, rv)
      if rv
        rv.methode = "51d"
        rv.pz_methode = 4051
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 7
      pz = 7 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 52
    # Für Konten die mit 9 beginnen: Berechnung nach Methode 20; sonst wird
    # aus BLZ und Kontonummer die Kontonummer des ESER-Altsystems generiert
    # und diese geprüft.
    def m52(kto, blz, um, rv)
      m1052(kto, blz, um, rv)
    end

    # Methode 52a (Berechnung nach Methode 20, nur für Konten mit führender 9)
    def m1052(kto, blz, um, rv)
      if rv
        rv.methode = "52a"
        rv.pz_methode = 1052
      end
      if kto[0] == 9
        pz = kto[0] * 3 +
             kto[1] * 9 +
             kto[2] * 8 +
             kto[3] * 7 +
             kto[4] * 6 +
             kto[5] * 5 +
             kto[6] * 4 +
             kto[7] * 3 +
             kto[8] * 2
        pz %= 11
        if pz <= 1
          pz = 0
        else
          pz = 11 - pz
        end
        # CHECK_PZ10
        if rv
          rv.pz_pos = 10
          rv.pz = pz
        end
        return kto[9] == pz ? OK : FALSE
      end
      m2052(kto, blz, um, rv)
    end

    # Methode 52b (Konto-Nr. des ESER-Altsystems generieren und prüfen)
    def m2052(kto, blz, um, rv)
      if rv
        rv.methode = "52b"
        rv.pz_methode = 2052
      end
      if blz.nil?
        ok = OK_TEST_BLZ_USED
        blz = "13051172"
      else
        ok = OK
      end

      # Generieren der Konto-Nr. des ESER-Altsystems
      ptr = 0
      ptr += 1 while ptr < 10 && kto[ptr] == 0
      return INVALID_KTO if ptr > 2
      kto_alt = Array.new(6, 0)
      kto_alt[0] = blz[4].to_i
      kto_alt[1] = blz[5].to_i
      kto_alt[2] = blz[6].to_i
      kto_alt[3] = blz[7].to_i
      kto_alt[4] = kto[ptr]
      ptr += 1
      kto_alt[5] = kto[ptr]
      ptr += 1
      if rv
        rv.pz_pos = ptr + 1
        rv.pz = kto_alt[5]
      end
      ptr += 1 while ptr < 10 && kto[ptr] == 0
      while ptr < 10
        kto_alt << kto[ptr]
        ptr += 1
      end
      # die Konto-Nr. des ESER-Altsystems darf maximal 12 Stellen haben
      return INVALID_KTO if kto_alt.length > 12

      p1 = kto_alt[5]   # Prüfziffer
      kto_alt[5] = 0
      pz = 0
      i = 0
      j = kto_alt.length - 1
      while j >= 0
        pz += kto_alt[j] * W52[i]
        j -= 1
        i += 1
      end
      kto_alt[5] = p1
      pz %= 11
      p1 = W52[i - 6]

      # passenden Faktor suchen
      tmp = pz
      i = 0
      while i < 10
        pz = tmp + p1 * i
        pz %= 11
        break if pz == 10
        i += 1
      end
      pz = i   # Prüfziffer ist der verwendete Faktor des Gewichtes
      # INVALID_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return INVALID_KTO if pz == 10
      kto_alt[5] == pz ? ok : FALSE
    end

    # Methode 53
    # Wie Methode 52, aber mit anderer Generierung der ESER-Kontonummer
    # (nur für neunstellige Kontonummern).
    def m53(kto, blz, um, rv)
      if kto[0] == 9
        return m1053(kto, blz, um, rv)
      end
      m2053(kto, blz, um, rv)
    end

    # Methode 53a (Berechnung nach Methode 20, nur für Konten mit führender 9)
    def m1053(kto, blz, um, rv)
      if rv
        rv.methode = "53a"
        rv.pz_methode = 1053
      end
      pz = kto[0] * 3 +
           kto[1] * 9 +
           kto[2] * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      if pz <= 1
        pz = 0
      else
        pz = 11 - pz
      end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 53b (Konto-Nr. des ESER-Altsystems generieren und prüfen)
    def m2053(kto, blz, um, rv)
      if rv
        rv.methode = "53b"
        rv.pz_methode = 2053
      end
      if blz.nil?
        ok = OK_TEST_BLZ_USED
        blz = "16052072"
      else
        ok = OK
      end

      # Generieren der Konto-Nr. des ESER-Altsystems; die Kto-Nr. muß
      # neunstellig sein
      if kto[0] != 0 || kto[1] == 0
        rv.pz = -2 if rv
        return INVALID_KTO
      end
      kto_alt = Array.new(6, 0)
      kto_alt[0] = blz[4].to_i
      kto_alt[1] = blz[5].to_i
      kto_alt[2] = kto[2]         # T-Ziffer
      kto_alt[3] = blz[7].to_i
      kto_alt[4] = kto[1]
      kto_alt[5] = kto[3]
      ptr = 4
      ptr += 1 while ptr < 10 && kto[ptr] == 0
      while ptr < 10
        kto_alt << kto[ptr]
        ptr += 1
      end

      p1 = kto_alt[5]   # Prüfziffer merken
      kto_alt[5] = 0
      pz = 0
      i = 0
      j = kto_alt.length - 1
      while j >= 0
        pz += kto_alt[j] * W52[i]
        j -= 1
        i += 1
      end
      kto_alt[5] = p1   # Prüfziffer zurückschreiben
      pz %= 11
      p1 = W52[i - 6]

      # passenden Faktor suchen
      tmp = pz
      i = 0
      while i < 10
        pz = tmp + p1 * i
        pz %= 11
        break if pz == 10
        i += 1
      end
      pz = i   # Prüfziffer ist der verwendete Faktor des Gewichtes
      rv.pz = pz if rv
      # INVALID_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return INVALID_KTO if pz == 10
      kto_alt[5] == pz ? ok : FALSE
    end

    # Methode 54
    # Modulus 11, Gewichtung 2,7,6,5,4,3,2. Die Kontonummer muß mit 49
    # beginnen.
    def m54(kto, blz, um, rv)
      if rv
        rv.methode = "54"
        rv.pz_methode = 54
      end
      return INVALID_KTO if kto[0] != 4 && kto[1] != 9
      pz = kto[2] * 2 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      pz = 11 - pz
      return INVALID_KTO if pz > 9
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 55
    # Modulus 11, Gewichtung 8,7,8,7,6,5,4,3,2
    def m55(kto, blz, um, rv)
      if rv
        rv.methode = "55"
        rv.pz_methode = 55
      end
      pz = kto[0] * 8 +
           kto[1] * 7 +
           kto[2] * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      if pz <= 1
        pz = 0
      else
        pz = 11 - pz
      end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 56
    # Modulus 11, Gewichtung 4,3,2,7,6,5,4,3,2; Sonderfall für Konten, die
    # mit 9 beginnen (Prüfziffer 7 bzw. 8).
    def m56(kto, blz, um, rv)
      if rv
        rv.methode = "56"
        rv.pz_methode = 56
      end
      pz = kto[0] * 4 +
           kto[1] * 3 +
           kto[2] * 2 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      pz = 11 - pz
      if pz > 9
        if kto[0] == 9
          if pz == 10
            pz = 7
          else
            pz = 8
          end
        else
          return INVALID_KTO
        end
      end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 57
    # Die Untermethoden werden anhand der ersten beiden Stellen der
    # Kontonummer ausgewählt (eigener innerer switch in C).
    def m57(kto, blz, um, rv)
      m1057(kto, blz, um, rv)
    end

    # Erste beide Stellen -> Variante 1 (57a, Modulus 10 Luhn auf Stellen 1-9)
    M57_VAR1 = [51, 55, 61, 64, 65, 66, 70, 73, 74, 75, 76, 77, 78, 79,
                80, 81, 82, 88, 94, 95].freeze
    # Variante 2 (57b, Modulus 10 Luhn auf Stellen 1,4-10)
    M57_VAR2 = [32, 33, 34, 35, 36, 37, 38, 39, 41, 42, 43, 44, 45, 46, 47,
                48, 49, 52, 53, 54, 56, 57, 58, 59, 60, 62, 63, 67, 68, 69,
                71, 72, 83, 84, 85, 86, 87, 89, 90, 92, 93, 96, 97, 98].freeze
    # Variante 3 (57c, keine Prüfziffer)
    M57_VAR3 = [40, 50, 91, 99].freeze

    def m1057(kto, blz, um, rv)
      if rv
        rv.methode = "57"
        rv.pz_methode = 57
      end
      # erstmal die Sonderfälle abhaken
      if kto[0, 6] == [7, 7, 7, 7, 7, 7] || kto[0, 6] == [8, 8, 8, 8, 8, 8]
        if rv
          rv.methode = "57a"
          rv.pz_methode = 1057
        end
        return OK_NO_CHK
      end
      if kto == [0, 1, 8, 5, 1, 2, 5, 4, 3, 4]
        if rv
          rv.methode = "57d"
          rv.pz_methode = 4057
        end
        return OK_NO_CHK
      end

      tmp = kto[0] * 10 + kto[1]   # die ersten beiden Stellen als Integer
      if M57_VAR1.include?(tmp)   # Variante 1
        if rv
          rv.methode = "57a"
          rv.pz_methode = 1057
        end
        pz = kto[0] + kto[2] + kto[4] + kto[6] + kto[8]
        if kto[1] < 5 then pz += kto[1] * 2 else pz += kto[1] * 2 - 9 end
        if kto[3] < 5 then pz += kto[3] * 2 else pz += kto[3] * 2 - 9 end
        if kto[5] < 5 then pz += kto[5] * 2 else pz += kto[5] * 2 - 9 end
        if kto[7] < 5 then pz += kto[7] * 2 else pz += kto[7] * 2 - 9 end
        pz %= 10
        pz = 10 - pz if pz != 0
        # CHECK_PZ10
        if rv
          rv.pz_pos = 10
          rv.pz = pz
        end
        kto[9] == pz ? OK : FALSE
      elsif M57_VAR2.include?(tmp)   # Variante 2
        if rv
          rv.methode = "57b"
          rv.pz_methode = 2057
        end
        pz = kto[0] + kto[3] + kto[5] + kto[7] + kto[9]
        if kto[1] < 5 then pz += kto[1] * 2 else pz += kto[1] * 2 - 9 end
        if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
        if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
        if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
        pz %= 10
        pz = 10 - pz if pz != 0
        # CHECK_PZ3
        if rv
          rv.pz_pos = 3
          rv.pz = pz
        end
        kto[2] == pz ? OK : FALSE
      elsif M57_VAR3.include?(tmp)   # Variante 3
        if rv
          rv.methode = "57c"
          rv.pz_methode = 3057
        end
        OK_NO_CHK
      else   # Variante 4: keine Prüfziffer, nur Plausibilitätsprüfung
        if rv
          rv.methode = "57d"
          rv.pz_methode = 4057
        end
        return INVALID_KTO if tmp == 0   # Kontonummern müssen mit 01 bis 31 beginnen
        tmp = kto[2] * 10 + kto[3]
        return INVALID_KTO if tmp == 0 || tmp > 12
        tmp = kto[6] * 100 + kto[7] * 10 + kto[8]
        return INVALID_KTO if tmp >= 500
        OK_NO_CHK
      end
    end

    def m2057(kto, blz, um, rv)
      m1057(kto, blz, um, rv)
    end

    def m3057(kto, blz, um, rv)
      m1057(kto, blz, um, rv)
    end

    def m4057(kto, blz, um, rv)
      m1057(kto, blz, um, rv)
    end

    # Methode 58
    # Modulus 11, Gewichtung 6,5,4,3,2
    def m58(kto, blz, um, rv)
      if rv
        rv.methode = "58"
        rv.pz_methode = 58
      end
      if kto[0] == 0 && kto[1] == 0 && kto[2] == 0 && kto[3] == 0 && kto[4] == 0
        return INVALID_KTO
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      pz = 11 - pz if pz != 0
      # INVALID_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return INVALID_KTO if pz == 10
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 59
    # Modulus 10, Gewichtung 2,1,2,1,2,1,2,1,2; Konten mit weniger als
    # 9 Stellen (führende 00) werden nicht geprüft.
    def m59(kto, blz, um, rv)
      if rv
        rv.methode = "59"
        rv.pz_methode = 59
      end
      return OK_NO_CHK if kto[0] == 0 && kto[1] == 0
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      if kto[0] < 5 then pz += kto[0] * 2 else pz += kto[0] * 2 - 9 end
      if kto[2] < 5 then pz += kto[2] * 2 else pz += kto[2] * 2 - 9 end
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 60
    # Modulus 10, Gewichtung 2,1,2,1,2,1,2 (Stellen 3 bis 9)
    def m60(kto, blz, um, rv)
      if rv
        rv.methode = "60"
        rv.pz_methode = 60
      end
      pz = kto[3] + kto[5] + kto[7]
      if kto[2] < 5 then pz += kto[2] * 2 else pz += kto[2] * 2 - 9 end
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 61
    # Modulus 10, Gewichtung 2,1,2,1,2,1,2; Prüfziffer ist die 8. Stelle.
    # Ist die 9. Stelle eine 8, werden die Stellen 9 und 10 einbezogen.
    def m61(kto, blz, um, rv)
      if kto[8] == 8
        return m2061(kto, blz, um, rv)
      end
      m1061(kto, blz, um, rv)
    end

    # Methode 61b (mit Einbeziehung der Stellen 9 und 10)
    def m2061(kto, blz, um, rv)
      if rv
        rv.methode = "61b"
        rv.pz_methode = 2061
      end
      pz = kto[1] + kto[3] + kto[5] + kto[8]
      if kto[0] < 5 then pz += kto[0] * 2 else pz += kto[0] * 2 - 9 end
      if kto[2] < 5 then pz += kto[2] * 2 else pz += kto[2] * 2 - 9 end
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      if kto[9] < 5 then pz += kto[9] * 2 else pz += kto[9] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      kto[7] == pz ? OK : FALSE
    end

    # Methode 61a (ohne Stellen 9 und 10)
    def m1061(kto, blz, um, rv)
      if rv
        rv.methode = "61a"
        rv.pz_methode = 1061
      end
      pz = kto[1] + kto[3] + kto[5]
      if kto[0] < 5 then pz += kto[0] * 2 else pz += kto[0] * 2 - 9 end
      if kto[2] < 5 then pz += kto[2] * 2 else pz += kto[2] * 2 - 9 end
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      kto[7] == pz ? OK : FALSE
    end

    # Methode 62
    # Modulus 10, Gewichtung 2,1,2,1 (Stellen 3 bis 6), Prüfziffer Stelle 8
    def m62(kto, blz, um, rv)
      if rv
        rv.methode = "62"
        rv.pz_methode = 62
      end
      pz = kto[3] + kto[5]
      if kto[2] < 5 then pz += kto[2] * 2 else pz += kto[2] * 2 - 9 end
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      kto[7] == pz ? OK : FALSE
    end

    # Methode 63
    # Modulus 10, Gewichtung 2,1,2,1,2,1; Prüfziffer Stelle 8. Falls die
    # Stellen 2 und 3 Null sind, wurde evl. ein Unterkonto weggelassen;
    # dann wird zuerst die verschobene Variante getestet.
    def m63(kto, blz, um, rv)
      if kto[1] == 0 && kto[2] == 0   # Unterkonto weggelassen
        return m2063(kto, blz, um, rv)
      end
      m1063(kto, blz, um, rv)
    end

    # Methode 63b (Unterkonto weggelassen, Prüfziffer Stelle 10)
    def m2063(kto, blz, um, rv)
      if rv
        rv.methode = "63b"
        rv.pz_methode = 2063
      end
      return INVALID_KTO if kto[0] != 0
      pz = kto[3] + kto[5] + kto[7]
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m1063(kto, blz, um, rv)
    end

    # Methode 63a (Prüfziffer Stelle 8)
    def m1063(kto, blz, um, rv)
      if rv
        rv.methode = "63a"
        rv.pz_methode = 1063
      end
      return INVALID_KTO if kto[0] != 0
      pz = kto[1] + kto[3] + kto[5]
      if kto[2] < 5 then pz += kto[2] * 2 else pz += kto[2] * 2 - 9 end
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      kto[7] == pz ? OK : FALSE
    end

    # Methode 64
    # Modulus 11, Gewichtung 9,10,5,8,4,2; Prüfziffer Stelle 7
    def m64(kto, blz, um, rv)
      if rv
        rv.methode = "64"
        rv.pz_methode = 64
      end
      pz = kto[0] * 9 +
           kto[1] * 10 +
           kto[2] * 5 +
           kto[3] * 8 +
           kto[4] * 4 +
           kto[5] * 2
      pz %= 11
      if pz <= 1
        pz = 0
      else
        pz = 11 - pz
      end
      # CHECK_PZ7
      if rv
        rv.pz_pos = 7
        rv.pz = pz
      end
      kto[6] == pz ? OK : FALSE
    end

    # Methode 65
    # Modulus 10, Gewichtung 2,1,2,1,2,1,2; Prüfziffer Stelle 8. Ist die
    # 9. Stelle eine 9, wird die 10. Stelle (Unterkonto) mit einbezogen.
    def m65(kto, blz, um, rv)
      if rv
        rv.methode = "65"
        rv.pz_methode = 65
      end
      pz = kto[1] + kto[3] + kto[5]
      if kto[0] < 5 then pz += kto[0] * 2 else pz += kto[0] * 2 - 9 end
      if kto[2] < 5 then pz += kto[2] * 2 else pz += kto[2] * 2 - 9 end
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      pz %= 10
      if kto[8] == 9
        p1 = kto[9] * 2
        p1 -= 9 if p1 > 9
        pz += p1 + 9
      end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      kto[7] == pz ? OK : FALSE
    end

    # Methode 66
    # Modulus 11, Gewichtung 7,0,0,6,5,4,3,2; Konten mit 9 an 2. Stelle
    # haben keine Prüfziffer.
    def m66(kto, blz, um, rv)
      m2066(kto, blz, um, rv)
    end

    # Methode 66b (Konten mit 9 an der 2. Stelle: keine Prüfziffer)
    def m2066(kto, blz, um, rv)
      if rv
        rv.methode = "66b"
        rv.pz_methode = 2066
      end
      return OK_NO_CHK if kto[1] == 9
      m1066(kto, blz, um, rv)
    end

    # Methode 66a
    def m1066(kto, blz, um, rv)
      if rv
        rv.methode = "66a"
        rv.pz_methode = 1066
      end
      return INVALID_KTO if kto[0] != 0
      pz = kto[1] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      if pz < 2
        pz = 1 - pz
      else
        pz = 11 - pz
      end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 67
    # Modulus 10, Gewichtung 2,1,2,1,2,1,2; Prüfziffer Stelle 8
    def m67(kto, blz, um, rv)
      if rv
        rv.methode = "67"
        rv.pz_methode = 67
      end
      pz = kto[1] + kto[3] + kto[5]
      if kto[0] < 5 then pz += kto[0] * 2 else pz += kto[0] * 2 - 9 end
      if kto[2] < 5 then pz += kto[2] * 2 else pz += kto[2] * 2 - 9 end
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      kto[7] == pz ? OK : FALSE
    end

    # Methode 68
    # Modulus 10, Gewichtung 2,1,2,1,2,1,2,1,2. Konten mit 10 Stellen
    # (4. Stelle 9) werden nach Variante a gerechnet, 6- bis 9-stellige
    # Konten nach Variante b bzw. c; Konten mit 04 am Anfang haben keine
    # Prüfziffer.
    def m68(kto, blz, um, rv)
      if rv
        rv.methode = "68"
        rv.pz_methode = 68
      end
      # die Kontonummer muß mindestens 6-stellig sein (ohne führende Nullen)
      if kto[0] == 0 && kto[1] == 0 && kto[2] == 0 && kto[3] == 0 && kto[4] == 0
        return INVALID_KTO
      end
      # Sonderfall: keine Prüfziffer
      return OK_NO_CHK if kto[0] == 0 && kto[1] == 4
      m1068(kto, blz, um, rv)
    end

    # Methode 68a (10stellige Kontonummern)
    def m1068(kto, blz, um, rv)
      if rv
        rv.methode = "68a"
        rv.pz_methode = 1068
      end
      if kto[0] != 0
        return INVALID_KTO if kto[3] != 9
        pz = 9 + kto[5] + kto[7]
        if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
        if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
        if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
        pz %= 10
        pz = 10 - pz if pz != 0
        # CHECK_PZ10
        if rv
          rv.pz_pos = 10
          rv.pz = pz
        end
        return kto[9] == pz ? OK : FALSE
      end
      m2068(kto, blz, um, rv)
    end

    # Methode 68b (6 bis 9stellige Kontonummern, Variante 1)
    def m2068(kto, blz, um, rv)
      if rv
        rv.methode = "68b"
        rv.pz_methode = 2068
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      if kto[2] < 5 then pz += kto[2] * 2 else pz += kto[2] * 2 - 9 end
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m3068(kto, blz, um, rv)
    end

    # Methode 68c (6 bis 9stellige Kontonummern, Variante 2)
    def m3068(kto, blz, um, rv)
      if rv
        rv.methode = "68c"
        rv.pz_methode = 3068
      end
      pz = kto[1] + kto[5] + kto[7]
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 69
    # Variante 1: Modulus 11, Gewichtung 8,7,6,5,4,3,2, Prüfziffer Stelle 8;
    # Variante 2: Verfahren 10H. Konten 93xxxxxxxx haben keine Prüfziffer,
    # Konten 97xxxxxxxx werden nur nach Variante 2 gerechnet.
    def m69(kto, blz, um, rv)
      if rv
        rv.methode = "69"
        rv.pz_methode = 69
      end
      # Sonderfall 93xxxxxxxx: Keine Prüfziffer
      return OK_NO_CHK if kto[0] == 9 && kto[1] == 3
      m1069(kto, blz, um, rv)
    end

    # Methode 69a (Variante 1)
    def m1069(kto, blz, um, rv)
      if rv
        rv.methode = "69a"
        rv.pz_methode = 1069
      end
      # Sonderfall 97xxxxxxxx nur über Variante 2
      if kto[0] != 9 || kto[1] != 7
        pz = kto[0] * 8 +
             kto[1] * 7 +
             kto[2] * 6 +
             kto[3] * 5 +
             kto[4] * 4 +
             kto[5] * 3 +
             kto[6] * 2
        pz %= 11
        if pz <= 1
          pz = 0
        else
          pz = 11 - pz
        end
        # CHECK_PZX8
        if rv
          rv.pz_pos = 8
          rv.pz = pz
        end
        return OK if kto[7] == pz
        return FALSE if um != 0
      end
      m2069(kto, blz, um, rv)
    end

    # Methode 69b (Variante 2, Verfahren 10H)
    def m2069(kto, blz, um, rv)
      if rv
        rv.methode = "69b"
        rv.pz_methode = 2069
      end
      pz = M10H_DIGITS[0][kto[0]] +
           M10H_DIGITS[3][kto[1]] +
           M10H_DIGITS[2][kto[2]] +
           M10H_DIGITS[1][kto[3]] +
           M10H_DIGITS[0][kto[4]] +
           M10H_DIGITS[3][kto[5]] +
           M10H_DIGITS[2][kto[6]] +
           M10H_DIGITS[1][kto[7]] +
           M10H_DIGITS[0][kto[8]]
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 70
    # Modulus 11, Gewichtung 4,3,2,7,6,5,4,3,2; Sonderfälle für Konten mit
    # 5 bzw. 69 ab der 4. Stelle.
    def m70(kto, blz, um, rv)
      if rv
        rv.methode = "70"
        rv.pz_methode = 70
      end
      if kto[3] == 5
        pz = 5 * 7 +
             kto[4] * 6 +
             kto[5] * 5 +
             kto[6] * 4 +
             kto[7] * 3 +
             kto[8] * 2
        pz %= 11
      elsif kto[3] == 6 && kto[4] == 9
        pz = 6 * 7 +
             9 * 6 +
             kto[5] * 5 +
             kto[6] * 4 +
             kto[7] * 3 +
             kto[8] * 2
        pz %= 11
      else
        pz = kto[0] * 4 +
             kto[1] * 3 +
             kto[2] * 2 +
             kto[3] * 7 +
             kto[4] * 6 +
             kto[5] * 5 +
             kto[6] * 4 +
             kto[7] * 3 +
             kto[8] * 2
        pz %= 11
      end
      if pz <= 1
        pz = 0
      else
        pz = 11 - pz
      end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 71
    # Modulus 11, Gewichtung 6,5,4,3,2,1 (Stellen 2 bis 7)
    def m71(kto, blz, um, rv)
      if rv
        rv.methode = "71"
        rv.pz_methode = 71
      end
      pz = kto[1] * 6 +
           kto[2] * 5 +
           kto[3] * 4 +
           kto[4] * 3 +
           kto[5] * 2 +
           kto[6]
      pz %= 11
      pz = 11 - pz if pz > 1
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 72
    # Modulus 10, Gewichtung 2,1,2,1,2,1 (Stellen 4 bis 9)
    def m72(kto, blz, um, rv)
      if rv
        rv.methode = "72"
        rv.pz_methode = 72
      end
      pz = kto[3] + kto[5] + kto[7]
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 73
    # Variante a: Modulus 10, Gewichtung 2,1,2,1,2,1 (Stellen 4 bis 9);
    # Variante b ohne Stelle 4, Variante c mit Modulus 7. Bei einer 9 an
    # der 3. Stelle wird wie bei Methode 51 gerechnet (Varianten d und e).
    def m73(kto, blz, um, rv)
      if kto[2] == 9   # Ausnahme, Berechnung wie in Verfahren 51
        return m4073(kto, blz, um, rv)
      end
      m1073(kto, blz, um, rv)
    end

    # Methode 73d (Ausnahme, Variante 1)
    def m4073(kto, blz, um, rv)
      if rv
        rv.methode = "73d"
        rv.pz_methode = 4073
      end
      pz = 9 * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      if pz <= 1
        pz = 0
      else
        pz = 11 - pz
      end
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m5073(kto, blz, um, rv)
    end

    # Methode 73e (Ausnahme, Variante 2)
    def m5073(kto, blz, um, rv)
      if rv
        rv.methode = "73e"
        rv.pz_methode = 5073
      end
      pz = kto[0] * 10 +
           kto[1] * 9 +
           9 * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      if pz <= 1
        pz = 0
      else
        pz = 11 - pz
      end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 73a
    def m1073(kto, blz, um, rv)
      if rv
        rv.methode = "73a"
        rv.pz_methode = 1073
      end
      pz1 = kto[5] + kto[7]
      if kto[4] < 5 then pz1 += kto[4] * 2 else pz1 += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz1 += kto[6] * 2 else pz1 += kto[6] * 2 - 9 end
      if kto[8] < 5 then pz1 += kto[8] * 2 else pz1 += kto[8] * 2 - 9 end
      pz = pz1 + kto[3]
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2073(kto, blz, um, rv)
    end

    # Methode 73b
    def m2073(kto, blz, um, rv)
      if rv
        rv.methode = "73b"
        rv.pz_methode = 2073
      end
      pz = kto[5] + kto[7]
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m3073(kto, blz, um, rv)
    end

    # Methode 73c (Modulus 7)
    def m3073(kto, blz, um, rv)
      if rv
        rv.methode = "73c"
        rv.pz_methode = 3073
      end
      pz = kto[5] + kto[7]
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
      pz %= 7
      pz = 7 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 74
    # Variante a: Modulus 10, Gewichtung 2,1,2,1,2,1,2,1,2; für 6-stellige
    # Kontonummern zusätzlich die Halbdekaden-Variante b; zum Schluß
    # Variante c (Modulus 11, Gewichtung 4,3,2,7,6,5,4,3,2).
    def m74(kto, blz, um, rv)
      if kto[0] == 0 && kto[1] == 0 && kto[2] == 0 && kto[3] == 0 && kto[4] == 0 &&
         kto[5] == 0 && kto[6] == 0 && kto[7] == 0 && kto[8] == 0
        return INVALID_KTO
      end
      m1074(kto, blz, um, rv)
    end

    # Methode 74a
    def m1074(kto, blz, um, rv)
      if rv
        rv.methode = "74a"
        rv.pz_methode = 1074
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      if kto[0] < 5 then pz += kto[0] * 2 else pz += kto[0] * 2 - 9 end
      if kto[2] < 5 then pz += kto[2] * 2 else pz += kto[2] * 2 - 9 end
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
      pz1 = pz   # Summe merken für Fall b
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      if kto[0] == 0 && kto[1] == 0 && kto[2] == 0 && kto[3] == 0 && kto[4] != 0
        return m2074(kto, blz, um, rv, pz1)
      end
      m3074(kto, blz, um, rv)
    end

    # Methode 74b (Hochrechnen auf die nächste Halbdekade)
    def m2074(kto, blz, um, rv, pz1 = 0)
      if rv
        rv.methode = "74b"
        rv.pz_methode = 2074
      end
      if um != 0
        # pz wurde noch nicht berechnet; jetzt erledigen
        pz1 = kto[5] + kto[7]
        if kto[4] < 5 then pz1 += kto[4] * 2 else pz1 += kto[4] * 2 - 9 end
        if kto[6] < 5 then pz1 += kto[6] * 2 else pz1 += kto[6] * 2 - 9 end
        if kto[8] < 5 then pz1 += kto[8] * 2 else pz1 += kto[8] * 2 - 9 end
      end
      pz = pz1
      if pz < 5
        pz += 5
      else
        pz -= 5
      end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 74c (Modulus 11, Gewichtung 4,3,2,7,6,5,4,3,2)
    def m3074(kto, blz, um, rv)
      if rv
        rv.methode = "74c"
        rv.pz_methode = 3074
      end
      pz = kto[0] * 4 +
           kto[1] * 3 +
           kto[2] * 2 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      pz = 11 - pz if pz != 0
      # INVALID_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return INVALID_KTO if pz == 10
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 75
    # Modulus 10, Gewichtung 2,1,2,1,2; die Stellen und die Position der
    # Prüfziffer hängen von der Länge der Kontonummer ab.
    def m75(kto, blz, um, rv)
      if rv
        rv.methode = "75"
        rv.pz_methode = 75
      end
      return INVALID_KTO if kto[0] != 0   # 10-stellige Kontonummer
      if kto[0] == 0 && kto[1] == 0   # 6/7-stellige Kontonummer
        m1075(kto, blz, um, rv)
      elsif kto[1] == 9   # 9-stellige Kontonummer, Variante 2
        m2075(kto, blz, um, rv)
      else   # 9-stellige Kontonummer, Variante 1
        m3075(kto, blz, um, rv)
      end
    end

    # Methode 75a (6/7-stellige Kontonummern)
    def m1075(kto, blz, um, rv)
      if rv
        rv.methode = "75a"
        rv.pz_methode = 1075
      end
      # 8- oder <6-stellige Kontonummer
      if kto[2] != 0 || (kto[2] == 0 && kto[3] == 0 && kto[4] == 0)
        return INVALID_KTO
      end
      pz = kto[5] + kto[7]
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      if kto[8] < 5 then pz += kto[8] * 2 else pz += kto[8] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 75b (9-stellige Kontonummern, Variante 2)
    def m2075(kto, blz, um, rv)
      if rv
        rv.methode = "75b"
        rv.pz_methode = 2075
      end
      pz = kto[3] + kto[5]
      if kto[2] < 5 then pz += kto[2] * 2 else pz += kto[2] * 2 - 9 end
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      kto[7] == pz ? OK : FALSE
    end

    # Methode 75c (9-stellige Kontonummern, Variante 1)
    def m3075(kto, blz, um, rv)
      if rv
        rv.methode = "75c"
        rv.pz_methode = 3075
      end
      pz = kto[2] + kto[4]
      if kto[1] < 5 then pz += kto[1] * 2 else pz += kto[1] * 2 - 9 end
      if kto[3] < 5 then pz += kto[3] * 2 else pz += kto[3] * 2 - 9 end
      if kto[5] < 5 then pz += kto[5] * 2 else pz += kto[5] * 2 - 9 end
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ7
      if rv
        rv.pz_pos = 7
        rv.pz = pz
      end
      kto[6] == pz ? OK : FALSE
    end

    # Methode 76
    # Modulus 11, Gewichtung 7,6,5,4,3,2; die erste Stelle (Kontoart) muß
    # 0, 4, 6, 7, 8 oder 9 sein. Bei achtstelligen Konten wird zusätzlich
    # die um zwei Stellen verschobene Variante b getestet.
    def m76(kto, blz, um, rv)
      m1076(kto, blz, um, rv)
    end

    # Methode 76a
    def m1076(kto, blz, um, rv)
      if rv
        rv.methode = "76a"
        rv.pz_methode = 1076
      end
      p1 = kto[0]
      if p1 == 1 || p1 == 2 || p1 == 3 || p1 == 5
        return INVALID_KTO
      end
      pz = kto[1] * 7 +
           kto[2] * 6 +
           kto[3] * 5 +
           kto[4] * 4 +
           kto[5] * 3 +
           kto[6] * 2
      pz %= 11
      # CHECK_PZX8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      return OK if kto[7] == pz
      return FALSE if um != 0
      return FALSE if kto[0] != 0 || kto[1] != 0
      m2076(kto, blz, um, rv)
    end

    # Methode 76b (Kontoart in Stelle 3)
    def m2076(kto, blz, um, rv)
      if rv
        rv.methode = "76b"
        rv.pz_methode = 2076
      end
      p1 = kto[2]
      if p1 == 1 || p1 == 2 || p1 == 3 || p1 == 5
        return INVALID_KTO
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      return INVALID_KTO if pz == 10
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 77
    # Modulus 11, Gewichtung 5,4,3,2,1 bzw. 5,4,3,4,5 auf die Stellen 6
    # bis 10; es gibt keine eigentliche Prüfziffer, die Summe muß ohne
    # Rest durch 11 teilbar sein.
    def m77(kto, blz, um, rv)
      m1077(kto, blz, um, rv)
    end

    # Methode 77a (Gewichtung 5,4,3,2,1)
    def m1077(kto, blz, um, rv)
      if rv
        rv.methode = "77a"
        rv.pz_methode = 1077
      end
      pz = kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2 +
           kto[9]
      pz %= 11
      return OK if pz == 0
      return INVALID_KTO if um != 0
      m2077(kto, blz, um, rv)
    end

    # Methode 77b (Gewichtung 5,4,3,4,5)
    def m2077(kto, blz, um, rv)
      if rv
        rv.methode = "77b"
        rv.pz_methode = 2077
      end
      pz = kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 4 +
           kto[9] * 5
      pz %= 11
      return OK if pz == 0
      return INVALID_KTO if um != 0
      FALSE
    end
  end
end
