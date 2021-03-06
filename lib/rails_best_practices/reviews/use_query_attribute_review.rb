# encoding: utf-8
require 'rails_best_practices/reviews/review'

module RailsBestPractices
  module Reviews
    # Make sure to use query attribute instead of nil?, blank? and present?.
    #
    # See the best practice details here http://rails-bestpractices.com/posts/56-use-query-attribute.
    #
    # Implementation:
    #
    # Review process:
    #   check all method calls within conditional statements, like @user.login.nil?
    #   if their subjects are one of the model names
    #   and their messages of first call are not pluralize and not in any of the association names
    #   and their messages of second call are one of nil?, blank?, present?, or they are == ""
    #   then you can use query attribute instead.
    class UseQueryAttributeReview < Review

      QUERY_METHODS = %w(nil? blank? present?)

      def url
        "http://rails-bestpractices.com/posts/56-use-query-attribute"
      end

      def interesting_nodes
        [:if, :unless, :elsif]
      end

      # check if node to see whose conditional statement nodes contain nodes that can use query attribute instead.
      #
      # it will check every call nodes in the if nodes. If the call node is
      #
      # 1. two method calls, like @user.login.nil?
      # 2. the subject is one of the model names
      # 3. the message of first call is the model's attribute,
      #    the message is not in any of associations name and is not pluralize
      # 4. the message of second call is one of nil?, blank? or present? or
      #    the message is == and the argument is ""
      #
      # then the call node can use query attribute instead.
      def start_if(node)
        all_conditions = node.conditional_statement == node.conditional_statement.all_conditions ? [node.conditional_statement] : node.conditional_statement.all_conditions
        all_conditions.each do |condition_node|
          if query_attribute_node = query_attribute_node(condition_node)
            subject_node = query_attribute_node.subject
            add_error "use query attribute (#{subject_node.subject}.#{subject_node.message}?)", node.file, query_attribute_node.line
          end
        end
      end

      alias_method :start_unless, :start_if
      alias_method :start_elsif, :start_if

      private
        # recursively check conditional statement nodes to see if there is a call node that may be possible query attribute.
        def query_attribute_node(conditional_statement_node)
          case conditional_statement_node.sexp_type
          when :and, :or
            node = query_attribute_node(conditional_statement_node[1]) || query_attribute_node(conditional_statement_node[2])
            node.file = conditional_statement_code.file
            return node
          when :not
            node = query_attribute_node(conditional_statement_node[1])
            node.file = conditional_statement_node.file
          when :call
            return conditional_statement_node if possible_query_attribute?(conditional_statement_node)
          when :binary
            return conditional_statement_node if possible_query_attribute?(conditional_statement_node)
          end
          nil
        end

        # check if the node may use query attribute instead.
        #
        # if the node contains two method calls, e.g. @user.login.nil?
        #
        # for the first call, the subject should be one of the class names and
        # the message should be one of the attribute name.
        #
        # for the second call, the message should be one of nil?, blank? or present? or
        # it is compared with an empty string.
        #
        # the node that may use query attribute.
        def possible_query_attribute?(node)
          return false unless :call == node.subject.sexp_type
          variable_node = variable(node)
          message_node = node.grep_node(:subject => variable_node.to_s).message

          is_model?(variable_node) && model_attribute?(variable_node, message_node.to_s) &&
            (QUERY_METHODS.include?(node.message.to_s) || compare_with_empty_string?(node))
        end

        # check if the subject is one of the models.
        def is_model?(variable_node)
          return false if variable_node.const?
          class_name = variable_node.to_s.sub(/^@/, '').classify
          models.include?(class_name)
        end

        # check if the subject and message is one of the model's attribute.
        # the subject should match one of the class model name, and the message should match one of attribute name.
        def model_attribute?(variable_node, message)
          class_name = variable_node.to_s.sub(/^@/, '').classify
          attribute_type = model_attributes.get_attribute_type(class_name, message)
          attribute_type && !["integer", "float"].include?(attribute_type)
        end

        # check if the node is with node type :binary, node message :== and node argument is empty string.
        def compare_with_empty_string?(node)
          :binary == node.sexp_type && ["==", "!="].include?(node.message.to_s) && s(:string_literal, s(:string_content)) == node.argument
        end
    end
  end
end
