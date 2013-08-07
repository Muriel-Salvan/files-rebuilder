require 'optparse'
require 'rUtilAnts/Logging'
RUtilAnts::Logging::install_logger_on_object

module FilesRebuilder

  class Launcher

    def initialize
      @display_help = false
      @debug = false
      # The command line parser
      @options = OptionParser.new
      @options.banner = 'rebuild [--help] [--debug] <filename>'
      @options.on( '--help',
        'Display help') do
        @display_help = true
      end
      @options.on( '--debug',
        'Activate debug logs') do
        @debug = true
      end
    end

    # Execute with given arguments
    #
    # Parameters::
    # * *args* (<em>list<String></em>): Arguments given, as in the command line
    def execute(args)
      # Analyze arguments
      remaining_args = @options.parse(args)
      if @display_help
        puts @options
      elsif (remaining_args.size > 2)
        puts 'Please specify just 1 file to be loaded on startup.'
        puts @options
      else
        activate_log_debug(true) if @debug
        log_info 'Loading GUI libraries...'
        require 'gtk2'
        Gdk::Threads.init
        require 'ruby-serial'
        require 'filesrebuilder/Model/Data'
        require 'filesrebuilder/GUIFactory'
        require 'filesrebuilder/GUIcontroller'
        gui_factory = GUIFactory.new
        gui_controller = GUIController.new(gui_factory)
        gui_factory.gui_controller = gui_controller
        Gtk::Settings.default.gtk_button_images = true
        log_info 'Executing application...'
        main_widget = gui_factory.new_widget('Main')
        gui_controller.set_main_widget(main_widget)
        main_widget.show
        gui_controller.run_callback_dirline_progress_bars
        gui_controller.load_from_file(remaining_args[0]) if (remaining_args.size == 1)
        Gtk.main
        log_info 'Quitting application...'
      end
    end

  end

end
