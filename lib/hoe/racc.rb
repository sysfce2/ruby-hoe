##
# Racc plugin for hoe.
#
# === Tasks Provided:
#
# lexer            :: Generate lexers for all .rex files in your Manifest.txt.
# parser           :: Generate parsers for all .y files in your Manifest.txt.
# .y   -> .rb rule :: Generate a parser using racc.
# .rex -> .rb rule :: Generate a lexer using oedipus_lex.

module Hoe::Racc

  ##
  # Optional: Defines what tasks need to generate parsers/lexers first.
  #
  # Defaults to [:multi, :test, :check_manifest]
  #
  # If you have extra tasks that require your parser/lexer to be
  # built, add their names here in your hoe spec. eg:
  #
  #    racc_tasks << :debug

  attr_accessor :racc_tasks

  ##
  # Optional: Defines what flags to use for racc. default: "-v -l"

  attr_accessor :racc_flags

  ##
  # Optional: Defines what flags to use for oedipus_lex. default: "--independent"

  attr_accessor :oedipus_options

  ##
  # Initialize variables for racc plugin.

  def initialize_racc
    self.racc_tasks = [:multi, :test, :check_manifest]

    # -v = verbose
    # -l = no-line-convert (they don't ever line up anyhow)
    self.racc_flags ||= +"-v -l"
    self.oedipus_options ||= {
                              :do_parse => false,
                             }
  end

  ##
  # Activate the racc dependencies

  def activate_racc_deps
    dependency "racc", "~> 1.5", :development
    dependency "oedipus_lex", "~> 2.6", :development
  end

  ##
  # Define tasks for racc plugin

  def define_racc_tasks
    y_files      = self.spec.files.grep(/\.y$/)
    yy_files     = self.spec.files.grep(/\.yy$/)
    rex_files    = self.spec.files.grep(/\.rex$/)

    yy_re = Regexp.union yy_files.map { |s| s.delete_suffix ".yy" }

    parser_files =
      y_files.map { |f| f.sub(/\.y$/, ".rb") } +
      spec.files.grep(/(#{yy_re})\d+\.rb$/) -
      yy_files
    lexer_files  = rex_files.map  { |f| f.sub(/\.rex$/, ".rex.rb") }

    self.clean_globs += parser_files
    self.clean_globs += lexer_files

    rule ".rb" => ".y" do |t|
      begin
        sh "racc #{racc_flags} -o #{t.name} #{t.source}"
      rescue
        abort "need racc, sudo gem install racc"
      end
    end

    # HACK: taken from oedipus_lex's .rake file to bypass isolate bootstrap
    rule ".rex.rb" => proc { |path| path.sub(/\.rb$/, "") } do |t|
      require "oedipus_lex"
      warn "Generating #{t.name} from #{t.source} from #{OedipusLex::VERSION}"
      oedipus = OedipusLex.new oedipus_options
      oedipus.parse_file t.source

      File.open t.name, "w" do |f|
        f.write oedipus.generate
      end
    end

    task :isolate # stub task

    multitask :parser # make them multithreaded!
    multitask :lexer

    desc "build the parser" unless parser_files.empty?
    task :parser => :isolate

    desc "build the lexer" unless lexer_files.empty?
    task :lexer  => :isolate

    task :parser => parser_files
    task :lexer  => lexer_files

    racc_tasks.each do |t|
      task t => [:parser, :lexer]
    end
  end # define_racc_tasks
end
