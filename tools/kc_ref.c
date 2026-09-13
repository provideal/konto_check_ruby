/* Copyright (C) 2026 tickettoaster GmbH, LGPL 2.1 or later (links against konto_check.c by Michael Plugge).
 * Reference driver for differential testing of the Ruby port against the C library.
 * Reads commands from stdin, one per line, writes one result line per command.
 *   P <pz> <kto> [blz]      -> kto_check_pz(pz,kto,blz) result; blz "-" = NULL
 *   D <pz> <kto> [blz]      -> kto_check_pz_dbg: result methode pz_methode pz pz_pos
 *   B <blz> <kto>           -> kto_check_blz
 *   R <blz> <kto>           -> kto_check_regel_dbg: result blz2 kto2 bic regel
 *   G <blz> <kto>           -> iban_bic_gen: retval iban bic blz2 kto2
 *   I <iban>                -> iban_check: result retval
 *   2 <iban>                -> iban2bic: retval bic blz kto
 *   C <ci>                  -> ci_check
 *   N <zweck>               -> ipi_gen: result dst papier
 *   Q <zweck>               -> ipi_check
 *   A <blz> [filiale]       -> all lut fields for blz/branch
 *   K <bic>                 -> bic_check: result cnt
 *   V                       -> lut_valid
 *   L                       -> print lut info of loaded set
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "konto_check.h"

static void chomp(char *s){ size_t n=strlen(s); while(n && (s[n-1]=='\n'||s[n-1]=='\r')) s[--n]=0; }

int main(int argc,char **argv)
{
   char line[1024],a1[256],a2[256],a3[256],*lutname;
   int level=9,set=0,ret,ret2,n,retval,regel,cnt;
   RETVAL rv;
   const char *bic;
   char blz2[32],kto2[32],dst[64],papier[64],*iban;

   lutname=argc>1?argv[1]:NULL;
   if(argc>2)level=atoi(argv[2]);
   if(argc>3)set=atoi(argv[3]);
   if(lutname && *lutname){
      ret=lut_init(lutname,level,set);
      fprintf(stderr,"lut_init(%s,%d,%d)=%d %s\n",lutname,level,set,ret,kto_check_retval2txt_short(ret));
   }
   while(fgets(line,sizeof(line),stdin)){
      chomp(line);
      if(!*line)continue;
      a1[0]=a2[0]=a3[0]=0;
      n=sscanf(line+2,"%255s %255s %255s",a1,a2,a3);
      switch(line[0]){
         case 'P':
            ret=kto_check_pz(a1,a2,(n>2 && strcmp(a3,"-"))?a3:NULL);
            printf("%d\n",ret);
            break;
         case 'D':
            ret=kto_check_pz_dbg(a1,a2,(n>2 && strcmp(a3,"-"))?a3:NULL,&rv);
            printf("%d %s %d %d %d\n",ret,rv.methode,rv.pz_methode,rv.pz,rv.pz_pos);
            break;
         case 'B':
            printf("%d\n",kto_check_blz(a1,a2));
            break;
         case 'R':
            blz2[0]=kto2[0]=0; bic=NULL; regel=0;
            ret=kto_check_regel_dbg(a1,a2,blz2,kto2,&bic,&regel,&rv);
            printf("%d %s %s %s %d %s %d %d %d\n",ret,blz2,kto2,bic?bic:"(null)",regel,rv.methode,rv.pz_methode,rv.pz,rv.pz_pos);
            break;
         case 'G':
            blz2[0]=kto2[0]=0; bic=NULL; retval=0;
            iban=iban_bic_gen(a1,a2,&bic,blz2,kto2,&retval);
            printf("%d %s %s %s %s\n",retval,iban?iban:"(null)",bic?bic:"(null)",blz2,kto2);
            if(iban)kc_free(iban);
            break;
         case 'I':
            retval=0;
            ret=iban_check(a1,&retval);
            printf("%d %d\n",ret,retval);
            break;
         case '2':
            retval=0; blz2[0]=kto2[0]=0;
            bic=iban2bic(a1,&retval,blz2,kto2);
            printf("%d %s %s %s\n",retval,bic?bic:"(null)",blz2,kto2);
            break;
         case 'C':
            printf("%d\n",ci_check(a1));
            break;
         case 'N':
            ret=ipi_gen(a1,dst,papier);
            printf("%d %s %s\n",ret,dst,papier);
            break;
         case 'Q':
            printf("%d\n",ipi_check(a1));
            break;
         case 'K':
            cnt=0;
            ret=bic_check(a1,&cnt);
            printf("%d %d\n",ret,cnt);
            break;
         case 'A':{
            int fil=(n>1)?atoi(a2):0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13;
            int f=lut_filialen(a1,&r1);
            const char *nm=lut_name(a1,fil,&r2);
            const char *nk=lut_name_kurz(a1,fil,&r3);
            int plz=lut_plz(a1,fil,&r4);
            const char *ort=lut_ort(a1,fil,&r5);
            int pan=lut_pan(a1,fil,&r6);
            const char *bc=lut_bic(a1,fil,&r7);
            int pz=lut_pz(a1,fil,&r8);
            int nr=lut_nr(a1,fil,&r9);
            int ae=lut_aenderung(a1,fil,&r10);
            int lo=lut_loeschung(a1,fil,&r11);
            int nb=lut_nachfolge_blz(a1,fil,&r12);
            int ir=lut_iban_regel(a1,fil,&r13);
            printf("%d %d|%d %s|%d %s|%d %d|%d %s|%d %d|%d %s|%d %d|%d %d|%d %c|%d %c|%d %d|%d %d\n",
               r1,f,r2,nm?nm:"(null)",r3,nk?nk:"(null)",r4,plz,r5,ort?ort:"(null)",r6,pan,r7,bc?bc:"(null)",r8,pz,r9,nr,r10,ae?ae:'-',r11,lo?lo:'-',r12,nb,r13,ir);
            break;}
         case 'V':
            printf("%d\n",lut_valid());
            break;
         case 'L':{
            char *i1,*i2; int v1,v2;
            ret=lut_info(NULL,&i1,&i2,&v1,&v2);
            printf("%d %d %d\n%s\n",ret,v1,v2,i1?i1:"(null)");
            break;}
         default:
            printf("?\n");
      }
      fflush(stdout);
   }
   return 0;
}
