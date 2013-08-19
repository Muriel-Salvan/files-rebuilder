module FilesRebuilder

  module GUI

    module ComparePointer

      # Set the pointer to be compared in this widget
      #
      # Parameters::
      # * *pointer* (_FileInfo_ or _SegmentPointer_): Pointer to be compared
      # * *matching_info* (_MatchingInfo_): Matching information of all files matching this pointer
      # * *matching_selection* (_MatchingSelection_): Current user selection of matching files
      def set_pointer_to_compare(pointer, matching_info, matching_selection)
        @matching_selection = matching_selection
        @idx_focused = nil
        @builder['original_container'] << @gui_controller.create_widget_for_matching_pointer(pointer, matching_selection.matching_pointers[pointer] == pointer)
        # For each encountered CRC, keep the matching pointer widget
        # map< String, Gtk::Widget >
        crcs = {}
        matching_pointers_container = @builder['matching_container']
        matching_info.matching_files(@gui_controller.options[:score_min]).sort_by { |_, matching_file_info| matching_file_info.score }.reverse_each do |matching_pointer, matching_file_info|
          crc = matching_pointer.get_crc
          if crcs.has_key?(crc)
            # Add it to the existing widget
            crcs[crc].add_pointer(matching_pointer)
          else
            matching_pointer_widget = @gui_controller.create_widget_for_matching_pointer(matching_pointer, matching_selection.matching_pointers[pointer] == matching_pointer)
            matching_pointers_container << matching_pointer_widget
            crcs[crc] = matching_pointer_widget
          end
        end
        # First, focus the original one
        set_focused(-1)
      end

      def on_next_match_button_clicked(button_widget)
        new_idx_focused = @idx_focused + 1
        new_idx_focused = -1 if (new_idx_focused == @builder['matching_container'].children.size)
        set_focused(new_idx_focused)
      end

      def on_previous_match_button_clicked(button_widget)
        new_idx_focused = @idx_focused - 1
        new_idx_focused = @builder['matching_container'].children.size - 1 if (new_idx_focused == -2)
        set_focused(new_idx_focused)
      end

      def on_select_original_button_clicked(button_widget)
        select_pointer_widget(@builder['original_container'].children[0])
      end

      def on_select_matched_button_clicked(button_widget)
        idx_focused = @idx_focused
        select_pointer_widget(((idx_focused == -1) ? @builder['original_container'].children[0] : @builder['matching_container'].children[idx_focused]))
      end

      # Select a given Matching pointer widget
      #
      # Parameters::
      # * *matching_pointer_widget* (<em>Gtk::Widget</em>): The Matching pointer widget
      def select_pointer_widget(matching_pointer_widget)
        original_pointer = @builder['original_container'].children[0].matching_pointers[0]
        matched_pointer = matching_pointer_widget.matching_pointers[0]
        @matching_selection.matching_pointers[original_pointer] = matched_pointer
        self.destroy
      end

      private

      # Set the focused matching pointer
      #
      # Parameters::
      # * *idx_focus* (_Fixnum_): The index of the matching pointer (-1: original pointer)
      def set_focused(idx_focus)
        if (@idx_focused != idx_focus)
          matching_selection = @matching_selection
          original_pointer_widget = @builder['original_container'].children[0]
          original_pointer = original_pointer_widget.matching_pointers[0]
          matching_pointers_container = @builder['matching_container']
          # Update the previous one
          if (@idx_focused != nil)
            previous_focused_widget = ((@idx_focused == -1) ? original_pointer_widget : matching_pointers_container.children[@idx_focused])
            previous_focused_widget.set_focus(false, matching_selection.matching_pointers[original_pointer] == previous_focused_widget.matching_pointers[0])
          end
          # Update the new one
          next_focused_widget = ((idx_focus == -1) ? original_pointer_widget : matching_pointers_container.children[idx_focus])
          next_focused_widget.set_focus(true, matching_selection.matching_pointers[original_pointer] == next_focused_widget.matching_pointers[0])
          @idx_focused = idx_focus
          # Make sure it is visible
          @builder['matching_scrolledwindow'].vadjustment.value = matching_pointers_container.children[idx_focus].allocation.y if (idx_focus != -1)
        end
      end

    end

  end

end
