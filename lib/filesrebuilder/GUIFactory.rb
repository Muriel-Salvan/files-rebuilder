module FilesRebuilder

  class GUIFactory

    # Constructor
    def initialize
      require 'filesrebuilder/GUIHandler'
      # Map of GUI handlers, by gui_id
      @gui_handlers = {}
    end

    # Set the GUI controller
    #
    # Parameters::
    # * *gui_controller* (_GUIController_): The GUI controller
    def gui_controller=(gui_controller)
      @gui_controller = gui_controller
    end

    # Get the GUI handler associated to the given GUI ID
    #
    # Parameters::
    # * *gui_id* (_String_): The GUI widget ID
    # Result::
    # * _GUIHandler_: The corresponding GUI handler
    def get_gui_handler(gui_id)
      if (@gui_handlers[gui_id] == nil)
        require "filesrebuilder/GUI/#{gui_id}"
        @gui_handlers[gui_id] = eval("FilesRebuilder::GUI::#{gui_id}").new(self, @gui_controller)
      end
      return @gui_handlers[gui_id]
    end

    # Get a new widget associated to the given GUI ID
    #
    # Parameters::
    # * *gui_id* (_String_): The GUI widget ID
    # Result::
    # * <em>Gtk::Widget</em>: The corresponding widget
    def new_widget(gui_id)
      return get_gui_handler(gui_id).new_widget
    end

  end

end
