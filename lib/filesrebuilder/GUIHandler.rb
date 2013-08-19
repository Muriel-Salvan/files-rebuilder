module FilesRebuilder

  module GUIHandler

    # Init common variables, accessible to all GUI
    #
    # Parameters::
    # * *gui_factory* (_GUIFactory_): The GUI factory
    # * *gui_controller* (_GUIController_): The GUI controller
    # * *builder* (<em>Gtk::Builder</em>): The Gtk builder used to build this widget
    def init(gui_factory, gui_controller, builder)
      @gui_factory = gui_factory
      @gui_controller = gui_controller
      @builder = builder
    end

  end

end
