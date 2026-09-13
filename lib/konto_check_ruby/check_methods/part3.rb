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

    # Methode 78
    # Modulus 10, Gewichtung 2, 1, 2, 1, 2, 1, 2, 1, 2 (wie Methode 00).
    # Ausnahme: 10-stellige Kontonummern, die mit 00 beginnen und deren
    # 3. Stelle ungleich 0 ist, sind ohne Pruefziffer gueltig.
    def m78(kto, blz, um, rv)
      if rv
        rv.methode = "78"
        rv.pz_methode = 78
      end
      return OK_NO_CHK if kto[0] == 0 && kto[1] == 0 && kto[2] != 0

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

    # Methode 79
    # Modulus 10, Gewichtung 2, 1, 2, 1, 2, 1, 2, 1.
    # Bei Kontonummern mit 1, 2 oder 9 an der 1. Stelle liegt die Pruefziffer
    # an Stelle 9, sonst an Stelle 10. Die 1. Stelle darf nicht 0 sein.
    def m79(kto, blz, um, rv)
      if rv
        rv.methode = "79"
        rv.pz_methode = 79
      end
      return INVALID_KTO if kto[0] == 0

      if kto[0] == 1 || kto[0] == 2 || kto[0] == 9
        pz = kto[0] + kto[2] + kto[4] + kto[6]
        pz += kto[1] < 5 ? kto[1] * 2 : kto[1] * 2 - 9
        pz += kto[3] < 5 ? kto[3] * 2 : kto[3] * 2 - 9
        pz += kto[5] < 5 ? kto[5] * 2 : kto[5] * 2 - 9
        pz += kto[7] < 5 ? kto[7] * 2 : kto[7] * 2 - 9

        pz %= 10
        pz = 10 - pz if pz != 0
        # CHECK_PZ9
        if rv
          rv.pz_pos = 9
          rv.pz = pz
        end
        kto[8] == pz ? OK : FALSE
      else
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

    # Methode 80
    # Modulus 10, Gewichtung 2, 1, 2, 1, 2 (Variante 1) bzw. Modulus 7
    # (Variante 2); Ausnahme: 3. Stelle = 9 -> Berechnung wie Verfahren 51.
    def m80(kto, blz, um, rv)
      if kto[2] == 9 # Berechnung wie in Verfahren 51
        m3080(kto, blz, um, rv)
      else
        m1080(kto, blz, um, rv)
      end
    end

    # Methode 80c (Ausnahme, Variante 1)
    def m3080(kto, blz, um, rv)
      if rv
        rv.methode = "80c"
        rv.pz_methode = 3080
      end
      pz = 9 * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m4080(kto, blz, um, rv)
    end

    # Methode 80d (Ausnahme, Variante 2)
    def m4080(kto, blz, um, rv)
      if rv
        rv.methode = "80d"
        rv.pz_methode = 4080
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
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 80a (Variante 1)
    def m1080(kto, blz, um, rv)
      if rv
        rv.methode = "80a"
        rv.pz_methode = 1080
      end
      pz = kto[5] + kto[7]
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

      m2080(kto, blz, um, rv)
    end

    # Methode 80b (Variante 2)
    def m2080(kto, blz, um, rv)
      if rv
        rv.methode = "80b"
        rv.pz_methode = 2080
      end
      pz = kto[5] + kto[7]
      pz += kto[4] < 5 ? kto[4] * 2 : kto[4] * 2 - 9
      pz += kto[6] < 5 ? kto[6] * 2 : kto[6] * 2 - 9
      pz += kto[8] < 5 ? kto[8] * 2 : kto[8] * 2 - 9

      pz %= 7
      pz = 7 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 81
    # Modulus 11, Gewichtung 2, 3, 4, 5, 6, 7; Ausnahme: 3. Stelle = 9 ->
    # Berechnung wie Verfahren 51.
    def m81(kto, blz, um, rv)
      if kto[2] == 9 # Berechnung wie in Verfahren 51
        m2081(kto, blz, um, rv)
      else
        m1081(kto, blz, um, rv)
      end
    end

    # Methode 81b (Ausnahme, Variante 1)
    def m2081(kto, blz, um, rv)
      if rv
        rv.methode = "81b"
        rv.pz_methode = 2081
      end
      pz = 9 * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m3081(kto, blz, um, rv)
    end

    # Methode 81c (Ausnahme, Variante 2)
    def m3081(kto, blz, um, rv)
      if rv
        rv.methode = "81c"
        rv.pz_methode = 3081
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
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 81a (Normalfall)
    def m1081(kto, blz, um, rv)
      if rv
        rv.methode = "81a"
        rv.pz_methode = 1081
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 82
    # Kontonummern mit 99 an der 3./4. Stelle: Verfahren 10, sonst
    # Verfahren 33.
    def m82(kto, blz, um, rv)
      m1082(kto, blz, um, rv)
    end

    # Methode 82a (Verfahren 10)
    def m1082(kto, blz, um, rv)
      if rv
        rv.methode = "82a"
        rv.pz_methode = 1082
      end
      if kto[2] == 9 && kto[3] == 9
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
        pz = pz <= 1 ? 0 : 11 - pz
        # CHECK_PZ10
        if rv
          rv.pz_pos = 10
          rv.pz = pz
        end
        return kto[9] == pz ? OK : FALSE
      end

      m2082(kto, blz, um, rv)
    end

    # Methode 82b (Verfahren 33)
    def m2082(kto, blz, um, rv)
      if rv
        rv.methode = "82b"
        rv.pz_methode = 2082
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 83
    # Varianten A (Modulus 11, Gewichtung 2..7), B (Modulus 11, 2..6) und
    # C (Modulus 7, 2..6); Sachkonten (99 an 3./4. Stelle) mit Variante D.
    def m83(kto, blz, um, rv)
      m4083(kto, blz, um, rv)
    end

    # Methode 83d (Sachkonten)
    def m4083(kto, blz, um, rv)
      if rv
        rv.methode = "83d"
        rv.pz_methode = 4083
      end
      if kto[2] == 9 && kto[3] == 9
        pz = 9 * 8 +
             9 * 7 +
             kto[4] * 6 +
             kto[5] * 5 +
             kto[6] * 4 +
             kto[7] * 3 +
             kto[8] * 2

        pz %= 11
        pz = pz <= 1 ? 0 : 11 - pz
        # CHECK_PZ10
        if rv
          rv.pz_pos = 10
          rv.pz = pz
        end
        return kto[9] == pz ? OK : FALSE
      end

      m1083(kto, blz, um, rv)
    end

    # Methode 83a
    def m1083(kto, blz, um, rv)
      if rv
        rv.methode = "83a"
        rv.pz_methode = 1083
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m2083(kto, blz, um, rv)
    end

    # Methode 83b
    def m2083(kto, blz, um, rv)
      if rv
        rv.methode = "83b"
        rv.pz_methode = 2083
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m3083(kto, blz, um, rv)
    end

    # Methode 83c
    def m3083(kto, blz, um, rv)
      if rv
        rv.methode = "83c"
        rv.pz_methode = 3083
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

    # Methode 84
    # Varianten A (Modulus 11, 2..6), B (Modulus 7, 2..6) und C (Modulus 10,
    # Gewichtung 2, 1, 2, 1, 2); Ausnahme: 3. Stelle = 9 (Verfahren 51).
    def m84(kto, blz, um, rv)
      if kto[2] == 9 # Berechnung wie in Verfahren 51
        m4084(kto, blz, um, rv)
      else
        m1084(kto, blz, um, rv)
      end
    end

    # Methode 84d (Ausnahme, Variante 1)
    def m4084(kto, blz, um, rv)
      if rv
        rv.methode = "84d"
        rv.pz_methode = 4084
      end
      pz = 9 * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m5084(kto, blz, um, rv)
    end

    # Methode 84e (Ausnahme, Variante 2)
    def m5084(kto, blz, um, rv)
      if rv
        rv.methode = "84e"
        rv.pz_methode = 5084
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
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 84a
    def m1084(kto, blz, um, rv)
      if rv
        rv.methode = "84a"
        rv.pz_methode = 1084
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m2084(kto, blz, um, rv)
    end

    # Methode 84b
    def m2084(kto, blz, um, rv)
      if rv
        rv.methode = "84b"
        rv.pz_methode = 2084
      end
      pz = kto[4] * 6 +
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

      m3084(kto, blz, um, rv)
    end

    # Methode 84c
    def m3084(kto, blz, um, rv)
      if rv
        rv.methode = "84c"
        rv.pz_methode = 3084
      end
      pz = kto[4] * 2 +
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

    # Methode 85
    # Varianten A (Modulus 11, 2..7), B (Modulus 11, 2..6) und C (Modulus 7,
    # 2..6); Sachkonten (99 an 3./4. Stelle) mit Variante D.
    def m85(kto, blz, um, rv)
      m4085(kto, blz, um, rv)
    end

    # Methode 85d (Sachkonten)
    def m4085(kto, blz, um, rv)
      if rv
        rv.methode = "85d"
        rv.pz_methode = 4085
      end
      if kto[2] == 9 && kto[3] == 9
        pz = 9 * 8 +
             9 * 7 +
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
        return kto[9] == pz ? OK : FALSE
      end

      m1085(kto, blz, um, rv)
    end

    # Methode 85a
    def m1085(kto, blz, um, rv)
      if rv
        rv.methode = "85a"
        rv.pz_methode = 1085
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m2085(kto, blz, um, rv)
    end

    # Methode 85b
    def m2085(kto, blz, um, rv)
      if rv
        rv.methode = "85b"
        rv.pz_methode = 2085
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m3085(kto, blz, um, rv)
    end

    # Methode 85c
    def m3085(kto, blz, um, rv)
      if rv
        rv.methode = "85c"
        rv.pz_methode = 3085
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

    # Methode 86
    # Varianten A (Modulus 10, Gewichtung 2, 1, 2, 1, 2, 1) und B (Modulus 11,
    # Gewichtung 2..7); Ausnahme: 3. Stelle = 9 (Verfahren 51).
    def m86(kto, blz, um, rv)
      if kto[2] == 9 # Berechnung wie in Verfahren 51
        m3086(kto, blz, um, rv)
      else
        m1086(kto, blz, um, rv)
      end
    end

    # Methode 86c (Ausnahme, Variante 1)
    def m3086(kto, blz, um, rv)
      if rv
        rv.methode = "86c"
        rv.pz_methode = 3086
      end
      pz = 9 * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m4086(kto, blz, um, rv)
    end

    # Methode 86d (Ausnahme, Variante 2)
    def m4086(kto, blz, um, rv)
      if rv
        rv.methode = "86d"
        rv.pz_methode = 4086
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
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 86a
    def m1086(kto, blz, um, rv)
      if rv
        rv.methode = "86a"
        rv.pz_methode = 1086
      end
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

      m2086(kto, blz, um, rv)
    end

    # Methode 86b
    def m2086(kto, blz, um, rv)
      if rv
        rv.methode = "86b"
        rv.pz_methode = 2086
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 87
    # Variante A: eigenes Verfahren mit den Tabellen tab1/tab2, Variante B:
    # Verfahren 33, Variante C: Verfahren 84 Variante 2, Variante D:
    # Modulus 11 mit Gewichtung 2..7; Ausnahme: 3. Stelle = 9 (Verfahren 51).
    def m87(kto, blz, um, rv)
      if kto[2] == 9 # Berechnung wie in Verfahren 51
        m5087(kto, blz, um, rv)
      else
        m1087(kto, blz, um, rv)
      end
    end

    # Methode 87e (Ausnahme, Variante 1)
    def m5087(kto, blz, um, rv)
      if rv
        rv.methode = "87e"
        rv.pz_methode = 5087
      end
      pz = 9 * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m6087(kto, blz, um, rv)
    end

    # Methode 87f (Ausnahme, Variante 2)
    def m6087(kto, blz, um, rv)
      if rv
        rv.methode = "87f"
        rv.pz_methode = 6087
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
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 87a
    # Der Startindex fuer das Array konto[] ist 1, nicht 0; daher hat es 11
    # Elemente. Die Tabellen tab1/tab2 haben dagegen den Startindex 0.
    def m1087(kto, blz, um, rv)
      if rv
        rv.methode = "87a"
        rv.pz_methode = 1087
      end

      konto = Array.new(12)
      i = 1
      while i < 11
        konto[i] = kto[i - 1]
        i += 1
      end
      i = 4
      i += 1 while konto[i] == 0
      c2 = i % 2
      d2 = 0
      a5 = 0

      while i < 10
        case konto[i]
        when 0 then konto[i] = 5
        when 1 then konto[i] = 6
        when 5 then konto[i] = 10
        when 6 then konto[i] = 1
        end

        if c2 == d2
          if konto[i] > 5
            if c2 == 0 && d2 == 0
              c2 = d2 = 1
              a5 = a5 + 6 - (konto[i] - 6)
            else
              c2 = d2 = 0
              a5 = a5 + konto[i]
            end
          else
            if c2 == 0 && d2 == 0
              c2 = 1
              a5 = a5 + konto[i]
            else
              c2 = 0
              a5 = a5 + konto[i]
            end
          end
        else
          if konto[i] > 5
            if c2 == 0
              c2 = 1
              d2 = 0
              a5 = a5 - 6 + (konto[i] - 6)
            else
              c2 = 0
              d2 = 1
              a5 = a5 - konto[i]
            end
          else
            if c2 == 0
              c2 = 1
              a5 = a5 - konto[i]
            else
              c2 = 0
              a5 = a5 - konto[i]
            end
          end
        end
        i += 1
      end

      while a5 < 0 || a5 > 4
        if a5 > 4
          a5 -= 5
        else
          a5 += 5
        end
      end
      p = d2 == 0 ? TAB1[a5] : TAB2[a5]
      if p == konto[10]
        return OK # Pruefziffer ok
      else
        if konto[4] == 0
          p = p > 4 ? p - 5 : p + 5
          return OK if p == konto[10] # Pruefziffer ok
        end
      end

      m2087(kto, blz, um, rv)
    end

    # Methode 87b (Verfahren 33)
    def m2087(kto, blz, um, rv)
      if rv
        rv.methode = "87b"
        rv.pz_methode = 2087
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m3087(kto, blz, um, rv)
    end

    # Methode 87c (Verfahren 84 Variante 2)
    def m3087(kto, blz, um, rv)
      if rv
        rv.methode = "87c"
        rv.pz_methode = 3087
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 7
      pz = 7 - pz if pz != 0
      # kein CHECK_PZX10: es wird auch bei gesetzter Untermethode weiter
      # zur Methode 87d gegangen
      if rv
        rv.pz = pz
        rv.pz_pos = 10
      end
      return OK if pz == kto[9]

      m4087(kto, blz, um, rv)
    end

    # Methode 87d
    def m4087(kto, blz, um, rv)
      if rv
        rv.methode = "87d"
        rv.pz_methode = 4087
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 88
    # Modulus 11, Gewichtung 2, 3, 4, 5, 6, 7; Ausnahme: 3. Stelle = 9, dann
    # wird die 3. Stelle mit dem Gewicht 8 mitgerechnet.
    def m88(kto, blz, um, rv)
      if rv
        rv.methode = "88"
        rv.pz_methode = 88
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2
      pz += 9 * 8 if kto[2] == 9 # Ausnahme

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 89
    # 8- und 9-stellige Kontonummern: Verfahren 10; 7-stellige Kontonummern:
    # Modulus 11 mit Quersummenbildung; sonst keine Pruefzifferberechnung.
    def m89(kto, blz, um, rv)
      m1089(kto, blz, um, rv)
    end

    # Methode 89a (8- und 9-stellige Kontonummern)
    def m1089(kto, blz, um, rv)
      if rv
        rv.methode = "89a"
        rv.pz_methode = 1089
      end
      if kto[0] == 0 && (kto[1] != 0 || kto[2] != 0)
        pz = kto[1] * 9 +
             kto[2] * 8 +
             kto[3] * 7 +
             kto[4] * 6 +
             kto[5] * 5 +
             kto[6] * 4 +
             kto[7] * 3 +
             kto[8] * 2

        pz %= 11
        pz = pz <= 1 ? 0 : 11 - pz
        # CHECK_PZ10
        if rv
          rv.pz_pos = 10
          rv.pz = pz
        end
        return kto[9] == pz ? OK : FALSE
      end

      m2089(kto, blz, um, rv)
    end

    # Methode 89b (7-stellige Kontonummern)
    def m2089(kto, blz, um, rv)
      if rv
        rv.methode = "89b"
        rv.pz_methode = 2089
      end
      if kto[0] == 0 && kto[1] == 0 && kto[2] == 0 && kto[3] != 0
        pz = kto[3] * 7
        if pz >= 40
          if pz >= 50
            if pz >= 60
              pz -= 54
            else
              pz -= 45
            end
          else
            pz -= 36
          end
        elsif pz >= 20
          if pz >= 30
            pz -= 27
          else
            pz -= 18
          end
        elsif pz >= 10
          pz -= 9
        end

        p1 = kto[4] * 6
        if p1 >= 40
          if p1 >= 50
            p1 -= 45
          else
            p1 -= 36
          end
        elsif p1 >= 20
          if p1 >= 30
            p1 -= 27
          else
            p1 -= 18
          end
        elsif p1 >= 10
          p1 -= 9
        end
        pz += p1

        p1 = kto[5] * 5
        if p1 >= 40
          p1 -= 36
        elsif p1 >= 20
          if p1 >= 30
            p1 -= 27
          else
            p1 -= 18
          end
        elsif p1 >= 10
          p1 -= 9
        end
        pz += p1

        p1 = kto[6] * 4
        if p1 >= 20
          if p1 >= 30
            p1 -= 27
          else
            p1 -= 18
          end
        elsif p1 >= 10
          p1 -= 9
        end
        pz += p1

        p1 = kto[7] * 3
        if p1 >= 20
          p1 -= 18
        elsif p1 >= 10
          p1 -= 9
        end
        pz += p1

        p1 = kto[8] * 2
        p1 -= 9 if p1 >= 10
        pz += p1

        pz %= 11
        pz = pz <= 1 ? 0 : 11 - pz
        # CHECK_PZ10
        if rv
          rv.pz_pos = 10
          rv.pz = pz
        end
        return kto[9] == pz ? OK : FALSE
      end

      m3089(kto, blz, um, rv)
    end

    # Methode 89c (1- bis 6- und 10-stellige Kontonummern)
    def m3089(kto, blz, um, rv)
      if rv
        rv.methode = "89c"
        rv.pz_methode = 3089
      end
      OK_NO_CHK
    end

    # Methode 90
    # Varianten A bis E und G; Sachkonten (3. Stelle = 9) mit Variante F.
    def m90(kto, blz, um, rv)
      if kto[2] == 9 # Sachkonto
        m6090(kto, blz, um, rv)
      else
        m1090(kto, blz, um, rv)
      end
    end

    # Methode 90f (Sachkonto)
    def m6090(kto, blz, um, rv)
      if rv
        rv.methode = "90f"
        rv.pz_methode = 6090
      end
      pz = 9 * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 90a
    def m1090(kto, blz, um, rv)
      if rv
        rv.methode = "90a"
        rv.pz_methode = 1090
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m2090(kto, blz, um, rv)
    end

    # Methode 90b
    def m2090(kto, blz, um, rv)
      if rv
        rv.methode = "90b"
        rv.pz_methode = 2090
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m3090(kto, blz, um, rv)
    end

    # Methode 90c
    def m3090(kto, blz, um, rv)
      if rv
        rv.methode = "90c"
        rv.pz_methode = 3090
      end
      pz = kto[4] * 6 +
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

      m4090(kto, blz, um, rv)
    end

    # Methode 90d
    def m4090(kto, blz, um, rv)
      if rv
        rv.methode = "90d"
        rv.pz_methode = 4090
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 9
      pz = 9 - pz if pz != 0
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m5090(kto, blz, um, rv)
    end

    # Methode 90e
    def m5090(kto, blz, um, rv)
      if rv
        rv.methode = "90e"
        rv.pz_methode = 5090
      end
      pz = kto[4] * 2 +
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

      m7090(kto, blz, um, rv)
    end

    # Methode 90g
    def m7090(kto, blz, um, rv)
      if rv
        rv.methode = "90g"
        rv.pz_methode = 7090
      end
      pz = kto[3] +
           kto[4] * 2 +
           kto[5] +
           kto[6] * 2 +
           kto[7] +
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

    # Methode 91
    # Pruefziffer an Stelle 7; Varianten A bis D mit unterschiedlichen
    # Gewichtungen, alle Modulus 11.
    def m91(kto, blz, um, rv)
      m1091(kto, blz, um, rv)
    end

    # Methode 91a
    def m1091(kto, blz, um, rv)
      if rv
        rv.methode = "91a"
        rv.pz_methode = 1091
      end
      pz = kto[0] * 7 +
           kto[1] * 6 +
           kto[2] * 5 +
           kto[3] * 4 +
           kto[4] * 3 +
           kto[5] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX7
      if rv
        rv.pz_pos = 7
        rv.pz = pz
      end
      return OK if kto[6] == pz
      return FALSE if um != 0

      m2091(kto, blz, um, rv)
    end

    # Methode 91b
    def m2091(kto, blz, um, rv)
      if rv
        rv.methode = "91b"
        rv.pz_methode = 2091
      end
      pz = kto[0] * 2 +
           kto[1] * 3 +
           kto[2] * 4 +
           kto[3] * 5 +
           kto[4] * 6 +
           kto[5] * 7

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX7
      if rv
        rv.pz_pos = 7
        rv.pz = pz
      end
      return OK if kto[6] == pz
      return FALSE if um != 0

      m3091(kto, blz, um, rv)
    end

    # Methode 91c
    def m3091(kto, blz, um, rv)
      if rv
        rv.methode = "91c"
        rv.pz_methode = 3091
      end
      pz = kto[0] * 10 +
           kto[1] * 9 +
           kto[2] * 8 +
           kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[7] * 4 +
           kto[8] * 3 +
           kto[9] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX7
      if rv
        rv.pz_pos = 7
        rv.pz = pz
      end
      return OK if kto[6] == pz
      return FALSE if um != 0

      m4091(kto, blz, um, rv)
    end

    # Methode 91d
    def m4091(kto, blz, um, rv)
      if rv
        rv.methode = "91d"
        rv.pz_methode = 4091
      end
      pz = kto[0] * 9 +
           kto[1] * 10 +
           kto[2] * 5 +
           kto[3] * 8 +
           kto[4] * 4 +
           kto[5] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ7
      if rv
        rv.pz_pos = 7
        rv.pz = pz
      end
      kto[6] == pz ? OK : FALSE
    end

    # Methode 92
    # Modulus 10, Gewichtung 3, 7, 1, 3, 7, 1.
    def m92(kto, blz, um, rv)
      if rv
        rv.methode = "92"
        rv.pz_methode = 92
      end
      pz = kto[3] +
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

    # Methode 93
    # Modulus 11, Gewichtung 2, 3, 4, 5, 6 (Variante 1) bzw. Modulus 7
    # (Variante 2); Fall a): Kontonummer 1..5 mit Pruefziffer an Stelle 6,
    # Fall b): Kontonummer 5..9 mit Pruefziffer an Stelle 10.
    def m93(kto, blz, um, rv)
      if kto[0] == 0 && kto[1] == 0 && kto[2] == 0 && kto[3] == 0 # Fall b)
        m2093(kto, blz, um, rv)
      else
        m1093(kto, blz, um, rv)
      end
    end

    # Methode 93b (Variante 1, Fall b)
    def m2093(kto, blz, um, rv)
      if rv
        rv.methode = "93b"
        rv.pz_methode = 2093
      end
      pz = kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      p1 = pz
      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      # Variante 2 (untermethode == 0, pz wurde bereits berechnet)
      pz = p1 % 7
      pz = 7 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 93a (Variante 1, Fall a)
    def m1093(kto, blz, um, rv)
      if rv
        rv.methode = "93a"
        rv.pz_methode = 1093
      end
      pz = kto[0] * 6 +
           kto[1] * 5 +
           kto[2] * 4 +
           kto[3] * 3 +
           kto[4] * 2

      kto[9] = kto[5] # Pruefziffer nach Stelle 10
      p1 = pz
      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      # Variante 2 (untermethode == 0, pz wurde bereits berechnet)
      pz = p1 % 7
      pz = 7 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 93d (Variante 2, Fall b)
    def m4093(kto, blz, um, rv)
      if rv
        rv.methode = "93d"
        rv.pz_methode = 4093
      end
      p1 = 0
      i = 0
      while i < 5
        p1 += kto[8 - i] * W93[i]
        i += 1
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

    # Methode 93c (Variante 2, Fall a)
    def m3093(kto, blz, um, rv)
      if rv
        rv.methode = "93c"
        rv.pz_methode = 3093
      end
      p1 = 0
      i = 0
      while i < 5
        p1 += kto[4 - i] * W93[i]
        i += 1
      end
      kto[9] = kto[5] # Pruefziffer nach Stelle 10

      pz = p1 % 7
      pz = 7 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 94
    # Modulus 10, Gewichtung 1, 2, 1, 2, 1, 2, 1, 2, 1.
    def m94(kto, blz, um, rv)
      if rv
        rv.methode = "94"
        rv.pz_methode = 94
      end
      pz = kto[0] + kto[2] + kto[4] + kto[6] + kto[8]
      pz += kto[1] < 5 ? kto[1] * 2 : kto[1] * 2 - 9
      pz += kto[3] < 5 ? kto[3] * 2 : kto[3] * 2 - 9
      pz += kto[5] < 5 ? kto[5] * 2 : kto[5] * 2 - 9
      pz += kto[7] < 5 ? kto[7] * 2 : kto[7] * 2 - 9

      pz %= 10
      pz = 10 - pz if pz != 0
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 95
    # Modulus 11, Gewichtung 2, 3, 4, 5, 6, 7, 2, 3, 4; fuer bestimmte
    # Nummernkreise (Sach- und Verrechnungskonten) entfaellt die Pruefung.
    def m95(kto, blz, um, rv)
      if rv
        rv.methode = "95"
        rv.pz_methode = 95
      end
      tmp = kto[0] * 1000 + kto[1] * 100 + kto[2] * 10 + kto[3]
      # Ausnahmen: keine Pruefzifferberechnung
      if tmp <= 1 ||
         (tmp >= 9 && tmp <= 25) ||
         (tmp >= 396 && tmp <= 499) ||
         (tmp >= 700 && tmp <= 799) ||
         (tmp >= 910 && tmp <= 989)
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
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 96
    # Variante A: Verfahren 19, Variante B: Verfahren 00; Kontonummern von
    # 0001300000 bis 0099399999 sind ohne Pruefzifferberechnung gueltig.
    def m96(kto, blz, um, rv)
      m3096(kto, blz, um, rv)
    end

    # Methode 96c (Nummernkreis ohne Pruefzifferberechnung)
    def m3096(kto, blz, um, rv)
      if rv
        rv.methode = "96c"
        rv.pz_methode = 3096
      end
      # die Berechnung muss in diesem Fall nicht gemacht werden
      s = kto.join
      return OK_NO_CHK if s >= "0001300000" && s < "0099400000"

      m1096(kto, blz, um, rv)
    end

    # Methode 96a (Verfahren 19)
    def m1096(kto, blz, um, rv)
      if rv
        rv.methode = "96a"
        rv.pz_methode = 1096
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
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZX10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      return OK if kto[9] == pz
      return FALSE if um != 0

      m2096(kto, blz, um, rv)
    end

    # Methode 96b (Verfahren 00)
    def m2096(kto, blz, um, rv)
      if rv
        rv.methode = "96b"
        rv.pz_methode = 2096
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

    # Methode 97
    # Die ersten 9 Stellen werden als Zahl modulo 11 gerechnet; ein Rest von
    # 10 ergibt die Pruefziffer 0.
    def m97(kto, blz, um, rv)
      if rv
        rv.methode = "97"
        rv.pz_methode = 97
      end
      if kto[0] == 0 && kto[1] == 0 && kto[2] == 0 && kto[3] == 0 && kto[4] == 0 &&
         kto[5] == 0
        return INVALID_KTO
      end

      # Pruefziffer temporaer loeschen -> atoi() ueber die ersten 9 Stellen
      pz = kto[0, 9].join.to_i % 11
      pz = 0 if pz == 10
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 98
    # Variante A: Modulus 10, Gewichtung 3, 1, 7, 3, 1, 7, 3;
    # Variante B: Verfahren 32 (Modulus 11, Gewichtung 2..7).
    def m98(kto, blz, um, rv)
      m1098(kto, blz, um, rv)
    end

    # Methode 98a
    def m1098(kto, blz, um, rv)
      if rv
        rv.methode = "98a"
        rv.pz_methode = 1098
      end
      pz = kto[2] * 3 +
           kto[3] * 7 +
           kto[4] +
           kto[5] * 3 +
           kto[6] * 7 +
           kto[7] +
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

      m2098(kto, blz, um, rv)
    end

    # Methode 98b (Verfahren 32)
    def m2098(kto, blz, um, rv)
      if rv
        rv.methode = "98b"
        rv.pz_methode = 2098
      end
      pz = kto[3] * 7 +
           kto[4] * 6 +
           kto[5] * 5 +
           kto[6] * 4 +
           kto[7] * 3 +
           kto[8] * 2

      pz %= 11
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end

    # Methode 99
    # Modulus 11, Gewichtung 2, 3, 4, 5, 6, 7, 2, 3, 4; Kontonummern von
    # 0396000000 bis 0499999999 sind ohne Pruefzifferberechnung gueltig.
    def m99(kto, blz, um, rv)
      if rv
        rv.methode = "99"
        rv.pz_methode = 99
      end
      s = kto.join
      if s >= "0396000000" && s < "0500000000"
        return OK
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
      pz = pz <= 1 ? 0 : 11 - pz
      # CHECK_PZ10
      if rv
        rv.pz_pos = 10
        rv.pz = pz
      end
      kto[9] == pz ? OK : FALSE
    end
  end
end
