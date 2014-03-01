# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "seeing_is_believing/version"

Gem::Specification.new do |s|
  s.name        = "seeing_is_believing"
  s.version     = SeeingIsBelieving::VERSION
  s.authors     = ["Josh Cheek"]
  s.email       = ["josh.cheek@gmail.com"]
  s.homepage    = "https://github.com/JoshCheek/seeing_is_believing"
  s.summary     = %q{Records results of every line of code in your file}
  s.description = %q{Records the results of every line of code in your file (intended to be like xmpfilter), inspired by Bret Victor's JavaScript example in his talk "Inventing on Principle"}
  s.license     = "WTFPL"

  s.rubyforge_project = "seeing_is_believing"

  s.files         = `git ls-files`.split("\n") - ['docs/seeing is believing.psd'] # remove psd b/c it boosts the gem size from 50kb to 20mb O.o
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency             "parser",   "~> 2.1.4"

  s.add_development_dependency "haiti",    "~> 0.0.3"
  s.add_development_dependency "rake",     "~> 10.0.3"
  s.add_development_dependency "rspec",    "~> 2.12.0"
  s.add_development_dependency "cucumber", "~> 1.2.1"
  s.add_development_dependency "ichannel", "~> 5.1.1"

  s.post_install_message = <<'Omg, frogs <3'
              .7
     .      .M
      .  . .N
      M.  ..O
     =. .. .M
     N . .  .N
      O.. . . O
        MN:. . M
           OM...N
             N .OM                 .NM8MMMMMM
             O ..N             ...MM=:Z7?Z7??MMMMIMMOM8N
             M...O        ,MMMMMMMMMM$$:=ZZ$~:$?7ZMMMMM8?M
           .N .  M       MMI$7:==?:77MMMM7$O~+~ZO~~I=7ZMMMM
           O$...N        M=$ZZI=MMM7ZZI=?MMZ+:$I?8Z~?ZO~=ZIMM
        .MN ...O         M~?Z==ZZZ=MM$$=$ZZMMO=~~?$=$Z~~OO+=MM
        OM ...,M      DMMMMMMMDMMMMOMMMMMMMMMMM=Z=+OOI=+ZO$O+MM
      NOM.. . N     MMMMMMMMMMMMMM?:MMMMMMMMMMMMMM$ZZ?$+IZ7+8?M8
     NOM.....O     MMMMMMMMMM: ...7MMMMMMMMMMMMMMM78OI+D=78=$MM
    NO.. ...MN     MMMMMMMM........MMMMMMMMMMMMMMN,MMMO7?I8Z7OM
   MN.......O       NMMMMM,......... MMMMMMMMMMMMM ~MMM?NMM7O8MM
  NOM..  ..MN        NMMI............ZMMMMMMMMMMM .... ,MM7.MMM
 NOM.. ....OM         M................MMMMMMMMM.......... MM:M
 NOM.... ..NO        M...................~MMMM .............I,,M
 NOM.. .. .MN       MM ..ZMMMMMM. ...........................=MM
 NOM. . ... O       M.MMMMNMMMMMMMMZ..........................$MI
 NOM8.. .. .MM      MZMMMMMMMMMMMMMMM ........M~...............MM
  NOM .. . . NOM    M....................... 8M$................MM
   NOMO. . . . .    M.MMMMMMMMMMMMNMMMMNMMMMMM .................MM,
     NOMM8.  .     M:MM .MM.  ................. ................ MM
           . .  .MMMM ....MMMMMMM. ...   ..7ZMM..................MM
               .MNOM......MMMMMMMMMMMMMMMMMMM....................OMM
             .   H         MMMMMMMMMMMMMMMMM.......,..............MM
                            MMMMMMMMMMMM=.........MM......  ......MMN
                              :MMMM...............MM.......M......MMM
                                 MMM ........  ...MN.....:7.......MMM .MMMMMM
   Seeing                        MMMM ........M...M.....M.........MMMM .....MM
                                 M .MMM ..... M...M ...=I....... MM.........M
      is                         M..MMMM ....M... M....M.....MMM:..........MM
                                MM..M  MMM ..M ..MM...M....MMM.............M,
  Believing                    .M..MM   MMMMMM...M....M .............. .. MM
                       . MMMMMMMM..M   M .MMM ..MM ..OM..............MN..MM
                     M ............M  MMM .MM...MMMMMMM ............M= +MM
                     :MM7 .. M..IMM  D ..M?M...MM     M ..........MM .MM,
                          .M .M..    ... .M+...M      NM.......:MMM .MM
                                  .MM+.ZMM  .. M       MMMMMMMMMM... M
                                  MI .8MM,....MM           .MMM. MM.M
                                 MMM...MMMM. MI        .OMMM. OMMM MM
                                M..:MD .. M M        M  ...NMM..MM.MM
                                MMMM.....M ..M      .M:...M ...M ...M
                                           MM          MMMM......MMMI
Omg, frogs <3
end
