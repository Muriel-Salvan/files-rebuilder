module FilesRebuilder

  class Launcher

    # Execute with given arguments
    #
    # Parameters::
    # * *args* (<em>list<String></em>): Arguments given, as in the command line
    def execute(args)
      puts 'Loading GUI libraries...'
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
      puts 'Executing application...'
      main_widget = gui_factory.new_widget('Main')
      gui_controller.set_main_widget(main_widget)
      main_widget.show
      gui_controller.run_callback_dirline_progress_bars
      Gtk.main
      puts 'Quitting application...'
    end

  end

end
