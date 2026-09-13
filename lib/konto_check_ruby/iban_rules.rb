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
  # Port of iban_regel_cvt() from konto_check.c: applies the IBAN rules of
  # the Deutsche Bundesbank to a BLZ/account combination. The rules may
  # replace the BLZ and/or the account number, forbid the IBAN calculation
  # or prescribe a BIC.
  #
  # This module is included into Engine and uses its lookup helpers.
  module IbanRules
    # ---------------------------------------------------------------- Regel 5
    # Kontenkreis 9 98000000..99499999 ohne IBAN-Berechnung (Commerzbank)
    IBAN_R5_NO_IBAN_BLZ = [
      10080900, 12080000, 13080000, 14080000, 15080000, 16080000, 17080000, 18080000,
      20080055, 20080057, 21080050, 21280002, 21480003, 21580000, 22180000, 22181400,
      22280000, 24080000, 24180001, 25480021, 25780022, 25980027, 26080024, 26281420,
      26580070, 26880063, 26981062, 28280012, 29280011, 30080055, 30080057, 31080015,
      32080010, 33080030, 34080031, 34280032, 36280071, 36580072, 40080040, 41280043,
      42080082, 42680081, 43080083, 44080055, 44080057, 44580070, 45080060, 46080010,
      47880031, 49080025, 50080055, 50080057, 50080082, 50680002, 50780006, 50880050,
      51380040, 52080080, 53080030, 54080021, 54280023, 54580020, 54680022, 55080065,
      57080070, 58580074, 59080090, 60080055, 60080057, 60380002, 60480008, 61080006,
      61281007, 61480001, 62080012, 62280012, 63080015, 64080014, 64380011, 65080009,
      65180005, 65380003, 66280053, 66680013, 67280051, 69280035, 70080056, 70080057,
      70380006, 71180005, 72180002, 73180011, 73380004, 73480013, 74180009, 74380007,
      75080003, 76080053, 79080052, 79380051, 79580099, 80080000, 81080000, 82080000,
      83080000, 84080000, 85080200, 86080055, 86080057, 87080000
    ].freeze

    # ab Version 1 der Regel 5 freigegeben (im Kontenkreis 98000000..99499999)
    IBAN_R5_NO_IBAN_BLZ_V0 = [50080081, 51080000].freeze

    # BLZs ohne IBAN-Berechnung, ab Version 1 freigegeben
    IBAN_R5_BLZ_V0 = [
      10045050, 70045050, 10040085, 35040085, 36040085,
      44040085, 50040085, 67040085, 82040085
    ].freeze

    # Spendenkonten der Commerzbank: BLZ => { [k1, k2] => neue Kontonummer }
    IBAN_R5_SPENDEN = {
      10040000 => { [0, 7878] => "0267878700" },
      10080000 => { [0, 1987] => "0928127700", [0, 8888] => "0928126501", [0, 1234567] => "0920192001" },
      12080000 => { [0, 212121] => "4050462200", [0, 7654321] => "0144000700", [0, 12121212] => "4101725100" },
      16080000 => { [0, 123456] => "0012345600", [0, 3030400] => "4205227110" },
      20080000 => { [0, 2222] => "0903927200", [0, 505050] => "0500100600", [0, 666666] => "0900732500" },
      25040066 => { [0, 1919] => "0141919100" },
      26580070 => { [0, 700] => "0710000000" },
      29080010 => { [0, 124124] => "0107502000", [0, 12412400] => "0107502000" },
      30040000 => { [0, 36] => "0261103600", [0, 222] => "0348010002", [0, 999] => "0123799900" },
      30080000 => { [0, 700000] => "0800005000", [0, 70000000] => "0800005000" },
      32040024 => { [0, 47800] => "0155515000" },
      34280032 => { [0, 14111935] => "0645753800" },
      36040039 => { [0, 150] => "0161620000" },
      37040044 => { [0, 1888] => "0212129101", [0, 102030] => "0222344400", [0, 300000] => "0300000700" },
      37080040 => { [0, 100] => "0269100000", [0, 111] => "0215022000", [0, 4004] => "0233533500",
                    [0, 4444] => "0233000300", [0, 55555] => "0263602501", [0, 182002] => "0216603302",
                    [0, 300000] => "0983307900", [0, 333333] => "0270330000", [0, 414141] => "0041414100",
                    [0, 555666] => "0055566600", [0, 909090] => "0269100000", [0, 5555500] => "0263602501" },
      38040007 => { [0, 100] => "0119160000", [0, 240] => "0109024000", [0, 3366] => "0385333000",
                    [0, 55555] => "0305555500", [0, 336666] => "0105232300", [0, 414141] => "0108000100",
                    [0, 909090] => "0119160000", [0, 1555555] => "0258266600", [0, 43434343] => "0118163500" },
      39040013 => { [0, 556] => "0106555600" },
      39080005 => { [0, 556] => "0204655600", [0, 9800] => "0208457000" },
      43080083 => { [0, 4630] => "0825110100" },
      44040037 => { [1, 11111111] => "0320565500" },
      47840065 => { [0, 50] => "0150103000", [0, 55] => "0150103000", [0, 99] => "0150103000" },
      47880031 => { [0, 50] => "0519899900" },
      50040000 => { [0, 2000] => "0728400300", [0, 101010] => "0311011100" },
      50080000 => { [0, 6060] => "0096736100", [0, 9000] => "0026492100", [0, 42195] => "0900333200",
                    [0, 101010] => "0090003500" },
      50640015 => { [0, 777] => "0222222200" },
      51080060 => { [0, 123] => "0012299300" },
      55040022 => { [0, 555] => "0211050000", [0, 343434] => "0217900000" },
      57080070 => { [0, 661] => "0604101200" },
      60040071 => { [0, 502] => "0525950200", [5, 500500] => "0512700600" },
      60080000 => { [0, 502] => "0901581400", [5, 500500] => "0901581400" },
      61080006 => { [0, 9999999] => "0202427500" },
      64140036 => { [0, 8907339] => "0890733900" },
      66280053 => { [0, 121212] => "0625242400" },
      68080030 => { [0, 202] => "0416520200" },
      69240075 => { [0, 444] => "0445520000" },
      70040041 => { [4, 500500] => "0400500500", [0, 94] => "0212808000", [0, 1111111] => "0152140000",
                    [0, 7777777] => "0213600000" },
      70080000 => { [0, 94] => "0928553201", [0, 700000] => "0750055500", [0, 900000] => "0319966601",
                    [0, 949494] => "0575757500", [0, 1111111] => "0448060000", [0, 7777777] => "0443540000",
                    [0, 9000000] => "0319966601", [0, 70000000] => "0750055500" },
      75040062 => { [0, 6008833] => "0600883300" },
      76040061 => { [0, 2500000] => "0482146800" },
      79040047 => { [0, 9696] => "0680210200" },
      79080052 => { [0, 9696] => "0300021700" },
      85080000 => { [0, 400000] => "0459488501" },
      86080000 => { [0, 1212] => "0480375900", [0, 121200] => "0480375900" }
    }.freeze

    # ------------------------------------------------------------ Regeln 31-35
    # "Tabelle zu Kontokreise exHypo": Kontokreis (erste drei Ziffern der
    # 10-stelligen Kontonummer) => Nachfolge-BLZ
    IBAN_R31_KONTOKREIS = {
      100 => "76020070", 101 => "10020890", 102 => "78320076", 103 => "79320075", 104 => "76320072",
      105 => "79020076", 106 => "79320075", 107 => "79320075", 108 => "77320072", 109 => "79320075",
      110 => "76220073", 111 => "76020070", 112 => "79320075", 113 => "76020070", 114 => "76020070",
      115 => "76520071", 117 => "77120073", 118 => "76020070", 119 => "75320075", 120 => "72120078",
      121 => "76220073", 122 => "76320072", 123 => "76420080", 124 => "76320072", 125 => "79520070",
      126 => "77320072", 127 => "78020070", 128 => "78020070", 129 => "77120073", 130 => "78020070",
      131 => "78020070", 132 => "60020290", 134 => "78020070", 135 => "77020070", 136 => "79520070",
      137 => "79320075", 138 => "61120286", 139 => "66020286", 140 => "79020076", 142 => "64020186",
      143 => "60020290", 144 => "79020076", 145 => "66020286", 146 => "72120078", 147 => "72223182",
      148 => "76520071", 149 => "79020076", 150 => "76020070", 151 => "76320072", 152 => "78320076",
      154 => "70020270", 155 => "76520071", 156 => "76020070", 157 => "10020890", 158 => "70020270",
      159 => "54520194", 160 => "70020270", 161 => "54520194", 162 => "70020270", 163 => "70020270",
      164 => "70020270", 166 => "71120078", 167 => "74320073", 168 => "70320090", 169 => "79020076",
      170 => "70020270", 172 => "70020270", 174 => "70020270", 175 => "72120078", 176 => "74020074",
      177 => "74320073", 178 => "70020270", 181 => "77320072", 182 => "79520070", 183 => "70020270",
      185 => "70020270", 186 => "79020076", 188 => "70020270", 189 => "70020270", 190 => "76020070",
      191 => "77020070", 192 => "70025175", 193 => "85020086", 194 => "76020070", 196 => "72020070",
      198 => "76320072", 199 => "70020270", 201 => "76020070", 202 => "76020070", 203 => "76020070",
      204 => "76020070", 205 => "79520070", 206 => "79520070", 207 => "71120078", 208 => "73120075",
      209 => "18020086", 210 => "10020890", 211 => "60020290", 212 => "51020186", 214 => "75020073",
      215 => "63020086", 216 => "75020073", 217 => "79020076", 218 => "59020090", 219 => "79520070",
      220 => "73322380", 221 => "73120075", 222 => "73421478", 223 => "74320073", 224 => "73322380",
      225 => "74020074", 227 => "75020073", 228 => "71120078", 229 => "80020086", 230 => "72120078",
      231 => "72020070", 232 => "75021174", 233 => "71020072", 234 => "71022182", 235 => "74320073",
      236 => "71022182", 237 => "76020070", 238 => "63020086", 239 => "70020270", 240 => "75320075",
      241 => "76220073", 243 => "72020070", 245 => "72120078", 246 => "74320073", 247 => "60020290",
      248 => "85020086", 249 => "73321177", 250 => "73420071", 251 => "70020270", 252 => "70020270",
      253 => "70020270", 254 => "10020890", 255 => "50820292", 256 => "71022182", 257 => "83020086",
      258 => "79320075", 259 => "71120077", 260 => "10020890", 261 => "70025175", 262 => "72020070",
      264 => "74020074", 267 => "63020086", 268 => "70320090", 269 => "71122183", 270 => "82020086",
      271 => "75020073", 272 => "73420071", 274 => "63020086", 276 => "70020270", 277 => "74320073",
      278 => "71120077", 279 => "10020890", 281 => "71120078", 282 => "70020270", 283 => "72020070",
      284 => "79320075", 286 => "54520194", 287 => "70020270", 288 => "75220070", 291 => "77320072",
      292 => "76020070", 293 => "72020070", 294 => "54520194", 295 => "70020270", 296 => "70020270",
      299 => "72020070", 301 => "85020086", 302 => "54520194", 304 => "70020270", 308 => "70020270",
      309 => "54520194", 310 => "72020070", 312 => "74120071", 313 => "76320072", 314 => "70020270",
      315 => "70020270", 316 => "70020270", 317 => "70020270", 318 => "70020270", 320 => "71022182",
      321 => "75220070", 322 => "79520070", 324 => "70020270", 326 => "85020086", 327 => "72020070",
      328 => "72020070", 329 => "70020270", 330 => "76020070", 331 => "70020270", 333 => "70020270",
      334 => "75020073", 335 => "70020270", 337 => "80020086", 341 => "10020890", 342 => "10020890",
      344 => "70020270", 345 => "77020070", 346 => "76020070", 350 => "79320075", 351 => "79320075",
      352 => "70020270", 353 => "70020270", 354 => "72223182", 355 => "72020070", 356 => "70020270",
      358 => "54220091", 359 => "76220073", 360 => "80020087", 361 => "70020270", 362 => "70020270",
      363 => "70020270", 366 => "72220074", 367 => "70020270", 368 => "10020890", 369 => "76520071",
      370 => "85020086", 371 => "70020270", 373 => "70020270", 374 => "73120075", 375 => "70020270",
      379 => "70020270", 380 => "70020270", 381 => "70020270", 382 => "79520070", 383 => "72020070",
      384 => "72020070", 386 => "70020270", 387 => "70020270", 389 => "70020270", 390 => "67020190",
      391 => "70020270", 392 => "70020270", 393 => "54520194", 394 => "70020270", 396 => "70020270",
      398 => "66020286", 399 => "87020088", 401 => "30220190", 402 => "36020186", 403 => "38020090",
      404 => "30220190", 405 => "68020186", 406 => "48020086", 407 => "37020090", 408 => "68020186",
      409 => "10020890", 410 => "66020286", 411 => "60420186", 412 => "57020086", 422 => "70020270",
      423 => "70020270", 424 => "76020070", 426 => "70025175", 427 => "50320191", 428 => "70020270",
      429 => "85020086", 432 => "70020270", 434 => "60020290", 435 => "76020070", 436 => "76020070",
      437 => "70020270", 438 => "70020270", 439 => "70020270", 440 => "70020270", 441 => "70020270",
      442 => "85020086", 443 => "55020486", 444 => "50520190", 446 => "80020086", 447 => "70020270",
      450 => "30220190", 451 => "44020090", 452 => "70020270", 453 => "70020270", 456 => "10020890",
      457 => "87020086", 458 => "54520194", 459 => "61120286", 460 => "70020270", 461 => "70020270",
      462 => "70020270", 463 => "70020270", 465 => "70020270", 466 => "10020890", 467 => "10020890",
      468 => "70020270", 469 => "60320291", 470 => "65020186", 471 => "84020087", 472 => "76020070",
      473 => "74020074", 476 => "78320076", 477 => "78320076", 478 => "87020088", 480 => "70020270",
      481 => "70020270", 482 => "84020087", 484 => "70020270", 485 => "50320191", 486 => "70020270",
      488 => "67220286", 489 => "10020890", 490 => "10020890", 491 => "16020086", 492 => "10020890",
      494 => "79020076", 495 => "87020088", 497 => "87020087", 499 => "79020076", 502 => "10020890",
      503 => "10020890", 505 => "70020270", 506 => "10020890", 507 => "87020086", 508 => "86020086",
      509 => "83020087", 510 => "80020086", 511 => "83020086", 513 => "85020086", 515 => "17020086",
      518 => "82020086", 519 => "83020086", 522 => "10020890", 523 => "70020270", 524 => "85020086",
      525 => "70020270", 527 => "82020088", 528 => "10020890", 530 => "10020890", 531 => "10020890",
      533 => "50320191", 534 => "70020270", 536 => "85020086", 538 => "82020086", 540 => "65020186",
      541 => "80020087", 545 => "18020086", 546 => "10020890", 547 => "10020890", 548 => "10020890",
      549 => "82020087", 555 => "79020076", 560 => "79320075", 567 => "86020086", 572 => "10020890",
      580 => "70020270", 581 => "70020270", 601 => "74320073", 602 => "70020270", 603 => "70020270",
      604 => "70020270", 605 => "70020270", 606 => "70020270", 607 => "74320073", 608 => "72020070",
      609 => "72020070", 610 => "72020070", 611 => "72020070", 612 => "71120077", 613 => "70020270",
      614 => "72020070", 615 => "70025175", 616 => "73420071", 617 => "68020186", 618 => "73120075",
      619 => "60020290", 620 => "71120077", 621 => "71120077", 622 => "74320073", 623 => "72020070",
      624 => "71020072", 625 => "71023173", 626 => "71020072", 627 => "71021270", 628 => "71120077",
      629 => "73120075", 630 => "71121176", 631 => "71022182", 632 => "70020270", 633 => "74320073",
      634 => "70020270", 635 => "70320090", 636 => "70320090", 637 => "72120078", 638 => "72120078",
      640 => "70020270", 641 => "70020270", 643 => "74320073", 644 => "70020270", 645 => "70020270",
      646 => "70020270", 647 => "70020270", 648 => "72120078", 649 => "72122181", 650 => "54520194",
      652 => "71021270", 653 => "70020270", 654 => "70020270", 655 => "72120078", 656 => "71120078",
      657 => "71020072", 658 => "68020186", 659 => "54520194", 660 => "54620093", 661 => "74320073",
      662 => "73120075", 663 => "70322192", 664 => "72120078", 665 => "70321194", 666 => "73322380",
      667 => "60020290", 668 => "60020290", 669 => "73320073", 670 => "75020073", 671 => "74220075",
      672 => "74020074", 673 => "74020074", 674 => "74120071", 675 => "74020074", 676 => "74020074",
      677 => "72020070", 678 => "72020070", 679 => "54520194", 680 => "71120077", 681 => "67020190",
      682 => "78020070", 683 => "71020072", 684 => "70020270", 685 => "70020270", 686 => "70020270",
      687 => "70020270", 688 => "70020270", 689 => "70020270", 690 => "76520071", 692 => "70020270",
      693 => "73420071", 694 => "70021180", 695 => "70320090", 696 => "74320073", 697 => "54020090",
      698 => "73320073", 710 => "30220190", 711 => "70020270", 712 => "10020890", 714 => "76020070",
      715 => "75020073", 717 => "74320073", 718 => "87020086", 719 => "37020090", 720 => "30220190",
      723 => "77320072", 733 => "83020087", 798 => "70020270",
    }.freeze

    # --------------------------------------------------------------- Regel 53
    # BLZ => { [k1, k2] => echte Kontonummer }; BLZ neu ist stets 60050101,
    # der BIC stets SOLADEST600
    IBAN_R53_SONDERKONTEN = {
      55050000 => { [0, 901] => "7401507497", [0, 902] => "7401507473", [0, 908] => "7401507480",
                    [0, 910] => "7401507466", [0, 3500] => "7401555913", [0, 35000] => "7401555913",
                    [0, 35100] => "7401555913", [0, 44000] => "7401555872", [0, 55020100] => "7401555872",
                    [1, 10024270] => "7401501266", [1, 10050002] => "7401502234", [1, 10132511] => "7401550530",
                    [1, 10149226] => "7401512248", [1, 19345106] => "7401555906" },
      60020030 => { [10, 617900] => "0002009906", [10, 919900] => "7871531505", [10, 2999900] => "0002588991",
                    [10, 3340500] => "0002001155", [10, 4184600] => "7871513509", [10, 40748400] => "0001366705",
                    [10, 47444300] => "7871538395", [10, 54290000] => "7871521216" },
      60050000 => { [0, 1523] => "0001364934", [0, 2502] => "0001366705", [0, 2535] => "0001119897",
                    [0, 2811] => "0001367450", [0, 3002] => "0001367924", [0, 3009] => "0001367924",
                    [0, 3080] => "0002009906", [0, 4596] => "0001372809", [0, 5500] => "0001375703",
                    [0, 123456] => "0001362826", [0, 250412] => "7402051588", [0, 1029204] => "0002782254" },
      66020020 => { [40, 604100] => "0002810030", [40, 2015800] => "7495530102", [40, 2401000] => "7495500967",
                    [40, 3746700] => "7495501485" },
      66050000 => { [0, 85304] => "7402045439", [0, 85990] => "7402051588", [0, 86345] => "7402046641",
                    [0, 86567] => "0001364934" },
      86050000 => { [0, 1016] => "7461500128", [0, 2020] => "7461500018", [0, 3535] => "7461505611",
                    [0, 4394] => "7461505714" }
    }.freeze

    # Applies IBAN rule `regel_version` (rule * 100 + version, as stored in
    # the Bundesbank file) to blz (mutable String, 8 digits) and kto (mutable
    # String, 10 digits, zero padded). Both may be modified in place.
    # Returns [ret, bic]: ret is a return code (OK, OK_BLZ_REPLACED,
    # OK_KTO_REPLACED, OK_BLZ_KTO_REPLACED, NO_IBAN_CALCULATION,
    # IBAN_RULE_UNKNOWN, ...), bic a prescribed BIC or nil.
    def iban_regel_cvt(blz, kto, regel_version, retvals = nil)
      return [LUT2_NOT_INITIALIZED, nil] unless @data
      return [INVALID_BLZ, nil] unless blz =~ /\A\d{8}\z/
      return [INVALID_KTO, nil] unless kto =~ /\A\d{1,10}\z/

      ret = iban_init
      return [ret, nil] if ret < OK

      regel = regel_version / 100
      version = regel_version % 100
      bic = nil
      ret = OK

      # Konto und BLZ nach Integer umwandeln
      k1 = kto[0, 2].to_i
      k2 = kto[2, 8].to_i
      b_alt = b = blz.to_i

      # Löschkennzeichen der BLZ überprüfen, u.U. Nachfolge-BLZ einsetzen
      if lut_aenderung_i(b) == "D"
        b = lut_nachfolge_blz_i(b)
        return [BLZ_MARKED_AS_DELETED, bic] if b == 0
      end

      # Makros RETURN_OK und RETURN_OK_KTO_REPLACED (Löschkennzeichen und
      # Nachfolge-BLZ werden für den Rückgabewert beachtet)
      r_ok = -> { [b != b_alt ? OK_BLZ_REPLACED : OK, bic] }
      r_ok_kto = -> { [b != b_alt ? OK_BLZ_KTO_REPLACED : OK_KTO_REPLACED, bic] }

      case regel

      # IBAN-Regel 0000.00  Standardregel zur IBAN-Berechnung
      when 0
        return [ret, bic] if ret == OK_UNTERKONTO_ATTACHED
        return r_ok.call

      # IBAN-Regel 0001.00  Standardregel: keine Berechnung
      when 1
        return [NO_IBAN_CALCULATION, bic]

      # IBAN-Regel 0002.00  Augsburger Aktienbank
      when 2
        return [NO_IBAN_CALCULATION, bic] if (kto[7] == "8" && kto[8] == "6") || kto[7] == "6"
        return r_ok.call

      # IBAN-Regel 0003.00  Aareal Bank AG
      when 3
        return [NO_IBAN_CALCULATION, bic] if kto == "6161604670"
        return r_ok.call

      # IBAN-Regel 0004.00  Landesbank Berlin / Berliner Sparkasse
      when 4
        if k1 == 0
          neu = case k2
                when 135 then "0990021440"
                when 1111 then "6600012020"
                when 1900 then "0920019005"
                when 7878 then "0780008006"
                when 8888 then "0250030942"
                when 9595 then "1653524703"
                when 97097 then "0013044150"
                when 112233 then "0630025819"
                when 336666 then "6604058903"
                when 484848 then "0920018963"
                end
          if neu
            kto.replace(neu)
            return r_ok_kto.call
          end
        end
        return r_ok.call

      # IBAN-Regel 0005.03  Commerzbank AG
      when 5
        idx = lut_index(blz)
        return [idx, bic] if idx < 0
        pz_methode = @data.pz[idx]

        # comdirect bank behält ihren BIC, alle anderen BLZs der Commerzbank
        # bekommen COBADEFFXXX
        bic = "COBADEFFXXX" if blz[3] == "4" && blz[4] != "1"

        # BLZs ohne Prüfzifferberechnung
        return [OK_NO_CHK, bic] if pz_methode == 9

        # Kontenkreis ohne IBAN-Berechnung (für etliche BLZs)
        if k1 == 9 && k2 >= 98_000_000 && k2 <= 99_499_999
          return [NO_IBAN_CALCULATION, bic] if IBAN_R5_NO_IBAN_BLZ.include?(b)
          return [NO_IBAN_CALCULATION, bic] if version == 0 && IBAN_R5_NO_IBAN_BLZ_V0.include?(b)
        end

        # BLZs ohne IBAN-Berechnung (etliche ab Version 1 der Regel freigegeben)
        return [NO_IBAN_CALCULATION, bic] if b == 50040033
        return [NO_IBAN_CALCULATION, bic] if version == 0 && IBAN_R5_BLZ_V0.include?(b)

        # Spendenkonten
        if (tab = IBAN_R5_SPENDEN[b]) && (neu = tab[[k1, k2]])
          kto.replace(neu)
          return r_ok_kto.call
        end

        # Prüfziffermethode 13: fehlendes Unterkonto "00" ergänzen, falls die
        # Kontonummer nur 6- oder 7-stellig ist
        if pz_methode == 13 && kto[0] == "0" && kto[1] == "0" && kto[2] == "0" &&
           (kto[3] != "0" || kto[4] != "0")
          kto.replace(kto[0] + kto[3, 7] + "00")
          return [kto_check_pz("13a", kto, nil) > 0 ? OK_UNTERKONTO_ATTACHED : FALSE_UNTERKONTO_ATTACHED, bic]
        end

        # Ausnahme in Prüfziffermethode 76 (Prüfziffer auf Stelle 10)
        if pz_methode == 76
          ret = kto_check_pz("76a", kto, nil)
          if ret < OK && kto[0] == "0" && kto[1] == "0" && kto_check_pz("76b", kto, nil) > 0
            kto.replace(kto[2, 8] + "00")
            return [OK_UNTERKONTO_ATTACHED, bic]
          end
          return [ret, bic]
        end

        return r_ok.call

      # IBAN-Regel 0006.00  Stadtsparkasse München
      when 6
        if k1 == 0
          neu = case k2
                when 1111111 then "0020228888"
                when 7777777 then "0903286003"
                when 34343434 then "1000506517"
                when 70000 then "0018180018"
                end
          if neu
            kto.replace(neu)
            return r_ok_kto.call
          end
        end
        return r_ok.call

      # IBAN-Regel 0007.00  Sparkasse Köln-Bonn
      when 7
        if k1 == 2
          if k2 == 820082
            kto.replace("1901783868")
            return r_ok_kto.call
          end
          if k2 == 22220022
            kto.replace("0002222222")
            return r_ok_kto.call
          end
        end
        if k1 == 0
          neu = case k2
                when 111 then "0000001115"
                when 221 then "0023002157"
                when 1888 then "0018882068"
                when 2006 then "1900668508"
                when 2626 then "1900730100"
                when 3004 then "1900637016"
                when 3636 then "0023002447"
                when 4000 then "0000004028"
                when 4444 then "0000017368"
                when 5050 then "0000073999"
                when 8888 then "1901335750"
                when 30000 then "0009992959"
                when 43430 then "1901693331"
                when 46664 then "1900399856"
                when 55555 then "0034407379"
                when 102030 then "1900480466"
                when 151515 then "0057762957"
                when 222222 then "0002222222"
                when 300000 then "0009992959"
                when 333333 then "0000033217"
                when 414141 then "0000092817"
                when 606060 then "0000091025"
                when 909090 then "0000090944"
                when 2602024 then "0005602024"
                when 3000000 then "0009992959"
                when 7777777 then "0002222222"
                when 8090100 then "0000038901"
                when 14141414 then "0043597665"
                when 15000023 then "0015002223"
                when 15151515 then "0057762957"
                when 22222222 then "0002222222"
                end
          if neu
            kto.replace(neu)
            return r_ok_kto.call
          end
        end
        return r_ok.call

      # IBAN-Regel 0008.00  BHF-Bank AG
      when 8
        return [OK, bic] if b == 50020200
        blz.replace("50020200")
        bic = "BHFBDEFF500"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0009.00  Sparkasse Schopfheim-Zell
      when 9
        return [OK, bic] if b == 68351557
        blz.replace("68351557")
        bic = "SOLADES1SFH"
        # Konten der ehemaligen Sparkasse Zell im Wiesental, die mit 1116
        # beginnen: die ersten vier Stellen werden durch 3047 ersetzt
        if b == 68351976 && kto[0, 4] == "1116"
          kto[0, 4] = "3047"
          return [OK_BLZ_KTO_REPLACED, bic]
        end
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0010.01  Frankfurter Sparkasse
      when 10
        if b == 50050222
          blz.replace("50050201")
          ret = OK_BLZ_REPLACED
          b = 50050201
        else
          ret = OK
        end
        if b == 50050201 && k1 == 0
          if k2 == 2000
            kto.replace("0000222000")
            return ret == OK_BLZ_REPLACED ? [OK_BLZ_KTO_REPLACED, bic] : r_ok_kto.call
          end
          if k2 == 800000
            kto.replace("0000180802")
            return ret == OK_BLZ_REPLACED ? [OK_BLZ_KTO_REPLACED, bic] : r_ok_kto.call
          end
        end
        return [ret, bic]

      # IBAN-Regel 0011.00  Sparkasse Krefeld
      when 11
        if k1 == 0
          case k2
          when 1000
            kto.replace("0008010001")
            return r_ok_kto.call
          when 47800
            kto.replace("0000047803")
            return r_ok_kto.call
          end
        end
        return r_ok.call

      # IBAN-Regel 0012.01  Landesbank Hessen-Thüringen
      when 12
        return [OK, bic] if b == 50050000
        blz.replace("50050000")
        bic = "HELADEFFXXX"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0013.01  Landesbank Hessen-Thüringen
      when 13
        return [OK, bic] if b == 30050000
        blz.replace("30050000")
        bic = "WELADEDDXXX"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0014.00  Deutsche Apotheker- u. Ärztebank
      when 14
        return [OK, bic] if b == 30060601
        blz.replace("30060601")
        bic = "DAAEDEDDXXX"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0015.01  Pax-Bank eG
      when 15
        if k1 == 4 && k2 == 569017
          kto.replace("4000569017")
          return r_ok_kto.call
        end
        if k1 == 0
          neu = case k2
                when 94 then "3008888018"
                when 556 then "0000101010"
                when 888 then "0031870011"
                when 4040 then "4003600101"
                when 5826 then "1015826017"
                when 25000 then "0025000110"
                when 393393 then "0033013019"
                when 444555 then "0032230016"
                when 603060 then "6002919018"
                when 2120041 then "0002130041"
                when 80868086 then "4007375013"
                end
          if neu
            kto.replace(neu)
            return r_ok_kto.call
          end
        end
        return r_ok.call

      # IBAN-Regel 0016.00  Kölner Bank eG
      when 16
        if k1 == 0 && k2 == 300000
          kto.replace("0018128012")
          return r_ok_kto.call
        end
        return r_ok.call

      # IBAN-Regel 0017.00  Volksbank Bonn Rhein-Sieg
      when 17
        if k1 == 0
          neu = case k2
                when 100 then "2009090013"
                when 111 then "2111111017"
                when 240 then "2100240010"
                when 4004 then "2204004016"
                when 4444 then "2044444014"
                when 6060 then "2016060014"
                when 102030 then "1102030016"
                when 333333 then "2033333016"
                when 909090 then "2009090013"
                when 50005000 then "5000500013"
                end
          if neu
            kto.replace(neu)
            return r_ok_kto.call
          end
        end
        return r_ok.call

      # IBAN-Regel 0018.00  Aachener Bank eG
      when 18
        if k1 == 54 && k2 == 35435430
          kto.replace("0543543543")
          return r_ok_kto.call
        end
        if k1 == 0
          neu = case k2
                when 556 then "0120440110"
                when 2157 then "0121787016"
                when 9800 then "0120800019"
                when 202050 then "1221864014"
                end
          if neu
            kto.replace(neu)
            return r_ok_kto.call
          end
        end
        return r_ok.call

      # IBAN-Regel 0019.00  Bethmann Bank
      when 19
        return [OK, bic] if b == 50120383
        blz.replace("50120383")
        bic = "DELBDE33XXX"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0020.02  Deutsche Bank AG
      when 20
        # BLZ ohne IBAN-Berechnung
        return [NO_IBAN_CALCULATION, bic] if b == 10020000

        # Spendenkontonummer
        if b == 50070010 && k1 == 0 && k2 == 9999
          kto.replace("0092777202")
          return r_ok_kto.call
        end

        idx = lut_index(blz)
        return [idx, bic] if idx < 0
        pz_methode = @data.pz[idx]

        # Prüfzifferverfahren 09 (Deutsche Bank GF intern)
        return [OK_NO_CHK, bic] if pz_methode == 9

        # Sonderfall Norisbank: Konten, bei denen ausschließlich das
        # Prüfzifferverfahren 06 eine gültige Prüfziffer liefert, sind für die
        # IBAN-Berechnung nicht zugelassen
        if pz_methode == 127 && kto_check_pz("c7a", kto, nil) < OK && kto_check_pz("c7c", kto, nil) < OK
          if retvals
            retvals.methode = "c7b"
            retvals.pz_methode = 2127
          end
          ret = kto_check_pz("c7b", kto, nil)
          return [ret == OK ? NO_IBAN_CALCULATION : ret, bic]
        end

        # 10-stellige Konten sind ungültig
        return [INVALID_KTO, bic] if kto[0] != "0"

        # jetzt kommt nur noch das Prüfzifferverfahren 63 (Deutsche Bank)
        if retvals
          retvals.methode = "63"
          retvals.pz_methode = 63
        end

        if k1 == 0
          # 1-4 stellige Konten sind generell nicht zugelassen
          return [NO_IBAN_CALCULATION, bic] if k2 < 10000

          # 5- und 6-stellige Konten: rechts zwei Nullen anfügen
          if k2 < 1000000
            tmp = kto_check_pz("63a", kto, nil)
            kto.replace(kto[2, 8] + "00")
            ret = kto_check_pz("63a", kto, nil)
            return [OK_UNTERKONTO_ATTACHED, bic] if ret == OK
            if retvals
              retvals.methode = "63b"
              retvals.pz_methode = 2063
            end
            return [tmp == OK ? NO_IBAN_CALCULATION : ret, bic]
          end

          # 7-stellige Konten: zuerst Unterkonto 00 anhängen, sonst mit 63a
          if k2 >= 1000000 && k2 < 10000000
            if kto_check_pz("63b", kto, nil) == OK
              kto.replace(kto[2, 8] + "00")
              return [OK_UNTERKONTO_ATTACHED, bic]
            end
            return [kto_check_pz("63a", kto, nil), bic]
          end
        end

        # alle restlichen Konten (8- bis 9-stellig) nur mit Methode 63a prüfen
        return [kto_check_pz("63a", kto, nil), bic]

      # IBAN-Regel 0021.01  National-Bank AG
      when 21
        # 1-5 stellige oder 8 stellige Konten sind ungültig
        return [INVALID_KTO, bic] if k1 == 0 && (k2 < 100000 || k2 > 9999999)
        return [OK, bic] if b == 36020030
        blz.replace("36020030")
        bic = "NBAGDE3EXXX"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0022.00  GLS Gemeinschaftsbank eG
      when 22
        if k1 == 0 && k2 == 1111111
          kto.replace("2222200000")
          return r_ok_kto.call
        end
        return r_ok.call

      # IBAN-Regel 0023.00  Volksbank Osnabrück eG
      when 23
        if k1 == 0 && k2 == 700
          kto.replace("1000700800")
          return r_ok_kto.call
        end
        return r_ok.call

      # IBAN-Regel 0024.00  Bank im Bistum Essen eG
      # (die Ersatzkontonummern sind hier nur achtstellig, wie im C-Code)
      when 24
        if k1 == 0
          neu = case k2
                when 94 then "00001694"
                when 248 then "00017248"
                when 345 then "00017345"
                when 400 then "00014400"
                end
          if neu
            kto.replace(neu)
            return r_ok_kto.call
          end
        end
        return r_ok.call

      # IBAN-Regel 0025.00  Landesbank Baden-Württemberg / BW-Bank
      when 25
        return [OK, bic] if b == 60050101
        blz.replace("60050101")
        bic = "SOLADEST600"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0026.00  Bank für Kirche und Diakonie eG
      when 26
        return [OK_IBAN_WITHOUT_KC_TEST, bic] if k1 == 0 && (k2 == 55111 || k2 == 8090100)
        return r_ok.call

      # IBAN-Regel 0027.00  Volksbank Krefeld eG
      when 27
        return [OK_IBAN_WITHOUT_KC_TEST, bic] if k1 == 0 && (k2 == 3333 || k2 == 4444)
        return r_ok.call

      # IBAN-Regel 0028.00  Sparkasse Hannover
      when 28
        return [OK, bic] if b == 25050180
        blz.replace("25050180")
        bic = "SPKHDE2HXXX"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0029.00  Société Générale
      when 29
        # 10-stellige Kontonummern mit einer "0" an Position 4: die 4. Ziffer
        # wird entfernt
        if kto[0] != "0" && kto[3] == "0"
          kto.replace("0" + kto[0, 3] + kto[4, 6])
          return r_ok_kto.call
        end
        return r_ok.call

      # IBAN-Regel 0030.00  Pommersche Volksbank eG (ab September 2018 entfallen)
      when 30
        return [OK, bic]

      # IBAN-Regeln 0031.01 .. 0035.01  UniCredit Bank AG (ex HypoVereinsbank)
      when 31, 32, 33, 34, 35
        loesch, ret = lut_loeschung(blz, 0)
        loesch = loesch == 1 ? 1 : 0
        return [ret, bic] if ret < OK

        # Spendenkonten nicht testen
        spende = (regel == 33 && k1 == 0 &&
                  (k2 == 22222 || k2 == 1111111 || k2 == 94 || k2 == 7777777 || k2 == 55555)) ||
                 (regel == 34 && ((k1 == 0 && k2 == 502) || (k1 == 5 && k2 == 500500))) ||
                 (regel == 35 && k1 == 0 && k2 == 9696)
        unless spende
          ret = kto_check_blz(blz, kto)
          return [ret, bic] if ret < OK
        end

        case regel
        when 31
          if loesch == 0
            # Testfall D bei IBAN-Regel 31: weiter wie Regel 32
            return [NO_IBAN_CALCULATION, bic] if k1 == 8
          else
            # 31: nur 10-stellige Konten
            return [NO_IBAN_CALCULATION, bic] if kto[0] == "0"
          end

        when 32
          return [IBAN_INVALID_RULE, bic] if loesch != 0
          return [NO_IBAN_CALCULATION, bic] if k1 == 8

        when 33
          return [IBAN_INVALID_RULE, bic] if b != 70020270
          if k1 == 0
            neu = case k2
                  when 22222 then "5803435253"
                  when 1111111 then "0039908140"
                  when 94 then "0002711931"
                  when 7777777 then "5800522694"
                  when 55555 then "5801800000"
                  end
            if neu
              kto.replace(neu)
              return r_ok_kto.call
            end
          end

        when 34
          return [IBAN_INVALID_RULE, bic] if b != 60020290
          return [NO_IBAN_CALCULATION, bic] if k1 == 8
          if k1 == 5 && k2 == 500500
            kto.replace("4340111112")
            return r_ok_kto.call
          end
          if k1 == 0 && k2 == 502
            kto.replace("4340118001")
            return r_ok_kto.call
          end

        when 35
          return [IBAN_INVALID_RULE, bic] if b != 79020076
          return [NO_IBAN_CALCULATION, bic] if k1 == 8
          if k1 == 0 && k2 == 9696
            kto.replace("1490196966")
            return r_ok_kto.call
          end
        end

        # Für 10-stellige Kontonummern die Nachfolge-BLZ aus dem Kontokreis
        # bestimmen ("Tabelle zu Kontokreise exHypo"); gilt für die Regeln 31-35
        if kto[0] != "0"
          k3 = kto[0, 3].to_i
          blz_neu = IBAN_R31_KONTOKREIS[k3]
          # kein Kontenkreis definiert, dürfte ein ungültiges Konto sein
          return [INVALID_KTO, bic] unless blz_neu
          blz.replace(blz_neu)
          b_neu = blz.to_i
          ret = b == b_neu ? OK : OK_BLZ_REPLACED
        else
          ret = OK
        end

        # BIC aus der Nachfolge-BLZ bestimmen (die ist hier eingesetzt)
        bic = lut_bic_int(blz, 0)[0]
        return [ret, bic]

      # IBAN-Regel 0036.00  HSH Nordbank AG
      when 36
        # Variante 3: Kontonummernkreise ohne IBAN-Ermittlung
        if (k1 == 0 && (k2 <= 99999 || (k2 >= 900000 && k2 <= 29999999) || k2 >= 60000000)) ||
           k1 == 9 || (k1 >= 20 && k1 <= 29) || (k1 >= 71 && k1 <= 84) || (k1 >= 86 && k1 <= 89)
          return [NO_IBAN_CALCULATION, bic]
        end

        blz.replace("21050000")

        # Variante 1: 6-stellige Kontonummern, 5. Stelle 1-8: rechtsbündig mit
        # 3 Nullen aufgefüllt
        if kto[0] == "0" && kto[1] == "0" && kto[2] == "0" && kto[3] == "0" && kto[4] != "0"
          kto.replace("0" + kto[4, 6] + "000")
          ret = kto_check_blz(blz, kto)
          return [ret, bic] if ret < OK
          return b == 21050000 ? r_ok_kto.call : [OK_BLZ_KTO_REPLACED, bic]
        end

        # Variante 2: alle übrigen Kontonummern (Standard, linksbündig)
        ret = kto_check_blz(blz, kto)
        return [ret, bic] if ret < OK
        return [b == 21050000 ? OK : OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0037.00  The Bank of Tokyo-Mitsubishi UFJ, Ltd.
      when 37
        return [OK, bic] if b == 30010700
        blz.replace("30010700")
        bic = "BOTKDEDXXXX"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0038.00  Ostfriesische Volksbank eG
      when 38
        return [OK, bic] if b == 28590075
        case b
        when 26691213, 28591579, 25090300
          blz.replace("28590075")
          bic = "GENODEF1LER"
          return [OK_BLZ_REPLACED, bic]
        end
        return r_ok.call

      # IBAN-Regel 0039.00  Oldenburgische Landesbank AG
      when 39
        return [OK, bic] if b == 28020050
        blz.replace("28020050")
        bic = "OLBODEH2XXX"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0040.01  Sparkasse Staufen-Breisach
      when 40
        return [OK, bic] if b == 68052328
        blz.replace("68052328")
        bic = "SOLADES1STF"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0041.00  Bausparkasse Schwäbisch Hall AG
      when 41
        if b == 62220000
          blz.replace("50060400")
          kto.replace("0000011404")
          bic = "GENODEFFXXX"
          return [OK_BLZ_KTO_REPLACED, bic]
        end
        return r_ok.call

      # IBAN-Regel 0042.01  Deutsche Bundesbank
      when 42
        # ab Dezember 2016 sind auch 10-stellige Konten nnn4400001..nnn4499999 zulässig
        if k1 >= 10
          if kto[3] == "4" && kto[4] == "4" &&
             (kto[5] != "0" || kto[6] != "0" || kto[7] != "0" || kto[8] != "0" || kto[9] != "0")
            return [OK, bic]
          end
          return [NO_IBAN_CALCULATION, bic]
        end

        # ansonsten sind nur noch 8-stellige Konten freigegeben
        return [NO_IBAN_CALCULATION, bic] if k1 != 0 || k2 < 10000000

        # Konten ohne IBAN-Berechnung: nnn 0 0000 bis nnn 0 0999
        return [NO_IBAN_CALCULATION, bic] if kto[5] == "0" && kto[6] == "0"

        # die Kontonummer muss an der 4. Stelle (der 8-stelligen Nummer) '0' sein
        return [OK, bic] if kto[5] == "0"

        # außerdem freigegeben: 50462000..50463999 sowie 50469000..50469999
        if k1 == 0 && ((k2 >= 50462000 && k2 <= 50463999) || (k2 >= 50469000 && k2 <= 50469999))
          return [OK, bic]
        end
        return [NO_IBAN_CALCULATION, bic]

      # IBAN-Regel 0043.01  Sparkasse Pforzheim Calw
      when 43
        if b == 60651070
          blz.replace("66650085")
          bic = "PZHSDE66XXX"
          return [OK_BLZ_REPLACED, bic]
        end
        return r_ok.call

      # IBAN-Regel 0044.00  Sparkasse Freiburg
      when 44
        if k1 == 0 && k2 == 202
          kto.replace("0002282022")
          return r_ok_kto.call
        end
        return r_ok.call

      # IBAN-Regel 0045.01  SEB AG (ab September 2017 entfallen)
      when 45
        return [OK, bic]

      # IBAN-Regel 0046.00  Santander Consumer Bank
      when 46
        return [OK, bic] if b == 31010833
        blz.replace("31010833")
        bic = "CCBADE31XXX"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0047.00  Santander Consumer Bank
      when 47
        # achtstellige Kontonummern sind rechtsbündig mit Nullen aufzufüllen
        if kto[0] == "0" && kto[1] == "0" && kto[2] != "0"
          kto.replace(kto[2, 8] + "00")
          return r_ok_kto.call
        end
        return r_ok.call

      # IBAN-Regel 0048.00  VON ESSEN GmbH & Co. KG Bankgesellschaft
      when 48
        return [OK, bic] if b == 36010200
        blz.replace("36010200")
        bic = "VONEDE33XXX"
        return [OK_BLZ_REPLACED, bic]

      # IBAN-Regel 0049.01  DZ Bank
      when 49
        # Kontonummern mit einer '9' an der 5. Stelle: die ersten 4 Stellen
        # werden ans Ende gestellt; diese Kontonummer hat keine Prüfziffer
        return r_ok.call if kto[4] != "9"
        tmp_buffer = kto.dup
        kto.replace(tmp_buffer[4, 6] + tmp_buffer[0, 4])
        return [OK_KTO_REPLACED_NO_PZ, bic]

      # IBAN-Regel 0050.00  Sparkasse LeerWittmund
      when 50
        if b == 28252760
          blz.replace("28550000")
          bic = "BRLADE21LER"
          return [OK_BLZ_REPLACED, bic]
        end
        return r_ok.call

      # IBAN-Regel 0051.00  Landesbank Baden-Württemberg / BW-Bank
      when 51
        if k1 == 0
          case k2
          when 333
            kto.replace("7832500881")
            return r_ok_kto.call
          when 502
            kto.replace("0001108884")
            return r_ok_kto.call
          end
        end
        if k1 == 5
          case k2
          when 500500
            kto.replace("0005005000")
            return r_ok_kto.call
          when 2502502
            kto.replace("0001108884")
            return r_ok_kto.call
          end
        end
        return r_ok.call

      # IBAN-Regel 0052.00  Landesbank Baden-Württemberg / BW-Bank
      when 52
        neu = if b == 67220020 && k1 == 53 && k2 == 8810004 then "0002662604"
              elsif b == 67220020 && k1 == 53 && k2 == 8810000 then "0002659600"
              elsif b == 67020020 && k1 == 52 && k2 == 3145700 then "7496510994"
              elsif b == 69421020 && k1 == 62 && k2 == 8908100 then "7481501341"
              elsif b == 66620020 && k1 == 48 && k2 == 40404000 then "7498502663"
              elsif b == 64120030 && k1 == 12 && k2 == 1200100 then "7477501214"
              elsif b == 64020030 && k1 == 14 && k2 == 8050100 then "7469534505"
              elsif b == 63020130 && k1 == 11 && k2 == 12156300 then "0004475655"
              elsif b == 62030050 && k1 == 70 && k2 == 2703200 then "7406501175"
              elsif b == 69220020 && k1 == 64 && k2 == 2145400 then "7485500252"
              end
        if neu
          blz.replace("60050101")
          kto.replace(neu)
          bic = "SOLADEST600"
          return [OK_BLZ_KTO_REPLACED, bic]
        end
        return [NO_IBAN_CALCULATION, bic]

      # IBAN-Regel 0053.00  Landesbank Baden-Württemberg / BW-Bank
      when 53
        if (tab = IBAN_R53_SONDERKONTEN[b]) && (neu = tab[[k1, k2]])
          blz.replace("60050101")
          kto.replace(neu)
          bic = "SOLADEST600"
          return [OK_BLZ_KTO_REPLACED, bic]
        end
        return r_ok.call

      # IBAN-Regel 0054.01  Evangelische Darlehnsgenossenschaft eG (ab Juni 2017 entfallen)
      when 54
        return [OK, bic]

      # IBAN-Regel 0055.00  BHW Kreditservice GmbH
      when 55
        if b != 25410200
          blz.replace("25410200")
          bic = "BHWBDE2HXXX"
          return [OK_BLZ_REPLACED, bic]
        end
        return r_ok.call

      # IBAN-Regel 0056.03  SEB AG (ab Dezember 2018 entfallen)
      when 56
        return r_ok.call

      # IBAN-Regel 0057.00  Badenia Bausparkasse
      when 57
        if b != 66010200
          blz.replace("66010200")
          bic = "BBSPDE6KXXX"
          return [OK_BLZ_REPLACED, bic]
        end
        return r_ok.call

      # Lumpensammler für unbekannte Regeln
      else
        return [IBAN_RULE_UNKNOWN, bic]
      end
    end
  end
end
