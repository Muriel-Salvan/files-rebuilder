module FilesRebuilder

  module GUI

    module ComparePointer

      # Set the pointer to be compared in this widget
      #
      # Parameters::
      # * *itr_pointer* (_PointerIterator_): Pointer iterator giving pointers to be compared
      # * *matching_selection* (_MatchingSelection_): Current user selection of matching files
      # * *single* (_Boolean_): Is there a single pointer to compare?
      def set_pointers_to_compare(itr_pointer, matching_selection, single)
        @matching_selection = matching_selection
        @itr_pointer = itr_pointer
        @single = single
        @builder['comparison_navigation_hbox'].visible = !single
        goto_next
      end

      def on_close_button_clicked(button_widget)
        self.destroy
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

      def on_next_comparison_button_clicked(button_widget)
        goto_next
      end

      def on_previous_comparison_button_clicked(button_widget)
        goto_prev
      end

      # Select a given Matching pointer widget
      #
      # Parameters::
      # * *matching_pointer_widget* (<em>Gtk::Widget</em>): The Matching pointer widget
      def select_pointer_widget(matching_pointer_widget)
        original_pointer = @builder['original_container'].children[0].matching_pointers[0]
        matched_pointer = matching_pointer_widget.matching_pointers[0]
        @matching_selection.matching_pointers[original_pointer] = matched_pointer
        goto_next
      end

      private

      # Display the next comparison
      def goto_next
        pointer, matching_pointers = @itr_pointer.next(@builder['skip_matched_checkbutton'].active?, true)
        if (pointer == nil)
          if @single
            self.destroy
          else
            @itr_pointer.reset
            pointer, matching_pointers = @itr_pointer.next(@builder['skip_matched_checkbutton'].active?, true)
            if (pointer == nil)
              notify('No more items to compare')
            else
              notify('Cycling items to compare from the beginning')
            end
          end
        else
          notify('')
        end
        if (pointer != nil)
          load_comparison(pointer, matching_pointers)
        end
      end

      # Display the previous comparison
      def goto_prev
        pointer, matching_pointers = @itr_pointer.next(@builder['skip_matched_checkbutton'].active?, false)
        if (pointer == nil)
          @itr_pointer.reset
          pointer, matching_pointers = @itr_pointer.next(@builder['skip_matched_checkbutton'].active?, false)
          if (pointer == nil)
            notify('No more items to compare')
          else
            notify('Cycling items to compare from the end')
          end
        else
          notify('')
        end
        if (pointer != nil)
          load_comparison(pointer, matching_pointers)
        end
      end

      # Load a new pointer and its matching pointers to be displayed
      #
      # Parameters::
      # * *pointer* (<em>(_FileInfo_ | _SegmentPointer_)</em>): The pointer, or nil if none
      # * *matching_pointers* (<em>list< [ (_FileInfo_ | _SegmentPointer_), MatchingIndexSinglePointer ] ></em>): The sorted list of matching pointers, along with their matching index information
      def load_comparison(pointer, matching_pointers)
        @idx_focused = nil
        original_container = @builder['original_container']
        matching_pointers_container = @builder['matching_container']
        # Delete previous containers if needed
        original_container.remove(original_container.children[0]) if (original_container.children.size > 0)
        matching_pointers_container.each do |child_widget|
          matching_pointers_container.remove(child_widget)
        end
        # Create new containers
        original_container << @gui_controller.create_widget_for_matching_pointer(pointer, @matching_selection.matching_pointers[pointer] == pointer)
        # For each encountered CRC, keep the matching pointer widget
        # map< String, Gtk::Widget >
        crcs = {}
        matching_pointers.each do |matching_pointer, matching_file_info|
          crc = matching_pointer.get_crc
          if crcs.has_key?(crc)
            # Add it to the existing widget
            crcs[crc].add_pointer(matching_pointer)
          else
            matching_pointer_widget = @gui_controller.create_widget_for_matching_pointer(matching_pointer, @matching_selection.matching_pointers[pointer] == matching_pointer)
            matching_pointers_container << matching_pointer_widget
            crcs[crc] = matching_pointer_widget
          end
        end
        # First, focus the original one
        set_focused(-1)
      end

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

      private

      # Notify a message to the user
      #
      # Parameters::
      # * *message* (_String_): Message to notify
      def notify(message)
        status_bar = @builder['statusbar']
        status_bar.push(status_bar.get_context_id(''), message)
      end

    end

  end

end
