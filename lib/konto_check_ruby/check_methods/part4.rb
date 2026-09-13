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

# Port der Prüfziffermethoden A0 bis C2 (numerisch 100 bis 122) aus
# kto_check_int() von konto_check.c.

module KontoCheckRuby
  module CheckMethods
    extend self

    # Methode A0
    # Modulus 11, Gewichtung 10, 5, 8, 4, 2 (Stellen 5 bis 9).
    # Kontonummern, die mit 0000000 beginnen, werden nicht geprüft.
    def m100(kto, blz, um, rv)
      if rv
        rv.methode = "A0"
        rv.pz_methode = 100
      end
      return OK_NO_CHK if kto[0] == 0 && kto[1] == 0 && kto[2] == 0 && kto[3] == 0 &&
                          kto[4] == 0 && kto[5] == 0 && kto[6] == 0
      pz = kto[4] * 10 +
           kto[5] * 5 +
           kto[6] * 8 +
           kto[7] * 4 +
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

    # Methode A1
    # Modulus 10, Gewichtung 2, 1, 2, 1, 2, 1, 2 (Stellen 3 bis 9).
    # Kontonummern mit 0 an Stelle 1 sind nur gültig, wenn Stelle 2 und 3
    # nicht beide 0 sind bzw. Stelle 2 nicht 0 ist.
    def m101(kto, blz, um, rv)
      if rv
        rv.methode = "A1"
        rv.pz_methode = 101
      end
      if (kto[0] == 0 && kto[1] != 0) ||
         (kto[0] == 0 && kto[1] == 0 && kto[2] == 0)
        return INVALID_KTO
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

    # Methode A2: Variante 1 nach Methode 00, Variante 2 nach Methode 04.
    def m102(kto, blz, um, rv)
      m1102(kto, blz, um, rv)
    end

    # Methode A2, Variante 1 (Methode 00)
    def m1102(kto, blz, um, rv)
      if rv
        rv.methode = "A2a"
        rv.pz_methode = 1102
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      if kto[0] < 5 then pz += kto[0] * 2 else pz += kto[0] * 2 - 9 end
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
      m2102(kto, blz, um, rv)
    end

    # Methode A2, Variante 2 (Methode 04)
    def m2102(kto, blz, um, rv)
      if rv
        rv.methode = "A2b"
        rv.pz_methode = 2102
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

    # Methode A3: Variante 1 nach Methode 00, Variante 2 nach Methode 10.
    def m103(kto, blz, um, rv)
      m1103(kto, blz, um, rv)
    end

    # Methode A3, Variante 1 (Methode 00)
    def m1103(kto, blz, um, rv)
      if rv
        rv.methode = "A3a"
        rv.pz_methode = 1103
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      if kto[0] < 5 then pz += kto[0] * 2 else pz += kto[0] * 2 - 9 end
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
      m2103(kto, blz, um, rv)
    end

    # Methode A3, Variante 2 (Methode 10)
    def m2103(kto, blz, um, rv)
      if rv
        rv.methode = "A3b"
        rv.pz_methode = 2103
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
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode A4: vier bzw. fünf Varianten; Variante 1/2 wenn Stelle 3 und 4
    # nicht beide 9 sind, sonst Variante 3. Danach Methode 93 (Var. 4 und 5).
    def m104(kto, blz, um, rv)
      if kto[2] != 9 || kto[3] != 9
        m1104(kto, blz, um, rv)
      else
        m3104(kto, blz, um, rv)
      end
    end

    # Methode A4, Variante 1 (Modulus 11, Gewichtung 7, 6, 5, 4, 3, 2)
    def m1104(kto, blz, um, rv)
      if rv
        rv.methode = "A4a"
        rv.pz_methode = 1104
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
      m2104(kto, blz, um, rv)
    end

    # Methode A4, Variante 2 (Modulus 7, Gewichtung 7, 6, 5, 4, 3, 2)
    def m2104(kto, blz, um, rv)
      if rv
        rv.methode = "A4b"
        rv.pz_methode = 2104
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
      m4104(kto, blz, um, rv)
    end

    # Methode A4, Variante 3 (3. und 4. Stelle sind 9)
    def m3104(kto, blz, um, rv)
      if rv
        rv.methode = "A4c"
        rv.pz_methode = 3104
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
      m4104(kto, blz, um, rv)
    end

    # Methode A4, Variante 4 (Methode 93, Variante 1)
    def m4104(kto, blz, um, rv)
      if rv
        rv.methode = "A4d"
        rv.pz_methode = 4104
      end
      if kto[0] == 0 && kto[1] == 0 && kto[2] == 0 && kto[3] == 0 # Fall b)
        pz = kto[4] * 6 +
             kto[5] * 5 +
             kto[6] * 4 +
             kto[7] * 3 +
             kto[8] * 2
        p1 = pz
        pz %= 11
      else
        pz = kto[0] * 6 +
             kto[1] * 5 +
             kto[2] * 4 +
             kto[3] * 3 +
             kto[4] * 2
        kto[9] = kto[5] # Prüfziffer nach Stelle 10
        p1 = pz
        pz %= 11
      end
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
      m5104(kto, blz, um, rv, p1)
    end

    # Methode A4, Variante 5 (Methode 93, Variante 2)
    def m5104(kto, blz, um, rv, p1 = 0)
      if rv
        rv.methode = "A4e"
        rv.pz_methode = 5104
      end
      if um != 0 # pz wurde noch nicht berechnet
        if kto[0] == 0 && kto[1] == 0 && kto[2] == 0 && kto[3] == 0 # Fall b)
          p1 = kto[8] * W93[0] +
               kto[7] * W93[1] +
               kto[6] * W93[2] +
               kto[5] * W93[3] +
               kto[4] * W93[4]
        else
          p1 = kto[4] * W93[0] +
               kto[3] * W93[1] +
               kto[2] * W93[2] +
               kto[1] * W93[3] +
               kto[0] * W93[4]
          kto[9] = kto[5] # Prüfziffer nach Stelle 10
        end
      end
      pz = p1 % 7
      pz = 7 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode A5: Variante 1 nach Methode 00, Variante 2 nach Methode 10.
    # Bei Kontonummern mit 9 an Stelle 1 ist nur Variante 1 zulässig.
    def m105(kto, blz, um, rv)
      m1105(kto, blz, um, rv)
    end

    # Methode A5, Variante 1 (Methode 00)
    def m1105(kto, blz, um, rv)
      if rv
        rv.methode = "A5a"
        rv.pz_methode = 1105
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      if kto[0] < 5 then pz += kto[0] * 2 else pz += kto[0] * 2 - 9 end
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
      return INVALID_KTO if kto[0] == 9
      m2105(kto, blz, um, rv)
    end

    # Methode A5, Variante 2 (Methode 10)
    def m2105(kto, blz, um, rv)
      if rv
        rv.methode = "A5b"
        rv.pz_methode = 2105
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
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode A6: Variante 1 (Methode 00) wenn Stelle 2 eine 8 ist,
    # sonst Variante 2 (Methode 01).
    def m106(kto, blz, um, rv)
      if kto[1] == 8
        m1106(kto, blz, um, rv)
      else
        m2106(kto, blz, um, rv)
      end
    end

    # Methode A6, Variante 1 (Methode 00)
    def m1106(kto, blz, um, rv)
      if rv
        rv.methode = "A6a"
        rv.pz_methode = 1106
      end
      pz = 8 + kto[3] + kto[5] + kto[7]
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

    # Methode A6, Variante 2 (Methode 01)
    def m2106(kto, blz, um, rv)
      if rv
        rv.methode = "A6b"
        rv.pz_methode = 2106
      end
      pz = kto[0] +
           kto[1] * 7 +
           kto[2] * 3 +
           kto[3] +
           kto[4] * 7 +
           kto[5] * 3 +
           kto[6] +
           kto[7] * 7 +
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

    # Methode A7: Variante 1 nach Methode 00, Variante 2 nach Methode 03.
    def m107(kto, blz, um, rv)
      m1107(kto, blz, um, rv)
    end

    # Methode A7, Variante 1 (Methode 00)
    def m1107(kto, blz, um, rv)
      if rv
        rv.methode = "A7a"
        rv.pz_methode = 1107
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      if kto[0] < 5 then pz += kto[0] * 2 else pz += kto[0] * 2 - 9 end
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
      m2107(kto, blz, um, rv)
    end

    # Methode A7, Variante 2 (Gewichtung 2, 1, 2, 1, ... ohne Quersumme)
    def m2107(kto, blz, um, rv)
      if rv
        rv.methode = "A7b"
        rv.pz_methode = 2107
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
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode A8: bei 9 an Stelle 3 zuerst die Ausnahmevarianten c und d
    # (Methode 51 bzw. 10), sonst die Varianten a (Methode 32) und b.
    def m108(kto, blz, um, rv)
      if kto[2] == 9
        m3108(kto, blz, um, rv)
      else
        m1108(kto, blz, um, rv)
      end
    end

    # Methode A8, Ausnahme Variante 1 (wie Verfahren 51)
    def m3108(kto, blz, um, rv)
      if rv
        rv.methode = "A8c"
        rv.pz_methode = 3108
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
      m4108(kto, blz, um, rv)
    end

    # Methode A8, Ausnahme Variante 2 (Methode 10)
    def m4108(kto, blz, um, rv)
      if rv
        rv.methode = "A8d"
        rv.pz_methode = 4108
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
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode A8, Variante 1 (Methode 32)
    def m1108(kto, blz, um, rv)
      if rv
        rv.methode = "A8a"
        rv.pz_methode = 1108
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
      m2108(kto, blz, um, rv)
    end

    # Methode A8, Variante 2 (Methode 00 über die Stellen 4 bis 9)
    def m2108(kto, blz, um, rv)
      if rv
        rv.methode = "A8b"
        rv.pz_methode = 2108
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

    # Methode A9: Variante 1 nach Methode 01, Variante 2 nach Methode 06.
    def m109(kto, blz, um, rv)
      m1109(kto, blz, um, rv)
    end

    # Methode A9, Variante 1 (Methode 01)
    def m1109(kto, blz, um, rv)
      if rv
        rv.methode = "A9a"
        rv.pz_methode = 1109
      end
      pz = kto[0] +
           kto[1] * 7 +
           kto[2] * 3 +
           kto[3] +
           kto[4] * 7 +
           kto[5] * 3 +
           kto[6] +
           kto[7] * 7 +
           kto[8] * 3

      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2109(kto, blz, um, rv)
    end

    # Methode A9, Variante 2 (Methode 06)
    def m2109(kto, blz, um, rv)
      if rv
        rv.methode = "A9b"
        rv.pz_methode = 2109
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

    # Methode B0
    # Kontonummern mit 0 oder 8 an Stelle 1 sind ungültig. Bei 1, 2, 3 oder 6
    # an Stelle 8 entfällt die Prüfung, sonst Methode 06.
    def m110(kto, blz, um, rv)
      if rv
        rv.methode = "B0"
        rv.pz_methode = 110
      end
      return INVALID_KTO if kto[0] == 0 || kto[0] == 8

      if kto[7] == 1 || kto[7] == 2 || kto[7] == 3 || kto[7] == 6
        m1110(kto, blz, um, rv)
      else
        m2110(kto, blz, um, rv)
      end
    end

    # Methode B0, Variante 1 (keine Prüfung)
    def m1110(kto, blz, um, rv)
      if rv
        rv.methode = "B0a"
        rv.pz_methode = 1110
      end
      OK_NO_CHK
    end

    # Methode B0, Variante 2 (Methode 06)
    def m2110(kto, blz, um, rv)
      if rv
        rv.methode = "B0b"
        rv.pz_methode = 2110
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

    # Methode B1: Varianten nach den Methoden 05, 01 und 00.
    def m111(kto, blz, um, rv)
      m1111(kto, blz, um, rv)
    end

    # Methode B1, Variante 1 (Methode 05)
    def m1111(kto, blz, um, rv)
      if rv
        rv.methode = "B1a"
        rv.pz_methode = 1111
      end
      pz = kto[0] +
           kto[1] * 3 +
           kto[2] * 7 +
           kto[3] +
           kto[4] * 3 +
           kto[5] * 7 +
           kto[6] +
           kto[7] * 3 +
           kto[8] * 7

      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2111(kto, blz, um, rv)
    end

    # Methode B1, Variante 2 (Methode 01)
    def m2111(kto, blz, um, rv)
      if rv
        rv.methode = "B1b"
        rv.pz_methode = 2111
      end
      pz = kto[0] +
           kto[1] * 7 +
           kto[2] * 3 +
           kto[3] +
           kto[4] * 7 +
           kto[5] * 3 +
           kto[6] +
           kto[7] * 7 +
           kto[8] * 3

      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m3111(kto, blz, um, rv)
    end

    # Methode B1, Variante 3 (Methode 00)
    def m3111(kto, blz, um, rv)
      if rv
        rv.methode = "B1c"
        rv.pz_methode = 3111
      end
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

    # Methode B2: bei Stelle 1 kleiner 8 Methode 02, sonst Methode 00.
    def m112(kto, blz, um, rv)
      if kto[0] < 8
        m1112(kto, blz, um, rv)
      else
        m2112(kto, blz, um, rv)
      end
    end

    # Methode B2, Variante 1 (Methode 02)
    def m1112(kto, blz, um, rv)
      if rv
        rv.methode = "B2a"
        rv.pz_methode = 1112
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

    # Methode B2, Variante 2 (Methode 00)
    def m2112(kto, blz, um, rv)
      if rv
        rv.methode = "B2b"
        rv.pz_methode = 2112
      end
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

    # Methode B3: bei Stelle 1 kleiner 9 Methode 32, sonst Methode 06.
    def m113(kto, blz, um, rv)
      if kto[0] < 9
        m1113(kto, blz, um, rv)
      else
        m2113(kto, blz, um, rv)
      end
    end

    # Methode B3, Variante 1 (Methode 32)
    def m1113(kto, blz, um, rv)
      if rv
        rv.methode = "B3a"
        rv.pz_methode = 1113
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
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode B3, Variante 2 (Methode 06)
    def m2113(kto, blz, um, rv)
      if rv
        rv.methode = "B3b"
        rv.pz_methode = 2113
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

    # Methode B4: bei 9 an Stelle 1 Methode 00, sonst Methode 02.
    def m114(kto, blz, um, rv)
      if kto[0] == 9
        m1114(kto, blz, um, rv)
      else
        m2114(kto, blz, um, rv)
      end
    end

    # Methode B4, Variante 1 (Methode 00)
    def m1114(kto, blz, um, rv)
      if rv
        rv.methode = "B4a"
        rv.pz_methode = 1114
      end
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

    # Methode B4, Variante 2 (Methode 02)
    def m2114(kto, blz, um, rv)
      if rv
        rv.methode = "B4b"
        rv.pz_methode = 2114
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

    # Methode B5: Variante 1 nach Methode 05, Variante 2 nach Methode 00;
    # Variante 2 nur für Kontonummern mit 0 bis 7 an Stelle 1.
    def m115(kto, blz, um, rv)
      m1115(kto, blz, um, rv)
    end

    # Methode B5, Variante 1 (Methode 05)
    def m1115(kto, blz, um, rv)
      if rv
        rv.methode = "B5a"
        rv.pz_methode = 1115
      end
      pz = kto[0] +
           kto[1] * 3 +
           kto[2] * 7 +
           kto[3] +
           kto[4] * 3 +
           kto[5] * 7 +
           kto[6] +
           kto[7] * 3 +
           kto[8] * 7

      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      return FALSE if kto[0] > 7
      m2115(kto, blz, um, rv)
    end

    # Methode B5, Variante 2 (Methode 00)
    def m2115(kto, blz, um, rv)
      if rv
        rv.methode = "B5b"
        rv.pz_methode = 2115
      end
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

    # Methode B6: bei Kontonummern mit Stelle 1 größer 0 (oder 269 an den
    # Stellen 2 bis 4 und Stelle 5 größer 0) Prüfung nach Methode 20,
    # sonst Prüfung des ESER-Altsystems wie Methode 52.
    def m116(kto, blz, um, rv)
      if kto[0] > 0 || (kto[1] == 2 && kto[2] == 6 && kto[3] == 9 && kto[4] > 0)
        m1116(kto, blz, um, rv)
      else
        m2116(kto, blz, um, rv)
      end
    end

    # Methode B6, Variante 1 (Methode 20)
    def m1116(kto, blz, um, rv)
      if rv
        rv.methode = "B6a"
        rv.pz_methode = 1116
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

    # Methode B6, Variante 2 (ESER-Altsystem, Rechnung wie Methode 52)
    def m2116(kto, blz, um, rv)
      if rv
        rv.methode = "B6b"
        rv.pz_methode = 2116
      end
      if blz.nil?
        ok = OK_TEST_BLZ_USED
        blz = "80053762"
      else
        ok = OK
      end

      # Generieren der Konto-Nr. des ESER-Altsystems
      return INVALID_KTO if kto[0] != 0 || kto[1] == 0 # Kto-Nr. muß neunstellig sein

      kto_alt = Array.new(6)
      kto_alt[0] = blz[4].to_i
      kto_alt[1] = blz[5].to_i
      kto_alt[2] = kto[2] # T-Ziffer
      kto_alt[3] = blz[7].to_i
      kto_alt[4] = kto[1]
      kto_alt[5] = kto[3]
      j = 4
      j += 1 while j < 10 && kto[j] == 0
      while j < 10
        kto_alt << kto[j]
        j += 1
      end

      p1 = kto_alt[5] # Prüfziffer merken
      kto_alt[5] = 0
      pz = 0
      i = 0
      k = kto_alt.length - 1
      while k >= 0
        pz += kto_alt[k] * W52[i]
        k -= 1
        i += 1
      end
      kto_alt[5] = p1 # Prüfziffer zurückschreiben
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
      pz = i # Prüfziffer ist der verwendete Faktor des Gewichtes
      rv.pz = pz if rv
      # INVALID_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return INVALID_KTO if pz == 10

      if kto_alt[5] == pz
        ok
      else
        FALSE
      end
    end

    # Methode B7: Prüfung nach Methode 01 nur für bestimmte Kontonummern
    # (Stelle 1 = 0 und Stelle 2 = 7 oder 8, bzw. 00 und Stelle 4 in 1..5);
    # alle anderen Kontonummern werden nicht geprüft.
    def m117(kto, blz, um, rv)
      m1117(kto, blz, um, rv)
    end

    # Methode B7, Variante 1 (Methode 01)
    def m1117(kto, blz, um, rv)
      if rv
        rv.methode = "B7a"
        rv.pz_methode = 1117
      end
      if kto[0] == 0 && ((kto[1] == 7 || kto[1] == 8) ||
         (kto[1] == 0 && kto[2] == 0 && kto[3] >= 1 && kto[3] < 6))
        pz = kto[0] +
             kto[1] * 7 +
             kto[2] * 3 +
             kto[3] +
             kto[4] * 7 +
             kto[5] * 3 +
             kto[6] +
             kto[7] * 7 +
             kto[8] * 3

        pz %= 10
        pz = 10 - pz if pz != 0
        # CHECK_PZ10
        if rv
          rv.pz_pos = 10
          rv.pz = pz
        end
        kto[9] == pz ? OK : FALSE
      else
        m2117(kto, blz, um, rv)
      end
    end

    # Methode B7, Variante 2 (keine Prüfung)
    def m2117(kto, blz, um, rv)
      if rv
        rv.methode = "B7b"
        rv.pz_methode = 2117
      end
      OK_NO_CHK
    end

    # Methode B8: Variante 1 nach Methode 20, Variante 2 nach Methode 29,
    # Variante 3 (seit 6.6.2011) ohne Prüfung für bestimmte Kontonummern.
    def m118(kto, blz, um, rv)
      m1118(kto, blz, um, rv)
    end

    # Methode B8, Variante 1 (Methode 20)
    def m1118(kto, blz, um, rv)
      if rv
        rv.methode = "B8a"
        rv.pz_methode = 1118
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
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2118(kto, blz, um, rv)
    end

    # Methode B8, Variante 2 (Methode 29)
    def m2118(kto, blz, um, rv)
      if rv
        rv.methode = "B8b"
        rv.pz_methode = 2118
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
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m3118(kto, blz, um, rv)
    end

    # Methode B8, Variante 3 (neu zum 6.6.2011): keine Prüfung
    def m3118(kto, blz, um, rv)
      if rv
        rv.methode = "B8c"
        rv.pz_methode = 3118
      end
      if (kto[0] == 5 && kto[1] > 0) ||
         (kto[0] == 9 && kto[1] == 0 && kto[2] >= 1) ||
         (kto[0] == 9 && kto[1] == 1 && kto[2] == 0)
        return OK_NO_CHK
      end
      FALSE
    end

    # Methode B9
    # Nur Kontonummern mit 00 an den Stellen 1 und 2 (aber nicht 0000) sind
    # gültig. Bei Stelle 3 ungleich 0 Variante 1, sonst Variante 2. In beiden
    # Fällen wird bei Fehlschlag zusätzlich die um 5 erhöhte Prüfziffer geprüft.
    def m119(kto, blz, um, rv)
      if rv
        rv.methode = "B9"
        rv.pz_methode = 119
      end
      return INVALID_KTO if kto[0] != 0 || kto[1] != 0
      return INVALID_KTO if kto[0] == 0 && kto[1] == 0 && kto[2] == 0 && kto[3] == 0

      if kto[2] != 0
        m1119(kto, blz, um, rv)
      else
        m2119(kto, blz, um, rv)
      end
    end

    # Methode B9, Variante 1 (Gewichtung 1, 2, 3, 1, 2, 3, 1 mit Modulo-11-
    # Reduktion jedes Produkts)
    def m1119(kto, blz, um, rv)
      if rv
        rv.methode = "B9a"
        rv.pz_methode = 1119
      end
      pz = kto[2] * 1 + 1 # Maximum ist 9*1+1=10 -> kann direkt genommen werden

      pz1 = kto[3] * 2 + 2 # Maximum ist 9*2+2=20 -> nur ein Test auf >=11
      if pz1 >= 11
        pz += pz1 - 11
      else
        pz += pz1
      end

      pz1 = kto[4] * 3 + 3 # Maximum ist 9*3+3=30 -> zwei Tests nötig
      if pz1 >= 22
        pz += pz1 - 22
      elsif pz1 >= 11
        pz += pz1 - 11
      else
        pz += pz1
      end

      pz += kto[5] * 1 + 1

      pz1 = kto[6] * 2 + 2
      if pz1 >= 11
        pz += pz1 - 11
      else
        pz += pz1
      end

      pz1 = kto[7] * 3 + 3
      if pz1 >= 22
        pz += pz1 - 22
      elsif pz1 >= 11
        pz += pz1 - 11
      else
        pz += pz1
      end

      pz += kto[8] * 1 + 1

      pz %= 10
      rv.pz = pz if rv
      return OK if kto[9] == pz
      pz += 5
      pz %= 10
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode B9, Variante 2 (Modulus 11, Gewichtung 6, 5, 4, 3, 2, 1)
    def m2119(kto, blz, um, rv)
      if rv
        rv.methode = "B9b"
        rv.pz_methode = 2119
      end
      pz = kto[3] * 6 +
           kto[4] * 5 +
           kto[5] * 4 +
           kto[6] * 3 +
           kto[7] * 2 +
           kto[8] * 1

      pz %= 11
      rv.pz = pz if rv
      return OK if kto[9] == pz
      pz += 5
      pz %= 10
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode C0: bei Kontonummern mit 00 an Stelle 1/2 und Stelle 3 ungleich 0
    # zuerst die Prüfung des ESER-Altsystems (wie Methode 52), danach bzw.
    # sonst die Prüfung nach Methode 20.
    def m120(kto, blz, um, rv)
      if kto[0] == 0 && kto[1] == 0 && kto[2] != 0
        m1120(kto, blz, um, rv)
      else
        m2120(kto, blz, um, rv)
      end
    end

    # Methode C0, Variante 1 (ESER-Altsystem, Rechnung wie Methode 52)
    def m1120(kto, blz, um, rv)
      if rv
        rv.methode = "C0a"
        rv.pz_methode = 1120
      end
      if blz.nil?
        ok = OK_TEST_BLZ_USED
        blz = "13051172"
      else
        ok = OK
      end

      # Generieren der Konto-Nr. des ESER-Altsystems
      j = 0
      j += 1 while j < 10 && kto[j] == 0
      return INVALID_KTO if j > 2

      kto_alt = Array.new(6)
      kto_alt[0] = blz[4].to_i
      kto_alt[1] = blz[5].to_i
      kto_alt[2] = blz[6].to_i
      kto_alt[3] = blz[7].to_i
      kto_alt[4] = kto[j]
      j += 1
      kto_alt[5] = kto[j]
      j += 1
      j += 1 while j < 10 && kto[j] == 0
      while j < 10
        kto_alt << kto[j]
        j += 1
      end

      p1 = kto_alt[5] # Prüfziffer
      kto_alt[5] = 0
      pz = 0
      i = 0
      k = kto_alt.length - 1
      while k >= 0
        pz += kto_alt[k] * W52[i]
        k -= 1
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
      pz = i
      return ok if kto_alt[5] == pz
      return FALSE if um != 0
      m2120(kto, blz, um, rv)
    end

    # Methode C0, Variante 2 (Methode 20)
    def m2120(kto, blz, um, rv)
      if rv
        rv.methode = "C0b"
        rv.pz_methode = 2120
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

    # Methode C1: bei Stelle 1 ungleich 5 Prüfung nach Methode 17 (Prüfziffer
    # an Stelle 8), sonst Methode 00 mit Prüfziffer an Stelle 10.
    def m121(kto, blz, um, rv)
      if kto[0] != 5
        m1121(kto, blz, um, rv)
      else
        m2121(kto, blz, um, rv)
      end
    end

    # Methode C1, Variante 1 (Methode 17)
    def m1121(kto, blz, um, rv)
      if rv
        rv.methode = "C1a"
        rv.pz_methode = 1121
      end
      pz = kto[1] + kto[3] + kto[5]
      if kto[2] < 5 then pz += kto[2] * 2 else pz += kto[2] * 2 - 9 end
      if kto[4] < 5 then pz += kto[4] * 2 else pz += kto[4] * 2 - 9 end
      if kto[6] < 5 then pz += kto[6] * 2 else pz += kto[6] * 2 - 9 end

      pz -= 1
      pz %= 11 if pz >= 0 # MOD_11_44 läßt negative Werte unverändert
      pz = 10 - pz if pz != 0
      # CHECK_PZ8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      kto[7] == pz ? OK : FALSE
    end

    # Methode C1, Variante 2 (Stelle 1 = 5)
    def m2121(kto, blz, um, rv)
      if rv
        rv.methode = "C1b"
        rv.pz_methode = 2121
      end
      pz = kto[0] + kto[2] + kto[4] + kto[6] + kto[8]
      if kto[1] < 5 then pz += kto[1] * 2 else pz += kto[1] * 2 - 9 end
      if kto[3] < 5 then pz += kto[3] * 2 else pz += kto[3] * 2 - 9 end
      if kto[5] < 5 then pz += kto[5] * 2 else pz += kto[5] * 2 - 9 end
      if kto[7] < 5 then pz += kto[7] * 2 else pz += kto[7] * 2 - 9 end

      pz -= 1
      pz %= 11 if pz >= 0 # MOD_11_44 läßt negative Werte unverändert
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode C2: Variante 1 (Gewichtung 3, 1, 3, ... mit Quersumme),
    # Variante 2 nach Methode 00, Variante 3 (ab September 2017) nach
    # Methode 04.
    def m122(kto, blz, um, rv)
      m1122(kto, blz, um, rv)
    end

    # Methode C2, Variante 1
    def m1122(kto, blz, um, rv)
      if rv
        rv.methode = "C2a"
        rv.pz_methode = 1122
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]

      if kto[0] < 4
        pz += kto[0] * 3
      elsif kto[0] < 7
        pz += kto[0] * 3 - 10
      else
        pz += kto[0] * 3 - 20
      end

      if kto[2] < 4
        pz += kto[2] * 3
      elsif kto[2] < 7
        pz += kto[2] * 3 - 10
      else
        pz += kto[2] * 3 - 20
      end

      if kto[4] < 4
        pz += kto[4] * 3
      elsif kto[4] < 7
        pz += kto[4] * 3 - 10
      else
        pz += kto[4] * 3 - 20
      end

      if kto[6] < 4
        pz += kto[6] * 3
      elsif kto[6] < 7
        pz += kto[6] * 3 - 10
      else
        pz += kto[6] * 3 - 20
      end

      if kto[8] < 4
        pz += kto[8] * 3
      elsif kto[8] < 7
        pz += kto[8] * 3 - 10
      else
        pz += kto[8] * 3 - 20
      end

      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      m2122(kto, blz, um, rv)
    end

    # Methode C2, Variante 2 (Methode 00)
    def m2122(kto, blz, um, rv)
      if rv
        rv.methode = "C2b"
        rv.pz_methode = 2122
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]
      if kto[0] < 5 then pz += kto[0] * 2 else pz += kto[0] * 2 - 9 end
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
      m3122(kto, blz, um, rv)
    end

    # Methode C2, Variante 3 (gültig ab September 2017, Methode 04)
    def m3122(kto, blz, um, rv)
      if rv
        rv.methode = "C2c"
        rv.pz_methode = 3122
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
  end
end
