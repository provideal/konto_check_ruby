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

# Port of the C case labels 0..50 (including the sub-methods 13a/13b, 49a/49b
# and 50a/50b) of kto_check_int() from konto_check.c.

module KontoCheckRuby
  module CheckMethods
    extend self

    # Methode 00
    # Modulus 10, Gewichtung 2, 1, 2, 1, 2, 1, 2, 1, 2 (mit Quersumme).
    def m0(kto, blz, um, rv)
      if rv
        rv.methode = "00"
        rv.pz_methode = 0
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

    # Methode 01
    # Modulus 10, Gewichtung 3, 7, 1, 3, 7, 1, 3, 7, 1.
    def m1(kto, blz, um, rv)
      if rv
        rv.methode = "01"
        rv.pz_methode = 1
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

    # Methode 02
    # Modulus 11, Gewichtung 2, 3, 4, 5, 6, 7, 8, 9, 2.
    def m2(kto, blz, um, rv)
      if rv
        rv.methode = "02"
        rv.pz_methode = 2
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

    # Methode 03
    # Modulus 10, Gewichtung 2, 1, 2, 1, 2, 1, 2, 1, 2 (ohne Quersumme).
    def m3(kto, blz, um, rv)
      if rv
        rv.methode = "03"
        rv.pz_methode = 3
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

    # Methode 04
    # Modulus 11, Gewichtung 2, 3, 4, 5, 6, 7, 2, 3, 4.
    def m4(kto, blz, um, rv)
      if rv
        rv.methode = "04"
        rv.pz_methode = 4
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

    # Methode 05
    # Modulus 10, Gewichtung 7, 3, 1, 7, 3, 1, 7, 3, 1.
    def m5(kto, blz, um, rv)
      if rv
        rv.methode = "05"
        rv.pz_methode = 5
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
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 06
    # Modulus 11, Gewichtung 2, 3, 4, 5, 6, 7, 2, 3, 4; Rest 0 und 1 -> Pz 0.
    def m6(kto, blz, um, rv)
      if rv
        rv.methode = "06"
        rv.pz_methode = 6
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
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 07
    # Modulus 11, Gewichtung 2, 3, 4, 5, 6, 7, 8, 9, 10.
    def m7(kto, blz, um, rv)
      if rv
        rv.methode = "07"
        rv.pz_methode = 7
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

    # Methode 08
    # Wie Methode 00, jedoch nur fuer Kontonummern ab 60 000.
    def m8(kto, blz, um, rv)
      if rv
        rv.methode = "08"
        rv.pz_methode = 8
      end
      return OK_NO_CHK if kto.join < "0000060000"
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

    # Methode 09
    # Keine Pruefzifferberechnung.
    def m9(kto, blz, um, rv)
      if rv
        rv.methode = "09"
        rv.pz_methode = 9
      end
      OK_NO_CHK
    end

    # Methode 10
    # Modulus 11, Gewichtung 2 bis 10; Rest 0 und 1 -> Pz 0.
    def m10(kto, blz, um, rv)
      if rv
        rv.methode = "10"
        rv.pz_methode = 10
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
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 11
    # Wie Methode 10, jedoch Rest 1 -> Pruefziffer 9.
    def m11(kto, blz, um, rv)
      if rv
        rv.methode = "11"
        rv.pz_methode = 11
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
      if pz == 1
        pz = 9
      elsif pz > 1
        pz = 11 - pz
      end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 12
    # Nicht definiert.
    def m12(kto, blz, um, rv)
      if rv
        rv.methode = "12"
        rv.pz_methode = 12
      end
      NOT_DEFINED
    end

    # Methode 13
    def m13(kto, blz, um, rv)
      m1013(kto, blz, um, rv)
    end

    # Methode 13a
    # Modulus 10, Gewichtung 2, 1, 2, 1, 2 ueber die Stellen 2 bis 7,
    # Pruefziffer an Stelle 8.
    def m1013(kto, blz, um, rv)
      if rv
        rv.methode = "13a"
        rv.pz_methode = 1013
      end
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
      # falls die beiden ersten Stellen nicht 00 sind, kann keine
      # Unterkontonummer weggelassen sein
      return FALSE if kto[0] != 0 || kto[1] != 0
      m2013(kto, blz, um, rv)
    end

    # Methode 13b
    # Wie 13a, jedoch um zwei Stellen nach rechts verschoben.
    def m2013(kto, blz, um, rv)
      if rv
        rv.methode = "13b"
        rv.pz_methode = 2013
      end
      pz = kto[3] + kto[5] + kto[7]
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

    # Methode 14
    # Modulus 11, Gewichtung 2, 3, 4, 5, 6, 7 ueber die Stellen 4 bis 9.
    def m14(kto, blz, um, rv)
      if rv
        rv.methode = "14"
        rv.pz_methode = 14
      end
      pz = kto[3] * 7 +
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

    # Methode 15
    # Modulus 11, Gewichtung 2, 3, 4, 5 ueber die Stellen 6 bis 9.
    def m15(kto, blz, um, rv)
      if rv
        rv.methode = "15"
        rv.pz_methode = 15
      end
      pz = kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 16
    # Wie Methode 06; bei Rest 1 muessen die Stellen 9 und 10 uebereinstimmen.
    def m16(kto, blz, um, rv)
      if rv
        rv.methode = "16"
        rv.pz_methode = 16
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
      if pz == 10
        if rv
          rv.pz_pos = 10
          rv.pz = kto[8]
        end
        return kto[8] == kto[9] ? OK : FALSE
      end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 17
    # Modulus 11, Gewichtung 1, 2, 1, 2, 1, 2 ueber die Stellen 2 bis 7,
    # Summe minus 1, Pruefziffer an Stelle 8.
    def m17(kto, blz, um, rv)
      if rv
        rv.methode = "17"
        rv.pz_methode = 17
      end
      pz = kto[1] + kto[3] + kto[5]
      pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz -= 1
      # MOD_11_44: iterierte Subtraktion, ein negativer Wert bleibt unveraendert
      pz %= 11 if pz >= 0
      pz = 10 - pz if pz != 0
      # CHECK_PZ8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      kto[7] == pz ? OK : FALSE
    end

    # Methode 18
    # Modulus 10, Gewichtung 3, 9, 7, 1, 3, 9, 7, 1, 3.
    def m18(kto, blz, um, rv)
      if rv
        rv.methode = "18"
        rv.pz_methode = 18
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

    # Methode 19
    # Modulus 11, Gewichtung 2, 3, 4, 5, 6, 7, 8, 9, 1.
    def m19(kto, blz, um, rv)
      if rv
        rv.methode = "19"
        rv.pz_methode = 19
      end
      pz = kto[0] +
           kto[1] * 9 +
           kto[2] * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 20
    # Modulus 11, Gewichtung 2, 3, 4, 5, 6, 7, 8, 9, 3.
    def m20(kto, blz, um, rv)
      if rv
        rv.methode = "20"
        rv.pz_methode = 20
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
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 21
    # Modulus 10, Gewichtung 2, 1, 2, 1, 2 ...; iterierte Quersumme der Summe.
    def m21(kto, blz, um, rv)
      if rv
        rv.methode = "21"
        rv.pz_methode = 21
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

    # Methode 22
    # Modulus 10, Gewichtung 3, 1, 3, 1, 3 ...; von zweistelligen Produkten
    # wird nur die Einerstelle gewertet.
    def m22(kto, blz, um, rv)
      if rv
        rv.methode = "22"
        rv.pz_methode = 22
      end
      pz = kto[1] + kto[3] + kto[5] + kto[7]

      pz += if kto[0] < 4
              kto[0] * 3
            elsif kto[0] < 7
              kto[0] * 3 - 10
            else
              kto[0] * 3 - 20
            end

      pz += if kto[2] < 4
              kto[2] * 3
            elsif kto[2] < 7
              kto[2] * 3 - 10
            else
              kto[2] * 3 - 20
            end

      pz += if kto[4] < 4
              kto[4] * 3
            elsif kto[4] < 7
              kto[4] * 3 - 10
            else
              kto[4] * 3 - 20
            end

      pz += if kto[6] < 4
              kto[6] * 3
            elsif kto[6] < 7
              kto[6] * 3 - 10
            else
              kto[6] * 3 - 20
            end

      pz += if kto[8] < 4
              kto[8] * 3
            elsif kto[8] < 7
              kto[8] * 3 - 10
            else
              kto[8] * 3 - 20
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

    # Methode 23
    # Wie Methode 16, jedoch ueber die Stellen 1 bis 6, Pruefziffer Stelle 7.
    def m23(kto, blz, um, rv)
      if rv
        rv.methode = "23"
        rv.pz_methode = 23
      end
      pz = kto[0] * 7 +
           kto[1] * 6 +
           kto[2] * 5 +
           kto[3] * 4 +
           kto[4] * 3 +
           kto[5] * 2
      pz %= 11
      pz = 11 - pz if pz != 0
      if pz == 10
        if rv
          rv.pz_pos = 7
          rv.pz = kto[6]
        end
        return kto[5] == kto[6] ? OK : FALSE
      end
      # CHECK_PZ7
      if rv
        rv.pz_pos = 7
        rv.pz = pz
      end
      kto[6] == pz ? OK : FALSE
    end

    # Methode 24
    # Modulus 10, Gewichtung 1, 2, 3, 1, 2, 3 ...; Sonderbehandlung der
    # ersten Stellen, fuehrende Nullen werden uebergangen.
    def m24(kto, blz, um, rv)
      if rv
        rv.methode = "24"
        rv.pz_methode = 24
      end
      kto[0] = 0 if kto[0] >= 3 && kto[0] <= 6
      if kto[0] == 9
        kto[0] = 0
        kto[1] = 0
        kto[2] = 0
      end
      ptr = 0
      ptr += 1 while ptr < 10 && kto[ptr] == 0
      i = 0
      pz = 0
      while ptr < 9
        p1 = kto[ptr] * W24[i] + W24[i]
        p1 %= 11 if p1 >= 11 # SUB1_22
        pz += p1
        ptr += 1
        i += 1
      end
      pz %= 10
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 25
    # Modulus 11, Gewichtung 2 bis 9; Rest 1 nur fuer Konten mit 8 oder 9
    # an der zweiten Stelle zulaessig.
    def m25(kto, blz, um, rv)
      if rv
        rv.methode = "25"
        rv.pz_methode = 25
      end
      pz = kto[1] * 9 +
           kto[2] * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      pz = 11 - pz if pz != 0
      if pz == 10
        pz = 0
        return INVALID_KTO if kto[1] != 8 && kto[1] != 9
      end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 26
    # Modulus 11, Gewichtung 2 bis 7 (plus 2); bei ausgelassener
    # Unterkontonummer (Stellen 1 und 2 = 00) verschobene Berechnung.
    def m26(kto, blz, um, rv)
      if rv
        rv.methode = "26"
        rv.pz_methode = 26
      end
      if kto[0] == 0 && kto[1] == 0
        # Unterkontonummer ausgelassen
        pz = kto[2] * 2 +
             kto[3] * 7 +
             kto[4] * 6 +
             kto[5] * 5 +
             kto[6] * 4 +
             kto[7] * 3 +
             kto[8] * 2
        pz %= 11
        pz = if pz <= 1
               0
             else
               11 - pz
             end
        # CHECK_PZ10
        if rv
          rv.pz_pos = 10
          rv.pz = pz
        end
        kto[9] == pz ? OK : FALSE
      else
        pz = kto[0] * 2 +
             kto[1] * 7 +
             kto[2] * 6 +
             kto[3] * 5 +
             kto[4] * 4 +
             kto[5] * 3 +
             kto[6] * 2
        pz %= 11
        pz = if pz <= 1
               0
             else
               11 - pz
             end
        # CHECK_PZ8
        if rv
          rv.pz_pos = 8
          rv.pz = pz
        end
        kto[7] == pz ? OK : FALSE
      end
    end

    # Methode 27
    # Modulus 10, Gewichtung 2, 1, 2, 1, ... fuer Konten bis 999.999.999,
    # sonst Modulus 10 iteriert (Methode 10h).
    def m27(kto, blz, um, rv)
      if rv
        rv.methode = "27"
        rv.pz_methode = 27
      end
      if kto[0] == 0 # Kontonummern von 1 bis 999.999.999
        pz = kto[1] + kto[3] + kto[5] + kto[7]
        pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
        pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
        pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
        pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
        pz %= 10
      else
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
      end
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 28
    # Modulus 11, Gewichtung 2 bis 8, Pruefziffer an Stelle 8.
    def m28(kto, blz, um, rv)
      if rv
        rv.methode = "28"
        rv.pz_methode = 28
      end
      pz = kto[0] * 8 +
           kto[1] * 7 +
           kto[2] * 6 +
           kto[3] * 5 +
           kto[4] * 4 +
           kto[5] * 3 +
           kto[6] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      kto[7] == pz ? OK : FALSE
    end

    # Methode 29
    # Modulus 10 iteriert (Transformationstabelle, Methode 10h).
    def m29(kto, blz, um, rv)
      if rv
        rv.methode = "29"
        rv.pz_methode = 29
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

    # Methode 30
    # Modulus 10, Gewichtung 2, 0, 0, 0, 0, 1, 2, 1, 2.
    def m30(kto, blz, um, rv)
      if rv
        rv.methode = "30"
        rv.pz_methode = 30
      end
      pz = kto[0] * 2 +
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

    # Methode 31
    # Modulus 11, Gewichtung 9, 8, 7, 6, 5, 4, 3, 2, 1; Rest = Pruefziffer,
    # Rest 10 -> Konto ungueltig.
    def m31(kto, blz, um, rv)
      if rv
        rv.methode = "31"
        rv.pz_methode = 31
      end
      pz = kto[0] +
           kto[1] * 2 +
           kto[2] * 3 +
           kto[3] * 4 +
           kto[4] * 5 +
           kto[5] * 6 +
           kto[6] * 7 +
           kto[7] * 8 +
           kto[8] * 9
      pz %= 11
      return INVALID_KTO if pz == 10
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 32
    # Modulus 11, Gewichtung 2 bis 7 ueber die Stellen 4 bis 9.
    def m32(kto, blz, um, rv)
      if rv
        rv.methode = "32"
        rv.pz_methode = 32
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 33
    # Modulus 11, Gewichtung 2 bis 6 ueber die Stellen 5 bis 9.
    def m33(kto, blz, um, rv)
      if rv
        rv.methode = "33"
        rv.pz_methode = 33
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 34
    # Modulus 11, Gewichtung 2, 4, 8, 5, 10, 9, 7, Pruefziffer Stelle 8.
    def m34(kto, blz, um, rv)
      if rv
        rv.methode = "34"
        rv.pz_methode = 34
      end
      pz = kto[0] * 7 +
           kto[1] * 9 +
           kto[2] * 10 +
           kto[3] * 5 +
           kto[4] * 8 +
           kto[5] * 4 +
           kto[6] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      kto[7] == pz ? OK : FALSE
    end

    # Methode 35
    # Modulus 11, Gewichtung 2 bis 10; Rest = Pruefziffer, Rest 10 nur gueltig
    # wenn die Stellen 9 und 10 uebereinstimmen.
    def m35(kto, blz, um, rv)
      if rv
        rv.methode = "35"
        rv.pz_methode = 35
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
      if pz == 10
        if kto[8] == kto[9]
          return OK
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

    # Methode 36
    # Modulus 11, Gewichtung 2, 4, 8, 5 ueber die Stellen 6 bis 9.
    def m36(kto, blz, um, rv)
      if rv
        rv.methode = "36"
        rv.pz_methode = 36
      end
      pz = kto[5] * 5 +
           kto[6] * 8 +
           kto[7] * 4 +
           kto[8] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 37
    # Modulus 11, Gewichtung 2, 4, 8, 5, 10 ueber die Stellen 5 bis 9.
    def m37(kto, blz, um, rv)
      if rv
        rv.methode = "37"
        rv.pz_methode = 37
      end
      pz = kto[4] * 10 +
           kto[5] * 5 +
           kto[6] * 8 +
           kto[7] * 4 +
           kto[8] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 38
    # Modulus 11, Gewichtung 2, 4, 8, 5, 10, 9 ueber die Stellen 4 bis 9.
    def m38(kto, blz, um, rv)
      if rv
        rv.methode = "38"
        rv.pz_methode = 38
      end
      pz = kto[3] * 9 +
           kto[4] * 10 +
           kto[5] * 5 +
           kto[6] * 8 +
           kto[7] * 4 +
           kto[8] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 39
    # Modulus 11, Gewichtung 2, 4, 8, 5, 10, 9, 7 ueber die Stellen 3 bis 9.
    def m39(kto, blz, um, rv)
      if rv
        rv.methode = "39"
        rv.pz_methode = 39
      end
      pz = kto[2] * 7 +
           kto[3] * 9 +
           kto[4] * 10 +
           kto[5] * 5 +
           kto[6] * 8 +
           kto[7] * 4 +
           kto[8] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 40
    # Modulus 11, Gewichtung 2, 4, 8, 5, 10, 9, 7, 3, 6.
    def m40(kto, blz, um, rv)
      if rv
        rv.methode = "40"
        rv.pz_methode = 40
      end
      pz = kto[0] * 6 +
           kto[1] * 3 +
           kto[2] * 7 +
           kto[3] * 9 +
           kto[4] * 10 +
           kto[5] * 5 +
           kto[6] * 8 +
           kto[7] * 4 +
           kto[8] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 41
    # Wie Methode 00; bei einer 9 an der 4. Stelle werden nur die Stellen
    # 4 bis 9 einbezogen.
    def m41(kto, blz, um, rv)
      if rv
        rv.methode = "41"
        rv.pz_methode = 41
      end
      if kto[3] == 9
        pz = kto[3] + kto[5] + kto[7]
        pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
        pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
        pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
        pz %= 10
      else
        pz = kto[1] + kto[3] + kto[5] + kto[7]
        pz += kto[0] < 5 ? kto[0] * 2 : kto[0] * 2 - 9
        pz += kto[2] < 5 ? kto[2] * 2 : kto[2] * 2 - 9
        pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
        pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
        pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9
        pz %= 10
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

    # Methode 42
    # Modulus 11, Gewichtung 2 bis 9 ueber die Stellen 2 bis 9.
    def m42(kto, blz, um, rv)
      if rv
        rv.methode = "42"
        rv.pz_methode = 42
      end
      pz = kto[1] * 9 +
           kto[2] * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 43
    # Modulus 10, Gewichtung 1, 2, 3, 4, 5, 6, 7, 8, 9.
    def m43(kto, blz, um, rv)
      if rv
        rv.methode = "43"
        rv.pz_methode = 43
      end
      pz = kto[0] * 9 +
           kto[1] * 8 +
           kto[2] * 7 +
           kto[3] * 6 +
           kto[4] * 5 +
           kto[5] * 4 +
           kto[6] * 3 +
           kto[7] * 2 +
           kto[8]
      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 44
    # Modulus 11, Gewichtung 2, 4, 8, 5, 10 ueber die Stellen 5 bis 9;
    # Sonderfall der IBAN-Regel 49 (9 an Stelle 1 oder 5).
    def m44(kto, blz, um, rv)
      if rv
        rv.methode = "44"
        rv.pz_methode = 44
      end
      pz = kto[4] * 10 +
           kto[5] * 5 +
           kto[6] * 8 +
           kto[7] * 4 +
           kto[8] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0
      if kto[0] == 9 || kto[4] == 9
        OK_NO_CHK
      else
        FALSE
      end
    end

    # Methode 45
    # Wie Methode 00; keine Pruefung bei einer 0 an Stelle 1 oder einer 1
    # an Stelle 5.
    def m45(kto, blz, um, rv)
      if rv
        rv.methode = "45"
        rv.pz_methode = 45
      end
      return OK_NO_CHK if kto[0] == 0 || kto[4] == 1
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

    # Methode 46
    # Modulus 11, Gewichtung 2 bis 6 ueber die Stellen 3 bis 7.
    def m46(kto, blz, um, rv)
      if rv
        rv.methode = "46"
        rv.pz_methode = 46
      end
      pz = kto[2] * 6 +
           kto[3] * 5 +
           kto[4] * 4 +
           kto[5] * 3 +
           kto[6] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ8
      if rv
        rv.pz_pos = 8
        rv.pz = pz
      end
      kto[7] == pz ? OK : FALSE
    end

    # Methode 47
    # Modulus 11, Gewichtung 2 bis 6 ueber die Stellen 4 bis 8.
    def m47(kto, blz, um, rv)
      if rv
        rv.methode = "47"
        rv.pz_methode = 47
      end
      pz = kto[3] * 6 +
           kto[4] * 5 +
           kto[5] * 4 +
           kto[6] * 3 +
           kto[7] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ9
      if rv
        rv.pz_pos = 9
        rv.pz = pz
      end
      kto[8] == pz ? OK : FALSE
    end

    # Methode 48
    # Modulus 11, Gewichtung 2 bis 7 ueber die Stellen 3 bis 8.
    def m48(kto, blz, um, rv)
      if rv
        rv.methode = "48"
        rv.pz_methode = 48
      end
      pz = kto[2] * 7 +
           kto[3] * 6 +
           kto[4] * 5 +
           kto[5] * 4 +
           kto[6] * 3 +
           kto[7] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZ9
      if rv
        rv.pz_pos = 9
        rv.pz = pz
      end
      kto[8] == pz ? OK : FALSE
    end

    # Methode 49
    def m49(kto, blz, um, rv)
      m1049(kto, blz, um, rv)
    end

    # Methode 49a
    # Berechnung nach Methode 00.
    def m1049(kto, blz, um, rv)
      if rv
        rv.methode = "49a"
        rv.pz_methode = 1049
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
      m2049(kto, blz, um, rv)
    end

    # Methode 49b
    # Berechnung nach Methode 01.
    def m2049(kto, blz, um, rv)
      if rv
        rv.methode = "49b"
        rv.pz_methode = 2049
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

    # Methode 50
    def m50(kto, blz, um, rv)
      m1050(kto, blz, um, rv)
    end

    # Methode 50a
    # Modulus 11, Gewichtung 2 bis 7 ueber die Stellen 1 bis 6,
    # Pruefziffer an Stelle 7.
    def m1050(kto, blz, um, rv)
      if rv
        rv.methode = "50a"
        rv.pz_methode = 1050
      end
      pz = kto[0] * 7 +
           kto[1] * 6 +
           kto[2] * 5 +
           kto[3] * 4 +
           kto[4] * 3 +
           kto[5] * 2
      pz %= 11
      pz = if pz <= 1
             0
           else
             11 - pz
           end
      # CHECK_PZX7
      if rv
        rv.pz_pos = 7
        rv.pz = pz
      end
      return OK if kto[6] == pz
      return FALSE if um != 0
      m2050(kto, blz, um, rv)
    end

    # Methode 50b
    # Wie 50a, jedoch mit weggelassener Unterkontonummer (eine, zwei oder
    # drei Stellen).
    def m2050(kto, blz, um, rv)
      if rv
        rv.methode = "50b"
        rv.pz_methode = 2050
      end
      if kto[0] == 0 && kto[1] == 0 && kto[2] == 0
        pz = kto[3] * 7 +
             kto[4] * 6 +
             kto[5] * 5 +
             kto[6] * 4 +
             kto[7] * 3 +
             kto[8] * 2
        pz %= 11
        pz = if pz <= 1
               0
             else
               11 - pz
             end
        # CHECK_PZ10
        if rv
          rv.pz_pos = 10
          rv.pz = pz
        end
        kto[9] == pz ? OK : FALSE
      elsif kto[0] == 0 && kto[1] == 0 && kto[9] == 0
        pz = kto[2] * 7 +
             kto[3] * 6 +
             kto[4] * 5 +
             kto[5] * 4 +
             kto[6] * 3 +
             kto[7] * 2
        pz %= 11
        pz = if pz <= 1
               0
             else
               11 - pz
             end
        # CHECK_PZ9
        if rv
          rv.pz_pos = 9
          rv.pz = pz
        end
        kto[8] == pz ? OK : FALSE
      elsif kto[0] == 0 && kto[8] == 0 && kto[9] == 0
        pz = kto[1] * 7 +
             kto[2] * 6 +
             kto[3] * 5 +
             kto[4] * 4 +
             kto[5] * 3 +
             kto[6] * 2
        pz %= 11
        pz = if pz <= 1
               0
             else
               11 - pz
             end
        # CHECK_PZ8
        if rv
          rv.pz_pos = 8
          rv.pz = pz
        end
        kto[7] == pz ? OK : FALSE
      else
        # bei DEBUG wurde evl. direkt die Methode angesprungen; daher mit 50a testen
        if rv
          rv.methode = "50a"
          rv.pz_methode = 1050
        end
        pz = kto[0] * 7 +
             kto[1] * 6 +
             kto[2] * 5 +
             kto[3] * 4 +
             kto[4] * 3 +
             kto[5] * 2
        pz %= 11
        pz = if pz <= 1
               0
             else
               11 - pz
             end
        # CHECK_PZ7
        if rv
          rv.pz_pos = 7
          rv.pz = pz
        end
        kto[6] == pz ? OK : FALSE
      end
    end
  end
end
