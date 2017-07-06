# -*- encoding: utf-8 -*-
$:.push File.realpath("lib", __dir__)
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

  s.add_dependency             "parser",      "~> 2.4.0"
  s.add_dependency             "childprocess","~> 0.7.1"

  s.add_development_dependency "pry"
  s.add_development_dependency "haiti",       ">= 0.1", "< 0.3"
  s.add_development_dependency "rake",        "~> 12.0.0"
  s.add_development_dependency "mrspec",      "~>  0.3.1"
  s.add_development_dependency "rspec",       "~>  3.6.0"
  s.add_development_dependency "cucumber",    "~>  2.4"
  s.add_development_dependency "ripper-tags", "~>  0.3"

  s.post_install_message = <<'Omg, frogs <3'.gsub(/(gg+)/) { |capture| "\e[32m#{capture.gsub 'g', '.'}\e[0m" }.gsub("brown", "\e[33m").gsub("off", "\e[0m")
              .7
     .      .M
      .  . .N
      M.  ..O
     =. .. .M
     N . .  .N
      O.. . . O
        MN:. . M
           OM...N
             N .OM                 brown.NM8MMMMMMoff
             O ..N             brown...MM=:Z7?Z7??MMMMIMMOM8Noff
             M...O        brown,MMMMMMMMMM$$:=ZZ$~:$?7ZMMMMM8?Moff
           .N .  M       brownMMI$7:==?:77MMMM7$O~+~ZO~~I=7ZMMMMoff
           O$...N        brownM=$ZZI=MMM7ZZI=?MMZ+:$I?8Z~?ZO~=ZIMMoff
        .MN ...O         brownM~?Z==ZZZ=MM$$=$ZZMMO=~~?$=$Z~~OO+=MMoff
        OM ...,M      DAAAAAAAAAAAAAAAAAAAAAAAMbrown=Z=+OOI=+ZO$O+MMoff
      NOM.. . N     DAAAAAAAAAAAAM?:DAAAAAAAAAAAAMbrown$ZZ?$+IZ7+8?M8off
     NOM.....O     DAAAAAAAAM:ggggDAAAAAAAAAAAAAAMbrown78OI+D=78=$MMoff
    NO.. ...MN     DAAAAAAAMgggggggDAAAAAAAAAAAAAM,MMbrownMO7?I8Z7OMoff
   MN.... ..O       DAAAAAMgggggggggDAAAAAAAAAAAAMgg~MMbrown?NMM7O8MMoff
  NOM..  ..MN        DAAMggggggggggggDAAAAAAAAAAMgggggggMMbrown7.MMMoff
 NOM.. .. .OM         MggggggggggggggggDAAAAAAAMgggggggggggMM:M
 NOM. .. ..NO        Mggggggggggggggggggg~DAAMggggggggggggggI,,M
 NOM.. .. .MN       MMgggbrownZMMMMMMoffggggggggggggggggggggggggggggg=MM
 NOM. . ... O       MggbrownMMMNMMMMMMMMZoffgggggggggggggggggggggggggg$MI
 NOM8.. .. .MM      MZbrownMMMMMMMMMMMMMMMoffgggggggggM~gggggggggggggggMM
  NOM .. . . NOM    Mgggggggggggggggggggggggg8M$ggggggggggggggggMM
   NOMO. . . . .    M.MMMMMMMMMMMMNMMMMNMMMMMMggggggggggggggggggMM,
     NOMM8.  .     M:MM  MMggggggggggggggggggggggggggggggggggggggMM
           .    .MMMM     brownMMMMgggggggggggggbrown7ZMMggggggggggggggggggMM
               .MNOM      brownMMMMMMMMMMMMMMMMMMMggggggggggggggggggggOMM
                 H         brownMMMMMMMMMMMMMMMMMggggggg,ggggggggggggggMM
                            brownMMMMMMMMMMMM=gggggggggMMggggggggggggggMMN
                              brown:MMMMggggggggggggggggMgggggggMggggggMMM
                                 MMMggggggggggggggMNggggg:7gggggggMMM .MMMMMM
   Seeing                        MMMMgggggggggMgggMgggggMgggggggggMMMMggggggMM
                                 MggMMMgggggggMgggMgggg=IggggggggMMgggggggggM
      is                         MggMMMMgggggMggggMggggMgggggMMM:ggggggggggMM
                                MMggM  MMMgggMgggMMgggMggggMMMgggggggggggggM,
  Believing                    .MggMM   MMMMMMgggMggggMgggggggggggggggggggMM
                       ggMMMMMMMMggM   MggMMMgggMMgggOMggggggggggggggMNggMM
                     MgggggggggggggM  MMMggMMgggMMMMMMMgggggggggggggMgg+MM
                     :MM7ggggMggIMM  D ggM?MgggMM     MgggggggggggMMggMM,
                          .MggMgg    ggg gM+gggM      NMggggggggMMMggMM
                                  .MM+gZMMgggggM       MMMMMMMMMMggggM
                                  MIgg8MM,ggggMM           .MMMggMggM
                                 MMMgggMMMMggMI       ggOMMMggOMMggMM
                                MgggMDggggM M        MgggggNMMggMMggM
                                MMMMgggggM ggM      .M:gggMggggMggggM
                                           MM          MMMMggggggMMMI
Omg, frogs <3
end
