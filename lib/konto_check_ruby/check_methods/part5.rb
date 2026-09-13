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

    # Methode C3
    # Kontonummern mit 1. Stelle != 9: Methode 00 (Modulus 10, Gewichtung
    # 2,1,2,1,2,1,2,1,2); Kontonummern mit 1. Stelle == 9: Modulus 11,
    # Gewichtung 2,3,4,5,6 (Stellen 5 bis 9), Prüfziffer 10 ist ungültig.
    def m123(kto, blz, um, rv)
      if kto[0] != 9
        m1123(kto, blz, um, rv)
      else
        m2123(kto, blz, um, rv)
      end
    end

    # Methode C3a (Variante 1: Methode 00)
    def m1123(kto, blz, um, rv)
      if rv
        rv.methode = "C3a"
        rv.pz_methode = 1123
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode C3b (Variante 2: Modulus 11, Gewichtung 6,5,4,3,2)
    def m2123(kto, blz, um, rv)
      if rv
        rv.methode = "C3b"
        rv.pz_methode = 2123
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

    # Methode C4
    # 1. Stelle != 9: Modulus 11, Gewichtung 2,3,4,5 (Rest 0 und 1 -> Pz 0);
    # 1. Stelle == 9: Modulus 11, Gewichtung 2,3,4,5,6, Pz 10 ungültig.
    def m124(kto, blz, um, rv)
      if kto[0] != 9
        m1124(kto, blz, um, rv)
      else
        m2124(kto, blz, um, rv)
      end
    end

    # Methode C4a
    def m1124(kto, blz, um, rv)
      if rv
        rv.methode = "C4a"
        rv.pz_methode = 1124
      end
      pz = kto[5] * 5 +
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

    # Methode C4b
    def m2124(kto, blz, um, rv)
      if rv
        rv.methode = "C4b"
        rv.pz_methode = 2124
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

    # Methode C5
    # Vier Kontenkreise mit unterschiedlichen Verfahren (Methode 00 auf
    # verschiedenen Stellen, Methode 06/M10H-Variante, keine Prüfung).
    def m125(kto, blz, um, rv)
      m1125(kto, blz, um, rv)
    end

    # Methode C5a (Varianten 1a und 1b: Methode 00 auf 6- bzw. 9-stelligen
    # Kontonummern; Prüfziffer an Stelle 10 bzw. 7)
    def m1125(kto, blz, um, rv)
      if rv
        rv.methode = "C5a"
        rv.pz_methode = 1125
      end

      # Variante 1a: 6-stellige Kontonummern, 5. Stelle = 1-8, Pz an Stelle 10
      if kto[0] == 0 && kto[1] == 0 && kto[2] == 0 && kto[3] == 0 && kto[4] >= 1 && kto[4] <= 8
        pz = kto[5] + kto[7]
        pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
        pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
        pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
        pz %= 10
        pz = 10 - pz if pz != 0
        # CHECK_PZ10
        if rv
          rv.pz_pos = 10
          rv.pz = pz
        end
        return kto[9] == pz ? OK : FALSE

      # Variante 1b: 9-stellige Kontonummern, 2. Stelle = 1-8, Pz an Stelle 7
      elsif kto[0] == 0 && kto[1] >= 1 && kto[1] <= 8
        pz = kto[2] + kto[4]
        pz += kto[1] < 5 ? kto[1] * 2 : kto[1] * 2 - 9
        pz += kto[3] < 5 ? kto[3] * 2 : kto[3] * 2 - 9
        pz += kto[5] < 5 ? kto[5] * 2 : kto[5] * 2 - 9
        pz %= 10
        pz = 10 - pz if pz != 0
        # CHECK_PZ7
        if rv
          rv.pz_pos = 7
          rv.pz = pz
        end
        return kto[6] == pz ? OK : FALSE

      # Variante 2: 10-stellige Kontonummern, 1. Stelle = 1, 4, 5, 6 oder 9
      elsif kto[0] == 1 || (kto[0] >= 4 && kto[0] <= 6) || kto[0] == 9
        return m2125(kto, blz, um, rv)

      # Variante 3: 10-stellige Kontonummern, 1. Stelle = 3
      elsif kto[0] == 3
        return m3125(kto, blz, um, rv)

      # Variante 4: 8-stellige Kontonummern mit 3. Stelle = 3, 4 oder 5 bzw.
      # 10-stellige Kontonummern mit 1. und 2. Stelle = 70 oder 85
      elsif (kto[0] == 0 && kto[1] == 0 && kto[2] >= 3 && kto[2] <= 5) ||
            (kto[0] == 7 && kto[1] == 0) ||
            (kto[0] == 8 && kto[1] == 5)
        return m4125(kto, blz, um, rv)
      else
        # Kontonummer entspricht keinem vorgegebenen Kontenkreis
        return INVALID_KTO
      end
    end

    # Methode C5b (Variante 2: Modulus 10, iterierte Transformation)
    def m2125(kto, blz, um, rv)
      if rv
        rv.methode = "C5b"
        rv.pz_methode = 2125
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

    # Methode C5c (Variante 3: Methode 00)
    def m3125(kto, blz, um, rv)
      if rv
        rv.methode = "C5c"
        rv.pz_methode = 3125
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode C5d (Variante 4: keine Prüfzifferberechnung)
    def m4125(kto, blz, um, rv)
      if rv
        rv.methode = "C5d"
        rv.pz_methode = 4125
      end
      OK_NO_CHK
    end

    # Methode C6
    # Methode 00 über die Stellen 2 bis 9, wobei zur Summe abhängig von der
    # 1. Stelle der Kontonummer eine Konstante addiert wird.
    def m126(kto, blz, um, rv)
      if rv
        rv.methode = "C6"
        rv.pz_methode = 126
      end
      case kto[0]
      when 0 then pz = 30
      when 1 then pz = 33
      when 2 then pz = 36
      when 3 then pz = 38
      when 4 then pz = 45
      when 5 then pz = 41
      when 6 then pz = 43
      when 7 then pz = 31
      when 8 then pz = 40
      when 9 then pz = 40
      else return INVALID_KTO
      end

      pz += kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode C7
    # Variante 1 (evl. weggelassenes Unterkonto) und Variante 1 entsprechen
    # der Methode 63, Variante 2 der Methode 06 (Modulus 11).
    def m127(kto, blz, um, rv)
      if kto[0] == 0
        # bei Methode 63 sind 10-stellige Kontonummern falsch
        if kto[1] == 0 && kto[2] == 0
          # evl. Unterkonto weggelassen
          m3127(kto, blz, um, rv)
        else
          m1127(kto, blz, um, rv)
        end
      else
        m2127(kto, blz, um, rv)
      end
    end

    # Methode C7c (Methode 63 mit weggelassenem Unterkonto)
    def m3127(kto, blz, um, rv)
      if rv
        rv.methode = "C7c"
        rv.pz_methode = 3127
      end
      return INVALID_KTO if kto[0] != 0
      pz = kto[3] + kto[5] + kto[7]
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      # hier darf kein else-Zweig hin, damit nach 63c auch 63a geprüft wird
      m1127(kto, blz, um, rv)
    end

    # Methode C7a (Methode 63)
    def m1127(kto, blz, um, rv)
      if rv
        rv.methode = "C7a"
        rv.pz_methode = 1127
      end
      return INVALID_KTO if kto[0] != 0
      pz = kto[1] + kto[3] + kto[5]
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      return OK if kto[7] == pz
      return FALSE if um != 0
      m2127(kto, blz, um, rv)
    end

    # Methode C7b (Variante 2: Modulus 11, Gewichtung 2,3,4,5,6,7,2,3,4)
    def m2127(kto, blz, um, rv)
      if rv
        rv.methode = "C7b"
        rv.pz_methode = 2127
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

    # Methode C8
    # Variante 1: Methode 00, Variante 2: Modulus 11 mit Gewichtung
    # 2,3,4,5,6,7,2,3,4, Variante 3: Methode 07 (Pz 10 ungültig).
    def m128(kto, blz, um, rv)
      m1128(kto, blz, um, rv)
    end

    # Methode C8a (Variante 1: Methode 00)
    def m1128(kto, blz, um, rv)
      if rv
        rv.methode = "C8a"
        rv.pz_methode = 1128
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2128(kto, blz, um, rv)
    end

    # Methode C8b (Variante 2)
    def m2128(kto, blz, um, rv)
      if rv
        rv.methode = "C8b"
        rv.pz_methode = 2128
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
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m3128(kto, blz, um, rv)
    end

    # Methode C8c (Variante 3: Methode 07)
    def m3128(kto, blz, um, rv)
      if rv
        rv.methode = "C8c"
        rv.pz_methode = 3128
      end
      pz = kto[0] * 10 +
           kto[1] * 9 +
           kto[2] * 8 +
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

    # Methode C9
    # Variante 1: Methode 00, Variante 2: Methode 07 (Pz 10 ungültig).
    def m129(kto, blz, um, rv)
      m1129(kto, blz, um, rv)
    end

    # Methode C9a (Variante 1: Methode 00)
    def m1129(kto, blz, um, rv)
      if rv
        rv.methode = "C9a"
        rv.pz_methode = 1129
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2129(kto, blz, um, rv)
    end

    # Methode C9b (Variante 2: Methode 07)
    def m2129(kto, blz, um, rv)
      if rv
        rv.methode = "C9b"
        rv.pz_methode = 2129
      end
      pz = kto[0] * 10 +
           kto[1] * 9 +
           kto[2] * 8 +
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

    # Methode D0
    # Variante 2: Kontonummern, die mit 57 beginnen, werden nicht geprüft;
    # Variante 1: Modulus 11, Gewichtung 2,3,4,5,6,7,8,9,3.
    def m130(kto, blz, um, rv)
      m2130(kto, blz, um, rv)
    end

    # Methode D0b (Variante 2: keine Prüfung für Kontonummern mit 57)
    def m2130(kto, blz, um, rv)
      if rv
        rv.methode = "D0b"
        rv.pz_methode = 2130
      end
      if kto[0] == 5 && kto[1] == 7
        OK_NO_CHK
      else
        m1130(kto, blz, um, rv)
      end
    end

    # Methode D0a (Variante 1)
    def m1130(kto, blz, um, rv)
      if rv
        rv.methode = "D0a"
        rv.pz_methode = 1130
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

    # Methode D1
    # Methode 00 mit zusätzlicher Konstante 31; Kontonummern, die mit 8
    # beginnen, sind ungültig.
    def m131(kto, blz, um, rv)
      if rv
        rv.methode = "D1"
        rv.pz_methode = 131
      end
      return INVALID_KTO if kto[0] == 8
      pz = 31

      pz += kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode D2
    # Variante 1: Methode 95 (mit Ausnahmen), Variante 2: Methode 00,
    # Variante 3: Methode 68 (mit diversen Sonderfällen).
    def m132(kto, blz, um, rv)
      if rv
        rv.methode = "D2"
        rv.pz_methode = 132
      end
      m1132(kto, blz, um, rv)
    end

    # Methode D2a (Variante 1: Methode 95)
    def m1132(kto, blz, um, rv)
      if rv
        rv.methode = "D2a"
        rv.pz_methode = 1132
      end
      s = kto.join
      # Ausnahmen: keine Prüfzifferberechnung
      if (s >= "0000000001" && s <= "0001999999") ||
         (s >= "0009000000" && s <= "0025999999") ||
         (s >= "0396000000" && s <= "0499999999") ||
         (s >= "0700000000" && s <= "0799999999")
        return OK_NO_CHK
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
      m2132(kto, blz, um, rv)
    end

    # Methode D2b (Variante 2: Methode 00)
    def m2132(kto, blz, um, rv)
      if rv
        rv.methode = "D2b"
        rv.pz_methode = 2132
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m3132(kto, blz, um, rv)
    end

    # Methode D2c (Variante 3: Methode 68, mit diversen Sonderfällen; sie
    # werden hier nicht getrennt nummeriert, sondern alle unter Variante 3
    # geführt)
    def m3132(kto, blz, um, rv)
      if rv
        rv.methode = "D2c"
        rv.pz_methode = 3132
      end

      # Sonderfall: keine Prüfziffer
      return OK_NO_CHK if kto[0] == 0 && kto[1] == 4

      # 10stellige Kontonummern
      if kto[0] != 0
        return INVALID_KTO if kto[3] != 9
        pz = 9 + kto[5] + kto[7]   # 9: 7. Stelle von rechts
        pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
        pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
        pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
        pz %= 10
        pz = 10 - pz if pz != 0
        # CHECK_PZ10
        if rv
          rv.pz_pos = 10
          rv.pz = pz
        end
        return kto[9] == pz ? OK : FALSE
      end

      # 6 bis 9stellige Kontonummern: Variante 1
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      rv.pz = pz if rv
      return OK if kto[9] == pz

      # 6 bis 9stellige Kontonummern: Variante 2
      pz = kto[1] + kto[5] + kto[7]
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode D3
    # Variante 1: Methode 00, Variante 2: Methode 27 (Modulus 10, iterierte
    # Transformation) für Kontonummern ab 1.000.000.000.
    def m133(kto, blz, um, rv)
      if rv
        rv.methode = "D3"
        rv.pz_methode = 133
      end
      m1133(kto, blz, um, rv)
    end

    # Methode D3a (Variante 1: Methode 00)
    def m1133(kto, blz, um, rv)
      if rv
        rv.methode = "D3a"
        rv.pz_methode = 1133
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2133(kto, blz, um, rv)
    end

    # Methode D3b (Variante 2: Methode 27)
    def m2133(kto, blz, um, rv)
      if rv
        rv.methode = "D3b"
        rv.pz_methode = 2133
      end
      # Kontonummern von 1 bis 999.999.999 wurden schon nach Methode 00
      # geprüft, hier kann einfach FALSE zurückgegeben werden.
      return FALSE if kto[0] == 0
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

    # Methode D4
    # Methode 00 mit zusätzlicher Konstante 29; Kontonummern, die mit 0
    # beginnen, sind ungültig.
    def m134(kto, blz, um, rv)
      if rv
        rv.methode = "D4"
        rv.pz_methode = 134
      end
      if kto[0] == 0
        return INVALID_KTO
      else
        pz = 29
      end

      pz += kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode D5
    # Variante 1 (Stellen 3 und 4 == 99): Modulus 11, Gewichtung 2..7;
    # Varianten 2-4: Modulus 11, Modulus 7 und Modulus 10, Gewichtung 2..7.
    def m135(kto, blz, um, rv)
      if rv
        rv.methode = "D5"
        rv.pz_methode = 135
      end
      if kto[2] == 9 && kto[3] == 9
        m1135(kto, blz, um, rv)
      else
        m2135(kto, blz, um, rv)
      end
    end

    # Methode D5a (Variante 1)
    def m1135(kto, blz, um, rv)
      if rv
        rv.methode = "D5a"
        rv.pz_methode = 1135
      end
      # die Stellen 3 und 4 sind 99; das ergibt einen Rest von 3
      pz = 3 +
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

    # Methode D5b (Variante 2: Modulus 11, Gewichtung 2,3,4,5,6,7)
    def m2135(kto, blz, um, rv)
      if rv
        rv.methode = "D5b"
        rv.pz_methode = 2135
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
      m3135(kto, blz, um, rv)
    end

    # Methode D5c (Variante 3: Modulus 7, Gewichtung 2,3,4,5,6,7)
    def m3135(kto, blz, um, rv)
      if rv
        rv.methode = "D5c"
        rv.pz_methode = 3135
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 7
      pz = 7 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m4135(kto, blz, um, rv)
    end

    # Methode D5d (Variante 4: Modulus 10, Gewichtung 2,3,4,5,6,7)
    def m4135(kto, blz, um, rv)
      if rv
        rv.methode = "D5d"
        rv.pz_methode = 4135
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode D6
    # Variante 1: Methode 07, Variante 2: Methode 03, Variante 3: Methode 00.
    def m136(kto, blz, um, rv)
      if rv
        rv.methode = "D6"
        rv.pz_methode = 136
      end
      m1136(kto, blz, um, rv)
    end

    # Methode D6a (Variante 1: Methode 07)
    def m1136(kto, blz, um, rv)
      if rv
        rv.methode = "D6a"
        rv.pz_methode = 1136
      end
      pz = kto[0] * 10 +
           kto[1] * 9 +
           kto[2] * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      pz = 11 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2136(kto, blz, um, rv)
    end

    # Methode D6b (Variante 2: Methode 03)
    def m2136(kto, blz, um, rv)
      if rv
        rv.methode = "D6b"
        rv.pz_methode = 2136
      end
      pz = kto[0] * 2 +
           kto[1] +
           kto[2] * 2 +
           kto[3] +
           kto[4] * 2 +
           kto[5] +
           kto[6] * 2 +
           kto[7] +
           kto[8] * 2
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m3136(kto, blz, um, rv)
    end

    # Methode D6c (Variante 3: Methode 00)
    def m3136(kto, blz, um, rv)
      if rv
        rv.methode = "D6c"
        rv.pz_methode = 3136
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode D7
    # Methode 00, allerdings ohne die abschließende Subtraktion von 10
    # (die Prüfziffer ist direkt der Rest der Division durch 10).
    def m137(kto, blz, um, rv)
      if rv
        rv.methode = "D7"
        rv.pz_methode = 137
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode D8
    # Variante 2: Kontonummern 0010000000 bis 0099999999 werden nicht
    # geprüft, kleinere sind ungültig; Variante 1: Methode 00.
    def m138(kto, blz, um, rv)
      if rv
        rv.methode = "D8"
        rv.pz_methode = 138
      end
      m2138(kto, blz, um, rv)
    end

    # Methode D8b (Variante 2)
    def m2138(kto, blz, um, rv)
      if rv
        rv.methode = "D8b"
        rv.pz_methode = 2138
      end
      if kto[0] == 0
        if kto[1] == 0 && kto[2] > 0
          return OK_NO_CHK
        else
          return INVALID_KTO
        end
      end
      m1138(kto, blz, um, rv)
    end

    # Methode D8a (Variante 1: Methode 00)
    def m1138(kto, blz, um, rv)
      if rv
        rv.methode = "D8a"
        rv.pz_methode = 1138
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode D9
    # Variante 1: Methode 00, Variante 2: Methode 10, Variante 3: Methode 18.
    def m139(kto, blz, um, rv)
      if rv
        rv.methode = "D9"
        rv.pz_methode = 139
      end
      m1139(kto, blz, um, rv)
    end

    # Methode D9a (Variante 1: Methode 00)
    def m1139(kto, blz, um, rv)
      if rv
        rv.methode = "D9a"
        rv.pz_methode = 1139
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2139(kto, blz, um, rv)
    end

    # Methode D9b (Variante 2: Methode 10)
    def m2139(kto, blz, um, rv)
      if rv
        rv.methode = "D9b"
        rv.pz_methode = 2139
      end
      pz = kto[0] * 10 +
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
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m3139(kto, blz, um, rv)
    end

    # Methode D9c (Variante 3: Methode 18)
    def m3139(kto, blz, um, rv)
      if rv
        rv.methode = "D9c"
        rv.pz_methode = 3139
      end
      pz = kto[0] * 3 +
           kto[1] +
           kto[2] * 7 +
           kto[3] * 9 +
           kto[4] * 3 +
           kto[5] +
           kto[6] * 7 +
           kto[7] * 9 +
           kto[8] * 3
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode E0
    # Das Verfahren entspricht (bis auf die zusätzliche 7) genau dem
    # Verfahren 00.
    def m140(kto, blz, um, rv)
      if rv
        rv.methode = "E0"
        rv.pz_methode = 140
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz += 7
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode E1
    # Modulus 11, Gewichtung 1,2,3,4,5,6,11,10,9 (von rechts); die Prüfziffer
    # ist der Rest selbst, Rest 10 ist ungültig.
    def m141(kto, blz, um, rv)
      if rv
        rv.methode = "E1"
        rv.pz_methode = 141
      end
      # die Form (kto[x]+48) entspricht dem C-Code (für nicht-ASCII Plattformen)
      pz = (kto[0] + 48) * 9 +
           (kto[1] + 48) * 10 +
           (kto[2] + 48) * 11 +
           (kto[3] + 48) * 6 +
           (kto[4] + 48) * 5 +
           (kto[5] + 48) * 4 +
           (kto[6] + 48) * 3 +
           (kto[7] + 48) * 2 +
           (kto[8] + 48) -
           2442
      pz %= 11
      return FALSE if pz == 10
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode E2
    # Methode 00 mit zusätzlicher Konstante 25; Kontonummern, deren erste
    # Stelle größer als 5 ist, sind ungültig.
    def m142(kto, blz, um, rv)
      if rv
        rv.methode = "E2"
        rv.pz_methode = 142
      end
      return INVALID_KTO if kto[0] > 5
      pz = 25

      pz += kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode E3
    # Variante 1: Methode 00, Variante 2: Methode 21 (Quersummen-Iteration).
    def m143(kto, blz, um, rv)
      if rv
        rv.methode = "E3"
        rv.pz_methode = 143
      end
      m1143(kto, blz, um, rv)
    end

    # Methode E3a (Variante 1: Methode 00)
    def m1143(kto, blz, um, rv)
      if rv
        rv.methode = "E3a"
        rv.pz_methode = 1143
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2143(kto, blz, um, rv)
    end

    # Methode E3b (Variante 2: Methode 21)
    def m2143(kto, blz, um, rv)
      if rv
        rv.methode = "E3b"
        rv.pz_methode = 2143
      end
      pz = kto[0] * 2 +
           kto[1] +
           kto[2] * 2 +
           kto[3] +
           kto[4] * 2 +
           kto[5] +
           kto[6] * 2 +
           kto[7] +
           kto[8] * 2
      # iterierte Quersumme (wie im C-Code ausgeschrieben)
      pz = pz - 80 + 8 if pz >= 80
      pz = pz - 40 + 4 if pz >= 40
      pz = pz - 20 + 2 if pz >= 20
      pz = pz - 10 + 1 if pz >= 10
      pz = pz - 10 + 1 if pz >= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode E4
    # Variante 1: Methode 02, Variante 2: Methode 00.
    def m144(kto, blz, um, rv)
      if rv
        rv.methode = "E4"
        rv.pz_methode = 144
      end
      m1144(kto, blz, um, rv)
    end

    # Methode E4a (Variante 1: Methode 02)
    def m1144(kto, blz, um, rv)
      if rv
        rv.methode = "E4a"
        rv.pz_methode = 1144
      end
      pz = kto[0] * 2 +
           kto[1] * 9 +
           kto[2] * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      pz = 11 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2144(kto, blz, um, rv)
    end

    # Methode E4b (Variante 2: Methode 00)
    def m2144(kto, blz, um, rv)
      if rv
        rv.methode = "E4b"
        rv.pz_methode = 2144
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end
  end
end
