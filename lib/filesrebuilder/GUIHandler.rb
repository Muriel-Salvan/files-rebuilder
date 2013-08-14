module FilesRebuilder

  class GUIHandler

    # Constructor
    #
    # Parameters::
    # * *gui_factory* (_GUIFactory_): The GUI factory
    # * *gui_controller* (_GUIController_): The GUI controller
    def initialize(gui_factory, gui_controller)
      @gui_factory = gui_factory
      @gui_controller = gui_controller
      @class_name = self.class.name.split('::')[-1]
      # Load the Glade content in memory to avoid disk IOs each time we ask for a new widget
      @glade_content = nil
      File.open("#{File.dirname(__FILE__)}/GUI/#{self.class.name.split('::')[2..-1].join('/')}.glade", 'r') do |file|
        @glade_content = file.read
      end
    end

    # Create a new root widget
    #
    # Result::
    # * <em>Gtk::Widget</em>: The root widget
    def new_widget
      gtk_builder = Gtk::Builder.new
      gtk_builder.add_from_string(@glade_content)
      gtk_builder.connect_signals { |handler| method(handler) }
      return gtk_builder[@class_name]
    end

  end

end
